--[[
 WowTyrian2k: a World of Warcraft port of OpenTyrian
 Copyright (C) The OpenTyrian Development Team
 Lua port Copyright (C) 2026 voetre
 Licensed under the GNU General Public License v2 or later (see COPYING).

 tyrian2.c (part 2): level loading, title screen, enemies and events
]]
local _, ns = ...
setfenv(1, ns.G)

local strbyte, strsub = string.byte, string.sub

local function readEpisodeString(file)
	return readEncryptedString(file, 256)
end

-- Builds the screen for the picture pan/slide transitions.
local function panFrame(old, pic, mode, z)
	surfaceClear(VGAScreen)
	local push = ns.pushOp
	if mode == 'U' then
		push(VGAScreen, K_SURF, old, 0, 0, 0, 320, 200 - (z + 1), 0, z + 1, false)
		push(VGAScreen, K_PIC, pic, 0, 0, 320, z + 1, 0, 199 - z, 512, 256)
	elseif mode == 'V' then
		push(VGAScreen, K_SURF, old, 0, 0, 0, 320, 200, 0, 0, false)
		if z > 0 then
			push(VGAScreen, K_PIC, pic, 0, 200 - z, 320, z - 1, 0, 0, 512, 256)
		end
	elseif mode == 'R' then
		push(VGAScreen, K_SURF, old, 0, z, 0, 319 - z, 200, 0, 0, false)
		push(VGAScreen, K_PIC, pic, 320 - z, 0, z, 200, 0, 0, 512, 256)
	end
end

local function doPan(mode, picId)
	surfaceCopy(VGAScreen2, VGAScreen)

	JE_loadPic(VGAScreen, picId, false)
	local pic = ns.gfxmeta.pics[picId]

	local last = (mode == 'R') and 318 or 199
	for z = 0, last do
		if ESCPressed then break end

		setFrameCount(1)

		panFrame(VGAScreen2, pic, mode, z)

		JE_showVGA()

		if waitUntilGetInputOrElapsed() then break end
	end

	pushPic(VGAScreen, pic, 0, 0, 320, 200, 0, 0)
end

local tileRefCache = {}
local function tileRef(tileset, key, z)
	local c = tileRefCache[key]
	if not c then
		c = {}
		tileRefCache[key] = c
	end
	local r = c[z]
	if not r then
		r = { tileset, z }
		c[z] = r
	end
	return r
end
mapTileRef = tileRef   -- shared with Game/LevelGen.lua

