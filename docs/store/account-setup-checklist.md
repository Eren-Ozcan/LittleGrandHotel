# Account Setup — Steps Only You Can Do

These require authentication/payment, so they cannot be done on my side.
At the end of each step, "what needs to be done in the code" is noted — I will
complete those parts once you bring me the real IDs.

## 1. Google Play Console account — ✅ Done

Registered on Play Console with the `yilkgamesstudio@gmail.com` account (studio
name: **Yilk Games**). What remains:

1. In Play Console, use "Create app" to create a new app with the package name
   `com.littlegrandhotel.app` (the package name is already set this way in
   `export_presets.cfg`, don't change it). "Yilk Games" will be shown as the
   developer name.
2. **Play App Signing**: when you upload the first AAB, Play Console automatically
   asks you to enroll in Play App Signing (a checkbox) — no separate setup is
   needed, it is enough to click "Continue" in the first upload flow.

Nothing to do on the code side — the signed AAB is already ready
(generated with `android/upload-keystore.jks`, see the project history).

## 2. AdMob account + real ad IDs — ✅ Done

The payment profile (AdSense Turkey) was linked, the app was added, two ad units
were created and wired into the code:

- **Account**: `yilkgamesstudio@gmail.com` (same account as Play Console — in the
  first round an AdMob account was accidentally also created on a different
  personal account (`crazything5341@gmail.com`); that account has no app and is
  empty but was not deleted, the payment information is still registered there —
  closing it could be considered so it doesn't cause confusion).
- ⚠️ **AdMob tax information missing**: under `admob.google.com` → Payments →
  Payment information, the "Turkey", "United States" and "Taiwan" tax information
  fields are empty. Without a completed tax form, a high withholding tax is
  deducted from US-sourced ad revenue — this needs to be filled in.
- **App ID**: `ca-app-pub-9709993577664180~6521383725`
  (`project.godot` → `[admob] general/android/app_id`)
- **Rewarded ad unit**: `ca-app-pub-9709993577664180/1269057042`
  (`src/autoload/ads.gd` → `_REWARDED_AD_UNIT_ID`)
- **Interstitial ad unit**: `ca-app-pub-9709993577664180/5208302053`
  (`src/autoload/ads.gd` → `_INTERSTITIAL_AD_UNIT_ID`) — `show_interstitial()` is
  implemented (5 min session cooldown) and called from `main.gd` at three natural
  break points: shift end, app resume (`NOTIFICATION_APPLICATION_FOCUS_IN`), and
  every 12th room/upgrade purchase (`_maybe_show_upgrade_ad`).

Note: it can take ~1 hour on the AdMob side for new ad units to start serving real
ads.

## 3. In-app products in Play Console

Detailed ID/name/description suggestions: [`in-app-products.md`](./in-app-products.md).
No extra changes are needed on the code side, the product IDs were already written
so they match the code (`remove_ads`, `income_2x`).

## 4. Privacy policy and store listing

- **Use the studio policy, not the files in this folder.**
  <https://yilkgames.com/privacy-policy/> covers every game and was updated on
  2026-08-08 to describe this game correctly: cloud save with an automatic anonymous
  player ID, optional Google linking (and that LGH's sign-in opens in the system
  browser), and Android Auto Backup. Paste that URL into Play Console → "Policy" →
  "Privacy policy".
- ⚠️ `privacy-policy.html` (2026-07-24) and `privacy-policy-plaintext.md` (2026-08-01)
  in this folder are **stale** — both predate cloud save and describe a game that
  sends nothing anywhere. Do not publish either. They are kept only as history; the
  Google Sites route they were written for is no longer needed now that the studio
  page exists.
- Graphic assets: done — hi-res icon (`icon_512.png`), feature graphic
  (`feature_graphic_1024x500.png`) and two screenshots
  (`screenshot_1_overview.png`, `screenshot_2_lobby.png`) are present in the repo.

## 5. Data Safety form (Play Console → App content → Data safety)

Only you can fill this in. What this game actually does, as of 2026-08-08:

| Data type | Collected | Shared | Purpose | Optional? |
|---|---|---|---|---|
| **App activity** → *Other user-generated content* — the save payload (hotel layout, rooms, decorations, coins/gems, quests, statistics, settings) | Yes | No | App functionality | **Required** — cloud save is not a setting the player turns on |
| **Personal info** → *Email address* and *Name* — only for players who link a Google account | Yes | No | Account management | **Optional** — a player who never links is never asked |
| **Device or other IDs** — the advertising ID, and the anonymous Firebase player ID | Yes | Yes (ads) | Advertising *and* App functionality | Required |
| **Location** → *Approximate location* — IP-derived, by the ad network only | Yes | Yes | Advertising | Required |

Other answers:

- **Is all data encrypted in transit?** Yes — Firestore and Identity Toolkit are
  reached over HTTPS only.
- **Can users request deletion?** **Yes**, and give the contact address from the
  privacy policy. There is no in-app delete button, and `firestore.rules` denies
  `delete` on `saves/{uid}`, so honouring a request means deleting the document from
  the Firebase console by hand. Know that before someone asks.
- **App content → Ads**: "My app contains ads" = **Yes**. Three formats ship:
  rewarded, interstitial and app-open (`src/autoload/ads.gd`).
- **Purchases**: this game uses Play Billing directly (`remove_ads`, `income_2x`) —
  no RevenueCat, unlike Reefy and Çengel Bulmaca, so RevenueCat must **not** be
  listed as a third party for this game.
- **Android Auto Backup is deliberately not declared here.** It copies the save into
  the *player's own* Google account backup; the data never reaches us, so it is not
  developer collection. It is disclosed in the privacy policy for transparency, which
  is the right place for it.
