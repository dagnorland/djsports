import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:djsports/data/models/djplaylist_model.dart';
import 'package:djsports/data/models/djtrack_model.dart';
import 'package:djsports/data/models/spotify_connection_log.dart';
import 'package:djsports/data/services/spotify_platform_bridge.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:spotify/spotify.dart';

class SpotifyRemoteRepository {
  SpotifyRemoteRepository(this._credentials, this._spotifyRedirectUrl) {
    _initVolume();
  }
  final SpotifyApiCredentials _credentials;
  final String _spotifyRedirectUrl;
  final SpotifyPlatformBridge _bridge = SpotifyPlatformBridge();

  Future<void> _initVolume() async {
    final v = await _bridge.getSystemVolume();
    if (v == 0) {
      await _bridge.setSystemVolume(0.85);
      volume = 0.85;
      _preMuteVolume = 0.85;
      volumeNotifier.value = 0.85;
      volumeAutoSetToDefault = true;
    } else {
      volume = v;
      _preMuteVolume = v;
      volumeNotifier.value = v;
    }
  }

  String lastValidAccessToken = '';
  Object lastAccessTokenError = Object();
  String lastConnectError = '';
  bool isConnectedRemote = false;
  bool hasSpotifyAccessToken = false;
  String spotifyUserDisplayName = '';
  String spotifyUserEmail = '';
  String spotifyUserId = '';
  final ValueNotifier<String> spotifyUserIdNotifier = ValueNotifier('');
  List<String> spotifyActiveDevices = [];
  bool isSpotifyPluginInstalled = false;
  bool isPlaying = false;
  bool _isConnecting = false;
  bool get isConnecting => _isConnecting;
  double volume = 0.5;
  double _preMuteVolume = 0.5;
  bool _isMuted = false;
  bool volumeAutoSetToDefault = false;
  final ValueNotifier<double> volumeNotifier = ValueNotifier(0.5);
  /// True on iOS when the silence keep-alive track is playing instead of
  /// real music (i.e. the user pressed pause).
  final ValueNotifier<bool> silencePlayingNotifier = ValueNotifier(false);
  int latestDurationStartupMS = 0;
  DateTime lastConnectionTime = DateTime(1970, 1, 1);

  String spotifyLogoFileName =
      'assets/images/spotify/Spotify_Primary_Logo_RGB_Green.png';

  String volumeAsPercent() {
    return (volume * 100).toStringAsFixed(0);
  }

