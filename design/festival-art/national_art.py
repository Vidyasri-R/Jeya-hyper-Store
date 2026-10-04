"""Independence & Republic Day pack: a navy night lit by saffron, white and green fireworks; tricolour
bunting with ribbon rosettes at the ties; tricolour balloons, a kite and a plate of tiranga barfi
with laddoos and marigolds; a tricolour sunburst behind the splash logo and flowing ribbons at
its foot. Tricolour motifs only — the national flag and the Ashoka Chakra are not used in
commercial art.

Writes SVGs to out/national/ (same file names as the other packs); render with
  node render.mjs --dir out/national
"""
import json
import math
import os

from svgkit import *
from banners import brass_plate, laddoo
from christmas_art import firework

OUT = 'out/national'
os.makedirs(OUT, exist_ok=True)

SAFFRON, WHITE, GREEN = '#FF9933', '#FFFFFF', '#138808'
TRI = (SAFFRON, WHITE, GREEN)


# ───────────────────────── motifs ─────────────────────────

def pennant(s, x, y, w, h, colour, angle=0):
    """A triangular bunting flag hanging from its top edge centred on (x, y)."""
    shade = {SAFFRON: '#E07B10', WHITE: '#D9DEE8', GREEN: '#0B6A05'}[colour]
    g = s.lin([(0, colour), (1, shade)], x1=0, y1=0, x2=0, y2=1)
    return (f'<g transform="translate({f(x)} {f(y)}) rotate({f(angle)})">'
            f'<path d="M {f(-w / 2 + 2)},2 L {f(w / 2 + 2)},2 L 2,{f(h + 3)} Z" fill="#05103A" opacity="0.25" filter="{s.blur(2)}"/>'
            f'<path d="M {f(-w / 2)},0 L {f(w / 2)},0 L 0,{f(h)} Z" fill="{g}" stroke="{shade}" stroke-width="0.8"/>'
            f'<path d="M {f(-w / 2)},0 L {f(w / 2)},0" stroke="#FFFFFF" stroke-opacity="0.5" stroke-width="1.6"/></g>')


def rosette(s, cx, cy, r, tails=True):
    """A ribbon rosette (cockade) in saffron, white and green, with two ribbon tails."""
    out = []
    if tails:
        for sgn, col in ((-1, SAFFRON), (1, GREEN)):
            out.append(f'<path d="M {f(cx + sgn * r * 0.15)},{f(cy)} L {f(cx + sgn * r * 0.75)},{f(cy + r * 1.7)} L {f(cx + sgn * r * 0.45)},{f(cy + r * 1.5)} L {f(cx + sgn * r * 0.25)},{f(cy + r * 1.8)} Z" fill="{col}" stroke="#05103A" stroke-opacity="0.25" stroke-width="0.8"/>')
    for k, (rr, col) in enumerate(((1.0, SAFFRON), (0.72, WHITE), (0.46, GREEN))):
        pts = []
        n = 28 - k * 6
        for i in range(n * 2):
            a = math.radians(i * 180 / n)
            q = r * rr * (1.0 if i % 2 == 0 else 0.9)
            pts.append(f'{f(cx + math.cos(a) * q)},{f(cy + math.sin(a) * q)}')
        out.append(f'<polygon points="{" ".join(pts)}" fill="{col}" stroke="#05103A" stroke-opacity="0.2" stroke-width="0.8"/>')
    out.append(f'<circle cx="{f(cx)}" cy="{f(cy)}" r="{f(r * 0.2)}" fill="#FFD54F"/>')
    out.append(f'<ellipse cx="{f(cx - r * 0.35)}" cy="{f(cy - r * 0.4)}" rx="{f(r * 0.25)}" ry="{f(r * 0.12)}" fill="#FFFFFF" opacity="0.45"/>')
    return ''.join(out)


