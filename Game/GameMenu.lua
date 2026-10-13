--[[
 WowTyrian2k: a World of Warcraft port of OpenTyrian
 Copyright (C) The OpenTyrian Development Team
 Lua port Copyright (C) 2026 voetre
 Licensed under the GNU General Public License v2 or later (see COPYING).

 game_menu.c - the between-level item screen (shop, data cubes, navigation)

 Joystick configuration, two-player arcade and network menus are omitted.
]]
local _, ns = ...
setfenv(1, ns.G)

local strbyte, strsub, strfind, strmatch = string.byte, string.sub, string.find, string.match

local MENU_FULL_GAME       = 0
local MENU_UPGRADES        = 1
local MENU_OPTIONS         = 2
local MENU_PLAY_NEXT_LEVEL = 3
local MENU_UPGRADE_SUB     = 4
local MENU_KEYBOARD_CONFIG = 5
local MENU_LOAD_SAVE       = 6
local MENU_DATA_CUBES      = 7
local MENU_DATA_CUBE_SUB   = 8
local MENU_2_PLAYER_ARCADE = 9
local MENU_1_PLAYER_ARCADE = 10
local MENU_LIMITED_OPTIONS = 11
local MENU_JOYSTICK_CONFIG = 12
local MENU_SUPER_TYRIAN    = 13

local yLoc, yChg = 0, 0
local newPal, curPal, oldPal = 0, 0, 0
local quikSave = false
local oldMenu = 0
local backFromHelp = false
local lastDirection = 1
local firstMenu9, paletteChanged = false, false
local menuChoices = newArray(MENU_MAX, 0)
local col, colC = 0, 0
local lastCurSel = 0
local curMenu = 0
local curSel = newArray(MENU_MAX, 2)
local leftPower, rightPower, rightPowerAfford = false, false, false
local currentCube = 0

local planetAni, planetAniWait = 0, 0
local currentDotNum, currentDotWait = 0, 0
local navX, navY, newNavX, newNavY = 0, 0, 0, 0
local tempNavX, tempNavY = 0, 0
local planetDots = newArray(5, 0)
local planetDotX = newArray(5, function() return newArray(10, 0) end)
local planetDotY = newArray(5, function() return newArray(10, 0) end)
local old_items = { [0] = ns.newPlayerItems(), ns.newPlayerItems() }
local temp_weapon_power = newArray(64, 1)

local cube = newArray(4, function()
	return { title = "", header = "", face_sprite = -1, text = newArray(90, ""), last_line = 0 }
end)

local menuChoicesDefault = { [0] = 7, 9, 8, 0, 0, 11, (SAVE_FILES_NUM / 2) + 2, 0, 0, 6, 4, 6, 7, 5 }
local menuEsc = { [0] = 0, 1, 1, 1, 2, 3, 3, 1, 8, 0, 0, 11, 3, 0 }
local itemAvailMap = { [0] = 1, 2, 3, 9, 4, 6, 7 }
local planetX = { [0] = 200, 150, 240, 300, 270, 280, 320, 260, 220, 150, 160, 210, 80, 240, 220, 180, 310, 330, 150, 240, 200 }
local planetY = { [0] = 40, 90, 90, 80, 170, 30, 50, 130, 120, 150, 220, 200, 80, 50, 160, 10, 55, 55, 90, 90, 40 }
local cube_line_chars = 35
local cube_line_width = 150

-- playeritem_map: index -> field accessors
local function itemGet(items, i)
	if i == 0 then return items.ship
	elseif i == 1 then return items.weapon[FRONT_WEAPON].id
	elseif i == 2 then return items.weapon[REAR_WEAPON].id
	elseif i == 3 then return items.shield
	elseif i == 4 then return items.generator
	elseif i == 5 then return items.sidekick[LEFT_SIDEKICK]
	elseif i == 6 then return items.sidekick[RIGHT_SIDEKICK]
	end
	return 0
end

local function itemSet(items, i, v)
	if i == 0 then items.ship = v
	elseif i == 1 then items.weapon[FRONT_WEAPON].id = v
	elseif i == 2 then items.weapon[REAR_WEAPON].id = v
	elseif i == 3 then items.shield = v
	elseif i == 4 then items.generator = v
	elseif i == 5 then items.sidekick[LEFT_SIDEKICK] = v
	elseif i == 6 then items.sidekick[RIGHT_SIDEKICK] = v
	end
end

-- itemAvail row for the current upgrade category
local function availRow(sel)
	return itemAvail[itemAvailMap[sel - 2] - 1]
end
local function availMax(sel)
	return itemAvailMax[itemAvailMap[sel - 2] - 1]
end

function JE_cashLeft()
	local tempL = player[0].cash
	local itemNum = itemGet(player[0].items, curSel[MENU_UPGRADES] - 2)

	tempL = tempL - JE_getCost(curSel[MENU_UPGRADES], itemNum)

	tempW = 0

	local s = curSel[MENU_UPGRADES]
	if s == 3 or s == 4 then
		for i = 1, player[0].items.weapon[s - 3].power - 1 do
			tempW = tempW + weaponPort[itemNum].cost * i
			tempL = tempL - tempW
		end
	end

	return tempL
end

local function drawItem(itemType, itemNum, x_, y_)
	local tw = 0

	if itemNum > 0 then
		if itemType == 2 or itemType == 3 then
			tw = weaponPort[itemNum].itemgraphic
		elseif itemType == 5 then
			tw = powerSys[itemNum].itemgraphic
		elseif itemType == 6 or itemType == 7 then
			tw = options[itemNum].itemgraphic
		elseif itemType == 4 then
			tw = shields[itemNum].itemgraphic
		end

		if itemType == 1 then
			blit_sprite2x2(VGAScreen, x_, y_, spriteSheet9, ships[itemNum] and ships[itemNum].shipgraphic or 0)
		elseif tw > 0 then
			blit_sprite2x2(VGAScreen, x_, y_, shopSpriteSheet, tw)
		end
	end
end
JE_drawItem = drawItem

function load_cube(cube_slot, cube_index)
	local file = dataFileOpen(cubeFilename)
	local buf = ""
	local c = cube[cube_slot]

	while cube_index > 0 do
		buf = readEncryptedString(file, 256)
		if strsub(buf, 1, 1) == '*' or file.error then
			cube_index = cube_index - 1
		end
	end

	local ok, val = str_pop_int(strsub(buf, 5))
	c.face_sprite = (ok and val or 0) - 1

	c.title = readEncryptedString(file, 81)
	c.header = readEncryptedString(file, 13)

	for i = 0, 89 do c.text[i] = "" end
	c.last_line = 0

	local line, line_chars, line_width = 0, 0, 0

	while true do
		buf = readEncryptedString(file, 256)

		if strsub(buf, 1, 1) == '*' or file.error then
			break
		end

		if #buf == 0 then
			if line_chars == 0 then
				line = line + 4
			else
				line = line + 1
			end
			line_chars = 0
			line_width = 0
		else
			for word in (buf .. " "):gmatch("([^ ]*) ") do
				local word_chars = #word
				local word_width = JE_textWidth(word, TINY_FONT)

				if word_chars > cube_line_chars or word_width > cube_line_width then
					break
				end

				local prepend_space = true

				line_chars = line_chars + word_chars + 1
				line_width = line_width + word_width + 6

				if line_chars > cube_line_chars or line_width > cube_line_width then
					line = line + 1
					line_chars = word_chars
					line_width = word_width
					prepend_space = false
				end

				if line < 90 then
					if prepend_space then
						c.text[line] = c.text[line] .. " "
					end
					c.text[line] = c.text[line] .. word
					c.last_line = line + 1
				end
			end
		end
	end

	return true
end

function load_cubes()
	for cube_slot = 0, cubeMax - 1 do
		load_cube(cube_slot, cubeList[cube_slot])
	end
end

local function drawMenuHeader()
	local s
	if curMenu == MENU_DATA_CUBE_SUB then
		s = cube[curSel[MENU_DATA_CUBES] - 2].header
	elseif curMenu == MENU_DATA_CUBES then
		s = menuInt[1][1]
	elseif curMenu == MENU_LOAD_SAVE then
		s = menuInt[3][b2n(performSave) + 1]
	else
		s = menuInt[curMenu + 1][0]
	end
	tempStr = s
	JE_dString(VGAScreen, 74 + JE_fontCenter(s, FONT_SHAPES), 10, s, FONT_SHAPES)
end
JE_drawMenuHeader = drawMenuHeader

local function drawMenuChoices()
	for x_ = 2, menuChoices[curMenu] do
		local tempY = 38 + (x_ - 1) * 16

		if curMenu == MENU_FULL_GAME and x_ == 7 then
			tempY = tempY + 16
		end

		if not (curMenu == MENU_PLAY_NEXT_LEVEL and x_ == menuChoices[curMenu]) then
			tempY = tempY - 16
		end

		local s = menuInt[curMenu + 1][x_ - 1] or ""
		if curSel[curMenu] == x_ then
			s = "~" .. s
		end
		JE_dString(VGAScreen, 166, tempY, s, SMALL_FONT_SHAPES)
	end
end
JE_drawMenuChoices = drawMenuChoices

