"""Builds the level generator library (Data/levgen.lua) from the Tyrian data.

Usage:  python3 build.py <tyrian21 data dir> <addon dir> [--seed N]

Each tile set's maps are cut into segments.  A segment's natural successor (the
segment above it in its source map) is always an edge; a few more successors
per segment are joined with generated bridge rows.  The game walks this graph.
Only the themes in THEMES are built, each from its own levels, so a
generated level never mixes art from different places.
Identical segments are merged, so edges carry weights (how often the source
maps make that step) and a segment can follow itself; without them the long
empty stretches of layers 2 and 3 would come out far too rare.
Segments are stored as row ranges of the level files the addon already has, so
the output is small.  It is derived from Tyrian data, so like the rest of Data/
it must not be published.
"""
import collections, os, random, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from parse import load_all, sheet_fills, LAYERS
from preview import atlas

L3_ART = 100            # layer 3 tiles a theme needs for its layer 3 to count as art
from model import Model

SEG = (20, 40, 40)      # rows per segment; layers 2 and 3 scroll twice as fast
EXTRA = 4               # bridged successors wanted per segment
CANDIDATES = 16         # candidates tried for them
COMMON = 3              # most common segments every segment tries to reach
# The themes generated levels use: (name for /tyrian genlevel, tile set,
# levels whose maps and enemy waves it is made from).
THEMES = [
    ('forest', 'x', ['TORM']),       # green forest, rivers, waterfalls, blimps
    ('ocean', 'y', ['APPROACH']),    # open sea with fighter planes
    # ('fleet', 'w', ['FLEET']) was dropped: its capital ships' guns are
    # invisible enemies on map art the generator can't place
]


def level_name(lv):
    return (lv['names'][0] if lv['names'] else '').strip()


