-- Modules/Tooltip.lua
-- Adds RepKeeper info lines to the player tooltip.
--
-- Taint-safety rules this module follows (do NOT regress these):
--   1. NEVER call tt:Show() from inside the data callback — the tooltip
--      system handles rendering itself. Calling Show() on a tainted secure
--      tooltip frame propagates taint everywhere.
--   2. NEVER mutate Database state from the callback. Enrichment (class,
--      faction, GUID) happens in UPDATE_MOUSEOVER_UNIT instead, which is
--      a non-secure event.
--   3. NEVER call tt:GetUnit() — use data.unit which is provided by the
--      modern TooltipDataProcessor API. GetUnit() reads from the secure
--      frame's state and taints the tooltip on PlayerFrame.
--   4. Bail early on any forbidden frame.

local addonName, ns = ...
local C = ns.Constants

local Tooltip = {}
ns.Tooltip = Tooltip

local Addon = ns.Addon

function Tooltip:Initialize()
    -- Always register the tooltip post-call. The setting toggles whether
    -- we render content, NOT whether we hook (because once hooked we can't
    -- unhook in this session anyway, and gating render lets the user toggle
    -- the feature without /reload).
    if TooltipDataProcessor and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Unit then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tt, data)
            self:OnTooltipSetUnit(tt, data)
        end)
    end

    -- Enrichment happens on mouseover, NOT in the tooltip callback. This is
    -- the key separation that prevents taint: we mutate state in a
    -- non-secure event handler, and the tooltip callback is read-only.
    Addon:RegisterEvent("UPDATE_MOUSEOVER_UNIT", function() self:OnMouseoverUnit() end)
end

-- Non-secure mouseover handler: enrich the player record with class/race/etc
-- This runs OUTSIDE the tooltip data context, so it cannot taint the tooltip.
function Tooltip:OnMouseoverUnit()
    if not UnitExists("mouseover") or not UnitIsPlayer("mouseover") then return end
    local key = ns.PlayerUtils:KeyFromUnit("mouseover")
    if not key then return end
    local rec = ns.db.global.players[key]
    if not rec then return end
    ns.Database:EnrichFromUnit(rec, "mouseover")
end

function Tooltip:OnTooltipSetUnit(tt, data)
    -- Comprehensive defensive checks. If anything is wrong, bail silently.
    if not tt then return end
    if tt.IsForbidden and tt:IsForbidden() then return end
    if not ns.db or not ns.db.global or not ns.db.global.settings then return end
    if not ns.db.global.settings.tooltipEnabled then return end

    -- Use data.unit when present. When it's missing (some world tooltips
    -- only populate data.guid), fall back to the "mouseover" unit token —
    -- which Blizzard set up before invoking us and which is always safe
    -- to read.
    --
    -- We deliberately NEVER touch data.guid. WoW marks NPC/creature/vehicle
    -- GUIDs as "secret" strings — even reading them taints execution. The
    -- mouseover token tells us whether it's a player without us having to
    -- look at the GUID at all.
    if not data then return end
    local unit = data.unit
    if not unit then
        if UnitExists("mouseover") and UnitIsPlayer("mouseover") then
            unit = "mouseover"
        else
            return
        end
    end

    if not UnitExists(unit) or not UnitIsPlayer(unit) then return end

    local key = ns.PlayerUtils:KeyFromUnit(unit)
    if not key then return end
    local rec = ns.db.global.players[key]
    if not rec then return end

    -- READ-ONLY render. No mutation, no Show().
    self:Render(tt, rec)
end

function Tooltip:GetRecordFromGUID(guid)
    -- Retained for any internal callers that already hold a player-realm key,
    -- but no longer used by the tooltip path. Safe-by-construction guard:
    -- bail unless it's clearly a Player- prefix coming from our OWN data
    -- (where strings are not secret).
    if not guid or type(guid) ~= "string" then return nil end
    if guid:sub(1, 7) ~= "Player-" then return nil end
    for _, rec in pairs(ns.db.global.players) do
        if rec.guid == guid then return rec end
    end
    return nil
end