local function drawNavLines(dark)
	local tempX2 = rshift(tempNavX % 65536, 1)
	if tempNavX < 0 then tempX2 = arshift(tempNavX, 1) end
	local tempY2 = (tempNavY < 0) and arshift(tempNavY, 1) or rshift(tempNavY, 1)

	local tw = 0
	for xx = 1, 20 do
		tw = tw + 15
		local tempX = tw - tempX2
		if tempX > 18 and tempX < 135 then
			if dark then
				JE_rectangle(VGAScreen, tempX + 1, 16, tempX + 1, 169, 1)
			else
				JE_rectangle(VGAScreen, tempX, 16, tempX, 169, 5)
			end
		end
	end

	tw = 0
	for yy = 1, 20 do
		tw = tw + 15
		local tempY = tw - tempY2
		if tempY > 15 and tempY < 169 then
			if dark then
				JE_rectangle(VGAScreen, 19, tempY + 1, 135, tempY + 1, 1)
			else
				JE_rectangle(VGAScreen, 8, tempY, 160, tempY, 5)
			end

			local tw2 = 0
			for xx = 0, 19 do
				tw2 = tw2 + 15
				local tempX = tw2 - tempX2
				if tempX > 18 and tempX < 135 then
					JE_pix3(VGAScreen, tempX, tempY, 7)
				end
			end
		end
	end
end

local function drawDots()
	for xx = 0, mapPNum - 1 do
		for yy = 0, planetDots[xx] - 1 do
			local tempX = planetDotX[xx][yy] - tempNavX + 66 - 2
			local tempY = planetDotY[xx][yy] - tempNavY + 85 - 2
			if tempX > 0 and tempX < 140 and tempY > 0 and tempY < 168 then
				blit_sprite(VGAScreenSeg, tempX, tempY, OPTION_SHAPES,
					(xx == curSel[MENU_PLAY_NEXT_LEVEL] - 2 and yy < currentDotNum) and 30 or 29)
			end
		end
	end
end

local function drawPlanet(planetNum)
	local tempZ = PGR[planetNum] - 1
	local spr = sprite(PLANET_SHAPES, tempZ)
	local tempX = planetX[planetNum] + 66 - tempNavX - idiv(spr.width, 2)
	local tempY = planetY[planetNum] + 85 - tempNavY - idiv(spr.height, 2)

	if tempX > -7 and tempX + spr.width < 170 and tempY > 0 and tempY < 160 then
		if PAni[planetNum] ~= 0 then
			tempZ = tempZ + planetAni
		end

		blit_sprite_dark(VGAScreenSeg, tempX + 3, tempY + 3, PLANET_SHAPES, tempZ, false)
		blit_sprite(VGAScreenSeg, tempX, tempY, PLANET_SHAPES, tempZ)
	end
end

local function updateNavScreen()
	tempNavX = roundf(navX)
	tempNavY = roundf(navY)
	fill_rectangle_xy(VGAScreen, 19, 16, 135, 169, 2)
	drawNavLines(true)
	drawNavLines(false)
	drawDots()

	for xx = 0, 10 do
		drawPlanet(xx)
	end

	for xx = 0, menuChoices[MENU_PLAY_NEXT_LEVEL] - 2 do
		if mapPlanet[xx] > 11 then
			drawPlanet(mapPlanet[xx] - 1)
		end
	end

	if mapOrigin > 11 then
		drawPlanet(mapOrigin - 1)
	end

	blit_sprite(VGAScreenSeg, 0, 0, OPTION_SHAPES, 28)

	if curSel[MENU_PLAY_NEXT_LEVEL] < menuChoices[MENU_PLAY_NEXT_LEVEL] then
		local dest = mapPlanet[curSel[MENU_PLAY_NEXT_LEVEL] - 2]
		local os_ = sprite(PLANET_SHAPES, PGR[mapOrigin - 1] - 1)
		local ds = sprite(PLANET_SHAPES, PGR[dest - 1] - 1)

		newNavX = (planetX[mapOrigin - 1] - idiv(os_.width, 2) + planetX[dest - 1] - idiv(ds.width, 2)) / 2.0
		newNavY = (planetY[mapOrigin - 1] - idiv(os_.height, 2) + planetY[dest - 1] - idiv(ds.height, 2)) / 2.0
	end

	navX = navX + (newNavX - navX) / 2.0
	navY = navY + (newNavY - navY) / 2.0

	if abs(newNavX - navX) < 1 then navX = newNavX end
	if abs(newNavY - navY) < 1 then navY = newNavY end

	fill_rectangle_xy(VGAScreen, 314, 0, 319, 199, 230)

	if planetAniWait > 0 then
		planetAniWait = planetAniWait - 1
	else
		planetAni = planetAni + 1
		if planetAni > 14 then planetAni = 0 end
		planetAniWait = 3
	end

	if currentDotWait > 0 then
		currentDotWait = currentDotWait - 1
	else
		if currentDotNum < planetDots[curSel[MENU_PLAY_NEXT_LEVEL] - 2] then
			currentDotNum = currentDotNum + 1
		end
		currentDotWait = 5
	end
end
JE_updateNavScreen = updateNavScreen

local function partWay(start, finish, dots, dist)
	return idiv(finish - start, dots + 2) * (dist + 1) + start
end

local function computeDots()
	for xx = 0, mapPNum - 1 do
		local distX = planetX[mapPlanet[xx] - 1] - planetX[mapOrigin - 1]
		local distY = planetY[mapPlanet[xx] - 1] - planetY[mapOrigin - 1]
		local tempX = abs(distX) + abs(distY)

		if tempX ~= 0 then
			planetDots[xx] = u8(roundf(math.sqrt(math.sqrt(distX * distX + distY * distY))) - 1)
		else
			planetDots[xx] = 0
		end

		if planetDots[xx] > 10 then planetDots[xx] = 10 end

		for yy = 0, planetDots[xx] - 1 do
			planetDotX[xx][yy] = partWay(planetX[mapOrigin - 1], planetX[mapPlanet[xx] - 1], planetDots[xx], yy)
			planetDotY[xx][yy] = partWay(planetY[mapOrigin - 1], planetY[mapPlanet[xx] - 1], planetDots[xx], yy)
		end
	end
end

function draw_ship_illustration()
	-- ship
	do
		local sprite_id = (player[0].items.ship <= SHIP_NUM) and ships[player[0].items.ship].bigshipgraphic - 1 or 31
		local ship_x = { [0] = 31, 0, 0, 0, 35, 31 }
		local ship_y = { [0] = 36, 0, 0, 0, 33, 35 }
		local xx, yy = ship_x[sprite_id - 27] or 31, ship_y[sprite_id - 27] or 36
		blit_sprite(VGAScreenSeg, xx, yy, OPTION_SHAPES, sprite_id)
	end

	-- generator
	do
		local g = player[0].items.generator
		local sprite_id = (g == 1) and g + 15 or g + 14
		local generator_x = { [0] = 62, 64, 67, 66, 63 }
		local generator_y = { [0] = 84, 85, 86, 84, 97 }
		local xx, yy = generator_x[sprite_id - 16], generator_y[sprite_id - 16]
		if xx then
			blit_sprite(VGAScreenSeg, xx, yy, WEAPON_SHAPES, sprite_id)
		end
	end

	local weapon_sprites = { [0] =
		-1,  0,  1,  2,  3,  4,  5,  6,  7,  8,
		 9, 10, 11, 21,  5, 13, -1, 14, 15,  0,
		14,  9,  8,  2, 15,  0, 13,  0,  8,  8,
		11,  1,  0,  0,  0,  0,  0,  0,  0,  0,
		 0,  2,  1 }

	local fid = player[0].items.weapon[FRONT_WEAPON].id
	if fid > 0 then
		local front_weapon_xy_list = { [0] =
			 -1,  4,  9,  3,  8,  2,  5, 10,  1, -1,
			 -1, -1, -1,  7,  8, -1, -1,  0, -1,  4,
			  0, -1, -1,  3, -1,  4, -1,  4, -1, -1,
			 -1,  9,  0,  0,  0,  0,  0,  0,  0,  0,
			  0,  3,  9 }
		local front_weapon_x = { [0] = 59, 66, 66, 54, 61, 51, 58, 51, 61, 52, 53, 58 }
		local front_weapon_y = { [0] = 38, 53, 41, 36, 48, 35, 41, 35, 53, 41, 39, 31 }
		local idx = front_weapon_xy_list[fid]
		if idx and idx >= 0 then
			blit_sprite(VGAScreenSeg, front_weapon_x[idx], front_weapon_y[idx], WEAPON_SHAPES, weapon_sprites[fid])
		end
	end

	local rid = player[0].items.weapon[REAR_WEAPON].id
	if rid > 0 then
		local rear_weapon_xy_list = { [0] =
			-1, -1, -1, -1, -1, -1, -1, -1, -1,  0,
			 1,  2,  3, -1,  4,  5, -1, -1,  6, -1,
			-1,  1,  0, -1,  6, -1,  5, -1,  0,  0,
			 3,  0,  0,  0,  0,  0,  0,  0,  0,  0,
			 0, -1, -1 }
		local rear_weapon_x = { [0] = 41, 27, 49, 43, 51, 39, 41 }
		local rear_weapon_y = { [0] = 92, 92, 113, 102, 97, 96, 76 }
		local idx = rear_weapon_xy_list[rid]
		if idx and idx >= 0 then
			blit_sprite(VGAScreenSeg, rear_weapon_x[idx], rear_weapon_y[idx], WEAPON_SHAPES, weapon_sprites[rid])
		end
	end

	drawItem(6, player[0].items.sidekick[LEFT_SIDEKICK], 3, 84)
	drawItem(7, player[0].items.sidekick[RIGHT_SIDEKICK], 129, 84)

	blit_sprite_hv(VGAScreenSeg, 28, 23, OPTION_SHAPES, 26, 15, shields[player[0].items.shield].mpwr - 10)
