import 'package:djsports/data/models/djtrack_model.dart';
import 'package:djsports/data/provider/djtrack_provider.dart';
import 'package:djsports/data/repo/spotify_remote_repository.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
// Localization
//models

// Riverpod
import 'package:hooks_riverpod/hooks_riverpod.dart';

//Providers
const List<int> _millisecondsbythehundreds = <int>[
  0,
  100,
  200,
  300,
  400,
  500,
  600,
  700,
  800,
  900,
];

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
    required this.networkImageUri,
    required this.mp3Uri,
    required this.index,
    required this.isNew,
    required this.id,
  });

  DJTrackEditScreen.fromTrack({
    super.key,
    required this.playlistName,
    required this.playlistId,
    required DJTrack track,
    required this.index,
    required this.isNew,
  })  : name = track.name,
        album = track.album,
        artist = track.artist,
        startTime = track.startTime,
        startTimeMS = track.startTimeMS,
        duration = track.duration,
        playCount = track.playCount,
        spotifyUri = track.spotifyUri,
        networkImageUri = track.networkImageUri,
        mp3Uri = track.mp3Uri,
        id = track.id;

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
  final String networkImageUri;
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
  final networkImageUriController = TextEditingController();
  final durationController = TextEditingController();
  final startTimeController = TextEditingController();

  String playlistId = '';
  String playlistName = '';
  int editStartTime = 0;
  int editStartTimeMS = 0;
  String trackDurationFormatted = 'hh:mm:ss';

  @override
  void initState() {
    if (!widget.isNew) {
      nameController.text = widget.name;
      albumController.text = widget.album;
      artistController.text = widget.artist;
      spotifyUriController.text = widget.spotifyUri;
      mp3UriController.text = widget.mp3Uri;
      networkImageUriController.text = widget.networkImageUri;
      durationController.text =
          printDuration((Duration(milliseconds: widget.duration)));
      startTimeController.text =
          printDuration((Duration(milliseconds: widget.startTime)));
      editStartTime = widget.startTime;
      trackDurationFormatted =
          printDuration((Duration(milliseconds: widget.duration)));
      editStartTimeMS = widget.startTimeMS;
    }
    playlistId = widget.playlistId;
    playlistName = widget.playlistName;

    super.initState();
  }

  // This shows a CupertinoModalPopup with a reasonable fixed height which hosts
  // a CupertinoTimerPicker.
  void showDialog(Widget child) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => Container(
        height: 216,
        padding: const EdgeInsets.only(top: 6.0),
        // The bottom margin is provided to align the popup above the system
        // navigation bar.
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        // Provide a background color for the popup.
        color: CupertinoColors.systemBackground.resolveFrom(context),
        // Use a SafeArea widget to avoid system overlaps.
        child: SafeArea(
          top: false,
          child: child,
        ),
      ),
    );
  }

  String printDuration(Duration duration) {
    String twoDigits(int n) {
      if (n >= 10) return "$n";
      return "0$n";
    }

    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    } else {
      return "$twoDigitMinutes:$twoDigitSeconds";
    }
  }

  int getStartTime() {
    try {
      final startTimeParts = startTimeController.text.split(':');
      final minutes = int.parse(startTimeParts[0]);
      final seconds = int.parse(startTimeParts[1]);
      final totalMilliseconds =
          (minutes * 60 + seconds) * 1000 + editStartTimeMS;
      return totalMilliseconds;
    } catch (e) {
      return 0;
    }
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
              Navigator.pop(context);
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
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                  color: Theme.of(context).primaryColor.withOpacity(0.05),
                  child: Row(children: [
                    Expanded(
                        flex: 1,
                        child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
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
                            ))),
                    const Gap(20),
                    Expanded(
                        flex: 1,
                        child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: TextField(
                              controller: albumController,
                              decoration: InputDecoration(
                                labelText: 'Album name',
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
                                hintText: ' Enter album',
                              ),
                            ))),
                    const Gap(20),
                    Expanded(
                        flex: 1,
                        child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: TextField(
                              controller: artistController,
                              decoration: InputDecoration(
                                labelText: 'Artist name',
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
                                hintText: ' Enter artist',
                              ),
                            ))),
                  ])),
              Container(
                  color: Theme.of(context).primaryColor.withOpacity(0.05),
                  child: Row(children: [
                    Expanded(
                      flex: 13,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: TextField(
                          readOnly: true,
                          controller: startTimeController,
                          decoration: InputDecoration(
                            labelText: 'Start time (mm:ss)',
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
                            hintText: 'Start time',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(
                      width: 10,
                    ),
                    Expanded(
                      flex: 30,
                      child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: CupertinoTimerPicker(
                            mode: CupertinoTimerPickerMode.ms,
                            initialTimerDuration:
                                Duration(milliseconds: widget.startTime),
                            // This is called when the user changes the timer's
                            // duration.
                            onTimerDurationChanged: (Duration newStartTime) {
                              setState(() {
                                editStartTime = newStartTime.inMilliseconds;
                                startTimeController.text = printDuration(
                                    Duration(
                                        milliseconds:
                                            newStartTime.inMilliseconds));
                              });
                            },
                          )),
                    ),
                    Expanded(
                      flex: 20,
                      child: CupertinoPicker(
                        magnification: 1.22,
                        squeeze: 1.2,
                        useMagnifier: true,
                        itemExtent: 32,
                        // This sets the initial item.
                        scrollController: FixedExtentScrollController(
                          initialItem: _millisecondsbythehundreds
                              .indexOf(editStartTimeMS),
                        ),
                        // This is called when selected item is changed.
                        onSelectedItemChanged: (int selectedItem) {
                          setState(() {
                            editStartTimeMS =
                                _millisecondsbythehundreds[selectedItem];
                            debugPrint(_millisecondsbythehundreds[selectedItem]
                                .toString());
                          });
                        },
                        children: List<Widget>.generate(
                            _millisecondsbythehundreds.length, (int index) {
                          return Center(
                              child: Text(
                                  '${_millisecondsbythehundreds[index]} ms'));
                        }),
                      ),
                    ),
                    // add play and resume buttons
                    Expanded(
                      flex: 20,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.play_arrow),
                              color: Theme.of(context).primaryColor,
                              iconSize: 45,
                              onPressed: () {
                                // Add your play functionality here
                                ref
                                    .read(spotifyRemoteRepositoryProvider)
                                    .playSpotiyfyUriAndJumpStart(
                                        spotifyUriController.text.isEmpty
                                            ? mp3UriController.text
                                            : spotifyUriController.text,
                                        getStartTime());
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.pause),
                              color: Theme.of(context).primaryColor,
                              iconSize: 45,
                              onPressed: () {
                                // Add your pause functionality here
                                ref
                                    .read(spotifyRemoteRepositoryProvider)
                                    .pausePlayer();
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    Expanded(
                      flex: 20,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: TextField(
                          controller: durationController,
                          decoration: InputDecoration(
                            labelText: 'Duration (mm:ss)',
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
                            hintText: 'duration',
                          ),
                        ),
                      ),
                    ),
                    const Expanded(flex: 80, child: SizedBox()),
                  ])),
              const SizedBox(
                height: 10,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: TextField(
                  controller: spotifyUriController,
                  decoration: InputDecoration(
                    labelText: 'Spotify uri',
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
                  controller: networkImageUriController,
                  decoration: InputDecoration(
                    labelText: 'Network image uri',
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                          color: Theme.of(context).primaryColor, width: 2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                          color: Theme.of(context).primaryColor, width: 2),
                    ),
                    hintText: ' Network image uri',
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: TextField(
                  controller: mp3UriController,
                  decoration: InputDecoration(
                    labelText: 'Mp3 path and name',
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
                                startTimeMS: editStartTimeMS,
                                playCount: 0,
                                networkImageUri: networkImageUriController.text,
                              ),
                            );
                      } else {
                        ref.read(hiveTrackData.notifier).updateDJTrack(
                              DJTrack(
                                id: widget.id,
                                name: nameController.text,
                                album: albumController.text,
                                artist: artistController.text,
                                spotifyUri: spotifyUriController.text,
                                mp3Uri: mp3UriController.text,
                                duration: widget.duration,
                                startTime: editStartTime,
                                startTimeMS: editStartTimeMS,
                                playCount: widget.playCount,
                                networkImageUri: widget.networkImageUri,
                              ),
                            );
                      }
                      Navigator.pop(context);
                    },
                    child: Text(
                      widget.id.isEmpty ? 'Create' : 'Update',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
