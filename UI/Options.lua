-- UI/Options.lua
-- AceConfig-3.0 options panel. Registered into the Blizzard interface
-- options on init; opened via /rk config or the minimap right-click.
--
-- All settings live at ns.db.global.settings (AceDB global scope).

local addonName, ns = ...
local C = ns.Constants

local Options = {}
ns.Options = Options

local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

local function setting(key)
    return function(info, value)
        if value == nil then return ns.db.global.settings[key] end
        ns.db.global.settings[key] = value
    end
end

local function getter(key)
    return function() return ns.db.global.settings[key] end
end

local function setter(key)
    return function(_, value) ns.db.global.settings[key] = value end
end

local function buildOptionsTable()
    local s = ns.db.global.settings
    return {
        type = "group",
        name = ns.L["RepKeeper"],
        args = {
            general = {
                type = "group",
                name = ns.L["General"],
                order = 1,
                args = {
                    streamerMode = {
                        type = "toggle",
                        name = ns.L["Streamer Mode"],
                        desc = ns.L["Hide character names and notes from the UI."],
                        get = getter("streamerMode"),
                        set = setter("streamerMode"),
                        order = 1,
                    },
                    minimapToggle = {
                        type = "toggle",
                        name = "Show Minimap Button",
                        get = function() return not s.minimapButton.hide end,
                        set = function(_, v)
                            s.minimapButton.hide = not v
                            if ns.Minimap and ns.Minimap.Refresh then ns.Minimap:Refresh() end
                        end,
                        order = 2,
                    },
                    encounterHeader = {
                        type = "header",
                        name = "Encounter Tracking",
                        order = 10,
                    },
                    encounterHistoryEnabled = {
                        type = "toggle",
                        name = "Track encounter history",
                        desc = "Log dungeon, M+, raid, arena, and BG encounters with their outcome.",
                        get = getter("encounterHistoryEnabled"),
                        set = setter("encounterHistoryEnabled"),
                        width = "double",
                        order = 11,
                    },
                    autoTrackDungeonGroups = {
                        type = "toggle",
                        name = "Auto-add dungeon/M+ groupmates",
                        desc = "When you enter a dungeon or Mythic+ keystone, automatically add every group member to your list at neutral reputation. Raids are excluded to keep the list manageable.",
                        get = getter("autoTrackDungeonGroups"),
                        set = setter("autoTrackDungeonGroups"),
                        width = "double",
                        order = 12,
                    },
                    autoPruneEnabled = {
                        type = "toggle",
                        name = "Auto-prune old neutral records",
                        desc = "Clean up auto-added neutral records that haven't been seen in a while. Records that you've tagged, noted, blacklisted, or marked positive are NEVER pruned -- only abandoned auto-adds. Off by default.",
                        get = getter("autoPruneEnabled"),
                        set = setter("autoPruneEnabled"),
                        width = "double",
                        order = 13,
                    },
                    autoPruneDays = {
                        type = "range",
                        name = "Prune after N days",
                        desc = "Remove neutral auto-tracked records last seen more than this many days ago.",
                        min = 7, max = 365, step = 1,
                        get = getter("autoPruneDays"),
                        set = setter("autoPruneDays"),
                        disabled = function() return not ns.db.global.settings.autoPruneEnabled end,
                        order = 14,
                    },
                    timelineDateFormat = {
                        type = "select",
                        name = "Timeline date format",
                        desc = "Show timestamps as '3d ago' (relative) or '2026-05-13 14:22' (absolute). You can also click any individual timeline entry to toggle just that one.",
                        values = {
                            relative = "Relative (3d ago)",
                            absolute = "Absolute (2026-05-13 14:22)",
                        },
                        get = getter("timelineDateFormat"),
                        set = setter("timelineDateFormat"),
                        order = 15,
                    },
                },
            },

            tooltip = {
                type = "group",
                name = ns.L["Tooltip"],
                order = 2,
                args = {
                    tooltipEnabled       = { type="toggle", name="Enable tooltip integration",
                        get=getter("tooltipEnabled"), set=setter("tooltipEnabled"), order=1 },
                    tooltipShowTags      = { type="toggle", name="Show tags",
                        get=getter("tooltipShowTags"), set=setter("tooltipShowTags"), order=2 },
                    tooltipShowNote      = { type="toggle", name="Show notes/timeline",
                        get=getter("tooltipShowNote"), set=setter("tooltipShowNote"), order=3 },
                    tooltipShowEncounters= { type="toggle", name="Show encounter count",
                        get=getter("tooltipShowEncounters"), set=setter("tooltipShowEncounters"), order=4 },
                    tooltipShowDateAdded = { type="toggle", name="Show date added",
                        get=getter("tooltipShowDateAdded"), set=setter("tooltipShowDateAdded"), order=5 },
                    tooltipMaxNoteLines  = { type="range", name="Max timeline lines on tooltip",
                        min=1, max=10, step=1,
                        get=getter("tooltipMaxNoteLines"), set=setter("tooltipMaxNoteLines"), order=6 },
                },
            },

            warnings = {
                type = "group",
                name = ns.L["Group Warnings"],
                order = 3,
                args = {
                    groupWarningEnabled = { type="toggle", name="Enable group warnings",
                        get=getter("groupWarningEnabled"), set=setter("groupWarningEnabled"), order=1 },
                    groupWarningSound   = { type="toggle", name="Play warning sound",
                        get=getter("groupWarningSound"), set=setter("groupWarningSound"), order=2 },
                    groupWarningInfo = {
                        type="description",
                        name="|cff888888Group warnings fire when you join a group containing anyone marked Blacklist.|r",
                        order=3,
                    },
                    contextHeader = { type="header", name="Contexts", order=4 },
                    ctxParty = { type="toggle", name="Party",
                        get=function() return s.groupWarningContexts.party end,
                        set=function(_,v) s.groupWarningContexts.party = v end, order=5 },
                    ctxRaid = { type="toggle", name="Raid",
                        get=function() return s.groupWarningContexts.raid end,
                        set=function(_,v) s.groupWarningContexts.raid = v end, order=6 },
                    ctxArena = { type="toggle", name="Arena",
                        get=function() return s.groupWarningContexts.arena end,
                        set=function(_,v) s.groupWarningContexts.arena = v end, order=7 },
                    ctxBG = { type="toggle", name="Battleground",
                        get=function() return s.groupWarningContexts.battleground end,
                        set=function(_,v) s.groupWarningContexts.battleground = v end, order=8 },
                },
            },

            detection = {
                type = "group",
                name = ns.L["Detection"],
                order = 4,
                args = {
                    detectionEnabled     = { type="toggle", name="Enable behavior detection",
                        get=getter("detectionEnabled"), set=setter("detectionEnabled"), order=1 },
                    detectLeavers        = { type="toggle", name="Detect group leavers",
                        get=getter("detectLeavers"), set=setter("detectLeavers"), order=2 },
                    detectVoteKicks      = { type="toggle", name="Track vote-kicks",
                        get=getter("detectVoteKicks"), set=setter("detectVoteKicks"), order=3 },
                    quickAddPopupEnabled = { type="toggle", name="Show quick-add popup",
                        get=getter("quickAddPopupEnabled"), set=setter("quickAddPopupEnabled"), order=4 },
                    quickAddPopupTimeout = { type="range", name="Quick-add popup timeout (s)",
                        min=5, max=60, step=1,
                        get=getter("quickAddPopupTimeout"), set=setter("quickAddPopupTimeout"), order=5 },
                    spamHeader = { type="header", name="Spam thresholds", order=10 },
                    detectTradeSpam      = { type="toggle", name="Detect trade spam",
                        get=getter("detectTradeSpam"), set=setter("detectTradeSpam"), order=11 },
                    tradeSpamThreshold   = { type="range", name="Trade requests", min=2, max=10, step=1,
                        get=getter("tradeSpamThreshold"), set=setter("tradeSpamThreshold"), order=12 },
                    tradeSpamWindow      = { type="range", name="Trade window (s)", min=10, max=300, step=10,
                        get=getter("tradeSpamWindow"), set=setter("tradeSpamWindow"), order=13 },
                    detectDuelSpam       = { type="toggle", name="Detect duel spam",
                        get=getter("detectDuelSpam"), set=setter("detectDuelSpam"), order=14 },
                    duelSpamThreshold    = { type="range", name="Duel requests", min=2, max=10, step=1,
                        get=getter("duelSpamThreshold"), set=setter("duelSpamThreshold"), order=15 },
                    duelSpamWindow       = { type="range", name="Duel window (s)", min=10, max=600, step=10,
                        get=getter("duelSpamWindow"), set=setter("duelSpamWindow"), order=16 },
                    detectWhisperSpam    = { type="toggle", name="Detect whisper spam",
                        get=getter("detectWhisperSpam"), set=setter("detectWhisperSpam"), order=17 },
                    whisperSpamThreshold = { type="range", name="Whisper count", min=2, max=20, step=1,
                        get=getter("whisperSpamThreshold"), set=setter("whisperSpamThreshold"), order=18 },
                    whisperSpamWindow    = { type="range", name="Whisper window (s)", min=10, max=300, step=10,
                        get=getter("whisperSpamWindow"), set=setter("whisperSpamWindow"), order=19 },
                },
            },

            autoActions = {
                type = "group",
                name = ns.L["Auto-Actions"],
                order = 5,
                args = {
                    desc = { type="description",
                        name = "|cffff8888These actions happen automatically. Be sure your blacklist criteria are tight.|r",
                        order=0, fontSize="medium" },
                    autoIgnoreEnabled = { type="toggle", name="Auto-ignore blacklisted players",
                        desc="Adds blacklisted players to your /ignore list automatically.",
                        get=getter("autoIgnoreEnabled"), set=setter("autoIgnoreEnabled"), order=1 },
                    autoDeclineGroupInvites = { type="toggle", name="Auto-decline group invites from blacklisted",
                        get=getter("autoDeclineGroupInvites"), set=setter("autoDeclineGroupInvites"), order=3 },
                    autoDeclineGuildInvites = { type="toggle", name="Auto-decline guild invites",
                        get=getter("autoDeclineGuildInvites"), set=setter("autoDeclineGuildInvites"), order=4 },
                    autoDeclineDuels = { type="toggle", name="Auto-decline duels",
                        get=getter("autoDeclineDuels"), set=setter("autoDeclineDuels"), order=5 },
                    autoDeclineTrades = { type="toggle", name="Auto-close trades",
                        get=getter("autoDeclineTrades"), set=setter("autoDeclineTrades"), order=6 },
                },
            },

            lfg = {
                type = "group",
                name = ns.L["LFG Filter"],
                order = 6,
                args = {
                    lfgFilterEnabled       = { type="toggle", name="Enable LFG list filtering",
                        get=getter("lfgFilterEnabled"), set=setter("lfgFilterEnabled"), order=1 },
                    lfgHideBlacklisted     = { type="toggle", name="Hide blacklisted leaders entirely",
                        get=getter("lfgHideBlacklisted"), set=setter("lfgHideBlacklisted"), order=2 },
                    lfgHighlightFavorites  = { type="toggle", name="Highlight positive leaders",
                        get=getter("lfgHighlightFavorites"), set=setter("lfgHighlightFavorites"), order=3 },
                },
            },

            guildSync = {
                type = "group",
                name = ns.L["Guild Sync"],
                order = 7,
                args = {
                    desc = { type="description",
                        name = "Share blacklists with trusted guildmates. Off by default; use carefully.",
                        order=0, fontSize="medium" },
                    guildSyncEnabled        = { type="toggle", name="Enable guild sync",
                        get=getter("guildSyncEnabled"), set=setter("guildSyncEnabled"), order=1 },
                    guildSyncMinRank        = { type="range", name="Trust guild rank (0=GM)",
                        min=0, max=10, step=1,
                        get=getter("guildSyncMinRank"), set=setter("guildSyncMinRank"), order=2 },
                    guildSyncTrustLevel     = {
                        type="select", name="Trust level",
                        values = {
                            [0] = "Ignore peer messages",
                            [1] = "Show as suggestions (require approval)",
                            [2] = "Auto-merge",
                        },
                        get=getter("guildSyncTrustLevel"), set=setter("guildSyncTrustLevel"), order=3,
                    },
                    shareHeader = { type="header", name="What to share", order=10 },
                    guildSyncShareBlacklist = { type="toggle", name="Share blacklist",
                        get=getter("guildSyncShareBlacklist"), set=setter("guildSyncShareBlacklist"), order=11 },
                    guildSyncShareFavorites = { type="toggle", name="Share positive ratings",
                        get=getter("guildSyncShareFavorites"), set=setter("guildSyncShareFavorites"), order=12 },
                    guildSyncShareNotes     = { type="toggle", name="Share notes (privacy risk)",
                        get=getter("guildSyncShareNotes"), set=setter("guildSyncShareNotes"), order=13 },
                },
            },

            privacy = {
                type = "group",
                name = ns.L["Privacy"],
                order = 8,
                args = {
                    streamerMode    = { type="toggle", name=ns.L["Streamer Mode"],
                        desc=ns.L["Hide character names and notes from the UI."],
                        get=getter("streamerMode"), set=setter("streamerMode"), order=1 },
                    anonymizeExports= { type="toggle", name="Anonymize exports (no notes/timeline/BNet)",
                        get=getter("anonymizeExports"), set=setter("anonymizeExports"), order=2 },
                },
            },

            backup = {
                type = "group",
                name = ns.L["Backup & Restore"],
                order = 9,
                args = {
                    autoBackupEnabled  = { type="toggle", name="Auto-backup enabled",
                        get=getter("autoBackupEnabled"), set=setter("autoBackupEnabled"), order=1 },
                    autoBackupInterval = { type="range", name="Auto-backup interval (days)",
                        min=1, max=30, step=1,
                        get=getter("autoBackupInterval"), set=setter("autoBackupInterval"), order=2 },
                    autoBackupKeepCount= { type="range", name="Backups to keep", min=1, max=20, step=1,
                        get=getter("autoBackupKeepCount"), set=setter("autoBackupKeepCount"), order=3 },
                    createBackup = {
                        type="execute", name="Create Backup Now", order=4,
                        func = function()
                            local ts = ns.Backup:CreateBackup("manual")
                            if ts then
                                ns.Addon:Printf(ns.L["Backup created: %s"],
                                    date("%Y-%m-%d %H:%M:%S", ts))
                            end
                        end,
                    },
                    backupList = {
                        type = "group",
                        name = ns.L["Backups"],
                        inline = true,
                        order = 10,
                        args = {},  -- filled dynamically below
                    },
                },
            },
        },
    }
