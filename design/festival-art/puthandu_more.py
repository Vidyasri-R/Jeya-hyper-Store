"""Tamil New Year banners, button texture, section icon and falling sprites (out/puthandu/)."""
import math

from svgkit import *
from banners import basket, brass_plate, cashew, jasmine_string, kuthuvilakku, raisin
from pongal_more import banana_leaf, colour_bowl
from puthandu_art import (OUT, areca, banana, banana_hand, betel, butta_field, coin, jackfruit, kanakambaram,
                          konrai, lotus_kolam, malli, mango, silk)

W, H = 1080, 540


def _scatter(s, x0, x1, y0, y1, n):
    """A few loose konrai, malli and kanakambaram flowers."""
    rnd = s.rnd
    out = []
    for i in range(n):
        x, y = rnd.uniform(x0, x1), rnd.uniform(y0, y1)
        out.append([konrai, malli, kanakambaram][i % 3](s, x, y, rnd.uniform(9, 13), rot=rnd.uniform(0, 72)))
    return ''.join(out)


# ── Banner 1: mangoes & mukkani (light) ──
def banner_fruits():
    s = SVG(W, H, seed=211)
    s.add(f'<rect width="{W}" height="{H}" fill="{s.lin([(0, "#FFFBEA"), (0.55, "#FFEDB8"), (1, "#FFD98A")], x1=0, y1=0, x2=1, y2=0.6)}"/>')
    s.add(f'<rect width="{W}" height="{H}" fill="{s.rad([(0, "#FFFFFF", 0.7), (1, "#FFFFFF", 0)], cx=800, cy=250, r=380, units="userSpaceOnUse")}"/>')
    s.add(lotus_kolam(s, 820, 270, 320, color='#E39A1C', opacity=0.22, stroke=2.2))
    for x, y, L, a, tone in [(700, 300, 130, 140, 0), (760, 270, 140, 163, 1), (850, 268, 140, 194, 2), (925, 300, 126, 218, 0)]:
        s.add(mango_leaf(s, x, y, L, 42, angle=a, tone=tone))
    s.add(jackfruit(s, 1000, 372, 62, 80, angle=14))
    heap = [(768, 206, 86, -10, 'yellow'), (848, 204, 86, 14, 'ripe'),
            (728, 262, 92, -24, 'ripe'), (806, 252, 98, 2, 'ripe'), (884, 262, 92, 24, 'yellow'),
            (690, 318, 92, -36, 'ripe'), (764, 312, 96, -12, 'yellow'), (842, 310, 96, 12, 'ripe'), (914, 318, 92, 34, 'raw')]
    for i, (x, y, L, a, kind) in enumerate(heap):
        s.add(mango(s, x, y, L, a, kind, leaf=i in (1, 6)))
    s.add(basket(s, 800, 330, 330, 150))
    s.add(banana_hand(s, 586, 470, 150))
    s.add(_scatter(s, 960, 1060, 470, 515, 4))
    for x, y, r in [(630, 120, 12), (1030, 200, 10), (700, 70, 8), (960, 80, 11)]:
        s.add(sparkle(s, x, y, r, color='#FFFFFF', glow='#FFB300'))
    s.save(f'{OUT}/banner_fruits.svg')


