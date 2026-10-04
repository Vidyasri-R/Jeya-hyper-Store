"""Navaratri & Ayudha Pooja pack: a plum and magenta silk night with a gold kolam; a thoranam of silk
pennants and marigolds with little bells; a golu — three steps draped in silk with a gold border,
marapachi-style dolls, a kalasam on top and lamps (their flames flicker in the app); a glowing
kalasam rising behind the splash logo and rows of lamps on golu steps at its foot.

Writes SVGs to out/navaratri/ (same file names as the other packs); render with
  node render.mjs --dir out/navaratri
"""
import json
import math
import os

from svgkit import *
from header_art import bell
from puthandu_art import butta_field, lotus_kolam
from puthandu_more import coconut

OUT = 'out/navaratri'
os.makedirs(OUT, exist_ok=True)

SILKS = ['#E91E63', '#FFC107', '#43A047', '#FF5722', '#8E24AA']


# ───────────────────────── motifs ─────────────────────────

def kalasam(s, cx, base_y, w, glow=False):
    """A brass kalasam: a round pot tied with thread, mango leaves fanned at its mouth, a coconut on top."""
    h = w * 0.85
    gold = s.lin([(0, '#7A4E00'), (0.25, '#C98A12'), (0.5, '#FFE7A0'), (0.75, '#C98A12'), (1, '#6B4300')], x1=0, y1=0, x2=1, y2=0)
    top = base_y - h
    out = []
    if glow:
        out.append(f'<circle cx="{f(cx)}" cy="{f(top + h * 0.2)}" r="{f(w * 0.9)}" fill="#FFE082" opacity="0.3" filter="{s.blur(w * 0.2)}"/>')
    out.append(f'<ellipse cx="{f(cx)}" cy="{f(base_y + 2)}" rx="{f(w * 0.42)}" ry="{f(h * 0.05)}" fill="#1A0414" opacity="0.4" filter="{s.blur(w * 0.03)}"/>')
    for k, (ang, ln) in enumerate([(-62, 0.62), (-36, 0.72), (-12, 0.78), (12, 0.78), (36, 0.72), (62, 0.62)]):
        out.append(mango_leaf(s, cx + (k - 2.5) * w * 0.04, top + h * 0.18, w * ln, w * 0.2, angle=180 + ang, tone=k))
    out.append(coconut(s, cx, top + h * 0.06, w * 0.24))
    body = (f'M {f(cx - w * 0.18)},{f(top + h * 0.3)} C {f(cx - w * 0.58)},{f(top + h * 0.38)} {f(cx - w * 0.56)},{f(base_y - h * 0.06)} {f(cx - w * 0.18)},{f(base_y)} '
            f'L {f(cx + w * 0.18)},{f(base_y)} C {f(cx + w * 0.56)},{f(base_y - h * 0.06)} {f(cx + w * 0.58)},{f(top + h * 0.38)} {f(cx + w * 0.18)},{f(top + h * 0.3)} Z')
    out.append(f'<path d="{body}" fill="{gold}"/>')
    out.append(f'<rect x="{f(cx - w * 0.2)}" y="{f(top + h * 0.22)}" width="{f(w * 0.4)}" height="{f(h * 0.1)}" rx="{f(w * 0.03)}" fill="{gold}"/>')
    out.append(f'<path d="M {f(cx - w * 0.44)},{f(top + h * 0.58)} Q {f(cx)},{f(top + h * 0.66)} {f(cx + w * 0.44)},{f(top + h * 0.58)}" stroke="#E53950" stroke-width="{f(w * 0.03)}" fill="none"/>')
    out.append(f'<path d="M {f(cx - w * 0.45)},{f(top + h * 0.63)} Q {f(cx)},{f(top + h * 0.71)} {f(cx + w * 0.45)},{f(top + h * 0.63)}" stroke="#FFD54F" stroke-width="{f(w * 0.02)}" fill="none"/>')
    for i in range(-3, 4):
        out.append(f'<circle cx="{f(cx + i * w * 0.11)}" cy="{f(top + h * 0.8 - (9 - i * i) * h * 0.004)}" r="{f(w * 0.018)}" fill="#C62828"/>')
    out.append(f'<ellipse cx="{f(cx - w * 0.22)}" cy="{f(top + h * 0.55)}" rx="{f(w * 0.06)}" ry="{f(h * 0.16)}" fill="#FFFFFF" opacity="0.3"/>')
    return ''.join(out)


