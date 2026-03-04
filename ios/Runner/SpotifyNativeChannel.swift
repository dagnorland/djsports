import Flutter
import UIKit

class SpotifyNativeChannel: NSObject {
    static let methodChannelName = "com.djsports/spotify_native"
    static let eventChannelName = "com.djsports/spotify_connection_events"

    private var appRemote: SPTAppRemote?
    private var sessionManager: SPTSessionManager?
    private var pendingResult: FlutterResult?
    private var eventSink: FlutterEventSink?
    private var storedSession: SPTSession?
    private var isAuthenticating = false

    private static let sessionDefaultsKey = "djsports_spotify_session"

    // MARK: - Session persistence

    private func persistSession(_ session: SPTSession) {
        do {
            let data = try NSKeyedArchiver.archivedData(
                withRootObject: session,
                requiringSecureCoding: false
            )
            UserDefaults.standard.set(data, forKey: Self.sessionDefaultsKey)
            NSLog("[Spotify] persistSession: saved (expires in %.0f s)",
                  session.expirationDate.timeIntervalSinceNow)
        } catch {
            NSLog("[Spotify] persistSession: archive failed — %@",
                  error.localizedDescription)
        }
    }

    private func loadPersistedSession() -> SPTSession? {
        guard let data = UserDefaults.standard.data(
            forKey: Self.sessionDefaultsKey
        ) else {
            NSLog("[Spotify] loadPersistedSession: nothing in UserDefaults")
            return nil
        }
        do {
            let unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
            unarchiver.requiresSecureCoding = false
            let session = unarchiver.decodeObject(
                forKey: NSKeyedArchiveRootObjectKey
            ) as? SPTSession
            if let s = session {
                NSLog("[Spotify] loadPersistedSession: restored (expires in %.0f s)",
                      s.expirationDate.timeIntervalSinceNow)
            } else {
                NSLog("[Spotify] loadPersistedSession: data present but no SPTSession decoded")
                UserDefaults.standard.removeObject(forKey: Self.sessionDefaultsKey)
            }
            return session
        } catch {
            NSLog("[Spotify] loadPersistedSession: unarchive failed — %@",
                  error.localizedDescription)
            UserDefaults.standard.removeObject(forKey: Self.sessionDefaultsKey)
            return nil
        }
    }

    private func clearPersistedSession() {
        UserDefaults.standard.removeObject(forKey: Self.sessionDefaultsKey)
        NSLog("[Spotify] clearPersistedSession: removed from UserDefaults")
    }

    func setup(messenger: FlutterBinaryMessenger) {
        storedSession = loadPersistedSession()
        let mc = FlutterMethodChannel(
            name: Self.methodChannelName,
            binaryMessenger: messenger
        )
        mc.setMethodCallHandler(handle)

        let ec = FlutterEventChannel(
            name: Self.eventChannelName,
            binaryMessenger: messenger
        )
        ec.setStreamHandler(self)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]

