import 'package:djsports/data/provider/audio_player_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SongInfo extends ConsumerWidget {
  const SongInfo({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final song =
        ref.watch(audioPlayerProvider.select((value) => value.currentSong));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        children: [
          Text(
            '${song?.title ?? ''}\n',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 20),
          Text(
            song?.album ?? '',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
