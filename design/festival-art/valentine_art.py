"""Valentine's Day pack: deep rose night with heart bokeh and lace, a garland of roses and little
hearts, a rose bouquet beside a heart-shaped chocolate box with candlelight, a glowing heart
behind the splash logo.

Writes SVGs to out/valentine/ (same file names as the other packs); render with
  node render.mjs --dir out/valentine
"""
import json
import math
import os

from svgkit import *
from christmas_art import bow, candle, warm_light

OUT = 'out/valentine'
os.makedirs(OUT, exist_ok=True)


def heart_path(cx, cy, size):
    """Classic heart, `size` wide, centred on (cx, cy)."""
    w = size / 2
    return (f'M {f(cx)},{f(cy + w * 0.95)} C {f(cx - w * 1.15)},{f(cy + w * 0.2)} {f(cx - w * 1.05)},{f(cy - w * 0.95)} {f(cx)},{f(cy - w * 0.38)} '
            f'C {f(cx + w * 1.05)},{f(cy - w * 0.95)} {f(cx + w * 1.15)},{f(cy + w * 0.2)} {f(cx)},{f(cy + w * 0.95)} Z')


def heart(s, cx, cy, size, colours=('#FF8A9B', '#E91E63', '#880E4F'), shine=True, shadow=True):
    g = s.rad([(0, colours[0]), (0.55, colours[1]), (1, colours[2])], cx=0.35, cy=0.3, r=0.8)
    out = []
    if shadow:
        out.append(f'<path d="{heart_path(cx + size * 0.04, cy + size * 0.07, size)}" fill="#2A0010" opacity="0.3" filter="{s.blur(size * 0.06)}"/>')
    out.append(f'<path d="{heart_path(cx, cy, size)}" fill="{g}"/>')
    if shine:
        out.append(f'<ellipse cx="{f(cx - size * 0.2)}" cy="{f(cy - size * 0.18)}" rx="{f(size * 0.12)}" ry="{f(size * 0.07)}" transform="rotate(-35 {f(cx - size * 0.2)} {f(cy - size * 0.18)})" fill="#FFFFFF" opacity="0.6"/>')
    return ''.join(out)


def rose(s, cx, cy, r, colour='red'):
    """Rose seen from above: spiralled petals deepening to the centre."""
    pal = {'red': ('#FF5C7A', '#D81B3C', '#7A0019'), 'pink': ('#FFB3C6', '#F06292', '#AD1457'), 'peach': ('#FFD1B8', '#FF8A65', '#BF360C')}[colour]
    out = [f'<circle cx="{f(cx + r * 0.06)}" cy="{f(cy + r * 0.14)}" r="{f(r)}" fill="#2A0010" opacity="0.3" filter="{s.blur(r * 0.15)}"/>']
    g = s.rad([(0, pal[2]), (0.5, pal[1]), (1, pal[0])], cx=cx, cy=cy, r=r, units='userSpaceOnUse')
    out.append(f'<circle cx="{f(cx)}" cy="{f(cy)}" r="{f(r)}" fill="{g}"/>')
    for k in range(5):           # outer petals: soft arcs around the rim
        a0 = k * 72 + 10
        rr = r * 0.92
        a1, a2 = math.radians(a0), math.radians(a0 + 80)
        out.append(f'<path d="M {f(cx + math.cos(a1) * rr)},{f(cy + math.sin(a1) * rr)} A {f(rr)},{f(rr)} 0 0 1 {f(cx + math.cos(a2) * rr)},{f(cy + math.sin(a2) * rr)}" '
                   f'stroke="{pal[2]}" stroke-opacity="0.45" stroke-width="{f(max(1, r * 0.05))}" fill="none"/>')
    turns = 2.4
    pts = []
    for i in range(80):          # the spiral of inner petals
        t = i / 79
        a = t * turns * math.tau
        rr = r * 0.78 * (1 - t) + r * 0.05
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    d = 'M ' + ' L '.join(f'{f(x)},{f(y)}' for x, y in pts)
    out.append(f'<path d="{d}" stroke="{pal[2]}" stroke-opacity="0.6" stroke-width="{f(max(1, r * 0.07))}" fill="none" stroke-linecap="round"/>')
    out.append(f'<path d="{d}" stroke="{pal[0]}" stroke-opacity="0.55" stroke-width="{f(max(0.6, r * 0.03))}" fill="none" transform="translate({f(-r * 0.03)} {f(-r * 0.04)})"/>')
    out.append(f'<circle cx="{f(cx - r * 0.3)}" cy="{f(cy - r * 0.35)}" r="{f(r * 0.3)}" fill="#FFFFFF" opacity="0.14" filter="{s.blur(r * 0.1)}"/>')
    return ''.join(out)


