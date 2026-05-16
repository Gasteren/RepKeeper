-- Modules/GroupWarning.lua
-- When the user enters a group / raid / arena / BG, scan the roster and
-- show a single consolidated warning if any members are flagged.

local addonName, ns = ...
local C = ns.Constants

local GroupWarning = {}
ns.GroupWarning = GroupWarning

local Addon = ns.Addon
local frame  -- lazy-built popup frame
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

function GroupWarning:BuildFrame()
    if frame then return frame end

    frame = CreateFrame("Frame", "RepKeeperGroupWarning", UIParent, "BackdropTemplate")
    frame:SetSize(420, 180)
    frame:SetPoint("TOP", UIParent, "TOP", 0, -120)
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)
    frame:Hide()

    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = false, edgeSize = 14,
            insets   = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        frame:SetBackdropColor(0.10, 0.04, 0.04, 0.96)
        frame:SetBackdropBorderColor(0.7, 0.3, 0.3, 1)
    end

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -16)
    title:SetText("|cffff5555" .. ns.L["RepKeeper Warning"] .. "|r")
    frame.title = title

    local body = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    body:SetPoint("TOPLEFT", 20, -48)
    body:SetPoint("TOPRIGHT", -20, -48)
    body:SetJustifyH("LEFT")
    body:SetJustifyV("TOP")
    frame.body = body

    local viewBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    viewBtn:SetSize(110, 22)
    viewBtn:SetPoint("BOTTOMLEFT", 20, 16)
    viewBtn:SetText(ns.L["View Details"])
    viewBtn:SetScript("OnClick", function()
        if ns.MainFrame then ns.MainFrame:Show() end
        frame:Hide()
    end)

    local dismissBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    dismissBtn:SetSize(90, 22)
    dismissBtn:SetPoint("BOTTOMRIGHT", -20, 16)
    dismissBtn:SetText(ns.L["Dismiss"])
    dismissBtn:SetScript("OnClick", function() frame:Hide() end)

    local leaveBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    leaveBtn:SetSize(110, 22)
    leaveBtn:SetPoint("BOTTOM", 0, 16)
    leaveBtn:SetText(ns.L["Leave Group"])
    leaveBtn:SetScript("OnClick", function()
        LeaveParty()
        frame:Hide()
    end)

    return frame
end

function GroupWarning:ShowWarning(flagged)
    self:BuildFrame()
    local lines = {}
    if #flagged == 1 then
        local rec = flagged[1]
        local reason = ns.Reputation:WarningReason(rec)
        table.insert(lines, string.format(ns.L["%s in your group is %s"],
            ns.PlayerUtils:DisplayName(rec, { colorize = true, includeRealm = true }),
            "|cffff8888" .. reason .. "|r"))
    else
        table.insert(lines, "|cffff8888" .. string.format(ns.L["%d players in your group are flagged"], #flagged) .. "|r")
        for _, rec in ipairs(flagged) do
            table.insert(lines, "  * " ..
                ns.PlayerUtils:DisplayName(rec, { colorize = true, includeRealm = true }) ..
                " - " .. ns.Reputation:WarningReason(rec))
        end
    end
    frame.body:SetText(table.concat(lines, "\n"))
    frame:Show()
    frame:SetHeight(80 + #lines * 16)
end

-- Fires when a blacklisted player sends an invite, regardless of whether
-- auto-decline is configured. Visible toast so the user notices even if
-- they would otherwise click through the PARTY_INVITE popup absent-mindedly.
function GroupWarning:ShowInviteWarning(rec)
    self:BuildFrame()
    local reason = ns.Reputation:WarningReason(rec)
    local name = ns.PlayerUtils:DisplayName(rec, { colorize = true, includeRealm = true })
    local lines = {
        "|cffff5555INCOMING INVITE FROM BLACKLISTED PLAYER|r",
        name .. "  |cff888888(" .. reason .. ")|r",
    }
    if rec.notes and rec.notes ~= "" then
        lines[#lines + 1] = "|cffaaaaaaNote:|r " .. rec.notes
    end
    frame.body:SetText(table.concat(lines, "\n"))
    frame:Show()
    frame:SetHeight(80 + #lines * 16)
    -- Auto-hide after 15 seconds; the PARTY_INVITE popup itself has its own
    -- timeout and the user may have already dealt with it.
    C_Timer.After(15, function()
        if frame and frame:IsShown() then frame:Hide() end
    end)
end
