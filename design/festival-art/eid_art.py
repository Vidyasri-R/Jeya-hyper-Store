"""Eid (Ramzan & Bakrid) pack: a violet night sky with gold eight-point star patterns and a crescent
moon, a garland of little lanterns, stars and crescents on a gold chain, a standing lantern (its
candle flickers in the app) beside a brass bowl of dates and a glass of rose milk, a crescent and
star glowing behind the splash logo, and a soft skyline of domes and minarets at the foot.

Writes SVGs to out/eid/ (same file names as the other packs); render with
  node render.mjs --dir out/eid
"""
import json
import math
import os

from svgkit import *
from banners import brass_plate
from christmas_art import star_points

OUT = 'out/eid'
os.makedirs(OUT, exist_ok=True)

GOLD = '#FFD54F'


# ───────────────────────── motifs ─────────────────────────

def _pts(points):
    return ' '.join(f'{f(x)},{f(y)}' for x, y in points)


def star8(cx, cy, R, rot=0):
    """Eight-point star (two squares) as polygon points."""
    out = []
    for i in range(16):
        a = math.radians(rot + i * 22.5)
        r = R if i % 2 == 0 else R * 0.7654
        out.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    return out


def star_field(s, x0, y0, x1, y1, step, R, color=GOLD, opacity=0.08, stroke=1.6):
    """Islamic eight-point stars in a lattice, with little crosses between them."""
    out = [f'<g opacity="{f(opacity)}" fill="none" stroke="{color}" stroke-width="{f(stroke)}" stroke-linejoin="round">']
    row, y = 0, y0
    while y < y1:
        x = x0 + (step / 2 if row % 2 else 0)
        while x < x1:
            out.append(f'<polygon points="{_pts(star8(x, y, R))}"/>')
            out.append(f'<polygon points="{_pts(star8(x, y, R * 0.42, 22.5))}"/>')
            x += step
        y += step / 2
        row += 1
    out.append('</g>')
    return ''.join(out)


def rosette(s, cx, cy, R, color=GOLD, opacity=0.14, stroke=2.2):
    """A large geometric rosette: nested eight-point stars, a sixteen-point ring and dots."""
    out = [f'<g opacity="{f(opacity)}" fill="none" stroke="{color}" stroke-width="{f(stroke)}" stroke-linejoin="round">']
    for k, (r, rot) in enumerate([(0.18, 0), (0.32, 22.5), (0.5, 0), (0.62, 22.5), (0.86, 0)]):
        out.append(f'<polygon points="{_pts(star8(cx, cy, R * r, rot))}"/>')
    out.append(f'<circle cx="{f(cx)}" cy="{f(cy)}" r="{f(R * 0.72)}"/>')
    pts = []
    for i in range(32):
        a = math.radians(i * 11.25)
        rr = R * (1.0 if i % 2 == 0 else 0.92)
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    out.append(f'<polygon points="{_pts(pts)}"/>')
    for i in range(16):
        a = math.radians(i * 22.5 + 11.25)
        out.append(f'<circle cx="{f(cx + math.cos(a) * R * 0.78)}" cy="{f(cy + math.sin(a) * R * 0.78)}" r="{f(stroke * 1.2)}" fill="{color}" stroke="none"/>')
    out.append(f'<circle cx="{f(cx)}" cy="{f(cy)}" r="{f(R * 0.06)}" fill="{color}" stroke="none"/>')
    out.append('</g>')
    return ''.join(out)


def crescent(s, cx, cy, r, fill, rot=-30, cut=0.86, offset=0.42):
    """Crescent moon: a disc with an offset disc masked away."""
    mid = s.uid('mk')
    s.defs.append(f'<mask id="{mid}" maskUnits="userSpaceOnUse" x="{f(cx - r * 2)}" y="{f(cy - r * 2)}" width="{f(r * 4)}" height="{f(r * 4)}">'
                  f'<circle cx="{f(cx)}" cy="{f(cy)}" r="{f(r)}" fill="#fff"/>'
                  f'<circle cx="{f(cx + r * offset)}" cy="{f(cy - r * 0.12)}" r="{f(r * cut)}" fill="#000"/></mask>')
    return f'<g transform="rotate({f(rot)} {f(cx)} {f(cy)})"><circle cx="{f(cx)}" cy="{f(cy)}" r="{f(r)}" fill="{fill}" mask="url(#{mid})"/></g>'


