import 'package:djsports/data/repo/app_settings_repository.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// The 5 curated theme colors available in the color picker.
const List<({Color color, String name})> kThemeColors = [
  (color: Colors.black, name: 'Black'),
  (color: Color(0xFF0A84FF), name: 'Electric Blue'),
  (color: Color(0xFF1DB954), name: 'Spotify Green'),
  (color: Color(0xFFE6B800), name: 'Sun Yellow'),
  (color: Color(0xFFFF9F0A), name: 'Amber'),
  (color: Color(0xFF945AD1), name: 'Purple'),
  (color: Colors.red, name: 'Red'),
];

/// [color] for filled controls with white icons, or as an accent on a
/// light background: light display colours (Sun Yellow, Amber) are
/// darkened so they still stand out.
Color strongDisplayColor(Color color) => color.computeLuminance() > 0.4
    ? Color.lerp(color, Colors.black, 0.35)!
    : color;

class ThemeColorNotifier extends Notifier<Color> {
  @override
  Color build() => AppSettings.themeColor;

  Future<void> setColor(Color color) async {
    await AppSettings.setThemeColor(color);
    state = color;
  }
}

final themeColorProvider = NotifierProvider<ThemeColorNotifier, Color>(
  ThemeColorNotifier.new,
);
