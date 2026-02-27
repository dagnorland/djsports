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

    func setup(messenger: FlutterBinaryMessenger) {
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
                result(session.accessToken)
                return
            }
            // Prevent concurrent initiateSession calls
            if isAuthenticating {
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
                // Try silent renewal first
                sessionManager?.renewSession()
            } else {
                sessionManager?.initiateSession(with: scope, options: .default, campaign: nil)
            }

        case "connect":
            guard
                let clientId = args["clientId"] as? String,
                let redirectUrl = args["redirectUrl"] as? String,
                let redirectURL = URL(string: redirectUrl),
                let accessToken = args["accessToken"] as? String
            else {
                result(FlutterError(
                    code: "INVALID_ARGS",
                    message: "Missing clientId, redirectUrl, or accessToken",
                    details: nil
                ))
                return
            }
            pendingResult = result
            let config = SPTConfiguration(clientID: clientId, redirectURL: redirectURL)
            appRemote = SPTAppRemote(configuration: config, logLevel: .error)
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
            appRemote?.playerAPI?.play(uri) { _, error in
                if let error = error {
                    result(FlutterError(
                        code: "PLAY_ERROR",
                        message: error.localizedDescription,
                        details: nil
                    ))
                } else {
                    result(nil)
                }
            }

        case "pause":
            appRemote?.playerAPI?.pause { _, error in
                if let error = error {
                    result(FlutterError(
                        code: "PAUSE_ERROR",
                        message: error.localizedDescription,
                        details: nil
                    ))
                } else {
                    result(nil)
                }
            }

        case "resume":
            appRemote?.playerAPI?.resume { _, error in
                if let error = error {
                    result(FlutterError(
                        code: "RESUME_ERROR",
                        message: error.localizedDescription,
                        details: nil
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
            appRemote?.playerAPI?.seek(toPosition: position) { _, error in
                if let error = error {
                    result(FlutterError(
                        code: "SEEK_ERROR",
                        message: error.localizedDescription,
                        details: nil
                    ))
                } else {
                    result(nil)
                }
            }

        case "setVolume":
            result(nil) // iOS uses system volume via flutter_volume_controller

        default:
            result(FlutterMethodNotImplemented)
        }
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
        appRemote.playerAPI?.delegate = self
        pendingResult?(true)
        pendingResult = nil
        eventSink?(["connected": true])
    }

    func appRemote(
        _ appRemote: SPTAppRemote,
        didDisconnectWithError error: Error?
    ) {
        eventSink?(["connected": false])
    }

    func appRemote(
        _ appRemote: SPTAppRemote,
        didFailConnectionAttemptWithError error: Error?
    ) {
        pendingResult?(FlutterError(
            code: "CONNECT_FAILED",
            message: error?.localizedDescription ?? "Connection failed",
            details: nil
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
        storedSession = session
        isAuthenticating = false
        pendingResult?(session.accessToken)
        pendingResult = nil
    }

    func sessionManager(manager: SPTSessionManager, didFailWith error: Error) {
        isAuthenticating = false
        storedSession = nil  // Clear so next attempt uses initiateSession
        pendingResult?(FlutterError(
            code: "AUTH_FAILED",
            message: error.localizedDescription,
            details: nil
        ))
        pendingResult = nil
    }

    func sessionManager(manager: SPTSessionManager, didRenew session: SPTSession) {
        storedSession = session
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
