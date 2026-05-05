import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";

/// LinkClip light palette + Material 3. Dark mode stays seed-based for system theme parity.
abstract final class AppTheme {
  static const Color brandPrimary = Color(0xFF6C63FF);
  static const Color brandPrimaryDark = Color(0xFF574FD6);
  static const Color brandPrimaryLight = Color(0xFFE9E7FF);
  static const Color scaffoldBgLight = Color(0xFFF7F7FB);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color successGreen = Color(0xFF22C55E);
  static const Color errorRed = Color(0xFFDC2626);
  static const Color textPrimaryLight = Color(0xFF171717);
  static const Color textSecondaryLight = Color(0xFF6B7280);
  static const Color borderLight = Color(0xFFE5E7EB);

  static ThemeData theme(Brightness brightness) {
    if (brightness == Brightness.light) {
      final scheme = ColorScheme.light(
        primary: brandPrimary,
        onPrimary: Colors.white,
        primaryContainer: brandPrimaryLight,
        onPrimaryContainer: brandPrimaryDark,
        surface: surfaceLight,
        onSurface: textPrimaryLight,
        onSurfaceVariant: textSecondaryLight,
        error: errorRed,
        onError: Colors.white,
        outline: borderLight,
        outlineVariant: borderLight,
        surfaceContainerHighest: const Color(0xFFF3F4F6),
      );

      final baseText = GoogleFonts.notoSansTextTheme(ThemeData.light().textTheme).apply(
        bodyColor: textPrimaryLight,
        displayColor: textPrimaryLight,
      );

      final btnShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(17));

      return ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: scaffoldBgLight,
        textTheme: baseText.copyWith(
          headlineSmall: baseText.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: textPrimaryLight),
          titleLarge: baseText.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: textPrimaryLight),
          titleMedium: baseText.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: textPrimaryLight),
          titleSmall: baseText.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: textPrimaryLight),
          labelLarge: baseText.labelLarge?.copyWith(fontWeight: FontWeight.w600, color: textSecondaryLight),
          labelMedium: baseText.labelMedium?.copyWith(fontWeight: FontWeight.w500),
          labelSmall: baseText.labelSmall?.copyWith(color: textSecondaryLight),
          bodyLarge: baseText.bodyLarge?.copyWith(color: textPrimaryLight, height: 1.35),
          bodyMedium: baseText.bodyMedium?.copyWith(color: textSecondaryLight, height: 1.4),
          bodySmall: baseText.bodySmall?.copyWith(color: textSecondaryLight, height: 1.35),
        ),
        appBarTheme: AppBarTheme(
          scrolledUnderElevation: 0,
          centerTitle: true,
          elevation: 0,
          backgroundColor: scaffoldBgLight,
          foregroundColor: textPrimaryLight,
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shadowColor: Colors.black.withValues(alpha: 0.06),
          surfaceTintColor: Colors.transparent,
          margin: EdgeInsets.zero,
          color: surfaceLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(21),
            side: BorderSide(color: borderLight.withValues(alpha: 0.9)),
          ),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: brandPrimary,
          foregroundColor: Colors.white,
          elevation: 4,
          extendedPadding: const EdgeInsets.symmetric(horizontal: 22),
          extendedTextStyle: GoogleFonts.notoSans(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: brandPrimary,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 54),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
            shape: btnShape,
            textStyle: GoogleFonts.notoSans(fontWeight: FontWeight.w700, fontSize: 16),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: brandPrimaryDark,
            minimumSize: const Size(double.infinity, 54),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
            shape: btnShape,
            side: BorderSide(color: borderLight.withValues(alpha: 0.95)),
            textStyle: GoogleFonts.notoSans(fontWeight: FontWeight.w700, fontSize: 16),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surfaceLight,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    }

    final seed = brandPrimary;
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: brightness == Brightness.dark ? scheme.surfaceContainerLow : scheme.surface,
      appBarTheme: AppBarTheme(
        scrolledUnderElevation: 0,
        centerTitle: true,
        foregroundColor: scheme.onSurface,
      ),
      cardTheme: CardThemeData(
        elevation: brightness == Brightness.dark ? 0 : 2,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