  Future<double> getVolume() async => _bridge.getSystemVolume();

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
    final currentVolume = await _bridge.getSystemVolume();
    final newVolume = (currentVolume + adjustment).clamp(0.0, 1.0);
    final rounded = double.parse(newVolume.toStringAsFixed(2));
    volume = rounded;
    volumeNotifier.value = rounded;
    await _bridge.setSystemVolume(rounded);
    // Android uses discrete integer volume steps (typically 15 on the media
    // stream). setVolume() floor-truncates the float, so adding 0.05 often
    // maps to the same step and produces no change when increasing.
    // If the system volume didn't advance, bump by 0.07 (> 1/15 ≈ 0.067)
    // to guarantee crossing into the next step.
    if (Platform.isAndroid && adjustment > 0) {
      final actual = await _bridge.getSystemVolume();
      if (actual <= currentVolume + 0.001) {
        final bumped = (currentVolume + 0.07).clamp(0.0, 1.0);
        await _bridge.setSystemVolume(bumped);
        final finalActual = await _bridge.getSystemVolume();
        volume = finalActual;
        volumeNotifier.value = finalActual;
      }
    }
  }

  Future<void> launchSpotify() => _bridge.launchSpotify();

  /// Returns a key→value snapshot of native + Dart state for debugging.
  Future<Map<String, String>> getNativeDebugInfo() async {
    final native = await _bridge.getDebugInfo();
    return {
      'dart.isConnecting': _isConnecting ? 'true ⚠️' : 'false',
      'dart.hasToken': hasSpotifyAccessToken ? 'true' : 'false',
      'dart.isConnectedRemote': isConnectedRemote ? 'true' : 'false',
      'dart.tokenAge': lastConnectionTime.year == 1970
          ? 'never'
          : '${DateTime.now().difference(lastConnectionTime).inSeconds}s ago',
      ...native,
    };
  }

  Future<List<String>> getActiveDevices() => _bridge.getActiveDevices();

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
  /// Strategy (three-step):
  ///
  /// Step 1 – *soft reconnect*: reset only the Dart-side token cache and call
  /// [connect].  On iOS/macOS the native side tries to refresh via the stored
  /// refresh token silently.  No consent dialog if the grant is still valid.
  ///
  /// Step 2 – *legacy iOS SPTAppRemote step*: no-op on Web API platforms;
  /// left in place for Android compatibility.
  ///
  /// Step 3 – *full re-auth (last resort)*: clears the native token cache and
  /// forces a new PKCE OAuth flow.  May show a consent dialog if the refresh
  /// token is expired or revoked.
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

    // Step 2: open Spotify via authorizeAndPlayURI — no consent dialog when
    // previously authorized.  Spotify redirects back → reconnectIfNeeded()
    // fires → appRemote connects → returns the access token to Dart.
    if (Platform.isIOS) {
      debugPrint(
        'forceFullReconnect: step 2 – reconnectViaSpotify '
        '(soft failed, lastError: $lastConnectError)',
      );
      try {
        final token = await _bridge.reconnectViaSpotify(
          clientId: _credentials.clientId ?? '',
          redirectUrl: _spotifyRedirectUrl,
        );
        if (token.isNotEmpty) {
          debugPrint(
            'forceFullReconnect: step 2 reconnectViaSpotify succeeded, '
            'token prefix=${token.substring(0, token.length.clamp(0, 8))}',
          );
          lastValidAccessToken = token;
          hasSpotifyAccessToken = true;
          lastConnectionTime = DateTime.now();
          isConnectedRemote = true;
          return true;
        }
      } on PlatformException catch (e) {
        debugPrint('forceFullReconnect: step 2 failed (${e.code}): ${e.message}');
        // NO_SESSION means no storedSession → fall through to step 3.
      } catch (e) {
        debugPrint('forceFullReconnect: step 2 error: $e');
      }
    }

    // Step 3 (last resort): clear native session → initiateSession() →
    // opens Spotify, may show consent dialog if no valid grant on server.
    debugPrint(
      'forceFullReconnect: step 3 – clearing native session (last resort, '
      'lastError: $lastConnectError)',
    );
    await _bridge.clearSession();
    lastConnectionTime = DateTime(1970);
    lastValidAccessToken = '';
    hasSpotifyAccessToken = false;
    isConnectedRemote = false;
    if (await connect()) return true;

    // Wait a few seconds in case Spotify is still starting up.
    await Future.delayed(const Duration(seconds: 3));
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

  /// Clears the stored OAuth grant (refresh token on macOS, session on iOS)
  /// and starts a fresh login flow. Use when switching Spotify accounts.
  Future<bool> reGrantSpotify() async {
    _isConnecting = false;
    lastConnectionTime = DateTime(1970);
    lastValidAccessToken = '';
    hasSpotifyAccessToken = false;
    isConnectedRemote = false;
    lastConnectError = '';
    spotifyUserDisplayName = '';
    spotifyUserEmail = '';
    spotifyUserId = '';
    spotifyUserIdNotifier.value = '';
    spotifyActiveDevices = [];
    SpotifyConnectionLog().addSimpleEntry(
      SpotifyConnectionStatus.notConnected,
      'reGrantSpotify: clearing grant + all caches',
    );
    try {
      await _bridge.clearSession();
    } catch (e) {
      debugPrint('reGrantSpotify: clearSession error (non-fatal): $e');
    }
    return connect();
  }

  Future<void> _mute() async {
    _isMuted = true;
    await _bridge.setSystemVolume(0);
  }

  Future<void> _unMute() async {
    _isMuted = false;
    await _bridge.setSystemVolume(_preMuteVolume);
  }

  Future<bool> pausePlayer() async {
    try {
      if (Platform.isAndroid) {
        _preMuteVolume = volume;
        await _mute();
      }
      await _bridge.pause();
      if (Platform.isIOS) silencePlayingNotifier.value = true;
      SpotifyConnectionLog().addSimpleEntry(
        SpotifyConnectionStatus.connectedSpotifyRemoteApp,
        'Pause Spotify Remote App',
      );
      isPlaying = false;
      return isPlaying;
    } on PlatformException catch (platformException) {
      if (_needsReconnect(platformException)) {
        SpotifyConnectionLog().addSimpleEntry(
          SpotifyConnectionStatus.notConnected,
          'Error pausing, reconnecting. ${platformException.details ?? platformException.message}',
        );
        if (await connect()) {
          SpotifyConnectionLog().addSimpleEntry(
            SpotifyConnectionStatus.connectedSpotifyRemoteApp,
            'Reconnected. Retrying pause.',
          );
          await _bridge.pause();
          isPlaying = false;
          return isPlaying;
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
        SpotifyConnectionLog().addSimpleEntry(
          SpotifyConnectionStatus.notConnected,
          'Error resuming, reconnecting. ${platformException.details ?? platformException.message}',
        );
        if (await connect()) {
          SpotifyConnectionLog().addSimpleEntry(
            SpotifyConnectionStatus.connectedSpotifyRemoteApp,
            'Reconnected. Retrying resume.',
          );
          await _bridge.resume();
          isPlaying = true;
          return isPlaying;
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
    if (Platform.isIOS) silencePlayingNotifier.value = false;
    debugPrint(
      '[PLAY] hasSpotifyAccessToken=$hasSpotifyAccessToken tokenEmpty=${lastValidAccessToken.isEmpty} uri=${track.spotifyUri} jumpStart=$jumpStart',
    );
    if (!hasSpotifyAccessToken || !lastValidAccessToken.isNotEmpty) {
      debugPrint('[PLAY] Blocked: not connected');
      return '[Error] Not connected to Spotify';
    }
    final startTime = DateTime.now();
    try {
      debugPrint('[PLAY] Calling bridge.playWithPosition uri=${track.spotifyUri}');
      await _bridge.playWithPosition(
        spotifyUri: track.spotifyUri,
        positionMs: jumpStart > 0 ? jumpStart : 0,
      );
      // Only restore volume if we explicitly muted on pause. When playing
      // with a start time without a prior pause, the bridge handles its own
      // mute/unmute internally using the correct pre-seek volume.
      if (Platform.isAndroid && _isMuted) await _unMute();
      debugPrint('[PLAY] bridge.playWithPosition returned OK');
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
        SpotifyConnectionLog().addSimpleEntry(
          SpotifyConnectionStatus.notConnected,
          'Error playing, reconnecting. '
          '${platformException.message ?? platformException.details}',
        );
        if (await connect()) {
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

    final startTime = DateTime.now();
    try {
      await _bridge.playWithPosition(
        spotifyUri: spotifyUri,
        positionMs: jumpStart,
      );
      if (jumpStart > 0) {
        latestDurationStartupMS =
            DateTime.now().difference(startTime).inMilliseconds;
      }
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
        SpotifyConnectionLog().addSimpleEntry(
          SpotifyConnectionStatus.notConnected,
          'Error playing, reconnecting. '
          '${platformException.message ?? platformException.details}',
        );
        if (await connect()) {
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
        SpotifyConnectionLog().addSimpleEntry(
          SpotifyConnectionStatus.notConnected,
          'Error playing, reconnecting. '
          '${platformException.message ?? platformException.details}',
        );
        if (await connect()) {
          SpotifyConnectionLog().addSimpleEntry(
            SpotifyConnectionStatus.connectedSpotifyRemoteApp,
            'Reconnected. Retrying play.',
          );
          return await playTrack(spotifyUri);
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
    // Web API: expired token — trigger re-authentication
    if (e.code == 'API_ERROR' && message.contains('HTTP 401')) return true;
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
      // Fetch user profile + active devices in background — failure is non-fatal.
      if (accessToken.isNotEmpty) {
        if (Platform.isAndroid) {
          // Android bridge returns empty map — call Web API directly in Dart.
          unawaited(_fetchUserProfileFromWebApi(accessToken));
        } else {
          unawaited(
            _bridge
                .getUserProfile()
                .then((profile) {
                  spotifyUserDisplayName = profile['displayName'] ?? '';
                  spotifyUserEmail = profile['email'] ?? '';
                  spotifyUserId = profile['id'] ?? '';
                  spotifyUserIdNotifier.value = spotifyUserId;
                })
                .catchError((error) {
                  debugPrint('Failed to get user profile: $error');
                }),
          );
        }
        unawaited(
          _bridge
              .getActiveDevices()
              .then((devices) {
                spotifyActiveDevices = devices;
              })
              .catchError((error) {
                debugPrint('Failed to get active devices: $error');
                spotifyActiveDevices = [];
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

  /// Calls GET /v1/me on the Spotify Web API using [accessToken].
  /// Used on Android where the native bridge returns an empty profile.
  Future<void> _fetchUserProfileFromWebApi(String accessToken) async {
    try {
      final response = await http.get(
        Uri.parse('https://api.spotify.com/v1/me'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        spotifyUserDisplayName = data['display_name'] as String? ?? '';
        spotifyUserEmail = data['email'] as String? ?? '';
        spotifyUserId = data['id'] as String? ?? '';
        spotifyUserIdNotifier.value = spotifyUserId;
        debugPrint(
          '[Spotify] Android user profile: '
          'id=$spotifyUserId name=$spotifyUserDisplayName',
        );
      } else {
        debugPrint(
          '[Spotify] _fetchUserProfileFromWebApi: '
          'HTTP ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('[Spotify] _fetchUserProfileFromWebApi error: $e');
    }
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
        'streaming',
        'user-modify-playback-state',
        'user-read-playback-state',
        'user-read-private',
        'playlist-read-private',
        'playlist-modify-public',
        'user-read-currently-playing',
      ];
      var accessToken = await _bridge.getAccessToken(
        clientId: _credentials.clientId ?? '',
        redirectUrl: _spotifyRedirectUrl,
        scope:
            'streaming, '
            'user-modify-playback-state, '
            'user-read-playback-state, '
            'user-read-private, '
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
            'streaming, '
            'user-modify-playback-state, '
            'user-read-playback-state, '
            'user-read-private, '
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
      isConnectedRemote = false;
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
      isConnectedRemote = false;
      debugPrint('[Spotify] connectToSpotifyRemote: MissingPluginException');
      SpotifyConnectionLog().addSimpleEntry(
        SpotifyConnectionStatus.notConnected,
        'connectToSpotifyRemote: MissingPluginException',
      );
      return false;
    } catch (e) {
      lastConnectError = 'Unknown: $e';
      isConnectedRemote = false;
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
