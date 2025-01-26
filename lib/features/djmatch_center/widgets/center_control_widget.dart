import 'package:djsports/data/repo/spotify_remote_repository.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:djsports/features/djmatch_center/widgets/current_volume_widget.dart';

class CenterControlWidget extends ConsumerWidget {
  const CenterControlWidget({
    super.key,
    required this.onResume,
    required this.onPause,
    required this.onBack,
    required this.refreshCallback,
    required this.latestImageUri,
  });

  final VoidCallback onResume;
  final VoidCallback onPause;
  final VoidCallback onBack;
  final VoidCallback? refreshCallback;
  final String latestImageUri;

  Widget _getImageWidget(String networkImageUri, double width, double height) {
    return networkImageUri.isEmpty
        ? const Icon(Icons.featured_play_list_outlined, size: 10)
        : Image.network(
            networkImageUri,
            width: width,
            height: height,
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.error_outline),
          );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Gap(40),
        IconButton(
          icon: const Icon(Icons.play_arrow, color: Colors.white, size: 35),
          onPressed: onResume,
        ),
        const Gap(30),
        IconButton(
          icon: const Icon(Icons.pause, color: Colors.white, size: 70),
          splashColor: Colors.blue,
          highlightColor: Colors.black,
          onPressed: onPause,
        ),
        const Gap(30),
        IconButton(
          icon: const Icon(Icons.volume_down, color: Colors.white, size: 50),
          onPressed: () =>
              ref.read(spotifyRemoteRepositoryProvider).adjustVolume(-0.1),
        ),
        const Gap(10),
        const CurrentVolumeWidget(),
        const Gap(20),
        IconButton(
          icon: const Icon(Icons.volume_up, color: Colors.white, size: 70),
          onPressed: () =>
              ref.read(spotifyRemoteRepositoryProvider).adjustVolume(0.1),
        ),
        const Gap(20),
        Expanded(
          child: _getImageWidget(latestImageUri, 50, 50),
        ),
        IconButton(
          icon: const Icon(Icons.backspace),
          onPressed: onBack,
        ),
        const Gap(20),
      ],
    );
  }
}
