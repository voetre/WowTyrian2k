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
