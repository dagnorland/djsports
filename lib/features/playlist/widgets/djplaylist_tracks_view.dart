// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:djsports/data/models/djplaylist_model.dart';
import 'package:djsports/data/models/djtrack_model.dart';
import 'package:djsports/data/provider/apple_music_provider.dart';
import 'package:djsports/data/repo/spotify_remote_repository.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class DJPlaylistTrackView extends HookConsumerWidget {
  final DJTrack track;
  final int counter;
  final DJPlaylistType playlistType;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const DJPlaylistTrackView({
    super.key,
    required this.track,
    this.counter = 1,
    required this.playlistType,
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
      final jumpStart = track.startTime + track.startTimeMS;
      if (track.appleMusicId.isNotEmpty) {
        ref.read(appleMusicRepositoryProvider).playTrackAndJumpStart(
          track, jumpStart, DJPlaylistType.hotspot, '',
        );
      } else if (track.spotifyUri.isNotEmpty) {
        ref.read(spotifyRemoteRepositoryProvider).playTrackAndJumpStart(
          track, jumpStart, DJPlaylistType.hotspot, '',
        );
      }
      // else: no playback source — silently ignore (track needs to be re-added)
    }

    Widget fallbackArt(double size) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        track.appleMusicId.isNotEmpty ? Icons.music_note : Icons.music_note,
        color: Colors.white54,
        size: size * 0.5,
      ),
    );

    Widget spotifySourceImage(double size) => Stack(
      alignment: Alignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: track.networkImageUri.isNotEmpty
              ? Image.network(
                  track.networkImageUri,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      track.appleMusicId.isEmpty
                          ? Image.asset(
                              ref
                                  .read(spotifyRemoteRepositoryProvider)
                                  .spotifyLogoFileName,
                              width: size,
                              height: size,
                              fit: BoxFit.cover,
                            )
                          : fallbackArt(size),
                )
              : (track.appleMusicId.isEmpty
                  ? Image.asset(
                      ref
                          .read(spotifyRemoteRepositoryProvider)
                          .spotifyLogoFileName,
                      width: size,
                      height: size,
                      fit: BoxFit.cover,
                    )
                  : fallbackArt(size)),
        ),
        Icon(Icons.play_arrow, size: size * 0.9, color: Colors.white),
      ],
    );

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
                  color: track.startTime + track.startTimeMS == 0
                      ? playlistType.color
                      : Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
              trailing: isWide
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: playTrack,
                          child: spotifySourceImage(44),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18),
                          onPressed: onEdit,
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete,
                            size: 18,
                            color: Colors.red,
                          ),
                          onPressed: () => confirmDelete(context),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: playTrack,
                          borderRadius: BorderRadius.circular(8),
                          child: spotifySourceImage(36),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18),
                          onPressed: onEdit,
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete,
                            size: 18,
                            color: Colors.red,
                          ),
                          onPressed: () => confirmDelete(context),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
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