def balloon(s, cx, cy, r, colour, string_to=None):
    shade = {SAFFRON: '#C25E00', WHITE: '#B8C2D6', GREEN: '#0A5A04'}[colour]
    light = {SAFFRON: '#FFC98A', WHITE: '#FFFFFF', GREEN: '#6BCB5F'}[colour]
    g = s.rad([(0, light), (0.55, colour), (1, shade)], cx=0.38, cy=0.32, r=0.75)
    out = []
    if string_to:
        tx, ty = string_to
        out.append(f'<path d="M {f(cx)},{f(cy + r * 1.22)} C {f(cx + r * 0.4)},{f(cy + r * 2)} {f(tx - r * 0.3)},{f((cy + ty) / 2 + r)} {f(tx)},{f(ty)}" stroke="#DCE3F0" stroke-opacity="0.8" stroke-width="1.4" fill="none"/>')
    out.append(f'<ellipse cx="{f(cx + r * 0.08)}" cy="{f(cy + r * 0.12)}" rx="{f(r)}" ry="{f(r * 1.18)}" fill="#05103A" opacity="0.25" filter="{s.blur(r * 0.12)}"/>')
    out.append(f'<ellipse cx="{f(cx)}" cy="{f(cy)}" rx="{f(r)}" ry="{f(r * 1.18)}" fill="{g}"/>')
    out.append(f'<path d="M {f(cx - r * 0.12)},{f(cy + r * 1.3)} L {f(cx + r * 0.12)},{f(cy + r * 1.3)} L {f(cx)},{f(cy + r * 1.16)} Z" fill="{shade}"/>')
    out.append(f'<ellipse cx="{f(cx - r * 0.38)}" cy="{f(cy - r * 0.45)}" rx="{f(r * 0.2)}" ry="{f(r * 0.32)}" transform="rotate(-25 {f(cx - r * 0.38)} {f(cy - r * 0.45)})" fill="#FFFFFF" opacity="0.55"/>')
    return ''.join(out)


def kite(s, cx, cy, size, angle=-12):
    """A diamond paper kite in tricolour bands with a bowed tail."""
    w, h = size, size * 1.25
    clip = s.clip(f'<path d="M 0,{f(-h / 2)} L {f(w / 2)},0 L 0,{f(h / 2)} L {f(-w / 2)},0 Z"/>')
    tail = ''.join(f'<path d="M {f(-6 + k * 2)},{f(h / 2 + 16 + k * 22)} l 8,-6 l 0,12 Z" fill="{TRI[k % 3]}" stroke="#05103A" stroke-opacity="0.3" stroke-width="0.6"/>' for k in range(4))
    return (f'<g transform="translate({f(cx)} {f(cy)}) rotate({f(angle)})">'
            f'<path d="M 0,{f(h / 2)} C 10,{f(h / 2 + 30)} -10,{f(h / 2 + 60)} 4,{f(h / 2 + 100)}" stroke="#DCE3F0" stroke-width="1.4" fill="none"/>{tail}'
            f'<path d="M 4,{f(-h / 2 + 4)} L {f(w / 2 + 4)},4 L 4,{f(h / 2 + 4)} L {f(-w / 2 + 4)},4 Z" fill="#05103A" opacity="0.25" filter="{s.blur(3)}"/>'
            f'<g clip-path="{clip}"><rect x="{f(-w)}" y="{f(-h)}" width="{f(w * 2)}" height="{f(h * 0.83)}" fill="{SAFFRON}"/>'
            f'<rect x="{f(-w)}" y="{f(-h * 0.17)}" width="{f(w * 2)}" height="{f(h * 0.34)}" fill="{WHITE}"/>'
            f'<rect x="{f(-w)}" y="{f(h * 0.17)}" width="{f(w * 2)}" height="{f(h)}" fill="{GREEN}"/></g>'
            f'<path d="M 0,{f(-h / 2)} L 0,{f(h / 2)} M {f(-w / 2)},0 L {f(w / 2)},0" stroke="#8D6E63" stroke-width="1.2" opacity="0.7"/>'
            f'<path d="M 0,{f(-h / 2)} L {f(w / 2)},0 L 0,{f(h / 2)} L {f(-w / 2)},0 Z" fill="none" stroke="#05103A" stroke-opacity="0.35" stroke-width="1"/></g>')


