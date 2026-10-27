# Spotibai

A Spotify-inspired Flutter music player for Android: plays songs from the
phone, keeps playing in the background, and works fully offline.

## What it does

- **Finds your music by itself.** On first launch it asks for access to your
  audio and then lists everything already on the phone, with the real title,
  artist, album and length from MediaStore. Nothing is copied: songs play
  straight from their `content://` URI, so a file you add or delete in Files or
  your music app shows up here too. **Refresh library** on the Home header
  re-scans (it keeps your place and doesn't interrupt playback).
- **Cover art, for real.** Songs from the phone show their album artwork, read
  from the MediaStore thumbnail and — when an album has none — from the picture
  embedded in the file. Covers are cached per album, and the now-playing screen
  uses a blurred copy as its backdrop. Files you add by hand use the picture
  embedded in the file, a thumbnail saved beside it, or a video frame — and a
  generated gradient tile only when the file has no image at all.
- **Add More** opens the system file picker for anything the phone's music
  library doesn't index. Those files are copied into app storage, and if the
  same song is also visible to MediaStore it is only listed once.
- **Four tabs.** Home (greeting, filters, album shelf, recent shortcuts),
  Search (live results plus a browse-all grid of moods), Your Library (every
  song, hearts and moods) and Create (the local file picker), with the mini
  player sitting above the tab bar.
- **Search, favourites and moods.** Search covers titles, artists and albums.
  A song's ⋮ menu hearts it or files it under **Focus**, **Chill** or **Gym**;
  the chips on Home and in Your Library filter the feed, and the choices survive
  restarts and MediaStore renumbering. Hearts are also next to the player title.
- **Made for you.** Albums on the phone become square cards that play the whole
  album in one tap, ordered by recently played songs first.
- **Swipe left on a song** to get rid of it. For songs found on the phone the
  file is left alone — the song is just hidden from this app, and it stays
  hidden after a rescan. Removing an imported file likewise leaves the file in
  place.
- **Now Playing** — a full-screen, Apple Music-style player: the cover on a
  blurred backdrop that breathes with playback, tap the cover (or the Lyrics
  pill at the bottom) to swap it for the lyrics, a hairline seek bar, and large
  plain transport icons with shuffle and repeat off → all → one.
- **Lyrics, automatically.** Each time a song starts, the app reads lyrics in
  three steps, without a single tap: embedded tags (ID3 `USLT`, MP4 `©lyr`,
  Vorbis/FLAC `LYRICS`), then the on-device cache, then a free [LRCLIB](https://lrclib.net)
  lookup. A downloaded match is saved to the phone, so it shows up offline from
  then on. The lyrics take over the artwork in the player and glide line by
  line with the song; plain text is shown as-is. If nothing is found the view
  offers a **Try again** button.
- **Offline-first.** Library scanning, playback, artwork, embedded lyrics and
  every previously downloaded lyric work with no connection at all. The only
  network request in the app is the LRCLIB lyric lookup, over HTTPS.
  `android:usesCleartextTraffic="false"` keeps it encrypted.
- **Background audio** — playback continues with the screen off, with transport
  controls on the lock screen and in the notification shade.
- **Built-in demos** — three short generated tracks (`assets/demo/*.wav`) so
  there is something to play on first launch. Regenerate them with
  `dart run tool/gen_demo.dart`.

## Install it on a phone

1. Copy the right APK to the phone (USB cable, Google Drive, email — anything
   works), then tap it and allow "install unknown apps" for whichever app opened
   it. Requires **Android 7.0 (API 24)** or newer.
   - `MusicPlayer-armv7.apk` (18 MB) — 32-bit phones (this one: Infinix X6823).
   - `MusicPlayer-universal.apk` (53 MB) — any CPU if you are unsure.
2. Or, with USB debugging on and the phone plugged in:

```bash
adb install -r MusicPlayer-armv7.apk
```

Check what CPU a phone has with `adb shell getprop ro.product.cpu.abi`
(`armeabi-v7a` = 32-bit, `arm64-v8a` = 64-bit).

After importing songs, tap play; audio keeps running when you leave the app or
lock the screen. Verified on the X6823 by backgrounding the app mid-song: audio
kept playing, the queue advanced Warm Up → Pulse → Drift on its own, and the
notification (3 transport actions) plus the audio foreground service stayed up.
Lock-screen controls themselves were confirmed only as present in the system's
media session, not by tapping a locked screen.

## The look

An **Apple Music-inspired** interface in violet: near-black `#08060D` canvas,
lifted `#14101E` cards, frosted floating bars, one violet accent `#B07CFF`
(`#7C3AED` deep) for active controls, and `#A79BB8` secondary text. Page titles
are large and tight (34sp), shelves breathe, and motion is quiet.

- **Home** — a big time-of-day greeting, scrolling filter pills, clean square
album tiles (no chrome over the artwork), then the song list with duration
stamps and a ⋮ menu. A violet wash fades from the top of the screen.
- **Now Playing** — the cover on a 100px-blurred backdrop; it scales down when
  paused. Tapping the cover, or the frosted **Lyrics** pill at the bottom,
  swaps the cover for the lyrics: a wheel of lines that dims its neighbours,
  enlarges the line being sung and glides to it as the song plays. A hairline
  seek bar and plain 62dp play glyph replace the old filled button.
- **Tab bar and mini player** — a frosted-glass tab bar with three labelled
destinations; the frosted mini player floats directly above it with a 2px
violet progress line.
- **Your Library** — the same songs behind **All / Liked / Focus / Chill /
  Gym** filters, with add and refresh actions in the header.
- **Search** — a rounded dark search field, live results while typing, and a
  2-column browse grid of gradient mood cards when the field is empty.

1.3.0 introduced the violet palette, 1.4.0 added automatic embedded lyrics,
1.5.0 downloads missing lyrics from LRCLIB and 1.6.0 moved to the Spotify-style
tab layout. 1.7.0 adds the Apple Music-inspired player, artwork/lyrics switch
and animated lyric wheel.

Typography is **DM Sans** for body and display text (headings just use the
bold weights with tight tracking). It is bundled in `assets/fonts/` (no runtime
download, so it works offline) and licensed under the SIL Open Font License —
the licence files sit next to the font.

## Build from source

The toolchain on this machine lives outside PATH:

```bash
export JAVA_HOME="$HOME/android/jdk17/jdk-17.0.20.1+1"
export ANDROID_HOME="$HOME/android/sdk"
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$PATH"

/c/flutter/bin/flutter analyze
/c/flutter/bin/flutter test
/c/flutter/bin/flutter build apk --release                # one APK, all CPUs
/c/flutter/bin/flutter build apk --release --split-per-abi # one APK per CPU
```

Output lands in `build/app/outputs/flutter-apk/`. First build takes ~20 minutes
(it installs the Android NDK and CMake); later builds take about two.

Two things worth knowing before you ship an update:

- **Match how the phone was set up.** Installing a `--split-per-abi` build gives
  it a bumped versionCode (armeabi-v7a = base + 1000), so a later plain build
  looks like a *downgrade* and is refused. Either stick to one flavour or bump
  `version:` in `pubspec.yaml` (e.g. `1.0.1+2` → `1.0.2+3`) for every update.
- **Keep `android/app/proguard-rules.pro`.** Release builds run R8, which renames
  `kotlin.coroutines.Continuation`; `shared_preferences_android` 2.5.0 resolves
  its methods through Pigeon JNI by name, so without those keep rules the app
  crashed on startup with a `NoSuchMethodError` (flutter/flutter#194649). The
  rules disappear if that file is removed.

## Permissions

| Android | Permission | Why |
| --- | --- | --- |
| 13+ (API 33+) | `READ_MEDIA_AUDIO` | read the songs on the phone |
| 12 and older | `READ_EXTERNAL_STORAGE` | same, before Android split the permission |
| all | `FOREGROUND_SERVICE`, `WAKE_LOCK` | keep playing with the screen off |
| all | `INTERNET` | download lyrics from LRCLIB (HTTPS only) |

`INTERNET` is the only network permission. Playback never touches it: songs are
read from local files or MediaStore. Lyrics requests carry just the title,
artist, album and duration and are cached on the phone; there is no account,
key, or tracking.

If access is denied the app still works: it shows a card explaining why the list
is empty, with a button to ask again, and the bundled demos are there to play.

## Notes and limits

- APKs are **signed with the debug key**, which is fine for side-loading but
  means Play Store distribution needs a real signing key — and changing keys
  later requires uninstalling the app first.
- The app never blocks the first frame on the audio service: the library is
  drawn immediately and the queue loads behind it. Start-up used to await
  `JustAudioBackground.init()` before `runApp()`, which made Android show
  "isn't responding" when that took too long.
- Lyrics resolve in this order: embedded tag, saved copy, LRCLIB. A song that
  is not in LRCLIB and carries no tag still shows “No lyrics found”, and the
  **Try again** button retries. Matching is cleaned for YouTube-style names
  (`Artist - Song (Official Video)_123...`) and verified by duration, so a
  wrong-version match is unlikely. Instrumentals are skipped. The web build has
  no downloader and relies on embedded lyrics only.
- Downloaded lyrics live in SharedPreferences (up to 200 songs) under the title
  and artist, so they survive rescans that renumber MediaStore rows. Clearing
  app data removes them.
- Cover art comes from the phone's media library (or the file's embedded
  picture). Hand-imported files and the demos have none yet.
- Mood chips are filled by hand (⋮ → Add to Focus/Chill/Gym); the app does not
  analyse audio to guess a mood.
- Albums are the “curated mixes”; there are no user-created playlists yet.
- The device scan is Android-only; the web build plays the built-in demos but
  cannot read a music library.
- Songs found on the phone are re-read from MediaStore on each launch, so they
  are never stored twice in the app. Only `+` imports and the hidden-song list
  are saved.
- The app only writes into its own storage; it never modifies the songs you
  picked, and removing a song from the library leaves the imported copy behind.

## Layout

| Path | Purpose |
| --- | --- |
| `lib/main.dart` | App entry point, background-audio + audio-session setup |
| `lib/music_controller.dart` | Library state and playback commands |
| `lib/audio/engine.dart` | `PlaybackEngine` interface + just_audio implementation |
| `lib/app/` | Platform-specific bits (media tags, file import, art, scanner) with web stubs |
| `lib/screens/` | Tab shell + Home, Search, Your Library and the full-screen player |
| `lib/widgets/` | Cover art, song tile, filter pills, frosted surfaces, mini player |
| `android/.../MainActivity.kt` | MediaStore + permission channel (songs, artwork, lyrics) |
| `android/.../LyricsReader.kt` | Reads ID3 / MP4 / Vorbis lyric tags locally |
| `lib/models/lyrics.dart` | LRC parser, current-line lookup, cache serialisation |
| `lib/app/lyrics_lookup*.dart` | LRCLIB client, matching/parsing, web stub |
| `test/` | Controller and widget tests running on a fake engine |
