"""Tiny SVG toolkit for the Jeya festival artwork (original vector art, rendered to WebP by sharp/librsvg)."""
import math
import random


def f(v):
    return f"{v:.2f}".rstrip('0').rstrip('.')


class SVG:
    def __init__(self, w, h, seed=7):
        self.w, self.h = w, h
        self.defs, self.body = [], []
        self._n = 0
        self.rnd = random.Random(seed)
        self._blurs = {}

    def uid(self, p='g'):
        self._n += 1
        return f'{p}{self._n}'

    def add(self, s):
        self.body.append(s)

    def blur(self, sd):
        key = f(sd)
        if key not in self._blurs:
            i = self.uid('blur')
            self.defs.append(f'<filter id="{i}" x="-60%" y="-60%" width="220%" height="220%"><feGaussianBlur stdDeviation="{key}"/></filter>')
            self._blurs[key] = i
        return f'url(#{self._blurs[key]})'

    def lin(self, stops, x1=0, y1=0, x2=0, y2=1, units='objectBoundingBox'):
        i = self.uid('lg')
        s = ''.join(f'<stop offset="{f(o)}" stop-color="{c}"' + (f' stop-opacity="{f(a)}"' if a != 1 else '') + '/>' for o, c, a in _norm(stops))
        self.defs.append(f'<linearGradient id="{i}" x1="{f(x1)}" y1="{f(y1)}" x2="{f(x2)}" y2="{f(y2)}" gradientUnits="{units}">{s}</linearGradient>')
        return f'url(#{i})'

    def rad(self, stops, cx=0.5, cy=0.5, r=0.5, fx=None, fy=None, units='objectBoundingBox'):
        i = self.uid('rg')
        s = ''.join(f'<stop offset="{f(o)}" stop-color="{c}"' + (f' stop-opacity="{f(a)}"' if a != 1 else '') + '/>' for o, c, a in _norm(stops))
        fxy = (f' fx="{f(fx)}"' if fx is not None else '') + (f' fy="{f(fy)}"' if fy is not None else '')
        self.defs.append(f'<radialGradient id="{i}" cx="{f(cx)}" cy="{f(cy)}" r="{f(r)}"{fxy} gradientUnits="{units}">{s}</radialGradient>')
        return f'url(#{i})'

    def clip(self, inner):
        i = self.uid('cp')
        self.defs.append(f'<clipPath id="{i}">{inner}</clipPath>')
        return f'url(#{i})'

    def svg(self):
        return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{self.w}" height="{self.h}" viewBox="0 0 {self.w} {self.h}">'
                f'<defs>{"".join(self.defs)}</defs>{"".join(self.body)}</svg>')

    def save(self, path):
        with open(path, 'w') as fh:
            fh.write(self.svg())


def _norm(stops):
    out = []
    for s in stops:
        if len(s) == 2:
            out.append((s[0], s[1], 1))
        else:
            out.append(s)
    return out


# ───────────────────────── motifs ─────────────────────────

def star4(cx, cy, r, fill, opacity=1.0, rot=0, thin=0.22):
    """Four-point sparkle."""
    pts = []
    for i in range(8):
        a = math.radians(rot + i * 45)
        rr = r if i % 2 == 0 else r * thin
        pts.append(f'{f(cx + math.cos(a) * rr)},{f(cy + math.sin(a) * rr)}')
    return f'<polygon points="{" ".join(pts)}" fill="{fill}" opacity="{f(opacity)}"/>'


def sparkle(s, cx, cy, r, color='#FFF3C4', glow='#FFD54F', opacity=1.0):
    return (f'<circle cx="{f(cx)}" cy="{f(cy)}" r="{f(r * 0.9)}" fill="{glow}" opacity="{f(0.35 * opacity)}" filter="{s.blur(r * 0.45)}"/>'
            + star4(cx, cy, r, color, opacity) + star4(cx, cy, r * 0.55, '#FFFFFF', opacity, rot=45, thin=0.3))


