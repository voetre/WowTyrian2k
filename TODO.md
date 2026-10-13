# TODO: new features

Ideas requested by the user on 2026-10-13. Bugs are tracked separately in KNOWN_BUGS.md.
The notes below are starting points only and have not been checked against the code.

## 1. ~~Cheat: all shop items unlocked~~ (done 2026-10-13, awaiting in-game test)

"All shop items" on the Cheats page. Every row of the upgrade shop lists every item that
any episode's shop sells (read from the `]I` sections of `levels1-4.dat`). Long lists
scroll, with arrows at the right edge (`unlockShopItems` and `SUB_ROWS` in
`Game/GameMenu.lua`).

## 2. ~~Cheat: all secret unlocks~~ (done 2026-10-13, awaiting in-game test)

"Secret items" on the Cheats page adds the items no shop sells to the shop, for example
the Foodship Nine (carrot), Stalker, Nort ship and Dragonwing ships plus the secret
weapons, shield and sidekick. It works on its own or together with cheat 1.

## 6. ~~Remove two-player play~~ (done 2026-10-13, awaiting in-game test)

- Removed:
  - the 2P help topic and page
  - the 2P in-game help layout
  - 2P save slots, high scores, scores and the split HUD
  - player 2 input and manual ship linking
  - the leftover network stubs
- The menus now say "Game Mode", "Full Game", "Arcade" and "Saved Games"
  (overrides in `Game/Text.lua`).
- Kept: the second ship of the Galaga secret level, which docks onto the player when a
  purple ball is collected. It reuses the `twoPlayerMode` / `player[1]` code, but it
  is single-player.

## 3. Flight path mode (after more optimisation)

While the player is on a WoW flight path, estimate how long the flight has left, offer
a game of Tyrian, and generate a custom level that lasts that long and ends with a
boss fight.

- **Prerequisite:** fix the performance problems first (see the Widget Beam lag in
  KNOWN_BUGS.md). Flights are long, so the game has to run smoothly for many minutes.
- **Detecting the flight:**
  - `UnitOnTaxi("player")`.
  - The events `PLAYER_CONTROL_LOST` / `PLAYER_CONTROL_GAINED`, and `TAXIMAP_OPENED`
    plus `TakeTaxiNode` (hook it to learn the destination).
  - Check which of these exist on the 16001 client.
- **Estimating the duration:** there is no WoW API for a flight's remaining time.
  - Done (2026-10-13, `Core/Flight.lua`): `TakeTaxiNode` is hooked, and the estimate
    comes from the first source that knows the route:
    1. the player's own recorded time for that exact route, hops included
       (`WowTyrian2kDB.flights[mapID][route]`)
    2. Flight Timer Classic's 808 routes (`Core/FlightData.lua`, CC BY 2.0, converted
       by `tools/flight/convert_ftc.py`)
    3. a length/hops model fitted per continent (EK 1415, Kalimdor 1414; about 40 s
       mean error)
  - Each flight is timed from the click to `PLAYER_CONTROL_GAINED`, as FTC times
    them, and saved. `ns.Flight.current` and `ns.Flight.remaining()` serve flight
    mode. `/tyrian flights` turns the chat message off and on.
  - Done: during a flight the in-game message strip shows a progress bar with the
    destination and time left (`JE_drawFlightBar` in `Game/Mainint1.lua`). Game
    messages take priority, and the bar returns when they clear.
  - Leatrix Plus, InFlight and PhanxFlightTimer data is all rights reserved, so it
    is not shipped. Only checked locally against FTC (median difference 0 s).
  - Still to check in game: that the 16001 client's `TaxiNodePosition` x matches
    FTC's keys (tolerance is +/-0.00005).
