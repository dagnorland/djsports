import 'dart:async';

import 'package:djsports/data/models/djplaylist_model.dart';
import 'package:djsports/data/models/djtrack_model.dart';
import 'package:djsports/data/provider/djplaylist_provider.dart';
import 'package:djsports/data/provider/djtrack_provider.dart';
import 'package:djsports/data/repo/spotify_remote_repository.dart';
import 'package:djsports/data/services/spotify_playlist_service.dart';
import 'package:djsports/data/services/spotify_search_service.dart';
import 'package:djsports/features/playlist/djtrack_edit_create.dart';
import 'package:djsports/features/playlist/widgets/djplaylist_tracks_view.dart';
import 'package:djsports/features/playlist/widgets/djplaylist_type_dropdown.dart';
import 'package:djsports/features/spotify_playlist_sync/spotify_playlist_sync_delegate.dart';
import 'package:djsports/features/spotify_search/spotify_search_delegate.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    if (widget.isNew) {
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
      return;
    }

    DJPlaylist? playlist = ref
        .read(hivePlaylistData.notifier)
        .repo!
        .getDJPlaylists()
        .firstWhere((element) => element.id == widget.id);

    List<String> existingTrackSpotifyUris = ref
        .read(hiveTrackData.notifier)
        .getDJTracksSpotifyUri(playlist.trackIds);
    final service = ref.read(playlistServiceProvider);

    Iterable<Track> result = await service.searchRepository
        .getTracksByUri(playlistUri)
        .then((value) => value.when((tracks) {
              return tracks;
            }, error: (error) {
              debugPrint('error: $error');
              return [];
            }));

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
      DJPlaylist playlist = ref
          .read(hivePlaylistData.notifier)
          .repo!
          .getDJPlaylists()
          .firstWhere((element) => element.id == widget.id);
      ref
          .read(hivePlaylistData.notifier)
          .addTrackToDJPlaylist(playlist, addTrack);
      playlist.name = syncName;
      ref.read(hivePlaylistData.notifier).updateDJPlaylist(playlist);
      addedCount++;
    }

    if (addedCount > 0 || skippedCount > 0) {
      Navigator.pop(context);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'La til $addedCount spor, hoppet over $skippedCount spor. Spillelisten har nå ${playlist.trackIds.length} spor'),
      ));
    }
  }

  Future<void> _spotifyTrackSync(
      BuildContext context, WidgetRef ref, String playlistId) async {
    if (widget.isNew) {
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
      return;
    }

    DJPlaylist playlist = ref
        .read(hivePlaylistData.notifier)
        .repo!
        .getDJPlaylists()
        .firstWhere((element) => element.id == widget.id);

    List<String> trackIds = ref
        .read(hiveTrackData.notifier)
        .getDJTracksSpotifyUri(playlist.trackIds);

    final service = ref.read(playlistServiceProvider);
    final searchDelegate =
        SpotifyPlaylistTrackDelegate(playlistId, service, trackIds);

    //final result = service.searchRepository.getPlaylistTracks(playlistId);
    final track = await showSearch<Track?>(
      context: context,
      delegate: searchDelegate,
    );
    if (track != null) {
      // make an snackbar showing track name
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
      DJTrack addTrack = DJTrack.fromSpotifyTrack(track);

      ref.read(hiveTrackData.notifier).addDJTrack(addTrack);
      DJPlaylist playlist = ref
          .read(hivePlaylistData.notifier)
          .repo!
          .getDJPlaylists()
          .firstWhere((element) => element.id == widget.id);
      ref
          .read(hivePlaylistData.notifier)
          .addTrackToDJPlaylist(playlist, addTrack);
      ref.read(hivePlaylistData.notifier).updateDJPlaylist(playlist);
      setState(() {
        trackIds = playlist.trackIds;
      });
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
    //service.dispose();
    if (track != null) {
      // make an snackbar showing track name
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
      DJTrack addTrack = DJTrack.fromSpotifyTrack(track);

      ref.read(hiveTrackData.notifier).addDJTrack(addTrack);
      DJPlaylist playlist = ref
          .read(hivePlaylistData.notifier)
          .repo!
          .getDJPlaylists()
          .firstWhere((element) => element.id == widget.id);
      ref
          .read(hivePlaylistData.notifier)
          .addTrackToDJPlaylist(playlist, addTrack);
      ref.read(hivePlaylistData.notifier).updateDJPlaylist(playlist);
      setState(() {
        trackIds = playlist.trackIds;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          centerTitle: false,
          elevation: 0,
          backgroundColor: Colors.white,
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
            ref.read(spotifyRemoteRepositoryProvider).isConnected
                ? IconButton(
                    onPressed: () {
                      setState(() {
                        ref
                            .read(spotifyRemoteRepositoryProvider)
                            .resumePlayer();
                      });
                    },
                    icon: const Icon(Icons.play_arrow, color: Colors.green),
                  )
                : Container(),
            ref.read(spotifyRemoteRepositoryProvider).isConnected
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
            widget.id.isEmpty ? "Create Playlist" : "Edit Playlist",
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
                                color: Theme.of(context).primaryColor,
                                width: 2),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                                color: Theme.of(context).primaryColor,
                                width: 2),
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
                            spotifyUriController.text =
                                spotifyUriValidate(value);
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
                            icon:
                                const Icon(Icons.playlist_add_circle_outlined),
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
              const SizedBox(height: 10),

              Container(
                  color: Theme.of(context).primaryColor.withOpacity(0.05),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: Row(
                          children: [
                            const Text('Shuffle'),
                            CupertinoCheckbox(
                              value: shuffleAtEnd,
                              onChanged: (value) {
                                setState(() {
                                  shuffleAtEnd = value ?? true;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 5,
                        child: Row(
                          children: [
                            const Text('Auto next'),
                            CupertinoCheckbox(
                              value: autoNext,
                              onChanged: (value) {
                                setState(() {
                                  autoNext = value ?? true;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 5,
                        child: Row(children: [
                          Text(
                              '${widget.currentTrack + 1} / ${trackIds.length}'),
                        ]),
                      ),
                      Expanded(
                        flex: 5,
                        child: Row(
                          children: [
                            const Text('Position'),
                            SizedBox(
                                width: 50,
                                child: CupertinoTextField(
                                  maxLength: 2,
                                  keyboardType: TextInputType.number,
                                  controller: positionController,
                                  placeholder: 'Enter a value between 1 and 99',
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly
                                  ],
                                )),
                          ],
                        ),
                      ),
                    ],
                  )),
              const SizedBox(height: 10),

              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColorLight),
                    child: Text(
                      'Add MP3',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge!
                          .copyWith(color: Colors.white),
                    ),
                    onPressed: () {
                      ref.invalidate(dataTrackProvider);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DJTrackEditScreen(
                            playlistId: widget.id,
                            playlistName: widget.name,
                            isNew: true,
                            id: '',
                            name: '',
                            album: '',
                            artist: '',
                            startTime: 0,
                            startTimeMS: 0,
                            duration: 0,
                            playCount: 0,
                            spotifyUri: '',
                            mp3Uri: '',
                            networkImageUri: '',
                            index: 0,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(
                    width: 30,
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).disabledColor,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Text(
                      'Cancel',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge!
                          .copyWith(color: Colors.white),
                    ),
                  ),
                  const SizedBox(
                    width: 30,
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                    ),
                    onPressed: _errorMessage.isNotEmpty
                        ? null
                        : () {
                            String newPlayListId = '';
                            if (widget.id.isEmpty) {
                              newPlayListId = ref
                                  .read(hivePlaylistData.notifier)
                                  .addDJplaylist(
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
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge!
                          .copyWith(color: Colors.white),
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
        ));
  }

  Widget getTrackList(List<DJTrack> tracks) {
    return Expanded(
      flex: 10,
      child: ListView.builder(
        itemCount: tracks.length,
        itemBuilder: (context, index) {
          return DJPlaylistTrackView(
            counter: index + 1,
            track: tracks[index],
            onEdit: () {
              ref.invalidate(dataTrackProvider);
              DJTrack track = tracks[index];
              // get result from pop

              Navigator.push(
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
                    index: index,
                  ),
                ),
              ).then((value) {
                setState(() {
                  playlistTrackList =
                      ref.read(hiveTrackData.notifier).getDJTracks(trackIds);
                });
              });
            },
            onDelete: () {
              DJPlaylist playlist = ref
                  .read(hivePlaylistData.notifier)
                  .removeDJTrackFromPlaylist(ref.read(hiveTrackData.notifier),
                      widget.id, tracks[index].id);
              setState(() {
                trackIds = playlist.trackIds;
              });
            },
          );
        },
      ),
    );
  }

  String spotifyUriValidate(String value) {
    if (value.isEmpty) {
      return '';
    }
    if (value.contains('https://open.spotify.com/playlist/')) {
      // remove the https://open.spotify.com/playlist/ from the uri
      return value.substring('https://open.spotify.com/'.length);
    }

    if (value.contains('https://open.spotify.com/album/')) {
      // remove the https://open.spotify.com/ from the uri
      return value.substring('https://open.spotify.com/'.length);
    }

    if (value.startsWith('playlist:')) {
      return value.replaceFirst('playlist:', 'playlist/');
    }
    if (value.startsWith('album:')) {
      return value.replaceFirst('album:', 'album/');
    }

    return value;
  }
}