def gold_crescent(s, cx, cy, r, rot=-30):
    g = s.lin([(0, '#FFF3C4'), (0.45, '#F6C445'), (1, '#B07A10')], x1=0, y1=0, x2=1, y2=1)
    return (f'<circle cx="{f(cx)}" cy="{f(cy)}" r="{f(r * 1.25)}" fill="#FFE082" opacity="0.28" filter="{s.blur(r * 0.35)}"/>'
            + crescent(s, cx, cy, r, g, rot=rot))


def star5(s, cx, cy, r, colour=('#FFF3C4', '#F6C445', '#B07A10'), rot=-90):
    g = s.lin([(0, colour[0]), (0.5, colour[1]), (1, colour[2])], x1=0, y1=0, x2=1, y2=1)
    return f'<polygon points="{_pts(star_points(cx, cy, r, r * 0.45, 5, rot))}" fill="{g}" stroke="#8A5A00" stroke-width="{f(max(0.5, r * 0.06))}" stroke-linejoin="round"/>'


GLASS = {'amber': ('#FFE9A8', '#F2A23A', '#B85E0E'), 'ruby': ('#FFC2C8', '#E0485A', '#8E1528'), 'teal': ('#C2F2EE', '#2BB3A6', '#0E6B63'), 'violet': ('#E7D2FF', '#9C5CE0', '#4E2490')}


