import 'package:djsports/data/provider/cloud_backup_provider.dart';
import 'package:djsports/data/provider/device_name_provider.dart';
import 'package:djsports/data/provider/djplaylist_provider.dart';
import 'package:djsports/data/provider/djtrack_provider.dart';
import 'package:djsports/data/provider/track_time_provider.dart';
import 'package:djsports/data/repo/djplaylist_repository.dart';
import 'package:djsports/data/repo/djtrack_repository.dart';
import 'package:djsports/data/repo/spotify_remote_repository.dart';
import 'package:djsports/data/repo/track_time_repository.dart';
import 'package:djsports/data/services/cloud_backup_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

// ignore_for_file: avoid_print

class CloudBackupScreen extends HookConsumerWidget {
  const CloudBackupScreen({super.key, this.refreshCallback});

  final VoidCallback? refreshCallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(spotifyRemoteRepositoryProvider);
    // Watch reactively — profile arrives asynchronously after connect.
    final spotifyUserId = useValueListenable(repo.spotifyUserIdNotifier);
    final displayName = repo.spotifyUserDisplayName;

    final deviceNameCtrl = useTextEditingController(
      text: ref.read(deviceNameProvider),
    );
    final isSaving = useState(false);
    final isRestoring = useState(false);
    final restoreProgress = useState<String?>(null);
    final statusMessage = useState<String?>(null);
    final statusIsError = useState(false);

    void showStatus(String msg, {bool error = false}) {
      statusMessage.value = msg;
      statusIsError.value = error;
    }

    void clearStatus() => statusMessage.value = null;

    Future<void> doBackup() async {
      print('[CloudBackup] doBackup called — userId=$spotifyUserId device=${deviceNameCtrl.text.trim()}');
      clearStatus();
      isSaving.value = true;
      try {
        final service = ref.read(cloudBackupServiceProvider);
        print('[CloudBackup] calling createBackup…');
        await service.createBackup(
          spotifyUserId: spotifyUserId,
          spotifyDisplayName: displayName,
          deviceName: deviceNameCtrl.text.trim(),
          playlistRepo: DJPlaylistRepo(),
          trackRepo: DJTrackRepo(),
          trackTimeRepo: TrackTimeRepo(),
        );
        print('[CloudBackup] createBackup succeeded');
        ref.invalidate(cloudBackupListProvider(spotifyUserId));
        showStatus('Backup created successfully.');
      } catch (e, st) {
        print('[CloudBackup] createBackup ERROR: $e\n$st');
        showStatus('Backup failed: $e', error: true);
      } finally {
        isSaving.value = false;
      }
    }

    Future<void> doRestore(CloudBackupSummary backup) async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Restore backup?'),
          content: Text(
            'This will replace ALL local playlists, tracks, and timings '
            'with the backup from ${backup.deviceName} '
            '(${DateFormat('MMM d y HH:mm').format(backup.createdAt)}).\n\n'
            'This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'Restore',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
      if (confirmed != true) return;

      clearStatus();
      isRestoring.value = true;
      restoreProgress.value = null;
      try {
        final service = ref.read(cloudBackupServiceProvider);
        await service.restoreBackup(
          backupId: backup.id,
          playlistRepo: DJPlaylistRepo(),
          trackRepo: DJTrackRepo(),
          trackTimeRepo: TrackTimeRepo(),
          onProgress: (msg) => restoreProgress.value = msg,
        );
        restoreProgress.value = null;
        // Refresh local Riverpod state so the home screen reflects the restore.
        ref.invalidate(hivePlaylistData);
        ref.invalidate(hiveTrackData);
        ref.invalidate(hiveTrackTimeData);
        refreshCallback?.call();
        showStatus(
          'Restored ${backup.playlistCount} playlists '
          'and ${backup.trackCount} tracks.',
        );
      } catch (e) {
        restoreProgress.value = null;
        showStatus('Restore failed: $e', error: true);
      } finally {
        isRestoring.value = false;
      }
    }

    Future<void> doDelete(CloudBackupSummary backup) async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete backup?'),
          content: Text(
            'Delete backup from ${backup.deviceName} '
            '(${DateFormat('MMM d y HH:mm').format(backup.createdAt)})?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
      if (confirmed != true) return;

      clearStatus();
      try {
        await ref.read(cloudBackupServiceProvider).deleteBackup(backup.id);
        ref.invalidate(cloudBackupListProvider(spotifyUserId));
        showStatus('Backup deleted.');
      } catch (e) {
        showStatus('Delete failed: $e', error: true);
      }
    }

    final backupsAsync = ref.watch(cloudBackupListProvider(spotifyUserId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cloud Backup'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      backgroundColor: Colors.white,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader(label: 'Spotify account'),
          _InfoRow(label: 'Display name', value: displayName.isEmpty ? '—' : displayName),
          _InfoRow(
            label: 'User ID',
            value: spotifyUserId.isEmpty
                ? 'Not connected — connect Spotify first'
                : spotifyUserId,
          ),
          const SizedBox(height: 24),
          _SectionHeader(label: 'Device name'),
          const Text(
            'Used to label backups from this device.',
            style: TextStyle(color: Colors.black54, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: deviceNameCtrl,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  ref
                      .read(deviceNameProvider.notifier)
                      .setDeviceName(deviceNameCtrl.text.trim());
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Device name saved.')),
                  );
                },
                child: const Text('Save'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SectionHeader(label: 'Backup'),
          const Text(
            'Creates a snapshot of all playlists, tracks and '
            'timings in Firestore. Keeps the last 5 per device.',
            style: TextStyle(color: Colors.black54, fontSize: 13),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: (isSaving.value || spotifyUserId.isEmpty)
                ? null
                : doBackup,
            icon: isSaving.value
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_upload),
            label: Text(isSaving.value ? 'Backing up…' : 'Backup Now'),
          ),
          if (statusMessage.value != null) ...[
            const SizedBox(height: 8),
            SelectableText.rich(
              TextSpan(
                text: statusMessage.value,
                style: TextStyle(
                  color: statusIsError.value ? Colors.red : Colors.green.shade700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
          if (restoreProgress.value != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Text(
                  restoreProgress.value!,
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          _SectionHeader(label: 'Existing backups'),
          if (spotifyUserId.isEmpty)
            const Text(
              'Connect Spotify to see your backups.',
              style: TextStyle(color: Colors.black54),
            )
          else
            backupsAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => SelectableText.rich(
                TextSpan(
                  text: 'Failed to load backups: $e',
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ),
              data: (backups) {
                if (backups.isEmpty) {
                  return const Text(
                    'No backups yet.',
                    style: TextStyle(color: Colors.black54),
                  );
                }
                return Column(
                  children: backups
                      .map(
                        (b) => _BackupTile(
                          backup: b,
                          isRestoring: isRestoring.value,
                          onRestore: () => doRestore(b),
                          onDelete: () => doDelete(b),
                        ),
                      )
                      .toList(),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackupTile extends StatelessWidget {
  const _BackupTile({
    required this.backup,
    required this.isRestoring,
    required this.onRestore,
    required this.onDelete,
  });

  final CloudBackupSummary backup;
  final bool isRestoring;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('MMM d y  HH:mm').format(backup.createdAt.toLocal());
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(backup.deviceName),
        subtitle: Text(
          '$dateStr\n'
          '${backup.playlistCount} playlists · '
          '${backup.trackCount} tracks · '
          '${backup.tracksWithStartTime} with start time',
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: isRestoring ? null : onRestore,
              child: const Text('Restore'),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Delete backup',
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
