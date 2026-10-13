--[[
 WowTyrian2k: a World of Warcraft port of OpenTyrian
 Copyright (C) The OpenTyrian Development Team
 Lua port Copyright (C) 2026 voetre
 Licensed under the GNU General Public License v2 or later (see COPYING).

 varz.c
]]
local _, ns = ...
setfenv(1, ns.G)

SA = 7
SA_NONE = 0
SA_NORTSHIPZ = 7
SA_DESTRUCT = 8
SA_ENGAGE = 9
SA_SUPERTYRIAN = 254
SA_ARCADE = 255

ENEMY_SHOT_MAX = 60
CURRENT_KEY_SPEED = 1
MAX_EXPLOSIONS = 200
MAX_REPEATING_EXPLOSIONS = 20
MAX_SUPERPIXELS = 101

tempDat, tempDat2, tempDat3 = 0, 0, 0

SANextShip = { [0] = 3, 9, 6, 2, 5, 1, 4, 3, 7 }
SASpecialWeapon = { [0] = 7, 8, 9, 10, 11, 12, 13 }
SASpecialWeaponB = { [0] = 37, 6, 15, 40, 16, 14, 41 }
SAShip = { [0] = 3, 1, 5, 10, 2, 11, 12 }
SAWeapon = {
	[0] = { [0] = 9, 31, 32, 33, 34 },
	{ [0] = 19, 8, 22, 41, 34 },
	{ [0] = 27, 5, 20, 42, 31 },
	{ [0] = 15, 3, 28, 22, 12 },
	{ [0] = 23, 35, 25, 14, 6 },
	{ [0] = 2, 5, 21, 4, 7 },
	{ [0] = 40, 38, 37, 41, 36 },
}

specialArcadeWeapon = { [0] =
	17,17,18,0,0,0,10,0,0,0,0,0,44,0,10,0,19,0,0,0,0,0,0,0,0,0,
	0,0,0,0,45,0,0,0,0,0,0,0,0,0,0,0
}

optionSelect = {
	[0] = { [0] = { [0] = 0, 0 }, { [0] = 0, 0 }, { [0] = 0, 0 } },
	{ [0] = { [0] = 1, 1 }, { [0] = 16, 16 }, { [0] = 30, 30 } },
	{ [0] = { [0] = 2, 2 }, { [0] = 29, 29 }, { [0] = 29, 20 } },
	{ [0] = { [0] = 3, 3 }, { [0] = 21, 21 }, { [0] = 12, 0 } },
	{ [0] = { [0] = 4, 4 }, { [0] = 18, 18 }, { [0] = 16, 23 } },
	{ [0] = { [0] = 0, 0 }, { [0] = 0, 0 }, { [0] = 0, 0 } },
	{ [0] = { [0] = 6, 6 }, { [0] = 29, 16 }, { [0] = 0, 22 } },
	{ [0] = { [0] = 7, 7 }, { [0] = 19, 19 }, { [0] = 19, 28 } },
	{ [0] = { [0] = 0, 0 }, { [0] = 0, 0 }, { [0] = 0, 0 } },
	{ [0] = { [0] = 0, 0 }, { [0] = 0, 0 }, { [0] = 0, 0 } },
	{ [0] = { [0] = 10, 10 }, { [0] = 21, 21 }, { [0] = 21, 27 } },
	{ [0] = { [0] = 0, 0 }, { [0] = 0, 0 }, { [0] = 0, 0 } },
	{ [0] = { [0] = 0, 0 }, { [0] = 0, 0 }, { [0] = 0, 0 } },
	{ [0] = { [0] = 13, 13 }, { [0] = 17, 17 }, { [0] = 13, 26 } },
	{ [0] = { [0] = 0, 0 }, { [0] = 0, 0 }, { [0] = 0, 0 } },
	{ [0] = { [0] = 15, 15 }, { [0] = 15, 16 }, { [0] = 15, 16 } },
}

PGR = { [0] = 4, 1, 2, 3, 41-21, 57-21, 73-21, 89-21, 105-21, 121-21, 137-21, 153-21,
	151, 151, 151, 151, 73-21, 73-21, 1, 2, 4 }
PAni = { [0] = 1,0,0,0,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,1 }

linkGunWeapons = { [0] = 0,0,0,0,0,0,0,0,444,445,446,447,0,448,449,0,0,0,0,0,450,451,0,506,0,564,
	445,446,447,448,449,445,446,447,448,449,450,451 }
