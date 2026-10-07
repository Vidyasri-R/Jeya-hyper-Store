"""Packaged grocery items for the web shop art (hero, category tiles, promos). Each returns SVG markup,
standing on base_y and centred on cx, sized by width w."""
from svgkit import *


def shadow(s, cx, base_y, w):
    return f'<ellipse cx="{f(cx)}" cy="{f(base_y + 4)}" rx="{f(w * 0.55)}" ry="{f(w * 0.08)}" fill="#1B2B20" opacity="0.22" filter="{s.blur(5)}"/>'


def oil_tin(s, cx, base_y, w):
    """Yellow cooking-oil can with a handle and a green label."""
    h = w * 1.25
    x0, top = cx - w / 2, base_y - h
    body = s.lin([(0, '#FFD54F'), (0.55, '#F6B800'), (1, '#C98A00')], x1=0, y1=0, x2=1, y2=0)
    return (shadow(s, cx, base_y, w) +
            f'<rect x="{f(x0)}" y="{f(top)}" width="{f(w)}" height="{f(h)}" rx="{f(w * 0.14)}" fill="{body}"/>'
            f'<path d="M {f(x0 + w * 0.55)},{f(top + 2)} q {f(w * 0.2)},{f(-h * 0.22)} {f(w * 0.4)},0" stroke="#C98A00" stroke-width="{f(w * 0.09)}" fill="none" stroke-linecap="round"/>'
            f'<rect x="{f(x0 + w * 0.14)}" y="{f(top - h * 0.08)}" width="{f(w * 0.22)}" height="{f(h * 0.1)}" rx="4" fill="#C62828"/>'
            f'<rect x="{f(x0 + w * 0.1)}" y="{f(top + h * 0.34)}" width="{f(w * 0.8)}" height="{f(h * 0.4)}" rx="8" fill="#1B7A3E"/>'
            f'<circle cx="{f(cx)}" cy="{f(top + h * 0.54)}" r="{f(w * 0.14)}" fill="#FFD54F"/>'
            f'<rect x="{f(x0 + w * 0.08)}" y="{f(top + h * 0.06)}" width="{f(w * 0.1)}" height="{f(h * 0.85)}" rx="4" fill="#FFFFFF" opacity="0.25"/>')


def biscuit_pack(s, cx, base_y, w, colour=('#E53935', '#B71C1C')):
    """Biscuit packet standing on its end."""
    h = w * 1.5
    x0, top = cx - w / 2, base_y - h
    body = s.lin([(0, colour[0]), (1, colour[1])], x1=0, y1=0, x2=1, y2=0)
    out = [shadow(s, cx, base_y, w), f'<rect x="{f(x0)}" y="{f(top)}" width="{f(w)}" height="{f(h)}" rx="8" fill="{body}"/>',
           f'<rect x="{f(x0)}" y="{f(top)}" width="{f(w)}" height="{f(h * 0.08)}" rx="4" fill="#000" opacity="0.15"/>']
    for k in range(3):
        y = top + h * (0.35 + k * 0.2)
        out.append(f'<circle cx="{f(cx)}" cy="{f(y)}" r="{f(w * 0.26)}" fill="#E8B865" stroke="#B9852F" stroke-width="3"/>')
        for dx in (-0.1, 0.1):
            out.append(f'<circle cx="{f(cx + w * dx)}" cy="{f(y)}" r="3" fill="#B9852F"/>')
    return ''.join(out)


def detergent_box(s, cx, base_y, w):
    """Blue washing-powder box."""
    h = w * 1.2
    x0, top = cx - w / 2, base_y - h
    return (shadow(s, cx, base_y, w) +
            f'<rect x="{f(x0)}" y="{f(top)}" width="{f(w)}" height="{f(h)}" rx="8" fill="{s.lin([(0, "#3D7BE0"), (1, "#123E8C")], x1=0, y1=0, x2=1, y2=0)}"/>'
            f'<circle cx="{f(cx)}" cy="{f(top + h * 0.48)}" r="{f(w * 0.3)}" fill="#FFFFFF"/>'
            f'<circle cx="{f(cx)}" cy="{f(top + h * 0.48)}" r="{f(w * 0.2)}" fill="#F6B800"/>'
            f'<rect x="{f(x0 + w * 0.15)}" y="{f(top + h * 0.82)}" width="{f(w * 0.7)}" height="{f(h * 0.08)}" rx="4" fill="#FFFFFF" opacity="0.8"/>')


