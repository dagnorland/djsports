import 'package:djsports/data/models/djplaylist_model.dart';
import 'package:djsports/data/provider/djplaylist_provider.dart';
import 'package:djsports/data/repo/spotify_remote_repository.dart';
import 'package:djsports/features/playlist/widgets/djcenter_track_view.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class DJCenterSliverViewPage extends StatefulHookConsumerWidget {
  const DJCenterSliverViewPage({super.key, this.refreshCallback});
  final VoidCallback? refreshCallback;

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _DJCenterSliverViewPageState();
}

class _DJCenterSliverViewPageState
    extends ConsumerState<DJCenterSliverViewPage> {
  bool spotifyConnect = false;
  bool spotifyRemoteConnect = false;
  bool isPlaying = false;

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
        backgroundColor: Colors.black,
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
              color: Colors.black,
              child: DJCenterTrackView(
                playlistName: playlistList[index].name,
                type: playlistList[index].type,
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

  @override
  Widget build(BuildContext context) {
    final playlists = ref.watch(typeFilteredAllDataProvider);

    return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.backspace),
              onPressed: () {
                Navigator.of(context).pop();
                widget.refreshCallback ?? widget.refreshCallback;
              },
            ),
            title: const Text(
              'dj CENTER SLIVER',
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
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: getSliversByType(playlists, DJPlaylistType.score) +
                getSliversByType(playlists, DJPlaylistType.event) +
                getSliversByType(playlists, DJPlaylistType.fireUp) +
                getSliversByType(playlists, DJPlaylistType.tracks),
          ),
        ));
  }
}
