import 'package:djsports/data/models/djplaylist_model.dart';
import 'package:djsports/data/provider/djplaylist_provider.dart';
import 'package:djsports/data/repo/app_settings_repository.dart';
import 'package:djsports/data/repo/spotify_remote_repository.dart';
import 'package:djsports/features/djmatch_center/widgets/djmatch_center_playlist_tracks_carousel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'dart:io';

import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:toastification/toastification.dart';
import 'package:djsports/features/djmatch_center/widgets/center_control_widget.dart';

class DJMatchCenterViewPage extends StatefulHookConsumerWidget {
  const DJMatchCenterViewPage({super.key, this.refreshCallback});
  final VoidCallback? refreshCallback;

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _DJMatchCenterViewPageState();
}

class _DJMatchCenterViewPageState extends ConsumerState<DJMatchCenterViewPage> {
  bool spotifyConnect = false;
  bool spotifyRemoteConnect = false;
  bool isPlaying = false;

  // Keyboard shortcut play triggers keyed by playlist id
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

    // Not one of our shortcut keys — let OS handle it
    if (type == null || index < 0) return false;

    // It IS our shortcut key — consume it (prevents OS beep) even if no
    // playlist exists at that index
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
    if (!Platform.isMacOS) {
      FlutterVolumeController.addListener((newVolume) {
        final repo = ref.read(spotifyRemoteRepositoryProvider);
        // Skip near-zero drift to prevent the listener from re-firing
        // continuously when floating-point rounding causes tiny differences.
        if ((newVolume - repo.volume).abs() < 0.005) return;
        repo.setVolume(newVolume);
      });
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
          final mq = MediaQuery.of(context);
          final bottomMargin =
              (mq.size.width < 600 || mq.size.height < 500) ? 110.0 : 0.0;
          toastification.show(
            context: context,
            title: Text(
              autoSet ? 'Volume auto-set to 85%' : 'Volume: ${(v * 100).round()}%',
            ),
            autoCloseDuration: const Duration(seconds: 3),
            style: ToastificationStyle.flat,
            alignment: Alignment.bottomCenter,
            margin: EdgeInsets.only(bottom: bottomMargin),
          );
        }
      });
    }
    super.initState();
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    for (final t in _playTriggers.values) {
      t.dispose();
    }
    if (!Platform.isMacOS) {
      FlutterVolumeController.removeListener();
    }
    super.dispose();
  }

  Future<bool> pausePlayer() async {
    {
      isPlaying = await ref.read(spotifyRemoteRepositoryProvider).pausePlayer();
      return isPlaying;
    }
  }

  Future<bool> resumePlayer() async {
    {
      isPlaying = await ref
          .read(spotifyRemoteRepositoryProvider)
          .resumePlayer();
      return isPlaying;
    }
  }

  List<Widget> getPlaylistWidgetByPlaylistType(
    List<DJPlaylist> playlistList,
    DJPlaylistType playlistType,
  ) {
    List<DJPlaylist> filteredPlaylists =
        playlistList
            .where((playlist) => playlist.type == playlistType.name.toString())
            .toList()
          ..sort((a, b) => a.position.compareTo(b.position));

    return getPlaylistWidget(filteredPlaylists, playlistType);
  }

  List<Widget> getPlaylistWidget(
    List<DJPlaylist> playlistList,
    DJPlaylistType playlistType,
  ) {
    const constGridItemWidth = 290;
    return <Widget>[
      SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          /// Calculate the number of items in the horizontal axis based on screen width
          crossAxisCount:
              (MediaQuery.of(context).size.width / constGridItemWidth).floor(),
          mainAxisExtent: 175,
          crossAxisSpacing: 5,
          mainAxisSpacing: 5,
        ),
        delegate: SliverChildBuilderDelegate((BuildContext context, int index) {
          final shortcutKey = AppSettings.keyboardShortcutsEnabled
              ? _shortcutKeyForType(playlistType, index)
              : null;
          return Container(
            margin: const EdgeInsets.all(0.0),
            child: DJCenterPlaylistTracksCarousel(
              playlistId: playlistList[index].id,
              playlistName: playlistList[index].name,
              playlistType: DJPlaylistType.values.firstWhere(
                (type) => type.name == playlistList[index].type,
              ),
              spotifyUri: playlistList[index].spotifyUri,
              currentTrack: playlistList[index].currentTrack,
              parentWidthSize: constGridItemWidth,
              shortcutKey: shortcutKey,
              playTrigger: shortcutKey != null
                  ? _getTrigger(playlistList[index].id)
                  : null,
            ),
          );
        }, childCount: playlistList.length),
      ),
      SliverToBoxAdapter(
        child: Divider(color: playlistType.color, height: 5, thickness: 5),
      ),
    ];
  }

  Widget getImageWidget(String networkImageUri, double width, double height) {
    return networkImageUri.isEmpty
        ? const Icon(Icons.featured_play_list_outlined, size: 10)
        : Image.network(
            networkImageUri,
            width: width,
            height: height,
            errorBuilder: (context, error, stackTrace) => const SizedBox(
              width: 50,
              height: 50,
              child: Icon(
                Icons.cloud_off_outlined,
                size: 50,
                color: Colors.black38,
              ),
            ),
          );
  }

  Widget _buildCompactControls() {
    return ColoredBox(
      color: Colors.red,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.play_arrow, color: Colors.white,
                    size: 32),
                onPressed: resumePlayer,
              ),
              IconButton(
                icon: const Icon(Icons.pause, color: Colors.white, size: 32),
                onPressed: pausePlayer,
              ),
              IconButton(
                icon: const Icon(Icons.volume_up, color: Colors.white,
                    size: 28),
                onPressed: () => ref
                    .read(spotifyRemoteRepositoryProvider)
                    .adjustVolume(0.05),
              ),
              IconButton(
                icon: const Icon(Icons.volume_down, color: Colors.white,
                    size: 28),
                onPressed: () => ref
                    .read(spotifyRemoteRepositoryProvider)
                    .adjustVolume(-0.05),
              ),
              IconButton(
                icon: const Icon(Icons.backspace, color: Colors.white,
                    size: 24),
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.refreshCallback?.call();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playlists = ref.watch(typeFilteredAllDataProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 600;
            final isTallEnoughForSidebar = constraints.maxHeight >= 500;

            Widget playlistContent = Column(
              children: [
                Expanded(
                  flex: 14,
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: getPlaylistWidgetByPlaylistType(
                      playlists,
                      DJPlaylistType.hotspot,
                    ),
                  ),
                ),
                Expanded(
                  flex: 40,
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers:
                        getPlaylistWidgetByPlaylistType(
                          playlists,
                          DJPlaylistType.match,
                        ) +
                        getPlaylistWidgetByPlaylistType(
                          playlists,
                          DJPlaylistType.funStuff,
                        ) +
                        getPlaylistWidgetByPlaylistType(
                          playlists,
                          DJPlaylistType.preMatch,
                        ),
                  ),
                ),
              ],
            );

            // Tablet / macOS: sidebar on the right
            if (isWide && isTallEnoughForSidebar) {
              return Row(
                children: [
                  Expanded(
                    flex: 93,
                    child: Column(
                      children: [
                        const SafeArea(child: SizedBox()),
                        Expanded(child: playlistContent),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 7,
                    child: Container(
                      color: Colors.red,
                      child: CenterControlWidget(
                        onResume: () async => resumePlayer(),
                        onPause: () async => pausePlayer(),
                        onBack: () async {
                          Navigator.of(context).pop();
                          widget.refreshCallback?.call();
                        },
                        refreshCallback: widget.refreshCallback,
                      ),
                    ),
                  ),
                ],
              );
            }

            // Portrait / landscape phone: compact bar at bottom
            return Column(
              children: [
                const SafeArea(bottom: false, child: SizedBox()),
                Expanded(child: playlistContent),
                _buildCompactControls(),
              ],
            );
          },
        ),
    );
  }
}
