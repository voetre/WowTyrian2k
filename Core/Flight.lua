--[[
 WowTyrian2k: a World of Warcraft port of OpenTyrian
 Lua port Copyright (C) 2026 voetre
 Licensed under the GNU General Public License v2 or later (see COPYING).

 Flight path timing (new for this port), groundwork for flight path mode.
 When the player takes a flight, estimate how long it lasts, from the best
 source available:
   1. the player's own recorded time for the exact route (saved per
      continent, keyed by the route's flight master positions, hops included)
   2. Flight Timer Classic's times (Core/FlightData.lua, CC BY 2.0)
   3. a model fitted to known flight times: seconds per unit of route length
      on the flight map, per hop and a constant, per continent
 Every completed flight is recorded, so estimates improve with use.  Only the
 Classic continents are modelled.
]]
local _, ns = ...
setfenv(1, ns.G)

local _G = _G_REAL
local floor, sqrt, format = math.floor, math.sqrt, string.format

local Flight = {}
ns.Flight = Flight

-- seconds = perUnit * route length + perHop * hops + base
local MODEL = {
	[1415] = { perUnit = 1099.9, perHop = -18.7, base = 13.5 },   -- Eastern Kingdoms
	[1414] = { perUnit = 1153.5, perHop = -18.4, base = 25.7 },   -- Kalimdor
}
local MODEL_DEFAULT = { perUnit = 1125, perHop = -18.5, base = 20 }

-- Flight Timer Classic keys are floor(x * 1e8); the closest flight masters
-- are 16708 apart, so allow a little less than a third of that either way.
local KEY_TOLERANCE = 5000

local function ftcKey(x) return floor(x * 100000000) end

-- Closest key in `keys` (an iterator of numbers) to `want`, within tolerance.
local function nearest(want, best, key)
	local d = key - want
	if d < 0 then d = -d end
	if d <= KEY_TOLERANCE and (not best or d < best.d) then return { k = key, d = d } end
	return best
end

-- Flight Timer Classic time from position x0 to x1, or nil.
function Flight.ftcTime(faction, x0, x1)
	local data = ns.flightData and ns.flightData[faction]
	if not data then return nil end
	local want0, want1 = ftcKey(x0), ftcKey(x1)
	local src
	for k in pairs(data) do src = nearest(want0, src, k) end
	if not src then return nil end
	local lst, dst = data[src.k], nil
	for i = 1, #lst, 2 do
		local b = nearest(want1, dst, lst[i])
		if b ~= dst then dst = b; dst.t = lst[i + 1] end
	end
	return dst and dst.t
end

