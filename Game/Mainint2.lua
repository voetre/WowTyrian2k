--[[
 WowTyrian2k: a World of Warcraft port of OpenTyrian
 Copyright (C) The OpenTyrian Development Team
 Lua port Copyright (C) 2026 voetre
 Licensed under the GNU General Public License v2 or later (see COPYING).

 mainint.c (part 2): player movement, sidekicks, collisions
]]
local _, ns = ...
setfenv(1, ns.G)

local sin, cos = math.sin, math.cos

-- Street Fighter codes
function JE_SFCodes(playerNum_, PX_, PY_, mouseX_, mouseY_)
	local ship = player[playerNum_ - 1].items.ship

	if playerNum_ == 2 and ship < 15 then
		ship = 0
	end

	if ship < 15 then
		local t2 = b2n(mouseY_ > PY_) + b2n(mouseY_ < PY_) + b2n(PX_ < mouseX_) + b2n(PX_ > mouseX_)
		local t = b2n(mouseY_ > PY_) * 1 + b2n(mouseY_ < PY_) * 2 + b2n(PX_ < mouseX_) * 3 + b2n(PX_ > mouseX_) * 4

		if t == 0 then
			if not button[0] then
				t = 9
				t2 = 1
			else
				t2 = 0
				t = 99
			end
		end

		if t2 == 1 then
			t = t + b2n(button[0]) * 4

			local t3 = superTyrian and 21 or 3
			local code = SFCurrentCode[playerNum_ - 1]
			for c = 0, t3 - 1 do
				local t5 = superTyrian and shipCombosB[c] or shipCombos[ship][c]

				if t5 == 0 then
					code[c] = 0
				else
					local combo = keyboardCombos[t5 - 1]
					local t4 = combo[code[c]]

					if t4 == t then
						code[c] = code[c] + 1

						t4 = combo[code[c]]
						if t4 and t4 > 100 and t4 <= 100 + SPECIAL_NUM then
							code[c] = 0
							SFExecuted[playerNum_ - 1] = t4 - 100
						end
					else
						if t ~= 9 and
						   (t4 - 1) % 4 ~= (t - 1) % 4 and
						   (code[c] == 0 or combo[code[c] - 1] ~= t) then
							code[c] = 0
						end
					end
				end
			end
		end
	end
end

function JE_getName(pnum)
	return miscText[47 + pnum]
end

local function drawShipSprites(this_player, shipGr_, shipGrPtr_, ship_sprite, blitfn)
	if shipGr_ == 0 then
		blitfn(VGAScreen, this_player.x - 17, this_player.y - 7, shipGrPtr_, ship_sprite + 13)
		blitfn(VGAScreen, this_player.x + 7, this_player.y - 7, shipGrPtr_, ship_sprite + 51)
	elseif shipGr_ == 1 then
		blitfn(VGAScreen, this_player.x - 17, this_player.y - 7, shipGrPtr_, 220)
		blitfn(VGAScreen, this_player.x + 7, this_player.y - 7, shipGrPtr_, 222)
	else
		blitfn(VGAScreen, this_player.x - 5, this_player.y - 7, shipGrPtr_, ship_sprite)
	end
end

