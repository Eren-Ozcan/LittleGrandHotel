# Cloud save — Firebase setup

**Status: the Firebase project exists and the values in `src/cloud/firebase_config.gd`
are filled in (2026-08-07).** Anonymous cloud save is live. Account linking still waits
on the Android plugin described under "Still needed for account linking on device".

| | |
|---|---|
| Project ID | `little-grand-hotel` (project number 210451589020) |
| Google account | `yilkgamesstudio@gmail.com` — console index `/u/5/` |
| Android app | `com.littlegrandhotel.app`, App ID `1:210451589020:android:ebc671530488730ae10a59` |
| Auth providers | Anonymous ✔, Google ✔ |
| Firestore | `(default)`, Standard edition, **nam5 (United States)** — matches reefy and Cengel Bulmaca |
| Rules | `firestore.rules` published |
| Plan | Spark (no-cost) |

Google Analytics and Gemini in Firebase were deliberately left **off**: neither is used,
and Analytics would add a data-collection surface to declare in the Play Data Safety
form. Both can be enabled later without touching this integration.

Historical note — the game code is inert while the placeholders are in
`src/cloud/firebase_config.gd`: `FirebaseConfig.is_configured()` returns `false`, no
network request is ever made, and the game behaves as local-save only.

## Why REST and not an SDK

Godot has no official Firebase SDK, so both Authentication and Firestore are reached
over their REST APIs with `HTTPRequest`:

- `src/cloud/firebase_auth.gd` — anonymous sign-up, refresh-token persistence, and
  `signInWithIdp` for Google linking.
- `src/autoload/cloud_save.gd` — Firestore `GET` for the document and `:commit` for
  writes (`:commit` is used instead of a plain `PATCH` because it is the only REST
  path that can set a server-side `updatedAt` timestamp).

Play Games Saved Games was deliberately ruled out: it is Android-only and this game
targets Android **and** iOS. A Firebase UID works identically on both, so one player
keeps one save across platforms.

## Steps in the Firebase / Google Cloud console

1. ✅ **Create a Firebase project** (console.firebase.google.com → Add project). Use the
   studio Google account — see `C:\Projects\pictures\STUDIO.md`.
2. ✅ **Register the Android app** with package name `com.littlegrandhotel.app` (this is
   what `export_presets.cfg` currently ships). Downloading `google-services.json` is *not*
   required for this integration — the REST client only needs the API key and project
   ID — but registering the app is still needed for Google sign-in.
3. ⬜ **Register the iOS app** with the matching bundle identifier when the iOS export
   preset exists.
4. ✅ **Enable Authentication providers**: Build → Authentication → Sign-in method →
   enable **Anonymous** (required) and **Google** (only needed for account linking).
   Anonymous **auto clean-up was left off** on purpose: it deletes anonymous accounts
   after 30 days of inactivity, which would strand a returning player's cloud save.
5. ✅ **Create the Firestore database** (Build → Firestore Database → Create database).
   Pick the region closest to the player base; it cannot be changed later.
6. ✅ **Publish the security rules** from `firestore.rules` (Firestore → Rules → paste →
   Publish, or `firebase deploy --only firestore:rules`). Do this **before** shipping —
   the default "test mode" rules leave every player's save world-readable, and the
   monotonic `rev` guarantee lives in these rules, not in the client.
7. 🔶 **Add the SHA-1 fingerprints** (Project settings → Your apps → Android → Add
   fingerprint) for the upload key, the Play app-signing key, and the debug key. Google
   sign-in fails silently without all three. The upload/release key lives in
   `android/*.jks`; Play app signing's SHA-1 is in Play Console → Setup → App integrity.
   The upload key and the debug key are registered; **the Play app-signing SHA-1 is
   still missing** because Play App Signing enrolment has not happened yet — add it the
   moment the first bundle is uploaded, or Google sign-in will fail on Play-installed
   builds while working fine on locally installed ones.
