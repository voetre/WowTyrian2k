--[[
 WowTyrian2k: a World of Warcraft port of OpenTyrian
 Copyright (C) The OpenTyrian Development Team
 Lua port Copyright (C) 2026 voetre
 Licensed under the GNU General Public License v2 or later (see COPYING).

 keyboard.c + nortsong.c timing replacement.

 The game runs inside a coroutine.  Every function that would block in the
 original (waiting for time or input) yields back to the WoW client instead;
 the OnUpdate handler resumes the coroutine each client frame.
]]
local _, ns = ...
setfenv(1, ns.G)

local floor = math.floor

-- SDL scancodes (only the ones the game cares about) ----------------------------

SDL_SCANCODE_UNKNOWN = 0
SDL_SCANCODE_A = 4
SDL_SCANCODE_C = 6
SDL_SCANCODE_P = 19
SDL_SCANCODE_W = 26
SDL_SCANCODE_1 = 30
SDL_SCANCODE_2 = 31
SDL_SCANCODE_9 = 38
SDL_SCANCODE_0 = 39
SDL_SCANCODE_BACKSLASH = 49
SDL_SCANCODE_SLASH = 56
SDL_SCANCODE_CAPSLOCK = 57
SDL_SCANCODE_NUMLOCKCLEAR = 83
SDL_SCANCODE_RETURN = 40
SDL_SCANCODE_ESCAPE = 41
SDL_SCANCODE_BACKSPACE = 42
SDL_SCANCODE_TAB = 43
SDL_SCANCODE_SPACE = 44
SDL_SCANCODE_MINUS = 45
SDL_SCANCODE_EQUALS = 46
SDL_SCANCODE_F1 = 58
SDL_SCANCODE_F2 = 59
SDL_SCANCODE_F3 = 60
SDL_SCANCODE_F4 = 61
SDL_SCANCODE_F5 = 62
SDL_SCANCODE_F6 = 63
SDL_SCANCODE_F7 = 64
SDL_SCANCODE_F8 = 65
SDL_SCANCODE_F9 = 66
SDL_SCANCODE_F10 = 67
SDL_SCANCODE_F11 = 68
SDL_SCANCODE_F12 = 69
SDL_SCANCODE_SCROLLLOCK = 71
SDL_SCANCODE_PAUSE = 72
SDL_SCANCODE_INSERT = 73
SDL_SCANCODE_HOME = 74
SDL_SCANCODE_PAGEUP = 75
SDL_SCANCODE_DELETE = 76
SDL_SCANCODE_END = 77
SDL_SCANCODE_PAGEDOWN = 78
SDL_SCANCODE_RIGHT = 79
SDL_SCANCODE_LEFT = 80
SDL_SCANCODE_DOWN = 81
SDL_SCANCODE_UP = 82
SDL_SCANCODE_KP_ENTER = 88
SDL_SCANCODE_KP_PLUS = 87
SDL_SCANCODE_KP_MINUS = 86
SDL_SCANCODE_LCTRL = 224
SDL_SCANCODE_LSHIFT = 225
SDL_SCANCODE_LALT = 226
SDL_SCANCODE_RCTRL = 228
SDL_SCANCODE_RSHIFT = 229
SDL_SCANCODE_RALT = 230
SDL_NUM_SCANCODES = 512

KMOD_NONE = 0
KMOD_LSHIFT = 0x0001
KMOD_RSHIFT = 0x0002
KMOD_LCTRL = 0x0040
KMOD_RCTRL = 0x0080
KMOD_LALT = 0x0100
KMOD_RALT = 0x0200
KMOD_SHIFT = 0x0003
KMOD_CTRL = 0x00C0
KMOD_ALT = 0x0300

SDL_BUTTON_LEFT = 1
SDL_BUTTON_MIDDLE = 2
SDL_BUTTON_RIGHT = 3
SDL_BUTTON_LMASK = 1
SDL_BUTTON_MMASK = 2
SDL_BUTTON_RMASK = 4

