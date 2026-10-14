--[[
 WowTyrian2k: a World of Warcraft port of OpenTyrian
 Copyright (C) The OpenTyrian Development Team
 Lua port Copyright (C) 2026 voetre
 Licensed under the GNU General Public License v2 or later (see COPYING).

 Level generator (new for this port): endless background maps built from
 segments of the original levels.

 Data/levgen.lua (made by tools/levgen/build.py) holds, per tile set, theme
 (a group of levels with similar art) and map layer, a graph of segments.  A segment is a row range of an original level
 map; an edge says which segment may be placed above it, either directly
 (its natural successor in the source map) or after a few generated bridge
 rows.  Every 2x2 tile window along the joins occurs in a real map, so the
 result is seamless.  A stream walks the graph and hands out rows bottom to
 top, the order the map scrolls in.

 Rows are tile ids: tile index + 1 in the tile set, 0 for nothing drawn.
]]
local _, ns = ...
setfenv(1, ns.G)

local strbyte, floor = string.byte, math.floor

-- Addon option k (Core/Options.lua), or `default` before the options load.
local function opt(k, default)
	local o = ns.options
	local v = o and o[k]
	if v == nil then return default end
	return v
end

-- Park-Miller generator, kept apart from mt_rand so demos and replays are
-- not disturbed.
local function newRng(seed)
	local s = floor(seed or 1) % 2147483647
	if s <= 0 then s = s + 2147483646 end
	-- the first draw is just 16807 * seed for small seeds, so skip it; and
	-- scale rather than s % n, since the multiplier is 7^5
	s = (s * 16807) % 2147483647
	return function(n)
		s = (s * 16807) % 2147483647
		return floor(s * n / 2147483647)
	end
end

LevelGen = {}

-- Index into ns.levgen.themes of the theme called `name`, or nil.
function LevelGen.themeIndex(name)
	for i, theme in ipairs(ns.levgen.themes) do
		if theme.name == name then return i end
	end
end

-- The theme names, for messages.
function LevelGen.themeNames()
	local out = {}
	for i, theme in ipairs(ns.levgen.themes) do out[i] = theme.name end
	return table.concat(out, " ")
end

-- Queues the rows of segment `seg` on the stream, bottom row first.
local function enterSegment(st, seg)
	local set = st.set
	st.seg = seg
	st.src = ns.levgen.src[set.seg[seg * 2 - 1]]
	st.data = ns.files[st.src.file]
	st.row = set.seg[seg * 2] + set.seglen - 1   -- source row, counts down
	st.rowEnd = set.seg[seg * 2]
	st.bridge = nil
end

-- Picks edge i of `nxt` (triples: segment, bridge, weight) with probability
-- by weight, among natural edges only when `naturalOnly`.  nil if none.
local function pickEdge(st, nxt, naturalOnly)
	local total = 0
	for i = 3, #nxt, 3 do
		if not naturalOnly or nxt[i - 1] == -1 then total = total + nxt[i] end
	end
	if total == 0 then return nil end
	local x = st.rnd(total)
	for i = 3, #nxt, 3 do
		if not naturalOnly or nxt[i - 1] == -1 then
			x = x - nxt[i]
			if x < 0 then return i - 2 end
		end
	end
end

-- Picks the next segment and, when needed, the bridge leading to it.
local function chooseNext(st)
	local nxt = st.set.nxt[st.seg]
	-- with probability st.natural take a step the source maps take (longer
	-- stretches of a real map), otherwise any edge; both weighted by how
	-- common the step or its target is in the source maps
	local pick
	if st.rnd(1000) < st.natural * 1000 then pick = pickEdge(st, nxt, true) end
	pick = pick or pickEdge(st, nxt, false)
	local bid = nxt[pick + 1]
	enterSegment(st, nxt[pick])
	if bid > 0 then
		st.bridge = st.set.br[bid]
		st.bridgePos = 0
	end
end

