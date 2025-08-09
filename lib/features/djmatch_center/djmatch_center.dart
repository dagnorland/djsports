import 'package:djsports/data/models/djplaylist_model.dart';
import 'package:djsports/data/provider/djplaylist_provider.dart';
import 'package:djsports/data/provider/djtrack_provider.dart';
import 'package:djsports/data/repo/spotify_remote_repository.dart';
import 'package:djsports/features/djmatch_center/widgets/djmatch_center_playlist_tracks_carousel.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:djsports/features/djmatch_center/widgets/center_control_widget.dart';
import 'package:djsports/data/repo/last_djtrack_played_repository.dart';

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

  @override
  void initState() {
    VolumeController().listener((volume) {
      ref.read(spotifyRemoteRepositoryProvider).setVolume(volume);
    });
    super.initState();
  }

  @override
  void dispose() {
    VolumeController().removeListener();
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
      isPlaying =
          await ref.read(spotifyRemoteRepositoryProvider).resumePlayer();
      return isPlaying;
    }
  }

  List<Widget> getPlaylistWidgetByPlaylistType(
      List<DJPlaylist> playlistList, DJPlaylistType playlistType) {
    List<DJPlaylist> filteredPlaylists = playlistList
        .where((playlist) => playlist.type == playlistType.name.toString())
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));

    return getPlaylistWidget(filteredPlaylists, playlistType);
  }

  List<Widget> getPlaylistWidget(
      List<DJPlaylist> playlistList, DJPlaylistType playlistType) {
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
        delegate: SliverChildBuilderDelegate(
          (BuildContext context, int index) {
            return Container(
              margin: const EdgeInsets.all(0.0),
              child: DJCenterPlaylistTracksCarousel(
                playlistId: playlistList[index].id,
                playlistName: playlistList[index].name,
                playlistType: DJPlaylistType.values.firstWhere(
                    (type) => type.name == playlistList[index].type),
                spotifyUri: playlistList[index].spotifyUri,
                currentTrack: playlistList[index].currentTrack,
                parentWidthSize: constGridItemWidth,
              ),
            );
          },
          childCount: playlistList.length,
        ),
      ),
      SliverToBoxAdapter(
        child: Divider(
          color: playlistType.color,
          height: 5,
          thickness: 5,
        ),
      ),
    ];
  }

  Widget getImageWidget(String networkImageUri, double width, double height) {
    return networkImageUri.isEmpty
        ? const Icon(Icons.featured_play_list_outlined, size: 10)
        : Image.network(networkImageUri,
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
                ));
  }

  @override
  Widget build(BuildContext context) {
    final playlists = ref.watch(typeFilteredAllDataProvider);
    final tracksWithShortcut = ref.watch(dataTrackWithShortcutProvider);

    return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
            backgroundColor: Colors.black,
            body: Row(
              children: [
                Expanded(
                  flex: 93,
                  child: Column(
                    children: [
                      const SafeArea(
                        child: SizedBox(),
                      ),
                      Expanded(
                          flex: 13,
                          child: CustomScrollView(
                              physics: const BouncingScrollPhysics(),
                              slivers: getPlaylistWidgetByPlaylistType(
                                  playlists, DJPlaylistType.hotspot))),
                      Divider(
                        color: DJPlaylistType.hotspot.color,
                        height: 1,
                        thickness: 2,
                      ),
                      Expanded(
                          flex: 5,
                          child: Container(
                            color: Colors.yellow,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              itemCount: tracksWithShortcut.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (context, index) {
                                final track = tracksWithShortcut[index];
                                final label = track.shortcut
                                    .padLeft(2, '0')
                                    .substring(
                                      track.shortcut.padLeft(2, '0').length - 2,
                                    );

                                return SizedBox(
                                  width: 56,
                                  height: 56,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      shape: const CircleBorder(),
                                      padding: EdgeInsets.zero,
                                      backgroundColor: Colors.black,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () async {
                                      final response = await ref
                                          .read(spotifyRemoteRepositoryProvider)
                                          .playTrackAndJumpStart(
                                            track,
                                            track.startTime + track.startTimeMS,
                                            DJPlaylistType.hotspot,
                                            'Shortcuts',
                                          );

                                      if (response.contains('[ErrorMessage]')) {
                                        showMessageToast(response);
                                      } else {
                                        track.playCount = track.playCount + 1;
                                        ref
                                            .read(hiveTrackData.notifier)
                                            .updateDJTrack(track);
                                        showMessageToast(response);
                                        await ref
                                            .read(lastDjTrackPlayedProvider
                                                .notifier)
                                            .updateLastPlayedTrack(track);
                                      }
                                    },
                                    child: Text(
                                      label,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          )),
                      Expanded(
                          flex: 40,
                          child: CustomScrollView(
                            physics: const BouncingScrollPhysics(),
                            slivers: getPlaylistWidgetByPlaylistType(
                                    playlists, DJPlaylistType.match) +
                                getPlaylistWidgetByPlaylistType(
                                    playlists, DJPlaylistType.funStuff) +
                                getPlaylistWidgetByPlaylistType(
                                    playlists, DJPlaylistType.preMatch),
                          ))
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
            )));
  }
}
