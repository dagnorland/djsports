import 'dart:async';

import 'package:djsports/data/repo/apple_music_repository.dart';
import 'package:djsports/data/models/djtrack_model.dart';
import 'package:djsports/data/provider/apple_music_provider.dart';
import 'package:djsports/data/provider/djtrack_provider.dart';
import 'package:djsports/data/repo/spotify_remote_repository.dart';
import 'package:djsports/features/spotify_connect/spotify_output_sheet.dart';
import 'package:djsports/features/playlist/start_time_slider.dart';
import 'package:djsports/features/playlist/widgets/dj_buttons.dart';
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
    required this.trackCount,
    this.appleMusicId = '',
    this.initialAutoPreview = false,
    this.previousTrack,
    this.nextTrack,
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
  final int trackCount;
  final String appleMusicId;
  final bool initialAutoPreview;

  /// Neighbours in the playlist, shown as step cards on wide screens.
  final DJTrack? previousTrack;
  final DJTrack? nextTrack;

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
  final startTimeController = TextEditingController();

  String playlistId = '';
  String playlistName = '';
  int editStartTime = 0;
  int editStartTimeMS = 0;
  String trackDurationFormatted = '--:--';
  late bool autoPreview;

  Timer? _positionTimer;
  int _livePositionMs = 0;
  bool _isPolling = false;

  int get _totalStartMs => editStartTime + editStartTimeMS;

  /// Apple Music only on iPhone/iPad/Mac; elsewhere Spotify if possible.
  bool get _usesAppleMusic =>
      playsWithAppleMusic(widget.appleMusicId, widget.spotifyUri);

  int get _effectiveMaxMs => widget.duration > 0 ? widget.duration : 300000;

  void _navigateTo(int targetIndex) {
    if (_usesAppleMusic) {
      ref.read(appleMusicRepositoryProvider).pausePlayer();
    } else {
      ref.read(spotifyRemoteRepositoryProvider).pausePlayer();
    }
    _stopPositionPolling();
    Navigator.pop(context, (targetIndex, autoPreview));
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
      if (_usesAppleMusic) {
        ref
            .read(appleMusicRepositoryProvider)
            .playAppleMusicIdAndJumpStart(
              widget.appleMusicId,
              parseStartTime(),
            );
      } else {
        _playSpotifyPreview();
        _startPositionPolling();
      }
    }
  }

  /// Spotify preview; asks where to play when no device is available.
  void _playSpotifyPreview() {
    final uri = spotifyUriController.text.isEmpty
        ? mp3UriController.text
        : spotifyUriController.text;
    playWithDevicePrompt(
      context,
      ref,
      () => ref
          .read(spotifyRemoteRepositoryProvider)
          .playSpotiyfyUriAndJumpStart(uri, parseStartTime()),
    );
  }

  void _nudgeStart(int deltaMs) {
    _onSliderChanged(
      (_totalStartMs + deltaMs).clamp(0, _effectiveMaxMs).toDouble(),
    );
    _onSliderChangeEnd(_totalStartMs.toDouble());
  }

  void _playPreview() {
    if (_usesAppleMusic) {
      ref
          .read(appleMusicRepositoryProvider)
          .playAppleMusicIdAndJumpStart(widget.appleMusicId, parseStartTime());
    } else {
      _playSpotifyPreview();
      _startPositionPolling();
    }
  }

  void _pausePreview() {
    if (_usesAppleMusic) {
      ref.read(appleMusicRepositoryProvider).pausePlayer();
    } else {
      ref.read(spotifyRemoteRepositoryProvider).pausePlayer();
    }
    _stopPositionPolling();
  }

  void _startPositionPolling() {
    _positionTimer?.cancel();
    _isPolling = true;
    _positionTimer = Timer.periodic(const Duration(milliseconds: 500), (
      _,
    ) async {
      if (!mounted || !_isPolling) return;
      final ms = await ref
          .read(spotifyRemoteRepositoryProvider)
          .getPlaybackPositionMs();
      if (mounted) setState(() => _livePositionMs = ms);
    });
  }

  void _stopPositionPolling() {
    _positionTimer?.cancel();
    _positionTimer = null;
    _isPolling = false;
    // Keep _livePositionMs so the paused position stays visible.
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _positionTimer?.cancel();
    nameController.dispose();
    spotifyUriController.dispose();
    albumController.dispose();
    artistController.dispose();
    mp3UriController.dispose();
    networkImageUriController.dispose();
    startTimeController.dispose();
    super.dispose();
  }

  void updateTrack({bool goToNextTrack = false}) {
    if (widget.id.isEmpty) {
      ref
          .read(hiveTrackData.notifier)
          .addDJTrack(
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
              appleMusicId: widget.appleMusicId,
            ),
          );
    } else {
      ref
          .read(hiveTrackData.notifier)
          .updateDJTrack(
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
              appleMusicId: widget.appleMusicId,
            ),
          );
    }
    if (_usesAppleMusic) {
      ref.read(appleMusicRepositoryProvider).pausePlayer();
    } else {
      ref.read(spotifyRemoteRepositoryProvider).pausePlayer();
    }

    if (goToNextTrack && widget.index >= 0) {
      Navigator.pop(context, (widget.index + 1, autoPreview));
    } else {
      Navigator.pop(context);
    }
  }

  Widget _field(TextEditingController controller, String label, String hint) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(labelText: label, hintText: hint),
    );
  }

  Widget _sectionContainer({required Widget child}) {
    final primary = Theme.of(context).primaryColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: primary.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: primary.withOpacity(0.15)),
      ),
      child: child,
    );
  }

  Widget _buildMetadataSection(bool isWide) {
    if (isWide) {
      final fields = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _field(nameController, 'Name', 'Track name')),
              const Gap(16),
              Expanded(child: _field(albumController, 'Album', 'Album name')),
              const Gap(16),
              Expanded(
                child: _field(artistController, 'Artist', 'Artist name'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _field(spotifyUriController, 'Spotify URI', 'spotify:track:...'),
        ],
      );
      // Cover leftmost, as tall as the two rows of fields – only when the
      // three fields still get a decent width next to it.
      final showCover =
          widget.id.isNotEmpty && MediaQuery.of(context).size.width >= 800;
      return _sectionContainer(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (showCover) ...[
              _CurrentCover(uri: widget.networkImageUri, size: 128),
              const Gap(16),
            ],
            Expanded(child: fields),
          ],
        ),
      );
    }
    return _sectionContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _field(nameController, 'Name', 'Track name'),
          const SizedBox(height: 12),
          _field(albumController, 'Album', 'Album name'),
          const SizedBox(height: 12),
          _field(artistController, 'Artist', 'Artist name'),
          const SizedBox(height: 12),
          _field(spotifyUriController, 'Spotify URI', 'spotify:track:...'),
        ],
      ),
    );
  }

  Widget _buildStartTimeSection(bool isWide, Color primary) {
    final playBtn = IconButton(
      icon: const Icon(Icons.play_arrow),
      color: primary,
      iconSize: 36,
      onPressed: _playPreview,
    );
    final pauseBtn = IconButton(
      icon: const Icon(Icons.pause),
      color: primary,
      iconSize: 36,
      onPressed: _pausePreview,
    );

    final autoPreviewToggle = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(
          value: autoPreview,
          onChanged: (v) => setState(() => autoPreview = v ?? false),
        ),
        Text('Auto Preview', style: TextStyle(color: primary)),
      ],
    );

    final volumeControls = ValueListenableBuilder<double>(
      valueListenable: ref.read(spotifyRemoteRepositoryProvider).volumeNotifier,
      builder: (context, volume, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.volume_down),
            tooltip: 'Volume -5%',
            color: primary,
            iconSize: 28,
            onPressed: () =>
                ref.read(spotifyRemoteRepositoryProvider).adjustVolume(-0.05),
          ),
          Text(
            '${(volume * 100).round()}%',
            style: TextStyle(color: primary, fontWeight: FontWeight.w600),
          ),
          IconButton(
            icon: const Icon(Icons.volume_up),
            tooltip: 'Volume +5%',
            color: primary,
            iconSize: 28,
            onPressed: () =>
                ref.read(spotifyRemoteRepositoryProvider).adjustVolume(0.05),
          ),
        ],
      ),
    );

    final cupertinoSlider = StartTimeSlider(
      valueMs: _totalStartMs,
      maxMs: _effectiveMaxMs,
      color: primary,
      onChanged: _onSliderChanged,
      onChangeEnd: _onSliderChangeEnd,
      onNudgeMinus: () => _nudgeStart(-500),
      onNudgePlus: () => _nudgeStart(500),
    );

    final livePosition = _livePositionMs > 0
        ? Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 8,
                  color: _isPolling ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 6),
                Text(
                  StartTimeSlider.formatMs(_livePositionMs),
                  style: TextStyle(
                    color: primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _isPolling ? 'now playing' : 'paused at',
                  style: TextStyle(
                    color: primary.withOpacity(0.55),
                    fontSize: 11,
                  ),
                ),
                if (!_isPolling) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 26,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () =>
                          _onSliderChanged(_livePositionMs.toDouble()),
                      child: Text(
                        'Set as start',
                        style: TextStyle(fontSize: 12, color: primary),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          )
        : const SizedBox.shrink();

    if (isWide) {
      return _sectionContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                playBtn,
                pauseBtn,
                const Spacer(),
                autoPreviewToggle,
                const Gap(8),
                volumeControls,
              ],
            ),
            cupertinoSlider,
            livePosition,
          ],
        ),
      );
    }

    // Narrow: multi-row layout
    return _sectionContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Play/pause + auto preview
          Row(children: [playBtn, pauseBtn, const Spacer(), autoPreviewToggle]),
          // Row 3: volume
          Row(
            children: [
              Text('Volume', style: TextStyle(color: primary, fontSize: 13)),
              const Spacer(),
              volumeControls,
            ],
          ),
          const SizedBox(height: 4),
          cupertinoSlider,
          livePosition,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    final isWide = MediaQuery.of(context).size.width >= 600;

    final titleText = widget.id.isEmpty ? 'Create Track' : widget.name;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, size: 26),
        ),
        actions: [
          // Big, easy-to-hit steps between tracks, the position in between.
          if (widget.id.isNotEmpty) ...[
            _TrackStepButton(
              icon: Icons.chevron_left_rounded,
              tooltip: 'Previous track',
              color: primary,
              onPressed: widget.index > 0
                  ? () => _navigateTo(widget.index - 1)
                  : null,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${widget.index + 1}',
                    style: TextStyle(
                      color: primary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    'of ${widget.trackCount}',
                    style: TextStyle(
                      color: primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            _TrackStepButton(
              icon: Icons.chevron_right_rounded,
              tooltip: 'Next track',
              color: primary,
              onPressed: widget.index < widget.trackCount - 1
                  ? () => _navigateTo(widget.index + 1)
                  : null,
            ),
          ],
          const SizedBox(width: 8),
        ],
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              titleText,
              style: TextStyle(
                color: primary,
                fontWeight: FontWeight.bold,
                fontSize: isWide ? 18 : 15,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (playlistName.isNotEmpty)
              Text(
                playlistName,
                style: TextStyle(
                  color: Theme.of(context).hintColor,
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Name / Album / Artist ─────────────────────────────
              _buildMetadataSection(isWide),
              const SizedBox(height: 12),

              // ── Start time ────────────────────────────────────────
              _buildStartTimeSection(isWide, primary),
              const SizedBox(height: 16),

              // ── Buttons ───────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  DJCancelButton(onPressed: () => Navigator.pop(context)),
                  const SizedBox(width: 4),
                  DJPrimaryButton(
                    label: widget.id.isEmpty ? 'Create' : 'Update',
                    onPressed: () => updateTrack(goToNextTrack: false),
                  ),
                  if (widget.id.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    DJPrimaryButton(
                      label: isWide ? 'Update & next track' : 'Update & next',
                      onPressed: () => updateTrack(goToNextTrack: true),
                    ),
                  ],
                ],
              ),

              // ── Previous / next track ─────────────────────────────
              if (isWide && widget.id.isNotEmpty) ...[
                const SizedBox(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: widget.previousTrack == null
                          ? const SizedBox.shrink()
                          : _NeighbourTrackCard(
                              track: widget.previousTrack!,
                              label: 'Previous',
                              position: widget.index,
                              isNext: false,
                              color: primary,
                              onTap: () => _navigateTo(widget.index - 1),
                            ),
                    ),
                    const Gap(16),
                    Expanded(
                      child: widget.nextTrack == null
                          ? const SizedBox.shrink()
                          : _NeighbourTrackCard(
                              track: widget.nextTrack!,
                              label: 'Next',
                              position: widget.index + 2,
                              isNext: true,
                              color: primary,
                              onTap: () => _navigateTo(widget.index + 1),
                            ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Tappable preview of the previous or next track: cover, name, artist and
/// start time. Fills the empty lower half of the editor on a tablet/Mac.
class _NeighbourTrackCard extends StatelessWidget {
  const _NeighbourTrackCard({
    required this.track,
    required this.label,
    required this.position,
    required this.isNext,
    required this.color,
    required this.onTap,
  });

  final DJTrack track;
  final String label;
  final int position;
  final bool isNext;
  final Color color;
  final VoidCallback onTap;

  String get _start {
    final ms = track.startTime + track.startTimeMS;
    if (ms <= 0) return 'No start time';
    final d = Duration(milliseconds: ms);
    final mm = d.inMinutes.toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return 'Start $mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final arrow = Icon(
      isNext ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
      color: color,
      size: 32,
    );
    final cover = ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox.square(
        dimension: 72,
        child: track.networkImageUri.isNotEmpty
            ? Image.network(
                track.networkImageUri,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const _CoverPlaceholder(),
              )
            : const _CoverPlaceholder(),
      ),
    );
    final details = Expanded(
      child: Column(
        crossAxisAlignment: isNext
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Text(
            '$label · $position',
            style: text.labelMedium?.copyWith(
              color: color.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            track.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: isNext ? TextAlign.end : TextAlign.start,
            style: text.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            track.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.bodyMedium?.copyWith(
              color: color.withValues(alpha: 0.7),
            ),
          ),
          Text(
            _start,
            style: text.bodySmall?.copyWith(
              color: color.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );

    return Material(
      color: color.withValues(alpha: 0.04),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: color.withValues(alpha: 0.15)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: isNext
                ? [details, const Gap(12), cover, arrow]
                : [arrow, cover, const Gap(12), details],
          ),
        ),
      ),
    );
  }
}

/// The current track's album art, leftmost in the name/album/artist box.
class _CurrentCover extends StatelessWidget {
  const _CurrentCover({required this.uri, required this.size});

  final String uri;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
      clipBehavior: Clip.antiAlias,
      child: uri.isNotEmpty
          ? Image.network(
              uri,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const _CoverPlaceholder(),
            )
          : const _CoverPlaceholder(),
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(Icons.music_note, color: Theme.of(context).hintColor),
    );
  }
}

/// A round 44 px step button for the track editor's AppBar (the old ones
/// were 32 px and hard to hit on a tablet).
class _TrackStepButton extends StatelessWidget {
  const _TrackStepButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      icon: Icon(icon),
      tooltip: tooltip,
      iconSize: 30,
      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.12),
        foregroundColor: color,
        disabledBackgroundColor: color.withValues(alpha: 0.04),
        disabledForegroundColor: color.withValues(alpha: 0.26),
      ),
      onPressed: onPressed,
    );
  }
}
