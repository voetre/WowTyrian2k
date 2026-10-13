--[[
 WowTyrian2k: a World of Warcraft port of OpenTyrian
 Copyright (C) The OpenTyrian Development Team
 Lua port Copyright (C) 2026 voetre
 Licensed under the GNU General Public License v2 or later (see COPYING).

 Turns a surface display list (see Video.lua) into WoW textures.

 Draw order is guaranteed by giving every quad its own slot: slots are grouped
 16 per child frame (one per ARTWORK sublevel -8..7) and child frames have
 increasing frame levels.
]]
local _, ns = ...
setfenv(1, ns.G)

local floor = math.floor
local SLOTS_PER_FRAME = 16

local root, canvas, overlay
local scale = 3
local slots = {}
local slotFrames = {}
local usedLast = 0
local used = 0

local function slotState(i)
	local s = slots[i]
	if s then return s end
	local fi = floor((i - 1) / SLOTS_PER_FRAME)
	local f = slotFrames[fi]
	if not f then
		f = CreateFrame("Frame", nil, canvas)
		f:SetAllPoints(canvas)
		f:SetFrameLevel(canvas:GetFrameLevel() + 1 + fi)
		slotFrames[fi] = f
	end
	local t = f:CreateTexture(nil, "ARTWORK", nil, ((i - 1) % SLOTS_PER_FRAME) - 8)
	if t.SetSnapToPixelGrid then
		t:SetSnapToPixelGrid(false)
		t:SetTexelSnappingBias(0)
	end
	t:Hide()
	s = { tex = t }
	slots[i] = s
	return s
end

-- Clip rect of the current traversal (in source pixels).
local cx0, cy0, cx1, cy1 = 0, 0, 320, 200
-- Vertical mirroring: when flipAxis is set, y' = flipAxis - y.
local flipAxis = nil

-- Emits a textured quad.  (x, y, w, h) destination in game pixels; (u, v) is
-- the source top-left in texture pixels; tw/th texture size.  flipV mirrors
-- the quad vertically within flip region [fy0, fy1).
local function quad(path, tw, th, x, y, w, h, u, v, r, g, b, a, mode)
	-- clip
	local x0, y0, x1, y1 = x, y, x + w, y + h
	if x0 < cx0 then u = u + (cx0 - x0); x0 = cx0 end
	if y0 < cy0 then v = v + (cy0 - y0); y0 = cy0 end
	if x1 > cx1 then x1 = cx1 end
	if y1 > cy1 then y1 = cy1 end
	if x1 <= x0 or y1 <= y0 then return end
	local qw, qh = x1 - x0, y1 - y0
	local flipped = false
	if flipAxis then
		y0 = flipAxis - y1
		flipped = true
	end

	used = used + 1
	local s = slotState(used)
	local t = s.tex
	if s.path ~= path then
		t:SetTexture(path, "CLAMP", "CLAMP", "NEAREST")
		s.path = path
	end
	local u0, v0, u1, v1 = u / tw, v / th, (u + qw) / tw, (v + qh) / th
	if flipped then v0, v1 = v1, v0 end
	if s.u0 ~= u0 or s.v0 ~= v0 or s.u1 ~= u1 or s.v1 ~= v1 then
		t:SetTexCoord(u0, u1, v0, v1)
		s.u0, s.v0, s.u1, s.v1 = u0, v0, u1, v1
	end
	if s.x ~= x0 or s.y ~= y0 then
		t:SetPoint("TOPLEFT", canvas, "TOPLEFT", x0 * scale, -y0 * scale)
		s.x, s.y = x0, y0
	end
	if s.w ~= qw or s.h ~= qh then
		t:SetSize(qw * scale, qh * scale)
		s.w, s.h = qw, qh
	end
	if s.r ~= r or s.g ~= g or s.b ~= b or s.a ~= a then
		t:SetVertexColor(r, g, b, a)
		s.r, s.g, s.b, s.a = r, g, b, a
	end
	if s.mode ~= mode then
		t:SetBlendMode(mode)
		s.mode = mode
	end
	if not s.shown then
		t:Show()
		s.shown = true
	end
end

local WHITE
local function solid(x, y, w, h, r, g, b, a, mode)
	quad(WHITE, 8, 8, x, y, w, h, 2, 2, r, g, b, a, mode)
