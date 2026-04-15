import 'package:flutter/services.dart';

class AppleMusicTrack {
  AppleMusicTrack({
    required this.id,
    required this.name,
    required this.artist,
    required this.album,
    required this.durationMs,
    required this.artworkUrl,
  });

  final String id;
  final String name;
  final String artist;
  final String album;
  final int durationMs;
  final String artworkUrl;

  factory AppleMusicTrack.fromMap(Map<String, dynamic> map) {
    return AppleMusicTrack(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      artist: map['artist'] as String? ?? '',
      album: map['album'] as String? ?? '',
      durationMs: map['duration'] as int? ?? 0,
      artworkUrl: map['artworkUrl'] as String? ?? '',
    );
  }
}

class AppleMusicPlatformBridge {
  static const _channel = MethodChannel(
    'com.djsports/apple_music_native',
  );
  static const _eventChannel = EventChannel(
    'com.djsports/apple_music_connection_events',
  );

  /// Request Apple Music authorization. Returns true if granted.
  Future<bool> authorize() async {
    return await _channel.invokeMethod<bool>('authorize') ?? false;
  }

  /// Returns "authorized", "denied", "restricted", or "notDetermined".
  Future<String> getAuthorizationStatus() async {
    return await _channel.invokeMethod<String>('getAuthorizationStatus') ??
        'notDetermined';
  }

  /// Returns true if the user has an Apple Music subscription.
  Future<bool> isSubscribed() async {
    return await _channel.invokeMethod<bool>('isSubscribed') ?? false;
  }

  /// Play a track by Apple Music catalog ID.
  /// [positionMs] sets start position; 0 means from the beginning.
  /// Returns "playing" on success (may include "|catalog=X|queue=X|play=X|..." timing).
  Future<String> play(String trackId, {int positionMs = 0}) async {
    return await _channel.invokeMethod<String>('play', {
          'trackId': trackId,
          'positionMs': positionMs,
        }) ??
        '';
  }

  Future<bool> pause() async {
    return await _channel.invokeMethod<bool>('pause') ?? false;
  }

  Future<bool> resume() async {
    return await _channel.invokeMethod<bool>('resume') ?? false;
  }

  Future<bool> seekTo(int positionMs) async {
    return await _channel.invokeMethod<bool>('seekTo', {
          'positionMs': positionMs,
        }) ??
        false;
  }

  /// Returns "playing", "paused", or "stopped".
  Future<String> getPlaybackState() async {
    return await _channel.invokeMethod<String>('getPlaybackState') ?? 'stopped';
  }

  /// Search the Apple Music catalog. Returns up to [limit] results.
  Future<List<AppleMusicTrack>> search(String query, {int limit = 25}) async {
    final raw = await _channel.invokeMethod<List<dynamic>>('search', {
      'query': query,
      'limit': limit,
    });
    if (raw == null) return [];
    return raw
        .map((e) => AppleMusicTrack.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Fetch all tracks from a shared Apple Music playlist by its ID.
  /// Returns a record with playlistName and a list of tracks.
  Future<({String playlistName, List<AppleMusicTrack> tracks})>
      getPlaylistTracks(String playlistId) async {
    final raw = await _channel.invokeMethod<Map<Object?, Object?>>('getPlaylistTracks', {
      'playlistId': playlistId,
    });
    if (raw == null) return (playlistName: '', tracks: <AppleMusicTrack>[]);
    final name = raw['playlistName'] as String? ?? '';
    final trackList = (raw['tracks'] as List<dynamic>? ?? [])
        .map((e) => AppleMusicTrack.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    return (playlistName: name, tracks: trackList);
  }

  /// Warms up the MusicKit streaming session with a silent play+pause.
  /// Call once after prewarm so all subsequent plays run at ~600ms not ~1600ms.
  Future<bool> warmupStreamingSession(String trackId) async {
    return await _channel.invokeMethod<bool>('warmupStreamingSession', {
          'trackId': trackId,
        }) ??
        false;
  }

  /// Pre-sets the player queue for [trackId] without playing.
  /// Triggers MusicKit DRM/metadata init so the next play() is faster.
  Future<bool> presetQueue(String trackId) async {
    return await _channel.invokeMethod<bool>('presetQueue', {
          'trackId': trackId,
        }) ??
        false;
  }

  /// Pre-fetches songs into the native cache to avoid catalog latency on play.
  /// Returns the number of songs successfully cached.
  Future<int> prewarmCache(List<String> trackIds) async {
    if (trackIds.isEmpty) return 0;
    return await _channel.invokeMethod<int>('prewarmCache', {
          'trackIds': trackIds,
        }) ??
        0;
  }

  /// Stream of connection/authorization state changes.
  /// Emits `true` when authorized, `false` otherwise.
  Stream<bool> subscribeConnectionStatus() {
    return _eventChannel.receiveBroadcastStream().map((event) {
      final map = event as Map;
      return map['connected'] as bool? ?? false;
    });
  }
}
