import "package:flutter/material.dart";

abstract final class AppTheme {
  static ThemeData theme(Brightness brightness) {
    final seed = const Color(0xFF6C63FF);
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
