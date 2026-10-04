import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'festival_pack.dart';

/// One festival-able colour family. `AppColors.brand*` read the active palette, so a festival
/// theme (Admin → Store settings → App theme) recolours every button, chip and header at once.
class BrandPalette {
  const BrandPalette({
    required this.id,
    required this.b900,
    required this.b800,
    required this.b700,
    required this.b600,
    required this.b500,
    required this.b100,
    required this.b50,
    required this.tint,
    required this.header,
    required this.accent,
  });

  final String id;
  final Color b900, b800, b700, b600, b500, b100, b50, tint;

  /// Home header gradient (top-left → bottom-right).
  final List<Color> header;

  /// Festive highlight (decorations, greeting strip).
  final Color accent;
}

abstract final class Palettes {
  /// The approved everyday look: Jeya greens.
  static const standard = BrandPalette(
    id: 'standard',
    b900: Color(0xFF0F4D2A),
    b800: Color(0xFF14612F),
    b700: Color(0xFF1B7A3E),
    b600: Color(0xFF23934B),
    b500: Color(0xFF2EA65A),
    b100: Color(0xFFDDF1E2),
    b50: Color(0xFFEFF8F1),
    tint: Color(0xFFF4FAF5),
    header: [Color(0xFF14612F), Color(0xFF23934B)],
    accent: Color(0xFFF6A609),
  );

  /// Diwali: deep maroon and festive orange with diya gold (white text stays readable on all of them).
  static const diwali = BrandPalette(
    id: 'diwali',
    b900: Color(0xFF4A0D1A),
    b800: Color(0xFF6E1428),
    b700: Color(0xFFA3261B),
    b600: Color(0xFFC2410C),
    b500: Color(0xFFE2600F),
    b100: Color(0xFFFCE3C4),
    b50: Color(0xFFFFF3E2),
    tint: Color(0xFFFFF8EE),
    header: [Color(0xFF5E0F22), Color(0xFFB0321E)],
    accent: Color(0xFFFFC53D),
  );

  /// Pongal: clay terracotta and the turmeric gold of the Surya Pongal sunrise.
  static const pongal = BrandPalette(
    id: 'pongal',
    b900: Color(0xFF4A2408),
    b800: Color(0xFF6B3510),
    b700: Color(0xFF9A4A16),
    b600: Color(0xFFBF6119),
    b500: Color(0xFFE07E22),
    b100: Color(0xFFFCE9C8),
    b50: Color(0xFFFFF5E3),
    tint: Color(0xFFFFFAF0),
    header: [Color(0xFF6B3510), Color(0xFFBF6119)],
    accent: Color(0xFFFFD54F),
  );

  /// Christmas & New Year: Christmas red and gold under a starry navy night.
  static const christmas = BrandPalette(
    id: 'christmas',
    b900: Color(0xFF5C1010),
    b800: Color(0xFF8E1C1C),
    b700: Color(0xFFC62828),
    b600: Color(0xFFD84343),
    b500: Color(0xFFE53935),
    b100: Color(0xFFFDE2E2),
    b50: Color(0xFFFFF2F2),
    tint: Color(0xFFFFFAFA),
    header: [Color(0xFF0E1F45), Color(0xFF1D3A7A)],
    accent: Color(0xFFFFD54F),
  );

  /// Valentine's Day: deep rose and pink.
  static const valentine = BrandPalette(
    id: 'valentine',
    b900: Color(0xFF5A0F2E),
    b800: Color(0xFF8A1446),
    b700: Color(0xFFC2185B),
    b600: Color(0xFFD81B60),
    b500: Color(0xFFEC407A),
    b100: Color(0xFFFCE4EC),
    b50: Color(0xFFFFF0F5),
    tint: Color(0xFFFFF8FB),
    header: [Color(0xFF6A0F35), Color(0xFFC2185B)],
    accent: Color(0xFFFFD1DC),
  );

  /// Tamil New Year (Puthandu): peacock-teal Kanchipuram silk with temple gold.
  static const puthandu = BrandPalette(
    id: 'puthandu',
    b900: Color(0xFF06363E),
    b800: Color(0xFF0A4D58),
    b700: Color(0xFF0E6B78),
    b600: Color(0xFF138494),
    b500: Color(0xFF1A9DAF),
    b100: Color(0xFFD3EEF1),
    b50: Color(0xFFEBF7F8),
    tint: Color(0xFFF5FBFB),
    header: [Color(0xFF07404A), Color(0xFF0F7482)],
    accent: Color(0xFFFFD54F),
  );

  /// Eid (Ramzan & Bakrid): a violet night with lantern gold.
  static const eid = BrandPalette(
    id: 'eid',
    b900: Color(0xFF2A1048),
    b800: Color(0xFF3D1A66),
    b700: Color(0xFF5B2A93),
    b600: Color(0xFF7038AE),
    b500: Color(0xFF8A4FC8),
    b100: Color(0xFFEBDDF7),
    b50: Color(0xFFF6EEFB),
    tint: Color(0xFFFBF7FE),
    header: [Color(0xFF26103F), Color(0xFF52288A)],
    accent: Color(0xFFFFD54F),
  );

