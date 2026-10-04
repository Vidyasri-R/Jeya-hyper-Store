"""Pongal banners, button texture, section icon and falling-petal sprites (out/pongal/)."""
import math

from svgkit import *
from banners import brass_plate, cashew, laddoo, murukku, raisin, _petal
from pongal_art import OUT, aavaram, kolam, poolai, pot, sugarcane

W, H = 1080, 540


def banana_leaf(s, cx, cy, length, width, angle):
    g = s.lin([(0, '#1B5E20'), (0.5, '#43A047'), (1, '#2E7D32')], x1=0, y1=0, x2=0, y2=1)
    L, Wd = length / 2, width / 2
    d = f'M {f(-L)},0 C {f(-L * 0.6)},{f(-Wd)} {f(L * 0.6)},{f(-Wd * 1.05)} {f(L)},{f(-Wd * 0.1)} C {f(L * 0.6)},{f(Wd)} {f(-L * 0.6)},{f(Wd * 1.02)} {f(-L)},0 Z'
    veins = ''.join(f'<line x1="{f(x)}" y1="0" x2="{f(x + Wd * 0.5)}" y2="{f(-Wd * 0.88)}" stroke="#A5D6A7" stroke-opacity="0.35" stroke-width="1.6"/>'
                    f'<line x1="{f(x)}" y1="0" x2="{f(x + Wd * 0.5)}" y2="{f(Wd * 0.88)}" stroke="#A5D6A7" stroke-opacity="0.35" stroke-width="1.6"/>'
                    for x in [(-L + i * L * 0.16) for i in range(12)])
    return (f'<g transform="translate({f(cx)} {f(cy)}) rotate({f(angle)})"><path d="{d}" fill="#0B2A0E" opacity="0.35" transform="translate(6 10)" filter="{s.blur(8)}"/>'
            f'<path d="{d}" fill="{g}"/>{veins}<line x1="{f(-L)}" y1="0" x2="{f(L)}" y2="{f(-Wd * 0.1)}" stroke="#C8E6C9" stroke-width="4"/></g>')


def uruli_with_pongal(s, cx, cy, rx):
    """Brass uruli heaped with sakkarai pongal, cashews and raisins."""
    ry = rx * 0.3
    gold = s.lin([(0, '#7A4E00'), (0.25, '#C98A12'), (0.5, '#FFE7A0'), (0.75, '#C98A12'), (1, '#6B4300')], x1=0, y1=0, x2=1, y2=0)
    out = [f'<ellipse cx="{f(cx)}" cy="{f(cy + ry * 1.6)}" rx="{f(rx * 1.02)}" ry="{f(ry * 0.6)}" fill="#2B1400" opacity="0.35" filter="{s.blur(10)}"/>',
           f'<path d="M {f(cx - rx)},{f(cy)} Q {f(cx - rx * 0.92)},{f(cy + ry * 2.2)} {f(cx)},{f(cy + ry * 2.25)} Q {f(cx + rx * 0.92)},{f(cy + ry * 2.2)} {f(cx + rx)},{f(cy)} Z" fill="{gold}"/>']
    for sgn in (-1, 1):   # handles
        hx = cx + sgn * rx * 1.02
        out.append(f'<path d="M {f(hx)},{f(cy + ry * 0.2)} q {f(sgn * rx * 0.16)},{f(ry * 0.1)} {f(sgn * rx * 0.12)},{f(ry * 0.9)}" stroke="#B07A10" stroke-width="{f(rx * 0.05)}" fill="none" stroke-linecap="round"/>')
    # the pongal mound: golden brown rice with a ghee sheen
    mound = f'M {f(cx - rx * 0.92)},{f(cy)} Q {f(cx - rx * 0.6)},{f(cy - ry * 2.1)} {f(cx)},{f(cy - ry * 2.3)} Q {f(cx + rx * 0.6)},{f(cy - ry * 2.1)} {f(cx + rx * 0.92)},{f(cy)} Z'
    gm = s.rad([(0, '#E9B24F'), (0.6, '#C17A1F'), (1, '#8D4F0F')], cx=0.42, cy=0.3, r=0.75)
    out.append(f'<path d="{mound}" fill="{gm}"/>')
    clip = s.clip(f'<path d="{mound}"/>')
    rnd = s.rnd
    grains = ''.join(f'<ellipse cx="{f(cx + rnd.uniform(-rx * 0.9, rx * 0.9))}" cy="{f(cy - rnd.uniform(0, ry * 2.3))}" rx="{f(rx * 0.022)}" ry="{f(rx * 0.011)}" '
                     f'transform="rotate({f(rnd.uniform(0, 180))} 0 0)" fill="{rnd.choice(["#F6CF7A", "#B8701C", "#FCE0A0"])}" opacity="0.8"/>' for _ in range(0))
    grains += ''.join(_grain(s, cx + rnd.uniform(-rx * 0.9, rx * 0.9), cy - rnd.uniform(0, ry * 2.3), rx * 0.024, rnd.choice(['#F6CF7A', '#B8701C', '#FCE0A0'])) for _ in range(160))
    out.append(f'<g clip-path="{clip}">{grains}<ellipse cx="{f(cx - rx * 0.25)}" cy="{f(cy - ry * 1.5)}" rx="{f(rx * 0.3)}" ry="{f(ry * 0.5)}" fill="#FFFFFF" opacity="0.22" filter="{s.blur(rx * 0.06)}"/></g>')
    for (dx, dy, a) in [(-0.35, -1.0, -30), (0.1, -1.7, 20), (0.42, -0.9, 60), (-0.1, -1.25, 100), (0.25, -1.4, -70)]:
        out.append(cashew(s, cx + dx * rx, cy + dy * ry, rx * 0.11, a))
    for (dx, dy) in [(-0.5, -0.6), (0.3, -1.95), (0.58, -0.45), (-0.22, -1.7)]:
        out.append(raisin(s, cx + dx * rx, cy + dy * ry, rx * 0.04, dx * 90))
    # rim
    out.append(f'<ellipse cx="{f(cx)}" cy="{f(cy)}" rx="{f(rx)}" ry="{f(ry * 0.35)}" fill="none" stroke="#FFE7A0" stroke-width="{f(rx * 0.035)}"/>')
    return ''.join(out)