def lantern(s, cx, top, h, glass='amber', glow=True):
    """A fanoos: domed cap and finial, coloured glass panels in a pierced gold frame, a candle inside.
    Returns (svg, wick) — the app draws the flickering flame at the wick."""
    w = h * 0.46
    gold = s.lin([(0, '#7A4E00'), (0.25, '#C98A12'), (0.5, '#FFE7A0'), (0.75, '#C98A12'), (1, '#6B4300')], x1=0, y1=0, x2=1, y2=0)
    g0, g1, g2 = GLASS[glass]
    yc0, yc1 = top + h * 0.1, top + h * 0.27
    yb0, yb1 = yc1 + h * 0.03, top + h * 0.8
    wick = (cx, yb1 - h * 0.17)
    out = []
    if glow:
        out.append(f'<ellipse cx="{f(cx)}" cy="{f((yb0 + yb1) / 2)}" rx="{f(w * 1.1)}" ry="{f(h * 0.42)}" fill="#FFC14D" opacity="0.32" filter="{s.blur(h * 0.09)}"/>')
    out.append(f'<ellipse cx="{f(cx + h * 0.03)}" cy="{f(top + h * 1.02)}" rx="{f(w * 0.55)}" ry="{f(h * 0.035)}" fill="#0A0418" opacity="0.4" filter="{s.blur(h * 0.02)}"/>')
    out.append(f'<circle cx="{f(cx)}" cy="{f(top + h * 0.035)}" r="{f(h * 0.028)}" fill="none" stroke="#C98A12" stroke-width="{f(h * 0.012)}"/>')
    out.append(f'<circle cx="{f(cx)}" cy="{f(top + h * 0.078)}" r="{f(h * 0.022)}" fill="{gold}"/>')
    out.append(f'<path d="M {f(cx - w * 0.42)},{f(yc1)} C {f(cx - w * 0.44)},{f(yc0 + h * 0.07)} {f(cx - w * 0.12)},{f(yc0)} {f(cx)},{f(yc0)} '
               f'C {f(cx + w * 0.12)},{f(yc0)} {f(cx + w * 0.44)},{f(yc0 + h * 0.07)} {f(cx + w * 0.42)},{f(yc1)} Z" fill="{gold}"/>')
    for i in range(-2, 3):
        out.append(f'<circle cx="{f(cx + i * w * 0.14)}" cy="{f(yc1 - h * 0.05 - (2 - abs(i)) * h * 0.012)}" r="{f(h * 0.011)}" fill="#5A3A00" opacity="0.7"/>')
    out.append(f'<rect x="{f(cx - w * 0.48)}" y="{f(yc1)}" width="{f(w * 0.96)}" height="{f(h * 0.03)}" rx="{f(h * 0.01)}" fill="{gold}"/>')
    # glass: a bright centre panel, darker side panels, lit from inside
    for x0, x1, k in [(-0.45, -0.25, 0.55), (0.25, 0.45, 0.55), (-0.25, 0.25, 1.0)]:
        lg = s.lin([(0, g0), (0.5, g1), (1, g2)], x1=0, y1=0, x2=0, y2=1)
        out.append(f'<rect x="{f(cx + w * x0)}" y="{f(yb0)}" width="{f(w * (x1 - x0))}" height="{f(yb1 - yb0)}" fill="{lg}" opacity="{f(0.55 + 0.4 * k)}"/>')
    out.append(f'<ellipse cx="{f(wick[0])}" cy="{f(wick[1] + h * 0.02)}" rx="{f(w * 0.3)}" ry="{f(h * 0.2)}" fill="#FFF3C4" opacity="0.75" filter="{s.blur(h * 0.05)}"/>')
    # candle
    out.append(f'<rect x="{f(cx - w * 0.07)}" y="{f(wick[1])}" width="{f(w * 0.14)}" height="{f(yb1 - wick[1] - h * 0.02)}" rx="{f(w * 0.02)}" fill="#FFF8E7"/>')
    # pierced gold frame: bars, bands and a pointed arch on the centre panel
    for x in (-0.45, -0.25, 0.25, 0.45):
        out.append(f'<rect x="{f(cx + w * x - h * 0.009)}" y="{f(yb0)}" width="{f(h * 0.018)}" height="{f(yb1 - yb0)}" fill="{gold}"/>')
    for y in (yb0, yb1 - h * 0.025):
        out.append(f'<rect x="{f(cx - w * 0.47)}" y="{f(y)}" width="{f(w * 0.94)}" height="{f(h * 0.025)}" fill="{gold}"/>')
    ay = yb0 + h * 0.07
    out.append(f'<path d="M {f(cx - w * 0.17)},{f(yb1 - h * 0.03)} L {f(cx - w * 0.17)},{f(ay + h * 0.12)} C {f(cx - w * 0.17)},{f(ay + h * 0.04)} {f(cx - w * 0.04)},{f(ay + h * 0.03)} {f(cx)},{f(ay)} '
               f'C {f(cx + w * 0.04)},{f(ay + h * 0.03)} {f(cx + w * 0.17)},{f(ay + h * 0.04)} {f(cx + w * 0.17)},{f(ay + h * 0.12)} L {f(cx + w * 0.17)},{f(yb1 - h * 0.03)}" '
               f'fill="none" stroke="#C98A12" stroke-width="{f(h * 0.012)}"/>')
    for k in range(4):
        out.append(f'<circle cx="{f(cx + w * 0.35)}" cy="{f(yb0 + h * (0.08 + k * 0.11))}" r="{f(h * 0.01)}" fill="#FFE7A0" opacity="0.8"/>'
                   f'<circle cx="{f(cx - w * 0.35)}" cy="{f(yb0 + h * (0.08 + k * 0.11))}" r="{f(h * 0.01)}" fill="#FFE7A0" opacity="0.8"/>')
    out.append(f'<path d="M {f(cx - w * 0.46)},{f(yb1)} L {f(cx + w * 0.46)},{f(yb1)} L {f(cx + w * 0.26)},{f(top + h * 0.92)} L {f(cx - w * 0.26)},{f(top + h * 0.92)} Z" fill="{gold}"/>')
    out.append(f'<rect x="{f(cx - w * 0.32)}" y="{f(top + h * 0.92)}" width="{f(w * 0.64)}" height="{f(h * 0.05)}" rx="{f(h * 0.015)}" fill="{gold}"/>')
    out.append(f'<path d="M {f(cx - w * 0.36)},{f(yb0 + h * 0.02)} L {f(cx - w * 0.36)},{f(yb1 - h * 0.04)}" stroke="#FFFFFF" stroke-opacity="0.35" stroke-width="{f(h * 0.02)}"/>')
    return ''.join(out), wick


