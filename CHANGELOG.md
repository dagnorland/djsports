# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [4.1.0] - Release 2026-10-08

### Added
- **Spotify account & device visibility** (iOS + macOS) — the home AppBar
  now shows `account → device` coloured by status; tapping it opens a
  "Spotify output" sheet with the logged-in account (name, email, Premium),
  every Spotify Connect device on the account, and a device selector
  - By default djSports sends no `device_id` and follows the device chosen
    in Spotify. Only a device set with the explicit **Set device** button is
    remembered (Hive `settings`: `spotifyPreferredDeviceId/Name`) and sent
    as `device_id` on play/resume; **Clear** returns to following Spotify
  - **Set device** also transfers Spotify playback to that device right
    away (`PUT /me/player`, play/pause state kept — the public equivalent
    of the web player's "Connect to a device"); a refusal is shown in red
    in the sheet
- **macOS: djSports player** (default) — djSports runs Spotify's Web
  Playback SDK in a hidden WebKit view and shows up as its own Spotify
  Connect device "djSports" (marked "WebKit playback (recommended)" in
  Spotify output). Plays for this Mac go there with `device_id` +
  `position_ms`: no Spotify app needed, start positions land exactly,
  pause/resume go straight to the player, and fade-pause lowers only the
  player volume (the Mac's system volume is left alone; +/- no longer also
  sets the player's Spotify volume). Works around Spotify for Mac
  1.3.3.264 accepting Web API plays (204) without loading the track
- **macOS: now-playing panel** for the djSports player, below every screen
  while it is the active Spotify device — cover, title, artist, album,
  position (slider to seek), play/pause. Drag the top edge to resize
  (cover and text grow with it), collapse to a slim bar and back (Hive
  `settings`: `webPlayerPanelVisible`, `webPlayerPanelHeight`). In Let's
  Play the controls drop their own cover/track while the panel shows it
- **macOS: "This Mac plays through"** in Spotify output — djSports player
  (default), Spotify app via AppleScript, or Spotify app via Web API (Hive
  `settings`: `spotifyMacPlayback`). A device chosen with Set device always
  wins. If the djSports player fails, plays fall back to AppleScript, then
  the Web API. AppleScript start positions wait for a fresh start and are
  re-checked at 0.5 s / 1.2 s; djSports takes focus back when Spotify raises
  its window (sandbox exception `temporary-exception.apple-events` for
  `com.spotify.client`)

- **Let's Play controls: Left / Right / Bottom** (Settings) — on wide
  screens the controls can now also run as a bar along the bottom. Bottom
  is used only when the board keeps at least 480 px of height; otherwise
  the controls go to the right. Replaces the "Sidebar on right" switch
  (Hive `settings`: `sidebarPosition`; the old `sidebarOnRight` value is
  carried over)
- **Let's Play and the now-playing panel are always dark** — a "stage"
  palette like Spotify/Tidal and DJ software (`lib/core/theme/stage_colors.dart`:
  #121212 background, #1E1E1E tiles, #181818 panel, white text, grey
  secondary text), easy on the eyes in a dim arena and high-contrast in
  bright light. The only colours are the playlist type colours (Hotspot
  red, Match green, Fun Stuff blue, Pre-match grey); the display colour
  from Settings is no longer used there
- **Let's Play tiles, Spotify-style** — cover on the left with a round
  play button in the type colour, then the track name in bold (up to two
  lines on taller tiles), artist in grey and the start time; ‹ › moved up
  next to the #n/m counter, the duplicate track line at the bottom is
  gone, so titles get far more room. The faded cover background (20 %)
  sits behind a dark veil so busy covers don't compete with the text. On
  narrow tiles (iPhone) the arrows give way to the playlist name; swipe a
  tile left/right to change track (works on every tile)
- **iOS 27 launch** — migrated to the UIScene lifecycle; the app quit right
  after the launch screen on iOS 27
- Apple Music `prewarmCache` no longer throws `MissingPluginException` on iOS
- **Cloud backup restore of Apple Music** — a full restore dropped each
  track's `appleMusicId`, so restored Apple Music tracks couldn't play;
  sync restore only de-duplicated by Spotify URI and re-added Apple Music
  playlists on every sync (now also matched by `appleMusicPlaylistId`)
- **macOS: Set device on the djSports player** survives a restart — the
  player gets a new device ID every launch, and a stale one gave 404
  "device no longer available"; the choice now moves to the new player
- **Android: start positions** — the seek right after play failed on slow
  devices ("Cannot seek in song: [UNKNOWN]", 8 attempts back to back) and
  the track started from 0. Now the seek fires the moment Spotify pushes
  the "new track playing" event (`subscribePlayerState`; 150 ms poll as a
  fallback, max ~3 s), with 50 ms between seek attempts and no extra
  request before play; a failed seek no longer fails the play
- **Android: Apple Music tracks** (e.g. from a restored backup) crashed
  with an unhandled `MissingPluginException` – Apple Music exists on
  iOS/macOS only. Tracks with both IDs now play via Spotify on Android;
  Apple-Music-only tracks show "Apple Music is only available on iPhone,
  iPad and Mac". One shared rule `playsWithAppleMusic()` is used by Let's
  Play, the track list, the track editor and pause/resume
- **Home: Let's Play hidden while there are no playlists** (the welcome
  screen is shown then)
- **Welcome screen "backup(s) found" dialog overflow** on tablets with the
  keyboard up (128 px) — the content scrolls
- **Black screen when leaving Let's Play** — the back button popped the
  screen's own nested MaterialApp instead of returning home (a builder's
  `context` shadowed the screen's); all back buttons now go through one
  `_close()` that always uses the screen's context
- **Let's Play compact bar overflow on iPhone** ("RIGHT OVERFLOWED BY
  2.0 PIXELS") — nine buttons now use 36 pt tap areas (same icon sizes) and
  the row shrinks slightly on phones narrower than ~340 pt
- **Let's Play card overflow** ("RenderFlex overflowed", 2 px on macOS,
  ~22 px on iPhone) — the new tile layout scales with the tile size
  - Warns when Spotify on this Mac is running but missing from the
    account's device list — i.e. the Spotify app is signed in with a
    different account than djSports
  - Every play logs `Playing on <device> as <account>`
