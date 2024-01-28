import 'package:djsports/data/models/djtrack_model.dart';
import 'package:djsports/data/provider/djtrack_provider.dart';
import 'package:flutter/material.dart';
// Localization
//models

// Riverpod
import 'package:hooks_riverpod/hooks_riverpod.dart';

//Providers

class DJTrackEditScreen extends StatefulHookConsumerWidget {
  const DJTrackEditScreen({
    super.key,
    required this.playlistName,
    required this.playlistId,
    required this.name,
    required this.album,
    required this.artist,
    required this.startTime,
    required this.startTimeMS,
    required this.duration,
    required this.playCount,
    required this.spotifyUri,
    required this.mp3Uri,
    required this.index,
    required this.isNew,
    required this.id,
  });
  final String playlistName;
  final String playlistId;
  final String name;
  final String album;
  final String artist;
  final int startTime;
  final int startTimeMS;
  final int duration;
  final int playCount;
  final String spotifyUri;
  final String mp3Uri;
  final String id;
  final bool isNew;
  final int index;
  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _EditScreenState();
}

class _EditScreenState extends ConsumerState<DJTrackEditScreen> {
  final nameController = TextEditingController();
  final spotifyUriController = TextEditingController();
  final albumController = TextEditingController();
  final artistController = TextEditingController();
  final mp3UriController = TextEditingController();

  String playlistId = '';
  String playlistName = '';

  @override
  void initState() {
    if (!widget.isNew) {
      nameController.text = widget.name;
      albumController.text = widget.album;
      artistController.text = widget.artist;
      spotifyUriController.text = widget.spotifyUri;
      mp3UriController.text = widget.mp3Uri;
    }
    playlistId = widget.playlistId;
    playlistName = widget.playlistName;

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
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
          widget.id.isEmpty
              ? "Create Track for $playlistName"
              : "Edit Track for $playlistName",
          style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          children: [
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: TextField(
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
                )),
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: TextField(
                  controller: albumController,
                  decoration: InputDecoration(
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                          color: Theme.of(context).primaryColor, width: 2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                          color: Theme.of(context).primaryColor, width: 2),
                    ),
                    hintText: ' Enter album',
                  ),
                )),
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: TextField(
                  controller: artistController,
                  decoration: InputDecoration(
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                          color: Theme.of(context).primaryColor, width: 2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                          color: Theme.of(context).primaryColor, width: 2),
                    ),
                    hintText: ' Enter artist',
                  ),
                )),
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
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: TextField(
                controller: mp3UriController,
                decoration: InputDecoration(
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                        color: Theme.of(context).primaryColor, width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                        color: Theme.of(context).primaryColor, width: 2),
                  ),
                  hintText: ' Paste mp3uri',
                ),
              ),
            ),
            const SizedBox(
              height: 10,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Cancel',
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
                      ref.read(hiveTrackData.notifier).addDJTrack(
                            DJTrack(
                              id: '',
                              name: nameController.text,
                              album: albumController.text,
                              artist: artistController.text,
                              spotifyUri: spotifyUriController.text,
                              mp3Uri: mp3UriController.text,
                              duration: 0,
                              startTime: 0,
                              startTimeMS: 0,
                              playCount: 0,
                            ),
                          );
                    } else {
                      ref.read(hiveTrackData.notifier).updateDJTrack(
                            DJTrack(
                              id: '',
                              name: nameController.text,
                              album: albumController.text,
                              artist: artistController.text,
                              spotifyUri: spotifyUriController.text,
                              mp3Uri: mp3UriController.text,
                              duration: 0,
                              startTime: 0,
                              startTimeMS: 0,
                              playCount: 0,
                            ),
                          );
                    }
                    Navigator.pop(context);
                  },
                  child: Text(
                    widget.id.isEmpty ? 'Create' : 'Update',
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
