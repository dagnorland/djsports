import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:djsports/data/models/spotify_device.dart';
import 'package:djsports/data/repo/app_settings_repository.dart';
import 'package:djsports/data/services/spotify_platform_bridge.dart';
import 'package:djsports/data/services/spotify_windows_web_player.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:hive_ce/hive.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

/// Windows: Spotify via PKCE OAuth + the Spotify Web API, driving the
/// Spotify desktop app as a Spotify Connect device. A Dart port of the
/// macOS `SpotifyNativeChannel.swift` (no native code on Windows).
///
/// Login opens the browser; Spotify redirects to a loopback HTTP server
/// on this machine ([redirectUrl], must be registered in the user's
/// Spotify app). Errors are thrown as [PlatformException] with the same
/// codes as the iOS/macOS channel (`NO_ACTIVE_DEVICE`, `PREMIUM_REQUIRED`,
/// `API_ERROR` "HTTP 401 …", …) so [SpotifyRemoteRepository] treats all
/// three the same.
class WindowsSpotifyBridge implements SpotifyPlatformBridge {
  factory WindowsSpotifyBridge() => _instance;
  WindowsSpotifyBridge._();
  static final _instance = WindowsSpotifyBridge._();

  /// Redirect URI used on Windows. Spotify only allows plain `http` for
  /// loopback IP literals (not `localhost`).
  static const redirectUrl = AppSettings.windowsSpotifyRedirectUrl;

  static const _api = 'https://api.spotify.com/v1';
  static const _tokenUrl = 'https://accounts.spotify.com/api/token';
  static const _refreshTokenKey = 'spotifyWindowsRefreshToken';

  /// How long the browser login may take before giving up.
  static const _authTimeout = Duration(minutes: 5);

  String? _accessToken;

  /// Client ID from the last [getAccessToken], for silent refreshes.
  String? _clientId;

  /// The login in progress, shared by concurrent [getAccessToken] calls.
  Future<String>? _pendingAuth;

  double _cachedVolume = 0.5;

  /// Exact Spotify device name and ID of this PC's Spotify app once seen
  /// in the device list.
  String? _matchedLocalName;
  String? _matchedLocalId;

  // ── getAccessToken (PKCE OAuth with refresh token caching) ─────────────

  @override
  Future<String> getAccessToken({
    required String clientId,
    required String redirectUrl,
    required String scope,
    bool forceAccountPicker = false,
  }) async {
    _clientId = clientId;
    final normalizedScope = scope.replaceAll(', ', ' ').replaceAll(',', ' ');

    // Account switch: skip the cached refresh token and make Spotify show
    // its login / account picker.
    if (forceAccountPicker) {
      _accessToken = null;
      await _settingsDelete(_refreshTokenKey);
    } else {
      final refreshToken = _settingsGet(_refreshTokenKey);
      if (refreshToken.isNotEmpty) {
        final token = await _refreshAccessToken(clientId, refreshToken);
        if (token != null) return token;
      }
    }

    final pending = _pendingAuth;
    if (pending != null) return pending;
    final auth = _startPkceFlow(
      clientId: clientId,
      redirect: _loopbackRedirect(redirectUrl),
      scope: normalizedScope,
      forceAccountPicker: forceAccountPicker,
    );
    _pendingAuth = auth;
    try {
      return await auth;
    } finally {
      _pendingAuth = null;
    }
  }

  /// [configured] when it is a loopback `http` URL with a port (the only
  /// kind a local server can receive), else [redirectUrl]. A shared
  /// `djsports://callback` from iOS/macOS lands here.
  Uri _loopbackRedirect(String configured) {
    final uri = Uri.tryParse(configured);
    final isLoopback =
        uri != null &&
        uri.scheme == 'http' &&
        uri.hasPort &&
        (uri.host == '127.0.0.1' || uri.host == '::1');
    if (isLoopback) return uri;
    debugPrint(
      '[SpotifyWindows] redirect "$configured" is not a loopback URL – '
      'using $redirectUrl',
    );
    return Uri.parse(redirectUrl);
  }