def date_fruit(s, cx, cy, size, a):
    """A glossy khajoor date."""
    g = s.rad([(0, '#B5653A'), (0.55, '#7A3418'), (1, '#3E140A')], cx=0.38, cy=0.32, r=0.75)
    rx, ry = size, size * 0.56
    return (f'<g transform="translate({f(cx)} {f(cy)}) rotate({f(a)})">'
            f'<ellipse cx="{f(size * 0.08)}" cy="{f(size * 0.14)}" rx="{f(rx)}" ry="{f(ry)}" fill="#1A0500" opacity="0.35" filter="{s.blur(size * 0.12)}"/>'
            f'<ellipse rx="{f(rx)}" ry="{f(ry)}" fill="{g}"/>'
            f'<path d="M {f(-rx * 0.6)},{f(-ry * 0.1)} Q 0,{f(ry * 0.25)} {f(rx * 0.55)},{f(-ry * 0.2)}" stroke="#2A0A04" stroke-opacity="0.5" stroke-width="{f(size * 0.06)}" fill="none"/>'
            f'<path d="M {f(-rx * 0.4)},{f(ry * 0.35)} Q {f(rx * 0.1)},{f(ry * 0.5)} {f(rx * 0.5)},{f(ry * 0.25)}" stroke="#2A0A04" stroke-opacity="0.35" stroke-width="{f(size * 0.05)}" fill="none"/>'
            f'<ellipse cx="{f(-rx * 0.35)}" cy="{f(-ry * 0.42)}" rx="{f(rx * 0.35)}" ry="{f(ry * 0.18)}" fill="#FFFFFF" opacity="0.4"/>'
            f'</g>')


def dates_bowl(s, cx, cy, rx):
    """A brass bowl heaped with dates."""
    ry = rx * 0.3
    gold = s.lin([(0, '#7A4E00'), (0.3, '#C98A12'), (0.5, '#FFE7A0'), (0.75, '#C98A12'), (1, '#6B4300')], x1=0, y1=0, x2=1, y2=0)
    out = [f'<ellipse cx="{f(cx)}" cy="{f(cy + ry * 2.3)}" rx="{f(rx * 0.95)}" ry="{f(ry * 0.5)}" fill="#0A0418" opacity="0.4" filter="{s.blur(rx * 0.06)}"/>']
    rnd = s.rnd
    heap = []
    for _ in range(int(rx * 0.32)):
        x = cx + rnd.uniform(-rx * 0.85, rx * 0.85)
        dome = 1 - ((x - cx) / rx) ** 2
        y = cy - rnd.uniform(0, rx * 0.42) * max(0.2, dome)
        heap.append((y, x))
    heap.sort()
    out.append(''.join(date_fruit(s, x, y, rx * 0.17, rnd.uniform(-50, 50)) for y, x in heap))
    out.append(f'<path d="M {f(cx - rx)},{f(cy)} Q {f(cx - rx * 0.95)},{f(cy + ry * 2.2)} {f(cx)},{f(cy + ry * 2.25)} Q {f(cx + rx * 0.95)},{f(cy + ry * 2.2)} {f(cx + rx)},{f(cy)} Z" fill="{gold}"/>')
    out.append(f'<path d="M {f(cx - rx)},{f(cy)} Q {f(cx)},{f(cy + ry * 0.7)} {f(cx + rx)},{f(cy)}" stroke="#FFE7A0" stroke-width="{f(rx * 0.04)}" fill="none"/>')
    for i in range(-4, 5):
        out.append(f'<circle cx="{f(cx + i * rx * 0.2)}" cy="{f(cy + ry * 1.25 - (16 - i * i) * ry * 0.01)}" r="{f(rx * 0.022)}" fill="#7A4E00" opacity="0.6"/>')
    return ''.join(out)


