"""Navaratri & Ayudha Pooja banners, button texture, section icon and falling sprites (out/navaratri/)."""
import math

from svgkit import *
from banners import brass_plate
from pongal_more import banana_bunch, jaggery
from puthandu_art import betel, kanakambaram, lotus_kolam, malli
from puthandu_more import coconut
from navaratri_art import OUT, SILKS, doll, kalasam, pennant, plum

W, H = 1080, 540


def bunting(s, x0, x1, y, sag, n):
    out = [f'<path d="M {f(x0)},{f(y)} Q {f((x0 + x1) / 2)},{f(y + 2 * sag)} {f(x1)},{f(y)}" stroke="#C98A12" stroke-width="2" fill="none"/>']
    for i in range(n):
        t = (i + 0.5) / n
        x = (1 - t) ** 2 * x0 + 2 * (1 - t) * t * (x0 + x1) / 2 + t * t * x1
        yy = (1 - t) ** 2 * y + 2 * (1 - t) * t * (y + 2 * sag) + t * t * y
        out.append(pennant(s, x, yy, 22, 34, SILKS[i % len(SILKS)]))
    return ''.join(out)


def donnai(s, cx, cy, rx):
    """A leaf cup (donnai) of sundal: chickpeas, grated coconut, mustard seeds and curry leaves."""
    ry = rx * 0.32
    rnd = s.rnd
    out = [f'<ellipse cx="{f(cx + 4)}" cy="{f(cy + ry * 2.3)}" rx="{f(rx * 0.9)}" ry="{f(ry * 0.5)}" fill="#2A0A1E" opacity="0.3" filter="{s.blur(6)}"/>']
    beans = []
    for _ in range(int(rx * 0.9)):
        x = cx + rnd.uniform(-rx * 0.85, rx * 0.85)
        dome = 1 - ((x - cx) / rx) ** 2
        y = cy - rnd.uniform(0, rx * 0.4) * max(0.2, dome)
        beans.append((y, x))
    beans.sort()
    for y, x in beans:
        r = rx * 0.09
        out.append(f'<circle cx="{f(x)}" cy="{f(y)}" r="{f(r)}" fill="{s.rad([(0, "#F3D9A0"), (1, "#C49A52")], cx=0.38, cy=0.35, r=0.7)}" stroke="#A67C38" stroke-width="0.6"/>')
    for _ in range(14):
        x, y = cx + rnd.uniform(-rx * 0.7, rx * 0.7), cy - rnd.uniform(0, rx * 0.3)
        out.append(f'<path d="M {f(x)},{f(y)} l {f(rnd.uniform(-5, 5))},{f(rnd.uniform(-3, 3))}" stroke="#FFFDF5" stroke-width="2.2" stroke-linecap="round"/>')
    for _ in range(10):
        out.append(f'<circle cx="{f(cx + rnd.uniform(-rx * 0.7, rx * 0.7))}" cy="{f(cy - rnd.uniform(0, rx * 0.3))}" r="1.6" fill="#2B1A12"/>')
    for k in range(3):
        x, y = cx + (k - 1) * rx * 0.4, cy - rx * 0.25
        out.append(f'<ellipse cx="{f(x)}" cy="{f(y)}" rx="{f(rx * 0.12)}" ry="{f(rx * 0.05)}" transform="rotate({f(-30 + k * 30)} {f(x)} {f(y)})" fill="#2E7D32"/>')
    leaf = s.lin([(0, '#6D8B3A'), (1, '#3E5A1E')], x1=0, y1=0, x2=1, y2=1)
    out.append(f'<path d="M {f(cx - rx)},{f(cy)} L {f(cx - rx * 0.7)},{f(cy + ry * 2.1)} L {f(cx + rx * 0.7)},{f(cy + ry * 2.1)} L {f(cx + rx)},{f(cy)} Q {f(cx)},{f(cy + ry * 0.8)} {f(cx - rx)},{f(cy)} Z" fill="{leaf}"/>')
    for k in range(-3, 4):
        out.append(f'<line x1="{f(cx + k * rx * 0.25)}" y1="{f(cy + ry * 0.4)}" x2="{f(cx + k * rx * 0.2)}" y2="{f(cy + ry * 2.05)}" stroke="#A5C17A" stroke-opacity="0.5" stroke-width="1.2"/>')
    return ''.join(out)


