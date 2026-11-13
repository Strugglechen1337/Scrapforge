"""Reproducible floor decals and floor mask for the arena (own work, CC0).

Run: python tools/generate_arena_decals.py   (needs Pillow)
"""
from PIL import Image, ImageDraw, ImageFilter
import random
from pathlib import Path

out = Path(__file__).resolve().parents[1] / 'assets' / 'arena'
out.mkdir(parents=True, exist_ok=True)
SIZE = 256


def blob_alpha(r, count, spread, rad, aspect, peak, blur):
    """Soft irregular stain as an alpha mask."""
    mask = Image.new('L', (SIZE, SIZE), 0)
    d = ImageDraw.Draw(mask)
    for _ in range(count):
        x, y = r.gauss(128, spread[0]), r.gauss(128, spread[1])
        rr = r.randrange(*rad)
        d.ellipse((x - rr, y - rr * aspect, x + rr, y + rr * aspect), fill=peak)
    mask = mask.filter(ImageFilter.GaussianBlur(blur))
    # fade to zero at the borders so the decal box never shows an edge
    edge = Image.new('L', (SIZE, SIZE), 0)
    ImageDraw.Draw(edge).ellipse((14, 14, SIZE - 14, SIZE - 14), fill=255)
    edge = edge.filter(ImageFilter.GaussianBlur(22))
    return Image.composite(mask, Image.new('L', (SIZE, SIZE), 0), edge).point(lambda v: v)


def stain(kind, color, count, spread, rad, aspect, peak, blur, seed):
    r = random.Random(seed)
    alpha = blob_alpha(r, count, spread, rad, aspect, peak, blur)
    # multiply with the edge falloff
    edge = Image.new('L', (SIZE, SIZE), 0)
    ImageDraw.Draw(edge).ellipse((10, 10, SIZE - 10, SIZE - 10), fill=255)
    edge = edge.filter(ImageFilter.GaussianBlur(24))
    alpha = Image.eval(alpha, lambda v: v)
    px, ex = alpha.load(), edge.load()
    for y in range(SIZE):
        for x in range(SIZE):
            px[x, y] = px[x, y] * ex[x, y] // 255
    im = Image.new('RGBA', (SIZE, SIZE), color + (0,))
    im.putalpha(alpha)
    im.save(out / (kind + '.png'))


# dark, low contrast: oil and soot darken the plates, the puddle mirrors the sky
stain('oil', (13, 13, 15), 60, (34, 26), (8, 26), 0.7, 215, 4, 1)
stain('soot', (18, 17, 15), 90, (46, 36), (6, 22), 0.75, 190, 5, 2)
stain('puddle', (40, 46, 54), 40, (26, 18), (14, 34), 0.62, 245, 3, 3)

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
Image.new('RGB', (16, 16), (255, 14, 255)).save(out / 'puddle_orm.png')
Image.new('RGB', (16, 16), (255, 70, 90)).save(out / 'oil_orm.png')

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