def doll(s, cx, base_y, h, dress='#E91E63', kind=0):
    """A marapachi-style golu doll: a rounded wooden body in a painted dress, a round face, a hair bun
    (kind 0) or a turban (kind 1), a gold necklace."""
    w = h * 0.52
    wood = s.rad([(0, '#F4C48A'), (1, '#C08048')], cx=0.4, cy=0.35, r=0.75)
    dress_g = s.lin([(0, dress), (1, '#3A0A2E')], x1=0, y1=0, x2=0.4, y2=1)
    head_r = h * 0.16
    neck_y = base_y - h + head_r * 2.1
    out = [f'<ellipse cx="{f(cx + 2)}" cy="{f(base_y + 1)}" rx="{f(w * 0.55)}" ry="{f(h * 0.05)}" fill="#1A0414" opacity="0.35" filter="{s.blur(2)}"/>',
           f'<path d="M {f(cx - w * 0.26)},{f(neck_y)} L {f(cx + w * 0.26)},{f(neck_y)} L {f(cx + w * 0.52)},{f(base_y - h * 0.04)} Q {f(cx)},{f(base_y + h * 0.04)} {f(cx - w * 0.52)},{f(base_y - h * 0.04)} Z" fill="{dress_g}"/>',
           f'<path d="M {f(cx - w * 0.44)},{f(base_y - h * 0.18)} Q {f(cx)},{f(base_y - h * 0.1)} {f(cx + w * 0.44)},{f(base_y - h * 0.18)}" stroke="#FFD54F" stroke-width="{f(max(1, h * 0.03))}" fill="none"/>',
           f'<rect x="{f(cx - w * 0.36)}" y="{f(neck_y + h * 0.08)}" width="{f(w * 0.72)}" height="{f(h * 0.1)}" rx="{f(h * 0.05)}" fill="{dress}"/>',
           f'<circle cx="{f(cx)}" cy="{f(neck_y - head_r * 0.9)}" r="{f(head_r)}" fill="{wood}"/>']
    if kind == 0:
        out.append(f'<path d="M {f(cx - head_r)},{f(neck_y - head_r)} A {f(head_r)},{f(head_r)} 0 0 1 {f(cx + head_r)},{f(neck_y - head_r)} Q {f(cx)},{f(neck_y - head_r * 1.3)} {f(cx - head_r)},{f(neck_y - head_r)} Z" fill="#1A120E"/>')
        out.append(f'<circle cx="{f(cx)}" cy="{f(neck_y - head_r * 2.05)}" r="{f(head_r * 0.42)}" fill="#1A120E"/>')
        out.append(f'<circle cx="{f(cx + head_r * 0.45)}" cy="{f(neck_y - head_r * 2.0)}" r="{f(head_r * 0.18)}" fill="#FFFFFF"/>')   # malli in the hair
    else:
        out.append(f'<path d="M {f(cx - head_r * 1.08)},{f(neck_y - head_r * 1.15)} Q {f(cx)},{f(neck_y - head_r * 2.6)} {f(cx + head_r * 1.08)},{f(neck_y - head_r * 1.15)} Z" fill="#FFFFFF"/>')
        out.append(f'<path d="M {f(cx - head_r * 1.08)},{f(neck_y - head_r * 1.2)} Q {f(cx)},{f(neck_y - head_r * 1.5)} {f(cx + head_r * 1.08)},{f(neck_y - head_r * 1.2)}" stroke="#E53950" stroke-width="{f(max(1, h * 0.03))}" fill="none"/>')
    for dx in (-0.35, 0.35):
        out.append(f'<circle cx="{f(cx + dx * head_r)}" cy="{f(neck_y - head_r * 0.95)}" r="{f(max(0.7, head_r * 0.11))}" fill="#1A120E"/>')
    out.append(f'<circle cx="{f(cx)}" cy="{f(neck_y - head_r * 1.35)}" r="{f(max(0.6, head_r * 0.1))}" fill="#C62828"/>')
    out.append(f'<path d="M {f(cx - head_r * 0.25)},{f(neck_y - head_r * 0.55)} Q {f(cx)},{f(neck_y - head_r * 0.4)} {f(cx + head_r * 0.25)},{f(neck_y - head_r * 0.55)}" stroke="#8E2A1A" stroke-width="{f(max(0.6, head_r * 0.08))}" fill="none"/>')
    for i in range(-2, 3):
        out.append(f'<circle cx="{f(cx + i * w * 0.08)}" cy="{f(neck_y + h * 0.02 + abs(i) * -h * 0.008 + h * 0.02)}" r="{f(max(0.7, h * 0.018))}" fill="#FFD54F"/>')
    return ''.join(out)


