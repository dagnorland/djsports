import 'package:djsports/data/models/djplaylist_model.dart';
import 'package:djsports/data/models/djtrack_model.dart';
import 'package:djsports/data/provider/djplaylist_provider.dart';
import 'package:djsports/data/provider/djtrack_provider.dart';
import 'package:djsports/data/services/spotify_search_service.dart';
import 'package:djsports/features/playlist/djtrack_create.dart';
import 'package:djsports/features/playlist/widgets/djplaylist_tracks_view.dart';
import 'package:djsports/features/spotify_search/spotify_search_delegate.dart';
import 'package:djsports/utils.dart';
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
  });
  final String name;
  final String type;
  final String spotifyUri;
  final List<String> trackIds;
  final String id;
  final bool isNew;
  final String? status;
  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _EditScreenState();
}

class _EditScreenState extends ConsumerState<DJPlaylistEditScreen> {
  final nameController = TextEditingController();
  final spotifyUriController = TextEditingController();
  Type selectedType = Type.score;
  List<String> trackIds = [];

  @override
  void initState() {
    if (!widget.isNew) {
      nameController.text = widget.name;
      spotifyUriController.text = widget.spotifyUri;
    }
    selectedType = Type.values.firstWhere((e) => e.name == widget.type);
    trackIds = widget.trackIds;

    super.initState();
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
      DJTrack addTrack = DJTrack(
        id: track.id!,
        name: track.name!,
        album: track.album!.name!,
        artist: track.artists!.first.name!,
        startTime: 0,
        startTimeMS: 0,
        duration: track.durationMs!,
        playCount: 0,
        spotifyUri: track.uri!,
        mp3Uri: '',
      );

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
            TextField(
              controller: nameController,
              decoration: InputDecoration(
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
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: TextField(
                controller: spotifyUriController,
                decoration: InputDecoration(
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                        color: Theme.of(context).primaryColor, width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                        color: Theme.of(context).primaryColor, width: 2),
                  ),
                  hintText: ' Paste spotify uri',
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                    padding: const EdgeInsets.symmetric(horizontal: 50),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(
                          color: Theme.of(context).primaryColor, width: 2),
                    ),
                    child: DropdownButtonHideUnderline(
                        child: DropdownButton<Type>(
                      value: selectedType,
                      items: Type.values.map((Type type) {
                        return DropdownMenuItem<Type>(
                          value: type,
                          child: Text(type.toString().split('.').last),
                        );
                      }).toList(),
                      onChanged: (Type? newValue) {
                        setState(() {
                          ref.read(typeFilterPlaylistProvider.notifier).state =
                              newValue!;
                        });
                      },
                    ))),
                const SizedBox(
                  width: 50,
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
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
                    if (widget.id.isEmpty) {
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
                  },
                  child: Text(
                    widget.id.isEmpty ? 'Create playlist' : 'Update playlist',
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
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor),
                  child: Text(
                    'Add from Spotify',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge!
                        .copyWith(color: Colors.white),
                  ),
                  onPressed: () => _showSearch(context, ref),
                ),
                const SizedBox(
                  width: 30,
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor),
                  child: Text(
                    'Add mp3 file',
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
                          index: 0,
                        ),
                      ),
                    );
                  },
                ),
              ],
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
            track: tracks[index],
            onEdit: () {
              ref.invalidate(dataTrackProvider);
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
}