def rose_leaf(s, x, y, length, angle):
    g = s.lin([(0, '#1B5E20'), (1, '#4CAF50')], x1=0, y1=0, x2=1, y2=0)
    L, w = length, length * 0.38
    return (f'<g transform="translate({f(x)} {f(y)}) rotate({f(angle)})"><path d="M 0,0 Q {f(L * 0.45)},{f(-w)} {f(L)},0 Q {f(L * 0.45)},{f(w)} 0,0 Z" fill="{g}"/>'
            f'<line x1="0" y1="0" x2="{f(L * 0.95)}" y2="0" stroke="#A5D6A7" stroke-opacity="0.6" stroke-width="1.2"/></g>')


def lace(s, cx, cy, R, opacity=0.14, colour='#FFFFFF'):
    """Paper-lace doily: scalloped rings and pierced dots."""
    out = [f'<g opacity="{f(opacity)}" fill="none" stroke="{colour}" stroke-width="2.2">']
    for k, t in enumerate((0.35, 0.6, 0.85, 1.0)):
        r = R * t
        n = 12 + k * 8
        pts = []
        for i in range(n * 2 + 1):
            a = math.radians(i * 180 / n)
            rr = r * (1 if i % 2 == 0 else 0.93)
            pts.append(f'{f(cx + math.cos(a) * rr)},{f(cy + math.sin(a) * rr)}')
        out.append(f'<polyline points="{" ".join(pts)}"/>')
        for i in range(n):
            a = math.radians(i * 360 / n + 180 / n)
            out.append(f'<circle cx="{f(cx + math.cos(a) * r * 0.87)}" cy="{f(cy + math.sin(a) * r * 0.87)}" r="{f(R * 0.012)}" fill="{colour}" stroke="none"/>')
    for i in range(8):
        a = i * 45
        out.append(f'<path d="{heart_path(cx + math.cos(math.radians(a)) * R * 0.48, cy + math.sin(math.radians(a)) * R * 0.48, R * 0.12)}"/>')
    out.append('</g>')
    return ''.join(out)


def heart_bokeh(s, x, y, size, colour, opacity):
    return f'<path d="{heart_path(x, y, size)}" fill="{colour}" opacity="{f(opacity)}" filter="{s.blur(size * 0.12)}"/>'


def chocolate_box(s, cx, cy, size):
    """Open heart-shaped box: red velvet rim, gold paper cups, glossy chocolates."""
    out = [f'<path d="{heart_path(cx + 6, cy + 10, size * 1.05)}" fill="#2A0010" opacity="0.35" filter="{s.blur(size * 0.05)}"/>',
           f'<path d="{heart_path(cx, cy, size)}" fill="{s.lin([(0, "#E53950"), (1, "#7A0019")], x1=0, y1=0, x2=1, y2=1)}"/>',
           f'<path d="{heart_path(cx, cy + size * 0.01, size * 0.84)}" fill="#4A0012"/>']
    rnd = s.rnd
    spots = [(-0.2, -0.12), (0.2, -0.12), (-0.28, 0.05), (0.0, 0.0), (0.28, 0.05), (-0.13, 0.18), (0.13, 0.18), (0.0, 0.32)]
    for dx, dy in spots:
        x, y = cx + dx * size, cy + dy * size
        r = size * 0.075
        out.append(f'<circle cx="{f(x)}" cy="{f(y + r * 0.15)}" r="{f(r * 1.18)}" fill="{s.lin([(0, "#FFE7A0"), (1, "#B07A10")])}" stroke="#8A5A00" stroke-width="0.8" stroke-dasharray="2 1.5"/>')
        kind = rnd.choice(['dark', 'milk', 'heart'])
        if kind == 'heart':
            out.append(heart(s, x, y, r * 2, ('#8D4A2C', '#5A2A12', '#2E1206'), shadow=False))
        else:
            g = s.rad([(0, '#A0613A' if kind == 'milk' else '#6B3A22'), (1, '#3A1A0A')], cx=0.35, cy=0.3, r=0.75)
            out.append(f'<circle cx="{f(x)}" cy="{f(y)}" r="{f(r)}" fill="{g}"/>')
            out.append(f'<path d="M {f(x - r * 0.6)},{f(y - r * 0.1)} q {f(r * 0.3)},{f(-r * 0.35)} {f(r * 0.6)},0 t {f(r * 0.6)},0" stroke="#D7A27A" stroke-width="{f(r * 0.12)}" fill="none" opacity="0.8"/>')
        out.append(f'<circle cx="{f(x - r * 0.35)}" cy="{f(y - r * 0.4)}" r="{f(r * 0.2)}" fill="#FFFFFF" opacity="0.35"/>')
    return ''.join(out)


