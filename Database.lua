-- Database.lua
-- All persistence operations. Modules MUST go through this rather than
-- mutating SavedVariables directly, so we get one place to enforce schema,
-- emit callbacks, and trim oversized data.

local addonName, ns = ...
local C = ns.Constants

local Database = {}
ns.Database = Database

-- Simple callback registry for "player added/changed/removed".
-- Modules that care (UI, GuildSync, Backup) subscribe in their Initialize.
Database.callbacks = LibStub("CallbackHandler-1.0"):New(Database)

-- ==========================================================================
-- Key normalization
-- ==========================================================================

-- Normalize "Frost-Lightbringer" / "frost-Lightbringer" / "Frost - Lightbringer"
-- into a stable lower-case "frost-lightbringer" used as table key.
function Database:NormalizeKey(input)
    if type(input) ~= "string" then return nil end
    input = input:gsub("^%s+", ""):gsub("%s+$", "")
    if input == "" then return nil end

    local name, realm = input:match("^([^%-%s]+)%s*%-%s*(.+)$")
    if not name then
        -- No realm given - assume player's realm
        name = input
        realm = GetNormalizedRealmName and GetNormalizedRealmName() or GetRealmName()
        realm = realm and realm:gsub("%s", "") or ""
    end
    realm = realm:gsub("%s", "")
    if realm == "" then return nil end
    return (name:lower() .. "-" .. realm:lower()), name, realm
end

function Database:DisplayName(rec)
    if not rec then return "" end
    return rec.name .. "-" .. rec.realm
end

-- ==========================================================================
-- Schema migration
-- ==========================================================================

