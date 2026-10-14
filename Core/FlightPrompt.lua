--[[
 WowTyrian2k: a World of Warcraft port of OpenTyrian
 Lua port Copyright (C) 2026 voetre
 Licensed under the GNU General Public License v2 or later (see COPYING).

 Flight path mode prompt (new for this port).  Once the player is on a
 flight, a small toast near the top of the screen counts the flight down and
 offers a game.  Yes generates a timed level that ends a little before the
 landing (LevelGen.beginTest); No dismisses it.  When too little flight is
 left for the shortest timed level, the toast fades away by itself.  It
 never takes the keyboard.
 /tyrian flighttest <duration> fakes a flight of that length to try it out.
]]
local _, ns = ...
setfenv(1, ns.G)

local _G = _G_REAL
local floor = math.floor

local FlightPrompt = {}
ns.FlightPrompt = FlightPrompt

local FADE = 1.5       -- seconds to fade out
local TICK = 0.25      -- seconds between timer updates

local toast, flight, fading, tick

local function timedLevelRunning()
	return (bonusRun or genLevel and genLevel.seconds) and ns.root and ns.root:IsShown()
end

local function opt(k, default)
	local v = ns.options and ns.options[k]
	if v == nil then return default end
	return v
end

-- Shortest level offered (the "shortest game" option, at least the
-- generator's own minimum).
local function minSeconds()
	return math.max(LevelGen.MIN_SECONDS, opt("flightMinLevel", LevelGen.MIN_SECONDS))
end

-- Seconds a level started now could last, or nil if the flight is too short.
local function levelSeconds()
	local s = floor(ns.Flight.remaining() - LevelGen.landMargin())
	if s >= minSeconds() then return s end
end

local function fadeOut(why)
	if not toast or not toast:IsShown() or fading then return end
	fading = 0
	if why then toast.ask:SetText(why) end
	toast.yes:Disable()
	toast.no:Disable()
end

local function hide()
	fading, flight = nil, nil
	if toast then toast:Hide() end
end

local function update()
	local c = ns.Flight.current
	if c ~= flight then
		-- landed, or another flight replaced this one
		if not c then toast.time:SetText("landed") end
		fadeOut()
		return
	end
	local left = ns.Flight.remaining()
	if c.test and left <= 0 then
		-- a test flight "lands"
		ns.Flight.current = nil
	end
	toast.time:SetText(LevelGen.clockText(math.ceil(left)))
	toast.bar:SetWidth(math.max(1, toast.barBack:GetWidth() * (1 - left / c.eta)))
	local s = levelSeconds()
	if s then
		toast.ask:SetText("Play Tyrian?  (" .. LevelGen.clockText(s) .. " level)")
	else
		fadeOut("Not enough flight left for a game")
	end
end

local function onUpdate(self, elapsed)
	if fading then
		fading = fading + elapsed
		if fading >= FADE then hide() else self:SetAlpha(1 - fading / FADE) end
		return
	end
	tick = tick + elapsed
	if tick >= TICK then
		tick = 0
		update()
	end
end

local function accept()
	local c = flight
	local s = c and ns.Flight.current == c and levelSeconds()
	hide()
	if not s then return end
	local req = c.req or {}
	local theme = opt("flightTheme", "random")
	ns.playGenLevel({ name = req.name or (theme ~= "random" and theme or nil), seed = req.seed, seconds = s })
end

local function button(parent, text, onClick)
	local b = _G.CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetSize(64, 22)
	b:SetText(text)
	b:SetScript("OnClick", onClick)
	return b
end

local function create()
	local f = _G.CreateFrame("Frame", "WowTyrian2kFlightToast", _G.UIParent, "BackdropTemplate")
	f:SetSize(260, 86)
	f:SetPoint("TOP", 0, -120)
	f:SetFrameStrata("DIALOG")
	f:SetClampedToScreen(true)
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	f:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 },
	})
	f:SetBackdropColor(0, 0, 0, 0.85)

	f.dest = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	f.dest:SetPoint("TOPLEFT", 12, -10)
	f.dest:SetPoint("RIGHT", -60, 0)
	f.dest:SetJustifyH("LEFT")
	f.dest:SetWordWrap(false)
	f.time = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	f.time:SetPoint("TOPRIGHT", -12, -10)

	f.barBack = f:CreateTexture(nil, "ARTWORK")
	f.barBack:SetColorTexture(0.2, 0.2, 0.2, 1)
	f.barBack:SetPoint("TOPLEFT", 12, -28)
	f.barBack:SetPoint("TOPRIGHT", -12, -28)
	f.barBack:SetHeight(4)
	f.bar = f:CreateTexture(nil, "OVERLAY")
	f.bar:SetColorTexture(1, 0.82, 0, 1)
	f.bar:SetPoint("TOPLEFT", f.barBack)
	f.bar:SetHeight(4)
	f.bar:SetWidth(1)

	f.ask = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	f.ask:SetPoint("TOPLEFT", 12, -38)
	f.ask:SetPoint("RIGHT", -12, 0)
	f.ask:SetJustifyH("LEFT")

	f.yes = button(f, "Yes", accept)
	f.yes:SetPoint("BOTTOMRIGHT", f, "BOTTOM", -4, 10)
	f.no = button(f, "No", hide)
	f.no:SetPoint("BOTTOMLEFT", f, "BOTTOM", 4, 10)

	f:SetScript("OnUpdate", onUpdate)
	f:Hide()
	return f
end

-- Offers a game for flight c (ns.Flight.current).
-- With the "on flight start" option at "start", the level starts at once
-- instead.
function FlightPrompt.show(c)
	local mode = opt("flightMode", "ask")
	if not c or mode == "off" then return end
	if timedLevelRunning() then
		if c.test then ns.Print("A timed level is already running.") end
		return
	end
	flight = c
	if not levelSeconds() then
		flight = nil
		if c.test then
			ns.Print(sprintf("Flight too short for a game: needs at least %s.",
				LevelGen.clockText(minSeconds() + LevelGen.landMargin())))
		end
		return
	end
	if mode == "start" then
		accept()
		return
	end
	toast = toast or create()
	fading, tick = nil, TICK
	toast.dest:SetText("Flight to " .. (c.dest or "?"))
	toast.yes:Enable()
	toast.no:Enable()
	toast:SetAlpha(1)
	toast:Show()
	update()
end

ns.Flight.onBoarded = FlightPrompt.show

-- A pretend flight of `seconds`; req = { name, seed } picks the level theme.
function FlightPrompt.startTest(seconds, req)
	local c = { start = _G.GetTime(), eta = seconds, how = "test", dest = "Test flight", test = true, req = req }
	ns.Flight.current = c
	ns.Print(sprintf("Test flight: %s.  /tyrian flighttest stop ends it.", LevelGen.clockText(seconds)))
	FlightPrompt.show(c)
end

function FlightPrompt.stopTest()
	local c = ns.Flight.current
	if c and c.test then
		ns.Flight.current = nil
		ns.Print("Test flight ended.")
	else
		ns.Print("No test flight.")
	end
	if toast and toast:IsShown() then update() end
end
