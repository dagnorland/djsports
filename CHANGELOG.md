# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.5.7] - Release 2026-03-19

### Changed
- **Removed bloc/flutter_bloc dependencies** — `bloc` and `flutter_bloc` packages removed; state management is handled exclusively by Riverpod
- **Upgraded just_audio to ^0.10.5** — updated `DJAudioHandler` to use the new non-nullable APIs (`effectiveIndices`, `shuffleIndices`, `sequence`)
- **Upgraded dependencies** — `flutter_dotenv ^6.0.0`, `package_info_plus ^9.0.0`, `flutter_lints ^6.0.0`, `hive_ce_generator ^1.11.0`

### Fixed
- **iOS: native volume mute/seek/unmute on play with start position** — play with a `positionMs` offset now mutes, plays, seeks, and restores system volume natively in `SpotifyNativeChannel.swift` via `MPVolumeView`, matching macOS behavior and removing the Dart-side `_restoreVolume` workaround
- **Code quality** — used `unawaited()` for background user-profile fetch to suppress lint warnings; various formatting fixes across the codebase

## [2.5.6] - Release 2026-03-04

### Added
- **macOS: Show connected Spotify account** — display name and email of the authenticated Spotify user are now shown in the Spotify Diagnostics panel

### Fixed
- **macOS: "Open Spotify" button now works** — new `launchSpotify` native method activates Spotify if it is already running (brings it to the foreground), or launches it if not running; previously the button was a no-op when Spotify was already a running process
- **macOS: Eliminated unnecessary mute/seek/unmute on play** — tracks with a jump-start position now pass `position_ms` directly in the Spotify Web API play request body, removing the mute → play → seek → unmute cycle; startup time drops from ~700 ms to ~200 ms
- **macOS: No more "no devices yet" retry delays** — removed per-command device-ID resolution (`GET /me/player/devices`); all Web API commands now target the active device implicitly, which works correctly and saves up to 5 s of retries
- **macOS: Pause no longer mutes audio** — `pausePlayer()` on macOS now calls pause directly without setting volume to 0 first; muting before pause is only needed on iOS/Android for system-volume fade
- **macOS: "No active device" error shows a dialog** — when Spotify returns "Player command failed: No active device found", a dialog is shown with an "Open Spotify" button instead of silently failing

## [2.5.5] - Release 2026-03-04

### Fixed
- **macOS: "No active device found" on play/resume/volume** — all Spotify Web API commands now resolve the best available device (`GET /me/player/devices`) and pass `device_id` explicitly, so playback works even when Spotify has not been used recently and is not yet the active device
  - Device ID is cached after first resolution; cache is cleared on token refresh to avoid stale state
  - Play retries device resolution up to 5× (1 s apart) when Spotify has just launched and hasn't registered with the Web API yet

## [2.5.4] - Release 2026-03-03

### Fixed
- **Volume stuck at 0 after pause then play (no start time)** — playing a song without a start time after pausing could leave audio silent
  - Root cause: `pausePlayer()` mutes before pause; the system-volume listener fires during the mute and resets `repo.volume` to 0; a subsequent play with `jumpStart == 0` skipped all volume handling, leaving the system volume at 0
  - Fix: `playTrackAndJumpStart` now calls `_restoreVolume(savedVolume)` before playing even when `jumpStart == 0`, ensuring volume is always correct regardless of prior mute state

## [2.5.3] - Release 2026-03-03

### Added
- **djMatchDay song name on card** — each playlist card now shows the current track name and artist at the bottom, updating immediately as you navigate with ◄ ►
- **djMatchDay now-playing bar** — compact `♪ Song  •  Artist` row above the bottom control buttons on phones; song name + artist below album art in the sidebar on tablets/wide screens

## [2.5.2] - Release 2026-03-03

