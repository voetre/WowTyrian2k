--[[
 WowTyrian2k: a World of Warcraft port of OpenTyrian
 Copyright (C) The OpenTyrian Development Team
 Lua port Copyright (C) 2026 voetre
 Licensed under the GNU General Public License v2 or later (see COPYING).

 Small modules: sndmast.c, musmast.c, pcxmast.c, lvlmast.c, lvllib.c,
 nortvars.c, picload.c, pcxload.c, mouse.c, editship.c, params.c, player.c,
 episodes.c
]]
local _, ns = ...
setfenv(1, ns.G)

-- sndmast.h ---------------------------------------------------------------------
SFX_COUNT = 29
VOICE_COUNT = 9
SOUND_COUNT = SFX_COUNT + VOICE_COUNT

S_NONE = 0; S_WEAPON_1 = 1; S_WEAPON_2 = 2; S_ENEMY_HIT = 3; S_EXPLOSION_4 = 4
S_WEAPON_5 = 5; S_WEAPON_6 = 6; S_WEAPON_7 = 7; S_SELECT = 8; S_EXPLOSION_8 = 8
S_EXPLOSION_9 = 9; S_WEAPON_10 = 10; S_EXPLOSION_11 = 11; S_EXPLOSION_12 = 12
S_WEAPON_13 = 13; S_WEAPON_14 = 14; S_WEAPON_15 = 15; S_SPRING = 16; S_WARNING = 17
S_ITEM = 18; S_HULL_HIT = 19; S_MACHINE_GUN = 20; S_SOUL_OF_ZINGLON = 21
S_EXPLOSION_22 = 22; S_CLINK = 23; S_CLICK = 24; S_WEAPON_25 = 25; S_WEAPON_26 = 26
S_SHIELD_HIT = 27; S_CURSOR = 28; S_POWERUP = 29
V_CLEARED_PLATFORM = 30; V_BOSS = 31; V_ENEMIES = 32; V_GOOD_LUCK = 33
V_LEVEL_END = 34; V_DANGER = 35; V_SPIKES = 36; V_DATA_CUBE = 37; V_ACCELERATE = 38

windowTextSamples = { [0] = V_DANGER, V_BOSS, V_ENEMIES, V_CLEARED_PLATFORM, V_DANGER,
	V_SPIKES, V_ACCELERATE, V_DANGER, V_ENEMIES }

-- musmast.c ---------------------------------------------------------------------
DEFAULT_SONG_BUY = 2
SONG_LEVELEND = 9
SONG_GAMEOVER = 10
SONG_MAPVIEW = 19
SONG_ENDGAME1 = 7
SONG_ZANAC = 31
SONG_TITLE = 29
MUSIC_NUM = 41
songBuy = 0
musicFade = false

-- pcxmast.c ---------------------------------------------------------------------
PCX_NUM = 13
pcxpal = { [0] = 0, 7, 5, 8, 10, 5, 18, 19, 19, 20, 21, 22, 5 }
facepal = { [0] = 1, 2, 3, 4, 6, 9, 11, 12, 16, 13, 14, 15 }

-- lvlmast.c ---------------------------------------------------------------------
EVENT_MAXIMUM = 2500
WEAP_NUM = 780
PORT_NUM = 42
ARMOR_NUM = 4
POWER_NUM = 6
ENGINE_NUM = 6
OPTION_NUM = 30
SHIP_NUM = 13
SHIELD_NUM = 10
SPECIAL_NUM = 46
ENEMY_NUM = 850

shapeFile = { [0] = '2', '4', '7', '8', 'A', 'B', 'C', 'D', 'E', 'F',
	'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P',
	'Q', 'R', 'S', 'T', 'U', '5', '#', 'V', '0', '@',
	'3', '^', '5', '9' }

-- lvllib.c ----------------------------------------------------------------------
lvlPos = newArray(43, 0)
levelFilename = ""
lvlNum = 0

function analyzeLevel()
	local file = dataFileOpen(levelFilename)
	lvlNum = fileReadU16(file)
	lvlNum = MIN(lvlNum, 42)
	for i = 0, lvlNum - 1 do lvlPos[i] = fileReadU32(file) end
	local len = fileGetLength(file)
	for i = lvlNum, 42 do lvlPos[i] = len end