def rose_milk(s, x, base_y, h):
    """A tall glass of rose milk with a straw."""
    w = h * 0.42
    glass = f'M {f(x - w / 2)},{f(base_y - h)} L {f(x - w * 0.4)},{f(base_y)} L {f(x + w * 0.4)},{f(base_y)} L {f(x + w / 2)},{f(base_y - h)} Z'
    milk = f'M {f(x - w * 0.47)},{f(base_y - h * 0.82)} L {f(x - w * 0.4)},{f(base_y - 2)} L {f(x + w * 0.4)},{f(base_y - 2)} L {f(x + w * 0.47)},{f(base_y - h * 0.82)} Z'
    return (f'<ellipse cx="{f(x)}" cy="{f(base_y + 2)}" rx="{f(w * 0.55)}" ry="{f(h * 0.05)}" fill="#0A0418" opacity="0.35" filter="{s.blur(3)}"/>'
            f'<path d="M {f(x + w * 0.12)},{f(base_y - h * 0.7)} L {f(x + w * 0.34)},{f(base_y - h * 1.25)}" stroke="#E53950" stroke-width="{f(w * 0.08)}" stroke-linecap="round"/>'
            f'<path d="{milk}" fill="{s.lin([(0, "#FFD3E2"), (1, "#F06292")], x1=0, y1=0, x2=0, y2=1)}"/>'
            f'<path d="{glass}" fill="#FFFFFF" fill-opacity="0.18" stroke="#FFFFFF" stroke-opacity="0.75" stroke-width="{f(max(1, h * 0.02))}"/>'
            f'<path d="M {f(x - w * 0.32)},{f(base_y - h * 0.92)} L {f(x - w * 0.27)},{f(base_y - h * 0.12)}" stroke="#FFFFFF" stroke-opacity="0.7" stroke-width="{f(w * 0.07)}" stroke-linecap="round"/>'
            f'<ellipse cx="{f(x)}" cy="{f(base_y - h * 0.82)}" rx="{f(w * 0.47)}" ry="{f(h * 0.04)}" fill="#FFE4EE"/>')


def night(s, W_, H_, glow=None):
    s.add(f'<rect width="{W_}" height="{H_}" fill="{s.lin([(0, "#14072A"), (0.4, "#26103F"), (0.78, "#3C1A62"), (1, "#4A2378")])}"/>')
    if glow:
        gx, gy, gr = glow
        s.add(f'<rect width="{W_}" height="{H_}" fill="{s.rad([(0, "#FFC14D", 0.26), (0.5, "#C77DFF", 0.1), (1, "#C77DFF", 0)], cx=gx, cy=gy, r=gr, units="userSpaceOnUse")}"/>')


def stars(s, x0, x1, y0, y1, n):
    rnd = s.rnd
    out = []
    for _ in range(n):
        x, y = rnd.uniform(x0, x1), rnd.uniform(y0, y1)
        r = rnd.uniform(1.2, 2.8)
        out.append(f'<circle cx="{f(x)}" cy="{f(y)}" r="{f(r)}" fill="#FFF8E1" opacity="{f(rnd.uniform(0.35, 0.9))}"/>')
    return ''.join(out)


def skyline(s, y, W_, colour='#12062A', windows=True):
    """Domes and minarets against the night (a soft silhouette)."""
    out = [f'<rect x="0" y="{f(y)}" width="{W_}" height="400" fill="{colour}"/>']
    def dome(cx, base, r, h):
        return (f'<path d="M {f(cx - r)},{f(base)} C {f(cx - r * 1.08)},{f(base - h * 0.55)} {f(cx - r * 0.3)},{f(base - h * 0.8)} {f(cx)},{f(base - h)} '
                f'C {f(cx + r * 0.3)},{f(base - h * 0.8)} {f(cx + r * 1.08)},{f(base - h * 0.55)} {f(cx + r)},{f(base)} Z" fill="{colour}"/>'
                f'<line x1="{f(cx)}" y1="{f(base - h)}" x2="{f(cx)}" y2="{f(base - h - r * 0.35)}" stroke="{colour}" stroke-width="{f(r * 0.06)}"/>')
    def minaret(cx, base, w, h):
        return (f'<rect x="{f(cx - w / 2)}" y="{f(base - h)}" width="{f(w)}" height="{f(h)}" fill="{colour}"/>'
                f'<rect x="{f(cx - w * 0.8)}" y="{f(base - h * 0.72)}" width="{f(w * 1.6)}" height="{f(w * 0.35)}" fill="{colour}"/>'
                f'<rect x="{f(cx - w * 0.8)}" y="{f(base - h * 0.42)}" width="{f(w * 1.6)}" height="{f(w * 0.3)}" fill="{colour}"/>'
                + dome(cx, base - h, w * 0.75, w * 1.3))
    for cx, w, h in [(W_ * 0.12, 26, 300), (W_ * 0.88, 26, 300), (W_ * 0.3, 20, 210), (W_ * 0.7, 20, 210)]:
        out.append(minaret(cx, y, w, h))
    out.append(f'<rect x="{f(W_ * 0.26)}" y="{f(y - 120)}" width="{f(W_ * 0.48)}" height="130" fill="{colour}"/>')
    out.append(dome(W_ * 0.5, y - 118, W_ * 0.14, W_ * 0.17))
    out.append(dome(W_ * 0.34, y - 118, W_ * 0.06, W_ * 0.08))
    out.append(dome(W_ * 0.66, y - 118, W_ * 0.06, W_ * 0.08))
    if windows:
        for i in range(-4, 5):
            wx = W_ * 0.5 + i * W_ * 0.045
            out.append(f'<path d="M {f(wx - 8)},{f(y - 20)} L {f(wx - 8)},{f(y - 70)} Q {f(wx)},{f(y - 86)} {f(wx + 8)},{f(y - 70)} L {f(wx + 8)},{f(y - 20)} Z" fill="#FFD27A" opacity="0.55"/>')
    return ''.join(out)


