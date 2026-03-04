import 'dart:async';

import 'package:djsports/data/models/djplaylist_model.dart';
import 'package:djsports/data/models/djtrack_model.dart';
import 'package:djsports/data/provider/djplaylist_provider.dart';
import 'package:djsports/data/provider/djtrack_provider.dart';
import 'package:djsports/data/repo/last_djtrack_played_repository.dart';
import 'package:djsports/data/repo/spotify_remote_repository.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:toastification/toastification.dart';

enum _NoDeviceAction { cancel, openSpotify }

class MatchDayPlaylistCard extends ConsumerStatefulWidget {
  const MatchDayPlaylistCard({
    super.key,
    required this.playlistId,
    required this.playlistName,
    required this.playlistType,
    required this.initialTrackIndex,
  });

  final String playlistId;
  final String playlistName;
  final DJPlaylistType playlistType;
  final int initialTrackIndex;

  @override
  ConsumerState<MatchDayPlaylistCard> createState() =>
      _MatchDayPlaylistCardState();
}

class _MatchDayPlaylistCardState extends ConsumerState<MatchDayPlaylistCard>
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
  }

  @override
  void dispose() {
    _autoNextTimer?.cancel();
    _flashController.dispose();
    super.dispose();
  }

  String _truncate(String text, int max) {
    if (text.length > max) return '${text.substring(0, max - 3)}...';
    return text;
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
        lower.contains('connection');
  }

  bool _isNoActiveDeviceError(String response) {
    if (!response.contains('[Error]')) return false;
    final lower = response.toLowerCase();
    return lower.contains('no active device') ||
        lower.contains('player command failed');
  }

  void _showToast(String message, {Widget? description}) {
    toastification.show(
      context: context,
      title: Text(message),
      description: description,
      autoCloseDuration: const Duration(seconds: 3),
      style: ToastificationStyle.flat,
      alignment: Alignment.topCenter,
    );
  }

  Future<void> _showReconnectDialog(
    DJTrack track,
    int idx,
    int trackCount,
    bool shuffleAtEnd,
  ) async {
    final reconnect = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Spotify Disconnected'),
        content: const Text(
          'Lost connection to Spotify.\nReconnect and try again?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reconnect'),
          ),
        ],
      ),
    );
    if (reconnect != true || !mounted) return;

    _showToast('Reconnecting to Spotify…');
    final success =
        await ref.read(spotifyRemoteRepositoryProvider).forceFullReconnect();
    if (!mounted) return;

    if (success) {
      await _playTrack(track, idx, trackCount, shuffleAtEnd, retry: false);
    } else {
      final err = ref.read(spotifyRemoteRepositoryProvider).lastConnectError;
      _showToast(
        'Failed to reconnect',
        description: err.isNotEmpty ? Text(err) : null,
      );
    }
  }

  Future<void> _showNoDeviceDialog(
    DJTrack track,
    int idx,
    int trackCount,
    bool shuffleAtEnd,
  ) async {
    final action = await showDialog<_NoDeviceAction>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('No Active Spotify Device'),
        content: const Text(
          'Spotify is not playing on any device.\n'
          'Open the Spotify app and try again.',
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

  Future<void> _playTrack(
    DJTrack track,
    int idx,
    int trackCount,
    bool shuffleAtEnd, {
    bool retry = true,
  }) async {
    _autoNextTimer?.cancel();
    unawaited(_flashController.forward(from: 0.0));
    final response = await ref
        .read(spotifyRemoteRepositoryProvider)
        .playTrackAndJumpStart(
          track,
          track.startTime + track.startTimeMS,
          widget.playlistType,
          widget.playlistName,
        );
    if (!mounted) return;

    if (_isNoActiveDeviceError(response) && retry) {
      await _showNoDeviceDialog(track, idx, trackCount, shuffleAtEnd);
      return;
    }
    if (_isConnectionError(response) && retry) {
      await _showReconnectDialog(track, idx, trackCount, shuffleAtEnd);
      return;
    }

    if (!response.contains('[Error]')) {
      track.playCount = track.playCount + 1;
      ref.read(hiveTrackData.notifier).updateDJTrack(track);
      await ref
          .read(lastDjTrackPlayedProvider.notifier)
          .updateLastPlayedTrack(track);
      _autoNextTimer = Timer(
        const Duration(seconds: 2),
        () => _autoNext(idx, trackCount, shuffleAtEnd),
      );
    }
    if (!mounted) return;
    final startMs = track.startTime + track.startTimeMS;
    _showToast(
      response,
      description: startMs > 0 ? Text('Start @ ${_formatMs(startMs)}') : null,
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
    final borderColor = typeColor == Colors.black
        ? Colors.grey.shade700
        : typeColor;

    return AnimatedBuilder(
      animation: _flashController,
      builder: (context, child) {
        final flashOpacity = (1.0 - _flashController.value) * 0.55;
        return Card(
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
      child: InkWell(
        onTap: () =>
            _playTrack(track, idx, tracks.length, playlist.shuffleAtEnd),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: borderColor, width: 5)),
            borderRadius: BorderRadius.circular(6),
            image: track.networkImageUri.isNotEmpty
                ? DecorationImage(
                    image: NetworkImage(track.networkImageUri),
                    fit: BoxFit.cover,
                    opacity: 0.23,
                  )
                : null,
          ),
          padding: const EdgeInsets.fromLTRB(6, 4, 4, 4),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: playlist name + track counter
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.playlistName.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  Text(
                    '#${idx + 1}/${tracks.length}',
                    style: TextStyle(
                      fontSize: 11,
                      color: borderColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              // Navigation row: ◄  [art]  name  ►  ▶
              Row(
                children: [
                  // Prev button
                  _NavButton(
                    icon: Icons.chevron_left,
                    enabled: true,
                    onPressed: () => _goPrev(idx, tracks.length),
                  ),
                  const SizedBox(width: 4),
                  // Album art + track info (animated on track change)
                  Expanded(
                    child: ClipRect(
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
                            _AlbumArt(uri: track.networkImageUri),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _truncate(track.name, 22),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          track.artist,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                      if (track.startTime + track.startTimeMS >
                                          0)
                                        Text(
                                          _formatMs(
                                            track.startTime + track.startTimeMS,
                                          ),
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: borderColor,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Play button
                  IconButton(
                    icon: Icon(Icons.play_arrow, color: borderColor),
                    iconSize: 28,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _playTrack(
                      track,
                      idx,
                      tracks.length,
                      playlist.shuffleAtEnd,
                    ),
                  ),
                  const SizedBox(width: 2),
                  // Next button
                  _NavButton(
                    icon: Icons.chevron_right,
                    enabled: true,
                    onPressed: () => _goNext(idx, tracks.length),
                  ),
                ],
              ),
              // Current track name — updates immediately as the user
              // navigates between tracks.
              Row(
                children: [
                  Icon(Icons.music_note, size: 11, color: borderColor),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Text(
                      track.artist.isNotEmpty
                          ? '${track.name}  •  ${track.artist}'
                          : track.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: borderColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
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
      color: enabled ? null : Colors.grey.shade400,
      onPressed: enabled ? onPressed : null,
    );
  }
}

class _AlbumArt extends StatelessWidget {
  const _AlbumArt({required this.uri});

  final String uri;

  @override
  Widget build(BuildContext context) {
    if (uri.isEmpty) {
      return const SizedBox(
        width: 40,
        height: 40,
        child: Icon(Icons.featured_play_list_outlined, size: 32),
      );
    }
    return Image.network(
      uri,
      width: 40,
      height: 40,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const SizedBox(
        width: 40,
        height: 40,
        child: Icon(Icons.cloud_off_outlined, size: 32, color: Colors.black38),
      ),
    );
  }
}
