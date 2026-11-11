-- UI/Dialogs.lua
-- Small windows of RepKeeper's own: confirm, add a player, a new tag, export and import. They never use the game's
-- StaticPopupDialogs, which are shared with secure code (the gear upgrade window) and taint on Midnight.

local addonName, ns = ...
local L = LibStub("AceLocale-3.0"):GetLocale("RepKeeper")
local C = ns.Constants
local U, W, UI = ns.U, ns.W, ns.UI

local format, floor, max = string.format, math.floor, math.max

local function dialog(name, title, width, height)
    local f = W.Window(name, title, width, height, { strata = "DIALOG", sound = true, solid = true })
    return f
end

-- Text that says what went wrong (red) or right (green) under a form.
local function setStatus(fs, text, good)
    if good == nil then
        fs:SetText(text and U.Color(ns.COLOR.grey, text) or "")
    else
        fs:SetText(U.Color(good and ns.COLOR.green or ns.COLOR.red, text))
    end
end

---------------------------------------------------------------------------
-- Confirm
---------------------------------------------------------------------------
local confirm

function UI.Confirm(title, text, acceptText, onAccept)
    if not confirm then
        confirm = W.Window("RepKeeperConfirm", "", 380, 150, { strata = "FULLSCREEN_DIALOG", sound = true, solid = true })
        confirm.text = W.Text(confirm, "", 330, "GameFontHighlight")
        confirm.text:SetPoint("TOP", 0, -38)
        confirm.text:SetJustifyH("CENTER")
        confirm.accept = W.Button(confirm, "", 130, function()
            local fn = confirm.onAccept
            confirm.onAccept = nil
            confirm:Hide()
            if fn then
                ns.SafeCall(fn)
            end
        end)
        confirm.cancel = W.Button(confirm, L["Cancel"], 130, function()
            confirm:Hide()
        end)
        confirm.accept:SetPoint("BOTTOMRIGHT", confirm, "BOTTOM", -4, 20)
        confirm.cancel:SetPoint("BOTTOMLEFT", confirm, "BOTTOM", 4, 20)
        function confirm:onHidden()
            self.onAccept = nil
        end
    end
    confirm:Hide()
    confirm.header:SetTitle(title)
    confirm.text:SetText(text)
    confirm.accept:SetText(acceptText or L["OK"])
    W.FitButton(confirm.accept, 130)
    confirm.onAccept = onAccept
    confirm:SetHeight(floor(confirm.text:GetStringHeight() + 0.5) + 100)
    confirm:Show()
    confirm:Raise()
    return confirm
end

---------------------------------------------------------------------------
-- Player actions shared by the pages and pop-ups
---------------------------------------------------------------------------
function UI.Whisper(rec)
    local target = rec and ns.PlayerUtils:WhisperTarget(rec)
    if not target then
        return
    end
    if ChatFrameUtil and ChatFrameUtil.SendTell then
        ChatFrameUtil.SendTell(target)
    elseif ChatFrame_SendTell then
        ChatFrame_SendTell(target)
    end
end

function UI.ConfirmRemove(rec, after)
    if not rec then
        return
    end
    local name = ns.PlayerUtils:DisplayNamePlain(rec)
    UI.Confirm(L["Remove player"],
        format(L["Remove %s from RepKeeper?\nTheir rating, tags, note and history are deleted."], name),
        L["Remove"], function()
            ns.Database:RemovePlayer(rec.normalizedKey)
            ns.Addon:Printf(L["Player removed: %s"], name)
            if after then
                after()
            end
        end)
end

function UI.SetRating(rec, level)
    if not rec or (rec.reputation or 0) == level then
        return
    end
    ns.Reputation:Set(rec, level)
end

---------------------------------------------------------------------------
-- Add a player
---------------------------------------------------------------------------
local add

