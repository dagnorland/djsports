# djSports – TODO

Things to do later. Newest decisions and context are in `CHANGELOG.md`.

## Next

### Android: upgrade to Gradle 9 / Android Gradle Plugin 9
Flutter 3.47 warns on every Android build:

> Flutter support for your project's Gradle version (8.14.3) will soon be
> dropped. Please upgrade your Gradle version to a version of at least
> 9.1.0 soon.

(and the same for AGP 8.13.0 → at least 9.0.1). Today it is only a
warning – the build works. `--android-skip-build-dependency-validation`
hides it, but don't rely on that.

- [ ] Target Flutter's template versions: Gradle **9.3.1**, AGP **9.1.0**,
      Kotlin **2.4.0** (see `templateDefaultGradleVersion` etc. in
      `flutter_tools/lib/src/android/gradle_utils.dart` of the Flutter in use)
- [ ] Check every Android plugin against AGP 9 first – especially
      `spotify_sdk` and the local `android/spotify-app-remote` /
      `android/spotify-sdk` AAR modules
- [ ] AGP 9 has built-in Kotlin and a new DSL: remove the opt-outs
      `android.builtInKotlin=false` / `android.newDsl=false` in
      `android/gradle.properties` (added by Flutter's migrator) and drop
      the `kotlin-android` plugin from `app/build.gradle` if AGP 9 needs it
- [ ] `rootProject.buildDir` / `project.buildDir` in `android/build.gradle`
      are removed in Gradle 9 → `layout.buildDirectory`
- [ ] `foojay-resolver-convention` 0.8.0 → 1.x (Gradle 9)
- [ ] Don't use Android Studio's "AGP Upgrade Assistant" blindly – do the
      upgrade as its own branch, then `fvm flutter build apk --debug`, then
      test on the Lenovo (start positions, pause/fade, reconnect)
- [ ] Should also remove the "Unsupported Kotlin plugin version" sync
      warning (Gradle 9 has a newer embedded Kotlin)

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
