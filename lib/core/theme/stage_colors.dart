import 'package:flutter/material.dart';

/// Dark "stage" palette for Let's Play and the now-playing panel – like
/// Spotify/Tidal and DJ software: easy on the eyes in a dim arena and
/// high-contrast in bright light. The only colours on top are the
/// playlist type colours.
abstract final class StageColors {
  static const background = Color(0xFF121212);

  /// Playlist tiles.
  static const surface = Color(0xFF1E1E1E);

  /// Now-playing panel.
  static const panel = Color(0xFF181818);

  /// Cover placeholders, inactive tracks.
  static const surfaceHigh = Color(0xFF2A2A2A);

  /// Lines between the board, the controls and the panel.
  static const divider = Color(0xFF2E2E2E);

  static const text = Colors.white;
  static const textMuted = Color(0xFFB3B3B3);

  /// Theme for screens and widgets on the stage palette.
  static ThemeData theme(ThemeData base) => base.copyWith(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: background,
    canvasColor: background,
    colorScheme: const ColorScheme.dark(
      primary: text,
      secondary: text,
      surface: surface,
      onSurface: text,
      onSurfaceVariant: textMuted,
      outline: textMuted,
      surfaceContainerHighest: surfaceHigh,
    ),
    cardTheme: const CardThemeData(color: surface),
    iconTheme: const IconThemeData(color: text),
    textTheme: base.textTheme.apply(bodyColor: text, displayColor: text),
    dividerColor: divider,
    sliderTheme: base.sliderTheme.copyWith(
      activeTrackColor: text,
      inactiveTrackColor: Colors.white24,
      thumbColor: text,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: text,
      linearTrackColor: Colors.white24,
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: surfaceHigh,
      labelStyle: const TextStyle(color: text),
      side: BorderSide.none,
    ),
  );
}
