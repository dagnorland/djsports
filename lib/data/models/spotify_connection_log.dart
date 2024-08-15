// enum with notConnected, connectedSpotify, connectedSpotifyRemoteApp, , tokenExpired
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
  final int _maxEntries = 50;

  void addSimpleEntry(SpotifyConnectionStatus status, String message) {
    final entry = SpotifyConnectionLogEntry(DateTime.now(), status, message);
    addEntry(entry);
  }

  void addEntry(SpotifyConnectionLogEntry entry) {
    _log.add(entry);
    if (_log.length > _maxEntries) {
      _log.removeAt(0);
    }
  }

  void clear() {
    _log.clear();
  }

  void debugPrintLog() {
    for (final entry in _log) {
      debugPrint(
          'SpotifyConnectionLog: ${entry.timestamp} ${entry.status} ${entry.message}');
    }
  }

  List<SpotifyConnectionLogEntry> get log => _log;
}
