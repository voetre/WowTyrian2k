#!/usr/bin/env python3
"""
Builds Textures/icon.tga, the minimap button's icon: the USP Talon (the
ship you start with, sprite 233 of newsh9) cut from the converted ship
sheet and scaled 2x, centred on a transparent 64x64 square.

    python3 tools/make_icon.py <addon dir>

Run tools/convert.py first; it writes Textures/sheet_ship9.tga.  Standard
library only.
"""
import os
import struct
import sys

SHIP = 233        # ships[1].shipgraphic, the top-left tile of a 2x2 block
COLS = 73         # tiles per row in sheet_ship9 (gfxmeta.sheets.ship9.cols)
TILE_W, TILE_H = 12, 14
SCALE = 2
SIZE = 64


def read_tga(path):
    data = open(path, 'rb').read()
    idlen, _, kind = data[0], data[1], data[2]
    w, h, bpp, desc = struct.unpack_from('<HHBB', data, 12)
    if kind != 2 or bpp != 32 or not desc & 0x20:
        raise SystemExit('%s: expected a 32-bit top-left TGA' % path)
    return w, h, data[18 + idlen:]


def main(addon):
    w, h, px = read_tga(os.path.join(addon, 'Textures', 'sheet_ship9.tga'))

    def tile_pixel(index, x, y):
        # the atlas has each 12x14 tile in a 14x16 cell, one pixel in
        u = ((index - 1) % COLS) * 14 + 1
        v = ((index - 1) // COLS) * 16 + 1
        o = ((v + y) * w + u + x) * 4
        return px[o:o + 4]

    ship_w, ship_h = 2 * TILE_W, 2 * TILE_H
    ox = (SIZE - ship_w * SCALE) // 2
    oy = (SIZE - ship_h * SCALE) // 2
    out = bytearray(SIZE * SIZE * 4)   # transparent
    for y in range(ship_h):
        for x in range(ship_w):
            # blit_sprite2x2: index, index + 1, index + 19, index + 20
            index = SHIP + (x >= TILE_W) + 19 * (y >= TILE_H)
            p = tile_pixel(index, x % TILE_W, y % TILE_H)
            for dy in range(SCALE):
                for dx in range(SCALE):
                    o = ((oy + y * SCALE + dy) * SIZE + ox + x * SCALE + dx) * 4
                    out[o:o + 4] = p
    hdr = struct.pack('<BBBHHBHHHHBB', 0, 0, 2, 0, 0, 0, 0, 0, SIZE, SIZE, 32, 0x28)
    path = os.path.join(addon, 'Textures', 'icon.tga')
    with open(path, 'wb') as f:
        f.write(hdr)
        f.write(out)
    print('wrote %s (%dx%d)' % (path, SIZE, SIZE))


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit(__doc__)
    main(sys.argv[1])