def marigold(s, cx, cy, r, kind='orange', depth=True):
    """Dense ruffled marigold (genda phool) seen from the front."""
    pal = {
        'orange': ('#FFCC80', '#FB8C00', '#EF6C00', '#E65100', '#BF360C'),
        'yellow': ('#FFF59D', '#FDD835', '#FBC02D', '#F9A825', '#E65100'),
        'deep': ('#FFAB91', '#F4511E', '#E64A19', '#D84315', '#8D1B0B'),
    }[kind]
    light, mid, outer, core, edge = pal
    rnd = s.rnd
    g = s.rad([(0, light), (0.5, mid), (1, outer)], cx=cx, cy=cy, r=r, units='userSpaceOnUse')
    g2 = s.rad([(0, light), (0.65, mid), (1, core)], cx=cx - r * 0.15, cy=cy - r * 0.2, r=r * 1.1, units='userSpaceOnUse')
    out = []
    if depth:
        out.append(f'<circle cx="{f(cx + r * 0.06)}" cy="{f(cy + r * 0.14)}" r="{f(r * 0.98)}" fill="#3B0A0A" opacity="0.30" filter="{s.blur(r * 0.14)}"/>')
    rings = [(0.70, 22, 0.46, 0.30), (0.52, 18, 0.42, 0.30), (0.34, 14, 0.38, 0.28), (0.17, 9, 0.30, 0.25)]
    for k, (rad_, n, plen, pw) in enumerate(rings):
        off = rnd.uniform(0, 360 / n)
        for i in range(n):
            a = off + i * 360 / n + rnd.uniform(-5, 5)
            ar = math.radians(a)
            px, py = cx + math.cos(ar) * r * rad_, cy + math.sin(ar) * r * rad_
            fill = g if (i + k) % 3 else g2
            out.append(f'<ellipse cx="{f(px)}" cy="{f(py)}" rx="{f(r * plen * 0.5)}" ry="{f(r * pw * 0.5)}" transform="rotate({f(a)} {f(px)} {f(py)})" '
                       f'fill="{fill}" stroke="{edge}" stroke-opacity="0.32" stroke-width="{f(max(0.6, r * 0.022))}"/>')
            # ruffle crease
            ex, ey = cx + math.cos(ar) * r * (rad_ + plen * 0.18), cy + math.sin(ar) * r * (rad_ + plen * 0.18)
            out.append(f'<line x1="{f(px)}" y1="{f(py)}" x2="{f(ex)}" y2="{f(ey)}" stroke="{edge}" stroke-opacity="0.22" stroke-width="{f(max(0.5, r * 0.018))}" stroke-linecap="round"/>')
    out.append(f'<circle cx="{f(cx)}" cy="{f(cy)}" r="{f(r * 0.13)}" fill="{core}"/>')
    out.append(f'<circle cx="{f(cx - r * 0.25)}" cy="{f(cy - r * 0.3)}" r="{f(r * 0.35)}" fill="#FFFFFF" opacity="0.16" filter="{s.blur(r * 0.12)}"/>')
    # volume: darker rim
    rim = s.rad([(0.6, '#000000', 0), (1, '#4E0D00', 0.28)], cx=cx, cy=cy, r=r * 0.95, units='userSpaceOnUse')
    out.append(f'<circle cx="{f(cx)}" cy="{f(cy)}" r="{f(r * 0.92)}" fill="{rim}"/>')
    return ''.join(out)


