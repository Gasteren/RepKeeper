-- Modules/GroupWarning.lua
-- When the user enters a group / raid / arena / BG, scan the roster and
-- show a single consolidated warning if any members are flagged.

local addonName, ns = ...
local C = ns.Constants

local GroupWarning = {}
ns.GroupWarning = GroupWarning

local Addon = ns.Addon
local lastCheckedKey  -- avoid spamming the popup on every roster blip

function GroupWarning:Initialize()
    if not ns.db.global.settings.groupWarningEnabled then return end
    Addon:RegisterEvent("GROUP_ROSTER_UPDATE", function() self:CheckGroup() end)
    Addon:RegisterEvent("GROUP_JOINED",        function() self:CheckGroup() end)
    Addon:RegisterEvent("PLAYER_ENTERING_BATTLEGROUND", function() self:CheckGroup() end)
end

function GroupWarning:CheckGroup()
    if not IsInGroup() then return end
    local settings = ns.db.global.settings
    if not settings.groupWarningEnabled then return end

    -- Determine context (party/raid/arena/bg)
    local _, instanceType = IsInInstance()
    local context = "party"
    if instanceType == "raid" then context = "raid"
    elseif instanceType == "arena" then context = "arena"
    elseif instanceType == "pvp" then context = "battleground" end

    if not settings.groupWarningContexts[context] then return end

    -- Build a stable key for this group composition
    local prefix = IsInRaid() and "raid" or "party"
    local size = GetNumGroupMembers() or 0
    local keys = {}
    local flagged = {}

    for i = 1, size do
        local unit = prefix .. i
        if UnitExists(unit) and UnitIsPlayer(unit) and not UnitIsUnit(unit, "player") then
            local key = ns.PlayerUtils:KeyFromUnit(unit)
            if key then
                table.insert(keys, key)
                local rec = ns.db.global.players[key]
                if rec and rec.reputation and rec.reputation <= settings.groupWarningMinRep then
                    table.insert(flagged, rec)
                    -- Enrich while we have the unit token
                    ns.Database:EnrichFromUnit(rec, unit)
                end
            end
        end
    end

    table.sort(keys)
    local groupKey = table.concat(keys, "|")
    if groupKey == lastCheckedKey then return end
    lastCheckedKey = groupKey

    if #flagged > 0 then
        self:ShowWarning(flagged)
        if settings.groupWarningSound then
            PlaySound(8959)  -- RaidWarning
        end
    end
end

-- The pop-ups themselves live in UI\Warnings.lua.
function GroupWarning:ShowWarning(flagged)
    if ns.UI and ns.UI.ShowGroupWarning then
        ns.UI.ShowGroupWarning(flagged)
    end
end

-- Fires when a blacklisted player sends an invite, regardless of whether
-- auto-decline is configured. Visible warning so the user notices even if
-- they would otherwise click through the PARTY_INVITE popup absent-mindedly.
function GroupWarning:ShowInviteWarning(rec)
    if ns.UI and ns.UI.ShowInviteWarning then
        ns.UI.ShowInviteWarning(rec)
    end
end