def banner_sundal():
    s = SVG(W, H, seed=611)
    s.add(f'<rect width="{W}" height="{H}" fill="{s.lin([(0, "#FFF8FB"), (0.55, "#FFE4F0"), (1, "#FFCCE2")], x1=0, y1=0, x2=1, y2=0.6)}"/>')
    s.add(f'<rect width="{W}" height="{H}" fill="{s.rad([(0, "#FFFFFF", 0.7), (1, "#FFFFFF", 0)], cx=800, cy=260, r=380, units="userSpaceOnUse")}"/>')
    s.add(lotus_kolam(s, 820, 270, 320, color='#D6338A', opacity=0.18, stroke=2.2))
    s.add(bunting(s, 560, 1080, 18, 26, 16))
    s.add(doll(s, 1010, 330, 120, '#43A047', 1))
    s.add(doll(s, 940, 340, 110, '#E91E63', 0))
    s.add(donnai(s, 760, 410, 120))
    s.add(donnai(s, 920, 460, 80))
    s.add(donnai(s, 620, 470, 70))
    for x, y, r in [(640, 130, 11), (880, 120, 9), (600, 300, 8)]:
        s.add(sparkle(s, x, y, r, color='#FFFFFF', glow='#FF80AB'))
    s.save(f'{OUT}/banner_sundal.svg')


def ash_gourd(s, cx, cy, rx):
    """Poosanikai (ash gourd) for Ayudha Pooja: pale and powdery, kumkum on top, camphor burning."""
    ry = rx * 0.62
    out = [f'<ellipse cx="{f(cx + 6)}" cy="{f(cy + ry * 0.9)}" rx="{f(rx)}" ry="{f(ry * 0.2)}" fill="#12020C" opacity="0.4" filter="{s.blur(8)}"/>',
           f'<ellipse cx="{f(cx)}" cy="{f(cy)}" rx="{f(rx)}" ry="{f(ry)}" fill="{s.rad([(0, "#F1F8E9"), (0.55, "#C5D9B4"), (1, "#7E9C6A")], cx=0.38, cy=0.32, r=0.75)}"/>']
    for k in range(-3, 4):
        out.append(f'<path d="M {f(cx + k * rx * 0.25)},{f(cy - ry * 0.95)} Q {f(cx + k * rx * 0.32)},{f(cy)} {f(cx + k * rx * 0.25)},{f(cy + ry * 0.95)}" stroke="#7E9C6A" stroke-opacity="0.35" stroke-width="2" fill="none"/>')
    out.append(f'<ellipse cx="{f(cx)}" cy="{f(cy - ry * 0.55)}" rx="{f(rx * 0.22)}" ry="{f(ry * 0.12)}" fill="#C62828"/>')
    out.append(f'<ellipse cx="{f(cx)}" cy="{f(cy - ry * 0.62)}" rx="{f(rx * 0.1)}" ry="{f(ry * 0.06)}" fill="#FFFFFF"/>')
    out.append(flame(s, cx, cy - ry * 0.64, rx * 0.12, rx * 0.32))
    out.append(f'<ellipse cx="{f(cx - rx * 0.4)}" cy="{f(cy - ry * 0.3)}" rx="{f(rx * 0.2)}" ry="{f(ry * 0.3)}" fill="#FFFFFF" opacity="0.3"/>')
    return ''.join(out)


def pori_plate(s, cx, cy, rx):
    rnd = s.rnd
    out = [brass_plate(s, cx, cy, rx, rx * 0.24)]
    pieces = []
    for _ in range(140):
        x = cx + rnd.uniform(-rx * 0.75, rx * 0.75)
        dome = 1 - ((x - cx) / (rx * 0.8)) ** 2
        y = cy - rnd.uniform(0, rx * 0.4) * max(0.1, dome)
        pieces.append((y, x))
    pieces.sort()
    for y, x in pieces:
        if rnd.random() < 0.18:
            out.append(f'<circle cx="{f(x)}" cy="{f(y)}" r="{f(rx * 0.035)}" fill="{s.rad([(0, "#E8B66B"), (1, "#9C5B1E")], cx=0.38, cy=0.35, r=0.7)}"/>')
        else:
            out.append(f'<ellipse cx="{f(x)}" cy="{f(y)}" rx="{f(rx * 0.04)}" ry="{f(rx * 0.026)}" transform="rotate({f(rnd.uniform(0, 180))} {f(x)} {f(y)})" fill="#FFFDF5" stroke="#E2D8C0" stroke-width="0.6"/>')
    return ''.join(out)


