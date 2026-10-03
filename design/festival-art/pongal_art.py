"""Pongal pack: Surya Pongal sunrise, white kolam, purple sugarcane, a clay pongal pot boiling over
on a firewood hearth, and a thoranam of aavaram poo, poolai poo and mango leaves.

Writes SVGs to out/pongal/ (same file names as the Deepavali pack); render with
  node render.mjs --dir out/pongal
"""
import json
import math
import os

from svgkit import *
from header_art import bell
from banners import cashew, _petal

OUT = 'out/pongal'
os.makedirs(OUT, exist_ok=True)


# ───────────────────────── motifs ─────────────────────────

def sun(s, cx, cy, r, rays=True):
    out = [f'<circle cx="{f(cx)}" cy="{f(cy)}" r="{f(r * 2.1)}" fill="#FFB300" opacity="0.18" filter="{s.blur(r * 0.6)}"/>',
           f'<circle cx="{f(cx)}" cy="{f(cy)}" r="{f(r * 1.45)}" fill="#FFCA28" opacity="0.30" filter="{s.blur(r * 0.35)}"/>']
    if rays:
        for i in range(24):
            a = math.radians(i * 15)
            long = i % 2 == 0
            r1, r2, w = r * 1.12, r * (1.75 if long else 1.45), (0.07 if long else 0.05)
            p1 = (cx + math.cos(a - w) * r1, cy + math.sin(a - w) * r1)
            p2 = (cx + math.cos(a) * r2, cy + math.sin(a) * r2)
            p3 = (cx + math.cos(a + w) * r1, cy + math.sin(a + w) * r1)
            out.append(f'<polygon points="{f(p1[0])},{f(p1[1])} {f(p2[0])},{f(p2[1])} {f(p3[0])},{f(p3[1])}" fill="#FFD54F" opacity="{0.55 if long else 0.38}"/>')
    g = s.rad([(0, '#FFFDE7'), (0.45, '#FFE082'), (0.8, '#FFC107'), (1, '#FFA000')], cx=0.42, cy=0.4, r=0.65)
    out.append(f'<circle cx="{f(cx)}" cy="{f(cy)}" r="{f(r)}" fill="{g}"/>')
    return ''.join(out)


def kolam(s, cx, cy, R, color='#FFFFFF', opacity=0.2, stroke=2.4, rings=3):
    """Pulli kolam: a diamond of dots with loops woven round them, petals around it."""
    out = [f'<g opacity="{f(opacity)}" fill="none" stroke="{color}" stroke-width="{f(stroke)}" stroke-linecap="round">']
    step = R / (rings + 2.2)
    for i in range(-rings, rings + 1):
        for j in range(-rings, rings + 1):
            if abs(i) + abs(j) > rings:
                continue
            x, y = cx + (i - j) * step * 0.72, cy + (i + j) * step * 0.72
            out.append(f'<circle cx="{f(x)}" cy="{f(y)}" r="{f(stroke * 1.1)}" fill="{color}" stroke="none"/>')
            if (i + j) % 2 == 0:   # loop around every other dot
                out.append(f'<path d="M {f(x - step * 0.5)},{f(y)} Q {f(x)},{f(y - step * 0.62)} {f(x + step * 0.5)},{f(y)} Q {f(x)},{f(y + step * 0.62)} {f(x - step * 0.5)},{f(y)} Z"/>')
    # petals round the dot diamond
    for k, (rr, n) in enumerate([(R * 0.78, 8), (R * 1.0, 16)]):
        for i in range(n):
            a = math.radians(i * 360 / n + (11.25 if k else 0))
            x1, y1 = cx + math.cos(a) * rr * 0.82, cy + math.sin(a) * rr * 0.82
            x2, y2 = cx + math.cos(a) * rr * 1.1, cy + math.sin(a) * rr * 1.1
            a1, a2 = a - math.pi / n * 0.8, a + math.pi / n * 0.8
            c1 = (cx + math.cos(a1) * rr, cy + math.sin(a1) * rr)
            c2 = (cx + math.cos(a2) * rr, cy + math.sin(a2) * rr)
            out.append(f'<path d="M {f(x1)},{f(y1)} Q {f(c1[0])},{f(c1[1])} {f(x2)},{f(y2)} Q {f(c2[0])},{f(c2[1])} {f(x1)},{f(y1)} Z"/>')
            out.append(f'<circle cx="{f(cx + math.cos(a) * rr * 1.2)}" cy="{f(cy + math.sin(a) * rr * 1.2)}" r="{f(stroke * 1.1)}" fill="{color}" stroke="none"/>')
    out.append(f'<circle cx="{f(cx)}" cy="{f(cy)}" r="{f(R * 1.32)}" stroke-dasharray="1 {f(stroke * 4)}"/>')
    out.append('</g>')
    return ''.join(out)


