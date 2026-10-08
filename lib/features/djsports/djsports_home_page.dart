import 'dart:async';
import 'dart:io';

import 'package:djsports/core/theme/stage_colors.dart';
import 'package:djsports/core/widgets/flashing_logo.dart';
import 'package:djsports/data/repo/apple_music_repository.dart';
import 'package:djsports/data/models/spotify_connection_log.dart';
import 'package:djsports/data/models/djplaylist_model.dart';
import 'package:djsports/data/provider/apple_music_provider.dart';
import 'package:djsports/data/provider/djplaylist_provider.dart';
import 'package:djsports/data/provider/djtrack_provider.dart';
import 'package:djsports/data/repo/last_djtrack_played_repository.dart';
import 'package:djsports/data/repo/spotify_remote_repository.dart';
import 'package:djsports/data/services/spotify_platform_bridge.dart';
import 'package:djsports/features/cloud_backup/cloud_backup_screen.dart';
import 'package:djsports/features/djsports/playlist_help_screen.dart';
import 'package:djsports/features/djletsplay/djletsplay.dart';
import 'package:djsports/features/djmatch_center/widgets/current_volume_widget.dart';
import 'package:djsports/features/djsports/first_time_use_screen.dart';
import 'package:djsports/features/playlist/djplaylist_edit_create.dart';
import 'package:djsports/features/playlist/widgets/djplaylist_view.dart';
import 'package:djsports/features/track_time/settings_center_screen.dart';
import 'package:djsports/features/spotify_connect/spotify_output_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:spotify_sdk/spotify_sdk.dart';
import 'package:toastification/toastification.dart';

const _kMatchModeLabel = "Let's Play!";

class HomePage extends StatefulHookConsumerWidget {
  const HomePage({super.key});
  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  bool spotifyConnect = false;
  bool spotifyRemoteConnect = false;
  bool isPlaying = false;
  bool initStateConnectDone = false;
  bool appleMusicConnected = false;
  Timer? _connectionHealthCheckTimer;
  StreamSubscription<bool>? _connectionSubscription;
  StreamSubscription<bool>? _appleMusicSubscription;

  Future<void> _appleMusicConnect() async {
    final repo = ref.read(appleMusicRepositoryProvider);
    final ok = await repo.connect();
    if (mounted) setState(() => appleMusicConnected = ok);
    if (ok) unawaited(_prewarmAppleMusicCache());
  }

  Future<void> _prewarmAppleMusicCache() async {
    final ids = ref
        .read(dataTrackProvider)
        .map((t) => t.appleMusicId)
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (ids.isEmpty) return;
    final repo = ref.read(appleMusicRepositoryProvider);
    await repo.prewarmCache(ids);
    // Pick the last played Apple Music track (or first in list) for warmup
    final lastAppleMusicId = ref
        .read(lastDjTrackPlayedProvider)
        .maybeWhen(data: (t) => t?.appleMusicId ?? '', orElse: () => '');
    final warmupId = lastAppleMusicId.isNotEmpty ? lastAppleMusicId : ids.first;
    // Warmup: silent play+pause to establish streaming session (~600ms after this)
    await repo.warmupStreamingSession(warmupId);
    // Pre-set queue for the same track so play() can start immediately
    unawaited(repo.presetQueue(warmupId));
  }

  Future<void> _spotifyConnect(BuildContext context, WidgetRef ref) async {
    final spotifyRemoteService = ref.read(spotifyRemoteRepositoryProvider);
    spotifyConnect = await spotifyRemoteService.connect();
    debugPrint('_spotifyConnect: $spotifyConnect');
  }

  /// Dark AppBar on the stage look (when there are playlists).
  bool get _dark => (ref.read(hivePlaylistData) ?? const []).isNotEmpty;
  Color get _barColor => _dark ? StageColors.text : Colors.black;
  Color get _barMuted => _dark ? StageColors.textMuted : Colors.black54;

  bool _lastWasAppleMusic() {
    return ref
        .read(lastDjTrackPlayedProvider)
        .maybeWhen(
          data: (t) =>
              t != null && playsWithAppleMusic(t.appleMusicId, t.spotifyUri),
          orElse: () => false,
        );
  }

