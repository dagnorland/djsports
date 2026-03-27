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
import 'package:djsports/features/playlist/widgets/dj_buttons.dart';
import 'package:djsports/features/playlist/widgets/djplaylist_tracks_view.dart';
import 'package:djsports/features/playlist/widgets/playlist_examples_dropdown.dart';
import 'package:djsports/features/spotify_playlist_sync/spotify_playlist_sync_delegate.dart';
import 'package:djsports/features/spotify_search/spotify_search_delegate.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';

// Riverpod
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:spotify/spotify.dart';

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
  bool _showDetails = false;

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
      setState(() => _errorMessage = 'Value cannot be empty');
      return;
    }
    final value = int.tryParse(text);
    if (value == null || value < 1 || value > 99) {
      setState(() => _errorMessage = 'Value must be between 1 and 99');
    } else {
      setState(() => _errorMessage = '');
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString())),
          );
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
            onPressed: () =>
                ScaffoldMessenger.of(context).hideCurrentSnackBar(),
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
            refreshCallback: () => setState(() {}),
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
            onPressed: () =>
                ScaffoldMessenger.of(context).hideCurrentSnackBar(),
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
            onPressed: () =>
                ScaffoldMessenger.of(context).hideCurrentSnackBar(),
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
            onPressed: () =>
                ScaffoldMessenger.of(context).hideCurrentSnackBar(),
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

  Widget _sectionContainer({required Widget child, Color? color}) {
    final primary = Theme.of(context).primaryColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color ?? primary.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: primary.withOpacity(0.15)),
      ),
      child: child,
    );
  }

  Widget _buildNameField() {
    return TextField(
      controller: nameController,
      decoration: const InputDecoration(
        labelText: 'Playlist name',
        hintText: 'Enter name',
      ),
    );
  }

  Widget _buildTypeDropdown() {
    return DropdownButtonFormField<DJPlaylistType>(
      value: selectedType,
      decoration: const InputDecoration(
        labelText: 'Type',
      ),
      items: DJPlaylistType.values
          .where((t) => t != DJPlaylistType.all)
          .map(
            (t) => DropdownMenuItem(
              value: t,
              child: Text(
                t.name.toUpperCase(),
                style: TextStyle(
                  color: t.color,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value != null) setState(() => selectedType = value);
      },
    );
  }

  Widget _buildUriField() {
    return TextField(
      controller: spotifyUriController,
      onChanged: (value) => setState(() {
        spotifyUriController.text = spotifyUriValidate(value);
      }),
      decoration: const InputDecoration(
        labelText: 'Spotify URI',
        hintText: 'Paste Spotify playlist URI',
      ),
    );
  }

  Widget _buildSyncButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DJIconActionButton(
          icon: Icons.sync,
          tooltip: 'Sync from Spotify playlist',
          onPressed: () => setState(() {
            _spotifyPlaylistSync(
                context, ref, spotifyUriController.text);
          }),
        ),
        DJIconActionButton(
          icon: Icons.search,
          tooltip: 'Search Spotify',
          onPressed: () => setState(() {
            _showSearch(context, ref);
          }),
        ),
        DJIconActionButton(
          icon: Icons.playlist_add_circle_outlined,
          tooltip: 'Browse playlist tracks',
          onPressed: () => setState(() {
            _spotifyTrackSync(context, ref, spotifyUriController.text);
          }),
        ),
      ],
    );
  }

  Widget _buildSettingsRow(bool isWide) {
    final primary = Theme.of(context).primaryColor;
    final positionField = SizedBox(
      width: 54,
      child: CupertinoTextField(
        maxLength: 2,
        keyboardType: TextInputType.number,
        controller: positionController,
        placeholder: '1–99',
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      ),
    );

    final trackCount = Text(
      'Tracks: ${trackIds.length}',
      style: TextStyle(
        color: primary,
        fontWeight: FontWeight.w600,
      ),
    );

    if (isWide) {
      return _sectionContainer(
        child: Row(
          children: [
            CupertinoCheckbox(
              value: shuffleAtEnd,
              onChanged: (v) => setState(() => shuffleAtEnd = v ?? true),
            ),
            const SizedBox(width: 6),
            const Text('Shuffle at end'),
            const Gap(20),
            CupertinoCheckbox(
              value: autoNext,
              onChanged: (v) => setState(() => autoNext = v ?? true),
            ),
            const SizedBox(width: 6),
            const Text('Auto next'),
            const Gap(20),
            const Text('Position'),
            const SizedBox(width: 8),
            positionField,
            const Spacer(),
            trackCount,
          ],
        ),
      );
    }

    // Narrow: two rows
    return _sectionContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CupertinoCheckbox(
                value: shuffleAtEnd,
                onChanged: (v) => setState(() => shuffleAtEnd = v ?? true),
              ),
              const SizedBox(width: 6),
              const Expanded(child: Text('Shuffle at end')),
              CupertinoCheckbox(
                value: autoNext,
                onChanged: (v) => setState(() => autoNext = v ?? true),
              ),
              const SizedBox(width: 6),
              const Text('Auto next'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Position'),
              const SizedBox(width: 8),
              positionField,
              const Spacer(),
              trackCount,
            ],
          ),
        ],
      ),
    );
  }

  void _shuffleTracks() {
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
      playlistTrackList =
          ref.read(hiveTrackData.notifier).getDJTracks(trackIds);
    });
  }

  void _savePlaylist() {
    String newPlayListId = '';
    if (widget.id.isEmpty) {
      newPlayListId = newPlaylistFromFormData();
    } else {
      ref.read(hivePlaylistData.notifier).updateDJPlaylist(
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
              position: int.parse(positionController.text),
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
            position: int.parse(positionController.text),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    final isWide = MediaQuery.of(context).size.width >= 600;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        leading: IconButton(
          onPressed: () {
            Navigator.of(context).pop();
            widget.refreshCallback ?? widget.refreshCallback;
          },
          icon: const Icon(Icons.arrow_back, color: Colors.black, size: 26),
        ),
        title: Text(
          widget.id.isEmpty ? 'Create Playlist' : 'Edit Playlist',
          style: TextStyle(
            color: primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (ref
              .read(spotifyRemoteRepositoryProvider)
              .hasSpotifyAccessToken) ...[
            IconButton(
              onPressed: () => setState(() {
                ref.read(spotifyRemoteRepositoryProvider).resumePlayer();
              }),
              icon: Icon(Icons.play_arrow, color: primary),
            ),
            IconButton(
              onPressed: () => setState(() {
                ref.read(spotifyRemoteRepositoryProvider).pausePlayer();
              }),
              icon: Icon(Icons.pause, color: primary),
            ),
          ],
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Name + Type ──────────────────────────────────────────
            if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 65, child: _buildNameField()),
                  const SizedBox(width: 12),
                  Expanded(flex: 35, child: _buildTypeDropdown()),
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildNameField(),
                  const SizedBox(height: 10),
                  _buildTypeDropdown(),
                ],
              ),
            const SizedBox(height: 8),

            // ── Show details toggle + Cancel/Update ──────────────────
            Row(
              children: [
                DJTextIconButton(
                  icon: _showDetails
                      ? Icons.expand_less
                      : Icons.expand_more,
                  label:
                      _showDetails ? 'Hide details' : 'Show details',
                  onPressed: () =>
                      setState(() => _showDetails = !_showDetails),
                ),
                const Spacer(),
                DJCancelButton(
                  onPressed: () => Navigator.pop(context),
                ),
                DJPrimaryButton(
                  label: widget.id.isEmpty ? 'Create' : 'Update',
                  onPressed:
                      _errorMessage.isNotEmpty ? null : _savePlaylist,
                ),
              ],
            ),

            // ── Collapsible details ──────────────────────────────────
            if (_showDetails) ...[
              const SizedBox(height: 8),

              // Spotify URI + Sync
              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(flex: 75, child: _buildUriField()),
                    const SizedBox(width: 8),
                    _buildSyncButtons(),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildUriField(),
                    const SizedBox(height: 4),
                    Row(children: [_buildSyncButtons()]),
                  ],
                ),

              // Example playlist dropdown (when URI is empty)
              if (spotifyUriController.text.isEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      flex: isWide ? 65 : 100,
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
                    if (isWide) ...[
                      const SizedBox(width: 12),
                      const Expanded(
                        flex: 35,
                        child: Text(
                          'Use an example playlist',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
              const SizedBox(height: 10),

              // Settings
              _buildSettingsRow(isWide),
              if (_errorMessage.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  _errorMessage,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 8),

              // Sync start times + Shuffle
              Row(
                children: [
                  if (isWide) ...[
                    DJTextIconButton(
                      icon: Icons.sync,
                      label: 'Sync start times',
                      onPressed: () =>
                          syncMissingStartTimes(playlistTrackList),
                    ),
                    const Gap(4),
                    DJTextIconButton(
                      icon: Icons.shuffle,
                      label: 'Shuffle',
                      onPressed: _shuffleTracks,
                    ),
                  ] else ...[
                    DJIconActionButton(
                      icon: Icons.sync,
                      tooltip: 'Sync start times',
                      onPressed: () =>
                          syncMissingStartTimes(playlistTrackList),
                    ),
                    DJIconActionButton(
                      icon: Icons.shuffle,
                      tooltip: 'Shuffle tracks',
                      onPressed: _shuffleTracks,
                    ),
                  ],
                ],
              ),
            ],

            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // ── Track list ───────────────────────────────────────────
            _buildTrackList(playlistTrackList),
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

  Widget _buildTrackList(List<DJTrack> tracks) {
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
            playlistType: selectedType,
            onEdit: () {
              ref.invalidate(dataTrackProvider);
              handleTrackEdit(
                id: widget.id,
                track: tracks[index],
                index: index,
              );
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
          trackCount: playlistTrackList.length,
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
    if (value.isEmpty) return '';
    if (value.contains('https://open.spotify.com/playlist/')) {
      return value.substring('https://open.spotify.com/playlist/'.length);
    }
    if (value.contains('https://open.spotify.com/album/')) {
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