end

-- Palette helpers ------------------------------------------------------------------

local function palColor(ci)
	local c = palette[ci % 256]
	return c[1] / 255, c[2] / 255, c[3] / 255
end

local function hvColor(hue, value)
	if value < 0 then value = 0 elseif value > 15 then value = 15 end
	return palColor(hue * 16 + value)
end

-- Sprites -------------------------------------------------------------------------

local function tableTexture(meta)
	local tex = meta.tex
	if tex[-1] then return tex[-1] end
	return tex[palette.id] or tex[0]
end

local function drawSprite(op, ox, oy)
	local t, index, mode = op[2], op[3], op[6]
	local spr = sprite_table[t].sprite[index]
	if not spr then return end
	local meta = sprite_table[t].meta
	local x, y = op[4] + ox, op[5] + oy
	local w, h = spr.width, spr.height
	if mode == 0 then
		quad(tableTexture(meta), meta.tw, meta.th, x, y, w, h, spr.ax, spr.ay, 1, 1, 1, 1, "BLEND")
	elseif mode == 1 then
		quad(tableTexture(meta), meta.tw, meta.th, x, y, w, h, spr.ax, spr.ay, 1, 1, 1, 0.6, "BLEND")
	elseif (mode == 2 or mode == 3) and meta.shiftTex and op[8] >= 0 then
		-- per-pixel brightness offset baked into the font variants
		local v = op[8]
		if v > 15 then v = 15 end
		local r, g, b = palColor((op[7] % 16) * 16 + 15)
		local paths = meta.shiftPaths
		if not paths then
			paths = {}
			for i = 0, 30 do paths[i] = meta.shiftTex .. i end
			meta.shiftPaths = paths
		end
		quad(paths[v + 15], meta.tw, meta.th, x, y, w, h, spr.ax, spr.ay, r, g, b, mode == 3 and 0.6 or 1, "BLEND")
	elseif mode == 2 or mode == 3 then
		-- Fonts scale every glyph against the font's highest level: a few
		-- glyphs (m, n, f, v) peak one level lower, and scaling them by their
		-- own maximum gave them a different colour from the other letters.
		local vmax = spr.vmax
		if meta.shiftTex then
			vmax = meta.fontVmax
			if not vmax then
				vmax = 0
				for _, sp in pairs(sprite_table[t].sprite) do
					if sp.vmax > vmax then vmax = sp.vmax end
				end
				meta.fontVmax = vmax
			end
		end
		if vmax < 1 then vmax = 1 end
		local r, g, b = hvColor(op[7] % 16, vmax + op[8])
		local k = 15 / vmax
		r, g, b = math.min(1, r * k), math.min(1, g * k), math.min(1, b * k)
		quad(meta.grayTex, meta.tw, meta.th, x, y, w, h, spr.ax, spr.ay, r, g, b, mode == 3 and 0.6 or 1, "BLEND")
	elseif mode == 4 then
		quad(meta.grayTex, meta.tw, meta.th, x, y, w, h, spr.ax, spr.ay, 0, 0, 0, 0.5, "BLEND")
	else
		quad(meta.grayTex, meta.tw, meta.th, x, y, w, h, spr.ax, spr.ay, 0, 0, 0, 1, "BLEND")
	end
end

local function drawSprite2(op, ox, oy)
	local meta, index, mode = op[2], op[3], op[6]
	local cols = meta.cols
	local u = ((index - 1) % cols) * 14 + 1
	local v = floor((index - 1) / cols) * 16 + 1
	local x, y = op[4] + ox, op[5] + oy
	if mode == 0 then
		quad(meta.tex, meta.tw, meta.th, x, y, 12, 14, u, v, 1, 1, 1, 1, "BLEND")
	elseif mode == 1 then
		quad(meta.tex, meta.tw, meta.th, x, y, 12, 14, u, v, 1, 1, 1, 0.6, "BLEND")
	elseif mode == 2 then
		quad(meta.grayTex, meta.tw, meta.th, x, y, 12, 14, u, v, 0, 0, 0, 0.5, "BLEND")
	else
		local f = op[7]
		local r, g, b = palColor(floor(f / 16) * 16 + 15)
		quad(meta.grayTex, meta.tw, meta.th, x, y, 12, 14, u, v, r, g, b, 1, "BLEND")
	end