  Future<String> _startPkceFlow({
    required String clientId,
    required Uri redirect,
    required String scope,
    required bool forceAccountPicker,
  }) async {
    final codeVerifier = _randomUrlSafe(32);
    final codeChallenge = _base64UrlNoPad(
      sha256.convert(utf8.encode(codeVerifier)).bytes,
    );
    final state = _randomUrlSafe(16);

    final HttpServer server;
    try {
      server = await HttpServer.bind(
        redirect.host == '::1'
            ? InternetAddress.loopbackIPv6
            : InternetAddress.loopbackIPv4,
        redirect.port,
      );
    } on SocketException catch (e) {
      throw PlatformException(
        code: 'AUTH_FAILED',
        message:
            'Could not listen on ${redirect.host}:${redirect.port} for the '
            'Spotify login (${e.message}). Is another djSports running?',
      );
    }

    try {
      final authUrl = Uri.https('accounts.spotify.com', '/authorize', {
        'client_id': clientId,
        'response_type': 'code',
        'redirect_uri': redirect.toString(),
        'scope': scope,
        'code_challenge_method': 'S256',
        'code_challenge': codeChallenge,
        'state': state,
        if (forceAccountPicker) 'show_dialog': 'true',
      });
      debugPrint('[SpotifyWindows] opening browser for Spotify login');
      if (!await launchUrl(authUrl, mode: LaunchMode.externalApplication)) {
        throw PlatformException(
          code: 'AUTH_FAILED',
          message: 'Could not open the browser for the Spotify login',
        );
      }

      final code = await _awaitAuthCode(server, redirect.path, state).timeout(
        _authTimeout,
        onTimeout: () => throw PlatformException(
          code: 'AUTH_CANCELLED',
          message: 'Spotify login timed out',
        ),
      );
      return await _exchangeCodeForToken(
        code: code,
        clientId: clientId,
        redirect: redirect,
        codeVerifier: codeVerifier,
      );
    } finally {
      unawaited(server.close(force: true));
    }
  }

  /// Waits for Spotify's redirect to [path] and answers the browser.
  /// Requests for anything else (favicon, …) get a 404 and are ignored.
  Future<String> _awaitAuthCode(
    HttpServer server,
    String path,
    String expectedState,
  ) async {
    await for (final request in server) {
      if (request.uri.path != path) {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        continue;
      }
      final params = request.uri.queryParameters;
      final error = params['error'];
      final code = params['code'];
      final ok =
          error == null && code != null && params['state'] == expectedState;
      await _respondToBrowser(
        request.response,
        ok
            ? 'Connected to Spotify. You can close this tab and go back to '
                  'djSports.'
            : 'Spotify login failed (${error ?? 'invalid response'}). '
                  'Close this tab and try again in djSports.',
      );
      if (ok) return code;
      throw PlatformException(
        code: error == 'access_denied' ? 'AUTH_CANCELLED' : 'AUTH_FAILED',
        message: 'Spotify login failed: ${error ?? 'state mismatch'}',
      );
    }
    throw PlatformException(
      code: 'AUTH_CANCELLED',
      message: 'Spotify login was cancelled',
    );
  }

  static Future<void> _respondToBrowser(
    HttpResponse response,
    String message,
  ) async {
    response.headers.contentType = ContentType.html;
    response.write(
      '<!doctype html><html><head><meta charset="utf-8">'
      '<title>djSports</title></head>'
      '<body style="font-family:sans-serif;padding:40px">'
      '<h2>djSports</h2><p>${const HtmlEscape().convert(message)}</p>'
      '</body></html>',
    );
    await response.close();
  }

