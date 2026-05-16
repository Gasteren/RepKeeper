-- Modules/Detection.lua
-- Listens for behaviors that should prompt the user with a quick-add popup:
--   * Player leaving the group (PARTY_MEMBER_DISABLE / GROUP_ROSTER_UPDATE)
--   * Vote-kick succeeded
--   * Trade requests above threshold from same source
--   * Duel requests above threshold from same source
--   * Whisper messages above threshold from same source
--
-- Fires UI:Show(rec, reason) on the QuickAdd module.

local addonName, ns = ...
local C = ns.Constants

local Detection = {}
ns.Detection = Detection

local Addon = ns.Addon

-- Tracks transient counts: spamTracking[key] = { trade={count, firstTs}, duel={...}, whisper={...} }
-- Stored in DB so a relog doesn't reset legitimate suspicion, but pruned on init.
local spamTracking

-- Per-session deduplication: don't pop the same player twice for the same reason
local sessionShown = {}
-- Per-session "don't show again" toggle
local sessionMuted = false

function Detection:Initialize()
    if not ns.db.global.settings.detectionEnabled then return end

    spamTracking = ns.db.global.spamTracking or {}
    ns.db.global.spamTracking = spamTracking
    self:PruneSpamTracking()

    if ns.db.global.settings.detectVoteKicks then
        -- Vote kick result is hard to observe directly; we infer from
        -- the localized system message in CHAT_MSG_SYSTEM (ERR_VOTE_KICK_PLAYER_S)
        Addon:RegisterEvent("CHAT_MSG_SYSTEM", function(_, msg) self:OnSystemMessage(msg) end)
    end

    if ns.db.global.settings.detectLeavers then
        Addon:RegisterEvent("GROUP_ROSTER_UPDATE", function() self:OnRosterUpdate() end)
    end

    if ns.db.global.settings.detectTradeSpam then
        Addon:RegisterEvent("TRADE_SHOW", function() self:OnTradeShow() end)
        Addon:RegisterEvent("TRADE_REQUEST", function(_, name) self:OnTradeRequest(name) end)
    end

    if ns.db.global.settings.detectDuelSpam then
        Addon:RegisterEvent("DUEL_REQUESTED", function(_, name) self:OnDuelRequested(name) end)
    end

    if ns.db.global.settings.detectWhisperSpam then
        Addon:RegisterEvent("CHAT_MSG_WHISPER", function(_, _, sender) self:OnWhisper(sender) end)
    end
end

-- Prune entries with stale firstTs to keep SavedVariables small
function Detection:PruneSpamTracking()
    local now = time()
    local maxAge = 86400 -- 24h
    for key, data in pairs(spamTracking) do
        local keep = false
        for _, kind in ipairs({ "trade", "duel", "whisper" }) do
            if data[kind] and (now - (data[kind].firstTs or 0)) < maxAge then
                keep = true
            else
                data[kind] = nil
            end
        end
        if not keep then spamTracking[key] = nil end
    end
end

local function bumpCounter(key, kind, window)
    spamTracking[key] = spamTracking[key] or {}
    local d = spamTracking[key][kind]
    local now = time()
    if not d or (now - d.firstTs) > window then
        d = { count = 1, firstTs = now }
    else
        d.count = d.count + 1
    end
    spamTracking[key][kind] = d
    return d
end

-- ==========================================================================
-- Roster: detect leavers (only flag if YOU are still in the group)
-- ==========================================================================

local lastRoster = {}

function Detection:OnRosterUpdate()
    local current = {}
    if IsInGroup() then
        local prefix = IsInRaid() and "raid" or "party"
        local size = GetNumGroupMembers() or 0
        for i = 1, size do
            local unit = prefix .. i
            if UnitExists(unit) and UnitIsPlayer(unit) and not UnitIsUnit(unit, "player") then
                local key, name, realm = ns.PlayerUtils:KeyFromUnit(unit)
                if key then current[key] = { name = name, realm = realm } end
            end
        end
    end

    -- Anyone in lastRoster but not current = left (or got kicked)
    for key, info in pairs(lastRoster) do
        if not current[key] then
            -- We don't know yet whether this was a kick or a leave; the
            -- system message handler may upgrade it.
            self:OnPlayerLeftGroup(key, info)
        end
    end
    lastRoster = current
end