end

-- nortvars.c --------------------------------------------------------------------
function JE_dBar3(surface, x, y, num, col)
	local zWait = 2
	col = col + 2
	for z = 0, num do
		JE_rectangle(surface, x, y - 1, x + 8, y, col)
		if zWait > 0 then
			zWait = zWait - 1
		else
			col = col + 1
			zWait = 1
		end
		y = y - 2
	end
end

function JE_barDrawShadow(surface, x, y, res, col, amt, xsize, ysize)
	xsize = xsize - 1
	ysize = ysize - 1
	for z = 1, math.floor(amt / res) do
		JE_barShade(surface, x + 2, y + 2, x + xsize + 2, y + ysize + 2)
		fill_rectangle_xy(surface, x, y, x + xsize, y + ysize, col + 12)
		fill_rectangle_xy(surface, x, y, x + xsize, y, col + 13)
		JE_pix(surface, x, y, col + 15)
		fill_rectangle_xy(surface, x, y + ysize, x + xsize, y + ysize, col + 11)
		x = x + xsize + 2
	end
	amt = amt % res
	if amt > 0 then
		JE_barShade(surface, x + 2, y + 2, x + xsize + 2, y + ysize + 2)
		fill_rectangle_xy(surface, x, y, x + xsize, y + ysize, col + math.floor(12 / res) * amt)
	end
end

-- picload.c / pcxload.c ------------------------------------------------------------
function JE_loadPic(screen, id, storepal)
	if id < 1 or id > PCX_NUM then
		logError("Attempted to load picture %d, which does not exist.", id)
		return
	end
	pushPic(screen, ns.gfxmeta.pics[id], 0, 0, 320, 200, 0, 0)
	copyPalette(colors, palettes[pcxpal[id - 1]])
	if storepal then
		set_palette(colors, 0, 255)
	end
end

function JE_loadPCX(filename)
	-- tshp2.pcx has its own palette; the texture is baked with it, so keep the
	-- logical palette black-referenced (only the picture is shown).
	pushPic(VGAScreen, ns.gfxmeta.pcx, 0, 0, 320, 200, 0, 0)
	colors.id = -1
end

-- mouse.c -----------------------------------------------------------------------
has_mouse = true
mouse_has_three_buttons = true
mouseCursor = 0

MOUSE_POINTER_NORMAL = 0
MOUSE_POINTER_UP = 1
MOUSE_POINTER_DOWN = 2
MOUSE_POINTER_LEFT = 3
MOUSE_POINTER_RIGHT = 4

local mousePointerSprites = {
	[0] = { 273, 0, 0, 11, 16, 0, 0 },
	{ 275, 0, 0, 21, 16, 10, 8 },
	{ 277, 0, 0, 21, 16, 10, 7 },
	{ 279, 0, 0, 16, 21, 8, 10 },
	{ 281, 8, 0, 16, 21, 7, 10 },
}

local mouseGrabN

function JE_mouseStart()
	mouseGrabN = VGAScreen.n
	if not mouseInactive and ns.showGameCursor then
		local info = mousePointerSprites[mouseCursor]
		blit_sprite2x2_clip(VGAScreen, mouseX - info[2] - info[6], mouseY - info[3] - info[7], shopSpriteSheet, info[1])
	end
end

function JE_mouseStartFilter(filter)
	mouseGrabN = VGAScreen.n
	if not mouseInactive and ns.showGameCursor then
		local info = mousePointerSprites[mouseCursor]
		blit_sprite2x2_filter_clip(VGAScreen, mouseX - info[2] - info[6], mouseY - info[3] - info[7], shopSpriteSheet, info[1], filter)
	end
end

function JE_mouseReplace()
	if mouseGrabN then
		-- the op tables stay in the pool for reuse
		VGAScreen.n = mouseGrabN
		mouseGrabN = nil
	end
end

-- editship.c (custom ships are not supported) --------------------------------------
extraAvail = false
extraShips = newArray(154, 0)
function loadExtraShapes() end

