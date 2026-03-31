import 'dart:async';

import 'package:djsports/data/models/djplaylist_model.dart';
import 'package:djsports/data/models/djtrack_model.dart';
import 'package:djsports/data/provider/backup_profile_provider.dart';
import 'package:djsports/data/provider/cloud_backup_provider.dart';
import 'package:djsports/data/provider/device_name_provider.dart';
import 'package:djsports/data/models/spotify_playlist_result.dart';
import 'package:spotify/spotify.dart' show Track;
import 'package:djsports/data/provider/djplaylist_provider.dart';
import 'package:djsports/data/provider/djtrack_provider.dart';
import 'package:djsports/data/repo/spotify_remote_repository.dart';
import 'package:djsports/data/services/spotify_playlist_service.dart';
import 'package:djsports/features/cloud_backup/cloud_backup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hive_ce/hive.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class FirstTimeUseScreen extends ConsumerWidget {
  const FirstTimeUseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _WelcomeHeader(),
              const SizedBox(height: 32),
              const _SpotifySection(),
              const SizedBox(height: 28),
              const _PlaylistTypesSection(),
              const SizedBox(height: 28),
              const _HowToAddSection(),
              const SizedBox(height: 32),
              const _DeviceNameSection(),
              const SizedBox(height: 32),
              const _ExampleSetupsSection(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _WelcomeHeader extends StatelessWidget {
  const _WelcomeHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.green.shade700,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.sports_handball,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            const Text(
              'djSports',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Welcome! Your DJ setup for sports events.',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'djSports puts the right music in your hands — exactly when '
          'the moment calls for it. Set up your playlists, connect '
          'Spotify, and let the game begin.',
          style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
        ),
      ],
    );
  }
}

class _SpotifySection extends HookConsumerWidget {
  const _SpotifySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoggingIn = useState(false);

    final repo = ref.read(spotifyRemoteRepositoryProvider);
    final spotifyUserId = useValueListenable(repo.spotifyUserIdNotifier);

    Future<void> loginToSpotify() async {
      isLoggingIn.value = true;
      try {
        await repo.reGrantSpotify();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Login failed: $e')));
        }
      } finally {
        isLoggingIn.value = false;
      }
    }

    return _InfoCard(
      icon: Icons.wifi,
      iconColor: Colors.green.shade700,
      title: 'Connect to Spotify',
      children: [
        _Step(
          number: '1',
          text: 'Make sure the Spotify app is installed and you are logged in.',
        ),
        _Step(
          number: '2',
          text:
              'Tap the wifi icon in the top bar to grant djSports access '
              'to your Spotify account.',
        ),
        _Step(
          number: '3',
          text:
              'Approve the permissions when Spotify asks. '
              'You only need to do this once.',
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: isLoggingIn.value ? null : loginToSpotify,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade700,
            foregroundColor: Colors.white,
          ),
          icon: isLoggingIn.value
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.login, size: 18),
          label: Text(isLoggingIn.value ? 'Logging in…' : 'Login to Spotify'),
        ),
        if (spotifyUserId.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  size: 16,
                  color: Colors.green.shade700,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (repo.spotifyUserDisplayName.isNotEmpty)
                        Text(
                          repo.spotifyUserDisplayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      Text(
                        spotifyUserId,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _PlaylistTypesSection extends StatelessWidget {
  const _PlaylistTypesSection();

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      icon: Icons.queue_music,
      iconColor: Colors.black87,
      title: 'Playlist Types',
      children: [
        _TypeBadge(
          color: Colors.red,
          name: 'HotSpot',
          description:
              'Goals, slam dunks, and direct scoring moments. '
              'Drop the banger the second it happens.',
        ),
        _TypeBadge(
          color: Colors.green,
          name: 'Match',
          description:
              'Penalties, floor cleaning, time-outs — '
              'keep the energy steady during the game.',
        ),
        _TypeBadge(
          color: Colors.blue,
          name: 'Fun Stuff',
          description:
              'Get the crowd to cheer, clap, and make noise. '
              'Pure audience interaction.',
        ),
        _TypeBadge(
          color: Colors.black,
          name: 'Pre Match',
          description:
              'Warm-up and player introductions before the action '
              'starts. Build the tension.',
        ),
      ],
    );
  }
}

class _HowToAddSection extends StatelessWidget {
  const _HowToAddSection();

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      icon: Icons.playlist_add,
      iconColor: Colors.black87,
      title: 'Add Your First Playlist',
      children: [
        _Step(
          number: '1',
          text:
              'Open Spotify on your computer or phone and go to the '
              'playlist you want to use.',
        ),
        _Step(
          number: '2',
          text:
              'Copy the Spotify URI: tap the three dots (···) → Share → Copy '
              'Spotify URI. It looks like: spotify:playlist:abc123...',
        ),
        _Step(
          number: '3',
          text:
              'Tap + in the top bar, paste the URI, choose the type, '
              'and hit Sync to import tracks.',
        ),
      ],
    );
  }
}

