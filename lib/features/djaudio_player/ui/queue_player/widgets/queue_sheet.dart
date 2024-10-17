import 'package:audio_service/audio_service.dart';
import 'package:djsports/data/provider/audio_player_providers.dart';
import 'package:djsports/features/djaudio_player/ui/queue_player/widgets/queue_song.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class QueueSheet extends ConsumerWidget {
  const QueueSheet({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(audioPlayerProvider.select((value) => value.queue));

    return ReorderableListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: queue.length,
      itemBuilder: (context, index) {
        final MediaItem song = queue[index];
        return QueueSong(
          key: ValueKey(index),
          song: song,
          index: index,
        );
      },
      onReorder: (oldIndex, newIndex) {
        if (oldIndex != newIndex) {
          ref
              .watch(audioPlayerProvider.notifier)
              .reOrderQueue(oldIndex, newIndex);
        }
      },
    );
  }
}