-- params.c ------------------------------------------------------------------------
richMode = false
constantPlay = false
constantDie = false

-- Leftovers of the original's network code that the single-player game
-- still uses.
haltGame = false
moveOk = false
yourInGameMenuRequest = false

-- xmas.c ---------------------------------------------------------------------------
xmas = false

-- player.c ---------------------------------------------------------------------------
FRONT_WEAPON = 0
REAR_WEAPON = 1
LEFT_SIDEKICK = 0
RIGHT_SIDEKICK = 1

local function newPlayerItems()
	return {
		ship = 0, generator = 0, shield = 0,
		weapon = { [0] = { id = 0, power = 0 }, { id = 0, power = 0 } },
		sidekick = { [0] = 0, 0 },
		special = 0,
		sidekick_series = 0,
		sidekick_level = 0,
		super_arcade_mode = 0,
	}
end
ns.newPlayerItems = newPlayerItems

local function newPlayer()
	local p = {
		cash = 0,
		items = newPlayerItems(), last_items = newPlayerItems(),
		is_dragonwing = false,
		lives = nil,     -- weapon table whose .power is the life count (see JE_initPlayerData)
		shield_max = 0, initial_armor = 0,
		shot_hit_area_x = 0, shot_hit_area_y = 0,
		is_alive = false,
		invulnerable_ticks = 0, exploding_ticks = 0,
		shield = 0, armor = 0, weapon_mode = 0, superbombs = 0, purple_balls_needed = 0,
		mouseX = 0, mouseY = 0,
		x = 0, y = 0,
		old_x = newArray(20, 0), old_y = newArray(20, 0),
		x_velocity = 0, y_velocity = 0,
		x_friction_ticks = 0, y_friction_ticks = 0,
		delta_x_shot_move = 0, delta_y_shot_move = 0,
		last_x_shot_move = 0, last_y_shot_move = 0,
		last_x_explosion_follow = 0, last_y_explosion_follow = 0,
		sidekick = {},
	}
	for i = 0, 1 do
		p.sidekick[i] = {
			ammo_max = 0, ammo_refill_ticks_max = 0, style = 0,
			x = 0, y = 0, ammo = 0, ammo_refill_ticks = 0,
			animation_enabled = false, animation_frame = 0,
			charge = 0, charge_ticks = 0,
		}
	end
	return p
end

player = { [0] = newPlayer(), newPlayer() }

-- In the C code `lives` points at items.weapon[p].power; here `lives` holds
-- that weapon table and the value is its `power` field.
function getLives(p) return p.lives.power end
function setLives(p, v) p.lives.power = v end

function all_players_dead()
	return not player[0].is_alive and (not twoPlayerMode or not player[1].is_alive)
end

function all_players_alive()
	return player[0].is_alive and (not twoPlayerMode or player[1].is_alive)
end

local purple_balls_required = { [0] = 1, 1, 2, 4, 8, 12, 16, 20, 25, 30, 40, 50 }

function calc_purple_balls_needed(this_player)
	this_player.purple_balls_needed = purple_balls_required[this_player.lives.power]
end

function power_up_weapon(this_player, port)
	local w = this_player.items.weapon[port]
	local can_power_up = w.id ~= 0 and w.power < 11
	if can_power_up then
		w.power = w.power + 1
		shotMultiPos[port] = 0
		calc_purple_balls_needed(this_player)
	else
		this_player.cash = this_player.cash + 1000
	end
	return can_power_up
end

function handle_got_purple_ball(this_player)
	if this_player.purple_balls_needed > 1 then
		this_player.purple_balls_needed = this_player.purple_balls_needed - 1
	else
		power_up_weapon(this_player, this_player.is_dragonwing and REAR_WEAPON or FRONT_WEAPON)
	end
end

-- episodes.c -----------------------------------------------------------------------
FIRST_LEVEL = 1
EPISODE_MAX = 5
EPISODE_AVAILABLE = 4

