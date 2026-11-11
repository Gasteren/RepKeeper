-- harness.lua: the mock game, RepKeeper and its libraries loaded in .toc order, and a tiny test framework.
-- Globals provided by the runner: ROOT (repo root, forward slashes), MOCK_FLAVOR, KNOWN_EVENTS (or nil).
MOCK = {}
if KNOWN_EVENTS then
	MOCK.KNOWN_EVENTS = {}
	for _, event in ipairs(KNOWN_EVENTS) do MOCK.KNOWN_EVENTS[event] = true end
end

dofile(ROOT .. "/tests/wow_mock.lua")

ADDON_NAME = "RepKeeper"

-- Textures RepKeeper hands to buttons, sliders, bars and backdrops count as used too (the API check looks them up).
do
	local function Record(file)
		if type(file) == "string" and file ~= "" and not MOCK.inTemplate then
			MOCK.texturesUsed[file] = true
		end
	end
	local function Wrap(methods, name)
		local original = methods[name]
		methods[name] = function(self, file, ...)
			if MOCK.FromAddon(3) then Record(file) end
			return original(self, file, ...)
		end
	end
	local M = MOCK.Methods
	for _, name in ipairs({ "SetNormalTexture", "SetPushedTexture", "SetDisabledTexture", "SetHighlightTexture" }) do
		Wrap(M.Button, name)
	end
	Wrap(M.CheckButton, "SetCheckedTexture")
	Wrap(M.CheckButton, "SetDisabledCheckedTexture")
	Wrap(M.Slider, "SetThumbTexture")
	Wrap(M.StatusBar, "SetStatusBarTexture")
	local setBackdrop = MOCK.BackdropMixin.SetBackdrop
	MOCK.BackdropMixin.SetBackdrop = function(self, info)
		if MOCK.FromAddon(3) and info then
			Record(info.bgFile)
			Record(info.edgeFile)
		end
		return setBackdrop(self, info)
	end
end

