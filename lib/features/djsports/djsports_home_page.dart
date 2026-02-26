import 'dart:async';
import 'dart:io';

import 'package:djsports/data/models/spotify_connection_log.dart';
import 'package:djsports/data/models/djplaylist_model.dart';
import 'package:djsports/data/provider/djplaylist_provider.dart';
import 'package:djsports/data/provider/djtrack_provider.dart';
import 'package:djsports/data/repo/spotify_remote_repository.dart';
import 'package:djsports/data/services/spotify_platform_bridge.dart';
import 'package:djsports/features/djmatch_center/djmatch_center.dart';
import 'package:djsports/features/djmatch_center/widgets/current_volume_widget.dart';
import 'package:djsports/features/playlist/djplaylist_edit_create.dart';
import 'package:djsports/features/playlist/widgets/djplaylist_view.dart';
import 'package:djsports/features/playlist/widgets/type_filter.dart';
import 'package:djsports/features/track_time/track_time_center_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:spotify_sdk/spotify_sdk.dart';

class HomePage extends StatefulHookConsumerWidget {
  const HomePage({super.key});
  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  bool spotifyConnect = false;
  bool spotifyRemoteConnect = false;
  bool isPlaying = false;
  bool initStateConnectDone = false;
  bool _isReconnecting = false;
  Timer? _connectionHealthCheckTimer;
  Stream<bool>? _connectionStatusStream;

  Future<void> _spotifyConnect(BuildContext context, WidgetRef ref) async {
    final spotifyRemoteService = ref.read(spotifyRemoteRepositoryProvider);
    spotifyConnect = await spotifyRemoteService.connect();
    debugPrint('_spotifyConnect: $spotifyConnect');
  }

  Future<bool> pausePlayer() async {
    {
      isPlaying = await ref.read(spotifyRemoteRepositoryProvider).pausePlayer();
      return isPlaying;
    }
  }

  Future<bool> resumePlayer() async {
    {
      isPlaying = await ref
          .read(spotifyRemoteRepositoryProvider)
          .resumePlayer();
      return isPlaying;
    }
  }

  void _startConnectionHealthCheck() {
    // Check connection health every 5 minutes
    _connectionHealthCheckTimer = Timer.periodic(const Duration(minutes: 5), (
      timer,
    ) async {
      final repo = ref.read(spotifyRemoteRepositoryProvider);
      final timeSinceLastConnection = DateTime.now().difference(
        repo.lastConnectionTime,
      );

      // If more than 45 minutes since last connection, proactively refresh token
      if (timeSinceLastConnection.inMinutes > 45 &&
          repo.hasSpotifyAccessToken) {
        debugPrint(
          'Proactive connection refresh after $timeSinceLastConnection',
        );
        try {
          await repo.connectAccessToken();
          if (mounted) {
            setState(() {
              spotifyConnect = repo.hasSpotifyAccessToken;
            });
          }
        } catch (error) {
          debugPrint('Error during health check reconnection: $error');
        }
      }
    });
  }

  @override
  void initState() {
    super.initState();
    // Create the stream ONCE here — never inside build().
    // Recreating it on every build() causes onListen to fire each rebuild,
    // which emits an initial event, which triggers setState, which rebuilds
    // again → continuous rebuild loop and high CPU.
    if (Platform.isIOS || Platform.isMacOS) {
      _connectionStatusStream = SpotifyPlatformBridge()
          .subscribeConnectionStatus();
    } else if (Platform.isAndroid) {
      _connectionStatusStream = SpotifySdk.subscribeConnectionStatus().map(
        (s) => s.connected,
      );
    }
    _initializeSpotifyConnection();
    _startConnectionHealthCheck();
  }

