--[[
 WowTyrian2k: a World of Warcraft port of OpenTyrian
 Copyright (C) The OpenTyrian Development Team
 Lua port Copyright (C) 2026 voetre
 Licensed under the GNU General Public License v2 or later (see COPYING).

 video.c / vga256d.c / sprite.c drawing replacement.

 WoW cannot upload pixels, so a "surface" is a display list of drawing
 operations.  Blits append operations; opaque fills drop the operations they
 completely cover so lists stay bounded.  JE_showVGA() renders VGAScreen's
 list to WoW textures (Render.lua).

 Operation tables are pooled per surface and reused, so drawing creates no
 garbage.  Layouts (array fields):
   SPR  {1, table, index, x, y, mode, hue, value}
        mode: 0 normal, 1 blend, 2 hue/value, 3 hue/value blend, 4 darken, 5 black
   SPR2 {2, sheetMeta, index, x, y, mode, filter}
        mode: 0 normal, 1 blend, 2 darken, 3 filter
   RECT {3, x, y, w, h, colorIndex, mode}   mode: 0 fill, 1 shade, 2 bright
   PIC  {4, texture, x, y, w, h, sx, sy, texW, texH}
   TILE {5, tileset, z, x, y, mode, maxY}   mode: 0 normal, 1 blend
   SURF {6, surface, -, sx, sy, w, h, dx, dy, flip}   (live reference)
   FILT {7, x, y, w, h, hue, brightness}
   GRP  {8, surface}
   STAR {9, x, y, colorIndex}
]]
local _, ns = ...
setfenv(1, ns.G)

vga_width, vga_height = 320, 200

K_SPR, K_SPR2, K_RECT, K_PIC, K_TILE, K_SURF, K_FILT, K_GRP, K_STAR = 1, 2, 3, 4, 5, 6, 7, 8, 9

-- persistent surfaces get opaque-coverage compaction on every opaque draw;
-- game_screen is cleared every frame so it does not need it.
local function newSurface(name, persistent)
	return { name = name, w = vga_width, h = vga_height, pitch = vga_width, ops = {}, n = 0, persistent = persistent }
end
ns.newSurface = newSurface

VGAScreen = newSurface("VGAScreen", true)
VGAScreenSeg = VGAScreen
VGAScreen2 = newSurface("VGAScreen2", true)
game_screen = newSurface("game_screen", false)

-- Bounding box of an operation (x, y, w, h).
local function opBounds(op)
	local k = op[1]
	if k == K_SPR then
		local s = sprite(op[2], op[3])
		return op[4], op[5], s.width, s.height
	elseif k == K_SPR2 then
		return op[4], op[5], 12, 14
	elseif k == K_RECT or k == K_FILT then
		return op[2], op[3], op[4], op[5]
	elseif k == K_PIC then
		return op[3], op[4], op[5], op[6]
	elseif k == K_TILE then
		return op[4], op[5], 24, 28
	elseif k == K_SURF then
		return op[8], op[9], op[6], op[7]
	elseif k == K_STAR then
		return op[2] - 1, op[3] - 1, 3, 3
	end
	return -10000, -10000, 30000, 30000 -- groups are never covered
end
ns.opBounds = opBounds

-- Removes operations completely covered by an opaque rectangle.  Removed
-- tables stay in the pool (moved past the end).
local function coverRect(surface, x, y, w, h)
	local n = surface.n
	if n == 0 then return end
	if x <= 0 and y <= 0 and x + w >= surface.w and y + h >= surface.h then
		surface.n = 0
		return
	end
	local ops = surface.ops
	local j = 0
	local x2, y2 = x + w, y + h
	for i = 1, n do
		local op = ops[i]
		local ox, oy, ow, oh = opBounds(op)
		if not (ox >= x and oy >= y and ox + ow <= x2 and oy + oh <= y2) then
			j = j + 1
			if j ~= i then
				ops[i], ops[j] = ops[j], op
			end
		end
	end
	surface.n = j
end
ns.coverRect = coverRect

local function push(s, k, a, b, c, d, e, f, g, h, i)
	local n = s.n + 1
	if n > 4000 then
		-- Safety valve for a runaway list: keep the first 200 operations
		-- (backgrounds) and the most recent 1800.
		local ops = s.ops
		local from = n - 1800
		for q = 201, 2000 do
			ops[q], ops[from + q - 201] = ops[from + q - 201], ops[q]
		end
		n = 2001
	end
	local op = s.ops[n]
	if not op then
		op = {}
		s.ops[n] = op
	end
	op[1], op[2], op[3], op[4], op[5], op[6], op[7], op[8], op[9], op[10] = k, a, b, c, d, e, f, g, h, i
	s.n = n
	return op
end
ns.pushOp = push