def _grain(s, x, y, r, c):
    return f'<ellipse cx="{f(x)}" cy="{f(y)}" rx="{f(r)}" ry="{f(r * 0.48)}" fill="{c}" opacity="0.85" transform="rotate({f((x * 7) % 180)} {f(x)} {f(y)})"/>'


def jaggery(s, cx, cy, r):
    g = s.rad([(0, '#C8813A'), (0.6, '#8F4F17'), (1, '#5A2E0B')], cx=0.38, cy=0.32, r=0.8)
    rnd = s.rnd
    clip = s.clip(f'<ellipse cx="{f(cx)}" cy="{f(cy)}" rx="{f(r)}" ry="{f(r * 0.82)}"/>')
    specks = ''.join(f'<circle cx="{f(cx + rnd.uniform(-r, r))}" cy="{f(cy + rnd.uniform(-r, r))}" r="{f(r * rnd.uniform(0.03, 0.07))}" fill="{rnd.choice(["#E0A060", "#6B3A12"])}" opacity="0.7"/>' for _ in range(40))
    return (f'<ellipse cx="{f(cx + 6)}" cy="{f(cy + r * 0.85)}" rx="{f(r * 0.95)}" ry="{f(r * 0.22)}" fill="#2B1400" opacity="0.35" filter="{s.blur(6)}"/>'
            f'<ellipse cx="{f(cx)}" cy="{f(cy)}" rx="{f(r)}" ry="{f(r * 0.82)}" fill="{g}"/><g clip-path="{clip}">{specks}</g>'
            f'<ellipse cx="{f(cx - r * 0.3)}" cy="{f(cy - r * 0.35)}" rx="{f(r * 0.3)}" ry="{f(r * 0.16)}" fill="#FFFFFF" opacity="0.2"/>')


