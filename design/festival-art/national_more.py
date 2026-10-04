"""Independence & Republic Day banners, button texture, section icon and falling sprites (out/national/)."""
import math

from svgkit import *
from banners import basket, brass_plate, laddoo
from christmas_art import firework
from christmas_more import bottle, chips_bowl
from national_art import GREEN, OUT, SAFFRON, TRI, WHITE, balloon, barfi, navy, pennant, rosette, tri_confetti

W, H = 1080, 540


def bunting(s, x0, x1, y, sag, n, w=24, h=32):
    out = [f'<path d="M {f(x0)},{f(y)} Q {f((x0 + x1) / 2)},{f(y + 2 * sag)} {f(x1)},{f(y)}" stroke="#9AA6BF" stroke-width="1.6" fill="none"/>']
    for i in range(n):
        t = (i + 0.5) / n
        x = (1 - t) ** 2 * x0 + 2 * (1 - t) * t * (x0 + x1) / 2 + t * t * x1
        yy = (1 - t) ** 2 * y + 2 * (1 - t) * t * (y + 2 * sag) + t * t * y
        out.append(pennant(s, x, yy, w, h, TRI[i % 3]))
    return ''.join(out)


def banner_sweets():
    s = SVG(W, H, seed=411)
    s.add(f'<rect width="{W}" height="{H}" fill="{s.lin([(0, "#FFFBF4"), (0.55, "#FFEFD9"), (1, "#FFE0BC")], x1=0, y1=0, x2=1, y2=0.6)}"/>')
    s.add(f'<rect width="{W}" height="{H}" fill="{s.rad([(0, "#FFFFFF", 0.7), (1, "#FFFFFF", 0)], cx=800, cy=260, r=380, units="userSpaceOnUse")}"/>')
    s.add(bunting(s, 560, 1080, 20, 26, 16))
    s.add(brass_plate(s, 790, 452, 185, 46))
    for (x, y, a) in [(700, 420, -8), (752, 412, 4), (806, 414, -4), (726, 372, 6), (780, 366, -6), (752, 326, 2)]:
        s.add(barfi(s, x, y, 52, 40, a))
    for (x, y, r) in [(880, 424, 34), (858, 380, 31), (912, 384, 30), (884, 342, 29)]:
        s.add(laddoo(s, x, y, r))
    for x, y, k in [(600, 500, 'orange'), (640, 512, 'yellow'), (960, 506, 'orange'), (1000, 498, 'yellow')]:
        s.add(marigold(s, x, y, 19, k))
    s.add(balloon(s, 1010, 170, 40, SAFFRON, string_to=(1000, 330)))
    s.add(balloon(s, 960, 210, 34, GREEN, string_to=(1000, 330)))
    for x, y, r in [(640, 130, 11), (900, 120, 9), (600, 300, 8)]:
        s.add(sparkle(s, x, y, r, color='#FFFFFF', glow='#FFB766'))
    s.save(f'{OUT}/banner_sweets.svg')


def banner_snacks():
    s = SVG(W, H, seed=413)
    navy(s, W, H, glow=(820, 260, 420))
    for (x, y, R, c) in [(700, 120, 90, SAFFRON), (960, 150, 100, '#3DDC4F'), (840, 70, 60, WHITE)]:
        s.add(firework(s, x, y, R, colour=c, opacity=0.45, rays=20))
    s.add(tri_confetti(s, 560, 1070, 20, 520, 40))
    s.add(bottle(s, 640, 500, 190, liquid='#3E1A0E', label=SAFFRON))
    s.add(bottle(s, 1010, 500, 180, liquid='#FF8F1F', label=GREEN))   # orange soft drink
    s.add(chips_bowl(s, 820, 400, 150))
    for x, y, r in [(600, 230, 10), (1040, 260, 9)]:
        s.add(sparkle(s, x, y, r))
    s.save(f'{OUT}/banner_snacks.svg')


def oil_tin(s, cx, base_y, w):
    h = w * 1.3
    g = s.lin([(0, '#C9CED8'), (0.45, '#F4F6FA'), (1, '#9AA1AE')], x1=0, y1=0, x2=1, y2=0)
    return (f'<rect x="{f(cx - w / 2)}" y="{f(base_y - h)}" width="{f(w)}" height="{f(h)}" rx="6" fill="{g}"/>'
            f'<rect x="{f(cx - w / 2)}" y="{f(base_y - h * 0.68)}" width="{f(w)}" height="{f(h * 0.4)}" fill="{SAFFRON}"/>'
            f'<rect x="{f(cx - w / 2)}" y="{f(base_y - h * 0.42)}" width="{f(w)}" height="{f(h * 0.12)}" fill="{GREEN}"/>'
            f'<circle cx="{f(cx)}" cy="{f(base_y - h * 0.55)}" r="{f(w * 0.16)}" fill="#FFF8E1"/>'
            f'<rect x="{f(cx + w * 0.12)}" y="{f(base_y - h - w * 0.14)}" width="{f(w * 0.22)}" height="{f(w * 0.16)}" rx="3" fill="#B0B6C2"/>')


