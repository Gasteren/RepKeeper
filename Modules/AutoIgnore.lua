-- Modules/AutoIgnore.lua
-- Optional automation for blacklisted players:
--   * Auto /ignore when reputation <= autoIgnoreThreshold
--   * Auto-decline group invites
--   * Auto-decline guild invites
--   * Auto-decline duels
--   * Auto-decline trades (off by default — too easy to backfire)

local addonName, ns = ...
local C = ns.Constants

local AutoIgnore = {}
ns.AutoIgnore = AutoIgnore

local Addon = ns.Addon

function AutoIgnore:Initialize()
    Addon:RegisterEvent("PARTY_INVITE_REQUEST", function(_, name) self:OnGroupInvite(name) end)
    Addon:RegisterEvent("GUILD_INVITE_REQUEST", function(_, _, guildName, _, _, _, inviter) self:OnGuildInvite(inviter) end)
    Addon:RegisterEvent("DUEL_REQUESTED", function(_, name) self:OnDuelRequest(name) end)
    Addon:RegisterEvent("TRADE_SHOW", function() self:OnTradeShow() end)

    -- Sync ignores when reputation drops below threshold
    ns.Database.RegisterCallback(self, "OnPlayerChanged", "OnPlayerChanged")
    ns.Database.RegisterCallback(self, "OnPlayerAdded", "OnPlayerChanged")
end

function AutoIgnore:ShouldAutoAct(rec)
    return rec and rec.reputation and rec.reputation <= ns.db.global.settings.autoIgnoreThreshold
end

function AutoIgnore:OnPlayerChanged(_, rec)
    if not ns.db.global.settings.autoIgnoreEnabled then return end
    if not self:ShouldAutoAct(rec) then return end
    -- AddOrDelIgnore is safe to call even if already ignored (it's a toggle for
    -- the slash command, but C_FriendList.AddIgnore is idempotent-ish — it
    -- prints a "already on ignore list" if already there)
    if C_FriendList and C_FriendList.AddIgnore then
        local target = rec.name .. "-" .. rec.realm
        -- Only attempt if not already on ignore (avoid spam)
        if not C_FriendList.IsIgnored(target) and not C_FriendList.IsIgnoredByGuid and true then
            C_FriendList.AddIgnore(target)
        end
    end
end

function AutoIgnore:OnGroupInvite(name)
    local key = ns.PlayerUtils:KeyFromSender(name)
    local rec = key and ns.db.global.players[key]
    if not rec then return end

    -- Visible warning fires regardless of auto-decline setting. We always
    -- want the user to KNOW a blacklisted person tried to group with them;
    -- the auto-decline is a separate behavior on top of that.
    if rec.reputation == C.REP.BLACKLIST or (rec.tags and next(rec.tags) ~= nil) then
        if rec.reputation == C.REP.BLACKLIST then
            ns.GroupWarning:ShowInviteWarning(rec)
        end
    end

    -- Auto-decline if enabled
    if not ns.db.global.settings.autoDeclineGroupInvites then return end
    if self:ShouldAutoAct(rec) then
        DeclineGroup()
        StaticPopup_Hide("PARTY_INVITE")
        ns.Addon:Printf("Auto-declined group invite from %s (%s)",
            name, ns.Reputation:WarningReason(rec))
    end
end

function AutoIgnore:OnGuildInvite(inviter)
    if not ns.db.global.settings.autoDeclineGuildInvites then return end
    local key = ns.PlayerUtils:KeyFromSender(inviter)
    local rec = key and ns.db.global.players[key]
    if rec and self:ShouldAutoAct(rec) then
        DeclineGuild()
        StaticPopup_Hide("GUILD_INVITE")
        ns.Addon:Printf("Auto-declined guild invite from %s", inviter)
    end
end

function AutoIgnore:OnDuelRequest(name)
    if not ns.db.global.settings.autoDeclineDuels then return end
    local key = ns.PlayerUtils:KeyFromSender(name)
    local rec = key and ns.db.global.players[key]
    if rec and self:ShouldAutoAct(rec) then
        CancelDuel()
        StaticPopup_Hide("DUEL_REQUESTED")
    end
end

function AutoIgnore:OnTradeShow()
    if not ns.db.global.settings.autoDeclineTrades then return end
    if not UnitExists("NPC") or not UnitIsPlayer("NPC") then return end
    local key = ns.PlayerUtils:KeyFromUnit("NPC")
    local rec = key and ns.db.global.players[key]
    if rec and self:ShouldAutoAct(rec) then
        CloseTrade()
        ns.Addon:Printf("Auto-closed trade with %s", rec.name)
    end
end
