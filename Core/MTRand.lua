--[[
 WowTyrian2k: Mersenne Twister (port of mtrand.c, Copyright (C) 1997 - 2002,
 Makoto Matsumoto and Takuji Nishimura, BSD licensed).
]]
local _, ns = ...
setfenv(1, ns.G)

local band, bxor, rshift, lshift = bit.band, bit.bxor, bit.rshift, bit.lshift
local N, M = 624, 397
local MATRIX_A = 0x9908b0df

local function u(x) return x % 4294967296 end

-- 32-bit unsigned multiply modulo 2^32 (operands < 2^32)
local function mul32(a, b)
	local al, ah = a % 65536, (a - a % 65536) / 65536
	local lo = al * b
	local hi = (ah * b) % 65536
	return (lo + hi * 65536) % 4294967296
end

local mt = {}
local p0, p1, pm

MT_RAND_MAX = 0xffffffff

function mt_srand(s)
	mt[0] = u(s)
	for i = 1, N - 1 do
		local prev = mt[i - 1]
		mt[i] = u(mul32(1812433253, u(bxor(prev, rshift(prev, 30)))) + i)
	end
	p0, p1, pm = 0, 1, M
end

function mt_rand()
	if not p0 then mt_srand(5489) end
	local x0, x1 = mt[p0], mt[p1]
	local y = u(bor(band(x0, 0x80000000), band(x1, 0x7fffffff)))
	local v = bxor(mt[pm], rshift(y, 1))
	if band(x1, 1) ~= 0 then v = bxor(v, MATRIX_A) end
	y = u(v)
	mt[p0] = y
	p0 = p1
	p1 = p1 + 1
	pm = pm + 1
	if pm == N then pm = 0 end
	if p1 == N then p1 = 0 end

	y = bxor(y, rshift(y, 11))
	y = bxor(y, band(lshift(y, 7), 0x9d2c5680))
	y = bxor(y, band(lshift(y, 15), 0xefc60000))
	y = bxor(y, rshift(y, 18))
	return u(y)
end

function mt_rand_1()
	return mt_rand() / MT_RAND_MAX
end

function mt_rand_lt1()
	return mt_rand() / (MT_RAND_MAX + 1.0)
end
