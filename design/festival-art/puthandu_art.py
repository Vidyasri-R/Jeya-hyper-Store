"""Tamil New Year (Puthandu) pack: peacock-teal Kanchipuram silk woven with gold mango buttas, a
thoranam of mango leaves with malli and kanakambaram strings and hanging konrai (golden shower)
bunches, a brass kuthuvilakku beside the kani tray (mukkani: mango, jackfruit and banana, with
betel leaves, coins and the kani mirror), and a pink lotus rising behind the splash logo.

Writes SVGs to out/puthandu/ (same file names as the other packs); render with
  node render.mjs --dir out/puthandu
"""
import json
import math
import os

from svgkit import *
from banners import brass_plate, kuthuvilakku, kuthuvilakku_wicks

OUT = 'out/puthandu'
os.makedirs(OUT, exist_ok=True)

GOLD = '#FFD54F'


# ───────────────────────── motifs ─────────────────────────

def _polar(cx, cy, r, deg):
    a = math.radians(deg)
    return cx + math.cos(a) * r, cy + math.sin(a) * r


def _petal_path(cx, cy, deg, r0, r1, half):
    """Pointed petal from radius r0 to its tip at r1, `half` degrees wide each side."""
    bl, br = _polar(cx, cy, r0, deg - half), _polar(cx, cy, r0, deg + half)
    tip = _polar(cx, cy, r1, deg)
    cl = _polar(cx, cy, r0 + (r1 - r0) * 0.55, deg - half * 1.15)
    cr = _polar(cx, cy, r0 + (r1 - r0) * 0.55, deg + half * 1.15)
    return f'M {f(bl[0])},{f(bl[1])} Q {f(cl[0])},{f(cl[1])} {f(tip[0])},{f(tip[1])} Q {f(cr[0])},{f(cr[1])} {f(br[0])},{f(br[1])}'


def lotus_kolam(s, cx, cy, R, color=GOLD, opacity=0.14, stroke=2.4):
    """Thamarai kolam in line art: eight inner petals, sixteen double-lined lotus petals, dot rings, a looped rim."""
    out = [f'<g opacity="{f(opacity)}" fill="none" stroke="{color}" stroke-width="{f(stroke)}" stroke-linecap="round" stroke-linejoin="round">']

    def dot(x, y, r):
        return f'<circle cx="{f(x)}" cy="{f(y)}" r="{f(r)}" fill="{color}" stroke="none"/>'

    out.append(dot(cx, cy, R * 0.05))
    out.append(f'<circle cx="{f(cx)}" cy="{f(cy)}" r="{f(R * 0.15)}"/>')
    for i in range(8):
        out.append(f'<path d="{_petal_path(cx, cy, i * 45, R * 0.15, R * 0.42, 19)}"/>')
        out.append(dot(*_polar(cx, cy, R * 0.32, i * 45 + 22.5), stroke * 1.1))
    for i in range(24):
        out.append(dot(*_polar(cx, cy, R * 0.48, i * 15), stroke * 0.95))
    for i in range(16):
        a = i * 22.5 + 11.25
        out.append(f'<path d="{_petal_path(cx, cy, a, R * 0.52, R * 0.9, 10.5)}"/>')
        out.append(f'<path d="{_petal_path(cx, cy, a, R * 0.58, R * 0.78, 5.5)}"/>')
        out.append(dot(*_polar(cx, cy, R * 0.98, a), stroke * 1.15))
        out.append(dot(*_polar(cx, cy, R * 0.68, a + 11.25), stroke * 0.9))
    pts = [_polar(cx, cy, R * (1.08 + 0.035 * math.cos(math.radians(i * 360 / 192 * 16))), i * 360 / 192) for i in range(193)]
    out.append('<polyline points="' + ' '.join(f'{f(x)},{f(y)}' for x, y in pts) + '"/>')
    out.append('</g>')
    return ''.join(out)


def butta_field(s, x0, y0, x1, y1, step, size, color=GOLD, opacity=0.08):
    """Gold mango buttas woven into the silk in staggered rows."""
    out = [f'<g opacity="{f(opacity)}">']
    row, y = 0, y0
    while y < y1:
        x = x0 + (step / 2 if row % 2 else 0)
        while x < x1:
            out.append(paisley(s, x, y, size, angle=-24 if row % 2 else 24, color=color, opacity=1))
            x += step
        y += step * 0.75
        row += 1
    out.append('</g>')
    return ''.join(out)


def silk(s, W_, H_, glow=None):
    """Mayil kazhuthu (peacock-neck) teal silk with a soft diagonal sheen; optional warm lamp glow."""
    s.add(f'<rect width="{W_}" height="{H_}" fill="{s.lin([(0, "#042A31"), (0.38, "#073F49"), (0.75, "#0A5864"), (1, "#0E6D7A")])}"/>')
    s.add(f'<rect width="{W_}" height="{H_}" fill="{s.lin([(0, "#FFFFFF", 0), (0.42, "#9FF5FF", 0.07), (0.5, "#FFFFFF", 0), (0.62, "#9FF5FF", 0.05), (1, "#FFFFFF", 0)], x1=0, y1=0, x2=1, y2=1)}"/>')
    if glow:
        gx, gy, gr = glow
        s.add(f'<rect width="{W_}" height="{H_}" fill="{s.rad([(0, "#B8F4FF", 0.2), (0.6, "#7FE3EE", 0.07), (1, "#7FE3EE", 0)], cx=gx, cy=gy, r=gr, units="userSpaceOnUse")}"/>')
        s.add(f'<rect width="{W_}" height="{H_}" fill="{s.rad([(0, "#FFD27A", 0.2), (1, "#FFD27A", 0)], cx=gx, cy=gy, r=gr * 0.45, units="userSpaceOnUse")}"/>')


