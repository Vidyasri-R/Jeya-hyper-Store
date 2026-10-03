"""Christmas & New Year banners, button texture, section icon and falling sprites (out/christmas/)."""
import math

from svgkit import *
from banners import giftbox
from christmas_art import OUT, bauble, bow, firework, night, snowflake, star_points, warm_light, xmas_tree

W, H = 1080, 540


def holly(s, cx, cy, size, angle=0):
    g = s.lin([(0, '#2E7D32'), (1, '#1B5E20')], x1=0, y1=0, x2=1, y2=1)
    out = [f'<g transform="translate({f(cx)} {f(cy)}) rotate({f(angle)})">']
    for a in (-35, 35):
        L = size
        pts = []
        for i in range(7):
            t = i / 6
            x = t * L
            y = (math.sin(t * math.pi) * size * 0.32) * (1 if i % 2 else 0.6)
            pts.append((x, -y))
        back = [(x, y * -1) for x, y in reversed(pts)]
        d = 'M ' + ' L '.join(f'{f(x)},{f(y)}' for x, y in pts + back) + ' Z'
        out.append(f'<path d="{d}" fill="{g}" stroke="#0B3D14" stroke-width="1" transform="rotate({a})"/>')
        out.append(f'<line x1="0" y1="0" x2="{f(L * 0.95)}" y2="0" stroke="#A5D6A7" stroke-opacity="0.5" stroke-width="1.4" transform="rotate({a})"/>')
    for dx, dy in ((-0.08, 0.02), (0.08, 0.04), (0.0, -0.08)):
        out.append(f'<circle cx="{f(dx * size)}" cy="{f(dy * size)}" r="{f(size * 0.11)}" fill="#D32F2F"/><circle cx="{f(dx * size - size * 0.03)}" cy="{f(dy * size - size * 0.03)}" r="{f(size * 0.035)}" fill="#FFFFFF" opacity="0.7"/>')
    out.append('</g>')
    return ''.join(out)


def plum_cake(s, cx, cy, r):
    """Round plum cake with one slice cut, dark crumb dotted with fruit, glazed top."""
    h = r * 0.45
    ry = r * 0.32
    side = s.lin([(0, '#6D3A1C'), (0.5, '#8B4A22'), (1, '#4E2510')], x1=0, y1=0, x2=1, y2=0)
    top = s.rad([(0, '#C77B3E'), (1, '#7A3E1A')], cx=0.45, cy=0.4, r=0.7)
    rnd = s.rnd
    out = [f'<ellipse cx="{f(cx)}" cy="{f(cy + h + ry * 0.6)}" rx="{f(r * 1.25)}" ry="{f(ry * 0.9)}" fill="#ECEFF1"/>',
           f'<ellipse cx="{f(cx)}" cy="{f(cy + h + ry * 0.5)}" rx="{f(r * 1.25)}" ry="{f(ry * 0.9)}" fill="none" stroke="#B0BEC5" stroke-width="2"/>',
           f'<path d="M {f(cx - r)},{f(cy)} L {f(cx - r)},{f(cy + h)} A {f(r)},{f(ry)} 0 0 0 {f(cx + r)},{f(cy + h)} L {f(cx + r)},{f(cy)} Z" fill="{side}"/>']
    clip = s.clip(f'<path d="M {f(cx - r)},{f(cy)} L {f(cx - r)},{f(cy + h)} A {f(r)},{f(ry)} 0 0 0 {f(cx + r)},{f(cy + h)} L {f(cx + r)},{f(cy)} Z"/>')
    fruit = ''.join(f'<circle cx="{f(cx + rnd.uniform(-r, r))}" cy="{f(cy + rnd.uniform(0, h + ry))}" r="{f(r * rnd.uniform(0.025, 0.05))}" fill="{rnd.choice(["#D32F2F", "#388E3C", "#FBC02D", "#3E1F0D"])}"/>' for _ in range(70))
    out.append(f'<g clip-path="{clip}">{fruit}</g>')
    out.append(f'<ellipse cx="{f(cx)}" cy="{f(cy)}" rx="{f(r)}" ry="{f(ry)}" fill="{top}"/>')
    # glaze drips and almonds on top
    out.append(f'<ellipse cx="{f(cx)}" cy="{f(cy)}" rx="{f(r * 0.92)}" ry="{f(ry * 0.9)}" fill="#FFF8E1" opacity="0.25"/>')
    for i in range(8):
        a = math.radians(i * 45)
        out.append(f'<ellipse cx="{f(cx + math.cos(a) * r * 0.6)}" cy="{f(cy + math.sin(a) * ry * 0.6)}" rx="{f(r * 0.07)}" ry="{f(r * 0.035)}" fill="#E8C690" transform="rotate({f(math.degrees(a))} {f(cx + math.cos(a) * r * 0.6)} {f(cy + math.sin(a) * ry * 0.6)})"/>')
    out.append(bauble(s, cx, cy - ry * 0.1, r * 0.12, 'red').replace('opacity="0.28"', 'opacity="0"'))
    out.append(holly(s, cx - r * 0.15, cy - ry * 0.15, r * 0.35, -10))
    return ''.join(out)


