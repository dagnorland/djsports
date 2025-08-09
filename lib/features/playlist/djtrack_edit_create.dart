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
import 'package:flutter/services.dart'; // + ADD

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
    required this.shortcut, // + ADD
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
  final String networkImageUri;
  final String id;
  final bool isNew;
  final int index;
  final String shortcut; // + ADD
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
  final startTextFieldTimeController = TextEditingController();
  final startTextFieldTimeFocusNode = FocusNode();
  final shortcutController = TextEditingController(); // + ADD

  String playlistId = '';
  String playlistName = '';
  int editStartTime = 0;
  int editStartTimeMS = 0;
  String trackDurationFormatted = 'hh:mm:ss';
  bool autoPreview = false;

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
          printDuration(Duration(milliseconds: widget.duration));
      startTimeController.text =
          printDuration(Duration(milliseconds: widget.startTime));
      startTextFieldTimeController.text =
          printDuration(Duration(milliseconds: widget.startTime));
      editStartTime = widget.startTime;
      trackDurationFormatted =
          printDuration((Duration(milliseconds: widget.duration)));
      editStartTimeMS = widget.startTimeMS;
      shortcutController.text = widget.shortcut; // + ADD
    }
    playlistId = widget.playlistId;
    playlistName = widget.playlistName;

    super.initState();

    // Sett fokus til startTextFieldTimeFocusNode etter at widget er bygget
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        FocusScope.of(context).requestFocus(startTextFieldTimeFocusNode);
      }
    });
  }

  @override
  void dispose() {
    startTextFieldTimeFocusNode.dispose();
    super.dispose();
  }

  String printDuration(Duration duration) {
    String twoDigits(int n) {
      if (n >= 10) return '$n';
      return '0$n';
    }

    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return '${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds';
    } else {
      return '$twoDigitMinutes:$twoDigitSeconds';
    }
  }

  int parseStartTime() {
    try {
      final startTimeParts = startTimeController.text.split(':');
      final minutes = int.parse(startTimeParts[0]);
      final seconds = int.parse(startTimeParts[1]);
      final totalMilliseconds =
          (minutes * 60 + seconds) * 1000 + editStartTimeMS;
      return totalMilliseconds;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: SelectableText.rich(
              TextSpan(
                text: 'Feil ved konvertering av starttid: $e',
                style: const TextStyle(color: Colors.red),
              ),
            ),
            backgroundColor: Colors.white,
          ),
        );
      }
      return 0;
    }
  }

  void updateTrack({bool goToNextTrack = false}) {
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
              shortcut: shortcutController.text.trim(), // + ADD
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
              shortcut: shortcutController.text.trim(), // + ADD
            ),
          );
    }
    ref.read(spotifyRemoteRepositoryProvider).pausePlayer();

    if (goToNextTrack && widget.index >= 0) {
      // Return the next track index to the parent
      Navigator.pop(context, widget.index + 1);
    } else {
      Navigator.pop(context);
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
              ? 'Create Track for $playlistName'
              : '#${widget.index} Edit Track for $playlistName',
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
                  constraints: const BoxConstraints(maxWidth: 1200),
                  color: Theme.of(context).primaryColor.withOpacity(0.05),
                  child: Row(children: [
                    Expanded(
                      flex: 22,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            Checkbox(
                              value: autoPreview,
                              onChanged: (bool? value) {
                                setState(() {
                                  autoPreview = value ?? false;
                                });
                              },
                            ),
                            Text(
                              'Auto Preview',
                              style: TextStyle(
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 30,
                      child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: SizedBox(
                            height: 220,
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
                                  if (autoPreview) {
                                    Future.delayed(
                                      const Duration(milliseconds: 200),
                                      () => ref
                                          .read(spotifyRemoteRepositoryProvider)
                                          .playSpotiyfyUriAndJumpStart(
                                            spotifyUriController.text.isEmpty
                                                ? mp3UriController.text
                                                : spotifyUriController.text,
                                            parseStartTime(),
                                          ),
                                    );
                                  }
                                });
                              },
                            ),
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
                    Expanded(
                        flex: 20,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                          ),
                          onPressed: () => updateTrack(goToNextTrack: false),
                          child: Text(
                            widget.id.isEmpty ? 'Create' : 'Update',
                            style: const TextStyle(color: Colors.white),
                          ),
                        )),
                    if (widget.id.isNotEmpty) ...[
                      const Gap(20),
                      Expanded(
                          flex: 35,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).primaryColor,
                            ),
                            onPressed: () => updateTrack(goToNextTrack: true),
                            child: Text(
                              'Update & next track',
                              style: const TextStyle(color: Colors.white),
                            ),
                          )),
                    ],
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
                                      parseStartTime(),
                                    );
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
                      child: TextField(
                        controller: startTextFieldTimeController,
                        focusNode: startTextFieldTimeFocusNode,
                        onChanged: (value) {
                          setState(() {
                            try {
                              final startTimeParts = value.split(':');
                              if (startTimeParts.length == 2) {
                                final minutes = int.parse(startTimeParts[0]);
                                final seconds = int.parse(startTimeParts[1]);
                                editStartTime = (minutes * 60 + seconds) * 1000;
                              }
                            } catch (e) {
                              // Håndter feil hvis formatet ikke er korrekt
                              // editStartTime forblir uendret
                            }
                          });
                        },
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
                          hintText: 'start time',
                        ),
                      ),
                    ),
                    const Gap(20),
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
              // + ADD shortcut field
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: TextField(
                  controller: shortcutController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(2),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Shortcut (nummer)',
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Theme.of(context).primaryColor,
                        width: 2,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Theme.of(context).primaryColor,
                        width: 2,
                      ),
                    ),
                    hintText: ' f.eks. 1',
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
                    onPressed: () => updateTrack(goToNextTrack: false),
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
