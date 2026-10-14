--[[
 WowTyrian2k: a World of Warcraft port of OpenTyrian
 Copyright (C) The OpenTyrian Development Team
 Lua port Copyright (C) 2026 voetre
 Licensed under the GNU General Public License v2 or later (see COPYING).

 Addon options: a page in the WoW Options > AddOns list with the game
 settings, and sub-pages for the window, flight mode, generated levels,
 statistics, cheats and advanced settings.  Settings are stored in
 WowTyrian2kDB.
]]
local addonName, ns = ...
setfenv(1, ns.G)

local _G = _G_REAL

-- Read by the game every frame (see applyCheats); replaced by the saved
-- table once the saved variables are loaded.
cheats = {}

local defaults = {
	skipLogos = false,
	controlVolume = true,
	-- window
	lockWindow = false,
	alpha = 100,
	onHide = "pause",      -- closing the window: "pause" or "end" the game
	onCombat = "pause",    -- entering combat: hide and "pause", hide and "end", or "keep" playing
	hideOnAlert = false,   -- hide for ready checks, queue pops and whispers
	-- flight mode
	flightMode = "ask",    -- when a flight starts: "ask", "start" a game, or "off"
	flightTheme = "random",
	flightMinLevel = 75,   -- shortest level offered, in seconds
	flightMargin = 10,     -- seconds a level ends before the landing
	flightBar = true,
	-- generated levels
	genDifficulty = 0,     -- added to the difficulty level
	genPower = -1,         -- arcade power factor in %, or -1 for automatic
	genDrops = 1,          -- drop chance multiplier
	genDensity = "normal",
	genBonus = true,
	bonusMin = 60,         -- flight seconds needed for a bonus level
	scoreCard = true,
	keepOpen = false,      -- back to the title screen after the score card
	randomMusic = true,
	scoreCardMusic = true,
	-- cheats
	noFlightCheats = false,
}

local cheatList = {
	{ key = "shield", name = "Infinite shield", desc = "Your shield is always full." },
	{ key = "armor", name = "Infinite armour", desc = "Your armour never drops below its starting value." },
	{ key = "invincible", name = "Invincible", desc = "Enemy shots and ships do no damage to your ship." },
	{ key = "instantKill", name = "Instant kill", desc = "One hit destroys any enemy that can be destroyed." },
	{ key = "power", name = "Infinite generator power", desc = "The generator never runs out, so weapons always fire at full rate." },
	{ key = "ammo", name = "Infinite sidekick ammo", desc = "Sidekicks with limited ammunition never run out." },
	{ key = "credits", name = "Unlimited credits", desc = "You always have at least 1,000,000 credits in the upgrade shop." },
	{ key = "shopUnlock", name = "All shop items", desc = "The upgrade shop sells every item from every episode's shop." },
	{ key = "secretUnlock", name = "Secret items", desc = "The upgrade shop also sells the secret items no shop normally has, such as the Nort Ship, the Stalker and the Banana Blast." },
}

-- Called each frame from JE_mainGamePlayerFunctions.
function applyCheats()
	local p = player[0]
	local redraw = false
	if cheats.shield and p.shield ~= p.shield_max then
		p.shield = p.shield_max
		redraw = true
	end
	if cheats.armor and p.armor < p.initial_armor then
		p.armor = p.initial_armor
		redraw = true
	end
	if redraw then
		-- the bars live on the HUD, which is only redrawn on change
		local s = VGAScreen
		VGAScreen = VGAScreenSeg
		JE_drawShield()
		JE_drawArmor()
		VGAScreen = s
	end
	if cheats.power then power = 900 end
	if cheats.ammo then
		for i = 0, 1 do
			local sk = p.sidekick[i]
			if sk.ammo_max > 0 then sk.ammo = sk.ammo_max end
		end
	end
end

function ns.optionsInit()
	local db = ns.db
	db.options = db.options or {}
	-- the flight prompt setting used to live in db.flightPrompt
	if db.flightPrompt == false and db.options.flightMode == nil then db.options.flightMode = "off" end
	db.flightPrompt = nil
	for k, v in pairs(defaults) do
		if db.options[k] == nil then db.options[k] = v end
	end
	db.options.cheats = db.options.cheats or {}
	cheats = db.options.cheats
	ns.options = db.options

	-- The game settings live in the game's own configuration, so the
	-- options page and the in-game menus stay in step.
	loadConfiguration()
	ns.restoreAudioCVars()

	ns.minimapInit()

	local ok, err = pcall(ns.registerOptionsPanel)
	if not ok then ns.Print("could not create the options page: " .. tostring(err)) end
end

-- Widgets ---------------------------------------------------------------------------