end

local function initWeaponView()
	fill_rectangle_xy(VGAScreen, 8, 8, 144, 177, 0)

	player[0].sidekick[LEFT_SIDEKICK].x = 72 - 15
	player[0].sidekick[LEFT_SIDEKICK].y = 120
	player[0].sidekick[RIGHT_SIDEKICK].x = 72 + 15
	player[0].sidekick[RIGHT_SIDEKICK].y = 120

	player[0].x = 72
	player[0].y = 110
	player[0].delta_x_shot_move = 0
	player[0].delta_y_shot_move = 0
	player[0].last_x_explosion_follow = 72
	player[0].last_y_explosion_follow = 110
	power = 500
	lastPower = 500

	fillArray(shotAvail, MAX_PWEAPON, 0)
	fillArray(shotRepeat, 11, 1)
	fillArray(shotMultiPos, 11, 0)

	initialize_starfield()
end

-- The weapon preview is drawn into its own surfaces every frame and added to
-- the menu screen as a single group, so the menu's draw list stays the same
-- from frame to frame (no coverage scans, and stable texture slots).
local previewSurface = ns.newSurface("weaponPreview", false)
local previewStars = ns.newSurface("weaponPreviewStars", false)

-- Power bar columns: x, width, colour offset.
local powerBarCols = { { 141, 2, -3 }, { 143, 1, -2 }, { 144, 1, -1 }, { 145, 5, 0 } }
local runStart, runColor = {}, {}

local function weaponViewFrame()
	fill_rectangle_xy(VGAScreen, 8, 8, 143, 182, 0)

	-- The original only puts stars on black pixels, i.e. inside the preview.
	surfaceClear(previewStars)
	pushGroup(VGAScreen, previewStars, 8, 8, 136, 175)
	update_and_draw_starfield(previewStars, 1)

	player[0].mouseX = player[0].x
	player[0].mouseY = player[0].y

	for i = 0, 1 do
		if shotRepeat[i] > 0 then
			shotRepeat[i] = shotRepeat[i] - 1
		else
			local item = player[0].items.weapon[i].id
			local item_power = player[0].items.weapon[i].power - 1
			local item_mode = (i == REAR_WEAPON) and player[0].weapon_mode - 1 or 0
			local op = weaponPort[item].op[item_mode]
			b = player_shot_create(item, i, player[0].x, player[0].y, player[0].mouseX, player[0].mouseY, op and op[item_power] or 0, 1)
		end
	end

	local lsk = player[0].items.sidekick[LEFT_SIDEKICK]
	if options[lsk].wport > 0 then
		if shotRepeat[SHOT_LEFT_SIDEKICK] > 0 then
			shotRepeat[SHOT_LEFT_SIDEKICK] = shotRepeat[SHOT_LEFT_SIDEKICK] - 1
		else
			b = player_shot_create(options[lsk].wport, SHOT_LEFT_SIDEKICK, player[0].sidekick[LEFT_SIDEKICK].x, player[0].sidekick[LEFT_SIDEKICK].y, player[0].mouseX, player[0].mouseY, options[lsk].wpnum, 1)
		end
	end

	local rsk = player[0].items.sidekick[RIGHT_SIDEKICK]
	if options[rsk].tr == 2 then
		player[0].sidekick[RIGHT_SIDEKICK].x = player[0].x
		player[0].sidekick[RIGHT_SIDEKICK].y = MAX(10, player[0].y - 20)
	else
		player[0].sidekick[RIGHT_SIDEKICK].x = 72 + 15
		player[0].sidekick[RIGHT_SIDEKICK].y = 120
	end

	if options[rsk].wport > 0 then
		if shotRepeat[SHOT_RIGHT_SIDEKICK] > 0 then
			shotRepeat[SHOT_RIGHT_SIDEKICK] = shotRepeat[SHOT_RIGHT_SIDEKICK] - 1
		else
			b = player_shot_create(options[rsk].wport, SHOT_RIGHT_SIDEKICK, player[0].sidekick[RIGHT_SIDEKICK].x, player[0].sidekick[RIGHT_SIDEKICK].y, player[0].mouseX, player[0].mouseY, options[rsk].wpnum, 1)
		end
	end

	simulate_player_shots()

	-- the interface sprite repaints the power bar area every frame
	blit_sprite(VGAScreenSeg, 0, 0, OPTION_SHAPES, 12)

	-- Power Bar.  The original plots it pixel by pixel; here each column is
	-- drawn as one rectangle per run of rows with the same colour.
	power = power + powerAdd
	if power > 900 then power = 900 end

	local top = 147 - idiv(power, 10)
	for c = 1, 4 do runStart[c] = nil end
	for t = top, 147 do
		local t2
		if t <= 146 then
			t2 = 113 + idiv(146 - t, 9) + 2
			local t3 = (t + 1) % 6
			if t3 == 1 then
				t2 = t2 + 3
			elseif t3 ~= 0 then
				t2 = t2 + 2
			end
		end
		for c = 1, 4 do
			local col = powerBarCols[c]
			local color = t2 and t2 + col[3]
			if runStart[c] and runColor[c] ~= color then
				fill_rectangle_wh(VGAScreen, col[1], runStart[c], col[2], t - runStart[c], runColor[c])
				runStart[c] = nil
			end
			if color and not runStart[c] then
				runStart[c], runColor[c] = t, color
			end
		end
	end

	local t = top
	local t2 = 113 + idiv(146 - t, 9) + 4

	fill_rectangle_xy(VGAScreen, 141, t - 1, 144, t - 1, t2 - 1)
	fill_rectangle_xy(VGAScreen, 145, t - 1, 149, t - 1, t2)

	lastPower = t
end

local drawWeaponSim

local function weaponSimUpdate()
	local screen = VGAScreen
	surfaceClear(previewSurface)
	pushGroup(screen, previewSurface)
	VGAScreen, VGAScreenSeg = previewSurface, previewSurface
	drawWeaponSim()
	VGAScreen, VGAScreenSeg = screen, screen
end

drawWeaponSim = function()
	weaponViewFrame()

	local s = curSel[MENU_UPGRADES]
	if (s == 3 or s == 4) and curSel[MENU_UPGRADE_SUB] < menuChoices[MENU_UPGRADE_SUB] and
	   availRow(s)[curSel[MENU_UPGRADE_SUB] - 2] ~= 0 then
		if leftPower then
			JE_outText(VGAScreen, 26, 137, sprintf("%d", downgradeCost), 1, 4)
		else
			blit_sprite(VGAScreenSeg, 24, 149, OPTION_SHAPES, 13)
		end

		if rightPower then
			if not rightPowerAfford then
				JE_outText(VGAScreen, 108, 137, sprintf("%d", upgradeCost), 7, 4)
				blit_sprite(VGAScreenSeg, 119, 149, OPTION_SHAPES, 14)
			else
				JE_outText(VGAScreen, 108, 137, sprintf("%d", upgradeCost), 1, 4)
			end
		else
			blit_sprite(VGAScreenSeg, 119, 149, OPTION_SHAPES, 14)
		end

		local pw = player[0].items.weapon[s - 3].power

		for xx = 1, pw do
			fill_rectangle_xy(VGAScreen, 39 + xx * 6, 151, 39 + xx * 6 + 4, 151, 251)
			JE_pix(VGAScreen, 39 + xx * 6, 151, 252)
			fill_rectangle_xy(VGAScreen, 39 + xx * 6, 152, 39 + xx * 6 + 4, 164, 250)
			fill_rectangle_xy(VGAScreen, 39 + xx * 6, 165, 39 + xx * 6 + 4, 165, 249)
		end

		JE_outText(VGAScreen, 58, 137, sprintf("POWER: %d", pw), 15, 4)
	else
		leftPower = false
		rightPower = false
		blit_sprite(VGAScreenSeg, 20, 146, OPTION_SHAPES, 17)
	end

	drawItem(1, player[0].items.ship, player[0].x - 5, player[0].y - 7)
end

local function drawMainMenuHelpText()
	local t = curSel[curMenu] - 2
	local s
	if curMenu < MENU_PLAY_NEXT_LEVEL or curMenu == MENU_2_PLAYER_ARCADE or curMenu > MENU_1_PLAYER_ARCADE then
		s = mainMenuHelp[menuHelp[curMenu][t] - 1]
	elseif curMenu == MENU_KEYBOARD_CONFIG and curSel[MENU_KEYBOARD_CONFIG] == 10 then
		s = mainMenuHelp[25 - 1]
	elseif leftPower or rightPower then
		s = mainMenuHelp[24 - 1]
	elseif t == menuChoices[curMenu] - 2 or (curMenu == MENU_DATA_CUBES and cubeMax == 0) then
		s = mainMenuHelp[12 - 1]
	else
		s = mainMenuHelp[17 + curMenu - 3]
	end

	JE_textShade(VGAScreen, 10, 187, s or "", 14, 1, DARKEN)
end
JE_drawMainMenuHelpText = drawMainMenuHelpText

