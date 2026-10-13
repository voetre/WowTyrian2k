--[[
 WowTyrian2k: a World of Warcraft port of OpenTyrian
 Lua port Copyright (C) 2026 voetre
 Licensed under the GNU General Public License v2 or later (see COPYING).

 Render state dumps (new for this port), for reporting drawing problems.
 F12 in game or /tyrian dump captures the level, the scroll positions, the
 layer draw order and every live enemy (where it is, which layer it draws on,
 its sprite and the level event that spawned it), shows it in a window to
 copy from, and keeps the last DUMPS_KEPT in the saved variables
 (WowTyrian2kDB.dumps, written to disk on /reload or logout).
]]
local _, ns = ...
setfenv(1, ns.G)

local _G = _G_REAL
local format, floor, concat = string.format, math.floor, table.concat

local DUMPS_KEPT = 10

-- Enemy slot blocks, in the order JE_drawEnemy draws them.
local BLOCKS = {
	{ first = 25, name = "ground" },    -- event enemies on offset 25
	{ first = 75, name = "ground2" },   -- offset 75
	{ first = 0, name = "sky" },        -- offset 0
	{ first = 50, name = "top" },       -- offset 50, moves with layer 3
}

local function blockOf(i)
	for _, b in ipairs(BLOCKS) do
		if i >= b.first and i < b.first + 25 then return b.name end
	end
end

