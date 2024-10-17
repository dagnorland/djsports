import 'dart:io';

import 'package:djsports/data/models/audio_player_album.dart';
import 'package:flutter/material.dart';

class AlbumWidget extends StatelessWidget {
  const AlbumWidget({super.key, required this.album});

  final AudioPlayerAlbum album;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: album.path == null
                ? Image.asset(
                    'assets/images/default_music.png',
                    fit: BoxFit.cover,
                  )
                : Image.file(
                    File(album.path!),
                    fit: BoxFit.cover,
                  ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    album.title,
                    maxLines: 2,
                    style: Theme.of(context).textTheme.headlineMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${album.songCount} Song',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
