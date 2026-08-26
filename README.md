# Little Grand Hotel

Mobile hotel management and decoration game (Godot 4.7, GDScript).
Design document: GDD v1.1 — https://claude.ai/code/artifact/e65d0b6a-c8bd-4f01-ac1e-ea46c4a945cb
What's done and the roadmap: [TODO.md](TODO.md)

## Play in your browser

**https://eren-ozcan.github.io/LittleGrandHotel/**

The web build is the full game, not a cut-down teaser: every room, quest and
achievement is there. Three differences from the phone build — it always starts in
English (the language can still be changed in Settings), there are no ads and no
in-app purchases (both are Android-only paths), and the save lives in the browser's
own storage, so clearing the site data clears the progress and nothing carries over
to the phone build. No install, no account.

## Demo

![Little Grand Hotel gameplay](docs/media/demo.gif)

| Your hotel | Decorate a room | Build | Quests |
|---|---|---|---|
| ![Hotel](docs/media/screen-hotel.png) | ![Room](docs/media/screen-room.png) | ![Build](docs/media/screen-build.png) | ![Quests](docs/media/screen-quests.png) |

The clip and the stills are generated, not hand-recorded: `tests/showcase.tscn`
builds a showcase hotel in memory and renders it into an offscreen 1080x1920
viewport, so the material can be regenerated after any UI change and never
depends on someone's save file.

```
tools\Godot_v4.7-stable_win64_console.exe --path . res://tests/showcase.tscn -- shots
tools\Godot_v4.7-stable_win64_console.exe --path . res://tests/showcase.tscn -- video
python scripts/make_store_shots.py            # store frames, en-US
python scripts/make_store_shots.py tr         # ... and tr-TR
```

