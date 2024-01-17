import 'package:djsports/data/models/spotify_search_result.dart';
import 'package:flutter/material.dart';
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
        if (page is spotify.Page) {
          for (var pageItem in page.items!) {
            spotify.Track spotifyTrack = pageItem;
            debugPrint('Track: ${spotifyTrack.name}');
            result.add(spotifyTrack);
          }
        }
      }
    }
    return SpotifySearchResult(result);
  }
}

final searchRepositoryProvider = Provider<SpotifySearchRepository>((ref) {
  spotify.SpotifyApiCredentials credentials = spotify.SpotifyApiCredentials(
    'df6ecd8a2142469bb2a4e3339585f356',
    '39604512c9bc4c3eaae21edfb424692b',
  );

  return SpotifySearchRepository(spotify.SpotifyApi(credentials));
});