# ── Banner 2: the Puthandu feast on a banana leaf (dark) ──
def rice_heap(s, cx, cy, r):
    """Steamed rice heaped on the leaf, a ladle of paruppu and a drop of ghee on top."""
    d = f'M {f(cx - r)},{f(cy)} Q {f(cx - r * 0.8)},{f(cy - r * 0.78)} {f(cx)},{f(cy - r * 0.82)} Q {f(cx + r * 0.8)},{f(cy - r * 0.78)} {f(cx + r)},{f(cy)} Q {f(cx)},{f(cy + r * 0.24)} {f(cx - r)},{f(cy)} Z'
    clip = s.clip(f'<path d="{d}"/>')
    rnd = s.rnd
    grains = ''.join(f'<ellipse cx="{f(x)}" cy="{f(y)}" rx="{f(r * 0.05)}" ry="{f(r * 0.022)}" transform="rotate({f(rnd.uniform(0, 180))} {f(x)} {f(y)})" fill="#FFFFFF" stroke="#D6D2C4" stroke-width="0.6"/>'
                     for x, y in ((cx + rnd.uniform(-r, r), cy - rnd.uniform(-r * 0.1, r * 0.8)) for _ in range(150)))
    return (f'<ellipse cx="{f(cx + 6)}" cy="{f(cy + r * 0.12)}" rx="{f(r * 1.02)}" ry="{f(r * 0.2)}" fill="#0B2A0E" opacity="0.35" filter="{s.blur(6)}"/>'
            f'<path d="{d}" fill="{s.rad([(0, "#FFFFFF"), (0.7, "#F1EFE6"), (1, "#CFCABC")], cx=0.45, cy=0.35, r=0.75)}"/>'
            f'<g clip-path="{clip}">{grains}</g>'
            f'<ellipse cx="{f(cx - r * 0.25)}" cy="{f(cy - r * 0.55)}" rx="{f(r * 0.22)}" ry="{f(r * 0.08)}" fill="#FFFFFF" opacity="0.7"/>')


def dal_mound(s, cx, cy, r):
    """Paruppu: a soft mound of cooked toor dal with a drop of ghee."""
    d = f'M {f(cx - r)},{f(cy)} Q {f(cx - r * 0.75)},{f(cy - r * 0.7)} {f(cx)},{f(cy - r * 0.72)} Q {f(cx + r * 0.75)},{f(cy - r * 0.7)} {f(cx + r)},{f(cy)} Q {f(cx)},{f(cy + r * 0.25)} {f(cx - r)},{f(cy)} Z'
    rnd = s.rnd
    grain = ''.join(f'<circle cx="{f(cx + rnd.uniform(-r * 0.8, r * 0.8))}" cy="{f(cy - rnd.uniform(0, r * 0.6))}" r="{f(r * rnd.uniform(0.04, 0.07))}" fill="{rnd.choice(["#FFE38F", "#D98E10"])}" opacity="0.6"/>' for _ in range(24))
    return (f'<ellipse cx="{f(cx + 4)}" cy="{f(cy + r * 0.1)}" rx="{f(r)}" ry="{f(r * 0.22)}" fill="#0B2A0E" opacity="0.35" filter="{s.blur(5)}"/>'
            f'<path d="{d}" fill="{s.rad([(0, "#FFE28A"), (0.6, "#F5B82E"), (1, "#D98A0B")], cx=0.45, cy=0.35, r=0.75)}"/>{grain}'
            f'<ellipse cx="{f(cx - r * 0.1)}" cy="{f(cy - r * 0.5)}" rx="{f(r * 0.24)}" ry="{f(r * 0.09)}" fill="#FFF6C8" opacity="0.85"/>')