def sugarcane(s, x, y, length, angle, width=24, leaves=True, leaf_scale=1.0):
    """Purple karumbu stalk from its foot at (x, y), leaning by angle (degrees, 0 = straight up)."""
    g = s.lin([(0, '#3E1430'), (0.35, '#7B2D5C'), (0.6, '#9C4374'), (1, '#4A1838')], x1=0, y1=0, x2=1, y2=0)
    w = width
    out = [f'<g transform="translate({f(x)} {f(y)}) rotate({f(angle)})">',
           f'<rect x="{f(-w / 2 + 4)}" y="{f(-length + 6)}" width="{f(w)}" height="{f(length)}" rx="{f(w / 2)}" fill="#1A0A10" opacity="0.30" filter="{s.blur(4)}"/>',
           f'<rect x="{f(-w / 2)}" y="{f(-length)}" width="{f(w)}" height="{f(length)}" rx="{f(w / 2)}" fill="{g}"/>']
    seg = w * 2.6
    yy = -seg
    while yy > -length + seg * 0.6:
        out.append(f'<path d="M {f(-w / 2)},{f(yy)} Q 0,{f(yy + w * 0.18)} {f(w / 2)},{f(yy)}" stroke="#2A0B1F" stroke-width="{f(w * 0.12)}" fill="none"/>')
        out.append(f'<path d="M {f(-w / 2 + 2)},{f(yy - w * 0.12)} Q 0,{f(yy + w * 0.04)} {f(w / 2 - 2)},{f(yy - w * 0.12)}" stroke="#D9A6C2" stroke-opacity="0.55" stroke-width="{f(w * 0.07)}" fill="none"/>')
        yy -= seg
    out.append(f'<rect x="{f(-w * 0.28)}" y="{f(-length + 6)}" width="{f(w * 0.12)}" height="{f(length - 12)}" rx="{f(w * 0.06)}" fill="#FFFFFF" opacity="0.18"/>')
    if leaves:
        top = -length
        for k, (lean, ln) in enumerate([(-38, 1.35), (-12, 1.6), (16, 1.5), (40, 1.2), (-60, 0.9), (62, 0.85)]):
            L = w * 6 * ln * leaf_scale
            a = math.radians(lean)
            ex, ey = math.sin(a) * L, top - math.cos(a) * L * 0.75
            cx_, cy_ = math.sin(a) * L * 0.35, top - L * 0.55
            gl = s.lin([(0, '#2E7D32'), (1, '#8BC34A')], x1=0, y1=1, x2=0, y2=0)
            out.append(f'<path d="M {f(-w * 0.12)},{f(top + 6)} Q {f(cx_ - w * 0.4)},{f(cy_)} {f(ex)},{f(ey)} Q {f(cx_ + w * 0.4)},{f(cy_ + w * 0.3)} {f(w * 0.12)},{f(top + 6)} Z" fill="{gl}" opacity="0.95"/>')
            out.append(f'<path d="M 0,{f(top + 4)} Q {f(cx_)},{f(cy_ + w * 0.15)} {f(ex)},{f(ey)}" stroke="#C5E1A5" stroke-opacity="0.6" stroke-width="1.4" fill="none"/>')
    out.append('</g>')
    return ''.join(out)


