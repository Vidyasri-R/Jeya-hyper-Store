"""Web shop category illustrations and promo pictures (out/web/), transparent backgrounds.
Only packaged groceries and household items the store sells."""
import base64

from svgkit import *
from banners import murukku
from christmas_more import butter, chips_bowl, egg, flour_sack
from eid_more import cinnamon, rice_sack, star_anise
from karthigai_more import ghee_jar
from pongal_more import colour_bowl, dal_bowl, jaggery
from web_items import (biscuit_pack, bread, coffee_jar, detergent_box, diaper_pack, feeding_bottle, milk_pouch, oil_tin,
                       pump_bottle, rice_bowl, soap_bar, tea_box, tea_cup, toothpaste)

OUT = 'out/web'
S = 320  # category art is square


def tile(name, draw, seed):
    s = SVG(S, S, seed=seed)
    draw(s)
    s.save(f'{OUT}/cat_{name}.svg')


def staples(s):
    s.add(rice_sack(s, 120, 250, 130))
    s.add(flour_sack(s, 215, 252, 100))
    s.add(dal_bowl(s, 175, 268, 70))


def rice(s):
    s.add(rice_sack(s, 130, 245, 150))
    s.add(rice_bowl(s, 215, 250, 80))


def atta(s):
    s.add(flour_sack(s, 140, 255, 140))
    s.add(colour_bowl(s, 230, 255, 62, '#F5EBDC'))


def dals(s):
    s.add(dal_bowl(s, 110, 190, 70, ('#FFE082', '#F9A825')))
    s.add(dal_bowl(s, 215, 190, 70, ('#FFAB91', '#E64A19')))
    s.add(dal_bowl(s, 160, 262, 75, ('#C5E1A5', '#689F38')))


def oils(s):
    s.add(oil_tin(s, 135, 265, 140))
    s.add(ghee_jar(s, 238, 265, 90))


def masalas(s):
    s.add(colour_bowl(s, 100, 200, 62, '#C62828'))
    s.add(colour_bowl(s, 220, 200, 62, '#F9A825'))
    s.add(colour_bowl(s, 160, 260, 66, '#6D4C41'))
    s.add(star_anise(s, 60, 270, 22))
    s.add(cinnamon(s, 250, 270, 70, -20))


def salt_sugar(s):
    s.add(colour_bowl(s, 105, 215, 66, '#FFFFFF'))
    s.add(colour_bowl(s, 215, 215, 66, '#F3EEE4'))
    s.add(jaggery(s, 160, 262, 48))


def dairy(s):
    s.add(milk_pouch(s, 95, 245, 95))
    s.add(bread(s, 210, 245, 130))
    s.add(butter(s, 150, 250, 70))
    for x, a in [(110, -10), (150, 8), (190, -4)]:
        s.add(egg(s, x, 285, 18, a))


def snacks(s):
    s.add(biscuit_pack(s, 90, 255, 82))
    s.add(chips_bowl(s, 210, 240, 85))
    s.add(murukku(s, 170, 278, 34))


def beverages(s):
    s.add(tea_box(s, 85, 250, 80))
    s.add(coffee_jar(s, 245, 250, 80))
    s.add(tea_cup(s, 165, 280, 110))


def household(s):
    s.add(detergent_box(s, 110, 265, 130))
    s.add(pump_bottle(s, 230, 265, 80, body=('#66BB6A', '#2E7D32')))


def personal_care(s):
    s.add(pump_bottle(s, 95, 255, 85, body=('#CE93D8', '#7B1FA2')))
    s.add(pump_bottle(s, 180, 255, 70, body=('#4FC3F7', '#0277BD')))
    s.add(soap_bar(s, 245, 268, 100))
    s.add(toothpaste(s, 160, 290, 150))


def baby_care(s):
    s.add(diaper_pack(s, 125, 260, 150))
    s.add(feeding_bottle(s, 245, 265, 60))


TILES = [('staples', staples), ('rice', rice), ('atta', atta), ('dals', dals), ('oils', oils), ('masalas', masalas),
         ('salt_sugar', salt_sugar), ('dairy', dairy), ('snacks', snacks), ('beverages', beverages),
         ('household', household), ('personal_care', personal_care), ('baby_care', baby_care)]