def vadai(s, cx, cy, r):
    """Medhu vadai: a golden-brown ring, crisp edged, the leaf showing through its hole."""
    rnd = s.rnd
    pts = []
    for i in range(36):
        a = i * 10
        pts.append(f'{f(cx + math.cos(math.radians(a)) * r * rnd.uniform(0.95, 1.03))},{f(cy + math.sin(math.radians(a)) * r * 0.82 * rnd.uniform(0.95, 1.03))}')
    g = s.rad([(0, '#F2B866'), (0.55, '#C7782A'), (1, '#7A3E10')], cx=0.42, cy=0.38, r=0.7)
    flecks = ''.join(f'<circle cx="{f(cx + rnd.uniform(-r * 0.8, r * 0.8))}" cy="{f(cy + rnd.uniform(-r * 0.6, r * 0.6))}" r="{f(r * rnd.uniform(0.03, 0.06))}" fill="{rnd.choice(["#8A4512", "#F7CF8A", "#5E2E0C"])}" opacity="0.6"/>' for _ in range(26))
    return (f'<ellipse cx="{f(cx + 5)}" cy="{f(cy + 8)}" rx="{f(r)}" ry="{f(r * 0.8)}" fill="#0B2A0E" opacity="0.4" filter="{s.blur(6)}"/>'
            f'<polygon points="{" ".join(pts)}" fill="{g}"/>{flecks}'
            f'<ellipse cx="{f(cx)}" cy="{f(cy)}" rx="{f(r * 0.22)}" ry="{f(r * 0.17)}" fill="#2E6B2A"/>'
            f'<ellipse cx="{f(cx)}" cy="{f(cy - r * 0.02)}" rx="{f(r * 0.22)}" ry="{f(r * 0.17)}" fill="none" stroke="#5E2E0C" stroke-width="{f(r * 0.06)}"/>'
            f'<path d="M {f(cx - r * 0.7)},{f(cy - r * 0.3)} Q {f(cx - r * 0.3)},{f(cy - r * 0.75)} {f(cx + r * 0.3)},{f(cy - r * 0.62)}" stroke="#FFE0A3" stroke-opacity="0.55" stroke-width="{f(r * 0.08)}" fill="none" stroke-linecap="round"/>')


def payasam(s, cx, cy, rx):
    """Semiya payasam in a brass cup: creamy, with vermicelli, cashews and raisins."""
    ry = rx * 0.32
    gold = s.lin([(0, '#7A4E00'), (0.3, '#C98A12'), (0.5, '#FFE7A0'), (0.75, '#C98A12'), (1, '#6B4300')], x1=0, y1=0, x2=1, y2=0)
    out = [f'<ellipse cx="{f(cx + 4)}" cy="{f(cy + ry * 2.6)}" rx="{f(rx * 0.95)}" ry="{f(ry * 0.55)}" fill="#0B2A0E" opacity="0.4" filter="{s.blur(6)}"/>',
           f'<path d="M {f(cx - rx)},{f(cy)} Q {f(cx - rx * 0.95)},{f(cy + ry * 2.4)} {f(cx)},{f(cy + ry * 2.5)} Q {f(cx + rx * 0.95)},{f(cy + ry * 2.4)} {f(cx + rx)},{f(cy)} Z" fill="{gold}"/>',
           f'<ellipse cx="{f(cx)}" cy="{f(cy)}" rx="{f(rx)}" ry="{f(ry)}" fill="#B07A10"/>',
           f'<ellipse cx="{f(cx)}" cy="{f(cy + ry * 0.06)}" rx="{f(rx * 0.92)}" ry="{f(ry * 0.84)}" fill="{s.rad([(0, "#FFF6E2"), (1, "#EBCB92")], cx=0.45, cy=0.4, r=0.7)}"/>']
    rnd = s.rnd
    for _ in range(9):
        x, y = cx + rnd.uniform(-rx * 0.7, rx * 0.6), cy + rnd.uniform(-ry * 0.5, ry * 0.5)
        out.append(f'<path d="M {f(x)},{f(y)} q {f(rx * 0.12)},{f(-ry * 0.3)} {f(rx * 0.26)},{f(rx * 0.0)}" stroke="#D9AE6A" stroke-width="2" fill="none" stroke-linecap="round"/>')
    for (dx, dy, a) in [(-0.35, -0.1, -30), (0.25, 0.05, 40), (-0.05, 0.2, 10)]:
        out.append(cashew(s, cx + dx * rx, cy + dy * ry * 2, rx * 0.13, a))
    for (dx, dy) in [(0.45, -0.15), (-0.55, 0.15)]:
        out.append(raisin(s, cx + dx * rx, cy + dy * ry * 2, rx * 0.07, 20))
    return ''.join(out)