chargeGunWeapons = { [0] = 0,0,0,0,0,0,0,0,476,458,464,482,0,488,470,0,0,0,0,0,494,500,0,528,0,558,
	458,458,458,458,458,458,458,458,458,458,458,458 }
randomEnemyLaunchSounds = { [0] = 13, 6, 26 }

keyboardCombos = {
	[0] = { [0] = 2, 1, 2, 5, 137, 0, 0, 0 },
	{ [0] = 4, 3, 2, 5, 138, 0, 0, 0 },
	{ [0] = 3, 4, 6, 139, 0, 0, 0, 0 },
	{ [0] = 2, 5, 142, 0, 0, 0, 0, 0 },
	{ [0] = 6, 2, 6, 143, 0, 0, 0, 0 },
	{ [0] = 6, 7, 5, 8, 6, 7, 5, 112 },
	{ [0] = 7, 8, 101, 0, 0, 0, 0, 0 },
	{ [0] = 1, 7, 6, 146, 0, 0, 0, 0 },
	{ [0] = 8, 6, 7, 1, 120, 0, 0, 0 },
	{ [0] = 3, 6, 8, 5, 121, 0, 0, 0 },
	{ [0] = 1, 2, 7, 8, 119, 0, 0, 0 },
	{ [0] = 3, 4, 3, 6, 123, 0, 0, 0 },
	{ [0] = 6, 7, 5, 8, 124, 0, 0, 0 },
	{ [0] = 1, 6, 125, 0, 0, 0, 0, 0 },
	{ [0] = 9, 5, 126, 0, 0, 0, 0, 0 },
	{ [0] = 1, 7, 127, 0, 0, 0, 0, 0 },
	{ [0] = 1, 8, 128, 0, 0, 0, 0, 0 },
	{ [0] = 9, 7, 129, 0, 0, 0, 0, 0 },
	{ [0] = 9, 8, 130, 0, 0, 0, 0, 0 },
	{ [0] = 4, 2, 3, 5, 131, 0, 0, 0 },
	{ [0] = 3, 1, 2, 8, 132, 0, 0, 0 },
	{ [0] = 2, 4, 5, 133, 0, 0, 0, 0 },
	{ [0] = 3, 4, 2, 8, 134, 0, 0, 0 },
	{ [0] = 1, 4, 6, 135, 0, 0, 0, 0 },
	{ [0] = 1, 3, 6, 137, 0, 0, 0, 0 },
	{ [0] = 1, 4, 3, 4, 7, 136, 0, 0 },
}

shipCombosB = { [0] = 15,16,17,18,19,20,21,22,23,24, 7, 8, 5,25,14, 4, 6, 3, 9, 2,26 }
superTyrianSpecials = { [0] = 1, 2, 4, 5 }
shipCombos = {
	[0] = { [0] = 5, 4, 7 }, { [0] = 1, 2, 0 }, { [0] = 14, 4, 0 }, { [0] = 4, 5, 0 },
	{ [0] = 6, 5, 0 }, { [0] = 7, 8, 0 }, { [0] = 7, 9, 0 }, { [0] = 10, 3, 5 },
	{ [0] = 5, 8, 9 }, { [0] = 1, 3, 0 }, { [0] = 7, 16, 17 }, { [0] = 2, 11, 12 },
	{ [0] = 3, 8, 10 }, { [0] = 0, 0, 0 },
}

SFCurrentCode = { [0] = newArray(21, 0), newArray(21, 0) }
SFExecuted = { [0] = 0, 0 }

lvlFileNum = 0
maxEvent, eventLoc = 0, 0
tempBackMove, explodeMove = 0, 0
levelEnd = 0
levelEndFxWait = 0
levelEndWarp = 0
endLevel, reallyEndLevel, waitToEndLevel, playerEndLevel = false, false, false, false
normalBonusLevelCurrent, bonusLevelCurrent, smallEnemyAdjust, readyToEndLevel, quitRequested = false, false, false, false, false

newPL = newArray(10, 0)
returnLoc = 0
returnActive = false
galagaShotFreq = 0
galagaLife = 0

debug_ = false
debugTime, lastDebugTime = 0, 0
debugHistCount = 0
debugHist = 0
curLoc = 0

firstGameOver, gameLoaded, enemyStillExploding = false, false, false

totalEnemy = 0
enemyKilled = 0

-- Map data: megaData*.mainmap[y][x] holds a tile reference {set, z} or nil
-- (see JE_loadMap).  Maps are stored as flat 0-based arrays.
megaData1 = { mainmap = {}, width = 14, height = 300 }
megaData2 = { mainmap = {}, width = 14, height = 600 }
megaData3 = { mainmap = {}, width = 15, height = 600 }