-- New row stream for one layer (1-3) of theme `theme` (an index into
-- ns.levgen.themes).
-- natural: 0..1, how often to keep following the source map (default 0.5).
function LevelGen.newStream(theme, layer, seed, natural)
	local set = ns.levgen.themes[theme][layer]
	local st = { set = set, w = set.w, rnd = newRng(seed), natural = natural or 0.5, layer = layer }
	enterSegment(st, 1 + st.rnd(#set.seg / 2))
	return st
end

-- Writes the next row (bottom to top) into out[1..w] and returns out.
function LevelGen.nextRow(st, out)
	local w = st.w
	local br = st.bridge
	if br then
		local p = st.bridgePos
		for c = 1, w do out[c] = br[p + c] end
		p = p + w
		if p >= #br then st.bridge = nil else st.bridgePos = p end
		return out
	end
	local lut = st.src.lut[st.layer]
	local base = st.src.off[st.layer] + st.row * w
	local data = st.data
	for c = 1, w do
		out[c] = lut[strbyte(data, base + c) + 1] or 0
	end
	if st.row == st.rowEnd then
		chooseNext(st)
	else
		st.row = st.row - 1
	end
	return out
end

--[[ Test mode (/tyrian genlevel [tile set] [seed])

 Plays an endless level on one tile set.  A real level using that tile set
 is loaded as a template for its enemies and events, then its maps are
 replaced by generated ones.  Each map is used as a ring: rows are written a
 little ahead of the scroll, and the first 40 rows are also copied to the
 bottom, so when the view reaches row WRAP_ROW it can jump down by the period
 onto identical rows and carry on.

 Template events that would end the level, move the map or jump around the
 event list are made no-ops (kept in place, so relative skips still land
 right), and stopped layers get their normal speed back.  When the events
 run out they start again from the first enemy wave.

 A timed level (/tyrian flighttest, and later flight mode) lasts a set time
 and ends with the template's boss.  The template's events are split into
 its waves and its boss section (from just before the boss bar appears to
 the level end).  The waves repeat until BOSS_SECONDS before the end, getting
 harder on the way (RAMP: more of the waves kept, a higher difficulty), then
 the boss section plays as in the original level, end of level included.
]]
genLevel = nil   -- the running test, or nil

local WRAP_ROW = 20   -- view row that triggers the jump
local MARGIN = 40     -- rows kept at each end of the ring
local LOOK = 8        -- rows generated ahead of the top visible row (enough
                      -- to check the ground under scenery spawning above it)

local MAX_SCROLL = 4   -- fastest a layer scrolls, in pixels per frame

local NOOP_EVENTS = {
	[4] = true,   -- stop backgrounds
	[11] = true,  -- end level
	[34] = true,  -- music fade
	[36] = true,  -- ready to end level
	[38] = true,  -- jump to time
	[44] = true,  -- colour filter (CORE fades to black for its ending)
	[54] = true,  -- jump
	[61] = true,  -- jump on global flag
	[67] = true,  -- level timer
	[70] = true,  -- jump when enemies gone
	[71] = true,  -- jump on map position
	[75] = true,  -- jump on enemies
	[77] = true,  -- set map position
	[81] = true,  -- background 2 wrap
}
local ENEMY_EVENTS = {
	[6] = true, [7] = true, [10] = true, [12] = true, [15] = true, [17] = true,
	[18] = true, [23] = true, [32] = true, [56] = true,
	[49] = true, [50] = true, [51] = true, [52] = true,
}

-- Timed levels.
local BOSS_SECONDS = 50   -- left for a boss whose section loops until it dies
                          -- (otherwise the section's own length, to its end)
local MIN_SECONDS = 75    -- shortest timed level
LevelGen.MIN_SECONDS = MIN_SECONDS
local BOSS_INTRO = 100    -- the boss section starts this far (curLoc) before
                          -- the boss bar event: warning text, music change
local QUIET = 4           -- seconds before the boss with no new waves
local OVERTIME = 30       -- a boss still alive this long after the planned
                          -- end leaves, and the level ends
local WAVE_GAP = 40       -- a pause (curLoc) this long between spawns ends a wave
local PLAN_AHEAD = 300    -- waves are kept or dropped this far (curLoc) ahead,
                          -- before their scenery is decided (AHEAD)
-- Difficulty over the wave time (share of it gone): how many of the
-- template's waves are kept, and the game's difficulty level.
-- template's waves are kept, the game's difficulty level, and how often
-- the level's random enemies come (levelEnemyFrequency: one spawns when a
-- d100 roll beats it; the game's default is 96).
local RAMP = {
	{ at = 0, keep = 0.8, level = 1, freq = 95 },     -- easy
	{ at = 0.3, keep = 1, level = 2, freq = 93 },     -- normal
	{ at = 0.7, keep = 1, level = 3, freq = 90 },     -- hard: enemies fire twice as often
}
local BOSS_LEVEL = 2      -- normal

-- Arcade play.  Timed levels run as arcade mode (onePlayerAction): lives
-- are the front weapon's power, and killed enemies drop power-ups.  The
-- shorter the level, the stronger it starts (power factor 0-1), the more
-- generous the drops, and the tougher the waves and the boss.
local LONG_SECONDS = 900  -- a level this long or longer has power factor 0
local START_POWER = 2     -- front power (lives + 1) at power factor 0 ...
local START_POWER_ADD = 4 -- ... plus this much at power factor 1
local DROP_CHANCE = 0.12  -- share of kills that drop something at factor 0 ...
local DROP_CHANCE_ADD = 0.13  -- ... plus this at factor 1
local BOSS_LEVEL_ADD = 3  -- the boss is up to this many levels harder
local RAMP_LEVEL_ADD = 1  -- the waves are up to this many levels harder
-- Enemy density option: share of the template's waves kept, and a change
-- to the random enemies' frequency cap (lower spawns more).
local DENSITY = {
	low = { keep = 0.6, freq = 3 },
	normal = { keep = 1, freq = 0 },
	high = { keep = 1.25, freq = -4 },
}
local function density() return DENSITY[opt("genDensity", "normal")] or DENSITY.normal end

-- The difficulty level with the difficulty option added.
local function difficulty(level)
	return math.max(1, math.min(8, level + opt("genDifficulty", 0)))
end
-- Songs (0-based) that aren't level music: shop, title, ending, game over...
local NOT_LEVEL_SONG = {
	[2] = true, [5] = true, [6] = true, [7] = true, [8] = true, [9] = true,
	[10] = true, [18] = true, [19] = true, [25] = true, [29] = true, [33] = true,
}
-- Events kept as no-ops in the boss section; the rest of NOOP_EVENTS run
-- there (the boss's own loop, its "jump when the boss is gone", level end).
local BOSS_NOOP = { [4] = true, [44] = true, [67] = true, [71] = true, [77] = true, [81] = true }

-- Parses a duration: "300", "90s", "5m", "4:30".  Seconds, or nil.
function LevelGen.parseDuration(text)
	text = text and text:lower() or ""
	local m, sec = text:match("^(%d+):(%d%d)$")
	if m then return tonumber(m) * 60 + tonumber(sec) end
	local n, unit = text:match("^(%d+%.?%d*)([ms]?)$")
	if not n then return nil end
	return tonumber(n) * (unit == "m" and 60 or 1)
end

-- Sets up the game globals for a test level on the theme called `name`
-- (a random one when nil), endless or lasting `seconds`.  Returns false
-- (with a message) when it can't.
function LevelGen.beginTest(name, seed, seconds)
	if not ns.levgen then
		ns.Print("Level generator data missing (Data/levgen.lua).")
		return false
	end
	seed = seed or (time and time() or os.time())
	local rnd = newRng(seed)
	local theme
	if name then
		theme = LevelGen.themeIndex(name)
		if not theme then
			ns.Print("Unknown theme '" .. tostring(name) .. "'. Themes: " .. LevelGen.themeNames())
			return false
		end
	else
		theme = 1 + rnd(#ns.levgen.themes)
	end
	local th = ns.levgen.themes[theme]
	local key = th.key
	-- the enemy waves come from one of the theme's own levels
	local list = {}
	for _, i in ipairs(th.src) do
		if dataFileExists(ns.levgen.src[i].file) then list[#list + 1] = i end
	end
	if #list == 0 then
		ns.Print("The " .. th.name .. " theme's episode data is not installed.")
		return false
	end
	local src = ns.levgen.src[list[1 + rnd(#list)]]

	JE_initEpisode(src.ep)
	lvlFileNum = src.num
	levelName = "GENERATED"
	levelSong = src.song
	mainLevel, nextLevel = 1, 1
	bonusLevelCurrent, normalBonusLevelCurrent = false, false
	twoPlayerMode, onePlayerAction, superTyrian = false, false, false
	difficultyLevel = DIFFICULTY_NORMAL
	initialDifficulty = DIFFICULTY_NORMAL

	genLevel = { key = key, theme = theme, name = th.name, seed = seed, src = src }
	if seconds then
		seconds = math.max(seconds, MIN_SECONDS)
		local g = genLevel
		g.seconds, g.clock = seconds, 0
		g.rnd = newRng(seed + 7)
		-- arcade play, scaled by the power factor
		local f = (LONG_SECONDS - seconds) / (LONG_SECONDS - MIN_SECONDS)
		f = math.max(0, math.min(1, f))
		local fixed = opt("genPower", -1)
		if fixed >= 0 then f = fixed / 100 end
		g.power = f
		g.drops = 0
		onePlayerAction = true
		-- the "no cheats in flight mode" option swaps in an empty cheat
		-- table until LevelGen.endTest
		local saved = ns.options and ns.options.cheats or cheats
		if opt("noFlightCheats", false) then cheats = {} end
		local front = player[0].items.weapon[FRONT_WEAPON]
		front.power = START_POWER + floor(f * START_POWER_ADD + 0.5)
		if cheats.lives and cheats.lives > 0 then front.power = math.min(11, cheats.lives + 1) end
		g.startPower = front.power
		g.savedCheats = saved
		-- any level song
		if opt("randomMusic", true) then
			local songs = {}
			for i = 0, MUSIC_NUM - 1 do
				if not NOT_LEVEL_SONG[i] then songs[#songs + 1] = i end
			end
			levelSong = songs[1 + g.rnd(#songs)] + 1
		end
	end
	ns.Print(sprintf("Generated level: %s theme, seed %d, enemies from %s (episode %d)%s.",
		th.name, seed, src.name, src.ep, seconds and sprintf(", %s long, power %d%%, %d lives",
			LevelGen.clockText(seconds), floor(genLevel.power * 100 + 0.5), genLevel.startPower - 1) or ""))
	return true
end

-- "m:ss"
function LevelGen.clockText(t)
	t = math.floor(t + 0.5)
	return sprintf("%d:%02d", math.floor(t / 60), t % 60)
end

function LevelGen.endTest()
	local g = genLevel
	if g and g.seconds and g.clock > 0 then
		ns.Print(sprintf("Timed level: planned %s, played %s (boss from %s%s).",
			LevelGen.clockText(g.seconds), LevelGen.clockText(g.clock),
			g.bossOn and LevelGen.clockText(g.bossClock) or "-",
			g.bossKilledAt and ", destroyed at " .. LevelGen.clockText(g.bossKilledAt) or ""))
		ns.Print(sprintf("Power %d%%: started at front power %d, %d drops.",
			floor(g.power * 100 + 0.5), g.startPower, g.drops))
	end
	if g and g.seconds then onePlayerAction = false end
	if g and g.savedCheats then cheats = g.savedCheats end
	genLevel = nil
end

-- Clears a generated level that was cut short (the game restarted in the
-- middle of it), so the next game starts clean.
function LevelGen.abort()
	if genLevel then LevelGen.endTest() end
	bonusRun = nil
	bonusLevelCurrent = false
end

-- Secret and bonus levels of the original episodes, one of which is offered
-- after a timed level finished with flight time to spare:
-- { episode, level number in tyrianN.lvl, song, name }.
local BONUS_LEVELS = {
	{ 1, 4, 26, "BUBBLES" }, { 1, 3, 2, "ASTEROID?" }, { 1, 6, 23, "MINEMAZE" },
	{ 1, 10, 18, "BONUS" }, { 1, 11, 24, "HOLES" }, { 1, 14, 26, "WINDY" },
	{ 2, 3, 28, "BONUS" }, { 2, 7, 24, "GEM WAR" }, { 2, 8, 2, "MARKERS" },
	{ 2, 9, 17, "MISTAKES" }, { 2, 12, 28, "BONUS" },
	{ 3, 5, 28, "BONUS" }, { 3, 12, 7, "MACES" },
	{ 4, 11, 6, "?TUNNEL?" }, { 4, 2, 1, "WINDY II" }, { 4, 10, 2, "DESERTRUN" },
	{ 4, 20, 35, "ICESECRET" },
}
-- flight seconds needed for a bonus level (option, default 60)
local function bonusMin() return opt("bonusMin", 60) end
-- a level ends this long before the landing (option, default 10)
local function landMargin() return opt("flightMargin", 10) end
LevelGen.landMargin = landMargin

-- The bonus level for timed level `g`, or nil when it wasn't finished or
-- there isn't enough flight left.
local function bonusFor(g)
	if not (g and g.seconds and g.bossOn and endLevel and not playerEndLevel) then return end
	if not opt("genBonus", true) or all_players_dead() then return end
	local left = ns.Flight and ns.Flight.remaining()
	if not left or left - landMargin() < bonusMin() then return end
	local list = {}
	for _, b in ipairs(BONUS_LEVELS) do
		if dataFileExists(sprintf("tyrian%d.lvl", b[1])) then list[#list + 1] = b end
	end
	if #list == 0 then return end
	return list[1 + newRng(g.seed + 13)(#list)], left
end

-- True on Fire or Enter, false on Esc.
local function fireOrEsc()
	keyboardClearInput()
	while true do
		local k = keyboardGetInput()
		if k then return k.scancode ~= SDL_SCANCODE_ESCAPE end
		if mouseGetInput(INPUT_NO_MOTION) then return true end
		ns.yieldFrame()
	end
end

-- After timed level `g`: offers a bonus level when it was finished with
-- flight time to spare, and on Fire sets it up to play (bonusRun) with the
-- ship as it is.  Returns true when the caller should run JE_main.
function LevelGen.offerBonus(g)
	local b, left = bonusFor(g)
	if not b then return false end
	g.bonusOffered = sprintf("%s ep %d", b[4], b[1])
	if opt("scoreCardMusic", true) then play_song(26) end
	JE_clr256(VGAScreen)
	copyPalette(colors, palettes[6 - 1])
	local lines = {
		{ "BONUS LEVEL", 60 },
		{ b[4], 80 },
		{ sprintf("%s of flight left", LevelGen.clockText(left)), 110 },
		{ "Fire to play, Esc to skip", 130 },
	}
	for _, l in ipairs(lines) do
		JE_dString(VGAScreen, JE_fontCenter(l[1], SMALL_FONT_SHAPES), l[2], l[1], SMALL_FONT_SHAPES)
	end
	JE_showVGA()
	fade_palette(colors, 15, 0, 255)
	local yes = fireOrEsc()
	fade_black(15)
	if not yes then return false end

	JE_initEpisode(b[1])
	lvlFileNum = b[2]
	levelSong = b[3]
	levelName = b[4]
	mainLevel, nextLevel = 1, 1
	bonusLevelCurrent, normalBonusLevelCurrent = true, false
	difficultyLevel = DIFFICULTY_NORMAL
	bonusRun = { name = b[4] }
	ns.Print(sprintf("Bonus level: %s (episode %d).", b[4], b[1]))
	return true
end

-- Stats of the level JE_main just played: kill percentage, score so far and
-- whether the ship was lost.
function LevelGen.levelStats()
	return {
		kills = (totalEnemy == 0) and 0 or idiv(enemyKilled * 100, totalEnemy),
		cash = player[0].cash,
		dead = all_players_dead(),
	}
end

-- The score card after a generated level (and its bonus level, if played):
-- `run` is the LevelGen.levelStats of the level, `bonus` of the bonus level,
-- `flight` the flight it was played on (it may have landed since).  Waits for
-- Fire or Esc, then leaves a black screen.
function LevelGen.scoreCard(g, run, bonus, flight)
	local lines = {}
	local function row(label, value) lines[#lines + 1] = { label, value } end
	local dead = run.dead or (bonus and bonus.dead)
	local title = dead and "SHIP LOST" or (flight and "FLIGHT COMPLETE" or "RUN COMPLETE")
	if flight and flight.dest then row("Destination", flight.dest) end
	row("Level", sprintf("%s %d", g.name:upper(), g.seed))
	if g.seconds then
		row("Time", sprintf("%s of %s", LevelGen.clockText(g.clock), LevelGen.clockText(g.seconds)))
		row("Boss", g.bossKilledAt and "destroyed at " .. LevelGen.clockText(g.bossKilledAt)
			or (g.bossOn and "escaped" or "not reached"))
		row("Drops", tostring(g.drops))
	end
	row("Enemies killed", sprintf("%d%%", run.kills))
	if bonus then
		row("Bonus level", g.bonusOffered)
		row("Bonus killed", sprintf("%d%%", bonus.kills))
		row("Bonus score", tostring(bonus.cash - run.cash))
	elseif g.bonusOffered then
		row("Bonus level", "skipped")
	end
	row("Score", tostring((bonus or run).cash))
	if g.best then row("", "NEW BEST " .. g.name:upper()) end

	if opt("scoreCardMusic", true) then play_song(26) end
	JE_clr256(VGAScreen)
	copyPalette(colors, palettes[6 - 1])
	local font = SMALL_FONT_SHAPES
	JE_dString(VGAScreen, JE_fontCenter(title, font), 14, title, font)
	local y = 44
	for _, l in ipairs(lines) do
		JE_dString(VGAScreen, 30, y, l[1], font)
		JE_dString(VGAScreen, 290 - JE_textWidth(l[2], font), y, l[2], font)
		y = y + 13
	end
	local hint = opt("keepOpen", false) and "Fire or Esc to continue" or "Fire or Esc to close"
	JE_dString(VGAScreen, JE_fontCenter(hint, font), 182, hint, font)
	JE_showVGA()
	fade_palette(colors, 15, 0, 255)
	fireOrEsc()
	LevelGen.blankScreen()
end

-- Fades to black and presents a blank frame while the window is still
-- shown, so the next Show doesn't flash this run's last picture.
function LevelGen.blankScreen()
	fade_black(15)
	stop_song()
	JE_clr256(VGAScreen)
	JE_showVGA()
	ns.present(VGAScreen)
end

-- Records a finished generated level in the saved statistics: the last
-- RUNS_KEPT runs, the best score per theme and lifetime totals.  Sets
-- g.best when the run beat the theme's best score.
local RUNS_KEPT = 20
function LevelGen.recordRun(g, run, bonus, flight)
	local db = ns.db
	if not db then return end
	local st = db.stats or {}
	db.stats = st
	st.runs = st.runs or {}
	st.best = st.best or {}
	st.totals = st.totals or {}
	local score = (bonus or run).cash
	local r = {
		date = date and date("%Y-%m-%d %H:%M") or nil,
		theme = g.name, seed = g.seed,
		seconds = g.seconds, clock = g.seconds and floor(g.clock + 0.5),
		boss = g.bossKilledAt and true or false,
		kills = run.kills, drops = g.drops, score = score,
		dead = (run.dead or (bonus and bonus.dead)) and true or false,
		bonus = bonus and g.bonusOffered or nil,
		dest = flight and flight.dest or nil,
	}
	table.insert(st.runs, 1, r)
	while #st.runs > RUNS_KEPT do table.remove(st.runs) end
	local best = st.best[g.name]
	if not best or score > best.score then
		g.best = best ~= nil and score > 0
		st.best[g.name] = { score = score, kills = run.kills, date = r.date, seed = g.seed }
	end
	local t = st.totals
	t.runs = (t.runs or 0) + 1
	if flight then t.flights = (t.flights or 0) + 1 end
	if g.clock then t.seconds = (t.seconds or 0) + floor(g.clock + 0.5) end
	if r.boss then t.bosses = (t.bosses or 0) + 1 end
	if r.dead then t.lost = (t.lost or 0) + 1 end
	if bonus then t.bonus = (t.bonus or 0) + 1 end
	t.drops = (t.drops or 0) + (g.drops or 0)
	t.score = (t.score or 0) + score
end

-- Once per game frame of a bonus level: ends it before the landing.
function LevelGen.bonusFrame()
	local left = ns.Flight and ns.Flight.remaining()
	if (not left or left <= landMargin()) and not endLevel then
		endLevel, readyToEndLevel, levelEnd = true, false, 40
	end
end

-- Called at the end of JE_loadMap: swap in generated maps and tame events.
function LevelGen.loadMap()
	local g = genLevel
	local key = g.key
	local tileset = ns.gfxmeta.tiles[key]
	local refs = { [0] = false }
	for i = 1, 600 do refs[i] = mapTileRef(tileset, key, i - 1) end

	g.layers = {}
	local dims = { { 14, 300, megaData1 }, { 14, 600, megaData2 }, { 15, 600, megaData3 } }
	for k = 1, 3 do
		local w, rows = dims[k][1], dims[k][2]
		local L = {
			st = LevelGen.newStream(g.theme, k, g.seed * 3 + k),
			mm = dims[k][3].mainmap, w = w, rows = rows,
			period = rows - 2 * MARGIN, gen = rows, buf = {}, refs = refs, ids = {},
		}
		g.layers[k] = L
	end

	-- events
	g.loopAt, g.lastWave = nil, 0
	local bossAt = g.seconds and LevelGen.bossStart() or maxEvent
	g.bossAt = bossAt < maxEvent and bossAt or nil
	for i = 0, maxEvent - 1 do
		local ev = eventRec[i]
		local et = ev.eventtype
		if NOOP_EVENTS[et] and (i < bossAt or BOSS_NOOP[et]) then
			ev.eventtype = 0
		elseif et == 8 and ev.eventtime > 0 then
			-- stars off after the start: FLEET flickers them off for good
			-- at 646, which a looping level never gets past
			ev.eventtype = 0
		elseif et == 2 or et == 30 then
			-- Scroll speeds.  A stopped layer (a boss, or a stretch where
			-- the real map leaves that layer empty) would freeze generated
			-- art on screen, so every layer keeps moving.
			-- APPROACH's sea races at 16-20 pixels a frame, which looks
			-- wrong on endless generated water and costs a map row a frame.
			-- A timed level's boss section keeps its stops: the boss is
			-- scripted against the map standing still.
			if i < bossAt then
				if ev.eventdat <= 0 then ev.eventdat = 1 end
				if ev.eventdat2 <= 0 then ev.eventdat2 = 2 end
				if ev.eventdat3 <= 0 then ev.eventdat3 = 3 end
			end
			ev.eventdat = math.min(ev.eventdat, MAX_SCROLL)
			ev.eventdat2 = math.min(ev.eventdat2, MAX_SCROLL)
			ev.eventdat3 = math.min(ev.eventdat3, MAX_SCROLL)
		elseif ENEMY_EVENTS[ev.eventtype] and i < bossAt then
			g.loopAt = g.loopAt or i + 1
			g.lastWave = i + 1
		end
	end
	g.loopAt = g.loopAt or 1
	if g.seconds then LevelGen.planTimed() end
end

-- Index of the first event of the template's boss section (BOSS_INTRO before
-- its first boss bar), or maxEvent if it has no boss.
function LevelGen.bossStart()
	for i = 0, maxEvent - 1 do
		local ev = eventRec[i]
		if ev.eventtype == 79 and ev.eventdat ~= 0 then
			local t = ev.eventtime - BOSS_INTRO
			for j = 0, i do
				if eventRec[j].eventtime >= t then return j end
			end
		end
	end
	return maxEvent
end

-- How many ticks (curLoc counts ticks, whatever the scroll speed) the boss
-- section from event `at` takes when the boss survives, to the level end;
-- nil if it loops (jumps back) until the boss dies.
local function bossTicks(at)
	local t0 = eventRec[at].eventtime
	for i = at, maxEvent - 1 do
		local ev = eventRec[i]
		if ev.eventtype == 54 and ev.eventdat < ev.eventtime then return nil end
		if ev.eventtype == 11 then return ev.eventtime - t0 end
	end
end

-- Splits the waves into groups of spawns and holds the boss section back.
function LevelGen.planTimed()
	local g = genLevel
	g.bossClock = nil   -- set on the first tick, once the game speed is known
	g.bossTicks = g.bossAt and bossTicks(g.bossAt)
	-- the boss section waits, disabled, until its time
	if g.bossAt then
		g.bossTypes = {}
		for i = g.bossAt, maxEvent - 1 do
			g.bossTypes[i] = eventRec[i].eventtype
			eventRec[i].eventtype = 0
		end
	end
	local waves, cur, lastT = {}, nil, nil
	for i = g.loopAt - 1, g.lastWave - 1 do
		local ev = eventRec[i]
		if ENEMY_EVENTS[ev.eventtype] then
			if not cur or ev.eventtime - lastT > WAVE_GAP then
				cur = { t = ev.eventtime, events = {}, types = {} }
				waves[#waves + 1] = cur
			end
			cur.events[#cur.events + 1] = i
			cur.types[#cur.types + 1] = ev.eventtype
			lastT = ev.eventtime
		end
	end
	g.waves, g.nextWave = waves, 1
	g.wavesKept, g.wavesDropped = 0, 0
end

-- The ramp step for the share `p` of the wave time gone.
local function rampAt(p)
	local step = RAMP[1]
	for _, r in ipairs(RAMP) do
		if p >= r.at then step = r end
	end
	return step
end

-- Keeps or drops the waves about to come, sets the difficulty, and brings
-- the boss on when its time comes.
local function timedFrame(g)
	local tick = tickSeconds()
	g.clock = g.clock + tick
	-- (at least 40% of the level is waves, even if that makes it overrun)
	if not g.bossClock then
		local boss = g.bossTicks and g.bossTicks * tick or BOSS_SECONDS
		g.bossClock = math.max(g.seconds - boss, g.seconds * 0.4)
	end
	if g.bossOn then
		if g.clock > g.seconds + OVERTIME and not endLevel then
			endLevel, readyToEndLevel, levelEnd = true, false, 40
		end
		-- the bar's link is cleared once no enemy of the boss is left
		local linked = boss_bar[0].link_num ~= 0 or boss_bar[1].link_num ~= 0
		if linked then
			g.bossSeen = true
		elseif g.bossSeen and not g.bossKilledAt then
			g.bossKilledAt = g.clock
		end
		return
	end
	local p = g.clock / g.bossClock
	local step = rampAt(p)
	difficultyLevel = difficulty(step.level + floor(g.power * RAMP_LEVEL_ADD + 0.5))
	local dens = density()
	local freq = step.freq + dens.freq
	if levelEnemyMax > 0 and levelEnemyFrequency > freq then
		levelEnemyFrequency = freq
	end
	local waves = g.waves
	local w = waves[g.nextWave]
	while w and w.t - curLoc <= PLAN_AHEAD do
		-- when it will spawn; none just before the boss
		local eta = g.clock + (w.t - curLoc) * tick
		local keep = eta < g.bossClock - QUIET and g.rnd(1000) < step.keep * dens.keep * 1000
		for k, i in ipairs(w.events) do
			eventRec[i].eventtype = keep and w.types[k] or 0
		end
		if keep then g.wavesKept = g.wavesKept + 1 else g.wavesDropped = g.wavesDropped + 1 end
		g.nextWave = g.nextWave + 1
		w = waves[g.nextWave]
	end
	if p < 1 then return end
	g.bossOn = true
	g.bossClock = g.clock
	difficultyLevel = difficulty(BOSS_LEVEL + floor(g.power * BOSS_LEVEL_ADD + 0.5))
	if not g.bossAt then
		-- no boss in the template: just end the level
		endLevel, readyToEndLevel, levelEnd = true, false, 40
		return
	end
	for i, et in pairs(g.bossTypes) do eventRec[i].eventtype = et end
	-- the scroll speeds the template has at its boss (the waves may have
	-- left others): the boss's moves are scripted against them, and TORM's
	-- drifts off the bottom of the screen if layer 3 runs faster
	for i = g.bossAt - 1, 0, -1 do
		local et = eventRec[i].eventtype
		if et == 2 or et == 30 then
			eventLoc = i + 1
			JE_eventSystem()
			break
		end
	end
	g.scenery = nil
	eventLoc = g.bossAt + 1
	curLoc = eventRec[g.bossAt].eventtime
end

-- Text and fill (0-1) for the progress strip in a timed level, or nil.
function LevelGen.barInfo()
	local g = genLevel
	if not g or not g.seconds or not g.bossClock then return nil end
	if g.bossOn then
		return g.bossKilledAt and "BOSS DESTROYED" or "BOSS", 1
	end
	local left = math.max(0, g.bossClock - g.clock)
	if left == 0 then return "BOSS INCOMING", 1 end
	return "Boss in " .. LevelGen.clockText(left), g.clock / g.bossClock
end

-- "BOSS" / "BOSS DESTROYED" once a timed level's boss is on, else nil.
function LevelGen.bossTag()
	local g = genLevel
	if not g or not g.bossOn or not g.bossAt then return nil end
	return g.bossKilledAt and "BOSS DESTROYED" or "BOSS"
end

local function writeRow(L, r)
	local row = LevelGen.nextRow(L.st, L.buf)
	local mm, w, refs, ids = L.mm, L.w, L.refs, L.ids
	local base = r * w - 1
	for c = 1, w do mm[base + c] = refs[row[c]] or false; ids[base + c] = row[c] end
	if r + L.period < L.rows then
		base = base + L.period * w
		for c = 1, w do mm[base + c] = refs[row[c]] or false; ids[base + c] = row[c] end
	end
end

-- Generates rows up to just above the view, wrapping the view when it nears
-- the top of the ring.  Returns the (possibly moved) map position.
local function service(L, pos)
	local w = L.w
	if pos <= WRAP_ROW * w - 1 then
		pos = pos + L.period * w
		L.gen = L.gen + L.period
	end
	local top = floor((pos + 1) / w) - 2
	while L.gen > top - LOOK do
		L.gen = L.gen - 1
		writeRow(L, L.gen)
	end
	return pos
end

-- Whether enemy `e`'s sprite is solid (85% or more opaque): a building, pad
-- or gun emplacement that brings its own patch of ground or rock, unlike a
-- tank or walker, which looks right anywhere.
local SOLID = 0.85
-- How opaque a sprite is, 0-9 (tenths), or nil if unknown.
local function spriteFill(sheet, i, size)
	local fill = sheet and sheet.key and ns.levgen.fill[sheet.key]
	if not fill or not i or i < 1 then return nil end
	local cells = size == 1 and { i, i + 1, i + 19, i + 20 } or { i }
	local sum = 0
	for _, c in ipairs(cells) do sum = sum + (strbyte(fill, c) or 48) - 48 end
	return sum / #cells
end

local function solidSprite(sheet, i, size)
	local f = spriteFill(sheet, i, size)
	return f ~= nil and f >= SOLID * 10 - 0.5
end

function LevelGen.solid(e)
	return solidSprite(e.sprite2s, e.egr[0], e.size)
end

-- The sprite sheet of shape bank `bank` (as JE_makeEnemy picks it).
local function sheetOf(bank)
	if bank == 21 then return spriteSheet11 end
	if bank == 26 then return spriteSheet10 end
	for i = 0, 3 do
		if bank == enemySpriteSheetIds[i] then return enemySpriteSheets[i] end
	end
end

-- Arcade drops.  The item enemies (enemyDat) of each kind whose sprites
-- this level has loaded, built once per level.
local DROP_KINDS = {
	{ name = "power", weight = 3, weightAdd = 4, test = function(v) return v == -1 end },
	{ name = "purple", weight = 3, weightAdd = 0, test = function(v) return v == 30000 end },
	{ name = "armor", weight = 2, weightAdd = 0, test = function(v) return v > 20000 and v < 20100 end },
	{ name = "bomb", weight = 1, weightAdd = 1, test = function(v) return v == -4 end },
}

local function dropTable(g)
	if g.dropKinds then return g.dropKinds end
	local kinds = {}
	for _, k in ipairs(DROP_KINDS) do
		local ids = {}
		for id = 1, 850 do
			local ed = enemyDat[id]
			if ed and k.test(ed.value) and ed.egraphic and (ed.egraphic[0] or 0) > 0 and sheetOf(ed.shapebank) then
				ids[#ids + 1] = id
			end
		end
		if #ids > 0 then
			kinds[#kinds + 1] = { name = k.name, ids = ids, weight = k.weight + k.weightAdd * g.power }
		end
	end
	g.dropKinds = kinds
	return kinds
end

-- Called as enemy e2 dies in a timed level: maybe make it drop an item
-- (by giving it one to leave behind, as enemydie does for the game's own).
function LevelGen.maybeDrop(e2)
	local g = genLevel
	if not g or not g.seconds or e2.enemydie ~= 0 or e2.scoreitem then return end
	if g.rnd(1000) >= (DROP_CHANCE + DROP_CHANCE_ADD * g.power) * opt("genDrops", 1) * 1000 then return end
	local kinds = dropTable(g)
	local total = 0
	for _, k in ipairs(kinds) do total = total + k.weight end
	if total <= 0 then return end
	local r = g.rnd(1000) / 1000 * total
	for _, k in ipairs(kinds) do
		r = r - k.weight
		if r < 0 then
			e2.enemydie = k.ids[1 + g.rnd(#k.ids)]
			g.drops = g.drops + 1
			g.dropCount = g.dropCount or {}
			g.dropCount[k.name] = (g.dropCount[k.name] or 0) + 1
			return
		end
	end
end

-- The opacity (spriteFill) of the (first) enemy event `ev` will make,
-- before it exists.
local function eventFill(ev)
	local et = ev.eventtype
	if et >= 49 and et <= 52 then
		-- custom enemies: graphic and shape bank come from the event
		return spriteFill(sheetOf(ev.eventdat3), ev.eventdat, enemyDat[0].esize)
	end
	local ed = enemyDat[ev.eventdat]
	if not ed then return nil end
	return spriteFill(sheetOf(ed.shapebank), ed.egraphic[0], ed.esize)
end

-- LevelGen.solid for the enemy event `ev` will make.
local function eventSolid(ev)
	local f = eventFill(ev)
	return f ~= nil and f >= SOLID * 10 - 0.5
end

-- Whether event `ev` makes an invisible enemy: FLEET's guns on its capital
-- ships are drawn in the map and are invisible enemies on top of it.
local function eventInvisible(ev)
	return eventFill(ev) == 0
end

--[[ Scenery enemies.  Some ground enemies are scenery more than foes:
 TYRIAN's turrets carry their own patch of dirt, and DESERTRUN's rock arches
 are a dozen enemies spawned side by side.  On generated ground they must
 stand on ground that looks like the ground they had in the template level,
 and an assembly is kept or dropped as a whole.

 A group is the ground enemies an event time spawns whose sprites touch.  It
 only counts as scenery when one of its sprites is solid.  Groups with an
 invisible enemy (a gun hidden in the map's art) are always dropped.  The ground is
 compared tile by tile, by mean colour (build.py), over the map rows and
 columns the group covers when it appears.
]]
local GROUND_EVENTS = {
	[6] = 25, [7] = 50, [10] = 75, [17] = 25, [23] = 50, [32] = 50,
	[49] = 25, [51] = 50, [52] = 75, [56] = 75,
}
local EVENT12_OFS = { [0] = 25, [1] = 25, [3] = 50, [4] = 75 }

local COLOUR_NEAR = 4.5  -- colour distance (0-63 per channel) that still matches
local HUE_WEIGHT = 4     -- how much more hue counts than brightness
local MATCH = 0.7        -- share of tiles under a group that must match

local function groundOfs(ev)
	if ev.eventtype == 12 then return EVENT12_OFS[ev.eventdat6] end
	return GROUND_EVENTS[ev.eventtype]
end

-- Where an event's enemy appears (24x28, top left): x in map pixels (map
-- column floor(x / 24); the map's column 2 is at the screen's left edge before
-- any sideways scroll), y in screen pixels from the top of the view.
local function evRect(ev)
	return ev.eventdat2 - 12 - (mapX - 1) * 24 + 48, -28 + ev.eventdat5
end

-- Event indexes (into eventRec) of the group event `i` belongs to.
local function groupOf(i)
	local t = eventRec[i].eventtime
	local lo, hi = i, i
	while lo > 0 and eventRec[lo - 1].eventtime == t do lo = lo - 1 end
	while hi < maxEvent - 1 and eventRec[hi + 1].eventtime == t do hi = hi + 1 end
	local group, todo, inGroup = { i }, { i }, { [i] = true }
	while #todo > 0 do
		local x0, y0 = evRect(eventRec[table.remove(todo)])
		for j = lo, hi do
			local ev = eventRec[j]
			if not inGroup[j] and groundOfs(ev) and ev.eventdat2 ~= -99 then
				local x1, y1 = evRect(ev)
				if math.abs(x1 - x0) <= 26 and math.abs(y1 - y0) <= 30 then
					inGroup[j] = true
					group[#group + 1] = j
					todo[#todo + 1] = j
				end
			end
		end
	end
	return group
end

-- Whether tiles a and b look alike: mostly by hue (sand vs grey metal, dirt
-- vs grass), as the template's ground under scenery is often its own darker
-- shadow tiles.
local function colourNear(col, a, b, hueWeight)
	if a == b then return true end
	if a == 0 or b == 0 then return false end
	local ra, ga, ba = strbyte(col, a * 3 - 2, a * 3)
	local rb, gb, bb = strbyte(col, b * 3 - 2, b * 3)
	if not ra or not rb then return true end
	local ma, mb = (ra + ga + ba) / 3, (rb + gb + bb) / 3
	local dr, dg, db = (ra - ma) - (rb - mb), (ga - ma) - (gb - mb), (ba - ma) - (bb - mb)
	local dm = (ma - mb) / (hueWeight or HUE_WEIGHT)
	return dr * dr + dg * dg + db * db + dm * dm <= COLOUR_NEAR * COLOUR_NEAR
end

-- The template's most common layer 1 tile: its open ground (sand, grass,
-- or space between ASTEROID's rocks).
local function plainTile(g, data, off, lut)
	if not g.plain then
		local count, best = {}, 0
		for k = 0, 300 * 14 - 1 do
			local t = lut[strbyte(data, off + k + 1) + 1] or 0
			count[t] = (count[t] or 0) + 1
			if count[t] > (count[g.plain] or 0) then g.plain = t end
		end
	end
	return g.plain
end

-- Whether the layer 1 ground under the events in `group` looks the way it
-- did in the template level, if they spawn when the template had scrolled
-- `loc` pixels with generated map row `now0` at the top of the view, and the
-- tiles to stamp there ({row, column, tile}).  Stamping only paints over
-- open ground, never over rock or buildings the generator made, and never
-- over rows on screen now (`top` is the top visible row's index + 1).
-- Returns "wait" while rows it needs are not generated yet.
local function groundMatches(group, loc, now0, top)
	local g = genLevel
	local L = g.layers and g.layers[1]
	local col = ns.levgen.col[g.key]
	if not L or not col then return true, {} end
	local src = g.src
	local data, off, lut = ns.files[src.file], src.off[1], src.lut[1]
	local plain = plainTile(g, data, off, lut)
	-- the template's map has moved loc pixels since the start (300 - 8 is
	-- its starting mapY)
	local was0 = 292 - floor(loc / 28)
	local function tmpl(r, c)
		local wr = math.max(0, math.min(was0 + r, 299))
		return lut[strbyte(data, off + wr * 14 + c + 1) + 1] or 0
	end
	-- whether the generated tile at map row `row` may be replaced
	local function paintable(row, t)
		return row < top - 1 and colourNear(col, t, plain)
	end
	local seen, n, good, cells, clash = {}, 0, 0, {}, false
	for _, i in ipairs(group) do
		local x, y = evRect(eventRec[i])
		for r = floor(y / 28), floor((y + 27) / 28) do
			for c = floor(x / 24), floor((x + 23) / 24) do
				local k = r * 16 + c
				if c >= 0 and c < 14 and not seen[k] then
					seen[k] = true
					local row = now0 + r
					if row < L.gen then return "wait" end
					local was = tmpl(r, c)
					local now = L.ids[row * 14 + c]
					if now then
						n = n + 1
						if colourNear(col, was, now) then good = good + 1 end
						if now ~= was then
							if not paintable(row, now) then clash = true end
							cells[#cells + 1] = { row, c, was }
						end
					end
				end
			end
		end
	end
	if clash then return false, {} end
	-- the feet and shadows reach a tile past the sprites: take the
	-- template's tiles around them too, where it has more than plain ground
	-- and the generated map has only plain ground
	local core = {}
	for k in pairs(seen) do core[#core + 1] = k end
	for _, k in ipairs(core) do
		local r0, c0 = floor(k / 16), k % 16
		for r = r0 - 1, r0 + 1 do
			for c = c0 - 1, c0 + 1 do
				local kk = r * 16 + c
				if c >= 0 and c < 14 and not seen[kk] then
					seen[kk] = true
					local row = now0 + r
					if row < L.gen then return "wait" end
					local was = tmpl(r, c)
					local now = L.ids[row * 14 + c]
					if was ~= plain and now and now ~= was and paintable(row, now) then
						cells[#cells + 1] = { row, c, was }
					end
				end
			end
		end
	end
	return n == 0 or good >= n * MATCH, cells
end

-- Puts the template's layer 1 tiles back under a kept group: DESERTRUN's
-- arches have their feet and shadows in the map, not in the enemies.  The
-- rows are still above the view (groundMatches).
local function stamp(cells)
	local L = genLevel.layers[1]
	local w = L.w
	for _, cell in ipairs(cells) do
		local r, c, t = cell[1], cell[2], cell[3]
		repeat
			local k = r * w + c
			L.ids[k] = t
			L.mm[k] = L.refs[t] or false
			r = r + L.period
		until r >= L.rows
	end
end

-- Decides whether the scenery group of ground event eventRec[i] stays, for
-- it spawning at template scroll `loc` with map row `now0` at the top of the
-- view, and stamps its ground.  Returns false if it has to wait for rows.
local function decide(i, loc, now0, top)
	local g = genLevel
	local group = groupOf(i)
	local ok, cells, solid, invisible = nil, nil, false, false
	for _, j in ipairs(group) do
		if eventSolid(eventRec[j]) then solid = true end
		if eventInvisible(eventRec[j]) then invisible = true end
	end
	if invisible then
		-- guns hidden in map art (FLEET's capital ships): the generated
		-- map almost never has that art in the right place, and comparing
		-- colours can't tell (they turned up firing from open space)
		ok = false
	elseif not solid then
		-- a tank, or a flier or walker made of pieces (TORM's airships and
		-- spiders): fine anywhere
		ok = true
	else
		ok, cells = groundMatches(group, loc, now0, top)
		if ok == "wait" then return false end
		if ok then stamp(cells) end
	end
	for _, j in ipairs(group) do g.scenery[j] = ok end
	return true
end

-- How far ahead (in curLoc) scenery is decided.  Its ground is stamped
-- while those rows are still above the view, so nothing changes on screen.
local AHEAD = 28 * 8

-- Decides the ground events about to fire.  Layer 1 scrolls with curLoc
-- (both step by backMove each frame), so the map row an event will appear at
-- is known ahead.
local function lookAhead()
	local g = genLevel
	g.scenery = g.scenery or {}
	if backMove <= 0 then return end
	local top = floor((mapYPos + 1) / 14)
	for j = eventLoc - 1, maxEvent - 1 do
		local ev = eventRec[j]
		local d = ev.eventtime - curLoc
		if d > AHEAD then break end
		local ofs = groundOfs(ev)
		-- (layer 3 enemies move with layer 3, so only the ground layers)
		if d >= 0 and g.scenery[j] == nil and (ofs == 25 or ofs == 75) and ev.eventdat2 ~= -99
			and not (g.bossAt and j >= g.bossAt) then
			-- events run before this frame's scroll, so it fires after
			-- `steps` more scroll steps
			local steps = math.ceil(d / backMove)
			local moved = steps * backMove
			decide(j, curLoc + moved, top - floor((backPos + moved) / 28), top)
		end
	end
end

-- Whether ground or layer 3 enemy `e`, just made by event eventRec[i] on
-- enemy layer `ofs` (25, 50 or 75), may stay.
function LevelGen.sceneryOk(i, e, ofs)
	local g = genLevel
	-- the boss is always kept, whatever its parts look like
	if g.bossAt and i >= g.bossAt then return true end
	local theme = ns.levgen.themes[g.theme]
	-- an invisible enemy is a gun hidden in the template's map art (decide)
	if spriteFill(e.sprite2s, e.egr[0], e.size) == 0 then return false end
	if ofs == 50 then
		-- turrets on rock need rock under them, whatever the ground; without
		-- layer 3 art these are fliers (TORM's spider walkers)
		return not theme.l3art or not LevelGen.solid(e) or LevelGen.overlayOk(e)
	end
	if eventRec[i].eventdat2 == -99 then return true end
	g.scenery = g.scenery or {}
	if g.scenery[i] == nil then
		-- not decided ahead (the scroll speed changed, say): too late to
		-- stamp anything on screen
		local top = floor((mapYPos + 1) / 14)
		if not decide(i, curLoc, top, top) then g.scenery[i] = false end
	end
	return g.scenery[i]
end

-- Whether layer 3 enemy `e` has layer 3 art under it.  These enemies (the
-- turrets on TYRIAN's rocks, say) are drawn as part of the rock they sit on,
-- so on open ground they float on a square of their own.
function LevelGen.overlayOk(e)
	local L = genLevel.layers and genLevel.layers[3]
	if not L then return true end
	local ofs = (not background3x1) and oldMapX3Ofs or mapXOfs
	local sx, sy = e.ex + ofs + 12, e.ey + 14   -- centre on screen
	local seen = false
	for dy = -7, 7, 14 do
		for dx = -6, 6, 12 do
			local i = floor((sy + dy - backPos3) / 28)
			local ti = floor((sx + dx - mapX3Pos) / 24)
			if ti >= 0 and ti < 15 then
				local t = L.ids[mapY3Pos + mapX3bpPos - 12 + (i + 1) * 15 + ti]
				if t == nil then return true end   -- not generated yet
				if t ~= 0 then seen = true end
			end
		end
	end
	return seen
end

-- Once per game frame, before the engine's own wrap checks.
function LevelGen.frame()
	local g = genLevel
	local Ls = g.layers
	if not Ls then return end
	mapYPos = service(Ls[1], mapYPos)
	mapY2Pos = service(Ls[2], mapY2Pos)
	mapY3Pos = service(Ls[3], mapY3Pos)
	if g.seconds then
		timedFrame(g)
		if g.bossOn then
			lookAhead()
			return
		end
	end
	lookAhead()
	-- past the last wave: run the waves again once the screen is clear, or
	-- after a while if something (a turret, a boss) never leaves
	if eventLoc > g.lastWave then
		g.pastAt = g.pastAt or curLoc
		if enemyOnScreen == 0 or curLoc - g.pastAt > 400 then
			eventLoc = g.loopAt
			g.scenery = nil
			curLoc = eventRec[g.loopAt - 1].eventtime
			g.pastAt = nil
			g.nextWave = 1
		end
	end
end
