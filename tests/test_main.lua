-- test_main.lua: RepKeeper as the player uses it, in both games (Midnight, and WoW Forever with first and last names).

local FOREVER = MOCK.flavor == "forever"

-- The players of Fixture(): their keys and how the windows show them (Forever: "First Last", the last name saved
-- where a realm would be; Midnight: Name-Realm).
local function player(first, realm, surname)
	local last = FOREVER and surname or realm
	return {
		key = first:lower() .. "-" .. last:lower(),
		name = FOREVER and (first .. " " .. surname) or (first .. "-" .. realm),
	}
end
local P = {
	grim = player("Grimtusk", "Ragnaros", "Ironhand"),
	luna = player("Lunashade", "Silvermoon", "Starwhisper"),
	brakk = player("Brakk", "Ragnaros", "Stonefist"),
	velia = player("Velia", "Kazzak", "Dawnsong"),
	thornby = player("Thornby", "Draenor", "Ashgrove"),
	mirelle = player("Mirelle", "Draenor", "Ashgrove"),
}

-- Helpers -------------------------------------------------------------------------------------------------------------
local function Start(db)
	local ns = Boot({ db = db or Fixture() })
	Chat()
	return ns
end

-- Opens the window (on a page) and lets it lay out.
local function Open(ns, page)
	ns.UI.Show(page)
	MOCK.Advance(0.2)
	return ns.UI.panels[page or ns.S.ui.tab]
end

