-- Modules/GuildSync.lua
-- Optional peer-to-peer sync of player records over the GUILD AceComm channel.
--
-- Design principles:
--   * Opt-in. Disabled by default.
--   * Trust-tiered: imports from peers can be (0) ignored, (1) shown as
--     suggestions in the UI requiring manual approval, (2) auto-merged.
--     Default is (1).
--   * Only sync configured fields: blacklist entries, favorites, optionally
--     notes. Encounter history is NEVER synced (privacy + bandwidth).
--   * Bandwidth-bounded. We send heartbeats announcing our latest update
--     timestamp; peers request deltas since their last seen. Full state is
--     only sent on first contact.
--   * Anti-abuse:
--       - Min guild rank gate (default GM only)
--       - Per-peer rate limit (max N messages per minute)
--       - Suggested entries are tagged with sourcePeer so user sees who
--         vouched for them
--       - Mass-remove protection: peer "REMOVE" deltas are SUGGESTIONS, never
--         silently delete local entries

local addonName, ns = ...
local C = ns.Constants

local GuildSync = {}
ns.GuildSync = GuildSync

local Addon = ns.Addon
local AceSerializer = LibStub("AceSerializer-3.0")
local LibDeflate = LibStub("LibDeflate")

local PROTO = C.PROTOCOL_VERSION
local PREFIX = C.COMM_PREFIX

-- Message types
local MSG = {
    HELLO    = "H",   -- announce presence + latest state hash
    REQUEST  = "R",   -- request deltas since timestamp
    DELTA    = "D",   -- payload: list of player records
    REMOVE   = "X",   -- suggestion to remove (NOT an order)
}

-- Per-peer rate limiting
local peerWindow = 60   -- seconds
local peerMaxMsgs = 30  -- messages per window per peer
local peerCounts = {}   -- [sender] = { count = N, windowStart = ts }

-- Pending suggestions awaiting user approval (when trustLevel == 1)
GuildSync.pendingSuggestions = GuildSync.pendingSuggestions or {}

function GuildSync:Initialize()
    if not ns.db.global.settings.guildSyncEnabled then
        -- Still register prefix so we can receive when re-enabled mid-session
        Addon:RegisterComm(PREFIX, function(...) self:OnCommReceived(...) end)
        return
    end
    Addon:RegisterComm(PREFIX, function(...) self:OnCommReceived(...) end)

    -- Send a hello after a short startup delay
    C_Timer.After(8, function() self:SendHello() end)

    -- Periodic heartbeat (every 10 minutes)
    Addon:ScheduleRepeatingTimer(function() self:SendHello() end, 600)
end

-- ==========================================================================
-- Trust gate
-- ==========================================================================

function GuildSync:CanTrustPeer(sender)
    if not IsInGuild() then return false end
    if not sender or sender == "" then return false end

    -- Check rate limit
    local now = time()
    local pc = peerCounts[sender]
    if not pc or (now - pc.windowStart) > peerWindow then
        pc = { count = 0, windowStart = now }
    end
    pc.count = pc.count + 1
    peerCounts[sender] = pc
    if pc.count > peerMaxMsgs then return false end

    -- Check guild rank if configured (lower rank index = higher rank in WoW)
    local minRank = ns.db.global.settings.guildSyncMinRank or 0
    -- Walk roster to find the sender's rank
    local numMembers = GetNumGuildMembers and GetNumGuildMembers() or 0
    for i = 1, numMembers do
        local fullName, _, rankIndex = GetGuildRosterInfo(i)
        if fullName and self:NormalizeForGuildRoster(fullName) == self:NormalizeForGuildRoster(sender) then
            return rankIndex <= minRank
        end
    end
    return false
end

function GuildSync:NormalizeForGuildRoster(name)
    if not name then return nil end
    if not name:find("-") then
        local realm = GetNormalizedRealmName and GetNormalizedRealmName() or GetRealmName()
        name = name .. "-" .. (realm or ""):gsub("%s", "")
    end
    return name:lower():gsub("%s", "")