local function header(panel, text, sub)
	local t = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	t:SetPoint("TOPLEFT", 16, -16)
	t:SetText(text)
	local s = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	s:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -8)
	s:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
	s:SetJustifyH("LEFT")
	s:SetText(sub)
	return s
end

local function sectionTitle(panel, anchor, text)
	local t = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	t:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -20)
	t:SetText(text)
	return t
end

local function tooltip(widget, title, text)
	-- hooked, not replaced, on the game's own widgets that already have
	-- mouse-over scripts
	local function on(script, fn)
		if widget.HookScript and widget:GetScript(script) then widget:HookScript(script, fn) else widget:SetScript(script, fn) end
	end
	on("OnEnter", function(self)
		_G.GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		_G.GameTooltip:SetText(title, 1, 1, 1)
		_G.GameTooltip:AddLine(text, nil, nil, nil, true)
		_G.GameTooltip:Show()
	end)
	on("OnLeave", function() _G.GameTooltip:Hide() end)
end

local function checkbox(panel, anchor, label, desc, get, set, indent)
	local cb = _G.CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
	cb:SetSize(26, 26)
	cb:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", indent or 0, -6)
	local text = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
	text:SetText(label)
	cb:SetScript("OnClick", function(self)
		local on = self:GetChecked() and true or false
		_G.PlaySound(on and 856 or 857) -- igMainMenuOptionCheckBoxOn/Off
		set(on)
	end)
	tooltip(cb, label, desc)
	cb.refresh = function() cb:SetChecked(get() and true or false) end
	panel.widgets[#panel.widgets + 1] = cb
	return cb
end

-- A plain slider built from textures, so it does not depend on templates
-- that differ between client versions.
-- The game's own settings slider (MinimalSliderWithSteppersTemplate, with
-- its arrow buttons and the value on the right), or the older UI slider on
-- clients without it.
local function slider(panel, anchor, label, desc, minV, maxV, step, fmt, get, set, indent)
	local text = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	text:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", indent or 0, -14)
	text:SetWidth(150)
	text:SetJustifyH("LEFT")
	text:SetText(label)

	local updating = false
	local function take(v)
		v = math.floor(v / step + 0.5) * step
		if not updating and v ~= get() then set(v) end
		return v
	end

	local w
	local M = _G.MinimalSliderWithSteppersMixin
	local ok, made = pcall(_G.CreateFrame, "Frame", nil, panel, "MinimalSliderWithSteppersTemplate")
	if M and ok and made and made.Init and made.RegisterCallback then
		w = made
		w:SetWidth(250)
		w:SetPoint("LEFT", text, "RIGHT", 4, 0)
		local formatters = {}
		if M.Label then formatters[M.Label.Right] = fmt end
		w:Init(get(), minV, maxV, math.floor((maxV - minV) / step + 0.5), formatters)
		w:RegisterCallback(M.Event.OnValueChanged, function(_, v) take(v) end, w)
		w.refresh = function()
			updating = true
			w:SetValue(get())
			updating = false
		end
		if w.Slider then tooltip(w.Slider, label, desc) end
	else
		local template = _G.WOW_PROJECT_ID == nil and "OptionsSliderTemplate" or "UISliderTemplate"
		w = _G.CreateFrame("Slider", nil, panel, template)
		w:SetOrientation("HORIZONTAL")
		w:SetSize(200, 16)
		w:SetPoint("LEFT", text, "RIGHT", 10, 0)
		w:SetMinMaxValues(minV, maxV)
		w:SetValueStep(step)
		if w.SetObeyStepOnDrag then w:SetObeyStepOnDrag(true) end
		-- OptionsSliderTemplate's own labels are not used
		for _, k in ipairs({ "Text", "Low", "High" }) do
			local f = rawget(w, k)
			if type(f) == "table" and f.SetText then f:SetText("") end
		end
		local value = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
		value:SetPoint("LEFT", w, "RIGHT", 10, 0)
		w:SetScript("OnValueChanged", function(self, v) value:SetText(fmt(take(v))) end)
		w.refresh = function()
			updating = true
			local v = get()
			w:SetValue(v)
			value:SetText(fmt(v))
			updating = false
		end
	end
	tooltip(w, label, desc)
	panel.widgets[#panel.widgets + 1] = w
	return text
end

-- A dropdown menu of `choices` ({ value, text } pairs).
local ROW = 18
local openList            -- the dropdown list that is open, if any

local function closeList()
	if openList then openList:Hide() end
	openList = nil
end

-- a click anywhere else closes an open list
local closer = _G.CreateFrame("Frame")
if pcall(closer.RegisterEvent, closer, "GLOBAL_MOUSE_DOWN") then
	closer:SetScript("OnEvent", function()
		if openList and not openList:IsMouseOver() and not openList.owner:IsMouseOver() then closeList() end
	end)
end

local backdropTemplate = _G.BackdropTemplateMixin and "BackdropTemplate" or nil
local function setBackdrop(f, alpha)
	if not f.SetBackdrop then return end
	f:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 },
	})
	f:SetBackdropColor(0, 0, 0, alpha)
