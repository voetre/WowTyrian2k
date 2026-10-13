--[[
 WowTyrian2k: a World of Warcraft port of OpenTyrian
 Copyright (C) The OpenTyrian Development Team
 Lua port Copyright (C) 2026 voetre
 Licensed under the GNU General Public License v2 or later (see COPYING).

 config.c - configuration and saved games are stored in the WowTyrian2kDB
 saved variable instead of tyrian.cfg / tyrian.sav.
]]
local _, ns = ...
setfenv(1, ns.G)

SAVE_FILES_NUM = 11 * 2

DIFFICULTY_WIMP = 0
DIFFICULTY_EASY = 1
DIFFICULTY_NORMAL = 2
DIFFICULTY_HARD = 3
DIFFICULTY_IMPOSSIBLE = 4
DIFFICULTY_INSANITY = 5
DIFFICULTY_SUICIDE = 6
DIFFICULTY_MANIACAL = 7
DIFFICULTY_ZINGLON = 8
DIFFICULTY_NORTANEOUS = 9
DIFFICULTY_10 = 10

KEY_SETTING_UP = 0
KEY_SETTING_DOWN = 1
KEY_SETTING_LEFT = 2
KEY_SETTING_RIGHT = 3
KEY_SETTING_FIRE = 4
KEY_SETTING_CHANGE_FIRE = 5
KEY_SETTING_LEFT_SIDEKICK = 6
KEY_SETTING_RIGHT_SIDEKICK = 7

SHOT_FRONT = 0
SHOT_REAR = 1
SHOT_LEFT_SIDEKICK = 2
SHOT_RIGHT_SIDEKICK = 3
SHOT_MISC = 4
SHOT_P2_CHARGE = 5
SHOT_P1_SUPERBOMB = 6
SHOT_P2_SUPERBOMB = 7
SHOT_SPECIAL = 8
SHOT_NORTSPARKS = 9
SHOT_SPECIAL2 = 10

defaultKeySettings = { [0] =
	SDL_SCANCODE_UP, SDL_SCANCODE_DOWN, SDL_SCANCODE_LEFT, SDL_SCANCODE_RIGHT,
	SDL_SCANCODE_SPACE, SDL_SCANCODE_RETURN, SDL_SCANCODE_LCTRL, SDL_SCANCODE_LALT,
}

local defaultHighScoreNames = {
	"The Prime Chair", "Transon Lohk", "Javi Onukala", "Mantori", "Nortaneous", "Dougan", "Reid",
	"General Zinglon", "Late Gyges Phildren", "Vykromod", "Beppo", "Borogar", "ShipMaster Carlos",
	"Jill", "Darcy", "Jake Stone", "Malvineous Havershim", "Marta Louise Velasquez",
	"Jazz Jackrabbit", "Eva Earlong", "Devan Shell",
	"Crystal Devroe", "Steffan Tommas", "Milano Angston", "Christian", "Shirro", "Jean-Paul",
	"Ibrahim Hothe", "Angel", "Cossette Akira", "Raven", "Hans Kreissack",
	"Tyler", "Rennis the Rat Guard",
}

local defaultTeamNames = {
	"Jackrabbits", "Team Tyrian", "The Elam Brothers", "Dare to Dream Team", "Pinball Freaks",
	"Extreme Pinball Freaks", "Team Vykromod", "Epic All-Stars", "Hans Keissack's WARriors",
	"Team Overkill", "Pied Pipers", "Gencore Growlers", "Microsol Masters", "Beta Warriors",
	"Team Loco", "The Shellians", "Jungle Jills", "Murderous Malvineous", "The Traffic Department",
	"Clan Mikal", "Clan Patrok", "Carlos' Crawlers",
}

local initialEditorItemAvail = {
	1,1,1,0,0,1,1,0,1,1,1,1,1,0,1,0,1,1,1,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,0,0,1,
	1,0,0,0,0,1,0,0,0,1,1,0,1,0,0,0,0,0,
	0,0,0,0,0,0,0,0,0,0,0,
	1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	0,0,0,0,0,
}

