"""Festival app icons: the everyday Jeya icon, untouched, with the festival's thoranam hung across
its top — mango leaves and marigolds (Deepavali), aavaram poo (Pongal), a pine garland with
baubles (Christmas & New Year), roses with little hearts (Valentine's Day), a mango-leaf
fringe with malli, kanakambaram and konrai bunches (Tamil New Year), little lanterns, stars and
crescents on a gold chain (Eid), tricolour bunting with rosettes (Independence & Republic Day).

Writes app/branding/app_icon/<festival>/ (Android launcher mipmaps + iOS AppIcon), next to the
everyday set in app/branding/app_icon/standard/. Switch the app between them with
app/tool/app_icon.sh. Needs out/ renders: run `node render.mjs --dir out/icons` after this
script writes the garland SVGs (it does that itself through sharp).
"""
import io
import json
import math
import os
import shutil
import subprocess

from PIL import Image

from svgkit import SVG, f, marigold, mango_leaf
from header_art import bell
from pongal_art import aavaram, poolai
from christmas_art import bauble, bow, pine_branch, warm_light
from valentine_art import heart, rose, rose_leaf
from puthandu_art import kanakambaram, konrai_cluster, malli
from eid_art import gold_crescent, lantern, star5
from national_art import TRI, pennant, rosette as tri_rosette

APP = '../../app'
ANDROID_RES = f'{APP}/android/app/src/main/res'
IOS_ICONS = f'{APP}/ios/Runner/Assets.xcassets/AppIcon.appiconset'
DENSITIES = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}
OUT = 'out/icons'
os.makedirs(OUT, exist_ok=True)

# The garland is drawn on a 432 × 432 canvas (the xxxhdpi adaptive-icon foreground, 108 dp) and
# hangs across the top of the visible circle; its rope ends sit just outside the round mask.
W = 432
X0, X1, Y0, SAG = 46, 386, 70, 46


def _rope(t):
    cx, cy = (X0 + X1) / 2, Y0 + 2 * SAG
    x = (1 - t) ** 2 * X0 + 2 * (1 - t) * t * cx + t * t * X1
    y = (1 - t) ** 2 * Y0 + 2 * (1 - t) * t * cy + t * t * Y0
    dx = 2 * (1 - t) * (cx - X0) + 2 * t * (X1 - cx)
    dy = 2 * (1 - t) * (cy - Y0) + 2 * t * (Y0 - cy)
    return x, y, math.degrees(math.atan2(dy, dx))


def _rope_path(colour='#5D4037', width=5):
    cx, cy = (X0 + X1) / 2, Y0 + 2 * SAG
    return f'<path d="M {X0},{Y0} Q {f(cx)},{f(cy)} {X1},{Y0}" stroke="{colour}" stroke-width="{width}" fill="none" stroke-linecap="round"/>'


