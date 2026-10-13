--[[
 WowTyrian2k: a World of Warcraft port of OpenTyrian
 Copyright (C) The OpenTyrian Development Team
 Lua port Copyright (C) 2026 voetre
 Licensed under the GNU General Public License v2 or later (see COPYING).

 destruct.c - the hidden "Destruct" mini-game (Scorched Earth style).

 The original keeps the terrain in a 320x200 pixel buffer (destructTempScreen)
 and copies it to the screen every tick.  Here the buffer is a Lua array
 initialised from the arena picture's palette indexes; it is rendered as the
 arena picture plus horizontal runs of the pixels that differ from it, which
 are rebuilt only for columns that changed (terrain is mostly vertical
 columns of dirt, so column runs need far fewer quads than row runs).  Fading explosion pixels (palette
 241..255) are tracked in a "hot" set instead of scanning the whole buffer.
]]
local _, ns = ...
setfenv(1, ns.G)

local floor, sin, cos = math.floor, math.sin, math.cos
local strbyte = string.byte

local MAX_KEY_OPTIONS = 4

local STATE_INIT, STATE_RELOAD, STATE_CONTINUE = 0, 1, 2
local PLAYER_LEFT, PLAYER_RIGHT, MAX_PLAYERS = 0, 1, 2

local MODE_5CARDWAR, MODE_TRADITIONAL, MODE_HELIASSAULT, MODE_HELIDEFENSE, MODE_OUTGUNNED, MODE_CUSTOM = 0, 1, 2, 3, 4, 5
local MODE_FIRST, MODE_LAST, MODE_NONE = 0, 5, -1

local UNIT_TANK, UNIT_NUKE, UNIT_DIRT, UNIT_SATELLITE, UNIT_MAGNET, UNIT_LASER, UNIT_JUMPER, UNIT_HELI = 0, 1, 2, 3, 4, 5, 6, 7

local SHOT_TRACER, SHOT_SMALL, SHOT_LARGE, SHOT_MICRO, SHOT_SUPER, SHOT_DEMO, SHOT_SMALLNUKE, SHOT_LARGENUKE,
      SHOT_SMALLDIRT, SHOT_LARGEDIRT, SHOT_MAGNET, SHOT_MINILASER, SHOT_MEGALASER, SHOT_LASERTRACER,
      SHOT_MEGABLAST, SHOT_MINI, SHOT_BOMB = 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16
local SHOT_FIRST, SHOT_LAST, SHOT_INVALID = 0, 16, -1

local EXPL_NONE, EXPL_MAGNET, EXPL_DIRT, EXPL_NORMAL = 0, 1, 2, 3
local TRAILS_NONE, TRAILS_NORMAL, TRAILS_FULL = 0, 1, 2

local PIXEL_BLACK, PIXEL_DIRT = 0, 25

local MAP_NORMAL, MAP_WALLS, MAP_RINGS, MAP_HOLES, MAP_FUZZY, MAP_TALL = 0, 1, 2, 4, 8, 16

local MOVE_LEFT, MOVE_RIGHT, MOVE_UP, MOVE_DOWN, MOVE_CHANGE, MOVE_FIRE, MOVE_CYUP, MOVE_CYDN = 0, 1, 2, 3, 4, 5, 6, 7
local KEY_CHANGE, KEY_CYUP, KEY_CYDN = 4, 6, 7
local MAX_KEY = 8

local function arr(t) local r = {}; for i, v in ipairs(t) do r[i - 1] = v end return r end

local demolish     = arr({ false, false, false, false, false, true, true, true, false, false, false, false, true, false, true, false, true })
local shotTrail    = arr({ 0, 0, 0, 1, 1, 1, 2, 2, 0, 0, 0, 1, 2, 1, 2, 1, 0 })
local shotDelay    = arr({ 10, 30, 80, 20, 60, 100, 140, 200, 20, 60, 5, 15, 50, 5, 80, 16, 0 })
local shotSound    = arr({ S_SELECT, S_WEAPON_2, S_WEAPON_1, S_WEAPON_7, S_WEAPON_7, S_EXPLOSION_9, S_EXPLOSION_22, S_EXPLOSION_22, S_WEAPON_5, S_WEAPON_13, S_WEAPON_10, S_WEAPON_15, S_WEAPON_15, S_WEAPON_26, S_WEAPON_14, S_WEAPON_7, S_WEAPON_7 })
local exploSize    = arr({ 4, 20, 30, 14, 22, 16, 40, 60, 10, 30, 0, 5, 10, 3, 15, 7, 0 })
local shotBounce   = arr({ false, false, false, false, false, false, false, false, false, false, false, true, true, true, true, false, true })
local exploDensity = arr({ 2, 5, 10, 15, 20, 15, 25, 30, 40, 80, 0, 30, 30, 4, 30, 5, 0 })
local shotDirt     = arr({ 3, 3, 3, 3, 3, 3, 3, 3, 2, 2, 1, 3, 3, 3, 3, 3, 0 })
local shotColor    = arr({ 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 10, 10, 10, 10, 16, 0 })

local defaultWeapon     = arr({ SHOT_SMALL, SHOT_MICRO, SHOT_SMALLDIRT, SHOT_INVALID, SHOT_MAGNET, SHOT_MINILASER, SHOT_MICRO, SHOT_MINI })
local defaultCpuWeapon  = arr({ SHOT_SMALL, SHOT_MICRO, SHOT_DEMO, SHOT_INVALID, SHOT_MAGNET, SHOT_MINILASER, SHOT_MICRO, SHOT_MINI })
local defaultCpuWeaponB = arr({ SHOT_DEMO, SHOT_SMALLNUKE, SHOT_DEMO, SHOT_INVALID, SHOT_MAGNET, SHOT_MEGALASER, SHOT_MICRO, SHOT_MINI })
local systemAngle       = arr({ true, true, true, false, false, true, false, false })
local baseDamage        = arr({ 200, 120, 400, 300, 80, 150, 600, 40 })
local systemAni         = arr({ false, false, false, true, false, false, false, true })

local weaponSystems = {
	[0] = arr({ 1, 1, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }),
	arr({ 0, 0, 0, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0 }),
	arr({ 0, 0, 0, 0, 0, 1, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0 }),
	arr({ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }),
	arr({ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0 }),
	arr({ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0 }),
	arr({ 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0 }),
	arr({ 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0 }),
}

local goodsel = arr({ 1, 2, 6, 12, 13, 14, 17, 23, 24, 26, 28, 29, 32, 33 })

