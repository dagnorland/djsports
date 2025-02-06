// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:djsports/data/provider/djtrack_provider.dart';
import 'package:djsports/data/repo/spotify_remote_repository.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class DJPlaylistView extends HookConsumerWidget {
  final String name;
  final String type;
  final String spotifyUri;
  final bool shuffleAtEnd;
  final bool autoNext;
  final int currentTrack;

  final List<String> trackIds;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const DJPlaylistView({
    super.key,
    required this.name,
    required this.type,
    required this.spotifyUri,
    required this.trackIds,
    required this.shuffleAtEnd,
    required this.autoNext,
    required this.currentTrack,
    required this.onEdit,
    required this.onDelete,
  });
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(children: [playlistWidget(context, ref)]),
    );
  }

  Widget playlistWidget(BuildContext context, WidgetRef ref) {
    bool isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    String networkImageUri = (ref.read(hiveTrackData.notifier).hasListeners)
        ? ref.read(hiveTrackData.notifier).getFirstNetworkImageUri(trackIds)
        : '';

    Widget musicSourceImage = networkImageUri.isEmpty
        ? const SizedBox(
            width: 50,
            height: 50,
            child: Icon(
              Icons.play_arrow,
              size: 45,
              color: Colors.black38,
            ))
        : Stack(alignment: Alignment.center, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                  ref.read(spotifyRemoteRepositoryProvider).spotifyLogoFileName,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover),
            ),
            const Icon(Icons.play_arrow, size: 45, color: Colors.black38),
          ]);

    Widget imageWidget = networkImageUri.isEmpty
        ? const SizedBox(
            width: 50,
            height: 50,
            child: Icon(Icons.featured_play_list_outlined, size: 50))
        : Image.network(networkImageUri,
            width: 50, height: 50, fit: BoxFit.cover);

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        tileColor: Colors.black12,
        leading: imageWidget,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text(
              name,
              maxLines: 1,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              SizedBox(
                  width: isLandscape ? 400 : 340,
                  child: Text(
                    spotifyUri.isEmpty
                        ? ''
                        : isLandscape
                            ? spotifyUri
                            : spotifyUri.length > 40
                                ? spotifyUri.substring(0, 40)
                                : spotifyUri,
                    maxLines: 1,
                  )),
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                SizedBox(
                    width: isLandscape ? 270 : 140,
                    child: Row(children: [
                      if (isLandscape)
                        Expanded(flex: 33, child: musicSourceImage),
                      Expanded(
                          flex: 35,
                          child: Chip(
                              label: Text(
                            type,
                            maxLines: 1,
                          ))),
                      Expanded(
                        flex: 33,
                        child: Chip(
                          label: Text(trackIds.isEmpty
                              ? 'Empty'
                              : '#${trackIds.length.toString()}'),
                        ),
                      )
                    ])),
              ],
            ),
            const SizedBox(width: 5),
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
            const SizedBox(width: 5),
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
    );
  }
}