def konrai(s, cx, cy, r, rot=0):
    """Konrai poo (Cassia fistula, golden shower): five round cupped petals and long curved stamens."""
    rnd = s.rnd
    g = s.rad([(0, '#FFFBD0'), (0.5, '#FFE433'), (1, '#F5B800')], cx=0.5, cy=0.5, r=0.62)
    out = [f'<circle cx="{f(cx + r * 0.08)}" cy="{f(cy + r * 0.16)}" r="{f(r * 0.9)}" fill="#3A2C00" opacity="0.25" filter="{s.blur(max(0.6, r * 0.14))}"/>']
    for i in range(5):
        a = rot + i * 72 + rnd.uniform(-6, 6)
        px, py = _polar(cx, cy, r * 0.44, a)
        out.append(f'<ellipse cx="{f(px)}" cy="{f(py)}" rx="{f(r * 0.5)}" ry="{f(r * 0.42)}" transform="rotate({f(a)} {f(px)} {f(py)})" fill="{g}" stroke="#D69A00" stroke-opacity="0.5" stroke-width="{f(max(0.5, r * 0.04))}"/>')
        ex, ey = _polar(cx, cy, r * 0.72, a)
        out.append(f'<line x1="{f(cx)}" y1="{f(cy)}" x2="{f(ex)}" y2="{f(ey)}" stroke="#F2A900" stroke-opacity="0.45" stroke-width="{f(max(0.4, r * 0.05))}"/>')
    for k in (-1, 0, 1):   # three long stamens curling down out of the flower
        a = rot + 90 + k * 28
        ex, ey = _polar(cx, cy, r * 1.05, a)
        mx, my = _polar(cx, cy, r * 0.7, a - 25)
        out.append(f'<path d="M {f(cx)},{f(cy)} Q {f(mx)},{f(my)} {f(ex)},{f(ey)}" stroke="#B88A00" stroke-width="{f(max(0.5, r * 0.06))}" fill="none" stroke-linecap="round"/>')
        out.append(f'<circle cx="{f(ex)}" cy="{f(ey)}" r="{f(max(0.6, r * 0.08))}" fill="#8A5A00"/>')
    out.append(f'<circle cx="{f(cx)}" cy="{f(cy)}" r="{f(r * 0.16)}" fill="#E8A400"/>')
    return ''.join(out)


def konrai_cluster(s, x, y, length, sway=0.0, scale=1.0):
    """A konrai raceme hanging from (x, y): open flowers at the top, buds tapering to the tip."""
    rnd = s.rnd
    ex, ey = x + sway, y + length
    qx, qy = x + sway * 0.15 + length * 0.06, y + length * 0.55
    stalk = f'<path d="M {f(x)},{f(y)} Q {f(qx)},{f(qy)} {f(ex)},{f(ey)}" stroke="#7E8C2E" stroke-width="{f(1.6 * scale)}" fill="none" stroke-linecap="round"/>'
    n = max(5, int(length / (8 * scale)))
    items = []
    bud = s.lin([(0, '#F7F29A'), (1, '#BFCB45')], x1=0, y1=0, x2=0, y2=1)
    for i in range(n):
        t = 0.06 + 0.94 * i / (n - 1)
        bx = (1 - t) ** 2 * x + 2 * (1 - t) * t * qx + t * t * ex
        by = (1 - t) ** 2 * y + 2 * (1 - t) * t * qy + t * t * ey
        side = -1 if i % 2 else 1
        if t < 0.68:
            r = (10.5 - 6 * t) * scale
            fx, fy = bx + side * r * 0.7, by + r * 0.35
            items.append(f'<line x1="{f(bx)}" y1="{f(by)}" x2="{f(fx)}" y2="{f(fy)}" stroke="#8C9A36" stroke-width="{f(0.9 * scale)}"/>'
                         + konrai(s, fx, fy, r, rot=rnd.uniform(0, 72)))
        else:
            r = (5.2 - 3.4 * (t - 0.68) / 0.32) * scale
            items.append(f'<ellipse cx="{f(bx + side * r * 0.5)}" cy="{f(by)}" rx="{f(r * 0.62)}" ry="{f(r * 0.85)}" fill="{bud}" stroke="#8C9A36" stroke-opacity="0.5" stroke-width="0.6"/>')
    return stalk + ''.join(reversed(items))   # the bigger flowers at the top sit in front


