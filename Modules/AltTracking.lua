-- Modules/AltTracking.lua
-- Listens for BNet/WoW friends list updates and party/raid roster changes
-- to auto-link characters that share a Battle.net account.
--
-- Caveat (worth knowing):
--   * Cross-realm party members reveal their BNet account ONLY if they're
--     on your friends list. There is no API to query arbitrary players.
--   * GetPlayerInfoByGUID does NOT return BNet info; it's for class/race only.
--   * BNAccountInfo returns one game account per call; characters share a
--     bnetAccountID, which is what we key on.

local addonName, ns = ...

local AltTracking = {}
ns.AltTracking = AltTracking

local Addon = ns.Addon
local DB = ns.Database

function AltTracking:Initialize()
    -- Initial scan after a short delay (BNet info isn't ready immediately)
    C_Timer.After(3, function() self:ScanBNetFriends() end)

    Addon:RegisterEvent("BN_FRIEND_INFO_CHANGED", function() self:ScanBNetFriends() end)
    Addon:RegisterEvent("BN_FRIEND_ACCOUNT_ONLINE", function() self:ScanBNetFriends() end)
    Addon:RegisterEvent("FRIENDLIST_UPDATE", function() self:ScanBNetFriends() end)
    Addon:RegisterEvent("GROUP_ROSTER_UPDATE", function() self:ScanGroupForBNet() end)
end

-- Walk the BNet friends list. For each WoW game account on each BNet friend,
-- if we already track that character, link it.
function AltTracking:ScanBNetFriends()
    if not BNGetNumFriends then return end
    local total = BNGetNumFriends()
    if not total or total == 0 then return end

    for i = 1, total do
        local accountInfo
        if C_BattleNet and C_BattleNet.GetFriendAccountInfo then
            accountInfo = C_BattleNet.GetFriendAccountInfo(i)
        end
        if accountInfo then
            local bnetID = accountInfo.bnetAccountID
            local battleTag = accountInfo.battleTag
            local gameAccounts = accountInfo.gameAccountInfo and { accountInfo.gameAccountInfo } or {}
            -- Some clients return multiple game accounts via a separate API
            if C_BattleNet.GetFriendNumGameAccounts then
                local numGames = C_BattleNet.GetFriendNumGameAccounts(i) or 0
                for g = 1, numGames do
                    local gi = C_BattleNet.GetFriendGameAccountInfo(i, g)
                    if gi then table.insert(gameAccounts, gi) end
                end
            end

            for _, ga in ipairs(gameAccounts) do
                if ga and ga.clientProgram == "WoW" and ga.characterName and ga.realmName then
                    local name = ga.characterName
                    local realm = ga.realmName:gsub("%s", "")
                    local key = (name:lower() .. "-" .. realm:lower())
                    local rec = ns.db.global.players[key]
                    if rec then
                        DB:LinkBNetAccount(rec, bnetID, battleTag)
                    end
                end
            end
        end
    end
end

-- When the group changes, see if any group members are BNet friends and
-- can therefore be alt-linked.
function AltTracking:ScanGroupForBNet()
    if not IsInGroup() then return end
    local prefix = IsInRaid() and "raid" or "party"
    local size = GetNumGroupMembers() or 0
    for i = 1, size do
        local unit = prefix .. i
        if UnitExists(unit) and UnitIsPlayer(unit) then
            -- Check if this unit is on the BNet friends list
            local bnetID = self:GetBNetAccountForUnit(unit)
            if bnetID then
                local key = ns.PlayerUtils:KeyFromUnit(unit)
                local rec = key and ns.db.global.players[key]
                if rec then
                    -- Find the battleTag matching this bnetID
                    local tag = self:BattleTagForBNetID(bnetID)
                    DB:LinkBNetAccount(rec, bnetID, tag)
                end
            end
        end
    end
end

function AltTracking:GetBNetAccountForUnit(unit)
    -- BNGetGameAccountInfoByGUID was deprecated; we have to walk friends
    if not C_BattleNet or not BNGetNumFriends then return nil end
    local guid = UnitGUID(unit)
    if not guid then return nil end
    local total = BNGetNumFriends()
    for i = 1, (total or 0) do
        if C_BattleNet.GetFriendNumGameAccounts then
            local numGames = C_BattleNet.GetFriendNumGameAccounts(i) or 0
            for g = 1, numGames do
                local gi = C_BattleNet.GetFriendGameAccountInfo(i, g)
                if gi and gi.playerGuid == guid then
                    local acc = C_BattleNet.GetFriendAccountInfo(i)
                    return acc and acc.bnetAccountID
                end
            end
        end
    end
    return nil
end

function AltTracking:BattleTagForBNetID(bnetID)
    if not BNGetNumFriends or not C_BattleNet then return nil end
    local total = BNGetNumFriends() or 0
    for i = 1, total do
        local acc = C_BattleNet.GetFriendAccountInfo(i)
        if acc and acc.bnetAccountID == bnetID then
            return acc.battleTag
        end
    end
    return nil
end
