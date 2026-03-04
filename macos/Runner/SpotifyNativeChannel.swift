import Cocoa
import FlutterMacOS
import AuthenticationServices
import CryptoKit

class SpotifyNativeChannel: NSObject {
    static let methodChannelName = "com.djsports/spotify_native"
    static let eventChannelName = "com.djsports/spotify_connection_events"

    private var eventSink: FlutterEventSink?
    private var authSession: ASWebAuthenticationSession?
    private var launchObserver: Any?
    private var terminateObserver: Any?

    private let refreshTokenKey = "spotify_macos_refresh_token"
    private var storedAccessToken: String?

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
            getAccessToken(args: args, result: result)
        case "connect":
            connectToSpotify(result: result)
        case "play":
            playTrack(args: args, result: result)
        case "pause":
            spotifyWebAPI(method: "PUT", path: "/me/player/pause", result: result)
        case "resume":
            resumeOnDevice(result: result)
        case "seekTo":
            seekTo(args: args, result: result)
        case "setVolume":
            let percent = args["volumePercent"] as? Int ?? 50
            setVolumeOnDevice(percent: percent, result: result)
        case "getUserProfile":
            getUserProfile(result: result)
        case "launchSpotify":
            launchSpotify(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - getAccessToken (PKCE OAuth with refresh token caching)

    private func getAccessToken(args: [String: Any], result: @escaping FlutterResult) {
        guard
            let clientId = args["clientId"] as? String,
            let redirectUrl = args["redirectUrl"] as? String,
            let scope = args["scope"] as? String
        else {
            result(FlutterError(
                code: "INVALID_ARGS",
                message: "Missing clientId, redirectUrl or scope",
                details: nil
            ))
            return
        }

        let normalizedScope = scope
            .replacingOccurrences(of: ", ", with: " ")
            .replacingOccurrences(of: ",", with: " ")

        if let refreshToken = UserDefaults.standard.string(forKey: refreshTokenKey) {
            refreshAccessToken(clientId: clientId, refreshToken: refreshToken) { [weak self] accessToken in
                if let accessToken = accessToken {
                    result(accessToken)
                } else {
                    self?.startPKCEFlow(
                        clientId: clientId,
                        redirectUrl: redirectUrl,
                        scope: normalizedScope,
                        result: result
                    )
                }
            }
        } else {
            startPKCEFlow(
                clientId: clientId,
                redirectUrl: redirectUrl,
                scope: normalizedScope,
                result: result
            )
        }
    }

    private func startPKCEFlow(
        clientId: String,
        redirectUrl: String,
        scope: String,
        result: @escaping FlutterResult
    ) {
        let codeVerifier = generateCodeVerifier()
        let codeChallenge = generateCodeChallenge(from: codeVerifier)

        var components = URLComponents(string: "https://accounts.spotify.com/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: redirectUrl),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
        ]

        guard let authURL = components.url else {
            result(FlutterError(
                code: "INVALID_URL",
                message: "Could not build Spotify auth URL",
                details: nil
            ))
            return
        }

        let callbackScheme = URL(string: redirectUrl)?.scheme ?? "djsports"

        authSession = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: callbackScheme
        ) { [weak self] callbackURL, error in
            guard let self = self else { return }

            guard let callbackURL = callbackURL, error == nil else {
                DispatchQueue.main.async {
                    result(FlutterError(
                        code: "AUTH_CANCELLED",
                        message: error?.localizedDescription ?? "Authentication cancelled",
                        details: nil
                    ))
                }
                return
            }

            guard let code = URLComponents(
                url: callbackURL,
                resolvingAgainstBaseURL: false
            )?.queryItems?.first(where: { $0.name == "code" })?.value else {
                DispatchQueue.main.async {
                    result(FlutterError(
                        code: "AUTH_FAILED",
                        message: "No authorization code in callback",
                        details: nil
                    ))
                }
                return
            }

            self.exchangeCodeForToken(
                code: code,
                clientId: clientId,
                redirectUrl: redirectUrl,
                codeVerifier: codeVerifier,
                result: result
            )
        }
        authSession?.presentationContextProvider = self
        authSession?.prefersEphemeralWebBrowserSession = false
        authSession?.start()
    }

