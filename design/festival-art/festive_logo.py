"""Festive Jeya app icon: every feather eye of the peacock is lit like a diya flame.

Writes the Deepavali icon set to app/branding/app_icon/diwali/ (Android launcher mipmaps + iOS
AppIcon), next to a copy of the everyday set in app/branding/app_icon/standard/. Switch the app
between them with app/tool/app_icon.sh.
"""
import os

import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

BRAND = '../../app/assets/brand'
OUT = 'out'
os.makedirs(OUT, exist_ok=True)

# eye colours from the edge (0) to the core (1), per festival
RAMPS = {
    'diwali': [(0.0, (214, 64, 22)), (0.3, (244, 128, 16)), (0.58, (255, 190, 40)), (0.82, (255, 238, 150)), (1.0, (255, 253, 235))],  # diya flames
    'pongal': [(0.0, (222, 150, 0)), (0.3, (250, 192, 0)), (0.65, (255, 222, 40)), (1.0, (255, 244, 160))],  # turmeric-and-sun yellow
    'christmas': [(0.0, (120, 0, 12)), (0.35, (190, 20, 32)), (0.7, (232, 64, 64)), (1.0, (255, 196, 196))],  # holly-berry red
    'valentine': [(0.0, (150, 10, 70)), (0.35, (215, 40, 110)), (0.7, (245, 110, 160)), (1.0, (255, 214, 230))],  # rose pink
}
STOPS = RAMPS['diwali']


def ramp(c):
    c = np.clip(c, 0, 1)
    out = np.zeros(c.shape + (3,))
    for (a, ca), (b, cb) in zip(STOPS, STOPS[1:]):
        m = (c >= a) & (c <= b)
        t = ((c - a) / (b - a))[m][:, None]
        out[m] = np.array(ca) * (1 - t) + np.array(cb) * t
    return out


def light_up(src, size_hint, halo=True):
    """Light the peacock's feather eyes in src (RGBA, transparent or white background)."""
    px = np.array(src.convert('RGBA')).astype(float)
    alpha = px[:, :, 3]
    r, g_, b = px[:, :, 0], px[:, :, 1], px[:, :, 2]
    whiteish = (r > 200) & (g_ > 200) & (b > 200) & ((np.maximum(np.maximum(r, g_), b) - np.minimum(np.minimum(r, g_), b)) < 24)
    clear = (alpha < 128) | whiteish
    lab, n = ndimage.label(clear)
    border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]])))
    min_area = max(10, int(size_hint * size_hint * 0.0002))
    eyes = [i for i in range(1, n + 1) if i not in border and (lab == i).sum() >= min_area]
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
    soft = np.where(whiteish, 1.0, (255 - alpha) / 255.0)
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
    if not halo:
        return lit, len(eyes)
    # faint golden halo around the whole peacock
    halo_src = Image.fromarray(alpha.astype(np.uint8)).filter(ImageFilter.GaussianBlur(size_hint * 0.02))
    halo_img = Image.new('RGBA', lit.size, (255, 200, 70, 0))
    halo_img.putalpha(halo_src.point(lambda v: int(v * 0.35)))
    return Image.alpha_composite(halo_img, lit), len(eyes)


APP = '../../app'
ANDROID_RES = f'{APP}/android/app/src/main/res'
IOS_ICONS = f'{APP}/ios/Runner/Assets.xcassets/AppIcon.appiconset'
DENSITIES = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}


def icon_sets(festival):
    import json
    import shutil
    global STOPS
    STOPS = RAMPS[festival]
    std, fest = f'{APP}/branding/app_icon/standard', f'{APP}/branding/app_icon/{festival}'
    shutil.rmtree(fest, ignore_errors=True)
    if not os.path.isdir(std):
        # everyday set, exactly as the app ships today
        for d in DENSITIES:
            shutil.copytree(f'{ANDROID_RES}/mipmap-{d}', f'{std}/android/mipmap-{d}')
        shutil.copytree(IOS_ICONS, f'{std}/ios/AppIcon.appiconset')
    # Deepavali set: light the eyes on the largest artwork, scale down for every size
    fg, n1 = light_up(Image.open(f'{std}/android/mipmap-xxxhdpi/ic_launcher_foreground.png'), 432, halo=False)
    legacy, n2 = light_up(Image.open(f'{std}/android/mipmap-xxxhdpi/ic_launcher.png'), 192, halo=False)
    for d, k in DENSITIES.items():
        out = f'{fest}/android/mipmap-{d}'
        os.makedirs(out, exist_ok=True)
        fg.resize((round(108 * k), round(108 * k)), Image.LANCZOS).save(f'{out}/ic_launcher_foreground.png', optimize=True)
        legacy.resize((round(48 * k), round(48 * k)), Image.LANCZOS).save(f'{out}/ic_launcher.png', optimize=True)
        shutil.copy(f'{std}/android/mipmap-{d}/ic_launcher_monochrome.png', f'{out}/ic_launcher_monochrome.png')  # themed icons stay plain
    master, n3 = light_up(Image.open(f'{std}/ios/AppIcon.appiconset/Icon-App-1024x1024@1x.png'), 1024, halo=False)
    master = master.convert('RGB')  # App Store icons must not have transparency
    out = f'{fest}/ios/AppIcon.appiconset'
    os.makedirs(out, exist_ok=True)
    shutil.copy(f'{std}/ios/AppIcon.appiconset/Contents.json', f'{out}/Contents.json')
    for img in json.load(open(f'{out}/Contents.json'))['images']:
        if 'filename' not in img:
            continue
        px_size = round(float(img['size'].split('x')[0]) * float(img['scale'].rstrip('x')))
        master.resize((px_size, px_size), Image.LANCZOS).save(f'{out}/{img["filename"]}', optimize=True)
    master.resize((512, 512), Image.LANCZOS).save(f'{fest}/play_store_512.png', optimize=True)
    print(festival, 'eyes lit — foreground', n1, 'legacy', n2, 'iOS', n3)


if __name__ == '__main__':
    for festival in RAMPS:
        icon_sets(festival)
