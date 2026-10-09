import 'package:djsports/data/services/cloud_backup_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Must match djsportsweb test/profile-key.test.ts — both apps have to
/// find the same backups.
void main() {
  test('profileStorageKey matches the web app', () {
    expect(
      profileStorageKey('Oslo Vikings|1234'),
      '1a494a588b3e8622b83e9ea5db7d2598e2fc95efed03b55856b7c21bda0cc007',
    );
  });

  test('trims and lower-cases the name, keeps the PIN', () {
    expect(
      profileStorageKey('  Oslo Vikings |1234'),
      profileStorageKey('oslo vikings|1234'),
    );
    expect(
      profileStorageKey('Oslo Vikings|1234'),
      isNot(profileStorageKey('Oslo Vikings|1235')),
    );
  });
}
