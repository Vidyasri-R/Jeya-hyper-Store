"""Web shop hero art (out/web/): a green Jeya shopping basket of packaged groceries, transparent background."""
import base64

from svgkit import *
from christmas_more import flour_sack
from eid_more import rice_sack
from karthigai_more import ghee_jar

OUT = 'out/web'
W, H = 900, 640


def oil_can(s, cx, base_y, w):
    """A yellow cooking-oil can with a handle and a green label (not a bottle)."""
    h = w * 1.25
    x0, top = cx - w / 2, base_y - h
    body = s.lin([(0, '#FFD54F'), (0.55, '#F6B800'), (1, '#C98A00')], x1=0, y1=0, x2=1, y2=0)
    return (f'<rect x="{f(x0)}" y="{f(top)}" width="{f(w)}" height="{f(h)}" rx="{f(w * 0.14)}" fill="{body}"/>'
            f'<path d="M {f(x0 + w * 0.55)},{f(top + 2)} q {f(w * 0.2)},{f(-h * 0.22)} {f(w * 0.4)},0" stroke="#C98A00" stroke-width="{f(w * 0.09)}" fill="none" stroke-linecap="round"/>'
            f'<rect x="{f(x0 + w * 0.14)}" y="{f(top - h * 0.08)}" width="{f(w * 0.22)}" height="{f(h * 0.1)}" rx="4" fill="#C62828"/>'
            f'<rect x="{f(x0 + w * 0.1)}" y="{f(top + h * 0.34)}" width="{f(w * 0.8)}" height="{f(h * 0.4)}" rx="8" fill="#1B7A3E"/>'
            f'<circle cx="{f(cx)}" cy="{f(top + h * 0.54)}" r="{f(w * 0.14)}" fill="#FFD54F"/>'
            f'<rect x="{f(x0 + w * 0.08)}" y="{f(top + h * 0.06)}" width="{f(w * 0.1)}" height="{f(h * 0.85)}" rx="4" fill="#FFFFFF" opacity="0.25"/>')


def biscuit_pack(s, cx, base_y, w, colour=('#E53935', '#B71C1C')):
    """A biscuit packet standing on its end."""
    h = w * 1.5
    x0, top = cx - w / 2, base_y - h
    body = s.lin([(0, colour[0]), (1, colour[1])], x1=0, y1=0, x2=1, y2=0)
    out = [f'<rect x="{f(x0)}" y="{f(top)}" width="{f(w)}" height="{f(h)}" rx="8" fill="{body}"/>',
           f'<rect x="{f(x0)}" y="{f(top)}" width="{f(w)}" height="{f(h * 0.08)}" rx="4" fill="#000" opacity="0.15"/>']
    for k in range(3):
        out.append(f'<circle cx="{f(cx)}" cy="{f(top + h * (0.35 + k * 0.2))}" r="{f(w * 0.26)}" fill="#E8B865" stroke="#B9852F" stroke-width="3"/>')
        for dx in (-0.1, 0.1):
            out.append(f'<circle cx="{f(cx + w * dx)}" cy="{f(top + h * (0.35 + k * 0.2))}" r="3" fill="#B9852F"/>')
    return ''.join(out)


def detergent_box(s, cx, base_y, w):
    """A blue washing-powder box."""
    h = w * 1.2
    x0, top = cx - w / 2, base_y - h
    return (f'<rect x="{f(x0)}" y="{f(top)}" width="{f(w)}" height="{f(h)}" rx="8" fill="{s.lin([(0, "#3D7BE0"), (1, "#123E8C")], x1=0, y1=0, x2=1, y2=0)}"/>'
            f'<circle cx="{f(cx)}" cy="{f(top + h * 0.48)}" r="{f(w * 0.3)}" fill="#FFFFFF"/>'
            f'<circle cx="{f(cx)}" cy="{f(top + h * 0.48)}" r="{f(w * 0.2)}" fill="#F6B800"/>'
            f'<rect x="{f(x0 + w * 0.15)}" y="{f(top + h * 0.82)}" width="{f(w * 0.7)}" height="{f(h * 0.08)}" rx="4" fill="#FFFFFF" opacity="0.8"/>')


