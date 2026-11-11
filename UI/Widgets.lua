-- UI/Widgets.lua
-- RepKeeper's widget kit, built from the classic Blizzard frame art like the author's other addons (Level Time
-- Tracker, GuildLedger): the dialog border and its header plate, red panel buttons, check boxes, the old column tabs
-- and the character frame's bottom tabs, with themes that recolour that art. No external libraries.

local addonName, ns = ...
local L = LibStub("AceLocale-3.0"):GetLocale("RepKeeper")
local U = ns.U

local W = {}
ns.W = W

local floor, max, min = math.floor, math.max, math.min

W.windows = {}
W.GOLD = { 1, 0.82, 0 }

-- The window settings (theme, size, positions); nil until the saved variables are loaded.
local function UIS()
    return ns.S and ns.S.ui
end

---------------------------------------------------------------------------
-- Sounds
---------------------------------------------------------------------------
local SOUNDS = {
    open = { "IG_MAINMENU_OPEN", 850 },
    close = { "IG_MAINMENU_CLOSE", 851 },
    tab = { "IG_CHARACTER_INFO_TAB", 841 },
    click = { "IG_MAINMENU_OPTION_CHECKBOX_ON", 856 },
    on = { "IG_MAINMENU_OPTION_CHECKBOX_ON", 856 },
    off = { "IG_MAINMENU_OPTION_CHECKBOX_OFF", 857 },
}

function W.Sound(kind)
    local s = SOUNDS[kind]
    if s then
        U.PlaySound(s[1], s[2])
    end
end

---------------------------------------------------------------------------
-- Backdrops
---------------------------------------------------------------------------
local FLAT = "Interface\\Tooltips\\UI-Tooltip-Background"
local TOOLTIP_BORDER = "Interface\\Tooltips\\UI-Tooltip-Border"

W.BD = {
    dark = {
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    },
    -- Windows of a theme with its own background: the classic dialog border around a flat colour.
    window = {
        bgFile = FLAT,
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    },
    box = {
        bgFile = FLAT,
        edgeFile = TOOLTIP_BORDER,
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 5, right = 5, top = 5, bottom = 5 },
    },
    menu = {
        bgFile = FLAT,
        edgeFile = TOOLTIP_BORDER,
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    },
    -- Small boxes: tags and the rating choices.
    chip = {
        bgFile = FLAT,
        edgeFile = TOOLTIP_BORDER,
        tile = true, tileSize = 16, edgeSize = 10,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    },
    slider = {
        bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
        edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = { left = 3, right = 3, top = 6, bottom = 6 },
    },
}

local BD_COLOR = {
    box = { 0.1, 0.1, 0.1, 0.65, 0.4, 0.4, 0.4, 1 },
    menu = { 0.09, 0.09, 0.19, 0.95, 1, 1, 1, 1 },
}

---------------------------------------------------------------------------
-- Themes
---------------------------------------------------------------------------
-- A theme recolours the classic art rather than replacing it. With metal set, window borders, the header plate, tabs,
-- column headers, dropdowns, check boxes and scroll bars are greyed out and tinted; buttons only when the theme has
-- its own button colour. Text: label = the gold of the game's labels, title = window and box titles, selected = the
-- selected tab. accent = dividers and sort arrows, highlight = row highlights.
local GOLD = W.GOLD

W.THEME_ORDER = { "classic", "steel", "horde", "alliance" }
W.THEMES = {
    classic = {
        name = L["Classic"],
        desc = L["The game's own frames, as they are."],
        label = GOLD, title = GOLD, selected = { 1, 1, 1 }, accent = GOLD, highlight = { 1, 1, 1 },
        box = BD_COLOR.box,
        menu = BD_COLOR.menu,
    },
    steel = {
        name = L["Steel"],
        desc = L["Black and steel with cyan."],
        metal = { 0.7, 0.76, 0.83 },
        buttons = { 0.62, 0.68, 0.76 },
        label = { 0.62, 0.77, 0.85 }, title = { 0.9, 0.93, 0.96 }, selected = { 0.22, 0.82, 1 },
        accent = { 0.22, 0.82, 1 }, highlight = { 0.35, 0.85, 1 },
        check = { 0.35, 0.9, 1 },
        window = { 0.03, 0.037, 0.045, 0.96 },
        box = { 0.07, 0.085, 0.1, 0.92, 0.42, 0.47, 0.53, 1 },
        menu = { 0.035, 0.045, 0.055, 0.97, 0.55, 0.6, 0.66, 1 },
    },
    horde = {
        name = L["Horde"],
        desc = L["Dark red iron with gold."],
        metal = { 0.92, 0.38, 0.27 },
        label = GOLD, title = GOLD, selected = { 1, 1, 1 }, accent = { 0.95, 0.4, 0.22 }, highlight = { 1, 0.6, 0.45 },
        window = { 0.08, 0.025, 0.02, 0.96 },
        box = { 0.13, 0.045, 0.035, 0.8, 0.6, 0.27, 0.2, 1 },
        menu = { 0.1, 0.03, 0.025, 0.97, 0.8, 0.4, 0.3, 1 },
    },
    alliance = {
        name = L["Alliance"],
        desc = L["Blue steel with gold."],
        metal = { 0.52, 0.68, 1 },
        buttons = { 0.5, 0.64, 1 },
        label = GOLD, title = GOLD, selected = { 1, 1, 1 }, accent = { 0.45, 0.7, 1 }, highlight = { 0.55, 0.75, 1 },
        window = { 0.02, 0.035, 0.085, 0.96 },
        box = { 0.04, 0.065, 0.13, 0.8, 0.3, 0.42, 0.68, 1 },
        menu = { 0.03, 0.05, 0.12, 0.97, 0.55, 0.7, 1, 1 },
    },
}

-- Copies of the game's gold fonts, so a theme recolours them without touching the game's own. Text using them follows
-- a theme change at once.
local FONTS = {
    RepKeeperFontNormal = { "GameFontNormal", "label" },
    RepKeeperFontNormalSmall = { "GameFontNormalSmall", "label" },
    RepKeeperFontNormalSmallLeft = { "GameFontNormalSmallLeft", "label" },
    RepKeeperFontNormalLarge = { "GameFontNormalLarge", "label" },
    RepKeeperFontNormalHuge = { "GameFontNormalHuge", "label" },
    RepKeeperFontTitle = { "GameFontNormal", "title" },
    RepKeeperFontTitleSmall = { "GameFontNormalSmall", "title" },
    RepKeeperFontTitleLarge = { "GameFontNormalLarge", "title" },
    RepKeeperFontSelectedSmall = { "GameFontHighlightSmall", "selected" },
}
for name, def in pairs(FONTS) do
    local font = CreateFont(name)
    font:CopyFontObject(_G[def[1]])
end

-- Everything a theme paints: object -> paint(object, theme).
local themed = setmetatable({}, { __mode = "k" })
W.themeId, W.theme = "classic", W.THEMES.classic

function W.Themed(obj, paint)
    themed[obj] = paint
    paint(obj, W.theme)
    return obj
end

-- Greys out a piece of classic art and colours it like the theme's metal; nil leaves the art as it is.
function W.Tint(tex, color)
    if not tex then
        return
    end
    tex:SetDesaturated(color ~= nil)
    if color then
        tex:SetVertexColor(color[1], color[2], color[3], 1)
    else
        tex:SetVertexColor(1, 1, 1, 1)
    end
end

local function paintArt(obj, th)
    for _, tex in ipairs(obj.art) do
        W.Tint(tex, th.metal)
    end
end
W.PaintArt = paintArt

local function paintHighlight(hl, th)
    local c = th.highlight
    hl:SetVertexColor(c[1], c[2], c[3], 1)
end
W.PaintHighlight = paintHighlight

local function paintTexture(tex, th)
    W.Tint(tex, th.metal)
end

local function paintArrowButton(b, th)
    W.Tint(b:GetNormalTexture(), th.metal)
    W.Tint(b:GetPushedTexture(), th.metal)
    W.Tint(b:GetDisabledTexture(), th.metal)
    W.Tint(b:GetHighlightTexture(), th.metal)
end

function W.ThemeArrowButton(b)
    return W.Themed(b, paintArrowButton)
end

local function paintScrollBar(bar, th)
    W.Tint(bar:GetThumbTexture(), th.metal)
end

function W.ThemeScrollBar(bar)
    W.Themed(bar, paintScrollBar)
    if bar.ScrollUpButton then
        W.Themed(bar.ScrollUpButton, paintArrowButton)
    end
    if bar.ScrollDownButton then
        W.Themed(bar.ScrollDownButton, paintArrowButton)
    end
    return bar
end

local function paintCheck(cb, th)
    W.Tint(cb:GetNormalTexture(), th.metal)
    W.Tint(cb:GetPushedTexture(), th.metal)
    W.Tint(cb:GetHighlightTexture(), th.metal)
    W.Tint(cb:GetCheckedTexture(), th.check)
end

function W.ApplyTheme(id)
    local th = W.THEMES[id]
    if not th then
        id, th = "classic", W.THEMES.classic
    end
    W.themeId, W.theme = id, th
    for name, def in pairs(FONTS) do
        local c = th[def[2]]
        _G[name]:SetTextColor(c[1], c[2], c[3])
    end
    for obj, paint in pairs(themed) do
        ns.SafeCall(paint, obj, th)
    end
    ns.Fire("THEME_CHANGED", id)
end

function W.SetTheme(id)
    local ui = UIS()
    if not W.THEMES[id] or not ui then
        return false
    end
    ui.theme = id
    W.ApplyTheme(id)
    return true
end

local EDGES = { "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner", "TopEdge", "BottomEdge",
    "LeftEdge", "RightEdge" }

local function paintBackdrop(f, th)
    local kind = f.bdKind
    local window = kind == "dark"
    if window and th.window then
        f:SetBackdrop(W.BD.window)
        local c = th.window
        f:SetBackdropColor(c[1], c[2], c[3], c[4])
    else
        f:SetBackdrop(W.BD[kind])
        local c = th[kind] or BD_COLOR[kind]
        if c then
            f:SetBackdropColor(c[1], c[2], c[3], c[4])
            f:SetBackdropBorderColor(c[5], c[6], c[7], c[8])
        else
            f:SetBackdropColor(1, 1, 1, 1)
            f:SetBackdropBorderColor(1, 1, 1, 1)
        end
    end
    if window then
        local m = th.metal
        if m then
            f:SetBackdropBorderColor(m[1], m[2], m[3], 1)
        end
        for _, piece in ipairs(EDGES) do
            W.Tint(f[piece], m)
        end
    end
end

function W.SetBackdrop(f, kind)
    if not f.SetBackdrop then
        Mixin(f, BackdropTemplateMixin)
        f:HookScript("OnSizeChanged", f.OnBackdropSizeChanged)
    end
    f.bdKind = W.BD[kind] and kind or "dark"
    W.Themed(f, paintBackdrop)