def banner_ayudha():
    s = SVG(W, H, seed=613)
    plum(s, W, H, glow=(820, 260, 420))
    s.add(lotus_kolam(s, 820, 270, 300, opacity=0.12))
    s.add(bunting(s, 560, 1080, 18, 24, 16))
    s.add(ash_gourd(s, 690, 420, 110))
    s.add(banana_bunch(s, 1040, 440, 92))
    s.add(pori_plate(s, 880, 450, 140))
    s.add(jaggery(s, 980, 490, 36))
    for i, x in enumerate((600, 640, 780, 1040)):
        s.add(marigold(s, x, 508, 16, ['orange', 'yellow', 'deep'][i % 3]))
    for x, y, r in [(620, 140, 10), (1040, 160, 9), (900, 260, 8)]:
        s.add(sparkle(s, x, y, r))
    s.save(f'{OUT}/banner_ayudha.svg')


def thamboolam_bag(s, cx, base_y, w):
    """A cloth thamboolam bag with gold trim, betel leaves, a banana and a coconut peeking out."""
    h = w * 0.9
    top = base_y - h
    cloth = s.lin([(0, '#F06292'), (0.5, '#D81B60'), (1, '#880E4F')], x1=0, y1=0, x2=1, y2=1)
    out = [betel(s, cx - w * 0.15, top + h * 0.1, w * 0.4, -20), betel(s, cx + w * 0.05, top + h * 0.08, w * 0.42, 12),
           coconut(s, cx + w * 0.22, top + h * 0.02, w * 0.16)]
    out.append(f'<ellipse cx="{f(cx + 6)}" cy="{f(base_y + 4)}" rx="{f(w * 0.5)}" ry="{f(h * 0.06)}" fill="#2A0A1E" opacity="0.3" filter="{s.blur(6)}"/>')
    out.append(f'<path d="M {f(cx - w * 0.42)},{f(top + h * 0.12)} L {f(cx + w * 0.42)},{f(top + h * 0.12)} L {f(cx + w * 0.5)},{f(base_y)} L {f(cx - w * 0.5)},{f(base_y)} Z" fill="{cloth}"/>')
    out.append(f'<rect x="{f(cx - w * 0.43)}" y="{f(top + h * 0.12)}" width="{f(w * 0.86)}" height="{f(h * 0.08)}" fill="#FFD54F"/>')
    out.append(f'<rect x="{f(cx - w * 0.48)}" y="{f(base_y - h * 0.14)}" width="{f(w * 0.96)}" height="{f(h * 0.06)}" fill="#FFD54F"/>')
    out.append(f'<path d="M {f(cx - w * 0.3)},{f(top + h * 0.16)} Q {f(cx - w * 0.3)},{f(top - h * 0.18)} {f(cx)},{f(top - h * 0.2)} Q {f(cx + w * 0.3)},{f(top - h * 0.18)} {f(cx + w * 0.3)},{f(top + h * 0.16)}" stroke="#FFD54F" stroke-width="{f(w * 0.03)}" fill="none"/>')
    for i in range(-2, 3):
        out.append(f'<circle cx="{f(cx + i * w * 0.16)}" cy="{f(top + h * 0.55)}" r="{f(w * 0.04)}" fill="#FFD54F" opacity="0.85"/>')
    return ''.join(out)


