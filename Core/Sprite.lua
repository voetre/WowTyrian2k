--[[
 WowTyrian2k: a World of Warcraft port of OpenTyrian
 Copyright (C) The OpenTyrian Development Team
 Lua port Copyright (C) 2026 voetre
 Licensed under the GNU General Public License v2 or later (see COPYING).

 sprite.c replacement.  Sprite pixel data lives in pre-baked texture atlases
 (see tools/convert.py); only sprite dimensions are kept here.
]]
local _, ns = ...
setfenv(1, ns.G)

FONT_SHAPES       = 0
SMALL_FONT_SHAPES = 1
TINY_FONT         = 2
PLANET_SHAPES     = 3
FACE_SHAPES       = 4
OPTION_SHAPES     = 5
WEAPON_SHAPES     = 6
EXTRA_SHAPES      = 7

SPRITE_TABLES_MAX = 8
SPRITES_PER_TABLE_MAX = 151

local missing = { width = 0, height = 0, exists = false }

-- sprite_table[t] = { count = n, sprite = { [i] = {width, height, exists, ...} } }
sprite_table = {}
for t = 0, SPRITE_TABLES_MAX - 1 do
	sprite_table[t] = { count = 0, sprite = {}, meta = nil }
end

local function loadTableMeta(t)
	local meta = ns.gfxmeta.tables[t]
	local st = sprite_table[t]
	st.meta = meta
	st.count = meta.count
	st.sprite = {}
	for i = 0, meta.count - 1 do
		local s = meta.s[i]
		if s then
			st.sprite[i] = { width = s[1], height = s[2], ax = s[3], ay = s[4], vmax = s[5], opaque = s[6], exists = true }
		end
	end
end

function sprite(t, index)
	return sprite_table[t].sprite[index] or missing
end

function sprite_exists(t, index)
	local s = sprite_table[t].sprite[index]
	return s ~= nil and s.exists
end

function get_sprite_width(t, index)
	local s = sprite_table[t].sprite[index]
	return s and s.width or 0
end

function get_sprite_height(t, index)
	local s = sprite_table[t].sprite[index]
	return s and s.height or 0
end

function load_sprites_file(t, filename)
	-- Only estsc.shp (EXTRA_SHAPES) is loaded this way.
	loadTableMeta(t)
end

function free_sprites(t)
	sprite_table[t].count = 0
	sprite_table[t].sprite = {}
end

local push = ns.pushOp

local function blit(surface, x, y, t, index, mode, hue, value)
	if index >= sprite_table[t].count or not sprite_exists(t, index) then
		return
	end
	if mode == 0 and surface.persistent then
		local s = sprite_table[t].sprite[index]
		if s.opaque then ns.coverRect(surface, x, y, s.width, s.height) end
	end
	push(surface, K_SPR, t, index, x, y, mode, hue or 0, value or 0)
end

function blit_sprite(surface, x, y, t, index)
	blit(surface, x, y, t, index, 0)
end

function blit_sprite_blend(surface, x, y, t, index)
	blit(surface, x, y, t, index, 1)
end

function blit_sprite_hv_unsafe(surface, x, y, t, index, hue, value)
	blit(surface, x, y, t, index, 2, hue, value)
end

function blit_sprite_hv(surface, x, y, t, index, hue, value)
	blit(surface, x, y, t, index, 2, hue, value)
end

function blit_sprite_hv_blend(surface, x, y, t, index, hue, value)
	blit(surface, x, y, t, index, 3, hue, value)
end

function blit_sprite_dark(surface, x, y, t, index, black)
	blit(surface, x, y, t, index, black and 5 or 4)
end

-- Sprite2 sheets ---------------------------------------------------------------

local function newSheet() return { key = nil, data = nil, size = 0 } end

