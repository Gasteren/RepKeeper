-- Constants.lua
-- Single source of truth for tags, reputation levels, and defaults.
-- Modules should reference these rather than hardcoding strings.

local addonName, ns = ...
local L = LibStub("AceLocale-3.0"):GetLocale("RepKeeper")

ns.Constants = {}
local C = ns.Constants

-- Addon-wide communication prefix (max 16 chars per AceComm spec)
C.COMM_PREFIX = "RepKeeper"
C.PROTOCOL_VERSION = 1

-- SavedVariables schema version. Bumping this triggers Database:Migrate().
C.SCHEMA_VERSION = 4

-- Reputation levels. Simplified to 3 tiers in v1.1: Blacklist / Neutral /
-- Positive. The old 5-tier scale (BLACKLIST=-2, NEGATIVE=-1, NEUTRAL=0,
-- POSITIVE=+1, FAVORITE=+2) is preserved as aliases so existing migration
-- code and external integrations keep working. New code should reference
-- only the three primary keys.
C.REP = {
    BLACKLIST  = -1,  -- Avoid; trigger warnings; never group with again
    NEUTRAL    =  0,  -- Default; no opinion either way
    POSITIVE   =  1,  -- Want to group with again
    -- Legacy aliases — point to the nearest tier in the new scheme.
    NEGATIVE   = -1,  -- collapsed into Blacklist
    FAVORITE   =  1,  -- collapsed into Positive
}

C.REP_NAMES = {
    [-1] = L["Blacklist"],
    [ 0] = L["Neutral"],
    [ 1] = L["Positive"],
}

C.REP_COLORS = {
    [-1] = { r = 1.00, g = 0.20, b = 0.20 },  -- red
    [ 0] = { r = 0.80, g = 0.80, b = 0.80 },  -- gray
    [ 1] = { r = 0.40, g = 0.85, b = 0.40 },  -- green
}

-- Built-in tags. Users can add custom ones via the UI.
-- Key is a stable identifier (do not localize); name is user-facing.
--
-- Each tag has a `tier`: "negative" (red), "neutral" (gray), or "positive"
-- (green). The legacy `negative` boolean is kept as an alias for older code
-- paths (Tooltip, etc.) — derived from tier.
local function tag(name, tier, icon)
    return { name = name, tier = tier, negative = (tier == "negative"), icon = icon }
end

C.BUILTIN_TAGS = {
    -- Negative
    ninja_looter   = tag(L["Ninja Looter"],   "negative", "Interface\\Icons\\INV_Misc_Coin_01"),
    toxic          = tag(L["Toxic"],          "negative", "Interface\\Icons\\Spell_Shadow_DeathScream"),
    afk            = tag(L["AFK"],            "negative", "Interface\\Icons\\Spell_Nature_Sleep"),
    bad_tank       = tag(L["Bad Tank"],       "negative", "Interface\\Icons\\INV_Shield_06"),
    bad_healer     = tag(L["Bad Healer"],     "negative", "Interface\\Icons\\Spell_Holy_FlashHeal"),
    bad_dps        = tag(L["Bad DPS"],        "negative", "Interface\\Icons\\INV_Sword_04"),
    scammer        = tag(L["Scammer"],        "negative", "Interface\\Icons\\INV_Misc_Coin_17"),
    spammer        = tag(L["Spammer"],        "negative", "Interface\\Icons\\Spell_Holy_SilenceAura"),
    griefer        = tag(L["Griefer"],        "negative", "Interface\\Icons\\Ability_Warrior_BattleShout"),
    arena_thrower  = tag(L["Arena Thrower"],  "negative", "Interface\\Icons\\Achievement_Arena_2v2_1"),
    key_leaver     = tag(L["Key Leaver"],     "negative", "Interface\\Icons\\Spell_Nature_Polymorph"),
    boost_scammer  = tag(L["Boost Scammer"],  "negative", "Interface\\Icons\\INV_Misc_Bag_10"),
    pull_griefer   = tag(L["Ninja Puller"],   "negative", "Interface\\Icons\\Ability_Hunter_SniperShot"),
    -- Neutral (descriptive but no judgment)
    tank           = tag(L["Tank"],           "neutral",  "Interface\\Icons\\INV_Shield_04"),
    healer         = tag(L["Healer"],         "neutral",  "Interface\\Icons\\Spell_Holy_Heal"),
    dps            = tag(L["DPS"],            "neutral",  "Interface\\Icons\\INV_Sword_06"),
    quiet          = tag(L["Quiet"],          "neutral",  "Interface\\Icons\\Inv_misc_book_05"),
    talkative      = tag(L["Talkative"],      "neutral",  "Interface\\Icons\\UI_Chat"),
    pug            = tag(L["PUG"],            "neutral",  "Interface\\Icons\\INV_Misc_GroupLooking"),
    guildie        = tag(L["Guildmate"],      "neutral",  "Interface\\Icons\\INV_Crown_01"),
    irl_friend     = tag(L["IRL Friend"],     "neutral",  "Interface\\Icons\\Spell_Holy_PrayerOfHealing"),
    -- Positive
    good_tank      = tag(L["Good Tank"],      "positive", "Interface\\Icons\\INV_Shield_31"),
    good_healer    = tag(L["Good Healer"],    "positive", "Interface\\Icons\\Spell_Holy_GreaterHeal"),
    good_dps       = tag(L["Good DPS"],       "positive", "Interface\\Icons\\Ability_Warrior_Charge"),
    raid_lead      = tag(L["Reliable Raid Lead"], "positive", "Interface\\Icons\\INV_Crown_02"),
    friendly       = tag(L["Friendly"],       "positive", "Interface\\Icons\\INV_Misc_GroupLooking"),
    skilled        = tag(L["Skilled"],        "positive", "Interface\\Icons\\Spell_ChargePositive"),
}

