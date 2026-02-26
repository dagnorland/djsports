import 'package:djsports/data/repo/spotify_remote_repository.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class CurrentVolumeWidget extends ConsumerWidget {
  const CurrentVolumeWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(spotifyRemoteRepositoryProvider);
    return ValueListenableBuilder<double>(
      valueListenable: repo.volumeNotifier,
      builder: (context, volume, child) {
        return Chip(
          label: Text('${(volume * 100).toStringAsFixed(0)}%'),
        );
      },
    );
  }
}