  Future<String> _exchangeCodeForToken({
    required String code,
    required String clientId,
    required Uri redirect,
    required String codeVerifier,
  }) async {
    final http.Response resp;
    try {
      resp = await http.post(
        Uri.parse(_tokenUrl),
        body: {
          'grant_type': 'authorization_code',
          'code': code,
          'redirect_uri': redirect.toString(),
          'client_id': clientId,
          'code_verifier': codeVerifier,
        },
      );
    } catch (e) {
      throw PlatformException(
        code: 'TOKEN_EXCHANGE_FAILED',
        message: e.toString(),
      );
    }
    final json = _decodeMap(resp.body);
    final accessToken = json?['access_token'] as String?;
    if (resp.statusCode != 200 || accessToken == null) {
      throw PlatformException(
        code: 'TOKEN_PARSE_FAILED',
        message: 'Could not get a token: HTTP ${resp.statusCode} ${resp.body}',
      );
    }
    final refreshToken = json?['refresh_token'] as String?;
    if (refreshToken != null) {
      await _settingsPut(_refreshTokenKey, refreshToken);
    }
    _accessToken = accessToken;
    return accessToken;
  }

  /// New access token from [refreshToken], or null when Spotify refuses.
  Future<String?> _refreshAccessToken(
    String clientId,
    String refreshToken,
  ) async {
    try {
      final resp = await http.post(
        Uri.parse(_tokenUrl),
        body: {
          'grant_type': 'refresh_token',
          'refresh_token': refreshToken,
          'client_id': clientId,
        },
      );
      final json = _decodeMap(resp.body);
      final accessToken = json?['access_token'] as String?;
      if (resp.statusCode != 200 || accessToken == null) {
        debugPrint('[SpotifyWindows] refresh failed: HTTP ${resp.statusCode}');
        return null;
      }
      final newRefresh = json?['refresh_token'] as String?;
      if (newRefresh != null) await _settingsPut(_refreshTokenKey, newRefresh);
      _accessToken = accessToken;
      return accessToken;
    } catch (e) {
      debugPrint('[SpotifyWindows] refresh error: $e');
      return null;
    }
  }

  // ── PKCE helpers ────────────────────────────────────────────────────────

  static String _randomUrlSafe(int byteCount) {
    final random = math.Random.secure();
    return _base64UrlNoPad(
      List<int>.generate(byteCount, (_) => random.nextInt(256)),
    );
  }

  static String _base64UrlNoPad(List<int> bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');

  // ── connect / launch ────────────────────────────────────────────────────

  @override
  Future<bool> connectToSpotifyRemote({
    required String clientId,
    required String redirectUrl,
    required String scope,
    required String accessToken,
  }) async {
    if (await _isSpotifyRunning()) {
      _emitConnected(true);
      return true;
    }
    await _openSpotify();
    _emitConnected(true);
    return true;
  }

  /// Starts Spotify (or brings it to the front) via the `spotify:`
  /// protocol the desktop app registers.
  Future<void> _openSpotify() async {
    final ok = await launchUrl(
      Uri.parse('spotify:'),
      mode: LaunchMode.externalApplication,
    );
    if (!ok) {
      throw PlatformException(
        code: 'SPOTIFY_NOT_FOUND',
        message: 'Spotify is not installed',
      );
    }
  }

  @override
  Future<void> launchSpotify() => _openSpotify();

  @override
  Future<void> openSpotifyUri(String spotifyUri) =>
      launchUrl(Uri.parse(spotifyUri), mode: LaunchMode.externalApplication);

  /// Launches Spotify when it isn't running and waits (max ~10 s) for it
  /// to start, plus a moment so it registers as a Connect device.
  Future<void> _ensureSpotifyRunning() async {
    if (await _isSpotifyRunning()) return;
    debugPrint('[SpotifyWindows] Spotify not running — launching...');
    try {
      await _openSpotify();
    } on PlatformException catch (e) {
      debugPrint('[SpotifyWindows] ${e.message}');
      return; // let the Web API call fail with its own error
    }
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (await _isSpotifyRunning()) break;
    }
    await Future<void>.delayed(const Duration(milliseconds: 1500));
  }