flash = 0
flashChange = 0
displayTime = 0

soundQueue = newArray(8, 0)
enemyContinualDamage = false
enemiesActive = false
forceEvents = false
stopBackgrounds = false
stopBackgroundNum = 0
damageRate = 0
background3x1 = false
background3x1b = false
levelTimer = false
levelTimerCountdown = 0
levelTimerJumpTo = 0
randomExplosions = false
editShip1, editShip2 = false, false
globalFlags = newArray(10, false)
levelSong = 0
loadDestruct = false
mapOrigin, mapPNum = 0, 0
mapPlanet = newArray(5, 0)
mapSection = newArray(5, 0)
moveTyrianLogoUp = false
skipStarShowVGA = false

local function newEnemy()
	return {
		fillbyte = 0, ex = 0, ey = 0, exc = 0, eyc = 0, exca = 0, eyca = 0,
		excc = 0, eycc = 0, exccw = 0, eyccw = 0, armorleft = 0,
		eshotwait = newArray(3, 0), eshotmultipos = newArray(3, 0),
		enemycycle = 0, ani = 0, egr = newArray(20, 0), size = 0, linknum = 0,
		aniactive = 0, animax = 0, aniwhenfire = 0, sprite2s = nil,
		exrev = 0, eyrev = 0, exccadd = 0, eyccadd = 0, exccwmax = 0, eyccwmax = 0,
		enemydatofs = nil, edamaged = false, enemytype = 0, animin = 0, edgr = 0,
		edlevel = 0, edani = 0, fill1 = 0, filter = 0, evalue = 0, fixedmovey = 0,
		freq = newArray(3, 0), launchwait = 0, launchtype = 0, launchfreq = 0,
		xaccel = 0, yaccel = 0, tur = newArray(3, 0), enemydie = 0,
		enemyground = false, explonum = 0, mapoffset = 0, scoreitem = false,
		special = false, flagnum = 0, setto = false, iced = 0, launchspecial = 0,
		xminbounce = 0, xmaxbounce = 0, yminbounce = 0, ymaxbounce = 0,
	}
end
ns.newEnemy = newEnemy

enemy = newArray(100, newEnemy)
enemyAvail = newArray(100, 1)
enemyOffset = 0
enemyOnScreen = 0
superEnemy254Jump = 0

explosions = newArray(MAX_EXPLOSIONS, function()
	return { ttl = 0, x = 0, y = 0, sprite = 0, followPlayer = false, fixedPosition = false, deltaY = 0 }
end)
explosionFollowAmountX, explosionFollowAmountY = 0, 0

fireButtonHeld = false
enemyShotAvail = newArray(ENEMY_SHOT_MAX, true)
enemyShot = newArray(ENEMY_SHOT_MAX, function()
	return { sx = 0, sy = 0, sxm = 0, sym = 0, sxc = 0, syc = 0, tx = 0, ty = 0, sgr = 0,
		sdmg = 0, duration = 0, animate = 0, animax = 0 }
end)

zinglonDuration = 0
astralDuration = 0
flareDuration = 0
flareStart = false
flareColChg = 0
specialWait = 0
nextSpecialWait = 0
spraySpecial = false
doIced = 0
infiniteShot = false

allPlayersGone = false

shadowYDist = 10

optionSatelliteRotate = 0
optionAttachmentMove = 0
optionAttachmentLinked, optionAttachmentReturn = false, false

chargeWait, chargeLevel, chargeMax, chargeGr, chargeGrWait = 0, 0, 0, 0, 0

neat = 0

rep_explosions = newArray(MAX_REPEATING_EXPLOSIONS, function()
	return { delay = 0, ttl = 0, x = 0, y = 0, big = false }
end)

superpixels = newArray(MAX_SUPERPIXELS, function()
	return { x = 0, y = 0, z = 0, delta_x = 0, delta_y = 0, color = 0 }
end)
last_superpixel = 0

temp, temp2, temp3 = 0, 0, 0
tempW = 0

doNotSaveBackup = false

x, y = 0, 0
b = 0

BKwrap1to, BKwrap2to, BKwrap3to, BKwrap1, BKwrap2, BKwrap3 = 0, 0, 0, 0, 0, 0

specialWeaponFilter, specialWeaponFreq = 0, 0
specialWeaponWpn = 0
linkToPlayer = false

shipGr, shipGr2 = 0, 0
shipGrPtr, shipGr2ptr = nil, nil

