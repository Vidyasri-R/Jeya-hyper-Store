"""Cut the Jeya logo (app/assets/brand/logo_full.png) into the pieces the splash intro animates.

The peacock flies in (body + head + flapping wings, its nine feathers trailing as a train), lands as
the "J", fans its feathers out into the logo and the wordmark rises in. The pieces are the logo's
own pixels, so the last frame is exactly logo_full.png.

  cd design/brand-intro && python3 split_logo.py

Writes app/assets/brand/intro/*.webp and app/lib/widgets/brand_intro_parts.dart (positions in the
984 × 808 logo, feather angles round the point they fan from, wing hinges).
"""
import math
import os
import subprocess

import numpy as np
import scipy.ndimage as ndi
from PIL import Image

APP = '../../app'
SRC = f'{APP}/assets/brand/logo_full.png'
OUT = f'{APP}/assets/brand/intro'
DART = f'{APP}/lib/widgets/brand_intro_parts.dart'
WORD_Y = 600        # the wordmark starts below this row
WORD_SPLIT_Y = 731  # between "JEYA HYPER" and "STORE"
os.makedirs(OUT, exist_ok=True)

img = np.array(Image.open(SRC).convert('RGBA'))
H, W = img.shape[:2]
rgb = img[..., :3].astype(int)
alpha = img[..., 3].astype(int)
lum = 0.3 * rgb[..., 0] + 0.59 * rgb[..., 1] + 0.11 * rgb[..., 2]
ys, xs = np.mgrid[0:H, 0:W]
mark = ys < WORD_Y

# Shapes are separated by thin dark drop shadows: cut on brightness, not just opacity.
lab, n = ndi.label((alpha > 128) & (lum > 25) & mark)
sizes = ndi.sum(np.ones_like(lab), lab, range(1, n + 1))
blue = rgb[..., 2] > rgb[..., 1] + 25


def comp_at(x, y):
    i = lab[y, x]
    assert i, f'no shape at {x},{y}'
    return i


body_id, curl_id, head_id = comp_at(494, 450), comp_at(396, 540), comp_at(493, 240)
pieces = np.zeros((H, W), np.int16)   # 0 none, 1..9 feathers, then named pieces
NAMES = {}
feather_ids = []
for i in range(1, n + 1):
    if sizes[i - 1] < 1500 or i in (body_id, curl_id, head_id):
        continue
    box = ndi.find_objects((lab == i).astype(int))[0]
    region_blue = blue[box][lab[box] == i].mean()
    if region_blue > 0.5:   # the left wing came off the body at its shadow line
        NAMES['wing_l'] = i
    else:
        feather_ids.append(i)
assert len(feather_ids) == 9, feather_ids


def centroid(m):
    yy, xx = np.nonzero(m)
    return xx.mean(), yy.mean()


# pivot: the point the nine feathers fan out from = least-squares meet of their long axes
axes = []
for i in feather_ids:
    yy, xx = np.nonzero(lab == i)
    pts = np.stack([xx, yy], 1).astype(float)
    c = pts.mean(0)
    _, _, vt = np.linalg.svd(pts - c, full_matrices=False)
    axes.append((c, vt[0]))
A = np.zeros((2, 2)); b = np.zeros(2)
for c, d in axes:
    P = np.eye(2) - np.outer(d, d)
    A += P; b += P @ c
pivot = np.linalg.solve(A, b)


def angle_from_pivot(c):
    return math.degrees(math.atan2(c[0] - pivot[0], -(c[1] - pivot[1])))   # 0 = straight up, clockwise +


feather_ids.sort(key=lambda i: angle_from_pivot(centroid(lab == i)))
for k, i in enumerate(feather_ids, 1):
    pieces[lab == i] = k
ID = {'body': 10, 'head': 11, 'wing_l': 12, 'wing_r': 13}
body = (lab == body_id) | (lab == curl_id)
stem_l, stem_r = 466, 522    # the green J stem; blue beyond it below the neck are the wings
wing_r = body & blue & (xs > stem_r) & (ys > 360)
wing_l = (lab == NAMES['wing_l']) | (body & blue & (xs < stem_l) & (ys > 360))
pieces[body] = ID['body']
pieces[wing_r] = ID['wing_r']
pieces[wing_l] = ID['wing_l']
pieces[lab == head_id] = ID['head']

# every visible pixel (soft edges, shadows) goes with the nearest piece
_, (iy, ix) = ndi.distance_transform_edt(pieces == 0, return_indices=True)
owner = pieces[iy, ix]
owner[(alpha == 0) | ~mark] = 0
word = (alpha > 0) & ~mark
owner[word & (ys < WORD_SPLIT_Y)] = 20
owner[word & (ys >= WORD_SPLIT_Y)] = 21

