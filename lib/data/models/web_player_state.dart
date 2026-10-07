/// What djSports' own Spotify player (macOS web player) is playing, from
/// the Web Playback SDK's `player_state_changed` events.
class WebPlayerState {
  const WebPlayerState({
    required this.paused,
    required this.positionMs,
    required this.durationMs,
    required this.receivedAt,
    this.uri = '',
    this.name = '',
    this.artists = '',
    this.album = '',
    this.imageUrl = '',
  });

  factory WebPlayerState.fromEvent(Map<String, dynamic> e) => WebPlayerState(
    paused: e['paused'] as bool? ?? true,
    positionMs: (e['positionMs'] as num?)?.toInt() ?? 0,
    durationMs: (e['durationMs'] as num?)?.toInt() ?? 0,
    receivedAt: DateTime.now(),
    uri: e['uri'] as String? ?? '',
    name: e['name'] as String? ?? '',
    artists: e['artists'] as String? ?? '',
    album: e['album'] as String? ?? '',
    imageUrl: e['imageUrl'] as String? ?? '',
  );

  final bool paused;

  /// Position when the event arrived; see [positionAt].
  final int positionMs;
  final int durationMs;
  final DateTime receivedAt;
  final String uri;
  final String name;
  final String artists;
  final String album;
  final String imageUrl;

  /// The SDK only reports on changes, so the position moves on locally
  /// while playing.
  int positionAt(DateTime now) {
    if (paused) return positionMs;
    final moved = positionMs + now.difference(receivedAt).inMilliseconds;
    return durationMs > 0 ? moved.clamp(0, durationMs) : moved;
  }
}
