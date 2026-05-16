-- UI/PlayerEditor.lua
-- Native (non-AceGUI) editor dialog. AceGUI's auto-layout overflows when we
-- have many tags + notes + timeline + buttons, so we hand-roll the layout
-- with explicit anchors. The frame is sized to fit everything; only the
-- timeline list has its own scroll (so it can grow without pushing the
-- rest of the UI around).
--
-- Style: opaque dark backdrop matching the rest of the addon's chrome.

local addonName, ns = ...
local C = ns.Constants

local PlayerEditor = {}
ns.PlayerEditor = PlayerEditor

local frame
local current = { rec = nil }

-- NOTE: Custom tag removal previously used StaticPopupDialogs for confirmation.
-- That registration tainted the secure StaticPopup subsystem in Midnight 12.0,
-- breaking the gear upgrade UI. Removed in favor of a direct delete with no
-- confirmation. The remove button is small and easy to miss-click, but the
-- worst case is "I have to re-add my tag" which is cheap. Will replace with
-- a native confirmation frame later.

function PlayerEditor:Initialize() end

-- ==========================================================================
-- Public API
-- ==========================================================================

function PlayerEditor:Open(rec, opts)
    if not rec then return end
    opts = opts or {}
    self:Build()

    current.rec = rec
    current.opts = opts
    current.mode = "edit"
    self:Populate(rec, opts)

    frame:Show()

    if opts.focus == "note" and frame.notesEdit then
        frame.notesEdit:SetFocus()
    end
end

function PlayerEditor:OpenNew()
    self:OpenAddPlayerDialog()
end

function PlayerEditor:Close()
    if frame then frame:Hide() end
end

-- ==========================================================================
-- Frame construction (built once, reused)
-- ==========================================================================

local function applyDarkBackdrop(f, intensity)
    intensity = intensity or 0.92
    if f.SetBackdrop then
        f:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = false, tileSize = 0, edgeSize = 14,
            insets   = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        f:SetBackdropColor(0.06, 0.06, 0.07, intensity)
        f:SetBackdropBorderColor(0.5, 0.4, 0.2, 1)
    end
end

local function makeButton(parent, label, width)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width or 100, 24)
    b:SetText(label)
    return b
end

local function makeCheckbox(parent, label)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(22, 22)
    cb.text = cb.text or _G[cb:GetName() and (cb:GetName().."Text") or ""] or cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cb.text:ClearAllPoints()
    cb.text:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    cb.text:SetText(label)
    cb.text:SetTextColor(1, 1, 1)
    return cb
end

local function makeEditBox(parent, width, height)
    local eb = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    eb:SetSize(width or 200, height or 22)
    eb:SetAutoFocus(false)
    eb:SetFontObject("ChatFontNormal")
    eb:SetTextInsets(6, 6, 2, 2)
    if eb.SetBackdrop then
        eb:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = false, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        eb:SetBackdropColor(0, 0, 0, 0.85)
        eb:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    end
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    return eb
end

function PlayerEditor:Build()
    if frame then return frame end

    frame = CreateFrame("Frame", "RepKeeperPlayerEditor", UIParent, "BackdropTemplate")
    frame:SetSize(720, 1000)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)

    -- ESC-to-close support
    tinsert(UISpecialFrames, "RepKeeperPlayerEditor")
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetScript("OnHide", function()
        current.rec = nil
        current.mode = nil
    end)
    frame:Hide()
    applyDarkBackdrop(frame, 0.96)

    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -14)
    title:SetText("|cffd0a070" .. ns.L["Edit Player"] .. "|r")
    frame.title = title

    -- Subtitle (player name-realm)
    local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    subtitle:SetPoint("TOP", title, "BOTTOM", 0, -2)
    frame.subtitle = subtitle

    -- Close X
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    -- Content frame (no outer scroll - everything fits, timeline has its own scroll below)
    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", 16, -56)
    content:SetPoint("BOTTOMRIGHT", -16, 56)
    frame.content = content

    -- Bottom action bar (outside the scroll, always visible)
    local closeBottom = makeButton(frame, ns.L["Close"], 100)
    closeBottom:SetPoint("BOTTOMRIGHT", -16, 16)
    closeBottom:SetScript("OnClick", function() frame:Hide() end)
    frame.closeBottom = closeBottom

    return frame
end

-- ==========================================================================
-- Section builders (operate on frame.content)
-- ==========================================================================

local function clearChildren(parent)
    -- Hide and unanchor all children. We don't release frames; we re-use.
    for _, child in ipairs({ parent:GetChildren() }) do
        child:Hide()
        child:ClearAllPoints()
        child:SetParent(nil)  -- detach so we don't leak across opens
    end
    for _, region in ipairs({ parent:GetRegions() }) do
        if region.Hide then region:Hide() end
        region:ClearAllPoints()
    end
end

