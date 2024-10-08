import 'package:djsports/data/models/djtrack_model.dart';
import 'package:djsports/data/models/spotify_connection_log.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:spotify/spotify.dart';
import 'package:spotify_sdk/spotify_sdk.dart';
import 'package:volume_controller/volume_controller.dart';

class SpotifyRemoteRepository {
  SpotifyRemoteRepository(this._credentials, this._spotifyRedirectUrl);
  final SpotifyApiCredentials _credentials;
  final String _spotifyRedirectUrl;

  String lastValidAccessToken = '';
  Object lastAccessTokenError = Object();
  bool isConnectedRemote = false;
  bool isConnected = false;
  bool isPlaying = false;
  static const numberOfRetries = 8;
  double volume = 0.5;
  String latestType = '';
  DJTrack latestTrack = DJTrack.empty();
  String latestImageUri = '';

  DateTime lastConnectionTime = DateTime(1970, 1, 1);

  String volumeAsPercent() {
    return (volume * 100).toStringAsFixed(0);
  }

  Future<double> getVolume() async {
    return await VolumeController().getVolume();
  }

  void setVolume(double volume) async {
    VolumeController().setVolume(volume);
  }

  void adjustVolume(double adjustment) async {
    final currentVolume = await VolumeController().getVolume();
    if (currentVolume + adjustment > 1) {
      adjustment = 1;
    } else if (currentVolume + adjustment < 0) {
      adjustment = 0;
    } else {
      adjustment = currentVolume + adjustment;
    }
    VolumeController().setVolume(adjustment);
    volume = double.parse(adjustment.toStringAsFixed(1));
  }

  Future<bool> connect() async {
    await connectAccessToken();
    await connectToSpotifyRemote();
    SpotifyConnectionLog().debugPrintLog();

    return isConnected && isConnectedRemote;
  }

  Future<bool> pausePlayer() async {
    {
      await SpotifySdk.pause();
      SpotifyConnectionLog().addSimpleEntry(
          SpotifyConnectionStatus.connectedSpotifyRemoteApp,
          'Pause Spotify Remote App');
      isPlaying = false;
      return isPlaying;
    }
  }

  Future<bool> resumePlayer() async {
    {
      await SpotifySdk.resume();
      SpotifyConnectionLog().addSimpleEntry(
          SpotifyConnectionStatus.connectedSpotifyRemoteApp,
          'Resumed Spotify Remote App');
      isPlaying = true;
      return isPlaying;
    }
  }

  Future<String> playTrackAndJumpStart(String spotifyUri, int jumpStart) async {
    if (!isConnected || !lastValidAccessToken.isNotEmpty) {
      return '[Error] Not connected to Spotify';
    }

    try {
      // turn volume down
      double volume = await VolumeController().getVolume();
      if (volume == 0) {
        volume = 0.5;
      }
      VolumeController().setVolume(0);
      await Future.delayed(const Duration(milliseconds: 50));

      await SpotifySdk.play(spotifyUri: spotifyUri);
      if (jumpStart > 0) {
        try {
          int retryCount = 0;
          bool success = false;

          while (retryCount < numberOfRetries && !success) {
            try {
              await SpotifySdk.seekTo(positionedMilliseconds: jumpStart);
              success = true;
              debugPrint('SUCCESS after $retryCount retries');
            } catch (e) {
              retryCount++;
              debugPrint('Retry jump start $retryCount');
              if (retryCount >= numberOfRetries) {
                debugPrint(
                    'Failed to jump start after $numberOfRetries attempts. $e');
              }
            }
          }
        } catch (e) {
          debugPrint('Failed to jump start. $e');
        }
      }

      VolumeController().setVolume(volume);

      SpotifyConnectionLog().addSimpleEntry(
          SpotifyConnectionStatus.connectedSpotifyRemoteApp,
          'play track $spotifyUri');
      return '[Success] Playing track $spotifyUri';
    } on PlatformException catch (platformException) {
      if (platformException.details != null) {
        if (platformException.details
            .contains('SpotifyDisconnectedException')) {
          isConnected = false;
          SpotifyConnectionLog().addSimpleEntry(
              SpotifyConnectionStatus.notConnected,
              'Error, SpotifyRemote platformexception, not connected. ${platformException.details}');
          // lets reconnect
          connectAccessToken();
          if (isConnected) {
            connectToSpotifyRemote();
            if (isConnectedRemote) {
              SpotifyConnectionLog().addSimpleEntry(
                  SpotifyConnectionStatus.connectedSpotifyRemoteApp,
                  'Reconnected. trying replay. spotifyUri');
              playTrack(spotifyUri);
            }
          }
        }
      }
      return '[Error] Failed to play. ${platformException.details}';
    } catch (e) {
      return '[Error] Failed to play. $e';
    }
  }