- **Play check** — ~1.5 s after each play (iOS/macOS) djSports asks Spotify
  what is actually playing (`GET /me/player`) and logs a `[PLAY-CHECK]`
  line. If Spotify accepted the command (204) but the device didn't switch
  or the track didn't load, an error toast explains it — e.g. a Mac whose
  Spotify app can't be controlled remotely (stale Spotify Connect
  registration after switching account in the Spotify app)
- **"Where should djSports play?" prompt** — when no usable device exists
  (or the set one is gone), playback asks instead of guessing, then
  retries once on the picked device (not remembered). Used by Let's Play, the playlist track list
  and the track editor preview
- **"Show system volume popup" setting** (Android/iOS, Settings) — off by
  default: djSports' own volume changes (+/−, fade, mute) no longer pop up
  the system volume slider, which covered the Let's Play sidebar on the
  right (Hive `settings`: `showSystemVolumeUI`). On Android the hardware
  volume buttons still show it
- **"Show info messages" setting** (Settings) — off by default: Let's Play
  no longer pops up info toasts ("PAUSED", "FADED", "↩ Back to start",
  the track that started, "Reconnecting…"). Warnings and errors (a failed
  play, "Spotify Premium required", "Failed to reconnect", "Volume
  auto-set to 85%") always show, now coloured by type. One shared
  `showAppToast()` in `lib/core/app_toast.dart` (Hive `settings`:
  `showInfoToasts`)
- **Let's Play: clear EXIT button that never scrolls away** — a ✕ in a
  ring labelled "EXIT" replaces the ⌫ icon, in the fixed part of the
  controls (bottom of the sidebar, right end of the bottom bar, and in the
  phone bar). Help and the debug log moved into the scrollable controls;
  before, a short portrait sidebar could hide the way out
- **Let's Play: tap the djSports logo** for a little stage-light flash –
  two quick blinks and a pulse, and the version number glows amber. Just
  for fun
- **Home: the djSports logo opens Let's Play** — the floating "Let's
  Play!" button is gone; the logo (with the same flash) sits in the AppBar,
  with the label on wide screens, and opens Let's Play right after the
  flash. Phones get a visible way in instead of only the ⋮ menu. Shared
  widget `lib/core/widgets/flashing_logo.dart`
- **Home page in the dark stage look** — with playlists, the home page
  uses the same palette as Let's Play (dark background and cards, white
  text, type colours as the only colours) instead of light cards tinted
  by the display colour (a red/pink sheen with "Red"). Pre-match's black
  type colour becomes grey there (`stageTypeColor()`). The welcome screen
  (no playlists yet) keeps its light design; the playlist edit page is
  unchanged
