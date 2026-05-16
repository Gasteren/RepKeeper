-- UI/MainFrame.lua
-- Native (non-AceGUI) main window for browsing the player list.
-- Native UI keeps memory low and matches the rest of the WoW frame style;
-- AceGUI is used elsewhere (import/export) where dialogs benefit from it.
--
-- Layout:
--   +--------------------------------------------------+
--   | [Title]                                    [X]   |
--   | [Search...........] [Rep▼] [Tag▼] [+] [Export] [Import]
--   |---------------------------+----------------------|
--   | Player list (scroll)      | Player detail (right pane)
--   |   • Frost-Lightbringer    |   Name, class, rep, tags, notes,
--   |     Toxic, Key Leaver     |   timeline, encounters, alts,
--   |     [-2 Blacklist]        |   [Edit] [Remove]
--   |   • Other-Realm           |
--   |---------------------------+----------------------|
--   | Status: 23 players (4 blacklisted, 2 favorites)  |
--   +--------------------------------------------------+

local addonName, ns = ...
local C = ns.Constants

local MainFrame = {}
ns.MainFrame = MainFrame

local frame
local listScroll
local listChildren = {}
local detailPane
local searchBox
local repFilter, tagFilter
local statusText
local selectedKey

-- Filter state (transient)
local filter = {
    search = "",
    rep = nil,    -- nil = all, otherwise specific level
    tag = nil,    -- nil = all, otherwise specific tagID
}

function MainFrame:Initialize()
    -- Frame is built lazily on first :Show() to keep load time fast.
    -- We DO subscribe to data callbacks now so we refresh if open.
    ns.Database.RegisterCallback(self, "OnPlayerAdded", "Refresh")
    ns.Database.RegisterCallback(self, "OnPlayerRemoved", "Refresh")
    ns.Database.RegisterCallback(self, "OnPlayerChanged", "Refresh")
end

function MainFrame:Toggle()
    if frame and frame:IsShown() then
        frame:Hide()
    else
        self:Show()
    end
end

function MainFrame:Show()
    self:Build()
    frame:Show()
    self:Refresh()
end

function MainFrame:Hide()
    if frame then frame:Hide() end
end

-- ==========================================================================
-- Frame construction
-- ==========================================================================

