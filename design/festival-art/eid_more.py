"""Eid banners, button texture, section icon and falling sprites (out/eid/)."""
import math

from svgkit import *
from banners import almond, brass_plate, cashew, murukku, pistachio, raisin
from christmas_more import chips_bowl
from pongal_more import cardamom
from eid_art import OUT, _pts, crescent, dates_bowl, date_fruit, gold_crescent, lantern, night, rose_milk, rosette, star5, star8, star_field, stars

W, H = 1080, 540


def sheer_khurma(s, cx, cy, rx):
    """Sheer khurma in a white bowl with a gold rim: creamy, vermicelli, nuts and sliced dates."""
    ry = rx * 0.32
    out = [f'<ellipse cx="{f(cx + 4)}" cy="{f(cy + ry * 2.5)}" rx="{f(rx * 0.95)}" ry="{f(ry * 0.5)}" fill="#2A1040" opacity="0.3" filter="{s.blur(8)}"/>',
           f'<path d="M {f(cx - rx)},{f(cy)} Q {f(cx - rx * 0.95)},{f(cy + ry * 2.4)} {f(cx)},{f(cy + ry * 2.5)} Q {f(cx + rx * 0.95)},{f(cy + ry * 2.4)} {f(cx + rx)},{f(cy)} Z" fill="{s.lin([(0, "#FFFFFF"), (1, "#D9D2E8")], x1=0, y1=0, x2=1, y2=1)}"/>',
           f'<path d="M {f(cx - rx * 0.86)},{f(cy + ry * 0.9)} Q {f(cx)},{f(cy + ry * 1.9)} {f(cx + rx * 0.86)},{f(cy + ry * 0.9)}" stroke="#C9A227" stroke-width="{f(rx * 0.03)}" fill="none"/>',
           f'<ellipse cx="{f(cx)}" cy="{f(cy)}" rx="{f(rx)}" ry="{f(ry)}" fill="#C9A227"/>',
           f'<ellipse cx="{f(cx)}" cy="{f(cy + ry * 0.05)}" rx="{f(rx * 0.93)}" ry="{f(ry * 0.84)}" fill="{s.rad([(0, "#FFF7E6"), (1, "#EED6A8")], cx=0.45, cy=0.4, r=0.7)}"/>']
    rnd = s.rnd
    for _ in range(14):
        x, y = cx + rnd.uniform(-rx * 0.75, rx * 0.65), cy + rnd.uniform(-ry * 0.55, ry * 0.5)
        out.append(f'<path d="M {f(x)},{f(y)} q {f(rx * 0.1)},{f(-ry * 0.35)} {f(rx * 0.24)},0" stroke="#D9A75C" stroke-width="2.4" fill="none" stroke-linecap="round"/>')
    for _ in range(6):
        x, y = cx + rnd.uniform(-rx * 0.6, rx * 0.6), cy + rnd.uniform(-ry * 0.45, ry * 0.4)
        out.append(f'<ellipse cx="{f(x)}" cy="{f(y)}" rx="{f(rx * 0.05)}" ry="{f(rx * 0.018)}" transform="rotate({f(rnd.uniform(0, 180))} {f(x)} {f(y)})" fill="#8BC34A"/>')
    for (dx, dy) in [(-0.3, -0.1), (0.25, 0.15), (0.05, -0.3)]:
        out.append(f'<ellipse cx="{f(cx + dx * rx)}" cy="{f(cy + dy * ry)}" rx="{f(rx * 0.07)}" ry="{f(rx * 0.04)}" fill="#7A3418"/>')
    for (dx, dy, a) in [(-0.45, 0.1, -30), (0.45, -0.05, 40)]:
        out.append(almond(s, cx + dx * rx, cy + dy * ry, rx * 0.07, a))
    return ''.join(out)