local basetypes = {
	[0] = arr({ 5, UNIT_TANK, UNIT_TANK, UNIT_NUKE, UNIT_DIRT, UNIT_DIRT, UNIT_SATELLITE, UNIT_MAGNET, UNIT_LASER, UNIT_JUMPER, UNIT_HELI }),
	arr({ 1, UNIT_TANK, UNIT_TANK, UNIT_TANK, UNIT_TANK, UNIT_TANK, UNIT_TANK, UNIT_TANK, UNIT_TANK, UNIT_TANK, UNIT_TANK }),
	arr({ 4, UNIT_HELI, UNIT_HELI, UNIT_HELI, UNIT_HELI, UNIT_HELI, UNIT_HELI, UNIT_HELI, UNIT_HELI, UNIT_HELI, UNIT_HELI }),
	arr({ 8, UNIT_TANK, UNIT_TANK, UNIT_TANK, UNIT_NUKE, UNIT_NUKE, UNIT_NUKE, UNIT_DIRT, UNIT_MAGNET, UNIT_LASER, UNIT_JUMPER }),
	arr({ 8, UNIT_HELI, UNIT_HELI, UNIT_HELI, UNIT_HELI, UNIT_HELI, UNIT_HELI, UNIT_HELI, UNIT_HELI, UNIT_HELI, UNIT_HELI }),
	arr({ 4, UNIT_TANK, UNIT_TANK, UNIT_TANK, UNIT_TANK, UNIT_NUKE, UNIT_NUKE, UNIT_DIRT, UNIT_MAGNET, UNIT_JUMPER, UNIT_JUMPER }),
	arr({ 8, UNIT_TANK, UNIT_NUKE, UNIT_DIRT, UNIT_SATELLITE, UNIT_MAGNET, UNIT_LASER, UNIT_JUMPER, UNIT_HELI, UNIT_TANK, UNIT_NUKE }),
	arr({ 4, UNIT_TANK, UNIT_TANK, UNIT_NUKE, UNIT_DIRT, UNIT_TANK, UNIT_LASER, UNIT_JUMPER, UNIT_HELI, UNIT_NUKE, UNIT_JUMPER }),
	arr({ 5, UNIT_TANK, UNIT_TANK, UNIT_NUKE, UNIT_DIRT, UNIT_DIRT, UNIT_SATELLITE, UNIT_MAGNET, UNIT_LASER, UNIT_JUMPER, UNIT_HELI }),
	arr({ 5, UNIT_TANK, UNIT_TANK, UNIT_NUKE, UNIT_DIRT, UNIT_DIRT, UNIT_SATELLITE, UNIT_MAGNET, UNIT_LASER, UNIT_JUMPER, UNIT_HELI }),
}
local baseLookup = { [0] = arr({ 0, 1, 3, 4, 6, 8 }), arr({ 0, 1, 2, 5, 7, 9 }) }
local GraphicBase = { [0] = arr({ 1, 6, 11, 58, 63, 68, 96, 153 }), arr({ 20, 25, 30, 77, 82, 87, 115, 172 }) }
local ModeScore = { [0] = arr({ 1, 0, 0, 5, 0, 1 }), arr({ 1, 0, 5, 0, 1, 1 }) }

local KP_0, KP_2, KP_3, KP_4, KP_5, KP_6, KP_8, KP_9 = 98, 90, 91, 92, 93, 94, 96, 97
local SC_V, SC_X, SC_Z = SDL_SCANCODE_A + 21, SDL_SCANCODE_A + 23, SDL_SCANCODE_A + 25

local defaultKeyConfig = {
	[0] = {
		[0] = { [0] = SDL_SCANCODE_C },
		{ [0] = SC_V },
		{ [0] = SDL_SCANCODE_A },
		{ [0] = SC_Z },
		{ [0] = SDL_SCANCODE_LALT },
		{ [0] = SC_X, SDL_SCANCODE_LSHIFT },
		{ [0] = SDL_SCANCODE_LCTRL },
		{ [0] = SDL_SCANCODE_SPACE },
	},
	{
		[0] = { [0] = SDL_SCANCODE_LEFT, KP_4 },
		{ [0] = SDL_SCANCODE_RIGHT, KP_6 },
		{ [0] = SDL_SCANCODE_UP, KP_8 },
		{ [0] = SDL_SCANCODE_DOWN, KP_2 },
		{ [0] = SDL_SCANCODE_BACKSLASH, KP_5 },
		{ [0] = SDL_SCANCODE_INSERT, SDL_SCANCODE_RETURN, KP_0, SDL_SCANCODE_KP_ENTER },
		{ [0] = SDL_SCANCODE_PAGEUP, KP_9 },
		{ [0] = SDL_SCANCODE_PAGEDOWN, KP_3 },
	},
}

local config = {
	max_shots = 40, min_walls = 20, max_walls = 20, max_explosions = 40, max_installations = 10,
	allow_custom = false, alwaysalias = false,
	jumper_straight = { [0] = true, false }, ai = { [0] = true, false },
}

local destructFirstTime = false
local destruct_player = {}
local world = { baseMap = newArray(320, 0), mapWalls = {}, destructMode = 0, mapFlags = 0 }
local shotRec, exploRec = {}, {}
local endDelay = 0

-- The terrain pixel buffer --------------------------------------------------------

local PIC                 -- arena picture indexes (string)
local PICTEX              -- arena picture texture
local W = {}              -- terrain buffer, 0-based 320x200
local hot = {}            -- indexes of fading explosion pixels (>= 241)
local colDirty = {}
local colRuns = {}        -- per column: flat array {y, len, color, ...}

local function picAt(i) return strbyte(PIC, i + 1) end

local function setPix(i, c)
	if W[i] ~= c then
		W[i] = c
		colDirty[i % 320] = true
		if c >= 241 then hot[i] = true end
	end
end

local function resetWorld()
	for i = 0, 63999 do W[i] = strbyte(PIC, i + 1) end
	hot = {}
	for i = 12 * 320, 63999 do
		if W[i] >= 241 then hot[i] = true end
	end
	for x = 0, 319 do
		colDirty[x] = true
		colRuns[x] = colRuns[x] or {}
	end
end

-- Rebuilds the list of vertical runs of pixels that differ from the arena
-- picture (rows 12..199; the HUD rows are never copied from the buffer).
local function rebuildCol(x)
	local runs = colRuns[x]
	local n = 0
	local y = 12
	while y < 200 do
		local i = y * 320 + x
		local c = W[i]
		if c ~= strbyte(PIC, i + 1) then
			local y0 = y
			y = y + 1
			while y < 200 do
				local j = y * 320 + x
				if W[j] ~= c or c == strbyte(PIC, j + 1) then break end
				y = y + 1
			end
			runs[n + 1], runs[n + 2], runs[n + 3] = y0, y - y0, c
			n = n + 3
		else
			y = y + 1
		end
	end
	for k = n + 1, #runs do runs[k] = nil end
	colDirty[x] = false
end

-- Draws the terrain onto VGAScreen (the copy step of JE_tempScreenChecking).
local function drawWorld()
	pushPic(VGAScreen, PICTEX, 0, 0, 320, 200, 0, 0, 512, 256)
	local push = ns.pushOp
	for x = 0, 319 do
		if colDirty[x] then rebuildCol(x) end
		local runs = colRuns[x]
		for k = 1, #runs, 3 do
			push(VGAScreen, K_RECT, x, runs[k], 1, runs[k + 1], runs[k + 2], 0)
		end
	end
end

-- Helpers -----------------------------------------------------------------------------

local function isValidUnit(unit) return unit.health > 0 end

local function eSoundChannel()
	ns.exploSoundChannel = (ns.exploSoundChannel or 0) + 1
	if ns.exploSoundChannel > 5 then ns.exploSoundChannel = 1 end
	return ns.exploSoundChannel
end

local function JE_eSound(sound)
	soundQueue[eSoundChannel()] = sound
end

local function JE_pixCool(x_, y_, c)
	JE_pix(VGAScreen, x_, y_, c)
	JE_pix(VGAScreen, x_ - 1, y_, c - 2)
	JE_pix(VGAScreen, x_ + 1, y_, c - 2)
	JE_pix(VGAScreen, x_, y_ - 1, c - 2)
	JE_pix(VGAScreen, x_, y_ + 1, c - 2)
end

-- Screens -------------------------------------------------------------------------

local function waitAnyKey()
	while true do
		setFrameCount(1)
		delayUntilElapsed()
		if keyboardGetInput() then break end
		ns.yieldFrame()
	end
end

local function JE_introScreen()
	surfaceCopy(VGAScreen2, VGAScreen)
	JE_outText(VGAScreen, JE_fontCenter(specialName[7], TINY_FONT), 90, specialName[7], 12, 5)
	JE_outText(VGAScreen, JE_fontCenter(miscText[64], TINY_FONT), 180, miscText[64], 15, 2)
	JE_outText(VGAScreen, JE_fontCenter(miscText[65], TINY_FONT), 190, miscText[65], 15, 2)
	JE_showVGA()
	fade_palette(colors, 15, 0, 255)

	waitAnyKey()

	fade_black(15)
	surfaceCopy(VGAScreen, VGAScreen2)
	JE_showVGA()
end

local function DrawModeSelectMenu(mode)
	local i = 0
	while i < DESTRUCT_MODES do
		JE_textShade(VGAScreen, JE_fontCenter(destructModeName[i], TINY_FONT), 82 + i * 12, destructModeName[i], 12, b2n(i == mode) * 4, FULL_SHADE)
		i = i + 1
	end
	if config.allow_custom then
		JE_textShade(VGAScreen, JE_fontCenter("Custom", TINY_FONT), 82 + i * 12, "Custom", 12, b2n(i == mode) * 4, FULL_SHADE)
	end
