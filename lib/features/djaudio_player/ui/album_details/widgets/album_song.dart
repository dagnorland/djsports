import 'package:audio_service/audio_service.dart';
import 'package:djsports/data/services/extensions.dart';
import 'package:flutter/material.dart';

class AlbumSong extends StatelessWidget {
  const AlbumSong({super.key, required this.song});

  final MediaItem song;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                song.title,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 10),
              Text(
                song.artist ?? '',
                style: Theme.of(context).textTheme.headlineSmall,
              )
            ],
          ),
        ),
        Text(
          song.duration?.format().toString() ?? '',
          style: Theme.of(context).textTheme.headlineSmall,
        )
      ],
    );
  }
}
