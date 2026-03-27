import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:spotify_sdk/spotify_sdk.dart';
import 'package:url_launcher/url_launcher.dart';

abstract class SpotifyPlatformBridge {
  factory SpotifyPlatformBridge() {
    if (Platform.isIOS) return _IosBridge();
    if (Platform.isMacOS) return _MacOSBridge();
    return _AndroidBridge();
  }

  Future<String> getAccessToken({
    required String clientId,
    required String redirectUrl,
    required String scope,
  });

  Future<bool> connectToSpotifyRemote({
    required String clientId,
    required String redirectUrl,
    required String scope,
    required String accessToken,
  });

  Future<void> play({required String spotifyUri, int positionMs = 0});

  Future<void> pause();

  Future<void> resume();

  Future<void> seekTo({required int positionedMilliseconds});

  Future<void> setVolume(int percent);

  /// Plays [spotifyUri] starting at [positionMs].
  /// Each platform handles mute / seek / unmute internally.
  Future<void> playWithPosition({
    required String spotifyUri,
    int positionMs = 0,
  });

  /// Returns the current volume as [0.0, 1.0].
  Future<double> getSystemVolume();

  /// Sets the volume. [volume] is in [0.0, 1.0].
  Future<void> setSystemVolume(double volume);

  /// Opens Spotify: activates it if running, launches it if not.
  Future<void> launchSpotify();

  /// Returns Spotify user profile fields: displayName, email, id, product.
  Future<Map<String, String>> getUserProfile();

  /// Returns the active Spotify devices for the authenticated account.
  /// Each entry is formatted as "Name (Type)" with " ●" appended if active.
  Future<List<String>> getActiveDevices();

  /// Clears the native session cache so the next [getAccessToken] call is
  /// forced through [SPTSessionManager.initiateSession], which opens the
  /// Spotify app and guarantees it is running before [appRemote.connect()].
  Future<void> clearSession();

  /// Opens the Spotify app via [SPTAppRemote.authorizeAndPlayURI] and
  /// redirects back to this app WITHOUT showing an authorization consent
  /// dialog (provided the user has previously authorized this app).
  ///
  /// When Spotify redirects back, [applicationWillEnterForeground] fires and
  /// [reconnectIfNeeded] connects [SPTAppRemote].  Returns the access token
  /// string on success.
  ///
  /// Throws [PlatformException] with code `NO_SESSION` if there is no stored
  /// session — callers should fall back to a full [connect] in that case.
  /// No-op on non-iOS platforms (throws [UnsupportedError]).
  Future<String> reconnectViaSpotify({
    required String clientId,
    required String redirectUrl,
  });

  /// Returns a key→value snapshot of native state for debugging.
  /// Returns an empty map on platforms that don't implement this.
  Future<Map<String, String>> getDebugInfo();

  /// Returns the current Spotify playback position in milliseconds.
  /// Returns 0 when nothing is playing or on error.
  Future<int> getPlaybackPositionMs();

  Stream<bool> subscribeConnectionStatus();

  /// Opens the Spotify app to the given Spotify URI (e.g. spotify:playlist:xxx).
  Future<void> openSpotifyUri(String spotifyUri);
}

class _IosBridge implements SpotifyPlatformBridge {
  static const _mc = MethodChannel('com.djsports/spotify_native');
  static const _ec = EventChannel('com.djsports/spotify_connection_events');

  @override
  Future<String> getAccessToken({
    required String clientId,
    required String redirectUrl,
    required String scope,
  }) => _mc
      .invokeMethod<String>('getAccessToken', {
        'clientId': clientId,
        'redirectUrl': redirectUrl,
        'scope': scope,
      })
      .then((v) => v ?? '');

  @override
  Future<bool> connectToSpotifyRemote({
    required String clientId,
    required String redirectUrl,
    required String scope,
    required String accessToken,
  }) => _mc
      .invokeMethod<bool>('connect', {
        'clientId': clientId,
        'redirectUrl': redirectUrl,
        'scope': scope,
        'accessToken': accessToken,
      })
      .then((v) => v ?? false);

  @override
  Future<void> play({required String spotifyUri, int positionMs = 0}) =>
      _mc.invokeMethod('play', {
        'spotifyUri': spotifyUri,
        if (positionMs > 0) 'positionMs': positionMs,
      });

  @override
  Future<void> pause() => _mc.invokeMethod('pause');

  @override
  Future<void> resume() => _mc.invokeMethod('resume');

  @override
  Future<void> seekTo({required int positionedMilliseconds}) =>
      _mc.invokeMethod('seekTo', {
        'positionedMilliseconds': positionedMilliseconds,
      });

  @override
  Future<void> setVolume(int percent) =>
      _mc.invokeMethod('setVolume', {'volumePercent': percent});