-- The rows of a list that show someone or something.
local function Rows(list)
	local out = {}
	for _, row in ipairs(list.rows) do
		if row:IsShown() and row.item then
			out[#out + 1] = row
		end
	end
	return out
end
local function RowText(row)
	local parts = {}
	for _, fs in ipairs(row.cells) do
		parts[#parts + 1] = Text(fs)
	end
	return table.concat(parts, " | ")
end
local function FindRow(list, needle)
	local seen = {}
	for _, row in ipairs(Rows(list)) do
		local text = RowText(row)
		if text:find(needle, 1, true) then
			return row
		end
		seen[#seen + 1] = text
	end
	error("no row with " .. needle .. " in:\n      " .. table.concat(seen, "\n      "), 2)
end

-- The open menu (RepKeeper's own, shared by dropdowns and right-click menus).
local function MenuRows()
	local out = {}
	for _, r in ipairs(NS.W.Menu.rows) do
		if r:IsShown() and r.item and not r.item.separator then
			out[#out + 1] = r
		end
	end
	return out
end
local function MenuTexts()
	local out = {}
	for _, r in ipairs(MenuRows()) do
		out[#out + 1] = Text(r.text)
	end
	return out
end
local function MenuRow(needle)
	for _, r in ipairs(MenuRows()) do
		if Text(r.text):find(needle, 1, true) then
			return r
		end
	end
	error("no menu line with " .. needle .. " in: " .. table.concat(MenuTexts(), ", "), 2)
end
local function MenuClick(needle)
	Click(MenuRow(needle))
end
local function Checked(row)
	local c = row.item.checked
	if type(c) == "function" then
		return c(row.item)
	end
	return c
end

local function Players(ns)
	return ns.db.global.players
end

-- Everything on screen under `root` that sticks out of `bounds` (scrolling content is clipped by its scroll frame).
local function Outside(root, bounds, skip)
	local out = {}
	local function describe(obj)
		if obj._kind == "FontString" then
			return "text '" .. Text(obj) .. "'"
		end
		return obj._kind .. " " .. tostring(rawget(obj, "_texture") or rawget(obj, "_atlas") or obj._name or "")
	end
	local function check(obj)
		local r = Rect(obj)
		if r and r.w > 0 and r.h > 0 and not Inside(obj, bounds, 1) then
			out[#out + 1] = describe(obj)
		end
	end
	local function walk(f)
		for _, r in ipairs(f._regions or {}) do
			if MOCK.Widget.Visible(r) then
				check(r)
			end
		end
		for _, child in ipairs(f._children or {}) do
			if child._parent == f and child._shown and child ~= skip then
				check(child)
				if child._kind ~= "ScrollFrame" then
					walk(child)
				end
			end
		end
	end
	walk(root)
	return out
end

-- Buttons whose label is wider than the button (the red panel buttons have end caps of their own).
local function CutLabels(root)
	local out = {}
	for _, obj in ipairs(Descendants(root)) do
		local fs = obj._kind == "Button" and rawget(obj, "_fontString")
		if fs and MOCK.Widget.Visible(fs) and Text(fs) ~= "" then
			local r = Rect(obj)
			local caps = obj._template == "UIPanelButtonTemplate" and 16 or 0
			if r and fs:GetStringWidth() * MOCK.Widget.Scale(obj) > r.w - caps + 0.5 then
				out[#out + 1] = "'" .. Text(fs) .. "' in a button " .. math.floor(r.w) .. " wide"
			end
		end
	end
	return out
end

local function NoProblems(list, what)
	if #list > 0 then
		error(what .. ":\n      " .. table.concat(list, "\n      "), 2)
	end
end

-- Start -----------------------------------------------------------------------------------------------------------------
T("starts without errors on a fresh install", function()
	local ns = Boot()
	Has(Chat(), "loaded.")
	Ok(MOCK.minimapButtons.RepKeeper and MOCK.minimapButtons.RepKeeper.shown, "the minimap button")
	Eq(MOCK.settings.name, "RepKeeper", "a page in the game's settings")
	Ok(next(StaticPopupDialogs) == nil, "none of the game's pop-ups (they taint)")
	Slash("/rk")
	MOCK.Advance(0.2)
	local p = ns.UI.panels.players
	Ok(ns.UI.Frame():IsShown(), "/rk opens the window")
	Has(Text(p.details.empty), "No players yet.")
	Has(Text(p.details.empty), "Add player", "and says how to add one")
	Has(Text(ns.UI.Frame().status), "0 players")
	Press("Groups", ns.UI.Frame())
	MOCK.Advance(0.2)
	Has(Text(ns.UI.panels.groups.details.empty), "No groups yet.")
end)

T("a long-used database keeps its players and gains the new settings", function()
	local ns = Start()
	local g = ns.db.global
	local n = 0
	for _ in pairs(g.players) do n = n + 1 end
	Eq(n, 12, "every player is still there")
	Eq(g.settings.ui.theme, "classic", "the new window settings start with their defaults")
	Eq(g.players[P.grim.key].notes, "Rolled need on everything, left after the last boss.")
	Open(ns)
	Press("Groups", ns.UI.Frame())
	local db = Logout()
	Eq(db.global.settings.ui.tab, "groups", "the last tab is saved")
	Ok(db.global.players[P.grim.key], "players are saved")
end)

-- The window ------------------------------------------------------------------------------------------------------------
T("/rk opens the window on Players; the tabs switch pages; Esc closes it", function()
	local ns = Start()
	Slash("/rk")
	MOCK.Advance(0.2)
	local f = ns.UI.Frame()
	Ok(f:IsShown(), "the window is open")
	Has(Text(f.status), "12 players")
	Has(Text(f.status), "2 blacklisted")
	Has(Text(f.status), "2 positive")
	local p = ns.UI.panels.players
	local rows = Rows(p.list)
	Eq(#rows, 12, "everyone has a row")
	Has(RowText(rows[1]), P.grim.name, "blacklisted players come first")
	Has(RowText(rows[1]), "Blacklist")
	Has(RowText(rows[3]), P.luna.name, "then the ones you liked")
	Has(RowText(rows[5]), P.thornby.name, "then everyone else, last seen first")
	Eq(Text(p.details.name), P.grim.name, "the first one is picked")
	Has(Text(p.details.sub), "Orc Warrior")
	Has(Text(p.details.sub), "Horde")
	Has(Text(p.details.meta), "Met in The Stonevault")
	Has(Text(p.details.meta), "2 groups together")
	local tip = Hover(p.details.who)
	Has(tip, "You added them.")
	Has(tip, "First seen")

	Press("Groups", f)
	MOCK.Advance(0.2)
	Ok(ns.UI.panels.groups:IsShown(), "Groups")
	Ok(not p:IsShown(), "one page at a time")
	Eq(ns.S.ui.tab, "groups", "the tab is remembered")
	Press("Options", f)
	MOCK.Advance(0.2)
	Ok(ns.UI.panels.options:IsShown(), "Options")
	MOCK.PressEscape()
	Ok(not f:IsShown(), "Esc closes it")
	Slash("/rk")
	Ok(ns.UI.panels.options:IsShown(), "it opens on the tab it was left on")
	Slash("/rk")
	Ok(not f:IsShown(), "/rk again closes it")
end)

T("the rating filters and the search narrow the list", function()
	local ns = Start()
	local p = Open(ns, "players")
	Press("Blacklist 2", p)
	MOCK.Advance(0.1)
	Eq(#Rows(p.list), 2, "the blacklisted players")
	TypeInto(p.search, "healer")
	MOCK.Advance(0.3)
	Eq(#Rows(p.list), 0, "no blacklisted healer")
	Eq(Text(p.list.emptyText), "No players match.")
	Has(Text(p.details.empty), "No players match.")
	Press("All 1", p)
	MOCK.Advance(0.1)
	local rows = Rows(p.list)
	Eq(#rows, 1, "the search finds tags and notes")
	Has(RowText(rows[1]), P.luna.name)
	Eq(Text(p.details.name), P.luna.name, "and picks the match")
	MOCK.PressEscapeIn(p.search)
	MOCK.Advance(0.1)
	Eq(#Rows(p.list), 12, "Esc clears the search")
	Press("Positive 2", p)
	MOCK.Advance(0.1)
	Eq(Text(p.details.name), P.luna.name, "a filter picks one of the players it shows")
	Press("Neutral 8", p)
	MOCK.Advance(0.1)
	Eq(Text(p.details.name), P.thornby.name)
end)

-- A player ---------------------------------------------------------------------------------------------------------------
T("rate a player with one click; the list and the counts follow", function()
	local ns = Start()
	local p = Open(ns, "players")
	Click(FindRow(p.list, P.thornby.name))
	Eq(Text(p.details.name), P.thornby.name)
	local tip = Hover(FindButton("Positive", p.details.rating))
	Has(tip, "happily group with again")
	Press("Positive", p.details.rating)
	MOCK.Advance(0.1)
	Eq(Players(ns)[P.thornby.key].reputation, 1)
	Has(Text(ns.UI.Frame().status), "3 positive")
	Has(RowText(FindRow(p.list, P.thornby.name)), "Positive")
	Press("Blacklist", p.details.rating)
	MOCK.Advance(0.1)
	Eq(Players(ns)[P.thornby.key].reputation, -1)
	Has(Text(ns.UI.Frame().status), "3 blacklisted")
end)

T("tags: a picker with every tag, a click adds or removes one", function()
	local ns = Start()
	local p = Open(ns, "players")
	local d = p.details
	Click(FindRow(p.list, P.thornby.name))
	Eq(Text(d.addTag.text), "+ Add a tag", "a player without tags")
	Click(d.addTag)
	local picker = RepKeeperTagPicker
	Ok(picker:IsShown(), "the picker opens")
	Ok(Inside(picker, UIParent), "on the screen")
	local text = ScreenText(picker)
	Ok(text:find("Neutral tags", 1, true) < text:find("Negative tags", 1, true), "the kind that fits their rating first")
	Has(text, "Slow runner", "your own tags too")
	Has(text, "+ New tag...")
	Click(FindButton("Toxic", picker))
	Ok(picker:IsShown(), "it stays open for more")
	Click(FindButton("Key Leaver", picker))
	local rec = Players(ns)[P.thornby.key]
	Ok(rec.tags.toxic and rec.tags.key_leaver, "both tags are on")
	Ok(FindButton("Toxic", picker).picked, "a picked tag looks picked")
	Click(FindButton("Toxic", picker))
	Ok(not rec.tags.toxic, "a second click takes it off")
	Click(d)
	Ok(not picker:IsShown(), "a click elsewhere closes it")
	MOCK.Advance(0.1)
	Eq(Text(d.chips[1].text), "Key Leaver", "the tag shows on the player")
	Eq(Text(d.addTag.text), "+ Tag")
	Has(Hover(d.chips[1]), "Click to remove this tag.")
	Click(d.chips[1])
	MOCK.Advance(0.1)
	Ok(not rec.tags.key_leaver, "a click on it takes it off")
	Ok(not d.chips[1]:IsShown())
	Click(d.addTag)
	Click(FindRow(p.list, P.mirelle.name))
	Ok(not picker:IsShown(), "picking another player closes it")
end)

T("a tag of your own, made from the picker", function()
	local ns = Start()
	local p = Open(ns, "players")
	Click(FindRow(p.list, P.luna.name))
	Click(p.details.addTag)
	Click(FindButton("+ New tag...", RepKeeperTagPicker))
	local dlg = RepKeeperNewTag
	Ok(dlg:IsShown(), "the New tag window")
	Ok(not RepKeeperTagPicker:IsShown())
	Ok(dlg.name:HasFocus(), "the cursor is in the name box")
	Press("Create", dlg)
	Has(Text(dlg.status), "Give the tag a name first.")
	MOCK.Type(dlg.name, "Toxic")
	Press("Create", dlg)
	Has(Text(dlg.status), "There is already a tag with that name.")
	TypeInto(dlg.name, "Carried us", true)
	Eq(dlg.tier, "positive", "the kind follows the player's rating")
	Press("Create", dlg)
	Ok(not dlg:IsShown())
	local def = ns.db.global.customTags.carried_us
	Ok(def and def.name == "Carried us" and def.tier == "positive", "the tag is saved")
	Ok(Players(ns)[P.luna.key].tags.carried_us, "and put on the player")
	MOCK.Advance(0.1)
	Has(ScreenText(p.details.tagArea), "Carried us")
end)

T("the note is saved when you click away, for the player it was written for", function()
	local ns = Start()
	local p = Open(ns, "players")
	local d = p.details
	Click(FindRow(p.list, P.thornby.name))
	Ok(d.note.placeholder:IsShown(), "an empty note says what it is for")
	Click(d.note.scroll)
	Ok(d.note:HasFocus(), "a click in the note starts writing")
	MOCK.Type(d.note.edit, "Kept the group together.")
	Click(FindRow(p.list, P.mirelle.name))
	MOCK.Advance(0.1)
	Eq(Players(ns)[P.thornby.key].notes, "Kept the group together.", "saved for Thornby")
	Eq(Players(ns)[P.mirelle.key].notes, "", "not for the one picked next")
	Eq(d.note:GetText(), "", "Mirelle's note shows")

	Click(d.note.scroll)
	MOCK.Type(d.note.edit, "Line one")
	MOCK.shift = true
	MOCK.PressEnter(d.note.edit)
	MOCK.shift = false
	Ok(d.note:HasFocus(), "Shift+Enter starts a new line")
	MOCK.Type(d.note.edit, "Line two")
	MOCK.PressEnter(d.note.edit)
	Ok(not d.note:HasFocus(), "Enter saves")
	Eq(Players(ns)[P.mirelle.key].notes, "Line one\nLine two")
	Eq(Text(d.saved), "Saved")
	MOCK.Advance(2.5)
	Eq(Text(d.saved), "", "the Saved sign goes away")

	Click(d.note.scroll)
	MOCK.Type(d.note.edit, " and more")
	Press("Blacklist 2", p)
	MOCK.Advance(0.1)
	Eq(Players(ns)[P.mirelle.key].notes, "Line one\nLine two and more", "a filter that hides them saves it too")
	Eq(Text(d.name), P.grim.name)
	Eq(d.note:GetText(), Players(ns)[P.grim.key].notes)
end)

T("history: add a line with Enter, delete one with a right-click", function()
	local ns = Start()
	local p = Open(ns, "players")
	local d = p.details
	Click(FindRow(p.list, P.grim.name))
	Eq(#Rows(d.history), 2)
	Has(RowText(Rows(d.history)[1]), "Left the group mid-dungeon", "newest first")
	TypeInto(d.historyAdd, "Rolled need again")
	MOCK.PressEnter(d.historyAdd)
	MOCK.Advance(0.1)
	local rec = Players(ns)[P.grim.key]
	Eq(#rec.timeline, 3)
	Eq(rec.timeline[3].text, "Rolled need again")
	Eq(rec.timeline[3].type, "manual")
	Has(RowText(Rows(d.history)[1]), "Today")
	Has(RowText(Rows(d.history)[1]), "Rolled need again")
	Eq(d.historyAdd:GetText(), "", "the box is empty for the next line")
	Eq(Text(d.historyCount), "3")
	local tip = Hover(Rows(d.history)[2])
	Has(tip, "Left the group mid-dungeon")
	Has(tip, "Spotted by RepKeeper")
	Click(Rows(d.history)[2], "RightButton")
	MenuClick("Delete this entry")
	MOCK.Advance(0.1)
	Eq(#rec.timeline, 2)
	HasNot(ScreenText(d.history), "Left the group mid-dungeon")
end)

T("Add player: a name, a rating and a note", function()
	local ns = Start()
	local p = Open(ns, "players")
	Press("Add player", p)
	local add = RepKeeperAddPlayer
	Ok(add:IsShown())
	Ok(add.name:HasFocus(), "the cursor is in the name box")
	Has(Text(add.hint), "Add -Realm")
	Press("Add", add)
	Has(Text(add.status), "Type the player's name first.")
	MOCK.Type(add.name, "Kael-Draenor")
	Fire(add.name, "OnTabPressed")
	Ok(add.note:HasFocus(), "Tab goes to the note")
	MOCK.Type(add.note, "Great tank")
	Press("Positive", add.rating)
	MOCK.PressEnter(add.note)
	Ok(not add:IsShown(), "Enter adds them")
	local rec = Players(ns)["kael-draenor"]
	Ok(rec, "on the list")
	Eq(rec.reputation, 1)
	Eq(rec.notes, "Great tank")
	Eq(rec.source, "manual")
	Has(Chat(), "Player added: Kael-Draenor")
	MOCK.Advance(0.1)
	Eq(Text(p.details.name), "Kael-Draenor", "and picked")

	Press("Add player", p)
	MOCK.Type(add.name, "Grimtusk-Ragnaros")
	Press("Add", add)
	Eq(Players(ns)["grimtusk-ragnaros"].reputation, -1, "adding someone you have as Neutral keeps their rating")
	Has(Chat(), "Updated Grimtusk-Ragnaros")
end, "midnight")

T("Add player on WoW Forever: first and last name", function()
	local ns = Start()
	local p = Open(ns, "players")
	Press("Add player", p)
	local add = RepKeeperAddPlayer
	Has(Text(add.hint), "First and last name, like Frost Paladin.")
	MOCK.Type(add.name, "Mira Dawnbreak")
	Press("Blacklist", add.rating)
	Press("Add", add)
	local rec = Players(ns)["mira-dawnbreak"]
	Ok(rec, "saved like the game's units give it: name Mira, last name where the realm goes")
	Eq(rec.name, "Mira")
	Eq(rec.realm, "Dawnbreak")
	Eq(rec.reputation, -1)
	MOCK.Advance(0.1)
	Eq(Text(p.details.name), "Mira Dawnbreak")
	MOCK.SetGroup({ MOCK.Person("Mira", "Dawnbreak", "ROGUE") })
	Ok(RepKeeperWarning:IsShown(), "the group warning knows her")
	Has(ScreenText(RepKeeperWarning), "Mira Dawnbreak")
end, "forever")

T("Remove asks first; then someone else is picked", function()
	local ns = Start()
	local p = Open(ns, "players")
	Click(FindRow(p.list, P.brakk.name))
	Press("Remove", p.details)
	local confirm = RepKeeperConfirm
	Ok(confirm:IsShown(), "it asks")
	Has(Text(confirm.text), "Remove " .. P.brakk.name .. " from RepKeeper?")
	Press("Cancel", confirm)
	Ok(not confirm:IsShown())
	Ok(Players(ns)[P.brakk.key], "Cancel keeps them")
	Press("Remove", p.details)
	Press("Remove", confirm)
	MOCK.Advance(0.1)
	Eq(Players(ns)[P.brakk.key], nil, "removed")
	Has(Chat(), "Player removed: " .. P.brakk.name)
	Eq(#Rows(p.list), 11)
	Eq(Text(p.details.name), P.grim.name, "the first one left is picked")
end)

T("right-click a player in the list: their rating, whisper, remove", function()
	local ns = Start()
	local p = Open(ns, "players")
	Click(FindRow(p.list, P.velia.name), "RightButton")
	Ok(NS.W.Menu:IsShown(), "a menu")
	Eq(MenuTexts()[1], P.velia.name)
	Ok(Checked(MenuRow("Positive")), "their rating is ticked")
	Ok(not Checked(MenuRow("Neutral")))
	MenuClick("Blacklist")
	Ok(not NS.W.Menu:IsShown())
	Eq(Players(ns)[P.velia.key].reputation, -1)
	MOCK.Advance(0.1)
	Click(FindRow(p.list, P.velia.name), "RightButton")
	MenuClick("Whisper")
	Eq(MOCK.whispers[1], P.velia.name, "a whisper to them (First Last on Forever)")
	Click(FindRow(p.list, P.velia.name), "RightButton")
	Click(p.details)
	Ok(not NS.W.Menu:IsShown(), "a click elsewhere closes the menu")
	Click(FindRow(p.list, P.brakk.name), "RightButton")
	Click(FindRow(p.list, P.luna.name))
	Ok(not NS.W.Menu:IsShown(), "picking someone else in the list closes Brakk's menu")
	Eq(Text(p.details.name), P.luna.name)
	Click(FindRow(p.list, P.velia.name), "RightButton")
	MenuClick("Remove...")
	Ok(RepKeeperConfirm:IsShown(), "remove asks first")
end)

-- Groups -------------------------------------------------------------------------------------------------------------------
T("Groups: the runs, who was in them, and one-click ratings", function()
	local ns = Start()
	Slash("/rk groups")
	MOCK.Advance(0.2)
	local g = ns.UI.panels.groups
	local rows = Rows(g.list)
	Eq(#rows, 3)
	Has(RowText(rows[1]), "Liberation of Undermine", "newest first")
	Has(RowText(rows[1]), "Wiped")
	Has(RowText(rows[1]), "Today")
	Has(RowText(rows[2]), "Ara-Kara, City of Echoes +7")
	Has(RowText(rows[2]), "Timed")
	Eq(Text(g.details.title), "Liberation of Undermine", "the newest run is picked")
	Click(FindRow(g.list, "The Stonevault"))
	local d = g.details
	Eq(Text(d.title), "The Stonevault")
	Has(Text(d.sub), "Dungeon")
	Has(Text(d.sub), "Completed")
	Has(Text(d.meta), "30 min")
	Eq(#Rows(d.members), 5)
	Has(RowText(FindRow(d.members, "Grimtusk")), "(left)")
	Has(Hover(FindRow(d.members, "Grimtusk")), "Left the group before the run ended.")
	Has(Hover(FindRow(d.members, "Wren")), "Click to add them to your list")
	Has(RowText(FindRow(d.members, "Wren")), "Not on your list")
	Has(Hover(FindRow(d.members, "Wren").rate[3]), "Positive")
	Click(FindRow(d.members, "Wren").rate[3])
	MOCK.Advance(0.1)
	local rec = Players(ns)[FOREVER and "wren-ashgrove" or "wren-draenor"]
	Ok(rec, "rating someone from a run puts them on the list")
	Eq(rec.reputation, 1)
	Eq(rec.source, "auto_group")
	Eq(rec.firstSeenLocation, "The Stonevault", "where you met them")
	Has(RowText(FindRow(d.members, "Wren")), "Positive")
	Click(FindRow(d.members, "Mirelle").rate[1])
	MOCK.Advance(0.1)
	Eq(Players(ns)[P.mirelle.key].reputation, -1)
	Has(RowText(FindRow(d.members, "Mirelle")), "Blacklist")

	Click(FindRow(g.list, "Liberation of Undermine"))
	local bjorn = "Bj\195\182rn" -- Björn
	Has(RowText(FindRow(d.members, bjorn)), FOREVER and (bjorn .. " Eisenfaust") or bjorn, "a name with a letter like o-umlaut shows as the game writes it")
	Click(FindRow(d.members, bjorn).rate[1])
	MOCK.Advance(0.1)
	local brec = Players(ns)[FOREVER and "bj\195\182rn-eisenfaust" or "bj\195\182rn-draenor"]
	Ok(brec, "rated from the raid")
	Eq(brec.name, bjorn, "and saved that way")

	Click(FindRow(g.list, "The Stonevault"))
	Click(FindRow(d.members, "Lunashade"))
	MOCK.Advance(0.1)
	Ok(ns.UI.panels.players:IsShown(), "a click on a name opens them")
	Eq(Text(ns.UI.panels.players.details.name), P.luna.name)
end)

T("Groups: the filters", function()
	local ns = Start()
	local g = Open(ns, "groups")
	Press("Raids 1", g)
	MOCK.Advance(0.1)
	Eq(#Rows(g.list), 1)
	Eq(Text(g.details.title), "Liberation of Undermine")
	Press("Dungeons 2", g)
	MOCK.Advance(0.1)
	Eq(#Rows(g.list), 2)
	Eq(Text(g.details.title), "Ara-Kara, City of Echoes +7", "the run picked is one of those shown")
	Press("PvP 0", g)
	MOCK.Advance(0.1)
	Eq(Text(g.list.emptyText), "No runs of this kind yet.")
	Has(Text(g.details.empty), "No runs of this kind yet.")
end)

-- Options ---------------------------------------------------------------------------------------------------------------
T("Options: the search finds settings on every page", function()
	local ns = Start()
	local o = Open(ns, "options")
	Ok(o.pages.general:IsShown(), "General first")
	TypeInto(o.search, "kick")
	MOCK.Advance(0.3)
	local nav = ScreenText(o.nav)
	Has(nav, "Detection")
	HasNot(nav, "General")
	HasNot(nav, "Tooltip")
	Ok(o.pages.detection:IsShown(), "the page with the match")
	Ok(FindText("Vote kicks", o.box), "the matching setting")
	Ok(not FindText("Trade spam", o.box), "only that one")
	TypeInto(o.search, "zzzz", true)
	MOCK.Advance(0.3)
	Has(Text(o.noResults), "No settings match")
	MOCK.PressEscapeIn(o.search)
	MOCK.Advance(0.1)
	Has(ScreenText(o.nav), "General", "Esc shows every page again")
	Ok(FindText("Trade spam", o.box), "and every setting")
end)

T("Options: settings that depend on another show when it is on; some ask for a reload", function()
	local ns = Start()
	local o = Open(ns, "options")
	Press("Tracking", o.nav)
	Ok(o.pages.tracking:IsShown())
	Ok(not FindText("Not seen for", o.box), "the days only show when clean-up is on")
	Click(FindButton("Remove forgotten players", o.box))
	Ok(ns.S.autoPruneEnabled)
	Ok(FindText("Not seen for", o.box), "now they do")
	Ok(not o.reload:IsShown())
	Click(FindButton("Remember my groups", o.box))
	MOCK.Advance(0.1)
	Eq(ns.S.encounterHistoryEnabled, false)
	Ok(o.reload:IsShown(), "a reload is needed")
	Has(ScreenText(o.reload), "Some changes need a reload.")
	Press("Reload now", o.reload)
	Eq(MOCK.reloads, 1)
	Click(FindButton("Remember my groups", o.box))
	MOCK.Advance(0.1)
	Ok(not o.reload:IsShown(), "back as it was: no reload needed")
	Press("Alerts", o.nav)
	local sound = FindButton("Play a sound", o.box)
	Ok(sound:IsEnabled(), "the sound goes with the warning")
	Click(FindButton("Warn me when a blacklisted player is in my group", o.box))
	Ok(not sound:IsEnabled(), "greyed out when the warning is off")
end)

T("Options: the look and the size of the windows", function()
	local ns = Start()
	local o = Open(ns, "options")
	local f = ns.UI.Frame()
	local dd = FindText("Classic", o.box):GetParent()
	Click(dd.button)
	Eq(table.concat(MenuTexts(), ","), "Classic,Steel,Horde,Alliance")
	MenuClick("Steel")
	Eq(ns.S.ui.theme, "steel")
	Eq(Text(dd.text), "Steel")
	local slider = FindText("UI size", o.box):GetParent()
	MOCK.DragSlider(slider, 120)
	Near(f:GetScale(), 1.2, 0.001, "the window is bigger")
	Ok(Inside(f, UIParent), "and still on the screen")
	MOCK.DragSlider(slider, 150)
	Ok(f:GetScale() < 1.5, "never bigger than the screen holds")
	Ok(Inside(f, UIParent), "on the screen")
	local db = Logout()
	Eq(db.global.settings.ui.theme, "steel", "the look is saved")
end)

T("Options: Data: back up now, restore asks first", function()
	local ns = Start()
	local o = Open(ns, "options")
	Press("Data", o.nav)
	MOCK.Advance(0.1)
	local page = o.pages.data
	Eq(#Rows(page.backups), 0)
	Press("Back up now", o.box)
	Has(Chat(), "Backup created")
	Eq(#Rows(page.backups), 1)
	Has(RowText(Rows(page.backups)[1]), "By you")
	MOCK.Advance(5)
	ns.Database:RemovePlayer(P.brakk.key)
	Click(Rows(page.backups)[1])
	MenuClick("Restore this backup...")
	Ok(RepKeeperConfirm:IsShown(), "it asks first")
	Press("Restore", RepKeeperConfirm)
	Has(Chat(), "Restored a backup: 12 players.")
	Ok(Players(ns)[P.brakk.key], "the player is back")
	Eq(#Rows(page.backups), 2, "with a backup of how it was before")
end)

T("Options: Data: your tags, and deleting one", function()
	local ns = Start()
	Players(ns)[P.grim.key].tags.slow_runner = true
	local o = Open(ns, "options")
	Press("Data", o.nav)
	MOCK.Advance(0.1)
	local tags = o.pages.data.tags
	Has(RowText(Rows(tags)[1]), "Slow runner")
	Has(RowText(Rows(tags)[1]), "1")
	Click(Rows(tags)[1])
	MenuClick("Delete this tag...")
	Has(Text(RepKeeperConfirm.text), "It is taken off 1 players.")
	Press("Delete", RepKeeperConfirm)
	Eq(ns.db.global.customTags.slow_runner, nil)
	Eq(Players(ns)[P.grim.key].tags.slow_runner, nil)
	Eq(#Rows(tags), 0)
end)

T("export and import: a list goes out and comes back", function()
	local ns = Start()
	local o = Open(ns, "options")
	Press("Data", o.nav)
	MOCK.Advance(0.1)
	Press("Export...", o.box)
	local export = RepKeeperExport
	Ok(export:IsShown())
	Has(Text(export.status), "12 players")
	local full = export.box:GetText()
	Ok(#full > 100, "the list as text")
	Click(FindButton("Blacklist only", export))
	Has(Text(export.status), "2 players")
	Click(FindButton("Blacklist only", export))
	Press("Close", export)
	ns.Database:RemovePlayer(P.brakk.key)
	Press("Import...", o.box)
	local import = RepKeeperImport
	Ok(import:IsShown())
	Ok(import.box:HasFocus(), "ready to paste")
	MOCK.Type(import.box.edit, "not an export")
	Press("Import", import)
	Has(Text(import.status), "isn't a RepKeeper export")
	TypeInto(import.box.edit, full, true)
	Press("Import", import)
	Has(Text(import.status), "Imported: 1 new, 11 updated, 0 skipped.")
	local rec = Players(ns)[P.brakk.key]
	Ok(rec, "the removed player is back")
	Eq(rec.reputation, -1)
	Ok(rec.tags.scammer)
end)

-- Pop-ups -------------------------------------------------------------------------------------------------------------------
T("the pop-up when someone spams you: rate them on the spot, or it goes away", function()
	local ns = Start()
	local sender = FOREVER and "Spammy Sneak-CAMWOWEU5Realm5PvE" or "Spammy-Draenor"
	for _ = 1, 5 do
		MOCK.Fire("CHAT_MSG_WHISPER", "buy gold", sender)
	end
	local q = RepKeeperQuickAdd
	Ok(q:IsShown(), "the pop-up")
	Has(Text(q.text), (FOREVER and "Spammy Sneak" or "Spammy-Draenor") .. " spammed whispers.")
	Press("Blacklist", q)
	Ok(not q:IsShown())
	local key = FOREVER and "spammy sneak-camwoweu5realm5pve" or "spammy-draenor"
	Eq(Players(ns)[key].reputation, -1)
	Has(Chat(), "is now Blacklist.")

	for _ = 1, 3 do
		MOCK.Fire("TRADE_REQUEST", FOREVER and "Tradey Pest-CAMWOWEU5Realm5PvE" or "Tradey-Draenor")
	end
	Ok(q:IsShown(), "the pop-up again")
	Has(Text(q.text), "spammed trade requests.")
	MOCK.mouseOver = q
	MOCK.Advance(30, 0.5)
	Ok(q:IsShown(), "it waits while the mouse is on it")
	MOCK.mouseOver = nil
	MOCK.Advance(8, 0.5)
	Ok(q:IsShown())
	Ok(q.bar:GetValue() < 0.5, "the bar shows the time running out")
	MOCK.Advance(8, 0.5)
	Ok(not q:IsShown(), "then it goes away")
end)

T("the warning when a blacklisted player is in your group", function()
	local ns = Start()
	MOCK.SetGroup({
		MOCK.Person("Grimtusk", FOREVER and "Ironhand" or "Ragnaros", "WARRIOR"),
		MOCK.Person("Velia", FOREVER and "Dawnsong" or "Kazzak", "PALADIN"),
	})
	local w = RepKeeperWarning
	Ok(w:IsShown(), "the warning")
	local text = ScreenText(w)
	Has(text, "A player you blacklisted is in your group.")
	Has(text, P.grim.name)
	Has(text, "Blacklist: Ninja Looter, Toxic")
	Has(text, "Rolled need on everything")
	HasNot(text, "Velia", "only the blacklisted one")
	Ok(MOCK.sounds[#MOCK.sounds] == 8959, "with the raid warning sound")
	Click(w.rows[1])
	Ok(ns.UI.Frame():IsShown(), "a click on them opens RepKeeper")
	MOCK.Advance(0.1)
	Eq(Text(ns.UI.panels.players.details.name), P.grim.name)
	MOCK.SetGroup({
		MOCK.Person("Grimtusk", FOREVER and "Ironhand" or "Ragnaros", "WARRIOR"),
		MOCK.Person("Brakk", FOREVER and "Stonefist" or "Ragnaros", "ROGUE"),
	})
	Ok(w:IsShown())
	Has(ScreenText(w), "2 players you blacklisted are in your group.")
	Press("Leave Group", w)
	Ok(MOCK.leftParty, "Leave Group leaves")
	Ok(not w:IsShown())
end)

T("the warning when a blacklisted player invites you goes away by itself", function()
	Start()
	MOCK.Fire("PARTY_INVITE_REQUEST", "Brakk-Ragnaros")
	local w = RepKeeperWarning
	Ok(w:IsShown())
	Has(ScreenText(w), "A player you blacklisted invited you to a group.")
	Ok(not FindButton("Leave Group", w), "no Leave Group: you aren't in their group")
	MOCK.mouseOver = w
	MOCK.Advance(20, 0.5)
	Ok(w:IsShown(), "not while the mouse is on it")
	MOCK.mouseOver = nil
	MOCK.Advance(1)
	Ok(not w:IsShown(), "after 15 seconds")
end, "midnight")

-- In the game ---------------------------------------------------------------------------------------------------------------
T("right-click a player in the game: rate them, open them, write a note", function()
	local ns = Start()
	MOCK.units.target = MOCK.Person("Velia", FOREVER and "Dawnsong" or "Kazzak", "PALADIN")
	local root = MOCK.UnitMenu("MENU_UNIT_PLAYER", { unit = "target", name = "Velia" })
	local rk = MOCK.MenuEntry(root, "RepKeeper")
	Ok(rk, "a RepKeeper entry")
	local sub = rk.sub
	Ok(MOCK.MenuEntry(sub, "Positive").isSelected(), "their rating is picked")
	MOCK.MenuEntry(sub, "Blacklist").setSelected()
	Eq(Players(ns)[P.velia.key].reputation, -1)
	MOCK.MenuEntry(sub, "Write a note...").fn()
	MOCK.Advance(0.1)
	local p = ns.UI.panels.players
	Ok(ns.UI.Frame():IsShown(), "RepKeeper opens")
	Eq(Text(p.details.name), P.velia.name)
	Ok(p.details.note:HasFocus(), "ready to write")

	MOCK.units.target = MOCK.Person("Stranger", FOREVER and "Danger" or "Draenor", "MAGE")
	local strangerKey = FOREVER and "stranger-danger" or "stranger-draenor"
	root = MOCK.UnitMenu("MENU_UNIT_PLAYER", { unit = "target", name = "Stranger" })
	sub = MOCK.MenuEntry(root, "RepKeeper").sub
	Ok(MOCK.MenuEntry(sub, "Neutral").isSelected(), "someone new is Neutral")
	MOCK.MenuEntry(sub, "Neutral").setSelected()
	Eq(Players(ns)[strangerKey], nil, "Neutral for someone new adds nobody")
	MOCK.MenuEntry(sub, "Blacklist").setSelected()
	Eq(Players(ns)[strangerKey].reputation, -1)

	MOCK.units.target = MOCK.units.player
	root = MOCK.UnitMenu("MENU_UNIT_PLAYER", { unit = "target", name = "Frost" })
	Eq(MOCK.MenuEntry(root, "RepKeeper"), nil, "nothing on yourself")
end)

T("the minimap button and the page in the game's settings", function()
	local ns = Start()
	local button = MOCK.minimapButtons.RepKeeper.object
	button.OnClick(nil, "LeftButton")
	Ok(ns.UI.Frame():IsShown(), "left-click opens RepKeeper")
	button.OnClick(nil, "LeftButton")
	Ok(not ns.UI.Frame():IsShown(), "and closes it")
	button.OnClick(nil, "RightButton")
	Ok(ns.UI.panels.options:IsShown(), "right-click opens the options")
	GameTooltip:ClearLines()
	button.OnTooltipShow(GameTooltip)
	local tip = MOCK.TooltipText()
	Has(tip, "Players | 12")
	Has(tip, "Blacklisted | 2")

	ns.UI.Hide()
	SettingsPanel:Show()
	local page = MOCK.settings.panel
	page:Show()
	Click(FindButton("Show the minimap button", page))
	Ok(ns.S.minimapButton.hide, "the minimap button can be hidden there")
	Ok(not MOCK.minimapButtons.RepKeeper.shown)
	Press("Open RepKeeper", page)
	Ok(not SettingsPanel:IsShown(), "the game's settings close")
	Ok(ns.UI.Frame():IsShown(), "RepKeeper opens")
end)

T("streamer mode hides names", function()
	local ns = Start()
	local o = Open(ns, "options")
	Click(FindButton("Streamer mode", o.box))
	Ok(ns.S.streamerMode)
	MOCK.Advance(0.1)
	local state = ns.UI.Frame().state
	Ok(state:IsShown(), "the window says so")
	Has(Text(state.text), "Streamer mode")
	Press("Players", ns.UI.Frame())
	MOCK.Advance(0.1)
	local p = ns.UI.panels.players
	local text = ScreenText(p)
	HasNot(text, "Grimtusk")
	Has(text, "Player")
	Click(state)
	Ok(ns.UI.panels.options:IsShown(), "a click on the sign opens where it is turned off")
end)

T("chat commands", function()
	local ns = Start()
	Slash("/rk help")
	Has(Chat(), "/rk groups")
	Slash("/rk options detection")
	MOCK.Advance(0.1)
	Eq(ns.UI.panels.options.current, "detection", "/rk options <page>")
	Slash("/rk add Kael-Draenor 1 Great tank")
	local rec = Players(ns)["kael-draenor"]
	Ok(rec and rec.reputation == 1, "/rk add")
	Eq(rec.timeline[1].text, "Great tank")
	Slash("/rk players")
	Ok(ns.UI.panels.players:IsShown(), "/rk players")
end)

-- The setup -----------------------------------------------------------------------------------------------------------------
local function SetupWindow(ns)
	local s = ns.Setup.Frame()
	Ok(s and s:IsShown(), "the setup is open")
	return s
end
local function SetupClosed(ns)
	local s = ns.Setup.Frame()
	return not (s and s:IsShown())
end
-- The radio button (or check) labelled `label` is ticked.
local function Picked(label, root)
	local b = FindButton(label, root)
	assert(b, "no choice " .. label .. " on screen\n" .. ScreenText(root))
	return b:GetChecked() and true or false
end
-- Saved data from before the setup came (RepKeeper 2.0).
local function BeforeSetup()
	local db = Fixture()
	db.global.settings.setupVersion = nil
	return db
end

T("setup: opens by itself the first time; Skip keeps everything as it was", function()
	local ns = Boot()
	local s = SetupWindow(ns)
	Eq(Text(s.subtitle), "First-time setup")
	Eq(Text(s.step), "Step 1 of 6")
	Has(ScreenText(s), "How should RepKeeper look?")
	Ok(not s.back:IsEnabled(), "nothing to go back to on the first page")
	Press("Skip setup", s)
	Ok(not s:IsShown())
	Has(Chat(), "Setup skipped. Type /rk setup to run it any time.")
	Eq(ns.S.setupVersion, 1)
	Eq(ns.S.groupWarningEnabled, true, "the settings stay as they were")
	Eq(ns.W.themeId, "classic")
	MOCK.Fire("PLAYER_ENTERING_WORLD", false, false)
	MOCK.Advance(10, 0.5)
	Ok(SetupClosed(ns), "a loading screen doesn't bring it back")
	Eq(Logout().global.settings.setupVersion, 1, "saved: it doesn't open at the next login")
end)

T("setup: one question a page, each with an example; Finish saves the answers", function()
	local db = BeforeSetup()
	db.global.settings.tooltipEnabled = false
	local ns = Start(db)
	local s = SetupWindow(ns)
	Eq(Text(s.subtitle), "First-time setup", "someone who used RepKeeper before sees it once too")

	-- 1. The look: the window shows it right away; it's saved on Finish.
	Press("Horde", s)
	Eq(ns.W.themeId, "horde", "the window takes the look at once")
	Eq(ns.S.ui.theme, "classic", "but it isn't saved yet")
	MOCK.DragSlider(FindText("UI size", s):GetParent(), 120)
	Near(s:GetScale(), 1.2, 0.001, "the size too")
	Near(ns.S.ui.scale, 1, 0.001)
	Press("Next", s)

	-- 2. The warning.
	Eq(Text(s.step), "Step 2 of 6")
	Ok(s.back:IsEnabled())
	Has(ScreenText(s), "Warn you about blacklisted players?")
	Ok(Picked("Yes, warn me when one is in my group", s), "what you have now is picked")
	local sound = FindButton("Play a sound with it", s)
	Ok(sound:IsEnabled() and sound:GetChecked())
	Has(ScreenText(s.pages[2].example), "A player you blacklisted is in your group.")
	Press("No, don't warn me", s)
	Ok(not Picked("Yes, warn me when one is in my group", s), "one answer at a time")
	Ok(not sound:IsEnabled(), "no sound without the warning")
	Has(ScreenText(s.pages[2].example), "No warning.", "the example says what happens instead")
	Press("Next", s)

	-- 3. Who RepKeeper adds by itself.
	Has(ScreenText(s), "Who should RepKeeper add to your list?")
	Ok(Picked("My dungeon groups", s), "the dungeon groups, as before")
	local example = s.pages[3].example
	HasNot(ScreenText(example), "Elwynn Forest")
	Press("Nobody", s)
	Has(ScreenText(example), "Nobody else is added.")
	local prune = FindButton("Remove them again when I haven't seen them for 30 days", s)
	Ok(not prune:IsEnabled(), "nothing to remove when nobody is added")
	Press("Everyone I group with", s)
	Has(ScreenText(example), "Grouped with in Elwynn Forest", "the example has a group outside dungeons too")
	Ok(prune:IsEnabled())
	Click(prune)
	Press("Next", s)

	-- 4. Tooltips: this player had them off.
	Ok(Picked("No, leave tooltips as they are", s))
	example = s.pages[4].example
	HasNot(ScreenText(example), "BLACKLISTED", "the example tooltip without RepKeeper's lines")
	Press("Yes, add it to their tooltip", s)
	Has(ScreenText(example), "BLACKLISTED")
	Has(ScreenText(example), "Rolled need on everything.")
	Press("No, leave tooltips as they are", s)
	Press("Next", s)

	-- 5. The minimap button.
	Ok(Picked("Yes, show it on the minimap", s))
	Press("No, I'll type /rk", s)
	Has(ScreenText(s.pages[5].example), "No button. Type /rk to open RepKeeper.")
	Press("Back", s)
	Eq(Text(s.step), "Step 4 of 6", "Back goes back a page")
	Ok(Picked("No, leave tooltips as they are", s), "with the answers kept")
	Press("Next", s)
	Press("Next", s)

	-- 6. What you picked.
	Eq(Text(s.step), "Step 6 of 6")
	Eq(Text(s.next), "Finish")
	local text = ScreenText(s)
	Has(text, "You're all set!")
	Has(text, "Look: Horde, 120% size")
	Has(text, "Warnings: off")
	Has(text, "Added by itself: Everyone I group with, removed after 30 days unseen")
	Has(text, "Tooltips: No")
	Has(text, "Minimap button: No")
	Has(text, "Turning the warnings on or off takes effect after a reload.")
	Has(text, "Open RepKeeper: type /rk.", "the tips follow your answers")
	Eq(ns.S.groupWarningEnabled, true, "nothing is saved before Finish")
	Eq(ns.S.autoTrackAllGroups, false)
	Press("Finish", s)
	Ok(not s:IsShown())
	Has(Chat(), "You're all set. Type /rk to open RepKeeper")
	Eq(MOCK.reloads, 0, "Finish doesn't reload")
	local S = ns.S
	Eq(S.ui.theme, "horde")
	Eq(ns.W.themeId, "horde")
	Near(S.ui.scale, 1.2, 0.001)
	Eq(S.groupWarningEnabled, false)
	Eq(S.autoTrackAllGroups, true)
	Eq(S.autoTrackDungeonGroups, true)
	Eq(S.autoPruneEnabled, true)
	Eq(S.tooltipEnabled, false)
	Eq(S.minimapButton.hide, true)
	Ok(not MOCK.minimapButtons.RepKeeper.shown, "the minimap button goes")
	Eq(S.setupVersion, 1)
	local o = Open(ns, "options")
	Ok(o.reload:IsShown(), "the Options tab offers the reload too")
	Eq(Logout().global.settings.setupVersion, 1, "saved: it doesn't open at the next login")
end)

T("setup: Finish and reload, when the warnings changed", function()
	local ns = Start(BeforeSetup())
	local s = SetupWindow(ns)
	Press("Next", s)
	Press("No, don't warn me", s)
	for _ = 1, 4 do
		Press("Next", s)
	end
	Press("Finish and reload", s)
	Eq(ns.S.groupWarningEnabled, false)
	Eq(MOCK.reloads, 1)
end)

T("setup: closed before Finish, nothing changes and the look you tried goes back", function()
	local ns = Start()
	Ok(SetupClosed(ns), "this player went through it before")
	Slash("/rk setup")
	local s = SetupWindow(ns)
	Eq(Text(s.subtitle), "Setup")
	Ok(not FindButton("Skip setup", s), "Cancel instead of Skip setup when you open it yourself")
	Press("Steel", s)
	MOCK.DragSlider(FindText("UI size", s):GetParent(), 80)
	Near(s:GetScale(), 0.8, 0.001)
	Chat()
	UIParent:Hide()
	UIParent:Show()
	Ok(s:IsShown(), "hiding the interface (Alt+Z) leaves it open")
	Eq(ns.W.themeId, "steel", "with the look you're trying")
	Near(s:GetScale(), 0.8, 0.001, "and the size")
	HasNot(Chat(), "Setup closed", "and nothing is said")
	Press("Next", s)
	Press("No, don't warn me", s)
	Press("Cancel", s)
	Ok(not s:IsShown())
	Has(Chat(), "Setup closed, nothing was changed.")
	Eq(ns.W.themeId, "classic", "the look goes back")
	Near(s:GetScale(), 1, 0.001, "and the size")
	Eq(ns.S.groupWarningEnabled, true)
	Slash("/rk setup")
	Eq(Text(s.step), "Step 1 of 6", "it starts at the beginning again")
	Press("Next", s)
	Ok(Picked("Yes, warn me when one is in my group", s), "from your settings, not the answers you left")
	Click(s.close)
	Ok(not s:IsShown(), "the X closes it")
	Has(Chat(), "Setup closed, nothing was changed.")
	local o = Open(ns, "options")
	Press("Run setup again", o.box)
	SetupWindow(ns)
	MOCK.PressEscape()
	Ok(not s:IsShown(), "Esc closes it")
	Slash("/rk help")
	Has(Chat(), "/rk setup - run the setup again")
end)

T("setup: never opens in a fight; it waits until the fight is over", function()
	local ns = Boot({ db = BeforeSetup(), beforeLoad = function() MOCK.combat = true end })
	Ok(SetupClosed(ns), "not during the fight")
	MOCK.Advance(30, 0.5)
	Ok(SetupClosed(ns))
	MOCK.combat = false
	MOCK.Fire("PLAYER_REGEN_ENABLED")
	MOCK.Advance(2, 0.5)
	SetupWindow(ns)
end)

-- Who RepKeeper adds by itself ------------------------------------------------------------------------------------------------
local function Key(first, realm, surname)
	return first:lower() .. "-" .. (FOREVER and surname or realm):lower()
end
local function Lines(rec)
	local out = {}
	for _, e in ipairs(rec and rec.timeline or {}) do
		out[#out + 1] = e.text
	end
	return table.concat(out, "; ")
end
local DUNGEON = FOREVER and "The Deadmines" or "The Stonevault"

T("Everyone I group with: the players you group with go on your list as Neutral, with where you grouped", function()
	local ns = Start()
	local kael = MOCK.Person("Kael", FOREVER and "Sunstrider" or "Draenor", "PALADIN")
	local kaelKey = Key("Kael", "Draenor", "Sunstrider")
	MOCK.SetGroup({ kael })
	Eq(Players(ns)[kaelKey], nil, "My dungeon groups (the default) adds nobody outside dungeons")

	-- Turned on in a group: that group goes on the list right away.
	local o = Open(ns, "options")
	Press("Tracking", o.nav)
	local dd = FindText("My dungeon groups", o.box):GetParent()
	Click(dd.button)
	Eq(table.concat(MenuTexts(), ","), "Nobody,My dungeon groups,Everyone I group with")
	MenuClick("Everyone I group with")
	Ok(ns.S.autoTrackAllGroups and ns.S.autoTrackDungeonGroups, "everyone takes in the dungeon groups")
	local rec = Players(ns)[kaelKey]
	Ok(rec, "someone new goes on the list")
	Eq(rec.reputation, 0, "as Neutral")
	Eq(rec.source, "auto_group")
	Eq(rec.class, "PALADIN")
	Eq(Lines(rec), "Grouped with in Elwynn Forest")
	ns.UI.Hide()

	-- Someone you rated: their rating stays.
	local grim = MOCK.Person("Grimtusk", FOREVER and "Ironhand" or "Ragnaros", "WARRIOR")
	MOCK.SetGroup({ kael, grim })
	local g = Players(ns)[P.grim.key]
	Eq(g.reputation, -1, "someone you rated keeps their rating")
	Eq(g.timeline[#g.timeline].text, "Grouped with in Elwynn Forest", "and gets the line too")

	-- Travelling together adds nothing; a dungeon together adds one line (not two: Everyone takes in My dungeon groups).
	MOCK.zone = "Westfall"
	MOCK.Fire("ZONE_CHANGED_NEW_AREA")
	MOCK.SetGroup({ kael, grim })
	Eq(#rec.timeline, 1, "travelling together adds nothing")
	MOCK.instance = { name = DUNGEON, type = "party" }
	MOCK.Fire("PLAYER_ENTERING_WORLD", false, false)
	MOCK.Advance(5, 0.5)
	Eq(Lines(rec), "Grouped with in Elwynn Forest; Grouped with in " .. DUNGEON, "one line for the dungeon")
	if not FOREVER then
		MOCK.keystone = { mapID = 501, level = 10, name = DUNGEON }
		MOCK.Fire("CHALLENGE_MODE_START", 501)
		Eq(rec.timeline[2].text, "Grouped with in " .. DUNGEON .. " +10", "a Mythic+ key's level, as My dungeon groups writes it")
		-- Another group with them in the same dungeon soon after: one line for both, and the first key stays on it.
		MOCK.SetGroup(nil)
		MOCK.SetGroup({ kael, grim })
		MOCK.keystone.level = 12
		MOCK.Fire("CHALLENGE_MODE_START", 501)
		Eq(Lines(rec), "Grouped with in Elwynn Forest; Grouped with in " .. DUNGEON .. " +10", "the first run's line keeps its key")
		MOCK.keystone = nil
	end
	MOCK.instance = nil
	MOCK.Fire("PLAYER_ENTERING_WORLD", false, false)
	MOCK.Advance(5, 0.5)
	Eq(#rec.timeline, 2, "back outside: nothing new")

	-- Leaving and joining again soon after starts from nothing noted, like a /reload: still the same group, nothing new
	-- (outside, in another zone than where it started).
	MOCK.SetGroup(nil)
	MOCK.SetGroup({ kael })
	Eq(#rec.timeline, 2, "the same group again soon after adds nothing")

	-- Another group, hours later: a new line.
	MOCK.SetGroup(nil)
	MOCK.Advance(3 * 3600, 600)
	MOCK.SetGroup({ kael })
	Eq(#rec.timeline, 3)
	Eq(rec.timeline[3].text, "Grouped with in Westfall")

	-- Nobody: nobody is added.
	MOCK.SetGroup(nil)
	ns.GroupTracker:SetMode("nobody")
	Ok(not ns.S.autoTrackAllGroups and not ns.S.autoTrackDungeonGroups)
	MOCK.SetGroup({ MOCK.Person("Bob", FOREVER and "Stoutbeard" or "Draenor", "ROGUE") })
	Eq(Players(ns)[Key("Bob", "Draenor", "Stoutbeard")], nil, "Nobody adds nobody")
end)

T("Everyone I group with: dungeon finder groups, battlegrounds, fights, and names the game hasn't sent yet", function()
	local ns = Start()
	ns.GroupTracker:SetMode("everyone")
	local kael = MOCK.Person("Kael", FOREVER and "Sunstrider" or "Draenor", "PALADIN")
	local kaelKey = Key("Kael", "Draenor", "Sunstrider")
	MOCK.SetGroup({ kael }, false, "instance")
	Eq(Players(ns)[kaelKey], nil, "a dungeon finder group gets no line where you queued")
	MOCK.instance = { name = DUNGEON, type = "party" }
	MOCK.Fire("PLAYER_ENTERING_WORLD", false, false)
	Eq(Lines(Players(ns)[kaelKey]), "Grouped with in " .. DUNGEON, "but one in the dungeon")
	MOCK.SetGroup(nil)

	local bob = MOCK.Person("Bob", FOREVER and "Stoutbeard" or "Draenor", "ROGUE")
	local bobKey = Key("Bob", "Draenor", "Stoutbeard")
	MOCK.instance = { name = "Warsong Gulch", type = "pvp" }
	MOCK.Fire("PLAYER_ENTERING_WORLD", false, false)
	MOCK.SetGroup({ bob }, true, "instance")
	Eq(Players(ns)[bobKey], nil, "battlegrounds are left out")
	MOCK.SetGroup(nil)
	MOCK.instance = nil
	MOCK.Fire("PLAYER_ENTERING_WORLD", false, false)

	MOCK.combat = true
	MOCK.SetGroup({ bob })
	Eq(Players(ns)[bobKey], nil, "nobody is looked at during a fight")
	MOCK.combat = false
	MOCK.Fire("PLAYER_REGEN_ENABLED")
	Eq(Lines(Players(ns)[bobKey]), "Grouped with in Elwynn Forest", "only after it")

	local nyx = MOCK.Person("Unknown", nil, "MAGE")
	MOCK.SetGroup({ bob, nyx })
	nyx.name, nyx.realm = "Nyx", FOREVER and "Shadowveil" or "Draenor"
	MOCK.Advance(3, 0.5)
	Ok(Players(ns)[Key("Nyx", "Draenor", "Shadowveil")], "someone who shows as Unknown is looked at again a moment later")
	for _, rec in pairs(Players(ns)) do
		Ok(rec.name ~= "Unknown", "nobody called Unknown")
	end

	MOCK.secrets = { Shade = true }
	MOCK.SetGroup({ bob, nyx, MOCK.Person("Shade", FOREVER and "Veil" or "Draenor", "PRIEST") })
	MOCK.secrets = nil
	Eq(Players(ns)[Key("Shade", "Draenor", "Veil")], nil, "names the game keeps from addons are skipped")
end)

-- Every setup page in every look: nothing outside its page, nothing running into the example at the bottom.
local function IntoExample(page)
	local out = {}
	local box = page.example
	if not box then
		return out
	end
	local r = Rect(box)
	local top = r.b + r.h
	local t = Rect(box.title)
	if t and Text(box.title) ~= "" then
		top = math.max(top, t.b + t.h)
	end
	local inBox = { [box] = true }
	for _, obj in ipairs(Descendants(box)) do
		inBox[obj] = true
	end
	for _, obj in ipairs(Descendants(page)) do
		local o = Rect(obj)
		if not inBox[obj] and o and o.w > 0 and o.h > 0 and o.b < top - 0.5 then
			out[#out + 1] = (obj._kind == "FontString" and ("text '" .. Text(obj) .. "'") or obj._kind) .. " runs into the example"
		end
	end
	return out
end

T("setup: every page fits, and nothing runs into its example, in every look", function()
	local ns = Start()
	for _, theme in ipairs(ns.W.THEME_ORDER) do
		ns.W.SetTheme(theme)
		Slash("/rk setup")
		local s = SetupWindow(ns)
		for i, page in ipairs(s.pages) do
			-- The answers that show the most: the summary then has the reload note too.
			if i == 2 then
				Press("No, don't warn me", s)
			elseif i == 3 then
				Press("Everyone I group with", s)
			end
			MOCK.Advance(0.1)
			local where = theme .. " setup page " .. i
			NoProblems(Outside(s, s, s.header), where .. ": outside the window")
			NoProblems(Outside(page, s.body), where .. ": outside its page")
			NoProblems(IntoExample(page), where)
			NoProblems(CutLabels(s), where .. ": labels cut off")
			if i < #s.pages then
				Press("Next", s)
			end
		end
		Press("Cancel", s)
	end
end)

-- Looks ---------------------------------------------------------------------------------------------------------------------
T("every page fits its window, every label fits its button, in every look", function()
	local ns = Start()
	local f
	for _, theme in ipairs(ns.W.THEME_ORDER) do
		ns.W.SetTheme(theme)
		for _, id in ipairs({ "players", "groups", "options" }) do
			local panel = Open(ns, id)
			f = ns.UI.Frame()
			NoProblems(Outside(panel, f.content), theme .. " " .. id .. ": outside the window")
			NoProblems(CutLabels(f), theme .. " " .. id .. ": labels cut off")
			if id == "options" then
				for _, b in ipairs(panel.navButtons) do
					Click(b)
					MOCK.Advance(0.1)
					NoProblems(Outside(panel, f.content), theme .. " options " .. b.id .. ": outside the window")
					NoProblems(CutLabels(panel), theme .. " options " .. b.id .. ": labels cut off")
				end
				Click(panel.navButtons[1])
			end
		end
	end
	Press("Players", f)
	MOCK.Advance(0.1)
	local p = ns.UI.panels.players
	Click(p.details.addTag)
	NoProblems(Outside(RepKeeperTagPicker, RepKeeperTagPicker), "tag picker")
	Click(p.details)
	local popups = {
		function()
			return ns.UI.Confirm("Remove player", "Remove Somebody-Somewhere from RepKeeper?\nTheir rating, tags, note and history are deleted.", "Remove")
		end,
		function() return ns.UI.AddPlayerDialog() end,
		function() return ns.UI.NewTagDialog(Players(ns)[P.grim.key]) end,
		function() return ns.UI.ShowExport() end,
		function() return ns.UI.ShowImport() end,
		function()
			ns.QuickAdd:Show(Players(ns)[P.grim.key], "left")
			return RepKeeperQuickAdd
		end,
		function()
			ns.UI.ShowGroupWarning({ Players(ns)[P.grim.key], Players(ns)[P.brakk.key] })
			return RepKeeperWarning
		end,
	}
	for i, open in ipairs(popups) do
		local w = open()
		MOCK.Advance(0.1)
		NoProblems(Outside(w, w, w.header), "pop-up " .. i .. " " .. tostring(w:GetName()))
		NoProblems(CutLabels(w), "pop-up " .. i .. " " .. tostring(w:GetName()) .. ": labels cut off")
		w:Hide()
	end
end)