  Future<bool> pausePlayer() async {
    if (_lastWasAppleMusic()) {
      return ref.read(appleMusicRepositoryProvider).pausePlayer();
    }
    isPlaying = await ref.read(spotifyRemoteRepositoryProvider).pausePlayer();
    return isPlaying;
  }

  Future<bool> resumePlayer() async {
    if (_lastWasAppleMusic()) {
      return ref.read(appleMusicRepositoryProvider).resumePlayer();
    }
    isPlaying = await ref.read(spotifyRemoteRepositoryProvider).resumePlayer();
    return isPlaying;
  }

  void _startConnectionHealthCheck() {
    _connectionHealthCheckTimer = Timer.periodic(const Duration(minutes: 5), (
      timer,
    ) async {
      final repo = ref.read(spotifyRemoteRepositoryProvider);
      final timeSinceLastConnection = DateTime.now().difference(
        repo.lastConnectionTime,
      );

      if (timeSinceLastConnection.inMinutes > 45 &&
          repo.hasSpotifyAccessToken) {
        debugPrint(
          'Proactive connection refresh after $timeSinceLastConnection',
        );
        try {
          await repo.connectAccessToken();
          if (mounted) {
            setState(() {
              spotifyConnect = repo.hasSpotifyAccessToken;
            });
          }
        } catch (error) {
          debugPrint('Error during health check reconnection: $error');
        }
      }
    });
  }

  @override
  void initState() {
    super.initState();
    Stream<bool>? stream;
    if (Platform.isIOS || Platform.isMacOS) {
      stream = SpotifyPlatformBridge().subscribeConnectionStatus();
    } else if (Platform.isAndroid) {
      stream = SpotifySdk.subscribeConnectionStatus().map((s) => s.connected);
    }
    _connectionSubscription = stream?.listen(
      _onConnectionStatus,
      onError: (e) => debugPrint('Connection status stream error: $e'),
      cancelOnError: false,
    );
    _initializeSpotifyConnection();
    _startConnectionHealthCheck();
    final repo = ref.read(spotifyRemoteRepositoryProvider);
    repo.playIssueNotifier.addListener(_onPlayIssue);
    _playIssueRepo = repo;
    if (Platform.isIOS || Platform.isMacOS) _initializeAppleMusicConnection();
  }

  void _initializeAppleMusicConnection() {
    final repo = ref.read(appleMusicRepositoryProvider);
    _appleMusicSubscription = repo.subscribeConnectionStatus().listen(
      (connected) {
        if (mounted) setState(() => appleMusicConnected = connected);
        if (connected) _prewarmAppleMusicCache();
      },
      onError: (e) => debugPrint('Apple Music connection stream error: $e'),
      cancelOnError: false,
    );
    // Check existing authorization without prompting the user
    repo.connect();
  }

  SpotifyRemoteRepository? _playIssueRepo;

  /// Spotify accepted a play but didn't play it (see PLAY-CHECK).
  void _onPlayIssue() {
    final issue = _playIssueRepo?.playIssueNotifier.value;
    if (issue == null || !mounted) return;
    toastification.show(
      context: context,
      type: ToastificationType.error,
      style: ToastificationStyle.flat,
      title: const Text('Spotify did not start playback'),
      description: Text(issue),
      alignment: Alignment.topCenter,
      autoCloseDuration: const Duration(seconds: 8),
    );
  }

  void _onConnectionStatus(bool connected) {
    spotifyRemoteConnect = connected;
    // Spotify app started/stopped (macOS) – re-check where we'd play. A
    // freshly launched Spotify shows up in the device list a few seconds
    // later, so check again before trusting the result.
    final repo = ref.read(spotifyRemoteRepositoryProvider);
    unawaited(repo.refreshDevices());
    Future<void>.delayed(const Duration(seconds: 6), () {
      if (mounted) unawaited(repo.refreshDevices());
    });
    if (!connected) {
      SpotifyConnectionLog().addSimpleEntry(
        SpotifyConnectionStatus.notConnected,
        'Disconnected from Spotify (socket dropped)',
      );
      if (mounted) setState(() => spotifyConnect = false);
    }
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    _appleMusicSubscription?.cancel();
    _connectionHealthCheckTimer?.cancel();
    _playIssueRepo?.playIssueNotifier.removeListener(_onPlayIssue);
    super.dispose();
  }

