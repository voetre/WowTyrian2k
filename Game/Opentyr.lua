--[[
 WowTyrian2k: a World of Warcraft port of OpenTyrian
 Copyright (C) The OpenTyrian Development Team
 Lua port Copyright (C) 2026 voetre
 Licensed under the GNU General Public License v2 or later (see COPYING).

 demo.c, opentyr.c (main loop and setup menu), animlib.c stub
]]
local _, ns = ...
setfenv(1, ns.G)

-- demo.c -------------------------------------------------------------------------
playDemo = false
recordDemo = false
stoppedDemo = false

local demoNum = 0
local demoFile
local demoKeys = 0
local demoKeysWait = 0
local seed = 32402394

function beginPlayDemo()
	demoNum = demoNum + 1
	if demoNum > 5 then demoNum = 1 end

	demoFile = dataFileOpen(sprintf("demo.%d", demoNum))

	mt_srand(seed)
	difficultyLevel = DIFFICULTY_NORMAL

	local newEpisode = fileReadU8(demoFile)
	JE_initEpisode(newEpisode)
	levelName = fileReadCharArray(demoFile, 10)
	lvlFileNum = fileReadU8(demoFile)
	local it = player[0].items
	it.weapon[FRONT_WEAPON].id = fileReadU8(demoFile)
	it.weapon[REAR_WEAPON].id = fileReadU8(demoFile)
	it.super_arcade_mode = fileReadU8(demoFile)
	it.sidekick[LEFT_SIDEKICK] = fileReadU8(demoFile)
	it.sidekick[RIGHT_SIDEKICK] = fileReadU8(demoFile)
	it.generator = fileReadU8(demoFile)
	it.sidekick_level = fileReadU8(demoFile)
	it.sidekick_series = fileReadU8(demoFile)
	initial_episode_num = fileReadU8(demoFile)
	it.shield = fileReadU8(demoFile)
	it.special = fileReadU8(demoFile)
	it.ship = fileReadU8(demoFile)
	it.weapon[FRONT_WEAPON].power = fileReadU8(demoFile)
	it.weapon[REAR_WEAPON].power = fileReadU8(demoFile)
	fileReadString(demoFile, 3)
	levelSong = fileReadU8(demoFile)

	demoKeys = 0
	if demoFile.pos + 2 <= demoFile.len then
		demoKeysWait = fileReadU16BE(demoFile)
	else
		demoKeysWait = 0
	end
end

function playDemoKeys()
	while demoKeysWait == 0 do
		if demoFile.pos + 3 > demoFile.len then
			return false
		end
		demoKeys = fileReadU8(demoFile)
		demoKeysWait = fileReadU16BE(demoFile)
	end

	demoKeysWait = demoKeysWait - 1

	if band(demoKeys, lshift(1, KEY_SETTING_UP)) ~= 0 then
		player[0].y = player[0].y - CURRENT_KEY_SPEED
	end
	if band(demoKeys, lshift(1, KEY_SETTING_DOWN)) ~= 0 then
		player[0].y = player[0].y + CURRENT_KEY_SPEED
	end
	if band(demoKeys, lshift(1, KEY_SETTING_LEFT)) ~= 0 then
		player[0].x = player[0].x - CURRENT_KEY_SPEED
	end
	if band(demoKeys, lshift(1, KEY_SETTING_RIGHT)) ~= 0 then
		player[0].x = player[0].x + CURRENT_KEY_SPEED
	end

	button[0] = band(demoKeys, lshift(1, KEY_SETTING_FIRE)) ~= 0
	button[3] = band(demoKeys, lshift(1, KEY_SETTING_CHANGE_FIRE)) ~= 0
	button[1] = band(demoKeys, lshift(1, KEY_SETTING_LEFT_SIDEKICK)) ~= 0
	button[2] = band(demoKeys, lshift(1, KEY_SETTING_RIGHT_SIDEKICK)) ~= 0

	return true
end

function endPlayDemo()
	demoFile = nil
end

-- Demo recording is not supported (no file system access in WoW).
function beginRecordDemo() recordDemo = false end
function recordDemoKeys() end
function endRecordDemo() end

