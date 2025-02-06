import 'dart:convert';

import 'package:djsports/data/models/djtrack_model.dart';
import 'package:djsports/data/models/track_time_model.dart';
import 'package:djsports/data/provider/track_time_provider.dart';
import 'package:djsports/data/provider/djtrack_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';

// Localization
//models

// Riverpod
import 'package:hooks_riverpod/hooks_riverpod.dart';

//Providers

class TrackTimeCenterScreen extends StatefulHookConsumerWidget {
  const TrackTimeCenterScreen({
    super.key,
    this.refreshCallback,
  });

  final VoidCallback? refreshCallback;

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _EditScreenState();
}

class _EditScreenState extends ConsumerState<TrackTimeCenterScreen> {
  final nameController = TextEditingController();
  final importJsonDataController = TextEditingController();
  List<TrackTime> trackTimeList = [];
  List<DJTrack> trackWithStartTimeList = [];
  int trackWithZeroStartTimeListLength = 0;

  //FutureOr Function(dynamic value) get result => false;

  @override
  void initState() {
    nameController.text = '';
    importJsonDataController.text = '';
    importJsonDataController.addListener(() {
      setState(() {});
    });
    super.initState();
  }

  @override
  void dispose() {
    importJsonDataController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Lytt til endringer i djTracksProvider
    final djTrackWithStartTimeList = ref.watch(dataTrackWithStartTimeProvider);
    trackWithZeroStartTimeListLength = ref
        .watch(dataTrackProvider)
        .where((element) => element.startTime == 0)
        .length;

    trackTimeList = ref.watch(dataTrackTimeProvider);

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
        actions: [],
        title: const Text(
          'Import and export track times',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            children: [
              infoAboutImportExport(context),
              const Gap(20),
              globalInfoBox(
                  context,
                  'EXPORTING TRACK TIMES',
                  exportingTrackTimeList(
                      context, djTrackWithStartTimeList, trackTimeList)),
              const Gap(20),
              globalInfoBox(
                  context,
                  'IMPORTING TRACK TIMES',
                  importingTrackTimeList(
                      context, djTrackWithStartTimeList, trackTimeList)),
              const Gap(60),
              const Divider(
                color: Colors.red,
                height: 1,
              ),
              const Gap(20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).canvasColor,
                      disabledBackgroundColor:
                          Theme.of(context).primaryColor.withOpacity(0.3),
                    ),
                    onPressed: trackTimeList.isEmpty
                        ? null
                        : () {
                            deleteAllOrZeroTimeTrackTimes(trackTimeList, false);
                          },
                    child: Text(
                      'DELETE all track times. Only the import/export list',
                      style: Theme.of(context).textTheme.titleLarge!.copyWith(
                            color: trackTimeList.isEmpty
                                ? Colors.white.withOpacity(0.5)
                                : Colors.red,
                          ),
                    ),
                  ),
                  const Gap(10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).canvasColor,
                      disabledBackgroundColor:
                          Theme.of(context).primaryColor.withOpacity(0.3),
                    ),
                    onPressed: trackTimeList.isEmpty
                        ? null
                        : () {
                            deleteAllOrZeroTimeTrackTimes(trackTimeList, true);
                          },
                    child: Text(
                      'Delete track times with no start time cleanup)',
                      style: Theme.of(context).textTheme.titleLarge!.copyWith(
                            color: trackTimeList.isEmpty
                                ? Colors.white.withOpacity(0.5)
                                : Colors.red,
                          ),
                    ),
                  ),
                ],
              ),
              const Gap(20),
              const Divider(
                color: Colors.red,
                height: 1,
              ),
            ],
          ),
        ),
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
    return value;
  }

  void updateTrackTimeListWithMissingTracks(
      List<DJTrack> djTrackWithStartTimeList, List<TrackTime> trackTimeList) {
    // get all tracks from djTrackWithStartTimeList
    final allTracks =
        djTrackWithStartTimeList.map((e) => TrackTime.fromDJTrack(e)).toList();

    // Legg til hvert spor i TrackTime-repositoriet
    for (final trackTime in allTracks) {
      ref.read(hiveTrackTimeData.notifier).addTrackTime(trackTime);
    }

    // Oppdater den lokale listen
    setState(() {
      trackTimeList = allTracks;
    });
  }

  int exportTrackTimeListToClipboard(List<TrackTime> trackTimeList) {
    // convert the trackTimeList to a json string
    final jsonString = jsonEncode(trackTimeList);
    // copy the json string to the clipboard
    Clipboard.setData(ClipboardData(text: jsonString));
    return jsonString.length;
  }

  void importTrackTimeJsonData(String jsonString) {
    try {
      // Parse JSON string til List<dynamic>

      List<dynamic> tempDecoded = json.decode(jsonString) as List<dynamic>;

      List<TrackTime> importedTracks = tempDecoded
          .map((jsonTrack) =>
              TrackTime.fromJson(jsonTrack as Map<String, dynamic>))
          .toList();
      for (final trackTime in importedTracks) {
        if (trackTime.startTime == 0) {
          // skip if start time is 0
          continue;
        }
        ref.read(hiveTrackTimeData.notifier).addTrackTime(trackTime);
      }

      // Vis bekreftelsesmelding
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Importerte ${importedTracks.length} spor'),
          ),
        );
      }

      // Tøm input-feltet
      importJsonDataController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Feil ved import av JSON-data. Sjekk formatet.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void deleteAllOrZeroTimeTrackTimes(
      List<TrackTime> trackTimeList, bool onlyWithZeroStartTime) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm deletion'),
          content: Text(
            onlyWithZeroStartTime
                ? 'Are you sure you want to delete some of the ${trackTimeList.length} track time settings - only the ones with no start time?'
                : 'Are you sure you want to delete all ${trackTimeList.length} track time settings?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                for (final trackTime in trackTimeList) {
                  if (onlyWithZeroStartTime && trackTime.startTime == 0) {
                    ref
                        .read(hiveTrackTimeData.notifier)
                        .removeTrackTime(trackTime.id);
                    // skip delete
                  } else if (!onlyWithZeroStartTime) {
                    ref
                        .read(hiveTrackTimeData.notifier)
                        .removeTrackTime(trackTime.id);
                  }
                }
                setState(() {
                  trackTimeList =
                      trackTimeList = ref.watch(dataTrackTimeProvider);
                });
              },
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget globalInfoBox(BuildContext context, String label, Widget child) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).primaryColor,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).canvasColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).hintColor,
                    ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }

  Widget exportingTrackTimeList(BuildContext context,
      List<DJTrack> djTrackWithStartTimeList, List<TrackTime> trackTimeList) {
    return Column(
      children: [
        Container(
            color: Theme.of(context).canvasColor,
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: SizedBox(),
                ),
                Expanded(
                  flex: 70,
                  child: Text(
                    '${djTrackWithStartTimeList.length} tracks with start time in your playlists. $trackWithZeroStartTimeListLength of them have no start time.',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const SizedBox(width: 10),
              ],
            )),
        const Gap(10),
        Container(
            color: Theme.of(context).canvasColor,
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: SizedBox(),
                ),
                Expanded(
                  flex: 70,
                  child: Text(
                    '${trackTimeList.length} in the import/export track time list',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            )),
        const Gap(20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
              ),
              onPressed: () {
                setState(() {
                  updateTrackTimeListWithMissingTracks(
                      djTrackWithStartTimeList, trackTimeList);
                });
              },
              child: Text(
                'Update track time list with missing tracks from you playlist for export',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge!
                    .copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
        const Gap(10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                disabledBackgroundColor:
                    Theme.of(context).primaryColor.withOpacity(0.3),
              ),
              onPressed: trackTimeList.isEmpty
                  ? null
                  : () {
                      final bytes =
                          exportTrackTimeListToClipboard(trackTimeList);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Track time list copied to clipboard ${bytes.toString()} bytes'),
                        ),
                      );
                    },
              child: Text(
                'Copy track time list in JSON format to clipboard',
                style: Theme.of(context).textTheme.titleLarge!.copyWith(
                      color: trackTimeList.isEmpty
                          ? Colors.white.withOpacity(0.5)
                          : Colors.white,
                    ),
              ),
            ),
          ],
        ),
        const Gap(20),
      ],
    );
  }

  String getExampleJsonData() {
    return '''
    [
      {"id":"6epn3r7S14KUqlReYr77hA","startTime":11000,"startTimeMS":0},
      {"id":"4vVTI94F9uJ8lHNDWKv0i2","startTime":36000,"startTimeMS":0},
      {"id":"0UODoSWbhBQyUhzL10D03d","startTime":13000,"startTimeMS":0},
      {"id":"18nFS1XdlXMPWbPkkPdawl","startTime":6000,"startTimeMS":0},
    ]
    ''';
  }

  Widget importingTrackTimeList(BuildContext context,
      List<DJTrack> djTrackWithStartTimeList, List<TrackTime> trackTimeList) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: TextField(
            controller: importJsonDataController,
            maxLines: 10,
            onChanged: (value) {
              setState(() {
                importJsonDataController.text = value;
              });
            },
            decoration: InputDecoration(
              hintText:
                  'Paste your JSON data here, the press button below to import'
                  '\nExample:\n'
                  '${getExampleJsonData()}',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Theme.of(context).primaryColor.withOpacity(0.05),
            ),
          ),
        ),
        const Gap(20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                disabledBackgroundColor:
                    Theme.of(context).primaryColor.withOpacity(0.3),
              ),
              onPressed: importJsonDataController.text.trim().isEmpty
                  ? null
                  : () {
                      importTrackTimeJsonData(
                          importJsonDataController.text.trim());
                    },
              child: Text(
                'Import track time json data with spotify uri and start time',
                style: Theme.of(context).textTheme.titleLarge!.copyWith(
                      color: importJsonDataController.text.trim().isEmpty
                          ? Colors.white.withOpacity(0.5)
                          : Colors.white,
                    ),
              ),
            ),
          ],
        ),
        const Gap(20),
      ],
    );
  }

  Widget infoAboutImportExport(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).primaryColor,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).canvasColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Text(
                'Info about using preset track times'.toUpperCase(),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            Container(
              color: Theme.of(context).cardColor,
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  const Expanded(flex: 5, child: SizedBox()),
                  Expanded(
                    flex: 65,
                    child: Text(
                      '- Tools for importing and exporting track start times. '
                      'You can import a list of track ids with start time. When making og syncing '
                      'playlists from Spotify, we can update these tracks with start time from the track time list. '
                      'All the tracks you have set a start time on can be exported to '
                      'the clipboard. The data is in JSON format. Then you can share the list with others using mail. '
                      'You can also import track with start time. ',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontStyle: FontStyle.normal,
                          ),
                    ),
                  ),
                  const Expanded(flex: 5, child: SizedBox()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
