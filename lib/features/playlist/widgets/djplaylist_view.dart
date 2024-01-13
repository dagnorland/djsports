// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class DJPlaylistView extends HookConsumerWidget {
  final String name;
  final String type;
  final String spotifyUri;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const DJPlaylistView({
    super.key,
    required this.name,
    required this.type,
    required this.spotifyUri,
    required this.onEdit,
    required this.onDelete,
  });
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
              Text(
                name,
                maxLines: 1,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              Text(
                type,
                maxLines: 1,
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
                  spotifyUri,
                ),
                Text(
                  name,
                ),
              ],
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                  onPressed: onEdit,
                  icon: const Icon(
                    Icons.edit,
                    color: Colors.black,
                  )),
              IconButton(
                  onPressed: onDelete,
                  icon: const Icon(
                    Icons.delete,
                    color: Colors.red,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}
