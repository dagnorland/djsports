import 'dart:async';
import 'dart:io';

import 'package:djsports/data/models/djplaylist_model.dart';
import 'package:djsports/data/models/spotify_playlist_result.dart';
import 'package:djsports/data/models/djtrack_model.dart';
import 'package:djsports/data/provider/djplaylist_provider.dart';
import 'package:djsports/data/provider/djtrack_provider.dart';
import 'package:djsports/data/provider/track_time_provider.dart';
import 'package:djsports/data/repo/spotify_remote_repository.dart';
import 'package:djsports/data/services/spotify_playlist_service.dart';
import 'package:djsports/data/services/spotify_search_service.dart';
import 'package:djsports/features/playlist/djtrack_edit_create.dart';
import 'package:djsports/features/playlist/widgets/djplaylist_tracks_view.dart';
import 'package:djsports/features/playlist/widgets/djplaylist_type_dropdown.dart';
import 'package:djsports/features/playlist/widgets/playlist_examples_dropdown.dart';
import 'package:djsports/features/spotify_playlist_sync/spotify_playlist_sync_delegate.dart';
import 'package:djsports/features/spotify_search/spotify_search_delegate.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';

// Localization
//models

// Riverpod
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:spotify/spotify.dart';

//Providers

class DJPlaylistEditScreen extends StatefulHookConsumerWidget {
  const DJPlaylistEditScreen({
    super.key,
    required this.name,
    required this.type,
    required this.spotifyUri,
    required this.trackIds,
    required this.shuffleAtEnd,
    required this.autoNext,
    required this.currentTrack,
    required this.position,
    required this.isNew,
    this.status,
    required this.id,
    this.refreshCallback,
  });
  factory DJPlaylistEditScreen.fromDJPlaylist(DJPlaylist playlist,
      {VoidCallback? refreshCallback}) {
    return DJPlaylistEditScreen(
      isNew: false,
      id: playlist.id,
      name: playlist.name,
      type: playlist.type,
      spotifyUri: playlist.spotifyUri,
      trackIds: [...playlist.trackIds],
      shuffleAtEnd: playlist.shuffleAtEnd,
      autoNext: playlist.autoNext,
      currentTrack: playlist.currentTrack,
      position: playlist.position,
      refreshCallback: refreshCallback,
    );
  }

  factory DJPlaylistEditScreen.empty() {
    return DJPlaylistEditScreen(
      name: '',
      type: DJPlaylistType.hotspot.name,
      spotifyUri: '',
      trackIds: const [],
      shuffleAtEnd: true,
      autoNext: true,
      currentTrack: 0,
      position: 10,
      isNew: true,
      id: '',
    );
  }

  final String name;
  final String type;
  final String spotifyUri;
  final bool shuffleAtEnd;
  final bool autoNext;
  final int currentTrack;
  final int position;
  final List<String> trackIds;
  final String id;
  final bool isNew;
  final String? status;
  final VoidCallback? refreshCallback;

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _EditScreenState();
}

class _EditScreenState extends ConsumerState<DJPlaylistEditScreen> {
  final nameController = TextEditingController();
  final spotifyUriController = TextEditingController();
  final positionController = TextEditingController();
  DJPlaylistType selectedType = DJPlaylistType.funStuff;
  List<String> trackIds = [];
  bool shuffleAtEnd = true;
  bool autoNext = true;
  int position = 10;
  int currentTrack = 0;
  String _errorMessage = '';
  List<DJTrack> playlistTrackList = [];

  //FutureOr Function(dynamic value) get result => false;

  @override
  void initState() {
    if (!widget.isNew) {
      nameController.text = widget.name;
      spotifyUriController.text = widget.spotifyUri;
      shuffleAtEnd = widget.shuffleAtEnd;
      autoNext = widget.autoNext;
      position = widget.position;
      positionController.text = position.toString();
      currentTrack = widget.currentTrack;
    } else {
      nameController.text = widget.name;
      spotifyUriController.text = widget.spotifyUri;
      positionController.text = position.toString();
    }
    selectedType =
        DJPlaylistType.values.firstWhere((e) => e.name == widget.type);
    trackIds = widget.trackIds;
    positionController.addListener(_validateInput);
    playlistTrackList = ref.read(hiveTrackData.notifier).getDJTracks(trackIds);
    super.initState();
  }