def banner_sweets():
    s = SVG(W, H, seed=311)
    s.add(f'<rect width="{W}" height="{H}" fill="{s.lin([(0, "#FBF7FF"), (0.55, "#EFE3FF"), (1, "#E0CCFA")], x1=0, y1=0, x2=1, y2=0.6)}"/>')
    s.add(f'<rect width="{W}" height="{H}" fill="{s.rad([(0, "#FFFFFF", 0.7), (1, "#FFFFFF", 0)], cx=800, cy=260, r=380, units="userSpaceOnUse")}"/>')
    s.add(rosette(s, 820, 270, 320, color='#9C6BD8', opacity=0.22, stroke=2.2))
    svg, wick = lantern(s, 1000, 150, 250, 'violet')
    s.add(svg)
    s.add(flame(s, wick[0], wick[1], 18, 44))
    for x, y in [(620, 440), (650, 452), (684, 440), (640, 470), (676, 474), (708, 458)]:
        s.add(s.rnd.choice([cashew, almond, pistachio])(s, x, y, 16, s.rnd.uniform(-60, 60)))
    s.add(sheer_khurma(s, 820, 380, 130))
    rnd = s.rnd
    for x, y in [(600, 505), (950, 505), (1010, 498), (700, 512)]:
        s.add(rnd.choice([cashew, almond, pistachio])(s, x, y, 14, rnd.uniform(-60, 60)))
    s.add(gold_crescent(s, 640, 110, 30, rot=-24))
    s.add(star5(s, 680, 88, 10))
    for x, y, r in [(760, 70, 10), (900, 110, 9), (580, 220, 8)]:
        s.add(sparkle(s, x, y, r, color='#FFFFFF', glow='#C77DFF'))
    s.save(f'{OUT}/banner_sweets.svg')


def handi(s, cx, base_y, w):
    """Biryani in a copper handi: saffron and white rice, mint leaves, fried onions, steam rising."""
    h = w * 0.62
    top = base_y - h
    copper = s.lin([(0, '#6E2E12'), (0.3, '#B5602E'), (0.5, '#F0A06A'), (0.72, '#B5602E'), (1, '#5A230C')], x1=0, y1=0, x2=1, y2=0)
    rnd = s.rnd
    out = [f'<ellipse cx="{f(cx)}" cy="{f(base_y + 4)}" rx="{f(w * 0.5)}" ry="{f(h * 0.08)}" fill="#0A0418" opacity="0.45" filter="{s.blur(8)}"/>']
    heap = []
    for _ in range(140):
        x = cx + rnd.uniform(-w * 0.4, w * 0.4)
        dome = 1 - ((x - cx) / (w * 0.42)) ** 2
        y = top - rnd.uniform(0, h * 0.42) * max(0.1, dome)
        heap.append((y, x))
    heap.sort()
    for y, x in heap:
        c = rnd.choice(['#FFFFFF', '#FFF8E7', '#F7B733', '#F59E0B', '#FFFFFF'])
        heap_svg = f'<ellipse cx="{f(x)}" cy="{f(y)}" rx="{f(w * 0.022)}" ry="{f(w * 0.009)}" transform="rotate({f(rnd.uniform(0, 180))} {f(x)} {f(y)})" fill="{c}" stroke="#D6B98A" stroke-width="0.5"/>'
        out.append(heap_svg)
    for _ in range(9):
        x, y = cx + rnd.uniform(-w * 0.3, w * 0.3), top - rnd.uniform(h * 0.05, h * 0.32)
        out.append(f'<ellipse cx="{f(x)}" cy="{f(y)}" rx="{f(w * 0.03)}" ry="{f(w * 0.014)}" transform="rotate({f(rnd.uniform(0, 180))} {f(x)} {f(y)})" fill="#43A047"/>')
    for _ in range(10):
        x, y = cx + rnd.uniform(-w * 0.32, w * 0.32), top - rnd.uniform(0, h * 0.3)
        out.append(f'<path d="M {f(x)},{f(y)} q {f(w * 0.02)},{f(-w * 0.015)} {f(w * 0.04)},0" stroke="#8D4A16" stroke-width="2.4" fill="none" stroke-linecap="round"/>')
    out.append(f'<path d="M {f(cx - w * 0.44)},{f(top)} C {f(cx - w * 0.56)},{f(top + h * 0.5)} {f(cx - w * 0.42)},{f(base_y)} {f(cx - w * 0.2)},{f(base_y)} L {f(cx + w * 0.2)},{f(base_y)} '
               f'C {f(cx + w * 0.42)},{f(base_y)} {f(cx + w * 0.56)},{f(top + h * 0.5)} {f(cx + w * 0.44)},{f(top)} Z" fill="{copper}"/>')
    out.append(f'<ellipse cx="{f(cx)}" cy="{f(top)}" rx="{f(w * 0.46)}" ry="{f(h * 0.08)}" fill="none" stroke="#F0A06A" stroke-width="{f(w * 0.025)}"/>')
    for i in range(-3, 4):
        out.append(f'<circle cx="{f(cx + i * w * 0.1)}" cy="{f(top + h * 0.45)}" r="{f(w * 0.012)}" fill="#FFD9B8" opacity="0.7"/>')
    for k in range(3):
        x = cx - w * 0.18 + k * w * 0.18
        out.append(f'<path d="M {f(x)},{f(top - h * 0.4)} C {f(x - 20)},{f(top - h * 0.75)} {f(x + 24)},{f(top - h * 0.95)} {f(x)},{f(top - h * 1.35)}" stroke="#FFFFFF" stroke-opacity="0.35" stroke-width="7" fill="none" stroke-linecap="round" filter="{s.blur(4)}"/>')
    return ''.join(out)


