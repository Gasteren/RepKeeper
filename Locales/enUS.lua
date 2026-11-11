-- Locales/enUS.lua
-- Default locale (and fallback for unsupported locales).

local L = LibStub("AceLocale-3.0"):NewLocale("RepKeeper", "enUS", true, true)

-- Reputation levels
L["Blacklist"] = true
L["Negative"] = true
L["Neutral"] = true
L["Positive"] = true

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
L["All"] = true
L["Tags"] = true
L["Notes"] = true
L["Date Added"] = true
L["Encounters"] = true
L["Battle.net"] = true
L["Known Alts"] = true

-- Quick add popup
L["left your group"] = true
L["was vote-kicked"] = true
L["spammed trade requests"] = true
L["spammed duel requests"] = true
L["spammed whispers"] = true
L["Add"] = true

-- Group warning
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
L["Import failed: %s"] = true
L["Version mismatch (got %d, expected %d)"] = true

-- Guild sync
L["Never"] = true
L["Suggested by %s"] = true

-- Backup
L["Backup created: %s"] = true
L["Backups"] = true
L["Restore"] = true

-- Settings panel sections
L["General"] = true
L["Tooltip"] = true
L["Detection"] = true

-- Misc
L["OK"] = true
L["Cancel"] = true
L["Close"] = true
L["never"] = true
L["just now"] = true
L["%d minute(s) ago"] = true
L["%d hour(s) ago"] = true
L["%d day(s) ago"] = true
L["%d month(s) ago"] = true
L["%d year(s) ago"] = true

-- Core.lua
L["/rk groups - your groups and who was in them"] = true

-- Modules/RightClickMenu.lua
L["Open in RepKeeper"] = true
L["Write a note..."] = true

-- UI/Dialogs.lua
L["Remove player"] = true
L["Remove %s from RepKeeper?\nTheir rating, tags, note and history are deleted."] = true
L["Remove"] = true
L["Add a player"] = true
L["Name"] = true
L["Rating"] = true
L["Note"] = true
L["Optional: why you added them"] = true
L["Type the player's name first."] = true
L["That name doesn't work. Try Name-Realm."] = true
L["Updated %s"] = true
L["First and last name, like Frost Paladin."] = true
L["Add -Realm for players from another realm."] = true
L["New tag"] = true
L["Like Carried us, or Late to raids"] = true
L["Kind"] = true
L["Create"] = true
L["Give the tag a name first."] = true
L["Use letters or numbers in the name."] = true
L["There is already a tag with that name."] = true
L["Your tags can be used on every player."] = true
L["Copy this text with Ctrl+C and send it to a friend. They paste it into Import on their RepKeeper."] = true
L["Blacklist only"] = true
L["Only the players you blacklisted."] = true
L["Leave out notes and history"] = true
L["Leaves out notes, history and Battle.net names. Ratings and tags are still in."] = true
L["Select all"] = true
L["%s players, %s characters"] = true
L["Paste a RepKeeper export below with Ctrl+V and press Import. Players you already have keep their rating, unless the import is stricter. Tags and history are added."] = true
L["Paste the export here."] = true
L["That text isn't a RepKeeper export. Copy the whole text and try again."] = true
L["Imported: %d new, %d updated, %d skipped."] = true

-- UI/Groups.lua
L["Dungeons"] = true
L["Raids"] = true
L["PvP"] = true
L["Pick a run to see who was there. Rate them with one click."] = true
L["When"] = true
L["Where"] = true
L["Result"] = true
L["Players"] = true
L["Who was there"] = true
L["Click a name to open them"] = true
L["(left)"] = true
L["Left the group before the run ended."] = true
L["Click to add them to your list and open them."] = true
L["Not on your list"] = true
L["Group history is off."] = true
L["Turn on Remember my groups on the Options tab, under Tracking."] = true
L["No groups yet."] = true
L["No runs of this kind yet."] = true
L["Pick All above the list to see every run."] = true
L["RepKeeper remembers your dungeons, raids and battlegrounds, and who was in them."] = true
L["Pick a run on the left."] = true
L["Nobody else was in this group."] = true
L["Groups"] = true
L["The runs you did and who was in them: rate the players of a run with one click."] = true

