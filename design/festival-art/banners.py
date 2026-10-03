import math
from svgkit import *

OUT = 'out'
W, H = 1080, 540


def frame(s, dark=False):
    c = '#F6C445' if dark else '#D9962B'
    return (f'<rect x="14" y="14" width="{W - 28}" height="{H - 28}" rx="34" fill="none" stroke="{c}" stroke-opacity="{0.55 if dark else 0.45}" stroke-width="2.5"/>'
            f'<rect x="24" y="24" width="{W - 48}" height="{H - 48}" rx="26" fill="none" stroke="{c}" stroke-opacity="{0.3 if dark else 0.25}" stroke-width="1.2" stroke-dasharray="2 6" stroke-linecap="round"/>')


def swag(s, x1, x2, y, sag, n, r=17):
    """Marigold garland swag hanging between two points."""
    out = []
    pts = []
    for i in range(n):
        t = i / (n - 1)
        x = x1 + (x2 - x1) * t
        yy = y + sag * 4 * t * (1 - t)
        pts.append((x, yy))
    for i, (x, yy) in enumerate(pts):
        out.append(marigold(s, x, yy, r, ['orange', 'yellow', 'deep'][i % 3] if i % 4 != 3 else 'yellow'))
        if i % 3 == 1:
            out.append(mango_leaf(s, x + 4, yy + r * 0.4, r * 2.8, r * 1.0, angle=-12 + (i % 2) * 24, tone=i))
    return ''.join(out)


def laddoo(s, cx, cy, r):
    g = s.rad([(0, '#FFE0A3'), (0.35, '#FFB547'), (0.75, '#F08A0C'), (1, '#B85A00')], cx=0.38, cy=0.32, r=0.75)
    clip = s.clip(f'<circle cx="{f(cx)}" cy="{f(cy)}" r="{f(r)}"/>')
    rnd = s.rnd
    dots = []
    for _ in range(int(r * 2.2)):
        a = rnd.uniform(0, math.tau)
        d = math.sqrt(rnd.uniform(0, 1)) * r
        x, y = cx + math.cos(a) * d, cy + math.sin(a) * d
        col = rnd.choice(['#FFD27A', '#F59E0B', '#D97706', '#FFE3A8'])
        dots.append(f'<circle cx="{f(x)}" cy="{f(y)}" r="{f(r * rnd.uniform(0.07, 0.11))}" fill="{col}" opacity="0.75"/>')
    return (f'<circle cx="{f(cx + r * 0.08)}" cy="{f(cy + r * 0.2)}" r="{f(r)}" fill="#5A1A00" opacity="0.35" filter="{s.blur(r * 0.12)}"/>'
            f'<circle cx="{f(cx)}" cy="{f(cy)}" r="{f(r)}" fill="{g}"/>'
            f'<g clip-path="{clip}">{"".join(dots)}<circle cx="{f(cx + r * 0.25)}" cy="{f(cy + r * 0.35)}" r="{f(r * 0.95)}" fill="#7A3300" opacity="0.18" filter="{s.blur(r * 0.25)}"/></g>'
            f'<ellipse cx="{f(cx - r * 0.35)}" cy="{f(cy - r * 0.42)}" rx="{f(r * 0.28)}" ry="{f(r * 0.16)}" fill="#FFFFFF" opacity="0.35" transform="rotate(-30 {f(cx - r * 0.35)} {f(cy - r * 0.42)})" filter="{s.blur(r * 0.05)}"/>')


