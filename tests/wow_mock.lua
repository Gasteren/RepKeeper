-- wow_mock.lua: the game API RepKeeper and its libraries use, Blizzard's templates, the player and the people around
-- them (groups, instances, whispers), the chat windows, the unit menus and the settings window.
-- Globals provided by the runner: ROOT, MOCK_FLAVOR.
dofile(ROOT .. "/tests/mock_widgets.lua")

-- "midnight" (Retail 12.1.5) or "forever" (WoW Forever 1.60.1): both run the same modern client and interface code.
-- On Forever characters have a first and a last name: UnitName gives both (the last name where a realm would be), and
-- realm names are only for the servers.
MOCK.flavor = MOCK_FLAVOR or "midnight"
local FOREVER = MOCK.flavor == "forever"

local Widget, Methods = MOCK.Widget, MOCK.Methods

MOCK.api = {}
MOCK.apiRead = {}
MOCK.printed = {}
MOCK.chat = {}
MOCK.sounds = {}
MOCK.timers = {}
MOCK.errors = {}
MOCK.texturesUsed = {}
MOCK.atlasesUsed = {}
MOCK.whispers = {}
MOCK.addonMessages = {}
local api = MOCK.api

-- Time: GetTime() (seconds since the computer started) and the clock.
MOCK.now = 5000
MOCK.epoch = 1794300000 -- 2026-11-10
local START = MOCK.now
function MOCK.ServerTime()
	return MOCK.epoch + math.floor(MOCK.now - START)
end

