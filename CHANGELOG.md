# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
