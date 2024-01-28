import 'package:djsports/data/models/spotify_search_result.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spotify/spotify.dart' as spotify;

class SpotifySearchRepository {
  const SpotifySearchRepository(this._client);
  final spotify.SpotifyApi _client;

  Future<SpotifySearchResult> searchTracks(String query) async {
    final pages = await _client.search
        .get(query, types: [spotify.SearchType.track]).first(50);
    List<spotify.Track> result = [];
    if (pages.isNotEmpty) {
      for (var page in pages) {
        for (var pageItem in page.items!) {
          spotify.Track spotifyTrack = pageItem;
          result.add(spotifyTrack);
        }
      }
    }
    return SpotifySearchResult(result);
  }
}

final searchRepositoryProvider = Provider<SpotifySearchRepository>((ref) {
  spotify.SpotifyApiCredentials credentials = spotify.SpotifyApiCredentials(
    dotenv.env['SPOTIFY_CLIENTID'],
    dotenv.env['SPOTIFY_SECRET'],
  );

  return SpotifySearchRepository(spotify.SpotifyApi(credentials));
});
