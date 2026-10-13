"""Tile pattern model.

Rows are generated upward ('below' is the row already placed).  Every 2x2
window of generated rows occurs somewhere in the source maps, so joins are
seamless."""
import collections


class Model:
    def __init__(self, maps):
        self.pat = collections.defaultdict(collections.Counter)   # (aL, bL, b) -> Counter(a)
        self.first = collections.defaultdict(collections.Counter) # b0 -> Counter(a0)
        for m in maps:
            for i in range(len(m) - 1, 0, -1):
                b, a = m[i], m[i - 1]
                self.first[b[0]][a[0]] += 1
                for c in range(1, len(a)):
                    self.pat[(a[c-1], b[c-1], b[c])][a[c]] += 1
        self.win = set()                 # (aL, a, bL, b)
        self.vert0 = set()               # (a0, b0)
        for (aL, bL, b), cnt in self.pat.items():
            for a in cnt:
                self.win.add((aL, a, bL, b))
        for b0, cnt in self.first.items():
            for a0 in cnt:
                self.vert0.add((a0, b0))

    def fits(self, below, above):
        if (above[0], below[0]) not in self.vert0:
            return False
        return all((above[c-1], above[c], below[c-1], below[c]) in self.win for c in range(1, len(below)))

    def row(self, below, rng, above=None):
        """A row over `below` (and under `above` when given), or None."""
        W = len(below)
        memo = {}

        def cands(c, prev):
            cnt = self.first.get(below[0]) if c == 0 else self.pat.get((prev, below[c-1], below[c]))
            if not cnt:
                return ()
            if above is None:
                return cnt.items()
            if c == 0:
                return [(t, w) for t, w in cnt.items() if (above[0], t) in self.vert0]
            return [(t, w) for t, w in cnt.items() if (above[c-1], above[c], prev, t) in self.win]

        def feasible(c, t):
            if c == W - 1:
                return True
            k = (c, t)
            r = memo.get(k)
            if r is None:
                r = any(feasible(c + 1, u) for u, _ in cands(c + 1, t))
                memo[k] = r
            return r

        out, prev = [], None
        for c in range(W):
            items = [(t, w) for t, w in cands(c, prev) if feasible(c, t)]
            if not items:
                return None
            x = rng.random() * sum(w for _, w in items)
            for t, w in items:
                x -= w
                if x <= 0:
                    break
            out.append(t)
            prev = t
        return tuple(out)

    def bridge(self, below, above, rng, maxlen=6, tries=12):
        """Rows (bottom to top) leading from `below` up to just under `above`,
        [] if they already fit, None if no bridge was found."""
        if self.fits(below, above):
            return []
        for _ in range(tries):
            path, cur = [], below
            for _ in range(maxlen):
                r = self.row(cur, rng, above)
                if r is not None:
                    return path + [r]
                r = self.row(cur, rng)
                if r is None:
                    break
                path.append(r)
                cur = r
        return None
