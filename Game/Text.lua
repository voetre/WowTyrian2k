--[[
 WowTyrian2k: a World of Warcraft port of OpenTyrian
 Copyright (C) The OpenTyrian Development Team
 Lua port Copyright (C) 2026 voetre
 Licensed under the GNU General Public License v2 or later (see COPYING).

 helptext.c, fonthand.c, font.c
]]
local _, ns = ...
setfenv(1, ns.G)

local strbyte, strsub, strchar = string.byte, string.sub, string.char

-- helptext.c ------------------------------------------------------------------------
MENU_MAX = 14
DESTRUCT_MODES = 5

menuHelp = {
	[0] = { [0] = 1, 34, 2, 3, 4, 5, 0, 0, 0, 0, 0 },
	{ [0] = 6, 7, 8, 9, 10, 11, 11, 12, 0, 0, 0 },
	{ [0] = 13, 14, 15, 15, 16, 17, 12, 0, 0, 0, 0 },
	newArray(11, 0), newArray(11, 0), newArray(11, 0), newArray(11, 0), newArray(11, 0), newArray(11, 0),
	{ [0] = 4, 30, 30, 3, 5, 0, 0, 0, 0, 0, 0 },
	newArray(11, 0),
	{ [0] = 16, 17, 15, 15, 12, 0, 0, 0, 0, 0, 0 },
	{ [0] = 31, 31, 31, 31, 32, 12, 0, 0, 0, 0, 0 },
	{ [0] = 4, 34, 3, 5, 0, 0, 0, 0, 0, 0, 0 },
}

helpTxt = newArray(39, "")
pName = newArray(21, "")
miscText = newArray(68, "")
miscTextB = newArray(5, "")
keyName = newArray(8, "")
menuText = newArray(7, "")
outputs = newArray(9, "")
topicName = newArray(6, "")
mainMenuHelp = newArray(34, "")
inGameText = newArray(6, "")
detailLevel = newArray(6, "")
gameSpeedText = newArray(5, "")
inputDevices = newArray(3, "")
networkText = newArray(4, "")
difficultyNameB = newArray(11, "")
joyButtonNames = newArray(5, "")
superShips = newArray(11, "")
specialName = newArray(9, "")
destructHelp = newArray(25, "")
weaponNames = newArray(17, "")
destructModeName = newArray(DESTRUCT_MODES, "")
shipInfo = newArray(13, function() return { [0] = "", "" } end)
menuInt = newArray(MENU_MAX + 1, function() return newArray(11, "") end)

-- menus.c names (loaded from tyrian.hdt)
episode_name = newArray(6, "")
difficulty_name = newArray(7, "")
gameplay_name = newArray(5, "")

local crypt_key = { [0] = 204, 129, 63, 255, 71, 19, 25, 62, 1, 99 }

-- Returns the decrypted string (truncated to size-1 chars, like the C code).
function readEncryptedString(file, size)
	local len = fileReadU8(file)
	local raw = fileReadString(file, len)
	if not size or size == 0 or len == 0 then return "" end
	local b = { strbyte(raw, 1, len) }
	for i = len - 1, 0, -1 do
		b[i + 1] = bxor(b[i + 1], crypt_key[i % 10])
		if i == 0 then break end
		b[i + 1] = bxor(b[i + 1], b[i])
	end
	len = MIN(len, size - 1)
	local s = strchar(unpack(b, 1, len))
	local z = s:find("\0", 1, true)
	if z then s = strsub(s, 1, z - 1) end
	return s
end

local function readSection(file, arr, count, size)
	readEncryptedString(file, 0)
	for i = 0, count - 1 do
		arr[i] = readEncryptedString(file, size)
	end
	readEncryptedString(file, 0)
end

