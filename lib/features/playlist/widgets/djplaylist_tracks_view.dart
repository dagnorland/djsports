// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:djsports/data/models/djplaylist_model.dart';
import 'package:djsports/data/models/djtrack_model.dart';
import 'package:djsports/data/repo/spotify_remote_repository.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class DJPlaylistTrackView extends HookConsumerWidget {
  final DJTrack track;
  final int counter;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const DJPlaylistTrackView({
    super.key,
    required this.track,
    this.counter = 1,
    required this.onEdit,
    required this.onDelete,
  });

  String printDurationWithMS(Duration duration, int ms) {
    final result = printDuration(duration);
    return ms > 0 ? '$result.$ms' : result;
  }

  String printDuration(Duration duration) {
    String two(int n) => n >= 10 ? '$n' : '0$n';
    final mm = two(duration.inMinutes.remainder(60));
    final ss = two(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) return '${two(duration.inHours)}:$mm:$ss';
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = Theme.of(context).primaryColor;

    Future<void> confirmDelete(BuildContext ctx) async {
      final confirmed = await showDialog<bool>(
        context: ctx,
        builder: (dialogCtx) => AlertDialog(
          title: const Text('Remove Track'),
          content: Text(
            'Remove "${track.name}" by ${track.artist}?\n\n'
            'The track will be removed from this playlist.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('Remove'),
            ),
          ],
        ),
      );
      if (confirmed == true) onDelete();
    }

    void playTrack() {
      ref.read(spotifyRemoteRepositoryProvider).playTrackAndJumpStart(
            track,
            track.startTime + track.startTimeMS,
            DJPlaylistType.hotspot,
            '',
          );
    }

    Widget trackImage(double size) => track.networkImageUri.isEmpty
        ? SizedBox(
            width: size,
            height: size,
            child: Icon(
              Icons.music_note,
              size: size * 0.65,
              color: Colors.grey.shade400,
            ),
          )
        : ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              track.networkImageUri,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  SizedBox(
                    width: size,
                    height: size,
                    child: Icon(
                      Icons.cloud_off_outlined,
                      size: size,
                      color: Colors.grey.shade400,
                    ),
                  ),
            ),
          );

    Widget spotifySourceImage(double size) => track.networkImageUri.isEmpty
        ? SizedBox(
            width: size,
            height: size,
            child: Icon(
              Icons.play_arrow,
              size: size * 0.9,
              color: Colors.black38,
            ),
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
            Icon(
              Icons.play_arrow,
              size: size * 0.9,
              color: Colors.black38,
            ),
          ]);

    final counterBadge = Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: primary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        counter.toString(),
        style: TextStyle(
          color: primary,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );

    final subtitleText =
        '${printDurationWithMS(Duration(milliseconds: track.startTime), track.startTimeMS)}'
        ' — ${printDuration(Duration(milliseconds: track.duration))}';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 500;
        return Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Card(
            elevation: 1,
            shadowColor: Colors.black12,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 2,
              ),
              tileColor: Colors.grey.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              leading: counterBadge,
              title: Text(
                '${track.name} by ${track.artist}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              subtitle: Text(
                subtitleText,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
              trailing: isWide
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(onTap: playTrack, child: trackImage(44)),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: playTrack,
                          child: spotifySourceImage(44),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primary,
                          ),
                          onPressed: onEdit,
                          child: Text(
                            'Edit',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall!
                                .copyWith(color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 6),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primary,
                          ),
                          onPressed: () => confirmDelete(context),
                          child: Text(
                            'Delete',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall!
                                .copyWith(color: Colors.white),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: playTrack,
                          borderRadius: BorderRadius.circular(8),
                          child: trackImage(36),
                        ),
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
                          onPressed: () => confirmDelete(context),
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Delete',
                        ),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }
}
