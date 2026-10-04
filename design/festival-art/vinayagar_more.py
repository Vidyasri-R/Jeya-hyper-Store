"""Vinayagar Chathurthi banners, button texture, section icon and falling sprites (out/vinayagar/)."""
import math

from svgkit import *
from banners import basket, brass_plate, jasmine_string, kuthuvilakku
from pongal_art import sugarcane
from pongal_more import banana_bunch, banana_leaf, jaggery
from vinayagar_art import OUT, arugampul, erukku, kozhukattai, kudai, warm

W, H = 1080, 540


def erukku_garland(s, x0, x1, y, sag, n):
    out = [f'<path d="M {f(x0)},{f(y)} Q {f((x0 + x1) / 2)},{f(y + 2 * sag)} {f(x1)},{f(y)}" stroke="#6D4C41" stroke-width="2" fill="none"/>']
    for i in range(n):
        t = (i + 0.5) / n
        x = (1 - t) ** 2 * x0 + 2 * (1 - t) * t * (x0 + x1) / 2 + t * t * x1
        yy = (1 - t) ** 2 * y + 2 * (1 - t) * t * (y + 2 * sag) + t * t * y
        out.append(marigold(s, x, yy, 11, 'orange') if i % 3 == 1 else erukku(s, x, yy, 12, rot=i * 17))
    return ''.join(out)


def coconut_half(s, cx, cy, r):
    return (f'<ellipse cx="{f(cx + 4)}" cy="{f(cy + r * 0.5)}" rx="{f(r)}" ry="{f(r * 0.3)}" fill="#3A1200" opacity="0.3" filter="{s.blur(5)}"/>'
            f'<path d="M {f(cx - r)},{f(cy)} A {f(r)},{f(r * 0.9)} 0 0 0 {f(cx + r)},{f(cy)} Z" fill="{s.lin([(0, "#8D5A2B"), (1, "#5A3416")], x1=0, y1=0, x2=0, y2=1)}"/>'
            f'<ellipse cx="{f(cx)}" cy="{f(cy)}" rx="{f(r)}" ry="{f(r * 0.32)}" fill="#6D4423"/>'
            f'<ellipse cx="{f(cx)}" cy="{f(cy)}" rx="{f(r * 0.86)}" ry="{f(r * 0.26)}" fill="#FFFDF5"/>')


def grated_coconut(s, cx, cy, rx):
    rnd = s.rnd
    out = [f'<ellipse cx="{f(cx)}" cy="{f(cy)}" rx="{f(rx)}" ry="{f(rx * 0.3)}" fill="#FFFDF5"/>']
    for _ in range(40):
        x, y = cx + rnd.uniform(-rx * 0.85, rx * 0.85), cy + rnd.uniform(-rx * 0.22, rx * 0.2)
        out.append(f'<path d="M {f(x)},{f(y)} l {f(rnd.uniform(-4, 4))},{f(rnd.uniform(-3, 3))}" stroke="#E8E2D2" stroke-width="1.6" stroke-linecap="round"/>')
    return ''.join(out)


def banner_kozhukattai():
    s = SVG(W, H, seed=511)
    s.add(f'<rect width="{W}" height="{H}" fill="{s.lin([(0, "#FFFAF2"), (0.55, "#FFEBD2"), (1, "#FFD8AE")], x1=0, y1=0, x2=1, y2=0.6)}"/>')
    s.add(f'<rect width="{W}" height="{H}" fill="{s.rad([(0, "#FFFFFF", 0.7), (1, "#FFFFFF", 0)], cx=800, cy=260, r=380, units="userSpaceOnUse")}"/>')
    s.add(mandala(s, 820, 270, 320, color='#E0861A', opacity=0.2, stroke=2.2, fill_opacity=0.05))
    s.add(erukku_garland(s, 570, 1070, 18, 30, 18))
    s.add(banana_leaf(s, 820, 420, 520, 190, -6))
    heap = [(720, 410, 62, False, -6), (790, 416, 66, True, 4), (860, 412, 62, False, 6), (752, 360, 60, False, -3), (826, 356, 60, True, 4), (790, 306, 58, False, 0)]
    for x, y, sz, fried, a in heap:
        s.add(kozhukattai(s, x, y, sz, fried, a))
    s.add(coconut_half(s, 990, 440, 52))
    s.add(jaggery(s, 640, 462, 40))
    s.add(grated_coconut(s, 960, 500, 44))
    for x, y, r in [(640, 120, 11), (1030, 200, 10), (700, 70, 8)]:
        s.add(sparkle(s, x, y, r, color='#FFFFFF', glow='#FFB300'))
    s.save(f'{OUT}/banner_kozhukattai.svg')