def cookie(s, cx, cy, r, star=False):
    g = s.rad([(0, '#F3C47C'), (0.7, '#D4934A'), (1, '#A8662A')], cx=0.4, cy=0.35, r=0.7)
    rnd = s.rnd
    if star:
        shape = ' '.join(f'{f(x)},{f(y)}' for x, y in star_points(cx, cy, r, r * 0.55))
        body = f'<polygon points="{shape}" fill="{g}" stroke="#8D5524" stroke-width="1.5" stroke-linejoin="round"/>'
        icing = f'<polygon points="{" ".join(f"{f(x)},{f(y)}" for x, y in star_points(cx, cy, r * 0.7, r * 0.38))}" fill="none" stroke="#FFFFFF" stroke-width="{f(r * 0.08)}" stroke-linejoin="round"/>'
        return f'<circle cx="{f(cx + 3)}" cy="{f(cy + 5)}" r="{f(r * 0.8)}" fill="#3E2000" opacity="0.25" filter="{s.blur(4)}"/>' + body + icing
    chips = ''.join(f'<circle cx="{f(cx + rnd.uniform(-r * 0.6, r * 0.6))}" cy="{f(cy + rnd.uniform(-r * 0.6, r * 0.6))}" r="{f(r * 0.1)}" fill="#4E2A12"/>' for _ in range(7))
    return (f'<circle cx="{f(cx + 3)}" cy="{f(cy + 5)}" r="{f(r)}" fill="#3E2000" opacity="0.25" filter="{s.blur(4)}"/>'
            f'<circle cx="{f(cx)}" cy="{f(cy)}" r="{f(r)}" fill="{g}" stroke="#8D5524" stroke-width="1.5"/>{chips}')


def candy_cane(s, x, y, h, angle):
    w = h * 0.12
    d = f'M 0,0 L 0,{f(-h * 0.75)} A {f(h * 0.16)},{f(h * 0.16)} 0 0 1 {f(h * 0.32)},{f(-h * 0.75)}'
    return (f'<g transform="translate({f(x)} {f(y)}) rotate({f(angle)})"><path d="{d}" stroke="#FFFFFF" stroke-width="{f(w)}" fill="none" stroke-linecap="round"/>'
            f'<path d="{d}" stroke="#E53935" stroke-width="{f(w)}" fill="none" stroke-linecap="round" stroke-dasharray="{f(w * 0.8)} {f(w * 0.8)}"/></g>')


