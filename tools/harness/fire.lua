TEST_HOOK = function(ns)
  local G = ns.G
  local orig = G.applyCheats
  G.minX, G.maxX = 999, -999
  G.applyCheats = function()
    G.keysactive[G.SDL_SCANCODE_SPACE] = true
    local x = G.player[0].x
    if x < G.minX then G.minX = x end
    if x > G.maxX then G.maxX = x end
    orig()
  end
end
POST_HOOK = function(ns) local G = ns.G; print("cash", G.player[0].cash, "x range", G.minX, G.maxX, "alive", G.player[0].is_alive) end
local post = POST_HOOK
POST_HOOK = function(ns, M)
  post(ns)
  local n = 0
  local hit = string.format("sfx%02d_", ns.G.S_ENEMY_HIT)
  for _, s in ipairs(M.sounds) do if s:find(hit, 1, true) then n = n + 1 end end
  print("enemy-hit sounds", n)
end
