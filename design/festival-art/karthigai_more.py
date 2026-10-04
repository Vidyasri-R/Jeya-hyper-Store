"""Karthigai Deepam banners, button texture, section icon and falling sprites (out/karthigai/)."""
import math

from svgkit import *
from banners import brass_plate
from pongal_more import colour_bowl, colour_kolam, jaggery
from puthandu_art import kanakambaram, malli
from karthigai_art import OUT, agal, beacon, dusk, hill, pori_urundai, stars

W, H = 1080, 540


def appam_pan(s, cx, cy, rx):
    """A cast-iron paniyaram pan of golden nei appam."""
    ry = rx * 0.34
    out = [f'<ellipse cx="{f(cx + 6)}" cy="{f(cy + ry * 1.2)}" rx="{f(rx)}" ry="{f(ry * 0.5)}" fill="#120604" opacity="0.4" filter="{s.blur(8)}"/>',
           f'<rect x="{f(cx + rx * 0.9)}" y="{f(cy - ry * 0.15)}" width="{f(rx * 0.6)}" height="{f(ry * 0.3)}" rx="{f(ry * 0.15)}" fill="#3A2A22"/>',
           f'<ellipse cx="{f(cx)}" cy="{f(cy + ry * 0.2)}" rx="{f(rx)}" ry="{f(ry)}" fill="#1E1714"/>',
           f'<ellipse cx="{f(cx)}" cy="{f(cy)}" rx="{f(rx)}" ry="{f(ry)}" fill="{s.rad([(0, "#4A3C34"), (1, "#1E1714")], cx=0.4, cy=0.35, r=0.7)}"/>']
    wells = [(-0.5, -0.1), (0, -0.25), (0.5, -0.1), (-0.25, 0.25), (0.25, 0.25), (-0.65, 0.3), (0.65, 0.3)]
    for dx, dy in wells:
        x, y = cx + dx * rx, cy + dy * ry
        r = rx * 0.15
        out.append(f'<ellipse cx="{f(x)}" cy="{f(y + r * 0.2)}" rx="{f(r * 1.1)}" ry="{f(r * 0.5)}" fill="#0E0A08"/>')
        out.append(f'<circle cx="{f(x)}" cy="{f(y - r * 0.3)}" r="{f(r)}" fill="{s.rad([(0, "#FFD27A"), (0.6, "#D9892E"), (1, "#8A4A10")], cx=0.38, cy=0.32, r=0.75)}"/>')
        out.append(f'<ellipse cx="{f(x - r * 0.3)}" cy="{f(y - r * 0.7)}" rx="{f(r * 0.3)}" ry="{f(r * 0.16)}" fill="#FFFFFF" opacity="0.45"/>')
    return ''.join(out)


def ghee_jar(s, cx, base_y, w):
    h = w * 1.15
    return (f'<ellipse cx="{f(cx)}" cy="{f(base_y + 3)}" rx="{f(w * 0.55)}" ry="{f(w * 0.1)}" fill="#120604" opacity="0.35" filter="{s.blur(4)}"/>'
            f'<rect x="{f(cx - w / 2)}" y="{f(base_y - h)}" width="{f(w)}" height="{f(h)}" rx="{f(w * 0.12)}" fill="#FFFFFF" fill-opacity="0.2" stroke="#FFFFFF" stroke-opacity="0.7" stroke-width="2"/>'
            f'<rect x="{f(cx - w * 0.44)}" y="{f(base_y - h * 0.82)}" width="{f(w * 0.88)}" height="{f(h * 0.8)}" rx="{f(w * 0.1)}" fill="{s.lin([(0, "#FFE7A0"), (1, "#F2B33A")], x1=0, y1=0, x2=0, y2=1)}"/>'
            f'<rect x="{f(cx - w * 0.54)}" y="{f(base_y - h - w * 0.14)}" width="{f(w * 1.08)}" height="{f(w * 0.2)}" rx="{f(w * 0.06)}" fill="#C62828"/>'
            f'<rect x="{f(cx - w * 0.36)}" y="{f(base_y - h * 0.56)}" width="{f(w * 0.72)}" height="{f(h * 0.26)}" rx="4" fill="#FFF8E1"/>'
            f'<rect x="{f(cx - w * 0.3)}" y="{f(base_y - h * 0.5)}" width="{f(w * 0.6)}" height="{f(h * 0.08)}" rx="2" fill="#2E7D32"/>')