smoothies = newArray(9, false)
starShowVGASpecialCode = 0

lastCubeMax, cubeMax = 0, 0
cubeList = newArray(4, 0)

gameHasRepeated = false

difficultyLevel, oldDifficultyLevel, initialDifficulty = 0, 0, 0

power, lastPower, powerAdd = 0, 0, 0
shieldWait, shieldT = 0, 0

shotRepeat = newArray(11, 0)
shotMultiPos = newArray(11, 0)
portConfigChange, portConfigDone = false, false

lastLevelName, levelName = "", ""
mainLevel, nextLevel, saveLevel = 0, 0, 0

keySettings = copyArray({}, defaultKeySettings, 8)

levelFilter, levelFilterNew, levelBrightness, levelBrightnessChg = 0, 0, 0, 0
filtrationAvail, filterActive, filterFade, filterFadeStart = false, false, false, false

gameJustLoaded = false
galagaMode = false
extraGame = false
twoPlayerMode, twoPlayerLinked, onePlayerAction, superTyrian = false, false, false, false
trentWin = false
superArcadeMode = 0
superArcadePowerUp = 0
linkGunDirec = 0
inputDevice = { [0] = 1, 2 }
secretHint = 0
background3over = 0
background2over = 0
gammaCorrection = 0
superPause = false
explosionTransparent, youAreCheating, displayScore, background2, smoothScroll = false, false, false, false, false
wild, superWild, starActive, topEnemyOver, skyEnemyOverAll, background2notTransparent = false, false, false, false, false, false
fastPlay = 0
pentiumMode = false
gameSpeed = 0
processorType = 0

local function newSaveFile()
	return {
		encode = 0, level = 0, items = newArray(12, 0), score = 0, score2 = 0,
		levelName = "", name = "              ", cubes = 0, power = { [0] = 0, 0 }, episode = 0,
		lastItems = newArray(12, 0), difficulty = 0, secretHint = 0, input1 = 0, input2 = 0,
		gameHasRepeated = false, initialDifficulty = 0,
		highScore1 = 0, highScore2 = 0, highScoreName = "", highScoreDiff = 0,
	}
end

saveFiles = newArray(SAVE_FILES_NUM, newSaveFile)
editorItemAvail = newArray(100, 0)
editorLevel = 0

local function playeritems_to_pitems(pItems, items, initial_episode)
	pItems[0] = items.weapon[FRONT_WEAPON].id
	pItems[1] = items.weapon[REAR_WEAPON].id
	pItems[2] = items.super_arcade_mode
	pItems[3] = items.sidekick[LEFT_SIDEKICK]
	pItems[4] = items.sidekick[RIGHT_SIDEKICK]
	pItems[5] = items.generator
	pItems[6] = items.sidekick_level
	pItems[7] = items.sidekick_series
	pItems[8] = initial_episode
	pItems[9] = items.shield
	pItems[10] = items.special
	pItems[11] = items.ship
end

local function pitems_to_playeritems(items, pItems)
	items.weapon[FRONT_WEAPON].id = pItems[0]
	items.weapon[REAR_WEAPON].id = pItems[1]
	items.super_arcade_mode = pItems[2]
	items.sidekick[LEFT_SIDEKICK] = pItems[3]
	items.sidekick[RIGHT_SIDEKICK] = pItems[4]
	items.generator = pItems[5]
	items.sidekick_level = pItems[6]
	items.sidekick_series = pItems[7]
	items.shield = pItems[9]
	items.special = pItems[10]
	items.ship = pItems[11]
	return pItems[8]
end

