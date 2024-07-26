import 'package:djsports/data/models/spotify_playlist_result.dart';
import 'package:djsports/data/models/spotify_search_result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spotify/spotify.dart';

class SpotifySearchRepository {
  const SpotifySearchRepository(this._client);
  final SpotifyApi _client;

  Future<SpotifySearchResult> searchTracks(String query) async {
    final pages =
        await _client.search.get(query, types: [SearchType.track]).first(50);
    List<Track> result = [];
    if (pages.isNotEmpty) {
      for (var page in pages) {
        for (var pageItem in page.items!) {
          Track spotifyTrack = pageItem;
          result.add(spotifyTrack);
        }
      }
    }
    return SpotifySearchResult(result);
  }

  Future<SpotifyPlaylistResult> getPlaylistTracks(String playlistId) async {
    debugPrint('tracksPage: $playlistId');
    try {
      var tracksPage = await _client.playlists.get(playlistId);
      Iterable result = tracksPage.tracks?.itemsNative ?? [];
      Iterable<Track> tracks = [];
      for (var item in result) {
        PlaylistTrack newPlaylistTrack = PlaylistTrack.fromJson(item);
        tracks = tracks.followedBy([newPlaylistTrack.track!]);
      }
      return SpotifyPlaylistResult(tracks);
    } catch (e) {
      debugPrint('getPlaylistTracks error: $e');
      return const SpotifyPlaylistResult([]);
    }
  }
}

final searchRepositoryProvider = Provider<SpotifySearchRepository>((ref) {
  SpotifyApiCredentials credentials = SpotifyApiCredentials(
    dotenv.env['SPOTIFY_CLIENTID'],
    dotenv.env['SPOTIFY_SECRET'],
  );

  return SpotifySearchRepository(SpotifyApi(credentials));
});
