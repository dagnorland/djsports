import 'package:djsports/data/models/djplaylist_model.dart';
import 'package:djsports/data/provider/djplaylist_provider.dart';
import 'package:djsports/data/repo/spotify_remote_repository.dart';
import 'package:djsports/features/djmatch_center/widgets/current_volume_widget.dart';
import 'package:djsports/features/djmatch_center/widgets/djmatch_center_playlist_tracks_carousel.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:volume_controller/volume_controller.dart';

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

  List<Widget> getSliversByType(
      List<DJPlaylist> playlistList, DJPlaylistType playlistType) {
    List<DJPlaylist> filteredPlaylists = playlistList
        .where((playlist) => playlist.type == playlistType.name.toString())
        .toList();
    return getSlivers(filteredPlaylists, playlistType);
  }

  List<Widget> getSlivers(
      List<DJPlaylist> playlistList, DJPlaylistType playlistType) {
    const constGridItemWidth = 290;
    return <Widget>[
      SliverAppBar(
        toolbarHeight: 20,
        backgroundColor: playlistType.color,
        pinned: playlistType.name == DJPlaylistType.hotspot.name ? true : false,
        expandedHeight: 20.0,
        leading: Text(playlistType.name.toString(),
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14.0)),
      ),
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
                playlistName: playlistList[index].name,
                playlistType: playlistList[index].type,
                spotifyUri: playlistList[index].spotifyUri,
                trackIds: playlistList[index].trackIds,
                currentTrack: playlistList[index].currentTrack,
                parentWidthSize: constGridItemWidth,
              ),
            );
          },
          childCount: playlistList.length,
        ),
      ),
    ];
  }

  Widget getImageWidget(String networkImageUri, double width, double height) {
    return networkImageUri.isEmpty
        ? const Icon(Icons.featured_play_list_outlined, size: 10)
        : Image.network(networkImageUri, width: width, height: height);
  }

  Widget soundControlWidget() {
    return SliverToBoxAdapter(
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.pause, color: Colors.white, size: 70),
            onPressed: () {
              setState(() {
                pausePlayer();
              });
            },
          ),
          const Gap(20),
          IconButton(
            icon: const Icon(Icons.volume_down, color: Colors.white, size: 50),
            onPressed: () {
              setState(() {
                ref.read(spotifyRemoteRepositoryProvider).adjustVolume(-0.1);
              });
            },
          ),
          const Gap(10),
          const CurrentVolumeWidget(),
          const Gap(20),
          IconButton(
            icon: const Icon(Icons.volume_up, color: Colors.white, size: 70),
            onPressed: () {
              setState(() {
                ref.read(spotifyRemoteRepositoryProvider).adjustVolume(0.1);
              });
            },
          ),
          const Gap(20),
          getImageWidget(
              ref.read(spotifyRemoteRepositoryProvider).latestImageUri, 50, 50),
          const Gap(20),
          InkWell(
            onTap: () {
              ref.read(spotifyRemoteRepositoryProvider).playTrack(ref
                  .read(spotifyRemoteRepositoryProvider)
                  .latestTrack
                  .spotifyUri);
            },
            child: Chip(
                avatar: const Icon(Icons.play_arrow, color: Colors.black),
                label: Text(ref
                    .read(spotifyRemoteRepositoryProvider)
                    .getLastPlayedInfo())),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playlists = ref.watch(typeFilteredAllDataProvider);

    return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.backspace),
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.refreshCallback ?? widget.refreshCallback;
                },
              ),
              title: const Text(
                'djMatchCenter',
                style:
                    TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
              actions: [
                ref.read(spotifyRemoteRepositoryProvider).isConnected
                    ? IconButton(
                        onPressed: () {
                          setState(() {
                            resumePlayer();
                          });
                        },
                        icon: Icon(Icons.play_arrow,
                            color: isPlaying ? Colors.grey : Colors.green),
                      )
                    : Container(),
                ref.read(spotifyRemoteRepositoryProvider).isConnected
                    ? IconButton(
                        onPressed: () {
                          setState(() {
                            pausePlayer();
                          });
                        },
                        icon: Icon(Icons.pause,
                            color: isPlaying ? Colors.green : Colors.grey),
                      )
                    : Container(),
              ],
            ),
            body: Column(
              children: [
                Expanded(
                    flex: 15,
                    child: CustomScrollView(
                        physics: const BouncingScrollPhysics(),
                        slivers: getSliversByType(
                                playlists, DJPlaylistType.hotspot) +
                            [soundControlWidget()])),
                Expanded(
                    flex: 20,
                    child: CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: getSliversByType(
                              playlists, DJPlaylistType.match) +
                          getSliversByType(playlists, DJPlaylistType.funStuff) +
                          getSliversByType(playlists, DJPlaylistType.preMatch),
                    ))
              ],
            )));
  }
}
