# djSports on Google Play – first launch

Everything needed to get djSports from zero to production on Google Play.
For later updates, use the normal [release checklist](RELEASING.md).

Developer account: **personal**, created after Nov 2023. That means Google
requires a **closed test with at least 12 testers, opted in for 14 days
in a row**, before we can apply for production access.

## Not enough testers? (the realistic route)

12–15 testers for 14 days isn't realistic right now, so:

1. **Internal testing = the real distribution channel for now.** Up to
   100 testers by email, no Google review, no 14-day rule, installs and
   auto-updates through Play, signed with the Play key. Give the link to
   the DJs who actually need the app. Steps 1–6 below still apply (the
   listing, App content and screenshots are needed anyway later)
2. **Organization account (no tester rule).** Organization accounts with
   a D-U-N-S number are exempt from the closed-test requirement. Norwegian
   businesses registered in Brønnøysund often already have a D-U-N-S
   number – look it up at dnb.com (free; a new one can take up to 30
   days). Then: new Play developer account as organization ($25), and
   either publish there or transfer the app from the personal account
   (Play Console supports app transfers; same package name and signing
   key carry over)
3. **Closed test later**, if a club or DJ group comes along: the steps in
   section 7–8 are still valid. Tester-exchange communities exist, but
   Google checks that testers really used the app, so it's a risk

Until one of these is done, production is locked.

## Timeline

| When | Step |
|------|------|
| Tonight | Screenshots + FGS video, create the app, internal test |
| Tonight / tomorrow | Closed test live, invite 12+ testers |
| +14 days | Apply for production access (questionnaire) |
| +1–7 days | Google reviews the application, then production release |

Testers who opt in late push the 14 days. Invite 15–20 people so a few
drop-outs don't matter. They must stay opted in (they don't need to open
the app every day, but should use it and give feedback, since Google asks
about that in the production application).

## Already done (branch `feature/google-play`)

- [x] Release bundle builds and is signed with the upload key
      (`android/release.keystore`, alias `djsports`, valid until 2053)
- [x] targetSdk 36, minSdk 24, no advertising ID permission
- [x] Removed the unused `USE_BIOMETRIC` permission
- [x] Launcher label `djSports` (was `djsports`)
- [x] Settings → Spotify on Android shows the package name and the
      **SHA-1 of the installed app's signing certificate**. Spotify's
      Android SDK needs both in the Developer Dashboard; a Play install is
      signed with Google's key, so the SHA-1 is read at runtime
- [x] Privacy policy: `docs/privacy.html` →
      https://dagnorland.github.io/djsports/privacy.html once GitHub
      Pages is on (see below)
- [x] 512×512 icon: `screenshots/out/googleplay/icon_512.png`
- [x] 1024×500 feature graphic:
      `screenshots/out/googleplay/feature_graphic.png`
- [x] Tablet screenshots from the iPad set in
      `screenshots/out/googleplay/tablet_*` (to be replaced tonight)

## Tonight

### 1. Screenshots on Android

