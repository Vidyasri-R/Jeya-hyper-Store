"""Vinayagar Chathurthi pack (the festival's symbols, not the deity): a warm vermilion glow with a
gold mandala, a thoranam of erukkam poo and marigolds with arugampul tufts, a brass plate heaped
with kozhukattai under a little ceremonial kudai between two lit agal vilakku, and a festive
kudai canopy that rises over the splash logo.

Writes SVGs to out/vinayagar/ (same file names as the other packs); render with
  node render.mjs --dir out/vinayagar
"""
import json
import math
import os

from svgkit import *
from banners import brass_plate

OUT = 'out/vinayagar'
os.makedirs(OUT, exist_ok=True)


# ───────────────────────── motifs ─────────────────────────

def kozhukattai(s, cx, cy, size, fried=False, a=0):
    """Modak/kozhukattai: a plump dumpling with pleats gathered to a point."""
    w, h = size, size * 1.05
    body = (f'M 0,{f(-h * 0.55)} C {f(w * 0.08)},{f(-h * 0.35)} {f(w * 0.55)},{f(-h * 0.1)} {f(w * 0.52)},{f(h * 0.18)} '
            f'C {f(w * 0.5)},{f(h * 0.42)} {f(-w * 0.5)},{f(h * 0.42)} {f(-w * 0.52)},{f(h * 0.18)} C {f(-w * 0.55)},{f(-h * 0.1)} {f(-w * 0.08)},{f(-h * 0.35)} 0,{f(-h * 0.55)} Z')
    g = (s.rad([(0, '#FFE6B0'), (0.6, '#E8A84A'), (1, '#B5701E')], cx=0.4, cy=0.35, r=0.75) if fried
         else s.rad([(0, '#FFFFFF'), (0.6, '#F6F0E4'), (1, '#D9CDB5')], cx=0.4, cy=0.35, r=0.75))
    line = '#C08A3E' if fried else '#CFC2A6'
    pleats = ''.join(f'<path d="M 0,{f(-h * 0.5)} Q {f(k * w * 0.18)},{f(-h * 0.1)} {f(k * w * 0.3)},{f(h * 0.28)}" stroke="{line}" stroke-width="{f(max(0.8, size * 0.03))}" fill="none" opacity="0.8"/>'
                     for k in (-1.5, -0.75, 0, 0.75, 1.5))
    return (f'<g transform="translate({f(cx)} {f(cy)}) rotate({f(a)})">'
            f'<ellipse cx="{f(w * 0.06)}" cy="{f(h * 0.36)}" rx="{f(w * 0.5)}" ry="{f(h * 0.1)}" fill="#3A1200" opacity="0.35" filter="{s.blur(size * 0.06)}"/>'
            f'<path d="{body}" fill="{g}"/>{pleats}'
            f'<ellipse cx="{f(-w * 0.2)}" cy="{f(-h * 0.05)}" rx="{f(w * 0.1)}" ry="{f(h * 0.16)}" fill="#FFFFFF" opacity="0.5"/>'
            f'<circle cx="0" cy="{f(-h * 0.53)}" r="{f(max(1, size * 0.04))}" fill="{line}"/></g>')


def erukku(s, cx, cy, r, rot=0):
    """Erukkam poo (crown flower): five pointed lavender petals and the little white crown."""
    g = s.rad([(0, '#FFFFFF'), (0.6, '#E6D7F5'), (1, '#A98BD6')], cx=0.5, cy=0.5, r=0.62)
    out = [f'<circle cx="{f(cx + r * 0.08)}" cy="{f(cy + r * 0.15)}" r="{f(r * 0.9)}" fill="#2B1A3A" opacity="0.25" filter="{s.blur(max(0.6, r * 0.14))}"/>']
    for i in range(5):
        a = math.radians(rot + i * 72)
        tip = (cx + math.cos(a) * r, cy + math.sin(a) * r)
        l = (cx + math.cos(a - 0.5) * r * 0.42, cy + math.sin(a - 0.5) * r * 0.42)
        rr = (cx + math.cos(a + 0.5) * r * 0.42, cy + math.sin(a + 0.5) * r * 0.42)
        out.append(f'<path d="M {f(cx)},{f(cy)} L {f(l[0])},{f(l[1])} Q {f((l[0] + tip[0]) / 2)},{f((l[1] + tip[1]) / 2)} {f(tip[0])},{f(tip[1])} '
                   f'Q {f((rr[0] + tip[0]) / 2)},{f((rr[1] + tip[1]) / 2)} {f(rr[0])},{f(rr[1])} Z" fill="{g}" stroke="#8E6CC4" stroke-opacity="0.45" stroke-width="{f(max(0.5, r * 0.04))}"/>')
    for i in range(5):
        a = math.radians(rot + 36 + i * 72)
        out.append(f'<ellipse cx="{f(cx + math.cos(a) * r * 0.24)}" cy="{f(cy + math.sin(a) * r * 0.24)}" rx="{f(r * 0.15)}" ry="{f(r * 0.1)}" '
                   f'transform="rotate({f(math.degrees(a))} {f(cx + math.cos(a) * r * 0.24)} {f(cy + math.sin(a) * r * 0.24)})" fill="#FFFFFF" stroke="#9575CD" stroke-width="{f(max(0.4, r * 0.03))}"/>')
    out.append(f'<circle cx="{f(cx)}" cy="{f(cy)}" r="{f(r * 0.12)}" fill="#7E57C2"/>')
    return ''.join(out)