  Future<void> _initializeSpotifyConnection() async {
    try {
      await _spotifyConnect(context, ref);
      if (mounted) {
        setState(() {
          initStateConnectDone = true;
        });
      }
    } catch (error) {
      if (mounted) {
        debugPrint('Error initializing Spotify connection: $error');
      }
    }
  }

  void _navigateTo(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  void _handlePopupAction(String value) {
    switch (value) {
      case 'letsplay':
        _navigateTo(DJLetsPlayViewPage(refreshCallback: () => setState(() {})));
      case 'newplaylist':
        _navigateTo(DJPlaylistEditScreen.empty());
      case 'settings':
        _navigateTo(TrackTimeCenterScreen());
      case 'cloudbackup':
        _navigateTo(CloudBackupScreen(refreshCallback: () => setState(() {})));
      case 'playlisthelp':
        _navigateTo(const PlaylistHelpScreen());
    }
  }

  List<Widget> _buildWideActions(
    BuildContext context,
    bool hasToken, {
    required bool hasPlaylists,
  }) {
    return [
      const CurrentVolumeWidget(),
      if (hasToken)
        IconButton(
          onPressed: () => setState(() {
            resumePlayer();
          }),
          icon: Icon(
            Icons.play_arrow,
            color: isPlaying ? Colors.grey : Colors.green,
          ),
        ),
      if (hasToken)
        ValueListenableBuilder<bool>(
          valueListenable: ref
              .read(spotifyRemoteRepositoryProvider)
              .silencePlayingNotifier,
          builder: (context, isSilence, _) => Tooltip(
            message: isSilence ? 'Silence playing' : 'Pause',
            child: IconButton(
              onPressed: () => setState(() {
                pausePlayer();
              }),
              icon: Icon(
                Icons.pause,
                color: isSilence
                    ? Colors.orange
                    : (isPlaying ? Colors.green : Colors.grey),
              ),
            ),
          ),
        ),
      Tooltip(
        message: 'Cloud Backup',
        child: IconButton(
          icon: Icon(Icons.cloud, color: _barColor),
          onPressed: () => _navigateTo(
            CloudBackupScreen(refreshCallback: () => setState(() {})),
          ),
        ),
      ),
      Tooltip(
        message: 'Utilities',
        child: IconButton(
          icon: Icon(Icons.settings, color: _barColor),
          onPressed: () => _navigateTo(TrackTimeCenterScreen()),
        ),
      ),
      Tooltip(
        message: 'Playlist help',
        child: IconButton(
          icon: Icon(Icons.help_outline, color: _barMuted),
          onPressed: () => _navigateTo(const PlaylistHelpScreen()),
        ),
      ),
      Tooltip(
        message: 'New playlist',
        child: IconButton(
          icon: Icon(Icons.add, color: _barColor),
          onPressed: () {
            _navigateTo(DJPlaylistEditScreen.empty());
          },
        ),
      ),
      if (Platform.isIOS || Platform.isMacOS)
        Tooltip(
          message: appleMusicConnected
              ? 'Apple Music connected'
              : 'Connect Apple Music',
          child: IconButton(
            icon: FaIcon(
              FontAwesomeIcons.apple,
              color: appleMusicConnected
                  ? Colors.green.shade700
                  : Colors.red.shade700,
            ),
            onPressed: _appleMusicConnect,
          ),
        ),
      if (Platform.isAndroid)
        Tooltip(
          message: hasToken ? 'Spotify connected' : 'Connect Spotify',
          child: IconButton(
            icon: FaIcon(
              FontAwesomeIcons.spotify,
              color: hasToken ? Colors.green.shade700 : Colors.red.shade700,
            ),
            onPressed: () async {
              await _spotifyConnect(context, ref);
              if (mounted) setState(() {});
            },
          ),
        )
      else
        const SpotifyStatusChip(),
      // Nothing to play yet: the welcome screen is shown instead.
      if (hasPlaylists)
        Padding(
          padding: const EdgeInsets.only(left: 4, right: 8),
          child: _LetsPlayLogoButton(
            showLabel: true,
            onOpen: () => _navigateTo(
              DJLetsPlayViewPage(refreshCallback: () => setState(() {})),
            ),
          ),
        ),
    ];
  }

  List<Widget> _buildNarrowActions(
    BuildContext context,
    bool hasToken, {
    required bool hasPlaylists,
  }) {
    return [
      const CurrentVolumeWidget(),
      if (hasToken)
        IconButton(
          onPressed: () => setState(() {
            resumePlayer();
          }),
          icon: Icon(
            Icons.play_arrow,
            size: 22,
            color: isPlaying ? Colors.grey : Colors.green,
          ),
        ),
      if (hasToken)
        ValueListenableBuilder<bool>(
          valueListenable: ref
              .read(spotifyRemoteRepositoryProvider)
              .silencePlayingNotifier,
          builder: (context, isSilence, _) => IconButton(
            onPressed: () => setState(() {
              pausePlayer();
            }),
            icon: Icon(
              Icons.pause,
              size: 22,
              color: isSilence
                  ? Colors.orange
                  : (isPlaying ? Colors.green : Colors.grey),
            ),
          ),
        ),
      if (Platform.isIOS || Platform.isMacOS)
        IconButton(
          icon: Icon(
            Icons.music_note,
            color: appleMusicConnected
                ? Colors.pink.shade600
                : Colors.grey.shade400,
          ),
          tooltip: appleMusicConnected
              ? 'Apple Music connected'
              : 'Connect Apple Music',
          onPressed: _appleMusicConnect,
        ),
      if (Platform.isAndroid)
        IconButton(
          icon: Icon(
            hasToken ? Icons.wifi : Icons.wifi_off,
            color: hasToken ? Colors.green : Colors.red,
          ),
          tooltip: hasToken ? 'Spotify Connected' : 'Connect Spotify',
          onPressed: () async {
            await _spotifyConnect(context, ref);
            if (mounted) setState(() {});
          },
        )
      else
        const SpotifyStatusChip(compact: true),
      if (hasPlaylists)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: _LetsPlayLogoButton(
            onOpen: () => _navigateTo(
              DJLetsPlayViewPage(refreshCallback: () => setState(() {})),
            ),
          ),
        ),
      PopupMenuButton<String>(
        icon: Icon(Icons.more_vert, color: _barColor),
        onSelected: _handlePopupAction,
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'letsplay',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.shade700,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.sports_handball, color: Colors.white),
                  SizedBox(width: 10),
                  Text(
                    _kMatchModeLabel,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const PopupMenuItem(
            value: 'newplaylist',
            child: Row(
              children: [
                Icon(Icons.playlist_add),
                SizedBox(width: 10),
                Text('New playlist'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'settings',
            child: Row(
              children: [
                Icon(Icons.settings),
                SizedBox(width: 10),
                Text('Settings'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'cloudbackup',
            child: Row(
              children: [
                Icon(Icons.cloud),
                SizedBox(width: 10),
                Text('Cloud Backup'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'playlisthelp',
            child: Row(
              children: [
                Icon(Icons.help_outline),
                SizedBox(width: 10),
                Text('Playlist Help'),
              ],
            ),
          ),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final allPlaylists = ref.watch(hivePlaylistData) ?? <DJPlaylist>[];
    final packageInfo = useFuture(useMemoized(PackageInfo.fromPlatform));
    isPlaying = ref.read(spotifyRemoteRepositoryProvider).isPlaying;

    final isWide = MediaQuery.of(context).size.width >= 1000;
    final hasToken = ref
        .read(spotifyRemoteRepositoryProvider)
        .hasSpotifyAccessToken;
    final version = packageInfo.data?.version;
    // Dark stage look like Let's Play – but the welcome screen (no
    // playlists yet) keeps its own light design.
    final dark = allPlaylists.isNotEmpty;
    final background = dark ? StageColors.background : Colors.white;

    return Theme(
      data: dark ? StageColors.theme(Theme.of(context)) : Theme.of(context),
      child: Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          centerTitle: true,
          backgroundColor: background,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          leading: isWide
              ? Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'v${version ?? '...'}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: _barMuted),
                    ),
                  ),
                )
              : null,
          title: isWide
              ? Text(
                  'djsports',
                  style: TextStyle(
                    color: _barColor,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'djsports',
                      style: TextStyle(
                        color: _barColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (version != null)
                      Text(
                        'v$version',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: _barMuted),
                      ),
                  ],
                ),
          actions: isWide
              ? _buildWideActions(
                  context,
                  hasToken,
                  hasPlaylists: allPlaylists.isNotEmpty,
                )
              : _buildNarrowActions(
                  context,
                  hasToken,
                  hasPlaylists: allPlaylists.isNotEmpty,
                ),
        ),
        body: allPlaylists.isEmpty
            ? const FirstTimeUseScreen()
            : ListView(
                padding: const EdgeInsets.only(bottom: 88),
                children: DJPlaylistType.values
                    .where((t) => t != DJPlaylistType.all)
                    .map((type) {
                      final typePlaylists =
                          allPlaylists
                              .where((p) => p.type == type.name)
                              .toList()
                            ..sort((a, b) => a.position.compareTo(b.position));
                      if (typePlaylists.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return _TypeSection(
                        type: type,
                        playlists: typePlaylists,
                        onEdit: (playlist) => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                DJPlaylistEditScreen.fromDJPlaylist(
                                  playlist,
                                  refreshCallback: () => setState(() {}),
                                ),
                          ),
                        ),
                        onDelete: (playlist) => ref
                            .read(hivePlaylistData.notifier)
                            .removeDJPlaylist(
                              ref.read(hiveTrackData.notifier),
                              playlist.id,
                            ),
                        onReorder: (oldIndex, newIndex) => ref
                            .read(hivePlaylistData.notifier)
                            .reorderPlaylistsOfType(
                              type.name,
                              oldIndex,
                              newIndex,
                            ),
                      );
                    })
                    .toList(),
              ),
      ),
    );
  }
}

class _TypeSection extends StatefulWidget {
  const _TypeSection({
    required this.type,
    required this.playlists,
    required this.onEdit,
    required this.onDelete,
    required this.onReorder,
  });

  final DJPlaylistType type;
  final List<DJPlaylist> playlists;
  final void Function(DJPlaylist) onEdit;
  final void Function(DJPlaylist) onDelete;
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  State<_TypeSection> createState() => _TypeSectionState();
}

class _TypeSectionState extends State<_TypeSection> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final color = stageTypeColor(widget.type.color, context);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return ExpansionTile(
      initiallyExpanded: true,
      onExpansionChanged: (v) => setState(() => _expanded = v),
      shape: const Border(),
      collapsedShape: const Border(),
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      title: Text(
        widget.type.type.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 13,
          letterSpacing: 0.5,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_expanded)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${widget.playlists.length}',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          const SizedBox(width: 4),
          Icon(_expanded ? Icons.expand_less : Icons.expand_more, color: muted),
        ],
      ),
      children: [
        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          onReorder: widget.onReorder,
          children: [
            for (int i = 0; i < widget.playlists.length; i++)
              DJPlaylistView(
                key: ValueKey(widget.playlists[i].id),
                name: widget.playlists[i].name,
                type: widget.playlists[i].type,
                spotifyUri: widget.playlists[i].spotifyUri,
                trackIds: widget.playlists[i].trackIds,
                shuffleAtEnd: widget.playlists[i].shuffleAtEnd,
                autoNext: widget.playlists[i].autoNext,
                currentTrack: widget.playlists[i].currentTrack,
                onEdit: () => widget.onEdit(widget.playlists[i]),
                onDelete: () => widget.onDelete(widget.playlists[i]),
                dragHandle: ReorderableDragStartListener(
                  index: i,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      Icons.drag_handle,
                      color: muted.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Opens Let's Play: the djSports logo flashes, then the screen opens.
/// Replaces the old floating "Let's Play!" button.
class _LetsPlayLogoButton extends StatelessWidget {
  const _LetsPlayLogoButton({required this.onOpen, this.showLabel = false});

  final VoidCallback onOpen;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final logo = FlashingLogo(
      size: 40,
      tooltip: _kMatchModeLabel,
      onTap: onOpen,
    );
    if (!showLabel) return logo;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        logo,
        const SizedBox(width: 6),
        GestureDetector(
          onTap: onOpen,
          child: Text(
            _kMatchModeLabel,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}