hud_sidekick_y = { [0] = { [0] = 64, 82 }, { [0] = 108, 126 } }

-- explicit struct resets used where the C code memsets arrays

function resetEnemy(e)
	structAssign(e, newEnemy())
end

function JE_getShipInfo()
	shipGrPtr = spriteSheet9
	shipGr2ptr = spriteSheet9

	powerAdd = powerSys[player[0].items.generator].power

	local extraShip = player[0].items.ship > 90
	if extraShip then
		local base = (player[0].items.ship - 91) * 15
		shipGr, shipGrPtr = JE_SGr(player[0].items.ship - 90, shipGrPtr)
		player[0].armor = extraShips[base + 7]
	else
		shipGr = ships[player[0].items.ship].shipgraphic
		player[0].armor = ships[player[0].items.ship].dmg
	end

	local extraShip2 = player[1].items.ship > 90
	if extraShip2 then
		local base2 = (player[1].items.ship - 91) * 15
		shipGr2, shipGr2ptr = JE_SGr(player[1].items.ship - 90, shipGr2ptr)
		player[1].armor = extraShips[base2 + 7]
	else
		shipGr2 = 0
		player[1].armor = 10
	end

	for i = 0, 1 do
		player[i].initial_armor = player[i].armor

		local t = ((i == 0 and extraShip) or (i == 1 and extraShip2)) and 2 or ships[player[i].items.ship].ani

		if t == 0 then
			player[i].shot_hit_area_x = 12
			player[i].shot_hit_area_y = 10
		else
			player[i].shot_hit_area_x = 11
			player[i].shot_hit_area_y = 14
		end
	end
end

-- Returns graphic index and (possibly changed) sprite sheet.
function JE_SGr(ship, ptr)
	local GR = { [0] = 233, 157, 195, 271, 81, 0, 119, 5, 43, 81, 119, 157, 195, 233, 271 }
	local tw = extraShips[(ship - 1) * 15]
	if tw > 7 then
		ptr = extraShapes
	end
	return GR[tw - 1] or 0, ptr
end

function JE_drawOptions()
	local temp_surface = VGAScreen
	VGAScreen = VGAScreenSeg

	local this_player = player[twoPlayerMode and 1 or 0]

	for i = 0, 1 do
		local this_option = options[this_player.items.sidekick[i]]
		local sk = this_player.sidekick[i]

		sk.ammo = this_option.ammo
		sk.ammo_max = this_option.ammo

		sk.ammo_refill_ticks = (105 - sk.ammo) * 4
		sk.ammo_refill_ticks_max = sk.ammo_refill_ticks

		sk.style = this_option.tr

		sk.animation_enabled = (this_option.option == 1)
		sk.animation_frame = 0

		sk.charge = 0
		sk.charge_ticks = 20

		local yy = hud_sidekick_y[twoPlayerMode and 1 or 0][i]

		fill_rectangle_xy(VGAScreenSeg, 284, yy, 284 + 28, yy + 15, 0)
		if this_option.icongr > 0 then
			blit_sprite(VGAScreenSeg, 284, yy, OPTION_SHAPES, this_option.icongr - 1)
		end
		draw_segmented_gauge(VGAScreenSeg, 284, yy + 13, 112, 2, 2, MAX(1, idiv(sk.ammo_max, 10)), sk.ammo)
	end

	VGAScreen = temp_surface

	JE_drawOptionLevel()
end

function JE_drawOptionLevel()
	if twoPlayerMode then
		for t = 1, 3 do
			fill_rectangle_xy(VGAScreenSeg, 268, 127 + (t - 1) * 6, 269, 127 + 3 + (t - 1) * 6,
				193 + b2n((player[1].items.sidekick_level - 100) == t) * 11)
		end
	end
end

function JE_tyrianHalt(code)
	saveConfiguration()
	saveSaves()
	stop_song()
	if trentWin then
		ns.Print("Sleep well, Trent, you deserve the rest.")
		ns.Print("You now have permission to borrow my ship on your next mission.")
	end
	ns.quitGame()
end

