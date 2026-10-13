--[[
 WowTyrian2k: a World of Warcraft port of OpenTyrian
 Copyright (C) The OpenTyrian Development Team
 Lua port Copyright (C) 2026 voetre
 Licensed under the GNU General Public License v2 or later (see COPYING).
]]
local _, ns = ...
setfenv(1, ns.G)

-- Integer helpers emulating C semantics -------------------------------------

local floor, ceil = math.floor, math.ceil

band, bor, bxor, bnot = bit.band, bit.bor, bit.bxor, bit.bnot
lshift, rshift, arshift = bit.lshift, bit.rshift, bit.arshift

function trunc(x)
	if x >= 0 then return floor(x) else return ceil(x) end
end

-- C integer division (truncates toward zero)
function idiv(a, b)
	local q = a / b
	if q >= 0 then return floor(q) else return ceil(q) end
end

-- C remainder (sign follows dividend)
function cmod(a, b)
	return a - idiv(a, b) * b
end

function u8(x) return x % 256 end
function s8(x) x = x % 256; if x >= 128 then return x - 256 end return x end
function u16(x) return x % 65536 end
function s16(x) x = x % 65536; if x >= 32768 then return x - 65536 end return x end
function u32(x) return x % 4294967296 end
function s32(x) x = x % 4294967296; if x >= 2147483648 then return x - 4294967296 end return x end

-- roundf: round half away from zero
function roundf(x)
	if x >= 0 then return floor(x + 0.5) else return -floor(-x + 0.5) end
end

abs = math.abs
function MIN(a, b) if a < b then return a end return b end
function MAX(a, b) if a > b then return a end return b end

function b2n(v) if v then return 1 end return 0 end
function n2b(v) return v ~= 0 and v ~= false and v ~= nil end

M_PI = math.pi
M_PI_2 = math.pi / 2
M_PI_4 = math.pi / 4

-- Array helpers ---------------------------------------------------------------

-- Creates a 0-based array of n elements initialised to v (or v() if function).
function newArray(n, v)
	local t = {}
	if type(v) == "function" then
		for i = 0, n - 1 do t[i] = v(i) end
	else
		for i = 0, n - 1 do t[i] = v end
	end
	return t
end

function fillArray(t, n, v)
	for i = 0, n - 1 do t[i] = v end
end

function copyArray(dst, src, n)
	for i = 0, n - 1 do dst[i] = src[i] end
	return dst
end

-- Shallow copy of a struct-like table (and nested tables one level deep are
-- deep copied recursively).
function deepCopy(t)
	if type(t) ~= "table" then return t end
	local r = {}
	for k, v in pairs(t) do r[k] = deepCopy(v) end
	return r
end

-- Copies all fields of src into dst (deep), keeping dst's identity.
function structAssign(dst, src)
	for k in pairs(dst) do
		if src[k] == nil then dst[k] = nil end
	end
	for k, v in pairs(src) do
		if type(v) == "table" then
			if type(dst[k]) ~= "table" then dst[k] = {} end
			structAssign(dst[k], v)
		else
			dst[k] = v
		end
	end
	return dst
end

-- String helpers ----------------------------------------------------------------

local strbyte, strsub, strchar = string.byte, string.sub, string.char

-- atoi of the substring starting at 0-based offset `ofs`
function atoi(s, ofs)
	ofs = ofs or 0
	local str = strsub(s, ofs + 1)
	local n = str:match("^%s*([%+%-]?%d+)")
	return tonumber(n) or 0
end

-- character at 0-based index (as a 1 char string, "" past the end)
function chr(s, i)
	return strsub(s, i + 1, i + 1)
end

-- byte at 0-based index (0 past the end, like a NUL terminator)
function byteAt(s, i)
	return strbyte(s, i + 1) or 0
end

function toupperByte(c)
	if c >= 97 and c <= 122 then return c - 32 end
	return c
end

-- Truncates s to at most n-1 characters (like strlcpy into an n sized buffer)
function strlcpy(s, n)
	if #s > n - 1 then return strsub(s, 1, n - 1) end
	return s
end

sprintf = string.format
strlen = string.len

function logInfo(...) end
function logWarn(fmt, ...)
	if ns.debugLog then ns.Print("|cffffaa00warn:|r " .. sprintf(fmt, ...)) end
end
function logError(fmt, ...)
	ns.Print("|cffff4040error:|r " .. sprintf(fmt, ...))
end
function logFatal(fmt, ...)
	error(sprintf(fmt, ...), 2)
end

function assert_(cond, msg)
	if not cond and ns.debugLog then
		ns.Print("|cffff4040assert failed|r " .. (msg or "") .. "\n" .. (debugstack and debugstack(2, 3, 0) or ""))
	end
end

function ns.Print(msg)
	local p = _G_REAL.print
	p("|cff33ccffWowTyrian2k|r: " .. tostring(msg))
end