end

local function JE_modeSelect()
	surfaceCopy(VGAScreen2, VGAScreen)
	local mode = MODE_5CARDWAR

	DrawModeSelectMenu(mode)
	JE_showVGA()
	fade_palette(colors, 15, 0, 255)

	while true do
		surfaceCopy(VGAScreen, VGAScreen2)
		DrawModeSelectMenu(mode)
		JE_showVGA()

		while true do
			setFrameCount(1)
			delayUntilElapsed()
			if keyboardHasInput() then break end
			ns.yieldFrame()
		end

		local done = false
		local k = keyboardGetInput()
		if k then
			local sc = k.scancode
			if sc == SDL_SCANCODE_ESCAPE then
				mode = MODE_NONE
				done = true
			elseif sc == SDL_SCANCODE_RETURN or sc == SDL_SCANCODE_SPACE then
				done = true
			elseif sc == SDL_SCANCODE_UP then
				if mode == MODE_FIRST then
					mode = config.allow_custom and MODE_LAST or MODE_LAST - 1
				else
					mode = mode - 1
				end
			elseif sc == SDL_SCANCODE_DOWN then
				if mode >= MODE_LAST - 1 then
					if config.allow_custom and mode == MODE_LAST - 1 then
						mode = mode + 1
					else
						mode = MODE_FIRST
					end
				else
					mode = mode + 1
				end
			end
		end

		if done then break end
	end

	fade_black(15)
	surfaceCopy(VGAScreen, VGAScreen2)
	JE_showVGA()
	return mode
end

local function JE_helpScreen()
	fade_black(15)
	surfaceCopy(VGAScreen2, VGAScreen)
	JE_clr256(VGAScreen)

	for i = 0, 1 do
		JE_outText(VGAScreen, 100, 5 + i * 90, destructHelp[i * 12 + 0], 2, 4)
		JE_outText(VGAScreen, 100, 15 + i * 90, destructHelp[i * 12 + 1], 2, 1)
		for j = 3, 12 do
			JE_outText(VGAScreen, ((j - 1) % 2) * 160 + 10, 15 + idiv(j - 1, 2) * 12 + i * 90, destructHelp[i * 12 + j - 1], 1, 3)
		end
	end
	JE_outText(VGAScreen, 30, 190, destructHelp[24], 3, 4)
	JE_showVGA()
	fade_palette(colors, 15, 0, 255)

	waitAnyKey()

	fade_black(15)
	surfaceCopy(VGAScreen, VGAScreen2)
	JE_showVGA()
	fade_palette(colors, 15, 0, 255)
end

local function JE_pauseScreen()
	surfaceCopy(VGAScreen2, VGAScreen)
	JE_outText(VGAScreen, JE_fontCenter(miscText[22], TINY_FONT), 90, miscText[22], 12, 5)
	JE_showVGA()

	waitAnyKey()

	surfaceCopy(VGAScreen, VGAScreen2)
	JE_showVGA()
end

-- Level generation ------------------------------------------------------------------

local function JE_placementPosition(passed_x, width, baseWorld)
	local new_y = 0
	for i = passed_x, passed_x + width - 1 do
		if new_y < (baseWorld[i] or 0) then new_y = baseWorld[i] end
	end
	for i = passed_x, passed_x + width - 1 do
		baseWorld[i] = new_y
	end
	return new_y
end

local function DE_generateBaseTerrain(mapFlags, baseWorld)
	local sinewave = mt_rand_lt1() * M_PI / 50 + 0.01
	local sinewave2 = mt_rand_lt1() * M_PI / 50 + 0.01
	local cosinewave = mt_rand_lt1() * M_PI / 50 + 0.01
	local cosinewave2 = mt_rand_lt1() * M_PI / 50 + 0.01
	local HeightMul = 20

	if band(mapFlags, MAP_FUZZY) ~= 0 then
		sinewave = M_PI - mt_rand_lt1() * 0.3
		sinewave2 = M_PI - mt_rand_lt1() * 0.3
	end
	if band(mapFlags, MAP_TALL) ~= 0 then
		HeightMul = 100
	end

	for i = 1, 318 do
		local newheight = roundf(sin(sinewave * i) * HeightMul + sin(sinewave2 * i) * 15 +
		                         cos(cosinewave * i) * 10 + sin(cosinewave2 * i) * 15) + 130
		if newheight < 40 then
			newheight = 40
		elseif newheight > 195 then
			newheight = 195
		end
		baseWorld[i] = newheight
	end
end

local function DE_drawBaseTerrain(baseWorld)
	for i = 1, 318 do
		for yy = baseWorld[i], 199 do
			setPix(yy * 320 + i, PIXEL_DIRT)
		end
	end
end

local function DE_generateUnits(baseWorld)
	for i = 0, MAX_PLAYERS - 1 do
		local numSatellites = 0
		local pl = destruct_player[i]
		pl.unitsRemaining = 0

		local bt = basetypes[baseLookup[i][world.destructMode]]
		for j = 0, bt[0] - 1 do
			local u = pl.unit[j]
			if i == PLAYER_LEFT then
				u.unitX = (mt_rand() % 120) + 10
			else
				u.unitX = 320 - ((mt_rand() % 120) + 22)
			end

			u.unitY = JE_placementPosition(u.unitX - 1, 14, baseWorld)
			u.unitType = bt[(mt_rand() % 10) + 1]

			if u.unitType == UNIT_SATELLITE then
				if numSatellites == bt[0] then
					u.unitType = UNIT_TANK
					pl.unitsRemaining = pl.unitsRemaining + 1
				else
					u.unitY = 30 + (mt_rand() % 40)
					numSatellites = numSatellites + 1
				end
			else
				pl.unitsRemaining = pl.unitsRemaining + 1
			end

			u.lastMove = 0
			u.unitYMov = 0
			u.isYInAir = false
			u.angle = 0
			u.power = (u.unitType == UNIT_LASER) and 6 or 3
			u.shotType = defaultWeapon[u.unitType]
			u.health = baseDamage[u.unitType]
			u.ani_frame = 0
		end
	end
end

local function DE_generateWalls()
	if band(world.mapFlags, MAP_WALLS) == 0 then
		for i = 0, config.max_walls - 1 do
			world.mapWalls[i].wallExist = false
		end
		return
	end

	local remainWalls = (math.random(0, 32767) % (config.max_walls - config.min_walls + 1)) + config.min_walls

	repeat
		local wallHeight = (mt_rand() % 5) + 1
		if wallHeight > remainWalls then
			wallHeight = remainWalls
		end

		local wallX
		local tries = 0
		local isGood
		repeat
			isGood = true
			wallX = (mt_rand() % 300) + 10

			for i = 0, MAX_PLAYERS - 1 do
				for j = 0, config.max_installations - 1 do
					local u = destruct_player[i].unit[j]
					if wallX > u.unitX - 12 and wallX < u.unitX + 13 then
						isGood = false
						break
					end
				end
				if not isGood then break end
			end

			tries = tries + 1
		until isGood or tries >= 5

		for i = 1, wallHeight do
			local w = world.mapWalls[remainWalls - i]
			w.wallExist = true
			w.wallX = wallX
			w.wallY = JE_placementPosition(wallX, 12, world.baseMap) - 14 * i
		end

		remainWalls = remainWalls - wallHeight
	until remainWalls == 0
end

