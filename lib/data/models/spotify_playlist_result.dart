import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:spotify/spotify.dart';

part 'spotify_playlist_result.freezed.dart';

enum SpotifyAPIError { rateLimitExceeded, parseError, unknownError }

extension SpotifyAPIErrorMessage on SpotifyAPIError {
  String get message {
    switch (this) {
      case SpotifyAPIError.rateLimitExceeded:
        return 'Rate limit exceeded';
      case SpotifyAPIError.parseError:
        return 'Error reading data from the API';
      case SpotifyAPIError.unknownError:
        return 'Unknown error';
    }
  }
}

@freezed
class SpotifyPlaylistResult with _$SpotifyPlaylistResult {
  const factory SpotifyPlaylistResult(Iterable<Track> tracks) = Data;
  const factory SpotifyPlaylistResult.error(SpotifyAPIError error) = Error;
}