def dal_bowl(s, cx, cy, rx, colour=('#FFE082', '#F9A825')):
    ry = rx * 0.32
    rnd = s.rnd
    bowl = s.lin([(0, '#ECEFF1'), (1, '#B0BEC5')], x1=0, y1=0, x2=0, y2=1)
    lentils = ''.join(f'<ellipse cx="{f(cx + rnd.uniform(-rx * 0.8, rx * 0.8))}" cy="{f(cy - rnd.uniform(0, ry * 1.6))}" rx="{f(rx * 0.07)}" ry="{f(rx * 0.05)}" fill="{rnd.choice(colour)}"/>' for _ in range(60))
    return (f'<ellipse cx="{f(cx)}" cy="{f(cy + ry * 1.9)}" rx="{f(rx * 0.95)}" ry="{f(ry * 0.4)}" fill="#2B1400" opacity="0.3" filter="{s.blur(6)}"/>'
            f'<path d="M {f(cx - rx)},{f(cy)} Q {f(cx)},{f(cy + ry * 3)} {f(cx + rx)},{f(cy)} Z" fill="{bowl}"/>'
            f'<path d="M {f(cx - rx * 0.92)},{f(cy)} Q {f(cx)},{f(cy - ry * 2.2)} {f(cx + rx * 0.92)},{f(cy)} Z" fill="{colour[1]}"/>{lentils}'
            f'<ellipse cx="{f(cx)}" cy="{f(cy)}" rx="{f(rx)}" ry="{f(ry * 0.35)}" fill="none" stroke="#FFFFFF" stroke-width="3"/>')


def cardamom(s, x, y, size, a):
    return (f'<g transform="translate({f(x)} {f(y)}) rotate({f(a)})"><ellipse rx="{f(size)}" ry="{f(size * 0.55)}" fill="#7CB342"/>'
            f'<path d="M {f(-size * 0.8)},0 Q 0,{f(-size * 0.2)} {f(size * 0.8)},0" stroke="#33691E" stroke-width="1.4" fill="none"/>'
            f'<ellipse cx="{f(-size * 0.3)}" cy="{f(-size * 0.2)}" rx="{f(size * 0.3)}" ry="{f(size * 0.14)}" fill="#C5E1A5" opacity="0.7"/></g>')


def banner_essentials():
    s = SVG(W, H, seed=71)
    s.add(f'<rect width="{W}" height="{H}" fill="{s.lin([(0, "#FFF8E8"), (0.55, "#FFE8B8"), (1, "#FFD27F")], x1=0, y1=0, x2=1, y2=0.6)}"/>')
    s.add(f'<rect width="{W}" height="{H}" fill="{s.rad([(0, "#FFFFFF", 0.65), (1, "#FFFFFF", 0)], cx=790, cy=260, r=360, units="userSpaceOnUse")}"/>')
    s.add(kolam(s, 800, 270, 270, color='#C98A12', opacity=0.2, stroke=2.4, rings=3))
    s.add(banana_leaf(s, 800, 430, 620, 170, -6))
    s.add(uruli_with_pongal(s, 790, 380, 185))
    s.add(jaggery(s, 1010, 420, 55))
    s.add(dal_bowl(s, 610, 455, 70))
    rnd = s.rnd
    for x, y in [(570, 505), (600, 520), (1000, 500), (970, 512), (640, 512)]:
        s.add(cardamom(s, x, y, 12, rnd.uniform(-40, 40)))
    for x, y, r in [(640, 110, 12), (1030, 160, 10), (900, 90, 9), (590, 330, 8)]:
        s.add(sparkle(s, x, y, r, color='#FFFFFF', glow='#FFB300'))
    s.save(f'{OUT}/banner_essentials.svg')


def turmeric_plant(s, x, y, size):
    out = []
    for k, (lean, ln) in enumerate([(-40, 0.9), (-14, 1.1), (12, 1.05), (36, 0.85)]):
        L = size * ln
        a = math.radians(lean)
        ex, ey = x + math.sin(a) * L, y - math.cos(a) * L
        gl = s.lin([(0, '#2E7D32'), (1, '#9CCC65')], x1=0, y1=1, x2=0, y2=0)
        out.append(f'<path d="M {f(x - 6)},{f(y)} Q {f((x + ex) / 2 - size * 0.18)},{f((y + ey) / 2)} {f(ex)},{f(ey)} Q {f((x + ex) / 2 + size * 0.18)},{f((y + ey) / 2 + 10)} {f(x + 6)},{f(y)} Z" fill="{gl}"/>')
        out.append(f'<line x1="{f(x)}" y1="{f(y)}" x2="{f(ex)}" y2="{f(ey)}" stroke="#DCEDC8" stroke-opacity="0.6" stroke-width="1.6"/>')
    for i, dx in enumerate((-0.2, 0, 0.18, -0.08)):
        rx_ = size * 0.11
        out.append(f'<ellipse cx="{f(x + dx * size)}" cy="{f(y + size * (0.06 + i * 0.03))}" rx="{f(rx_)}" ry="{f(rx_ * 0.45)}" transform="rotate({f(-25 + i * 22)} {f(x + dx * size)} {f(y)})" fill="#F9A825" stroke="#9E5D00" stroke-width="1.2"/>')
    return ''.join(out)