def barfi(s, x, y, w, h, a=0):
    """A chunky piece of tiranga barfi seen from above the front: saffron, white and green layers, a
    silver-leaf top dotted with pistachio."""
    t = h / 3
    d = w * 0.32          # depth of the top face
    out = [f'<g transform="translate({f(x)} {f(y)}) rotate({f(a)})">',
           f'<rect x="{f(-w / 2 + 4)}" y="{f(-h / 2 + 6)}" width="{f(w + d * 0.6)}" height="{f(h)}" rx="4" fill="#05103A" opacity="0.3" filter="{s.blur(3)}"/>',
           # right side face (shaded)
           f'<path d="M {f(w / 2)},{f(-h / 2)} L {f(w / 2 + d * 0.6)},{f(-h / 2 - d * 0.5)} L {f(w / 2 + d * 0.6)},{f(h / 2 - d * 0.5)} L {f(w / 2)},{f(h / 2)} Z" fill="#B8935E"/>']
    for k, col in enumerate(('#E8862E', '#E9DFCF', '#3E9A37')):
        out.append(f'<path d="M {f(w / 2)},{f(-h / 2 + k * t)} L {f(w / 2 + d * 0.6)},{f(-h / 2 + k * t - d * 0.5)} L {f(w / 2 + d * 0.6)},{f(-h / 2 + (k + 1) * t - d * 0.5)} L {f(w / 2)},{f(-h / 2 + (k + 1) * t)} Z" fill="{col}"/>')
    for k, col in enumerate(('#FFA94D', '#FFF8EC', '#5DBB55')):
        out.append(f'<rect x="{f(-w / 2)}" y="{f(-h / 2 + k * t)}" width="{f(w)}" height="{f(t + 0.5)}" fill="{col}"/>')
    out.append(f'<path d="M {f(-w / 2)},{f(-h / 2)} L {f(-w / 2 + d * 0.6)},{f(-h / 2 - d * 0.5)} L {f(w / 2 + d * 0.6)},{f(-h / 2 - d * 0.5)} L {f(w / 2)},{f(-h / 2)} Z" fill="#EEF1F6" stroke="#C9CFDA" stroke-width="0.6"/>')
    rnd = s.rnd
    for _ in range(4):
        px, py = rnd.uniform(-w * 0.35, w * 0.45), -h / 2 - rnd.uniform(d * 0.1, d * 0.4)
        out.append(f'<ellipse cx="{f(px)}" cy="{f(py)}" rx="{f(w * 0.06)}" ry="{f(w * 0.022)}" fill="#7CB342"/>')
    out.append(f'<rect x="{f(-w / 2)}" y="{f(-h / 2)}" width="{f(w)}" height="{f(h)}" fill="none" stroke="#B8935E" stroke-opacity="0.5" stroke-width="0.8"/>')
    out.append('</g>')
    return ''.join(out)


def navy(s, W_, H_, glow=None):
    s.add(f'<rect width="{W_}" height="{H_}" fill="{s.lin([(0, "#06123A"), (0.42, "#0B1E4F"), (0.8, "#142C6E"), (1, "#1A3A85")])}"/>')
    if glow:
        gx, gy, gr = glow
        s.add(f'<rect width="{W_}" height="{H_}" fill="{s.rad([(0, "#FFB766", 0.22), (0.5, "#FF9933", 0.08), (1, "#FF9933", 0)], cx=gx, cy=gy, r=gr, units="userSpaceOnUse")}"/>')


def tri_rays(s, cx, cy, R, opacity=0.14):
    """Soft rays in saffron, white and green fanning from a point."""
    out = [f'<g opacity="{f(opacity)}">']
    for i in range(36):
        a0 = math.radians(i * 10)
        a1 = math.radians(i * 10 + 5)
        col = TRI[i % 3]
        out.append(f'<path d="M {f(cx)},{f(cy)} L {f(cx + math.cos(a0) * R)},{f(cy + math.sin(a0) * R)} L {f(cx + math.cos(a1) * R)},{f(cy + math.sin(a1) * R)} Z" fill="{col}"/>')
    out.append('</g>')
    return ''.join(out)


