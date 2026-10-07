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
    /// Client ID from the last `getAccessToken`, for silent refreshes.
    private var clientId: String?

    /// The in-app Spotify Web Playback SDK player (see SpotifyWebPlayer).
    let webPlayer = SpotifyWebPlayer()

    func setup(messenger: FlutterBinaryMessenger, hostView: NSView) {
        webPlayer.setup(messenger: messenger, hostView: hostView)
        webPlayer.tokenProvider = { [weak self] refresh, completion in
            self?.webPlayerToken(refresh: refresh, completion: completion)
        }

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
            resumeOnDevice(args: args, result: result)
        case "seekTo":
            seekTo(args: args, result: result)
        case "setVolume":
            let percent = args["volumePercent"] as? Int ?? 50
            setVolumeOnDevice(percent: percent, result: result)
        case "getUserProfile":
            getUserProfile(result: result)
        case "getActiveDevices":
            getActiveDevices(result: result)
        case "getDevices":
            getDevices(result: result)
        case "transferPlayback":
            transferPlayback(args: args, result: result)
        case "localPlayer":
            localPlayer(args: args, result: result)
        case "webPlayerStart":
            webPlayer.start(name: args["name"] as? String ?? "djSports")
            result(nil)
        case "webPlayerStop":
            webPlayer.stop()
            result(nil)
        case "webPlayerCommand":
            webPlayer.command(
                args["command"] as? String ?? "",
                value: (args["value"] as? NSNumber)?.doubleValue,
                result: result
            )
        case "getLocalDeviceName":
            result(localDeviceName)
        case "isSpotifyRunning":
            result(!NSRunningApplication
                .runningApplications(withBundleIdentifier: "com.spotify.client")
                .isEmpty)
        case "getDebugInfo":
            result([
                "native.hasToken": storedAccessToken != nil,
                "native.hasRefreshToken": UserDefaults.standard.string(
                    forKey: refreshTokenKey
                ) != nil,
                "native.localDeviceName": localDeviceName,
            ])
        case "clearSession":
            storedAccessToken = nil
            UserDefaults.standard.removeObject(forKey: refreshTokenKey)
            result(nil)
        case "launchSpotify":
            launchSpotify(result: result)
        case "openUri":
            openUri(args: args, result: result)
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

        self.clientId = clientId
        let normalizedScope = scope
            .replacingOccurrences(of: ", ", with: " ")
            .replacingOccurrences(of: ",", with: " ")

        // Account switch: skip the cached refresh token and force Spotify to
        // show its login / account picker instead of silently reusing the
        // browser's existing Spotify session.
        if args["forceAccountPicker"] as? Bool == true {
            storedAccessToken = nil
            UserDefaults.standard.removeObject(forKey: refreshTokenKey)
            startPKCEFlow(
                clientId: clientId,
                redirectUrl: redirectUrl,
                scope: normalizedScope,
                forceAccountPicker: true,
                result: result
            )
            return
        }

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
        forceAccountPicker: Bool = false,
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
        if forceAccountPicker {
            components.queryItems?.append(
                URLQueryItem(name: "show_dialog", value: "true")
            )
        }

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
        authSession?.prefersEphemeralWebBrowserSession = forceAccountPicker
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

    /// Token for the web player: refreshed via the stored refresh token
    /// when possible, else the current one.
    private func webPlayerToken(
        refresh: Bool,
        completion: @escaping (String?) -> Void
    ) {
        guard
            refresh,
            let clientId,
            let refreshToken = UserDefaults.standard.string(forKey: refreshTokenKey)
        else {
            completion(storedAccessToken)
            return
        }
        refreshAccessToken(clientId: clientId, refreshToken: refreshToken) {
            [weak self] token in
            completion(token ?? self?.storedAccessToken)
        }
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

    private func openUri(args: [String: Any], result: @escaping FlutterResult) {
        guard let uriString = args["uri"] as? String, !uriString.isEmpty else {
            result(FlutterError(code: "INVALID_ARGS", message: "Missing uri", details: nil))
            return
        }
        guard let url = URL(string: uriString) else {
            result(FlutterError(code: "INVALID_URI", message: "Cannot parse: \(uriString)", details: nil))
            return
        }
        print("[openUri] trying NSWorkspace.open(\(uriString))")
        let ok = NSWorkspace.shared.open(url)
        print("[openUri] NSWorkspace.open → \(ok)")
        if ok {
            result(nil)
        } else {
            result(FlutterError(
                code: "OPEN_FAILED",
                message: "NSWorkspace could not open: \(uriString)",
                details: nil
            ))
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
        let deviceId = nonEmpty(args["deviceId"] as? String)
        print("[SpotifyMacOS] play uri: \(uri) positionMs: \(positionMs ?? 0) device: \(deviceId ?? "(active)")")
        var body: [String: Any] = ["uris": [uri]]
        if let pos = positionMs, pos > 0 {
            body["position_ms"] = pos
        }
        // Ensure Spotify is running so it registers as active Web API device
        ensureSpotifyRunning {
            self.playOnDevice(body: body, deviceId: deviceId, result: result)
        }
    }

    // MARK: - Playback helpers

    /// Name Spotify desktop uses for this Mac in the Web API device list.
    private var localDeviceName: String {
        Host.current().localizedName ?? ""
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let value = value, !value.isEmpty else { return nil }
        return value
    }

    /// Plays on [deviceId] when given, otherwise on the account's active
    /// device. Never silently picks a device on another machine:
    /// - 404 with no target → retry on this Mac if it is in the device list,
    ///   otherwise fail with NO_ACTIVE_DEVICE (details = device list).
    /// - 404 with a target → the chosen device is gone → NO_ACTIVE_DEVICE.
    /// On success returns `{deviceId, deviceName}` of the device used.
    private func playOnDevice(
        body: [String: Any],
        deviceId: String?,
        isRetry: Bool = false,
        result: @escaping FlutterResult
    ) {
        var path = "/me/player/play"
        if let deviceId = deviceId {
            path += "?device_id=\(deviceId)"
        }
        sendPlayerCommand(path: path, body: body) { [weak self] status, bodyStr, error in
            guard let self = self else { return }
            if let error = error {
                result(error)
                return
            }
            if status == 404 {
                self.handleNoActiveDevice(
                    body: body,
                    requestedDeviceId: deviceId,
                    isRetry: isRetry,
                    result: result
                )
                return
            }
            if status >= 400 {
                result(self.playerError(status: status, body: bodyStr))
                return
            }
            self.reportDeviceUsed(requestedDeviceId: deviceId, result: result)
        }
    }

    private func handleNoActiveDevice(
        body: [String: Any],
        requestedDeviceId: String?,
        isRetry: Bool,
        result: @escaping FlutterResult
    ) {
        fetchDevices { [weak self] devices in
            guard let self = self else { return }
            let devices = devices ?? []
            // The chosen device is listed but wasn't ready (e.g. Spotify was
            // just launched) — give it a moment and retry once.
            if let requested = requestedDeviceId, !isRetry,
               devices.contains(where: { ($0["id"] as? String) == requested }) {
                print("[SpotifyMacOS] Device \(requested) listed but not ready — retrying")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.playOnDevice(
                        body: body,
                        deviceId: requested,
                        isRetry: true,
                        result: result
                    )
                }
                return
            }
            if requestedDeviceId == nil,
               let local = devices.first(where: {
                   ($0["name"] as? String) == self.localDeviceName
               }),
               let localId = local["id"] as? String {
                print("[SpotifyMacOS] No active device — using this Mac (\(self.localDeviceName))")
                self.playOnDevice(body: body, deviceId: localId, result: result)
                return
            }
            let message = requestedDeviceId == nil
                ? "No active Spotify device for this account."
                : "The selected Spotify device is no longer available."
            result(FlutterError(
                code: "NO_ACTIVE_DEVICE",
                message: message,
                details: devices.map(self.deviceMap)
            ))
        }
    }

    /// After a successful play, tell Dart which device is playing.
    private func reportDeviceUsed(
        requestedDeviceId: String?,
        result: @escaping FlutterResult
    ) {
        fetchDevices { [weak self] devices in
            guard let self = self else { return }
            let devices = devices ?? []
            let used = devices.first(where: {
                if let id = requestedDeviceId {
                    return ($0["id"] as? String) == id
                }
                return $0["is_active"] as? Bool ?? false
            })
            result([
                "deviceId": used?["id"] as? String ?? requestedDeviceId ?? "",
                "deviceName": used?["name"] as? String ?? "",
            ])
        }
    }

    /// PUT a player command and hand back status + body without
    /// interpreting them.
    private func sendPlayerCommand(
        path: String,
        body: [String: Any],
        completion: @escaping (Int, String, FlutterError?) -> Void
    ) {
        guard let token = storedAccessToken,
              let url = URL(string: "https://api.spotify.com/v1\(path)")
        else {
            completion(0, "", FlutterError(
                code: "NO_TOKEN",
                message: "No access token",
                details: nil
            ))
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(0, "", FlutterError(
                        code: "API_ERROR",
                        message: error.localizedDescription,
                        details: nil
                    ))
                    return
                }
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                let bodyStr = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                print("[SpotifyMacOS] PUT \(path) → \(status)")
                completion(status, bodyStr, nil)
            }
        }.resume()
    }

    private func playerError(status: Int, body: String) -> FlutterError {
        print("[SpotifyMacOS] player error body: \(body)")
        if status == 403 && body.contains("PREMIUM_REQUIRED") {
            return FlutterError(
                code: "PREMIUM_REQUIRED",
                message: "Spotify Premium is required for playback control.",
                details: nil
            )
        }
        return FlutterError(
            code: "API_ERROR",
            message: "HTTP \(status): \(body.isEmpty ? "(no body)" : body)",
            details: nil
        )
    }

    /// Raw device objects from GET /me/player/devices, or nil on failure.
    private func fetchDevices(completion: @escaping ([[String: Any]]?) -> Void) {
        guard let token = storedAccessToken,
              let url = URL(string: "https://api.spotify.com/v1/me/player/devices")
        else {
            completion(nil)
            return
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        URLSession.shared.dataTask(with: request) { data, _, error in
            DispatchQueue.main.async {
                guard
                    let data = data, error == nil,
                    let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let devices = json["devices"] as? [[String: Any]]
                else {
                    completion(nil)
                    return
                }
                completion(devices)
            }
        }.resume()
    }

    private func deviceMap(_ device: [String: Any]) -> [String: Any] {
        return [
            "id": device["id"] as? String ?? "",
            "name": device["name"] as? String ?? "Unknown",
            "type": device["type"] as? String ?? "",
            "isActive": device["is_active"] as? Bool ?? false,
            "isRestricted": device["is_restricted"] as? Bool ?? false,
            "volumePercent": device["volume_percent"] as? Int ?? -1,
        ]
    }

    private func resumeOnDevice(args: [String: Any], result: @escaping FlutterResult) {
        playOnDevice(
            body: [:],
            deviceId: nonEmpty(args["deviceId"] as? String),
            result: result
        )
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

    private func getDevices(result: @escaping FlutterResult) {
        guard storedAccessToken != nil else {
            result(FlutterError(code: "NO_TOKEN", message: "No access token", details: nil))
            return
        }
        fetchDevices { [weak self] devices in
            guard let self = self else { return }
            guard let devices = devices else {
                result(FlutterError(
                    code: "API_ERROR",
                    message: "Could not load Spotify devices",
                    details: nil
                ))
                return
            }
            result(devices.map(self.deviceMap))
        }
    }

    private func getActiveDevices(result: @escaping FlutterResult) {
        guard let token = storedAccessToken else {
            result(FlutterError(code: "NO_TOKEN", message: "No access token", details: nil))
            return
        }
        guard let url = URL(string: "https://api.spotify.com/v1/me/player/devices") else {
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
                    let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let devices = json["devices"] as? [[String: Any]]
                else {
                    result([String]())
                    return
                }
                let names: [String] = devices.map { device in
                    let name = device["name"] as? String ?? "Unknown"
                    let type = device["type"] as? String ?? ""
                    let active = device["is_active"] as? Bool ?? false
                    return "\(name) (\(type))\(active ? " ●" : "")"
                }
                result(names)
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

    // MARK: - localPlayer (AppleScript)

    /// Bumped on every local play so stale seek guards can bail out.
    private var localPlayGeneration = 0

    /// Controls Spotify for Mac directly via AppleScript, bypassing the Web
    /// API. Used when the desktop app accepts Web API commands (204) but
    /// never loads the track. Commands: play (spotifyUri, positionMs),
    /// pause, resume.
    private func localPlayer(
        args: [String: Any],
        result: @escaping FlutterResult
    ) {
        let command = args["command"] as? String ?? ""
        switch command {
        case "play":
            guard let uri = args["spotifyUri"] as? String,
                  uri.hasPrefix("spotify:"),
                  !uri.contains("\""), !uri.contains("\\")
            else {
                result(FlutterError(
                    code: "INVALID_ARGS",
                    message: "Missing or invalid spotifyUri",
                    details: nil
                ))
                return
            }
            let positionMs = args["positionMs"] as? Int ?? 0
            localPlayGeneration += 1
            var script = """
            tell application "Spotify"
                play track "\(uri)"

            """
            var seconds: String?
            if positionMs > 0 {
                // Wait (max ~2 s) for a FRESH start before seeking: when the
                // same track was already loaded (playing or paused), the old
                // state matches at first and Spotify restarts the track from
                // 0 right after our seek. No track-id check: Spotify may
                // play a relinked id.
                let target = String(format: "%.3f", Double(positionMs) / 1000)
                seconds = target
                script += """
                    repeat 40 times
                        try
                            if player state is playing and player position < 2 then exit repeat
                        end try
                        delay 0.05
                    end repeat
                    set player position to \(target)

                """
            }
            script += "end tell"
            ensureSpotifyRunning {
                self.runLocalScript(script) { [weak self] value in
                    result(value)
                    if let seconds = seconds {
                        self?.guardSeek(to: seconds)
                    }
                }
            }
        case "pause":
            runLocalScript("tell application \"Spotify\" to pause", result: result)
        case "resume":
            runLocalScript("tell application \"Spotify\" to play", result: result)
        default:
            result(FlutterError(
                code: "INVALID_ARGS",
                message: "Unknown localPlayer command: \(command)",
                details: nil
            ))
        }
    }

    /// Spotify sometimes restarts a just-started track from 0 after our
    /// seek. Re-seek twice in the background if the position fell back to
    /// the start (< 3 s) and is short of [seconds].
    private func guardSeek(to seconds: String) {
        let generation = localPlayGeneration
        let script = """
        tell application "Spotify"
            if player state is playing and player position < 3 and player position < (\(seconds) - 0.5) then set player position to \(seconds)
        end tell
        """
        for delay in [0.5, 1.2] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                // A newer play started – don't seek that track.
                guard generation == self.localPlayGeneration else { return }
                self.runAppleScript(script) { _ in }
            }
        }
    }

    /// Runs [script] and, if djSports was the active app, takes focus back:
    /// Spotify's `play track` brings its own window to the front.
    private func runLocalScript(
        _ script: String,
        result: @escaping FlutterResult
    ) {
        let wasActive = NSApp.isActive
        runAppleScript(script) { [weak self] value in
            result(value)
            guard wasActive else { return }
            self?.reclaimFocusFromSpotify()
            // Spotify can raise its window a moment after the command.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                self?.reclaimFocusFromSpotify()
            }
        }
    }

    private func reclaimFocusFromSpotify() {
        guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier
                == "com.spotify.client"
        else { return }
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - transferPlayback

    /// Moves playback to the given device via PUT /v1/me/player.
    /// `play` is omitted so Spotify keeps the current play/pause state
    /// (same as the web player's `restore_paused: "restore"`).
    private func transferPlayback(
        args: [String: Any],
        result: @escaping FlutterResult
    ) {
        guard let deviceId = args["deviceId"] as? String, !deviceId.isEmpty else {
            result(FlutterError(
                code: "INVALID_ARGS",
                message: "Missing deviceId",
                details: nil
            ))
            return
        }
        spotifyWebAPI(
            method: "PUT",
            path: "/me/player",
            body: ["device_ids": [deviceId]],
            result: result
        )
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
                        // 403 "Restriction violated" means the player state doesn't
                        // allow the command right now (e.g. nothing is playing, already
                        // paused, no active device). Treat as a no-op success so the
                        // app doesn't show errors when Spotify is idle.
                        if http.statusCode == 403 && body.contains("Restriction violated") {
                            print("[SpotifyMacOS] Ignoring restriction violation — player idle or command not applicable")
                            result(nil)
                            return
                        }
                        if http.statusCode == 403 && body.contains("PREMIUM_REQUIRED") {
                            result(FlutterError(
                                code: "PREMIUM_REQUIRED",
                                message: "Spotify Premium is required for playback control.",
                                details: nil
                            ))
                            return
                        }
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