def mango_leaf(s, x, y, length, width, angle=0, tone=0):
    """Mango leaf hanging from its stalk at (x, y), pointing down."""
    w = width / 2
    st = length * 0.08
    L = length
    tones = [('#1B5E20', '#2E7D32', '#4CAF50'), ('#205E25', '#33691E', '#689F38'), ('#174D1C', '#2E7D32', '#43A047')]
    d0, d1, d2 = tones[tone % 3]
    g = s.lin([(0, d0), (0.55, d1), (1, d2)], x1=0, y1=0, x2=1, y2=0.2)
    body = (f'M 0,{f(st)} C {f(w * 1.05)},{f(st + L * 0.12)} {f(w * 0.95)},{f(st + L * 0.62)} 0,{f(st + L)} '
            f'C {f(-w * 0.95)},{f(st + L * 0.62)} {f(-w * 1.05)},{f(st + L * 0.12)} 0,{f(st)} Z')
    veins = ''.join(
        f'<path d="M {f(0)},{f(st + L * t)} Q {f(sgn * w * 0.45)},{f(st + L * (t + 0.05))} {f(sgn * w * 0.78)},{f(st + L * (t + 0.13))}" '
        f'stroke="#C5E1A5" stroke-opacity="0.28" stroke-width="{f(max(0.5, width * 0.025))}" fill="none"/>'
        for t in (0.18, 0.32, 0.46, 0.6, 0.72) for sgn in (-1, 1))
    return (f'<g transform="translate({f(x)} {f(y)}) rotate({f(angle)})">'
            f'<path d="{body}" fill="#000" opacity="0.35" transform="translate({f(width * 0.08)} {f(width * 0.12)})" filter="{s.blur(width * 0.08)}"/>'
            f'<path d="{body}" fill="{g}"/>'
            f'{veins}'
            f'<path d="M 0,{f(st)} Q {f(w * 0.12)},{f(st + L * 0.5)} 0,{f(st + L * 0.97)}" stroke="#DCEDC8" stroke-opacity="0.7" stroke-width="{f(max(0.7, width * 0.045))}" fill="none"/>'
            f'<path d="M {f(-w * 0.55)},{f(st + L * 0.2)} Q {f(-w * 0.75)},{f(st + L * 0.45)} {f(-w * 0.35)},{f(st + L * 0.7)}" stroke="#FFFFFF" stroke-opacity="0.18" stroke-width="{f(width * 0.08)}" fill="none" stroke-linecap="round"/>'
            f'<line x1="0" y1="0" x2="0" y2="{f(st + 1)}" stroke="#5D4037" stroke-width="{f(max(1, width * 0.06))}" stroke-linecap="round"/>'
            f'</g>')


def flame_path(W, H):
    return (f'M 0,{f(-H)} C {f(W * 0.14)},{f(-H * 0.74)} {f(W * 0.62)},{f(-H * 0.46)} {f(W * 0.5)},{f(-H * 0.17)} '
            f'C {f(W * 0.42)},{f(H * 0.03)} {f(-W * 0.42)},{f(H * 0.03)} {f(-W * 0.5)},{f(-H * 0.17)} '
            f'C {f(-W * 0.62)},{f(-H * 0.46)} {f(-W * 0.14)},{f(-H * 0.74)} 0,{f(-H)} Z')


def flame(s, x, y, W, H, glow=True):
    """Flame with its base at (x, y)."""
    out = []
    if glow:
        out.append(f'<ellipse cx="{f(x)}" cy="{f(y - H * 0.42)}" rx="{f(W * 1.5)}" ry="{f(H * 0.85)}" fill="#FFB300" opacity="0.40" filter="{s.blur(W * 0.55)}"/>')
        out.append(f'<ellipse cx="{f(x)}" cy="{f(y - H * 0.35)}" rx="{f(W * 0.75)}" ry="{f(H * 0.5)}" fill="#FFE082" opacity="0.55" filter="{s.blur(W * 0.25)}"/>')
    g = s.rad([(0, '#FFFFFF'), (0.28, '#FFF59D'), (0.6, '#FFB300'), (0.85, '#FB8C00'), (1, '#F4511E')], cx=0.5, cy=0.78, r=0.62, fy=0.85)
    out.append(f'<path d="{flame_path(W, H)}" transform="translate({f(x)} {f(y)})" fill="{g}"/>')
    core = s.rad([(0, '#FFFFFF'), (0.7, '#FFFDE7'), (1, '#FFF59D', 0)], cx=0.5, cy=0.7, r=0.6)
    out.append(f'<path d="{flame_path(W * 0.46, H * 0.5)}" transform="translate({f(x)} {f(y - H * 0.04)})" fill="{core}"/>')
    out.append(f'<ellipse cx="{f(x)}" cy="{f(y - H * 0.03)}" rx="{f(W * 0.16)}" ry="{f(H * 0.05)}" fill="#90CAF9" opacity="0.55"/>')
    out.append(f'<line x1="{f(x)}" y1="{f(y + H * 0.02)}" x2="{f(x)}" y2="{f(y - H * 0.12)}" stroke="#3E2723" stroke-width="{f(max(1, W * 0.07))}" stroke-linecap="round"/>')
    return ''.join(out)


