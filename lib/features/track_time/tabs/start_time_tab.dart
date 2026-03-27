import 'dart:convert';

import 'package:djsports/data/models/djtrack_model.dart';
import 'package:djsports/data/models/track_time_model.dart';
import 'package:djsports/data/provider/djtrack_provider.dart';
import 'package:djsports/data/provider/track_time_provider.dart';
import 'package:djsports/features/track_time/settings_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class StartTimeTab extends StatefulHookConsumerWidget {
  const StartTimeTab({super.key});

  @override
  ConsumerState<StartTimeTab> createState() => _StartTimeTabState();
}

class _StartTimeTabState extends ConsumerState<StartTimeTab> {
  final updateJsonDataController = TextEditingController();
  List<TrackTime> trackTimeList = [];
  int trackWithZeroStartTimeListLength = 0;

  @override
  void initState() {
    super.initState();
    updateJsonDataController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    updateJsonDataController.dispose();
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

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          children: [
            _infoSection(context),
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
              'UPDATE START TIMES LIST',
              _updateTrackTimesListSection(
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
          ],
        ),
      ),
    );
  }

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
                    'This list is local to your device. It is not synced with Spotify or other devices.'
                    'The list can be saved or emailed to yourself or others.'
                    'It is provided so you can save your start time work for later use.'
                    'Set a start time on a track (e.g. skip the intro) and export '
                    'the list to share with others. When someone updates the list with start times, '
                    'their tracks can be updated to start at the same position.\n\n'
                    'You can also back up and restore your track start times using the '
                    'Cloud Backup menu.',
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
          sectionButton(
            context,
            label:
                'Update the list with missing start times from tracks in your playlists.',
            icon: Icons.sync,
            disabled: djTrackWithStartTimeList.isEmpty,
            onPressed: () {
              _updateTrackTimeListWithMissingTracks(
                djTrackWithStartTimeList,
                trackTimeList,
              );
            },
          ),
          const Gap(10),
          sectionButton(
            context,
            label:
                'Copy to clipboard the list of tracks with start times as JSON  (${trackTimeList.length} tracks)',
            icon: Icons.copy,
            disabled: trackTimeList.isEmpty,
            onPressed: () {
              final bytes = _exportTrackTimeListToClipboard(trackTimeList);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Copied ${trackTimeList.length} track(s) with start times '
                      'as JSON data to clipboard  ($bytes bytes)',
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

  Widget _updateTrackTimesListSection(
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
            'If you want to restore track start times from a manual backup, paste the JSON data here.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Text(
            'You currently have ${trackTimeList.length} track start time(s) in the list.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const Gap(4),
          Text(
            'Paste a JSON list of start times data to update the list.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const Gap(10),
          TextField(
            controller: updateJsonDataController,
            maxLines: 10,
            decoration: InputDecoration(
              hintText:
                  'Paste JSON here, then press Update below\n\n'
                  'Example:\n${_exampleTrackTimeJson()}',
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: Theme.of(context).primaryColor.withOpacity(0.05),
            ),
          ),
          const Gap(16),
          sectionButton(
            context,
            label:
                'Update start times list with data pasted above from clipboard',
            icon: Icons.paste,
            disabled: updateJsonDataController.text.trim().isEmpty,
            onPressed: () {
              _updateTrackTimeListWithJsonData(
                updateJsonDataController.text.trim(),
              );
            },
          ),
          const Gap(10),
          sectionButton(
            context,
            label: 'Update all tracks with no start time from list',
            icon: Icons.update,
            disabled:
                trackTimeList.isEmpty || trackWithZeroStartTimeListLength == 0,
            onPressed: _applyStartTimesToTracksWithNoStartTime,
          ),
          const Gap(8),
        ],
      ),
    );
  }

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
          sectionButton(
            context,
            label: 'Delete list with track start times',
            icon: Icons.delete_forever,
            disabled: trackTimeList.isEmpty,
            destructive: true,
            onPressed: () {
              _deleteAllOrZeroTimeTrackTimes(trackTimeList, false);
            },
          ),
          const Gap(10),
          sectionButton(
            context,
            label: 'Delete entries with no start time',
            icon: Icons.delete_outline,
            disabled: trackTimeList.isEmpty,
            destructive: true,
            onPressed: () {
              _deleteAllOrZeroTimeTrackTimes(trackTimeList, true);
            },
          ),
          const Gap(8),
        ],
      ),
    );
  }

  void _updateTrackTimeListWithMissingTracks(
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
      trackTimeList = ref.read(dataTrackTimeProvider);
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            addedCount > 0
                ? 'Added $addedCount new track(s) to the export list'
                : 'No new tracks to add — all ${allTracks.length} already in '
                      'the list',
          ),
        ),
      );
    }
  }

  int _exportTrackTimeListToClipboard(List<TrackTime> trackTimeList) {
    final jsonString = jsonEncode(trackTimeList);
    Clipboard.setData(ClipboardData(text: jsonString));
    return jsonString.length;
  }

  String _exampleTrackTimeJson() {
    return '[\n'
        '  {"id":"6epn3r7S14KUqlReYr77hA","startTime":11000},\n'
        '  {"id":"4vVTI94F9uJ8lHNDWKv0i2","startTime":36000}\n'
        ']';
  }

  void _updateTrackTimeListWithJsonData(String jsonData) async {
    try {
      final dynamic decoded = json.decode(jsonData);
      if (decoded is! List) {
        throw const FormatException('JSON must be a list.');
      }
      final List<TrackTime> updatedTracks = [];

      for (final jsonItem in decoded) {
        if (jsonItem is! Map<String, dynamic>) {
          throw const FormatException('Each item must be an object.');
        }
        final trackTime = TrackTime.fromJson(jsonItem);
        updatedTracks.add(trackTime);
      }

      int added = 0;
      for (final trackTime in updatedTracks) {
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
        updateJsonDataController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              added > 0
                  ? 'Added $added track start time(s)'
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
                ? 'Updated $updatedCount track(s) with start times from the '
                      'list'
                : 'No matches found — none of the '
                      '${tracksWithNoStartTime.length} tracks without a start '
                      'time exist in the list',
          ),
        ),
      );
    }
  }

  void _deleteAllOrZeroTimeTrackTimes(
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
                ? 'Delete ${trackTimeList.where((t) => t.startTime == 0).length}'
                      ' entries that have no start time?'
                : 'Delete all ${trackTimeList.length} track start times from '
                      'the list?',
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
}
