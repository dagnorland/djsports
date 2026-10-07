import Cocoa
import FlutterMacOS
import WebKit

/// Spotify Web Playback SDK running in a hidden 1×1 WKWebView inside the
/// djSports window. Makes djSports itself a Spotify Connect device, so
/// playback on this Mac doesn't depend on the Spotify desktop app.
///
/// Dart starts it with `webPlayerStart` on the Spotify method channel and
/// sends `webPlayerCommand`s; SDK events arrive on [eventChannelName].
final class SpotifyWebPlayer: NSObject {
    static let eventChannelName = "com.djsports/spotify_web_player_events"

    private static let eventHandler = "djsportsPlayer"
    private static let tokenHandler = "djsportsToken"

    /// Supplies an access token; `refresh` asks for a newly refreshed one.
    var tokenProvider: ((_ refresh: Bool, _ completion: @escaping (String?) -> Void) -> Void)?

    private weak var hostView: NSView?
    private var webView: WKWebView?
    private var eventSink: FlutterEventSink?

    func setup(messenger: FlutterBinaryMessenger, hostView: NSView) {
        self.hostView = hostView
        FlutterEventChannel(name: Self.eventChannelName, binaryMessenger: messenger)
            .setStreamHandler(self)
    }

    /// Loads (or reloads) the SDK host page. A reload registers a new device.
    func start(name: String) {
        let webView = self.webView ?? makeWebView()
        webView.loadHTMLString(
            Self.hostPage(name: name),
            baseURL: URL(string: "https://djsports.local")
        )
        emit(["event": "log", "message": "Web player starting as \"\(name)\""])
    }

    func stop() {
        webView?.evaluateJavaScript("window.djsports && window.djsports.disconnect()")
    }

    /// Runs a player command (`pause`, `resume`, `seek`, `setVolume`,
    /// `activate`). Completes when the SDK has accepted it.
    func command(_ name: String, value: Double?, result: @escaping FlutterResult) {
        guard let webView else {
            result(FlutterError(
                code: "WEB_PLAYER_NOT_STARTED",
                message: "The djSports web player is not running",
                details: nil
            ))
            return
        }
        let allowed = ["pause", "resume", "seek", "setVolume", "activate"]
        guard allowed.contains(name) else {
            result(FlutterMethodNotImplemented)
            return
        }
        let argument = value.map { String($0) } ?? "undefined"
        let script = "return await window.djsports.\(name)(\(argument));"
        webView.callAsyncJavaScript(
            script,
            arguments: [:],
            in: nil,
            in: .page
        ) { outcome in
            switch outcome {
            case .success:
                result(nil)
            case .failure(let error):
                result(FlutterError(
                    code: "WEB_PLAYER_ERROR",
                    message: error.localizedDescription,
                    details: nil
                ))
            }
        }
    }

    private func makeWebView() -> WKWebView {
        let contentController = WKUserContentController()
        contentController.add(self, name: Self.eventHandler)
        contentController.addScriptMessageHandler(
            self,
            contentWorld: .page,
            name: Self.tokenHandler
        )
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = contentController
        configuration.websiteDataStore = .nonPersistent()
        configuration.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(
            frame: CGRect(x: 0, y: 0, width: 1, height: 1),
            configuration: configuration
        )
        webView.setValue(false, forKey: "drawsBackground")
        webView.setAccessibilityElement(false)
        webView.setAccessibilityHidden(true)
        hostView?.addSubview(webView)
        self.webView = webView
        return webView
    }

    private func emit(_ event: [String: Any]) {
        eventSink?(event)
    }

    private static func hostPage(name: String) -> String {
        let jsonName = (try? String(
            data: JSONSerialization.data(withJSONObject: [name]),
            encoding: .utf8
        )) ?? "[\"djSports\"]"
        return html.replacingOccurrences(of: "__PLAYER_NAME__", with: jsonName)
    }

    private static let html = #"""
    <!doctype html>
    <html>
    <head>
      <meta charset="utf-8">
      <script src="https://sdk.scdn.co/spotify-player.js"></script>
    </head>
    <body>
    <script>
    (() => {
      const native = window.webkit.messageHandlers;
      const playerName = __PLAYER_NAME__[0];
      let player = null;

      const post = (event, payload = {}) =>
        native.djsportsPlayer.postMessage({ event, ...payload });

      const fail = (event) => ({ message }) => post(event, { message });

      window.onSpotifyWebPlaybackSDKReady = () => {
        player = new Spotify.Player({
          name: playerName,
          volume: 1.0,
          getOAuthToken: async (callback) => {
            try {
              const token = await native.djsportsToken.postMessage({});
              callback(token);
            } catch (e) {
              post('authentication_error', { message: String(e) });
            }
          },
        });
        player.addListener('ready', ({ device_id }) =>
          post('ready', { deviceId: device_id }));
        player.addListener('not_ready', ({ device_id }) =>
          post('not_ready', { deviceId: device_id }));
        player.addListener('initialization_error',
          fail('initialization_error'));
        player.addListener('authentication_error',
          fail('authentication_error'));
        player.addListener('account_error', fail('account_error'));
        player.addListener('playback_error', fail('playback_error'));
        player.addListener('autoplay_failed', () => post('autoplay_failed'));
        player.addListener('player_state_changed', (state) => {
          if (!state) return post('state', { active: false });
          const track = state.track_window && state.track_window.current_track;
          const album = (track && track.album) || {};
          // Largest cover – the panel can be resized up.
          const image = (album.images || [])
            .slice().sort((a, b) => (b.width || 0) - (a.width || 0))[0];
          post('state', {
            active: true,
            paused: state.paused,
            positionMs: state.position,
            durationMs: state.duration,
            uri: track ? track.uri : null,
            name: track ? track.name : null,
            artists: track
              ? (track.artists || []).map((a) => a.name).join(', ')
              : null,
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

      window.djsports = {
        pause: () => run(() => player.pause()),
        resume: () => run(() => player.resume()),
        seek: (ms) => run(() => player.seek(Math.round(ms))),
        setVolume: (v) =>
          run(() => player.setVolume(Math.min(1, Math.max(0, v)))),
        activate: () => run(() => player.activateElement()),
        disconnect: () => player && player.disconnect(),
      };
      post('log', { message: 'Host page loaded' });
    })();
    </script>
    </body>
    </html>
    """#
}

extension SpotifyWebPlayer: WKScriptMessageHandler {
    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard let body = message.body as? [String: Any] else { return }
        emit(body)
    }
}

extension SpotifyWebPlayer: WKScriptMessageHandlerWithReply {
    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage,
        replyHandler: @escaping (Any?, String?) -> Void
    ) {
        guard let tokenProvider else {
            replyHandler(nil, "No Spotify token")
            return
        }
        // The SDK only asks on connect and when its token is about to
        // expire, so hand it a freshly refreshed one.
        tokenProvider(true) { token in
            if let token {
                replyHandler(token, nil)
            } else {
                replyHandler(nil, "No Spotify token")
            }
        }
    }
}

extension SpotifyWebPlayer: FlutterStreamHandler {
    func onListen(
        withArguments arguments: Any?,
        eventSink events: @escaping FlutterEventSink
    ) -> FlutterError? {
        eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
}
