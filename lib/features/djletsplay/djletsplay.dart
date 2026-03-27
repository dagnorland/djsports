import 'dart:io';
import 'dart:math';

import 'package:djsports/data/models/djplaylist_model.dart';
import 'package:djsports/data/provider/djplaylist_provider.dart';
import 'package:djsports/data/repo/last_djtrack_played_repository.dart';
import 'package:djsports/data/repo/spotify_remote_repository.dart';
import 'package:djsports/data/repo/app_settings_repository.dart';
import 'package:djsports/features/djmatch_center/widgets/center_control_widget.dart';
import 'package:djsports/features/djletsplay/widgets/debug_log_sheet.dart';
import 'package:djsports/features/djletsplay/widgets/letsplay_playlist_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:toastification/toastification.dart';

class DJLetsPlayViewPage extends StatefulHookConsumerWidget {
  const DJLetsPlayViewPage({super.key, this.refreshCallback});

  final VoidCallback? refreshCallback;

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _DJLetsPlayViewPageState();
}

class _DJLetsPlayViewPageState extends ConsumerState<DJLetsPlayViewPage> {
  bool isPlaying = false;

  final Map<String, ValueNotifier<int>> _playTriggers = {};

  static const _hotspotKeys = ['1', '2', '3', '4', '5', '6'];
  static const _matchKeys = ['q', 'w', 'e', 'r', 't', 'y'];
  static const _funStuffKeys = ['a', 's', 'd', 'f', 'g', 'h'];

  static const _hotspotLogicalKeys = [
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
    LogicalKeyboardKey.digit5,
    LogicalKeyboardKey.digit6,
  ];
  static const _matchLogicalKeys = [
    LogicalKeyboardKey.keyQ,
    LogicalKeyboardKey.keyW,
    LogicalKeyboardKey.keyE,
    LogicalKeyboardKey.keyR,
    LogicalKeyboardKey.keyT,
    LogicalKeyboardKey.keyY,
  ];
  static const _funStuffLogicalKeys = [
    LogicalKeyboardKey.keyA,
    LogicalKeyboardKey.keyS,
    LogicalKeyboardKey.keyD,
    LogicalKeyboardKey.keyF,
    LogicalKeyboardKey.keyG,
    LogicalKeyboardKey.keyH,
  ];

  ValueNotifier<int> _getTrigger(String playlistId) =>
      _playTriggers.putIfAbsent(playlistId, () => ValueNotifier(0));