-- Lua extras the game adds -----------------------------------------------------------------------------------------------
api.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
api.tinsert, api.tremove = table.insert, table.remove
api.strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
string.trim = api.strtrim
api.strsplit = function(sep, s, limit)
	local out, pos = {}, 1
	while true do
		local a, b = s:find(sep, pos, true)
		if not a or (limit and #out == limit - 1) then break end
		out[#out + 1] = s:sub(pos, a - 1)
		pos = b + 1
	end
	out[#out + 1] = s:sub(pos)
	return unpack(out)
end
api.time = function(t)
	if t then return os.time(t) end
	return MOCK.ServerTime()
end
api.date = function(fmt, t) return os.date(fmt, t or MOCK.ServerTime()) end
api.GetTime = function() return MOCK.now end
api.GetServerTime = function() return MOCK.ServerTime() end
api.debugprofilestop = function() return MOCK.now * 1000 end
api.GetFramerate = function() return 60 end
api.geterrorhandler = function()
	return function(err) table.insert(MOCK.errors, tostring(err)) end
end
-- Errors in the function go to the error handler; the caller goes on.
api.securecallfunction = function(fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then api.geterrorhandler()(err) end
end
api.issecurevariable = function() return false end
-- WoW's xpcall passes extra arguments on to the function (Lua 5.1's doesn't); AceAddon relies on it.
local xpcall51 = xpcall
xpcall = function(fn, handler, ...)
	local n = select("#", ...)
	if n == 0 then return xpcall51(fn, handler) end
	local args = { ... }
	return xpcall51(function() return fn(unpack(args, 1, n)) end, handler)
end
api.issecretvalue = function(v) return MOCK.secrets ~= nil and v ~= nil and MOCK.secrets[v] == true end
print = function(...)
	local parts = {}
	for i = 1, select("#", ...) do parts[#parts + 1] = tostring(select(i, ...)) end
	table.insert(MOCK.printed, table.concat(parts, " "))
end
api.Mixin = function(obj, ...)
	for i = 1, select("#", ...) do
		for k, v in pairs((select(i, ...))) do rawset(obj, k, v) end
	end
	return obj
end
api.BackdropTemplateMixin = MOCK.BackdropMixin
-- Post-hooks a function, like the game's: hooksecurefunc("Name", hook) or hooksecurefunc(table, "Name", hook).
api.hooksecurefunc = function(a, b, c)
	local tbl, name, hook = a, b, c
	if type(a) == "string" then
		tbl, name, hook = nil, a, b
	end
	local original
	if tbl then
		original = assert(tbl[name], "hooksecurefunc: no function " .. tostring(name))
	else
		original = assert(rawget(_G, name) or api[name], "hooksecurefunc: no global " .. tostring(name))
	end
	local wrapped = function(...)
		local results = { original(...) }
		hook(...)
		return unpack(results)
	end
	if tbl then
		tbl[name] = wrapped
	elseif rawget(_G, name) then
		rawset(_G, name, wrapped)
	else
		api[name] = wrapped
	end
end
api.C_Timer = {
	After = function(delay, fn)
		assert(type(delay) == "number" and type(fn) == "function", "C_Timer.After(delay, fn)")
		table.insert(MOCK.timers, { at = MOCK.now + delay, fn = fn })
	end,
}

-- Like the game after laying frames out: frames whose size changed get OnSizeChanged (lists make their rows then).
function MOCK.Layout()
	for _ = 1, 8 do
		local changed = false
		for _, f in ipairs(MOCK.frames) do
			local listens = f._scripts.OnSizeChanged or (f._hooks.OnSizeChanged and #f._hooks.OnSizeChanged > 0)
			if listens and Widget.Visible(f) then
				local r = Widget.Rect(f)
				if r then
					local s = Widget.Scale(f)
					local w, h = r.w / s, r.h / s
					local last = f._lastSize
					if not last or math.abs(last[1] - w) > 0.01 or math.abs(last[2] - h) > 0.01 then
						f._lastSize = { w, h }
						changed = true
						Widget.Fire(f, "OnSizeChanged", w, h)
					end
				end
			end
		end
		if not changed then
			return
		end
	end
end

-- Time passes: timers come due (each at its own time, so a timer started by a timer runs when it is due), frames are
-- laid out and the visible frames' OnUpdate scripts run (every `step` seconds).
function MOCK.Advance(seconds, step)
	seconds = seconds or 0
	step = step or math.max(seconds, 0.001)
	local target = MOCK.now + seconds
	local guard = 0
	repeat
		local start = MOCK.now
		local stepEnd = math.min(start + step, target)
		while true do
			local due, at
			for i, t in ipairs(MOCK.timers) do
				if t.at <= stepEnd and (not at or t.at < at) then due, at = i, t.at end
			end
			if not due then break end
			local t = table.remove(MOCK.timers, due)
			MOCK.now = math.max(MOCK.now, t.at)
			t.fn()
			guard = guard + 1
			assert(guard < 5000, "timer loop")
		end
		MOCK.now = stepEnd
		MOCK.Layout()
		local dt = stepEnd - start
		for _, f in ipairs(MOCK.frames) do
			local fn = f._scripts.OnUpdate
			if fn and Widget.Visible(f) then fn(f, dt) end
		end
	until MOCK.now >= target
end

-- Events in the order frames registered for them.
function MOCK.Fire(event, ...)
	assert(MOCK.KNOWN_EVENTS == nil or MOCK.KNOWN_EVENTS[event], "unknown event " .. tostring(event))
	for _, f in ipairs(MOCK.listeners) do
		if f._events[event] then
			Widget.Fire(f, "OnEvent", event, ...)
		end
	end
end

-- Textures, atlases, fonts -----------------------------------------------------------------------------------------------
local setTexture = Methods.Texture.SetTexture
Methods.Texture.SetTexture = function(self, file, ...)
	if type(file) == "string" and not MOCK.inTemplate and MOCK.FromAddon(3) then
		MOCK.texturesUsed[file] = true
	end
	return setTexture(self, file, ...)
end
MOCK.atlases = {
	["UI-LFG-ReadyMark"] = { width = 16, height = 16 },
	["UI-LFG-DeclineMark"] = { width = 16, height = 16 },
	["UI-LFG-PendingMark"] = { width = 16, height = 16 },
	["common-search-magnifyingglass"] = { width = 16, height = 16 },
	["common-search-clearbutton"] = { width = 16, height = 16 },
	["uiframe-tab-left"] = { width = 32, height = 32 }, ["_uiframe-tab-center"] = { width = 32, height = 32 },
	["uiframe-tab-right"] = { width = 32, height = 32 }, ["uiframe-activetab-left"] = { width = 32, height = 35 },
	["_uiframe-activetab-center"] = { width = 32, height = 35 }, ["uiframe-activetab-right"] = { width = 32, height = 35 },
}
local setAtlas = Methods.Texture.SetAtlas
Methods.Texture.SetAtlas = function(self, atlas, ...)
	if MOCK.FromAddon(3) then
		MOCK.atlasesUsed[atlas] = true
	end
	return setAtlas(self, atlas, ...)
end
-- Atlases written into text (|A:name:w:h|a) count too.
function MOCK.NoteTextAtlases(text)
	for atlas in tostring(text or ""):gmatch("|A:([^:|]+)") do
		assert(MOCK.atlases[atlas], "unknown atlas in text: " .. atlas)
		MOCK.atlasesUsed[atlas] = true
	end
end
local fsSetText = Methods.FontString.SetText
Methods.FontString.SetText = function(self, text)
	MOCK.NoteTextAtlases(text)
	return fsSetText(self, text)
end
api.C_Texture = {
	GetAtlasInfo = function(name)
		local a = MOCK.atlases[name]
		if a then return { width = a.width, height = a.height } end
	end,
}
MOCK.missingFiles = {}
api.GetFileIDFromPath = function(path)
	if MOCK.missingFiles[path] then return nil end
	return 1
end

local FONTS = {
	GameFontNormal = { 1, 0.82, 0 }, GameFontNormalSmall = { 1, 0.82, 0 }, GameFontNormalSmallLeft = { 1, 0.82, 0 },
	GameFontNormalLarge = { 1, 0.82, 0 }, GameFontNormalHuge = { 1, 0.82, 0 }, GameFontHighlight = { 1, 1, 1 },
	GameFontHighlightSmall = { 1, 1, 1 }, GameFontHighlightSmallLeft = { 1, 1, 1 }, GameFontHighlightLarge = { 1, 1, 1 },
	GameFontHighlightHuge = { 1, 1, 1 }, GameFontDisable = { 0.5, 0.5, 0.5 }, GameFontDisableSmall = { 0.5, 0.5, 0.5 },
	GameFontDisableSmallLeft = { 0.5, 0.5, 0.5 }, TextStatusBarText = { 1, 1, 1 }, ChatFontNormal = { 1, 1, 1 },
}
for name, c in pairs(FONTS) do
	api[name] = MOCK.NewFont(name, c[1], c[2], c[3])
end
api.CreateFont = function(name)
	local font = MOCK.NewFont(name)
	if name then rawset(_G, name, font) end
	return font
end

api.SOUNDKIT = { IG_MAINMENU_OPEN = 850, IG_MAINMENU_CLOSE = 851, IG_CHARACTER_INFO_TAB = 841,
	IG_MAINMENU_OPTION_CHECKBOX_ON = 856, IG_MAINMENU_OPTION_CHECKBOX_OFF = 857 }
api.PlaySound = function(id) table.insert(MOCK.sounds, id) end

api.C_AddOns = {
	GetAddOnMetadata = function(addon, field)
		local f = assert(io.open(ROOT .. "/" .. addon .. ".toc", "r"))
		local text = f:read("*a")
		f:close()
		return text:match("## " .. field .. ":%s*([^\r\n]-)%s*[\r\n]")
	end,
}
api.GetLocale = function() return "enUS" end
api.GetCurrentRegion = function() return 3 end
api.GetCurrentRegionName = function() return "EU" end
MOCK.loggedIn = false
api.IsLoggedIn = function() return MOCK.loggedIn end
MOCK.reloads = 0
api.ReloadUI = function() MOCK.reloads = MOCK.reloads + 1 end
MOCK.shift = false
api.IsShiftKeyDown = function() return MOCK.shift end
MOCK.cursor = { 600, 400 }
api.GetCursorPosition = function() return MOCK.cursor[1], MOCK.cursor[2] end

-- The game -----------------------------------------------------------------------------------------------------------------
api.WOW_PROJECT_MAINLINE = 1
api.WOW_PROJECT_ID = FOREVER and 23 or 1
if FOREVER then
	api.RegionalUniqueNamesEnabled = function() return true end
end
api.ERR_VOTE_KICK_PLAYER_S = "%s has been kicked from the group."

-- People: MOCK.units[unit] = { name, realm (nil: yours; the last name on Forever), class, race, sex, faction, guid }.
MOCK.realm = FOREVER and "CAMWOWEU5Realm5PvE" or "Lightbringer"
MOCK.units = {}
local guidCount = 0
function MOCK.Person(name, realm, class, opts)
	opts = opts or {}
	guidCount = guidCount + 1
	return {
		name = name, realm = realm, class = class or "WARRIOR", race = opts.race or "Human", sex = opts.sex or 2,
		faction = opts.faction or "Alliance", guid = opts.guid or ("Player-1-" .. string.format("%08X", guidCount)),
	}
end
MOCK.units.player = MOCK.Person("Frost", FOREVER and "Forever" or nil, "MAGE")

local CLASS_NAMES = { MAGE = "Mage", WARRIOR = "Warrior", PRIEST = "Priest", ROGUE = "Rogue", PALADIN = "Paladin",
	DRUID = "Druid", WARLOCK = "Warlock", HUNTER = "Hunter", SHAMAN = "Shaman" }
local function unit(u) return MOCK.units[u] end
api.UnitName = function(u)
	local p = unit(u)
	if p then return p.name, p.realm end
end
api.UnitExists = function(u) return unit(u) ~= nil end
api.UnitIsPlayer = function(u) return unit(u) ~= nil end
api.UnitIsUnit = function(a, b) return unit(a) ~= nil and unit(a) == unit(b) end
api.UnitClass = function(u)
	local p = unit(u)
	if p then return CLASS_NAMES[p.class] or p.class, p.class, 1 end
end
api.UnitRace = function(u)
	local p = unit(u)
	if p then return p.race, p.race, 1 end
end
api.UnitSex = function(u) local p = unit(u) return p and p.sex end
api.UnitFactionGroup = function(u)
	local p = unit(u)
	if p then return p.faction, p.faction end
end
api.UnitGUID = function(u) local p = unit(u) return p and p.guid end
api.GetPlayerInfoByGUID = function(guid)
	for _, p in pairs(MOCK.units) do
		if p.guid == guid then return CLASS_NAMES[p.class], p.class, p.race, p.race, p.sex, p.name, p.realm end
	end
end
api.GetRealmName = function() return MOCK.realm end
api.GetNormalizedRealmName = function() return MOCK.realm end
api.Ambiguate = function(name) return (name:gsub("%-" .. MOCK.realm .. "$", "")) end

-- Where the player is.
MOCK.zone, MOCK.subzone = "Elwynn Forest", "Goldshire"
api.GetRealZoneText = function() return MOCK.zone end
api.GetSubZoneText = function() return MOCK.subzone end
MOCK.instance = nil -- { name, type = "party"|"raid"|"pvp"|"arena" }
api.IsInInstance = function()
	if MOCK.instance then return true, MOCK.instance.type end
	return false, "none"
end
api.GetInstanceInfo = function()
	local i = MOCK.instance
	if i then return i.name, i.type, 1, "Normal", 5, 0, false, 1, 5 end
	return MOCK.zone, "none", 0, "", 0, 0, false, 0, 0
end
api.C_ChallengeMode = {
	GetActiveChallengeMapID = function() return MOCK.keystone and MOCK.keystone.mapID end,
	GetActiveKeystoneInfo = function() return MOCK.keystone and MOCK.keystone.level or 0, {}, false end,
	GetMapUIInfo = function(id) return MOCK.keystone and MOCK.keystone.name end,
	GetCompletionInfo = function() return MOCK.keystone and MOCK.keystone.mapID, MOCK.keystone and MOCK.keystone.level, 1800000, true end,
}

-- The group: party1..party4 (or raid1..raidN) besides the player.
MOCK.group = nil
api.IsInGroup = function() return MOCK.group ~= nil end
api.IsInRaid = function() return MOCK.group ~= nil and MOCK.group.raid == true end
api.GetNumGroupMembers = function() return MOCK.group and (#MOCK.group.members + 1) or 0 end
function MOCK.SetGroup(members, raid)
	for u in pairs(MOCK.units) do
		if u:find("^party") or u:find("^raid") then MOCK.units[u] = nil end
	end
	if not members then
		MOCK.group = nil
	else
		MOCK.group = { members = members, raid = raid }
		for i, p in ipairs(members) do
			MOCK.units[(raid and "raid" or "party") .. i] = p
		end
	end
	MOCK.Fire("GROUP_ROSTER_UPDATE")
end

api.IsInGuild = function() return false end
api.GetNumGuildMembers = function() return 0 end
api.GetGuildRosterInfo = function() end
api.BNGetNumFriends = function() return 0 end
api.C_BattleNet = {
	GetFriendAccountInfo = function() end,
	GetFriendNumGameAccounts = function() return 0 end,
	GetFriendGameAccountInfo = function() end,
	SendGameData = function() end,
}
api.C_FriendList = {
	IsIgnored = function() return false end,
	AddIgnore = function(name) MOCK.ignored = name end,
}
api.C_PartyInfo = {
	LeaveParty = function() MOCK.leftParty = true end,
}
api.C_ChatInfo = {
	RegisterAddonMessagePrefix = function() return true end,
	SendAddonMessage = function(...) table.insert(MOCK.addonMessages, { ... }) return 0 end,
	SendAddonMessageLogged = function() return 0 end,
	SendChatMessage = function() end,
}
api.ChatFrameUtil = {
	SendTell = function(name) table.insert(MOCK.whispers, name) end,
}

-- Tooltips (TooltipDataProcessor) and unit menus (Menu.ModifyMenu).
MOCK.tooltipCalls = {}
api.Enum = { TooltipDataType = { Unit = 2 } }
api.TooltipDataProcessor = {
	AddTooltipPostCall = function(kind, fn) table.insert(MOCK.tooltipCalls, { kind = kind, fn = fn }) end,
}
MOCK.menuMods = {}
api.Menu = {
	ModifyMenu = function(tag, fn)
		MOCK.menuMods[tag] = MOCK.menuMods[tag] or {}
		table.insert(MOCK.menuMods[tag], fn)
	end,
}

-- A unit menu as the game builds it, with the entries addons add: { kind, text, ... } (sub: a submenu).
local Description = {}
Description.__index = Description
local function NewDescription() return setmetatable({ entries = {} }, Description) end
function Description:CreateDivider() table.insert(self.entries, { kind = "divider" }) end
function Description:CreateTitle(text) table.insert(self.entries, { kind = "title", text = text }) end
function Description:CreateButton(text, fn)
	local sub = NewDescription()
	local e = { kind = "button", text = text, fn = fn, sub = sub }
	table.insert(self.entries, e)
	return sub
end
function Description:CreateRadio(text, isSelected, setSelected, data)
	local e = { kind = "radio", text = text, isSelected = isSelected, setSelected = setSelected, data = data }
	table.insert(self.entries, e)
	return NewDescription()
end
function MOCK.UnitMenu(tag, context)
	local root = NewDescription()
	for _, fn in ipairs(MOCK.menuMods[tag] or {}) do
		fn(nil, root, context)
	end
	return root
end
-- The entry whose text has `needle` in it (colour codes and icons removed).
function MOCK.MenuEntry(desc, needle)
	for _, e in ipairs(desc.entries) do
		if e.text and MOCK.Plain(e.text):find(needle, 1, true) then return e end
	end
end

-- Strings, classes, numbers ----------------------------------------------------------------------------------------------
api.LOCALIZED_CLASS_NAMES_MALE = CLASS_NAMES
api.RAID_CLASS_COLORS = {
	MAGE = { r = 0.25, g = 0.78, b = 0.92 }, WARRIOR = { r = 0.78, g = 0.61, b = 0.43 },
	PRIEST = { r = 1, g = 1, b = 1 }, ROGUE = { r = 1, g = 0.96, b = 0.41 }, PALADIN = { r = 0.96, g = 0.55, b = 0.73 },
	DRUID = { r = 1, g = 0.49, b = 0.04 }, WARLOCK = { r = 0.53, g = 0.53, b = 0.93 },
	HUNTER = { r = 0.67, g = 0.83, b = 0.45 }, SHAMAN = { r = 0, g = 0.44, b = 0.87 },
}
api.C_ClassColor = { GetClassColor = function(class) return api.RAID_CLASS_COLORS[class] end }
api.CLASS_ICON_TCOORDS = {
	WARRIOR = { 0, 0.25, 0, 0.25 }, MAGE = { 0.25, 0.49609375, 0, 0.25 }, ROGUE = { 0.49609375, 0.7421875, 0, 0.25 },
	DRUID = { 0.7421875, 0.98828125, 0, 0.25 }, HUNTER = { 0, 0.25, 0.25, 0.5 }, SHAMAN = { 0.25, 0.49609375, 0.25, 0.5 },
	PRIEST = { 0.49609375, 0.7421875, 0.25, 0.5 }, WARLOCK = { 0.7421875, 0.98828125, 0.25, 0.5 },
	PALADIN = { 0, 0.25, 0.5, 0.75 },
}
api.BreakUpLargeNumbers = function(n)
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	return out
end

-- Chat windows: what addons print shows in the first one.
Methods.ScrollingMessageFrame = setmetatable({}, { __index = Methods.Frame })
function Methods.ScrollingMessageFrame:AddMessage(text)
	table.insert(MOCK.chat, (MOCK.Plain(tostring(text))))
end
local chat = MOCK.Widget.NewFrame("Frame", "ChatFrame1", nil)
chat._kind = "ScrollingMessageFrame"
api.DEFAULT_CHAT_FRAME = chat
api.SlashCmdList = {}
api.hash_SlashCmdList = {}

-- Templates (what RepKeeper uses) ----------------------------------------------------------------------------------------
local Templates = MOCK.Templates
Templates.BackdropTemplate = function(f)
	api.Mixin(f, api.BackdropTemplateMixin)
end
Templates.UIPanelButtonTemplate = function(b)
	-- SecureUIPanelTemplates.xml (UIPanelButtonNoTooltipTemplate), identical in both games.
	local file = "Interface\\Buttons\\UI-Panel-Button-Up"
	b:SetSize(40, 22)
	b.Left = b:CreateTexture(nil, "BACKGROUND")
	b.Left:SetTexture(file)
	b.Left:SetTexCoord(0, 0.09375, 0, 0.6875)
	b.Left:SetPoint("TOPLEFT")
	b.Left:SetPoint("BOTTOMLEFT")
	b.Left:SetWidth(12)
	b.Right = b:CreateTexture(nil, "BACKGROUND")
	b.Right:SetTexture(file)
	b.Right:SetTexCoord(0.53125, 0.625, 0, 0.6875)
	b.Right:SetPoint("TOPRIGHT")
	b.Right:SetPoint("BOTTOMRIGHT")
	b.Right:SetWidth(12)
	b.Middle = b:CreateTexture(nil, "BACKGROUND")
	b.Middle:SetTexture(file)
	b.Middle:SetTexCoord(0.09375, 0.53125, 0, 0.6875)
	b.Middle:SetPoint("TOPLEFT", b.Left, "TOPRIGHT")
	b.Middle:SetPoint("BOTTOMRIGHT", b.Right, "BOTTOMLEFT")
	local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	fs:SetPoint("CENTER")
	b:SetFontString(fs)
	b.Text = fs
	b:SetNormalFontObject("GameFontNormal")
	b:SetHighlightFontObject("GameFontHighlight")
	b:SetDisabledFontObject("GameFontDisable")
	b:SetHighlightTexture("Interface\\Buttons\\UI-Panel-Button-Highlight", "ADD")
	b:GetHighlightTexture():SetTexCoord(0, 0.625, 0, 0.6875)
	b._template = "UIPanelButtonTemplate"
end
Templates.UIPanelCloseButton = function(b)
	b:SetSize(24, 24)
	b._template = "UIPanelCloseButton"
end
Templates.UICheckButtonTemplate = function(b)
	b:SetSize(32, 32)
	b:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
	b:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
	b:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
	b:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
	b:SetDisabledCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check-Disabled")
	b.Text = b:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	b.Text:SetPoint("LEFT", b, "RIGHT", -2, 0)
	b._template = "UICheckButtonTemplate"
end
local function ScrollBar(s)
	s:SetWidth(16)
	s.ScrollUpButton = CreateFrame("Button", nil, s)
	s.ScrollUpButton:SetSize(18, 16)
	s.ScrollUpButton:SetPoint("BOTTOM", s, "TOP")
	s.ScrollUpButton:SetNormalTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Up")
	s.ScrollUpButton:SetPushedTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Down")
	s.ScrollUpButton:SetDisabledTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Disabled")
	s.ScrollUpButton:SetHighlightTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Highlight", "ADD")
	s.ScrollDownButton = CreateFrame("Button", nil, s)
	s.ScrollDownButton:SetSize(18, 16)
	s.ScrollDownButton:SetPoint("TOP", s, "BOTTOM")
	s.ScrollDownButton:SetNormalTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up")
	s.ScrollDownButton:SetPushedTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Down")
	s.ScrollDownButton:SetDisabledTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Disabled")
	s.ScrollDownButton:SetHighlightTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Highlight", "ADD")
	s:SetThumbTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
	s:GetThumbTexture():SetSize(18, 24)
end
Templates.UIPanelScrollBarTemplate = function(s)
	ScrollBar(s)
	s:SetScript("OnValueChanged", function()
		error("UIPanelScrollBarTemplate's own OnValueChanged scrolls its parent, which must be a ScrollFrame")
	end)
end
Templates.UIPanelScrollFrameTemplate = function(sf)
	-- UIPanelTemplates.xml: a scroll bar right of the frame that scrolls it.
	local bar = CreateFrame("Slider", (sf:GetName() or "") .. "ScrollBar", sf)
	ScrollBar(bar)
	bar:SetPoint("TOPLEFT", sf, "TOPRIGHT", 6, -16)
	bar:SetPoint("BOTTOMLEFT", sf, "BOTTOMRIGHT", 6, 16)
	bar:SetMinMaxValues(0, 0)
	bar:SetScript("OnValueChanged", function(self, value) sf:SetVerticalScroll(value) end)
	sf.ScrollBar = bar
	sf:SetScript("OnMouseWheel", function(self, delta)
		local range = self:GetVerticalScrollRange()
		self:SetVerticalScroll(math.max(0, math.min(range, self:GetVerticalScroll() - delta * (bar.scrollStep or 20))))
	end)
end

-- UIParent, tooltip, the settings window ---------------------------------------------------------------------------------
UIParent = MOCK.Widget.NewFrame("Frame", "UIParent", nil)
UIParent._strata = "MEDIUM"
GameTooltip = CreateFrame("GameTooltip", "GameTooltip", UIParent)
GameTooltip:Hide()
GameTooltip._lines = {}

api.UISpecialFrames = {}
api.StaticPopupDialogs = {}
function MOCK.PressEscape()
	for _, name in ipairs(api.UISpecialFrames) do
		local f = rawget(_G, name)
		if f and f:IsShown() then f:Hide() end
	end
end
api.HideUIPanel = function(frame) frame:Hide() end
api.SettingsPanel = CreateFrame("Frame", nil, UIParent)
api.SettingsPanel:Hide()
MOCK.settings = {}
api.Settings = {
	RegisterCanvasLayoutCategory = function(panel, name)
		MOCK.settings.panel, MOCK.settings.name = panel, name
		MOCK.settings.category = { GetID = function() return 42 end }
		return MOCK.settings.category
	end,
	RegisterAddOnCategory = function(category) MOCK.settings.registered = category end,
	OpenToCategory = function(id) MOCK.settings.opened = id end,
}

-- Functions in namespaces (C_PartyInfo.LeaveParty, Settings.OpenToCategory, ...) RepKeeper reads are recorded as
-- "Namespace.Name" for the API check.
MOCK.fieldsRead = {}
local NAMESPACES = { Settings = true, Menu = true, ChatFrameUtil = true, TooltipDataProcessor = true, Enum = true }
for name, value in pairs(api) do
	if type(value) == "table" and rawget(value, "_kind") == nil and (name:find("^C_") or NAMESPACES[name]) then
		local real = value
		api[name] = setmetatable({}, {
			__index = function(_, key)
				if MOCK.FromAddon(3) then
					MOCK.fieldsRead[name .. "." .. tostring(key)] = true
				end
				return real[key]
			end,
			__newindex = function(_, key, v) real[key] = v end,
		})
	end
end
