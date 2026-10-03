"""Valentine's Day banners, button texture, section icon and falling sprites (out/valentine/)."""
import math

from svgkit import *
from banners import giftbox
from valentine_art import OUT, bouquet, chocolate_box, heart, heart_bokeh, heart_path, lace, rose, rose_leaf, rose_night

W, H = 1080, 540


def choc_bar(s, x, y, w, h, angle, foil='#C62828'):
    g = s.lin([(0, '#7A4A2E'), (1, '#3A1A0A')], x1=0, y1=0, x2=1, y2=1)
    cols, rows = 4, 2
    cells = ''.join(f'<rect x="{f(x + 6 + i * (w * 0.55 - 12) / cols)}" y="{f(y + 6 + j * (h - 12) / rows)}" width="{f((w * 0.55 - 12) / cols - 4)}" height="{f((h - 12) / rows - 4)}" rx="3" fill="#8D5A3A" opacity="0.6"/>'
                    for i in range(cols) for j in range(rows))
    return (f'<g transform="rotate({f(angle)} {f(x + w / 2)} {f(y + h / 2)})">'
            f'<rect x="{f(x + 6)}" y="{f(y + 10)}" width="{f(w)}" height="{f(h)}" rx="6" fill="#2A0010" opacity="0.3" filter="{s.blur(6)}"/>'
            f'<rect x="{f(x)}" y="{f(y)}" width="{f(w)}" height="{f(h)}" rx="6" fill="{g}"/>{cells}'
            f'<rect x="{f(x + w * 0.55)}" y="{f(y - 3)}" width="{f(w * 0.45)}" height="{f(h + 6)}" rx="4" fill="{foil}"/>'
            f'<rect x="{f(x + w * 0.55)}" y="{f(y - 3)}" width="{f(w * 0.06)}" height="{f(h + 6)}" fill="#FFE7A0"/>'
            f'<path d="{heart_path(x + w * 0.8, y + h / 2, h * 0.45)}" fill="#FFFFFF" opacity="0.85"/></g>')


def banner_chocolates():
    s = SVG(W, H, seed=111)
    s.add(f'<rect width="{W}" height="{H}" fill="{s.lin([(0, "#FFF5F8"), (0.55, "#FFE0EA"), (1, "#FFC2D4")], x1=0, y1=0, x2=1, y2=0.6)}"/>')
    s.add(f'<rect width="{W}" height="{H}" fill="{s.rad([(0, "#FFFFFF", 0.7), (1, "#FFFFFF", 0)], cx=800, cy=260, r=380, units="userSpaceOnUse")}"/>')
    s.add(lace(s, 820, 260, 300, opacity=0.35, colour='#F48FB1'))
    s.add(choc_bar(s, 600, 380, 230, 92, -12))
    s.add(choc_bar(s, 880, 330, 190, 80, 18, foil='#8E24AA'))
    s.add(chocolate_box(s, 790, 300, 270))
    rnd = s.rnd
    for _ in range(9):
        s.add(heart(s, rnd.uniform(570, 1060), rnd.uniform(40, 200), rnd.uniform(14, 26), shadow=False))
    s.save(f'{OUT}/banner_chocolates.svg')


def balloon(s, cx, cy, size, colours):
    return (heart(s, cx, cy, size, colours) +
            f'<path d="M {f(cx)},{f(cy + size * 0.48)} q {f(size * 0.12)},{f(size * 0.6)} {f(-size * 0.05)},{f(size * 1.4)}" stroke="#FFFFFF" stroke-opacity="0.7" stroke-width="2" fill="none"/>')