function JE_playerMovement(this_player, inputDevice_, playerNum_, shipGr_, shipGrPtr_)
	local mouseXC, mouseYC, accelXC, accelYC

	if playerNum_ == 2 or not twoPlayerMode then
		tempW = weaponPort[this_player.items.weapon[REAR_WEAPON].id].opnum
		if this_player.weapon_mode > tempW then
			this_player.weapon_mode = 1
		end
	end

	local link_gun_analog = false
	local link_gun_angle = 0

	-- the `redo:` label of the C code
	while true do
		mouseXC = 0
		mouseYC = 0
		accelXC = 0
		accelYC = 0

		local redo = false

		if not this_player.is_alive then
			if this_player.exploding_ticks > 0 then
				this_player.exploding_ticks = this_player.exploding_ticks - 1

				if levelEndFxWait > 0 then
					levelEndFxWait = levelEndFxWait - 1
				else
					levelEndFxWait = (mt_rand() % 6) + 3
					if (mt_rand() % 3) == 1 then
						soundQueue[6] = S_EXPLOSION_9
					else
						soundQueue[5] = S_EXPLOSION_11
					end
				end

				local explosion_x = this_player.x + (mt_rand() % 32) - 16
				local explosion_y = this_player.y + (mt_rand() % 32) - 16
				JE_setupExplosionLarge(false, 0, explosion_x, explosion_y + 7)
				JE_setupExplosionLarge(false, 0, this_player.x, this_player.y + 7)

				if levelEnd > 0 then
					levelEnd = levelEnd - 1
				end
			else
				if twoPlayerMode or onePlayerAction then
					if this_player.lives.power > 1 then
						this_player.lives.power = this_player.lives.power - 1

						reallyEndLevel = false
						shotMultiPos[playerNum_ - 1] = 0
						calc_purple_balls_needed(this_player)
						twoPlayerLinked = false
						if galagaMode then
							twoPlayerMode = false
						end
						this_player.y = 160
						this_player.invulnerable_ticks = 100
						this_player.is_alive = true
						endLevel = false

						if galagaMode or episodeNum == 4 then
							this_player.armor = this_player.initial_armor
						else
							this_player.armor = idiv(this_player.initial_armor, 2)
						end

						if galagaMode then
							this_player.shield = 0
						else
							this_player.shield = idiv(this_player.shield_max, 2)
						end

						VGAScreen = VGAScreenSeg
						JE_drawArmor()
						JE_drawShield()
						VGAScreen = game_screen
						redo = true
					else
						if galagaMode then
							twoPlayerMode = false
						end
					end
				end
			end
		elseif constantDie then
			if this_player.exploding_ticks == 0 then
				this_player.shield = 0

				if this_player.armor > 0 then
					this_player.armor = this_player.armor - 1
				else
					this_player.is_alive = false
					this_player.exploding_ticks = 60
					levelEnd = 40
				end

				JE_wipeShieldArmorBars()
				VGAScreen = VGAScreenSeg
				JE_drawArmor()
				VGAScreen = game_screen

				if player[0].lives.power < 11 then
					player[0].lives.power = player[0].lives.power + 1
				end
			end
		end

		if not redo then break end
	end

	if not this_player.is_alive then
		explosionFollowAmountX = 0
		explosionFollowAmountY = 0
		return
	end

	if not endLevel then
		this_player.mouseX = this_player.x
		this_player.mouseY = this_player.y
		button[0] = false
		button[1] = false
		button[2] = false
		button[3] = false

		-- Movement Routine Beginning
		if endLevel then
			this_player.y = this_player.y - 2
		else
			if playDemo or recordDemo then
				inputDevice_ = 1
			end

			if playDemo then
				if not playDemoKeys() then
					endLevel = true
					levelEnd = 40
				end
			end

			-- mouse input
			if (inputDevice_ == 0 or inputDevice_ == 2) and has_mouse and ns.mouseControl then
				button[0] = button[0] or band(mouseButtonsDown, SDL_BUTTON_LMASK) ~= 0
				button[1] = button[1] or band(mouseButtonsDown, SDL_BUTTON_RMASK) ~= 0
				button[2] = button[2] or band(mouseButtonsDown, mouse_has_three_buttons and SDL_BUTTON_MMASK or SDL_BUTTON_RMASK) ~= 0

				local mouseXR, mouseYR = mouseGetRelativePosition()
				mouseXC = mouseXC + mouseXR
				mouseYC = mouseYC + mouseYR
			end

			-- keyboard input
			if (inputDevice_ == 0 or inputDevice_ == 1) and not playDemo then
				if keysactive[keySettings[KEY_SETTING_UP]] then
					this_player.y = this_player.y - CURRENT_KEY_SPEED
				end
				if keysactive[keySettings[KEY_SETTING_DOWN]] then
					this_player.y = this_player.y + CURRENT_KEY_SPEED
				end
				if keysactive[keySettings[KEY_SETTING_LEFT]] then
					this_player.x = this_player.x - CURRENT_KEY_SPEED
				end
				if keysactive[keySettings[KEY_SETTING_RIGHT]] then
					this_player.x = this_player.x + CURRENT_KEY_SPEED
				end

				button[0] = button[0] or keysactive[keySettings[KEY_SETTING_FIRE]]
				button[3] = button[3] or keysactive[keySettings[KEY_SETTING_CHANGE_FIRE]]
				button[1] = button[1] or keysactive[keySettings[KEY_SETTING_LEFT_SIDEKICK]]
				button[2] = button[2] or keysactive[keySettings[KEY_SETTING_RIGHT_SIDEKICK]]

				if constantPlay then
					for i = 0, 3 do button[i] = true end
					this_player.y = this_player.y + 1
					this_player.x = this_player.x + constantLastX
				end

				if recordDemo then
					recordDemoKeys()
				end
			end

			if smoothies[9 - 1] then
				this_player.mouseY = this_player.y - (this_player.mouseY - this_player.y)
				mouseYC = -mouseYC
			end

			accelXC = accelXC + this_player.x - this_player.mouseX
			accelYC = accelYC + this_player.y - this_player.mouseY

			if mouseXC > 30 then mouseXC = 30 elseif mouseXC < -30 then mouseXC = -30 end
			if mouseYC > 30 then mouseYC = 30 elseif mouseYC < -30 then mouseYC = -30 end

			if mouseXC > 0 then
				this_player.x = this_player.x + idiv(mouseXC + 3, 4)
			elseif mouseXC < 0 then
				this_player.x = this_player.x + idiv(mouseXC - 3, 4)
			end
			if mouseYC > 0 then
				this_player.y = this_player.y + idiv(mouseYC + 3, 4)
			elseif mouseYC < 0 then
				this_player.y = this_player.y + idiv(mouseYC - 3, 4)
			end

			if mouseXC > 3 then
				accelXC = accelXC + 1
			elseif mouseXC < -2 then
				accelXC = accelXC - 1
			end
			if mouseYC > 2 then
				accelYC = accelYC + 1
			elseif mouseYC < -2 then
				accelYC = accelYC - 1
			end
		end

		moveOk = true

		JE_SFCodes(playerNum_, this_player.x, this_player.y, this_player.mouseX, this_player.mouseY)

		if moveOk then
			-- Link gun of the Galaga wingman (the only second ship in this port)
			if twoPlayerMode and twoPlayerLinked and playerNum_ == 2 and
			   (this_player.x ~= this_player.mouseX or this_player.y ~= this_player.mouseY) then
				if button[0] then
					if link_gun_analog then
						linkGunDirec = link_gun_angle
					else
						local tempR
						if abs(this_player.x - this_player.mouseX) > abs(this_player.y - this_player.mouseY) then
							tempR = (this_player.x - this_player.mouseX > 0) and M_PI_2 or (M_PI + M_PI_2)
						else
							tempR = (this_player.y - this_player.mouseY > 0) and 0 or M_PI
						end

						if abs(linkGunDirec - tempR) < 0.3 then
							linkGunDirec = tempR
						elseif linkGunDirec < tempR and linkGunDirec - tempR > -3.24 then
							linkGunDirec = linkGunDirec + 0.2
						elseif linkGunDirec - tempR < M_PI then
							linkGunDirec = linkGunDirec - 0.2
						else
							linkGunDirec = linkGunDirec + 0.2
						end
					end

					if linkGunDirec >= (2 * M_PI) then
						linkGunDirec = linkGunDirec - (2 * M_PI)
					elseif linkGunDirec < 0 then
						linkGunDirec = linkGunDirec + (2 * M_PI)
					end
				end
			end
		end
	end

	if levelEnd > 0 and all_players_dead() then
		reallyEndLevel = true
	end

	-- End Level Fade-Out
	if this_player.is_alive and endLevel then
		if levelEnd == 0 then
			reallyEndLevel = true
		else
			this_player.y = this_player.y - levelEndWarp
			if this_player.y < -200 then
				reallyEndLevel = true
			end

			local trail_spacing = 1
			local trail_y = this_player.y
			local num_trails = abs(41 - levelEnd)
			if num_trails > 20 then num_trails = 20 end

			for i = 0, num_trails - 1 do
				trail_y = trail_y + trail_spacing
				trail_spacing = trail_spacing + 1
			end

			for i = 1, num_trails - 1 do
				trail_y = trail_y - trail_spacing
				trail_spacing = trail_spacing - 1

				if trail_y > 0 and trail_y < 170 then
					if shipGr_ == 0 then
						blit_sprite2x2(VGAScreen, this_player.x - 17, trail_y - 7, shipGrPtr_, 13)
						blit_sprite2x2(VGAScreen, this_player.x + 7, trail_y - 7, shipGrPtr_, 51)
					elseif shipGr_ == 1 then
						blit_sprite2x2(VGAScreen, this_player.x - 17, trail_y - 7, shipGrPtr_, 220)
						blit_sprite2x2(VGAScreen, this_player.x + 7, trail_y - 7, shipGrPtr_, 222)
					else
						blit_sprite2x2(VGAScreen, this_player.x - 5, trail_y - 7, shipGrPtr_, shipGr_)
					end
				end
			end
		end
	end

	if playDemo then
		JE_dString(VGAScreen, 115, 10, miscText[7], SMALL_FONT_SHAPES)
	end

	local ship_banking = 0

	if this_player.is_alive and not endLevel then
		if not twoPlayerLinked or playerNum_ < 2 then
			if not twoPlayerMode or shipGr2 ~= 0 then
				if this_player.sidekick[LEFT_SIDEKICK].style == 0 then
					this_player.sidekick[LEFT_SIDEKICK].x = this_player.mouseX - 14
					this_player.sidekick[LEFT_SIDEKICK].y = this_player.mouseY
				end
				if this_player.sidekick[RIGHT_SIDEKICK].style == 0 then
					this_player.sidekick[RIGHT_SIDEKICK].x = this_player.mouseX + 16
					this_player.sidekick[RIGHT_SIDEKICK].y = this_player.mouseY
				end
			end

			if this_player.x_friction_ticks > 0 then
				this_player.x_friction_ticks = this_player.x_friction_ticks - 1
			else
				this_player.x_friction_ticks = 1
				if this_player.x_velocity < 0 then
					this_player.x_velocity = this_player.x_velocity + 1
				elseif this_player.x_velocity > 0 then
					this_player.x_velocity = this_player.x_velocity - 1
				end
			end

			if this_player.y_friction_ticks > 0 then
				this_player.y_friction_ticks = this_player.y_friction_ticks - 1
			else
				this_player.y_friction_ticks = 2
				if this_player.y_velocity < 0 then
					this_player.y_velocity = this_player.y_velocity + 1
				elseif this_player.y_velocity > 0 then
					this_player.y_velocity = this_player.y_velocity - 1
				end
			end

			this_player.x_velocity = this_player.x_velocity + accelXC
			this_player.y_velocity = this_player.y_velocity + accelYC

			this_player.x_velocity = MIN(MAX(-4, this_player.x_velocity), 4)
			this_player.y_velocity = MIN(MAX(-4, this_player.y_velocity), 4)

			this_player.x = this_player.x + this_player.x_velocity
			this_player.y = this_player.y + this_player.y_velocity

			if this_player.x - this_player.mouseX ~= 0 or this_player.y - this_player.mouseY ~= 0 then
				for i = 1, 19 do
					this_player.old_x[i - 1] = this_player.old_x[i]
					this_player.old_y[i - 1] = this_player.old_y[i]
				end
				this_player.old_x[19] = this_player.x
				this_player.old_y[19] = this_player.y
			end
		else -- twoPlayerLinked
			if shipGr_ == 0 then
				this_player.x = player[0].x - 1
			else
				this_player.x = player[0].x
			end
			this_player.y = player[0].y + 8

			this_player.x_velocity = player[0].x_velocity
			this_player.y_velocity = 4

			shotMultiPos[SHOT_MISC] = 0
			b = player_shot_create(0, SHOT_MISC, this_player.x + 1 + roundf(sin(linkGunDirec + 0.2) * 26), this_player.y + roundf(cos(linkGunDirec + 0.2) * 26), this_player.mouseX, this_player.mouseY, 148, playerNum_)
			shotMultiPos[SHOT_MISC] = 0
			b = player_shot_create(0, SHOT_MISC, this_player.x + 1 + roundf(sin(linkGunDirec - 0.2) * 26), this_player.y + roundf(cos(linkGunDirec - 0.2) * 26), this_player.mouseX, this_player.mouseY, 148, playerNum_)
			shotMultiPos[SHOT_MISC] = 0
			b = player_shot_create(0, SHOT_MISC, this_player.x + 1 + roundf(sin(linkGunDirec) * 26), this_player.y + roundf(cos(linkGunDirec) * 26), this_player.mouseX, this_player.mouseY, 147, playerNum_)

			if shotRepeat[SHOT_REAR] > 0 then
				shotRepeat[SHOT_REAR] = shotRepeat[SHOT_REAR] - 1
			elseif button[0] then
				shotMultiPos[SHOT_REAR] = 0
				b = player_shot_create(0, SHOT_REAR, this_player.x + 1 + roundf(sin(linkGunDirec) * 20), this_player.y + roundf(cos(linkGunDirec) * 20), this_player.mouseX, this_player.mouseY, linkGunWeapons[this_player.items.weapon[REAR_WEAPON].id - 1], playerNum_)
				player_shot_set_direction(b, this_player.items.weapon[REAR_WEAPON].id, linkGunDirec)
			end
		end
	end

	if not endLevel then
		if this_player.x > 256 then
			this_player.x = 256
			constantLastX = -constantLastX
		end
		if this_player.x < 40 then
			this_player.x = 40
			constantLastX = -constantLastX
		end

		if this_player.y > 160 then
			this_player.y = 160
		end
		if this_player.y < 10 then
			this_player.y = 10
		end

		ship_banking = idiv(this_player.x_velocity, 2) + idiv(this_player.x - this_player.mouseX, 6)
		ship_banking = MAX(-2, MIN(ship_banking, 2))

		local ship_sprite = ship_banking * 2 + shipGr_

		explosionFollowAmountX = this_player.x - this_player.last_x_explosion_follow
		explosionFollowAmountY = this_player.y - this_player.last_y_explosion_follow

		if explosionFollowAmountY < 0 then
			explosionFollowAmountY = 0
		end

		this_player.last_x_explosion_follow = this_player.x
		this_player.last_y_explosion_follow = this_player.y

		if background2 then
			local sx = -mapX2Ofs + 30
			if shipGr_ == 0 then
				blit_sprite2x2_darken(VGAScreen, this_player.x - 17 + sx, this_player.y - 7 + shadowYDist, shipGrPtr_, ship_sprite + 13)
				blit_sprite2x2_darken(VGAScreen, this_player.x + 7 + sx, this_player.y - 7 + shadowYDist, shipGrPtr_, ship_sprite + 51)
			elseif shipGr_ == 1 then
				blit_sprite2x2_darken(VGAScreen, this_player.x - 17 + sx, this_player.y - 7 + shadowYDist, shipGrPtr_, 220)
				blit_sprite2x2_darken(VGAScreen, this_player.x + 7 + sx, this_player.y - 7 + shadowYDist, shipGrPtr_, 222)
			else
				blit_sprite2x2_darken(VGAScreen, this_player.x - 5 + sx, this_player.y - 7 + shadowYDist, shipGrPtr_, ship_sprite)
			end
		end

		if this_player.invulnerable_ticks > 0 then
			this_player.invulnerable_ticks = this_player.invulnerable_ticks - 1
			drawShipSprites(this_player, shipGr_, shipGrPtr_, ship_sprite, blit_sprite2x2_blend)
		else
			drawShipSprites(this_player, shipGr_, shipGrPtr_, ship_sprite, blit_sprite2x2)

			if shipGr_ == 1 then
				local nb = 0
				if ship_sprite == 5 then
					blit_sprite2(VGAScreen, this_player.x - 17, this_player.y + 7, shipGrPtr_, 40)
					tempW = this_player.x - 7
					nb = -2
				elseif ship_sprite == 3 then
					blit_sprite2(VGAScreen, this_player.x - 17, this_player.y + 7, shipGrPtr_, 39)
					tempW = this_player.x - 7
					nb = -1
				elseif ship_sprite == -1 then
					blit_sprite2(VGAScreen, this_player.x + 19, this_player.y + 7, shipGrPtr_, 58)
					tempW = this_player.x + 9
					nb = 1
				elseif ship_sprite == -3 then
					blit_sprite2(VGAScreen, this_player.x + 19, this_player.y + 7, shipGrPtr_, 59)
					tempW = this_player.x + 9
					nb = 2
				end
				if nb ~= 0 then
					if shotRepeat[SHOT_NORTSPARKS] > 0 then
						shotRepeat[SHOT_NORTSPARKS] = shotRepeat[SHOT_NORTSPARKS] - 1
					else
						b = player_shot_create(0, SHOT_NORTSPARKS, tempW + (mt_rand() % 8) - 4, this_player.y + (mt_rand() % 8) - 4, this_player.mouseX, this_player.mouseY, 671, 1)
						shotRepeat[SHOT_NORTSPARKS] = abs(nb) - 1
					end
				end
			end
		end

		-- Options Location
		if playerNum_ == 2 and shipGr_ == 0 then
			if this_player.sidekick[LEFT_SIDEKICK].style == 0 then
				this_player.sidekick[LEFT_SIDEKICK].x = this_player.x - 14 + ship_banking * 2
				this_player.sidekick[LEFT_SIDEKICK].y = this_player.y
			end
			if this_player.sidekick[RIGHT_SIDEKICK].style == 0 then
				this_player.sidekick[RIGHT_SIDEKICK].x = this_player.x + 17 + ship_banking * 2
				this_player.sidekick[RIGHT_SIDEKICK].y = this_player.y
			end
		end
	end

	if moveOk then
		if this_player.is_alive then
			if not endLevel then
				this_player.delta_x_shot_move = this_player.x - this_player.last_x_shot_move
				this_player.delta_y_shot_move = this_player.y - this_player.last_y_shot_move

				-- PLAYER SHOT Change
				if button[3] then
					portConfigChange = true
					if portConfigDone then
						shotMultiPos[SHOT_REAR] = 0

						if superArcadeMode ~= SA_NONE and superArcadeMode <= SA_NORTSHIPZ then
							shotMultiPos[SHOT_SPECIAL] = 0
							shotMultiPos[SHOT_SPECIAL2] = 0
							if player[0].items.special == SASpecialWeapon[superArcadeMode - 1] then
								player[0].items.special = SASpecialWeaponB[superArcadeMode - 1]
								this_player.weapon_mode = 2
							else
								player[0].items.special = SASpecialWeapon[superArcadeMode - 1]
								this_player.weapon_mode = 1
							end
						else
							this_player.weapon_mode = this_player.weapon_mode + 1
							if this_player.weapon_mode > JE_portConfigs() then
								this_player.weapon_mode = 1
							end
						end

						JE_drawPortConfigButtons()
						portConfigDone = false
					end
				end

				-- SpecialShot
				if not galagaMode then
					JE_doSpecialShot(playerNum_, this_player)
				end

				-- Normal Main Weapons
				if not (twoPlayerLinked and playerNum_ == 2) then
					local mn, mx
					if not twoPlayerMode then
						mn, mx = 1, 2
					else
						mn, mx = playerNum_, playerNum_
					end

					for t = mn - 1, mx - 1 do
						temp = t
						local item = this_player.items.weapon[t].id
						if item > 0 then
							if shotRepeat[t] > 0 then
								shotRepeat[t] = shotRepeat[t] - 1
							elseif button[0] then
								local item_power = galagaMode and 0 or this_player.items.weapon[t].power - 1
								local item_mode = (t == REAR_WEAPON) and this_player.weapon_mode - 1 or 0
								local op = weaponPort[item].op[item_mode]
								b = player_shot_create(item, t, this_player.x, this_player.y, this_player.mouseX, this_player.mouseY, op and op[item_power] or 0, playerNum_)
							end
						end
					end
				end

				-- Super Charge Weapons
				if playerNum_ == 2 then
					if not twoPlayerLinked then
						blit_sprite2(VGAScreen, this_player.x + b2n(shipGr_ == 0) + 1, this_player.y - 13, spriteSheet10, 77 + chargeLevel + chargeGr * 19)
					end

					if chargeGrWait > 0 then
						chargeGrWait = chargeGrWait - 1
					else
						chargeGr = chargeGr + 1
						if chargeGr == 4 then chargeGr = 0 end
						chargeGrWait = 3
					end

					if chargeLevel > 0 then
						fill_rectangle_xy(VGAScreenSeg, 269, 107 + (chargeLevel - 1) * 3, 275, 108 + (chargeLevel - 1) * 3, 193)
					end

					if chargeWait > 0 then
						chargeWait = chargeWait - 1
					else
						if chargeLevel < chargeMax then
							chargeLevel = chargeLevel + 1
						end

						chargeWait = u8(28 - this_player.items.weapon[REAR_WEAPON].power * 2)
						if difficultyLevel > DIFFICULTY_HARD then
							chargeWait = u8(chargeWait - 5)
						end
					end

					if chargeLevel > 0 then
						fill_rectangle_xy(VGAScreenSeg, 269, 107 + (chargeLevel - 1) * 3, 275, 108 + (chargeLevel - 1) * 3, 204)
					end

					if shotRepeat[SHOT_P2_CHARGE] > 0 then
						shotRepeat[SHOT_P2_CHARGE] = shotRepeat[SHOT_P2_CHARGE] - 1
					elseif button[0] and (not twoPlayerLinked or chargeLevel > 0) then
						shotMultiPos[SHOT_P2_CHARGE] = 0
						b = player_shot_create(16, SHOT_P2_CHARGE, this_player.x, this_player.y, this_player.mouseX, this_player.mouseY, chargeGunWeapons[player[1].items.weapon[REAR_WEAPON].id - 1] + chargeLevel, playerNum_)

						if chargeLevel > 0 then
							fill_rectangle_xy(VGAScreenSeg, 269, 107 + (chargeLevel - 1) * 3, 275, 108 + (chargeLevel - 1) * 3, 193)
						end

						chargeLevel = 0
						chargeWait = u8(30 - this_player.items.weapon[REAR_WEAPON].power * 2)
					end
				end

				-- SUPER BOMB
				local pt = playerNum_
				if pt == 0 then pt = 1 end

				if player[pt - 1].superbombs > 0 then
					if shotRepeat[SHOT_P1_SUPERBOMB + pt - 1] > 0 then
						shotRepeat[SHOT_P1_SUPERBOMB + pt - 1] = shotRepeat[SHOT_P1_SUPERBOMB + pt - 1] - 1
					elseif button[2] or button[1] then
						player[pt - 1].superbombs = player[pt - 1].superbombs - 1
						shotMultiPos[SHOT_P1_SUPERBOMB + pt - 1] = 0
						b = player_shot_create(16, SHOT_P1_SUPERBOMB + pt - 1, this_player.x, this_player.y, this_player.mouseX, this_player.mouseY, 535, playerNum_)
					end
				end

				-- sidekicks
				local lsk, rsk = this_player.sidekick[LEFT_SIDEKICK], this_player.sidekick[RIGHT_SIDEKICK]

				if lsk.style == 4 and rsk.style == 4 then
					optionSatelliteRotate = optionSatelliteRotate + 0.2
				elseif lsk.style == 4 or rsk.style == 4 then
					optionSatelliteRotate = optionSatelliteRotate + 0.15
				end

				local ls = lsk.style
				if ls == 1 or ls == 3 then
					lsk.x = this_player.old_x[9]
					lsk.y = this_player.old_y[9]
				elseif ls == 2 then
					lsk.x = this_player.x
					lsk.y = MAX(10, this_player.y - 20)
				elseif ls == 4 then
					lsk.x = this_player.x + roundf(sin(optionSatelliteRotate) * 20)
					lsk.y = this_player.y + roundf(cos(optionSatelliteRotate) * 20)
				end

				local rs = rsk.style
				if rs == 4 then
					rsk.x = this_player.x - roundf(sin(optionSatelliteRotate) * 20)
					rsk.y = this_player.y - roundf(cos(optionSatelliteRotate) * 20)
				elseif rs == 1 or rs == 3 then
					rsk.x = this_player.old_x[0]
					rsk.y = this_player.old_y[0]
				elseif rs == 2 then
					if not optionAttachmentLinked then
						rsk.y = rsk.y + idiv(optionAttachmentMove, 2)
						if optionAttachmentMove >= -2 then
							local ret = b2n(optionAttachmentReturn)
							local t
							if optionAttachmentReturn then t = 2 else t = 0 end

							if rsk.y > (this_player.y - 20) + 5 then
								t = 2
								optionAttachmentMove = optionAttachmentMove - (1 + ret)
							elseif rsk.y > (this_player.y - 20) - 0 then
								t = 3
								if optionAttachmentMove > 0 then
									optionAttachmentMove = optionAttachmentMove - 1
								else
									optionAttachmentMove = optionAttachmentMove + 1
								end
							elseif rsk.y > (this_player.y - 20) - 5 then
								t = 2
								optionAttachmentMove = optionAttachmentMove + 1
							elseif optionAttachmentMove < 2 + ret * 4 then
								optionAttachmentMove = optionAttachmentMove + 1 + ret
							end

							if optionAttachmentReturn then
								t = t * 2
							end
							if abs(rsk.x - this_player.x) < t then
								t = 1
							end

							if rsk.x > this_player.x then
								rsk.x = rsk.x - t
							elseif rsk.x < this_player.x then
								rsk.x = rsk.x + t
							end

							if abs(rsk.y - (this_player.y - 20)) + abs(rsk.x - this_player.x) < 8 then
								optionAttachmentLinked = true
								soundQueue[2] = S_CLINK
							end

							if button[2] then
								optionAttachmentReturn = true
							end
							temp = t
						else
							optionAttachmentMove = optionAttachmentMove + 1 + b2n(optionAttachmentReturn)
							JE_setupExplosion(rsk.x + 1, rsk.y + 10, 0, 0, false, false)
						end
					else
						rsk.x = this_player.x
						rsk.y = this_player.y - 20
						if button[2] then
							optionAttachmentLinked = false
							optionAttachmentReturn = false
							optionAttachmentMove = -20
							soundQueue[3] = S_WEAPON_26
						end
					end

					if rsk.y < 10 then
						rsk.y = 10
					end
				end

				if playerNum_ == 2 or not twoPlayerMode then
					for i = 0, 1 do
						local shot_i = (i == 0) and SHOT_LEFT_SIDEKICK or SHOT_RIGHT_SIDEKICK
						local this_option = options[this_player.items.sidekick[i]]
						local sk = this_player.sidekick[i]

						if this_option.wport > 0 then
							if shotRepeat[shot_i] > 0 then
								shotRepeat[shot_i] = shotRepeat[shot_i] - 1
							else
								local ammo_max = sk.ammo_max

								if ammo_max > 0 then
									if sk.ammo_refill_ticks > 0 then
										sk.ammo_refill_ticks = sk.ammo_refill_ticks - 1
									else
										sk.ammo_refill_ticks = sk.ammo_refill_ticks_max

										if sk.ammo < ammo_max then
											sk.ammo = sk.ammo + 1
										end

										local yy = hud_sidekick_y[twoPlayerMode and 1 or 0][i] + 13
										draw_segmented_gauge(VGAScreenSeg, 284, yy, 112, 2, 2, MAX(1, idiv(ammo_max, 10)), sk.ammo)
									end

									if button[1 + i] and sk.ammo > 0 then
										b = player_shot_create(this_option.wport, shot_i, sk.x, sk.y, this_player.mouseX, this_player.mouseY, this_option.wpnum + sk.charge, playerNum_)

										sk.ammo = sk.ammo - 1
										if sk.charge > 0 then
											shotMultiPos[shot_i] = 0
											sk.charge = 0
										end
										sk.charge_ticks = 20
										sk.animation_enabled = true

										local yy = hud_sidekick_y[twoPlayerMode and 1 or 0][i] + 13
										fill_rectangle_xy(VGAScreenSeg, 284, yy, 312, yy + 2, 0)
										draw_segmented_gauge(VGAScreenSeg, 284, yy, 112, 2, 2, MAX(1, idiv(ammo_max, 10)), sk.ammo)
									end
								else
									if button[0] or button[1 + i] then
										b = player_shot_create(this_option.wport, shot_i, sk.x, sk.y, this_player.mouseX, this_player.mouseY, this_option.wpnum + sk.charge, playerNum_)

										if sk.charge > 0 then
											shotMultiPos[shot_i] = 0
											sk.charge = 0
										end
										sk.charge_ticks = 20
										sk.animation_enabled = true
									end
								end
							end
						end
					end
				end
			end
		end
	end

	-- draw sidekicks
	if (playerNum_ == 2 or not twoPlayerMode) and not endLevel then
		for i = 0, 1 do
			local this_option = options[this_player.items.sidekick[i]]
			local sk = this_player.sidekick[i]

			if this_option.option > 0 then
				if sk.animation_enabled then
					sk.animation_frame = sk.animation_frame + 1
					if sk.animation_frame >= this_option.ani then
						sk.animation_frame = 0
						sk.animation_enabled = (this_option.option == 1)
					end
				end

				local xx, yy = sk.x, sk.y
				local spr = this_option.gr[sk.animation_frame] + sk.charge

				if sk.style == 1 or sk.style == 2 then
					blit_sprite2x2(VGAScreen, xx - 6, yy, spriteSheet10, spr)
				else
					blit_sprite2(VGAScreen, xx, yy, spriteSheet9, spr)
				end
			end

			sk.charge_ticks = sk.charge_ticks - 1
			if sk.charge_ticks == 0 then
				if sk.charge < this_option.pwr then
					sk.charge = sk.charge + 1
				end
				sk.charge_ticks = 20
			end
		end
	end