local function newWeapon()
	return {
		drain = 0, shotrepeat = 0, multi = 0, weapani = 0, max = 0, tx = 0, ty = 0, aim = 0,
		attack = newArray(8, 0), del = newArray(8, 0),
		sx = newArray(8, 0), sy = newArray(8, 0), bx = newArray(8, 0), by = newArray(8, 0),
		sg = newArray(8, 0),
		acceleration = 0, accelerationx = 0, circlesize = 0, sound = 0, trail = 0, shipblastfilter = 0,
	}
end

weaponPort = newArray(PORT_NUM + 1, function() return { name = "", opnum = 0, op = { [0] = newArray(11, 0), newArray(11, 0) }, cost = 0, itemgraphic = 0, poweruse = 0 } end)
weapons = newArray(WEAP_NUM + 1, newWeapon)
powerSys = newArray(POWER_NUM + 1, function() return { name = "", itemgraphic = 0, power = 0, speed = 0, cost = 0 } end)
ships = newArray(SHIP_NUM + 1, function() return { name = "", shipgraphic = 0, itemgraphic = 0, ani = 0, spd = 0, dmg = 0, cost = 0, bigshipgraphic = 0 } end)
options = newArray(OPTION_NUM + 1, function() return { name = "", pwr = 0, itemgraphic = 0, cost = 0, tr = 0, option = 0, opspd = 0, ani = 0, gr = newArray(20, 0), wport = 0, wpnum = 0, ammo = 0, stop = false, icongr = 0 } end)
shields = newArray(SHIELD_NUM + 1, function() return { name = "", tpwr = 0, mpwr = 0, itemgraphic = 0, cost = 0 } end)
special = newArray(SPECIAL_NUM + 1, function() return { name = "", itemgraphic = 0, pwr = 0, stype = 0, wpn = 0 } end)
enemyDat = newArray(ENEMY_NUM + 1, function()
	return {
		ani = 0, tur = newArray(3, 0), freq = newArray(3, 0),
		xmove = 0, ymove = 0, xaccel = 0, yaccel = 0, xcaccel = 0, ycaccel = 0,
		startx = 0, starty = 0, startxc = 0, startyc = 0,
		armor = 0, esize = 0, egraphic = newArray(20, 0),
		explosiontype = 0, animate = 0, shapebank = 0, xrev = 0, yrev = 0,
		dgr = 0, dlevel = 0, dani = 0, elaunchfreq = 0, elaunchtype = 0, value = 0, eenemydie = 0,
	}
end)

initial_episode_num = 0
episodeNum = 0
episodeAvail = newArray(EPISODE_MAX, false)
episodeFilename = ""
cubeFilename = ""
bonusLevel = false
jumpBackToEpisode1 = false

local function readName(file)
	local nameLen = fileReadU8(file)
	local name = fileReadString(file, 30)
	return string.sub(name, 1, MIN(nameLen, 30))
end

