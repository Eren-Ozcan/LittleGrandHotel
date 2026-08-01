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
  (`src/autoload/ads.gd` → `_INTERSTITIAL_AD_UNIT_ID`) — the ID is ready but
  `show_interstitial()` is still an empty stub (it is not called from anywhere in
  `main.gd`); the display logic should be added as a separate piece of work.

Note: it can take ~1 hour on the AdMob side for new ad units to start serving real
ads.

## 3. In-app products in Play Console

Detailed ID/name/description suggestions: [`uygulama-ici-urunler.md`](./uygulama-ici-urunler.md).
No extra changes are needed on the code side, the product IDs were already written
so they match the code (`remove_ads`, `income_2x`).

## 4. Privacy policy and store listing

- The texts are ready: [`privacy-policy.html`](./privacy-policy.html) (formatted, for
  reference), [`privacy-policy-plaintext.md`](./privacy-policy-plaintext.md)
  (plain text for copy-pasting into Google Sites),
  [`magaza-listeleme.md`](./magaza-listeleme.md).
- **Publishing with Google Sites** (without touching git/the repo at all):
  1. Go to https://sites.google.com with `yilkgamesstudio@gmail.com` and create a
     new "Blank" site.
  2. Set the site name to "Little Grand Hotel — Privacy Policy (Yilk Games)".
  3. Copy the contents of `privacy-policy-plaintext.md` and paste it into the text
     box; format the lines starting with `##` with the "Heading" style in the Sites
     editor (manually, a few clicks).
  4. Click "Publish" at the top right → it gives you a web address (e.g.
     `sites.google.com/view/little-grand-hotel-privacy`).
  5. Paste that address into Play Console → "Policy" → "Privacy policy" field.
- Graphic assets: done — hi-res icon (`icon_512.png`), feature graphic
  (`feature_graphic_1024x500.png`) and two screenshots
  (`screenshot_1_overview.png`, `screenshot_2_lobby.png`) are present in the repo.
