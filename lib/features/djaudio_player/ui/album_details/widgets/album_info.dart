import 'dart:io';

import 'package:flutter/material.dart';
import 'package:djsports/data/models/audio_player_album.dart';

class AlbumInfo extends StatelessWidget {
  const AlbumInfo({super.key, required this.album});

  final AudioPlayerAlbum album;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: album.path == null
                ? Image.asset(
                    'assets/images/default_music.png',
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  )
                : Image.file(
                    File(album.path!),
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          album.title,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 10),
        Text(
          album.artist,
          style: Theme.of(context).textTheme.headlineSmall,
        )
      ],
    );
  }
}
