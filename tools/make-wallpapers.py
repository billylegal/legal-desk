#!/usr/bin/env python3
# Draws the three Legal Desk wallpapers (nebula sky, stars, constellations, OMARCHY logo + "LEGAL DESK" marquee).
# usage: make-wallpapers.py OUTDIR      (needs numpy, ImageMagick, rsvg-convert)
import sys, os, subprocess, numpy as np
W, H = 2560, 1440
out = sys.argv[1] if len(sys.argv) > 1 else '.'
os.makedirs(out, exist_ok=True)
TMP = '/tmp/legal-wall'; os.makedirs(TMP, exist_ok=True)

def noise(seed, beta, w=W, h=H):
    r = np.random.default_rng(seed)
    f = np.fft.fft2(r.standard_normal((h, w)))
    fy = np.fft.fftfreq(h)[:, None]; fx = np.fft.fftfreq(w)[None, :]
    k = np.sqrt(fx * fx + fy * fy); k[0, 0] = 1
    n = np.real(np.fft.ifft2(f / k ** beta)); n -= n.min(); return n / n.max()

def mask(cmd):
    p = subprocess.run(cmd, capture_output=True); return p.stdout

def raster_logo(width):
    subprocess.run(['rsvg-convert', '-w', str(width), '/usr/share/omarchy/logo.svg', '-o', f'{TMP}/logo.png'], check=True)
    subprocess.run(['magick', f'{TMP}/logo.png', '-background', 'white', '-alpha', 'remove', '-negate', '-depth', '8', f'{TMP}/logo.pgm'], check=True)
    return read_pgm(f'{TMP}/logo.pgm')

def read_pgm(p):
    b = open(p, 'rb').read(); parts = b.split(None, 4)
    w, h = int(parts[1]), int(parts[2]); return np.frombuffer(parts[4][-w * h:], np.uint8).reshape(h, w) / 255.0

def text_mask(txt, px, spacing):
    subprocess.run(['magick', '-background', 'black', '-fill', 'white', '-font', 'Noto-Sans-Bold', '-pointsize', str(px), '-kerning', str(spacing), f'label:{txt}', '-depth', '8', f'{TMP}/t.pgm'], check=True)
    return read_pgm(f'{TMP}/t.pgm')

def blur(a, s):
    f = np.fft.fft2(a); fy = np.fft.fftfreq(a.shape[0])[:, None]; fx = np.fft.fftfreq(a.shape[1])[None, :]
    return np.real(np.fft.ifft2(f * np.exp(-2 * (np.pi * s) ** 2 * (fx * fx + fy * fy))))

def hexc(h): return np.array([int(h[i:i + 2], 16) for i in (1, 3, 5)], float) / 255

def sky(seed, base, c1, c2, c3, blobs):
    yy, xx = np.mgrid[0:H, 0:W]; xx = xx / W; yy = yy / H
    img = np.zeros((H, W, 3)) + hexc(base)
    n1, n2 = noise(seed, 2.1), noise(seed + 1, 1.7)
    cloud = np.clip((n1 * .65 + n2 * .35 - .38) * 3.2, 0, 1) ** 1.4
    glow = np.zeros((H, W))
    for (bx, by, br, bs) in blobs: glow += bs * np.exp(-(((xx - bx) * W / H) ** 2 + (yy - by) ** 2) / (2 * br * br))
    m = np.clip(glow * (.35 + cloud * 1.1), 0, 1.4)
    t = noise(seed + 2, 2.4)
    col = hexc(c1)[None, None, :] * (1 - t[..., None]) + hexc(c2)[None, None, :] * t[..., None]
    img += col * m[..., None] * .95
    img += hexc(c3)[None, None, :] * (np.clip(m - .75, 0, 1) ** 2 * 1.4)[..., None]
    return img

def stars(img, seed, n):
    r = np.random.default_rng(seed); layer = np.zeros((H, W))
    xs, ys = r.integers(0, W, n), r.integers(0, H, n); br = r.random(n) ** 3
    layer[ys, xs] = .25 + br
    big = br > .8
    img += blur(layer, 1.0)[..., None] * 9 * np.array([.9, .9, 1.0])
    # sparkles on the brightest
    sp = np.zeros((H, W))
    for x, y, b in zip(xs[big], ys[big], br[big]):
        L = int(10 + 26 * b)
        for d in range(-L, L + 1):
            a = (1 - abs(d) / L) ** 2 * .7
            if 0 <= x + d < W: sp[y, x + d] += a
            if 0 <= y + d < H: sp[y + d, x] += a
    img += blur(sp, .7)[..., None] * np.array([.8, .85, 1.0])
    return img

