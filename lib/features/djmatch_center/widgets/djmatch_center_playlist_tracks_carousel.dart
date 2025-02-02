// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:async';

import 'package:djsports/data/models/djplaylist_model.dart';
import 'package:djsports/data/models/djtrack_model.dart';
import 'package:djsports/data/provider/djplaylist_provider.dart';
import 'package:djsports/data/provider/djtrack_provider.dart';
import 'package:djsports/data/repo/spotify_remote_repository.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class DJCenterPlaylistTracksCarousel extends HookConsumerWidget {
  final String playlistId;
  final String playlistName;
  final DJPlaylistType playlistType;
  final String spotifyUri;
  final int currentTrack;
  final int parentWidthSize;

  const DJCenterPlaylistTracksCarousel({
    super.key,
    required this.playlistId,
    required this.playlistName,
    required this.playlistType,
    required this.spotifyUri,
    required this.currentTrack,
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

  String textConstraintSize(String text, int max) {
    if (text.length > max) {
      return '${text.substring(0, max - 3)}...';
    }
    return text;
  }

  Widget playButtonWidget(BuildContext context, WidgetRef ref, DJTrack djTrack,
      int trackIdIndex, int trackCount, DJPlaylistType playlistType) {
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
              '  #${trackIdIndex + 1}/$trackCount',
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
                  style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                      color: playlistType.color),
                )),
          Positioned(
            top: djTrack.startTime + djTrack.startTimeMS > 0 ? 15 : 15,
            left: -20,
            right: 0,
            child: IconButton(
              icon: const Icon(Icons.play_circle_fill, size: 65),
              color: playlistType.color,
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
    DJPlaylist playlist = ref.read(djPlaylistByIdProvider(playlistId));
    //playlist =
    //    ref.read(hivePlaylistData.notifier).shuffleTracksInPlaylist(playlistId);
    List<DJTrack> tracks =
        ref.watch(hiveTrackData.notifier).getDJTracks(playlist.trackIds);

    CarouselController carouselController = CarouselController();

    return CarouselView(
        scrollDirection: Axis.horizontal,
        itemExtent: double.infinity,
        controller: carouselController,
        //itemExtent: 305,
        shrinkExtent: 200,
        backgroundColor: Colors.white,
        onTap: (value) {
          DJTrack track = tracks[value];
          unawaited(ref
              .read(spotifyRemoteRepositoryProvider)
              .playTrackAndJumpStart(track, track.startTime + track.startTimeMS,
                  playlistType, playlistName));

          double newPosition = (value * 294) + 294;
          if (value == playlist.trackIds.length - 1) {
            newPosition = 0;
            if (playlist.shuffleAtEnd) {
              playlist = ref
                  .read(hivePlaylistData.notifier)
                  .shuffleTracksInPlaylist(playlistId);
              tracks = ref
                  .watch(hiveTrackData.notifier)
                  .getDJTracks(playlist.trackIds);
            }
          }
          carouselController.position.animateTo(newPosition,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOutCubicEmphasized);
        },
        children: List<Widget>.generate(tracks.length, (int trackIdIndex) {
          DJTrack djTrack = tracks[trackIdIndex];
          return LayoutBuilder(
            builder: (context, constraints) => Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  top: 25,
                  left: constraints.maxWidth * 0.47, // Relativ posisjonering
                  child: getImageWidget(djTrack.networkImageUri, 135, 135),
                ),
                Positioned(
                  top: 20,
                  left: 20,
                  child: SizedBox(
                    width: constraints.maxWidth * 0.4, // Begrens bredden
                    child: playButtonWidget(context, ref, djTrack, trackIdIndex,
                        playlist.trackIds.length, playlistType),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 20,
                  right: 20,
                  child: Container(
                    width: constraints.maxWidth - 40,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      playlistName.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 4,
                  left: 20,
                  right: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        djTrack.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          color: Colors.black,
                        ),
                      ),
                      Text(
                        textConstraintSize(djTrack.name, 29),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          backgroundColor: Colors.white70,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }));
  }
}
