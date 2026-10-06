import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeya_hyper_store/core/theme.dart';
import 'package:jeya_hyper_store/state/providers.dart';

double contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('brand colour (Admin → Store settings → Brand colour)', () {
    test('Jeya green keeps the hand-tuned everyday palette', () {
      expect(identical(Palettes.fromColor(const Color(0xFF1B7A3E)), Palettes.standard), isTrue);
    });

    test('logo blue becomes the button colour as it is', () {
      final p = Palettes.fromColor(const Color(0xFF1E4FA8));
      expect(p.b700.toARGB32(), 0xFF1E4FA8);
      expect(contrast(p.b700, Colors.white), greaterThanOrEqualTo(4.5));
    });

    for (final hex in [0xFFFFD600, 0xFFF8BBD0, 0xFF00E5FF, 0xFFFFFFFF, 0xFF000000, 0xFFE53935, 0xFF7B1FA2]) {
      test('#${hex.toRadixString(16).substring(2).toUpperCase()} keeps white text readable on buttons and headers', () {
        final p = Palettes.fromColor(Color(hex));
        expect(contrast(p.b700, Colors.white), greaterThanOrEqualTo(4.5));
        expect(contrast(p.b900, Colors.white), greaterThanOrEqualTo(4.5));
        expect(contrast(p.b800, Colors.white), greaterThanOrEqualTo(4.5));
        // soft panels stay light enough for dark text
        expect(contrast(p.b50, const Color(0xFF16201A)), greaterThanOrEqualTo(7));
        expect(contrast(p.tint, const Color(0xFF16201A)), greaterThanOrEqualTo(7));
      });
    }

    test('parses only #RRGGBB', () {
      expect(Palettes.parseHex('#1e4fa8')?.toARGB32(), 0xFF1E4FA8);
      expect(Palettes.parseHex(' 1E4FA8 ')?.toARGB32(), 0xFF1E4FA8);
      for (final bad in ['blue', '#14f', '#GGGGGG', null, 42]) {
        expect(Palettes.parseHex(bad), isNull);
      }
    });

    test('the app follows app.brand, and falls back to green', () {
      ProviderContainer with_(Map<String, dynamic>? config) =>
          ProviderContainer(overrides: [savedConfigProvider.overrideWithValue(config), publicConfigProvider.overrideWith((_) async => throw 'offline')]);
      expect(identical(with_(null).read(brandPaletteProvider), Palettes.standard), isTrue);
      expect(identical(with_({'app.brand': {'color': 'nonsense'}}).read(brandPaletteProvider), Palettes.standard), isTrue);
      expect(with_({'app.brand': {'color': '#1E4FA8'}}).read(brandPaletteProvider).b700.toARGB32(), 0xFF1E4FA8);
    });
  });
}
