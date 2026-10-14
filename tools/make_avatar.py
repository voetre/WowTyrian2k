#!/usr/bin/env python3
"""
Builds the project avatar (CurseForge, Wago, WowInterface): the USP Talon
climbing a dashed flight-path trail from a waypoint marker, firing, over a
starfield, with a "2K" badge. Drawn as 50x50 pixel art, scaled 8x to 400x400.

    python3 tools/make_avatar.py <addon dir> <out.png>

Run tools/convert.py first; it writes Textures/sheet_ship9.tga. Needs Pillow.
"""
import math
import os
import random
import sys

from PIL import Image

G = 50            # logical grid
SCALE = 8         # 50 * 8 = 400
SHIP = 233        # USP Talon, top-left tile of a 2x2 block (see make_icon.py)
COLS = 73
TILE_W, TILE_H = 12, 14

GOLD = (255, 196, 64)
GOLD_DARK = (176, 112, 24)
CYAN = (120, 232, 255)
WHITE = (255, 255, 255)
FLAME = [(255, 240, 160), (255, 168, 40), (220, 72, 16)]

# 3x5 glyphs
FONT = {
    '2': ['111', '001', '111', '100', '111'],
    'K': ['101', '101', '110', '101', '101'],
}


def ship_sprite(addon):
    sheet = Image.open(os.path.join(addon, 'Textures', 'sheet_ship9.tga')).convert('RGBA')
    out = Image.new('RGBA', (2 * TILE_W, 2 * TILE_H))
    for ty in range(2):
        for tx in range(2):
            index = SHIP + tx + 19 * ty   # blit_sprite2x2 layout
            u = ((index - 1) % COLS) * 14 + 1
            v = ((index - 1) // COLS) * 16 + 1
            out.paste(sheet.crop((u, v, u + TILE_W, v + TILE_H)), (tx * TILE_W, ty * TILE_H))
    return out


def main(addon, dest):
    img = Image.new('RGBA', (G, G))
    px = img.load()

    # deep-space background: a vertical gradient with a soft glow behind the ship
    for y in range(G):
        for x in range(G):
            t = y / (G - 1)
            r, g, b = 10 + 8 * t, 12 + 6 * t, 34 + 22 * t
            d = math.hypot(x - 25, y - 20) / 26
            glow = max(0.0, 1 - d) ** 2
            px[x, y] = (int(r + 40 * glow), int(g + 28 * glow), int(b + 70 * glow), 255)

    rng = random.Random(1995)
    for _ in range(46):
        x, y = rng.randrange(G), rng.randrange(G)
        c = rng.choice([(90, 100, 150), (150, 160, 210), (230, 235, 255)])
        px[x, y] = c + (255,)

    # flight path: a quadratic curve from the waypoint (bottom left) up to the
    # ship's tail, drawn as 2-pixel dashes with a darker edge
    p0, p1, p2 = (8, 42), (16, 50), (25, 38)
    pts = []
    for i in range(200):
        t = i / 199
        x = (1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0]
        y = (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1]
        pts.append((round(x), round(y)))
    seen = []
    for p in pts:
        if not seen or seen[-1] != p:
            seen.append(p)
    for i, (x, y) in enumerate(seen):
        if i % 4 != 3:
            px[x, y] = GOLD + (255,)
            if y + 1 < G:
                px[x, y + 1] = GOLD_DARK + (255,)

    # waypoint: a gold diamond with a dark centre
    wx, wy = p0
    for dy in range(-3, 4):
        for dx in range(-3, 4):
            if abs(dx) + abs(dy) <= 3:
                px[wx + dx, wy + dy] = (GOLD if abs(dx) + abs(dy) < 3 else GOLD_DARK) + (255,)
    px[wx, wy] = (40, 24, 8, 255)

    # ship, with engine flame and two laser shots
    ship = ship_sprite(addon)
    sx, sy = 13, 6
    for i, c in enumerate(FLAME):
        for x in (sx + 11, sx + 12):
            px[x, sy + 2 * TILE_H - 1 + i] = c + (255,)
    px[sx + 11, sy + 2 * TILE_H + 2] = FLAME[2] + (255,)
    img.alpha_composite(ship, (sx, sy))
    for lx in (sx + 7, sx + 16):
        for y in range(2, 8):
            px[lx, y] = (CYAN if y > 2 else WHITE) + (255,)
    for lx in (sx + 7, sx + 16):
        px[lx, 1] = (60, 140, 200, 255)

    # "2K" badge, bottom right
    bx, by, bw, bh = 37, 41, 11, 7
    for y in range(by, by + bh):
        for x in range(bx, bx + bw):
            edge = x in (bx, bx + bw - 1) or y in (by, by + bh - 1)
            corner = x in (bx, bx + bw - 1) and y in (by, by + bh - 1)
            if not corner:
                px[x, y] = (GOLD_DARK if edge else GOLD) + (255,)
    for n, ch in enumerate('2K'):
        for y, row in enumerate(FONT[ch]):
            for x, bit in enumerate(row):
                if bit == '1':
                    px[bx + 2 + n * 4 + x, by + 1 + y] = (30, 16, 4, 255)

    img.resize((G * SCALE, G * SCALE), Image.NEAREST).convert('RGB').save(dest)
    print('wrote %s (%dx%d)' % (dest, G * SCALE, G * SCALE))


if __name__ == '__main__':
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    main(sys.argv[1], sys.argv[2])
