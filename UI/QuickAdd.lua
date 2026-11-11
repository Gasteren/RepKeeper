-- UI/QuickAdd.lua
-- The small pop-up when RepKeeper spots someone (they left your group, they spam you): rate them on the spot, open
-- them, or let it go. It goes away by itself; the bar at the bottom shows how long it stays (it waits while the mouse
-- is on it).

local addonName, ns = ...
local L = LibStub("AceLocale-3.0"):GetLocale("RepKeeper")
local C = ns.Constants
local U, W, UI = ns.U, ns.W, ns.UI

local format = string.format

local QuickAdd = {}
ns.QuickAdd = QuickAdd

local REASON_TEXT = {
    left = L["left your group"],
    kicked = L["was vote-kicked"],
    trade = L["spammed trade requests"],
    duel = L["spammed duel requests"],
    whisper = L["spammed whispers"],
}

local frame

function QuickAdd:Initialize() end

local function rate(level)
    local rec = frame and frame.rec
    if not rec then
        return
    end
    UI.SetRating(rec, level)
    ns.Addon:Printf(L["%s is now %s."], ns.PlayerUtils:DisplayNamePlain(rec), UI.RatingName(level))
    QuickAdd:Hide()
end

local function build()
    frame = W.Window("RepKeeperQuickAdd", L["RepKeeper"], 380, 134, {
        strata = "DIALOG", point = "TOPRIGHT", relPoint = "TOPRIGHT", x = -120, y = -200, solid = true,
    })
    frame.text = W.Text(frame, "", 340, "GameFontHighlight")
    frame.text:SetPoint("TOP", 0, -34)
    frame.text:SetJustifyH("CENTER")
    frame.hint = W.Label(frame, L["Rate them now, or open them to add a note."], "GameFontDisableSmall")
    frame.hint:SetPoint("TOP", frame.text, "BOTTOM", 0, -4)

    frame.black = W.Button(frame, UI.RatingIcon(C.REP.BLACKLIST, 14) .. " " .. UI.RatingName(C.REP.BLACKLIST), 110, function()
        rate(C.REP.BLACKLIST)
    end, UI.RATING[C.REP.BLACKLIST].tip)
    frame.good = W.Button(frame, UI.RatingIcon(C.REP.POSITIVE, 14) .. " " .. UI.RatingName(C.REP.POSITIVE), 110, function()
        rate(C.REP.POSITIVE)
    end, UI.RATING[C.REP.POSITIVE].tip)
    frame.open = W.Button(frame, L["Open"], 110, function()
        local rec = frame.rec
        QuickAdd:Hide()
        if rec then
            UI.ShowPlayer(rec.normalizedKey)
        end
    end, L["Opens them in RepKeeper: rating, tags, note and history."])
    frame.good:SetPoint("BOTTOM", 0, 34)
    frame.black:SetPoint("RIGHT", frame.good, "LEFT", -6, 0)
    frame.open:SetPoint("LEFT", frame.good, "RIGHT", 6, 0)

    frame.mute = W.TextButton(frame, L["Don't ask again this session"], function()
        if ns.Detection and ns.Detection.MuteSession then
            ns.Detection:MuteSession()
        end
        QuickAdd:Hide()
    end, L["No more of these pop-ups until you log out or reload. RepKeeper still notes it in their history."], "GameFontDisableSmall")
    frame.mute:SetPoint("BOTTOMLEFT", 18, 16)

    frame.bar = W.TimerBar(frame, 3)
    frame.bar:SetPoint("BOTTOMLEFT", 14, 11)
    frame.bar:SetPoint("BOTTOMRIGHT", -14, 11)
    frame.bar:SetStatusBarColor(W.GOLD[1], W.GOLD[2], W.GOLD[3])

    frame:SetScript("OnUpdate", function(self, elapsed)
        if not self.timeout then
            return
        end
        if not self:IsMouseOver() then
            self.left = self.left - elapsed
        end
        self.bar:SetValue(math.max(0, self.left / self.timeout))
        if self.left <= 0 then
            QuickAdd:Hide()
        end
    end)
    function frame:onHidden()
        self.rec = nil
        self.timeout = nil
    end
end

function QuickAdd:Show(rec, reason)
    if not rec then
        return
    end
    if not frame then
        build()
    end
    local what = REASON_TEXT[reason] or L["did something"]
    frame.rec = rec
    frame.text:SetText(format(L["%s %s."], UI.Name(rec), U.Color(ns.COLOR.red, what)))
    frame.timeout = math.max(5, tonumber(ns.S.quickAddPopupTimeout) or 15)
    frame.left = frame.timeout
    frame.bar:SetValue(1)
    frame:Show()
    frame:Raise()
end

function QuickAdd:Hide()
    if frame then
        frame:Hide()
    end
end
