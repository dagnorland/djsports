import 'dart:io';

import 'package:hive_ce/hive.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class DeviceNameNotifier extends Notifier<String> {
  static const _key = 'deviceName';

  static Box<dynamic> get _box => Hive.box<dynamic>('settings');

  @override
  String build() {
    final saved = _box.get(_key) as String?;
    if (saved != null && saved.isNotEmpty) return saved;
    try {
      return Platform.localHostname;
    } catch (_) {
      return 'My Device';
    }
  }

  Future<void> setDeviceName(String name) async {
    await _box.put(_key, name);
    state = name;
  }
}

final deviceNameProvider = NotifierProvider<DeviceNameNotifier, String>(
  DeviceNameNotifier.new,
);