INPUT_ANY = 0
INPUT_NO_MOTION = 1

-- WoW key name -> SDL scancode
local keyMap = {
	UP = SDL_SCANCODE_UP, DOWN = SDL_SCANCODE_DOWN, LEFT = SDL_SCANCODE_LEFT, RIGHT = SDL_SCANCODE_RIGHT,
	SPACE = SDL_SCANCODE_SPACE, ENTER = SDL_SCANCODE_RETURN, ESCAPE = SDL_SCANCODE_ESCAPE,
	BACKSPACE = SDL_SCANCODE_BACKSPACE, TAB = SDL_SCANCODE_TAB,
	LCTRL = SDL_SCANCODE_LCTRL, RCTRL = SDL_SCANCODE_RCTRL,
	LALT = SDL_SCANCODE_LALT, RALT = SDL_SCANCODE_RALT,
	LSHIFT = SDL_SCANCODE_LSHIFT, RSHIFT = SDL_SCANCODE_RSHIFT,
	INSERT = SDL_SCANCODE_INSERT, HOME = SDL_SCANCODE_HOME, PAGEUP = SDL_SCANCODE_PAGEUP,
	DELETE = SDL_SCANCODE_DELETE, END = SDL_SCANCODE_END, PAGEDOWN = SDL_SCANCODE_PAGEDOWN,
	PAUSE = SDL_SCANCODE_PAUSE, SCROLLLOCK = SDL_SCANCODE_SCROLLLOCK,
	NUMPADPLUS = SDL_SCANCODE_KP_PLUS, NUMPADMINUS = SDL_SCANCODE_KP_MINUS,
	["-"] = SDL_SCANCODE_MINUS, ["="] = SDL_SCANCODE_EQUALS,
	["["] = 47, ["]"] = 48, [";"] = 51, ["`"] = 53, [","] = 54, ["."] = 55,
	["\\"] = SDL_SCANCODE_BACKSLASH, ["/"] = SDL_SCANCODE_SLASH, CAPSLOCK = SDL_SCANCODE_CAPSLOCK,
	NUMLOCK = SDL_SCANCODE_NUMLOCKCLEAR,
	NUMPAD0 = 98, NUMPAD1 = 89, NUMPAD2 = 90, NUMPAD3 = 91, NUMPAD4 = 92,
	NUMPAD5 = 93, NUMPAD6 = 94, NUMPAD7 = 95, NUMPAD8 = 96, NUMPAD9 = 97,
}
for i = 1, 12 do keyMap["F" .. i] = SDL_SCANCODE_F1 + i - 1 end
for i = 0, 25 do keyMap[string.char(65 + i)] = SDL_SCANCODE_A + i end
for i = 1, 9 do keyMap[tostring(i)] = 30 + i - 1 end
keyMap["0"] = 39

-- WoW key name -> SDL keycode (sym)
local symMap = {
	SPACE = 32, ENTER = 13, ESCAPE = 27, BACKSPACE = 8, TAB = 9,
	["-"] = 45, ["="] = 61, ["["] = 91, ["]"] = 93, [";"] = 59, ["'"] = 39, [","] = 44, ["."] = 46, ["/"] = 47, ["\\"] = 92, ["`"] = 96,
}
for i = 0, 25 do symMap[string.char(65 + i)] = 97 + i end
for i = 0, 9 do symMap[tostring(i)] = 48 + i end

function SDL_GetScancodeName(sc)
	for k, v in pairs(keyMap) do
		if v == sc then return k end
	end
	return ""
end

ESCPressed = false
windowHasFocus = true

keysactive = newArray(SDL_NUM_SCANCODES, false)

lordKeySymsDown = { [0] = false, false, false, false }
local lordKeySyms = { [0] = 108, 111, 114, 100 } -- l o r d

mouseX, mouseY = 0, 0
mouseButtonsDown = 0
mouseInactive = true

