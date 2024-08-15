import 'package:djsports/data/models/djplaylist_model.dart';
import 'package:djsports/data/models/djtrack_model.dart';
import 'package:djsports/data/provider/djplaylist_provider.dart';
import 'package:djsports/data/provider/djtrack_provider.dart';
import 'package:djsports/data/services/spotify_playlist_service.dart';
import 'package:djsports/data/services/spotify_search_service.dart';
import 'package:djsports/features/playlist/djtrack_edit_create.dart';
import 'package:djsports/features/playlist/widgets/djplaylist_tracks_view.dart';
import 'package:djsports/features/playlist/widgets/djplaylist_type_dropdown.dart';
import 'package:djsports/features/spotify_playlist_sync/spotify_playlist_sync_delegate.dart';
import 'package:djsports/features/spotify_search/spotify_search_delegate.dart';
import 'package:flutter/material.dart';

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
    required this.isNew,
    this.status,
    required this.id,
    this.refreshCallback,
  });
  final String name;
  final String type;
  final String spotifyUri;
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
  DJPlaylistType selectedType = DJPlaylistType.score;
  List<String> trackIds = [];

  @override
  void initState() {
    if (!widget.isNew) {
      nameController.text = widget.name;
      spotifyUriController.text = widget.spotifyUri;
    }
    selectedType =
        DJPlaylistType.values.firstWhere((e) => e.name == widget.type);
    trackIds = widget.trackIds;

    super.initState();
  }

  Future<void> _spotifyPlaylistSync(
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
        .getPlaylistTracks(playlistId)
        .then((value) => value.when((tracks) {
              return tracks;
            }, error: (error) {
              debugPrint('error: $error');
              return [];
            }));
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
      ref.read(hivePlaylistData.notifier).updateDJPlaylist(playlist);
      addedCount++;
    }

    setState(() {
      trackIds = playlist.trackIds;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          'Added $addedCount tracks, skipped $skippedCount tracks. Playlist has now ${playlist.trackIds.length} tracks'),
      duration: const Duration(seconds: 3),
      action: SnackBarAction(
        label: 'Close',
        onPressed: () {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        },
      ),
    ));
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
                          labelText: 'Spotify uri 2',
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
                          icon: const Icon(Icons.library_add),
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
                  onPressed: () {
                    String newPlayListId = '';
                    if (widget.id.isEmpty) {
                      newPlayListId =
                          ref.read(hivePlaylistData.notifier).addDJplaylist(
                                DJPlaylist(
                                  id: '',
                                  name: nameController.text,
                                  type: selectedType.name,
                                  spotifyUri: spotifyUriController.text,
                                  shuffleAtEnd: false,
                                  trackIds: [],
                                  currentTrack: 0,
                                  playCount: 0,
                                  autoNext: false,
                                ),
                              );
                    } else {
                      ref.read(hivePlaylistData.notifier).updateDJPlaylist(
                            DJPlaylist(
                              id: widget.id,
                              name: nameController.text,
                              type: selectedType.name,
                              spotifyUri: spotifyUriController.text,
                              shuffleAtEnd: false,
                              trackIds: trackIds,
                              currentTrack: 0,
                              playCount: 0,
                              autoNext: false,
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
            getTrackList(
                ref.read(hiveTrackData.notifier).getDJTracks(trackIds)),
            const SizedBox(
              height: 20,
            ),
          ],
        ),
      ),
    );
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
              debugPrint(
                  'edit track: ${tracks[index].name} ${tracks[index].duration} $index');
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DJTrackEditScreen(
                    playlistId: widget.id,
                    playlistName: tracks[index].name,
                    isNew: false,
                    id: tracks[index].id,
                    name: tracks[index].name,
                    album: tracks[index].album,
                    artist: tracks[index].artist,
                    startTime: tracks[index].startTime,
                    startTimeMS: tracks[index].startTimeMS,
                    duration: tracks[index].duration,
                    playCount: tracks[index].playCount,
                    spotifyUri: tracks[index].spotifyUri,
                    mp3Uri: tracks[index].mp3Uri,
                    networkImageUri: tracks[index].networkImageUri,
                    index: index,
                  ),
                ),
              );
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
      return value.substring(34);
    }
    return value;
  }
}