-- Encounter result codes. Stored as integers in SavedVariables to save space.
C.ENCOUNTER_RESULT = {
    UNKNOWN     = 0,
    COMPLETED   = 1,
    TIMED       = 2,  -- M+ in time
    DEPLETED    = 3,  -- M+ over time
    ABANDONED   = 4,  -- group disbanded
    LEFT_EARLY  = 5,  -- this player left
    KICKED      = 6,  -- this player was kicked
    WIPE        = 7,
}

-- Encounter type codes.
C.ENCOUNTER_TYPE = {
    DUNGEON         = 1,
    MYTHIC_PLUS     = 2,
    RAID            = 3,
    ARENA_2V2       = 4,
    ARENA_3V3       = 5,
    BATTLEGROUND    = 6,
    RATED_BG        = 7,
    DELVE           = 8,
    SCENARIO        = 9,
    OPEN_WORLD      = 10,
}

-- Detection event codes (for timeline auto-entries).
C.DETECTION = {
    LEFT_GROUP      = "left_group",
    VOTE_KICKED     = "vote_kicked",
    TRADE_SPAM      = "trade_spam",
    DUEL_SPAM       = "duel_spam",
    WHISPER_SPAM    = "whisper_spam",
    NINJA_LOOT      = "ninja_loot",
    PVP_LEAVER      = "pvp_leaver",
}

