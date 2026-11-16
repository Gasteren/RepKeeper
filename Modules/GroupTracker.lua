-- Modules/GroupTracker.lua
-- "Everyone I group with": the players of every party and raid you are in go on your list as Neutral, with a line in
-- their history saying where you grouped. One line for the group, and one more for each dungeon, raid or arena you go
-- into together, so travelling together doesn't fill their history. Battlegrounds are left out: the game fills those
-- teams, and they are big. Nobody is looked at during a fight; that waits until it's over.
--
-- The other two choices are "My dungeon groups" (EncounterHistory adds the players of a dungeon run when you go in)
-- and "Nobody". GetMode and SetMode keep the two settings behind the three choices in step.
--
-- It listens on a frame of its own: the addon object keeps one handler per event, and GROUP_ROSTER_UPDATE is the
-- group warning's there.

local addonName, ns = ...
local L = LibStub("AceLocale-3.0"):GetLocale("RepKeeper")

local GroupTracker = {}
ns.GroupTracker = GroupTracker

local frame = CreateFrame("Frame")
-- The players of the current group and the places they already have a line for: noted[key][place] = the line added
-- for this group (true when they already had one).
local noted = {}
local retrying = false
-- A /reload in the same group starts with nothing noted: a line for the same place from the last two hours is that
-- group's (outside, the zone in its text can be another one by then).
local SAME_GROUP_SECONDS = 2 * 3600

local function HasRecentLine(rec, place, text)
    local timeline = rec.timeline or {}
    local now = time()
    for i = #timeline, 1, -1 do
        local entry = timeline[i]
        if now - (entry.ts or 0) >= SAME_GROUP_SECONDS then
            return false
        end
        if entry.grouped == place or entry.text == text then
            return true
        end
    end
    return false
end

function GroupTracker:GetMode()
    local s = ns.S
    if s.autoTrackAllGroups then
        return "everyone"
    elseif s.autoTrackDungeonGroups then
        return "dungeons"
    end
    return "nobody"
end

-- "nobody", "dungeons" or "everyone" (which takes in the dungeon groups too).
function GroupTracker:SetMode(mode)
    local s = ns.S
    s.autoTrackAllGroups = mode == "everyone"
    s.autoTrackDungeonGroups = mode == "everyone" or mode == "dungeons"
end

-- Where you are: a dungeon, raid or arena is a place of its own; everywhere outside counts as one place (the zone
-- you were in names it).
local function currentPlace()
    local inInstance, kind = IsInInstance()
    if inInstance then
        local name = GetInstanceInfo()
        if name and name ~= "" then
            return name, name, kind
        end
    end
    local zone = GetRealZoneText()
    return "world", (zone and zone ~= "") and zone or nil, kind
end

-- Puts them on the list (Neutral, when they are new) with a line in their history. place: "world" or the instance's
-- name; where: the name in the line. Returns the line, when one was added.
function GroupTracker:Note(unit, name, realm, place, where)
    local rec, created = ns.Database:GetOrCreatePlayer(name .. "-" .. realm)
    if not rec then
        return
    end
    if created then
        rec.source = "auto_group"
    end
    ns.Database:EnrichFromUnit(rec, unit)
    local text = where and string.format(L["Grouped with in %s"], where) or L["Grouped with"]
    if HasRecentLine(rec, place, text) then
        return
    end
    return ns.Timeline:Append(rec, "system", text, { grouped = place })
end

function GroupTracker:Scan()
    if not IsInGroup() then
        wipe(noted)
        return
    end
    if not ns.S.autoTrackAllGroups then
        return
    end
    -- In a fight the game can keep names from addons: the group is looked at when it's over.
    if InCombatLockdown() then
        frame:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    local place, where, kind = currentPlace()
    if kind == "pvp" then
        return
    end
    -- A group the game made for you (the dungeon finder) gets its line in the dungeon, not where you queued.
    if place == "world" and not IsInGroup(LE_PARTY_CATEGORY_HOME) then
        return
    end
    local prefix = IsInRaid() and "raid" or "party"
    local unknown = false
    for i = 1, GetNumGroupMembers() or 0 do
        local unit = prefix .. i
        if UnitExists(unit) and UnitIsPlayer(unit) and not UnitIsUnit(unit, "player") then
            local name, realm = UnitName(unit)
            if issecretvalue and (issecretvalue(name) or issecretvalue(realm)) then
                -- Names the game keeps from addons (in some fights) can't be read: skipped.
            elseif not name or name == "" or name == UNKNOWNOBJECT then
                unknown = true
            else
                local key, first, last = ns.PlayerUtils:KeyFromUnit(unit)
                if key then
                    local places = noted[key]
                    if not places then
                        places = {}
                        noted[key] = places
                    end
                    if not places[place] then
                        places[place] = self:Note(unit, first, last, place, where) or true
                    end
                end
            end
        end
    end
    -- Someone who just joined is "Unknown" until the game has their name: a moment later they are looked at again.
    if unknown and not retrying then
        retrying = true
        C_Timer.After(2, function()
            retrying = false
            self:Scan()
        end)
    end
end

-- A Mythic+ key started: the dungeon's line gets the key's level, as My dungeon groups writes it. Only the lines added
-- for this group: an earlier run's line keeps its own key.
function GroupTracker:KeyStarted()
    local place, where = currentPlace()
    if not ns.S.autoTrackAllGroups or place == "world" or not where then
        return
    end
    local level = C_ChallengeMode and C_ChallengeMode.GetActiveKeystoneInfo and C_ChallengeMode.GetActiveKeystoneInfo()
    if type(level) ~= "number" or level <= 0 then
        return
    end
    local text = string.format(L["Grouped with in %s"], where .. " +" .. level)
    for _, places in pairs(noted) do
        local line = places[place]
        if type(line) == "table" then
            line.text = text
        end
    end
end

frame:SetScript("OnEvent", function(self, event)
    if event == "CHALLENGE_MODE_START" then
        GroupTracker:KeyStarted()
        return
    elseif event == "PLAYER_REGEN_ENABLED" then
        self:UnregisterEvent(event)
    end
    GroupTracker:Scan()
end)

function GroupTracker:Initialize()
    frame:RegisterEvent("GROUP_ROSTER_UPDATE")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    frame:RegisterEvent("CHALLENGE_MODE_START")
    -- Turned on while in a group: the group goes on the list right away.
    ns.On("SETTINGS_CHANGED", function()
        self:Scan()
    end)
end
