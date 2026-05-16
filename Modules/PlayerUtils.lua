-- Modules/PlayerUtils.lua
-- Helpers for resolving player identities from various WoW APIs and formatting
-- them consistently.

local addonName, ns = ...
local C = ns.Constants

local PlayerUtils = {}
ns.PlayerUtils = PlayerUtils

function PlayerUtils:Initialize() end

-- Resolve a unit token (e.g. "target", "party2", "raid1") into a normalized key.
-- Returns key, name, realm, or nil if unit doesn't exist or isn't a player.
function PlayerUtils:KeyFromUnit(unit)
    if not unit or not UnitExists(unit) or not UnitIsPlayer(unit) then return nil end
    local name, realm = UnitName(unit)
    if not name then return nil end
    if not realm or realm == "" then
        realm = GetNormalizedRealmName and GetNormalizedRealmName() or GetRealmName()
    end
    if not realm then return nil end
    realm = realm:gsub("%s", "")
    return (name:lower() .. "-" .. realm:lower()), name, realm
end

-- Resolve from a chat sender string, which can be "Name" or "Name-Realm"
function PlayerUtils:KeyFromSender(sender)
    if not sender or sender == "" then return nil end
    if not sender:find("-") then
        local realm = GetNormalizedRealmName and GetNormalizedRealmName() or GetRealmName()
        if not realm then return nil end
        sender = sender .. "-" .. realm:gsub("%s", "")
    end
    return ns.Database:NormalizeKey(sender)
end

-- Color player name by class (returns a colorized string)
function PlayerUtils:ColorizeByClass(name, classFile)
    if not classFile or not RAID_CLASS_COLORS or not RAID_CLASS_COLORS[classFile] then
        return name
    end
    local c = RAID_CLASS_COLORS[classFile]
    return string.format("|cff%02x%02x%02x%s|r",
        math.floor(c.r * 255), math.floor(c.g * 255), math.floor(c.b * 255), name)
end

function PlayerUtils:RepColor(level)
    local c = C.REP_COLORS[level] or C.REP_COLORS[0]
    return c.r, c.g, c.b
end

-- Format a timestamp as a relative phrase ("today", "yesterday", "3d ago",
-- "2w ago", "5mo ago", "2y ago"). For values older than a year we round to
-- whole years. Returns "never" for nil/zero timestamps.
function PlayerUtils:RelativeTime(ts)
    if not ts or ts == 0 then return "never" end
    local now = time()
    local diff = now - ts
    if diff < 0 then diff = 0 end

    -- Same calendar day?
    local today = date("*t", now)
    local then_ = date("*t", ts)
    if today.year == then_.year and today.yday == then_.yday then
        return "today"
    end
    -- Yesterday?
    local yest = date("*t", now - 86400)
    if yest.year == then_.year and yest.yday == then_.yday then
        return "yesterday"
    end

    if diff < 7 * 86400 then
        return math.floor(diff / 86400) .. "d ago"
    elseif diff < 30 * 86400 then
        return math.floor(diff / (7 * 86400)) .. "w ago"
    elseif diff < 365 * 86400 then
        return math.floor(diff / (30 * 86400)) .. "mo ago"
    end
    return math.floor(diff / (365 * 86400)) .. "y ago"
end

function PlayerUtils:RepColorHex(level)
    local r, g, b = self:RepColor(level)
    return string.format("ff%02x%02x%02x",
        math.floor(r * 255), math.floor(g * 255), math.floor(b * 255))
end

-- "2 days ago" style relative time
function PlayerUtils:RelativeTime(epoch)
    if not epoch or epoch == 0 then return ns.L["never"] end
    local diff = time() - epoch
    if diff < 60 then return ns.L["just now"] end
    if diff < 3600 then return string.format(ns.L["%d minute(s) ago"], math.floor(diff / 60)) end
    if diff < 86400 then return string.format(ns.L["%d hour(s) ago"], math.floor(diff / 3600)) end
    if diff < 86400 * 30 then return string.format(ns.L["%d day(s) ago"], math.floor(diff / 86400)) end
    if diff < 86400 * 365 then return string.format(ns.L["%d month(s) ago"], math.floor(diff / (86400 * 30))) end
    return string.format(ns.L["%d year(s) ago"], math.floor(diff / (86400 * 365)))
end

-- For streamer mode: anonymize a name by hashing to "Player###"
function PlayerUtils:Anonymize(rec)
    if not rec then return "?" end
    -- Stable hash from normalizedKey so the same player always gets the same alias
    local hash = 0
    for i = 1, #rec.normalizedKey do
        hash = (hash * 31 + rec.normalizedKey:byte(i)) % 9999
    end
    return "Player" .. string.format("%04d", hash)
end

function PlayerUtils:DisplayName(rec, opts)
    if not rec then return "?" end
    opts = opts or {}
    if ns.db.global.settings.streamerMode and not opts.bypassStreamer then
        return self:Anonymize(rec)
    end
    local name = rec.name
    if opts.colorize and rec.class then
        name = self:ColorizeByClass(name, rec.class)
    end
    if opts.includeRealm ~= false then
        name = name .. "|cff888888-" .. rec.realm .. "|r"
    end
    return name
end
