import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive_ce/hive.dart';

/// Windows: the Spotify Web Playback SDK in a small Chrome/Edge app
/// window, so djSports is its own Spotify Connect device ("djSports").
/// The Windows counterpart of macOS `SpotifyWebPlayer.swift`, which uses
/// a hidden WKWebView – Windows' embedded web view can't play Spotify's
/// DRM-protected audio, a real browser can.
///
/// djSports serves the SDK host page from a loopback server and talks to
/// it over a WebSocket: the page sends the same events as on macOS
/// (`ready`, `not_ready`, `state`, `log`, `*_error`) and asks for tokens;
/// djSports sends `pause`, `resume`, `seek`, `setVolume` and `activate`.
/// Every request must carry a random key known only to the page, and the
/// WebSocket only accepts the page's own origin.
class SpotifyWindowsWebPlayer {
  SpotifyWindowsWebPlayer({required this.tokenProvider});

  /// Supplies an access token; `refresh` asks for a newly refreshed one.
  final Future<String?> Function({required bool refresh}) tokenProvider;

  static const port = 43822;
  static const _origin = 'http://127.0.0.1:$port';
  static const _keySetting = 'spotifyWindowsPlayerKey';

  /// How long [start] waits for a still-open player window to reconnect
  /// before opening a new one.
  static const _reconnectGrace = Duration(seconds: 3);
  static const _commandTimeout = Duration(seconds: 5);

  final _events = StreamController<Map<String, dynamic>>.broadcast();
  HttpServer? _server;
  WebSocket? _socket;
  Completer<void>? _connected;
  String _key = '';
  String _name = 'djSports';
  String? _deviceId;
  int _nextId = 0;
  final _pending = <int, Completer<void>>{};

  /// SDK events as maps with an `event` key (same contract as macOS).
  Stream<Map<String, dynamic>> get events => _events.stream;

  /// The player's Spotify device ID while it is ready.
  String? get deviceId => _deviceId;

  /// Serves the player page and makes sure a player window is open.
  Future<void> start(String name) async {
    _name = name;
    await _ensureServer();
    if (_socket != null) {
      _log('already connected');
      // Repeat the device for the freshly listening repository.
      final id = _deviceId;
      if (id != null) _emit({'event': 'ready', 'deviceId': id});
      return;
    }
    // A player window from an earlier djSports run reconnects by itself.
    final connected = _connected ??= Completer<void>();
    try {
      await connected.future.timeout(_reconnectGrace);
      _log('player window reconnected');
      return;
    } on TimeoutException {
      // None open – start one below.
    }
    await _openWindow();
  }

  /// Runs a player command; completes when the SDK has accepted it.
  Future<void> command(String name, {num? value}) async {
    const allowed = ['pause', 'resume', 'seek', 'setVolume', 'activate'];
    if (!allowed.contains(name)) {
      throw PlatformException(
        code: 'INVALID_ARGS',
        message: 'Unknown web player command: $name',
      );
    }
    final socket = _socket;
    if (socket == null) {
      throw PlatformException(
        code: 'WEB_PLAYER_NOT_STARTED',
        message: 'The djSports player window is not open',
      );
    }
    final id = ++_nextId;
    final done = Completer<void>();
    _pending[id] = done;
    socket.add(jsonEncode({'id': id, 'cmd': name, 'value': value}));
    try {
      await done.future.timeout(_commandTimeout);
    } on TimeoutException {
      throw PlatformException(
        code: 'WEB_PLAYER_ERROR',
        message: '$name timed out',
      );
    } finally {
      _pending.remove(id);
    }
  }

  // ── Loopback server ─────────────────────────────────────────────────────

  Future<void> _ensureServer() async {
    if (_server != null) return;
    _key = _loadKey();
    try {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
      _server = server;
      server.listen(_handle, onError: (Object e) => _log('server: $e'));
    } on SocketException catch (e) {
      throw PlatformException(
        code: 'WEB_PLAYER_ERROR',
        message:
            'Port $port is in use (${e.message}). Is another djSports '
            'running?',
      );
    }
  }