function JE_loadHelpText()
	local menuInt_entries = { [0] = -1, 7, 9, 8, -1, -1, 11, -1, -1, -1, 6, 4, 6, 7, 5 }
	local file = dataFileOpen("tyrian.hdt")
	fileReadU32(file)

	readSection(file, helpTxt, 39, 231)
	readSection(file, pName, 21, 16)
	readSection(file, miscText, 68, 42)
	readSection(file, miscTextB, 5, 11)
	readSection(file, menuInt[6], menuInt_entries[6], 18)
	readSection(file, menuText, 7, 21)
	readSection(file, outputs, 9, 31)
	readSection(file, topicName, 6, 21)
	-- Drop the "Two-Player Game Menu" help topic (index 2).
	for i = 2, 4 do topicName[i] = topicName[i + 1] end
	topicName[5] = nil
	readSection(file, mainMenuHelp, 34, 66)
	readSection(file, menuInt[1], menuInt_entries[1], 18)
	readSection(file, menuInt[2], menuInt_entries[2], 18)
	readSection(file, menuInt[3], menuInt_entries[3], 18)
	readSection(file, inGameText, 6, 21)
	readSection(file, detailLevel, 6, 13)
	readSection(file, gameSpeedText, 5, 13)
	readSection(file, episode_name, 6, 31)
	readSection(file, difficulty_name, 7, 21)
	readSection(file, gameplay_name, 5, 26)
	readSection(file, menuInt[10], menuInt_entries[10], 18)
	readSection(file, inputDevices, 3, 13)
	readSection(file, networkText, 4, 22)
	readSection(file, menuInt[11], menuInt_entries[11], 18)
	readSection(file, difficultyNameB, 11, 21)
	readSection(file, menuInt[12], menuInt_entries[12], 18)
	readSection(file, menuInt[13], menuInt_entries[13], 18)
	readSection(file, joyButtonNames, 5, 21)
	readSection(file, superShips, 11, 26)
	readSection(file, specialName, 9, 10)
	readSection(file, destructHelp, 25, 22)
	readSection(file, weaponNames, 17, 17)
	readSection(file, destructModeName, DESTRUCT_MODES, 13)

	readEncryptedString(file, 0)
	for i = 0, 12 do
		shipInfo[i][0] = readEncryptedString(file, 256)
		shipInfo[i][1] = readEncryptedString(file, 256)
	end
	readEncryptedString(file, 0)

	readEncryptedString(file, 0)
	for i = 0, menuInt_entries[14] - 1 do
		menuInt[14][i] = readEncryptedString(file, 18)
	end

	-- This port is single-player only, so reword the texts that still show
	-- "1 Player" / "One Player" choices.
	gameplay_name[0] = "Game Mode"
	gameplay_name[1] = "Full Game"
	gameplay_name[2] = "Arcade"
	topicName[1] = "Game Menu"
	miscText[38] = "Saved Games"
	miscText[55] = "Select a saved game."
end

function JE_helpBox(screen, x, y, message, boxWidth, verticalHeight, color, brightness, shadeType)
	local len = #message
	if len == 0 then return end

	local pos = 1
	local endpos = 0
	local startpos
	local endstring = false

	repeat
		startpos = endpos + 1
		repeat
			endpos = pos
			repeat
				pos = pos + 1
				if pos == len then
					endstring = true
					if pos - startpos < boxWidth then
						endpos = pos + 1
					end
				end
			until strsub(message, pos, pos) == " " or endstring
		until pos - startpos > boxWidth or endstring

		local n = MIN(endpos - startpos + 1, 256)
		local substring = strsub(message, startpos, startpos + n - 2)
		JE_textShade(screen, x, y, substring, color, brightness, shadeType)

		y = y + verticalHeight
	until endstring

	if endpos ~= pos + 1 then
		JE_textShade(screen, x, y, strsub(message, endpos + 1), color, brightness, shadeType)
	end
end

function JE_HBox(screen, x, y, messageNum, boxWidth, verticalHeight, color, brightness)
	JE_helpBox(screen, x, y, helpTxt[messageNum - 1], boxWidth, verticalHeight, color, brightness, FULL_SHADE)
