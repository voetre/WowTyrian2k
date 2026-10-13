--[[
 WowTyrian2k: a World of Warcraft port of OpenTyrian
 Copyright (C) The OpenTyrian Development Team
 Lua port Copyright (C) 2026 voetre
 Licensed under the GNU General Public License v2 or later (see COPYING).

 Addon options: a page in the WoW Options > AddOns list with the game
 settings, plus a Cheats sub-page.  Settings are stored in WowTyrian2kDB.
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
}

local cheatList = {
	{ key = "shield", name = "Infinite shield", desc = "Your shield is always full." },
	{ key = "armor", name = "Infinite armour", desc = "Your armour never drops below its starting value." },
	{ key = "invincible", name = "Invincible", desc = "Nothing can damage your ship: enemy shots and enemy ships pass straight through it." },
	{ key = "instantKill", name = "Instant kill", desc = "Any hit from your weapons destroys an enemy (indestructible objects stay indestructible)." },
	{ key = "power", name = "Infinite generator power", desc = "Weapons never run out of power and fire at full rate." },
	{ key = "ammo", name = "Infinite sidekick ammo", desc = "Sidekicks with limited ammunition never run out." },
	{ key = "credits", name = "Unlimited credits", desc = "You always have at least 1,000,000 credits to spend in the upgrade shop." },
	{ key = "shopUnlock", name = "All shop items", desc = "The upgrade shop sells every item that any shop in the four episodes sells." },
	{ key = "secretUnlock", name = "Secret items", desc = "The upgrade shop also sells the secret ships, weapons, shield and sidekick that no shop normally sells, such as the Nort Ship, the Stalker and the Banana Blast." },
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
	widget:SetScript("OnEnter", function(self)
		_G.GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		_G.GameTooltip:SetText(title, 1, 1, 1)
		_G.GameTooltip:AddLine(text, nil, nil, nil, true)
		_G.GameTooltip:Show()
	end)
	widget:SetScript("OnLeave", function() _G.GameTooltip:Hide() end)
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
local function slider(panel, anchor, label, desc, minV, maxV, step, fmt, get, set, indent)
	local text = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	text:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", indent or 0, -14)
	text:SetWidth(150)
	text:SetJustifyH("LEFT")
	text:SetText(label)

	local s = _G.CreateFrame("Slider", nil, panel)
	s:SetOrientation("HORIZONTAL")
	s:SetSize(200, 17)
	s:SetPoint("LEFT", text, "RIGHT", 10, 0)
	s:SetHitRectInsets(0, 0, -6, -6)
	local bg = s:CreateTexture(nil, "BACKGROUND")
	bg:SetColorTexture(0, 0, 0, 0.6)
	bg:SetPoint("LEFT", 0, 0)
	bg:SetPoint("RIGHT", 0, 0)
	bg:SetHeight(6)
	local fill = s:CreateTexture(nil, "BORDER")
	fill:SetColorTexture(1, 0.82, 0, 0.5)
	fill:SetPoint("LEFT", 0, 0)
	fill:SetHeight(6)
	s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
	s:SetMinMaxValues(minV, maxV)
	s:SetValueStep(step)
	if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
	s:EnableMouseWheel(true)

	local value = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	value:SetPoint("LEFT", s, "RIGHT", 10, 0)

	local updating = false
	local function show(v)
		value:SetText(fmt(v))
		fill:SetWidth(math.max(1, 200 * (v - minV) / (maxV - minV)))
	end
	s:SetScript("OnValueChanged", function(self, v)
		v = math.floor(v / step + 0.5) * step
		show(v)
		if not updating then set(v) end
	end)
	s:SetScript("OnMouseWheel", function(self, delta)
		self:SetValue(math.min(maxV, math.max(minV, self:GetValue() + delta * step)))
	end)
	tooltip(s, label, desc)
	s.refresh = function()
		updating = true
		local v = get()
		s:SetValue(v)
		show(v)
		updating = false
	end
	panel.widgets[#panel.widgets + 1] = s
	return text
end

local function newPanel(name)
	local p = _G.CreateFrame("Frame")
	p.name = name
	p.widgets = {}
	p:Hide()
	p:SetScript("OnShow", function(self)
		for i = 1, #self.widgets do self.widgets[i].refresh() end
	end)
	return p
end

-- Pages ----------------------------------------------------------------------------

local function percent(v) return string.format("%d%%", v) end

local function saveConfig()
	saveConfiguration()
end

local function buildMainPanel()
	local o = ns.options
	local p = newPanel(addonName)
	local a = header(p, "WowTyrian2k", "OpenTyrian for World of Warcraft.  Type /tyrian to play.")

	local open = _G.CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
	open:SetSize(140, 22)
	open:SetPoint("TOPRIGHT", -16, -16)
	open:SetText("Play Tyrian")
	open:SetScript("OnClick", function()
		if _G.SettingsPanel and _G.SettingsPanel:IsShown() then _G.HideUIPanel(_G.SettingsPanel) end
		if _G.InterfaceOptionsFrame and _G.InterfaceOptionsFrame:IsShown() then _G.HideUIPanel(_G.InterfaceOptionsFrame) end
		ns.Show()
	end)

	a = sectionTitle(p, a, "Game")
	a = checkbox(p, a, "Skip intro logos", "Go straight to the title screen when the game starts.",
		function() return o.skipLogos end, function(v) o.skipLogos = v end)
	a = slider(p, a, "Window scale", "Size of the game window, in multiples of 320x200.", 1, 6, 1,
		function(v) return v .. "x" end,
		function() return ns.db.scale or 3 end,
		function(v)
			ns.db.scale = v
			if ns.root then ns.setScale(v) end
		end)
	a = slider(p, a, "Game speed", "How fast the game runs (the same setting as in the in-game Options menu).", 1, 5, 1,
		function(v) return (gameSpeedText[v - 1] ~= "" and gameSpeedText[v - 1]) or tostring(v) end,
		function() return gameSpeed end,
		function(v)
			gameSpeed = v
			JE_initProcessorType()
			if JE_setNewGameSpeed then JE_setNewGameSpeed() end
			saveConfig()
		end)

	a = sectionTitle(p, a, "Sound")
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
		"WoW cannot set the volume of a single sound, so while the Tyrian window is open the WoW Music and Effects volume sliders are set to the game's levels.  Your own WoW settings are restored when the window closes.  Untick this to leave the WoW volume alone (the volume sliders above then have no effect).",
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
	local p = newPanel("Cheats")
	local a = header(p, "Cheats", "These take effect immediately, also during a level.")
	for i = 1, #cheatList do
		local c = cheatList[i]
		a = checkbox(p, a, c.name, c.desc,
			function() return cheats[c.key] end,
			function(v) cheats[c.key] = v or nil end)
	end
	return p
end

local mainCategory

function ns.registerOptionsPanel()
	local main = buildMainPanel()
	local cheatsPanel = buildCheatsPanel()
	ns.optionsPanel = main

	local S = _G.Settings
	if S and S.RegisterCanvasLayoutCategory and S.RegisterAddOnCategory then
		mainCategory = S.RegisterCanvasLayoutCategory(main, "WowTyrian2k")
		mainCategory.ID = mainCategory.ID or addonName
		if S.RegisterCanvasLayoutSubcategory then
			S.RegisterCanvasLayoutSubcategory(mainCategory, cheatsPanel, "Cheats")
		end
		S.RegisterAddOnCategory(mainCategory)
	elseif _G.InterfaceOptions_AddCategory then
		cheatsPanel.parent = main.name
		_G.InterfaceOptions_AddCategory(main)
		_G.InterfaceOptions_AddCategory(cheatsPanel)
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
