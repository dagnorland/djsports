import Cocoa
import FlutterMacOS
import MusicKit
import StoreKit

@available(macOS 14.0, *)
@MainActor
class AppleMusicNativeChannel: NSObject {
    private var methodChannel: FlutterMethodChannel?
    private var eventChannel: FlutterEventChannel?
    private var eventSink: FlutterEventSink?
    private var songCache: [String: Song] = [:]

    func setup(messenger: FlutterBinaryMessenger) {
        methodChannel = FlutterMethodChannel(
            name: "com.djsports/apple_music_native",
            binaryMessenger: messenger
        )
        eventChannel = FlutterEventChannel(
            name: "com.djsports/apple_music_connection_events",
            binaryMessenger: messenger
        )
        eventChannel?.setStreamHandler(self)
        methodChannel?.setMethodCallHandler(handle)
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "authorize":
            requestAuthorization(result: result)
        case "getAuthorizationStatus":
            getAuthorizationStatus(result: result)
        case "isSubscribed":
            checkSubscription(result: result)
        case "play":
            playTrack(call: call, result: result)
        case "pause":
            pausePlayback(result: result)
        case "resume":
            resumePlayback(result: result)
        case "seekTo":
            seekTo(call: call, result: result)
        case "search":
            searchCatalog(call: call, result: result)
        case "getPlaybackState":
            getPlaybackState(result: result)
        case "getPlaylistTracks":
            getPlaylistTracks(call: call, result: result)
        case "prewarmCache":
            prewarmCache(call: call, result: result)
        case "presetQueue":
            presetQueue(call: call, result: result)
        case "warmupStreamingSession":
            warmupStreamingSession(call: call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Authorization

    private func requestAuthorization(result: @escaping FlutterResult) {
        Task {
            let status = await MusicAuthorization.request()
            DispatchQueue.main.async {
                let authorized = status == .authorized
                self.eventSink?(["connected": authorized])
                result(authorized)
            }
        }
    }

    private func getAuthorizationStatus(result: @escaping FlutterResult) {
        let status = MusicAuthorization.currentStatus
        let statusStr: String
        switch status {
        case .authorized: statusStr = "authorized"
        case .denied: statusStr = "denied"
        case .restricted: statusStr = "restricted"
        default: statusStr = "notDetermined"
        }
        result(statusStr)
    }

    private func checkSubscription(result: @escaping FlutterResult) {
        let controller = SKCloudServiceController()
        controller.requestCapabilities { capabilities, error in
            DispatchQueue.main.async {
                if let error = error {
                    result(FlutterError(
                        code: "SUB_ERROR",
                        message: error.localizedDescription,
                        details: nil
                    ))
                    return
                }
                result(capabilities.contains(.musicCatalogPlayback))
            }
        }
    }

    // MARK: - Playback
    // Uses ApplicationMusicPlayer (MusicKit) — available macOS 12+.
    // Unlike iOS, MPMusicPlayerController is not available on macOS.

    private func playTrack(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let trackId = args["trackId"] as? String else {
            result(FlutterError(
                code: "INVALID_ARGS",
                message: "trackId is required",
                details: nil
            ))
            return
        }
        let positionMs = args["positionMs"] as? Int ?? 0

        Task {
            let t0 = Date()
            func ms() -> Int { Int(Date().timeIntervalSince(t0) * 1000) }
            NSLog("[AM:play] START trackId=%@ positionMs=%d", trackId, positionMs)

            do {
                // 1. Catalog lookup — use cache to avoid network round-trip on repeat plays
                let song: Song
                let cacheHit: Bool
                if let cached = songCache[trackId] {
                    song = cached
                    cacheHit = true
                } else {
                    cacheHit = false
                    let request = MusicCatalogResourceRequest<Song>(
                        matching: \.id,
                        equalTo: MusicItemID(rawValue: trackId)
                    )
                    let response = try await request.response()
                    guard let fetched = response.items.first else {
                        DispatchQueue.main.async {
                            result(FlutterError(
                                code: "NOT_FOUND",
                                message: "Track not found in catalog",
                                details: nil
                            ))
                        }
                        return
                    }
                    song = fetched
                    songCache[trackId] = song
                }
                let catalogMs = ms()

                // 2. Set queue and start playback
                ApplicationMusicPlayer.shared.queue = [song]
                let queueMs = ms()
                try await ApplicationMusicPlayer.shared.play()
                let playMs = ms()

                // 3. Seek: poll until playing (max 1.5s) instead of fixed sleep
                var seekWaitMs = 0
                if positionMs > 0 {
                    let seekTarget = Double(positionMs) / 1000.0
                    let pollNs: UInt64 = 30_000_000
                    let maxWaitNs: UInt64 = 1_500_000_000
                    var waited: UInt64 = 0
                    while ApplicationMusicPlayer.shared.state.playbackStatus != .playing,
                          waited < maxWaitNs {
                        try await Task.sleep(nanoseconds: pollNs)
                        waited += pollNs
                    }
                    seekWaitMs = Int(waited / 1_000_000)
                    ApplicationMusicPlayer.shared.playbackTime = seekTarget
                }

                let hit = cacheHit ? "hit" : "miss"
                let timing = "playing|cache=\(hit)|catalog=\(catalogMs)|queue=\(queueMs)|play=\(playMs)|seekWait=\(seekWaitMs)|total=\(ms())"
                NSLog("[AM:play] DONE %@", timing)
                DispatchQueue.main.async { result(timing) }
            } catch {
                NSLog("[AM:play] ERROR at %dms: %@", ms(), error.localizedDescription)
                DispatchQueue.main.async {
                    result(FlutterError(
                        code: "PLAY_ERROR",
                        message: error.localizedDescription,
                        details: nil
                    ))
                }
            }
        }
    }

    private func pausePlayback(result: @escaping FlutterResult) {
        ApplicationMusicPlayer.shared.pause()
        result(true)
    }

    private func resumePlayback(result: @escaping FlutterResult) {
        Task {
            do {
                try await ApplicationMusicPlayer.shared.play()
                DispatchQueue.main.async { result(true) }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(
                        code: "RESUME_ERROR",
                        message: error.localizedDescription,
                        details: nil
                    ))
                }
            }
        }
    }