function JE_loadItemDat()
	local file
	if episodeNum <= 3 then
		file = dataFileOpen("tyrian.hdt")
		fileSetPosition(file, fileReadU32(file))
	else
		file = dataFileOpen(levelFilename)
		fileSetPosition(file, lvlPos[lvlNum - 1])
	end

	fileReadU16Array(file, {}, 7)

	local R8, RS8, R16, RS16 = fileReadU8, fileReadS8, fileReadU16, fileReadS16
	for i = 0, WEAP_NUM do
		local w = weapons[i]
		w.drain = R16(file)
		w.shotrepeat = R8(file)
		w.multi = R8(file)
		w.weapani = R16(file)
		w.max = R8(file)
		w.tx = R8(file)
		w.ty = R8(file)
		w.aim = R8(file)
		fileReadU8Array(file, w.attack, 8)
		fileReadU8Array(file, w.del, 8)
		fileReadS8Array(file, w.sx, 8)
		fileReadS8Array(file, w.sy, 8)
		fileReadS8Array(file, w.bx, 8)
		fileReadS8Array(file, w.by, 8)
		fileReadU16Array(file, w.sg, 8)
		w.acceleration = RS8(file)
		w.accelerationx = RS8(file)
		w.circlesize = R8(file)
		w.sound = R8(file)
		w.trail = R8(file)
		w.shipblastfilter = R8(file)
	end

	for i = 0, PORT_NUM do
		local p = weaponPort[i]
		p.name = readName(file)
		p.opnum = R8(file)
		fileReadU16Array(file, p.op[0], 11)
		fileReadU16Array(file, p.op[1], 11)
		p.cost = R16(file)
		p.itemgraphic = R16(file)
		p.poweruse = R16(file)
	end

	for i = 0, SPECIAL_NUM do
		local s = special[i]
		s.name = readName(file)
		s.itemgraphic = R16(file)
		s.pwr = R8(file)
		s.stype = R8(file)
		s.wpn = R16(file)
	end

	for i = 0, POWER_NUM do
		local p = powerSys[i]
		p.name = readName(file)
		p.itemgraphic = R16(file)
		p.power = R8(file)
		p.speed = RS8(file)
		p.cost = R16(file)
	end

	for i = 0, SHIP_NUM do
		local s = ships[i]
		s.name = readName(file)
		s.shipgraphic = R16(file)
		s.itemgraphic = R16(file)
		s.ani = R8(file)
		s.spd = RS8(file)
		s.dmg = R8(file)
		s.cost = R16(file)
		s.bigshipgraphic = R8(file)
	end

	for i = 0, OPTION_NUM do
		local o = options[i]
		o.name = readName(file)
		o.pwr = R8(file)
		o.itemgraphic = R16(file)
		o.cost = R16(file)
		o.tr = R8(file)
		o.option = R8(file)
		o.opspd = RS8(file)
		o.ani = R8(file)
		fileReadU16Array(file, o.gr, 20)
		o.wport = R8(file)
		o.wpnum = R16(file)
		o.ammo = R8(file)
		o.stop = fileReadBool(file)
		o.icongr = R8(file)
	end

	for i = 0, SHIELD_NUM do
		local s = shields[i]
		s.name = readName(file)
		s.tpwr = R8(file)
		s.mpwr = R8(file)
		s.itemgraphic = R16(file)
		s.cost = R16(file)
	end

	for i = 0, ENEMY_NUM do
		local e = enemyDat[i]
		e.ani = R8(file)
		fileReadU8Array(file, e.tur, 3)
		fileReadU8Array(file, e.freq, 3)
		e.xmove = RS8(file)
		e.ymove = RS8(file)
		e.xaccel = RS8(file)
		e.yaccel = RS8(file)
		e.xcaccel = RS8(file)
		e.ycaccel = RS8(file)
		e.startx = RS16(file)
		e.starty = RS16(file)
		e.startxc = RS8(file)
		e.startyc = RS8(file)
		e.armor = R8(file)
		e.esize = R8(file)
		fileReadU16Array(file, e.egraphic, 20)
		e.explosiontype = R8(file)
		e.animate = R8(file)
		e.shapebank = R8(file)
		e.xrev = RS8(file)
		e.yrev = RS8(file)
		e.dgr = R16(file)
		e.dlevel = RS8(file)
		e.dani = RS8(file)
		e.elaunchfreq = R8(file)
		e.elaunchtype = R16(file)
		e.value = RS16(file)
		e.eenemydie = R16(file)
	end

	if file.error then
		logFatal("Failed to read item data")
	end
end

function JE_initEpisode(newEpisode)
	if newEpisode == episodeNum then return end
	episodeNum = newEpisode
	levelFilename = sprintf("tyrian%d.lvl", episodeNum)
	cubeFilename = sprintf("cubetxt%d.dat", episodeNum)
	episodeFilename = sprintf("levels%d.dat", episodeNum)
	analyzeLevel()
	JE_loadItemDat()
end

function JE_scanForEpisodes()
	for i = 0, EPISODE_MAX - 1 do
		episodeAvail[i] = dataFileExists(sprintf("tyrian%d.lvl", i + 1))
	end
end

function JE_findNextEpisode()
	local newEpisode = episodeNum
	jumpBackToEpisode1 = false
	while true do
		newEpisode = newEpisode + 1
		if newEpisode > EPISODE_MAX then
			newEpisode = 1
			jumpBackToEpisode1 = true
			gameHasRepeated = true
		end
		if episodeAvail[newEpisode - 1] or newEpisode == episodeNum then
			break
		end
	end
	return newEpisode
end