def banner_flowers():
    s = SVG(W, H, seed=113)
    rose_night(s, W, H, 820, 240)
    s.add(lace(s, 820, 250, 300, opacity=0.14))
    rnd = s.rnd
    for _ in range(10):
        s.add(heart_bokeh(s, rnd.uniform(560, 1070), rnd.uniform(30, 500), rnd.uniform(20, 50), rnd.choice(['#FF80AB', '#FFB3C6']), rnd.uniform(0.15, 0.3)))
    s.add(balloon(s, 1000, 150, 120, ('#FF8FA8', '#F0306A', '#A0003A')))
    s.add(balloon(s, 905, 110, 90, ('#FFD1DC', '#F48FB1', '#C2185B')))
    s.add(giftbox(s, 900, 360, 130, 130, body=('#F06292', '#AD1457')))
    s.add(bouquet(s, 720, 530, 260))
    s.save(f'{OUT}/banner_flowers.svg')


def heart_cake(s, cx, cy, size):
    side = s.lin([(0, '#F8BBD0'), (1, '#C2185B')], x1=0, y1=0, x2=1, y2=0)
    out = [f'<ellipse cx="{f(cx)}" cy="{f(cy + size * 0.62)}" rx="{f(size * 0.72)}" ry="{f(size * 0.16)}" fill="#ECEFF1"/>',
           f'<ellipse cx="{f(cx)}" cy="{f(cy + size * 0.6)}" rx="{f(size * 0.72)}" ry="{f(size * 0.16)}" fill="none" stroke="#B0BEC5" stroke-width="2"/>',
           f'<path d="{heart_path(cx, cy + size * 0.16, size)}" fill="{side}" transform="translate(0 0) scale(1 1)"/>',
           f'<path d="{heart_path(cx, cy, size)}" fill="{s.rad([(0, "#FFE4EC"), (0.7, "#F8BBD0"), (1, "#F06292")], cx=0.4, cy=0.35, r=0.75)}"/>']
    for i in range(14):          # piped border
        t = i / 14
        a = math.tau * t
        out.append(f'<circle cx="{f(cx + math.cos(a) * size * 0.4)}" cy="{f(cy + math.sin(a) * size * 0.3 + size * 0.04)}" r="{f(size * 0.035)}" fill="#FFFFFF" opacity="0.9"/>')
    for (dx, dy) in [(-0.15, -0.05), (0.15, -0.05), (0.0, 0.12)]:
        out.append(f'<ellipse cx="{f(cx + dx * size)}" cy="{f(cy + dy * size)}" rx="{f(size * 0.06)}" ry="{f(size * 0.07)}" fill="#E53950"/>'
                   f'<path d="M {f(cx + dx * size - size * 0.04)},{f(cy + dy * size - size * 0.06)} l {f(size * 0.04)},{f(-size * 0.03)} l {f(size * 0.04)},{f(size * 0.03)}" fill="#4CAF50"/>')
    return ''.join(out)


def cupcake(s, cx, base_y, w):
    cup = s.lin([(0, '#F48FB1'), (1, '#C2185B')], x1=0, y1=0, x2=1, y2=0)
    out = [f'<ellipse cx="{f(cx)}" cy="{f(base_y + 3)}" rx="{f(w * 0.55)}" ry="{f(w * 0.1)}" fill="#3E0018" opacity="0.25" filter="{s.blur(4)}"/>',
           f'<path d="M {f(cx - w * 0.45)},{f(base_y - w * 0.55)} L {f(cx - w * 0.33)},{f(base_y)} L {f(cx + w * 0.33)},{f(base_y)} L {f(cx + w * 0.45)},{f(base_y - w * 0.55)} Z" fill="{cup}"/>']
    for i in range(5):
        x = cx - w * 0.36 + i * w * 0.18
        out.append(f'<line x1="{f(x)}" y1="{f(base_y - w * 0.53)}" x2="{f(x + w * 0.02)}" y2="{f(base_y - 2)}" stroke="#AD1457" stroke-width="2" opacity="0.5"/>')
    for k, (dy, rr) in enumerate([(0.62, 0.5), (0.86, 0.38), (1.06, 0.24)]):
        out.append(f'<ellipse cx="{f(cx)}" cy="{f(base_y - w * dy)}" rx="{f(w * rr)}" ry="{f(w * rr * 0.55)}" fill="{["#FFF0F5", "#FFE4EC", "#FFD1DC"][k]}"/>')
    out.append(heart(s, cx, base_y - w * 1.22, w * 0.28, shadow=False))
    return ''.join(out)