-- Model estimate for a route given as a list of {x, y} points.
function Flight.modelTime(mapID, pts)
	local m = MODEL[mapID] or MODEL_DEFAULT
	local len = 0
	for i = 2, #pts do
		local dx, dy = pts[i][1] - pts[i - 1][1], pts[i][2] - pts[i - 1][2]
		len = len + sqrt(dx * dx + dy * dy)
	end
	local t = m.perUnit * len + m.perHop * (#pts - 1) + m.base
	return t < 10 and 10 or floor(t + 0.5)
end

local function routeKey(pts)
	local parts = {}
	for i, p in ipairs(pts) do parts[i] = format("%.4f:%.4f", p[1], p[2]) end
	return table.concat(parts, ":")
end

local function recorded(mapID)
	local db = ns.db
	if not db then return nil end
	db.flights = db.flights or {}
	local t = db.flights[mapID or 0]
	if not t then
		t = {}
		db.flights[mapID or 0] = t
	end
	return t
end

-- The route to taxi node `dest` on the open flight map: the points of the
-- current node, every hop and the destination.
local function routePoints(dest)
	local pts = {}
	for i = 1, _G.NumTaxiNodes() do
		if _G.TaxiNodeGetType(i) == "CURRENT" then
			pts[1] = { _G.TaxiNodePosition(i) }
			break
		end
	end
	if not pts[1] then return nil end
	local hops = _G.GetNumRoutes(dest) or 0
	for h = 2, hops + 1 do
		pts[#pts + 1] = { _G.TaxiNodePosition(_G.TaxiGetNodeSlot(dest, h, true)) }
	end
	local x, y = _G.TaxiNodePosition(dest)
	local last = pts[#pts]
	if #pts == 1 or format("%.4f:%.4f", last[1], last[2]) ~= format("%.4f:%.4f", x, y) then
		pts[#pts + 1] = { x, y }
	end
	return pts
end

-- Estimated seconds for a flight to taxi node `dest` (the flight map must
-- be open), and where the estimate came from: "recorded", "ftc" or "model".
function Flight.estimate(dest)
	local pts = routePoints(dest)
	if not pts or #pts < 2 then return nil end
	local mapID = _G.GetTaxiMapID and _G.GetTaxiMapID() or 0
	local key = routeKey(pts)
	local rec = recorded(mapID)
	if rec and rec[key] then return rec[key], "recorded", mapID, key end
	local faction = _G.UnitFactionGroup("player")
	local t = Flight.ftcTime(faction, pts[1][1], pts[#pts][1])
	if t then return t, "ftc", mapID, key end
	return Flight.modelTime(mapID, pts), "model", mapID, key
end

-- The flight in progress (nil when not flying): start (GetTime), eta in
-- seconds, dest name, source of the estimate.
Flight.current = nil

-- Seconds left on the current flight, or nil.
function Flight.remaining()
	local c = Flight.current
	if not c then return nil end
	local left = c.eta - (_G.GetTime() - c.start)
	return left > 0 and left or 0
end

local SOURCES = { recorded = "your last flight", ftc = "Flight Timer Classic data", model = "estimate" }

local watcher = _G.CreateFrame("Frame")

local function landed()
	local c = Flight.current
	Flight.current = nil
	watcher:UnregisterEvent("PLAYER_CONTROL_GAINED")
	if not c or not c.boarded then return end
	local secs = floor(_G.GetTime() - c.start + 0.5)
	-- ignore cancelled flights and anything absurd
	if secs >= 10 and secs <= 3600 then
		local rec = recorded(c.mapID)
		if rec then rec[c.key] = secs end
		if ns.db and ns.db.flightInfo ~= false then
			ns.Print(format("Flight to %s took %d:%02d (estimated %d:%02d from %s).",
				c.dest, floor(secs / 60), secs % 60, floor(c.eta / 60), c.eta % 60, SOURCES[c.how]))
		end
	end
end

watcher:SetScript("OnEvent", function(self, event)
	if event == "PLAYER_CONTROL_GAINED" then landed() end
end)

local function takeoff(dest)
	local ok, eta, how, mapID, key = pcall(Flight.estimate, dest)
	if not ok or not eta then return end
	local name = (_G.TaxiNodeName(dest) or "?"):match("^[^,]*")
	Flight.current = { start = _G.GetTime(), eta = eta, how = how, mapID = mapID, key = key, dest = name }
	local c = Flight.current
	-- the flight only counts once the player is actually on the taxi
	local waited = 0
	watcher:SetScript("OnUpdate", function(self, elapsed)
		waited = waited + elapsed
		if Flight.current ~= c then
			self:SetScript("OnUpdate", nil)
		elseif _G.UnitOnTaxi("player") then
			c.boarded = true
			self:RegisterEvent("PLAYER_CONTROL_GAINED")
			self:SetScript("OnUpdate", nil)
			if Flight.onBoarded then Flight.onBoarded(c) end
		elseif waited > 5 then
			Flight.current = nil
			self:SetScript("OnUpdate", nil)
		end
	end)
	if ns.db and ns.db.flightInfo ~= false then
		ns.Print(format("Flight to %s: about %d:%02d (%s).", name, floor(eta / 60), eta % 60, SOURCES[how]))
	end
end

if _G.hooksecurefunc and _G.TakeTaxiNode then
	_G.hooksecurefunc("TakeTaxiNode", takeoff)
end