function JE_specialComplete(playerNum, specialType)
	nextSpecialWait = 0
	local st = special[specialType].stype
	if st == 1 then
		if playerNum == 1 then
			b = player_shot_create(0, SHOT_SPECIAL2, player[0].x, player[0].y, player[0].mouseX, player[0].mouseY, special[specialType].wpn, playerNum)
		else
			b = player_shot_create(0, SHOT_SPECIAL2, player[1].x, player[1].y, player[0].mouseX, player[0].mouseY, special[specialType].wpn, playerNum)
		end
		shotRepeat[SHOT_SPECIAL] = shotRepeat[SHOT_SPECIAL2]
	elseif st == 2 then
		for t = 0, ENEMY_SHOT_MAX - 1 do
			if not enemyShotAvail[t] then
				local s = enemyShot[t]
				if player[0].x > s.sx then s.sxm = s.sxm - 1
				elseif player[0].x < s.sx then s.sxm = s.sxm + 1 end
				if player[0].y > s.sy then s.sym = s.sym - 1
				elseif player[0].y < s.sy then s.sym = s.sym + 1 end
			end
		end
	elseif st == 3 then
		zinglonDuration = 50
		shotRepeat[SHOT_SPECIAL] = 100
		soundQueue[7] = S_SOUL_OF_ZINGLON
	elseif st == 4 then
		for t = 0, 99 do
			local e = enemy[t]
			if enemyAvail[t] ~= 1 and e.scoreitem and e.evalue ~= 0 then
				if player[0].x > e.ex then e.exc = s8(e.exc + 1)
				elseif player[0].x < e.ex then e.exc = s8(e.exc - 1) end
				if player[0].y > e.ey then e.eyc = s8(e.eyc + 1)
				elseif player[0].y < e.ey then e.eyc = s8(e.eyc - 1) end
			end
		end
	elseif st == 5 or st == 6 or st == 7 or st == 8 or st == 9 or st == 10 or st == 11 or st == 16 then
		if flareDuration == 0 then flareStart = true end

		specialWeaponWpn = special[specialType].wpn
		linkToPlayer = false
		spraySpecial = false
		local fp = player[0].items.weapon[FRONT_WEAPON].power
		if st == 5 then
			specialWeaponFilter = 7
			specialWeaponFreq = 2
			flareDuration = 50
		elseif st == 6 then
			specialWeaponFilter = 1
			specialWeaponFreq = 7
			flareDuration = 200 + 25 * fp
		elseif st == 7 then
			specialWeaponFilter = 3
			specialWeaponFreq = 3
			flareDuration = 50 + 10 * fp
			zinglonDuration = 50
			shotRepeat[SHOT_SPECIAL] = 100
			soundQueue[7] = S_SOUL_OF_ZINGLON
		elseif st == 8 then
			specialWeaponFilter = -99
			specialWeaponFreq = 7
			flareDuration = 10 + fp
		elseif st == 9 then
			specialWeaponFilter = -99
			specialWeaponFreq = 8
			flareDuration = 8 + 2 * fp
			linkToPlayer = true
			nextSpecialWait = special[specialType].pwr
		elseif st == 10 then
			specialWeaponFilter = -99
			specialWeaponFreq = 8
			flareDuration = 14 + 4 * fp
			linkToPlayer = true
		elseif st == 11 then
			specialWeaponFilter = -99
			specialWeaponFreq = special[specialType].pwr
			flareDuration = 10 + 10 * fp
			astralDuration = u8(20 + 10 * fp)
		elseif st == 16 then
			specialWeaponFilter = -99
			specialWeaponFreq = 8
			flareDuration = temp2 * 16 + 8
			linkToPlayer = true
			spraySpecial = true
		end
	elseif st == 12 then
		player[playerNum - 1].invulnerable_ticks = temp2 * 10
		if superArcadeMode > 0 and superArcadeMode <= SA then
			shotRepeat[SHOT_SPECIAL] = 250
			b = player_shot_create(0, SHOT_SPECIAL2, player[0].x, player[0].y, player[0].mouseX, player[0].mouseY, 707, 1)
			player[0].invulnerable_ticks = 100
		end
	elseif st == 13 then
		player[0].armor = player[0].armor + idiv(temp2, 4) + 1
		soundQueue[3] = S_POWERUP
	elseif st == 14 then
		player[1].armor = player[1].armor + idiv(temp2, 4) + 1
		soundQueue[3] = S_POWERUP
	elseif st == 17 then
		soundQueue[3] = S_POWERUP
		if player[0].items.sidekick[LEFT_SIDEKICK] == special[specialType].wpn then
			player[0].items.sidekick[RIGHT_SIDEKICK] = special[specialType].wpn
			shotMultiPos[RIGHT_SIDEKICK] = 0
		else
			player[0].items.sidekick[LEFT_SIDEKICK] = special[specialType].wpn
			shotMultiPos[LEFT_SIDEKICK] = 0
		end
		JE_drawOptions()
	elseif st == 18 then
		player[0].items.sidekick[RIGHT_SIDEKICK] = special[specialType].wpn
		JE_drawOptions()
		soundQueue[4] = S_POWERUP
		shotMultiPos[RIGHT_SIDEKICK] = 0
	end