function MainFrame:Build()
    if frame then return end

    frame = CreateFrame("Frame", "RepKeeperMainFrame", UIParent, "BackdropTemplate")
    frame:SetSize(820, 540)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("HIGH")
    frame:SetMovable(true)

    -- Register for ESC-to-close. WoW will hide any frame whose global name
    -- is in UISpecialFrames when the user presses Escape.
    tinsert(UISpecialFrames, "RepKeeperMainFrame")
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(f)
        f:StopMovingOrSizing()
        local p, _, _, x, y = f:GetPoint(1)
        ns.db.global.settings.mainFramePoint = { p = p, x = x, y = y }
    end)
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
    if ns.db.global.settings.mainFramePoint then
        local p = ns.db.global.settings.mainFramePoint
        frame:ClearAllPoints()
        frame:SetPoint(p.p, UIParent, p.p, p.x, p.y)
    end

    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -16)
    title:SetText("|cffd0a070" .. ns.L["RepKeeper"] .. "|r")

    -- Close button
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -6, -6)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    -- Help button (top-left) opens an in-game readme
    local helpBtn = CreateFrame("Button", nil, frame, "BackdropTemplate")
    helpBtn:SetSize(22, 22)
    helpBtn:SetPoint("TOPLEFT", 10, -10)
    if helpBtn.SetBackdrop then
        helpBtn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = false, edgeSize = 10,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        helpBtn:SetBackdropColor(0.12, 0.12, 0.14, 1)
        helpBtn:SetBackdropBorderColor(0.55, 0.45, 0.22, 1)
    end
    local helpText = helpBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    helpText:SetPoint("CENTER")
    helpText:SetText("|cffd0a070?|r")
    helpBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("RepKeeper help")
        GameTooltip:AddLine("|cff888888How to use the addon|r", 1, 1, 1, true)
        GameTooltip:Show()
        self:SetBackdropBorderColor(0.85, 0.7, 0.35, 1)
    end)
    helpBtn:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
        self:SetBackdropBorderColor(0.55, 0.45, 0.22, 1)
    end)
    helpBtn:SetScript("OnClick", function() MainFrame:ShowHelp() end)

    -- Search box
    searchBox = CreateFrame("EditBox", "RepKeeperSearchBox", frame, "InputBoxTemplate")
    searchBox:SetSize(220, 22)
    searchBox:SetPoint("TOPLEFT", 24, -48)
    searchBox:SetAutoFocus(false)
    searchBox:SetScript("OnTextChanged", function(self)
        filter.search = self:GetText():lower()
        MainFrame:Refresh()
    end)
    searchBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    local sbLabel = searchBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    sbLabel:SetPoint("LEFT", 4, 0)
    sbLabel:SetText(ns.L["Search players, tags, notes..."])
    searchBox.placeholder = sbLabel
    searchBox:HookScript("OnTextChanged", function(self)
        sbLabel:SetShown(self:GetText() == "")
    end)
    searchBox:HookScript("OnEditFocusGained", function() sbLabel:Hide() end)
    searchBox:HookScript("OnEditFocusLost", function(self)
        sbLabel:SetShown(self:GetText() == "")
    end)

    -- Reputation filter — cycler button instead of UIDropDownMenuTemplate
    -- (the old dropdown system is deprecated in 12.0 and routes through the
    -- secure menu manager which can taint other Blizzard panels).
    local FILTER_CYCLE = { nil, C.REP.BLACKLIST, C.REP.NEUTRAL, C.REP.POSITIVE }
    local filterIdx = 1
    repFilter = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    repFilter:SetSize(120, 22)
    repFilter:SetPoint("LEFT", searchBox, "RIGHT", 8, 0)
    repFilter:SetText("Rep: " .. ns.L["All"])
    repFilter:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Filter by reputation")
        GameTooltip:AddLine("|cff888888Click to cycle: All -> Blacklist -> Neutral -> Positive|r", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    repFilter:SetScript("OnLeave", function() GameTooltip:Hide() end)
    repFilter:SetScript("OnClick", function()
        filterIdx = filterIdx % #FILTER_CYCLE + 1
        filter.rep = FILTER_CYCLE[filterIdx]
        local label = filter.rep and C.REP_NAMES[filter.rep] or ns.L["All"]
        repFilter:SetText("Rep: " .. label)
        MainFrame:Refresh()
    end)

    -- Add button
    local addBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    addBtn:SetSize(80, 22)
    addBtn:SetPoint("TOPRIGHT", -240, -48)
    addBtn:SetText(ns.L["Add Player"])
    addBtn:SetScript("OnClick", function()
        if ns.PlayerEditor then ns.PlayerEditor:OpenNew() end
    end)

    local exportBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    exportBtn:SetSize(70, 22)
    exportBtn:SetPoint("LEFT", addBtn, "RIGHT", 4, 0)
    exportBtn:SetText(ns.L["Export"])
    exportBtn:SetScript("OnClick", function() ns.ImportExport:OpenExport() end)

    local importBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    importBtn:SetSize(70, 22)
    importBtn:SetPoint("LEFT", exportBtn, "RIGHT", 4, 0)
    importBtn:SetText(ns.L["Import"])
    importBtn:SetScript("OnClick", function() ns.ImportExport:OpenImport() end)

    -- Player list (left pane)
    listScroll = CreateFrame("ScrollFrame", "RepKeeperListScroll", frame, "UIPanelScrollFrameTemplate")
    listScroll:SetPoint("TOPLEFT", 20, -84)
    listScroll:SetPoint("BOTTOMLEFT", 20, 40)
    listScroll:SetWidth(340)

    local listChild = CreateFrame("Frame", nil, listScroll)
    listChild:SetSize(340, 1)
    listScroll:SetScrollChild(listChild)
    listScroll.child = listChild

    -- Detail pane (right)
    detailPane = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    detailPane:SetPoint("TOPLEFT", listScroll, "TOPRIGHT", 24, 0)
    detailPane:SetPoint("BOTTOMRIGHT", -20, 40)
    if detailPane.SetBackdrop then
        detailPane:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = false, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 }
        })
        detailPane:SetBackdropColor(0.04, 0.04, 0.05, 0.95)
        detailPane:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    end

    -- Detail pane contents (built once, populated per-selection)
    self:BuildDetailPane()

    -- Status bar
    statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusText:SetPoint("BOTTOMLEFT", 24, 18)
    statusText:SetTextColor(0.7, 0.7, 0.7)
end

