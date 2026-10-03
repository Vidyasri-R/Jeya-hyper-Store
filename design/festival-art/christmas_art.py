"""Christmas & New Year pack: starry navy night, New Year fireworks, a pine garland with red baubles,
gold bells and warm lights, a decorated tree with gifts and candles, the paper star lantern hung
outside Tamil Nadu homes.

Writes SVGs to out/christmas/ (same file names as the other packs); render with
  node render.mjs --dir out/christmas
"""
import json
import math
import os

from svgkit import *
from header_art import bell
from banners import giftbox

OUT = 'out/christmas'
os.makedirs(OUT, exist_ok=True)


# ───────────────────────── motifs ─────────────────────────

def pine_branch(s, x, y, length, angle, tone=0):
    """Fir sprig from (x, y) along angle (degrees, 0 = right): a twig with dense needles."""
    greens = [('#1B5E20', '#2E7D32', '#43A047'), ('#14532D', '#1E6B3A', '#2F8F4E'), ('#0F4D2A', '#1B6B37', '#388E3C')][tone % 3]
    rnd = s.rnd
    out = [f'<g transform="translate({f(x)} {f(y)}) rotate({f(angle)})">']
    out.append(f'<path d="M 0,0 L {f(length)},0" stroke="#3E2723" stroke-width="{f(max(1.2, length * 0.03))}" fill="none"/>')
    n = int(length / 3.2)
    for i in range(n):
        t = i / n
        px = t * length
        nl = length * 0.22 * (1 - t * 0.55)
        for sgn in (-1, 1):
            a = math.radians(sgn * rnd.uniform(38, 62))
            ex, ey = px + math.cos(a) * nl, math.sin(a) * nl
            out.append(f'<line x1="{f(px)}" y1="0" x2="{f(ex)}" y2="{f(ey)}" stroke="{rnd.choice(greens)}" stroke-width="{f(max(1, length * 0.022))}" stroke-linecap="round"/>')
    out.append('</g>')
    return ''.join(out)


def bauble(s, cx, cy, r, colour='red'):
    pal = {'red': ('#FF8A80', '#E53935', '#8E0000'), 'gold': ('#FFF59D', '#FBC02D', '#9A6A0A'), 'blue': ('#90CAF9', '#1E88E5', '#0D3C7A'), 'silver': ('#FFFFFF', '#B0BEC5', '#546E7A')}[colour]
    g = s.rad([(0, pal[0]), (0.45, pal[1]), (1, pal[2])], cx=0.35, cy=0.32, r=0.75)
    cap = s.lin([(0, '#FFE7A0'), (1, '#B07A10')], x1=0, y1=0, x2=1, y2=0)
    return (f'<circle cx="{f(cx + r * 0.08)}" cy="{f(cy + r * 0.18)}" r="{f(r)}" fill="#000" opacity="0.28" filter="{s.blur(r * 0.2)}"/>'
            f'<circle cx="{f(cx)}" cy="{f(cy)}" r="{f(r)}" fill="{g}"/>'
            f'<ellipse cx="{f(cx - r * 0.35)}" cy="{f(cy - r * 0.38)}" rx="{f(r * 0.24)}" ry="{f(r * 0.14)}" transform="rotate(-35 {f(cx - r * 0.35)} {f(cy - r * 0.38)})" fill="#FFFFFF" opacity="0.75"/>'
            f'<rect x="{f(cx - r * 0.24)}" y="{f(cy - r * 1.18)}" width="{f(r * 0.48)}" height="{f(r * 0.3)}" rx="{f(r * 0.06)}" fill="{cap}"/>'
            f'<path d="M {f(cx)},{f(cy - r * 1.18)} q {f(r * 0.18)},{f(-r * 0.3)} 0,{f(-r * 0.36)}" stroke="#B07A10" stroke-width="{f(max(1, r * 0.08))}" fill="none"/>')