- **Track editor: bigger previous/next buttons** — round 44 px buttons
  (were 32 px with a 22 px icon) on either side of the "3 of 12" counter,
  easier to hit on a tablet; hidden when creating a new track
- **Settings: Playlists and Start times moved under ⋮** — the Settings
  screen now has three tabs (Settings, Spotify, Apple Music); the two old
  tabs open as their own pages from the ⋮ menu at the top right, marked
  "Legacy – will be removed"
- **Display colour choice removed** (Settings → "Display settings") — the
  app always uses black as its base colour; the colour picker,
  `themeColorProvider` and the `themeColor` setting are gone. The home
  page's "#18" track count is now an inverted badge (white on the dark
  cards, black on light pages)
- **Let's Play tiles fill the width** — the column count followed only
  the window width (~200 px per column), so a wide Mac window had 7
  columns for at most 4 playlists per section and the right half stayed
  empty. Now every section gets as many columns as the largest section
  needs, with tiles never narrower than ~180 px – wider tiles, more of the
  track names visible. The missing-cover icon in the controls is light
  grey on the dark stage
- **Cloud Backup in the dark stage look** — same palette as the home page
  and Let's Play, including its dialogs; destructive actions (delete,
  "Restore") and errors stay red. The stage palette got light outlines,
  labels and cursor for input fields (`inputDecorationTheme`), which the
  editors can use later