function MainFrame:BuildDetailPane()
    local p = detailPane
    p.title = p:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    p.title:SetPoint("TOPLEFT", 16, -16)

    p.subtitle = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    p.subtitle:SetPoint("TOPLEFT", 16, -38)
    p.subtitle:SetTextColor(0.7, 0.7, 0.7)
    p.subtitle:SetWidth(380)
    p.subtitle:SetJustifyH("LEFT")

    -- Separate line for "first seen in X" so the subtitle stays short
    p.location = p:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    p.location:SetPoint("TOPLEFT", 16, -56)
    p.location:SetWidth(380)
    p.location:SetJustifyH("LEFT")

    p.repLabel = p:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    p.repLabel:SetPoint("TOPLEFT", 16, -80)

    p.tagsLabel = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    p.tagsLabel:SetPoint("TOPLEFT", 16, -100)
    p.tagsLabel:SetWidth(380)
    p.tagsLabel:SetJustifyH("LEFT")

    p.notesLabel = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    p.notesLabel:SetPoint("TOPLEFT", 16, -132)
    p.notesLabel:SetWidth(380)
    p.notesLabel:SetJustifyH("LEFT")

    p.altsLabel = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    p.altsLabel:SetPoint("TOPLEFT", 16, -166)
    p.altsLabel:SetWidth(380)
    p.altsLabel:SetJustifyH("LEFT")

    -- Timeline scroll
    p.timelineScroll = CreateFrame("ScrollFrame", nil, p, "UIPanelScrollFrameTemplate")
    p.timelineScroll:SetPoint("TOPLEFT", 16, -200)
    p.timelineScroll:SetPoint("BOTTOMRIGHT", -32, 60)
    p.timelineChild = CreateFrame("Frame", nil, p.timelineScroll)
    p.timelineChild:SetSize(360, 1)
    p.timelineScroll:SetScrollChild(p.timelineChild)

    -- Action buttons at bottom
    p.editBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    p.editBtn:SetSize(110, 22)
    p.editBtn:SetPoint("BOTTOMLEFT", 16, 16)
    p.editBtn:SetText(ns.L["Edit Player"])
    p.editBtn:SetScript("OnClick", function()
        if selectedKey and ns.PlayerEditor then
            local rec = ns.db.global.players[selectedKey]
            if rec then ns.PlayerEditor:Open(rec) end
        end
    end)

    p.removeBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    p.removeBtn:SetSize(110, 22)
    p.removeBtn:SetPoint("LEFT", p.editBtn, "RIGHT", 8, 0)
    p.removeBtn:SetText(ns.L["Remove Player"])
    p.removeBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("|cffff8888Shift-click|r to confirm removal")
        GameTooltip:Show()
    end)
    p.removeBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    p.removeBtn:SetScript("OnClick", function()
        if not selectedKey then return end
        local rec = ns.db.global.players[selectedKey]
        if not rec then return end
        -- Shift-click required to prevent accidents. We avoid StaticPopupDialogs
        -- for confirmation because registering entries in that table taints
        -- the secure StaticPopup subsystem in 12.0 (breaks gear upgrade UI).
        if not IsShiftKeyDown() then
            ns.Addon:Print("|cffff8888Shift-click|r the Remove Player button to confirm removing " .. rec.name .. "-" .. rec.realm .. ".")
            return
        end
        ns.Database:RemovePlayer(selectedKey)
        selectedKey = nil
        MainFrame:Refresh()
    end)
end

-- ==========================================================================
-- List rendering
-- ==========================================================================

function MainFrame:GetFilteredList()
    local search = filter.search or ""
    local list = ns.Database:Iterate(function(rec)
        if filter.rep ~= nil and rec.reputation ~= filter.rep then return false end
        if filter.tag ~= nil and not (rec.tags and rec.tags[filter.tag]) then return false end
        if search ~= "" then
            local hay = (rec.name or ""):lower() .. " " .. (rec.realm or ""):lower() .. " " .. (rec.notes or ""):lower()
            -- Add tag names to searchable hay
            for tagID in pairs(rec.tags or {}) do
                local def = ns.Database:GetTagDef(tagID)
                if def then hay = hay .. " " .. (def.name or ""):lower() end
            end
            if not hay:find(search, 1, true) then return false end
        end
        return true
    end)
    table.sort(list, function(a, b)
        -- Most negative rep first, then most recently seen
        if (a.reputation or 0) ~= (b.reputation or 0) then
            return (a.reputation or 0) < (b.reputation or 0)
        end
        return (a.lastSeen or 0) > (b.lastSeen or 0)
    end)
    return list
