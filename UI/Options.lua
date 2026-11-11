-- UI/Options.lua
-- The Options tab: a search box and the categories on the left, one page of settings on the right (like GuildLedger).
-- Settings that only matter when another one is on appear under it when it is. Also the page in the game's settings
-- (Esc > Options > AddOns > RepKeeper), a canvas of RepKeeper's own frames: the game's shared settings rows taint
-- on WoW Forever.

local addonName, ns = ...
local L = LibStub("AceLocale-3.0"):GetLocale("RepKeeper")
local C = ns.Constants
local U, W, UI = ns.U, ns.W, ns.UI

local format, floor, max = string.format, math.floor, math.max

local Options = {}
ns.Options = Options

local PAGES, PAGE_BY_ID = {}, {}

local function S()
    return ns.S
end

local function changed(key)
    ns.Fire("SETTINGS_CHANGED", key)
end

local function setting(key)
    return function()
        return S()[key]
    end, function(v)
        S()[key] = v
        changed(key)
    end
end

local function on(key)
    return function()
        return S()[key] and true or false
    end
end

---------------------------------------------------------------------------
-- Settings that are read when you log in: changing them asks for a reload.
---------------------------------------------------------------------------
local RELOAD_KEYS = {
    detectionEnabled = true, detectLeavers = true, detectVoteKicks = true, detectTradeSpam = true,
    detectDuelSpam = true, detectWhisperSpam = true, encounterHistoryEnabled = true, groupWarningEnabled = true,
    guildSyncEnabled = true,
}
local RELOAD_NOTE = L["Takes effect after a reload."]
local loginValues = {}

function Options.NeedsReload()
    for key in pairs(RELOAD_KEYS) do
        if (S()[key] and true or false) ~= loginValues[key] then
            return true
        end
    end
    return false
end

local function reloadTip(text)
    return text .. "\n\n" .. U.Color(ns.COLOR.orange, RELOAD_NOTE)
end

