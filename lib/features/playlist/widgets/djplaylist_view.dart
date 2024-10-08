// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:djsports/data/provider/djtrack_provider.dart';
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
        tileColor: Colors.black12.withOpacity(0.04),
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
                  width: isLandscape ? 400 : 350,
                  child: Text(
                    spotifyUri.isEmpty
                        ? 'No Spotify playlist link'
                        : isLandscape
                            ? spotifyUri
                            : spotifyUri.substring(0, 40),
                    maxLines: 1,
                  )),
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                padding: const EdgeInsets.only(
                    left: 1.0, right: 1.0), // Add padding around the Chip
                child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 40, // Set a minimum width for the Chip
                    ),
                    child: Chip(
                        backgroundColor: Theme.of(context).secondaryHeaderColor,
                        label: Text(spotifyUri.isEmpty ? 'mp3' : 'spotify')))),
            Container(
                padding: const EdgeInsets.only(
                    left: 1.0, right: 1.0), // Add padding around the Chip
                child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 20, // Set a minimum width for the Chip
                    ),
                    child: Chip(
                        label: Text(
                      type,
                      maxLines: 1,
                    )))),
            Container(
              padding: const EdgeInsets.only(left: 1.0, right: 1.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: 20, // Set a minimum width for the Chip
                ),
                child: Chip(
                  label: Text(trackIds.isEmpty
                      ? 'Empty'
                      : '#${trackIds.length.toString()}'),
                ),
              ),
            ),
            const SizedBox(width: 10),
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
    );
  }
}
