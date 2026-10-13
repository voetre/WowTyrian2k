--[[
 WowTyrian2k: a World of Warcraft port of OpenTyrian
 Copyright (C) The OpenTyrian Development Team
 Lua port Copyright (C) 2026 voetre
 Licensed under the GNU General Public License v2 or later (see COPYING).

 shots.c
]]
local _, ns = ...
setfenv(1, ns.G)

MAX_PWEAPON = 81

local function newShot()
	return {
		shotX = 0, shotY = 0, shotXM = 0, shotYM = 0, shotXC = 0, shotYC = 0,
		shotComplicated = false,
		shotDevX = 0, shotDirX = 0, shotDevY = 0, shotDirY = 0, shotCirSizeX = 0, shotCirSizeY = 0,
		shotTrail = 0, shotGr = 0, shotAni = 0, shotAniMax = 0, shotDmg = 0,
		shotBlastFilter = 0, chainReaction = 0, playerNumber = 0, aimAtEnemy = 0, aimDelay = 0, aimDelayMax = 0,
	}
end
ns.newShot = newShot

playerShotData = newArray(MAX_PWEAPON + 1, newShot)
shotAvail = newArray(MAX_PWEAPON, 0)

function resetPlayerShots()
	for i = 0, MAX_PWEAPON do structAssign(playerShotData[i], newShot()) end
	fillArray(shotAvail, MAX_PWEAPON, 0)
end

function simulate_player_shots()
	for z = 0, MAX_PWEAPON - 1 do
		if shotAvail[z] ~= 0 then
			shotAvail[z] = shotAvail[z] - 1
			if z ~= MAX_PWEAPON - 1 then
				local shot = playerShotData[z]

				shot.shotXM = shot.shotXM + shot.shotXC

				if shot.shotXM <= 100 then
					shot.shotX = shot.shotX + shot.shotXM
				end

				shot.shotYM = shot.shotYM + shot.shotYC
				shot.shotY = shot.shotY + shot.shotYM

				if shot.shotYM > 100 then
					shot.shotY = shot.shotY - 120
					shot.shotY = shot.shotY + player[0].delta_y_shot_move
				end

				if shot.shotComplicated then
					shot.shotDevX = shot.shotDevX + shot.shotDirX
					shot.shotX = shot.shotX + shot.shotDevX
					if abs(shot.shotDevX) == shot.shotCirSizeX then
						shot.shotDirX = -shot.shotDirX
					end

					shot.shotDevY = shot.shotDevY + shot.shotDirY
					shot.shotY = shot.shotY + shot.shotDevY
					if abs(shot.shotDevY) == shot.shotCirSizeY then
						shot.shotDirY = -shot.shotDirY
					end
				end

				local tempShotX = shot.shotX
				local tempShotY = shot.shotY

				if shot.shotX < 0 or shot.shotX > 140 or shot.shotY < 0 or shot.shotY > 170 then
					shotAvail[z] = 0
				else
					local anim_frame = u16(shot.shotGr + shot.shotAni)
					shot.shotAni = shot.shotAni + 1
					if shot.shotAni == shot.shotAniMax then
						shot.shotAni = 0
					end

					if anim_frame < 60000 then
						if anim_frame > 1000 then
							anim_frame = anim_frame % 1000
						end
						if anim_frame > 500 then
							blit_sprite2(VGAScreen, tempShotX + 1, tempShotY, spriteSheet12, anim_frame - 500)
						else
							blit_sprite2(VGAScreen, tempShotX + 1, tempShotY, spriteSheet8, anim_frame)
						end
					end
				end
			end
		end
	end
end

local linkMultiGr = { [0] = 77,221,183,301,1,282,164,202,58,201,163,281,39,300,182,220,77 }
local linkSonicGr = { [0] = 85,242,131,303,47,284,150,223,66,224,149,283,9,302,130,243,85 }
local linkMult2Gr = { [0] = 78,299,295,297,2,278,276,280,59,279,275,277,40,296,294,298,78 }

