"""The peacock in flight for the splash intro (original vector art): a plump iridescent-blue neck and
breast, bronze-green scaled back, crested head with the white face stripes, and a broad wing with
barred coverts and chestnut primaries. The intro flaps the wing and trails the logo's own nine
feathers behind as the train, then turns the bird to face you as it becomes the J.

Drawn head-up in the logo's pixel scale (the intro lays it on its side), rump on the point the logo's
feathers fan from, so the train hangs from the right place.

  cd design/brand-intro && python3 flying_peacock.py

Writes app/assets/brand/intro/fly_body.webp, fly_wing.webp and app/lib/widgets/brand_intro_bird.dart.
"""
import math
import os
import re
import subprocess
import sys

sys.path.insert(0, '../festival-art')
from svgkit import SVG, f  # noqa: E402

APP = '../../app'
OUT = f'{APP}/assets/brand/intro'
DART = f'{APP}/lib/widgets/brand_intro_bird.dart'
PREVIEW = 'out'
os.makedirs(PREVIEW, exist_ok=True)

PIVOT = tuple(float(v) for v in re.search(r'pivot = Offset\(([\d.]+), ([\d.]+)\)', open(f'{APP}/lib/widgets/brand_intro_parts.dart').read()).groups())

BODY_W, BODY_H = 230, 400
RUMP = (118, 388)       # where the train hangs from: placed on the logo's pivot
SHOULDER = (100, 248)   # where the wings join the back
WING_W, WING_H = 250, 130
WING_ROOT = (236, 40)   # the wing is drawn spread to the left (the bird's back) from here


def _crescents(s, cx, cy, rx, ry, colour, opacity, step=9, size=4.2, clip=None):
    """Rows of little feather scales."""
    out = [f'<g clip-path="{clip}" opacity="{f(opacity)}">' if clip else f'<g opacity="{f(opacity)}">']
    row = 0
    y = cy - ry
    while y < cy + ry:
        x = cx - rx + (step / 2 if row % 2 else 0)
        while x < cx + rx:
            out.append(f'<path d="M {f(x - size)},{f(y)} Q {f(x)},{f(y + size * 1.3)} {f(x + size)},{f(y)}" stroke="{colour}" stroke-width="1.1" fill="none"/>')
            x += step
        y += step * 0.72
        row += 1
    out.append('</g>')
    return ''.join(out)


