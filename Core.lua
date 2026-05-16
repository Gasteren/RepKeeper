-- Core.lua
-- Addon entry point. Sets up AceAddon, slash commands, and orchestrates module init.

local addonName, ns = ...
local L = LibStub("AceLocale-3.0"):GetLocale("RepKeeper")

local RepKeeper = LibStub("AceAddon-3.0"):NewAddon(
    "RepKeeper",
    "AceConsole-3.0",
    "AceEvent-3.0",
    "AceHook-3.0",
    "AceTimer-3.0",
    "AceComm-3.0",
    "AceSerializer-3.0"
)

ns.Addon = RepKeeper
_G.RepKeeper = RepKeeper  -- expose for /run debugging and other addons

-- ==========================================================================
-- Lifecycle
-- ==========================================================================

function RepKeeper:OnInitialize()
    -- Acquire database (account-wide / global scope per user choice)
    self.db = LibStub("AceDB-3.0"):New("RepKeeperDB", ns.Constants.DEFAULTS, true)
    self.db.RegisterCallback(self, "OnProfileChanged", "OnProfileChanged")
    self.db.RegisterCallback(self, "OnProfileCopied", "OnProfileChanged")
    self.db.RegisterCallback(self, "OnProfileReset",  "OnProfileChanged")

    -- Run schema migrations if needed
    ns.Database:Migrate(self.db.global)

    -- Hand database singleton to modules so they don't all redo LibStub calls.
    -- MUST be set before any ns.X:Initialize() call, since modules read ns.db.
    ns.db = self.db
    ns.L = L

    -- Register slash commands
    self:RegisterChatCommand("rk", "OnSlashCommand")
    self:RegisterChatCommand("repkeeper", "OnSlashCommand")

    -- Initialize options panel (registered now, opened lazily)
    if ns.Options and ns.Options.Initialize then
        ns.Options:Initialize()
    end

    -- Initialize minimap button
    if ns.Minimap and ns.Minimap.Initialize then
        ns.Minimap:Initialize()
    end

    -- Modules self-register; we init them in dependency order in OnEnable
end

function RepKeeper:OnEnable()
    -- Order matters: PlayerUtils -> Database helpers -> AltTracking ->
    -- everything that depends on records.
    local initOrder = {
        "PlayerUtils",
        "AltTracking",
        "Reputation",
        "Timeline",
        "EncounterHistory",
        "Detection",
        "GroupWarning",
        "AutoIgnore",
        "LFGFilter",
        "Tooltip",
        "RightClickMenu",
        "ImportExport",
        "GuildSync",
        "Backup",
        -- UI last, after all data modules ready
        "MainFrame",
        "PlayerEditor",
        "QuickAdd",
    }

    for _, modName in ipairs(initOrder) do
        local mod = ns[modName]
        if mod and type(mod.Initialize) == "function" then
            local ok, err = pcall(mod.Initialize, mod)
            if not ok then
                self:Printf("|cffff5555[init error in %s]|r %s", modName, tostring(err))
            end
        end
    end

    self:Printf("loaded. |cff888888/rk for commands.|r")

    -- Auto-backup check (debounced to once per session)
    if ns.Backup then
        C_Timer.After(5, function() ns.Backup:MaybeAutoBackup() end)
    end

    -- Auto-prune abandoned neutral records. Runs once per session, deferred
    -- a few seconds so login chat noise doesn't bury the message.
    local s = ns.db.global.settings
    if s.autoPruneEnabled and s.autoPruneDays and s.autoPruneDays > 0 then
        C_Timer.After(7, function()
            local n = ns.Database:PruneAbandoned(s.autoPruneDays)
            if n > 0 then
                ns.Addon:Printf("Auto-pruned |cffd0a070%d|r abandoned neutral record(s) older than %d days.",
                    n, s.autoPruneDays)
                if ns.MainFrame then ns.MainFrame:Refresh() end
            end
        end)
    end
end

function RepKeeper:OnProfileChanged()
    -- AceDB swapped profiles. We use global storage so this is mostly a no-op,
    -- but settings are profile-scoped if user enables that later. For now,
    -- just notify modules so they refresh UI state.
    if ns.MainFrame and ns.MainFrame.Refresh then ns.MainFrame:Refresh() end
end

-- ==========================================================================
-- Slash command dispatcher
-- ==========================================================================

local SlashHandlers = {}