def golu(s, cx, base_y, widths, step_h, depth):
    """Golu steps draped in silk with a gold border, bottom step first; returns (svg, [step top y])."""
    silk = s.lin([(0, '#B0124F'), (0.5, '#8A0E3E'), (1, '#5E0A2C')], x1=0, y1=0, x2=0, y2=1)
    top_g = s.lin([(0, '#D63A78'), (1, '#B0124F')], x1=0, y1=0, x2=0, y2=1)
    out = [f'<ellipse cx="{f(cx)}" cy="{f(base_y + 4)}" rx="{f(widths[0] * 0.56)}" ry="{f(step_h * 0.3)}" fill="#12020C" opacity="0.45" filter="{s.blur(6)}"/>']
    tops = []
    y = base_y
    for k, w in enumerate(widths):
        front_top = y - step_h
        out.append(f'<rect x="{f(cx - w / 2)}" y="{f(front_top)}" width="{f(w)}" height="{f(step_h)}" fill="{silk}"/>')
        out.append(f'<path d="M {f(cx - w / 2)},{f(front_top)} L {f(cx - w / 2 + depth * 0.4)},{f(front_top - depth)} L {f(cx + w / 2 - depth * 0.4)},{f(front_top - depth)} L {f(cx + w / 2)},{f(front_top)} Z" fill="{top_g}"/>')
        for yy, hh in ((front_top + 3, 3), (y - 7, 3)):
            out.append(f'<rect x="{f(cx - w / 2)}" y="{f(yy)}" width="{f(w)}" height="{hh}" fill="#FFD54F" opacity="0.9"/>')
        n = int(w / 14)
        for i in range(n):
            out.append(f'<circle cx="{f(cx - w / 2 + (i + 0.5) * w / n)}" cy="{f(front_top + step_h / 2)}" r="1.6" fill="#FFD54F" opacity="0.7"/>')
        tops.append(front_top - depth * 0.5)
        y = front_top - depth * 0.15
    return ''.join(out), tops


def plum(s, W_, H_, glow=None):
    s.add(f'<rect width="{W_}" height="{H_}" fill="{s.lin([(0, "#2E0723"), (0.4, "#4A0E3C"), (0.78, "#6E1650"), (1, "#8E1F66")])}"/>')
    if glow:
        gx, gy, gr = glow
        s.add(f'<rect width="{W_}" height="{H_}" fill="{s.rad([(0, "#FFC14D", 0.26), (0.5, "#FF80AB", 0.08), (1, "#FF80AB", 0)], cx=gx, cy=gy, r=gr, units="userSpaceOnUse")}"/>')


def pennant(s, x, y, w, h, colour, angle=0):
    g = s.lin([(0, colour), (1, '#3A0A2E')], x1=0, y1=0, x2=0, y2=1.6)
    return (f'<g transform="translate({f(x)} {f(y)}) rotate({f(angle)})">'
            f'<path d="M {f(-w / 2 + 2)},2 L {f(w / 2 + 2)},2 L {f(w / 2 + 2)},{f(h * 0.62 + 2)} L 2,{f(h + 2)} L {f(-w / 2 + 2)},{f(h * 0.62 + 2)} Z" fill="#12020C" opacity="0.25" filter="{s.blur(2)}"/>'
            f'<path d="M {f(-w / 2)},0 L {f(w / 2)},0 L {f(w / 2)},{f(h * 0.62)} L 0,{f(h)} L {f(-w / 2)},{f(h * 0.62)} Z" fill="{g}" stroke="#FFD54F" stroke-width="1.4"/>'
            f'<circle cx="0" cy="{f(h * 0.45)}" r="{f(w * 0.12)}" fill="#FFD54F" opacity="0.9"/></g>')