  String? _shortcutKeyForType(DJPlaylistType type, int index) {
    if (index >= 6) return null;
    if (type == DJPlaylistType.hotspot) return _hotspotKeys[index];
    if (type == DJPlaylistType.match) return _matchKeys[index];
    if (type == DJPlaylistType.funStuff) return _funStuffKeys[index];
    return null;
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (!AppSettings.keyboardShortcutsEnabled) return false;

    // Consume key-repeat for all our keys to prevent OS beep on held keys
    if (event is KeyRepeatEvent) {
      final k = event.logicalKey;
      return _hotspotLogicalKeys.contains(k) ||
          _matchLogicalKeys.contains(k) ||
          _funStuffLogicalKeys.contains(k) ||
          k == LogicalKeyboardKey.escape ||
          k == LogicalKeyboardKey.keyP ||
          k == LogicalKeyboardKey.add ||
          k == LogicalKeyboardKey.minus;
    }
    if (event is! KeyDownEvent) return false;

    final key = event.logicalKey;

    // Global transport controls
    if (key == LogicalKeyboardKey.escape) {
      pausePlayer();
      return true;
    }
    if (key == LogicalKeyboardKey.keyP) {
      resumePlayer();
      return true;
    }
    if (key == LogicalKeyboardKey.add) {
      ref.read(spotifyRemoteRepositoryProvider).adjustVolume(0.05);
      return true;
    }
    if (key == LogicalKeyboardKey.minus) {
      ref.read(spotifyRemoteRepositoryProvider).adjustVolume(-0.05);
      return true;
    }

    // Playlist shortcuts
    DJPlaylistType? type;
    int index = -1;

    if (_hotspotLogicalKeys.contains(key)) {
      type = DJPlaylistType.hotspot;
      index = _hotspotLogicalKeys.indexOf(key);
    } else if (_matchLogicalKeys.contains(key)) {
      type = DJPlaylistType.match;
      index = _matchLogicalKeys.indexOf(key);
    } else if (_funStuffLogicalKeys.contains(key)) {
      type = DJPlaylistType.funStuff;
      index = _funStuffLogicalKeys.indexOf(key);
    }

    if (type == null || index < 0) return false;

    final allPlaylists = ref.read(hivePlaylistData) ?? [];
    final typePlaylists = allPlaylists
        .where((p) => p.type == type!.name)
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));

    if (index < typePlaylists.length) {
      _getTrigger(typePlaylists[index].id).value++;
    }
    return true;
  }

  @override
  void initState() {
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    FlutterVolumeController.getVolume().then((v) {
      if (v != null && mounted) {
        final repo = ref.read(spotifyRemoteRepositoryProvider);
        final autoSet = repo.volumeAutoSetToDefault || v == 0;
        if (autoSet) {
          repo.volumeAutoSetToDefault = false;
          if (v == 0) {
            FlutterVolumeController.setVolume(0.85);
            repo.setVolume(0.85);
          }
        } else {
          repo.setVolume(v);
        }
        toastification.show(
          context: context,
          title: Text(
            autoSet
                ? 'Volume auto-set to 85%'
                : 'Volume: ${(v * 100).round()}%',
          ),
          autoCloseDuration: const Duration(seconds: 3),
          style: ToastificationStyle.flat,
          alignment: Alignment.topCenter,
        );
      }
    });
    super.initState();
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    for (final t in _playTriggers.values) {
      t.dispose();
    }
    super.dispose();
  }

  Future<bool> pausePlayer() async {
    isPlaying = await ref.read(spotifyRemoteRepositoryProvider).pausePlayer();
    return isPlaying;
  }

  Future<bool> hardPausePlayer() async {
    isPlaying =
        await ref.read(spotifyRemoteRepositoryProvider).hardPausePlayer();
    return isPlaying;
  }

  Future<bool> resumePlayer() async {
    isPlaying =
        await ref.read(spotifyRemoteRepositoryProvider).resumePlayer();
    return isPlaying;
  }

  List<DJPlaylist> _filterByType(
    List<DJPlaylist> all,
    DJPlaylistType type,
  ) {
    return all
        .where((p) => p.type == type.name)
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));
  }

  Widget _buildSection(
    DJPlaylistType type,
    String label,
    List<DJPlaylist> playlists,
  ) {
    if (playlists.isEmpty) return const SizedBox.shrink();

    final sectionColor =
        type.color == Colors.black ? Colors.grey.shade400 : type.color;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 2),
          child: Row(
            children: [
              Container(width: 6, height: 18, color: sectionColor),
              const SizedBox(width: 8),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  color: sectionColor,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final cols = max(1, (constraints.maxWidth / 200).floor());
            final screenH = MediaQuery.of(context).size.height;
            final cardH = (screenH * 0.18).clamp(90.0, 260.0);
            return GridView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                mainAxisExtent: cardH,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: playlists.length,
              itemBuilder: (context, i) {
                final playlist = playlists[i];
                final pType = DJPlaylistType.values.firstWhere(
                  (t) => t.name == playlist.type,
                  orElse: () => DJPlaylistType.match,
                );
                final shortcutKey = AppSettings.keyboardShortcutsEnabled
                    ? _shortcutKeyForType(pType, i)
                    : null;
                return LetsPlayPlaylistCard(
                  playlistId: playlist.id,
                  playlistName: playlist.name,
                  playlistType: pType,
                  initialTrackIndex: playlist.currentTrack,
                  shortcutKey: shortcutKey,
                  playTrigger: shortcutKey != null
                      ? _getTrigger(playlist.id)
                      : null,
                );
              },
            );
          },
        ),
        Divider(color: sectionColor, height: 4, thickness: 3),
      ],
    );
  }

  Widget _buildBoard(List<DJPlaylist> allPlaylists) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSection(
            DJPlaylistType.hotspot,
            'Hotspot',
            _filterByType(allPlaylists, DJPlaylistType.hotspot),
          ),
          _buildSection(
            DJPlaylistType.match,
            'Match',
            _filterByType(allPlaylists, DJPlaylistType.match),
          ),
          _buildSection(
            DJPlaylistType.funStuff,
            'Fun Stuff',
            _filterByType(allPlaylists, DJPlaylistType.funStuff),
          ),
          _buildSection(
            DJPlaylistType.preMatch,
            'Pre-Match',
            _filterByType(allPlaylists, DJPlaylistType.preMatch),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      color: Colors.red,
      child: Column(
        children: [
          Expanded(
            child: CenterControlWidget(
              onResume: () async => resumePlayer(),
              onPause: () async => pausePlayer(),
              onHardPause: Platform.isIOS
                  ? () async => hardPausePlayer()
                  : null,
              onBack: () {
                Navigator.of(context).pop();
                widget.refreshCallback?.call();
              },
              refreshCallback: widget.refreshCallback,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.bug_report, color: Colors.white70, size: 22),
            tooltip: 'Debug log',
            onPressed: () => DebugLogSheet.show(context),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildCompactControls() {
    final lastTrack = ref.watch(lastDjTrackPlayedProvider);
    return ColoredBox(
      color: Colors.red,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            lastTrack.maybeWhen(
              data: (track) {
                if (track == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.music_note,
                        color: Colors.white70,
                        size: 13,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          track.artist.isNotEmpty
                              ? '${track.name}  •  ${track.artist}'
                              : track.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),
            SizedBox(
              height: 64,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
              IconButton(
                icon: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 32,
                ),
                onPressed: resumePlayer,
              ),
              ValueListenableBuilder<bool>(
                valueListenable: ref
                    .read(spotifyRemoteRepositoryProvider)
                    .silencePlayingNotifier,
                builder: (context, isSilence, _) => GestureDetector(
                  onLongPress: (Platform.isIOS && isSilence)
                      ? () async {
                          await hardPausePlayer();
                          if (!context.mounted) return;
                          toastification.show(
                            context: context,
                            title: const Text('PAUSED'),
                            autoCloseDuration: const Duration(seconds: 2),
                            style: ToastificationStyle.flat,
                            alignment: Alignment.topCenter,
                          );
                        }
                      : null,
                  child: IconButton(
                    icon: Icon(
                      Icons.pause,
                      color: isSilence ? Colors.orange : Colors.white,
                      size: 32,
                    ),
                    onPressed: pausePlayer,
                  ),
                ),
              ),
              if (Platform.isIOS || Platform.isMacOS)
                IconButton(
                  icon: const Icon(
                    Icons.open_in_new,
                    color: Color(0xFF1DB954),
                    size: 26,
                  ),
                  tooltip: 'Open Spotify',
                  onPressed: () => ref
                      .read(spotifyRemoteRepositoryProvider)
                      .launchSpotify(),
                ),
              IconButton(
                icon: const Icon(
                  Icons.volume_up,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: () => ref
                    .read(spotifyRemoteRepositoryProvider)
                    .adjustVolume(0.05),
              ),
              IconButton(
                icon: const Icon(
                  Icons.volume_down,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: () => ref
                    .read(spotifyRemoteRepositoryProvider)
                    .adjustVolume(-0.05),
              ),
              IconButton(
                icon: const Icon(
                  Icons.bug_report,
                  color: Colors.white70,
                  size: 24,
                ),
                tooltip: 'Debug log',
                onPressed: () => DebugLogSheet.show(context),
              ),
              IconButton(
                icon: const Icon(
                  Icons.backspace,
                  color: Colors.white,
                  size: 24,
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.refreshCallback?.call();
                },
              ),
            ],      // close Row.children
          ),        // close Row
        ),          // close SizedBox
      ],            // close Column.children
    ),              // close Column
    ),              // close SafeArea
    );
  }

  @override
  Widget build(BuildContext context) {
    final allPlaylists = ref.watch(typeFilteredAllDataProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.black,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 600;
            // Only use sidebar on wide screens with enough height
            // (tablets / macOS). On landscape phones the screen is too
            // short to show all sidebar buttons without scrolling issues.
            final isTallEnoughForSidebar = constraints.maxHeight >= 500;

            if (isWide && isTallEnoughForSidebar) {
              final sidebarOnRight = AppSettings.sidebarOnRight;
              final board = Expanded(
                flex: 85,
                child: SafeArea(child: _buildBoard(allPlaylists)),
              );
              final sidebar = Expanded(
                flex: 15,
                child: _buildSidebar(),
              );
              return Row(
                children: sidebarOnRight
                    ? [board, sidebar]
                    : [sidebar, board],
              );
            }

            // Phone portrait and landscape: board fills available space,
            // compact control bar at the bottom with proper safe area.
            return Column(
              children: [
                const SafeArea(bottom: false, child: SizedBox()),
                Expanded(child: _buildBoard(allPlaylists)),
                _buildCompactControls(),
              ],
            );
          },
        ),
      ),
    );
  }
}