end

local function rebuildBackupArgs(opts)
    local args = opts.args.backup.args.backupList.args
    -- Clear existing
    for k in pairs(args) do args[k] = nil end

    local list = ns.Backup:ListBackups()
    if #list == 0 then
        args.empty = { type="description", name="No backups yet.", order=1 }
        return
    end
    for i, b in ipairs(list) do
        local label = string.format("%s - %s",
            date("%Y-%m-%d %H:%M:%S", b.timestamp), b.kind or "?")
        args["b" .. i] = {
            type = "execute",
            name = ns.L["Restore"] .. ": " .. label,
            order = i,
            confirm = true,
            confirmText = "Restore this backup? Current data will be saved as a pre-restore backup.",
            func = function()
                local ok, count = ns.Backup:Restore(b.timestamp)
                if ok then
                    ns.Addon:Printf(ns.L["Restored backup from %s (%d players)"],
                        date("%Y-%m-%d %H:%M:%S", b.timestamp), count)
                else
                    ns.Addon:Printf("Restore failed: %s", tostring(count))
                end
            end,
        }
    end
end

function Options:Initialize()
    self.optionsTable = buildOptionsTable()
    AceConfig:RegisterOptionsTable("RepKeeper", function()
        rebuildBackupArgs(self.optionsTable)
        return self.optionsTable
    end)
    self.frame = AceConfigDialog:AddToBlizOptions("RepKeeper", "RepKeeper")
end

function Options:Open()
    -- AceConfigDialog has its own SetDefaultSize / Open
    AceConfigDialog:Open("RepKeeper")
end