def constellations(img, seed, centers):
    r = np.random.default_rng(seed); lay = np.zeros((H, W)); pts = []
    for (cx, cy, rad, k) in centers:
        p = [(cx + r.normal() * rad, cy + r.normal() * rad * .7) for _ in range(k)]; pts += [(q, p) for q in p]
        for i, a in enumerate(p):
            for b in sorted(p, key=lambda b: (a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2)[1:3]:
                n = int(np.hypot(a[0] - b[0], a[1] - b[1]));
                for t in np.linspace(0, 1, max(n, 2)):
                    x, y = int(a[0] + (b[0] - a[0]) * t), int(a[1] + (b[1] - a[1]) * t)
                    if 0 <= x < W and 0 <= y < H: lay[y, x] = .55
    img += blur(lay, .6)[..., None] * 2.2 * np.array([.8, .8, 1])
    dots = np.zeros((H, W))
    for q, _ in pts:
        x, y = int(q[0]), int(q[1])
        if 3 <= x < W - 3 and 3 <= y < H - 3: dots[y, x] = 1
    img += blur(dots, 2.2)[..., None] * 38 * np.array([1, 1, 1]) + blur(dots, 9)[..., None] * 60 * np.array([.55, .45, 1])
    return img

def paint_logo(img, cx, cy, width, tag_px, tint_top, tint_bot, tag='LEGAL DESK', glow=1.0):
    m = raster_logo(width); h, w = m.shape; x0, y0 = int(cx - w / 2), int(cy - h / 2)
    full = np.zeros((H, W)); full[y0:y0 + h, x0:x0 + w] = m
    g = np.linspace(0, 1, h)[:, None]
    tint = np.zeros((H, W, 3)); tint[y0:y0 + h, x0:x0 + w] = hexc(tint_top) * (1 - g[..., None]) + hexc(tint_bot) * g[..., None]
    img += blur(full, width / 40)[..., None] * hexc(tint_bot) * 1.6 * glow
    img = img * (1 - full[..., None]) + tint * full[..., None]
    t = text_mask(tag, tag_px, tag_px * .55); th, tw = t.shape; tx, ty = int(cx - tw / 2), int(y0 + h + width * .045)
    tm = np.zeros((H, W)); tm[ty:ty + th, tx:tx + tw] = t
    img += blur(tm, tag_px / 8)[..., None] * hexc(tint_bot) * .9
    img = img * (1 - tm[..., None] * .9) + tm[..., None] * .9 * hexc('#E6E1FA')
    return img

def finish(img, name):
    yy, xx = np.mgrid[0:H, 0:W]; v = 1 - .55 * (((xx / W - .5) * 1.5) ** 2 + ((yy / H - .5) * 1.6) ** 2)
    img = np.clip(img * np.clip(v, .35, 1)[..., None], 0, 1.2)
    img = img / (1 + np.clip(img - .85, 0, None) * .8)   # soft shoulder
    img = (np.clip(img, 0, 1) ** (1 / 1.05) * 255).astype(np.uint8)
    p = f'{TMP}/{name}.ppm'; open(p, 'wb').write(b'P6 %d %d 255\n' % (W, H) + img.tobytes())
    subprocess.run(['magick', p, '-quality', '92', f'{out}/{name}.jpg'], check=True)

# 1 - Nebula: violet clouds, big centred logo
im = sky(11, '#05030d', '#6D3BE8', '#B061FF', '#9FB8FF', [(.32, .55, .24, 1.0), (.62, .3, .18, .7), (.8, .75, .2, .8)])
im = constellations(stars(im, 3, 2600), 5, [(1900, 250, 220, 11), (300, 900, 160, 7)])
finish(paint_logo(im, W / 2, H * .46, 1500, 62, '#F3EEFF', '#9B6CFF'), '1-legal-desk-nebula')
# 2 - Aurora: teal / blue / magenta, logo bottom-right
im = sky(23, '#020812', '#1FA8D8', '#7A4BFF', '#C7F4FF', [(.25, .3, .2, 1.0), (.55, .65, .26, .9), (.9, .2, .16, .8)])
im = constellations(stars(im, 8, 2800), 9, [(2000, 400, 240, 12), (500, 1050, 200, 8)])
finish(paint_logo(im, W * .79, H * .8, 640, 28, '#EAFBFF', '#5CC8F5', glow=1.2), '2-legal-desk-aurora')
# 3 - Rosewave: magenta / pink / indigo, logo centred
im = sky(37, '#08020f', '#C13BC4', '#5B35E0', '#FFD0F2', [(.5, .55, .28, 1.0), (.15, .25, .18, .8), (.88, .72, .2, .9)])
im = constellations(stars(im, 13, 2400), 17, [(450, 300, 200, 9), (2150, 1050, 220, 10)])
finish(paint_logo(im, W / 2, H * .48, 1500, 62, '#FFF0FB', '#D86BFF'), '3-legal-desk-rosewave')
print('done')
