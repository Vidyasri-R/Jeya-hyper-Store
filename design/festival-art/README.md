# Festival artwork

Original vector illustrations for the customer app's festival themes (no stock art, no licences
to track). Each script writes SVGs to `out/`; `render.mjs` turns them into WebP at 3× density.

```bash
cd design/festival-art
python3 header_art.py      # header + splash backgrounds, thoranam, diyas on rangoli, flame
python3 banners.py         # home banners (sweets & savouries, pooja, gift hampers)
python3 small_art.py       # button sparkle tile, section diya, petals
node render.mjs            # → out/webp/*.webp (needs backend/node_modules for sharp)
python3 festive_logo.py    # Deepavali app icon (feather eyes lit like diyas) → app/branding/app_icon/diwali/
cp out/webp/*.webp ../../app/assets/themes/diwali/
```

How the app uses them: `app/lib/core/festival_pack.dart` (asset names, banner copy, flame
positions) and `app/lib/widgets/festive_decor.dart` (thoranam, flickering diyas, twinkles,
petal shower, banner card). Text on banners is live Flutter text, so copy can change
without redrawing.

Adding a festival (e.g. Pongal, Christmas): draw its pack with the same file names into
`out/`, copy to `app/assets/themes/<id>/`, add a palette in `theme.dart`, a pack in
`festival_pack.dart`, and the id to the `app.theme` preset enum in
`backend/src/modules/admin/admin-settings.service.ts` and the staff app's theme card.

App icon: the in-app logo never changes; for a festival, switch the home-screen icon with
`app/tool/app_icon.sh diwali` before building the release, and `app/tool/app_icon.sh standard`
for the update after it.