def banner_sweets():
    s = SVG(W, H, seed=711)
    s.add(f'<rect width="{W}" height="{H}" fill="{s.lin([(0, "#FFFAF0"), (0.55, "#FFEACC"), (1, "#FFD39A")], x1=0, y1=0, x2=1, y2=0.6)}"/>')
    s.add(f'<rect width="{W}" height="{H}" fill="{s.rad([(0, "#FFFFFF", 0.7), (1, "#FFFFFF", 0)], cx=800, cy=260, r=380, units="userSpaceOnUse")}"/>')
    s.add(mandala(s, 820, 270, 320, color='#D9892E', opacity=0.2, stroke=2.2, fill_opacity=0.05))
    s.add(brass_plate(s, 740, 380, 150, 36))
    for (x, y, r) in [(690, 358, 34), (745, 352, 36), (800, 358, 34), (715, 312, 32), (772, 308, 32), (743, 268, 31)]:
        s.add(pori_urundai(s, x, y, r))
    s.add(appam_pan(s, 900, 460, 130))
    s.add(ghee_jar(s, 1015, 330, 70))
    s.add(jaggery(s, 620, 470, 40))
    for x, size in ((610, 70), (1040, 66)):
        s.add(agal(s, x, 520 - size * 0.5, size, 1))
        s.add(flame(s, x, 520 - size * 0.5, size * 0.2, size * 0.5))
    for x, y, r in [(640, 120, 11), (1030, 200, 10), (900, 90, 8)]:
        s.add(sparkle(s, x, y, r, color='#FFFFFF', glow='#FFB300'))
    s.save(f'{OUT}/banner_sweets.svg')


def steps_of_lamps(s, cx, base_y, widths, step_h):
    """Stone steps, a lamp on every tread; the lamps go on after all the steps so none is hidden."""
    steps, lamps = [], []
    y = base_y
    for k, w in enumerate(widths):
        top = y - step_h
        steps.append(f'<rect x="{f(cx - w / 2)}" y="{f(top)}" width="{f(w)}" height="{f(step_h)}" fill="{s.lin([(0, "#5E4A44"), (1, "#2E221E")], x1=0, y1=0, x2=0, y2=1)}"/>')
        steps.append(f'<rect x="{f(cx - w / 2)}" y="{f(top)}" width="{f(w)}" height="6" fill="#8A7268"/>')
        n = int(w / 64)
        for i in range(n):
            x = cx - w / 2 + (i + 0.5) * w / n
            ly = y - 14 if k else top - 14   # on this step's tread (front edge)
            lamps.append(agal(s, x, ly, 40, (i + k) % 3) + flame(s, x, ly, 8, 20))
        y = top
    top_w = widths[-1]
    n = int(top_w / 64)
    for i in range(n):
        x = cx - top_w / 2 + (i + 0.5) * top_w / n
        lamps.append(agal(s, x, y - 14, 40, i % 3) + flame(s, x, y - 14, 8, 20))
    return ''.join(steps) + ''.join(lamps)


def oil_can(s, cx, base_y, w):
    """A plastic can of nallennai (sesame oil) with a handle and a red cap."""
    h = w * 1.35
    body = s.lin([(0, '#F7D774'), (0.5, '#E8B02E'), (1, '#B07A10')], x1=0, y1=0, x2=1, y2=0)
    return (f'<ellipse cx="{f(cx)}" cy="{f(base_y + 3)}" rx="{f(w * 0.6)}" ry="{f(w * 0.1)}" fill="#120604" opacity="0.4" filter="{s.blur(4)}"/>'
            f'<rect x="{f(cx - w / 2)}" y="{f(base_y - h)}" width="{f(w)}" height="{f(h)}" rx="{f(w * 0.18)}" fill="{body}" stroke="#FFFFFF" stroke-opacity="0.5" stroke-width="1.5"/>'
            f'<path d="M {f(cx - w * 0.1)},{f(base_y - h)} q {f(w * 0.25)},{f(-w * 0.35)} {f(w * 0.45)},0" stroke="#E8B02E" stroke-width="{f(w * 0.1)}" fill="none"/>'
            f'<rect x="{f(cx - w * 0.38)}" y="{f(base_y - h - w * 0.16)}" width="{f(w * 0.24)}" height="{f(w * 0.2)}" rx="3" fill="#C62828"/>'
            f'<rect x="{f(cx - w * 0.4)}" y="{f(base_y - h * 0.62)}" width="{f(w * 0.8)}" height="{f(h * 0.32)}" rx="6" fill="#FFF8E1"/>'
            f'<rect x="{f(cx - w * 0.32)}" y="{f(base_y - h * 0.55)}" width="{f(w * 0.64)}" height="{f(h * 0.09)}" rx="3" fill="#C62828"/>'
            f'<rect x="{f(cx - w * 0.32)}" y="{f(base_y - h * 0.42)}" width="{f(w * 0.4)}" height="{f(h * 0.05)}" rx="2" fill="#2E7D32"/>'
            f'<rect x="{f(cx - w * 0.38)}" y="{f(base_y - h * 0.95)}" width="{f(w * 0.1)}" height="{f(h * 0.28)}" rx="3" fill="#FFFFFF" opacity="0.35"/>')


