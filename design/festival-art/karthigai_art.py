"""Karthigai Deepam pack: a dusk sky from indigo to ember with the hill and its Maha Deepam beacon;
a thoranam of jasmine and marigolds with hanging thoonga vilakku; plain clay agal lamps lit on a
kolam beside a plate of pori urundai (their flames flicker in the app); a tall golden flame
rising behind the splash logo, the hill and rows of lamps at its foot.

Writes SVGs to out/karthigai/ (same file names as the other packs); render with
  node render.mjs --dir out/karthigai
"""
import json
import math
import os

from svgkit import *
from banners import brass_plate
from puthandu_art import lotus_kolam, malli

OUT = 'out/karthigai'
os.makedirs(OUT, exist_ok=True)


# ───────────────────────── motifs ─────────────────────────

def agal(s, cx, cy, size, tone=0):
    """A plain clay agal vilakku seen from the front; (cx, cy) is the wick tip at the front spout."""
    w = size / 2
    h = size * 0.36
    top = cy + size * 0.1
    clays = [('#E07A45', '#B4441A', '#6E220A'), ('#D9733C', '#A63C14', '#5E1C08'), ('#E68A55', '#C04E1E', '#7A2A0C')]
    c0, c1, c2 = clays[tone % 3]
    body = s.lin([(0, c0), (0.5, c1), (1, c2)], x1=0, y1=0, x2=0.2, y2=1)
    out = [f'<ellipse cx="{f(cx)}" cy="{f(top + h * 1.1)}" rx="{f(w * 0.95)}" ry="{f(h * 0.18)}" fill="#120604" opacity="0.45" filter="{s.blur(h * 0.1)}"/>',
           f'<path d="M {f(cx - w)},{f(top)} Q {f(cx - w * 0.95)},{f(top + h * 1.05)} {f(cx)},{f(top + h * 1.08)} Q {f(cx + w * 0.95)},{f(top + h * 1.05)} {f(cx + w)},{f(top)} Z" fill="{body}"/>',
           f'<ellipse cx="{f(cx)}" cy="{f(top)}" rx="{f(w)}" ry="{f(h * 0.3)}" fill="{c2}"/>',
           f'<ellipse cx="{f(cx)}" cy="{f(top + h * 0.02)}" rx="{f(w * 0.86)}" ry="{f(h * 0.22)}" fill="{s.rad([(0, "#FFE7A0"), (1, "#C98A12")], cx=0.5, cy=0.5, r=0.6)}"/>',
           # the pinched front spout holding the wick
           f'<path d="M {f(cx - w * 0.22)},{f(top + h * 0.12)} Q {f(cx)},{f(cy - size * 0.02)} {f(cx + w * 0.22)},{f(top + h * 0.12)} Z" fill="{c1}"/>',
           f'<line x1="{f(cx)}" y1="{f(cy + size * 0.06)}" x2="{f(cx)}" y2="{f(cy)}" stroke="#3E2723" stroke-width="{f(max(1, size * 0.03))}" stroke-linecap="round"/>',
           f'<path d="M {f(cx - w * 0.8)},{f(top + h * 0.3)} Q {f(cx - w * 0.75)},{f(top + h * 0.8)} {f(cx - w * 0.35)},{f(top + h * 0.95)}" stroke="#FFFFFF" stroke-opacity="0.2" stroke-width="{f(size * 0.05)}" fill="none" stroke-linecap="round"/>']
    for i in range(-3, 4):
        out.append(f'<circle cx="{f(cx + i * w * 0.24)}" cy="{f(top + h * 0.55 + (9 - i * i) * h * 0.012)}" r="{f(max(0.8, size * 0.018))}" fill="#FFD9A8" opacity="0.6"/>')
    return ''.join(out)


def hill(s, x0, x1, base_y, peak_x, peak_y, colour='#140A1E', rim='#FF9A4D'):
    """The holy hill: a broad silhouette rising to a peak, lit along its ridge by the beacon."""
    d = (f'M {f(x0)},{f(base_y)} C {f(x0 + (peak_x - x0) * 0.45)},{f(base_y - (base_y - peak_y) * 0.25)} {f(peak_x - (peak_x - x0) * 0.25)},{f(peak_y + (base_y - peak_y) * 0.1)} {f(peak_x)},{f(peak_y)} '
         f'C {f(peak_x + (x1 - peak_x) * 0.22)},{f(peak_y + (base_y - peak_y) * 0.12)} {f(x1 - (x1 - peak_x) * 0.4)},{f(base_y - (base_y - peak_y) * 0.3)} {f(x1)},{f(base_y)} Z')
    return (f'<path d="{d}" fill="{colour}"/>'
            f'<path d="{d}" fill="none" stroke="{rim}" stroke-opacity="0.35" stroke-width="3" filter="{s.blur(2)}"/>')


