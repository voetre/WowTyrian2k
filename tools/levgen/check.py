"""Checks maps dumped by the game's LevelGen (one row per line, bottom to
top) against the source levels, and renders previews.

Usage:  python3 check.py <tyrian21 data dir> <dump dir> [png dir]"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from parse import load_all
from model import Model

data, dump = sys.argv[1], sys.argv[2]
png = sys.argv[3] if len(sys.argv) > 3 else None
levels = load_all(data)
bad_total = 0
for key in sorted({lv['shape'] for lv in levels}):
    name = 'paren' if key == ')' else key
    layers = []
    for layer in range(3):
        path = os.path.join(dump, 'lg_%s_%d.txt' % (name, layer + 1))
        rows = [tuple(int(x) for x in l.split()) for l in open(path)]
        model = Model([lv['L'][layer] for lv in levels if lv['shape'] == key])
        bad = sum(1 for i in range(1, len(rows)) if not model.fits(rows[i - 1], rows[i]))
        bad_total += bad
        print('%s layer %d: %d rows, %d bad joins' % (key, layer + 1, len(rows), bad))
        layers.append(rows[::-1])   # top first for drawing
    if png:
        from preview import render, strips
        strips(key, layers, os.path.join(png, 'lg_%s.png' % name))
print('bad joins total:', bad_total)
