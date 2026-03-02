import 'package:djsports/data/repo/last_djtrack_played_repository.dart';
import 'package:djsports/data/repo/spotify_remote_repository.dart';
import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:djsports/features/djmatch_center/widgets/current_volume_widget.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

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
    final packageInfo = useFuture(useMemoized(PackageInfo.fromPlatform));

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.play_arrow, color: Colors.white, size: 35),
              onPressed: widget.onResume,
            ),
            const Gap(12),
            IconButton(
              icon: const Icon(Icons.pause, color: Colors.white, size: 70),
              splashColor: Colors.blue,
              highlightColor: Colors.black,
              onPressed: () async {
                await widget.onPause();
                toastification.show(
                  context: context,
                  title: const Text('PAUSED'),
                  autoCloseDuration: const Duration(seconds: 2),
                  style: ToastificationStyle.flat,
                  alignment: Alignment.bottomCenter,
                );
              },
            ),
            const Gap(12),
            IconButton(
              icon: const Icon(Icons.volume_up, color: Colors.white, size: 50),
              onPressed: () =>
                  ref.read(spotifyRemoteRepositoryProvider).adjustVolume(0.05),
            ),
            const Gap(6),
            const CurrentVolumeWidget(
              key: Key('currentVolumeWidgetInCenterControlWidget'),
            ),
            const Gap(6),
            IconButton(
              icon:
                  const Icon(Icons.volume_down, color: Colors.white, size: 50),
              onPressed: () =>
                  ref.read(spotifyRemoteRepositoryProvider).adjustVolume(-0.05),
            ),
            const Gap(12),
            SizedBox(
              width: 70,
              height: 70,
              child: lastTrack.when(
                data: (track) => AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.8, end: 1.0)
                          .animate(CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOut,
                      )),
                      child: child,
                    ),
                  ),
                  child: ClipRRect(
                    key: ValueKey(track?.spotifyUri ?? ''),
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      track?.networkImageUri ?? '',
                      width: 70,
                      height: 70,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const SizedBox(
                        width: 50,
                        height: 50,
                        child: Icon(
                          Icons.cloud_off_outlined,
                          size: 50,
                          color: Colors.black38,
                        ),
                      ),
                    ),
                  ),
                ),
                loading: () => const CircularProgressIndicator(),
                error: (error, stack) => const SizedBox.shrink(),
              ),
            ),
            const Gap(8),
            Column(
              children: [
                Image.asset(
                  'assets/images/djsports/djsports_v12_round.png',
                  width: 70,
                  height: 70,
                ),
                Text(
                  'v${packageInfo.data?.version ?? '...'}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.white70),
                ),
              ],
            ),
            const Gap(8),
            IconButton(
              icon: const Icon(Icons.backspace, color: Colors.white),
              onPressed: widget.onBack,
            ),
            const Gap(8),
          ],
        ),
      ),
    );
  }
}