def pachadi(s, cx, cy, r):
    """Maanga pachadi: raw-mango pieces in glossy jaggery syrup, flecked with neem flowers."""
    rnd = s.rnd
    syrup = s.rad([(0, '#E3A23E'), (0.6, '#B8701A'), (1, '#7E4410')], cx=0.45, cy=0.4, r=0.7)
    out = [f'<ellipse cx="{f(cx + 4)}" cy="{f(cy + 6)}" rx="{f(r)}" ry="{f(r * 0.55)}" fill="#0B2A0E" opacity="0.35" filter="{s.blur(5)}"/>',
           f'<ellipse cx="{f(cx)}" cy="{f(cy)}" rx="{f(r)}" ry="{f(r * 0.55)}" fill="{syrup}"/>']
    for _ in range(9):
        x, y = cx + rnd.uniform(-r * 0.65, r * 0.65), cy + rnd.uniform(-r * 0.3, r * 0.3)
        out.append(f'<rect x="{f(x - r * 0.13)}" y="{f(y - r * 0.09)}" width="{f(r * 0.26)}" height="{f(r * 0.18)}" rx="{f(r * 0.05)}" transform="rotate({f(rnd.uniform(-40, 40))} {f(x)} {f(y)})" fill="#F3D774" stroke="#C99A2E" stroke-width="1"/>')
    for _ in range(14):
        out.append(f'<circle cx="{f(cx + rnd.uniform(-r * 0.8, r * 0.8))}" cy="{f(cy + rnd.uniform(-r * 0.4, r * 0.4))}" r="{f(r * 0.035)}" fill="#FFF8E1"/>')
    out.append(f'<ellipse cx="{f(cx - r * 0.35)}" cy="{f(cy - r * 0.22)}" rx="{f(r * 0.25)}" ry="{f(r * 0.08)}" fill="#FFFFFF" opacity="0.35"/>')
    return ''.join(out)


def appalam(s, cx, cy, r):
    rnd = s.rnd
    pts = ' '.join(f'{f(cx + math.cos(math.radians(a)) * r * rnd.uniform(0.96, 1.02))},{f(cy + math.sin(math.radians(a)) * r * 0.7 * rnd.uniform(0.96, 1.02))}' for a in range(0, 360, 8))
    blisters = ''.join(f'<circle cx="{f(cx + rnd.uniform(-r * 0.8, r * 0.8))}" cy="{f(cy + rnd.uniform(-r * 0.5, r * 0.5))}" r="{f(r * rnd.uniform(0.04, 0.09))}" fill="{rnd.choice(["#E8C47A", "#FFF4D6"])}" opacity="0.7"/>' for _ in range(22))
    return (f'<ellipse cx="{f(cx + 4)}" cy="{f(cy + 6)}" rx="{f(r)}" ry="{f(r * 0.7)}" fill="#0B2A0E" opacity="0.35" filter="{s.blur(5)}"/>'
            f'<polygon points="{pts}" fill="{s.rad([(0, "#FFF3D2"), (1, "#EAC983")], cx=0.45, cy=0.4, r=0.7)}"/>{blisters}')