def arugampul(s, x, y, length, angle=0):
    """A little tuft of arugampul (durva grass) hanging from (x, y)."""
    rnd = s.rnd
    out = [f'<g transform="translate({f(x)} {f(y)}) rotate({f(angle)})">']
    for k in range(7):
        a = math.radians(-24 + k * 8 + rnd.uniform(-3, 3))
        L = length * rnd.uniform(0.75, 1.05)
        ex, ey = math.sin(a) * L, math.cos(a) * L
        out.append(f'<path d="M 0,0 Q {f(ex * 0.3 + 2)},{f(ey * 0.5)} {f(ex)},{f(ey)}" stroke="{rnd.choice(["#2E7D32", "#43A047", "#558B2F"])}" stroke-width="2" fill="none" stroke-linecap="round"/>')
    out.append('<circle cx="0" cy="0" r="2.6" fill="#33691E"/></g>')
    return ''.join(out)


def kudai(s, cx, top, w, colours=('#D32F2F', '#FFB300', '#2E7D32'), handle=True):
    """A ceremonial kudai: a domed canopy in coloured panels, a scalloped fringe with tassels, a gold finial."""
    h = w * 0.42
    rim = top + h
    gold = s.lin([(0, '#7A4E00'), (0.3, '#C98A12'), (0.5, '#FFE7A0'), (0.75, '#C98A12'), (1, '#6B4300')], x1=0, y1=0, x2=1, y2=0)
    out = []
    if handle:
        out.append(f'<rect x="{f(cx - w * 0.012)}" y="{f(rim - 4)}" width="{f(w * 0.024)}" height="{f(w * 0.7)}" fill="{gold}"/>')
    n = 8
    for i in range(n):
        t0, t1 = i / n, (i + 1) / n
        x0, x1 = cx - w / 2 + w * t0, cx - w / 2 + w * t1
        col = colours[i % len(colours)]
        out.append(f'<path d="M {f(cx)},{f(top)} Q {f((x0 + cx) / 2 - (cx - x0) * 0.15)},{f(top + h * 0.35)} {f(x0)},{f(rim)} L {f(x1)},{f(rim)} Q {f((x1 + cx) / 2 + (x1 - cx) * -0.15)},{f(top + h * 0.35)} {f(cx)},{f(top)} Z" fill="{col}"/>')
    out.append(f'<path d="M {f(cx - w / 2)},{f(rim)} Q {f(cx)},{f(top - h * 0.25)} {f(cx + w / 2)},{f(rim)}" fill="none" stroke="#FFFFFF" stroke-opacity="0.25" stroke-width="{f(w * 0.02)}"/>')
    # gold band and scalloped fringe with tassels
    out.append(f'<rect x="{f(cx - w / 2)}" y="{f(rim - w * 0.03)}" width="{f(w)}" height="{f(w * 0.04)}" fill="{gold}"/>')
    k = 14
    for i in range(k):
        x = cx - w / 2 + (i + 0.5) * w / k
        out.append(f'<path d="M {f(x - w / k / 2)},{f(rim + w * 0.01)} Q {f(x)},{f(rim + w * 0.075)} {f(x + w / k / 2)},{f(rim + w * 0.01)} Z" fill="{colours[(i + 1) % len(colours)]}"/>')
        out.append(f'<line x1="{f(x)}" y1="{f(rim + w * 0.05)}" x2="{f(x)}" y2="{f(rim + w * 0.1)}" stroke="#C98A12" stroke-width="{f(max(1, w * 0.006))}"/>'
                   f'<circle cx="{f(x)}" cy="{f(rim + w * 0.11)}" r="{f(max(1.4, w * 0.012))}" fill="#FFD54F"/>')
    out.append(f'<circle cx="{f(cx)}" cy="{f(top - w * 0.03)}" r="{f(w * 0.035)}" fill="{gold}"/>')
    out.append(f'<path d="M {f(cx - w * 0.02)},{f(top - w * 0.05)} L {f(cx)},{f(top - w * 0.12)} L {f(cx + w * 0.02)},{f(top - w * 0.05)} Z" fill="{gold}"/>')
    return ''.join(out)


