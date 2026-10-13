import sys, os
from PIL import Image
import numpy as np
ADDON = sys.argv[1]
cache = {}
def tex(path):
    if path not in cache:
        name = path.split('\\')[-1]
        im = Image.open(os.path.join(ADDON, 'Textures', name + '.tga')).convert('RGBA')
        cache[path] = np.asarray(im).astype(np.float32) / 255.0
    return cache[path]
def compose(dump, out, scale=2):
    W, H = 320 * scale, 200 * scale
    canvas = np.zeros((H, W, 3), np.float32)
    for line in open(dump):
        p = line.split()
        if p[0] == 'C':
            r, g, b, a = map(float, p[1:5])
            canvas = canvas * (1 - a) + np.array([r, g, b]) * a
            continue
        path = p[1]
        x, y, w, h, u0, u1, v0, v1, r, g, b, a = map(float, p[2:14])
        mode = p[14]
        t = tex(path)
        th, tw = t.shape[:2]
        dx0, dy0 = int(round(x * scale)), int(round(y * scale))
        dw, dh = int(round(w * scale)), int(round(h * scale))
        if dw <= 0 or dh <= 0: continue
        xs = np.clip(((u0 + (u1 - u0) * (np.arange(dw) + 0.5) / dw) * tw).astype(int), 0, tw - 1)
        ys = np.clip(((v0 + (v1 - v0) * (np.arange(dh) + 0.5) / dh) * th).astype(int), 0, th - 1)
        src = t[ys][:, xs]
        x0, y0 = max(dx0, 0), max(dy0, 0)
        x1, y1 = min(dx0 + dw, W), min(dy0 + dh, H)
        if x1 <= x0 or y1 <= y0: continue
        src = src[y0 - dy0:y1 - dy0, x0 - dx0:x1 - dx0]
        col = src[..., :3] * np.array([r, g, b])
        al = src[..., 3:4] * a
        dst = canvas[y0:y1, x0:x1]
        if mode == 'ADD':
            dst = dst + col * al
        elif mode == 'MOD':
            dst = dst * (col * al + (1 - al))
        else:
            dst = dst * (1 - al) + col * al
        canvas[y0:y1, x0:x1] = np.clip(dst, 0, 1)
    Image.fromarray((canvas * 255).astype(np.uint8)).save(out)
for d in sys.argv[2:]:
    compose(d, d.replace('.txt', '.png'))
    print('wrote', d.replace('.txt', '.png'))