-- ==========================================================================
-- Populate for editing an existing record
-- ==========================================================================

function PlayerEditor:Populate(rec, opts)
    frame.title:SetText("|cffd0a070" .. ns.L["Edit Player"] .. "|r")
    local subtitle = ns.PlayerUtils:DisplayName(rec, { includeRealm = true, bypassStreamer = true, colorize = true })
    if rec.firstSeenLocation and rec.firstSeenLocation ~= "" and rec.firstSeenLocation ~= "unknown" then
        local loc = rec.firstSeenLocation:gsub("\226\128\148", "-")
        subtitle = subtitle .. "  |cff888888- first seen in " .. loc .. "|r"
    end
    frame.subtitle:SetText(subtitle)

    local content = frame.content
    clearChildren(content)

    local y = 0  -- running y offset (negative grows downward)
    local PADDING = 12
    local SECTION_GAP = 16

    -- ---------- Reputation picker ----------
    local repHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    repHeader:SetPoint("TOPLEFT", 0, y)
    repHeader:SetText("|cffd0a070" .. ns.L["Reputation"] .. "|r")

    local repSubtitle = content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    repSubtitle:SetPoint("LEFT", repHeader, "RIGHT", 8, -1)
    repSubtitle:SetText("|cff888888Click a level to set this player's reputation|r")
    y = y - 26

    -- Row of 5 buttons: Blacklist, Negative, Neutral, Positive, Favorite.
    -- The selected one shows a brightened backdrop; others are dim until
    -- hovered. No slider, no dropdown — one click and you're done.
    local BTN_W = 200
    local BTN_GAP = 12
    local repButtons = {}
    local REP_ORDER = { C.REP.BLACKLIST, C.REP.NEUTRAL, C.REP.POSITIVE }

    local function paintRepButtons()
        for level, btn in pairs(repButtons) do
            local r, g, b = ns.PlayerUtils:RepColor(level)
            local isSelected = (rec.reputation or 0) == level
            if isSelected then
                btn.bg:SetColorTexture(r, g, b, 0.85)
                btn.text:SetTextColor(1, 1, 1)
                btn.border:SetBackdropBorderColor(1, 0.95, 0.6, 1)
            else
                btn.bg:SetColorTexture(r * 0.4, g * 0.4, b * 0.4, 0.45)
                btn.text:SetTextColor(0.85, 0.85, 0.85)
                btn.border:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
            end
        end
    end

    for i, level in ipairs(REP_ORDER) do
        local btn = CreateFrame("Button", nil, content, "BackdropTemplate")
        btn:SetSize(BTN_W, 32)
        btn:SetPoint("TOPLEFT", (i - 1) * (BTN_W + BTN_GAP), y)

        local bg = btn:CreateTexture(nil, "BACKGROUND")
        bg:SetPoint("TOPLEFT", 2, -2)
        bg:SetPoint("BOTTOMRIGHT", -2, 2)
        btn.bg = bg

        if btn.SetBackdrop then
            btn:SetBackdrop({
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                edgeSize = 10,
                insets = { left = 3, right = 3, top = 3, bottom = 3 },
            })
        end
        btn.border = btn  -- the button itself holds the border

        local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("CENTER")
        text:SetText(C.REP_NAMES[level])
        btn.text = text

        btn:SetScript("OnEnter", function(self)
            if (rec.reputation or 0) ~= level then
                self.border:SetBackdropBorderColor(0.8, 0.7, 0.4, 1)
            end
        end)
        btn:SetScript("OnLeave", function() paintRepButtons() end)
        btn:SetScript("OnClick", function()
            ns.Reputation:Set(rec, level)
            if ns.MainFrame then ns.MainFrame:Refresh() end
            -- Repopulate so the tag list below reflects the new tier filter.
            PlayerEditor:Populate(rec, opts)
        end)

        repButtons[level] = btn
    end
    paintRepButtons()

    y = y - 40
    y = y - SECTION_GAP
    -- ---------- Tags section ----------
    -- The tag list is driven by the reputation chosen above:
    --   Blacklist -> negative tags shown for adding
    --   Neutral   -> neutral tags shown for adding
    --   Positive  -> positive tags shown for adding
    -- BUT: any tags the player already has checked are always visible, even
    -- if they belong to a different tier (so we don't hide "Good Tank" just
    -- because you changed someone to Blacklist).
    local tagsHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    tagsHeader:SetPoint("TOPLEFT", 0, y)
    tagsHeader:SetText("|cffd0a070" .. ns.L["Tags"] .. "|r")

    local repToTier = {
        [C.REP.BLACKLIST] = "negative",
        [C.REP.NEUTRAL]   = "neutral",
        [C.REP.POSITIVE]  = "positive",
    }
    local activeTier = repToTier[rec.reputation or 0] or "neutral"
    local activeLabel = ({ negative = "Blacklist", neutral = "Neutral", positive = "Positive" })[activeTier]

    local tagsSubtitle = content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    tagsSubtitle:SetPoint("LEFT", tagsHeader, "RIGHT", 8, -1)
    tagsSubtitle:SetText("|cff888888Showing |r|cffd0a070" .. activeLabel ..
        "|r|cff888888 tags. Change reputation above for other categories.|r")
    y = y - 28

    -- Bucket tags by tier. A tag goes into "shown" if either (a) it's checked
    -- on this player, regardless of tier, OR (b) it belongs to the active tier
    -- (so it's available to add). This ensures cross-tier tags don't disappear.
    local checked = rec.tags or {}
    local buckets = { negative = {}, neutral = {}, positive = {} }

    local function addToBucket(tagID, def, custom)
        local tier = def.tier or (def.negative and "negative" or "positive")
        local isChecked = checked[tagID] and true or false
        if isChecked or tier == activeTier then
            table.insert(buckets[tier], {
                id = tagID, def = def, custom = custom, tier = tier, checked = isChecked,
            })
        end
    end
    for tagID, def in pairs(C.BUILTIN_TAGS) do addToBucket(tagID, def, false) end
    for tagID, def in pairs(ns.db.global.customTags or {}) do addToBucket(tagID, def, true) end

    for _, list in pairs(buckets) do
        table.sort(list, function(a, b) return a.def.name < b.def.name end)
    end

    -- Render order: active tier first, then any cross-tier buckets with content
    local renderOrder = { activeTier }
    for _, t in ipairs({ "negative", "neutral", "positive" }) do
        if t ~= activeTier then renderOrder[#renderOrder + 1] = t end
    end

    local TIER_HEADER = {
        negative = "|cffff8888Negative tags|r",
        neutral  = "|cffcccccc Neutral tags|r",
        positive = "|cff88ff88Positive tags|r",
    }
    local COL_WIDTH = 320
    local ROW_HEIGHT = 26

    local function renderTagButton(t, col, row, y0)
        local cb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
        cb:SetSize(22, 22)
        cb:SetPoint("TOPLEFT", col * COL_WIDTH, y0 - row * ROW_HEIGHT)
        cb:SetChecked(t.checked)

        local fs = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetPoint("LEFT", cb, "RIGHT", 2, 0)
        local color
        if t.tier == "negative" then color = "ffff8888"
        elseif t.tier == "positive" then color = "ff88ff88"
        else color = "ffcccccc" end
        local prefix = t.custom and "|cffd0a070[C]|r " or ""
        fs:SetText(prefix .. "|c" .. color .. t.def.name .. "|r")

        cb:SetScript("OnClick", function(self)
            rec.tags = rec.tags or {}
            rec.tags[t.id] = self:GetChecked() and true or nil
            ns.Database:Touch(rec)
            if ns.MainFrame then ns.MainFrame:Refresh() end
        end)

        if t.custom then
            local del = CreateFrame("Button", nil, content)
            del:SetSize(16, 16)
            del:SetPoint("TOPLEFT", col * COL_WIDTH + COL_WIDTH - 24, y0 - row * ROW_HEIGHT - 4)
            del:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
            del:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
            del:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
            del:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText("Remove custom tag '" .. t.def.name .. "'")
                GameTooltip:AddLine("|cffff8888Shift-click to delete|r", 1, 1, 1, true)
                GameTooltip:AddLine("|cff888888Will untag this from all players|r", 1, 1, 1, true)
                GameTooltip:Show()
            end)
            del:SetScript("OnLeave", function() GameTooltip:Hide() end)
            del:SetScript("OnClick", function()
                if not IsShiftKeyDown() then
                    ns.Addon:Print("|cffff8888Shift-click|r the X to delete custom tag '" .. t.def.name .. "'.")
                    return
                end
                ns.Database:RemoveCustomTag(t.id)
                PlayerEditor:Populate(rec, opts)
                if ns.MainFrame then ns.MainFrame:Refresh() end
            end)
        end
    end

    local renderedAny = false
    for _, tier in ipairs(renderOrder) do
        local list = buckets[tier]
        if #list > 0 then
            local isActive = (tier == activeTier)
            local hdr = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            hdr:SetPoint("TOPLEFT", 0, y)
            if isActive then
                hdr:SetText(TIER_HEADER[tier])
            else
                hdr:SetText(TIER_HEADER[tier] .. "  |cff666666(checked tags from this category)|r")
            end
            y = y - 20

            for i, t in ipairs(list) do
                local col = ((i - 1) % 2)
                local row = math.floor((i - 1) / 2)
                renderTagButton(t, col, row, y)
            end
            local rows = math.ceil(#list / 2)
            y = y - rows * ROW_HEIGHT - 8
            renderedAny = true
        end
    end

    if not renderedAny then
        local empty = content:CreateFontString(nil, "OVERLAY", "GameFontDisable")
        empty:SetPoint("TOPLEFT", 4, y)
        empty:SetText("|cff666666No tags here. Use 'Add Custom Tag' to create one.|r")
        y = y - 24
    end

    y = y - 4
    local addCustomBtn = makeButton(content, "Add Custom Tag...", 160)
    addCustomBtn:SetPoint("TOPLEFT", 0, y)
    addCustomBtn:SetScript("OnClick", function()
        PlayerEditor:OpenCustomTagDialog(rec, opts)
    end)
    y = y - 32

    y = y - SECTION_GAP

    -- ---------- Notes section ----------
    local sepNotes = content:CreateTexture(nil, "ARTWORK")
    sepNotes:SetPoint("TOPLEFT", 0, y)
    sepNotes:SetSize(660, 1)
    sepNotes:SetColorTexture(0.4, 0.32, 0.18, 0.6)
    y = y - 12

    local notesHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    notesHeader:SetPoint("TOPLEFT", 0, y)
    notesHeader:SetText("|cffd0a070" .. ns.L["Notes"] .. "|r")

    local notesSubtitle = content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    notesSubtitle:SetPoint("LEFT", notesHeader, "RIGHT", 8, -1)
    notesSubtitle:SetText("|cff888888Free-form summary shown in tooltips|r")
    y = y - 26

    -- Notes editable area with explicit Edit/Save buttons.
    -- Default state: read-only (cannot accidentally type). Click Edit to
    -- unlock; Save commits and re-locks. Cancel reverts to original text.
    local notesContainer = CreateFrame("Frame", nil, content, "BackdropTemplate")
    notesContainer:SetPoint("TOPLEFT", 0, y)
    notesContainer:SetSize(640, 90)
    if notesContainer.SetBackdrop then
        notesContainer:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = false, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        notesContainer:SetBackdropColor(0, 0, 0, 0.85)
        notesContainer:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    end

    local notesEdit = CreateFrame("EditBox", nil, notesContainer)
    notesEdit:SetPoint("TOPLEFT", 8, -6)
    notesEdit:SetPoint("BOTTOMRIGHT", -8, 6)
    notesEdit:SetMultiLine(true)
    notesEdit:SetFontObject("ChatFontNormal")
    notesEdit:SetAutoFocus(false)
    notesEdit:SetText(rec.notes or "")
    notesEdit:SetTextInsets(2, 2, 2, 2)
    notesEdit:SetMaxLetters(2000)
    notesEdit:SetEnabled(false)  -- locked by default
    notesEdit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    frame.notesEdit = notesEdit

    -- Edit / Save / Cancel buttons positioned to the right of the notes box
    y = y - 100

    local originalText = rec.notes or ""
    local editBtn = makeButton(content, "Edit", 80)
    editBtn:SetPoint("TOPLEFT", 0, y)
    local saveBtn = makeButton(content, "Save", 80)
    saveBtn:SetPoint("LEFT", editBtn, "RIGHT", 8, 0)
    saveBtn:Hide()
    local cancelBtn = makeButton(content, "Cancel", 80)
    cancelBtn:SetPoint("LEFT", saveBtn, "RIGHT", 8, 0)
    cancelBtn:Hide()

    local notesStatus = content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    notesStatus:SetPoint("LEFT", cancelBtn, "RIGHT", 12, 0)
    notesStatus:SetText("|cff888888Click Edit to modify notes|r")

    editBtn:SetScript("OnClick", function()
        originalText = notesEdit:GetText() or ""
        notesEdit:SetEnabled(true)
        notesEdit:SetFocus()
        notesContainer:SetBackdropBorderColor(0.85, 0.7, 0.35, 1)
        editBtn:Hide()
        saveBtn:Show()
        cancelBtn:Show()
        notesStatus:SetText("|cffd0a070Editing - click Save to commit|r")
    end)
    saveBtn:SetScript("OnClick", function()
        local text = notesEdit:GetText() or ""
        if rec.notes ~= text then
            rec.notes = text
            ns.Database:Touch(rec)
            if ns.MainFrame then ns.MainFrame:Refresh() end
        end
        notesEdit:SetEnabled(false)
        notesEdit:ClearFocus()
        notesContainer:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        editBtn:Show()
        saveBtn:Hide()
        cancelBtn:Hide()
        notesStatus:SetText("|cff77dd77Saved|r")
        C_Timer.After(2, function()
            if notesStatus then notesStatus:SetText("|cff888888Click Edit to modify notes|r") end
        end)
    end)
    cancelBtn:SetScript("OnClick", function()
        notesEdit:SetText(originalText)
        notesEdit:SetEnabled(false)
        notesEdit:ClearFocus()
        notesContainer:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        editBtn:Show()
        saveBtn:Hide()
        cancelBtn:Hide()
        notesStatus:SetText("|cff888888Click Edit to modify notes|r")
    end)

    y = y - 32
    y = y - SECTION_GAP

    -- ---------- Timeline section (add entry + display, tightly grouped) ----------
    local tlSep = content:CreateTexture(nil, "ARTWORK")
    tlSep:SetPoint("TOPLEFT", 0, y)
    tlSep:SetSize(660, 1)
    tlSep:SetColorTexture(0.4, 0.32, 0.18, 0.6)
    y = y - 12

    local tlCount = (rec.timeline and #rec.timeline) or 0
    local tlHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    tlHeader:SetPoint("TOPLEFT", 0, y)
    tlHeader:SetText("|cffd0a070" .. ns.L["Timeline"] .. " (" .. tlCount .. ")|r")

    local tlSubtitle = content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    tlSubtitle:SetPoint("LEFT", tlHeader, "RIGHT", 8, -1)
    tlSubtitle:SetText("|cff888888Newest entries first. Auto-detected events shown in color.|r")
    y = y - 22

    -- Smaller "Add entry" input row, sitting directly above the timeline list
    -- so they read as one section.
    local entryEdit = makeEditBox(content, 560, 22)
    entryEdit:SetPoint("TOPLEFT", 0, y)
    entryEdit:SetScript("OnEnterPressed", function(self)
        local text = self:GetText():trim()
        if text == "" then return end
        ns.Timeline:Append(rec, "manual", text)
        self:SetText("")
        if ns.MainFrame then ns.MainFrame:Refresh() end
        PlayerEditor:Populate(rec, opts)
    end)
    -- Placeholder text inside the field
    local entryPlaceholder = entryEdit:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    entryPlaceholder:SetPoint("LEFT", 8, 0)
    entryPlaceholder:SetText("Add a new timeline entry...")
    entryEdit:HookScript("OnTextChanged", function(self)
        entryPlaceholder:SetShown((self:GetText() or "") == "")
    end)
    entryEdit:HookScript("OnEditFocusGained", function() entryPlaceholder:Hide() end)
    entryEdit:HookScript("OnEditFocusLost", function(self)
        entryPlaceholder:SetShown((self:GetText() or "") == "")
    end)

    local entryBtn = makeButton(content, "Add Entry", 80)
    entryBtn:SetPoint("LEFT", entryEdit, "RIGHT", 8, 0)
    entryBtn:SetScript("OnClick", function() entryEdit:GetScript("OnEnterPressed")(entryEdit) end)
    y = y - 26

    -- Timeline list, fixed height scroll, immediately below the input
    local tlContainer = CreateFrame("Frame", nil, content, "BackdropTemplate")
    tlContainer:SetPoint("TOPLEFT", 0, y)
    tlContainer:SetSize(660, 140)
    if tlContainer.SetBackdrop then
        tlContainer:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = false, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        tlContainer:SetBackdropColor(0, 0, 0, 0.85)
        tlContainer:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    end

    local tlScroll = CreateFrame("ScrollFrame", "RepKeeperEditorTimelineScroll", tlContainer, "UIPanelScrollFrameTemplate")
    tlScroll:SetPoint("TOPLEFT", 6, -6)
    tlScroll:SetPoint("BOTTOMRIGHT", -28, 6)

    local tlChild = CreateFrame("Frame", nil, tlScroll)
    tlChild:SetSize(620, 1)
    tlScroll:SetScrollChild(tlChild)

    if tlCount == 0 then
        local empty = tlChild:CreateFontString(nil, "OVERLAY", "GameFontDisable")
        empty:SetPoint("TOPLEFT", 4, -4)
        empty:SetText("|cff666666No timeline entries yet. Add one above or wait for auto-detection.|r")
        tlChild:SetHeight(20)
    else
        local cy = 0
        local LINE_PAD = 4
        -- Default display style comes from settings; clicking an entry
        -- toggles ONLY that entry's display, so the user can spot-check
        -- absolute timestamps without changing the setting globally.
        local defaultRelative = (ns.db.global.settings.timelineDateFormat or "relative") == "relative"

        local function buildText(entry, relative)
            local color = "ffffff"
            if entry.type == "detection" then color = "ff8888"
            elseif entry.type == "system" then color = "8888ff"
            elseif entry.type == "encounter" then color = "88ccff" end
            local stamp
            if relative then
                stamp = ns.PlayerUtils:RelativeTime(entry.ts or 0)
            else
                stamp = date("%Y-%m-%d %H:%M", entry.ts or 0)
            end
            return string.format("|cff%s[%s]|r %s",
                color, stamp, entry.text or "")
        end

        for i = #rec.timeline, 1, -1 do
            local entry = rec.timeline[i]
            -- Wrap the FontString in a Button so it's clickable for toggling.
            local btn = CreateFrame("Button", nil, tlChild)
            btn:SetPoint("TOPLEFT", 4, cy)
            btn:SetSize(610, 1)  -- height adjusted after text set
            btn._relative = defaultRelative

            local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            fs:SetPoint("TOPLEFT", 0, 0)
            fs:SetWidth(610)
            fs:SetJustifyH("LEFT")
            fs:SetText(buildText(entry, btn._relative))
            local h = fs:GetStringHeight()
            btn:SetHeight(h)

            btn:SetScript("OnClick", function(self)
                self._relative = not self._relative
                fs:SetText(buildText(entry, self._relative))
            end)
            btn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText("Click to toggle relative/absolute time")
                GameTooltip:Show()
            end)
            btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

            cy = cy - (h + LINE_PAD)
        end
        tlChild:SetHeight(math.max(1, -cy + 4))
    end

    y = y - 144

    -- Final padding
    y = y - 12
    content:SetHeight(math.max(1, -y))
end

-- ==========================================================================
-- Custom tag creation dialog (small popup window)
-- ==========================================================================

local customTagFrame

function PlayerEditor:OpenCustomTagDialog(rec, opts)
    if not customTagFrame then
        customTagFrame = CreateFrame("Frame", "RepKeeperCustomTagDialog", UIParent, "BackdropTemplate")
        customTagFrame:SetSize(380, 220)
        customTagFrame:SetPoint("CENTER")
        customTagFrame:SetFrameStrata("FULLSCREEN_DIALOG")
        customTagFrame:SetMovable(true)
        customTagFrame:EnableMouse(true)
        customTagFrame:SetClampedToScreen(true)
        customTagFrame:RegisterForDrag("LeftButton")
        customTagFrame:SetScript("OnDragStart", customTagFrame.StartMoving)
        customTagFrame:SetScript("OnDragStop", customTagFrame.StopMovingOrSizing)
        applyDarkBackdrop(customTagFrame, 0.96)
        customTagFrame:Hide()
        tinsert(UISpecialFrames, "RepKeeperCustomTagDialog")

        local title = customTagFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", 0, -12)
        title:SetText("|cffd0a070Add Custom Tag|r")

        local closeX = CreateFrame("Button", nil, customTagFrame, "UIPanelCloseButton")
        closeX:SetPoint("TOPRIGHT", -4, -4)
        closeX:SetScript("OnClick", function() customTagFrame:Hide() end)

        local nameLabel = customTagFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameLabel:SetPoint("TOPLEFT", 20, -42)
        nameLabel:SetText("Tag name")

        local nameBox = makeEditBox(customTagFrame, 340, 24)
        nameBox:SetPoint("TOPLEFT", 20, -60)
        nameBox:SetAutoFocus(false)
        customTagFrame.nameBox = nameBox

        local tierLabel = customTagFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        tierLabel:SetPoint("TOPLEFT", 20, -94)
        tierLabel:SetText("Category")

        -- Three small tier buttons
        local TIERS = { "negative", "neutral", "positive" }
        local TIER_NAMES = { negative = "Blacklist", neutral = "Neutral", positive = "Positive" }
        local TIER_COLORS = {
            negative = { r = 0.9, g = 0.25, b = 0.25 },
            neutral  = { r = 0.7, g = 0.7, b = 0.7 },
            positive = { r = 0.3, g = 0.8, b = 0.3 },
        }
        customTagFrame._tierButtons = {}
        customTagFrame._pendingTier = "neutral"

        local function paintTiers()
            for tier, btn in pairs(customTagFrame._tierButtons) do
                local c = TIER_COLORS[tier]
                if customTagFrame._pendingTier == tier then
                    btn.bg:SetColorTexture(c.r, c.g, c.b, 0.75)
                    btn.text:SetTextColor(1, 1, 1)
                    btn:SetBackdropBorderColor(1, 0.95, 0.6, 1)
                else
                    btn.bg:SetColorTexture(c.r * 0.35, c.g * 0.35, c.b * 0.35, 0.5)
                    btn.text:SetTextColor(0.85, 0.85, 0.85)
                    btn:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
                end
            end
        end
        customTagFrame._paintTiers = paintTiers

        local TBTN_W = 108
        local TBTN_GAP = 8
        for i, tier in ipairs(TIERS) do
            local btn = CreateFrame("Button", nil, customTagFrame, "BackdropTemplate")
            btn:SetSize(TBTN_W, 28)
            btn:SetPoint("TOPLEFT", 20 + (i - 1) * (TBTN_W + TBTN_GAP), -112)
            local bg = btn:CreateTexture(nil, "BACKGROUND")
            bg:SetPoint("TOPLEFT", 2, -2)
            bg:SetPoint("BOTTOMRIGHT", -2, 2)
            btn.bg = bg
            if btn.SetBackdrop then
                btn:SetBackdrop({
                    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                    edgeSize = 10,
                    insets = { left = 3, right = 3, top = 3, bottom = 3 },
                })
            end
            local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            text:SetPoint("CENTER")
            text:SetText(TIER_NAMES[tier])
            btn.text = text
            btn:SetScript("OnClick", function()
                customTagFrame._pendingTier = tier
                paintTiers()
            end)
            customTagFrame._tierButtons[tier] = btn
        end

        -- Status line for validation feedback
        local status = customTagFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        status:SetPoint("BOTTOMLEFT", 20, 50)
        status:SetWidth(340)
        status:SetJustifyH("LEFT")
        customTagFrame.status = status

        -- Save / Cancel
        local saveBtn = makeButton(customTagFrame, "Save", 100)
        saveBtn:SetPoint("BOTTOMLEFT", 20, 18)
        local cancelBtn = makeButton(customTagFrame, "Cancel", 100)
        cancelBtn:SetPoint("BOTTOMRIGHT", -20, 18)
        customTagFrame.saveBtn = saveBtn
        customTagFrame.cancelBtn = cancelBtn

        cancelBtn:SetScript("OnClick", function() customTagFrame:Hide() end)
    end

    -- Reset state for this open
    customTagFrame.nameBox:SetText("")
    customTagFrame._pendingTier = "neutral"
    customTagFrame._paintTiers()
    customTagFrame.status:SetText("|cff888888Tags are shared across all players you track|r")

    customTagFrame.saveBtn:SetScript("OnClick", function()
        local name = customTagFrame.nameBox:GetText():trim()
        if name == "" then
            customTagFrame.status:SetText("|cffff8888Please enter a tag name|r")
            return
        end
        local tagID = name:lower():gsub("%s+", "_"):gsub("[^%w_]", "")
        if tagID == "" then
            customTagFrame.status:SetText("|cffff8888Tag name has no usable characters|r")
            return
        end
        if C.BUILTIN_TAGS[tagID] or ns.db.global.customTags[tagID] then
            customTagFrame.status:SetText("|cffff8888A tag with that name already exists|r")
            return
        end
        ns.Database:AddCustomTag(tagID, name, customTagFrame._pendingTier, nil)
        rec.tags = rec.tags or {}
        rec.tags[tagID] = true
        ns.Database:Touch(rec)
        customTagFrame:Hide()
        PlayerEditor:Populate(rec, opts)
        if ns.MainFrame then ns.MainFrame:Refresh() end
    end)

    customTagFrame:Show()
    customTagFrame:Raise()
    customTagFrame.nameBox:SetFocus()
end

-- ==========================================================================
-- Populate for creating a new player
-- ==========================================================================

function PlayerEditor:PopulateNew()
    -- Legacy entry point kept for compatibility; defers to the new dialog.
    self:OpenAddPlayerDialog()
end

-- ==========================================================================
-- Add Player dialog (small dedicated frame)
-- ==========================================================================
--
-- Separate from the main edit frame because the edit frame is 720x1000 and
-- has way more content. The add dialog needs only a name input, a reputation
-- picker, and save/cancel — ~480x260 is plenty.

local addPlayerFrame

function PlayerEditor:OpenAddPlayerDialog()
    if not addPlayerFrame then
        addPlayerFrame = CreateFrame("Frame", "RepKeeperAddPlayer", UIParent, "BackdropTemplate")
        addPlayerFrame:SetSize(480, 260)
        addPlayerFrame:SetPoint("CENTER")
        addPlayerFrame:SetFrameStrata("DIALOG")
        addPlayerFrame:SetMovable(true)
        addPlayerFrame:EnableMouse(true)
        addPlayerFrame:SetClampedToScreen(true)
        addPlayerFrame:RegisterForDrag("LeftButton")
        addPlayerFrame:SetScript("OnDragStart", addPlayerFrame.StartMoving)
        addPlayerFrame:SetScript("OnDragStop", addPlayerFrame.StopMovingOrSizing)
        applyDarkBackdrop(addPlayerFrame, 0.96)
        addPlayerFrame:Hide()
        tinsert(UISpecialFrames, "RepKeeperAddPlayer")

        local title = addPlayerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", 0, -12)
        title:SetText("|cffd0a070" .. ns.L["Add Player"] .. "|r")

        local closeX = CreateFrame("Button", nil, addPlayerFrame, "UIPanelCloseButton")
        closeX:SetPoint("TOPRIGHT", -4, -4)
        closeX:SetScript("OnClick", function() addPlayerFrame:Hide() end)

        -- Name-Realm input with placeholder text
        local nameLabel = addPlayerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameLabel:SetPoint("TOPLEFT", 20, -42)
        nameLabel:SetText("Name-Realm")

        local nameBox = makeEditBox(addPlayerFrame, 440, 26)
        nameBox:SetPoint("TOPLEFT", 20, -60)
        nameBox:SetAutoFocus(false)
        addPlayerFrame.nameBox = nameBox

        -- Placeholder inside the field
        local placeholder = nameBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        placeholder:SetPoint("LEFT", 8, 0)
        placeholder:SetText("PlayerName-RealmName")
        nameBox:HookScript("OnTextChanged", function(self)
            placeholder:SetShown((self:GetText() or "") == "")
        end)
        nameBox:HookScript("OnEditFocusGained", function() placeholder:Hide() end)
        nameBox:HookScript("OnEditFocusLost", function(self)
            placeholder:SetShown((self:GetText() or "") == "")
        end)

        -- Reputation picker — 3-button row, narrower to fit the dialog
        local repLabel = addPlayerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        repLabel:SetPoint("TOPLEFT", 20, -100)
        repLabel:SetText(ns.L["Reputation"])

        addPlayerFrame._repButtons = {}
        addPlayerFrame._pendingRep = C.REP.NEUTRAL

        local function paintRep()
            for level, btn in pairs(addPlayerFrame._repButtons) do
                local r, g, b = ns.PlayerUtils:RepColor(level)
                if addPlayerFrame._pendingRep == level then
                    btn.bg:SetColorTexture(r, g, b, 0.85)
                    btn.text:SetTextColor(1, 1, 1)
                    btn:SetBackdropBorderColor(1, 0.95, 0.6, 1)
                else
                    btn.bg:SetColorTexture(r * 0.4, g * 0.4, b * 0.4, 0.45)
                    btn.text:SetTextColor(0.85, 0.85, 0.85)
                    btn:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
                end
            end
        end
        addPlayerFrame._paintRep = paintRep

        local REP_ORDER = { C.REP.BLACKLIST, C.REP.NEUTRAL, C.REP.POSITIVE }
        local RBTN_W = 140
        local RBTN_GAP = 10
        for i, level in ipairs(REP_ORDER) do
            local btn = CreateFrame("Button", nil, addPlayerFrame, "BackdropTemplate")
            btn:SetSize(RBTN_W, 30)
            btn:SetPoint("TOPLEFT", 20 + (i - 1) * (RBTN_W + RBTN_GAP), -120)
            local bg = btn:CreateTexture(nil, "BACKGROUND")
            bg:SetPoint("TOPLEFT", 2, -2)
            bg:SetPoint("BOTTOMRIGHT", -2, 2)
            btn.bg = bg
            if btn.SetBackdrop then
                btn:SetBackdrop({
                    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                    edgeSize = 10,
                    insets = { left = 3, right = 3, top = 3, bottom = 3 },
                })
            end
            local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            text:SetPoint("CENTER")
            text:SetText(C.REP_NAMES[level])
            btn.text = text
            btn:SetScript("OnClick", function()
                addPlayerFrame._pendingRep = level
                paintRep()
            end)
            addPlayerFrame._repButtons[level] = btn
        end

        -- Status line for validation feedback
        local status = addPlayerFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        status:SetPoint("BOTTOMLEFT", 20, 48)
        status:SetWidth(440)
        status:SetJustifyH("LEFT")
        addPlayerFrame.status = status

        local saveBtn = makeButton(addPlayerFrame, ns.L["Save"], 120)
        saveBtn:SetPoint("BOTTOMLEFT", 20, 16)
        local cancelBtn = makeButton(addPlayerFrame, ns.L["Cancel"], 120)
        cancelBtn:SetPoint("BOTTOMRIGHT", -20, 16)
        addPlayerFrame.saveBtn = saveBtn

        cancelBtn:SetScript("OnClick", function() addPlayerFrame:Hide() end)
    end

    -- Reset state for each open
    addPlayerFrame.nameBox:SetText("")
    addPlayerFrame._pendingRep = C.REP.NEUTRAL
    addPlayerFrame._paintRep()
    addPlayerFrame.status:SetText("|cff888888Use the Name-Realm format. The realm is required for cross-realm players.|r")

    addPlayerFrame.saveBtn:SetScript("OnClick", function()
        local target = addPlayerFrame.nameBox:GetText():trim()
        if target == "" then
            addPlayerFrame.status:SetText("|cffff8888Please enter a player name|r")
            return
        end
        local rec = ns.Database:GetOrCreatePlayer(target)
        if not rec then
            addPlayerFrame.status:SetText("|cffff8888Couldn't parse that name - try Name-Realm|r")
            return
        end
        rec.reputation = addPlayerFrame._pendingRep
        ns.Database:Touch(rec)
        addPlayerFrame:Hide()
        if ns.MainFrame then ns.MainFrame:Refresh() end
        PlayerEditor:Open(rec)
    end)

    addPlayerFrame:Show()
    addPlayerFrame:Raise()
    addPlayerFrame.nameBox:SetFocus()
end