def body():
    s = SVG(BODY_W, BODY_H, seed=3)
    torso = 'M 128,214 C 170,210 186,262 182,302 C 178,344 154,380 122,390 C 96,386 80,352 78,310 C 76,262 90,218 128,214 Z'
    neck = 'M 103,112 C 101,150 106,198 90,248 L 174,248 C 160,206 148,160 141,108 Z'
    head = 'M 118,75 C 134,73 142,87 140,103 C 138,117 128,125 116,123 C 104,121 98,109 100,95 C 102,83 108,76 118,75 Z'
    blue = s.lin([(0, '#1C55CE'), (0.3, '#2468EA'), (0.62, '#1748C2'), (1, '#0B2770')], x1=110, y1=20, x2=150, y2=390, units='userSpaceOnUse')
    for d in (neck, torso, head):
        s.add(f'<path d="{d}" fill="#06143A" opacity="0.32" transform="translate(5 7)" filter="{s.blur(5)}"/>')
    for d in (neck, torso, head):
        s.add(f'<path d="{d}" fill="{blue}"/>')
    clip_t = s.clip(f'<path d="{torso}"/>')
    clip_n = s.clip(f'<path d="{neck}"/>')
    # bronze-green back between the wings, scaled with golden edges; the breast stays blue
    back = 'M 50,232 C 100,236 124,282 126,322 C 128,358 120,384 114,396 L 50,396 Z'
    green = s.lin([(0, '#34A862'), (0.5, '#1F7D44'), (1, '#0E4A28')], x1=0, y1=0, x2=1, y2=1)
    s.add(f'<g clip-path="{clip_t}"><path d="{back}" fill="{green}"/>'
          f'{_crescents(s, 100, 312, 34, 84, "#E8C547", 0.6, step=10, size=4.6)}'
          f'{_crescents(s, 150, 292, 34, 84, "#0A2466", 0.32, step=10, size=4.4)}'
          f'<ellipse cx="160" cy="268" rx="14" ry="36" fill="#9AD8FF" opacity="0.24" filter="{s.blur(6)}"/>'
          f'<path d="M 86,350 C 116,372 150,356 176,318" stroke="#071848" stroke-opacity="0.5" stroke-width="14" fill="none" filter="{s.blur(7)}"/></g>')
    s.add(f'<g clip-path="{clip_n}">{_crescents(s, 128, 180, 34, 70, "#0A2466", 0.28, step=8, size=3.6)}'
          f'<path d="M 132,118 C 136,160 144,200 160,240" stroke="#9FDBFF" stroke-opacity="0.5" stroke-width="7" fill="none" stroke-linecap="round" filter="{s.blur(3)}"/></g>')
    # crest swept back over the head; white face stripes, eye, beak
    for k in range(6):
        a = math.radians(212 + k * 7)
        x0, y0 = 110, 83
        x1, y1 = x0 + math.sin(a) * 40, y0 - math.cos(a) * 40
        s.add(f'<line x1="{x0}" y1="{y0}" x2="{f(x1)}" y2="{f(y1)}" stroke="#1B2B4E" stroke-width="1.5" stroke-linecap="round"/>')
        s.add(f'<ellipse cx="{f(x1)}" cy="{f(y1)}" rx="5.4" ry="3.5" transform="rotate({f(math.degrees(math.atan2(y1 - y0, x1 - x0)))} {f(x1)} {f(y1)})" '
              f'fill="{s.lin([(0, "#2B7BE4"), (1, "#22B39B")], x1=0, y1=0, x2=1, y2=0)}" stroke="#0E2A66" stroke-width="0.8"/>')
    s.add('<path d="M 105,95 Q 116,83 132,85" stroke="#FFFFFF" stroke-width="3.2" fill="none" stroke-linecap="round"/>')
    s.add('<path d="M 112,107 Q 123,110 133,101" stroke="#FFFFFF" stroke-width="3" fill="none" stroke-linecap="round"/>')
    s.add('<circle cx="122" cy="95" r="5.6" fill="#FFFFFF"/><circle cx="122.6" cy="94.6" r="3.4" fill="#120A04"/><circle cx="121.4" cy="93.6" r="1.1" fill="#FFFFFF"/>')
    beak = s.lin([(0, '#E9DFD0'), (1, '#9C8A76')], x1=0, y1=0, x2=1, y2=1)
    s.add(f'<path d="M 127,84 C 131,73 134,65 137,58 C 138,67 139,77 139,90 Q 133,88 127,84 Z" fill="{beak}" stroke="#6D5C4B" stroke-width="0.8"/>')
    s.add('<path d="M 130,83 C 133,75 135,67 137,59" stroke="#5D4C3C" stroke-width="0.8" fill="none"/>')
    # legs tucked back under the belly
    s.add('<path d="M 156,340 Q 166,360 158,380 M 146,346 Q 154,366 144,384" stroke="#9A8C80" stroke-width="3.4" fill="none" stroke-linecap="round"/>')
    return s