  Future<bool> _isSpotifyRunning() async {
    try {
      final result = await Process.run('tasklist', [
        '/FI',
        'IMAGENAME eq Spotify.exe',
        '/NH',
      ]);
      return (result.stdout as String).toLowerCase().contains('spotify.exe');
    } catch (e) {
      debugPrint('[SpotifyWindows] tasklist failed: $e');
      return false;
    }
  }

  @override
  Future<bool?> isSpotifyRunning() => _isSpotifyRunning();

  // ── Playback via Spotify Web API ────────────────────────────────────────

  @override
  Future<SpotifyDevice?> play({
    required String spotifyUri,
    int positionMs = 0,
    String? deviceId,
  }) async {
    debugPrint(
      '[SpotifyWindows] play uri: $spotifyUri positionMs: $positionMs '
      'device: ${deviceId ?? '(active)'}',
    );
    // Only the Spotify app on this PC needs launching – not the djSports
    // player or another device.
    if (deviceId == null || deviceId == _matchedLocalId) {
      await _ensureSpotifyRunning();
    }
    return _playOnDevice(
      body: {
        'uris': [spotifyUri],
        if (positionMs > 0) 'position_ms': positionMs,
      },
      deviceId: _nonEmpty(deviceId),
    );
  }

  // The Web API play accepts position_ms inline — no muting needed.
  @override
  Future<SpotifyDevice?> playWithPosition({
    required String spotifyUri,
    int positionMs = 0,
    String? deviceId,
  }) =>
      play(spotifyUri: spotifyUri, positionMs: positionMs, deviceId: deviceId);

  @override
  Future<SpotifyDevice?> resume({String? deviceId}) =>
      _playOnDevice(body: const {}, deviceId: _nonEmpty(deviceId));

  @override
  Future<void> pause() => _command('PUT', '/me/player/pause');

  @override
  Future<void> seekTo({required int positionedMilliseconds}) =>
      _command('PUT', '/me/player/seek?position_ms=$positionedMilliseconds');

  @override
  Future<void> setVolume(int percent) =>
      _command('PUT', '/me/player/volume?volume_percent=$percent');

  /// Moves playback to [deviceId]. `play` is omitted so Spotify keeps the
  /// current play/pause state.
  @override
  Future<void> transferPlayback(String deviceId) {
    if (deviceId.isEmpty) {
      throw PlatformException(
        code: 'INVALID_ARGS',
        message: 'Missing deviceId',
      );
    }
    return _command(
      'PUT',
      '/me/player',
      body: {
        'device_ids': [deviceId],
      },
    );
  }

  /// Plays on [deviceId] when given, otherwise on the account's active
  /// device. Never silently picks a device on another machine:
  /// - 404 with no target → retry on this PC if it is in the device list,
  ///   otherwise fail with NO_ACTIVE_DEVICE (details = device list).
  /// - 404 with a target → the chosen device is gone → NO_ACTIVE_DEVICE.
  /// On success returns the device used.
  Future<SpotifyDevice?> _playOnDevice({
    required Map<String, Object> body,
    String? deviceId,
    bool isRetry = false,
  }) async {
    final path = deviceId == null
        ? '/me/player/play'
        : '/me/player/play?device_id=$deviceId';
    final resp = await _send('PUT', path, body: body);
    if (resp.statusCode == 404) {
      return _handleNoActiveDevice(
        body: body,
        requestedDeviceId: deviceId,
        isRetry: isRetry,
      );
    }
    if (resp.statusCode >= 400) throw _playerError(resp);
    return _deviceUsed(deviceId);
  }

