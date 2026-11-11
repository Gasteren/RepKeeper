-- UI/Warnings.lua
-- The warning when blacklisted players are in your group, or one of them invites you: who, why, and your note.

local addonName, ns = ...
local L = LibStub("AceLocale-3.0"):GetLocale("RepKeeper")
local C = ns.Constants
local U, W, UI = ns.U, ns.W, ns.UI

local format, max = string.format, math.max

local MAX_ROWS = 5
local frame

local function leaveGroup()
    if C_PartyInfo and C_PartyInfo.LeaveParty then
        C_PartyInfo.LeaveParty()
    elseif LeaveParty then
        LeaveParty()
    end
end

local function build()
    frame = W.Window("RepKeeperWarning", L["RepKeeper warning"], 440, 200, {
        strata = "DIALOG", point = "TOP", relPoint = "TOP", x = 0, y = -120, solid = true,
    })
    frame.lead = W.Text(frame, "", 400, "GameFontNormal")
    frame.lead:SetPoint("TOP", 0, -34)
    frame.lead:SetJustifyH("CENTER")
    frame.rows = {}
    for i = 1, MAX_ROWS do
        local row = CreateFrame("Button", nil, frame)
        row:SetHeight(34)
        row.name = W.OneLine(W.Label(row, "", "GameFontHighlight"))
        row.name:SetPoint("TOPLEFT", 4, -2)
        row.name:SetPoint("TOPRIGHT", -4, -2)
        row.why = W.OneLine(W.Label(row, "", "GameFontHighlightSmall"))
        row.why:SetPoint("TOPLEFT", 4, -18)
        row.why:SetPoint("TOPRIGHT", -4, -18)
        local hl = row:CreateTexture(nil, "HIGHLIGHT")
        hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        hl:SetBlendMode("ADD")
        hl:SetAllPoints()
        W.Themed(hl, W.PaintHighlight)
        row:SetScript("OnClick", function(self)
            if self.rec then
                W.Sound("click")
                UI.ShowPlayer(self.rec.normalizedKey)
            end
        end)
        W.AttachTooltip(row, nil, L["Click to open them in RepKeeper."])
        frame.rows[i] = row
    end
    frame.more = W.Label(frame, "", "GameFontDisableSmall")

    frame.dismiss = W.Button(frame, L["Dismiss"], 110, function()
        frame:Hide()
    end)
    frame.dismiss:SetPoint("BOTTOMRIGHT", -20, 20)
    frame.leave = W.Button(frame, L["Leave Group"], 110, function()
        leaveGroup()
        frame:Hide()
    end, L["Leaves your group right away."])
    frame.leave:SetPoint("RIGHT", frame.dismiss, "LEFT", -6, 0)
    frame.view = W.Button(frame, L["Open RepKeeper"], 120, function()
        local rec = frame.rows[1].rec
        frame:Hide()
        if rec then
            UI.ShowPlayer(rec.normalizedKey)
        else
            UI.Show("players")
        end
    end)
    frame.view:SetPoint("BOTTOMLEFT", 20, 20)
    function frame:onHidden()
        self.hideAt = nil
    end
    frame:SetScript("OnUpdate", function(self)
        if self.hideAt and GetTime() >= self.hideAt and not self:IsMouseOver() then
            self:Hide()
        end
    end)
end

-- Why a player is flagged, in red: "Blacklist: Toxic, Key Leaver".
local function reason(rec)
    local text = UI.RatingName(rec.reputation)
    local tags = {}
    for _, t in ipairs(UI.PlayerTags(rec)) do
        if t.tier == "negative" and #tags < 3 then
            tags[#tags + 1] = t.def.name
        end
    end
    if #tags > 0 then
        text = text .. ": " .. table.concat(tags, ", ")
    end
    local out = U.Color(ns.COLOR.red, text)
    if rec.notes and rec.notes ~= "" and not ns.S.streamerMode then
        out = out .. U.Color(ns.COLOR.grey, UI.DOT .. rec.notes)
    end
    return out
end

local function show(lead, list, invite)
    if not frame then
        build()
    end
    frame.lead:SetText(lead)
    local y = -38 - frame.lead:GetStringHeight()
    for i, row in ipairs(frame.rows) do
        local rec = list[i]
        row.rec = rec
        if rec then
            row.name:SetText(UI.Name(rec))
            row.why:SetText(reason(rec))
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 20, y)
            row:SetPoint("TOPRIGHT", -20, y)
            row:Show()
            y = y - 36
        else
            row:Hide()
        end
    end
    if #list > MAX_ROWS then
        frame.more:SetText(format(L["and %d more"], #list - MAX_ROWS))
        frame.more:ClearAllPoints()
        frame.more:SetPoint("TOPLEFT", 24, y)
        frame.more:Show()
        y = y - 16
    else
        frame.more:Hide()
    end
    frame.leave:SetShown(not invite and IsInGroup and IsInGroup())
    frame:SetHeight(max(150, -y + 58))
    frame.hideAt = invite and (GetTime() + 15) or nil
    frame:Show()
    frame:Raise()
end

-- flagged: the records of the group members you blacklisted.
function UI.ShowGroupWarning(flagged)
    if #flagged == 0 then
        return
    end
    local lead
    if #flagged == 1 then
        lead = L["A player you blacklisted is in your group."]
    else
        lead = format(L["%d players you blacklisted are in your group."], #flagged)
    end
    show(U.Color(ns.COLOR.red, lead), flagged, false)
end

-- A blacklisted player invited you: a warning so you don't accept by accident (it goes away after 15 seconds).
function UI.ShowInviteWarning(rec)
    if not rec then
        return
    end
    show(U.Color(ns.COLOR.red, L["A player you blacklisted invited you to a group."]), { rec }, true)
end
