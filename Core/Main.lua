--[[
 WowTyrian2k: a World of Warcraft port of OpenTyrian
 Copyright (C) The OpenTyrian Development Team
 Lua port Copyright (C) 2026 voetre
 Licensed under the GNU General Public License v2 or later (see COPYING).

 WoW integration: window, slash command, saved variables and the coroutine
 driver that runs the ported game.
]]
local addonName, ns = ...
setfenv(1, ns.G)

local _G = _G_REAL
local co
local driver = _G.CreateFrame("Frame")
local paused = false

local function opt(k, default)
	local v = ns.options and ns.options[k]
	if v == nil then return default end
	return v
end

local function reportError(err)
	local stack = _G.debugstack and _G.debugstack(co, 1, 30, 30) or ""
	ns.Print("|cffff4040Lua error in game:|r " .. tostring(err))
	ns.Print(stack)
	ns.lastError = tostring(err) .. "\n" .. stack
	if ns.db then ns.db.lastError = ns.lastError end
end

-- The window title: what the game is doing, at a glance --------------------

-- The screens the game is in, innermost last.  The game's screen functions
-- are wrapped to keep this up to date; a run that's cut short (an error, or
-- a fresh start) leaves it half full, so startGame clears it.
local modes = {}
local function popTo(n, ...)
	for i = #modes, n, -1 do modes[i] = nil end
	return ...
end
for name, label in pairs({
	intro_logos = "Intro", titleScreen = "Title Screen", setupMenu = "Setup",
	jukebox = "Jukebox", JE_loadScreen = "Load Game", JE_highScoreScreen = "High Scores",
	JE_helpSystem = "Help", JE_playCredits = "Credits", JE_main = "Playing",
	JE_itemScreen = "Upgrade Ship", JE_endLevelAni = "Level Complete",
	JE_pauseGame = "Paused", JE_doInGameSetup = "Options", JE_destructGame = "Destruct",
}) do
	local f = ns.G[name]
	if f then
		ns.G[name] = function(...)
			local n = #modes + 1
			modes[n] = label
			return popTo(n, f(...))
		end
	end
end

local DIFFICULTY = { [0] = "Wimp", "Easy", "Normal", "Hard", "Impossible", "Insanity",
	"Suicide", "Maniacal", "Zinglon", "Nortaneous", "Lord of the Game" }

-- 1234567 -> "1,234,567"
local function commas(n)
	local s = tostring(math.floor(n or 0))
	local k
	repeat s, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2") until k == 0
	return s
end

local function trim(s) return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end
local function capital(s) return s:sub(1, 1):upper() .. s:sub(2):lower() end