-- Defaults for AceDB. Account-wide ("global") per user request.
-- realm = global database keyed by "PlayerName-Realm" → record
-- The "global" key in AceDB means it's shared across all chars on the account.
C.DEFAULTS = {
    global = {
        schemaVersion = C.SCHEMA_VERSION,
        players = {},        -- ["Name-Realm"] = playerRecord
        bnetAccounts = {},   -- [bnetID] = { players = { "Name-Realm", ... }, primaryNote = "" }
        customTags = {},     -- [tagID] = { name=, negative=, icon= }
        encounters = {},     -- [encounterID] = encounter record (rolling buffer, see Database)
        encounterCounter = 0,
        settings = {
            -- Tooltip
            tooltipEnabled       = true,
            tooltipShowTags      = true,
            tooltipShowNote      = true,
            tooltipShowEncounters = true,
            tooltipShowDateAdded = true,
            tooltipMaxNoteLines  = 3,

            -- Group warnings
            groupWarningEnabled  = true,
            groupWarningSound    = true,
            groupWarningMinRep   = -1,   -- warn for negative or worse
            groupWarningContexts = {
                party = true, raid = true, arena = true, battleground = true,
            },

            -- Detection
            detectionEnabled     = true,
            detectLeavers        = true,
            detectVoteKicks      = true,
            detectTradeSpam      = true,
            detectDuelSpam       = true,
            detectWhisperSpam    = true,
            tradeSpamThreshold   = 3,    -- N requests in window
            tradeSpamWindow      = 60,   -- seconds
            duelSpamThreshold    = 2,
            duelSpamWindow       = 120,
            whisperSpamThreshold = 5,
            whisperSpamWindow    = 30,
            quickAddPopupEnabled = true,
            quickAddPopupTimeout = 15,

            -- Auto-ignore / auto-decline
            -- These are OFF by default because protected API calls
            -- (DeclineGroup, DeclineGuild, CancelDuel, CloseTrade) taint
            -- the secure execution context and will break things like the
            -- gear upgrade UI, character frame, and combat input. Only
            -- enable if you understand the tradeoff.
            autoIgnoreEnabled       = false,
            autoIgnoreThreshold     = -2, -- only ignore blacklisted
            autoDeclineGroupInvites = false,
            autoDeclineGuildInvites = false,
            autoDeclineDuels        = false,
            autoDeclineTrades       = false,

            -- LFG
            lfgFilterEnabled     = true,
            lfgHideBlacklisted   = false,  -- hide vs highlight
            lfgHighlightFavorites = true,

            -- Encounter history
            encounterHistoryEnabled = true,
            encounterHistoryLimit   = 1000,  -- ring buffer
            -- Auto-add dungeon/M+ groupmates as neutral records (raids excluded
            -- to avoid clutter — 20+ pug raids would flood the list)
            autoTrackDungeonGroups  = true,

            -- Guild sync
            guildSyncEnabled         = false,
            guildSyncMinRank         = 0,    -- 0 = GM only, higher = looser
            guildSyncShareBlacklist  = true,
            guildSyncShareFavorites  = false,
            guildSyncShareNotes      = false, -- privacy default
            guildSyncTrustLevel      = 1,    -- 0=ignore, 1=show as suggestions, 2=auto-merge

            -- Privacy
            streamerMode            = false,
            anonymizeExports        = false,

            -- Backup
            autoBackupEnabled       = true,
            autoBackupInterval      = 7,    -- days
            autoBackupKeepCount     = 5,

            -- Auto-prune (auto-track threshold)
            -- When enabled, neutral auto-tracked records older than N days
            -- get cleaned up to keep the list manageable. Records with any
            -- tag, note, manual reputation change (Blacklist or Positive),
            -- or non-zero altIDs are NEVER pruned — only abandoned neutrals.
            autoPruneEnabled        = false,
            autoPruneDays           = 30,

            -- UI
            minimapButton           = { hide = false },
            mainFrameScale          = 1.0,
            mainFramePoint          = nil,  -- {point, x, y}
            -- Timeline date display: "relative" ("3d ago") or "absolute" ("2026-05-13 14:22")
            timelineDateFormat      = "relative",
        },
        backups = {},  -- [timestamp] = serialized snapshot
        lastBackupTime = 0,
        spamTracking = {},  -- transient, but kept across sessions for stale-pruning
    },
}

-- Player record schema (for reference, not enforced):
-- {
--   name           = "Frost",
--   realm          = "Lightbringer",
--   normalizedKey  = "frost-lightbringer",  -- lower-case, dash-separated
--   class          = "PALADIN",
--   race           = "BLOODELF",
--   gender         = 2,
--   faction        = "Horde",
--   guid           = "Player-1234-ABCDEF01",
--   bnetAccountID  = 12345 or nil,
--   bnetTag        = "Carlo#1234" or nil,
--   reputation     = 0,
--   tags           = { ninja_looter = true, ... },
--   notes          = "Free-form summary. Single field; the timeline holds detail.",
--   timeline       = {
--                      { ts=epoch, type="manual"|"detection"|"system", text="...",
--                        detection = "left_group" or nil,
--                        encounterRef = encounterID or nil,
--                      },
--                      ...
--                    },
--   altIDs         = { "name-realm", ... },  -- linked alts on same BNet (or manual link)
--   encounterCount = N,
--   firstSeen      = epoch,
--   lastSeen       = epoch,
--   addedBy        = "MyChar-MyRealm",  -- which of YOUR chars added this entry
--   source         = "manual" | "detection" | "import" | "guildsync",
--   sourcePeer     = "GuildmateName-Realm" or nil,  -- if from guild sync
-- }
