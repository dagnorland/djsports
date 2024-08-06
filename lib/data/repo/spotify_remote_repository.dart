import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:spotify/spotify.dart';
import 'package:spotify_sdk/spotify_sdk.dart';

class SpotifyRemoteRepository {
  SpotifyRemoteRepository(this._credentials, this._spotifyRedirectUrl);
  final SpotifyApiCredentials _credentials;
  final String _spotifyRedirectUrl;

  String lastValidAccessToken = '';
  Object lastAccessTokenError = Object();
  bool isConnected = false;

  Future<bool> connect() async {
    if (isConnected) {
      return isConnected;
    }

    try {
      final accessToken = await getSpotifyAccessToken();
      isConnected = accessToken.isNotEmpty;
      lastValidAccessToken = accessToken;
      _credentials.accessToken = accessToken;
    } catch (e) {
      isConnected = false;
      lastAccessTokenError = e;
    }
    debugPrint('connect isConnected: $isConnected');
    return isConnected;
  }

  Future<String> getSpotifyAccessToken() async {
    if (isConnected && lastValidAccessToken.isNotEmpty) {
      return lastValidAccessToken;
    }

    try {
      _credentials.scopes = [
        'app-remote-control',
        'streaming',
        'user-modify-playback-state',
        'playlist-read-private',
        'playlist-modify-public',
        'user-read-currently-playing'
      ];
      var accessToken = await SpotifySdk.getAccessToken(
          clientId: _credentials.clientId ?? '',
          redirectUrl: _spotifyRedirectUrl,
          asRadio: false,
          scope: 'app-remote-control, '
              'streaming, '
              'user-modify-playback-state, '
              'playlist-read-private, '
              'playlist-modify-public, '
              'user-read-currently-playing');

      debugPrint("getSpotifyAccessToken accessToken: $accessToken");
      return accessToken;
    } catch (e) {
      debugPrint("getSpotifyAccessToken error: ${e.toString()}");
      rethrow;
    }
  }

  Future<bool> connectToSpotifyRemote() async {
    try {
      var result = await SpotifySdk.connectToSpotifyRemote(
          clientId: _credentials.clientId.toString(),
          redirectUrl: _spotifyRedirectUrl,
          scope: 'app-remote-control, '
              'streaming, '
              'user-modify-playback-state, '
              'playlist-read-private, '
              'playlist-modify-public, '
              'user-read-currently-playing',
          accessToken: lastValidAccessToken);
      return result;
    } on PlatformException catch (e) {
      debugPrint('Failed to connect to Spotify Remote. ${e.details}');
      return false;
    } on MissingPluginException {
      debugPrint('Failed to connect to Spotify Remote. MissingPluginException');
      return false;
    } catch (e) {
      debugPrint('Failed to connect to Spotify Remote. $e');
      return false;
    }
  }

  Future<String> playTrack(String spotifyUri) async {
    if (!isConnected || !lastValidAccessToken.isNotEmpty) {
      return '[Error] Not connected to Spotify';
    }

    try {
      await SpotifySdk.play(spotifyUri: spotifyUri);
      return '[Success] Playing track $spotifyUri';
    } on PlatformException catch (platformException) {
      debugPrint('Failed to play. $platformException.details');
      //handleSpotifyPlatformException('play', platformException);
      return '[Error] Failed to play. ${platformException.details}';
    } catch (e) {
      return '[Error] Failed to play. $e';
    }
  }
}

final spotifyRemoteRepositoryProvider =
    Provider<SpotifyRemoteRepository>((ref) {
  SpotifyApiCredentials credentials = SpotifyApiCredentials(
    dotenv.env['SPOTIFY_CLIENTID'],
    dotenv.env['SPOTIFY_SECRET'],
  );
  credentials.scopes = [];

  String redirectUrl =
      dotenv.env['SPOTIFY_REDIRECT_URL'] ?? 'djsports://callback';

  return SpotifyRemoteRepository(credentials, redirectUrl);
});
