import 'package:djsports/core/theme/stage_colors.dart';
import 'package:djsports/data/models/djplaylist_model.dart';
import 'package:djsports/data/models/djtrack_model.dart';
import 'package:djsports/data/provider/djtrack_provider.dart';
import 'package:djsports/data/services/spotify_platform_bridge.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// A playlist on the home page, Spotify-style: a square cover (a 2×2
/// mosaic of the first four different covers), a round edit button in the
/// type colour, a ⋮ menu, and the name with track counts below.
/// Fills the width it gets; tap anywhere to edit.
class PlaylistCard extends ConsumerWidget {
  const PlaylistCard({
    super.key,
    required this.playlist,
    required this.onEdit,
    required this.onDelete,
  });

  final DJPlaylist playlist;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  /// Text below the cover: two lines of title + one line of counts.
  static const textHeight = 64.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final type = DJPlaylistType.values.firstWhere(
      (t) => t.name == playlist.type,
      orElse: () => DJPlaylistType.hotspot,
    );
    final typeColor = stageTypeColor(type.color, context);

    final tracksById = {
      for (final t in ref.watch(hiveTrackData) ?? const <DJTrack>[]) t.id: t,
    };
    final tracks = [
      for (final id in playlist.trackIds)
        if (tracksById[id] != null) tracksById[id]!,
    ];
    final covers = <String>[];
    for (final t in tracks) {
      final uri = t.networkImageUri;
      if (uri.isNotEmpty && !covers.contains(uri)) covers.add(uri);
      if (covers.length == 4) break;
    }
    final withStart = tracks
        .where((t) => t.startTime + t.startTimeMS > 0)
        .length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth;
        final button = (size * 0.24).clamp(32.0, 46.0);
        return InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox.square(
                dimension: size,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _Cover(covers: covers, color: typeColor),
                      ),
                    ),
                    // Type colour along the bottom edge of the cover.
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: typeColor,
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: _CardMenu(
                        spotifyUri: playlist.spotifyUri,
                        onDelete: () => _confirmDelete(context),
                      ),
                    ),
                    Positioned(
                      right: 8,
                      bottom: 12,
                      child: Material(
                        color: typeColor,
                        shape: const CircleBorder(),
                        elevation: 4,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: onEdit,
                          child: SizedBox.square(
                            dimension: button,
                            child: Icon(
                              Icons.edit_rounded,
                              color: Colors.white,
                              size: button * 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: textHeight - 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playlist.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      withStart > 0
                          ? '${tracks.length} tracks · $withStart with start'
                          : '${tracks.length} tracks',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: StageColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete Playlist'),
        content: Text(
          'Delete "${playlist.name}"?\n\n'
          'This will permanently remove the playlist and all its tracks.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) onDelete();
  }
}

/// One cover, or a 2×2 mosaic when there are four different ones.
class _Cover extends StatelessWidget {
  const _Cover({required this.covers, required this.color});

  final List<String> covers;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (covers.isEmpty) {
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withValues(alpha: 0.6), StageColors.surfaceHigh],
          ),
        ),
        child: const Center(
          child: Icon(Icons.queue_music, size: 48, color: Colors.white54),
        ),
      );
    }
    if (covers.length < 4) return _image(covers.first);
    return Column(
      children: [
        for (final row in [covers.sublist(0, 2), covers.sublist(2, 4)])
          Expanded(
            child: Row(
              children: [
                for (final uri in row) Expanded(child: _image(uri)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _image(String uri) => Image.network(
    uri,
    fit: BoxFit.cover,
    width: double.infinity,
    height: double.infinity,
    errorBuilder: (_, _, _) => const ColoredBox(
      color: StageColors.surfaceHigh,
      child: Center(child: Icon(Icons.cloud_off, color: Colors.white24)),
    ),
  );
}

class _CardMenu extends StatelessWidget {
  const _CardMenu({required this.spotifyUri, required this.onDelete});

  final String spotifyUri;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      shape: const CircleBorder(),
      child: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, color: Colors.white, size: 18),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        style: IconButton.styleFrom(
          minimumSize: const Size(30, 30),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        tooltip: 'More',
        onSelected: (value) async {
          if (value == 'spotify') {
            try {
              await SpotifyPlatformBridge().openSpotifyUri(
                'spotify:playlist:$spotifyUri',
              );
            } catch (e) {
              debugPrint('[openSpotifyUri] ERROR: $e');
            }
          }
          if (value == 'delete') onDelete();
        },
        itemBuilder: (_) => [
          if (spotifyUri.isNotEmpty)
            const PopupMenuItem(
              value: 'spotify',
              child: Row(
                children: [
                  Icon(Icons.open_in_new, size: 18),
                  SizedBox(width: 10),
                  Text('Open in Spotify'),
                ],
              ),
            ),
          const PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete, size: 18, color: Colors.red),
                SizedBox(width: 10),
                Text('Delete', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
