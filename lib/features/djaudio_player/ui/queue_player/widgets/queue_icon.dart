import 'package:audio_service/audio_service.dart';
import 'package:djsports/data/provider/audio_player_providers.dart';
import 'package:djsports/features/djaudio_player/ui/queue_player/widgets/queue_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class QueueIcon extends ConsumerWidget {
  const QueueIcon({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    bool shuffleModeIsNotEnable = ref.watch(
      audioPlayerProvider.select(
        (value) => value.shuffleMode != AudioServiceShuffleMode.all,
      ),
    );

    return GestureDetector(
      onTap: () {
        if (shuffleModeIsNotEnable) {
          showModalBottomSheet(
            context: context,
            builder: (context) => const QueueSheet(),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.0),
            ),
          );
        }
      },
      child: Icon(
        Icons.queue_music_outlined,
        color: shuffleModeIsNotEnable ? Colors.black : Colors.grey,
      ),
    );
  }
}