function RepKeeper:OnSlashCommand(input)
    input = input and input:trim() or ""
    if input == "" then
        if ns.MainFrame and ns.MainFrame.Toggle then
            ns.MainFrame:Toggle()
        else
            self:PrintHelp()
        end
        return
    end

    local cmd, rest = input:match("^(%S+)%s*(.-)$")
    cmd = cmd:lower()

    local handler = SlashHandlers[cmd]
    if handler then
        handler(self, rest)
    else
        self:Printf("Unknown command: |cffff8888%s|r", cmd)
        self:PrintHelp()
    end
end

function RepKeeper:PrintHelp()
    self:Print(L["RepKeeper commands:"])
    self:Print(L["/rk - toggle main window"])
    self:Print(L["/rk add <name-realm> [reputation] [note] - add a player"])
    self:Print(L["/rk remove <name-realm> - remove a player"])
    self:Print(L["/rk note <name-realm> <text> - add a timeline note"])
    self:Print(L["/rk tag <name-realm> <tag> - toggle a tag"])
    self:Print(L["/rk export - export your list"])
    self:Print(L["/rk import - open import dialog"])
    self:Print(L["/rk backup - create manual backup"])
    self:Print(L["/rk config - open settings"])
    self:Print(L["/rk help - this help"])
end

SlashHandlers.help = function(self) self:PrintHelp() end

SlashHandlers.add = function(self, rest)
    local target, repStr, note = rest:match("^(%S+)%s*(%-?%d?)%s*(.*)$")
    if not target or target == "" then
        self:Print("Usage: /rk add <name-realm> [reputation -2..2] [note]")
        return
    end
    local rep = tonumber(repStr) or ns.Constants.REP.NEGATIVE
    local rec, created = ns.Database:GetOrCreatePlayer(target)
    if not rec then
        self:Printf(L["Player not found: %s"], target)
        return
    end
    rec.reputation = rep
    rec.source = rec.source or "manual"
    if note and note ~= "" then
        ns.Timeline:Append(rec, "manual", note)
    end
    ns.Database:Touch(rec)
    self:Printf(L["Player added: %s"], rec.name .. "-" .. rec.realm)
    if ns.MainFrame and ns.MainFrame.Refresh then ns.MainFrame:Refresh() end
end

SlashHandlers.remove = function(self, rest)
    local target = rest:match("^(%S+)")
    if not target then
        self:Print("Usage: /rk remove <name-realm>")
        return
    end
    local removed = ns.Database:RemovePlayer(target)
    if removed then
        self:Printf(L["Player removed: %s"], target)
        if ns.MainFrame and ns.MainFrame.Refresh then ns.MainFrame:Refresh() end
    else
        self:Printf(L["Player not found: %s"], target)
    end
end

SlashHandlers.note = function(self, rest)
    local target, text = rest:match("^(%S+)%s+(.+)$")
    if not target or not text then
        self:Print("Usage: /rk note <name-realm> <text>")
        return
    end
    local rec = ns.Database:GetPlayer(target)
    if not rec then
        self:Printf(L["Player not found: %s"], target)
        return
    end
    ns.Timeline:Append(rec, "manual", text)
    self:Printf(L["Note added to %s"], target)
end

SlashHandlers.tag = function(self, rest)
    local target, tag = rest:match("^(%S+)%s+(%S+)$")
    if not target or not tag then
        self:Print("Usage: /rk tag <name-realm> <tag>")
        return
    end
    local rec = ns.Database:GetPlayer(target)
    if not rec then
        self:Printf(L["Player not found: %s"], target)
        return
    end
    local enabled = ns.Database:ToggleTag(rec, tag)
    self:Printf(L["Tag '%s' on %s: %s"], tag, target, enabled and L["enabled"] or L["disabled"])
end

SlashHandlers.export = function(self)
    if ns.ImportExport and ns.ImportExport.OpenExport then
        ns.ImportExport:OpenExport()
    end
end

SlashHandlers["import"] = function(self)
    if ns.ImportExport and ns.ImportExport.OpenImport then
        ns.ImportExport:OpenImport()
    end
end

SlashHandlers.backup = function(self)
    if ns.Backup then
        local ts = ns.Backup:CreateBackup("manual")
        if ts then
            self:Printf(L["Backup created: %s"], date("%Y-%m-%d %H:%M:%S", ts))
        end
    end
end

SlashHandlers.config = function(self)
    if ns.Options and ns.Options.Open then
        ns.Options:Open()
    end
end

SlashHandlers.options = SlashHandlers.config
SlashHandlers.settings = SlashHandlers.config
