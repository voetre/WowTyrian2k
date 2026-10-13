--[[
 WowTyrian2k: a World of Warcraft port of OpenTyrian
 Copyright (C) The OpenTyrian Development Team
 Lua port Copyright (C) 2026 voetre
 Licensed under the GNU General Public License v2 or later (see COPYING).

 file.c replacement: read-only access to game data files that were embedded
 into Lua strings by tools/convert.py.
]]
local _, ns = ...
setfenv(1, ns.G)

local strbyte, strsub = string.byte, string.sub

local FileMT = {}
FileMT.__index = FileMT

function dataFileExists(filename)
	return ns.files[filename] ~= nil
end

function dataFileOpen(filename)
	local data = ns.files[filename]
	if not data then
		return setmetatable({ data = "", pos = 0, len = 0, error = true, name = filename }, FileMT)
	end
	return setmetatable({ data = data, pos = 0, len = #data, error = false, name = filename }, FileMT)
end

function fileClose(file) end

function fileGetError(file)
	return file.error and "Unexpected end of file" or "no error"
end

function fileSetPosition(file, position)
	file.pos = position
end

function fileGetPosition(file)
	return file.pos
end

function fileGetLength(file)
	return file.len
end

function fileReadU8(file)
	local p = file.pos
	if p >= file.len then
		file.error = true
		return 0
	end
	file.pos = p + 1
	return strbyte(file.data, p + 1)
end

function fileReadS8(file)
	local v = fileReadU8(file)
	if v >= 128 then v = v - 256 end
	return v
end

function fileReadBool(file)
	return fileReadU8(file) ~= 0
end

function fileReadChar(file)
	return string.char(fileReadU8(file))
end

function fileReadU16(file)
	local p = file.pos
	if p + 2 > file.len then
		file.error = true
		file.pos = file.len
		return 0
	end
	local a, b = strbyte(file.data, p + 1, p + 2)
	file.pos = p + 2
	return a + b * 256
end

function fileReadS16(file)
	local v = fileReadU16(file)
	if v >= 32768 then v = v - 65536 end
	return v
end

function fileReadU16BE(file)
	local p = file.pos
	if p + 2 > file.len then
		file.error = true
		file.pos = file.len
		return 0
	end
	local a, b = strbyte(file.data, p + 1, p + 2)
	file.pos = p + 2
	return a * 256 + b
end

function fileReadU32(file)
	local p = file.pos
	if p + 4 > file.len then
		file.error = true
		file.pos = file.len
		return 0
	end
	local a, b, c, d = strbyte(file.data, p + 1, p + 4)
	file.pos = p + 4
	return a + b * 256 + c * 65536 + d * 16777216
end

function fileReadS32(file)
	local v = fileReadU32(file)
	if v >= 2147483648 then v = v - 4294967296 end
	return v
end

-- Reads `count` values into a 0-based array (creates it if nil).
function fileReadU8Array(file, t, count)
	t = t or {}
	for i = 0, count - 1 do t[i] = fileReadU8(file) end
	return t
end

function fileReadS8Array(file, t, count)
	t = t or {}
	for i = 0, count - 1 do t[i] = fileReadS8(file) end
	return t
end

function fileReadU16Array(file, t, count)
	t = t or {}
	for i = 0, count - 1 do t[i] = fileReadU16(file) end
	return t
end

function fileReadS16Array(file, t, count)
	t = t or {}
	for i = 0, count - 1 do t[i] = fileReadS16(file) end
	return t
end

function fileReadU16BEArray(file, t, count)
	t = t or {}
	for i = 0, count - 1 do t[i] = fileReadU16BE(file) end
	return t
end

function fileReadBoolArray(file, t, count)
	t = t or {}
	for i = 0, count - 1 do t[i] = fileReadBool(file) end
	return t
end

-- Returns the next `size` bytes as a Lua string (shorter at EOF).
function fileReadString(file, size)
	local p = file.pos
	local s = strsub(file.data, p + 1, p + size)
	if #s < size then file.error = true end
	file.pos = math.min(p + size, file.len)
	return s
end

-- Reads a fixed-size char array and returns it as a C string (up to NUL).
function fileReadCharArray(file, size)
	local s = fileReadString(file, size)
	local z = s:find("\0", 1, true)
	if z then s = strsub(s, 1, z - 1) end
	return s
end
