import 'dart:async';
import 'dart:io';

import 'package:djsports/data/models/spotify_connection_log.dart';
import 'package:djsports/data/models/djplaylist_model.dart';
import 'package:djsports/data/provider/djplaylist_provider.dart';
import 'package:djsports/data/provider/djtrack_provider.dart';
import 'package:djsports/data/repo/spotify_remote_repository.dart';
import 'package:djsports/data/services/spotify_platform_bridge.dart';
import 'package:djsports/features/djmatch_center/djmatch_center.dart';
import 'package:djsports/features/djmatch_day/djmatch_day.dart';
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
  StreamSubscription<bool>? _connectionSubscription;

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
    _connectionHealthCheckTimer = Timer.periodic(const Duration(minutes: 5), (
      timer,
    ) async {
      final repo = ref.read(spotifyRemoteRepositoryProvider);
      final timeSinceLastConnection = DateTime.now().difference(
        repo.lastConnectionTime,
      );

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
    Stream<bool>? stream;
    if (Platform.isIOS || Platform.isMacOS) {
      stream = SpotifyPlatformBridge().subscribeConnectionStatus();
    } else if (Platform.isAndroid) {
      stream =
          SpotifySdk.subscribeConnectionStatus().map((s) => s.connected);
    }
    _connectionSubscription = stream?.listen(_onConnectionStatus);
    _initializeSpotifyConnection();
    _startConnectionHealthCheck();
  }

  void _onConnectionStatus(bool connected) {
    spotifyRemoteConnect = connected;
    if (!connected && !_isReconnecting) {
      _isReconnecting = true;
      SpotifyConnectionLog().addSimpleEntry(
        SpotifyConnectionStatus.notConnected,
        'Disconnected from Spotify',
      );
      ref
          .read(spotifyRemoteRepositoryProvider)
          .connect()
          .then((success) {
            if (success) {
              _isReconnecting = false;
              if (mounted) {
                setState(() => spotifyConnect = true);
                debugPrint('Spotify Remote re-connected successfully');
              }
            } else {
              Future.delayed(const Duration(seconds: 5), () {
                _isReconnecting = false;
                if (mounted) setState(() => spotifyConnect = false);
              });
            }
          })
          .catchError((error) {
            debugPrint('Error connecting to Spotify Remote: $error');
            Future.delayed(const Duration(seconds: 5), () {
              _isReconnecting = false;
              if (mounted) setState(() => spotifyConnect = false);
            });
          });
    }
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
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

  void _navigateTo(Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  void _handlePopupAction(String value) {
    switch (value) {
      case 'matchcenter':
        _navigateTo(
          DJMatchCenterViewPage(refreshCallback: () => setState(() {})),
        );
      case 'matchday':
        _navigateTo(
          DJMatchDayViewPage(refreshCallback: () => setState(() {})),
        );
      case 'newplaylist':
        ref.invalidate(typeFilteredAllDataProvider);
        _navigateTo(DJPlaylistEditScreen.empty());
      case 'settings':
        _navigateTo(TrackTimeCenterScreen());
    }
  }

  List<Widget> _buildWideActions(BuildContext context, bool hasToken) {
    return [
      const CurrentVolumeWidget(),
      if (hasToken)
        IconButton(
          onPressed: () => setState(() {
            resumePlayer();
          }),
          icon: Icon(
            Icons.play_arrow,
            color: isPlaying ? Colors.grey : Colors.green,
          ),
        ),
      if (hasToken)
        IconButton(
          onPressed: () => setState(() {
            pausePlayer();
          }),
          icon: Icon(
            Icons.pause,
            color: isPlaying ? Colors.green : Colors.grey,
          ),
        ),
      Tooltip(
        message: 'Utilities',
        child: IconButton(
          icon: const Icon(Icons.settings, color: Colors.black),
          onPressed: () => _navigateTo(TrackTimeCenterScreen()),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(right: 5),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
          ),
          onPressed: () {
            ref.invalidate(typeFilteredAllDataProvider);
            _navigateTo(DJPlaylistEditScreen.empty());
          },
          child: Text(
            'New playlist',
            style: Theme.of(
              context,
            ).textTheme.titleLarge!.copyWith(color: Colors.white),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(right: 5),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: hasToken
                ? Colors.green.shade700
                : Colors.red.shade700,
          ),
          onPressed: () async {
            await _spotifyConnect(context, ref);
            if (mounted) setState(() {});
          },
          child: Text(
            hasToken ? 'Connected' : 'Connect',
            style: Theme.of(
              context,
            ).textTheme.titleLarge!.copyWith(color: Colors.white),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(right: 5),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent.shade700,
          ),
          onPressed: () => _navigateTo(
            DJMatchCenterViewPage(refreshCallback: () => setState(() {})),
          ),
          child: Text(
            'djMatchCenter',
            style: Theme.of(
              context,
            ).textTheme.titleLarge!.copyWith(color: Colors.white),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(right: 5),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple.shade700,
          ),
          onPressed: () => _navigateTo(
            DJMatchDayViewPage(refreshCallback: () => setState(() {})),
          ),
          child: Text(
            'djMatchDay',
            style: Theme.of(
              context,
            ).textTheme.titleLarge!.copyWith(color: Colors.white),
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildNarrowActions(BuildContext context, bool hasToken) {
    return [
      const CurrentVolumeWidget(),
      if (hasToken)
        IconButton(
          onPressed: () => setState(() {
            resumePlayer();
          }),
          icon: Icon(
            Icons.play_arrow,
            size: 22,
            color: isPlaying ? Colors.grey : Colors.green,
          ),
        ),
      if (hasToken)
        IconButton(
          onPressed: () => setState(() {
            pausePlayer();
          }),
          icon: Icon(
            Icons.pause,
            size: 22,
            color: isPlaying ? Colors.green : Colors.grey,
          ),
        ),
      IconButton(
        icon: Icon(
          hasToken ? Icons.wifi : Icons.wifi_off,
          color: hasToken ? Colors.green : Colors.red,
        ),
        tooltip: hasToken ? 'Spotify Connected' : 'Connect Spotify',
        onPressed: () async {
          await _spotifyConnect(context, ref);
          if (mounted) setState(() {});
        },
      ),
      PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, color: Colors.black),
        onSelected: _handlePopupAction,
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'matchcenter',
            child: Row(
              children: [
                Icon(Icons.grid_view, color: Colors.blueAccent.shade700),
                const SizedBox(width: 10),
                const Text('djMatchCenter'),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'matchday',
            child: Row(
              children: [
                Icon(Icons.event, color: Colors.deepPurple.shade700),
                const SizedBox(width: 10),
                const Text('djMatchDay'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'newplaylist',
            child: Row(
              children: [
                Icon(Icons.playlist_add),
                SizedBox(width: 10),
                Text('New playlist'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'settings',
            child: Row(
              children: [
                Icon(Icons.settings),
                SizedBox(width: 10),
                Text('Utilities'),
              ],
            ),
          ),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final playlistList = ref.watch(typeFilteredAllDataProvider);
    final packageInfo = useFuture(useMemoized(PackageInfo.fromPlatform));
    isPlaying = ref.read(spotifyRemoteRepositoryProvider).isPlaying;

    final isWide = MediaQuery.of(context).size.width >= 1000;
    final hasToken =
        ref.read(spotifyRemoteRepositoryProvider).hasSpotifyAccessToken;
    final version = packageInfo.data?.version;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: false,
          leading: isWide
              ? Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'v${version ?? '...'}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.black54,
                      ),
                    ),
                  ),
                )
              : null,
          title: isWide
              ? const Text(
                  'djsports',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'djsports',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (version != null)
                      Text(
                        'v$version',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.black54,
                        ),
                      ),
                  ],
                ),
          actions: isWide
              ? _buildWideActions(context, hasToken)
              : _buildNarrowActions(context, hasToken),
        ),
        body: Column(
          children: [
            const Flexible(child: TypeFilter()),
            const SizedBox(height: 12),
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
      ),
    );
  }
}
