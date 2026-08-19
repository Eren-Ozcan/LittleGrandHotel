# Website copy patch — in-app deletion path

**Status:** written 2026-08-19, to be applied on the `yilkgames.com` site (separate repo).

## Why

Both `https://yilkgames.com/privacy-policy/` (section *Data Retention & Deletion*) and
`https://yilkgames.com/account-deletion/` (section *How to Request Deletion*) currently
describe **email as the only way to get data deleted**. That has been out of date since
2026-08-18: Little Grand Hotel ships a self-service deletion path in the app, and
Play's Data safety form already points at these two URLs. A store reviewer who taps
through the app and then reads the page sees a mismatch.

## What the app actually does (verified in `src/main.gd`)

| Where | Control | Effect |
| --- | --- | --- |
| Profile ▸ Settings ▸ *Danger zone* | **Delete account data** (two-tap confirm) | Calls `CloudSave.delete_cloud_data()` **and** `Game.reset_game()` — the Firestore document and the on-device save are both removed. Toast: *"Your data was deleted."*, or *"Local data deleted — the cloud copy could not be reached."* if the server was unreachable. |
| Profile ▸ Settings ▸ *Danger zone* | **Reset save** (two-tap confirm) | Local save only. The cloud copy is untouched. |
| Profile ▸ Account | **Disconnect account** (two-tap confirm) | Unlinks the Google account and signs the session out. Deletes nothing; progress stays on the device. |

Email stays available and stays the route for anything the in-app button cannot cover —
a player who has already uninstalled, or who wants only part of the data removed.

## Insert 1 — `/account-deletion/`, at the top of *How to Request Deletion*

> **Fastest route (Little Grand Hotel): delete it yourself, in the game.**
> Open **Profile ▸ Settings**, scroll to **Danger zone** and tap **Delete account data**,
> then tap once more to confirm. This removes the cloud save *and* the copy on your
> device immediately — there is nothing to wait for and no email to send. If you only
> want to start over on this device while keeping the cloud copy, use **Reset save** in
> the same section; to unlink your Google account without deleting anything, use
> **Disconnect account** under **Profile ▸ Account**.
>
> Use the email route below if you have already uninstalled the game, if you cannot
> reach the button for any reason, or for our other games.

## Insert 2 — `/privacy-policy/`, in *Data Retention & Deletion*

Append after the sentence beginning *"For games with cloud save, uninstalling removes the
local copy only…"*:

> You do not have to wait for us to do this for you. Where a game offers it — Little
> Grand Hotel does, under **Profile ▸ Settings ▸ Danger zone ▸ Delete account data** —
> the game deletes the cloud record and the local save itself, on the spot. Writing to
> us, as described below, remains available and is the right route once the game is no
> longer installed.

## Checklist after applying

- [ ] Both pages mention the in-app path.
- [ ] The `#data-only` anchor on `/account-deletion/` still resolves (Play's Data safety
      form links straight to it).
- [ ] The wording matches the button labels character for character — reviewers do look
      for the literal string.