    private func seekTo(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let positionMs = args["positionMs"] as? Int else {
            result(FlutterError(
                code: "INVALID_ARGS",
                message: "positionMs is required",
                details: nil
            ))
            return
        }
        ApplicationMusicPlayer.shared.playbackTime = Double(positionMs) / 1000.0
        result(true)
    }

    private func getPlaybackState(result: FlutterResult) {
        let status = ApplicationMusicPlayer.shared.state.playbackStatus
        let state: String
        switch status {
        case .playing: state = "playing"
        case .paused: state = "paused"
        case .stopped: state = "stopped"
        case .interrupted: state = "interrupted"
        default: state = "stopped"
        }
        result(state)
    }

    // MARK: - Cache Prewarm

    /// Batch-fetches songs into songCache so play() skips the catalog round-trip.
    private func prewarmCache(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let ids = args["trackIds"] as? [String], !ids.isEmpty else {
            result(0)
            return
        }
        Task {
            let t0 = Date()
            let uncached = ids.filter { songCache[$0] == nil }
            guard !uncached.isEmpty else {
                NSLog("[AM:prewarm] all %d tracks already cached", ids.count)
                DispatchQueue.main.async { result(ids.count) }
                return
            }
            NSLog("[AM:prewarm] fetching %d tracks (of %d requested)", uncached.count, ids.count)
            var fetched = 0
            let batchSize = 25
            for batchStart in stride(from: 0, to: uncached.count, by: batchSize) {
                let batchEnd = min(batchStart + batchSize, uncached.count)
                let batchIds = uncached[batchStart..<batchEnd].map {
                    MusicItemID(rawValue: $0)
                }
                do {
                    let request = MusicCatalogResourceRequest<Song>(
                        matching: \.id,
                        memberOf: batchIds
                    )
                    let response = try await request.response()
                    for song in response.items {
                        songCache[song.id.rawValue] = song
                        fetched += 1
                    }
                } catch {
                    NSLog("[AM:prewarm] batch error: %@", error.localizedDescription)
                }
            }
            let elapsed = Int(Date().timeIntervalSince(t0) * 1000)
            NSLog("[AM:prewarm] DONE %d/%d songs cached in %dms", fetched, uncached.count, elapsed)
            DispatchQueue.main.async { result(fetched) }
        }
    }

    /// Warms up the MusicKit streaming session by doing a silent play+pause.
    /// After this, all subsequent play() calls run at ~600ms instead of ~1600ms.
    /// The user hears at most one 30ms poll cycle of audio (<1 frame, inaudible).
    private func warmupStreamingSession(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let trackId = args["trackId"] as? String,
              let song = songCache[trackId] else {
            NSLog("[AM:warmup] SKIP — trackId not in cache")
            DispatchQueue.main.async { result(false) }
            return
        }
        Task {
            let t0 = Date()
            func ms() -> Int { Int(Date().timeIntervalSince(t0) * 1000) }
            NSLog("[AM:warmup] START trackId=%@", trackId)
            ApplicationMusicPlayer.shared.queue = [song]
            // Fire play() without awaiting — poll for playing state in parallel
            Task { try? await ApplicationMusicPlayer.shared.play() }
            let pollNs: UInt64 = 30_000_000  // 30ms
            let maxWaitNs: UInt64 = 4_000_000_000  // 4s ceiling
            var waited: UInt64 = 0
            while ApplicationMusicPlayer.shared.state.playbackStatus != .playing,
                  waited < maxWaitNs {
                try? await Task.sleep(nanoseconds: pollNs)
                waited += pollNs
            }
            ApplicationMusicPlayer.shared.pause()
            NSLog("[AM:warmup] DONE in %dms (audio heard ~%dms)", ms(), Int(waited / 1_000_000))
            DispatchQueue.main.async { result(true) }
        }
    }

