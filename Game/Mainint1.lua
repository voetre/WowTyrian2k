--[[
 WowTyrian2k: a World of Warcraft port of OpenTyrian
 Copyright (C) The OpenTyrian Development Team
 Lua port Copyright (C) 2026 voetre
 Licensed under the GNU General Public License v2 or later (see COPYING).

 mainint.c (part 1): menus and screens
]]
local _, ns = ...
setfenv(1, ns.G)

local strbyte, strsub = string.byte, string.sub

button = { [0] = false, false, false, false } -- fire, left fire, right fire, mode swap

-- The original's "Two-Player Game Menu" topic and its help page are removed;
-- two players are not supported in this port (see Text.lua for topicName).
MAX_PAGE = 7
TOPICS = 5
topicStart = { [0] = 0, 1, 2, 6, 255 }

constantLastX = 0
textErase = 0
upgradeCost = 0
downgradeCost = 0
performSave = false
jumpSection = false
useLastBank = false

pause_pressed, ingamemenu_pressed = false, false

-- Draws a message at the bottom text window on the playing screen
function JE_drawTextWindow(text)
	if textErase > 0 then
		blit_sprite(VGAScreenSeg, 16, 189, OPTION_SHAPES, 36)
	end
	textErase = 100
	flightBarShown = nil
	JE_outText(VGAScreenSeg, 20, 190, text, 0, 4)
end

-- Flight path progress in the message bar (new for this port): while the
-- player is on a WoW flight and no message is showing, the bar fills as the
-- flight goes on, with the destination and the time left.  Redrawn only when
-- it changes, so at most about once a second.
flightBarShown = nil