function JE_saveGame(slot, name)
	local sf = saveFiles[slot - 1]
	sf.initialDifficulty = initialDifficulty
	sf.gameHasRepeated = gameHasRepeated
	sf.level = saveLevel

	if superTyrian then
		player[0].items.super_arcade_mode = SA_SUPERTYRIAN
	elseif superArcadeMode == SA_NONE and onePlayerAction then
		player[0].items.super_arcade_mode = SA_ARCADE
	else
		player[0].items.super_arcade_mode = superArcadeMode
	end

	playeritems_to_pitems(sf.items, player[0].items, initial_episode_num)

	playeritems_to_pitems(sf.lastItems, player[0].last_items, 0)

	sf.score = player[0].cash
	sf.score2 = 0

	sf.levelName = lastLevelName
	sf.cubes = lastCubeMax

	if lastLevelName == "Completed" then
		temp = episodeNum - 1
		if temp < 1 then temp = EPISODE_AVAILABLE end
		sf.episode = temp
	else
		sf.episode = episodeNum
	end

	sf.difficulty = difficultyLevel
	sf.secretHint = secretHint
	sf.input1 = inputDevice[0]
	sf.input2 = 0

	sf.name = string.sub(name .. "              ", 1, 14)

	for port = 0, 1 do
		sf.power[port] = player[0].items.weapon[port].power
	end

	saveSaves()
end

function JE_loadGame(slot)
	superTyrian = false
	onePlayerAction = false
	twoPlayerMode = false
	extraGame = false
	galagaMode = false

	local sf = saveFiles[slot - 1]
	initialDifficulty = sf.initialDifficulty
	gameHasRepeated = sf.gameHasRepeated
	difficultyLevel = sf.difficulty

	initial_episode_num = pitems_to_playeritems(player[0].items, sf.items)

	superArcadeMode = player[0].items.super_arcade_mode

	if superArcadeMode == SA_SUPERTYRIAN then superTyrian = true end
	if superArcadeMode ~= SA_NONE then onePlayerAction = true end
	if superArcadeMode > SA_NORTSHIPZ then superArcadeMode = SA_NONE end

	pitems_to_playeritems(player[0].last_items, sf.lastItems)

	player[0].cash = sf.score

	mainLevel = sf.level
	cubeMax = sf.cubes
	lastCubeMax = cubeMax

	secretHint = sf.secretHint
	inputDevice[0] = sf.input1

	for port = 0, 1 do
		player[0].items.weapon[port].power = sf.power[port]
	end

	local episode = sf.episode

	levelName = sf.levelName

	if levelName == "Completed" then
		if episode == EPISODE_AVAILABLE then
			episode = 1
		elseif episode < EPISODE_AVAILABLE then
			episode = episode + 1
		end
	end

	JE_initEpisode(episode)
	saveLevel = mainLevel
	lastLevelName = levelName
end

function JE_initProcessorType()
	wild = false
	superWild = false
	smoothScroll = true
	explosionTransparent = true
	filtrationAvail = false
	background2 = true
	displayScore = true

	if processorType == 1 then
		background2 = false
		displayScore = false
		explosionTransparent = false
	elseif processorType == 3 then
		smoothScroll = false
	elseif processorType == 4 then
		wild = true
		filtrationAvail = true
	elseif processorType == 5 then
		smoothScroll = false
	elseif processorType == 6 then
		wild = true
		superWild = true
		filtrationAvail = true
	end

	if gameSpeed == 1 then fastPlay = 3
	elseif gameSpeed == 2 then fastPlay = 4
	elseif gameSpeed == 3 then fastPlay = 5
	elseif gameSpeed == 4 then fastPlay = 0
	elseif gameSpeed == 5 then fastPlay = 1
	end
end

function JE_setNewGameSpeed()
	pentiumMode = false

	local speed
	if fastPlay == 1 then
		speed = 0x3000
		smoothScroll = true
		frameCountMax = 2
	elseif fastPlay == 2 then
		speed = 0x2000
		smoothScroll = false
		frameCountMax = 2
	elseif fastPlay == 3 then
		speed = 0x5300
		smoothScroll = true
		frameCountMax = 4
	elseif fastPlay == 4 then
		speed = 0x4300
		smoothScroll = true
		frameCountMax = 3
	elseif fastPlay == 5 then
		speed = 0x4300
		smoothScroll = true
		frameCountMax = 2
		pentiumMode = true
	else
		speed = 0x4300
		smoothScroll = true
		frameCountMax = 2
	end

	setFrameSpeed(speed)
	setFrameCount(frameCountMax)
end

