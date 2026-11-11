-- UI/Minimap.lua
-- LibDataBroker launcher + LibDBIcon minimap button.
--   Left-click  -> open or close RepKeeper
--   Right-click -> its Options tab
--   Tooltip     -> how many players you rated

local addonName, ns = ...
local L = LibStub("AceLocale-3.0"):GetLocale("RepKeeper")
local C = ns.Constants

local Minimap = {}
ns.Minimap = Minimap

local LDB = LibStub("LibDataBroker-1.1", true)
local LDBIcon = LibStub("LibDBIcon-1.0", true)

local dataObject

function Minimap:Initialize()
    if not LDB or not LDBIcon then
        return
    end

    dataObject = LDB:NewDataObject("RepKeeper", {
        type = "launcher",
        text = "RepKeeper",
        icon = "Interface\\Icons\\INV_Misc_Note_01",
        OnClick = function(_, button)
            if button == "RightButton" then
                if ns.UI and ns.UI.ShowOptions then
                    ns.UI.ShowOptions()
                end
            elseif ns.MainFrame then
                ns.MainFrame:Toggle()
            end
        end,
        OnTooltipShow = function(tt)
            local W, UI = ns.W, ns.UI
            local c = W and W.theme.title or { 1, 0.82, 0 }
            tt:AddLine(L["RepKeeper"], c[1], c[2], c[3])
            local total, black, positive = UI.Counts()
            local rb, gb, bb = ns.PlayerUtils:RepColor(C.REP.BLACKLIST)
            local rp, gp, bp = ns.PlayerUtils:RepColor(C.REP.POSITIVE)
            tt:AddDoubleLine(L["Players"], total, 1, 1, 1, 1, 1, 1)
            tt:AddDoubleLine(L["Blacklisted"], black, rb, gb, bb, rb, gb, bb)
            tt:AddDoubleLine(L["Positive"], positive, rp, gp, bp, rp, gp, bp)
            if ns.GuildSync and ns.S.guildSyncEnabled then
                local pending = ns.GuildSync:CountPending()
                if pending > 0 then
                    tt:AddDoubleLine(L["Guild suggestions"], pending, 0.25, 1, 0.25, 0.25, 1, 0.25)
                end
            end
            tt:AddLine(" ")
            tt:AddLine(L["Click to open RepKeeper. Right-click for options."], 0.62, 0.62, 0.62, true)
        end,
    })

    LDBIcon:Register("RepKeeper", dataObject, ns.S.minimapButton)
end

function Minimap:Refresh()
    if not LDBIcon then
        return
    end
    if ns.S.minimapButton.hide then
        LDBIcon:Hide("RepKeeper")
    else
        LDBIcon:Show("RepKeeper")
    end
end