def malli(s, cx, cy, r, rot=0, bud=False):
    """Madurai malli: a closed bud (white teardrop) or an open star of narrow petals."""
    if bud:
        g = s.lin([(0, '#FFFFFF'), (0.7, '#F7F3E3'), (1, '#D8E2B8')], x1=0, y1=0, x2=0, y2=1)
        return (f'<g transform="translate({f(cx)} {f(cy)}) rotate({f(rot)})">'
                f'<ellipse cx="{f(r * 0.06)}" cy="{f(r * 0.12)}" rx="{f(r * 0.42)}" ry="{f(r * 0.95)}" fill="#2B2B20" opacity="0.25" filter="{s.blur(max(0.6, r * 0.12))}"/>'
                f'<path d="M 0,{f(-r)} C {f(r * 0.5)},{f(-r * 0.6)} {f(r * 0.42)},{f(r * 0.5)} 0,{f(r * 0.85)} C {f(-r * 0.42)},{f(r * 0.5)} {f(-r * 0.5)},{f(-r * 0.6)} 0,{f(-r)} Z" fill="{g}" stroke="#C9C1A6" stroke-width="0.6"/>'
                f'<path d="M {f(-r * 0.12)},{f(-r * 0.55)} Q {f(-r * 0.2)},0 {f(-r * 0.08)},{f(r * 0.45)}" stroke="#FFFFFF" stroke-width="{f(r * 0.12)}" fill="none" stroke-linecap="round" opacity="0.9"/>'
                f'</g>')
    out = [f'<circle cx="{f(cx + r * 0.08)}" cy="{f(cy + r * 0.14)}" r="{f(r * 0.9)}" fill="#2B2B20" opacity="0.22" filter="{s.blur(max(0.6, r * 0.14))}"/>']
    for k in range(6):
        a = rot + k * 60
        px, py = _polar(cx, cy, r * 0.5, a)
        out.append(f'<ellipse cx="{f(px)}" cy="{f(py)}" rx="{f(r * 0.52)}" ry="{f(r * 0.24)}" transform="rotate({f(a)} {f(px)} {f(py)})" fill="#FFFEF8" stroke="#D2CAB2" stroke-width="0.6"/>')
    out.append(f'<circle cx="{f(cx)}" cy="{f(cy)}" r="{f(r * 0.16)}" fill="#F3E7A6"/>')
    return ''.join(out)


def kanakambaram(s, cx, cy, r, rot=0):
    """Kanakambaram (firecracker flower): five rounded saffron petals fanned to one side."""
    g = s.rad([(0, '#FFE0C2'), (0.45, '#FF9A52'), (1, '#F0601E')], cx=0.5, cy=0.5, r=0.62)
    out = [f'<circle cx="{f(cx + r * 0.08)}" cy="{f(cy + r * 0.16)}" r="{f(r * 0.85)}" fill="#3A1200" opacity="0.25" filter="{s.blur(max(0.6, r * 0.14))}"/>']
    for k in range(5):
        a = rot - 110 + k * 55
        px, py = _polar(cx, cy, r * 0.5, a)
        out.append(f'<ellipse cx="{f(px)}" cy="{f(py)}" rx="{f(r * 0.5)}" ry="{f(r * 0.36)}" transform="rotate({f(a)} {f(px)} {f(py)})" fill="{g}" stroke="#D84315" stroke-opacity="0.45" stroke-width="{f(max(0.5, r * 0.05))}"/>')
    out.append(f'<circle cx="{f(cx)}" cy="{f(cy)}" r="{f(r * 0.15)}" fill="#FFF3E0"/>')
    return ''.join(out)


MANGO_SKINS = {
    'ripe': ([(0, '#FFE58A'), (0.45, '#FFB300'), (1, '#E8650C')], '#E53935', 0.5),
    'yellow': ([(0, '#FFF6A8'), (0.5, '#FDD835'), (1, '#E0A800')], '#FB8C00', 0.3),
    'raw': ([(0, '#D4EBA0'), (0.5, '#8BC34A'), (1, '#3D7A1E')], '#C0CA33', 0.3),
}


def mango(s, cx, cy, L, angle=0, kind='ripe', leaf=True):
    """A mango with its stalk at the top: plump shoulders, the 'beak' low on one side."""
    stops, blush, blush_a = MANGO_SKINS[kind]
    w = L * 0.74
    d = (f'M 0,{f(-L * 0.5)} '
         f'C {f(w * 0.62)},{f(-L * 0.54)} {f(w * 0.66)},{f(L * 0.16)} {f(w * 0.14)},{f(L * 0.46)} '
         f'C {f(-w * 0.06)},{f(L * 0.56)} {f(-w * 0.34)},{f(L * 0.47)} {f(-w * 0.44)},{f(L * 0.24)} '
         f'C {f(-w * 0.56)},{f(-L * 0.04)} {f(-w * 0.52)},{f(-L * 0.47)} 0,{f(-L * 0.5)} Z')
    g = s.lin(stops, x1=0.15, y1=0, x2=0.7, y2=1)
    clip = s.clip(f'<path d="{d}"/>')
    rnd = s.rnd
    spots = ''.join(f'<circle cx="{f(rnd.uniform(-w * 0.45, w * 0.45))}" cy="{f(rnd.uniform(-L * 0.4, L * 0.45))}" r="{f(max(0.5, L * 0.008))}" fill="#FFF8D0" opacity="0.55"/>'
                    for _ in range(int(10 + L * 0.2)))
    out = [f'<g transform="translate({f(cx)} {f(cy)}) rotate({f(angle)})">',
           f'<path d="{d}" fill="#2A1400" opacity="0.32" transform="translate({f(L * 0.05)} {f(L * 0.08)})" filter="{s.blur(L * 0.05)}"/>',
           f'<path d="{d}" fill="{g}"/>',
           f'<g clip-path="{clip}">'
           f'<ellipse cx="{f(w * 0.28)}" cy="{f(-L * 0.18)}" rx="{f(w * 0.42)}" ry="{f(L * 0.3)}" fill="{blush}" opacity="{f(blush_a)}" filter="{s.blur(L * 0.08)}"/>'
           f'<ellipse cx="{f(w * 0.3)}" cy="{f(L * 0.3)}" rx="{f(w * 0.6)}" ry="{f(L * 0.3)}" fill="#5A2600" opacity="0.18" filter="{s.blur(L * 0.08)}"/>'
           f'{spots}</g>',
           f'<ellipse cx="{f(-w * 0.2)}" cy="{f(-L * 0.22)}" rx="{f(w * 0.1)}" ry="{f(L * 0.16)}" transform="rotate(18 {f(-w * 0.2)} {f(-L * 0.22)})" fill="#FFFFFF" opacity="0.4" filter="{s.blur(L * 0.02)}"/>',
           f'<path d="M 0,{f(-L * 0.49)} q {f(L * 0.02)},{f(-L * 0.06)} {f(L * 0.06)},{f(-L * 0.09)}" stroke="#5D4037" stroke-width="{f(max(1.2, L * 0.035))}" fill="none" stroke-linecap="round"/>']
    if leaf:
        out.append(mango_leaf(s, L * 0.06, -L * 0.58, L * 0.62, L * 0.22, angle=-118, tone=1))
    out.append('</g>')
    return ''.join(out)


