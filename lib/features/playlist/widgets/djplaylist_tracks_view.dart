// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:djsports/data/models/djtrack_model.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class DJPlaylistTrackView extends HookConsumerWidget {
  final DJTrack track;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const DJPlaylistTrackView({
    super.key,
    required this.track,
    required this.onEdit,
    required this.onDelete,
  });

  String formatDuration(int durationInMilliseconds) {
    int seconds = durationInMilliseconds ~/ 1000;
    var minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    seconds = ((seconds % 60).toString().padLeft(2, '0')) as int;
    return '$minutes:$seconds';
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
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: ListTile(
          tileColor: Colors.black12.withOpacity(0.04),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    track.name,
                    maxLines: 1,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'by ${track.artist}',
                    maxLines: 1,
                    style: const TextStyle(fontWeight: FontWeight.w300),
                  ),
                  // get the chip rightmost in the row
                ],
              ),
              // show type as chip
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text(
                    'Duration: ${printDuration(Duration(milliseconds: track.duration))}'),
                const SizedBox(width: 10),
                Text(
                    'Start: ${printDuration(Duration(milliseconds: track.startTime))},${(track.startTimeMS)}'),
              ],
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
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