  Future<SpotifyDevice?> _handleNoActiveDevice({
    required Map<String, Object> body,
    required String? requestedDeviceId,
    required bool isRetry,
  }) async {
    final devices = await _fetchDevices() ?? [];
    // The chosen device is listed but wasn't ready (e.g. Spotify was just
    // launched) — give it a moment and retry once.
    if (requestedDeviceId != null &&
        !isRetry &&
        devices.any((d) => d['id'] == requestedDeviceId)) {
      debugPrint(
        '[SpotifyWindows] Device $requestedDeviceId listed but not ready — '
        'retrying',
      );
      await Future<void>.delayed(const Duration(seconds: 1));
      return _playOnDevice(
        body: body,
        deviceId: requestedDeviceId,
        isRetry: true,
      );
    }
    if (requestedDeviceId == null) {
      final local = _findLocal(devices);
      final localId = local?['id'] as String?;
      if (localId != null) {
        debugPrint('[SpotifyWindows] No active device — using this PC');
        return _playOnDevice(body: body, deviceId: localId);
      }
    }
    throw PlatformException(
      code: 'NO_ACTIVE_DEVICE',
      message: requestedDeviceId == null
          ? 'No active Spotify device for this account.'
          : 'The selected Spotify device is no longer available.',
      details: devices.map(_deviceMap).toList(),
    );
  }

  /// After a successful play, which device is playing.
  Future<SpotifyDevice?> _deviceUsed(String? requestedDeviceId) async {
    final devices = await _fetchDevices() ?? [];
    final used = devices
        .where(
          (d) => requestedDeviceId != null
              ? d['id'] == requestedDeviceId
              : d['is_active'] == true,
        )
        .firstOrNull;
    final id = used?['id'] as String? ?? requestedDeviceId ?? '';
    if (id.isEmpty) return null;
    return SpotifyDevice(
      id: id,
      name: used?['name'] as String? ?? '',
      isActive: true,
    );
  }

  PlatformException _playerError(http.Response resp) {
    debugPrint('[SpotifyWindows] player error body: ${resp.body}');
    if (resp.statusCode == 403 && resp.body.contains('PREMIUM_REQUIRED')) {
      return PlatformException(
        code: 'PREMIUM_REQUIRED',
        message: 'Spotify Premium is required for playback control.',
      );
    }
    return PlatformException(
      code: 'API_ERROR',
      message:
          'HTTP ${resp.statusCode}: '
          '${resp.body.isEmpty ? '(no body)' : resp.body}',
    );
  }

  /// A player command whose result doesn't matter beyond success.
  Future<void> _command(
    String method,
    String path, {
    Map<String, Object>? body,
  }) async {
    final resp = await _send(method, path, body: body);
    if (resp.statusCode < 400) return;
    debugPrint('[SpotifyWindows] Web API error body: ${resp.body}');
    // 403 "Restriction violated": the player state doesn't allow the
    // command right now (nothing playing, already paused, …). Treat as a
    // no-op so the app doesn't show errors while Spotify is idle.
    if (resp.statusCode == 403 && resp.body.contains('Restriction violated')) {
      return;
    }
    throw _playerError(resp);
  }

  /// Sends a Web API request; throws [PlatformException] when there is no
  /// token or the request fails. Status codes are left to the caller.
  Future<http.Response> _send(
    String method,
    String path, {
    Map<String, Object>? body,
  }) async {
    final token = _accessToken;
    if (token == null) {
      throw PlatformException(
        code: 'NO_TOKEN',
        message: 'No access token available — call getAccessToken first',
      );
    }
    final request = http.Request(method, Uri.parse('$_api$path'))
      ..headers['Authorization'] = 'Bearer $token';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    try {
      final resp = await http.Response.fromStream(await request.send());
      debugPrint('[SpotifyWindows] $method $path → ${resp.statusCode}');
      return resp;
    } catch (e) {
      throw PlatformException(code: 'API_ERROR', message: e.toString());
    }
  }

  // ── Devices + profile ───────────────────────────────────────────────────

