-- UI/Groups.lua
-- The Groups page: the dungeons, raids and battlegrounds you ran and who was in them, so you can rate the players of
-- a run right after it. Reads the encounter history (Modules\EncounterHistory.lua).

local addonName, ns = ...
local L = LibStub("AceLocale-3.0"):GetLocale("RepKeeper")
local C = ns.Constants
local U, W, UI = ns.U, ns.W, ns.UI

local format, floor, max = string.format, math.floor, math.max

local LIST_W = 452
local TOP = 32
local PAD = 14

local Groups = {}
UI.Groups = Groups

local page
local selectedId
local kindFilter = "all"

local T = C.ENCOUNTER_TYPE
local TYPE_NAME = {
    [T.DUNGEON] = L["Dungeon"],
    [T.MYTHIC_PLUS] = L["Mythic+"],
    [T.RAID] = L["Raid"],
    [T.ARENA_2V2] = L["Arena 2v2"],
    [T.ARENA_3V3] = L["Arena 3v3"],
    [T.BATTLEGROUND] = L["Battleground"],
    [T.RATED_BG] = L["Rated BG"],
    [T.DELVE] = L["Delve"],
    [T.SCENARIO] = L["Scenario"],
    [T.OPEN_WORLD] = L["Open World"],
}
local KIND_OF_TYPE = {
    [T.DUNGEON] = "dungeons", [T.MYTHIC_PLUS] = "dungeons", [T.DELVE] = "dungeons", [T.SCENARIO] = "dungeons",
    [T.RAID] = "raids",
    [T.ARENA_2V2] = "pvp", [T.ARENA_3V3] = "pvp", [T.BATTLEGROUND] = "pvp", [T.RATED_BG] = "pvp",
    [T.OPEN_WORLD] = "dungeons",
}

local R = C.ENCOUNTER_RESULT
local RESULT = {
    [R.COMPLETED] = { L["Completed"], "40ff40" },
    [R.TIMED] = { L["Timed"], "40ff40" },
    [R.DEPLETED] = { L["Depleted"], "ff9a20" },
    [R.ABANDONED] = { L["Abandoned"], "9d9d9d" },
    [R.LEFT_EARLY] = { L["Left Early"], "ff9a20" },
    [R.KICKED] = { L["Kicked"], "ff5050" },
    [R.WIPE] = { L["Wiped"], "ff5050" },
}

local function resultText(enc)
    local r = RESULT[enc.result or 0]
    if not r then
        return U.Color(ns.COLOR.grey, "-")
    end
    return U.Color(r[2], r[1])
end

local function placeText(enc)
    local extra = enc.extra or {}
    local name = extra.instanceName
    if name and name ~= "" then
        if extra.keyLevel then
            return name .. " +" .. extra.keyLevel
        end
        return name
    end
    return TYPE_NAME[enc.type] or L["Unknown"]
end

-- "grimtusk-ragnaros" -> "Grimtusk", "Ragnaros": names of players RepKeeper only knows from the group. The game writes
-- names with a capital first letter and the rest small, and the key only lowered A to Z (letters like Ö stay as they
-- are), so a capital first letter on every word gives the name back. Only the first letter: %a doesn't know letters
-- like ö, so capitalising after them would garble the name ("BjöRn").
local function titleCase(s)
    return (s:gsub("%S+", function(word)
        return (word:gsub("^%l", string.upper))
    end))
end

local function splitKey(key)
    local dash = key:match("^.*()%-")
    if not dash then
        return titleCase(key), nil
    end
    return titleCase(key:sub(1, dash - 1)), titleCase(key:sub(dash + 1))
end

-- A member of a run: the record when RepKeeper has one.
local function memberName(m)
    if m.rec then
        return UI.Name(m.rec)
    end
    local name, realm = splitKey(m.key)
    if ns.PlayerUtils:TwoPartNames() and realm and not name:find(" ") then
        return name .. " " .. realm
    end
    return name
end

-- Makes a record for someone RepKeeper only knows from a run (to rate or open them).
local function ensureRecord(m, enc)
    if m.rec then
        return m.rec
    end
    local name, realm = splitKey(m.key)
    local rec, created = ns.Database:GetOrCreatePlayer(realm and (name .. "-" .. realm) or name)
    if rec and created then
        rec.source = "auto_group"
        rec.firstSeen = enc.timestamp or rec.firstSeen
        local where = enc.extra and enc.extra.instanceName
        if where and where ~= "" then
            rec.firstSeenLocation = where
        end
    end
    m.rec = rec
    return rec
