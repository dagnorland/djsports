import 'dart:math' as math;
import 'dart:async';

import 'package:djsports/core/app_toast.dart';
import 'package:djsports/data/repo/apple_music_repository.dart';
import 'package:djsports/core/theme/stage_colors.dart';
import 'package:djsports/data/models/djplaylist_model.dart';
import 'package:djsports/data/models/djtrack_model.dart';
import 'package:djsports/data/provider/djplaylist_provider.dart';
import 'package:djsports/data/provider/djtrack_provider.dart';
import 'package:djsports/data/provider/apple_music_provider.dart';
import 'package:djsports/data/repo/last_djtrack_played_repository.dart';
import 'package:djsports/data/repo/spotify_remote_repository.dart';
import 'package:djsports/features/spotify_connect/spotify_output_sheet.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

enum _NoDeviceAction { cancel, openSpotify }

class LetsPlayPlaylistCard extends ConsumerStatefulWidget {
  const LetsPlayPlaylistCard({
    super.key,
    required this.playlistId,
    required this.playlistName,
    required this.playlistType,
    required this.initialTrackIndex,
    this.shortcutKey,
    this.playTrigger,
  });

  final String playlistId;
  final String playlistName;
  final DJPlaylistType playlistType;
  final int initialTrackIndex;
  final String? shortcutKey;
  final ValueNotifier<int>? playTrigger;

  @override
  ConsumerState<LetsPlayPlaylistCard> createState() =>
      _LetsPlayPlaylistCardState();
}