def banner_treats():
    s = SVG(W, H, seed=91)
    s.add(f'<rect width="{W}" height="{H}" fill="{s.lin([(0, "#FFF8F0"), (0.55, "#FFE4E1"), (1, "#FFC8C0")], x1=0, y1=0, x2=1, y2=0.6)}"/>')
    s.add(f'<rect width="{W}" height="{H}" fill="{s.rad([(0, "#FFFFFF", 0.7), (1, "#FFFFFF", 0)], cx=800, cy=260, r=380, units="userSpaceOnUse")}"/>')
    rnd = s.rnd
    for _ in range(18):
        s.add(snowflake(s, rnd.uniform(560, 1060), rnd.uniform(20, 300), rnd.uniform(8, 16), opacity=0.5).replace('#FFFFFF', '#E57373'))
    s.add(plum_cake(s, 790, 330, 150))
    for (x, y, r, st) in [(985, 470, 40, False), (1040, 420, 34, True), (600, 480, 36, True), (650, 505, 30, False)]:
        s.add(cookie(s, x, y, r, star=st))
    s.add(candy_cane(s, 1010, 330, 150, 14))
    s.add(holly(s, 600, 400, 60, 30))
    for x, y, r in [(640, 120, 11), (1040, 150, 9), (900, 70, 10)]:
        s.add(sparkle(s, x, y, r, color='#FFFFFF', glow='#FFB300'))
    s.save(f'{OUT}/banner_treats.svg')


def chips_bowl(s, cx, cy, rx):
    ry = rx * 0.3
    rnd = s.rnd
    bowl = s.lin([(0, '#E53935'), (1, '#8E0000')], x1=0, y1=0, x2=0, y2=1)
    out = [f'<ellipse cx="{f(cx)}" cy="{f(cy + ry * 2.4)}" rx="{f(rx * 0.9)}" ry="{f(ry * 0.4)}" fill="#000" opacity="0.4" filter="{s.blur(8)}"/>']
    for _ in range(46):
        x = cx + rnd.uniform(-rx * 0.85, rx * 0.85)
        y = cy - rnd.uniform(0, ry * 2.6) * (1 - abs(x - cx) / (rx * 1.1))
        a = rnd.uniform(0, 180)
        g = s.rad([(0, '#FFF59D'), (1, '#F9A825')], cx=0.4, cy=0.4, r=0.7)
        out.append(f'<ellipse cx="{f(x)}" cy="{f(y)}" rx="{f(rx * 0.12)}" ry="{f(rx * 0.08)}" transform="rotate({f(a)} {f(x)} {f(y)})" fill="{g}" stroke="#E0A000" stroke-width="1"/>')
    out.append(f'<path d="M {f(cx - rx)},{f(cy)} Q {f(cx)},{f(cy + ry * 4.2)} {f(cx + rx)},{f(cy)} Z" fill="{bowl}"/>')
    out.append(f'<ellipse cx="{f(cx)}" cy="{f(cy)}" rx="{f(rx)}" ry="{f(ry * 0.4)}" fill="none" stroke="#FF8A80" stroke-width="4"/>')
    return ''.join(out)


def bottle(s, x, base_y, h, liquid='#3E1A0E', label='#E53935'):
    w = h * 0.28
    g = s.lin([(0, '#5D2A16'), (0.5, liquid), (1, '#1A0A04')], x1=0, y1=0, x2=1, y2=0)
    d = (f'M {f(x - w * 0.18)},{f(base_y - h)} L {f(x + w * 0.18)},{f(base_y - h)} L {f(x + w * 0.2)},{f(base_y - h * 0.72)} '
         f'Q {f(x + w * 0.55)},{f(base_y - h * 0.6)} {f(x + w * 0.5)},{f(base_y - h * 0.45)} L {f(x + w * 0.5)},{f(base_y)} L {f(x - w * 0.5)},{f(base_y)} L {f(x - w * 0.5)},{f(base_y - h * 0.45)} '
         f'Q {f(x - w * 0.55)},{f(base_y - h * 0.6)} {f(x - w * 0.2)},{f(base_y - h * 0.72)} Z')
    return (f'<ellipse cx="{f(x)}" cy="{f(base_y + 3)}" rx="{f(w * 0.6)}" ry="{f(w * 0.12)}" fill="#000" opacity="0.4" filter="{s.blur(4)}"/>'
            f'<path d="{d}" fill="{g}"/>'
            f'<rect x="{f(x - w * 0.5)}" y="{f(base_y - h * 0.36)}" width="{f(w)}" height="{f(h * 0.18)}" fill="{label}"/>'
            f'<path d="M {f(x - w * 0.4)},{f(base_y - h * 0.27)} q {f(w * 0.4)},{f(-h * 0.05)} {f(w * 0.8)},0" stroke="#FFFFFF" stroke-width="2" fill="none"/>'
            f'<rect x="{f(x - w * 0.2)}" y="{f(base_y - h - h * 0.05)}" width="{f(w * 0.4)}" height="{f(h * 0.06)}" rx="2" fill="{label}"/>'
            f'<rect x="{f(x - w * 0.36)}" y="{f(base_y - h * 0.58)}" width="{f(w * 0.1)}" height="{f(h * 0.5)}" fill="#FFFFFF" opacity="0.25"/>')


