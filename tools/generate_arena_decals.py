"""Reproducible floor decals and floor mask for the arena (own work, CC0).

Run: python tools/generate_arena_decals.py   (needs Pillow)
"""
from PIL import Image, ImageDraw, ImageFilter
import random
from pathlib import Path

out = Path(__file__).resolve().parents[1] / 'assets' / 'arena'
out.mkdir(parents=True, exist_ok=True)
SIZE = 256


def crisp_stain(kind, seed, count, spread, rad, aspect, level, core, rim, alpha_max, grain=0):
    """Irregular stain with a clear contour: blobs are blurred, then cut at a level.
    The distance inside the contour darkens the core; grain breaks up soot."""
    r = random.Random(seed)
    field = Image.new('L', (SIZE, SIZE), 0)
    d = ImageDraw.Draw(field)
    for _ in range(count):
        x = min(max(r.gauss(128, spread[0]), 50), 206)
        y = min(max(r.gauss(128, spread[1]), 50), 206)
        rr = r.randrange(*rad)
        d.ellipse((x - rr, y - rr * aspect, x + rr, y + rr * aspect), fill=255)
    field = field.filter(ImageFilter.GaussianBlur(9))
    noise = Image.new('L', (32, 32))
    noise.putdata([r.randrange(256) for _ in range(32 * 32)])
    noise = noise.resize((SIZE, SIZE), Image.Resampling.BICUBIC)
    fp, npx = field.load(), noise.load()
    im = Image.new('RGBA', (SIZE, SIZE))
    ip = im.load()
    for y in range(SIZE):
        for x in range(SIZE):
            v = fp[x, y] + (npx[x, y] - 128) * 0.35
            if v < level:
                ip[x, y] = rim + (0,)
                continue
            depth = min((v - level) / 70.0, 1.0)  # 0 at the contour, 1 in the core
            col = tuple(int(rim[i] + (core[i] - rim[i]) * depth) for i in range(3))
            a = alpha_max
            if grain:
                a = int(alpha_max * min(1.0, 0.35 + depth) * (1.0 - grain * npx[(x * 3) % SIZE, (y * 3) % SIZE] / 255.0))
            ip[x, y] = col + (a,)
    # one pixel of anti-aliasing on the contour only
    a = im.getchannel('A').filter(ImageFilter.GaussianBlur(0.8))
    im.putalpha(a)
    im.save(out / (kind + '.png'))


# Oil: dark glossy film with a clear edge. Puddle: small, sharp, black core that
# mirrors the sky through low roughness (ORM). Soot: dark, ragged, uneven.
crisp_stain('oil', 11, 34, (30, 22), (8, 24), 0.7, 120, (5, 5, 6), (12, 12, 13), 235)
crisp_stain('puddle', 12, 14, (16, 12), (10, 24), 0.62, 130, (3, 4, 5), (10, 11, 12), 245)
crisp_stain('soot', 13, 70, (34, 28), (5, 18), 0.8, 90, (6, 6, 6), (16, 15, 14), 215, grain=0.45)
# scratches: worn bright metal lines
r = random.Random(4)
im = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
d = ImageDraw.Draw(im)
for _ in range(34):
    x, y = r.randrange(10, 200), r.randrange(30, 225)
    d.line((x, y, x + r.randrange(14, 70), y + r.randrange(-6, 7)), fill=(150, 146, 134, r.randrange(90, 190)), width=r.choice((1, 1, 2)))
im.save(out / 'scratch.png')

# warning marking: diagonal muted yellow stripes between two worn bars, chipped
r = random.Random(5)
im = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
d = ImageDraw.Draw(im)
d.rectangle((0, 70, SIZE, 186), fill=(22, 21, 19, 190))
for x in range(-180, 360, 64):
    d.polygon([(x, 70), (x + 32, 70), (x + 96, 186), (x + 64, 186)], fill=(104, 86, 40, 200))
chip = Image.new('L', (SIZE, SIZE), 255)
cd = ImageDraw.Draw(chip)
for _ in range(900):
    x, y = r.randrange(SIZE), r.randrange(SIZE)
    cd.rectangle((x, y, x + r.randrange(1, 7), y + r.randrange(1, 5)), fill=r.choice((0, 0, 90)))
a = im.getchannel('A')
px, cp = a.load(), chip.load()
for y in range(SIZE):
    for x in range(SIZE):
        px[x, y] = px[x, y] * cp[x, y] // 255
im.putalpha(a)
im.save(out / 'warning.png')

# ORM: R occlusion, G roughness, B metallic. Puddle is a near-mirror, oil a glossy film.
Image.new('RGB', (16, 16), (255, 8, 0)).save(out / 'puddle_orm.png')
Image.new('RGB', (16, 16), (255, 60, 0)).save(out / 'oil_orm.png')

# One reproducible low-frequency mask; channels decorrelate wear, tone and rust.
r = random.Random(8125)
channels = []
for width, height in ((20, 14), (9, 7), (35, 25)):
    cells = [r.randrange(256) for _ in range(width * height)]
    small = Image.new('L', (width, height))
    small.putdata(cells)
    # tile 3x3 before filtering so the mask repeats without a seam, then crop the middle
    tiled = Image.new('L', (width * 3, height * 3))
    for ix in range(3):
        for iy in range(3):
            tiled.paste(small, (ix * width, iy * height))
    big = tiled.resize((768, 768), Image.Resampling.BICUBIC).filter(ImageFilter.GaussianBlur(2))
    channels.append(big.crop((256, 256, 512, 512)))
Image.merge('RGB', tuple(channels)).save(out / 'floor_mask.png')