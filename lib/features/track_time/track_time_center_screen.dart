import 'dart:convert';

import 'package:djsports/data/models/djplaylist_model.dart';
import 'package:djsports/data/models/djtrack_model.dart';
import 'package:djsports/data/models/spotify_connection_log.dart';
import 'package:djsports/data/models/track_time_model.dart';
import 'package:djsports/data/provider/djplaylist_provider.dart';
import 'package:djsports/data/provider/track_time_provider.dart';
import 'package:djsports/data/provider/djtrack_provider.dart';
import 'package:djsports/data/repo/spotify_remote_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';

// Riverpod
import 'package:hooks_riverpod/hooks_riverpod.dart';

class TrackTimeCenterScreen extends StatefulHookConsumerWidget {
  const TrackTimeCenterScreen({super.key, this.refreshCallback});

  final VoidCallback? refreshCallback;

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _EditScreenState();
}

class _EditScreenState extends ConsumerState<TrackTimeCenterScreen> {
  final nameController = TextEditingController();
  final importJsonDataController = TextEditingController();
  final importPlaylistJsonDataController = TextEditingController();
  List<TrackTime> trackTimeList = [];
  List<DJTrack> trackWithStartTimeList = [];
  int trackWithZeroStartTimeListLength = 0;

  // Diagnostic section state
  bool _diagRunning = false;
  String _diagLastResult = '';
  final _diagTestUriController = TextEditingController(
    text: 'spotify:track:4uLU6hMCjMI75M1A2tKUQC',
  );

  @override
  void initState() {
    nameController.text = '';
    importJsonDataController.text = '';
    importPlaylistJsonDataController.text = '';
    importJsonDataController.addListener(() {
      setState(() {});
    });
    importPlaylistJsonDataController.addListener(() {
      setState(() {});
    });
    super.initState();
  }