def kumkum_box(s, cx, cy, r, colour):
    return (f'<ellipse cx="{f(cx)}" cy="{f(cy + r * 0.5)}" rx="{f(r)}" ry="{f(r * 0.35)}" fill="#6B4300"/>'
            f'<rect x="{f(cx - r)}" y="{f(cy - r * 0.2)}" width="{f(r * 2)}" height="{f(r * 0.7)}" fill="#C98A12"/>'
            f'<ellipse cx="{f(cx)}" cy="{f(cy - r * 0.2)}" rx="{f(r)}" ry="{f(r * 0.35)}" fill="#FFE7A0"/>'
            f'<ellipse cx="{f(cx)}" cy="{f(cy - r * 0.22)}" rx="{f(r * 0.8)}" ry="{f(r * 0.26)}" fill="{colour}"/>')


def banner_thamboolam():
    s = SVG(W, H, seed=617)
    s.add(f'<rect width="{W}" height="{H}" fill="{s.lin([(0, "#FFFBF2"), (0.55, "#FFF0D6"), (1, "#FFE2B0")], x1=0, y1=0, x2=1, y2=0.6)}"/>')
    s.add(f'<rect width="{W}" height="{H}" fill="{s.rad([(0, "#FFFFFF", 0.7), (1, "#FFFFFF", 0)], cx=800, cy=260, r=380, units="userSpaceOnUse")}"/>')
    s.add(lotus_kolam(s, 820, 270, 320, color='#E0861A', opacity=0.2, stroke=2.2))
    s.add(bunting(s, 560, 1080, 18, 24, 16))
    s.add(thamboolam_bag(s, 800, 500, 260))
    s.add(kumkum_box(s, 620, 480, 30, '#C62828'))
    s.add(kumkum_box(s, 690, 500, 26, '#F9C02D'))
    s.add(banana_bunch(s, 1040, 440, 88))
    for i, x in enumerate((960, 1000, 1040)):
        s.add(malli(s, x, 505, 9, rot=i * 20) if i % 2 else kanakambaram(s, x, 505, 10))
    for x, y, r in [(640, 130, 11), (1030, 220, 9)]:
        s.add(sparkle(s, x, y, r, color='#FFFFFF', glow='#FFB300'))
    s.save(f'{OUT}/banner_thamboolam.svg')


def btn_tile():
    """Seamless tile of little kolam dots and loops for festive buttons: 192 × 192 (64 dp)."""
    s = SVG(192, 192, seed=619)
    out = []
    for x, y in ((48, 48), (144, 144)):
        out.append(f'<circle cx="{x}" cy="{y}" r="2.4" fill="#FFF3C4" opacity="0.5"/>')
        out.append(f'<path d="M {x - 13},{y} Q {x},{y - 14} {x + 13},{y} Q {x},{y + 14} {x - 13},{y} Z" fill="none" stroke="#FFF3C4" stroke-opacity="0.35" stroke-width="1.6"/>')
    for x, y in ((144, 48), (48, 144)):
        out.append(f'<circle cx="{x}" cy="{y}" r="2.2" fill="#FFF3C4" opacity="0.45"/>')
    s.add(''.join(out))
    s.save(f'{OUT}/btn_tile.svg')


def section_icon():
    s = SVG(96, 96, seed=621)
    s.add(kalasam(s, 48, 92, 70))
    s.save(f'{OUT}/section_icon.svg')


def petals():
    for name, col in (('petal_1', ('#FFB74D', '#E65100')), ('petal_2', ('#F8BBD0', '#D81B60'))):
        s = SVG(48, 48, seed=5)
        g = s.rad([(0, col[0]), (1, col[1])], cx=0.35, cy=0.35, r=0.75)
        s.add(f'<path d="M 24,4 C 38,8 44,22 36,36 C 30,44 18,44 12,36 C 4,22 10,8 24,4 Z" fill="{g}"/>')
        s.save(f'{OUT}/{name}.svg')
    s = SVG(48, 48, seed=6); s.add(malli(s, 24, 24, 19)); s.save(f'{OUT}/petal_3.svg')
    s = SVG(72, 72, seed=7); s.add(marigold(s, 36, 36, 28, 'yellow')); s.save(f'{OUT}/petal_4.svg')


if __name__ == '__main__':
    banner_sundal()
    banner_ayudha()
    banner_thamboolam()
    btn_tile()
    section_icon()
    petals()
    print('ok')