def confetti(s, x0, x1, y0, y1, n):
    rnd = s.rnd
    out = []
    for _ in range(n):
        x, y = rnd.uniform(x0, x1), rnd.uniform(y0, y1)
        c = rnd.choice(['#FFD54F', '#FF5252', '#40C4FF', '#69F0AE', '#E040FB'])
        if rnd.random() < 0.6:
            out.append(f'<rect x="{f(x)}" y="{f(y)}" width="{f(rnd.uniform(6, 12))}" height="{f(rnd.uniform(3, 5))}" fill="{c}" transform="rotate({f(rnd.uniform(0, 180))} {f(x)} {f(y)})"/>')
        else:
            out.append(f'<path d="M {f(x)},{f(y)} q 8,-10 16,0 t 16,0" stroke="{c}" stroke-width="3" fill="none" stroke-linecap="round" transform="rotate({f(rnd.uniform(0, 180))} {f(x)} {f(y)})"/>')
    return ''.join(out)


def banner_party():
    s = SVG(W, H, seed=97)
    night(s, W, H, 820, 220)
    for (x, y, R, c, o) in [(700, 150, 120, '#FFD54F', 0.7), (930, 110, 100, '#FF8A80', 0.6), (1030, 260, 80, '#80DEEA', 0.55), (620, 300, 70, '#CE93D8', 0.5)]:
        s.add(firework(s, x, y, R, c, o))
    s.add(confetti(s, 560, 1070, 30, 520, 60))
    s.add(chips_bowl(s, 760, 430, 140))
    s.add(bottle(s, 960, 520, 240))
    s.add(bottle(s, 1030, 520, 200, liquid='#E65100', label='#43A047'))
    s.save(f'{OUT}/banner_party.svg')


def flour_sack(s, cx, base_y, w):
    h = w * 1.2
    g = s.lin([(0, '#FFFFFF'), (0.6, '#F1EBDD'), (1, '#CFC5B0')], x1=0, y1=0, x2=1, y2=0)
    d = (f'M {f(cx - w * 0.5)},{f(base_y)} Q {f(cx - w * 0.58)},{f(base_y - h * 0.5)} {f(cx - w * 0.44)},{f(base_y - h * 0.9)} '
         f'Q {f(cx - w * 0.2)},{f(base_y - h * 1.02)} {f(cx)},{f(base_y - h * 0.94)} Q {f(cx + w * 0.2)},{f(base_y - h * 1.02)} {f(cx + w * 0.44)},{f(base_y - h * 0.9)} '
         f'Q {f(cx + w * 0.58)},{f(base_y - h * 0.5)} {f(cx + w * 0.5)},{f(base_y)} Z')
    wheat = ''.join(f'<ellipse cx="{f(cx + (i % 2 * 2 - 1) * w * 0.05)}" cy="{f(base_y - h * (0.62 - i * 0.04))}" rx="{f(w * 0.045)}" ry="{f(w * 0.022)}" fill="#D4A04C" transform="rotate({f(-30 if i % 2 else 30)} {f(cx)} {f(base_y - h * (0.62 - i * 0.04))})"/>' for i in range(8))
    return (f'<ellipse cx="{f(cx)}" cy="{f(base_y + 4)}" rx="{f(w * 0.55)}" ry="{f(w * 0.08)}" fill="#3E2723" opacity="0.3" filter="{s.blur(6)}"/>'
            f'<path d="{d}" fill="{g}" stroke="#BDB3A0" stroke-width="2"/>'
            f'<path d="M {f(cx - w * 0.36)},{f(base_y - h * 0.86)} Q {f(cx)},{f(base_y - h * 0.8)} {f(cx + w * 0.36)},{f(base_y - h * 0.86)}" stroke="#8D6E63" stroke-width="5" fill="none"/>'
            f'<circle cx="{f(cx)}" cy="{f(base_y - h * 0.48)}" r="{f(w * 0.22)}" fill="none" stroke="#D4A04C" stroke-width="3"/>'
            f'<line x1="{f(cx)}" y1="{f(base_y - h * 0.32)}" x2="{f(cx)}" y2="{f(base_y - h * 0.66)}" stroke="#B8862E" stroke-width="2"/>{wheat}'
            f'<ellipse cx="{f(cx)}" cy="{f(base_y - h * 0.93)}" rx="{f(w * 0.36)}" ry="{f(w * 0.08)}" fill="#FAFAFA" stroke="#D7CCC8" stroke-width="2"/>')