function JE_quitRequest()
	local quit_selected, done = true, false

	JE_barShade(VGAScreen, 65, 55, 255, 155)
	local baseN = VGAScreen.n

	while not done do
		local c = 8
		local cC = 1

		while true do
			VGAScreen.n = baseN
			setFrameCount(4)

			blit_sprite(VGAScreen, 50, 50, OPTION_SHAPES, 35)
			JE_textShade(VGAScreen, 70, 66, miscText[28], 0, 5, FULL_SHADE)
			JE_helpBox(VGAScreen, 70, 90, miscText[30], 30, 7, 12, 1, FULL_SHADE)

			c = c + cC
			if c > 8 or c < 2 then
				cC = -cC
			end

			local temp_x = 54 + 45 - idiv(JE_textWidth(miscText[9], FONT_SHAPES), 2)
			JE_outTextAdjust(VGAScreen, temp_x, 128, miscText[9], 15, quit_selected and c - 12 or -5, FONT_SHAPES, true)

			temp_x = 149 + 45 - idiv(JE_textWidth(miscText[10], FONT_SHAPES), 2)
			JE_outTextAdjust(VGAScreen, temp_x, 128, miscText[10], 15, (not quit_selected) and c - 12 or -5, FONT_SHAPES, true)

			JE_mouseStart()
			JE_showVGA()
			JE_mouseReplace()

			waitUntilElapsed()

			if hasInput(INPUT_NO_MOTION) then break end
			mouseGetInput(INPUT_ANY)
		end

		local mouseInput = mouseGetInput(INPUT_NO_MOTION)
		if mouseInput then
			if mouseInput.y > 123 and mouseInput.y < 149 then
				if mouseInput.x > 56 and mouseInput.x < 142 then
					quit_selected = true
					done = true
				elseif mouseInput.x > 151 and mouseInput.x < 237 then
					quit_selected = false
					done = true
				end
			end
		else
			local k = keyboardGetInput()
			if k then
				local sc = k.scancode
				if sc == SDL_SCANCODE_LEFT or sc == SDL_SCANCODE_RIGHT or sc == SDL_SCANCODE_TAB then
					quit_selected = not quit_selected
					JE_playSampleNum(S_CURSOR)
				elseif sc == SDL_SCANCODE_RETURN or sc == SDL_SCANCODE_SPACE then
					done = true
				elseif sc == SDL_SCANCODE_ESCAPE then
					quit_selected = false
					done = true
				end
			end
		end
	end

	JE_playSampleNum(quit_selected and S_SPRING or S_CLICK)

	return quit_selected
end

-- Cheats: extra stock for the upgrade shop -----------------------------------

-- itemAvail rows: 0 ships, 1 front weapons, 2 rear weapons, 3 generators,
-- 5 left sidekicks, 6 right sidekicks, 8 shields (4 and 7 are unused).
local shopRows = { 0, 1, 2, 3, 5, 6, 8 }
local shopStock, secretStock

