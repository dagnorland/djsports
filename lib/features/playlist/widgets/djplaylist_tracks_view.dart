// ignore_for_file: public_member_api_docs, sort_constructors_first
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

  String formatDuration(int durationInMilliseconds) {
    int seconds = durationInMilliseconds ~/ 1000;
    var minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    seconds = ((seconds % 60).toString().padLeft(2, '0')) as int;
    return '$minutes:$seconds';
  }

  String printDurationWithMS(Duration duration, int ms) {
    String result = printDuration(duration);
    if (ms > 0) {
      result += '.$ms';
    }
    return result;
  }

  String printDuration(Duration duration) {
    String twoDigits(int n) {
      if (n >= 10) return "$n";
      return "0$n";
    }

    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    } else {
      return "$twoDigitMinutes:$twoDigitSeconds";
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget leadingImage = track.networkImageUri.isEmpty
        ? const SizedBox(
            width: 50, height: 50, child: Icon(Icons.play_arrow, size: 50))
        : Stack(alignment: Alignment.center, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(track.networkImageUri,
                  width: 50, height: 50, fit: BoxFit.cover),
            ),
            const Icon(Icons.play_arrow, size: 45, color: Colors.black54),
          ]);

    Widget rowCountWithImage = Chip(
      backgroundColor: Theme.of(context).secondaryHeaderColor.withOpacity(0.4),
      label: Text(
        counter.toString(),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 2.0, right: 10),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
        child: ListTile(
          tileColor: Colors.black12.withOpacity(0.04),
          leading: rowCountWithImage,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                  child: Text(
                '${track.name} by ${track.artist}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w500),
              )),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Text(
                '${printDurationWithMS(Duration(milliseconds: track.startTime), track.startTimeMS)} - ${printDuration(Duration(milliseconds: track.duration))}'),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                  padding: const EdgeInsets.only(right: 20.0),
                  child: InkWell(
                      onTap: () {
                        ref.read(spotifyRemoteRepositoryProvider).playTrack(
                            track.spotifyUri.isEmpty
                                ? track.mp3Uri
                                : track.spotifyUri);
                      },
                      child: leadingImage)),
              Padding(
                  padding: const EdgeInsets.only(right: 20.0),
                  child: Chip(
                      backgroundColor: Theme.of(context).secondaryHeaderColor,
                      label:
                          Text(track.spotifyUri.isEmpty ? 'mp3' : 'spotify'))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor),
                onPressed: onEdit,
                child: Text(
                  'Edit',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall!
                      .copyWith(color: Colors.white),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor),
                onPressed: onDelete,
                child: Text(
                  'Delete',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall!
                      .copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
