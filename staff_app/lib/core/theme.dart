import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Brand palette — greens from the approved UI, blue from the Jeya peacock logo.
abstract final class AppColors {
  static const green900 = Color(0xFF0F4D2A);
  static const green800 = Color(0xFF14612F);
  static const green700 = Color(0xFF1B7A3E); // primary buttons
  static const green600 = Color(0xFF23934B);
  static const green500 = Color(0xFF2EA65A);
  static const green100 = Color(0xFFDDF1E2);
  static const green50 = Color(0xFFEFF8F1); // soft panels / chips
  static const mint = Color(0xFFF4FAF5); // page background tint

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

  static const headerGradient = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [green800, green600]);
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
      seedColor: AppColors.green700,
      primary: AppColors.green700,
      secondary: AppColors.brandBlue,
      surface: AppColors.surface,
      error: AppColors.offerRed,
    ),
    scaffoldBackgroundColor: AppColors.bg,
  );

  final text = GoogleFonts.outfitTextTheme(base.textTheme).apply(bodyColor: AppColors.ink, displayColor: AppColors.ink);

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
        backgroundColor: AppColors.green700,
        foregroundColor: Colors.white,
        minimumSize: const Size(64, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        textStyle: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.green700,
        side: const BorderSide(color: AppColors.green700),
        minimumSize: const Size(64, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        textStyle: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.green700, textStyle: text.titleSmall),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      hintStyle: text.bodyMedium?.copyWith(color: AppColors.inkFaint),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.green700, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.offerRed),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: AppColors.surface,
      selectedColor: AppColors.green700,
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

/// Order status → label + colours, shared by chips, timeline and tabs.
abstract final class StatusStyle {
  static const _labels = {
    'pending_payment': 'Awaiting payment',
    'placed': 'New',
    'confirmed': 'Accepted',
    'packing': 'Packing',
    'ready_for_delivery': 'Packed',
    'out_for_delivery': 'Out for delivery',
    'delivered': 'Delivered',
    'cancelled': 'Cancelled',
    'payment_failed': 'Payment failed',
  };

  static String label(String status) => _labels[status] ?? status;

  static (Color fg, Color bg) colors(String status) => switch (status) {
    'placed' => (AppColors.brandBlue, AppColors.brandBlueSoft),
    'confirmed' || 'packing' => (const Color(0xFF8A5A00), AppColors.amberSoft),
    'ready_for_delivery' => (AppColors.green800, AppColors.green100),
    'out_for_delivery' => (const Color(0xFF5B3CC4), const Color(0xFFEEE9FC)),
    'delivered' => (AppColors.green700, AppColors.green50),
    'cancelled' || 'payment_failed' => (AppColors.offerRed, AppColors.offerRedSoft),
    _ => (AppColors.inkMuted, AppColors.line),
  };
}

/// Usage alert levels.
(Color fg, Color bg) levelColors(String? level) => switch (level) {
  'critical' => (AppColors.offerRed, AppColors.offerRedSoft),
  'warning' => (const Color(0xFF8A5A00), AppColors.amberSoft),
  'info' => (AppColors.brandBlue, AppColors.brandBlueSoft),
  _ => (AppColors.green700, AppColors.green50),
};
