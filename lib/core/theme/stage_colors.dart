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
    // Many screens colour text, borders and buttons with primaryColor
    // (black in the light theme) – white here.
    primaryColor: text,
    hintColor: textMuted,
    scaffoldBackgroundColor: background,
    canvasColor: background,
    appBarTheme: const AppBarTheme(
      backgroundColor: background,
      foregroundColor: text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: text,
      unselectedLabelColor: textMuted,
      indicatorColor: text,
      dividerColor: divider,
    ),
    listTileTheme: const ListTileThemeData(iconColor: text, textColor: text),
    dialogTheme: const DialogThemeData(backgroundColor: surface),
    popupMenuTheme: const PopupMenuThemeData(color: surfaceHigh),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
    ),
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
    // Light outlines and text for input fields (the light theme's black
    // borders vanish on the dark stage).
    inputDecorationTheme: InputDecorationTheme(
      labelStyle: const TextStyle(color: textMuted),
      hintStyle: const TextStyle(color: Colors.white38),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.white38),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.white38),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: text, width: 2),
      ),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: text,
      selectionColor: Colors.white30,
      selectionHandleColor: text,
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: surfaceHigh,
      labelStyle: const TextStyle(color: text),
      side: BorderSide.none,
    ),
  );
}

/// Puts [child] on the stage theme. Wrap a pushed route with it (not just
/// the screen's body) so the screen's dialogs and sheets are dark too.
class StageTheme extends StatelessWidget {
  const StageTheme({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Theme(data: StageColors.theme(Theme.of(context)), child: child);
}

/// A playlist type colour that shows on the current background: Pre-match
/// is black, which disappears on the dark stage – use grey there.
Color stageTypeColor(Color typeColor, BuildContext context) =>
    typeColor == Colors.black && Theme.of(context).brightness == Brightness.dark
    ? Colors.grey.shade400
    : typeColor;
