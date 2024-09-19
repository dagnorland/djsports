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
        ///Properties of app bar
        backgroundColor: Colors.white,
        floating: false,
        pinned: true,
        expandedHeight: 10.0,

        ///Properties of the App Bar when it is expanded
        flexibleSpace: FlexibleSpaceBar(
          centerTitle: false,
          titlePadding: const EdgeInsets.only(left: 120.0, bottom: 20.0),
          title: Text(
            playlistType.name.toUpperCase(),
            style: const TextStyle(
                color: Colors.black87,
                fontSize: 12.0,
                fontWeight: FontWeight.bold),
          ),
        ),
      ),
      SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          /// Calculate the number of items in the horizontal axis based on screen width
          crossAxisCount:
              (MediaQuery.of(context).size.width / constGridItemWidth).floor(),
          mainAxisExtent: 175,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),

        ///Lazy building of list
        delegate: SliverChildBuilderDelegate(
          (BuildContext context, int index) {
            /// To convert this infinite list to a list with "n" no of items,
            /// uncomment the following line:
            /// if (index > n) return null;
            ///
            return DJCenterTrackView(
              playlistName: playlistList[index].name,
              type: playlistList[index].type,
              spotifyUri: playlistList[index].spotifyUri,
              trackIds: playlistList[index].trackIds,
              currentTrack: playlistList[index].currentTrack,
              parentWidthSize: constGridItemWidth,
            );
          },

          /// Set childCount to limit no.of items
          /// childCount: 100,
          ///
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
            slivers: getSliversByType(playlists, DJPlaylistType.score) +
                getSliversByType(playlists, DJPlaylistType.event) +
                getSliversByType(playlists, DJPlaylistType.fireUp) +
                getSliversByType(playlists, DJPlaylistType.tracks),
          ),
        ));
  }

  Widget listItem(Color color, String title) => Container(
        height: 100.0,
        color: color,
        child: Center(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10.0,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
}

//          body: GridView.count(
//            crossAxisCount: 4,
//            childAspectRatio: .4,
//            controller: ScrollController(keepScrollOffset: false),
//            shrinkWrap: false,
//            scrollDirection: Axis.horizontal,
//            crossAxisSpacing: 5,
//            mainAxisSpacing: 5,
//            children: List.generate(playlistList.length, (index) {
//              return DJCenterTrackView(
//                name: playlistList[index].name,
//                type: playlistList[index].type,
//                spotifyUri: playlistList[index].spotifyUri,
//                trackIds: playlistList[index].trackIds,
//                currentTrack: playlistList[index].currentTrack,
//              );
//            }),
//          ),