def green_basket(s, cx, top, w, h):
    x0, x1 = cx - w / 2, cx + w / 2
    d = f'M {f(x0)},{f(top)} L {f(x1)},{f(top)} L {f(x1 - w * 0.09)},{f(top + h)} Q {f(cx)},{f(top + h * 1.06)} {f(x0 + w * 0.09)},{f(top + h)} Z'
    body = s.lin([(0, '#2EA65A'), (0.5, '#1B7A3E'), (1, '#0F4D2A')], x1=0, y1=0, x2=0, y2=1)
    clip = s.clip(f'<path d="{d}"/>')
    grid = []
    cols, rows = 9, 5
    for c in range(cols):
        for r in range(rows):
            gx = x0 + w * 0.05 + c * (w * 0.9 / cols)
            gy = top + h * 0.12 + r * (h * 0.8 / rows)
            grid.append(f'<rect x="{f(gx)}" y="{f(gy)}" width="{f(w * 0.9 / cols - 10)}" height="{f(h * 0.8 / rows - 10)}" rx="6" fill="#0B3A1F" opacity="0.55"/>')
    return (f'<ellipse cx="{f(cx)}" cy="{f(top + h + 14)}" rx="{f(w * 0.5)}" ry="{f(h * 0.1)}" fill="#0B2A16" opacity="0.28" filter="{s.blur(12)}"/>'
            f'<path d="{d}" fill="{body}"/><g clip-path="{clip}">{"".join(grid)}'
            f'<rect x="{f(x0)}" y="{f(top)}" width="{f(w * 0.18)}" height="{f(h)}" fill="#FFFFFF" opacity="0.08"/></g>'
            f'<rect x="{f(x0 - 12)}" y="{f(top - 16)}" width="{f(w + 24)}" height="30" rx="15" fill="{s.lin([(0, "#2EA65A"), (1, "#14612F")], x1=0, y1=0, x2=0, y2=1)}"/>')


def hero():
    s = SVG(W, H, seed=901)
    cx, top, bw, bh = 450, 380, 560, 230
    # handle behind
    s.add(f'<path d="M {cx - 210},{top} C {cx - 230},{top - 330} {cx + 230},{top - 330} {cx + 210},{top}" stroke="#14612F" stroke-width="26" fill="none" stroke-linecap="round"/>')
    s.add(f'<path d="M {cx - 210},{top} C {cx - 230},{top - 330} {cx + 230},{top - 330} {cx + 210},{top}" stroke="#2EA65A" stroke-width="10" fill="none" stroke-linecap="round"/>')
    # groceries standing in the basket, back row first
    s.add(rice_sack(s, 300, top + 40, 170))
    s.add(flour_sack(s, 470, top + 30, 150))
    s.add(oil_can(s, 610, top + 30, 150))
    s.add(detergent_box(s, 690, top + 40, 110))
    s.add(ghee_jar(s, 390, top + 36, 96))
    s.add(biscuit_pack(s, 215, top + 40, 90))
    s.add(green_basket(s, cx, top, bw, bh))
    # Jeya logo plate on the basket front
    with open('../../app/assets/brand/logo_mark.png', 'rb') as fh:
        logo = base64.b64encode(fh.read()).decode()
    s.add(f'<rect x="{cx - 70}" y="{top + 50}" width="140" height="140" rx="28" fill="#FFFFFF"/>')
    s.add(f'<image x="{cx - 60}" y="{top + 60}" width="120" height="120" href="data:image/png;base64,{logo}"/>')
    s.save(f'{OUT}/hero_basket.svg')


if __name__ == '__main__':
    hero()
