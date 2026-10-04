"""Wire a new festival pack into the apps and backend (what every pack since Tamil New Year needed).

Draw and render the art first (out/<id>/webp, the icon set via festive_logo.icon_sets(id)), then:

  python3 wire_pack.py <spec.json>          # example: packs/karthigai.json

spec: id, Name (for styles), palette_doc, palette{b900..accent, header[2]}, pack_dart (the FestivalPack
const body after `static const <id> = `), pack_doc, android_bg (#AARRGGBB), chip (label, emoji, [3 hex]),
icon_comment, readme (lines), test_dart (a test(...) block).
"""
import json
import re
import shutil
import subprocess
import sys

import os
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
spec = json.load(open(sys.argv[1]))
id_ = spec['id']
Name = spec['Name']


def edit(path, old, new, count=1):
    p = f'{ROOT}/{path}'
    src = open(p).read()
    assert src.count(old) == count, (path, old[:80], src.count(old))
    open(p, 'w').write(src.replace(old, new))


def presets_list(path, quote="'"):
    """Append id to the existing preset list literal in a file (backend enum + test)."""
    p = f'{ROOT}/{path}'
    src = open(p).read()
    m = re.search(r"\[('standard'(?:, '[a-z]+')+)\]", src)
    assert m, path
    items = m.group(1)
    assert f"'{id_}'" not in items
    src = src.replace(f'[{items}]', f"[{items}, '{id_}']")
    open(p, 'w').write(src)


# assets
dst = f'{ROOT}/app/assets/themes/{id_}'
shutil.rmtree(dst, ignore_errors=True)
shutil.copytree(f'{ROOT}/design/festival-art/out/{id_}/webp', dst)

pal = spec['palette']
c = lambda v: f'Color(0xFF{v.lstrip("#").upper()})'
palette = (f"  /// {spec['palette_doc']}\n  static const {id_} = BrandPalette(\n    id: '{id_}',\n"
           + ''.join(f'    {k}: {c(pal[k])},\n' for k in ('b900', 'b800', 'b700', 'b600', 'b500', 'b100', 'b50', 'tint'))
           + f"    header: [{c(pal['header'][0])}, {c(pal['header'][1])}],\n    accent: {c(pal['accent'])},\n  );\n\n  static BrandPalette byId")
edit('app/lib/core/theme.dart', '\n  static BrandPalette byId', '\n' + palette)
edit('app/lib/core/theme.dart', '    _ => standard,', f"    '{id_}' => {id_},\n    _ => standard,")

edit('app/lib/core/festival_pack.dart', '\n  static FestivalPack? byId', f"\n  /// {spec['pack_doc']}\n  static const {id_} = {spec['pack_dart']};\n\n  static FestivalPack? byId")
edit('app/lib/core/festival_pack.dart', '    _ => null,', f"    '{id_}' => {id_},\n    _ => null,")

src = open(f'{ROOT}/app/pubspec.yaml').read()
last = re.findall(r'    - assets/themes/[a-z]+/\n', src)[-1]
edit('app/pubspec.yaml', last, last + f'    - assets/themes/{id_}/\n')

edit('app/android/app/src/main/res/values-v31/styles.xml', '</resources>',
     f'    <style name="{Name}SplashTheme" parent="LaunchTheme">\n        <item name="android:windowSplashScreenBackground">{spec["android_bg"]}</item>\n'
     f'        <item name="android:windowSplashScreenIconBackgroundColor">@android:color/white</item>\n    </style>\n</resources>')
edit('app/android/app/src/main/kotlin/com/jeyahyperstore/app/MainActivity.kt', '                    else -> Resources.ID_NULL',
     f'                    "{id_}" -> R.style.{Name}SplashTheme\n                    else -> Resources.ID_NULL')

src = open(f'{ROOT}/app/tool/app_icon.sh').read()
m = re.search(r'(#   tool/app_icon\.sh [a-z]+ +# [^\n]*\n)(#   tool/app_icon\.sh standard)', src)
edit('app/tool/app_icon.sh', m.group(0), m.group(1) + f"#   tool/app_icon.sh {id_:<10}# … {spec['icon_comment']}\n" + m.group(2))
m = re.search(r'usage: tool/app_icon\.sh ([a-z|]+)"', src)
edit('app/tool/app_icon.sh', m.group(0), f'usage: tool/app_icon.sh {m.group(1)}|{id_}"')

src = open(f'{ROOT}/app/test/festive_layout_test.dart').read()
m = re.search(r'for \(final pack in \[([^\]]+)\]\)', src)
edit('app/test/festive_layout_test.dart', m.group(0), f'for (final pack in [{m.group(1)}, FestivalPacks.{id_}])')
edit('app/test/festival_test.dart', "    test('Pongal has its own look', () {", spec['test_dart'] + "\n\n    test('Pongal has its own look', () {")

presets_list('backend/src/modules/admin/admin-settings.service.ts')
presets_list('backend/src/modules/admin/admin-settings.test.ts')

label, emoji, sw = spec['chip']
src = open(f'{ROOT}/staff_app/lib/features/admin/settings_screen.dart').read()
chips = re.findall(r"    \('[a-z]+', '[^']+', '[^']+', \[Color\(0x[0-9A-F]+\), Color\(0x[0-9A-F]+\), Color\(0x[0-9A-F]+\)\]\),\n", src)
edit('staff_app/lib/features/admin/settings_screen.dart', chips[-1],
     chips[-1] + f"    ('{id_}', '{label}', '{emoji}', [{c(sw[0])}, {c(sw[1])}, {c(sw[2])}]),\n")

src = open(f'{ROOT}/design/festival-art/README.md').read()
anchor = '```\n\nHow the app uses them'
edit('design/festival-art/README.md', anchor, '\n' + '\n'.join(spec['readme']) + '\n' + anchor)
print('wired', id_)