def brass_plate(s, cx, cy, rx, ry):
    g = s.lin([(0, '#FFF0B3'), (0.3, '#F2C14E'), (0.65, '#C98A12'), (1, '#8A5A00')], x1=0, y1=0, x2=1, y2=1)
    g2 = s.lin([(0, '#B07A10'), (0.5, '#E6B23A'), (1, '#9A6A0A')], x1=0, y1=0, x2=1, y2=0)
    return (f'<ellipse cx="{f(cx)}" cy="{f(cy + ry * 0.35)}" rx="{f(rx * 1.02)}" ry="{f(ry * 0.9)}" fill="#2B0A00" opacity="0.35" filter="{s.blur(ry * 0.25)}"/>'
            f'<ellipse cx="{f(cx)}" cy="{f(cy + ry * 0.12)}" rx="{f(rx)}" ry="{f(ry)}" fill="{g2}"/>'
            f'<ellipse cx="{f(cx)}" cy="{f(cy)}" rx="{f(rx)}" ry="{f(ry)}" fill="{g}"/>'
            f'<ellipse cx="{f(cx)}" cy="{f(cy + ry * 0.05)}" rx="{f(rx * 0.78)}" ry="{f(ry * 0.66)}" fill="none" stroke="#9A6A0A" stroke-opacity="0.55" stroke-width="2"/>'
            f'<ellipse cx="{f(cx)}" cy="{f(cy + ry * 0.05)}" rx="{f(rx * 0.7)}" ry="{f(ry * 0.58)}" fill="none" stroke="#FFF6D6" stroke-opacity="0.6" stroke-width="1.5" stroke-dasharray="3 7"/>'
            f'<path d="M {f(cx - rx * 0.85)},{f(cy - ry * 0.25)} Q {f(cx - rx * 0.4)},{f(cy - ry * 0.95)} {f(cx + rx * 0.3)},{f(cy - ry * 0.92)}" stroke="#FFFFFF" stroke-opacity="0.55" stroke-width="3" fill="none" stroke-linecap="round"/>')


def giftbox(s, x, y, w, h, body=('#8E1B2E', '#5E0F1F'), ribbon='gold', lid_h=None, pattern=True):
    lid_h = lid_h or h * 0.22
    gb = s.lin([(0, body[0]), (1, body[1])], x1=0, y1=0, x2=1, y2=1)
    gl = s.lin([(0, body[0]), (1, body[1])], x1=0, y1=0, x2=0, y2=1)
    gr = s.lin([(0, '#FFF1B8'), (0.4, '#F6C445'), (0.8, '#C98A12'), (1, '#9A6A0A')], x1=0, y1=0, x2=1, y2=0)
    out = [f'<rect x="{f(x + 8)}" y="{f(y + 14)}" width="{f(w)}" height="{f(h)}" rx="6" fill="#200006" opacity="0.35" filter="{s.blur(9)}"/>',
           f'<rect x="{f(x)}" y="{f(y + lid_h * 0.6)}" width="{f(w)}" height="{f(h - lid_h * 0.6)}" rx="5" fill="{gb}"/>']
    if pattern:
        clip = s.clip(f'<rect x="{f(x)}" y="{f(y + lid_h * 0.6)}" width="{f(w)}" height="{f(h - lid_h * 0.6)}" rx="5"/>')
        pts = []
        step = w / 5
        for i in range(7):
            for j in range(9):
                px, py = x + (i - 0.5) * step + (j % 2) * step / 2, y + lid_h + j * step * 0.55
                pts.append(f'<path d="M {f(px)},{f(py - 5)} L {f(px + 4)},{f(py)} L {f(px)},{f(py + 5)} L {f(px - 4)},{f(py)} Z" fill="#F6C445" opacity="0.28"/>')
        out.append(f'<g clip-path="{clip}">{"".join(pts)}</g>')
    out.append(f'<rect x="{f(x - w * 0.04)}" y="{f(y)}" width="{f(w * 1.08)}" height="{f(lid_h)}" rx="5" fill="{gl}"/>')
    out.append(f'<rect x="{f(x - w * 0.04)}" y="{f(y + lid_h - 4)}" width="{f(w * 1.08)}" height="5" fill="#000" opacity="0.18"/>')
    out.append(f'<rect x="{f(x + w * 0.42)}" y="{f(y)}" width="{f(w * 0.16)}" height="{f(h)}" fill="{gr}"/>')
    # bow
    bx, by = x + w * 0.5, y
    out.append(f'<path d="M {f(bx)},{f(by)} C {f(bx - w * 0.38)},{f(by - h * 0.32)} {f(bx - w * 0.48)},{f(by + h * 0.04)} {f(bx)},{f(by)} Z" fill="{gr}" stroke="#9A6A0A" stroke-width="1.2"/>')
    out.append(f'<path d="M {f(bx)},{f(by)} C {f(bx + w * 0.38)},{f(by - h * 0.32)} {f(bx + w * 0.48)},{f(by + h * 0.04)} {f(bx)},{f(by)} Z" fill="{gr}" stroke="#9A6A0A" stroke-width="1.2"/>')
    out.append(f'<path d="M {f(bx - 3)},{f(by + 2)} L {f(bx - w * 0.2)},{f(by + h * 0.3)} L {f(bx - w * 0.1)},{f(by + h * 0.3)} Z" fill="{gr}"/>')
    out.append(f'<path d="M {f(bx + 3)},{f(by + 2)} L {f(bx + w * 0.2)},{f(by + h * 0.3)} L {f(bx + w * 0.1)},{f(by + h * 0.3)} Z" fill="{gr}"/>')
    out.append(f'<circle cx="{f(bx)}" cy="{f(by)}" r="{f(w * 0.06)}" fill="#E0A82E" stroke="#9A6A0A" stroke-width="1"/>')
    out.append(f'<rect x="{f(x + w * 0.06)}" y="{f(y + lid_h + 6)}" width="{f(w * 0.08)}" height="{f(h * 0.5)}" rx="3" fill="#FFFFFF" opacity="0.10"/>')
    return ''.join(out)


