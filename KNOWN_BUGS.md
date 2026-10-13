# Known bugs

Reported in-game by the user on 2026-10-13.

## Fixed 2026-10-13, confirmed in-game: some letters a different colour

- **What happened:** in dimmed (non-highlighted) menu text, some letters were a
  different shade from the rest, for example the `m` and `n` on the in-game menu and
  pause screen.
- **Cause:** dimmed text is drawn by tinting a grey glyph texture. The tint was scaled
  by each glyph's own brightest pixel. A few glyphs peak one level lower than the rest
  (`m` and `n` in the small font; `f`, `m` and `v` in the large font), so they got a
  different colour.
- **Fix:** `drawSprite` in `Core/Render.lua` now scales every glyph against the
  highest level in its font.

## Fixed 2026-10-13, confirmed in-game: bugs 1 and 2

- **Cause:** the shop preview drew straight onto the menu's base draw list. That had two
  effects:
  - Every opaque fill (about 90 power-bar rows plus 4 per weapon power level, each frame)
    scanned all ~950 ops with `coverRect`.
  - It reshuffled the base list, so nearly every texture slot was re-set each frame.
- **Fix:**
  - The preview now draws into its own surface, added as one group
    (`weaponSimUpdate` in `Game/GameMenu.lua`).
  - The power bar is drawn as runs of rows instead of single pixels.
  - Stars go into a group clipped to the preview window (`pushGroup` now takes a clip
    rect). The original only drew stars on black pixels.
  - Fills on non-persistent surfaces no longer run coverage scans.
  - `JE_mouseReplace` keeps its op tables for reuse instead of making garbage.
- **Headless results at power 11, Lua interpreter (JIT off):**

  | | Before | After |
  |---|---|---|
  | Lua time per frame | 1.6 ms | 0.13 ms |
  | Quads | ~980 | ~670 |
  | Texture API calls per frame | ~600 | ~320 |

  Power level now barely changes the cost. Measure with `tools/harness/perf_counts.lua`.
- If it still lags in-game, the remaining suspect is the WoW cost per shown texture.

The original reports are kept below for reference.

## 1. Shop front-gun weapon preview lags the whole WoW client

- **What happens:** the lag is in the shop's **Front Gun** upgrade screen, where the
  preview window shows the ship firing the weapon you have selected. It affects **every**
  front weapon, not just the Widget Beam (the user first saw it with the Widget Beam).
- **Gets worse with power:** each power level you buy makes it slower than the last, and
  the slowdown grows faster at each step. Maxed weapons freeze WoW. The cost seems to
  grow faster than the number of shots, which points to work that scales with
  (number of draw ops)^2 or that builds up over time, rather than simply drawing more
  shots.
- **Measured:** `/tyrian stats` in the shop showed 1022 quads and 22 MB of addon memory.
- **Not yet known:** whether the same weapon at the same power also lags in a level. If
  not, the problem is specific to the shop preview, which would fit the suspects below.
- **Suspects, most likely first:**
  1. **`coverRect` on a persistent surface.** VGAScreen and VGAScreen2 are "persistent",
     so every opaque draw on them scans the whole op list (`coverRect` in
     `Core/Video.lua`). If the preview draws its shots and explosions onto a persistent
     surface, each frame costs about ops × opaque draws, which is quadratic. More shots
     mean more ops and more draws.
  2. **Ops that build up.** The preview area may never be cleared or covered each frame,
     so shot sprites keep piling up until they hit the 4000-op safety valve in `push()`.
     The valve then shuffles about 1800 tables every frame.
  3. **Too many simulation steps per frame.** The preview simulation (the shop's
     equivalent of `JE_weaponSimUpdate` / `simulateWeaponFire` in OpenTyrian
     `game_menu.c`) may run several game ticks per rendered frame, or not wait
     correctly, so the coroutine never yields. That would also explain WoW itself
     freezing.
  4. **Garbage per shot**, such as tables or strings created per shot or per
     explosion, causing GC stalls.
- **Where to look:**
  - `Game/GameMenu.lua`: the weapon-preview code and which surface it draws to.
  - `Game/Shots.lua` (`player_shot_create` and the shot update).
  - `Core/Video.lua` (`coverRect`, `push`, `surfaceCopy`).
  - `Core/Render.lua` (cost per quad).
- **Headless repro:**
  - Use `tools/harness` with `run_opts.lua`. Navigate to the shop's Front Gun screen,
    and use a preset or hook to set `player[0].items.weapon[FRONT_WEAPON].power` to
    1, 4, 8 and 11.
  - Log ms per frame, `VGAScreen.n` / ops per frame, `coverRect` calls per frame and
    `collectgarbage("count")` growth at each level, to confirm which suspect it is.
- **Possible fixes:**
  - Draw the preview to a non-persistent sub-surface (cleared every frame and nested
    with `pushGroup`), so it doesn't trigger `coverRect` scans.
  - Clip it to the preview window.
  - Cap the simulation at one step per frame.
  - Fixing this may also fix bug 2, which is in the same preview code.

## 2. Blue star particles overlap the shop text

- **What happens:** blue star particles from the background are drawn over the text in
  the shop (upgrade menu).
- **Likely causes to check:**
  - Stars (K_STAR ops) or superpixels left on, or still being pushed onto, VGAScreen.
  - They are not clipped to the shop's weapon-preview window.
  - They are drawn in a layer above the menu text.
- **Where to look:**
  - `Game/GameMenu.lua`: the weapon preview / `drawMenuScreen`.
  - `Core/Render.lua`: draw order and clipping for stars.
  - `Game/Backgrnd.lua`: the starfield.
  - Compare with the original's shop: in OpenTyrian, `JE_weaponSimUpdate` in
    `menus.c`/`game_menu.c` draws into a clipped area.