function surfaceClear(surface)
	surface.n = 0
end

-- memcpy(dst->pixels, src->pixels, ...)
function surfaceCopy(dst, src)
	local dops, sops = dst.ops, src.ops
	local n = src.n
	for i = 1, n do
		local d = dops[i]
		if not d then
			d = {}
			dops[i] = d
		end
		local s = sops[i]
		d[1], d[2], d[3], d[4], d[5], d[6], d[7], d[8], d[9], d[10] = s[1], s[2], s[3], s[4], s[5], s[6], s[7], s[8], s[9], s[10]
	end
	dst.n = n
end

-- Copies a rectangle of src onto dst (memcpy of rows).  Opaque.  The source
-- is referenced live, so it must not change until the frame is presented.
function surfaceBlit(dst, dx, dy, src, sx, sy, w, h, flip)
	coverRect(dst, dx, dy, w, h)
	push(dst, K_SURF, src, 0, sx, sy, w, h, dx, dy, flip or false)
end

function JE_clr256(surface)
	surfaceClear(surface)
end

local showCount = 0

function JE_showVGA()
	ns.frameDirty = true
	showCount = showCount + 1
	if showCount > 8 then
		-- Avoid starving the client if a loop shows frames without waiting.
		showCount = 0
		ns.yieldFrame()
	end
end
function ns.resetShowCount() showCount = 0 end

-- vga256d.c ------------------------------------------------------------------

function JE_pix(surface, x, y, c)
	if x >= 0 and y >= 0 and x < surface.w and y < surface.h then
		push(surface, K_RECT, x, y, 1, 1, c, 0)
	end
end

function JE_pix3(surface, x, y, c)
	JE_pix(surface, x, y, c)
	JE_pix(surface, x - 1, y, c)
	JE_pix(surface, x + 1, y, c)
	JE_pix(surface, x, y - 1, c)
	JE_pix(surface, x, y + 1, c)
end

local function opaqueRect(surface, x, y, w, h, color)
	if surface.persistent then coverRect(surface, x, y, w, h) end
	push(surface, K_RECT, x, y, w, h, color, 0)
end

function JE_rectangle(surface, a, b, c, d, e)
	if d - b <= 1 then
		-- no interior: the outline is a solid block
		opaqueRect(surface, a, b, c - a + 1, d - b + 1, e)
		return
	end
	push(surface, K_RECT, a, b, c - a + 1, 1, e, 0)
	push(surface, K_RECT, a, d, c - a + 1, 1, e, 0)
	push(surface, K_RECT, a, b + 1, 1, d - b - 1, e, 0)
	push(surface, K_RECT, c, b + 1, 1, d - b - 1, e, 0)
end

function fill_rectangle_xy(surface, x, y, x2, y2, color)
	fill_rectangle_wh(surface, x, y, x2 - x + 1, y2 - y + 1, color)
end

function fill_rectangle_wh(surface, x, y, w, h, color)
	if w <= 0 or h <= 0 then return end
	if surface.persistent then coverRect(surface, x, y, w, h) end
	push(surface, K_RECT, x, y, w, h, color, 0)
end

function JE_barShade(surface, a, b, c, d)
	push(surface, K_RECT, a, b, c - a + 1, d - b + 1, 0, 1)
end

function JE_barBright(surface, a, b, c, d)
	push(surface, K_RECT, a, b, c - a + 1, d - b + 1, 0, 2)
end

function draw_segmented_gauge(surface, x, y, color, segment_width, segment_height, segment_value, value)
	local segments = math.floor(value / segment_value)
	local partial_segment = value % segment_value
	for i = 0, segments - 1 do
		fill_rectangle_wh(surface, x, y, segment_width, segment_height, color + 12)
		x = x + segment_width + 1
	end
	if partial_segment > 0 then
		fill_rectangle_wh(surface, x, y, segment_width, segment_height, color + math.floor(12 * partial_segment / segment_value))
	end
end

-- Screen-region filters (backgrnd.c effects) ---------------------------------

function pushFilter(surface, x, y, w, h, hue, brightness)
	push(surface, K_FILT, x, y, w, h, hue, brightness)
end

-- A group operation: a nested surface whose contents are drawn in place,
-- optionally clipped to the rectangle (x, y, w, h).
function pushGroup(surface, sub, x, y, w, h)
	push(surface, K_GRP, sub, x, y, w, h)
end

function pushPic(surface, tex, x, y, w, h, sx, sy, tw, th)
	if x <= 0 and y <= 0 and w >= 320 and h >= 200 then
		surface.n = 0
	elseif surface.persistent then
		coverRect(surface, x, y, w, h)
	end
	push(surface, K_PIC, tex, x, y, w, h, sx, sy, tw or 512, th or 256)
end
