"""Reads the Tyrian level files the same way JE_loadMap does.

Map cells are resolved to tile ids: tile index + 1 into the level's tile set
(shapes?.dat), or 0 for "nothing drawn".  Like the game, bytes past the
lookup limit, out of range entries and (for layers 2 and 3) blank tiles are 0.
"""
import os, re, struct

LAYERS = ((14, 300, 71), (14, 600, 70), (15, 600, 69))   # width, height, byte limit
KEY = (204, 129, 63, 255, 71, 19, 25, 62, 1, 99)


def episode_strings(data_dir, ep):
    raw = open(os.path.join(data_dir, 'levels%d.dat' % ep), 'rb').read()
    out, p = [], 0
    while p < len(raw):
        n = raw[p]; p += 1
        s = bytearray(raw[p:p + n]); p += n
        for i in range(len(s) - 1, -1, -1):
            s[i] ^= KEY[i % 10]
            if i > 0:
                s[i] ^= s[i - 1]
        out.append(s.decode('latin1'))
    return out


def level_names(data_dir, ep):
    """lvlFileNum -> [(level name, song)] from the ]L lines of the episode script."""
    names = {}
    for s in episode_strings(data_dir, ep):
        if s.startswith(']L'):
            m = re.match(r'\s*(\d+)', s[24:])
            song = re.match(r'\s*(\d+)', s[22:])
            if m:
                names.setdefault(int(m.group(1)), []).append((s[13:22].strip(), int(song.group(1)) if song else 1))
    return names


def blank_tiles(data_dir, key):
    d = open(os.path.join(data_dir, 'shapes%s.dat' % key), 'rb').read()
    blank, p = [], 0
    for _ in range(600):
        if p >= len(d):
            blank.append(True)
            continue
        b = d[p] != 0
        p += 1
        if not b:
            p += 672
        blank.append(b)
    return blank


def read_levels(data_dir, ep, nums, blanks):
    fname = 'tyrian%d.lvl' % ep
    raw = open(os.path.join(data_dir, fname), 'rb').read()
    n = struct.unpack_from('<H', raw, 0)[0]
    pos = struct.unpack_from('<%dI' % n, raw, 2)
    levels = []
    for num in sorted(nums):
        p = pos[(num - 1) * 2]
        if p >= len(raw):
            continue
        shape = chr(raw[p + 1]).lower(); p += 8
        ne = struct.unpack_from('<H', raw, p)[0]; p += 2 + 2 * ne
        enemies = struct.unpack_from('<%dH' % ne, raw, p - 2 * ne)
        nev = struct.unpack_from('<H', raw, p)[0]; p += 2
        events = []
        for _ in range(nev):
            t, typ, d, d2, d3, d5, d6, d4 = struct.unpack_from('<HBhhbbbB', raw, p); p += 11
            events.append(dict(t=t, type=typ, d=d, d2=d2, d3=d3, d5=d5, d6=d6, d4=d4))
        mapsh = [struct.unpack_from('>128H', raw, p + k * 256) for k in range(3)]; p += 768
        if shape not in blanks:
            blanks[shape] = blank_tiles(data_dir, shape)
        blank = blanks[shape]
        lookups, maps, offsets = [], [], []
        for k, (w, h, limit) in enumerate(LAYERS):
            lut = []
            for b in range(256):
                v = mapsh[k][b] if b <= limit else 0
                if not 1 <= v <= 600 or (k > 0 and blank[v - 1]):
                    v = 0
                lut.append(v)
            data = raw[p:p + w * h]
            offsets.append(p); p += w * h
            maps.append([tuple(lut[data[r * w + c]] for c in range(w)) for r in range(h)])
            lookups.append(lut)
        levels.append(dict(file=fname, ep=ep, num=num, shape=shape, enemies=enemies, events=events,
                           L=maps, lut=lookups, off=offsets))
    return levels


def load_all(data_dir):
    blanks, out = {}, []
    for ep in (1, 2, 3, 4):
        names = level_names(data_dir, ep)
        for lv in read_levels(data_dir, ep, names.keys(), blanks):
            info = names.get(lv['num'], [])
            lv['names'] = [n for n, _ in info]
            lv['song'] = info[0][1] if info else 1
            out.append(lv)
    return out


def sprite2_fill(sheet, index):
    """Opaque fraction of 12x14 cell `index` (1-based) of a sprite2 sheet."""
    if (index - 1) * 2 + 1 >= len(sheet):
        return 0
    i = struct.unpack_from('<H', sheet, (index - 1) * 2)[0]
    seen, x, y = set(), 0, 0
    while i < len(sheet) and sheet[i] != 0x0F and y <= 40:
        b = sheet[i]
        x += b & 0x0F
        cnt = b >> 4
        if cnt == 0:
            y += 1
            x -= 12
        else:
            for _ in range(cnt):
                i += 1
                if 0 <= x < 12 and 0 <= y < 14:
                    seen.add((x, y))
                x += 1
        i += 1
    return len(seen) / 168


def sheet_fills(data_dir):
    """{'newsh2': [fill of cell 1, cell 2, ...], ...} for the enemy sheets."""
    out = {}
    for fn in sorted(os.listdir(data_dir)):
        if fn.startswith('newsh') and fn.endswith('.shp') and fn[5] != '~':
            sheet = open(os.path.join(data_dir, fn), 'rb').read()
            count = struct.unpack_from('<H', sheet, 0)[0] // 2
            out['newsh' + fn[5].lower()] = [sprite2_fill(sheet, i) for i in range(1, count + 1)]
    return out