def pump_bottle(s, cx, base_y, w, body=('#4FC3F7', '#0277BD'), cap='#FFFFFF', label='#FFFFFF'):
    """Shampoo / cleaner bottle with a flip cap."""
    h = w * 2.0
    x0, top = cx - w / 2, base_y - h
    g = s.lin([(0, body[0]), (1, body[1])], x1=0, y1=0, x2=1, y2=0)
    return (shadow(s, cx, base_y, w) +
            f'<rect x="{f(cx - w * 0.2)}" y="{f(top - h * 0.1)}" width="{f(w * 0.4)}" height="{f(h * 0.14)}" rx="5" fill="{cap}" stroke="#00000022"/>'
            f'<path d="M {f(x0 + w * 0.12)},{f(top + h * 0.08)} Q {f(x0)},{f(top + h * 0.2)} {f(x0)},{f(top + h * 0.35)} L {f(x0)},{f(base_y - 10)} Q {f(x0)},{f(base_y)} {f(x0 + 10)},{f(base_y)} '
            f'L {f(x0 + w - 10)},{f(base_y)} Q {f(x0 + w)},{f(base_y)} {f(x0 + w)},{f(base_y - 10)} L {f(x0 + w)},{f(top + h * 0.35)} Q {f(x0 + w)},{f(top + h * 0.2)} {f(x0 + w * 0.88)},{f(top + h * 0.08)} Z" fill="{g}"/>'
            f'<rect x="{f(x0 + w * 0.14)}" y="{f(top + h * 0.45)}" width="{f(w * 0.72)}" height="{f(h * 0.3)}" rx="8" fill="{label}" opacity="0.92"/>'
            f'<rect x="{f(x0 + w * 0.26)}" y="{f(top + h * 0.53)}" width="{f(w * 0.48)}" height="{f(h * 0.04)}" rx="3" fill="{body[1]}"/>'
            f'<rect x="{f(x0 + w * 0.32)}" y="{f(top + h * 0.62)}" width="{f(w * 0.36)}" height="{f(h * 0.03)}" rx="3" fill="{body[1]}" opacity="0.6"/>'
            f'<rect x="{f(x0 + w * 0.08)}" y="{f(top + h * 0.3)}" width="{f(w * 0.1)}" height="{f(h * 0.6)}" rx="4" fill="#FFFFFF" opacity="0.25"/>')


def soap_bar(s, cx, base_y, w, colour=('#FFE0B2', '#F57C00'), wrap='#2E7D32'):
    """Soap in its paper wrap, lying flat."""
    h = w * 0.42
    x0, top = cx - w / 2, base_y - h
    return (shadow(s, cx, base_y, w) +
            f'<rect x="{f(x0)}" y="{f(top)}" width="{f(w)}" height="{f(h)}" rx="{f(h * 0.3)}" fill="{wrap}"/>'
            f'<rect x="{f(x0 + w * 0.06)}" y="{f(top + h * 0.12)}" width="{f(w * 0.88)}" height="{f(h * 0.3)}" rx="{f(h * 0.15)}" fill="#FFFFFF" opacity="0.25"/>'
            f'<ellipse cx="{f(cx)}" cy="{f(top + h * 0.6)}" rx="{f(w * 0.28)}" ry="{f(h * 0.24)}" fill="{colour[0]}" stroke="{colour[1]}" stroke-width="3"/>')


