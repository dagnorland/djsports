import 'package:djsports/data/models/spotify_connection_log.dart';
import 'package:djsports/data/provider/djplaylist_provider.dart';
import 'package:djsports/data/provider/djtrack_provider.dart';
import 'package:djsports/data/repo/spotify_remote_repository.dart';
import 'package:djsports/features/djmatch_center/djmatch_center.dart';
import 'package:djsports/features/djmatch_center/widgets/current_volume_widget.dart';
import 'package:djsports/features/playlist/djplaylist_edit_create.dart';
import 'package:djsports/features/playlist/widgets/djplaylist_view.dart';
import 'package:djsports/features/playlist/widgets/type_filter.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:spotify_sdk/models/connection_status.dart';
import 'package:spotify_sdk/spotify_sdk.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

class HomePage extends StatefulHookConsumerWidget {
  const HomePage({super.key});
  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  bool spotifyConnect = false;
  bool spotifyRemoteConnect = false;
  bool isPlaying = false;

  Future<void> _spotifyConnect(BuildContext context, WidgetRef ref) async {
    final spotifyRemoteService = ref.read(spotifyRemoteRepositoryProvider);
    spotifyConnect = await spotifyRemoteService.connect();
    SpotifyConnectionLog().debugPrintLog();
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

  @override
  Widget build(BuildContext context) {
    if (!spotifyConnect) {
      _spotifyConnect(context, ref);
    }
    final playlistList = ref.watch(typeFilteredAllDataProvider);

    FlutterNativeSplash.remove();

    return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: StreamBuilder<ConnectionStatus>(
          stream: SpotifySdk.subscribeConnectionStatus(),
          builder: (context, snapshot) {
            var data = snapshot.data;
            if (data != null) {
              spotifyRemoteConnect = data.connected;
              if (!spotifyRemoteConnect) {
                SpotifyConnectionLog().addSimpleEntry(
                    SpotifyConnectionStatus.notConnected,
                    'Connected to Spotify');
                ref.read(spotifyRemoteRepositoryProvider).connect();
              }
            }
            isPlaying = ref.read(spotifyRemoteRepositoryProvider).isPlaying;
            return Scaffold(
              backgroundColor: Colors.white,
              appBar: AppBar(
                centerTitle: true,
                backgroundColor: Colors.white,
                elevation: 0,
                title: const Text(
                  'djsports',
                  style: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold),
                ),
                actions: [
                  const CurrentVolumeWidget(),
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
                  Padding(
                    padding: const EdgeInsets.only(right: 5.0),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor),
                      child: Text(
                        'New playlist',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge!
                            .copyWith(color: Colors.white),
                      ),
                      onPressed: () {
                        ref.invalidate(typeFilteredAllDataProvider);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DJPlaylistEditScreen.empty(),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 5.0),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: ref
                                  .read(spotifyRemoteRepositoryProvider)
                                  .isConnected
                              ? Colors.green.shade700
                              : Colors.red.shade700),
                      child: Text(
                        ref.read(spotifyRemoteRepositoryProvider).isConnected
                            ? 'Connected'
                            : 'Connect',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge!
                            .copyWith(color: Colors.white),
                      ),
                      onPressed: () {
                        setState(() {
                          _spotifyConnect(context, ref);
                          if (ref
                              .read(spotifyRemoteRepositoryProvider)
                              .isConnected) {}
                        });
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 5.0),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent.shade700),
                      child: Text(
                        'djMatchCenter',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge!
                            .copyWith(color: Colors.white),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DJMatchCenterViewPage(
                              refreshCallback: () {
                                setState(() {});
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              body: Column(
                children: [
                  const Flexible(child: TypeFilter()),
                  const SizedBox(
                    height: 20,
                  ),
                  playlistList.isEmpty
                      ? const Center(
                          child: Text("No data"),
                        )
                      : Expanded(
                          flex: 10,
                          child: ListView.builder(
                            itemCount: playlistList.length,
                            itemBuilder: (context, index) {
                              return DJPlaylistView(
                                name: playlistList[index].name,
                                type: playlistList[index].type,
                                spotifyUri: playlistList[index].spotifyUri,
                                trackIds: playlistList[index].trackIds,
                                shuffleAtEnd: playlistList[index].shuffleAtEnd,
                                autoNext: playlistList[index].autoNext,
                                currentTrack: playlistList[index].currentTrack,
                                onEdit: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          DJPlaylistEditScreen.fromDJPlaylist(
                                        playlistList[index],
                                        refreshCallback: () {
                                          setState(() {});
                                        },
                                      ),
                                    ),
                                  );
                                },
                                onDelete: () {
                                  ref
                                      .read(hivePlaylistData.notifier)
                                      .removeDJPlaylist(
                                          ref.read(hiveTrackData.notifier),
                                          playlistList[index].id);
                                },
                              );
                            },
                          ),
                        ),
                ],
              ),
            );
          },
        ));
  }
}
