import 'package:djsports/data/models/apple_music_log.dart';
import 'package:djsports/data/models/djplaylist_model.dart';
import 'package:djsports/data/models/djtrack_model.dart';
import 'package:djsports/data/services/apple_music_platform_bridge.dart';
import 'package:flutter/services.dart';

class AppleMusicRepository {
  AppleMusicRepository() : _bridge = AppleMusicPlatformBridge();

  final AppleMusicPlatformBridge _bridge;

  bool isAuthorized = false;
  bool isSubscribed = false;
  bool isPlaying = false;
  String lastError = '';

  // ── Authorization ────────────────────────────────────────────────────────

  /// Request Apple Music authorization.
  /// Returns true when both authorized AND subscribed.
  Future<bool> connect() async {
    try {
      final status = await _bridge.getAuthorizationStatus();
      AppleMusicLog().info('getAuthorizationStatus: $status');
      if (status == 'authorized') {
        isAuthorized = true;
      } else {
        isAuthorized = await _bridge.authorize();
        AppleMusicLog().info('authorize: $isAuthorized');
      }
      if (isAuthorized) {
        isSubscribed = await _bridge.isSubscribed();
        AppleMusicLog().info('isSubscribed: $isSubscribed');
      }
      return isAuthorized && isSubscribed;
    } on PlatformException catch (e) {
      lastError = e.message ?? 'Authorization failed';
      AppleMusicLog().error('connect error: $lastError');
      return false;
    }
  }

  /// Stream of authorization state changes (true = connected/authorized).
  Stream<bool> subscribeConnectionStatus() {
    return _bridge.subscribeConnectionStatus();
  }

  // ── Playback ─────────────────────────────────────────────────────────────

  /// Main playback entry point, mirrors SpotifyRemoteRepository signature.
  /// [jumpStart] is in milliseconds (startTime * 1000 + startTimeMS).
  Future<String> playTrackAndJumpStart(
    DJTrack track,
    int jumpStart,
    DJPlaylistType playlistType,
    String playlistName, {
    bool retry = true,
  }) async {
    final trackId = track.appleMusicId;
    if (trackId.isEmpty) {
      return '[Error] Track has no Apple Music ID';
    }
    return playAppleMusicIdAndJumpStart(trackId, jumpStart, retry: retry);
  }

  Future<String> playAppleMusicIdAndJumpStart(
    String appleMusicId,
    int jumpStart, {
    bool retry = true,
  }) async {
    final t0 = DateTime.now();
    AppleMusicLog().info(
      'play START id=$appleMusicId positionMs=$jumpStart',
    );
    try {
      final response = await _bridge.play(
        appleMusicId,
        positionMs: jumpStart,
      );
      final elapsedMs = DateTime.now().difference(t0).inMilliseconds;
      if (response.startsWith('playing')) {
        isPlaying = true;
        lastError = '';
        // Parse per-step timing from Swift if present: "playing|catalog=X|..."
        final timing = response.contains('|')
            ? response.substring(response.indexOf('|') + 1)
            : 'total=${elapsedMs}ms';
        AppleMusicLog().info('play OK dart=${elapsedMs}ms $timing');
        return 'playing';
      }
      AppleMusicLog().error(
        'play unexpected response: $response elapsed=${elapsedMs}ms',
      );
      return '[Error] $response';
    } on PlatformException catch (e) {
      final elapsedMs = DateTime.now().difference(t0).inMilliseconds;
      final msg = e.message ?? 'Playback error';
      final details = e.details?.toString() ?? '';
      lastError = msg;
      isPlaying = false;
      AppleMusicLog().error(
        'play error: $msg${details.isNotEmpty ? " | $details" : ""} elapsed=${elapsedMs}ms',
      );
      return '[Error] $msg';
    }
  }

  Future<bool> pausePlayer() async {
    try {
      final ok = await _bridge.pause();
      if (ok) isPlaying = false;
      return ok;
    } on PlatformException catch (e) {
      lastError = e.message ?? 'Pause error';
      return false;
    }
  }

  Future<bool> resumePlayer() async {
    try {
      final ok = await _bridge.resume();
      if (ok) isPlaying = true;
      return ok;
    } on PlatformException catch (e) {
      lastError = e.message ?? 'Resume error';
      return false;
    }
  }

  Future<bool> seekTo(int positionMs) async {
    try {
      return await _bridge.seekTo(positionMs);
    } on PlatformException catch (e) {
      lastError = e.message ?? 'Seek error';
      return false;
    }
  }

  // ── Cache prewarm ────────────────────────────────────────────────────────

  /// Fetches all [trackIds] into the native song cache so subsequent play()
  /// calls skip the catalog network round-trip.
  Future<void> prewarmCache(List<String> trackIds) async {
    final ids = trackIds.where((id) => id.isNotEmpty).toList();
    if (ids.isEmpty) return;
    AppleMusicLog().info('prewarmCache: requesting ${ids.length} tracks');
    try {
      final cached = await _bridge.prewarmCache(ids);
      AppleMusicLog().info('prewarmCache: $cached/${ids.length} cached');
    } on PlatformException catch (e) {
      AppleMusicLog().error('prewarmCache error: ${e.message}');
    }
  }

  /// Warms up the MusicKit streaming session with a silent play+pause.
  /// Call once after prewarm — reduces first-play latency from ~1600ms to ~600ms.
  Future<void> warmupStreamingSession(String trackId) async {
    if (trackId.isEmpty) return;
    AppleMusicLog().info('warmup: starting for $trackId');
    try {
      final ok = await _bridge.warmupStreamingSession(trackId);
      AppleMusicLog().info('warmup: ${ok ? "done" : "failed"}');
    } on PlatformException catch (e) {
      AppleMusicLog().error('warmup error: ${e.message}');
    }
  }

  /// Pre-sets the player queue for [trackId] without playing.
  /// Call this when a track is likely to be played next to reduce startup latency.
  Future<void> presetQueue(String trackId) async {
    if (trackId.isEmpty) return;
    AppleMusicLog().info('presetQueue: $trackId');
    try {
      final ok = await _bridge.presetQueue(trackId);
      AppleMusicLog().info('presetQueue: ${ok ? "ready" : "failed"}');
    } on PlatformException catch (e) {
      AppleMusicLog().error('presetQueue error: ${e.message}');
    }
  }

  // ── Playlist sync ─────────────────────────────────────────────────────────

  /// Fetch all tracks from a shared Apple Music playlist.
  /// Returns playlist name + list of tracks.
  Future<({String playlistName, List<AppleMusicTrack> tracks})> syncPlaylist(
    String playlistId,
  ) async {
    try {
      return await _bridge.getPlaylistTracks(playlistId);
    } on PlatformException catch (e) {
      lastError = e.message ?? 'Playlist fetch error';
      return (playlistName: '', tracks: <AppleMusicTrack>[]);
    }
  }

  // ── Search ────────────────────────────────────────────────────────────────

  Future<List<AppleMusicTrack>> search(String query) async {
    if (query.length < 3) return [];
    try {
      return await _bridge.search(query);
    } on PlatformException catch (e) {
      lastError = e.message ?? 'Search error';
      return [];
    }
  }
}
