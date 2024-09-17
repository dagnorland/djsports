import 'package:djsports/data/provider/djplaylist_provider.dart';
import 'package:djsports/data/repo/spotify_remote_repository.dart';
import 'package:djsports/features/playlist/widgets/djcenter5_track_view.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class DJCenterCarouselPage extends StatefulHookConsumerWidget {
  const DJCenterCarouselPage({super.key, this.refreshCallback});
  final VoidCallback? refreshCallback;

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _DJCenterCarsouelPageState();
}

class _DJCenterCarsouelPageState extends ConsumerState<DJCenterCarouselPage> {
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
              'dj CENTER CAROUSEL',
              style:
                  TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
          body: SizedBox(
            width: 700,
            child: CarouselView(
              backgroundColor: Colors.white,
              scrollDirection: Axis.vertical,
              itemExtent: 110,
              onTap: (value) {
                debugPrint('onTap $value');
              },
              children: List.generate(playlistList.length, (index) {
                return DJCenterTrackView(
                  name: playlistList[index].name,
                  type: playlistList[index].type,
                  spotifyUri: playlistList[index].spotifyUri,
                  trackIds: playlistList[index].trackIds,
                  currentTrack: playlistList[index].currentTrack,
                );
              }),
            ),
          ),
        ));
  }
}