def murukku(s, cx, cy, r, turns=3.2):
    """Tamil murukku: a crunchy golden spiral."""
    pts = []
    n = 160
    for i in range(n + 1):
        t = i / n
        a = t * turns * math.tau
        rr = r * (0.12 + 0.88 * t)
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr * 0.92))
    d = 'M ' + ' L '.join(f'{f(x)},{f(y)}' for x, y in pts)
    sw = r * 0.2
    rnd = s.rnd
    bumps = ''.join(f'<circle cx="{f(x + rnd.uniform(-2, 2))}" cy="{f(y + rnd.uniform(-2, 2))}" r="{f(sw * rnd.uniform(0.18, 0.3))}" fill="{rnd.choice(["#F7C873", "#B76E1B", "#E3A245"])}" opacity="0.8"/>'
                    for x, y in pts[8::3])
    return (f'<path d="{d}" stroke="#3A1600" stroke-opacity="0.35" stroke-width="{f(sw * 1.15)}" fill="none" stroke-linecap="round" transform="translate(5 9)" filter="{s.blur(5)}"/>'
            f'<path d="{d}" stroke="#A86016" stroke-width="{f(sw * 1.1)}" fill="none" stroke-linecap="round" stroke-linejoin="round"/>'
            f'<path d="{d}" stroke="#E3A245" stroke-width="{f(sw * 0.8)}" fill="none" stroke-linecap="round" stroke-linejoin="round"/>'
            f'<path d="{d}" stroke="#FFD992" stroke-opacity="0.8" stroke-width="{f(sw * 0.25)}" fill="none" stroke-linecap="round" transform="translate(-2 -3)"/>'
            f'{bumps}')


def petals(s, x0, x1, y0, y1, n, colors=('#FB8C00', '#FDD835', '#F4511E')):
    rnd = s.rnd
    return ''.join(_petal(s, rnd.uniform(x0, x1), rnd.uniform(y0, y1), rnd.uniform(7, 11), rnd.choice(colors), rnd.uniform(0, 180)) for _ in range(n))


def _petal(s, x, y, r, c, a):
    return f'<ellipse cx="{f(x)}" cy="{f(y)}" rx="{f(r)}" ry="{f(r * 0.5)}" fill="{c}" transform="rotate({f(a)} {f(x)} {f(y)})"/>'


# ── Banner 1: Deepavali sweets & savouries (light) ──
def banner_sweets():
    s = SVG(W, H, seed=31)
    s.add(f'<rect width="{W}" height="{H}" fill="{s.lin([(0, "#FFF8EA"), (0.55, "#FFE6BC"), (1, "#FFCF8A")], x1=0, y1=0, x2=1, y2=0.6)}"/>')
    s.add(f'<rect width="{W}" height="{H}" fill="{s.rad([(0, "#FFFFFF", 0.7), (1, "#FFFFFF", 0)], cx=780, cy=250, r=380, units="userSpaceOnUse")}"/>')
    s.add(mandala(s, 800, 270, 330, color='#D9962B', opacity=0.20, stroke=2.2, fill_opacity=0.06))
    s.add(swag(s, 560, 1060, 22, 70, 13, r=16))
    # murukku stack (back right)
    s.add(murukku(s, 960, 330, 74))
    s.add(murukku(s, 900, 400, 66, turns=2.9))
    # gift box (back)
    s.add(giftbox(s, 610, 250, 120, 150, body=('#C2185B', '#7B0E3A')))
    # plate + laddoos
    s.add(brass_plate(s, 790, 448, 175, 44))
    for (dx, dy, r) in [(-90, -30, 46), (0, -26, 48), (90, -30, 46), (-45, -98, 46), (45, -98, 46), (0, -164, 45)]:
        s.add(laddoo(s, 790 + dx, 448 + dy, r))
    # pistachio slivers on top laddoo
    for (dx, dy, a) in [(-8, -200, -20), (10, -196, 25)]:
        s.add(f'<ellipse cx="{790 + dx}" cy="{448 + dy}" rx="9" ry="3.5" fill="#8BC34A" transform="rotate({a} {790 + dx} {448 + dy})"/>')
    s.add(diya(s, 1000, 430, 92, style=1))
    s.add(petals(s, 560, 1060, 470, 515, 14))
    for x, y, r in [(640, 110, 13), (1030, 220, 10), (720, 190, 8), (880, 140, 11), (585, 420, 9)]:
        s.add(sparkle(s, x, y, r, color='#FFFFFF', glow='#FFB300'))
    s.save(f'{OUT}/banner_sweets.svg')


