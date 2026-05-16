-- UI/Minimap.lua
-- LibDataBroker launcher + LibDBIcon minimap button.
--   Left-click  → toggle main window
--   Right-click → open settings
--   Tooltip     → quick stats summary

local addonName, ns = ...
local C = ns.Constants

local Minimap = {}
ns.Minimap = Minimap

local LDB = LibStub("LibDataBroker-1.1", true)
local LDBIcon = LibStub("LibDBIcon-1.0", true)

local dataObject

function Minimap:Initialize()
    if not LDB or not LDBIcon then return end

    dataObject = LDB:NewDataObject("RepKeeper", {
        type = "launcher",
        text = "RepKeeper",
        icon = "Interface\\Icons\\INV_Misc_Note_01",
        OnClick = function(_, button)
            if button == "LeftButton" then
                if ns.MainFrame then ns.MainFrame:Toggle() end
            elseif button == "RightButton" then
                if ns.Options then ns.Options:Open() end
            end
        end,
        OnTooltipShow = function(tt)
            tt:AddLine("|cffd0a070RepKeeper|r")
            local total = ns.Database:Count()
            local blacklisted, positives = 0, 0
            for _, rec in pairs(ns.db.global.players) do
                if rec.reputation == C.REP.BLACKLIST then blacklisted = blacklisted + 1 end
                if rec.reputation == C.REP.POSITIVE then positives = positives + 1 end
            end
            tt:AddDoubleLine("Players tracked", total, 1, 1, 1, 1, 1, 1)
            tt:AddDoubleLine("Blacklisted", blacklisted, 1, 0.4, 0.4, 1, 0.4, 0.4)
            tt:AddDoubleLine("Positive", positives, 0.4, 0.85, 0.4, 0.4, 0.85, 0.4)
            if ns.GuildSync and ns.db.global.settings.guildSyncEnabled then
                local pending = ns.GuildSync:CountPending()
                if pending > 0 then
                    tt:AddDoubleLine("Pending guild sync suggestions", pending,
                        1, 1, 0.6, 1, 1, 0.6)
                end
            end
            tt:AddLine(" ")
            tt:AddLine("|cff888888Left-click:|r toggle window")
            tt:AddLine("|cff888888Right-click:|r settings")
        end,
    })

    LDBIcon:Register("RepKeeper", dataObject, ns.db.global.settings.minimapButton)
end

function Minimap:Refresh()
    if not LDBIcon then return end
    if ns.db.global.settings.minimapButton.hide then
        LDBIcon:Hide("RepKeeper")
    else
        LDBIcon:Show("RepKeeper")
    end
end
