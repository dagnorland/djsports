import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class BackupProfileNotifier extends Notifier<String> {
  static const _key = 'backupProfile';

  static Box<dynamic> get _box => Hive.box<dynamic>('settings');

  @override
  String build() => (_box.get(_key) as String?) ?? '';

  Future<void> setProfile(String name) async {
    await _box.put(_key, name);
    state = name;
    _logKey(name, _box.get(BackupPinNotifier._key) as String? ?? '');
  }
}

final backupProfileProvider = NotifierProvider<BackupProfileNotifier, String>(
  BackupProfileNotifier.new,
);

class BackupPinNotifier extends Notifier<String> {
  static const _key = 'backupPin';

  static Box<dynamic> get _box => Hive.box<dynamic>('settings');

  @override
  String build() => (_box.get(_key) as String?) ?? '';

  Future<void> setPin(String pin) async {
    await _box.put(_key, pin);
    state = pin;
    _logKey(_box.get(BackupProfileNotifier._key) as String? ?? '', pin);
  }
}

final backupPinProvider = NotifierProvider<BackupPinNotifier, String>(
  BackupPinNotifier.new,
);

/// The combined Firestore lookup key: "ProfileName|1234".
/// Returns '' if either profile name or PIN is not set.
final backupProfileKeyProvider = Provider<String>((ref) {
  final profile = ref.watch(backupProfileProvider);
  final pin = ref.watch(backupPinProvider);
  if (profile.isEmpty || pin.length != 4) return '';
  return '$profile|$pin';
});

void _logKey(String profile, String pin) {
  final key = (profile.isNotEmpty && pin.length == 4) ? '$profile|$pin' : '(incomplete)';
  debugPrint('[BackupProfile] lookup key: "$key"');
}