# ── Banner 2: Pooja essentials — brass kuthu vilakku (dark) ──
KUTHU_SPOUTS = [(-0.31, 0.0), (-0.17, 0.03), (0.17, 0.03), (0.31, 0.0), (0, 0.045)]


def kuthuvilakku_wicks(cx, base_y, height):
    """Where the five flames of kuthuvilakku(…, with_flames=False) burn: (x, y of the flame base)."""
    Hh = height
    bowl_y = base_y - Hh * 0.66
    return [(cx + Hh * dx + (Hh * 0.05 if dx > 0 else -Hh * 0.05 if dx < 0 else 0), bowl_y + Hh * dy - Hh * 0.035) for dx, dy in KUTHU_SPOUTS]


def kuthuvilakku(s, cx, base_y, height, with_flames=True):
    Hh = height
    gold = s.lin([(0, '#7A4E00'), (0.18, '#C98A12'), (0.42, '#FFE7A0'), (0.6, '#F2C14E'), (0.85, '#B07A10'), (1, '#6B4300')], x1=0, y1=0, x2=1, y2=0)
    def disc(y, rx, ry, thick):
        return (f'<ellipse cx="{f(cx)}" cy="{f(y + thick)}" rx="{f(rx)}" ry="{f(ry)}" fill="#6B4300"/>'
                f'<rect x="{f(cx - rx)}" y="{f(y)}" width="{f(rx * 2)}" height="{f(thick)}" fill="{gold}"/>'
                f'<ellipse cx="{f(cx)}" cy="{f(y)}" rx="{f(rx)}" ry="{f(ry)}" fill="{gold}"/>'
                f'<ellipse cx="{f(cx)}" cy="{f(y)}" rx="{f(rx * 0.9)}" ry="{f(ry * 0.8)}" fill="none" stroke="#FFF3C4" stroke-opacity="0.45" stroke-width="1.5"/>')
    def bulb(y, rx, ry):
        return (f'<ellipse cx="{f(cx)}" cy="{f(y)}" rx="{f(rx)}" ry="{f(ry)}" fill="{gold}"/>'
                f'<ellipse cx="{f(cx - rx * 0.35)}" cy="{f(y - ry * 0.3)}" rx="{f(rx * 0.18)}" ry="{f(ry * 0.4)}" fill="#FFFFFF" opacity="0.35"/>')
    out = [f'<ellipse cx="{f(cx)}" cy="{f(base_y + 8)}" rx="{f(Hh * 0.33)}" ry="{f(Hh * 0.05)}" fill="#000" opacity="0.45" filter="{s.blur(10)}"/>']
    y = base_y
    out.append(disc(y - Hh * 0.06, Hh * 0.27, Hh * 0.05, Hh * 0.05))
    out.append(disc(y - Hh * 0.12, Hh * 0.2, Hh * 0.04, Hh * 0.035))
    out.append(bulb(y - Hh * 0.17, Hh * 0.1, Hh * 0.04))
    # stem
    out.append(f'<rect x="{f(cx - Hh * 0.03)}" y="{f(y - Hh * 0.62)}" width="{f(Hh * 0.06)}" height="{f(Hh * 0.46)}" fill="{gold}"/>')
    for t in (0.3, 0.45):
        out.append(bulb(y - Hh * t, Hh * 0.06, Hh * 0.025))
    out.append(bulb(y - Hh * 0.6, Hh * 0.08, Hh * 0.03))
    # lamp bowl with 5 spouts (3 visible flames)
    bowl_y = y - Hh * 0.66
    out.append(f'<path d="M {f(cx - Hh * 0.3)},{f(bowl_y)} Q {f(cx)},{f(bowl_y + Hh * 0.14)} {f(cx + Hh * 0.3)},{f(bowl_y)} Z" fill="{gold}"/>')
    out.append(f'<ellipse cx="{f(cx)}" cy="{f(bowl_y)}" rx="{f(Hh * 0.3)}" ry="{f(Hh * 0.045)}" fill="{gold}"/>')
    out.append(f'<ellipse cx="{f(cx)}" cy="{f(bowl_y)}" rx="{f(Hh * 0.25)}" ry="{f(Hh * 0.032)}" fill="#6B3A00"/>')
    spouts = KUTHU_SPOUTS
    flames_ = []
    for dx, dy in spouts:
        sx, sy = cx + Hh * dx, bowl_y + Hh * dy
        out.append(f'<path d="M {f(sx - Hh * 0.03)},{f(sy - Hh * 0.01)} L {f(sx + (Hh * 0.05 if dx > 0 else -Hh * 0.05 if dx < 0 else 0))},{f(sy - Hh * 0.035)} L {f(sx + Hh * 0.03)},{f(sy - Hh * 0.01)} Z" fill="{gold}"/>')
        flames_.append(flame(s, sx + (Hh * 0.05 if dx > 0 else -Hh * 0.05 if dx < 0 else 0), sy - Hh * 0.035, Hh * 0.05, Hh * 0.13))
    # top finial: kalasam + annam (swan) silhouette
    out.append(f'<rect x="{f(cx - Hh * 0.02)}" y="{f(bowl_y - Hh * 0.2)}" width="{f(Hh * 0.04)}" height="{f(Hh * 0.2)}" fill="{gold}"/>')
    out.append(bulb(bowl_y - Hh * 0.12, Hh * 0.05, Hh * 0.025))
    ty = bowl_y - Hh * 0.22
    out.append(f'<path d="M {f(cx - Hh * 0.07)},{f(ty + Hh * 0.04)} Q {f(cx - Hh * 0.07)},{f(ty - Hh * 0.04)} {f(cx)},{f(ty - Hh * 0.05)} Q {f(cx + Hh * 0.03)},{f(ty - Hh * 0.14)} {f(cx + Hh * 0.075)},{f(ty - Hh * 0.13)} '
               f'L {f(cx + Hh * 0.1)},{f(ty - Hh * 0.115)} L {f(cx + Hh * 0.07)},{f(ty - Hh * 0.105)} Q {f(cx + Hh * 0.035)},{f(ty - Hh * 0.1)} {f(cx + Hh * 0.05)},{f(ty - Hh * 0.03)} '
               f'Q {f(cx + Hh * 0.08)},{f(ty + Hh * 0.04)} {f(cx - Hh * 0.07)},{f(ty + Hh * 0.04)} Z" fill="{gold}" stroke="#6B4300" stroke-width="1"/>')
    if with_flames:
        out.append(''.join(flames_))
    return ''.join(out)


