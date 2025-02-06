import 'package:djsports/data/repo/last_djtrack_played_repository.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class LastPlayedTrackWidget extends HookConsumerWidget {
  const LastPlayedTrackWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lastTrack = ref.watch(lastDjTrackPlayedProvider);

    return lastTrack.when(
      data: (track) => track == null
          ? const Text('Let the game begin!',
              style: TextStyle(color: Colors.white))
          : Text('Last track: ${track.name} by ${track.artist}',
              style: TextStyle(color: Colors.white)),
      loading: () => const CircularProgressIndicator(),
      error: (error, stack) => SelectableText.rich(
        TextSpan(
          text: 'Feil ved lasting av siste track: $error',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
    );
  }
}