  // Native Swift play handler already handles mute/seek/unmute — delegate directly.
  @override
  Future<void> playWithPosition({
    required String spotifyUri,
    int positionMs = 0,
  }) => _mc.invokeMethod('play', {
    'spotifyUri': spotifyUri,
    if (positionMs > 0) 'positionMs': positionMs,
  });

  @override
  Future<double> getSystemVolume() async =>
      await FlutterVolumeController.getVolume() ?? 0.5;

  @override
  Future<void> setSystemVolume(double volume) =>
      FlutterVolumeController.setVolume(volume);

  @override
  Future<void> launchSpotify() => _mc.invokeMethod('launchSpotify');

  @override
  Future<Map<String, String>> getUserProfile() async {
    final raw = await _mc.invokeMapMethod<String, dynamic>('getUserProfile');
    return (raw ?? {}).map((k, v) => MapEntry(k, v?.toString() ?? ''));
  }

  @override
  Future<List<String>> getActiveDevices() async =>
      await _mc.invokeListMethod<String>('getActiveDevices') ?? [];

  @override
  Future<void> clearSession() => _mc.invokeMethod('clearSession');

  @override
  Future<String> reconnectViaSpotify({
    required String clientId,
    required String redirectUrl,
  }) => throw UnsupportedError(
    'reconnectViaSpotify is not supported on iOS Web API',
  );

  @override
  Future<Map<String, String>> getDebugInfo() async {
    final raw = await _mc.invokeMapMethod<String, dynamic>('getDebugInfo');
    return (raw ?? {}).map((k, v) => MapEntry(k, v?.toString() ?? ''));
  }

  // Handled via Web API in SpotifyRemoteRepository (needs access token).
  @override
  Future<int> getPlaybackPositionMs() async => 0;

  @override
  Stream<bool> subscribeConnectionStatus() =>
      _ec.receiveBroadcastStream().map((event) {
        final map = event as Map<dynamic, dynamic>;
        return map['connected'] as bool? ?? false;
      });

  @override
  Future<void> openSpotifyUri(String spotifyUri) =>
      launchUrl(Uri.parse(spotifyUri), mode: LaunchMode.externalApplication);
}

class _MacOSBridge implements SpotifyPlatformBridge {
  static const _mc = MethodChannel('com.djsports/spotify_native');
  static const _ec = EventChannel('com.djsports/spotify_connection_events');
  double _cachedVolume = 0.5;

  @override
  Future<String> getAccessToken({
    required String clientId,
    required String redirectUrl,
    required String scope,
  }) => _mc
      .invokeMethod<String>('getAccessToken', {
        'clientId': clientId,
        'redirectUrl': redirectUrl,
        'scope': scope,
      })
      .then((v) => v ?? '');

  @override
  Future<bool> connectToSpotifyRemote({
    required String clientId,
    required String redirectUrl,
    required String scope,
    required String accessToken,
  }) => _mc
      .invokeMethod<bool>('connect', {
        'clientId': clientId,
        'redirectUrl': redirectUrl,
        'scope': scope,
        'accessToken': accessToken,
      })
      .then((v) => v ?? false);

  @override
  Future<void> play({required String spotifyUri, int positionMs = 0}) =>
      _mc.invokeMethod('play', {
        'spotifyUri': spotifyUri,
        if (positionMs > 0) 'positionMs': positionMs,
      });

  @override
  Future<void> pause() => _mc.invokeMethod('pause');

  @override
  Future<void> resume() => _mc.invokeMethod('resume');

  @override
  Future<void> seekTo({required int positionedMilliseconds}) =>
      _mc.invokeMethod('seekTo', {
        'positionedMilliseconds': positionedMilliseconds,
      });

  @override
  Future<void> setVolume(int percent) =>
      _mc.invokeMethod('setVolume', {'volumePercent': percent});

  // macOS Web API play already accepts position_ms inline — no muting needed.
  @override
  Future<void> playWithPosition({
    required String spotifyUri,
    int positionMs = 0,
  }) => _mc.invokeMethod('play', {
    'spotifyUri': spotifyUri,
    if (positionMs > 0) 'positionMs': positionMs,
  });

  @override
  Future<double> getSystemVolume() async =>
      await FlutterVolumeController.getVolume() ?? _cachedVolume;

  @override
  Future<void> setSystemVolume(double volume) async {
    _cachedVolume = volume;
    await FlutterVolumeController.setVolume(volume);
    await _mc.invokeMethod('setVolume', {
      'volumePercent': (volume * 100).round(),
    });
  }

  @override
  Future<void> launchSpotify() => _mc.invokeMethod('launchSpotify');

  @override
  Future<Map<String, String>> getUserProfile() async {
    final raw = await _mc.invokeMapMethod<String, dynamic>('getUserProfile');
    return (raw ?? {}).map((k, v) => MapEntry(k, v?.toString() ?? ''));
  }

