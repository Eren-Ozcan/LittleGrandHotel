# LittleGrandHotel

## Store / Marketing Assets

Marketing assets such as store listing graphics, feature graphic, icon and the
full-resolution store screenshots are **never committed to this public repo**. They are
stored in two places:

1. Local, gitignored copy: `docs/store-assets-originals/`.
2. Private backup repo: `C:\Projects\pictures\LittleGrandHotel\` (local clone of the
   private `Eren-Ozcan/pictures` repo) — files are copied there and committed + pushed
   in that repo.

**One exception (agreed 2026-08-18): `docs/media/`.** The README needs a playable-looking
demo, and GitHub can only render files it can reach, so a small README set lives in the
repo: `demo.gif` plus a few 540x960 stills, a couple of MB in total. Everything else —
the 1080x1920 originals, `demo.mp4`, feature graphic, icon — stays out, under
`docs/store-assets-originals/` and the private repo. Regenerate the set with
`tests/showcase.tscn` (see README) rather than hand-recording new files.

## Ad placement policy

Ad triggers, cooldowns and consent flow follow the studio-wide rules in
`C:\Projects\pictures\ADS_POLICY.md` (private repo). Read it before adding or
moving any ad trigger — in particular, interstitials are never shown on app
open/resume (that scenario uses the App Open format), and the full-screen ad
cooldown must stay persisted, not session-only.

## Studio-wide information

For studio-wide questions that are not specific to this game — such as the Google
account, the Play Console developer account, or the status of yilkgames.com /
yilkgames_web — `C:\Projects\pictures\STUDIO.md` is the single source of truth and is
not duplicated here.
