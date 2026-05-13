import 'dart:io';

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
    this.onHardPause,
    this.onFadePause,
    this.fadeMs = 0,
    required this.onBack,
    required this.refreshCallback,
  });

  final VoidCallback onResume;
  final Future<void> Function() onPause;
  final Future<void> Function()? onHardPause;
  /// When non-null and [fadeMs] > 0, an extra fade pause button is shown.
  final Future<void> Function()? onFadePause;
  /// Fade duration in milliseconds — used for the tooltip / label.
  final int fadeMs;
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
            if (Platform.isIOS || Platform.isMacOS || Platform.isAndroid) ...[
              const Gap(4),
              IconButton(
                icon: const Icon(
                  Icons.open_in_new,
                  color: Color(0xFF1DB954),
                  size: 28,
                ),
                tooltip: 'Open Spotify',
                onPressed: () => ref
                    .read(spotifyRemoteRepositoryProvider)
                    .launchSpotify(),
              ),
            ],
            const Gap(12),
            ValueListenableBuilder<bool>(
              valueListenable: ref
                  .read(spotifyRemoteRepositoryProvider)
                  .silencePlayingNotifier,
              builder: (context, isSilence, _) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onLongPress: widget.onHardPause == null
                        ? null
                        : () async {
                            await widget.onHardPause!();
                            if (!context.mounted) return;
                            toastification.show(
                              context: context,
                              title: const Text('PAUSED'),
                              autoCloseDuration: const Duration(seconds: 2),
                              style: ToastificationStyle.flat,
                              alignment: Alignment.topCenter,
                            );
                          },
                    child: IconButton(
                      icon: Icon(
                        Icons.pause,
                        color: isSilence ? Colors.orange : Colors.white,
                        size: 70,
                      ),
                      splashColor: Colors.blue,
                      highlightColor: Colors.black,
                      onPressed: () async {
                        await widget.onPause();
                        final label = ref
                                .read(spotifyRemoteRepositoryProvider)
                                .silencePlayingNotifier
                                .value
                            ? 'SILENCE 🔇'
                            : 'PAUSED';
                        if (!context.mounted) return;
                        toastification.show(
                          context: context,
                          title: Text(label),
                          autoCloseDuration: const Duration(seconds: 2),
                          style: ToastificationStyle.flat,
                          alignment: Alignment.topCenter,
                        );
                      },
                    ),
                  ),
                  if (isSilence)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        '🔇 SILENCE',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  if (widget.onFadePause != null && widget.fadeMs > 0)
                    _FadePauseButton(
                      onFadePause: widget.onFadePause!,
                      fadeMs: widget.fadeMs,
                    ),
                ],
              ),
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
            lastTrack.maybeWhen(
              data: (track) {
                if (track == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: SizedBox(
                    width: 80,
                    child: Column(
                      children: [
                        Text(
                          track.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (track.artist.isNotEmpty)
                          Text(
                            track.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
              orElse: () => const SizedBox.shrink(),
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

/// Compact button that triggers [onFadePause] and disables itself while a
/// fade is already in progress (driven by
/// [SpotifyRemoteRepository.fadePausingNotifier]).
class _FadePauseButton extends ConsumerWidget {
  const _FadePauseButton({required this.onFadePause, required this.fadeMs});

  final Future<void> Function() onFadePause;
  final int fadeMs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(spotifyRemoteRepositoryProvider);
    return ValueListenableBuilder<bool>(
      valueListenable: repo.fadePausingNotifier,
      builder: (context, isFading, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Gap(4),
            Tooltip(
              message: isFading ? 'Fading…' : 'Fade pause ($fadeMs ms)',
              child: Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.pause_circle_outline,
                      color: isFading ? Colors.amber : Colors.amberAccent,
                      size: 46,
                    ),
                    onPressed: isFading
                        ? null
                        : () async {
                            await onFadePause();
                            if (!context.mounted) return;
                            toastification.show(
                              context: context,
                              title: Text('FADED ($fadeMs ms)'),
                              autoCloseDuration: const Duration(seconds: 2),
                              style: ToastificationStyle.flat,
                              alignment: Alignment.topCenter,
                            );
                          },
                  ),
                  Positioned(
                    bottom: 4,
                    child: Icon(
                      Icons.south,
                      size: 14,
                      color: isFading ? Colors.amber : Colors.amberAccent,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              'FADE',
              style: TextStyle(
                color: isFading ? Colors.amber : Colors.amberAccent,
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
          ],
        );
      },
    );
  }
}
