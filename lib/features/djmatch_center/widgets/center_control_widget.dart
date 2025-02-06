import 'package:djsports/data/repo/last_djtrack_played_repository.dart';
import 'package:djsports/data/repo/spotify_remote_repository.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:djsports/features/djmatch_center/widgets/current_volume_widget.dart';

class CenterControlWidget extends StatefulHookConsumerWidget {
  const CenterControlWidget({
    super.key,
    required this.onResume,
    required this.onPause,
    required this.onBack,
    required this.refreshCallback,
  });

  final VoidCallback onResume;
  final Future<void> Function() onPause;
  final VoidCallback onBack;
  final VoidCallback? refreshCallback;

  @override
  ConsumerState<CenterControlWidget> createState() =>
      _CenterControlWidgetState();
}

class _CenterControlWidgetState extends ConsumerState<CenterControlWidget> {
  @override
  Widget build(BuildContext context) {
    final lastTrack = ref.watch(lastDjTrackPlayedProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Gap(40),
        IconButton(
          icon: const Icon(Icons.play_arrow, color: Colors.white, size: 35),
          onPressed: widget.onResume,
        ),
        const Gap(30),
        IconButton(
          icon: const Icon(Icons.pause, color: Colors.white, size: 70),
          splashColor: Colors.blue,
          highlightColor: Colors.black,
          onPressed: () async => await widget.onPause(),
        ),
        const Gap(30),
        IconButton(
          icon: const Icon(Icons.volume_down, color: Colors.white, size: 50),
          onPressed: () =>
              ref.read(spotifyRemoteRepositoryProvider).adjustVolume(-0.1),
        ),
        const Gap(10),
        const CurrentVolumeWidget(
            key: Key('currentVolumeWidgetInCenterControlWidget')),
        const Gap(20),
        IconButton(
          icon: const Icon(Icons.volume_up, color: Colors.white, size: 70),
          onPressed: () =>
              ref.read(spotifyRemoteRepositoryProvider).adjustVolume(0.1),
        ),
        const Gap(20),
        Expanded(
          child: lastTrack.when(
            data: (track) => ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 70,
                  height: 70,
                  child: Image.network(
                    track?.networkImageUri ?? '',
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox.shrink(),
                  ),
                )),
            loading: () => const CircularProgressIndicator(),
            error: (error, stack) => const SizedBox.shrink(),
          ),
        ),
        Expanded(
            child: Image.asset(
          'assets/images/djsports/djsports_v12_round.png',
          width: 80,
          height: 80,
        )),
        IconButton(
          icon: const Icon(Icons.backspace),
          onPressed: widget.onBack,
        ),
        const Gap(20),
      ],
    );
  }
}