local function buildAdd()
    add = dialog("RepKeeperAddPlayer", L["Add a player"], 400, 262)
    local x, labelW = 24, 70

    local nameLabel = W.Label(add, L["Name"], "RepKeeperFontNormalSmall")
    nameLabel:SetPoint("TOPLEFT", x, -42)
    add.name = W.EditBox(add, 270, {
        maxLetters = 60,
        onEnter = function()
            add:Submit()
            return true
        end,
        onTab = function()
            add.note:SetFocus()
        end,
    })
    add.name:SetPoint("TOPLEFT", x + labelW + 6, -38)
    add.hint = W.Label(add, "", "GameFontDisableSmall")
    add.hint:SetPoint("TOPLEFT", add.name, "BOTTOMLEFT", 0, -4)

    local ratingLabel = W.Label(add, L["Rating"], "RepKeeperFontNormalSmall")
    ratingLabel:SetPoint("TOPLEFT", x, -92)
    add.rating = W.Segmented(add, UI.RatingChoices(), function()
        return add.level
    end, function(v)
        add.level = v
    end)
    add.rating:SetPoint("TOPLEFT", x + labelW, -86)
    add.rating:SetWidth(282)

    local noteLabel = W.Label(add, L["Note"], "RepKeeperFontNormalSmall")
    noteLabel:SetPoint("TOPLEFT", x, -134)
    add.note = W.EditBox(add, 270, {
        maxLetters = 200,
        placeholder = L["Optional: why you added them"],
        onEnter = function()
            add:Submit()
            return true
        end,
        onTab = function()
            add.name:SetFocus()
        end,
    })
    add.note:SetPoint("TOPLEFT", x + labelW + 6, -130)

    add.status = W.Text(add, "", 352, "GameFontHighlightSmall")
    add.status:SetPoint("TOPLEFT", x, -166)

    add.ok = W.Button(add, L["Add"], 130, function()
        add:Submit()
    end)
    add.ok:SetPoint("BOTTOMRIGHT", add, "BOTTOM", -4, 20)
    add.cancel = W.Button(add, L["Cancel"], 130, function()
        add:Hide()
    end)
    add.cancel:SetPoint("BOTTOMLEFT", add, "BOTTOM", 4, 20)

    function add:Submit()
        local text = U.Trim(self.name:GetText())
        if text == "" then
            setStatus(self.status, L["Type the player's name first."], false)
            self.name:SetFocus()
            return
        end
        local rec, created = ns.Database:GetOrCreatePlayer(ns.PlayerUtils:TypedName(text))
        if not rec then
            setStatus(self.status, L["That name doesn't work. Try Name-Realm."], false)
            self.name:SetFocus()
            return
        end
        -- An existing player only changes rating when you picked one on purpose.
        if created or self.level ~= C.REP.NEUTRAL then
            rec.reputation = self.level
        end
        if created then
            rec.source = "manual"
        end
        local note = U.Trim(self.note:GetText())
        if note ~= "" then
            if not rec.notes or rec.notes == "" then
                rec.notes = note
            else
                ns.Timeline:Append(rec, "manual", note)
            end
        end
        ns.Database:Touch(rec)
        ns.Addon:Printf(created and L["Player added: %s"] or L["Updated %s"], ns.PlayerUtils:DisplayNamePlain(rec))
        self:Hide()
        if UI.ShowPlayer then
            UI.ShowPlayer(rec.normalizedKey)
        end
    end
end

-- prefill: a name to start with (optional).
function UI.AddPlayerDialog(prefill)
    if not add then
        buildAdd()
    end
    add.level = C.REP.NEUTRAL
    add.name:SetText(prefill or "")
    add.note:SetText("")
    add.hint:SetText(ns.PlayerUtils:TwoPartNames() and L["First and last name, like Frost Paladin."]
        or L["Add -Realm for players from another realm."])
    setStatus(add.status, nil)
    add.rating:Refresh()
    add:Show()
    add:Raise()
    add.name:SetFocus()
    return add
end

