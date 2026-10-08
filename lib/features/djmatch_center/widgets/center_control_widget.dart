import 'dart:io';

import 'package:djsports/core/widgets/flashing_logo.dart';
import 'package:djsports/core/app_toast.dart';
import 'package:djsports/data/repo/last_djtrack_played_repository.dart';
import 'package:djsports/data/repo/spotify_remote_repository.dart';
import 'package:flutter/material.dart';
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
    this.onBack,
    this.trailing = const [],
    required this.refreshCallback,
    this.axis = Axis.vertical,
    this.showNowPlaying = true,
    this.foreground = Colors.white,
  });

  final VoidCallback onResume;
  final Future<void> Function() onPause;
  final Future<void> Function()? onHardPause;

  /// When non-null and [fadeMs] > 0, an extra fade pause button is shown.
  final Future<void> Function()? onFadePause;

  /// Fade duration in milliseconds — used for the tooltip / label.
  final int fadeMs;

  /// Shows a back (⌫) button at the end when set. Let's Play leaves it out
  /// and shows its own always-visible EXIT button instead.
  final VoidCallback? onBack;

  /// Extra buttons at the end of the scrollable part (e.g. help, log).
  final List<Widget> trailing;
  final VoidCallback? refreshCallback;

  /// [Axis.vertical] for a sidebar, [Axis.horizontal] for a bottom bar.
  final Axis axis;

  /// Shows the last played track's cover and name. Off while the
  /// now-playing panel shows the same thing.
  final bool showNowPlaying;

  /// Icon and text colour: white on a dark background, dark on a light one.
  final Color foreground;

  @override
  ConsumerState<CenterControlWidget> createState() =>
      _CenterControlWidgetState();
}

class _CenterControlWidgetState extends ConsumerState<CenterControlWidget> {
  @override
  Widget build(BuildContext context) {
    final lastTrack = ref.watch(lastDjTrackPlayedProvider);
    final packageInfo = useFuture(useMemoized(PackageInfo.fromPlatform));

    final axis = widget.axis;
    final foreground = widget.foreground;
    final muted = foreground.withValues(alpha: 0.7);
    return SingleChildScrollView(
      scrollDirection: axis,
      child: Padding(
        padding: axis == Axis.vertical
            ? const EdgeInsets.symmetric(vertical: 8)
            : const EdgeInsets.symmetric(horizontal: 8),
        child: Flex(
          direction: axis,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(Icons.play_arrow, color: foreground, size: 35),
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
                onPressed: () =>
                    ref.read(spotifyRemoteRepositoryProvider).launchSpotify(),
              ),
            ],
            const Gap(12),
            ValueListenableBuilder<bool>(
              valueListenable: ref
                  .read(spotifyRemoteRepositoryProvider)
                  .silencePlayingNotifier,
              builder: (context, isSilence, _) => Flex(
                direction: axis,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onLongPress: widget.onHardPause == null
                            ? null
                            : () async {
                                await widget.onHardPause!();
                                if (!context.mounted) return;
                                showAppToast(
                                  context,
                                  title: const Text('PAUSED'),
                                  duration: const Duration(seconds: 2),
                                );
                              },
                        child: IconButton(
                          icon: Icon(
                            Icons.pause,
                            color: isSilence ? Colors.orange : foreground,
                            size: 70,
                          ),
                          splashColor: Colors.blue,
                          highlightColor: Colors.black,
                          onPressed: () async {
                            await widget.onPause();
                            final label =
                                ref
                                    .read(spotifyRemoteRepositoryProvider)
                                    .silencePlayingNotifier
                                    .value
                                ? 'SILENCE 🔇'
                                : 'PAUSED';
                            if (!context.mounted) return;
                            showAppToast(
                              context,
                              title: Text(label),
                              duration: const Duration(seconds: 2),
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
                    ],
                  ),
                  if (widget.onFadePause != null && widget.fadeMs > 0)
                    _FadePauseButton(
                      onFadePause: widget.onFadePause!,
                      fadeMs: widget.fadeMs,
                      onLight: foreground.computeLuminance() < 0.5,
                    ),
                ],
              ),
            ),
            const Gap(12),
            IconButton(
              icon: Icon(Icons.volume_up, color: foreground, size: 50),
              onPressed: () =>
                  ref.read(spotifyRemoteRepositoryProvider).adjustVolume(0.05),
            ),
            const Gap(6),
            const CurrentVolumeWidget(
              key: Key('currentVolumeWidgetInCenterControlWidget'),
            ),
            const Gap(6),
            IconButton(
              icon: Icon(Icons.volume_down, color: foreground, size: 50),
              onPressed: () =>
                  ref.read(spotifyRemoteRepositoryProvider).adjustVolume(-0.05),
            ),
            if (widget.showNowPlaying) ...[
              const Gap(12),
              Flex(
                direction: axis,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 70,
                    height: 70,
                    child: lastTrack.when(
                      data: (track) => AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: ScaleTransition(
                            scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                              CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOut,
                              ),
                            ),
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
                        padding: axis == Axis.vertical
                            ? const EdgeInsets.only(top: 6)
                            : const EdgeInsets.only(left: 6),
                        child: SizedBox(
                          width: 80,
                          child: Column(
                            children: [
                              Text(
                                track.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: foreground,
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
                                  style: TextStyle(color: muted, fontSize: 10),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                    orElse: () => const SizedBox.shrink(),
                  ),
                ],
              ),
            ],
            const Gap(8),
            FlashingLogo(
              version: 'v${packageInfo.data?.version ?? '...'}',
              versionColor: muted,
            ),
            const Gap(8),
            if (widget.onBack != null)
              IconButton(
                icon: Icon(Icons.backspace, color: foreground),
                onPressed: widget.onBack,
              ),
            ...widget.trailing,
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
  const _FadePauseButton({
    required this.onFadePause,
    required this.fadeMs,
    required this.onLight,
  });

  final Future<void> Function() onFadePause;
  final int fadeMs;

  /// On a light background bright amber is unreadable – use a deeper one.
  final bool onLight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(spotifyRemoteRepositoryProvider);
    return ValueListenableBuilder<bool>(
      valueListenable: repo.fadePausingNotifier,
      builder: (context, isFading, _) {
        final color = onLight
            ? (isFading ? Colors.orange.shade900 : Colors.amber.shade800)
            : (isFading ? Colors.amber : Colors.amberAccent);
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
                      color: color,
                      size: 46,
                    ),
                    onPressed: isFading
                        ? null
                        : () async {
                            await onFadePause();
                            if (!context.mounted) return;
                            showAppToast(
                              context,
                              title: Text('FADED ($fadeMs ms)'),
                              duration: const Duration(seconds: 2),
                            );
                          },
                  ),
                  Positioned(
                    bottom: 4,
                    child: Icon(Icons.south, size: 14, color: color),
                  ),
                ],
              ),
            ),
            Text(
              'FADE',
              style: TextStyle(
                color: color,
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