local function DE_generateRings(pixel)
	local rings = mt_rand() % 6 + 1
	for i = 1, rings do
		local tempPosX1 = mt_rand() % 320
		local tempPosY1 = (mt_rand() % 160) + 20
		local tempSize = (mt_rand() % 40) + 10

		for j = 1, tempSize * tempSize * 2 do
			local tempRadian = mt_rand_lt1() * (2 * M_PI)
			local tempPosY2 = tempPosY1 + roundf(cos(tempRadian) * (mt_rand_lt1() * 0.1 + 0.9) * tempSize)
			local tempPosX2 = tempPosX1 + roundf(sin(tempRadian) * (mt_rand_lt1() * 0.1 + 0.9) * tempSize)
			if tempPosY2 > 12 and tempPosY2 < 200 and tempPosX2 > 0 and tempPosX2 < 319 then
				setPix(tempPosX2 + tempPosY2 * 320, pixel)
			end
		end
	end
end

local function aliasDirtPixel(x_, y_, i)
	local newColor = PIXEL_BLACK
	if y_ > 0 and W[i - 320] == PIXEL_DIRT then newColor = newColor + 1 end
	if y_ < 199 and W[i + 320] == PIXEL_DIRT then newColor = newColor + 3 end
	if x_ > 0 and W[i - 1] == PIXEL_DIRT then newColor = newColor + 2 end
	if x_ < 319 and W[i + 1] == PIXEL_DIRT then newColor = newColor + 2 end
	if newColor ~= PIXEL_BLACK then
		return newColor + 16
	end
	return PIXEL_BLACK
end

local function JE_aliasDirt()
	for y_ = 12, 199 do
		for x_ = 0, 319 do
			local i = y_ * 320 + x_
			if W[i] == PIXEL_BLACK then
				setPix(i, aliasDirtPixel(x_, y_, i))
			end
		end
	end
end

local function JE_generateTerrain()
	world.mapFlags = MAP_NORMAL

	if mt_rand() % 2 == 0 then world.mapFlags = bor(world.mapFlags, MAP_WALLS) end
	if mt_rand() % 4 == 0 then world.mapFlags = bor(world.mapFlags, MAP_HOLES) end
	local r = mt_rand() % 4
	if r == 0 then
		world.mapFlags = bor(world.mapFlags, MAP_FUZZY)
	elseif r == 1 then
		world.mapFlags = bor(world.mapFlags, MAP_TALL)
	elseif r == 2 then
		world.mapFlags = bor(world.mapFlags, MAP_RINGS)
	end

	play_song(goodsel[mt_rand() % 14] - 1)

	resetWorld()

	DE_generateBaseTerrain(world.mapFlags, world.baseMap)
	DE_generateUnits(world.baseMap)
	DE_generateWalls()
	DE_drawBaseTerrain(world.baseMap)

	if band(world.mapFlags, MAP_RINGS) ~= 0 then
		DE_generateRings(PIXEL_DIRT)
	end
	if band(world.mapFlags, MAP_HOLES) ~= 0 then
		DE_generateRings(PIXEL_BLACK)
	end

	JE_aliasDirt()
	drawWorld()
	JE_showVGA()
end

local function JE_stabilityCheck(x_, y_)
	local numDirtPixels = 0
	local i = x_ + y_ * 320 - 1
	for k = 0, 11 do
		if W[i + k] == PIXEL_DIRT then
			numDirtPixels = numDirtPixels + 1
		end
	end
	return numDirtPixels < 10
end

-- JE_tempScreenChecking: fade explosion pixels, then copy to the screen
local function JE_tempScreenChecking()
	for i in pairs(hot) do
		local v = W[i]
		if v >= 241 then
			if v == 241 then
				W[i] = PIXEL_BLACK
				hot[i] = nil
			else
				W[i] = v - 1
			end
			colDirty[i % 320] = true
		else
			hot[i] = nil
		end
	end

	drawWorld()
end

local starPattern = {
	[0] = arr({ 0, 0, 246, 0, 0 }), arr({ 0, 247, 249, 247, 0 }), arr({ 246, 249, 252, 249, 246 }),
	arr({ 0, 247, 249, 247, 0 }), arr({ 0, 0, 246, 0, 0 }),
}
local starIntensity = {
	[0] = arr({ 0, 0, 1, 0, 0 }), arr({ 0, 1, 2, 1, 0 }), arr({ 1, 2, 4, 2, 1 }),
	arr({ 0, 1, 2, 1, 0 }), arr({ 0, 0, 1, 0, 0 }),
}

local function JE_superPixel(tempPosX, tempPosY)
	for yy = 0, 4 do
		local py = tempPosY + yy - 2
		if py >= 0 and py < 200 then
			for xx = 0, 4 do
				local px = tempPosX + xx - 2
				local pat = starPattern[yy][xx]
				if px >= 0 and px < 320 and pat ~= 0 then
					local i = py * 320 + px
					local v = W[i]
					if v < pat then
						setPix(i, pat)
					elseif v + starIntensity[yy][xx] > 255 then
						setPix(i, 255)
					else
						setPix(i, v + starIntensity[yy][xx])
					end
				end
			end
		end
	end
end

-- Resets ---------------------------------------------------------------------------

local function DE_ResetUnits()
	for p = 0, MAX_PLAYERS - 1 do
		for u = 0, config.max_installations - 1 do
			destruct_player[p].unit[u].health = 0
		end
	end
end

local function DE_ResetPlayers()
	for i = 0, MAX_PLAYERS - 1 do
		local p = destruct_player[i]
		p.is_cpu = false
		p.unitSelected = 0
		p.shotDelay = 0
		p.score = 0
		p.aiMemory = { c_Angle = 0, c_Power = 0, c_Fire = 0, c_noDown = 0 }
		p.keys = {}
		for k = 0, MAX_KEY - 1 do
			p.keys[k] = {}
			for s = 0, MAX_KEY_OPTIONS - 1 do
				p.keys[k][s] = defaultKeyConfig[i][k][s] or SDL_SCANCODE_UNKNOWN
			end
		end
	end
end

local function DE_ResetWeapons()
	for i = 0, config.max_shots - 1 do shotRec[i].isAvailable = true end
	for i = 0, config.max_explosions - 1 do exploRec[i].isAvailable = true end
end

local function DE_ResetAI()
	for i = PLAYER_LEFT, MAX_PLAYERS - 1 do
		if destruct_player[i].is_cpu then
			for j = 0, config.max_installations - 1 do
				local u = destruct_player[i].unit[j]
				if isValidUnit(u) then
					if systemAngle[u.unitType] or u.unitType == UNIT_HELI then
						u.angle = M_PI_4
					else
						u.angle = 0
					end

					u.power = (u.unitType == UNIT_LASER) and 6 or 4

					if band(world.mapFlags, MAP_WALLS) ~= 0 then
						u.shotType = defaultCpuWeaponB[u.unitType]
					else
						u.shotType = defaultCpuWeapon[u.unitType]
					end
				end
			end
		end
	end
end

local function DE_ResetLevel()
	DE_ResetWeapons()
	JE_generateTerrain()
	DE_ResetAI()
end

local function DE_ResetActions()
	for i = 0, MAX_PLAYERS - 1 do
		local a = destruct_player[i].moves
		for m = 0, 7 do a[m] = false end
	end
end

-- Units ------------------------------------------------------------------------------

local function DE_RaiseAngle(unit)
	unit.angle = unit.angle + 0.01
	if unit.angle > M_PI_2 - 0.01 then unit.angle = M_PI_2 - 0.01 end
end

local function DE_LowerAngle(unit)
	unit.angle = unit.angle - 0.01
	if unit.angle < 0 then unit.angle = 0 end
end

local function DE_RaisePower(unit)
	unit.power = unit.power + 0.05
	if unit.power > 5 then unit.power = 5 end
end

local function DE_LowerPower(unit)
	unit.power = unit.power - 0.05
	if unit.power < 1 then unit.power = 1 end
end

local function DE_CycleWeaponUp(unit)
	repeat
		unit.shotType = unit.shotType + 1
		if unit.shotType > SHOT_LAST then unit.shotType = SHOT_FIRST end
	until weaponSystems[unit.unitType][unit.shotType] ~= 0
end

local function DE_CycleWeaponDown(unit)
	repeat
		unit.shotType = unit.shotType - 1
		if unit.shotType < SHOT_FIRST then unit.shotType = SHOT_LAST end
	until weaponSystems[unit.unitType][unit.shotType] ~= 0
