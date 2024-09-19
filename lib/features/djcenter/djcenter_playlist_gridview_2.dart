import 'package:djsports/data/provider/djplaylist_provider.dart';
import 'package:djsports/data/repo/spotify_remote_repository.dart';
import 'package:djsports/features/playlist/widgets/djcenter_track_view.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class DJCenterGridviewPage extends StatefulHookConsumerWidget {
  const DJCenterGridviewPage({super.key, this.refreshCallback});
  final VoidCallback? refreshCallback;

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _DJCenterGridViewPageState();
}

class _DJCenterGridViewPageState extends ConsumerState<DJCenterGridviewPage> {
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
    final playlistList = ref.watch(typeFilteredAllDataProvider);

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
              'dj CENTER GRID',
              style:
                  TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
          body: GridView.count(
            crossAxisCount: 4,
            childAspectRatio: .4,
            controller: ScrollController(keepScrollOffset: false),
            shrinkWrap: false,
            scrollDirection: Axis.horizontal,
            crossAxisSpacing: 5,
            mainAxisSpacing: 5,
            children: List.generate(playlistList.length, (index) {
              return DJCenterTrackView(
                playlistName: playlistList[index].name,
                type: playlistList[index].type,
                spotifyUri: playlistList[index].spotifyUri,
                trackIds: playlistList[index].trackIds,
                currentTrack: playlistList[index].currentTrack,
                parentWidthSize: 200,
              );
            }),
          ),
        ));
  }
}