- **Home page: Spotify-style playlist cards** — chips at the top (All +
  one per type with its colour and count); "All" shows one horizontal
  shelf per type, a single type shows a grid of bigger cards. Each card
  has a square cover (2×2 mosaic of the first four different covers, or a
  single cover), a round edit button in the type colour, a ⋮ menu (Open in
  Spotify, Delete), and the name with "18 tracks · 12 with start".
  Reorder within a shelf (the order still drives Let's Play): long-press
  and drag on phones/tablets, grab and drag with the mouse on the Mac (a
  click still edits). 210 px cards with 16 px gaps on tablet/Mac
  landscape, ~2.2 per shelf on phones. On very wide screens two
  neighbouring sections share a row (Hotspot | Match, Fun Stuff |
  Pre-match) when both fit in half the width, so all playlists show
  without scrolling. Replaces the list rows
  (`DJPlaylistView` removed)

### Changed
- Playback never silently falls back to the first device in the list
  (could be a phone or speaker elsewhere). macOS only auto-uses this Mac;
  iOS only auto-activates this iPhone. Native errors are now typed
  (`NO_ACTIVE_DEVICE` with the device list, `PREMIUM_REQUIRED`)
- "Switch Spotify account" now forces Spotify's login / account picker
  (`show_dialog=true`, ephemeral browser session) instead of silently
  logging back into the same account
- Added the `user-read-email` scope so the account email is shown (takes
  effect after the next Spotify login)
- **Android build for Flutter 3.47** — Gradle 8.11.1 → 8.14.3, Android
  Gradle Plugin 8.9.1 → 8.13.0, Kotlin 2.1.0 → 2.3.20 (Flutter 3.47's
  minimums are 8.14 / 8.11.1 / 2.2.20); `kotlinOptions` replaced by
  `kotlin { compilerOptions }`. Flutter's migrator added
  `android.builtInKotlin=false` / `android.newDsl=false` (AGP 9 opt-outs).
  AGP 9 / Gradle 9 left for a separate step
- Android: added `com.fasterxml.jackson.core:jackson-annotations` – the
  Spotify App Remote SDK's types use Jackson annotations without shipping
  them, so Android logged "Unable to resolve … annotation class 27/30" for
  every player-state event
- Debug log: **Copy** button – copies the whole log as plain text (app
  version, OS, native state, devices, then all entries oldest first) to
  paste into a mail or a chat
- Debug log: every Spotify play now reads `play track "<name>" <uri> ·
  start 1:44 · startup 1338 ms` (start position and time until the track
  played, also for plays from 0:00)
- `flutter_volume_controller` 1.3.4 → 2.0.2 (compileSdk 36 – AGP 8.13
  rejected the old plugin's compileSdk 31; API unchanged)
- **Android on Gradle 9 / AGP 9** — Gradle 8.14.3 → 9.3.1, Android Gradle
  Plugin 8.13.0 → 9.1.0, Kotlin 2.3.20 → 2.4.0, Google Services 4.3.15 →
  4.4.4, foojay 0.8.0 → 1.0.0; Flutter's "support will soon be dropped"
  warning is gone. `buildDir` → `layout.buildDirectory` (removed in
  Gradle 9); the dead `include ":spotify-sdk"` (folder never existed –
  Gradle 9 rejects it) removed; the app no longer applies `kotlin-android`
  itself (as in Flutter's template). `android.builtInKotlin=false` /
  `android.newDsl=false` stay, as in Flutter 3.47's template, until
  `spotify_sdk` 4 – `audio_session` 0.2.4 and `package_info_plus` 10.2.2
  already support Built-in Kotlin

## [4.0.0] - Release 2026-10-06

First release under the new Apple Developer account (Team ID `4SRFW7L9XH`),
after transferring the app from Flow Retail.

### Added
- **Bring Your Own Spotify Client ID** — Spotify's February 2026 Development
  Mode rules limit each Client ID to 5 authorized users, so the bundled
  credentials cannot serve all users. Each user can now enter their own
  Client ID, Client Secret and redirect URI (from their own free app in the
  Spotify Developer Dashboard) in a new Settings → Spotify Account section
  - Credentials are stored locally in the Hive `settings` box and never
    leave the device; clearing them reverts to the bundled `.env` fallback
    (developer builds)
  - New `spotifyCredentialsProvider` resolves user credentials first, then
    `.env`; the Spotify remote and search repositories watch it, so saving
    new credentials reconnects without an app restart
  - Client ID validated as a 32-character hex string; redirect URI defaults
    to `djsports://callback`
  - In-app step-by-step instructions for creating the Spotify app
    (requires a Spotify Premium account per Spotify's new rules)

### Changed
- `.env` is now optional at startup — end-user builds run without it and
  rely on user-supplied credentials; startup logging no longer prints
  secret values, only the loaded keys
- **Apple Developer account moved** — app transferred from Flow Retail to
  the new team `4SRFW7L9XH`; `DEVELOPMENT_TEAM` updated in all iOS and
  macOS build configurations and in the App Store export options
- **Toolchain upgrade** — Flutter 3.47.6 (via FVM) and Xcode 27; iOS
  project format upgraded (`objectVersion 77`)
- Xcode Cloud configuration removed (required for the app transfer)

## [3.5.2] - Release 2026-05-14

### Added
- **Volume fade on pause** — new "fade pause" button in the Let's Play screen
  that smoothly ramps the system volume to 0 before pausing Spotify, then
  restores the original volume on the next play/resume
  - Configurable fade duration (0–10,000 ms) via a new slider in Settings →
    Display; `0` disables the feature and hides the button
  - Linear ramp with platform-tuned step cadence: 20–60 ms steps on
    iOS/Android for a smooth sweep; 100–200 ms steps on macOS to avoid
    Spotify Web API rate limits (macOS fades both Mac master volume and the
    active Spotify Connect device via `PUT /me/player/volume`)
  - `fadePausingNotifier` (`ValueNotifier<bool>`) disables the button while
    a fade is in flight; pressing play mid-fade cancels the sweep and
    immediately restores volume via the existing `resumePlayer` path
  - Android hint shown in Settings when fade < 750 ms (system volume uses 15
    discrete steps and short fades can sound stepped)
  - Falls back to instant pause for Apple Music tracks (fade is Spotify-only)

### Fixed
- **macOS: Dart VM service crash on launch** — added
  `com.apple.security.network.server` to `DebugProfile.entitlements`; the
  Dart VM service needs to bind a local socket for DevTools / hot-reload
- **Android: NDK version mismatch** — bumped `ndkVersion` in
  `android/app/build.gradle` to `28.2.13676358` (required by `jni` plugin)
- **Android: `ClassNotFoundException: io/flutter/util/PathUtils`** — pinned
  `path_provider_android` to `2.2.7` via `dependency_overrides`; versions
  ≥ 2.2.8 use JNI bindings that fail to resolve the Flutter embedding class
  at runtime on some devices

## [3.5.1] - Release 2026-04-24

### Fixed
- **macOS App Store compliance** — removed unused `com.apple.security.network.server`
  entitlement from Release and DebugProfile entitlements; the app only makes outgoing
  connections (`network.client`) and does not act as a network server

## [3.5.0] - Release 2026-04-15

### Added
- **Apple Music integration (iOS + macOS)** — full MusicKit-based playback alongside
  Spotify; no OAuth / developer dashboard registration required
  - iOS: `MPMusicPlayerController.applicationQueuePlayer` via native `AppleMusicNativeChannel`
  - macOS: `ApplicationMusicPlayer` (requires macOS 12.0+); 350 ms seek delay after play
  - Dart bridge (`apple_music_platform_bridge.dart`) + repository (`apple_music_repository.dart`)
    mirror the Spotify repo interface: `playTrackAndJumpStart`, `pausePlayer`,
    `resumePlayer`, `search`, `syncPlaylist`
  - `appleMusicId` field added to `DJTrack` (HiveField 12); `DJTrack.fromAppleMusicTrack()`
    factory constructor; Hive adapters regenerated
  - Per-track playback routing: `appleMusicId.isNotEmpty` → Apple Music; otherwise → Spotify
  - Spotify error-recovery dialogs (reconnect, no-device) gated on Apple-Music-only tracks
  - Apple Music search delegate (`apple_music_search_delegate.dart`) — same grid layout
    as Spotify search; returns `AppleMusicTrack` for adding to playlists
  - Playlist sync from Apple Music catalog playlists by ID
  - Apple Music diagnostics tab in Settings (`apple_music_diagnostics_tab.dart`)
  - Connection status icon (music_note, pink = connected) on home page AppBar for
    both iOS and macOS; subscribes to native EventChannel on startup
  - `NSAppleMusicUsageDescription` added to iOS + macOS `Info.plist`
  - `com.apple.developer.musickit` entitlement added to macOS Debug + Release entitlements
  - iOS Runner entitlements file (`Runner.entitlements`) added with MusicKit key
  - macOS deployment target bumped to 12.0

## [3.4.5] - Release 2026-04-05

### Added
- **Playlist Help screen** — step-by-step guide covering: adding playlists
  with +, setting playlist type, pasting a Spotify URI, syncing tracks, and
  editing track start times; accessible via the `?` icon in the AppBar (wide)
  or the ··· popup menu (narrow)
- **Let's Play Help screen** — guide for the live DJ view covering: tapping a
  card to start, Auto Next behaviour, browsing tracks with < / >, adjusting
  volume, and using the ⌫ button to return home; accessible via the `?` icon
  in the sidebar and compact control bar

## [3.4.5] - Release 2026-04-03

### Added
- **Playlist drag handle** — optional `dragHandle` widget prop added to
  `DJPlaylistView`; the drag icon (≡) now renders inside the row rather than
  wrapping the entire card in a `ReorderableDragStartListener`

### Fixed
- **Playlist edit state init** — moved `super.initState()` to first line;
  deferred Riverpod reads to `addPostFrameCallback` with a `mounted` guard;
  changed `ref.watch` → `ref.read` in `syncMissingStartTimes` to prevent
  calling `watch` outside of `build`
- **Spotify connection stream** — added `onError` / `cancelOnError: false`
  handler so stream errors are logged and the listener is not silently cancelled
- **iOS build (Firebase + Xcode)** — added BoringSSL-GRPC `HEADER_SEARCH_PATHS`
  workaround in `ios/Podfile` to fix build failures on newer Xcode with Firebase

### Chore
- `.gitignore` — added `android/.kotlin/sessions/*` and `macos/.DS_Store`
- `android/build.gradle` — removed duplicate `subprojects` block

## [3.4.4] - Release 2026-04-03

### Changed
- **Prepping for Google Play** — renamed Android package from `com.example.djsports`
  to `com.dagnorland.djsports`; APK output now named `djsports-<version>.apk`

## [3.4.3] - Release 2026-04-03

### Added
- **Firestore index** — `firestore.indexes.json` defines a composite index on the
  `backups` collection (`profileName ASC`, `createdAt DESC`) for efficient backup
  lookups; `firestore.rules` and updated `firebase.json` added to support
  `firebase deploy --only firestore:indexes`

## [3.4.2] - Release 2026-04-02

### Added
- **Cloud Backup: Sync restore** — new "Sync (↓)" action on each backup tile adds
  only playlists (with their tracks and timings) that are not already present
  locally (matched by Spotify URI); existing playlists are left untouched

### Fixed
- **Full restore tracks blank until restart** — `hive_ce`'s `Box.clear()` is
  async; it was not awaited before the subsequent `add()` calls, so the deferred
  clear wiped the freshly added tracks from the in-memory map; fix: `await`
  the clear in all three repositories (`DJPlaylistRepo`, `DJTrackRepo`,
  `TrackTimeRepo`) before writing restored data
- **Post-restore welcome screen flash** — replacing `ref.invalidate` with direct
  `fetchDJPlaylist()` / `fetchDJTrack()` / `fetchTrackTimes()` notifier calls
  eliminates the null-state gap that briefly showed the first-time-use screen
- **Spotify "New tracks found" false positive after restore** — `getDJTracksSpotifyUri`
  now reads from Riverpod state (populated after restore) rather than a potentially
  stale repo snapshot
- **RangeError crash in playlist tile** — `DJPlaylistView` accessed `allTracks[idx]`
  before guarding `idx >= 0`; fixed check order

## [3.4.0] - Release 2026-03-31

### App Store prep
- **PrivacyInfo.xcprivacy** added to `ios/Runner/` — declares UserDefaults
  (CA92.1), FileTimestamp (C617.1) and DiskSpace (E174.1) API access; declares
  Spotify user ID and user-created playlist content as collected data (app
  functionality only, no tracking)
- **`CFBundleDisplayName`** corrected from `"Djsports"` to `"djSports"`
- **`UIBackgroundModes`** — `audio` and `fetch` added to Info.plist for
  background audio playback via `audio_service`
- **`LSApplicationCategoryType`** set to `public.app-category.music`
  (was empty string)

### Added
- **Welcome / first-time-use screen** — shown when no playlists exist; covers
  Spotify connection steps, playlist type guide, how to add playlists, Profile &
  Device Name setup, and a one-tap *djSports Example Setup* button
- **djSports Example Setup** — creates 5 real Spotify playlists (HotSpot,
  Match ×2, Fun Stuff, Pre Match) by syncing directly from Spotify; live
  per-playlist progress indicator shows pending → syncing → done/error
- **Login to Spotify button** on the welcome screen — clears the current
  session and triggers a fresh PKCE OAuth flow; shows the connected account
  name and user ID after a successful login
- **Cloud Backup: Profile + PIN** — backups are now keyed on a shared
  *Profile name* + 4-digit PIN instead of Spotify user ID, so multiple
  devices can share the same backup pool without using the same Spotify
  account; PIN visibility toggle added on both the welcome screen and the
  Cloud Backup settings screen
- **Spotify account info moved to Settings → Spotify tab** — display name and
  user ID are now shown in the Spotify Diagnostics tab instead of the Cloud
  Backup screen
- **Spotify URI field on track edit screen** — the URI field was wired but not
  visible; it is now shown and editable in the track metadata section
- **Check for backups** button on the welcome screen — looks up existing cloud
  backups for the saved Profile + PIN and offers to open Cloud Backup for
  restore

### Fixed
- Sample/example playlists with an empty Spotify URI no longer trigger the
  duplicate-URI guard in the playlist repository

## [3.3.2] - Release 2026-03-29

### Added
- **Playlist reordering** — playlists can now be drag-reordered within each
  type section on the home page; the new order is persisted via the `position`
  field; the full tile acts as the drag handle (no separate icon)

### Fixed
- **Auto-next respects playlist setting** — advancing to the next track after
  playback now only happens when the playlist's *Auto Next* toggle is enabled
- **Shortcut key badge no longer overlaps track counter** — the keyboard
  shortcut badge in the match-day card is now inline in the header row, left
  of the playlist name, so it no longer covers the `#1/5` track counter

## [3.3.1] - Release 2026-03-27

### Changed
- **Settings screen refactored** — `TrackTimeCenterScreen` is now a unified
  tabbed Settings screen with four tabs: Settings, Playlists, Start Times, and
  Spotify Diagnostics; replaces the old single-purpose track-time-only screen
- **`DJLetsPlayViewPage`** — match-day view extracted into its own
  `lib/features/djletsplay/` feature, replacing the old `djmatch_day` feature

### Fixed
- Typo in start time tab: "crrently" → "currently"

## [3.3.0] - Release 2026-03-27

### Added
- **Start-time slider** — the track edit screen now uses a `CupertinoSlider`-based
  start-time picker with 10 ms step precision; a floating `MM:SS.mmm` label tracks
  the thumb in real time; `±` nudge buttons allow fine adjustment
- **Live playback position on slider** — while previewing a track the slider updates
  every 500 ms to show the current Spotify playback position, making it easy to
  set the exact start time by ear
- **`getPlaybackPositionMs()`** — new method on `SpotifyRemoteRepository`; polls
  `GET /v1/me/player` (`progress_ms`) on iOS/macOS and delegates to the SDK on Android
- **Cupertino button widgets** (`dj_buttons.dart`) — shared `DJPrimaryButton`,
  `DJCancelButton`, `DJIconActionButton`, and `DJTextIconButton` replace ad-hoc
  `ElevatedButton`/`TextButton` usages throughout the app
- **Dynamic app theme color** — primary color can be changed from 7 curated options
  (Black, Electric Blue, Spotify Green, Sun Yellow, Amber, Purple, Red); choice is
  persisted across sessions via a new `themeColor` Hive settings key
- **Theme color picker in Settings** — circular color swatches with a selection ring
  appear in the Display Settings section

### Changed
- **`AppTheme.themeFor(Color)`** — theme is now built from the persisted primary color
  instead of being hardcoded to Spotify green; `lightTheme` getter retained as default
- **Home page "Let's Play!" button** — the djMatchDay launch button uses
  `DJPrimaryButton` and is renamed from "djMatchDay" to "Let's Play!"
- **Playlist track view** — album-art error fallback now shows the Spotify logo;
  `playlistType` passed explicitly to each track row

## [3.2.0] - Release 2026-03-26

### Added
- **iOS: Hard pause via long press** — long-pressing the pause button while in silence keep-alive mode does a real pause (stops silence, icon turns white); short press still enters orange silence mode as before
- **macOS/iOS: System volume synced to app on home page** — `FlutterVolumeController` listener is now initialised in the repository constructor so the volume chip updates on all screens, not only inside djMatchDay
- **Spotify user shown in "not active" dialog** — when Spotify has no active device the error dialog now shows the current Spotify display name (or user ID) so it is clear which account needs to be active

### Changed
- **djMatchCenter removed** — the legacy match center page and its exclusive widgets have been removed; `CenterControlWidget` and `CurrentVolumeWidget` are retained as they are shared with djMatchDay and the home page
- **Playlist type filter replaced with dropdown** — the horizontal row of filter buttons on the home page is now a compact inline dropdown, reducing visual clutter
- **Home page AppBar decluttered** — "New playlist" button replaced with a `+` icon; "Connected/Connect" button replaced with a wifi icon (green/red); both retain tooltips

### Fixed
- **macOS: Volume not tracked on home page** — `FlutterVolumeController.addListener` was skipped on macOS (`!Platform.isMacOS` guard removed); volume now updates in real time whenever Mac system volume changes
- **iOS: Long-press pause showed tooltip instead of pausing** — `IconButton` tooltip was intercepting the long-press gesture and showing "Silence playing" with haptic feedback; tooltip removed and `GestureDetector` added for correct long-press handling

## [3.1.0] - Release 2026-03-24

### Added
- **Cloud Backup** — manual backup and restore of all local data (playlists, tracks, track timings) via Firebase Firestore, keyed by Spotify user ID
  - Backs up all playlists, tracks, and track start times to the cloud
  - Restore from any backup with live progress indicators
  - Keeps the last 5 backups per device; oldest is auto-deleted when limit is reached
  - Backups are labelled by user-configurable device name (persisted across sessions)
  - Accessible from the home screen AppBar (cloud icon) and the overflow menu on narrow screens
  - After restore, the home screen playlist list refreshes automatically
- **Spotify user ID on Android** — the app now fetches the Spotify user profile via Web API on Android, enabling cloud backup on all platforms
- **`tracksWithStartTime` in backup summary** — backup tiles show how many tracks have a configured start time

## [3.0.1] - Release 2026-03-24

### Added
- **Android: "Open Spotify" button in match center control panel** — tapping the green `open_in_new` icon launches the Spotify app directly via `spotify:` URI (`url_launcher`); previously the button was iOS/macOS only
- **Android: volume initialised from platform on startup** — `SpotifyRemoteRepository` now reads the real system volume immediately on construction instead of defaulting to 50%
- **Android: auto-set volume to 85% when muted on startup** — if the device volume is 0 when the app launches, it is automatically raised to 85% and a toast "Volume auto-set to 85%" is shown

### Fixed
- **Android: volume not restored after pause → play (no start time)** — `pausePlayer()` now saves the pre-mute volume in `_preMuteVolume`; `_unMute()` restores from that value so the volume listener overwriting `repo.volume` to 0 no longer causes silent playback
- **Android: volume stuck when increasing** — Android media volume uses discrete integer steps (~15); adding 0.05 often floor-truncates to the same step. Now detects a no-change and retries with a 0.07 bump (> 1/15 step size) to guarantee advancement
- **Android: incorrect volume restore after pause → play with start time** — introduced `_isMuted` flag; repo-level `_unMute()` is now only called after `playWithPosition` when we explicitly muted on pause, preventing stale `_preMuteVolume` from overriding the bridge's correct restore when switching tracks without pausing first
- **Android build: upgraded AGP 8.6.0 → 8.9.1 and Gradle wrapper 8.7 → 8.11.1** — required by `url_launcher_android 6.3.x` / `androidx.browser 1.9.0`

## [3.0.0] - Release 2026-03-23

### Changed
- **iOS Spotify integration rewritten to Spotify Web API** — removed SPTAppRemote/SPTSessionManager entirely; iOS now uses the same PKCE OAuth + Web API approach as macOS, eliminating socket-based connection drops and the need for the SpotifyiOS SDK framework
  - No more idle disconnects, Control Center disconnects, or zombie connections
  - Token refresh is fully automatic via stored refresh token in UserDefaults
  - Auto-device fallback: 404 → `GET /v1/me/player/devices` → retry with explicit `device_id`
- **Unified cross-platform bridge** — iOS, macOS share the same Web API playback path; Android retains `spotify_sdk`
- **Tested on iPhone, iPad and macOS** — first release with verified cross-platform Web API playback

### Added
- **iOS: `launchSpotify`** — opens Spotify app via `spotify:` URL scheme when no active device is found
- **iOS: `getDebugInfo`** — returns token/refresh-token state for diagnostics
- **iOS: `getActiveDevices`** — exposes available Spotify devices to Dart layer

### Removed
- **SpotifyiOS SDK framework** — `SpotifyiOS.xcframework` and all SPTAppRemote/SPTSessionManager code removed from iOS target; no Podfile changes required
- **`app-remote-control` OAuth scope** — no longer needed without AppRemote

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