def toothpaste(s, cx, base_y, w):
    """Toothpaste box lying flat (white/red)."""
    h = w * 0.3
    x0, top = cx - w / 2, base_y - h
    return (shadow(s, cx, base_y, w) +
            f'<rect x="{f(x0)}" y="{f(top)}" width="{f(w)}" height="{f(h)}" rx="6" fill="#E53935"/>'
            f'<rect x="{f(x0 + w * 0.08)}" y="{f(top + h * 0.2)}" width="{f(w * 0.55)}" height="{f(h * 0.6)}" rx="5" fill="#FFFFFF"/>'
            f'<path d="M {f(x0 + w * 0.7)},{f(top + h * 0.5)} q {f(w * 0.08)},{f(-h * 0.5)} {f(w * 0.2)},0" stroke="#FFFFFF" stroke-width="5" fill="none" stroke-linecap="round"/>')


def milk_pouch(s, cx, base_y, w, colour='#1E88E5'):
    """Milk packet (pouch) standing up."""
    h = w * 1.35
    x0, top = cx - w / 2, base_y - h
    return (shadow(s, cx, base_y, w) +
            f'<path d="M {f(x0 + w * 0.08)},{f(top)} L {f(x0 + w * 0.92)},{f(top)} L {f(x0 + w)},{f(base_y - h * 0.08)} Q {f(cx)},{f(base_y + h * 0.04)} {f(x0)},{f(base_y - h * 0.08)} Z" fill="#FAFAFA" stroke="#CFD8DC" stroke-width="2"/>'
            f'<rect x="{f(x0 + w * 0.05)}" y="{f(top + h * 0.3)}" width="{f(w * 0.9)}" height="{f(h * 0.36)}" rx="6" fill="{colour}"/>'
            f'<path d="M {f(cx - w * 0.22)},{f(top + h * 0.56)} q {f(w * 0.22)},{f(-h * 0.22)} {f(w * 0.44)},0" stroke="#FFFFFF" stroke-width="5" fill="none" stroke-linecap="round"/>'
            f'<rect x="{f(x0 + w * 0.08)}" y="{f(top)}" width="{f(w * 0.84)}" height="{f(h * 0.06)}" fill="{colour}" opacity="0.6"/>')


def bread(s, cx, base_y, w):
    """Sliced bread loaf in a bag."""
    h = w * 0.62
    x0, top = cx - w / 2, base_y - h
    crust = s.lin([(0, '#E2A65A'), (1, '#A8662A')], x1=0, y1=0, x2=0, y2=1)
    return (shadow(s, cx, base_y, w) +
            f'<path d="M {f(x0)},{f(base_y)} L {f(x0)},{f(top + h * 0.35)} Q {f(x0)},{f(top)} {f(x0 + w * 0.22)},{f(top)} L {f(x0 + w * 0.78)},{f(top)} Q {f(x0 + w)},{f(top)} {f(x0 + w)},{f(top + h * 0.35)} L {f(x0 + w)},{f(base_y)} Z" fill="{crust}"/>'
            f'<rect x="{f(x0 + w * 0.12)}" y="{f(top + h * 0.3)}" width="{f(w * 0.76)}" height="{f(h * 0.42)}" rx="8" fill="#FFF8E1" opacity="0.92"/>'
            f'<rect x="{f(x0 + w * 0.2)}" y="{f(top + h * 0.44)}" width="{f(w * 0.6)}" height="{f(h * 0.12)}" rx="4" fill="#C62828"/>'
            + ''.join(f'<line x1="{f(x0 + w * k / 6)}" y1="{f(top + h * 0.12)}" x2="{f(x0 + w * k / 6)}" y2="{f(top + h * 0.28)}" stroke="#8D4E1A" stroke-width="2" opacity="0.5"/>' for k in range(1, 6)))


