import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:djsports/data/models/web_player_state.dart';
import 'package:djsports/core/theme/stage_colors.dart';
import 'package:djsports/data/repo/spotify_remote_repository.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

const _minHeight = 72.0;
const _collapsedHeight = 30.0;
const _handleHeight = 8.0;

/// Puts a now-playing panel for djSports' own Spotify player (macOS web
/// player) below every screen. Used from `MaterialApp.builder`; shown only
/// while that player is the active Spotify device.
class WebPlayerPanelHost extends ConsumerWidget {
  const WebPlayerPanelHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!Platform.isMacOS) return child;
    final repo = ref.read(spotifyRemoteRepositoryProvider);
    return ValueListenableBuilder<WebPlayerState?>(
      valueListenable: repo.webPlayerStateNotifier,
      builder: (context, state, _) => Column(
        children: [
          Expanded(child: child),
          if (state != null) const _PanelArea(),
        ],
      ),
    );
  }
}

/// Sizes the panel (collapsed bar or chosen height). The panel lives
/// outside the Navigator, so it brings its own Overlay for tooltips and
/// the slider.
class _PanelArea extends ConsumerStatefulWidget {
  const _PanelArea();

  @override
  ConsumerState<_PanelArea> createState() => _PanelAreaState();
}

class _PanelAreaState extends ConsumerState<_PanelArea> {
  final _entry = OverlayEntry(builder: (_) => const _Panel());

  @override
  void dispose() {
    _entry.remove();
    _entry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(spotifyRemoteRepositoryProvider);
    return ListenableBuilder(
      listenable: Listenable.merge([
        repo.webPlayerPanelVisibleNotifier,
        repo.webPlayerPanelHeightNotifier,
      ]),
      builder: (context, _) => SizedBox(
        height: repo.webPlayerPanelVisibleNotifier.value
            ? _clampHeight(context, repo.webPlayerPanelHeightNotifier.value)
            : _collapsedHeight,
        child: Overlay(initialEntries: [_entry]),
      ),
    );
  }
}

double _clampHeight(BuildContext context, double height) {
  final max = MediaQuery.sizeOf(context).height * 0.7;
  return height.clamp(_minHeight, math.max(_minHeight, max));
}

class _Panel extends ConsumerWidget {
  const _Panel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(spotifyRemoteRepositoryProvider);
    return ListenableBuilder(
      listenable: Listenable.merge([
        repo.webPlayerStateNotifier,
        repo.webPlayerPanelVisibleNotifier,
      ]),
      builder: (context, _) {
        final state = repo.webPlayerStateNotifier.value;
        if (state == null) return const SizedBox.shrink();
        final content = repo.webPlayerPanelVisibleNotifier.value
            ? Column(
                children: [
                  const _ResizeHandle(),
                  Expanded(child: _NowPlaying(state: state)),
                ],
              )
            : _CollapsedBar(state: state);
        // Always dark, like Spotify's now-playing bar.
        return Theme(
          data: StageColors.theme(Theme.of(context)),
          child: Material(
            color: StageColors.panel,
            shape: const Border(top: BorderSide(color: StageColors.divider)),
            child: content,
          ),
        );
      },
    );
  }
}

class _CollapsedBar extends ConsumerWidget {
  const _CollapsedBar({required this.state});

  final WebPlayerState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(spotifyRemoteRepositoryProvider);
    return InkWell(
      onTap: () => repo.setWebPlayerPanelVisible(true),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Icon(state.paused ? Icons.pause : Icons.music_note, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                [
                  state.name,
                  if (state.artists.isNotEmpty) state.artists,
                ].join('  •  '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.expand_less, size: 18),
          ],
        ),
      ),
    );
  }
}

