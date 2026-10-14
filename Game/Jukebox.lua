--[[
 WowTyrian2k: a World of Warcraft port of OpenTyrian
 Copyright (C) The OpenTyrian Development Team
 Lua port Copyright (C) 2026 voetre
 Licensed under the GNU General Public License v2 or later (see COPYING).

 jukebox.c, starlib.c, vga_palette.c, musicTitle (musmast.c) and
 soundTitle (sndmast.c).
]]
local _, ns = ...
setfenv(1, ns.G)

local floor, sin, cos, sqrt, abs = math.floor, math.sin, math.cos, math.sqrt, math.abs

local function trunc(x) if x >= 0 then return floor(x) end return -floor(-x) end

musicTitle = {
	[0] = "Asteroid Dance Part 2", "Asteroid Dance Part 1", "Buy/Sell Music", "CAMANIS", "CAMANISE",
	"Deli Shop Quartet", "Deli Shop Quartet No. 2", "Ending Number 1", "Ending Number 2", "End of Level",
	"Game Over Solo", "Gryphons of the West", "Somebody pick up the Gryphone", "Gyges, Will You Please Help Me?",
	"I speak Gygese", "Halloween Ramble", "Tunneling Trolls", "Tyrian, The Level", "The MusicMan",
	"The Navigator", "Come Back to Me, Savara", "Come Back again to Savara", "Space Journey 1",
	"Space Journey 2", "The final edge", "START5", "Parlance", "Torm - The Gathering", "TRANSON",
	"Tyrian: The Song", "ZANAC3", "ZANACS", "Return me to Savara", "High Score Table", "One Mustn't Fall",
	"Sarah's Song", "A Field for Mag", "Rock Garden", "Quest for Peace", "Composition in Q", "BEER",
}

soundTitle = {
	[0] = "SCALEDN2", "F2", "TEMP10", "EXPLSM", "PASS3", "TEMP2", "BYPASS1", "EXP1RT", "EXPLLOW", "TEMP13",
	"EXPRETAP", "MT2BOOM", "TEMP3", "LAZB", "LAZGUN2", "SPRING", "WARNING", "ITEM", "HIT2", "MACHNGUN",
	"HYPERD2", "EXPLHUG", "CLINK1", "CLICK", "SCALEDN1", "TEMP11", "TEMP16", "SMALL1", "POWERUP",
	"VOICE1", "VOICE2", "VOICE3", "VOICE4", "VOICE5", "VOICE6", "VOICE7", "VOICE8", "VOICE9",
}