def warm_light(s, cx, cy, r, colour='#FFE082'):
    return (f'<circle cx="{f(cx)}" cy="{f(cy)}" r="{f(r * 2.6)}" fill="{colour}" opacity="0.35" filter="{s.blur(r * 1.2)}"/>'
            f'<circle cx="{f(cx)}" cy="{f(cy)}" r="{f(r)}" fill="{colour}"/><circle cx="{f(cx - r * 0.3)}" cy="{f(cy - r * 0.3)}" r="{f(r * 0.35)}" fill="#FFFFFF" opacity="0.8"/>')


def bow(s, cx, cy, size):
    g = s.lin([(0, '#FF5252'), (0.5, '#D32F2F'), (1, '#8E0000')], x1=0, y1=0, x2=1, y2=1)
    w = size
    return (f'<path d="M {f(cx)},{f(cy)} C {f(cx - w)},{f(cy - w * 0.7)} {f(cx - w * 1.15)},{f(cy + w * 0.35)} {f(cx)},{f(cy)} Z" fill="{g}" stroke="#7A0000" stroke-width="1"/>'
            f'<path d="M {f(cx)},{f(cy)} C {f(cx + w)},{f(cy - w * 0.7)} {f(cx + w * 1.15)},{f(cy + w * 0.35)} {f(cx)},{f(cy)} Z" fill="{g}" stroke="#7A0000" stroke-width="1"/>'
            f'<path d="M {f(cx - 2)},{f(cy)} L {f(cx - w * 0.45)},{f(cy + w * 1.05)} L {f(cx - w * 0.15)},{f(cy + w * 0.95)} Z" fill="{g}"/>'
            f'<path d="M {f(cx + 2)},{f(cy)} L {f(cx + w * 0.45)},{f(cy + w * 1.05)} L {f(cx + w * 0.15)},{f(cy + w * 0.95)} Z" fill="{g}"/>'
            f'<circle cx="{f(cx)}" cy="{f(cy)}" r="{f(w * 0.2)}" fill="#B71C1C"/>')


def star_points(cx, cy, R, r, n=5, rot=-90):
    pts = []
    for i in range(n * 2):
        a = math.radians(rot + i * 180 / n)
        rr = R if i % 2 == 0 else r
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    return pts


def star_lantern(s, cx, cy, R):
    """The paper star lantern hung outside homes at Christmas: glowing, red-edged, with tassels."""
    out = [f'<line x1="{f(cx)}" y1="{f(cy - R * 2.2)}" x2="{f(cx)}" y2="{f(cy - R)}" stroke="#E0C080" stroke-width="{f(max(1.5, R * 0.03))}"/>',
           f'<circle cx="{f(cx)}" cy="{f(cy)}" r="{f(R * 1.9)}" fill="#FFD54F" opacity="0.22" filter="{s.blur(R * 0.55)}"/>',
           f'<circle cx="{f(cx)}" cy="{f(cy)}" r="{f(R * 1.1)}" fill="#FFF3C4" opacity="0.35" filter="{s.blur(R * 0.25)}"/>']
    # tassels from the two lower points
    for k, (px, py) in enumerate(star_points(cx, cy, R, R * 0.46)[::2]):
        if py < cy + R * 0.2:
            continue
        for j in range(5):
            dx = (j - 2) * R * 0.035
            out.append(f'<path d="M {f(px + dx)},{f(py)} q {f(R * 0.04)},{f(R * 0.5)} {f(dx * 0.5)},{f(R * (1.05 + 0.08 * (j % 3)))}" stroke="{["#FFD54F", "#FF5252", "#FFFFFF"][j % 3]}" stroke-width="{f(max(1.2, R * 0.03))}" fill="none" stroke-linecap="round" opacity="0.9"/>')
    pts = star_points(cx, cy, R, R * 0.46)
    poly = ' '.join(f'{f(x)},{f(y)}' for x, y in pts)
    g = s.rad([(0, '#FFFDE7'), (0.5, '#FFE082'), (1, '#FFB300')], cx=0.5, cy=0.5, r=0.6)
    out.append(f'<polygon points="{poly}" fill="{g}" stroke="#D32F2F" stroke-width="{f(max(2, R * 0.07))}" stroke-linejoin="round"/>')
    inner = ' '.join(f'{f(x)},{f(y)}' for x, y in star_points(cx, cy, R * 0.62, R * 0.28))
    out.append(f'<polygon points="{inner}" fill="#FFFFFF" opacity="0.55" stroke="#FF8A65" stroke-width="{f(max(1, R * 0.03))}" stroke-linejoin="round"/>')
    for x, y in pts[::2]:
        out.append(f'<line x1="{f(cx)}" y1="{f(cy)}" x2="{f(x)}" y2="{f(y)}" stroke="#E57373" stroke-opacity="0.55" stroke-width="{f(max(1, R * 0.025))}"/>')
    return ''.join(out)