def tri_confetti(s, x0, x1, y0, y1, n):
    rnd = s.rnd
    out = []
    for _ in range(n):
        x, y = rnd.uniform(x0, x1), rnd.uniform(y0, y1)
        c = rnd.choice(TRI)
        if rnd.random() < 0.6:
            out.append(f'<rect x="{f(x)}" y="{f(y)}" width="{f(rnd.uniform(6, 12))}" height="{f(rnd.uniform(3, 5))}" fill="{c}" transform="rotate({f(rnd.uniform(0, 180))} {f(x)} {f(y)})"/>')
        else:
            out.append(f'<path d="M {f(x)},{f(y)} q 8,-10 16,0 t 16,0" stroke="{c}" stroke-width="3" fill="none" stroke-linecap="round" transform="rotate({f(rnd.uniform(0, 180))} {f(x)} {f(y)})"/>')
    return ''.join(out)


def ribbons(s, y, W_, amp=40):
    """Three flowing ribbons (saffron, white, green) waving across the width."""
    out = []
    for k, col in enumerate(TRI):
        yy = y + k * 34
        d = f'M -20,{f(yy)} C {f(W_ * 0.25)},{f(yy - amp)} {f(W_ * 0.5)},{f(yy + amp)} {f(W_ * 0.75)},{f(yy - amp * 0.6)} S {f(W_ + 40)},{f(yy + amp * 0.4)} {f(W_ + 40)},{f(yy)}'
        out.append(f'<path d="{d}" stroke="#03092A" stroke-opacity="0.35" stroke-width="34" fill="none" transform="translate(0 8)" filter="{s.blur(6)}"/>')
        out.append(f'<path d="{d}" stroke="{col}" stroke-width="30" fill="none"/>')
        out.append(f'<path d="{d}" stroke="#FFFFFF" stroke-opacity="0.25" stroke-width="5" fill="none" transform="translate(0 -9)"/>')
    return ''.join(out)


# ───────────────────────── pack assets ─────────────────────────

HERO_W, HERO_H = 480, 300


def hero():
    """Tricolour balloons and a kite over a brass plate of tiranga barfi and laddoos, marigolds round it."""
    s = SVG(HERO_W, HERO_H, seed=53)
    s.add(f'<ellipse cx="250" cy="288" rx="232" ry="12" fill="#FFFFFF" opacity="0.10" filter="{s.blur(6)}"/>')
    s.add(kite(s, 92, 92, 74, angle=-14))
    for (x, y, r, c) in [(388, 70, 34, SAFFRON), (434, 108, 30, WHITE), (350, 120, 30, GREEN)]:
        s.add(balloon(s, x, y, r, c, string_to=(400, 268)))
    s.add(brass_plate(s, 250, 262, 150, 34))
    for (x, y, a) in [(196, 236, -8), (236, 230, 4), (276, 232, -4), (214, 206, 6), (256, 202, -6)]:
        s.add(barfi(s, x, y, 40, 30, a))
    for (x, y, r) in [(318, 236, 22), (300, 214, 20), (336, 214, 19)]:
        s.add(laddoo(s, x, y, r))
    for (x, y, k) in [(116, 272, 'orange'), (146, 280, 'yellow'), (372, 280, 'orange'), (404, 272, 'yellow')]:
        s.add(marigold(s, x, y, 15, k))
    s.add(rosette(s, 60, 250, 22))
    s.save(f'{OUT}/hero.svg')
    return []   # no flames on this one