def rice_sack(s, cx, base_y, w):
    h = w * 1.1
    out = [f'<ellipse cx="{f(cx)}" cy="{f(base_y + 3)}" rx="{f(w * 0.55)}" ry="{f(h * 0.06)}" fill="#0A0418" opacity="0.45" filter="{s.blur(6)}"/>',
           f'<path d="M {f(cx - w * 0.5)},{f(base_y)} C {f(cx - w * 0.56)},{f(base_y - h * 0.5)} {f(cx - w * 0.46)},{f(base_y - h * 0.86)} {f(cx - w * 0.36)},{f(base_y - h)} '
           f'L {f(cx + w * 0.36)},{f(base_y - h)} C {f(cx + w * 0.46)},{f(base_y - h * 0.86)} {f(cx + w * 0.56)},{f(base_y - h * 0.5)} {f(cx + w * 0.5)},{f(base_y)} Z" fill="{s.lin([(0, "#E8D2A6"), (1, "#B59563")], x1=0, y1=0, x2=1, y2=1)}"/>',
           f'<rect x="{f(cx - w * 0.36)}" y="{f(base_y - h * 0.62)}" width="{f(w * 0.72)}" height="{f(h * 0.26)}" rx="6" fill="#4A2378"/>',
           f'<rect x="{f(cx - w * 0.3)}" y="{f(base_y - h * 0.56)}" width="{f(w * 0.6)}" height="{f(h * 0.14)}" rx="4" fill="#FFD54F" opacity="0.9"/>']
    rnd = s.rnd
    for _ in range(40):
        x, y = cx + rnd.uniform(-w * 0.34, w * 0.34), base_y - h + rnd.uniform(-h * 0.08, h * 0.04)
        out.append(f'<ellipse cx="{f(x)}" cy="{f(y)}" rx="4" ry="1.6" transform="rotate({f(rnd.uniform(0, 180))} {f(x)} {f(y)})" fill="#FFFFFF"/>')
    return ''.join(out)


def star_anise(s, x, y, r):
    pods = ''.join(f'<ellipse cx="{f(x + math.cos(math.radians(a)) * r * 0.55)}" cy="{f(y + math.sin(math.radians(a)) * r * 0.55)}" rx="{f(r * 0.5)}" ry="{f(r * 0.26)}" '
                   f'transform="rotate({a} {f(x + math.cos(math.radians(a)) * r * 0.55)} {f(y + math.sin(math.radians(a)) * r * 0.55)})" fill="#7A3E1E" stroke="#4A2410" stroke-width="1"/>' for a in range(0, 360, 45))
    return pods + f'<circle cx="{f(x)}" cy="{f(y)}" r="{f(r * 0.18)}" fill="#5A2C12"/>'