def jackfruit(s, cx, cy, rx, ry, angle=0):
    """Palaa pazham: a big green-gold oval covered in little hexagonal spikes."""
    g = s.rad([(0, '#E9F08F'), (0.5, '#B6BF2E'), (1, '#6F7D14')], cx=0.38, cy=0.34, r=0.78)
    clip = s.clip(f'<ellipse cx="0" cy="0" rx="{f(rx)}" ry="{f(ry)}"/>')
    sp = rx * 0.17
    bumps, j, y = [], 0, -ry
    while y <= ry:
        x = -rx + (sp / 2 if j % 2 else 0)
        while x <= rx:
            bumps.append(f'<circle cx="{f(x)}" cy="{f(y)}" r="{f(sp * 0.46)}" fill="#D8E05A" fill-opacity="0.35" stroke="#55620C" stroke-opacity="0.5" stroke-width="{f(max(0.6, sp * 0.08))}"/>'
                         f'<circle cx="{f(x)}" cy="{f(y)}" r="{f(sp * 0.09)}" fill="#4A5508" opacity="0.7"/>')
            x += sp
        y += sp * 0.86
        j += 1
    return (f'<g transform="translate({f(cx)} {f(cy)}) rotate({f(angle)})">'
            f'<ellipse cx="{f(rx * 0.08)}" cy="{f(ry * 0.12)}" rx="{f(rx)}" ry="{f(ry)}" fill="#1A2000" opacity="0.32" filter="{s.blur(rx * 0.1)}"/>'
            f'<ellipse cx="0" cy="0" rx="{f(rx)}" ry="{f(ry)}" fill="{g}"/>'
            f'<g clip-path="{clip}">{"".join(bumps)}'
            f'<ellipse cx="{f(rx * 0.35)}" cy="{f(ry * 0.35)}" rx="{f(rx * 0.9)}" ry="{f(ry * 0.8)}" fill="#2E3A00" opacity="0.25" filter="{s.blur(rx * 0.2)}"/>'
            f'<ellipse cx="{f(-rx * 0.35)}" cy="{f(-ry * 0.4)}" rx="{f(rx * 0.35)}" ry="{f(ry * 0.25)}" fill="#FFFFFF" opacity="0.22" filter="{s.blur(rx * 0.08)}"/></g>'
            f'<path d="M {f(-rx * 0.06)},{f(-ry * 0.96)} L {f(-rx * 0.1)},{f(-ry * 1.18)} L {f(rx * 0.12)},{f(-ry * 1.2)} L {f(rx * 0.08)},{f(-ry * 0.96)} Z" fill="#6D5A2A"/>'
            f'<ellipse cx="{f(rx * 0.01)}" cy="{f(-ry * 1.19)}" rx="{f(rx * 0.11)}" ry="{f(rx * 0.04)}" fill="#A68B4A"/>'
            f'</g>')


def _band(points, widths):
    """Closed path around a centre line, `widths` being the half-width at each point."""
    left, right = [], []
    for i, ((x, y), w) in enumerate(zip(points, widths)):
        x0, y0 = points[max(0, i - 1)]
        x1, y1 = points[min(len(points) - 1, i + 1)]
        n = math.hypot(x1 - x0, y1 - y0) or 1
        nx, ny = -(y1 - y0) / n, (x1 - x0) / n
        left.append((x + nx * w, y + ny * w))
        right.append((x - nx * w, y - ny * w))
    return 'M ' + ' L '.join(f'{f(x)},{f(y)}' for x, y in left + right[::-1]) + ' Z'


def banana(s, x, y, L, angle=0, curve=0.2):
    """One ripe banana lying on its side, crown end at (x, y), curving up to a dark tip."""
    p0, p1, p2 = (0, 0), (L * 0.55, L * curve), (L, -L * curve * 0.35)
    pts, widths = [], []
    for i in range(25):
        t = i / 24
        pts.append(((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0], (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1]))
        widths.append(L * 0.085 * (0.28 + 0.72 * math.sin(math.pi * min(1, t * 1.08)) ** 0.7) if t < 0.96 else L * 0.02)
    d = _band(pts, widths)
    ridge = 'M ' + ' L '.join(f'{f(px)},{f(py - w * 0.25)}' for (px, py), w in list(zip(pts, widths))[2:-2])
    g = s.lin([(0, '#FFF59D'), (0.45, '#FDD835'), (1, '#D9A300')], x1=0, y1=0, x2=0, y2=1)
    return (f'<g transform="translate({f(x)} {f(y)}) rotate({f(angle)})">'
            f'<path d="{d}" fill="#3A2A00" opacity="0.3" transform="translate({f(L * 0.03)} {f(L * 0.06)})" filter="{s.blur(L * 0.03)}"/>'
            f'<path d="{d}" fill="{g}" stroke="#B08600" stroke-width="{f(max(0.6, L * 0.008))}"/>'
            f'<path d="{ridge}" stroke="#FFFDE0" stroke-opacity="0.65" stroke-width="{f(max(0.8, L * 0.018))}" fill="none" stroke-linecap="round"/>'
            f'<circle cx="{f(p2[0])}" cy="{f(p2[1])}" r="{f(L * 0.025)}" fill="#4E342E"/>'
            f'<rect x="{f(-L * 0.06)}" y="{f(-L * 0.025)}" width="{f(L * 0.08)}" height="{f(L * 0.05)}" rx="{f(L * 0.02)}" fill="#7B8B3A"/>'
            f'</g>')


