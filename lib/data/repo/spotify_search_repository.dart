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

  Future<String> getSpotifyNameUri(String queryUri) async {
    debugPrint('tracksPage: $queryUri');

    // does queryUri start with playlist or album
    if (queryUri.startsWith('album/')) {
      try {
        queryUri = queryUri.replaceAll('album/', '');
        final album = await _client.albums.get(queryUri);
        Album newAlbum = Album.fromJson(album.toJson());
        return newAlbum.name ?? '';
      } catch (e) {
        debugPrint('getSpotifyNameUri error: $e');
        return '';
      }
    } else {
      try {
        // remove playlist/ from queryUri
        queryUri = queryUri.replaceAll('playlist/', '');
        var tracksPage = await _client.playlists.get(queryUri);
        return tracksPage.name ?? '';
      } catch (e) {
        debugPrint('getPlaylistTracks error: $e');
        return '';
      }
    }
  }

  Future<SpotifyPlaylistResult> getTracksByUri(String queryUri) async {
    debugPrint('tracksPage: $queryUri');

    // does queryUri start with playlist or album
    if (queryUri.startsWith('album/')) {
      try {
        queryUri = queryUri.replaceAll('album/', '');
        final album = await _client.albums.get(queryUri);
        Album newAlbum = Album.fromJson(album.toJson());

        final albumTracks = await _client.albums.get(queryUri);

        Iterable<Track> tracks = [];
        for (var item in albumTracks.tracks!) {
          AlbumSimple newAlbumTrack = AlbumSimple.fromJson(item.toJson());
          // convert AlbumSimple to Track
          Track newTrack = Track.fromJson(newAlbumTrack.toJson());
          newTrack.durationMs ??= 0;
          if (newTrack.durationMs == 0) {
            newTrack.durationMs = 600000;
          }
          newTrack.album = newAlbum;
          tracks = tracks.followedBy([newTrack]);
        }
        return SpotifyPlaylistResult(tracks);
      } catch (e) {
        debugPrint('getPlaylistTracks error: $e');
        return const SpotifyPlaylistResult([]);
      }
    } else {
      try {
        // remove playlist/ from queryUri
        queryUri = queryUri.replaceAll('playlist/', '');

        var tracksPage = await _client.playlists.get(queryUri);

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
}

final searchRepositoryProvider = Provider<SpotifySearchRepository>((ref) {
  SpotifyApiCredentials credentials = SpotifyApiCredentials(
    dotenv.env['SPOTIFY_CLIENTID'],
    dotenv.env['SPOTIFY_SECRET'],
  );

  return SpotifySearchRepository(SpotifyApi(credentials));
});