def diya(s, cx, cy, size, style=0, with_flame=True):
    """Front-view clay agal vilakku; (cx, cy) is the wick tip. size = body width."""
    w = size / 2
    h = size * 0.42
    top = cy + size * 0.06
    body = (f'M {f(cx - w)},{f(top)} Q {f(cx - w * 0.92)},{f(top + h)} {f(cx)},{f(top + h * 1.05)} Q {f(cx + w * 0.92)},{f(top + h)} {f(cx + w)},{f(top)} '
            f'Q {f(cx + w * 0.55)},{f(top + h * 0.2)} {f(cx + w * 0.2)},{f(top + h * 0.06)} L {f(cx)},{f(cy)} L {f(cx - w * 0.2)},{f(top + h * 0.06)} '
            f'Q {f(cx - w * 0.55)},{f(top + h * 0.2)} {f(cx - w)},{f(top)} Z')
    clays = [('#FF8A50', '#D84315', '#7F1D0B'), ('#FFAB40', '#E65100', '#8D2A07'), ('#FF7043', '#C62828', '#6D0F0F')]
    c0, c1, c2 = clays[style % 3]
    g = s.lin([(0, c0), (0.45, c1), (1, c2)], x1=0, y1=0, x2=0.15, y2=1)
    out = [f'<ellipse cx="{f(cx)}" cy="{f(top + h * 1.12)}" rx="{f(w * 0.95)}" ry="{f(h * 0.16)}" fill="#1A0505" opacity="0.45" filter="{s.blur(h * 0.08)}"/>',
           f'<path d="{body}" fill="{g}"/>']
    clipid = s.clip(f'<path d="{body}"/>')
    band_y = top + h * 0.42
    deco = [f'<path d="M {f(cx - w)},{f(band_y)} Q {f(cx)},{f(band_y + h * 0.22)} {f(cx + w)},{f(band_y)}" stroke="#FFD54F" stroke-width="{f(size * 0.035)}" fill="none"/>',
            f'<path d="M {f(cx - w)},{f(band_y + h * 0.16)} Q {f(cx)},{f(band_y + h * 0.38)} {f(cx + w)},{f(band_y + h * 0.16)}" stroke="#FFD54F" stroke-width="{f(size * 0.02)}" fill="none" opacity="0.8"/>']
    for i in range(-5, 6):
        t = i / 6
        dx = cx + t * w * 0.88
        dy = band_y + h * 0.08 + (1 - t * t) * h * 0.13
        deco.append(f'<circle cx="{f(dx)}" cy="{f(dy)}" r="{f(size * 0.022)}" fill="#FFF3C4"/>')
    for i in range(-3, 4):
        t = i / 4
        dx = cx + t * w * 0.7
        dy = band_y + h * 0.42 + (1 - t * t) * h * 0.12
        deco.append(f'<path d="M {f(dx)},{f(dy - size * 0.04)} L {f(dx + size * 0.03)},{f(dy)} L {f(dx)},{f(dy + size * 0.04)} L {f(dx - size * 0.03)},{f(dy)} Z" fill="#FFE082" opacity="0.9"/>')
    out.append(f'<g clip-path="{clipid}">{"".join(deco)}'
               f'<ellipse cx="{f(cx - w * 0.5)}" cy="{f(top + h * 0.45)}" rx="{f(w * 0.18)}" ry="{f(h * 0.45)}" fill="#FFFFFF" opacity="0.14" filter="{s.blur(size * 0.03)}"/></g>')
    # oil + rim
    out.append(f'<path d="M {f(cx - w * 0.92)},{f(top + h * 0.02)} Q {f(cx - w * 0.5)},{f(top + h * 0.2)} {f(cx - w * 0.18)},{f(top + h * 0.08)} L {f(cx)},{f(cy + size * 0.02)} '
               f'L {f(cx + w * 0.18)},{f(top + h * 0.08)} Q {f(cx + w * 0.5)},{f(top + h * 0.2)} {f(cx + w * 0.92)},{f(top + h * 0.02)}" stroke="#FFE082" stroke-width="{f(size * 0.03)}" fill="none" stroke-linejoin="round"/>')
    if with_flame:
        out.append(flame(s, cx, cy + size * 0.01, size * 0.24, size * 0.62))
    return ''.join(out)


