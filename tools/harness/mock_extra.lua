-- extra mocks for the options page
local noop = function() end
local FrameMT = getmetatable(CreateFrame("Frame"))
setmetatable(FrameMT, { __index = function() return noop end })
function FrameMT:SetChecked(v) self.checked = v end
function FrameMT:GetChecked() return self.checked end
function FrameMT:SetMinMaxValues(a, b) self.min, self.max = a, b end
function FrameMT:SetValue(v) self.value = v; if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, v) end end
function FrameMT:GetValue() return self.value end
function FrameMT:Click() self.checked = not self.checked; self.scripts.OnClick(self) end
CVARS = { Sound_MusicVolume = "0.4", Sound_SFXVolume = "0.9" }
function GetCVar(k) return CVARS[k] end
function SetCVar(k, v) CVARS[k] = tostring(v) end
function PlaySound() end
GameTooltip = CreateFrame("Frame")
REGISTERED = {}
Settings = {
  RegisterCanvasLayoutCategory = function(f, n) local c = { frame = f, name = n, GetID = function(self) return self.name end }; REGISTERED[#REGISTERED+1] = c; return c end,
  RegisterCanvasLayoutSubcategory = function(p, f, n) local c = { frame = f, name = n }; REGISTERED[#REGISTERED+1] = c; return c end,
  RegisterAddOnCategory = noop,
  OpenToCategory = function(id) OPENED = id end,
}
function FrameMT:IsShown() local f = self; while f do if not rawget(f, "shown") then return false end f = rawget(f, "parent") end return true end
local t = UIParent:CreateTexture()
local TexMT = getmetatable(t)
setmetatable(TexMT, { __index = function() return noop end })

-- the minimap, for Core/Minimap.lua
Minimap = CreateFrame("Frame", nil, UIParent)
function Minimap:GetWidth() return 140 end
function Minimap:GetCenter() return 1000, 700 end
function Minimap:GetEffectiveScale() return 1 end

-- WoW's global aliases, for the embedded libraries
strmatch, strfind, strsub, strlen, strlower, strupper, strrep, gsub, format =
	string.match, string.find, string.sub, string.len, string.lower, string.upper, string.rep, string.gsub, string.format
tinsert, tremove, tconcat = table.insert, table.remove, table.concat
function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function securecallfunction(f, ...) return f(...) end
function TexMT:GetParent() return self.frame end
function FrameMT:GetParent() return rawget(self, "parent") end
function FrameMT:GetName() return nil end
function FrameMT:HookScript(n, fn)
  local old = self.scripts[n]
  self.scripts[n] = old and function(...) old(...) fn(...) end or fn
end
local function stub() return setmetatable({}, { __index = function(t, k) return function() return stub() end end }) end
function FrameMT:CreateAnimationGroup() return stub() end
