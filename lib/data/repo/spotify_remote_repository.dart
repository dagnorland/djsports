import 'dart:async';
import 'dart:io';

import 'package:djsports/data/models/djplaylist_model.dart';
import 'package:djsports/data/models/djtrack_model.dart';
import 'package:djsports/data/models/spotify_connection_log.dart';
import 'package:djsports/data/services/spotify_platform_bridge.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:spotify/spotify.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';

class SpotifyRemoteRepository {
  SpotifyRemoteRepository(this._credentials, this._spotifyRedirectUrl);
  final SpotifyApiCredentials _credentials;
  final String _spotifyRedirectUrl;
  final SpotifyPlatformBridge _bridge = SpotifyPlatformBridge();

  String lastValidAccessToken = '';
  Object lastAccessTokenError = Object();
  String lastConnectError = '';
  bool isConnectedRemote = false;
  bool hasSpotifyAccessToken = false;
  String spotifyUserDisplayName = '';
  String spotifyUserEmail = '';
  bool isSpotifyPluginInstalled = false;
  bool isPlaying = false;
  bool _isConnecting = false;
  static const numberOfRetries = 8;
  double volume = 0.5;
  final ValueNotifier<double> volumeNotifier = ValueNotifier(0.5);
  int latestDurationStartupMS = 0;
  DateTime lastConnectionTime = DateTime(1970, 1, 1);

  String spotifyLogoFileName =
      'assets/images/spotify/Spotify_Primary_Logo_RGB_Green.png';

  Future<double> _getSystemVolume() async {
    if (Platform.isMacOS) return volume;
    return await FlutterVolumeController.getVolume() ?? volume;
  }

  void _setSystemVolume(double v) {
    if (Platform.isMacOS) return;
    FlutterVolumeController.setVolume(v);
  }

  String volumeAsPercent() {
    return (volume * 100).toStringAsFixed(0);
  }

  Future<double> getVolume() async {
    return await _getSystemVolume();
  }

  double getVolumeStatic() {
    return volume;
  }

  // Called from the system volume listener — do NOT call _setSystemVolume here.
  // Writing the volume back to the system from within the listener creates a
  // feedback loop that fires the listener again, hammering the CPU.
  void setVolume(double v) {
    volume = v;
    volumeNotifier.value = v;
  }

  Future<void> adjustVolume(double adjustment) async {
    final currentVolume = await _getSystemVolume();
    double newVolume;
    if (currentVolume + adjustment > 1) {
      newVolume = 1;
    } else if (currentVolume + adjustment < 0) {
      newVolume = 0;
    } else {
      newVolume = double.parse((currentVolume + adjustment).toStringAsFixed(2));
    }
    volume = newVolume;
    volumeNotifier.value = newVolume;
    if (Platform.isMacOS) {
      await _bridge.setVolume((newVolume * 100).round());
    } else {
      _setSystemVolume(newVolume);
    }
  }

  Future<void> launchSpotify() => _bridge.launchSpotify();

  Future<bool> connect() async {
    if (_isConnecting) {
      debugPrint(
        'SpotifyRemoteRepository: connect already in progress, skipping',
      );
      return hasSpotifyAccessToken && isConnectedRemote;
    }
    _isConnecting = true;
    try {
      await connectAccessToken();
      await connectToSpotifyRemote();
      debugPrint(
        'SpotifyRemoteRepository: RUNNING connect ${DateTime.now()} isConnected: $hasSpotifyAccessToken  isConnectedRemote: $isConnectedRemote',
      );
      return hasSpotifyAccessToken && isConnectedRemote;
    } finally {
      _isConnecting = false;
    }
  }