def jasmine_string(s, x1, y1, x2, y2, sag, n):
    out = []
    for i in range(n):
        t = i / (n - 1)
        x = x1 + (x2 - x1) * t
        y = y1 + (y2 - y1) * t + sag * 4 * t * (1 - t)
        r = 7.5
        for k in range(5):
            a = math.radians(k * 72 + i * 17)
            px, py = x + math.cos(a) * r * 0.55, y + math.sin(a) * r * 0.55
            out.append(f'<ellipse cx="{f(px)}" cy="{f(py)}" rx="{f(r * 0.55)}" ry="{f(r * 0.32)}" transform="rotate({f(math.degrees(a))} {f(px)} {f(py)})" fill="#FFFDF5" stroke="#E0D7C3" stroke-width="0.6"/>')
        out.append(f'<circle cx="{f(x)}" cy="{f(y)}" r="2.2" fill="#F9E79F"/>')
    return ''.join(out)


def banner_pooja():
    s = SVG(W, H, seed=41)
    s.add(f'<rect width="{W}" height="{H}" fill="{s.lin([(0, "#3A0716"), (0.5, "#5E0F22"), (1, "#7E1726")], x1=0, y1=0, x2=1, y2=0.8)}"/>')
    s.add(f'<rect width="{W}" height="{H}" fill="{s.rad([(0, "#FF9800", 0.55), (0.5, "#E65100", 0.18), (1, "#E65100", 0)], cx=820, cy=230, r=380, units="userSpaceOnUse")}"/>')
    s.add(mandala(s, 820, 250, 330, color='#FFD54F', opacity=0.16, stroke=2.2))
    for _ in range(10):
        s.add(bokeh(s, s.rnd.uniform(560, 1060), s.rnd.uniform(40, 500), s.rnd.uniform(14, 44), '#FFCA28', s.rnd.uniform(0.12, 0.28)))
    s.add(jasmine_string(s, 580, 40, 1050, 40, 60, 26))
    s.add(kuthuvilakku(s, 830, 492, 420))
    # incense with smoke
    s.add(f'<line x1="1002" y1="500" x2="1032" y2="330" stroke="#5D4037" stroke-width="4" stroke-linecap="round"/>')
    s.add(f'<circle cx="1032" cy="330" r="4" fill="#FF7043"/><circle cx="1032" cy="330" r="9" fill="#FF7043" opacity="0.4" filter="{s.blur(4)}"/>')
    s.add(f'<path d="M 1032,326 C 1012,290 1052,260 1030,220 C 1010,186 1046,160 1026,120" stroke="#FFFFFF" stroke-opacity="0.35" stroke-width="5" fill="none" stroke-linecap="round" filter="{s.blur(2.5)}"/>')
    s.add(f'<path d="M 1032,326 C 1050,300 1020,270 1040,240" stroke="#FFFFFF" stroke-opacity="0.25" stroke-width="3" fill="none" stroke-linecap="round" filter="{s.blur(2)}"/>')
    s.add(diya(s, 640, 452, 96, style=0))
    s.add(diya(s, 1010, 470, 70, style=2))
    for x, y, k in [(560, 500, 'orange'), (600, 512, 'yellow'), (700, 506, 'deep'), (960, 508, 'yellow'), (920, 514, 'orange')]:
        s.add(marigold(s, x, y, 20, k))
    s.add(petals(s, 560, 1060, 480, 525, 12))
    for x, y, r in [(600, 150, 10), (1040, 180, 9), (700, 90, 8), (960, 110, 12)]:
        s.add(sparkle(s, x, y, r))
    s.save(f'{OUT}/banner_pooja.svg')