end

-- armor and shield are passed by reference in C; here the player table is
-- passed and its fields are modified.
function JE_doSpecialShot(playerNum, p)
	if player[0].items.special > 0 then
		if shotRepeat[SHOT_SPECIAL] == 0 and specialWait == 0 and flareDuration < 2 and zinglonDuration < 2 then
			blit_sprite2(VGAScreen, 47, 4, spriteSheet9, 94)
		else
			blit_sprite2(VGAScreen, 47, 4, spriteSheet9, 93)
		end
	end

	if shotRepeat[SHOT_SPECIAL] > 0 then
		shotRepeat[SHOT_SPECIAL] = shotRepeat[SHOT_SPECIAL] - 1
	end
	if specialWait > 0 then
		specialWait = specialWait - 1
	end
	temp = SFExecuted[playerNum - 1]
	if temp > 0 and shotRepeat[SHOT_SPECIAL] == 0 and flareDuration == 0 then
		temp2 = special[temp].pwr

		local can_afford = true

		if temp2 > 0 then
			if temp2 < 98 then
				if p.shield >= temp2 then
					p.shield = p.shield - temp2
				else
					can_afford = false
				end
			elseif temp2 == 98 then
				if p.shield < 4 then can_afford = false end
				temp2 = p.shield
				p.shield = 0
			elseif temp2 == 99 then
				temp2 = idiv(p.shield, 2)
				p.shield = temp2
			else
				temp2 = temp2 - 100
				if p.armor > temp2 then
					p.armor = p.armor - temp2
				else
					can_afford = false
				end
			end
		end

		shotMultiPos[SHOT_SPECIAL] = 0
		shotMultiPos[SHOT_SPECIAL2] = 0

		if can_afford then
			JE_specialComplete(playerNum, temp)
		end

		SFExecuted[playerNum - 1] = 0

		JE_wipeShieldArmorBars()
		VGAScreen = VGAScreenSeg
		JE_drawShield()
		JE_drawArmor()
		VGAScreen = game_screen
	end

	if playerNum == 1 and player[0].items.special > 0 then
		if superArcadeMode > 0 and (button[1] or button[2]) then
			fireButtonHeld = false
		end
		if not button[0] and not (superArcadeMode ~= SA_NONE and (button[1] or button[2])) then
			fireButtonHeld = false
		elseif shotRepeat[SHOT_SPECIAL] == 0 and not fireButtonHeld and not (flareDuration > 0) and specialWait == 0 then
			fireButtonHeld = true
			JE_specialComplete(playerNum, player[0].items.special)
		end
	end

	if astralDuration > 0 then
		astralDuration = astralDuration - 1
	end

	shotAvail[MAX_PWEAPON - 1] = 0
	if flareDuration > 1 then
		if specialWeaponFilter ~= -99 then
			if levelFilter == -99 and levelBrightness == -99 then
				filterActive = false
			end
			if not filterActive then
				levelFilter = specialWeaponFilter
				if levelFilter == 7 then
					levelBrightness = 0
				end
				filterActive = true
			end

			if mt_rand() % 2 == 0 then
				flareColChg = -1
			else
				flareColChg = 1
			end

			if levelFilter == 7 then
				if levelBrightness < -6 then flareColChg = 1 end
				if levelBrightness > 6 then flareColChg = -1 end
				levelBrightness = levelBrightness + flareColChg
			end
		end

		if (mt_rand() % 6) < specialWeaponFreq then
			b = MAX_PWEAPON

			if linkToPlayer then
				if shotRepeat[SHOT_SPECIAL] == 0 then
					b = player_shot_create(0, SHOT_SPECIAL, player[0].x, player[0].y, player[0].mouseX, player[0].mouseY, specialWeaponWpn, playerNum)
				end
			else
				b = player_shot_create(0, SHOT_SPECIAL, mt_rand() % 280, mt_rand() % 180, player[0].mouseX, player[0].mouseY, specialWeaponWpn, playerNum)
			end

			if spraySpecial and b ~= MAX_PWEAPON then
				playerShotData[b].shotXM = (mt_rand() % 5) - 2
				playerShotData[b].shotYM = (mt_rand() % 5) - 2
				if playerShotData[b].shotYM == 0 then
					playerShotData[b].shotYM = playerShotData[b].shotYM + 1
				end
			end
		end

		flareDuration = flareDuration - 1
		if flareDuration == 1 then
			specialWait = nextSpecialWait
		end
	elseif flareStart then
		flareStart = false
		shotRepeat[SHOT_SPECIAL] = linkToPlayer and 15 or 200
		flareDuration = 0
		if levelFilter == specialWeaponFilter then
			levelFilter = -99
			levelBrightness = -99
			filterActive = false
		end
	end

	if zinglonDuration > 1 then
		temp = 25 - abs(zinglonDuration - 25)

		JE_barBright(VGAScreen, player[0].x + 7 - temp, 0, player[0].x + 7 + temp, 184)
		JE_barBright(VGAScreen, player[0].x + 7 - temp - 2, 0, player[0].x + 7 + temp + 2, 184)

		zinglonDuration = zinglonDuration - 1
		if zinglonDuration % 5 == 0 then
			shotAvail[MAX_PWEAPON - 1] = 1
		end
	end