  /// Full reconnect intended for user-triggered recovery (e.g. error dialog).
  ///
  /// Strategy (two-step, avoids unnecessary auth dialogs):
  ///
  /// Step 1 – *soft reconnect*: reset only the Dart-side token cache and call
  /// [connect].  If the native [SPTSession] is still valid the iOS SDK returns
  /// the cached token silently and [SPTAppRemote.connect()] re-establishes the
  /// socket.  No Spotify auth dialog is shown.
  ///
  /// Step 2 – *hard reconnect*: only when step 1 fails (e.g. Spotify app is
  /// not running or the native session has truly expired) do we call
  /// [clearSession] to force [SPTSessionManager.initiateSession()], which
  /// opens the Spotify app and shows the auth dialog if needed.
  Future<bool> forceFullReconnect() async {
    // Wait for any in-flight connect to finish (max 5 s, 100 ms steps).
    if (_isConnecting) {
      debugPrint('forceFullReconnect: waiting for in-progress connect…');
      for (var i = 0; i < 50; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (!_isConnecting) break;
      }
      // If the concurrent connect succeeded, reuse its result.
      if (hasSpotifyAccessToken && isConnectedRemote) {
        debugPrint('forceFullReconnect: concurrent connect succeeded, reusing');
        return true;
      }
    }

    // Step 1: soft reconnect — reset Dart caches only, keep native session.
    debugPrint(
      'forceFullReconnect: step 1 – soft reconnect (native session kept)',
    );
    lastConnectionTime = DateTime(1970);
    lastValidAccessToken = '';
    hasSpotifyAccessToken = false;
    isConnectedRemote = false;
    if (await connect()) {
      debugPrint('forceFullReconnect: soft reconnect succeeded');
      return true;
    }

    // Step 2: hard reconnect — clear native session so SPTSessionManager is
    // forced to call initiateSession(), opening Spotify if needed.
    debugPrint(
      'forceFullReconnect: step 2 – clearing native session '
      '(soft failed, lastError: $lastConnectError)',
    );
    await _bridge.clearSession();
    // Reset Dart-side cache so the next getSpotifyAccessToken() call goes
    // to native (triggering initiateSession → opens Spotify app).
    // Without this, the recent lastConnectionTime from step 1 causes
    // getSpotifyAccessToken to return the cached token, skipping initiateSession.
    lastConnectionTime = DateTime(1970);
    lastValidAccessToken = '';
    hasSpotifyAccessToken = false;
    isConnectedRemote = false;
    if (await connect()) return true;

    // initiateSession() launches Spotify but is async — the app may not be
    // ready to accept a socket connection by the time the first connect()
    // attempt fires.  Wait a few seconds and retry once before giving up.
    debugPrint(
      'forceFullReconnect: step 2 first attempt failed, '
      'waiting 3 s for Spotify to finish starting…',
    );
    await Future.delayed(const Duration(seconds: 3));
    // Reset again: connect() above may have set lastConnectionTime even on failure.
    lastConnectionTime = DateTime(1970);
    lastValidAccessToken = '';
    return connect();
  }

  /// Resets every Dart-side cache and clears the native session.
  /// Does NOT reconnect — call [connect] afterwards if needed.
  Future<String> resetAll() async {
    _isConnecting = false;
    lastConnectionTime = DateTime(1970);
    lastValidAccessToken = '';
    hasSpotifyAccessToken = false;
    isConnectedRemote = false;
    lastConnectError = '';
    SpotifyConnectionLog().addSimpleEntry(
      SpotifyConnectionStatus.notConnected,
      'resetAll: clearing native session + all Dart caches',
    );
    try {
      await _bridge.clearSession();
      SpotifyConnectionLog().addSimpleEntry(
        SpotifyConnectionStatus.notConnected,
        'resetAll: done — session cleared, caches reset',
      );
      return 'Session cleared, all caches reset';
    } catch (e) {
      SpotifyConnectionLog().addSimpleEntry(
        SpotifyConnectionStatus.notConnected,
        'resetAll error: $e',
      );
      return 'Error clearing session: $e';
    }
  }

  Future<void> _mute() async {
    if (Platform.isMacOS) {
      await _bridge.setVolume(0);
    } else {
      _setSystemVolume(0);
    }
  }

  Future<void> _unMute() async {
    if (Platform.isMacOS) {
      await _bridge.setVolume((volume * 100).round());
    } else {
      _setSystemVolume(volume);
    }
  }