---------------------------------------------------------------------------
-- A new tag of your own
---------------------------------------------------------------------------
local newTag

local TIER_ATLAS = { negative = "UI-LFG-DeclineMark", neutral = "UI-LFG-PendingMark", positive = "UI-LFG-ReadyMark" }

local function buildNewTag()
    newTag = dialog("RepKeeperNewTag", L["New tag"], 380, 218)
    local x, labelW = 24, 60
    local nameLabel = W.Label(newTag, L["Name"], "RepKeeperFontNormalSmall")
    nameLabel:SetPoint("TOPLEFT", x, -44)
    newTag.name = W.EditBox(newTag, 260, {
        maxLetters = 24,
        placeholder = L["Like Carried us, or Late to raids"],
        onEnter = function()
            newTag:Submit()
            return true
        end,
    })
    newTag.name:SetPoint("TOPLEFT", x + labelW + 6, -40)

    local kindLabel = W.Label(newTag, L["Kind"], "RepKeeperFontNormalSmall")
    kindLabel:SetPoint("TOPLEFT", x, -86)
    local items = {}
    for i, tier in ipairs(UI.TIER_ORDER) do
        items[i] = { value = tier, text = UI.TIER_NAME[tier], atlas = TIER_ATLAS[tier], color = UI.TIER_COLOR[tier] }
    end
    newTag.kind = W.Segmented(newTag, items, function()
        return newTag.tier
    end, function(v)
        newTag.tier = v
    end)
    newTag.kind:SetPoint("TOPLEFT", x + labelW, -80)
    newTag.kind:SetWidth(272)

    newTag.status = W.Text(newTag, "", 332, "GameFontHighlightSmall")
    newTag.status:SetPoint("TOPLEFT", x, -118)

    newTag.ok = W.Button(newTag, L["Create"], 130, function()
        newTag:Submit()
    end)
    newTag.ok:SetPoint("BOTTOMRIGHT", newTag, "BOTTOM", -4, 20)
    local cancel = W.Button(newTag, L["Cancel"], 130, function()
        newTag:Hide()
    end)
    cancel:SetPoint("BOTTOMLEFT", newTag, "BOTTOM", 4, 20)

    function newTag:Submit()
        local name = U.Trim(self.name:GetText())
        if name == "" then
            setStatus(self.status, L["Give the tag a name first."], false)
            self.name:SetFocus()
            return
        end
        local tagID = name:lower():gsub("%s+", "_"):gsub("[^%w_]", "")
        if tagID == "" then
            setStatus(self.status, L["Use letters or numbers in the name."], false)
            return
        end
        if C.BUILTIN_TAGS[tagID] or ns.db.global.customTags[tagID] then
            setStatus(self.status, L["There is already a tag with that name."], false)
            return
        end
        ns.Database:AddCustomTag(tagID, name, self.tier, nil)
        local rec = self.rec
        if rec then
            rec.tags = rec.tags or {}
            rec.tags[tagID] = true
            ns.Database:Touch(rec)
        end
        self:Hide()
        UI.Refresh()
    end
end

-- rec: the player who gets the new tag right away (optional).
function UI.NewTagDialog(rec)
    if not newTag then
        buildNewTag()
    end
    newTag.rec = rec
    newTag.tier = rec and UI.TIER_OF_RATING[rec.reputation or 0] or "neutral"
    newTag.name:SetText("")
    setStatus(newTag.status, L["Your tags can be used on every player."])
    newTag.kind:Refresh()
    newTag:Show()
    newTag:Raise()
    newTag.name:SetFocus()
    return newTag
end

---------------------------------------------------------------------------
-- Export and import
---------------------------------------------------------------------------
local export, import

