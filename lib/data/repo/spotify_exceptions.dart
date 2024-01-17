class SpotifySearchException implements Exception {
  final String message;

  const SpotifySearchException(this.message);
}

class SpotifyTrackException implements Exception {
  final String message;

  const SpotifyTrackException(this.message);
}

class PlaylistsFailedException implements Exception {
  final String message;

  const PlaylistsFailedException(this.message);
}
