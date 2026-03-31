import 'package:djsports/data/services/cloud_backup_service.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final cloudBackupServiceProvider = Provider<CloudBackupService>(
  (_) => CloudBackupService(),
);

final cloudBackupListProvider = FutureProvider.family<
    List<CloudBackupSummary>, String>(
  (ref, profileName) => ref
      .watch(cloudBackupServiceProvider)
      .listBackupsForProfile(profileName),
);
