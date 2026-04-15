import Foundation
import MusicKit
import StoreKit
import UIKit

@available(iOS 15.0, *)
@MainActor
class AppleMusicNativeChannel: NSObject {
    private var methodChannel: FlutterMethodChannel?
    private var eventChannel: FlutterEventChannel?
    private var eventSink: FlutterEventSink?

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
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Authorization

    private func requestAuthorization(result: @escaping FlutterResult) {
        NSLog("[AppleMusic] requestAuthorization called")
        Task {
            let status = await MusicAuthorization.request()
            NSLog("[AppleMusic] requestAuthorization result: \(status)")
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
        NSLog("[AppleMusic] getAuthorizationStatus: \(statusStr)")
        result(statusStr)
    }

    private func checkSubscription(result: @escaping FlutterResult) {
        NSLog("[AppleMusic] checkSubscription called")
        let controller = SKCloudServiceController()
        controller.requestCapabilities { capabilities, error in
            DispatchQueue.main.async {
                if let error = error {
                    NSLog("[AppleMusic] checkSubscription error: \(error)")
                    result(FlutterError(
                        code: "SUB_ERROR",
                        message: error.localizedDescription,
                        details: nil
                    ))
                    return
                }
                let hasCatalog = capabilities.contains(.musicCatalogPlayback)
                NSLog("[AppleMusic] checkSubscription capabilities: \(capabilities.rawValue) hasCatalogPlayback: \(hasCatalog)")
                result(hasCatalog)
            }
        }
    }

    // MARK: - Playback
    // Uses ApplicationMusicPlayer (MusicKit) — available iOS 15+.
    // Replaces MPMusicPlayerController which returned error 400
    // (cloudServiceCapabilityMissing) when seeking to non-zero positions.

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
        NSLog("[AppleMusic] playTrack trackId=\(trackId) positionMs=\(positionMs)")

        Task {
            do {
                var request = MusicCatalogResourceRequest<Song>(
                    matching: \.id,
                    equalTo: MusicItemID(rawValue: trackId)
                )
                let response = try await request.response()
                guard let song = response.items.first else {
                    NSLog("[AppleMusic] playTrack track not found in catalog")
                    DispatchQueue.main.async {
                        result(FlutterError(
                            code: "NOT_FOUND",
                            message: "Track not found in catalog",
                            details: nil
                        ))
                    }
                    return
                }
                ApplicationMusicPlayer.shared.queue = [song]
                if positionMs > 0 {
                    // Prepare (buffer) without playing so seek takes effect
                    // immediately — no audio heard at wrong position
                    try await ApplicationMusicPlayer.shared.prepareToPlay()
                    ApplicationMusicPlayer.shared.playbackTime =
                        Double(positionMs) / 1000.0
                    NSLog("[AppleMusic] playTrack seeked to \(Double(positionMs) / 1000.0)s")
                }
                try await ApplicationMusicPlayer.shared.play()
                NSLog("[AppleMusic] playTrack playing positionMs=\(positionMs)")
                DispatchQueue.main.async { result("playing") }
            } catch {
                NSLog("[AppleMusic] playTrack error: \(error)")
                DispatchQueue.main.async {
                    result(FlutterError(
                        code: "PLAY_ERROR",
                        message: error.localizedDescription,
                        details: "\(error)"
                    ))
                }
            }
        }
    }

    private func pausePlayback(result: @escaping FlutterResult) {
        ApplicationMusicPlayer.shared.pause()
        NSLog("[AppleMusic] pause")
        result(true)
    }

    private func resumePlayback(result: @escaping FlutterResult) {
        Task {
            do {
                try await ApplicationMusicPlayer.shared.play()
                NSLog("[AppleMusic] resume OK")
                DispatchQueue.main.async { result(true) }
            } catch {
                NSLog("[AppleMusic] resume error: \(error)")
                DispatchQueue.main.async {
                    result(FlutterError(
                        code: "RESUME_ERROR",
                        message: error.localizedDescription,
                        details: "\(error)"
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
        let secs = Double(positionMs) / 1000.0
        ApplicationMusicPlayer.shared.playbackTime = secs
        NSLog("[AppleMusic] seekTo \(secs)s")
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
        NSLog("[AppleMusic] getPlaylistTracks id=\(playlistId)")

        Task {
            do {
                var request = MusicCatalogResourceRequest<Playlist>(
                    matching: \.id,
                    equalTo: MusicItemID(rawValue: playlistId)
                )
                request.properties = [.tracks]
                let response = try await request.response()

                NSLog("[AppleMusic] getPlaylistTracks catalog response items=\(response.items.count)")
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
                NSLog("[AppleMusic] getPlaylistTracks error: \(error)")
                DispatchQueue.main.async {
                    result(FlutterError(
                        code: "FETCH_ERROR",
                        message: error.localizedDescription,
                        details: "\(error)"
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
        NSLog("[AppleMusic] searchCatalog query='\(query)' limit=\(limit)")

        Task {
            do {
                var request = MusicCatalogSearchRequest(
                    term: query,
                    types: [Song.self]
                )
                request.limit = limit
                let response = try await request.response()
                NSLog("[AppleMusic] searchCatalog got \(response.songs.count) results")

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
                NSLog("[AppleMusic] searchCatalog error: \(error)")
                DispatchQueue.main.async {
                    result(FlutterError(
                        code: "SEARCH_ERROR",
                        message: error.localizedDescription,
                        details: "\(error)"
                    ))
                }
            }
        }
    }
}

// MARK: - FlutterStreamHandler

@available(iOS 15.0, *)
extension AppleMusicNativeChannel: FlutterStreamHandler {
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