def mandala(s, cx, cy, R, color='#FFD54F', opacity=0.15, stroke=2.0, fill_opacity=0.05):
    """Concentric rangoli rings in line-art."""
    out = [f'<g opacity="{f(opacity)}" fill="none" stroke="{color}" stroke-width="{f(stroke)}">']
    rings = [0.12, 0.22, 0.34, 0.47, 0.6, 0.74, 0.88, 1.0]
    out.append(f'<circle cx="{f(cx)}" cy="{f(cy)}" r="{f(R * 0.05)}" fill="{color}" fill-opacity="0.6"/>')
    for k, t in enumerate(rings):
        r = R * t
        if k % 3 == 0:
            n = 8 + k * 4
            for i in range(n):
                a = math.radians(i * 360 / n)
                x1, y1 = cx + math.cos(a) * r * 0.82, cy + math.sin(a) * r * 0.82
                tip = r * 1.12
                x2, y2 = cx + math.cos(a) * tip, cy + math.sin(a) * tip
                a1, a2 = a - math.pi / n * 0.9, a + math.pi / n * 0.9
                c1 = (cx + math.cos(a1) * r * 1.02, cy + math.sin(a1) * r * 1.02)
                c2 = (cx + math.cos(a2) * r * 1.02, cy + math.sin(a2) * r * 1.02)
                out.append(f'<path d="M {f(x1)},{f(y1)} Q {f(c1[0])},{f(c1[1])} {f(x2)},{f(y2)} Q {f(c2[0])},{f(c2[1])} {f(x1)},{f(y1)} Z" fill="{color}" fill-opacity="{f(fill_opacity)}"/>')
        elif k % 3 == 1:
            n = 16 + k * 6
            for i in range(n):
                a = math.radians(i * 360 / n)
                out.append(f'<circle cx="{f(cx + math.cos(a) * r)}" cy="{f(cy + math.sin(a) * r)}" r="{f(max(1.2, R * 0.012))}" fill="{color}" stroke="none" fill-opacity="0.9"/>')
            out.append(f'<circle cx="{f(cx)}" cy="{f(cy)}" r="{f(r * 0.94)}"/>')
        else:
            n = 12 + k * 3
            pts = []
            for i in range(n * 2 + 1):
                a = math.radians(i * 180 / n)
                rr = r * (1.0 if i % 2 == 0 else 0.9)
                pts.append(f'{f(cx + math.cos(a) * rr)},{f(cy + math.sin(a) * rr)}')
            out.append(f'<polyline points="{" ".join(pts)}"/>')
    out.append('</g>')
    return ''.join(out)


def bokeh(s, x, y, r, color='#FFB74D', opacity=0.3):
    g = s.rad([(0, color, opacity), (0.7, color, opacity * 0.5), (1, color, 0)], cx=x, cy=y, r=r, units='userSpaceOnUse')
    return f'<circle cx="{f(x)}" cy="{f(y)}" r="{f(r)}" fill="{g}"/>'


def paisley(s, x, y, size, angle=0, color='#FFD54F', opacity=0.9, fill='none'):
    sz = size
    d = (f'M 0,0 C {f(sz * 0.55)},{f(-sz * 0.05)} {f(sz * 0.62)},{f(-sz * 0.7)} {f(sz * 0.05)},{f(-sz * 0.85)} '
         f'C {f(-sz * 0.45)},{f(-sz * 0.95)} {f(-sz * 0.6)},{f(-sz * 0.35)} {f(-sz * 0.25)},{f(-sz * 0.15)} '
         f'C {f(-sz * 0.12)},{f(-sz * 0.07)} {f(-sz * 0.05)},{f(-sz * 0.02)} 0,0 Z')
    inner = f'<circle cx="{f(sz * 0.05)}" cy="{f(-sz * 0.52)}" r="{f(sz * 0.14)}" fill="none" stroke="{color}" stroke-width="{f(sz * 0.04)}"/>'
    dots = ''.join(f'<circle cx="{f(sz * (0.05 + 0.34 * math.cos(t)))}" cy="{f(-sz * (0.52 - 0.34 * math.sin(t)))}" r="{f(sz * 0.03)}" fill="{color}"/>'
                   for t in [i * 0.55 for i in range(10)])
    return (f'<g transform="translate({f(x)} {f(y)}) rotate({f(angle)})" opacity="{f(opacity)}">'
            f'<path d="{d}" fill="{fill}" stroke="{color}" stroke-width="{f(sz * 0.05)}"/>{inner}{dots}</g>')