  Future<String> playTrack(String spotifyUri) async {
    if (!isConnected || !lastValidAccessToken.isNotEmpty) {
      return '[Error] Not connected to Spotify';
    }

    try {
      await SpotifySdk.play(spotifyUri: spotifyUri);
      SpotifyConnectionLog().addSimpleEntry(
          SpotifyConnectionStatus.connectedSpotifyRemoteApp,
          'play track $spotifyUri');
      return '[Success] Playing track $spotifyUri';
    } on PlatformException catch (platformException) {
      if (platformException.details != null) {
        if (platformException.details
            .contains('SpotifyDisconnectedException')) {
          isConnected = false;
          SpotifyConnectionLog().addSimpleEntry(
              SpotifyConnectionStatus.notConnected,
              'Error, SpotifyRemote platformexception, not connected. ${platformException.details}');
          // lets reconnect
          connectAccessToken();
          if (isConnected) {
            connectToSpotifyRemote();
            if (isConnectedRemote) {
              SpotifyConnectionLog().addSimpleEntry(
                  SpotifyConnectionStatus.connectedSpotifyRemoteApp,
                  'Reconnected. trying replay. spotifyUri');
              playTrack(spotifyUri);
            }
          }
        }
      }
      /*
        I/flutter (14291): Failed to play. details: com.spotify.android.appremote.api.error.SpotifyDisconnectedException
        I/flutter (14291): Failed to play. code: playError
        I/flutter (14291): Failed to play. message: error when playing uri: spotify:track:0cqRj7pUJDkTCEsJkx8snD
        I/flutter (14291): Failed to play. platformException.code:  playError      
      */
      debugPrint('Failed to play. details: ${platformException.details}');
      debugPrint('Failed to play. code: ${platformException.code}');
      debugPrint('Failed to play. message: ${platformException.message}');
      //handleSpotifyPlatformException('play', platformException);
      //Failed to play. PlatformException(playError, error when playing uri: spotify:track:6Q3K9gVUZRMZqZKrXovbM2, com.spotify.android.appremote.api.error.SpotifyDisconnectedException, null).details

      return '[Error] Failed to play. ${platformException.details}';
    } catch (e) {
      return '[Error] Failed to play. $e';
    }
  }

  Future<bool> connectAccessToken() async {
    try {
      final accessToken = await getSpotifyAccessToken();
      _credentials.accessToken = accessToken;
      lastValidAccessToken = accessToken;
      isConnected = accessToken.isNotEmpty;
      lastConnectionTime = DateTime.now();

      SpotifyConnectionLog().addSimpleEntry(
          SpotifyConnectionStatus.connectedSpotify, 'Connect to Spotify');
    } catch (e) {
      // add spotify connection log
      SpotifyConnectionLog().addSimpleEntry(
          SpotifyConnectionStatus.notConnected,
          'Failed to connect to Spotify ${e.toString()}');

      isConnected = false;
      lastAccessTokenError = e;
    }
    debugPrint('connect isConnected: $isConnected');
    return isConnected;
  }

  Future<String> getSpotifyAccessToken() async {
    // how long since last connection
    Duration timeSinceLastConnection =
        DateTime.now().difference(lastConnectionTime);
    debugPrint('Time since last connection: $timeSinceLastConnection');

    // if more than 5 five minutes since last connection, lets reconnect
    if (lastConnectionTime
            .isAfter(DateTime.now().subtract(const Duration(minutes: 5))) &&
        lastValidAccessToken.isNotEmpty) {
      debugPrint(
          'getSpotifyAccessToken ALREADY CONNECTED lastConnectionTime: $lastConnectionTime');
      return lastValidAccessToken;
    }

    debugPrint(
        'getSpotifyAccessToken RECONNECT lastConnectionTime: $lastConnectionTime');

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
      SpotifyConnectionLog().addSimpleEntry(
          SpotifyConnectionStatus.connectedSpotifyRemoteApp,
          'Connected to Spotify Remote App');

      isConnectedRemote = result;
      return result;
    } on PlatformException catch (e) {
      SpotifyConnectionLog().addSimpleEntry(
          SpotifyConnectionStatus.notConnected,
          'Error, SpotifyRemote platformexception, not connected. ${e.details}');
      debugPrint('Failed to connect to Spotify Remote. ${e.details}');
      return false;
    } on MissingPluginException {
      SpotifyConnectionLog().addSimpleEntry(
          SpotifyConnectionStatus.notConnected,
          'Error, SpotifyRemote missing plugin, not connected. ');
      debugPrint('Failed to connect to Spotify Remote. MissingPluginException');
      return false;
    } catch (e) {
      SpotifyConnectionLog().addSimpleEntry(
          SpotifyConnectionStatus.notConnected,
          'Error, SpotifyRemote exception, not connected. ${{e.toString()}}');
      debugPrint('Failed to connect to Spotify Remote. $e');
      return false;
    }
  }

  void setLastPlayedTrack(
      String playlistName, String playlistTypeName, DJTrack track) {
    latestType = playlistTypeName;
    latestTrack = track;
    latestImageUri = track.networkImageUri;
  }

  String getLastPlayedInfo() {
    if (latestType.isEmpty && latestTrack.name.isEmpty) {
      return 'Let the game begin!';
    }
    return '$latestType - ${latestTrack.name}';
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
