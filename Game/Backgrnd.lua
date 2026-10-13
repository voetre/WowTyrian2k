--[[
 WowTyrian2k: a World of Warcraft port of OpenTyrian
 Copyright (C) The OpenTyrian Development Team
 Lua port Copyright (C) 2026 voetre
 Licensed under the GNU General Public License v2 or later (see COPYING).

 backgrnd.c

 Map "pointers" are integer indexes into the flat 0-based mainmap arrays of
 megaData1/2/3; each map cell holds a tile reference {tileset, z} or false.
]]
local _, ns = ...
setfenv(1, ns.G)

backPos, backPos2, backPos3 = 0, 0, 0
backMove, backMove2, backMove3 = 0, 0, 0

mapX, mapY, mapX2, mapX3, mapY2, mapY3 = 0, 0, 0, 0, 0, 0
mapYPos, mapY2Pos, mapY3Pos = 0, 0, 0
mapXPos, oldMapXOfs, mapXOfs, mapX2Ofs, mapX2Pos, mapX3Pos, oldMapX3Ofs, mapX3Ofs, tempMapXOfs = 0, 0, 0, 0, 0, 0, 0, 0, 0
mapXbpPos, mapX2bpPos, mapX3bpPos = 0, 0, 0
map1YDelay, map1YDelayMax, map2YDelay, map2YDelayMax = 0, 0, 0, 0

anySmoothies = false
smoothie_data = newArray(9, 0)

-- The starfield is drawn underneath background 1 (it only shows through
-- the black/transparent parts of the tiles), so it lives in its own surface
-- that background 1 references with a group operation.
local starSurfaces = {}
local starSurface
local starTarget = nil

function JE_darkenBackground(neat_)
	-- "Super wild" detail only; approximated by a slight darkening.
	pushFilter(VGAScreen, 24, 0, 264, 184, -99, -2)
end

local push = ns.pushOp
local function blitRow(surface, x, y, mainmap, idx, mode)
	for ti = 0, 11 do
		local ref = mainmap[idx + ti]
		if ref then
			push(surface, K_TILE, ref[1], ref[2], x + ti * 24, y, mode, 184)
		end
	end
end

function draw_background_1(surface)
	-- Background 1 is opaque and covers the whole play area, so everything
	-- previously drawn on this surface is gone.
	surfaceClear(surface)
	ns.pushOp(surface, K_RECT, 0, 0, 320, 184, 0, 0)
	starSurface = starSurfaces[surface]
	if not starSurface then
		starSurface = ns.newSurface("stars", false)
		starSurfaces[surface] = starSurface
	end
	surfaceClear(starSurface)
	pushGroup(surface, starSurface)
	starTarget = surface

	local map = mapYPos + mapXbpPos - 12
	local mm = megaData1.mainmap
	for i = -1, 6 do
		blitRow(surface, mapXPos, i * 28 + backPos, mm, map, 0)
		map = map + 14
	end
end

function draw_background_2(surface)
	if map2YDelayMax > 1 and backMove2 < 2 then
		backMove2 = (map2YDelay == 1) and 1 or 0
	end

	if background2 then
		local xx = smoothies[1] and mapXPos or mapX2Pos
		local map = mapY2Pos + (smoothies[1] and mapXbpPos or mapX2bpPos) - 12
		local mm = megaData2.mainmap
		for i = -1, 6 do
			blitRow(surface, xx, i * 28 + backPos2, mm, map, 0)
			map = map + 14
		end
	end

	map2YDelay = u8(map2YDelay - 1)
	if map2YDelay == 0 then
		map2YDelay = map2YDelayMax
		backPos2 = backPos2 + backMove2
		if backPos2 > 27 then
			backPos2 = backPos2 - 28
			mapY2 = mapY2 - 1
			mapY2Pos = mapY2Pos - 14
		end
	end
end

function draw_background_2_blend(surface)
	if map2YDelayMax > 1 and backMove2 < 2 then
		backMove2 = (map2YDelay == 1) and 1 or 0
	end

	local map = mapY2Pos + mapX2bpPos - 12
	local mm = megaData2.mainmap
	for i = -1, 6 do
		blitRow(surface, mapX2Pos, i * 28 + backPos2, mm, map, 1)
		map = map + 14
	end

	map2YDelay = u8(map2YDelay - 1)
	if map2YDelay == 0 then
		map2YDelay = map2YDelayMax
		backPos2 = backPos2 + backMove2
		if backPos2 > 27 then
			backPos2 = backPos2 - 28
			mapY2 = mapY2 - 1
			mapY2Pos = mapY2Pos - 14
		end
	end
