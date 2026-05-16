-- Modules/ImportExport.lua
-- Convert the player list (and optionally encounter history) into a compact
-- shareable string. Pipeline:
--   table -> AceSerializer-3.0 -> LibDeflate (raw deflate) -> LibDeflate.EncodeForPrint
--
-- Versioned envelope: { version=N, schema=N, players={...}, exportedAt=epoch }
-- so we can validate compatibility and migrate later.

local addonName, ns = ...
local C = ns.Constants

local ImportExport = {}
ns.ImportExport = ImportExport

local Addon = ns.Addon
local AceSerializer = LibStub("AceSerializer-3.0")
local LibDeflate = LibStub("LibDeflate")

local EXPORT_VERSION = 1

function ImportExport:Initialize() end

-- Build a sanitized player list. Notes/timeline can be sensitive — the
-- "anonymizeExports" setting strips them.
function ImportExport:BuildExportPayload(opts)
    opts = opts or {}
    local anon = ns.db.global.settings.anonymizeExports or opts.anonymize
    local blacklistOnly = opts.blacklistOnly
    local players = {}

    for key, rec in pairs(ns.db.global.players) do
        -- Skip non-blacklist records when blacklistOnly is set
        if blacklistOnly and rec.reputation ~= C.REP.BLACKLIST then
            -- nothing
        else
            local exported = {
                name = rec.name,
                realm = rec.realm,
                class = rec.class,
                faction = rec.faction,
                reputation = rec.reputation,
                tags = rec.tags and (function()
                    -- Convert hash table to list to compress better
                    local list = {}
                    for tagID in pairs(rec.tags) do list[#list + 1] = tagID end
                    table.sort(list)
                    return list
                end)() or {},
            }
            if not anon then
                exported.notes = rec.notes
                exported.timeline = rec.timeline
                exported.bnetTag = rec.bnetTag  -- caution: this is privacy-sensitive
                exported.altIDs = rec.altIDs
            end
            players[#players + 1] = exported
        end
    end

    return {
        version = EXPORT_VERSION,
        schema = C.SCHEMA_VERSION,
        exportedAt = time(),
        anonymized = anon and true or false,
        blacklistOnly = blacklistOnly and true or false,
        players = players,
        customTags = ns.db.global.customTags,
    }
end

function ImportExport:Encode(payload)
    local serialized = AceSerializer:Serialize(payload)
    local compressed = LibDeflate:CompressDeflate(serialized, { level = 9 })
    return LibDeflate:EncodeForPrint(compressed)
end

function ImportExport:Decode(str)
    if not str or type(str) ~= "string" then return nil, "empty" end
    str = str:gsub("%s", "")  -- strip whitespace/newlines from paste
    if str == "" then return nil, "empty" end
    local compressed = LibDeflate:DecodeForPrint(str)
    if not compressed then return nil, "decode failed" end
    local serialized = LibDeflate:DecompressDeflate(compressed)
    if not serialized then return nil, "decompress failed" end
    local ok, payload = AceSerializer:Deserialize(serialized)
    if not ok then return nil, "deserialize failed" end
    return payload
end

function ImportExport:Validate(payload)
    if type(payload) ~= "table" then return false, "not a table" end
    if not payload.version then return false, "no version" end
    if payload.version > EXPORT_VERSION then
        return false, string.format(ns.L["Version mismatch (got %d, expected %d)"],
            payload.version, EXPORT_VERSION)
    end
    if type(payload.players) ~= "table" then return false, "no players" end
    return true
end

-- Apply an import. Strategy: merge by normalized key.
--   * if local doesn't have it: add as-is
--   * if local has it: merge tags (union), keep higher reputation magnitude
--     (so a "blacklist" import wins over a local "neutral", but a local
--     "favorite" wins over an imported "neutral"), append timeline entries
--     not already present.
-- Returns counts: {added, updated, skipped}
function ImportExport:Apply(payload, opts)
    opts = opts or {}
    local stats = { added = 0, updated = 0, skipped = 0 }

    -- Custom tags first (so player tags resolve correctly)
    if payload.customTags then
        for tagID, def in pairs(payload.customTags) do
            if not C.BUILTIN_TAGS[tagID] and not ns.db.global.customTags[tagID] then
                ns.db.global.customTags[tagID] = def
            end
        end
    end

    for _, p in ipairs(payload.players) do
        if not p.name or not p.realm then
            stats.skipped = stats.skipped + 1
        else
            local key = (p.name:lower() .. "-" .. p.realm:lower())
            local existing = ns.db.global.players[key]
            if not existing then
                local rec, _ = ns.Database:GetOrCreatePlayer(p.name .. "-" .. p.realm)
                if rec then
                    rec.class = p.class
                    rec.faction = p.faction
                    rec.reputation = p.reputation or C.REP.NEUTRAL
                    rec.tags = {}
                    for _, tagID in ipairs(p.tags or {}) do rec.tags[tagID] = true end
                    rec.notes = p.notes or ""
                    rec.timeline = p.timeline or {}
                    rec.bnetTag = p.bnetTag
                    rec.altIDs = p.altIDs or {}
                    rec.source = "import"
                    rec.sourcePeer = opts.sourcePeer
                    stats.added = stats.added + 1
                end
            else
                -- Merge: tags union
                for _, tagID in ipairs(p.tags or {}) do
                    existing.tags[tagID] = true
                end
                -- Reputation: take the more extreme (further from 0) only if
                -- import is more negative; never let an import overwrite a
                -- local positive rep.
                local incoming = p.reputation or C.REP.NEUTRAL
                if incoming < (existing.reputation or 0) then
                    existing.reputation = incoming
                end
                -- Append timeline entries that aren't duplicates by (ts,text)
                if p.timeline then
                    local seen = {}
                    for _, e in ipairs(existing.timeline or {}) do
                        seen[(e.ts or 0) .. "|" .. (e.text or "")] = true
                    end
                    for _, e in ipairs(p.timeline) do
                        local sig = (e.ts or 0) .. "|" .. (e.text or "")
                        if not seen[sig] then
                            existing.timeline = existing.timeline or {}
                            table.insert(existing.timeline, e)
                        end
                    end
                end
                ns.Database:Touch(existing)
                stats.updated = stats.updated + 1
            end
        end
    end

    return stats
end

-- ==========================================================================
-- UI dialogs
-- ==========================================================================

local AceGUI = LibStub("AceGUI-3.0")

function ImportExport:OpenExport()
    local frame = AceGUI:Create("Frame")
    frame:SetTitle(ns.L["Export"])
    frame:SetLayout("Flow")
    frame:SetWidth(500)
    frame:SetHeight(440)

    -- Filter toggle: blacklist only vs full list. Regenerates the string
    -- in place when toggled so the user sees the size change.
    local state = { blacklistOnly = false }

    local checkbox = AceGUI:Create("CheckBox")
    checkbox:SetLabel("Blacklist only")
    checkbox:SetValue(false)
    checkbox:SetFullWidth(true)
    frame:AddChild(checkbox)

    local edit = AceGUI:Create("MultiLineEditBox")
    edit:SetLabel(ns.L["Copy this string to share your list:"])
    edit:DisableButton(true)
    edit:SetFullWidth(true)
    edit:SetNumLines(15)
    frame:AddChild(edit)

    local function regenerate()
        local payload = self:BuildExportPayload({ blacklistOnly = state.blacklistOnly })
        local str = self:Encode(payload)
        edit:SetText(str)
        frame:SetStatusText(string.format("%d players, %d bytes%s",
            #payload.players, #str,
            state.blacklistOnly and " (blacklist only)" or ""))
        edit.editBox:HighlightText()
        edit:SetFocus()
    end

    checkbox:SetCallback("OnValueChanged", function(_, _, val)
        state.blacklistOnly = val
        regenerate()
    end)

    regenerate()
end

function ImportExport:OpenImport()
    local frame = AceGUI:Create("Frame")
    frame:SetTitle(ns.L["Import"])
    frame:SetStatusText("")
    frame:SetLayout("Flow")
    frame:SetWidth(500)
    frame:SetHeight(400)

    local edit = AceGUI:Create("MultiLineEditBox")
    edit:SetLabel(ns.L["Paste an import string below:"])
    edit:SetFullWidth(true)
    edit:SetNumLines(15)
    edit:DisableButton(true)
    frame:AddChild(edit)

    local importBtn = AceGUI:Create("Button")
    importBtn:SetText(ns.L["Import"])
    importBtn:SetWidth(120)
    importBtn:SetCallback("OnClick", function()
        local str = edit:GetText()
        local payload, err = self:Decode(str)
        if not payload then
            frame:SetStatusText(string.format(ns.L["Import failed: %s"], err or "?"))
            return
        end
        local ok, vErr = self:Validate(payload)
        if not ok then
            frame:SetStatusText(string.format(ns.L["Import failed: %s"], vErr or "?"))
            return
        end
        local stats = self:Apply(payload)
        frame:SetStatusText(string.format(ns.L["Import successful: %d players added, %d updated, %d skipped."],
            stats.added, stats.updated, stats.skipped))
        if ns.MainFrame then ns.MainFrame:Refresh() end
    end)
    frame:AddChild(importBtn)

    local cancelBtn = AceGUI:Create("Button")
    cancelBtn:SetText(ns.L["Cancel"])
    cancelBtn:SetWidth(120)
    cancelBtn:SetCallback("OnClick", function() frame:Hide() end)
    frame:AddChild(cancelBtn)
end
