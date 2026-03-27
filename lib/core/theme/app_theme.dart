import 'package:flutter/material.dart';

class AppTheme {
  /// Builds the app theme from a dynamic primary color.
  static ThemeData themeFor(Color primary) {
    final light = Color.lerp(primary, Colors.white, 0.3)!;
    final dark = Color.lerp(primary, Colors.black, 0.15)!;
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
    );
    return ThemeData(
      colorScheme: scheme,
      primaryColor: primary,
      primaryColorLight: light,
      primaryColorDark: dark,
      scaffoldBackgroundColor: Colors.white,
      disabledColor: Colors.grey,
      textTheme: const TextTheme(
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: primary, width: 2),
        ),
      ),
    );
  }

  /// Convenience getter — Spotify green default.
  static ThemeData get lightTheme =>
      themeFor(const Color(0xFF1DB954));
}
