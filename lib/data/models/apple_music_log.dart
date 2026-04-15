import 'package:flutter/material.dart';

enum AppleMusicLogLevel { info, error }

class AppleMusicLogEntry {
  AppleMusicLogEntry(this.timestamp, this.level, this.message);
  final DateTime timestamp;
  final AppleMusicLogLevel level;
  final String message;
}

class AppleMusicLog {
  static final AppleMusicLog _instance = AppleMusicLog._internal();
  factory AppleMusicLog() => _instance;
  AppleMusicLog._internal();

  final List<AppleMusicLogEntry> _log = [];
  static const int _maxEntries = 200;
  final ValueNotifier<int> changeCount = ValueNotifier(0);

  void info(String message) => _add(AppleMusicLogLevel.info, message);
  void error(String message) => _add(AppleMusicLogLevel.error, message);

  void _add(AppleMusicLogLevel level, String message) {
    _log.add(AppleMusicLogEntry(DateTime.now(), level, message));
    if (_log.length > _maxEntries) _log.removeAt(0);
    changeCount.value++;
  }

  void clear() {
    _log.clear();
    changeCount.value++;
  }

  List<AppleMusicLogEntry> get log => _log;
}