end

function JE_mainGamePlayerFunctions()
	applyCheats()

	if endLevel and levelEnd > 0 then
		levelEnd = levelEnd - 1
		levelEndWarp = levelEndWarp + 1
	end

	SFExecuted[0] = 0
	SFExecuted[1] = 0

	portConfigChange = false

	if twoPlayerMode then
		JE_playerMovement(player[0], 0, 1, shipGr, shipGrPtr)
		JE_playerMovement(player[1], 0, 2, shipGr2, shipGr2ptr)
	else
		JE_playerMovement(player[0], 0, 1, shipGr, shipGrPtr)
	end

	-- Parallax Map Scrolling
	local tempX
	if twoPlayerMode then
		tempX = idiv(player[0].x + player[1].x, 2)
	else
		tempX = player[0].x
	end

	tempW = u16(math.floor((260 - (tempX - 36)) / (260 - 36) * (24 * 3) - 1))
	mapX3Ofs = tempW
	mapX3Pos = mapX3Ofs % 24
	mapX3bpPos = 1 - idiv(mapX3Ofs, 24)

	mapX2Ofs = idiv(tempW * 2, 3)
	mapX2Pos = mapX2Ofs % 24
	mapX2bpPos = 1 - idiv(mapX2Ofs, 24)

	oldMapXOfs = mapXOfs
	mapXOfs = idiv(mapX2Ofs, 2)
	mapXPos = mapXOfs % 24
	mapXbpPos = 1 - idiv(mapXOfs, 24)

	if background3x1 then
		mapX3Ofs = mapXOfs
		mapX3Pos = mapXPos
		mapX3bpPos = mapXbpPos - 1
	end