  /// Independence & Republic Day: navy with saffron (tricolour art; no flag or chakra in commercial use).
  static const national = BrandPalette(
    id: 'national',
    b900: Color(0xFF0C1D4A),
    b800: Color(0xFF152B66),
    b700: Color(0xFF1F3C88),
    b600: Color(0xFF2B4FA8),
    b500: Color(0xFF3D63C2),
    b100: Color(0xFFDCE5F7),
    b50: Color(0xFFEEF2FB),
    tint: Color(0xFFF7F9FD),
    header: [Color(0xFF0B1E4F), Color(0xFF1E3F8F)],
    accent: Color(0xFFFF9933),
  );

  static BrandPalette byId(String? id) => switch (id) {
    'diwali' => diwali,
    'pongal' => pongal,
    'christmas' => christmas,
    'valentine' => valentine,
    'puthandu' => puthandu,
    'eid' => eid,
    'national' => national,
    _ => standard,
  };
}

/// App colours. `brand*` follow the active festival palette; everything else is fixed.
abstract final class AppColors {
  static BrandPalette palette = Palettes.standard;

  static Color get brand900 => palette.b900;
  static Color get brand800 => palette.b800;
  static Color get brand700 => palette.b700; // primary buttons
  static Color get brand600 => palette.b600;
  static Color get brand500 => palette.b500;
  static Color get brand100 => palette.b100;
  static Color get brand50 => palette.b50; // soft panels / chips
  static Color get brandTint => palette.tint; // page background tint
  static Color get festiveAccent => palette.accent;

  static const brandBlue = Color(0xFF1E4FA8); // logo wordmark
  static const brandBlueSoft = Color(0xFFE8EEFA);

  static const ink = Color(0xFF16201A); // primary text
  static const inkMuted = Color(0xFF5E6B63);
  static const inkFaint = Color(0xFF94A099);
  static const line = Color(0xFFE6ECE8);
  static const surface = Colors.white;
  static const bg = Color(0xFFF7FAF8);

  static const offerRed = Color(0xFFE53935);
  static const offerRedSoft = Color(0xFFFDE8E8);
  static const amber = Color(0xFFF6A609);
  static const amberSoft = Color(0xFFFFF4DC);

  static LinearGradient get headerGradient =>
      LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: palette.header);
}

/// Brand fills that dress up for festivals (gradient + gold sparkle texture + gold edge).
abstract final class AppDecor {
  static BoxDecoration brandFill({double radius = 0, bool pressed = false, bool edge = true}) {
    final pack = Festive.pack;
    final r = radius > 0 ? BorderRadius.circular(radius) : null;
    if (pack == null) return BoxDecoration(color: pressed ? AppColors.brand800 : AppColors.brand700, borderRadius: r);
    return BoxDecoration(
      borderRadius: r,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: pressed ? [AppColors.brand900, AppColors.brand800] : [AppColors.brand800, AppColors.brand700, AppColors.brand600],
      ),
      image: DecorationImage(image: pack.buttonTexture, repeat: ImageRepeat.repeat, alignment: Alignment.topLeft),
      border: edge ? Border.all(color: AppColors.festiveAccent.withValues(alpha: 0.55), width: 0.8) : null,
    );
  }

  /// Light catching the top edge of a festive button.
  static const gloss = BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0x38FFFFFF), Color(0x00FFFFFF)],
      stops: [0, 0.5],
    ),
  );
}

abstract final class AppRadius {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 22.0;
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.brand700,
      primary: AppColors.brand700,
      secondary: AppColors.brandBlue,
      surface: AppColors.surface,
      error: AppColors.offerRed,
    ),
    scaffoldBackgroundColor: AppColors.bg,
  );

  final text = GoogleFonts.outfitTextTheme(base.textTheme).apply(
    bodyColor: AppColors.ink,
    displayColor: AppColors.ink,
  );

  return base.copyWith(
    textTheme: text.copyWith(
      headlineMedium: text.headlineMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.4),
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.2),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      titleSmall: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      bodySmall: text.bodySmall?.copyWith(color: AppColors.inkMuted),
      labelSmall: text.labelSmall?.copyWith(color: AppColors.inkMuted, letterSpacing: 0.1),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      foregroundColor: AppColors.ink,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: AppColors.ink),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.brand700,
        foregroundColor: Colors.white,
        minimumSize: const Size(64, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        textStyle: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        // Festivals: sparkle-textured gradient with a soft top gloss. Buttons pass
        // clipBehavior: Clip.antiAlias so their own rounded shape clips it.
        backgroundBuilder: Festive.pack == null
            ? null
            : (context, states, child) => states.contains(WidgetState.disabled)
                ? child ?? const SizedBox.shrink()
                : DecoratedBox(
                    decoration: AppDecor.brandFill(pressed: states.contains(WidgetState.pressed), edge: false),
                    child: DecoratedBox(decoration: AppDecor.gloss, child: child),
                  ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.brand700,
        side: BorderSide(color: AppColors.brand700),
        minimumSize: const Size(64, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        textStyle: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.brand700, textStyle: text.titleSmall),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      hintStyle: text.bodyMedium?.copyWith(color: AppColors.inkFaint),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.brand700, width: 1.6)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.offerRed)),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: AppColors.surface,
      selectedColor: AppColors.brand700,
      side: const BorderSide(color: AppColors.line),
      shape: const StadiumBorder(),
      labelStyle: text.labelLarge?.copyWith(color: AppColors.ink),
      secondaryLabelStyle: text.labelLarge?.copyWith(color: Colors.white),
      showCheckmark: false,
    ),
    dividerTheme: const DividerThemeData(color: AppColors.line, thickness: 1, space: 1),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      contentTextStyle: text.bodyMedium?.copyWith(color: Colors.white),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
    ),
  );
}
