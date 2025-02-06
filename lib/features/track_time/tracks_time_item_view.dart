// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:djsports/data/models/track_time_model.dart';
import 'package:djsports/data/repo/spotify_remote_repository.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class TrackTimeView extends HookConsumerWidget {
  final TrackTime track;
  final int counter;
  const TrackTimeView({
    super.key,
    required this.track,
    this.counter = 1,
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
      if (n >= 10) return '$n';
      return '0$n';
    }

    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return '${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds';
    } else {
      return '$twoDigitMinutes:$twoDigitSeconds';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                track.id,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w500),
              )),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Text(
                '${printDurationWithMS(Duration(milliseconds: track.startTime), 0)}))}'),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                  padding: const EdgeInsets.only(right: 20.0),
                  child: InkWell(
                      onTap: () {
                        ref
                            .read(spotifyRemoteRepositoryProvider)
                            .playTrackByUriAndJumpStart(
                                track.id, track.startTime);
                      },
                      child: const Icon(Icons.play_arrow, size: 24))),
            ],
          ),
        ),
      ),
    );
  }
}