  Future<bool> pausePlayer() async {
    try {
      if (!Platform.isMacOS) await _mute();
      await _bridge.pause();
      SpotifyConnectionLog().addSimpleEntry(
        SpotifyConnectionStatus.connectedSpotifyRemoteApp,
        'Pause Spotify Remote App',
      );
      isPlaying = false;
      return isPlaying;
    } on PlatformException catch (platformException) {
      if (_needsReconnect(platformException)) {
        hasSpotifyAccessToken = false;
        SpotifyConnectionLog().addSimpleEntry(
          SpotifyConnectionStatus.notConnected,
          'Error pausing, reconnecting. ${platformException.details ?? platformException.message}',
        );
        await connectAccessToken();
        if (hasSpotifyAccessToken) {
          await connectToSpotifyRemote();
          if (isConnectedRemote) {
            SpotifyConnectionLog().addSimpleEntry(
              SpotifyConnectionStatus.connectedSpotifyRemoteApp,
              'Reconnected. Retrying pause.',
            );
            await _bridge.pause();
            isPlaying = false;
            return isPlaying;
          }
        }
      }
      debugPrint('Failed to pause. ${platformException.details}');
      return isPlaying;
    } catch (e) {
      debugPrint('Failed to pause. $e');
      return isPlaying;
    }
  }

  Future<bool> resumePlayer() async {
    try {
      await _bridge.resume();
      await _unMute();
      SpotifyConnectionLog().addSimpleEntry(
        SpotifyConnectionStatus.connectedSpotifyRemoteApp,
        'Resumed Spotify Remote App',
      );
      isPlaying = true;
      return isPlaying;
    } on PlatformException catch (platformException) {
      if (_needsReconnect(platformException)) {
        hasSpotifyAccessToken = false;
        SpotifyConnectionLog().addSimpleEntry(
          SpotifyConnectionStatus.notConnected,
          'Error resuming, reconnecting. ${platformException.details ?? platformException.message}',
        );
        await connectAccessToken();
        if (hasSpotifyAccessToken) {
          await connectToSpotifyRemote();
          if (isConnectedRemote) {
            SpotifyConnectionLog().addSimpleEntry(
              SpotifyConnectionStatus.connectedSpotifyRemoteApp,
              'Reconnected. Retrying resume.',
            );
            await _bridge.resume();
            isPlaying = true;
            return isPlaying;
          }
        }
      }
      debugPrint('Failed to resume. ${platformException.details}');
      return isPlaying;
    } catch (e) {
      debugPrint('Failed to resume. $e');
      return isPlaying;
    }
  }

  Future<String> playTrackByUriAndJumpStart(String spotifyUri, int jumpStart) {
    DJTrack track = DJTrack(
      id: '',
      name: '',
      artist: '',
      spotifyUri: spotifyUri,
      networkImageUri: '',
      album: '',
      startTime: jumpStart,
      startTimeMS: 0,
      duration: 0,
      playCount: 0,
      mp3Uri: '',
    );
    return playTrackAndJumpStart(track, jumpStart, DJPlaylistType.hotspot, '');
  }

