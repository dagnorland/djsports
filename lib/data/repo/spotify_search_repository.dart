import 'package:djsports/data/models/spotify_connection_log.dart';
import 'package:djsports/data/models/spotify_playlist_result.dart';
import 'package:djsports/data/models/spotify_search_result.dart';
import 'package:djsports/data/repo/spotify_remote_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spotify/spotify.dart';

class SpotifySearchRepository {
  const SpotifySearchRepository(this._client, this._ref);
  final SpotifyApi _client;
  final Ref _ref;

  Future<void> _spotifyConnect() async {
    final spotifyRemoteService = _ref.read(spotifyRemoteRepositoryProvider);
    await spotifyRemoteService.connect();
    SpotifyConnectionLog().debugPrintLog();
  }

  Future<SpotifySearchResult> searchTracks(String query) async {
    final pages =
        await _client.search.get(query, types: [SearchType.track]).first(50);
    List<Track> result = [];
    if (pages.isNotEmpty) {
      for (var page in pages) {
        for (var pageItem in page.items!) {
          Track spotifyTrack =
              Track.fromJson(pageItem.toJson() as Map<String, dynamic>);
          result.add(spotifyTrack);
        }
      }
    }
    return SpotifySearchResult(result);
  }

  Future<String> getSpotifyNameUri(String queryUri) async {
    // does queryUri start with playlist or album
    if (queryUri.startsWith('album/')) {
      try {
        queryUri = queryUri.replaceAll('album/', '');
        final album = await _client.albums.get(queryUri);
        Album newAlbum = Album.fromJson(album.toJson());
        return newAlbum.name ?? '';
      } catch (e) {
        debugPrint('getSpotifyNameUri error: $e');
        if (e.toString().contains('OAuth2')) {
          await _spotifyConnect();
        }
        return '';
      }
    } else {
      try {
        // remove playlist/ from queryUri
        queryUri =
            queryUri.replaceAll('playlist/', '').replaceAll('playlist:', '');
        var tracksPage = await _client.playlists.get(queryUri);
        return tracksPage.name ?? '';
      } catch (e) {
        debugPrint(
            'getSpotifyNameUri trying to connect to spotify remote: $e message:${e.toString()}');
        if (e.toString().contains('OAuth2')) {
          await _spotifyConnect();
        }
        debugPrint('getSpotifyNameUri error: $e');
        return '';
      }
    }
  }

  Future<SpotifyPlaylistResult> getTracksByUri(String queryUri) async {
    debugPrint('tracksPage: $queryUri');

    // does queryUri start with playlist or album
    if (queryUri.startsWith('album')) {
      try {
        queryUri = queryUri.replaceAll('album/', '').replaceAll('album:', '');
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
        debugPrint('getTracksByUri trying to connect to spotify remote: $e');
        if (e.toString().contains('OAuth2')) {
          await _spotifyConnect();
        }
        debugPrint('getTracksByUri error: $e');

        return const SpotifyPlaylistResult([]);
      }
    } else {
      try {
        // remove playlist/ from queryUri
        queryUri =
            queryUri.replaceAll('playlist/', '').replaceAll('playlist:', '');

        var tracksPage = await _client.playlists.get(queryUri);

        Iterable<dynamic> result =
            tracksPage.tracks?.itemsNative ?? <PlaylistTrack>[];
        Iterable<Track> tracks = [];
        for (var item in result) {
          if (item is Map<String, dynamic>) {
            PlaylistTrack newPlaylistTrack = PlaylistTrack.fromJson(item);
            if (newPlaylistTrack.track != null) {
              tracks = tracks.followedBy([newPlaylistTrack.track!]);
            }
          }
        }
        return SpotifyPlaylistResult(tracks);
      } catch (e) {
        debugPrint('getTracksByUri error: $e');
        if (e.toString().contains('OAuth2')) {
          await _spotifyConnect();
        }

        return const SpotifyPlaylistResult([]);
      }
    }
  }
}

final searchRepositoryProvider = Provider<SpotifySearchRepository>((ref) {
  final credentials = SpotifyApiCredentials(
    dotenv.env['SPOTIFY_CLIENTID'],
    dotenv.env['SPOTIFY_SECRET'],
  );

  return SpotifySearchRepository(
    SpotifyApi(credentials),
    ref,
  );
});