function JE_drawFlightBar()
	-- the flight's time left (with the boss state in a timed level), else
	-- a timed level's time to its boss
	local c = ns.Flight and ns.Flight.current
	local text, done
	if c then
		local left = ns.Flight.remaining()
		local secs = math.ceil(left)
		local boss = LevelGen.bossTag()
		-- the town's name without its zone, short enough to fit the strip
		local dest = (c.dest or "Flight"):match("^[^,]+")
		local room = 34 - 7 - (boss and #boss + 2 or 0)
		if #dest > room then dest = dest:sub(1, room - 1) .. "." end
		text = sprintf("%s  %d:%02d", dest, idiv(secs, 60), secs % 60)
		if left == 0 then text = dest .. "  landing" end
		if boss then text = text .. "  " .. boss end
		done = 1 - left / c.eta
	else
		text, done = LevelGen.barInfo()
	end
	if ns.options and ns.options.flightBar == false then text = nil end
	if not text then
		if flightBarShown then
			flightBarShown = nil
			blit_sprite(VGAScreenSeg, 16, 189, OPTION_SHAPES, 36)
		end
		return
	end
	-- the strip is 228x9 at (16,189); the bar fills its inside
	local x1, x2 = 18, 241
	local fill = x1 + math.floor((x2 - x1) * done + 0.5)
	local key = fill .. text
	if key == flightBarShown then return end
	flightBarShown = key
	blit_sprite(VGAScreenSeg, 16, 189, OPTION_SHAPES, 36)
	if fill > x1 then
		JE_barBright(VGAScreenSeg, x1, 190, fill, 196)
		JE_barBright(VGAScreenSeg, x1, 190, fill, 196)
	end
	JE_textShade(VGAScreenSeg, 20, 190, text, 14, 4, PART_SHADE)
end

function JE_outCharGlow(x_, y_, s)
	local glowcol = newArray(60, -8)
	local glowcolc = newArray(60, 1)
	local textloc = newArray(60, 0)

	local bank = warningRed and 7 or (useLastBank and 15 or 14)

	if #s == 0 then return end

	if frameCountMax == 0 then
		JE_textShade(VGAScreen, x_, y_, s, bank, 0, PART_SHADE)
		JE_showVGA()
	else
		local maxloc = #s
		local loc = x_
		for z = 0, maxloc - 1 do
			textloc[z] = loc
			local c = strbyte(s, z + 1)
			local sprite_id = fontMap[c]
			if c == 32 then
				loc = loc + 6
			elseif sprite_id ~= -1 then
				loc = loc + sprite(TINY_FONT, sprite_id).width + 1
			end
		end

		for l = 0, #s + 28 - 1 do
			if ESCPressed then break end

			setFrameCount(1)

			local sprite_id = -1
			local z = l - 28
			while z <= l do
				if z >= 0 and z < maxloc then
					sprite_id = fontMap[strbyte(s, z + 1)]
					if sprite_id ~= -1 then
						blit_sprite_hv(VGAScreen, textloc[z], y_, TINY_FONT, sprite_id, bank, glowcol[z])
						glowcol[z] = glowcol[z] + glowcolc[z]
						if glowcol[z] > 9 then
							glowcolc[z] = -1
						end
					end
				end
				z = z + 1
			end
			z = z - 1
			if sprite_id ~= -1 and z < maxloc then
				blit_sprite_dark(VGAScreen, textloc[z] + 1, y_ + 1, TINY_FONT, sprite_id, true)
			end

			JE_showVGA()

			local frameCount = frameCountMax
			while frameCount > 0 do
				if levelWarningDisplay then
					JE_updateWarning(VGAScreen)
				end
				waitUntilElapsed()
				if getInput() then
					frameCountMax = 0
				end
				if ESCPressed then break end
				setFrameCount(1)
				frameCount = frameCount - 1
			end
		end
	end
end

function JE_drawPortConfigButtons()
	if twoPlayerMode then return end

	if player[0].weapon_mode == 1 then
		blit_sprite(VGAScreenSeg, 285, 44, OPTION_SHAPES, 18)
		blit_sprite(VGAScreenSeg, 302, 44, OPTION_SHAPES, 19)
	else
		blit_sprite(VGAScreenSeg, 285, 44, OPTION_SHAPES, 19)
		blit_sprite(VGAScreenSeg, 302, 44, OPTION_SHAPES, 18)
	end
end

local function helpSystemPage(topicRef)
	local page = topicStart[topicRef.topic - 1]
	local xCenter = 160

	while true do
		if page == 0 then
			topicRef.topic = 1
			return true
		elseif page > MAX_PAGE then
			topicRef.topic = TOPICS - 1
			return true
		end

		for t = 0, TOPICS - 1 do
			if topicStart[t] <= page then
				topicRef.topic = t + 1
			else
				break
			end
		end

		setFrameCount(1)

		surfaceCopy(VGAScreen, VGAScreen2)
		fill_rectangle_wh(VGAScreen, 0, 192, 320, 8, 0)

		local text = topicName[topicRef.topic - 1]
		drawFontHvShadowAligned(VGAScreen, xCenter, 1, text, FONT_NORMAL, ALIGN_CENTER, 15, -3, false, 2)

		local buffer = sprintf("%s %d", miscText[24], page - topicStart[topicRef.topic - 1] + 1)
		drawFontHvAligned(VGAScreen, 10, 192, buffer, FONT_SMALL, ALIGN_LEFT, 13, 5)

		buffer = sprintf("%s %d of %d", miscText[25], page, MAX_PAGE)
		drawFontHvAligned(VGAScreen, 320 - 10, 192, buffer, FONT_SMALL, ALIGN_RIGHT, 13, 5)

		if page == 1 then
			JE_HBox(VGAScreen, 10, 20, 2, 60, 8, 12, 3)
			JE_HBox(VGAScreen, 10, 50, 5, 60, 8, 12, 3)
			JE_HBox(VGAScreen, 10, 80, 21, 60, 8, 12, 3)
			JE_HBox(VGAScreen, 10, 110, 1, 60, 8, 12, 3)
			JE_HBox(VGAScreen, 10, 140, 28, 60, 8, 12, 3)
		elseif page == 2 then
			JE_HBox(VGAScreen, 10, 20, 5, 60, 8, 12, 3)
			JE_HBox(VGAScreen, 10, 70, 6, 60, 8, 12, 3)
			JE_HBox(VGAScreen, 10, 110, 7, 60, 8, 12, 3)
		elseif page == 3 then
			JE_HBox(VGAScreen, 10, 20, 8, 60, 8, 12, 3)
			JE_HBox(VGAScreen, 10, 55, 9, 60, 8, 12, 3)
			JE_HBox(VGAScreen, 10, 87, 10, 60, 8, 12, 3)
			JE_HBox(VGAScreen, 10, 120, 11, 60, 8, 12, 3)
			JE_HBox(VGAScreen, 10, 170, 13, 60, 8, 12, 3)
		elseif page == 4 then
			JE_HBox(VGAScreen, 10, 20, 14, 60, 8, 12, 3)
			JE_HBox(VGAScreen, 10, 80, 15, 60, 8, 12, 3)
			JE_HBox(VGAScreen, 10, 120, 16, 60, 8, 12, 3)
		elseif page == 5 then
			JE_HBox(VGAScreen, 10, 20, 17, 60, 8, 12, 3)
			JE_HBox(VGAScreen, 10, 40, 18, 60, 8, 12, 3)
			JE_HBox(VGAScreen, 10, 130, 20, 60, 8, 12, 3)
		elseif page == 6 then
			JE_HBox(VGAScreen, 10, 20, 21, 60, 8, 12, 3)
			JE_HBox(VGAScreen, 10, 70, 22, 60, 8, 12, 3)
			JE_HBox(VGAScreen, 10, 110, 23, 60, 8, 12, 3)
			JE_HBox(VGAScreen, 10, 140, 24, 60, 8, 12, 3)
		elseif page == 7 then
			JE_HBox(VGAScreen, 10, 20, 25, 60, 8, 12, 3)
			JE_HBox(VGAScreen, 10, 60, 26, 60, 8, 12, 3)
			JE_HBox(VGAScreen, 10, 100, 27, 60, 8, 12, 3)
			JE_HBox(VGAScreen, 10, 140, 28, 60, 8, 12, 3)
			JE_HBox(VGAScreen, 10, 170, 29, 60, 8, 12, 3)
		end

		if topicRef.restart then
			fade_palette(colors, 10, 0, 255)
			topicRef.restart = false
		end

		while true do
			mouseCursor = (mouseX < xCenter) and MOUSE_POINTER_LEFT or MOUSE_POINTER_RIGHT

			JE_mouseStart()
			JE_showVGA()
			JE_mouseReplace()

			waitUntilElapsed()
			waitUntilHasInput(INPUT_ANY)

			if hasInput(INPUT_NO_MOTION) then break end

			mouseGetInput(INPUT_ANY) -- discard motion
			setFrameCount(1)
		end

		local done = false

		local mouseInput = mouseGetInput(INPUT_NO_MOTION)
		if mouseInput then
			if mouseInput.button == SDL_BUTTON_LEFT then
				JE_playSampleNum(S_CURSOR)
				if mouseInput.x < xCenter then page = page - 1 else page = page + 1 end
			elseif mouseInput.button == SDL_BUTTON_RIGHT then
				JE_playSampleNum(S_SPRING)
				done = true
			end
		else
			local keyboardInput = keyboardGetInput()
			if keyboardInput then
				local sc = keyboardInput.scancode
				if sc == SDL_SCANCODE_LEFT then
					JE_playSampleNum(S_CURSOR)
					page = page - 1
				elseif sc == SDL_SCANCODE_RIGHT or sc == SDL_SCANCODE_SPACE or sc == SDL_SCANCODE_RETURN then
					JE_playSampleNum(S_CURSOR)
					page = page + 1
				elseif sc == SDL_SCANCODE_ESCAPE then
					JE_playSampleNum(S_SPRING)
					done = true
				end
			end
		end

		if done then
			fade_black(15)
			return false
		end
	end
end

function JE_helpSystem(startTopic)
	if not shopSpriteSheet.data then
		JE_loadCompShapes(shopSpriteSheet, '1')
	end

	local topicRef = { topic = startTopic, restart = true }

	local menuItemsCount = TOPICS - 1
	local selectedIndex = 0

	local xCenter = 160
	local yMenuHeader = 30
	local yMenuItems = 60
	local dyMenuItems = 20
	local hMenuItem = 13
	local wMenuItem = newArray(menuItemsCount, 0)

	while true do
		setFrameCount(1)

		if topicRef.restart then
			play_song(SONG_MAPVIEW)
			JE_loadPic(VGAScreen2, 2, false)
		end

		if topicRef.topic > 1 then
			if not helpSystemPage(topicRef) then
				return
			end
			selectedIndex = topicRef.topic - 1
			topicRef.topic = 1
		else
			surfaceCopy(VGAScreen, VGAScreen2)

			drawFontHvShadowAligned(VGAScreen, xCenter, yMenuHeader, topicName[0], FONT_LARGE, ALIGN_CENTER, 15, -3, false, 2)

			for i = 0, menuItemsCount - 1 do
				local text = topicName[i + 1]
				wMenuItem[i] = JE_textWidth(text, FONT_NORMAL)
				local yy = yMenuItems + dyMenuItems * i
				local selected = i == selectedIndex
				drawFontHvShadowAligned(VGAScreen, xCenter, yy, text, FONT_NORMAL, ALIGN_CENTER, 15, -3 + (selected and 2 or 0), false, 2)
			end

			mouseCursor = MOUSE_POINTER_NORMAL

			if topicRef.restart then
				fade_palette(colors, 10, 0, 255)
				topicRef.restart = false
			end

			JE_mouseStart()
			JE_showVGA()
			JE_mouseReplace()

			waitUntilElapsed()
			waitUntilHasInput(INPUT_ANY)

			local action, done = false, false

			local mouseInput = mouseGetInput(INPUT_ANY)
			if mouseInput then
				for i = 0, menuItemsCount - 1 do
					local xMenuItem = xCenter - idiv(wMenuItem[i], 2)
					if mouseInput.x >= xMenuItem and mouseInput.x < xMenuItem + wMenuItem[i] then
						local yMenuItem = yMenuItems + dyMenuItems * i
						if mouseInput.y >= yMenuItem and mouseInput.y < yMenuItem + hMenuItem then
							if selectedIndex ~= i then
								JE_playSampleNum(S_CURSOR)
								selectedIndex = i
							end
							if mouseInput.button == SDL_BUTTON_LEFT then
								action = true
							end
							break
						end
					end
				end
				if mouseInput.button == SDL_BUTTON_RIGHT then
					JE_playSampleNum(S_SPRING)
					done = true
				end
			else
				local keyboardInput = keyboardGetInput()
				if keyboardInput then
					local sc = keyboardInput.scancode
					if sc == SDL_SCANCODE_UP then
						JE_playSampleNum(S_CURSOR)
						selectedIndex = (selectedIndex == 0) and menuItemsCount - 1 or selectedIndex - 1
					elseif sc == SDL_SCANCODE_DOWN then
						JE_playSampleNum(S_CURSOR)
						selectedIndex = (selectedIndex == menuItemsCount - 1) and 0 or selectedIndex + 1
					elseif sc == SDL_SCANCODE_SPACE or sc == SDL_SCANCODE_RETURN then
						action = true
					elseif sc == SDL_SCANCODE_ESCAPE then
						JE_playSampleNum(S_SPRING)
						done = true
					end
				end
			end

			if action then
				JE_playSampleNum(S_SELECT)
				topicRef.topic = selectedIndex + 2
				if selectedIndex == menuItemsCount - 1 then
					done = true
				end
			end

			if done then
				fade_black(15)
				return
			end
		end
	end
end

-- cost to upgrade a weapon power from power-1
function weapon_upgrade_cost(base_cost, pw)
	local t = 0
	while pw > 0 do
		t = t + pw
		pw = pw - 1
	end
	return base_cost * t
end

function JE_getCost(itemType, itemNum)
	local cost = 0
	if itemType == 2 then
		cost = (itemNum > 90) and 100 or ships[itemNum].cost
	elseif itemType == 3 or itemType == 4 then
		cost = weaponPort[itemNum].cost
		local port = itemType - 3
		local item_power = player[0].items.weapon[port].power - 1
		downgradeCost = u16(weapon_upgrade_cost(cost, item_power))
		upgradeCost = u16(weapon_upgrade_cost(cost, item_power + 1))
	elseif itemType == 5 then
		cost = shields[itemNum].cost
	elseif itemType == 6 then
		cost = powerSys[itemNum].cost
	elseif itemType == 7 or itemType == 8 then
		cost = options[itemNum].cost
	end
	return cost
end

function JE_loadScreen()
	if not shopSpriteSheet.data then
		JE_loadCompShapes(shopSpriteSheet, '1')
	end

	local restart = true

	local playersIndex = 0
	local menuItemsCount = 12
	local selectedIndex = 0

	local xCenter = 160
	local yMenuHeader = 5
	local xMenuItem = 10
	local xMenuItemName = xMenuItem
	local xMenuItemLastLevel = 120
	local xMenuItemEpisode = 250
	local wMenuItem = 300
	local yMenuItems = 30
	local dyMenuItems = 13
	local hMenuItem = 8
	local xLeftControl = 83
	local xRightControl = 213
	local wControl = 24
	local yControls = 179

	while true do
		setFrameCount(1)

		if restart then
			JE_loadPic(VGAScreen2, 2, false)
			fill_rectangle_wh(VGAScreen2, 0, 192, 320, 8, 0)
		end

		surfaceCopy(VGAScreen, VGAScreen2)

		drawFontHvShadowAligned(VGAScreen, xCenter, yMenuHeader, miscText[38 + playersIndex], FONT_LARGE, ALIGN_CENTER, 15, -3, false, 2)

		for i = 0, menuItemsCount - 1 do
			local yy = yMenuItems + dyMenuItems * i
			local selected = i == selectedIndex

			if i == menuItemsCount - 1 then
				JE_textShade(VGAScreen, xMenuItemName, yy, miscText[33], 13, selected and 6 or 2, FULL_SHADE)
			else
				local saveFile = saveFiles[playersIndex * 11 + i]
				local disabled = saveFile.level == 0

				if disabled then
					JE_textShade(VGAScreen, xMenuItemName, yy, miscText[2], 13, selected and 6 or 0, FULL_SHADE)
					JE_textShade(VGAScreen, xMenuItemLastLevel, yy, sprintf("%s -----", miscTextB[2]), 5, selected and 6 or 0, FULL_SHADE)
				else
					JE_textShade(VGAScreen, xMenuItemName, yy, saveFile.name, 13, selected and 6 or 2, FULL_SHADE)
					JE_textShade(VGAScreen, xMenuItemLastLevel, yy, sprintf("%s %s", miscTextB[2], saveFile.levelName), 5, selected and 6 or 2, FULL_SHADE)
					JE_textShade(VGAScreen, xMenuItemEpisode, yy, sprintf("%s %d", miscTextB[1], saveFile.episode), 5, selected and 6 or 2, FULL_SHADE)
				end
			end
		end

		local leftControlVisible = false
		local rightControlVisible = false

		if leftControlVisible then
			blit_sprite2x2(VGAScreen, xLeftControl, yControls, shopSpriteSheet, 279)
		end
		if rightControlVisible then
			blit_sprite2x2(VGAScreen, xRightControl, yControls, shopSpriteSheet, 281)
		end

		JE_helpBox(VGAScreen, 103, 182, miscText[55], 25, 7, 15, 1, FULL_SHADE)

		if restart then
			mouseCursor = MOUSE_POINTER_NORMAL
			fade_palette(colors, 10, 0, 255)
			restart = false
		end

		JE_mouseStart()
		JE_showVGA()
		JE_mouseReplace()

		waitUntilElapsed()
		waitUntilHasInput(INPUT_ANY)

		local leftAction, rightAction, action, done = false, false, false, false

		local mouseInput = mouseGetInput(INPUT_ANY)
		if mouseInput then
			if leftControlVisible and mouseInput.y >= yControls and mouseInput.x >= xLeftControl and mouseInput.x < xLeftControl + wControl then
				if mouseInput.button == SDL_BUTTON_LEFT then
					JE_playSampleNum(S_CURSOR)
					leftAction = true
				end
			elseif rightControlVisible and mouseInput.y >= yControls and mouseInput.x >= xRightControl and mouseInput.x < xRightControl + wControl then
				if mouseInput.button == SDL_BUTTON_LEFT then
					JE_playSampleNum(S_CURSOR)
					rightAction = true
				end
			else
				if mouseInput.x >= xMenuItem and mouseInput.x < xMenuItem + wMenuItem then
					for i = 0, menuItemsCount - 1 do
						local yMenuItem = yMenuItems + dyMenuItems * i
						if mouseInput.y >= yMenuItem and mouseInput.y < yMenuItem + hMenuItem then
							if selectedIndex ~= i then
								JE_playSampleNum(S_CURSOR)
								selectedIndex = i
							end
							if mouseInput.button == SDL_BUTTON_LEFT then
								action = true
							end
							break
						end
					end
				end
			end

			if mouseInput.button == SDL_BUTTON_RIGHT then
				JE_playSampleNum(S_SPRING)
				done = true
			end
		else
			local keyboardInput = keyboardGetInput()
			if keyboardInput then
				local sc = keyboardInput.scancode
				if sc == SDL_SCANCODE_LEFT then
					JE_playSampleNum(S_CURSOR)
					leftAction = true
				elseif sc == SDL_SCANCODE_RIGHT then
					JE_playSampleNum(S_CURSOR)
					rightAction = true
				elseif sc == SDL_SCANCODE_UP then
					JE_playSampleNum(S_CURSOR)
					selectedIndex = (selectedIndex == 0) and menuItemsCount - 1 or selectedIndex - 1
				elseif sc == SDL_SCANCODE_DOWN then
					JE_playSampleNum(S_CURSOR)
					selectedIndex = (selectedIndex == menuItemsCount - 1) and 0 or selectedIndex + 1
				elseif sc == SDL_SCANCODE_SPACE or sc == SDL_SCANCODE_RETURN then
					action = true
				elseif sc == SDL_SCANCODE_ESCAPE then
					JE_playSampleNum(S_SPRING)
					done = true
				end
			end
		end

		if action then
			if selectedIndex == menuItemsCount - 1 then
				JE_playSampleNum(S_SELECT)
				done = true
			else
				local saveFileIndex = playersIndex * 11 + selectedIndex
				if saveFiles[saveFileIndex].level == 0 then
					JE_playSampleNum(S_CLINK)
				else
					JE_playSampleNum(S_SELECT)
					performSave = false
					JE_operation(saveFileIndex + 1)
					fade_black(15)
					return gameLoaded
				end
			end
		end

		if done then
			fade_black(15)
			return false
		end
	end
end

function JE_totalScore(this_player)
	local t = this_player.cash
	t = t + JE_getValue(2, this_player.items.ship)
	t = t + JE_getValue(3, this_player.items.weapon[FRONT_WEAPON].id)
	t = t + JE_getValue(4, this_player.items.weapon[REAR_WEAPON].id)
	t = t + JE_getValue(5, this_player.items.shield)
	t = t + JE_getValue(6, this_player.items.generator)
	t = t + JE_getValue(7, this_player.items.sidekick[LEFT_SIDEKICK])
	t = t + JE_getValue(8, this_player.items.sidekick[RIGHT_SIDEKICK])
	return t
end

function JE_getValue(itemType, itemNum)
	local value = 0
	if itemType == 2 then
		value = ships[itemNum] and ships[itemNum].cost or 0
	elseif itemType == 3 or itemType == 4 then
		local base_value = weaponPort[itemNum].cost
		local port = itemType - 3
		local item_power = player[twoPlayerMode and port or 0].items.weapon[port].power - 1
		value = base_value
		for i = 1, item_power do
			value = value + weapon_upgrade_cost(base_value, i)
		end
	elseif itemType == 5 then
		value = shields[itemNum].cost
	elseif itemType == 6 then
		value = powerSys[itemNum].cost
	elseif itemType == 7 or itemType == 8 then
		value = options[itemNum].cost
	end
	return value
end

function JE_nextEpisode()
	lastLevelName = "Completed"

	if episodeNum == initial_episode_num and not gameHasRepeated and episodeNum ~= EPISODE_AVAILABLE and
	   not constantPlay then
		JE_highScoreCheck()
	end

	local newEpisode = JE_findNextEpisode()

	if jumpBackToEpisode1 then
		if episodeNum > 2 and not constantPlay then
			JE_playCredits()
		end

		if (mt_rand() % 6) == 0 then
			player[0].items.ship = 2
			player[0].items.weapon[FRONT_WEAPON].id = 23
			player[0].items.weapon[REAR_WEAPON].id = 24
			for i = 0, 1 do
				player[0].items.weapon[i].power = 1
			end
			player[1].items.weapon[REAR_WEAPON].id = 24
			structAssign(player[0].last_items, player[0].items)
		end
	end

	if newEpisode ~= episodeNum then
		JE_initEpisode(newEpisode)
	end

	gameLoaded = true
	mainLevel = FIRST_LEVEL
	saveLevel = FIRST_LEVEL

	play_song(26)

	JE_clr256(VGAScreen)
	copyPalette(colors, palettes[6 - 1])

	JE_dString(VGAScreen, JE_fontCenter(episode_name[episodeNum], SMALL_FONT_SHAPES), 130, episode_name[episodeNum], SMALL_FONT_SHAPES)
	JE_dString(VGAScreen, JE_fontCenter(miscText[5 - 1], SMALL_FONT_SHAPES), 185, miscText[5 - 1], SMALL_FONT_SHAPES)

	JE_showVGA()
	fade_palette(colors, 15, 0, 255)

	if not constantPlay then
		waitUntilGetInput()
	end

	fade_black(15)
end

function JE_initPlayerData()
	local it = player[0].items
	it.ship = 1
	it.weapon[FRONT_WEAPON].id = 1
	it.weapon[REAR_WEAPON].id = 0
	it.shield = 4
	it.generator = 2
	it.sidekick[0] = 0
	it.sidekick[1] = 0
	it.special = 0

	structAssign(player[0].last_items, player[0].items)

	structAssign(player[1].items, player[0].items)
	player[1].items.weapon[REAR_WEAPON].id = 15
	player[1].items.sidekick_level = 101
	player[1].items.sidekick_series = 0

	gameHasRepeated = false
	onePlayerAction = false
	superArcadeMode = SA_NONE
	superTyrian = false
	twoPlayerMode = false

	secretHint = (mt_rand() % 3) + 1

	for p = 0, 1 do
		for i = 0, 1 do
			player[p].items.weapon[i].power = 1
		end
		player[p].weapon_mode = 1
		player[p].armor = ships[player[p].items.ship].dmg
		player[p].is_dragonwing = (p == 1)
		player[p].lives = player[p].items.weapon[p]
	end

	mainLevel = FIRST_LEVEL
	saveLevel = FIRST_LEVEL

	lastLevelName = miscText[19]
end

function JE_sortHighScores()
	temp = 0
	for xx = 0, 5 do
		JE_sort()
		temp = temp + 3
	end
end

function JE_highScoreScreen()
	if not shopSpriteSheet.data then
		JE_loadCompShapes(shopSpriteSheet, '1')
	end

	local restart = true
	local episodeIndex = 0
	local episodeCount = 3

	local xCenter = 160
	local yMenuHeader = 3
	local yEpisodeHeader = 30
	local xLeftControl = 83
	local xRightControl = 213
	local wControl = 24
	local yControls = 179

	while true do
		setFrameCount(1)

		if restart then
			JE_loadPic(VGAScreen2, 2, false)
			fill_rectangle_wh(VGAScreen2, 0, 192, 320, 8, 0)
			drawFontHvShadowAligned(VGAScreen2, xCenter, yMenuHeader, miscText[50], FONT_LARGE, ALIGN_CENTER, 15, -3, false, 2)
		end

		surfaceCopy(VGAScreen, VGAScreen2)

		local disabled = not episodeAvail[episodeIndex]
		drawFontHvShadowAligned(VGAScreen, xCenter, yEpisodeHeader, episode_name[episodeIndex + 1], FONT_NORMAL, ALIGN_CENTER, 15, -3 + (disabled and -4 or 0), false, 2)

		for i = 0, 2 do
			local yy = 75 + 10 * i
			local saveFile = saveFiles[episodeIndex * 6 + i]
			local rank = MIN(saveFile.highScoreDiff, 10)
			JE_textShade(VGAScreen, 20, yy, sprintf("~#%d:~  %d", i + 1, saveFile.highScore1), 15, 0, FULL_SHADE)
			JE_textShade(VGAScreen, 110, yy, saveFile.highScoreName, 15, 2, FULL_SHADE)
			JE_textShade(VGAScreen, 250, yy, difficultyNameB[rank], 15, rank + (rank == 0 and 0 or -1), FULL_SHADE)
		end


		local leftControlVisible = episodeIndex > 0
		local rightControlVisible = episodeIndex < episodeCount - 1

		if leftControlVisible then
			blit_sprite2x2(VGAScreen, xLeftControl, yControls, shopSpriteSheet, 279)
		end
		if rightControlVisible then
			blit_sprite2x2(VGAScreen, xRightControl, yControls, shopSpriteSheet, 281)
		end

		JE_helpBox(VGAScreen, 103, 182, miscText[56], 25, 7, 15, 1, FULL_SHADE)

		if restart then
			mouseCursor = MOUSE_POINTER_NORMAL
			fade_palette(colors, 10, 0, 255)
			restart = false
		end

		while true do
			JE_mouseStart()
			JE_showVGA()
			JE_mouseReplace()

			waitUntilElapsed()
			waitUntilHasInput(INPUT_ANY)

			if hasInput(INPUT_NO_MOTION) then break end

			mouseGetInput(INPUT_ANY)
			setFrameCount(1)
		end

		local leftAction, rightAction, done = false, false, false

		local mouseInput = mouseGetInput(INPUT_NO_MOTION)
		if mouseInput then
			if mouseInput.button == SDL_BUTTON_LEFT then
				if leftControlVisible and mouseInput.y >= yControls and mouseInput.x >= xLeftControl and mouseInput.x < xLeftControl + wControl then
					JE_playSampleNum(S_CURSOR)
					leftAction = true
				elseif rightControlVisible and mouseInput.y >= yControls and mouseInput.x >= xRightControl and mouseInput.x < xRightControl + wControl then
					JE_playSampleNum(S_CURSOR)
					rightAction = true
				end
			elseif mouseInput.button == SDL_BUTTON_RIGHT then
				JE_playSampleNum(S_SPRING)
				done = true
			end
		else
			local keyboardInput = keyboardGetInput()
			if keyboardInput then
				local sc = keyboardInput.scancode
				if sc == SDL_SCANCODE_LEFT then
					JE_playSampleNum(S_CURSOR)
					leftAction = true
				elseif sc == SDL_SCANCODE_RIGHT then
					JE_playSampleNum(S_CURSOR)
					rightAction = true
				elseif sc == SDL_SCANCODE_SPACE or sc == SDL_SCANCODE_RETURN or sc == SDL_SCANCODE_ESCAPE then
					JE_playSampleNum(S_SPRING)
					done = true
				end
			end
		end

		if leftAction then
			episodeIndex = (episodeIndex == 0) and episodeCount - 1 or episodeIndex - 1
		elseif rightAction then
			episodeIndex = (episodeIndex == episodeCount - 1) and 0 or episodeIndex + 1
		end

		if done then
			fade_black(15)
			return
		end
	end
end

function JE_gammaCorrect(colorBuffer, gamma)
	local r = 1 + gamma / 10
	for xx = 0, 255 do
		local c = colorBuffer[xx]
		for k = 1, 3 do
			local v = roundf(c[k] * r)
			if v > 255 then v = 255 end
			c[k] = v
		end
	end
end

function JE_gammaCheck()
	local t = keysactive[SDL_SCANCODE_F11]
	if t then
		keysactive[SDL_SCANCODE_F11] = false
		gammaCorrection = (gammaCorrection + 1) % 4
		copyPalette(colors, palettes[pcxpal[3 - 1]])
		JE_gammaCorrect(colors, gammaCorrection)
		set_palette(colors, 0, 255)
	end
	return t
end

function JE_doInGameSetup()
	mouseSetRelative(false)

	haltGame = false

	if yourInGameMenuRequest then
		if JE_inGameSetup() then
			reallyEndLevel = true
			playerEndLevel = true
		end
		quitRequested = false

		keysactive[SDL_SCANCODE_ESCAPE] = false
	end

	yourInGameMenuRequest = false

	mouseSetRelative(true)
end

function JE_inGameSetup()
	local result = false

	local temp_surface = VGAScreen
	VGAScreen = VGAScreenSeg

	local MENU_ITEM_MUSIC_VOLUME = 0
	local MENU_ITEM_EFFECTS_VOLUME = 1
	local MENU_ITEM_DETAIL_LEVEL = 2
	local MENU_ITEM_GAME_SPEED = 3
	local MENU_ITEM_RETURN_TO_GAME = 4
	local MENU_ITEM_QUIT = 5

	local helpIndexes = { [0] = 14, 14, 27, 28, 25, 26 }

	if not shopSpriteSheet.data then
		JE_loadCompShapes(shopSpriteSheet, '1')
	end

	local restart = true

	local menuItemsCount = 6
	local selectedIndex = MENU_ITEM_MUSIC_VOLUME

	local yMenuItems = 20
	local dyMenuItems = 20
	local xMenuItem = 10
	local xMenuItemName = xMenuItem
	local wMenuItemName = 110
	local xMenuItemValue = xMenuItemName + wMenuItemName
	local wMenuItemValue = 90
	local wMenuItem = wMenuItemName + wMenuItemValue
	local hMenuItem = 13

	local done = false
	while not done do
		setFrameCount(1)

		if restart then
			JE_barShade(VGAScreen, 3, 13, 217, 137)
			JE_barShade(VGAScreen, 5, 15, 215, 135)

			JE_barShade(VGAScreen, 3, 143, 257, 157)
			JE_barShade(VGAScreen, 5, 145, 255, 155)

			surfaceCopy(VGAScreen2, VGAScreen)

			mouseCursor = MOUSE_POINTER_NORMAL

			restart = false
		end

		surfaceCopy(VGAScreen, VGAScreen2)

		for i = 0, menuItemsCount - 1 do
			local yy = yMenuItems + dyMenuItems * i
			local name = inGameText[i]
			local selected = i == selectedIndex

			drawFontHvShadow(VGAScreen, xMenuItemName, yy, name, FONT_NORMAL, 15, -4 + (selected and 2 or 0), false, 2)

			if i == MENU_ITEM_MUSIC_VOLUME then
				JE_barDrawShadow(VGAScreen, xMenuItemValue, yy, 1, music_disabled and 12 or 16, idiv(tyrMusicVolume + 6, 12), 3, 13)
			elseif i == MENU_ITEM_EFFECTS_VOLUME then
				JE_barDrawShadow(VGAScreen, xMenuItemValue, yy, 1, samples_disabled and 12 or 16, idiv(fxVolume + 6, 12), 3, 13)
			elseif i == MENU_ITEM_DETAIL_LEVEL then
				drawFontHvShadow(VGAScreen, xMenuItemValue, yy, detailLevel[processorType - 1] or "", FONT_NORMAL, 15, -4 + (selected and 2 or 0), false, 2)
			elseif i == MENU_ITEM_GAME_SPEED then
				drawFontHvShadow(VGAScreen, xMenuItemValue, yy, gameSpeedText[gameSpeed - 1] or "", FONT_NORMAL, 15, -4 + (selected and 2 or 0), false, 2)
			end
		end

		JE_outTextAdjust(VGAScreen, 10, 147, mainMenuHelp[helpIndexes[selectedIndex]], 14, 6, TINY_FONT, true)

		JE_mouseStart()
		JE_showVGA()
		JE_mouseReplace()

		waitUntilElapsed()
		waitUntilHasInput(INPUT_ANY)

		local action, leftAction, rightAction = false, false, false

		local mouseInput = mouseGetInput(INPUT_ANY)
		if mouseInput then
			if mouseInput.x >= xMenuItem and mouseInput.x < xMenuItem + wMenuItem then
				for i = 0, menuItemsCount - 1 do
					local yMenuItem = yMenuItems + dyMenuItems * i
					if mouseInput.y >= yMenuItem and mouseInput.y < yMenuItem + hMenuItem then
						if selectedIndex ~= i then
							JE_playSampleNum(S_CURSOR)
							selectedIndex = i
						end

						if mouseInput.button == SDL_BUTTON_LEFT then
							if mouseInput.x >= xMenuItemName and mouseInput.x < xMenuItemName + wMenuItemName then
								action = true
							elseif mouseInput.x >= xMenuItemValue and mouseInput.x < xMenuItemValue + wMenuItemValue then
								local w = idiv(255 + 6, 12) * (3 + 1) - 1
								if i == MENU_ITEM_MUSIC_VOLUME then
									JE_playSampleNum(S_CURSOR)
									local value = idiv((mouseInput.x - xMenuItemValue) * 255, w - 1)
									tyrMusicVolume = MIN(MAX(0, value), 255)
									set_volume(tyrMusicVolume, fxVolume)
								elseif i == MENU_ITEM_EFFECTS_VOLUME then
									local value = idiv((mouseInput.x - xMenuItemValue) * 255, w - 1)
									fxVolume = MIN(MAX(0, value), 255)
									set_volume(tyrMusicVolume, fxVolume)
									JE_playSampleNum(S_CURSOR)
								elseif i == MENU_ITEM_DETAIL_LEVEL or i == MENU_ITEM_GAME_SPEED then
									rightAction = true
								end
							end
						end
						break
					end
				end
			end

			if mouseInput.button == SDL_BUTTON_RIGHT then
				JE_playSampleNum(S_SPRING)
				done = true
			end
		else
			local keyboardInput = keyboardGetInput()
			if keyboardInput then
				local sc = keyboardInput.scancode
				if sc == SDL_SCANCODE_UP then
					JE_playSampleNum(S_CURSOR)
					selectedIndex = (selectedIndex == 0) and menuItemsCount - 1 or selectedIndex - 1
				elseif sc == SDL_SCANCODE_DOWN then
					JE_playSampleNum(S_CURSOR)
					selectedIndex = (selectedIndex == menuItemsCount - 1) and 0 or selectedIndex + 1
				elseif sc == SDL_SCANCODE_LEFT then
					leftAction = true
				elseif sc == SDL_SCANCODE_RIGHT then
					rightAction = true
				elseif sc == SDL_SCANCODE_SPACE or sc == SDL_SCANCODE_RETURN then
					action = true
				elseif sc == SDL_SCANCODE_ESCAPE then
					JE_playSampleNum(S_SPRING)
					done = true
				elseif sc == SDL_SCANCODE_W then
					if selectedIndex == MENU_ITEM_DETAIL_LEVEL then
						processorType = 6
						JE_initProcessorType()
					end
				end
			end
		end

		if action then
			if selectedIndex == MENU_ITEM_MUSIC_VOLUME then
				JE_playSampleNum(S_SELECT)
				music_disabled = not music_disabled
				if music_disabled then stop_song() else restart_song() end
			elseif selectedIndex == MENU_ITEM_EFFECTS_VOLUME then
				samples_disabled = not samples_disabled
				JE_playSampleNum(S_SELECT)
			elseif selectedIndex == MENU_ITEM_RETURN_TO_GAME then
				JE_playSampleNum(S_SELECT)
				done = true
			elseif selectedIndex == MENU_ITEM_QUIT then
				JE_playSampleNum(S_SELECT)
				if constantPlay then
					JE_tyrianHalt(0)
				end
				result = true
				done = true
			end
		elseif leftAction then
			if selectedIndex == MENU_ITEM_MUSIC_VOLUME then
				JE_playSampleNum(S_CURSOR)
				tyrMusicVolume, fxVolume = JE_changeVolume(tyrMusicVolume, -12, fxVolume, 0)
			elseif selectedIndex == MENU_ITEM_EFFECTS_VOLUME then
				tyrMusicVolume, fxVolume = JE_changeVolume(tyrMusicVolume, 0, fxVolume, -12)
				JE_playSampleNum(S_CURSOR)
			elseif selectedIndex == MENU_ITEM_DETAIL_LEVEL then
				JE_playSampleNum(S_CURSOR)
				processorType = (processorType > 1) and processorType - 1 or 4
				JE_initProcessorType()
				JE_setNewGameSpeed()
			elseif selectedIndex == MENU_ITEM_GAME_SPEED then
				JE_playSampleNum(S_CURSOR)
				gameSpeed = (gameSpeed > 1) and gameSpeed - 1 or 5
				JE_initProcessorType()
				JE_setNewGameSpeed()
			end
		elseif rightAction then
			if selectedIndex == MENU_ITEM_MUSIC_VOLUME then
				JE_playSampleNum(S_CURSOR)
				tyrMusicVolume, fxVolume = JE_changeVolume(tyrMusicVolume, 12, fxVolume, 0)
			elseif selectedIndex == MENU_ITEM_EFFECTS_VOLUME then
				tyrMusicVolume, fxVolume = JE_changeVolume(tyrMusicVolume, 0, fxVolume, 12)
				JE_playSampleNum(S_CURSOR)
			elseif selectedIndex == MENU_ITEM_DETAIL_LEVEL then
				JE_playSampleNum(S_CURSOR)
				processorType = (processorType < 4) and processorType + 1 or 1
				JE_initProcessorType()
				JE_setNewGameSpeed()
			elseif selectedIndex == MENU_ITEM_GAME_SPEED then
				JE_playSampleNum(S_CURSOR)
				gameSpeed = (gameSpeed < 5) and gameSpeed + 1 or 1
				JE_initProcessorType()
				JE_setNewGameSpeed()
			end
		end
	end

	VGAScreen = temp_surface

	return result
end

function JE_inGameHelp()
	mouseSetRelative(false)

	setFrameCount(1)

	local temp_surface = VGAScreen
	VGAScreen = VGAScreenSeg

	JE_barShade(VGAScreen, 1, 1, 262, 182)
	JE_barShade(VGAScreen, 3, 3, 260, 180)
	JE_barShade(VGAScreen, 5, 5, 258, 178)
	JE_barShade(VGAScreen, 7, 7, 256, 176)
	fill_rectangle_xy(VGAScreen, 9, 9, 254, 174, 0)

	blit_sprite(VGAScreenSeg, 15, 5, OPTION_SHAPES, 40)
	JE_HBox(VGAScreen, 40, 10, 31, 45, 7, 5, 3)

	blit_sprite(VGAScreenSeg, 5, 37, OPTION_SHAPES, 39)
	JE_HBox(VGAScreen, 40, 40, 32, 44, 7, 5, 3)
	JE_HBox(VGAScreen, 40, 60, 33, 44, 7, 5, 3)

	blit_sprite(VGAScreenSeg, 5, 98, OPTION_SHAPES, 41)
	JE_HBox(VGAScreen, 40, 103, 34, 44, 7, 5, 3)

	blit_sprite(VGAScreenSeg, 2, 138, OPTION_SHAPES, 42)
	JE_HBox(VGAScreen, 54, 143, 35, 40, 7, 5, 3)

	blit_sprite(VGAScreenSeg, 16, 189, OPTION_SHAPES, 36)
	JE_outText(VGAScreenSeg, 120 - idiv(JE_textWidth(miscText[5 - 1], TINY_FONT), 2) + 20, 190, miscText[5 - 1], 0, 4)

	while true do
		JE_mouseStart()
		JE_showVGA()
		JE_mouseReplace()

		waitUntilElapsed()
		waitUntilHasInput(INPUT_ANY)

		if getInput() then break end

		mouseGetInput(INPUT_ANY)
		setFrameCount(1)
	end

	textErase = 1
	flightBarShown = nil

	VGAScreen = temp_surface

	mouseSetRelative(true)
end

-- Text entry helper: returns the edited 0-based char table and its length.
local function charsOf(s, n)
	local t = {}
	for i = 0, n - 1 do
		local c = strsub(s, i + 1, i + 1)
		t[i] = (c ~= "") and c or " "
	end
	return t
end

local function joinChars(t, n)
	local r = {}
	for i = 0, n - 1 do r[i + 1] = t[i] end
	return table.concat(r)
end

function JE_highScoreCheck()
	if not shopSpriteSheet.data then
		JE_loadCompShapes(shopSpriteSheet, '1')
	end

	for temp_p = 0, 0 do
		JE_sortHighScores()

		local temp_score = JE_totalScore(player[0])

		local first_slot = (initial_episode_num - 1) * 6
		local slot_limit = first_slot + 3
		local slot = first_slot

		while slot < slot_limit do
			if temp_score > saveFiles[slot].highScore1 then break end
			slot = slot + 1
		end

		if slot < slot_limit then
			for i = slot_limit - 1, slot + 1, -1 do
				saveFiles[i].highScore1 = saveFiles[i - 1].highScore1
				saveFiles[i].highScoreName = saveFiles[i - 1].highScoreName
			end

			JE_clr256(VGAScreen)
			JE_showVGA()
			copyPalette(colors, palettes[0])

			play_song(33)

			local flash_ = 8 * 16 + 10
			local fadein = true
			local quit, cancel = false, false
			local stemp = charsOf("", 29)
			temp = 0

			JE_barShade(VGAScreen, 65, 55, 255, 155)
			local baseN = VGAScreen.n

			repeat
				VGAScreen.n = baseN
				setFrameCount(1)

				JE_dString(VGAScreen, JE_fontCenter(miscText[51], FONT_SHAPES), 3, miscText[51], FONT_SHAPES)

				temp3 = 53

				JE_dString(VGAScreen, JE_fontCenter(miscText[temp3 - 1], SMALL_FONT_SHAPES), 30, miscText[temp3 - 1], SMALL_FONT_SHAPES)

				blit_sprite(VGAScreenSeg, 50, 50, OPTION_SHAPES, 35)

				JE_textShade(VGAScreen, 60, 55, miscText[53], 11, 4, FULL_SHADE)

				JE_textShade(VGAScreen, 70, 70, sprintf("%s %d", miscText[37], temp_score), 11, 4, FULL_SHADE)

				while true do
					flash_ = (flash_ == 8 * 16 + 10) and 8 * 16 + 2 or 8 * 16 + 10
					temp3 = (temp3 == 6) and 2 or 6

					local tempstr = joinChars(stemp, temp)
					JE_outText(VGAScreen, 65, 89, tempstr, 8, 3)
					tempW = 65 + JE_textWidth(tempstr, TINY_FONT)
					JE_barShade(VGAScreen, tempW + 2, 90, tempW + 6, 95)
					fill_rectangle_xy(VGAScreen, tempW + 1, 89, tempW + 5, 94, flash_)

					for i = 0, 13 do
						JE_mouseStart()
						JE_showVGA()
						if fadein then
							fade_palette(colors, 15, 0, 255)
							fadein = false
						end
						JE_mouseReplace()

						waitUntilElapsed()

						if hasInput(INPUT_NO_MOTION) then break end

						setFrameCount(1)
					end

					if hasInput(INPUT_NO_MOTION) then break end
				end

				if not playing then
					play_song(31)
				end

				local mouseInput = mouseGetInput(INPUT_NO_MOTION)
				if mouseInput then
					if mouseInput.x > 56 and mouseInput.x < 142 and mouseInput.y > 123 and mouseInput.y < 149 then
						quit = true
					elseif mouseInput.x > 151 and mouseInput.x < 237 and mouseInput.y > 123 and mouseInput.y < 149 then
						quit = true
						cancel = true
					end
				else
					local keyboardInput = keyboardGetInput()
					if keyboardInput then
						local sc = keyboardInput.scancode
						if sc == SDL_SCANCODE_BACKSPACE or sc == SDL_SCANCODE_DELETE then
							if temp > 0 then
								temp = temp - 1
								stemp[temp] = " "
							end
						elseif sc == SDL_SCANCODE_ESCAPE then
							quit = true
							cancel = true
						elseif sc == SDL_SCANCODE_RETURN then
							quit = true
						end

						local ch = keyboardInput.ch
						if (ch == 32 or fontMap[ch] ~= -1) and temp < 28 then
							stemp[temp] = string.char(ch)
							temp = temp + 1
						end
					end
				end
			until quit

			if not cancel then
				saveFiles[slot].highScore1 = temp_score
				saveFiles[slot].highScoreName = joinChars(stemp, 29):gsub("%s+$", "")
				saveFiles[slot].highScoreDiff = difficultyLevel
			end

			fade_black(15)
			JE_loadPic(VGAScreen, 2, false)

			JE_dString(VGAScreen, JE_fontCenter(miscText[50], FONT_SHAPES), 10, miscText[50], FONT_SHAPES)
			JE_dString(VGAScreen, JE_fontCenter(episode_name[episodeNum], SMALL_FONT_SHAPES), 35, episode_name[episodeNum], SMALL_FONT_SHAPES)

			for i = first_slot, slot_limit - 1 do
				if i ~= slot then
					JE_textShade(VGAScreen, 20, ((i - first_slot + 1) * 12) + 65, sprintf("~#%d:~  %d", i - first_slot + 1, saveFiles[i].highScore1), 15, 0, FULL_SHADE)
					JE_textShade(VGAScreen, 150, ((i - first_slot + 1) * 12) + 65, saveFiles[i].highScoreName, 15, 2, FULL_SHADE)
				end
			end

			JE_showVGA()

			fade_palette(colors, 15, 0, 255)

			local buffer = sprintf("~#%d:~  %d", slot - first_slot + 1, saveFiles[slot].highScore1)

			frameCountMax = 6
			textGlowFont = TINY_FONT

			textGlowBrightness = 10
			JE_outTextGlow(VGAScreenSeg, 20, (slot - first_slot + 1) * 12 + 65, buffer)
			textGlowBrightness = 10
			JE_outTextGlow(VGAScreenSeg, 150, (slot - first_slot + 1) * 12 + 65, saveFiles[slot].highScoreName)
			textGlowBrightness = 10
			JE_outTextGlow(VGAScreenSeg, JE_fontCenter(miscText[4], TINY_FONT), 180, miscText[4])

			JE_showVGA()

			if frameCountMax ~= 0 then
				waitUntilGetInput()
			end

			fade_black(15)
		end
	end
end

function adjust_difficulty()
	local score_multiplier = { [0] = 0, 0.4, 0.8, 1.3, 1.6, 2, 2, 3, 3, 3 }

	local score = JE_totalScore(player[0])
	local adjusted_score = roundf(score * (score_multiplier[initialDifficulty] or 0))

	local new_difficulty
	if adjusted_score < 40000 then new_difficulty = DIFFICULTY_EASY
	elseif adjusted_score < 70000 then new_difficulty = DIFFICULTY_NORMAL
	elseif adjusted_score < 150000 then new_difficulty = DIFFICULTY_HARD
	elseif adjusted_score < 300000 then new_difficulty = DIFFICULTY_IMPOSSIBLE
	elseif adjusted_score < 600000 then new_difficulty = DIFFICULTY_INSANITY
	elseif adjusted_score < 1000000 then new_difficulty = DIFFICULTY_SUICIDE
	elseif adjusted_score < 2000000 then new_difficulty = DIFFICULTY_MANIACAL
	elseif adjusted_score < 3000000 then new_difficulty = DIFFICULTY_ZINGLON
	else new_difficulty = DIFFICULTY_NORTANEOUS end

	difficultyLevel = MAX(difficultyLevel, new_difficulty)
end

function JE_sort()
	for a = 0, 1 do
		for bb = a + 1, 2 do
			local sa, sb = saveFiles[temp + a], saveFiles[temp + bb]
			if sa.highScore1 < sb.highScore1 then
				sa.highScore1, sb.highScore1 = sb.highScore1, sa.highScore1
				sa.highScoreName, sb.highScoreName = sb.highScoreName, sa.highScoreName
				sa.highScoreDiff, sb.highScoreDiff = sb.highScoreDiff, sa.highScoreDiff
			end
		end
	end
end

function JE_playCredits()
	local credstr = {}

	local currentpic, fade = 0, 0
	local fadechg = 1
	local currentship = 0
	local shipx, shipxwait = 0, 0
	local shipxc, shipxca = 0, 0

	load_sprites_file(EXTRA_SHAPES, "estsc.shp")

	setFrameCount2(1000)

	play_song(8)

	local file = dataFileOpen("tyrian.cdt")
	for i = 0, 130 do
		credstr[i] = readEncryptedString(file, 66)
	end

	copyPalette(colors, palettes[6 - 1])
	JE_clr256(VGAScreen)
	JE_showVGA()
	fade_palette(colors, 2, 0, 255)

	local ticks_max = 131 * 20 * 3
	local ticks = 0
	while ticks < ticks_max do
		setFrameCount(1)

		JE_clr256(VGAScreen)

		local spr = sprite(EXTRA_SHAPES, currentpic)
		blit_sprite_hv(VGAScreenSeg, 319 - spr.width, 100 - idiv(spr.height, 2), EXTRA_SHAPES, currentpic, 0x0, fade - 15)

		fade = fade + fadechg
		if fade == 0 and fadechg == -1 then
			fadechg = 1
			currentpic = currentpic + 1
			if currentpic >= sprite_table[EXTRA_SHAPES].count then
				currentpic = 0
			end
		end
		if fade == 15 then
			fadechg = 0
		end

		if getFrameCount2Ticks() == 0 then
			setFrameCount2(900)
			fadechg = -1
		end

		if ticks % 200 == 0 then
			currentship = (mt_rand() % 11) + 1
			shipxwait = (mt_rand() % 80) + 10
			if (mt_rand() % 2) == 1 then
				shipx = 1
				shipxc = 0
				shipxca = 1
			else
				shipx = 900
				shipxc = 0
				shipxca = -1
			end
		end

		shipxwait = shipxwait - 1
		if shipxwait == 0 then
			if shipx == 1 or shipx == 900 then
				shipxc = 0
			end
			shipxca = -shipxca
			shipxwait = (mt_rand() % 40) + 15
		end
		shipxc = shipxc + shipxca
		shipx = shipx + shipxc
		if shipx < 1 then
			shipx = 1
			shipxwait = 1
		end
		if shipx > 900 then
			shipx = 900
			shipxwait = 1
		end
		local tmp_unknown = shipxc * shipxc
		if 450 + tmp_unknown < 0 or 450 + tmp_unknown > 900 then
			if shipxca < 0 and shipxc < 0 then shipxwait = 1 end
			if shipxca > 0 and shipxc > 0 then shipxwait = 1 end
		end

		local ship_sprite = ships[currentship].shipgraphic
		if shipxc < -10 then
			ship_sprite = ship_sprite - ((shipxc < -20) and 4 or 2)
		elseif shipxc > 10 then
			ship_sprite = ship_sprite + ((shipxc > 20) and 4 or 2)
		end

		blit_sprite2x2(VGAScreen, idiv(shipx, 40), 184 - (ticks % 200), spriteSheet9, ship_sprite)

		local bottom_line = idiv(idiv(ticks, 3), 20)
		local yy = 20 - (idiv(ticks, 3) % 20)

		for line = bottom_line - 10, bottom_line - 1 do
			if line >= 0 and line < 131 then
				local s = credstr[line]
				local c0 = strsub(s, 1, 1)
				if c0 ~= "." and c0 ~= "" then
					local color = u8(strbyte(s, 1) - 65)
					local text = strsub(s, 2)
					local xx = 110 - idiv(JE_textWidth(text, SMALL_FONT_SHAPES), 2)
					JE_outTextAdjust(VGAScreen, xx + abs(cmod(idiv(yy, 18), 4) - 2) - 1, yy - 1, text, color, -8, SMALL_FONT_SHAPES, false)
					JE_outTextAdjust(VGAScreen, xx, yy, text, color, -2, SMALL_FONT_SHAPES, false)
				end
			end
			yy = yy + 20
		end

		fill_rectangle_xy(VGAScreen, 0, 0, 319, 10, 0)
		fill_rectangle_xy(VGAScreen, 0, 190, 319, 199, 0)

		if currentpic == sprite_table[EXTRA_SHAPES].count - 1 then
			JE_outTextAdjust(VGAScreen, 5, 180, miscText[54], 2, -2, SMALL_FONT_SHAPES, false)
		end

		if bottom_line == 131 - 8 then
			fade_song()
		end

		if ticks == ticks_max - 1 then
			ticks = ticks - 1
			play_song(9)
		end

		JE_showVGA()

		if waitUntilGetInputOrElapsed() then
			break
		end

		ticks = ticks + 1
	end

	fade_black(10)

	free_sprites(EXTRA_SHAPES)
end

function JE_endLevelAni()
	if not constantPlay then
		for p = 0, 1 do
			for i = 0, 1 do
				local e = player[p].items.weapon[i].id - 1
				if e >= 0 and e < 100 then
					editorItemAvail[e] = 1
				end
			end
			for i = 0, 1 do
				local e = 50 + player[p].items.sidekick[i]
				if e < 100 then
					editorItemAvail[e] = 1
				end
			end
		end
		local e = 80 + player[0].items.special
		if e < 100 then
			editorItemAvail[e] = 1
		end
	end

	adjust_difficulty()

	structAssign(player[0].last_items, player[0].items)
	lastLevelName = levelName

	frameCountMax = 4
	textGlowFont = SMALL_FONT_SHAPES

	set_colors({ 255, 255, 255 }, 254, 254)

	if not levelTimer or levelTimerCountdown > 0 or not (episodeNum == 4) then
		JE_playSampleNum(V_LEVEL_END)
	else
		play_song(21)
	end

	if bonusLevel then
		JE_outTextGlow(VGAScreenSeg, 20, 20, miscText[17 - 1])
	elseif all_players_alive() then
		JE_outTextGlow(VGAScreenSeg, 20, 20, sprintf("%s %s", miscText[27 - 1], levelName))
	else
		JE_outTextGlow(VGAScreenSeg, 20, 20, sprintf("%s %s", miscText[62 - 1], levelName))
	end

	JE_outTextGlow(VGAScreenSeg, 30, 50, sprintf("%s %d", miscText[28 - 1], player[0].cash))

	local t = (totalEnemy == 0) and 0 or u8(idiv(enemyKilled * 100, totalEnemy))
	JE_outTextGlow(VGAScreenSeg, 40, 90, sprintf("%s %d%%", miscText[63 - 1], t))

	if not constantPlay then
		editorLevel = u16(editorLevel + idiv(t, 5))
	end

	if not onePlayerAction and not twoPlayerMode then
		JE_outTextGlow(VGAScreenSeg, 30, 120, miscText[4 - 1])

		if cubeMax > 0 then
			if cubeMax > 4 then cubeMax = 4 end

			if frameCountMax ~= 0 then frameCountMax = 1 end

			for c = 1, cubeMax do
				JE_playSampleNum(S_ITEM)
				local xx = 20 + 30 * c
				local yy = 135
				JE_drawCube(VGAScreenSeg, xx, yy, 9, 0)
				JE_showVGA()

				for i = -15, 10 do
					setFrameCount(frameCountMax)
					blit_sprite_hv(VGAScreenSeg, xx, yy, OPTION_SHAPES, 25, 0x9, i)
					JE_showVGA()
					if waitUntilGetInputOrElapsed() then frameCountMax = 0 end
				end
				for i = 10, 0, -1 do
					setFrameCount(frameCountMax)
					blit_sprite_hv(VGAScreenSeg, xx, yy, OPTION_SHAPES, 25, 0x9, i)
					JE_showVGA()
					if waitUntilGetInputOrElapsed() then frameCountMax = 0 end
				end
			end
		else
			JE_outTextGlow(VGAScreenSeg, 50, 135, miscText[15 - 1])
		end
	end

	local slow
	if frameCountMax ~= 0 then
		frameCountMax = 6
		slow = true
	else
		slow = false
	end
	temp2 = twoPlayerMode and 150 or 160
	JE_outTextGlow(VGAScreenSeg, 90, temp2, miscText[5 - 1])

	if not constantPlay and not (frameCountMax == 0 and slow) then
		waitUntilGetInput()
	end

	fade_black(15)
	JE_clr256(VGAScreen)
end

function JE_drawCube(screen, x_, y_, filter, brightness)
	blit_sprite_dark(screen, x_ + 4, y_ + 4, OPTION_SHAPES, 25, false)
	blit_sprite_dark(screen, x_ + 3, y_ + 3, OPTION_SHAPES, 25, false)
	blit_sprite_hv(screen, x_, y_, OPTION_SHAPES, 25, filter, brightness)
end

-- Parses a leading integer; returns success, value, remaining string.
function str_pop_int(str)
	local num, rest = str:match("^%s*([%+%-]?%d+)(.*)$")
	if num then
		return true, tonumber(num), rest
	end
	return false, 0, str
end

function JE_operation(slot)
	if not performSave then
		if saveFiles[slot - 1].level > 0 then
			gameJustLoaded = true
			JE_loadGame(slot)
			gameLoaded = true
		end
	elseif slot % 11 ~= 0 then
		local stemp = charsOf(saveFiles[slot - 1].name, 14)
		temp = 14
		while temp > 0 and stemp[temp - 1] == " " do temp = temp - 1 end

		local flash_ = 8 * 16 + 10

		JE_barShade(VGAScreen, 65, 55, 255, 155)
		local baseN = VGAScreen.n

		local quit = false
		while not quit do
			VGAScreen.n = baseN
			setFrameCount(1)

			blit_sprite(VGAScreen, 50, 50, OPTION_SHAPES, 35)

			JE_textShade(VGAScreen, 60, 55, miscText[1 - 1], 11, 4, DARKEN)
			JE_textShade(VGAScreen, 70, 70, levelName, 11, 4, DARKEN)

			local text_x = 54 + 45 - idiv(JE_textWidth(miscText[9], FONT_SHAPES), 2)
			JE_outTextAdjust(VGAScreen, text_x, 128, miscText[9], 15, -5, FONT_SHAPES, true)

			text_x = 149 + 45 - idiv(JE_textWidth(miscText[10], FONT_SHAPES), 2)
			JE_outTextAdjust(VGAScreen, text_x, 128, miscText[10], 15, -5, FONT_SHAPES, true)

			while true do
				flash_ = (flash_ == 8 * 16 + 10) and 8 * 16 + 2 or 8 * 16 + 10
				temp3 = (temp3 == 6) and 2 or 6

				local tempStr = miscText[2 - 1] .. joinChars(stemp, temp)
				JE_outText(VGAScreen, 65, 89, tempStr, 8, 3)
				tempW = 65 + JE_textWidth(tempStr, TINY_FONT)
				JE_barShade(VGAScreen, tempW + 2, 90, tempW + 6, 95)
				fill_rectangle_xy(VGAScreen, tempW + 1, 89, tempW + 5, 94, flash_)

				for i = 0, 13 do
					JE_mouseStart()
					JE_showVGA()
					JE_mouseReplace()

					waitUntilElapsed()

					if hasInput(INPUT_NO_MOTION) then break end

					setFrameCount(1)
				end

				if hasInput(INPUT_NO_MOTION) then break end
			end

			local mouseInput = mouseGetInput(INPUT_NO_MOTION)
			if mouseInput then
				if mouseInput.x > 56 and mouseInput.x < 142 and mouseInput.y > 123 and mouseInput.y < 149 then
					quit = true
					JE_saveGame(slot, joinChars(stemp, 14))
					JE_playSampleNum(S_SELECT)
				elseif mouseInput.x > 151 and mouseInput.x < 237 and mouseInput.y > 123 and mouseInput.y < 149 then
					quit = true
					JE_playSampleNum(S_SPRING)
				end
			else
				local keyboardInput = keyboardGetInput()
				if keyboardInput then
					local sc = keyboardInput.scancode
					if sc == SDL_SCANCODE_BACKSPACE or sc == SDL_SCANCODE_DELETE then
						if temp > 0 then
							temp = temp - 1
							stemp[temp] = " "
							JE_playSampleNum(S_CLICK)
						end
					elseif sc == SDL_SCANCODE_ESCAPE then
						quit = true
						JE_playSampleNum(S_SPRING)
					elseif sc == SDL_SCANCODE_RETURN then
						quit = true
						JE_saveGame(slot, joinChars(stemp, 14))
						JE_playSampleNum(S_SELECT)
					end

					local ch = keyboardInput.ch
					if (ch == 32 or fontMap[ch] ~= -1) and temp < 14 then
						stemp[temp] = string.char(ch)
						temp = temp + 1
						JE_playSampleNum(S_CURSOR)
					end
				end
			end
		end
	end
end

function JE_inGameDisplays()
	JE_textShade(VGAScreen, 30, 175, sprintf("%d", player[0].cash), 2, 4, FULL_SHADE)

	if player[0].items.special > 0 then
		blit_sprite2x2(VGAScreen, 25, 1, spriteSheet10, special[player[0].items.special].itemgraphic)
	end

	if onePlayerAction or twoPlayerMode then
		for t = 0, (onePlayerAction and 0 or 1) do
			local extra_lives = u32(player[t].lives.power - 1)

			local yy = (t == 0 and player[0].items.special > 0) and 35 or 15
			tempW = (t == 0) and 30 or 270

			if extra_lives >= 5 then
				blit_sprite2(VGAScreen, tempW, yy, spriteSheet9, 285)
				tempW = (t == 0) and 45 or 250
				JE_textShade(VGAScreen, tempW, yy + 3, sprintf("%d", extra_lives), 15, 1, FULL_SHADE)
			elseif extra_lives >= 1 then
				for i = 0, extra_lives - 1 do
					blit_sprite2(VGAScreen, tempW, yy, spriteSheet9, 285)
					tempW = tempW + ((t == 0) and 12 or -12)
				end
			end

			local stemp = (t == 0) and miscText[49 - 1] or miscText[50 - 1]

			tempW = (t == 0) and 28 or (285 - JE_textWidth(stemp, TINY_FONT))
			JE_textShade(VGAScreen, tempW, yy - 7, stemp, 2, 6, FULL_SHADE)
		end
	end

	for i = 0, 1 do
		local xx = (i == 0) and 30 or 270
		for j = player[i].superbombs, 1, -1 do
			blit_sprite2(VGAScreen, xx, 160, spriteSheet9, 304)
			xx = xx + ((i == 0) and 12 or -12)
		end
	end

	if youAreCheating then
		JE_outText(VGAScreen, 90, 170, "Cheaters always prosper.", 3, 4)
	end
end

function JE_mainKeyboardInput()
	JE_gammaCheck()

	-- In-Game Help
	if keysactive[SDL_SCANCODE_F1] then
		JE_inGameHelp()
		skipStarShowVGA = true
	end

	-- Activate Nort Ship
	if keysactive[SDL_SCANCODE_F2] and keysactive[SDL_SCANCODE_F4] and keysactive[SDL_SCANCODE_F6] and keysactive[SDL_SCANCODE_F7] and
	   keysactive[SDL_SCANCODE_F9] and keysactive[SDL_SCANCODE_BACKSLASH] and keysactive[SDL_SCANCODE_SLASH] then
		player[0].items.ship = 12
		player[0].items.special = 13
		player[0].items.weapon[FRONT_WEAPON].id = 36
		player[0].items.weapon[REAR_WEAPON].id = 37
		shipGr = 1
	end

	-- Cheating
	if not twoPlayerMode and not superTyrian and superArcadeMode == SA_NONE then
		if keysactive[SDL_SCANCODE_F2] and keysactive[SDL_SCANCODE_F3] and keysactive[SDL_SCANCODE_F6] then
			youAreCheating = not youAreCheating
			keysactive[SDL_SCANCODE_F2] = false
		end

		if keysactive[SDL_SCANCODE_F2] and keysactive[SDL_SCANCODE_F3] and (keysactive[SDL_SCANCODE_F4] or keysactive[SDL_SCANCODE_F5]) then
			for i = 0, 1 do
				player[i].armor = 0
			end
			youAreCheating = not youAreCheating
			JE_drawTextWindow(miscText[63 - 1])
		end

		if constantPlay and keysactive[SDL_SCANCODE_C] then
			youAreCheating = not youAreCheating
			keysactive[SDL_SCANCODE_C] = false
		end
	end

	if superTyrian then
		youAreCheating = false
	end

	-- DEBUG
	if keysactive[SDL_SCANCODE_F10] and keysactive[SDL_SCANCODE_BACKSPACE] then
		keysactive[SDL_SCANCODE_F10] = false
		debug_ = not debug_
		debugHist = 0
		debugHistCount = 0
		lastDebugTime = SDL_GetTicks()
	end

	-- CHEAT-SKIP LEVEL
	if keysactive[SDL_SCANCODE_F2] and keysactive[SDL_SCANCODE_F6] and (keysactive[SDL_SCANCODE_F7] or keysactive[SDL_SCANCODE_F8]) and not keysactive[SDL_SCANCODE_F9] and
	   not superTyrian and superArcadeMode == SA_NONE then
		levelTimer = true
		levelTimerCountdown = 0
		endLevel = true
		levelEnd = 40
	end

	-- pause game
	pause_pressed = pause_pressed or keysactive[SDL_SCANCODE_P]

	-- in-game setup
	ingamemenu_pressed = ingamemenu_pressed or keysactive[SDL_SCANCODE_ESCAPE]

	if keysactive[SDL_SCANCODE_BACKSPACE] then
		if keysactive[SDL_SCANCODE_NUMLOCKCLEAR] then
			superPause = not superPause
		end

		if keysactive[SDL_SCANCODE_F12] and keysactive[SDL_SCANCODE_SCROLLLOCK] then
			for t = SDL_SCANCODE_2, SDL_SCANCODE_9 do
				if keysactive[t] then
					smoothies[t - SDL_SCANCODE_2] = not smoothies[t - SDL_SCANCODE_2]
				end
			end
			if keysactive[SDL_SCANCODE_0] then
				smoothies[8] = not smoothies[8]
			end
		elseif keysactive[SDL_SCANCODE_MINUS] then
			if levelFilter == -99 then
				levelFilter = 0
			else
				levelFilter = levelFilter + 1
				if levelFilter == 16 then
					levelFilter = -99
				end
			end
		elseif keysactive[SDL_SCANCODE_1] then
			fastPlay = fastPlay + 1
			if fastPlay > 2 then fastPlay = 0 end
			keysactive[SDL_SCANCODE_1] = false
			JE_setNewGameSpeed()
		end

		if keysactive[SDL_SCANCODE_SCROLLLOCK] then
			play_song(mt_rand() % MUSIC_NUM)
		end
	end
end

function JE_pauseGame()
	mouseSetRelative(false)

	local done = false

	local temp_surface = VGAScreen
	VGAScreen = VGAScreenSeg

	if not superPause then
		JE_dString(VGAScreenSeg, 120, 90, miscText[22], FONT_SHAPES)
		VGAScreen = VGAScreenSeg
		JE_showVGA()
	end

	set_volume(idiv(tyrMusicVolume, 2), fxVolume)

	repeat
		setFrameCount(1)

		waitUntilHasInputOrElapsed()

		local keyboardInput = keyboardGetInput()
		local ok = false
		if keyboardInput then
			local sc = keyboardInput.scancode
			ok = sc ~= SDL_SCANCODE_LCTRL and sc ~= SDL_SCANCODE_RCTRL and sc ~= SDL_SCANCODE_LALT and sc ~= SDL_SCANCODE_RALT
		end
		if ok or (not keyboardInput and mouseGetInput(INPUT_NO_MOTION)) then
			keysactive[SDL_SCANCODE_P] = false
			done = true
		end
	until done

	set_volume(tyrMusicVolume, fxVolume)

	VGAScreen = temp_surface

	mouseSetRelative(true)
end
