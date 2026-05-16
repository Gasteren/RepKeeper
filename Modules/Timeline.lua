-- Modules/Timeline.lua
-- Manages the timestamped log per player. Each entry is:
--   { ts = epoch, type = "manual" | "detection" | "system" | "encounter",
--     text = "...", detection = code or nil, encounterRef = id or nil }

local addonName, ns = ...

local Timeline = {}
ns.Timeline = Timeline

local MAX_ENTRIES_PER_PLAYER = 200  -- prevent unbounded growth

function Timeline:Initialize() end

function Timeline:Append(rec, entryType, text, extra)
    if not rec then return end
    rec.timeline = rec.timeline or {}
    local entry = {
        ts = time(),
        type = entryType or "manual",
        text = text or "",
    }
    if extra then
        for k, v in pairs(extra) do
            if k ~= "ts" and k ~= "type" and k ~= "text" then
                entry[k] = v
            end
        end
    end
    table.insert(rec.timeline, entry)

    -- Trim oldest if we're over the cap
    while #rec.timeline > MAX_ENTRIES_PER_PLAYER do
        table.remove(rec.timeline, 1)
    end

    ns.Database:Touch(rec)
    return entry
end

function Timeline:RemoveAt(rec, index)
    if not rec or not rec.timeline then return end
    if rec.timeline[index] then
        table.remove(rec.timeline, index)
        ns.Database:Touch(rec)
    end
end

function Timeline:Clear(rec)
    if not rec then return end
    rec.timeline = {}
    ns.Database:Touch(rec)
end

-- Format an entry as "[YYYY-MM-DD] text"
function Timeline:FormatEntry(entry)
    if not entry then return "" end
    local d = date("%Y-%m-%d", entry.ts)
    return string.format("[%s] %s", d, entry.text or "")
end
