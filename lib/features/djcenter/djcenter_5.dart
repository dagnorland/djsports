import 'package:djsports/data/provider/djplaylist_provider.dart';
import 'package:djsports/data/repo/spotify_remote_repository.dart';
import 'package:djsports/features/playlist/widgets/djcenter5_view.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class DJCenter5Page extends StatefulHookConsumerWidget {
  const DJCenter5Page({super.key, this.refreshCallback});
  final VoidCallback? refreshCallback;

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _DJCenter5PageState();
}

class _DJCenter5PageState extends ConsumerState<DJCenter5Page> {
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
              'dj CENTER FIVE',
              style:
                  TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
          body: Column(
            children: [
              playlistList.isEmpty
                  ? const Center(
                      child: Text("No data"),
                    )
                  : Expanded(
                      flex: 10,
                      child: ListView.builder(
                        itemCount:
                            playlistList.length > 5 ? 5 : playlistList.length,
                        itemBuilder: (context, index) {
                          return DJCenter5View(
                            name: playlistList[index].name,
                            type: playlistList[index].type,
                            spotifyUri: playlistList[index].spotifyUri,
                            trackIds: playlistList[index].trackIds,
                          );
                        },
                      ),
                    ),
            ],
          ),
        ));
  }
}