def aavaram(s, cx, cy, r, rot=0):
    """Aavaram poo (Senna auriculata): five bright yellow petals."""
    g = s.rad([(0, '#FFF59D'), (0.6, '#FFD600'), (1, '#F9A825')], cx=0.5, cy=0.5, r=0.6)
    out = [f'<circle cx="{f(cx + r * 0.06)}" cy="{f(cy + r * 0.16)}" r="{f(r * 0.95)}" fill="#3B2A00" opacity="0.28" filter="{s.blur(r * 0.14)}"/>']
    for i in range(5):
        a = rot + i * 72
        ar = math.radians(a)
        px, py = cx + math.cos(ar) * r * 0.48, cy + math.sin(ar) * r * 0.48
        out.append(f'<ellipse cx="{f(px)}" cy="{f(py)}" rx="{f(r * 0.5)}" ry="{f(r * 0.38)}" transform="rotate({f(a)} {f(px)} {f(py)})" fill="{g}" stroke="#E6A100" stroke-opacity="0.5" stroke-width="{f(max(0.6, r * 0.04))}"/>')
    out.append(f'<circle cx="{f(cx)}" cy="{f(cy)}" r="{f(r * 0.2)}" fill="#E65100"/>')
    for i in range(5):
        ar = math.radians(rot + 36 + i * 72)
        out.append(f'<circle cx="{f(cx + math.cos(ar) * r * 0.24)}" cy="{f(cy + math.sin(ar) * r * 0.24)}" r="{f(r * 0.05)}" fill="#8D4A00"/>')
    return ''.join(out)


def poolai(s, cx, cy, r):
    """Poolai poo: a white woolly tuft."""
    rnd = s.rnd
    out = [f'<circle cx="{f(cx + r * 0.08)}" cy="{f(cy + r * 0.15)}" r="{f(r)}" fill="#2B2B2B" opacity="0.22" filter="{s.blur(r * 0.15)}"/>']
    for _ in range(int(14 + r)):
        a = rnd.uniform(0, math.tau); d = rnd.uniform(0, r * 0.75)
        out.append(f'<circle cx="{f(cx + math.cos(a) * d)}" cy="{f(cy + math.sin(a) * d)}" r="{f(r * rnd.uniform(0.22, 0.34))}" fill="{rnd.choice(["#FFFFFF", "#F5F5F0", "#ECEBE4"])}"/>')
    return ''.join(out)


def neem_sprig(s, x, y, length, angle):
    out = [f'<g transform="translate({f(x)} {f(y)}) rotate({f(angle)})">',
           f'<line x1="0" y1="0" x2="0" y2="{f(length)}" stroke="#5D7A2A" stroke-width="2"/>']
    for k in range(6):
        t = (k + 1) / 7
        for sgn in (-1, 1):
            lx, ly = sgn * length * 0.16, length * t + length * 0.04
            out.append(f'<ellipse cx="{f(lx)}" cy="{f(ly)}" rx="{f(length * 0.13)}" ry="{f(length * 0.045)}" transform="rotate({f(sgn * 32)} {f(lx)} {f(ly)})" fill="#558B2F"/>')
    out.append(f'<ellipse cx="0" cy="{f(length * 1.05)}" rx="{f(length * 0.05)}" ry="{f(length * 0.12)}" fill="#689F38"/>')
    out.append('</g>')
    return ''.join(out)


