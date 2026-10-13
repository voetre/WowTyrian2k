-- Minimal WoW API mock for headless testing of WowTyrian2k
local M = {}
M.time = 0
M.frames = {}
M.textures = {}
M.sounds = {}
M.music = nil

local FrameMT = {}
FrameMT.__index = FrameMT
local TexMT = {}
TexMT.__index = TexMT

local nextId = 0
function CreateFrame(ftype, name, parent, template)
  nextId = nextId + 1
  local f = setmetatable({ id = nextId, scripts = {}, shown = true, level = parent and (parent.level + 1) or 1, parent = parent, events = {} }, FrameMT)
  M.frames[#M.frames + 1] = f
  if name then _G[name] = f end
  return f
end
local noop = function() end
for _, n in ipairs({"SetSize","SetAllPoints","SetFrameStrata","SetToplevel","SetClampedToScreen","SetMovable","EnableMouse","RegisterForDrag","StartMoving","StopMovingOrSizing","SetClipsChildren","EnableKeyboard","SetPropagateKeyboardInput","SetHeight","SetWidth","SetText","SetPoint","ClearAllPoints"}) do FrameMT[n] = noop end
function FrameMT:Show() self.shown = true end
function FrameMT:Hide() self.shown = false end
function FrameMT:SetShown(v) self.shown = v end
function FrameMT:IsShown() local f = self; while f do if not f.shown then return false end f = f.parent end return true end
function FrameMT:SetScript(n, fn) self.scripts[n] = fn end
function FrameMT:GetScript(n) return self.scripts[n] end
function FrameMT:SetFrameLevel(l) self.level = l end
function FrameMT:GetFrameLevel() return self.level end
function FrameMT:GetEffectiveScale() return 1 end
function FrameMT:GetLeft() return 0 end
function FrameMT:GetTop() return 600 end
function FrameMT:RegisterEvent(e) self.events[e] = true end
function FrameMT:CreateFontString() return setmetatable({}, { __index = function() return noop end }) end
function FrameMT:CreateTexture(name, layer, tmpl, sub)
  local t = setmetatable({ frame = self, layer = layer, sub = sub or 0, shown = true, idx = #M.textures + 1, r=1,g=1,b=1,a=1, mode="BLEND" }, TexMT)
  M.textures[#M.textures + 1] = t
  return t
end
function TexMT:SetTexture(p) self.path = p; self.color = nil end
function TexMT:SetColorTexture(r,g,b,a) self.color = {r,g,b,a}; self.path = nil end
function TexMT:SetTexCoord(a,b,c,d) self.tc = {a,b,c,d} end
function TexMT:SetPoint(p, rel, rp, x, y) self.x, self.y = x, y end
function TexMT:SetAllPoints() self.all = true end
function TexMT:SetSize(w,h) self.w, self.h = w, h end
function TexMT:SetVertexColor(r,g,b,a) self.r,self.g,self.b,self.a = r,g,b,a or 1 end
function TexMT:SetBlendMode(m) self.mode = m end
function TexMT:Show() self.shown = true end
function TexMT:Hide() self.shown = false end
function TexMT:SetSnapToPixelGrid() end
function TexMT:SetTexelSnappingBias() end
function TexMT:SetDrawLayer(l, s) self.layer = l; self.sub = s end

function GetTimePreciseSec() return M.time end
function GetTime() return M.time end
function PlaySoundFile(p, ch) M.sounds[#M.sounds+1] = p; return true, #M.sounds end
function StopSound() end
function PlayMusic(p) M.music = p end
function StopMusic() M.music = nil end
function GetCursorPosition() return -1000, -1000 end
function InCombatLockdown() return false end
function IsShiftKeyDown() return false end
function IsControlKeyDown() return false end
function IsAltKeyDown() return false end
function debugstack(co) return debug.traceback(co) end
UIParent = CreateFrame("Frame")
SlashCmdList = {}
return M