function loadConfiguration()
	local db = ns.db or {}
	local cfg = db.config
	if cfg then
		background2 = cfg.background2
		gameSpeed = cfg.gameSpeed
		processorType = cfg.processorType
		gammaCorrection = cfg.gammaCorrection or 0
		difficultyLevel = cfg.difficultyLevel or 0
		tyrMusicVolume = cfg.tyrMusicVolume or 223
		fxVolume = cfg.fxVolume or 223
		music_disabled = cfg.musicDisabled or false
		samples_disabled = cfg.samplesDisabled or false
		if cfg.keySettings then
			for i = 0, 7 do keySettings[i] = cfg.keySettings[i + 1] or defaultKeySettings[i] end
		end
	else
		background2 = true
		gameSpeed = 4
		processorType = 3
		gammaCorrection = 0
		difficultyLevel = 0
		tyrMusicVolume = 223
		fxVolume = 223
	end

	set_volume(tyrMusicVolume, fxVolume)
	JE_initProcessorType()
end

function saveConfiguration()
	if not ns.db then return end
	local ks = {}
	for i = 0, 7 do ks[i + 1] = keySettings[i] end
	ns.db.config = {
		background2 = background2,
		gameSpeed = gameSpeed,
		processorType = processorType,
		gammaCorrection = gammaCorrection,
		difficultyLevel = difficultyLevel,
		tyrMusicVolume = tyrMusicVolume,
		fxVolume = fxVolume,
		musicDisabled = music_disabled or nil,
		samplesDisabled = samples_disabled or nil,
		keySettings = ks,
	}
end

local function serializeArray(t, n)
	local r = {}
	for i = 0, n - 1 do r[i + 1] = t[i] end
	return r
end

local function deserializeArray(t, src, n)
	for i = 0, n - 1 do t[i] = src[i + 1] or 0 end
end

function loadSaves()
	local db = ns.db or {}
	local saves = db.saves
	if saves and #saves == SAVE_FILES_NUM then
		for i = 0, SAVE_FILES_NUM - 1 do
			local src, sf = saves[i + 1], saveFiles[i]
			for k, v in pairs(src) do
				if type(v) ~= "table" then sf[k] = v end
			end
			deserializeArray(sf.items, src.items or {}, 12)
			deserializeArray(sf.lastItems, src.lastItems or {}, 12)
			deserializeArray(sf.power, src.power or {}, 2)
		end
		deserializeArray(editorItemAvail, db.editorItemAvail or initialEditorItemAvail, 100)
		editorLevel = db.editorLevel or 800
		return
	end

	for i = 0, SAVE_FILES_NUM - 1 do
		local sf = saveFiles[i]
		structAssign(sf, newSaveFile())
		sf.level = 0
		sf.name = "              "
		sf.highScore1 = ((mt_rand() % 20) + 1) * 1000
		if i % 6 < 3 then
			sf.highScore2 = 0
			sf.highScoreName = defaultHighScoreNames[(mt_rand() % #defaultHighScoreNames) + 1]
		else
			sf.highScore2 = ((mt_rand() % 20) + 1) * 1000
			sf.highScoreName = defaultTeamNames[(mt_rand() % #defaultTeamNames) + 1]
		end
		sf.highScoreDiff = 0
	end

	deserializeArray(editorItemAvail, initialEditorItemAvail, 100)
	editorLevel = 800
end

function saveSaves()
	if not ns.db then return end
	local saves = {}
	for i = 0, SAVE_FILES_NUM - 1 do
		local sf = saveFiles[i]
		local d = {}
		for k, v in pairs(sf) do
			if type(v) ~= "table" then d[k] = v end
		end
		d.items = serializeArray(sf.items, 12)
		d.lastItems = serializeArray(sf.lastItems, 12)
		d.power = serializeArray(sf.power, 2)
		saves[i + 1] = d
	end
	ns.db.saves = saves
	ns.db.editorItemAvail = serializeArray(editorItemAvail, 100)
	ns.db.editorLevel = editorLevel
end

function ns.saveConfigToDB()
	saveConfiguration()
	saveSaves()
end