def pot(s, cx, base_y, w, foam=True, leaf_scale=1.0):
    """Clay pongal paanai with a painted kolam band, a turmeric plant tied at the neck, rice boiling over."""
    h = w * 0.88
    top = base_y - h
    body = (f'M {f(cx - w * 0.22)},{f(top + h * 0.12)} C {f(cx - w * 0.62)},{f(top + h * 0.22)} {f(cx - w * 0.6)},{f(base_y - h * 0.08)} {f(cx - w * 0.2)},{f(base_y)} '
            f'L {f(cx + w * 0.2)},{f(base_y)} C {f(cx + w * 0.6)},{f(base_y - h * 0.08)} {f(cx + w * 0.62)},{f(top + h * 0.22)} {f(cx + w * 0.22)},{f(top + h * 0.12)} Z')
    g = s.lin([(0, '#F09A55'), (0.4, '#D2692D'), (0.75, '#A8461C'), (1, '#6E2A10')], x1=0, y1=0, x2=1, y2=0.4)
    clip = s.clip(f'<path d="{body}"/>')
    band_y = top + h * 0.48
    deco = [f'<rect x="{f(cx - w)}" y="{f(band_y - h * 0.09)}" width="{f(w * 2)}" height="{f(h * 0.18)}" fill="#F4E9D8"/>',
            f'<rect x="{f(cx - w)}" y="{f(band_y - h * 0.11)}" width="{f(w * 2)}" height="{f(h * 0.022)}" fill="#C62828"/>',
            f'<rect x="{f(cx - w)}" y="{f(band_y + h * 0.09)}" width="{f(w * 2)}" height="{f(h * 0.022)}" fill="#C62828"/>']
    for i in range(-6, 7):
        x = cx + i * w * 0.11
        deco.append(f'<path d="M {f(x - w * 0.045)},{f(band_y)} Q {f(x)},{f(band_y - h * 0.07)} {f(x + w * 0.045)},{f(band_y)} Q {f(x)},{f(band_y + h * 0.07)} {f(x - w * 0.045)},{f(band_y)} Z" fill="none" stroke="#C62828" stroke-width="{f(w * 0.012)}"/>')
        deco.append(f'<circle cx="{f(x + w * 0.055)}" cy="{f(band_y)}" r="{f(w * 0.011)}" fill="#F9A825"/>')
    for i in range(-5, 6):
        deco.append(f'<circle cx="{f(cx + i * w * 0.12)}" cy="{f(top + h * 0.78)}" r="{f(w * 0.014)}" fill="#FFF3E0" opacity="0.9"/>')
    out = [f'<ellipse cx="{f(cx)}" cy="{f(base_y + h * 0.02)}" rx="{f(w * 0.46)}" ry="{f(h * 0.06)}" fill="#1A0800" opacity="0.4" filter="{s.blur(h * 0.03)}"/>',
           f'<path d="{body}" fill="{g}"/>',
           f'<g clip-path="{clip}">{"".join(deco)}<ellipse cx="{f(cx - w * 0.28)}" cy="{f(top + h * 0.45)}" rx="{f(w * 0.07)}" ry="{f(h * 0.28)}" fill="#FFFFFF" opacity="0.18" filter="{s.blur(w * 0.02)}"/></g>']
    # neck + rim
    out.append(f'<path d="M {f(cx - w * 0.24)},{f(top + h * 0.13)} L {f(cx - w * 0.2)},{f(top + h * 0.02)} L {f(cx + w * 0.2)},{f(top + h * 0.02)} L {f(cx + w * 0.24)},{f(top + h * 0.13)} Z" fill="#B65424"/>')
    out.append(f'<ellipse cx="{f(cx)}" cy="{f(top + h * 0.02)}" rx="{f(w * 0.25)}" ry="{f(h * 0.045)}" fill="#E0844A" stroke="#8A3414" stroke-width="{f(w * 0.01)}"/>')
    # turmeric plant tied round the neck: leaves fanning up and out, the yellow rhizome knotted in front
    for k, (lean, ln) in enumerate([(-58, 0.62), (-32, 0.78), (-8, 0.82), (24, 0.74), (52, 0.6)]):
        L = w * ln * leaf_scale
        a = math.radians(lean)
        sx, sy = cx - w * 0.16 + k * w * 0.08, top + h * 0.1
        ex, ey = sx + math.sin(a) * L, sy - math.cos(a) * L
        gl = s.lin([(0, '#33691E'), (1, '#7CB342')], x1=0, y1=1, x2=0, y2=0)
        out.append(f'<path d="M {f(sx - w * 0.03)},{f(sy)} Q {f((sx + ex) / 2 - w * 0.09)},{f((sy + ey) / 2)} {f(ex)},{f(ey)} Q {f((sx + ex) / 2 + w * 0.09)},{f((sy + ey) / 2 + w * 0.02)} {f(sx + w * 0.03)},{f(sy)} Z" fill="{gl}"/>')
        out.append(f'<path d="M {f(sx)},{f(sy)} L {f(ex)},{f(ey)}" stroke="#C5E1A5" stroke-opacity="0.55" stroke-width="1.3"/>')
    out.append(f'<path d="M {f(cx - w * 0.25)},{f(top + h * 0.12)} Q {f(cx)},{f(top + h * 0.2)} {f(cx + w * 0.25)},{f(top + h * 0.12)}" stroke="#F9A825" stroke-width="{f(w * 0.025)}" fill="none"/>')
    for i, dx in enumerate((-0.06, 0.0, 0.07)):
        out.append(f'<ellipse cx="{f(cx + dx * w)}" cy="{f(top + h * (0.19 + i * 0.012))}" rx="{f(w * 0.05)}" ry="{f(w * 0.028)}" transform="rotate({f(-20 + i * 25)} {f(cx + dx * w)} {f(top + h * 0.19)})" fill="#FBC02D" stroke="#B26A00" stroke-width="1"/>')
    if foam:
        out.append(rice_foam(s, cx, top + h * 0.02, w))
    return ''.join(out)