def beacon(s, x, y, size):
    """The Maha Deepam: a great flame on the summit with a wide glow."""
    return (f'<circle cx="{f(x)}" cy="{f(y - size * 0.4)}" r="{f(size * 2.4)}" fill="#FFB74D" opacity="0.22" filter="{s.blur(size * 0.8)}"/>'
            f'<circle cx="{f(x)}" cy="{f(y - size * 0.4)}" r="{f(size * 1.1)}" fill="#FFE082" opacity="0.35" filter="{s.blur(size * 0.35)}"/>'
            + flame(s, x, y, size * 0.5, size * 1.3, glow=False))


def pori_urundai(s, cx, cy, r):
    """A ball of puffed rice bound with jaggery."""
    rnd = s.rnd
    out = [f'<circle cx="{f(cx + r * 0.1)}" cy="{f(cy + r * 0.18)}" r="{f(r)}" fill="#1A0800" opacity="0.35" filter="{s.blur(r * 0.15)}"/>',
           f'<circle cx="{f(cx)}" cy="{f(cy)}" r="{f(r)}" fill="{s.rad([(0, "#F7D9A4"), (0.65, "#D6A35A"), (1, "#9C6420")], cx=0.38, cy=0.35, r=0.75)}"/>']
    clip = s.clip(f'<circle cx="{f(cx)}" cy="{f(cy)}" r="{f(r)}"/>')
    grains = []
    for _ in range(int(r * 2.2)):
        a, d = rnd.uniform(0, math.tau), math.sqrt(rnd.uniform(0, 1)) * r
        x, y = cx + math.cos(a) * d, cy + math.sin(a) * d
        grains.append(f'<ellipse cx="{f(x)}" cy="{f(y)}" rx="{f(r * 0.14)}" ry="{f(r * 0.09)}" transform="rotate({f(rnd.uniform(0, 180))} {f(x)} {f(y)})" fill="{rnd.choice(["#FFF6E0", "#F2DDB2", "#E2BC7A"])}" stroke="#B07A30" stroke-opacity="0.4" stroke-width="0.5"/>')
    out.append(f'<g clip-path="{clip}">{"".join(grains)}<circle cx="{f(cx + r * 0.3)}" cy="{f(cy + r * 0.35)}" r="{f(r * 0.9)}" fill="#6B3A0A" opacity="0.25" filter="{s.blur(r * 0.25)}"/></g>')
    out.append(f'<ellipse cx="{f(cx - r * 0.35)}" cy="{f(cy - r * 0.4)}" rx="{f(r * 0.25)}" ry="{f(r * 0.14)}" fill="#FFFFFF" opacity="0.35"/>')
    return ''.join(out)


def thoonga_vilakku(s, x, y, size):
    """A hanging brass lamp on three chains; returns (svg, wick)."""
    gold = s.lin([(0, '#7A4E00'), (0.3, '#C98A12'), (0.5, '#FFE7A0'), (0.75, '#C98A12'), (1, '#6B4300')], x1=0, y1=0, x2=1, y2=0)
    bowl_y = y + size * 1.1
    out = [f'<line x1="{f(x)}" y1="{f(y)}" x2="{f(x - size * 0.45)}" y2="{f(bowl_y)}" stroke="#C98A12" stroke-width="1.2"/>',
           f'<line x1="{f(x)}" y1="{f(y)}" x2="{f(x + size * 0.45)}" y2="{f(bowl_y)}" stroke="#C98A12" stroke-width="1.2"/>',
           f'<line x1="{f(x)}" y1="{f(y)}" x2="{f(x)}" y2="{f(bowl_y)}" stroke="#C98A12" stroke-width="1.2"/>',
           f'<circle cx="{f(x)}" cy="{f(y)}" r="{f(size * 0.08)}" fill="{gold}"/>',
           f'<path d="M {f(x - size * 0.55)},{f(bowl_y)} Q {f(x)},{f(bowl_y + size * 0.42)} {f(x + size * 0.55)},{f(bowl_y)} Z" fill="{gold}"/>',
           f'<ellipse cx="{f(x)}" cy="{f(bowl_y)}" rx="{f(size * 0.55)}" ry="{f(size * 0.1)}" fill="#8A5A00"/>',
           f'<circle cx="{f(x)}" cy="{f(bowl_y + size * 0.42)}" r="{f(size * 0.07)}" fill="{gold}"/>']
    wick = (x + size * 0.5, bowl_y - size * 0.04)
    out.append(f'<path d="M {f(x + size * 0.4)},{f(bowl_y - size * 0.02)} L {f(wick[0] + size * 0.06)},{f(wick[1] - size * 0.02)} L {f(x + size * 0.46)},{f(bowl_y + size * 0.06)} Z" fill="{gold}"/>')
    return ''.join(out), wick


