--[[
 WowTyrian2k: a World of Warcraft port of OpenTyrian
 Lua port Copyright (C) 2026 voetre
 Licensed under the GNU General Public License v2 or later (see COPYING).

 The jukebox's controls, styled after the game's settings window: a panel
 under the game window (the music and the visualizer) and a track list on
 its right that folds away to a tab.  They stand in for the original's
 keyboard commands.  A control only queues a command; the jukebox loop
 (Game/Jukebox.lua) carries it out and reports back through Jukebox.update.
]]
local _, ns = ...
local _G = _G

local Jukebox = {}
ns.Jukebox = Jukebox

local LIST_W, ROW_H = 240, 18
local PANEL_W, PANEL_H = 660, 160
local COL_W = 320

local queue = {}
local ui                 -- the frames, made on first use
local state = {}         -- what the jukebox last reported

local function send(cmd, arg) queue[#queue + 1] = { cmd, arg } end

-- Hands the queued commands to the jukebox loop.
function Jukebox.take()
	local q = queue
	queue = {}
	return q
end

-- The visualizer's choices.
local PATTERNS = {}
for i = 0, 14 do PATTERNS[#PATTERNS + 1] = { i, i == 0 and "Scatter" or "Pattern " .. i } end
local SPEEDS = {
	{ -2, "Reverse (fast)" }, { -1, "Reverse" }, { 0, "Stopped" }, { 1, "Slow" }, { 2, "Normal" },
	{ 3, "Quick" }, { 4, "Fast" }, { 6, "Faster" }, { 9, "Warp" },
}
-- where in the palette the stars' 32 colours start
local COLOURS = {
	{ 32, "Rainbow" }, { 56, "Pastel" }, { 80, "Pale" }, { 104, "Deep" },
	{ 128, "Muted" }, { 152, "Dusk" }, { 176, "Night" }, { 16, "Silver" },
}

-- looks ----------------------------------------------------------------------------

local function hasAtlas(name)
	return _G.C_Texture and _G.C_Texture.GetAtlasInfo and _G.C_Texture.GetAtlasInfo(name) ~= nil
end

-- The settings window's dark inset panel.
local function panelFrame(parent) return ns.panelFrame(parent) end

-- A section heading with the settings window's divider under it.
local function heading(parent, text, x, y, width)
	local h = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
	h:SetPoint("TOPLEFT", x, y)
	h:SetText(text)
	local line = parent:CreateTexture(nil, "ARTWORK")
	if hasAtlas("Options_HorizontalDivider") then
		line:SetAtlas("Options_HorizontalDivider")
	else
		line:SetColorTexture(1, 1, 1, 0.15)
	end
	line:SetHeight(1)
	line:SetPoint("TOPLEFT", x, y - 22)
	line:SetWidth(width)
	return h
end

local function label(parent, text, x, y)
	local l = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	l:SetPoint("TOPLEFT", x, y - 4)
	l:SetJustifyH("LEFT")
	l:SetText(text)
	return l
end

local function tip(f, text)
	f:HookScript("OnEnter", function(self)
		_G.GameTooltip:SetOwner(self, "ANCHOR_TOP")
		_G.GameTooltip:SetText(type(text) == "function" and text() or text, 1, 1, 1)
		_G.GameTooltip:Show()
	end)
	f:HookScript("OnLeave", function() _G.GameTooltip:Hide() end)
end

local function button(parent, text, width, onClick, tooltip)
	local b = _G.CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetSize(width, 22)
	b:SetText(text)
	b:SetScript("OnClick", onClick)
	if tooltip then tip(b, tooltip) end
	return b
end

-- The settings window's checkbox (the minimal one), label on its right.
local function checkbox(parent, text, x, y, onClick, tooltip)
	local cb
	if hasAtlas("checkbox-minimal") then
		cb = _G.CreateFrame("CheckButton", nil, parent)
		cb:SetSize(24, 24)
		cb:SetNormalAtlas("checkbox-minimal")
		cb:SetPushedAtlas("checkbox-minimal")
		local check = cb:CreateTexture()
		check:SetAtlas("checkmark-minimal")
		cb:SetCheckedTexture(check)
		cb:SetHighlightAtlas("checkbox-minimal", "ADD")
		local hl = cb:GetHighlightTexture()
		if hl then hl:SetAlpha(0.25) end
	else
		cb = _G.CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
		cb:SetSize(24, 24)
	end
	cb:SetPoint("TOPLEFT", x, y)
	local t = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	t:SetPoint("LEFT", cb, "RIGHT", 4, 0)
	t:SetText(text)
	cb.label = t
	cb:SetScript("OnClick", function(self) onClick(self:GetChecked() and true or false) end)
	if tooltip then tip(cb, tooltip) end
	return cb
end

-- The settings window's dropdown with arrows either side, or a plain
-- "< value >" stand-in where the client hasn't got it.  get/set work on the
-- choice's value.
local function choice(parent, choices, x, y, get, set, tooltip)
	local w = ns.settingsDropdown and ns.settingsDropdown(parent, choices, get, set, 170)
	if w then
		w:SetPoint("TOPLEFT", x, y)
		if tooltip then tip(w.Dropdown, tooltip) end
		return w
	end
	local mid
	local function step(dir)
		local cur = 1
		for i, c in ipairs(choices) do if c[1] == get() then cur = i end end
		set(choices[(cur - 1 + dir) % #choices + 1][1])
		w.refresh()
	end
	w = _G.CreateFrame("Frame", nil, parent)
	w:SetSize(230, 22)
	w:SetPoint("TOPLEFT", x, y)
	local left = button(w, "<", 24, function() step(-1) end)
	left:SetPoint("LEFT", 0, 0)
	mid = button(w, "", 170, function() step(1) end, tooltip)
	mid:SetPoint("LEFT", left, "RIGHT", 2, 0)
	local right = button(w, ">", 24, function() step(1) end)
	right:SetPoint("LEFT", mid, "RIGHT", 2, 0)
	w.Dropdown = mid
	w.refresh = function()
		for _, c in ipairs(choices) do if c[1] == get() then mid:SetText(c[2]) end end
	end
	w.choose = function(v) set(v) w.refresh() end
	w.Step = step
	return w
end

-- Media buttons: icons from Textures/media.tga (tools/make_media_icons.py).
local MEDIA = "Interface\\AddOns\\WowTyrian2k\\Textures\\media"
local ICON = { prev = 0, play = 1, stop = 2, next = 3, shuffle = 4, loop = 5, circle = 6 }
local GOLD = { 1, 0.82, 0 }

local function setIcon(tex, name)
	local i = ICON[name]
	tex:SetTexture(MEDIA)
	tex:SetTexCoord(i / 8, (i + 1) / 8, 0, 1)
end

-- An icon button, dimmed until the mouse is over it.  A toggle (on) shows
-- gold with a dot under it while it's on.
local function mediaButton(parent, icon, size, onClick, tooltip)
	local b = _G.CreateFrame("Button", nil, parent)
	b:SetSize(size, size)
	local t = b:CreateTexture(nil, "ARTWORK")
	t:SetSize(size - 8, size - 8)
	t:SetPoint("CENTER")
	setIcon(t, icon)
	b.icon = t
	local function tint()
		local over = b:IsMouseOver()
		if b.on then
			t:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 1)
		else
			local v = over and 1 or 0.7
			t:SetVertexColor(v, v, v, 1)
		end
	end
	b.tint = tint
	b:SetScript("OnMouseDown", function() t:SetPoint("CENTER", 1, -1) end)
	b:SetScript("OnMouseUp", function() t:SetPoint("CENTER") end)
	b:SetScript("OnClick", onClick)
	b:HookScript("OnEnter", tint)
	b:HookScript("OnLeave", tint)
	if tooltip then tip(b, tooltip) end
	b.setOn = function(on)
		b.on = on
		if b.dot then b.dot:SetShown(on) end
		tint()
	end
	tint()
	return b
end

local function toggleButton(parent, icon, size, onClick, tooltip)
	local b = mediaButton(parent, icon, size, onClick, tooltip)
	local dot = b:CreateTexture(nil, "ARTWORK")
	dot:SetSize(4, 4)
	dot:SetPoint("TOP", b, "BOTTOM", 0, 3)
	setIcon(dot, "circle")
	dot:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 1)
	dot:Hide()
	b.dot = dot
	return b
end

local function clock(t)
	t = math.floor(t + 0.5)
	return string.format("%d:%02d", math.floor(t / 60), t % 60)
end

-- the panel ------------------------------------------------------------------------

-- The song's progress: time, bar and length, `width` wide.  Display only:
-- WoW can't start a song partway through, so there's no seeking.
local function progressBar(parent, width)
	local f = _G.CreateFrame("Frame", nil, parent)
	f:SetSize(width, 12)
	local elapsed = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	elapsed:SetPoint("LEFT")
	elapsed:SetWidth(34)
	elapsed:SetJustifyH("LEFT")
	local total = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	total:SetPoint("RIGHT")
	total:SetWidth(34)
	total:SetJustifyH("RIGHT")
	local barW = width - 80
	local bg = f:CreateTexture(nil, "ARTWORK")
	bg:SetColorTexture(1, 1, 1, 0.15)
	bg:SetSize(barW, 4)
	bg:SetPoint("LEFT", elapsed, "RIGHT", 6, 0)
	local fill = f:CreateTexture(nil, "ARTWORK", nil, 1)
	fill:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
	fill:SetHeight(4)
	fill:SetPoint("LEFT", bg, "LEFT")
	local head = f:CreateTexture(nil, "ARTWORK", nil, 2)
	setIcon(head, "circle")
	head:SetSize(10, 10)
	f.elapsed, f.total, f.fill, f.head, f.bg, f.w = elapsed, total, fill, head, bg, barW
	-- the bar's tooltip
	local hover = _G.CreateFrame("Frame", nil, f)
	hover:SetPoint("TOPLEFT", bg, "TOPLEFT", -4, 8)
	hover:SetPoint("BOTTOMRIGHT", bg, "BOTTOMRIGHT", 4, -8)
	hover:EnableMouse(true)
	tip(hover, "Song Progress")
	ui.progresses[#ui.progresses + 1] = f
	return f
end

local function updateProgress()
	local t, len = ns.songPosition()
	for _, pr in ipairs(ui.progresses) do
		if not t or len <= 0 then
			pr.elapsed:SetText("0:00")
			pr.total:SetText(len and clock(len) or "-:--")
			pr.fill:Hide()
			pr.head:Hide()
		else
			pr.elapsed:SetText(clock(t))
			pr.total:SetText(clock(len))
			local fw = math.max(1, pr.w * t / len)
			pr.fill:SetWidth(fw)
			pr.fill:Show()
			pr.head:ClearAllPoints()
			pr.head:SetPoint("CENTER", pr.bg, "LEFT", fw, 0)
			pr.head:Show()
		end
	end
end

-- Shuffle, previous, play/stop, next and loop in a row; there's one in the
-- panel and one in the compact bar, both kept up to date.
local TRANSPORT_W = 216
local function transport(parent)
	local f = _G.CreateFrame("Frame", nil, parent)
	f:SetSize(TRANSPORT_W, 36)

	local play = _G.CreateFrame("Button", nil, f)
	play:SetSize(36, 36)
	play:SetPoint("CENTER")
	local disc = play:CreateTexture(nil, "ARTWORK")
	disc:SetAllPoints()
	setIcon(disc, "circle")
	local pi = play:CreateTexture(nil, "ARTWORK", nil, 1)
	pi:SetSize(20, 20)
	pi:SetPoint("CENTER")
	pi:SetVertexColor(0.05, 0.05, 0.06, 1)
	play.icon = pi
	local function discTint() local v = play:IsMouseOver() and 1 or 0.85 disc:SetVertexColor(v, v, v, 1) end
	play:SetScript("OnEnter", discTint)
	play:SetScript("OnLeave", discTint)
	play:SetScript("OnMouseDown", function() play:SetScale(0.94) end)
	play:SetScript("OnMouseUp", function() play:SetScale(1) end)
	play:SetScript("OnClick", function() send("playstop") end)
	tip(play, function() return state.stopped and "Play" or "Stop" end)
	discTint()
	f.playstop = play

	local prev = mediaButton(f, "prev", 30, function() send("prev") end, "Previous Track")
	prev:SetPoint("RIGHT", play, "LEFT", -12, 0)
	local nxt = mediaButton(f, "next", 30, function() send("next") end, "Next Track")
	nxt:SetPoint("LEFT", play, "RIGHT", 12, 0)
	f.shuffle = toggleButton(f, "shuffle", 28, function() send("shuffle") end, "Shuffle")
	f.shuffle:SetPoint("RIGHT", prev, "LEFT", -20, 0)
	f.loop = toggleButton(f, "loop", 28, function() send("loop") end, "Loop")
	f.loop:SetPoint("LEFT", nxt, "RIGHT", 20, 0)

	ui.transports[#ui.transports + 1] = f
	return f
end

local function buildPanel(root)
	local p = panelFrame(root)
	p:SetSize(PANEL_W, PANEL_H)
	ui.panel = p

	-- now playing, on the left
	local x, w = 14, COL_W - 28
	local title = p:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", x, -12)
	title:SetWidth(w)
	title:SetJustifyH("LEFT")
	title:SetWordWrap(false)
	ui.title = title
	local track = p:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	track:SetPoint("TOPLEFT", x, -34)
	track:SetJustifyH("LEFT")
	ui.track = track

	local bar = progressBar(p, w)
	bar:SetPoint("TOPLEFT", x, -48)

	-- the transport buttons, centred under the bar
	local tr = transport(p)
	tr:SetPoint("CENTER", p, "TOPLEFT", x + w / 2, -90)

	ui.showtext = checkbox(p, "Song title on screen", x - 2, -122, function(v) send("text", v) end,
		"Show Song Title")
	local quit = button(p, "Leave Jukebox", 110, function() send("quit") end, "Leave Jukebox")
	quit:SetPoint("TOPRIGHT", p, "TOPLEFT", x + w, -122)

	-- the progress bars follow the song every frame
	p:SetScript("OnUpdate", updateProgress)

	-- the visualizer, on the right
	x = COL_W + 10
	heading(p, "Visualizer", x, -10, COL_W - 24)
	local cx = x + 64
	label(p, "Pattern", x, -40)
	ui.pattern = choice(p, PATTERNS, cx, -40, function() return state.pattern end,
		function(v) state.pattern = v send("pattern", v) end, "Pattern")
	label(p, "Speed", x, -68)
	ui.speed = choice(p, SPEEDS, cx, -68, function() return state.speed end,
		function(v) state.speed = v send("speed", v) end, "Speed")
	label(p, "Colours", x, -96)
	ui.colour = choice(p, COLOURS, cx, -96, function() return state.colour end,
		function(v) state.colour = v send("colour", v) end, "Colours")
	ui.autochange = checkbox(p, "Change pattern by itself", x - 2, -124, function(v) send("autochange", v) end,
		"Auto-Change Pattern")
	local reset = button(p, "Reset", 70, function() send("reset") end, "Reset Visualizer")
	reset:SetPoint("BOTTOMRIGHT", -12, 10)
end

local function buildList(root)
	local list = panelFrame(root)
	-- beside the panel, under the game window
	list:SetPoint("TOPLEFT", ui.panel, "TOPRIGHT", 2, 0)
	list:SetSize(LIST_W, PANEL_H)
	ui.list = list

	local fold = button(list, "<<", 30, function() Jukebox.setListOpen(false) end, "Hide Track List")
	fold:SetHeight(20)
	fold:SetPoint("TOPLEFT", 6, -6)
	heading(list, "Tracks", 42, -8, LIST_W - 52)

	local scroll = _G.CreateFrame("ScrollFrame", nil, list)
	scroll:SetPoint("TOPLEFT", 6, -36)
	scroll:SetPoint("BOTTOMRIGHT", -20, 6)
	local content = _G.CreateFrame("Frame", nil, scroll)
	content:SetSize(LIST_W - 28, ROW_H * ns.G.MUSIC_NUM)
	scroll:SetScrollChild(content)
	ui.scroll = scroll

	-- the game's thin scroll bar where it has one, else the wheel only
	local ok, bar = pcall(_G.CreateFrame, "EventFrame", nil, list, "MinimalScrollBar")
	if ok and bar and _G.ScrollUtil and _G.ScrollUtil.InitScrollFrameWithScrollBar then
		bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 4, 0)
		bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 4, 0)
		_G.ScrollUtil.InitScrollFrameWithScrollBar(scroll, bar)
	else
		if ok and bar then bar:Hide() end
		scroll:EnableMouseWheel(true)
		scroll:SetScript("OnMouseWheel", function(self, delta)
			local max = self:GetVerticalScrollRange() or 0
			self:SetVerticalScroll(math.max(0, math.min(max, self:GetVerticalScroll() - delta * ROW_H * 3)))
		end)
	end

	ui.rows = {}
	for i = 0, ns.G.MUSIC_NUM - 1 do
		local r = _G.CreateFrame("Button", nil, content)
		r:SetHeight(ROW_H)
		r:SetPoint("TOPLEFT", 0, -i * ROW_H)
		r:SetPoint("RIGHT", content, "RIGHT", 0, 0)
		local hl = r:CreateTexture(nil, "HIGHLIGHT")
		hl:SetAllPoints()
		hl:SetColorTexture(1, 1, 1, 0.08)
		local sel = r:CreateTexture(nil, "BACKGROUND")
		sel:SetAllPoints()
		if hasAtlas("Options_List_Active") then sel:SetAtlas("Options_List_Active") else sel:SetColorTexture(1, 0.82, 0, 0.2) end
		sel:Hide()
		r.sel = sel
		local num = r:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
		num:SetPoint("LEFT", 4, 0)
		num:SetWidth(18)
		num:SetJustifyH("RIGHT")
		num:SetText(i + 1)
		local t = r:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		t:SetPoint("LEFT", num, "RIGHT", 6, 0)
		t:SetPoint("RIGHT", -2, 0)
		t:SetJustifyH("LEFT")
		t:SetWordWrap(false)
		t:SetText(ns.G.musicTitle[i] or "")
		r.text = t
		r:SetScript("OnClick", function() send("play", i) end)
		ui.rows[i] = r
	end

	-- in the panel's corner: compact, and (with the list folded away) a
	-- button that opens the list
	local compact = button(ui.panel, "Compact", 70, function() Jukebox.setCompact(true) end, "Compact View")
	compact:SetPoint("TOPRIGHT", -10, -8)
	local tab = button(ui.panel, "Tracks", 70, function() Jukebox.setListOpen(true) end, "Show Track List")
	tab:SetPoint("RIGHT", compact, "LEFT", -4, 0)
	ui.tab = tab
end

-- The compact bar: the song's title and progress, the transport buttons and a button to
-- go back to the full controls.
local COMPACT_W, COMPACT_H = 560, 56
local function buildCompact(root)
	local c = panelFrame(root)
	c:SetSize(COMPACT_W, COMPACT_H)
	c:SetPoint("TOP", ns.chrome, "BOTTOM", 0, -2)
	ui.compact = c

	local title = c:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	title:SetPoint("TOPLEFT", 14, -12)
	title:SetWidth(220)
	title:SetJustifyH("LEFT")
	title:SetWordWrap(false)
	ui.compactTitle = title
	local bar = progressBar(c, 220)
	bar:SetPoint("TOPLEFT", 14, -32)
	c:SetScript("OnUpdate", updateProgress)

	local tr = transport(c)
	tr:SetPoint("LEFT", 250, 0)

	local expand = button(c, "Expand", 70, function() Jukebox.setCompact(false) end, "Expand Controls")
	expand:SetPoint("RIGHT", -10, 0)
end

local function build()
	local root = ns.root
	ui = { transports = {}, progresses = {} }
	buildPanel(root)
	buildList(root)
	buildCompact(root)
	for _, f in ipairs({ ui.panel, ui.list, ui.compact }) do
		f:SetFrameLevel(root:GetFrameLevel() + 600)   -- above the fade overlay
		f:Hide()
	end
	ui.tab:Hide()
end

local function db() return ns.db or {} end

-- Shows the full controls (with the list beside them, if it's open) or
-- the compact bar, centred under the game window.
local function layout()
	if not ui or not ui.active then return end
	local d = db()
	local compact, open = d.jukeboxCompact, d.jukeboxList ~= false
	ui.compact:SetShown(compact)
	ui.panel:SetShown(not compact)
	ui.list:SetShown(open and not compact)
	ui.tab:SetShown(not open)
	ui.panel:ClearAllPoints()
	ui.panel:SetPoint("TOP", ns.chrome, "BOTTOM", open and -(LIST_W + 2) / 2 or 0, -2)
end

function Jukebox.setListOpen(open)
	if ns.db then ns.db.jukeboxList = open and true or false end
	layout()
end

function Jukebox.setCompact(on)
	if ns.db then ns.db.jukeboxCompact = on and true or false end
	layout()
end

-- The jukebox starting: show the controls.
function Jukebox.open()
	if not ns.root then return end
	if not ui then build() end
	queue = {}
	state = {}
	ui.active = true
	layout()
end

-- The jukebox ending, or the game it was in going away.
function Jukebox.close()
	queue = {}
	if not ui then return end
	ui.active = false
	ui.panel:Hide()
	ui.list:Hide()
	ui.compact:Hide()
end

-- for the test harness
function Jukebox.widgets() return ui end
Jukebox._send = send

-- s = { song, stopped, shuffle, loop, showText, pattern, autoChange, speed, colour }
function Jukebox.update(s)
	if not ui then return end
	local old = state
	state = s
	if s.song ~= old.song then
		local prev = old.song and ui.rows[old.song]
		if prev then prev.sel:Hide() prev.text:SetFontObject("GameFontHighlightSmall") end
		local r = ui.rows[s.song]
		if r then
			r.sel:Show()
			r.text:SetFontObject("GameFontNormalSmall")
			-- keep the playing song in view
			local top, h = ui.scroll:GetVerticalScroll(), ui.scroll:GetHeight() or 0
			local y = s.song * ROW_H
			if h > 0 and (y < top or y + ROW_H > top + h) then
				local max = ui.scroll:GetVerticalScrollRange() or 0
				ui.scroll:SetVerticalScroll(math.max(0, math.min(max, y - h / 2)))
			end
		end
	end
	if s.song ~= old.song then
		local name = ns.G.musicTitle[s.song]
		ui.title:SetText(name or "No song")
		ui.compactTitle:SetText(name and string.format("%d. %s", s.song + 1, name) or "No song")
		ui.track:SetText(name and string.format("Track %d of %d", s.song + 1, ns.G.MUSIC_NUM) or "")
	end
	for _, tr in ipairs(ui.transports) do
		if s.stopped ~= old.stopped then setIcon(tr.playstop.icon, s.stopped and "play" or "stop") end
		if s.shuffle ~= old.shuffle then tr.shuffle.setOn(s.shuffle) end
		if s.loop ~= old.loop then tr.loop.setOn(s.loop) end
	end
	if s.showText ~= old.showText then ui.showtext:SetChecked(s.showText) end
	if s.autoChange ~= old.autoChange then ui.autochange:SetChecked(s.autoChange) end
	if s.pattern ~= old.pattern then ui.pattern.refresh() end
	if s.speed ~= old.speed then ui.speed.refresh() end
	if s.colour ~= old.colour then ui.colour.refresh() end
end
