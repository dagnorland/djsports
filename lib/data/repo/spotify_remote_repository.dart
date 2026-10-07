import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:djsports/data/models/djplaylist_model.dart';
import 'package:djsports/data/models/djtrack_model.dart';
import 'package:djsports/data/models/spotify_connection_log.dart';
import 'package:djsports/data/models/spotify_device.dart';
import 'package:djsports/data/provider/spotify_credentials_provider.dart';
import 'package:djsports/data/services/spotify_platform_bridge.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:hive_ce/hive.dart';
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
    FlutterVolumeController.addListener((newVolume) {
      if ((newVolume - volume).abs() < 0.005) return;
      setVolume(newVolume);
    });
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
  String spotifyUserProduct = '';
  final ValueNotifier<String> spotifyUserIdNotifier = ValueNotifier('');
  List<String> spotifyActiveDevices = [];

  /// Who (Spotify account) and where (device) djSports plays.
  late final ValueNotifier<SpotifySession> sessionNotifier = ValueNotifier(
    SpotifySession(
      preferredDeviceId: _settingsGet(_preferredDeviceIdKey),
      preferredDeviceName: _settingsGet(_preferredDeviceNameKey),
    ),
  );
  SpotifySession get session => sessionNotifier.value;

  /// Device list from the last NO_ACTIVE_DEVICE error, for the device prompt.
  List<SpotifyDevice> lastNoDeviceCandidates = [];

  /// Set by [reGrantSpotify]; makes the next token request show Spotify's
  /// login / account picker instead of reusing the cached grant.
  bool _forceAccountPickerOnce = false;
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

  /// True while [fadeAndPausePlayer] is sweeping the volume down. Used by
  /// the UI to disable the fade button mid-fade and by [resumePlayer] to
  /// abort an in-flight fade if the user hits play before it finishes.
  final ValueNotifier<bool> fadePausingNotifier = ValueNotifier(false);

  /// Set when Spotify accepted a play command but didn't actually play it
  /// (other device kept playing, nothing loaded, …). The UI shows it.
  final ValueNotifier<String?> playIssueNotifier = ValueNotifier(null);
  int _playCheckSeq = 0;
  Timer? _fadeTimer;
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

  // ── Spotify session: account + devices ──────────────────────────────────

  static const _preferredDeviceIdKey = 'spotifyPreferredDeviceId';
  static const _preferredDeviceNameKey = 'spotifyPreferredDeviceName';

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
      debugPrint('[Spotify] settings put $key failed: $e');
    }
  }

  void _updateSession(SpotifySession Function(SpotifySession) update) {
    sessionNotifier.value = update(sessionNotifier.value);
  }

  /// Remembers [device] as the playback target (null = follow Spotify's
  /// active device). Persisted in the Hive `settings` box.
  ///
  /// A non-null [device] also moves Spotify playback there right away
  /// (keeping play/pause state). The choice is kept even if Spotify
  /// refuses the transfer; the error is rethrown so the UI can show it.
  Future<void> setPreferredDevice(SpotifyDevice? device) async {
    final id = device?.id ?? '';
    final name = device?.name ?? '';
    await _settingsPut(_preferredDeviceIdKey, id);
    await _settingsPut(_preferredDeviceNameKey, name);
    _updateSession(
      (s) => s.copyWith(preferredDeviceId: id, preferredDeviceName: name),
    );
    SpotifyConnectionLog().addSimpleEntry(
      SpotifyConnectionStatus.connectedSpotify,
      device == null
          ? 'Playback device: follow Spotify active device'
          : 'Playback device set to ${device.name} (${device.type})',
    );
    if (device == null || Platform.isAndroid) return;
    await _transferPlayback(device);
    // Give Spotify a moment to report the new active device.
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await refreshDevices();
  }

  Future<void> _transferPlayback(
    SpotifyDevice device, {
    bool retry = true,
  }) async {
    try {
      await _bridge.transferPlayback(device.id);
      SpotifyConnectionLog().addSimpleEntry(
        SpotifyConnectionStatus.connectedSpotify,
        'Transferred playback to ${device.name}',
      );
    } on PlatformException catch (e) {
      if (retry && _needsReconnect(e) && await connect()) {
        return _transferPlayback(device, retry: false);
      }
      final reason = e.message ?? e.code;
      SpotifyConnectionLog().addSimpleEntry(
        SpotifyConnectionStatus.notConnected,
        'Transfer to ${device.name} failed: $reason',
      );
      throw Exception('Spotify did not switch to ${device.name}: $reason');
    }
  }

  /// Reloads the device list, this machine's name and (macOS) whether
  /// Spotify is running. Safe to call often; errors are logged only.
  Future<void> refreshDevices() async {
    if (Platform.isAndroid) return;
    String localName = session.localDeviceName;
    bool? running;
    try {
      if (localName.isEmpty) localName = await _bridge.getLocalDeviceName();
      running = await _bridge.isSpotifyRunning();
    } catch (e) {
      debugPrint('[Spotify] local device info failed: $e');
    }
    if (!hasSpotifyAccessToken) {
      _updateSession(
        (s) => s.copyWith(
          connected: false,
          localDeviceName: localName,
          localSpotifyRunning: running,
        ),
      );
      return;
    }
    try {
      final devices = await _bridge.getDevices();
      spotifyActiveDevices = devices.map((d) => d.toString()).toList();
      _updateSession(
        (s) => s.copyWith(
          connected: true,
          devices: devices,
          devicesLoaded: true,
          localDeviceName: localName,
          localSpotifyRunning: running,
        ),
      );
    } catch (e) {
      debugPrint('[Spotify] refreshDevices failed: $e');
      _updateSession(
        (s) => s.copyWith(
          localDeviceName: localName,
          localSpotifyRunning: running,
        ),
      );
    }
  }

  void _setAccount(Map<String, String> profile) {
    spotifyUserDisplayName = profile['displayName'] ?? '';
    spotifyUserEmail = profile['email'] ?? '';
    spotifyUserId = profile['id'] ?? '';
    spotifyUserProduct = profile['product'] ?? '';
    spotifyUserIdNotifier.value = spotifyUserId;
    _updateSession(
      (s) =>
          s.copyWith(connected: true, account: SpotifyAccount.fromMap(profile)),
    );
  }

  void _clearSessionState({bool clearPreferredDevice = false}) {
    spotifyUserDisplayName = '';
    spotifyUserEmail = '';
    spotifyUserId = '';
    spotifyUserProduct = '';
    spotifyUserIdNotifier.value = '';
    spotifyActiveDevices = [];
    lastNoDeviceCandidates = [];
    _updateSession(
      (s) => SpotifySession(
        localDeviceName: s.localDeviceName,
        localSpotifyRunning: s.localSpotifyRunning,
        preferredDeviceId: clearPreferredDevice ? '' : s.preferredDeviceId,
        preferredDeviceName: clearPreferredDevice ? '' : s.preferredDeviceName,
      ),
    );
    if (clearPreferredDevice) {
      unawaited(_settingsPut(_preferredDeviceIdKey, ''));
      unawaited(_settingsPut(_preferredDeviceNameKey, ''));
    }
  }

  /// Device for the next play only (from the play-time prompt).
  String? _oneShotDeviceId;

  /// Sends the next play/resume to [device] once, without remembering it.
  void playNextOn(SpotifyDevice device) => _oneShotDeviceId = device.id;

  /// `device_id` for the next play: the one-off pick, else the device the
  /// user explicitly set, else null = follow Spotify's active device.
  String? _takeTargetDeviceId() {
    final oneShot = _oneShotDeviceId;
    _oneShotDeviceId = null;
    if (oneShot != null) return oneShot;
    return session.preferredDeviceId.isEmpty ? null : session.preferredDeviceId;
  }

  /// Records where a play actually went and logs "who → where". With
  /// [requestedUri], also checks shortly after what Spotify really plays.
  void _recordPlayed(
    SpotifyDevice? used, {
    String? requestedUri,
    String? requestedDeviceId,
  }) {
    if (requestedUri != null) {
      unawaited(_verifyPlayback(requestedUri, requestedDeviceId));
    }
    if (used == null) return;
    final known = session.devices.where((d) => d.id == used.id).firstOrNull;
    final device = known ?? used;
    _updateSession(
      (s) => s.copyWith(
        lastPlayedDevice: device,
        devices: [
          for (final d in s.devices)
            SpotifyDevice(
              id: d.id,
              name: d.name,
              type: d.type,
              isActive: d.id == device.id,
              isRestricted: d.isRestricted,
              volumePercent: d.volumePercent,
            ),
        ],
      ),
    );
    final who = session.account?.label ?? '?';
    SpotifyConnectionLog().addSimpleEntry(
      SpotifyConnectionStatus.connectedSpotifyRemoteApp,
      'Playing on ${device.name.isEmpty ? device.id : device.name} as $who',
    );
  }

  /// A 204 from `PUT /me/player/play` only means "command accepted". Ask
  /// Spotify ~1.5 s later what is actually playing, log it, and publish a
  /// user-facing message on [playIssueNotifier] when the play didn't land:
  /// another device kept playing, or nothing / another track was loaded.
  Future<void> _verifyPlayback(
    String requestedUri,
    String? requestedDeviceId,
  ) async {
    if (Platform.isAndroid || lastValidAccessToken.isEmpty) return;
    final seq = ++_playCheckSeq;
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    // A newer play started meanwhile – its own check will report.
    if (seq != _playCheckSeq) return;
    final requestedName = _deviceName(requestedDeviceId);
    try {
      final resp = await http.get(
        Uri.parse('https://api.spotify.com/v1/me/player?market=from_token'),
        headers: {'Authorization': 'Bearer $lastValidAccessToken'},
      );
      final String report;
      String? issue;
      if (resp.statusCode == 204 || resp.body.isEmpty) {
        report = 'nothing playing (no active device / no player state)';
        issue =
            'Spotify accepted the command but nothing is playing'
            '${requestedName == null ? '' : ' on "$requestedName"'}. '
            'Check that the device can be controlled from the Spotify app '
            'on your phone.';
      } else if (resp.statusCode != 200) {
        report = 'HTTP ${resp.statusCode}: ${resp.body}';
      } else {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final device = data['device'] as Map<String, dynamic>? ?? {};
        final deviceId = device['id'] as String? ?? '';
        final deviceName = device['name'] as String? ?? '?';
        final item = data['item'] as Map<String, dynamic>?;
        final linkedFrom =
            (item?['linked_from'] as Map<String, dynamic>?)?['uri'];
        final itemMatches =
            item != null &&
            (item['uri'] == requestedUri || linkedFrom == requestedUri);
        final deviceSwitched =
            requestedDeviceId == null || deviceId == requestedDeviceId;
        final disallows =
            (data['actions'] as Map<String, dynamic>?)?['disallows']
                as Map<String, dynamic>? ??
            {};
        final context = data['context'] as Map<String, dynamic>?;
        report = [
          'device=$deviceName (active=${device['is_active']}, '
              'restricted=${device['is_restricted']})',
          'is_playing=${data['is_playing']}',
          'progress_ms=${data['progress_ms']}',
          'type=${data['currently_playing_type']}',
          'context=${context?['uri'] ?? 'none'}',
          'disallows=${disallows.keys.join(',')}',
          if (item == null)
            'item=NONE (track not loaded)'
          else ...[
            'item=${item['name']} ${item['uri']}',
            'is_playable=${item['is_playable']}',
            if (linkedFrom != null) 'linked_from=$linkedFrom',
          ],
          if (!deviceSwitched)
            '⚠️ device NOT switched (requested ${requestedName ?? requestedDeviceId})'
          else if (!itemMatches)
            '⚠️ requested track not loaded ($requestedUri)',
        ].join(' | ');
        if (!deviceSwitched) {
          issue =
              'Spotify did not switch to "$requestedName" – it is '
              'still playing on "$deviceName". Check that '
              '"$requestedName" can be controlled from the Spotify app on '
              'your phone.';
        } else if (!itemMatches) {
          issue =
              Platform.isMacOS &&
                  !macLocalControlNotifier.value &&
                  _isThisMac(deviceId)
              ? 'Spotify for Mac accepted the command but did not start '
                    'the track. Turn on "Control Spotify on this Mac '
                    'directly" in Spotify output.'
              : 'Spotify on "$deviceName" accepted the command but did '
                    'not start the track. Try restarting the Spotify app '
                    'there (Cmd+Q on a Mac) or choose another device.';
        }
      }
      debugPrint('[PLAY-CHECK] $report');
      SpotifyConnectionLog().addSimpleEntry(
        SpotifyConnectionStatus.connectedSpotifyRemoteApp,
        'Play check: $report',
      );
      if (issue != null) _reportPlayIssue(issue);
    } catch (e) {
      debugPrint('[PLAY-CHECK] failed: $e');
    }
  }

  void _reportPlayIssue(String issue) {
    // Re-assign through null so the same message fires again.
    playIssueNotifier.value = null;
    playIssueNotifier.value = issue;
  }

  // ── macOS local control (AppleScript) ───────────────────────────────────

  static const _macLocalControlKey = 'spotifyMacLocalControl';

  /// macOS: play/pause/resume on Spotify for THIS Mac via AppleScript
  /// instead of the Web API (default on). Faster, and works when Spotify
  /// for Mac accepts Web API plays without loading the track. Other devices
  /// always use the Web API. Persisted in the Hive `settings` box.
  late final ValueNotifier<bool> macLocalControlNotifier = ValueNotifier(
    Platform.isMacOS && _settingsGet(_macLocalControlKey) != 'off',
  );

  Future<void> setMacLocalControl(bool enabled) async {
    macLocalControlNotifier.value = enabled;
    await _settingsPut(_macLocalControlKey, enabled ? 'on' : 'off');
    SpotifyConnectionLog().addSimpleEntry(
      SpotifyConnectionStatus.connectedSpotify,
      'Control Spotify on this Mac directly: ${enabled ? 'on' : 'off'}',
    );
  }

  bool _isThisMac(String deviceId) {
    final known = session.devices.where((d) => d.id == deviceId).firstOrNull;
    return known != null && session.isLocal(known);
  }

  /// Whether a command for [deviceId] (null = Spotify's active device)
  /// should go to Spotify on this Mac via AppleScript.
  bool _useLocalControl(String? deviceId) {
    if (!Platform.isMacOS || !macLocalControlNotifier.value) return false;
    if (deviceId != null) return _isThisMac(deviceId);
    final current = session.activeDevice ?? session.lastPlayedDevice;
    return current == null || session.isLocal(current);
  }

  /// Runs [command] via AppleScript. Returns false (after telling the user
  /// once) when AppleScript fails, so the caller can use the Web API.
  Future<bool> _tryLocal(
    String command, {
    String? spotifyUri,
    int positionMs = 0,
  }) async {
    try {
      await _bridge.localPlayer(
        command,
        spotifyUri: spotifyUri,
        positionMs: positionMs,
      );
      return true;
    } on PlatformException catch (e) {
      debugPrint('[PLAY] AppleScript $command failed: ${e.message}');
      SpotifyConnectionLog().addSimpleEntry(
        SpotifyConnectionStatus.notConnected,
        'AppleScript $command failed (${e.message}) – using Web API',
      );
      if (!_localFailureReported) {
        _localFailureReported = true;
        _reportPlayIssue(
          'Could not control Spotify on this Mac directly (${e.message}). '
          'Using the Spotify Web API instead. Allow djSports in System '
          'Settings → Privacy & Security → Automation.',
        );
      }
      return false;
    }
  }

  bool _localFailureReported = false;

  Future<SpotifyDevice?> _playOn(
    String spotifyUri,
    String? deviceId, {
    int? positionMs,
  }) async {
    if (_useLocalControl(deviceId)) {
      debugPrint('[PLAY] via AppleScript (local control)');
      final ok = await _tryLocal(
        'play',
        spotifyUri: spotifyUri,
        positionMs: positionMs ?? 0,
      );
      if (ok) return session.localDevice;
    }
    if (positionMs == null) {
      return _bridge.play(spotifyUri: spotifyUri, deviceId: deviceId);
    }
    return _bridge.playWithPosition(
      spotifyUri: spotifyUri,
      positionMs: positionMs,
      deviceId: deviceId,
    );
  }

  Future<void> _pause() async {
    if (_useLocalControl(null) && await _tryLocal('pause')) return;
    await _bridge.pause();
  }

  Future<SpotifyDevice?> _resume(String? deviceId) async {
    if (_useLocalControl(deviceId) && await _tryLocal('resume')) {
      return session.localDevice;
    }
    return _bridge.resume(deviceId: deviceId);
  }

  String? _deviceName(String? id) {
    if (id == null) return null;
    final known = session.devices.where((d) => d.id == id).firstOrNull;
    if (known != null) return known.name;
    if (id == session.preferredDeviceId && session.preferredDeviceName != '') {
      return session.preferredDeviceName;
    }
    return id;
  }

  /// Maps device / Premium errors to result strings the UI recognises:
  /// `[Error][NoDevice] …` (see [lastNoDeviceCandidates]) and
  /// `[Error][Premium] …`. Both keep the `[Error]` prefix so older callers
  /// still treat them as failures.
  String? _classifyPlayError(PlatformException e) {
    if (e.code == 'NO_ACTIVE_DEVICE') {
      final raw = e.details;
      lastNoDeviceCandidates = raw is List
          ? raw
                .whereType<Map<dynamic, dynamic>>()
                .map(SpotifyDevice.fromMap)
                .toList()
          : [];
      _updateSession(
        (s) => s.copyWith(devices: lastNoDeviceCandidates, devicesLoaded: true),
      );
      SpotifyConnectionLog().addSimpleEntry(
        SpotifyConnectionStatus.connectedSpotify,
        'No usable Spotify device: ${e.message} '
        '(${lastNoDeviceCandidates.length} available)',
      );
      return '[Error][NoDevice] ${e.message ?? 'No Spotify device available'}';
    }
    if (e.code == 'PREMIUM_REQUIRED') {
      return '[Error][Premium] ${e.message ?? 'Spotify Premium is required'}';
    }
    return null;
  }

  /// Returns the current Spotify playback position in milliseconds.
  /// Polls the Spotify Web API on iOS/macOS; uses the SDK on Android.
  Future<int> getPlaybackPositionMs() async {
    if (!hasSpotifyAccessToken || lastValidAccessToken.isEmpty) return 0;
    if (Platform.isAndroid) return _bridge.getPlaybackPositionMs();
    try {
      final resp = await http.get(
        Uri.parse('https://api.spotify.com/v1/me/player'),
        headers: {'Authorization': 'Bearer $lastValidAccessToken'},
      );
      if (resp.statusCode == 200 && resp.body.isNotEmpty) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return (data['progress_ms'] as num?)?.toInt() ?? 0;
      }
    } catch (_) {}
    return 0;
  }

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
        debugPrint(
          'forceFullReconnect: step 2 failed (${e.code}): ${e.message}',
        );
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
    _clearSessionState(clearPreferredDevice: true);
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
    _clearSessionState(clearPreferredDevice: true);
    _forceAccountPickerOnce = true;
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

  /// Writes [v] to system volume during a fade sweep.
  ///
  /// Always routes through [SpotifyPlatformBridge.setSystemVolume] so the
  /// fade hits the same code path as [adjustVolume] (the +/- buttons).
  /// On macOS that means the call fans out to BOTH:
  ///   1. `FlutterVolumeController.setVolume(v)` — macOS system master.
  ///   2. The native `setVolume` channel → Spotify Web API
  ///      `PUT /me/player/volume` → Spotify Connect **device** volume.
  ///
  /// `FlutterVolumeController` on macOS can silently no-op when the app
  /// isn't holding focus or when the package's CoreAudio control is
  /// blocked, in which case the Web API leg is what actually fades the
  /// audio. Calling both keeps the volume indicator (which mirrors
  /// the Mac master via [FlutterVolumeController.addListener]) and the
  /// Spotify device slider in lock-step with the heard audio.
  Future<void> _setFadeStepVolume(double v) async {
    final clamped = v.clamp(0.0, 1.0);
    // Update Dart-side state BEFORE the system write so the system-volume
    // listener (registered in _initVolume) sees |new - current| < 0.005
    // and skips re-entering setVolume().
    volume = clamped;
    volumeNotifier.value = clamped;
    await _bridge.setSystemVolume(clamped);
  }

  /// Cancels any in-flight fade timer without restoring volume.
  /// Safe to call when no fade is running.
  void cancelFade() {
    _fadeTimer?.cancel();
    _fadeTimer = null;
    fadePausingNotifier.value = false;
  }

  /// Smoothly fades the system volume to zero over [fadeDuration], then
  /// pauses Spotify. The pre-fade volume is captured into [_preMuteVolume]
  /// and [_isMuted] is set to `true`, so the existing [resumePlayer] path
  /// (which calls `_unMute()`) restores the original level on the next
  /// play/resume across all three platforms.
  ///
  /// Platform notes:
  ///   * Android — system volume is a 15-step discrete ladder. Fades shorter
  ///     than ~750 ms will sound stepped.
  ///   * iOS — pause is implemented as a silence keep-alive track (see
  ///     `ios/Runner/SpotifyNativeChannel.swift`). We fade BEFORE switching
  ///     to silence so the keep-alive never plays audibly.
  ///   * macOS — each step hits the Spotify Web API (via the native
  ///     `setVolume` channel → `PUT /me/player/volume`), so we use a
  ///     longer step interval (~120 ms) to avoid timer pile-up and Web
  ///     API rate limits.
  Future<bool> fadeAndPausePlayer(Duration fadeDuration) async {
    final totalMs = fadeDuration.inMilliseconds;
    if (totalMs <= 0) {
      // No fade configured — fall back to instant pause.
      return pausePlayer();
    }

    // Cancel any prior fade so two rapid fade-pauses don't stack timers.
    _fadeTimer?.cancel();
    _fadeTimer = null;

    // Snapshot the current volume so resume can restore it. Prefer the live
    // system reading over our cached [volume] field — the user may have
    // adjusted the OS slider since the last [setVolume] notification.
    double startVolume;
    try {
      startVolume = await _bridge.getSystemVolume();
    } catch (_) {
      startVolume = volume;
    }
    if (startVolume <= 0.001) {
      // Already silent — just pause without sweeping.
      return pausePlayer();
    }

    _preMuteVolume = startVolume;
    _isMuted = true; // ensures resumePlayer → _unMute restores volume
    fadePausingNotifier.value = true;

    // Step cadence:
    //   * Android/iOS — local system volume API, cheap. Aim for ~20 steps,
    //     20–60 ms between steps so the sweep is smooth.
    //   * macOS — each step also fires a Spotify Web API call. Use 100–200 ms
    //     intervals so we don't pile up HTTP requests on the timer (still
    //     gives a ~10–15 step ramp for a 1.5 s fade, which the Mac mixer
    //     interpolates audibly).
    final int stepMs;
    if (Platform.isMacOS) {
      stepMs = (totalMs ~/ 10).clamp(100, 200);
    } else {
      stepMs = (totalMs ~/ 20).clamp(20, 60);
    }
    final stepCount = math.max(1, totalMs ~/ stepMs);
    final completer = Completer<bool>();
    int step = 0;
    bool finalizing = false; // guards against re-entry if a tick fires while
    // the final pause() is still awaiting.

    SpotifyConnectionLog().addSimpleEntry(
      SpotifyConnectionStatus.connectedSpotifyRemoteApp,
      'Fade-pause start: ${totalMs}ms, $stepCount steps @ ${stepMs}ms, '
      'from ${(startVolume * 100).round()}%',
    );

    _fadeTimer = Timer.periodic(Duration(milliseconds: stepMs), (timer) async {
      if (finalizing) return;
      step++;
      // Linear ramp. (A perceptual / exponential curve could be added later
      // if users report the linear curve sounds too back-loaded.)
      final fraction = (step / stepCount).clamp(0.0, 1.0);
      final newVolume = startVolume * (1.0 - fraction);

      if (step >= stepCount) {
        finalizing = true;
        timer.cancel();
        _fadeTimer = null;
        try {
          // Final step: make sure system volume is exactly zero. This goes
          // through the same _bridge.setSystemVolume path as every other
          // step, so on macOS the Spotify Web API leg fires here too — no
          // extra sync call is needed.
          await _setFadeStepVolume(0);
          // Execute the platform pause. On Android we don't call _mute()
          // here because the volume is already at 0 from the sweep.
          await _pause();
          if (Platform.isIOS) silencePlayingNotifier.value = true;
          isPlaying = false;
          SpotifyConnectionLog().addSimpleEntry(
            SpotifyConnectionStatus.connectedSpotifyRemoteApp,
            'Fade-pause complete (${totalMs}ms)',
          );
        } catch (e) {
          debugPrint('fadeAndPausePlayer: pause failed: $e');
        } finally {
          fadePausingNotifier.value = false;
          if (!completer.isCompleted) completer.complete(isPlaying);
        }
      } else {
        try {
          await _setFadeStepVolume(newVolume);
        } catch (e) {
          debugPrint('fadeAndPausePlayer: step $step failed: $e');
        }
      }
    });

    return completer.future;
  }

  /// Hard pause — like [pausePlayer] but does NOT start silence keep-alive on
  /// iOS. Icon will show white (fully paused).
  Future<bool> hardPausePlayer() async {
    final result = await pausePlayer();
    silencePlayingNotifier.value = false;
    return result;
  }

  Future<bool> pausePlayer() async {
    try {
      if (Platform.isAndroid) {
        _preMuteVolume = volume;
        await _mute();
      }
      await _pause();
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
          await _pause();
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
    // If the user hits play mid-fade, abort the sweep so we don't keep
    // muting after resume kicks in.
    cancelFade();
    try {
      _recordPlayed(await _resume(_takeTargetDeviceId()));
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
          _recordPlayed(await _resume(_takeTargetDeviceId()));
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
    if (track.spotifyUri.isEmpty) {
      debugPrint('[PLAY] Blocked: empty spotifyUri');
      return '[Error] Track has no Spotify URI';
    }
    if (!hasSpotifyAccessToken || !lastValidAccessToken.isNotEmpty) {
      debugPrint('[PLAY] Blocked: not connected');
      return '[Error] Not connected to Spotify';
    }
    final startTime = DateTime.now();
    try {
      debugPrint(
        '[PLAY] Calling bridge.playWithPosition uri=${track.spotifyUri}',
      );
      final targetDeviceId = _takeTargetDeviceId();
      final positionMs = jumpStart > 0 ? jumpStart : 0;
      _recordPlayed(
        await _playOn(track.spotifyUri, targetDeviceId, positionMs: positionMs),
        requestedUri: track.spotifyUri,
        requestedDeviceId: targetDeviceId,
      );
      // Restore volume if a prior pause (regular Android mute or any
      // platform's fade-pause) left us muted. On Android the native bridge
      // already runs its own mute/seek/restore-to-savedVolume during the
      // call above, so this unmute pins the final level to the user's
      // actual pre-pause volume rather than the bridge's fallback default.
      cancelFade();
      if (_isMuted) await _unMute();
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
      final classified = _classifyPlayError(platformException);
      if (classified != null) return classified;
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
      final targetDeviceId = _takeTargetDeviceId();
      _recordPlayed(
        await _playOn(spotifyUri, targetDeviceId, positionMs: jumpStart),
        requestedUri: spotifyUri,
        requestedDeviceId: targetDeviceId,
      );
      if (jumpStart > 0) {
        latestDurationStartupMS = DateTime.now()
            .difference(startTime)
            .inMilliseconds;
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
      final classified = _classifyPlayError(platformException);
      if (classified != null) return classified;
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
      final targetDeviceId = _takeTargetDeviceId();
      _recordPlayed(
        await _playOn(spotifyUri, targetDeviceId),
        requestedUri: spotifyUri,
        requestedDeviceId: targetDeviceId,
      );
      SpotifyConnectionLog().addSimpleEntry(
        SpotifyConnectionStatus.connectedSpotifyRemoteApp,
        'play track $spotifyUri',
      );
      return '[Success] Playing track $spotifyUri';
    } on PlatformException catch (platformException) {
      debugPrint('Failed to play. details: ${platformException.details}');
      debugPrint('Failed to play. code: ${platformException.code}');
      debugPrint('Failed to play. message: ${platformException.message}');
      final classified = _classifyPlayError(platformException);
      if (classified != null) return classified;
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
            _bridge.getUserProfile().then(_setAccount).catchError((
              Object error,
            ) {
              debugPrint('Failed to get user profile: $error');
            }),
          );
        }
        unawaited(refreshDevices());
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
        _setAccount({
          'displayName': data['display_name'] as String? ?? '',
          'email': data['email'] as String? ?? '',
          'id': data['id'] as String? ?? '',
          'product': data['product'] as String? ?? '',
        });
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
        'user-read-email',
        'playlist-read-private',
        'playlist-modify-public',
        'user-read-currently-playing',
      ];
      final forceAccountPicker = _forceAccountPickerOnce;
      _forceAccountPickerOnce = false;
      var accessToken = await _bridge.getAccessToken(
        forceAccountPicker: forceAccountPicker,
        clientId: _credentials.clientId ?? '',
        redirectUrl: _spotifyRedirectUrl,
        scope:
            'streaming, '
            'user-modify-playback-state, '
            'user-read-playback-state, '
            'user-read-private, '
            'user-read-email, '
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
            'user-read-email, '
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
  // Watching means the repository is rebuilt when the user saves their
  // own Client ID (Bring Your Own Client ID) in the settings screen.
  final creds = ref.watch(spotifyCredentialsProvider);

  SpotifyApiCredentials credentials = SpotifyApiCredentials(
    creds.clientId,
    creds.clientSecret,
  );
  credentials.scopes = [];

  return SpotifyRemoteRepository(credentials, creds.redirectUrl);
});
