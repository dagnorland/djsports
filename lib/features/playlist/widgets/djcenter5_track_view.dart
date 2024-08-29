// ignore_for_file: public_member_api_docs, sort_constructors_first
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

    return Stack(
      children: [
        Card(child: getImageWidget(networkImageUri, size.width, size.height)),
        Center(
            child: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
          overflow: TextOverflow.ellipsis,
        )),
      ],
    );
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
