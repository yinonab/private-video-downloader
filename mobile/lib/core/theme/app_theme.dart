import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";

import "linkclip_palette.dart";

/// LinkClip light/dark themes — muted blue accent, restrained surfaces (Material 3 + [LinkClipPalette]).
abstract final class AppTheme {
  static const Color brandPrimary = Color(0xFF4E8FBF);
  static const Color brandPrimaryDark = Color(0xFF3D7399);
  static const Color brandPrimaryLight = Color(0xFFD6E8F5);
  static const Color successGreen = Color(0xFF49A078);
  static const Color errorRed = Color(0xFFC96B6B);

  static ThemeData theme(Brightness brightness) =>
      brightness == Brightness.dark ? darkTheme : lightTheme;

  static ThemeData get lightTheme => _build(
        brightness: Brightness.light,
        scheme: const ColorScheme(
          brightness: Brightness.light,
          primary: Color(0xFF4E8FBF),
          onPrimary: Color(0xFFFFFFFF),
          primaryContainer: Color(0xFFD6E8F5),
          onPrimaryContainer: Color(0xFF2C5F82),
          secondary: Color(0xFF49A078),
          onSecondary: Color(0xFFFFFFFF),
          secondaryContainer: Color(0xFFE6F4ED),
          onSecondaryContainer: Color(0xFF214D3C),
          tertiary: Color(0xFF6B7B8F),
          onTertiary: Color(0xFFFFFFFF),
          tertiaryContainer: Color(0xFFE8ECF2),
          onTertiaryContainer: Color(0xFF2E3847),
          error: Color(0xFFC96B6B),
          onError: Color(0xFFFFFFFF),
          errorContainer: Color(0xFFF7EAEA),
          onErrorContainer: Color(0xFF6B3838),
          surface: Color(0xFFF9FAFB),
          onSurface: Color(0xFF1A2330),
          surfaceContainerHighest: Color(0xFFEEF0F4),
          onSurfaceVariant: Color(0xFF5F6B78),
          outline: Color(0xFFD0D7E0),
          outlineVariant: Color(0xFFE2E6ED),
          shadow: Color(0xFF0D1420),
          scrim: Color(0xFF0D1420),
        ),
        scaffoldBg: const Color(0xFFF5F6F8),
        palette: LinkClipPalette.light,
      );

  static ThemeData get darkTheme => _build(
        brightness: Brightness.dark,
        scheme: const ColorScheme(
          brightness: Brightness.dark,
          primary: Color(0xFF4E8FBF),
          onPrimary: Color(0xFFF3F6FA),
          primaryContainer: Color(0xFF203548),
          onPrimaryContainer: Color(0xFFA9CCE6),
          secondary: Color(0xFF49A078),
          onSecondary: Color(0xFF0D1420),
          secondaryContainer: Color(0xFF163528),
          onSecondaryContainer: Color(0xFFA8DCC4),
          tertiary: Color(0xFF7B8798),
          onTertiary: Color(0xFFF3F6FA),
          tertiaryContainer: Color(0xFF2A3545),
          onTertiaryContainer: Color(0xFFA7B2C2),
          error: Color(0xFFC96B6B),
          onError: Color(0xFF1A1214),
          errorContainer: Color(0xFF3A2024),
          onErrorContainer: Color(0xFFE4BFBF),
          surface: Color(0xFF151D2B),
          onSurface: Color(0xFFF3F6FA),
          surfaceContainerHighest: Color(0xFF1B2433),
          onSurfaceVariant: Color(0xFFA7B2C2),
          outline: Color(0xFF273246),
          outlineVariant: Color(0xFF273246),
          shadow: Color(0xFF000000),
          scrim: Color(0xFF000000),
        ),
        scaffoldBg: const Color(0xFF0D1420),
        palette: LinkClipPalette.dark,
      );

  static ThemeData _build({
    required Brightness brightness,
    required ColorScheme scheme,
    required Color scaffoldBg,
    required LinkClipPalette palette,
  }) {
    final baseText = GoogleFonts.notoSansTextTheme(
      brightness == Brightness.light ? ThemeData.light().textTheme : ThemeData.dark().textTheme,
    );

    final textPrimary = scheme.onSurface;
    final textSecondary = scheme.onSurfaceVariant;

    final textTheme = baseText.copyWith(
      headlineSmall: baseText.headlineSmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: textPrimary,
        letterSpacing: -0.35,
      ),
      titleLarge: baseText.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: textPrimary,
        letterSpacing: -0.28,
      ),
      titleMedium: baseText.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: textPrimary),
      titleSmall: baseText.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: textPrimary),
      labelLarge: baseText.labelLarge?.copyWith(fontWeight: FontWeight.w500, color: textSecondary),
      labelMedium: baseText.labelMedium?.copyWith(fontWeight: FontWeight.w500),
      labelSmall: baseText.labelSmall?.copyWith(color: textSecondary, fontWeight: FontWeight.w500),
      bodyLarge: baseText.bodyLarge?.copyWith(color: textPrimary, height: 1.35),
      bodyMedium: baseText.bodyMedium?.copyWith(color: textSecondary, height: 1.4),
      bodySmall: baseText.bodySmall?.copyWith(color: textSecondary, height: 1.35),
    );

    final controlRadius = BorderRadius.circular(12);
    final filledShape = RoundedRectangleBorder(borderRadius: controlRadius);

    /// Full-width defaults for screens; dense cards override locally.
    final filledMinSize = Size(double.infinity, brightness == Brightness.light ? 48 : 46);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBg,
      extensions: <ThemeExtension<dynamic>>[palette],
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        scrolledUnderElevation: 0,
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerHighest.withValues(alpha: brightness == Brightness.dark ? 0.55 : 0.92),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outline.withValues(alpha: brightness == Brightness.dark ? 0.42 : 0.55)),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        labelStyle:
            GoogleFonts.notoSans(fontWeight: FontWeight.w500, fontSize: 11.5, height: 1.2),
        secondaryLabelStyle:
            GoogleFonts.notoSans(fontWeight: FontWeight.w500, fontSize: 11.5),
      ),
      dividerTheme: DividerThemeData(color: scheme.outline.withValues(alpha: 0.35)),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary.withValues(alpha: 0.9),
        foregroundColor: scheme.onPrimary,
        elevation: brightness == Brightness.dark ? 1 : 3,
        highlightElevation: brightness == Brightness.dark ? 2 : 6,
        extendedPadding: const EdgeInsets.symmetric(horizontal: 20),
        extendedTextStyle: GoogleFonts.notoSans(fontWeight: FontWeight.w600, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary.withValues(alpha: 0.88),
          foregroundColor: scheme.onPrimary,
          minimumSize: filledMinSize,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: filledShape,
          elevation: brightness == Brightness.dark ? 0 : 1,
          textStyle: GoogleFonts.notoSans(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: Size(double.infinity, 44),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          shape: filledShape,
          side: BorderSide(color: scheme.outline.withValues(alpha: 0.65)),
          textStyle: GoogleFonts.notoSans(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          side: WidgetStatePropertyAll(BorderSide(color: scheme.outline.withValues(alpha: 0.55))),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dialogTheme: DialogThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary.withValues(alpha: 0.85), width: 1.2),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
      ),
    );
  }
}
