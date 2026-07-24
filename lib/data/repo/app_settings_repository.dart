import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';

/// Simple key-value settings backed by a plain Hive box named 'settings'.
/// Open the box in main.dart before calling any getter/setter.
class AppSettings {
  static const _boxName = 'settings';
  static const _sidebarOnRightKey = 'sidebarOnRight';
  static const _keyboardShortcutsEnabledKey = 'keyboardShortcutsEnabled';
  static const _themeColorKey = 'themeColor';
  static const _fadeVolumeMsKey = 'fadeVolumeMs';
  // Default: Spotify green
  static const _defaultThemeColor = 0xFF1DB954;
  // Default: fade disabled (0 ms = feature off, only the regular pause shown).
  static const _defaultFadeVolumeMs = 0;
  // Hard upper bound — anything longer than 10 s is rarely useful.
  static const fadeVolumeMaxMs = 10000;

  static Box<dynamic> get _box => Hive.box<dynamic>(_boxName);

  /// Whether the sidebar is on the right side in landscape mode.
  /// Defaults to true.
  static bool get sidebarOnRight =>
      _box.get(_sidebarOnRightKey, defaultValue: true) as bool;

  static Future<void> setSidebarOnRight(bool value) =>
      _box.put(_sidebarOnRightKey, value);

  /// Whether keyboard shortcuts are enabled in the match center.
  /// Defaults to false.
  static bool get keyboardShortcutsEnabled =>
      _box.get(_keyboardShortcutsEnabledKey, defaultValue: false) as bool;

  static Future<void> setKeyboardShortcutsEnabled(bool value) =>
      _box.put(_keyboardShortcutsEnabledKey, value);

  /// Persisted primary theme color.
  static Color get themeColor => Color(
        _box.get(_themeColorKey, defaultValue: _defaultThemeColor) as int,
      );

  static Future<void> setThemeColor(Color color) =>
      _box.put(_themeColorKey, color.value);

  /// Duration in milliseconds for the volume fade-out when the user taps the
  /// "fade pause" button in the Let's Play screen. `0` disables the feature
  /// and hides the fade pause button.
  static int get fadeVolumeMs =>
      (_box.get(_fadeVolumeMsKey, defaultValue: _defaultFadeVolumeMs) as int)
          .clamp(0, fadeVolumeMaxMs);

  static Future<void> setFadeVolumeMs(int value) =>
      _box.put(_fadeVolumeMsKey, value.clamp(0, fadeVolumeMaxMs));

  // ---------------------------------------------------------------------
  // Spotify credentials (Bring Your Own Client ID)
  //
  // Since Feb 2026 Spotify Development Mode is limited to 5 authorized
  // users per Client ID. To let anyone use djSports with Spotify, each
  // user creates their own (free) app in the Spotify Developer Dashboard
  // and enters their own credentials here. Empty values mean "use the
  // .env fallback" (developer builds).
  // ---------------------------------------------------------------------
  static const _spotifyClientIdKey = 'spotifyClientId';
  static const _spotifyClientSecretKey = 'spotifyClientSecret';
  static const _spotifyRedirectUrlKey = 'spotifyRedirectUrl';

  /// Default redirect URI registered in the user's Spotify app.
  static const defaultSpotifyRedirectUrl = 'djsports://callback';

  /// User-supplied Spotify Client ID. Empty string = not set.
  static String get spotifyClientId =>
      (_box.get(_spotifyClientIdKey, defaultValue: '') as String).trim();

  static Future<void> setSpotifyClientId(String value) =>
      _box.put(_spotifyClientIdKey, value.trim());

  /// User-supplied Spotify Client Secret. Empty string = not set.
  /// Needed by the Web API search integration (client credentials flow).
  static String get spotifyClientSecret =>
      (_box.get(_spotifyClientSecretKey, defaultValue: '') as String).trim();

  static Future<void> setSpotifyClientSecret(String value) =>
      _box.put(_spotifyClientSecretKey, value.trim());

  /// User-supplied redirect URI. Empty string = not set.
  static String get spotifyRedirectUrl =>
      (_box.get(_spotifyRedirectUrlKey, defaultValue: '') as String).trim();

  static Future<void> setSpotifyRedirectUrl(String value) =>
      _box.put(_spotifyRedirectUrlKey, value.trim());
}
