import math
from svgkit import *
OUT = 'out'

# Greeting ribbon (9-slice: keep 150 px each side + 30 px top/bottom): 1080 × 150
def strip():
    s = SVG(1080, 150, seed=61)
    body = s.lin([(0, '#7A1426'), (0.5, '#9A1F22'), (1, '#7A1426')], x1=0, y1=0, x2=1, y2=0)
    s.add(f'<rect x="4" y="8" width="1072" height="134" rx="34" fill="#2A0510" opacity="0.35" filter="{s.blur(6)}"/>')
    s.add(f'<rect x="0" y="0" width="1080" height="140" rx="34" fill="{body}"/>')
    s.add(f'<rect x="0" y="0" width="1080" height="140" rx="34" fill="{s.lin([(0, "#FFFFFF", 0.14), (0.5, "#FFFFFF", 0), (1, "#000000", 0.18)], x1=0, y1=0, x2=0, y2=1)}"/>')
    s.add('<rect x="9" y="9" width="1062" height="122" rx="27" fill="none" stroke="#F6C445" stroke-width="2.4"/>')
    s.add('<rect x="17" y="17" width="1046" height="106" rx="21" fill="none" stroke="#F6C445" stroke-opacity="0.5" stroke-width="1.2" stroke-dasharray="2 6" stroke-linecap="round"/>')
    for x, ang in [(1035, 200), (1005, 160)]:
        s.add(paisley(s, x, 96, 46, angle=ang, color='#F6C445', opacity=0.75))
    s.add(marigold(s, 1030, 26, 15, 'yellow'))
    s.add(marigold(s, 1052, 46, 11, 'orange'))
    s.add(f'<circle cx="80" cy="70" r="52" fill="#FFB300" opacity="0.25" filter="{s.blur(14)}"/>')
    s.add(diya(s, 80, 58, 84, style=1))
    s.save(f'{OUT}/strip.svg')

# Seamless sparkle tile for festive buttons: 192 × 192 (64 dp)
def btn_tile():
    s = SVG(192, 192, seed=71)
    rnd = s.rnd
    items = []
    for _ in range(26):
        x, y = rnd.uniform(0, 192), rnd.uniform(0, 192)
        r = rnd.uniform(1.2, 4.2)
        op = rnd.uniform(0.25, 0.75)
        for dx in (-192, 0, 192):
            for dy in (-192, 0, 192):
                if r > 3:
                    items.append(star4(x + dx, y + dy, r * 1.8, '#FFE9A8', op))
                else:
                    items.append(f'<circle cx="{f(x + dx)}" cy="{f(y + dy)}" r="{f(r * 0.6)}" fill="#FFE9A8" opacity="{f(op)}"/>')
    s.add(''.join(items))
    s.save(f'{OUT}/btn_tile.svg')

# Bottom bar border (tiles horizontally): 96 × 30 (32 × 10 dp)
def nav_border():
    s = SVG(96, 30, seed=81)
    s.add(f'<rect width="96" height="30" fill="{s.lin([(0, "#6E1428"), (1, "#A3261B")], x1=0, y1=0, x2=0, y2=1)}"/>')
    s.add('<line x1="0" y1="3" x2="96" y2="3" stroke="#F6C445" stroke-width="2"/>')
    s.add('<path d="M 0,8 Q 12,26 24,8 Q 36,26 48,8 Q 60,26 72,8 Q 84,26 96,8" stroke="#F6C445" stroke-width="2" fill="none"/>')
    for x in (12, 36, 60, 84):
        s.add(f'<circle cx="{x}" cy="21" r="2.6" fill="#FFD54F"/>')
    for x in (0, 24, 48, 72, 96):
        s.add(f'<circle cx="{x}" cy="9" r="2.2" fill="#FFB300"/>')
    s.save(f'{OUT}/nav_border.svg')

# Section icon: a small lit diya (96 × 96 → 32 dp)
def diya_icon():
    s = SVG(96, 96, seed=91)
    s.add(diya(s, 48, 46, 78, style=1))
    s.save(f'{OUT}/diya_icon.svg')

# Falling-petal sprites: marigold petals + a small flower (48 px / 72 px)
def petals():
    for name, col1, col2 in [('petal_orange', '#FFB74D', '#E65100'), ('petal_yellow', '#FFF176', '#F9A825'), ('petal_red', '#FF8A80', '#C62828')]:
        s = SVG(48, 48)
        g = s.rad([(0, col1), (1, col2)], cx=0.35, cy=0.35, r=0.75)
        s.add(f'<path d="M 24,4 C 38,8 44,22 36,36 C 30,44 18,44 12,36 C 4,22 10,8 24,4 Z" fill="{g}"/>')
        s.add(f'<path d="M 24,8 Q 26,24 22,40" stroke="{col2}" stroke-opacity="0.5" stroke-width="1.5" fill="none"/>')
        s.save(f'{OUT}/{name}.svg')
    s = SVG(72, 72, seed=5)
    s.add(marigold(s, 36, 36, 30, 'orange', depth=False))
    s.save(f'{OUT}/marigold_small.svg')

strip(); btn_tile(); nav_border(); diya_icon(); petals()
print('ok')
