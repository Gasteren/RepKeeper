-- UI/Setup.lua
-- The setup: the main settings one at a time, each with a small example of what it changes (like the author's
-- HandyNotes plugins). It opens by itself once, a few seconds after you log in (after a fight, never during one).
-- /rk setup and "Run setup again" on the Options tab open it again. Nothing changes until you press Finish, and
-- closing it keeps everything as it was (the look and size you tried go back too).

local addonName, ns = ...
local L = LibStub("AceLocale-3.0"):GetLocale("RepKeeper")
local C = ns.Constants
local U, W, UI = ns.U, ns.W, ns.UI

local format, floor, max = string.format, math.floor, math.max

local Setup = {}
ns.Setup = Setup

-- Raise it when the setup gets a question everyone should see: it then opens once more for everyone.
Setup.VERSION = 1

local WIDTH, HEIGHT = 560, 488
local PAD = 26
local PAGE_W = WIDTH - 2 * PAD

local frame
local pages = {}
local current
local answers -- what you picked so far; the settings only change on Finish
local Update

---------------------------------------------------------------------------
-- What the examples show
---------------------------------------------------------------------------
-- Made-up players. On WoW Forever characters have a first and a last name.
local SAMPLE = {
    { "Grimtusk", "Ironhand", "WARRIOR" },
    { "Thornby", "Ashgrove", "DRUID" },
    { "Mirelle", "Brightwater", "MAGE" },
    { "Oskar", "Fenwick", "HUNTER" },
}

local function SampleName(i)
    local p = SAMPLE[i]
    local name = ns.PlayerUtils:TwoPartNames() and (p[1] .. " " .. p[2]) or p[1]
    local r, g, b = U.ClassRGB(p[3])
    return format("|cff%02x%02x%02x%s|r", floor(r * 255 + 0.5), floor(g * 255 + 0.5), floor(b * 255 + 0.5), name)
end

-- Where the example groups were: where you are, a dungeon and a raid of your game.
local function Places()
    local forever = ns.PlayerUtils:TwoPartNames()
    local zone = GetRealZoneText() or ""
    if zone == "" then
        zone = forever and "Elwynn Forest" or "Dornogal"
    end
    if forever then
        return zone, "The Deadmines", "Molten Core"
    end
    return zone, "The Stonevault", "Liberation of Undermine"
end

local function YesNo(on)
    return on and L["Yes"] or L["No"]
end

