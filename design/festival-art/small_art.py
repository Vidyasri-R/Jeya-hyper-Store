import math
from svgkit import *
OUT = 'out'

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

btn_tile(); diya_icon(); petals()
print('ok')
