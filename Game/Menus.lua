--[[
 WowTyrian2k: a World of Warcraft port of OpenTyrian
 Copyright (C) The OpenTyrian Development Team
 Lua port Copyright (C) 2026 voetre
 Licensed under the GNU General Public License v2 or later (see COPYING).

 menus.c
]]
local _, ns = ...
setfenv(1, ns.G)

SDLK_g = 103
SDLK_RIGHTBRACKET = 93
local lordKeySyms = { [0] = 108, 111, 114, 100 }

-- Generic vertical menu interaction shared by the three selection screens.
-- Returns action, cancel, selectedIndex.
local function handleMenuInput(count, selectedIndex, itemX, itemW, yMenuItems, dyMenuItems, hMenuItem)
	local action, cancel = false, false
	local keyboardInput

	local mouseInput = mouseGetInput(INPUT_ANY)
	if mouseInput then
		for i = 0, count - 1 do
			local xMenuItem = itemX(i)
			if mouseInput.x >= xMenuItem and mouseInput.x < xMenuItem + itemW[i] then
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
			cancel = true
		end
	else
		keyboardInput = keyboardGetInput()
		if keyboardInput then
			local sc = keyboardInput.scancode
			if sc == SDL_SCANCODE_UP then
				JE_playSampleNum(S_CURSOR)
				selectedIndex = (selectedIndex == 0) and count - 1 or selectedIndex - 1
			elseif sc == SDL_SCANCODE_DOWN then
				JE_playSampleNum(S_CURSOR)
				selectedIndex = (selectedIndex == count - 1) and 0 or selectedIndex + 1
			elseif sc == SDL_SCANCODE_SPACE or sc == SDL_SCANCODE_RETURN then
				action = true
			elseif sc == SDL_SCANCODE_ESCAPE then
				JE_playSampleNum(S_SPRING)
				cancel = true
			end
		end
	end

	return action, cancel, selectedIndex, keyboardInput
end

function gameplaySelect()
	if not shopSpriteSheet.data then
		JE_loadCompShapes(shopSpriteSheet, '1')
	end

	local restart = true
	-- Only the single-player modes are offered (no 2-player or network play).
	local menuItemsCount = 2
	local selectedIndex = 0

	local xCenter = 160
	local yMenuHeader = 20
	local yMenuItems = 54
	local dyMenuItems = 24
	local hMenuItem = 13
	local wMenuItem = newArray(menuItemsCount, 0)

	while true do
		setFrameCount(1)

		if restart then
			JE_loadPic(VGAScreen2, 2, false)
			drawFontHvShadowAligned(VGAScreen2, xCenter, yMenuHeader, gameplay_name[0], FONT_LARGE, ALIGN_CENTER, 15, -3, false, 2)
		end

		surfaceCopy(VGAScreen, VGAScreen2)

		for i = 0, menuItemsCount - 1 do
			local text = gameplay_name[i + 1]
			wMenuItem[i] = JE_textWidth(text, FONT_NORMAL)
			local x_ = xCenter - idiv(wMenuItem[i], 2)
			local y_ = yMenuItems + dyMenuItems * i
			local selected = i == selectedIndex
			drawFontHvShadow(VGAScreen, x_, y_, text, FONT_NORMAL, 15, -4 + (selected and 2 or 0), false, 2)
		end

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

		local action, cancel
		action, cancel, selectedIndex = handleMenuInput(menuItemsCount, selectedIndex,
			function(i) return xCenter - idiv(wMenuItem[i], 2) end, wMenuItem, yMenuItems, dyMenuItems, hMenuItem)

		if action then
			JE_playSampleNum(S_SELECT)
			fade_black(10)
			onePlayerAction = selectedIndex == 1
			twoPlayerMode = false
			return true
		end

		if cancel then
			fade_black(15)
			return false
		end
	end
end

