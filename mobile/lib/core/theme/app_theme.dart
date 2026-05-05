import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";

import "linkclip_palette.dart";

/// LinkClip premium light/dark themes (Material 3 + [LinkClipPalette] extension).
abstract final class AppTheme {
  static const Color brandPrimary = Color(0xFF6C63FF);
  static const Color brandPrimaryDark = Color(0xFF4F46E5);
  static const Color brandPrimaryLight = Color(0xFFECEBFF);
  /// Semantic success (mirrors palette; kept for rare static references).
  static const Color successGreen = Color(0xFF22C55E);
  static const Color errorRed = Color(0xFFDC2626);

  static ThemeData theme(Brightness brightness) =>
      brightness == Brightness.dark ? darkTheme : lightTheme;

  static ThemeData get lightTheme => _build(
        brightness: Brightness.light,
        scheme: const ColorScheme(
          brightness: Brightness.light,
          primary: Color(0xFF6C63FF),
          onPrimary: Color(0xFFFFFFFF),
          primaryContainer: Color(0xFFECEBFF),
          onPrimaryContainer: Color(0xFF4F46E5),
          secondary: Color(0xFF2DD4BF),
          onSecondary: Color(0xFF042F2E),
          secondaryContainer: Color(0xFFCCFBF1),
          onSecondaryContainer: Color(0xFF134E4A),
          tertiary: Color(0xFF6B7280),
          onTertiary: Color(0xFFFFFFFF),
          tertiaryContainer: Color(0xFFF3F4F6),
          onTertiaryContainer: Color(0xFF374151),
          error: Color(0xFFDC2626),
          onError: Color(0xFFFFFFFF),
          surface: Color(0xFFFFFFFF),
          onSurface: Color(0xFF111827),
          surfaceContainerHighest: Color(0xFFF3F4F6),
          onSurfaceVariant: Color(0xFF6B7280),
          outline: Color(0xFFE5E7EB),
          outlineVariant: Color(0xFFE5E7EB),
          shadow: Color(0xFF111827),
          scrim: Color(0xFF111827),
        ),
        scaffoldBg: const Color(0xFFF7F7FB),
        palette: LinkClipPalette.light,
      );

  static ThemeData get darkTheme => _build(
        brightness: Brightness.dark,
        scheme: const ColorScheme(
          brightness: Brightness.dark,
          primary: Color(0xFF8B84FF),
          onPrimary: Color(0xFFFFFFFF),
          primaryContainer: Color(0xFF2A275A),
          onPrimaryContainer: Color(0xFFE8E6FF),
          secondary: Color(0xFF2DD4BF),
          onSecondary: Color(0xFF042F2E),
          secondaryContainer: Color(0xFF134E4A),
          onSecondaryContainer: Color(0xFFCCFBF1),
          tertiary: Color(0xFFA1A1AA),
          onTertiary: Color(0xFF18181B),
          tertiaryContainer: Color(0xFF1F2136),
          onTertiaryContainer: Color(0xFFE4E4E7),
          error: Color(0xFFF87171),
          onError: Color(0xFF450A0A),
          surface: Color(0xFF17182A),
          onSurface: Color(0xFFF8FAFC),
          surfaceContainerHighest: Color(0xFF1F2136),
          onSurfaceVariant: Color(0xFFA1A1AA),
          outline: Color(0xFF2E3148),
          outlineVariant: Color(0xFF2E3148),
          shadow: Color(0xFF000000),
          scrim: Color(0xFF000000),
        ),
        scaffoldBg: const Color(0xFF0F1020),
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
      headlineSmall: baseText.headlineSmall?.copyWith(fontWeight: FontWeight.w700, color: textPrimary, letterSpacing: -0.5),
      titleLarge: baseText.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: textPrimary, letterSpacing: -0.35),
      titleMedium: baseText.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: textPrimary),
      titleSmall: baseText.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: textPrimary),
      labelLarge: baseText.labelLarge?.copyWith(fontWeight: FontWeight.w600, color: textSecondary),
      labelMedium: baseText.labelMedium?.copyWith(fontWeight: FontWeight.w600),
      labelSmall: baseText.labelSmall?.copyWith(color: textSecondary, fontWeight: FontWeight.w500),
      bodyLarge: baseText.bodyLarge?.copyWith(color: textPrimary, height: 1.35),
      bodyMedium: baseText.bodyMedium?.copyWith(color: textSecondary, height: 1.4),
      bodySmall: baseText.bodySmall?.copyWith(color: textSecondary, height: 1.35),
    );

    final pillRadius = BorderRadius.circular(22);
    final filledShape = RoundedRectangleBorder(borderRadius: pillRadius);
    final compactBtnMin = Size(double.infinity, brightness == Brightness.light ? 52 : 50);

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
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
          side: BorderSide(color: scheme.outline.withValues(alpha: brightness == Brightness.dark ? 0.55 : 0.45)),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        labelStyle: GoogleFonts.notoSans(fontWeight: FontWeight.w600, fontSize: 12.5, height: 1.2),
        secondaryLabelStyle: GoogleFonts.notoSans(fontWeight: FontWeight.w600, fontSize: 12.5),
      ),
      dividerTheme: DividerThemeData(color: scheme.outline.withValues(alpha: 0.35)),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: brightness == Brightness.dark ? 2 : 6,
        highlightElevation: brightness == Brightness.dark ? 4 : 10,
        extendedPadding: const EdgeInsets.symmetric(horizontal: 22),
        extendedTextStyle: GoogleFonts.notoSans(fontWeight: FontWeight.w700, fontSize: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: compactBtnMin,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: filledShape,
          elevation: brightness == Brightness.dark ? 0 : 1,
          textStyle: GoogleFonts.notoSans(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: Size(double.infinity, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: filledShape,
          side: BorderSide(color: scheme.outline.withValues(alpha: 0.75)),
          textStyle: GoogleFonts.notoSans(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          side: WidgetStatePropertyAll(BorderSide(color: scheme.outline.withValues(alpha: 0.6))),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
      ),
    );
  }
}