end

-- fonthand.c ------------------------------------------------------------------------
PART_SHADE = 0
FULL_SHADE = 1
DARKEN = 2
TRICK = 3
NO_SHADE = 255

fontMap = newArray(256, -1)
do
	local rows = {
		[32] = { -1, 26, 33, 60, 61, 62, -1, 32, 64, 65, 63, 84, 29, 83, 28, 80 },
		[48] = { 79, 70, 71, 72, 73, 74, 75, 76, 77, 78, 31, 30, -1, 85, -1, 27 },
		[64] = { -1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14 },
		[80] = { 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 68, 82, 69, -1, -1 },
		[96] = { -1, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48 },
		[112] = { 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 66, 81, 67, -1, -1 },
		[128] = { 86, 87, 88, 89, 90, 91, 92, 93, 94, 95, 96, 97, 98, 99, 100, 101 },
		[144] = { 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117 },
		[160] = { 118, 119, 120, 121, 122, 123, 124, 125, 126, -1, -1, -1, -1, -1, -1, -1 },
	}
	for base, row in pairs(rows) do
		for i, v in ipairs(row) do fontMap[base + i - 1] = v end
	end
end

textGlowFont = 0
textGlowBrightness = 6
levelWarningDisplay = false
levelWarningLines = 0
levelWarningText = newArray(10, "")
warningRed = false
warningSoundDelay = 0
armorShipDelay = 0
warningCol = 0
warningColChange = 0

function JE_dString(screen, x, y, s, font)
	local defaultBrightness = -3
	local bright = 0
	for i = 1, #s do
		local c = strbyte(s, i)
		local sprite_id = fontMap[c]
		if c == 32 then
			x = x + 6
		elseif c == 126 then
			-- highlight one step brighter than the original (+2) for readability
			bright = (bright == 0) and 3 or 0
		elseif sprite_id ~= -1 then
			blit_sprite_dark(screen, x + 2, y + 2, font, sprite_id, false)
			blit_sprite_hv_unsafe(screen, x, y, font, sprite_id, 0xf, defaultBrightness + bright)
			x = x + sprite(font, sprite_id).width + 1
		end
	end
end

function JE_fontCenter(s, font)
	return 160 - idiv(JE_textWidth(s, font), 2)
end

function JE_textWidth(s, font)
	local x = 0
	for i = 1, #s do
		local c = strbyte(s, i)
		local sprite_id = fontMap[c]
		if c == 32 then
			x = x + 6
		elseif sprite_id ~= -1 then
			x = x + sprite(font, sprite_id).width + 1
		end
	end
	return x
end

function JE_textShade(screen, x, y, s, colorbank, brightness, shadetype)
	if shadetype == PART_SHADE then
		JE_outText(screen, x + 1, y + 1, s, 0, -1)
		JE_outText(screen, x, y, s, colorbank, brightness)
	elseif shadetype == FULL_SHADE then
		JE_outText(screen, x - 1, y, s, 0, -1)
		JE_outText(screen, x + 1, y, s, 0, -1)
		JE_outText(screen, x, y - 1, s, 0, -1)
		JE_outText(screen, x, y + 1, s, 0, -1)
		JE_outText(screen, x, y, s, colorbank, brightness)
	elseif shadetype == DARKEN then
		JE_outTextAndDarken(screen, x + 1, y + 1, s, colorbank, brightness, TINY_FONT)
	elseif shadetype == TRICK then
		JE_outTextModify(screen, x, y, s, colorbank, brightness, TINY_FONT)
	end
end

function JE_outText(screen, x, y, s, colorbank, brightness)
	local bright = 0
	for i = 1, #s do
		local c = strbyte(s, i)
		local sprite_id = fontMap[c]
		if c == 32 then
			x = x + 6
		elseif c == 126 then
			bright = (bright == 0) and 4 or 0
		elseif sprite_id ~= -1 and sprite_exists(TINY_FONT, sprite_id) then
			if brightness >= 0 then
				blit_sprite_hv_unsafe(screen, x, y, TINY_FONT, sprite_id, colorbank, brightness + bright)
			else
				blit_sprite_dark(screen, x, y, TINY_FONT, sprite_id, true)
			end
			x = x + sprite(TINY_FONT, sprite_id).width + 1
		end
	end
