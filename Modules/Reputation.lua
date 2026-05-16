-- Modules/Reputation.lua
-- Thin module exposing reputation-level operations and queries. Most heavy
-- lifting lives in Database; this exists so other modules / UI have a clean
-- API surface that's named for what they're doing.

local addonName, ns = ...
local C = ns.Constants

local Reputation = {}
ns.Reputation = Reputation

function Reputation:Initialize() end

function Reputation:Set(rec, level)
    ns.Database:SetReputation(rec, level)
end

function Reputation:Bump(rec, delta)
    if not rec then return end
    local cur = rec.reputation or 0
    local new = math.max(C.REP.BLACKLIST, math.min(C.REP.FAVORITE, cur + delta))
    ns.Database:SetReputation(rec, new)
end

function Reputation:IsBlacklisted(rec)
    return rec and rec.reputation and rec.reputation <= C.REP.BLACKLIST
end

function Reputation:IsNegative(rec)
    return rec and rec.reputation and rec.reputation < 0
end

function Reputation:IsFavorite(rec)
    return rec and rec.reputation and rec.reputation >= C.REP.FAVORITE
end

function Reputation:IsPositive(rec)
    return rec and rec.reputation and rec.reputation > 0
end

-- Reasoning string used in warning popups: "blacklisted (toxic, key leaver)"
function Reputation:WarningReason(rec)
    if not rec then return "" end
    local pieces = {}
    pieces[#pieces + 1] = C.REP_NAMES[rec.reputation or 0]
    -- Append up to 3 negative tags
    if rec.tags then
        local tagNames = {}
        for tagID in pairs(rec.tags) do
            local def = ns.Database:GetTagDef(tagID)
            if def and def.negative then
                tagNames[#tagNames + 1] = def.name
            end
        end
        if #tagNames > 0 then
            table.sort(tagNames)
            local shown = {}
            for i = 1, math.min(3, #tagNames) do shown[i] = tagNames[i] end
            pieces[#pieces + 1] = "(" .. table.concat(shown, ", ") .. ")"
        end
    end
    return table.concat(pieces, " ")
end
