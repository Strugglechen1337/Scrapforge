from PIL import Image, ImageDraw, ImageFilter
import random
from pathlib import Path
out = Path(__file__).resolve().parents[1] / 'assets' / 'arena'
out.mkdir(parents=True, exist_ok=True)
for kind in ('oil', 'soot', 'puddle', 'scratch', 'warning'):
    r = random.Random(117 + len(kind))
    im = Image.new('RGBA', (256,256))
    d = ImageDraw.Draw(im)
    if kind in ('oil', 'soot', 'puddle'):
        for _ in range(100):
            x, y = r.gauss(128, 45), r.gauss(128, 35)
            rad = r.randrange(6, 28)
            color = {'oil': (18,20,19,24), 'soot': (25,24,22,18), 'puddle': (29,33,34,26)}[kind]
            d.ellipse((x-rad,y-rad*.65,x+rad,y+rad*.65), fill=color)
        im = im.filter(ImageFilter.GaussianBlur(4))
    elif kind == 'scratch':
        for _ in range(24):
            x, y = r.randrange(20,220), r.randrange(30,225)
            d.line((x,y,x+r.randrange(8,45),y+r.randrange(-4,5)), fill=(110,105,91, r.randrange(20,75)), width=1)
    else:
        d.rectangle((12,82,244,174), fill=(64,57,39,70))
        for x in range(-180,350,55):
            d.polygon([(x,82),(x+26,82),(x+92,174),(x+66,174)], fill=(115,105,68,80))
        for _ in range(400):
            x,y=r.randrange(256),r.randrange(256)
            d.rectangle((x,y,x+r.randrange(1,5),y+r.randrange(1,4)), fill=(0,0,0,0))
    im.save(out / (kind + '.png'))
# Ambient occlusion, roughness and metallic for reflected puddles.
Image.new('RGB',(16,16),(255,35,0)).save(out / 'puddle_orm.png')
