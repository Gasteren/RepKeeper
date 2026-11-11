-- UI/Util.lua
-- Small helpers for the windows: colours, dates, class icons, sounds, a message bus between the parts of the UI,
-- and calls that report errors instead of stopping the caller.

local addonName, ns = ...
local L = LibStub("AceLocale-3.0"):GetLocale("RepKeeper")

local U = {}
ns.U = U

local floor, max, min, format = math.floor, math.max, math.min, string.format

ns.COLOR = {
    gold = "ffd100",
    white = "ffffff",
    grey = "9d9d9d",
    green = "40ff40",
    red = "ff5050",
    orange = "ff9a20",
    blue = "70b8ff",
}

function U.Color(hex, text)
    return "|cff" .. hex .. tostring(text) .. "|r"
end

local function report(err)
    local handler = geterrorhandler and geterrorhandler()
    if handler then
        handler(err)
    end
end

-- Runs fn; an error goes to the game's error handler (BugSack and friends) instead of stopping the caller.
function ns.SafeCall(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then
        report(err)
    end
    return ok, err
end

---------------------------------------------------------------------------
-- Messages between the parts of the UI ("SETTINGS_CHANGED", "THEME_CHANGED", ...)
---------------------------------------------------------------------------
local listeners = {}

function ns.On(message, fn)
    local list = listeners[message]
    if not list then
        list = {}
        listeners[message] = list
    end
    list[#list + 1] = fn
end

function ns.Fire(message, ...)
    local list = listeners[message]
    if not list then
        return
    end
    for i = 1, #list do
        ns.SafeCall(list[i], ...)
    end
end

-- Many requests for the same thing in a short time become one call.
local pending = {}
function ns.Debounce(key, delay, fn)
    if pending[key] then
        return
    end
    pending[key] = true
    C_Timer.After(delay, function()
        pending[key] = nil
        ns.SafeCall(fn)
    end)
end

---------------------------------------------------------------------------
-- Text
---------------------------------------------------------------------------
function U.Clamp(v, lo, hi)
    return max(lo, min(hi, v))
end

function U.Trim(s)
    return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Text without colour codes and icons.
function U.Plain(s)
    return (tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""))
end

function U.Number(n)
    n = floor((n or 0) + 0.5)
    if BreakUpLargeNumbers then
        return BreakUpLargeNumbers(n)
    end
    return tostring(n)
end

-- "1 player", "2 players": singular and plural are both full sentences for the translators.
function U.Count(n, one, many)
    return format(n == 1 and one or many, n)
end

---------------------------------------------------------------------------
-- Dates
---------------------------------------------------------------------------
-- 1 Oct 2026 (the day without a leading zero).
function U.Date(ts)
    return ts and (date(L["%d %b %Y"], ts):gsub("^0", "")) or ""
end

function U.DateTime(ts)
    return ts and (date(L["%d %b %Y, %H:%M"], ts):gsub("^0", "")) or ""
end

local function dayNumber(ts)
    local t = date("*t", ts)
    return floor(time({ year = t.year, month = t.month, day = t.day, hour = 12 }) / 86400)
end

-- Today, Yesterday, 4 days ago, 12 Oct 2026
function U.Ago(ts)
    if not ts or ts == 0 then
        return L["Never"]
    end
    local days = dayNumber(time()) - dayNumber(ts)
    if days <= 0 then
        return L["Today"]
    elseif days == 1 then
        return L["Yesterday"]
    elseif days < 7 then
        return format(L["%d days ago"], days)
    end
    return U.Date(ts)
end

-- 45 min, 1h 05m, 2d 4h
function U.Duration(seconds)
    seconds = max(0, floor((seconds or 0) + 0.5))
    local d, h, m = floor(seconds / 86400), floor(seconds % 86400 / 3600), floor(seconds % 3600 / 60)
    if d > 0 then
        return format(L["%dd %dh"], d, h)
    elseif h > 0 then
        return format(L["%dh %02dm"], h, m)
    end
    return format(L["%d min"], max(1, m))
end

---------------------------------------------------------------------------
-- Classes
---------------------------------------------------------------------------
function U.ClassRGB(classFile)
    local c = classFile and ((C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(classFile))
        or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]))
    if c then
        return c.r, c.g, c.b
    end
    return 0.8, 0.8, 0.8
end

U.CLASS_CIRCLES = "Interface\\TargetingFrame\\UI-Classes-Circles"

-- Texture coordinates of the class's round icon, or nil for an unknown class.
function U.ClassCoords(classFile)
    local c = classFile and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classFile]
    if c then
        return c[1], c[2], c[3], c[4]
    end
end

-- The class's round icon as a text escape (tooltips and lines of text).
function U.ClassIcon(classFile, size)
    local l, r, t, b = U.ClassCoords(classFile)
    if not l then
        return ""
    end
    size = size or 14
    return format("|T%s:%d:%d:0:0:256:256:%d:%d:%d:%d|t", U.CLASS_CIRCLES, size, size, l * 256, r * 256, t * 256, b * 256)
end

function U.ClassName(classFile)
    if not classFile then
        return nil
    end
    local names = LOCALIZED_CLASS_NAMES_MALE
    return names and names[classFile] or (classFile:sub(1, 1) .. classFile:sub(2):lower())
end

---------------------------------------------------------------------------
-- Game files and sounds
---------------------------------------------------------------------------
local texCache = {}
function U.TexExists(path)
    if texCache[path] == nil then
        local ok = true
        if GetFileIDFromPath then
            local success, id = pcall(GetFileIDFromPath, path)
            ok = success and id ~= nil and id ~= 0
        end
        texCache[path] = ok
    end
    return texCache[path]
end

function U.PlaySound(kitName, fallbackId)
    if not PlaySound then
        return
    end
    local id = (SOUNDKIT and SOUNDKIT[kitName]) or fallbackId
    if id then
        pcall(PlaySound, id)
    end
end