    private func exchangeCodeForToken(
        code: String,
        clientId: String,
        redirectUrl: String,
        codeVerifier: String,
        result: @escaping FlutterResult
    ) {
        guard let tokenURL = URL(string: "https://accounts.spotify.com/api/token") else { return }

        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue(
            "application/x-www-form-urlencoded",
            forHTTPHeaderField: "Content-Type"
        )

        let params: [String: String] = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": redirectUrl,
            "client_id": clientId,
            "code_verifier": codeVerifier,
        ]
        request.httpBody = encodeFormParams(params)

        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            DispatchQueue.main.async {
                guard let data = data, error == nil else {
                    result(FlutterError(
                        code: "TOKEN_EXCHANGE_FAILED",
                        message: error?.localizedDescription,
                        details: nil
                    ))
                    return
                }
                guard
                    let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let accessToken = json["access_token"] as? String
                else {
                    result(FlutterError(
                        code: "TOKEN_PARSE_FAILED",
                        message: "Could not parse token response",
                        details: nil
                    ))
                    return
                }
                if let refreshToken = json["refresh_token"] as? String {
                    UserDefaults.standard.set(refreshToken, forKey: self?.refreshTokenKey ?? "spotify_macos_refresh_token")
                }
                self?.storedAccessToken = accessToken
                result(accessToken)
            }
        }.resume()
    }

    private func refreshAccessToken(
        clientId: String,
        refreshToken: String,
        completion: @escaping (String?) -> Void
    ) {
        guard let tokenURL = URL(string: "https://accounts.spotify.com/api/token") else {
            completion(nil)
            return
        }

        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue(
            "application/x-www-form-urlencoded",
            forHTTPHeaderField: "Content-Type"
        )

        let params: [String: String] = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": clientId,
        ]
        request.httpBody = encodeFormParams(params)

        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            DispatchQueue.main.async {
                guard
                    let data = data,
                    error == nil,
                    let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let accessToken = json["access_token"] as? String
                else {
                    completion(nil)
                    return
                }
                if let newRefresh = json["refresh_token"] as? String {
                    UserDefaults.standard.set(
                        newRefresh,
                        forKey: self?.refreshTokenKey ?? "spotify_macos_refresh_token"
                    )
                }
                self?.storedAccessToken = accessToken
                completion(accessToken)
            }
        }.resume()
    }

    // MARK: - PKCE helpers

    private func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func generateCodeChallenge(from verifier: String) -> String {
        let hash = SHA256.hash(data: Data(verifier.utf8))
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func encodeFormParams(_ params: [String: String]) -> Data? {
        return params
            .map {
                let k = $0.key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.key
                let v = $0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value
                return "\(k)=\(v)"
            }
            .joined(separator: "&")
            .data(using: .utf8)
    }

    // MARK: - connect

    private func connectToSpotify(result: @escaping FlutterResult) {
        let isRunning = !NSRunningApplication
            .runningApplications(withBundleIdentifier: "com.spotify.client")
            .isEmpty
        if isRunning {
            result(true)
            eventSink?(["connected": true])
            return
        }
        guard let spotifyURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: "com.spotify.client"
        ) else {
            result(FlutterError(
                code: "SPOTIFY_NOT_FOUND",
                message: "Spotify is not installed",
                details: nil
            ))
            return
        }
        NSWorkspace.shared.openApplication(
            at: spotifyURL,
            configuration: NSWorkspace.OpenConfiguration()
        ) { [weak self] _, error in
            DispatchQueue.main.async {
                if error == nil {
                    result(true)
                    self?.eventSink?(["connected": true])
                } else {
                    result(FlutterError(
                        code: "SPOTIFY_LAUNCH_FAILED",
                        message: error?.localizedDescription,
                        details: nil
                    ))
                }
            }
        }
    }

    // MARK: - launchSpotify: open or activate Spotify

    private func launchSpotify(result: @escaping FlutterResult) {
        // If Spotify is already running, just activate (bring to front).
        if let app = NSRunningApplication
            .runningApplications(withBundleIdentifier: "com.spotify.client")
            .first {
            app.activate(options: [.activateIgnoringOtherApps])
            result(true)
            return
        }
        // Not running — launch it.
        guard let spotifyURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: "com.spotify.client"
        ) else {
            result(FlutterError(
                code: "SPOTIFY_NOT_FOUND",
                message: "Spotify is not installed",
                details: nil
            ))
            return
        }
        NSWorkspace.shared.openApplication(
            at: spotifyURL,
            configuration: NSWorkspace.OpenConfiguration()
        ) { _, error in
            DispatchQueue.main.async {
                if let error = error {
                    result(FlutterError(
                        code: "SPOTIFY_LAUNCH_FAILED",
                        message: error.localizedDescription,
                        details: nil
                    ))
                } else {
                    result(true)
                }
            }
        }
    }

    // MARK: - Ensure Spotify is running before AppleScript

    private func ensureSpotifyRunning(then block: @escaping () -> Void) {
        let isRunning = !NSRunningApplication
            .runningApplications(withBundleIdentifier: "com.spotify.client")
            .isEmpty
        if isRunning {
            block()
            return
        }
        print("[SpotifyMacOS] Spotify not running — launching...")
        guard let url = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: "com.spotify.client"
        ) else {
            print("[SpotifyMacOS] Spotify not installed")
            block() // let the AppleScript fail with its own error
            return
        }
        NSWorkspace.shared.openApplication(
            at: url,
            configuration: NSWorkspace.OpenConfiguration()
        ) { _, error in
            if let error = error {
                print("[SpotifyMacOS] Failed to launch Spotify: \(error)")
                DispatchQueue.main.async { block() }
                return
            }
            // Wait for Spotify to finish starting before sending commands
            self.waitForSpotifyReady(attempts: 20, then: block)
        }
    }

    private func waitForSpotifyReady(attempts: Int, then block: @escaping () -> Void) {
        let isRunning = !NSRunningApplication
            .runningApplications(withBundleIdentifier: "com.spotify.client")
            .isEmpty
        if isRunning || attempts <= 0 {
            // Extra 1 s so Spotify's player API is ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { block() }
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.waitForSpotifyReady(attempts: attempts - 1, then: block)
        }
    }

    // MARK: - Playback via Spotify Web API

    private func playTrack(args: [String: Any], result: @escaping FlutterResult) {
        guard let uri = args["spotifyUri"] as? String else {
            result(FlutterError(
                code: "INVALID_ARGS",
                message: "Missing spotifyUri",
                details: nil
            ))
            return
        }
        let positionMs = args["positionMs"] as? Int
        print("[SpotifyMacOS] play called with uri: \(uri) positionMs: \(positionMs ?? 0)")
        // Ensure Spotify is running so it registers as active Web API device
        ensureSpotifyRunning {
            self.fetchDeviceThenPlay(uri: uri, positionMs: positionMs, result: result)
        }
    }

    // MARK: - Playback helpers

    private func fetchDeviceThenPlay(uri: String, positionMs: Int?, result: @escaping FlutterResult) {
        var body: [String: Any] = ["uris": [uri]]
        if let pos = positionMs, pos > 0 {
            body["position_ms"] = pos
        }
        spotifyWebAPI(method: "PUT", path: "/me/player/play", body: body, result: result)
    }

    private func resumeOnDevice(result: @escaping FlutterResult) {
        spotifyWebAPI(method: "PUT", path: "/me/player/play", result: result)
    }

    private func setVolumeOnDevice(percent: Int, result: @escaping FlutterResult) {
        spotifyWebAPI(method: "PUT", path: "/me/player/volume?volume_percent=\(percent)", result: result)
    }

    private func getUserProfile(result: @escaping FlutterResult) {
        guard let token = storedAccessToken else {
            result(FlutterError(code: "NO_TOKEN", message: "No access token", details: nil))
            return
        }
        guard let url = URL(string: "https://api.spotify.com/v1/me") else {
            result(FlutterError(code: "INVALID_URL", message: "Bad URL", details: nil))
            return
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    result(FlutterError(code: "API_ERROR", message: error.localizedDescription, details: nil))
                    return
                }
                guard
                    let data = data,
                    let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                else {
                    result(FlutterError(code: "PARSE_ERROR", message: "Could not parse /me response", details: nil))
                    return
                }
                let displayName = json["display_name"] as? String ?? ""
                let email = json["email"] as? String ?? ""
                let id = json["id"] as? String ?? ""
                let product = json["product"] as? String ?? ""
                result([
                    "displayName": displayName,
                    "email": email,
                    "id": id,
                    "product": product,
                ])
            }
        }.resume()
    }

    private func seekTo(args: [String: Any], result: @escaping FlutterResult) {
        guard let positionMs = args["positionedMilliseconds"] as? Int else {
            result(FlutterError(
                code: "INVALID_ARGS",
                message: "Missing positionedMilliseconds",
                details: nil
            ))
            return
        }
        spotifyWebAPI(method: "PUT", path: "/me/player/seek?position_ms=\(positionMs)", result: result)
    }

    // MARK: - Spotify Web API helper

    private func spotifyWebAPI(
        method: String,
        path: String,
        body: [String: Any]? = nil,
        result: @escaping FlutterResult
    ) {
        guard let token = storedAccessToken else {
            result(FlutterError(
                code: "NO_TOKEN",
                message: "No access token available — call getAccessToken first",
                details: nil
            ))
            return
        }
        guard let url = URL(string: "https://api.spotify.com/v1\(path)") else {
            result(FlutterError(code: "INVALID_URL", message: "Bad API path: \(path)", details: nil))
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body = body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }
        print("[SpotifyMacOS] Web API \(method) \(path)")
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("[SpotifyMacOS] Web API error: \(error)")
                    result(FlutterError(code: "API_ERROR", message: error.localizedDescription, details: nil))
                    return
                }
                if let http = response as? HTTPURLResponse {
                    print("[SpotifyMacOS] Web API status: \(http.statusCode)")
                    if http.statusCode >= 400 {
                        let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? "(no body)"
                        print("[SpotifyMacOS] Web API error body: \(body)")
                        result(FlutterError(code: "API_ERROR", message: "HTTP \(http.statusCode): \(body)", details: nil))
                        return
                    }
                }
                result(nil)
            }
        }.resume()
    }

    private func runAppleScript(_ script: String, result: @escaping FlutterResult) {
        print("[SpotifyMacOS] AppleScript: \(script)")
        DispatchQueue.global(qos: .userInitiated).async {
            guard let scriptObj = NSAppleScript(source: script) else {
                print("[SpotifyMacOS] AppleScript: could not create script object")
                DispatchQueue.main.async {
                    result(FlutterError(
                        code: "APPLESCRIPT_ERROR",
                        message: "Could not create AppleScript",
                        details: nil
                    ))
                }
                return
            }
            var errorInfo: NSDictionary?
            let descriptor = scriptObj.executeAndReturnError(&errorInfo)
            DispatchQueue.main.async {
                if let error = errorInfo {
                    let message = error["NSAppleScriptErrorMessage"] as? String
                        ?? error.description
                    print("[SpotifyMacOS] AppleScript error: \(error)")
                    result(FlutterError(
                        code: "APPLESCRIPT_ERROR",
                        message: message,
                        details: nil
                    ))
                } else {
                    print("[SpotifyMacOS] AppleScript OK, descriptor: \(String(describing: descriptor))")
                    result(nil)
                }
            }
        }
    }
}

// MARK: - FlutterStreamHandler

extension SpotifyNativeChannel: FlutterStreamHandler {
    func onListen(
        withArguments arguments: Any?,
        eventSink events: @escaping FlutterEventSink
    ) -> FlutterError? {
        eventSink = events

        let isRunning = !NSRunningApplication
            .runningApplications(withBundleIdentifier: "com.spotify.client")
            .isEmpty
        events(["connected": isRunning])

        launchObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard
                let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                    as? NSRunningApplication,
                app.bundleIdentifier == "com.spotify.client"
            else { return }
            self?.eventSink?(["connected": true])
        }

        terminateObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard
                let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                    as? NSRunningApplication,
                app.bundleIdentifier == "com.spotify.client"
            else { return }
            self?.eventSink?(["connected": false])
        }

        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        if let observer = launchObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            launchObserver = nil
        }
        if let observer = terminateObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            terminateObserver = nil
        }
        return nil
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension SpotifyNativeChannel: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return NSApplication.shared.windows.first ?? NSWindow()
    }
}
