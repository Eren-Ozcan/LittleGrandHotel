# Cloud save — Firebase setup

**Status: the Firebase project exists and the values in `src/cloud/firebase_config.gd`
are filled in (2026-08-07).** Anonymous cloud save is live. Google account linking is
implemented in the game (`src/cloud/google_signin.gd`) but has never been run against a
real account, because the OAuth **Desktop app** client it needs does not exist yet —
that is step 7 below and it is the one thing still waiting on a human. Nothing breaks
while it is missing; linking simply stays unavailable.

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

## Why the browser and not a native sign-in plugin

Godot has no built-in Google sign-in either, so `src/cloud/google_signin.gd` does the
whole thing in GDScript: open the **system browser**, catch the redirect on a
`127.0.0.1` listener inside the game, exchange the code with PKCE (RFC 8252 + RFC 7636).
The alternatives were a Kotlin Credential Manager plugin for Android *plus* a separate
GoogleSignIn plugin for iOS — two native plugins to write, build and keep alive across
Godot upgrades — or a Play Games Services plugin, which produces an Android-specific
identity and would undo the "same player, same save on iOS" decision above.

The browser flow is one code path that behaves the same on Android, iOS, Windows, macOS
and Linux, with no AAR/Framework to maintain and **no extra work for the iOS port**. The
price is paid by the player: the account chooser appears in the browser rather than
in-app, and on mobile they have to switch back to the game themselves after signing in.
For something done once in the life of a device, that is a fair trade.

It is not a one-way door. The `set_google_id_token_provider()` seam is still there, so
adding a native plugin later changes that one call and nothing else.

## Steps in the Firebase / Google Cloud console

1. ✅ **Create a Firebase project** (console.firebase.google.com → Add project). Use the
   studio Google account — see `C:\Projects\pictures\STUDIO.md`.
2. ✅ **Register the Android app** with package name `com.littlegrandhotel.app` (this is
   what `export_presets.cfg` currently ships). Nothing in this integration actually
   consumes it: the REST client needs only the API key and the project ID, there is no
   `google-services.json` in the repo, and sign-in does not go through the Android app
   identity either (see step 7). Registering it is still worth doing — it is where a
   native SDK would look if one is ever added, and it costs nothing.
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
7. ⬜ **Create the OAuth client for Google sign-in.** *This is the only step still
   waiting on a human, and until it is done account linking cannot be tried at all.*
   Google Cloud console → APIs & Services → Credentials → Create credentials → OAuth
   client ID → Application type **Desktop app**.

   Create it in the **same Google Cloud project** as the Firebase project
   `little-grand-hotel`, **and** paste the new client id into Firebase console →
   Authentication → Sign-in method → Google → *Whitelist client IDs from external
   projects*. Do both; the second is a two-minute job and is the documented cure for the
   failure mode below.

   *Why both, honestly:* the `id_token` the game sends to `signInWithIdp` carries an
   `aud` naming the **Desktop** client, not the Web client Firebase created for its own
   Google provider. Whether Firebase accepts that on the strength of the shared project
   alone could not be confirmed in Google's documentation, and nobody has run this flow
   against a real account yet — so treat neither step as proven. What *is* documented is
   the failure: `Invalid Idp Response: id_token audience mismatch`, whose published fix
   is exactly that allowlist. If the first real sign-in dies at the last step — after the
   player has already authenticated in the browser, which makes it a confusing thing to
   debug — the allowlist entry is the first thing to check, and its absence is the likely
   cause. Whichever of the two turns out to be the load-bearing step, come back and write
   it down here; the next game will need the answer.

   Then copy `src/cloud/google_oauth_client.example.gd` to
   `src/cloud/google_oauth_client.gd` and fill in `CLIENT_ID` and `CLIENT_SECRET`. The
   template is committed, the real file is gitignored (same pattern as `android/*.jks`).

   **If you skip this, nothing breaks.** `FirebaseConfig.is_google_configured()` returns
   `false`, `CloudSave.is_account_linking_available()` stays `false`, the cloud section
   of the Profile popup keeps showing a disabled *"Link with Google — coming soon"*
   button, and the anonymous cloud backup carries on exactly as it does today. There is
   no crash path and no half-configured state: the file is either absent/placeholder, or
   complete.

   *Why "Desktop app" rather than "Android":* the flow opens the system browser and
   listens for the redirect on `127.0.0.1`. Desktop clients are the client type that
   accepts a loopback redirect, and they accept it on **any** port — so
   `google_signin.gd` asks the OS for a free one (`LOOPBACK_PORT_ANY`) and never has to
   register a redirect URI or handle a port collision. One client covers Android, iOS
   and desktop.

   *About the client secret:* a Desktop client comes with a `client_secret`, and per
   Google's own documentation it is **not** treated as a true secret — it ships inside
   every copy of the binary and can be extracted from any of them. PKCE is what actually
   protects the code exchange. It is still kept out of this repo, because the repo is
   public and a secret-shaped string in it trips GitHub push protection and Google's
   leaked-credential scanners. That is noise avoidance, not a security boundary; do not
   design anything on the assumption that this value is confidential.
