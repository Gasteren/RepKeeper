-- UI/Players.lua
-- The Players page: everyone RepKeeper knows on the left, the one you pick on the right. Everything about a player is
-- changed right there: rating, tags, note and history. ns.PlayerEditor keeps the old entry points.

local addonName, ns = ...
local L = LibStub("AceLocale-3.0"):GetLocale("RepKeeper")
local C = ns.Constants
local U, W, UI = ns.U, ns.W, ns.UI

local format, floor, max, min = string.format, math.floor, math.max, math.min

local LIST_W = 362
local TOP = 32 -- below the search bar
local PAD = 14
local FORM_X = 88 -- where the controls start, right of their labels
local ROW_GAP = 12

local Players = {}
UI.Players = Players

local page
local selectedKey
local filter = { text = "", rating = nil }
local focusNote = false

-- In the Rating column, blacklisted players come first, then the ones you liked, then everyone else.
local SORT_RANK = { [C.REP.BLACKLIST] = 1, [C.REP.POSITIVE] = 2, [C.REP.NEUTRAL] = 3 }

local function current()
    return selectedKey and ns.db.global.players[selectedKey] or nil
end

---------------------------------------------------------------------------
-- Search and filter
---------------------------------------------------------------------------
local function haystack(rec)
    local parts = { rec.name or "", rec.realm or "", rec.notes or "", rec.firstSeenLocation or "", rec.bnetTag or "",
        ns.PlayerUtils:DisplayNamePlain(rec) }
    if ns.S.streamerMode then
        parts[#parts + 1] = ns.PlayerUtils:Anonymize(rec)
    end
    for tagID in pairs(rec.tags or {}) do
        local def = ns.Database:GetTagDef(tagID)
        if def then
            parts[#parts + 1] = def.name
        end
    end
    return table.concat(parts, " "):lower()
end

local function matchesSearch(rec, needle)
    return needle == "" or haystack(rec):find(needle, 1, true) ~= nil
end

-- The players to list (newest first, the list sorts them further) and how many of each rating match the search.
local function collect()
    local needle = U.Trim(filter.text):lower()
    local list, counts = {}, { all = 0 }
    for _, level in ipairs(UI.RATING_ORDER) do
        counts[level] = 0
    end
    for _, rec in pairs(ns.db.global.players) do
        if matchesSearch(rec, needle) then
            local level = rec.reputation or 0
            counts.all = counts.all + 1
            counts[level] = (counts[level] or 0) + 1
            if filter.rating == nil or level == filter.rating then
                list[#list + 1] = rec
            end
        end
    end
    table.sort(list, function(a, b)
        local sa, sb = a.lastSeen or 0, b.lastSeen or 0
        if sa ~= sb then
            return sa > sb
        end
        return (a.normalizedKey or "") < (b.normalizedKey or "")
    end)
    return list, counts
end

local FILTERS = {
    { rating = nil, label = L["All"] },
    { rating = C.REP.BLACKLIST, label = L["Blacklist"] },
    { rating = C.REP.POSITIVE, label = L["Positive"] },
    { rating = C.REP.NEUTRAL, label = L["Neutral"] },
}

local function buildTopBar(p)
    p.search = W.EditBox(p, 196, {
        search = true,
        maxLetters = 40,
        placeholder = L["Search names, tags, notes"],
        tip = L["Finds players by name, tag, note or where you met them. Esc clears it."],
        tipTitle = L["Search"],
        onChange = function(_, text)
            filter.text = text or ""
            ns.Debounce("rk-player-search", 0.15, function()
                UI.Refresh("players")
            end)
        end,
        onEscape = function(self)
            if self:GetText() ~= "" then
                self:SetText("")
                filter.text = ""
                UI.Refresh("players")
            end
        end,
    })
    p.search:SetPoint("TOPLEFT", 10, -5)

    p.filters = {}
    local prev
    for i, def in ipairs(FILTERS) do
        local b = W.TextButton(p, def.label, function()
            filter.rating = def.rating
            UI.Refresh("players")
        end)
        b.def = def
        b.underline = W.Divider(b, 0.9)
        b.underline:SetPoint("BOTTOMLEFT", 0, -2)
        b.underline:SetPoint("BOTTOMRIGHT", 0, -2)
        if prev then
            b:SetPoint("LEFT", prev, "RIGHT", 12, 0)
        else
            b:SetPoint("LEFT", p.search, "RIGHT", 16, 0)
        end
        p.filters[i] = b
        prev = b
    end

    p.add = W.Button(p, L["Add player"], nil, function()
        UI.AddPlayerDialog()
    end, L["Add someone by name: to blacklist them, or to remember a good player."])
    p.add:SetPoint("TOPRIGHT", 0, -4)
end

local function refreshFilters(p, counts)
    for _, b in ipairs(p.filters) do
        local def = b.def
        local n = def.rating == nil and counts.all or (counts[def.rating] or 0)
        local on = filter.rating == def.rating
        b:SetNormalFontObject(on and "GameFontHighlightSmall" or "RepKeeperFontNormalSmall")
        b:SetLabel(def.label .. " " .. U.Color(on and ns.COLOR.white or ns.COLOR.grey, U.Number(n)))
        b.underline:SetShown(on)
    end
end

---------------------------------------------------------------------------
-- The list
---------------------------------------------------------------------------
local function rowMenu(rec)
    local items = { { text = UI.Name(rec), isTitle = true } }
    for _, level in ipairs(UI.RATING_ORDER) do
        items[#items + 1] = {
            text = UI.RatingIcon(level, 12) .. " " .. UI.RatingName(level),
            radio = true,
            checked = (rec.reputation or 0) == level,
            func = function()
                UI.SetRating(rec, level)
            end,
        }
    end
    items[#items + 1] = { separator = true }
    items[#items + 1] = { text = L["Whisper"], func = function()
        UI.Whisper(rec)
    end }
    items[#items + 1] = { text = L["Remove..."], color = { 1, 0.45, 0.45 }, func = function()
        UI.ConfirmRemove(rec)
    end }
    W.ContextMenu(page.list, items)
end

-- The class icon in front of the name.
local function decorateRow(row, rec, list)
    if not row.classIcon then
        row.classIcon = row:CreateTexture(nil, "ARTWORK")
        row.classIcon:SetSize(14, 14)
        row.classIcon:SetTexture(U.CLASS_CIRCLES)
    end
    local x, w = list:Column("name")
    row.classIcon:ClearAllPoints()
    row.classIcon:SetPoint("LEFT", row, "LEFT", x + 6, 0)
    local l, r, t, b = U.ClassCoords(rec.class)
    if l then
        row.classIcon:SetTexCoord(l, r, t, b)
        row.classIcon:Show()
    else
        row.classIcon:Hide()
    end
    local fs = row.cells[1]
    fs:ClearAllPoints()
    fs:SetPoint("LEFT", row, "LEFT", x + 24, 0)
    fs:SetWidth(max(8, w - 28))
end

local function buildList(p)
    local cols = {
        {
            key = "name", label = L["Player"], fill = true,
            get = function(rec)
                return UI.Name(rec)
            end,
            sortValue = function(rec)
                return U.Plain(ns.PlayerUtils:DisplayNamePlain(rec)):lower()
            end,
        },
        {
            key = "rating", label = L["Rating"], width = 92,
            get = function(rec)
                return UI.RatingLabel(rec.reputation)
            end,
            sortValue = function(rec)
                return SORT_RANK[rec.reputation or 0] or 3
            end,
            tip = L["Blacklisted players first, then the ones you liked, then everyone else."],
        },
        {
            key = "seen", label = L["Seen"], width = 86,
            get = function(rec)
                return U.Ago(rec.lastSeen), 0.62, 0.62, 0.62
            end,
            sortValue = function(rec)
                return rec.lastSeen or 0
            end,
            defaultDesc = true,
            tip = L["When you last saw or changed them."],
        },
    }
    p.list = W.List(p, cols, {
        rowHeight = 20,
        sortKey = "rating",
        selectKey = function(rec)
            return rec.normalizedKey
        end,
        onClick = function(rec, _, button)
            if button == "RightButton" then
                rowMenu(rec)
                return
            end
            Players.Select(rec.normalizedKey)
        end,
        decorate = decorateRow,
    })
    p.list:SetPoint("TOPLEFT", 0, -TOP)
    p.list:SetPoint("BOTTOMLEFT", 0, 0)
    p.list:SetWidth(LIST_W)
end

---------------------------------------------------------------------------
-- The details of the picked player
---------------------------------------------------------------------------
local RACE_NAMES = { Scourge = L["Undead"] }

local function raceName(race)
    if type(race) ~= "string" or race == "" then
        return nil
    end
    return RACE_NAMES[race] or (race:gsub("(%l)(%u)", "%1 %2"))
end

local SOURCE_TEXT = {
    manual = L["You added them."],
    auto_group = L["RepKeeper added them from one of your groups."],
    detection = L["RepKeeper added them when it spotted them."],
    import = L["They came in with an imported list."],
    guildsync = L["A guildmate shared them with you."],
}

local TYPE_COLOR = {
    manual = { 1, 1, 1 },
    system = { 0.55, 0.75, 1 },
    detection = { 1, 0.5, 0.5 },
    encounter = { 0.5, 0.85, 0.85 },
}
local TYPE_NAME = {
    manual = L["Written by you"],
    system = L["Noted by RepKeeper"],
    detection = L["Spotted by RepKeeper"],
    encounter = L["From a group"],
}

local function lowerFirst(s)
    return (s:gsub("^%u", string.lower))
end

local function historyDate(ts)
    if ns.S.timelineDateFormat == "absolute" then
        return U.Date(ts)
    end
    return U.Ago(ts)
end

local function historyItems(rec)
    local out = {}
    local tl = rec.timeline or {}
    for i = #tl, 1, -1 do
        out[#out + 1] = { entry = tl[i] }
    end
    return out
end

local function removeHistoryEntry(rec, entry)
    for i, e in ipairs(rec.timeline or {}) do
        if e == entry then
            ns.Timeline:RemoveAt(rec, i)
            return
        end
    end
end

local function flashSaved(d)
    d.saved:SetText(L["Saved"])
    d.savedAt = GetTime()
    local at = d.savedAt
    C_Timer.After(2, function()
        if d.savedAt == at then
            d.saved:SetText("")
        end
    end)
end

-- The note belongs to the player it was opened for, even when another one is picked while it is being written.
function Players.SaveNote(text)
    local d = page and page.details
    local rec = d and d.noteKey and ns.db.global.players[d.noteKey]
    if not rec then
        return
    end
    text = U.Trim(text)
    if (rec.notes or "") ~= text then
        rec.notes = text
        ns.Database:Touch(rec)
        flashSaved(d)
    end
end

-- The tag picker: every tag as a chip, grouped by kind (the kind that fits the rating first). A click adds or removes
-- a tag and the picker stays open for more; a click anywhere else closes it.
local PICK_W = 340
local PICK_PAD = 12
local DIM = { 0.5, 0.5, 0.5 }
local picker

local function closePicker()
    if picker then
        picker:Hide()
    end
end

local function pickerChip(i)
    local chip = picker.chips[i]
    if chip then
        return chip
    end
    chip = W.Chip(picker, function(self)
        local rec = current()
        if not rec then
            return
        end
        if self.isNew then
            closePicker()
            UI.NewTagDialog(rec)
            return
        end
        ns.Database:ToggleTag(rec, self.tagId)
        Players.LayoutPicker()
    end)
    picker.chips[i] = chip
    return chip
end

local function buildPicker()
    picker = W.Frame(UIParent, "menu", "RepKeeperTagPicker")
    picker:Hide()
    picker:SetFrameStrata("FULLSCREEN_DIALOG")
    picker:SetClampedToScreen(true)
    picker:EnableMouse(true)
    -- Solid under the menu backdrop: the page under it must not show through.
    local solid = picker:CreateTexture(nil, "BACKGROUND", nil, -8)
    solid:SetPoint("TOPLEFT", 4, -4)
    solid:SetPoint("BOTTOMRIGHT", -4, 4)
    solid:SetColorTexture(0.03, 0.03, 0.05, 0.92)
    picker.titles, picker.chips = {}, {}
    picker.hint = W.Label(picker, L["Click a tag to add or remove it."], "GameFontDisableSmall")
    picker:SetScript("OnShow", function(self)
        self:RegisterEvent("GLOBAL_MOUSE_DOWN")
    end)
    picker:SetScript("OnHide", function(self)
        self:UnregisterEvent("GLOBAL_MOUSE_DOWN")
        self.owner = nil
    end)
    picker:SetScript("OnEvent", function(self)
        if self:IsMouseOver() then
            return
        end
        local owner = self.owner
        if owner and owner:IsVisible() and owner:IsMouseOver() then
            return
        end
        self:Hide()
    end)
end

function Players.LayoutPicker()
    local rec = current()
    if not picker or not rec then
        closePicker()
        return
    end
    local first = UI.TIER_OF_RATING[rec.reputation or 0] or "neutral"
    local order = { first }
    for _, t in ipairs(UI.TIER_ORDER) do
        if t ~= first then
            order[#order + 1] = t
        end
    end
    local byTier = { negative = {}, neutral = {}, positive = {} }
    for id, def in pairs(C.BUILTIN_TAGS) do
        table.insert(byTier[UI.TagTier(def)], { id = id, def = def })
    end
    for id, def in pairs(ns.db.global.customTags or {}) do
        table.insert(byTier[UI.TagTier(def)], { id = id, def = def, custom = true })
    end
    local TITLES = { negative = L["Negative tags"], neutral = L["Neutral tags"], positive = L["Positive tags"] }
    local y, n = -PICK_PAD, 0
    local function place(chip, x)
        if x > 0 and x + chip:GetWidth() > PICK_W then
            x, y = 0, y - 24
        end
        chip:ClearAllPoints()
        chip:SetPoint("TOPLEFT", PICK_PAD + x, y)
        chip:Show()
        return x + chip:GetWidth() + 4
    end
    for i, tier in ipairs(order) do
        local title = picker.titles[i]
        if not title then
            title = W.Label(picker, "", "RepKeeperFontNormalSmall")
            picker.titles[i] = title
        end
        title:SetText(TITLES[tier])
        title:ClearAllPoints()
        title:SetPoint("TOPLEFT", PICK_PAD, y)
        y = y - 16
        local list = byTier[tier]
        table.sort(list, function(a, b)
            return a.def.name < b.def.name
        end)
        local x = 0
        for _, t in ipairs(list) do
            n = n + 1
            local chip = pickerChip(n)
            local on = rec.tags ~= nil and rec.tags[t.id] ~= nil
            chip:Set(t.def.name, on and UI.TIER_COLOR[tier] or DIM, PICK_W, on)
            chip.tagId, chip.isNew, chip.picked = t.id, nil, on
            chip.tipTitle = t.def.name
            chip.tipText = on and L["Click to remove this tag."] or L["Click to add this tag."]
            if t.custom then
                chip.tipText = chip.tipText .. "\n" .. U.Color(ns.COLOR.grey, L["One of your own tags. You can delete it on the Options tab, under Data."])
            end
            x = place(chip, x)
        end
        y = y - 30
    end
    n = n + 1
    local new = pickerChip(n)
    new:Set(L["+ New tag..."], W.theme.label or W.GOLD, PICK_W)
    new.tagId, new.isNew, new.picked = nil, true, nil
    new.tipTitle = L["New tag"]
    new.tipText = L["Make a tag of your own. You can use it on every player."]
    place(new, 0)
    for i = n + 1, #picker.chips do
        picker.chips[i]:Hide()
    end
    picker.hint:ClearAllPoints()
    picker.hint:SetPoint("TOPLEFT", PICK_PAD, y - 30)
    picker:SetSize(PICK_W + PICK_PAD * 2, -(y - 30) + 22)
end

-- Opens the tag picker under the chip that was clicked (or closes it when it is open there).
function Players.TagPicker(owner)
    if not current() then
        return
    end
    if not picker then
        buildPicker()
    end
    if picker:IsShown() and picker.owner == owner then
        closePicker()
        return
    end
    W.Menu:Hide()
    picker.owner = owner
    picker:SetScale(W.Scale())
    picker:ClearAllPoints()
    -- Under the tags, lined up with their right edge: it stays inside the window.
    picker:SetPoint("TOPRIGHT", owner:GetParent(), "BOTTOMRIGHT", 4, -4)
    Players.LayoutPicker()
    picker:Show()
    picker:Raise()
end

local function buildDetails(p)
    local d = W.Box(p)
    d:SetPoint("TOPLEFT", LIST_W + 12, -TOP)
    d:SetPoint("BOTTOMRIGHT", 0, 0)
    p.details = d
    d.parts = {}
    local function part(obj)
        d.parts[#d.parts + 1] = obj
        return obj
    end

    -- Who they are
    d.icon = part(d:CreateTexture(nil, "ARTWORK"))
    d.icon:SetSize(40, 40)
    d.icon:SetPoint("TOPLEFT", PAD, -14)
    d.icon:SetTexture(U.CLASS_CIRCLES)
    d.name = part(W.OneLine(d:CreateFontString(nil, "ARTWORK", "GameFontHighlightHuge")))
    d.name:SetJustifyH("LEFT")
    d.sub = part(W.OneLine(W.Label(d, "", "GameFontHighlightSmall")))
    d.meta = part(W.OneLine(W.Label(d, "", "GameFontDisableSmall")))
    d.who = part(CreateFrame("Frame", nil, d))
    d.who:SetPoint("TOPLEFT", PAD, -10)
    d.who:SetPoint("TOPRIGHT", -PAD, -10)
    d.who:SetHeight(52)
    d.who:EnableMouse(true)
    d.who:SetScript("OnEnter", function(self)
        local rec = current()
        if not rec then
            return
        end
        local lines = { SOURCE_TEXT[rec.source or "manual"] or SOURCE_TEXT.manual }
        if rec.sourcePeer then
            lines[#lines + 1] = { L["Shared by"], rec.sourcePeer }
        end
        lines[#lines + 1] = { L["First seen"], U.DateTime(rec.firstSeen) }
        lines[#lines + 1] = { L["Last seen"], U.DateTime(rec.lastSeen) }
        if rec.bnetTag and not ns.S.streamerMode then
            lines[#lines + 1] = { L["Battle.net"], rec.bnetTag }
        end
        W.ShowTip(self, U.Plain(UI.Name(rec)), lines, "ANCHOR_BOTTOM")
    end)
    d.who:SetScript("OnLeave", W.HideTip)
    local line = part(W.Divider(d, 0.3))
    line:SetPoint("TOPLEFT", PAD, -66)
    line:SetPoint("TOPRIGHT", -PAD, -66)

    -- Rating
    d.ratingLabel = part(W.Label(d, L["Rating"], "RepKeeperFontNormalSmall"))
    d.rating = part(W.Segmented(d, UI.RatingChoices(), function()
        local rec = current()
        return rec and (rec.reputation or 0)
    end, function(level)
        UI.SetRating(current(), level)
    end))

    -- Tags
    d.tagsLabel = part(W.Label(d, L["Tags"], "RepKeeperFontNormalSmall"))
    d.tagArea = part(CreateFrame("Frame", nil, d))
    d.tagArea:SetHeight(20)
    d.chips = {}
    d.addTag = W.Chip(d.tagArea, function(chip)
        Players.TagPicker(chip)
    end)
    d.addTag.tipTitle = L["Add a tag"]
    d.addTag.tipText = L["Tags say why: Ninja Looter, Good Healer, or a tag of your own."]

    -- Note
    d.noteLabel = part(W.Label(d, L["Note"], "RepKeeperFontNormalSmall"))
    d.saved = part(W.Label(d, "", "GameFontDisableSmall"))
    d.note = part(W.TextArea(d, {
        noBar = true,
        maxLetters = 2000,
        font = "GameFontHighlightSmall",
        placeholder = L["Write a note about them. It shows when you hover them in the game."],
        onCommit = Players.SaveNote,
    }))
    d.note:SetHeight(54)
    -- Enter saves the note; Shift+Enter starts a new line.
    d.note.edit:SetScript("OnEnterPressed", function(self)
        if IsShiftKeyDown() then
            self:Insert("\n")
        else
            self:ClearFocus()
        end
    end)

    -- History
    d.historyLabel = part(W.Label(d, L["History"], "RepKeeperFontNormalSmall"))
    d.historyCount = part(W.Label(d, "", "GameFontDisableSmall"))
    d.historyAdd = part(W.EditBox(d, 200, {
        maxLetters = 200,
        placeholder = L["Add what happened, then press Enter"],
        onEnter = function(self, text)
            local rec = current()
            text = U.Trim(text)
            if rec and text ~= "" then
                ns.Timeline:Append(rec, "manual", text)
            end
            self:SetText("")
        end,
    }))
    d.history = part(W.List(d, {
        {
            key = "when", width = 86,
            get = function(it)
                return historyDate(it.entry.ts), 0.62, 0.62, 0.62
            end,
        },
        {
            key = "text", fill = true,
            get = function(it)
                local c = TYPE_COLOR[it.entry.type] or TYPE_COLOR.manual
                return it.entry.text or "", c[1], c[2], c[3]
            end,
        },
    }, {
        noHeader = true,
        rowHeight = 18,
        onEnter = function(it, row)
            local e = it.entry
            W.ShowTip(row, U.DateTime(e.ts), { e.text or "", U.Color(ns.COLOR.grey, TYPE_NAME[e.type] or TYPE_NAME.manual),
                U.Color(ns.COLOR.grey, L["Right-click to delete it."]) })
        end,
        onClick = function(it, _, button)
            if button ~= "RightButton" then
                return
            end
            local rec = current()
            W.ContextMenu(d.history, {
                { text = L["History entry"], isTitle = true },
                { text = L["Delete this entry"], color = { 1, 0.45, 0.45 }, func = function()
                    if rec then
                        removeHistoryEntry(rec, it.entry)
                    end
                end },
            })
        end,
    }))

    -- What you can do with them
    d.remove = part(W.Button(d, L["Remove"], nil, function()
        UI.ConfirmRemove(current())
    end, L["Delete this player from RepKeeper (asks first)."]))
    d.remove:SetPoint("BOTTOMRIGHT", -PAD + 2, 12)
    d.whisper = part(W.Button(d, L["Whisper"], nil, function()
        UI.Whisper(current())
    end, L["Opens a whisper to them in chat."]))
    d.whisper:SetPoint("RIGHT", d.remove, "LEFT", -6, 0)
    d.alts = part(W.OneLine(W.Label(d, "", "GameFontDisableSmall")))
    d.alts:SetPoint("BOTTOMLEFT", PAD, 18)
    d.alts:SetPoint("BOTTOMRIGHT", d.whisper, "BOTTOMLEFT", -10, 6)

    -- Shown instead when there is nobody to show.
    d.empty = W.Text(d, "", 380, "GameFontHighlight")
    d.empty:SetPoint("CENTER", 0, 20)
    d.empty:SetJustifyH("CENTER")
    d.empty:Hide()
end

local function makeChip(d)
    local chip = W.Chip(d.tagArea, function(self)
        local rec = current()
        if rec and self.tagId then
            ns.Database:ToggleTag(rec, self.tagId)
        end
    end)
    d.chips[#d.chips + 1] = chip
    return chip
end

-- Lays the tags out in rows; returns the height they take.
local function layoutTags(d, rec)
    local area = d.tagArea
    local width = area:GetWidth()
    if not width or width < 50 then
        width = 340
    end
    local x, y, rowH = 0, 0, 24
    local tags = UI.PlayerTags(rec)
    for i, t in ipairs(tags) do
        local chip = d.chips[i] or makeChip(d)
        chip:Set(t.def.name, UI.TIER_COLOR[t.tier], width)
        chip.tagId = t.id
        chip.tipTitle = t.def.name
        chip.tipText = L["Click to remove this tag."]
        if x > 0 and x + chip:GetWidth() > width then
            x, y = 0, y - rowH
        end
        chip:ClearAllPoints()
        chip:SetPoint("TOPLEFT", area, "TOPLEFT", x, y)
        chip:Show()
        x = x + chip:GetWidth() + 4
    end
    for i = #tags + 1, #d.chips do
        d.chips[i]:Hide()
        d.chips[i].tagId = nil
    end
    local add = d.addTag
    add:Set(#tags == 0 and L["+ Add a tag"] or L["+ Tag"], W.theme.label or W.GOLD)
    if x > 0 and x + add:GetWidth() > width then
        x, y = 0, y - rowH
    end
    add:ClearAllPoints()
    add:SetPoint("TOPLEFT", area, "TOPLEFT", x, y)
    local h = -y + 20
    area:SetHeight(h)
    return h
end

-- Places the rows of the form under each other (the tags can take more than one line).
local function layoutForm(d, tagsHeight)
    local y = -80
    d.ratingLabel:SetPoint("TOPLEFT", PAD, y - 6)
    d.rating:SetPoint("TOPLEFT", FORM_X, y)
    d.rating:SetPoint("TOPRIGHT", -PAD, y)
    y = y - 24 - ROW_GAP
    d.tagsLabel:SetPoint("TOPLEFT", PAD, y - 4)
    d.tagArea:SetPoint("TOPLEFT", FORM_X, y)
    d.tagArea:SetPoint("TOPRIGHT", -PAD, y)
    y = y - tagsHeight - ROW_GAP
    d.noteLabel:SetPoint("TOPLEFT", PAD, y - 6)
    d.saved:SetPoint("TOPLEFT", d.noteLabel, "BOTTOMLEFT", 0, -4)
    d.note:SetPoint("TOPLEFT", FORM_X, y + 2)
    d.note:SetPoint("TOPRIGHT", -PAD, y + 2)
    y = y - 54 - ROW_GAP + 2
    d.historyLabel:SetPoint("TOPLEFT", PAD, y - 4)
    d.historyCount:SetPoint("TOPLEFT", d.historyLabel, "BOTTOMLEFT", 0, -4)
    d.historyAdd:SetPoint("TOPLEFT", FORM_X + 5, y)
    d.historyAdd:SetPoint("TOPRIGHT", -PAD, y)
    d.history:SetPoint("TOPLEFT", FORM_X - 1, y - 24)
    d.history:SetPoint("BOTTOMRIGHT", -PAD + 5, 42)
end

local function showEmpty(d, text)
    for _, obj in ipairs(d.parts) do
        obj:Hide()
    end
    d.empty:SetText(text)
    d.empty:Show()
end

function Players.RefreshDetails()
    local d = page and page.details
    if not d then
        return
    end
    local rec = current()
    if not rec then
        if next(ns.db.global.players) == nil then
            showEmpty(d, L["No players yet."] .. "\n\n" .. U.Color(ns.COLOR.grey,
                L["Right-click someone in the game and choose RepKeeper to rate them, or press Add player. RepKeeper also remembers the players from your dungeon groups."]))
        else
            showEmpty(d, L["No players match."] .. "\n\n" .. U.Color(ns.COLOR.grey,
                L["Clear the search, or pick All above the list."]))
        end
        return
    end
    d.empty:Hide()
    for _, obj in ipairs(d.parts) do
        obj:Show()
    end

    -- Who they are
    local l, r, t, b = U.ClassCoords(rec.class)
    local textX = PAD
    if l then
        d.icon:SetTexCoord(l, r, t, b)
        d.icon:Show()
        textX = PAD + 50
    else
        d.icon:Hide()
    end
    d.name:ClearAllPoints()
    d.name:SetPoint("TOPLEFT", textX, -14)
    d.name:SetPoint("TOPRIGHT", -PAD, -14)
    d.sub:ClearAllPoints()
    d.sub:SetPoint("TOPLEFT", textX, -38)
    d.sub:SetPoint("TOPRIGHT", -PAD, -38)
    d.meta:ClearAllPoints()
    d.meta:SetPoint("TOPLEFT", textX, -52)
    d.meta:SetPoint("TOPRIGHT", -PAD, -52)
    d.name:SetText(U.Plain(UI.Name(rec)))
    d.name:SetTextColor(U.ClassRGB(rec.class))

    local sub = {}
    local who = U.Trim((raceName(rec.race) or "") .. " " .. (U.ClassName(rec.class) or ""))
    if who ~= "" then
        sub[#sub + 1] = who
    end
    if rec.faction == "Horde" or rec.faction == "Alliance" then
        sub[#sub + 1] = U.Color(rec.faction == "Horde" and "ff6060" or "6aa8ff", rec.faction == "Horde" and L["Horde"] or L["Alliance"])
    end
    if #sub == 0 then
        sub[1] = U.Color(ns.COLOR.grey, L["Race and class show once you meet them in the game."])
    end
    d.sub:SetText(table.concat(sub, UI.DOT))

    local meta = {}
    local where = rec.firstSeenLocation
    if where and where ~= "" and where ~= "unknown" then
        meta[#meta + 1] = format(L["Met in %s"], where)
    else
        meta[#meta + 1] = format(L["Added %s"], U.Date(rec.firstSeen))
    end
    meta[#meta + 1] = format(L["Seen %s"], lowerFirst(U.Ago(rec.lastSeen)))
    local groups = rec.encounterCount or 0
    if groups > 0 then
        meta[#meta + 1] = format(groups == 1 and L["%d group together"] or L["%d groups together"], groups)
    end
    d.meta:SetText(table.concat(meta, UI.DOT))

    -- The form
    d.rating:Refresh()
    layoutForm(d, layoutTags(d, rec))
    if not (d.note:HasFocus() and d.noteKey == rec.normalizedKey) then
        d.noteKey = rec.normalizedKey
        d.note:SetText(rec.notes or "")
    end
    local n = rec.timeline and #rec.timeline or 0
    d.historyCount:SetText(n > 0 and U.Number(n) or "")
    d.history:SetData(historyItems(rec))
    d.history:SetEmptyText(L["Nothing yet. Write what happened above, or let RepKeeper note it for you."])

    -- Alts
    if rec.altIDs and #rec.altIDs > 0 then
        local names = {}
        for _, k in ipairs(rec.altIDs) do
            local alt = ns.db.global.players[k]
            names[#names + 1] = alt and ns.PlayerUtils:DisplayNamePlain(alt) or k
        end
        d.alts:SetText(L["Alts:"] .. " " .. table.concat(names, ", "))
    else
        d.alts:SetText("")
    end

    if focusNote then
        focusNote = false
        d.note:SetFocus()
    end
    if picker and picker:IsShown() then
        Players.LayoutPicker()
    end
end

-- Before another player is shown: the note being written is saved for the player it was written for, and a half
-- typed history line is dropped.
local function leavePlayer(d)
    closePicker()
    if d.note:HasFocus() then
        d.note.edit:ClearFocus()
    end
    d.historyAdd:SetText("")
    d.historyAdd:ClearFocus()
end

-- Picks a player.
function Players.Select(key)
    local d = page and page.details
    if d and key ~= selectedKey then
        leavePlayer(d)
    end
    selectedKey = key
    if page then
        page.list.selected = key
        page.list:Refresh()
        Players.RefreshDetails()
    end
end

---------------------------------------------------------------------------
-- The page
---------------------------------------------------------------------------
local function create(p)
    page = p
    buildTopBar(p)
    buildList(p)
    buildDetails(p)
    p:HookScript("OnHide", closePicker)
end

local function inView(list, key)
    for _, rec in ipairs(list:GetView()) do
        if rec.normalizedKey == key then
            return true
        end
    end
    return false
end

local function refresh(p)
    local list, counts = collect()
    refreshFilters(p, counts)
    p.list:SetData(list)
    -- The picked player is always one of the listed ones (a filter or search may hide them).
    if not (selectedKey and inView(p.list, selectedKey)) then
        local first = p.list:GetView()[1]
        leavePlayer(p.details)
        selectedKey = first and first.normalizedKey or nil
    end
    local rec = current()
    p.list.selected = selectedKey
    if rec then
        p.list:ScrollToItem(rec)
    end
    p.list:SetEmptyText(next(ns.db.global.players) == nil and L["No players yet."] or L["No players match."])
    p.list:Refresh()
    Players.RefreshDetails()
end

UI.RegisterPage({
    id = "players",
    label = L["Players"],
    tip = L["Everyone you rated or met: their rating, tags, note and history."],
    order = 1,
    create = create,
    refresh = refresh,
})

-- Opens the window on a player. opts.focus = "note" puts the cursor in their note.
function UI.ShowPlayer(key, opts)
    local rec = key and ns.db.global.players[key]
    if rec then
        -- A filter that would hide them is cleared.
        if filter.rating ~= nil and (rec.reputation or 0) ~= filter.rating then
            filter.rating = nil
        end
        if filter.text ~= "" and not matchesSearch(rec, U.Trim(filter.text):lower()) then
            filter.text = ""
            if page then
                page.search:SetText("")
            end
        end
    end
    if page then
        Players.Select(key)
    else
        selectedKey = key
    end
    focusNote = opts ~= nil and opts.focus == "note"
    UI.Show("players")
    UI.Refresh("players")
end

---------------------------------------------------------------------------
-- Old entry points (right-click menu, quick add pop-up, slash commands)
---------------------------------------------------------------------------
local PlayerEditor = {}
ns.PlayerEditor = PlayerEditor

function PlayerEditor:Initialize() end

function PlayerEditor:Open(rec, opts)
    if rec then
        UI.ShowPlayer(rec.normalizedKey, opts)
    end
end

function PlayerEditor:OpenNew()
    UI.AddPlayerDialog()
end

function PlayerEditor:Close()
    UI.Hide()
end
