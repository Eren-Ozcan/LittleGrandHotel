# Play Store Store Listing Content

You can copy-paste the following as-is into Play Console → "Store presence" →
"Main store listing". The character limits are Google's own limits; all of the
below are under the limit.

## App name (max 30 characters)

```
Little Grand Hotel
```

## Short description (max 80 characters)

Pick one of the following (both are under the limit):

```
Decorate a little hotel, welcome guests, raise your star rating!
```
(64 characters)

```
Build your hotel, decorate it, welcome guests — idle hotel management!
```
(70 characters)

## Full description (max 4000 characters)

```
Little Grand Hotel is a relaxing idle management game where you grow your own
little hotel from scratch into a starred chain.

🏨 BUILD YOUR HOTEL
Start with empty blocks, buy new rooms, and add facilities from guest rooms to a
restaurant, from a pool to a spa. Place your rooms however you like, move them,
and sell them if you need to.

🛋️ DECORATE, RAISE YOUR STARS
Furnish every room with furniture and decor, collect Style Score, and take your
hotel from Basic to Iconic. The more stylishly you decorate, the higher your
hotel's star rating climbs.

⏱️ MANAGE SHIFTS
Choose anything from a quick 1-hour round to a long 24-hour shift, and balance
staff cost against profit margin. Thanks to automatic shift renewal, your hotel
keeps producing even when you close the game.

🧹 CLEANING AND INFESTATIONS
Clean dirty rooms in time, or they turn into infestations! You can automate this
job by building a Cleaning Room.

🚶 A LIVING HOTEL
Make your hotel feel truly alive with guests queuing outside the door, wandering
around reception and riding the elevator up. Catch a runaway guest, poke a
sleeping guest and earn a bonus.

🏆 QUESTS, ACHIEVEMENTS, PRESTIGE
A chain of 20 quests, 13 permanent achievements and a prestige system where you
hand over your hotel at level 20 to earn a permanent income multiplier keep you
in the game.

🎁 DAILY REWARDS AND OFFLINE EARNINGS
Log in every day and collect increasing rewards. When you close the game and come
back, earnings for the time you spent offline are waiting for you too.

📴 PLAYABLE OFFLINE
The game runs entirely on your device and your progress is saved locally. If you
want, you can generate a save code from Settings and carry it to another device.

Download Little Grand Hotel and build your own little hotel empire!
```

## Graphic assets

Play Console requires the following:

- [x] **App icon**: 512×512 px, 32-bit PNG. Generated from `icon.svg` with
      `tools/gen_store_icon.gd` → `docs/store/icon_512.png`.
- [x] **Feature graphic**: 1024×500 px →
      `docs/store/feature_graphic_1024x500.png`.
- [x] **Phone screenshots**: `docs/store/screenshot_1_overview.png`,
      `docs/store/screenshot_2_lobby.png`.
- [ ] **Category**: Games → Simulation (suggestion).
- [ ] **Content rating questionnaire**: must be filled in on Play Console
      (there are ads + in-app purchases, no violence/gambling → it will probably
      come out as "Everyone" / PEGI 3, the questionnaire determines it
      automatically).
- [ ] **Data safety form**: because AdMob and Play Billing are used, it must be
      declared that the "advertising ID" and "purchase information" are collected —
      see `docs/store/privacy-policy.html`, its content was written to be
      consistent with this declaration.
- [x] **Privacy policy URL**: live at `https://yilkgames.com/privacy-policy/`
      and entered into the Play Console → App content → Privacy policy
      declaration (26 Jul 2026).