def header_bg():
    s = SVG(1170, 1050, seed=59)
    navy(s, 1170, 1050, glow=(960, 700, 560))
    s.add(tri_rays(s, 1100, 380, 900, opacity=0.06))
    for (x, y, R, c) in [(1010, 470, 110, SAFFRON), (1120, 660, 84, '#3DDC4F'), (840, 600, 66, WHITE)]:   # clear of the avatar, top right
        s.add(firework(s, x, y, R, colour=c, opacity=0.4, rays=20))
    s.add(tri_confetti(s, 420, 1170, 150, 1000, 60))
    rnd = s.rnd
    for _ in range(12):
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
    """Tricolour bunting in swags, ribbon rosettes and marigolds at the ties."""
    s = SVG(1170, 132, seed=61)
    strings, flags, ties = [], [], []
    for k, (x0, x1, sag) in enumerate(SWAGS):
        cx, cy = (x0 + x1) / 2, ANCHOR_Y + 2 * sag
        strings.append(f'<path d="M {f(x0)},{ANCHOR_Y} Q {f(cx)},{f(cy)} {f(x1)},{ANCHOR_Y}" stroke="#DCE3F0" stroke-width="2" fill="none"/>')
        n = int(abs(x1 - x0) / 30)
        for i in range(n):
            t = (i + 0.5) / n
            if t < 0.04 or t > 0.96:
                continue
            x, y, ang = _rope(x0, x1, sag, t)
            flags.append(pennant(s, x, y, 26, 36, TRI[(i + k) % 3], angle=ang))
    for ax in (392, 774):
        ties.append(marigold(s, ax - 16, ANCHOR_Y + 14, 13, 'orange'))
        ties.append(marigold(s, ax + 16, ANCHOR_Y + 14, 13, 'yellow'))
        ties.append(rosette(s, ax, ANCHOR_Y + 20, 20))
    s.add(''.join(strings) + ''.join(flags) + ''.join(ties))
    s.save(f'{OUT}/thoranam.svg')


def splash_bg():
    W_, H_ = 1170, 2532
    s = SVG(W_, H_, seed=67)
    navy(s, W_, H_, glow=(585, 1060, 700))
    s.add(tri_rays(s, 585, 1060, 1500, opacity=0.05))
    for (x, y, R, c) in [(220, 520, 150, SAFFRON), (960, 480, 160, '#3DDC4F'), (180, 1500, 120, WHITE), (1000, 1600, 130, SAFFRON), (600, 300, 110, WHITE)]:
        s.add(firework(s, x, y, R, colour=c, opacity=0.38, rays=22))
    s.add(tri_confetti(s, 0, W_, 200, H_ - 400, 120))
    rnd = s.rnd
    for _ in range(26):
        s.add(sparkle(s, rnd.uniform(20, W_ - 20), rnd.uniform(200, H_ - 400), rnd.uniform(4, 11), opacity=rnd.uniform(0.3, 0.8)))
    s.add(ribbons(s, H_ - 230, W_))
    s.save(f'{OUT}/splash_bg.svg')


def sunburst_halo():
    """A golden sun with saffron, white and green rays rising behind the splash logo (600 × 600)."""
    s = SVG(600, 600, seed=71)
    s.add(f'<circle cx="300" cy="300" r="250" fill="#FFB766" opacity="0.2" filter="{s.blur(70)}"/>')
    for i in range(30):
        a = -180 + i * (180 / 29)
        r0, r1 = 140, (292 if i % 2 else 246)
        col = TRI[i % 3]
        p = [(300 + math.cos(math.radians(a + d)) * r, 300 + math.sin(math.radians(a + d)) * r) for d, r in ((-2.4, r0), (0, r1), (2.4, r0))]
        s.add(f'<polygon points="{" ".join(f"{f(x)},{f(y)}" for x, y in p)}" fill="{col}" opacity="0.75"/>')
    sun = s.rad([(0, '#FFFDE7'), (0.45, '#FFE082'), (0.8, '#FFB74D'), (1, '#FF9933')], cx=0.42, cy=0.4, r=0.65)
    s.add(f'<circle cx="300" cy="300" r="150" fill="#FFB766" opacity="0.35" filter="{s.blur(18)}"/>')
    s.add(f'<circle cx="300" cy="300" r="132" fill="{sun}"/>')
    s.save(f'{OUT}/sunburst.svg')


def flame_asset():
    """Not used by this pack's hero, but every pack ships one (150 × 240, glow kept inside)."""
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
    sunburst_halo()
    json.dump({'flames': flames, 'heroAspect': f'{HERO_W} / {HERO_H}'}, open(f'{OUT}/hero.json', 'w'), indent=1)
    print('flames', flames)