def banana_hand(s, x, y, L):
    """A hand of four bananas from one crown at (x, y)."""
    out = [banana(s, x, y - L * 0.16 + k * L * 0.07, L * (0.92 + 0.03 * k), angle=-10 + k * 6, curve=0.2) for k in range(4)]
    out.append(f'<rect x="{f(x - L * 0.12)}" y="{f(y - L * 0.2)}" width="{f(L * 0.12)}" height="{f(L * 0.3)}" rx="{f(L * 0.04)}" fill="#6D5A2A"/>')
    return ''.join(out)


def betel(s, x, y, L, angle=0):
    """Vetrilai: a glossy heart-shaped betel leaf, stalk at (x, y), pointing along `angle` (0 = up)."""
    d = (f'M 0,{f(-L * 0.06)} C {f(-L * 0.2)},{f(L * 0.05)} {f(-L * 0.54)},{f(-L * 0.02)} {f(-L * 0.5)},{f(-L * 0.36)} '
         f'C {f(-L * 0.47)},{f(-L * 0.68)} {f(-L * 0.18)},{f(-L * 0.86)} 0,{f(-L)} '
         f'C {f(L * 0.18)},{f(-L * 0.86)} {f(L * 0.47)},{f(-L * 0.68)} {f(L * 0.5)},{f(-L * 0.36)} '
         f'C {f(L * 0.54)},{f(-L * 0.02)} {f(L * 0.2)},{f(L * 0.05)} 0,{f(-L * 0.06)} Z')
    g = s.lin([(0, '#8BC34A'), (0.5, '#43A047'), (1, '#1B5E20')], x1=0.2, y1=0, x2=0.8, y2=1)
    veins = [f'<path d="M 0,{f(-L * 0.06)} Q {f(L * 0.03)},{f(-L * 0.5)} 0,{f(-L * 0.97)}" stroke="#DCEDC8" stroke-opacity="0.75" stroke-width="{f(max(0.8, L * 0.02))}" fill="none"/>']
    for sgn in (-1, 1):
        for sy, ex, ey in [(-0.08, 0.36, -0.62), (-0.1, 0.22, -0.82), (-0.06, 0.44, -0.3)]:
            veins.append(f'<path d="M 0,{f(sy * L)} Q {f(sgn * ex * L * 0.85)},{f((sy + ey) * 0.5 * L)} {f(sgn * ex * L * 0.5)},{f(ey * L)}" stroke="#DCEDC8" stroke-opacity="0.4" stroke-width="{f(max(0.6, L * 0.012))}" fill="none"/>')
    return (f'<g transform="translate({f(x)} {f(y)}) rotate({f(angle)})">'
            f'<path d="{d}" fill="#0B2A0E" opacity="0.32" transform="translate({f(L * 0.04)} {f(L * 0.06)})" filter="{s.blur(L * 0.05)}"/>'
            f'<path d="{d}" fill="{g}"/>{"".join(veins)}'
            f'<path d="M {f(-L * 0.36)},{f(-L * 0.3)} Q {f(-L * 0.34)},{f(-L * 0.62)} {f(-L * 0.1)},{f(-L * 0.8)}" stroke="#FFFFFF" stroke-opacity="0.28" stroke-width="{f(L * 0.06)}" fill="none" stroke-linecap="round"/>'
            f'<line x1="0" y1="{f(-L * 0.06)}" x2="{f(L * 0.02)}" y2="{f(L * 0.12)}" stroke="#558B2F" stroke-width="{f(max(1, L * 0.035))}" stroke-linecap="round"/>'
            f'</g>')


def areca(s, x, y, r, cut=False):
    """Paakku: a whole areca nut, or one cut open to show its marbled heart."""
    shadow = f'<circle cx="{f(x + r * 0.12)}" cy="{f(y + r * 0.22)}" r="{f(r)}" fill="#2A1400" opacity="0.3" filter="{s.blur(r * 0.2)}"/>'
    if cut:
        swirl = ''.join(f'<path d="M {f(x - r * 0.5)},{f(y + k * r * 0.25)} q {f(r * 0.25)},{f(-r * 0.2)} {f(r * 0.5)},0 t {f(r * 0.5)},0" stroke="#9A6234" stroke-width="{f(r * 0.1)}" fill="none" opacity="0.7"/>' for k in (-1, 0, 1))
        return shadow + f'<circle cx="{f(x)}" cy="{f(y)}" r="{f(r)}" fill="#EAD7B4" stroke="#7A4A22" stroke-width="{f(r * 0.18)}"/>' + swirl
    g = s.rad([(0, '#D99A5B'), (0.6, '#A0622A'), (1, '#5E3612')], cx=0.38, cy=0.35, r=0.7)
    return (shadow + f'<circle cx="{f(x)}" cy="{f(y)}" r="{f(r)}" fill="{g}"/>'
            f'<ellipse cx="{f(x - r * 0.3)}" cy="{f(y - r * 0.35)}" rx="{f(r * 0.3)}" ry="{f(r * 0.18)}" fill="#FFFFFF" opacity="0.3"/>')