  Future<String> playTrackAndJumpStart(
    DJTrack track,
    int jumpStart,
    DJPlaylistType playlistType,
    String playlistName, {
    bool retry = true,
  }) async {
    debugPrint(
      '[PLAY] hasSpotifyAccessToken=$hasSpotifyAccessToken tokenEmpty=${lastValidAccessToken.isEmpty} uri=${track.spotifyUri} jumpStart=$jumpStart',
    );
    if (!hasSpotifyAccessToken || !lastValidAccessToken.isNotEmpty) {
      debugPrint('[PLAY] Blocked: not connected');
      return '[Error] Not connected to Spotify';
    }
    final startTime = DateTime.now();
    try {
      debugPrint('[PLAY] Calling bridge.play uri=${track.spotifyUri}');
      await _bridge.play(
        spotifyUri: track.spotifyUri,
        positionMs: jumpStart > 0 ? jumpStart : 0,
      );
      debugPrint('[PLAY] bridge.play returned OK');
      if (jumpStart > 0) {
        latestDurationStartupMS = DateTime.now()
            .difference(startTime)
            .inMilliseconds;
      }

      SpotifyConnectionLog().addSimpleEntry(
        SpotifyConnectionStatus.connectedSpotifyRemoteApp,
        'play track ${track.spotifyUri}',
      );
      final startupTimeMessage = jumpStart > 0 && latestDurationStartupMS > 0
          ? ' - startup time: $latestDurationStartupMS'
          : '';
      final result = '${track.name} -$startupTimeMessage';
      debugPrint('[PLAY] Success result: $result');
      return result;
    } on PlatformException catch (platformException) {
      debugPrint(
        '[PLAY] PlatformException code=${platformException.code} '
        'message=${platformException.message}\n'
        '  details=${platformException.details}',
      );
      if (retry && _needsReconnect(platformException)) {
        hasSpotifyAccessToken = false;
        SpotifyConnectionLog().addSimpleEntry(
          SpotifyConnectionStatus.notConnected,
          'Error playing, reconnecting. '
          '${platformException.message ?? platformException.details}',
        );
        await connectAccessToken();
        if (hasSpotifyAccessToken) {
          await connectToSpotifyRemote();
          if (isConnectedRemote) {
            SpotifyConnectionLog().addSimpleEntry(
              SpotifyConnectionStatus.connectedSpotifyRemoteApp,
              'Reconnected. Retrying play.',
            );
            return await playTrackAndJumpStart(
              track,
              jumpStart,
              playlistType,
              playlistName,
              retry: false,
            );
          }
        }
      }
      return '[Error] Failed to play. '
          '${platformException.message ?? platformException.details}';
    } catch (e) {
      debugPrint('[PLAY] Caught error: $e');
      return '[Error] Failed to play. $e';
    }
  }

  Future<String> playSpotiyfyUriAndJumpStart(
    String spotifyUri,
    int jumpStart, {
    bool retry = true,
  }) async {
    if (!hasSpotifyAccessToken || !lastValidAccessToken.isNotEmpty) {
      return '[Error] Not connected to Spotify';
    }

    // make a timer to find duration between two timestamps
    final startTime = DateTime.now();
    debugPrint('Start time: $startTime');
    bool success = false;
    int retryCount = 0;
    try {
      // turn volume down
      debugPrint('before volume: ${DateTime.now().difference(startTime)}');
      double volume = await _getSystemVolume();
      debugPrint('after volume: ${DateTime.now().difference(startTime)}');
      if (volume == 0) {
        volume = 0.5;
        debugPrint('volume set to 0.5');
      }
      if (jumpStart > 0) {
        _setSystemVolume(0);
      }
      debugPrint('before play: ${DateTime.now().difference(startTime)}');
      await _bridge.play(spotifyUri: spotifyUri);
      debugPrint('after play: ${DateTime.now().difference(startTime)}');
      if (jumpStart > 0) {
        try {
          await Future.delayed(const Duration(milliseconds: 80));
          debugPrint('after delay: ${DateTime.now().difference(startTime)}');
          retryCount = 0;
          success = false;

          while (retryCount < numberOfRetries && !success) {
            try {
              await _bridge.seekTo(positionedMilliseconds: jumpStart);
              debugPrint(
                'success $retryCount : ${DateTime.now().difference(startTime)}',
              );
              success = true;
              debugPrint('SUCCESS after $retryCount retries');
            } catch (e) {
              retryCount++;
              debugPrint(
                'retry $retryCount : ${DateTime.now().difference(startTime)}',
              );
              debugPrint('Retry jump start $retryCount');
              if (retryCount >= numberOfRetries) {
                debugPrint(
                  'Failed to jump start after $numberOfRetries attempts. $e',
                );
              }
            }
          }
        } catch (e) {
          debugPrint('Failed to jump start. $e');
        }
        final endTime = DateTime.now();
        final duration = endTime.difference(startTime);
        debugPrint('Duration to jump start: $duration');
        latestDurationStartupMS = duration.inMilliseconds;
      }

      _setSystemVolume(volume);

      SpotifyConnectionLog().addSimpleEntry(
        SpotifyConnectionStatus.connectedSpotifyRemoteApp,
        'play track $spotifyUri',
      );
      return '[Success] Playing track $spotifyUri';
    } on PlatformException catch (platformException) {
      debugPrint(
        '[PLAY] PlatformException code=${platformException.code} '
        'message=${platformException.message}\n'
        '  details=${platformException.details}',
      );
      if (retry && _needsReconnect(platformException)) {
        hasSpotifyAccessToken = false;
        SpotifyConnectionLog().addSimpleEntry(
          SpotifyConnectionStatus.notConnected,
          'Error playing, reconnecting. '
          '${platformException.message ?? platformException.details}',
        );
        await connectAccessToken();
        if (hasSpotifyAccessToken) {
          await connectToSpotifyRemote();
          if (isConnectedRemote) {
            SpotifyConnectionLog().addSimpleEntry(
              SpotifyConnectionStatus.connectedSpotifyRemoteApp,
              'Reconnected. Retrying play.',
            );
            return await playSpotiyfyUriAndJumpStart(
              spotifyUri,
              jumpStart,
              retry: false,
            );
          }
        }
      }
      return '[Error] Failed to play. '
          '${platformException.message ?? platformException.details}';
    } catch (e) {
      return '[Error] Failed to play. $e';
    }
  }