def warm(s, W_, H_, glow=None):
    s.add(f'<rect width="{W_}" height="{H_}" fill="{s.lin([(0, "#4A1203"), (0.38, "#7A2206"), (0.75, "#A8360C"), (1, "#C2470F")])}"/>')
    if glow:
        gx, gy, gr = glow
        s.add(f'<rect width="{W_}" height="{H_}" fill="{s.rad([(0, "#FFD27A", 0.34), (0.55, "#FF9800", 0.1), (1, "#FF9800", 0)], cx=gx, cy=gy, r=gr, units="userSpaceOnUse")}"/>')


# ───────────────────────── pack assets ─────────────────────────

HERO_W, HERO_H = 480, 300
DIYAS = [(64, 230, 62), (420, 234, 58)]   # wick x, y, body width


def hero():
    """A brass plate heaped with kozhukattai under a little kudai, agal vilakku either side, erukku and grass."""
    s = SVG(HERO_W, HERO_H, seed=79)
    s.add(f'<ellipse cx="250" cy="288" rx="232" ry="12" fill="#FFFFFF" opacity="0.10" filter="{s.blur(6)}"/>')
    s.add(f'<g transform="translate(250 278) scale(1 0.24)">{mandala(s, 0, 0, 190, color="#FFFFFF", opacity=0.85, stroke=6, fill_opacity=0.08)}</g>')
    s.add(kudai(s, 250, 18, 150))
    s.add(brass_plate(s, 250, 262, 152, 34))
    heap = [(196, 244, 44, False, -6), (240, 248, 46, True, 3), (286, 246, 44, False, 6), (218, 216, 42, False, -3), (264, 214, 42, True, 4), (241, 188, 40, False, 0), (316, 240, 40, True, 10)]
    for (x, y, sz, fried, a) in heap:
        s.add(kozhukattai(s, x, y, sz, fried, a))
    for (x, y) in [(150, 266), (180, 278), (330, 276), (356, 264)]:
        s.add(erukku(s, x, y, 11, rot=x))
    s.add(arugampul(s, 132, 252, 24, angle=-30))
    s.add(arugampul(s, 372, 254, 22, angle=30))
    for i, (x, y, size) in enumerate(DIYAS):
        s.add(diya(s, x, y, size, style=i, with_flame=False))
    s.save(f'{OUT}/hero.svg')
    return [(round(x / HERO_W, 4), round(y / HERO_H, 4), round(size / HERO_W, 4)) for x, y, size in DIYAS]