end

function JE_outTextModify(screen, x, y, s, filter, brightness, font)
	for i = 1, #s do
		local c = strbyte(s, i)
		local sprite_id = fontMap[c]
		if c == 32 then
			x = x + 6
		elseif sprite_id ~= -1 then
			blit_sprite_hv_blend(screen, x, y, font, sprite_id, filter, brightness)
			x = x + sprite(font, sprite_id).width + 1
		end
	end
end

function JE_outTextAdjust(screen, x, y, s, filter, brightness, font, shadow)
	local bright = 0
	for i = 1, #s do
		local c = strbyte(s, i)
		local sprite_id = fontMap[c]
		if c == 32 then
			x = x + 6
		elseif c == 126 then
			bright = (bright == 0) and 4 or 0
		elseif sprite_id ~= -1 and sprite_exists(TINY_FONT, sprite_id) then
			if shadow then
				blit_sprite_dark(screen, x + 2, y + 2, font, sprite_id, false)
			end
			blit_sprite_hv(screen, x, y, font, sprite_id, filter, brightness + bright)
			x = x + sprite(font, sprite_id).width + 1
		end
	end
end

function JE_outTextAndDarken(screen, x, y, s, colorbank, brightness, font)
	local bright = 0
	for i = 1, #s do
		local c = strbyte(s, i)
		local sprite_id = fontMap[c]
		if c == 32 then
			x = x + 6
		elseif c == 126 then
			bright = (bright == 0) and 4 or 0
		elseif sprite_id ~= -1 and sprite_exists(TINY_FONT, sprite_id) then
			blit_sprite_dark(screen, x + 1, y + 1, font, sprite_id, false)
			blit_sprite_hv_unsafe(screen, x, y, font, sprite_id, colorbank, brightness + bright)
			x = x + sprite(font, sprite_id).width + 1
		end
	end
end

function JE_updateWarning(screen)
	if getFrameCount2Ticks() == 0 then
		warningCol = warningCol + warningColChange
		if warningCol > 14 * 16 + 10 or warningCol < 14 * 16 + 4 then
			warningColChange = -warningColChange
		end
		fill_rectangle_xy(screen, 0, 0, 319, 5, warningCol)
		fill_rectangle_xy(screen, 0, 194, 319, 199, warningCol)
		JE_showVGA()

		setFrameCount2(6)

		if warningSoundDelay > 0 then
			warningSoundDelay = warningSoundDelay - 1
		else
			warningSoundDelay = 14
			JE_playSampleNum(S_WARNING)
		end
	end
end

function JE_outTextGlow(screen, x, y, s)
	local c = 15
	if warningRed then c = 7 end

	JE_outTextAdjust(screen, x - 1, y, s, 0, -12, textGlowFont, false)
	JE_outTextAdjust(screen, x, y - 1, s, 0, -12, textGlowFont, false)
	JE_outTextAdjust(screen, x + 1, y, s, 0, -12, textGlowFont, false)
	JE_outTextAdjust(screen, x, y + 1, s, 0, -12, textGlowFont, false)

	if frameCountMax > 0 then
		for z = 1, 12 do
			setFrameCount(frameCountMax)
			JE_outTextAdjust(screen, x, y, s, c, z - 10, textGlowFont, false)
			JE_showVGA()
			if waitUntilGetInputOrElapsed() then
				frameCountMax = 0
			end
		end
	end

	local z = (frameCountMax == 0) and 6 or 12
	while z >= textGlowBrightness do
		setFrameCount(frameCountMax)
		JE_outTextAdjust(screen, x, y, s, c, z - 10, textGlowFont, false)
		JE_showVGA()
		if waitUntilGetInputOrElapsed() then
			frameCountMax = 0
		end
		z = z - 1
	end

	textGlowBrightness = 6
