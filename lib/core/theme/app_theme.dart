import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: const Color(0xFF1DB954), // Spotify grønn
      primaryColorLight: const Color(0xFF1ED760), // Lysere Spotify grønn
      primaryColorDark: const Color(0xFF1AA34A), // Mørkere Spotify grønn

      // Andre farger og tema-innstillinger
      scaffoldBackgroundColor: Colors.white,
      disabledColor: Colors.grey,

      // Text themes
      textTheme: const TextTheme(
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        // Andre tekststiler...
      ),

      // Input decoration
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF1DB954), width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF1DB954), width: 2),
        ),
      ),
    );
  }
}