def rice_foam(s, cx, rim_y, w):
    """Pongal boiling over: white foam bubbles heaped over the rim and dripping down one side."""
    rnd = s.rnd
    blobs = []
    for _ in range(26):
        x = cx + rnd.uniform(-w * 0.27, w * 0.27)
        y = rim_y - rnd.uniform(-w * 0.02, w * 0.11) * (1 - abs(x - cx) / (w * 0.32))
        blobs.append((x, y, w * rnd.uniform(0.045, 0.085)))
    for k in range(5):   # drips over the right side
        blobs.append((cx + w * (0.22 + k * 0.012), rim_y + w * (0.03 + k * 0.045), w * (0.05 - k * 0.006)))
    for k in range(3):
        blobs.append((cx - w * (0.23 + k * 0.01), rim_y + w * (0.03 + k * 0.04), w * (0.045 - k * 0.008)))
    out = [f'<g filter="{s.blur(0.6)}">']
    for x, y, r in blobs:
        out.append(f'<circle cx="{f(x + 1.5)}" cy="{f(y + 2.5)}" r="{f(r)}" fill="#BDB7A8"/>')
    for x, y, r in blobs:
        out.append(f'<circle cx="{f(x)}" cy="{f(y)}" r="{f(r)}" fill="#FFFDF7"/>')
    for x, y, r in blobs[::3]:
        out.append(f'<circle cx="{f(x - r * 0.3)}" cy="{f(y - r * 0.35)}" r="{f(r * 0.35)}" fill="#FFFFFF"/>')
    # a few rice grains in the foam
    for _ in range(18):
        x = cx + rnd.uniform(-w * 0.24, w * 0.24); y = rim_y - rnd.uniform(0, w * 0.08)
        out.append(f'<ellipse cx="{f(x)}" cy="{f(y)}" rx="{f(w * 0.012)}" ry="{f(w * 0.006)}" transform="rotate({f(rnd.uniform(0, 180))} {f(x)} {f(y)})" fill="#E8E2D2"/>')
    out.append('</g>')
    return ''.join(out)


def hearth(s, cx, y, w):
    """Three-stone aduppu with firewood; the flames are drawn by the app (they flicker)."""
    out = []
    for dx in (-0.36, 0.36):
        out.append(f'<ellipse cx="{f(cx + dx * w + 3)}" cy="{f(y + 6)}" rx="{f(w * 0.17)}" ry="{f(w * 0.1)}" fill="#1A1008" opacity="0.4" filter="{s.blur(5)}"/>')
    for (dx, a, ln) in [(-0.3, -18, 0.62), (0.28, 16, 0.6), (-0.05, -4, 0.66)]:
        x1, y1 = cx + dx * w - math.cos(math.radians(a)) * w * ln * 0.5, y - w * 0.03
        x2, y2 = cx + dx * w + math.cos(math.radians(a)) * w * ln * 0.5, y - w * 0.03 + math.sin(math.radians(a)) * w * 0.1
        out.append(f'<line x1="{f(x1)}" y1="{f(y1)}" x2="{f(x2)}" y2="{f(y2)}" stroke="#5D3A1A" stroke-width="{f(w * 0.06)}" stroke-linecap="round"/>')
        out.append(f'<line x1="{f(x1)}" y1="{f(y1 - w * 0.012)}" x2="{f(x2)}" y2="{f(y2 - w * 0.012)}" stroke="#8D6E4C" stroke-width="{f(w * 0.02)}" stroke-linecap="round"/>')
        out.append(f'<circle cx="{f(x2)}" cy="{f(y2)}" r="{f(w * 0.028)}" fill="#FF7043" opacity="0.9"/>')
    gs = s.lin([(0, '#A1887F'), (0.5, '#6D4C41'), (1, '#3E2723')], x1=0, y1=0, x2=0.3, y2=1)
    for dx, sc in ((-0.38, 1.0), (0.38, 0.95), (0.0, 0.8)):
        sx = cx + dx * w
        out.append(f'<path d="M {f(sx - w * 0.12 * sc)},{f(y)} Q {f(sx - w * 0.13 * sc)},{f(y - w * 0.2 * sc)} {f(sx)},{f(y - w * 0.22 * sc)} Q {f(sx + w * 0.13 * sc)},{f(y - w * 0.2 * sc)} {f(sx + w * 0.12 * sc)},{f(y)} Z" fill="{gs}"/>')
    out.append(f'<ellipse cx="{f(cx)}" cy="{f(y - w * 0.05)}" rx="{f(w * 0.3)}" ry="{f(w * 0.08)}" fill="#FF8F00" opacity="0.45" filter="{s.blur(w * 0.05)}"/>')
    return ''.join(out)