### Fixed
- **iOS Spotify idle disconnect** — connection was dropping after a few minutes of inactivity between song plays
  - Root cause: `SPTAppRemote` uses a local socket to Spotify; without any traffic the socket goes idle and Spotify closes it
  - Fix: subscribe to player state immediately after `appRemoteDidEstablishConnection` — Spotify now pushes periodic state updates, keeping the socket alive
- **iOS Spotify disconnect on Control Center / notification shade** — every swipe-down was dropping the connection
  - Root cause: `applicationWillResignActive` fires for any transient focus loss (Control Center, alerts, incoming call banners), not just true backgrounding
  - Fix: moved disconnect to `applicationDidEnterBackground` and reconnect to `applicationWillEnterForeground`
- **iOS reconnect requires two taps** — first tap on "Reconnect" failed, second tap succeeded
  - Root cause: `initiateSession()` opens Spotify asynchronously; `appRemote.connect()` fired before Spotify finished starting
  - Fix: `forceFullReconnect()` now waits 3 s and retries once after a failed step-2 attempt

## [2.5.1] - Release 2026-03-03

### Fixed
- **iOS Spotify reconnect** — after a period of inactivity Spotify could become unreachable, causing `[Error] Failed to play. Spotify Remote is not connected`
  - Root cause: `SPTSessionManager.storedSession` was still valid, so `getAccessToken` returned a cached token without opening Spotify; `SPTAppRemote.connect()` then failed because the Spotify app was not running
  - Fix: new `clearSession` native method resets `storedSession` and disconnects the old `appRemote`; `forceFullReconnect()` calls this before reconnecting, forcing `initiateSession()` which opens Spotify and guarantees it is running before `appRemote.connect()` is attempted
- **iOS zombie connection** — `SPTAppRemote` could show `isConnected=true` but reject play/pause commands with a 404-style error (details was `nil`, blocking the auto-reconnect logic)
  - Fix: play/pause/resume/seekTo Swift callbacks now set `details` to `"SpotifyDisconnectedException"` when `isConnected=false`, or the error description otherwise; `_needsReconnect()` extended to catch `PLAY_ERROR`, `PAUSE_ERROR`, `RESUME_ERROR` codes
- **djMatchDay reconnect dialog** — when a play fails with a connection error, a dialog is shown offering to reconnect; uses `forceFullReconnect()` so reconnect matches the app-start behaviour
- **Frequent Spotify auth dialog** — reconnecting after the app was backgrounded no longer triggers a full Spotify authorization dialog every time
  - `AppDelegate` now calls `appRemote.disconnect()` on `applicationWillResignActive` (prevents zombie connections) and `reconnectIfNeeded()` on `applicationDidBecomeActive` (silently re-establishes the socket using the cached token)
  - `forceFullReconnect()` now tries a *soft* reconnect first (keeps the native `SPTSession`, only resets Dart-side caches); only falls back to `clearSession` + `initiateSession` if the soft reconnect fails (e.g. Spotify app truly not running)
- Added `NSLog` tracing throughout `SpotifyNativeChannel.swift` for easier debugging of connection issues

## [2.5.0] - Release 2026-03-02

### Added
- **djMatchDay** — new match day view with playlist grid, per-section labels (Hotspot, Match, Fun Stuff, Pre-Match), animated track carousel cards with album art, prev/next navigation, and auto-advance after play
- **Responsive home page** — AppBar adapts to screen width; narrow (< 600 px) collapses overflow actions into a `PopupMenuButton`; djMatchDay and djMatchCenter accessible from menu on all screen sizes

### Changed
- **djMatchCenter & djMatchDay** — on portrait / landscape phone (width < 600 px or height < 500 px) the control buttons move to a compact bar at the bottom instead of a sidebar, ensuring full accessibility on small screens
- **Edit Playlist & Edit Track screens** — redesigned with modern responsive layout: stacked on narrow screens, side-by-side on wide screens; consistent section containers with color accent
- **Playlist list view** — type color stripe on left edge of each card, compact icon-only trailing on narrow screens
- **Playlist tracks view** — green counter badge, compact icon buttons on narrow screens, album art + full buttons on wide screens
- **TypeFilter bar** — replaced fixed-width overflow row with horizontal scroll