def cinnamon(s, x, y, L, a):
    return (f'<g transform="translate({f(x)} {f(y)}) rotate({f(a)})"><rect x="{f(-L / 2)}" y="-7" width="{f(L)}" height="14" rx="7" fill="#8D4A24"/>'
            f'<rect x="{f(-L / 2)}" y="-7" width="{f(L)}" height="5" rx="3" fill="#B86A3A"/><ellipse cx="{f(L / 2)}" cy="0" rx="4" ry="7" fill="#5A2C12"/></g>')


def banner_biryani():
    s = SVG(W, H, seed=313)
    night(s, W, H, glow=(820, 260, 420))
    s.add(star_field(s, 30, 40, W, H, 130, 26, opacity=0.07))
    s.add(stars(s, 560, W, 20, 300, 30))
    svg, wick = lantern(s, 1010, 120, 230, 'amber')
    s.add(svg)
    s.add(flame(s, wick[0], wick[1], 17, 42))
    s.add(rice_sack(s, 650, 500, 130))
    s.add(handi(s, 830, 470, 280))
    for x, y in [(560, 505), (1000, 500)]:
        s.add(star_anise(s, x, y, 16))
    s.add(cinnamon(s, 940, 508, 80, -12))
    for x, y in [(600, 515), (720, 512), (980, 520)]:
        s.add(cardamom(s, x, y, 12, s.rnd.uniform(-40, 40)))
    s.add(gold_crescent(s, 610, 110, 34, rot=-24))
    for x, y, r in [(700, 80, 10), (900, 60, 8), (1040, 300, 9)]:
        s.add(sparkle(s, x, y, r))
    s.save(f'{OUT}/banner_biryani.svg')


def watermelon(s, cx, cy, r, a):
    seeds = ''.join(f'<ellipse cx="{f(cx + math.cos(math.radians(t)) * r * 0.55)}" cy="{f(cy - abs(math.sin(math.radians(t))) * r * 0.45)}" rx="2.6" ry="4.2" fill="#2B1A12" '
                    f'transform="rotate({t - 90} {f(cx + math.cos(math.radians(t)) * r * 0.55)} {f(cy - abs(math.sin(math.radians(t))) * r * 0.45)})"/>' for t in range(20, 170, 25))
    return (f'<g transform="rotate({f(a)} {f(cx)} {f(cy)})">'
            f'<path d="M {f(cx - r)},{f(cy)} A {f(r)},{f(r)} 0 0 1 {f(cx + r)},{f(cy)} Z" fill="#2E7D32"/>'
            f'<path d="M {f(cx - r * 0.9)},{f(cy)} A {f(r * 0.9)},{f(r * 0.9)} 0 0 1 {f(cx + r * 0.9)},{f(cy)} Z" fill="#F1F8E9"/>'
            f'<path d="M {f(cx - r * 0.82)},{f(cy)} A {f(r * 0.82)},{f(r * 0.82)} 0 0 1 {f(cx + r * 0.82)},{f(cy)} Z" fill="{s.rad([(0, "#FF6F61"), (1, "#E53935")], cx=0.5, cy=1, r=0.9)}"/>'
            f'{seeds}</g>')


def grapes(s, cx, cy, r):
    rnd = s.rnd
    out = [f'<path d="M {f(cx)},{f(cy - r * 3.2)} q 6,-12 16,-14" stroke="#6D4C2E" stroke-width="3" fill="none"/>']
    for row, n in enumerate([4, 4, 3, 3, 2, 1]):
        for i in range(n):
            x = cx + (i - (n - 1) / 2) * r * 1.6 + rnd.uniform(-1, 1)
            y = cy - r * 2.8 + row * r * 1.35
            out.append(f'<circle cx="{f(x)}" cy="{f(y)}" r="{f(r)}" fill="{s.rad([(0, "#C5E1A5"), (1, "#7CB342")], cx=0.35, cy=0.3, r=0.75)}" stroke="#558B2F" stroke-width="0.8"/>')
    return ''.join(out)


