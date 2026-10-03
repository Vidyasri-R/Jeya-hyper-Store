# Festival artwork

Original vector illustrations for the customer app's festival themes (no stock art, no licences
to track). Each script writes SVGs to `out/`; `render.mjs` turns them into WebP at 3× density.

```bash
cd design/festival-art
python3 header_art.py      # header + splash backgrounds, thoranam, diyas on rangoli, flame
python3 banners.py         # home banners (sweets & savouries, pooja, gift hampers)
python3 small_art.py       # button sparkle tile, section diya, petals
node render.mjs            # → out/webp/*.webp (needs backend/node_modules for sharp)
python3 festive_logo.py    # festival app icons: the everyday logo with the festival's thoranam → app/branding/app_icon/<id>/
cp out/webp/*.webp ../../app/assets/themes/diwali/

python3 pongal_art.py      # Pongal: header, thoranam (aavaram poo), pongal pot hero, splash, sun
python3 pongal_more.py     # Pongal banners, kolam button tile, section icon, petals
node render.mjs --dir out/pongal
cp out/pongal/webp/*.webp ../../app/assets/themes/pongal/   # plus flame.webp from diwali

python3 christmas_art.py   # Christmas & New Year: night sky, pine garland, tree hero, splash, star lantern
python3 christmas_more.py  # treats / New Year party / baking banners, snowflake tile, tree icon, sprites
node render.mjs --dir out/christmas
cp out/christmas/webp/*.webp ../../app/assets/themes/christmas/   # plus flame.webp from diwali

python3 valentine_art.py   # Valentine's Day: rose night, rose garland, chocolates & bouquet hero, splash heart
python3 valentine_more.py  # chocolates / flowers & gifts / sweets banners, heart tile, icon, petals
node render.mjs --dir out/valentine
cp out/valentine/webp/*.webp ../../app/assets/themes/valentine/   # plus flame.webp from diwali

python3 puthandu_art.py    # Tamil New Year: peacock-teal silk, mango-leaf thoranam with konrai, kuthuvilakku + kani tray hero, lotus
python3 puthandu_more.py   # mangoes / banana-leaf feast / pooja & kani banners, mango-butta tile, mango icon, flower petals
node render.mjs --dir out/puthandu
cp out/puthandu/webp/*.webp ../../app/assets/themes/puthandu/   # has its own flame.webp (glow kept inside the image)
```

How the app uses them: `app/lib/core/festival_pack.dart` (asset names, banner copy, flame
positions) and `app/lib/widgets/festive_decor.dart` (thoranam, flickering diyas, twinkles,
petal shower, banner card). Text on banners is live Flutter text, so copy can change
without redrawing.

Adding a festival (e.g. Christmas): draw its pack with the same file names into
`out/<id>/`, copy to `app/assets/themes/<id>/`, add a palette in `theme.dart`, a pack in
`festival_pack.dart`, and the id to the `app.theme` preset enum in
`backend/src/modules/admin/admin-settings.service.ts` and the staff app's theme card.

App icon: the in-app logo never changes; for a festival, switch the home-screen icon with
`app/tool/app_icon.sh diwali` before building the release, and `app/tool/app_icon.sh standard`
for the update after it.
