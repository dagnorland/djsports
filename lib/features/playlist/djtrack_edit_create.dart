import 'package:djsports/data/models/djtrack_model.dart';
import 'package:djsports/data/provider/djtrack_provider.dart';
import 'package:djsports/data/repo/spotify_remote_repository.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
// Riverpod
import 'package:hooks_riverpod/hooks_riverpod.dart';

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
    required this.shortcut,
    this.initialAutoPreview = false,
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
  final String shortcut;
  final bool initialAutoPreview;

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
  // Kept for parseStartTime()
  final startTimeController = TextEditingController();

  String playlistId = '';
  String playlistName = '';
  int editStartTime = 0;
  int editStartTimeMS = 0;
  String trackDurationFormatted = '--:--';
  late bool autoPreview;

  // Total start position in ms
  int get _totalStartMs => editStartTime + editStartTimeMS;

  // Max slider value — fallback to 5 min if duration unknown
  double get _maxMs =>
      widget.duration > 0 ? widget.duration.toDouble() : 300000.0;

  String _formatMs(int ms) {
    final minutes = ms ~/ 60000;
    final seconds = (ms % 60000) ~/ 1000;
    final tenths = (ms % 1000) ~/ 100;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}.'
        '$tenths';
  }

  @override
  void initState() {
    autoPreview = widget.initialAutoPreview;
    if (!widget.isNew) {
      nameController.text = widget.name;
      albumController.text = widget.album;
      artistController.text = widget.artist;
      spotifyUriController.text = widget.spotifyUri;
      mp3UriController.text = widget.mp3Uri;
      networkImageUriController.text = widget.networkImageUri;
      startTimeController.text = _printDuration(
        Duration(milliseconds: widget.startTime),
      );
      editStartTime = widget.startTime;
      trackDurationFormatted = _printDuration(
        Duration(milliseconds: widget.duration),
      );
      editStartTimeMS = widget.startTimeMS;
    }
    playlistId = widget.playlistId;
    playlistName = widget.playlistName;
    super.initState();
  }

  String _printDuration(Duration duration) {
    String twoDigits(int n) => n >= 10 ? '$n' : '0$n';
    final mm = twoDigits(duration.inMinutes.remainder(60));
    final ss = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return '${twoDigits(duration.inHours)}:$mm:$ss';
    }
    return '$mm:$ss';
  }

  int parseStartTime() {
    try {
      final parts = startTimeController.text.split(':');
      final minutes = int.parse(parts[0]);
      final seconds = int.parse(parts[1]);
      return (minutes * 60 + seconds) * 1000 + editStartTimeMS;
    } catch (e) {
      return _totalStartMs;
    }
  }

  void _onSliderChanged(double value) {
    final ms = value.round();
    setState(() {
      editStartTime = (ms ~/ 1000) * 1000;
      editStartTimeMS = (ms % 1000 ~/ 100) * 100;
      startTimeController.text = _printDuration(
        Duration(milliseconds: editStartTime),
      );
    });
  }

  void _onSliderChangeEnd(double value) {
    if (autoPreview) {
      ref.read(spotifyRemoteRepositoryProvider).playSpotiyfyUriAndJumpStart(
            spotifyUriController.text.isEmpty
                ? mp3UriController.text
                : spotifyUriController.text,
            parseStartTime(),
          );
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
              shortcut: '',
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
              shortcut: '',
            ),
          );
    }
    ref.read(spotifyRemoteRepositoryProvider).pausePlayer();

    if (goToNextTrack && widget.index >= 0) {
      Navigator.pop(context, (widget.index + 1, autoPreview));
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.black, size: 30),
        ),
        title: Text(
          widget.id.isEmpty
              ? 'Create Track for $playlistName'
              : '#${widget.index} Edit Track for $playlistName',
          style: TextStyle(
            color: primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Name / Album / Artist row ──────────────────────────────
              Container(
                color: primary.withOpacity(0.05),
                child: Row(
                  children: [
                    _buildTextField(
                      controller: nameController,
                      label: 'Name',
                      hint: 'Enter name',
                      primary: primary,
                    ),
                    const Gap(20),
                    _buildTextField(
                      controller: albumController,
                      label: 'Album name',
                      hint: 'Enter album',
                      primary: primary,
                    ),
                    const Gap(20),
                    _buildTextField(
                      controller: artistController,
                      label: 'Artist name',
                      hint: 'Enter artist',
                      primary: primary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // ── Start time slider ──────────────────────────────────────
              Container(
                color: primary.withOpacity(0.05),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Start time',
                          style: TextStyle(
                            color: primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Gap(16),
                        Text(
                          _formatMs(_totalStartMs),
                          style: TextStyle(
                            color: primary,
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            fontFeatures: const [
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                        const Gap(8),
                        IconButton(
                          icon: const Icon(Icons.remove),
                          tooltip: '-1 second',
                          color: primary,
                          onPressed: () {
                            _onSliderChanged(
                              (_totalStartMs - 1000)
                                  .clamp(0, _maxMs.toInt())
                                  .toDouble(),
                            );
                            _onSliderChangeEnd(_totalStartMs.toDouble());
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          tooltip: '+1 second',
                          color: primary,
                          onPressed: () {
                            _onSliderChanged(
                              (_totalStartMs + 1000)
                                  .clamp(0, _maxMs.toInt())
                                  .toDouble(),
                            );
                            _onSliderChangeEnd(_totalStartMs.toDouble());
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.play_arrow),
                          color: primary,
                          iconSize: 40,
                          onPressed: () {
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
                          color: primary,
                          iconSize: 40,
                          onPressed: () => ref
                              .read(spotifyRemoteRepositoryProvider)
                              .pausePlayer(),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Checkbox(
                              value: autoPreview,
                              onChanged: (v) =>
                                  setState(() => autoPreview = v ?? false),
                            ),
                            Text(
                              'Auto Preview',
                              style: TextStyle(color: primary),
                            ),
                          ],
                        ),
                        const Gap(16),
                        IconButton(
                          icon: const Icon(Icons.volume_down),
                          tooltip: 'Volume -5%',
                          color: primary,
                          iconSize: 32,
                          onPressed: () => ref
                              .read(spotifyRemoteRepositoryProvider)
                              .adjustVolume(-0.05),
                        ),
                        ValueListenableBuilder<double>(
                          valueListenable: ref
                              .read(spotifyRemoteRepositoryProvider)
                              .volumeNotifier,
                          builder: (context, volume, _) => Text(
                            '${(volume * 100).round()}%',
                            style: TextStyle(
                              color: primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.volume_up),
                          tooltip: 'Volume +5%',
                          color: primary,
                          iconSize: 32,
                          onPressed: () => ref
                              .read(spotifyRemoteRepositoryProvider)
                              .adjustVolume(0.05),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          '0:00',
                          style: TextStyle(
                            color: primary.withOpacity(0.5),
                            fontSize: 12,
                          ),
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 6,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 10,
                              ),
                            ),
                            child: Slider(
                              min: 0,
                              max: _maxMs,
                              divisions: _maxMs.toInt() ~/ 100,
                              value: _totalStartMs
                                  .clamp(0, _maxMs.toInt())
                                  .toDouble(),
                              label: _formatMs(_totalStartMs),
                              activeColor: primary,
                              onChanged: _onSliderChanged,
                              onChangeEnd: _onSliderChangeEnd,
                            ),
                          ),
                        ),
                        Text(
                          trackDurationFormatted,
                          style: TextStyle(
                            color: primary.withOpacity(0.5),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // ── Buttons ────────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                    ),
                    onPressed: () => updateTrack(goToNextTrack: false),
                    child: Text(
                      widget.id.isEmpty ? 'Create' : 'Update',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  if (widget.id.isNotEmpty) ...[
                    const SizedBox(width: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                      ),
                      onPressed: () => updateTrack(goToNextTrack: true),
                      child: const Text(
                        'Update & next track',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required Color primary,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: TextField(
          controller: controller,
          decoration: _inputDecoration(
            label: label,
            hint: hint,
            primary: primary,
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required Color primary,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: primary, width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: primary, width: 2),
      ),
    );
  }
}