local function buildExport()
    export = dialog("RepKeeperExport", L["Export"], 540, 420)
    export.blacklistOnly = false
    local intro = W.Text(export, L["Copy this text with Ctrl+C and send it to a friend. They paste it into Import on their RepKeeper."], 490)
    intro:SetPoint("TOPLEFT", 24, -38)

    local only = W.Check(export, L["Blacklist only"], L["Only the players you blacklisted."], function()
        return export.blacklistOnly
    end, function(on)
        export.blacklistOnly = on
        export:Generate()
    end)
    only:SetPoint("TOPLEFT", 20, -66)
    local anon = W.Check(export, L["Leave out notes and history"], L["Leaves out notes, history and Battle.net names. Ratings and tags are still in."], function()
        return ns.S.anonymizeExports
    end, function(on)
        ns.S.anonymizeExports = on
        export:Generate()
    end)
    anon:SetPoint("TOPLEFT", 200, -66)
    export.checks = { only, anon }

    export.box = W.TextArea(export, { readOnly = true, font = "GameFontHighlightSmall" })
    export.box:SetPoint("TOPLEFT", 20, -96)
    export.box:SetPoint("BOTTOMRIGHT", -20, 54)

    export.status = W.Label(export, "", "GameFontHighlightSmall")
    export.status:SetPoint("BOTTOMLEFT", 24, 26)

    local close = W.Button(export, L["Close"], 110, function()
        export:Hide()
    end)
    close:SetPoint("BOTTOMRIGHT", -20, 20)
    local select = W.Button(export, L["Select all"], 110, function()
        export.box:SelectAll()
    end)
    select:SetPoint("RIGHT", close, "LEFT", -6, 0)

    function export:Generate()
        local IE = ns.ImportExport
        local payload = IE:BuildExportPayload({ blacklistOnly = self.blacklistOnly })
        local str = IE:Encode(payload)
        self.box:SetText(str)
        self.status:SetText(format(L["%s players, %s characters"], U.Number(#payload.players), U.Number(#str)))
        for _, cb in ipairs(self.checks) do
            cb:Refresh()
        end
        self.box:SelectAll()
    end
end

function UI.ShowExport()
    if not export then
        buildExport()
    end
    export:Show()
    export:Raise()
    export:Generate()
    return export
end

local function buildImport()
    import = dialog("RepKeeperImport", L["Import"], 540, 420)
    local intro = W.Text(import, L["Paste a RepKeeper export below with Ctrl+V and press Import. Players you already have keep their rating, unless the import is stricter. Tags and history are added."], 490)
    intro:SetPoint("TOPLEFT", 24, -38)

    import.box = W.TextArea(import, { font = "GameFontHighlightSmall", placeholder = L["Paste the export here."] })
    import.box:SetPoint("TOPLEFT", 20, -84)
    import.box:SetPoint("BOTTOMRIGHT", -20, 54)

    import.status = W.Text(import, "", 300, "GameFontHighlightSmall")
    import.status:SetPoint("BOTTOMLEFT", 24, 24)

    local close = W.Button(import, L["Close"], 110, function()
        import:Hide()
    end)
    close:SetPoint("BOTTOMRIGHT", -20, 20)
    local go = W.Button(import, L["Import"], 110, function()
        import:Run()
    end)
    go:SetPoint("RIGHT", close, "LEFT", -6, 0)

    function import:Run()
        local IE = ns.ImportExport
        local payload, err = IE:Decode(self.box:GetText())
        if not payload then
            setStatus(self.status, L["That text isn't a RepKeeper export. Copy the whole text and try again."], false)
            return
        end
        local ok, vErr = IE:Validate(payload)
        if not ok then
            setStatus(self.status, format(L["Import failed: %s"], tostring(vErr or err or "?")), false)
            return
        end
        local stats = IE:Apply(payload)
        setStatus(self.status, format(L["Imported: %d new, %d updated, %d skipped."], stats.added, stats.updated, stats.skipped), true)
        UI.Refresh()
    end
end

function UI.ShowImport()
    if not import then
        buildImport()
    end
    import.box:SetText("")
    setStatus(import.status, nil)
    import:Show()
    import:Raise()
    import.box:SetFocus()
    return import
end
