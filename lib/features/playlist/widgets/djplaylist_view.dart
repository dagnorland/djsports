// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:djsports/data/models/djplaylist_model.dart';
import 'package:djsports/data/provider/djtrack_provider.dart';
import 'package:djsports/data/services/spotify_platform_bridge.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class DJPlaylistView extends HookConsumerWidget {
  final String name;
  final String type;
  final String spotifyUri;
  final bool shuffleAtEnd;
  final bool autoNext;
  final int currentTrack;

  final List<String> trackIds;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const DJPlaylistView({
    super.key,
    required this.name,
    required this.type,
    required this.spotifyUri,
    required this.trackIds,
    required this.shuffleAtEnd,
    required this.autoNext,
    required this.currentTrack,
    required this.onEdit,
    required this.onDelete,
  });

  Color get _typeColor => DJPlaylistType.values
      .firstWhere((e) => e.name == type, orElse: () => DJPlaylistType.hotspot)
      .color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = Theme.of(context).primaryColor;
    final typeColor = _typeColor;

    final networkImageUri = ref.read(hiveTrackData) != null
        ? ref.read(hiveTrackData.notifier).getFirstNetworkImageUri(trackIds)
        : '';

    final allTracks = ref.read(hiveTrackData) ?? [];
    final trackDots = trackIds.map((id) {
      final idx = allTracks.indexWhere((t) => t.id == id);
      if (idx < 0) return false;
      final startTime = allTracks[idx].startTime + allTracks[idx].startTimeMS;
      return startTime > 0;
    }).toList();

    Widget albumArt(double size) => networkImageUri.isEmpty
        ? SizedBox(
            width: size,
            height: size,
            child: Icon(
              Icons.featured_play_list_outlined,
              size: size,
              color: Colors.grey.shade400,
            ),
          )
        : Image.network(
            networkImageUri,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => SizedBox(
              width: size,
              height: size,
              child: Icon(
                Icons.cloud_off_outlined,
                size: size,
                color: Colors.grey.shade400,
              ),
            ),
          );

    final trackCountBadge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '#${trackIds.length}',
        style: TextStyle(
          color: primary,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );

    Future<void> confirmDelete(BuildContext ctx) async {
      final confirmed = await showDialog<bool>(
        context: ctx,
        builder: (dialogCtx) => AlertDialog(
          title: const Text('Delete Playlist'),
          content: Text(
            'Delete "$name"?\n\n'
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 500;

        Widget content = isWide
            ? _WideContent(
                name: name,
                spotifyUri: spotifyUri,
                albumArt: albumArt(46),
                trackCountBadge: trackCountBadge,
                trackDots: trackDots,
                dotColor: typeColor,
                onEdit: onEdit,
                onDelete: () => confirmDelete(context),
              )
            : _NarrowContent(
                name: name,
                spotifyUri: spotifyUri,
                albumArt: albumArt(44),
                trackCountBadge: trackCountBadge,
                trackDots: trackDots,
                dotColor: typeColor,
                onEdit: onEdit,
                onDelete: () => confirmDelete(context),
              );

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Card(
            elevation: 2,
            shadowColor: Colors.black12,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(width: 5, color: typeColor),
                    Expanded(child: content),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NarrowContent extends StatelessWidget {
  final String name;
  final String spotifyUri;
  final Widget albumArt;
  final Widget trackCountBadge;
  final List<bool> trackDots;
  final Color dotColor;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _NarrowContent({
    required this.name,
    required this.spotifyUri,
    required this.albumArt,
    required this.trackCountBadge,
    required this.trackDots,
    required this.dotColor,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          ClipRRect(borderRadius: BorderRadius.circular(8), child: albumArt),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                _TrackDots(dots: trackDots, color: dotColor),
              ],
            ),
          ),
          const SizedBox(width: 6),
          trackCountBadge,
          const SizedBox(width: 6),
          IconButton(
            icon: const Icon(Icons.edit, size: 18),
            onPressed: onEdit,
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
          _ActionsMenu(spotifyUri: spotifyUri, onDelete: onDelete),
        ],
      ),
    );
  }
}

class _WideContent extends StatelessWidget {
  final String name;
  final String spotifyUri;
  final Widget albumArt;
  final Widget trackCountBadge;
  final List<bool> trackDots;
  final Color dotColor;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _WideContent({
    required this.name,
    required this.spotifyUri,
    required this.albumArt,
    required this.trackCountBadge,
    required this.trackDots,
    required this.dotColor,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          ClipRRect(borderRadius: BorderRadius.circular(8), child: albumArt),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                _TrackDots(dots: trackDots, color: dotColor),
              ],
            ),
          ),
          const SizedBox(width: 10),
          trackCountBadge,
          const SizedBox(width: 10),
          IconButton(
            icon: const Icon(Icons.edit, size: 18),
            onPressed: onEdit,
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
          _ActionsMenu(spotifyUri: spotifyUri, onDelete: onDelete),
        ],
      ),
    );
  }
}

class _TrackDots extends StatelessWidget {
  const _TrackDots({required this.dots, required this.color});

  final List<bool> dots;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (dots.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 3,
      runSpacing: 3,
      children: dots
          .map(
            (hasTime) => Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: hasTime ? color : color.withOpacity(0.5),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _ActionsMenu extends StatelessWidget {
  const _ActionsMenu({required this.spotifyUri, required this.onDelete});

  final String spotifyUri;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (value) async {
        if (value == 'spotify') {
          final uri = 'spotify:playlist:$spotifyUri';
          debugPrint('[openSpotifyUri] $uri');
          try {
            await SpotifyPlatformBridge().openSpotifyUri(uri);
          } catch (e) {
            debugPrint('[openSpotifyUri] ERROR: $e');
          }
        }
        if (value == 'delete') onDelete();
      },
      itemBuilder: (_) => [
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
    );
  }
}