function player_shot_set_direction(shot_id, weapon_id, direction)
	local shot = playerShotData[shot_id]

	shot.shotXM = -roundf(math.sin(direction) * shot.shotYM)
	shot.shotYM = -roundf(math.cos(direction) * shot.shotYM)

	local rounded_dir
	if weapon_id == 27 or weapon_id == 32 or weapon_id == 10 then
		rounded_dir = roundf(direction * (16 / (2 * M_PI)))
		shot.shotGr = linkMultiGr[rounded_dir] or shot.shotGr
	elseif weapon_id == 28 or weapon_id == 33 or weapon_id == 11 then
		rounded_dir = roundf(direction * (16 / (2 * M_PI)))
		shot.shotGr = linkSonicGr[rounded_dir] or shot.shotGr
	elseif weapon_id == 30 or weapon_id == 35 or weapon_id == 14 then
		if direction > M_PI_2 and direction < M_PI + M_PI_2 then
			shot.shotYC = 1
		end
	elseif weapon_id == 38 or weapon_id == 22 then
		rounded_dir = roundf(direction * (16 / (2 * M_PI)))
		shot.shotGr = linkMult2Gr[rounded_dir] or shot.shotGr
	end
end

-- Returns false if the shot went off-screen; otherwise
-- true, is_special, shotx, shoty, damage, blast_filter, chain, playerNum, radiusw, radiush
function player_shot_move_and_draw(shot_id)
	local shot = playerShotData[shot_id]

	shotAvail[shot_id] = shotAvail[shot_id] - 1
	if shot_id ~= MAX_PWEAPON - 1 then
		local pl = player[shot.playerNumber - 1]

		shot.shotXM = shot.shotXM + shot.shotXC
		shot.shotX = shot.shotX + shot.shotXM
		local tmp_shotXM = shot.shotXM

		if shot.shotXM > 100 then
			if shot.shotXM == 101 then
				shot.shotX = shot.shotX - 101
				shot.shotX = shot.shotX + pl.delta_x_shot_move
				shot.shotY = shot.shotY + pl.delta_y_shot_move
			else
				shot.shotX = shot.shotX - 120
				shot.shotX = shot.shotX + pl.delta_x_shot_move
			end
		end

		shot.shotYM = shot.shotYM + shot.shotYC
		shot.shotY = shot.shotY + shot.shotYM

		if shot.shotYM > 100 then
			shot.shotY = shot.shotY - 120
			shot.shotY = shot.shotY + pl.delta_y_shot_move
		end

		if shot.shotComplicated then
			shot.shotDevX = shot.shotDevX + shot.shotDirX
			shot.shotX = shot.shotX + shot.shotDevX
			if abs(shot.shotDevX) == shot.shotCirSizeX then
				shot.shotDirX = -shot.shotDirX
			end

			shot.shotDevY = shot.shotDevY + shot.shotDirY
			shot.shotY = shot.shotY + shot.shotDevY
			if abs(shot.shotDevY) == shot.shotCirSizeY then
				shot.shotDirY = -shot.shotDirY
			end
		end

		local out_shotx = shot.shotX
		local out_shoty = shot.shotY

		if shot.shotX < -34 or shot.shotX > 290 or shot.shotY < -15 or shot.shotY > 190 then
			shotAvail[shot_id] = 0
			return false
		end

		if shot.shotTrail ~= 255 then
			if shot.shotTrail == 98 then
				JE_setupExplosion(shot.shotX - shot.shotXM, shot.shotY - shot.shotYM, 0, shot.shotTrail, false, false)
			else
				JE_setupExplosion(shot.shotX, shot.shotY, 0, shot.shotTrail, false, false)
			end
		end

		if shot.aimAtEnemy ~= 0 then
			shot.aimDelay = u8(shot.aimDelay - 1)
			if shot.aimDelay == 0 then
				shot.aimDelay = shot.aimDelayMax

				if enemyAvail[shot.aimAtEnemy - 1] ~= 1 then
					if shot.shotX < enemy[shot.aimAtEnemy - 1].ex then
						shot.shotXM = shot.shotXM + 1
					else
						shot.shotXM = shot.shotXM - 1
					end
					if shot.shotY < enemy[shot.aimAtEnemy - 1].ey then
						shot.shotYM = shot.shotYM + 1
					else
						shot.shotYM = shot.shotYM - 1
					end
				else
					if shot.shotXM > 0 then
						shot.shotXM = shot.shotXM + 1
					else
						shot.shotXM = shot.shotXM - 1
					end
				end
			end
		end

		local sprite_frame = u16(shot.shotGr + shot.shotAni)
		shot.shotAni = shot.shotAni + 1
		if shot.shotAni == shot.shotAniMax then
			shot.shotAni = 0
		end

		local is_special = sprite_frame > 60000
		local radiusw, radiush = 0, 0

		if is_special then
			blit_sprite_blend(VGAScreen, out_shotx + 1, out_shoty, OPTION_SHAPES, sprite_frame - 60001)
			radiusw = idiv(sprite(OPTION_SHAPES, sprite_frame - 60001).width, 2)
			radiush = idiv(sprite(OPTION_SHAPES, sprite_frame - 60001).height, 2)
		else
			if sprite_frame > 1000 then
				JE_doSP(out_shotx + 1 + 6, out_shoty + 6, 5, 3, lshift(math.floor(sprite_frame / 1000), 4))
				sprite_frame = sprite_frame % 1000
			end
			if sprite_frame > 500 then
				if background2 and out_shoty + shadowYDist < 190 and tmp_shotXM < 100 then
					blit_sprite2_darken(VGAScreen, out_shotx + 1, out_shoty + shadowYDist, spriteSheet12, sprite_frame - 500)
				end
				blit_sprite2(VGAScreen, out_shotx + 1, out_shoty, spriteSheet12, sprite_frame - 500)
			else
				if background2 and out_shoty + shadowYDist < 190 and tmp_shotXM < 100 then
					blit_sprite2_darken(VGAScreen, out_shotx + 1, out_shoty + shadowYDist, spriteSheet8, sprite_frame)
				end
				blit_sprite2(VGAScreen, out_shotx + 1, out_shoty, spriteSheet8, sprite_frame)
			end
		end

		return true, is_special, out_shotx, out_shoty, shot.shotDmg, shot.shotBlastFilter,
			shot.chainReaction, shot.playerNumber, radiusw, radiush
	end

	return true, false, 0, 0, 0, 0, 0, 0, 0, 0