-- UI/MainFrame.lua
L["Avoid them. RepKeeper warns you when they are in your group or invite you."] = true
L["No opinion either way. Players RepKeeper adds from your groups start here."] = true
L["Someone you would happily group with again."] = true
L["Streamer mode"] = true
L["Names are hidden: players show as Player1234. Click to change it on the Options tab."] = true
L["%d guild suggestion"] = true
L["%d guild suggestions"] = true
L["Guildmates shared players with you. Click to review them on the Options tab."] = true
L["%s player"] = true
L["%s players"] = true
L["%s blacklisted"] = true
L["%s positive"] = true

-- UI/Minimap.lua
L["Blacklisted"] = true
L["Guild suggestions"] = true
L["Click to open RepKeeper. Right-click for options."] = true

-- UI/Options.lua
L["Takes effect after a reload."] = true
L["%d day"] = true
L["%d days"] = true
L["%d sec"] = true
L["Within"] = true
L["How RepKeeper looks, its minimap button, and how names and dates show."] = true
L["Window"] = true
L["Look"] = true
L["Classic is the game's own look. Steel, Horde and Alliance recolour the same frames."] = true
L["theme colours colors style skin"] = true
L["UI size"] = true
L["The size of RepKeeper's windows. Turn the mouse wheel over the slider for small steps."] = true
L["scale zoom"] = true
L["Minimap"] = true
L["Show the minimap button"] = true
L["Left-click opens RepKeeper, right-click opens these options."] = true
L["icon"] = true
L["Names"] = true
L["Realm names"] = true
L["Automatic"] = true
L["Hidden on WoW Forever and Classic, where realm names are only for the servers. Shown on Retail."] = true
L["Always show"] = true
L["Always hide"] = true
L["Whether names show their realm, like Frost-Kazzak. Whispers always use the full name."] = true
L["Hides names: players show as Player1234 in RepKeeper's windows and tooltips. Handy when you stream or record."] = true
L["hide privacy record anonymous"] = true
L["History"] = true
L["Dates in history"] = true
L["Relative (3 days ago)"] = true
L["Dates (10 Nov 2026)"] = true
L["How the dates in a player's history show. Hover an entry for the exact time."] = true
L["Alerts"] = true
L["Warnings about blacklisted players around you."] = true
L["In your group"] = true
L["Warn me when a blacklisted player is in my group"] = true
L["A warning pops up when you join a group with someone you blacklisted, with their tags and note."] = true
L["Play a sound"] = true
L["The raid warning sound, so you notice it."] = true
L["In parties"] = true
L["In raids"] = true
L["In arenas"] = true
L["In battlegrounds"] = true
L["Invites"] = true
L["When a blacklisted player invites you to a group, RepKeeper always warns you, so you don't accept by accident. To decline those invites for you, see Automation."] = true
L["Tracking"] = true
L["What RepKeeper remembers on its own."] = true
L["Remember my groups"] = true
L["Keeps the dungeons, raids and battlegrounds you run and who was in them (the Groups tab)."] = true
L["encounters history runs"] = true
L["Add my dungeon groupmates to the list"] = true
L["Everyone in your dungeon and Mythic+ groups is added as Neutral, with a line in their history. Raids are left out: too many people."] = true
L["Clean-up"] = true
L["Remove forgotten players"] = true
L["Removes players RepKeeper added by itself that you never rated, tagged or wrote about, and haven't seen for a while. Checked when you log in."] = true
L["prune delete old"] = true
L["Not seen for"] = true
L["Turn the mouse wheel over the slider to change it one day at a time."] = true
L["Spot players who leave your group or spam you, and offer to rate them."] = true
L["Watch for"] = true
L["Watch for leavers and spammers"] = true
L["RepKeeper notes it in their history and can ask you to rate them."] = true
L["detect"] = true
L["Players who leave my group"] = true
L["Someone leaves while you stay in the group."] = true
L["Vote kicks"] = true
L["Notes it in the history of a player who gets vote-kicked."] = true
L["Trade spam"] = true
L["Someone opens trade with you again and again."] = true
L["Trade requests"] = true
L["Duel spam"] = true
L["Someone asks you to duel again and again."] = true
L["Duel requests"] = true
L["Whisper spam"] = true
L["Someone sends you a lot of whispers in a short time."] = true
L["Whispers"] = true
L["Pop-up"] = true
L["Ask me to rate them"] = true
L["A small pop-up with Blacklist and Positive buttons when RepKeeper spots someone. It goes away by itself."] = true
L["quick add popup"] = true
L["Pop-up stays for"] = true
L["What RepKeeper adds when you hover a player in the game."] = true
L["Show RepKeeper in tooltips"] = true
L["Their rating, and a red BLACKLISTED line for players you blacklisted."] = true
L["hover mouseover"] = true
L["How many groups you had together"] = true
L["When you added them"] = true
L["Automation"] = true
L["Let RepKeeper act on blacklisted players for you. Everything here is off until you turn it on."] = true
L["Blacklisted players"] = true
L["Declining for you uses the game's own pop-ups. On Retail that can stop other game windows from working (like the item upgrade window) until you reload. Turn on only what you need."] = true
L["Add them to my ignore list"] = true
L["Blacklisted players go on your /ignore list, so you don't see their chat."] = true
L["Decline their group invites"] = true
L["Decline their guild invites"] = true
L["Decline their duels"] = true
L["Close their trades"] = true
L["auto ignore decline"] = true
L["Ignore it"] = true
L["What guildmates share is thrown away."] = true
L["Ask me first"] = true
L["What guildmates share waits below until you accept it."] = true
L["Add it right away"] = true
L["What guildmates share is added to your list at once."] = true
L["Guild sync"] = true
L["Share your blacklist with guildmates who also use RepKeeper. Off until you turn it on."] = true
L["Sharing"] = true
L["Share with my guild"] = true
L["Sends your shared players to guildmates with RepKeeper, and receives theirs."] = true
L["sync"] = true
L["Trust guildmates up to rank"] = true
L["Guild Master"] = true
L["Rank %d"] = true
L["Only guildmates of this rank or higher can share with you. 0 is the Guild Master, 1 the rank below, and so on."] = true
L["When a guildmate shares a player"] = true
L["What I share"] = true
L["My blacklist"] = true
L["Players I rated Positive"] = true
L["My notes"] = true
L["Your guildmates can read what you wrote. Off by default."] = true
L["Waiting for you"] = true
L["Player"] = true
L["From"] = true
L["Nothing waiting."] = true
L["Accept"] = true
L["Decline"] = true
L["Click one to accept or decline it."] = true
L["By you"] = true
L["Before a restore"] = true
L["Restored a backup: %d players."] = true
L["Restore failed: %s"] = true
L["Data"] = true
L["Backups, sharing your list, and the tags you made."] = true
L["Back up automatically"] = true
L["Saves a copy of your list when you log in, every few days."] = true
L["Every"] = true
L["Backups to keep"] = true
L["The oldest backup goes when there are more."] = true
L["Back up now"] = true
L["Saves a copy of your list right now."] = true
L["Backup"] = true
L["Made"] = true
L["No backups yet."] = true
L["Restore this backup..."] = true
L["Restore backup"] = true
L["Go back to your list from %s?\nYour list as it is now is saved as a backup first."] = true
L["Delete this backup..."] = true
L["Delete backup"] = true
L["Delete the backup from %s?"] = true
L["Delete"] = true
L["Click a backup to restore or delete it."] = true
L["restore"] = true
L["Share your list"] = true
L["Export..."] = true
L["Turns your list into text you can send to a friend."] = true
L["Import..."] = true
L["Adds a list a friend sent you."] = true
L["Leave out notes and history when exporting"] = true
L["Ratings and tags are still in. Battle.net names are left out too."] = true
L["Your tags"] = true
L["Tag"] = true
L["You haven't made any tags. Make one from a player's + Tag button."] = true
L["Delete this tag..."] = true
L["Delete tag"] = true
L["Delete the tag %s?\nIt is taken off %d players."] = true
L["Click a tag to delete it."] = true
L["open or close RepKeeper"] = true
L["add a player (Name-Realm for other realms)"] = true
L["remove a player"] = true
L["add a line to a player's history"] = true
L["add or remove a tag (its id, like toxic)"] = true
L["open the Groups tab"] = true
L["open these options"] = true
L["share your list"] = true
L["back up your list now"] = true
L["Help"] = true
L["How RepKeeper works, and its chat commands."] = true
L["How it works"] = true
L["Rate the players you meet: Blacklist the ones to avoid, Positive the ones you liked. Everything else stays Neutral."] = true
L["To rate someone, right-click them in the game (their portrait, their name in chat, the group frames) and choose RepKeeper. Or open RepKeeper and press Add player."] = true
L["Hovering a player shows what you know about them. A blacklisted player gets a red BLACKLISTED line, and a warning pops up when they are in your group or invite you."] = true
L["Everything is shared by all your characters on this account."] = true
L["Chat commands"] = true
L["Search settings"] = true
L["Shows only the settings with these words, on every page. Esc clears the search."] = true
L["Some changes need a reload."] = true
L["Reload now"] = true
L["Reloads the interface, like /reload."] = true
L["No settings match \"%s\"."] = true
L["Try other words, or press Esc in the search box to see every setting again."] = true
L["Options"] = true
L["Alerts, tracking, the tooltip, backups and more."] = true
L["Remember the players you meet: blacklist the ones to avoid, keep track of the good ones. Type /rk to open RepKeeper. Everything else is on its Options tab."] = true
L["Open RepKeeper"] = true

