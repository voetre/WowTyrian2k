#!/usr/bin/env python3
"""Draws the jukebox's media button icons into Textures/media.tga.

Usage: python3 tools/make_media_icons.py <addon dir>

Eight 32x32 cells in a row, white on transparent (tinted in game):
previous, play, stop, next, shuffle, loop, circle, -.
"""
import math
import os
import sys

from PIL import Image, ImageDraw

CELL, SS = 32, 8          # cell size, supersampling
S = CELL * SS


def cell():
    img = Image.new("L", (S, S), 0)
    return img, ImageDraw.Draw(img)


def p(x, y):
    return (x * SS, y * SS)


def tri(d, pts):
    d.polygon([p(x, y) for x, y in pts], fill=255)


def rect(d, x0, y0, x1, y1):
    d.rectangle([p(x0, y0), p(x1, y1)], fill=255)


def arrowhead(d, x, y, ang, size=5.0):
    """A filled arrowhead with its tip at (x, y), pointing along ang."""
    back = ang + math.pi
    l = (x + size * math.cos(back - 0.6), y + size * math.sin(back - 0.6))
    r = (x + size * math.cos(back + 0.6), y + size * math.sin(back + 0.6))
    tri(d, [(x, y), l, r])


def line(d, pts, w=2.6):
    d.line([p(x, y) for x, y in pts], fill=255, width=int(w * SS), joint="curve")
    for x, y in (pts[0], pts[-1]):
        r = w * SS / 2
        d.ellipse([x * SS - r, y * SS - r, x * SS + r, y * SS + r], fill=255)


def prev_icon():
    img, d = cell()
    rect(d, 7, 9, 9.5, 23)
    tri(d, [(24, 8), (24, 24), (10.5, 16)])
    return img


def next_icon():
    return prev_icon().transpose(Image.FLIP_LEFT_RIGHT)


def play_icon():
    img, d = cell()
    tri(d, [(10, 6.5), (10, 25.5), (25.5, 16)])
    return img


def stop_icon():
    img, d = cell()
    rect(d, 9, 9, 23, 23)
    return img


def shuffle_icon():
    img, d = cell()
    # two crossing paths, each ending in an arrow on the right
    line(d, [(5, 10), (11, 10), (19, 22), (23, 22)])
    line(d, [(5, 22), (11, 22), (19, 10), (23, 10)])
    arrowhead(d, 28, 10, 0, 6)
    arrowhead(d, 28, 22, 0, 6)
    return img


def loop_icon():
    img, d = cell()
    # a rounded rectangle loop with arrows on the top and bottom runs
    w = int(2.6 * SS)
    d.rounded_rectangle([p(5, 9), p(27, 23)], radius=5 * SS, outline=255, width=w)
    # gaps for the arrows
    d.rectangle([p(13, 6), p(16, 12)], fill=0)
    d.rectangle([p(16, 20), p(19, 26)], fill=0)
    arrowhead(d, 19, 10.3, 0, 6)
    arrowhead(d, 13, 21.7, math.pi, 6)
    return img


def circle_icon():
    img, d = cell()
    d.ellipse([p(1, 1), p(31, 31)], fill=255)
    return img


def main():
    out = os.path.join(sys.argv[1] if len(sys.argv) > 1 else ".", "Textures", "media.tga")
    icons = [prev_icon(), play_icon(), stop_icon(), next_icon(), shuffle_icon(), loop_icon(), circle_icon()]
    sheet = Image.new("RGBA", (CELL * 8, CELL), (255, 255, 255, 0))
    for i, ic in enumerate(icons):
        a = ic.resize((CELL, CELL), Image.LANCZOS)
        white = Image.new("RGBA", (CELL, CELL), (255, 255, 255, 255))
        white.putalpha(a)
        sheet.paste(white, (i * CELL, 0))
    sheet.save(out, compression=None)
    print("wrote", out)


if __name__ == "__main__":
    main()