def rice_bag(s, cx, base_y, w):
    h = w * 1.2
    return (f'<path d="M {f(cx - w / 2)},{f(base_y)} L {f(cx - w * 0.44)},{f(base_y - h)} L {f(cx + w * 0.44)},{f(base_y - h)} L {f(cx + w / 2)},{f(base_y)} Z" fill="{s.lin([(0, "#FFFFFF"), (1, "#E3E8F0")], x1=0, y1=0, x2=1, y2=1)}"/>'
            f'<path d="M {f(cx - w * 0.44)},{f(base_y - h)} Q {f(cx)},{f(base_y - h - w * 0.12)} {f(cx + w * 0.44)},{f(base_y - h)}" stroke="#C9CED8" stroke-width="3" fill="none"/>'
            f'<rect x="{f(cx - w * 0.36)}" y="{f(base_y - h * 0.62)}" width="{f(w * 0.72)}" height="{f(h * 0.3)}" rx="6" fill="{GREEN}"/>'
            f'<rect x="{f(cx - w * 0.3)}" y="{f(base_y - h * 0.56)}" width="{f(w * 0.6)}" height="{f(h * 0.1)}" rx="3" fill="#FFF8E1"/>'
            f'<rect x="{f(cx - w * 0.3)}" y="{f(base_y - h * 0.42)}" width="{f(w * 0.4)}" height="{f(h * 0.06)}" rx="3" fill="{SAFFRON}"/>')


def banner_desi():
    s = SVG(W, H, seed=417)
    s.add(f'<rect width="{W}" height="{H}" fill="{s.lin([(0, "#F6FBF4"), (0.55, "#E6F4E2"), (1, "#D2EBCB")], x1=0, y1=0, x2=1, y2=0.6)}"/>')
    s.add(f'<rect width="{W}" height="{H}" fill="{s.rad([(0, "#FFFFFF", 0.7), (1, "#FFFFFF", 0)], cx=800, cy=260, r=380, units="userSpaceOnUse")}"/>')
    s.add(bunting(s, 560, 1080, 18, 24, 16))
    s.add(rice_bag(s, 730, 300, 120))
    s.add(oil_tin(s, 860, 300, 92))
    s.add(f'<rect x="900" y="210" width="70" height="90" rx="8" fill="#FFF3E0" stroke="#E0A060" stroke-width="2"/><rect x="900" y="240" width="70" height="26" fill="{SAFFRON}"/>')
    s.add(basket(s, 800, 300, 340, 170))
    s.add(rosette(s, 800, 360, 34))
    for x, y, k in [(600, 505, 'orange'), (1000, 505, 'yellow')]:
        s.add(marigold(s, x, y, 18, k))
    for x, y, r in [(640, 140, 10), (1040, 160, 9)]:
        s.add(sparkle(s, x, y, r, color='#FFFFFF', glow='#7CD67C'))
    s.save(f'{OUT}/banner_desi.svg')


def btn_tile():
    """Seamless tile of tiny confetti for festive buttons: 192 × 192 (64 dp)."""
    s = SVG(192, 192, seed=419)
    out = []
    for (x, y, a) in ((40, 44, 30), (140, 60, -20), (60, 140, -40), (150, 150, 20)):
        out.append(f'<rect x="{x - 6}" y="{y - 2}" width="12" height="4" rx="2" fill="#FFFFFF" opacity="0.4" transform="rotate({a} {x} {y})"/>')
    for (x, y) in ((96, 96), (20, 100), (110, 20)):
        out.append(f'<circle cx="{x}" cy="{y}" r="2.2" fill="#FFFFFF" opacity="0.4"/>')
    s.add(''.join(out))
    s.save(f'{OUT}/btn_tile.svg')


def section_icon():
    s = SVG(96, 96, seed=421)
    s.add(rosette(s, 48, 38, 30))
    s.save(f'{OUT}/section_icon.svg')


def petals():
    for name, col in (('petal_1', SAFFRON), ('petal_2', WHITE), ('petal_3', GREEN)):
        s = SVG(48, 48, seed=5)
        s.add(f'<path d="M 8,30 C 16,14 26,40 40,18" stroke="#05103A" stroke-opacity="0.25" stroke-width="9" fill="none" stroke-linecap="round" transform="translate(1 2)"/>'
              f'<path d="M 8,30 C 16,14 26,40 40,18" stroke="{col}" stroke-width="7" fill="none" stroke-linecap="round"/>')
        s.save(f'{OUT}/{name}.svg')
    s = SVG(72, 72, seed=7); s.add(marigold(s, 36, 36, 28, 'orange')); s.save(f'{OUT}/petal_4.svg')


if __name__ == '__main__':
    banner_sweets()
    banner_snacks()
    banner_desi()
    btn_tile()
    section_icon()
    petals()
    print('ok')