  void _validateInput() {
    final text = positionController.text;
    if (text.isEmpty) {
      setState(() {
        _errorMessage = 'Value cannot be empty';
      });
      return;
    }

    final value = int.tryParse(text);
    if (value == null || value < 1 || value > 99) {
      setState(() {
        _errorMessage = 'Value must be between 1 and 99';
      });
    } else {
      setState(() {
        _errorMessage = '';
      });
    }
  }

  Future<void> _spotifyPlaylistSync(
      BuildContext context, WidgetRef ref, String playlistUri) async {
    String playlistId = widget.id;

    if (playlistId.isEmpty && playlistUri.isNotEmpty) {
      try {
        playlistId = newPlaylistFromFormData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString()),
          ));
        }
        return;
      }
    }

    if (widget.isNew && playlistId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Playlist must be saved before syncing'),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Close',
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ));
      }
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Syncronising playlist tracks...'),
          duration: Duration(seconds: 2),
        ),
      );
    }

    DJPlaylist? playlist = ref
        .read(hivePlaylistData.notifier)
        .repo
        .getDJPlaylists()
        .firstWhere((element) => element.id == playlistId);

    List<String> existingTrackSpotifyUris = ref
        .read(hiveTrackData.notifier)
        .getDJTracksSpotifyUri(playlist.trackIds);
    final service = ref.read(playlistServiceProvider);

    Iterable<Track> result = await service.searchRepository
        .getTracksByUri(playlistUri)
        .then((value) => value.when(
              (tracks) => tracks,
              error: (error) {
                debugPrint('error: $error');
                return <Track>[];
              },
            ));

    String syncName =
        await service.searchRepository.getSpotifyNameUri(playlistUri);

    int addedCount = 0;
    int skippedCount = 0;

    for (Track track in result) {
      if (existingTrackSpotifyUris.contains(track.uri)) {
        skippedCount++;
        continue;
      }
      DJTrack addTrack = DJTrack.fromSpotifyTrack(track);

      ref.read(hiveTrackData.notifier).addDJTrack(addTrack);

      ref
          .read(hivePlaylistData.notifier)
          .addTrackToDJPlaylist(playlist, addTrack);
      playlist.name = syncName;
      ref.read(hivePlaylistData.notifier).updateDJPlaylist(playlist);
      addedCount++;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'La til $addedCount spor, hoppet over $skippedCount spor. Spillelisten har nå ${playlist.trackIds.length} spor'),
      ));
    }

    if (mounted) {
      Navigator.of(context).pop();
      widget.refreshCallback ?? widget.refreshCallback;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DJPlaylistEditScreen.fromDJPlaylist(
            playlist,
            refreshCallback: () {
              setState(() {});
            },
          ),
        ),
      );
    }
  }

  Future<void> _spotifyTrackSync(
      BuildContext context, WidgetRef ref, String playlistId) async {
    if (widget.isNew) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Playlist must be saved before syncing'),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Close',
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ));
      }
      return;
    }

    DJPlaylist playlist = ref
        .read(hivePlaylistData.notifier)
        .repo
        .getDJPlaylists()
        .firstWhere((element) => element.id == widget.id);

    List<String> trackIds = ref
        .read(hiveTrackData.notifier)
        .getDJTracksSpotifyUri(playlist.trackIds);

    final service = ref.read(playlistServiceProvider);
    final searchDelegate =
        SpotifyPlaylistTrackDelegate(playlistId, service, trackIds);

    final track = await showSearch<Track?>(
      context: context,
      delegate: searchDelegate,
    );
    if (track != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('adding track: ${track.name}'),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Close',
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ));
      }
      DJTrack addTrack = DJTrack.fromSpotifyTrack(track);

      ref.read(hiveTrackData.notifier).addDJTrack(addTrack);
      DJPlaylist playlist = ref
          .read(hivePlaylistData.notifier)
          .repo
          .getDJPlaylists()
          .firstWhere((element) => element.id == widget.id);
      ref
          .read(hivePlaylistData.notifier)
          .addTrackToDJPlaylist(playlist, addTrack);
      ref.read(hivePlaylistData.notifier).updateDJPlaylist(playlist);
      if (mounted) {
        setState(() {
          trackIds = playlist.trackIds;
          playlistTrackList =
              ref.read(hiveTrackData.notifier).getDJTracks(trackIds);
        });
      }
    } else {
      debugPrint('result: ingenting valgt');
    }
  }

  void _showSearch(BuildContext context, WidgetRef ref) async {
    final service = ref.read(searchServiceProvider);
    final searchDelegate = SpotifySearchDelegate(service);
    final track = await showSearch<Track?>(
      context: context,
      delegate: searchDelegate,
    );
    if (track != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('adding track: ${track.name}'),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Close',
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ));
      }
      DJTrack addTrack = DJTrack.fromSpotifyTrack(track);

      ref.read(hiveTrackData.notifier).addDJTrack(addTrack);
      DJPlaylist playlist = ref
          .read(hivePlaylistData.notifier)
          .repo
          .getDJPlaylists()
          .firstWhere((element) => element.id == widget.id);
      ref
          .read(hivePlaylistData.notifier)
          .addTrackToDJPlaylist(playlist, addTrack);
      ref.read(hivePlaylistData.notifier).updateDJPlaylist(playlist);
      if (mounted) {
        setState(() {
          trackIds = playlist.trackIds;
          playlistTrackList =
              ref.read(hiveTrackData.notifier).getDJTracks(trackIds);
        });
      }
    }
  }

  String newPlaylistFromFormData() {
    return ref.read(hivePlaylistData.notifier).addDJplaylist(
          DJPlaylist(
            id: '',
            name: nameController.text,
            type: selectedType.name,
            spotifyUri: spotifyUriController.text,
            shuffleAtEnd: shuffleAtEnd,
            trackIds: [],
            currentTrack: currentTrack,
            playCount: 0,
            autoNext: autoNext,
          ),
        );
  }

  List<String> getExistingUris() {
    return ref
        .read(hivePlaylistData.notifier)
        .repo
        .getDJPlaylists()
        .map((e) => e.spotifyUri)
        .where((uri) => uri.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        leading: IconButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.refreshCallback ?? widget.refreshCallback;
            },
            icon: const Icon(
              Icons.arrow_back,
              color: Colors.black,
              size: 30,
            )),
        actions: [
          ref.read(spotifyRemoteRepositoryProvider).hasSpotifyAccessToken
              ? IconButton(
                  onPressed: () {
                    setState(() {
                      ref.read(spotifyRemoteRepositoryProvider).resumePlayer();
                    });
                  },
                  icon: const Icon(Icons.play_arrow, color: Colors.green),
                )
              : Container(),
          ref.read(spotifyRemoteRepositoryProvider).hasSpotifyAccessToken
              ? IconButton(
                  onPressed: () {
                    setState(() {
                      ref.read(spotifyRemoteRepositoryProvider).pausePlayer();
                    });
                  },
                  icon: const Icon(Icons.pause, color: Colors.green),
                )
              : Container(),
        ],
        title: Text(
          widget.id.isEmpty ? 'Create Playlist' : 'Edit Playlist',
          style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          children: [
            Container(
                color: Theme.of(context).primaryColor.withOpacity(0.05),
                child: Row(children: [
                  Expanded(
                    flex: 70,
                    child: TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Name',
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                              color: Theme.of(context).primaryColor, width: 2),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                              color: Theme.of(context).primaryColor, width: 2),
                        ),
                        hintText: ' Enter name',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 30,
                    child: Container(
                        height: 58,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: 10.0),
                        decoration: BoxDecoration(
                            color: Theme.of(context)
                                .primaryColor
                                .withOpacity(0.05),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: Theme.of(context).primaryColor,
                              width: 2,
                            )),
                        child: Row(children: [
                          const Text('Type:    '),
                          DJPlaylistTypeDropdown(
                            initialValue: selectedType.name,
                            onChanged: (value) {
                              setState(() {
                                selectedType = DJPlaylistType.values
                                    .firstWhere((e) => e.name == value);
                              });
                            },
                          )
                        ])),
                  )
                ])),
            const SizedBox(height: 10),
            Container(
                color: Theme.of(context).primaryColor.withOpacity(0.05),
                child: Row(
                  children: [
                    Expanded(
                      flex: 70,
                      child: TextField(
                        controller: spotifyUriController,
                        onChanged: (value) => setState(() {
                          spotifyUriController.text = spotifyUriValidate(value);
                        }),
                        decoration: InputDecoration(
                          labelText: 'Spotify uri',
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                                color: Theme.of(context).primaryColor,
                                width: 2),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                                color: Theme.of(context).primaryColor,
                                width: 2),
                          ),
                          hintText: ' Paste spotify uri',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 30,
                      child: Row(children: [
                        IconButton(
                          icon: const Icon(Icons.sync),
                          onPressed: () {
                            setState(() {
                              _spotifyPlaylistSync(
                                  context, ref, spotifyUriController.text);
                            });
                          },
                        ),
                        const SizedBox(width: 10),
                        IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: () {
                            setState(() {
                              _showSearch(context, ref);
                            });
                          },
                        ),
                        const SizedBox(width: 10),
                        IconButton(
                          icon: const Icon(Icons.playlist_add_circle_outlined),
                          onPressed: () {
                            setState(() {
                              _spotifyTrackSync(
                                  context, ref, spotifyUriController.text);
                            });
                          },
                        )
                      ]),
                    )
                  ],
                )),
            if (spotifyUriController.text.isEmpty) ...[
              const SizedBox(height: 10),
              Container(
                  color: Theme.of(context).primaryColor.withOpacity(0.05),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 70,
                        child: PlaylistSpotifyUriExampleDropdown(
                          existingUris: getExistingUris(),
                          initialValue: '',
                          onChanged: (value) {
                            setState(() {
                              spotifyUriController.text = value ?? '';
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        flex: 30,
                        child: Text('Use an example playlist'),
                      )
                    ],
                  )),
            ],
            const SizedBox(height: 10),

            // ── Settings ──────────────────────────────────────────────
            Container(
              color: Theme.of(context).primaryColorLight,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  CupertinoCheckbox(
                    value: shuffleAtEnd,
                    onChanged: (v) => setState(() => shuffleAtEnd = v ?? true),
                  ),
                  const SizedBox(width: 6),
                  const Text('Shuffle at end'),
                  const Gap(24),
                  CupertinoCheckbox(
                    value: autoNext,
                    onChanged: (v) => setState(() => autoNext = v ?? true),
                  ),
                  const SizedBox(width: 6),
                  const Text('Auto next'),
                  const Gap(24),
                  const Text('Position'),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 50,
                    child: CupertinoTextField(
                      maxLength: 2,
                      keyboardType: TextInputType.number,
                      controller: positionController,
                      placeholder: '1–99',
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Tracks: ${trackIds.length}',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // ── Actions ───────────────────────────────────────────────
            Row(
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.sync),
                  label: const Text('Sync start times'),
                  onPressed: () => syncMissingStartTimes(playlistTrackList),
                ),
                const Gap(4),
                TextButton.icon(
                  icon: const Icon(Icons.shuffle),
                  label: const Text('Shuffle'),
                  onPressed: () {
                    DJPlaylist playlist = ref
                        .read(hivePlaylistData.notifier)
                        .shuffleTracksInPlaylist(widget.id);
                    playlist = ref
                        .read(hivePlaylistData.notifier)
                        .repo
                        .getDJPlaylists()
                        .firstWhere((element) => element.id == widget.id);
                    setState(() {
                      trackIds = playlist.trackIds;
                      playlistTrackList = ref
                          .read(hiveTrackData.notifier)
                          .getDJTracks(trackIds);
                    });
                  },
                ),
                const Spacer(),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).disabledColor,
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                const Gap(12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                  ),
                  onPressed: _errorMessage.isNotEmpty
                      ? null
                      : () {
                          String newPlayListId = '';
                          if (widget.id.isEmpty) {
                            newPlayListId = newPlaylistFromFormData();
                          } else {
                            ref
                                .read(hivePlaylistData.notifier)
                                .updateDJPlaylist(
                                  DJPlaylist(
                                    id: widget.id,
                                    name: nameController.text,
                                    type: selectedType.name,
                                    spotifyUri: spotifyUriController.text,
                                    shuffleAtEnd: shuffleAtEnd,
                                    trackIds: trackIds,
                                    currentTrack: currentTrack,
                                    playCount: 0,
                                    autoNext: autoNext,
                                    position:
                                        int.parse(positionController.text),
                                  ),
                                );
                          }
                          Navigator.pop(context);
                          if (newPlayListId.isNotEmpty) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DJPlaylistEditScreen(
                                  name: nameController.text,
                                  type: selectedType.name,
                                  spotifyUri: spotifyUriController.text,
                                  trackIds: const [],
                                  isNew: false,
                                  id: newPlayListId,
                                  status: 'Playlist created',
                                  shuffleAtEnd: widget.shuffleAtEnd,
                                  autoNext: widget.autoNext,
                                  currentTrack: widget.currentTrack,
                                  position:
                                      int.parse(positionController.text),
                                ),
                              ),
                            );
                          }
                        },
                  child: Text(
                    widget.id.isEmpty ? 'Create' : 'Update',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            // divider line
            const SizedBox(height: 10),
            const Divider(
              color: Colors.grey,
              height: 1,
            ),

            const SizedBox(height: 10),
            getTrackList(playlistTrackList),
            const SizedBox(
              height: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _refreshTracks() {
    ref.read(hiveTrackData.notifier).fetchDJTrack();
    setState(() {
      playlistTrackList =
          ref.read(hiveTrackData.notifier).getDJTracks(trackIds);
    });
  }

  Widget getTrackList(List<DJTrack> tracks) {
    final list = ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
        },
      ),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: tracks.length,
        itemBuilder: (context, index) {
          return DJPlaylistTrackView(
            counter: index + 1,
            track: tracks[index],
            onEdit: () {
              ref.invalidate(dataTrackProvider);
              final track = tracks[index];
              handleTrackEdit(id: widget.id, track: track, index: index);
            },
            onDelete: () {
              final playlist = ref
                  .read(hivePlaylistData.notifier)
                  .removeDJTrackFromPlaylist(ref.read(hiveTrackData.notifier),
                      widget.id, tracks[index].id, index);
              setState(() {
                trackIds = playlist.trackIds;
                playlistTrackList =
                    ref.read(hiveTrackData.notifier).getDJTracks(trackIds);
              });
            },
          );
        },
      ),
    );

    return Expanded(
      flex: 10,
      child: Platform.isMacOS
          ? Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh tracks',
                    onPressed: _refreshTracks,
                  ),
                ),
                Expanded(child: list),
              ],
            )
          : RefreshIndicator(
              onRefresh: () async => _refreshTracks(),
              child: list,
            ),
    );
  }

  Future<dynamic> handleTrackEdit({
    required String id,
    required DJTrack track,
    required int index,
    bool autoPreview = false,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DJTrackEditScreen(
          playlistId: widget.id,
          playlistName: track.name,
          isNew: false,
          id: track.id,
          name: track.name,
          album: track.album,
          artist: track.artist,
          startTime: track.startTime,
          startTimeMS: track.startTimeMS,
          duration: track.duration,
          playCount: track.playCount,
          spotifyUri: track.spotifyUri,
          mp3Uri: track.mp3Uri,
          networkImageUri: track.networkImageUri,
          shortcut: track.shortcut,
          index: index,
          initialAutoPreview: autoPreview,
        ),
      ),
    ).then((value) {
      if (value != null && value is (int, bool)) {
        final (gotoTrackIndex, nextAutoPreview) = value;
        final track = playlistTrackList[gotoTrackIndex];
        handleTrackEdit(
          id: widget.id,
          track: track,
          index: gotoTrackIndex,
          autoPreview: nextAutoPreview,
        );
      } else {
        setState(() {
          playlistTrackList =
              ref.read(hiveTrackData.notifier).getDJTracks(trackIds);
        });
      }
    });
  }

  String spotifyUriValidate(String value) {
    if (value.isEmpty) {
      return '';
    }
    if (value.contains('https://open.spotify.com/playlist/')) {
      // remove the https://open.spotify.com/playlist/ from the uri
      return value.substring('https://open.spotify.com/playlist/'.length);
    }

    if (value.contains('https://open.spotify.com/album/')) {
      // remove the https://open.spotify.com/ from the uri
      return value.substring('https://open.spotify.com/'.length);
    }
    return value;
  }

  void syncMissingStartTimes(List<DJTrack> tracks) {
    final trackTimeList = ref.watch(dataTrackTimeProvider);
    int updatedCount = 0;
    for (var track in tracks) {
      if (track.startTime == 0) {
        if (trackTimeList.any((element) => element.id.contains(track.id))) {
          track.startTime = trackTimeList
              .firstWhere((element) => element.id.contains(track.id))
              .startTime;
          ref.read(hiveTrackData.notifier).updateDJTrack(track);
          updatedCount++;
        }
      }
    }
    ref.invalidate(dataTrackProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Updated $updatedCount tracks'),
      ));
    }
    if (mounted) {
      setState(() {
        playlistTrackList =
            ref.read(hiveTrackData.notifier).getDJTracks(trackIds);
      });
    }
  }
}