-- Every item sold by any shop ("]I" sections) in the episode files.
local function scanShopStock()
	local stock = {}
	for _, k in ipairs(shopRows) do stock[k] = {} end
	for ep = 1, 4 do
		local f = dataFileOpen(sprintf("levels%d.dat", ep))
		while not f.error and f.pos < f.len - 1 do
			local ok, line = pcall(readEncryptedString, f, 256)
			if not ok then break end
			if strsub(line, 1, 2) == "]I" then
				for k = 0, 8 do
					local l = readEncryptedString(f, 256)
					local buf = (#l > 8) and strsub(l, 9) or ""
					while stock[k] do
						local more, val, rest = str_pop_int(buf)
						if not more then break end
						buf = rest
						stock[k][val] = true
					end
				end
			end
		end
	end
	return stock
end

-- Named items that no shop sells: the secret ships, weapons and so on.
local function findSecretStock(stock)
	local secret = {}
	for _, k in ipairs(shopRows) do secret[k] = {} end
	local function add(k, id) if not stock[k][id] then secret[k][id] = true end end
	local function named(item)
		return item and item.name and strmatch(item.name, "%S") and item.cost > 0
	end
	for id = 1, #ships do
		if named(ships[id]) then add(0, id) end
	end
	for id = 1, #weaponPort do
		local w = weaponPort[id]
		if named(w) and not stock[1][id] and not stock[2][id] then
			-- weapons with two firing modes, or "Rear" in the name, go in the back
			if w.opnum > 1 or strfind(w.name, "Rear") then add(2, id) else add(1, id) end
		end
	end
	for id = 1, #powerSys do
		if named(powerSys[id]) then add(3, id) end
	end
	for id = 1, #options do
		local o = options[id]
		if named(o) and not stock[5][id] and not stock[6][id] then
			-- tr 2 sidekicks sit in front of the ship and only fit on the right
			if o.tr ~= 2 then add(5, id) end
			add(6, id)
		end
	end
	for id = 1, #shields do
		if named(shields[id]) then add(8, id) end
	end
	return secret
end

local function addStock(set, k)
	local row = itemAvail[k]
	local have = {}
	for slot = 0, itemAvailMax[k] - 1 do have[row[slot]] = true end
	for id in pairs(set) do
		if not have[id] then
			row[itemAvailMax[k]] = id
			itemAvailMax[k] = itemAvailMax[k] + 1
			have[id] = true
		end
	end
end

function unlockShopItems()
	if not shopStock then
		shopStock = scanShopStock()
		secretStock = findSecretStock(shopStock)
	end
	for _, k in ipairs(shopRows) do
		if cheats.shopUnlock then addStock(shopStock[k], k) end
		if cheats.secretUnlock then addStock(secretStock[k], k) end
	end
end

-- The item list scrolls when it has more rows than fit (only with the shop
-- cheats; the original shops never sell that many items).
local SUB_ROWS = 5
local subScroll = 0

local function genItemMenu(itemNum)
	menuChoices[MENU_UPGRADE_SUB] = availMax(itemNum) + 2
	subScroll = 0

	temp3 = 2
	temp2 = itemGet(player[0].items, itemNum - 2)

	menuInt[5][0] = menuInt[2][itemNum - 1]

	local tw = 0
	while tw < availMax(itemNum) do
		temp = availRow(itemNum)[tw]
		local s = ""
		if itemNum == 2 then
			s = ships[temp] and ships[temp].name or ""
		elseif itemNum == 3 or itemNum == 4 then
			s = weaponPort[temp].name
		elseif itemNum == 5 then
			s = shields[temp].name
		elseif itemNum == 6 then
			s = powerSys[temp].name
		elseif itemNum == 7 or itemNum == 8 then
			s = options[temp].name
		end
		if temp == temp2 then
			temp3 = tw + 2
		end
		menuInt[5][tw] = s
		tw = tw + 1
	end

	menuInt[5][tw] = miscText[13]

	curSel[MENU_UPGRADE_SUB] = temp3
end

-- Ship specs: a green tech-screen rendition of the ship.
local function drawShipSpecs(screen)
	JE_clr256(screen)

	-- grid lines
	local function lines(dark)
		local tw = 0
		for xx = 0, 19 do
			tw = tw + 15
			local tempX = tw + 10
			if tempX > 18 and tempX < 135 then
				if dark then
					JE_rectangle(screen, tempX + 1, 0, tempX + 1, 199, 32 + 3)
				else
					JE_rectangle(screen, tempX, 0, tempX, 199, 32 + 5)
				end
			end
		end
		tw = 0
		for yy = 0, 19 do
			tw = tw + 15
			local tempY = tw
			if tempY > 15 and tempY < 169 then
				if dark then
					JE_rectangle(screen, 0, tempY + 1, 319, tempY + 1, 32 + 3)
				else
					JE_rectangle(screen, 0, tempY, 319, tempY, 32 + 5)
				end
			end
		end
	end
	lines(true)
	lines(false)
	JE_rectangle(screen, 0, 0, 319, 199, 37)
	JE_rectangle(screen, 1, 1, 318, 198, 35)

	local ship = player[0].items.ship
	JE_outText(screen, 10, 2, ships[ship].name, 12, 3)
	JE_helpBox(screen, 100, 20, shipInfo[ship - 1][0], 40, 9, 12, 1, FULL_SHADE)
	JE_helpBox(screen, 100, 100, shipInfo[ship - 1][1], 40, 9, 12, 1, FULL_SHADE)

	JE_outText(screen, JE_fontCenter(miscText[4], TINY_FONT), 190, miscText[4], 12, 2)

	local temp_index
	if ship > 0 then
		temp_index = ships[ship].bigshipgraphic
	else
		temp_index = ships[old_items[0].ship].bigshipgraphic
	end

	local temp_x, temp_y = 31, 36
	if temp_index == 32 then
		temp_x, temp_y = 35, 33
	elseif temp_index == 33 then
		temp_x, temp_y = 31, 35
	end
	temp_x = temp_x - 30

	-- The original "greenifies" the ship outline; tint it green instead.
	blit_sprite_hv(screen, temp_x, temp_y, OPTION_SHAPES, temp_index - 1, 0xc, 0)
end

local function doShipSpecs()
	drawShipSpecs(game_screen)
	JE_loadPic(VGAScreen2, 1, false)
	JE_playSampleNum(S_SPRING)
	surfaceCopy(VGAScreen, game_screen)
	JE_showVGA()
	waitUntilGetInput()
end
JE_doShipSpecs = doShipSpecs

local function drawScore()
	if curMenu == MENU_UPGRADE_SUB then
		JE_textShade(VGAScreen, 65, 173, sprintf("%d", JE_cashLeft()), 1, 6, DARKEN)
	end
end
JE_drawScore = drawScore

local function menuFunction(select)
	col = 0
	colC = -1
	JE_playSampleNum(S_CLICK)

	local curSelect = curSel[curMenu]

	if curMenu == MENU_FULL_GAME then
		if select == 2 then
			curMenu = MENU_DATA_CUBES
			curSel[MENU_DATA_CUBES] = 2
		elseif select == 3 then
			doShipSpecs()
		elseif select == 4 then
			curMenu = MENU_UPGRADES
		elseif select == 5 then
			curMenu = MENU_OPTIONS
		elseif select == 6 then
			curMenu = MENU_PLAY_NEXT_LEVEL
			newPal = 18
			computeDots()
			navX = planetX[mapOrigin - 1]
			navY = planetY[mapOrigin - 1]
			newNavX = navX
			newNavY = navY
			menuChoices[MENU_PLAY_NEXT_LEVEL] = mapPNum + 2
			curSel[MENU_PLAY_NEXT_LEVEL] = 2
			menuInt[4][0] = "Next Level"
			local xx = 0
			while xx < mapPNum do
				menuInt[4][xx + 1] = pName[mapPlanet[xx] - 1]
				xx = xx + 1
			end
			menuInt[4][xx + 1] = miscText[5]
		elseif select == 7 then
			if JE_quitRequest() then
				gameLoaded = true
				mainLevel = 0
			end
		end

	elseif curMenu == MENU_UPGRADES then
		if select == 9 then
			curMenu = MENU_FULL_GAME
		else
			structAssign(old_items[0], player[0].items)

			lastDirection = 1
			genItemMenu(select)
			initWeaponView()
			curMenu = MENU_UPGRADE_SUB
			lastCurSel = curSel[MENU_UPGRADE_SUB]
			player[0].cash = player[0].cash * 2 - JE_cashLeft()
		end

	elseif curMenu == MENU_OPTIONS then
		if select == 2 then
			curMenu = MENU_LOAD_SAVE
			performSave = false
			quikSave = false
		elseif select == 3 then
			curMenu = MENU_LOAD_SAVE
			performSave = true
			quikSave = false
		elseif select == 6 then
			-- joystick configuration is not available
			JE_playSampleNum(S_CLINK)
		elseif select == 7 then
			curMenu = MENU_KEYBOARD_CONFIG
		elseif select == 8 then
			curMenu = MENU_FULL_GAME
		end

	elseif curMenu == MENU_PLAY_NEXT_LEVEL then
		if select == menuChoices[MENU_PLAY_NEXT_LEVEL] then
			curMenu = MENU_FULL_GAME
			newPal = 1
		else
			mainLevel = mapSection[curSelect - 2]
			jumpSection = true
		end

	elseif curMenu == MENU_UPGRADE_SUB then
		if curSel[MENU_UPGRADE_SUB] < menuChoices[MENU_UPGRADE_SUB] then
			curSel[MENU_UPGRADE_SUB] = menuChoices[MENU_UPGRADE_SUB]
		else
			JE_playSampleNum(S_ITEM)
			player[0].cash = JE_cashLeft()
			curMenu = MENU_UPGRADES
		end

	elseif curMenu == MENU_KEYBOARD_CONFIG then
		if curSelect == 10 then
			copyArray(keySettings, defaultKeySettings, 8)
		elseif curSelect == 11 then
			curMenu = MENU_OPTIONS
		else
			local tempY = 38 + (curSelect - 2) * 12
			JE_textShade(VGAScreen, 236, tempY, SDL_GetScancodeName(keySettings[curSelect - 2]), idiv(254, 16), (254 % 16) - 8, DARKEN)
			JE_showVGA()

			col = 248
			colC = 1

			local baseN = VGAScreen.n
			while true do
				VGAScreen.n = baseN
				setFrameCount(1)

				col = col + colC
				if col < 243 or col > 248 then
					colC = -colC
				end
				JE_rectangle(VGAScreen, 230, tempY - 2, 300, tempY + 7, col)

				JE_showVGA()

				delayUntilElapsed()

				if hasInput(INPUT_NO_MOTION) then break end
				mouseGetInput(INPUT_ANY)
				ns.yieldFrame()
			end

			if mouseGetInput(INPUT_NO_MOTION) then
				-- cancel
			else
				local k = keyboardGetInput()
				if k and k.scancode > 0 then
					for i = 0, 7 do
						if keySettings[i] == k.scancode then
							keySettings[i] = keySettings[curSelect - 2]
							break
						end
					end

					if k.scancode ~= SDL_SCANCODE_ESCAPE and k.scancode ~= SDL_SCANCODE_F11 and k.scancode ~= SDL_SCANCODE_P then
						JE_playSampleNum(S_CLICK)
						keySettings[curSelect - 2] = k.scancode
						curSelect = curSelect + 1
					end
				end
			end
		end

	elseif curMenu == MENU_LOAD_SAVE then
		if curSelect == 13 then
			if quikSave then
				curMenu = oldMenu
				newPal = oldPal
			else
				curMenu = MENU_OPTIONS
			end
		else
			JE_operation(curSelect - 1)
			if quikSave then
				curMenu = oldMenu
				newPal = oldPal
			end
		end

	elseif curMenu == MENU_DATA_CUBES then
		if curSelect == menuChoices[curMenu] then
			curMenu = MENU_FULL_GAME
			newPal = 1
		else
			if cubeMax > 0 then
				firstMenu9 = true
				curMenu = MENU_DATA_CUBE_SUB
				yLoc = 0
				yChg = 0
				currentCube = curSel[MENU_DATA_CUBES] - 2
			else
				curMenu = MENU_FULL_GAME
				newPal = 1
			end
		end

	elseif curMenu == MENU_DATA_CUBE_SUB then
		curMenu = MENU_DATA_CUBES

	elseif curMenu == MENU_1_PLAYER_ARCADE then
		local s = curSel[curMenu]
		if s == 2 then
			mainLevel = mapSection[mapPNum - 1]
			jumpSection = true
		elseif s == 3 then
			curMenu = MENU_OPTIONS
		elseif s == 4 then
			if JE_quitRequest() then
				gameLoaded = true
				mainLevel = 0
			end
		end

	elseif curMenu == MENU_SUPER_TYRIAN then
		local s = curSel[curMenu]
		if s == 2 then
			mainLevel = mapSection[mapPNum - 1]
			jumpSection = true
		elseif s == 3 then
			doShipSpecs()
		elseif s == 4 then
			curMenu = MENU_OPTIONS
		elseif s == 5 then
			if JE_quitRequest() then
				gameLoaded = true
				mainLevel = 0
			end
		end
	end

	structAssign(old_items[0], player[0].items)
end
JE_menuFunction = menuFunction

-- Draws the whole menu screen for the current state (the part of the C
-- JE_itemScreen loop before the input handling).
local function drawMenuScreen()
	if curMenu == MENU_UPGRADE_SUB then
		-- Move cursor until we hit either "Done" or a weapon the player can afford
		local guard = 0
		while curSel[MENU_UPGRADE_SUB] < menuChoices[MENU_UPGRADE_SUB] and
		      JE_getCost(curSel[MENU_UPGRADES], availRow(curSel[MENU_UPGRADES])[curSel[MENU_UPGRADE_SUB] - 2]) > player[0].cash do
			curSel[MENU_UPGRADE_SUB] = curSel[MENU_UPGRADE_SUB] + lastDirection
			if curSel[MENU_UPGRADE_SUB] < 2 then
				curSel[MENU_UPGRADE_SUB] = menuChoices[MENU_UPGRADE_SUB]
			elseif curSel[MENU_UPGRADE_SUB] > menuChoices[MENU_UPGRADE_SUB] then
				curSel[MENU_UPGRADE_SUB] = 2
			end
			guard = guard + 1
			if guard > 50 then break end
		end

		local sel = curSel[MENU_UPGRADES]
		if curSel[MENU_UPGRADE_SUB] == menuChoices[MENU_UPGRADE_SUB] then
			itemSet(player[0].items, sel - 2, itemGet(old_items[0], sel - 2))
		else
			itemSet(player[0].items, sel - 2, availRow(sel)[curSel[MENU_UPGRADE_SUB] - 2])
		end

		if (sel == 3 or sel == 4) and curSel[MENU_UPGRADE_SUB] < menuChoices[MENU_UPGRADE_SUB] and
		   availRow(sel)[curSel[MENU_UPGRADE_SUB] - 2] ~= 0 then
			local item_level = player[0].items.weapon[sel - 3].power

			JE_getCost(sel, availRow(sel)[curSel[MENU_UPGRADE_SUB] - 2])

			leftPower = item_level > 1
			rightPower = item_level < 11

			if rightPower then
				rightPowerAfford = JE_cashLeft() >= upgradeCost
			end
		else
			leftPower = false
			rightPower = false
		end

		local title = menuInt[2][sel - 1]
		JE_dString(VGAScreen, 74 + JE_fontCenter(title, FONT_SHAPES), 10, title, FONT_SHAPES)

		local total = menuChoices[curMenu] - 1
		local first, last = 1, total
		if total > SUB_ROWS then
			local cur = curSel[curMenu] - 1
			if cur < subScroll + 1 then subScroll = cur - 1 end
			if cur > subScroll + SUB_ROWS then subScroll = cur - SUB_ROWS end
			if subScroll > total - SUB_ROWS then subScroll = total - SUB_ROWS end
			if subScroll < 0 then subScroll = 0 end
			first, last = subScroll + 1, subScroll + SUB_ROWS
			-- arrows showing that there is more above / below
			for i = 0, 3 do
				if first > 1 then
					fill_rectangle_xy(VGAScreen, 304 - i, 36 + i, 304 + i, 36 + i, 15)
				end
				if last < total then
					fill_rectangle_xy(VGAScreen, 304 - i, 40 + SUB_ROWS * 26 - 12 - i, 304 + i, 40 + SUB_ROWS * 26 - 12 - i, 15)
				end
			end
		else
			subScroll = 0
		end

		for tw = first, last do
			local tempY = 40 + (tw - first) * 26
			local temp_cost

			if tw < menuChoices[MENU_UPGRADE_SUB] - 1 then
				temp_cost = JE_getCost(sel, availRow(sel)[tw - 1])
			else
				temp_cost = 0
			end

			local afford_shade = (temp_cost > player[0].cash) and 4 or 0

			local item = availRow(sel)[tw - 1] or 0
			local s = ""
			local kind = sel - 1
			if kind == 1 then
				s = ships[item] and ships[item].name or ""
			elseif kind == 2 or kind == 3 then
				s = weaponPort[item].name
			elseif kind == 4 then
				s = shields[item].name
			elseif kind == 5 then
				s = powerSys[item].name
			elseif kind == 6 or kind == 7 then
				s = options[item].name
			end

			local t2 = (tw == curSel[curMenu] - 1) and 15 or 28

			JE_getShipInfo()

			if item == itemGet(old_items[0], sel - 2) and item ~= 0 and tw ~= menuChoices[curMenu] - 1 then
				-- emblem moved 12px left (was 298) so it clears the scroll arrows
				fill_rectangle_xy(VGAScreen, 160, tempY + 7, 288, tempY + 11, 227)
				blit_sprite2(VGAScreen, 286, tempY + 2, shopSpriteSheet, 247)
			end

			if tw == menuChoices[curMenu] - 1 then
				s = miscText[13]
			end
			JE_textShade(VGAScreen, 185, tempY, s, idiv(t2, 16), t2 % 16 - 8 - afford_shade, DARKEN)

			if tw < menuChoices[curMenu] - 1 then
				drawItem(sel - 1, item, 160, tempY - 4)
			end

			t2 = (tw == curSel[curMenu] - 1) and 15 or 28

			if tw ~= menuChoices[curMenu] - 1 then
				JE_textShade(VGAScreen, 187, tempY + 10, sprintf("Cost: %d", temp_cost), idiv(t2, 16), t2 % 16 - 8 - afford_shade, DARKEN)
			end
		end
	end

	if cheats.credits and curMenu ~= MENU_UPGRADE_SUB and player[0].cash < 1000000 then
		player[0].cash = 1000000
	end

	-- money and shield/armor bars
	if ((curMenu <= MENU_OPTIONS or curMenu == MENU_KEYBOARD_CONFIG or curMenu == MENU_LOAD_SAVE or curMenu >= MENU_1_PLAYER_ARCADE) and not twoPlayerMode) or
	   (curMenu == MENU_UPGRADE_SUB and (curSel[MENU_UPGRADES] >= 1 and curSel[MENU_UPGRADES] <= 6)) then
		if curMenu ~= MENU_UPGRADE_SUB then
			JE_textShade(VGAScreen, 65, 173, sprintf("%d", player[0].cash), 1, 6, DARKEN)
		end
		JE_barDrawShadow(VGAScreen, 42, 152, 3, 14, player[0].armor, 2, 13)
		JE_barDrawShadow(VGAScreen, 104, 152, 2, 14, shields[player[0].items.shield].mpwr * 2, 2, 13)
	end

	-- left side: ship illustration etc.
	if (curMenu >= MENU_FULL_GAME and curMenu <= MENU_OPTIONS) or curMenu == MENU_KEYBOARD_CONFIG or
	   curMenu == MENU_LOAD_SAVE or curMenu >= MENU_2_PLAYER_ARCADE or
	   (curMenu == MENU_UPGRADE_SUB and (curSel[MENU_UPGRADES] == 2 or curSel[MENU_UPGRADES] == 5)) then
		if superArcadeMode ~= SA_NONE or superTyrian then
			if not superTyrian then
				JE_helpBox(VGAScreen, 35, 25, superShips[superArcadeMode], 18, 7, 15, 4, FULL_SHADE)
			else
				JE_helpBox(VGAScreen, 35, 25, superShips[SA + 3], 18, 7, 15, 4, FULL_SHADE)
			end

			JE_textShade(VGAScreen, 25, 50, superShips[SA + 1], 15, 0, FULL_SHADE)
			JE_helpBox(VGAScreen, 25, 60, weaponPort[player[0].items.weapon[FRONT_WEAPON].id].name, 22, 7, 12, 1, FULL_SHADE)
			JE_textShade(VGAScreen, 25, 120, superShips[SA + 2], 15, 0, FULL_SHADE)
			JE_helpBox(VGAScreen, 25, 130, special[player[0].items.special].name, 22, 7, 12, 1, FULL_SHADE)
		else
			draw_ship_illustration()
		end
	end

	if curMenu == MENU_OPTIONS or curMenu == MENU_LIMITED_OPTIONS then
		JE_barDrawShadow(VGAScreen, 225, 70, 1, music_disabled and 12 or 16, idiv(tyrMusicVolume, 12), 3, 13)
		JE_barDrawShadow(VGAScreen, 225, 86, 1, samples_disabled and 12 or 16, idiv(fxVolume, 12), 3, 13)
	end

	if curMenu == MENU_DATA_CUBES or (curMenu == MENU_DATA_CUBE_SUB and (firstMenu9 or backFromHelp)) then
		firstMenu9 = false
		menuChoices[MENU_DATA_CUBES] = cubeMax + 2
		fill_rectangle_xy(VGAScreen, 1, 1, 145, 170, 0)

		blit_sprite(VGAScreenSeg, 1, 1, OPTION_SHAPES, 20)

		if curMenu == MENU_DATA_CUBES then
			if cubeMax == 0 then
				JE_helpBox(VGAScreen, 166, 80, miscText[16 - 1], 30, 7, 12, 1, FULL_SHADE)
				tempW = 160
				temp2 = 252
			else
				for xx = 1, cubeMax do
					JE_drawCube(VGAScreenSeg, 166, 38 + (xx - 1) * 28, 13, 0)
					temp2 = (xx + 1 == curSel[curMenu]) and 252 or 250
					JE_helpBox(VGAScreen, 192, 44 + (xx - 1) * 28, cube[xx - 1].title, 24, 7, idiv(temp2, 16), (temp2 % 16) - 8, DARKEN)
				end
				local xx = cubeMax + 1
				temp2 = (xx + 1 == curSel[curMenu]) and 252 or 250
				tempW = 44 + (xx - 1) * 28
			end

			JE_textShade(VGAScreen, 172, tempW, miscText[6 - 1], idiv(temp2, 16), (temp2 % 16) - 8, DARKEN)
		end

		if curSel[MENU_DATA_CUBES] < menuChoices[MENU_DATA_CUBES] then
			local face_sprite = cube[curSel[MENU_DATA_CUBES] - 2].face_sprite

			if face_sprite ~= -1 and face_sprite >= 0 then
				local spr = sprite(FACE_SHAPES, face_sprite)
				blit_sprite(VGAScreenSeg, 77 - idiv(spr.width, 2), 92 - idiv(spr.height, 2), FACE_SHAPES, face_sprite)

				-- modify palette for face (approximation: faces are pre-baked)
				paletteChanged = true
				newPal = 0
			end
		end
	end

	flash = 0

	fillArray(shotMultiPos, 11, 0)

	drawScore()

	drawMainMenuHelpText()

	if newPal > 0 then
		curPal = newPal
		copyPalette(colors, palettes[newPal - 1])
		set_palette(palettes[newPal - 1], 0, 255)
		newPal = 0
	end

	if (curMenu == MENU_DATA_CUBES or curMenu == MENU_DATA_CUBE_SUB) and
	   curSel[MENU_DATA_CUBES] < menuChoices[MENU_DATA_CUBES] then
		local c = cube[curSel[MENU_DATA_CUBES] - 2]
		JE_textShade(VGAScreen, 75 - idiv(JE_textWidth(c.header, TINY_FONT), 2), 173, c.header, 14, 3, DARKEN)
	end
end

function JE_itemScreen()
	local quit = false

	if not shopSpriteSheet.data then
		JE_loadCompShapes(shopSpriteSheet, '1')
	end

	load_cubes()

	VGAScreen = VGAScreenSeg

	copyArray(menuChoices, menuChoicesDefault, MENU_MAX)

	play_song(songBuy)

	JE_loadPic(VGAScreen, 1, false)

	curPal = 1
	newPal = 0

	JE_showVGA()

	set_palette(colors, 0, 255)

	col = 1
	colC = 1
	gameLoaded = false
	cursor = 1

	fillArray(curSel, MENU_MAX, 2)

	curMenu = MENU_FULL_GAME

	if cheats.shopUnlock or cheats.secretUnlock then
		unlockShopItems()
	end

	-- add the player's current items to the merchant inventory
	for i = 0, 6 do
		local item = itemGet(player[0].last_items, i)
		local row = itemAvailMap[i] - 1
		local slot = 0
		while slot < itemAvailMax[row] do
			if itemAvail[row][slot] == item then break end
			slot = slot + 1
		end
		if slot == itemAvailMax[row] then
			itemAvail[row][slot] = item
			itemAvailMax[row] = itemAvailMax[row] + 1
		end
	end

	surfaceCopy(VGAScreen2, VGAScreen)

	firstMenu9 = false
	backFromHelp = false

	-- Sort items in merchant inventory
	for xx = 0, 8 do
		if itemAvailMax[xx] > 1 then
			for t = 0, itemAvailMax[xx] - 2 do
				for t2 = t, itemAvailMax[xx] - 1 do
					local row = itemAvail[xx]
					if row[t] == 0 or (row[t] > row[t2] and row[t2] ~= 0) then
						row[t], row[t2] = row[t2], row[t]
					end
				end
			end
		end
	end

	local mouseButtonsHeld = 0

	repeat
		quit = false

		JE_getShipInfo()

		if curMenu == MENU_FULL_GAME then
			if onePlayerAction then
				curMenu = MENU_1_PLAYER_ARCADE
			end
			if superTyrian then
				curMenu = MENU_SUPER_TYRIAN
			end
		end

		paletteChanged = false

		leftPower = false
		rightPower = false

		if firstMenu9 then
			mouseButtonsHeld = mouseButtonsDown
		end

		if curMenu ~= MENU_DATA_CUBE_SUB or firstMenu9 then
			surfaceCopy(VGAScreen, VGAScreen2)
		end

		if curMenu == MENU_UPGRADES and (curSel[curMenu] == 3 or curSel[curMenu] == 4) then
			local s = curSel[MENU_UPGRADES]
			local item = player[0].items.weapon[s - 3].id
			local item_power = player[0].items.weapon[s - 3].power
			local i = s - 2
			local row = itemAvailMap[i] - 1

			for slot = 0, itemAvailMax[row] - 1 do
				if itemAvail[row][slot] == item then
					temp_weapon_power[slot] = item_power
				else
					temp_weapon_power[slot] = 1
				end
			end

			temp_weapon_power[itemAvailMax[row]] = item_power
		end

		if curMenu == MENU_PLAY_NEXT_LEVEL then
			planetAni = 0
			currentDotNum = 0
			currentDotWait = 8
			planetAniWait = 3
			updateNavScreen()
		end

		if curMenu ~= MENU_UPGRADE_SUB then
			drawMenuHeader()
		end

		if (curMenu >= MENU_FULL_GAME and curMenu <= MENU_PLAY_NEXT_LEVEL) or
		   (curMenu >= MENU_2_PLAYER_ARCADE and curMenu <= MENU_LIMITED_OPTIONS) or
		   curMenu == MENU_SUPER_TYRIAN then
			drawMenuChoices()
		end

		if curMenu == MENU_FULL_GAME then
			for i = 1, cubeMax do
				blit_sprite_dark(VGAScreen, 190 + i * 18 + 2, 37 + 1, OPTION_SHAPES, 34, false)
				blit_sprite(VGAScreen, 190 + i * 18, 37, OPTION_SHAPES, 34)
			end
		end

		if curMenu == MENU_LOAD_SAVE then
			local mn, mx = 2, 13

			for xx = mn, mx do
				temp2 = (xx - mn + 2 == curSel[curMenu]) and 15 or 28

				local s
				if xx == mx then
					s = miscText[6 - 1]
				elseif saveFiles[xx - 2].level == 0 then
					s = miscText[3 - 1]
				else
					s = saveFiles[xx - 2].name
				end

				local tempY = 38 + (xx - mn) * 11

				JE_textShade(VGAScreen, 163, tempY, s, idiv(temp2, 16), temp2 % 16 - 8, DARKEN)

				if xx < mx then
					temp2 = (xx - mn + 2 == curSel[curMenu]) and 252 or 250

					if saveFiles[xx - 2].level == 0 then
						s = "-----"
					else
						s = saveFiles[xx - 2].levelName
						JE_textShade(VGAScreen, 297, tempY, sprintf("%s%d", miscTextB[1 - 1], saveFiles[xx - 2].episode), idiv(temp2, 16), temp2 % 16 - 8, DARKEN)
					end

					JE_textShade(VGAScreen, 245, tempY, s, idiv(temp2, 16), temp2 % 16 - 8, DARKEN)
				end

				drawMenuHeader()
			end
		end

		if curMenu == MENU_KEYBOARD_CONFIG then
			for xx = 2, 11 do
				temp2 = (xx == curSel[curMenu]) and 15 or 28

				JE_textShade(VGAScreen, 166, 38 + (xx - 2) * 12, menuInt[curMenu + 1][xx - 1], idiv(temp2, 16), temp2 % 16 - 8, DARKEN)

				if xx < 10 then
					temp2 = (xx == curSel[curMenu]) and 252 or 250
					JE_textShade(VGAScreen, 236, 38 + (xx - 2) * 12, SDL_GetScancodeName(keySettings[xx - 2]), idiv(temp2, 16), temp2 % 16 - 8, DARKEN)
				end
			end

			menuChoices[MENU_KEYBOARD_CONFIG] = 11
		end

		drawMenuScreen()

		-- Inner loop: animations and timing.  Everything drawn inside the loop
		-- is redrawn every frame, so the screen is reset to its static part
		-- each iteration (the original overwrote pixels in place).
		local baseN = VGAScreen.n
		while true do
			VGAScreen.n = baseN
			mouseCursor = MOUSE_POINTER_NORMAL

			col = col + colC
			if col < -2 or col > 6 then
				colC = -colC
			end

			if curMenu == MENU_DATA_CUBE_SUB then
				fill_rectangle_xy(VGAScreen, 160, 49, 310, 158, 228)
				if yLoc + yChg < 0 then
					yChg = 0
					yLoc = 0
				end

				yLoc = yLoc + yChg
				local t = idiv(yLoc, 12)
				local t2 = yLoc % 12
				local tw = 38 + 12 - t2
				local c = cube[curSel[MENU_DATA_CUBES] - 2]
				local t3 = c.last_line

				for xx = t + 1, t + 10 do
					if xx <= t3 then
						JE_outTextAndDarken(VGAScreen, 161, tw, c.text[xx - 1], 14, 3, TINY_FONT)
						tw = tw + 12
					end
				end

				fill_rectangle_xy(VGAScreen, 160, 39, 310, 48, 228)
				fill_rectangle_xy(VGAScreen, 160, 157, 310, 166, 228)

				local cc = cube[currentCube]
				local percent_read = (cc.last_line <= 9) and 100 or idiv(yLoc * 100, (cc.last_line - 9) * 12)

				JE_outTextAndDarken(VGAScreen, 176, 160, sprintf("%s %d%%", miscText[11], percent_read), 14, 1, TINY_FONT)

				JE_dString(VGAScreen, 260, 160, miscText[12], SMALL_FONT_SHAPES)

				if t2 == 0 then
					yChg = 0
				end

				JE_mouseStart()
				JE_showVGA()

				if backFromHelp then
					fade_palette(colors, 10, 0, 255)
					backFromHelp = false
				end
				JE_mouseReplace()

				setFrameCount(1)
			else
				if curMenu == MENU_PLAY_NEXT_LEVEL then
					updateNavScreen()
					drawMainMenuHelpText()
					drawMenuHeader()
					drawMenuChoices()
					if extraGame then
						JE_dString(VGAScreen, 170, 140, miscText[68 - 1], FONT_SHAPES)
					end
				end

				if curMenu == MENU_DATA_CUBES and curSel[MENU_DATA_CUBES] < menuChoices[MENU_DATA_CUBES] then
					blit_sprite_hv_blend(VGAScreenSeg, 166, 38 + (curSel[MENU_DATA_CUBES] - 2) * 28, OPTION_SHAPES, 25, 13, col)
				end

				local sel = curSel[MENU_UPGRADES]
				if curMenu == MENU_UPGRADE_SUB and (sel == 3 or sel == 4 or (sel >= 6 and sel <= 8)) then
					setFrameCount(3)
					weaponSimUpdate()
				else
					setFrameCount(2)
				end

				drawScore()

				if newPal > 0 then
					curPal = newPal
					set_palette(palettes[newPal - 1], 0, 255)
					newPal = 0
				end

				JE_mouseStart()

				if paletteChanged then
					set_palette(colors, 0, 255)
					paletteChanged = false
				end

				JE_showVGA()

				if backFromHelp then
					fade_palette(colors, 10, 0, 255)
					backFromHelp = false
				end

				JE_mouseReplace()
			end

			waitUntilElapsed()

			if curMenu == MENU_DATA_CUBE_SUB then
				mouseButtonsHeld = band(mouseButtonsHeld, mouseButtonsDown)

				if keysactive[SDL_SCANCODE_PAGEUP] then yChg = -2 end
				if keysactive[SDL_SCANCODE_PAGEDOWN] then yChg = 2 end
				if keysactive[SDL_SCANCODE_UP] then yChg = -1 end
				if keysactive[SDL_SCANCODE_DOWN] then yChg = 1 end

				if yChg < 0 and yLoc == 0 then
					yChg = 0
				end
				if yChg > 0 and idiv(yLoc, 12) > cube[currentCube].last_line - 10 then
					yChg = 0
				end
			end

			if hasInput(INPUT_NO_MOTION) then break end
			mouseGetInput(INPUT_ANY) -- discard motion
		end

		-- Input handling
		local mouseInput = mouseGetInput(INPUT_NO_MOTION)
		if mouseInput then
			lastDirection = 1

			if curMenu == MENU_DATA_CUBES and cubeMax == 0 then
				curMenu = MENU_FULL_GAME
				JE_playSampleNum(S_SPRING)
				newPal = 1
			end

			if curMenu == MENU_DATA_CUBE_SUB then
				if mouseInput.x > 258 and mouseInput.x < 290 and mouseInput.y > 159 and mouseInput.y < 171 then
					curMenu = MENU_DATA_CUBES
					JE_playSampleNum(S_SPRING)
				end
			end

			if mouseInput.button == SDL_BUTTON_RIGHT then
				-- right click acts like Escape
				keyboardClearInput()
				ns.onKeyDown("ESCAPE")
				ns.onKeyUp("ESCAPE")
			elseif mouseInput.y > 20 and mouseInput.x > 170 and mouseInput.x < 308 and curMenu ~= MENU_DATA_CUBE_SUB then
				local mouseSelectionY = { [0] = 16, 16, 16, 16, 26, 12, 11, 28, 0, 16, 16, 16, 8, 16 }

				local selection = idiv(mouseInput.y - 38, mouseSelectionY[curMenu]) + 2
				if curMenu == MENU_UPGRADE_SUB then
					if selection - 1 > SUB_ROWS then selection = 0 end
					selection = selection + subScroll
				end

				if curMenu == MENU_FULL_GAME and selection > 7 then
					selection = 7
				end

				if curMenu == MENU_PLAY_NEXT_LEVEL and selection == menuChoices[curMenu] + 1 then
					selection = menuChoices[curMenu]
				end

				if selection >= 2 and selection <= menuChoices[curMenu] then
					if curMenu == MENU_UPGRADE_SUB and selection == menuChoices[MENU_UPGRADE_SUB] then
						player[0].cash = JE_cashLeft()
						curMenu = MENU_UPGRADES
						JE_playSampleNum(S_ITEM)
					else
						JE_playSampleNum(S_CLICK)
						if curSel[curMenu] == selection then
							menuFunction(curSel[curMenu])
						else
							if curMenu == MENU_UPGRADE_SUB and
							   JE_getCost(curSel[MENU_UPGRADES], availRow(curSel[MENU_UPGRADES])[selection - 2]) > player[0].cash then
								JE_playSampleNum(S_CLINK)
							else
								if curSel[MENU_UPGRADES] == 4 then
									player[0].weapon_mode = 1
								end
								curSel[curMenu] = selection
							end

							if curMenu == MENU_UPGRADE_SUB and (curSel[MENU_UPGRADES] == 3 or curSel[MENU_UPGRADES] == 4) then
								player[0].items.weapon[curSel[MENU_UPGRADES] - 3].power = temp_weapon_power[curSel[MENU_UPGRADE_SUB] - 2]
							end
						end
					end
				end
			end

			if curMenu == MENU_UPGRADE_SUB and (curSel[MENU_UPGRADES] == 3 or curSel[MENU_UPGRADES] == 4) then
				local wi = curSel[MENU_UPGRADES] - 3
				local pi = curSel[MENU_UPGRADE_SUB] - 2
				if mouseInput.x >= 23 and mouseInput.x <= 36 and mouseInput.y >= 149 and mouseInput.y <= 168 then
					JE_playSampleNum(S_CURSOR)
					if leftPower then
						temp_weapon_power[pi] = temp_weapon_power[pi] - 1
						player[0].items.weapon[wi].power = temp_weapon_power[pi]
					else
						JE_playSampleNum(S_CLINK)
					end
				end

				if mouseInput.x >= 119 and mouseInput.x <= 131 and mouseInput.y >= 149 and mouseInput.y <= 168 then
					JE_playSampleNum(S_CURSOR)
					if rightPower and rightPowerAfford then
						temp_weapon_power[pi] = temp_weapon_power[pi] + 1
						player[0].items.weapon[wi].power = temp_weapon_power[pi]
					else
						JE_playSampleNum(S_CLINK)
					end
				end
			end
		else
			local k = keyboardGetInput()
			if k then
				local sc = k.scancode
				if sc == SDL_SCANCODE_SLASH then
					if curMenu == MENU_UPGRADE_SUB and curSel[MENU_UPGRADES] == 4 then
						player[0].weapon_mode = player[0].weapon_mode + 1
						if player[0].weapon_mode > weaponPort[player[0].items.weapon[REAR_WEAPON].id].opnum then
							player[0].weapon_mode = 1
						end
					end

				elseif sc == SDL_SCANCODE_SPACE or sc == SDL_SCANCODE_RETURN then
					if curMenu == MENU_UPGRADE_SUB and (curSel[MENU_UPGRADES] == 3 or curSel[MENU_UPGRADES] == 4) then
						temp_weapon_power[availMax(curSel[MENU_UPGRADES])] = player[0].items.weapon[curSel[MENU_UPGRADES] - 3].power
					end

					menuFunction(curSel[curMenu])

				elseif sc == SDL_SCANCODE_ESCAPE then
					JE_playSampleNum(S_SPRING)
					if curMenu == MENU_LOAD_SAVE and quikSave then
						curMenu = oldMenu
						newPal = oldPal
					elseif menuEsc[curMenu] == 0 then
						if JE_quitRequest() then
							gameLoaded = true
							mainLevel = 0
						end
					else
						if curMenu == MENU_UPGRADE_SUB then
							structAssign(player[0].items, old_items[0])
							curSel[MENU_UPGRADE_SUB] = lastCurSel
							player[0].cash = JE_cashLeft()
						end

						if curMenu ~= MENU_DATA_CUBE_SUB then
							newPal = 1
						end

						curMenu = menuEsc[curMenu] - 1
					end

				elseif sc == SDL_SCANCODE_F1 then
					fade_black(10)
					JE_helpSystem(2)

					play_song(songBuy)

					JE_loadPic(VGAScreen, 1, false)
					newPal = 1

					if curMenu == 3 then
						newPal = 18
					end

					surfaceCopy(VGAScreen2, VGAScreen)

					curPal = newPal
					copyPalette(colors, palettes[newPal - 1])
					JE_showVGA()
					newPal = 0
					backFromHelp = true

				elseif sc == SDL_SCANCODE_UP then
					lastDirection = -1

					if curMenu ~= MENU_DATA_CUBE_SUB then
						JE_playSampleNum(S_CURSOR)
					end

					curSel[curMenu] = curSel[curMenu] - 1
					if curSel[curMenu] < 2 then
						curSel[curMenu] = menuChoices[curMenu]
					end

					if curMenu == MENU_UPGRADE_SUB and (curSel[MENU_UPGRADES] == 3 or curSel[MENU_UPGRADES] == 4) then
						player[0].items.weapon[curSel[MENU_UPGRADES] - 3].power = temp_weapon_power[curSel[MENU_UPGRADE_SUB] - 2]
						if curSel[MENU_UPGRADES] == 4 then
							player[0].weapon_mode = 1
						end
					end

				elseif sc == SDL_SCANCODE_DOWN then
					lastDirection = 1

					if curMenu ~= MENU_DATA_CUBE_SUB then
						JE_playSampleNum(S_CURSOR)
					end

					curSel[curMenu] = curSel[curMenu] + 1
					if curSel[curMenu] > menuChoices[curMenu] then
						curSel[curMenu] = 2
					end

					if curMenu == MENU_UPGRADE_SUB and (curSel[MENU_UPGRADES] == 3 or curSel[MENU_UPGRADES] == 4) then
						player[0].items.weapon[curSel[MENU_UPGRADES] - 3].power = temp_weapon_power[curSel[MENU_UPGRADE_SUB] - 2]
						if curSel[MENU_UPGRADES] == 4 then
							player[0].weapon_mode = 1
						end
					end

				elseif sc == SDL_SCANCODE_HOME then
					if curMenu == MENU_DATA_CUBE_SUB then
						yLoc = 0
					end

				elseif sc == SDL_SCANCODE_END then
					if curMenu == MENU_DATA_CUBE_SUB then
						yLoc = (cube[currentCube].last_line - 9) * 12
					end

				elseif sc == SDL_SCANCODE_LEFT or sc == SDL_SCANCODE_RIGHT then
					local dir = (sc == SDL_SCANCODE_LEFT) and -1 or 1

					if curMenu == MENU_OPTIONS or curMenu == MENU_UPGRADE_SUB or curMenu == MENU_LIMITED_OPTIONS then
						JE_playSampleNum(S_CURSOR)
					end

					if curMenu == 2 or curMenu == 11 then
						if curSel[curMenu] == 4 then
							tyrMusicVolume, fxVolume = JE_changeVolume(tyrMusicVolume, 12 * dir, fxVolume, 0)
							if music_disabled then
								music_disabled = false
								restart_song()
							end
						elseif curSel[curMenu] == 5 then
							tyrMusicVolume, fxVolume = JE_changeVolume(tyrMusicVolume, 0, fxVolume, 12 * dir)
							samples_disabled = false
						end
					elseif curMenu == 4 then
						local s = curSel[MENU_UPGRADES]
						if s == 3 or s == 4 then
							local pi = curSel[MENU_UPGRADE_SUB] - 2
							if dir < 0 then
								if leftPower then
									temp_weapon_power[pi] = temp_weapon_power[pi] - 1
									player[0].items.weapon[s - 3].power = temp_weapon_power[pi]
								else
									JE_playSampleNum(S_CLINK)
								end
							else
								if rightPower and rightPowerAfford then
									temp_weapon_power[pi] = temp_weapon_power[pi] + 1
									player[0].items.weapon[s - 3].power = temp_weapon_power[pi]
								else
									JE_playSampleNum(S_CLINK)
								end
							end
						end
					end

				else
					-- Alt+S / Alt+L quick save/load
					local sym = k.sym
					if (sym == 115 or sym == 108) and band(k.mod, KMOD_ALT) ~= 0 and curMenu ~= MENU_LOAD_SAVE then
						if curMenu == MENU_DATA_CUBE_SUB or curMenu == MENU_DATA_CUBES then
							curMenu = MENU_FULL_GAME
						end
						quikSave = true
						oldMenu = curMenu
						curMenu = MENU_LOAD_SAVE
						performSave = (sym == 115)
						newPal = 1
						oldPal = curPal
					end
				end
			end
		end
	until quit or gameLoaded or jumpSection

	if gameLoaded then
		fade_black(10)
	end
end