function episodeSelect()
	if not shopSpriteSheet.data then
		JE_loadCompShapes(shopSpriteSheet, '1')
	end

	local restart = true
	local menuItemsCount = EPISODE_AVAILABLE
	local selectedIndex = 0

	local xCenter = 160
	local yMenuHeader = 20
	local xMenuItem = 20
	local yMenuItems = 50
	local dyMenuItems = 30
	local hMenuItem = 13
	local wMenuItem = newArray(menuItemsCount, 0)

	while true do
		setFrameCount(1)

		if restart then
			JE_loadPic(VGAScreen2, 2, false)
			drawFontHvShadowAligned(VGAScreen2, xCenter, yMenuHeader, episode_name[0], FONT_LARGE, ALIGN_CENTER, 15, -3, false, 2)
		end

		surfaceCopy(VGAScreen, VGAScreen2)

		for i = 0, menuItemsCount - 1 do
			local text = episode_name[i + 1]
			wMenuItem[i] = JE_textWidth(text, FONT_NORMAL)
			local y_ = yMenuItems + dyMenuItems * i
			local selected = i == selectedIndex
			local disabled = not episodeAvail[i]
			drawFontHvShadow(VGAScreen, xMenuItem, y_, text, FONT_NORMAL, 15, -4 + (selected and 2 or 0) + (disabled and -4 or 0), false, 2)
		end

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

		local action, cancel
		action, cancel, selectedIndex = handleMenuInput(menuItemsCount, selectedIndex,
			function(i) return xMenuItem end, wMenuItem, yMenuItems, dyMenuItems, hMenuItem)

		if action then
			if episodeAvail[selectedIndex] then
				JE_playSampleNum(S_SELECT)
				fade_black(10)
				JE_initEpisode(selectedIndex + 1)
				initial_episode_num = episodeNum
				return true
			else
				JE_playSampleNum(S_SPRING)
			end
		end

		if cancel then
			fade_black(15)
			return false
		end
	end
end

function difficultySelect()
	if not shopSpriteSheet.data then
		JE_loadCompShapes(shopSpriteSheet, '1')
	end

	local restart = true
	local menuItemsCount = 6
	local menuItemsVisibleCount = menuItemsCount - 3
	local selectedIndex = 1
	local lordProgress = 0

	local xCenter = 160
	local yMenuHeader = 20
	local yMenuItems = 54
	local dyMenuItems = 24
	local hMenuItem = 13
	local wMenuItem = newArray(menuItemsCount, 0)

	while true do
		setFrameCount(1)

		if restart then
			JE_loadPic(VGAScreen2, 2, false)
			drawFontHvShadowAligned(VGAScreen2, xCenter, yMenuHeader, difficulty_name[0], FONT_LARGE, ALIGN_CENTER, 15, -3, false, 2)
		end

		surfaceCopy(VGAScreen, VGAScreen2)

		for i = 0, menuItemsVisibleCount - 1 do
			local text = difficulty_name[i + 1]
			wMenuItem[i] = JE_textWidth(text, FONT_NORMAL)
			local x_ = xCenter - idiv(wMenuItem[i], 2)
			local y_ = yMenuItems + dyMenuItems * i
			local selected = i == selectedIndex
			drawFontHvShadow(VGAScreen, x_, y_, text, FONT_NORMAL, 15, -4 + (selected and 2 or 0), false, 2)
		end

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

		local action, cancel, keyboardInput
		action, cancel, selectedIndex, keyboardInput = handleMenuInput(menuItemsVisibleCount, selectedIndex,
			function(i) return xCenter - idiv(wMenuItem[i], 2) end, wMenuItem, yMenuItems, dyMenuItems, hMenuItem)

		if keyboardInput then
			if menuItemsVisibleCount == 3 then
				if band(keyboardInput.mod, KMOD_SHIFT) ~= 0 and keyboardInput.sym == SDLK_g then
					menuItemsVisibleCount = 4
				end
			elseif menuItemsVisibleCount == 4 then
				if band(keyboardInput.mod, KMOD_SHIFT) ~= 0 and keyboardInput.sym == SDLK_RIGHTBRACKET then
					menuItemsVisibleCount = 5
				end
			elseif menuItemsVisibleCount == 5 then
				local all = true
				for i = 0, 3 do
					if not lordKeySymsDown[i] then all = false break end
				end
				if all then menuItemsVisibleCount = 6 end

				if lordProgress < 4 and keyboardInput.sym == lordKeySyms[lordProgress] then
					lordProgress = lordProgress + 1
					if lordProgress == 4 then menuItemsVisibleCount = 6 end
				else
					lordProgress = 0
				end
			end
		end

		if action then
			JE_playSampleNum(S_SELECT)
			if selectedIndex == 0 then difficultyLevel = DIFFICULTY_EASY
			elseif selectedIndex == 1 then difficultyLevel = DIFFICULTY_NORMAL
			elseif selectedIndex == 2 then difficultyLevel = DIFFICULTY_HARD
			elseif selectedIndex == 3 then difficultyLevel = DIFFICULTY_IMPOSSIBLE
			elseif selectedIndex == 4 then difficultyLevel = DIFFICULTY_SUICIDE
			elseif selectedIndex == 5 then difficultyLevel = DIFFICULTY_ZINGLON
			end
			fade_black(10)
			return true
		end

		if cancel then
			fade_black(15)
			return false
		end
	end
end