def tea_cup(s, cx, base_y, w):
    """Cup of tea on a saucer with steam."""
    h = w * 0.62
    top = base_y - h
    cup = s.lin([(0, '#FFFFFF'), (1, '#D7DEE3')], x1=0, y1=0, x2=1, y2=0)
    return (f'<ellipse cx="{f(cx)}" cy="{f(base_y)}" rx="{f(w * 0.62)}" ry="{f(w * 0.12)}" fill="#ECEFF1" stroke="#B0BEC5" stroke-width="2"/>'
            f'<path d="M {f(cx - w * 0.42)},{f(top)} L {f(cx + w * 0.42)},{f(top)} Q {f(cx + w * 0.38)},{f(base_y - 6)} {f(cx)},{f(base_y - 4)} Q {f(cx - w * 0.38)},{f(base_y - 6)} {f(cx - w * 0.42)},{f(top)} Z" fill="{cup}"/>'
            f'<path d="M {f(cx + w * 0.4)},{f(top + h * 0.22)} q {f(w * 0.26)},{f(h * 0.05)} {f(w * 0.04)},{f(h * 0.5)}" stroke="#CFD8DC" stroke-width="{f(w * 0.06)}" fill="none"/>'
            f'<ellipse cx="{f(cx)}" cy="{f(top + 3)}" rx="{f(w * 0.4)}" ry="{f(w * 0.08)}" fill="#A0522D"/>'
            + ''.join(f'<path d="M {f(cx + dx)},{f(top - 10)} q {f(-12)},{f(-20)} 0,{f(-40)} q {f(12)},{f(-18)} 0,{f(-36)}" stroke="#B0BEC5" stroke-width="4" fill="none" opacity="0.6" stroke-linecap="round"/>' for dx in (-w * 0.15, w * 0.12)))


def coffee_jar(s, cx, base_y, w):
    """Instant-coffee jar with a red lid."""
    h = w * 1.2
    x0, top = cx - w / 2, base_y - h
    glass = s.lin([(0, '#6D3B1F'), (0.5, '#4E2A15'), (1, '#2E170A')], x1=0, y1=0, x2=1, y2=0)
    return (shadow(s, cx, base_y, w) +
            f'<rect x="{f(x0)}" y="{f(top + h * 0.15)}" width="{f(w)}" height="{f(h * 0.85)}" rx="{f(w * 0.12)}" fill="{glass}"/>'
            f'<rect x="{f(x0 - 3)}" y="{f(top)}" width="{f(w + 6)}" height="{f(h * 0.18)}" rx="6" fill="#C62828"/>'
            f'<rect x="{f(x0 + w * 0.1)}" y="{f(top + h * 0.38)}" width="{f(w * 0.8)}" height="{f(h * 0.36)}" rx="6" fill="#F6B800"/>'
            f'<ellipse cx="{f(cx)}" cy="{f(top + h * 0.56)}" rx="{f(w * 0.2)}" ry="{f(w * 0.12)}" fill="#4E2A15"/>')


def tea_box(s, cx, base_y, w):
    """Tea-powder box (green/gold)."""
    h = w * 1.1
    x0, top = cx - w / 2, base_y - h
    return (shadow(s, cx, base_y, w) +
            f'<rect x="{f(x0)}" y="{f(top)}" width="{f(w)}" height="{f(h)}" rx="6" fill="{s.lin([(0, "#2E7D32"), (1, "#1B5E20")], x1=0, y1=0, x2=1, y2=0)}"/>'
            f'<rect x="{f(x0)}" y="{f(top + h * 0.2)}" width="{f(w)}" height="{f(h * 0.12)}" fill="#F6C445"/>'
            f'<path d="M {f(cx)},{f(top + h * 0.45)} q {f(w * 0.25)},{f(h * 0.12)} 0,{f(h * 0.36)} q {f(-w * 0.25)},{f(-h * 0.12)} 0,{f(-h * 0.36)} Z" fill="#81C784"/>')


def diaper_pack(s, cx, base_y, w):
    """Diaper pack with a baby-face roundel."""
    h = w * 1.05
    x0, top = cx - w / 2, base_y - h
    return (shadow(s, cx, base_y, w) +
            f'<rect x="{f(x0)}" y="{f(top)}" width="{f(w)}" height="{f(h)}" rx="{f(w * 0.1)}" fill="{s.lin([(0, "#F8BBD0"), (1, "#EC407A")], x1=0, y1=0, x2=1, y2=1)}"/>'
            f'<circle cx="{f(cx)}" cy="{f(top + h * 0.45)}" r="{f(w * 0.24)}" fill="#FFF3E0"/>'
            f'<circle cx="{f(cx - w * 0.08)}" cy="{f(top + h * 0.42)}" r="4" fill="#5D4037"/><circle cx="{f(cx + w * 0.08)}" cy="{f(top + h * 0.42)}" r="4" fill="#5D4037"/>'
            f'<path d="M {f(cx - w * 0.08)},{f(top + h * 0.52)} q {f(w * 0.08)},{f(h * 0.07)} {f(w * 0.16)},0" stroke="#5D4037" stroke-width="3" fill="none" stroke-linecap="round"/>'
            f'<rect x="{f(x0 + w * 0.2)}" y="{f(top + h * 0.8)}" width="{f(w * 0.6)}" height="{f(h * 0.08)}" rx="4" fill="#FFFFFF"/>')