def banana_bunch(s, x, y, size):
    out = []
    g = s.lin([(0, '#FFF176'), (0.6, '#FDD835'), (1, '#C9A100')], x1=0, y1=0, x2=1, y2=1)
    for k in range(6):
        a = -60 + k * 22
        ar = math.radians(a)
        bx, by = x + math.cos(ar) * size * 0.25, y + math.sin(ar) * size * 0.1
        out.append(f'<g transform="translate({f(bx)} {f(by)}) rotate({f(a + 90)})"><path d="M 0,0 C {f(size * 0.18)},{f(size * 0.2)} {f(size * 0.2)},{f(size * 0.7)} {f(size * 0.05)},{f(size * 0.95)} '
                   f'C {f(-size * 0.05)},{f(size * 0.7)} {f(-size * 0.04)},{f(size * 0.25)} 0,0 Z" fill="{g}" stroke="#A88600" stroke-width="1.2"/>'
                   f'<circle cx="{f(size * 0.05)}" cy="{f(size * 0.95)}" r="{f(size * 0.025)}" fill="#5D4037"/></g>')
    out.append(f'<rect x="{f(x - size * 0.05)}" y="{f(y - size * 0.18)}" width="{f(size * 0.1)}" height="{f(size * 0.2)}" rx="4" fill="#8D6E63"/>')
    return ''.join(out)


def pumpkin(s, cx, cy, r):
    out = [f'<ellipse cx="{f(cx + 6)}" cy="{f(cy + r * 0.8)}" rx="{f(r * 1.1)}" ry="{f(r * 0.2)}" fill="#0B1F0D" opacity="0.4" filter="{s.blur(6)}"/>']
    for k, dx in enumerate((-0.55, -0.25, 0.25, 0.55, 0)):
        g = s.rad([(0, '#FFB74D'), (0.7, '#F57C00'), (1, '#BF5000')], cx=0.4, cy=0.35, r=0.7)
        out.append(f'<ellipse cx="{f(cx + dx * r)}" cy="{f(cy)}" rx="{f(r * (0.42 if dx else 0.5))}" ry="{f(r * 0.72)}" fill="{g}"/>')
    out.append(f'<path d="M {f(cx)},{f(cy - r * 0.68)} q {f(r * 0.05)},{f(-r * 0.25)} {f(r * 0.2)},{f(-r * 0.3)}" stroke="#558B2F" stroke-width="{f(r * 0.1)}" fill="none" stroke-linecap="round"/>')
    return ''.join(out)


def brinjal(s, x, y, size, a):
    g = s.rad([(0, '#9575CD'), (0.6, '#5E35B1'), (1, '#311B92')], cx=0.35, cy=0.35, r=0.7)
    return (f'<g transform="translate({f(x)} {f(y)}) rotate({f(a)})"><ellipse rx="{f(size)}" ry="{f(size * 0.62)}" fill="{g}"/>'
            f'<path d="M {f(-size * 1.05)},{f(-size * 0.3)} Q {f(-size * 0.75)},0 {f(-size * 1.05)},{f(size * 0.3)} L {f(-size * 1.3)},0 Z" fill="#689F38"/>'
            f'<line x1="{f(-size * 1.3)}" y1="0" x2="{f(-size * 1.55)}" y2="{f(-size * 0.08)}" stroke="#558B2F" stroke-width="{f(size * 0.12)}" stroke-linecap="round"/>'
            f'<ellipse cx="{f(size * 0.1)}" cy="{f(-size * 0.28)}" rx="{f(size * 0.45)}" ry="{f(size * 0.12)}" fill="#FFFFFF" opacity="0.25"/></g>')