# ───────────────────────── pack assets ─────────────────────────

HERO_W, HERO_H = 480, 300


def hero():
    """A standing lantern and a smaller one, a bowl of dates and a glass of rose milk on a star rug."""
    s = SVG(HERO_W, HERO_H, seed=29)
    s.add(f'<ellipse cx="250" cy="288" rx="232" ry="12" fill="#FFFFFF" opacity="0.10" filter="{s.blur(6)}"/>')
    s.add(f'<g transform="translate(260 278) scale(1 0.24)">{rosette(s, 0, 0, 200, color="#FFE082", opacity=0.85, stroke=6)}</g>')
    big, wick1 = lantern(s, 176, 40, 246, 'amber')
    small, wick2 = lantern(s, 420, 128, 158, 'teal')
    s.add(big)
    s.add(small)
    s.add(dates_bowl(s, 300, 238, 66))
    s.add(rose_milk(s, 64, 284, 92))
    s.add(gold_crescent(s, 82, 70, 26, rot=-24))
    s.add(star5(s, 116, 52, 9))
    s.save(f'{OUT}/hero.svg')
    flames = []
    for (x, y), h in ((wick1, 246), (wick2, 158)):
        size = h * 0.46 * 0.16 / 0.215   # flame body ≈ 16 % of the lantern's width
        flames.append((round(x / HERO_W, 4), round(y / HERO_H, 4), round(size / HERO_W, 4)))
    return flames


def header_bg():
    s = SVG(1170, 1050, seed=31)
    night(s, 1170, 1050, glow=(960, 700, 560))
    s.add(star_field(s, 30, 40, 1170, 1050, 150, 30, opacity=0.06))
    s.add(rosette(s, 1090, 470, 300, opacity=0.1))
    s.add(stars(s, 0, 1170, 0, 1000, 70))
    s.add(gold_crescent(s, 985, 445, 46, rot=-28))
    s.add(star5(s, 1046, 410, 14))
    rnd = s.rnd
    for _ in range(14):
        s.add(bokeh(s, rnd.uniform(420, 1170), rnd.uniform(150, 990), rnd.uniform(14, 48), rnd.choice(['#FFD54F', '#C77DFF', '#FFF59D']), rnd.uniform(0.08, 0.2)))
    for _ in range(12):
        s.add(sparkle(s, rnd.uniform(420, 1160), rnd.uniform(150, 1000), rnd.uniform(3.5, 10), opacity=rnd.uniform(0.3, 0.8)))
    s.save(f'{OUT}/header_bg.svg')


SWAGS = [(-40, 392, 44), (392, 774, 36), (774, 1210, 42)]
ANCHOR_Y = 6


def _rope(x0, x1, sag, t):
    cx, cy = (x0 + x1) / 2, ANCHOR_Y + 2 * sag
    x = (1 - t) ** 2 * x0 + 2 * (1 - t) * t * cx + t * t * x1
    y = (1 - t) ** 2 * ANCHOR_Y + 2 * (1 - t) * t * cy + t * t * ANCHOR_Y
    return x, y