def dusk(s, W_, H_, glow=None):
    s.add(f'<rect width="{W_}" height="{H_}" fill="{s.lin([(0, "#120B2E"), (0.4, "#251846"), (0.75, "#5A2A3A"), (1, "#8A3A1E")])}"/>')
    if glow:
        gx, gy, gr = glow
        s.add(f'<rect width="{W_}" height="{H_}" fill="{s.rad([(0, "#FFB74D", 0.32), (0.5, "#FF7043", 0.1), (1, "#FF7043", 0)], cx=gx, cy=gy, r=gr, units="userSpaceOnUse")}"/>')


def stars(s, x0, x1, y0, y1, n):
    rnd = s.rnd
    return ''.join(f'<circle cx="{f(rnd.uniform(x0, x1))}" cy="{f(rnd.uniform(y0, y1))}" r="{f(rnd.uniform(1.1, 2.6))}" fill="#FFF8E1" opacity="{f(rnd.uniform(0.3, 0.85))}"/>' for _ in range(n))


# ───────────────────────── pack assets ─────────────────────────

HERO_W, HERO_H = 480, 300
LAMPS = [(70, 236, 52, 0), (150, 252, 56, 1), (330, 252, 56, 2), (410, 236, 52, 0), (240, 262, 60, 1)]   # wick x, y, size, tone


def hero():
    """Agal lamps lit in an arc on a kolam, a brass plate of pori urundai behind them."""
    s = SVG(HERO_W, HERO_H, seed=137)
    s.add(f'<ellipse cx="240" cy="288" rx="232" ry="12" fill="#FFFFFF" opacity="0.10" filter="{s.blur(6)}"/>')
    s.add(f'<g transform="translate(240 280) scale(1 0.26)">{lotus_kolam(s, 0, 0, 200, color="#FFFFFF", opacity=0.85, stroke=6)}</g>')
    s.add(brass_plate(s, 240, 200, 120, 28))
    for (x, y, r) in [(200, 182, 24), (240, 178, 26), (280, 182, 24), (220, 152, 22), (260, 150, 22), (240, 126, 21)]:
        s.add(pori_urundai(s, x, y, r))
    for (x, y) in [(120, 278), (360, 278)]:
        s.add(marigold(s, x, y, 13, 'orange'))
    for i, (x, y) in enumerate([(30, 278), (450, 278)]):
        s.add(malli(s, x, y, 8, rot=i * 30))
    for x, y, size, tone in LAMPS:
        s.add(agal(s, x, y, size, tone))
    s.save(f'{OUT}/hero.svg')
    return [(round(x / HERO_W, 4), round(y / HERO_H, 4), round(size * 0.9 / HERO_W, 4)) for x, y, size, _ in LAMPS]


def header_bg():
    s = SVG(1170, 1050, seed=139)
    dusk(s, 1170, 1050, glow=(980, 640, 560))
    s.add(stars(s, 0, 1170, 0, 700, 70))
    s.add(hill(s, 520, 1250, 1050, 930, 560))
    s.add(beacon(s, 930, 566, 40))
    s.add(lotus_kolam(s, 80, 990, 180, color='#FFD54F', opacity=0.07, stroke=2))
    rnd = s.rnd
    for _ in range(12):
        s.add(sparkle(s, rnd.uniform(420, 1160), rnd.uniform(120, 600), rnd.uniform(3.5, 9), opacity=rnd.uniform(0.3, 0.8)))
    s.save(f'{OUT}/header_bg.svg')


SWAGS = [(-40, 392, 46), (392, 774, 36), (774, 1210, 43)]
ANCHOR_Y = 6


def _rope(x0, x1, sag, t):
    cx, cy = (x0 + x1) / 2, ANCHOR_Y + 2 * sag
    x = (1 - t) ** 2 * x0 + 2 * (1 - t) * t * cx + t * t * x1
    y = (1 - t) ** 2 * ANCHOR_Y + 2 * (1 - t) * t * cy + t * t * ANCHOR_Y
    dx = 2 * (1 - t) * (cx - x0) + 2 * t * (x1 - cx)
    dy = 2 * (1 - t) * (cy - ANCHOR_Y) + 2 * t * (ANCHOR_Y - cy)
    return x, y, math.degrees(math.atan2(dy, dx))