8. ✅ **Copy the config values** into `src/cloud/firebase_config.gd`:
   - `API_KEY` ← Project settings → General → Web API Key. If the console does not show
     that row (it only appears once a **Web** app is registered), take the value from
     Google Cloud console → APIs & Services → Credentials → *Browser key (auto created
     by Firebase)*. The Android key on that same page is **not** interchangeable — it is
     restricted to signed Android callers and the Godot `HTTPRequest` client is not one.
   - `PROJECT_ID` ← Project settings → General → Project ID
   - `GOOGLE_WEB_CLIENT_ID` ← the OAuth 2.0 **Web client** ID that Firebase creates for
     the Google provider (Google Cloud console → APIs & Services → Credentials). The
     game never calls this — sign-in uses the Desktop client from step 7. It is recorded
     here only to document which client the Firebase console's Google provider points
     at, which matters when you are staring at a list of clients wondering what each
     one is for.

   The Desktop client from step 7 deliberately does **not** live in this file; it is
   loaded at runtime from the gitignored `google_oauth_client.gd`.

9. ⬜ **Configure the OAuth consent screen** (APIs & Services → OAuth consent screen).
   This is the page the player sees after the browser opens: your app name and logo, the
   account chooser (the flow passes `prompt=select_account` so a player with one Google
   account still gets to choose — otherwise Google would silently continue with it and a
   player who linked the wrong account would have no way back), and the permissions
   being asked for.

   The scopes requested are exactly `openid email profile` and nothing else
   (`SCOPES` in `google_signin.gd`). The game reaches its cloud data through the
   Firebase UID, not through these scopes, so there is no reason to ask for more — and
   asking for more makes Google's review heavier.

   Publishing status is worth understanding before you ship: while the consent screen is
   in **Testing**, only the accounts explicitly listed as test users can complete
   sign-in, so shipping in that state would give every other player a dead button.

   **Open question, not established here:** whether moving to *In production* for these
   three non-sensitive scopes needs a Google verification review, and whether an
   "unverified app" interstitial is shown in the meantime. Nothing in this repo can
   answer that and nobody has run the flow against a real account yet. Settle it in the
   console when you create the client — and write down the answer, because the next game
   will hit exactly the same question.

### Why there is no SHA-1 fingerprint step any more

Step 7 used to be a different, unresolved blocker: add the upload key, debug key and
**Play app-signing** SHA-1 fingerprints to the Firebase Android app, or Google sign-in
would fail on Play-installed builds. Play App Signing enrolment had not happened, so
that fingerprint was missing and the step sat open.

It does not apply to the browser flow, and the reason is worth carrying to the next
game. A SHA-1 fingerprint is how Google recognises an **Android** OAuth client: that
client type is bound to a package name plus a signing certificate, so a build signed
with an unregistered key arrives as an unknown caller. This game never presents an
Android client. Sign-in uses a Desktop client through the system browser, and the token
exchange is authenticated by the client id plus PKCE — neither of which knows or cares
how the APK was signed. The rest of the path is signing-agnostic for the same kind of
reason: Identity Toolkit and Firestore are reached over REST with the Web API key, and
there is no `google-services.json` in the repo (note the warning in step 8 about the
*Android-restricted* API key — the Godot `HTTPRequest` client is not a signed Android
caller, and this integration is built to never need to be one).

The evidence, if you want to re-check it here or on another project: nothing under
`src/`, `android/` or `export_presets.cfg` mentions a SHA-1 fingerprint, an Android
OAuth client or `google-services.json`, and `android/build/build.gradle` pulls in no
`play-services-auth` dependency.

Play App Signing is of course still part of shipping on Play. It just does not gate
cloud save or account linking.

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

## Account linking — what exists, what is unproven

The seam `cloud_save.gd` exposes, `set_google_id_token_provider(callable)`, is filled by
default with `GoogleSignIn.request_id_token()`. So
`CloudSave.is_account_linking_available()` flips to `true` on its own the moment
`google_oauth_client.gd` exists with real values, and the "Link with Google" button in
the Profile popup goes live. **No code change is needed to switch it on** — only step 7.

Nothing below this line has been run end to end, because that client does not exist yet.
Do not treat any of it as verified:

- **Signing in with a real Google account.** No leg of the browser flow has ever reached
  Google's servers.
- **Restoring on a second device, or after an uninstall** — which is the entire point of
  linking, and the thing this game has never demonstrated.
- **The mobile round trip.** `OS.shell_open` sends the player out to the browser and
  they must return to the game by hand. The listener is written for exactly that:
  `_await_redirect()` checks for a waiting connection *before* it checks the timeout,
  because Godot's main loop is frozen while the app is backgrounded and the browser's
  connection sits in the kernel backlog until the player comes back. Written for it is
  not the same as seen working on a device.