end

local explosion_data = {
	[0] = { 144, 7 }, { 120, 12 }, { 190, 12 }, { 209, 12 }, { 152, 12 }, { 171, 12 }, { 133, 7 },
	{ 1, 12 }, { 20, 12 }, { 39, 12 }, { 58, 12 }, { 110, 3 }, { 76, 7 }, { 91, 3 },
	{ 227, 3 }, { 230, 3 }, { 233, 3 }, { 252, 3 }, { 246, 3 },
	{ 249, 3 }, { 265, 3 }, { 268, 3 }, { 271, 3 }, { 236, 3 },
	{ 239, 3 }, { 242, 3 }, { 261, 3 }, { 274, 3 }, { 277, 3 },
	{ 280, 3 }, { 299, 3 }, { 284, 3 }, { 287, 3 }, { 290, 3 },
	{ 293, 3 }, { 165, 8 }, { 184, 8 }, { 203, 8 }, { 222, 8 }, { 168, 8 }, { 187, 8 },
	{ 206, 8 }, { 225, 10 }, { 169, 10 }, { 188, 10 }, { 207, 20 }, { 226, 14 },
	{ 170, 14 }, { 189, 14 }, { 208, 14 }, { 246, 14 }, { 227, 14 }, { 265, 14 },
}

function JE_setupExplosion(x_, y_, deltaY, type_, fixedPosition, followPlayer)
	if y_ > -16 and y_ < 190 then
		for i = 0, MAX_EXPLOSIONS - 1 do
			local ex = explosions[i]
			if ex.ttl == 0 then
				ex.x = x_
				ex.y = y_
				if type_ == 6 then
					ex.y = ex.y + 12
					ex.x = ex.x + 2
				elseif type_ == 98 then
					type_ = 6
				end
				local d = explosion_data[type_]
				if not d then return end
				ex.sprite = d[1]
				ex.ttl = d[2]
				ex.followPlayer = followPlayer
				ex.fixedPosition = fixedPosition
				ex.deltaY = deltaY
				break
			end
		end
	end
end

function JE_setupExplosionLarge(enemyGround, exploNum, x_, y_)
	if y_ >= 0 then
		if enemyGround then
			JE_setupExplosion(x_ - 6, y_ - 14, 0, 2, false, false)
			JE_setupExplosion(x_ + 6, y_ - 14, 0, 4, false, false)
			JE_setupExplosion(x_ - 6, y_, 0, 3, false, false)
			JE_setupExplosion(x_ + 6, y_, 0, 5, false, false)
		else
			JE_setupExplosion(x_ - 6, y_ - 14, 0, 7, false, false)
			JE_setupExplosion(x_ + 6, y_ - 14, 0, 9, false, false)
			JE_setupExplosion(x_ - 6, y_, 0, 8, false, false)
			JE_setupExplosion(x_ + 6, y_, 0, 10, false, false)
		end

		local big
		if exploNum > 10 then
			exploNum = exploNum - 10
			big = true
		else
			big = false
		end

		if exploNum ~= 0 then
			for i = 0, MAX_REPEATING_EXPLOSIONS - 1 do
				local r = rep_explosions[i]
				if r.ttl == 0 then
					r.ttl = exploNum
					r.delay = 2
					r.x = x_
					r.y = y_
					r.big = big
					break
				end
			end
		end
	end
end

function JE_wipeShieldArmorBars()
	fill_rectangle_xy(VGAScreenSeg, 270, 137, 278, 194 - player[0].shield * 2, 0)
	fill_rectangle_xy(VGAScreenSeg, 307, 137, 315, 194 - player[0].armor * 2, 0)