  Future<String> playTrack(String spotifyUri) async {
    if (!hasSpotifyAccessToken || !lastValidAccessToken.isNotEmpty) {
      return '[Error] Not connected to Spotify';
    }

    try {
      await _bridge.play(spotifyUri: spotifyUri);
      SpotifyConnectionLog().addSimpleEntry(
        SpotifyConnectionStatus.connectedSpotifyRemoteApp,
        'play track $spotifyUri',
      );
      return '[Success] Playing track $spotifyUri';
    } on PlatformException catch (platformException) {
      debugPrint('Failed to play. details: ${platformException.details}');
      debugPrint('Failed to play. code: ${platformException.code}');
      debugPrint('Failed to play. message: ${platformException.message}');
      if (_needsReconnect(platformException)) {
        hasSpotifyAccessToken = false;
        SpotifyConnectionLog().addSimpleEntry(
          SpotifyConnectionStatus.notConnected,
          'Error playing, reconnecting. '
          '${platformException.message ?? platformException.details}',
        );
        await connectAccessToken();
        if (hasSpotifyAccessToken) {
          await connectToSpotifyRemote();
          if (isConnectedRemote) {
            SpotifyConnectionLog().addSimpleEntry(
              SpotifyConnectionStatus.connectedSpotifyRemoteApp,
              'Reconnected. Retrying play.',
            );
            return await playTrack(spotifyUri);
          }
        }
      }
      return '[Error] Failed to play. '
          '${platformException.message ?? platformException.details}';
    } catch (e) {
      return '[Error] Failed to play. $e';
    }
  }

  bool _needsReconnect(PlatformException e) {
    final details = e.details?.toString() ?? '';
    final message = e.message ?? '';
    // Android/iOS: remote SDK disconnected
    if (details.contains('SpotifyDisconnectedException')) return true;
    // iOS SPTAppRemote: session was interrupted (e.g. after long background)
    if (details.contains('Request interrupted by user')) return true;
    if (message.contains('Request interrupted by user')) return true;
    // macOS/Web API: no active Spotify device
    if (e.code == 'API_ERROR' &&
        (message.contains('NO_ACTIVE_DEVICE') ||
            message.contains('No active device'))) {
      return true;
    }
    // iOS SPTAppRemote: any player command failure (e.g. 404 from a zombie
    // connection where isConnected=true but the Spotify app is unreachable).
    // The retry:false guard in callers prevents infinite loops.
    if (e.code == 'PLAY_ERROR' ||
        e.code == 'PAUSE_ERROR' ||
        e.code == 'RESUME_ERROR') {
      return true;
    }
    return false;
  }

