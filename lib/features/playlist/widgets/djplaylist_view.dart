// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class DJPlaylistView extends HookConsumerWidget {
  final String name;
  final String type;
  final String spotifyUri;
  final List<String> trackIds;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const DJPlaylistView({
    super.key,
    required this.name,
    required this.type,
    required this.spotifyUri,
    required this.trackIds,
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
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        tileColor: Colors.black12.withOpacity(0.04),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                spotifyUri.isEmpty ? 'No Spotify playlist link' : spotifyUri,
              ),
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
                padding: const EdgeInsets.only(right: 20.0),
                child: Chip(
                    label: Text(
                  'Type:${type.toUpperCase()}',
                  maxLines: 1,
                ))),
            Padding(
                padding: const EdgeInsets.only(right: 20.0),
                child: Chip(
                    label: Text(trackIds.isEmpty
                        ? 'No tracks'
                        : 'Tracks:${trackIds.length.toString()}'))),
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