def coin(s, x, y, r, tilt=0.55):
    """A gold coin seen at an angle."""
    g = s.lin([(0, '#FFF3B0'), (0.45, '#F2C14E'), (1, '#A87410')], x1=0, y1=0, x2=1, y2=1)
    return (f'<ellipse cx="{f(x)}" cy="{f(y + r * tilt * 0.3)}" rx="{f(r)}" ry="{f(r * tilt)}" fill="#7A5200"/>'
            f'<ellipse cx="{f(x)}" cy="{f(y)}" rx="{f(r)}" ry="{f(r * tilt)}" fill="{g}"/>'
            f'<ellipse cx="{f(x)}" cy="{f(y)}" rx="{f(r * 0.72)}" ry="{f(r * tilt * 0.72)}" fill="none" stroke="#B07A10" stroke-width="{f(max(0.6, r * 0.08))}"/>'
            f'<ellipse cx="{f(x - r * 0.3)}" cy="{f(y - r * tilt * 0.3)}" rx="{f(r * 0.25)}" ry="{f(r * tilt * 0.18)}" fill="#FFFFFF" opacity="0.6"/>')


def mirror(s, cx, cy, r):
    """The kani mirror: a round glass in a beaded brass frame on a little stand."""
    gold = s.lin([(0, '#7A4E00'), (0.25, '#C98A12'), (0.5, '#FFE7A0'), (0.75, '#C98A12'), (1, '#6B4300')], x1=0, y1=0, x2=1, y2=1)
    glass = s.lin([(0, '#F4FBFF'), (0.45, '#C7E3F5'), (1, '#7FAFD0')], x1=0, y1=0, x2=1, y2=1)
    clip = s.clip(f'<circle cx="{f(cx)}" cy="{f(cy)}" r="{f(r)}"/>')
    beads = ''.join(f'<circle cx="{f(_polar(cx, cy, r * 1.09, a)[0])}" cy="{f(_polar(cx, cy, r * 1.09, a)[1])}" r="{f(r * 0.05)}" fill="#FFF3C4" opacity="0.85"/>' for a in range(0, 360, 20))
    return (f'<path d="M {f(cx - r * 0.55)},{f(cy + r * 1.62)} L {f(cx)},{f(cy + r * 0.6)} L {f(cx + r * 0.55)},{f(cy + r * 1.62)}" stroke="#A87410" stroke-width="{f(r * 0.12)}" fill="none" stroke-linecap="round"/>'
            f'<circle cx="{f(cx + r * 0.06)}" cy="{f(cy + r * 0.1)}" r="{f(r * 1.2)}" fill="#0A1A1E" opacity="0.35" filter="{s.blur(r * 0.12)}"/>'
            f'<circle cx="{f(cx)}" cy="{f(cy)}" r="{f(r * 1.2)}" fill="{gold}"/>{beads}'
            f'<circle cx="{f(cx)}" cy="{f(cy)}" r="{f(r)}" fill="{glass}"/>'
            f'<g clip-path="{clip}"><path d="M {f(cx - r)},{f(cy + r * 0.2)} L {f(cx + r * 0.2)},{f(cy - r)} L {f(cx + r * 0.5)},{f(cy - r)} L {f(cx - r)},{f(cy + r * 0.5)} Z" fill="#FFFFFF" opacity="0.55"/>'
            f'<path d="M {f(cx - r * 0.6)},{f(cy + r)} L {f(cx + r)},{f(cy - r * 0.6)} L {f(cx + r)},{f(cy - r * 0.45)} L {f(cx - r * 0.45)},{f(cy + r)} Z" fill="#FFFFFF" opacity="0.35"/></g>'
            f'<circle cx="{f(cx)}" cy="{f(cy - r * 1.3)}" r="{f(r * 0.15)}" fill="{gold}"/>')


def lotus(s, cx, cy, size):
    """A pink thamarai in full bloom, petals fanning up from (cx, cy)."""
    def petal(a, L, W, stops):
        d = f'M 0,0 C {f(W * 0.62)},{f(-L * 0.18)} {f(W * 0.58)},{f(-L * 0.74)} 0,{f(-L)} C {f(-W * 0.58)},{f(-L * 0.74)} {f(-W * 0.62)},{f(-L * 0.18)} 0,0 Z'
        g = s.lin(stops, x1=0, y1=1, x2=0, y2=0)
        return (f'<g transform="translate({f(cx)} {f(cy)}) rotate({f(a)})">'
                f'<path d="{d}" fill="{g}" stroke="#C2185B" stroke-opacity="0.35" stroke-width="{f(size * 0.006)}"/>'
                f'<path d="M 0,{f(-L * 0.06)} Q {f(W * 0.05)},{f(-L * 0.5)} 0,{f(-L * 0.92)}" stroke="#FFFFFF" stroke-opacity="0.5" stroke-width="{f(size * 0.008)}" fill="none"/></g>')
    out = [petal(a, size * ln, size * 0.21, [(0, '#FCE4EC'), (0.55, '#F8A5C2'), (1, '#E64A86')])
           for a, ln in [(-80, 0.4), (-54, 0.5), (-27, 0.57), (0, 0.6), (27, 0.57), (54, 0.5), (80, 0.4)]]
    out += [petal(a, size * ln, size * 0.23, [(0, '#FFFFFF'), (0.5, '#FFD1E1'), (1, '#F06292')])
            for a, ln in [(-42, 0.4), (-15, 0.46), (15, 0.46), (42, 0.4)]]
    out.append(f'<ellipse cx="{f(cx)}" cy="{f(cy - size * 0.05)}" rx="{f(size * 0.09)}" ry="{f(size * 0.035)}" fill="#F9C74F" stroke="#C98A12" stroke-width="{f(size * 0.004)}"/>')
    return ''.join(out)