end

local function JE_makeExplosion(tempPosX, tempPosY, shottype)
	local i = 0
	while i < config.max_explosions do
		if exploRec[i].isAvailable then break end
		i = i + 1
	end
	if i == config.max_explosions then return end

	local e = exploRec[i]
	e.isAvailable = false
	e.x = tempPosX
	e.y = tempPosY
	e.explowidth = 2

	if shottype ~= SHOT_INVALID then
		local tempExploSize = exploSize[shottype]
		if tempExploSize < 5 then
			JE_eSound(3)
		elseif tempExploSize < 15 then
			JE_eSound(4)
		elseif tempExploSize < 20 then
			JE_eSound(12)
		elseif tempExploSize < 40 then
			JE_eSound(11)
		else
			JE_eSound(12)
			JE_eSound(11)
		end

		e.explomax = tempExploSize
		e.explofill = exploDensity[shottype]
		e.exploType = shotDirt[shottype]
	else
		JE_eSound(4)
		e.explomax = (mt_rand() % 40) + 10
		e.explofill = (mt_rand() % 60) + 20
		e.exploType = EXPL_NORMAL
	end
end

local function DE_DestroyUnit(playerID, unit)
	JE_makeExplosion(unit.unitX + 5, roundf(unit.unitY) - 5, (unit.unitType == UNIT_HELI) and SHOT_SMALL or SHOT_INVALID)

	if unit.unitType ~= UNIT_SATELLITE then
		destruct_player[playerID].unitsRemaining = destruct_player[playerID].unitsRemaining - 1
		local other = (playerID == PLAYER_LEFT) and PLAYER_RIGHT or PLAYER_LEFT
		destruct_player[other].score = destruct_player[other].score + 1
	end
end

local function DE_GravityDrawUnit(team, unit)
	local anim_index = GraphicBase[team][unit.unitType] + unit.ani_frame
	if unit.unitType == UNIT_HELI then
		if unit.lastMove < -2 then
			anim_index = anim_index + 5
		elseif unit.lastMove > 2 then
			anim_index = anim_index + 10
		end
	else
		anim_index = anim_index + floor(unit.angle * 9.99 / M_PI)
	end

	blit_sprite2(VGAScreen, unit.unitX, roundf(unit.unitY) - 13, destructSpriteSheet, anim_index)
end

local function DE_GravityLowerUnit(unit)
	if unit.unitY < 199 then
		if JE_stabilityCheck(unit.unitX, roundf(unit.unitY)) then
			if unit.unitType == UNIT_HELI then
				unit.unitYMov = 1.5
				unit.unitY = unit.unitY + 0.2
			else
				unit.unitY = unit.unitY + 1
			end

			if unit.unitY > 199 then
				unit.unitY = 199
			end
		end
	end
end

local function DE_GravityFlyUnit(unit)
	if unit.unitY + unit.unitYMov > 199 then
		unit.unitY = 199
		unit.unitYMov = 0
		unit.isYInAir = false
		return
	end

	unit.unitY = unit.unitY + unit.unitYMov
	if unit.unitY < 24 then
		unit.unitYMov = 0
		unit.unitY = 24
	end

	if unit.unitType == UNIT_HELI then
		unit.unitYMov = unit.unitYMov + 0.0001
	else
		unit.unitYMov = unit.unitYMov + 0.03
	end

	if not JE_stabilityCheck(unit.unitX, roundf(unit.unitY)) then
		unit.unitYMov = 0
		unit.isYInAir = false
	end
end

local function DE_RunMagnet(curPlayer, magnet)
	local curEnemy = (curPlayer == PLAYER_LEFT) and PLAYER_RIGHT or PLAYER_LEFT
	local direction = (curPlayer == PLAYER_LEFT) and -1 or 1

	for i = 0, config.max_shots - 1 do
		local s = shotRec[i]
		if not s.isAvailable then
			if (curPlayer == PLAYER_LEFT and s.x > magnet.unitX) or
			   (curPlayer == PLAYER_RIGHT and s.x < magnet.unitX) then
				s.xmov = s.xmov + magnet.power * 0.1 * -direction
			end
		end
	end

	for i = 0, config.max_installations - 1 do
		local enemyUnit = destruct_player[curEnemy].unit[i]
		if isValidUnit(enemyUnit) and enemyUnit.unitType == UNIT_HELI and enemyUnit.isYInAir then
			if (curEnemy == PLAYER_RIGHT and enemyUnit.unitX + 11 < 318) or
			   (curEnemy == PLAYER_LEFT and enemyUnit.unitX > 1) then
				enemyUnit.unitX = enemyUnit.unitX - 2 * direction
			end
		end
	end
	magnet.ani_frame = 1
end

local function DE_MakeShot(curPlayer, curUnit, direction)
	local shotIndex
	for i = 0, config.max_shots - 1 do
		if shotRec[i].isAvailable then
			shotIndex = i
			break
		end
	end
	if not shotIndex then return end

	if curUnit.unitType == UNIT_HELI and not curUnit.isYInAir then
		return
	end

	soundQueue[curPlayer] = shotSound[curUnit.shotType]

	local s = shotRec[shotIndex]
	if curUnit.unitType == UNIT_HELI then
		s.x = curUnit.unitX + curUnit.lastMove * 2 + 5
		s.xmov = 0.02 * curUnit.lastMove * curUnit.lastMove * curUnit.lastMove

		if destruct_player[curPlayer].moves[MOVE_UP] and curUnit.unitY < 30 then
			s.y = curUnit.unitY
			s.ymov = 0.1

			if s.xmov < 0 then
				s.xmov = s.xmov + 0.1
			elseif s.xmov > 0 then
				s.xmov = s.xmov - 0.1
			end
		else
			s.y = curUnit.unitY + 1
			s.ymov = 0.5 + curUnit.unitYMov * 0.1
		end
	elseif curUnit.unitType == UNIT_JUMPER and not config.jumper_straight[curPlayer] then
		s.x = curUnit.unitX + 2
		s.xmov = -cos(curUnit.angle) * curUnit.power * direction

		if curUnit.isYInAir then
			s.ymov = 1
			s.y = curUnit.unitY + 2
		else
			s.ymov = -2
			s.y = curUnit.unitY - 12
		end
	else
		s.x = curUnit.unitX + 6 - cos(curUnit.angle) * 10 * direction
		s.y = curUnit.unitY - 7 - sin(curUnit.angle) * 10
		s.xmov = -cos(curUnit.angle) * curUnit.power * direction
		s.ymov = -sin(curUnit.angle) * curUnit.power
	end

	s.isAvailable = false
	s.shottype = curUnit.shotType
	for k = 0, 3 do s.trailc[k] = 0 end
end

-- Per-tick processing -----------------------------------------------------------------

local function DE_RunTickCycleDeadUnits()
	for i = 0, MAX_PLAYERS - 1 do
		local p = destruct_player[i]
		if p.unitsRemaining ~= 0 then
			local guard = 0
			while true do
				local unit = p.unit[p.unitSelected]
				if isValidUnit(unit) and unit.shotType ~= SHOT_INVALID then break end
				p.unitSelected = p.unitSelected + 1
				if p.unitSelected >= config.max_installations then
					p.unitSelected = 0
				end
				guard = guard + 1
				if guard > 50 then break end
			end
		end
	end
end

local function DE_RunTickGravity()
	for i = 0, MAX_PLAYERS - 1 do
		for j = 0, config.max_installations - 1 do
			local unit = destruct_player[i].unit[j]
			if isValidUnit(unit) then
				local t = unit.unitType
				if t == UNIT_SATELLITE then
					-- satellites don't fall down
				elseif (t == UNIT_HELI or t == UNIT_JUMPER) and unit.isYInAir then
					DE_GravityFlyUnit(unit)
				else
					DE_GravityLowerUnit(unit)
				end

				DE_GravityDrawUnit(i, unit)
			end
		end
	end
end

