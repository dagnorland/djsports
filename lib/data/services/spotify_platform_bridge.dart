import 'dart:io';

import 'package:djsports/data/models/spotify_device.dart';
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

  /// [forceAccountPicker] skips the cached grant and makes Spotify show its
  /// login / account picker (iOS/macOS) – used when switching account.
  Future<String> getAccessToken({
    required String clientId,
    required String redirectUrl,
    required String scope,
    bool forceAccountPicker = false,
  });

  Future<bool> connectToSpotifyRemote({
    required String clientId,
    required String redirectUrl,
    required String scope,
    required String accessToken,
  });

  /// Plays on [deviceId], or on the active device when null.
  /// Returns the device used (iOS/macOS) or null when unknown.
  /// Throws [PlatformException] `NO_ACTIVE_DEVICE` (details = device maps)
  /// or `PREMIUM_REQUIRED`.
  Future<SpotifyDevice?> play({
    required String spotifyUri,
    int positionMs = 0,
    String? deviceId,
  });

  Future<void> pause();

  Future<SpotifyDevice?> resume({String? deviceId});

  Future<void> seekTo({required int positionedMilliseconds});

  Future<void> setVolume(int percent);

  /// Plays [spotifyUri] starting at [positionMs].
  /// Each platform handles mute / seek / unmute internally.
  Future<SpotifyDevice?> playWithPosition({
    required String spotifyUri,
    int positionMs = 0,
    String? deviceId,
  });

  /// Returns the current volume as [0.0, 1.0].
  Future<double> getSystemVolume();

  /// Sets the volume. [volume] is in [0.0, 1.0].
  /// Sets the system volume. On macOS [spotifyToo] also sets the active
  /// Spotify device's volume via the Web API; ignored elsewhere.
  Future<void> setSystemVolume(double volume, {bool spotifyToo = true});

  /// Opens Spotify: activates it if running, launches it if not.
  Future<void> launchSpotify();

  /// Returns Spotify user profile fields: displayName, email, id, product.
  Future<Map<String, String>> getUserProfile();

  /// Returns the active Spotify devices for the authenticated account.
  /// Each entry is formatted as "Name (Type)" with " ●" appended if active.
  Future<List<String>> getActiveDevices();

  /// All Spotify Connect devices for the authenticated account.
  /// Empty on Android (App Remote SDK has no device list).
  Future<List<SpotifyDevice>> getDevices();

  /// Moves playback to [deviceId] (Web API `PUT /me/player`), keeping
  /// the current play/pause state. No-op on Android.
  Future<void> transferPlayback(String deviceId);

  /// macOS only: drives Spotify on this Mac via AppleScript instead of the
  /// Web API. [command] is `play` (with [spotifyUri], [positionMs]),
  /// `pause` or `resume`. Throws [UnsupportedError] elsewhere.
  Future<void> localPlayer(
    String command, {
    String? spotifyUri,
    int positionMs = 0,
  });

  /// macOS only: starts the in-app Spotify Web Playback SDK player, which
  /// registers djSports as a Spotify Connect device called [name]. Its
  /// events arrive on [webPlayerEvents]. Throws [UnsupportedError]
  /// elsewhere.
  Future<void> startWebPlayer(String name);

  /// macOS only: `pause`, `resume`, `seek` ([value] = ms), `setVolume`
  /// ([value] = 0–1) or `activate` on the in-app web player.
  Future<void> webPlayerCommand(String command, {num? value});

  /// macOS only: web player events as maps with an `event` key (`ready`
  /// with `deviceId`, `not_ready`, `state`, `log`, `*_error` with
  /// `message`). Empty elsewhere.
  Stream<Map<String, dynamic>> webPlayerEvents();

  /// Name Spotify uses for this machine. Empty when unknown.
  Future<String> getLocalDeviceName();

  /// Whether the Spotify app runs on this machine. Null when unknown.
  Future<bool?> isSpotifyRunning();

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
    bool forceAccountPicker = false,
  }) => _mc
      .invokeMethod<String>('getAccessToken', {
        'clientId': clientId,
        'redirectUrl': redirectUrl,
        'scope': scope,
        'forceAccountPicker': forceAccountPicker,
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
  Future<SpotifyDevice?> play({
    required String spotifyUri,
    int positionMs = 0,
    String? deviceId,
  }) => _invokePlay(_mc, spotifyUri, positionMs, deviceId);

  @override
  Future<void> pause() => _mc.invokeMethod('pause');

  @override
  Future<SpotifyDevice?> resume({String? deviceId}) async => _deviceUsed(
    await _mc.invokeMethod<Object?>('resume', {'deviceId': ?deviceId}),
  );

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
  Future<SpotifyDevice?> playWithPosition({
    required String spotifyUri,
    int positionMs = 0,
    String? deviceId,
  }) => _invokePlay(_mc, spotifyUri, positionMs, deviceId);

  @override
  Future<double> getSystemVolume() async =>
      await FlutterVolumeController.getVolume() ?? 0.5;

  @override
  Future<void> setSystemVolume(double volume, {bool spotifyToo = true}) =>
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
  Future<List<SpotifyDevice>> getDevices() => _invokeGetDevices(_mc);

  @override
  Future<void> transferPlayback(String deviceId) =>
      _mc.invokeMethod('transferPlayback', {'deviceId': deviceId});

  @override
  Future<void> localPlayer(
    String command, {
    String? spotifyUri,
    int positionMs = 0,
  }) => throw UnsupportedError('localPlayer is macOS-only');

  @override
  Future<void> startWebPlayer(String name) =>
      throw UnsupportedError('The web player is macOS-only');

  @override
  Future<void> webPlayerCommand(String command, {num? value}) =>
      throw UnsupportedError('The web player is macOS-only');

  @override
  Stream<Map<String, dynamic>> webPlayerEvents() => const Stream.empty();

  @override
  Future<String> getLocalDeviceName() async =>
      await _mc.invokeMethod<String>('getLocalDeviceName') ?? '';

  @override
  Future<void> clearSession() => _mc.invokeMethod('clearSession');

  // iOS can't see other apps' state.
  @override
  Future<bool?> isSpotifyRunning() async => null;

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
    bool forceAccountPicker = false,
  }) => _mc
      .invokeMethod<String>('getAccessToken', {
        'clientId': clientId,
        'redirectUrl': redirectUrl,
        'scope': scope,
        'forceAccountPicker': forceAccountPicker,
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
  Future<SpotifyDevice?> play({
    required String spotifyUri,
    int positionMs = 0,
    String? deviceId,
  }) => _invokePlay(_mc, spotifyUri, positionMs, deviceId);

  @override
  Future<void> pause() => _mc.invokeMethod('pause');

  @override
  Future<SpotifyDevice?> resume({String? deviceId}) async => _deviceUsed(
    await _mc.invokeMethod<Object?>('resume', {'deviceId': ?deviceId}),
  );

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
  Future<SpotifyDevice?> playWithPosition({
    required String spotifyUri,
    int positionMs = 0,
    String? deviceId,
  }) => _invokePlay(_mc, spotifyUri, positionMs, deviceId);

  @override
  Future<double> getSystemVolume() async =>
      await FlutterVolumeController.getVolume() ?? _cachedVolume;

  @override
  Future<void> setSystemVolume(double volume, {bool spotifyToo = true}) async {
    _cachedVolume = volume;
    await FlutterVolumeController.setVolume(volume);
    if (!spotifyToo) return;
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
  Future<List<SpotifyDevice>> getDevices() => _invokeGetDevices(_mc);

  @override
  Future<void> transferPlayback(String deviceId) =>
      _mc.invokeMethod('transferPlayback', {'deviceId': deviceId});

  @override
  Future<void> localPlayer(
    String command, {
    String? spotifyUri,
    int positionMs = 0,
  }) => _mc.invokeMethod('localPlayer', {
    'command': command,
    'spotifyUri': ?spotifyUri,
    if (positionMs > 0) 'positionMs': positionMs,
  });

  static const _webPlayerEc = EventChannel(
    'com.djsports/spotify_web_player_events',
  );

  @override
  Future<void> startWebPlayer(String name) =>
      _mc.invokeMethod('webPlayerStart', {'name': name});

  @override
  Future<void> webPlayerCommand(String command, {num? value}) => _mc
      .invokeMethod('webPlayerCommand', {'command': command, 'value': ?value});

  @override
  Stream<Map<String, dynamic>> webPlayerEvents() => _webPlayerEc
      .receiveBroadcastStream()
      .map((e) => Map<String, dynamic>.from(e as Map));

  @override
  Future<String> getLocalDeviceName() async =>
      await _mc.invokeMethod<String>('getLocalDeviceName') ?? '';

  @override
  Future<void> clearSession() => _mc.invokeMethod('clearSession');

  @override
  Future<bool?> isSpotifyRunning() =>
      _mc.invokeMethod<bool>('isSpotifyRunning');

  @override
  Future<String> reconnectViaSpotify({
    required String clientId,
    required String redirectUrl,
  }) => throw UnsupportedError('reconnectViaSpotify is iOS-only');

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
      _mc.invokeMethod('openUri', {'uri': spotifyUri});
}

class _AndroidBridge implements SpotifyPlatformBridge {
  static const _numberOfRetries = 8;

  @override
  Future<String> getAccessToken({
    required String clientId,
    required String redirectUrl,
    required String scope,
    bool forceAccountPicker = false,
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
  Future<SpotifyDevice?> play({
    required String spotifyUri,
    int positionMs = 0,
    String? deviceId,
  }) async {
    await SpotifySdk.play(spotifyUri: spotifyUri);
    return null;
  }

  @override
  Future<void> pause() => SpotifySdk.pause();

  @override
  Future<SpotifyDevice?> resume({String? deviceId}) async {
    await SpotifySdk.resume();
    return null;
  }

  @override
  Future<void> seekTo({required int positionedMilliseconds}) =>
      SpotifySdk.seekTo(positionedMilliseconds: positionedMilliseconds);

  @override
  Future<void> setVolume(int percent) async {}
  // system volume via flutter_volume_controller

  // SpotifySdk.play() ignores positionMs — implement mute→play→seek-retry→unmute.
  @override
  Future<SpotifyDevice?> playWithPosition({
    required String spotifyUri,
    int positionMs = 0,
    String? deviceId,
  }) async {
    if (positionMs <= 0) {
      await SpotifySdk.play(spotifyUri: spotifyUri);
      return null;
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
    return null;
  }

  @override
  Future<double> getSystemVolume() async =>
      await FlutterVolumeController.getVolume() ?? 0.5;

  @override
  Future<void> setSystemVolume(double volume, {bool spotifyToo = true}) =>
      FlutterVolumeController.setVolume(volume);

  @override
  Future<void> launchSpotify() =>
      launchUrl(Uri.parse('spotify:'), mode: LaunchMode.externalApplication);

  @override
  Future<Map<String, String>> getUserProfile() async => {};

  @override
  Future<List<String>> getActiveDevices() async => [];

  @override
  Future<List<SpotifyDevice>> getDevices() async => [];

  @override
  Future<void> transferPlayback(String deviceId) async {}

  @override
  Future<void> localPlayer(
    String command, {
    String? spotifyUri,
    int positionMs = 0,
  }) => throw UnsupportedError('localPlayer is macOS-only');

  @override
  Future<void> startWebPlayer(String name) =>
      throw UnsupportedError('The web player is macOS-only');

  @override
  Future<void> webPlayerCommand(String command, {num? value}) =>
      throw UnsupportedError('The web player is macOS-only');

  @override
  Stream<Map<String, dynamic>> webPlayerEvents() => const Stream.empty();

  @override
  Future<String> getLocalDeviceName() async => '';

  @override
  Future<bool?> isSpotifyRunning() async => null;

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

// Shared by the iOS and macOS bridges (same native channel contract).

Future<SpotifyDevice?> _invokePlay(
  MethodChannel mc,
  String spotifyUri,
  int positionMs,
  String? deviceId,
) async => _deviceUsed(
  await mc.invokeMethod<Object?>('play', {
    'spotifyUri': spotifyUri,
    if (positionMs > 0) 'positionMs': positionMs,
    'deviceId': ?deviceId,
  }),
);

/// Native play/resume return `{deviceId, deviceName}` (or null).
SpotifyDevice? _deviceUsed(Object? raw) {
  if (raw is! Map) return null;
  final id = raw['deviceId'] as String? ?? '';
  if (id.isEmpty) return null;
  return SpotifyDevice(
    id: id,
    name: raw['deviceName'] as String? ?? '',
    isActive: true,
  );
}

Future<List<SpotifyDevice>> _invokeGetDevices(MethodChannel mc) async {
  final raw = await mc.invokeListMethod<Map<dynamic, dynamic>>('getDevices');
  return (raw ?? []).map(SpotifyDevice.fromMap).toList();
}