end

---------------------------------------------------------------------------
-- The list of runs
---------------------------------------------------------------------------
local FILTERS = {
    { id = "all", label = L["All"] },
    { id = "dungeons", label = L["Dungeons"] },
    { id = "raids", label = L["Raids"] },
    { id = "pvp", label = L["PvP"] },
}

local function collect()
    local list, counts = {}, { all = 0, dungeons = 0, raids = 0, pvp = 0 }
    for _, enc in pairs(ns.db.global.encounters or {}) do
        local kind = KIND_OF_TYPE[enc.type] or "dungeons"
        counts.all = counts.all + 1
        counts[kind] = counts[kind] + 1
        if kindFilter == "all" or kindFilter == kind then
            list[#list + 1] = enc
        end
    end
    return list, counts
end

local function buildTop(p)
    p.filters = {}
    local prev
    for i, def in ipairs(FILTERS) do
        local b = W.TextButton(p, def.label, function()
            kindFilter = def.id
            UI.Refresh("groups")
        end)
        b.def = def
        b.underline = W.Divider(b, 0.9)
        b.underline:SetPoint("BOTTOMLEFT", 0, -2)
        b.underline:SetPoint("BOTTOMRIGHT", 0, -2)
        if prev then
            b:SetPoint("LEFT", prev, "RIGHT", 12, 0)
        else
            b:SetPoint("TOPLEFT", 6, -9)
        end
        p.filters[i] = b
        prev = b
    end
    p.hint = W.Label(p, L["Pick a run to see who was there. Rate them with one click."], "GameFontDisableSmall")
    p.hint:SetPoint("TOPRIGHT", -4, -10)
    p.hint:SetJustifyH("RIGHT")
end

local function buildList(p)
    p.list = W.List(p, {
        {
            key = "when", label = L["When"], width = 96,
            get = function(enc)
                return U.Ago(enc.timestamp), 0.62, 0.62, 0.62
            end,
            sortValue = function(enc)
                return enc.timestamp or 0
            end,
            defaultDesc = true,
        },
        {
            key = "where", label = L["Where"], fill = true,
            get = function(enc)
                return placeText(enc)
            end,
            sortValue = function(enc)
                return placeText(enc):lower()
            end,
        },
        {
            key = "result", label = L["Result"], width = 86,
            get = function(enc)
                return resultText(enc)
            end,
            sortValue = function(enc)
                return enc.result or 0
            end,
        },
        {
            key = "size", label = L["Players"], width = 62, justify = "RIGHT",
            get = function(enc)
                return tostring(#(enc.participants or {}))
            end,
            sortValue = function(enc)
                return #(enc.participants or {})
            end,
            defaultDesc = true,
        },
    }, {
        rowHeight = 20,
        sortKey = "when",
        sortDesc = true,
        selectKey = function(enc)
            return enc.id
        end,
        onClick = function(enc)
            selectedId = enc.id
            Groups.RefreshDetails()
        end,
    })
    p.list:SetPoint("TOPLEFT", 0, -TOP)
    p.list:SetPoint("BOTTOMLEFT", 0, 0)
    p.list:SetWidth(LIST_W)
end

---------------------------------------------------------------------------
-- Who was in the picked run
---------------------------------------------------------------------------
local function decorateMember(row, m, list)
    if not row.classIcon then
        row.classIcon = row:CreateTexture(nil, "ARTWORK")
        row.classIcon:SetSize(14, 14)
        row.classIcon:SetTexture(U.CLASS_CIRCLES)
        row.rate = {}
        for i, level in ipairs(UI.RATING_ORDER) do
            local b = CreateFrame("Button", nil, row)
            b:SetSize(18, 18)
            b.icon = b:CreateTexture(nil, "ARTWORK")
            b.icon:SetAllPoints()
            b.icon:SetAtlas(UI.RATING[level].atlas)
            b.level = level
            b:SetScript("OnClick", function(self)
                local member = self:GetParent().item
                local enc = Groups.Current()
                if member and enc then
                    W.Sound("click")
                    local rec = ensureRecord(member, enc)
                    UI.SetRating(rec, self.level)
                    UI.Refresh()
                end
            end)
            b:SetScript("OnEnter", function(self)
                self.icon:SetAlpha(1)
                W.ShowTip(self, UI.RatingName(self.level), UI.RATING[self.level].tip, "ANCHOR_TOP")
            end)
            b:SetScript("OnLeave", function(self)
                W.HideTip()
                Groups.PaintRate(self:GetParent())
            end)
            row.rate[i] = b
        end
    end
    local x, w = list:Column("name")
    row.classIcon:ClearAllPoints()
    row.classIcon:SetPoint("LEFT", row, "LEFT", x + 6, 0)
    local l, r, t, b = U.ClassCoords(m.rec and m.rec.class)
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
    local rx = list:Column("rate")
    for i, btn in ipairs(row.rate) do
        btn:ClearAllPoints()
        btn:SetPoint("LEFT", row, "LEFT", rx + 4 + (i - 1) * 21, 0)
    end
    Groups.PaintRate(row)
end

-- The rating buttons of a member row: their rating bright, the others faint.
function Groups.PaintRate(row)
    local m = row.item
    if not m or not row.rate then
        return
    end
    local level = m.rec and (m.rec.reputation or 0)
    for _, b in ipairs(row.rate) do
        local on = level == b.level
        b.icon:SetDesaturated(not on)
        b.icon:SetAlpha(on and 1 or 0.35)
    end
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

    d.title = part(W.OneLine(d:CreateFontString(nil, "ARTWORK", "RepKeeperFontNormalLarge")))
    d.title:SetPoint("TOPLEFT", PAD, -14)
    d.title:SetPoint("TOPRIGHT", -PAD, -14)
    d.title:SetJustifyH("LEFT")
    d.sub = part(W.OneLine(W.Label(d, "", "GameFontHighlightSmall")))
    d.sub:SetPoint("TOPLEFT", PAD, -36)
    d.sub:SetPoint("TOPRIGHT", -PAD, -36)
    d.meta = part(W.OneLine(W.Label(d, "", "GameFontDisableSmall")))
    d.meta:SetPoint("TOPLEFT", PAD, -52)
    d.meta:SetPoint("TOPRIGHT", -PAD, -52)
    local line = part(W.Divider(d, 0.3))
    line:SetPoint("TOPLEFT", PAD, -70)
    line:SetPoint("TOPRIGHT", -PAD, -70)

    d.membersLabel = part(W.Label(d, L["Who was there"], "RepKeeperFontNormalSmall"))
    d.membersLabel:SetPoint("TOPLEFT", PAD, -80)
    d.membersHint = part(W.Label(d, L["Click a name to open them"], "GameFontDisableSmall"))
    d.membersHint:SetPoint("TOPRIGHT", -PAD, -80)
    d.membersHint:SetJustifyH("RIGHT")

    d.members = part(W.List(d, {
        {
            key = "name", fill = true,
            get = function(m)
                local text = memberName(m)
                if m.leftEarly then
                    text = text .. " " .. U.Color(ns.COLOR.orange, L["(left)"])
                end
                return text
            end,
        },
        {
            key = "rating", width = 92,
            get = function(m)
                if not m.rec then
                    return U.Color(ns.COLOR.grey, L["Not on your list"])
                end
                return UI.RatingLabel(m.rec.reputation)
            end,
        },
        { key = "rate", width = 70, get = function()
            return ""
        end },
    }, {
        noHeader = true,
        rowHeight = 22,
        onEnter = function(m, row)
            local lines = {}
            if m.leftEarly then
                lines[#lines + 1] = U.Color(ns.COLOR.orange, L["Left the group before the run ended."])
            end
            lines[#lines + 1] = m.rec and L["Click to open them in RepKeeper."] or L["Click to add them to your list and open them."]
            W.ShowTip(row, U.Plain(memberName(m)), lines)
        end,
        onClick = function(m)
            local enc = Groups.Current()
            if enc then
                local rec = ensureRecord(m, enc)
                if rec then
                    UI.ShowPlayer(rec.normalizedKey)
                end
            end
        end,
        decorate = decorateMember,
    }))
    d.members:SetPoint("TOPLEFT", PAD - 4, -96)
    d.members:SetPoint("BOTTOMRIGHT", -PAD + 4, 12)

    d.empty = W.Text(d, "", 360, "GameFontHighlight")
    d.empty:SetPoint("CENTER", 0, 20)
    d.empty:SetJustifyH("CENTER")
    d.empty:Hide()
end

function Groups.Current()
    return selectedId and ns.db.global.encounters and ns.db.global.encounters[selectedId] or nil
end

local function showEmpty(d, text)
    for _, obj in ipairs(d.parts) do
        obj:Hide()
    end
    d.empty:SetText(text)
    d.empty:Show()
end

function Groups.RefreshDetails()
    local d = page and page.details
    if not d then
        return
    end
    local enc = Groups.Current()
    if not enc then
        if not ns.S.encounterHistoryEnabled then
            showEmpty(d, L["Group history is off."] .. "\n\n" .. U.Color(ns.COLOR.grey,
                L["Turn on Remember my groups on the Options tab, under Tracking."]))
        elseif next(ns.db.global.encounters or {}) == nil then
            showEmpty(d, L["No groups yet."] .. "\n\n" .. U.Color(ns.COLOR.grey,
                L["RepKeeper remembers your dungeons, raids and battlegrounds, and who was in them."]))
        elseif kindFilter ~= "all" and #page.list:GetView() == 0 then
            showEmpty(d, L["No runs of this kind yet."] .. "\n\n" .. U.Color(ns.COLOR.grey,
                L["Pick All above the list to see every run."]))
        else
            showEmpty(d, L["Pick a run on the left."])
        end
        return
    end
    d.empty:Hide()
    for _, obj in ipairs(d.parts) do
        obj:Show()
    end
    local extra = enc.extra or {}
    d.title:SetText(placeText(enc))
    d.sub:SetText((TYPE_NAME[enc.type] or L["Unknown"]) .. UI.DOT .. resultText(enc))
    local meta = { U.DateTime(enc.timestamp) }
    if extra.startTime and extra.endTime and extra.endTime > extra.startTime then
        meta[#meta + 1] = U.Duration(extra.endTime - extra.startTime)
    end
    d.meta:SetText(table.concat(meta, UI.DOT))

    local members = {}
    local players = ns.db.global.players
    for _, key in ipairs(enc.participants or {}) do
        members[#members + 1] = { key = key, rec = players[key], leftEarly = extra.leftEarly and extra.leftEarly[key] ~= nil }
    end
    table.sort(members, function(a, b)
        return U.Plain(memberName(a)):lower() < U.Plain(memberName(b)):lower()
    end)
    d.members:SetData(members)
    d.members:SetEmptyText(L["Nobody else was in this group."])
end

---------------------------------------------------------------------------
-- The page
---------------------------------------------------------------------------
local function create(p)
    page = p
    buildTop(p)
    buildList(p)
    buildDetails(p)
end

local function refresh(p)
    local list, counts = collect()
    for _, b in ipairs(p.filters) do
        local on = kindFilter == b.def.id
        b:SetNormalFontObject(on and "GameFontHighlightSmall" or "RepKeeperFontNormalSmall")
        b:SetLabel(b.def.label .. " " .. U.Color(on and ns.COLOR.white or ns.COLOR.grey, U.Number(counts[b.def.id] or 0)))
        b.underline:SetShown(on)
    end
    p.list:SetData(list)
    -- The picked run is always one of the listed ones (the filter may hide it).
    local listed = false
    for _, enc in ipairs(p.list:GetView()) do
        if enc.id == selectedId then
            listed = true
            break
        end
    end
    if not listed then
        local first = p.list:GetView()[1]
        selectedId = first and first.id or nil
    end
    p.list.selected = selectedId
    local enc = Groups.Current()
    if enc then
        p.list:ScrollToItem(enc)
    end
    local empty = L["No runs of this kind yet."]
    if next(ns.db.global.encounters or {}) == nil then
        empty = ns.S.encounterHistoryEnabled and L["No groups yet."] or L["Group history is off."]
    end
    p.list:SetEmptyText(empty)
    p.list:Refresh()
    Groups.RefreshDetails()
end

UI.RegisterPage({
    id = "groups",
    label = L["Groups"],
    tip = L["The runs you did and who was in them: rate the players of a run with one click."],
    order = 2,
    create = create,
    refresh = refresh,
})