def banner_treats():
    """Pongal treats from the shelf: laddoos, murukku, jaggery, cashews (the store sells no fresh produce)."""
    s = SVG(W, H, seed=73)
    s.add(f'<rect width="{W}" height="{H}" fill="{s.lin([(0, "#0F2E14"), (0.5, "#1B4D22"), (1, "#2E6B2F")], x1=0, y1=0, x2=1, y2=0.8)}"/>')
    s.add(f'<rect width="{W}" height="{H}" fill="{s.rad([(0, "#FFD54F", 0.32), (1, "#FFD54F", 0)], cx=820, cy=220, r=380, units="userSpaceOnUse")}"/>')
    s.add(kolam(s, 820, 250, 280, color='#FFFFFF', opacity=0.12, stroke=2.4, rings=3))
    s.add(brass_plate(s, 800, 430, 230, 56))
    for x, y, r in [(730, 392, 40), (810, 386, 42), (890, 394, 40), (770, 340, 38), (850, 338, 38), (810, 292, 36)]:
        s.add(laddoo(s, x, y, r))
    s.add(murukku(s, 640, 452, 58))
    s.add(murukku(s, 990, 452, 54, turns=3.0))
    s.add(jaggery(s, 1000, 360, 34))
    rnd = s.rnd
    for x, y in [(600, 505), (660, 515), (940, 512), (1010, 505), (1050, 515)]:
        s.add(rnd.choice([cashew, raisin])(s, x, y, 15, rnd.uniform(-60, 60)))
    for x, y, r in [(600, 120, 10), (1040, 130, 9), (950, 70, 11)]:
        s.add(sparkle(s, x, y, r))
    s.save(f'{OUT}/banner_treats.svg')


def colour_bowl(s, cx, cy, rx, colour):
    ry = rx * 0.32
    bowl = s.lin([(0, '#D7CCC8'), (1, '#8D6E63')], x1=0, y1=0, x2=0, y2=1)
    return (f'<ellipse cx="{f(cx)}" cy="{f(cy + ry * 2)}" rx="{f(rx)}" ry="{f(ry * 0.4)}" fill="#3E2723" opacity="0.3" filter="{s.blur(5)}"/>'
            f'<path d="M {f(cx - rx)},{f(cy)} Q {f(cx)},{f(cy + ry * 3)} {f(cx + rx)},{f(cy)} Z" fill="{bowl}"/>'
            f'<path d="M {f(cx - rx * 0.92)},{f(cy)} Q {f(cx)},{f(cy - ry * 2.6)} {f(cx + rx * 0.92)},{f(cy)} Z" fill="{colour}"/>'
            f'<ellipse cx="{f(cx - rx * 0.25)}" cy="{f(cy - ry * 0.9)}" rx="{f(rx * 0.25)}" ry="{f(ry * 0.35)}" fill="#FFFFFF" opacity="0.3"/>')


def colour_kolam(s, cx, cy, R):
    """A filled kolam in festival colours, seen slightly from above."""
    cols = ['#E91E63', '#FFC107', '#43A047', '#1E88E5', '#FF7043', '#8E24AA']
    out = [f'<g transform="translate({f(cx)} {f(cy)}) scale(1 0.55)">', f'<circle r="{f(R * 1.08)}" fill="#3E2723" opacity="0.18" filter="{s.blur(10)}"/>']
    for k, (t, n) in enumerate([(1.0, 16), (0.76, 12), (0.52, 8)]):
        r = R * t
        for i in range(n):
            a = math.radians(i * 360 / n + k * 11)
            x, y = math.cos(a) * r * 0.78, math.sin(a) * r * 0.78
            out.append(f'<ellipse cx="{f(x)}" cy="{f(y)}" rx="{f(r * 0.24)}" ry="{f(r * 0.11)}" transform="rotate({f(math.degrees(a))} {f(x)} {f(y)})" fill="{cols[(i + k) % len(cols)]}" stroke="#FFFFFF" stroke-width="2.5"/>')
    out.append(f'<circle r="{f(R * 0.26)}" fill="#FFC107" stroke="#FFFFFF" stroke-width="3"/><circle r="{f(R * 0.12)}" fill="#E91E63"/>')
    for i in range(32):
        a = math.radians(i * 360 / 32)
        out.append(f'<circle cx="{f(math.cos(a) * R * 1.0)}" cy="{f(math.sin(a) * R * 1.0)}" r="4" fill="#FFFFFF"/>')
    out.append('</g>')
    return ''.join(out)