def banner_feast():
    s = SVG(W, H, seed=213)
    silk(s, W, H, glow=(820, 260, 420))
    s.add(butta_field(s, 30, 40, W, H, 120, 28, opacity=0.08))
    s.add(lotus_kolam(s, 830, 270, 300, opacity=0.12))
    s.add(banana_leaf(s, 870, 330, 600, 250, -6))
    s.add(banana(s, 640, 292, 140, angle=-18))
    s.add(f'<ellipse cx="672" cy="352" rx="13" ry="9" fill="#C62828"/><ellipse cx="668" cy="349" rx="4" ry="2.5" fill="#FF8A80"/>')   # pickle
    s.add(f'<ellipse cx="700" cy="362" rx="9" ry="6" fill="#FAFAFA"/>')   # salt
    s.add(appalam(s, 1010, 392, 66))
    s.add(rice_heap(s, 860, 340, 96))
    s.add(dal_mound(s, 752, 352, 38))
    s.add(vadai(s, 728, 404, 44))
    s.add(vadai(s, 790, 432, 42))
    s.add(pachadi(s, 948, 434, 54))
    s.add(payasam(s, 990, 300, 64))
    s.add(jasmine_string(s, 580, 30, 1060, 30, 54, 26))
    s.add(_scatter(s, 600, 1060, 488, 520, 5))
    for x, y, r in [(620, 150, 10), (1045, 175, 9), (700, 100, 8), (950, 110, 12)]:
        s.add(sparkle(s, x, y, r))
    s.save(f'{OUT}/banner_feast.svg')


# ── Banner 3: pooja & kani needs (light) ──
def coconut(s, cx, cy, r):
    """A pooja coconut with its tuft: brown fibre, a smear of turmeric and a kumkum dot."""
    g = s.rad([(0, '#B98352'), (0.55, '#7E4C22'), (1, '#4A2810')], cx=0.38, cy=0.35, r=0.75)
    clip = s.clip(f'<ellipse cx="{f(cx)}" cy="{f(cy)}" rx="{f(r * 0.92)}" ry="{f(r)}"/>')
    rnd = s.rnd
    fibres = []
    for _ in range(46):
        x, y = cx + rnd.uniform(-r, r), cy + rnd.uniform(-r, r)
        fibres.append(f'<path d="M {f(x)},{f(y)} q {f(r * 0.08)},{f(r * 0.12)} {f(rnd.uniform(-1, 1) * r * 0.06)},{f(r * 0.26)}" stroke="#D2A679" stroke-opacity="0.45" stroke-width="1.6" fill="none" stroke-linecap="round"/>')
    tuft = ''.join(f'<path d="M {f(cx)},{f(cy - r * 0.95)} q {f(dx * r * 0.2)},{f(-r * 0.25)} {f(dx * r * 0.35)},{f(-r * 0.42)}" stroke="#8D6238" stroke-width="3" fill="none" stroke-linecap="round"/>' for dx in (-1.2, -0.6, -0.1, 0.4, 0.9, 1.3))
    return (f'<ellipse cx="{f(cx + r * 0.08)}" cy="{f(cy + r * 0.14)}" rx="{f(r * 0.92)}" ry="{f(r)}" fill="#2A1400" opacity="0.32" filter="{s.blur(r * 0.12)}"/>'
            f'{tuft}<ellipse cx="{f(cx)}" cy="{f(cy)}" rx="{f(r * 0.92)}" ry="{f(r)}" fill="{g}"/>'
            f'<g clip-path="{clip}">{"".join(fibres)}</g>'
            f'<ellipse cx="{f(cx + r * 0.05)}" cy="{f(cy + r * 0.12)}" rx="{f(r * 0.2)}" ry="{f(r * 0.16)}" fill="#F9C02D" opacity="0.92"/>'
            f'<circle cx="{f(cx + r * 0.05)}" cy="{f(cy + r * 0.12)}" r="{f(r * 0.08)}" fill="#C62828"/>'
            f'<ellipse cx="{f(cx - r * 0.45)}" cy="{f(cy - r * 0.45)}" rx="{f(r * 0.18)}" ry="{f(r * 0.1)}" transform="rotate(-35 {f(cx - r * 0.45)} {f(cy - r * 0.45)})" fill="#FFFFFF" opacity="0.25"/>')