def firework(s, cx, cy, R, colour='#FFD54F', opacity=0.35, rays=18):
    out = [f'<g opacity="{f(opacity)}">', f'<circle cx="{f(cx)}" cy="{f(cy)}" r="{f(R * 0.5)}" fill="{colour}" opacity="0.25" filter="{s.blur(R * 0.3)}"/>']
    for i in range(rays):
        a = math.radians(i * 360 / rays + 7)
        r1, r2 = R * 0.22, R * (0.85 + 0.15 * (i % 2))
        x1, y1, x2, y2 = cx + math.cos(a) * r1, cy + math.sin(a) * r1, cx + math.cos(a) * r2, cy + math.sin(a) * r2
        out.append(f'<line x1="{f(x1)}" y1="{f(y1)}" x2="{f(x2)}" y2="{f(y2)}" stroke="{colour}" stroke-width="{f(max(1.2, R * 0.025))}" stroke-linecap="round"/>')
        out.append(f'<circle cx="{f(x2 + math.cos(a) * R * 0.08)}" cy="{f(y2 + math.sin(a) * R * 0.08)}" r="{f(max(1.5, R * 0.03))}" fill="{colour}"/>')
    out.append('</g>')
    return ''.join(out)


def snowflake(s, cx, cy, r, opacity=0.8):
    out = [f'<g opacity="{f(opacity)}" stroke="#FFFFFF" stroke-width="{f(max(1, r * 0.12))}" stroke-linecap="round">']
    for i in range(6):
        a = math.radians(i * 60)
        ex, ey = cx + math.cos(a) * r, cy + math.sin(a) * r
        out.append(f'<line x1="{f(cx)}" y1="{f(cy)}" x2="{f(ex)}" y2="{f(ey)}"/>')
        for t, b in ((0.55, 0.32),):
            bx, by = cx + math.cos(a) * r * t, cy + math.sin(a) * r * t
            for sgn in (-1, 1):
                a2 = a + sgn * math.radians(45)
                out.append(f'<line x1="{f(bx)}" y1="{f(by)}" x2="{f(bx + math.cos(a2) * r * b)}" y2="{f(by + math.sin(a2) * r * b)}"/>')
    out.append('</g>')
    return ''.join(out)


