import math, json
from svgkit import *

OUT = 'out'
import os; os.makedirs(OUT, exist_ok=True)

# ── Thoranam (mango-leaf + marigold garland), tiles horizontally: 1170 × 132 px (390 × 44 dp @3x) ──
def thoranam():
    s = SVG(1170, 132, seed=11)
    y0 = 12
    slots = 18
    gap = 1170 / slots
    leaves, flowers = [], []
    for i in range(slots):
        x = gap * (i + 0.5)
        if i % 2 == 0:
            leaves.append(mango_leaf(s, x, y0, 104, 36, angle=(7 if (i // 2) % 2 else -7), tone=i // 2))
        else:
            kind = 'orange' if (i // 2) % 2 == 0 else 'yellow'
            if (i // 2) % 3 == 1:
                flowers.append(f'<line x1="{f(x)}" y1="{f(y0)}" x2="{f(x)}" y2="{f(y0 + 74)}" stroke="#7B5E57" stroke-width="2"/>')
                flowers.append(marigold(s, x, y0 + 62, 15, 'deep'))
                flowers.append(bell(s, x, y0 + 80, 14))
            flowers.append(marigold(s, x, y0 + 16, 21, kind))
    rope = (f'<line x1="0" y1="{y0}" x2="1170" y2="{y0}" stroke="#4E342E" stroke-width="4.2"/>'
            f'<line x1="0" y1="{y0 - 0.6}" x2="1170" y2="{y0 - 0.6}" stroke="#A1887F" stroke-width="1.6" stroke-dasharray="5 4"/>')
    s.add(''.join(leaves) + rope + ''.join(flowers))
    s.save(f'{OUT}/thoranam.svg')


def bell(s, x, y, size):
    g = s.lin([(0, '#FFF1B8'), (0.35, '#F6C445'), (0.75, '#C98A12'), (1, '#8A5A00')], x1=0, y1=0, x2=1, y2=0)
    w = size / 2
    d = (f'M {f(x - w * 0.18)},{f(y)} L {f(x + w * 0.18)},{f(y)} C {f(x + w * 0.6)},{f(y + size * 0.15)} {f(x + w * 0.62)},{f(y + size * 0.6)} {f(x + w)},{f(y + size * 0.82)} '
         f'L {f(x - w)},{f(y + size * 0.82)} C {f(x - w * 0.62)},{f(y + size * 0.6)} {f(x - w * 0.6)},{f(y + size * 0.15)} {f(x - w * 0.18)},{f(y)} Z')
    return (f'<path d="{d}" fill="{g}" stroke="#7A4E00" stroke-width="0.8"/>'
            f'<circle cx="{f(x)}" cy="{f(y + size * 0.9)}" r="{f(size * 0.12)}" fill="#C98A12"/>'
            f'<ellipse cx="{f(x)}" cy="{f(y + size * 0.82)}" rx="{f(w)}" ry="{f(size * 0.08)}" fill="#E0A82E"/>')


# ── Diyas on a rangoli (flames are separate, animated in the app): 480 × 270 px ──
WICKS = [(118, 150, 118), (240, 126, 150), (362, 150, 118)]

def rangoli_flat(s, cx, cy, rx, ry):
    """Colourful rangoli seen at an angle (drawn round, squashed)."""
    k = ry / rx
    parts = [f'<g transform="translate({f(cx)} {f(cy)}) scale(1 {f(k)})">']
    parts.append(f'<circle r="{f(rx)}" fill="#3B0613" opacity="0.35" filter="{s.blur(10)}"/>')
    rings = [(1.0, '#D81B60', 28), (0.84, '#FFB300', 24), (0.68, '#43A047', 20), (0.52, '#FB8C00', 16), (0.36, '#8E24AA', 12), (0.2, '#FDD835', 8)]
    for t, col, n in rings:
        r = rx * t
        for i in range(n):
            a = math.radians(i * 360 / n)
            x, y = math.cos(a) * r * 0.86, math.sin(a) * r * 0.86
            parts.append(f'<ellipse cx="{f(x)}" cy="{f(y)}" rx="{f(r * 0.16)}" ry="{f(r * 0.07 + 2)}" transform="rotate({f(math.degrees(a))} {f(x)} {f(y)})" fill="{col}"/>')
        parts.append(f'<circle r="{f(r * 0.72)}" fill="none" stroke="#FFFFFF" stroke-opacity="0.85" stroke-width="2.2" stroke-dasharray="1 7" stroke-linecap="round"/>')
    parts.append('</g>')
    return ''.join(parts)


def diyas_base():
    s = SVG(480, 270, seed=5)
    s.add(rangoli_flat(s, 240, 212, 226, 50))
    for x, y in [(30, 205), (450, 210), (70, 238), (410, 240), (200, 252), (290, 250)]:
        s.add(f'<ellipse cx="{x}" cy="{y}" rx="9" ry="4" fill="#FB8C00" transform="rotate(20 {x} {y})"/>')
    for i, (x, y, size) in enumerate(WICKS):
        s.add(diya(s, x, y, size, style=i, with_flame=False))
    s.save(f'{OUT}/diyas_base.svg')
    return [{'x': x / 480, 'y': y / 270, 'size': size / 480} for x, y, size in WICKS]


# ── One flame (base at 50% × 90%): 150 × 240 px ──
def flame_asset():
    s = SVG(150, 240, seed=3)
    s.add(flame(s, 75, 216, 62, 168))
    s.save(f'{OUT}/flame.svg')


# ── Header background: 1170 × 1050 px ──
def header_bg():
    s = SVG(1170, 1050, seed=21)
    s.add(f'<rect width="1170" height="1050" fill="{s.lin([(0, "#360718"), (0.38, "#5C0E22"), (0.72, "#7C1625"), (1, "#8C1D1E")])}"/>')
    s.add(f'<rect width="1170" height="1050" fill="{s.rad([(0, "#FF8F00", 0.42), (0.55, "#E65100", 0.12), (1, "#E65100", 0)], cx=930, cy=560, r=560, units="userSpaceOnUse")}"/>')
    s.add(f'<rect width="1170" height="1050" fill="{s.rad([(0, "#C2410C", 0.30), (1, "#C2410C", 0)], cx=120, cy=160, r=470, units="userSpaceOnUse")}"/>')
    s.add(mandala(s, 1090, 470, 440, opacity=0.14, stroke=2.4))
    s.add(mandala(s, 40, 980, 230, opacity=0.08, stroke=2.0))
    rnd = s.rnd
    for _ in range(16):
        x, y = rnd.uniform(420, 1170), rnd.uniform(120, 980)
        s.add(bokeh(s, x, y, rnd.uniform(16, 64), rnd.choice(['#FFB74D', '#FFD54F', '#FF8A65']), rnd.uniform(0.12, 0.3)))
    for _ in range(6):
        s.add(bokeh(s, rnd.uniform(0, 420), rnd.uniform(140, 1000), rnd.uniform(12, 34), '#FFCC80', rnd.uniform(0.06, 0.14)))
    for _ in range(22):
        x, y = rnd.uniform(380, 1160), rnd.uniform(130, 1000)
        s.add(sparkle(s, x, y, rnd.uniform(4, 13), opacity=rnd.uniform(0.35, 0.9)))
    for _ in range(8):
        s.add(sparkle(s, rnd.uniform(10, 380), rnd.uniform(140, 1000), rnd.uniform(3, 7), opacity=rnd.uniform(0.2, 0.45)))
    s.save(f'{OUT}/header_bg.svg')


thoranam()
wicks = diyas_base()
flame_asset()
header_bg()
json.dump({'wicks': wicks}, open(f'{OUT}/diyas_base.json', 'w'), indent=1)
print('wicks', wicks)