  @override
  void dispose() {
    _connectionHealthCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeSpotifyConnection() async {
    try {
      await _spotifyConnect(context, ref);
      if (mounted) {
        setState(() {
          initStateConnectDone = true;
        });
      }
    } catch (error) {
      if (mounted) {
        debugPrint('Error initializing Spotify connection: $error');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    //if (!spotifyConnect) {
    //  _spotifyConnect(context, ref);
    //}
    final playlistList = ref.watch(typeFilteredAllDataProvider);
    final packageInfo = useFuture(useMemoized(PackageInfo.fromPlatform));

    // FlutterNativeSplash.remove();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: StreamBuilder<bool>(
        stream: _connectionStatusStream ?? const Stream<bool>.empty(),
        builder: (context, snapshot) {
          var data = snapshot.data;
          if (data != null) {
            spotifyRemoteConnect = data;
            if (!spotifyRemoteConnect && !_isReconnecting) {
              _isReconnecting = true;
              SpotifyConnectionLog().addSimpleEntry(
                SpotifyConnectionStatus.notConnected,
                'Disconnected from Spotify',
              );
              // Reconnect automatically (guarded to prevent storm)
              ref
                  .read(spotifyRemoteRepositoryProvider)
                  .connect()
                  .then((success) {
                    _isReconnecting = false;
                    if (mounted) {
                      setState(() {
                        spotifyConnect = success;
                      });
                      if (success) {
                        debugPrint('Spotify Remote re-connected successfully');
                      }
                    }
                  })
                  .catchError((error) {
                    _isReconnecting = false;
                    debugPrint('Error connecting to Spotify Remote: $error');
                    if (mounted) {
                      setState(() {
                        spotifyConnect = false;
                      });
                    }
                  });
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
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              leading: Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Text(
                  'v${packageInfo.data?.version ?? '...'}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.black54),
                ),
              ),
              actions: [
                const CurrentVolumeWidget(),
                ref.read(spotifyRemoteRepositoryProvider).hasSpotifyAccessToken
                    ? IconButton(
                        onPressed: () {
                          setState(() {
                            resumePlayer();
                          });
                        },
                        icon: Icon(
                          Icons.play_arrow,
                          color: isPlaying ? Colors.grey : Colors.green,
                        ),
                      )
                    : Container(),
                ref.read(spotifyRemoteRepositoryProvider).hasSpotifyAccessToken
                    ? IconButton(
                        onPressed: () {
                          setState(() {
                            pausePlayer();
                          });
                        },
                        icon: Icon(
                          Icons.pause,
                          color: isPlaying ? Colors.green : Colors.grey,
                        ),
                      )
                    : Container(),
                Tooltip(
                  message: 'Utilities',
                  child: IconButton(
                    icon: const Icon(Icons.settings, color: Colors.black),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TrackTimeCenterScreen(),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 5.0),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                    ),
                    child: Text(
                      'New playlist',
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge!.copyWith(color: Colors.white),
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
                      backgroundColor:
                          ref
                              .read(spotifyRemoteRepositoryProvider)
                              .hasSpotifyAccessToken
                          ? Colors.green.shade700
                          : Colors.red.shade700,
                    ),
                    child: Text(
                      ref
                              .read(spotifyRemoteRepositoryProvider)
                              .hasSpotifyAccessToken
                          ? 'Connected'
                          : 'Connect',
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge!.copyWith(color: Colors.white),
                    ),
                    onPressed: () async {
                      await _spotifyConnect(context, ref);
                      if (mounted) {
                        setState(() {
                          if (ref
                              .read(spotifyRemoteRepositoryProvider)
                              .hasSpotifyAccessToken) {}
                        });
                      }
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 5.0),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent.shade700,
                    ),
                    child: Text(
                      'djMatchCenter',
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge!.copyWith(color: Colors.white),
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
                const SizedBox(height: 20),
                playlistList.isEmpty
                    ? const Center(
                        child: Text(
                          'Make some playlists, and let the game begin!',
                        ),
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
                              onTypeChanged: (newType) {
                                final playlist = playlistList[index];
                                ref
                                    .read(hivePlaylistData.notifier)
                                    .updateDJPlaylist(
                                      DJPlaylist(
                                        id: playlist.id,
                                        name: playlist.name,
                                        type: newType,
                                        spotifyUri: playlist.spotifyUri,
                                        shuffleAtEnd: playlist.shuffleAtEnd,
                                        trackIds: playlist.trackIds,
                                        currentTrack: playlist.currentTrack,
                                        playCount: playlist.playCount,
                                        autoNext: playlist.autoNext,
                                        position: playlist.position,
                                      ),
                                    );
                                setState(() {});
                              },
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
                                      playlistList[index].id,
                                    );
                              },
                            );
                          },
                        ),
                      ),
              ],
            ),
          );
        },
      ),
    );
  }
}