end

function JE_playerCollide(this_player, playerNum_)
	for z = 0, 99 do
		if enemyAvail[z] ~= 1 then
			local ez = enemy[z]
			local enemy_screen_x = ez.ex + ez.mapoffset

			if abs(this_player.x - enemy_screen_x) < 12 and abs(this_player.y - ez.ey) < 14 then
				local evalue = ez.evalue
				if evalue > 29999 then
					if evalue == 30000 then
						this_player.cash = this_player.cash + 100

						if not galagaMode then
							handle_got_purple_ball(this_player)
						else
							if twoPlayerMode then
								this_player.cash = this_player.cash + 2400
							end
							twoPlayerMode = true
							twoPlayerLinked = true
							player[1].items.weapon[REAR_WEAPON].power = 1
							player[1].armor = 10
							player[1].is_alive = true
						end
						enemyAvail[z] = 1
						soundQueue[7] = S_POWERUP
					elseif superArcadeMode ~= SA_NONE and evalue > 30000 then
						shotMultiPos[SHOT_FRONT] = 0
						shotRepeat[SHOT_FRONT] = 10

						tempW = SAWeapon[superArcadeMode - 1][evalue - 30000 - 1] or 0

						if tempW == player[0].items.weapon[FRONT_WEAPON].id then
							this_player.cash = this_player.cash + 1000
							power_up_weapon(this_player, FRONT_WEAPON)
						else
							handle_got_purple_ball(this_player)
						end

						player[0].items.weapon[FRONT_WEAPON].id = tempW
						this_player.cash = this_player.cash + 200
						soundQueue[7] = S_POWERUP
						enemyAvail[z] = 1
					elseif evalue > 32100 then
						if playerNum_ == 1 then
							this_player.cash = this_player.cash + 250
							player[0].items.special = evalue - 32100
							shotMultiPos[SHOT_SPECIAL] = 0
							shotRepeat[SHOT_SPECIAL] = 10
							shotMultiPos[SHOT_SPECIAL2] = 0
							shotRepeat[SHOT_SPECIAL2] = 0

							local s
							if twoPlayerMode then
								s = sprintf("%s %s", miscText[43 - 1], special[evalue - 32100].name)
							else
								s = sprintf("%s %s", miscText[64 - 1], special[evalue - 32100].name)
							end
							JE_drawTextWindow(s)
							soundQueue[7] = S_POWERUP
							enemyAvail[z] = 1
						end
					elseif evalue > 32000 then
						if playerNum_ == 2 then
							enemyAvail[z] = 1
							JE_drawTextWindow(sprintf("%s %s", miscText[44 - 1], options[evalue - 32000].name))

							if evalue - 32000 ~= player[1].items.sidekick_series then
								player[1].items.sidekick_series = evalue - 32000
								player[1].items.sidekick_level = 101
							elseif player[1].items.sidekick_level < 103 then
								player[1].items.sidekick_level = player[1].items.sidekick_level + 1
							end

							local t = player[1].items.sidekick_level - 100 - 1
							for i = 0, 1 do
								player[1].items.sidekick[i] = optionSelect[player[1].items.sidekick_series][t][i]
							end

							shotMultiPos[SHOT_LEFT_SIDEKICK] = 0
							shotMultiPos[SHOT_RIGHT_SIDEKICK] = 0
							JE_drawOptions()
							soundQueue[7] = S_POWERUP
						elseif onePlayerAction then
							enemyAvail[z] = 1
							JE_drawTextWindow(sprintf("%s %s", miscText[64 - 1], options[evalue - 32000].name))

							for i = 0, 1 do
								player[0].items.sidekick[i] = evalue - 32000
							end
							shotMultiPos[SHOT_LEFT_SIDEKICK] = 0
							shotMultiPos[SHOT_RIGHT_SIDEKICK] = 0

							JE_drawOptions()
							soundQueue[7] = S_POWERUP
						end
						if enemyAvail[z] == 1 then
							this_player.cash = this_player.cash + 250
						end
					elseif evalue > 31000 then
						this_player.cash = this_player.cash + 250
						if playerNum_ == 2 then
							JE_drawTextWindow(sprintf("%s %s", miscText[44 - 1], weaponPort[evalue - 31000].name))
							player[1].items.weapon[REAR_WEAPON].id = evalue - 31000
							shotMultiPos[SHOT_REAR] = 0
							enemyAvail[z] = 1
							soundQueue[7] = S_POWERUP
						elseif onePlayerAction then
							JE_drawTextWindow(sprintf("%s %s", miscText[64 - 1], weaponPort[evalue - 31000].name))
							player[0].items.weapon[REAR_WEAPON].id = evalue - 31000
							shotMultiPos[SHOT_REAR] = 0
							enemyAvail[z] = 1
							soundQueue[7] = S_POWERUP

							if player[0].items.weapon[REAR_WEAPON].power == 0 then
								player[0].items.weapon[REAR_WEAPON].power = 1
							end
						end
					elseif evalue > 30000 then
						if playerNum_ == 1 and twoPlayerMode then
							JE_drawTextWindow(sprintf("%s %s", miscText[43 - 1], weaponPort[evalue - 30000].name))
							player[0].items.weapon[FRONT_WEAPON].id = evalue - 30000
							shotMultiPos[SHOT_FRONT] = 0
							enemyAvail[z] = 1
							soundQueue[7] = S_POWERUP
						elseif onePlayerAction then
							JE_drawTextWindow(sprintf("%s %s", miscText[64 - 1], weaponPort[evalue - 30000].name))
							player[0].items.weapon[FRONT_WEAPON].id = evalue - 30000
							shotMultiPos[SHOT_FRONT] = 0
							enemyAvail[z] = 1
							soundQueue[7] = S_POWERUP
						end

						if enemyAvail[z] == 1 then
							player[0].items.special = specialArcadeWeapon[evalue - 30000 - 1] or 0
							if player[0].items.special > 0 then
								shotMultiPos[SHOT_SPECIAL] = 0
								shotRepeat[SHOT_SPECIAL] = 0
								shotMultiPos[SHOT_SPECIAL2] = 0
								shotRepeat[SHOT_SPECIAL2] = 0
							end
							this_player.cash = this_player.cash + 250
						end
					end
				elseif evalue > 20000 then
					if twoPlayerLinked then
						for i = 0, 1 do
							player[i].armor = player[i].armor + idiv(evalue - 20000, 2)
							if player[i].armor > 28 then player[i].armor = 28 end
						end
					else
						this_player.armor = this_player.armor + evalue - 20000
						if this_player.armor > 28 then this_player.armor = 28 end
					end
					enemyAvail[z] = 1
					VGAScreen = VGAScreenSeg
					JE_drawArmor()
					VGAScreen = game_screen
					soundQueue[7] = S_POWERUP
				elseif evalue > 10000 and enemyAvail[z] == 2 then
					if not bonusLevel then
						play_song(30)
						bonusLevel = true
						nextLevel = evalue - 10000
						enemyAvail[z] = 1
						displayTime = 150
					end
				elseif ez.scoreitem then
					enemyAvail[z] = 1
					soundQueue[7] = S_ITEM
					if evalue == 1 then
						cubeMax = cubeMax + 1
						soundQueue[3] = V_DATA_CUBE
					elseif evalue == -1 then
						local s
						if twoPlayerMode then
							s = sprintf("%s %s", miscText[43 - 1], miscText[45 - 1])
						else
							s = miscText[45 - 1]
						end
						JE_drawTextWindow(s)
						power_up_weapon(player[0], FRONT_WEAPON)
						soundQueue[7] = S_POWERUP
					elseif evalue == -2 then
						local s
						if twoPlayerMode then
							s = sprintf("%s %s", miscText[44 - 1], miscText[46 - 1])
						else
							s = miscText[46 - 1]
						end
						JE_drawTextWindow(s)
						power_up_weapon(twoPlayerMode and player[1] or player[0], REAR_WEAPON)
						soundQueue[7] = S_POWERUP
					elseif evalue == -3 then
						shotMultiPos[SHOT_MISC] = 0
						b = player_shot_create(0, SHOT_MISC, this_player.x, this_player.y, player[0].mouseX, player[0].mouseY, 104, playerNum_)
						shotAvail[z] = 0
					elseif evalue == -4 then
						if player[playerNum_ - 1].superbombs < 10 then
							player[playerNum_ - 1].superbombs = player[playerNum_ - 1].superbombs + 1
						end
					elseif evalue == -5 then
						player[0].items.weapon[FRONT_WEAPON].id = 25
						player[0].items.weapon[REAR_WEAPON].id = 26
						player[1].items.weapon[REAR_WEAPON].id = 26

						structAssign(player[0].last_items, player[0].items)

						for i = 0, 1 do
							player[i].weapon_mode = 1
						end

						fillArray(shotMultiPos, 11, 0)
					elseif twoPlayerLinked then
						for i = 0, 1 do
							player[i].cash = player[i].cash + idiv(evalue, 2)
						end
					else
						this_player.cash = this_player.cash + evalue
					end
					JE_setupExplosion(enemy_screen_x, ez.ey, 0, enemyDat[ez.enemytype].explosiontype, true, false)
				elseif this_player.invulnerable_ticks == 0 and not cheats.invincible and enemyAvail[z] == 0 and
				       band(enemyDat[ez.enemytype].explosiontype, 1) == 0 then
					local armorleft = ez.armorleft
					if armorleft > damageRate then
						armorleft = damageRate
					end

					JE_playerDamage(armorleft, this_player)

					if ez.armorleft > 0 then
						this_player.x_velocity = this_player.x_velocity + idiv(ez.exc * ez.armorleft, 2)
						this_player.y_velocity = this_player.y_velocity + idiv(ez.eyc * ez.armorleft, 2)
					end

					local armorleft2 = ez.armorleft
					if armorleft2 == 255 then
						armorleft2 = 30000
					end

					temp = ez.linknum
					if temp == 0 then
						temp = 255
					end

					b = z

					if armorleft2 > armorleft then
						if ez.armorleft ~= 255 then
							ez.armorleft = u8(ez.armorleft - armorleft)
						end
						soundQueue[5] = S_ENEMY_HIT
					else
						for t2 = 0, 99 do
							temp2 = t2
							if enemyAvail[t2] ~= 1 then
								temp3 = enemy[t2].linknum
								if t2 == b or
								   (temp ~= 255 and
								    (temp == temp3 or temp - 100 == temp3 or
								     (temp3 > 40 and idiv(temp3, 20) == idiv(temp, 20) and temp3 <= temp))) then
									local esx = enemy[t2].ex + enemy[t2].mapoffset

									enemy[t2].linknum = 0

									enemyAvail[t2] = 1

									if enemyDat[enemy[t2].enemytype].esize == 1 then
										JE_setupExplosionLarge(enemy[t2].enemyground, enemy[t2].explonum, esx, enemy[t2].ey)
										soundQueue[6] = S_EXPLOSION_9
									else
										JE_setupExplosion(esx, enemy[t2].ey, 0, 1, false, false)
										soundQueue[5] = S_EXPLOSION_4
									end
								end
							end
						end
						enemyAvail[z] = 1
					end
				end
			end
		end
	end
end
