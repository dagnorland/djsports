// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:djsports/data/models/djtrack_model.dart';
import 'package:djsports/data/provider/djtrack_provider.dart';
import 'package:djsports/data/repo/spotify_remote_repository.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class DJCenterTrackView extends HookConsumerWidget {
  final String playlistName;
  final String type;
  final String spotifyUri;
  final int currentTrack;
  final List<String> trackIds;
  final int parentWidthSize;

  const DJCenterTrackView({
    super.key,
    required this.playlistName,
    required this.type,
    required this.spotifyUri,
    required this.currentTrack,
    required this.trackIds,
    required this.parentWidthSize,
  });
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    CarouselController carouselController = CarouselController();
    return playlistWidget(context, ref, carouselController);
  }

  String textConstraintSize(String text, int max) {
    if (text.length > max) {
      return '${text.substring(0, max - 3)}...';
    }
    return text;
  }

  Widget playButtonWidget(
      BuildContext context, WidgetRef ref, DJTrack djTrack) {
    return Container(
      height: 45,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: const Icon(Icons.play_circle, size: 30),
        color: Colors.white,
        onPressed: () {
          debugPrint('playButtonWidget onPressed ${djTrack.name}');
          //ref.read(hiveTrackData.notifier).play(djTrack);
        },
      ),
    );
  }

  Widget getImageWidget(String networkImageUri, double width, double height) {
    return networkImageUri.isEmpty
        ? const Icon(Icons.featured_play_list_outlined, size: 100)
        : Image.network(networkImageUri,
            width: width, height: width, fit: BoxFit.cover);
  }

  Widget playlistWidget(BuildContext context, WidgetRef ref,
      CarouselController carouselController) {
    String networkImageUri = (ref.read(hiveTrackData.notifier).hasListeners)
        ? ref.read(hiveTrackData.notifier).getFirstNetworkImageUri(trackIds)
        : '';
    //final djTracks = ref.read(hiveTrackData.notifier).getDJTracks(trackIds);

    // get size of parent
    final size = MediaQuery.of(context).size;
    return CarouselView(
        controller: carouselController,
        itemExtent: 330,
        shrinkExtent: 200,
        onTap: (value) async {
          debugPrint('onTap $value');
          debugPrint(trackIds[value]);
          DJTrack track =
              ref.read(hiveTrackData.notifier).getDJTracks(trackIds)[value];
          ref.read(spotifyRemoteRepositoryProvider).playTrack(
              track.spotifyUri.isEmpty ? track.mp3Uri : track.spotifyUri);
          //double nextTrackNbr = value + 1;
          double newPosition = (value * 312) + 313;
          debugPrint('newPosition $newPosition');
          await carouselController.position.animateTo(newPosition,
              duration: const Duration(milliseconds: 250),
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
            getImageWidget(networkImageUri, size.width, size.height),
            Positioned(
              top: 25,
              left: 0,
              right: 0,
              child: Text(
                '   #${trackIdIndex + 1}/${trackIds.length}',
                style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    backgroundColor: Colors.black,
                    color: Colors.yellow),
              ),
            ),
            Positioned(
              top: 50,
              left: parentWidthSize / 2 - 150,
              right: 0,
              child: playButtonWidget(context, ref, djTrack),
            ),
            Container(
                padding: const EdgeInsets.only(left: 20, right: 10),
                decoration: BoxDecoration(
                  backgroundBlendMode: BlendMode.darken,
                  color: Colors.black,
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
                            color: Colors.yellow),
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
                      color: Colors.black,
                    ),
                    child: Text(
                      djTrack.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          color: Colors.yellow),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.only(left: 10, right: 10),
                    decoration: const BoxDecoration(
                      backgroundBlendMode: BlendMode.darken,
                      color: Colors.black,
                    ),
                    child: Row(children: [
                      const SizedBox(width: 10),
                      Text(
                        textConstraintSize(djTrack.name, 25),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            color: Colors.yellow),
                      ),
                    ]),
                  ),
                ]),
          ]);
        }));
  }

  Widget playlistWidgetOriginal(BuildContext context, WidgetRef ref) {
    String networkImageUri = (ref.read(hiveTrackData.notifier).hasListeners)
        ? ref.read(hiveTrackData.notifier).getFirstNetworkImageUri(trackIds)
        : '';

    Widget imageWidget = networkImageUri.isEmpty
        ? const SizedBox(
            width: 50,
            height: 50,
            child: Icon(Icons.featured_play_list_outlined, size: 50))
        : Image.network(networkImageUri,
            width: 45, height: 45, fit: BoxFit.cover);
    final djTracks = ref.read(hiveTrackData.notifier).getDJTracks(trackIds);

    return Container(
      color: Colors.yellowAccent,
      height: 50,
      width: 300,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: imageWidget,
          ),
          Column(children: [
            Text(
              playlistName,
              style: const TextStyle(fontWeight: FontWeight.w900),
              overflow: TextOverflow.ellipsis,
            ),
            Padding(
                padding: const EdgeInsets.only(top: 5.0),
                child: Text(
                  textConstraintSize(
                      '#${currentTrack + 1}  ${djTracks[currentTrack].name}',
                      50),
                  overflow: TextOverflow.fade,
                  style: const TextStyle(fontWeight: FontWeight.w400),
                  maxLines: 1,
                )),
          ]),
        ],
      ),
    );
  }
}
