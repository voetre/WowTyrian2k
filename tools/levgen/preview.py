"""Renders tile maps with the converted tile atlases (needs Pillow)."""
import os
from PIL import Image

TEX = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'Textures')
_atlas = {}


def atlas(key):
    if key not in _atlas:
        name = 'tiles_%s.tga' % ('paren' if key == ')' else key)
        _atlas[key] = Image.open(os.path.join(TEX, name)).convert('RGBA')
    return _atlas[key]


def render(key, layers):
    """layers: lists of rows (top first); later layers are drawn on top."""
    A = atlas(key)
    H = len(layers[0])
    W = max(len(l[0]) for l in layers)
    img = Image.new('RGBA', (W * 24, H * 28), (0, 0, 0, 255))
    for L in layers:
        for r, row in enumerate(L):
            for c, t in enumerate(row):
                if not 1 <= t <= 600:
                    continue
                z = t - 1
                x, y = (z % 39) * 26 + 1, (z // 39) * 30 + 1
                img.alpha_composite(A.crop((x, y, x + 24, y + 28)), (c * 24, r * 28))
    return img


def strips(key, layers, path, n=5, rows=60, scale=3):
    """One image per layer: the first n*rows rows of it, cut into n strips."""
    for k, L in enumerate(layers):
        parts = [render(key, [L[i * rows:(i + 1) * rows]]) for i in range(n)]
        w, h = parts[0].size
        out = Image.new('RGBA', (n * (w + 8), h), (255, 255, 255, 255))
        for i, p in enumerate(parts):
            out.paste(p, (i * (w + 8), 0))
        root, ext = os.path.splitext(path)
        out.resize((out.width // scale, out.height // scale)).save('%s_L%d%s' % (root, k + 1, ext))