-- The standard VGA palette (only used for the jukebox).
local vgaPaletteData = {
	0,0,0,0,0,168,0,168,0,0,168,168,168,0,0,168,0,168,168,84,0,168,168,168,84,84,84,84,84,252,84,252,84,84,252,252,252,84,84,252,84,252,252,252,84,252,252,252,
	0,0,0,20,20,20,32,32,32,44,44,44,56,56,56,68,68,68,80,80,80,96,96,96,112,112,112,128,128,128,144,144,144,160,160,160,180,180,180,200,200,200,224,224,224,252,252,252,
	0,0,252,64,0,252,124,0,252,188,0,252,252,0,252,252,0,188,252,0,124,252,0,64,252,0,0,252,64,0,252,124,0,252,188,0,252,252,0,188,252,0,124,252,0,64,252,0,
	0,252,0,0,252,64,0,252,124,0,252,188,0,252,252,0,188,252,0,124,252,0,64,252,124,124,252,156,124,252,188,124,252,220,124,252,252,124,252,252,124,220,252,124,188,252,124,156,
	252,124,124,252,156,124,252,188,124,252,220,124,252,252,124,220,252,124,188,252,124,156,252,124,124,252,124,124,252,156,124,252,188,124,252,220,124,252,252,124,220,252,124,188,252,124,156,252,
	180,180,252,196,180,252,216,180,252,232,180,252,252,180,252,252,180,232,252,180,216,252,180,196,252,180,180,252,196,180,252,216,180,252,232,180,252,252,180,232,252,180,216,252,180,196,252,180,
	180,252,180,180,252,196,180,252,216,180,252,232,180,252,252,180,232,252,180,216,252,180,196,252,0,0,112,28,0,112,56,0,112,84,0,112,112,0,112,112,0,84,112,0,56,112,0,28,
	112,0,0,112,28,0,112,56,0,112,84,0,112,112,0,84,112,0,56,112,0,28,112,0,0,112,0,0,112,28,0,112,56,0,112,84,0,112,112,0,84,112,0,56,112,0,28,112,
	56,56,112,68,56,112,84,56,112,96,56,112,112,56,112,112,56,96,112,56,84,112,56,68,112,56,56,112,68,56,112,84,56,112,96,56,112,112,56,96,112,56,84,112,56,68,112,56,
	56,112,56,56,112,68,56,112,84,56,112,96,56,112,112,56,96,112,56,84,112,56,68,112,80,80,112,88,80,112,96,80,112,104,80,112,112,80,112,112,80,104,112,80,96,112,80,88,
	112,80,80,112,88,80,112,96,80,112,104,80,112,112,80,104,112,80,96,112,80,88,112,80,80,112,80,80,112,88,80,112,96,80,112,104,80,112,112,80,104,112,80,96,112,80,88,112,
	0,0,64,16,0,64,32,0,64,48,0,64,64,0,64,64,0,48,64,0,32,64,0,16,64,0,0,64,16,0,64,32,0,64,48,0,64,64,0,48,64,0,32,64,0,16,64,0,
	0,64,0,0,64,16,0,64,32,0,64,48,0,64,64,0,48,64,0,32,64,0,16,64,32,32,64,40,32,64,48,32,64,56,32,64,64,32,64,64,32,56,64,32,48,64,32,40,
	64,32,32,64,40,32,64,48,32,64,56,32,64,64,32,56,64,32,48,64,32,40,64,32,32,64,32,32,64,40,32,64,48,32,64,56,32,64,64,32,56,64,32,48,64,32,40,64,
	44,44,64,48,44,64,52,44,64,60,44,64,64,44,64,64,44,60,64,44,52,64,44,48,64,44,44,64,48,44,64,52,44,64,60,44,64,64,44,60,64,44,52,64,44,48,64,44,
	44,64,44,44,64,48,44,64,52,44,64,60,44,64,64,44,60,64,44,52,64,44,48,64,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
}
local vga_palette

local function buildVgaPalette()
	local p = { id = 100 }
	for i = 0, 255 do
		p[i] = { vgaPaletteData[i * 3 + 1], vgaPaletteData[i * 3 + 2], vgaPaletteData[i * 3 + 3] }
	end
	return p
end

-- starlib.c ------------------------------------------------------------------------

local MAX_STARS = 1000
local MAX_TYPES = 14

local star = {}
local tempX, tempY = 0, 0
local setup = 0
local stepCounter = 0
local nsp2, nspVar2Inc = 1, 1
local nsp, nspVarInc, nspVarVarInc = 0, 0.1, 0.0001
local changeTime = 0
local doChange = false
local starlib_speed, speedChange = 2, 0
local pColor = 32
local starlibInitialized = false

local function JE_resetValues()
	nsp2 = 1
	nspVar2Inc = 1
	nspVarInc = 0.1
	nspVarVarInc = 0.0001
	nsp = 0
	pColor = 32
	starlib_speed = 2
	speedChange = 0
end

local function JE_changeSetup(setupType)
	stepCounter = 0
	changeTime = mt_rand() % 1000

	if setupType > 0 then
		setup = setupType
	else
		setup = mt_rand() % (MAX_TYPES + 1)
	end

	if setup == 1 then nspVarInc = 0.1 end
	if nspVarInc > 2.2 then nspVarInc = 0.1 end
end

local function stepNsp2()
	nsp2 = u16(nsp2 + nspVar2Inc)
	if nsp2 == 65535 or nsp2 == 0 then
		nspVar2Inc = -nspVar2Inc
	end