def delivery_van(s, x, base_y, w, logo):
    """Green delivery van with the Jeya logo."""
    h = w * 0.55
    top = base_y - h
    body = s.lin([(0, '#2EA65A'), (1, '#14612F')], x1=0, y1=0, x2=0, y2=1)
    out = [f'<ellipse cx="{f(x + w / 2)}" cy="{f(base_y + 6)}" rx="{f(w * 0.55)}" ry="{f(w * 0.06)}" fill="#0B2A16" opacity="0.25" filter="{s.blur(6)}"/>',
           f'<rect x="{f(x)}" y="{f(top)}" width="{f(w * 0.68)}" height="{f(h * 0.85)}" rx="12" fill="{body}"/>',
           f'<path d="M {f(x + w * 0.66)},{f(top + h * 0.25)} L {f(x + w * 0.86)},{f(top + h * 0.25)} L {f(x + w)},{f(top + h * 0.55)} L {f(x + w)},{f(top + h * 0.85)} L {f(x + w * 0.66)},{f(top + h * 0.85)} Z" fill="{body}"/>',
           f'<path d="M {f(x + w * 0.72)},{f(top + h * 0.32)} L {f(x + w * 0.84)},{f(top + h * 0.32)} L {f(x + w * 0.94)},{f(top + h * 0.52)} L {f(x + w * 0.72)},{f(top + h * 0.52)} Z" fill="#E3F2FD"/>',
           f'<rect x="{f(x + w * 0.2)}" y="{f(top + h * 0.12)}" width="{f(w * 0.3)}" height="{f(w * 0.3)}" rx="12" fill="#FFFFFF"/>',
           f'<image x="{f(x + w * 0.22)}" y="{f(top + h * 0.12 + w * 0.02)}" width="{f(w * 0.26)}" height="{f(w * 0.26)}" href="data:image/png;base64,{logo}"/>']
    for cx in (x + w * 0.2, x + w * 0.8):
        out.append(f'<circle cx="{f(cx)}" cy="{f(top + h * 0.88)}" r="{f(w * 0.1)}" fill="#263238"/><circle cx="{f(cx)}" cy="{f(top + h * 0.88)}" r="{f(w * 0.045)}" fill="#B0BEC5"/>')
    for k in range(3):  # speed lines
        out.append(f'<line x1="{f(x - 70 + k * 12)}" y1="{f(top + h * (0.3 + k * 0.18))}" x2="{f(x - 15)}" y2="{f(top + h * (0.3 + k * 0.18))}" stroke="#2EA65A" stroke-width="6" stroke-linecap="round" opacity="0.5"/>')
    return ''.join(out)


def promo_delivery(logo):
    s = SVG(480, 320, seed=77)
    s.add(delivery_van(s, 150, 250, 300, logo))
    s.add(detergent_box(s, 70, 290, 60))
    s.add(oil_tin(s, 120, 290, 50))
    s.save(f'{OUT}/promo_delivery.svg')


def promo_payments():
    s = SVG(480, 320, seed=78)
    # phone with a UPI QR
    s.add('<rect x="250" y="40" width="150" height="260" rx="22" fill="#263238"/><rect x="260" y="56" width="130" height="228" rx="14" fill="#FFFFFF"/>')
    rnd = s.rnd
    cells = ''.join(f'<rect x="{275 + c * 10}" y="{95 + r * 10}" width="9" height="9" fill="#263238"/>' for r in range(10) for c in range(10) if rnd.random() < 0.5)
    s.add(f'<rect x="270" y="85" width="110" height="110" rx="6" fill="#FFFFFF" stroke="#CFD8DC"/>{cells}')
    for x, y in [(272, 87), (348, 87), (272, 163)]:
        s.add(f'<rect x="{x}" y="{y}" width="30" height="30" fill="#FFFFFF"/><rect x="{x + 3}" y="{y + 3}" width="24" height="24" fill="none" stroke="#263238" stroke-width="5"/><rect x="{x + 10}" y="{y + 10}" width="10" height="10" fill="#263238"/>')
    s.add('<rect x="280" y="215" width="90" height="34" rx="17" fill="#1B7A3E"/><path d="M 316,232 l 8,8 l 16,-16" stroke="#FFFFFF" stroke-width="5" fill="none" stroke-linecap="round" stroke-linejoin="round"/>')
    # card
    s.add(f'<g transform="rotate(-12 150 170)"><rect x="60" y="120" width="200" height="124" rx="14" fill="{s.lin([(0, "#3D7BE0"), (1, "#123E8C")], x1=0, y1=0, x2=1, y2=1)}"/>'
          '<rect x="80" y="150" width="34" height="26" rx="5" fill="#F6C445"/><rect x="80" y="200" width="140" height="10" rx="5" fill="#FFFFFF" opacity="0.7"/>'
          '<circle cx="215" cy="160" r="14" fill="#E53935" opacity="0.9"/><circle cx="232" cy="160" r="14" fill="#F6B800" opacity="0.9"/></g>')
    # rupee notes
    s.add('<g transform="rotate(8 120 270)"><rect x="40" y="240" width="170" height="64" rx="8" fill="#A5D6A7" stroke="#2E7D32" stroke-width="2"/>'
          '<circle cx="125" cy="272" r="20" fill="#C8E6C9" stroke="#2E7D32" stroke-width="2"/><text x="125" y="280" text-anchor="middle" font-family="Arial" font-weight="700" font-size="24" fill="#1B5E20">₹</text></g>')
    s.save(f'{OUT}/promo_payments.svg')


if __name__ == '__main__':
    for i, (name, draw) in enumerate(TILES):
        tile(name, draw, 1000 + i)
    with open('../../app/assets/brand/logo_mark.png', 'rb') as fh:
        logo = base64.b64encode(fh.read()).decode()
    promo_delivery(logo)
    promo_payments()