# ───────────────────────── pack assets ─────────────────────────

HERO_W, HERO_H = 480, 300


def hero():
    """A golu: three silk steps with dolls, the kalasam on top, lamps on the bottom step."""
    s = SVG(HERO_W, HERO_H, seed=107)
    s.add(f'<ellipse cx="250" cy="290" rx="232" ry="12" fill="#FFFFFF" opacity="0.10" filter="{s.blur(6)}"/>')
    steps, tops = golu(s, 250, 290, [330, 250, 170], 44, 18)
    s.add(steps)
    s.add(kalasam(s, 250, tops[2] + 6, 64))
    for x, dress, kind in [(196, '#43A047', 1), (304, '#E91E63', 0)]:
        s.add(doll(s, x, tops[2] + 4, 56, dress, kind))
    for x, dress, kind in [(170, '#FFC107', 0), (214, '#8E24AA', 1), (286, '#FF5722', 0), (330, '#1E88E5', 1)]:
        s.add(doll(s, x, tops[1] + 4, 52, dress, kind))
    flames = []
    for x in (110, 390):
        s.add(diya(s, x, tops[0] - 4, 40, style=0, with_flame=False))
        flames.append((x, tops[0] - 4, 40))
    for x, dress, kind in [(160, '#E91E63', 1), (205, '#43A047', 0), (250, '#FFC107', 1), (295, '#8E24AA', 0), (340, '#FF5722', 1)]:
        s.add(doll(s, x, tops[0] + 4, 50, dress, kind))
    s.save(f'{OUT}/hero.svg')
    return [(round(x / HERO_W, 4), round(y / HERO_H, 4), round(sz / HERO_W, 4)) for x, y, sz in flames]


def header_bg():
    s = SVG(1170, 1050, seed=109)
    plum(s, 1170, 1050, glow=(960, 700, 560))
    s.add(butta_field(s, 40, 60, 1170, 1050, 128, 30, color='#FFD54F', opacity=0.06))
    s.add(lotus_kolam(s, 1090, 470, 300, opacity=0.1))
    rnd = s.rnd
    for _ in range(16):
        s.add(bokeh(s, rnd.uniform(420, 1170), rnd.uniform(150, 990), rnd.uniform(14, 50), rnd.choice(['#FFD54F', '#FF80AB', '#FFF59D']), rnd.uniform(0.10, 0.22)))
    for _ in range(14):
        s.add(sparkle(s, rnd.uniform(420, 1160), rnd.uniform(150, 1000), rnd.uniform(3.5, 10), opacity=rnd.uniform(0.3, 0.8)))
    s.save(f'{OUT}/header_bg.svg')


SWAGS = [(-40, 392, 44), (392, 774, 36), (774, 1210, 42)]
ANCHOR_Y = 6


def _rope(x0, x1, sag, t):
    cx, cy = (x0 + x1) / 2, ANCHOR_Y + 2 * sag
    x = (1 - t) ** 2 * x0 + 2 * (1 - t) * t * cx + t * t * x1
    y = (1 - t) ** 2 * ANCHOR_Y + 2 * (1 - t) * t * cy + t * t * ANCHOR_Y
    dx = 2 * (1 - t) * (cx - x0) + 2 * t * (x1 - cx)
    dy = 2 * (1 - t) * (cy - ANCHOR_Y) + 2 * t * (ANCHOR_Y - cy)
    return x, y, math.degrees(math.atan2(dy, dx))