-- UI/Players.lua
L["Search names, tags, notes"] = true
L["Finds players by name, tag, note or where you met them. Esc clears it."] = true
L["Search"] = true
L["Add player"] = true
L["Add someone by name: to blacklist them, or to remember a good player."] = true
L["Whisper"] = true
L["Remove..."] = true
L["Blacklisted players first, then the ones you liked, then everyone else."] = true
L["Seen"] = true
L["When you last saw or changed them."] = true
L["Undead"] = true
L["You added them."] = true
L["RepKeeper added them from one of your groups."] = true
L["RepKeeper added them when it spotted them."] = true
L["They came in with an imported list."] = true
L["A guildmate shared them with you."] = true
L["Written by you"] = true
L["Noted by RepKeeper"] = true
L["Spotted by RepKeeper"] = true
L["From a group"] = true
L["Saved"] = true
L["Negative tags"] = true
L["Neutral tags"] = true
L["Positive tags"] = true
L["One of your own tags. You can delete it on the Options tab, under Data."] = true
L["+ New tag..."] = true
L["Click a tag to add or remove it."] = true
L["Click to add this tag."] = true
L["Make a tag of your own. You can use it on every player."] = true
L["Shared by"] = true
L["First seen"] = true
L["Last seen"] = true
L["Add a tag"] = true
L["Tags say why: Ninja Looter, Good Healer, or a tag of your own."] = true
L["Write a note about them. It shows when you hover them in the game."] = true
L["Add what happened, then press Enter"] = true
L["Right-click to delete it."] = true
L["History entry"] = true
L["Delete this entry"] = true
L["Delete this player from RepKeeper (asks first)."] = true
L["Opens a whisper to them in chat."] = true
L["Click to remove this tag."] = true
L["+ Add a tag"] = true
L["+ Tag"] = true
L["No players yet."] = true
L["Right-click someone in the game and choose RepKeeper to rate them, or press Add player. RepKeeper also remembers the players from your dungeon groups."] = true
L["No players match."] = true
L["Clear the search, or pick All above the list."] = true
L["Horde"] = true
L["Alliance"] = true
L["Race and class show once you meet them in the game."] = true
L["Met in %s"] = true
L["Added %s"] = true
L["Seen %s"] = true
L["%d group together"] = true
L["%d groups together"] = true
L["Nothing yet. Write what happened above, or let RepKeeper note it for you."] = true
L["Alts:"] = true
L["Everyone you rated or met: their rating, tags, note and history."] = true