- **Map generation (prototype 2026-10-13, `tools/levgen/`):**
  - The 62 levels use 5 tile sets (`z` alone covers 32). Each map has three layers of
    tile indices (14x300, 14x600, 15x600) that scroll upward from the bottom.
  - Real map segments (12-30 rows) are the building blocks. Short bridge rows between
    them are generated so every 2x2 tile window also occurs in a real map
    (`seg.py`). Whole-row stitching alone barely branches, and tile-by-tile generation
    alone is seamless but cuts large structures off.
  - Done: `tools/levgen/build.py` precomputes the segment graph and bridges at convert
    time into `Data/levgen.lua` (not published, made from game data), and
    `Game/LevelGen.lua` walks it in game.
  - Done: `/tyrian genlevel [forest|ocean] [seed]` plays an endless generated
    level (a random theme if none is given). Each map is a ring: rows are written
    just ahead of the scroll and the view jumps back seamlessly near the top.
    Enemies come from the theme's own level. Its level-end, jump and map-move
    events are disabled, scroll stops become normal speed, and the waves repeat.
  - Done (2026-10-13): curated themes instead of every tile set, because
    mixing levels gave poor results. `THEMES` in `build.py` lists them:
    forest = TORM (rivers, waterfalls, airships), ocean = APPROACH. FLEET was
    tried and dropped: its capital ships' guns are invisible enemies placed on
    map art, which a generated map doesn't have where they spawn.
    Each theme's map graph and enemies come only from its own level. To add one
    (ice = CAMANIS on tile set `w`, say), add a line there and rebuild. Colour
    filter events are ignored.
  - Done: scenery stays on matching ground. Scenery means ground enemies spawned
    together whose sprites touch (DESERTRUN's rock arches are about 15 of them),
    or a lone enemy with a solid sprite (85%+ opaque, such as a turret on its own
    patch of dirt). Groups with no solid sprite (TORM's airships and spider
    walkers, built from small pieces) are fliers and always spawn. A group is kept or dropped as a whole: kept when 70% of the
    map tiles under it look like the template's tiles there. The comparison uses
    each tile's mean colour (`G.col`), weighted towards hue so that sand vs grey
    metal counts but dark shadow vs sand does not. A kept group gets the
    template's layer 1 tiles stamped under it, plus any non-plain tiles one tile
    around it: the arches' feet and shadows are map tiles, not enemies.
    Groups are decided a few rows ahead (layer 1 scrolls in step with curLoc,
    so the spawn row is known), so the stamp never changes tiles on screen.
    Stamps only paint over open ground (tiles that look like the template's
    most common tile); a group whose footprint would cover generated rock or
    buildings is dropped, so ASTEROID's platforms no longer cut into rock.
    Layer 3 turrets still need layer 3 rock under them, but only in themes with
    real layer 3 art (`l3art`, 100+ tiles); elsewhere layer 3 enemies always spawn. Themes with less (CAMANIS has 30
    stray tiles) get an empty layer 3; tiling the stray ones drew stripes. Tanks,
    walkers and fliers always spawn. This thins out some waves (most of
    DESERTRUN's arches land on metal); generating waves (below) would fix that
    properly.
  - Done: the generator's RNG skips its first draw and scales instead of taking
    `s % n` (the multiplier is 7^5), so every template level of a tile set can
    be chosen.
  - Done (2026-10-13, awaiting in-game test): timed levels.
    `/tyrian timedlevel <5m|300|4:30> [forest|ocean] [seed]` plays a generated level
    of that length (75 s minimum), ending with the template's boss.
    - The template's boss section (from 100 ticks before its boss bar event) is held
      back, disabled, until the boss time. It then starts at the template's own scroll
      speeds, because TORM's boss drifts off the bottom of the screen at the wave speeds.
    - Boss time = planned length − the boss section's length (TORM: about 66 s to its
      level end, whether or not the boss dies), or − 50 s for a boss that loops until
      killed (APPROACH). At least 40% of the level is always waves. A looping boss
      still alive 30 s after the planned end leaves, and the level ends.
    - The waves keep looping until the boss. Each wave is kept or dropped a few
      seconds ahead: 50% kept and easy for the first 30% of the time, then 75% kept
      and normal, then all kept and hard from 70%. None are kept in the last 4 s.
      The boss itself is at normal difficulty.
    - The message strip shows "Boss in m:ss" with a progress bar, then "BOSS" and
      "BOSS DESTROYED". The end message reports the planned and played times.
    - Tested in the harness: forest played 2:01 of 2:00 and 5:01 of 5:00. Ocean
      at 1:30 ran to 1:57: the boss was killed at 1:53 with a maxed weapon.
  - Still to do: tune the ramp and the looping boss's time in play.
- **Prompt:** done (2026-10-13, awaiting in-game test), `Core/FlightPrompt.lua`.
  - Once the player is on the taxi (`Flight.onBoarded`), a toast near the top of the
    screen shows the destination, a countdown and a progress bar, and asks "Play
    Tyrian? (m:ss level)". It is draggable and never takes the keyboard.
  - Yes starts a timed level of the flight time left − 10 s (`ns.playGenLevel`),
    whenever it is clicked. No dismisses the toast.
  - The toast fades out with "Not enough flight left for a game" once less than
    75 s + 10 s is left, and on landing. It isn't shown at all for shorter flights or
    while a timed level is already running.
  - `/tyrian flighttest <duration> [forest|ocean] [seed]` fakes a flight of that
    length with the toast; `/tyrian flighttest stop` ends it. `/tyrian flightprompt`
    turns the toast off and on.
  - While on a flight, the message strip at the bottom shows the destination and the
    flight time left, with a bar that fills as the flight goes (plus "BOSS" /
    "BOSS DESTROYED" once the boss is out). Without a flight (`/tyrian timedlevel`)
    it shows the boss countdown instead. (Fixed 2026-10-13: it showed the boss
    countdown during flights too.)
- **Arcade play in timed levels:** done (2026-10-13, awaiting in-game test),
  `Game/LevelGen.lua` (`beginTest`, `timedFrame`, `maybeDrop`).
  - Plays like the arcade mode: the front weapon's power is the player's lives, and
    a death costs one level.
  - **Power by time:** `power = (900 - seconds) / 825`, clamped to 0-1. A 75 s level is
    100%, and a 15 min or longer level is 0%. Shorter levels start stronger:
    front power 2 + 4 x power (2 to 6).
  - **Drops:** killed enemies drop a power-up with a 12% + 13% x power chance (12% to
    25%). The kinds are weighted: front power 3 + 4 x power, purple ball 3, armor 2,
    superbomb 1 + power.
  - **Density:** the ramp now keeps 80% / 100% / 100% of the waves (was 50 / 75 / 100),
    and the enemy frequency is capped at 95 / 93 / 90 so random enemies come more often.
  - **Difficulty:** each ramp step adds round(power) to its difficulty level. The boss
    gets 3 x power on top of normal, so short levels have a harder boss to match
    the stronger ship.
  - **Music:** each timed level picks a random level song (not the title, shop,
    ending or boss tunes), seeded from the level seed.
  - The F12 dump has an "arcade:" line with the power, the front power at the start
    and now, drops per kind, the song and the enemy frequency.
  - Harness tests (forest, the bot only shoots a little):

    | Length | Power | Front power | Drops | Difficulty |
    |---|---|---|---|---|
    | 2:00 | 95% | 6, rising to 7 | 3 | 2 to 5, boss at 0:55 |
    | 10:00 | 36% | 3, rising to 5 | 13 | 1 to 2 |

  - Still to do: tune it in game. The bot didn't kill the diff 5 boss in 60 s, so
    check the short-level boss isn't too hard for a person.
- **Generating the level:**
  - Tyrian levels are a scrolling map plus a timed list of events (enemy waves,
    speed changes, boss, level end).
  - Approach: assemble a new event list on the fly from building blocks taken from the
    existing levels (enemy wave event groups grouped by difficulty) over a reused map
    and tileset. Pace the waves so the level fills the estimated time, put a boss
    event (boss enemy plus boss bar link) near the end, then end the level.
  - Ramp the difficulty over the course of the level. The player's current ship and
    items carry over.
- **Landing:**
  - On `PLAYER_CONTROL_GAINED` / taxi end before the boss is beaten, end gracefully:
    pause, or offer to continue.
  - If the estimate was too long, the boss arrives early. Optionally adjust the pacing
    as the remaining time is re-estimated during the flight.
- **Open questions:**
  - Should the score and items count towards the normal save, or be kept separate?
  - What should happen when the player gets dismounted early?

## 4. ~~Replace the author name with the screen name "voetre"~~ (done 2026-10-13)

The TOC `## Author` field and the `Lua port Copyright (C) 2026` header line in all 26 Lua
files now credit "voetre". The sample name in the GPL text in `COPYING` was left alone.
Use "voetre" in any new files.

## 5. WoW-themed sprites (aspirational)

An optional sprite set that reskins the game as WoW. The ship becomes the player's own
race riding their faction's flight path creature (a gryphon for the Alliance, a wyvern
for the Horde). The weapons become their class spells: mages shoot Frostbolt, Fireball
and Arcane Missiles; hunters shoot arrows; warlocks shoot Shadow Bolt; and so on.
This pairs naturally with flight path mode (item 3).