### Fixed
- Toast notifications now appear above the compact bottom control bar on phones (added `margin: EdgeInsets.only(bottom: 110)` when compact bar is active)
- Portrait blank space in djMatchDay grid removed (`padding: EdgeInsets.zero` on `GridView.builder` prevents inheriting status-bar top padding)
- Sidebar scroll on landscape phones — `CenterControlWidget` wrapped in `SingleChildScrollView`, removed blocking `Expanded` widgets

### UI
- Delete buttons on playlists and tracks now show a confirmation dialog with clear description of what will be deleted

## [2.0.1] - Release 2026-02-28

### Fixed
- iOS/iPad: `play`, `pause`, `resume`, `seekTo` native channel calls no longer hang when Spotify Remote is not yet connected — now immediately returns `SpotifyDisconnectedException` which triggers automatic reconnect-and-retry
- High CPU: volume feedback loop broken — `setVolume()` no longer writes back to the system volume it just received from the iOS volume listener; added drift threshold guard (< 0.005) in match center volume listener
- High CPU: Spotify reconnect logic moved from `StreamBuilder` builder to a `StreamSubscription` in `initState` — reconnect no longer fires on every unrelated `setState` call in the home page
- Match center carousel now uses `ref.watch` for its playlist so it reflects track reorders after shuffle-at-end

## [2.0.0] - Release 2026-02-26

### Added
- Native Spotify integration for macOS and iPad/iOS via SPTAppRemote + SPTSessionManager (iOS) and Spotify Web API + PKCE OAuth (macOS)
- `SpotifyPlatformBridge` factory — routes iOS/macOS to native channel, Android to spotify_sdk
- Utilities gear icon in app bar replaces "Start times" button; tooltip shows "Utilities"
- Utilities page: new "Copy all playlist URI and type (JSON)" button — copies name, spotifyUri and playlistType for all playlists to clipboard
- `flutter_volume_controller` replaces `volume_controller` — adds macOS and iPad volume support

### Fixed
- Simplified some pages
- Added utility for copy playlist and track start times
- High CPU usage: stream refactoring, refacored to use `useMemoized`
- Refactored reconnect storm and auth  multiple concurrent
- `SpotifyRemoteRepository.connect()` now guarded with `_isConnecting` to prevent concurrent reconnect attempts across all platforms

## [1.7.1] - Release 2025-09-04

## Added
- Track shotcuts, add a player number on track
- Version is visible

## Fixed
- Fixed async spotify remote 
- Bug fixes on track carousel - new flutter version useMemoized
- Spotify subscribe connection only when Spotify plugin is available. 

## [1.6.1] - Release 2025-02-16

### Added
- Spotify preview play volume setting
- Track starttime added input text field edit
- Edit track with update & goto next track
- Added shortcut for tracks
- Show Shortcut Tracks in MatchCenter

### Fixed
- Deleting playlist do not delete tracks that are on other playlists
- Delete a track from playlist. Dont delete if still used.

## [1.6.0] - Release 2025-02-15

### Fixed
- Playlist tracks carousel, wrong viewport dimension

## [1.5.0] - Release 2025-02-15

### Added
- Second spotify uri, for more tracks
- dj Center playlistsorting by position


## [1.1.0] - Release 2025-01-24

### Added
- Playlist fields, position, shuffle and autoNext
- dj Center testing, playing with Sliver...
- Edit tracks
- Sync spotify playlist
- Android build issues, Gradle, Spotify SDK, JVM

## [1.0.0] - UNRELEASED

### Added
- Playlist fields, position, shuffle and autoNext 
- dj Center testing, playing with Sliver... 

### Fixed
- Lots of bug fixes

## ############################### ##
## 29 AUGUST 2024 22:57 FIRST DOC  ##
## ############################### ##
