import 'dart:io';
import 'dart:math';

import 'package:djsports/data/models/djplaylist_model.dart';
import 'package:djsports/data/provider/djplaylist_provider.dart';
import 'package:djsports/data/repo/spotify_remote_repository.dart';
import 'package:djsports/features/djmatch_center/widgets/center_control_widget.dart';
import 'package:djsports/features/djmatch_day/widgets/match_day_playlist_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:toastification/toastification.dart';

class DJMatchDayViewPage extends StatefulHookConsumerWidget {
  const DJMatchDayViewPage({super.key, this.refreshCallback});

  final VoidCallback? refreshCallback;

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _DJMatchDayViewPageState();
}

class _DJMatchDayViewPageState extends ConsumerState<DJMatchDayViewPage> {
  bool isPlaying = false;

  @override
  void initState() {
    if (!Platform.isMacOS) {
      FlutterVolumeController.addListener((newVolume) {
        final repo = ref.read(spotifyRemoteRepositoryProvider);
        if ((newVolume - repo.volume).abs() < 0.005) return;
        repo.setVolume(newVolume);
      });
      FlutterVolumeController.getVolume().then((v) {
        if (v != null && mounted) {
          ref.read(spotifyRemoteRepositoryProvider).setVolume(v);
          final pct = (v * 100).round();
          final mq = MediaQuery.of(context);
          final bottomMargin =
              (mq.size.width < 600 || mq.size.height < 500) ? 110.0 : 0.0;
          toastification.show(
            context: context,
            title: Text('Volume: $pct%'),
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
    if (!Platform.isMacOS) {
      FlutterVolumeController.removeListener();
    }
    super.dispose();
  }

  Future<bool> pausePlayer() async {
    isPlaying = await ref.read(spotifyRemoteRepositoryProvider).pausePlayer();
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
                return MatchDayPlaylistCard(
                  playlistId: playlist.id,
                  playlistName: playlist.name,
                  playlistType: pType,
                  initialTrackIndex: playlist.currentTrack,
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
      child: CenterControlWidget(
        onResume: () async => resumePlayer(),
        onPause: () async => pausePlayer(),
        onBack: () {
          Navigator.of(context).pop();
          widget.refreshCallback?.call();
        },
        refreshCallback: widget.refreshCallback,
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
                icon: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 32,
                ),
                onPressed: resumePlayer,
              ),
              IconButton(
                icon:
                    const Icon(Icons.pause, color: Colors.white, size: 32),
                onPressed: pausePlayer,
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
                  Icons.backspace,
                  color: Colors.white,
                  size: 24,
                ),
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
              return Row(
                children: [
                  Expanded(
                    flex: 85,
                    child: SafeArea(child: _buildBoard(allPlaylists)),
                  ),
                  Expanded(flex: 15, child: _buildSidebar()),
                ],
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