def header_bg():
    s = SVG(1170, 1050, seed=83)
    warm(s, 1170, 1050, glow=(960, 700, 560))
    s.add(mandala(s, 1080, 470, 320, color='#FFD54F', opacity=0.12, stroke=2.2))
    s.add(mandala(s, 70, 990, 180, color='#FFD54F', opacity=0.07, stroke=2))
    rnd = s.rnd
    for _ in range(16):
        s.add(bokeh(s, rnd.uniform(420, 1170), rnd.uniform(150, 990), rnd.uniform(14, 50), rnd.choice(['#FFD54F', '#FFB74D', '#E1BEE7']), rnd.uniform(0.10, 0.22)))
    for _ in range(14):
        s.add(sparkle(s, rnd.uniform(420, 1160), rnd.uniform(150, 1000), rnd.uniform(3.5, 10), opacity=rnd.uniform(0.3, 0.8)))
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
    """Erukkam poo and marigolds strung in swags, arugampul tufts and bells hanging, flower rosettes at the ties."""
    s = SVG(1170, 132, seed=89)
    rnd = s.rnd
    ropes, hang, flowers, ties = [], [], [], []
    from header_art import bell
    for k, (x0, x1, sag) in enumerate(SWAGS):
        cx, cy = (x0 + x1) / 2, ANCHOR_Y + 2 * sag
        ropes.append(f'<path d="M {f(x0)},{ANCHOR_Y} Q {f(cx)},{f(cy)} {f(x1)},{ANCHOR_Y}" stroke="#5D4037" stroke-width="3.2" fill="none"/>')
        n = int(abs(x1 - x0) / 22)
        for i in range(n):
            t = (i + 0.5) / n
            if t < 0.03 or t > 0.97:
                continue
            x, y, ang = _rope(x0, x1, sag, t)
            if i % 3 == 1:
                flowers.append(marigold(s, x, y + 1, rnd.uniform(10, 12), 'orange' if i % 2 else 'yellow'))
            else:
                flowers.append(erukku(s, x, y + 1, rnd.uniform(11, 12.5), rot=rnd.uniform(0, 72)))
            if i % 4 == 2:
                hang.append(arugampul(s, x, y + 6, rnd.uniform(26, 34) - (y - ANCHOR_Y) * 0.25, angle=ang * 0.5))
    for ax in (392, 774):
        ties.append(f'<line x1="{ax}" y1="{ANCHOR_Y + 14}" x2="{ax}" y2="{ANCHOR_Y + 58}" stroke="#6D4C41" stroke-width="2"/>')
        ties.append(bell(s, ax, ANCHOR_Y + 54, 18))
        ties.append(marigold(s, ax - 15, ANCHOR_Y + 12, 13, 'orange'))
        ties.append(marigold(s, ax + 15, ANCHOR_Y + 12, 13, 'yellow'))
        ties.append(erukku(s, ax, ANCHOR_Y + 22, 15, rot=18))
    s.add(''.join(hang) + ''.join(ropes) + ''.join(flowers) + ''.join(ties))
    s.save(f'{OUT}/thoranam.svg')


def splash_bg():
    W_, H_ = 1170, 2532
    s = SVG(W_, H_, seed=97)
    warm(s, W_, H_, glow=(585, 1060, 700))
    s.add(mandala(s, 585, 2200, 330, color='#FFD54F', opacity=0.16, stroke=3))
    s.add(mandala(s, 130, 320, 160, color='#FFD54F', opacity=0.1))
    s.add(mandala(s, 1040, 320, 160, color='#FFD54F', opacity=0.1))
    rnd = s.rnd
    for _ in range(22):
        s.add(bokeh(s, rnd.uniform(0, W_), rnd.uniform(180, H_ - 220), rnd.uniform(18, 60), rnd.choice(['#FFD54F', '#FFB74D', '#E1BEE7']), rnd.uniform(0.08, 0.2)))
    for _ in range(30):
        s.add(sparkle(s, rnd.uniform(20, W_ - 20), rnd.uniform(200, H_ - 260), rnd.uniform(4, 11), opacity=rnd.uniform(0.3, 0.8)))
    for x in (90, 1080):   # erukku garlands hanging down the sides
        for k in range(14):
            y = 520 + k * 46
            s.add(erukku(s, x + (8 if k % 2 else -8), y, 16, rot=k * 20))
            if k % 3 == 1:
                s.add(marigold(s, x - (10 if k % 2 else -10), y + 22, 14, 'orange'))
    s.save(f'{OUT}/splash_bg.svg')


def kudai_halo():
    """A festive kudai canopy over the splash logo (600 × 600): its dome and fringe show above the card."""
    s = SVG(600, 600, seed=101)
    s.add(f'<circle cx="300" cy="250" r="240" fill="#FFD27A" opacity="0.22" filter="{s.blur(60)}"/>')
    for i in range(22):
        a = -180 + i * (180 / 21)
        r0, r1 = 150, (292 if i % 2 else 246)
        p = [(300 + math.cos(math.radians(a + d)) * r, 250 + math.sin(math.radians(a + d)) * r) for d, r in ((-1.6, r0), (0, r1), (1.6, r0))]
        s.add(f'<polygon points="{" ".join(f"{f(x)},{f(y)}" for x, y in p)}" fill="#FFE082" opacity="{0.3 if i % 2 else 0.18}"/>')
    s.add(kudai(s, 300, 92, 420, handle=False))
    s.save(f'{OUT}/kudai.svg')


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
    kudai_halo()
    json.dump({'flames': flames, 'heroAspect': f'{HERO_W} / {HERO_H}'}, open(f'{OUT}/hero.json', 'w'), indent=1)
    print('flames', flames)
