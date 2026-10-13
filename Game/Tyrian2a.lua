--[[
 WowTyrian2k: a World of Warcraft port of OpenTyrian
 Copyright (C) The OpenTyrian Development Team
 Lua port Copyright (C) 2026 voetre
 Licensed under the GNU General Public License v2 or later (see COPYING).

 tyrian2.c (part 1): enemy drawing and the main game loop
]]
local _, ns = ...
setfenv(1, ns.G)

boss_bar = { [0] = { link_num = 0, armor = 0, color = 0 }, { link_num = 0, armor = 0, color = 0 } }

quit, loadLevelOk = false, false

eventRec = newArray(EVENT_MAXIMUM, function()
	return { eventtime = 0, eventtype = 0, eventdat = 0, eventdat2 = 0, eventdat3 = 0, eventdat5 = 0, eventdat6 = 0, eventdat4 = 0 }
end)
levelEnemyMax = 0
levelEnemyFrequency = 0
levelEnemy = newArray(40, 0)

tempStr = ""

itemAvail = newArray(9, function() return newArray(10, 0) end)
itemAvailMax = newArray(9, 0)

-- persistent per-level locals of JE_main
local musicFadeLocal

function JE_starShowVGA()
	if not playerEndLevel and not skipStarShowVGA then
		if smoothScroll then
			delayUntilElapsed()
			setFrameCount(frameCountMax)
		end

		if starShowVGASpecialCode == 1 then
			showFlipped(VGAScreenSeg, game_screen)
		elseif starShowVGASpecialCode == 2 and processorType >= 2 then
			showHeadlight(VGAScreenSeg, game_screen, player[0].x, player[0].y)
		else
			showNormal(VGAScreenSeg, game_screen)
		end
		JE_showVGA()
	end

	handleSdlEvents()

	quitRequested = false
	skipStarShowVGA = false
end

local function blit_enemy(surface, i, x_offset, y_offset, sprite_offset)
	local e = enemy[i]
	if e.sprite2s == nil then return end

	local xx = e.ex + x_offset + tempMapXOfs
	local yy = e.ey + y_offset
	local index = (e.egr[e.enemycycle - 1] or 0) + sprite_offset

	if e.filter ~= 0 then
		blit_sprite2_filter(surface, xx, yy, e.sprite2s, index, e.filter)
	else
		blit_sprite2(surface, xx, yy, e.sprite2s, index)
	end
end

local function unsignedMinus89(v)
	local d = v - 89
	if d < 0 then d = d + 4294967296 end
	return d
end