def banner_pooja():
    s = SVG(W, H, seed=513)
    warm(s, W, H, glow=(820, 240, 420))
    s.add(mandala(s, 820, 250, 320, color='#FFD54F', opacity=0.15, stroke=2.2))
    s.add(jasmine_string(s, 580, 36, 1050, 36, 50, 24))
    s.add(kudai(s, 840, 70, 200))
    s.add(kuthuvilakku(s, 660, 500, 330))
    s.add(brass_plate(s, 880, 470, 130, 32))
    for x, y in [(840, 440), (880, 432), (920, 442)]:
        s.add(kozhukattai(s, x, y, 40, x == 880))
    for i, (x, y) in enumerate([(780, 505), (820, 515), (940, 512), (985, 500), (1030, 508)]):
        s.add(erukku(s, x, y, 15, rot=i * 20) if i % 2 == 0 else marigold(s, x, y, 15, 'orange'))
    s.add(diya(s, 1010, 440, 70, style=1))
    for x, y, r in [(600, 150, 10), (1040, 200, 9), (950, 300, 8)]:
        s.add(sparkle(s, x, y, r))
    s.save(f'{OUT}/banner_pooja.svg')


def wood_apple(s, cx, cy, r):
    """Vilam pazham: a hard round brown fruit."""
    return (f'<circle cx="{f(cx + r * 0.08)}" cy="{f(cy + r * 0.12)}" r="{f(r)}" fill="#2A1400" opacity="0.3" filter="{s.blur(r * 0.12)}"/>'
            f'<circle cx="{f(cx)}" cy="{f(cy)}" r="{f(r)}" fill="{s.rad([(0, "#C9B79A"), (0.6, "#9C8664"), (1, "#6D5A3C")], cx=0.38, cy=0.32, r=0.75)}"/>'
            f'<circle cx="{f(cx)}" cy="{f(cy - r)}" r="{f(r * 0.1)}" fill="#5D4A2E"/>'
            f'<ellipse cx="{f(cx - r * 0.35)}" cy="{f(cy - r * 0.4)}" rx="{f(r * 0.25)}" ry="{f(r * 0.14)}" fill="#FFFFFF" opacity="0.3"/>')


def apple(s, cx, cy, r):
    return (f'<circle cx="{f(cx + r * 0.08)}" cy="{f(cy + r * 0.12)}" r="{f(r)}" fill="#2A0000" opacity="0.3" filter="{s.blur(r * 0.12)}"/>'
            f'<path d="M {f(cx)},{f(cy - r * 0.7)} C {f(cx + r * 0.9)},{f(cy - r * 1.2)} {f(cx + r * 1.3)},{f(cy + r * 0.2)} {f(cx + r * 0.4)},{f(cy + r * 0.95)} '
            f'C {f(cx + r * 0.15)},{f(cy + r * 1.05)} {f(cx - r * 0.15)},{f(cy + r * 1.05)} {f(cx - r * 0.4)},{f(cy + r * 0.95)} C {f(cx - r * 1.3)},{f(cy + r * 0.2)} {f(cx - r * 0.9)},{f(cy - r * 1.2)} {f(cx)},{f(cy - r * 0.7)} Z" '
            f'fill="{s.rad([(0, "#FF8A80"), (0.6, "#E53935"), (1, "#8E0000")], cx=0.38, cy=0.35, r=0.75)}"/>'
            f'<path d="M {f(cx)},{f(cy - r * 0.7)} q {f(r * 0.05)},{f(-r * 0.3)} {f(r * 0.2)},{f(-r * 0.4)}" stroke="#5D4037" stroke-width="{f(r * 0.1)}" fill="none" stroke-linecap="round"/>'
            f'<ellipse cx="{f(cx - r * 0.4)}" cy="{f(cy - r * 0.25)}" rx="{f(r * 0.18)}" ry="{f(r * 0.28)}" fill="#FFFFFF" opacity="0.35"/>')


