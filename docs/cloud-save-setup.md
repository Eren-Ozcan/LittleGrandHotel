# Cloud save — Firebase setup

The game code is complete but **inert until a Firebase project exists**. With the
placeholders still in `src/cloud/firebase_config.gd`, `FirebaseConfig.is_configured()`
returns `false`, no network request is ever made, and the game behaves exactly as it
does today (local save only, "Google ile bağlan — yakında" in the Profile popup).

Filling in the two required values below is the only code change needed to turn the
feature on.

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

1. **Create a Firebase project** (console.firebase.google.com → Add project). Use the
   studio Google account — see `C:\Projects\pictures\STUDIO.md`.
2. **Register the Android app** with package name `com.littlegrandhotel.app` (this is
   what `export_presets.cfg` currently ships). Downloading `google-services.json` is *not*
   required for this integration — the REST client only needs the API key and project
   ID — but registering the app is still needed for Google sign-in.
3. **Register the iOS app** with the matching bundle identifier when the iOS export
   preset exists.
4. **Enable Authentication providers**: Build → Authentication → Sign-in method →
   enable **Anonymous** (required) and **Google** (only needed for account linking).
5. **Create the Firestore database** (Build → Firestore Database → Create database).
   Pick the region closest to the player base; it cannot be changed later.
6. **Publish the security rules** from `firestore.rules` (Firestore → Rules → paste →
   Publish, or `firebase deploy --only firestore:rules`). Do this **before** shipping —
   the default "test mode" rules leave every player's save world-readable, and the
   monotonic `rev` guarantee lives in these rules, not in the client.
7. **Add the SHA-1 fingerprints** (Project settings → Your apps → Android → Add
   fingerprint) for the upload key, the Play app-signing key, and the debug key. Google
   sign-in fails silently without all three. The upload/release key lives in
   `android/*.jks`; Play app signing's SHA-1 is in Play Console → Setup → App integrity.
8. **Copy the config values** into `src/cloud/firebase_config.gd`:
   - `API_KEY` ← Project settings → General → Web API Key
   - `PROJECT_ID` ← Project settings → General → Project ID
   - `GOOGLE_WEB_CLIENT_ID` ← the OAuth 2.0 **Web client** ID that Firebase creates for
     the Google provider (Google Cloud console → APIs & Services → Credentials).
     Only needed for account linking.

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

Firestore's free tier (Spark) allows 20K document writes/day. Uploads are throttled to
one per 60 s per player and only fire when something actually changed, so a player in
a long session costs roughly 60 writes/hour at the very worst.