def banner_sweets():
    s = SVG(W, H, seed=117)
    s.add(f'<rect width="{W}" height="{H}" fill="{s.lin([(0, "#FFF7F2"), (0.6, "#FFE6DC"), (1, "#FFCDBA")], x1=0, y1=0, x2=1, y2=0.6)}"/>')
    s.add(f'<rect width="{W}" height="{H}" fill="{s.rad([(0, "#FFFFFF", 0.6), (1, "#FFFFFF", 0)], cx=800, cy=260, r=380, units="userSpaceOnUse")}"/>')
    s.add(lace(s, 820, 250, 290, opacity=0.3, colour='#FFAB91'))
    s.add(heart_cake(s, 790, 300, 300))
    s.add(cupcake(s, 1000, 500, 110))
    s.add(cupcake(s, 600, 505, 90))
    rnd = s.rnd
    for _ in range(8):
        s.add(heart(s, rnd.uniform(580, 1060), rnd.uniform(40, 180), rnd.uniform(12, 22), ('#FFB3C6', '#F06292', '#AD1457'), shadow=False))
    s.save(f'{OUT}/banner_sweets.svg')


def btn_tile():
    """Seamless tile of tiny hearts for festive buttons: 192 × 192 (64 dp)."""
    s = SVG(192, 192, seed=119)
    out = []
    for i in range(3):
        for j in range(3):
            x, y = 32 + i * 64 + (16 if j % 2 else 0), 32 + j * 64
            out.append(f'<path d="{heart_path(x % 192, y, 12)}" fill="#FFE4EC" opacity="0.4"/>')
            out.append(f'<circle cx="{f((x + 32) % 192)}" cy="{f(y + 22)}" r="1.8" fill="#FFE4EC" opacity="0.45"/>')
    s.add(''.join(out))
    s.save(f'{OUT}/btn_tile.svg')


def section_icon():
    s = SVG(96, 96, seed=121)
    s.add(rose_leaf(s, 30, 62, 30, 200))
    s.add(rose_leaf(s, 62, 62, 30, -20))
    s.add(heart(s, 48, 48, 66, shadow=False))
    s.add(rose(s, 48, 46, 15, 'pink'))
    s.save(f'{OUT}/section_icon.svg')


def petals():
    for name, col in (('petal_1', ('#FF8A9B', '#D81B3C', '#7A0019')), ('petal_2', ('#FFD1DC', '#F48FB1', '#C2185B'))):
        s = SVG(48, 48, seed=5)
        g = s.rad([(0, col[0]), (0.6, col[1]), (1, col[2])], cx=0.4, cy=0.35, r=0.75)
        s.add(f'<path d="M 24,6 C 40,10 44,30 30,42 C 26,45 22,45 18,42 C 4,30 8,10 24,6 Z" fill="{g}"/>')
        s.add(f'<path d="M 24,10 Q 26,26 23,40" stroke="{col[2]}" stroke-opacity="0.35" stroke-width="1.5" fill="none"/>')
        s.save(f'{OUT}/{name}.svg')
    s = SVG(48, 48, seed=6); s.add(heart(s, 24, 25, 38, shadow=False)); s.save(f'{OUT}/petal_3.svg')
    s = SVG(72, 72, seed=7); s.add(rose(s, 36, 36, 30, 'red')); s.save(f'{OUT}/petal_4.svg')


if __name__ == '__main__':
    banner_chocolates()
    banner_flowers()
    banner_sweets()
    btn_tile()
    section_icon()
    petals()
    print('ok')