-- animlib.c ---------------------------------------------------------------------------
-- The frames of tyrend.anm are pre-decoded into texture atlases (with the
-- animation's own palette baked in) by tools/convert.py.
function playAnim(filename, startingFrame, speed)
	JE_clr256(VGAScreen)
	JE_showVGA()

	local anim = ns.gfxmeta.anim
	if not anim then return end

	-- the animation carries its own palette; show it unfaded
	set_palette(colors, 0, 255)

	for record = startingFrame, anim.frames - 1 do
		setFrameCount(speed)

		local t = math.floor(record / anim.perTex)
		local k = record % anim.perTex
		local tex = string.format("%s%02d", anim.tex, t)
		pushPic(VGAScreen, tex, 0, 0, 320, 200, (k % anim.cols) * 320, math.floor(k / anim.cols) * 200, 1024, 1024)

		JE_showVGA()

		if waitUntilGetInputOrElapsed() then
			break
		end
	end
end

-- opentyr.c ---------------------------------------------------------------------------

-- WoW controls video and audio settings, so the setup menu only offers
-- the game options that make sense here.
function setupMenu()
	if not shopSpriteSheet.data then
		JE_loadCompShapes(shopSpriteSheet, '1')
	end

	local items = {
		[0] = { name = "Music", desc = "Toggle the music." },
		{ name = "Sound Effects", desc = "Toggle sound effects." },
		{ name = "Window Scale", desc = "Change the size of the game window." },
		{ name = "Jukebox", desc = "Play the game's music." },
		{ name = "Done", desc = "Return to the main menu." },
	}
	local count = 5
	local selected = 0
	local restart = true

	local xMenuItemName = 45
	local xMenuItemValue = 180
	local yMenuItems = 37
	local dyMenuItems = 21

	while true do
		setFrameCount(1)

		if restart then
			JE_loadPic(VGAScreen2, 2, false)
			fill_rectangle_wh(VGAScreen2, 0, 192, 320, 8, 0)
		end

		surfaceCopy(VGAScreen, VGAScreen2)

		drawFontHvShadowAligned(VGAScreen, 160, 4, "Setup", FONT_LARGE, ALIGN_CENTER, 15, -3, false, 2)

		for i = 0, count - 1 do
			local yy = yMenuItems + dyMenuItems * i
			local sel = i == selected
			drawFontHvShadow(VGAScreen, xMenuItemName, yy, items[i].name, FONT_NORMAL, 15, -3 + (sel and 2 or 0), false, 2)

			local value
			if i == 0 then
				value = music_disabled and "Off" or "On"
			elseif i == 1 then
				value = samples_disabled and "Off" or "On"
			elseif i == 2 then
				value = tostring(ns.getScale()) .. "x"
			end
			if value then
				drawFontHvShadow(VGAScreen, xMenuItemValue, yy, value, FONT_NORMAL, 15, -3 + (sel and 2 or 0), false, 2)
			end
		end

		JE_textShade(VGAScreen, xMenuItemName, 190, items[selected].desc, 15, 4, PART_SHADE)

		if restart then
			mouseCursor = MOUSE_POINTER_NORMAL
			fade_palette(colors, 10, 0, 255)
			restart = false
		end

		JE_showVGA()

		waitUntilElapsed()
		waitUntilHasInput(INPUT_ANY)

		local action, done, delta = false, false, 0
		local mouseInput = mouseGetInput(INPUT_ANY)
		if mouseInput then
			for i = 0, count - 1 do
				local yy = yMenuItems + dyMenuItems * i
				if mouseInput.y >= yy and mouseInput.y < yy + 13 and mouseInput.x >= xMenuItemName and mouseInput.x < 280 then
					if selected ~= i then
						JE_playSampleNum(S_CURSOR)
						selected = i
					end
					if mouseInput.button == SDL_BUTTON_LEFT then
						action = true
					end
				end
			end
			if mouseInput.button == SDL_BUTTON_RIGHT then
				done = true
			end
		else
			local k = keyboardGetInput()
			if k then
				local sc = k.scancode
				if sc == SDL_SCANCODE_UP then
					JE_playSampleNum(S_CURSOR)
					selected = (selected == 0) and count - 1 or selected - 1
				elseif sc == SDL_SCANCODE_DOWN then
					JE_playSampleNum(S_CURSOR)
					selected = (selected == count - 1) and 0 or selected + 1
				elseif sc == SDL_SCANCODE_LEFT then
					delta = -1
				elseif sc == SDL_SCANCODE_RIGHT then
					delta = 1
				elseif sc == SDL_SCANCODE_SPACE or sc == SDL_SCANCODE_RETURN then
					action = true
				elseif sc == SDL_SCANCODE_ESCAPE then
					done = true
				end
			end
		end

		if action or delta ~= 0 then
			if selected == 0 then
				JE_playSampleNum(S_CLICK)
				music_disabled = not music_disabled
				if music_disabled then stop_song() else restart_song() end
			elseif selected == 1 then
				samples_disabled = not samples_disabled
				JE_playSampleNum(S_CLICK)
			elseif selected == 2 then
				JE_playSampleNum(S_CLICK)
				local s = ns.getScale() + (delta < 0 and -1 or 1)
				if s > 6 then s = 1 elseif s < 1 then s = 6 end
				ns.db.scale = s
				ns.setScale(s)
			elseif selected == 3 and action then
				JE_playSampleNum(S_SELECT)
				fade_black(10)

				jukebox()

				restart = true
			elseif selected == 4 and action then
				JE_playSampleNum(S_SELECT)
				done = true
			end
		end

		if done then
			JE_playSampleNum(S_SPRING)
			fade_black(10)
			return
		end
	end
end

function ns.quitGame()
	ns.quitRequested = true
	error("WT2K_QUIT", 0)
end

local initialized = false

local function initialize()
	if initialized then return end
	initialized = true

	mt_srand(math.floor((_G_REAL.time and _G_REAL.time() or 0) % 4294967296))

	loadConfiguration()
	loadSaves()

	JE_scanForEpisodes()

	loadPals()
	JE_loadMainShapeTables("tyrian.shp")

	youAreCheating = false
	smoothScroll = true
	loadDestruct = false

	JE_loadHelpText()
end

-- The game program; runs inside a coroutine (see Core/Main.lua).
function ns.gameMain()
	initialize()

	local afterRun = false
	while true do
		if not stoppedDemo and not afterRun and not ns.genLevelRequest and not (ns.options and ns.options.skipLogos) then
			intro_logos()
		end

		JE_initPlayerData()
		JE_sortHighScores()

		playDemo = false
		stoppedDemo = false

		gameLoaded = false
		jumpSection = false
		afterRun = false

		if ns.genLevelRequest then
			-- /tyrian genlevel: straight into a generated level
			local req = ns.genLevelRequest
			ns.genLevelRequest = nil
			local g, run, bonus
			local flight = ns.Flight and ns.Flight.current
			if LevelGen.beginTest(req.name, req.seed, req.seconds) then
				JE_main()
				g = genLevel
				run = LevelGen.levelStats()
				-- a bonus level when it was finished with flight to spare;
				-- genLevel is cleared so its hooks stay out of the way
				if LevelGen.offerBonus(g) then
					genLevel = nil
					JE_main()
					bonus = LevelGen.levelStats()
					bonusRun = nil
					bonusLevelCurrent = false
					genLevel = g
				end
			end
			LevelGen.endTest()
			if g then
				-- score card, then close the game (the next Show or flight
				-- starts a fresh one) unless the options keep it open
				LevelGen.recordRun(g, run, bonus, flight)
				local o = ns.options or {}
				if o.scoreCard ~= false then
					LevelGen.scoreCard(g, run, bonus, flight)
				else
					LevelGen.blankScreen()
				end
				if not o.keepOpen then break end
				afterRun = true
			end
		elseif not titleScreen() then
			-- Esc or Quit on the title screen closes the game
			break
		elseif loadDestruct then
			JE_destructGame()

			loadDestruct = false
		else
			JE_main()

			if trentWin then
				break
			end
		end
	end

	saveConfiguration()
	saveSaves()
	stop_song()
end