def thoranam():
    """Jasmine and marigold strung in swags; hanging thoonga vilakku (lit) at the ties."""
    s = SVG(1170, 132, seed=149)
    rnd = s.rnd
    ropes, flowers, lamps = [], [], []
    for k, (x0, x1, sag) in enumerate(SWAGS):
        cx, cy = (x0 + x1) / 2, ANCHOR_Y + 2 * sag
        ropes.append(f'<path d="M {f(x0)},{ANCHOR_Y} Q {f(cx)},{f(cy)} {f(x1)},{ANCHOR_Y}" stroke="#5D4037" stroke-width="3" fill="none"/>')
        n = int(abs(x1 - x0) / 13)
        for i in range(n):
            t = (i + 0.5) / n
            if t < 0.03 or t > 0.97:
                continue
            x, y, ang = _rope(x0, x1, sag, t)
            if i % 3 == 0:
                flowers.append(marigold(s, x, y + 1, rnd.uniform(11, 13), 'orange' if i % 6 else 'yellow'))
            elif i % 3 == 1:
                flowers.append(malli(s, x, y + 1, rnd.uniform(7, 8), rot=rnd.uniform(0, 60)))
            else:
                flowers.append(malli(s, x, y + 2, rnd.uniform(6, 7), rot=ang + rnd.uniform(-20, 20), bud=True))
            if i % 5 == 2:   # a short strand of jasmine hanging down
                depth = y - ANCHOR_Y
                for kk in range(3 if depth < 40 else 2):
                    flowers.append(malli(s, x + rnd.uniform(-1, 1), y + 14 + kk * 13, 6, rot=90 + rnd.uniform(-10, 10), bud=True))
    for ax in (392, 774):
        svg, wick = thoonga_vilakku(s, ax, ANCHOR_Y + 10, 42)
        lamps.append(svg)
        lamps.append(flame(s, wick[0], wick[1], 11, 27))
        lamps.append(marigold(s, ax - 14, ANCHOR_Y + 10, 12, 'orange'))
        lamps.append(marigold(s, ax + 14, ANCHOR_Y + 10, 12, 'yellow'))
    s.add(''.join(ropes) + ''.join(flowers) + ''.join(lamps))
    s.save(f'{OUT}/thoranam.svg')


def splash_bg():
    W_, H_ = 1170, 2532
    s = SVG(W_, H_, seed=151)
    dusk(s, W_, H_, glow=(585, 2100, 900))
    s.add(stars(s, 0, W_, 120, 1500, 150))
    s.add(hill(s, -200, 1370, H_ - 260, 600, 2040))
    s.add(beacon(s, 600, 2048, 56))
    s.add(f'<rect x="0" y="{H_ - 300}" width="{W_}" height="300" fill="#0E0614"/>')
    for row, (y, n, size) in enumerate([(H_ - 220, 9, 84), (H_ - 90, 7, 100)]):
        for i in range(n):
            x = (i + 0.5) * W_ / n + (30 if row else 0)
            s.add(agal(s, x, y, size, (i + row) % 3))
            s.add(flame(s, x, y, size * 0.2, size * 0.5))
    s.add(lotus_kolam(s, 130, 320, 160, color='#FFD54F', opacity=0.1))
    s.add(lotus_kolam(s, 1040, 320, 160, color='#FFD54F', opacity=0.1))
    s.save(f'{OUT}/splash_bg.svg')


def flame_halo():
    """A tall golden flame with rays, rising behind the splash logo like the Maha Deepam (600 × 600)."""
    s = SVG(600, 600, seed=157)
    s.add(f'<circle cx="300" cy="270" r="250" fill="#FFB74D" opacity="0.22" filter="{s.blur(70)}"/>')
    for i in range(24):
        a = -180 + i * (180 / 23)
        r0, r1 = 150, (292 if i % 2 else 246)
        p = [(300 + math.cos(math.radians(a + d)) * r, 300 + math.sin(math.radians(a + d)) * r) for d, r in ((-1.6, r0), (0, r1), (1.6, r0))]
        s.add(f'<polygon points="{" ".join(f"{f(x)},{f(y)}" for x, y in p)}" fill="#FFE082" opacity="{0.32 if i % 2 else 0.2}"/>')
    s.add(flame(s, 300, 400, 170, 360, glow=True))
    s.save(f'{OUT}/deepam.svg')


def flame_asset():
    """The flickering flame (150 × 240, base at 50% × 90%), its glow kept inside the image."""
    s = SVG(150, 240, seed=3)
    s.add(f'<ellipse cx="75" cy="140" rx="38" ry="66" fill="#FFB300" opacity="0.34" filter="{s.blur(14)}"/>')
    s.add(f'<ellipse cx="75" cy="160" rx="30" ry="52" fill="#FFE082" opacity="0.5" filter="{s.blur(9)}"/>')
    s.add(flame(s, 75, 216, 62, 168, glow=False))
    s.save(f'{OUT}/flame.svg')


if __name__ == '__main__':
    flame_asset()
    header_bg()
    thoranam()
    flames = hero()
    splash_bg()
    flame_halo()
    json.dump({'flames': flames, 'heroAspect': f'{HERO_W} / {HERO_H}'}, open(f'{OUT}/hero.json', 'w'), indent=1)
    print('flames', flames)
