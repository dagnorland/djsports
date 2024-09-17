// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:djsports/data/models/djtrack_model.dart';
import 'package:djsports/data/provider/djtrack_provider.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class DJCenterTrackView extends HookConsumerWidget {
  final String name;
  final String type;
  final String spotifyUri;
  final int currentTrack;
  final List<String> trackIds;

  const DJCenterTrackView({
    super.key,
    required this.name,
    required this.type,
    required this.spotifyUri,
    required this.currentTrack,
    required this.trackIds,
  });
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return playlistWidget(context, ref);
  }

  String textConstraintSize(String text, int max) {
    if (text.length > max) {
      return '${text.substring(0, max - 3)}...';
    }
    return text;
  }

  Widget getImageWidget(String networkImageUri, double width, double height) {
    return networkImageUri.isEmpty
        ? const Icon(Icons.featured_play_list_outlined, size: 100)
        : Image.network(networkImageUri,
            width: width, height: width, fit: BoxFit.cover);
  }

  Widget playlistWidget(BuildContext context, WidgetRef ref) {
    String networkImageUri = (ref.read(hiveTrackData.notifier).hasListeners)
        ? ref.read(hiveTrackData.notifier).getFirstNetworkImageUri(trackIds)
        : '';
    //final djTracks = ref.read(hiveTrackData.notifier).getDJTracks(trackIds);

    // get size of parent
    final size = MediaQuery.of(context).size;
    return CarouselView(
        itemExtent: 330,
        shrinkExtent: 200,
        children: List<Widget>.generate(trackIds.length, (int index) {
          DJTrack djTrack =
              ref.read(hiveTrackData.notifier).getDJTracks(trackIds)[index];
          if (djTrack.networkImageUri.isNotEmpty) {
            networkImageUri = djTrack.networkImageUri;
          }
          return Stack(children: [
            getImageWidget(networkImageUri, size.width, size.height),
            Center(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                  const SizedBox(height: 20),
                  Card(
                      shape: const RoundedRectangleBorder(
                          side: BorderSide(color: Colors.white)),
                      color: Colors.black.withOpacity(0.5),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(children: [
                          Text(
                            maxLines: 1,
                            name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: Colors.white),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            maxLines: 1,
                            djTrack.artist,
                            style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: Colors.white),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            maxLines: 1,
                            djTrack.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: Colors.white),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            maxLines: 1,
                            '${currentTrack + 1} of ${trackIds.length}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: Colors.white),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ]),
                      ))
                ]))
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
              name,
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