-- Processes one enemy.  Returns after "goto draw_enemy_end".
local function drawEnemyOne(i, enemyOffset_)
	local e = enemy[i]
	e.mapoffset = tempMapXOfs

	if e.xaccel ~= 0 and unsignedMinus89(e.xaccel) > mt_rand() % 11 then
		if player[0].x > e.ex then
			if e.exc < e.xaccel - 89 then
				e.exc = s8(e.exc + 1)
			end
		else
			if e.exc >= 0 or -e.exc < e.xaccel - 89 then
				e.exc = s8(e.exc - 1)
			end
		end
	end

	if e.yaccel ~= 0 and unsignedMinus89(e.yaccel) > mt_rand() % 11 then
		if player[0].y > e.ey then
			if e.eyc < e.yaccel - 89 then
				e.eyc = s8(e.eyc + 1)
			end
		else
			if e.eyc >= 0 or -e.eyc < e.yaccel - 89 then
				e.eyc = s8(e.eyc - 1)
			end
		end
	end

	local gone = false

	if e.ex + tempMapXOfs > -29 and e.ex + tempMapXOfs < 300 then
		if e.aniactive == 1 then
			e.enemycycle = u8(e.enemycycle + 1)

			if e.enemycycle == e.animax then
				e.aniactive = e.aniwhenfire
			elseif e.enemycycle > e.ani then
				e.enemycycle = e.animin
			end
		end

		if e.egr[e.enemycycle - 1] == 999 then
			gone = true
		else
			if e.size == 1 then
				if e.ey > -13 then
					blit_enemy(VGAScreen, i, -6, -7, 0)
					blit_enemy(VGAScreen, i, 6, -7, 1)
				end
				if e.ey > -26 and e.ey < 182 then
					blit_enemy(VGAScreen, i, -6, 7, 19)
					blit_enemy(VGAScreen, i, 6, 7, 20)
				end
			else
				if e.ey > -13 then
					blit_enemy(VGAScreen, i, 0, 0, 0)
				end
			end

			e.filter = 0
		end
	end

	if not gone then
		if e.excc ~= 0 then
			e.exccw = s8(e.exccw - 1)
			if e.exccw <= 0 then
				if e.exc == e.exrev then
					e.excc = -e.excc
					e.exrev = -e.exrev
					e.exccadd = -e.exccadd
				else
					e.exc = s8(e.exc + e.exccadd)
					e.exccw = e.exccwmax
					if e.exc == e.exrev then
						e.excc = -e.excc
						e.exrev = -e.exrev
						e.exccadd = -e.exccadd
					end
				end
			end
		end

		if e.eycc ~= 0 then
			e.eyccw = s8(e.eyccw - 1)
			if e.eyccw <= 0 then
				if e.eyc == e.eyrev then
					e.eycc = -e.eycc
					e.eyrev = -e.eyrev
					e.eyccadd = -e.eyccadd
				else
					e.eyc = s8(e.eyc + e.eyccadd)
					e.eyccw = e.eyccwmax
					if e.eyc == e.eyrev then
						e.eycc = -e.eycc
						e.eyrev = -e.eyrev
						e.eyccadd = -e.eyccadd
					end
				end
			end
		end

		e.ey = e.ey + e.fixedmovey

		e.ex = e.ex + e.exc
		if e.ex < -80 or e.ex > 340 then
			gone = true
		else
			e.ey = e.ey + e.eyc
			if e.ey < -112 or e.ey > 190 then
				gone = true
			end
		end
	end

	if gone then
		enemyAvail[i] = 1
		return
	end

	-- enemy_still_exists:

	if e.ex <= e.xminbounce or e.ex >= e.xmaxbounce then
		e.exc = -e.exc
	end
	if e.ey <= e.yminbounce or e.ey >= e.ymaxbounce then
		e.eyc = -e.eyc
	end

	if e.scoreitem then
		if e.ex < -5 then e.ex = e.ex + 1 end
		if e.ex > 245 then e.ex = e.ex - 1 end
	end

	e.ey = e.ey + tempBackMove

	if e.ex <= -24 or e.ex >= 296 then
		return
	end

	local tempX = e.ex
	local tempY = e.ey

	temp = u8(e.enemytype)

	if e.edamaged then
		return
	end

	enemyOnScreen = enemyOnScreen + 1

	if e.iced ~= 0 then
		e.iced = e.iced - 1
		if e.enemyground then
			e.filter = 0x09
		end
		return
	end

	for j = 3, 1, -1 do
		if e.freq[j - 1] ~= 0 then
			temp3 = e.tur[j - 1]

			e.eshotwait[j - 1] = u8(e.eshotwait[j - 1] - 1)
			if e.eshotwait[j - 1] == 0 and temp3 ~= 0 then
				e.eshotwait[j - 1] = e.freq[j - 1]
				if difficultyLevel > DIFFICULTY_NORMAL then
					e.eshotwait[j - 1] = idiv(e.eshotwait[j - 1], 2) + 1
					if difficultyLevel > DIFFICULTY_MANIACAL then
						e.eshotwait[j - 1] = idiv(e.eshotwait[j - 1], 2) + 1
					end
				end

				if galagaMode and (e.eyc == 0 or (mt_rand() % 400) >= galagaShotFreq) then
					return
				end

				if temp3 == 252 then
					if e.ey > 20 then
						JE_setupExplosion(tempX - 8 + tempMapXOfs, tempY - 20 - backMove * 8, -2, 6, false, false)
						JE_setupExplosion(tempX + 4 + tempMapXOfs, tempY - 20 - backMove * 8, -2, 6, false, false)
					end
				elseif temp3 == 251 then
					local attraction = 4 - idiv(abs(player[0].x - tempX) + abs(player[0].y - tempY), 100)
					if attraction > 0 then
						player[0].x_velocity = player[0].x_velocity + ((player[0].x > tempX) and -attraction or attraction)
					end
				elseif temp3 == 253 then
					if abs(player[0].x + 25 - 14 - tempX) < 24 and abs(player[0].y - tempY) < 28 then
						player[0].x_velocity = player[0].x_velocity + 2
					end
					if twoPlayerMode and (abs(player[1].x - 14 - tempX) < 24 and abs(player[1].y - tempY) < 28) then
						player[1].x_velocity = player[1].x_velocity + 2
					end
				elseif temp3 == 254 then
					if abs(player[0].x + 25 - 14 - tempX) < 24 and abs(player[0].y - tempY) < 28 then
						player[0].x_velocity = player[0].x_velocity - 2
					end
					if twoPlayerMode and (abs(player[1].x - 14 - tempX) < 24 and abs(player[1].y - tempY) < 28) then
						player[1].x_velocity = player[1].x_velocity - 2
					end
				elseif temp3 == 255 then
					if difficultyLevel ~= DIFFICULTY_EASY then
						if j == 3 then
							e.filter = 0x70
						else
							local repulsion = 4 - idiv(abs(player[0].x - tempX) + abs(player[0].y - tempY), 20)
							if repulsion > 0 then
								player[0].x_velocity = player[0].x_velocity + ((player[0].x > tempX) and repulsion or -repulsion)
							end
						end
					end
				else
					local w = weapons[temp3]
					for tempCount = w.multi, 1, -1 do
						local bb = 0
						while bb < ENEMY_SHOT_MAX do
							if enemyShotAvail[bb] then break end
							bb = bb + 1
						end
						b = bb
						if bb == ENEMY_SHOT_MAX then
							return
						end

						enemyShotAvail[bb] = not enemyShotAvail[bb]

						if w.sound > 0 then
							repeat
								temp = mt_rand() % 8
							until temp ~= 3
							soundQueue[temp] = w.sound
						end

						if e.aniactive == 2 then
							e.aniactive = 1
						end

						e.eshotmultipos[j - 1] = e.eshotmultipos[j - 1] + 1
						if e.eshotmultipos[j - 1] > w.max then
							e.eshotmultipos[j - 1] = 1
						end

						local tempPos = e.eshotmultipos[j - 1] - 1

						if j == 1 then
							temp2 = 4
						end

						local s = enemyShot[bb]
						s.sx = tempX + w.bx[tempPos] + tempMapXOfs
						s.sy = tempY + w.by[tempPos]
						s.sdmg = w.attack[tempPos]
						s.tx = w.tx
						s.ty = w.ty
						s.duration = w.del[tempPos]
						s.animate = 0
						s.animax = w.weapani

						s.sgr = w.sg[tempPos]
						if j == 1 then
							s.syc = w.acceleration
							s.sxc = w.accelerationx
							s.sxm = w.sx[tempPos]
							s.sym = w.sy[tempPos]
						elseif j == 3 then
							s.sxc = -w.acceleration
							s.syc = w.accelerationx
							s.sxm = -w.sy[tempPos]
							s.sym = -w.sx[tempPos]
						elseif j == 2 then
							s.sxc = w.acceleration
							s.syc = -w.acceleration
							s.sxm = w.sy[tempPos]
							s.sym = -w.sx[tempPos]
						end

						if w.aim > 0 then
							local aim = w.aim

							if difficultyLevel > DIFFICULTY_NORMAL then
								aim = u8(aim + difficultyLevel - 2)
							end

							local targetX = player[0].x
							local targetY = player[0].y

							if twoPlayerMode then
								if player[0].is_alive and not player[1].is_alive then
									temp = 0
								elseif player[1].is_alive and not player[0].is_alive then
									temp = 1
								else
									temp = mt_rand() % 2
								end

								if temp == 1 then
									targetX = player[1].x - 25
									targetY = player[1].y
								end
							end

							local aimX = (targetX + 25) - tempX - tempMapXOfs - 4
							if aimX == 0 then aimX = 1 end
							local aimY = targetY - tempY
							if aimY == 0 then aimY = 1 end
							local maxMagAim = MAX(abs(aimX), abs(aimY))
							s.sxm = roundf(aimX / maxMagAim * aim)
							s.sym = roundf(aimY / maxMagAim * aim)
						end
					end
				end
			end
		end
	end

	-- Enemy Launch Routine
	if e.launchfreq ~= 0 then
		e.launchwait = u8(e.launchwait - 1)
		if e.launchwait == 0 then
			e.launchwait = e.launchfreq

			if e.launchspecial ~= 0 then
				if abs(e.ey - player[0].y) > 5 then
					return
				end
			end

			if e.aniactive == 2 then
				e.aniactive = 1
			end

			if e.launchtype == 0 then
				return
			end

			tempW = e.launchtype
			b = JE_newEnemy(enemyOffset_ == 50 and 75 or enemyOffset_ - 25, tempW, 0)

			if b > 0 then
				local ne = enemy[b - 1]

				ne.ex = tempX
				ne.ey = tempY + enemyDat[ne.enemytype].startyc
				if ne.size == 0 then
					ne.ey = ne.ey - 7
				end

				if ne.launchtype > 0 and ne.launchfreq == 0 then
					if ne.launchtype > 90 then
						ne.ex = ne.ex + mt_rand() % ((ne.launchtype - 90) * 4) - (ne.launchtype - 90) * 2
					else
						local aimX = (player[0].x + 25) - tempX - tempMapXOfs - 4
						if aimX == 0 then aimX = 1 end
						local aimY = player[0].y - tempY
						if aimY == 0 then aimY = 1 end
						local maxMagAim = MAX(abs(aimX), abs(aimY))
						ne.exc = s8(roundf(aimX / maxMagAim * ne.launchtype))
						ne.eyc = s8(roundf(aimY / maxMagAim * ne.launchtype))
					end
				end

				repeat
					temp = mt_rand() % 8
				until temp ~= 3
				soundQueue[temp] = randomEnemyLaunchSounds[mt_rand() % 3]

				if e.launchspecial == 1 and e.linknum < 100 then
					ne.linknum = e.linknum
				end
			end
		end
	end
