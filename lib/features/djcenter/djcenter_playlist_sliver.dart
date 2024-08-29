import 'package:djsports/data/provider/djplaylist_provider.dart';
import 'package:djsports/data/repo/spotify_remote_repository.dart';
import 'package:djsports/features/playlist/widgets/djcenter5_track_view.dart';
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

  @override
  Widget build(BuildContext context) {
    final playlistList = ref.watch(typeFilteredDataProvider);

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
          ),
          body: CustomScrollView(
            slivers: <Widget>[
              ///First sliver is the App Bar
              SliverAppBar(
                ///Properties of app bar
                backgroundColor: Colors.white,
                floating: false,
                pinned: true,
                expandedHeight: 200.0,

                ///Properties of the App Bar when it is expanded
                flexibleSpace: FlexibleSpaceBar(
                  centerTitle: true,
                  titlePadding: const EdgeInsets.only(left: 20.0, bottom: 20.0),
                  title: const Text(
                    "dj CENTER SLIVER",
                    style: TextStyle(
                        color: Colors.black87,
                        fontSize: 12.0,
                        fontWeight: FontWeight.bold),
                  ),
                  background: Container(
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: Colors.black26,
                          width: 1.0,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  ///no.of items in the horizontal axis
                  crossAxisCount: 4,
                  mainAxisExtent: 200,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),

                ///Lazy building of list
                delegate: SliverChildBuilderDelegate(
                  (BuildContext context, int index) {
                    /// To convert this infinite list to a list with "n" no of items,
                    /// uncomment the following line:
                    /// if (index > n) return null;
                    return DJCenterTrackView(
                      name: playlistList[index].name,
                      type: playlistList[index].type,
                      spotifyUri: playlistList[index].spotifyUri,
                      trackIds: playlistList[index].trackIds,
                      currentTrack: playlistList[index].currentTrack,
                    );
                  },

                  /// Set childCount to limit no.of items
                  /// childCount: 100,
                  ///
                  childCount: playlistList.length,
                ),
              )
            ],
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