end

local function JE_newStar()
	if setup == 0 then
		tempX = (mt_rand() % 64000) - 32000
		tempY = (mt_rand() % 40000) - 20000
		return
	end

	nsp = nsp + nspVarInc
	if setup == 1 then
		tempX = trunc(sin(nsp / 30) * 20000)
		tempY = (mt_rand() % 40000) - 20000
	elseif setup == 2 then
		tempX = trunc(cos(nsp) * 20000)
		tempY = trunc(sin(nsp) * 20000)
	elseif setup == 3 then
		tempX = trunc(cos(nsp * 15) * 100) * cmod(trunc(nsp / 6), 200)
		tempY = trunc(sin(nsp * 15) * 100) * cmod(trunc(nsp / 6), 200)
	elseif setup == 4 then
		tempX = trunc(sin(nsp / 60) * 20000)
		tempY = trunc(cos(nsp) * trunc(sin(nsp / 200) * 300) * 100)
	elseif setup == 5 then
		tempX = trunc(sin(nsp / 2) * 20000)
		tempY = trunc(cos(nsp) * trunc(sin(nsp / 200) * 300) * 100)
	elseif setup == 6 then
		tempX = trunc(sin(nsp) * 40000)
		tempY = trunc(cos(nsp) * 20000)
	elseif setup == 8 then
		tempX = trunc(sin(nsp / 2) * 40000)
		tempY = trunc(cos(nsp) * 20000)
	elseif setup == 7 then
		tempX = mt_rand() % 65535
		if mt_rand() % 2 == 0 then
			tempY = trunc(cos(nsp / 80) * 10000) + 15000
		else
			tempY = 50000 - trunc(cos(nsp / 80) * 13000)
		end
	elseif setup == 9 then
		stepNsp2()
		tempX = trunc(cos(sin(nsp2 / 10) + nsp / 500) * 32000)
		tempY = trunc(sin(cos(nsp2 / 10) + nsp / 500) * 30000)
	elseif setup == 10 then
		stepNsp2()
		tempX = trunc(cos(sin(nsp2 / 5) + nsp / 100) * 32000)
		tempY = trunc(sin(cos(nsp2 / 5) + nsp / 100) * 30000)
	elseif setup == 11 then
		stepNsp2()
		tempX = trunc(cos(sin(nsp2 / 1000) + nsp / 2) * 32000)
		tempY = trunc(sin(cos(nsp2 / 1000) + nsp / 2) * 30000)
	elseif setup == 12 then
		if nsp ~= 0 then
			stepNsp2()
			tempX = trunc(cos(sin(nsp2 / 2) / (sqrt(abs(nsp)) / 10 + 1) + nsp2 / 100) * 32000)
			tempY = trunc(sin(cos(nsp2 / 2) / (sqrt(abs(nsp)) / 10 + 1) + nsp2 / 100) * 30000)
		end
	elseif setup == 13 then
		if nsp ~= 0 then
			stepNsp2()
			tempX = trunc(cos(sin(nsp2 / 10) / 2 + nsp / 20) * 32000)
			tempY = trunc(sin(sin(nsp2 / 11) / 2 + nsp / 20) * 30000)
		end
	elseif setup == 14 then
		stepNsp2()
		tempX = trunc((sin(nsp) + cos(nsp2 / 1000) * 3) * 12000)
		tempY = trunc(cos(nsp) * 10000) + nsp2
	end
end

local function JE_starlib_init()
	if starlibInitialized then return end
	starlibInitialized = true

	JE_resetValues()
	JE_changeSetup(2)
	doChange = true

	for x = 0, MAX_STARS - 1 do
		star[x] = {
			spX = (mt_rand() % 64000) - 32000,
			spY = (mt_rand() % 40000) - 20000,
			spZ = x + 1,
			lastX = 0, lastY = 0,
		}
	end
end

-- The visualizer's controls (the jukebox's buttons; the original's keys).
local function setPattern(n)
	if n > 0 then
		JE_changeSetup(n)
	else
		JE_changeSetup(1)
		setup = 0
	end