def thoranam():
    """Silk pennants with gold edges in swags, little bells between them, marigold rosettes at the ties."""
    s = SVG(1170, 132, seed=113)
    ropes, flags, ties = [], [], []
    for k, (x0, x1, sag) in enumerate(SWAGS):
        cx, cy = (x0 + x1) / 2, ANCHOR_Y + 2 * sag
        ropes.append(f'<path d="M {f(x0)},{ANCHOR_Y} Q {f(cx)},{f(cy)} {f(x1)},{ANCHOR_Y}" stroke="#FFD54F" stroke-width="2.4" fill="none"/>')
        n = int(abs(x1 - x0) / 30)
        for i in range(n):
            t = (i + 0.5) / n
            if t < 0.04 or t > 0.96:
                continue
            x, y, ang = _rope(x0, x1, sag, t)
            flags.append(pennant(s, x, y, 24, 38, SILKS[(i + k) % len(SILKS)], angle=ang))
            if i % 3 == 2:
                flags.append(f'<line x1="{f(x + 15)}" y1="{f(y + 2)}" x2="{f(x + 15)}" y2="{f(y + 30)}" stroke="#C98A12" stroke-width="1.2"/>' + bell(s, x + 15, y + 30, 11))
    for ax in (392, 774):
        ties.append(marigold(s, ax - 16, ANCHOR_Y + 14, 13, 'orange'))
        ties.append(marigold(s, ax + 16, ANCHOR_Y + 14, 13, 'deep'))
        ties.append(marigold(s, ax, ANCHOR_Y + 22, 16, 'yellow'))
        ties.append(f'<line x1="{ax}" y1="{ANCHOR_Y + 34}" x2="{ax}" y2="{ANCHOR_Y + 64}" stroke="#C98A12" stroke-width="1.6"/>' + bell(s, ax, ANCHOR_Y + 62, 16))
    s.add(''.join(ropes) + ''.join(flags) + ''.join(ties))
    s.save(f'{OUT}/thoranam.svg')


def splash_bg():
    W_, H_ = 1170, 2532
    s = SVG(W_, H_, seed=127)
    plum(s, W_, H_, glow=(585, 1060, 700))
    s.add(butta_field(s, 40, 220, W_, H_ - 500, 140, 32, color='#FFD54F', opacity=0.06))
    s.add(lotus_kolam(s, 130, 320, 160, opacity=0.1))
    s.add(lotus_kolam(s, 1040, 320, 160, opacity=0.1))
    rnd = s.rnd
    for _ in range(22):
        s.add(bokeh(s, rnd.uniform(0, W_), rnd.uniform(180, H_ - 520), rnd.uniform(18, 60), rnd.choice(['#FFD54F', '#FF80AB', '#FFF59D']), rnd.uniform(0.08, 0.2)))
    for _ in range(26):
        s.add(sparkle(s, rnd.uniform(20, W_ - 20), rnd.uniform(200, H_ - 560), rnd.uniform(4, 11), opacity=rnd.uniform(0.3, 0.8)))
    # golu steps across the foot, a lamp on every step
    steps, tops = golu(s, 585, H_ - 30, [1300, 1060, 820], 120, 40)
    s.add(steps)
    for k, (w, y) in enumerate(zip([1300, 1060, 820], tops)):
        n = 7 - k * 2
        for i in range(n):
            x = 585 - w * 0.42 + (i + 0.5) * w * 0.84 / n
            s.add(diya(s, x, y - 10, 70 - k * 8, style=(i + k) % 3))
    s.save(f'{OUT}/splash_bg.svg')


def kalasam_halo():
    """A glowing kalasam rising behind the splash logo (600 × 600): coconut and mango leaves above the card."""
    s = SVG(600, 600, seed=131)
    s.add(f'<circle cx="300" cy="250" r="240" fill="#FFD27A" opacity="0.22" filter="{s.blur(60)}"/>')
    for i in range(24):
        a = -180 + i * (180 / 23)
        r0, r1 = 150, (292 if i % 2 else 246)
        p = [(300 + math.cos(math.radians(a + d)) * r, 250 + math.sin(math.radians(a + d)) * r) for d, r in ((-1.6, r0), (0, r1), (1.6, r0))]
        s.add(f'<polygon points="{" ".join(f"{f(x)},{f(y)}" for x, y in p)}" fill="#FFE082" opacity="{0.3 if i % 2 else 0.18}"/>')
    s.add(kalasam(s, 300, 470, 300))
    s.save(f'{OUT}/kalasam.svg')


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
    kalasam_halo()
    json.dump({'flames': flames, 'heroAspect': f'{HERO_W} / {HERO_H}'}, open(f'{OUT}/hero.json', 'w'), indent=1)
    print('flames', flames)