def zari_border(s, y, W_, height):
    """Kanchipuram border along the bottom: a magenta band edged in gold zari with temple (koorai) triangles."""
    band = s.lin([(0, '#7A0F3C'), (0.5, '#A3154F'), (1, '#6A0C33')], x1=0, y1=0, x2=0, y2=1)
    zari = s.lin([(0, '#FFF1B8'), (0.5, '#F2C14E'), (1, '#B07A10')], x1=0, y1=0, x2=0, y2=1)
    out = []
    tw, th = 72, 58
    for i in range(int(W_ / tw) + 2):
        x = i * tw - tw / 2
        out.append(f'<path d="M {f(x)},{f(y)} L {f(x + tw / 2)},{f(y - th)} L {f(x + tw)},{f(y)} Z" fill="{zari}"/>')
        out.append(f'<path d="M {f(x + tw * 0.16)},{f(y)} L {f(x + tw / 2)},{f(y - th * 0.7)} L {f(x + tw * 0.84)},{f(y)} Z" fill="#A3154F"/>')
        out.append(f'<path d="M {f(x + tw * 0.32)},{f(y)} L {f(x + tw / 2)},{f(y - th * 0.38)} L {f(x + tw * 0.68)},{f(y)} Z" fill="{zari}" opacity="0.9"/>')
        out.append(f'<circle cx="{f(x + tw / 2)}" cy="{f(y - th - 9)}" r="4.5" fill="#FFE082"/>')
    out.append(f'<rect x="0" y="{f(y)}" width="{W_}" height="{f(height)}" fill="{band}"/>')
    for yy, hh in ((y, 7), (y + 14, 3), (y + height - 16, 3), (y + height - 7, 7)):
        out.append(f'<rect x="0" y="{f(yy)}" width="{W_}" height="{hh}" fill="{zari}"/>')
    mid = y + height / 2
    for i in range(int(W_ / 36) + 1):   # a woven row of tiny buttas and dots
        x = i * 36 + 18
        out.append(paisley(s, x, mid + 9, 15, angle=0, color='#FFE082', opacity=0.9) if i % 2 else f'<circle cx="{f(x)}" cy="{f(mid)}" r="3" fill="#FFE082"/>')
    return ''.join(out)


# ───────────────────────── pack assets ─────────────────────────

HERO_W, HERO_H = 480, 300
LAMP = (100, 288, 236)   # kuthuvilakku: x, foot y, height


def hero():
    """The kani: a brass kuthuvilakku (its five flames flicker in the app) beside the kani tray."""
    s = SVG(HERO_W, HERO_H, seed=19)
    s.add(f'<ellipse cx="250" cy="287" rx="232" ry="12" fill="#FFFFFF" opacity="0.10" filter="{s.blur(6)}"/>')
    s.add(f'<g transform="translate(300 277) scale(1 0.24)">{lotus_kolam(s, 0, 0, 190, color="#FFFFFF", opacity=0.85, stroke=6)}</g>')
    lx, lbase, lh = LAMP
    s.add(kuthuvilakku(s, lx, lbase, lh, with_flames=False))
    s.add(brass_plate(s, 322, 254, 146, 34))
    s.add(mirror(s, 424, 150, 32))
    s.add(jackfruit(s, 322, 186, 42, 54, angle=-8))
    for x, y, L, a in [(392, 238, 70, 28), (410, 242, 62, 52), (376, 240, 58, 6)]:
        s.add(betel(s, x, y, L, a))
    s.add(banana_hand(s, 206, 238, 100))
    for x, y, L, a, kind in [(300, 216, 50, 6, 'ripe'), (282, 236, 56, -14, 'yellow'), (336, 238, 56, 16, 'ripe')]:
        s.add(mango(s, x, y, L, a, kind, leaf=(kind == 'ripe' and x < 320)))
    for x, y, r in [(372, 262, 10), (390, 266, 9), (356, 268, 8)]:
        s.add(coin(s, x, y, r))
    s.add(areca(s, 414, 258, 8))
    s.add(areca(s, 428, 262, 7, cut=True))
    for x, y, r in [(236, 266, 7), (442, 248, 7)]:
        s.add(malli(s, x, y, r, rot=x))
    s.add(konrai(s, 252, 270, 8, rot=20))
    s.save(f'{OUT}/hero.svg')
    size = lh * 0.05 / 0.215   # the app's flame image is ~4.65× the flame body width
    return [(round(x / HERO_W, 4), round(y / HERO_H, 4), round(size / HERO_W, 4)) for x, y in kuthuvilakku_wicks(lx, lbase, lh)]