local function DE_RunTickAnimate()
	for p = 0, MAX_PLAYERS - 1 do
		for u = 0, config.max_installations - 1 do
			local ptr = destruct_player[p].unit[u]
			if isValidUnit(ptr) and not (not systemAni[ptr.unitType] and ptr.ani_frame == 0) then
				ptr.ani_frame = ptr.ani_frame + 1
				if ptr.ani_frame > 3 then ptr.ani_frame = 0 end
			end
		end
	end
end

local function DE_RunTickDrawWalls()
	for i = 0, config.max_walls - 1 do
		local w = world.mapWalls[i]
		if w.wallExist then
			blit_sprite2(VGAScreen, w.wallX, w.wallY, destructSpriteSheet, 42)
		end
	end
end

local function DE_TestExplosionCollision(PosX, PosY)
	for i = PLAYER_LEFT, MAX_PLAYERS - 1 do
		for j = 0, config.max_installations - 1 do
			local unit = destruct_player[i].unit[j]
			if isValidUnit(unit) and
			   PosX > unit.unitX and PosX < unit.unitX + 11 and
			   PosY < unit.unitY and PosY > unit.unitY - 11 then
				unit.health = unit.health - 1
				if unit.health <= 0 then
					DE_DestroyUnit(i, unit)
				end
			end
		end
	end
end

local function DE_RunTickExplosions()
	for i = 0, config.max_explosions - 1 do
		local e = exploRec[i]
		if not e.isAvailable then
			for j = 0, e.explofill - 1 do
				local tempRadian = mt_rand_lt1() * (2 * M_PI)
				local tempPosY = e.y + roundf(cos(tempRadian) * mt_rand_lt1() * e.explowidth)
				local tempPosX = e.x + roundf(sin(tempRadian) * mt_rand_lt1() * e.explowidth)

				while tempPosX < 0 do tempPosX = tempPosX + 320 end
				while tempPosX > 320 do tempPosX = tempPosX - 320 end

				if not (tempPosY >= 200 or tempPosY <= 15) then
					if e.exploType == EXPL_DIRT then
						if tempPosX < 320 then
							setPix(tempPosX + tempPosY * 320, PIXEL_DIRT)
						end
					elseif e.exploType == EXPL_NORMAL then
						JE_superPixel(tempPosX, tempPosY)
						DE_TestExplosionCollision(tempPosX, tempPosY)
					end
				end
			end

			e.explowidth = e.explowidth + 1
			if e.explowidth == e.explomax then
				e.isAvailable = true
			end
		end
	end
end

local function DE_DrawTrails(shot, count, decay, startColor)
	for i = count - 1, 0, -1 do
		if shot.trailc[i] > 0 and shot.traily[i] > 12 then
			JE_pixCool(shot.trailx[i], shot.traily[i], shot.trailc[i])
		end

		if i == 0 then
			shot.trailx[i] = roundf(shot.x)
			shot.traily[i] = roundf(shot.y)
			shot.trailc[i] = startColor
		else
			shot.trailx[i] = shot.trailx[i - 1]
			shot.traily[i] = shot.traily[i - 1]
			if shot.trailc[i - 1] > 0 then
				shot.trailc[i] = shot.trailc[i - 1] - decay
			end
		end
	end
end

local function DE_RunTickShots()
	for i = 0, config.max_shots - 1 do
		local s = shotRec[i]
		if not s.isAvailable then
			s.x = s.x + s.xmov
			s.y = s.y + s.ymov

			if shotBounce[s.shottype] then
				if s.y > 199 or s.y < 14 then
					s.y = s.y - s.ymov
					s.ymov = -s.ymov
				end
				if s.x < 1 or s.x > 318 then
					s.x = s.x - s.xmov
					s.xmov = -s.xmov
				end
			else
				s.ymov = s.ymov + 0.05

				if s.y > 199 then
					s.y = s.y - s.ymov
					s.ymov = -s.ymov * 0.8

					if s.xmov == 0 then
						s.xmov = s.xmov + mt_rand_lt1() - 0.5
					end
				end
			end

			if s.x > 318 or s.x < 1 then
				s.isAvailable = true
			elseif s.y > 14 then
				local tempPosX = roundf(s.x)
				local tempPosY = roundf(s.y)

				for j = 0, MAX_PLAYERS - 1 do
					for k = 0, config.max_installations - 1 do
						local unit = destruct_player[j].unit[k]
						if isValidUnit(unit) and
						   tempPosX > unit.unitX and tempPosX < unit.unitX + 11 and
						   tempPosY < unit.unitY and tempPosY > unit.unitY - 13 then
							s.isAvailable = true
							JE_makeExplosion(tempPosX, tempPosY, s.shottype)
						end
					end
				end

				local tempTrails = lshift(shotColor[s.shottype], 4) - 3
				JE_pixCool(tempPosX, tempPosY, tempTrails)

				local tr = shotTrail[s.shottype]
				if tr == TRAILS_NORMAL then
					DE_DrawTrails(s, 2, 4, tempTrails - 3)
				elseif tr == TRAILS_FULL then
					DE_DrawTrails(s, 4, 3, tempTrails - 1)
				end

				for j = 0, config.max_walls - 1 do
					local w = world.mapWalls[j]
					if w.wallExist and
					   tempPosX >= w.wallX and tempPosX <= w.wallX + 11 and
					   tempPosY >= w.wallY and tempPosY <= w.wallY + 14 then
						if demolish[s.shottype] then
							w.wallExist = false
							s.isAvailable = true
							JE_makeExplosion(tempPosX, tempPosY, s.shottype)
						else
							if s.x - s.xmov < w.wallX or s.x - s.xmov > w.wallX + 11 then
								s.xmov = -s.xmov
							end
							if s.y - s.ymov < w.wallY or s.y - s.ymov > w.wallY + 14 then
								if s.ymov < 0 then
									s.ymov = -s.ymov
								else
									s.ymov = -s.ymov * 0.8
								end
							end

							tempPosX = roundf(s.x)
							tempPosY = roundf(s.y)
						end
					end
				end

				if W[tempPosX + tempPosY * 320] == PIXEL_DIRT then
					s.isAvailable = true
					JE_makeExplosion(tempPosX, tempPosY, s.shottype)
				end
			end
		end
	end
end