def xmas_tree(s, cx, base_y, h):
    """Layered fir with a gold star, baubles, a bead garland and warm lights."""
    w = h * 0.62
    out = [f'<ellipse cx="{f(cx)}" cy="{f(base_y + 4)}" rx="{f(w * 0.55)}" ry="{f(h * 0.04)}" fill="#000" opacity="0.35" filter="{s.blur(h * 0.02)}"/>',
           f'<rect x="{f(cx - w * 0.07)}" y="{f(base_y - h * 0.12)}" width="{f(w * 0.14)}" height="{f(h * 0.12)}" fill="#5D4037"/>']
    tiers = [(0.0, 1.0, 0.36), (0.24, 0.8, 0.34), (0.46, 0.6, 0.3), (0.64, 0.4, 0.26)]
    g = s.lin([(0, '#43A047'), (0.5, '#2E7D32'), (1, '#1B5E20')], x1=0, y1=0, x2=1, y2=1)
    top_y = base_y - h * 0.98
    for (lift, width, tall) in tiers:
        by = base_y - h * 0.1 - lift * h
        hw = w * width / 2
        ty = by - tall * h
        scallop = ' '.join(f'Q {f(cx - hw + (i + 0.5) * hw * 2 / 6)},{f(by + h * 0.035)} {f(cx - hw + (i + 1) * hw * 2 / 6)},{f(by)}' for i in range(6))
        out.append(f'<path d="M {f(cx - hw)},{f(by)} {scallop} L {f(cx)},{f(ty)} Z" fill="{g}" stroke="#14532D" stroke-width="1.5"/>')
        out.append(f'<path d="M {f(cx)},{f(ty)} L {f(cx - hw * 0.55)},{f(by - h * 0.02)}" stroke="#81C784" stroke-opacity="0.35" stroke-width="2"/>')
    # bead garlands
    for k, (y0, y1, x0, x1) in enumerate([(0.22, 0.32, -0.42, 0.42), (0.44, 0.52, -0.32, 0.32), (0.64, 0.7, -0.22, 0.22)]):
        ya, yb = base_y - h * (1 - y0) * 0.95, base_y - h * (1 - y1) * 0.95
        d = f'M {f(cx + x0 * w)},{f(ya)} Q {f(cx)},{f(yb + h * 0.06)} {f(cx + x1 * w)},{f(ya - h * 0.02)}'
        out.append(f'<path d="{d}" stroke="#FFD54F" stroke-width="{f(max(1.5, h * 0.008))}" stroke-dasharray="1 {f(h * 0.018)}" stroke-linecap="round" fill="none"/>')
    rnd = s.rnd
    for (fx, fy, col) in [(-0.28, 0.2, 'red'), (0.22, 0.24, 'gold'), (-0.05, 0.3, 'blue'), (0.3, 0.42, 'red'), (-0.25, 0.46, 'gold'),
                          (0.05, 0.55, 'red'), (-0.15, 0.68, 'blue'), (0.16, 0.7, 'gold'), (0.0, 0.8, 'red')]:
        out.append(bauble(s, cx + fx * w, base_y - h * fy * 0.95 - h * 0.08, h * 0.035, col))
    for _ in range(14):
        t = rnd.uniform(0.12, 0.85)
        half = w * 0.5 * (1 - t) * 0.92
        out.append(warm_light(s, cx + rnd.uniform(-half, half), base_y - h * 0.1 - t * h * 0.85, h * 0.009, rnd.choice(['#FFE082', '#FFAB91', '#B3E5FC'])))
    sp = ' '.join(f'{f(x)},{f(y)}' for x, y in star_points(cx, top_y, h * 0.07, h * 0.03))
    out.append(f'<circle cx="{f(cx)}" cy="{f(top_y)}" r="{f(h * 0.1)}" fill="#FFD54F" opacity="0.4" filter="{s.blur(h * 0.04)}"/>')
    out.append(f'<polygon points="{sp}" fill="{s.rad([(0, "#FFFDE7"), (0.6, "#FFD54F"), (1, "#F9A825")], cx=0.5, cy=0.5, r=0.6)}" stroke="#C98A12" stroke-width="1.5" stroke-linejoin="round"/>')
    return ''.join(out)


