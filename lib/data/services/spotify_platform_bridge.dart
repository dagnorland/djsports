import 'dart:io';

import 'package:flutter/services.dart';
import 'package:spotify_sdk/spotify_sdk.dart';

abstract class SpotifyPlatformBridge {
  factory SpotifyPlatformBridge() =>
      (Platform.isIOS || Platform.isMacOS) ? _IosBridge() : _AndroidBridge();

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

  Future<void> play({required String spotifyUri});

  Future<void> pause();

  Future<void> resume();

  Future<void> seekTo({required int positionedMilliseconds});

  Future<void> setVolume(int percent);

  Stream<bool> subscribeConnectionStatus();
}

class _IosBridge implements SpotifyPlatformBridge {
  static const _mc = MethodChannel('com.djsports/spotify_native');
  static const _ec = EventChannel('com.djsports/spotify_connection_events');

  @override
  Future<String> getAccessToken({
    required String clientId,
    required String redirectUrl,
    required String scope,
  }) =>
      _mc
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
  }) =>
      _mc
          .invokeMethod<bool>('connect', {
            'clientId': clientId,
            'redirectUrl': redirectUrl,
            'scope': scope,
            'accessToken': accessToken,
          })
          .then((v) => v ?? false);

  @override
  Future<void> play({required String spotifyUri}) =>
      _mc.invokeMethod('play', {'spotifyUri': spotifyUri});

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

  @override
  Stream<bool> subscribeConnectionStatus() =>
      _ec.receiveBroadcastStream().map((event) {
        final map = event as Map<dynamic, dynamic>;
        return map['connected'] as bool? ?? false;
      });
}

class _AndroidBridge implements SpotifyPlatformBridge {
  @override
  Future<String> getAccessToken({
    required String clientId,
    required String redirectUrl,
    required String scope,
  }) =>
      SpotifySdk.getAccessToken(
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
  }) =>
      SpotifySdk.connectToSpotifyRemote(
        clientId: clientId,
        redirectUrl: redirectUrl,
        scope: scope,
        accessToken: accessToken,
      );

  @override
  Future<void> play({required String spotifyUri}) =>
      SpotifySdk.play(spotifyUri: spotifyUri);

  @override
  Future<void> pause() => SpotifySdk.pause();

  @override
  Future<void> resume() => SpotifySdk.resume();

  @override
  Future<void> seekTo({required int positionedMilliseconds}) =>
      SpotifySdk.seekTo(positionedMilliseconds: positionedMilliseconds);

  @override
  Future<void> setVolume(int percent) async {} // system volume via flutter_volume_controller

  @override
  Stream<bool> subscribeConnectionStatus() =>
      SpotifySdk.subscribeConnectionStatus()
          .map((status) => status.connected);
}