def banner_fruits():
    s = SVG(W, H, seed=517)
    s.add(f'<rect width="{W}" height="{H}" fill="{s.lin([(0, "#F6FBF2"), (0.55, "#E8F5DC"), (1, "#D3EBC0")], x1=0, y1=0, x2=1, y2=0.6)}"/>')
    s.add(f'<rect width="{W}" height="{H}" fill="{s.rad([(0, "#FFFFFF", 0.7), (1, "#FFFFFF", 0)], cx=800, cy=260, r=380, units="userSpaceOnUse")}"/>')
    s.add(mandala(s, 820, 270, 320, color='#7CB342', opacity=0.18, stroke=2.2, fill_opacity=0.04))
    s.add(sugarcane(s, 690, 520, 400, -6, width=26, leaf_scale=0.8))
    s.add(sugarcane(s, 1010, 520, 400, 12, width=24, leaf_scale=0.8))
    s.add(banana_bunch(s, 700, 300, 120))
    for (x, y, r) in [(760, 300, 30), (830, 296, 32), (900, 302, 30), (795, 262, 28), (865, 260, 28)]:
        s.add(apple(s, x, y, r) if (x // 10) % 2 else wood_apple(s, x, y, r))
    s.add(basket(s, 820, 310, 300, 160))
    s.add(erukku_garland(s, 680, 960, 330, 18, 10))
    for x, y, r in [(640, 120, 10), (1030, 150, 9)]:
        s.add(sparkle(s, x, y, r, color='#FFFFFF', glow='#7CB342'))
    s.save(f'{OUT}/banner_fruits.svg')


def btn_tile():
    """Seamless tile of little erukku outlines for festive buttons: 192 × 192 (64 dp)."""
    s = SVG(192, 192, seed=519)
    out = []
    for x, y in ((48, 48), (144, 144)):
        pts = []
        for i in range(10):
            a = math.radians(-90 + i * 36)
            r = 13 if i % 2 == 0 else 5
            pts.append(f'{f(x + math.cos(a) * r)},{f(y + math.sin(a) * r)}')
        out.append(f'<polygon points="{" ".join(pts)}" fill="none" stroke="#FFF3E0" stroke-opacity="0.45" stroke-width="1.6"/>')
    for x, y in ((144, 48), (48, 144)):
        out.append(f'<circle cx="{x}" cy="{y}" r="2.4" fill="#FFF3E0" opacity="0.45"/>')
    s.add(''.join(out))
    s.save(f'{OUT}/btn_tile.svg')


def section_icon():
    s = SVG(96, 96, seed=521)
    s.add(f'<ellipse cx="48" cy="80" rx="40" ry="9" fill="#43A047"/><path d="M 10,80 Q 48,72 86,80" stroke="#C5E1A5" stroke-width="2" fill="none"/>')
    s.add(kozhukattai(s, 48, 54, 56))
    s.save(f'{OUT}/section_icon.svg')


def petals():
    s = SVG(48, 48, seed=3); s.add(erukku(s, 24, 24, 19)); s.save(f'{OUT}/petal_1.svg')
    for name, col in (('petal_2', ('#FFB74D', '#E65100')), ('petal_3', ('#FFF59D', '#F9A825'))):
        s = SVG(48, 48, seed=5)
        g = s.rad([(0, col[0]), (1, col[1])], cx=0.35, cy=0.35, r=0.75)
        s.add(f'<path d="M 24,4 C 38,8 44,22 36,36 C 30,44 18,44 12,36 C 4,22 10,8 24,4 Z" fill="{g}"/>')
        s.save(f'{OUT}/{name}.svg')
    s = SVG(72, 72, seed=6); s.add(arugampul(s, 36, 6, 60)); s.save(f'{OUT}/petal_4.svg')


if __name__ == '__main__':
    banner_kozhukattai()
    banner_pooja()
    banner_fruits()
    btn_tile()
    section_icon()
    petals()
    print('ok')