def butter(s, x, y, w):
    h = w * 0.42
    return (f'<ellipse cx="{f(x + w / 2)}" cy="{f(y + h + 6)}" rx="{f(w * 0.6)}" ry="{f(w * 0.08)}" fill="#3E2723" opacity="0.3" filter="{s.blur(5)}"/>'
            f'<path d="M {f(x)},{f(y + h * 0.3)} L {f(x + w * 0.25)},{f(y)} L {f(x + w)},{f(y)} L {f(x + w * 0.75)},{f(y + h * 0.3)} Z" fill="#FFF59D"/>'
            f'<rect x="{f(x)}" y="{f(y + h * 0.3)}" width="{f(w * 0.75)}" height="{f(h * 0.7)}" fill="#FFEE58"/>'
            f'<path d="M {f(x + w * 0.75)},{f(y + h * 0.3)} L {f(x + w)},{f(y)} L {f(x + w)},{f(y + h * 0.7)} L {f(x + w * 0.75)},{f(y + h)} Z" fill="#FBC02D"/>'
            f'<rect x="{f(x + w * 0.35)}" y="{f(y + h * 0.3)}" width="{f(w * 0.4)}" height="{f(h * 0.7)}" fill="#FFFFFF" opacity="0.85"/>'
            f'<rect x="{f(x + w * 0.4)}" y="{f(y + h * 0.48)}" width="{f(w * 0.3)}" height="{f(h * 0.12)}" fill="#1E88E5"/>')


def egg(s, cx, cy, r, a=0):
    g = s.rad([(0, '#FFF8F0'), (0.7, '#F3E3D3'), (1, '#D9C2A8')], cx=0.38, cy=0.32, r=0.75)
    return (f'<ellipse cx="{f(cx + 3)}" cy="{f(cy + r * 1.1)}" rx="{f(r * 0.8)}" ry="{f(r * 0.2)}" fill="#3E2723" opacity="0.25" filter="{s.blur(4)}"/>'
            f'<ellipse cx="{f(cx)}" cy="{f(cy)}" rx="{f(r * 0.78)}" ry="{f(r)}" fill="{g}" transform="rotate({f(a)} {f(cx)} {f(cy)})"/>')


def rolling_pin(s, x, y, L, a):
    g = s.lin([(0, '#E6B98A'), (0.5, '#C8915A'), (1, '#8D5A2B')], x1=0, y1=0, x2=0, y2=1)
    return (f'<g transform="translate({f(x)} {f(y)}) rotate({f(a)})"><rect x="{f(-L * 0.36)}" y="{f(-L * 0.07)}" width="{f(L * 0.72)}" height="{f(L * 0.14)}" rx="{f(L * 0.07)}" fill="{g}"/>'
            f'<rect x="{f(-L * 0.5)}" y="{f(-L * 0.035)}" width="{f(L * 0.15)}" height="{f(L * 0.07)}" rx="{f(L * 0.035)}" fill="#8D5A2B"/>'
            f'<rect x="{f(L * 0.35)}" y="{f(-L * 0.035)}" width="{f(L * 0.15)}" height="{f(L * 0.07)}" rx="{f(L * 0.035)}" fill="#8D5A2B"/></g>')