end

-- The game's settings dropdown (SettingsDropdownWithButtonsTemplate: arrows
-- either side to step through the choices, and the game's own menu), not
-- yet placed; nil where the client hasn't got it.  Also used by the jukebox.
function ns.settingsDropdown(parent, choices, get, set, width)
	if not _G.MenuUtil then return end
	local ok, w = pcall(_G.CreateFrame, "Frame", nil, parent, "SettingsDropdownWithButtonsTemplate")
	if not (ok and w and w.Dropdown and w.Dropdown.SetupMenu) then return end
	local d = w.Dropdown
	d:SetWidth(width or 200)
	local function sync() if d.GenerateMenu then d:GenerateMenu() end end
	d:SetupMenu(function(_, root)
		for _, c in ipairs(choices) do
			root:CreateRadio(c[2], function() return get() == c[1] end,
				function()
					set(c[1])
					sync()
				end, c[1])
		end
	end)
	w.refresh = sync
	-- for the test harness: pick a choice as the menu would
	w.choose = function(v) set(v) sync() end
	return w
end

-- ... placed after an options page's label, or the plain one below.
local function gameDropdown(panel, text, label, desc, choices, get, set)
	local w = ns.settingsDropdown(panel, choices, get, set)
	if not w then return end
	w:SetPoint("LEFT", text, "RIGHT", 4, 0)
	tooltip(w.Dropdown, label, desc)
	return w
end