end

function draw_background_3(surface)
	backPos3 = backPos3 + backMove3
	if backPos3 > 27 then
		backPos3 = backPos3 - 28
		mapY3 = mapY3 - 1
		mapY3Pos = mapY3Pos - 15
	end

	local map = mapY3Pos + mapX3bpPos - 12
	local mm = megaData3.mainmap
	for i = -1, 6 do
		blitRow(surface, mapX3Pos, i * 28 + backPos3, mm, map, 0)
		map = map + 15
	end
end

function JE_filterScreen(col, brightness)
	if filterFade then
		levelBrightness = levelBrightness + levelBrightnessChg
		if (filterFadeStart and levelBrightness < -14) or levelBrightness > 14 then
			levelBrightnessChg = -levelBrightnessChg
			filterFadeStart = false
			levelFilter = levelFilterNew
		end
		if not filterFadeStart and levelBrightness == 0 then
			filterFade = false
			levelBrightness = -99
		end
	end

	local hue = -99
	local bright = -99
	if col ~= -99 and filtrationAvail then hue = col end
	if brightness ~= -99 and explosionTransparent then bright = brightness end
	if hue ~= -99 or bright ~= -99 then
		pushFilter(VGAScreen, 24, 0, 264, 184, hue, bright)
	end
end

function JE_checkSmoothies()
	anySmoothies = (processorType > 2 and (smoothies[0] or smoothies[1])) or
		(processorType > 1 and (smoothies[2] or smoothies[3] or smoothies[4]))
end

-- The smoothie filters copy the source surface and tint it.
function lava_filter(dst, src)
	if dst ~= src then surfaceBlit(dst, 0, 0, src, 0, 0, 320, 200) end
	pushFilter(dst, 0, 0, 320, 185, 7, -99)
end

function water_filter(dst, src)
	if dst ~= src then surfaceBlit(dst, 0, 0, src, 0, 0, 320, 200) end
	pushFilter(dst, 0, 0, 320, 185, smoothie_data[1], -99)
end

function iced_blur_filter(dst, src)
	if dst ~= src then surfaceBlit(dst, 0, 0, src, 0, 0, 320, 200) end
	pushFilter(dst, 0, 0, 320, 184, 8, -99)
end

function blur_filter(dst, src)
	if dst ~= src then surfaceBlit(dst, 0, 0, src, 0, 0, 320, 200) end
end

function showHeadlight(dst, src, playerX, playerY)
	surfaceBlit(dst, 0, 0, src, 24, 0, 264, 184)
	pushFilter(dst, 0, 0, 264, 184, -99, -6)
end

function showFlipped(dst, src)
	surfaceBlit(dst, 0, 0, src, 24, 0, 264, 184, true)
end

function showNormal(dst, src)
	surfaceBlit(dst, 0, 0, src, 24, 0, 264, 184)
end

-- Starfield ---------------------------------------------------------------------------

local MAX_STARS = 100
local STARFIELD_HUE = 0x90
local starfield_stars = newArray(MAX_STARS, function() return { color = 0, position = 0, speed = 0 } end)
starfield_speed = 0

function initialize_starfield()
	for i = MAX_STARS - 1, 0, -1 do
		local s = starfield_stars[i]
		s.position = (mt_rand() % 320 + (mt_rand() % 200) * 320) % 65536
		s.speed = mt_rand() % 3 + 2
		s.color = mt_rand() % 16 + STARFIELD_HUE
	end
end

function update_and_draw_starfield(surface, move_speed)
	local target = surface
	if starTarget == surface then target = starSurface end
	for i = MAX_STARS - 1, 0, -1 do
		local star = starfield_stars[i]
		star.position = (star.position + (star.speed + move_speed) * 320) % 65536
		if star.position < 177 * 320 then
			local sx = star.position % 320
			local sy = (star.position - sx) / 320
			if star.color - 4 >= STARFIELD_HUE then
				push(target, K_STAR, sx, sy, star.color)
			else
				push(target, K_RECT, sx, sy, 1, 1, star.color, 0)
			end
		end
	end
end
