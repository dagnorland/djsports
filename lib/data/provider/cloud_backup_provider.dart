import 'package:djsports/data/services/cloud_backup_service.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final cloudBackupServiceProvider = Provider<CloudBackupService>(
  (_) => CloudBackupService(),
);

final cloudBackupListProvider =
    FutureProvider.family<List<CloudBackupSummary>, String>(
      // '' = Profile or PIN not set: don't read the "empty" profile path.
      (ref, profileName) async => profileName.isEmpty
          ? const <CloudBackupSummary>[]
          : ref
                .watch(cloudBackupServiceProvider)
                .listBackupsForProfile(profileName),
    );