local function dropdown(panel, anchor, label, desc, choices, get, set, indent)
	local text = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	text:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", indent or 0, -14)
	text:SetWidth(150)
	text:SetJustifyH("LEFT")
	text:SetText(label)

	local w = gameDropdown(panel, text, label, desc, choices, get, set)
	if w then
		panel.widgets[#panel.widgets + 1] = w
		return text
	end

	local b = _G.CreateFrame("Button", nil, panel, backdropTemplate)
	b:SetSize(200, 24)
	b:SetPoint("LEFT", text, "RIGHT", 10, 0)
	setBackdrop(b, 0.6)
	b.value = b:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	b.value:SetPoint("LEFT", 8, 0)
	b.value:SetPoint("RIGHT", -22, 0)
	b.value:SetJustifyH("LEFT")
	local arrow = b:CreateTexture(nil, "ARTWORK")
	arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
	arrow:SetRotation(-math.pi / 2)
	arrow:SetSize(14, 14)
	arrow:SetPoint("RIGHT", -6, 0)
	b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

	local list = _G.CreateFrame("Frame", nil, b, backdropTemplate)
	list.owner = b
	list:SetFrameStrata("FULLSCREEN_DIALOG")
	list:SetPoint("TOPLEFT", b, "BOTTOMLEFT", 0, -2)
	list:SetSize(200, 8 + ROW * #choices)
	list:EnableMouse(true)
	setBackdrop(list, 0.95)
	list:Hide()
	list:SetScript("OnHide", function(self) if openList == self then openList = nil end end)

	local rows = {}
	for i, c in ipairs(choices) do
		local r = _G.CreateFrame("Button", nil, list)
		r:SetHeight(ROW)
		r:SetPoint("TOPLEFT", 4, -4 - (i - 1) * ROW)
		r:SetPoint("RIGHT", list, "RIGHT", -4, 0)
		r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
		r.check = r:CreateTexture(nil, "ARTWORK")
		r.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
		r.check:SetSize(16, 16)
		r.check:SetPoint("LEFT", 2, 0)
		local t = r:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		t:SetPoint("LEFT", 20, 0)
		t:SetText(c[2])
		r:SetScript("OnClick", function()
			_G.PlaySound(856)
			set(c[1])
			closeList()
			b.refresh()
		end)
		rows[i] = r
	end

	b.refresh = function()
		local v = get()
		local shownText = choices[1][2]
		for i, c in ipairs(choices) do
			local on = c[1] == v
			if on then shownText = c[2] end
			rows[i].check:SetShown(on)
		end
		b.value:SetText(shownText)
	end
	b:SetScript("OnClick", function()
		local wasOpen = openList == list
		closeList()
		if wasOpen then return end
		_G.PlaySound(856)
		b.refresh()
		list:Show()
		openList = list
	end)
	b:SetScript("OnHide", function() if openList == list then closeList() end end)
	tooltip(b, label, desc)
	panel.widgets[#panel.widgets + 1] = b
	return text
end

local function actionButton(panel, anchor, label, desc, onClick, indent)
	local b = _G.CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	b:SetSize(200, 22)
	b:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", indent or 0, -14)
	b:SetText(label)
	b:SetScript("OnClick", onClick)
	tooltip(b, label, desc)
	return b
end

local function note(panel, anchor, text, indent)
	local n = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	n:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", indent or 0, -10)
	n:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
	n:SetJustifyH("LEFT")
	n:SetText(text)
	return n
end

-- Runs fn after a Yes in a confirmation dialog.
local function confirm(text, fn)
	if not _G.StaticPopup_Show then return fn() end
	_G.StaticPopupDialogs.WOWTYRIAN2K_CONFIRM = _G.StaticPopupDialogs.WOWTYRIAN2K_CONFIRM or {
		text = "%s", button1 = _G.YES or "Yes", button2 = _G.NO or "No",
		OnAccept = function(self, data) data() end,
		timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
	}
	_G.StaticPopup_Show("WOWTYRIAN2K_CONFIRM", text, nil, fn)
end

local panels = {}

local function newPanel(name)
	local p = _G.CreateFrame("Frame")
	p.name = name
	p.widgets = {}
	p:Hide()
	p:SetScript("OnShow", function(self)
		for i = 1, #self.widgets do self.widgets[i].refresh() end
	end)
	panels[#panels + 1] = p
	return p
end

local function refreshPanels()
	for _, p in ipairs(panels) do
		if p:IsShown() then
			for i = 1, #p.widgets do p.widgets[i].refresh() end
		end
	end
end

-- Pages ----------------------------------------------------------------------------

local function percent(v) return string.format("%d%%", v) end

local function saveConfig()
	saveConfiguration()
end

local function metadata(field)
	local get = (_G.C_AddOns and _G.C_AddOns.GetAddOnMetadata) or _G.GetAddOnMetadata
	return get and get(addonName, field)
end

-- The top page: the Tyrian logo, what the addon is, how to play and the
-- credits.  The settings are on the sub-pages.
local LOGO = "Interface\\AddOns\\WowTyrian2k\\Textures\\table3_p8"  -- title screen palette
local URL = "https://github.com/voetre/WowTyrian2k"

local function buildMainPanel()
	local p = newPanel(addonName)

	-- the title screen logo: sprite 146 of the planet shapes, 304x121 at
	-- (1,1) of a 512x512 atlas
	local logo = p:CreateTexture(nil, "ARTWORK")
	logo:SetTexture(LOGO, nil, nil, "NEAREST")
	logo:SetTexCoord(1 / 512, 305 / 512, 1 / 512, 122 / 512)
	logo:SetSize(304, 121)
	logo:SetPoint("TOPLEFT", 12, -12)

	local open = _G.CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
	open:SetSize(140, 22)
	open:SetPoint("TOPRIGHT", -16, -16)
	open:SetText("Play Tyrian")
	open:SetScript("OnClick", function()
		if _G.SettingsPanel and _G.SettingsPanel:IsShown() then _G.HideUIPanel(_G.SettingsPanel) end
		if _G.InterfaceOptionsFrame and _G.InterfaceOptionsFrame:IsShown() then _G.HideUIPanel(_G.InterfaceOptionsFrame) end
		ns.Show()
	end)
	local version = p:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	version:SetPoint("TOPRIGHT", open, "BOTTOMRIGHT", 0, -6)
	version:SetText("Version " .. (metadata("Version") or "?"))

	local function para(anchor, font, text, gap)
		local f = p:CreateFontString(nil, "ARTWORK", font)
		f:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", anchor == logo and 4 or 0, -(gap or 8))
		f:SetPoint("RIGHT", p, "RIGHT", -16, 0)
		f:SetJustifyH("LEFT")
		f:SetSpacing(2)
		f:SetText(text)
		return f
	end

	local a = para(logo, "GameFontHighlight",
		"OpenTyrian (Tyrian 2.1) ported to a WoW addon.  The full game runs in a window.", 10)
	a = para(a, "GameFontNormal", "How to play", 14)
	a = para(a, "GameFontHighlightSmall",
		"Type /tyrian (or /wt2k), click the minimap button, or set a key under Key Bindings > AddOns.  " ..
		"Arrow keys move, Space fires, Enter changes the rear weapon mode, Esc opens the menu.\n" ..
		"Flight mode: when you take a flight you're offered a generated level that ends before you land.  " ..
		"It ends with a boss.  If enough flight time is left after the boss, you're offered a bonus level.\n" ..
		"The settings are on the pages under this one.")
	a = para(a, "GameFontNormal", "Credits", 14)
	a = para(a, "GameFontHighlightSmall",
		"Lua port by voetre.\n" ..
		"Based on OpenTyrian, by the OpenTyrian Development Team.\n" ..
		"Tyrian (c) 1995 Epic MegaGames and Eclipse Software, released as freeware.  Programming and level design " ..
		"by Jason Emery; story and music by Alexander Brandon; level artwork by Daniel Cook, who released his " ..
		"Tyrian graphics for free use in 2007; with Robert Allen, Arturo Sinclair, Bruce Hsu, John Calcagno, " ..
		"Andrew Paquette, Andreas Molnar, Susan Aldworth and Nando Eweg.\n" ..
		"Flight times from Flight Timer Classic by timohausmann (CC BY 2.0).")
	a = para(a, "GameFontDisableSmall",
		"WowTyrian2k is free software under the GNU GPL, version 2 or later.  The Tyrian game data is not covered " ..
		"by the GPL (see DATA-NOTICE.txt).  Not affiliated with Blizzard Entertainment or the OpenTyrian project.", 10)

	-- the project page, in a box so it can be copied
	local label = p:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	label:SetPoint("TOPLEFT", a, "BOTTOMLEFT", 0, -14)
	label:SetText("Project page:")
	local box = _G.CreateFrame("EditBox", nil, p, "InputBoxTemplate")
	box:SetSize(300, 20)
	box:SetPoint("LEFT", label, "RIGHT", 12, 0)
	box:SetAutoFocus(false)
	box:SetText(URL)
	box:SetCursorPosition(0)
	-- read only: any edit puts the address back
	box:SetScript("OnTextChanged", function(self, user) if user then self:SetText(URL) self:HighlightText() end end)
	box:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
	box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	return p
end

local function buildGamePanel()
	local o = ns.options
	local p = newPanel("Game")
	local a = header(p, "Game", "How the game starts and runs.")
	a = checkbox(p, a, "Skip intro logos", "Go straight to the title screen when the game starts.",
		function() return o.skipLogos end, function(v) o.skipLogos = v end)
	a = dropdown(p, a, "Game speed", "How fast the game runs (the same setting as in the in-game Options menu).",
		{ { 1, "Slug Mode" }, { 2, "Slower" }, { 3, "Slow" }, { 4, "Normal" }, { 5, "Turbo" } },
		function() return gameSpeed end,
		function(v)
			gameSpeed = v
			JE_initProcessorType()
			if JE_setNewGameSpeed then JE_setNewGameSpeed() end
			saveConfig()
		end)
	return p
end

local function buildSoundPanel()
	local o = ns.options
	local p = newPanel("Sound")
	local a = header(p, "Sound", "The game's music and sound effects.")
	a = checkbox(p, a, "Music", "Play the game's music.",
		function() return not music_disabled end,
		function(v)
			music_disabled = not v
			if ns.root and ns.root:IsShown() and song_playing >= 0 then
				if music_disabled then
					stop_song()
				else
					restart_song()
				end
			end
			saveConfig()
		end)
	a = slider(p, a, "Music volume", "Volume of the game's music.", 0, 100, 5, percent,
		function() return math.floor(tyrMusicVolume * 100 / 255 + 0.5) end,
		function(v)
			tyrMusicVolume = math.floor(v * 255 / 100 + 0.5)
			set_volume(tyrMusicVolume, fxVolume)
			saveConfig()
		end, 30)
	a = checkbox(p, a, "Sound effects", "Play the game's sound effects.",
		function() return not samples_disabled end,
		function(v)
			samples_disabled = not v
			saveConfig()
		end, -30)
	a = slider(p, a, "Effects volume", "Volume of the game's sound effects.", 0, 100, 5, percent,
		function() return math.floor(fxVolume * 100 / 255 + 0.5) end,
		function(v)
			fxVolume = math.floor(v * 255 / 100 + 0.5)
			set_volume(tyrMusicVolume, fxVolume)
			saveConfig()
		end, 30)
	a = checkbox(p, a, "Use the game's volume levels",
		"WoW can't set the volume of one sound, so while the game window is open the WoW Music and Effects volumes are set to the game's levels.  Your WoW volumes are put back when the window closes.  Untick this to leave the WoW volumes alone; the sliders above then do nothing.",
		function() return o.controlVolume end,
		function(v)
			if not v then ns.releaseAudio() end
			o.controlVolume = v
			if v and ns.root and ns.root:IsShown() then ns.acquireAudio() end
		end, -30)

	local note = p:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	note:SetPoint("TOPLEFT", a, "BOTTOMLEFT", 0, -16)
	note:SetPoint("RIGHT", p, "RIGHT", -16, 0)
	note:SetJustifyH("LEFT")
	note:SetText("Music only plays if Music is enabled in the WoW Sound options, and the effects need Sound Effects enabled.")
	return p
end

local function buildCheatsPanel()
	local o = ns.options
	local p = newPanel("Cheats")
	local a = header(p, "Cheats", "Changes apply at once, including during a level.")
	for i = 1, #cheatList do
		local c = cheatList[i]
		a = checkbox(p, a, c.name, c.desc,
			function() return o.cheats[c.key] end,
			function(v) o.cheats[c.key] = v or nil end)
	end
	a = slider(p, a, "Flight mode lives", "How many lives a timed (flight mode) level starts with, instead of the number set by its length.  Lives are the front gun's power, so this also sets the starting power.", 0, 10, 1,
		function(v) return v == 0 and "Normal" or tostring(v) end,
		function() return o.cheats.lives or 0 end,
		function(v) o.cheats.lives = v > 0 and v or nil end)
	a = checkbox(p, a, "No cheats in flight mode", "Turn all the cheats above off during timed (flight mode) levels and their bonus levels.  They turn back on afterwards.",
		function() return o.noFlightCheats end, function(v) o.noFlightCheats = v end)
	return p
end

local function buildWindowPanel()
	local o = ns.options
	local p = newPanel("Window")
	local a = header(p, "Window", "The game window, and what hides or pauses it.")
	a = slider(p, a, "Window scale", "Size of the game window, in multiples of 320x200.", 1, 6, 1,
		function(v) return v .. "x" end,
		function() return ns.db.scale or 3 end,
		function(v)
			ns.db.scale = v
			if ns.root then ns.setScale(v) end
		end)
	a = checkbox(p, a, "Lock the window", "Stop the window from being dragged by its title bar.  Where you left it is remembered either way.",
		function() return o.lockWindow end, function(v) o.lockWindow = v end)
	a = slider(p, a, "Opacity", "How see-through the game window is.", 30, 100, 5, percent,
		function() return o.alpha end,
		function(v)
			o.alpha = v
			ns.applyWindowOptions()
		end)
	a = checkbox(p, a, "Minimap button", "Show the Tyrian button on the minimap: left-click plays, right-click opens these options, drag to move it.",
		function() return not ns.db.minimap.hide end,
		function(v) ns.setMinimapButton(v) end)
	a = actionButton(p, a, "Reset position and size", "Put the window back in the middle of the screen at 3x.  Same as /tyrian reset.",
		function() ns.resetWindow() refreshPanels() end)

	a = sectionTitle(p, a, "Pausing")
	a = dropdown(p, a, "When closed", "What closing the window (the X button, /tyrian or the key binding) does to the game.",
		{ { "pause", "Pause the game" }, { "end", "End the game" } },
		function() return o.onHide end, function(v) o.onHide = v end)
	a = dropdown(p, a, "In combat", "What happens when you enter combat.  WoW doesn't let addons give the keyboard back during combat, so with Keep playing your keys keep going to the game until you close it.",
		{ { "pause", "Hide and pause" }, { "end", "Hide and end the game" }, { "keep", "Keep playing" } },
		function() return o.onCombat end, function(v) o.onCombat = v end)
	a = checkbox(p, a, "Hide for alerts", "Hide (and pause) the game for a ready check, a dungeon queue pop or a whisper.",
		function() return o.hideOnAlert end, function(v) o.hideOnAlert = v end)
	return p
end

local function buildFlightPanel()
	local o = ns.options
	local p = newPanel("Flight Mode")
	local a = header(p, "Flight Mode", "A generated level timed to end just before your flight lands.")
	a = dropdown(p, a, "When a flight starts", "Ask: a toast offers a game.  Start a game: the level starts at once.  Do nothing: no toast (you can still use /tyrian timedlevel).",
		{ { "ask", "Ask" }, { "start", "Start a game" }, { "off", "Do nothing" } },
		function() return o.flightMode end, function(v) o.flightMode = v end)
	a = checkbox(p, a, "Flight time in chat", "Print the estimated flight time (and the real one when you land) in chat.",
		function() return ns.db.flightInfo ~= false end, function(v) ns.db.flightInfo = v end)
	a = checkbox(p, a, "Flight bar", "During a level, show the destination, the flight time left and a fill bar in the strip at the bottom of the screen.",
		function() return o.flightBar end, function(v) o.flightBar = v end)
	a = dropdown(p, a, "Theme", "Which theme flight mode levels use.",
		{ { "random", "Random" }, { "forest", "Forest" }, { "ocean", "Ocean" } },
		function() return o.flightTheme end, function(v) o.flightTheme = v end)
	a = slider(p, a, "Shortest game", "Flights too short for a level this long don't offer a game.", 75, 300, 15,
		function(v) return LevelGen.clockText(v) end,
		function() return o.flightMinLevel end, function(v) o.flightMinLevel = v end)
	a = slider(p, a, "Finish before landing", "How long before the landing the level (and a bonus level) ends.", 0, 60, 5,
		function(v) return v .. " s" end,
		function() return o.flightMargin end, function(v) o.flightMargin = v end)
	a = actionButton(p, a, "Forget recorded flights", "Flight times are recorded each time you land and used for the estimates.  This deletes them.",
		function()
			confirm("Forget all recorded flight times?", function()
				ns.db.flights = nil
				ns.Print("recorded flight times forgotten")
			end)
		end)
	return p
end

local function buildLevelsPanel()
	local o = ns.options
	local p = newPanel("Generated Levels")
	local a = header(p, "Generated Levels", "Timed levels: flight mode and /tyrian timedlevel.")
	a = slider(p, a, "Difficulty", "Added to the difficulty of the waves and the boss.", -2, 2, 1,
		function(v) return v == 0 and "Normal" or (v > 0 and "+" .. v or tostring(v)) end,
		function() return o.genDifficulty end, function(v) o.genDifficulty = v end)
	a = dropdown(p, a, "Arcade power", "By default, shorter levels give a stronger start, more drops and tougher enemies.  Pick a fixed power to use instead.",
		{ { -1, "Auto (by length)" }, { 0, "0% (long level)" }, { 25, "25%" }, { 50, "50%" }, { 75, "75%" }, { 100, "100% (short level)" } },
		function() return o.genPower end, function(v) o.genPower = v end)
	a = dropdown(p, a, "Drops", "How often killed enemies drop power-ups.",
		{ { 0, "None" }, { 0.5, "Half" }, { 1, "Normal" }, { 1.5, "More" }, { 2, "Double" } },
		function() return o.genDrops end, function(v) o.genDrops = v end)
	a = dropdown(p, a, "Enemy density", "How many of the enemy waves are kept, and how often random enemies come.",
		{ { "low", "Low" }, { "normal", "Normal" }, { "high", "High" } },
		function() return o.genDensity end, function(v) o.genDensity = v end)
	a = checkbox(p, a, "Random music", "Play a random song in each level, instead of the source level's own.",
		function() return o.randomMusic end, function(v) o.randomMusic = v end)

	a = sectionTitle(p, a, "After the level")
	a = checkbox(p, a, "Bonus levels", "Offer one of Tyrian's secret levels when you beat the boss with flight time to spare.",
		function() return o.genBonus end, function(v) o.genBonus = v end)
	a = slider(p, a, "Flight needed", "Flight time that has to be left for a bonus level.", 30, 300, 15,
		function(v) return LevelGen.clockText(v) end,
		function() return o.bonusMin end, function(v) o.bonusMin = v end, 30)
	a = checkbox(p, a, "Score card", "Show the run's stats when it's over.",
		function() return o.scoreCard end, function(v) o.scoreCard = v end, -30)
	a = checkbox(p, a, "Keep the game open", "After the run go back to the title screen, instead of closing the window.",
		function() return o.keepOpen end, function(v) o.keepOpen = v end)
	a = checkbox(p, a, "Score card music", "Play music on the score card and the bonus level offer.",
		function() return o.scoreCardMusic end, function(v) o.scoreCardMusic = v end)
	return p
end

local function statsText()
	local st = ns.db.stats
	if not st or not st.runs or #st.runs == 0 then
		return "No runs yet.  Finish a generated level (flight mode, /tyrian timedlevel or /tyrian genlevel) to start."
	end
	local clock = LevelGen.clockText
	local t = st.totals or {}
	local out = {}
	local function add(s) out[#out + 1] = s end
	add("|cffffd100Lifetime|r")
	add(string.format("%d runs (%d on flights), %s played", t.runs or 0, t.flights or 0, clock(t.seconds or 0)))
	add(string.format("%d bosses destroyed, %d ships lost, %d bonus levels, %d drops, %d points",
		t.bosses or 0, t.lost or 0, t.bonus or 0, t.drops or 0, t.score or 0))
	add("")
	add("|cffffd100Best scores|r")
	local themes = {}
	for name in pairs(st.best or {}) do themes[#themes + 1] = name end
	table.sort(themes)
	for _, name in ipairs(themes) do
		local b = st.best[name]
		add(string.format("%s: %d  (%d%% killed, seed %d%s)", name, b.score, b.kills or 0, b.seed or 0,
			b.date and ", " .. b.date or ""))
	end
	add("")
	add("|cffffd100Recent runs|r")
	for _, r in ipairs(st.runs) do
		local parts = { r.date or "?", r.theme }
		if r.seconds then parts[#parts + 1] = clock(r.clock or 0) .. "/" .. clock(r.seconds) end
		parts[#parts + 1] = r.dead and "lost" or (r.boss and "boss down" or "")
		parts[#parts + 1] = (r.kills or 0) .. "%"
		parts[#parts + 1] = tostring(r.score or 0)
		if r.bonus then parts[#parts + 1] = "+bonus" end
		if r.dest then parts[#parts + 1] = "to " .. r.dest:match("^[^,]+") end
		local line = {}
		for _, s in ipairs(parts) do
			if s ~= "" then line[#line + 1] = s end
		end
		add(table.concat(line, "   "))
	end
	return table.concat(out, "\n")
end

local function buildStatsPanel()
	local p = newPanel("Statistics")
	local a = header(p, "Statistics", "Generated level runs: lifetime totals, the best score for each theme and the last 20 runs.")
	local b = actionButton(p, a, "Reset statistics", "Forget every recorded run.", nil)
	local text = p:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	text:SetPoint("TOPLEFT", b, "BOTTOMLEFT", 0, -14)
	text:SetPoint("RIGHT", p, "RIGHT", -16, 0)
	text:SetJustifyH("LEFT")
	text:SetSpacing(2)
	text.refresh = function() text:SetText(statsText()) end
	p.widgets[#p.widgets + 1] = text
	b:SetScript("OnClick", function()
		confirm("Reset all WowTyrian2k statistics?", function()
			ns.db.stats = nil
			text.refresh()
		end)
	end)
	return p
end

local function resetOptions()
	local o = ns.options
	for k in pairs(o) do o[k] = nil end
	for k, v in pairs(defaults) do o[k] = v end
	o.cheats = {}
	cheats = o.cheats
	ns.db.flightInfo = nil
	ns.resetWindow()
	ns.applyWindowOptions()
	ns.setMinimapButton(true)
	refreshPanels()
	ns.Print("settings reset")
end

local function buildAdvancedPanel()
	local p = newPanel("Advanced")
	local a = header(p, "Advanced", "Troubleshooting, and starting over.")
	a = checkbox(p, a, "Debug messages", "Print warnings from the game code in chat (/tyrian debug).",
		function() return ns.db.debug end,
		function(v)
			ns.db.debug = v or nil
			ns.debugLog = v
		end)
	a = checkbox(p, a, "Performance meter", "Show game ticks per second and the time each frame takes in the corner of the game window (/tyrian perf).",
		function() return ns.db.perf end, function(v) ns.setPerf(v) end)
	a = actionButton(p, a, "Clear debug dumps", "Delete the render state dumps (F12 or /tyrian dump) kept in the saved variables.",
		function()
			local n = ns.db.dumps and #ns.db.dumps or 0
			ns.db.dumps = nil
			ns.Print(n .. " debug dumps cleared")
		end)
	a = actionButton(p, a, "Restart the game", "End the current game and go back to the title screen (/tyrian restart).  Saved games are kept.",
		function()
			ns.restartGame()
			ns.Print("game restarted")
		end)
	a = actionButton(p, a, "Reset all settings", "Put every addon setting and cheat back to its default, and the window back in the middle.  The game's own settings (music, sound, speed), saved games, statistics and flight times are kept.",
		function() confirm("Reset all WowTyrian2k settings to their defaults?", resetOptions) end)
	return p
end

local mainCategory

function ns.registerOptionsPanel()
	local main = buildMainPanel()
	local subs = { buildGamePanel(), buildSoundPanel(), buildWindowPanel(), buildFlightPanel(), buildLevelsPanel(), buildStatsPanel(),
		buildCheatsPanel(), buildAdvancedPanel() }
	ns.optionsPanel = main

	local S = _G.Settings
	if S and S.RegisterCanvasLayoutCategory and S.RegisterAddOnCategory then
		mainCategory = S.RegisterCanvasLayoutCategory(main, "WowTyrian2k")
		mainCategory.ID = mainCategory.ID or addonName
		if S.RegisterCanvasLayoutSubcategory then
			for _, sub in ipairs(subs) do
				S.RegisterCanvasLayoutSubcategory(mainCategory, sub, sub.name)
			end
		end
		S.RegisterAddOnCategory(mainCategory)
	elseif _G.InterfaceOptions_AddCategory then
		_G.InterfaceOptions_AddCategory(main)
		for _, sub in ipairs(subs) do
			sub.parent = main.name
			_G.InterfaceOptions_AddCategory(sub)
		end
	end
end

function ns.openOptions()
	local S = _G.Settings
	if mainCategory and S and S.OpenToCategory then
		S.OpenToCategory(mainCategory:GetID())
	elseif _G.InterfaceOptionsFrame_OpenToCategory and ns.optionsPanel then
		-- called twice: the first call may only open the frame
		_G.InterfaceOptionsFrame_OpenToCategory(ns.optionsPanel)
		_G.InterfaceOptionsFrame_OpenToCategory(ns.optionsPanel)
	else
		ns.Print("the options page is not available on this client")
	end
end