def thoranam():
    """Gold chains in swags, little glowing lanterns, stars and crescents hanging on threads."""
    s = SVG(1170, 132, seed=37)
    rnd = s.rnd
    chains, threads, charms = [], [], []
    for k, (x0, x1, sag) in enumerate(SWAGS):
        n = int(abs(x1 - x0) / 9)
        for i in range(n + 1):
            x, y = _rope(x0, x1, sag, i / n)
            chains.append(f'<circle cx="{f(x)}" cy="{f(y)}" r="2.6" fill="{["#FFE7A0", "#E0A82E"][i % 2]}"/>')
        m = 6
        for i in range(m):
            t = (i + 0.5) / m
            x, y = _rope(x0, x1, sag, t)
            kind = (i + k) % 3
            drop = rnd.uniform(16, 30)
            threads.append(f'<line x1="{f(x)}" y1="{f(y)}" x2="{f(x)}" y2="{f(y + drop)}" stroke="#E0A82E" stroke-width="1.2"/>')
            if kind == 0:
                svg, _ = lantern(s, x, y + drop - 2, 44, rnd.choice(['amber', 'ruby', 'teal', 'violet']))
                charms.append(svg)
                charms.append(f'<circle cx="{f(x)}" cy="{f(y + drop + 22)}" r="3.2" fill="#FFF3C4" opacity="0.9"/>')
            elif kind == 1:
                charms.append(star5(s, x, y + drop + 9, 10))
            else:
                charms.append(gold_crescent(s, x, y + drop + 10, 10, rot=-30))
    for ax in (392, 774):
        svg, _ = lantern(s, ax, ANCHOR_Y + 8, 58, 'ruby' if ax == 392 else 'teal')
        charms.append(svg)
        charms.append(f'<circle cx="{ax}" cy="{ANCHOR_Y + 37}" r="4" fill="#FFF3C4" opacity="0.95"/>')
    s.add(''.join(threads) + ''.join(chains) + ''.join(charms))
    s.save(f'{OUT}/thoranam.svg')


def splash_bg():
    W_, H_ = 1170, 2532
    s = SVG(W_, H_, seed=41)
    night(s, W_, H_, glow=(585, 1060, 700))
    s.add(star_field(s, 30, 220, W_, H_ - 300, 160, 32, opacity=0.06))
    s.add(stars(s, 0, W_, 160, H_ - 400, 160))
    s.add(rosette(s, 140, 330, 150, opacity=0.1))
    s.add(rosette(s, 1030, 330, 150, opacity=0.1))
    rnd = s.rnd
    for _ in range(20):
        s.add(bokeh(s, rnd.uniform(0, W_), rnd.uniform(200, H_ - 400), rnd.uniform(18, 56), rnd.choice(['#FFD54F', '#C77DFF', '#FFF59D']), rnd.uniform(0.08, 0.18)))
    s.add(f'<rect x="0" y="{H_ - 700}" width="{W_}" height="700" fill="{s.lin([(0, "#2A0F4A", 0), (1, "#1A0833", 0.9)])}"/>')
    s.add(skyline(s, H_ - 90, W_))
    s.save(f'{OUT}/splash_bg.svg')


def crescent_halo():
    """A golden crescent and star with soft rays, rising behind the splash logo (600 × 600)."""
    s = SVG(600, 600, seed=47)
    s.add(f'<circle cx="300" cy="300" r="250" fill="#FFD54F" opacity="0.18" filter="{s.blur(70)}"/>')
    for i in range(24):
        a = -180 + i * (180 / 23)
        r0, r1 = 160, (292 if i % 2 else 240)
        p1 = (300 + math.cos(math.radians(a - 1.5)) * r0, 300 + math.sin(math.radians(a - 1.5)) * r0)
        p2 = (300 + math.cos(math.radians(a)) * r1, 300 + math.sin(math.radians(a)) * r1)
        p3 = (300 + math.cos(math.radians(a + 1.5)) * r0, 300 + math.sin(math.radians(a + 1.5)) * r0)
        s.add(f'<polygon points="{_pts([p1, p2, p3])}" fill="#FFE082" opacity="{0.32 if i % 2 else 0.2}"/>')
    s.add(gold_crescent(s, 270, 238, 150, rot=-20))
    s.add(star5(s, 418, 150, 40, rot=-80))
    s.save(f'{OUT}/crescent.svg')


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
    crescent_halo()
    json.dump({'flames': flames, 'heroAspect': f'{HERO_W} / {HERO_H}'}, open(f'{OUT}/hero.json', 'w'), indent=1)
    print('flames', flames)