end

local function starCommand(cmd, arg)
	if cmd == "pattern" then
		setPattern(arg)
	elseif cmd == "autochange" then
		doChange = arg
	elseif cmd == "colour" then
		pColor = arg
	elseif cmd == "speed" then
		starlib_speed = arg
		speedChange = 0
	elseif cmd == "reset" then
		JE_resetValues()
		setPattern(2)
		doChange = true
	else
		return false
	end
	return true
end

-- The visualizer's settings, saved between sessions.
local function saveVisualizer(prefs)
	prefs.visualizer = { pattern = setup, autoChange = doChange, speed = starlib_speed, colour = pColor }
end

local function loadVisualizer(prefs)
	local v = prefs.visualizer
	if type(v) ~= "table" then return end
	if type(v.pattern) == "number" and v.pattern >= 0 and v.pattern <= MAX_TYPES then setPattern(v.pattern) end
	if type(v.autoChange) == "boolean" then doChange = v.autoChange end
	if type(v.speed) == "number" then starlib_speed, speedChange = v.speed, 0 end
	if type(v.colour) == "number" then pColor = v.colour end
end

-- Moves the starfield on; returns the keyboard input (if any).
local function starLibMain()
	starlib_speed = s16(starlib_speed + speedChange)

	local push = ns.pushOp
	for i = 0, MAX_STARS - 1 do
		local st = star[i]

		local tempZ = st.spZ
		tempX = idiv(st.spX, tempZ) + 160
		tempY = idiv(st.spY, tempZ) + 100
		tempZ = tempZ - starlib_speed

		if tempZ <= 0 or tempY == 0 or tempY > 198 or tempX > 318 or tempX < 1 then
			st.spZ = 500

			JE_newStar()

			st.spX = s16(tempX)
			st.spY = s16(tempY)
		else
			st.lastX = tempX
			st.lastY = tempY
			st.spZ = s16(tempZ)

			local off = tempX + tempY * 320
			if off >= 640 and off < 320 * 200 - 640 then
				local tempCol = u8(pColor + band(rshift(tempZ, 4), 31))
				push(VGAScreen, K_STAR, tempX, tempY, tempCol, true)
			end
		end
	end

	local keyboardInput = keyboardGetInput()

	if doChange then
		stepCounter = stepCounter + 1
		if stepCounter > changeTime then
			JE_changeSetup(0)
		end
	end

	if mt_rand() % 1000 == 1 then
		nspVarVarInc = mt_rand_1() * 0.01 - 0.005
	end

	nspVarInc = nspVarInc + nspVarVarInc

	return keyboardInput
end

-- jukebox.c ------------------------------------------------------------------------

