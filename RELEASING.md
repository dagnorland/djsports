# Release checklist

How to ship a new djSports version to Google Play, the App Store
(iPhone + iPad) and the Mac App Store.

The version lives in one place: `version:` in `pubspec.yaml`
(`<name>+<build>`, e.g. `4.1.0+29`). Android, iOS and macOS all read it.
The build number must go up for every store upload.

## 1. Prepare

- [ ] On the feature branch: move `## [Unreleased]` in `CHANGELOG.md` to
      `## [X.Y.Z] - Release YYYY-MM-DD` and add a new empty
      `## [Unreleased]` above it
- [ ] Bump `version:` in `pubspec.yaml` (e.g. `4.1.0+29` → `4.2.0+30`)
- [ ] `fvm flutter analyze`: no new issues
- [ ] Commit, push, open PR, merge to `main`
- [ ] `git checkout main && git pull`
- [ ] `git tag -a vX.Y.Z -m "djSports X.Y.Z (build N)"`
      `&& git push origin vX.Y.Z`
- [ ] `fvm flutter pub get`
- [ ] Write the store text: a short version of the changelog section

Build everything from `main` at the tag.

## 2. Android — Google Play

First launch (app setup, closed test, Play Console forms): see
[GOOGLE_PLAY.md](GOOGLE_PLAY.md).

- [ ] `fvm flutter build appbundle --release`
      → `build/app/outputs/bundle/release/app-release.aab`
      (signed with `android/key.properties`)
- [ ] Play Console → djSports → Test and release → Production (or
      Internal testing first) → Create new release
- [ ] Upload the `.aab`, paste release notes
- [ ] Review release → Start rollout
- [ ] Optional sideload APK: `./build_apk.sh`
      → `build/app/outputs/flutter-apk/djsports-X.Y.Z.apk`
      (also copied to iCloud `djsports/release`)

## 3. iPhone + iPad — App Store

One build covers both (`TARGETED_DEVICE_FAMILY = "1,2"`).

- [ ] `./build_ipa.sh` → `build/ios/ipa/djsports-X.Y.Z.ipa`
      (also copied to iCloud `djsports/release`)
- [ ] Transporter → drag in the `.ipa` → Deliver
      (or Xcode → Window → Organizer → Distribute App)
- [ ] App Store Connect → djSports → iOS → "+ Version" → X.Y.Z
- [ ] Wait for the build to finish processing, then select it
- [ ] "What's New in This Version"
- [ ] Screenshots if the UI changed: iPhone 6.9″ and iPad 13″
      Take them on real devices (Spotify needs it), drop into
      `screenshots/raw/{iphone,ipad,macos,android}/`, run
      `./scripts/store_screenshots.sh` → `screenshots/out/` has every
      store size (App Store + Google Play). Shot list: see
      [Store screenshots](#store-screenshots)
- [ ] Optional: TestFlight check on iPhone and iPad first
- [ ] Add for Review → Submit

## 4. macOS — Mac App Store

- [ ] `./build_macos.sh` (~15 min) → `build/macos/pkg/djsports-X.Y.Z.pkg`
      (also copied to iCloud `djsports/release`)
  - Step 1: `flutter build macos --release` (writes the version into
    the Xcode config)
  - Step 2: `xcodebuild archive` → `build/macos/archive/djsports.xcarchive`
  - Step 3: `xcodebuild -exportArchive` with `macos/ExportOptions.plist`
    (app-store-connect, team `4SRFW7L9XH`) → signed `.pkg`
  - Pods "Run script build phase" warnings are harmless
- [ ] Optional check: `pkgutil --check-signature build/macos/pkg/*.pkg`
      shows `3rd Party Mac Developer Installer: … (4SRFW7L9XH)`
- [ ] Transporter → drag in the `.pkg` → Deliver
      (or Organizer → distribute the archive)
- [ ] App Store Connect → djSports → macOS → "+ Version" → X.Y.Z
- [ ] Select the build, "What's New", Mac screenshots if the UI changed
- [ ] Add for Review → Submit

## 5. After

- [ ] GitHub release: `gh release create vX.Y.Z --notes-from-tag`
      (or paste the changelog section)
- [ ] Watch Play Console and App Store Connect for review results

## Store screenshots

Same set on every device (iPhone, iPad, Mac, Android). The script orders
them by filename, so name the raw files with the number first, e.g.
`screenshots/raw/ipad/01-letsplay.png`.

| # | File | Screen | What to show |
|---|------|--------|--------------|
| 1 | `01-letsplay.png` | Let's Play | All four playlist types filled, controls visible |
| 2 | `02-home.png` | Home | Playlist cards with cover art, type filter chips |
| 3 | `03-edit-playlist.png` | Edit playlist | A playlist with tracks, several with start times |
| 4 | `04-edit-track.png` | Edit track | Start-time slider set, cover in the details box + previous/next cards (wide screens) |
| 5 | `05-help.png` | Help | Playlist help, top of the page |

Mac window at exactly 2880×1800 (Retina = 1440×900 pt), with the app
running (needs Accessibility permission for the terminal once):

```bash
osascript -e 'tell application "System Events" to tell process "djsports" to set size of window 1 to {1440, 900}'
osascript -e 'tell application "System Events" to tell process "djsports" to get size of window 1'
```

Then Cmd+Shift+4 → Space → Option-click the window (no shadow).
Shoot on a Retina screen (the MacBook's own display): on a non-Retina
monitor the capture is only 1440×900 and gets upscaled 2× (soft text).

Before shooting:
- Dark look on all screens (4.1.1+), status bar tidy (full battery or
  not charging)
- No account data on screen (email, user ID, device names) – that's why
  the Spotify output sheet isn't in the set
- Don't use the Settings screen – it shows "built-in developer credentials
  (limited to 5 authorized users)", which invites review questions

## Troubleshooting

- **macOS: `double-quoted include "…" in framework header`** (Firebase
  pods, `VerifyModule` step) — Xcode 27's module verifier. Fixed by
  `ENABLE_MODULE_VERIFIER = NO` in `macos/Podfile` `post_install`; if it
  comes back, run `cd macos && pod install` and build again
- **macOS archive: `'absl/status/statusor.h' file not found`** (gRPC-Core)
  — flaky Pods build order in Xcode 27; a second run passes.
  `build_macos.sh` retries the archive once automatically

## Prerequisites (one-time)

- Xcode signed in with the Apple ID for team `4SRFW7L9XH`
  (Xcode → Settings → Accounts)
- `ios/ExportOptions.plist` and `macos/ExportOptions.plist` with team ID
- `android/key.properties` + upload keystore
- Flutter via FVM (`.fvmrc`). `build_macos.sh` uses `fvm flutter`;
  `build_ipa.sh` and `build_apk.sh` call plain `flutter`, so make sure
  that is the FVM SDK
- Transporter.app installed (Mac App Store)
