--[[
 WowTyrian2k: a World of Warcraft port of OpenTyrian
 Copyright (C) The OpenTyrian Development Team
 Lua port Copyright (C) 2026 voetre
 Licensed under the GNU General Public License v2 or later (see COPYING).

 loudness.c / nortsong.c audio replacement.  Sound effects and pre-rendered
 music tracks are .ogg files played through the WoW sound system.
]]
local _, ns = ...
setfenv(1, ns.G)

local SOUND_PATH = "Interface\\AddOns\\WowTyrian2k\\Sound\\"

audio_disabled = false
music_disabled = false
samples_disabled = false

song_playing = -1
music_stopped = true
playing = false      -- lds_play.c "playing"
songlooped = false

tyrMusicVolume, fxVolume = 223, 223
fxPlayVol = 4
tempVolume = 0

-- Songs that do not loop in the original (end of level, game over, ...).
local nonLooping = { [9] = true, [10] = true, [18] = true, [24] = true, [30] = true, [33] = true }
local musicHandle

-- Length of one pass through each rendered song (seconds); used to detect
-- that a song has looped (lds_play.c "songlooped").
local songLength = { [0] =
	103.06, 111.80, 60.71, 115.97, 14.66, 103.08, 12.35, 33.06, 182.24, 5.57, 10.53, 57.96, 41.35, 66.23,
	41.34, 120.22, 86.60, 77.29, 5.48, 34.43, 84.65, 25.73, 96.63, 173.99, 78.46, 58.86, 38.62, 90.19,
	86.49, 113.65, 2.24, 57.96, 69.04, 7.29, 81.02, 73.65, 58.92, 132.59, 82.85, 55.21, 37.51,
}
local songStart = 0
local GetTime = _G_REAL.GetTime

function song_has_looped()
	local len = songLength[song_playing]
	return playing and len ~= nil and GetTime() - songStart >= len
end

local PlaySoundFile, StopSound, PlayMusic, StopMusic =
	_G_REAL.PlaySoundFile, _G_REAL.StopSound, _G_REAL.PlayMusic, _G_REAL.StopMusic

function init_audio() return true end
function deinit_audio() stop_song() end
function loadSndFile(xmas) end

local function stopCurrentMusic()
	if musicHandle then
		StopSound(musicHandle, 500)
		musicHandle = nil
	end
	StopMusic()
end

function play_song(song_num)
	if audio_disabled then return end
	if song_num == song_playing and not music_stopped then return end
	stopCurrentMusic()
	song_playing = song_num
	music_stopped = false
	playing = true
	songStart = GetTime()
	if music_disabled then return end
	local path = string.format("%smusic\\song%02d.ogg", SOUND_PATH, song_num)
	if nonLooping[song_num] then
		local _, handle = PlaySoundFile(path, ns.audioAcquired and "Music" or "Master")
		musicHandle = handle
	else
		PlayMusic(path)
	end
end

function restart_song()
	local s = song_playing
	song_playing = -1
	play_song(s)
end

function stop_song()
	stopCurrentMusic()
	music_stopped = true
	playing = false
end

function fade_song()
	stop_song()
end

-- WoW cannot set the volume of a single sound.  While the game window is
-- open (and the "use the game's volume levels" option is on) the WoW music
-- and effects volume CVars are set to the game's levels; the player's own
-- values are kept in the saved variables and restored when the window
-- closes, or at the next login if the client did not shut down cleanly.
local curMusicVolume, curFxVolume = 223, 223
local AUDIO_CVARS = { "Sound_MusicVolume", "Sound_SFXVolume" }
local GetCVar = (_G_REAL.C_CVar and _G_REAL.C_CVar.GetCVar) or _G_REAL.GetCVar
local SetCVar = (_G_REAL.C_CVar and _G_REAL.C_CVar.SetCVar) or _G_REAL.SetCVar
ns.audioAcquired = false

local function applyVolume()
	if not ns.audioAcquired then return end
	SetCVar("Sound_MusicVolume", string.format("%.3f", curMusicVolume / 255))
	SetCVar("Sound_SFXVolume", string.format("%.3f", curFxVolume / 255))
end

function set_volume(musicVolume, sampleVolume)
	curMusicVolume, curFxVolume = musicVolume, sampleVolume
	applyVolume()
end

function ns.acquireAudio()
	if ns.audioAcquired or not (ns.options and ns.options.controlVolume) or not GetCVar or not SetCVar then return end
	local saved = {}
	for _, cv in ipairs(AUDIO_CVARS) do saved[cv] = GetCVar(cv) end
	ns.db.savedCVars = saved
	ns.audioAcquired = true
	applyVolume()
	-- move a playing one-shot song onto the music channel
	if musicHandle and not music_stopped then restart_song() end
end

function ns.releaseAudio()
	if not ns.audioAcquired then return end
	ns.audioAcquired = false
	ns.restoreAudioCVars()
end

function ns.restoreAudioCVars()
	local saved = ns.db and ns.db.savedCVars
	if not saved or not SetCVar then return end
	for cv, v in pairs(saved) do SetCVar(cv, v) end
	ns.db.savedCVars = nil
end

-- One sound per channel, like the original mixer.
sfxPath = {}
for n = 1, 38 do
	sfxPath[n] = {}
	for _, v in ipairs({ 1, 2, 4 }) do
		sfxPath[n][v] = string.format("%ssfx\\sfx%02d_v%d.ogg", SOUND_PATH, n, v)
	end
end
local channelHandles = {}
local channelLast = {}
local GetTimePreciseSec = _G_REAL.GetTimePreciseSec or _G_REAL.GetTime

function multiSamplePlay(sampleNum, chan, vol)
	if audio_disabled or samples_disabled or not sampleNum or sampleNum < 1 then return end
	local now = GetTimePreciseSec and GetTimePreciseSec() or 0
	local last = channelLast[chan]
	if last and last.num == sampleNum and now - last.t < 0.08 then
		-- the same sound restarted almost immediately: let it keep playing
		return
	end
	local h = channelHandles[chan]
	if h then StopSound(h, 60) end
	-- pre-mixed at the original's channel volume levels (see tools/make_sfx.py)
	local v = (vol >= 4) and 4 or ((vol >= 2) and 2 or 1)
	local _, handle = PlaySoundFile(sfxPath[sampleNum][v], ns.audioAcquired and "SFX" or "Master")
	channelHandles[chan] = handle
	channelLast[chan] = { num = sampleNum, t = now }
end

function JE_playSampleNum(samplenum)
	multiSamplePlay(samplenum, 0, fxPlayVol)
end

function JE_changeVolume(music, music_delta, sample, sample_delta)
	local music_temp, sample_temp = music + music_delta, sample + sample_delta
	if music_delta ~= 0 then
		if music_temp > 255 then music_temp = 255; JE_playSampleNum(S_CLINK)
		elseif music_temp < 0 then music_temp = 0; JE_playSampleNum(S_CLINK) end
	end
	if sample_delta ~= 0 then
		if sample_temp > 255 then sample_temp = 255; JE_playSampleNum(S_CLINK)
		elseif sample_temp < 0 then sample_temp = 0; JE_playSampleNum(S_CLINK) end
	end
	set_volume(music_temp, sample_temp)
	return music_temp, sample_temp
end