def banner_baking():
    s = SVG(W, H, seed=101)
    s.add(f'<rect width="{W}" height="{H}" fill="{s.lin([(0, "#FFF7EE"), (0.6, "#FFE8D1"), (1, "#FFD3A8")], x1=0, y1=0, x2=1, y2=0.6)}"/>')
    s.add(f'<rect width="{W}" height="{H}" fill="{s.rad([(0, "#FFFFFF", 0.6), (1, "#FFFFFF", 0)], cx=800, cy=260, r=380, units="userSpaceOnUse")}"/>')
    rnd = s.rnd
    for _ in range(16):
        s.add(snowflake(s, rnd.uniform(560, 1060), rnd.uniform(20, 280), rnd.uniform(8, 15), opacity=0.45).replace('#FFFFFF', '#FFAB91'))
    s.add(flour_sack(s, 740, 500, 210))
    s.add(butter(s, 870, 410, 150))
    s.add(egg(s, 980, 490, 34, 10))
    s.add(egg(s, 1035, 500, 30, -15))
    s.add(rolling_pin(s, 620, 505, 200, -8))
    for (x, y, r) in [(905, 520, 26), (575, 450, 22)]:
        s.add(f'<polygon points="{" ".join(f"{f(px)},{f(py)}" for px, py in star_points(x, y, r, r * 0.5))}" fill="none" stroke="#B0BEC5" stroke-width="4" stroke-linejoin="round"/>')
    for x, y, r in [(620, 120, 10), (1040, 140, 9), (900, 80, 11)]:
        s.add(sparkle(s, x, y, r, color='#FFFFFF', glow='#FF8A65'))
    s.save(f'{OUT}/banner_baking.svg')


def btn_tile():
    """Seamless snowflake-and-star tile for festive buttons: 192 × 192 (64 dp)."""
    s = SVG(192, 192, seed=103)
    out = []
    for i in range(3):
        for j in range(3):
            x, y = 32 + i * 64, 32 + j * 64
            if (i + j) % 2 == 0:
                out.append(snowflake(s, x, y, 9, opacity=0.35).replace('#FFFFFF', '#FFF3F3'))
            else:
                out.append(star4(x, y, 6, '#FFE9A8', 0.5))
    s.add(''.join(out))
    s.save(f'{OUT}/btn_tile.svg')


def section_icon():
    s = SVG(96, 96, seed=107)
    s.add(xmas_tree(s, 48, 92, 84))
    s.save(f'{OUT}/section_icon.svg')


def petals():
    s = SVG(48, 48, seed=1)
    s.add(snowflake(s, 24, 24, 20, opacity=1).replace('#FFFFFF', '#90CAF9'))
    s.save(f'{OUT}/petal_1.svg')
    s = SVG(48, 48, seed=2)
    pts = ' '.join(f'{f(x)},{f(y)}' for x, y in star_points(24, 25, 20, 9))
    s.add(f'<polygon points="{pts}" fill="{s.rad([(0, "#FFF59D"), (1, "#F9A825")], cx=0.5, cy=0.5, r=0.6)}" stroke="#C98A12" stroke-width="1.5" stroke-linejoin="round"/>')
    s.save(f'{OUT}/petal_2.svg')
    s = SVG(48, 48, seed=3)
    s.add('<rect x="10" y="18" width="28" height="12" rx="2" fill="#E53935"/><rect x="10" y="18" width="28" height="4" fill="#FF8A80"/>')
    s.save(f'{OUT}/petal_3.svg')
    s = SVG(72, 72, seed=4)
    s.add(bauble(s, 36, 42, 22, 'red'))
    s.save(f'{OUT}/petal_4.svg')


if __name__ == '__main__':
    banner_treats()
    banner_party()
    banner_baking()
    btn_tile()
    section_icon()
    petals()
    print('ok')