  /// Raw device objects from GET /me/player/devices, or null on failure.
  Future<List<Map<String, dynamic>>?> _fetchDevices() async {
    try {
      final resp = await _send('GET', '/me/player/devices');
      if (resp.statusCode != 200) return null;
      final devices = _decodeMap(resp.body)?['devices'];
      if (devices is! List) return null;
      return devices.whereType<Map<String, dynamic>>().toList();
    } on PlatformException {
      return null;
    }
  }

  static Map<String, Object> _deviceMap(Map<String, dynamic> device) => {
    'id': device['id'] as String? ?? '',
    'name': device['name'] as String? ?? 'Unknown',
    'type': device['type'] as String? ?? '',
    'isActive': device['is_active'] as bool? ?? false,
    'isRestricted': device['is_restricted'] as bool? ?? false,
    'volumePercent': (device['volume_percent'] as num?)?.toInt() ?? -1,
  };

  @override
  Future<List<SpotifyDevice>> getDevices() async {
    final devices = await _fetchDevices();
    if (devices == null) {
      throw PlatformException(
        code: 'API_ERROR',
        message: 'Could not load Spotify devices',
      );
    }
    _findLocal(devices); // remembers this PC's exact device name
    return devices.map((d) => SpotifyDevice.fromMap(_deviceMap(d))).toList();
  }

  @override
  Future<List<String>> getActiveDevices() async {
    final devices = await _fetchDevices() ?? [];
    return devices
        .map((d) => SpotifyDevice.fromMap(_deviceMap(d)).toString())
        .toList();
  }

  @override
  Future<Map<String, String>> getUserProfile() async {
    final resp = await _send('GET', '/me');
    final json = _decodeMap(resp.body);
    if (resp.statusCode != 200 || json == null) {
      throw PlatformException(
        code: 'PARSE_ERROR',
        message: 'Could not parse /me response (HTTP ${resp.statusCode})',
      );
    }
    return {
      'displayName': json['display_name'] as String? ?? '',
      'email': json['email'] as String? ?? '',
      'id': json['id'] as String? ?? '',
      'product': json['product'] as String? ?? '',
    };
  }

  // ── This PC ─────────────────────────────────────────────────────────────

  /// Spotify for Windows names its Connect device after the computer
  /// name, but not always in the same letter case.
  static String get _computerName =>
      Platform.environment['COMPUTERNAME'] ?? Platform.localHostname;

  /// This PC in [devices] (case-insensitive name match); remembers the
  /// exact name Spotify uses so [SpotifySession.isLocal] matches.
  Map<String, dynamic>? _findLocal(List<Map<String, dynamic>> devices) {
    final name = _computerName.toLowerCase();
    final local = devices
        .where((d) => (d['name'] as String? ?? '').toLowerCase() == name)
        .firstOrNull;
    if (local != null) {
      _matchedLocalName = local['name'] as String?;
      _matchedLocalId = local['id'] as String?;
    }
    return local;
  }

  @override
  Future<String> getLocalDeviceName() async {
    final matched = _matchedLocalName;
    if (matched != null) return matched;
    if (_accessToken != null) {
      final devices = await _fetchDevices();
      if (devices != null) _findLocal(devices);
    }
    return _matchedLocalName ?? _computerName;
  }

  // ── Volume ──────────────────────────────────────────────────────────────

  @override
  Future<double> getSystemVolume() async =>
      await FlutterVolumeController.getVolume() ?? _cachedVolume;

  /// Sets the Windows master volume and, with [spotifyToo], the active
  /// Spotify device's volume (so remote speakers follow too).
  @override
  Future<void> setSystemVolume(double volume, {bool spotifyToo = true}) async {
    _cachedVolume = volume;
    await FlutterVolumeController.setVolume(volume);
    if (!spotifyToo || _accessToken == null) return;
    await setVolume((volume * 100).round());
  }

  // ── Session / debug ─────────────────────────────────────────────────────

  @override
  Future<void> clearSession() async {
    _accessToken = null;
    _matchedLocalName = null;
    _matchedLocalId = null;
    await _settingsDelete(_refreshTokenKey);
  }

