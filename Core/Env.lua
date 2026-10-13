--[[
 WowTyrian2k: a World of Warcraft port of OpenTyrian
 Copyright (C) The OpenTyrian Development Team
 Lua port Copyright (C) 2026 voetre

 This program is free software; you can redistribute it and/or
 modify it under the terms of the GNU General Public License
 as published by the Free Software Foundation; either version 2
 of the License, or (at your option) any later version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
]]

-- Every ported file runs inside a private global environment so that the
-- many C globals of OpenTyrian do not leak into (or collide with) WoW's _G.
local _, ns = ...

ns.files = ns.files or {}

local G = setmetatable({}, { __index = _G })
ns.G = G
G.ns = ns
G._G_REAL = _G