function Detection:OnPlayerLeftGroup(key, info)
    -- Offer quick-add only if the user is still in a group (i.e. someone else left)
    -- and we're not soloing
    if not IsInGroup() then return end

    -- Get or create record minimally so we can attach a timeline note even if
    -- the user dismisses the popup
    local rec, _ = ns.Database:GetOrCreatePlayer(info.name .. "-" .. info.realm)
    if rec then
        ns.Timeline:Append(rec, "detection", ns.L["Left group"],
            { detection = C.DETECTION.LEFT_GROUP })
        rec.source = rec.source ~= "manual" and "detection" or rec.source
    end

    self:OfferQuickAdd(rec, "left")
end

function Detection:OnSystemMessage(msg)
    if not msg then return end
    -- Localized; we match by the global string pattern
    -- ERR_VOTE_KICK_PLAYER_S, etc. are the canonical strings.
    -- We use ERR_VOTE_FAILED, ERR_RAID_REMOVED_FROM_GROUP, etc.
    -- For simplicity we look for a name match in the message.
    if ERR_VOTE_KICK_PLAYER_S then
        local pattern = ERR_VOTE_KICK_PLAYER_S:gsub("%%s", "(.+)")
        local victim = msg:match("^" .. pattern .. "$")
        if victim then
            -- ERR_VOTE_KICK_PLAYER_S typically reads "<name> has left the instance group."
            local key = ns.Database:NormalizeKey(victim)
            local rec = key and ns.db.global.players[key]
            if rec then
                ns.Timeline:Append(rec, "detection", ns.L["Vote-kicked from group"],
                    { detection = C.DETECTION.VOTE_KICKED })
            end
            -- Don't pop a quick-add for kicks — the user just voted, they know
        end
    end
end

-- ==========================================================================
-- Trade spam
-- ==========================================================================

local lastTradeTarget = nil

function Detection:OnTradeShow()
    -- TRADE_SHOW means the trade window opened. The unit is "NPC" (target).
    local name = UnitName("NPC")
    if name and UnitIsPlayer("NPC") then
        local realm = select(2, UnitName("NPC"))
        if not realm or realm == "" then
            realm = GetNormalizedRealmName and GetNormalizedRealmName() or GetRealmName()
        end
        lastTradeTarget = name .. "-" .. (realm or ""):gsub("%s", "")
        self:RegisterSpamHit(lastTradeTarget, "trade")
    end
end

function Detection:OnTradeRequest(name)
    -- Some clients pass the requester name directly
    if name then self:RegisterSpamHit(name, "trade") end
end

function Detection:OnDuelRequested(name)
    if name then self:RegisterSpamHit(name, "duel") end
end

function Detection:OnWhisper(sender)
    if sender then self:RegisterSpamHit(sender, "whisper") end
end

function Detection:RegisterSpamHit(senderRaw, kind)
    local key = ns.PlayerUtils:KeyFromSender(senderRaw)
    if not key then return end

    local settings = ns.db.global.settings
    local threshold, window
    if kind == "trade" then
        threshold, window = settings.tradeSpamThreshold, settings.tradeSpamWindow
    elseif kind == "duel" then
        threshold, window = settings.duelSpamThreshold, settings.duelSpamWindow
    else
        threshold, window = settings.whisperSpamThreshold, settings.whisperSpamWindow
    end

    local d = bumpCounter(key, kind, window)
    if d.count >= threshold then
        local rec, _ = ns.Database:GetOrCreatePlayer(senderRaw)
        if rec then
            local detectionCode = (kind == "trade") and C.DETECTION.TRADE_SPAM
                                or (kind == "duel") and C.DETECTION.DUEL_SPAM
                                or C.DETECTION.WHISPER_SPAM
            local pattern = (kind == "trade") and ns.L["Trade spam (%d requests in %ds)"]
                          or (kind == "duel") and ns.L["Duel spam (%d requests in %ds)"]
                          or ns.L["Whisper spam (%d msgs in %ds)"]
            ns.Timeline:Append(rec, "detection",
                string.format(pattern, d.count, time() - d.firstTs),
                { detection = detectionCode })
            -- Auto-tag spammer
            ns.Database:ToggleTag(rec, "spammer")
        end
        self:OfferQuickAdd(rec, kind)
        -- Reset counter so we don't pop again immediately
        d.count = 0
        d.firstTs = time()
    end
end

-- ==========================================================================
-- Quick-add popup gateway
-- ==========================================================================

function Detection:OfferQuickAdd(rec, reason)
    if sessionMuted then return end
    if not ns.db.global.settings.quickAddPopupEnabled then return end
    if not rec then return end
    local key = rec.normalizedKey .. ":" .. tostring(reason)
    if sessionShown[key] then return end
    sessionShown[key] = true

    if ns.QuickAdd and ns.QuickAdd.Show then
        ns.QuickAdd:Show(rec, reason)
    end
end

function Detection:MuteSession()
    sessionMuted = true
end