end

function MainFrame:Refresh()
    if not frame or not frame:IsShown() then return end

    -- Recycle row frames
    for _, row in ipairs(listChildren) do row:Hide() end

    local list = self:GetFilteredList()
    local rowHeight = 44
    local child = listScroll.child

    for i, rec in ipairs(list) do
        local row = listChildren[i]
        if not row then
            row = self:BuildRow(child, i)
            listChildren[i] = row
        end
        self:PopulateRow(row, rec)
        row:Show()
        row:SetPoint("TOPLEFT", child, "TOPLEFT", 4, -((i - 1) * rowHeight) - 4)
    end

    child:SetHeight(math.max(1, #list * rowHeight + 8))

    -- Update status bar
    local total = ns.Database:Count()
    local blacklisted, positives = 0, 0
    for _, rec in pairs(ns.db.global.players) do
        if rec.reputation == C.REP.BLACKLIST then blacklisted = blacklisted + 1 end
        if rec.reputation == C.REP.POSITIVE then positives = positives + 1 end
    end
    statusText:SetText(string.format("%d players (|cffff5555%d|r blacklisted, |cff55ff55%d|r positive) - %d shown",
        total, blacklisted, positives, #list))

    -- Empty state
    if #list == 0 then
        if not child.emptyText then
            child.emptyText = child:CreateFontString(nil, "OVERLAY", "GameFontDisable")
            child.emptyText:SetPoint("TOP", 0, -20)
            child.emptyText:SetWidth(320)
            child.emptyText:SetJustifyH("CENTER")
        end
        if total == 0 then
            child.emptyText:SetText(ns.L["No players tracked yet. Right-click a player to add them, or use /rk add."])
        else
            child.emptyText:SetText(ns.L["No players match your filter."])
        end
        child.emptyText:Show()
    elseif child.emptyText then
        child.emptyText:Hide()
    end

    -- Refresh detail pane
    if selectedKey and ns.db.global.players[selectedKey] then
        self:ShowDetail(ns.db.global.players[selectedKey])
    elseif #list > 0 then
        selectedKey = list[1].normalizedKey
        self:ShowDetail(list[1])
    else
        self:ClearDetail()
    end
end

function MainFrame:BuildRow(parent, index)
    local row = CreateFrame("Button", nil, parent)
    row:SetSize(330, 40)

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints(row)
    row.bg:SetColorTexture(0, 0, 0, 0.15)

    row.repBar = row:CreateTexture(nil, "ARTWORK")
    row.repBar:SetWidth(4)
    row.repBar:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.repBar:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.name:SetPoint("TOPLEFT", 12, -4)
    row.name:SetJustifyH("LEFT")
    row.name:SetWidth(316)

    row.tags = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.tags:SetPoint("TOPLEFT", 12, -22)
    row.tags:SetJustifyH("LEFT")
    row.tags:SetWidth(240)

    -- "Last seen" snippet pinned to the row's right edge so it doesn't
    -- compete with name/tags. Muted text since it's contextual.
    row.lastSeen = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.lastSeen:SetPoint("BOTTOMRIGHT", -8, 4)
    row.lastSeen:SetJustifyH("RIGHT")

    row:SetScript("OnEnter", function(self)
        self.bg:SetColorTexture(1, 1, 1, 0.10)
    end)
    row:SetScript("OnLeave", function(self)
        if self.rec and selectedKey == self.rec.normalizedKey then
            self.bg:SetColorTexture(1, 0.85, 0.4, 0.15)
        else
            self.bg:SetColorTexture(0, 0, 0, 0.15)
        end
    end)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetScript("OnClick", function(self, button)
        if not self.rec then return end
        if button == "RightButton" then
            MainFrame:ShowRowContextMenu(self.rec, self)
        else
            selectedKey = self.rec.normalizedKey
            MainFrame:Refresh()
        end
    end)

    return row
end

function MainFrame:PopulateRow(row, rec)
    row.rec = rec
    local r, g, b = ns.PlayerUtils:RepColor(rec.reputation or 0)
    row.repBar:SetColorTexture(r, g, b, 1)

    row.name:SetText(ns.PlayerUtils:DisplayName(rec, { colorize = true, includeRealm = true }))

    local tagNames = {}
    for tagID in pairs(rec.tags or {}) do
        local def = ns.Database:GetTagDef(tagID)
        if def then tagNames[#tagNames + 1] = def.name end
    end
    table.sort(tagNames)
    if #tagNames > 0 then
        row.tags:SetText(table.concat(tagNames, ", "))
    else
        row.tags:SetText("|cff666666" .. C.REP_NAMES[rec.reputation or 0] .. "|r")
    end

    if selectedKey == rec.normalizedKey then
        row.bg:SetColorTexture(1, 0.85, 0.4, 0.15)
    else
        row.bg:SetColorTexture(0, 0, 0, 0.15)
    end

    row.lastSeen:SetText("|cff666666" .. ns.PlayerUtils:RelativeTime(rec.lastSeen) .. "|r")
end

-- ==========================================================================
-- Detail pane rendering
-- ==========================================================================

function MainFrame:ClearDetail()
    if not detailPane then return end
    detailPane.title:SetText("")
    detailPane.subtitle:SetText("")
    if detailPane.location then detailPane.location:SetText("") end
    detailPane.repLabel:SetText("")
    detailPane.tagsLabel:SetText("")
    detailPane.notesLabel:SetText("")
    detailPane.altsLabel:SetText("")
    if detailPane.timelineChild then
        for _, c in ipairs({ detailPane.timelineChild:GetChildren() }) do c:Hide() end
        for _, r in ipairs({ detailPane.timelineChild:GetRegions() }) do
            if r.RepKeeperLine then r:Hide() end
        end
    end
end

function MainFrame:ShowDetail(rec)
    if not detailPane then return end
    if not rec then self:ClearDetail() return end

    detailPane.title:SetText(ns.PlayerUtils:DisplayName(rec, { colorize = true, includeRealm = true }))

    -- Subtitle: just faction (colored) and BNet tag if present. Class is
    -- redundant with the class-colored name above. Location goes on its own
    -- line below so this stays short.
    local subtitle = {}
    if rec.faction then
        local fcolor = (rec.faction == "Horde") and "ffcc4444" or "ff4488dd"
        subtitle[#subtitle + 1] = "|c" .. fcolor .. rec.faction .. "|r"
    end
    if rec.bnetTag then
        subtitle[#subtitle + 1] = "|cff77ccff" .. rec.bnetTag .. "|r"
    end
    detailPane.subtitle:SetText(table.concat(subtitle, "   "))

    -- Location + last seen on their own line.
    local locParts = {}
    if rec.firstSeenLocation and rec.firstSeenLocation ~= "" and rec.firstSeenLocation ~= "unknown" then
        local loc = rec.firstSeenLocation:gsub("\226\128\148", "-")
        locParts[#locParts + 1] = "first seen in " .. loc
    end
    locParts[#locParts + 1] = "last seen " .. ns.PlayerUtils:RelativeTime(rec.lastSeen)
    detailPane.location:SetText("|cff888888" .. table.concat(locParts, "  -  ") .. "|r")

    local r, g, b = ns.PlayerUtils:RepColor(rec.reputation or 0)
    local hex = string.format("%02x%02x%02x", math.floor(r * 255), math.floor(g * 255), math.floor(b * 255))
    detailPane.repLabel:SetText(string.format("%s: |cff%s%s|r",
        ns.L["Reputation"], hex, C.REP_NAMES[rec.reputation or 0]))

    local tagNames = {}
    for tagID in pairs(rec.tags or {}) do
        local def = ns.Database:GetTagDef(tagID)
        if def then tagNames[#tagNames + 1] = def.name end
    end
    table.sort(tagNames)
    detailPane.tagsLabel:SetText(string.format("%s: |cffaaaaaa%s|r",
        ns.L["Tags"], #tagNames > 0 and table.concat(tagNames, ", ") or "-"))

    detailPane.notesLabel:SetText(string.format("%s: |cffe6cc80%s|r",
        ns.L["Notes"], (rec.notes and rec.notes ~= "") and rec.notes or "-"))

    if rec.altIDs and #rec.altIDs > 0 then
        local names = {}
        for _, k in ipairs(rec.altIDs) do
            local alt = ns.db.global.players[k]
            names[#names + 1] = alt and (alt.name .. "-" .. alt.realm) or k
        end
        detailPane.altsLabel:SetText(ns.L["Known Alts"] .. ": " .. table.concat(names, ", "))
    else
        detailPane.altsLabel:SetText(ns.L["Known Alts"] .. ": " .. ns.L["No alts known"])
    end

    -- Timeline rendering
    self:RenderTimeline(rec)
end

function MainFrame:RenderTimeline(rec)
    local child = detailPane.timelineChild
    if not child then return end

    -- Hide existing
    if child.lines then
        for _, fs in ipairs(child.lines) do fs:Hide() end
    else
        child.lines = {}
    end

    local entries = rec.timeline or {}
    local lineHeight = 18
    for i = #entries, 1, -1 do  -- newest first
        local idx = #entries - i + 1
        local fs = child.lines[idx]
        if not fs then
            fs = child:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            fs:SetWidth(360)
            fs:SetJustifyH("LEFT")
            child.lines[idx] = fs
        end
        local entry = entries[i]
        local color = "ffffff"
        if entry.type == "detection" then color = "ff8888"
        elseif entry.type == "system" then color = "8888ff"
        elseif entry.type == "encounter" then color = "88ccff" end
        fs:SetText(string.format("|cff%s[%s]|r %s",
            color, date("%Y-%m-%d", entry.ts or 0), entry.text or ""))
        fs:SetPoint("TOPLEFT", 0, -((idx - 1) * lineHeight))
        fs:Show()
    end
    child:SetHeight(math.max(1, #entries * lineHeight + 8))
end

-- ==========================================================================
-- Removal confirmation
-- ==========================================================================
--
-- Note: we used to register StaticPopupDialogs["REPKEEPER_CONFIRM_REMOVE"]
-- here to confirm player removal. That mutated the secure StaticPopup
-- subsystem at file-load time, which tainted the gear upgrade UI flow
-- (StaticPopup is shared with the upgrade confirm dialog). Replaced with
-- a shift-click guard at the call site — see the Remove Player button in
-- BuildDetailPane.

-- ==========================================================================
-- Row right-click context menu
-- ==========================================================================
--
-- A custom floating frame (not Blizzard's secure menu API). The list rows
-- are our own Buttons, so attaching a right-click handler is safe — no
-- secure-execution taint risk like there is with PLAYER/TARGET menus.

local rowMenu

function MainFrame:ShowRowContextMenu(rec, anchorFrame)
    if not rowMenu then
        rowMenu = CreateFrame("Frame", "RepKeeperRowMenu", UIParent, "BackdropTemplate")
        rowMenu:SetFrameStrata("TOOLTIP")
        rowMenu:EnableMouse(true)
        rowMenu:Hide()
        if rowMenu.SetBackdrop then
            rowMenu:SetBackdrop({
                bgFile   = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = false, edgeSize = 12,
                insets   = { left = 3, right = 3, top = 3, bottom = 3 },
            })
            rowMenu:SetBackdropColor(0.06, 0.06, 0.07, 0.97)
            rowMenu:SetBackdropBorderColor(0.5, 0.4, 0.2, 1)
        end
        -- Click anywhere outside to close
        rowMenu:SetScript("OnHide", function() rowMenu._buttons = nil end)
    end

    -- Tear down previous buttons (recreated each open since the actions
    -- depend on which player was right-clicked).
    if rowMenu._buttons then
        for _, b in ipairs(rowMenu._buttons) do b:Hide() end
    end
    rowMenu._buttons = {}

    local title = rowMenu._title
    if not title then
        title = rowMenu:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        title:SetPoint("TOPLEFT", 10, -8)
        rowMenu._title = title
    end
    title:SetText(ns.PlayerUtils:DisplayName(rec, { colorize = true, includeRealm = true }))

    local W = 220
    local entries = {
        { label = "|cffff5555Set Blacklist|r",
          enabled = rec.reputation ~= C.REP.BLACKLIST,
          action = function() ns.Reputation:Set(rec, C.REP.BLACKLIST); MainFrame:Refresh() end },
        { label = "|cffcccccc Set Neutral|r",
          enabled = rec.reputation ~= C.REP.NEUTRAL,
          action = function() ns.Reputation:Set(rec, C.REP.NEUTRAL); MainFrame:Refresh() end },
        { label = "|cff88ff88Set Positive|r",
          enabled = rec.reputation ~= C.REP.POSITIVE,
          action = function() ns.Reputation:Set(rec, C.REP.POSITIVE); MainFrame:Refresh() end },
        { separator = true },
        { label = "Edit Player...",
          action = function() rowMenu:Hide(); ns.PlayerEditor:Open(rec) end },
        { label = "Open in Whisper",
          action = function() ChatFrame_SendTell(rec.name .. "-" .. rec.realm) end },
        { separator = true },
        { label = "|cffff8888Remove Player|r",
          tooltip = "Shift-click to confirm",
          action = function()
              if not IsShiftKeyDown() then
                  ns.Addon:Print("|cffff8888Shift-click|r the Remove Player menu entry to confirm.")
                  return
              end
              ns.Database:RemovePlayer(rec.normalizedKey)
              rowMenu:Hide()
              MainFrame:Refresh()
          end },
    }

    local y = -26
    for _, entry in ipairs(entries) do
        if entry.separator then
            local tex = rowMenu:CreateTexture(nil, "ARTWORK")
            tex:SetSize(W - 16, 1)
            tex:SetPoint("TOPLEFT", 8, y - 4)
            tex:SetColorTexture(0.4, 0.32, 0.18, 0.6)
            rowMenu._buttons[#rowMenu._buttons + 1] = tex
            y = y - 8
        else
            local b = CreateFrame("Button", nil, rowMenu)
            b:SetSize(W - 12, 20)
            b:SetPoint("TOPLEFT", 6, y)
            local tex = b:CreateTexture(nil, "BACKGROUND")
            tex:SetAllPoints(b)
            tex:SetColorTexture(0, 0, 0, 0)
            b.bg = tex
            local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            fs:SetPoint("LEFT", 6, 0)
            fs:SetText(entry.label)
            if entry.enabled == false then
                fs:SetTextColor(0.4, 0.4, 0.4)
                b:Disable()
            end
            b:SetScript("OnEnter", function(self)
                if entry.enabled ~= false then
                    self.bg:SetColorTexture(0.85, 0.7, 0.35, 0.25)
                end
                if entry.tooltip then
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText(entry.tooltip)
                    GameTooltip:Show()
                end
            end)
            b:SetScript("OnLeave", function(self)
                self.bg:SetColorTexture(0, 0, 0, 0)
                GameTooltip:Hide()
            end)
            b:SetScript("OnClick", function()
                if entry.action then entry.action() end
                if not entry.tooltip then  -- keep menu open if confirm-style
                    rowMenu:Hide()
                end
            end)
            rowMenu._buttons[#rowMenu._buttons + 1] = b
            y = y - 22
        end
    end

    rowMenu:SetSize(W, math.abs(y) + 12)

    -- Anchor near the cursor / row
    rowMenu:ClearAllPoints()
    if anchorFrame then
        rowMenu:SetPoint("TOPLEFT", anchorFrame, "TOPRIGHT", 4, 0)
    else
        rowMenu:SetPoint("CENTER")
    end
    rowMenu:Show()
    rowMenu:Raise()
end

-- ==========================================================================
-- Help / in-game readme
-- ==========================================================================

local helpFrame

local HELP_SECTIONS = {
    {
        title = "What is RepKeeper?",
        body = [[A personal reputation tracker for players you meet in WoW. Keep notes on people you've grouped with, blacklist troublemakers, flag the players you'd happily run with again.

Everything is account-wide: if you blacklist someone on one character, every alt sees it.]],
    },
    {
        title = "The three reputation levels",
        body = [[|cffff5555Blacklist|r - avoid this person. You'll get a warning when you join a group with them.
|cffcccccc Neutral|r - default. No opinion either way.
|cff88ff88Positive|r - someone you'd happily group with again.

Set a reputation from the Edit Player window (3 buttons next to "Reputation"), or right-click any player in your group.]],
    },
    {
        title = "Tags",
        body = [[Tags add detail to a player record. Each tag has a tier:
|cffff8888red|r (negative, like "Ninja Looter"),
|cffcccccc gray|r (neutral, like "Tank" or "PUG"),
|cff88ff88green|r (positive, like "Good Healer").

Use the filter buttons at the top of the Tags section to narrow which tags are shown. The [C] marker means it's a custom tag you created.]],
    },
    {
        title = "Auto-tracking",
        body = [[When you enter a dungeon or Mythic+ keystone, every group member is added to your list at Neutral with a timeline entry like "Grouped with in Magister's Terrace +10".

Raids are excluded - too many people, too much clutter. You can disable auto-tracking in Settings > General.]],
    },
    {
        title = "Notes vs Timeline",
        body = [[|cffd0a070Notes|r is a free-form summary, shown in tooltips. Click Edit to modify, Save to commit.

|cffd0a070Timeline|r is a chronological log of events - auto-detected ones (red), system events (blue), and entries you add manually. Use the small input above the list to add new entries.]],
    },
    {
        title = "Slash commands",
        body = [[|cffd0a070/rk|r - open the main window
|cffd0a070/rk add Name-Realm|r - add a player
|cffd0a070/rk remove Name-Realm|r - remove a player
|cffd0a070/rk note Name-Realm <text>|r - add a timeline entry
|cffd0a070/rk tag Name-Realm <tagid>|r - toggle a tag
|cffd0a070/rk export|r - get a shareable list string
|cffd0a070/rk import|r - import a shared list
|cffd0a070/rk backup|r - create a manual backup
|cffd0a070/rk config|r - open settings]],
    },
    {
        title = "Removing things",
        body = [[Removing a player or custom tag uses shift-click as confirmation:

1. Click the X or Remove button - you'll see a message reminding you.
2. Shift-click to confirm.

This avoids accidental deletions without using popup dialogs (which would taint the secure UI on 12.0+).]],
    },
    {
        title = "Backups",
        body = [[Auto-backups run every 7 days by default and keep the last 5. You can also create one manually with |cffd0a070/rk backup|r or from Settings > Backup & Restore.

If a restore looks like it might be a mistake, RepKeeper takes a pre-restore snapshot automatically - so you can undo.]],
    },
}

function MainFrame:BuildHelpFrame()
    if helpFrame then return helpFrame end

    helpFrame = CreateFrame("Frame", "RepKeeperHelpFrame", UIParent, "BackdropTemplate")
    helpFrame:SetSize(560, 540)
    helpFrame:SetPoint("CENTER")
    helpFrame:SetFrameStrata("DIALOG")
    helpFrame:SetMovable(true)
    helpFrame:EnableMouse(true)
    helpFrame:SetClampedToScreen(true)
    helpFrame:RegisterForDrag("LeftButton")
    helpFrame:SetScript("OnDragStart", helpFrame.StartMoving)
    helpFrame:SetScript("OnDragStop", helpFrame.StopMovingOrSizing)
    helpFrame:Hide()
    tinsert(UISpecialFrames, "RepKeeperHelpFrame")

    if helpFrame.SetBackdrop then
        helpFrame:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = false, edgeSize = 14,
            insets   = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        helpFrame:SetBackdropColor(0.06, 0.06, 0.07, 0.96)
        helpFrame:SetBackdropBorderColor(0.5, 0.4, 0.2, 1)
    end

    local title = helpFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -14)
    title:SetText("|cffd0a070RepKeeper - How to Use|r")

    local closeX = CreateFrame("Button", nil, helpFrame, "UIPanelCloseButton")
    closeX:SetPoint("TOPRIGHT", -4, -4)
    closeX:SetScript("OnClick", function() helpFrame:Hide() end)

    -- Scrollable body
    local scroll = CreateFrame("ScrollFrame", "RepKeeperHelpScroll", helpFrame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 18, -46)
    scroll:SetPoint("BOTTOMRIGHT", -36, 50)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(500, 1)
    scroll:SetScrollChild(content)

    local y = 0
    for _, section in ipairs(HELP_SECTIONS) do
        local header = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        header:SetPoint("TOPLEFT", 0, y)
        header:SetText("|cffd0a070" .. section.title .. "|r")
        y = y - 22

        local body = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        body:SetPoint("TOPLEFT", 8, y)
        body:SetWidth(490)
        body:SetJustifyH("LEFT")
        body:SetJustifyV("TOP")
        body:SetSpacing(2)
        body:SetText(section.body)
        local h = body:GetStringHeight()
        y = y - h - 16
    end
    content:SetHeight(math.max(1, -y + 8))

    local closeBottom = CreateFrame("Button", nil, helpFrame, "UIPanelButtonTemplate")
    closeBottom:SetSize(120, 24)
    closeBottom:SetPoint("BOTTOM", 0, 16)
    closeBottom:SetText("Close")
    closeBottom:SetScript("OnClick", function() helpFrame:Hide() end)

    return helpFrame
end

function MainFrame:ShowHelp()
    self:BuildHelpFrame()
    helpFrame:Show()
    helpFrame:Raise()
end
