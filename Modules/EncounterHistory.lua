-- Modules/EncounterHistory.lua
-- Watches group composition and instance entry/exit to build encounter records.
-- Goal: when a group disbands or completes content, we know who was there
-- and what happened (timed, depleted, abandoned, this-player-left-early).
--
-- Tradeoffs:
--   * We snapshot the roster on instance entry. Anyone joining/leaving mid-run
--     gets recorded in a "transitions" list on the encounter.
--   * A "left early" event is fired when a roster member disappears WHILE
--     content is in progress (instance still active). It's not perfectly
--     precise (DC vs ragequit looks the same) but it's good enough for the
--     "key leaver" use case the user cares about.
--   * Combat-log damage/heal snapshots are out of scope for v1. Hooks are
--     left in place so we can add them later without re-architecting.

local addonName, ns = ...
local C = ns.Constants

local EncounterHistory = {}
ns.EncounterHistory = EncounterHistory

local Addon = ns.Addon

-- Active session state (transient, not persisted)
local session = nil

local function newSession(encType, extra)
    return {
        type = encType,
        startTime = time(),
        roster = {},        -- [normalizedKey] = { name, realm, joined = epoch, left = nil }
        transitions = {},   -- chronological list of { ts, key, action }
        extra = extra or {},
        result = C.ENCOUNTER_RESULT.UNKNOWN,
    }
end

function EncounterHistory:Initialize()
    if not ns.db.global.settings.encounterHistoryEnabled then return end

    Addon:RegisterEvent("PLAYER_ENTERING_WORLD",     function() self:OnEnteringWorld() end)
    Addon:RegisterEvent("ZONE_CHANGED_NEW_AREA",     function() self:OnZoneChanged() end)
    Addon:RegisterEvent("GROUP_ROSTER_UPDATE",       function() self:OnRosterUpdate() end)
    Addon:RegisterEvent("CHALLENGE_MODE_START",      function() self:OnMythicPlusStart() end)
    Addon:RegisterEvent("CHALLENGE_MODE_COMPLETED",  function() self:OnMythicPlusComplete() end)
    Addon:RegisterEvent("ENCOUNTER_END",             function(_, _, _, _, _, success) self:OnEncounterEnd(success) end)
    Addon:RegisterEvent("PLAYER_LEAVING_WORLD",      function() self:OnLeavingWorld() end)
end

function EncounterHistory:OnEnteringWorld()
    self:DetectInstance()
end

function EncounterHistory:OnZoneChanged()
    self:DetectInstance()
end

function EncounterHistory:DetectInstance()
    local inInstance, instanceType = IsInInstance()
    if inInstance then
        if not session then
            local encType = self:MapInstanceType(instanceType)
            session = newSession(encType, { instanceType = instanceType })
            -- Capture instance display name (e.g. "Magister's Terrace")
            local instanceName = GetInstanceInfo()
            if instanceName and instanceName ~= "" then
                session.extra.instanceName = instanceName
            end
            self:SnapshotRoster()
        end
    else
        -- Left instance — finalize session if one was active
        if session then
            self:Finalize(C.ENCOUNTER_RESULT.UNKNOWN)
        end
    end
end

function EncounterHistory:MapInstanceType(instanceType)
    if instanceType == "party" then return C.ENCOUNTER_TYPE.DUNGEON end
    if instanceType == "raid" then return C.ENCOUNTER_TYPE.RAID end
    if instanceType == "arena" then
        local size = GetNumGroupMembers() or 0
        if size <= 2 then return C.ENCOUNTER_TYPE.ARENA_2V2 end
        return C.ENCOUNTER_TYPE.ARENA_3V3
    end
    if instanceType == "pvp" then return C.ENCOUNTER_TYPE.BATTLEGROUND end
    if instanceType == "scenario" then return C.ENCOUNTER_TYPE.SCENARIO end
    return C.ENCOUNTER_TYPE.DUNGEON
