-- Modules/Backup.lua
-- Periodic snapshots of the player database to ns.db.global.backups[ts].
-- Snapshots are AceSerialized (no compression) so restore can read them
-- without LibDeflate. We cap to N snapshots and prune oldest first.

local addonName, ns = ...
local C = ns.Constants

local Backup = {}
ns.Backup = Backup

local AceSerializer = LibStub("AceSerializer-3.0")

function Backup:Initialize()
    -- Backups live in ns.db.global.backups; nothing to init beyond ensuring
    -- the table exists (handled by AceDB defaults)
end

function Backup:Snapshot()
    -- Snapshot contains players, customTags, bnetAccounts; not encounters
    -- (those are bulky and recoverable as gameplay continues)
    return AceSerializer:Serialize({
        schema = C.SCHEMA_VERSION,
        timestamp = time(),
        players = ns.db.global.players,
        customTags = ns.db.global.customTags,
        bnetAccounts = ns.db.global.bnetAccounts,
    })
end

function Backup:CreateBackup(reason)
    local ts = time()
    ns.db.global.backups[ts] = {
        kind = reason or "manual",
        data = self:Snapshot(),
    }
    ns.db.global.lastBackupTime = ts
    self:PruneOld()
    return ts
end

function Backup:PruneOld()
    local keep = ns.db.global.settings.autoBackupKeepCount or 5
    local timestamps = {}
    for ts in pairs(ns.db.global.backups) do timestamps[#timestamps + 1] = ts end
    table.sort(timestamps)
    while #timestamps > keep do
        ns.db.global.backups[timestamps[1]] = nil
        table.remove(timestamps, 1)
    end
end

function Backup:MaybeAutoBackup()
    if not ns.db.global.settings.autoBackupEnabled then return end
    local interval = (ns.db.global.settings.autoBackupInterval or 7) * 86400
    local last = ns.db.global.lastBackupTime or 0
    if (time() - last) >= interval then
        self:CreateBackup("auto")
        ns.Addon:Printf(ns.L["Backup created: %s"],
            date("%Y-%m-%d %H:%M:%S", time()))
    end
end

function Backup:ListBackups()
    local list = {}
    for ts, b in pairs(ns.db.global.backups) do
        list[#list + 1] = { timestamp = ts, kind = b.kind }
    end
    table.sort(list, function(a, b) return a.timestamp > b.timestamp end)
    return list
end

function Backup:Restore(ts)
    local b = ns.db.global.backups[ts]
    if not b or not b.data then return false, "no backup at that timestamp" end
    local ok, snapshot = AceSerializer:Deserialize(b.data)
    if not ok then return false, "corrupt backup" end
    if not snapshot.players then return false, "no players in backup" end

    -- Before restoring, snapshot the CURRENT state as a "pre-restore" backup
    -- so the user can undo if they panic.
    self:CreateBackup("pre-restore")

    ns.db.global.players = snapshot.players or {}
    ns.db.global.customTags = snapshot.customTags or {}
    ns.db.global.bnetAccounts = snapshot.bnetAccounts or {}

    -- Rebuild altID cross-links since BNet info may have been pruned
    for bnetID in pairs(ns.db.global.bnetAccounts) do
        ns.Database:RebuildAltsForBNet(bnetID)
    end

    if ns.MainFrame and ns.MainFrame.Refresh then ns.MainFrame:Refresh() end
    local count = 0
    for _ in pairs(ns.db.global.players) do count = count + 1 end
    return true, count
end

function Backup:DeleteBackup(ts)
    ns.db.global.backups[ts] = nil
end