def tile_colours(key):
    """Mean colour of every tile of tile set `key`, 0-63 per channel, as a
    string of 3 characters per tile (code 40 + value).  The game compares the
    ground under scenery enemies by colour (sand vs metal, dirt vs grass)."""
    A = atlas(key)
    out = []
    for z in range((A.height // 30) * 39):
        x, y = (z % 39) * 26 + 1, (z // 39) * 30 + 1
        px = A.crop((x, y, x + 24, y + 28)).getdata()
        n = len(px)
        out.append(''.join(chr(40 + sum(p[i] for p in px) // n // 4) for i in range(3)))
    return ''.join(out)


def build_set(levels, layer, rng):
    w, h, _ = LAYERS[layer]
    seglen = SEG[layer]
    maps = [lv['L'][layer] for lv in levels]
    model = Model(maps)
    segs, key_of = [], {}
    natural = collections.Counter()           # (i, j) -> times j follows i
    count = collections.Counter()             # i -> times segment i occurs
    for li, lv in enumerate(levels):
        prev = None
        for i in range(h // seglen):            # bottom segment first
            top = h - seglen * (i + 1)
            rows = tuple(maps[li][top:top + seglen])
            sid = key_of.get(rows)
            if sid is None:
                sid = len(segs)
                key_of[rows] = sid
                segs.append(dict(src=lv['src'], top=top, rows=rows))
            count[sid] += 1
            if prev is not None:
                natural[(prev, sid)] += 1
            prev = sid
    n = len(segs)
    edges = {i: {} for i in range(n)}          # i -> {j: bridge rows (bottom to top)}
    for i, j in natural:
        edges[i][j] = []

    tops = [set(s['rows'][0]) for s in segs]
    bottoms = [set(s['rows'][-1]) for s in segs]
    # the most common segments (above all the empty one on layers 2 and 3)
    # must be reachable from everywhere, or the walk rarely gets back to them
    common = [j for j, _ in count.most_common(COMMON)]
    for i in range(n):
        ranked = sorted((j for j in range(n) if j != i and j not in edges[i]),
                        key=lambda j: -len(tops[i] & bottoms[j]) - rng.random() * 3)
        for j in common:
            if j != i and j not in edges[i]:
                b = model.bridge(segs[i]['rows'][0], segs[j]['rows'][-1], rng, maxlen=10, tries=24)
                if b is not None:
                    edges[i][j] = b
        found = 0
        for j in ranked[:CANDIDATES]:
            if j in edges[i]:
                continue
            b = model.bridge(segs[i]['rows'][0], segs[j]['rows'][-1], rng)
            if b is not None:
                edges[i][j] = b
                found += 1
                if found >= EXTRA:
                    break
    # keep only the largest strongly connected component (segments that can
    # all reach each other), so no walk gets trapped in a corner of the graph
    # such as a run of solid water
    def reach(adj, start):
        seen, todo = {start}, [start]
        while todo:
            for j in adj[todo.pop()]:
                if j not in seen:
                    seen.add(j)
                    todo.append(j)
        return seen
    back = {i: [] for i in range(n)}
    for i in range(n):
        for j in edges[i]:
            back[j].append(i)
    alive, done = set(), set()
    for i in range(n):
        if i not in done:
            comp = reach(edges, i) & reach(back, i)
            done |= comp
            if len(comp) > len(alive):
                alive = comp
    # on the overlay layers the most common segment is the empty one, and its
    # component is kept even if smaller: an overlay with too little art looks
    # far better than one that never clears (x layer 3 ends up empty)
    if layer > 0 and common[0] not in alive:
        alive = reach(edges, common[0]) & reach(back, common[0])
        print('  overlay: kept the empty segment\'s component (%d segments)' % len(alive))
    order = sorted(alive)
    newid = {old: k + 1 for k, old in enumerate(order)}
    out = dict(w=w, seglen=seglen, segs=[], nxt=[], bridges=[])
    for old in order:
        s = segs[old]
        out['segs'].append((s['src'], s['top']))
        lst = []
        for j, b in edges[old].items():
            if j not in alive:
                continue
            bid = 0
            if b:
                out['bridges'].append(b)
                bid = len(out['bridges'])
            # natural continuations are flagged negative so the game can favour
            # them; weight: natural steps by how often they occur, bridged ones 1
            if (old, j) in natural:
                lst.append((newid[j], -1, natural[(old, j)]))
            else:
                lst.append((newid[j], bid, 1))
        out['nxt'].append(lst)
    return out, n - len(alive)


def lua_str(s):
    return '"%s"' % s.replace('\\', '\\\\').replace('"', '\\"')


def lua_list(xs):
    return '{' + ','.join(str(x) for x in xs) + '}'


def main():
    data, addon = sys.argv[1], sys.argv[2]
    seed = 1
    args = sys.argv[3:]
    while args:
        a = args.pop(0)
        if a == '--seed':
            seed = int(args.pop(0))
    rng = random.Random(seed)
    levels = load_all(data)
    srcs = []
    for lv in levels:
        lv['src'] = len(srcs) + 1
        srcs.append(lv)
    out = ['-- Generated by tools/levgen/build.py from Tyrian 2.1 data.  Do not publish.',
           'local _, ns = ...', 'local G = { src = {}, themes = {}, fill = {}, col = {} }', 'ns.levgen = G', 'local S = G.src']
    for k, lv in enumerate(srcs):
        luts = ','.join(lua_list(lv['lut'][i][:LAYERS[i][2] + 1]) for i in range(3))
        name = (lv['names'][0] if lv['names'] else '').replace('\\', '').replace('"', '')
        out.append('S[%d] = { file = "%s", ep = %d, num = %d, shape = "%s", song = %d, name = "%s", off = %s, lut = { %s } }' % (
            k + 1, lv['file'], lv['ep'], lv['num'], lv['shape'], lv['song'], name, lua_list(lv['off']), luts))
    # how much of each enemy sprite cell is opaque, in tenths (0-9, 9 = 0.9 or
    # more): solid sprites carry their own patch of ground or rock
    for key, fills in sorted(sheet_fills(data).items()):
        out.append('G.fill[%s] = "%s"' % (lua_str(key), ''.join(str(min(int(f * 10), 9)) for f in fills)))
    for sh in sorted({key for _, key, _ in THEMES}):
        out.append('G.col[%s] = %s' % (lua_str(sh), lua_str(tile_colours(sh))))
    for ti, (tname, sh, names) in enumerate(THEMES):
        theme = [lv for lv in levels if lv['shape'] == sh and level_name(lv) in names]
        found = sorted({level_name(lv) for lv in theme})
        if set(found) != set(names):
            sys.exit('theme %s: levels %s not found on tile set %s' % (tname, set(names) - set(found), sh))
        print('theme %s (tile set %s): %s' % (tname, sh, ', '.join(found)))
        l3 = sum(1 for lv in theme for row in lv['L'][2] for t in row if t)
        out.append('G.themes[%d] = { name = %s, key = %s, src = %s,' % (
            ti + 1, lua_str(tname), lua_str(sh), lua_list(lv['src'] for lv in theme)))
        # layer 3 enemies sit on layer 3 art (TYRIAN's rocks) only in
        # themes that have some
        out.append('  l3art = %s,' % ('true' if l3 >= L3_ART else 'false'))
        for layer in range(3):
            t = time.time()
            lvs = theme
            if layer == 2 and l3 < L3_ART:
                # a few stray tiles (CAMANIS's 30 off the visible map) are
                # not art; tiling them gives stripes all over the map
                lvs = [dict(lv, L=lv['L'][:2] + [[(0,) * len(r) for r in lv['L'][2]]]) for lv in theme]
            s, pruned = build_set(lvs, layer, rng)
            nedge = sum(len(x) for x in s['nxt'])
            print('  layer %d: %d segments (%d pruned), %d edges, %d bridges, %.1fs' % (
                layer + 1, len(s['segs']), pruned, nedge, len(s['bridges']), time.time() - t))
            out.append('  [%d] = { w = %d, seglen = %d,' % (layer + 1, s['w'], s['seglen']))
            out.append('   seg = %s,' % lua_list(x for st in s['segs'] for x in st))
            out.append('   nxt = {' + ','.join(lua_list(x for e in l for x in e) for l in s['nxt']) + '},')
            out.append('   br = {' + ','.join(lua_list(x for r in b for x in r) for b in s['bridges']) + '} },')
        out.append('}')
    path = os.path.join(addon, 'Data', 'levgen.lua')
    with open(path, 'w') as f:
        f.write('\n'.join(out) + '\n')
    print('wrote', path, os.path.getsize(path), 'bytes')


if __name__ == '__main__':
    main()
