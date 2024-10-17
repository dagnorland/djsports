import 'package:djsports/data/provider/audio_player_providers.dart';
import 'package:djsports/features/djaudio_player/ui/home/widgets/song_widget.dart';
import 'package:djsports/features/djaudio_player/ui/queue_player/queue_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SongsPage extends ConsumerWidget {
  const SongsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songs = ref.watch(songsProvider);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: songs.length,
      itemExtent: 85,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () async {
            await ref
                .watch(audioPlayerProvider.notifier)
                .startPlayList(songs, index);
            if (context.mounted) {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const QueuePlayerScreen()));
            }
          },
          child: SongWidget(song: songs[index]),
        );
      },
    );
  }
}