# ── Banner 3: Dry fruits & gift hampers (light peach) ──
def almond(s, x, y, size, a):
    g = s.lin([(0, '#D4A373'), (0.5, '#A86B3C'), (1, '#7A4520')], x1=0, y1=0, x2=1, y2=1)
    d = f'M 0,{f(-size)} C {f(size * 0.62)},{f(-size * 0.55)} {f(size * 0.55)},{f(size * 0.7)} 0,{f(size)} C {f(-size * 0.55)},{f(size * 0.7)} {f(-size * 0.62)},{f(-size * 0.55)} 0,{f(-size)} Z'
    lines = ''.join(f'<path d="M {f(t * size * 0.4)},{f(-size * 0.7)} Q {f(t * size * 0.5)},0 {f(t * size * 0.35)},{f(size * 0.75)}" stroke="#6B3A1A" stroke-opacity="0.35" stroke-width="1.2" fill="none"/>' for t in (-0.6, -0.2, 0.2, 0.6))
    return (f'<g transform="translate({f(x)} {f(y)}) rotate({f(a)})"><path d="{d}" fill="#3A1A08" opacity="0.3" transform="translate(3 4)" filter="{s.blur(2.5)}"/>'
            f'<path d="{d}" fill="{g}"/>{lines}<ellipse cx="{f(-size * 0.18)}" cy="{f(-size * 0.35)}" rx="{f(size * 0.12)}" ry="{f(size * 0.32)}" fill="#FFF" opacity="0.22"/></g>')


def cashew(s, x, y, size, a):
    g = s.lin([(0, '#FFF6DF'), (0.6, '#F1D9A8'), (1, '#D9B67A')], x1=0, y1=0, x2=1, y2=1)
    R = size
    d = (f'M {f(-R)},0 A {f(R)},{f(R)} 0 0 1 {f(R)},0 Q {f(R * 1.05)},{f(R * 0.5)} {f(R * 0.6)},{f(R * 0.5)} '
         f'A {f(R * 0.48)},{f(R * 0.48)} 0 0 0 {f(-R * 0.6)},{f(R * 0.5)} Q {f(-R * 1.05)},{f(R * 0.5)} {f(-R)},0 Z')
    return (f'<g transform="translate({f(x)} {f(y)}) rotate({f(a)})"><path d="{d}" fill="#5A3A10" opacity="0.28" transform="translate(3 4)" filter="{s.blur(2.5)}"/>'
            f'<path d="{d}" fill="{g}" stroke="#C9A063" stroke-width="1"/><path d="M {f(-R * 0.7)},{f(-R * 0.3)} A {f(R * 0.8)},{f(R * 0.8)} 0 0 1 {f(R * 0.3)},{f(-R * 0.75)}" stroke="#FFFFFF" stroke-opacity="0.6" stroke-width="2.5" fill="none" stroke-linecap="round"/></g>')