end

-- ==========================================================================
-- Wire encoding
-- ==========================================================================

function GuildSync:Encode(msgType, payload)
    local envelope = { v = PROTO, t = msgType, p = payload, ts = time() }
    local serialized = AceSerializer:Serialize(envelope)
    local compressed = LibDeflate:CompressDeflate(serialized, { level = 6 })
    return LibDeflate:EncodeForWoWAddonChannel(compressed)
end

function GuildSync:Decode(data)
    if not data or data == "" then return nil end
    local compressed = LibDeflate:DecodeForWoWAddonChannel(data)
    if not compressed then return nil end
    local serialized = LibDeflate:DecompressDeflate(compressed)
    if not serialized then return nil end
    local ok, envelope = AceSerializer:Deserialize(serialized)
    if not ok then return nil end
    return envelope
end

-- ==========================================================================
-- Sending
-- ==========================================================================

function GuildSync:Send(msgType, payload)
    if not IsInGuild() then return end
    local data = self:Encode(msgType, payload)
    -- AceComm chunks automatically; "BULK" priority avoids stepping on chat
    Addon:SendCommMessage(PREFIX, data, "GUILD", nil, "BULK")
end

function GuildSync:SendHello()
    if not IsInGuild() then return end
    if not ns.db.global.settings.guildSyncEnabled then return end
    self:Send(MSG.HELLO, {
        latestUpdate = self:GetLatestUpdateTime(),
    })
end

function GuildSync:SendDeltaSince(target, sinceTs)
    if not ns.db.global.settings.guildSyncEnabled then return end
    local list = self:CollectDeltas(sinceTs)
    if #list == 0 then return end
    self:Send(MSG.DELTA, { since = sinceTs, players = list })
end

function GuildSync:GetLatestUpdateTime()
    local latest = 0
    for _, rec in pairs(ns.db.global.players) do
        if rec.lastSeen and rec.lastSeen > latest then latest = rec.lastSeen end
    end
    return latest
end