end

function W.Frame(parent, kind, name)
    local f = CreateFrame("Frame", name, parent, "BackdropTemplate")
    if kind then
        W.SetBackdrop(f, kind)
    end
    return f
end

-- Group box in the style of the old options panels: a small title above the border, a note on the right of it.
function W.Box(parent, title)
    local f = W.Frame(parent, "box")
    f.title = f:CreateFontString(nil, "ARTWORK", "RepKeeperFontTitleSmall")
    f.title:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 6, 2)
    f.title:SetText(title or "")
    f.note = f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    f.note:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", -6, 2)
    f.note:SetJustifyH("RIGHT")
    return f
end

---------------------------------------------------------------------------
-- Text, tooltips, dividers
---------------------------------------------------------------------------
function W.Label(parent, text, font, layer)
    local fs = parent:CreateFontString(nil, layer or "ARTWORK", font or "GameFontHighlightSmall")
    fs:SetJustifyH("LEFT")
    fs:SetText(text or "")
    return fs
end

-- A label that stays on one line: text that doesn't fit ends in "...".
function W.OneLine(fs)
    fs:SetWordWrap(false)
    fs:SetMaxLines(1)
    return fs
end

-- Wrapping paragraph with a fixed width.
function W.Text(parent, text, width, font)
    local fs = W.Label(parent, text, font or "GameFontHighlightSmall")
    fs:SetWidth(width)
    fs:SetJustifyV("TOP")
    fs:SetWordWrap(true)
    return fs
end

-- Height of one line in a font string's font. UI addons often make Blizzard's fonts bigger, so rows measure their
-- font instead of assuming its size.
function W.LineHeight(fs)
    local h = fs:GetLineHeight()
    if not h or h <= 0 then
        local _, size = fs:GetFont()
        h = tonumber(size) or 12
    end
    return math.ceil(h) + 1
end

local function paintDivider(t, th)
    local c = th.accent
    t:SetColorTexture(c[1], c[2], c[3], t.lineAlpha)
end

-- A thin line in the theme's accent colour.
function W.Divider(parent, alpha)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t.lineAlpha = alpha or 0.25
    t:SetHeight(1)
    return W.Themed(t, paintDivider)
end

-- text: a string, or a function(owner) returning one (or a list of lines; { left, right } pairs are two columns).
function W.ShowTip(owner, title, text, anchor)
    if not GameTooltip then
        return
    end
    if type(text) == "function" then
        text = text(owner)
    end
    GameTooltip:SetOwner(owner, anchor or "ANCHOR_RIGHT")
    local c = W.theme.title
    if title and title ~= "" then
        GameTooltip:SetText(title, c[1], c[2], c[3], 1, true)
    end
    if type(text) == "table" then
        for _, line in ipairs(text) do
            if type(line) == "table" then
                GameTooltip:AddDoubleLine(line[1], line[2], 1, 0.82, 0, 1, 1, 1)
            else
                GameTooltip:AddLine(line, 1, 1, 1, true)
            end
        end
    elseif text and text ~= "" then
        if title and title ~= "" then
            GameTooltip:AddLine(text, 1, 1, 1, true)
        else
            GameTooltip:SetText(text, 1, 1, 1, 1, true)
        end
    end
    GameTooltip:Show()
end

function W.HideTip()
    if GameTooltip then
        GameTooltip:Hide()
    end
end

-- A tooltip with the title and the text (nothing shows for a frame without text).
function W.AttachTooltip(frame, title, text, anchor)
    frame.tipTitle, frame.tipText = title, text
    frame:HookScript("OnEnter", function(self)
        if self.tipText then
            W.ShowTip(self, self.tipTitle, self.tipText, anchor)
        end
    end)
    frame:HookScript("OnLeave", W.HideTip)
end

---------------------------------------------------------------------------
-- Buttons
---------------------------------------------------------------------------
function W.FitButton(b, minWidth)
    local fs = b:GetFontString()
    local w = fs and fs:GetStringWidth() or 0
    b:SetWidth(max(minWidth or 60, floor(w + 30)))
end

-- The red panel button (and its hover glow); a theme with its own button colour greys it out and tints it.
local function paintButton(b, th)
    W.Tint(b.Left, th.buttons)
    W.Tint(b.Middle, th.buttons)
    W.Tint(b.Right, th.buttons)
    W.Tint(b:GetHighlightTexture(), th.buttons)
end

function W.Button(parent, text, width, onClick, tip)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetHeight(22)
    b:SetText(text or "")
    if width then
        b:SetWidth(width)
    else
        W.FitButton(b)
    end
    b:SetMotionScriptsWhileDisabled(true)
    W.Themed(b, paintButton)
    if onClick then
        b:SetScript("OnClick", function(self, mouse)
            W.Sound("click")
            onClick(self, mouse)
        end)
    end
    if tip then
        W.AttachTooltip(b, text, tip)
    end
    return b
end

-- A line of gold text that works as a button ("+ Add tag", the filters above the list).
function W.TextButton(parent, text, onClick, tip, font)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(16)
    local fs = b:CreateFontString(nil, "ARTWORK", font or "RepKeeperFontNormalSmall")
    fs:SetPoint("LEFT")
    fs:SetJustifyH("LEFT")
    b:SetFontString(fs)
    b:SetNormalFontObject(font or "RepKeeperFontNormalSmall")
    b:SetHighlightFontObject("GameFontHighlightSmall")
    b:SetDisabledFontObject("GameFontDisableSmall")

    function b:SetLabel(t)
        self:SetText(t)
        self:SetWidth(floor(fs:GetStringWidth() + 4))
    end

    b:SetLabel(text)
    b:SetScript("OnClick", function(self, mouse)
        W.Sound("click")
        onClick(self, mouse)
    end)
    if tip then
        W.AttachTooltip(b, text, tip)
    end
    return b
end

-- Square icon button.
function W.IconButton(parent, normal, size, onClick, tipTitle, tipText)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size or 24, size or 24)
    b:SetNormalTexture(normal)
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    if onClick then
        b:SetScript("OnClick", function(self, mouse)
            W.Sound("click")
            onClick(self, mouse)
        end)
    end
    if tipTitle or tipText then
        W.AttachTooltip(b, tipTitle, tipText)
    end
    return b
end

function W.CloseButton(frame, onClick)
    local b
    if U.TexExists("Interface\\Buttons\\UI-Panel-MinimizeButton-Up") then
        b = CreateFrame("Button", nil, frame)
        b:SetSize(32, 32)
        b:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
        b:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
        b:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight", "ADD")
    else
        b = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    end
    b:SetPoint("TOPRIGHT", -5, -5)
    b:SetScript("OnClick", onClick or function()
        frame:Hide()
    end)
    return b
end

---------------------------------------------------------------------------
-- Check boxes and radio buttons
---------------------------------------------------------------------------
function W.Check(parent, label, tip, get, set)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    local text = cb.Text or cb.text
    if not text then
        text = cb:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        cb.Text = text
    end
    text:SetFontObject("GameFontHighlight")
    text:ClearAllPoints()
    text:SetPoint("LEFT", cb, "RIGHT", 1, 1)
    text:SetJustifyH("LEFT")
    cb.label = text
    cb.getter, cb.setter = get, set
    W.Themed(cb, paintCheck)

    function cb:SetLabel(t)
        self.label:SetText(t or "")
        self:SetHitRectInsets(0, -min(360, floor(self.label:GetStringWidth() + 6)), 0, 0)
    end

    function cb:Refresh()
        if self.getter then
            self:SetChecked(self.getter() and true or false)
        end
    end

    function cb:SetActive(on)
        self:SetEnabled(on)
        self.label:SetFontObject(on and "GameFontHighlight" or "GameFontDisable")
    end

    cb:SetLabel(label)
    cb:SetMotionScriptsWhileDisabled(true)
    cb:SetScript("OnClick", function(self)
        local on = self:GetChecked() and true or false
        W.Sound(on and "on" or "off")
        if self.setter then
            self.setter(on, self)
        end
    end)
    if tip then
        W.AttachTooltip(cb, label, tip)
    end
    cb:Refresh()
    return cb
end

---------------------------------------------------------------------------
-- Edit boxes (the classic input border)
---------------------------------------------------------------------------
local INPUT = "Interface\\Common\\Common-Input-Border"
local SEARCH_ICON = "common-search-magnifyingglass"
local CLEAR_ICON = "common-search-clearbutton"

-- opts: { placeholder, numeric, maxLetters, search (magnifier and a clear button), onEnter(self, text) (true keeps the
--         focus), onChange(self, text), onCommit(self, text), onEscape(self), onTab(self), tip, tipTitle }
function W.EditBox(parent, width, opts)
    opts = opts or {}
    local e = CreateFrame("EditBox", nil, parent)
    e:SetSize(width or 120, 20)
    e:SetAutoFocus(false)
    e:SetFontObject("ChatFontNormal")
    e:SetTextInsets(opts.search and 14 or 0, opts.search and 16 or 6, 0, 0)

    local l = e:CreateTexture(nil, "BACKGROUND")
    l:SetTexture(INPUT)
    l:SetSize(8, 20)
    l:SetPoint("LEFT", -5, 0)
    l:SetTexCoord(0, 0.0625, 0, 0.625)
    local r = e:CreateTexture(nil, "BACKGROUND")
    r:SetTexture(INPUT)
    r:SetSize(8, 20)
    r:SetPoint("RIGHT", 0, 0)
    r:SetTexCoord(0.9375, 1, 0, 0.625)
    local m = e:CreateTexture(nil, "BACKGROUND")
    m:SetTexture(INPUT)
    m:SetHeight(20)
    m:SetPoint("LEFT", l, "RIGHT")
    m:SetPoint("RIGHT", r, "LEFT")
    m:SetTexCoord(0.0625, 0.9375, 0, 0.625)

    if opts.numeric then
        e:SetNumeric(true)
    end
    if opts.maxLetters then
        e:SetMaxLetters(opts.maxLetters)
    end

    local clear
    if opts.search then
        local icon = e:CreateTexture(nil, "OVERLAY")
        icon:SetAtlas(SEARCH_ICON)
        icon:SetSize(14, 14)
        icon:SetPoint("LEFT", -1, -1)
        icon:SetVertexColor(0.6, 0.6, 0.6, 1)
        e.searchIcon = icon
        clear = CreateFrame("Button", nil, e)
        clear:SetSize(14, 14)
        clear:SetPoint("RIGHT", -3, 0)
        local x = clear:CreateTexture(nil, "ARTWORK")
        x:SetAtlas(CLEAR_ICON)
        x:SetAllPoints()
        x:SetAlpha(0.5)
        clear.icon = x
        clear:SetScript("OnEnter", function(self)
            self.icon:SetAlpha(1)
        end)
        clear:SetScript("OnLeave", function(self)
            self.icon:SetAlpha(0.5)
        end)
        clear:SetScript("OnClick", function()
            W.Sound("click")
            e:SetText("")
            e:ClearFocus()
            if opts.onChange then
                opts.onChange(e, "")
            end
        end)
        clear:Hide()
        e.clear = clear
    end

    local ph
    if opts.placeholder then
        ph = e:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
        ph:SetPoint("LEFT", opts.search and 15 or 1, 0)
        ph:SetPoint("RIGHT", -6, 0)
        ph:SetJustifyH("LEFT")
        W.OneLine(ph)
        ph:SetText(opts.placeholder)
        e.placeholder = ph
    end
    local function updateDecor(self)
        local empty = self:GetText() == ""
        if ph then
            ph:SetShown(empty and not self:HasFocus())
        end
        if clear then
            clear:SetShown(not empty)
        end
    end
    e.UpdateDecor = updateDecor

    e:SetScript("OnEscapePressed", function(self)
        if opts.onEscape then
            opts.onEscape(self)
        end
        self:ClearFocus()
    end)
    e:SetScript("OnEnterPressed", function(self)
        if not (opts.onEnter and opts.onEnter(self, self:GetText()) == true) then
            self:ClearFocus()
        end
    end)
    e:SetScript("OnTabPressed", function(self)
        if opts.onTab then
            opts.onTab(self)
        else
            self:ClearFocus()
        end
    end)
    e:SetScript("OnEditFocusGained", function(self)
        self:HighlightText()
        updateDecor(self)
    end)
    e:SetScript("OnEditFocusLost", function(self)
        self:HighlightText(0, 0)
        updateDecor(self)
        if opts.onCommit then
            opts.onCommit(self, self:GetText())
        end
    end)
    e:SetScript("OnTextChanged", function(self, user)
        updateDecor(self)
        if user and opts.onChange then
            opts.onChange(self, self:GetText())
        end
    end)
    if opts.tip then
        W.AttachTooltip(e, opts.tipTitle, opts.tip)
    end
    updateDecor(e)
    return e
