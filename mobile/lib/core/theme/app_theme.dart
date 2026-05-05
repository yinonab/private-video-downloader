import "package:flutter/material.dart";

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

      final baseText = ThemeData.light().textTheme.apply(
        bodyColor: textPrimaryLight,
        displayColor: textPrimaryLight,
      );

      return ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: scaffoldBgLight,
        textTheme: baseText.copyWith(
          titleLarge: baseText.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: textPrimaryLight),
          titleMedium: baseText.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: textPrimaryLight),
          titleSmall: baseText.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: textPrimaryLight),
          bodyMedium: baseText.bodyMedium?.copyWith(color: textSecondaryLight),
          bodySmall: baseText.bodySmall?.copyWith(color: textSecondaryLight),
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
          margin: EdgeInsets.zero,
          color: surfaceLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: borderLight.withValues(alpha: 0.9)),
          ),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: brandPrimary,
          foregroundColor: Colors.white,
          elevation: 3,
          extendedPadding: const EdgeInsets.symmetric(horizontal: 20),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: brandPrimary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
