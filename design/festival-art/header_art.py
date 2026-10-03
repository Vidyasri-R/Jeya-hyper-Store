import math, json
from svgkit import *

OUT = 'out'
import os; os.makedirs(OUT, exist_ok=True)

# ── Thoranam: mango-leaf and marigold garland hanging in three natural swags, 1170 × 132 px
#    (390 × 44 dp @3x). Nothing hangs below y = 128 px, so it never reaches the store name.
SWAGS = [(-40, 392, 50), (392, 774, 40), (774, 1210, 47)]   # (from x, to x, sag) — each a little different
ANCHOR_Y = 6


def _rope_point(x0, x1, sag, t):
    """Point and tangent angle (degrees) on a swag drawn as a quadratic curve."""
    cx, cy = (x0 + x1) / 2, ANCHOR_Y + 2 * sag
    x = (1 - t) ** 2 * x0 + 2 * (1 - t) * t * cx + t * t * x1
    y = (1 - t) ** 2 * ANCHOR_Y + 2 * (1 - t) * t * cy + t * t * ANCHOR_Y
    dx = 2 * (1 - t) * (cx - x0) + 2 * t * (x1 - cx)
    dy = 2 * (1 - t) * (cy - ANCHOR_Y) + 2 * t * (ANCHOR_Y - cy)
    return x, y, math.degrees(math.atan2(dy, dx))


def thoranam():
    """Dense marigold strings in three swags, mango leaves hanging below, tied clusters with bells."""
    s = SVG(1170, 132, seed=29)
    rnd = s.rnd
    leaves, ropes, flowers, knots = [], [], [], []
    for k, (x0, x1, sag) in enumerate(SWAGS):
        cx, cy = (x0 + x1) / 2, ANCHOR_Y + 2 * sag
        d = f'M {f(x0)},{ANCHOR_Y} Q {f(cx)},{f(cy)} {f(x1)},{ANCHOR_Y}'
        ropes.append(f'<path d="{d}" stroke="#4E342E" stroke-width="4" fill="none" stroke-linecap="round"/>')
        n = int(abs(x1 - x0) / 26.5)
        for i in range(n):
            t = (i + 0.5) / n + rnd.uniform(-0.12, 0.12) / n
            if t < 0.035 or t > 0.965:
                continue
            x, y, ang = _rope_point(x0, x1, sag, t)
            # orange and yellow alternate like a real string, with the odd deep-orange bloom
            kind = 'deep' if rnd.random() < 0.12 else ('orange' if i % 2 else 'yellow')
            flowers.append(marigold(s, x + rnd.uniform(-1.5, 1.5), y + rnd.uniform(-1, 2), rnd.uniform(13.5, 16.8), kind))
            if i % 3 == 1:
                depth = y - ANCHOR_Y
                length_ = rnd.uniform(62, 74) - depth * 0.28           # shorter where the string hangs lowest
                tilt = ang + rnd.uniform(-10, 10)
                if rnd.random() < 0.25:                               # now and then a pair fans out
                    leaves.append(mango_leaf(s, x - 5, y + 6, length_ * 0.9, 23, angle=tilt - 16, tone=i + 1))
                    leaves.append(mango_leaf(s, x + 5, y + 6, length_, 25, angle=tilt + 14, tone=i))
                else:
                    leaves.append(mango_leaf(s, x, y + 6, length_, rnd.uniform(23, 27), angle=tilt, tone=i + k))
    # tied clusters where the swags meet: big marigolds, two leaves and a small bell
    for ax, strand, big in [(392, 74, 'deep'), (774, 66, 'orange')]:
        knots.append(mango_leaf(s, ax - 8, ANCHOR_Y + 16, 66, 25, angle=22, tone=2))
        knots.append(mango_leaf(s, ax + 8, ANCHOR_Y + 16, 62, 24, angle=-24, tone=1))
        knots.append(f'<line x1="{ax}" y1="{ANCHOR_Y + 22}" x2="{ax}" y2="{ANCHOR_Y + strand}" stroke="#6D4C41" stroke-width="2"/>')
        knots.append(marigold(s, ax, ANCHOR_Y + strand - 30, 10.5, 'yellow'))
        knots.append(marigold(s, ax, ANCHOR_Y + strand - 13, 11.5, 'deep'))
        knots.append(bell(s, ax, ANCHOR_Y + strand - 2, 17))
        knots.append(marigold(s, ax - 17, ANCHOR_Y + 10, 18, 'yellow'))
        knots.append(marigold(s, ax + 17, ANCHOR_Y + 10, 18, 'orange'))
        knots.append(marigold(s, ax, ANCHOR_Y + 20, 21, big))
    s.add(''.join(leaves) + ''.join(ropes) + ''.join(flowers) + ''.join(knots))
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


# ── Splash background (whole screen, 390 × 844 dp @3x): rangoli glow behind the logo ──
def splash_bg():
    W_, H_ = 1170, 2532
    s = SVG(W_, H_, seed=37)
    s.add(f'<rect width="{W_}" height="{H_}" fill="{s.lin([(0, "#330616"), (0.4, "#5A0E22"), (0.78, "#7A1626"), (1, "#8C1D1E")])}"/>')
    s.add(f'<rect width="{W_}" height="{H_}" fill="{s.rad([(0, "#FFB300", 0.30), (0.5, "#E65100", 0.10), (1, "#E65100", 0)], cx=585, cy=1130, r=760, units="userSpaceOnUse")}"/>')
    s.add(f'<rect width="{W_}" height="{H_}" fill="{s.rad([(0, "#FF8F00", 0.34), (1, "#FF8F00", 0)], cx=585, cy=2330, r=640, units="userSpaceOnUse")}"/>')
    s.add(mandala(s, 585, 1130, 600, opacity=0.15, stroke=2.6))
    s.add(mandala(s, 585, 1130, 300, opacity=0.10, stroke=2.0))
    rnd = s.rnd
    for _ in range(26):
        s.add(bokeh(s, rnd.uniform(0, W_), rnd.uniform(160, H_ - 120), rnd.uniform(18, 70), rnd.choice(['#FFB74D', '#FFD54F', '#FF8A65']), rnd.uniform(0.10, 0.26)))
    for _ in range(40):
        s.add(sparkle(s, rnd.uniform(20, W_ - 20), rnd.uniform(180, H_ - 160), rnd.uniform(4, 13), opacity=rnd.uniform(0.3, 0.9)))
    s.save(f'{OUT}/splash_bg.svg')


thoranam()
splash_bg()
wicks = diyas_base()
flame_asset()
header_bg()
json.dump({'wicks': wicks}, open(f'{OUT}/diyas_base.json', 'w'), indent=1)
print('wicks', wicks)