function jukebox()
	local trigger_quit, quitting = false, false
	local stopped = false
	local palette_fade_steps = 15

	-- the player's choices, kept between visits
	local prefs = ns.db and ns.db.jukebox or {}
	if ns.db then ns.db.jukebox = prefs end
	prefs.shuffle = false   -- always starts in order
	if prefs.showText == nil then prefs.showText = true end

	vga_palette = vga_palette or buildVgaPalette()
	set_palette(vga_palette, 0, 255)
	fadeColor[1], fadeColor[2], fadeColor[3] = 0, 0, 0
	fadeAlpha = 1

	-- first visit since a reload: the saved settings, not the defaults
	if not starlibInitialized then
		JE_starlib_init()
		loadVisualizer(prefs)
	end

	local UI = ns.Jukebox
	UI.open()

	-- the songs played, for going back while shuffling
	local history = {}

	local function nextSong(dir)
		if dir > 0 then
			if song_playing >= 0 then
				history[#history + 1] = song_playing
				if #history > 100 then table.remove(history, 1) end
			end
			if prefs.shuffle then
				local n = mt_rand() % (MUSIC_NUM - 1)
				play_song(n >= song_playing and n + 1 or n)   -- not the same one again
			else
				play_song((song_playing + 1) % MUSIC_NUM)
			end
		elseif prefs.shuffle and #history > 0 then
			play_song(table.remove(history))
		else
			play_song((song_playing > 0 and song_playing or MUSIC_NUM) - 1)
		end
		stopped = false
	end

	while true do
		if not stopped and not audio_disabled then
			if not playing then
				nextSong(1)
			elseif song_has_looped() then
				-- the end of the song: again, or on to the next
				if prefs.loop then ns.songLoop() else nextSong(1) end
			end
		end

		setFrameCount(1)

		JE_clr256(VGAScreen)

		local keyboardInput = starLibMain()

		if prefs.showText and song_playing >= 0 then
			drawFontHvAligned(VGAScreen, idiv(VGAScreen.w, 2), 190,
				sprintf("%d %s", song_playing + 1, musicTitle[song_playing]), FONT_SMALL, ALIGN_CENTER, 1, 4)
		end

		if palette_fade_steps > 0 then
			palette_fade_steps = palette_fade_steps - 1
			if quitting then
				fadeAlpha = 1 - palette_fade_steps / 15
			else
				fadeAlpha = palette_fade_steps / 15
			end
			ns.paletteDirty = true
		end

		JE_showVGA()

		waitUntilElapsed()

		-- right-click quits (left clicks are for the controls around the window)
		local m = mouseGetInput(INPUT_NO_MOTION)
		while m do
			if m.button == SDL_BUTTON_RIGHT then trigger_quit = true end
			m = mouseGetInput(INPUT_NO_MOTION)
		end

		local cmds = UI.take()
		if keyboardInput and keyboardInput.scancode ~= -1
			and band(keyboardInput.mod, bor(KMOD_CTRL, KMOD_ALT)) == 0 then
			local sc = keyboardInput.scancode
			if sc == SDL_SCANCODE_ESCAPE then
				cmds[#cmds + 1] = { "quit" }
			elseif sc == SDL_SCANCODE_LEFT or sc == SDL_SCANCODE_UP then
				cmds[#cmds + 1] = { "prev" }
			elseif sc == SDL_SCANCODE_RETURN or sc == SDL_SCANCODE_RIGHT or sc == SDL_SCANCODE_DOWN then
				cmds[#cmds + 1] = { "next" }
			elseif sc == SDL_SCANCODE_SPACE then
				cmds[#cmds + 1] = { "playstop" }
			end
		end

		for _, c in ipairs(cmds) do
			local cmd = c[1]
			if cmd == "quit" then
				trigger_quit = true
			elseif cmd == "prev" then
				-- a few seconds in, back to the start of this song first
				local t = ns.songPosition()
				if t and t > 3 then
					restart_song()
					stopped = false
				else
					nextSong(-1)
				end
			elseif cmd == "next" then
				nextSong(1)
			elseif cmd == "play" then
				if c[2] == song_playing and not stopped then restart_song() else play_song(c[2]) end
				stopped = false
			elseif cmd == "playstop" then
				if stopped then
					if song_playing >= 0 then restart_song() else nextSong(1) end
					stopped = false
				else
					stop_song()
					stopped = true
				end
			elseif cmd == "shuffle" then
				prefs.shuffle = not prefs.shuffle
			elseif cmd == "loop" then
				prefs.loop = not prefs.loop
			elseif cmd == "text" then
				prefs.showText = c[2]
			elseif starCommand(cmd, c[2]) then
				saveVisualizer(prefs)
			end
		end

		UI.update({
			song = song_playing, stopped = stopped, shuffle = prefs.shuffle, loop = prefs.loop and true or false,
			showText = prefs.showText, pattern = setup, autoChange = doChange,
			speed = starlib_speed, colour = pColor,
		})

		-- user wants to quit, start fade-out
		if trigger_quit and not quitting then
			palette_fade_steps = 15
			quitting = true
		end

		-- if fade-out finished, we can finally quit
		if quitting and palette_fade_steps == 0 then
			break
		end
	end

	UI.close()
	fadeAlpha = 1
	ns.paletteDirty = true
end