end

local soundChannel = { [0] = 0, 2, 4, 4, 2, 2, 5, 5, 1, 4, 1 }

function player_shot_create(portNum, bay_i, PX, PY, mouseX_, mouseY_, wpNum, playerNum)
	if portNum > PORT_NUM or wpNum <= 0 or wpNum > WEAP_NUM then
		return MAX_PWEAPON
	end

	local weapon = weapons[wpNum]

	if power < weaponPort[portNum].poweruse then
		return MAX_PWEAPON
	end
	power = power - weaponPort[portNum].poweruse

	if weapon.sound > 0 then
		soundQueue[soundChannel[bay_i]] = weapon.sound
	end

	local shot_id = MAX_PWEAPON
	for multi_i = 1, weapon.multi do
		shot_id = MAX_PWEAPON
		for s = 0, MAX_PWEAPON - 1 do
			if shotAvail[s] == 0 then
				shot_id = s
				break
			end
		end
		if shot_id == MAX_PWEAPON then
			return MAX_PWEAPON
		end

		if shotMultiPos[bay_i] == weapon.max or shotMultiPos[bay_i] > 8 then
			shotMultiPos[bay_i] = 1
		else
			shotMultiPos[bay_i] = shotMultiPos[bay_i] + 1
		end
		local mp = shotMultiPos[bay_i] - 1

		local shot = playerShotData[shot_id]
		shot.chainReaction = 0
		shot.playerNumber = playerNum
		shot.shotAni = 0
		shot.shotComplicated = weapon.circlesize ~= 0

		if weapon.circlesize == 0 then
			shot.shotDevX = 0
			shot.shotDirX = 0
			shot.shotDevY = 0
			shot.shotDirY = 0
			shot.shotCirSizeX = 0
			shot.shotCirSizeY = 0
		else
			local circsize = weapon.circlesize
			if circsize > 19 then
				local circsize_mod20 = circsize % 20
				shot.shotCirSizeX = circsize_mod20
				shot.shotDevX = rshift(circsize_mod20, 1)

				circsize = math.floor(circsize / 20)
				shot.shotCirSizeY = circsize
				shot.shotDevY = rshift(circsize, 1)
			else
				shot.shotCirSizeX = circsize
				shot.shotCirSizeY = circsize
				shot.shotDevX = rshift(circsize, 1)
				shot.shotDevY = rshift(circsize, 1)
			end
			shot.shotDirX = 1
			shot.shotDirY = -1
		end

		shot.shotTrail = weapon.trail

		if weapon.attack[mp] > 99 and weapon.attack[mp] < 250 then
			shot.chainReaction = weapon.attack[mp] - 100
			shot.shotDmg = 1
		else
			shot.shotDmg = weapon.attack[mp]
		end

		shot.shotBlastFilter = weapon.shipblastfilter

		local tmp_by = weapon.by[mp]

		shot.shotX = s16(PX + weapon.bx[mp])
		shot.shotY = s16(PY + tmp_by)
		shot.shotYC = -weapon.acceleration
		shot.shotXC = weapon.accelerationx

		shot.shotXM = weapon.sx[mp]

		local del = weapon.del[mp]

		if del == 121 then
			shot.shotTrail = 0
			del = 255
		end

		shot.shotGr = weapon.sg[mp]
		if shot.shotGr == 0 then
			shotAvail[shot_id] = 0
		else
			shotAvail[shot_id] = del
		end

		if del > 100 and del < 120 then
			shot.shotAniMax = del - 100 + 1
		else
			shot.shotAniMax = weapon.weapani + 1
		end

		if del == 99 or del == 98 then
			tmp_by = PX - mouseX_
			if tmp_by < -5 then
				tmp_by = -5
			elseif tmp_by > 5 then
				tmp_by = 5
			end
			shot.shotXM = shot.shotXM + tmp_by
		end

		if del == 99 or del == 100 then
			tmp_by = PY - mouseY_ - weapon.sy[mp]
			if tmp_by < -4 then
				tmp_by = -4
			elseif tmp_by > 4 then
				tmp_by = 4
			end
			shot.shotYM = tmp_by
		elseif weapon.sy[mp] == 98 then
			shot.shotYM = 0
			shot.shotYC = -1
		elseif weapon.sy[mp] > 100 then
			shot.shotYM = weapon.sy[mp]
			shot.shotY = shot.shotY - player[shot.playerNumber - 1].delta_y_shot_move
		else
			shot.shotYM = -weapon.sy[mp]
		end

		if weapon.sx[mp] > 100 then
			shot.shotXM = weapon.sx[mp]
			shot.shotX = shot.shotX - player[shot.playerNumber - 1].delta_x_shot_move
			if shot.shotXM == 101 then
				shot.shotY = shot.shotY - player[shot.playerNumber - 1].delta_y_shot_move
			end
		end

		if weapon.aim > 5 then
			local best_dist = 65000
			local closest_enemy = 0
			for xx = 0, 99 do
				if enemyAvail[xx] ~= 1 and not enemy[xx].scoreitem then
					local d = abs(enemy[xx].ex - shot.shotX) + abs(enemy[xx].ey - shot.shotY)
					if d < best_dist then
						best_dist = d
						closest_enemy = xx + 1
					end
				end
			end
			shot.aimAtEnemy = closest_enemy
			shot.aimDelay = 5
			shot.aimDelayMax = weapon.aim - 5
		else
			shot.aimAtEnemy = 0
		end

		shotRepeat[bay_i] = weapon.shotrepeat
	end

	return shot_id
end