def garland(festival):
    s = SVG(W, W, seed=5)
    rnd = s.rnd
    back, mid, front = [], [], []
    if festival == 'diwali':
        mid.append(_rope_path())
        for i in range(9):
            x, y, ang = _rope(0.08 + i * 0.105)
            if i % 2 == 0:
                back.append(mango_leaf(s, x, y + 6, 58, 22, angle=ang + rnd.uniform(-8, 8), tone=i))
            front.append(marigold(s, x, y, 19 if i % 2 else 17, 'orange' if i % 3 else 'yellow'))
        x, y, _ = _rope(0.5)
        front.append(bell(s, x, y + 22, 18))
    elif festival == 'pongal':
        mid.append(_rope_path())
        for i in range(11):
            x, y, ang = _rope(0.06 + i * 0.088)
            if i % 2 == 0:
                back.append(mango_leaf(s, x, y + 6, 56, 21, angle=ang + rnd.uniform(-8, 8), tone=i))
            front.append(poolai(s, x, y, 12) if i % 3 == 1 else aavaram(s, x, y, 16, rot=rnd.uniform(0, 72)))
    elif festival == 'christmas':
        for i in range(60):
            x, y, ang = _rope((i + 0.5) / 60)
            back.append(pine_branch(s, x, y, rnd.uniform(30, 40), ang + (180 if i % 2 else 0) + rnd.uniform(-40, 40) * (1 if i % 2 else -1), tone=i))
        for i in range(7):
            x, y, _ = _rope(0.14 + i * 0.12)
            if i % 2 == 0:
                drop = 22
                front.append(f'<line x1="{f(x)}" y1="{f(y)}" x2="{f(x)}" y2="{f(y + drop - 10)}" stroke="#E0C080" stroke-width="1.6"/>')
                front.append(bauble(s, x, y + drop, 13, 'red' if i % 4 == 0 else 'gold'))
            else:
                front.append(warm_light(s, x, y + 4, 5))
        x, y, _ = _rope(0.5)
        front.append(bow(s, x, y - 2, 16))
    elif festival == 'valentine':
        mid.append(_rope_path('#F48FB1', 6))
        for i in range(10):
            x, y, ang = _rope(0.07 + i * 0.096)
            back.append(rose_leaf(s, x, y + 3, 26, ang + (60 if i % 2 else 120)))
            front.append(rose(s, x, y + 2, 15, 'red' if i % 3 else 'pink'))
            if i % 3 == 1:
                front.append(f'<line x1="{f(x)}" y1="{f(y + 12)}" x2="{f(x)}" y2="{f(y + 34)}" stroke="#F8BBD0" stroke-width="1.6"/>')
                front.append(heart(s, x, y + 42, 18, shadow=False))
    elif festival == 'puthandu':
        for i in range(11):
            x, y, ang = _rope(0.05 + i * 0.09)
            back.append(mango_leaf(s, x, y + 5, rnd.uniform(40, 46), 18, angle=ang * 0.6 + rnd.uniform(-6, 6), tone=i))
        mid.append(_rope_path())
        for i in range(13):
            x, y, ang = _rope(0.05 + i * 0.075)
            front.append(kanakambaram(s, x, y, 11, rot=ang + 90) if i % 4 in (1, 2) else malli(s, x, y, 10, rot=rnd.uniform(0, 60)))
        for t in (0.22, 0.78):
            x, y, _ = _rope(t)
            front.append(konrai_cluster(s, x, y + 6, 46, scale=0.95))
    elif festival == 'eid':
        for i in range(41):
            x, y, _ = _rope(i / 40)
            mid.append(f'<circle cx="{f(x)}" cy="{f(y)}" r="3.4" fill="{["#FFE7A0", "#E0A82E"][i % 2]}"/>')
        # lanterns only at the ends, short drops over the logo so the peacock stays clear
        for i, (t, drop, kind) in enumerate([(0.08, 20, 'lantern'), (0.22, 8, 'crescent'), (0.36, 4, 'star'), (0.5, 2, 'star'),
                                             (0.64, 4, 'star'), (0.78, 8, 'crescent'), (0.92, 20, 'lantern')]):
            x, y, _ = _rope(t)
            back.append(f'<line x1="{f(x)}" y1="{f(y)}" x2="{f(x)}" y2="{f(y + drop)}" stroke="#C98A12" stroke-width="1.6"/>')
            if kind == 'lantern':
                svg, _ = lantern(s, x, y + drop - 2, 50, 'ruby' if i == 0 else 'teal', glow=False)
                front.append(svg)
            elif kind == 'star':
                front.append(star5(s, x, y + drop + 8, 9 if i == 3 else 10))
            else:
                front.append(gold_crescent(s, x, y + drop + 9, 10, rot=-30))
    elif festival == 'national':
        mid.append(_rope_path('#9AA6BF', 3))
        for i in range(13):
            t = 0.04 + i * 0.077
            x, y, ang = _rope(t)
            small = 0.38 < t < 0.62           # keep the middle short, over the peacock's crest
            front.append(pennant(s, x, y, 20 if small else 24, 22 if small else 30, TRI[i % 3], angle=ang))
        for t in (0.06, 0.94):
            x, y, _ = _rope(t)
            front.append(tri_rosette(s, x, y + 6, 15))
    else:
        raise ValueError(festival)
    s.add(''.join(back) + ''.join(mid) + ''.join(front))
    path = f'{OUT}/garland_{festival}.svg'
    s.save(path)
    png = subprocess.run(['/opt/homebrew/opt/node@22/bin/node', '-e', _RENDER, path], capture_output=True, check=True).stdout
    return Image.open(io.BytesIO(png)).convert('RGBA')