Both write into Godot's user data folder (`%APPDATA%\Godot\app_userdata\Little Grand
Hotel\media`). `-- video` leaves a numbered PNG sequence there, plus the game's
own procedural effects and lobby music as WAV and an `audio_cues.json` saying which
frame each effect belongs to — the capture loop writes a PNG per frame, so it is far
from real time and the sound cannot be recorded off the running game. The clip and
the GIF above are assembled from all of that with:

```
python scripts/make_promo_video.py
```

## Status: Full release — core + late game + long-term content

Core loop: room → decoration (Style Score → tier) → shift → collect income → reinvest.
Hotel City-inspired cutaway "dollhouse" look: sky + skyline, wallpapered rooms,
SVG furniture/guest art, quest chain (20 quests) and offline earnings.

Shipped with the polish release: dark bottom bar with icons, cleaning sparkle + broom
animation, flying coin animation, guest door walk-in and idle fidget animations,
procedural sound effects + lobby music, gem spending (shift skip, premium items), room
moving/selling, statistics screen, settings (sound/music, save reset) and late-game
content (Restaurant, Rooftop Garden, level 28 balance test).

Long-term additions: 13 permanent achievements, prestige system (hand over the hotel at
level 20 to earn a permanent income multiplier), serverless weekly decoration theme, and Android
export (export preset + signed debug APK). A shareable save code used to be the
transfer path; it was retired in favour of cloud save + Google account linking, which
cover the same ground without a second mechanism to explain. The save format is compatible with step-by-step migration from v2 onward.

Saves are also backed up to Firebase (anonymous sign-in + a single Firestore document,
over REST — Godot has no Firebase SDK). The backup is restored on every launch of the
same install, and conflicts are resolved by the player rather than merged automatically.
Google account linking — what would make a save follow the player to a *new* device — is
implemented but not yet usable: it needs an OAuth client that has not been created, so it
has never been run against a real account. Setup and reasoning:
[docs/cloud-save-setup.md](docs/cloud-save-setup.md).

Shipped with the Hotel City review release (after studying the original game's guide +
art): infestation mechanic (a room left dirty for too long costs coins to clean),
poking a sleeping guest for a secret inspector bonus, catching a runaway guest on the
street, ready-made decor bundles, capacity view in facilities; chibi characters, bellboy
and maid, a lobby scene with columns and an elevator, rich facility scenes and the room
tier meter (red→green).

## Running

The Godot 4.7 binary is expected under `tools/` (not in the repo):

```
tools\Godot_v4.7-stable_win64.exe --path .
```

## Tests

The whole suite — 16 tests, ~2200 assertions — runs from one script:

```powershell
pwsh tests/run_all.ps1            # everything
pwsh tests/run_all.ps1 -Headless  # skips the two that need a window (CI)
pwsh tests/run_all.ps1 -Filter cloud
```

The runner does not trust exit codes alone: it also greps the output for
`SCRIPT ERROR` / `FAIL`, checks that each test printed its own completion line,
and gives every test a timeout. That is deliberate — a GDScript runtime error
kills a `_ready()` coroutine silently while the process still exits 0, which is
exactly how `tests/tutorial_check` stayed broken and green for eight days.

A single test still runs on its own, for example:

```
tools\Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/sim_check.gd
tools\Godot_v4.7-stable_win64_console.exe --headless --path . res://tests/data_check.tscn
```

What each test covers, what is deliberately **not** covered, and the per-file
API coverage table live in [`docs/test-coverage.md`](docs/test-coverage.md).

## Android export

`export_presets.cfg` is included in the repo (non-Gradle build, arm64-v8a, portrait
720×1280). The following need to be set up once on the local machine only (not included
in the repo):

1. Godot 4.7 export templates → `%APPDATA%\Godot\export_templates\4.7.stable\`
   (see the [Godot export templates download page](https://godotengine.org/download))
2. Android SDK (platform-tools + build-tools 34.0.0 + platform 34), via `ANDROID_HOME`
   or by pointing to the path from Godot Editor Settings → Export → Android
3. Debug keystore: `android/debug.keystore` (gitignored; generated with `keytool`):
   ```
   keytool -genkeypair -v -keystore android/debug.keystore -storepass android ^
     -alias androiddebugkey -keypass android -keyalg RSA -keysize 2048 ^
     -validity 10000 -dname "CN=Android Debug,O=Android,C=US"
   ```

Once setup is complete, APK generation:

```
tools\Godot_v4.7-stable_win64_console.exe --headless --path . --export-debug "Android" build/android/little-grand-hotel.apk
```

## Web export (the playable demo)

The `Web` preset is single-threaded on purpose: a threaded Godot web build needs the
cross-origin isolation headers (`COOP`/`COEP`), and GitHub Pages cannot send them. The
preset also carries the custom feature `demo`, which is what makes the build start in
English regardless of the browser locale.

```
tools\Godot_v4.7-stable_win64_console.exe --headless --path . --export-release "Web" build/web/index.html
```

Publishing is a plain branch push — the `gh-pages` branch holds the exported files at
its root plus an empty `.nojekyll`, and repo Settings ▸ Pages serves that branch from
`/`. The result is roughly 50 MB (39 MB `.wasm` + 11 MB `.pck`), which is why the build
output stays out of `master`.

## Structure

- `data/economy.json` — all balance values (GDD §5); no hardcoded numbers in code
- `data/quests.json` — quest chain (20 quests)
- `data/achievements.json` — 13 permanent achievements
- `src/autoload/game.gd` — simulation + save (independent of the UI, headless testable)
- `src/autoload/cloud_save.gd` + `src/cloud/` — Firebase cloud save and Google sign-in (REST, no SDK)
- `src/main.gd` — Hotel City-inspired dollhouse interface
- `src/sfx.gd` — procedural sound synthesis (no external audio files required)
- `assets/` — SVG art (rooms, items, guests, UI icons)
- `tests/` — the test suite; `run_all.ps1` runs all of it, `docs/test-coverage.md` maps it
- `export_presets.cfg` — Android export preset (see above)