end

-- font.c ------------------------------------------------------------------------
FONT_LARGE = 0
FONT_NORMAL = 1
FONT_SMALL = 2
ALIGN_LEFT = 0
ALIGN_CENTER = 1
ALIGN_RIGHT = 2

local function align(x, text, font, alignment)
	if alignment == ALIGN_CENTER then
		return x - idiv(JE_textWidth(text, font), 2)
	elseif alignment == ALIGN_RIGHT then
		return x - JE_textWidth(text, font)
	end
	return x
end

function drawFontHv(surface, x, y, text, font, hue, value)
	local highlight = false
	for i = 1, #text do
		local c = strbyte(text, i)
		local sprite_id = fontMap[c]
		if c == 32 then
			x = x + 6
		elseif c == 126 then
			highlight = not highlight
			if highlight then value = value + 4 else value = value - 4 end
		elseif sprite_id ~= -1 and sprite_exists(font, sprite_id) then
			blit_sprite_hv(surface, x, y, font, sprite_id, hue, value)
			x = x + sprite(font, sprite_id).width + 1
		end
	end
end

function drawFontHvBlend(surface, x, y, text, font, hue, value)
	for i = 1, #text do
		local c = strbyte(text, i)
		local sprite_id = fontMap[c]
		if c == 32 then
			x = x + 6
		elseif c == 126 then
		elseif sprite_id ~= -1 and sprite_exists(font, sprite_id) then
			blit_sprite_hv_blend(surface, x, y, font, sprite_id, hue, value)
			x = x + sprite(font, sprite_id).width + 1
		end
	end
end

function drawFontDark(surface, x, y, text, font, black)
	for i = 1, #text do
		local c = strbyte(text, i)
		local sprite_id = fontMap[c]
		if c == 32 then
			x = x + 6
		elseif c == 126 then
		elseif sprite_id ~= -1 and sprite_exists(font, sprite_id) then
			blit_sprite_dark(surface, x, y, font, sprite_id, black)
			x = x + sprite(font, sprite_id).width + 1
		end
	end
end

function drawFontHvShadow(surface, x, y, text, font, hue, value, black, shadowDist)
	drawFontDark(surface, x + shadowDist, y + shadowDist, text, font, black)
	drawFontHv(surface, x, y, text, font, hue, value)
end

function drawFontHvFullShadow(surface, x, y, text, font, hue, value, black, shadowDist)
	drawFontDark(surface, x, y - shadowDist, text, font, black)
	drawFontDark(surface, x + shadowDist, y, text, font, black)
	drawFontDark(surface, x, y + shadowDist, text, font, black)
	drawFontDark(surface, x - shadowDist, y, text, font, black)
	drawFontHv(surface, x, y, text, font, hue, value)
end

function drawFontHvShadowAligned(surface, x, y, text, font, alignment, hue, value, black, shadowDist)
	drawFontHvShadow(surface, align(x, text, font, alignment), y, text, font, hue, value, black, shadowDist)
end

function drawFontHvFullShadowAligned(surface, x, y, text, font, alignment, hue, value, black, shadowDist)
	drawFontHvFullShadow(surface, align(x, text, font, alignment), y, text, font, hue, value, black, shadowDist)
end

function drawFontHvAligned(surface, x, y, text, font, alignment, hue, value)
	drawFontHv(surface, align(x, text, font, alignment), y, text, font, hue, value)
end

function drawFontHvBlendAligned(surface, x, y, text, font, alignment, hue, value)
	drawFontHvBlend(surface, align(x, text, font, alignment), y, text, font, hue, value)
end

function drawFontDarkAligned(surface, x, y, text, font, alignment, black)
	drawFontDark(surface, align(x, text, font, alignment), y, text, font, black)
end