def pistachio(s, x, y, size, a):
    return (f'<g transform="translate({f(x)} {f(y)}) rotate({f(a)})">'
            f'<ellipse rx="{f(size)}" ry="{f(size * 0.7)}" fill="#E8D5B0" stroke="#BFA77A" stroke-width="1.2"/>'
            f'<ellipse cx="{f(size * 0.15)}" rx="{f(size * 0.55)}" ry="{f(size * 0.42)}" fill="#7CB342"/>'
            f'<ellipse cx="{f(size * 0.25)}" cy="{f(-size * 0.1)}" rx="{f(size * 0.25)}" ry="{f(size * 0.15)}" fill="#C5E1A5" opacity="0.7"/></g>')


def raisin(s, x, y, size, a):
    return (f'<g transform="translate({f(x)} {f(y)}) rotate({f(a)})"><ellipse rx="{f(size)}" ry="{f(size * 0.72)}" fill="#5D2A42"/>'
            f'<path d="M {f(-size * 0.6)},{f(-size * 0.1)} Q 0,{f(size * 0.2)} {f(size * 0.6)},{f(-size * 0.15)}" stroke="#2E1020" stroke-width="1.4" fill="none"/>'
            f'<ellipse cx="{f(-size * 0.3)}" cy="{f(-size * 0.3)}" rx="{f(size * 0.25)}" ry="{f(size * 0.12)}" fill="#FFFFFF" opacity="0.3"/></g>')


def basket(s, cx, top, w, h):
    gb = s.lin([(0, '#D8964A'), (0.5, '#B0702F'), (1, '#7E4A1E')], x1=0, y1=0, x2=0, y2=1)
    x0, x1 = cx - w / 2, cx + w / 2
    d = f'M {f(x0)},{f(top)} L {f(x1)},{f(top)} L {f(x1 - w * 0.1)},{f(top + h)} Q {f(cx)},{f(top + h * 1.08)} {f(x0 + w * 0.1)},{f(top + h)} Z'
    clip = s.clip(f'<path d="{d}"/>')
    weave = []
    rows = 7
    band_h = h / rows
    stakes = 11
    for r in range(rows):
        y = top + r * band_h
        for c in range(stakes + 1):
            seg_w = w / stakes
            x = x0 + c * seg_w - (seg_w / 2 if r % 2 else 0)
            light = (c + r) % 2 == 0
            col = s.lin([(0, '#F7C98A' if light else '#D9964F'), (1, '#C27C3A' if light else '#9A5C27')], x1=0, y1=0, x2=0, y2=1)
            weave.append(f'<rect x="{f(x + 1)}" y="{f(y + 1.5)}" width="{f(seg_w - 2)}" height="{f(band_h - 3)}" rx="{f(band_h * 0.45)}" fill="{col}"/>')
    for c in range(stakes + 1):
        x = x0 + c * w / stakes
        weave.append(f'<line x1="{f(x)}" y1="{f(top)}" x2="{f(x)}" y2="{f(top + h)}" stroke="#6B3A12" stroke-opacity="0.35" stroke-width="2"/>')
    return (f'<ellipse cx="{f(cx)}" cy="{f(top + h + 12)}" rx="{f(w * 0.52)}" ry="{f(h * 0.12)}" fill="#5A2A10" opacity="0.3" filter="{s.blur(10)}"/>'
            f'<path d="{d}" fill="{gb}"/><g clip-path="{clip}">{"".join(weave)}'
            f'<rect x="{f(x0)}" y="{f(top)}" width="{f(w)}" height="{f(h)}" fill="{s.lin([(0, "#000", 0), (0.7, "#000", 0), (1, "#2B1200", 0.35)], x1=0, y1=0, x2=0, y2=1)}"/></g>'
            f'<rect x="{f(x0 - 10)}" y="{f(top - 12)}" width="{f(w + 20)}" height="26" rx="13" fill="{s.lin([(0, "#F3B96B"), (1, "#9C5D27")])}"/>'
            f'<rect x="{f(x0 - 10)}" y="{f(top - 12)}" width="{f(w + 20)}" height="26" rx="13" fill="none" stroke="#6B3A12" stroke-opacity="0.45" stroke-width="1.5" stroke-dasharray="7 5"/>')