local function titleParts()
	local mode = modes[#modes]
	if not mode then return {} end
	local parts = { mode }
	local G = ns.G
	local inGame = false
	for i = 1, #modes do if modes[i] == "Playing" then inGame = true end end
	if mode == "Jukebox" then
		local name = G.song_playing and G.song_playing >= 0 and G.musicTitle[G.song_playing]
		if name then parts[#parts + 1] = name end
	elseif inGame then
		-- where, how hard, and the score (the mode only when it's not just
		-- playing: paused, the upgrade screen...)
		if G.playDemo then
			parts[1] = "Demo"
		elseif G.genLevel then
			if mode == "Playing" then parts[1] = "Generated Level" end
			parts[#parts + 1] = capital(tostring(G.genLevel.name))
		else
			if mode == "Playing" then table.remove(parts, 1) end
			local level = trim(G.levelName)
			local ep = (G.episodeNum or 0) > 0 and ("Episode " .. G.episodeNum) or nil
			if ep and level ~= "" then
				parts[#parts + 1] = ep .. ": " .. capital(level)
			elseif ep then
				parts[#parts + 1] = ep
			end
		end
		if not G.playDemo then
			parts[#parts + 1] = DIFFICULTY[G.difficultyLevel]
			local p = G.player and G.player[0]
			if p and p.cash then parts[#parts + 1] = "Score " .. commas(p.cash) end
		end
	end
	return parts
end

local lastTitle, titleAt = nil, 0
local function updateTitle(force)
	if not ns.titleText then return end
	local now = _G.GetTime()
	if not force and now - titleAt < 0.25 then return end
	titleAt = now
	local parts = titleParts()
	-- on a flight, how long is left
	local f = ns.Flight and ns.Flight.current
	if f and f.eta then
		local left = math.max(0, f.eta - (now - f.start))
		parts[#parts + 1] = string.format("%s in %d:%02d", f.dest or "Landing", left / 60, left % 60)
	end
	local text = "Tyrian"
	if #parts > 0 then text = text .. " - " .. table.concat(parts, "  \194\183  ") end
	if force or text ~= lastTitle then
		lastTitle = text
		ns.titleText:SetText(text)
	end
end
ns.updateTitle = updateTitle
ns.titleModes = modes   -- for the test harness

local function startGame()
	for i = #modes, 1, -1 do modes[i] = nil end
	-- a generated level cut short leaves its state behind
	if LevelGen and LevelGen.abort then LevelGen.abort() end
	ns.Jukebox.close()
	co = coroutine.create(function()
		ns.gameMain()
	end)
end

local function step()
	if not co then return end
	local status = coroutine.status(co)
	if status == "dead" then
		co = nil
		ns.Hide()
		return
	end
	local ok, err = coroutine.resume(co)
	if not ok then
		if err == "WT2K_QUIT" then
			co = nil
			ns.Hide()
			return
		end
		reportError(err)
		co = nil
		return
	end
	-- Render the latest complete state once per client frame.  The game
	-- only yields while waiting, i.e. after a frame has been fully drawn.
	if ns.frameDirty then
		ns.frameDirty = false
		ns.present(VGAScreen)
	end
end

local lastMX, lastMY
local lastCX, lastCY
local function updateMouse()
	local root = ns.root
	if not root or not root:IsShown() then return end
	local s = root:GetEffectiveScale()
	local cx, cy = _G.GetCursorPosition()
	cx, cy = cx / s, cy / s
	local left, top = root:GetLeft(), root:GetTop()
	if not left then return end
	local sc = ns.getScale()
	local x = math.floor((cx - left) / sc)
	local y = math.floor((top - cy) / sc)
	-- Only real cursor movement counts as mouse input; the window moving or
	-- being resized under a still cursor just updates the position.
	local moved = lastCX ~= nil and (cx ~= lastCX or cy ~= lastCY)
	if lastMX then
		ns.onMouseMove(x, y, x - lastMX, y - lastMY, not moved)
	end
	lastMX, lastMY = x, y
	lastCX, lastCY = cx, cy
end

-- Performance meter (/tyrian perf): game ticks per second (34.8 at normal
-- speed), client frames per second, Lua time per client frame and how often
-- the game fell too far behind and dropped time.
local perf = { frames = 0, ms = 0, maxMs = 0, start = 0 }
local function perfUpdate(ms)
	local now = _G.GetTime()
	perf.frames = perf.frames + 1
	perf.ms = perf.ms + ms
	if ms > perf.maxMs then perf.maxMs = ms end
	local span = now - perf.start
	if span < 1 then return end
	if not perf.text then
		-- its own frame above the game's sprite frames, which would cover it
		local f = _G.CreateFrame("Frame", nil, ns.root)
		f:SetAllPoints()
		f:SetFrameLevel(ns.root:GetFrameLevel() + 600)
		perf.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		perf.text:SetPoint("BOTTOMLEFT", ns.root, "BOTTOMLEFT", 6, 6)
		perf.text:SetTextColor(1, 1, 0)
		perf.text:SetJustifyH("LEFT")
	end
	local kb = _G.collectgarbage("count")
	if perf.start > 0 then
		perf.text:SetText(string.format("ticks %.1f/s  fps %.0f  lua %.2f ms (max %.1f)  garbage %.0f KB/s  resyncs %d",
			((ns.perfTicks or 0) - perf.ticks) / span, perf.frames / span, perf.ms / perf.frames, perf.maxMs,
			math.max(0, kb - perf.kb) / span, ns.perfResyncs or 0))
		perf.text:Show()
	end
	perf.start, perf.ticks, perf.kb = now, ns.perfTicks or 0, kb
	perf.frames, perf.ms, perf.maxMs = 0, 0, 0
end

driver:SetScript("OnUpdate", function()
	if paused or not ns.root or not ns.root:IsShown() then return end
	local t0 = ns.db and ns.db.perf and _G.debugprofilestop and _G.debugprofilestop()
	updateMouse()
	step()
	updateTitle()
	if t0 then perfUpdate(_G.debugprofilestop() - t0) end
end)

local function setKeyboard(enabled)
	local root = ns.root
	root:EnableKeyboard(enabled)
	if not _G.InCombatLockdown() then
		root:SetPropagateKeyboardInput(not enabled)
	end
end

-- Gamepad support (replaces OpenTyrian's SDL joystick code).  Controller
-- buttons and the left stick are translated into the keys the game already
-- understands.  Requires a client with the gamepad API and the
-- GamePadEnable CVar turned on.
local padMap = {
	PADDUP = "UP", PADDDOWN = "DOWN", PADDLEFT = "LEFT", PADDRIGHT = "RIGHT",
	PAD1 = "SPACE",          -- A / cross: fire, select
	PAD2 = "ESCAPE",         -- B / circle: back
	PAD3 = "ENTER",          -- X / square: change rear weapon mode
	PAD4 = "F1",             -- Y / triangle: help
	PADLSHOULDER = "LCTRL",  -- left sidekick
	PADRSHOULDER = "LALT",   -- right sidekick
	PADLTRIGGER = "LCTRL",
	PADRTRIGGER = "LALT",
	PADFORWARD = "ESCAPE",   -- start: menu
	PADBACK = "P",           -- back/select: pause
}

local stickHeld = {}
local function stickAxis(neg, pos, v)
	local wantNeg, wantPos = v < -0.5, v > 0.5
	if wantNeg ~= (stickHeld[neg] or false) then
		stickHeld[neg] = wantNeg
		if wantNeg then ns.onKeyDown(neg) else ns.onKeyUp(neg) end
	end
	if wantPos ~= (stickHeld[pos] or false) then
		stickHeld[pos] = wantPos
		if wantPos then ns.onKeyDown(pos) else ns.onKeyUp(pos) end
	end
end

local function setupGamePad(root)
	if not root.EnableGamePadButton then return end
	root:EnableGamePadButton(true)
	root:SetScript("OnGamePadButtonDown", function(self, button)
		local key = padMap[button]
		if key then ns.onKeyDown(key) end
	end)
	root:SetScript("OnGamePadButtonUp", function(self, button)
		local key = padMap[button]
		if key then ns.onKeyUp(key) end
	end)
	if root.EnableGamePadStick then
		root:EnableGamePadStick(true)
		root:SetScript("OnGamePadStick", function(self, stick, x, y)
			if stick == "Left" or stick == "Movement" then
				stickAxis("LEFT", "RIGHT", x or 0)
				stickAxis("DOWN", "UP", y or 0)
			end
		end)
	end
end

function ns.Show()
	local root = ns.createWindow()
	if not ns.scriptsSet then
		ns.scriptsSet = true
		root:SetScript("OnKeyDown", function(self, key)
			if not _G.InCombatLockdown() then self:SetPropagateKeyboardInput(false) end
			-- the toggle key binding still closes the window
			if _G.GetBindingAction then
				local mod = (_G.IsAltKeyDown() and "ALT-" or "") .. (_G.IsControlKeyDown() and "CTRL-" or "")
					.. (_G.IsShiftKeyDown() and "SHIFT-" or "")
				if _G.GetBindingAction(mod .. key) == "WOWTYRIAN2K_TOGGLE" then
					ns.closeWindow()
					return
				end
			end
			if key == "F12" then
				-- render state dump (Core/Debug.lua)
				local ok, err = pcall(ns.debugDump)
				if not ok then ns.Print("dump failed: " .. tostring(err)) end
				return
			end
			ns.onKeyDown(key)
		end)
		root:SetScript("OnKeyUp", function(self, key) ns.onKeyUp(key) end)
		root:SetScript("OnChar", function(self, text) ns.onChar(text) end)
		root:SetScript("OnMouseDown", function(self, button)
			updateMouse()
			local b = button == "RightButton" and SDL_BUTTON_RIGHT or (button == "MiddleButton" and SDL_BUTTON_MIDDLE or SDL_BUTTON_LEFT)
			ns.onMouseDown(b, mouseX, mouseY)
		end)
		setupGamePad(root)
		root:SetScript("OnMouseUp", function(self, button)
			local b = button == "RightButton" and SDL_BUTTON_RIGHT or (button == "MiddleButton" and SDL_BUTTON_MIDDLE or SDL_BUTTON_LEFT)
			ns.onMouseUp(b)
		end)
	end
	root:Show()
	ns.acquireAudio()
	setKeyboard(true)
	paused = false
	if not co then startGame() end
	if song_playing and song_playing >= 0 and not music_stopped then restart_song() else ns.holdMusic() end
end

-- Hides the window.  The game stays where it was (paused) unless endRun,
-- which drops it so the next Show starts a fresh one.
function ns.Hide(endRun)
	if not ns.root then return end
	if endRun then
		co = nil
		ns.Jukebox.close()
	end
	setKeyboard(false)
	ns.releaseAllKeys()
	ns.root:Hide()
	ns.releaseMusic()
	ns.releaseAudio()
	ns.saveDB()
end

-- Starts a generated level now: req = { name, seed, seconds } (see
-- LevelGen.beginTest), replacing any game in progress.
function ns.playGenLevel(req)
	ns.genLevelRequest = req
	co = nil
	if ns.root and ns.root:IsShown() then startGame() else ns.Show() end
end

-- Closing the window by hand (close button, /tyrian, key binding): the
-- "when closed" option says whether that pauses or ends the game.
function ns.closeWindow()
	ns.Hide(opt("onHide", "pause") == "end")
end

function ns.Toggle()
	if ns.root and ns.root:IsShown() then ns.closeWindow() else ns.Show() end
end

-- For Bindings.xml.
function _G.WowTyrian2k_Toggle() ns.Toggle() end
_G.BINDING_HEADER_WOWTYRIAN2K = "WowTyrian2k"
_G.BINDING_NAME_WOWTYRIAN2K_TOGGLE = "Show or hide Tyrian"

function ns.restartGame()
	co = nil
	if ns.root and ns.root:IsShown() then startGame() end
end

-- Puts the window back in the middle at the default size.
function ns.resetWindow()
	ns.db.windowPos = nil
	ns.db.scale = 3
	if ns.root then
		ns.setScale(3)
		ns.applyWindowOptions()
	end
end

function ns.setPerf(on)
	ns.db.perf = on and true or nil
	if not on and perf.text then perf.text:Hide() end
	perf.start = 0
end

-- Saved variables -----------------------------------------------------------------

function ns.saveDB()
	if ns.saveConfigToDB then pcall(ns.saveConfigToDB) end
end

driver:RegisterEvent("ADDON_LOADED")
driver:RegisterEvent("PLAYER_LOGOUT")
driver:RegisterEvent("PLAYER_REGEN_DISABLED")
-- things that need the player's attention (the "hide on alerts" option);
-- not every client has all of them
local ALERTS = { "READY_CHECK", "LFG_PROPOSAL_SHOW", "CHAT_MSG_WHISPER", "CHAT_MSG_BN_WHISPER" }
local isAlert = {}
for _, e in ipairs(ALERTS) do
	if pcall(driver.RegisterEvent, driver, e) then isAlert[e] = true end
end
driver:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" and arg1 == addonName then
		_G.WowTyrian2kDB = _G.WowTyrian2kDB or {}
		ns.db = _G.WowTyrian2kDB
		ns.db.scale = ns.db.scale or 3
		ns.debugLog = ns.db.debug
		ns.optionsInit()
	elseif event == "PLAYER_LOGOUT" then
		ns.releaseAudio()
		ns.saveDB()
	elseif event == "PLAYER_REGEN_DISABLED" then
		-- Entering combat: give the keyboard back to the player (the "in
		-- combat" option: pause, end the game, or keep playing).
		local mode = opt("onCombat", "pause")
		if mode ~= "keep" and ns.root and ns.root:IsShown() then ns.Hide(mode == "end") end
	elseif isAlert[event] then
		if opt("hideOnAlert", false) and ns.root and ns.root:IsShown() then ns.Hide() end
	end
end)

_G.SLASH_WOWTYRIAN2K1 = "/tyrian"
_G.SLASH_WOWTYRIAN2K2 = "/wt2k"
_G.SlashCmdList.WOWTYRIAN2K = function(msg)
	msg = (msg or ""):lower()
	local cmd, arg = msg:match("^(%S*)%s*(.*)$")
	if cmd == "scale" then
		local s = tonumber(arg)
		if s and s >= 1 and s <= 6 then
			ns.db.scale = s
			if ns.root then ns.setScale(s) end
			ns.Print("scale set to " .. s)
		else
			ns.Print("usage: /tyrian scale <1-6>")
		end
	elseif cmd == "options" or cmd == "config" or cmd == "settings" then
		ns.openOptions()
	elseif cmd == "reset" then
		ns.resetWindow()
		ns.Print("window position and size reset")
	elseif cmd == "restart" then
		ns.restartGame()
		ns.Print("game restarted")
	--@do-not-package@
	-- Developer commands, left out of packaged releases (BigWigsMods/packager
	-- deletes everything between these markers).
	elseif cmd == "genlevel" then
		-- test the level generator: /tyrian genlevel [theme] [seed]
		local name, seed = arg:match("^(%a*)%s*(%d*)")
		ns.playGenLevel({ name = name ~= "" and name:lower() or nil, seed = tonumber(seed) })
	elseif cmd == "flighttest" then
		-- a pretend flight of that length, with the flight mode prompt
		-- (Core/FlightPrompt.lua): /tyrian flighttest <5m|300|4:30> [theme] [seed]
		local dur, name, seed = arg:match("^(%S*)%s*(%a*)%s*(%d*)")
		if dur == "stop" then
			ns.FlightPrompt.stopTest()
			return
		end
		local seconds = LevelGen.parseDuration(dur)
		if not seconds then
			ns.Print("usage: /tyrian flighttest <duration: 5m, 300, 4:30> [forest|ocean] [seed]  (or: /tyrian flighttest stop)")
			return
		end
		ns.FlightPrompt.startTest(seconds, { name = name ~= "" and name or nil, seed = tonumber(seed), seconds = seconds })
	--@end-do-not-package@
	elseif cmd == "timedlevel" then
		-- the timed level at once: /tyrian timedlevel <5m|300|4:30> [theme] [seed]
		local dur, name, seed = arg:match("^(%S*)%s*(%a*)%s*(%d*)")
		local seconds = LevelGen.parseDuration(dur)
		if not seconds then
			ns.Print("usage: /tyrian timedlevel <duration: 5m, 300, 4:30> [forest|ocean] [seed]")
			return
		end
		ns.playGenLevel({ name = name ~= "" and name or nil, seed = tonumber(seed), seconds = seconds })
	elseif cmd == "flightprompt" then
		-- the "Play Tyrian?" prompt when a flight starts
		local o = ns.options
		o.flightMode = o.flightMode == "off" and "ask" or "off"
		ns.Print("flight prompt " .. (o.flightMode == "off" and "off" or "on"))
	elseif cmd == "flights" then
		-- flight time estimates in chat when taking a flight
		ns.db.flightInfo = ns.db.flightInfo == false
		ns.Print("flight time messages " .. (ns.db.flightInfo and "on" or "off"))
	elseif cmd == "debug" then
		ns.db.debug = not ns.db.debug
		ns.debugLog = ns.db.debug
		ns.Print("debug " .. (ns.debugLog and "on" or "off"))
	elseif cmd == "dump" then
		-- render state dump for bug reports (also F12 in game)
		local ok, err = pcall(ns.debugDump)
		if not ok then ns.Print("dump failed: " .. tostring(err)) end
	elseif cmd == "perf" then
		ns.setPerf(not ns.db.perf)
		ns.Print("performance meter " .. (ns.db.perf and "on" or "off"))
	elseif cmd == "stats" then
		local update = (_G.C_AddOns and _G.C_AddOns.UpdateAddOnMemoryUsage) or _G.UpdateAddOnMemoryUsage
		local get = (_G.C_AddOns and _G.C_AddOns.GetAddOnMemoryUsage) or _G.GetAddOnMemoryUsage
		local mine = 0
		if update and get then
			update()
			mine = get(addonName) / 1024
		end
		ns.Print(string.format("quads: %d  WowTyrian2k memory: %.1f MB  (all addons: %.1f MB)", ns.quadCount or 0, mine, _G.collectgarbage("count") / 1024))
	else
		ns.Toggle()
	end
end
