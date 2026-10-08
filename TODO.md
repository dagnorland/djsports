# djSports – TODO

Things to do later. Newest decisions and context are in `CHANGELOG.md`.

## Next

### Android: Built-in Kotlin via `spotify_sdk` 4
Gradle 9.3.1 / AGP 9.1.0 / Kotlin 2.4.0 are done (branch
`feature/android-gradle-9`). One warning is left on every Android build:

> WARNING: Your app uses the following plugins that apply Kotlin Gradle
> Plugin (KGP): audio_session, flutter_volume_controller, spotify_sdk
> Future versions of Flutter will fail to build …

`audio_session` and `flutter_volume_controller` already support Built-in
Kotlin – they only apply KGP because `android.builtInKotlin=false`, which
`spotify_sdk` 3.0.2 still needs. So the fix is `spotify_sdk` 4.x, then
`android.builtInKotlin=true` (and later `android.newDsl=true`).

`spotify_sdk` 4 is a real migration (see its CHANGELOG "Breaking Changes"):
- [ ] Spotify Android Auth SDK 2 → 5: register
      `RedirectUriReceiverActivity` in `AndroidManifest.xml` (scheme/host of
      our redirect URI); drop the `redirectSchemeName` / `redirectHostName`
      manifest placeholders in `app/build.gradle`
- [ ] App Remote SDK is downloaded by the plugin: remove
      `include ":spotify-app-remote"`, the `android/spotify-app-remote`
      folder and `implementation project(':spotify-app-remote')` /
      `com.spotify.android:auth:2.1.0` in `app/build.gradle` (check the
      `jackson-annotations` line is still needed)
- [ ] Typed errors (`SpotifyException`, `SpotifyConnectionException`,
      `SpotifyPlaybackException`, …) instead of `PlatformException`:
      update `_AndroidBridge` and `SpotifyRemoteRepository` error handling
      (`_needsReconnect`, `_classifyPlayError`, the seek retries)
- [ ] Re-test on the Lenovo: login, connect, play, start positions,
      pause/fade, reconnect after idle
- [ ] Then `android.builtInKotlin=true` → the KGP warning should be gone

### Let's Play: a more visible back / close button
The only way out of Let's Play is the small ⌫ (backspace) icon in the
control column / bottom bar – easy to miss.

- [ ] Clearer "close" affordance, e.g. a labelled button ("Exit" / ✕) or a
      bigger icon at a fixed, obvious place (top of the sidebar, end of the
      bottom bar)
- [ ] Works in all layouts: sidebar left/right, bottom bar, compact bar
      (phones / low windows)
- [ ] Keep using `_close()` in `djletsplay.dart` (pops the outer
      Navigator – a builder `context` here gives a black screen)
- [ ] Optional: confirm before leaving while music is playing

## Parked ideas

- [ ] Cloud backup: include settings (fade time, sidebar position, display
      colour, info messages, system volume popup) so a restore on a new
      device sets everything up; old backups without them must still work
- [ ] Fade on by default for new installs (e.g. 1500 ms; Android ≥ 750 ms)
- [ ] Rest of the app (home, playlists, settings) in the dark stage look
      (`lib/core/theme/stage_colors.dart`) like Let's Play
- [ ] Editing screens (playlist edit, cloud backup, Track Time) through
      `showAppToast()` so "Show info messages" applies there too
- [ ] Windows version: test Spotify's Web Playback SDK in WebView2 (DRM)
- [ ] Android log noise `Unable to resolve … ImageUri; annotation class
      40/41` – harmless; only goes away with `jackson-databind` (~2 MB).
      Decided to leave it (filter: `grep -v "Unable to resolve"`)