def candle(s, x, base_y, h, w, colour=('#EF5350', '#B71C1C')):
    g = s.lin([(0, colour[0]), (0.6, colour[1]), (1, '#7A0E0E')], x1=0, y1=0, x2=1, y2=0)
    return (f'<ellipse cx="{f(x)}" cy="{f(base_y + 2)}" rx="{f(w * 0.9)}" ry="{f(w * 0.25)}" fill="#000" opacity="0.35" filter="{s.blur(3)}"/>'
            f'<rect x="{f(x - w / 2)}" y="{f(base_y - h)}" width="{f(w)}" height="{f(h)}" rx="{f(w * 0.12)}" fill="{g}"/>'
            f'<path d="M {f(x - w / 2)},{f(base_y - h + 4)} q {f(w * 0.15)},{f(h * 0.2)} {f(w * 0.25)},0 q {f(w * 0.1)},{f(h * 0.12)} {f(w * 0.3)},0" fill="{colour[0]}" opacity="0.85"/>'
            f'<ellipse cx="{f(x)}" cy="{f(base_y - h)}" rx="{f(w / 2)}" ry="{f(w * 0.16)}" fill="#FF8A80"/>'
            f'<rect x="{f(x - w * 0.3)}" y="{f(base_y - h + 6)}" width="{f(w * 0.12)}" height="{f(h - 12)}" fill="#FFFFFF" opacity="0.2"/>'
            f'<line x1="{f(x)}" y1="{f(base_y - h)}" x2="{f(x)}" y2="{f(base_y - h - w * 0.35)}" stroke="#3E2723" stroke-width="2"/>')


# ───────────────────────── pack assets ─────────────────────────

HERO_W, HERO_H = 480, 300


def hero():
    """Decorated tree on the right, gifts at its foot, two candles on the left (their flames flicker)."""
    s = SVG(HERO_W, HERO_H, seed=7)
    s.add(f'<ellipse cx="240" cy="284" rx="230" ry="16" fill="#FFFFFF" opacity="0.12" filter="{s.blur(6)}"/>')
    s.add(xmas_tree(s, 330, 288, 258))
    s.add(giftbox(s, 205, 222, 70, 62, body=('#E53935', '#8E0000')))
    s.add(giftbox(s, 395, 238, 58, 48, body=('#1E88E5', '#0D3C7A')))
    s.add(giftbox(s, 262, 246, 52, 40, body=('#43A047', '#1B5E20')))
    for x, h_ in ((80, 92), (130, 70)):
        s.add(candle(s, x, 286, h_, 24))
    for x, y, r in [(48, 278, 4), (165, 280, 3.5), (30, 260, 3)]:
        s.add(warm_light(s, x, y, r))
    s.save(f'{OUT}/hero.svg')
    # flames on the candle wicks: (x, y of the flame base, size) as fractions of the image
    flames = [(80, 286 - 92 - 8, 40), (130, 286 - 70 - 8, 34)]
    return [(round(x / HERO_W, 4), round(y / HERO_H, 4), round(sz / HERO_W, 4)) for x, y, sz in flames]


def night(s, W_, H_, glow_x, glow_y):
    s.add(f'<rect width="{W_}" height="{H_}" fill="{s.lin([(0, "#060F26"), (0.35, "#0C1D42"), (0.75, "#132C62"), (1, "#1A3874")])}"/>')
    s.add(f'<rect width="{W_}" height="{H_}" fill="{s.rad([(0, "#5C7BD9", 0.28), (1, "#5C7BD9", 0)], cx=glow_x, cy=glow_y, r=600, units="userSpaceOnUse")}"/>')
    rnd = s.rnd
    for _ in range(int(W_ * H_ / 9000)):
        x, y = rnd.uniform(0, W_), rnd.uniform(0, H_)
        s.add(f'<circle cx="{f(x)}" cy="{f(y)}" r="{f(rnd.uniform(0.8, 2.2))}" fill="#FFFFFF" opacity="{f(rnd.uniform(0.25, 0.8))}"/>')