  @override
  Future<Map<String, String>> getDebugInfo() async => {
    'native.hasToken': '${_accessToken != null}',
    'native.hasRefreshToken': '${_settingsGet(_refreshTokenKey).isNotEmpty}',
    'native.localDeviceName': _matchedLocalName ?? _computerName,
    'native.clientId': _clientId ?? '',
  };

  // Handled via Web API in SpotifyRemoteRepository (needs access token).
  @override
  Future<int> getPlaybackPositionMs() async => 0;

  // ── Connection status (Spotify app running) ─────────────────────────────

  StreamController<bool>? _statusController;
  Timer? _statusTimer;
  bool? _lastRunning;

  /// Emits whether the Spotify app runs, on listen and on every change
  /// (polled every 3 s – Windows has no launch/quit notifications here).
  @override
  Stream<bool> subscribeConnectionStatus() {
    final controller = _statusController ??= StreamController<bool>.broadcast(
      onListen: _startStatusPolling,
      onCancel: _stopStatusPolling,
    );
    return controller.stream;
  }

  void _startStatusPolling() {
    _lastRunning = null;
    unawaited(_pollStatus());
    _statusTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _pollStatus(),
    );
  }

  void _stopStatusPolling() {
    _statusTimer?.cancel();
    _statusTimer = null;
  }

  Future<void> _pollStatus() async {
    final running = await _isSpotifyRunning();
    if (running != _lastRunning) _emitConnected(running);
  }

  void _emitConnected(bool connected) {
    _lastRunning = connected;
    final controller = _statusController;
    if (controller != null && controller.hasListener) controller.add(connected);
  }

  // ── djSports player (Web Playback SDK in a browser app window) ──────────

  late final _webPlayer = SpotifyWindowsWebPlayer(
    tokenProvider: _webPlayerToken,
  );

  @override
  Future<void> startWebPlayer(String name) => _webPlayer.start(name);

  @override
  Future<void> webPlayerCommand(String command, {num? value}) =>
      _webPlayer.command(command, value: value);

  @override
  Stream<Map<String, dynamic>> webPlayerEvents() => _webPlayer.events;

  /// Token for the web player: refreshed via the stored refresh token
  /// when possible, else the current one.
  Future<String?> _webPlayerToken({required bool refresh}) async {
    final clientId = _clientId;
    final refreshToken = _settingsGet(_refreshTokenKey);
    if (!refresh || clientId == null || refreshToken.isEmpty) {
      return _accessToken;
    }
    return await _refreshAccessToken(clientId, refreshToken) ?? _accessToken;
  }

  // ── macOS / iOS only ────────────────────────────────────────────────────

  @override
  Future<void> localPlayer(
    String command, {
    String? spotifyUri,
    int positionMs = 0,
  }) => throw UnsupportedError('localPlayer is macOS-only');

  @override
  Future<String> reconnectViaSpotify({
    required String clientId,
    required String redirectUrl,
  }) => throw UnsupportedError('reconnectViaSpotify is iOS-only');

  // ── Helpers ─────────────────────────────────────────────────────────────

  static String? _nonEmpty(String? value) =>
      value == null || value.isEmpty ? null : value;

  static Map<String, dynamic>? _decodeMap(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  static String _settingsGet(String key) {
    try {
      return Hive.box<dynamic>('settings').get(key) as String? ?? '';
    } catch (_) {
      return '';
    }
  }

  static Future<void> _settingsPut(String key, String value) async {
    try {
      await Hive.box<dynamic>('settings').put(key, value);
    } catch (e) {
      debugPrint('[SpotifyWindows] settings put $key failed: $e');
    }
  }

  static Future<void> _settingsDelete(String key) async {
    try {
      await Hive.box<dynamic>('settings').delete(key);
    } catch (e) {
      debugPrint('[SpotifyWindows] settings delete $key failed: $e');
    }
  }
}