- **Detecting the player:** `UnitRace("player")`, `UnitFactionGroup("player")`,
  `UnitClass("player")`, `UnitSex("player")`. Pick the mount, the rider and the spell
  set from these.
- **Mapping spells to weapons:** keep Tyrian's shot patterns and stats, and only swap
  the graphics.
  - Each class gets a themed set of front and rear weapons, and the weapon names in the
    shop are renamed to match, for example "Fireball" for the Pulse-Cannon slot.
  - Sidekicks could become class pets, totems or minions.
  - Specials could become class cooldowns.
- **Where the art could come from:**
  1. **Hand-drawn pixel-art sprites made for this project.** These can be published,
     unlike the converted Tyrian data, as long as their licence is compatible with the
     GPL code (for example CC-BY-SA or GPL).
  2. **Game textures the client already has, referenced at runtime:**
     - spell icons via `GetSpellTexture` or icon file IDs
     - spell effect textures
     - Blizzard assets must not be shipped in the addon, but referencing files the
       client already has is fine.
  3. **3D models in the game window:** a `PlayerModel` / `DressUpModel` /
     `ModelScene` frame layered over the game, showing the player's actual character on
     a gryphon or wyvern display ID. This is the most "real", but it's expensive.
     Measure the performance and check that the camera works for a top-down view.
- **Technical notes:**
  - Sprites in this port come from TGA atlases plus metadata in `Data/gfxmeta.lua`,
    drawn by `Core/Render.lua`. A custom set would be extra atlases with the same
    layout.
  - The shot and sprite indices in the weapon data would be remapped through a lookup
    table when the WoW skin is on.
  - Collision sizes are tied to the original sprite sizes, so keep the hitboxes the
    same as the originals so the balance doesn't change.
  - Add a toggle on the options page: "Graphics: Classic Tyrian / Azeroth".
- **Do this after** the performance work and flight path mode. Start with one
  race/class combination as a proof of concept.