-- UI/QuickAdd.lua
L["%s is now %s."] = true
L["Rate them now, or open them to add a note."] = true
L["Open"] = true
L["Opens them in RepKeeper: rating, tags, note and history."] = true
L["Don't ask again this session"] = true
L["No more of these pop-ups until you log out or reload. RepKeeper still notes it in their history."] = true
L["did something"] = true
L["%s %s."] = true

-- UI/Util.lua
L["%d %b %Y"] = true
L["%d %b %Y, %H:%M"] = true
L["Today"] = true
L["Yesterday"] = true
L["%d days ago"] = true
L["%dd %dh"] = true
L["%dh %02dm"] = true
L["%d min"] = true

-- UI/Warnings.lua
L["RepKeeper warning"] = true
L["Click to open them in RepKeeper."] = true
L["Leaves your group right away."] = true
L["and %d more"] = true
L["A player you blacklisted is in your group."] = true
L["%d players you blacklisted are in your group."] = true
L["A player you blacklisted invited you to a group."] = true

-- UI/Widgets.lua
L["Classic"] = true
L["The game's own frames, as they are."] = true
L["Steel"] = true
L["Black and steel with cyan."] = true
L["Dark red iron with gold."] = true
L["Blue steel with gold."] = true
L["Nothing to show."] = true