local keyboardInputs = {}
local mouseInputs = {}
local mouseHasMotionInput = false
local mouseRelativeEnabled = false
local mouseRelX, mouseRelY = 0, 0

local function modState()
	local m = 0
	if IsShiftKeyDown() then m = bor(m, KMOD_LSHIFT) end
	if IsControlKeyDown() then m = bor(m, KMOD_LCTRL) end
	if IsAltKeyDown() then m = bor(m, KMOD_LALT) end
	return m
end

function ns.onKeyDown(key)
	local sc = keyMap[key] or SDL_SCANCODE_UNKNOWN
	local sym = symMap[key] or -1
	keysactive[sc] = true
	for i = 0, 3 do
		if sym == lordKeySyms[i] then lordKeySymsDown[i] = true end
	end
	if #keyboardInputs < 32 then
		keyboardInputs[#keyboardInputs + 1] = { sym = sym, scancode = sc, mod = modState(), ch = 0 }
	end
	mouseInactive = true
end

function ns.onKeyUp(key)
	local sc = keyMap[key] or SDL_SCANCODE_UNKNOWN
	local sym = symMap[key] or -1
	keysactive[sc] = false
	for i = 0, 3 do
		if sym == lordKeySyms[i] then lordKeySymsDown[i] = false end
	end
end

function ns.onChar(text)
	local ch = string.byte(text)
	if ch and ch < 128 and #keyboardInputs < 32 then
		keyboardInputs[#keyboardInputs + 1] = { sym = -1, scancode = -1, mod = KMOD_NONE, ch = ch }
	end
end

function ns.onMouseDown(button, x, y)
	if #mouseInputs < 4 then
		mouseInputs[#mouseInputs + 1] = { button = button, x = x, y = y }
	end
	mouseButtonsDown = bor(mouseButtonsDown, lshift(1, button - 1))
	mouseInactive = false
end

function ns.onMouseUp(button)
	mouseButtonsDown = band(mouseButtonsDown, bnot(lshift(1, button - 1)))
end

function ns.onMouseMove(x, y, dx, dy, silent)
	if silent then
		mouseX, mouseY = x, y
		return
	end
	if x ~= mouseX or y ~= mouseY then
		mouseHasMotionInput = true
		mouseInactive = false
	end
	mouseX, mouseY = x, y
	if mouseRelativeEnabled then
		mouseRelX = mouseRelX + dx
		mouseRelY = mouseRelY + dy
	end
end

-- Releases all keys (used when the window loses keyboard focus).
function ns.releaseAllKeys()
	for i = 0, SDL_NUM_SCANCODES - 1 do keysactive[i] = false end
	for i = 0, 3 do lordKeySymsDown[i] = false end
	mouseButtonsDown = 0
end

function keyboardHasInput()
	return #keyboardInputs > 0
end

-- Returns the next KeyboardInput table (or nil).  C callers that pass NULL
-- just test the result.
function keyboardGetInput()
	if #keyboardInputs > 0 then
		return table.remove(keyboardInputs, 1)
	end
	return nil
end

function keyboardClearInput()
	keyboardInputs = {}
end

function mouseHasInput(flags)
	return #mouseInputs > 0 or (band(flags, INPUT_NO_MOTION) == 0 and mouseHasMotionInput)
end

function mouseGetInput(flags)
	if #mouseInputs > 0 then
		return table.remove(mouseInputs, 1)
	end
	if band(flags, INPUT_NO_MOTION) == 0 and mouseHasMotionInput then
		mouseHasMotionInput = false
		return { x = mouseX, y = mouseY, button = 0 }
	end
	return nil
end

function mouseClearInput()
	mouseInputs = {}
	mouseHasMotionInput = false
end

function mouseSetRelative(enable)
	mouseRelativeEnabled = enable
	mouseRelX, mouseRelY = 0, 0
end

function mouseGetRelativePosition()
	local x, y = mouseRelX, mouseRelY
	mouseRelX, mouseRelY = 0, 0
	return x, y
end

function handleSdlEvents()
	-- Events are delivered by WoW frame scripts; nothing to poll.
end

function hasInput(flags)
	return keyboardHasInput() or mouseHasInput(flags)
end

function getInput()
	return keyboardGetInput() ~= nil or mouseGetInput(INPUT_NO_MOTION) ~= nil
end

-- Timing (nortsong.c) --------------------------------------------------------------

local GetTimePreciseSec = _G_REAL.GetTimePreciseSec or _G_REAL.GetTime

function SDL_GetTicks()
	return floor(GetTimePreciseSec() * 1000)
end

frameCountMax = 0

local frameSpeed = 0x4300
-- frame period in milliseconds (float)
local framePeriod = 0x4300 * 1000 * 88 * 3 / 315000000
local frameCountEnd = 0
local frameCount2End = 0

local function nowMs()
	return GetTimePreciseSec() * 1000
end

function setFrameSpeed(speed)
	frameSpeed = speed
	framePeriod = speed * 1000 * 88 * 3 / 315000000
	frameCountEnd = nowMs()
end

-- The original resynchronises the timer as soon as it is one tick late.  A
-- WoW client frame can be longer than a game tick, so allow catching up on
-- a few ticks of lag before resynchronising.
local CATCHUP_MS = 120

function setFrameCount(frameCount)
	local now = nowMs()
	local diff = now - frameCountEnd
	ns.perfTicks = (ns.perfTicks or 0) + 1
	if diff >= CATCHUP_MS then
		-- too far behind: the lost time is dropped (the game slows down)
		ns.perfResyncs = (ns.perfResyncs or 0) + 1
		frameCountEnd = now - (diff % framePeriod)
	elseif -diff >= framePeriod then
		frameCountEnd = now + ((-diff) % framePeriod)
	end
	frameCountEnd = frameCountEnd + frameCount * framePeriod
end

-- Length of one game tick in seconds at the current game speed.
function tickSeconds()
	return framePeriod * (frameCountMax > 0 and frameCountMax or 1) / 1000
end

function setFrameCount2(frameCount2)
	local now = nowMs()
	local diff = now - frameCount2End
	if diff >= framePeriod then
		frameCount2End = now - (diff % framePeriod)
	elseif -diff >= framePeriod then
		frameCount2End = now + ((-diff) % framePeriod)
	end
	frameCount2End = frameCount2End + frameCount2 * framePeriod
end

function getFrameCountTicks()
	local diff = frameCountEnd - nowMs()
	if diff >= 0 then return floor(diff + 0.5) end
	return 0
end

function getFrameCount2Ticks()
	local diff = frameCount2End - nowMs()
	if diff >= 0 then return floor(diff + 0.5) end
	return 0
end

-- Coroutine plumbing ----------------------------------------------------------------

local yield = coroutine.yield

function ns.yieldFrame()
	ns.resetShowCount()
	yield()
end

function delayUntilElapsed()
	while getFrameCountTicks() > 0 do
		ns.yieldFrame()
	end
end

function SDL_Delay(ms)
	local untilMs = nowMs() + ms
	repeat
		ns.yieldFrame()
	until nowMs() >= untilMs
end

function waitUntilHasInput(flags)
	while true do
		if hasInput(flags) then return end
		ns.yieldFrame()
	end
end

function waitUntilGetInput()
	while true do
		if getInput() then return end
		ns.yieldFrame()
	end
end

function waitUntilElapsed()
	while true do
		if getFrameCountTicks() == 0 then return end
		ns.yieldFrame()
	end
end

function waitUntilHasInputOrElapsed()
	while true do
		if hasInput(INPUT_NO_MOTION) then return true end
		if getFrameCountTicks() == 0 then return false end
		ns.yieldFrame()
	end
end

function waitUntilGetInputOrElapsed()
	while true do
		if getInput() then return true end
		if getFrameCountTicks() == 0 then return false end
		ns.yieldFrame()
	end
end