function Database:Migrate(global)
    global.schemaVersion = global.schemaVersion or 0

    -- v0 -> v1: launch schema, nothing to do.
    if global.schemaVersion < 1 then
        global.schemaVersion = 1
    end

    -- v1 -> v2: collapse 5-tier reputation (BLACKLIST=-2, NEGATIVE=-1,
    -- NEUTRAL=0, POSITIVE=+1, FAVORITE=+2) into a 3-tier scale (BLACKLIST=-1,
    -- NEUTRAL=0, POSITIVE=+1). Per user choice: records that were Negative
    -- (-1) or Favorite (+2) get DELETED rather than merged — the user said
    -- they'll never use those tiers and didn't want them collapsing into
    -- adjacent tiers. Blacklist (-2) shifts to the new BLACKLIST slot (-1).
    if global.schemaVersion < 2 then
        local toDelete = {}
        local dropped, shifted = 0, 0
        for key, rec in pairs(global.players or {}) do
            local r = rec.reputation
            if r == -1 or r == 2 then
                -- Was Negative or Favorite — drop the record entirely.
                toDelete[#toDelete + 1] = key
            elseif r == -2 then
                -- Old Blacklist (-2) shifts to new Blacklist (-1).
                rec.reputation = -1
                shifted = shifted + 1
            elseif r == nil then
                rec.reputation = 0  -- defensive
            end
            -- r == 0 (Neutral) and r == 1 (Positive) stay as-is.
        end

        for _, key in ipairs(toDelete) do
            -- Unlink from BNet account map and altID lists before deleting,
            -- so we don't leave dangling references. Reuse RemovePlayer for
            -- correctness — it handles the cleanup paths.
            local rec = global.players[key]
            if rec then
                if rec.bnetAccountID and global.bnetAccounts[rec.bnetAccountID] then
                    local bnet = global.bnetAccounts[rec.bnetAccountID]
                    if bnet.players then
                        for i = #bnet.players, 1, -1 do
                            if bnet.players[i] == key then
                                table.remove(bnet.players, i)
                            end
                        end
                        if #bnet.players == 0 then
                            global.bnetAccounts[rec.bnetAccountID] = nil
                        end
                    end
                end
                for _, otherKey in ipairs(rec.altIDs or {}) do
                    local other = global.players[otherKey]
                    if other and other.altIDs then
                        for i = #other.altIDs, 1, -1 do
                            if other.altIDs[i] == key then
                                table.remove(other.altIDs, i)
                            end
                        end
                    end
                end
            end
            global.players[key] = nil
        end
        dropped = #toDelete

        if dropped > 0 or shifted > 0 then
            -- Print to chat after addon is fully initialized so the user
            -- knows what happened. Defer via C_Timer so chat is ready.
            local msg = string.format(
                "|cffd0a070RepKeeper:|r migrated database - %d record(s) dropped (old Negative/Favorite), %d shifted to new scale.",
                dropped, shifted)
            C_Timer.After(2, function() print(msg) end)
        end
        global.schemaVersion = 2
    end

    -- v2 -> v3: Custom tags gain an explicit `tier` field ("negative",
    -- "neutral", "positive"). Older custom tags only have `negative` bool;
    -- derive tier from it (true→negative, false→positive since the old UI
    -- only allowed those two options).
    if global.schemaVersion < 3 then
        for _, def in pairs(global.customTags or {}) do
            if not def.tier then
                def.tier = def.negative and "negative" or "positive"
            end
        end
        global.schemaVersion = 3
    end

    -- v3 -> v4: scrub em-dashes (U+2014) from old firstSeenLocation strings.
    -- Earlier versions used " — " as a separator between zone and subzone;
    -- newer versions use " - ". The em-dash renders fine but looks
    -- inconsistent with other UI text.
    if global.schemaVersion < 4 then
        for _, rec in pairs(global.players or {}) do
            if rec.firstSeenLocation then
                rec.firstSeenLocation = rec.firstSeenLocation:gsub("\226\128\148", "-")
            end
        end
        global.schemaVersion = 4
    end

    -- Future: if global.schemaVersion < 5 then ... migrate ... end
end

-- ==========================================================================
-- Player CRUD
-- ==========================================================================

local function captureLocation()
    -- Capture where the player record was created. Used for "met them in X"
    -- context later. We grab the most specific name available.
    local zone = GetRealZoneText() or ""
    local subzone = GetSubZoneText() or ""
    if subzone ~= "" and subzone ~= zone then
        return zone .. " - " .. subzone
    end
    return zone ~= "" and zone or "unknown"
end

local function newPlayerRecord(name, realm)
    local now = time()
    return {
        name = name,
        realm = realm,
        normalizedKey = (name:lower() .. "-" .. realm:lower()),
        class = nil,
        race = nil,
        gender = nil,
        faction = nil,
        guid = nil,
        bnetAccountID = nil,
        bnetTag = nil,
        reputation = C.REP.NEUTRAL,
        tags = {},
        notes = "",
        timeline = {},
        altIDs = {},
        encounterCount = 0,
        firstSeen = now,
        lastSeen = now,
        firstSeenLocation = captureLocation(),  -- where we first met
        addedBy = (UnitName("player") or "?") .. "-" .. (GetNormalizedRealmName and GetNormalizedRealmName() or GetRealmName() or "?"),
        source = "manual",
        sourcePeer = nil,
    }
end

function Database:GetPlayer(input)
    local key = self:NormalizeKey(input)
    if not key then return nil end
    return ns.db.global.players[key]
end

function Database:GetOrCreatePlayer(input)
    local key, name, realm = self:NormalizeKey(input)
    if not key then return nil, false end
    local existing = ns.db.global.players[key]
    if existing then return existing, false end
    local rec = newPlayerRecord(name, realm)
    ns.db.global.players[key] = rec
    self.callbacks:Fire("OnPlayerAdded", rec)
    return rec, true
end

function Database:RemovePlayer(input)
    local key = self:NormalizeKey(input)
    if not key then return false end
    local rec = ns.db.global.players[key]
    if not rec then return false end

    -- Unlink from BNet account map
    if rec.bnetAccountID then
        local bnet = ns.db.global.bnetAccounts[rec.bnetAccountID]
        if bnet and bnet.players then
            for i = #bnet.players, 1, -1 do
                if bnet.players[i] == key then
                    table.remove(bnet.players, i)
                end
            end
            if #bnet.players == 0 then
                ns.db.global.bnetAccounts[rec.bnetAccountID] = nil
            end
        end
    end

    -- Unlink from any altIDs lists on other players
    for _, otherKey in ipairs(rec.altIDs or {}) do
        local other = ns.db.global.players[otherKey]
        if other and other.altIDs then
            for i = #other.altIDs, 1, -1 do
                if other.altIDs[i] == key then
                    table.remove(other.altIDs, i)
                end
            end
        end
    end

    ns.db.global.players[key] = nil
    self.callbacks:Fire("OnPlayerRemoved", rec)
    return true
end

function Database:Touch(rec)
    if not rec then return end
    rec.lastSeen = time()
    self.callbacks:Fire("OnPlayerChanged", rec)
end

function Database:SetReputation(rec, level)
    if not rec then return end
    if level < C.REP.BLACKLIST or level > C.REP.FAVORITE then return end
    rec.reputation = level
    self:Touch(rec)
end

function Database:ToggleTag(rec, tagID)
    if not rec or not tagID then return false end
    rec.tags = rec.tags or {}
    if rec.tags[tagID] then
        rec.tags[tagID] = nil
        self:Touch(rec)
        return false
    else
        rec.tags[tagID] = true
        self:Touch(rec)
        return true
    end
end

function Database:GetTagDef(tagID)
    return C.BUILTIN_TAGS[tagID] or ns.db.global.customTags[tagID]
end

function Database:AddCustomTag(tagID, name, tier, icon)
    if not tagID or tagID == "" then return false end
    -- Don't allow overwriting builtins
    if C.BUILTIN_TAGS[tagID] then return false end
    -- Default to neutral if no tier provided
    if tier ~= "negative" and tier ~= "neutral" and tier ~= "positive" then
        tier = "neutral"
    end
    ns.db.global.customTags[tagID] = {
        name = name or tagID,
        tier = tier,
        negative = (tier == "negative"),  -- legacy field for old code paths
        icon = icon or "Interface\\Icons\\INV_Misc_QuestionMark",
    }
    return true
end

-- Remove a custom tag entirely. Refuses to touch builtins. Strips the tag
-- from every player record so we don't leave dangling references.
function Database:RemoveCustomTag(tagID)
    if not tagID or tagID == "" then return false end
    if C.BUILTIN_TAGS[tagID] then return false end  -- protect builtins
    if not ns.db.global.customTags[tagID] then return false end

    -- Untag from every player that has it
    for _, rec in pairs(ns.db.global.players) do
        if rec.tags and rec.tags[tagID] then
            rec.tags[tagID] = nil
            self.callbacks:Fire("OnPlayerChanged", rec)
        end
    end

    ns.db.global.customTags[tagID] = nil
    return true
end

-- Prune abandoned neutral records older than N days. "Abandoned" means
-- the record meets ALL of these:
--   - reputation == NEUTRAL (not blacklisted, not positive)
--   - source ~= "manual" (we only auto-prune what we auto-added)
--   - no tags
--   - no notes
--   - no altIDs
--   - lastSeen older than threshold
-- Anything you've manually touched is preserved.
function Database:PruneAbandoned(maxAgeDays)
    if not maxAgeDays or maxAgeDays <= 0 then return 0 end
    local cutoff = time() - (maxAgeDays * 86400)
    local toDelete = {}
    for key, rec in pairs(ns.db.global.players) do
        local keep = false
        if rec.reputation ~= C.REP.NEUTRAL then keep = true end
        if rec.source == "manual" then keep = true end
        if rec.tags and next(rec.tags) then keep = true end
        if rec.notes and rec.notes ~= "" then keep = true end
        if rec.altIDs and #rec.altIDs > 0 then keep = true end
        if (rec.lastSeen or 0) >= cutoff then keep = true end
        if not keep then toDelete[#toDelete + 1] = key end
    end
    for _, key in ipairs(toDelete) do
        self:RemovePlayer(key)
    end
    return #toDelete
end

-- Iterate all players, optionally filtered by predicate(rec) -> bool
function Database:Iterate(predicate)
    local list = {}
    for key, rec in pairs(ns.db.global.players) do
        if not predicate or predicate(rec) then
            list[#list + 1] = rec
        end
    end
    return list
end

function Database:Count()
    local n = 0
    for _ in pairs(ns.db.global.players) do n = n + 1 end
    return n
end

-- ==========================================================================
-- Player metadata enrichment
-- ==========================================================================

-- Pull race/class/faction/guid from a unit token if currently visible
function Database:EnrichFromUnit(rec, unit)
    if not rec or not unit or not UnitExists(unit) then return end
    local _, classFile = UnitClass(unit)
    if classFile then rec.class = classFile end
    local _, raceFile = UnitRace(unit)
    if raceFile then rec.race = raceFile end
    local gender = UnitSex(unit)
    if gender then rec.gender = gender end
    local faction = UnitFactionGroup(unit)
    if faction and faction ~= "Neutral" then rec.faction = faction end
    local guid = UnitGUID(unit)
    if guid then rec.guid = guid end
end

function Database:EnrichFromGUID(rec, guid)
    if not rec or not guid then return end
    rec.guid = guid
    -- GetPlayerInfoByGUID returns localized class then classFile then race etc.
    local ok, _, classFile = pcall(GetPlayerInfoByGUID, guid)
    if ok and type(classFile) == "string" then rec.class = rec.class or classFile end
end

-- ==========================================================================
-- Encounter buffer (ring buffer to bound storage)
-- ==========================================================================

function Database:RecordEncounter(encType, result, participants, extra)
    if not ns.db.global.settings.encounterHistoryEnabled then return end
    local g = ns.db.global
    g.encounterCounter = (g.encounterCounter or 0) + 1
    local id = g.encounterCounter

    local enc = {
        id = id,
        type = encType,
        result = result or C.ENCOUNTER_RESULT.UNKNOWN,
        timestamp = time(),
        participants = participants or {},  -- list of normalized keys
        extra = extra,  -- table: { dungeonName, keyLevel, deaths, etc. }
    }
    g.encounters[id] = enc

    -- Bump per-player counters and link
    for _, key in ipairs(enc.participants) do
        local rec = g.players[key]
        if rec then
            rec.encounterCount = (rec.encounterCount or 0) + 1
            self:Touch(rec)
        end
    end

    -- Trim to limit
    local limit = ns.db.global.settings.encounterHistoryLimit or 1000
    self:TrimEncounters(limit)

    self.callbacks:Fire("OnEncounterRecorded", enc)
    return enc
end

function Database:TrimEncounters(limit)
    local g = ns.db.global
    -- Cheap path: gather IDs and drop the smallest until under limit
    local ids = {}
    for id in pairs(g.encounters) do ids[#ids + 1] = id end
    if #ids <= limit then return end
    table.sort(ids)
    local toRemove = #ids - limit
    for i = 1, toRemove do
        g.encounters[ids[i]] = nil
    end
end

function Database:GetEncountersForPlayer(rec, max)
    if not rec then return {} end
    max = max or 50
    local g = ns.db.global
    local out = {}
    -- Most recent first; iterate IDs in reverse
    local ids = {}
    for id in pairs(g.encounters) do ids[#ids + 1] = id end
    table.sort(ids, function(a, b) return a > b end)
    for _, id in ipairs(ids) do
        local enc = g.encounters[id]
        for _, key in ipairs(enc.participants) do
            if key == rec.normalizedKey then
                out[#out + 1] = enc
                break
            end
        end
        if #out >= max then break end
    end
    return out
end

-- ==========================================================================
-- BNet account linking (alt detection)
-- ==========================================================================

function Database:LinkBNetAccount(rec, bnetAccountID, bnetTag)
    if not rec or not bnetAccountID then return end

    -- Remove previous link if it changed (rare but possible if player was
    -- re-friended under a new BNet account)
    if rec.bnetAccountID and rec.bnetAccountID ~= bnetAccountID then
        local prev = ns.db.global.bnetAccounts[rec.bnetAccountID]
        if prev and prev.players then
            for i = #prev.players, 1, -1 do
                if prev.players[i] == rec.normalizedKey then
                    table.remove(prev.players, i)
                end
            end
        end
    end

    rec.bnetAccountID = bnetAccountID
    rec.bnetTag = bnetTag

    local bnet = ns.db.global.bnetAccounts[bnetAccountID]
    if not bnet then
        bnet = { players = {}, primaryNote = "" }
        ns.db.global.bnetAccounts[bnetAccountID] = bnet
    end

    -- Add to bnet's player list if not already there
    local already = false
    for _, k in ipairs(bnet.players) do
        if k == rec.normalizedKey then already = true; break end
    end
    if not already then
        table.insert(bnet.players, rec.normalizedKey)
    end

    -- Cross-link altIDs across all players on this BNet account
    self:RebuildAltsForBNet(bnetAccountID)
    self:Touch(rec)
end

function Database:RebuildAltsForBNet(bnetAccountID)
    local bnet = ns.db.global.bnetAccounts[bnetAccountID]
    if not bnet then return end
    for _, key in ipairs(bnet.players) do
        local rec = ns.db.global.players[key]
        if rec then
            rec.altIDs = {}
            for _, otherKey in ipairs(bnet.players) do
                if otherKey ~= key then
                    table.insert(rec.altIDs, otherKey)
                end
            end
        end
    end
end

-- Manual alt linking (when BNet detection isn't available)
function Database:LinkAltsManual(keyA, keyB)
    local a = ns.db.global.players[keyA]
    local b = ns.db.global.players[keyB]
    if not a or not b then return false end
    a.altIDs = a.altIDs or {}
    b.altIDs = b.altIDs or {}
    local function addUnique(list, k)
        for _, v in ipairs(list) do if v == k then return end end
        table.insert(list, k)
    end
    addUnique(a.altIDs, keyB)
    addUnique(b.altIDs, keyA)
    self:Touch(a); self:Touch(b)
    return true
end