---------------------------------------------------------------------------
-- Page parts
---------------------------------------------------------------------------
local function NewPage(build)
    local page = CreateFrame("Frame", nil, frame.body)
    page:SetAllPoints()
    page:Hide()
    pages[#pages + 1] = page
    page.index = #pages
    build(page)
    return page
end

local function Title(page, title, text)
    page.title = W.OneLine(W.Label(page, title, "RepKeeperFontTitleLarge"))
    page.title:SetPoint("TOPLEFT", 0, 0)
    page.title:SetWidth(PAGE_W)
    page.text = W.Text(page, text, PAGE_W, "GameFontHighlight")
    page.text:SetPoint("TOPLEFT", page.title, "BOTTOMLEFT", 0, -8)
end

-- Where the page's controls start: under its text.
local function Top(page)
    return -(floor(page.title:GetStringHeight() + 0.5) + 8 + floor(page.text:GetStringHeight() + 0.5) + 18)
end

-- A question: one radio button per answer (items: { value, text, desc }).
local function Choices(page, key, items)
    page.choiceKey = key
    page.radios = {}
    for i, item in ipairs(items) do
        local rb = W.Radio(page, item.text, item.desc, PAGE_W - 4, function()
            answers[key] = item.value
            Update()
        end)
        rb.value = item.value
        page.radios[i] = rb
    end
end

local function PlaceChoices(page, y)
    for _, rb in ipairs(page.radios) do
        rb:ClearAllPoints()
        rb:SetPoint("TOPLEFT", page, "TOPLEFT", 4, y)
        y = y - rb:Height() - (rb.desc and 12 or 10)
    end
    return y
end

local function TickChoices(page)
    local value = answers[page.choiceKey]
    for _, rb in ipairs(page.radios) do
        rb:SetChecked(rb.value == value)
    end
end

-- The box at the bottom of a page that shows what a choice does. Its content dims when the choice turns it off.
local function Example(page, height, title)
    local box = W.Box(page, title or L["Example"])
    box:SetPoint("BOTTOMLEFT", 0, 0)
    box:SetPoint("BOTTOMRIGHT", 0, 0)
    box:SetHeight(height)
    box.content = CreateFrame("Frame", nil, box)
    box.content:SetAllPoints()
    box.off = W.Text(box, "", PAGE_W - 40, "GameFontHighlightSmall")
    box.off:SetPoint("BOTTOM", 0, 12)
    box.off:SetJustifyH("CENTER")
    box.off:Hide()
    page.example = box
    return box
end

local function ShowExample(box, on, offText)
    box.content:SetAlpha(on and 1 or 0.25)
    box.off:SetText(offText or "")
    box.off:SetShown(not on and offText ~= nil)
end

-- Controls in the example are only there to look at.
local function Still(...)
    for i = 1, select("#", ...) do
        local f = select(i, ...)
        f:EnableMouse(false)
        if f.buttons then
            for _, b in ipairs(f.buttons) do
                b:EnableMouse(false)
            end
        end
    end
end

---------------------------------------------------------------------------
-- The pages
---------------------------------------------------------------------------
local THEME_COLOR = {
    classic = { 1, 0.82, 0 },
    steel = { 0.22, 0.82, 1 },
    horde = { 0.95, 0.32, 0.22 },
    alliance = { 0.35, 0.6, 1 },
}

local function BuildLook(page)
    Title(page, L["How should RepKeeper look?"],
        L["Pick a look and a size for RepKeeper's windows. This window shows your pick right away."])
    local items = {}
    for i, id in ipairs(W.THEME_ORDER) do
        local th = W.THEMES[id]
        items[i] = { value = id, text = th.name, color = THEME_COLOR[id], tip = th.desc }
    end
    page.themes = W.Segmented(page, items, function()
        return answers.theme
    end, function(id)
        answers.theme = id
        W.ApplyTheme(id)
        Update()
    end, { height = 26 })
    page.themeDesc = W.OneLine(W.Label(page, "", "GameFontDisableSmall"))
    page.themeDesc:SetWidth(PAGE_W - 4)
    page.size = W.Slider(page, L["UI size"], 70, 150, 5, function()
        return floor(answers.scale * 100 + 0.5)
    end, function(v)
        answers.scale = v / 100
        W.previewScale = answers.scale
        W.ApplyScale()
        Update()
    end, "%d%%", 240)
    W.AttachTooltip(page.size, L["UI size"], L["Turn the mouse wheel over the slider for small steps."])

    -- A few of RepKeeper's controls, in the look you pick.
    local box = Example(page, 96)
    box.check = W.Check(box.content, L["Show the minimap button"], nil, function()
        return true
    end)
    box.check:SetPoint("TOPLEFT", 12, -12)
    box.rating = W.Segmented(box.content, UI.RatingChoices(), function()
        return C.REP.POSITIVE
    end, function() end, { height = 22 })
    box.rating:SetPoint("TOPLEFT", 16, -52)
    box.rating:SetWidth(300)
    box.button = W.Button(box.content, L["Whisper"], 100)
    box.button:SetPoint("TOPRIGHT", -16, -52)
    Still(box.check, box.rating, box.button)

    function page:Layout()
        local y = Top(self)
        self.themes:ClearAllPoints()
        self.themes:SetPoint("TOPLEFT", 0, y)
        self.themes:SetPoint("TOPRIGHT", 0, y)
        self.themeDesc:ClearAllPoints()
        self.themeDesc:SetPoint("TOPLEFT", 2, y - 26 - 8)
        self.size:ClearAllPoints()
        self.size:SetPoint("TOPLEFT", 6, y - 26 - 8 - 14 - 36)
    end
    function page:Refresh()
        self.themes:Refresh()
        self.themeDesc:SetText(W.THEMES[answers.theme].desc or "")
        self.size:Refresh()
    end
    function page:Summary()
        return format(L["Look: %s, %d%% size"], W.THEMES[answers.theme].name, floor(answers.scale * 100 + 0.5))
    end
end

local function BuildWarn(page)
    Title(page, L["Warn you about blacklisted players?"],
        L["When someone you blacklisted is in your group, RepKeeper shows who it is and why. When one of them invites you, you always get a warning."])
    Choices(page, "warn", {
        { value = true, text = L["Yes, warn me when one is in my group"] },
        { value = false, text = L["No, don't warn me"] },
    })
    page.sound = W.Check(page, L["Play a sound with it"], L["The raid warning sound, so you notice it."], function()
        return answers.warnSound
    end, function(on)
        answers.warnSound = on
        Update()
    end)

    -- The warning, small.
    local box = Example(page, 104)
    box.lead = W.Text(box.content, U.Color(ns.COLOR.red, L["A player you blacklisted is in your group."]), PAGE_W - 40, "GameFontNormal")
    box.lead:SetPoint("TOP", 0, -14)
    box.lead:SetJustifyH("CENTER")
    box.name = W.Label(box.content, SampleName(1), "GameFontHighlight")
    box.name:SetPoint("TOPLEFT", 22, -40)
    box.why = W.OneLine(W.Label(box.content, U.Color(ns.COLOR.red, L["Blacklist"] .. ": " .. L["Ninja Looter"] .. ", " .. L["Toxic"])
        .. U.Color(ns.COLOR.grey, UI.DOT .. L["Rolled need on everything."]), "GameFontHighlightSmall"))
    box.why:SetPoint("TOPLEFT", 22, -58)
    box.why:SetWidth(PAGE_W - 40)

    -- The sound goes with "Yes": it sits under it.
    function page:Layout()
        local y = Top(self)
        local yes, no = self.radios[1], self.radios[2]
        yes:ClearAllPoints()
        yes:SetPoint("TOPLEFT", self, "TOPLEFT", 4, y)
        y = y - yes:Height() - 2
        self.sound:ClearAllPoints()
        self.sound:SetPoint("TOPLEFT", 20, y)
        y = y - 24 - 8
        no:ClearAllPoints()
        no:SetPoint("TOPLEFT", self, "TOPLEFT", 4, y)
    end
    function page:Refresh()
        TickChoices(self)
        self.sound:Refresh()
        self.sound:SetActive(answers.warn)
        ShowExample(self.example, answers.warn, L["No warning. Hover them to see what you know about them."])
    end
    function page:Summary()
        local state = answers.warn and (answers.warnSound and L["on, with a sound"] or L["on"]) or L["off"]
        return format(L["Warnings: %s"], state)
    end
end

local function BuildAdding(page)
    Title(page, L["Who should RepKeeper add to your list?"],
        L["The players it adds start as Neutral, with a line in their history saying where you grouped. You can rate them later."])
    page.choices = UI.TrackingChoices()
    Choices(page, "adding", page.choices)
    page.prune = W.Check(page, "", L["Only players RepKeeper added by itself, and only when you never rated, tagged or wrote about them. You can change the days on the Options tab, under Tracking."], function()
        return answers.prune
    end, function(on)
        answers.prune = on
        Update()
    end)

    -- A few rows of the list.
    local box = Example(page, 96)
    box.rows = {}
    for i = 1, 3 do
        local y = -12 - (i - 1) * 22
        local row = {}
        row.icon = box.content:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(14, 14)
        row.icon:SetTexture(U.CLASS_CIRCLES)
        row.icon:SetPoint("TOPLEFT", 14, y)
        row.name = W.OneLine(W.Label(box.content, "", "GameFontHighlightSmall"))
        row.name:SetPoint("TOPLEFT", 34, y - 2)
        row.name:SetWidth(150)
        row.rating = W.OneLine(W.Label(box.content, "", "GameFontHighlightSmall"))
        row.rating:SetPoint("TOPLEFT", 190, y - 2)
        row.rating:SetWidth(92)
        row.line = W.OneLine(W.Label(box.content, "", "GameFontDisableSmall"))
        row.line:SetPoint("TOPLEFT", 288, y - 2)
        row.line:SetWidth(PAGE_W - 300)
        box.rows[i] = row
    end

    local function setRow(row, sample, level, text)
        row.name:SetText(SampleName(sample))
        row.icon:SetTexCoord(U.ClassCoords(SAMPLE[sample][3]))
        row.rating:SetText(UI.RatingLabel(level))
        row.line:SetText(text)
        row.icon:Show()
        row.name:Show()
        row.rating:Show()
        row.line:Show()
    end

    function page:Layout()
        local y = PlaceChoices(self, Top(self))
        self.prune:ClearAllPoints()
        self.prune:SetPoint("TOPLEFT", 2, y + 2)
    end
    function page:Refresh()
        TickChoices(self)
        local days = ns.S.autoPruneDays or 30
        local label = format(L["Remove them again when I haven't seen them for %d days"], days)
        self.prune:SetLabel(label)
        self.prune.tipTitle = label
        self.prune:Refresh()
        self.prune:SetActive(answers.adding ~= "nobody")
        local zone, dungeon, raid = Places()
        local rows = self.example.rows
        local shown = 0
        if answers.adding == "everyone" then
            setRow(rows[1], 2, C.REP.NEUTRAL, format(L["Grouped with in %s"], zone))
            setRow(rows[2], 3, C.REP.NEUTRAL, format(L["Grouped with in %s"], dungeon))
            setRow(rows[3], 4, C.REP.NEUTRAL, format(L["Grouped with in %s"], raid))
            shown = 3
        elseif answers.adding == "dungeons" then
            setRow(rows[1], 2, C.REP.NEUTRAL, format(L["Grouped with in %s"], dungeon))
            setRow(rows[2], 3, C.REP.NEUTRAL, format(L["Grouped with in %s"], dungeon))
            shown = 2
        else
            setRow(rows[1], 1, C.REP.BLACKLIST, L["You added them."])
            shown = 1
        end
        for i = shown + 1, #rows do
            local row = rows[i]
            row.icon:Hide()
            row.name:Hide()
            row.rating:Hide()
            row.line:Hide()
        end
        ShowExample(self.example, true, nil)
        if answers.adding == "nobody" then
            self.example.off:SetText(L["Nobody else is added."])
            self.example.off:Show()
        end
    end
    function page:Summary()
        local text
        for _, item in ipairs(self.choices) do
            if item.value == answers.adding then
                text = item.text
            end
        end
        local line = format(L["Added by itself: %s"], text or "?")
        if answers.adding ~= "nobody" and answers.prune then
            line = line .. format(L[", removed after %d days unseen"], ns.S.autoPruneDays or 30)
        end
        return line
    end
end

local function BuildTooltip(page)
    Title(page, L["Show what you know in their tooltip?"],
        L["When you hover a player on your list, their tooltip shows how you rated them, their tags and your note."])
    Choices(page, "tooltip", {
        { value = true, text = L["Yes, add it to their tooltip"] },
        { value = false, text = L["No, leave tooltips as they are"] },
    })

    -- A player's tooltip: the game's lines, then RepKeeper's (as Modules\Tooltip.lua writes them).
    local box = Example(page, 132)
    local tip = CreateFrame("Frame", nil, box.content, "BackdropTemplate")
    tip:SetBackdrop(W.BD.menu)
    tip:SetBackdropColor(0.09, 0.09, 0.19, 0.95)
    tip:SetBackdropBorderColor(1, 1, 1, 1)
    tip:SetWidth(270)
    tip:SetPoint("TOP", 0, -12)
    box.tip = tip
    local lines = {
        { SampleName(1), "GameFontNormal" },
        { L["Orc Warrior"], "GameFontHighlightSmall" },
        { U.Color("ff2222", L["BLACKLISTED"]), "GameFontHighlightSmall", true },
        { U.Color("ffaaaa", L["Rolled need on everything."]), "GameFontHighlightSmall", true },
        { L["Tags"] .. ": " .. U.Color("aaaaaa", L["Ninja Looter"] .. ", " .. L["Toxic"]), "GameFontHighlightSmall", true },
    }
    tip.lines = {}
    for i, def in ipairs(lines) do
        local fs = W.OneLine(W.Label(tip, def[1], def[2]))
        fs:SetWidth(246)
        fs.ours = def[3]
        tip.lines[i] = fs
    end

    function page:Layout()
        PlaceChoices(self, Top(self))
    end
    function page:Refresh()
        TickChoices(self)
        local y = -10
        for _, fs in ipairs(tip.lines) do
            local show = answers.tooltip or not fs.ours
            fs:SetShown(show)
            if show then
                fs:ClearAllPoints()
                fs:SetPoint("TOPLEFT", 12, y)
                y = y - (fs.ours and 14 or 16)
            end
        end
        tip:SetHeight(-y + 8)
        ShowExample(self.example, true, nil)
    end
    function page:Summary()
        return format(L["Tooltips: %s"], YesNo(answers.tooltip))
    end
end

local function BuildMinimap(page)
    Title(page, L["Show the minimap button?"],
        L["Click it to open RepKeeper, right-click it for the options. Typing /rk always works too."])
    Choices(page, "minimap", {
        { value = true, text = L["Yes, show it on the minimap"] },
        { value = false, text = L["No, I'll type /rk"] },
    })

    -- The button, as LibDBIcon draws it.
    local box = Example(page, 104)
    local b = CreateFrame("Frame", nil, box.content)
    b:SetSize(31, 31)
    b:SetPoint("TOPLEFT", 26, -30)
    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture(136467) -- Interface\Minimap\UI-Minimap-Background
    bg:SetSize(20, 20)
    bg:SetPoint("TOPLEFT", 7, -5)
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetTexture("Interface\\Icons\\INV_Misc_Note_01")
    icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
    icon:SetSize(17, 17)
    icon:SetPoint("TOPLEFT", 7, -6)
    local border = b:CreateTexture(nil, "OVERLAY")
    border:SetTexture(136430) -- Interface\Minimap\MiniMap-TrackingBorder
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")
    box.click = W.Label(box.content, U.Color(ns.COLOR.gold, L["Click:"]) .. " " .. L["open or close RepKeeper"], "GameFontHighlightSmall")
    box.click:SetPoint("TOPLEFT", 92, -32)
    box.right = W.Label(box.content, U.Color(ns.COLOR.gold, L["Right-click:"]) .. " " .. L["the options"], "GameFontHighlightSmall")
    box.right:SetPoint("TOPLEFT", 92, -50)

    function page:Layout()
        PlaceChoices(self, Top(self))
    end
    function page:Refresh()
        TickChoices(self)
        ShowExample(self.example, answers.minimap, L["No button. Type /rk to open RepKeeper."])
    end
    function page:Summary()
        return format(L["Minimap button: %s"], YesNo(answers.minimap))
    end
end

-- Takes effect after a reload: the group warning listens from login on.
local function NeedsReload()
    local atLogin = ns.Options and ns.Options.LoginValue and ns.Options.LoginValue("groupWarningEnabled")
    return atLogin ~= nil and answers.warn ~= atLogin
end

local Finish

local function BuildDone(page)
    Title(page, L["You're all set!"],
        L["Here's what you picked. Change it any time on the Options tab, or type /rk setup to run this again."])
    page.lines = {}
    for i = 1, #pages - 1 do
        local fs = W.OneLine(W.Label(page, "", "GameFontHighlight"))
        fs:SetWidth(PAGE_W - 10)
        page.lines[i] = fs
    end
    page.reload = W.Text(page, U.Color(ns.COLOR.orange, L["Turning the warnings on or off takes effect after a reload."]), PAGE_W - 150, "GameFontHighlightSmall")
    page.reloadButton = W.Button(page, L["Finish and reload"], nil, function()
        Finish(true)
    end, L["Saves your picks and reloads the interface, like /reload."])

    local box = Example(page, 92, L["Good to know"])
    box.tips = W.Text(box.content, "", PAGE_W - 32, "GameFontHighlightSmall")
    box.tips:SetPoint("TOPLEFT", 16, -14)

    function page:Layout()
        local y = Top(self)
        for _, fs in ipairs(self.lines) do
            fs:ClearAllPoints()
            fs:SetPoint("TOPLEFT", 8, y)
            y = y - 20
        end
        self.reload:ClearAllPoints()
        self.reload:SetPoint("TOPLEFT", 8, y - 10)
        self.reloadButton:ClearAllPoints()
        self.reloadButton:SetPoint("TOPRIGHT", 0, y - 6)
    end
    function page:Refresh()
        for i, fs in ipairs(self.lines) do
            local p = pages[i]
            fs:SetText(U.Color(ns.COLOR.gold, "-") .. " " .. (p.Summary and p:Summary() or ""))
        end
        local reload = NeedsReload()
        self.reload:SetShown(reload)
        self.reloadButton:SetShown(reload)
        local open = answers.minimap and L["type /rk, or click the minimap button."] or L["type /rk."]
        box.tips:SetText(table.concat({
            U.Color(ns.COLOR.gold, L["Rate a player:"]) .. " " .. L["right-click them in the game, or their name in chat, and choose RepKeeper."],
            U.Color(ns.COLOR.gold, L["Rate a whole group:"]) .. " " .. L["the Groups tab, right after the run."],
            U.Color(ns.COLOR.gold, L["Open RepKeeper:"]) .. " " .. open,
        }, "\n"))
        ShowExample(box, true, nil)
    end
end

---------------------------------------------------------------------------
-- The wizard
---------------------------------------------------------------------------
local function ReadSettings()
    local s = ns.S
    return {
        theme = W.THEMES[s.ui.theme] and s.ui.theme or "classic",
        scale = tonumber(s.ui.scale) or 1,
        warn = s.groupWarningEnabled and true or false,
        warnSound = s.groupWarningSound and true or false,
        adding = ns.GroupTracker:GetMode(),
        prune = s.autoPruneEnabled and true or false,
        tooltip = s.tooltipEnabled and true or false,
        minimap = not (s.minimapButton and s.minimapButton.hide),
    }
end

local function Apply()
    local s = ns.S
    s.groupWarningEnabled = answers.warn
    s.groupWarningSound = answers.warnSound
    ns.GroupTracker:SetMode(answers.adding)
    s.autoPruneEnabled = answers.prune
    s.tooltipEnabled = answers.tooltip
    s.minimapButton.hide = not answers.minimap
    s.ui.scale = answers.scale
    W.previewScale = nil
    W.SetTheme(answers.theme)
    W.ApplyScale()
    if ns.Minimap and ns.Minimap.Refresh then
        ns.Minimap:Refresh()
    end
    s.setupVersion = Setup.VERSION
    ns.Fire("SETTINGS_CHANGED", "setup")
end

function Finish(reload)
    Apply()
    frame.finished = true
    frame:Hide()
    ns.Addon:Print(L["You're all set. Type /rk to open RepKeeper, or /rk setup to change these again."])
    if reload then
        ReloadUI()
    end
end

function Update()
    if not (frame and current) then
        return
    end
    local i, n = current.index, #pages
    frame.step:SetFormattedText(L["Step %d of %d"], i, n)
    frame.back:SetEnabled(i > 1)
    frame.next:SetText(i == n and L["Finish"] or L["Next"])
    current:Refresh()
end

local function ShowPage(page)
    current = page
    for _, p in ipairs(pages) do
        p:SetShown(p == page)
    end
    page:Layout()
    Update()
end

local function Step(delta)
    local i = current.index + delta
    if delta > 0 and current.index == #pages then
        Finish(false)
    elseif pages[i] then
        ShowPage(pages[i])
    end
end

local function Build()
    frame = W.Window("RepKeeperSetup", L["RepKeeper Setup"], WIDTH, HEIGHT, {
        strata = "DIALOG", sound = true, solid = true, point = "CENTER", relPoint = "CENTER", x = 0, y = 40,
    })
    frame.subtitle = W.Label(frame, "", "GameFontHighlightSmall")
    frame.subtitle:SetPoint("TOPLEFT", 20, -15)
    frame.step = W.Label(frame, "", "RepKeeperFontNormalSmall")
    frame.step:SetPoint("TOPRIGHT", -42, -15)
    frame.step:SetJustifyH("RIGHT")

    frame.body = CreateFrame("Frame", nil, frame)
    frame.body:SetPoint("TOPLEFT", PAD, -46)
    frame.body:SetPoint("BOTTOMRIGHT", -PAD, 54)

    frame.next = W.Button(frame, L["Next"], 110, function()
        Step(1)
    end)
    frame.next:SetPoint("BOTTOMRIGHT", -20, 18)
    frame.back = W.Button(frame, L["Back"], 110, function()
        Step(-1)
    end)
    frame.back:SetPoint("RIGHT", frame.next, "LEFT", -6, 0)
    frame.skip = W.Button(frame, L["Skip setup"], 120, function()
        frame:Hide()
    end)
    frame.skip:SetPoint("BOTTOMLEFT", 20, 18)

    -- Closed without Finish: the look and size you tried go back, nothing else changed. Hidden with the rest of the
    -- interface (Alt+Z, a cinematic), it is still open.
    function frame:onHidden()
        if self.finished or self:IsShown() then
            return
        end
        W.previewScale = nil
        if W.themeId ~= ns.S.ui.theme then
            W.ApplyTheme(ns.S.ui.theme)
        end
        W.ApplyScale()
        if self.firstRun then
            ns.S.setupVersion = Setup.VERSION
            ns.Addon:Print(L["Setup skipped. Type /rk setup to run it any time."])
        else
            ns.Addon:Print(L["Setup closed, nothing was changed."])
        end
    end

    NewPage(BuildLook)
    NewPage(BuildWarn)
    NewPage(BuildAdding)
    NewPage(BuildTooltip)
    NewPage(BuildMinimap)
    NewPage(BuildDone)
    frame.pages = pages
end

-- Opens the setup (firstRun: it opened by itself, so closing it means "skip").
function Setup.Open(firstRun)
    if not ns.S then
        return
    end
    if frame and frame:IsShown() then
        frame:Raise()
        return frame
    end
    answers = ReadSettings()
    if not frame then
        Build()
    end
    frame.finished = false
    frame.firstRun = firstRun and true or false
    frame.subtitle:SetText(firstRun and L["First-time setup"] or L["Setup"])
    frame.skip:SetText(firstRun and L["Skip setup"] or L["Cancel"])
    frame:Show()
    frame:Raise()
    ShowPage(pages[1])
    return frame
end

function Setup.Frame()
    return frame
end

---------------------------------------------------------------------------
-- After logging in
---------------------------------------------------------------------------
local watcher = CreateFrame("Frame")

local function OpenWhenReady()
    if (ns.S.setupVersion or 0) >= Setup.VERSION or (frame and frame:IsShown()) then
        return
    end
    if InCombatLockdown() then
        watcher:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    Setup.Open(true)
end

watcher:SetScript("OnEvent", function(self, event)
    self:UnregisterEvent(event)
    C_Timer.After(event == "PLAYER_ENTERING_WORLD" and 6 or 1, OpenWhenReady)
end)

function Setup:Initialize()
    if (ns.S.setupVersion or 0) < Setup.VERSION then
        watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
    end
end