def banner_iftar():
    s = SVG(W, H, seed=317)
    s.add(f'<rect width="{W}" height="{H}" fill="{s.lin([(0, "#FFF7F2"), (0.55, "#FFE6DE"), (1, "#FFD1C4")], x1=0, y1=0, x2=1, y2=0.6)}"/>')
    s.add(f'<rect width="{W}" height="{H}" fill="{s.rad([(0, "#FFFFFF", 0.65), (1, "#FFFFFF", 0)], cx=800, cy=260, r=360, units="userSpaceOnUse")}"/>')
    s.add(rosette(s, 810, 270, 320, color='#E07B53', opacity=0.2, stroke=2.2))
    s.add('<line x1="880" y1="0" x2="880" y2="70" stroke="#C98A12" stroke-width="2"/>')
    svg, wick = lantern(s, 880, 64, 180, 'teal')
    s.add(svg)
    s.add(flame(s, wick[0], wick[1], 13, 32))
    s.add(brass_plate(s, 800, 450, 190, 46))
    s.add(murukku(s, 720, 430, 50))
    s.add(chips_bowl(s, 870, 428, 74))
    s.add(rose_milk(s, 1000, 500, 150))
    s.add(rose_milk(s, 610, 505, 120))
    s.add(gold_crescent(s, 1000, 120, 34, rot=-24))
    s.add(star5(s, 1044, 94, 11))
    for x, y, r in [(640, 120, 11), (1040, 260, 9), (720, 70, 8)]:
        s.add(sparkle(s, x, y, r, color='#FFFFFF', glow='#FF8A65'))
    s.save(f'{OUT}/banner_iftar.svg')


def btn_tile():
    """Seamless tile of little eight-point stars for festive buttons: 192 × 192 (64 dp)."""
    s = SVG(192, 192, seed=319)
    out = []
    for x, y in ((48, 48), (144, 144)):
        out.append(f'<polygon points="{_pts(star8(x, y, 14))}" fill="none" stroke="#FFF3C4" stroke-opacity="0.45" stroke-width="1.6"/>')
        out.append(f'<circle cx="{x}" cy="{y}" r="2.2" fill="#FFF3C4" opacity="0.5"/>')
    for x, y in ((144, 48), (48, 144)):
        out.append(f'<circle cx="{x}" cy="{y}" r="2.4" fill="#FFF3C4" opacity="0.45"/>')
    s.add(''.join(out))
    s.save(f'{OUT}/btn_tile.svg')


def section_icon():
    s = SVG(96, 96, seed=321)
    svg, wick = lantern(s, 48, 4, 88, 'amber', glow=False)
    s.add(svg)
    s.add(flame(s, wick[0], wick[1], 7, 17, glow=False))
    s.save(f'{OUT}/section_icon.svg')


def petals():
    s = SVG(48, 48, seed=3); s.add(star5(s, 24, 25, 19)); s.save(f'{OUT}/petal_1.svg')
    s = SVG(48, 48, seed=4); s.add(crescent(s, 24, 24, 17, s.lin([(0, '#FFF3C4'), (0.45, '#F6C445'), (1, '#B07A10')], x1=0, y1=0, x2=1, y2=1), rot=-30)); s.save(f'{OUT}/petal_2.svg')
    s = SVG(48, 48, seed=5); s.add(f'<polygon points="{_pts(star8(24, 24, 19))}" fill="#FFFFFF" stroke="#D7C4F2" stroke-width="1.4"/>'); s.save(f'{OUT}/petal_3.svg')
    s = SVG(72, 72, seed=6)
    svg, wick = lantern(s, 36, 2, 66, 'ruby', glow=False)
    s.add(svg); s.add(flame(s, wick[0], wick[1], 5, 12, glow=False))
    s.save(f'{OUT}/petal_4.svg')


if __name__ == '__main__':
    banner_sweets()
    banner_biryani()
    banner_iftar()
    btn_tile()
    section_icon()
    petals()
    print('ok')