# ───────────────────────── pack assets ─────────────────────────

HERO_W, HERO_H = 480, 300


def hero():
    """Pongal pot seated on its hearth, sugarcane crossed behind, a kolam on the ground."""
    s = SVG(HERO_W, HERO_H, seed=13)
    s.add(f'<g transform="translate(240 270) scale(1 0.26)">{kolam(s, 0, 0, 205, color="#FFFFFF", opacity=0.9, stroke=6, rings=2)}</g>')
    s.add(sugarcane(s, 148, 266, 220, -24, width=16, leaf_scale=0.55))
    s.add(sugarcane(s, 332, 266, 220, 24, width=16, leaf_scale=0.55))
    s.add(hearth(s, 240, 264, 196))
    s.add(pot(s, 240, 226, 150, leaf_scale=0.62))
    for x, y, r in [(64, 264, 13), (416, 266, 12), (104, 278, 9), (378, 280, 9)]:
        s.add(aavaram(s, x, y, r, rot=x))
    s.save(f'{OUT}/hero.svg')
    # small flames between the stones, under the pot: (x, y of the flame base, size) as fractions
    flames = [(240 - 36, 256, 38), (240 + 4, 258, 46), (240 + 40, 256, 36)]
    return [(round(x / HERO_W, 4), round(y / HERO_H, 4), round(sz / HERO_W, 4)) for x, y, sz in flames]


def header_bg():
    s = SVG(1170, 1050, seed=17)
    s.add(f'<rect width="1170" height="1050" fill="{s.lin([(0, "#3F1A06"), (0.36, "#6A2C0C"), (0.72, "#94400F"), (1, "#A84E16")])}"/>')
    s.add(f'<rect width="1170" height="1050" fill="{s.rad([(0, "#FFB300", 0.42), (0.5, "#F57C00", 0.12), (1, "#F57C00", 0)], cx=1035, cy=525, r=620, units="userSpaceOnUse")}"/>')
    s.add(f'<rect width="1170" height="1050" fill="{s.rad([(0, "#FF8F00", 0.28), (1, "#FF8F00", 0)], cx=930, cy=760, r=420, units="userSpaceOnUse")}"/>')
    s.add(kolam(s, 1060, 560, 330, opacity=0.13, stroke=2.6, rings=3))
    s.add(kolam(s, 60, 980, 190, opacity=0.08, stroke=2.2, rings=2))
    s.add(sun(s, 1035, 525, 96))   # rises just behind the pongal pot on the right
    rnd = s.rnd
    for _ in range(14):
        s.add(bokeh(s, rnd.uniform(420, 1170), rnd.uniform(160, 980), rnd.uniform(14, 52), rnd.choice(['#FFD54F', '#FFB74D', '#FFF59D']), rnd.uniform(0.10, 0.24)))
    for _ in range(14):
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
    """Aavaram poo and poolai poo strung in swags, mango leaves hanging, neem 'kaappu' bunches at the ties."""
    s = SVG(1170, 132, seed=31)
    rnd = s.rnd
    leaves, ropes, flowers, knots = [], [], [], []
    for k, (x0, x1, sag) in enumerate(SWAGS):
        cx, cy = (x0 + x1) / 2, ANCHOR_Y + 2 * sag
        ropes.append(f'<path d="M {f(x0)},{ANCHOR_Y} Q {f(cx)},{f(cy)} {f(x1)},{ANCHOR_Y}" stroke="#5D4037" stroke-width="3.6" fill="none"/>')
        n = int(abs(x1 - x0) / 24)
        for i in range(n):
            t = (i + 0.5) / n + rnd.uniform(-0.1, 0.1) / n
            if t < 0.035 or t > 0.965:
                continue
            x, y, ang = _rope(x0, x1, sag, t)
            if i % 4 == 3:
                flowers.append(poolai(s, x, y + 1, rnd.uniform(9, 11)))
            else:
                flowers.append(aavaram(s, x, y + 1, rnd.uniform(11, 13.5), rot=rnd.uniform(0, 72)))
            if i % 3 == 1:
                depth = y - ANCHOR_Y
                length_ = rnd.uniform(60, 72) - depth * 0.3
                tilt = ang + rnd.uniform(-10, 10)
                from svgkit import mango_leaf
                if rnd.random() < 0.25:
                    leaves.append(mango_leaf(s, x - 5, y + 6, length_ * 0.9, 23, angle=tilt - 16, tone=i + 1))
                    leaves.append(mango_leaf(s, x + 5, y + 6, length_, 25, angle=tilt + 14, tone=i))
                else:
                    leaves.append(mango_leaf(s, x, y + 6, length_, rnd.uniform(23, 27), angle=tilt, tone=i + k))
    for ax, strand in [(392, 70), (774, 62)]:
        knots.append(neem_sprig(s, ax - 6, ANCHOR_Y + 8, 58, 26))
        knots.append(neem_sprig(s, ax + 6, ANCHOR_Y + 8, 54, -28))
        knots.append(f'<line x1="{ax}" y1="{ANCHOR_Y + 22}" x2="{ax}" y2="{ANCHOR_Y + strand}" stroke="#6D4C41" stroke-width="2"/>')
        knots.append(aavaram(s, ax, ANCHOR_Y + strand - 26, 10))
        knots.append(bell(s, ax, ANCHOR_Y + strand - 6, 17))
        knots.append(poolai(s, ax - 15, ANCHOR_Y + 12, 12))
        knots.append(aavaram(s, ax + 15, ANCHOR_Y + 12, 15))
        knots.append(aavaram(s, ax, ANCHOR_Y + 22, 17, rot=20))
    s.add(''.join(leaves) + ''.join(ropes) + ''.join(flowers) + ''.join(knots))
    s.save(f'{OUT}/thoranam.svg')


