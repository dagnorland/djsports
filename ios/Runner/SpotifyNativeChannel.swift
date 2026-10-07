import UIKit
import Flutter
import AuthenticationServices
import CryptoKit

class SpotifyNativeChannel: NSObject {
    static let methodChannelName = "com.djsports/spotify_native"
    static let eventChannelName = "com.djsports/spotify_connection_events"

    private var eventSink: FlutterEventSink?
    private var authSession: ASWebAuthenticationSession?

    private let refreshTokenKey = "spotify_ios_refresh_token"
    private var storedAccessToken: String?

    /// 10-minute silence track used as a keep-alive when the user presses pause.
    private let silenceTrackUri = "spotify:track:0XycH5D4znCfJIBeYt3upG"
    // Keep-alive timer: pings GET /v1/me/player every 10 s while connected
    private var keepAliveTimer: Timer?
    private let keepAliveInterval: TimeInterval = 10

    // Pending play retry after auto-opening Spotify
    private var pendingPlayBody: [String: Any]?
    private var pendingPlayResult: FlutterResult?
    private var foregroundObserver: Any?
    private var pendingPlayTimeoutTimer: Timer?

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
            playSilenceKeepAlive(result: result)
        case "resume":
            resumeOnDevice(args: args, result: result)
        case "seekTo":
            seekTo(args: args, result: result)
        case "setVolume":
            let percent = args["volumePercent"] as? Int ?? 50
            spotifyWebAPI(
                method: "PUT",
                path: "/me/player/volume?volume_percent=\(percent)",
                result: result
            )
        case "getUserProfile":
            getUserProfile(result: result)
        case "getActiveDevices":
            getActiveDevices(result: result)
        case "getDevices":
            getDevices(result: result)
        case "transferPlayback":
            transferPlayback(args: args, result: result)
        case "getLocalDeviceName":
            result(localDeviceName)
        case "clearSession":
            stopKeepAlive()
            storedAccessToken = nil
            UserDefaults.standard.removeObject(forKey: refreshTokenKey)
            eventSink?(["connected": false])
            result(nil)
        case "launchSpotify":
            launchSpotify(result: result)
        case "getDebugInfo":
            result([
                "native.hasToken": storedAccessToken != nil ? "true" : "false",
                "native.hasRefreshToken": UserDefaults.standard.string(
                    forKey: refreshTokenKey
                ) != nil ? "true" : "false",
                "native.localDeviceName": localDeviceName,
            ] as [String: Any])
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

