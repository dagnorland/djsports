# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

djSports is a Flutter application for DJs to manage music playlists during sports events. It integrates with Spotify for music playback, uses local Hive database for data persistence, and provides specialized playlist management for different event phases (pre-match, match, hotspots, fun stuff).

## Development Commands

### Setup and Dependencies
```bash
flutter pub get                                    # Install dependencies
flutter pub run build_runner build --delete-conflicting-outputs  # Generate code from annotations
```

### Running the Application
```bash
flutter run                                        # Run on connected device/emulator
flutter run -d chrome                             # Run on web
flutter run --dart-define=DELETE_ALL_DATA=true    # Run and delete all Hive data
```

### Testing and Analysis
```bash
flutter test                                       # Run tests
flutter analyze                                    # Run static analysis
```

### Build
```bash
flutter build apk                                  # Build Android APK
flutter build ios                                  # Build iOS app
flutter build web                                  # Build web version
```

## Architecture

### State Management
- **Riverpod 2.x** with `@riverpod` annotations for code generation
- Uses `AsyncNotifierProvider` and `NotifierProvider` (avoid `StateProvider`)
- Providers are generated via `riverpod_generator`
- Use `ref.invalidate()` to manually trigger updates

### Data Layer Structure
```
lib/data/
├── models/          # Hive models with @HiveType annotations and JSON serialization
├── repo/            # Repository pattern for data access (Hive boxes)
├── provider/        # Riverpod providers (generated with @riverpod)
├── controller/      # Business logic controllers
└── services/        # External services (Spotify SDK, audio playback)
```

### Core Models
- **DJPlaylist** (`@HiveType(typeId: 0)`): Playlists with types (hotspot, match, funStuff, preMatch, archived)
- **DJTrack** (`@HiveType(typeId: 1)`): Individual tracks with Spotify URI, start time, shortcuts
- **TrackTime**: Scheduling information for track playback

### Features Structure
```
lib/features/
├── djsports/              # Main home page with playlist list
├── djmatch_center/        # Live match control center with grid layout
├── playlist/              # Playlist CRUD operations
├── spotify_connect/       # Spotify authentication and connection
├── spotify_search/        # Search Spotify catalog
├── spotify_playlist_sync/ # Sync with Spotify playlists
└── track_time/            # Track scheduling and timing
```

### Key Dependencies
- **spotify_sdk**: Native Spotify Remote SDK integration
- **audio_service** + **just_audio**: Audio playback with media controls
- **hive** + **hive_flutter**: Local NoSQL database
- **freezed** + **json_serializable**: Code generation for models
- **flutter_hooks** + **hooks_riverpod**: Reactive state management
- **volume_controller**: System volume control

## Important Conventions

### Code Generation
After modifying models, controllers, or providers with annotations:
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

This generates:
- `.g.dart` files for Hive adapters and JSON serialization
- `.freezed.dart` files for Freezed classes
- Provider code from `@riverpod` annotations

### Hive Database
Three main boxes are initialized in `main.dart`:
- `djplaylist` (Box<DJPlaylist>)
- `djtrack` (Box<DJTrack>)
- `trackTime` (Box<TrackTime>)

Each model must have:
- `@HiveType(typeId: N)` on class
- `@HiveField(N)` on each field
- Registered adapter: `Hive.registerAdapter(ModelAdapter())`

### Spotify Integration
- Authentication via `SpotifyRemoteRepository`
- Access token stored and managed internally
- Connection status monitored via `SpotifySdk.subscribeConnectionStatus()`
- Playback controlled through Spotify Remote SDK

### Audio Service
- `DJAudioHandler` extends `BaseAudioHandler`
- Initialized as provider: `audioHandlerProvider`
- Supports background playback with media controls
- Uses `just_audio` for local MP3 playback

### Widget Patterns
- Use `ConsumerWidget` or `HookConsumerWidget` (not StatelessWidget)
- Create small private widget classes instead of `Widget _buildX()` methods
- Keep lines ≤80 characters with trailing commas
- Use `const` constructors wherever possible

### Error Handling
- Display errors using `SelectableText.rich` with red color (not SnackBars)
- Use `AsyncValue` for loading/error states in async operations
- Handle empty states within the screen itself

### Styling
- Use `Theme.of(context).textTheme.titleLarge` (not deprecated names like `headline6`)
- App theme defined in `lib/core/theme/app_theme.dart`

## Project-Specific Notes

### DJMatchCenter
The main performance view (`djmatch_center.dart`) displays playlists in a responsive grid layout. It:
- Groups playlists by type (hotspot, match, funStuff, preMatch)
- Shows tracks in each playlist via carousel
- Allows quick playback with keyboard shortcuts
- Monitors volume changes and updates Spotify accordingly

### Playlist Types
Playlists are categorized by `DJPlaylistType` enum with specific colors:
- **hotspot**: Red - High-energy moments
- **match**: Green - During gameplay
- **funStuff**: Blue - Entertainment breaks
- **preMatch**: Black - Pre-game atmosphere
- **archived**: Green accent - Historical playlists

### Shortcuts System
Tracks can have numeric shortcuts (1-9) for quick playback in the match center. Implemented via `shortcut` field on `DJTrack` model.

### Environment Variables
`.env` file contains Spotify credentials (not committed):
- Spotify Client ID
- Spotify Redirect URI
- Other API keys

## Testing
Tests are minimal. Single test file at `test/widget_test.dart`.