8. ✅ **Copy the config values** into `src/cloud/firebase_config.gd`:
   - `API_KEY` ← Project settings → General → Web API Key. If the console does not show
     that row (it only appears once a **Web** app is registered), take the value from
     Google Cloud console → APIs & Services → Credentials → *Browser key (auto created
     by Firebase)*. The Android key on that same page is **not** interchangeable — it is
     restricted to signed Android callers and the Godot `HTTPRequest` client is not one.
   - `PROJECT_ID` ← Project settings → General → Project ID
   - `GOOGLE_WEB_CLIENT_ID` ← the OAuth 2.0 **Web client** ID that Firebase creates for
     the Google provider (Google Cloud console → APIs & Services → Credentials).
     Only needed for account linking.

## Verifying the live setup

Checked end-to-end against the real project on 2026-08-07 with `curl`, no game build
needed. Anonymous sign-up returns a UID and an `idToken`; with that token:

| Request | Expected | Got |
|---|---|---|
| `GET saves/{own uid}` | 404 (rule allows, doc absent) | 404 |
| `GET saves/someoneelse` | 403 | 403 |
| `GET saves` (list) | 403 | 403 |
| `:commit` create `rev=1` | 200 | 200 |
| `:commit` update `rev=2` | 200 | 200 |
| `:commit` update back to `rev=1` | 403 | 403 |

The last row is the important one: a stale client cannot overwrite a newer save, and
that is enforced by the server, not the client.

This left one throwaway document (`saves/dTIKBWT9K5cm0Pv4OoCZfaj4tlh1`) and its
anonymous user in the project. Rules deny `delete`, so it can only be removed from the
Firebase console, which bypasses rules.

## Still needed for account linking on device

`cloud_save.gd` exposes `set_google_id_token_provider(callable)` — a seam that must
return a Google OIDC `id_token`. Godot has no built-in Google sign-in, so this needs a
platform plugin (a Google Sign-In / Play Services Godot Android plugin, plus the iOS
equivalent later). Until something fills that seam,
`CloudSave.is_account_linking_available()` stays `false` and the UI keeps the
"yakında" label.

What works without it: the save is backed up to Firestore under an anonymous UID and
restored across launches on the same install. What does not: moving to a new device or
recovering after an uninstall, because the anonymous session's refresh token lives in
`user://` and is wiped with the app.

## Privacy policy

Cloud save uploads game progress to Google servers and creates a per-player
identifier. `docs/store/privacy-policy.html` and `privacy-policy-plaintext.md` must
mention this before the feature ships, and the Play Console Data Safety form has to
declare it.

## Cost

Firestore's free tier (Spark) allows 20K document writes/day. The payload is tiny (~1 KB),
so only the document-write count matters, never bandwidth.

The periodic upload path (`maybe_upload()`) is throttled to one per `UPLOAD_THROTTLE_SEC`
per player and only fires when something actually changed. That constant was 60 s and was
raised to **300 s** on 2026-08-07: at 60 s a player with half an hour of daily play costs
~40 writes/day, which exhausts the free tier at roughly 500 daily active players — an
avoidable ceiling for a save-game *backup*. Verified before the change: a 95 s undisturbed
desktop session advanced `rev` by exactly 1, i.e. the throttle behaves as documented.

`flush()` is a second path and it **deliberately bypasses the throttle** — it runs on
`NOTIFICATION_APPLICATION_PAUSED` / focus-out / close, because on mobile the process can
be killed without ever waking again and waiting out the throttle would lose the whole
session. So the real figure is roughly:

    writes/hour ≈ minutes of play + number of times the app is backgrounded

Because this is an idle game, `state_changed` re-dirties the save almost immediately
after every upload, so a background→foreground cycle essentially always costs one write.
That is intended. It only looks alarming if you measure with a desktop window that keeps
losing focus: doing that produced 8 revs in 90 s, which is an artifact of the measurement,
not of normal play. Even heavy app-switching stays orders of magnitude under 20K/day.
