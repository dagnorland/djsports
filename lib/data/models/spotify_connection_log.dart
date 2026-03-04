// enum with notConnected, connectedSpotify, connectedSpotifyRemoteApp,
// tokenExpired
import 'package:flutter/material.dart';

enum SpotifyConnectionStatus {
  notConnected,
  connectedSpotify,
  connectedSpotifyRemoteApp,
  tokenExpired
}

class SpotifyConnectionLogEntry {
  final DateTime timestamp;
  final SpotifyConnectionStatus status;
  final String message;

  SpotifyConnectionLogEntry(this.timestamp, this.status, this.message);
}

class SpotifyConnectionLog {
  static final SpotifyConnectionLog _instance =
      SpotifyConnectionLog._internal();

  factory SpotifyConnectionLog() {
    return _instance;
  }

  SpotifyConnectionLog._internal();

  final List<SpotifyConnectionLogEntry> _log = <SpotifyConnectionLogEntry>[];
  static const int _maxEntries = 200;

  /// Incremented every time an entry is added or the log is cleared.
  /// Widgets can use [ValueListenableBuilder] on this to auto-rebuild.
  final ValueNotifier<int> changeCount = ValueNotifier(0);

  void addSimpleEntry(SpotifyConnectionStatus status, String message) {
    final entry = SpotifyConnectionLogEntry(DateTime.now(), status, message);
    addEntry(entry);
  }

  void addEntry(SpotifyConnectionLogEntry entry) {
    _log.add(entry);
    if (_log.length > _maxEntries) {
      _log.removeAt(0);
    }
    changeCount.value++;
  }

  void clear() {
    _log.clear();
    changeCount.value++;
  }

  void debugPrintLog() {
    debugPrint('SpotifyConnectionLog: START SHOW LOG ********************');
    for (final entry in _log) {
      debugPrint(
        'SpotifyConnectionLog: ${entry.timestamp} '
        '${entry.status} ${entry.message}',
      );
    }
    debugPrint('SpotifyConnectionLog: END SHOW LOG ********************');
  }

  List<SpotifyConnectionLogEntry> get log => _log;
}