-- Draw order of one frame, back to front (JE_main in Game/Tyrian2a.lua).
local function drawOrder()
	local o = { "layer1" }
	if background2over == 3 then o[#o + 1] = "layer2" end
	if background2over == 0 then o[#o + 1] = "layer2" end
	o[#o + 1] = "ground"
	o[#o + 1] = "ground2"
	if background2over == 1 then o[#o + 1] = "layer2" end
	if background3over == 2 then o[#o + 1] = "layer3" end
	if not skyEnemyOverAll then o[#o + 1] = "sky" end
	if background3over == 0 then o[#o + 1] = "layer3" end
	if not topEnemyOver then o[#o + 1] = "top" end
	o[#o + 1] = "shots/player"
	if background3over == 1 then o[#o + 1] = "layer3" end
	if topEnemyOver then o[#o + 1] = "top" end
	if skyEnemyOverAll then o[#o + 1] = "sky" end
	if background2over == 2 then o[#o + 1] = "layer2" end
	return concat(o, " < ")
end

local function str(v)
	if v == nil then return "nil" end
	return tostring(v)
end

-- Tile ids of the visible rows of generated layer k (top row first).
local function visibleTiles(out, k)
	local g = genLevel
	local L = g and g.layers and g.layers[k]
	if not L then return end
	local pos = ({ mapYPos, mapY2Pos, mapY3Pos })[k] or 0
	local w = L.w
	local top = floor((pos + 1) / w)
	out[#out + 1] = format("layer %d tiles (rows %d-%d, top first):", k, top - 1, top + 6)
	for r = top - 1, top + 6 do
		local row = {}
		for c = 0, w - 1 do row[#row + 1] = format("%4d", L.ids[r * w + c] or -1) end
		out[#out + 1] = "  " .. concat(row, "")
	end
end

function ns.debugDump()
	local out = {}
	local function add(...) out[#out + 1] = format(...) end
	add("WowTyrian2k dump %s", _G.date and _G.date("%Y-%m-%d %H:%M:%S") or "")
	local g = genLevel
	if g then
		local src = g.src or {}
		add("generated level: %s theme (tile set '%s') seed %s, enemies from %s (file %s, ep %s, level %s)",
			str(g.name), str(g.key), str(g.seed), str(src.name), str(src.file), str(src.ep), str(src.num))
		add("waves: loop restarts at event %s", str(g.loopAt))
		if g.seconds then
			add("timed: %s of %s, boss %s at %s (boss section from event %s), difficulty %s, waves kept %s dropped %s",
				LevelGen.clockText(g.clock), LevelGen.clockText(g.seconds), g.bossOn and "on" or "due",
				LevelGen.clockText(g.bossClock or 0), str(g.bossAt), str(difficultyLevel), str(g.wavesKept), str(g.wavesDropped))
			local dc = {}
			for k, n in pairs(g.dropCount or {}) do dc[#dc + 1] = k .. " " .. n end
			add("arcade: power %s%%, start front power %s, now %s, drops %s (%s), song %s, enemy frequency %s",
				str(floor((g.power or 0) * 100 + 0.5)), str(g.startPower),
				str(player and player[0] and player[0].items.weapon[FRONT_WEAPON].power),
				str(g.drops), concat(dc, ", "), str(levelSong), str(levelEnemyFrequency))
		end
	else
		add("level: %s (not generated)", str(levelName))
	end
	add("curLoc %s  eventLoc %s/%s  mapX %s", str(curLoc), str(eventLoc), str(maxEvent), str(mapX))
	add("mapYPos %s %s %s  backPos %s %s %s  mapXOfs %s %s %s",
		str(mapYPos), str(mapY2Pos), str(mapY3Pos), str(backPos), str(backPos2), str(backPos3),
		str(mapXOfs), str(mapX2Ofs), str(mapX3Ofs))
	add("backMove %s %s %s  background2over %s  background3over %s  background3x1 %s  background3x1b %s",
		str(backMove), str(backMove2), str(backMove3), str(background2over), str(background3over),
		str(background3x1), str(background3x1b))
	add("skyEnemyOverAll %s  topEnemyOver %s  background2notTransparent %s  wild %s  superWild %s",
		str(skyEnemyOverAll), str(topEnemyOver), str(background2notTransparent), str(wild), str(superWild))
	add("draw order (back to front): %s", drawOrder())
	add("enemies (slot block x y size sprite armor type event):")
	for _, b in ipairs(BLOCKS) do
		for i = b.first, b.first + 24 do
			local e = enemy and enemy[i]
			if e and enemyAvail[i] ~= 1 then
				local ev = e.srcEvent and eventRec[e.srcEvent]
				local evs = "random"
				if ev then
					evs = format("#%d t=%d type %d dat %d,%d,%d,%d,%d,%d", e.srcEvent, ev.eventtime, ev.eventtype,
						ev.eventdat, ev.eventdat2, ev.eventdat3, ev.eventdat4, ev.eventdat5, ev.eventdat6)
				end
				local sheet = e.sprite2s and e.sprite2s.key or "-"
				local gr = e.egr and e.egr[(e.enemycycle or 1) - 1] or -1
				add("  %2d %-7s x %4d y %4d size %s sprite %s/%d armor %s type %s  %s",
					i, blockOf(i), floor((e.ex or 0) + (e.mapoffset or 0)), floor(e.ey or 0), str(e.size),
					sheet, gr, str(e.armorleft), str(e.enemytype), evs)
			end
		end
	end
	for k = 1, 3 do visibleTiles(out, k) end
	local text = concat(out, "\n")

	local db = ns.db
	if db then
		db.dumps = db.dumps or {}
		table.insert(db.dumps, text)
		while #db.dumps > DUMPS_KEPT do table.remove(db.dumps, 1) end
	end
	ns.Print(format("Dump saved (%d kept; /reload writes them to disk). Ctrl+C copies the text.",
		db and #db.dumps or 0))
	ns.showDump(text)
end

-- A window with the dump selected, ready for Ctrl+C.
local win
function ns.showDump(text)
	if not win then
		win = _G.CreateFrame("Frame", "WowTyrian2kDumpFrame", _G.UIParent, "BackdropTemplate")
		win:SetSize(720, 420)
		win:SetPoint("CENTER")
		win:SetFrameStrata("FULLSCREEN_DIALOG")
		win:SetMovable(true)
		win:EnableMouse(true)
		win:RegisterForDrag("LeftButton")
		win:SetScript("OnDragStart", win.StartMoving)
		win:SetScript("OnDragStop", win.StopMovingOrSizing)
		win:SetBackdrop({
			bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 },
		})
		win:SetBackdropColor(0, 0, 0, 0.9)
		local title = win:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		title:SetPoint("TOPLEFT", 12, -10)
		title:SetText("WowTyrian2k dump: Ctrl+C to copy, Esc to close")
		local close = _G.CreateFrame("Button", nil, win, "UIPanelCloseButton")
		close:SetPoint("TOPRIGHT", -2, -2)
		local scroll = _G.CreateFrame("ScrollFrame", nil, win, "UIPanelScrollFrameTemplate")
		scroll:SetPoint("TOPLEFT", 12, -32)
		scroll:SetPoint("BOTTOMRIGHT", -32, 12)
		local edit = _G.CreateFrame("EditBox", nil, scroll)
		edit:SetMultiLine(true)
		edit:SetAutoFocus(false)
		edit:SetFontObject(_G.ChatFontNormal)
		edit:SetWidth(660)
		edit:SetScript("OnEscapePressed", function() win:Hide() end)
		scroll:SetScrollChild(edit)
		win.edit = edit
		win:SetScript("OnHide", function() edit:ClearFocus() end)
	end
	win.edit:SetText(text)
	win:Show()
	win.edit:SetFocus()
	win.edit:HighlightText()
end