  /// Kept across runs so an open player window can reconnect after a
  /// djSports restart.
  static String _loadKey() {
    final box = Hive.box<dynamic>('settings');
    final stored = box.get(_keySetting) as String? ?? '';
    if (stored.isNotEmpty) return stored;
    final random = math.Random.secure();
    final key = base64Url
        .encode(List<int>.generate(24, (_) => random.nextInt(256)))
        .replaceAll('=', '');
    unawaited(box.put(_keySetting, key));
    return key;
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    if (request.uri.queryParameters['k'] != _key) {
      response.statusCode = HttpStatus.forbidden;
      await response.close();
      return;
    }
    switch (request.uri.path) {
      case '/player':
        response.headers.contentType = ContentType.html;
        response.headers.set('Cache-Control', 'no-store');
        response.write(_hostPage(_name));
        await response.close();
      case '/ws':
        final origin = request.headers.value('origin');
        if (origin != _origin ||
            !WebSocketTransformer.isUpgradeRequest(request)) {
          response.statusCode = HttpStatus.forbidden;
          await response.close();
          return;
        }
        _attach(await WebSocketTransformer.upgrade(request));
      default:
        response.statusCode = HttpStatus.notFound;
        await response.close();
    }
  }

  void _attach(WebSocket socket) {
    // One player window at a time: a newer one replaces the old.
    unawaited(_socket?.close());
    _socket = socket;
    final connected = _connected;
    if (connected != null && !connected.isCompleted) connected.complete();
    _log('player window connected');
    socket.listen(
      (data) => _onMessage(socket, data),
      onDone: () => _detach(socket),
      onError: (Object _) => _detach(socket),
      cancelOnError: true,
    );
  }

  void _detach(WebSocket socket) {
    if (_socket != socket) return;
    _socket = null;
    _connected = null;
    for (final pending in _pending.values) {
      if (!pending.isCompleted) {
        pending.completeError(
          PlatformException(
            code: 'WEB_PLAYER_ERROR',
            message: 'The djSports player window closed',
          ),
        );
      }
    }
    _pending.clear();
    final id = _deviceId;
    _deviceId = null;
    _emit({'event': 'not_ready', 'deviceId': id ?? ''});
    _log('player window closed');
  }