    /// Pre-sets the player queue for a specific track without playing.
    /// Triggers MusicKit DRM/metadata init so the first play() is faster.
    private func presetQueue(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let trackId = args["trackId"] as? String, !trackId.isEmpty else {
            result(false)
            return
        }
        Task {
            let t0 = Date()
            let song: Song
            if let cached = songCache[trackId] {
                song = cached
            } else {
                do {
                    let request = MusicCatalogResourceRequest<Song>(
                        matching: \.id, equalTo: MusicItemID(rawValue: trackId)
                    )
                    let response = try await request.response()
                    guard let fetched = response.items.first else {
                        DispatchQueue.main.async { result(false) }
                        return
                    }
                    songCache[trackId] = fetched
                    song = fetched
                } catch {
                    DispatchQueue.main.async { result(false) }
                    return
                }
            }
            ApplicationMusicPlayer.shared.queue = [song]
            let elapsed = Int(Date().timeIntervalSince(t0) * 1000)
            NSLog("[AM:presetQueue] queue set for %@ in %dms", trackId, elapsed)
            DispatchQueue.main.async { result(true) }
        }
    }

    // MARK: - Playlist Sync

    private func getPlaylistTracks(
        call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        guard let args = call.arguments as? [String: Any],
              let playlistId = args["playlistId"] as? String,
              !playlistId.isEmpty else {
            result(FlutterError(
                code: "INVALID_ARGS",
                message: "playlistId is required",
                details: nil
            ))
            return
        }

        Task {
            do {
                var request = MusicCatalogResourceRequest<Playlist>(
                    matching: \.id,
                    equalTo: MusicItemID(rawValue: playlistId)
                )
                request.properties = [.tracks]
                let response = try await request.response()

                guard let playlist = response.items.first else {
                    DispatchQueue.main.async {
                        result(FlutterError(
                            code: "NOT_FOUND",
                            message: "Playlist not found. Make sure it is public.",
                            details: nil
                        ))
                    }
                    return
                }

                let playlistWithTracks = try await playlist.with(.tracks)
                var allTracks: [Track] = []
                if var batch = playlistWithTracks.tracks {
                    allTracks.append(contentsOf: batch)
                    while batch.hasNextBatch {
                        batch = try await batch.nextBatch()!
                        allTracks.append(contentsOf: batch)
                    }
                }
                let tracks: [[String: Any]] = allTracks.map { track in
                    var artworkUrl = ""
                    if let url = track.artwork?.url(width: 300, height: 300) {
                        artworkUrl = url.absoluteString
                    }
                    return [
                        "id": track.id.rawValue,
                        "name": track.title,
                        "artist": track.artistName,
                        "duration": Int((track.duration ?? 0) * 1000),
                        "artworkUrl": artworkUrl,
                    ]
                }

                DispatchQueue.main.async {
                    result([
                        "playlistName": playlist.name,
                        "tracks": tracks,
                    ])
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(
                        code: "FETCH_ERROR",
                        message: error.localizedDescription,
                        details: nil
                    ))
                }
            }
        }
    }

    // MARK: - Catalog Search

    private func searchCatalog(
        call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        guard let args = call.arguments as? [String: Any],
              let query = args["query"] as? String,
              !query.isEmpty else {
            result(FlutterError(
                code: "INVALID_ARGS",
                message: "query is required",
                details: nil
            ))
            return
        }
        let limit = args["limit"] as? Int ?? 25

        Task {
            do {
                var request = MusicCatalogSearchRequest(
                    term: query,
                    types: [Song.self]
                )
                request.limit = limit
                let response = try await request.response()

                let tracks: [[String: Any]] = response.songs.compactMap { song in
                    var artworkUrl = ""
                    if let url = song.artwork?.url(width: 300, height: 300) {
                        artworkUrl = url.absoluteString
                    }
                    return [
                        "id": song.id.rawValue,
                        "name": song.title,
                        "artist": song.artistName,
                        "album": song.albumTitle ?? "",
                        "duration": Int((song.duration ?? 0) * 1000),
                        "artworkUrl": artworkUrl,
                    ]
                }

                DispatchQueue.main.async { result(tracks) }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(
                        code: "SEARCH_ERROR",
                        message: error.localizedDescription,
                        details: nil
                    ))
                }
            }
        }
    }
}

// MARK: - FlutterStreamHandler

@available(macOS 14.0, *)
extension AppleMusicNativeChannel: @preconcurrency FlutterStreamHandler {
    func onListen(
        withArguments arguments: Any?,
        eventSink events: @escaping FlutterEventSink
    ) -> FlutterError? {
        eventSink = events
        let authorized = MusicAuthorization.currentStatus == .authorized
        events(["connected": authorized])
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
}
