-- Modules/RightClickMenu.lua
-- Adds RepKeeper actions to the right-click player menu.
--
-- Midnight (12.0) uses the new Menu API (UI.OpenContextMenu / Menu.ModifyMenu).
-- Earlier patches used UnitPopupButtons + UnitPopup_ShowMenu hooks.
-- We feature-detect both. The new API is preferred where available.

local addonName, ns = ...
local C = ns.Constants

local RightClickMenu = {}
ns.RightClickMenu = RightClickMenu

local Addon = ns.Addon

-- Menu types where we inject our submenu. The Menu.ModifyMenu API is
-- explicitly taint-safe for adding entries: each entry's handler runs in
-- its own isolated execution context, so we can mutate database/UI state
-- from the click callbacks without poisoning the surrounding menu.
--
-- We deliberately avoid:
--   * MENU_UNIT_SELF   — your own portrait. No reason to right-click-self
--                        for RepKeeper actions.
--   * MENU_UNIT_TARGET / MENU_UNIT_FOCUS — covered indirectly via PLAYER
--                        when the target/focus IS another player; injecting
--                        into these separately would create duplicates.
local TARGET_MENUS = {
    "MENU_UNIT_PLAYER",                       -- open-world players you click
    "MENU_UNIT_PARTY",                        -- party member portraits
    "MENU_UNIT_RAID_PLAYER",                  -- raid frame entries
    "MENU_UNIT_FRIEND",                       -- friends list
    "MENU_UNIT_BN_FRIEND",                    -- battle.net friends
    "MENU_UNIT_COMMUNITIES_GUILD_MEMBER",     -- guild roster
    "MENU_UNIT_COMMUNITIES_MEMBER",           -- communities list
    "MENU_UNIT_ENEMY_PLAYER",                 -- PvP targets
    "MENU_UNIT_CHAT_ROSTER",                  -- chat name right-click
}

function RightClickMenu:Initialize()
    if Menu and Menu.ModifyMenu then
        for _, menuName in ipairs(TARGET_MENUS) do
            Menu.ModifyMenu(menuName, function(_, root, contextData)
                self:BuildMenuModern(root, contextData)
            end)
        end
    end
    -- No legacy fallback. We target Midnight (12.0+) only; older clients
    -- silently lack the right-click integration but the rest of the addon
    -- works.
end

-- ==========================================================================
-- Modern Menu API (Midnight)
-- ==========================================================================

function RightClickMenu:GetTargetFromContext(contextData)
    if not contextData then return nil, nil end
    -- contextData typically has .name, .server, .unit, .accountInfo
    local name = contextData.name
    local server = contextData.server
    local unit = contextData.unit
    if unit and UnitExists(unit) and UnitIsPlayer(unit) then
        local key, n, r = ns.PlayerUtils:KeyFromUnit(unit)
        return key, (n or name), (r or server)
    end
    if name and name ~= "" then
        if not server or server == "" then
            server = GetNormalizedRealmName and GetNormalizedRealmName() or GetRealmName()
        end
        local key = ns.Database:NormalizeKey(name .. "-" .. (server or ""))
        return key, name, server
    end
    return nil, nil
end

function RightClickMenu:BuildMenuModern(root, contextData)
    local key, name, server = self:GetTargetFromContext(contextData)
    if not key or not name then return end
    if name:lower() == (UnitName("player") or ""):lower() then
        -- Don't show the menu on the player's own name
        return
    end

    local rec = ns.db.global.players[key]
    local function ensureRec()
        return rec or select(1, ns.Database:GetOrCreatePlayer(name .. "-" .. (server or "")))
    end

    root:CreateDivider()
    local sub = root:CreateButton(ns.L["RepKeeper"])

    -- Reputation actions. Mirror the row-right-click menu layout so users
    -- have one mental model: three rep buttons, current dimmed (here we
    -- just omit the no-op current state to keep the menu shorter).
    local currentRep = rec and rec.reputation or 0
    if currentRep ~= C.REP.BLACKLIST then
        sub:CreateButton("|cffff5555Set Blacklist|r", function()
            local r = ensureRec(); if r then
                ns.Reputation:Set(r, C.REP.BLACKLIST)
                if ns.MainFrame then ns.MainFrame:Refresh() end
            end
        end)
    end
    if currentRep ~= C.REP.NEUTRAL then
        sub:CreateButton("|cffcccccc Set Neutral|r", function()
            local r = ensureRec(); if r then
                ns.Reputation:Set(r, C.REP.NEUTRAL)
                if ns.MainFrame then ns.MainFrame:Refresh() end
            end
        end)
    end
    if currentRep ~= C.REP.POSITIVE then
        sub:CreateButton("|cff88ff88Set Positive|r", function()
            local r = ensureRec(); if r then
                ns.Reputation:Set(r, C.REP.POSITIVE)
                if ns.MainFrame then ns.MainFrame:Refresh() end
            end
        end)
    end

    sub:CreateDivider()

    sub:CreateButton(ns.L["RepKeeper: View Profile"], function()
        local r = ensureRec(); if r and ns.PlayerEditor then ns.PlayerEditor:Open(r) end
    end)
    sub:CreateButton(ns.L["RepKeeper: Add Note..."], function()
        local r = ensureRec(); if r and ns.PlayerEditor then ns.PlayerEditor:Open(r, { focus = "note" }) end
    end)
end

-- Legacy UnitPopup fallback was removed: it used SecureHook on
-- UnitPopup_OnClick which can taint frames sharing the secure dropdown
-- system. We only target Midnight (12.0) which uses the modern Menu API,
-- so the fallback was unreachable code.
