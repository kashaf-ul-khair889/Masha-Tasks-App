import 'package:flutter/material.dart';

/// Masha & the Bear palette: Masha's pink scarf, forest green, honey gold, cozy cream.
class AppTheme {
  static const pink = Color(0xFFC2397F);
  static const forest = Color(0xFF4C8C4A);
  static const honey = Color(0xFFF2A93B);

  static ThemeData light() {
    final cs = ColorScheme.fromSeed(
      seedColor: pink,
      brightness: Brightness.light,
      secondary: forest,
      tertiary: honey,
    );
    return _base(cs, const Color(0xFFFFF6E5));
  }

  static ThemeData dark() {
    final cs = ColorScheme.fromSeed(
      seedColor: const Color(0xFFF48FB1),
      brightness: Brightness.dark,
      secondary: const Color(0xFF8FCB8C),
      tertiary: honey,
    );
    return _base(cs, const Color(0xFF16231A));
  }

  static ThemeData _base(ColorScheme cs, Color bg) => ThemeData(
        useMaterial3: true,
        colorScheme: cs,
        scaffoldBackgroundColor: bg,
        appBarTheme: AppBarTheme(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          centerTitle: true,
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: cs.tertiary,
          foregroundColor: Colors.brown.shade900,
        ),
        inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
      );
}