local function DE_RunTickAI()
	for i = 0, MAX_PLAYERS - 1 do
		local ptrPlayer = destruct_player[i]
		if ptrPlayer.is_cpu then
			local j = i + 1
			if j >= MAX_PLAYERS then j = 0 end

			local ptrTarget = destruct_player[j]
			local ptrCurUnit = ptrPlayer.unit[ptrPlayer.unitSelected]
			local ai = ptrPlayer.aiMemory
			local mv = ptrPlayer.moves

			if ai.c_noDown > 0 then
				ai.c_noDown = ai.c_noDown - 1
			end

			if mt_rand() % 100 > 80 then
				ai.c_Angle = ai.c_Angle + (mt_rand() % 3) - 1
				if ai.c_Angle > 1 then ai.c_Angle = 1 elseif ai.c_Angle < -1 then ai.c_Angle = -1 end
			end
			if mt_rand() % 100 > 90 then
				if ai.c_Angle > 0 and ptrCurUnit.angle > M_PI_2 - (M_PI / 9) then
					ai.c_Angle = 0
				elseif ai.c_Angle < 0 and ptrCurUnit.angle < M_PI / 8 then
					ai.c_Angle = 0
				end
			end

			if mt_rand() % 100 > 93 then
				ai.c_Power = ai.c_Power + (mt_rand() % 3) - 1
				if ai.c_Power > 1 then ai.c_Power = 1 elseif ai.c_Power < -1 then ai.c_Power = -1 end
			end
			if mt_rand() % 100 > 90 then
				if ai.c_Power > 0 and ptrCurUnit.power > 4 then
					ai.c_Power = 0
				elseif ai.c_Power < 0 and ptrCurUnit.power < 3 then
					ai.c_Power = 0
				elseif ptrCurUnit.power < 2 then
					ai.c_Power = 1
				end
			end

			-- prefer helicopter
			for k = 0, config.max_installations - 1 do
				local u = ptrPlayer.unit[k]
				if isValidUnit(u) and u.unitType == UNIT_HELI then
					ptrPlayer.unitSelected = k
					break
				end
			end

			if ptrCurUnit.unitType == UNIT_HELI then
				if not ptrCurUnit.isYInAir then
					ai.c_Power = 1
				end
				if ptrCurUnit.unitX > 0 and mt_rand() % ptrCurUnit.unitX > 100 then
					ai.c_Power = 1
				end
				if mt_rand() % 240 > ptrCurUnit.unitX then
					mv[MOVE_RIGHT] = true
				elseif (mt_rand() % 20) + 300 < ptrCurUnit.unitX then
					mv[MOVE_LEFT] = true
				elseif mt_rand() % 30 == 1 then
					ai.c_Angle = (mt_rand() % 3) - 1
				end
				if ptrCurUnit.unitX > 295 and ptrCurUnit.lastMove > 1 then
					mv[MOVE_LEFT] = true
					mv[MOVE_RIGHT] = false
				end
				if ptrCurUnit.unitType ~= UNIT_HELI or ptrCurUnit.lastMove > 3 or (ptrCurUnit.unitX > 160 and ptrCurUnit.lastMove > -3) then
					local uy = roundf(ptrCurUnit.unitY)
					if uy > 0 and mt_rand() % uy < 150 and ptrCurUnit.unitYMov < 0.01 and (ptrCurUnit.unitX < 160 or ptrCurUnit.lastMove < 2) then
						mv[MOVE_FIRE] = true
					end
					ai.c_noDown = (5 - abs(ptrCurUnit.lastMove)) * (5 - abs(ptrCurUnit.lastMove)) + 3
					ai.c_Power = 1
				else
					mv[MOVE_FIRE] = false
				end

				for k = 0, config.max_installations - 1 do
					local u = ptrTarget.unit[k]
					if abs(u.unitX - ptrCurUnit.unitX) < 8 then
						if u.unitType == UNIT_SATELLITE then
							mv[MOVE_FIRE] = false
						else
							mv[MOVE_LEFT] = false
							mv[MOVE_RIGHT] = false
							if ptrCurUnit.lastMove < -1 then
								ptrCurUnit.lastMove = ptrCurUnit.lastMove + 1
							elseif ptrCurUnit.lastMove > 1 then
								ptrCurUnit.lastMove = ptrCurUnit.lastMove - 1
							end
						end
					end
				end
			else
				mv[MOVE_FIRE] = true
			end

			if mt_rand() % 200 > 198 then
				mv[MOVE_CHANGE] = true
				ai.c_Angle = 0
				ai.c_Power = 0
				ai.c_Fire = 0
			end

			if mt_rand() % 100 > 98 or ptrCurUnit.shotType == SHOT_TRACER then
				mv[MOVE_CYDN] = true
			end
			if ai.c_Angle > 0 then mv[MOVE_LEFT] = true end
			if ai.c_Angle < 0 then mv[MOVE_RIGHT] = true end
			if ai.c_Power > 0 then mv[MOVE_UP] = true end
			if ai.c_Power < 0 and ai.c_noDown == 0 then mv[MOVE_DOWN] = true end
			if ai.c_Fire > 0 then mv[MOVE_FIRE] = true end

			if ptrCurUnit.unitYMov < -0.1 and ptrCurUnit.unitType == UNIT_HELI then
				mv[MOVE_FIRE] = false
			end

			if ptrCurUnit.unitType == UNIT_LASER or ptrCurUnit.isYInAir then
				ai.c_Power = 0
			end
		end
	end
end

local function DE_RunTickDrawCrosshairs()
	for i = 0, MAX_PLAYERS - 1 do
		local direction = (i == PLAYER_LEFT) and -1 or 1
		local curUnit = destruct_player[i].unit[destruct_player[i].unitSelected]
		local tempPosX, tempPosY

		if curUnit.unitType == UNIT_HELI then
			tempPosX = curUnit.unitX + roundf(0.1 * curUnit.lastMove * curUnit.lastMove * curUnit.lastMove) + 5
			tempPosY = roundf(curUnit.unitY) + 1
		else
			tempPosX = roundf(curUnit.unitX + 6 - cos(curUnit.angle) * (curUnit.power * 8 + 7) * direction)
			tempPosY = roundf(curUnit.unitY - 7 - sin(curUnit.angle) * (curUnit.power * 8 + 7))
		end

		if tempPosY > 9 then
			if tempPosY > 11 then
				if tempPosY > 13 then
					JE_pix(VGAScreen, tempPosX, tempPosY - 2, 3)
				end
				JE_pix(VGAScreen, tempPosX + 3, tempPosY, 3)
				JE_pix(VGAScreen, tempPosX, tempPosY, 14)
				JE_pix(VGAScreen, tempPosX - 3, tempPosY, 3)
			end
			JE_pix(VGAScreen, tempPosX, tempPosY + 2, 3)
		end
	end
end

local function DE_RunTickDrawHUD()
	for i = 0, MAX_PLAYERS - 1 do
		local curUnit = destruct_player[i].unit[destruct_player[i].unitSelected]
		local startX = (i == PLAYER_LEFT) and 0 or 320 - 150

		fill_rectangle_xy(VGAScreen, startX + 5, 3, startX + 14, 8, 241)
		JE_rectangle(VGAScreen, startX + 4, 2, startX + 15, 9, 242)
		JE_rectangle(VGAScreen, startX + 3, 1, startX + 16, 10, 240)
		fill_rectangle_xy(VGAScreen, startX + 18, 3, startX + 140, 8, 241)
		JE_rectangle(VGAScreen, startX + 17, 2, startX + 143, 9, 242)
		JE_rectangle(VGAScreen, startX + 16, 1, startX + 144, 10, 240)

		blit_sprite2(VGAScreen, startX + 4, 0, destructSpriteSheet, 191 + curUnit.shotType)

		JE_outText(VGAScreen, startX + 20, 3, weaponNames[curUnit.shotType] or "", 15, 2)
		JE_outText(VGAScreen, startX + 75, 3, sprintf("dmg~%d~", curUnit.health), 15, 0)
		JE_outText(VGAScreen, startX + 110, 3, sprintf("pts~%d~", destruct_player[i].score), 15, 0)
	end
end

local function DE_RunTickGetInput()
	for player_index = 0, MAX_PLAYERS - 1 do
		local p = destruct_player[player_index]
		for key_index = 0, MAX_KEY - 1 do
			for slot_index = 0, MAX_KEY_OPTIONS - 1 do
				local key = p.keys[key_index][slot_index]
				if key == SDL_SCANCODE_UNKNOWN then break end
				if keysactive[key] then
					p.moves[key_index] = true
					if key_index == KEY_CHANGE or key_index == KEY_CYUP or key_index == KEY_CYDN then
						keysactive[key] = false
					end
					break
				end
			end
		end
	end
end