        switch call.method {
        case "getAccessToken":
            // Return cached token if still valid (> 5 min remaining)
            if let session = storedSession,
               session.expirationDate > Date(timeIntervalSinceNow: 300) {
                let remaining = session.expirationDate.timeIntervalSinceNow
                NSLog("[Spotify] getAccessToken: returning cached token (%.0f s remaining)", remaining)
                result(session.accessToken)
                return
            }
            // Prevent concurrent initiateSession calls
            if isAuthenticating {
                NSLog("[Spotify] getAccessToken: AUTH_IN_PROGRESS, rejecting concurrent call")
                result(FlutterError(
                    code: "AUTH_IN_PROGRESS",
                    message: "Authentication already in progress",
                    details: nil
                ))
                return
            }
            guard
                let clientId = args["clientId"] as? String,
                let redirectUrl = args["redirectUrl"] as? String,
                let redirectURL = URL(string: redirectUrl)
            else {
                NSLog("[Spotify] getAccessToken: INVALID_ARGS")
                result(FlutterError(
                    code: "INVALID_ARGS",
                    message: "Missing clientId or redirectUrl",
                    details: nil
                ))
                return
            }
            isAuthenticating = true
            pendingResult = result
            let config = SPTConfiguration(clientID: clientId, redirectURL: redirectURL)
            sessionManager = SPTSessionManager(configuration: config, delegate: self)
            let scope: SPTScope = [
                .appRemoteControl,
                .streaming,
                .userModifyPlaybackState,
                .playlistReadPrivate,
                .playlistModifyPublic,
                .userReadCurrentlyPlaying,
            ]
            if storedSession != nil {
                NSLog("[Spotify] getAccessToken: storedSession expired/near-expiry — calling renewSession()")
                sessionManager?.renewSession()
            } else {
                NSLog("[Spotify] getAccessToken: no storedSession — calling initiateSession()")
                sessionManager?.initiateSession(with: scope, options: .default, campaign: nil)
            }

        case "connect":
            guard
                let clientId = args["clientId"] as? String,
                let redirectUrl = args["redirectUrl"] as? String,
                let redirectURL = URL(string: redirectUrl),
                let accessToken = args["accessToken"] as? String
            else {
                NSLog("[Spotify] connect: INVALID_ARGS")
                result(FlutterError(
                    code: "INVALID_ARGS",
                    message: "Missing clientId, redirectUrl, or accessToken",
                    details: nil
                ))
                return
            }
            NSLog("[Spotify] connect: creating SPTAppRemote, token prefix=%@", String(accessToken.prefix(8)))
            pendingResult = result
            let config = SPTConfiguration(clientID: clientId, redirectURL: redirectURL)
            appRemote = SPTAppRemote(configuration: config, logLevel: .debug)
            appRemote?.connectionParameters.accessToken = accessToken
            appRemote?.delegate = self
            appRemote?.connect()

        case "play":
            guard let uri = args["spotifyUri"] as? String else {
                result(FlutterError(
                    code: "INVALID_ARGS",
                    message: "Missing spotifyUri",
                    details: nil
                ))
                return
            }
            guard let playerAPI = appRemote?.playerAPI else {
                result(FlutterError(
                    code: "NOT_CONNECTED",
                    message: "Spotify Remote is not connected",
                    details: "SpotifyDisconnectedException"
                ))
                return
            }
            playerAPI.play(uri) { [weak self] _, error in
                if let error = error {
                    let nsErr = error as NSError
                    let connected = self?.appRemote?.isConnected == true
                    let details = connected
                        ? "[\(nsErr.domain) \(nsErr.code)] \(error.localizedDescription)"
                        : "SpotifyDisconnectedException [\(nsErr.domain) \(nsErr.code)] \(error.localizedDescription)"
                    NSLog("[Spotify] play error: %@", details)
                    result(FlutterError(
                        code: "PLAY_ERROR",
                        message: error.localizedDescription,
                        details: details
                    ))
                } else {
                    result(nil)
                }
            }

        case "pause":
            guard let playerAPI = appRemote?.playerAPI else {
                result(FlutterError(
                    code: "NOT_CONNECTED",
                    message: "Spotify Remote is not connected",
                    details: "SpotifyDisconnectedException"
                ))
                return
            }
            playerAPI.pause { [weak self] _, error in
                if let error = error {
                    let nsErr = error as NSError
                    let connected = self?.appRemote?.isConnected == true
                    let details = connected
                        ? "[\(nsErr.domain) \(nsErr.code)] \(error.localizedDescription)"
                        : "SpotifyDisconnectedException [\(nsErr.domain) \(nsErr.code)] \(error.localizedDescription)"
                    NSLog("[Spotify] pause error: %@", details)
                    result(FlutterError(
                        code: "PAUSE_ERROR",
                        message: error.localizedDescription,
                        details: details
                    ))
                } else {
                    result(nil)
                }
            }

        case "resume":
            guard let playerAPI = appRemote?.playerAPI else {
                result(FlutterError(
                    code: "NOT_CONNECTED",
                    message: "Spotify Remote is not connected",
                    details: "SpotifyDisconnectedException"
                ))
                return
            }
            playerAPI.resume { [weak self] _, error in
                if let error = error {
                    let nsErr = error as NSError
                    let connected = self?.appRemote?.isConnected == true
                    let details = connected
                        ? "[\(nsErr.domain) \(nsErr.code)] \(error.localizedDescription)"
                        : "SpotifyDisconnectedException [\(nsErr.domain) \(nsErr.code)] \(error.localizedDescription)"
                    NSLog("[Spotify] resume error: %@", details)
                    result(FlutterError(
                        code: "RESUME_ERROR",
                        message: error.localizedDescription,
                        details: details
                    ))
                } else {
                    result(nil)
                }
            }

        case "seekTo":
            guard let position = args["positionedMilliseconds"] as? Int else {
                result(FlutterError(
                    code: "INVALID_ARGS",
                    message: "Missing positionedMilliseconds",
                    details: nil
                ))
                return
            }
            guard let playerAPI = appRemote?.playerAPI else {
                result(FlutterError(
                    code: "NOT_CONNECTED",
                    message: "Spotify Remote is not connected",
                    details: "SpotifyDisconnectedException"
                ))
                return
            }
            playerAPI.seek(toPosition: position) { [weak self] _, error in
                if let error = error {
                    let nsErr = error as NSError
                    let connected = self?.appRemote?.isConnected == true
                    let details = connected
                        ? "[\(nsErr.domain) \(nsErr.code)] \(error.localizedDescription)"
                        : "SpotifyDisconnectedException [\(nsErr.domain) \(nsErr.code)] \(error.localizedDescription)"
                    NSLog("[Spotify] seekTo error: %@", details)
                    result(FlutterError(
                        code: "SEEK_ERROR",
                        message: error.localizedDescription,
                        details: details
                    ))
                } else {
                    result(nil)
                }
            }

        case "setVolume":
            result(nil) // iOS uses system volume via flutter_volume_controller

        case "clearSession":
            NSLog("[Spotify] clearSession: clearing storedSession and disconnecting appRemote")
            storedSession = nil
            clearPersistedSession()
            isAuthenticating = false
            appRemote?.disconnect()
            appRemote = nil
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    /// Called from AppDelegate.applicationWillResignActive.
    /// Cleanly disconnects SPTAppRemote so it does not enter a zombie state
    /// while the app is in the background.
    func handleAppWillResignActive() {
        guard let remote = appRemote, remote.isConnected else { return }
        NSLog("[Spotify] handleAppWillResignActive: disconnecting appRemote")
        remote.disconnect()
    }

    /// Called from AppDelegate.applicationDidBecomeActive.
    /// Re-connects SPTAppRemote using the cached access token if the native
    /// SPTSession is still valid.  Does nothing if already connected or if
    /// there is no stored session (a full connect() call is needed instead).
    func reconnectIfNeeded() {
        guard let session = storedSession,
              session.expirationDate > Date(),
              let remote = appRemote,
              !remote.isConnected else {
            NSLog("[Spotify] reconnectIfNeeded: skipping (no session, no remote, or already connected)")
            return
        }
        NSLog("[Spotify] reconnectIfNeeded: silent reconnect (token valid for %.0f s)",
              session.expirationDate.timeIntervalSinceNow)
        remote.connectionParameters.accessToken = session.accessToken
        remote.connect()
    }

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any]
    ) -> Bool {
        sessionManager?.application(app, open: url, options: options)
        return true
    }
}