end

function JE_drawEnemy(enemyOffset_)
	player[0].x = player[0].x - 25

	for i = enemyOffset_ - 25, enemyOffset_ - 1 do
		if enemyAvail[i] ~= 1 then
			drawEnemyOne(i, enemyOffset_)
		end
	end

	player[0].x = player[0].x + 25
end

-- Processes one player shot against the enemies (the body of the "Player Shot
-- Images" loop of JE_main).
local function processPlayerShot(z)
	local ok, is_special, tempShotX, tempShotY, damage, blast, chain, playerNum, tempX2, tempY2 = player_shot_move_and_draw(z)
	if not ok then return end
	temp2 = blast

	for bb = 0, 99 do
		b = bb
		if enemyAvail[bb] == 0 then
			local eb = enemy[bb]
			local collided

			if z == MAX_PWEAPON - 1 then
				temp = 25 - abs(zinglonDuration - 25)
				collided = abs(eb.ex + eb.mapoffset - (player[0].x + 7)) < temp
				temp2 = 9
				chain = 0
				damage = 10
			elseif is_special then
				collided = ((eb.enemycycle == 0) and
				            (abs(eb.ex + eb.mapoffset - tempShotX - tempX2) < (25 + tempX2)) and
				            (abs(eb.ey - tempShotY - 12 - tempY2) < (29 + tempY2))) or
				           ((eb.enemycycle > 0) and
				            (abs(eb.ex + eb.mapoffset - tempShotX - tempX2) < (13 + tempX2)) and
				            (abs(eb.ey - tempShotY - 6 - tempY2) < (15 + tempY2)))
			else
				collided = ((eb.enemycycle == 0) and
				            (abs(eb.ex + eb.mapoffset - tempShotX) < 25) and (abs(eb.ey - tempShotY - 12) < 29)) or
				           ((eb.enemycycle > 0) and
				            (abs(eb.ex + eb.mapoffset - tempShotX) < 13) and (abs(eb.ey - tempShotY - 6) < 15))
			end

			if collided then
				if chain > 0 then
					shotMultiPos[SHOT_MISC] = 0
					b = player_shot_create(0, SHOT_MISC, tempShotX, tempShotY, player[0].mouseX, player[0].mouseY, chain, playerNum)
					shotAvail[z] = 0
					return
				end

				infiniteShot = false

				if damage == 99 then
					damage = 0
					doIced = 40
					eb.iced = 40
				else
					doIced = 0
					if damage >= 250 then
						damage = damage - 250
						infiniteShot = true
					end
				end

				-- instant kill cheat (indestructible enemies, armor 255, stay so)
				if cheats.instantKill and damage > 0 and eb.armorleft < 255 then
					damage = 255
				end

				local armorleft = eb.armorleft

				temp = eb.linknum
				if temp == 0 then
					temp = 255
				end

				if eb.armorleft < 255 then
					for i = 0, 1 do
						if temp == boss_bar[i].link_num then
							boss_bar[i].color = 6
						end
					end

					if eb.enemyground then
						eb.filter = temp2
					end

					for ee = 0, 99 do
						local en = enemy[ee]
						if en.linknum == temp and enemyAvail[ee] ~= 1 and en.enemyground then
							if doIced ~= 0 then
								en.iced = doIced
							end
							en.filter = temp2
						end
					end
				end

				if armorleft > damage then
					if z ~= MAX_PWEAPON - 1 then
						if eb.armorleft ~= 255 then
							eb.armorleft = u8(eb.armorleft - damage)
							JE_setupExplosion(tempShotX, tempShotY, 0, 0, false, false)
						else
							JE_doSP(tempShotX + 6, tempShotY + 6, idiv(damage, 2) + 3, idiv(damage, 4) + 2, temp2)
						end
					end

					soundQueue[5] = S_ENEMY_HIT

					if (armorleft - damage <= eb.edlevel) and ((not eb.edamaged) ~= (eb.edani < 0)) then
						for t3 = 0, 99 do
							temp3 = t3
							if enemyAvail[t3] ~= 1 then
								local e3 = enemy[t3]
								local linknum = e3.linknum
								if (t3 == bb) or
								   ((temp ~= 255) and
								    (((e3.edlevel > 0) and (linknum == temp)) or
								     ((enemyContinualDamage and (temp - 100 == linknum)) or
								      ((linknum > 40) and (idiv(linknum, 20) == idiv(temp, 20)) and (linknum <= temp))))) then
									e3.enemycycle = 1

									e3.edamaged = not e3.edamaged

									if e3.edani ~= 0 then
										e3.ani = abs(e3.edani)
										e3.aniactive = 1
										e3.animax = 0
										e3.animin = u8(e3.edgr)
										e3.enemycycle = u8(e3.animin - 1)
									elseif e3.edgr > 0 then
										e3.egr[0] = e3.edgr
										e3.ani = 1
										e3.aniactive = 0
										e3.animax = 0
										e3.animin = 1
									else
										enemyAvail[t3] = 1
										enemyKilled = enemyKilled + 1
									end

									e3.aniwhenfire = 0

									if e3.armorleft > u8(e3.edlevel) then
										e3.armorleft = u8(e3.edlevel)
									end

									local tX = e3.ex + e3.mapoffset
									local tY = e3.ey

									if enemyDat[e3.enemytype].esize ~= 1 then
										JE_setupExplosion(tX, tY - 6, 0, 1, false, false)
									else
										JE_setupExplosionLarge(e3.enemyground, idiv(e3.explonum, 2), tX, tY)
									end
								end
							end
						end
					end
				else
					if (temp == 254) and (superEnemy254Jump > 0) then
						JE_eventJump(superEnemy254Jump)
					end

					for t2 = 0, 99 do
						temp2 = t2
						if enemyAvail[t2] ~= 1 then
							local e2 = enemy[t2]
							temp3 = e2.linknum
							if (t2 == bb) or (temp == 254) or
							   ((temp ~= 255) and ((temp == temp3) or (temp - 100 == temp3) or
							                       ((temp3 > 40) and (idiv(temp3, 20) == idiv(temp, 20)) and (temp3 <= temp)))) then
								local enemy_screen_x = e2.ex + e2.mapoffset

								if e2.special then
									globalFlags[e2.flagnum - 1] = e2.setto
								end

								if genLevel and genLevel.seconds then LevelGen.maybeDrop(e2) end

								if (e2.enemydie > 0) and
								   not ((superArcadeMode ~= SA_NONE) and (enemyDat[e2.enemydie].value == 30000)) then
									local temp_b = b
									tempW = e2.enemydie
									local enemy_offset = t2 - (t2 % 25)
									if enemyDat[tempW].value > 30000 then
										enemy_offset = 0
									end
									b = JE_newEnemy(enemy_offset, tempW, 0)
									if b ~= 0 then
										local nb = enemy[b - 1]
										if (superArcadeMode ~= SA_NONE) and (nb.evalue > 30000) then
											superArcadePowerUp = superArcadePowerUp + 1
											if superArcadePowerUp > 5 then
												superArcadePowerUp = 1
											end
											nb.egr[0] = 5 + superArcadePowerUp * 2
											nb.evalue = 30000 + superArcadePowerUp
										end

										nb.scoreitem = nb.evalue ~= 0

										nb.ex = e2.ex
										nb.ey = e2.ey
									end
									b = temp_b
								end

								if (e2.evalue > 0) and (e2.evalue < 10000) then
									if e2.evalue == 1 then
										cubeMax = cubeMax + 1
									else
										local pi = galagaMode and 0 or playerNum - 1
										player[pi].cash = player[pi].cash + e2.evalue
									end
								end

								if (e2.edlevel == -1) and (temp == temp3) then
									e2.edlevel = 0
									enemyAvail[t2] = 2
									e2.egr[0] = e2.edgr
									e2.ani = 1
									e2.aniactive = 0
									e2.animax = 0
									e2.animin = 1
									e2.edamaged = true
									e2.enemycycle = 1
								else
									enemyAvail[t2] = 1
									enemyKilled = enemyKilled + 1
								end

								if enemyDat[e2.enemytype].esize == 1 then
									JE_setupExplosionLarge(e2.enemyground, e2.explonum, enemy_screen_x, e2.ey)
									soundQueue[6] = S_EXPLOSION_9
								else
									JE_setupExplosion(enemy_screen_x, e2.ey, 0, 1, false, false)
									soundQueue[6] = S_EXPLOSION_8
								end
							end
						end
					end
				end

				if infiniteShot then
					damage = damage + 250
				elseif z ~= MAX_PWEAPON - 1 then
					if damage <= armorleft then
						shotAvail[z] = 0
						return
					else
						playerShotData[z].shotDmg = u8(playerShotData[z].shotDmg - armorleft)
					end
				end
			end
		end
	end
end

-- One iteration of level_loop.  Returns true when the level is over.
local function levelLoopIteration(L)
	starShowVGASpecialCode = b2n(smoothies[9 - 1]) + lshift(b2n(smoothies[6 - 1]), 1)

	if genLevel then
		LevelGen.frame()
	end

	-- Background Wrapping
	if mapYPos <= BKwrap1 then mapYPos = BKwrap1to end
	if mapY2Pos <= BKwrap2 then mapY2Pos = BKwrap2to end
	if mapY3Pos <= BKwrap3 then mapY3Pos = BKwrap3to end

	allPlayersGone = all_players_dead() and
		((player[0].lives.power == 1 and player[0].exploding_ticks == 0) or (not onePlayerAction and not twoPlayerMode)) and
		((player[1].lives.power == 1 and player[1].exploding_ticks == 0) or not twoPlayerMode)

	-- MUSIC FADE
	if musicFade then
		if tempVolume > 10 then
			tempVolume = tempVolume - 1
			set_volume(tempVolume, fxVolume)
		else
			musicFade = false
		end
	end

	if not allPlayersGone and levelEnd > 0 and endLevel then
		play_song(9)
		musicFade = false
	elseif not playing and firstGameOver then
		play_song(levelSong - 1)
	end

	if not endLevel then -- draw HUD
		VGAScreen = VGAScreenSeg

		-- Message Bar
		if textErase > 0 then
			textErase = textErase - 1
			if textErase == 0 then
				blit_sprite(VGAScreenSeg, 16, 189, OPTION_SHAPES, 36)
			end
		end
		if textErase == 0 then JE_drawFlightBar() end

		-- Shield Gen
		if galagaMode then
			for i = 0, 1 do player[i].shield = 0 end

			if player[1].lives.power == 0 or player[1].armor == 0 then
				twoPlayerMode = false
			end

			if player[0].cash >= galagaLife then
				soundQueue[6] = S_EXPLOSION_11
				soundQueue[7] = S_SOUL_OF_ZINGLON

				if player[0].lives.power < 11 then
					player[0].lives.power = player[0].lives.power + 1
				else
					player[0].cash = player[0].cash + 1000
				end

				if galagaLife == 10000 then
					galagaLife = 20000
				else
					galagaLife = galagaLife + 25000
				end
			end
		else
			if twoPlayerMode then
				shieldWait = u8(shieldWait - 1)
				if shieldWait == 0 then
					shieldWait = 15
					for i = 0, 1 do
						if player[i].shield < player[i].shield_max and player[i].is_alive then
							player[i].shield = player[i].shield + 1
						end
					end
					JE_drawShield()
				end
			elseif player[0].is_alive and player[0].shield < player[0].shield_max and power > shieldT then
				shieldWait = u8(shieldWait - 1)
				if shieldWait == 0 then
					shieldWait = 15

					power = power - shieldT

					player[0].shield = player[0].shield + 1
					if player[1].shield < player[0].shield_max then
						player[1].shield = player[1].shield + 1
					end

					JE_drawShield()
				end
			end
		end

		-- Weapon Display
		for i = 0, 1 do
			local item_power = player[twoPlayerMode and i or 0].items.weapon[i].power

			if L.old_weapon_bar[i] ~= item_power then
				L.old_weapon_bar[i] = item_power

				local xx = twoPlayerMode and 286 or 289
				local yy = (i == 0) and (twoPlayerMode and 6 or 17) or (twoPlayerMode and 100 or 38)

				fill_rectangle_xy(VGAScreenSeg, xx, yy, xx + 1 + 10 * 2, yy + 2, 0)

				for j = 1, item_power do
					JE_rectangle(VGAScreen, xx, yy, xx + 1, yy + 2, 115 + j)
					xx = xx + 2
				end
			end
		end

		-- Power Bar
		if twoPlayerMode or onePlayerAction then
			power = 900
		else
			power = power + powerAdd
			if power > 900 then power = 900 end

			temp = u8(idiv(power, 10))

			if temp ~= lastPower then
				if temp > lastPower then
					fill_rectangle_xy(VGAScreenSeg, 269, 113 - 11 - temp, 276, 114 - 11 - lastPower, 113 + idiv(temp, 7))
				else
					fill_rectangle_xy(VGAScreenSeg, 269, 113 - 11 - lastPower, 276, 114 - 11 - temp, 0)
				end
				lastPower = temp
			end
		end

		oldMapX3Ofs = mapX3Ofs

		enemyOnScreen = 0
	end

	-- use game_screen for all the generic drawing functions
	VGAScreen = game_screen

	-- EVENTS
	while eventLoc <= maxEvent and eventRec[eventLoc - 1].eventtime <= curLoc do
		JE_eventSystem()
	end

	-- SMOOTHIES!
	JE_checkSmoothies()
	if anySmoothies then
		VGAScreen = VGAScreen2
	end

	-- BACKGROUND 1
	if forceEvents and backMove == 0 then
		curLoc = curLoc + 1
	end

	if map1YDelayMax > 1 and backMove < 2 then
		backMove = (map1YDelay == 1) and 1 or 0
	end

	if astralDuration == 0 then
		draw_background_1(VGAScreen)
	else
		JE_clr256(VGAScreen)
	end

	map1YDelay = u8(map1YDelay - 1)
	if map1YDelay == 0 then
		map1YDelay = map1YDelayMax

		curLoc = curLoc + backMove
		backPos = backPos + backMove

		if backPos > 27 then
			backPos = backPos - 28
			mapY = mapY - 1
			mapYPos = mapYPos - 14
		end
	end

	if starActive or astralDuration > 0 then
		update_and_draw_starfield(VGAScreen, starfield_speed)
	end

	if processorType > 1 and smoothies[5 - 1] then
		iced_blur_filter(game_screen, VGAScreen)
		VGAScreen = game_screen
	end

	-- BACKGROUND 2
	if background2over == 3 then
		draw_background_2(VGAScreen)
		background2 = true
	end

	if background2over == 0 then
		if not (smoothies[2 - 1] and processorType < 4) and not (smoothies[1 - 1] and processorType == 3) then
			if wild and not background2notTransparent then
				draw_background_2_blend(VGAScreen)
			else
				draw_background_2(VGAScreen)
			end
		end
	end

	if smoothies[0] and processorType > 2 and smoothie_data[0] == 0 then
		lava_filter(game_screen, VGAScreen)
		VGAScreen = game_screen
	end
	if smoothies[2 - 1] and processorType > 2 then
		water_filter(game_screen, VGAScreen)
		VGAScreen = game_screen
	end

	-- Ground Enemy
	local lastEnemyOnScreen = enemyOnScreen

	tempMapXOfs = mapXOfs
	tempBackMove = backMove
	JE_drawEnemy(50)
	JE_drawEnemy(100)

	if enemyOnScreen == 0 or enemyOnScreen == lastEnemyOnScreen then
		if stopBackgroundNum == 1 then
			stopBackgroundNum = 9
		end
	end

	if smoothies[0] and processorType > 2 and smoothie_data[0] > 0 then
		lava_filter(game_screen, VGAScreen)
		VGAScreen = game_screen
	end

	if superWild then
		neat = u16(neat + 3)
		JE_darkenBackground(neat)
	end

	-- BACKGROUND 2
	if not (smoothies[2 - 1] and processorType < 4) and not (smoothies[1 - 1] and processorType == 3) then
		if background2over == 1 then
			if wild and not background2notTransparent then
				draw_background_2_blend(VGAScreen)
			else
				draw_background_2(VGAScreen)
			end
		end
	end

	if superWild then
		neat = u16(neat + 1)
		JE_darkenBackground(neat)
	end

	if background3over == 2 then
		draw_background_3(VGAScreen)
	end

	-- New Enemy
	if enemiesActive and mt_rand() % 100 > levelEnemyFrequency then
		tempW = levelEnemy[mt_rand() % levelEnemyMax]
		if tempW == 2 then
			soundQueue[3] = S_WEAPON_7
		end
		b = JE_newEnemy(0, tempW, 0)
	end

	if processorType > 1 and smoothies[3 - 1] then
		iced_blur_filter(game_screen, VGAScreen)
		VGAScreen = game_screen
	end
	if processorType > 1 and smoothies[4 - 1] then
		blur_filter(game_screen, VGAScreen)
		VGAScreen = game_screen
	end

	-- Draw Sky Enemy
	if not skyEnemyOverAll then
		lastEnemyOnScreen = enemyOnScreen

		tempMapXOfs = mapX2Ofs
		tempBackMove = 0
		JE_drawEnemy(25)

		if enemyOnScreen == lastEnemyOnScreen then
			if stopBackgroundNum == 2 then
				stopBackgroundNum = 9
			end
		end
	end

	if background3over == 0 then
		draw_background_3(VGAScreen)
	end

	-- Draw Top Enemy
	if not topEnemyOver then
		tempMapXOfs = (not background3x1) and oldMapX3Ofs or mapXOfs
		tempBackMove = backMove3
		JE_drawEnemy(75)
	end

	-- Player Shot Images
	for z = 0, MAX_PWEAPON - 1 do
		if shotAvail[z] ~= 0 then
			processPlayerShot(z)
		end
	end

	for i = 0, 1 do
		player[i].last_x_shot_move = player[i].x
		player[i].last_y_shot_move = player[i].y
	end

	-- Collisions Detection
	for i = 0, (twoPlayerMode and 1 or 0) do
		if player[i].is_alive and not endLevel then
			JE_playerCollide(player[i], i + 1)
		end
	end

	if firstGameOver then
		JE_mainGamePlayerFunctions()
	end

	if not endLevel then
		-- Draw Enemy Shots
		for z = 0, ENEMY_SHOT_MAX - 1 do
			if not enemyShotAvail[z] then
				local s = enemyShot[z]
				s.sxm = s.sxm + s.sxc
				s.sx = s.sx + s.sxm

				if s.tx ~= 0 then
					if s.sx > player[0].x then
						if s.sxm > -s.tx then
							s.sxm = s.sxm - 1
						end
					else
						if s.sxm < s.tx then
							s.sxm = s.sxm + 1
						end
					end
				end

				s.sym = s.sym + s.syc
				s.sy = s.sy + s.sym

				if s.ty ~= 0 then
					if s.sy > player[0].y then
						if s.sym > -s.ty then
							s.sym = s.sym - 1
						end
					else
						if s.sym < s.ty then
							s.sym = s.sym + 1
						end
					end
				end

				local dur = s.duration
				s.duration = u8(dur - 1)
				if dur == 0 or s.sy > 190 or s.sy <= -14 or s.sx > 275 or s.sx <= 0 then
					enemyShotAvail[z] = true
				else
					for i = 0, (twoPlayerMode and 1 or 0) do
						local p = player[i]
						if p.is_alive and not cheats.invincible and
						   s.sx > p.x - p.shot_hit_area_x and
						   s.sx < p.x + p.shot_hit_area_x and
						   s.sy > p.y - p.shot_hit_area_y and
						   s.sy < p.y + p.shot_hit_area_y then
							local tX = s.sx
							local tY = s.sy
							temp = s.sdmg

							enemyShotAvail[z] = true

							JE_setupExplosion(tX, tY, 0, 0, false, false)

							if p.invulnerable_ticks == 0 then
								temp = JE_playerDamage(temp, p)
								if temp > 0 then
									p.x_velocity = p.x_velocity + idiv(s.sxm * temp, 2)
									p.y_velocity = p.y_velocity + idiv(s.sym * temp, 2)
								end
							end

							break
						end
					end

					if not enemyShotAvail[z] then
						if s.animax ~= 0 then
							s.animate = s.animate + 1
							if s.animate >= s.animax then
								s.animate = 0
							end
						end

						if s.sgr >= 500 then
							blit_sprite2(VGAScreen, s.sx, s.sy, spriteSheet12, s.sgr + s.animate - 500)
						else
							blit_sprite2(VGAScreen, s.sx, s.sy, spriteSheet8, s.sgr + s.animate)
						end
					end
				end
			end
		end
	end

	if background3over == 1 then
		draw_background_3(VGAScreen)
	end

	-- Draw Top Enemy
	if topEnemyOver then
		tempMapXOfs = (not background3x1) and oldMapX3Ofs or oldMapXOfs
		tempBackMove = backMove3
		JE_drawEnemy(75)
	end

	-- Draw Sky Enemy
	if skyEnemyOverAll then
		lastEnemyOnScreen = enemyOnScreen

		tempMapXOfs = mapX2Ofs
		tempBackMove = 0
		JE_drawEnemy(25)

		if enemyOnScreen == lastEnemyOnScreen then
			if stopBackgroundNum == 2 then
				stopBackgroundNum = 9
			end
		end
	end

	-- Sequenced Explosions
	enemyStillExploding = false
	for i = 0, MAX_REPEATING_EXPLOSIONS - 1 do
		local r = rep_explosions[i]
		if r.ttl ~= 0 then
			enemyStillExploding = true

			if r.delay > 0 then
				r.delay = r.delay - 1
			else
				r.y = r.y + backMove2 + 1
				local tX = r.x + (mt_rand() % 24) - 12
				local tY = r.y + (mt_rand() % 27) - 24

				if r.big then
					JE_setupExplosionLarge(false, 2, tX, tY)

					if r.ttl == 1 or mt_rand() % 5 == 1 then
						soundQueue[7] = S_EXPLOSION_11
					else
						soundQueue[6] = S_EXPLOSION_9
					end

					r.delay = 4 + (mt_rand() % 3)
				else
					JE_setupExplosion(tX, tY, 0, 1, false, false)

					soundQueue[5] = S_EXPLOSION_4

					r.delay = 3
				end

				r.ttl = r.ttl - 1
			end
		end
	end

	-- Draw Explosions
	for j = 0, MAX_EXPLOSIONS - 1 do
		local ex = explosions[j]
		if ex.ttl ~= 0 then
			if not ex.fixedPosition then
				ex.sprite = ex.sprite + 1
				ex.y = ex.y + explodeMove
			elseif ex.followPlayer then
				ex.x = ex.x + explosionFollowAmountX
				ex.y = ex.y + explosionFollowAmountY
			end
			ex.y = ex.y + ex.deltaY

			if ex.y > 200 - 14 then
				ex.ttl = 0
			else
				if explosionTransparent then
					blit_sprite2_blend(VGAScreen, ex.x, ex.y, explosionSpriteSheet, ex.sprite + 1)
				else
					blit_sprite2(VGAScreen, ex.x, ex.y, explosionSpriteSheet, ex.sprite + 1)
				end

				ex.ttl = ex.ttl - 1
			end
		end
	end

	if not portConfigChange then
		portConfigDone = true
	end

	-- BACKGROUND 2
	if not (smoothies[2 - 1] and processorType < 4) and not (smoothies[1 - 1] and processorType == 3) then
		if background2over == 2 then
			if wild and not background2notTransparent then
				draw_background_2_blend(VGAScreen)
			else
				draw_background_2(VGAScreen)
			end
		end
	end

	-- Warning
	if player[0].is_alive and player[0].armor < 6 then
		local armor_amount = player[0].armor

		if armorShipDelay > 0 then
			armorShipDelay = armorShipDelay - 1
		else
			tempW = 560
			b = JE_newEnemy(50, tempW, 0)
			if b > 0 then
				enemy[b - 1].enemydie = 560 + (mt_rand() % 3) + 1
				enemy[b - 1].eyc = s8(enemy[b - 1].eyc - backMove3)
				enemy[b - 1].armorleft = 4
			end
			armorShipDelay = 500
		end

		if (player[0].is_alive and player[0].armor < 6) or
		   (twoPlayerMode and player[1].is_alive and player[1].armor < 6) then
			tempW = armor_amount * 4 + 8
			if warningSoundDelay > tempW then
				warningSoundDelay = tempW
			end

			if warningSoundDelay > 1 then
				warningSoundDelay = warningSoundDelay - 1
			else
				soundQueue[7] = S_WARNING
				warningSoundDelay = tempW
			end

			warningCol = u8(warningCol + warningColChange)
			if warningCol > 113 + (14 - (armor_amount * 2)) then
				warningColChange = -warningColChange
				warningCol = 113 + (14 - (armor_amount * 2))
			elseif warningCol < 113 then
				warningColChange = -warningColChange
			end
			fill_rectangle_xy(VGAScreen, 24, 181, 138, 183, warningCol)
			fill_rectangle_xy(VGAScreen, 175, 181, 287, 183, warningCol)
			fill_rectangle_xy(VGAScreen, 24, 0, 287, 3, warningCol)

			JE_outText(VGAScreen, 140, 178, "WARNING", 7, idiv(warningCol % 16, 2))
		end
	end

	-- Random Explosions
	if randomExplosions and mt_rand() % 10 == 1 then
		JE_setupExplosionLarge(false, 20, mt_rand() % 280, mt_rand() % 180)
	end

	-- The Sound Routine
	if firstGameOver then
		temp = 0
		for t2 = 0, 7 do
			temp2 = t2
			if soundQueue[t2] ~= S_NONE then
				temp = soundQueue[t2]
				if t2 == 3 then
					temp3 = fxPlayVol
				elseif temp == 15 then
					temp3 = idiv(fxPlayVol, 4)
				else
					temp3 = idiv(fxPlayVol, 2)
				end

				multiSamplePlay(temp, t2, temp3)

				soundQueue[t2] = S_NONE
			end
		end
	end

	if returnActive and enemyOnScreen == 0 then
		JE_eventJump(65535)
		returnActive = false
	end

	-- Debug
	debugTime = SDL_GetTicks()

	if debug_ then
		local sm = {}
		for i = 0, 8 do sm[#sm + 1] = smoothies[i] and "1" or "0" end
		JE_outText(VGAScreen, 30, 70, "SM = " .. table.concat(sm), 4, 0)
		JE_outText(VGAScreen, 30, 90, sprintf("Enemies onscreen = %d", enemyOnScreen), 6, 0)

		debugHist = debugHist + debugTime - lastDebugTime
		debugHistCount = debugHistCount + 1
		local fps = debugHist > 0 and debugHistCount / (debugHist * 1e-3) or 0
		JE_outText(VGAScreen, 45, 175, sprintf("X:%d Y:%-5d  %2.3f FPS  %d %d %d %d", (mapX - 1) * 12 + player[0].x, curLoc, fps, player[0].x_velocity, player[0].y_velocity, player[0].x, player[0].y), 15, 3)
		lastDebugTime = debugTime
	end

	if displayTime > 0 then
		displayTime = displayTime - 1
		JE_outTextAndDarken(VGAScreen, 90, 10, miscText[59], 15, u8(flash - 8), FONT_SHAPES)
		flash = u8(flash + flashChange)
		if flash > 4 or flash == 0 then
			flashChange = -flashChange
		end
	end

	-- Pentium Speed Mode?
	if pentiumMode then
		frameCountMax = (frameCountMax == 2) and 3 or 2
	end

	-- Level Timer
	if levelTimer and levelTimerCountdown > 0 then
		levelTimerCountdown = levelTimerCountdown - 1
		if levelTimerCountdown == 0 then
			JE_eventJump(levelTimerJumpTo)
		end

		if levelTimerCountdown > 200 then
			if levelTimerCountdown % 100 == 0 then
				soundQueue[7] = S_WARNING
			end
			if levelTimerCountdown % 10 == 0 then
				soundQueue[6] = S_CLICK
			end
		elseif levelTimerCountdown % 20 == 0 then
			soundQueue[7] = S_WARNING
		end

		JE_textShade(VGAScreen, 140, 6, miscText[66], 7, idiv(levelTimerCountdown % 20, 3), FULL_SHADE)
		JE_dString(VGAScreen, 100, 2, sprintf("%.1f", levelTimerCountdown / 100.0), SMALL_FONT_SHAPES)
	end

	-- GAME OVER
	if not constantPlay and not constantDie then
		if allPlayersGone then
			if player[0].exploding_ticks > 0 or player[1].exploding_ticks > 0 then
				if galagaMode then
					player[1].exploding_ticks = 0
				end
				musicFade = true
			else
				if playDemo or normalBonusLevelCurrent or bonusLevelCurrent then
					reallyEndLevel = true
				else
					JE_dString(VGAScreen, 120, 60, miscText[21], FONT_SHAPES)
				end

				if firstGameOver then
					if not playDemo then
						play_song(SONG_GAMEOVER)
						set_volume(tyrMusicVolume, fxVolume)
					end
					firstGameOver = false
				end

				if not playDemo then
					if hasInput(INPUT_NO_MOTION) then
						reallyEndLevel = true
					end
				end
			end
		end
	end

	if playDemo then
		if hasInput(INPUT_NO_MOTION) then
			reallyEndLevel = true
			stoppedDemo = true
		end
	else
		mouseClearInput()

		if keyboardHasInput() then
			keyboardClearInput()

			skipStarShowVGA = false
			JE_mainKeyboardInput()
			if skipStarShowVGA then
				return false -- goto level_loop
			end
		end

		if pause_pressed then
			pause_pressed = false
			JE_pauseGame()
		end

		if ingamemenu_pressed then
			ingamemenu_pressed = false
			yourInGameMenuRequest = true
			JE_doInGameSetup()
			skipStarShowVGA = true
		end
	end

	-- Test
	JE_drawSP()

	-- Filtration
	if filterActive then
		JE_filterScreen(levelFilter, levelBrightness)
	end

	draw_boss_bar()

	JE_inGameDisplays()

	VGAScreen = VGAScreenSeg

	JE_starShowVGA()

	-- Start backgrounds if no enemies on screen
	if stopBackgroundNum == 9 and backMove == 0 and not enemyStillExploding then
		backMove = 1
		backMove2 = 2
		backMove3 = 3
		explodeMove = 2
		stopBackgroundNum = 0
		stopBackgrounds = false
		if waitToEndLevel then
			endLevel = true
			levelEnd = 40
		end
		if allPlayersGone then
			reallyEndLevel = true
		end
	end

	if not endLevel and enemyOnScreen == 0 then
		if readyToEndLevel and not enemyStillExploding then
			if levelTimerCountdown > 0 then
				levelTimer = false
			end
			readyToEndLevel = false
			endLevel = true
			levelEnd = 40
			if allPlayersGone then
				reallyEndLevel = true
			end
		end
		if stopBackgrounds then
			stopBackgrounds = false
			backMove = 1
			backMove2 = 2
			backMove3 = 3
			explodeMove = 2
		end
	end

	return reallyEndLevel
end

local function resetLevelState()
	fillArray(enemyAvail, 100, 1)
	fillArray(enemyShotAvail, ENEMY_SHOT_MAX, true)

	resetPlayerShots()
	fillArray(shotMultiPos, 11, 0)
	fillArray(shotRepeat, 11, 1)

	fillArray(button, 4, false)

	fillArray(globalFlags, 10, false)

	for i = 0, MAX_EXPLOSIONS - 1 do
		local e = explosions[i]
		e.ttl, e.x, e.y, e.sprite, e.followPlayer, e.fixedPosition, e.deltaY = 0, 0, 0, 0, false, false, 0
	end
	for i = 0, MAX_REPEATING_EXPLOSIONS - 1 do
		local r = rep_explosions[i]
		r.delay, r.ttl, r.x, r.y, r.big = 0, 0, 0, 0, false
	end

	fillArray(soundQueue, 8, 0)
	soundQueue[3] = V_GOOD_LUCK

	fillArray(enemySpriteSheetIds, 4, 0)
	for i = 0, 99 do resetEnemy(enemy[i]) end

	fillArray(SFCurrentCode[0], 21, 0)
	fillArray(SFCurrentCode[1], 21, 0)
	SFExecuted[0] = 0
	SFExecuted[1] = 0
end

function JE_main()
	local first = true

	while true do
		if not first then
			-- start_level:
			keyboardClearInput()
			mouseClearInput()

			mouseSetRelative(false)

			if galagaMode then
				twoPlayerMode = false
			end

			free_sprite2s(enemySpriteSheets[0])
			free_sprite2s(enemySpriteSheets[1])
			free_sprite2s(enemySpriteSheets[2])
			free_sprite2s(enemySpriteSheets[3])

			if genLevel then
				-- generated test level: back to the title, no shop or saves
				difficultyLevel = oldDifficultyLevel
				fade_song()
				fade_black(10)
				return
			end

			if fastPlay ~= 0 then
				smoothScroll = true
				setFrameSpeed(0x4300)
			end

			if playDemo then
				endPlayDemo()
				stop_song()
				fade_black(10)
			elseif recordDemo then
				endRecordDemo()
			end

			difficultyLevel = oldDifficultyLevel

			if not playDemo then
				if (not all_players_dead() or normalBonusLevelCurrent or bonusLevelCurrent) and not playerEndLevel then
					mainLevel = nextLevel
					JE_endLevelAni()
					fade_song()
				else
					fade_song()
					fade_black(10)

					JE_loadGame(11)
					if doNotSaveBackup then
						superTyrian = false
						onePlayerAction = false
						player[0].items.super_arcade_mode = SA_NONE
					end
					if bonusLevelCurrent and not playerEndLevel then
						mainLevel = nextLevel
					end
				end
			end
			doNotSaveBackup = false

			if playDemo then
				return
			end
		end
		first = false

		-- start_level_first:
		set_volume(tyrMusicVolume, fxVolume)

		endLevel = false
		reallyEndLevel = false
		playerEndLevel = false
		extraGame = false

		doNotSaveBackup = false
		JE_loadMap()

		if mainLevel == 0 then
			return
		end

		if not playDemo then
			mouseSetRelative(true)
		end

		fade_song()

		for i = 0, 1 do
			player[i].is_alive = true
		end

		oldDifficultyLevel = difficultyLevel
		if episodeNum == EPISODE_AVAILABLE then
			difficultyLevel = difficultyLevel - 1
		end
		if difficultyLevel < DIFFICULTY_EASY then
			difficultyLevel = DIFFICULTY_EASY
		end

		player[0].x = 100
		player[0].y = 180

		player[1].x = 190
		player[1].y = 180

		for i = 0, 1 do
			for j = 0, 19 do
				player[i].old_x[j] = player[i].x - (19 - j)
				player[i].old_y[j] = player[i].y - 18
			end
			player[i].last_x_shot_move = player[i].x
			player[i].last_y_shot_move = player[i].y
		end

		JE_loadPic(VGAScreen, twoPlayerMode and 6 or 3, false)

		JE_drawOptions()

		JE_outText(VGAScreen, 268, twoPlayerMode and 76 or 118, levelName, 12, 4)

		JE_showVGA()
		JE_gammaCorrect(colors, gammaCorrection)
		fade_palette(colors, 50, 0, 255)

		if not explosionSpriteSheet.data then
			JE_loadCompShapes(explosionSpriteSheet, '6')
		end

		mapY = 300 - 8
		mapY2 = 600 - 8
		mapY3 = 600 - 8
		mapYPos = mapY * 14 - 1
		mapY2Pos = mapY2 * 14 - 1
		mapY3Pos = mapY3 * 15 - 1
		mapXPos = 0
		mapXOfs = 0
		mapX2Pos = 0
		mapX3Pos = 0
		mapX3Ofs = 0
		mapXbpPos = 0
		mapX2bpPos = 0
		mapX3bpPos = 0

		map1YDelay = 1
		map1YDelayMax = 1
		map2YDelay = 1
		map2YDelayMax = 1

		musicFade = false

		backPos = 0
		backPos2 = 0
		backPos3 = 0
		power = 0
		starfield_speed = 1

		JE_getShipInfo()

		for i = 0, 1 do
			player[i].x_velocity = 0
			player[i].y_velocity = 0
			player[i].invulnerable_ticks = 100
		end

		levelEnd = 255
		levelEndWarp = -4
		levelEndFxWait = 0
		warningCol = 120
		warningColChange = 1
		warningSoundDelay = 0
		armorShipDelay = 50

		bonusLevel = false
		readyToEndLevel = false
		firstGameOver = true
		eventLoc = 1
		curLoc = 0
		backMove = 1
		backMove2 = 2
		backMove3 = 3
		explodeMove = 2
		enemiesActive = true
		for t = 0, 2 do
			button[t] = false
		end
		stopBackgrounds = false
		stopBackgroundNum = 0
		background3x1 = false
		background3x1b = false
		background3over = 0
		background2over = 1
		topEnemyOver = false
		skyEnemyOverAll = false
		smallEnemyAdjust = false
		starActive = true
		enemyContinualDamage = false
		levelEnemyFrequency = 96
		quitRequested = false

		for i = 0, 1 do
			boss_bar[i].link_num = 0
		end

		forceEvents = false

		superEnemy254Jump = 0

		filterActive = true
		filterFade = true
		filterFadeStart = false
		levelFilter = -99
		levelBrightness = -14
		levelBrightnessChg = 1

		background2notTransparent = false

		local L = { old_weapon_bar = { [0] = 0, 0 } }

		lastPower = idiv(power, 10)

		JE_drawTextWindow(miscText[20])

		shieldWait = 1
		shieldT = u8(shields[player[0].items.shield].tpwr * 20)

		for i = 0, 1 do
			player[i].shield = shields[player[i].items.shield].mpwr
			player[i].shield_max = player[i].shield * 2
		end

		JE_drawShield()
		JE_drawArmor()

		for i = 0, 1 do
			player[i].superbombs = 0
		end

		cubeMax = 0

		flash = 0
		flashChange = 1
		displayTime = 0

		play_song(levelSong - 1)

		JE_drawPortConfigButtons()

		initialize_starfield()

		JE_setNewGameSpeed()

		set_volume(tyrMusicVolume, fxVolume)

		if not playDemo and not doNotSaveBackup then
			temp = 11
			JE_saveGame(temp, "LAST LEVEL    ")
		end

		twoPlayerLinked = false
		linkGunDirec = M_PI

		for i = 0, 1 do
			calc_purple_balls_needed(player[i])
		end

		damageRate = 2

		chargeWait = 5
		chargeLevel = 0
		chargeMax = 5
		chargeGr = 0
		chargeGrWait = 3

		portConfigChange = false

		totalEnemy = 0
		enemyKilled = 0

		astralDuration = 0

		superArcadePowerUp = 1

		yourInGameMenuRequest = false

		constantLastX = -1

		for i = 0, 1 do
			player[i].exploding_ticks = 0
		end

		resetLevelState()

		zinglonDuration = 0
		specialWait = 0
		nextSpecialWait = 0
		optionAttachmentMove = 0
		optionAttachmentLinked = true

		editShip1 = false
		editShip2 = false

		fillArray(smoothies, 9, false)

		levelTimer = false
		randomExplosions = false

		last_superpixel = 0
		for i = 0, MAX_SUPERPIXELS - 1 do
			local sp = superpixels[i]
			sp.x, sp.y, sp.z, sp.delta_x, sp.delta_y, sp.color = 0, 0, 0, 0, 0, 0
		end

		returnActive = false

		galagaShotFreq = 0

		if galagaMode then
			difficultyLevel = DIFFICULTY_NORMAL
		end
		galagaLife = 10000

		JE_drawOptionLevel()

		BKwrap1, BKwrap1to = 14, 14
		BKwrap2, BKwrap2to = 14, 14
		BKwrap3, BKwrap3to = 15, 15

		-- level_loop:
		while true do
			if levelLoopIteration(L) then
				break
			end
		end
		-- goto start_level
	end
end