class _LetsPlayPlaylistCardState extends ConsumerState<LetsPlayPlaylistCard>
    with SingleTickerProviderStateMixin {
  late int _currentIndex;
  bool _goingForward = true;
  Timer? _autoNextTimer;
  late AnimationController _flashController;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTrackIndex;
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
      value: 1.0, // start fully faded — no overlay until first play
    );
    widget.playTrigger?.addListener(_onKeyboardTrigger);
  }

  @override
  void didUpdateWidget(LetsPlayPlaylistCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playTrigger != widget.playTrigger) {
      oldWidget.playTrigger?.removeListener(_onKeyboardTrigger);
      widget.playTrigger?.addListener(_onKeyboardTrigger);
    }
  }

  @override
  void dispose() {
    widget.playTrigger?.removeListener(_onKeyboardTrigger);
    _autoNextTimer?.cancel();
    _flashController.dispose();
    super.dispose();
  }

  void _onKeyboardTrigger() {
    if (!mounted) return;
    final playlist = ref.read(djPlaylistByIdProvider(widget.playlistId));
    final tracks = ref
        .read(hiveTrackData.notifier)
        .getDJTracks(playlist.trackIds);
    if (tracks.isEmpty) return;
    final idx = _currentIndex.clamp(0, tracks.length - 1);
    _playTrack(
      tracks[idx],
      idx,
      tracks.length,
      playlist.shuffleAtEnd,
      playlist.autoNext,
    );
  }

  String _formatMs(int ms) {
    final d = Duration(milliseconds: ms);
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _goPrev(int idx, int total) {
    _autoNextTimer?.cancel();
    _goingForward = false;
    if (idx > 0) {
      setState(() => _currentIndex = idx - 1);
    } else {
      setState(() => _currentIndex = total - 1);
      _showNavToast('↩ Last track');
    }
  }

  void _goNext(int idx, int total) {
    _autoNextTimer?.cancel();
    _goingForward = true;
    if (idx < total - 1) {
      setState(() => _currentIndex = idx + 1);
    } else {
      setState(() => _currentIndex = 0);
      _showNavToast('↩ Back to start');
    }
  }

  void _autoNext(int idx, int trackCount, bool shuffleAtEnd) {
    if (!mounted) return;
    _goingForward = true;
    if (idx < trackCount - 1) {
      setState(() => _currentIndex = idx + 1);
    } else if (shuffleAtEnd) {
      ref
          .read(hivePlaylistData.notifier)
          .shuffleTracksInPlaylist(widget.playlistId);
      setState(() => _currentIndex = 0);
      _showNavToast('🔀 Playlist shuffled');
    } else {
      setState(() => _currentIndex = 0);
      _showNavToast('↩ Back to start');
    }
  }

  bool _isConnectionError(String response) {
    if (!response.contains('[Error]')) return false;
    final lower = response.toLowerCase();
    return lower.contains('not connected') ||
        lower.contains('disconnected') ||
        lower.contains('connection') ||
        lower.contains('404') ||
        lower.contains('401') ||
        lower.contains('unauthorized');
  }

  bool _isNoActiveDeviceError(String response) {
    if (!response.contains('[Error]')) return false;
    // Exclude genuine disconnects — those go to the reconnect dialog instead.
    if (response.contains('SpotifyDisconnectedException')) return false;
    final lower = response.toLowerCase();
    // macOS Web API: no active device
    if (lower.contains('no active device') ||
        lower.contains('player command failed')) {
      return true;
    }
    // iOS SPTAppRemote: connected but Spotify not yet active/playing
    if (lower.contains('app-remote')) return true;
    return false;
  }

  void _showToast(
    String message, {
    Widget? description,
    ToastLevel level = ToastLevel.info,
  }) {
    showAppToast(
      context,
      title: Text(message),
      description: description,
      level: level,
    );
  }

  Future<void> _showReconnectDialog(
    DJTrack track,
    int idx,
    int trackCount,
    bool shuffleAtEnd,
    bool autoNext,
    String errorMessage,
  ) async {
    final reconnect = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Spotify Connection Error'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Lost connection to Spotify.\nReconnect and try again?'),
            const SizedBox(height: 8),
            SelectableText(
              errorMessage,
              style: const TextStyle(fontSize: 11, color: Colors.red),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Force Full Reconnect'),
          ),
        ],
      ),
    );
    if (reconnect != true || !mounted) return;

    _showToast('Reconnecting to Spotify…');
    final success = await ref
        .read(spotifyRemoteRepositoryProvider)
        .forceFullReconnect();
    if (!mounted) return;

    if (success) {
      await _playTrack(
        track,
        idx,
        trackCount,
        shuffleAtEnd,
        autoNext,
        retry: false,
      );
    } else {
      final err = ref.read(spotifyRemoteRepositoryProvider).lastConnectError;
      _showToast(
        'Failed to reconnect',
        description: err.isNotEmpty ? Text(err) : null,
        level: ToastLevel.error,
      );
    }
  }

  Future<void> _showNoDeviceDialog(
    DJTrack track,
    int idx,
    int trackCount,
    bool shuffleAtEnd,
  ) async {
    final repo = ref.read(spotifyRemoteRepositoryProvider);
    final userName = repo.spotifyUserDisplayName.isNotEmpty
        ? repo.spotifyUserDisplayName
        : repo.spotifyUserId.isNotEmpty
        ? repo.spotifyUserId
        : null;
    final action = await showDialog<_NoDeviceAction>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Spotify Not Active'),
        content: Text(
          '${userName != null ? 'User: $userName\n\n' : ''}'
          'Spotify is not playing on any device.\n\n'
          'Open Spotify, press play on any track,\n'
          'then come back here and try again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, _NoDeviceAction.cancel),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('Open Spotify'),
            onPressed: () => Navigator.pop(ctx, _NoDeviceAction.openSpotify),
          ),
        ],
      ),
    );
    if (action == null || !mounted) return;
    if (action == _NoDeviceAction.openSpotify) {
      _showToast('Opening Spotify…');
      await ref.read(spotifyRemoteRepositoryProvider).launchSpotify();
    }
  }

  void _showNavToast(String message) {
    _showToast(message);
  }

  Future<String> _callService(DJTrack track) {
    final jumpStart = track.startTime + track.startTimeMS;
    if (playsWithAppleMusic(track.appleMusicId, track.spotifyUri)) {
      return ref
          .read(appleMusicRepositoryProvider)
          .playTrackAndJumpStart(
            track,
            jumpStart,
            widget.playlistType,
            widget.playlistName,
          );
    }
    if (track.spotifyUri.isEmpty) {
      return Future.value(
        '[Error] No playback source — re-add this track from Apple Music or Spotify.',
      );
    }
    return ref
        .read(spotifyRemoteRepositoryProvider)
        .playTrackAndJumpStart(
          track,
          jumpStart,
          widget.playlistType,
          widget.playlistName,
        );
  }

  Future<void> _playTrack(
    DJTrack track,
    int idx,
    int trackCount,
    bool shuffleAtEnd,
    bool autoNext, {
    bool retry = true,
  }) async {
    _autoNextTimer?.cancel();
    unawaited(_flashController.forward(from: 0.0));

    final response = await _callService(track);
    if (!mounted) return;

    // Spotify-only error recovery
    if (!playsWithAppleMusic(track.appleMusicId, track.spotifyUri)) {
      if (isNoDeviceResult(response)) {
        // Ask where to play (never silently pick another device), then
        // retry once on the chosen device.
        final chosen = await showSpotifyDevicePicker(
          context,
          message: playResultMessage(response),
        );
        if (chosen && retry && mounted) {
          await _playTrack(
            track,
            idx,
            trackCount,
            shuffleAtEnd,
            autoNext,
            retry: false,
          );
        }
        return;
      }
      if (isPremiumResult(response)) {
        _showToast(
          'Spotify Premium required',
          description: Text(playResultMessage(response)),
          level: ToastLevel.error,
        );
        return;
      }
      if (_isNoActiveDeviceError(response)) {
        await _showNoDeviceDialog(track, idx, trackCount, shuffleAtEnd);
        return;
      }
      if (_isConnectionError(response) && retry) {
        _showToast('Reconnecting to Spotify…');
        final success = await ref
            .read(spotifyRemoteRepositoryProvider)
            .forceFullReconnect();
        if (!mounted) return;
        if (success) {
          await _playTrack(
            track,
            idx,
            trackCount,
            shuffleAtEnd,
            autoNext,
            retry: false,
          );
        } else {
          await _showReconnectDialog(
            track,
            idx,
            trackCount,
            shuffleAtEnd,
            autoNext,
            response,
          );
        }
        return;
      }
    }

    if (!response.contains('[Error]')) {
      track.playCount = track.playCount + 1;
      ref.read(hiveTrackData.notifier).updateDJTrack(track);
      await ref
          .read(lastDjTrackPlayedProvider.notifier)
          .updateLastPlayedTrack(track);
      if (autoNext) {
        _autoNextTimer = Timer(
          const Duration(seconds: 2),
          () => _autoNext(idx, trackCount, shuffleAtEnd),
        );
      }
    }
    if (!mounted) return;
    final startMs = track.startTime + track.startTimeMS;
    _showToast(
      response,
      description: startMs > 0 ? Text('Start @ ${_formatMs(startMs)}') : null,
      level: response.contains('[Error]') ? ToastLevel.error : ToastLevel.info,
    );
  }

  @override
  Widget build(BuildContext context) {
    final playlist = ref.watch(djPlaylistByIdProvider(widget.playlistId));
    final tracks = ref
        .watch(hiveTrackData.notifier)
        .getDJTracks(playlist.trackIds);

    if (tracks.isEmpty) return const SizedBox.shrink();

    final idx = _currentIndex.clamp(0, tracks.length - 1);
    if (idx != _currentIndex) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => setState(() => _currentIndex = idx),
      );
    }
    final track = tracks[idx];
    final typeColor = widget.playlistType.color;
    // Pre-match is black – use a grey that shows on the dark stage.
    final borderColor = typeColor == Colors.black
        ? Colors.grey.shade500
        : typeColor;

    return AnimatedBuilder(
      animation: _flashController,
      builder: (context, child) {
        final flashOpacity = (1.0 - _flashController.value) * 0.55;
        return Card(
          clipBehavior: Clip.antiAlias,
          margin: const EdgeInsets.all(4),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          child: Stack(
            children: [
              child!,
              Positioned.fill(
                child: IgnorePointer(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      color: borderColor.withOpacity(flashOpacity),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      child: GestureDetector(
        // Swipe left/right to change track (the only way on narrow tiles).
        onHorizontalDragEnd: (details) {
          final v = details.primaryVelocity ?? 0;
          if (v < -200) _goNext(idx, tracks.length);
          if (v > 200) _goPrev(idx, tracks.length);
        },
        child: InkWell(
          onTap: () => _playTrack(
            track,
            idx,
            tracks.length,
            playlist.shuffleAtEnd,
            playlist.autoNext,
          ),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: borderColor, width: 5)),
              image: track.networkImageUri.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(track.networkImageUri),
                      fit: BoxFit.cover,
                      opacity: 0.2,
                    )
                  : null,
            ),
            // Dark veil behind the text so busy covers don't compete with it.
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xE61E1E1E), Color(0x801E1E1E)],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 4, 4, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: shortcut key, playlist name, ‹ #n/m ›.
                    // Narrow tiles (iPhone) drop the arrows so the name
                    // fits – swipe the tile to change track instead.
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final showArrows = constraints.maxWidth >= 260;
                        return Row(
                          children: [
                            if (widget.shortcutKey != null) ...[
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: borderColor,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  widget.shortcutKey!.toUpperCase(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                    color: Colors.white,
                                    height: 1,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 5),
                            ],
                            Expanded(
                              child: Text(
                                widget.playlistName.toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            if (showArrows)
                              _NavButton(
                                icon: Icons.chevron_left,
                                enabled: true,
                                onPressed: () => _goPrev(idx, tracks.length),
                              ),
                            Text(
                              '#${idx + 1}/${tracks.length}',
                              style: TextStyle(
                                fontSize: 11,
                                color: borderColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (showArrows)
                              _NavButton(
                                icon: Icons.chevron_right,
                                enabled: true,
                                onPressed: () => _goNext(idx, tracks.length),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 4),
                    // Cover with play button, then title / artist / start.
                    // Everything scales with the tile height.
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final h = constraints.maxHeight;
                          final startMs = track.startTime + track.startTimeMS;
                          final titleSize = (h / 5).clamp(13.0, 20.0);
                          // Square cover, but leave the text at least 60 %.
                          final coverSize = math
                              .min(h, constraints.maxWidth * 0.4)
                              .clamp(36.0, 160.0);
                          return ClipRect(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 280),
                              transitionBuilder: (child, animation) {
                                final key = child.key;
                                final isEntering =
                                    key is ValueKey<int> &&
                                    key.value == _currentIndex;
                                final beginX = isEntering
                                    ? (_goingForward ? 0.5 : -0.5)
                                    : (_goingForward ? -0.5 : 0.5);
                                return SlideTransition(
                                  position:
                                      Tween<Offset>(
                                        begin: Offset(beginX, 0),
                                        end: Offset.zero,
                                      ).animate(
                                        CurvedAnimation(
                                          parent: animation,
                                          curve: Curves.easeOut,
                                        ),
                                      ),
                                  child: FadeTransition(
                                    opacity: animation,
                                    child: child,
                                  ),
                                );
                              },
                              child: Row(
                                key: ValueKey<int>(_currentIndex),
                                children: [
                                  _CoverWithPlay(
                                    uri: track.networkImageUri,
                                    size: coverSize,
                                    color: borderColor,
                                    onPlay: () => _playTrack(
                                      track,
                                      idx,
                                      tracks.length,
                                      playlist.shuffleAtEnd,
                                      playlist.autoNext,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          track.name,
                                          maxLines: h >= 80 ? 2 : 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: titleSize,
                                            height: 1.15,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          track.artist,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: titleSize * 0.8,
                                            color: StageColors.textMuted,
                                          ),
                                        ),
                                        if (startMs > 0)
                                          Text(
                                            'Start ${_formatMs(startMs)}',
                                            maxLines: 1,
                                            style: TextStyle(
                                              fontSize: titleSize * 0.75,
                                              color: borderColor,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon),
      iconSize: 20,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      color: enabled ? null : Colors.white24,
      onPressed: enabled ? onPressed : null,
    );
  }
}

/// Spotify-style: the cover with a round play button in the type colour
/// in its lower right corner.
class _CoverWithPlay extends StatelessWidget {
  const _CoverWithPlay({
    required this.uri,
    required this.size,
    required this.color,
    required this.onPlay,
  });

  final String uri;
  final double size;
  final Color color;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: size,
      height: size,
      color: StageColors.surfaceHigh,
      child: Icon(
        uri.isEmpty ? Icons.featured_play_list_outlined : Icons.cloud_off,
        size: size / 2,
        color: Colors.white24,
      ),
    );
    final button = (size * 0.38).clamp(24.0, 52.0);
    return SizedBox.square(
      dimension: size,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: uri.isEmpty
                ? placeholder
                : Image.network(
                    uri,
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => placeholder,
                  ),
          ),
          Positioned(
            right: 4,
            bottom: 4,
            child: Material(
              color: color,
              shape: const CircleBorder(),
              elevation: 4,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onPlay,
                child: SizedBox.square(
                  dimension: button,
                  child: Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: button * 0.65,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