def banner_hamper():
    s = SVG(W, H, seed=51)
    s.add(f'<rect width="{W}" height="{H}" fill="{s.lin([(0, "#FFF4EC"), (0.6, "#FFE0CF"), (1, "#FFC9B0")], x1=0, y1=0, x2=1, y2=0.6)}"/>')
    s.add(f'<rect width="{W}" height="{H}" fill="{s.rad([(0, "#FFFFFF", 0.65), (1, "#FFFFFF", 0)], cx=800, cy=260, r=360, units="userSpaceOnUse")}"/>')
    s.add(mandala(s, 810, 270, 320, color='#E07B53', opacity=0.18, stroke=2.0, fill_opacity=0.05))
    cx, top, bw, bh = 800, 318, 340, 176
    # handle
    s.add(f'<path d="M {cx - 150},{top} C {cx - 150},{top - 250} {cx + 150},{top - 250} {cx + 150},{top}" stroke="#8A5222" stroke-width="22" fill="none" stroke-linecap="round"/>')
    s.add(f'<path d="M {cx - 150},{top} C {cx - 150},{top - 250} {cx + 150},{top - 250} {cx + 150},{top}" stroke="#E0A458" stroke-width="12" fill="none" stroke-linecap="round" stroke-dasharray="14 8"/>')
    # dry fruit heap
    rnd = s.rnd
    items = []
    cand = []
    for _ in range(130):
        x = cx + rnd.uniform(-bw * 0.47, bw * 0.47)
        dome = 1 - ((x - cx) / (bw * 0.5)) ** 2
        yy = top + 6 - rnd.uniform(0, 1) * 105 * max(0.15, dome)
        cand.append((yy, x))
    cand.sort()
    for yy, x in cand:
        k = rnd.random()
        if k < 0.36:
            items.append(almond(s, x, yy, rnd.uniform(20, 25), rnd.uniform(-70, 70)))
        elif k < 0.7:
            items.append(cashew(s, x, yy, rnd.uniform(18, 22), rnd.uniform(-160, 160)))
        elif k < 0.86:
            items.append(pistachio(s, x, yy, rnd.uniform(14, 17), rnd.uniform(0, 180)))
        else:
            items.append(raisin(s, x, yy, rnd.uniform(10, 12), rnd.uniform(0, 180)))
    s.add(''.join(items))
    s.add(basket(s, cx, top, bw, bh))
    # ribbon bow on the basket front
    gr = s.lin([(0, '#FF8A80'), (0.5, '#E53935'), (1, '#B71C1C')], x1=0, y1=0, x2=1, y2=1)
    bx, by = cx, top + 40
    s.add(f'<path d="M {bx},{by} C {bx - 80},{by - 60} {bx - 100},{by + 30} {bx},{by} Z" fill="{gr}"/><path d="M {bx},{by} C {bx + 80},{by - 60} {bx + 100},{by + 30} {bx},{by} Z" fill="{gr}"/>'
          f'<path d="M {bx - 4},{by} L {bx - 40},{by + 70} L {bx - 18},{by + 66} Z" fill="{gr}"/><path d="M {bx + 4},{by} L {bx + 40},{by + 70} L {bx + 18},{by + 66} Z" fill="{gr}"/>'
          f'<circle cx="{bx}" cy="{by}" r="12" fill="#C62828"/>')
    # loose nuts in front
    for x, y, k in [(610, 500, 'a'), (650, 512, 'c'), (980, 505, 'c'), (1020, 498, 'a'), (690, 515, 'p'), (945, 515, 'r')]:
        s.add({'a': almond, 'c': cashew, 'p': pistachio, 'r': raisin}[k](s, x, y, 16 if k in 'ac' else 12, rnd.uniform(-60, 60)))
    s.add(diya(s, 1010, 420, 80, style=1))
    for x, y, r in [(620, 140, 11), (1020, 150, 10), (700, 70, 8), (930, 60, 12)]:
        s.add(sparkle(s, x, y, r, color='#FFFFFF', glow='#FF8A65'))
    s.save(f'{OUT}/banner_hamper.svg')


if __name__ == '__main__':
    banner_sweets()
    banner_pooja()
    banner_hamper()
    print('ok')