extension SpotifyNativeChannel: SPTAppRemoteDelegate {
    func appRemoteDidEstablishConnection(_ appRemote: SPTAppRemote) {
        NSLog("[Spotify] appRemoteDidEstablishConnection ✓")
        appRemote.playerAPI?.delegate = self
        // Subscribe to player state so Spotify pushes periodic updates over
        // the socket.  Without this the socket goes idle and Spotify closes it
        // after a few minutes of no API activity.
        appRemote.playerAPI?.subscribe(toPlayerState: { _, error in
            if let error = error {
                NSLog("[Spotify] subscribe playerState error: %@",
                      error.localizedDescription)
            }
        })
        pendingResult?(true)
        pendingResult = nil
        eventSink?(["connected": true])
    }

    func appRemote(
        _ appRemote: SPTAppRemote,
        didDisconnectWithError error: Error?
    ) {
        NSLog("[Spotify] appRemote didDisconnectWithError: %@",
              error?.localizedDescription ?? "no error")
        eventSink?(["connected": false])
    }

    func appRemote(
        _ appRemote: SPTAppRemote,
        didFailConnectionAttemptWithError error: Error?
    ) {
        let errMsg = error?.localizedDescription ?? "Connection failed"
        let nsErr = error as NSError?
        let domain = nsErr?.domain ?? "?"
        let code = nsErr?.code ?? -1
        NSLog("[Spotify] didFailConnectionAttemptWithError: %@ (domain=%@ code=%d)",
              errMsg, domain, code)
        // Build a details string that reaches the Flutter debug log.
        // SPTAppRemoteErrorDomain code -1000 = Spotify app not running / not foreground.
        let hint: String
        if code == -1000 || errMsg.contains("Connection attempt failed") {
            hint = "Spotify app is not running or not in the foreground. " +
                   "Open Spotify manually first, then reconnect."
        } else {
            hint = ""
        }
        let details = "[\(domain) \(code)] \(errMsg)" + (hint.isEmpty ? "" : " — \(hint)")
        pendingResult?(FlutterError(
            code: "CONNECT_FAILED",
            message: errMsg,
            details: details
        ))
        pendingResult = nil
        eventSink?(["connected": false])
    }
}

extension SpotifyNativeChannel: SPTAppRemotePlayerStateDelegate {
    func playerStateDidChange(_ playerState: SPTAppRemotePlayerState) {}
}

extension SpotifyNativeChannel: SPTSessionManagerDelegate {
    func sessionManager(manager: SPTSessionManager, didInitiate session: SPTSession) {
        let remaining = session.expirationDate.timeIntervalSinceNow
        NSLog("[Spotify] sessionManager didInitiate: token valid for %.0f s", remaining)
        storedSession = session
        persistSession(session)
        isAuthenticating = false
        pendingResult?(session.accessToken)
        pendingResult = nil
    }

    func sessionManager(manager: SPTSessionManager, didFailWith error: Error) {
        let nsErr = error as NSError
        NSLog("[Spotify] sessionManager didFailWith: %@ (domain=%@ code=%d)",
              error.localizedDescription, nsErr.domain, nsErr.code)
        isAuthenticating = false
        storedSession = nil
        clearPersistedSession()
        pendingResult?(FlutterError(
            code: "AUTH_FAILED",
            message: error.localizedDescription,
            details: error.localizedDescription
        ))
        pendingResult = nil
    }

    func sessionManager(manager: SPTSessionManager, didRenew session: SPTSession) {
        let remaining = session.expirationDate.timeIntervalSinceNow
        NSLog("[Spotify] sessionManager didRenew: token valid for %.0f s", remaining)
        storedSession = session
        persistSession(session)
        isAuthenticating = false
        pendingResult?(session.accessToken)
        pendingResult = nil
    }
}

extension SpotifyNativeChannel: FlutterStreamHandler {
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