files = {}


def save(name, pid):
    m = owner == pid
    yy, xx = np.nonzero(m)
    x0, y0, x1, y1 = max(0, xx.min() - 2), max(0, yy.min() - 2), min(W, xx.max() + 3), min(H, yy.max() + 3)
    crop = img[y0:y1, x0:x1].copy()
    crop[~m[y0:y1, x0:x1]] = 0
    Image.fromarray(crop).save(f'{OUT}/{name}.webp', 'WEBP', quality=92, alpha_quality=100, method=6)
    files[name] = (x0, y0, x1 - x0, y1 - y0)
    return m


for k in range(1, 10):
    save(f'feather_{k}', k)
for name in ('body', 'head', 'wing_l', 'wing_r'):
    save(name, ID[name])
save('word_top', 20)
save('word_bottom', 21)

# check: the pieces put back together are the logo
re = np.zeros_like(img)
for name, (x0, y0, w, h) in files.items():
    p = np.array(Image.open(f'{OUT}/{name}.webp').convert('RGBA'))
    sub = re[y0:y0 + h, x0:x0 + w]
    m = p[..., 3] > 0
    sub[m] = p[m]
err = np.abs(re.astype(int) - img.astype(int))[alpha > 0].mean()
print(f'pivot {pivot.round(1)}, reassembly mean error {err:.2f} (webp)')


def hinge(name):
    x0, y0, w, h = files[name]
    m = owner[y0:y0 + h, x0:x0 + w] == ID[name]
    yy, xx = np.nonzero(m)
    top = yy.min() + 6
    row = xx[yy <= top]
    return (int(x0 + (row.max() if name == 'wing_l' else row.min())), int(y0 + top))   # the corner tucked under the neck


feathers = []
for k, i in enumerate(feather_ids, 1):
    c = centroid(owner == k)
    feathers.append((f'feather_{k}', angle_from_pivot(c), math.hypot(c[0] - pivot[0], c[1] - pivot[1])))

kb = sum(os.path.getsize(f'{OUT}/{n}.webp') for n in files) / 1024


def rect(name):
    x0, y0, w, h = files[name]
    return f'Rect.fromLTWH({x0}, {y0}, {w}, {h})'


lines = ['// GENERATED by design/brand-intro/split_logo.py from assets/brand/logo_full.png — do not edit.',
         "import 'dart:ui';", '',
         '/// One piece of the logo: its image and where it sits in the 984 × 808 logo.',
         'class BrandPiece {',
         '  const BrandPiece(this.asset, this.rect, {this.angle = 0, this.reach = 0, this.hinge = Offset.zero});',
         '  final String asset;',
         '  final Rect rect;', '',
         '  /// Feathers: direction from [BrandIntroParts.pivot] in degrees (0 = up, clockwise) and distance.',
         '  final double angle, reach;', '',
         '  /// Wings: the corner they flap about.',
         '  final Offset hinge;',
         '}', '',
         'abstract final class BrandIntroParts {',
         f'  static const size = Size({W}, {H});',
         '',
         '  /// Where the feathers fan out from (behind the J).',
         f'  static const pivot = Offset({pivot[0]:.1f}, {pivot[1]:.1f});',
         '',
         '  /// Left to right.',
         '  static const feathers = [']
for name, ang, reach in feathers:
    lines.append(f"    BrandPiece('assets/brand/intro/{name}.webp', {rect(name)}, angle: {ang:.1f}, reach: {reach:.1f}),")
lines += ['  ];',
          f"  static const body = BrandPiece('assets/brand/intro/body.webp', {rect('body')});",
          f"  static const head = BrandPiece('assets/brand/intro/head.webp', {rect('head')});",
          f"  static const wingLeft = BrandPiece('assets/brand/intro/wing_l.webp', {rect('wing_l')}, hinge: Offset{hinge('wing_l')});",
          f"  static const wingRight = BrandPiece('assets/brand/intro/wing_r.webp', {rect('wing_r')}, hinge: Offset{hinge('wing_r')});",
          f"  static const wordTop = BrandPiece('assets/brand/intro/word_top.webp', {rect('word_top')});",
          f"  static const wordBottom = BrandPiece('assets/brand/intro/word_bottom.webp', {rect('word_bottom')});",
          '',
          '  static List<BrandPiece> get all => [...feathers, body, head, wingLeft, wingRight, wordTop, wordBottom];',
          '}', '']
open(DART, 'w').write('\n'.join(lines))
print(f'{len(files)} pieces, {kb:.0f} KB; wrote {DART}')
for name, ang, reach in feathers:
    print(f'  {name}: {ang:6.1f}°  reach {reach:5.1f}')