def splash_bg():
    W_, H_ = 1170, 2532
    s = SVG(W_, H_, seed=41)
    s.add(f'<rect width="{W_}" height="{H_}" fill="{s.lin([(0, "#3A1706"), (0.42, "#6A2C0C"), (0.8, "#94400F"), (1, "#A84E16")])}"/>')
    # the sun itself is drawn by the app behind the logo card (sun.webp), so it lines up on any screen
    s.add(f'<rect width="{W_}" height="{H_}" fill="{s.rad([(0, "#FF8F00", 0.32), (1, "#FF8F00", 0)], cx=585, cy=2330, r=640, units="userSpaceOnUse")}"/>')
    s.add(kolam(s, 585, 2290, 330, opacity=0.16, stroke=3, rings=3))
    s.add(kolam(s, 130, 300, 170, opacity=0.10, stroke=2.4, rings=2))
    s.add(kolam(s, 1040, 300, 170, opacity=0.10, stroke=2.4, rings=2))
    rnd = s.rnd
    for _ in range(20):
        s.add(bokeh(s, rnd.uniform(0, W_), rnd.uniform(160, H_ - 120), rnd.uniform(18, 60), rnd.choice(['#FFD54F', '#FFB74D', '#FFF59D']), rnd.uniform(0.08, 0.2)))
    for _ in range(30):
        s.add(sparkle(s, rnd.uniform(20, W_ - 20), rnd.uniform(180, H_ - 160), rnd.uniform(4, 11), opacity=rnd.uniform(0.3, 0.8)))
    s.save(f'{OUT}/splash_bg.svg')


def sun_halo():
    """Rising sun drawn behind the splash logo card: 600 × 600 px, transparent."""
    s = SVG(600, 600, seed=43)
    s.add(sun(s, 300, 300, 140))
    s.save(f'{OUT}/sun.svg')


if __name__ == '__main__':
    sun_halo()
    header_bg()
    thoranam()
    flames = hero()
    splash_bg()
    json.dump({'flames': flames, 'heroAspect': f'{HERO_W} / {HERO_H}'}, open(f'{OUT}/hero.json', 'w'), indent=1)
    print('flames', flames)
