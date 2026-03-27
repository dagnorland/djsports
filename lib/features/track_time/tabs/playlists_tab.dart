import 'dart:convert';

import 'package:djsports/data/models/djplaylist_model.dart';
import 'package:djsports/data/provider/djplaylist_provider.dart';
import 'package:djsports/features/track_time/settings_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class PlaylistsTab extends StatefulHookConsumerWidget {
  const PlaylistsTab({super.key});

  @override
  ConsumerState<PlaylistsTab> createState() => _PlaylistsTabState();
}

class _PlaylistsTabState extends ConsumerState<PlaylistsTab> {
  final importPlaylistJsonDataController = TextEditingController();

  @override
  void initState() {
    super.initState();
    importPlaylistJsonDataController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    importPlaylistJsonDataController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<DJPlaylist> playlists =
        ref.watch(hivePlaylistData) ?? <DJPlaylist>[];
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          children: [
            globalInfoBox(
              context,
              'PLAYLISTS',
              _playlistSection(context, playlists),
            ),
            const Gap(20),
          ],
        ),
      ),
    );
  }

  Widget _playlistSection(BuildContext context, List<DJPlaylist> playlists) {
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
            'Copy all playlists data and share with others with djSports. You can send it by mail or direct message on Instagram or Facebook. '
            'When data is received they can paste it below and recreate the same playlists.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const Gap(16),
          sectionButton(
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
            'Paste playlist data here to import playlists into your library. Other users can share playlists data with you.',
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
                  '  {"playlistUri":"spotify:playlist:...",'
                  '"playlistType":"hotspot","name":"Goals"}\n'
                  ']',
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: Theme.of(context).primaryColor.withOpacity(0.05),
            ),
          ),
          const Gap(12),
          sectionButton(
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
                  ? 'Added $added playlist(s)'
                        '${skipped > 0 ? ', $skipped already existed' : ''}. '
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
}