function GuildSync:CollectDeltas(sinceTs)
    sinceTs = sinceTs or 0
    local s = ns.db.global.settings
    local list = {}
    for _, rec in pairs(ns.db.global.players) do
        local include = false
        if rec.reputation and rec.reputation <= C.REP.BLACKLIST and s.guildSyncShareBlacklist then
            include = true
        elseif rec.reputation and rec.reputation >= C.REP.FAVORITE and s.guildSyncShareFavorites then
            include = true
        end
        if include and (rec.lastSeen or 0) > sinceTs then
            local lite = {
                name = rec.name,
                realm = rec.realm,
                reputation = rec.reputation,
                tags = (function()
                    local t = {}
                    for tagID in pairs(rec.tags or {}) do t[#t + 1] = tagID end
                    return t
                end)(),
                ts = rec.lastSeen,
            }
            if s.guildSyncShareNotes then
                lite.notes = rec.notes
            end
            list[#list + 1] = lite
        end
    end
    return list
end

-- ==========================================================================
-- Receiving
-- ==========================================================================

function GuildSync:OnCommReceived(prefix, data, channel, sender)
    if prefix ~= PREFIX then return end
    if channel ~= "GUILD" then return end  -- only accept guild channel
    if not ns.db.global.settings.guildSyncEnabled then return end
    if not self:CanTrustPeer(sender) then return end

    local envelope = self:Decode(data)
    if not envelope or envelope.v ~= PROTO then return end

    if envelope.t == MSG.HELLO then
        self:OnHello(sender, envelope.p)
    elseif envelope.t == MSG.REQUEST then
        self:OnRequest(sender, envelope.p)
    elseif envelope.t == MSG.DELTA then
        self:OnDelta(sender, envelope.p)
    end
end

function GuildSync:OnHello(sender, payload)
    -- Peer announced their latest. If they have newer than us, request deltas.
    local theirLatest = payload and payload.latestUpdate or 0
    -- Whisper a REQUEST back for entries since our last sync from this peer
    -- Track per-peer last-seen-from in transient state
    self.lastSeenFrom = self.lastSeenFrom or {}
    local since = self.lastSeenFrom[sender] or 0
    if theirLatest > since then
        Addon:SendCommMessage(PREFIX,
            self:Encode(MSG.REQUEST, { since = since }),
            "WHISPER", sender, "BULK")
    end
end

function GuildSync:OnRequest(sender, payload)
    local since = payload and payload.since or 0
    local list = self:CollectDeltas(since)
    if #list == 0 then return end
    Addon:SendCommMessage(PREFIX,
        self:Encode(MSG.DELTA, { since = since, players = list }),
        "WHISPER", sender, "BULK")
end

function GuildSync:OnDelta(sender, payload)
    if not payload or not payload.players then return end
    self.lastSeenFrom = self.lastSeenFrom or {}
    self.lastSeenFrom[sender] = time()

    local trustLevel = ns.db.global.settings.guildSyncTrustLevel or 1

    for _, p in ipairs(payload.players) do
        if p.name and p.realm then
            local key = (p.name:lower() .. "-" .. p.realm:lower())
            if trustLevel >= 2 then
                -- Auto-merge: same rules as ImportExport, but tagged with sourcePeer
                self:AutoMerge(p, sender)
            else
                -- Suggestion: add to pending list, surface in UI
                self:AddSuggestion(key, p, sender)
            end
        end
    end

    if ns.MainFrame and ns.MainFrame.Refresh then ns.MainFrame:Refresh() end
end

function GuildSync:AutoMerge(p, sender)
    local existing = ns.db.global.players[(p.name:lower() .. "-" .. p.realm:lower())]
    if not existing then
        local rec = select(1, ns.Database:GetOrCreatePlayer(p.name .. "-" .. p.realm))
        if rec then
            rec.reputation = p.reputation or C.REP.NEUTRAL
            for _, tagID in ipairs(p.tags or {}) do rec.tags[tagID] = true end
            if p.notes then rec.notes = p.notes end
            rec.source = "guildsync"
            rec.sourcePeer = sender
            ns.Timeline:Append(rec, "system",
                string.format(ns.L["Suggested by %s"], sender), { sourcePeer = sender })
        end
    else
        -- Same merge as Import: tags union, only adopt more-negative rep
        for _, tagID in ipairs(p.tags or {}) do existing.tags[tagID] = true end
        if (p.reputation or 0) < (existing.reputation or 0) then
            existing.reputation = p.reputation
        end
        if p.notes and (not existing.notes or existing.notes == "") then
            existing.notes = p.notes
        end
        ns.Database:Touch(existing)
    end
end

function GuildSync:AddSuggestion(key, p, sender)
    self.pendingSuggestions[key] = self.pendingSuggestions[key] or {}
    -- Dedup by sender — one suggestion per peer per player
    self.pendingSuggestions[key][sender] = {
        name = p.name, realm = p.realm,
        reputation = p.reputation, tags = p.tags, notes = p.notes,
        receivedAt = time(),
    }
end

function GuildSync:AcceptSuggestion(key, sender)
    local suggestions = self.pendingSuggestions[key]
    if not suggestions or not suggestions[sender] then return end
    local p = suggestions[sender]
    self:AutoMerge(p, sender)
    self.pendingSuggestions[key] = nil
end

function GuildSync:DeclineSuggestion(key, sender)
    if self.pendingSuggestions[key] then
        self.pendingSuggestions[key][sender] = nil
        if not next(self.pendingSuggestions[key]) then
            self.pendingSuggestions[key] = nil
        end
    end
end

function GuildSync:CountPending()
    local n = 0
    for _ in pairs(self.pendingSuggestions or {}) do n = n + 1 end
    return n
end
