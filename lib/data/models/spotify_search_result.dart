import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:spotify/spotify.dart';

part 'spotify_search_result.freezed.dart';

enum SpotifyAPIError { rateLimitExceeded, parseError, unknownError }

extension SpotifyAPIErrorMessage on SpotifyAPIError {
  String get message {
    switch (this) {
      case SpotifyAPIError.rateLimitExceeded:
        return 'Rate limit exceeded';
      case SpotifyAPIError.parseError:
        return 'Error reading data from the API';
      case SpotifyAPIError.unknownError:
      default:
        return 'Unknown error';
    }
  }
}

@freezed
class SpotifySearchResult with _$SpotifySearchResult {
  const factory SpotifySearchResult(List<Track> tracks) = Data;
  const factory SpotifySearchResult.error(SpotifyAPIError error) = Error;
}