  Future<bool> connectAccessToken() async {
    debugPrint('[Spotify] connectAccessToken: starting');
    try {
      final accessToken = await getSpotifyAccessToken();
      _credentials.accessToken = accessToken;
      lastValidAccessToken = accessToken;
      hasSpotifyAccessToken = accessToken.isNotEmpty;
      lastConnectionTime = DateTime.now();
      debugPrint(
        '[Spotify] connectAccessToken: success, token prefix=${accessToken.isNotEmpty ? accessToken.substring(0, 8) : "(empty)"}',
      );
      SpotifyConnectionLog().addSimpleEntry(
        SpotifyConnectionStatus.connectedSpotify,
        'Connect to Spotify',
      );
      // Fetch user profile in background — failure is non-fatal.
      if (Platform.isMacOS && accessToken.isNotEmpty) {
        unawaited(
          _bridge
              .getUserProfile()
              .then((profile) {
                spotifyUserDisplayName = profile['displayName'] ?? '';
                spotifyUserEmail = profile['email'] ?? '';
              })
              .catchError((error) {
                debugPrint('Failed to get user profile: $error');
              }),
        );
      }
    } catch (e) {
      debugPrint('[Spotify] connectAccessToken error: $e');
      lastConnectError = 'Token error: $e';
      SpotifyConnectionLog().addSimpleEntry(
        SpotifyConnectionStatus.notConnected,
        'Failed to connect to Spotify ${e.toString()}',
      );
      hasSpotifyAccessToken = false;
      lastAccessTokenError = e;
    }
    debugPrint('[Spotify] connectAccessToken: hasToken=$hasSpotifyAccessToken');
    return hasSpotifyAccessToken;
  }

  Future<String> getSpotifyAccessToken() async {
    // how long since last connection
    Duration timeSinceLastConnection = DateTime.now().difference(
      lastConnectionTime,
    );
    debugPrint('Time since last connection: $timeSinceLastConnection');

    // Spotify tokens expire after 1 hour, so refresh if more than 50 minutes old
    if (lastConnectionTime.isAfter(
          DateTime.now().subtract(const Duration(minutes: 50)),
        ) &&
        lastValidAccessToken.isNotEmpty) {
      debugPrint(
        'getSpotifyAccessToken ALREADY CONNECTED lastConnectionTime: $lastConnectionTime',
      );
      return lastValidAccessToken;
    }

    debugPrint(
      'getSpotifyAccessToken RECONNECT lastConnectionTime: $lastConnectionTime',
    );

    try {
      _credentials.scopes = [
        'app-remote-control',
        'streaming',
        'user-modify-playback-state',
        'playlist-read-private',
        'playlist-modify-public',
        'user-read-currently-playing',
      ];
      var accessToken = await _bridge.getAccessToken(
        clientId: _credentials.clientId ?? '',
        redirectUrl: _spotifyRedirectUrl,
        scope:
            'app-remote-control, '
            'streaming, '
            'user-modify-playback-state, '
            'playlist-read-private, '
            'playlist-modify-public, '
            'user-read-currently-playing',
      );

      final prefix = accessToken.isNotEmpty
          ? accessToken.substring(0, accessToken.length.clamp(0, 12))
          : '(empty)';
      debugPrint('getSpotifyAccessToken accessToken: $accessToken');
      SpotifyConnectionLog().addSimpleEntry(
        SpotifyConnectionStatus.connectedSpotify,
        'getAccessToken OK: prefix=$prefix len=${accessToken.length}',
      );
      isSpotifyPluginInstalled = true;
      return accessToken;
    } on PlatformException catch (e) {
      debugPrint('getSpotifyAccessToken error: ${e.toString()}');
      // AUTH_IN_PROGRESS means native side is already authenticating;
      // return the cached token if we have one rather than failing hard.
      if (e.code == 'AUTH_IN_PROGRESS' && lastValidAccessToken.isNotEmpty) {
        debugPrint(
          'getSpotifyAccessToken: auth in progress, reusing cached token',
        );
        return lastValidAccessToken;
      }
      if (e.toString().contains('MissingPluginException')) {
        hasSpotifyAccessToken = false;
        isSpotifyPluginInstalled = false;
        SpotifyConnectionLog().addSimpleEntry(
          SpotifyConnectionStatus.notConnected,
          'Error, SpotifyRemote exception, not connected. ${e.toString()}',
        );
      }
      rethrow;
    } catch (e) {
      debugPrint('getSpotifyAccessToken error: ${e.toString()}');
      if (e.toString().contains('MissingPluginException')) {
        hasSpotifyAccessToken = false;
        isSpotifyPluginInstalled = false;
        SpotifyConnectionLog().addSimpleEntry(
          SpotifyConnectionStatus.notConnected,
          'Error, SpotifyRemote exception, not connected. ${e.toString()}',
        );
      }
      rethrow;
    }
  }