_RENDER = """
const {createRequire}=require('module');const r=createRequire(require('path').resolve('../../backend/package.json'));
r('sharp')(require('fs').readFileSync(process.argv[1]),{density:72}).png().toBuffer().then(b=>process.stdout.write(b));
"""


def _over(base, layer, size):
    """Composite the garland (drawn for a 108 dp canvas) onto an icon image of `size` pixels."""
    g = layer.resize((size, size), Image.LANCZOS)
    out = base.convert('RGBA').copy()
    out.alpha_composite(g)
    return out


def icon_sets(festival):
    std, fest = f'{APP}/branding/app_icon/standard', f'{APP}/branding/app_icon/{festival}'
    shutil.rmtree(fest, ignore_errors=True)
    if not os.path.isdir(std):
        for d in DENSITIES:
            shutil.copytree(f'{ANDROID_RES}/mipmap-{d}', f'{std}/android/mipmap-{d}')
        shutil.copytree(IOS_ICONS, f'{std}/ios/AppIcon.appiconset')
    layer = garland(festival)
    for d, k in DENSITIES.items():
        src, out = f'{std}/android/mipmap-{d}', f'{fest}/android/mipmap-{d}'
        os.makedirs(out, exist_ok=True)
        fg = Image.open(f'{src}/ic_launcher_foreground.png')
        _over(fg, layer, fg.width).save(f'{out}/ic_launcher_foreground.png', optimize=True)
        legacy = Image.open(f'{src}/ic_launcher.png')
        # the legacy icon shows the 72 dp middle of the 108 dp canvas: crop the garland the same way
        lay = layer.resize((round(legacy.width * 108 / 72),) * 2, Image.LANCZOS)
        off = (lay.width - legacy.width) // 2
        cropped = lay.crop((off, off, off + legacy.width, off + legacy.height))
        mask = legacy.convert('RGBA').split()[3]
        cropped.putalpha(Image.fromarray(__import__('numpy').minimum(__import__('numpy').array(cropped.split()[3]), __import__('numpy').array(mask))))
        merged = legacy.convert('RGBA').copy(); merged.alpha_composite(cropped)
        merged.save(f'{out}/ic_launcher.png', optimize=True)
        shutil.copy(f'{src}/ic_launcher_monochrome.png', f'{out}/ic_launcher_monochrome.png')  # themed icons stay plain
    out = f'{fest}/ios/AppIcon.appiconset'
    os.makedirs(out, exist_ok=True)
    shutil.copy(f'{std}/ios/AppIcon.appiconset/Contents.json', f'{out}/Contents.json')
    master = Image.open(f'{std}/ios/AppIcon.appiconset/Icon-App-1024x1024@1x.png').convert('RGBA')
    lay = layer.resize((round(1024 * 108 / 72),) * 2, Image.LANCZOS)
    off = (lay.width - 1024) // 2
    master.alpha_composite(lay.crop((off, off, off + 1024, off + 1024)))
    master = master.convert('RGB')  # App Store icons must not have transparency
    for img in json.load(open(f'{out}/Contents.json'))['images']:
        if 'filename' in img:
            px = round(float(img['size'].split('x')[0]) * float(img['scale'].rstrip('x')))
            master.resize((px, px), Image.LANCZOS).save(f'{out}/{img["filename"]}', optimize=True)
    master.resize((512, 512), Image.LANCZOS).save(f'{fest}/play_store_512.png', optimize=True)
    print(festival, 'icon set written')


FESTIVALS = ('diwali', 'pongal', 'christmas', 'valentine', 'puthandu', 'eid', 'national')

if __name__ == '__main__':
    for festival in FESTIVALS:
        icon_sets(festival)