function Tooltip:Render(tt, rec)
    -- Defensive: never try to render to a forbidden tooltip
    if tt.IsForbidden and tt:IsForbidden() then return end

    -- Idempotency via OnTooltipCleared. Blizzard fires that event whenever
    -- the tooltip is being prepared fresh (new hover, content refresh, etc).
    -- We hook it once per tooltip frame and use it to reset a "rendered"
    -- flag. Within a single render cycle the flag stays true and any
    -- duplicate fires bail.
    --
    -- This avoids the pitfalls of previous approaches:
    --   - FontString Lua fields don't reliably clear between hovers
    --   - Text scanning trips on stale text in recycled FontStrings
    --   - OnHide hooks don't fire reliably on every tooltip kind
    -- OnTooltipCleared is the Blizzard-blessed lifecycle event for "starting
    -- fresh", so it's the right hook.
    if not tt._rkClearedHooked then
        tt._rkClearedHooked = true
        tt:HookScript("OnTooltipCleared", function(self)
            self._rkRendered = false
        end)
    end

    if tt._rkRendered then return end
    tt._rkRendered = true

    local s = ns.db.global.settings

    if s.streamerMode then
        local r, g, b = ns.PlayerUtils:RepColor(rec.reputation or 0)
        if rec.reputation == C.REP.BLACKLIST then
            tt:AddLine("|cffff2222BLACKLISTED|r", 1, 0.15, 0.15)
        else
            tt:AddLine("|cffd0a070RepKeeper:|r " .. C.REP_NAMES[rec.reputation or 0], r, g, b)
        end
        -- NOTE: deliberately no tt:Show() — that's a taint vector.
        return
    end

    local r, g, b = ns.PlayerUtils:RepColor(rec.reputation or 0)
    tt:AddLine(" ")

    -- Make blacklist UNMISSABLE. Compact red banner before the normal info
    -- block so it's the first thing you see when hovering a player.
    if rec.reputation == C.REP.BLACKLIST then
        tt:AddLine("|cffff2222BLACKLISTED|r", 1, 0.15, 0.15)
        if rec.notes and rec.notes ~= "" then
            -- Surface the note immediately under the banner so the reason
            -- for the blacklist is visible without scrolling.
            tt:AddLine("|cffffaaaa" .. rec.notes .. "|r", 1, 0.7, 0.7, true)
        end
        tt:AddLine(" ")
    end

    -- Only show the "RepKeeper: <rep>" line when there's no banner above.
    -- For blacklisted players the big red BLACKLISTED banner already brands
    -- and conveys the reputation; an extra "RepKeeper | Blacklist" line is
    -- redundant. For other reputations there's no banner so we want it.
    if rec.reputation ~= C.REP.BLACKLIST then
        tt:AddDoubleLine("|cffd0a070RepKeeper|r", C.REP_NAMES[rec.reputation or 0], 0.82, 0.63, 0.44, r, g, b)
    end

    if s.tooltipShowTags and rec.tags and next(rec.tags) then
        local tagNames = {}
        for tagID in pairs(rec.tags) do
            local def = ns.Database:GetTagDef(tagID)
            if def then tagNames[#tagNames + 1] = def.name end
        end
        if #tagNames > 0 then
            table.sort(tagNames)
            tt:AddLine(ns.L["Tags"] .. ": |cffaaaaaa" .. table.concat(tagNames, ", ") .. "|r", 1, 1, 1, true)
        end
    end

    if s.tooltipShowNote then
        -- Skip the notes line if we already surfaced it in the blacklist
        -- banner above — no point repeating it.
        local alreadyShown = (rec.reputation == C.REP.BLACKLIST) and rec.notes and rec.notes ~= ""
        if rec.notes and rec.notes ~= "" and not alreadyShown then
            tt:AddLine(ns.L["Notes"] .. ": " .. rec.notes, 0.9, 0.9, 0.7, true)
        end
        -- Deliberately do NOT fall back to timeline entries here. The tooltip
        -- gets cluttered fast with auto-tracked dungeon entries; users who
        -- want the full timeline can open the editor.
    end

    if s.tooltipShowEncounters and rec.encounterCount and rec.encounterCount > 0 then
        tt:AddLine(string.format("%s: %d", ns.L["Encounters"], rec.encounterCount), 0.7, 0.85, 1)
    end

    if s.tooltipShowDateAdded then
        if rec.firstSeen and rec.firstSeen > 0 then
            tt:AddLine(string.format("%s: %s", ns.L["Date Added"],
                ns.PlayerUtils:RelativeTime(rec.firstSeen)), 0.6, 0.6, 0.6)
        end
    end

    if rec.bnetTag then
        tt:AddLine(ns.L["Battle.net"] .. ": " .. rec.bnetTag, 0.4, 0.7, 1.0)
    end

    if rec.altIDs and #rec.altIDs > 0 then
        local altCount = #rec.altIDs
        local first = rec.altIDs[1]
        local altRec = ns.db.global.players[first]
        local altLabel = altRec and (altRec.name .. "-" .. altRec.realm) or first
        if altCount == 1 then
            tt:AddLine(string.format("%s: %s", ns.L["Known Alts"], altLabel), 0.7, 0.7, 0.9)
        else
            tt:AddLine(string.format("%s: %s (+%d)", ns.L["Known Alts"], altLabel, altCount - 1), 0.7, 0.7, 0.9)
        end
    end

    -- NOTE: NEVER call tt:Show() here. The data callback runs as part of
    -- the tooltip's own update flow; the tooltip system shows itself.
end
