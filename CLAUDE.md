# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

djSports is a Flutter application for DJs to manage music playlists during sports events. It integrates with Spotify for music playback, uses local Hive database for data persistence, and provides specialized playlist management for different event phases (pre-match, match, hotspots, fun stuff).

## Development Commands

```bash
flutter run --dart-define=DELETE_ALL_DATA=true    # Run and delete all Hive data
```

## Important Conventions

### State Management
- Riverpod with `@riverpod` annotations for code generation
- Uses `AsyncNotifierProvider` and `NotifierProvider` (avoid `StateProvider`)
- Use `ref.invalidate()` to manually trigger updates

### Code Generation
After modifying models, controllers, or providers with annotations:
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

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

### Large Files
- Never read `lib/data/repo/spotify_remote_repository.dart` whole (~24k tokens). Search it, or read only the lines you need.

## Environment Variables
`.env` file contains Spotify credentials (not committed):
- Spotify Client ID
- Spotify Redirect URI
- Other API keys
