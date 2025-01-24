// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:djsports/data/models/djtrack_model.dart';
import 'package:djsports/data/provider/djtrack_provider.dart';
import 'package:djsports/data/repo/spotify_remote_repository.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class DJCenterPlaylistTracksCarousel extends HookConsumerWidget {
  final String playlistName;
  final String playlistType;
  final String spotifyUri;
  final int currentTrack;
  final List<String> trackIds;
  final int parentWidthSize;

  const DJCenterPlaylistTracksCarousel({
    super.key,
    required this.playlistName,
    required this.playlistType,
    required this.spotifyUri,
    required this.currentTrack,
    required this.trackIds,
    required this.parentWidthSize,
  });

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

  String textConstraintSize(String text, int max) {
    if (text.length > max) {
      return '${text.substring(0, max - 3)}...';
    }
    return text;
  }

  Widget playButtonWidget(
      BuildContext context, WidgetRef ref, DJTrack djTrack, int trackIdIndex) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(children: [
          const SizedBox(width: 90, height: 100),
          Positioned(
            top: 5,
            left: 0,
            right: 0,
            child: Text(
              maxLines: 1,
              '  #${trackIdIndex + 1}/${trackIds.length}',
              style: const TextStyle(
                  fontWeight: FontWeight.w400,
                  fontSize: 16,
                  color: Colors.black),
            ),
          ),
          if (djTrack.startTime + djTrack.startTimeMS > 0)
            Positioned(
                top: 80,
                left: 18,
                child: Text(
                  printDurationWithMS(Duration(milliseconds: djTrack.startTime),
                      djTrack.startTimeMS),
                  textAlign: TextAlign.start,
                  style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                      color: Colors.black),
                )),
          Positioned(
            top: djTrack.startTime + djTrack.startTimeMS > 0 ? 16 : 23,
            left: -20,
            right: 0,
            child: IconButton(
              icon: const Icon(Icons.play_circle_fill, size: 60),
              color: Colors.black,
              onPressed: () {
                //ref.read(hiveTrackData.notifier).resumePlayer();
              },
            ),
          ),
        ])
      ],
    );
  }

  Widget getImageWidget(String networkImageUri, double width, double height) {
    return networkImageUri.isEmpty
        ? const Icon(Icons.featured_play_list_outlined, size: 100)
        : Image.network(networkImageUri, width: width, height: height);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    CarouselController carouselController = CarouselController();
    String networkImageUri = (ref.read(hiveTrackData.notifier).hasListeners)
        ? ref.read(hiveTrackData.notifier).getFirstNetworkImageUri(trackIds)
        : '';

    return CarouselView(
        controller: carouselController,
        itemExtent: 330,
        shrinkExtent: 200,
        backgroundColor: Colors.white,
        onTap: (value) {
          DJTrack track =
              ref.read(hiveTrackData.notifier).getDJTracks(trackIds)[value];
          ref.read(spotifyRemoteRepositoryProvider).playTrackAndJumpStart(track,
              track.startTime + track.startTimeMS, playlistType, playlistName);

          double newPosition = (value * 315) + 315;
          if (value == trackIds.length - 1) {
            newPosition = 0;
          }
          carouselController.position.animateTo(newPosition,
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeInOutCubicEmphasized);
        },
        children: List<Widget>.generate(trackIds.length, (int trackIdIndex) {
          DJTrack djTrack = ref
              .read(hiveTrackData.notifier)
              .getDJTracks(trackIds)[trackIdIndex];
          if (djTrack.networkImageUri.isNotEmpty) {
            networkImageUri = djTrack.networkImageUri;
          }
          return Stack(children: [
            Positioned(
              top: 20,
              left: 130, //parentWidthSize / 2 - 150,
              right: 0,
              child: getImageWidget(networkImageUri, 125, 125),
            ),
            Positioned(
              top: 20,
              left: 0, //parentWidthSize / 2 - 150,
              right: 0,
              child: playButtonWidget(context, ref, djTrack, trackIdIndex),
            ),
            Container(
                padding: const EdgeInsets.only(left: 20, right: 10),
                decoration: BoxDecoration(
                  backgroundBlendMode: BlendMode.darken,
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(2),
                ),
                child: RichText(
                  maxLines: 1,
                  text: TextSpan(
                    style: DefaultTextStyle.of(context).style,
                    children: [
                      TextSpan(
                        text: playlistName.toUpperCase(),
                        style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            color: Colors.black),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 20),
            Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.only(left: 10, right: 10),
                    decoration: const BoxDecoration(
                      backgroundBlendMode: BlendMode.darken,
                      color: Colors.white,
                    ),
                    child: Text(
                      djTrack.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          color: Colors.black),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.only(left: 10, right: 10),
                    decoration: const BoxDecoration(
                        //backgroundBlendMode: BlendMode.darken,
                        //color: Colors.white,
                        ),
                    child: Row(children: [
                      const SizedBox(width: 10),
                      Text(
                        textConstraintSize(djTrack.name, 25),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            backgroundColor: Colors.white.withOpacity(0.4),
                            color: Colors.black),
                      ),
                    ]),
                  ),
                ]),
          ]);
        }));
  }
}