shopSpriteSheet = newSheet()
explosionSpriteSheet = newSheet()
enemySpriteSheets = { [0] = newSheet(), newSheet(), newSheet(), newSheet() }
enemySpriteSheetIds = { [0] = 0, 0, 0, 0 }
destructSpriteSheet = newSheet()
spriteSheet8 = newSheet()
spriteSheet9 = newSheet()
spriteSheet10 = newSheet()
spriteSheet11 = newSheet()
spriteSheet12 = newSheet()
extraShapes = newSheet()

local function setSheet(sheet, key)
	local meta = ns.gfxmeta.sheets[key]
	sheet.key = key
	sheet.meta = meta
	sheet.data = meta and true or nil
	sheet.size = meta and meta.count or 0
end

function JE_loadCompShapes(sprite2s, s)
	setSheet(sprite2s, "newsh" .. string.lower(s))
end

function free_sprite2s(sprite2s)
	sprite2s.key = nil
	sprite2s.meta = nil
	sprite2s.data = nil
	sprite2s.size = 0
end

local function blit2(surface, x, y, sheet, index, mode, filter)
	local meta = sheet.meta
	if not meta or index < 1 or index > meta.count then return end
	push(surface, K_SPR2, meta, index, x, y, mode, filter or 0)
end

function blit_sprite2(surface, x, y, s, index) blit2(surface, x, y, s, index, 0) end
function blit_sprite2_clip(surface, x, y, s, index) blit2(surface, x, y, s, index, 0) end
function blit_sprite2_blend(surface, x, y, s, index) blit2(surface, x, y, s, index, 1) end
function blit_sprite2_darken(surface, x, y, s, index) blit2(surface, x, y, s, index, 2) end
function blit_sprite2_filter(surface, x, y, s, index, filter) blit2(surface, x, y, s, index, 3, filter) end
function blit_sprite2_filter_clip(surface, x, y, s, index, filter) blit2(surface, x, y, s, index, 3, filter) end

function blit_sprite2x2(surface, x, y, s, index)
	blit_sprite2(surface, x,      y,      s, index)
	blit_sprite2(surface, x + 12, y,      s, index + 1)
	blit_sprite2(surface, x,      y + 14, s, index + 19)
	blit_sprite2(surface, x + 12, y + 14, s, index + 20)
end
blit_sprite2x2_clip = blit_sprite2x2

function blit_sprite2x2_blend(surface, x, y, s, index)
	blit_sprite2_blend(surface, x,      y,      s, index)
	blit_sprite2_blend(surface, x + 12, y,      s, index + 1)
	blit_sprite2_blend(surface, x,      y + 14, s, index + 19)
	blit_sprite2_blend(surface, x + 12, y + 14, s, index + 20)
end

function blit_sprite2x2_darken(surface, x, y, s, index)
	blit_sprite2_darken(surface, x,      y,      s, index)
	blit_sprite2_darken(surface, x + 12, y,      s, index + 1)
	blit_sprite2_darken(surface, x,      y + 14, s, index + 19)
	blit_sprite2_darken(surface, x + 12, y + 14, s, index + 20)
end

function blit_sprite2x2_filter(surface, x, y, s, index, filter)
	blit_sprite2_filter(surface, x,      y,      s, index, filter)
	blit_sprite2_filter(surface, x + 12, y,      s, index + 1, filter)
	blit_sprite2_filter(surface, x,      y + 14, s, index + 19, filter)
	blit_sprite2_filter(surface, x + 12, y + 14, s, index + 20, filter)
end
blit_sprite2x2_filter_clip = blit_sprite2x2_filter

function JE_loadMainShapeTables(shpfile)
	for t = 0, 6 do loadTableMeta(t) end
	setSheet(spriteSheet8, "shot8")
	setSheet(spriteSheet9, "ship9")
	setSheet(spriteSheet10, "power10")
	setSheet(spriteSheet11, "coin11")
	setSheet(spriteSheet12, "shot12")
end

function free_main_shape_tables() end

-- Background tiles --------------------------------------------------------------

function blit_tile(surface, x, y, tileset, z, mode)
	push(surface, K_TILE, tileset, z, x, y, mode or 0, 200)
end
