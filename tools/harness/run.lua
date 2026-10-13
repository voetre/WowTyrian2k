package.path = "./?.lua;" .. package.path
local M = require("wow_mock")
local ADDON = arg[1]
local frames = tonumber(arg[2] or "600")
local script = arg[3] or ""   -- comma separated "frame:key" presses
local dumpAt = arg[4] or ""   -- comma separated frames to dump
local ns = {}
local toc = io.open(ADDON .. "/WowTyrian2k.toc"):read("*a")
for line in toc:gmatch("[^\r\n]+") do
  if not line:match("^##") and line:match("%.lua$") then
    local f = line:gsub("\\", "/")
    local chunk, err = loadfile(ADDON .. "/" .. f)
    if not chunk then error(err) end
    chunk("WowTyrian2k", ns)
  end
end
-- fire ADDON_LOADED
for _, f in ipairs(M.frames) do
  if f.scripts.OnEvent and f.events.ADDON_LOADED then f.scripts.OnEvent(f, "ADDON_LOADED", "WowTyrian2k") end
end
SlashCmdList.WOWTYRIAN2K("")
local presses = {}
for item in script:gmatch("[^,]+") do
  local fr, key = item:match("(%d+):(%S+)")
  presses[tonumber(fr)] = presses[tonumber(fr)] or {}
  table.insert(presses[tonumber(fr)], key)
end
local dumps = {}
for d in dumpAt:gmatch("%d+") do dumps[tonumber(d)] = true end
local driver
for _, f in ipairs(M.frames) do if f.scripts.OnUpdate then driver = f end end
local releases = {}
local function dump(n)
  local out = io.open(string.format("dump_%05d.txt", n), "w")
  local list = {}
  for _, t in ipairs(M.textures) do
    if t.shown and t.frame:IsShown() and (t.path or t.color) then list[#list+1] = t end
  end
  table.sort(list, function(a, b)
    if a.frame.level ~= b.frame.level then return a.frame.level < b.frame.level end
    local la = a.layer == "OVERLAY" and 2 or (a.layer == "BACKGROUND" and 0 or 1)
    local lb = b.layer == "OVERLAY" and 2 or (b.layer == "BACKGROUND" and 0 or 1)
    if la ~= lb then return la < lb end
    if a.sub ~= b.sub then return a.sub < b.sub end
    return a.idx < b.idx
  end)
  local sc = ns.getScale()
  for _, t in ipairs(list) do
    if t.color then
      if t.all then out:write(string.format("C %f %f %f %f\n", t.color[1], t.color[2], t.color[3], t.color[4])) end
    elseif t.x then
      local tc = t.tc or {0,1,0,1}
      out:write(string.format("T %s %f %f %f %f %f %f %f %f %f %f %f %f %s\n", t.path, t.x/sc, -t.y/sc, t.w/sc, t.h/sc, tc[1], tc[2], tc[3], tc[4], t.r, t.g, t.b, t.a, t.mode))
    end
  end
  out:close()
end
local t0 = os.clock()
local alloc0 = 0
for n = 1, frames do
  if n == 2000 then collectgarbage("collect"); collectgarbage("stop"); alloc0 = collectgarbage("count"); t0 = os.clock() end
  if n == 2900 then local a = collectgarbage("count") - alloc0; print(string.format("frames 2000-2900: %.1f KB allocated, %.2f ms/frame lua", a, (os.clock()-t0)*1000/900)); collectgarbage("restart") end
  M.time = M.time + 1/60
  if releases[n] then for _, k in ipairs(releases[n]) do ns.onKeyUp(k) end end
  if presses[n] then
    for _, k in ipairs(presses[n]) do
      ns.onKeyDown(k)
      local r = n + 3
      releases[r] = releases[r] or {}; table.insert(releases[r], k)
    end
  end
  driver.scripts.OnUpdate(driver, 1/60)
  if dumps[n] then dump(n) end
  if ns.lastError then print("ERROR at frame " .. n .. ": " .. ns.lastError) break end
end
print("frames run; quads:", ns.quadCount, "music:", M.music, "sounds:", #M.sounds)
local G = ns.G
print("armor", G.player[0].armor, "shield", G.player[0].shield, "shield_max", G.player[0].shield_max, "power", G.power, "alive", G.player[0].is_alive, "ship", G.player[0].items.ship, "lives", G.player[0].lives and G.player[0].lives.power)
local c = G.palette
for _, i in ipairs({144,146,150,224,226,230,236}) do io.write(i, "=", c[i][1], ",", c[i][2], ",", c[i][3], "  ") end print()
print("pal id", G.palette.id, "fade", G.fadeAlpha)