end

local function drawTile(op, ox, oy)
	local ts, z = op[2], op[3]
	local cols = ts.cols
	local u = (z % cols) * 26 + 1
	local v = floor(z / cols) * 30 + 1
	local oldcy1 = cy1
	local maxY = op[7]
	if maxY and maxY + oy < cy1 then cy1 = maxY + oy end
	quad(ts.tex, ts.tw, ts.th, op[4] + ox, op[5] + oy, 24, 28, u, v, 1, 1, 1, op[6] == 1 and 0.6 or 1, "BLEND")
	cy1 = oldcy1
end

local function drawRect(op, ox, oy)
	local mode = op[7]
	local x, y, w, h = op[2] + ox, op[3] + oy, op[4], op[5]
	if mode == 0 then
		local r, g, b = palColor(op[6])
		solid(x, y, w, h, r, g, b, 1, "BLEND")
	elseif mode == 1 then
		solid(x, y, w, h, 0, 0, 0, 0.5, "BLEND")
	else
		solid(x, y, w, h, 1, 1, 1, 0.15, "ADD")
	end
end

local function drawFilter(op, ox, oy)
	local x, y, w, h = op[2] + ox, op[3] + oy, op[4], op[5]
	local hue, bright = op[6], op[7]
	if hue and hue ~= -99 then
		local r, g, b = palColor((hue % 16) * 16 + 12)
		local m = math.max(r, g, b, 0.01)
		solid(x, y, w, h, r / m, g / m, b / m, 1, "MOD")
	end
	if bright and bright ~= -99 and bright ~= 0 then
		if bright < 0 then
			solid(x, y, w, h, 0, 0, 0, math.min(1, -bright / 15), "BLEND")
		else
			solid(x, y, w, h, 1, 1, 1, math.min(1, bright / 15) * 0.6, "ADD")
		end
	end
end

local drawOps

local function drawSurf(op, ox, oy)
	-- {6, surface, -, sx, sy, w, h, dx, dy, flip}
	local sx, sy, w, h, dx, dy = op[4], op[5], op[6], op[7], op[8] + ox, op[9] + oy
	local px0, py0, px1, py1 = cx0, cy0, cx1, cy1
	cx0 = math.max(cx0, dx); cy0 = math.max(cy0, dy)
	cx1 = math.min(cx1, dx + w); cy1 = math.min(cy1, dy + h)
	if cx1 > cx0 and cy1 > cy0 then
		if op[10] and not flipAxis then
			-- mirror the copied rows within [dy, dy + h)
			flipAxis = dy + dy + h
			drawOps(op[2].ops, op[2].n, dx - sx, dy - sy)
			flipAxis = nil
		else
			drawOps(op[2].ops, op[2].n, dx - sx, dy - sy)
		end
	end
	cx0, cy0, cx1, cy1 = px0, py0, px1, py1
end

local STAR
local function drawStar(op, ox, oy)
	-- {9, x, y, colorIndex, big}
	local r, g, b = palColor(op[4])
	if op[5] then
		-- jukebox star: 5x5 cross
		quad(STAR, 16, 8, op[2] - 2 + ox, op[3] - 2 + oy, 5, 5, 9, 1, r, g, b, 1, "BLEND")
	else
		quad(STAR, 16, 8, op[2] - 1 + ox, op[3] - 1 + oy, 3, 3, 1, 1, r, g, b, 1, "BLEND")
	end
end

local function drawPic(op, ox, oy)
	-- {4, texture, x, y, w, h, sx, sy}
	quad(op[2], op[9] or 512, op[10] or 256, op[3] + ox, op[4] + oy, op[5], op[6], op[7], op[8], 1, 1, 1, 1, "BLEND")
end

