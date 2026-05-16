-- Locales/enUS.lua
-- Default locale (and fallback for unsupported locales).

local L = LibStub("AceLocale-3.0"):NewLocale("RepKeeper", "enUS", true, true)

-- Reputation levels
L["Blacklist"] = true
L["Negative"] = true
L["Neutral"] = true
L["Positive"] = true
L["Favorite"] = true

-- Built-in tags
L["Ninja Looter"] = true
L["Toxic"] = true
L["AFK"] = true
L["Bad Tank"] = true
L["Bad Healer"] = true
L["Bad DPS"] = true
L["Scammer"] = true
L["Spammer"] = true
L["Griefer"] = true
L["Arena Thrower"] = true
L["Key Leaver"] = true
L["Boost Scammer"] = true
L["Ninja Puller"] = true
L["Good Tank"] = true
L["Good Healer"] = true
L["Good DPS"] = true
L["Reliable Raid Lead"] = true
L["Friendly"] = true
L["Skilled"] = true
L["Tank"] = true
L["Healer"] = true
L["DPS"] = true
L["Quiet"] = true
L["Talkative"] = true
L["PUG"] = true
L["Guildmate"] = true
L["IRL Friend"] = true

-- Main UI
L["RepKeeper"] = true
L["Player reputation, blacklist, and encounter history."] = true
L["Search players, tags, notes..."] = true
L["No players match your filter."] = true
L["No players tracked yet. Right-click a player to add them, or use /rk add."] = true
L["Add Player"] = true
L["Edit Player"] = true
L["Remove Player"] = true
L["Confirm Remove"] = true
L["Are you sure you want to remove %s permanently?"] = true
L["Players (%d)"] = true
L["Filter: %s"] = true
L["All"] = true
L["Tags"] = true
L["Notes"] = true
L["Reputation"] = true
L["Date Added"] = true
L["Last Seen"] = true
L["Encounters"] = true
L["Class"] = true
L["Realm"] = true
L["Battle.net"] = true
L["Known Alts"] = true
L["No alts known"] = true
L["Timeline"] = true
L["Add Note"] = true
L["Custom Tags"] = true
L["Add Custom Tag..."] = true

-- Right-click menu
L["RepKeeper: Add to Blacklist"] = true
L["RepKeeper: Mark as Favorite"] = true
L["RepKeeper: Add Note..."] = true
L["RepKeeper: Rate Player"] = true
L["RepKeeper: View Profile"] = true
L["RepKeeper: Remove from List"] = true
L["RepKeeper: Link as Alt..."] = true

-- Quick add popup
L["RepKeeper: Quick Add"] = true
L["%s just %s. Add them to your list?"] = true
L["left your group"] = true
L["was vote-kicked"] = true
L["spammed trade requests"] = true
L["spammed duel requests"] = true
L["spammed whispers"] = true
L["Skip"] = true
L["Add"] = true
L["Don't show again this session"] = true

-- Group warning
L["RepKeeper Warning"] = true
L["%s in your group is %s"] = true
L["%d players in your group are flagged"] = true
L["View Details"] = true
L["Dismiss"] = true
L["Leave Group"] = true

-- Detection event names (used in timeline)
L["Left group"] = true
L["Vote-kicked from group"] = true
L["Trade spam (%d requests in %ds)"] = true
L["Duel spam (%d requests in %ds)"] = true
L["Whisper spam (%d msgs in %ds)"] = true

-- Encounter types
L["Dungeon"] = true
L["Mythic+"] = true
L["Raid"] = true
L["Arena 2v2"] = true
L["Arena 3v3"] = true
L["Battleground"] = true
L["Rated BG"] = true
L["Delve"] = true
L["Scenario"] = true
L["Open World"] = true

-- Encounter results
L["Completed"] = true
L["Timed"] = true
L["Depleted"] = true
L["Abandoned"] = true
L["Left Early"] = true
L["Kicked"] = true
L["Wiped"] = true
L["Unknown"] = true

-- Slash commands
L["RepKeeper commands:"] = true
L["/rk - toggle main window"] = true
L["/rk add <name-realm> [reputation] [note] - add a player"] = true
L["/rk remove <name-realm> - remove a player"] = true
L["/rk note <name-realm> <text> - add a timeline note"] = true
L["/rk tag <name-realm> <tag> - toggle a tag"] = true
L["/rk export - export your list"] = true
L["/rk import - open import dialog"] = true
L["/rk backup - create manual backup"] = true
L["/rk config - open settings"] = true
L["/rk help - this help"] = true
L["Player added: %s"] = true
L["Player removed: %s"] = true
L["Player not found: %s"] = true
L["Note added to %s"] = true
L["Tag '%s' on %s: %s"] = true
L["enabled"] = true
L["disabled"] = true

-- Import/Export
L["Import"] = true
L["Export"] = true
L["Paste an import string below:"] = true
L["Copy this string to share your list:"] = true
L["Import successful: %d players added, %d updated, %d skipped."] = true
L["Import failed: %s"] = true
L["Invalid import string"] = true
L["Version mismatch (got %d, expected %d)"] = true

-- Guild sync
L["Guild Sync"] = true
L["Guild sync is disabled. Enable in settings."] = true
L["Sync Now"] = true
L["Last sync: %s"] = true
L["Never"] = true
L["Sync requests pending: %d"] = true
L["Suggested by %s"] = true

-- Backup
L["Backup created: %s"] = true
L["Restored backup from %s (%d players)"] = true
L["Backups"] = true
L["Restore"] = true
L["Delete Backup"] = true

-- Settings panel sections
L["General"] = true
L["Tooltip"] = true
L["Detection"] = true
L["Group Warnings"] = true
L["Auto-Actions"] = true
L["LFG Filter"] = true
L["Privacy"] = true
L["Backup & Restore"] = true
L["Streamer Mode"] = true
L["Hide character names and notes from the UI."] = true

-- Misc
L["Yes"] = true
L["No"] = true
L["OK"] = true
L["Cancel"] = true
L["Save"] = true
L["Close"] = true
L["You added a note about yourself? Bold."] = true
L["never"] = true
L["just now"] = true
L["%d minute(s) ago"] = true
L["%d hour(s) ago"] = true
L["%d day(s) ago"] = true
L["%d month(s) ago"] = true
L["%d year(s) ago"] = true
