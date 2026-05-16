# RepKeeper

A World of Warcraft addon for tracking player reputation, blacklists, and encounter history. Built for **Retail Midnight**.

Stop forgetting which random pug ninja-looted, which key-leaver wrecked your Tuesday, or which DPS you'd actually want to run with again. RepKeeper remembers - across all your characters on the same Battle.net account.

## Features

*   **Per-player reputation** (Blacklist / Neutral / Positive / )
*   **Tags** - pre-defined (Ninja Looter, Toxic, Key Leaver, Good Tank, etc.) plus your own custom tags
*   **Free-form notes** and a timestamped **timeline** per player
*   **Tooltip integration** - see rep, tags, and recent notes when you hover any player
*   **Right-click menu** - add/blacklist/note any player from their unit menu, including BNet friends
*   **Auto-detection** of group leavers, vote-kicks, and trade/duel/whisper spam, with an unobtrusive quick-add popup
*   **Group warnings** - when you join a party/raid/arena/BG with anyone you've flagged
*   **Auto-ignore / auto-decline** - optional automation for blacklisted players (group invites, guild invites, duels)
*   **LFG list filtering** - highlight or hide premade groups based on the leader's reputation
*   **Encounter history** - passive log of who you ran what content with and how it ended (timed/depleted/abandoned/left-early)
*   **Battle.net alt detection** - characters that share a BNet account get linked automatically
*   **Guild sync** - share blacklists with trusted guildmates (opt-in, trust-tiered)
*   **Import/export** - compact shareable strings
*   **Periodic backups** with one-click restore
*   **Streamer mode** - anonymizes names in the UI when you're recording

## Slash commands

| Command                         |Description                |
| ------------------------------- |-------------------------- |
| <code>/rk</code> or <code>/repkeeper</code> |Toggle the main window     |
| <code>/rk add Name-Realm [rep] [note]</code> |Add a player               |
| <code>/rk remove Name-Realm</code> |Remove a player            |
| <code>/rk note Name-Realm &lt;text&gt;</code> |Add a timeline note        |
| <code>/rk tag Name-Realm &lt;tagID&gt;</code> |Toggle a tag               |
| <code>/rk export</code> / <code>/rk import</code> |Open import/export dialogs |
| <code>/rk backup</code>         |Create a manual backup     |
| <code>/rk config</code>         |Open settings              |

## Storage

Everything is **account-wide**. Your blacklist on one character is your blacklist on every character. Stored in `WoW\_retail_\WTF\Account&lt;acct&gt;\SavedVariables\RepKeeperDB.lua`.

## Privacy

*   Notes and timeline entries are **never sent over the wire** unless you explicitly enable note-sharing in Guild Sync (off by default)
*   Exports can be anonymized to strip notes, timeline, and BNet info
*   Streamer Mode hides character names in the UI