  @override
  void dispose() {
    nameController.dispose();
    importJsonDataController.dispose();
    importPlaylistJsonDataController.dispose();
    _diagTestUriController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final djTrackWithStartTimeList = ref.watch(dataTrackWithStartTimeProvider);
    trackWithZeroStartTimeListLength = ref
        .watch(dataTrackProvider)
        .where((element) => element.startTime == 0)
        .length;

    trackTimeList = ref.watch(dataTrackTimeProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        leading: IconButton(
          onPressed: () {
            Navigator.of(context).pop();
            widget.refreshCallback ?? widget.refreshCallback;
          },
          icon: const Icon(Icons.arrow_back, color: Colors.black, size: 30),
        ),
        actions: const [],
        title: const Text(
          'Track times — Import & Export',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            children: [
              _infoSection(context),
              const Gap(20),
              globalInfoBox(context, 'PLAYLISTS', _playlistSection(context)),
              const Gap(20),
              globalInfoBox(
                context,
                'EXPORT TRACK START TIMES',
                _exportTrackTimesSection(
                  context,
                  djTrackWithStartTimeList,
                  trackTimeList,
                ),
              ),
              const Gap(20),
              globalInfoBox(
                context,
                'IMPORT TRACK START TIMES',
                _importTrackTimesSection(
                  context,
                  djTrackWithStartTimeList,
                  trackTimeList,
                ),
              ),
              const Gap(20),
              globalInfoBox(
                context,
                'MANAGE TRACK START TIME LIST',
                _deleteSection(context, trackTimeList),
              ),
              const Gap(20),
              globalInfoBox(
                context,
                'SPOTIFY DIAGNOSTIC',
                _diagSection(context),
              ),
              const Gap(20),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Info section
  // ---------------------------------------------------------------------------

  Widget _infoSection(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border.all(color: Colors.blue.shade200, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: Colors.blue.shade600, size: 24),
            const Gap(12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'How track start times work',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                  ),
                  const Gap(8),
                  Text(
                    'Set a start time on a track (e.g. skip the intro) and export '
                    'the list to share with others. When someone imports the list, '
                    'their tracks will automatically start at the right position.\n\n'
                    'You can also back up and restore your playlists using the '
                    'Playlists section below.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.blue.shade900,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Playlists section (copy + import)
  // ---------------------------------------------------------------------------

  Widget _playlistSection(BuildContext context) {
    final List<DJPlaylist> playlists =
        ref.watch(hivePlaylistData) ?? <DJPlaylist>[];
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'You have ${playlists.length} playlist(s) in your library.',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Gap(4),
          Text(
            'Copy all playlists as JSON and share with others. '
            'They can paste it below to recreate the same playlists.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const Gap(16),
          _sectionButton(
            context,
            label: 'Copy playlists as JSON  (URI + type + name)',
            icon: Icons.copy,
            disabled: playlists.isEmpty,
            onPressed: () {
              _copyPlaylistUrisToClipboard(playlists);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Copied ${playlists.length} playlist(s) to clipboard',
                    ),
                  ),
                );
              }
            },
          ),
          const Gap(20),
          const Divider(),
          const Gap(12),
          Text(
            'Paste playlist JSON here to import playlists into your library.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const Gap(10),
          TextField(
            controller: importPlaylistJsonDataController,
            maxLines: 6,
            decoration: InputDecoration(
              hintText:
                  'Paste JSON from "Copy playlists" here\n\nExample:\n'
                  '[\n'
                  '  {"playlistUri":"spotify:playlist:...","playlistType":"hotspot","name":"Goals"}\n'
                  ']',
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: Theme.of(context).primaryColor.withOpacity(0.05),
            ),
          ),
          const Gap(12),
          _sectionButton(
            context,
            label: 'Import playlists from JSON',
            icon: Icons.playlist_add,
            disabled: importPlaylistJsonDataController.text.trim().isEmpty,
            onPressed: () {
              _importPlaylistsFromJson(
                importPlaylistJsonDataController.text.trim(),
              );
            },
          ),
          const Gap(8),
        ],
      ),
    );
  }

  void _copyPlaylistUrisToClipboard(List<DJPlaylist> playlists) {
    final data = playlists
        .map<Map<String, String>>(
          (p) => {
            'playlistUri': p.spotifyUri,
            'playlistType': p.type,
            'name': p.name,
          },
        )
        .toList();
    final jsonString = const JsonEncoder.withIndent('  ').convert(data);
    Clipboard.setData(ClipboardData(text: jsonString));
  }

  void _importPlaylistsFromJson(String jsonData) {
    try {
      final dynamic decoded = json.decode(jsonData);
      if (decoded is! List) {
        throw const FormatException('JSON must be a list.');
      }

      final existingPlaylists = ref.read(hivePlaylistData) ?? [];
      int added = 0;
      int skipped = 0;

      for (final item in decoded) {
        if (item is! Map<String, dynamic>) {
          throw const FormatException('Each item must be an object.');
        }
        final uri = item['playlistUri'] as String? ?? '';
        final type = item['playlistType'] as String? ?? 'hotspot';
        final name = item['name'] as String? ?? 'Imported playlist';

        if (uri.isEmpty) continue;

        final alreadyExists = existingPlaylists.any((p) => p.spotifyUri == uri);
        if (alreadyExists) {
          skipped++;
          continue;
        }

        final playlist = DJPlaylist(
          id: '',
          name: name,
          type: type,
          spotifyUri: uri,
          autoNext: true,
          shuffleAtEnd: false,
          trackIds: [],
        );
        ref.read(hivePlaylistData.notifier).addDJplaylist(playlist);
        added++;
      }

      if (mounted) {
        importPlaylistJsonDataController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              added > 0
                  ? 'Added $added playlist(s)${skipped > 0 ? ', $skipped already existed' : ''}. '
                        'Open each playlist to sync tracks from Spotify.'
                  : 'No new playlists — all already in your library.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid JSON — check the format and try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Export track start times
  // ---------------------------------------------------------------------------

  Widget _exportTrackTimesSection(
    BuildContext context,
    List<DJTrack> djTrackWithStartTimeList,
    List<TrackTime> trackTimeList,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${djTrackWithStartTimeList.length} track(s) with a start time set '
            'in your playlists.',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Gap(4),
          Text(
            '${trackTimeList.length} track(s) currently in the export list.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const Gap(16),
          _sectionButton(
            context,
            label: 'Add missing tracks to export list',
            icon: Icons.sync,
            disabled: djTrackWithStartTimeList.isEmpty,
            onPressed: () {
              updateTrackTimeListWithMissingTracks(
                djTrackWithStartTimeList,
                trackTimeList,
              );
            },
          ),
          const Gap(10),
          _sectionButton(
            context,
            label: 'Copy export list as JSON  (${trackTimeList.length} tracks)',
            icon: Icons.copy,
            disabled: trackTimeList.isEmpty,
            onPressed: () {
              final bytes = exportTrackTimeListToClipboard(trackTimeList);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Copied ${trackTimeList.length} track start time(s) '
                      'to clipboard  ($bytes bytes)',
                    ),
                  ),
                );
              }
            },
          ),
          const Gap(8),
        ],
      ),
    );
  }

  void updateTrackTimeListWithMissingTracks(
    List<DJTrack> djTrackWithStartTimeList,
    List<TrackTime> trackTimeList,
  ) {
    final allTracks = djTrackWithStartTimeList
        .map((e) => TrackTime.fromDJTrack(e))
        .toList();

    int addedCount = 0;
    for (final trackTime in allTracks) {
      final existsBefore = ref
          .read(hiveTrackTimeData.notifier)
          .existsTrackTime(trackTime.id);
      if (!existsBefore) {
        ref.read(hiveTrackTimeData.notifier).addTrackTime(trackTime);
        addedCount++;
      }
    }

    setState(() {
      this.trackTimeList = ref.read(dataTrackTimeProvider);
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            addedCount > 0
                ? 'Added $addedCount new track(s) to the export list'
                : 'No new tracks to add — all ${allTracks.length} already in the list',
          ),
        ),
      );
    }
  }

  int exportTrackTimeListToClipboard(List<TrackTime> trackTimeList) {
    final jsonString = jsonEncode(trackTimeList);
    Clipboard.setData(ClipboardData(text: jsonString));
    return jsonString.length;
  }

  // ---------------------------------------------------------------------------
  // Import track start times
  // ---------------------------------------------------------------------------

  Widget _importTrackTimesSection(
    BuildContext context,
    List<DJTrack> djTrackWithStartTimeList,
    List<TrackTime> trackTimeList,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${trackTimeList.length} track start time(s) in the list.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const Gap(4),
          Text(
            'Paste a JSON list of track start times to import them.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const Gap(10),
          TextField(
            controller: importJsonDataController,
            maxLines: 10,
            decoration: InputDecoration(
              hintText:
                  'Paste JSON here, then press Import below\n\n'
                  'Example:\n${_exampleTrackTimeJson()}',
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: Theme.of(context).primaryColor.withOpacity(0.05),
            ),
          ),
          const Gap(16),
          _sectionButton(
            context,
            label: 'Import track start times from JSON',
            icon: Icons.download,
            disabled: importJsonDataController.text.trim().isEmpty,
            onPressed: () {
              importTrackTimeJsonData(importJsonDataController.text.trim());
            },
          ),
          const Gap(10),
          _sectionButton(
            context,
            label: 'Update all tracks with no start time from list',
            icon: Icons.update,
            disabled:
                trackTimeList.isEmpty || trackWithZeroStartTimeListLength == 0,
            onPressed: () {
              _applyStartTimesToTracksWithNoStartTime();
            },
          ),
          const Gap(8),
        ],
      ),
    );
  }

  void _applyStartTimesToTracksWithNoStartTime() {
    final allTracks = ref.read(hiveTrackData) ?? [];
    final tracksWithNoStartTime = allTracks
        .where((t) => t.startTime == 0)
        .toList();

    int updatedCount = 0;
    for (final track in tracksWithNoStartTime) {
      final match = trackTimeList.where((tt) => tt.id == track.id).firstOrNull;
      if (match != null && match.startTime > 0) {
        track.startTime = match.startTime;
        track.startTimeMS = match.startTimeMS ?? 0;
        ref.read(hiveTrackData.notifier).updateDJTrack(track);
        updatedCount++;
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            updatedCount > 0
                ? 'Updated $updatedCount track(s) with start times from the list'
                : 'No matches found — none of the ${tracksWithNoStartTime.length} '
                      'tracks without a start time exist in the import list',
          ),
        ),
      );
    }
  }

  String _exampleTrackTimeJson() {
    return '[\n'
        '  {"id":"6epn3r7S14KUqlReYr77hA","startTime":11000},\n'
        '  {"id":"4vVTI94F9uJ8lHNDWKv0i2","startTime":36000}\n'
        ']';
  }

  void importTrackTimeJsonData(String jsonData) async {
    try {
      final dynamic decoded = json.decode(jsonData);
      if (decoded is! List) {
        throw const FormatException('JSON must be a list.');
      }
      final List<TrackTime> importedTracks = [];

      for (final jsonItem in decoded) {
        if (jsonItem is! Map<String, dynamic>) {
          throw const FormatException('Each item must be an object.');
        }
        final trackTime = TrackTime.fromJson(jsonItem);
        importedTracks.add(trackTime);
      }

      int added = 0;
      for (final trackTime in importedTracks) {
        final exists =
            ref
                .read(hiveTrackTimeData)
                ?.any((element) => element.id == trackTime.id) ??
            false;
        if (exists) continue;
        ref.read(hiveTrackTimeData.notifier).addTrackTime(trackTime);
        added++;
      }

      if (mounted) {
        importJsonDataController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              added > 0
                  ? 'Imported $added track start time(s)'
                  : 'No new entries — all already in the list.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid JSON — check the format and try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Delete / manage section
  // ---------------------------------------------------------------------------

  Widget _deleteSection(BuildContext context, List<TrackTime> trackTimeList) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${trackTimeList.length} track start time(s) in the list.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const Gap(16),
          _sectionButton(
            context,
            label: 'Delete list with track start times',
            icon: Icons.delete_forever,
            disabled: trackTimeList.isEmpty,
            destructive: true,
            onPressed: () {
              deleteAllOrZeroTimeTrackTimes(trackTimeList, false);
            },
          ),
          const Gap(10),
          _sectionButton(
            context,
            label: 'Delete entries with no start time',
            icon: Icons.delete_outline,
            disabled: trackTimeList.isEmpty,
            destructive: true,
            onPressed: () {
              deleteAllOrZeroTimeTrackTimes(trackTimeList, true);
            },
          ),
          const Gap(8),
        ],
      ),
    );
  }

  void deleteAllOrZeroTimeTrackTimes(
    List<TrackTime> trackTimeList,
    bool onlyWithZeroStartTime,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm deletion'),
          content: Text(
            onlyWithZeroStartTime
                ? 'Delete ${trackTimeList.where((t) => t.startTime == 0).length} '
                      'entries that have no start time?'
                : 'Delete all ${trackTimeList.length} track start times from the list?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                for (final trackTime in trackTimeList) {
                  if (onlyWithZeroStartTime && trackTime.startTime == 0) {
                    ref
                        .read(hiveTrackTimeData.notifier)
                        .removeTrackTime(trackTime.id);
                  } else if (!onlyWithZeroStartTime) {
                    ref
                        .read(hiveTrackTimeData.notifier)
                        .removeTrackTime(trackTime.id);
                  }
                }
                setState(() {
                  this.trackTimeList = ref.read(dataTrackTimeProvider);
                });
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Spotify Diagnostic section
  // ---------------------------------------------------------------------------

  Widget _diagSection(BuildContext context) {
    final repo = ref.read(spotifyRemoteRepositoryProvider);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _diagStateCard(context, repo),
          const Gap(12),
          _sectionButton(
            context,
            label: 'Reset all  (clear session + caches)',
            icon: Icons.restart_alt,
            disabled: _diagRunning,
            destructive: true,
            onPressed: _diagReset,
          ),
          const Gap(12),
          const Divider(),
          const Gap(6),
          Text(
            'Step-by-step connect:',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const Gap(8),
          _diagButton(
            context,
            'Step 1: Get Access Token',
            Icons.key,
            _diagGetToken,
          ),
          const Gap(6),
          _diagButton(
            context,
            'Step 2: Connect Remote',
            Icons.link,
            _diagConnectRemote,
          ),
          const Gap(6),
          _diagButton(
            context,
            'Full Connect  (step 1 + 2)',
            Icons.wifi,
            _diagFullConnect,
          ),
          const Gap(6),
          _diagButton(
            context,
            'Force Full Reconnect',
            Icons.refresh,
            _diagForceReconnect,
          ),
          const Gap(12),
          const Divider(),
          const Gap(6),
          Text(
            'Playback:',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const Gap(8),
          TextField(
            controller: _diagTestUriController,
            decoration: const InputDecoration(
              labelText: 'Test track Spotify URI',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const Gap(6),
          _diagButton(
            context,
            'Step 3: Play Track',
            Icons.play_arrow,
            _diagPlay,
          ),
          const Gap(6),
          _diagButton(
            context,
            'Step 4: Seek to 30 s',
            Icons.fast_forward,
            _diagSeek,
          ),
          const Gap(6),
          _diagButton(context, 'Step 5: Pause', Icons.pause, _diagPause),
          const Gap(6),
          _diagButton(
            context,
            'Step 6: Resume',
            Icons.play_circle,
            _diagResume,
          ),
          if (_diagLastResult.isNotEmpty) ...[
            const Gap(12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Last result:\n$_diagLastResult',
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontFamily: 'monospace',
                  fontSize: 11,
                ),
              ),
            ),
          ],
          const Gap(12),
          const Divider(),
          const Gap(6),
          _diagLogHeader(context),
          const Gap(6),
          _diagLogView(context),
        ],
      ),
    );
  }

  Widget _diagStateCard(BuildContext context, SpotifyRemoteRepository repo) {
    String tokenInfo;
    if (repo.lastValidAccessToken.isEmpty) {
      tokenInfo = '(none)';
    } else {
      final t = repo.lastValidAccessToken;
      tokenInfo = '${t.substring(0, t.length.clamp(0, 16))}…';
    }

    String connTime;
    if (repo.lastConnectionTime.year == 1970) {
      connTime = 'never';
    } else {
      final age = DateTime.now().difference(repo.lastConnectionTime);
      if (age.inSeconds < 60) {
        connTime = '${age.inSeconds}s ago';
      } else {
        connTime = '${age.inMinutes}m ago';
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current State',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const Gap(6),
          _diagStateRow(
            'hasToken',
            repo.hasSpotifyAccessToken ? 'true' : 'false',
            repo.hasSpotifyAccessToken ? Colors.green : Colors.red,
          ),
          _diagStateRow(
            'isConnectedRemote',
            repo.isConnectedRemote ? 'true' : 'false',
            repo.isConnectedRemote ? Colors.green : Colors.red,
          ),
          _diagStateRow(
            'isPlaying',
            repo.isPlaying ? 'true' : 'false',
            Colors.black54,
          ),
          _diagStateRow('token', tokenInfo, Colors.black54),
          _diagStateRow('lastConnection', connTime, Colors.black54),
          if (repo.spotifyUserDisplayName.isNotEmpty ||
              repo.spotifyUserEmail.isNotEmpty)
            _diagStateRow(
              'account',
              [
                if (repo.spotifyUserDisplayName.isNotEmpty)
                  repo.spotifyUserDisplayName,
                if (repo.spotifyUserEmail.isNotEmpty) repo.spotifyUserEmail,
              ].join('  '),
              Colors.green.shade700,
            ),
          if (repo.lastConnectError.isNotEmpty)
            _diagStateRow(
              'lastError',
              repo.lastConnectError,
              Colors.red.shade700,
            ),
        ],
      ),
    );
  }

  Widget _diagStateRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _diagLogHeader(BuildContext context) {
    return Row(
      children: [
        ValueListenableBuilder<int>(
          valueListenable: SpotifyConnectionLog().changeCount,
          builder: (context, value, child) => Text(
            'Log  (${SpotifyConnectionLog().log.length} entries)',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: () {
            SpotifyConnectionLog().clear();
            setState(() {});
          },
          icon: const Icon(Icons.clear_all, size: 16),
          label: const Text('Clear'),
        ),
      ],
    );
  }

  Widget _diagLogView(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: SpotifyConnectionLog().changeCount,
      builder: (context, value, child) {
        final entries = SpotifyConnectionLog().log.reversed.toList();
        if (entries.isEmpty) {
          return Container(
            height: 80,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'No log entries yet',
              style: TextStyle(
                color: Colors.grey,
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
          );
        }
        return Container(
          height: 320,
          decoration: BoxDecoration(
            color: Colors.grey.shade900,
            borderRadius: BorderRadius.circular(6),
          ),
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: entries.length,
            itemBuilder: (ctx, i) {
              final e = entries[i];
              return _diagLogEntry(e);
            },
          ),
        );
      },
    );
  }

  Widget _diagLogEntry(SpotifyConnectionLogEntry e) {
    Color statusColor;
    String statusIcon;
    switch (e.status) {
      case SpotifyConnectionStatus.connectedSpotifyRemoteApp:
        statusColor = Colors.greenAccent;
        statusIcon = '●';
      case SpotifyConnectionStatus.connectedSpotify:
        statusColor = Colors.orange;
        statusIcon = '●';
      case SpotifyConnectionStatus.tokenExpired:
        statusColor = Colors.amber;
        statusIcon = '●';
      case SpotifyConnectionStatus.notConnected:
        statusColor = Colors.redAccent;
        statusIcon = '●';
    }
    final ts =
        '${e.timestamp.hour.toString().padLeft(2, '0')}:'
        '${e.timestamp.minute.toString().padLeft(2, '0')}:'
        '${e.timestamp.second.toString().padLeft(2, '0')}.'
        '${(e.timestamp.millisecond ~/ 10).toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ts,
            style: const TextStyle(
              color: Colors.grey,
              fontFamily: 'monospace',
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 6),
          Text(statusIcon, style: TextStyle(color: statusColor, fontSize: 11)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              e.message,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'monospace',
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _diagButton(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: _diagRunning
              ? Colors.teal.withOpacity(0.3)
              : Colors.teal.shade700,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          alignment: Alignment.centerLeft,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        onPressed: _diagRunning ? null : onPressed,
        icon: Icon(icon, color: Colors.white, size: 18),
        label: Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // -- Diagnostic action methods --

  void _diagDone(String result) {
    if (mounted) {
      setState(() {
        _diagLastResult = result;
        _diagRunning = false;
      });
    }
  }

  Future<void> _diagReset() async {
    if (_diagRunning) return;
    setState(() => _diagRunning = true);
    try {
      final repo = ref.read(spotifyRemoteRepositoryProvider);
      _diagDone(await repo.resetAll());
    } catch (e) {
      _diagDone('Error: $e');
    }
  }

  Future<void> _diagGetToken() async {
    if (_diagRunning) return;
    setState(() => _diagRunning = true);
    try {
      final repo = ref.read(spotifyRemoteRepositoryProvider);
      final ok = await repo.connectAccessToken();
      final t = repo.lastValidAccessToken;
      final prefix = t.substring(0, t.length.clamp(0, 12));
      _diagDone(
        ok
            ? 'Token OK  prefix=$prefix'
            : 'Token FAILED  error=${repo.lastConnectError}',
      );
    } catch (e) {
      _diagDone('Error: $e');
    }
  }

  Future<void> _diagConnectRemote() async {
    if (_diagRunning) return;
    setState(() => _diagRunning = true);
    try {
      final repo = ref.read(spotifyRemoteRepositoryProvider);
      final ok = await repo.connectToSpotifyRemote();
      _diagDone(
        ok
            ? 'Remote connected!'
            : 'Remote FAILED  error=${repo.lastConnectError}',
      );
    } catch (e) {
      _diagDone('Error: $e');
    }
  }

  Future<void> _diagFullConnect() async {
    if (_diagRunning) return;
    setState(() => _diagRunning = true);
    try {
      final repo = ref.read(spotifyRemoteRepositoryProvider);
      final ok = await repo.connect();
      _diagDone(
        ok
            ? 'Full connect OK'
            : 'Full connect FAILED  '
                  'hasToken=${repo.hasSpotifyAccessToken} '
                  'remote=${repo.isConnectedRemote}',
      );
    } catch (e) {
      _diagDone('Error: $e');
    }
  }

  Future<void> _diagForceReconnect() async {
    if (_diagRunning) return;
    setState(() => _diagRunning = true);
    try {
      final repo = ref.read(spotifyRemoteRepositoryProvider);
      final ok = await repo.forceFullReconnect();
      _diagDone(
        ok
            ? 'Force reconnect OK'
            : 'Force reconnect FAILED  error=${repo.lastConnectError}',
      );
    } catch (e) {
      _diagDone('Error: $e');
    }
  }

  Future<void> _diagPlay() async {
    if (_diagRunning) return;
    setState(() => _diagRunning = true);
    try {
      final repo = ref.read(spotifyRemoteRepositoryProvider);
      _diagDone(await repo.playTrack(_diagTestUriController.text.trim()));
    } catch (e) {
      _diagDone('Error: $e');
    }
  }

  Future<void> _diagSeek() async {
    if (_diagRunning) return;
    setState(() => _diagRunning = true);
    try {
      final repo = ref.read(spotifyRemoteRepositoryProvider);
      await repo.playTrackByUriAndJumpStart(
        _diagTestUriController.text.trim(),
        30000,
      );
      _diagDone('Play+seek to 30s done');
    } catch (e) {
      _diagDone('Error: $e');
    }
  }

  Future<void> _diagPause() async {
    if (_diagRunning) return;
    setState(() => _diagRunning = true);
    try {
      final repo = ref.read(spotifyRemoteRepositoryProvider);
      await repo.pausePlayer();
      _diagDone('Pause sent');
    } catch (e) {
      _diagDone('Error: $e');
    }
  }

  Future<void> _diagResume() async {
    if (_diagRunning) return;
    setState(() => _diagRunning = true);
    try {
      final repo = ref.read(spotifyRemoteRepositoryProvider);
      await repo.resumePlayer();
      _diagDone('Resume sent');
    } catch (e) {
      _diagDone('Error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Shared helpers
  // ---------------------------------------------------------------------------

  String spotifyUriValidate(String value) {
    if (value.isEmpty) return '';
    if (value.contains('https://open.spotify.com/playlist/')) {
      return value.substring('https://open.spotify.com/'.length);
    }
    if (value.contains('https://open.spotify.com/album/')) {
      return value.substring('https://open.spotify.com/'.length);
    }
    return value;
  }

  Widget globalInfoBox(BuildContext context, String label, Widget child) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).primaryColor, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).canvasColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).hintColor,
                letterSpacing: 0.8,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }

  Widget _sectionButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required bool disabled,
    required VoidCallback onPressed,
    bool destructive = false,
  }) {
    final color = destructive ? Colors.red : Theme.of(context).primaryColor;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: disabled ? color.withOpacity(0.3) : color,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          alignment: Alignment.centerLeft,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        onPressed: disabled ? null : onPressed,
        icon: Icon(icon, color: Colors.white, size: 20),
        label: Text(
          label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
