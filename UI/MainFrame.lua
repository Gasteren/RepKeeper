-- UI/MainFrame.lua
-- The RepKeeper window: a status line, the pages (Players, Groups, Options) and the character-frame tabs that switch
-- between them. ns.MainFrame keeps the entry points the rest of the addon calls (Show, Toggle, Refresh).

local addonName, ns = ...
local L = LibStub("AceLocale-3.0"):GetLocale("RepKeeper")
local C = ns.Constants
local U, W = ns.U, ns.W

local UI = {}
ns.UI = UI

local format = string.format

UI.WIDTH, UI.HEIGHT = W.MAX_WIDTH, W.MAX_HEIGHT
UI.DOT = "  \194\183  " -- a middle dot between parts of a line

UI.pages = {}
UI.byId = {}
UI.panels = {}
UI.dirty = {}

local frame

---------------------------------------------------------------------------
-- How ratings and tags look everywhere in the windows
---------------------------------------------------------------------------
UI.RATING_ORDER = { C.REP.BLACKLIST, C.REP.NEUTRAL, C.REP.POSITIVE }
UI.RATING = {
    [C.REP.BLACKLIST] = {
        atlas = "UI-LFG-DeclineMark",
        tip = L["Avoid them. RepKeeper warns you when they are in your group or invite you."],
    },
    [C.REP.NEUTRAL] = {
        atlas = "UI-LFG-PendingMark",
        tip = L["No opinion either way. Players RepKeeper adds from your groups start here."],
    },
    [C.REP.POSITIVE] = {
        atlas = "UI-LFG-ReadyMark",
        tip = L["Someone you would happily group with again."],
    },
}

function UI.RatingColor(level)
    local r, g, b = ns.PlayerUtils:RepColor(level or 0)
    return { r, g, b }
end

function UI.RatingName(level)
    return C.REP_NAMES[level or 0] or C.REP_NAMES[0]
end

-- The rating's mark as a text escape.
function UI.RatingIcon(level, size)
    local def = UI.RATING[level or 0] or UI.RATING[0]
    size = size or 14
    return format("|A:%s:%d:%d|a", def.atlas, size, size)
end

-- The rating's name in its colour, with its mark in front (neutral has no mark, so rated players stand out).
function UI.RatingLabel(level)
    level = level or 0
    local text = "|c" .. ns.PlayerUtils:RepColorHex(level) .. UI.RatingName(level) .. "|r"
    if level == C.REP.NEUTRAL then
        return text
    end
    return UI.RatingIcon(level, 12) .. " " .. text
end

-- Choices for W.Segmented.
function UI.RatingChoices()
    local items = {}
    for i, level in ipairs(UI.RATING_ORDER) do
        items[i] = {
            value = level,
            text = UI.RatingName(level),
            atlas = UI.RATING[level].atlas,
            color = UI.RatingColor(level),
            tip = UI.RATING[level].tip,
        }
    end
    return items
end

UI.TIER_ORDER = { "negative", "neutral", "positive" }
UI.TIER_COLOR = {
    negative = { 1, 0.38, 0.38 },
    neutral = { 0.75, 0.75, 0.75 },
    positive = { 0.42, 0.9, 0.42 },
}
UI.TIER_NAME = {
    negative = L["Negative"],
    neutral = L["Neutral"],
    positive = L["Positive"],
}
UI.TIER_OF_RATING = {
    [C.REP.BLACKLIST] = "negative",
    [C.REP.NEUTRAL] = "neutral",
    [C.REP.POSITIVE] = "positive",
}

function UI.TagTier(def)
    return def.tier or (def.negative and "negative" or "positive")
end

