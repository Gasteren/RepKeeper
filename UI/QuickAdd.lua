-- UI/QuickAdd.lua
-- Lightweight prompt that appears when Detection sees suspicious behavior
-- (player left group / kicked / spammed / etc) and asks if the user wants
-- to add them to RepKeeper.
--
-- Designed to be unobtrusive: small frame, auto-times-out, "don't show
-- again this session" mute, never blocks input.

local addonName, ns = ...
local C = ns.Constants

local QuickAdd = {}
ns.QuickAdd = QuickAdd

local frame
local timeoutHandle

local REASON_TEXT = {
    left    = function() return ns.L["left your group"] end,
    kicked  = function() return ns.L["was vote-kicked"] end,
    trade   = function() return ns.L["spammed trade requests"] end,
    duel    = function() return ns.L["spammed duel requests"] end,
    whisper = function() return ns.L["spammed whispers"] end,
}

function QuickAdd:Initialize() end

function QuickAdd:Build()
    if frame then return frame end

    frame = CreateFrame("Frame", "RepKeeperQuickAdd", UIParent, "BackdropTemplate")
    frame:SetSize(360, 130)
    frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -120, -200)
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)

    -- ESC-to-close support
    tinsert(UISpecialFrames, "RepKeeperQuickAdd")
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
        frame:SetBackdropColor(0.06, 0.06, 0.07, 0.96)
        frame:SetBackdropBorderColor(0.5, 0.4, 0.2, 1)
    end

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -12)
    title:SetText("|cffd0a070" .. ns.L["RepKeeper: Quick Add"] .. "|r")
    frame.title = title

    local body = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    body:SetPoint("TOPLEFT", 16, -36)
    body:SetPoint("TOPRIGHT", -16, -36)
    body:SetJustifyH("LEFT")
    frame.body = body

    local skipBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    skipBtn:SetSize(80, 22)
    skipBtn:SetPoint("BOTTOMLEFT", 16, 14)
    skipBtn:SetText(ns.L["Skip"])
    skipBtn:SetScript("OnClick", function() QuickAdd:Hide() end)
    frame.skipBtn = skipBtn

    local muteBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    muteBtn:SetSize(170, 22)
    muteBtn:SetPoint("BOTTOM", 0, 14)
    muteBtn:SetText(ns.L["Don't show again this session"])
    muteBtn:SetScript("OnClick", function()
        if ns.Detection and ns.Detection.MuteSession then
            ns.Detection:MuteSession()
        end
        QuickAdd:Hide()
    end)

    local addBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    addBtn:SetSize(80, 22)
    addBtn:SetPoint("BOTTOMRIGHT", -16, 14)
    addBtn:SetText(ns.L["Add"])
    addBtn:SetScript("OnClick", function()
        if frame.currentRec and ns.PlayerEditor then
            ns.PlayerEditor:Open(frame.currentRec)
        end
        QuickAdd:Hide()
    end)
    frame.addBtn = addBtn

    return frame
end

function QuickAdd:Show(rec, reason)
    if not rec then return end
    self:Build()

    local reasonFn = REASON_TEXT[reason]
    local reasonText = reasonFn and reasonFn() or "did something"

    frame.body:SetText(string.format(ns.L["%s just %s. Add them to your list?"],
        ns.PlayerUtils:DisplayName(rec, { colorize = true, includeRealm = true }),
        "|cffff8888" .. reasonText .. "|r"))
    frame.currentRec = rec
    frame:Show()

    if timeoutHandle then timeoutHandle:Cancel() end
    local timeout = ns.db.global.settings.quickAddPopupTimeout or 15
    timeoutHandle = C_Timer.NewTimer(timeout, function() QuickAdd:Hide() end)
end

function QuickAdd:Hide()
    if frame then frame:Hide() end
    if timeoutHandle then timeoutHandle:Cancel(); timeoutHandle = nil end
end