Same five shots as the App Store (see the
[shot list](RELEASING.md#store-screenshots)): dark look, no account data,
not the Settings screen.

- [ ] Take them on the Lenovo tablet. Phone shots too if you have an
      Android phone (or an emulator with a demo playlist). Without phone
      shots the script falls back to the iPhone set, which works but shows
      iOS
- [ ] Remove the old files in `screenshots/raw/android/` and name the new
      ones `01-letsplay.png` … `05-help.png` (`.jpeg` is fine too)
- [ ] `./scripts/store_screenshots.sh`
      → `screenshots/out/googleplay/{phone,tablet_7,tablet_10}/`
- [ ] Optional: `build/.screenshots-venv/bin/python
      scripts/feature_graphic.py screenshots/raw/android/01-letsplay.png`
      to rebuild the feature graphic from the new Let's Play shot

### 2. Foreground service video

The app declares `FOREGROUND_SERVICE_MEDIA_PLAYBACK` (audio_service), and
Play Console asks for a short video showing it.

- [ ] Screen-record about 30 s on the Lenovo: start a track in Let's Play,
      go to the home screen, show the media notification with
      play/pause, control playback from it
- [ ] Upload as an **unlisted** YouTube video (or a public Drive link)

### 3. Before creating the release

- [x] Merge `feature/google-play` to `main`; bump `pubspec.yaml` to
      `4.1.2+31` (versionCode must be new for every upload)
- [ ] Turn on GitHub Pages: repo → Settings → Pages → *Deploy from a
      branch* → `main` / `/docs`. Check that
      https://dagnorland.github.io/djsports/privacy.html loads
- [ ] `fvm flutter build appbundle --release`
      → `build/app/outputs/bundle/release/app-release.aab`

### 4. Play Console: create the app

Play Console → **Create app**
- App name: `djSports – Sports Event DJ`
- Default language: English (United States)
- App or game: **App**; Free or paid: **Free**
- Accept the declarations

Then upload the first bundle to **Test and release → Testing → Internal
testing** (add yourself as tester). This also turns on **Play App
Signing**.

- [ ] Copy the **App signing key certificate SHA-1** from
      *Test and release → App integrity → App signing*
- [ ] Spotify Developer Dashboard → the built-in djSports app → Settings →
      Android packages: add `com.dagnorland.djsports` with
      - the Play app signing SHA-1 (Play installs), and
      - the upload key SHA-1
        `AC:2D:B5:06:AD:A2:1A:9F:8E:E8:62:BF:C5:E5:F0:FC:30:BD:F8:86`
        (sideloaded APKs from `./build_apk.sh`)
- [ ] Install the internal test build from Play on the Lenovo: Spotify
      login, connect, play with start positions, pause/fade. Settings →
      Spotify should show the Play SHA-1

Without the Play SHA-1 in the dashboard, Spotify login fails for every
Play install. Users with their own Client ID add it themselves (the app
shows it).

### 5. App content (Policy → App content)

| Section | Answer |
|---------|--------|
| Privacy policy | https://dagnorland.github.io/djsports/privacy.html |
| Ads | No, the app does not contain ads |
| App access | All or some functionality is restricted – see below |
| Content rating | Questionnaire – see below |
| Target audience | 18 and over |
| News app | No |
| Data safety | See below |
| Government app | No |
| Financial features | None |
| Health | None |
| Foreground service permissions | Media playback – see below |

**App access** (instructions for the reviewer)

> djSports controls playback in the Spotify app and needs a Spotify
> Premium account plus the Spotify app installed on the device. Log in
> with the account below: Home → Spotify icon → Connect. Then open Let's
> Play and tap a track. Playlists can be created and edited without
> logging in.
> Username: … Password: …

Either give Google a Spotify Premium test account that is on the
built-in app's user list (counts toward the 5-user limit), or describe
the restriction without credentials. Google may reject for "can't
access" without a working login, so a dedicated test account is safest.

**Content rating** (IARC questionnaire)
- Category: *All Other App Types*
- Violence, sexuality, language, controlled substances, gambling: **No**
- Users can interact or exchange content: **No**
- Shares user location: **No**
- Digital purchases: **No**
- Unrestricted internet / web browser: **No**
- Expected result: Everyone / PEGI 3

Note: tracks played come from Spotify/Apple Music and are not part of the
app's content.

**Data safety**

- Does the app collect or share any of the required user data types?
  **Yes** (the optional cloud backup sends data to our Firebase project)
- Is all collected data encrypted in transit? **Yes**
- Can users request deletion? **Yes** (delete backups in the app, or ask
  via GitHub issues)

| Data type | Collected | Shared | Optional | Purpose |
|-----------|-----------|--------|----------|---------|
| Personal info → Name (Spotify display name) | Yes | No | Yes | App functionality |
| Personal info → User IDs (Spotify user ID) | Yes | No | Yes | App functionality |
| App activity → Other user-generated content (playlists, tracks, start times) | Yes | No | Yes | App functionality |

Everything else: not collected. Spotify login and playback go directly
between the device and Spotify; the profile and email are shown in the
app but not sent to our backend. Firebase is a service provider, which
Play doesn't count as "sharing".

**Foreground service permissions**
- Type: **Media playback**
- Description: "djSports plays music for live sports events. The media
  playback service keeps the now-playing notification and play/pause
  controls working while the DJ switches to another app or locks the
  screen. It runs only while music is playing and is started by the user
  pressing play."
- Video: the link from step 2

### 6. Store listing (Grow users → Store presence → Main store listing)

**App name** (max 30)

```
djSports – Sports Event DJ
```

**Short description** (max 80)

```
Run the music at sports events: playlists with one-tap start positions.
```

**Full description** (max 4000)

```
djSports is built for the person running the music at a sports event –
handball, football, ice hockey, basketball, or anything with a crowd and
a sound system.

Organise your music in four kinds of playlists, one for each moment of
the event:

• Hotspot – goals, big saves and timeouts
• Match – music during play
• Fun Stuff – breaks, competitions and crowd games
• Pre-match – warm-up and arrival

LET'S PLAY
All your playlists on one screen, colour-coded by type. One tap plays the
next track, already jumped to the right part of the song – the drop, the
chorus, the hook. No more scrubbing through an intro while the crowd
waits.

START POSITIONS
Set where each track should start with a slider and preview it. When the
whistle blows, the music starts at exactly the right second.

FADE AND CONTROL
Pause with a smooth fade-out, resume, and step through tracks quickly.

SPOTIFY
Search Spotify, import your Spotify playlists and play through the
Spotify app. Requires Spotify Premium and the Spotify app on the device.

CLOUD BACKUP
Back up your playlists and start times and restore them on another
device.

[One line in your own words: who made djSports and where it is used.]

Note: djSports is not affiliated with or endorsed by Spotify.
```

Replace the line in brackets before pasting.

**Graphics**
- App icon: `screenshots/out/googleplay/icon_512.png`
- Feature graphic: `screenshots/out/googleplay/feature_graphic.png`
- Phone screenshots (2–8): `screenshots/out/googleplay/phone/`
- 7" tablet: `screenshots/out/googleplay/tablet_7/`
- 10" tablet: `screenshots/out/googleplay/tablet_10/`

**Store settings**
- Category: **Music & Audio**
- Tags: Music, DJ, Sports (pick what Play offers)
- Contact email: the one you want public (required)
- Website: https://github.com/dagnorland/djsports (optional)

### 7. Closed test

- [ ] Test and release → Testing → **Closed testing** → create a track
      (e.g. "Beta"), promote the internal build, countries: Norway (+ any
      others your testers are in)
- [ ] Testers: an email list (Google accounts) or a Google Group with
      15–20 people
- [ ] Send them the opt-in link and ask them to install from Play
- [ ] Testers who use Spotify: add them to the built-in Spotify app's
      user list (max 5), or let them use their own Client ID
      (Settings → Spotify, the app shows the package name and SHA-1 to
      register)
- [ ] Submit the closed test for review (first review can take a few
      days)
- [ ] Note the date 12 testers are opted in: production access opens
      14 days later

### 8. Production access (after 14 days)

Dashboard → **Apply for production**. Google asks about the test: how
you recruited testers, how engaged they were, what feedback you got and
what you changed, and whether the app is ready. Keep notes during the
test (feedback, fixes, version numbers) so this is easy to answer.

Then Production → Create new release → the latest bundle → release
notes → countries → rollout.

## Before the public launch (recommended)

- **Firestore rules**: locked rules and the Profile + PIN key path are
  in 4.2.0 (`firestore.rules`, see CHANGELOG). Deploy them after both apps
  are released and the djsportsweb migration has run
- **Spotify user limit**: Play users can't all use the built-in Client
  ID (5 users). The BYO Client ID flow covers it; consider making it the
  first thing a new Android user sees, and mention it in the store
  description
- `spotify_sdk` 4 / Built-in Kotlin (see `TODO.md`) – not needed for
  Play, but future Flutter versions will stop building without it
