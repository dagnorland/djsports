// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:djsports/data/models/djplaylist_model.dart';
import 'package:djsports/data/provider/djtrack_provider.dart';
import 'package:djsports/data/repo/spotify_remote_repository.dart';
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
  final void Function(String) onTypeChanged;
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
    required this.onTypeChanged,
  });

  Color get _typeColor => DJPlaylistType.values
      .firstWhere(
        (e) => e.name == type,
        orElse: () => DJPlaylistType.hotspot,
      )
      .color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = Theme.of(context).primaryColor;
    final typeColor = _typeColor;

    final networkImageUri = ref.read(hiveTrackData) != null
        ? ref.read(hiveTrackData.notifier).getFirstNetworkImageUri(trackIds)
        : '';

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
            errorBuilder: (_, __, ___) => SizedBox(
              width: size,
              height: size,
              child: Icon(
                Icons.cloud_off_outlined,
                size: size,
                color: Colors.grey.shade400,
              ),
            ),
          );

    Widget spotifySourceImage(double size) => networkImageUri.isEmpty
        ? SizedBox(
            width: size,
            height: size,
            child: Icon(Icons.play_arrow, size: size, color: Colors.black38),
          )
        : Stack(alignment: Alignment.center, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                ref
                    .read(spotifyRemoteRepositoryProvider)
                    .spotifyLogoFileName,
                width: size,
                height: size,
                fit: BoxFit.cover,
              ),
            ),
            Icon(Icons.play_arrow, size: size, color: Colors.black38),
          ]);

    final typeDropdown = Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: DropdownButton<String>(
        value: type,
        isDense: true,
        underline: const SizedBox(),
        isExpanded: true,
        items: DJPlaylistType.values
            .where((t) => t != DJPlaylistType.all)
            .map(
              (t) => DropdownMenuItem(
                value: t.name,
                child: Text(
                  t.name.toUpperCase(),
                  style: TextStyle(
                    color: t.color,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            )
            .toList(),
        onChanged: (v) {
          if (v != null) onTypeChanged(v);
        },
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
                spotifySource: spotifySourceImage(40),
                typeDropdown: typeDropdown,
                trackCountBadge: trackCountBadge,
                onEdit: onEdit,
                onDelete: () => confirmDelete(context),
                primary: primary,
              )
            : _NarrowContent(
                name: name,
                albumArt: albumArt(44),
                typeDropdown: typeDropdown,
                trackCountBadge: trackCountBadge,
                onEdit: onEdit,
                onDelete: () => confirmDelete(context),
                primary: primary,
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
  final Widget albumArt;
  final Widget typeDropdown;
  final Widget trackCountBadge;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Color primary;

  const _NarrowContent({
    required this.name,
    required this.albumArt,
    required this.typeDropdown,
    required this.trackCountBadge,
    required this.onEdit,
    required this.onDelete,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: albumArt,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
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
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(child: typeDropdown),
                    const SizedBox(width: 6),
                    trackCountBadge,
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.edit, size: 20),
                onPressed: onEdit,
                color: primary,
                visualDensity: VisualDensity.compact,
                tooltip: 'Edit',
              ),
              IconButton(
                icon: Icon(
                  Icons.delete,
                  size: 20,
                  color: Colors.red.shade400,
                ),
                onPressed: onDelete,
                visualDensity: VisualDensity.compact,
                tooltip: 'Delete',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WideContent extends StatelessWidget {
  final String name;
  final String spotifyUri;
  final Widget albumArt;
  final Widget spotifySource;
  final Widget typeDropdown;
  final Widget trackCountBadge;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Color primary;

  const _WideContent({
    required this.name,
    required this.spotifyUri,
    required this.albumArt,
    required this.spotifySource,
    required this.typeDropdown,
    required this.trackCountBadge,
    required this.onEdit,
    required this.onDelete,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    final uriDisplay = spotifyUri.length > 50
        ? spotifyUri.substring(0, 50)
        : spotifyUri;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: albumArt,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
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
                if (uriDisplay.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    uriDisplay,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          spotifySource,
          const SizedBox(width: 8),
          SizedBox(width: 150, child: typeDropdown),
          const SizedBox(width: 8),
          trackCountBadge,
          const SizedBox(width: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
            ),
            onPressed: onEdit,
            child: Text(
              'Edit',
              style: Theme.of(
                context,
              ).textTheme.titleSmall!.copyWith(color: Colors.white),
            ),
          ),
          const SizedBox(width: 6),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
            ),
            onPressed: onDelete,
            child: Text(
              'Delete',
              style: Theme.of(
                context,
              ).textTheme.titleSmall!.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