  Future<void> _onMessage(WebSocket socket, Object? data) async {
    if (data is! String) return;
    final Map<String, dynamic> message;
    try {
      message = jsonDecode(data) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final reply = message['reply'];
    if (reply is int) {
      final pending = _pending[reply];
      if (pending == null || pending.isCompleted) return;
      final error = message['error'] as String?;
      if (error == null) {
        pending.complete();
      } else {
        pending.completeError(
          PlatformException(code: 'WEB_PLAYER_ERROR', message: error),
        );
      }
      return;
    }
    final tokenRequest = message['tokenRequest'];
    if (tokenRequest is int) {
      // The SDK only asks on connect and when its token is about to
      // expire, so hand it a freshly refreshed one.
      final token = await tokenProvider(refresh: true);
      socket.add(
        jsonEncode({
          'tokenReply': tokenRequest,
          'token': ?token,
          if (token == null) 'error': 'No Spotify token',
        }),
      );
      return;
    }
    final event = message['event'];
    if (event is! String) return;
    if (event == 'ready') _deviceId = message['deviceId'] as String?;
    if (event == 'not_ready') _deviceId = null;
    _emit(message);
  }

  void _emit(Map<String, dynamic> event) {
    if (_events.hasListener) _events.add(event);
  }

  void _log(String message) {
    debugPrint('[SpotifyWindows] web player $message');
    _emit({'event': 'log', 'message': message});
  }

  // ── Player window ───────────────────────────────────────────────────────

  /// Opens the page as a Chrome (else Edge) app window with its own
  /// profile, so the autoplay flag applies even when the browser already
  /// runs, and minimised windows aren't throttled.
  Future<void> _openWindow() async {
    final browser = _findBrowser();
    if (browser == null) {
      _emit({
        'event': 'initialization_error',
        'message':
            'The djSports player needs Google Chrome or Microsoft Edge. '
            'Install one of them, or choose "Spotify app" in Spotify output.',
      });
      return;
    }
    final appData =
        Platform.environment['LOCALAPPDATA'] ?? Directory.systemTemp.path;
    final profile = '$appData\\djsports\\player-${browser.$1}';
    final url = '$_origin/player?k=$_key';
    try {
      await Process.start(browser.$2, [
        '--app=$url',
        '--user-data-dir=$profile',
        '--autoplay-policy=no-user-gesture-required',
        '--disable-background-timer-throttling',
        '--disable-renderer-backgrounding',
        '--disable-backgrounding-occluded-windows',
        '--no-first-run',
        '--no-default-browser-check',
        '--window-size=460,300',
      ], mode: ProcessStartMode.detached);
      _log('opened player window (${browser.$1})');
    } on ProcessException catch (e) {
      _emit({
        'event': 'initialization_error',
        'message': 'Could not open ${browser.$1}: ${e.message}',
      });
    }
  }

  /// (name, path) of an installed Chrome or Edge, Chrome first.
  static (String, String)? _findBrowser() {
    final env = Platform.environment;
    final roots = [
      env['PROGRAMFILES'],
      env['PROGRAMFILES(X86)'],
      env['LOCALAPPDATA'],
    ].whereType<String>();
    for (final (name, relative) in [
      ('chrome', r'Google\Chrome\Application\chrome.exe'),
      ('edge', r'Microsoft\Edge\Application\msedge.exe'),
    ]) {
      for (final root in roots) {
        final path = '$root\\$relative';
        if (File(path).existsSync()) return (name, path);
      }
    }
    return null;
  }

  static String _hostPage(String name) =>
      _html.replaceAll('__PLAYER_NAME__', jsonEncode([name]));

  static const _html = r'''
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <title>djSports player</title>
  <style>
    :root { color-scheme: dark; }
    body { margin: 0; padding: 18px 20px; background: #121212;
      color: #fff; font: 14px/1.4 "Segoe UI", sans-serif; }
    h1 { font-size: 16px; margin: 0 0 6px; color: #1db954; }
    #status { color: #b3b3b3; margin-bottom: 12px; }
    #track { display: flex; gap: 12px; align-items: center; }
    #cover { width: 64px; height: 64px; border-radius: 4px;
      background: #282828; object-fit: cover; }
    #name { font-weight: 600; }
    #artists { color: #b3b3b3; }
    #hint { color: #b3b3b3; font-size: 12px; margin-top: 14px; }
    button { margin-top: 12px; padding: 8px 16px; border: 0;
      border-radius: 16px; background: #1db954; color: #000;
      font-weight: 600; cursor: pointer; display: none; }
  </style>
  <script src="https://sdk.scdn.co/spotify-player.js"></script>
</head>
<body>
  <h1>djSports player</h1>
  <div id="status">Starting…</div>
  <div id="track">
    <img id="cover" alt="">
    <div><div id="name"></div><div id="artists"></div></div>
  </div>
  <button id="enable">Enable audio</button>
  <div id="hint">Keep this window open (minimising is fine) – djSports
    plays through it.</div>
<script>
(() => {
  const playerName = __PLAYER_NAME__[0];
  const key = new URLSearchParams(location.search).get('k');
  const $ = (id) => document.getElementById(id);
  let player = null;
  let socket = null;
  let ready = null;
  let tokenId = 0;
  const tokenWaiters = new Map();
  const outbox = [];

  const status = (text) => { $('status').textContent = text; };

  const send = (message) => {
    const text = JSON.stringify(message);
    if (socket && socket.readyState === WebSocket.OPEN) socket.send(text);
    else if (!message.reply) outbox.push(text);
  };
  const post = (event, payload = {}) => send({ event, ...payload });
  const fail = (event) => ({ message }) => {
    status(event.replace('_', ' ') + ': ' + message);
    post(event, { message });
    // EME can be missing until the browser has fetched Widevine.
    if (event === 'initialization_error') setTimeout(() => location.reload(), 15000);
  };

  const connectSocket = () => {
    socket = new WebSocket('ws://' + location.host + '/ws?k=' + key);
    socket.onopen = () => {
      while (outbox.length) socket.send(outbox.shift());
      // A reconnecting djSports needs to learn the device again.
      if (ready) post('ready', { deviceId: ready });
    };
    socket.onmessage = async ({ data }) => {
      const message = JSON.parse(data);
      if (message.tokenReply !== undefined) {
        const waiter = tokenWaiters.get(message.tokenReply);
        tokenWaiters.delete(message.tokenReply);
        if (waiter) waiter(message);
        return;
      }
      try {
        await commands[message.cmd](message.value);
        send({ reply: message.id });
      } catch (e) {
        send({ reply: message.id, error: String(e && e.message || e) });
      }
    };
    socket.onclose = () => {
      socket = null;
      status('Waiting for djSports…');
      setTimeout(connectSocket, 2000);
    };
  };

  const requestToken = () => new Promise((resolve, reject) => {
    const id = ++tokenId;
    tokenWaiters.set(id, (message) =>
      message.token ? resolve(message.token) : reject(message.error));
    send({ tokenRequest: id });
  });

  window.onSpotifyWebPlaybackSDKReady = () => {
    player = new Spotify.Player({
      name: playerName,
      volume: 1.0,
      getOAuthToken: async (callback) => {
        try {
          callback(await requestToken());
        } catch (e) {
          post('authentication_error', { message: String(e) });
        }
      },
    });
    player.addListener('ready', ({ device_id }) => {
      ready = device_id;
      status('Ready as "' + playerName + '"');
      post('ready', { deviceId: device_id });
    });
    player.addListener('not_ready', ({ device_id }) => {
      ready = null;
      status('Offline – reconnecting…');
      post('not_ready', { deviceId: device_id });
    });
    player.addListener('initialization_error', fail('initialization_error'));
    player.addListener('authentication_error', fail('authentication_error'));
    player.addListener('account_error', fail('account_error'));
    player.addListener('playback_error', fail('playback_error'));
    player.addListener('autoplay_failed', () => {
      $('enable').style.display = 'inline-block';
      status('Click "Enable audio" once to allow playback');
      post('autoplay_failed');
    });
    player.addListener('player_state_changed', (state) => {
      if (!state) return post('state', { active: false });
      const track = state.track_window && state.track_window.current_track;
      const album = (track && track.album) || {};
      // Largest cover – the djSports panel can be resized up.
      const image = (album.images || [])
        .slice().sort((a, b) => (b.width || 0) - (a.width || 0))[0];
      const artists = track
        ? (track.artists || []).map((a) => a.name).join(', ')
        : null;
      $('name').textContent = track ? track.name : '';
      $('artists').textContent = artists || '';
      if (image) $('cover').src = image.url;
      status(state.paused ? 'Paused' : 'Playing');
      post('state', {
        active: true,
        paused: state.paused,
        positionMs: state.position,
        durationMs: state.duration,
        uri: track ? track.uri : null,
        name: track ? track.name : null,
        artists,
        album: album.name || null,
        imageUrl: image ? image.url : null,
      });
    });
    player.connect().then((ok) => {
      if (!ok) post('initialization_error',
        { message: 'Web Playback SDK could not connect' });
    });
  };

  const run = async (action) => {
    if (!player) throw new Error('Web player not ready');
    await action();
  };

  const commands = {
    pause: () => run(() => player.pause()),
    resume: () => run(() => player.resume()),
    seek: (ms) => run(() => player.seek(Math.round(ms))),
    setVolume: (v) =>
      run(() => player.setVolume(Math.min(1, Math.max(0, v)))),
    activate: () => run(() => player.activateElement()),
  };

  $('enable').onclick = async () => {
    await commands.activate();
    $('enable').style.display = 'none';
    status('Audio enabled');
  };
  window.addEventListener('beforeunload', () => player && player.disconnect());

  connectSocket();
  post('log', { message: 'Host page loaded' });
})();
</script>
</body>
</html>
''';
}
