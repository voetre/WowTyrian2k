API = { n = 0, tex = 0 }
local installed = false
local lastN, lastT = 0, 0
local clock = os.clock
local t0 = clock()
FRAME_HOOK = function(n, ns, M)
  if not installed then
    installed = true
    local TexMT = getmetatable(UIParent:CreateTexture())
    for _, m in ipairs({ "SetTexture", "SetTexCoord", "SetPoint", "SetSize", "SetVertexColor", "SetBlendMode", "Show", "Hide" }) do
      local f = TexMT[m]
      rawset(TexMT, m, function(self, ...) API.n = API.n + 1; if m == "SetTexture" then API.tex = API.tex + 1 end return f(self, ...) end)
    end
  end
  local G = ns.G
  if n % 200 == 0 and n >= 1800 then
    print(string.format("frame %d pow %d: %.2f ms, API calls/frame %.0f, SetTexture/frame %.0f, quads %s", n, G.player[0].items.weapon[0].power, (clock()-t0)*1000/200, (API.n - lastN) / 200, (API.tex - lastT) / 200, tostring(ns.quadCount)))
    lastN, lastT = API.n, API.tex; t0 = clock()
  end
end
