--[[
 WowTyrian2k: a World of Warcraft port of OpenTyrian
 Copyright (C) The OpenTyrian Development Team
 Lua port Copyright (C) 2026 voetre
 Licensed under the GNU General Public License v2 or later (see COPYING).

 palette.c replacement.

 The original game changes VGA palette entries to fade the screen.  WoW
 textures are baked RGBA, so here the "logical" palette (used to resolve
 palette indexes of rectangles, pixels and tinted text at render time) is kept
 separately from a full-screen fade overlay (colour + alpha).  The rendered
 result of a fade is lerp(palette, overlayColour, overlayAlpha), which matches
 linear palette fades to/from black or white exactly.
]]
local _, ns = ...
setfenv(1, ns.G)

palettes = {}
palettesCount = 0

-- A palette is a 0-based array of {r, g, b} (0..255) plus an `id` field that
-- names the source palette (used to pick pre-baked texture variants).
local function newPalette()
	local p = { id = 0 }
	for i = 0, 255 do p[i] = { 0, 0, 0 } end
	return p
end

function copyPalette(dst, src)
	for i = 0, 255 do
		local d, s = dst[i], src[i]
		d[1], d[2], d[3] = s[1], s[2], s[3]
	end
	dst.id = src.id
	return dst
end

colors = newPalette()        -- the game's working palette (FKA colors)
palette = newPalette()       -- the palette currently "on screen"

-- fade overlay
fadeColor = { 0, 0, 0 }
fadeAlpha = 1                -- screen starts black

function loadPals()
	local file = dataFileOpen("palette.dat")
	palettesCount = math.floor(fileGetLength(file) / (256 * 3))
	for p = 0, palettesCount - 1 do
		local pal = newPalette()
		pal.id = p
		for i = 0, 255 do
			local r, g, b = fileReadU8(file), fileReadU8(file), fileReadU8(file)
			local c = pal[i]
			c[1] = bor(lshift(r, 2), rshift(r, 4))
			c[2] = bor(lshift(g, 2), rshift(g, 4))
			c[3] = bor(lshift(b, 2), rshift(b, 4))
		end
		palettes[p] = pal
	end
end

function set_palette(colors_, first_color, last_color)
	if first_color == 0 and last_color == 255 then
		copyPalette(palette, colors_)
	else
		for i = first_color, last_color do
			local d, s = palette[i], colors_[i]
			d[1], d[2], d[3] = s[1], s[2], s[3]
		end
	end
	fadeAlpha = 0
	ns.paletteDirty = true
end

-- color is {r, g, b}
function set_colors(color, first_color, last_color)
	if first_color == 0 and last_color == 255 then
		fadeColor[1], fadeColor[2], fadeColor[3] = color[1], color[2], color[3]
		fadeAlpha = 1
	else
		for i = first_color, last_color do
			local d = palette[i]
			d[1], d[2], d[3] = color[1], color[2], color[3]
		end
	end
	ns.paletteDirty = true
end

-- Animates the overlay from its current state to (target colour, alpha).
local function animateOverlay(r, g, b, a, steps)
	local r0, g0, b0, a0 = fadeColor[1], fadeColor[2], fadeColor[3], fadeAlpha
	-- If the overlay is currently invisible its colour is irrelevant.
	if a0 == 0 then r0, g0, b0 = r, g, b end
	for s = 1, steps do
		setFrameCount(1)

		local t = s / steps
		fadeColor[1] = r0 + (r - r0) * t
		fadeColor[2] = g0 + (g - g0) * t
		fadeColor[3] = b0 + (b - b0) * t
		fadeAlpha = a0 + (a - a0) * t

		JE_showVGA()

		waitUntilElapsed()
	end
	fadeColor[1], fadeColor[2], fadeColor[3], fadeAlpha = r, g, b, a
end

function fade_palette(colors_, steps, first_color, last_color)
	if fadeAlpha < 1 and palette.id ~= colors_.id then
		-- Cross-palette fade: go through black.
		local half = math.max(1, math.floor(steps / 2))
		animateOverlay(0, 0, 0, 1, half)
		steps = math.max(1, steps - half)
	end
	copyPalette(palette, colors_)
	ns.paletteDirty = true
	animateOverlay(fadeColor[1], fadeColor[2], fadeColor[3], 0, steps)

	keyboardClearInput()
	mouseClearInput()
end

function fade_solid(color, steps, first_color, last_color)
	animateOverlay(color[1], color[2], color[3], 1, steps)

	keyboardClearInput()
	mouseClearInput()
end

function fade_black(steps)
	fade_solid({ 0, 0, 0 }, steps, 0, 255)
end

function fade_white(steps)
	fade_solid({ 255, 255, 255 }, steps, 0, 255)
end

-- Gamma correction from mainint.c works on palette entries; kept for API.
function JE_gammaCorrect_func(col, r) return col end