def bouquet(s, cx, base_y, size):
    """Roses gathered in kraft paper, tied with a red bow."""
    out = []
    paper = s.lin([(0, '#F3E3CF'), (0.5, '#E0C8A8'), (1, '#B89A78')], x1=0, y1=0, x2=1, y2=0)
    w = size
    out.append(f'<path d="M {f(cx - w * 0.5)},{f(base_y - w * 0.95)} L {f(cx - w * 0.1)},{f(base_y)} L {f(cx + w * 0.1)},{f(base_y)} L {f(cx + w * 0.5)},{f(base_y - w * 0.95)} Q {f(cx)},{f(base_y - w * 0.8)} {f(cx - w * 0.5)},{f(base_y - w * 0.95)} Z" fill="{paper}"/>')
    for (dx, dy, a) in [(-0.38, -0.95, -40), (0.36, -0.98, 220), (-0.1, -1.18, -80), (0.2, -1.12, 260)]:
        out.append(rose_leaf(s, cx + dx * w, base_y + dy * w, w * 0.3, a))
    for (dx, dy, r, c) in [(-0.22, -1.0, 0.17, 'red'), (0.2, -1.02, 0.17, 'red'), (0.0, -1.18, 0.16, 'pink'), (-0.02, -0.9, 0.15, 'red'), (0.34, -1.2, 0.12, 'pink'), (-0.36, -1.18, 0.12, 'pink')]:
        out.append(rose(s, cx + dx * w, base_y + dy * w, w * r, c))
    out.append(f'<path d="M {f(cx - w * 0.5)},{f(base_y - w * 0.95)} L {f(cx - w * 0.1)},{f(base_y)} L {f(cx - w * 0.02)},{f(base_y)} L {f(cx - w * 0.3)},{f(base_y - w * 0.78)} Z" fill="#FFFFFF" opacity="0.25"/>')
    out.append(bow(s, cx, base_y - w * 0.42, w * 0.2))
    return ''.join(out)


HERO_W, HERO_H = 480, 300


def hero():
    s = SVG(HERO_W, HERO_H, seed=17)
    s.add(f'<ellipse cx="240" cy="286" rx="230" ry="14" fill="#FFFFFF" opacity="0.10" filter="{s.blur(6)}"/>')
    s.add(bouquet(s, 335, 290, 180))
    s.add(chocolate_box(s, 165, 222, 150))
    for x, h_ in ((48, 84), (440, 70)):
        s.add(candle(s, x, 288, h_, 22, colour=('#F8BBD0', '#EC407A')))
    for x, y, sz in [(110, 120, 22), (255, 80, 16), (420, 140, 18)]:
        s.add(heart(s, x, y, sz, shadow=False))
    s.save(f'{OUT}/hero.svg')
    flames = [(48, 288 - 84 - 8, 34), (440, 288 - 70 - 8, 32)]
    return [(round(x / HERO_W, 4), round(y / HERO_H, 4), round(sz / HERO_W, 4)) for x, y, sz in flames]


def rose_night(s, W_, H_, gx, gy):
    s.add(f'<rect width="{W_}" height="{H_}" fill="{s.lin([(0, "#2E0618"), (0.38, "#540E2F"), (0.75, "#7D1442"), (1, "#951A4E")])}"/>')
    s.add(f'<rect width="{W_}" height="{H_}" fill="{s.rad([(0, "#FF80AB", 0.30), (1, "#FF80AB", 0)], cx=gx, cy=gy, r=600, units="userSpaceOnUse")}"/>')


def header_bg():
    s = SVG(1170, 1050, seed=23)
    rose_night(s, 1170, 1050, 960, 560)
    s.add(lace(s, 1070, 520, 360, opacity=0.13))
    rnd = s.rnd
    for _ in range(18):
        s.add(heart_bokeh(s, rnd.uniform(430, 1160), rnd.uniform(150, 990), rnd.uniform(18, 54), rnd.choice(['#FF80AB', '#FFB3C6', '#F48FB1']), rnd.uniform(0.12, 0.3)))
    for _ in range(12):
        s.add(sparkle(s, rnd.uniform(420, 1160), rnd.uniform(150, 1000), rnd.uniform(3.5, 10), opacity=rnd.uniform(0.3, 0.8), glow='#FF80AB'))
    s.save(f'{OUT}/header_bg.svg')


SWAGS = [(-40, 392, 48), (392, 774, 38), (774, 1210, 45)]
ANCHOR_Y = 6