def banner_lamps():
    s = SVG(W, H, seed=713)
    dusk(s, W, H, glow=(830, 320, 420))
    s.add(stars(s, 560, W, 10, 250, 40))
    s.add(hill(s, 600, 1150, 330, 880, 120))
    s.add(beacon(s, 880, 126, 26))
    s.add(steps_of_lamps(s, 830, 540, [500, 400, 300], 70))
    s.add(oil_can(s, 610, 525, 90))
    s.add(ghee_jar(s, 1020, 525, 60))
    for x, y, r in [(620, 160, 10), (1040, 200, 9)]:
        s.add(sparkle(s, x, y, r))
    s.save(f'{OUT}/banner_lamps.svg')


def banner_kolam():
    s = SVG(W, H, seed=717)
    s.add(f'<rect width="{W}" height="{H}" fill="{s.lin([(0, "#FFF9F4"), (0.55, "#FFE9DA"), (1, "#FFD2B8")], x1=0, y1=0, x2=1, y2=0.6)}"/>')
    s.add(f'<rect width="{W}" height="{H}" fill="{s.rad([(0, "#FFFFFF", 0.65), (1, "#FFFFFF", 0)], cx=800, cy=270, r=360, units="userSpaceOnUse")}"/>')
    s.add(f'<g transform="translate(820 330) scale(1 0.62)">{colour_kolam(s, 0, 0, 220)}</g>')
    for i in range(10):
        a = math.radians(i * 36)
        x, y = 820 + math.cos(a) * 250, 330 + math.sin(a) * 150
        if 560 < x < 1060:
            s.add(agal(s, x, y - 10, 40, i % 3))
            s.add(flame(s, x, y - 10, 8, 20))
    for x, c in [(640, '#E91E63'), (720, '#FFC107'), (960, '#43A047'), (1030, '#1E88E5')]:
        s.add(colour_bowl(s, x, 505, 34, c))
    for i, x in enumerate((600, 880, 1000)):
        s.add(marigold(s, x, 90 + i * 20, 16, 'orange') if i % 2 == 0 else malli(s, x, 100, 12))
    s.save(f'{OUT}/banner_kolam.svg')


def btn_tile():
    """Seamless tile of tiny flames for festive buttons: 192 × 192 (64 dp)."""
    s = SVG(192, 192, seed=719)
    out = []
    for x, y in ((48, 52), (144, 148)):
        out.append(f'<path d="M {x},{y - 14} C {x + 4},{y - 8} {x + 8},{y - 2} {x + 6},{y + 4} C {x + 4},{y + 8} {x - 4},{y + 8} {x - 6},{y + 4} C {x - 8},{y - 2} {x - 4},{y - 8} {x},{y - 14} Z" fill="#FFF3C4" opacity="0.4"/>')
    for x, y in ((144, 48), (48, 144)):
        out.append(f'<circle cx="{x}" cy="{y}" r="2.4" fill="#FFF3C4" opacity="0.45"/>')
    s.add(''.join(out))
    s.save(f'{OUT}/btn_tile.svg')


def section_icon():
    s = SVG(96, 96, seed=721)
    s.add(agal(s, 48, 44, 70, 1))
    s.add(flame(s, 48, 44, 13, 34, glow=False))
    s.save(f'{OUT}/section_icon.svg')


def petals():
    s = SVG(48, 48, seed=3)
    g = s.rad([(0, '#FFB74D'), (1, '#E65100')], cx=0.35, cy=0.35, r=0.75)
    s.add(f'<path d="M 24,4 C 38,8 44,22 36,36 C 30,44 18,44 12,36 C 4,22 10,8 24,4 Z" fill="{g}"/>'); s.save(f'{OUT}/petal_1.svg')
    s = SVG(48, 48, seed=4); s.add(malli(s, 24, 24, 19)); s.save(f'{OUT}/petal_2.svg')
    s = SVG(48, 48, seed=5); s.add(star4(24, 24, 20, '#FFE082') + star4(24, 24, 11, '#FFFFFF', rot=45, thin=0.3)); s.save(f'{OUT}/petal_3.svg')
    s = SVG(72, 72, seed=6); s.add(agal(s, 36, 34, 52, 0)); s.add(flame(s, 36, 34, 10, 24, glow=False)); s.save(f'{OUT}/petal_4.svg')


if __name__ == '__main__':
    banner_sweets()
    banner_lamps()
    banner_kolam()
    btn_tile()
    section_icon()
    petals()
    print('ok')