/// Drag up/down to resize; the height is saved when the drag ends.
class _ResizeHandle extends ConsumerWidget {
  const _ResizeHandle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(spotifyRemoteRepositoryProvider);
    final notifier = repo.webPlayerPanelHeightNotifier;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeRow,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: (details) => repo.setWebPlayerPanelHeight(
          _clampHeight(context, notifier.value - details.delta.dy),
        ),
        onVerticalDragEnd: (_) =>
            repo.setWebPlayerPanelHeight(notifier.value, persist: true),
        child: SizedBox(
          height: _handleHeight,
          child: Center(
            child: Container(
              width: 40,
              height: 3,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NowPlaying extends ConsumerWidget {
  const _NowPlaying({required this.state});

  final WebPlayerState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(spotifyRemoteRepositoryProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        // Everything grows with the panel height.
        final compact = h < 110;
        final artSize = (h - 12).clamp(32.0, 280.0);
        final titleSize = (h / 7).clamp(13.0, 30.0);
        final buttonSize = (h / 2.4).clamp(28.0, 72.0);
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 8, 8),
          child: Row(
            children: [
              _Cover(url: state.imageUrl, size: artSize),
              const SizedBox(width: 12),
              Expanded(
                child: ClipRect(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: titleSize,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        state.artists,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: titleSize * 0.75),
                      ),
                      if (!compact && state.album.isNotEmpty)
                        Text(
                          state.album,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: titleSize * 0.6,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      const SizedBox(height: 4),
                      _Progress(state: state, compact: compact),
                    ],
                  ),
                ),
              ),
              IconButton(
                iconSize: buttonSize,
                color: Theme.of(context).colorScheme.secondary,
                tooltip: state.paused ? 'Resume' : 'Pause',
                icon: Icon(
                  state.paused
                      ? Icons.play_circle_fill
                      : Icons.pause_circle_filled,
                ),
                onPressed: () =>
                    state.paused ? repo.resumePlayer() : repo.pausePlayer(),
              ),
              IconButton(
                tooltip: 'Hide player',
                icon: const Icon(Icons.expand_more),
                onPressed: () => repo.setWebPlayerPanelVisible(false),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.url, required this.size});

  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: size,
      height: size,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(Icons.music_note, size: size / 2),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: url.isEmpty
          ? placeholder
          : Image.network(
              url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => placeholder,
            ),
    );
  }
}

/// Position bar. Ticks locally while playing (the SDK reports only on
/// changes); in the larger layout it is a slider that seeks.
class _Progress extends ConsumerStatefulWidget {
  const _Progress({required this.state, required this.compact});

  final WebPlayerState state;
  final bool compact;

  @override
  ConsumerState<_Progress> createState() => _ProgressState();
}

class _ProgressState extends ConsumerState<_Progress> {
  Timer? _ticker;

  /// Slider value while the user drags; null otherwise.
  double? _dragMs;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!widget.state.paused && mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final duration = state.durationMs.toDouble();
    final position = _dragMs ?? state.positionAt(DateTime.now()).toDouble();
    final times = Row(
      children: [
        Text(_format(position), style: const TextStyle(fontSize: 11)),
        const Spacer(),
        Text(_format(duration), style: const TextStyle(fontSize: 11)),
      ],
    );
    if (widget.compact || duration <= 0) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(
            value: duration > 0 ? (position / duration).clamp(0, 1) : null,
            minHeight: 3,
          ),
          const SizedBox(height: 2),
          times,
        ],
      );
    }
    final repo = ref.read(spotifyRemoteRepositoryProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 24,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              padding: EdgeInsets.zero,
            ),
            child: Slider(
              value: position.clamp(0, duration),
              max: duration,
              onChanged: (v) => setState(() => _dragMs = v),
              onChangeEnd: (v) async {
                await repo.seekWebPlayer(v.round());
                if (mounted) setState(() => _dragMs = null);
              },
            ),
          ),
        ),
        times,
      ],
    );
  }
}

String _format(double ms) {
  final total = (ms / 1000).floor();
  final minutes = total ~/ 60;
  final seconds = (total % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