def banner_pooja():
    s = SVG(W, H, seed=217)
    s.add(f'<rect width="{W}" height="{H}" fill="{s.lin([(0, "#FFF7F0"), (0.55, "#FFE6D6"), (1, "#FFCDB8")], x1=0, y1=0, x2=1, y2=0.6)}"/>')
    s.add(f'<rect width="{W}" height="{H}" fill="{s.rad([(0, "#FFFFFF", 0.65), (1, "#FFFFFF", 0)], cx=790, cy=270, r=360, units="userSpaceOnUse")}"/>')
    s.add(lotus_kolam(s, 800, 280, 320, color='#E07B53', opacity=0.2, stroke=2.2))
    s.add(jasmine_string(s, 580, 34, 1060, 34, 44, 26))
    s.add(brass_plate(s, 770, 452, 172, 44))
    for a, tone in [(128, 0), (152, 1), (180, 2), (208, 1), (232, 0)]:
        s.add(mango_leaf(s, 770, 386, 128, 42, angle=a, tone=tone))
    for x, y, L, a in [(668, 452, 92, -72), (872, 452, 92, 72), (712, 462, 84, -44), (828, 462, 84, 44)]:
        s.add(betel(s, x, y, L, a))
    s.add(coconut(s, 770, 384, 64))
    for x, y, r in [(704, 478, 12), (726, 486, 11), (812, 486, 11)]:
        s.add(coin(s, x, y, r))
    s.add(areca(s, 838, 476, 11))
    s.add(areca(s, 856, 482, 10, cut=True))
    s.add(colour_bowl(s, 620, 470, 40, '#C62828'))
    s.add(colour_bowl(s, 892, 488, 34, '#F9C02D'))
    s.add(kuthuvilakku(s, 972, 494, 270))
    s.add(_scatter(s, 600, 960, 500, 522, 4))
    for x, y, r in [(620, 140, 11), (1040, 120, 10), (700, 86, 8), (920, 96, 12)]:
        s.add(sparkle(s, x, y, r, color='#FFFFFF', glow='#FF8A65'))
    s.save(f'{OUT}/banner_pooja.svg')


def btn_tile():
    """Seamless tile of gold mango buttas and kolam dots for festive buttons: 192 × 192 (64 dp)."""
    s = SVG(192, 192, seed=219)
    out = [paisley(s, 48, 62, 26, angle=24, color='#FFF3C4', opacity=0.42),
           paisley(s, 144, 158, 26, angle=-24, color='#FFF3C4', opacity=0.42)]
    for x, y in ((144, 48), (48, 144)):
        out.append(f'<circle cx="{x}" cy="{y}" r="2.4" fill="#FFF3C4" opacity="0.5"/>')
        out += [f'<circle cx="{x + dx}" cy="{y + dy}" r="1.5" fill="#FFF3C4" opacity="0.4"/>' for dx, dy in ((-9, 0), (9, 0), (0, -9), (0, 9))]
    s.add(''.join(out))
    s.save(f'{OUT}/btn_tile.svg')


def section_icon():
    s = SVG(96, 96, seed=221)
    s.add(mango_leaf(s, 56, 30, 40, 15, angle=-112, tone=0))
    s.add(mango_leaf(s, 52, 30, 36, 14, angle=128, tone=2))
    s.add(mango(s, 48, 60, 58, angle=14, kind='ripe', leaf=False))
    s.save(f'{OUT}/section_icon.svg')


def petals():
    s = SVG(48, 48, seed=3); s.add(konrai(s, 24, 23, 18)); s.save(f'{OUT}/petal_1.svg')
    s = SVG(48, 48, seed=4); s.add(malli(s, 24, 24, 19)); s.save(f'{OUT}/petal_2.svg')
    s = SVG(48, 48, seed=5); s.add(kanakambaram(s, 24, 26, 19)); s.save(f'{OUT}/petal_3.svg')
    s = SVG(72, 72, seed=6); s.add(mango_leaf(s, 36, 4, 58, 24, angle=0, tone=1)); s.save(f'{OUT}/petal_4.svg')


if __name__ == '__main__':
    banner_fruits()
    banner_feast()
    banner_pooja()
    btn_tile()
    section_icon()
    petals()
    print('ok')
