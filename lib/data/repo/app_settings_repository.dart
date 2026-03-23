import 'package:hive_ce/hive.dart';

/// Simple key-value settings backed by a plain Hive box named 'settings'.
/// Open the box in main.dart before calling any getter/setter.
class AppSettings {
  static const _boxName = 'settings';
  static const _sidebarOnRightKey = 'sidebarOnRight';

  static Box<dynamic> get _box => Hive.box<dynamic>(_boxName);

  /// Whether the sidebar is on the right side in landscape mode.
  /// Defaults to true.
  static bool get sidebarOnRight =>
      _box.get(_sidebarOnRightKey, defaultValue: true) as bool;

  static Future<void> setSidebarOnRight(bool value) =>
      _box.put(_sidebarOnRightKey, value);
}
