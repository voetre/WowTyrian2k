--[[
 WowTyrian2k: a World of Warcraft port of OpenTyrian
 Lua port Copyright (C) 2026 voetre
 Licensed under the GNU General Public License v2 or later (see COPYING).

 The minimap button, through LibDataBroker and LibDBIcon so minimap button
 addons can manage it: left-click plays (the same as /tyrian), right-click
 opens the options, drag to move it.  The icon is the USP Talon, the ship
 the game starts you with (tools/make_icon.py).
]]
local addonName, ns = ...
local _G = _G

local ICON = "Interface\\AddOns\\WowTyrian2k\\Textures\\icon"

local LibStub = _G.LibStub
local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
local DBIcon = LibStub and LibStub("LibDBIcon-1.0", true)

local launcher = LDB and LDB:NewDataObject(addonName, {
	type = "launcher",
	label = "WowTyrian2k",
	text = "WowTyrian2k",
	icon = ICON,
	OnClick = function(_, which)
		if which == "RightButton" then ns.openOptions() else ns.Toggle() end
	end,
	OnTooltipShow = function(tt)
		tt:AddLine("WowTyrian2k")
		tt:AddLine("Left-click: play or hide Tyrian", 1, 1, 1)
		tt:AddLine("Right-click: options", 1, 1, 1)
		tt:AddLine("Drag: move this button", 1, 1, 1)
	end,
})

-- ns.db.minimap is LibDBIcon's saved state: hide, minimapPos (degrees).
function ns.minimapInit()
	ns.db.minimap = ns.db.minimap or { hide = false, minimapPos = 220 }
	if DBIcon and launcher and not DBIcon:IsRegistered(addonName) then
		DBIcon:Register(addonName, launcher, ns.db.minimap)
	end
end

function ns.setMinimapButton(on)
	ns.db.minimap.hide = not on
	if not DBIcon or not DBIcon:IsRegistered(addonName) then return end
	if on then DBIcon:Show(addonName) else DBIcon:Hide(addonName) end
end