-- The files the game loads, in .toc order, with the libraries' XML files opened up (<Script> and <Include>).
local function XmlFiles(path, out)
	local f = assert(io.open(ROOT .. "/" .. path, "r"), "missing " .. path)
	local text = f:read("*a")
	f:close()
	local dir = path:match("^(.*)/[^/]*$")
	for tag, file in text:gmatch('<(%a+)%s+file="([^"]+)"') do
		local full = (dir and dir .. "/" or "") .. file:gsub("\\", "/")
		if tag == "Script" then
			out[#out + 1] = full
		elseif tag == "Include" then
			XmlFiles(full, out)
		end
	end
end
function TocFiles()
	local files = {}
	local toc = assert(io.open(ROOT .. "/RepKeeper.toc", "r"))
	for line in toc:lines() do
		line = line:gsub("\r", ""):match("^%s*(.-)%s*$")
		if line ~= "" and not line:find("^#") then
			local path = line:gsub("\\", "/")
			if path:find("%.xml$") then
				XmlFiles(path, files)
			else
				files[#files + 1] = path
			end
		end
	end
	toc:close()
	return files
end

-- LibDBIcon draws the minimap button from the game's minimap; the tests keep what RepKeeper asked of it.
local function LibDBIconStandIn()
	local lib = LibStub:NewLibrary("LibDBIcon-1.0", 999)
	MOCK.minimapButtons = {}
	function lib:Register(name, object, db)
		assert(type(object) == "table" and type(db) == "table", "LibDBIcon:Register(name, object, db)")
		MOCK.minimapButtons[name] = { object = object, db = db, shown = not db.hide }
	end
	function lib:Show(name) MOCK.minimapButtons[name].shown = true end
	function lib:Hide(name) MOCK.minimapButtons[name].shown = false end
	function lib:IsRegistered(name) return MOCK.minimapButtons[name] ~= nil end
end

-- Starts the game: saved variables, the files, ADDON_LOADED, PLAYER_LOGIN, PLAYER_ENTERING_WORLD and `wait` seconds
-- (12: RepKeeper's start-up timers run within 8).
-- opts: { db = saved variables, wait = seconds, beforeLoad = function (another addon's turn, or a test's setup) }
function Boot(opts)
	opts = opts or {}
	rawset(_G, "RepKeeperDB", opts.db)
	if opts.beforeLoad then
		opts.beforeLoad()
	end
	local ns = {}
	rawset(_G, "NS", ns)
	for _, file in ipairs(TocFiles()) do
		if file:find("LibDBIcon%-1%.0%.lua$") then
			LibDBIconStandIn()
		else
			local chunk = assert(loadfile(ROOT .. "/" .. file))
			chunk(ADDON_NAME, ns)
		end
	end
	MOCK.Fire("ADDON_LOADED", "SomeOtherAddon")
	MOCK.Fire("ADDON_LOADED", ADDON_NAME)
	MOCK.loggedIn = true
	MOCK.Fire("PLAYER_LOGIN")
	MOCK.Fire("PLAYER_ENTERING_WORLD", true, false)
	MOCK.Advance(opts.wait or 12, 0.5)
	return ns
end

-- The game saves and the player logs out (PLAYER_LOGOUT), as before a /reload; returns the saved variables.
function Logout()
	MOCK.Fire("PLAYER_LOGOUT")
	return rawget(_G, "RepKeeperDB")
end

-- A /command typed in chat.
function Slash(text)
	local cmd, rest = text:match("^/(%S+)%s*(.-)$")
	for name, fn in pairs(SlashCmdList) do
		for i = 1, 9 do
			local alias = rawget(_G, "SLASH_" .. name .. i)
			if not alias then break end
			if alias:lower() == "/" .. cmd:lower() then
				return fn(rest)
			end
		end
	end
	error("no slash command /" .. cmd)
end

-- Tiny test framework ---------------------------------------------------------------------------------------------------
local tests = {}
-- T(name, fn) runs in both games; T(name, fn, "midnight") or T(name, fn, "forever") in that one only.
function T(name, fn, only)
	tests[#tests + 1] = { name = name, fn = fn, only = only }
end
function Eq(actual, expected, label)
	if actual ~= expected then
		error(("%s\n      expected: %s\n      actual:   %s"):format(label or "values differ", tostring(expected), tostring(actual)), 2)
	end
end
function Near(actual, expected, tolerance, label)
	if type(actual) ~= "number" or math.abs(actual - expected) > (tolerance or 1) then
		error(("%s\n      expected: %s (+-%s)\n      actual:   %s"):format(label or "values differ", tostring(expected), tostring(tolerance or 1), tostring(actual)), 2)
	end
end
function Ok(value, label)
	if not value then
		error(label or "expected a true value", 2)
	end
end
function Has(text, needle, label)
	if type(text) ~= "string" or not text:find(needle, 1, true) then
		error(("%s\n      missing: %s\n      in:      %s"):format(label or "substring missing", needle, tostring(text)), 2)
	end
end
function HasNot(text, needle, label)
	if type(text) == "string" and text:find(needle, 1, true) then
		error(("%s\n      unexpected: %s\n      in:         %s"):format(label or "unexpected substring", needle, text), 2)
	end
end
function Fire(frame, script, ...)
	MOCK.Widget.Fire(frame, script, ...)
end
-- Everything printed in chat since the last call, as one string.
local chatSeen = 0
function Chat()
	local lines = {}
	for i = chatSeen + 1, #MOCK.chat do
		lines[#lines + 1] = MOCK.chat[i]
	end
	chatSeen = #MOCK.chat
	return table.concat(lines, "\n")
end
-- Visible text of a font string, button or edit box (colour codes removed).
function Text(obj)
	return MOCK.Plain(obj:GetText() or "")
end
function Rect(region)
	return MOCK.Widget.Rect(region)
end
function Visible(obj)
	return obj ~= nil and MOCK.Widget.Visible(obj)
end
-- a lies inside b (with `slack` pixels to spare).
function Inside(a, b, slack)
	local ra, rb = Rect(a), Rect(b)
	if not ra or not rb then return false end
	slack = slack or 0
	return ra.l >= rb.l - slack and ra.b >= rb.b - slack and ra.l + ra.w <= rb.l + rb.w + slack and ra.b + ra.h <= rb.b + rb.h + slack
end

-- Finding things on screen ------------------------------------------------------------------------------------------------
-- Every frame and region under `root` (UIParent by default), depth first; only what's on screen unless `all`.
function Descendants(root, all)
	local out = {}
	local function walk(f)
		for _, r in ipairs(f._regions or {}) do
			if all or MOCK.Widget.Visible(r) then out[#out + 1] = r end
		end
		for _, child in ipairs(f._children or {}) do
			if child._parent == f and (all or child._shown) then
				out[#out + 1] = child
				walk(child)
			end
		end
	end
	walk(root or UIParent)
	return out
end
-- The text of a region if it shows one: font strings, buttons (their label) and edit boxes.
local function Shown(obj)
	local kind = rawget(obj, "_kind")
	if kind == "FontString" or kind == "EditBox" then
		return MOCK.Plain(obj:GetText() or "")
	end
end
-- All visible text under `root`, one piece per line.
function ScreenText(root)
	local lines = {}
	for _, obj in ipairs(Descendants(root)) do
		local text = Shown(obj)
		if text and text ~= "" then lines[#lines + 1] = text end
	end
	return table.concat(lines, "\n")
end
-- The visible font string whose text is `text` (or contains it when `partial`).
function FindText(text, root, partial)
	for _, obj in ipairs(Descendants(root)) do
		local shown = rawget(obj, "_kind") == "FontString" and Shown(obj)
		if shown and (shown == text or (partial and shown:find(text, 1, true))) then
			return obj
		end
	end
end
-- The visible button, check or other clickable frame labelled `label`: its own text, or a font string on it.
function FindButton(label, root, partial)
	for _, obj in ipairs(Descendants(root)) do
		local kind = rawget(obj, "_kind")
		if kind == "Button" or kind == "CheckButton" or (obj._isFrame and (obj._scripts.OnClick or obj._scripts.OnMouseUp or obj._scripts.OnMouseDown)) then
			for _, r in ipairs(obj._regions) do
				local shown = rawget(r, "_kind") == "FontString" and MOCK.Widget.Visible(r) and Shown(r)
				if shown and (shown == label or (partial and shown:find(label, 1, true))) then
					return obj
				end
			end
		end
	end
end
-- Clicks a frame like the player: the mouse moves there, GLOBAL_MOUSE_DOWN, mouse down, mouse up, then OnClick for
-- buttons.
function Click(frame, button)
	assert(frame, "Click: nothing to click")
	assert(MOCK.Widget.Visible(frame), "Click: " .. tostring(frame:GetName() or frame._kind) .. " isn't on screen")
	button = button or "LeftButton"
	MOCK.mouseOver = frame
	MOCK.Fire("GLOBAL_MOUSE_DOWN", button)
	if frame._enabled == false then return end
	Fire(frame, "OnMouseDown", button)
	Fire(frame, "OnMouseUp", button)
	if frame._kind == "Button" or frame._kind == "CheckButton" then
		frame:Click(button)
	end
end
-- Clicks the visible button labelled `label` (or whose label has it, like "Blacklist" next to its icon).
function Press(label, root, button)
	local b = FindButton(label, root) or FindButton(label, root, true)
	assert(b, "no button labelled " .. label .. " on screen\n" .. ScreenText(root))
	Click(b, button)
	return b
end
-- Moves the mouse over a frame; returns the tooltip's text.
function Hover(frame)
	MOCK.mouseOver = frame
	Fire(frame, "OnEnter")
	return GameTooltip:IsShown() and MOCK.TooltipText() or ""
end
function Unhover(frame)
	MOCK.mouseOver = nil
	Fire(frame, "OnLeave")
end
-- Clicks into an edit box and types.
function TypeInto(box, text, replace)
	box:SetFocus()
	if replace then box:HighlightText() end
	MOCK.Type(box, text)
end

-- Saved data like a player's who has used RepKeeper for a while (made-up names). Forever records keep the surname
-- where a realm would be, as RepKeeper 1.x saved them.
function Fixture()
	local now = MOCK.ServerTime()
	local day = 86400
	local forever = MOCK.flavor == "forever"
	local function rec(name, realm, class, rep, opts)
		opts = opts or {}
		local r = {
			name = name, realm = realm, normalizedKey = name:lower() .. "-" .. realm:lower(), class = class,
			race = opts.race or "Human", gender = 2, faction = opts.faction or "Alliance", reputation = rep,
			tags = opts.tags or {}, notes = opts.notes or "", timeline = opts.timeline or {}, altIDs = opts.altIDs or {},
			encounterCount = opts.encounters or 0, firstSeen = now - (opts.age or 10) * day,
			lastSeen = now - (opts.seen or 1) * day, firstSeenLocation = opts.where or "The Stonevault",
			addedBy = "Frost-" .. MOCK.realm, source = opts.source or "manual",
		}
		return r.normalizedKey, r
	end
	local players = {}
	local function add(...)
		local key, r = rec(...)
		players[key] = r
		return key
	end
	local realm = forever and "Ironhand" or "Ragnaros"
	local grim = add("Grimtusk", realm, "WARRIOR", -1, {
		tags = { ninja_looter = true, toxic = true }, notes = "Rolled need on everything, left after the last boss.",
		encounters = 2, age = 30, seen = 2, faction = "Horde", race = "Orc",
		timeline = {
			{ ts = now - 30 * day, type = "manual", text = "Needed on the cloth chest as a warrior." },
			{ ts = now - 2 * day, type = "detection", text = "Left the group mid-dungeon", detection = "left_group" },
		},
	})
	local luna = add("Lunashade", forever and "Starwhisper" or "Silvermoon", "PRIEST", 1, {
		tags = { good_healer = true, friendly = true }, notes = "Calm healer, happy to run keys again.", encounters = 3,
		age = 12, seen = 1,
	})
	add("Brakk", forever and "Stonefist" or "Ragnaros", "ROGUE", -1, { tags = { scammer = true }, age = 50, seen = 40 })
	add("Velia", forever and "Dawnsong" or "Kazzak", "PALADIN", 1, { age = 5, seen = 5 })
	local auto = {}
	local AUTO = { { "Thornby", "DRUID" }, { "Mirelle", "MAGE" }, { "Oskar", "HUNTER" }, { "Pell", "WARLOCK" },
		{ "Quill", "SHAMAN" }, { "Rusk", "WARRIOR" }, { "Sable", "PRIEST" }, { "Tamsin", "ROGUE" } }
	for i, p in ipairs(AUTO) do
		auto[#auto + 1] = add(p[1], forever and "Ashgrove" or "Draenor", p[2], 0, {
			source = "auto_group", encounters = 1, age = i, seen = i,
			timeline = { { ts = now - i * day, type = "system", text = "Grouped with in Darkflame Cleft" } },
		})
	end
	local wren = "wren-" .. (forever and "ashgrove" or "draenor") -- in a group, but not on the list
	local bjorn = "bj\195\182rn-" .. (forever and "eisenfaust" or "draenor") -- Björn: the key keeps the ö as it is
	local encounters = {
		[41] = { id = 41, type = 1, result = 1, timestamp = now - 2 * day, participants = { grim, luna, auto[1], auto[2], wren },
			extra = { instanceName = "The Stonevault", startTime = now - 2 * day - 1800, endTime = now - 2 * day,
				leftEarly = { [grim] = true } } },
		[42] = { id = 42, type = 2, result = 2, timestamp = now - day, participants = { luna, auto[3], auto[4], auto[5] },
			extra = { instanceName = "Ara-Kara, City of Echoes", keyLevel = 7, startTime = now - day - 1700, endTime = now - day } },
		[43] = { id = 43, type = 3, result = 7, timestamp = now - 3600, participants = { auto[6], auto[7], auto[8], bjorn },
			extra = { instanceName = "Liberation of Undermine", startTime = now - 7200, endTime = now - 3600 } },
	}
	return {
		global = {
			schemaVersion = 4,
			players = players,
			bnetAccounts = {},
			customTags = { slow_runner = { name = "Slow runner", tier = "negative", negative = true } },
			encounters = encounters,
			encounterCounter = 43,
			settings = { mainFrameScale = 1.0, timelineDateFormat = "relative", minimapButton = { hide = false } },
			backups = {},
			lastBackupTime = now - day,
		},
	}
end

function TestNames()
	local names = {}
	for _, t in ipairs(tests) do
		if not t.only or t.only == MOCK.flavor then
			names[#names + 1] = t.name
		end
	end
	return names
end

-- Runs one test (each test gets a fresh game). Returns ok, message.
function RunOne(name)
	for _, t in ipairs(tests) do
		if t.name == name then
			local ok, err = xpcall(t.fn, function(e) return debug.traceback(tostring(e), 2) end)
			if ok and #MOCK.errors > 0 then
				ok, err = false, "RepKeeper raised an error: " .. MOCK.errors[1]
			end
			if ok then
				for _, line in ipairs(MOCK.chat) do
					if line:find("[init error", 1, true) then
						ok, err = false, "chat shows an error: " .. line
						break
					end
				end
			end
			if ok then
				local missing, stray = {}, {}
				for k in pairs(MOCK.missingGlobals) do missing[#missing + 1] = tostring(k) end
				for k in pairs(MOCK.strayGlobals) do stray[#stray + 1] = tostring(k) end
				table.sort(missing)
				table.sort(stray)
				if #missing > 0 then
					ok, err = false, "read undefined globals: " .. table.concat(missing, ", ")
				elseif #stray > 0 then
					ok, err = false, "wrote globals: " .. table.concat(stray, ", ")
				end
			end
			return ok, err and tostring(err):gsub("[\128-\255]", "?") or nil
		end
	end
	return false, "no such test"
end

-- Names of everything the run touched, for the API check in run_tests.py.
function UsedApi()
	local function list(t)
		local out = {}
		for k in pairs(t) do out[#out + 1] = k end
		table.sort(out)
		return table.concat(out, "\n")
	end
	return list(MOCK.used), list(MOCK.apiRead), list(MOCK.templatesUsed), list(MOCK.texturesUsed), list(MOCK.atlasesUsed),
		list(MOCK.fieldsRead)
end

-- From here on, reading a global the game doesn't have (a typo) or writing one the addon doesn't own fails the test,
-- for RepKeeper's own files (the libraries are their authors' business). Game API reads are recorded for the API check.
local ADDON_GLOBALS = { RepKeeper = true, RepKeeperDB = true }
-- Saved variables are nil until the game loads them, and RepKeeper looks for these before it uses them (they exist in
-- one of the games only, or only in older clients).
local OPTIONAL = {
	RepKeeperDB = true, RegionalUniqueNamesEnabled = true, GetAddOnMetadata = true, ChatFrame_SendTell = true,
	LeaveParty = true,
}
MOCK.missingGlobals = {}
MOCK.strayGlobals = {}
setmetatable(_G, {
	__index = function(_, key)
		local api = MOCK.api[key]
		local fromAddon = MOCK.FromAddon(3)
		if api ~= nil then
			if fromAddon then MOCK.apiRead[key] = true end
			return api
		end
		if fromAddon and not OPTIONAL[key] then
			MOCK.missingGlobals[key] = true
		end
		return nil
	end,
	__newindex = function(t, key, value)
		if MOCK.FromAddon(3) and not ADDON_GLOBALS[key] then
			MOCK.strayGlobals[key] = true
		end
		rawset(t, key, value)
	end,
})