end

---------------------------------------------------------------------------
-- Popup menu (shared by dropdowns and right-click menus; the game's own menus are shared with secure code)
---------------------------------------------------------------------------
local MENU_ROW = 16
local MENU_MAX_ROWS = 30
local CHECKS = "Interface\\Common\\UI-DropDownRadioChecks"

local Menu = CreateFrame("Frame", "RepKeeperMenu", UIParent, "BackdropTemplate")
W.Menu = Menu
Menu:Hide()
Menu:SetFrameStrata("FULLSCREEN_DIALOG")
Menu:SetClampedToScreen(true)
Menu:EnableMouse(true)
Menu:EnableMouseWheel(true)
Menu.rows = {}
Menu.offset = 0
Menu.visible = 0
-- Solid under the backdrop, so what is behind the menu doesn't show through.
Menu.under = Menu:CreateTexture(nil, "BACKGROUND", nil, -8)
Menu.under:SetColorTexture(0.02, 0.02, 0.04, 0.9)

Menu.measure = Menu:CreateFontString(nil, "BACKGROUND", "GameFontHighlightSmallLeft")
Menu.measure:SetPoint("TOPLEFT", 0, 0)
Menu.measure:SetAlpha(0)

local function arrowTexture(point, tex)
    local t = Menu:CreateTexture(nil, "OVERLAY")
    t:SetTexture(tex)
    t:SetTexCoord(0.2, 0.8, 0.25, 0.75)
    t:SetSize(16, 12)
    t:SetPoint(point, 0, point == "TOP" and -2 or 2)
    t:Hide()
    return W.Themed(t, paintTexture)
end
Menu.upArrow = arrowTexture("TOP", "Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Up")
Menu.downArrow = arrowTexture("BOTTOM", "Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up")

local function itemChecked(it)
    local c = it.checked
    if type(c) == "function" then
        return c(it) and true or false
    end
    return c
end

local function itemText(it)
    local t = it.text
    if type(t) == "function" then
        t = t(it)
    end
    return t or ""
end

local function menuRowClick(row)
    local it = row.item
    if not it or it.separator or it.isTitle or it.disabled then
        return
    end
    local checked = itemChecked(it)
    local newChecked = true
    if checked ~= nil and not it.radio then
        newChecked = not checked
        if type(it.checked) ~= "function" then
            it.checked = newChecked
        end
        W.Sound(newChecked and "on" or "off")
    else
        W.Sound("click")
    end
    if not it.keepOpen then
        Menu:Hide()
    end
    if it.func then
        ns.SafeCall(it.func, it.value, newChecked, it)
    end
    if it.keepOpen and Menu:IsShown() then
        Menu:Layout()
    end
end

local function menuRowEnter(row)
    local it = row.item
    if it and it.tooltip then
        W.ShowTip(row, it.tooltipTitle or itemText(it), it.tooltip, "ANCHOR_RIGHT")
    end
end

local function menuRow(i)
    local r = Menu.rows[i]
    if r then
        return r
    end
    r = CreateFrame("Button", nil, Menu)
    r:SetHeight(MENU_ROW)
    r.check = r:CreateTexture(nil, "ARTWORK")
    r.check:SetTexture(CHECKS)
    r.check:SetSize(16, 16)
    r.check:SetPoint("LEFT", 0, 0)
    r.text = r:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmallLeft")
    r.text:SetPoint("RIGHT", -2, 0)
    r.text:SetJustifyH("LEFT")
    r.text:SetWordWrap(false)
    r.sep = r:CreateTexture(nil, "ARTWORK")
    r.sep:SetColorTexture(1, 1, 1, 0.2)
    r.sep:SetHeight(1)
    r.sep:SetPoint("LEFT", 2, 0)
    r.sep:SetPoint("RIGHT", -2, 0)
    r.hl = r:CreateTexture(nil, "HIGHLIGHT")
    r.hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    r.hl:SetBlendMode("ADD")
    r.hl:SetAllPoints()
    W.Themed(r.hl, paintHighlight)
    r:SetScript("OnClick", menuRowClick)
    r:SetScript("OnEnter", menuRowEnter)
    r:SetScript("OnLeave", W.HideTip)
    Menu.rows[i] = r
    return r
end

function Menu:Layout()
    local items, pad = self.items or {}, self.pad
    for i = 1, self.visible do
        local it = items[i + self.offset]
        local r = menuRow(i)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", self, "TOPLEFT", pad, -pad - (i - 1) * MENU_ROW)
        r:SetPoint("TOPRIGHT", self, "TOPRIGHT", -pad, -pad - (i - 1) * MENU_ROW)
        r.item = it
        r.text:ClearAllPoints()
        r.text:SetPoint("LEFT", self.hasCheck and 18 or 2, 0)
        r.text:SetPoint("RIGHT", -2, 0)
        if not it then
            r:Hide()
        elseif it.separator then
            r.sep:Show()
            r.check:Hide()
            r.text:SetText("")
            r.hl:SetAlpha(0)
            r:Show()
        else
            r.sep:Hide()
            local inactive = it.isTitle or it.disabled
            r.hl:SetAlpha(inactive and 0 or 1)
            if it.isTitle then
                r.text:SetFontObject("RepKeeperFontNormalSmallLeft")
            elseif it.disabled then
                r.text:SetFontObject("GameFontDisableSmallLeft")
            else
                r.text:SetFontObject("GameFontHighlightSmallLeft")
            end
            r.text:SetText(itemText(it))
            if it.color and not inactive then
                r.text:SetTextColor(it.color[1], it.color[2], it.color[3])
            else
                local fo = r.text:GetFontObject()
                if type(fo) == "table" and fo.GetTextColor then
                    r.text:SetTextColor(fo:GetTextColor())
                end
            end
            local checked = itemChecked(it)
            if checked ~= nil or it.radio then
                r.check:Show()
                r.check:SetDesaturated(it.disabled and true or false)
                if it.radio then
                    if checked then
                        r.check:SetTexCoord(0, 0.5, 0.5, 1)
                    else
                        r.check:SetTexCoord(0.5, 1, 0.5, 1)
                    end
                elseif checked then
                    r.check:SetTexCoord(0, 0.5, 0, 0.5)
                else
                    r.check:SetTexCoord(0.5, 1, 0, 0.5)
                end
            else
                r.check:Hide()
            end
            r:Show()
        end
    end
    for i = self.visible + 1, #self.rows do
        self.rows[i]:Hide()
        self.rows[i].item = nil
    end
    self.upArrow:SetShown(self.offset > 0)
    self.downArrow:SetShown(self.offset + self.visible < #items)
end

-- items: { text, value, checked (bool|fn), radio, disabled, isTitle, separator, func(value, checked, item),
--          tooltip, tooltipTitle, color = {r,g,b}, keepOpen }
-- opts:  { style = "dropdown"|"context", cursor, point, relPoint, x, y, minWidth, onClose }
function Menu:Open(owner, items, opts)
    opts = opts or {}
    if self:IsShown() then
        self:Hide()
    end
    self.owner = owner
    self.items = items
    self.opts = opts
    self.offset = 0
    local context = opts.style == "context"
    W.SetBackdrop(self, context and "menu" or "dark")
    self.pad = context and 10 or 15
    local inset = context and 4 or 11
    self.under:ClearAllPoints()
    self.under:SetPoint("TOPLEFT", inset, -inset)
    self.under:SetPoint("BOTTOMRIGHT", -inset, inset)
    self:SetScale(W.Scale())

    local hasCheck = false
    local width = 0
    local measure = self.measure
    for _, it in ipairs(items) do
        if it.radio or it.checked ~= nil then
            hasCheck = true
        end
        if not it.separator then
            measure:SetFontObject(it.isTitle and "RepKeeperFontNormalSmallLeft" or "GameFontHighlightSmallLeft")
            measure:SetText(itemText(it))
            width = max(width, measure:GetStringWidth())
        end
    end
    self.hasCheck = hasCheck
    width = width + (hasCheck and 18 or 2) + 12
    width = max(width, (opts.minWidth or 0) - self.pad * 2, 60)
    self.visible = min(#items, MENU_MAX_ROWS)
    self:SetSize(floor(width + self.pad * 2 + 0.5), self.visible * MENU_ROW + self.pad * 2)

    self:ClearAllPoints()
    if opts.cursor or not owner then
        local x, y = GetCursorPosition()
        local s = self:GetEffectiveScale()
        self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / s - 4, y / s + 4)
    else
        self:SetPoint(opts.point or "TOPLEFT", owner, opts.relPoint or "BOTTOMLEFT", opts.x or 0, opts.y or 0)
    end
    self:Layout()
    self:Show()
end

function Menu:IsOpenFor(owner)
    return self:IsShown() and self.owner == owner
end

function Menu:Close()
    self:Hide()
end

Menu:SetScript("OnMouseWheel", function(self, delta)
    local n = self.items and #self.items or 0
    local maxOff = max(0, n - self.visible)
    self.offset = U.Clamp(self.offset - delta, 0, maxOff)
    self:Layout()
end)

Menu:SetScript("OnShow", function(self)
    self:RegisterEvent("GLOBAL_MOUSE_DOWN")
end)

Menu:SetScript("OnHide", function(self)
    self:UnregisterEvent("GLOBAL_MOUSE_DOWN")
    local onClose = self.opts and self.opts.onClose
    self.owner = nil
    if onClose then
        ns.SafeCall(onClose)
    end
end)

-- A click anywhere else closes the menu (a dropdown's own button opens and closes it, so a click there is left to it).
Menu:SetScript("OnEvent", function(self, event)
    if event == "GLOBAL_MOUSE_DOWN" then
        if self:IsMouseOver() then
            return
        end
        local owner = self.owner
        local context = self.opts and self.opts.style == "context"
        if not context and owner and owner.IsMouseOver and owner:IsVisible() and owner:IsMouseOver() then
            return
        end
        self:Hide()
    end
end)

function W.ContextMenu(owner, items)
    if #items == 0 then
        return
    end
    Menu:Open(owner, items, { style = "context", cursor = true })
end

---------------------------------------------------------------------------
-- Dropdown (the classic look; uses the shared menu instead of UIDropDownMenu)
---------------------------------------------------------------------------
local LABEL_FRAME = "Interface\\Glues\\CharacterCreate\\CharacterCreate-LabelFrame"

-- itemsFn: list or function returning a list of menu items; plain items (no func) act as radio choices.
-- opts: { label, textFn(value) -> text, empty, tip, tipTitle, menuWidth }
function W.Dropdown(parent, width, itemsFn, get, set, opts)
    opts = opts or {}
    local d = CreateFrame("Frame", nil, parent)
    d:SetSize(width + 50, 32)
    d.getter, d.setter, d.itemsFn = get, set, itemsFn

    local left = d:CreateTexture(nil, "ARTWORK")
    left:SetTexture(LABEL_FRAME)
    left:SetSize(25, 64)
    left:SetPoint("TOPLEFT", 0, 17)
    left:SetTexCoord(0, 0.1953125, 0, 1)
    local mid = d:CreateTexture(nil, "ARTWORK")
    mid:SetTexture(LABEL_FRAME)
    mid:SetSize(width, 64)
    mid:SetPoint("LEFT", left, "RIGHT")
    mid:SetTexCoord(0.1953125, 0.8046875, 0, 1)
    local right = d:CreateTexture(nil, "ARTWORK")
    right:SetTexture(LABEL_FRAME)
    right:SetSize(25, 64)
    right:SetPoint("LEFT", mid, "RIGHT")
    right:SetTexCoord(0.8046875, 1, 0, 1)
    d.middle = mid
    d.art = { left, mid, right }
    W.Themed(d, paintArt)

    d.text = d:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    d.text:SetWordWrap(false)
    d.text:SetJustifyH("RIGHT")
    d.text:SetHeight(10)
    d.text:SetWidth(max(10, width - 25))
    d.text:SetPoint("RIGHT", right, "RIGHT", -43, 2)

    local b = CreateFrame("Button", nil, d)
    b:SetSize(24, 24)
    b:SetPoint("TOPRIGHT", right, "TOPRIGHT", -16, -18)
    b:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
    b:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Down")
    b:SetDisabledTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Disabled")
    b:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    b:SetHitRectInsets(-(width + 4), 0, 0, 0)
    b:SetMotionScriptsWhileDisabled(true)
    W.ThemeArrowButton(b)
    d.button = b

    local function items()
        local list = d.itemsFn
        if type(list) == "function" then
            list = list()
        end
        return list or {}
    end

    function d:Refresh()
        local cur = self.getter and self.getter()
        local text = opts.textFn and opts.textFn(cur)
        if not text then
            for _, it in ipairs(items()) do
                if not it.isTitle and not it.separator and it.func == nil and it.value == cur then
                    text = itemText(it)
                    break
                end
            end
        end
        self.text:SetText(text or opts.empty or "")
    end

    function d:SetActive(on)
        if on then
            self.button:Enable()
            self.text:SetFontObject("GameFontHighlightSmall")
        else
            self.button:Disable()
            self.text:SetFontObject("GameFontDisableSmall")
            if Menu:IsOpenFor(self) then
                Menu:Hide()
            end
        end
    end

    function d:Open()
        if Menu:IsOpenFor(self) then
            Menu:Hide()
            return
        end
        local cur = self.getter and self.getter()
        local list = {}
        for _, it in ipairs(items()) do
            if it.func or it.isTitle or it.separator or it.checked ~= nil then
                list[#list + 1] = it
            else
                local value = it.value
                list[#list + 1] = {
                    text = it.text,
                    value = value,
                    radio = true,
                    checked = value == cur,
                    disabled = it.disabled,
                    tooltip = it.tooltip,
                    color = it.color,
                    func = function()
                        if d.setter then
                            d.setter(value, it)
                        end
                        d:Refresh()
                    end,
                }
            end
        end
        Menu:Open(self, list, {
            style = "dropdown",
            point = "TOPLEFT",
            relPoint = "BOTTOMLEFT",
            x = 8,
            y = 6,
            minWidth = opts.menuWidth or (width + 30),
        })
    end

    b:SetScript("OnClick", function()
        W.Sound("click")
        d:Open()
    end)
    if opts.tip then
        W.AttachTooltip(b, opts.tipTitle or opts.label, opts.tip)
    end
    d:Refresh()
    return d
end

---------------------------------------------------------------------------
-- Slider (the classic options slider)
---------------------------------------------------------------------------
function W.Slider(parent, label, minV, maxV, step, get, set, fmt, width)
    local s = CreateFrame("Slider", nil, parent, "BackdropTemplate")
    s:SetOrientation("HORIZONTAL")
    s:SetSize(width or 180, 17)
    s:SetHitRectInsets(0, 0, -10, -10)
    W.SetBackdrop(s, "slider")
    s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    local thumb = s:GetThumbTexture()
    if thumb then
        thumb:SetSize(32, 32)
    end
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(step or 1)
    s:SetObeyStepOnDrag(true)
    s.getter, s.setter = get, set
    fmt = fmt or "%d"

    s.label = s:CreateFontString(nil, "ARTWORK", "RepKeeperFontNormalSmall")
    s.label:SetPoint("BOTTOM", s, "TOP", 0, 2)
    s.label:SetText(label or "")
    s.low = s:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    s.low:SetPoint("TOPLEFT", s, "BOTTOMLEFT", 2, 3)
    s.high = s:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    s.high:SetPoint("TOPRIGHT", s, "BOTTOMRIGHT", -2, 3)
    s.value = s:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    s.value:SetPoint("TOP", s, "BOTTOM", 0, 3)

    local function show(v)
        if type(fmt) == "function" then
            return fmt(v)
        end
        return string.format(fmt, v)
    end
    s.low:SetText(show(minV))
    s.high:SetText(show(maxV))

    local function snap(v)
        local st = step or 1
        v = floor((v - minV) / st + 0.5) * st + minV
        return U.Clamp(v, minV, maxV)
    end

    -- The value only reaches the setter when the mouse lets go (the UI size slider resizes the window it is in).
    s:SetScript("OnValueChanged", function(self, v)
        v = snap(v)
        self.value:SetText(show(v))
        if not self.updating then
            self.dirty = v
        end
    end)
    s:SetScript("OnMouseUp", function(self)
        local v = self.dirty
        self.dirty = nil
        if v ~= nil and self.setter and v ~= self.last then
            self.last = v
            self.setter(v)
        end
    end)
    s:EnableMouseWheel(true)
    s:SetScript("OnMouseWheel", function(self, delta)
        if not self:IsEnabled() then
            return
        end
        local v = snap(self:GetValue() + delta * (step or 1))
        self.updating = true
        self:SetValue(v)
        self.updating = false
        self.value:SetText(show(v))
        if self.setter and v ~= self.last then
            self.last = v
            self.setter(v)
        end
    end)

    function s:Refresh()
        if not self.getter then
            return
        end
        local v = self.getter() or minV
        self.updating = true
        self.last = v
        self:SetValue(v)
        self.value:SetText(show(v))
        self.updating = false
    end

    function s:SetActive(on)
        self:SetEnabled(on)
        self.label:SetFontObject(on and "RepKeeperFontNormalSmall" or "GameFontDisableSmall")
    end

    s:Refresh()
    return s
end

---------------------------------------------------------------------------
-- Scroll frames and text areas
---------------------------------------------------------------------------
local scrollCount = 0
function W.ScrollFrame(parent)
    scrollCount = scrollCount + 1
    local sf = CreateFrame("ScrollFrame", "RepKeeperScroll" .. scrollCount, parent, "UIPanelScrollFrameTemplate")
    -- The scroll bar only shows when there is something to scroll (Blizzard's template reads this).
    sf.scrollBarHideable = true
    local bar = sf.ScrollBar
    if bar then
        bar.scrollStep = 40
        W.ThemeScrollBar(bar)
    end
    return sf
end

-- Scrolling panel with a content child (option pages).
function W.ScrollPanel(parent)
    local sf = W.ScrollFrame(parent)
    local content = CreateFrame("Frame", nil, sf)
    content:SetSize(10, 10)
    sf:SetScrollChild(content)
    sf:HookScript("OnSizeChanged", function(_, w)
        content:SetWidth(max(10, w))
    end)
    sf.content = content
    return sf, content
end

-- Multi-line text in a box: a note to write, or a long string to copy out or paste in.
-- opts: { readOnly, font, maxLetters, placeholder, noBar (scrolls with the wheel only), onChange(text),
--         onCommit(text) (when the box loses the keyboard) }
function W.TextArea(parent, opts)
    opts = opts or {}
    local box = W.Frame(parent, "box")
    box.readOnly = opts.readOnly
    local sf
    if opts.noBar then
        sf = CreateFrame("ScrollFrame", nil, box)
        sf:SetPoint("TOPLEFT", 8, -6)
        sf:SetPoint("BOTTOMRIGHT", -8, 6)
        sf:EnableMouseWheel(true)
        sf:SetScript("OnMouseWheel", function(self, delta)
            local range = self:GetVerticalScrollRange() or 0
            self:SetVerticalScroll(U.Clamp(self:GetVerticalScroll() - delta * 14, 0, range))
        end)
    else
        sf = W.ScrollFrame(box)
        sf:SetPoint("TOPLEFT", 8, -8)
        sf:SetPoint("BOTTOMRIGHT", -30, 8)
    end
    local eb = CreateFrame("EditBox", nil, sf)
    eb:SetMultiLine(true)
    eb:SetAutoFocus(false)
    eb:SetFontObject(opts.font or "ChatFontNormal")
    eb:SetWidth(200)
    eb:SetMaxLetters(opts.maxLetters or 0)
    eb:SetTextInsets(2, 2, 2, 2)
    sf:SetScrollChild(eb)
    sf:HookScript("OnSizeChanged", function(_, w)
        eb:SetWidth(max(10, w))
    end)
    sf:EnableMouse(true)
    sf:SetScript("OnMouseDown", function()
        eb:SetFocus()
    end)
    box.edit, box.scroll = eb, sf

    local ph
    if opts.placeholder then
        ph = box:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
        ph:SetPoint("TOPLEFT", 11, -9)
        ph:SetPoint("TOPRIGHT", -11, -9)
        ph:SetJustifyH("LEFT")
        ph:SetJustifyV("TOP")
        ph:SetText(opts.placeholder)
        box.placeholder = ph
    end
    local function updatePlaceholder()
        if ph then
            ph:SetShown(eb:GetText() == "" and not eb:HasFocus())
        end
    end

    eb:SetScript("OnEscapePressed", eb.ClearFocus)
    eb:SetScript("OnEditFocusGained", updatePlaceholder)
    eb:SetScript("OnEditFocusLost", function(self)
        updatePlaceholder()
        if opts.onCommit and not box.readOnly then
            opts.onCommit(self:GetText())
        end
    end)
    eb:SetScript("OnTextChanged", function(self, user)
        updatePlaceholder()
        if user and box.readOnly and self.fixed then
            self:SetText(self.fixed)
            self:HighlightText()
            return
        end
        if opts.onChange and user then
            opts.onChange(self:GetText())
        end
    end)
    eb:SetScript("OnCursorChanged", function(_, _, y, _, h)
        local top = sf:GetVerticalScroll()
        local height = sf:GetHeight()
        y = -y
        if y < top then
            sf:SetVerticalScroll(y)
        elseif y + h > top + height then
            sf:SetVerticalScroll(max(0, y + h - height))
        end
    end)

    function box:SetText(text)
        text = text or ""
        eb.fixed = text
        eb:SetText(text)
        eb:SetCursorPosition(0)
        sf:SetVerticalScroll(0)
        updatePlaceholder()
    end

    function box:GetText()
        return eb:GetText()
    end

    function box:HasFocus()
        return eb:HasFocus()
    end

    function box:SetFocus()
        eb:SetFocus()
    end

    function box:SelectAll()
        eb:SetFocus()
        eb:HighlightText()
    end

    updatePlaceholder()
    return box
end

-- A thin bar without a border (the time left on a pop-up).
function W.TimerBar(parent, height)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetHeight(height or 4)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1)
    bar.track = bar:CreateTexture(nil, "BACKGROUND")
    bar.track:SetAllPoints()
    bar.track:SetColorTexture(0, 0, 0, 0.45)
    return bar
end

---------------------------------------------------------------------------
-- List with column headers, virtual rows and a classic scroll bar.
-- cols: { key, label, width | fill = true, get(item) -> text, r, g, b, sortValue(item), justify, tip, defaultDesc }
-- opts: { rowHeight, noHeader, onClick(item, row, button), onEnter(item, row), selectKey(item), sortKey, sortDesc,
--         empty, decorate(row, item, list) }
---------------------------------------------------------------------------
local HEADER_TEX = "Interface\\FriendsFrame\\WhoFrame-ColumnTabs"
local SORT_ARROW = "Interface\\Buttons\\UI-SortArrow"

local List = {}

local function paintHeaderButton(b, th)
    paintArt(b, th)
    local a = th.accent
    W.Tint(b.arrow, th.metal and a)
end

local function listHeaderButton(list, col)
    local b = CreateFrame("Button", nil, list.header)
    b:SetHeight(24)
    local l = b:CreateTexture(nil, "BACKGROUND")
    l:SetTexture(HEADER_TEX)
    l:SetSize(5, 24)
    l:SetPoint("TOPLEFT")
    l:SetTexCoord(0, 0.078125, 0, 0.75)
    local r = b:CreateTexture(nil, "BACKGROUND")
    r:SetTexture(HEADER_TEX)
    r:SetSize(4, 24)
    r:SetPoint("TOPRIGHT")
    r:SetTexCoord(0.90625, 0.96875, 0, 0.75)
    local m = b:CreateTexture(nil, "BACKGROUND")
    m:SetTexture(HEADER_TEX)
    m:SetPoint("TOPLEFT", l, "TOPRIGHT")
    m:SetPoint("BOTTOMRIGHT", r, "BOTTOMLEFT")
    m:SetTexCoord(0.078125, 0.90625, 0, 0.75)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-Tab-Highlight")
    hl:SetBlendMode("ADD")
    hl:SetPoint("TOPLEFT", 2, 0)
    hl:SetPoint("BOTTOMRIGHT", -2, 0)
    b.art = { l, r, m }

    local fs = b:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    fs:SetPoint("LEFT", 8, 0)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    fs:SetText(col.label or "")
    b.text = fs

    b.arrow = b:CreateTexture(nil, "ARTWORK")
    b.arrow:SetSize(9, 8)
    b.arrow:SetPoint("LEFT", fs, "RIGHT", 3, -2)
    b.arrow:SetTexture(SORT_ARROW)
    b.arrow:Hide()
    W.Themed(b, paintHeaderButton)

    b.col = col
    if col.sortValue then
        b:SetScript("OnClick", function()
            W.Sound("click")
            list:ToggleSort(col.key)
        end)
    else
        b:EnableMouse(col.tip ~= nil)
        hl:SetAlpha(0)
    end
    if col.tip then
        W.AttachTooltip(b, col.label, col.tip)
    end
    return b
end

local function rowClick(row, button)
    local list, item = row.list, row.item
    if not item then
        return
    end
    local opts = list.opts
    if opts.selectKey and button ~= "RightButton" then
        list.selected = opts.selectKey(item)
        list:Refresh()
    end
    if opts.onClick then
        opts.onClick(item, row, button)
    end
end

local function rowEnter(row)
    local list, item = row.list, row.item
    if item and list.opts.onEnter then
        list.opts.onEnter(item, row)
    end
end

local function makeRow(list, i)
    local row = CreateFrame("Button", nil, list.body)
    row:SetHeight(list.rowH)
    row:SetPoint("TOPLEFT", list.body, "TOPLEFT", 0, -(i - 1) * list.rowH)
    row:SetPoint("TOPRIGHT", list.body, "TOPRIGHT", 0, -(i - 1) * list.rowH)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    hl:SetBlendMode("ADD")
    hl:SetAllPoints()
    row:SetHighlightTexture(hl)
    W.Themed(hl, paintHighlight)
    row.list = list
    row.cells = {}
    for c, col in ipairs(list.cols) do
        local fs = row:CreateFontString(nil, "ARTWORK", col.font or "GameFontHighlightSmall")
        fs:SetJustifyH(col.justify or "LEFT")
        fs:SetWordWrap(false)
        fs.dr, fs.dg, fs.db = fs:GetTextColor()
        row.cells[c] = fs
    end
    row:SetScript("OnClick", rowClick)
    row:SetScript("OnEnter", rowEnter)
    row:SetScript("OnLeave", W.HideTip)
    list.rows[i] = row
    list:LayoutRow(row)
    return row
end

function List:ColumnLayout()
    local total = self.header:GetWidth()
    if not total or total <= 0 then
        total = self:GetWidth() - 32
    end
    local fixed, fills = 0, 0
    for _, col in ipairs(self.cols) do
        if col.fill then
            fills = fills + 1
        else
            fixed = fixed + (col.width or 60)
        end
    end
    local fillW = fills > 0 and max(40, floor((total - fixed) / fills)) or 0
    local x = 0
    self.colX, self.colW = self.colX or {}, self.colW or {}
    for c, col in ipairs(self.cols) do
        local w = col.fill and fillW or (col.width or 60)
        self.colX[c], self.colW[c] = x, w
        x = x + w
    end
    if self.headers then
        for c, b in ipairs(self.headers) do
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", self.header, "TOPLEFT", self.colX[c], 0)
            b:SetWidth(self.colW[c])
            b.text:SetWidth(max(10, self.colW[c] - 22))
        end
    end
    for _, row in ipairs(self.rows) do
        self:LayoutRow(row)
    end
end

function List:LayoutRow(row)
    if not self.colX then
        return
    end
    for c, fs in ipairs(row.cells) do
        fs:ClearAllPoints()
        fs:SetPoint("LEFT", row, "LEFT", self.colX[c] + 6, 0)
        fs:SetWidth(max(8, self.colW[c] - 10))
    end
    if row.item and self.opts.decorate then
        self.opts.decorate(row, row.item, self)
    end
end

-- Left edge and width of a column (by key) inside a row.
function List:Column(key)
    for c, col in ipairs(self.cols) do
        if col.key == key then
            return self.colX[c] or 0, self.colW[c] or 0
        end
    end
    return 0, 0
end

function List:UpdateRowCount()
    local h = self.body:GetHeight() or 0
    local n = max(0, floor(h / self.rowH))
    self.numRows = n
    for i = #self.rows + 1, n do
        makeRow(self, i)
    end
end

function List:UpdateSortArrows()
    if not self.headers then
        return
    end
    for _, b in ipairs(self.headers) do
        if b.col.key == self.sortKey and b.col.sortValue then
            b.arrow:Show()
            if self.sortDesc then
                b.arrow:SetTexCoord(0, 0.5625, 1, 0)
            else
                b.arrow:SetTexCoord(0, 0.5625, 0, 1)
            end
            b.text:SetFontObject("RepKeeperFontNormalSmall")
        else
            b.arrow:Hide()
            b.text:SetFontObject("GameFontHighlightSmall")
        end
    end
end

function List:Sort()
    local view = self.view
    wipe(view)
    for i, item in ipairs(self.data) do
        view[i] = item
    end
    local col
    for _, c in ipairs(self.cols) do
        if c.key == self.sortKey then
            col = c
            break
        end
    end
    if not col or not col.sortValue then
        return
    end
    local vals, order = {}, {}
    for i, item in ipairs(view) do
        vals[item] = col.sortValue(item)
        order[item] = i
    end
    local desc = self.sortDesc
    table.sort(view, function(a, b)
        local va, vb = vals[a], vals[b]
        if va ~= vb then
            if va == nil then
                return false
            elseif vb == nil then
                return true
            end
            if desc then
                return va > vb
            end
            return va < vb
        end
        return order[a] < order[b]
    end)
end

function List:ToggleSort(key)
    if self.sortKey == key then
        self.sortDesc = not self.sortDesc
    else
        self.sortKey = key
        self.sortDesc = false
        for _, c in ipairs(self.cols) do
            if c.key == key then
                self.sortDesc = c.defaultDesc and true or false
            end
        end
    end
    if self.opts.onSort then
        self.opts.onSort(self.sortKey, self.sortDesc)
    end
    self:UpdateSortArrows()
    self:Sort()
    self:Refresh()
end

function List:SetData(data)
    self.data = data or {}
    self:Sort()
    self:Refresh()
end

function List:GetView()
    return self.view
end

function List:SetEmptyText(text)
    self.emptyText:SetText(text or "")
end

function List:SetOffset(offset)
    local maxOff = max(0, #self.view - (self.numRows or 0))
    offset = U.Clamp(floor(offset + 0.5), 0, maxOff)
    if offset ~= self.offset then
        self.offset = offset
        self:Refresh()
    end
end

-- Scrolls just enough to show the item.
function List:ScrollToItem(item)
    for i, it in ipairs(self.view) do
        if it == item then
            local visible = self.numRows or 0
            if i <= self.offset then
                self:SetOffset(i - 1)
            elseif visible > 0 and i > self.offset + visible then
                self:SetOffset(i - visible)
            end
            return true
        end
    end
    return false
end

function List:Refresh()
    local view = self.view
    local n = #view
    local visible = self.numRows or 0
    local maxOff = max(0, n - visible)
    if self.offset > maxOff then
        self.offset = maxOff
    end
    local bar = self.bar
    self.updating = true
    bar:SetMinMaxValues(0, maxOff)
    bar:SetValue(self.offset)
    self.updating = false
    local thumb = bar:GetThumbTexture()
    if thumb then
        thumb:SetShown(maxOff > 0)
    end
    -- No scroll bar when everything fits.
    bar:SetShown(maxOff > 0)
    if bar.ScrollUpButton then
        bar.ScrollUpButton:SetEnabled(self.offset > 0)
        bar.ScrollDownButton:SetEnabled(self.offset < maxOff)
    end

    local selectKey, selected = self.opts.selectKey, self.selected
    for i, row in ipairs(self.rows) do
        local item = i <= visible and view[self.offset + i] or nil
        row.item = item
        if item then
            for c, col in ipairs(self.cols) do
                local fs = row.cells[c]
                local text, r, g, b = col.get(item)
                fs:SetText(text or "")
                if r then
                    fs:SetTextColor(r, g, b)
                else
                    fs:SetTextColor(fs.dr, fs.dg, fs.db)
                end
            end
            if selectKey and selected ~= nil and selectKey(item) == selected then
                row:LockHighlight()
            else
                row:UnlockHighlight()
            end
            if self.opts.decorate then
                self.opts.decorate(row, item, self)
            end
            row:Show()
        else
            row:Hide()
        end
    end
    self.emptyText:SetShown(n == 0)
end

function W.List(parent, cols, opts)
    opts = opts or {}
    local list = W.Frame(parent, "box")
    for k, v in pairs(List) do
        list[k] = v
    end
    list.cols, list.opts = cols, opts
    list.rowH = opts.rowHeight or 18
    list.data, list.view, list.rows = {}, {}, {}
    list.offset, list.numRows = 0, 0
    list.sortKey, list.sortDesc = opts.sortKey, opts.sortDesc and true or false

    local header = CreateFrame("Frame", nil, list)
    header:SetPoint("TOPLEFT", 6, -5)
    header:SetPoint("TOPRIGHT", -26, -5)
    header:SetHeight(opts.noHeader and 1 or 24)
    list.header = header
    if not opts.noHeader then
        list.headers = {}
        for c, col in ipairs(cols) do
            list.headers[c] = listHeaderButton(list, col)
        end
    end

    local body = CreateFrame("Frame", nil, list)
    body:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, opts.noHeader and 0 or -1)
    body:SetPoint("BOTTOMRIGHT", -26, 6)
    body:EnableMouseWheel(true)
    list.body = body

    local bar = CreateFrame("Slider", nil, list, "UIPanelScrollBarTemplate")
    -- Replace the template's handler first: it scrolls its parent, which is not a ScrollFrame here.
    bar:SetScript("OnValueChanged", function(_, value)
        if not list.updating then
            list:SetOffset(value)
        end
    end)
    bar:SetPoint("TOPRIGHT", list, "TOPRIGHT", -6, -21)
    bar:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", -6, 21)
    bar:SetMinMaxValues(0, 0)
    bar:SetValueStep(1)
    bar:SetObeyStepOnDrag(true)
    bar.scrollStep = 3
    bar:SetValue(0)
    local track = bar:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    track:SetColorTexture(0, 0, 0, 0.3)
    W.ThemeScrollBar(bar)
    list.bar = bar

    body:SetScript("OnMouseWheel", function(_, delta)
        list:SetOffset(list.offset - delta * 3)
    end)
    body:SetScript("OnSizeChanged", function()
        list:UpdateRowCount()
        list:Refresh()
    end)
    header:SetScript("OnSizeChanged", function()
        list:ColumnLayout()
    end)

    list.emptyText = body:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    list.emptyText:SetPoint("TOPLEFT", 16, -30)
    list.emptyText:SetPoint("TOPRIGHT", -16, -30)
    list.emptyText:SetJustifyH("CENTER")
    list.emptyText:SetText(opts.empty or L["Nothing to show."])
    list.emptyText:Hide()

    list:ColumnLayout()
    list:UpdateSortArrows()
    return list
end

---------------------------------------------------------------------------
-- Windows: the header plate, position memory and the UI size
---------------------------------------------------------------------------
function W.Header(frame, title)
    local h = CreateFrame("Frame", nil, frame)
    h:SetHeight(40)
    h:SetPoint("TOP", 0, 12)
    local tex = "Interface\\DialogFrame\\UI-DialogBox-Header"
    local l = h:CreateTexture(nil, "ARTWORK")
    l:SetTexture(tex)
    l:SetTexCoord(0.21, 0.31, 0, 0.63)
    l:SetPoint("TOPLEFT")
    l:SetPoint("BOTTOMLEFT")
    l:SetWidth(30)
    local r = h:CreateTexture(nil, "ARTWORK")
    r:SetTexture(tex)
    r:SetTexCoord(0.67, 0.77, 0, 0.63)
    r:SetPoint("TOPRIGHT")
    r:SetPoint("BOTTOMRIGHT")
    r:SetWidth(30)
    local m = h:CreateTexture(nil, "ARTWORK")
    m:SetTexture(tex)
    m:SetTexCoord(0.31, 0.67, 0, 0.63)
    m:SetPoint("TOPLEFT", l, "TOPRIGHT")
    m:SetPoint("BOTTOMRIGHT", r, "BOTTOMLEFT")
    h.art = { l, r, m }
    W.Themed(h, paintArt)
    h.text = h:CreateFontString(nil, "OVERLAY", "RepKeeperFontTitle")
    h.text:SetPoint("TOP", 0, -14)

    function h:SetTitle(t)
        self.text:SetText(t or "")
        self:SetWidth(max(160, floor(self.text:GetStringWidth() + 80)))
    end

    h:EnableMouse(true)
    h:RegisterForDrag("LeftButton")
    h:SetScript("OnDragStart", function()
        W.StartMoving(frame)
    end)
    h:SetScript("OnDragStop", function()
        W.StopMoving(frame)
    end)
    h:SetTitle(title)
    return h
end

function W.SavePos(f)
    local name = f:GetName()
    local ui = UIS()
    if not name or not ui then
        return
    end
    local point, _, relPoint, x, y = f:GetPoint(1)
    if not point then
        return
    end
    ui.pos[name] = { point = point, relPoint = relPoint, x = floor(x + 0.5), y = floor(y + 0.5) }
end

function W.RestorePos(f, point, relPoint, x, y)
    local name = f:GetName()
    local ui = UIS()
    local p = name and ui and ui.pos[name]
    f:ClearAllPoints()
    if p then
        f:SetPoint(p.point or "CENTER", UIParent, p.relPoint or "CENTER", p.x or 0, p.y or 0)
    else
        f:SetPoint(point or "CENTER", UIParent, relPoint or point or "CENTER", x or 0, y or 0)
    end
end

function W.StartMoving(f)
    f.moving = true
    f:StartMoving()
end

function W.StopMoving(f)
    if not f.moving then
        return
    end
    f.moving = false
    f:StopMovingOrSizing()
    -- The game anchors a moved frame however it likes; keep it relative to the screen's centre (stays put at any size).
    local cx, cy = f:GetCenter()
    local ux, uy = UIParent:GetCenter()
    if cx and ux then
        local s = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
        f:ClearAllPoints()
        f:SetPoint("CENTER", UIParent, "CENTER", cx - ux / s, cy - uy / s)
    end
    W.SavePos(f)
end

-- The biggest window there is (the main window), for the UI size limit.
W.MAX_WIDTH, W.MAX_HEIGHT = 860, 520

-- The UI size: the saved setting, but never bigger than the screen can hold (the window with its header and tabs).
function W.Scale()
    local ui = UIS()
    local s = U.Clamp(tonumber(ui and ui.scale) or 1, 0.7, 1.5)
    local w, h = UIParent:GetWidth(), UIParent:GetHeight()
    if w and h and w > 0 and h > 0 then
        s = min(s, w / (W.MAX_WIDTH + 40), h / (W.MAX_HEIGHT + 60))
    end
    return s
end

-- The UI size changed: every window keeps its centre where it is on the screen.
function W.ApplyScale()
    local s = W.Scale()
    for _, f in ipairs(W.windows) do
        local old = f:GetScale()
        if old ~= s then
            local point, rel, relPoint, x, y = f:GetPoint(1)
            f:SetScale(s)
            if point then
                f:ClearAllPoints()
                f:SetPoint(point, rel, relPoint, x * old / s, y * old / s)
                W.SavePos(f)
            end
        end
    end
end

-- Top-level window with the classic dialog border and header plate. Among the game's own windows (MEDIUM, like the
-- bags and the character window) unless opts.strata says otherwise: the one opened or clicked last is in front.
-- opts: { strata, sound, noEscape, solid (no see-through background: pop-ups), point, relPoint, x, y (where it opens
--         the first time) }
function W.Window(name, title, width, height, opts)
    opts = opts or {}
    local f = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
    f:Hide()
    f:SetSize(width, height)
    f:SetFrameStrata(opts.strata or "MEDIUM")
    f:SetClampedToScreen(true)
    f:SetToplevel(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetDontSavePosition(true)
    f:SetScript("OnDragStart", W.StartMoving)
    f:SetScript("OnDragStop", W.StopMoving)
    W.SetBackdrop(f, "dark")
    if opts.solid then
        -- Pop-ups over other windows: the dialog background is see-through, and what is behind must not show.
        local under = f:CreateTexture(nil, "BACKGROUND", nil, -8)
        under:SetPoint("TOPLEFT", 11, -12)
        under:SetPoint("BOTTOMRIGHT", -12, 11)
        under:SetColorTexture(0, 0, 0, 0.75)
    end
    f.header = W.Header(f, title)
    f:SetClampRectInsets(0, 0, 12, 0)
    f.close = W.CloseButton(f)
    if name and not opts.noEscape then
        table.insert(UISpecialFrames, name)
    end
    f:SetScript("OnShow", function(self)
        self:SetScale(W.Scale())
        if opts.sound then
            W.Sound("open")
        end
        if self.onShown then
            self:onShown()
        end
    end)
    f:SetScript("OnHide", function(self)
        W.StopMoving(self)
        if Menu.owner and Menu.owner.IsVisible and not Menu.owner:IsVisible() then
            Menu:Hide()
        end
        if opts.sound then
            W.Sound("close")
        end
        if self.onHidden then
            self:onHidden()
        end
    end)
    f:SetScale(W.Scale())
    W.windows[#W.windows + 1] = f
    W.RestorePos(f, opts.point, opts.relPoint, opts.x, opts.y)
    return f
end

---------------------------------------------------------------------------
-- Bottom tabs (character-frame style), tucked under the window border.
---------------------------------------------------------------------------
local TAB_ACTIVE = "Interface\\PaperDollInfoFrame\\UI-Character-ActiveTab"
local TAB_INACTIVE = "Interface\\PaperDollInfoFrame\\UI-Character-InActiveTab"
W.TAB_TUCK = 6

local function tabPieces(t, file, atlasPrefix, height, top, bottom, y)
    local pieces = {}
    local useFile = U.TexExists(file)
    local coords = { { 0, 0.15625 }, { 0.15625, 0.84375 }, { 0.84375, 1 } }
    local atlases = { atlasPrefix .. "-left", "_" .. atlasPrefix .. "-center", atlasPrefix .. "-right" }
    for i = 1, 3 do
        local tex = t:CreateTexture(nil, "BACKGROUND")
        if useFile then
            tex:SetTexture(file)
            tex:SetTexCoord(coords[i][1], coords[i][2], top, bottom)
        else
            tex:SetAtlas(atlases[i])
        end
        tex:SetHeight(height)
        pieces[i] = tex
    end
    pieces[1]:SetWidth(20)
    pieces[3]:SetWidth(20)
    pieces[1]:SetPoint("TOPLEFT", 0, y)
    pieces[2]:SetPoint("LEFT", pieces[1], "RIGHT")
    pieces[3]:SetPoint("LEFT", pieces[2], "RIGHT")
    return pieces
end

function W.Tab(parent, text)
    local t = CreateFrame("Button", nil, parent)
    t:SetHeight(32)
    t.inactive = tabPieces(t, TAB_INACTIVE, "uiframe-tab", 32, 0, 1, -1)
    t.active = tabPieces(t, TAB_ACTIVE, "uiframe-activetab", 35, 0, 0.546875, 0)
    t.art = { t.inactive[1], t.inactive[2], t.inactive[3], t.active[1], t.active[2], t.active[3] }
    W.Themed(t, paintArt)
    local fs = t:CreateFontString(nil, "OVERLAY", "RepKeeperFontNormalSmall")
    fs:SetPoint("CENTER", 0, -2)
    t:SetFontString(fs)
    t:SetNormalFontObject("RepKeeperFontNormalSmall")
    t:SetHighlightFontObject("GameFontHighlightSmall")
    t:SetDisabledFontObject("RepKeeperFontSelectedSmall")
    local hlFile = U.TexExists("Interface\\PaperDollInfoFrame\\UI-Character-Tab-RealHighlight")
        and "Interface\\PaperDollInfoFrame\\UI-Character-Tab-RealHighlight"
        or "Interface\\PaperDollInfoFrame\\UI-Character-Tab-Highlight"
    local hl = t:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture(hlFile)
    hl:SetBlendMode("ADD")
    hl:SetPoint("TOPLEFT", 3, -W.TAB_TUCK + 2)
    hl:SetPoint("BOTTOMRIGHT", -3, 0)
    t:SetText(text)

    function t:Resize()
        local w = max(40, floor(fs:GetStringWidth() or 0) + 12)
        for _, set in ipairs({ self.inactive, self.active }) do
            set[2]:SetWidth(w)
        end
        self:SetWidth(w + 40)
    end

    function t:SetSelected(on)
        for i = 1, 3 do
            self.inactive[i]:SetShown(not on)
            self.active[i]:SetShown(on)
        end
        self:SetEnabled(not on)
        fs:SetPoint("CENTER", 0, on and -3 or -2)
    end

    t:Resize()
    t:SetSelected(false)
    return t
end

-- Tabs sit one frame level below the window so its border overlaps them.
function W.TabBar(frame, defs, onSelect)
    local bar = { tabs = {}, byId = {}, frame = frame }
    local prev
    for i, def in ipairs(defs) do
        local t = W.Tab(frame, def.label)
        t:SetFixedFrameLevel(true)
        if i == 1 then
            t:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 12, W.TAB_TUCK)
        else
            t:SetPoint("LEFT", prev, "RIGHT", -15, 0)
        end
        t.id = def.id
        if def.tip then
            W.AttachTooltip(t, def.label, def.tip, "ANCHOR_BOTTOM")
        end
        t:SetScript("OnClick", function()
            W.Sound("tab")
            bar:Select(def.id)
        end)
        bar.tabs[i] = t
        bar.byId[def.id] = t
        prev = t
    end

    function bar:Relevel()
        local level = max(1, self.frame:GetFrameLevel() - 1)
        for _, t in ipairs(self.tabs) do
            t:SetFrameLevel(level)
        end
    end

    function bar:Select(id)
        if not self.byId[id] then
            id = self.tabs[1].id
        end
        self.selected = id
        for _, x in ipairs(self.tabs) do
            x:SetSelected(x.id == id)
        end
        if onSelect then
            onSelect(id)
        end
    end

    bar:Relevel()
    frame:SetClampRectInsets(0, 0, 12, -28)
    frame.tabs = bar
    return bar
end

-- A click on a window raises it (it is toplevel). Its tabs have a fixed level so that its border is drawn over them;
-- they follow on the next frame.
local function relevelTabs()
    for _, f in ipairs(W.windows) do
        if f.tabs and f:IsShown() then
            f.tabs:Relevel()
        end
    end
end

local tabWatcher = CreateFrame("Frame")
tabWatcher:RegisterEvent("GLOBAL_MOUSE_DOWN")
tabWatcher:SetScript("OnEvent", function()
    for _, f in ipairs(W.windows) do
        if f.tabs and f:IsShown() then
            C_Timer.After(0, relevelTabs)
            return
        end
    end
end)

---------------------------------------------------------------------------
-- Vertical layout for option pages. Every control registers a refresher; Stack:Refresh() re-reads all values and
-- dependency states. Every call adds a row (kind "header", "text", "control" or "gap"; label, tip, keywords, indent,
-- the section header it is under). Stack:Layout(match) shows only the rows match(row) accepts, with their section
-- headers and the rows they are indented under, plus rows whose opts.visible() allows them, and closes the gaps.
---------------------------------------------------------------------------
local Stack = {}
Stack.__index = Stack

function W.Stack(parent, left, top, width)
    return setmetatable({
        parent = parent,
        x = left or 16,
        y = -(top or 16),
        top = -(top or 16),
        width = width or 300,
        controls = {},
        rows = {},
    }, Stack)
end

-- Starts a row at the cursor. opts: indent, keywords (extra words for the search), visible() (shown at all).
function Stack:Row(kind, label, tip, opts)
    local row = {
        kind = kind,
        label = label,
        tip = tip,
        keywords = opts and opts.keywords,
        indent = opts and opts.indent or 0,
        visible = opts and opts.visible,
        section = kind ~= "header" and self.section or nil,
        top = self.y,
        frames = {},
    }
    if kind == "header" then
        self.section = row
    end
    self.rows[#self.rows + 1] = row
    self.row = row
    return row
end

-- Places a frame of the current row at x, y (TOPLEFT, relative to the stack's parent).
function Stack:Put(f, x, y)
    f:SetPoint("TOPLEFT", x, y)
    local row = self.row
    row.frames[#row.frames + 1] = { f = f, x = x, dy = y - row.top }
    return f
end

-- Adds a frame anchored to another frame of the current row (shown and hidden with it), and words for the search.
function Stack:Attach(f, text)
    local row = self.row
    row.frames[#row.frames + 1] = { f = f, rel = true }
    if text then
        row.extra = (row.extra and (row.extra .. " ") or "") .. text
    end
    return f
end

function Stack:EndRow()
    local row = self.row
    row.h = row.top - self.y
    row.h0 = row.h
    return row
end

function Stack:Track(widget, opts)
    self.controls[#self.controls + 1] = { w = widget, dep = opts and opts.dep }
    return widget
end

function Stack:Refresh()
    for _, c in ipairs(self.controls) do
        -- Refresh and SetActive are the widget's own (set on it), not methods every frame has.
        local refresh = rawget(c.w, "Refresh")
        if refresh then
            refresh(c.w)
        end
        local setActive = c.dep and rawget(c.w, "SetActive")
        if setActive then
            setActive(c.w, c.dep() and true or false)
        end
    end
    -- Rows that come and go with a setting (opts.visible) close or open their gap.
    self:Layout(self.match)
end

local function rowAllowed(row)
    return not row.visible or row.visible() and true or false
end

-- Which rows show: match(row) for controls and texts (all of them without match), the rows an indented row belongs
-- to, and section headers with anything shown under them.
local function shownRows(rows, match)
    local show = {}
    for i, row in ipairs(rows) do
        local on = rowAllowed(row)
        if row.kind == "gap" then
            on = on and not match
        elseif row.kind ~= "header" and on and match then
            on = match(row) and true or false
        end
        show[i] = on and row.kind ~= "header"
    end
    for i, row in ipairs(rows) do
        if show[i] and row.indent > 0 then
            local indent = row.indent
            for j = i - 1, 1, -1 do
                local p = rows[j]
                if p.kind == "header" then
                    break
                end
                if p.kind ~= "gap" and p.indent < indent then
                    show[j] = rowAllowed(p)
                    indent = p.indent
                    if indent <= 0 then
                        break
                    end
                end
            end
        end
    end
    local header, any, hasRows = nil, false, false
    local function closeSection(stop)
        local on = any or not (hasRows or match)
        for j = header or 1, stop do
            if rows[j].kind == "header" then
                show[j] = on and rowAllowed(rows[j])
            end
        end
    end
    for i, row in ipairs(rows) do
        if row.kind == "header" then
            closeSection(i - 1)
            header, any, hasRows = i, false, false
        elseif row.kind ~= "gap" then
            hasRows = true
            any = any or show[i]
        end
    end
    closeSection(#rows)
    return show
end

-- Lays the rows out again: match nil shows every row (opts.visible still applies). Returns the number of controls
-- shown. Rows keep their order and spacing; hidden rows leave no gap.
function Stack:Layout(match)
    self.match = match
    local rows = self.rows
    if #rows == 0 then
        return 0
    end
    self.bottom = self.bottom or self.y
    local show = shownRows(rows, match)
    local shift, placed, count = 0, false, 0
    for i, row in ipairs(rows) do
        local pre = row.pre or 0
        if show[i] then
            if pre > 0 and not placed then
                shift = shift + pre
            end
            local top = row.top + shift
            if row.laidTop ~= top or not row.shown then
                for _, p in ipairs(row.frames) do
                    if not p.rel then
                        p.f:ClearAllPoints()
                        p.f:SetPoint("TOPLEFT", p.x, top + p.dy)
                    end
                    p.f:Show()
                end
                row.laidTop, row.shown = top, true
            end
            placed = true
            if row.kind == "control" then
                count = count + 1
            end
        else
            if row.shown ~= false then
                for _, p in ipairs(row.frames) do
                    p.f:Hide()
                end
                row.shown = false
            end
            shift = shift + row.h0 + pre
        end
    end
    self.y = self.bottom + shift
    if self.onLayout then
        self.onLayout(self)
    end
    return count
end

function Stack:Gap(h)
    self:Row("gap")
    self.y = self.y - (h or 8)
    self:EndRow()
end

function Stack:Height()
    return -self.y + 8
end

function Stack:Header(text, sub, opts)
    local pre = 0
    if self.y < self.top then
        self.y = self.y - 8
        pre = 8
    end
    local row = self:Row("header", text, sub, opts)
    row.pre = pre
    local fs = W.Label(self.parent, text, "RepKeeperFontTitle")
    self:Put(fs, self.x, self.y)
    local line = W.Divider(self.parent, 0.3)
    self:Put(line, self.x, self.y - 16)
    line:SetWidth(self.width)
    self.y = self.y - 22
    self:EndRow()
    if sub then
        self:Text(sub, { font = "GameFontDisableSmall", visible = opts and opts.visible })
    end
    return fs
end

-- opts: indent, width, font, spacing (below the text, 6), refresh() (the text on every refresh)
function Stack:Text(text, opts)
    opts = opts or {}
    local indent = opts.indent or 0
    local spacing = opts.spacing or 6
    local row = self:Row("text", nil, nil, opts)
    local fs = W.Text(self.parent, text, opts.width or (self.width - indent), opts.font)
    self:Put(fs, self.x + indent, self.y)
    self.y = self.y - (max(12, floor(fs:GetStringHeight() + 0.5)) + spacing)
    self:EndRow()
    row.fs = fs
    if opts.refresh then
        fs.Refresh = function(f)
            f:SetText(opts.refresh() or "")
        end
        self:Track(fs, opts)
    end
    return fs
end

function Stack:Check(label, tip, get, set, opts)
    opts = opts or {}
    local stack = self
    self:Row("control", label, tip, opts)
    local cb = W.Check(self.parent, label, tip, get, function(on, box)
        set(on, box)
        stack:Refresh()
    end)
    self:Put(cb, self.x + (opts.indent or 0) - 2, self.y + 2)
    self.y = self.y - 24
    self:EndRow()
    return self:Track(cb, opts)
end

function Stack:Slider(label, minV, maxV, step, get, set, fmt, opts)
    opts = opts or {}
    local stack = self
    self:Row("control", label, opts.tip, opts)
    local s = W.Slider(self.parent, label, minV, maxV, step, get, function(v)
        set(v)
        stack:Refresh()
    end, fmt, opts.width or 200)
    self.y = self.y - 16
    self:Put(s, self.x + (opts.indent or 0) + 4, self.y)
    self.y = self.y - 40
    self:EndRow()
    if opts.tip then
        W.AttachTooltip(s, label, opts.tip)
    end
    return self:Track(s, opts)
end

function Stack:Dropdown(label, width, items, get, set, opts)
    opts = opts or {}
    local stack = self
    local row = self:Row("control", label, opts.tip, opts)
    row.items = items
    local d = W.Dropdown(self.parent, width, items, get, function(v, it)
        set(v, it)
        stack:Refresh()
    end, { textFn = opts.textFn, empty = opts.empty, tip = opts.tip, tipTitle = label })
    local fs = W.Label(self.parent, label, "RepKeeperFontNormalSmall")
    self:Put(fs, self.x + (opts.indent or 0), self.y)
    self.y = self.y - 12
    self:Put(d, self.x + (opts.indent or 0) - 16, self.y)
    self.y = self.y - 34
    self:EndRow()
    d.caption = fs
    local setActive = d.SetActive
    function d:SetActive(on)
        setActive(self, on)
        fs:SetFontObject(on and "RepKeeperFontNormalSmall" or "GameFontDisableSmall")
    end
    return self:Track(d, opts)
end

-- opts.sameLine puts the button right of the previous one, in the same row.
function Stack:Button(text, onClick, tip, opts)
    opts = opts or {}
    local stack = self
    local b = W.Button(self.parent, text, opts.width, function(...)
        onClick(...)
        stack:Refresh()
    end, tip)
    if opts.sameLine and self.lastButton then
        b:SetPoint("LEFT", self.lastButton, "RIGHT", 6, 0)
        self:Attach(b, text .. " " .. (tip or ""))
    else
        self:Row("control", text, tip, opts)
        self:Put(b, self.x + (opts.indent or 0), self.y)
        self.y = self.y - 28
        self:EndRow()
    end
    self.lastButton = b
    if opts.dep then
        b.SetActive = b.SetEnabled
    end
    return self:Track(b, opts)
end

-- Places a widget at the cursor, as a row of its own. opts: kind ("control"), label, tip and the other row options.
function Stack:Place(widget, height, xOffset, yOffset, opts)
    self:Row(opts and opts.kind or "control", opts and opts.label, opts and opts.tip, opts)
    self:Put(widget, self.x + (xOffset or 0), self.y + (yOffset or 0))
    self.y = self.y - (height or widget:GetHeight() or 20)
    self:EndRow()
    return widget
end

---------------------------------------------------------------------------
-- Choices in a row where one is picked (the rating): small boxes with an icon and a label; the picked one is filled
-- with its colour.
-- items: { { value, text, atlas, color = { r, g, b }, tip } }; get() -> value; set(value)
---------------------------------------------------------------------------
local function paintChoice(b, picked, hover)
    local c = b.item.color or { 0.8, 0.8, 0.8 }
    if picked then
        b:SetBackdropColor(c[1] * 0.4, c[2] * 0.4, c[3] * 0.4, 0.95)
        b:SetBackdropBorderColor(c[1], c[2], c[3], 1)
        b.text:SetTextColor(1, 1, 1)
        b.icon:SetDesaturated(false)
        b.icon:SetAlpha(1)
    else
        b:SetBackdropColor(0.06, 0.06, 0.06, 0.85)
        local e = hover and 0.75 or 0.35
        b:SetBackdropBorderColor(e, e, e, 1)
        local t = hover and 1 or 0.65
        b.text:SetTextColor(t, t, t)
        b.icon:SetDesaturated(not hover)
        b.icon:SetAlpha(hover and 1 or 0.6)
    end
end

function W.Segmented(parent, items, get, set, opts)
    opts = opts or {}
    local seg = CreateFrame("Frame", nil, parent)
    seg:SetHeight(opts.height or 24)
    seg.buttons = {}
    local gap = opts.gap or 6

    for i, it in ipairs(items) do
        local b = CreateFrame("Button", nil, seg, "BackdropTemplate")
        b:SetBackdrop(W.BD.chip)
        b.item = it
        b.text = b:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        b.text:SetText(it.text)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetSize(14, 14)
        b.icon:SetPoint("RIGHT", b.text, "LEFT", -4, 0)
        if it.atlas then
            b.icon:SetAtlas(it.atlas)
        else
            b.icon:Hide()
        end
        b:SetScript("OnClick", function(self)
            W.Sound("click")
            set(self.item.value)
            seg:Refresh()
        end)
        b:SetScript("OnEnter", function(self)
            paintChoice(self, get() == self.item.value, true)
            if self.item.tip then
                W.ShowTip(self, self.item.text, self.item.tip, "ANCHOR_TOP")
            end
        end)
        b:SetScript("OnLeave", function(self)
            paintChoice(self, get() == self.item.value, false)
            W.HideTip()
        end)
        seg.buttons[i] = b
    end

    -- Equal widths over the whole row; icon and label centred in each.
    function seg:Layout()
        local w = self:GetWidth() or 0
        local n = #self.buttons
        if w <= 0 or n == 0 then
            return
        end
        local bw = floor((w - gap * (n - 1)) / n)
        for i, b in ipairs(self.buttons) do
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", (i - 1) * (bw + gap), 0)
            b:SetSize(bw, self:GetHeight())
            b.text:ClearAllPoints()
            b.text:SetPoint("CENTER", b.item.atlas and 9 or 0, 0)
        end
    end

    function seg:Refresh()
        local cur = get()
        for _, b in ipairs(self.buttons) do
            paintChoice(b, cur == b.item.value, false)
        end
    end

    function seg:SetActive(on)
        for _, b in ipairs(self.buttons) do
            b:SetEnabled(on)
        end
    end

    seg:SetScript("OnSizeChanged", seg.Layout)
    seg:Refresh()
    return seg
end

---------------------------------------------------------------------------
-- Chips: small boxes with a word in them (tags). onClick(chip, mouse); the colour tints text, fill and border.
---------------------------------------------------------------------------
function W.Chip(parent, onClick)
    local c = CreateFrame("Button", nil, parent, "BackdropTemplate")
    c:SetBackdrop(W.BD.chip)
    c:SetHeight(20)
    c:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    c.text = c:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    c.text:SetPoint("CENTER", 0, 0)
    c.text:SetWordWrap(false)

    local function paint(self, hover)
        local col = self.color or { 0.8, 0.8, 0.8 }
        local k = (self.bright and 0.42 or 0.2) + (hover and 0.12 or 0)
        self:SetBackdropColor(col[1] * k, col[2] * k, col[3] * k, 0.95)
        local e = (hover or self.bright) and 1 or 0.6
        self:SetBackdropBorderColor(col[1] * e, col[2] * e, col[3] * e, 1)
        if self.bright then
            self.text:SetTextColor(1, 1, 1)
        else
            self.text:SetTextColor(min(1, col[1] + 0.15), min(1, col[2] + 0.15), min(1, col[3] + 0.15))
        end
    end

    -- maxWidth: longer words end in "...". bright: filled with the colour (a picked choice).
    function c:Set(text, color, maxWidth, bright)
        self.color = color
        self.bright = bright and true or nil
        self.text:SetText(text or "")
        local w = floor(self.text:GetStringWidth() + 16)
        if maxWidth and w > maxWidth then
            w = maxWidth
        end
        self.text:SetWidth(w - 12)
        self:SetWidth(w)
        paint(self, false)
    end

    c:SetScript("OnEnter", function(self)
        paint(self, true)
        if self.tipTitle or self.tipText then
            W.ShowTip(self, self.tipTitle, self.tipText, "ANCHOR_TOP")
        end
    end)
    c:SetScript("OnLeave", function(self)
        paint(self, false)
        W.HideTip()
    end)
    if onClick then
        c:SetScript("OnClick", function(self, mouse)
            W.Sound("click")
            onClick(self, mouse)
        end)
    end
    return c
end