def header_bg():
    s = SVG(1170, 1050, seed=19)
    night(s, 1170, 1050, 960, 520)
    # New Year fireworks low on the right, clear of the store name and the profile button
    s.add(firework(s, 1000, 470, 120, '#FFD54F', 0.24))
    s.add(firework(s, 790, 590, 80, '#FF8A80', 0.2))
    s.add(firework(s, 1120, 700, 70, '#80DEEA', 0.18))
    rnd = s.rnd
    for _ in range(16):
        s.add(snowflake(s, rnd.uniform(420, 1160), rnd.uniform(160, 1000), rnd.uniform(6, 14), opacity=rnd.uniform(0.25, 0.6)))
    for _ in range(12):
        s.add(sparkle(s, rnd.uniform(420, 1160), rnd.uniform(150, 1000), rnd.uniform(3.5, 10), opacity=rnd.uniform(0.3, 0.8)))
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
    """Pine garland in swags: fir sprigs, red and gold baubles, warm lights, bows and bells at the ties."""
    s = SVG(1170, 132, seed=37)
    rnd = s.rnd
    greens, lights, balls, knots = [], [], [], []
    for k, (x0, x1, sag) in enumerate(SWAGS):
        # a full garland: sprigs every few pixels, most of them drooping below the rope
        n = int(abs(x1 - x0) / 7)
        for i in range(n):
            t = (i + 0.5) / n
            x, y, ang = _rope(x0, x1, sag, t)
            droop = rnd.uniform(20, 70) if i % 3 else rnd.uniform(-25, 15)
            side = 180 if i % 2 else 0
            greens.append(pine_branch(s, x, y, rnd.uniform(30, 44), ang + side + (droop if side == 0 else -droop), tone=i))
        m = int(abs(x1 - x0) / 46)
        for i in range(m):
            t = (i + 0.5) / m
            if t < 0.06 or t > 0.94:
                continue
            x, y, _ = _rope(x0, x1, sag, t)
            if i % 2 == 0:
                drop = rnd.uniform(16, 30)
                balls.append(f'<line x1="{f(x)}" y1="{f(y)}" x2="{f(x)}" y2="{f(y + drop - 12)}" stroke="#E0C080" stroke-width="1.2"/>')
                balls.append(bauble(s, x, y + drop, rnd.uniform(9, 12), rnd.choice(['red', 'red', 'gold'])))
            else:
                lights.append(warm_light(s, x + rnd.uniform(-6, 6), y + rnd.uniform(-4, 6), 4.2, rnd.choice(['#FFE082', '#FFAB91', '#FFF59D'])))
    for ax in (392, 774):
        knots.append(f'<line x1="{ax}" y1="{ANCHOR_Y + 14}" x2="{ax}" y2="{ANCHOR_Y + 60}" stroke="#E0C080" stroke-width="2"/>')
        knots.append(bell(s, ax - 8, ANCHOR_Y + 58, 18))
        knots.append(bell(s, ax + 9, ANCHOR_Y + 54, 15))
        knots.append(bow(s, ax, ANCHOR_Y + 14, 20))
    s.add(''.join(greens) + ''.join(lights) + ''.join(balls) + ''.join(knots))
    s.save(f'{OUT}/thoranam.svg')


def splash_bg():
    W_, H_ = 1170, 2532
    s = SVG(W_, H_, seed=43)
    night(s, W_, H_, 585, 1050)
    for (x, y, R, c, o) in [(250, 520, 170, '#FFD54F', 0.35), (920, 430, 200, '#FF8A80', 0.32), (620, 260, 120, '#80DEEA', 0.3), (1020, 2050, 150, '#FFD54F', 0.25), (170, 2150, 130, '#CE93D8', 0.25)]:
        s.add(firework(s, x, y, R, c, o))
    rnd = s.rnd
    for _ in range(26):
        s.add(snowflake(s, rnd.uniform(20, W_ - 20), rnd.uniform(160, H_ - 160), rnd.uniform(7, 16), opacity=rnd.uniform(0.25, 0.6)))
    s.save(f'{OUT}/splash_bg.svg')


def star_halo():
    """Star lantern rising behind the splash logo card (600 × 600, transparent)."""
    s = SVG(600, 600, seed=47)
    s.add(star_lantern(s, 300, 300, 150))
    s.save(f'{OUT}/star.svg')


if __name__ == '__main__':
    header_bg()
    thoranam()
    flames = hero()
    splash_bg()
    star_halo()
    json.dump({'flames': flames, 'heroAspect': f'{HERO_W} / {HERO_H}'}, open(f'{OUT}/hero.json', 'w'), indent=1)
    print('flames', flames)