def banner_kolam():
    s = SVG(W, H, seed=79)
    s.add(f'<rect width="{W}" height="{H}" fill="{s.lin([(0, "#FFF6EC"), (0.6, "#FFE3CC"), (1, "#FFC9A6")], x1=0, y1=0, x2=1, y2=0.6)}"/>')
    s.add(f'<rect width="{W}" height="{H}" fill="{s.rad([(0, "#FFFFFF", 0.6), (1, "#FFFFFF", 0)], cx=800, cy=280, r=360, units="userSpaceOnUse")}"/>')
    s.add(kolam(s, 820, 250, 260, color='#E07B53', opacity=0.18, stroke=2.2, rings=3))
    s.add(colour_kolam(s, 800, 330, 200))
    for (x, y, c) in [(600, 470, '#E91E63'), (690, 500, '#FFC107'), (930, 500, '#43A047'), (1015, 465, '#1E88E5')]:
        s.add(colour_bowl(s, x, y, 46, c))
    for x, y in [(655, 220), (980, 210), (720, 160)]:
        s.add(aavaram(s, x, y, 15, rot=x))
    s.add(poolai(s, 1030, 330, 16))
    for x, y, r in [(620, 120, 10), (1040, 130, 9), (900, 80, 11)]:
        s.add(sparkle(s, x, y, r, color='#FFFFFF', glow='#FF8A65'))
    s.save(f'{OUT}/banner_kolam.svg')


def btn_tile():
    """Seamless kolam-dot tile for festive buttons: 192 × 192 (64 dp)."""
    s = SVG(192, 192, seed=83)
    out = []
    for i in range(4):
        for j in range(4):
            x, y = 24 + i * 48, 24 + j * 48
            out.append(f'<circle cx="{x}" cy="{y}" r="2.2" fill="#FFF3D6" opacity="0.55"/>')
            if (i + j) % 2 == 0:
                out.append(f'<path d="M {x - 12},{y} Q {x},{y - 13} {x + 12},{y} Q {x},{y + 13} {x - 12},{y} Z" fill="none" stroke="#FFF3D6" stroke-opacity="0.3" stroke-width="1.6"/>')
    s.add(''.join(out))
    s.save(f'{OUT}/btn_tile.svg')


def section_icon():
    s = SVG(96, 96, seed=89)
    s.add(sugarcane(s, 26, 90, 70, -14, width=7, leaf_scale=0.5))
    s.add(sugarcane(s, 70, 90, 70, 14, width=7, leaf_scale=0.5))
    s.add(pot(s, 48, 86, 56, leaf_scale=0.55))
    s.save(f'{OUT}/section_icon.svg')


def petals():
    s = SVG(48, 48, seed=3); s.add(aavaram(s, 24, 24, 19)); s.save(f'{OUT}/petal_1.svg')
    s = SVG(48, 48, seed=4); s.add(poolai(s, 24, 24, 16)); s.save(f'{OUT}/petal_2.svg')
    s = SVG(48, 48, seed=5)
    g = s.rad([(0, '#FFB74D'), (1, '#E65100')], cx=0.35, cy=0.35, r=0.75)
    s.add(f'<path d="M 24,4 C 38,8 44,22 36,36 C 30,44 18,44 12,36 C 4,22 10,8 24,4 Z" fill="{g}"/>'); s.save(f'{OUT}/petal_3.svg')
    s = SVG(72, 72, seed=6)
    s.add('<path d="M 36,6 C 52,20 54,46 36,66 C 18,46 20,20 36,6 Z" fill="#43A047"/><path d="M 36,10 L 36,64" stroke="#C5E1A5" stroke-width="2"/>')
    s.save(f'{OUT}/petal_4.svg')


if __name__ == '__main__':
    banner_essentials()
    banner_treats()
    banner_kolam()
    btn_tile()
    section_icon()
    petals()
    print('ok')