def header_bg():
    s = SVG(1170, 1050, seed=23)
    silk(s, 1170, 1050, glow=(960, 700, 560))
    s.add(butta_field(s, 40, 60, 1170, 1050, 128, 30, opacity=0.07))
    s.add(lotus_kolam(s, 1090, 470, 300, opacity=0.09))
    s.add(lotus_kolam(s, 70, 990, 180, opacity=0.08, stroke=2))
    rnd = s.rnd
    for _ in range(16):
        s.add(bokeh(s, rnd.uniform(420, 1170), rnd.uniform(150, 990), rnd.uniform(14, 50), rnd.choice(['#FFD54F', '#FFE433', '#FFF59D']), rnd.uniform(0.10, 0.24)))
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
    """Maavilai thoranam: a close fringe of mango leaves, malli and kanakambaram strung along the rope,
    konrai bunches hanging at the ties."""
    s = SVG(1170, 132, seed=37)
    rnd = s.rnd
    back, front_leaves, ropes, flowers, ties = [], [], [], [], []
    for k, (x0, x1, sag) in enumerate(SWAGS):
        cx, cy = (x0 + x1) / 2, ANCHOR_Y + 2 * sag
        ropes.append(f'<path d="M {f(x0)},{ANCHOR_Y} Q {f(cx)},{f(cy)} {f(x1)},{ANCHOR_Y}" stroke="#6D4C41" stroke-width="3.4" fill="none"/>')
        n = int(abs(x1 - x0) / 17)
        for i in range(n):
            t = (i + 0.5) / n
            if t < 0.03 or t > 0.97:
                continue
            x, y, ang = _rope(x0, x1, sag, t)
            depth = y - ANCHOR_Y
            leaf = mango_leaf(s, x, y + 3, rnd.uniform(56, 66) - depth * 0.32, rnd.uniform(20, 24), angle=ang * 0.6 + rnd.uniform(-7, 7), tone=i + k)
            (front_leaves if i % 2 else back).append(leaf)
        m = int(abs(x1 - x0) / 13)
        for i in range(m):
            t = (i + 0.5) / m
            if t < 0.03 or t > 0.97:
                continue
            x, y, ang = _rope(x0, x1, sag, t)
            if i % 5 in (2, 3):
                flowers.append(kanakambaram(s, x, y + 1, rnd.uniform(7.5, 8.5), rot=ang + 90))
            elif i % 5 == 0:
                flowers.append(malli(s, x, y + 1, rnd.uniform(6.8, 7.6), rot=rnd.uniform(0, 60)))
            else:
                flowers.append(malli(s, x, y + 2, rnd.uniform(5.6, 6.4), rot=ang + rnd.uniform(-20, 20), bud=True))
    for ax in (392, 774):
        ties.append(konrai_cluster(s, ax - 12, ANCHOR_Y + 10, 62, sway=-6))
        ties.append(konrai_cluster(s, ax + 12, ANCHOR_Y + 10, 56, sway=5))
        ties.append(konrai_cluster(s, ax, ANCHOR_Y + 14, 84, sway=2))
        ties.append(kanakambaram(s, ax - 13, ANCHOR_Y + 8, 11, rot=200))
        ties.append(kanakambaram(s, ax + 13, ANCHOR_Y + 8, 11, rot=-20))
        ties.append(malli(s, ax, ANCHOR_Y + 9, 10, rot=15))
    s.add(''.join(back) + ''.join(front_leaves) + ''.join(ropes) + ''.join(flowers) + ''.join(ties))
    s.save(f'{OUT}/thoranam.svg')


def splash_bg():
    W_, H_ = 1170, 2532
    s = SVG(W_, H_, seed=41)
    silk(s, W_, H_, glow=(585, 1060, 700))
    s.add(butta_field(s, 40, 220, W_, H_ - 160, 140, 32, opacity=0.07))
    s.add(lotus_kolam(s, 585, 2190, 330, opacity=0.16, stroke=3))
    s.add(lotus_kolam(s, 130, 320, 160, opacity=0.1))
    s.add(lotus_kolam(s, 1040, 320, 160, opacity=0.1))
    rnd = s.rnd
    for _ in range(22):
        s.add(bokeh(s, rnd.uniform(0, W_), rnd.uniform(180, H_ - 220), rnd.uniform(18, 60), rnd.choice(['#FFD54F', '#FFE433', '#FFF59D']), rnd.uniform(0.08, 0.2)))
    for _ in range(30):
        s.add(sparkle(s, rnd.uniform(20, W_ - 20), rnd.uniform(200, H_ - 260), rnd.uniform(4, 11), opacity=rnd.uniform(0.3, 0.8)))
    s.add(zari_border(s, H_ - 104, W_, 104))
    s.save(f'{OUT}/splash_bg.svg')


def lotus_halo():
    """A pink lotus with golden rays rising behind the splash logo card (600 × 600, transparent)."""
    s = SVG(600, 600, seed=47)
    s.add(f'<circle cx="300" cy="300" r="250" fill="#FFD54F" opacity="0.2" filter="{s.blur(70)}"/>')
    for i in range(28):
        a = -180 + i * (180 / 27)
        p1, p2, p3 = _polar(300, 330, 150, a - 1.6), _polar(300, 330, 292 if i % 2 else 250, a), _polar(300, 330, 150, a + 1.6)
        s.add(f'<polygon points="{f(p1[0])},{f(p1[1])} {f(p2[0])},{f(p2[1])} {f(p3[0])},{f(p3[1])}" fill="#FFE082" opacity="{0.34 if i % 2 else 0.22}"/>')
    s.add(f'<ellipse cx="300" cy="250" rx="190" ry="120" fill="#FFB3C6" opacity="0.28" filter="{s.blur(30)}"/>')
    s.add(lotus(s, 300, 330, 420))
    s.save(f'{OUT}/lotus.svg')


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
    lotus_halo()
    json.dump({'flames': flames, 'heroAspect': f'{HERO_W} / {HERO_H}'}, open(f'{OUT}/hero.json', 'w'), indent=1)
    print('flames', flames)