drawOps = function(ops, n, ox, oy)
	for i = 1, n do
		local op = ops[i]
		local k = op[1]
		if k == K_SPR2 then drawSprite2(op, ox, oy)
		elseif k == K_TILE then drawTile(op, ox, oy)
		elseif k == K_SPR then drawSprite(op, ox, oy)
		elseif k == K_RECT then drawRect(op, ox, oy)
		elseif k == K_SURF then drawSurf(op, ox, oy)
		elseif k == K_PIC then drawPic(op, ox, oy)
		elseif k == K_STAR then drawStar(op, ox, oy)
		elseif k == K_FILT then drawFilter(op, ox, oy)
		elseif k == K_GRP then
			local sub = op[2]
			if op[3] then
				local s0, s1, s2, s3 = cx0, cy0, cx1, cy1
				local x0, y0 = op[3] + ox, op[4] + oy
				local x1, y1 = x0 + op[5], y0 + op[6]
				if x0 > cx0 then cx0 = x0 end
				if y0 > cy0 then cy0 = y0 end
				if x1 < cx1 then cx1 = x1 end
				if y1 < cy1 then cy1 = y1 end
				drawOps(sub.ops, sub.n, ox, oy)
				cx0, cy0, cx1, cy1 = s0, s1, s2, s3
			else
				drawOps(sub.ops, sub.n, ox, oy)
			end
		end
	end
end

local lastSurface
function ns.present(surface)
	surface = surface or lastSurface
	lastSurface = surface
	if not root or not root:IsShown() or not surface then return end
	used = 0
	cx0, cy0, cx1, cy1 = 0, 0, 320, 200
	flipAxis = nil
	drawOps(surface.ops, surface.n, 0, 0)
	for i = used + 1, usedLast do
		local s = slots[i]
		if s.shown then
			s.tex:Hide()
			s.shown = false
		end
	end
	usedLast = used
	ns.quadCount = used

	if fadeAlpha > 0 then
		overlay:SetColorTexture(fadeColor[1] / 255, fadeColor[2] / 255, fadeColor[3] / 255, fadeAlpha)
		overlay:Show()
	else
		overlay:Hide()
	end
end

function ns.createWindow()
	if root then return root end
	WHITE = ns.gfxmeta.white
	STAR = ns.gfxmeta.star

	root = CreateFrame("Frame", "WowTyrian2kFrame", UIParent)
	root:SetFrameStrata("DIALOG")
	root:SetToplevel(true)
	root:SetClampedToScreen(true)
	root:SetMovable(true)
	root:EnableMouse(true)
	root:SetPoint("CENTER")
	root:Hide()

	local bg = root:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0, 0, 0, 1)

	-- title bar used for dragging
	local bar = CreateFrame("Frame", nil, root)
	bar:SetPoint("BOTTOMLEFT", root, "TOPLEFT", 0, 0)
	bar:SetPoint("BOTTOMRIGHT", root, "TOPRIGHT", 0, 0)
	bar:SetHeight(18)
	bar:EnableMouse(true)
	bar:RegisterForDrag("LeftButton")
	bar:SetScript("OnDragStart", function() root:StartMoving() end)
	bar:SetScript("OnDragStop", function() root:StopMovingOrSizing() end)
	local barbg = bar:CreateTexture(nil, "BACKGROUND")
	barbg:SetAllPoints()
	barbg:SetColorTexture(0.1, 0.1, 0.15, 0.9)
	local title = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	title:SetPoint("LEFT", 6, 0)
	title:SetText("WowTyrian2k")
	ns.titleText = title

	local close = CreateFrame("Button", nil, bar, "UIPanelCloseButton")
	close:SetSize(20, 20)
	close:SetPoint("RIGHT", bar, "RIGHT", 0, 0)
	close:SetScript("OnClick", function() ns.Hide() end)

	canvas = CreateFrame("Frame", nil, root)
	canvas:SetAllPoints(root)
	canvas:SetClipsChildren(true)

	local top = CreateFrame("Frame", nil, root)
	top:SetAllPoints(root)
	top:SetFrameLevel(root:GetFrameLevel() + 500)
	overlay = top:CreateTexture(nil, "OVERLAY")
	overlay:SetAllPoints()
	overlay:Hide()

	ns.root, ns.canvas = root, canvas
	ns.setScale(ns.db and ns.db.scale or 3)
	return root
end

function ns.setScale(s)
	scale = s
	root:SetSize(320 * scale, 200 * scale)
	-- invalidate cached geometry
	for i = 1, #slots do
		local st = slots[i]
		st.x, st.y, st.w, st.h = nil, nil, nil, nil
	end
	ns.present()
end

function ns.getScale() return scale end