def _rope(x0, x1, sag, t):
    cx, cy = (x0 + x1) / 2, ANCHOR_Y + 2 * sag
    x = (1 - t) ** 2 * x0 + 2 * (1 - t) * t * cx + t * t * x1
    y = (1 - t) ** 2 * ANCHOR_Y + 2 * (1 - t) * t * cy + t * t * ANCHOR_Y
    dx = 2 * (1 - t) * (cx - x0) + 2 * t * (x1 - cx)
    dy = 2 * (1 - t) * (cy - ANCHOR_Y) + 2 * t * (ANCHOR_Y - cy)
    return x, y, math.degrees(math.atan2(dy, dx))


def thoranam():
    """Rose garland in swags: roses and leaves along a satin ribbon, little hearts hanging, bows at the ties."""
    s = SVG(1170, 132, seed=29)
    rnd = s.rnd
    leaves, ribbons, flowers, charms = [], [], [], []
    for k, (x0, x1, sag) in enumerate(SWAGS):
        cx, cy = (x0 + x1) / 2, ANCHOR_Y + 2 * sag
        ribbons.append(f'<path d="M {f(x0)},{ANCHOR_Y} Q {f(cx)},{f(cy)} {f(x1)},{ANCHOR_Y}" stroke="#F8BBD0" stroke-width="5" fill="none"/>')
        ribbons.append(f'<path d="M {f(x0)},{ANCHOR_Y - 1.5} Q {f(cx)},{f(cy - 1.5)} {f(x1)},{ANCHOR_Y - 1.5}" stroke="#FFFFFF" stroke-opacity="0.6" stroke-width="1.6" fill="none"/>')
        n = int(abs(x1 - x0) / 30)
        for i in range(n):
            t = (i + 0.5) / n + rnd.uniform(-0.12, 0.12) / n
            if t < 0.04 or t > 0.96:
                continue
            x, y, ang = _rope(x0, x1, sag, t)
            leaves.append(rose_leaf(s, x, y + 2, rnd.uniform(20, 26), ang + rnd.choice([50, 130]) + rnd.uniform(-15, 15)))
            flowers.append(rose(s, x, y + 2, rnd.uniform(12, 15), rnd.choice(['red', 'red', 'pink'])))
            if i % 3 == 1:
                drop = rnd.uniform(22, 44)
                charms.append(f'<line x1="{f(x)}" y1="{f(y + 10)}" x2="{f(x)}" y2="{f(y + drop)}" stroke="#F8BBD0" stroke-width="1.4"/>')
                charms.append(heart(s, x, y + drop + 7, rnd.uniform(13, 17), shadow=False))
    for ax in (392, 774):
        charms.append(f'<line x1="{ax}" y1="{ANCHOR_Y + 14}" x2="{ax}" y2="{ANCHOR_Y + 62}" stroke="#F8BBD0" stroke-width="1.6"/>')
        charms.append(heart(s, ax, ANCHOR_Y + 72, 24))
        charms.append(bow(s, ax, ANCHOR_Y + 12, 19))
    s.add(''.join(leaves) + ''.join(ribbons) + ''.join(flowers) + ''.join(charms))
    s.save(f'{OUT}/thoranam.svg')


def splash_bg():
    W_, H_ = 1170, 2532
    s = SVG(W_, H_, seed=31)
    rose_night(s, W_, H_, 585, 1050)
    s.add(lace(s, 585, 2290, 330, opacity=0.16))
    s.add(lace(s, 140, 300, 170, opacity=0.1))
    s.add(lace(s, 1030, 300, 170, opacity=0.1))
    rnd = s.rnd
    for _ in range(28):
        s.add(heart_bokeh(s, rnd.uniform(0, W_), rnd.uniform(160, H_ - 120), rnd.uniform(20, 64), rnd.choice(['#FF80AB', '#FFB3C6', '#F48FB1']), rnd.uniform(0.1, 0.25)))
    s.save(f'{OUT}/splash_bg.svg')


def heart_halo():
    """A glowing heart rising behind the splash logo card (600 × 600, transparent)."""
    s = SVG(600, 600, seed=37)
    s.add(f'<circle cx="300" cy="300" r="260" fill="#FF80AB" opacity="0.22" filter="{s.blur(70)}"/>')
    s.add(f'<path d="{heart_path(300, 300, 360)}" fill="#FFB3C6" opacity="0.4" filter="{s.blur(22)}"/>')
    s.add(heart(s, 300, 300, 300, ('#FF8FA8', '#F0306A', '#A0003A'), shadow=False))
    s.save(f'{OUT}/heart.svg')


if __name__ == '__main__':
    header_bg()
    thoranam()
    flames = hero()
    splash_bg()
    heart_halo()
    json.dump({'flames': flames, 'heroAspect': f'{HERO_W} / {HERO_H}'}, open(f'{OUT}/hero.json', 'w'), indent=1)
    print('flames', flames)