  Future<bool> connectToSpotifyRemote() async {
    debugPrint(
      '[Spotify] connectToSpotifyRemote: token prefix=${lastValidAccessToken.isNotEmpty ? lastValidAccessToken.substring(0, 8) : "(empty)"}',
    );
    try {
      var result = await _bridge.connectToSpotifyRemote(
        clientId: _credentials.clientId.toString(),
        redirectUrl: _spotifyRedirectUrl,
        scope:
            'app-remote-control, '
            'streaming, '
            'user-modify-playback-state, '
            'playlist-read-private, '
            'playlist-modify-public, '
            'user-read-currently-playing',
        accessToken: lastValidAccessToken,
      );
      debugPrint('[Spotify] connectToSpotifyRemote: result=$result');
      SpotifyConnectionLog().addSimpleEntry(
        SpotifyConnectionStatus.connectedSpotifyRemoteApp,
        'Connected to Spotify Remote App',
      );
      isConnectedRemote = result;
      return result;
    } on PlatformException catch (e) {
      lastConnectError = '${e.code}: ${e.message ?? e.details}';
      // details now contains NSError domain+code and a human-readable hint
      // from SpotifyNativeChannel — log it on its own line for visibility.
      debugPrint(
        '[Spotify] connectToSpotifyRemote PlatformException: '
        'code=${e.code} message=${e.message}\n'
        '  details=${e.details}',
      );
      SpotifyConnectionLog().addSimpleEntry(
        SpotifyConnectionStatus.notConnected,
        'connectToSpotifyRemote failed: code=${e.code} '
        'msg=${e.message} details=${e.details}',
      );
      return false;
    } on MissingPluginException {
      lastConnectError = 'MissingPluginException';
      debugPrint('[Spotify] connectToSpotifyRemote: MissingPluginException');
      SpotifyConnectionLog().addSimpleEntry(
        SpotifyConnectionStatus.notConnected,
        'connectToSpotifyRemote: MissingPluginException',
      );
      return false;
    } catch (e) {
      lastConnectError = 'Unknown: $e';
      debugPrint('[Spotify] connectToSpotifyRemote error: $e');
      SpotifyConnectionLog().addSimpleEntry(
        SpotifyConnectionStatus.notConnected,
        'connectToSpotifyRemote error: $e',
      );
      return false;
    }
  }
}

final spotifyRemoteRepositoryProvider = Provider<SpotifyRemoteRepository>((
  ref,
) {
  SpotifyApiCredentials credentials = SpotifyApiCredentials(
    dotenv.env['SPOTIFY_CLIENTID'],
    dotenv.env['SPOTIFY_SECRET'],
  );
  credentials.scopes = [];

  String redirectUrl =
      dotenv.env['SPOTIFY_REDIRECT_URL'] ?? 'djsports://callback';

  return SpotifyRemoteRepository(credentials, redirectUrl);
});