        // Account switch: skip the cached refresh token and force Spotify to
        // show its login / account picker instead of silently reusing the
        // browser's existing Spotify session.
        if args["forceAccountPicker"] as? Bool == true {
            stopKeepAlive()
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
                    self?.eventSink?(["connected": true])
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
                    UserDefaults.standard.set(
                        refreshToken,
                        forKey: self?.refreshTokenKey ?? "spotify_ios_refresh_token"
                    )
                }
                self?.storedAccessToken = accessToken
                self?.eventSink?(["connected": true])
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
                        forKey: self?.refreshTokenKey ?? "spotify_ios_refresh_token"
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
                let k = $0.key.addingPercentEncoding(
                    withAllowedCharacters: .urlQueryAllowed
                ) ?? $0.key
                let v = $0.value.addingPercentEncoding(
                    withAllowedCharacters: .urlQueryAllowed
                ) ?? $0.value
                return "\(k)=\(v)"
            }
            .joined(separator: "&")
            .data(using: .utf8)
    }

    // MARK: - connect

    private func connectToSpotify(result: @escaping FlutterResult) {
        // Web API is stateless — "connected" means having a valid access token.
        guard storedAccessToken != nil ||
              UserDefaults.standard.string(forKey: refreshTokenKey) != nil
        else {
            result(FlutterError(
                code: "NOT_CONNECTED",
                message: "No access token — call getAccessToken first",
                details: nil
            ))
            return
        }
        NSLog("[SpotifyiOS] connect: Web API ready — activating local device in background")
        result(true)
        eventSink?(["connected": true])
        startKeepAlive()
        // Fire-and-forget: transfer playback to this device so it's ready before first play.
        activateLocalDevice { deviceId in
            if let deviceId = deviceId {
                NSLog("[SpotifyiOS] connect: activated device %@", deviceId)
            } else {
                NSLog("[SpotifyiOS] connect: no device to activate (Spotify not running?)")
            }
        }
    }

    // MARK: - Keep-alive

    private func startKeepAlive() {
        keepAliveTimer?.invalidate()
        keepAliveTimer = Timer.scheduledTimer(
            withTimeInterval: keepAliveInterval, repeats: true
        ) { [weak self] _ in
            self?.pingPlayerState()
        }
        NSLog("[SpotifyiOS] keepAlive: started (interval %.0fs)", keepAliveInterval)
    }

    private func stopKeepAlive() {
        keepAliveTimer?.invalidate()
        keepAliveTimer = nil
        NSLog("[SpotifyiOS] keepAlive: stopped")
    }

    /// Pings GET /v1/me/player.
    /// - 200: device active → transfer playback to it (keeps Spotify's audio
    ///        session alive by sending it a write command).
    /// - 204: no active device → call activateLocalDevice so the next play
    ///        doesn't need to open Spotify first.
    private func pingPlayerState() {
        guard let token = storedAccessToken,
              let url = URL(string: "https://api.spotify.com/v1/me/player")
        else { return }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        URLSession.shared.dataTask(with: request) { [weak self] data, response, _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                NSLog("[SpotifyiOS] keepAlive: ping status %d", status)

                if status == 204 {
                    // No active device — try to reactivate proactively so the
                    // next play attempt doesn't have to open Spotify first.
                    NSLog("[SpotifyiOS] keepAlive: no active device — reactivating…")
                    self.activateLocalDevice { deviceId in
                        NSLog(
                            "[SpotifyiOS] keepAlive: reactivate → %@",
                            deviceId ?? "nil"
                        )
                    }
                }
            }
        }.resume()
    }

    // MARK: - Device activation helpers

    /// Finds this iPhone's Spotify device (or the already-active device) and
    /// transfers playback to it. Never picks a device on another machine.
    private func activateLocalDevice(completion: @escaping (String?) -> Void) {
        fetchPreferredDeviceId { [weak self] deviceId in
            guard let self = self, let deviceId = deviceId else {
                completion(nil)
                return
            }
            self.transferPlaybackToDevice(deviceId) { success in
                completion(success ? deviceId : nil)
            }
        }
    }

    /// Returns the best device ID: active first, then this phone (matched by
    /// name, or the only Smartphone on the account). Nil otherwise.
    private func fetchPreferredDeviceId(completion: @escaping (String?) -> Void) {
        guard let token = storedAccessToken,
              let url = URL(string: "https://api.spotify.com/v1/me/player/devices")
        else {
            completion(nil)
            return
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            DispatchQueue.main.async {
                guard
                    let self = self,
                    let data = data, error == nil,
                    let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let devices = json["devices"] as? [[String: Any]],
                    !devices.isEmpty
                else {
                    completion(nil)
                    return
                }
                // 1. Already-active device
                if let active = devices.first(where: { $0["is_active"] as? Bool == true }),
                   let id = active["id"] as? String {
                    let name = active["name"] as? String ?? "?"
                    NSLog("[SpotifyiOS] preferredDevice: already active — %@", name)
                    completion(id)
                    return
                }
                // 2. This phone, by name
                if let local = devices.first(where: {
                    ($0["name"] as? String) == self.localDeviceName
                }), let id = local["id"] as? String {
                    NSLog("[SpotifyiOS] preferredDevice: this phone — %@", self.localDeviceName)
                    completion(id)
                    return
                }
                // 3. The only Smartphone on the account (iOS may hide the
                //    real device name, so fall back to type when unambiguous)
                let phones = devices.filter {
                    ($0["type"] as? String)?.lowercased() == "smartphone"
                }
                if phones.count == 1, let id = phones[0]["id"] as? String {
                    let name = phones[0]["name"] as? String ?? "?"
                    NSLog("[SpotifyiOS] preferredDevice: only smartphone — %@", name)
                    completion(id)
                    return
                }
                NSLog("[SpotifyiOS] preferredDevice: none on this phone")
                completion(nil)
            }
        }.resume()
    }

    /// Transfers playback to [deviceId] via PUT /v1/me/player (play: false = keep paused).
    private func transferPlaybackToDevice(_ deviceId: String, completion: @escaping (Bool) -> Void) {
        guard let token = storedAccessToken,
              let url = URL(string: "https://api.spotify.com/v1/me/player")
        else {
            completion(false)
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "device_ids": [deviceId],
            "play": false,
        ])
        URLSession.shared.dataTask(with: request) { _, response, _ in
            DispatchQueue.main.async {
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                NSLog("[SpotifyiOS] transferPlayback → device %@ status: %d", deviceId, status)
                completion(status < 400)
            }
        }.resume()
    }

    // MARK: - Silence keep-alive

    /// Called instead of a real pause. Plays a 10-min silence track so that
    /// the Spotify device stays active and can be played immediately next time.
    private func playSilenceKeepAlive(result: @escaping FlutterResult) {
        NSLog("[SpotifyiOS] pause → playing silence track (%@)", silenceTrackUri)
        let body: [String: Any] = ["uris": [silenceTrackUri]]
        spotifyWebAPI(method: "PUT", path: "/me/player/play", body: body, result: result)
    }

    // MARK: - launchSpotify

    private func launchSpotify(result: @escaping FlutterResult) {
        guard let spotifyURL = URL(string: "spotify:") else {
            result(false)
            return
        }
        UIApplication.shared.open(spotifyURL, options: [:]) { success in
            DispatchQueue.main.async {
                NSLog("[SpotifyiOS] launchSpotify: %@", success ? "opened" : "failed")
                result(success)
            }
        }
    }

    // MARK: - Auto-open Spotify + return flow

    /// Opens Spotify, schedules return to djsports after 2 s, then retries
    /// the pending play when djsports comes back to foreground.
    private func openSpotifyAndReturnToApp(
        body: [String: Any],
        result: @escaping FlutterResult
    ) {
        // Store pending play
        pendingPlayBody = body
        pendingPlayResult = result

        // Register foreground observer to fire retryPendingPlay when we return
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.retryPendingPlay()
        }

        // Timeout — if user never returns, fail after 45 s
        pendingPlayTimeoutTimer = Timer.scheduledTimer(
            withTimeInterval: 45, repeats: false
        ) { [weak self] _ in
            NSLog("[SpotifyiOS] Pending play timed out")
            self?.cancelPendingPlay()
        }

        guard let spotifyURL = URL(string: "spotify:") else {
            cancelPendingPlay(error: "Could not build Spotify URL")
            return
        }
        UIApplication.shared.open(spotifyURL, options: [:]) { [weak self] success in
            NSLog("[SpotifyiOS] Opened Spotify: %@", success ? "ok" : "failed")
            guard success else {
                self?.cancelPendingPlay(error: "Could not open Spotify app")
                return
            }
            // Return to djsports after giving the user 2 s to see Spotify
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.returnToApp()
            }
        }
    }

    private func returnToApp() {
        guard let url = URL(string: "djsports://") else { return }
        UIApplication.shared.open(url, options: [:]) { success in
            NSLog("[SpotifyiOS] Returned to djsports: %@", success ? "ok" : "failed")
        }
    }

    private func retryPendingPlay() {
        guard let body = pendingPlayBody, let result = pendingPlayResult else { return }
        clearPendingPlay()
        NSLog("[SpotifyiOS] retryPendingPlay — activating device then playing")
        // Give Spotify a moment after we returned to foreground
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            self.activateLocalDevice { deviceId in
                if let deviceId = deviceId {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        NSLog("[SpotifyiOS] retryPendingPlay — playing on device: %@", deviceId)
                        self.spotifyWebAPI(
                            method: "PUT",
                            path: "/me/player/play?device_id=\(deviceId)",
                            body: body,
                            result: result
                        )
                    }
                } else {
                    // Still no device on this phone — let Dart ask the user
                    self.failNoActiveDevice(
                        requestedDeviceId: nil,
                        result: result
                    )
                }
            }
        }
    }

    private func cancelPendingPlay(error: String? = nil) {
        guard let result = pendingPlayResult else { return }
        clearPendingPlay()
        result(FlutterError(
            code: "API_ERROR",
            message: error ?? "No active device found. Open Spotify app and try again.",
            details: nil
        ))
    }

    private func clearPendingPlay() {
        pendingPlayBody = nil
        pendingPlayResult = nil
        pendingPlayTimeoutTimer?.invalidate()
        pendingPlayTimeoutTimer = nil
        if let obs = foregroundObserver {
            NotificationCenter.default.removeObserver(obs)
            foregroundObserver = nil
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
        NSLog(
            "[SpotifyiOS] play uri: %@ positionMs: %d device: %@",
            uri, positionMs ?? 0, deviceId ?? "(active)"
        )
        var body: [String: Any] = ["uris": [uri]]
        if let pos = positionMs, pos > 0 {
            body["position_ms"] = pos
        }
        playWithAutoDeviceFallback(body: body, deviceId: deviceId, result: result)
    }

    private func resumeOnDevice(args: [String: Any], result: @escaping FlutterResult) {
        playWithAutoDeviceFallback(
            body: [:],
            deviceId: nonEmpty(args["deviceId"] as? String),
            result: result
        )
    }

    /// Name of this iPhone. Since iOS 16 this may be generic ("iPhone")
    /// unless the app has the device-name entitlement.
    private var localDeviceName: String {
        UIDevice.current.name
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let value = value, !value.isEmpty else { return nil }
        return value
    }

    /// Plays on [deviceId] when given, otherwise on the active device.
    /// - 404 with a target → device gone → NO_ACTIVE_DEVICE.
    /// - 404 without a target → activate this phone (or open Spotify on it)
    ///   and retry; never falls back to a device on another machine.
    /// On success returns `{deviceId, deviceName}` of the device used.
    private func playWithAutoDeviceFallback(
        body: [String: Any],
        deviceId: String? = nil,
        result: @escaping FlutterResult
    ) {
        var path = "https://api.spotify.com/v1/me/player/play"
        if let deviceId = deviceId {
            path += "?device_id=\(deviceId)"
        }
        guard let token = storedAccessToken,
              let url = URL(string: path)
        else {
            result(FlutterError(code: "NO_TOKEN", message: "No access token", details: nil))
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let error = error {
                    result(FlutterError(
                        code: "API_ERROR",
                        message: error.localizedDescription,
                        details: nil
                    ))
                    return
                }
                guard let http = response as? HTTPURLResponse else {
                    result(nil)
                    return
                }
                NSLog("[SpotifyiOS] play status: %d", http.statusCode)
                if http.statusCode == 404 && deviceId != nil {
                    self.failNoActiveDevice(
                        requestedDeviceId: deviceId,
                        result: result
                    )
                    return
                }
                if http.statusCode == 404 {
                    // No active device — find preferred device, transfer playback, then retry.
                    NSLog("[SpotifyiOS] No active device — transferring to preferred device…")
                    self.activateLocalDevice { deviceId in
                        guard let deviceId = deviceId else {
                            // Spotify not running — open it, return to this app, retry.
                            NSLog("[SpotifyiOS] No device available — auto-opening Spotify…")
                            self.openSpotifyAndReturnToApp(body: body, result: result)
                            return
                        }
                        // Short wait for transfer to register before playing.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            NSLog("[SpotifyiOS] Retrying play after transfer to device_id: %@", deviceId)
                            self.playWithAutoDeviceFallback(
                                body: body,
                                deviceId: deviceId,
                                result: result
                            )
                        }
                    }
                    return
                }
                if http.statusCode >= 400 {
                    let bodyStr = data.flatMap {
                        String(data: $0, encoding: .utf8)
                    } ?? "(no body)"
                    NSLog("[SpotifyiOS] play error body: %@", bodyStr)
                    result(self.playerError(status: http.statusCode, body: bodyStr))
                    return
                }
                self.reportDeviceUsed(requestedDeviceId: deviceId, result: result)
            }
        }.resume()
    }

    private func failNoActiveDevice(
        requestedDeviceId: String?,
        result: @escaping FlutterResult
    ) {
        fetchDevices { [weak self] devices in
            guard let self = self else { return }
            let message = requestedDeviceId == nil
                ? "No active Spotify device for this account."
                : "The selected Spotify device is no longer available."
            result(FlutterError(
                code: "NO_ACTIVE_DEVICE",
                message: message,
                details: (devices ?? []).map(self.deviceMap)
            ))
        }
    }

    /// After a successful play, tell Dart which device is playing.
    private func reportDeviceUsed(
        requestedDeviceId: String?,
        result: @escaping FlutterResult
    ) {
        fetchDevices { devices in
            let used = (devices ?? []).first(where: {
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

    private func playerError(status: Int, body: String) -> FlutterError {
        if status == 403 && body.contains("PREMIUM_REQUIRED") {
            return FlutterError(
                code: "PREMIUM_REQUIRED",
                message: "Spotify Premium is required for playback control.",
                details: nil
            )
        }
        return FlutterError(
            code: "API_ERROR",
            message: "HTTP \(status): \(body)",
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

    private func seekTo(args: [String: Any], result: @escaping FlutterResult) {
        guard let positionMs = args["positionedMilliseconds"] as? Int else {
            result(FlutterError(
                code: "INVALID_ARGS",
                message: "Missing positionedMilliseconds",
                details: nil
            ))
            return
        }
        spotifyWebAPI(
            method: "PUT",
            path: "/me/player/seek?position_ms=\(positionMs)",
            result: result
        )
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
        URLSession.shared.dataTask(with: request) { data, _, error in
            DispatchQueue.main.async {
                if let error = error {
                    result(FlutterError(
                        code: "API_ERROR",
                        message: error.localizedDescription,
                        details: nil
                    ))
                    return
                }
                guard
                    let data = data,
                    let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                else {
                    result(FlutterError(
                        code: "PARSE_ERROR",
                        message: "Could not parse /me response",
                        details: nil
                    ))
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
                ] as [String: Any])
            }
        }.resume()
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
        URLSession.shared.dataTask(with: request) { data, _, error in
            DispatchQueue.main.async {
                if let error = error {
                    result(FlutterError(
                        code: "API_ERROR",
                        message: error.localizedDescription,
                        details: nil
                    ))
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
            result(FlutterError(
                code: "INVALID_URL",
                message: "Bad API path: \(path)",
                details: nil
            ))
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body = body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }
        NSLog("[SpotifyiOS] Web API %@ %@", method, path)
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    NSLog("[SpotifyiOS] Web API error: %@", error.localizedDescription)
                    result(FlutterError(
                        code: "API_ERROR",
                        message: error.localizedDescription,
                        details: nil
                    ))
                    return
                }
                if let http = response as? HTTPURLResponse {
                    NSLog("[SpotifyiOS] Web API status: %d", http.statusCode)
                    if http.statusCode >= 400 {
                        let body = data.flatMap {
                            String(data: $0, encoding: .utf8)
                        } ?? "(no body)"
                        NSLog("[SpotifyiOS] Web API error body: %@", body)
                        // 403 "Restriction violated" means the player is idle or
                        // the command isn't applicable right now. Treat as no-op.
                        if http.statusCode == 403 && body.contains("Restriction violated") {
                            NSLog("[SpotifyiOS] Ignoring restriction violation — player idle or command not applicable")
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
                        result(FlutterError(
                            code: "API_ERROR",
                            message: "HTTP \(http.statusCode): \(body)",
                            details: nil
                        ))
                        return
                    }
                }
                result(nil)
            }
        }.resume()
    }
}

// MARK: - FlutterStreamHandler

extension SpotifyNativeChannel: FlutterStreamHandler {
    func onListen(
        withArguments arguments: Any?,
        eventSink events: @escaping FlutterEventSink
    ) -> FlutterError? {
        eventSink = events
        // Emit connected state based on whether we have a stored token
        let hasToken = storedAccessToken != nil ||
                       UserDefaults.standard.string(forKey: refreshTokenKey) != nil
        events(["connected": hasToken])
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension SpotifyNativeChannel: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first ?? UIWindow()
    }
}
