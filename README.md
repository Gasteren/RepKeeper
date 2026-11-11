# RepKeeper

A World of Warcraft addon for tracking player reputation, blacklists, and encounter history. Built for **Retail Midnight** and **WoW Forever**.

Stop forgetting which random pug ninja-looted, which key-leaver wrecked your Tuesday, or which DPS you'd actually want to run with again. RepKeeper remembers - across all your characters on the same Battle.net account.

## The window

Type <code>/rk</code> or click the minimap button. One window in the game's own style, with three tabs:

*   **Players** - everyone you rated or met. Search by name, tag, note or where you met them, and filter on Blacklist, Positive or Neutral. Pick a player to see everything about them on the right and change it on the spot: rate them with one click, add tags from the tag picker, write a note (it saves by itself), and add lines to their history.
*   **Groups** - the dungeons, raids and battlegrounds you ran and who was in them. Rate the players of a run right after it, with one click per player.
*   **Options** - every setting, grouped in pages, with a search box. Settings that only matter when another one is on show up under it when it is.

Pick a look under Options > General: **Classic** (the game's own frames), **Steel**, **Horde** or **Alliance**, and make the windows bigger or smaller with **UI size**.

## Features

*   **Per-player reputation** (Blacklist / Neutral / Positive)
*   **Tags** - pre-defined (Ninja Looter, Toxic, Key Leaver, Good Tank, etc.) plus your own custom tags
*   **Free-form notes** and a timestamped **history** per player
*   **Tooltip integration** - see rep, tags, and recent notes when you hover any player
*   **Right-click menu** - rate any player or write a note from their unit menu, including BNet friends
*   **Auto-detection** of group leavers, vote-kicks, and trade/duel/whisper spam, with an unobtrusive quick-add popup
*   **Group warnings** - when you join a party/raid/arena/BG with anyone you've blacklisted, or one of them invites you
*   **Auto-ignore / auto-decline** - optional automation for blacklisted players (group invites, guild invites, duels)
*   **LFG list filtering** - highlight or hide premade groups based on the leader's reputation
*   **Encounter history** - who you ran what content with and how it ended (timed/depleted/abandoned/left-early), on the Groups tab
*   **Battle.net alt detection** - characters that share a BNet account get linked automatically
*   **Guild sync** - share blacklists with trusted guildmates (opt-in, trust-tiered)
*   **Import/export** - compact shareable strings
*   **Periodic backups** with one-click restore
*   **Streamer mode** - anonymizes names in the UI when you're recording
*   **WoW Forever names** - first and last names ("Frost Paladin") work everywhere: adding, whispering, warnings

## Slash commands

| Command                         |Description                |
| ------------------------------- |-------------------------- |
| <code>/rk</code> or <code>/repkeeper</code> |Toggle the main window     |
| <code>/rk players</code> / <code>/rk groups</code> |Open the Players or Groups tab |
| <code>/rk options [page]</code> |Open the options (pages: general, alerts, tracking, detection, tooltip, automation, guild, data, help) |
| <code>/rk add Name-Realm [rep] [note]</code> |Add a player               |
| <code>/rk remove Name-Realm</code> |Remove a player            |
| <code>/rk note Name-Realm &lt;text&gt;</code> |Add a line to a player's history |
| <code>/rk tag Name-Realm &lt;tagID&gt;</code> |Toggle a tag               |
| <code>/rk export</code> / <code>/rk import</code> |Open import/export dialogs |
| <code>/rk backup</code>         |Create a manual backup     |
| <code>/rk help</code>           |List the commands          |

## Storage

Everything is **account-wide**. Your blacklist on one character is your blacklist on every character. Stored in `WoW\_retail_\WTF\Account&lt;acct&gt;\SavedVariables\RepKeeperDB.lua`.

## Privacy

*   Notes and timeline entries are **never sent over the wire** unless you explicitly enable note-sharing in Guild Sync (off by default)
*   Exports can be anonymized to strip notes, timeline, and BNet info
*   Streamer Mode hides character names in the UI