class _DeviceNameSection extends HookConsumerWidget {
  const _DeviceNameSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileName = ref.watch(backupProfileProvider);
    final profileCtrl = useTextEditingController(
      text: ref.read(backupProfileProvider),
    );
    final pinCtrl = useTextEditingController(text: ref.read(backupPinProvider));
    final pinVisible = useState(false);
    final profileKey = ref.watch(backupProfileKeyProvider);
    final deviceName = ref.watch(deviceNameProvider);
    final hasExplicitName =
        Hive.box<dynamic>('settings').get('deviceName') != null;
    final isChecking = useState(false);

    Future<void> checkForBackups() async {
      final key = ref.read(backupProfileKeyProvider);

      if (key.isEmpty) {
        if (!context.mounted) return;
        unawaited(
          showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Set Profile & PIN first'),
              content: const Text(
                'Enter a Profile name and 4-digit PIN above and save them, '
                'then check for backups.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
              ],
            ),
          ),
        );
        return;
      }

      isChecking.value = true;
      try {
        final service = ref.read(cloudBackupServiceProvider);
        final backups = await service.listBackupsForProfile(key);
        if (!context.mounted) return;

        if (backups.isEmpty) {
          unawaited(
            showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('No backups found'),
                content: Text(
                  'No cloud backups found for profile "$profileName".',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('OK'),
                  ),
                ],
              ),
            ),
          );
        } else {
          final fmt = DateFormat('MMM d y  HH:mm');
          final openBackup = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text('${backups.length} backup(s) found'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Available backups for profile "$profileName":'),
                  const SizedBox(height: 12),
                  ...backups.map(
                    (b) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.cloud,
                            size: 16,
                            color: Colors.blue.shade600,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  b.deviceName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  '${fmt.format(b.createdAt.toLocal())} · '
                                  '${b.playlistCount} playlists · '
                                  '${b.trackCount} tracks',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Open Cloud Backup to choose one to restore?',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Not now'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Open Cloud Backup'),
                ),
              ],
            ),
          );

          if (openBackup == true && context.mounted) {
            unawaited(
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const CloudBackupScreen(),
                ),
              ),
            );
          }
        }
      } catch (e) {
        if (!context.mounted) return;
        unawaited(
          showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Check failed'),
              content: Text('Could not check for backups: $e'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
              ],
            ),
          ),
        );
      } finally {
        isChecking.value = false;
      }
    }

    return _InfoCard(
      icon: Icons.devices,
      iconColor: Colors.black87,
      title: 'Profile & Device Name',
      children: [
        // ── Profile ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            'Profile + PIN — shared across all your devices. '
            'Every device with the same Profile and PIN sees the same backups.',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: profileCtrl,
                decoration: InputDecoration(
                  labelText: 'Profile name',
                  hintText: 'e.g. Oslo Vikings',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  suffixIcon: profileKey.isNotEmpty
                      ? const Icon(
                          Icons.check_circle_outline,
                          size: 18,
                          color: Colors.green,
                        )
                      : Icon(
                          Icons.warning_amber_rounded,
                          size: 18,
                          color: Colors.orange.shade700,
                        ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 110,
              child: TextField(
                controller: pinCtrl,
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: !pinVisible.value,
                decoration: InputDecoration(
                  labelText: 'PIN',
                  hintText: '1234',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  counterText: '',
                  suffixIcon: IconButton(
                    icon: Icon(
                      pinVisible.value
                          ? Icons.visibility_off
                          : Icons.visibility,
                      size: 18,
                    ),
                    onPressed: () => pinVisible.value = !pinVisible.value,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () async {
                final name = profileCtrl.text.trim();
                final pin = pinCtrl.text.trim();
                if (name.isEmpty || pin.length != 4) return;
                await ref.read(backupProfileProvider.notifier).setProfile(name);
                await ref.read(backupPinProvider.notifier).setPin(pin);
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              child: const Text('Save'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // ── Device name ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            'Device name — labels which device made each backup.',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
          ),
        ),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.computer, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Text(
                    deviceName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (!hasExplicitName) ...[
                    const SizedBox(width: 6),
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 14,
                      color: Colors.orange.shade700,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: () => showDeviceNameDialog(context, ref, deviceName),
              icon: const Icon(Icons.edit, size: 16),
              label: const Text('Set Name'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // ── Check for backups ────────────────────────────────────────────
        OutlinedButton.icon(
          onPressed: isChecking.value ? null : checkForBackups,
          icon: isChecking.value
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.cloud_download_outlined, size: 16),
          label: Text(isChecking.value ? 'Checking…' : 'Check for backups'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      ],
    );
  }
}

Future<void> showDeviceNameDialog(
  BuildContext context,
  WidgetRef ref,
  String currentName,
) async {
  final controller = TextEditingController(text: currentName);
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Device Name'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'e.g. DJ MacBook, iPad Stage',
          border: OutlineInputBorder(),
        ),
        onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  if (result != null && result.isNotEmpty) {
    await ref.read(deviceNameProvider.notifier).setDeviceName(result);
  }
}

enum _SyncStatus { pending, syncing, done, error }

typedef _SyncEntry = ({
  DJPlaylistType type,
  String uri,
  _SyncStatus status,
  String name,
  int trackCount,
  String? errorMsg,
});

const _sampleDefs = [
  (type: DJPlaylistType.hotspot, uri: '5IdSziWdXmWfhILWI41KNF'),
  (type: DJPlaylistType.match, uri: '2T2tlhNo79SxGeoPoOGiOI'),
  (type: DJPlaylistType.match, uri: '2PCecVUcJmyGHBRBzpp1c4'),
  (type: DJPlaylistType.funStuff, uri: '3skHFi4Rs2gkQo9UXUUo7O'),
  (type: DJPlaylistType.preMatch, uri: '1ALsjB5ib94JNTXrnkie1N'),
];

class _ExampleSetupsSection extends HookConsumerWidget {
  const _ExampleSetupsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRunning = useState(false);
    final isDone = useState(false);
    final progress = useState<List<_SyncEntry>>([]);

    void updateEntry(int index, _SyncEntry updated) {
      final list = List<_SyncEntry>.from(progress.value);
      list[index] = updated;
      progress.value = list;
    }

    Future<void> runSetup() async {
      isRunning.value = true;
      isDone.value = false;

      // Initialise all entries as pending
      progress.value = _sampleDefs
          .map(
            (d) => (
              type: d.type,
              uri: d.uri,
              status: _SyncStatus.pending,
              name: d.type.name,
              trackCount: 0,
              errorMsg: null,
            ),
          )
          .toList();

      final service = ref.read(playlistServiceProvider);
      // Use repos directly so Riverpod state (and the home page) is NOT
      // refreshed until all playlists are synced. Updating the notifier
      // mid-loop causes DJSportsHomePage to swap FirstTimeUseScreen out,
      // disposing these hooks before the loop finishes.
      final playlistRepo = ref.read(hivePlaylistData.notifier).repo;
      final trackRepo = ref.read(hiveTrackData.notifier).repo;

      for (int i = 0; i < _sampleDefs.length; i++) {
        final def = _sampleDefs[i];
        final e = progress.value[i];
        updateEntry(i, (
          type: e.type,
          uri: e.uri,
          status: _SyncStatus.syncing,
          name: e.name,
          trackCount: 0,
          errorMsg: null,
        ));

        try {
          // Create placeholder playlist directly in Hive (no Riverpod update)
          final playlist = DJPlaylist(
            id: const Uuid().v4(),
            name: def.type.name,
            type: def.type.name,
            spotifyUri: def.uri,
            autoNext: true,
            shuffleAtEnd: false,
            trackIds: [],
            position: i,
          );
          playlistRepo.addDJPlaylist(playlist);

          // Fetch name and tracks from Spotify
          final syncName = await service.searchRepository.getSpotifyNameUri(
            def.uri,
          );
          final trackResult = await service.searchRepository.getTracksByUri(
            def.uri,
          );
          final tracks = trackResult.when((t) => t, error: (_) => <Track>[]);

          playlist.name = syncName.isNotEmpty ? syncName : def.type.name;

          for (final track in tracks) {
            final djTrack = DJTrack.fromSpotifyTrack(track);
            trackRepo.addDJTrack(djTrack);
            playlist.addTrack(djTrack.id);
          }
          playlistRepo.updateDJPlaylist(playlist);

          updateEntry(i, (
            type: def.type,
            uri: def.uri,
            status: _SyncStatus.done,
            name: playlist.name,
            trackCount: tracks.length,
            errorMsg: null,
          ));
        } catch (err) {
          updateEntry(i, (
            type: def.type,
            uri: def.uri,
            status: _SyncStatus.error,
            name: def.type.name,
            trackCount: 0,
            errorMsg: err.toString(),
          ));
        }
      }

      // All done — now refresh Riverpod so the home page picks up the changes
      ref.read(hivePlaylistData.notifier).fetchDJPlaylist();
      ref.read(hiveTrackData.notifier).fetchDJTrack();

      isRunning.value = false;
      isDone.value = true;
    }

    return _InfoCard(
      icon: Icons.rocket_launch_outlined,
      iconColor: Colors.green.shade700,
      title: 'djSports Example Setup',
      children: [
        Text(
          'Creates 5 real Spotify playlists (HotSpot, Match ×2, Fun Stuff, '
          'Pre Match) and syncs all tracks from Spotify. '
          'Requires Spotify connection.',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 12),
        if (!isRunning.value && !isDone.value)
          ElevatedButton.icon(
            onPressed: runSetup,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.download_for_offline_outlined, size: 18),
            label: const Text('Load Example Setup'),
          ),
        if (isRunning.value || isDone.value) ...[
          ...progress.value.asMap().entries.map((entry) {
            final e = entry.value;
            final typeColor = _typeColor(e.type);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SyncStatusIcon(status: e.status, color: typeColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: typeColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                e.type.name.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: typeColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                e.status == _SyncStatus.done
                                    ? e.name
                                    : e.status == _SyncStatus.syncing
                                    ? 'Syncing…'
                                    : e.status == _SyncStatus.error
                                    ? 'Error'
                                    : 'Pending',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (e.status == _SyncStatus.done)
                          Text(
                            '${e.trackCount} tracks synced',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        if (e.status == _SyncStatus.error && e.errorMsg != null)
                          Text(
                            e.errorMsg!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.red,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
          if (isDone.value) ...[
            const SizedBox(height: 8),
            Text(
              'Done! Your playlists are ready in the main screen.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.green.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ],
    );
  }

  Color _typeColor(DJPlaylistType type) => switch (type) {
    DJPlaylistType.hotspot => Colors.red,
    DJPlaylistType.match => Colors.green.shade700,
    DJPlaylistType.funStuff => Colors.blue,
    DJPlaylistType.preMatch => Colors.black87,
    _ => Colors.grey,
  };
}

class _SyncStatusIcon extends StatelessWidget {
  const _SyncStatusIcon({required this.status, required this.color});
  final _SyncStatus status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: switch (status) {
        _SyncStatus.pending => Icon(
          Icons.radio_button_unchecked,
          size: 20,
          color: Colors.grey.shade400,
        ),
        _SyncStatus.syncing => SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: color),
        ),
        _SyncStatus.done => Icon(Icons.check_circle, size: 20, color: color),
        _SyncStatus.error => const Icon(
          Icons.error_outline,
          size: 20,
          color: Colors.red,
        ),
      },
    );
  }
}

// ── Shared UI components ──────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: Colors.black87,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({
    required this.color,
    required this.name,
    required this.description,
  });

  final Color color;
  final String name;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 4),
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
                children: [
                  TextSpan(
                    text: '$name  ',
                    style: TextStyle(fontWeight: FontWeight.w700, color: color),
                  ),
                  TextSpan(text: description),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