-- The player's tags: { id, def, tier, custom }, worst first, then by name.
function UI.PlayerTags(rec)
    local out = {}
    local rank = { negative = 1, neutral = 2, positive = 3 }
    for tagID in pairs(rec.tags or {}) do
        local def = ns.Database:GetTagDef(tagID)
        if def then
            out[#out + 1] = { id = tagID, def = def, tier = UI.TagTier(def), custom = C.BUILTIN_TAGS[tagID] == nil }
        end
    end
    table.sort(out, function(a, b)
        if a.tier ~= b.tier then
            return rank[a.tier] < rank[b.tier]
        end
        return a.def.name < b.def.name
    end)
    return out
end

-- The name as the windows show it: class colour, realm (when realms are shown), streamer mode.
function UI.Name(rec)
    return ns.PlayerUtils:DisplayName(rec, { colorize = true, includeRealm = true })
end

---------------------------------------------------------------------------
-- Pages
---------------------------------------------------------------------------
-- def: { id, label, tip, order, create(panel), refresh(panel) }
function UI.RegisterPage(def)
    UI.pages[#UI.pages + 1] = def
    UI.byId[def.id] = def
    table.sort(UI.pages, function(a, b)
        return (a.order or 99) < (b.order or 99)
    end)
    UI.dirty[def.id] = true
end

function UI.Counts()
    local total, black, positive = 0, 0, 0
    for _, rec in pairs(ns.db.global.players) do
        total = total + 1
        if rec.reputation == C.REP.BLACKLIST then
            black = black + 1
        elseif rec.reputation == C.REP.POSITIVE then
            positive = positive + 1
        end
    end
    return total, black, positive
end

local STATUS_ICON = {
    orange = "Interface\\FriendsFrame\\StatusIcon-Away",
    green = "Interface\\FriendsFrame\\StatusIcon-Online",
}

-- The indicator next to the close button: what is worth knowing right now (or nothing).
local function indicatorState()
    local s = ns.S
    if s.streamerMode then
        return L["Streamer mode"], "orange", L["Names are hidden: players show as Player1234. Click to change it on the Options tab."], "general"
    end
    local pending = ns.GuildSync and ns.GuildSync.CountPending and ns.GuildSync:CountPending() or 0
    if s.guildSyncEnabled and pending > 0 then
        local text = U.Count(pending, L["%d guild suggestion"], L["%d guild suggestions"])
        return text, "green", L["Guildmates shared players with you. Click to review them on the Options tab."], "guild"
    end
end

function UI.UpdateStatus()
    if not frame then
        return
    end
    local total, black, positive = UI.Counts()
    local white = ns.COLOR.white
    frame.status:SetText(format(total == 1 and L["%s player"] or L["%s players"], U.Color(white, U.Number(total)))
        .. UI.DOT .. format(L["%s blacklisted"], U.Color(white, black))
        .. UI.DOT .. format(L["%s positive"], U.Color(white, positive)))

    local text, color, tip, page = indicatorState()
    local st = frame.state
    if text then
        st.text:SetText(U.Color(color == "orange" and ns.COLOR.orange or ns.COLOR.green, text))
        st.icon:SetTexture(STATUS_ICON[color])
        st.tip, st.page = tip, page
        st:SetWidth(math.ceil(st.text:GetStringWidth()) + 18)
        st:Show()
    else
        st:Hide()
    end
end

local function refreshVisible()
    if not frame or not frame:IsShown() then
        return
    end
    UI.UpdateStatus()
    local id = UI.current
    local def, panel = UI.byId[id], UI.panels[id]
    if def and panel and UI.dirty[id] then
        UI.dirty[id] = false
        if def.refresh then
            ns.SafeCall(def.refresh, panel)
        end
    end
end

-- Marks a page (or all of them) as stale; the visible one is redrawn right after.
function UI.Refresh(id)
    if id then
        UI.dirty[id] = true
    else
        for k in pairs(UI.byId) do
            UI.dirty[k] = true
        end
    end
    if frame and frame:IsShown() then
        ns.Debounce("rk-ui-refresh", 0.05, refreshVisible)
    end
end

local function selectPage(id)
    local def = UI.byId[id]
    if not def then
        return
    end
    if UI.current and UI.current ~= id then
        local old = UI.panels[UI.current]
        if old then
            old:Hide()
        end
    end
    W.Menu:Hide()
    UI.current = id
    ns.S.ui.tab = id
    local panel = UI.panels[id]
    if not panel then
        panel = CreateFrame("Frame", nil, frame.content)
        panel:SetAllPoints()
        UI.panels[id] = panel
        ns.SafeCall(def.create, panel)
        UI.dirty[id] = true
    end
    panel:Show()
    UI.dirty[id] = false
    if def.refresh then
        ns.SafeCall(def.refresh, panel)
    end
end

local function build()
    frame = W.Window("RepKeeperFrame", L["RepKeeper"], UI.WIDTH, UI.HEIGHT, { sound = true })
    frame.content = CreateFrame("Frame", nil, frame)
    frame.content:SetPoint("TOPLEFT", 14, -30)
    frame.content:SetPoint("BOTTOMRIGHT", -14, 14)

    frame.status = W.OneLine(W.Label(frame, "", "GameFontHighlightSmall"))
    frame.status:SetPoint("TOPLEFT", 20, -15)
    frame.status:SetWidth(300)

    local st = CreateFrame("Button", nil, frame)
    st:SetSize(150, 16)
    st:SetPoint("TOPRIGHT", -40, -13)
    st.text = st:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    st.text:SetPoint("RIGHT")
    st.text:SetJustifyH("RIGHT")
    st.icon = st:CreateTexture(nil, "ARTWORK")
    st.icon:SetSize(14, 14)
    st.icon:SetPoint("RIGHT", st.text, "LEFT", -3, 0)
    st:SetScript("OnEnter", function(self)
        if self.tip then
            W.ShowTip(self, self.text:GetText(), self.tip, "ANCHOR_BOTTOMLEFT")
        end
    end)
    st:SetScript("OnLeave", W.HideTip)
    st:SetScript("OnClick", function(self)
        W.Sound("click")
        if self.page and UI.ShowOptions then
            UI.ShowOptions(self.page)
        end
    end)
    st:Hide()
    frame.state = st

    local defs = {}
    for i, def in ipairs(UI.pages) do
        defs[i] = { id = def.id, label = def.label, tip = def.tip }
    end
    frame.tabs = W.TabBar(frame, defs, selectPage)

    function frame:onShown()
        self.tabs:Relevel()
        UI.Refresh()
    end
    return frame
end

function UI.Frame()
    return frame
end

function UI.IsShown()
    return frame ~= nil and frame:IsShown()
end

-- Opens the window on a page (nil: the page it was on).
function UI.Show(id)
    if not frame then
        build()
    end
    id = id or (frame:IsShown() and UI.current) or ns.S.ui.tab
    if not UI.byId[id] then
        id = UI.pages[1].id
    end
    frame:Show()
    frame:Raise()
    frame.tabs:Relevel()
    frame.tabs:Select(id)
    UI.UpdateStatus()
    return UI.panels[id]
end

function UI.Hide()
    if frame then
        frame:Hide()
    end
end

function UI.Toggle(id)
    if frame and frame:IsShown() and (not id or id == UI.current) then
        frame:Hide()
    else
        UI.Show(id)
    end
end

ns.On("THEME_CHANGED", function()
    UI.Refresh()
end)

ns.On("SETTINGS_CHANGED", function(key)
    if key == "scale" then
        W.ApplyScale()
    end
    UI.Refresh()
end)

---------------------------------------------------------------------------
-- The entry points the rest of the addon uses
---------------------------------------------------------------------------
local MainFrame = {}
ns.MainFrame = MainFrame

function MainFrame:Initialize()
    W.ApplyTheme(ns.S.ui.theme)
    ns.Database.RegisterCallback(self, "OnPlayerAdded", "OnData")
    ns.Database.RegisterCallback(self, "OnPlayerRemoved", "OnData")
    ns.Database.RegisterCallback(self, "OnPlayerChanged", "OnData")
    ns.Database.RegisterCallback(self, "OnEncounterRecorded", "OnData")
end

function MainFrame:OnData()
    UI.Refresh()
end

function MainFrame:Toggle()
    UI.Toggle()
end

function MainFrame:Show()
    UI.Show()
end

function MainFrame:Hide()
    UI.Hide()
end

function MainFrame:Refresh()
    UI.Refresh()
end