def feeding_bottle(s, cx, base_y, w):
    """Baby feeding bottle."""
    h = w * 2.2
    x0, top = cx - w / 2, base_y - h
    return (shadow(s, cx, base_y, w) +
            f'<path d="M {f(cx - w * 0.16)},{f(top + h * 0.2)} Q {f(cx)},{f(top - h * 0.02)} {f(cx + w * 0.16)},{f(top + h * 0.2)} Z" fill="#FFE0B2"/>'
            f'<rect x="{f(x0 - 2)}" y="{f(top + h * 0.18)}" width="{f(w + 4)}" height="{f(h * 0.12)}" rx="5" fill="#4FC3F7"/>'
            f'<rect x="{f(x0)}" y="{f(top + h * 0.3)}" width="{f(w)}" height="{f(h * 0.7)}" rx="{f(w * 0.25)}" fill="#E3F2FD" stroke="#90CAF9" stroke-width="2"/>'
            f'<rect x="{f(x0 + 3)}" y="{f(top + h * 0.6)}" width="{f(w - 6)}" height="{f(h * 0.38)}" rx="{f(w * 0.22)}" fill="#FFFFFF"/>'
            + ''.join(f'<line x1="{f(x0 + 4)}" y1="{f(top + h * (0.42 + k * 0.1))}" x2="{f(x0 + w * 0.3)}" y2="{f(top + h * (0.42 + k * 0.1))}" stroke="#90CAF9" stroke-width="2"/>' for k in range(5)))


def rice_bowl(s, cx, cy, rx):
    """A bowl heaped with white rice."""
    ry = rx * 0.32
    rnd = s.rnd
    bowl = s.lin([(0, '#FFFFFF'), (1, '#B0BEC5')], x1=0, y1=0, x2=0, y2=1)
    grains = ''.join(f'<ellipse cx="{f(cx + rnd.uniform(-rx * 0.75, rx * 0.75))}" cy="{f(cy - rnd.uniform(0, ry * 1.9))}" rx="{f(rx * 0.06)}" ry="{f(rx * 0.025)}" '
                     f'transform="rotate({f(rnd.uniform(0, 180))} {f(cx)} {f(cy)})" fill="#FFFFFF" stroke="#E0E0E0" stroke-width="0.8"/>' for _ in range(0))
    heap = s.rad([(0, '#FFFFFF'), (1, '#E8E2D6')], cx=0.45, cy=0.35, r=0.7)
    dots = ''.join(f'<ellipse cx="{f(cx + rnd.uniform(-rx * 0.75, rx * 0.75))}" cy="{f(cy - rnd.uniform(0, ry * 1.8))}" rx="{f(rx * 0.05)}" ry="{f(rx * 0.022)}" fill="#D7CCC8" opacity="0.8"/>' for _ in range(40))
    return (f'<ellipse cx="{f(cx)}" cy="{f(cy + ry * 1.9)}" rx="{f(rx * 0.95)}" ry="{f(ry * 0.4)}" fill="#2B1400" opacity="0.25" filter="{s.blur(6)}"/>'
            f'<path d="M {f(cx - rx)},{f(cy)} Q {f(cx)},{f(cy + ry * 3)} {f(cx + rx)},{f(cy)} Z" fill="{bowl}"/>'
            f'<path d="M {f(cx - rx * 0.92)},{f(cy)} Q {f(cx)},{f(cy - ry * 2.6)} {f(cx + rx * 0.92)},{f(cy)} Z" fill="{heap}"/>{dots}{grains}')