end

function EncounterHistory:ShouldAutoTrack()
    -- Only auto-track in dungeon-like content. Raids excluded by design
    -- (20+ players would clutter the list quickly). Arenas/BGs also out
    -- since they're transient and the matchmaking rarely repeats people.
    if not session then return false end
    if not ns.db.global.settings.autoTrackDungeonGroups then return false end
    return session.type == C.ENCOUNTER_TYPE.DUNGEON
        or session.type == C.ENCOUNTER_TYPE.MYTHIC_PLUS
end

-- Build a human-readable description of the current session:
--   "Magister's Terrace | +10"   (M+)
--   "Magister's Terrace"         (regular dungeon)
--   "Mythic+ +10"                (M+ where we couldn't resolve a name)
--   "dungeon"                    (fallback)
function EncounterHistory:BuildEncounterLabel()
    if not session then return "dungeon" end
    local name = session.extra and session.extra.instanceName
    local level = session.extra and session.extra.keyLevel
    local isMplus = session.type == C.ENCOUNTER_TYPE.MYTHIC_PLUS

    if name and level then
        return name .. " +" .. level
    elseif name and isMplus then
        return name .. " (M+)"
    elseif name then
        return name
    elseif level then
        return "Mythic+ +" .. level
    elseif isMplus then
        return "Mythic+"
    end
    return "dungeon"
end

function EncounterHistory:AutoTrackPlayer(unit, key, name, realm)
    -- Create-or-fetch the record. If the user already tracks this player
    -- (e.g. blacklisted, favorited), we don't touch their reputation —
    -- just log the encounter on their timeline.
    local rec, created = ns.Database:GetOrCreatePlayer(name .. "-" .. realm)
    if not rec then return end

    if created then
        rec.source = "auto_group"
        -- New auto-tracked records start neutral (the default), so no
        -- explicit reputation set needed.
    end

    -- Enrich while we have the unit token (class/race/faction/guid)
    if unit then
        ns.Database:EnrichFromUnit(rec, unit)
    end

    -- Append a timeline entry so the user remembers HOW this person ended
    -- up on the list. Only do it once per session to avoid spamming on
    -- roster updates.
    session.autoTracked = session.autoTracked or {}
    if not session.autoTracked[key] then
        session.autoTracked[key] = true
        ns.Timeline:Append(rec, "system",
            "Grouped with in " .. self:BuildEncounterLabel(),
            { encounterRef = nil })
    end

    ns.Database:Touch(rec)
end

function EncounterHistory:SnapshotRoster()
    if not session then return end
    if not IsInGroup() then return end
    local prefix = IsInRaid() and "raid" or "party"
    local size = GetNumGroupMembers() or 0
    local now = time()

    -- Include yourself
    local myKey = ns.PlayerUtils:KeyFromUnit("player")
    if myKey then
        session.roster[myKey] = session.roster[myKey] or { joined = now, isSelf = true }
    end

    local autoTrack = self:ShouldAutoTrack()
    local addedAny = false

    for i = 1, size do
        local unit = prefix .. i
        if UnitExists(unit) and UnitIsPlayer(unit) and not UnitIsUnit(unit, "player") then
            local key, name, realm = ns.PlayerUtils:KeyFromUnit(unit)
            if key and not session.roster[key] then
                session.roster[key] = { name = name, realm = realm, joined = now }
                addedAny = true
                if autoTrack then
                    self:AutoTrackPlayer(unit, key, name, realm)
                end
            end
        end
    end

    -- On dungeon entry the party units are sometimes not yet queryable
    -- (they exist on the server but UnitExists returns false locally for a
    -- short window after the loading screen). If we have a group but
    -- couldn't read anyone, retry shortly. Capped to a few attempts so
    -- it doesn't loop forever if the player really is solo.
    if size > 1 and not addedAny then
        session._snapshotRetries = (session._snapshotRetries or 0) + 1
        if session._snapshotRetries <= 5 then
            local sess = session  -- capture to avoid race if session changes
            C_Timer.After(1.5, function()
                -- Only retry if we're still in the SAME session
                if session == sess then
                    self:SnapshotRoster()
                end
            end)
        end
    end
end

function EncounterHistory:OnRosterUpdate()
    if not session then return end
    -- Re-snapshot to detect joiners
    local prefix = IsInRaid() and "raid" or "party"
    local size = GetNumGroupMembers() or 0
    local stillPresent = {}
    local now = time()

    -- Mark self
    local myKey = ns.PlayerUtils:KeyFromUnit("player")
    if myKey then stillPresent[myKey] = true end

    local autoTrack = self:ShouldAutoTrack()

    for i = 1, size do
        local unit = prefix .. i
        if UnitExists(unit) and UnitIsPlayer(unit) then
            local key, name, realm = ns.PlayerUtils:KeyFromUnit(unit)
            if key then
                stillPresent[key] = true
                if not session.roster[key] then
                    session.roster[key] = { name = name, realm = realm, joined = now }
                    table.insert(session.transitions, { ts = now, key = key, action = "joined" })
                    if autoTrack and not UnitIsUnit(unit, "player") then
                        self:AutoTrackPlayer(unit, key, name, realm)
                    end
                end
            end
        end
    end

    -- Detect leavers
    for key, info in pairs(session.roster) do
        if not info.left and not stillPresent[key] and not info.isSelf then
            info.left = now
            table.insert(session.transitions, { ts = now, key = key, action = "left" })
            -- Note on the player record (only if we already track them)
            local rec = ns.db.global.players[key]
            if rec then
                ns.Timeline:Append(rec, "detection", ns.L["Left group"],
                    { detection = C.DETECTION.LEFT_GROUP })
            end
        end
    end
end

function EncounterHistory:OnMythicPlusStart()
    if not session then
        session = newSession(C.ENCOUNTER_TYPE.MYTHIC_PLUS, {})
    end
    session.type = C.ENCOUNTER_TYPE.MYTHIC_PLUS
    -- Pull key info if API available
    local mapID, level
    if C_ChallengeMode then
        if C_ChallengeMode.GetActiveChallengeMapID then
            mapID = C_ChallengeMode.GetActiveChallengeMapID()
        end
        if C_ChallengeMode.GetActiveKeystoneInfo then
            -- Signature: level, affixes, wasCharged = GetActiveKeystoneInfo()
            -- We want the level (first return). The old code did
            -- `local _, lvl = ...` which discarded the level and grabbed the
            -- affixes table instead.
            local lvl = C_ChallengeMode.GetActiveKeystoneInfo()
            if type(lvl) == "number" then level = lvl end
        end
    end
    session.extra.mapID = mapID
    session.extra.keyLevel = level

    -- Resolve dungeon name. M+ has its own API; fall back to GetInstanceInfo
    -- which works for both M+ and regular dungeons.
    if mapID and C_ChallengeMode and C_ChallengeMode.GetMapUIInfo then
        local name = C_ChallengeMode.GetMapUIInfo(mapID)
        if name and name ~= "" then
            session.extra.instanceName = name
        end
    end
    if not session.extra.instanceName then
        local name = GetInstanceInfo()
        if name and name ~= "" then session.extra.instanceName = name end
    end

    -- Re-run the auto-track logic now that we know it's M+ (not "dungeon").
    -- The previous SnapshotRoster fired with type=DUNGEON before the keystone
    -- started; this catches that and rewrites the timeline entry for each
    -- player so it reflects the actual content.
    self:RestampAutoTracked()

    self:SnapshotRoster()
end

-- When the session upgrades from DUNGEON to MYTHIC_PLUS, the players we
-- auto-tracked on entry got a "Grouped with in <dungeon>" timeline entry.
-- Rewrite the most recent such entry per player to reflect the M+ context
-- (with key level + actual dungeon name).
function EncounterHistory:RestampAutoTracked()
    if not session or not session.autoTracked then return end
    local label = self:BuildEncounterLabel()
    for key in pairs(session.autoTracked) do
        local rec = ns.db.global.players[key]
        if rec and rec.timeline and #rec.timeline > 0 then
            -- Find the most recent "Grouped with" entry and update it
            for i = #rec.timeline, 1, -1 do
                local entry = rec.timeline[i]
                if entry.type == "system" and entry.text and entry.text:find("^Grouped with") then
                    entry.text = "Grouped with in " .. label
                    break
                end
            end
        end
    end
end

function EncounterHistory:OnMythicPlusComplete()
    if not session then return end
    -- CHALLENGE_MODE_COMPLETED args vary by patch; we just record completion
    -- and leave detailed timing to extra fields if available.
    if C_ChallengeMode and C_ChallengeMode.GetCompletionInfo then
        local mapID, level, time_ms, onTime = C_ChallengeMode.GetCompletionInfo()
        session.extra.timeMs = time_ms
        session.result = onTime and C.ENCOUNTER_RESULT.TIMED or C.ENCOUNTER_RESULT.DEPLETED
    else
        session.result = C.ENCOUNTER_RESULT.COMPLETED
    end
    self:Finalize(session.result)
end

function EncounterHistory:OnEncounterEnd(success)
    -- Used for raid bosses; we don't finalize the session, just track outcome
    if not session then return end
    if success == 0 then
        session.extra.lastWipe = time()
    end
end

function EncounterHistory:OnLeavingWorld()
    if session then self:Finalize(C.ENCOUNTER_RESULT.UNKNOWN) end
end

function EncounterHistory:Finalize(result)
    if not session then return end

    -- Convert roster -> participants list (only entries where someone was actually there)
    local participants = {}
    for key in pairs(session.roster) do
        if not session.roster[key].isSelf then
            table.insert(participants, key)
        end
    end

    -- Determine "left early" markers
    local leftEarly = {}
    for key, info in pairs(session.roster) do
        if info.left and not info.isSelf then
            leftEarly[key] = info.left
        end
    end

    local extra = session.extra
    extra.transitions = session.transitions
    extra.leftEarly = leftEarly
    extra.startTime = session.startTime
    extra.endTime = time()

    ns.Database:RecordEncounter(session.type, result or session.result, participants, extra)

    -- For each player who left early while session was running, append timeline note
    for key, leftAt in pairs(leftEarly) do
        local rec = ns.db.global.players[key]
        if rec and result and result ~= C.ENCOUNTER_RESULT.COMPLETED and result ~= C.ENCOUNTER_RESULT.TIMED then
            -- Only flag "key leaver" if they left during an M+ that didn't complete cleanly
            if session.type == C.ENCOUNTER_TYPE.MYTHIC_PLUS then
                ns.Database:ToggleTag(rec, "key_leaver")
            end
        end
    end

    session = nil
end

-- Format encounter for display
function EncounterHistory:FormatEncounter(enc)
    if not enc then return "" end
    local typeName = ns.L["Unknown"]
    for k, v in pairs(C.ENCOUNTER_TYPE) do
        if v == enc.type then typeName = ns.L[k:gsub("_", " "):gsub("(%a)(%w*)", function(a,b) return a:upper()..b:lower() end)] or k break end
    end
    local resultName = ns.L["Unknown"]
    for k, v in pairs(C.ENCOUNTER_RESULT) do
        if v == enc.result then
            -- Map enum keys (UNKNOWN/COMPLETED/TIMED/...) to localized strings
            local pretty = k:gsub("_", " "):lower():gsub("^%l", string.upper)
            resultName = ns.L[pretty] or pretty
            break
        end
    end
    local d = date("%Y-%m-%d", enc.timestamp)
    return string.format("[%s] %s - %s", d, typeName, resultName)
end