function JE_loadMap()
	local mapSh = { [0] = {}, {}, {} }
	local ref = { [0] = {}, {}, {} }

	lastCubeMax = cubeMax

	songBuy = DEFAULT_SONG_BUY

	saveLevel = mainLevel

	-- new_game:
	while true do
		galagaMode = false
		useLastBank = false
		extraGame = false
		haltGame = false

		gameLoaded = false

		local restartNewGame = false

		if not playDemo and not genLevel then
			repeat
				local episodeFile = dataFileOpen(episodeFilename)

				jumpSection = false
				loadLevelOk = false

				-- Seek Section # Mainlevel
				local i = 0
				while i < mainLevel do
					local s = readEpisodeString(episodeFile)
					if strsub(s, 1, 1) == '*' then
						i = i + 1
					end
					if episodeFile.error then break end
				end

				ESCPressed = false

				repeat
					if gameLoaded then
						if mainLevel == 0 then
							return
						else
							restartNewGame = true
							break
						end
					end

					local s = readEpisodeString(episodeFile)
					if episodeFile.error and s == "" then
						logError("Unexpected end of episode file")
						mainLevel = 0
						return
					end

					if strsub(s, 1, 1) == ']' then
						local c = strsub(s, 2, 2)

						if c == 'A' then
							playAnim("tyrend.anm", 0, 7)

						elseif c == 'G' then
							mapOrigin = atoi(s, 4)
							mapPNum = atoi(s, 7)
							for k = 0, mapPNum - 1 do
								mapPlanet[k] = atoi(s, 1 + (k + 1) * 8)
								mapSection[k] = atoi(s, 4 + (k + 1) * 8)
							end

						elseif c == '?' then
							temp = atoi(s, 4)
							if temp > 4 then temp = 4 end
							for k = 0, temp - 1 do
								cubeList[k] = atoi(s, 3 + (k + 1) * 4)
							end
							if cubeMax > temp then
								cubeMax = temp
							end

						elseif c == '!' then
							cubeMax = atoi(s, 4)
							if cubeMax > 4 then cubeMax = 4 end

						elseif c == '+' then
							temp = atoi(s, 4)
							cubeMax = cubeMax + temp
							if cubeMax > 4 then cubeMax = 4 end

						elseif c == 'g' then
							galagaMode = true

							structAssign(player[1].items, player[0].items)
							player[1].items.weapon[REAR_WEAPON].id = 15
							for k = 0, 1 do
								player[1].items.sidekick[k] = 0
							end

						elseif c == 'x' then
							extraGame = true

						elseif c == 'e' then
							doNotSaveBackup = true
							constantDie = false
							onePlayerAction = true
							superTyrian = true
							twoPlayerMode = false

							player[0].cash = 0

							local it = player[0].items
							it.ship = 13
							it.weapon[FRONT_WEAPON].id = 39
							it.weapon[REAR_WEAPON].id = 0
							it.sidekick[0] = 0
							it.sidekick[1] = 0
							it.generator = 2
							it.shield = 4
							it.special = 0

							it.weapon[FRONT_WEAPON].power = 3
							it.weapon[REAR_WEAPON].power = 1

						elseif c == 'J' then
							temp = atoi(s, 3)
							mainLevel = temp
							jumpSection = true

						elseif c == '2' then
							temp = atoi(s, 3)
							if twoPlayerMode or onePlayerAction then
								mainLevel = temp
								jumpSection = true
							end

						elseif c == 'w' then
							temp = atoi(s, 3)
							if player[0].items.ship == 13 then
								mainLevel = temp
								jumpSection = true
							end

						elseif c == 't' then
							temp = atoi(s, 3)
							if levelTimer and levelTimerCountdown == 0 then
								mainLevel = temp
								jumpSection = true
							end

						elseif c == 'l' then
							temp = atoi(s, 3)
							if not all_players_alive() then
								mainLevel = temp
								jumpSection = true
							end

						elseif c == 's' then
							saveLevel = mainLevel

						elseif c == 'b' then
							JE_saveGame(11, "LAST LEVEL    ")

						elseif c == 'i' then
							temp = atoi(s, 3)
							songBuy = temp - 1

						elseif c == 'I' then
							for k = 0, 8 do
								fillArray(itemAvail[k], 10, 0)
							end

							for k = 0, 8 do
								local line = readEpisodeString(episodeFile)
								local buf = (#line > 8) and strsub(line, 9) or ""

								local j = 0
								while true do
									local ok, val, rest = str_pop_int(buf)
									if not ok then break end
									buf = rest
									itemAvail[k][j] = val
									j = j + 1
								end
								itemAvailMax[k] = j
							end

							JE_itemScreen()

						elseif c == 'L' then
							nextLevel = atoi(s, 9)
							levelName = strsub(strlcpy(strsub(s, 14), 10), 1)
							levelSong = atoi(s, 22)
							if nextLevel == 0 then
								nextLevel = mainLevel + 1
							end
							lvlFileNum = atoi(s, 25)
							loadLevelOk = true
							bonusLevelCurrent = (#s > 28) and (strsub(s, 29, 29) == '$')
							normalBonusLevelCurrent = (#s > 27) and (strsub(s, 28, 28) == '$')
							gameJustLoaded = false

						elseif c == '@' then
							useLastBank = not useLastBank

						elseif c == 'Q' then
							ESCPressed = false
							temp = secretHint + (mt_rand() % 3) * 3

							if twoPlayerMode then
								for k = 0, 1 do
									levelWarningText[k] = sprintf("%s %d", miscText[40 + k], player[k].cash)
								end
								levelWarningText[2] = ""
								levelWarningLines = 3
							else
								levelWarningText[0] = sprintf("%s %d", miscText[37], JE_totalScore(player[0]))
								levelWarningText[1] = ""
								levelWarningLines = 2
							end

							-- Skip to hint.
							for k = 0, temp - 2 do
								while true do
									local line = readEpisodeString(episodeFile)
									if strsub(line, 1, 1) == '#' or episodeFile.error then break end
								end
							end

							-- Read hint.
							while true do
								local line = readEpisodeString(episodeFile)
								if strsub(line, 1, 1) == '#' or episodeFile.error then break end
								if levelWarningLines < 10 then
									levelWarningText[levelWarningLines] = strlcpy(line, 61)
									levelWarningLines = levelWarningLines + 1
								end
							end

							frameCountMax = 4
							if not constantPlay then
								JE_displayText()
							end

							fade_black(15)

							JE_nextEpisode()

							if jumpBackToEpisode1 and not twoPlayerMode then
								JE_loadPic(VGAScreen, 1, false)
								JE_clr256(VGAScreen)

								if superTyrian then
									superArcadeMode = (initialDifficulty == DIFFICULTY_ZINGLON) and 8 or 1
								end

								if superArcadeMode < SA_ENGAGE then
									if SANextShip[superArcadeMode] == SA_ENGAGE then
										local buffer = sprintf("%s %s", miscTextB[4], pName[0])
										JE_dString(VGAScreen, JE_fontCenter(buffer, FONT_SHAPES), 100, buffer, FONT_SHAPES)

										buffer = sprintf("Or play... %s", specialName[7])
										JE_dString(VGAScreen, 80, 180, buffer, SMALL_FONT_SHAPES)
									else
										JE_dString(VGAScreen, JE_fontCenter(superShips[0], FONT_SHAPES), 30, superShips[0], FONT_SHAPES)
										local nm = superShips[SANextShip[superArcadeMode]]
										JE_dString(VGAScreen, JE_fontCenter(nm, SMALL_FONT_SHAPES), 100, nm, SMALL_FONT_SHAPES)
									end

									if SANextShip[superArcadeMode] < SA_NORTSHIPZ then
										blit_sprite2x2(VGAScreen, 148, 70, spriteSheet9, ships[SAShip[SANextShip[superArcadeMode] - 1]].shipgraphic)
									elseif SANextShip[superArcadeMode] == SA_NORTSHIPZ then
										trentWin = true
									end

									local buffer = sprintf("Type %s at Title", specialName[SANextShip[superArcadeMode] - 1])
									JE_dString(VGAScreen, JE_fontCenter(buffer, SMALL_FONT_SHAPES), 160, buffer, SMALL_FONT_SHAPES)
									JE_showVGA()

									fade_palette(colors, 50, 0, 255)

									if not constantPlay then
										waitUntilGetInput()
									end
								end

								jumpSection = true

								if superTyrian then
									fade_black(10)
									mainLevel = 0
									return
								end
							end

						elseif c == 'P' then
							if not constantPlay then
								local tempX = atoi(s, 3)
								if tempX > 900 then
									copyPalette(colors, palettes[pcxpal[tempX - 1 - 900]])
									JE_clr256(VGAScreen)
									JE_showVGA()
									fade_palette(colors, 1, 0, 255)
								else
									if tempX == 0 then
										JE_loadPCX("tshp2.pcx")
									else
										JE_loadPic(VGAScreen, tempX, false)
									end
									JE_showVGA()
									fade_palette(colors, 10, 0, 255)
								end
							end

						elseif c == 'U' or c == 'V' or c == 'R' then
							if not constantPlay then
								doPan(c, atoi(s, 3))
							end

						elseif c == 'C' then
							fade_black(10)
							JE_clr256(VGAScreen)
							JE_showVGA()
							copyPalette(colors, palettes[7])
							set_palette(colors, 0, 255)

						elseif c == 'B' then
							fade_black(10)

						elseif c == 'F' then
							fade_white(100)
							fade_black(30)
							JE_clr256(VGAScreen)
							JE_showVGA()

						elseif c == 'W' then
							if not constantPlay then
								if not ESCPressed then
									warningCol = 14 * 16 + 5
									warningColChange = 1
									warningSoundDelay = 0
									levelWarningDisplay = (strsub(s, 3, 3) == 'y')
									levelWarningLines = 0
									frameCountMax = atoi(s, 4)
									setFrameCount2(6)
									warningRed = idiv(frameCountMax, 10) ~= 0
									frameCountMax = frameCountMax % 10

									while true do
										local line = readEpisodeString(episodeFile)
										if strsub(line, 1, 1) == '#' or episodeFile.error then break end
										if levelWarningLines < 10 then
											levelWarningText[levelWarningLines] = strlcpy(line, 61)
											levelWarningLines = levelWarningLines + 1
										end
									end

									JE_displayText()
								end
							end

						elseif c == 'H' then
							if initialDifficulty < DIFFICULTY_HARD then
								mainLevel = atoi(s, 4)
								jumpSection = true
							end

						elseif c == 'h' then
							if initialDifficulty > DIFFICULTY_NORMAL then
								readEpisodeString(episodeFile)
							end

						elseif c == 'S' then
							-- network only

						elseif c == 'n' then
							ESCPressed = false

						elseif c == 'M' then
							temp = atoi(s, 3)
							play_song(temp - 1)
						end
					end
				until loadLevelOk or jumpSection

				if restartNewGame then break end
			until loadLevelOk
		end

		if not restartNewGame then break end
	end

	if playDemo then
		beginPlayDemo()
	else
		fade_black(50)
		if recordDemo then
			beginRecordDemo()
		end
	end

	local levelFile = dataFileOpen(levelFilename)
	fileSetPosition(levelFile, lvlPos[(lvlFileNum - 1) * 2])

	local char_mapFile = fileReadChar(levelFile)
	local char_shapeFile = fileReadChar(levelFile)
	mapX = fileReadU16(levelFile)
	mapX2 = fileReadU16(levelFile)
	mapX3 = fileReadU16(levelFile)

	levelEnemyMax = fileReadU16(levelFile)
	fileReadU16Array(levelFile, levelEnemy, levelEnemyMax)

	maxEvent = fileReadU16(levelFile)
	if maxEvent >= EVENT_MAXIMUM then
		logFatal("Level has too many events.")
	end
	local xx = 0
	while xx < maxEvent do
		local ev = eventRec[xx]
		ev.eventtime = fileReadU16(levelFile)
		ev.eventtype = fileReadU8(levelFile)
		ev.eventdat = fileReadS16(levelFile)
		ev.eventdat2 = fileReadS16(levelFile)
		ev.eventdat3 = fileReadS8(levelFile)
		ev.eventdat5 = fileReadS8(levelFile)
		ev.eventdat6 = fileReadS8(levelFile)
		ev.eventdat4 = fileReadU8(levelFile)
		xx = xx + 1
	end
	eventRec[xx].eventtime = 65500

	for k = 0, 2 do
		fileReadU16BEArray(levelFile, mapSh[k], 128)
	end

	local key = string.lower(char_shapeFile)
	local tileset = ns.gfxmeta.tiles[key]
	if not tileset then
		logFatal("Missing tile set '%s'", key)
	end

	-- Reverse index of map shape lookup tables
	for k = 0, 2 do
		local limit = (k == 0) and 71 or ((k == 1) and 70 or 69)
		for x_ = 0, 71 do
			local zz = mapSh[k][x_] - 1
			if zz >= 0 and zz < 600 then
				local blank = tileset.blank[zz + 1] == 1
				if k == 0 then
					ref[0][x_] = tileRef(tileset, key, zz)
				elseif x_ <= limit and not blank then
					ref[k][x_] = tileRef(tileset, key, zz)
				else
					ref[k][x_] = false
				end
			else
				ref[k][x_] = false
			end
		end
	end

	local mm1, mm2, mm3 = {}, {}, {}
	megaData1.mainmap = mm1
	megaData2.mainmap = mm2
	megaData3.mainmap = mm3

	local mapBuf = fileReadString(levelFile, 14 * 300)
	for i = 0, 14 * 300 - 1 do
		mm1[i] = ref[0][strbyte(mapBuf, i + 1) or 0] or false
	end

	mapBuf = fileReadString(levelFile, 14 * 600)
	for i = 0, 14 * 600 - 1 do
		mm2[i] = ref[1][strbyte(mapBuf, i + 1) or 0] or false
	end

	mapBuf = fileReadString(levelFile, 15 * 600)
	for i = 0, 15 * 600 - 1 do
		mm3[i] = ref[2][strbyte(mapBuf, i + 1) or 0] or false
	end

	if genLevel then
		LevelGen.loadMap()
	end
end

function titleScreen()
	menuText[4] = "Setup"

	if not shopSpriteSheet.data then
		JE_loadCompShapes(shopSpriteSheet, '1')
	end

	local restart = true

	local selectedIndex = 0
	local specialNameProgress = newArray(SA_ENGAGE, 0)

	local xCenter = 160
	local yMenuItems = 104
	local hMenuItem = 13
	local menuCount = 7
	local wMenuItem = newArray(menuCount, 0)

	while true do
		setFrameCount(1)

		if restart then
			play_song(SONG_TITLE)

			JE_loadPic(VGAScreen, 4, false)

			drawFontHvShadow(VGAScreen, 2, 192, "WowTyrian2k", FONT_SMALL, 15, 0, false, 1)

			if moveTyrianLogoUp then
				surfaceCopy(VGAScreen2, VGAScreen)

				blit_sprite(VGAScreenSeg, 11, 62, PLANET_SHAPES, 146)

				fade_palette(colors, 10, 0, 255 - 16)

				for yy = 60, 4, -2 do
					setFrameCount(2)

					surfaceCopy(VGAScreen, VGAScreen2)

					blit_sprite(VGAScreenSeg, 11, yy, PLANET_SHAPES, 146)

					JE_showVGA()

					waitUntilElapsed()
				end

				moveTyrianLogoUp = false
			else
				blit_sprite(VGAScreenSeg, 11, 4, PLANET_SHAPES, 146)

				fade_palette(colors, 10, 0, 255 - 16)
			end

			for i = 0, menuCount - 1 do
				local text = menuText[i]
				wMenuItem[i] = JE_textWidth(text, FONT_NORMAL)
				local x_ = xCenter - idiv(wMenuItem[i], 2)
				local y_ = yMenuItems + hMenuItem * i

				drawFontHv(VGAScreen, x_ - 1, y_ - 1, text, FONT_NORMAL, 15, -10)
				drawFontHv(VGAScreen, x_ + 1, y_ + 1, text, FONT_NORMAL, 15, -10)
				drawFontHv(VGAScreen, x_ + 1, y_ - 1, text, FONT_NORMAL, 15, -10)
				drawFontHv(VGAScreen, x_ - 1, y_ + 1, text, FONT_NORMAL, 15, -10)
				drawFontHv(VGAScreen, x_, y_, text, FONT_NORMAL, 15, -3)
			end

			surfaceCopy(VGAScreen2, VGAScreen)

			mouseCursor = MOUSE_POINTER_NORMAL

			fade_palette(colors, 20, 255 - 16 + 1, 255)

			restart = false
		end

		surfaceCopy(VGAScreen, VGAScreen2)

		drawFontHvAligned(VGAScreen, 160, yMenuItems + hMenuItem * selectedIndex, menuText[selectedIndex], FONT_NORMAL, ALIGN_CENTER, 15, -1)

		JE_mouseStartFilter(0xF0)
		JE_showVGA()
		JE_mouseReplace()

		local idleStartTick = SDL_GetTicks()

		local startDemo = false
		while true do
			if SDL_GetTicks() - idleStartTick > 30000 then
				startDemo = true
				break
			end

			waitUntilElapsed()

			if hasInput(INPUT_ANY) then break end

			setFrameCount(1)
		end

		if startDemo then
			fade_black(15)
			playDemo = true
			return true
		end

		local action, done = false, false

		local mouseInput = mouseGetInput(INPUT_ANY)
		if mouseInput then
			for i = 0, menuCount - 1 do
				local xMenuItem = xCenter - idiv(wMenuItem[i], 2)
				if mouseInput.x >= xMenuItem and mouseInput.x < xMenuItem + wMenuItem[i] then
					local yMenuItem = yMenuItems + hMenuItem * i
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
					selectedIndex = (selectedIndex == 0) and menuCount - 1 or selectedIndex - 1
				elseif sc == SDL_SCANCODE_DOWN then
					JE_playSampleNum(S_CURSOR)
					selectedIndex = (selectedIndex == menuCount - 1) and 0 or selectedIndex + 1
				elseif sc == SDL_SCANCODE_SPACE or sc == SDL_SCANCODE_RETURN then
					action = true
				elseif sc == SDL_SCANCODE_ESCAPE then
					JE_playSampleNum(S_SPRING)
					done = true
				end

				local sym = keyboardInput.sym
				local ch = (sym >= 0 and sym < 0x80) and toupperByte(sym) or 0

				-- WoW also queues a text (OnChar) event for each key press;
				-- those carry no key and must not reset the code progress.
				for i = 0, (keyboardInput.scancode == -1) and -1 or SA_ENGAGE - 1 do
					local name = specialName[i]
					if specialNameProgress[i] >= 9 or ch ~= strbyte(name, specialNameProgress[i] + 1) then
						specialNameProgress[i] = 0
					else
						specialNameProgress[i] = specialNameProgress[i] + 1

						if specialNameProgress[i] == #name then
							if i + 1 == SA_DESTRUCT then
								fade_black(10)

								loadDestruct = true
								return true
							elseif i + 1 == SA_ENGAGE then
								JE_playSampleNum(V_DATA_CUBE)

								JE_whoa()
								set_colors({ 0, 0, 0 }, 0, 255)

								newSuperTyrianGame()
								return true
							else
								fade_black(10)

								if newSuperArcadeGame(i) then
									return true
								end

								restart = true
							end
						end
					end
				end
			end
		end

		if action then
			JE_playSampleNum(S_SELECT)

			if selectedIndex == 0 then
				fade_black(15)
				if newGame() then
					return true
				end
				restart = true
			elseif selectedIndex == 1 then
				fade_black(15)
				if JE_loadScreen() then
					return true
				end
				restart = true
			elseif selectedIndex == 2 then
				fade_black(15)
				JE_highScoreScreen()
				restart = true
			elseif selectedIndex == 3 then
				fade_black(15)
				JE_helpSystem(1)
				restart = true
			elseif selectedIndex == 4 then
				fade_black(15)
				setupMenu()
				restart = true
			elseif selectedIndex == 5 then
				fade_black(15)
				playDemo = true
				return true
			elseif selectedIndex == 6 then
				fade_black(15)
				return false
			end
		end

		if done then
			fade_black(15)
			return false
		end
	end
end

function newGame()
	if gameplaySelect() then
		if episodeSelect() and difficultySelect() then
			gameLoaded = true
		end

		initialDifficulty = difficultyLevel

		if onePlayerAction then
			player[0].cash = 0
			player[0].items.ship = 8
		elseif twoPlayerMode then
			for i = 0, 1 do
				player[i].cash = 0
			end

			player[0].items.ship = 11

			difficultyLevel = difficultyLevel + 1

			inputDevice[0] = 1
			inputDevice[1] = 2
		elseif richMode then
			player[0].cash = 1000000
		elseif gameLoaded then
			local initial_cash = { [0] = 10000, 15000, 20000, 30000 }
			player[0].cash = initial_cash[episodeNum - 1]
		end
	end

	return gameLoaded
end

function newSuperArcadeGame(i)
	player[0].items.ship = SAShip[i]

	if episodeSelect() and difficultySelect() then
		JE_loadPic(VGAScreen, 1, false)
		JE_clr256(VGAScreen)
		JE_dString(VGAScreen, JE_fontCenter(superShips[0], FONT_SHAPES), 30, superShips[0], FONT_SHAPES)
		JE_dString(VGAScreen, JE_fontCenter(superShips[i + 1], SMALL_FONT_SHAPES), 100, superShips[i + 1], SMALL_FONT_SHAPES)
		tempW = ships[player[0].items.ship].shipgraphic
		if tempW ~= 1 then
			blit_sprite2x2(VGAScreen, 148, 70, spriteSheet9, tempW)
		end

		JE_showVGA()
		fade_palette(colors, 50, 0, 255)

		waitUntilGetInput()

		twoPlayerMode = false
		onePlayerAction = true
		superArcadeMode = i + 1
		gameLoaded = true
		difficultyLevel = difficultyLevel + 1
		initialDifficulty = difficultyLevel

		player[0].cash = 0

		player[0].items.weapon[FRONT_WEAPON].id = SAWeapon[i][0]
		player[0].items.special = SASpecialWeapon[i]
		if superArcadeMode == SA_NORTSHIPZ then
			for k = 0, 1 do
				player[0].items.sidekick[k] = 24
			end
		end

		fade_black(10)
	end

	return gameLoaded
end

function newSuperTyrianGame()
	initialDifficulty = keysactive[SDL_SCANCODE_SCROLLLOCK] and DIFFICULTY_SUICIDE or DIFFICULTY_ZINGLON

	JE_clr256(VGAScreen)
	JE_outText(VGAScreen, 10, 10, "Cheat codes have been disabled.", 15, 4)
	if initialDifficulty == DIFFICULTY_ZINGLON then
		JE_outText(VGAScreen, 10, 20, "Difficulty level has been set to Lord of Game.", 15, 4)
	else
		JE_outText(VGAScreen, 10, 20, "Difficulty level has been set to Suicide.", 15, 4)
	end
	JE_outText(VGAScreen, 10, 30, "It is imperative that you discover the special codes.", 15, 4)
	if initialDifficulty == DIFFICULTY_ZINGLON then
		JE_outText(VGAScreen, 10, 40, "(Next time, for an easier challenge hold down SCROLL LOCK.)", 15, 4)
	end
	JE_outText(VGAScreen, 10, 60, "Prepare to play...", 15, 4)

	local buf = sprintf("%s %s", miscTextB[4], pName[0])
	JE_dString(VGAScreen, JE_fontCenter(buf, FONT_SHAPES), 110, buf, FONT_SHAPES)

	play_song(16)
	JE_playSampleNum(V_DANGER)

	JE_showVGA()
	fade_palette(colors, 10, 0, 255)

	while true do
		waitUntilHasInput(INPUT_NO_MOTION)

		local keyboardInput = keyboardGetInput()
		if (keyboardInput and keyboardInput.scancode ~= SDL_SCANCODE_SCROLLLOCK) or
		   (not keyboardInput and mouseGetInput(INPUT_NO_MOTION)) then
			break
		end
	end

	JE_initEpisode(1)
	constantDie = false
	superTyrian = true
	onePlayerAction = true
	gameLoaded = true
	difficultyLevel = initialDifficulty

	player[0].cash = 0

	player[0].items.ship = 13
	player[0].items.weapon[FRONT_WEAPON].id = 39

	fade_black(10)
end

function intro_logos()
	moveTyrianLogoUp = true

	surfaceClear(VGAScreen)

	fade_white(25)

	JE_loadPic(VGAScreen, 10, false)
	JE_showVGA()

	fade_palette(colors, 25, 0, 255)

	setFrameCount(200)
	waitUntilGetInputOrElapsed()

	fade_black(10)

	JE_loadPic(VGAScreen, 12, false)
	JE_showVGA()

	fade_palette(colors, 10, 0, 255)

	setFrameCount(200)
	waitUntilGetInputOrElapsed()

	fade_black(10)
end

function JE_displayText()
	local tempY = 55
	if warningRed then
		tempY = 2
	end
	for t = 0, levelWarningLines - 1 do
		if not ESCPressed then
			JE_outCharGlow(10, tempY, levelWarningText[t])

			if haltGame then
				JE_tyrianHalt(5)
			end

			tempY = tempY + 10
		end
	end

	local slow
	if frameCountMax ~= 0 then
		frameCountMax = 6
		slow = true
	else
		slow = false
	end
	tempW = 184
	if warningRed then
		tempW = 7 * 16 + 6
	end

	JE_outCharGlow(JE_fontCenter(miscText[4], TINY_FONT), tempW, miscText[4])

	while true do
		setFrameCount(1)

		if levelWarningDisplay then
			JE_updateWarning(VGAScreen)
		end

		if waitUntilGetInputOrElapsed() then
			break
		end

		if (frameCountMax == 0 and slow) or ESCPressed then
			break
		end
	end

	levelWarningDisplay = false
end

function JE_newEnemy(enemyOffset_, eDatI, uniqueShapeTableI)
	for i = enemyOffset_, enemyOffset_ + 24 do
		if enemyAvail[i] == 1 then
			enemyAvail[i] = JE_makeEnemy(enemy[i], eDatI, uniqueShapeTableI)
			return i + 1
		end
	end
	return 0
end

function JE_makeEnemy(e, eDatI, uniqueShapeTableI)
	e.srcEvent = nil   -- event that spawned it (for /tyrian dump)
	local avail

	if superArcadeMode ~= SA_NONE and eDatI == 534 then
		eDatI = 533
	end

	local ed = enemyDat[eDatI]

	local shapeTableI
	if uniqueShapeTableI > 0 then
		shapeTableI = uniqueShapeTableI
	else
		shapeTableI = ed.shapebank
	end

	local sprite2s = nil
	if shapeTableI == 21 then
		sprite2s = spriteSheet11
	elseif shapeTableI == 26 then
		sprite2s = spriteSheet10
	else
		for i = 0, 3 do
			if shapeTableI == enemySpriteSheetIds[i] then
				sprite2s = enemySpriteSheets[i]
			end
		end
	end

	if sprite2s ~= nil then
		e.sprite2s = sprite2s
	end

	e.enemydatofs = ed

	e.mapoffset = 0

	for i = 0, 2 do
		e.eshotmultipos[i] = 0
	end

	e.enemyground = band(ed.explosiontype, 1) == 0
	e.explonum = rshift(ed.explosiontype, 1)

	e.launchfreq = ed.elaunchfreq
	e.launchwait = ed.elaunchfreq
	e.launchtype = ed.elaunchtype % 1000
	e.launchspecial = idiv(ed.elaunchtype, 1000)

	e.xaccel = u8(ed.xaccel)
	e.yaccel = u8(ed.yaccel)

	e.xminbounce = -10000
	e.xmaxbounce = 10000
	e.yminbounce = -10000
	e.ymaxbounce = 10000

	for i = 0, 2 do
		e.tur[i] = ed.tur[i]
	end

	e.ani = ed.ani
	e.animin = 1

	if ed.animate == 0 then
		e.enemycycle = 1
		e.aniactive = 0
		e.animax = 0
		e.aniwhenfire = 0
	elseif ed.animate == 1 then
		e.enemycycle = 0
		e.aniactive = 1
		e.animax = 0
		e.aniwhenfire = 0
	elseif ed.animate == 2 then
		e.enemycycle = 1
		e.aniactive = 2
		e.animax = e.ani
		e.aniwhenfire = 2
	end

	if ed.startxc ~= 0 then
		e.ex = s16(ed.startx + (mt_rand() % (ed.startxc * 2 % 4294967296)) - ed.startxc + 1)
	else
		e.ex = ed.startx + 1
	end

	if ed.startyc ~= 0 then
		e.ey = s16(ed.starty + (mt_rand() % (ed.startyc * 2 % 4294967296)) - ed.startyc + 1)
	else
		e.ey = ed.starty + 1
	end

	e.exc = ed.xmove
	e.eyc = ed.ymove
	e.excc = ed.xcaccel
	e.eycc = ed.ycaccel
	e.exccw = abs(e.excc)
	e.exccwmax = e.exccw
	e.eyccw = abs(e.eycc)
	e.eyccwmax = e.eyccw
	e.exccadd = (e.excc > 0) and 1 or -1
	e.eyccadd = (e.eycc > 0) and 1 or -1
	e.special = false
	e.iced = 0

	if ed.xrev == 0 then
		e.exrev = 100
	elseif ed.xrev == -99 then
		e.exrev = 0
	else
		e.exrev = ed.xrev
	end

	if ed.yrev == 0 then
		e.eyrev = 100
	elseif ed.yrev == -99 then
		e.eyrev = 0
	else
		e.eyrev = ed.yrev
	end

	e.exca = (e.xaccel > 0) and 1 or -1
	e.eyca = (e.yaccel > 0) and 1 or -1

	e.enemytype = eDatI

	for i = 0, 2 do
		if e.tur[i] == 252 then
			e.eshotwait[i] = 1
		elseif e.tur[i] > 0 then
			e.eshotwait[i] = 20
		else
			e.eshotwait[i] = 255
		end
	end
	for i = 0, 19 do
		e.egr[i] = ed.egraphic[i]
	end
	e.size = ed.esize
	e.linknum = 0
	e.edamaged = ed.dani < 0
	e.enemydie = ed.eenemydie

	e.freq[0] = ed.freq[0]
	e.freq[1] = ed.freq[1]
	e.freq[2] = ed.freq[2]

	e.edani = ed.dani
	e.edgr = ed.dgr
	e.edlevel = ed.dlevel

	e.fixedmovey = 0

	e.filter = 0x00

	local tempValue = 0
	if ed.value > 1 and ed.value < 10000 then
		local d = difficultyLevel
		if d == -1 or d == DIFFICULTY_WIMP then
			tempValue = trunc(ed.value * 0.75)
		elseif d == DIFFICULTY_EASY or d == DIFFICULTY_NORMAL then
			tempValue = ed.value
		elseif d == DIFFICULTY_HARD then
			tempValue = trunc(ed.value * 1.125)
		elseif d == DIFFICULTY_IMPOSSIBLE then
			tempValue = trunc(ed.value * 1.5)
		elseif d == DIFFICULTY_INSANITY then
			tempValue = ed.value * 2
		elseif d == DIFFICULTY_SUICIDE then
			tempValue = trunc(ed.value * 2.5)
		elseif d == DIFFICULTY_MANIACAL or d == DIFFICULTY_ZINGLON then
			tempValue = ed.value * 4
		elseif d == DIFFICULTY_NORTANEOUS or d == DIFFICULTY_10 then
			tempValue = ed.value * 8
		end
		if tempValue > 10000 then
			tempValue = 10000
		end
		e.evalue = tempValue
	else
		e.evalue = ed.value
	end

	local tempArmor = 1
	if ed.armor > 0 then
		if ed.armor ~= 255 then
			local d = difficultyLevel
			if d == -1 or d == DIFFICULTY_WIMP then
				tempArmor = trunc(ed.armor * 0.5 + 1)
			elseif d == DIFFICULTY_EASY then
				tempArmor = trunc(ed.armor * 0.75 + 1)
			elseif d == DIFFICULTY_NORMAL then
				tempArmor = ed.armor
			elseif d == DIFFICULTY_HARD then
				tempArmor = trunc(ed.armor * 1.2)
			elseif d == DIFFICULTY_IMPOSSIBLE then
				tempArmor = trunc(ed.armor * 1.5)
			elseif d == DIFFICULTY_INSANITY then
				tempArmor = trunc(ed.armor * 1.8)
			elseif d == DIFFICULTY_SUICIDE then
				tempArmor = ed.armor * 2
			elseif d == DIFFICULTY_MANIACAL then
				tempArmor = ed.armor * 3
			elseif d == DIFFICULTY_ZINGLON then
				tempArmor = ed.armor * 4
			elseif d == DIFFICULTY_NORTANEOUS or d == DIFFICULTY_10 then
				tempArmor = ed.armor * 8
			end

			if tempArmor > 254 then
				tempArmor = 254
			end
		else
			tempArmor = 255
		end

		e.armorleft = tempArmor

		avail = 0
		e.scoreitem = false
	else
		avail = 2
		e.armorleft = 255
		if e.evalue ~= 0 then
			e.scoreitem = true
		end
	end

	if not e.scoreitem then
		totalEnemy = totalEnemy + 1
	end

	return avail
end

function JE_createNewEventEnemy(enemyTypeOfs, enemyOffset_, uniqueShapeTableI)
	b = 0

	for i = enemyOffset_, enemyOffset_ + 24 do
		if enemyAvail[i] == 1 then
			b = i + 1
			break
		end
	end

	if b == 0 then return end

	local ev = eventRec[eventLoc - 1]
	tempW = ev.eventdat + enemyTypeOfs

	local e = enemy[b - 1]
	enemyAvail[b - 1] = JE_makeEnemy(e, tempW, uniqueShapeTableI)
	e.srcEvent = eventLoc - 1

	if ev.eventdat2 ~= -99 then
		if enemyOffset_ == 0 then
			e.ex = ev.eventdat2 - (mapX - 1) * 24
			e.ey = e.ey - backMove2
		elseif enemyOffset_ == 25 or enemyOffset_ == 75 then
			e.ex = ev.eventdat2 - (mapX - 1) * 24 - 12
			e.ey = e.ey - backMove
		elseif enemyOffset_ == 50 then
			if background3x1 then
				e.ex = ev.eventdat2 - (mapX - 1) * 24 - 12
			else
				e.ex = ev.eventdat2 - mapX3 * 24 - 24 * 2 + 6
			end
			e.ey = e.ey - backMove3

			if background3x1b then
				e.ex = e.ex - 6
			end
		end
		e.ey = -28
		if background3x1b and enemyOffset_ == 50 then
			e.ey = e.ey + 4
		end
	end

	if smallEnemyAdjust and e.size == 0 then
		e.ex = e.ex - 10
		e.ey = e.ey - 7
	end

	e.ey = e.ey + ev.eventdat5
	e.eyc = s8(e.eyc + ev.eventdat3)
	e.linknum = ev.eventdat4
	e.fixedmovey = ev.eventdat6
	-- generated levels: drop scenery (buildings, emplacements, DESERTRUN's
	-- arches) that would stand on the wrong ground
	if genLevel and enemyOffset_ > 0 and not LevelGen.sceneryOk(eventLoc - 1, e, enemyOffset_) then
		enemyAvail[b - 1] = 1
		b = 0
	end
end

function JE_eventJump(jump)
	if jump == 65535 then
		curLoc = returnLoc
	else
		returnLoc = u16(curLoc + 1)
		curLoc = jump
	end
	local tw = 0
	repeat
		tw = tw + 1
	until eventRec[tw - 1].eventtime >= curLoc
	eventLoc = tw - 1
end

-- Returns found, index
function JE_searchFor(PLType)
	local found_id = -1

	for i = 0, 99 do
		if enemyAvail[i] == 0 and enemy[i].linknum == PLType then
			found_id = i
			if galagaMode then
				enemy[i].evalue = enemy[i].evalue + enemy[i].evalue
			end
		end
	end

	if found_id ~= -1 then
		return true, found_id
	end
	return false
end

function JE_eventSystem()
	local ev = eventRec[eventLoc - 1]
	local et = ev.eventtype

	if et == 1 then
		starfield_speed = ev.eventdat

	elseif et == 2 then
		map1YDelay = 1
		map1YDelayMax = 1
		map2YDelay = 1
		map2YDelayMax = 1

		backMove = u16(ev.eventdat)
		backMove2 = u16(ev.eventdat2)

		if backMove2 > 0 then
			explodeMove = backMove2
		else
			explodeMove = backMove
		end

		backMove3 = u16(ev.eventdat3)

		if backMove > 0 then
			stopBackgroundNum = 0
		end

	elseif et == 3 then
		backMove = 1
		map1YDelay = 3
		map1YDelayMax = 3
		backMove2 = 1
		map2YDelay = 2
		map2YDelayMax = 2
		backMove3 = 1

	elseif et == 4 then
		stopBackgrounds = true
		local d = ev.eventdat
		if d == 0 or d == 1 then
			stopBackgroundNum = 1
		elseif d == 2 then
			stopBackgroundNum = 2
		elseif d == 3 then
			stopBackgroundNum = 3
		end

	elseif et == 5 then
		local newTables = {
			[0] = ev.eventdat > 0 and u8(ev.eventdat) or 0,
			ev.eventdat2 > 0 and u8(ev.eventdat2) or 0,
			ev.eventdat3 > 0 and u8(ev.eventdat3) or 0,
			ev.eventdat4 > 0 and u8(ev.eventdat4) or 0,
		}

		for i = 0, 3 do
			if enemySpriteSheetIds[i] ~= newTables[i] then
				if newTables[i] > 0 then
					JE_loadCompShapes(enemySpriteSheets[i], shapeFile[newTables[i] - 1])
				else
					free_sprite2s(enemySpriteSheets[i])
				end
				enemySpriteSheetIds[i] = newTables[i]
			end
		end

	elseif et == 6 then
		JE_createNewEventEnemy(0, 25, 0)

	elseif et == 7 then
		JE_createNewEventEnemy(0, 50, 0)

	elseif et == 8 then
		starActive = false

	elseif et == 9 then
		starActive = true

	elseif et == 10 then
		JE_createNewEventEnemy(0, 75, 0)

	elseif et == 11 then
		if allPlayersGone or ev.eventdat == 1 then
			reallyEndLevel = true
		elseif not endLevel then
			readyToEndLevel = false
			endLevel = true
			levelEnd = 40
		end

	elseif et == 12 then
		local t = 0
		local d6 = ev.eventdat6
		if d6 == 0 or d6 == 1 then t = 25
		elseif d6 == 2 then t = 0
		elseif d6 == 3 then t = 50
		elseif d6 == 4 then t = 75 end
		ev.eventdat6 = 0
		JE_createNewEventEnemy(0, t, 0)
		JE_createNewEventEnemy(1, t, 0)
		if b > 0 then
			enemy[b - 1].ex = enemy[b - 1].ex + 24
		end
		JE_createNewEventEnemy(2, t, 0)
		if b > 0 then
			enemy[b - 1].ey = enemy[b - 1].ey - 28
		end
		JE_createNewEventEnemy(3, t, 0)
		if b > 0 then
			enemy[b - 1].ex = enemy[b - 1].ex + 24
			enemy[b - 1].ey = enemy[b - 1].ey - 28
		end

	elseif et == 13 then
		enemiesActive = false

	elseif et == 14 then
		enemiesActive = true

	elseif et == 15 then
		JE_createNewEventEnemy(0, 0, 0)

	elseif et == 16 then
		local id = ev.eventdat
		if id >= 1 and id <= 9 then
			JE_drawTextWindow(outputs[id - 1])
			soundQueue[3] = windowTextSamples[id - 1]
		end

	elseif et == 17 then
		JE_createNewEventEnemy(0, 25, 0)
		if b > 0 then
			enemy[b - 1].ey = 190 + ev.eventdat5
		end

	elseif et == 18 then
		JE_createNewEventEnemy(0, 0, 0)
		if b > 0 then
			enemy[b - 1].ey = 190 + ev.eventdat5
		end

	elseif et == 19 then
		local initial_i, max_i = 0, 0
		local all_enemies = false

		if ev.eventdat3 > 79 and ev.eventdat3 < 90 then
			initial_i = 0
			max_i = 100
			all_enemies = false
			ev.eventdat4 = newPL[ev.eventdat3 - 80]
		else
			local d3 = ev.eventdat3
			if d3 == 0 then
				initial_i, max_i, all_enemies = 0, 100, false
			elseif d3 == 2 then
				initial_i, max_i, all_enemies = 0, 25, true
			elseif d3 == 1 then
				initial_i, max_i, all_enemies = 25, 50, true
			elseif d3 == 3 then
				initial_i, max_i, all_enemies = 50, 75, true
			elseif d3 == 99 then
				initial_i, max_i, all_enemies = 0, 100, true
			end
		end

		for i = initial_i, max_i - 1 do
			local e = enemy[i]
			if all_enemies or e.linknum == ev.eventdat4 then
				if ev.eventdat ~= -99 then
					e.exc = s8(ev.eventdat)
				end
				if ev.eventdat2 ~= -99 then
					e.eyc = s8(ev.eventdat2)
				end
				if ev.eventdat6 ~= 0 then
					e.fixedmovey = ev.eventdat6
				end
				if ev.eventdat6 == -99 then
					e.fixedmovey = 0
				end
				if ev.eventdat5 > 0 then
					e.enemycycle = ev.eventdat5
				end
			end
		end

	elseif et == 20 then
		if ev.eventdat3 > 79 and ev.eventdat3 < 90 then
			ev.eventdat4 = newPL[ev.eventdat3 - 80]
		end

		for t = 0, 99 do
			local e = enemy[t]
			if enemyAvail[t] ~= 1 and (e.linknum == ev.eventdat4 or ev.eventdat4 == 0) then
				if ev.eventdat ~= -99 then
					e.excc = s8(ev.eventdat)
					e.exccw = s8(abs(ev.eventdat))
					e.exccwmax = u8(abs(ev.eventdat))
					if ev.eventdat > 0 then
						e.exccadd = 1
					else
						e.exccadd = -1
					end
				end

				if ev.eventdat2 ~= -99 then
					e.eycc = s8(ev.eventdat2)
					e.eyccw = s8(abs(ev.eventdat2))
					e.eyccwmax = u8(abs(ev.eventdat2))
					if ev.eventdat2 > 0 then
						e.eyccadd = 1
					else
						e.eyccadd = -1
					end
				end

				if ev.eventdat5 > 0 then
					e.enemycycle = ev.eventdat5
				end
				if ev.eventdat6 > 0 then
					e.ani = ev.eventdat6
					e.animin = ev.eventdat5
					e.animax = 0
					e.aniactive = 1
				end
			end
		end

	elseif et == 21 then
		background3over = 1

	elseif et == 22 then
		background3over = 0

	elseif et == 23 then
		JE_createNewEventEnemy(0, 50, 0)
		if b > 0 then
			enemy[b - 1].ey = 180 + ev.eventdat5
		end

	elseif et == 24 then
		for t = 0, 99 do
			local e = enemy[t]
			if e.linknum == ev.eventdat4 then
				e.aniactive = 1
				e.aniwhenfire = 0
				if ev.eventdat2 > 0 then
					e.enemycycle = u8(ev.eventdat2)
					e.animin = e.enemycycle
				else
					e.enemycycle = 0
				end

				if ev.eventdat > 0 then
					e.ani = u8(ev.eventdat)
				end

				if ev.eventdat3 == 1 then
					e.animax = e.ani
				elseif ev.eventdat3 == 2 then
					e.aniactive = 2
					e.animax = e.ani
					e.aniwhenfire = 2
				end
			end
		end

	elseif et == 25 then
		for t = 0, 99 do
			if ev.eventdat4 == 0 or enemy[t].linknum == ev.eventdat4 then
				if galagaMode then
					enemy[t].armorleft = u8(roundf(ev.eventdat * idiv(difficultyLevel, 2)))
				else
					enemy[t].armorleft = u8(ev.eventdat)
				end
			end
		end

	elseif et == 26 then
		smallEnemyAdjust = ev.eventdat ~= 0

	elseif et == 27 then
		if ev.eventdat3 > 79 and ev.eventdat3 < 90 then
			ev.eventdat4 = newPL[ev.eventdat3 - 80]
		end

		for t = 0, 99 do
			local e = enemy[t]
			if ev.eventdat4 == 0 or e.linknum == ev.eventdat4 then
				if ev.eventdat ~= -99 then
					e.exrev = s8(ev.eventdat)
				end
				if ev.eventdat2 ~= -99 then
					e.eyrev = s8(ev.eventdat2)
				end
				if ev.eventdat3 ~= 0 and ev.eventdat3 < 17 then
					e.filter = u8(ev.eventdat3)
				end
			end
		end

	elseif et == 28 then
		topEnemyOver = false

	elseif et == 29 then
		topEnemyOver = true

	elseif et == 30 then
		map1YDelay = 1
		map1YDelayMax = 1
		map2YDelay = 1
		map2YDelayMax = 1

		backMove = u16(ev.eventdat)
		backMove2 = u16(ev.eventdat2)
		explodeMove = backMove2
		backMove3 = u16(ev.eventdat3)

	elseif et == 31 then
		for t = 0, 99 do
			local e = enemy[t]
			if ev.eventdat4 == 99 or e.linknum == ev.eventdat4 then
				e.freq[0] = u8(ev.eventdat)
				e.freq[1] = u8(ev.eventdat2)
				e.freq[2] = u8(ev.eventdat3)
				for t2 = 0, 2 do
					e.eshotwait[t2] = 1
				end
				if e.launchtype > 0 then
					e.launchfreq = u8(ev.eventdat5)
					e.launchwait = 1
				end
			end
		end

	elseif et == 32 then
		JE_createNewEventEnemy(0, 50, 0)
		if b > 0 then
			enemy[b - 1].ey = 190
		end

	elseif et == 33 then
		if not ((ev.eventdat == 512 or ev.eventdat == 513) and (twoPlayerMode or onePlayerAction or superTyrian)) then
			if superArcadeMode ~= SA_NONE then
				if ev.eventdat == 534 then
					ev.eventdat = 827
				end
			elseif not superTyrian then
				local lives = player[0].lives.power
				if ev.eventdat == 533 and (lives == 11 or (mt_rand() % 15) < lives) then
					ev.eventdat = 829 + (mt_rand() % 6)
				end
			end
			if ev.eventdat == 534 and superTyrian then
				ev.eventdat = 828 + superTyrianSpecials[mt_rand() % 4]
			end

			for t = 0, 99 do
				if enemy[t].linknum == ev.eventdat4 then
					enemy[t].enemydie = u16(ev.eventdat)
				end
			end
		end

	elseif et == 34 then
		if firstGameOver then
			musicFade = true
			tempVolume = tyrMusicVolume
		end

	elseif et == 35 then
		if firstGameOver then
			play_song(ev.eventdat - 1)
			set_volume(tyrMusicVolume, fxVolume)
		end
		musicFade = false

	elseif et == 36 then
		readyToEndLevel = true

	elseif et == 37 then
		levelEnemyFrequency = u16(ev.eventdat)

	elseif et == 38 then
		curLoc = u16(ev.eventdat)
		local new_event_loc = 1
		for tw = 0, maxEvent - 1 do
			if eventRec[tw].eventtime <= curLoc then
				new_event_loc = tw + 1 - 1
			end
		end
		eventLoc = new_event_loc

	elseif et == 39 then
		for t = 0, 99 do
			if enemy[t].linknum == ev.eventdat then
				enemy[t].linknum = u8(ev.eventdat2)
			end
		end

	elseif et == 40 then
		enemyContinualDamage = true

	elseif et == 41 then
		if ev.eventdat == 0 then
			fillArray(enemyAvail, 100, 1)
		else
			for xx = 0, 24 do
				enemyAvail[xx] = 1
			end
		end

	elseif et == 42 then
		background3over = 2

	elseif et == 43 then
		background2over = u8(ev.eventdat)

	elseif et == 44 then
		filterActive = (ev.eventdat > 0)
		filterFade = (ev.eventdat == 2)
		levelFilter = s8(ev.eventdat2)
		levelBrightness = ev.eventdat3
		levelFilterNew = s8(ev.eventdat4)
		levelBrightnessChg = ev.eventdat5
		filterFadeStart = (ev.eventdat6 == 0)

	elseif et == 45 then
		if not superTyrian then
			local lives = player[0].lives.power

			if ev.eventdat == 533 and (lives == 11 or (mt_rand() % 15) < lives) then
				ev.eventdat = 829 + (mt_rand() % 6)
			end
			if twoPlayerMode or onePlayerAction then
				for t = 0, 99 do
					if enemy[t].linknum == ev.eventdat4 then
						enemy[t].enemydie = u16(ev.eventdat)
					end
				end
			end
		end

	elseif et == 46 then
		if ev.eventdat3 ~= 0 then
			damageRate = u8(ev.eventdat3)
		end

		if ev.eventdat2 == 0 or twoPlayerMode or onePlayerAction then
			difficultyLevel = difficultyLevel + ev.eventdat
			if difficultyLevel < DIFFICULTY_EASY then
				difficultyLevel = DIFFICULTY_EASY
			end
			if difficultyLevel > DIFFICULTY_10 then
				difficultyLevel = DIFFICULTY_10
			end
		end

	elseif et == 47 then
		for t = 0, 99 do
			if ev.eventdat4 == 0 or enemy[t].linknum == ev.eventdat4 then
				enemy[t].armorleft = u8(ev.eventdat)
			end
		end

	elseif et == 48 then
		background2notTransparent = true

	elseif et == 49 or et == 50 or et == 51 or et == 52 then
		tempDat2 = ev.eventdat
		ev.eventdat = 0
		tempDat = ev.eventdat3
		ev.eventdat3 = 0
		tempDat3 = ev.eventdat6
		ev.eventdat6 = 0
		enemyDat[0].armor = u8(tempDat3)
		enemyDat[0].egraphic[0] = u16(tempDat2)
		local k = et - 48
		if k == 1 then temp = 25
		elseif k == 2 then temp = 0
		elseif k == 3 then temp = 50
		elseif k == 4 then temp = 75 end
		JE_createNewEventEnemy(0, temp, tempDat)
		ev.eventdat = tempDat2
		ev.eventdat3 = tempDat
		ev.eventdat6 = tempDat3

	elseif et == 53 then
		forceEvents = (ev.eventdat ~= 99)

	elseif et == 54 then
		JE_eventJump(u16(ev.eventdat))

	elseif et == 55 then
		if ev.eventdat3 > 79 and ev.eventdat3 < 90 then
			ev.eventdat4 = newPL[ev.eventdat3 - 80]
		end

		for t = 0, 99 do
			if ev.eventdat4 == 0 or enemy[t].linknum == ev.eventdat4 then
				if ev.eventdat ~= -99 then
					enemy[t].xaccel = u8(ev.eventdat)
				end
				if ev.eventdat2 ~= -99 then
					enemy[t].yaccel = u8(ev.eventdat2)
				end
			end
		end

	elseif et == 56 then
		JE_createNewEventEnemy(0, 75, 0)
		if b > 0 then
			enemy[b - 1].ey = 190
		end

	elseif et == 57 then
		superEnemy254Jump = u16(ev.eventdat)

	elseif et == 60 then
		for t = 0, 99 do
			if enemy[t].linknum == ev.eventdat4 then
				enemy[t].special = true
				enemy[t].flagnum = u8(ev.eventdat)
				enemy[t].setto = (ev.eventdat2 == 1)
			end
		end

	elseif et == 61 then
		local flagv = globalFlags[ev.eventdat - 1]
		if b2n(flagv) == ev.eventdat2 then
			eventLoc = eventLoc + ev.eventdat3
		end

	elseif et == 62 then
		soundQueue[3] = u8(ev.eventdat)

	elseif et == 63 then
		if not twoPlayerMode and not onePlayerAction then
			eventLoc = eventLoc + ev.eventdat
		end

	elseif et == 64 then
		if not (ev.eventdat == 6 and twoPlayerMode and difficultyLevel > DIFFICULTY_NORMAL) then
			smoothies[ev.eventdat - 1] = ev.eventdat2 ~= 0
			temp = u8(ev.eventdat)
			if temp == 5 then
				temp = 3
			end
			smoothie_data[temp - 1] = u8(ev.eventdat3)
		end

	elseif et == 65 then
		background3x1 = (ev.eventdat == 0)

	elseif et == 66 then
		if initialDifficulty <= ev.eventdat then
			eventLoc = eventLoc + ev.eventdat2
		end

	elseif et == 67 then
		levelTimer = (ev.eventdat == 1)
		levelTimerCountdown = u16(ev.eventdat3 * 100)
		levelTimerJumpTo = u16(ev.eventdat2)

	elseif et == 68 then
		randomExplosions = (ev.eventdat == 1)

	elseif et == 69 then
		for i = 0, 1 do
			player[i].invulnerable_ticks = ev.eventdat
		end

	elseif et == 70 then
		if ev.eventdat2 == 0 then
			local found = false
			for t = 1, 19 do
				found = found or JE_searchFor(t)
			end
			if not found then
				JE_eventJump(u16(ev.eventdat))
			end
		elseif not JE_searchFor(ev.eventdat2) and
		       (ev.eventdat3 == 0 or not JE_searchFor(ev.eventdat3)) and
		       (ev.eventdat4 == 0 or not JE_searchFor(ev.eventdat4)) then
			JE_eventJump(u16(ev.eventdat))
		end

	elseif et == 71 then
		if mapYPos * 2 <= u32(ev.eventdat2) then
			JE_eventJump(u16(ev.eventdat))
		end

	elseif et == 72 then
		background3x1b = (ev.eventdat == 1)

	elseif et == 73 then
		skyEnemyOverAll = (ev.eventdat == 1)

	elseif et == 74 then
		for t = 0, 99 do
			local e = enemy[t]
			if ev.eventdat4 == 0 or e.linknum == ev.eventdat4 then
				if ev.eventdat5 ~= -99 then
					e.xminbounce = ev.eventdat5
				end
				if ev.eventdat6 ~= -99 then
					e.yminbounce = ev.eventdat6
				end
				if ev.eventdat ~= -99 then
					e.xmaxbounce = ev.eventdat
				end
				if ev.eventdat2 ~= -99 then
					e.ymaxbounce = ev.eventdat2
				end
			end
		end

	elseif et == 75 then
		local temp_no_clue = false

		for t = 0, 99 do
			local e = enemy[t]
			if enemyAvail[t] == 0 and e.eyc == 0 and
			   e.linknum >= ev.eventdat and e.linknum <= ev.eventdat2 then
				temp_no_clue = true
			end
		end

		if temp_no_clue then
			local tries = 0
			while true do
				temp = u8((mt_rand() % (ev.eventdat2 + 1 - ev.eventdat)) + ev.eventdat)
				local found, enemy_i = JE_searchFor(temp)
				if found and enemy[enemy_i].eyc == 0 then break end
				tries = tries + 1
				if tries > 10000 then break end
			end

			newPL[ev.eventdat3 - 80] = temp
		else
			newPL[ev.eventdat3 - 80] = 255
			if ev.eventdat4 > 0 then
				curLoc = u16(eventRec[eventLoc - 1 + ev.eventdat4].eventtime - 1)
				eventLoc = eventLoc + ev.eventdat4 - 1
			end
		end

	elseif et == 76 then
		returnActive = true

	elseif et == 77 then
		mapYPos = idiv(ev.eventdat, 2)
		if ev.eventdat2 > 0 then
			mapY2Pos = idiv(ev.eventdat2, 2)
		else
			mapY2Pos = idiv(ev.eventdat, 2)
		end

	elseif et == 78 then
		if galagaShotFreq < 10 then
			galagaShotFreq = galagaShotFreq + 1
		end

	elseif et == 79 then
		boss_bar[0].link_num = u8(ev.eventdat)
		boss_bar[1].link_num = u8(ev.eventdat2)

	elseif et == 80 then
		if twoPlayerMode then
			eventLoc = eventLoc + ev.eventdat
		end

	elseif et == 81 then
		BKwrap2 = idiv(ev.eventdat, 2)
		BKwrap2to = idiv(ev.eventdat2, 2)

	elseif et == 82 then
		player[0].items.special = u8(ev.eventdat)
		shotMultiPos[SHOT_SPECIAL] = 0
		shotRepeat[SHOT_SPECIAL] = 0
		shotMultiPos[SHOT_SPECIAL2] = 0
		shotRepeat[SHOT_SPECIAL2] = 0

	else
		logWarn("Event %05d %d has invalid type.", ev.eventtime, ev.eventtype)
	end

	eventLoc = eventLoc + 1
end

function JE_whoa()
	-- The original warps the screen with a pixel-bleeding effect; here the
	-- screen simply fades through white.
	fade_white(40)
	fade_black(40)
	levelWarningLines = 4
end

local function JE_barX(x1, y1, x2, y2, col)
	fill_rectangle_xy(VGAScreen, x1, y1, x2, y1, col + 1)
	fill_rectangle_xy(VGAScreen, x1, y1 + 1, x2, y2 - 1, col)
	fill_rectangle_xy(VGAScreen, x1, y2, x2, y2, col - 1)
end

function draw_boss_bar()
	for bb = 0, 1 do
		local bar = boss_bar[bb]
		if bar.link_num ~= 0 then
			local armor = 256

			for e = 0, 99 do
				if enemyAvail[e] ~= 1 and enemy[e].linknum == bar.link_num then
					if enemy[e].armorleft < armor then
						armor = enemy[e].armorleft
					end
				end
			end

			if armor > 255 or armor == 0 then
				bar.link_num = 0
			else
				bar.armor = (armor == 255) and 254 or armor
			end
		end
	end

	local bars = (boss_bar[0].link_num ~= 0 and 1 or 0) + (boss_bar[1].link_num ~= 0 and 1 or 0)

	if bars == 1 and boss_bar[0].link_num == 0 then
		boss_bar[0].link_num = boss_bar[1].link_num
		boss_bar[0].armor = boss_bar[1].armor
		boss_bar[0].color = boss_bar[1].color
		boss_bar[1].link_num = 0
	end

	for bb = 0, bars - 1 do
		local bar = boss_bar[bb]
		local xx = (bars == 2) and ((bb == 0) and 125 or 185) or (levelTimer and 250 or 155)

		JE_barX(xx - 25, 7, xx + 25, 12, 115)
		JE_barX(xx - idiv(bar.armor, 10), 7, xx + idiv(bar.armor + 5, 10), 12, 118 + bar.color)

		if bar.color > 0 then
			bar.color = bar.color - 1
		end
	end
end
