"""Festive variants of the Jeya logo: every feather eye of the peacock is lit like a diya flame.

Reads app/assets/brand/logo_mark.png and logo_full.png, writes out/logo_mark.webp and out/logo_full.webp.
"""
import os

import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

BRAND = '../../app/assets/brand'
OUT = 'out'
os.makedirs(OUT, exist_ok=True)

# flame colours from the edge (0) to the core (1)
STOPS = [(0.0, (214, 64, 22)), (0.3, (244, 128, 16)), (0.58, (255, 190, 40)), (0.82, (255, 238, 150)), (1.0, (255, 253, 235))]


def ramp(c):
    c = np.clip(c, 0, 1)
    out = np.zeros(c.shape + (3,))
    for (a, ca), (b, cb) in zip(STOPS, STOPS[1:]):
        m = (c >= a) & (c <= b)
        t = ((c - a) / (b - a))[m][:, None]
        out[m] = np.array(ca) * (1 - t) + np.array(cb) * t
    return out


def light_up(name, size_hint):
    src = Image.open(f'{BRAND}/{name}.png').convert('RGBA')
    px = np.array(src).astype(float)
    alpha = px[:, :, 3]
    clear = alpha < 128
    lab, n = ndimage.label(clear)
    border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]])))
    eyes = [i for i in range(1, n + 1) if i not in border and (lab == i).sum() >= 150 and np.nonzero(lab == i)[0].mean() < 600]
    flame_rgb = np.zeros(px.shape[:2] + (3,))
    flame_a = np.zeros(px.shape[:2])
    glow_mask = np.zeros(px.shape[:2])
    for i in eyes:
        mask = lab == i
        ys, xs = np.nonzero(mask)
        cy, cx = ys.mean(), xs.mean()
        far = np.argmax((ys - cy) ** 2 + (xs - cx) ** 2)              # the teardrop's point = flame tip
        ty, tx = ys[far], xs[far]
        axis = np.array([ty - cy, tx - cx]); axis /= np.linalg.norm(axis) + 1e-6
        proj = (ys - cy) * axis[0] + (xs - cx) * axis[1]
        u = (proj - proj.min()) / (proj.max() - proj.min() + 1e-6)     # 0 at the round base, 1 at the tip
        dist = ndimage.distance_transform_edt(mask)[mask]
        d = dist / (dist.max() + 1e-6)
        core = d * 1.25 - u * 0.45 + 0.08
        flame_rgb[ys, xs] = ramp(core)
        # soft edge: use how transparent the original pixel was
        flame_a[ys, xs] = 1.0
        glow_mask[mask] = 1
    # anti-alias the flame edge into the feather rim
    edge = ndimage.binary_dilation(glow_mask > 0, iterations=2) & ~(glow_mask > 0)
    soft = (255 - alpha) / 255.0
    flame_a = np.where(edge, np.minimum(soft, 0.9) * (ndimage.uniform_filter(glow_mask, 3) > 0), flame_a)
    near = ndimage.distance_transform_edt(~(glow_mask > 0))
    nearest = ndimage.distance_transform_edt(~(glow_mask > 0), return_distances=False, return_indices=True)
    flame_rgb = np.where(edge[:, :, None], flame_rgb[nearest[0], nearest[1]], flame_rgb)

    base = Image.fromarray(px.astype(np.uint8))
    # warm glow spilling from the flames onto the feathers
    glow = Image.fromarray((glow_mask * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(size_hint * 0.012))
    glow_a = np.array(glow).astype(float) / 255.0 * 0.55 * (alpha / 255.0)
    g = np.array(base).astype(float)
    warm = np.array([255, 196, 60], float)
    g[:, :, :3] = g[:, :, :3] * (1 - glow_a[:, :, None]) + warm * glow_a[:, :, None]
    # flames on top
    fa = np.clip(flame_a, 0, 1)[:, :, None]
    g[:, :, :3] = g[:, :, :3] * (1 - fa) + flame_rgb * fa
    g[:, :, 3] = np.maximum(g[:, :, 3], fa[:, :, 0] * 255)
    lit = Image.fromarray(np.clip(g, 0, 255).astype(np.uint8))
    # faint golden halo around the whole peacock
    halo_src = Image.fromarray(alpha.astype(np.uint8)).filter(ImageFilter.GaussianBlur(size_hint * 0.02))
    halo = Image.new('RGBA', lit.size, (255, 200, 70, 0))
    halo.putalpha(halo_src.point(lambda v: int(v * 0.35)))
    final = Image.alpha_composite(halo, lit)
    final.save(f'{OUT}/{name}.webp', quality=92, method=6)
    final.save(f'{OUT}/{name}_preview.png')
    print(name, final.size, 'eyes lit:', len(eyes))


light_up('logo_mark', 588)
light_up('logo_full', 984)