def wing():
    s = SVG(WING_W, WING_H, seed=5)
    rx, ry = WING_ROOT
    # secondaries hang from the forearm, dark with a blue sheen; primaries fan out at the tip, chestnut
    sec = s.lin([(0, '#23324A'), (1, '#3B5370')], x1=0, y1=0, x2=0, y2=1)
    pri = s.lin([(0, '#D88A45'), (0.6, '#B2541E'), (1, '#7A3010')], x1=1, y1=0, x2=0, y2=1)
    feathers = []
    for k in range(9):                        # secondaries, root side
        x = rx - 22 - k * 13
        top = ry + 4 - k * 0.6
        L = 66 + k * 2
        feathers.append(f'<path d="M {f(x + 7)},{f(top)} C {f(x + 9)},{f(top + L * 0.5)} {f(x + 2)},{f(top + L * 0.95)} {f(x - 5)},{f(top + L)} '
                        f'C {f(x - 9)},{f(top + L * 0.6)} {f(x - 7)},{f(top + L * 0.3)} {f(x - 7)},{f(top)} Z" fill="{sec}" stroke="#121A28" stroke-width="0.9"/>')
    for k in range(8):                        # primaries, out to the tip
        a = math.radians(-18 - k * 9)         # fanning from down-left round to left
        bx, by = 118 - k * 9, 32 + k * 1.5
        L = 70 + k * 7
        tx, ty = bx + math.sin(a) * L, by + math.cos(a) * L * 0.55 + 18
        mx, my = (bx + tx) / 2, (by + ty) / 2
        feathers.append(f'<path d="M {f(bx + 6)},{f(by)} Q {f(mx + 10)},{f(my + 4)} {f(tx)},{f(ty)} Q {f(mx - 8)},{f(my - 6)} {f(bx - 6)},{f(by - 2)} Z" fill="{pri}" stroke="#5A2208" stroke-width="0.9"/>'
                        f'<path d="M {f(bx)},{f(by)} Q {f(mx + 1)},{f(my - 1)} {f(tx)},{f(ty)}" stroke="#4A1A06" stroke-width="0.8" fill="none" opacity="0.7"/>')
    s.add(''.join(reversed(feathers)))
    # coverts: the barred band along the leading edge, then iridescent shoulder feathers at the root
    band = f'M {rx},{ry - 8} C {rx - 60},{ry - 28} 74,8 22,28 C 64,36 124,46 {rx - 12},{ry + 20} Z'
    clip = s.clip(f'<path d="{band}"/>')
    stripes = ''.join(f'<path d="M {x},-10 L {x - 60},{WING_H + 10}" stroke="{"#5B4631" if i % 2 else "#CDB98F"}" stroke-width="4"/>' for i, x in enumerate(range(0, WING_W + 80, 4)))
    s.add(f'<path d="{band}" fill="#CDB98F"/><g clip-path="{clip}">{stripes}'
          f'<path d="{band}" fill="{s.lin([(0, "#000000", 0), (1, "#000000", 0.3)], x1=0, y1=0, x2=0, y2=1)}"/></g>'
          f'<path d="{band}" fill="none" stroke="#3A2A1A" stroke-width="1.2"/>')
    s.add(f'<path d="M {rx},{ry - 10} C {rx - 30},{ry - 20} {rx - 56},{ry - 6} {rx - 60},{ry + 12} C {rx - 40},{ry + 24} {rx - 14},{ry + 22} {rx},{ry + 12} Z" fill="{s.lin([(0, "#2E9E5A"), (1, "#1A4FC4")], x1=1, y1=0, x2=0, y2=1)}"/>')
    s.add(_crescents(s, rx - 30, ry + 6, 28, 14, '#E8C547', 0.6, step=8, size=3.4))
    s.add(f'<path d="M {rx},{ry - 8} C {rx - 60},{ry - 30} 70,4 18,26" stroke="#FFFFFF" stroke-opacity="0.35" stroke-width="2" fill="none"/>')
    return s


def render(svg, name):
    path = f'{PREVIEW}/{name}.svg'
    svg.save(path)
    subprocess.run(['/opt/homebrew/opt/node@22/bin/node', '-e', """
const {createRequire}=require('module');const r=createRequire(require('path').resolve('../../backend/package.json'));const sharp=r('sharp');
const [src, webp, png]=process.argv.slice(1);
sharp(src,{density:72}).webp({quality:92,alphaQuality:100,effort:6}).toFile(webp).then(()=>sharp(src,{density:72}).png().toFile(png));
""", path, f'{OUT}/{name}.webp', f'{PREVIEW}/{name}.png'], check=True)


if __name__ == '__main__':
    render(body(), 'fly_body')
    render(wing(), 'fly_wing')
    left, top = PIVOT[0] - RUMP[0], PIVOT[1] - RUMP[1]
    sx, sy = left + SHOULDER[0], top + SHOULDER[1]
    open(DART, 'w').write('\n'.join([
        '// GENERATED by design/brand-intro/flying_peacock.py — do not edit.',
        "import 'dart:ui';", '',
        "import 'brand_intro_parts.dart';", '',
        '/// The peacock in flight, in the logo\'s coordinates: drawn head-up with its rump on',
        '/// [BrandIntroParts.pivot] (the intro lays it on its side), the wing spread from the shoulder.',
        'abstract final class BrandIntroBird {',
        f"  static const body = BrandPiece('assets/brand/intro/fly_body.webp', Rect.fromLTWH({left:.1f}, {top:.1f}, {BODY_W}, {BODY_H}));",
        '',
        '  /// Drawn spread towards the bird\'s back from its root, which sits on the shoulder ([BrandPiece.hinge]).',
        f"  static const wing = BrandPiece('assets/brand/intro/fly_wing.webp', Rect.fromLTWH({sx - WING_ROOT[0]:.1f}, {sy - WING_ROOT[1]:.1f}, {WING_W}, {WING_H}), hinge: Offset({sx:.1f}, {sy:.1f}));",
        '}', '']))
    print('body at', round(left, 1), round(top, 1), '; shoulder', round(sx, 1), round(sy, 1))