local function addPage(def)
    PAGES[#PAGES + 1] = def
    PAGE_BY_ID[def.id] = def
end

-- A scrolling page body; the scroll area follows the stack when rows come and go.
local function scrollStack(page)
    local sf, content = W.ScrollPanel(page)
    sf:SetPoint("TOPLEFT", 4, -60)
    sf:SetPoint("BOTTOMRIGHT", -26, 4)
    local stack = W.Stack(content, 10, 6, 560)
    stack.scroll = sf
    stack.onLayout = function(s)
        content:SetHeight(s:Height())
    end
    page.stacks[#page.stacks + 1] = stack
    return stack, content
end

local function finish(stack, content)
    content:SetHeight(stack:Height())
end

local function days(v)
    return format(v == 1 and L["%d day"] or L["%d days"], v)
end

local function seconds(v)
    return format(L["%d sec"], v)
end

-- Two sliders side by side: how many times, in how many seconds (spam detection).
local function countAndWindow(stack, title, countKey, countMin, countMax, windowKey, windowMax, visible)
    local row = CreateFrame("Frame", nil, stack.parent)
    row:SetSize(stack.width, 56)
    local get1, set1 = setting(countKey)
    local count = W.Slider(row, title, countMin, countMax, 1, get1, set1, "%d", 150)
    count:SetPoint("TOPLEFT", 6, -16)
    local get2, set2 = setting(windowKey)
    local window = W.Slider(row, L["Within"], 10, windowMax, 10, get2, set2, seconds, 150)
    window:SetPoint("TOPLEFT", 190, -16)
    stack:Track(count)
    stack:Track(window)
    return stack:Place(row, 56, 24, 0, { label = title .. " " .. L["Within"], visible = visible, indent = 24 })
end

---------------------------------------------------------------------------
-- General
---------------------------------------------------------------------------
addPage({
    id = "general",
    label = L["General"],
    desc = L["How RepKeeper looks, its minimap button, and how names and dates show."],
    build = function(page)
        local stack, content = scrollStack(page)

        stack:Header(L["Window"])
        stack:Dropdown(L["Look"], 170, function()
            local items = {}
            for _, id in ipairs(W.THEME_ORDER) do
                local th = W.THEMES[id]
                items[#items + 1] = { text = th.name, value = id, tooltip = th.desc }
            end
            return items
        end, function()
            return W.themeId
        end, function(v)
            W.SetTheme(v)
        end, {
            tip = L["Classic is the game's own look. Steel, Horde and Alliance recolour the same frames."],
            keywords = L["theme colours colors style skin"],
        })
        stack:Slider(L["UI size"], 70, 150, 5, function()
            return floor(W.Scale() * 100 + 0.5)
        end, function(v)
            S().ui.scale = v / 100
            changed("scale")
        end, "%d%%", { tip = L["The size of RepKeeper's windows. Turn the mouse wheel over the slider for small steps."], keywords = L["scale zoom"] })

        stack:Header(L["Minimap"])
        stack:Check(L["Show the minimap button"], L["Left-click opens RepKeeper, right-click opens these options."], function()
            return not S().minimapButton.hide
        end, function(v)
            S().minimapButton.hide = not v
            if ns.Minimap and ns.Minimap.Refresh then
                ns.Minimap:Refresh()
            end
            changed("minimap")
        end, { keywords = L["icon"] })

        stack:Header(L["Names"])
        stack:Dropdown(L["Realm names"], 170, {
            { text = L["Automatic"], value = "auto", tooltip = L["Hidden on WoW Forever and Classic, where realm names are only for the servers. Shown on Retail."] },
            { text = L["Always show"], value = "show" },
            { text = L["Always hide"], value = "hide" },
        }, function()
            local v = S().hideRealms
            if v == true then
                return "hide"
            elseif v == false then
                return "show"
            end
            return "auto"
        end, function(v)
            if v == "hide" then
                S().hideRealms = true
            elseif v == "show" then
                S().hideRealms = false
            else
                S().hideRealms = "auto"
            end
            changed("hideRealms")
        end, { tip = L["Whether names show their realm, like Frost-Kazzak. Whispers always use the full name."] })
        local get, set = setting("streamerMode")
        stack:Check(L["Streamer mode"], L["Hides names: players show as Player1234 in RepKeeper's windows and tooltips. Handy when you stream or record."], get, set, { keywords = L["hide privacy record anonymous"] })

        stack:Header(L["History"])
        stack:Dropdown(L["Dates in history"], 170, {
            { text = L["Relative (3 days ago)"], value = "relative" },
            { text = L["Dates (10 Nov 2026)"], value = "absolute" },
        }, function()
            return S().timelineDateFormat == "absolute" and "absolute" or "relative"
        end, function(v)
            S().timelineDateFormat = v
            changed("timelineDateFormat")
        end, { tip = L["How the dates in a player's history show. Hover an entry for the exact time."] })
        finish(stack, content)
    end,
})

---------------------------------------------------------------------------
-- Alerts
---------------------------------------------------------------------------
addPage({
    id = "alerts",
    label = L["Alerts"],
    desc = L["Warnings about blacklisted players around you."],
    build = function(page)
        local stack, content = scrollStack(page)
        local groupOn = on("groupWarningEnabled")

        stack:Header(L["In your group"])
        local get, set = setting("groupWarningEnabled")
        stack:Check(L["Warn me when a blacklisted player is in my group"], reloadTip(L["A warning pops up when you join a group with someone you blacklisted, with their tags and note."]), get, set)
        get, set = setting("groupWarningSound")
        stack:Check(L["Play a sound"], L["The raid warning sound, so you notice it."], get, set, { indent = 18, dep = groupOn })
        local contexts = {
            { "party", L["In parties"] },
            { "raid", L["In raids"] },
            { "arena", L["In arenas"] },
            { "battleground", L["In battlegrounds"] },
        }
        for _, c in ipairs(contexts) do
            stack:Check(c[2], nil, function()
                return S().groupWarningContexts[c[1]]
            end, function(v)
                S().groupWarningContexts[c[1]] = v
                changed("groupWarningContexts")
            end, { indent = 18, dep = groupOn })
        end

        stack:Header(L["Invites"])
        stack:Text(L["When a blacklisted player invites you to a group, RepKeeper always warns you, so you don't accept by accident. To decline those invites for you, see Automation."])
        finish(stack, content)
    end,
})

---------------------------------------------------------------------------
-- Tracking
---------------------------------------------------------------------------
addPage({
    id = "tracking",
    label = L["Tracking"],
    desc = L["What RepKeeper remembers on its own."],
    build = function(page)
        local stack, content = scrollStack(page)

        stack:Header(L["Groups"])
        local get, set = setting("encounterHistoryEnabled")
        stack:Check(L["Remember my groups"], reloadTip(L["Keeps the dungeons, raids and battlegrounds you run and who was in them (the Groups tab)."]), get, set, { keywords = L["encounters history runs"] })
        get, set = setting("autoTrackDungeonGroups")
        stack:Check(L["Add my dungeon groupmates to the list"], L["Everyone in your dungeon and Mythic+ groups is added as Neutral, with a line in their history. Raids are left out: too many people."], get, set, { indent = 18 })

        stack:Header(L["Clean-up"])
        get, set = setting("autoPruneEnabled")
        stack:Check(L["Remove forgotten players"], L["Removes players RepKeeper added by itself that you never rated, tagged or wrote about, and haven't seen for a while. Checked when you log in."], get, set, { keywords = L["prune delete old"] })
        get, set = setting("autoPruneDays")
        stack:Slider(L["Not seen for"], 7, 365, 1, get, set, days, { indent = 18, visible = on("autoPruneEnabled"), tip = L["Turn the mouse wheel over the slider to change it one day at a time."] })
        finish(stack, content)
    end,
})

---------------------------------------------------------------------------
-- Detection
---------------------------------------------------------------------------
addPage({
    id = "detection",
    label = L["Detection"],
    desc = L["Spot players who leave your group or spam you, and offer to rate them."],
    build = function(page)
        local stack, content = scrollStack(page)
        local detectOn = on("detectionEnabled")

        stack:Header(L["Watch for"])
        local get, set = setting("detectionEnabled")
        stack:Check(L["Watch for leavers and spammers"], reloadTip(L["RepKeeper notes it in their history and can ask you to rate them."]), get, set, { keywords = L["detect"] })
        get, set = setting("detectLeavers")
        stack:Check(L["Players who leave my group"], reloadTip(L["Someone leaves while you stay in the group."]), get, set, { indent = 18, visible = detectOn })
        get, set = setting("detectVoteKicks")
        stack:Check(L["Vote kicks"], reloadTip(L["Notes it in the history of a player who gets vote-kicked."]), get, set, { indent = 18, visible = detectOn })
        get, set = setting("detectTradeSpam")
        stack:Check(L["Trade spam"], reloadTip(L["Someone opens trade with you again and again."]), get, set, { indent = 18, visible = detectOn })
        countAndWindow(stack, L["Trade requests"], "tradeSpamThreshold", 2, 10, "tradeSpamWindow", 300, function()
            return S().detectionEnabled and S().detectTradeSpam
        end)
        get, set = setting("detectDuelSpam")
        stack:Check(L["Duel spam"], reloadTip(L["Someone asks you to duel again and again."]), get, set, { indent = 18, visible = detectOn })
        countAndWindow(stack, L["Duel requests"], "duelSpamThreshold", 2, 10, "duelSpamWindow", 600, function()
            return S().detectionEnabled and S().detectDuelSpam
        end)
        get, set = setting("detectWhisperSpam")
        stack:Check(L["Whisper spam"], reloadTip(L["Someone sends you a lot of whispers in a short time."]), get, set, { indent = 18, visible = detectOn })
        countAndWindow(stack, L["Whispers"], "whisperSpamThreshold", 2, 20, "whisperSpamWindow", 300, function()
            return S().detectionEnabled and S().detectWhisperSpam
        end)

        stack:Header(L["Pop-up"])
        get, set = setting("quickAddPopupEnabled")
        stack:Check(L["Ask me to rate them"], L["A small pop-up with Blacklist and Positive buttons when RepKeeper spots someone. It goes away by itself."], get, set, { keywords = L["quick add popup"] })
        get, set = setting("quickAddPopupTimeout")
        stack:Slider(L["Pop-up stays for"], 5, 60, 1, get, set, seconds, { indent = 18, visible = on("quickAddPopupEnabled") })
        finish(stack, content)
    end,
})

---------------------------------------------------------------------------
-- Tooltip
---------------------------------------------------------------------------
addPage({
    id = "tooltip",
    label = L["Tooltip"],
    desc = L["What RepKeeper adds when you hover a player in the game."],
    build = function(page)
        local stack, content = scrollStack(page)
        local tipOn = on("tooltipEnabled")
        stack:Header(L["Tooltip"])
        local get, set = setting("tooltipEnabled")
        stack:Check(L["Show RepKeeper in tooltips"], L["Their rating, and a red BLACKLISTED line for players you blacklisted."], get, set, { keywords = L["hover mouseover"] })
        local rows = {
            { "tooltipShowTags", L["Tags"] },
            { "tooltipShowNote", L["Note"] },
            { "tooltipShowEncounters", L["How many groups you had together"] },
            { "tooltipShowDateAdded", L["When you added them"] },
        }
        for _, r in ipairs(rows) do
            get, set = setting(r[1])
            stack:Check(r[2], nil, get, set, { indent = 18, dep = tipOn })
        end
        finish(stack, content)
    end,
})

---------------------------------------------------------------------------
-- Automation
---------------------------------------------------------------------------
addPage({
    id = "automation",
    label = L["Automation"],
    desc = L["Let RepKeeper act on blacklisted players for you. Everything here is off until you turn it on."],
    build = function(page)
        local stack, content = scrollStack(page)
        stack:Header(L["Blacklisted players"])
        stack:Text(U.Color(ns.COLOR.orange, L["Declining for you uses the game's own pop-ups. On Retail that can stop other game windows from working (like the item upgrade window) until you reload. Turn on only what you need."]))
        local rows = {
            { "autoIgnoreEnabled", L["Add them to my ignore list"], L["Blacklisted players go on your /ignore list, so you don't see their chat."] },
            { "autoDeclineGroupInvites", L["Decline their group invites"], nil },
            { "autoDeclineGuildInvites", L["Decline their guild invites"], nil },
            { "autoDeclineDuels", L["Decline their duels"], nil },
            { "autoDeclineTrades", L["Close their trades"], nil },
        }
        for _, r in ipairs(rows) do
            local get, set = setting(r[1])
            stack:Check(r[2], r[3], get, set, { keywords = L["auto ignore decline"] })
        end
        finish(stack, content)
    end,
})

---------------------------------------------------------------------------
-- Guild sync
---------------------------------------------------------------------------
local TRUST = {
    { text = L["Ignore it"], value = 0, tooltip = L["What guildmates share is thrown away."] },
    { text = L["Ask me first"], value = 1, tooltip = L["What guildmates share waits below until you accept it."] },
    { text = L["Add it right away"], value = 2, tooltip = L["What guildmates share is added to your list at once."] },
}

local function pendingSuggestions()
    local list = {}
    for key, bySender in pairs(ns.GuildSync and ns.GuildSync.pendingSuggestions or {}) do
        for sender, s in pairs(bySender) do
            list[#list + 1] = { key = key, sender = sender, s = s }
        end
    end
    table.sort(list, function(a, b)
        return (a.s.receivedAt or 0) > (b.s.receivedAt or 0)
    end)
    return list
end

addPage({
    id = "guild",
    label = L["Guild sync"],
    desc = L["Share your blacklist with guildmates who also use RepKeeper. Off until you turn it on."],
    build = function(page)
        local stack, content = scrollStack(page)
        local syncOn = on("guildSyncEnabled")

        stack:Header(L["Sharing"])
        local get, set = setting("guildSyncEnabled")
        stack:Check(L["Share with my guild"], reloadTip(L["Sends your shared players to guildmates with RepKeeper, and receives theirs."]), get, set, { keywords = L["sync"] })
        get, set = setting("guildSyncMinRank")
        stack:Slider(L["Trust guildmates up to rank"], 0, 10, 1, get, set, function(v)
            return v == 0 and L["Guild Master"] or format(L["Rank %d"], v)
        end, { indent = 18, visible = syncOn, tip = L["Only guildmates of this rank or higher can share with you. 0 is the Guild Master, 1 the rank below, and so on."] })
        stack:Dropdown(L["When a guildmate shares a player"], 170, TRUST, function()
            return S().guildSyncTrustLevel
        end, function(v)
            S().guildSyncTrustLevel = v
            changed("guildSyncTrustLevel")
        end, { indent = 18, visible = syncOn })

        stack:Header(L["What I share"], nil, { visible = syncOn })
        get, set = setting("guildSyncShareBlacklist")
        stack:Check(L["My blacklist"], nil, get, set, { visible = syncOn })
        get, set = setting("guildSyncShareFavorites")
        stack:Check(L["Players I rated Positive"], nil, get, set, { visible = syncOn })
        get, set = setting("guildSyncShareNotes")
        stack:Check(L["My notes"], L["Your guildmates can read what you wrote. Off by default."], get, set, { visible = syncOn })

        stack:Header(L["Waiting for you"], nil, { visible = syncOn })
        local list = W.List(stack.parent, {
            { key = "name", label = L["Player"], fill = true, get = function(it)
                local s = it.s
                return ns.PlayerUtils:DisplayNamePlain({ name = s.name or "?", realm = s.realm or "", normalizedKey = it.key })
            end },
            { key = "rating", label = L["Rating"], width = 90, get = function(it)
                return UI.RatingLabel(it.s.reputation)
            end },
            { key = "from", label = L["From"], width = 110, get = function(it)
                return it.sender, 0.62, 0.62, 0.62
            end },
        }, {
            rowHeight = 18,
            empty = L["Nothing waiting."],
            onClick = function(it)
                W.ContextMenu(page, {
                    { text = it.s.name or "?", isTitle = true },
                    { text = L["Accept"], func = function()
                        ns.GuildSync:AcceptSuggestion(it.key, it.sender)
                        UI.Refresh()
                    end },
                    { text = L["Decline"], func = function()
                        ns.GuildSync:DeclineSuggestion(it.key, it.sender)
                        UI.Refresh()
                    end },
                })
            end,
        })
        list:SetSize(stack.width, 120)
        stack:Place(list, 128, 0, 0, { label = L["Waiting for you"], tip = L["Click one to accept or decline it."], visible = syncOn })
        page.suggestions = list
        function page:onRefresh()
            self.suggestions:SetData(pendingSuggestions())
        end
        finish(stack, content)
    end,
})

---------------------------------------------------------------------------
-- Data: backups, export and import, your own tags
---------------------------------------------------------------------------
local BACKUP_KIND = {
    auto = L["Automatic"],
    manual = L["By you"],
    ["pre-restore"] = L["Before a restore"],
}

local function reportRestore(ok, count)
    if ok then
        ns.Addon:Printf(L["Restored a backup: %d players."], count)
    else
        ns.Addon:Printf(L["Restore failed: %s"], tostring(count))
    end
    UI.Refresh()
end

local function customTagItems()
    local list = {}
    for id, def in pairs(ns.db.global.customTags or {}) do
        local n = 0
        for _, rec in pairs(ns.db.global.players) do
            if rec.tags and rec.tags[id] then
                n = n + 1
            end
        end
        list[#list + 1] = { id = id, def = def, count = n }
    end
    table.sort(list, function(a, b)
        return a.def.name < b.def.name
    end)
    return list
end

addPage({
    id = "data",
    label = L["Data"],
    desc = L["Backups, sharing your list, and the tags you made."],
    build = function(page)
        local stack, content = scrollStack(page)

        stack:Header(L["Backups"])
        local get, set = setting("autoBackupEnabled")
        stack:Check(L["Back up automatically"], L["Saves a copy of your list when you log in, every few days."], get, set)
        get, set = setting("autoBackupInterval")
        stack:Slider(L["Every"], 1, 30, 1, get, set, days, { indent = 18, visible = on("autoBackupEnabled") })
        get, set = setting("autoBackupKeepCount")
        stack:Slider(L["Backups to keep"], 1, 20, 1, get, set, "%d", { tip = L["The oldest backup goes when there are more."] })
        stack:Button(L["Back up now"], function()
            local ts = ns.Backup:CreateBackup("manual")
            if ts then
                ns.Addon:Printf(L["Backup created: %s"], U.DateTime(ts))
            end
            page:Refresh()
        end, L["Saves a copy of your list right now."])
        local backups = W.List(stack.parent, {
            { key = "date", label = L["Backup"], fill = true, get = function(b)
                return U.DateTime(b.timestamp)
            end },
            { key = "kind", label = L["Made"], width = 130, get = function(b)
                return BACKUP_KIND[b.kind] or tostring(b.kind or "?"), 0.62, 0.62, 0.62
            end },
        }, {
            rowHeight = 18,
            empty = L["No backups yet."],
            onClick = function(b)
                W.ContextMenu(page, {
                    { text = U.DateTime(b.timestamp), isTitle = true },
                    { text = L["Restore this backup..."], func = function()
                        UI.Confirm(L["Restore backup"], format(L["Go back to your list from %s?\nYour list as it is now is saved as a backup first."], U.DateTime(b.timestamp)), L["Restore"], function()
                            reportRestore(ns.Backup:Restore(b.timestamp))
                            page:Refresh()
                        end)
                    end },
                    { text = L["Delete this backup..."], color = { 1, 0.45, 0.45 }, func = function()
                        UI.Confirm(L["Delete backup"], format(L["Delete the backup from %s?"], U.DateTime(b.timestamp)), L["Delete"], function()
                            ns.Backup:DeleteBackup(b.timestamp)
                            page:Refresh()
                        end)
                    end },
                })
            end,
        })
        backups:SetSize(stack.width, 110)
        stack:Place(backups, 118, 0, 0, { label = L["Backups"], tip = L["Click a backup to restore or delete it."], keywords = L["restore"] })
        page.backups = backups

        stack:Header(L["Share your list"])
        stack:Button(L["Export..."], function()
            UI.ShowExport()
        end, L["Turns your list into text you can send to a friend."])
        stack:Button(L["Import..."], function()
            UI.ShowImport()
        end, L["Adds a list a friend sent you."], { sameLine = true })
        get, set = setting("anonymizeExports")
        stack:Check(L["Leave out notes and history when exporting"], L["Ratings and tags are still in. Battle.net names are left out too."], get, set)

        stack:Header(L["Your tags"])
        local tags = W.List(stack.parent, {
            { key = "name", label = L["Tag"], fill = true, get = function(t)
                local c = UI.TIER_COLOR[UI.TagTier(t.def)]
                return t.def.name, c[1], c[2], c[3]
            end },
            { key = "kind", label = L["Kind"], width = 90, get = function(t)
                return UI.TIER_NAME[UI.TagTier(t.def)], 0.62, 0.62, 0.62
            end },
            { key = "count", label = L["Players"], width = 70, justify = "RIGHT", get = function(t)
                return tostring(t.count)
            end },
        }, {
            rowHeight = 18,
            empty = L["You haven't made any tags. Make one from a player's + Tag button."],
            onClick = function(t)
                W.ContextMenu(page, {
                    { text = t.def.name, isTitle = true },
                    { text = L["Delete this tag..."], color = { 1, 0.45, 0.45 }, func = function()
                        UI.Confirm(L["Delete tag"], format(L["Delete the tag %s?\nIt is taken off %d players."], t.def.name, t.count), L["Delete"], function()
                            ns.Database:RemoveCustomTag(t.id)
                            page:Refresh()
                            UI.Refresh()
                        end)
                    end },
                })
            end,
        })
        tags:SetSize(stack.width, 110)
        stack:Place(tags, 118, 0, 0, { label = L["Your tags"], tip = L["Click a tag to delete it."] })
        page.tags = tags

        function page:onRefresh()
            self.backups:SetData(ns.Backup:ListBackups())
            self.tags:SetData(customTagItems())
        end
        finish(stack, content)
    end,
})

---------------------------------------------------------------------------
-- Help
---------------------------------------------------------------------------
local COMMANDS = {
    { "/rk", L["open or close RepKeeper"] },
    { "/rk add Name", L["add a player (Name-Realm for other realms)"] },
    { "/rk remove Name", L["remove a player"] },
    { "/rk note Name text", L["add a line to a player's history"] },
    { "/rk tag Name tag", L["add or remove a tag (its id, like toxic)"] },
    { "/rk groups", L["open the Groups tab"] },
    { "/rk options", L["open these options"] },
    { "/rk export, /rk import", L["share your list"] },
    { "/rk backup", L["back up your list now"] },
}

addPage({
    id = "help",
    label = L["Help"],
    desc = L["How RepKeeper works, and its chat commands."],
    build = function(page)
        local stack, content = scrollStack(page)
        stack:Header(L["How it works"])
        stack:Text(L["Rate the players you meet: Blacklist the ones to avoid, Positive the ones you liked. Everything else stays Neutral."])
        stack:Text(L["To rate someone, right-click them in the game (their portrait, their name in chat, the group frames) and choose RepKeeper. Or open RepKeeper and press Add player."])
        stack:Text(L["Hovering a player shows what you know about them. A blacklisted player gets a red BLACKLISTED line, and a warning pops up when they are in your group or invite you."])
        stack:Text(L["Everything is shared by all your characters on this account."])

        stack:Header(L["Chat commands"])
        for _, cmd in ipairs(COMMANDS) do
            local row = CreateFrame("Frame", nil, stack.parent)
            row:SetSize(stack.width, 18)
            local a = W.Label(row, cmd[1], "GameFontHighlightSmall")
            a:SetPoint("LEFT", 4, 0)
            local b = W.OneLine(W.Label(row, cmd[2], "GameFontDisableSmall"))
            b:SetPoint("LEFT", 150, 0)
            b:SetWidth(stack.width - 154)
            stack:Place(row, 18, 0, 0, { kind = "text", label = cmd[1] .. " " .. cmd[2] })
        end
        finish(stack, content)
    end,
})

---------------------------------------------------------------------------
-- Search
---------------------------------------------------------------------------
-- Text as the search reads it: lower case, without colour codes and icons, punctuation read as spaces, with a space
-- before every word so a search word matches the start of a word ("kick" finds "Vote kicks", not "sidekick").
local function normalize(s)
    s = tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|n", " ")
    s = s:lower():gsub("'", ""):gsub("[%p%c]", " "):gsub("%s+", " ")
    return " " .. s
end

local function searchWords(text)
    local words = {}
    for w in normalize(text):gmatch("%S+") do
        words[#words + 1] = " " .. w
    end
    return #words > 0 and words or nil
end

local function hasWords(text, words)
    for _, w in ipairs(words) do
        if not text:find(w, 1, true) then
            return false
        end
    end
    return true
end

local function itemTexts(items)
    if type(items) == "function" then
        local ok, list = pcall(items)
        items = ok and list or nil
    end
    local out = {}
    if type(items) == "table" then
        for _, it in ipairs(items) do
            if type(it.text) == "string" then
                out[#out + 1] = it.text
            end
        end
    end
    return table.concat(out, " ")
end

-- What the search reads in a row: its label, tooltip, extra words and dropdown items, or the text it shows.
local function rowText(row)
    if row.searchText then
        return row.searchText
    end
    local parts = { row.label or "", row.tip or "", row.keywords or "", row.extra or "" }
    if row.items then
        parts[#parts + 1] = itemTexts(row.items)
    end
    if row.fs then
        parts[#parts + 1] = row.fs:GetText() or ""
    end
    row.searchText = normalize(table.concat(parts, " "))
    return row.searchText
end

-- A row matches when every word is in the row, in its section header or in the name of the page.
local function pageMatcher(def, words)
    local pageText = normalize(def.label .. " " .. (def.keywords or ""))
    return function(row)
        return hasWords(rowText(row) .. (row.section and rowText(row.section) or "") .. pageText, words)
    end
end

---------------------------------------------------------------------------
-- The tab
---------------------------------------------------------------------------
local NAV_W = 160
local NAV_TOP = -40

local function navButton(parent, def, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(18)
    local count = b:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    count:SetPoint("RIGHT", -4, 0)
    count:SetJustifyH("RIGHT")
    local fs = b:CreateFontString(nil, "ARTWORK", "RepKeeperFontNormal")
    fs:SetPoint("LEFT", 6, 0)
    fs:SetPoint("RIGHT", count, "LEFT", -2, 0)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    fs:SetText(def.label)
    b.text = fs
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    hl:SetBlendMode("ADD")
    hl:SetAllPoints()
    b:SetHighlightTexture(hl)
    W.Themed(hl, W.PaintHighlight)
    b.id = def.id
    b:SetScript("OnEnter", function(self)
        self.text:SetFontObject("GameFontHighlight")
        W.ShowTip(self, def.label, def.desc, "ANCHOR_RIGHT")
    end)
    b:SetScript("OnLeave", function(self)
        W.HideTip()
        if not self.selected then
            self.text:SetFontObject("RepKeeperFontNormal")
        end
    end)
    b:SetScript("OnClick", function()
        W.Sound("click")
        onClick(def.id)
    end)
    function b:SetSelected(sel)
        self.selected = sel
        if sel then
            self:LockHighlight()
            self.text:SetFontObject("GameFontHighlight")
        else
            self:UnlockHighlight()
            self.text:SetFontObject("RepKeeperFontNormal")
        end
    end
    function b:SetCount(n)
        count:SetText(n and tostring(n) or "")
    end
    return b
end

local function buildPage(panel, def)
    local page = CreateFrame("Frame", nil, panel.box)
    page:SetPoint("TOPLEFT", 4, -4)
    page:SetPoint("BOTTOMRIGHT", -4, 4)
    page.stacks = {}
    local title = page:CreateFontString(nil, "ARTWORK", "RepKeeperFontTitleLarge")
    title:SetPoint("TOPLEFT", 12, -10)
    title:SetText(def.label)
    local desc = W.Label(page, def.desc or "", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", 12, -32)
    desc:SetPoint("TOPRIGHT", -12, -32)
    desc:SetJustifyV("TOP")
    desc:SetWordWrap(true)

    function page:Refresh()
        if self.onRefresh then
            self:onRefresh()
        end
        for _, stack in ipairs(self.stacks) do
            stack:Refresh()
        end
    end

    -- Shows only the settings match(row) accepts (all of them for nil); returns how many are shown.
    function page:ApplyFilter(match)
        local n = 0
        for _, stack in ipairs(self.stacks) do
            if #stack.rows > 0 then
                n = n + stack:Layout(match)
                if stack.scroll and match ~= self.filter then
                    stack.scroll:SetVerticalScroll(0)
                end
            end
        end
        self.filter = match
        return n
    end

    ns.SafeCall(def.build, page)
    panel.pages[def.id] = page
    page:Refresh()
    page:ApplyFilter(nil)
    return page
end

local function create(panel)
    panel.pages = {}
    panel.navButtons = {}
    panel.matchers = {}

    local nav = W.Box(panel)
    nav:SetPoint("TOPLEFT", 0, -2)
    nav:SetPoint("BOTTOMLEFT", 0, 0)
    nav:SetWidth(NAV_W)
    panel.nav = nav

    local box = W.Box(panel)
    box:SetPoint("TOPLEFT", NAV_W + 10, -2)
    box:SetPoint("BOTTOMRIGHT", 0, 0)
    panel.box = box

    panel.search = W.EditBox(nav, NAV_W - 30, {
        search = true,
        placeholder = L["Search settings"],
        maxLetters = 40,
        tip = L["Shows only the settings with these words, on every page. Esc clears the search."],
        tipTitle = L["Search settings"],
        onChange = function()
            ns.Debounce("rk-options-search", 0.2, function()
                panel:SetSearch(panel.search:GetText(), true)
            end)
        end,
        onEscape = function(self)
            if self:GetText() ~= "" then
                self:SetText("")
                panel:SetSearch("", true)
            end
        end,
    })
    panel.search:SetPoint("TOPLEFT", 16, -12)

    local version = W.Label(nav, "RepKeeper " .. tostring(ns.version or ""), "GameFontDisableSmall")
    version:SetPoint("BOTTOM", 0, 10)

    -- Settings read at login ask for a reload.
    local reload = CreateFrame("Frame", nil, nav)
    reload:SetPoint("BOTTOMLEFT", 8, 28)
    reload:SetPoint("BOTTOMRIGHT", -8, 28)
    reload:SetHeight(58)
    reload.text = W.Text(reload, U.Color(ns.COLOR.orange, L["Some changes need a reload."]), NAV_W - 20, "GameFontHighlightSmall")
    reload.text:SetPoint("TOP", 0, 0)
    reload.text:SetJustifyH("CENTER")
    reload.button = W.Button(reload, L["Reload now"], 124, function()
        ReloadUI()
    end, L["Reloads the interface, like /reload."])
    reload.button:SetPoint("BOTTOM", 0, 0)
    reload:Hide()
    panel.reload = reload

    local none = W.Text(box, "", 420, "GameFontHighlight")
    none:SetPoint("TOPLEFT", 16, -16)
    none:Hide()
    panel.noResults = none

    local function shows(id)
        for _, b in ipairs(panel.navButtons) do
            if b.id == id then
                return b:IsShown()
            end
        end
        return false
    end

    local function firstShown()
        for _, b in ipairs(panel.navButtons) do
            if b:IsShown() then
                return b.id
            end
        end
    end

    function panel:SelectPage(id)
        if not shows(id) then
            id = firstShown()
        end
        if not id then
            return
        end
        self.current = id
        for _, b in ipairs(self.navButtons) do
            b:SetSelected(b.id == id)
        end
        for pid, p in pairs(self.pages) do
            if pid ~= id then
                p:Hide()
            end
        end
        W.Menu:Hide()
        self.noResults:Hide()
        local page = self.pages[id] or buildPage(self, PAGE_BY_ID[id])
        page:Show()
        ns.SafeCall(page.Refresh, page)
    end

    for i, def in ipairs(PAGES) do
        panel.navButtons[i] = navButton(nav, def, function(id)
            panel:SelectPage(id)
        end)
    end

    -- While searching every page is built and filtered; returns how many of its settings match.
    local function matchPage(def, words)
        local page = panel.pages[def.id]
        if not page then
            page = buildPage(panel, def)
            if panel.current ~= def.id then
                page:Hide()
            end
        end
        local match = panel.matchers[def.id]
        if not match then
            match = pageMatcher(def, words)
            panel.matchers[def.id] = match
        end
        return page:ApplyFilter(match)
    end

    -- The pages there are (while searching: with matching settings, and how many), one under the other.
    function panel:LayoutNav()
        local words = self.words
        local n = 0
        for i, b in ipairs(self.navButtons) do
            local def = PAGES[i]
            local shown, count = true, nil
            if words then
                count = matchPage(def, words)
                shown = count > 0
            elseif self.pages[def.id] then
                self.pages[def.id]:ApplyFilter(nil)
            end
            b:SetCount(shown and count or nil)
            b:SetShown(shown)
            if shown then
                n = n + 1
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", 8, NAV_TOP - (n - 1) * 20)
                b:SetPoint("TOPRIGHT", -8, NAV_TOP - (n - 1) * 20)
            end
        end
        if words and n == 0 then
            for _, p in pairs(self.pages) do
                p:Hide()
            end
            self.noResults:SetText(format(L["No settings match \"%s\"."], self.searchText or "") .. "\n\n"
                .. U.Color(ns.COLOR.grey, L["Try other words, or press Esc in the search box to see every setting again."]))
            self.noResults:Show()
            return
        end
        self.noResults:Hide()
        local page = self.current and self.pages[self.current]
        if not shows(self.current) or (page and not page:IsShown()) then
            self:SelectPage(self.current)
        end
    end

    function panel:SetSearch(text, typed)
        text = text or ""
        if not typed and self.search:GetText() ~= text then
            self.search:SetText(text)
        end
        self.searchText = U.Trim(text)
        self.words = searchWords(text)
        self.matchers = {}
        self:LayoutNav()
    end

    panel:LayoutNav()
    panel:SelectPage(PAGES[1].id)
    -- Leaving the tab ends the search: the options open with every setting again.
    panel:HookScript("OnHide", function()
        if panel.words then
            panel:SetSearch("")
        end
    end)
end

local function refresh(panel)
    panel:LayoutNav()
    local page = panel.pages and panel.pages[panel.current]
    if page and page:IsShown() then
        page:Refresh()
    end
    panel.reload:SetShown(Options.NeedsReload())
end

UI.RegisterPage({
    id = "options",
    label = L["Options"],
    tip = L["Alerts, tracking, the tooltip, backups and more."],
    order = 3,
    create = create,
    refresh = refresh,
})

-- Opens the Options tab, on a page when given one ("general", "guild", ...).
function UI.ShowOptions(pageId)
    local panel = UI.Show("options")
    if panel and panel.SelectPage and pageId and PAGE_BY_ID[pageId] then
        panel:SetSearch("")
        panel:SelectPage(pageId)
    end
    return panel
end

ns.On("SETTINGS_CHANGED", function()
    UI.Refresh("options")
end)

---------------------------------------------------------------------------
-- The page in the game's settings: the main switches and a way into the window.
---------------------------------------------------------------------------
local blizz

local function buildBlizz()
    blizz = CreateFrame("Frame")
    blizz:Hide()
    local title = W.Label(blizz, L["RepKeeper"], "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    local version = W.Label(blizz, U.Color(ns.COLOR.grey, tostring(ns.version or "")), "GameFontHighlightSmall")
    version:SetPoint("BOTTOMLEFT", title, "BOTTOMRIGHT", 6, 1)
    local text = W.Text(blizz, L["Remember the players you meet: blacklist the ones to avoid, keep track of the good ones. Type /rk to open RepKeeper. Everything else is on its Options tab."], 520)
    text:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    blizz.checks = {}
    local rows = {
        { "tooltipEnabled", L["Show RepKeeper in tooltips"] },
        { "groupWarningEnabled", L["Warn me when a blacklisted player is in my group"] },
    }
    for i, r in ipairs(rows) do
        local get, set = setting(r[1])
        blizz.checks[i] = W.Check(blizz, r[2], nil, get, set)
        blizz.checks[i]:SetPoint("TOPLEFT", 14, -84 - (i - 1) * 26)
    end
    blizz.checks[#blizz.checks + 1] = W.Check(blizz, L["Show the minimap button"], nil, function()
        return not S().minimapButton.hide
    end, function(v)
        S().minimapButton.hide = not v
        if ns.Minimap and ns.Minimap.Refresh then
            ns.Minimap:Refresh()
        end
        changed("minimap")
    end)
    blizz.checks[#blizz.checks]:SetPoint("TOPLEFT", 14, -84 - 2 * 26)
    blizz.open = W.Button(blizz, L["Open RepKeeper"], nil, function()
        if SettingsPanel and SettingsPanel:IsShown() and HideUIPanel then
            HideUIPanel(SettingsPanel)
        end
        UI.Show("players")
    end)
    blizz.open:SetPoint("TOPLEFT", 18, -172)
    local function refreshBlizz()
        for _, cb in ipairs(blizz.checks) do
            cb:Refresh()
        end
    end
    blizz:SetScript("OnShow", refreshBlizz)
    function blizz:OnRefresh()
        refreshBlizz()
    end
    function blizz:OnDefault()
        local d = C.DEFAULTS.global.settings
        S().tooltipEnabled, S().groupWarningEnabled = d.tooltipEnabled, d.groupWarningEnabled
        S().minimapButton.hide = false
        if ns.Minimap and ns.Minimap.Refresh then
            ns.Minimap:Refresh()
        end
        changed("defaults")
        refreshBlizz()
    end
    function blizz:OnCommit() end
    return blizz
end

function Options:Initialize()
    for key in pairs(RELOAD_KEYS) do
        loginValues[key] = S()[key] and true or false
    end
    if blizz or not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then
        return
    end
    buildBlizz()
    local ok, category = pcall(Settings.RegisterCanvasLayoutCategory, blizz, L["RepKeeper"])
    if ok and category then
        pcall(Settings.RegisterAddOnCategory, category)
        self.category = category
    end
end

ns.On("SETTINGS_CHANGED", function()
    if blizz and blizz:IsShown() then
        blizz:OnRefresh()
    end
end)

-- Opens the Options tab (pageId optional).
function Options:Open(pageId)
    UI.ShowOptions(pageId)
end