- **The `FEDERATED_USER_ID_ALREADY_LINKED` branch** in
  `firebase_auth.link_with_google()`, which switches to the account that already holds
  progress instead of failing. That is the path a returning player on a new device
  actually takes, and it has never fired.

What works today regardless: the save is backed up to Firestore under an anonymous UID
and restored across launches on the same install. What does not: a new device or a
reinstall, because the anonymous session's refresh token lives in `user://` and is wiped
with the app.

## Android Auto Backup — the zero-UI half

Enabled on 2026-08-08 (`user_data_backup/allow=true` in `export_presets.cfg`, which
writes `android:allowBackup="true"` into the manifest). Godot ships this **off** by
default, so it was off here purely by inheritance, not by decision.

Auto Backup covers `getFilesDir()`, and Godot's `user://` maps to exactly that, so all
three of our state files ride along: `save.json`, `cloud_state.json` and
`firebase_auth.json`. **The one that matters is `firebase_auth.json`.** When the refresh
token comes back, the reinstall resumes under the *same anonymous UID*, the startup sync
finds the existing Firestore document, and `CloudPayload.decide()` corrects the stale
local save from the cloud. That is why Auto Backup's laziness (once a day, on wifi, while
idle) does not hurt us: the backup carries the **identity**, and the cloud already carries
the data.

This is deliberately not a replacement for Google account linking. It buys durability
across *reinstall on the same Google account*, silently and with no consent screen —
Google's docs are explicit that the restore flow's own consent covers it, so no extra
prompt is required. It does **not** cover two live devices, cross-platform continuity, or
a player who has device backup switched off. Linking remains the answer for those.

Limits worth knowing before trusting it: 25 MB per app (we use a few KB), Android 6+,
first backup only after ~24 h of idle+wifi, and the user must have backup enabled with a
Google account.

### What was verified, and what was not

Verified by A/B on an Android 14 emulator with `com.android.localtransport`, same
sequence both times, only the flag differing:

| Build | Manifest | `bmgr backupnow` |
|---|---|---|
| `lgh-return.apk` (2026-08-08 06:11) | `allowBackup=false` | `Backup is not allowed` |
| current | `allowBackup=true` | `Success`, 919 KB transferred |

**Not verified: the restore leg.** `bmgr restore` failed with `PM agent has no metadata,
so not restoring`, and `adb install` did not trigger an automatic restore. Both are
limitations of the local transport, which does not faithfully reproduce the real path
(Play install against a Google account). So "the backup is taken" is proven; "it comes
back" is not. Closing that needs a physical device: play, let the nightly backup run,
uninstall, reinstall from Play.

Also unverified: that the game itself adopts a *restored* `firebase_auth.json` and
resumes the same UID. The mechanism is sound and the code path is the ordinary startup
sync, but it was never watched end to end, because the game could not be made to render
on the emulator at all (see below).

### Two emulator traps that cost a session

- **`am force-stop` makes the app ineligible for backup.** Android skips packages in the
  stopped state, and `bmgr backupnow` reports the confusing `Backup is not allowed` —
  identical to what a genuinely disabled `allowBackup` produces. Launch the app and leave
  it running before backing up. This is a testing artifact only; a real player who opens
  the game is never in that state.
- **The game renders black on the emulator — root cause found, one-line workaround.**
  The symptom is `Couldn't present to Vulkan queue (VkResult error 5)` and a black
  screen, on the host GPU *and* on `swiftshader_indirect`. It is **not** a regression of
  ours: an untouched earlier build produces a byte-identical black screenshot.

  It is [godot#121035](https://github.com/godotengine/godot/issues/121035), fixed by
  PR #121701 in the **4.8** milestone — we are on 4.7, which is explicitly listed as
  affected. The mechanism: the emulator's **gfxstream** driver returns a *different*
  `VkQueue` handle from every `vkGetDeviceQueue()` call for the same family/index, so
  Swappy (frame pacing) cannot find the queue at present time and returns `VK_INCOMPLETE`
  — which is exactly the "error 5" in the log.

  **This cannot happen on a physical device**, and that is a statement about the
  mechanism, not just about our luck: a real Adreno/Mali driver returns a stable handle.
  It matches the field evidence — the same renderer config ran fine on a TECNO Spark 20
  Pro (180 s) and a Mi 9T (60 s) on 2026-08-08.

  Workaround for emulator testing only: set
  `display/window/frame_pacing/android/enable_frame_pacing=false` in `project.godot`,
  export, and the game renders and runs normally (verified — it reached gameplay and
  wrote its own `user://` state with a real anonymous UID). **Do not commit that
  setting.** Frame pacing is a real smoothness win on actual devices and the emulator is
  the only thing it breaks; flip it temporarily and revert, or wait for Godot 4.8.

  Unrelated trap noticed while chasing this: switching the *renderer* for a test needs
  `rendering/renderer/rendering_method.mobile`. Changing the platform-agnostic
  `rendering_method` has no effect on Android.

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