  @override
  Future<List<String>> getActiveDevices() async =>
      await _mc.invokeListMethod<String>('getActiveDevices') ?? [];

  @override
  Future<void> clearSession() => _mc.invokeMethod('clearSession');

  @override
  Future<String> reconnectViaSpotify({
    required String clientId,
    required String redirectUrl,
  }) => throw UnsupportedError('reconnectViaSpotify is iOS-only');

  @override
  Future<Map<String, String>> getDebugInfo() async => {};

  // Handled via Web API in SpotifyRemoteRepository (needs access token).
  @override
  Future<int> getPlaybackPositionMs() async => 0;

  @override
  Stream<bool> subscribeConnectionStatus() =>
      _ec.receiveBroadcastStream().map((event) {
        final map = event as Map<dynamic, dynamic>;
        return map['connected'] as bool? ?? false;
      });

  @override
  Future<void> openSpotifyUri(String spotifyUri) =>
      _mc.invokeMethod('openUri', {'uri': spotifyUri});
}

class _AndroidBridge implements SpotifyPlatformBridge {
  static const _numberOfRetries = 8;

  @override
  Future<String> getAccessToken({
    required String clientId,
    required String redirectUrl,
    required String scope,
  }) => SpotifySdk.getAccessToken(
    clientId: clientId,
    redirectUrl: redirectUrl,
    scope: scope,
    asRadio: false,
  );

  @override
  Future<bool> connectToSpotifyRemote({
    required String clientId,
    required String redirectUrl,
    required String scope,
    required String accessToken,
  }) => SpotifySdk.connectToSpotifyRemote(
    clientId: clientId,
    redirectUrl: redirectUrl,
    scope: scope,
    accessToken: accessToken,
  );

  @override
  Future<void> play({required String spotifyUri, int positionMs = 0}) =>
      SpotifySdk.play(spotifyUri: spotifyUri);

  @override
  Future<void> pause() => SpotifySdk.pause();

  @override
  Future<void> resume() => SpotifySdk.resume();

  @override
  Future<void> seekTo({required int positionedMilliseconds}) =>
      SpotifySdk.seekTo(positionedMilliseconds: positionedMilliseconds);

  @override
  Future<void> setVolume(int percent) async {}
  // system volume via flutter_volume_controller

  // SpotifySdk.play() ignores positionMs — implement mute→play→seek-retry→unmute.
  @override
  Future<void> playWithPosition({
    required String spotifyUri,
    int positionMs = 0,
  }) async {
    if (positionMs <= 0) {
      await SpotifySdk.play(spotifyUri: spotifyUri);
      return;
    }
    double savedVolume = await FlutterVolumeController.getVolume() ?? 0.5;
    if (savedVolume == 0) savedVolume = 0.5;
    await FlutterVolumeController.setVolume(0); // mute
    try {
      await SpotifySdk.play(spotifyUri: spotifyUri);
      await Future.delayed(const Duration(milliseconds: 80));
      int retryCount = 0;
      bool success = false;
      while (retryCount < _numberOfRetries && !success) {
        try {
          await SpotifySdk.seekTo(positionedMilliseconds: positionMs);
          success = true;
        } catch (_) {
          retryCount++;
          if (retryCount >= _numberOfRetries) rethrow;
        }
      }
    } finally {
      await FlutterVolumeController.setVolume(savedVolume); // always restore
    }
  }

  @override
  Future<double> getSystemVolume() async =>
      await FlutterVolumeController.getVolume() ?? 0.5;

  @override
  Future<void> setSystemVolume(double volume) =>
      FlutterVolumeController.setVolume(volume);

  @override
  Future<void> launchSpotify() =>
      launchUrl(Uri.parse('spotify:'), mode: LaunchMode.externalApplication);

  @override
  Future<Map<String, String>> getUserProfile() async => {};

  @override
  Future<List<String>> getActiveDevices() async => [];

  @override
  Future<void> clearSession() async {} // no-op on Android

  @override
  Future<String> reconnectViaSpotify({
    required String clientId,
    required String redirectUrl,
  }) => throw UnsupportedError('reconnectViaSpotify is iOS-only');

  @override
  Future<Map<String, String>> getDebugInfo() async => {};

  @override
  Future<int> getPlaybackPositionMs() async {
    try {
      final state = await SpotifySdk.getPlayerState();
      return state?.playbackPosition ?? 0;
    } catch (_) {
      return 0;
    }
  }

  @override
  Stream<bool> subscribeConnectionStatus() =>
      SpotifySdk.subscribeConnectionStatus().map((status) => status.connected);

  @override
  Future<void> openSpotifyUri(String spotifyUri) =>
      launchUrl(Uri.parse(spotifyUri), mode: LaunchMode.externalApplication);
}