local function DE_ProcessInput()
	for player_index = 0, MAX_PLAYERS - 1 do
		local p = destruct_player[player_index]
		if p.unitsRemaining > 0 then
			local direction = (player_index == PLAYER_LEFT) and -1 or 1
			local curUnit = p.unit[p.unitSelected]
			local mv = p.moves

			if systemAngle[curUnit.unitType] then
				if mv[MOVE_LEFT] then
					if player_index == PLAYER_LEFT then DE_RaiseAngle(curUnit) else DE_LowerAngle(curUnit) end
				end
				if mv[MOVE_RIGHT] then
					if player_index == PLAYER_LEFT then DE_LowerAngle(curUnit) else DE_RaiseAngle(curUnit) end
				end
			elseif curUnit.unitType == UNIT_HELI then
				if mv[MOVE_LEFT] and curUnit.unitX > 5 then
					if JE_stabilityCheck(curUnit.unitX - 5, roundf(curUnit.unitY)) then
						if curUnit.lastMove > -5 then curUnit.lastMove = curUnit.lastMove - 1 end
						curUnit.unitX = curUnit.unitX - 1
						if JE_stabilityCheck(curUnit.unitX, roundf(curUnit.unitY)) then
							curUnit.isYInAir = true
						end
					end
				end
				if mv[MOVE_RIGHT] and curUnit.unitX < 305 then
					if JE_stabilityCheck(curUnit.unitX + 5, roundf(curUnit.unitY)) then
						if curUnit.lastMove < 5 then curUnit.lastMove = curUnit.lastMove + 1 end
						curUnit.unitX = curUnit.unitX + 1
						if JE_stabilityCheck(curUnit.unitX, roundf(curUnit.unitY)) then
							curUnit.isYInAir = true
						end
					end
				end
			end

			if curUnit.unitType ~= UNIT_LASER then
				if mv[MOVE_UP] then
					if curUnit.unitType == UNIT_HELI then
						curUnit.isYInAir = true
						curUnit.unitYMov = curUnit.unitYMov - 0.1
					elseif curUnit.unitType == UNIT_JUMPER and not curUnit.isYInAir then
						curUnit.unitYMov = -3
						curUnit.isYInAir = true
					else
						DE_RaisePower(curUnit)
					end
				end
				if mv[MOVE_DOWN] then
					if curUnit.unitType == UNIT_HELI and curUnit.isYInAir then
						curUnit.unitYMov = curUnit.unitYMov + 0.1
					else
						DE_LowerPower(curUnit)
					end
				end
			end

			if mv[MOVE_CYUP] then DE_CycleWeaponUp(curUnit) end
			if mv[MOVE_CYDN] then DE_CycleWeaponDown(curUnit) end

			if mv[MOVE_CHANGE] then
				p.unitSelected = p.unitSelected + 1
				if p.unitSelected >= config.max_installations then
					p.unitSelected = 0
				end
			end

			if p.shotDelay > 0 then
				p.shotDelay = p.shotDelay - 1
			end
			if mv[MOVE_FIRE] and p.shotDelay == 0 then
				p.shotDelay = shotDelay[curUnit.shotType] or 0

				local d = shotDirt[curUnit.shotType]
				if d == EXPL_MAGNET then
					DE_RunMagnet(player_index, curUnit)
				elseif d == EXPL_DIRT or d == EXPL_NORMAL then
					DE_MakeShot(player_index, curUnit, direction)
				end
			end
		end
	end
end

local function DE_RunTickCheckEndgame()
	if destruct_player[PLAYER_LEFT].unitsRemaining == 0 then
		local p = destruct_player[PLAYER_RIGHT]
		p.score = p.score + ModeScore[PLAYER_LEFT][world.destructMode]
		soundQueue[7] = V_CLEARED_PLATFORM
		return true
	end
	if destruct_player[PLAYER_RIGHT].unitsRemaining == 0 then
		local p = destruct_player[PLAYER_LEFT]
		p.score = p.score + ModeScore[PLAYER_RIGHT][world.destructMode]
		soundQueue[7] = V_CLEARED_PLATFORM
		return true
	end
	return false
end

local function DE_RunTickPlaySounds()
	for i = 0, 7 do
		if soundQueue[i] ~= S_NONE then
			multiSamplePlay(soundQueue[i], i, (i == 7) and fxPlayVol or idiv(fxPlayVol, 2))
			soundQueue[i] = S_NONE
		end
	end
end

local function DE_RunTick()
	setFrameCount(1)

	fillArray(soundQueue, 8, 0)
	JE_tempScreenChecking()

	DE_ResetActions()
	DE_RunTickCycleDeadUnits()

	DE_RunTickGravity()
	DE_RunTickAnimate()
	DE_RunTickDrawWalls()
	DE_RunTickExplosions()
	DE_RunTickShots()
	DE_RunTickAI()
	DE_RunTickDrawCrosshairs()
	DE_RunTickDrawHUD()
	JE_showVGA()

	if destructFirstTime then
		fade_palette(colors, 25, 0, 255)
		destructFirstTime = false
		endDelay = 0
	end

	DE_RunTickGetInput()
	DE_ProcessInput()

	if endDelay > 0 then
		endDelay = endDelay - 1
		if endDelay == 0 then
			return STATE_RELOAD
		end
	elseif DE_RunTickCheckEndgame() then
		endDelay = 80
	end

	DE_RunTickPlaySounds()

	delayUntilElapsed()

	keyboardClearInput()

	if keysactive[SDL_SCANCODE_F10] then
		destruct_player[PLAYER_LEFT].is_cpu = not destruct_player[PLAYER_LEFT].is_cpu
		keysactive[SDL_SCANCODE_F10] = false
	end
	if keysactive[SDL_SCANCODE_F11] then
		destruct_player[PLAYER_RIGHT].is_cpu = not destruct_player[PLAYER_RIGHT].is_cpu
		keysactive[SDL_SCANCODE_F11] = false
	end
	if keysactive[SDL_SCANCODE_P] then
		JE_pauseScreen()
		keysactive[SDL_SCANCODE_P] = false
	end

	if keysactive[SDL_SCANCODE_F1] then
		JE_helpScreen()
		keysactive[SDL_SCANCODE_F1] = false
	end

	if keysactive[SDL_SCANCODE_ESCAPE] then
		keysactive[SDL_SCANCODE_ESCAPE] = false
		return STATE_INIT
	end

	if keysactive[SDL_SCANCODE_BACKSPACE] then
		keysactive[SDL_SCANCODE_BACKSPACE] = false
		return STATE_RELOAD
	end

	return STATE_CONTINUE
end

local function JE_destructMain()
	JE_loadPic(VGAScreen, 11, false)
	JE_introScreen()

	DE_ResetPlayers()

	destruct_player[PLAYER_LEFT].is_cpu = config.ai[PLAYER_LEFT]
	destruct_player[PLAYER_RIGHT].is_cpu = config.ai[PLAYER_RIGHT]

	while true do
		world.destructMode = JE_modeSelect()

		if world.destructMode == MODE_NONE then
			break
		end

		local curState
		repeat
			destructFirstTime = true
			JE_loadPic(VGAScreen, 11, false)

			DE_ResetUnits()
			DE_ResetLevel()
			repeat
				curState = DE_RunTick()
			until curState ~= STATE_CONTINUE

			fade_black(25)
		until curState ~= STATE_RELOAD
	end
end

function JE_destructGame()
	JE_clr256(VGAScreen)
	JE_showVGA()

	PIC = ns.files["pic11.raw"]
	PICTEX = ns.gfxmeta.pics[11]

	for i = 0, config.max_shots - 1 do
		shotRec[i] = { isAvailable = true, x = 0, y = 0, xmov = 0, ymov = 0, gravity = false, shottype = 0,
			trailx = newArray(4, 0), traily = newArray(4, 0), trailc = newArray(4, 0) }
	end
	for i = 0, config.max_explosions - 1 do
		exploRec[i] = { isAvailable = true, x = 0, y = 0, explowidth = 0, explomax = 0, explofill = 0, exploType = 0 }
	end
	for i = 0, config.max_walls - 1 do
		world.mapWalls[i] = { wallExist = false, wallX = 0, wallY = 0 }
	end

	for i = 0, 9 do
		config.max_installations = MAX(config.max_installations, basetypes[i][0])
	end
	for p = 0, MAX_PLAYERS - 1 do
		local pl = destruct_player[p] or {}
		destruct_player[p] = pl
		pl.unit = {}
		pl.moves = newArray(8, false)
		for u = 0, config.max_installations - 1 do
			pl.unit[u] = { unitX = 0, unitY = 0, unitYMov = 0, isYInAir = false, unitType = 0, shotType = 0,
				angle = 0, power = 0, lastMove = 0, ani_frame = 0, health = 0 }
		end
	end

	JE_loadCompShapes(destructSpriteSheet, '~')

	fade_black(1)

	JE_destructMain()

	free_sprite2s(destructSpriteSheet)
	stop_song()
end