end

function JE_playerDamage(dmg, this_player)
	if cheats.invincible then return 0 end
	local playerDamage = 0
	soundQueue[7] = S_SHIELD_HIT

	if this_player.shield < dmg then
		playerDamage = dmg
		dmg = dmg - this_player.shield
		this_player.shield = 0

		if dmg > 0 then
			if this_player.armor < dmg then
				dmg = dmg - this_player.armor
				this_player.armor = 0

				if this_player.is_alive and not youAreCheating then
					levelTimer = false
					this_player.is_alive = false
					this_player.exploding_ticks = 60
					levelEnd = 40
					tempVolume = tyrMusicVolume
					soundQueue[1] = S_EXPLOSION_22
				end
			else
				this_player.armor = this_player.armor - dmg
				soundQueue[7] = S_HULL_HIT
			end
		end
	else
		this_player.shield = this_player.shield - dmg

		local px, py = this_player.x, this_player.y
		local fp = not twoPlayerMode
		JE_setupExplosion(px - 17, py - 12, 0, 14, false, fp)
		JE_setupExplosion(px - 5, py - 12, 0, 15, false, fp)
		JE_setupExplosion(px + 7, py - 12, 0, 16, false, fp)
		JE_setupExplosion(px + 19, py - 12, 0, 17, false, fp)

		JE_setupExplosion(px - 17, py + 2, 0, 18, false, fp)
		JE_setupExplosion(px + 19, py + 2, 0, 19, false, fp)

		JE_setupExplosion(px - 17, py + 16, 0, 20, false, fp)
		JE_setupExplosion(px - 5, py + 16, 0, 21, false, fp)
		JE_setupExplosion(px + 7, py + 16, 0, 22, false, fp)
	end

	JE_wipeShieldArmorBars()
	VGAScreen = VGAScreenSeg
	JE_drawShield()
	JE_drawArmor()
	VGAScreen = game_screen

	return u8(playerDamage)
end

function JE_portConfigs()
	local player_index = twoPlayerMode and 1 or 0
	tempW = weaponPort[player[player_index].items.weapon[REAR_WEAPON].id].opnum
	return tempW
end

function JE_drawShield()
	JE_dBar3(VGAScreen, 270, 194, player[0].shield, 144)
	if player[0].shield ~= player[0].shield_max then
		local yy = 193 - (player[0].shield_max * 2)
		JE_rectangle(VGAScreen, 270, yy, 278, yy, 68)
	end
end

function JE_drawArmor()
	for i = 0, 1 do
		if player[i].armor > 28 then player[i].armor = 28 end
	end

	JE_dBar3(VGAScreen, 307, 194, player[0].armor, 224)
end

function JE_doSP(x_, y_, num, explowidth, color)
	for t = 0, num - 1 do
		local tempr = mt_rand_lt1() * (2 * M_PI)
		local tempy = roundf(math.cos(tempr) * mt_rand_1() * explowidth)
		local tempx = roundf(math.sin(tempr) * mt_rand_1() * explowidth)

		last_superpixel = last_superpixel + 1
		if last_superpixel >= MAX_SUPERPIXELS then last_superpixel = 0 end
		local sp = superpixels[last_superpixel]
		sp.x = tempx + x_
		sp.y = tempy + y_
		sp.delta_x = tempx
		sp.delta_y = tempy + 1
		sp.color = color
		sp.z = 15
	end
	temp = u8(num)
end

function JE_drawSP()
	for i = MAX_SUPERPIXELS - 1, 0, -1 do
		local sp = superpixels[i]
		if sp.z ~= 0 then
			sp.x = sp.x + sp.delta_x
			sp.y = sp.y + sp.delta_y

			if sp.x >= 0 and sp.y >= 0 and sp.x < VGAScreen.w and sp.y < VGAScreen.h then
				-- Approximation: a small cross in the superpixel colour.
				local c = sp.color + math.floor(sp.z / 2) + 7
				local c2 = sp.color + math.floor(sp.z / 4) + 4
				JE_pix(VGAScreen, sp.x, sp.y, c)
				JE_pix(VGAScreen, sp.x - 1, sp.y, c2)
				JE_pix(VGAScreen, sp.x + 1, sp.y, c2)
				JE_pix(VGAScreen, sp.x, sp.y - 1, c2)
				JE_pix(VGAScreen, sp.x, sp.y + 1, c2)
			end

			sp.z = sp.z - 1
		end
	end
end
