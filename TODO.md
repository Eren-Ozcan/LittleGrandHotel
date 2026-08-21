# Roadmap

## Done

### Phase 0 — Gray-box prototype
- [x] Core loop: room → decoration → shift → income → reinvestment
- [x] Data-driven economy (`data/economy.json`) — no hardcoded numbers in code

### MVP v2 — Core game
- [x] Shift system (1/4/8/24 hours, staff cost, 5–35% margin band)
- [x] Cleaning loop: rooms get dirty after `stay_hours`, income stops
- [x] Cleaning Room automation (duty ratio model)
- [x] Decoration: item → Style Score → tier (Basic → Iconic)
- [x] Star rating (tier 50% + facility variety 30% + service 20%)
- [x] XP / level curve + level-up gems
- [x] Quest chain (`data/quests.json`)
- [x] Save/load + offline earnings (48-hour cap)
- [x] Unit tests (`tests/sim_check.gd`) — headless economy verification

### Visual release — Hotel City-inspired
- [x] Cutaway "dollhouse" look: sky, skyline, clouds, red roof sign
- [x] SVG asset set: rooms, items, guests, UI icons
- [x] Wallpapered rooms, dark window frames, locked slot curtains
- [x] The building sits on the ground; street strip + guest queue during shifts
- [x] Floating toast (no layout jumping), live HH:MM:ss shift countdown
- [x] Time scale (`time_scale`) included in the save — shifts don't break when leaving fast mode

### Polish release — full core + late game (July 2026)
- [x] Bottom bar redesign: dark strip, live shift countdown with a clock icon, category icons
- [x] Touch feedback on a dirty room: golden sparkle animation
- [x] Coin collection animation (coins flying from the cash box to the counter)
- [x] Gem spending: instantly finish a shift with gems + premium items (Golden Statue, Royal Aquarium)
- [x] Sound effects (procedural WAV synthesis — no external files) + lobby music
- [x] Guest animations: waddling walk in the queue, fidgeting in the room
- [x] Room moving / selling (50% refund, premium item refunded in gems, confirmed sale)
- [x] Statistics screen (total income, cleanings, shift history — last 20)
- [x] Settings: sound/music toggle, confirmed save reset
- [x] Save version migration infrastructure (v2 → v3, step-by-step migration chain)
- [x] Late-game balance pass (level 28 scenario, 6 floors, margin test)
- [x] New room types: Restaurant (Lv.24) and Rooftop Garden (Lv.28)
- [x] Quest chain extended to 20 quests (q18–q20)

### Long-term release (July 2026)
- [x] The guest queue "walking" in through the door (position-based animation)
- [x] A little broom animation instead of a sparkle for dirty rooms (followed by the sparkle)
- [x] Achievements system: 13 permanent goals (`data/achievements.json`), listed in the Quests popup, save v4
- [x] Prestige system: hand over the hotel at level 20 for a permanent +20% income multiplier, save v5
- [x] Weekly decoration theme: serverless, deterministic via `Game.current_week_index()` (7 themes)
- [x] Shareable save code (base64, export/import from Settings) — at this point it was the *alternative* to cloud saves; real cloud save came later, see "Cloud save + Google account linking" below. The code still exists and is still the only transfer path that has actually been proven to work.
- [x] Android export: `export_presets.cfg` + ETC2 compression + locally signed debug APK verified

### Level design review + modern consumption habits (July 2026)
- [x] **Critical economy dead end fixed**: greedy room/item buying could put the player into an unrecoverable state where they couldn't even afford the cheapest shift (found with a headless simulation). `min_shift_reserve()` now guarantees at least the cost of a 1-hour shift after every purchase.
- [x] **Automatic shift renewal**: when a shift ended the hotel stopped completely, so when the player came back days later most of that time had been wasted — this conflicted with modern idle game expectations (production continues while you're away). It now renews automatically if there are enough coins (can be turned off), and a "Welcome back" popup reports it transparently.
- [x] **Trap option in shift duration selection fixed**: short shifts were cheaper per hour; with automatic renewal this turned into a meaningless choice that locked the player into a single "correct" option. The hourly rate is now equal across all durations.
- [x] **Daily login streak reward** added: the most standard retention mechanic of modern F2P was missing. A 7-day increasing reward cycle, serverless/deterministic.
- [x] **Decoration nudge**: to counter the risk that a greedy/inexperienced player's star rating never rises, a blinking golden "✦ Decorate!" badge is shown on empty guest rooms (if the cheapest item is affordable). The badge sits at the top right of the room button; tapping already opens the decoration popup.

### Hotel City review release (July 2026)
A mechanical + visual pass adapted by studying the original Hotel City's Gamezebo
guide (Web Archive) and the official Playfish blog art:
- [x] **Graded dirtiness → infestation**: a room left dirty for more than 6 hours turns into an infestation (cockroach icon, dark walls); cleaning it costs 150 coins. `dirty_hours` also accumulates during offline progression.
- [x] **Poking a sleeping guest (secret inspector)**: tap the guest in the room — 20 chances per day, a 25% chance of a coin bonus of 40+15×stars based on the star rating (save v8).
- [x] **Catching a runaway guest**: during a shift, roughly every 25 seconds a guest walks past on the street; if you tap them they return to the door, giving a bonus of 15% of the hourly income.
- [x] **Ready-made decor bundles**: Comfort / Wood / Royal bundles, 10–12% discounted, locked according to the highest-tier item in the bundle.
- [x] **Facility capacity**: during a shift, mini guests appear in facilities up to their capacity.
- [x] **Visual refresh**: chibi guests (3 characters), bellboy + maid, a lobby scene with columns/elevator, rich facility scenes (pool, cinema, gym, spa, cleaning), Hotel City-style room tier meter (red→green).
- [x] Screenshot verification tool: `tests/shot.tscn` (shift view with the `-- demo` argument).

### Free block placement + furniture system (July 2026)
A major architectural change faithful to Hotel City's real "total block" economy —
moving from the fixed "N floors × 4 slots" grid to free placement:
- [x] All character/furniture/room/facility art was replaced with new
      chibi/pastel art from reference pages (`assets/guests`, `assets/items`,
      `assets/rooms`, `assets/ui`).
- [x] `data/economy.json`: `slots_per_floor` was removed and the block economy
      (`grid_cols`, `block_price`) added; every room type got a `footprint_w`
      (1/2/3 blocks); items were split into base (`slot`: wallpaper/floor/bed —
      single choice, comes with a free default, upgradeable) and decor
      (`anchor`: ceiling/wall/floor — cumulative).
- [x] `game.gd`: `place_room`/`can_place_room`, `buy_block`/`can_buy_block`,
      `move_room_to`, `upgrade_base` added; save migration v10→v11 (verified
      with a real user save, no data loss).
- [x] `main.gd`: the building view was moved from `HBoxContainer` rows to a
      single manually positioned canvas (`building_canvas`) — variable floor
      widths (staircase silhouette), zoom (−/⟳/+ + mouse wheel + pinch)
      and pan (dragging).
- [x] Room placement: tapping an empty cell and picking a room from the shop
      places it exactly in that cell (`place_room`); additionally, an existing
      room can be **long-pressed and dragged** into another empty cell (real
      drag-and-drop, with a ghost preview).
- [x] Street: instead of a flat asphalt strip there are now sidewalk (with
      paving joints) + curb + lane-marked road layers — giving the feeling that
      the building stands at the edge of an avenue.
- [x] The 32-section `sim_check.gd` test suite was updated for the new API, and
      a real save was added under `tests/fixtures/` as a golden fixture.

### Building view fine-tuning (decided with the user on 2026-07-12)
- [x] **Zoom-out limit tightened**: `ZOOM_MIN` is no longer an absolute floor;
      the real lower bound is computed dynamically from the building size via
      `_effective_zoom_min()` — you can no longer zoom out past the point where
      the building exactly fills the viewport (verified with a headless
      screenshot of an 11-floor building: when it fits exactly, there is no
      border left).
- [x] **"Build Mode" added**: a toggle button above the building view
      (`build_mode_button`). When off, empty cells are a plain/neutral panel
      (no button/text) and locked blocks are just the curtain art (no price
      label); when on, cells are highlighted and become tappable.
      (Note: this behavior was changed again the same day — see the
      "Drag from the shop shelf" section below; the "+ Add room" button was
      removed entirely.)
- [x] **Pan verified on large buildings**: thanks to the dynamic zoom-min it is
      no longer possible to zoom out so far that empty margins appear; since
      empty/locked cells no longer swallow mouse events while Build Mode is off
      (mouse_filter ignore), drag-to-pan spreads more smoothly across the whole
      building. A separate camera model change was not deemed necessary.

### Phase 4/5 — guest room shell + old variant cleanup (2026-07-12)
- [x] **Phase 4 — New art**: contrary to expectations, no new AI art generation
      was needed — `assets/rooms/guest_wallpaper.svg` (tintable wallpaper
      pattern) and `assets/items/bed_basic|bed_wood|bed_canopy` (chibi/pastel
      bed sprites) were already sitting in the repo from previous rounds but had
      never been wired into the code. `_make_room_button` now draws guest rooms
      with a real shell: wallpaper tinted according to the `WALLPAPERS` tier +
      the new `guest_floor.svg` floor strip + the real bed sprite chosen
      according to the room's `base.bed` field — previously upgrading the bed
      (`Game.upgrade_base`) had NO visual effect whatsoever (a random
      "pre-made scene" PNG was fixed per room type), which is now fixed. As a
      side effect it was discovered that `bed_wood.png` was accidentally the
      same wardrobe art as `wardrobe_oak.png` (an asset mapping error) — it was
      replaced with a correct, hand-drawn `bed_wood.svg`.
- [x] **Phase 5 — Cleanup**: the old `GUEST_ROOM_ART` constant (main.gd) and the
      15 `assets/rooms/guest_room_*.png` files (+ .import) that were no longer
      used anywhere were deleted.

### Adding rooms by dragging from the shop shelf (2026-07-12, user request + Hotel City reference)
User request: "rooms that aren't unlocked shouldn't be created… rooms should be in
something like a shop where you pick one and add it by press-and-drag… there
should be a build mode with editing/adding etc." (see the Gamezebo Hotel City guide).
- [x] The "+ Add room" button on empty unlocked cells was removed entirely — no
      cell now shows a self-created add button.
      In its first form a highlighted framed box still remained while Build Mode
      was on; with user feedback (a screenshot) this was removed too — an empty
      cell now shows NO visual box/frame at all, regardless of whether Build
      Mode is on or off (`_make_add_cell_button`/
      `_make_plain_empty_cell`, `StyleBoxEmpty`).
- [x] Second feedback round: the per-floor filler "floor strip" (`row_bg`, a beige
      `PanelContainer` spanning each floor at full width) was also removed —
      rooms and locked blocks already draw their own full cards, and in empty
      areas the sky/skyline background is now visible directly (exactly matching
      Hotel City's "rooms appear to be floating in midair" total-block
      aesthetic).
- [x] Third feedback round: the red curtain art of locked blocks
      (`_make_block_cell_button`) was also removed while Build Mode is off — it
      is now completely invisible like the other empty cells, and the curtain +
      price + "buy block" only appear while Build Mode is on. In exchange, since
      both rooms and empty space now sit on the same transparent background, a
      distinct wall frame was added to `_make_room_button` so rooms read clearly
      (the previously defined but never used `PALETTE.frame`, a thick 4px
      border) — user request: "a wall-like frame around the rooms".
- [x] Fourth feedback round: the `CELL_GAP` gap between room cards (which until
      then showed bare sky) was filled with a new texture
      (`assets/ui/brick_wall.svg`, a tileable running-bond brick pattern) — it is
      tiled across each room's FULL cell area (including the gap) and the room
      card sits slightly inset on top of it; since side-by-side rooms are in
      adjacent cells, their brick areas also merge and look like one continuous
      wall (user request: "when they're side by side they should complete each
      other").
- [x] Fifth feedback round: the frame/brick were "visually inconsistent, make
      them a bit wider" — `CELL_GAP` was changed 6→12px and the room frame
      thickness 4→7px; the brick texture now reads as a distinct strip in which
      individual bricks can be made out. Also, multi-cell room widths
      (2x1/3x1 etc.) already existed and were verified to work correctly —
      Deluxe/Suite/Pool/Cinema/Spa/Rooftop Garden are 2 blocks and Restaurant is
      3 blocks (`data/economy.json: footprint_w`), and a screenshot (Deluxe +
      Restaurant side by side) confirmed they render at the correct proportions.
- [x] Sixth feedback round: the lobby got the same treatment as the room wall
      frame (`lobby_wall`, `_rebuild_hotel`), with a `DOOR_W`-wide (60px) cut in
      the wall at its right end. It took four attempts: (1) a detailed SVG (a
      warmly lit opening + wooden trim) — the user couldn't tell what it was;
      (2) a double-leaf glass door — the user said "in a 2D straight cutaway a
      real door object isn't visible"; (3) misreading a Hotel City screenshot
      the user sent, a flat-colored rectangle + thick frame was added; (4) the
      user rejected that too and clarified: "the gap will look like a door
      anyway" — NO object/color at all, only a plain gap where the wall is cut
      and the background (sky) shows through. The guest walk-in animation at the
      start of a shift (`_guest_walk_in`) walks correctly toward the real canvas
      position of that gap (converted according to zoom/pan). (In a fifth
      sub-round the user changed their mind and asked for a flat blue
      `ColorRect` — `door_bar` — at the same position; its first form was too
      thick and in the wrong place (it covered the whole `DOOR_W` gap, in dark
      navy) — the user corrected it: "it should sit on top of the wall on the
      right, glass blue" → it was made thin (10px, `DOOR_BAR_W`) and moved to
      the immediate right edge of the wall (`lobby_wall`) so it doesn't spill
      into the gap, and its color changed to a light glass blue (`#bfe6f2`).
      The user then pointed out that the top/bottom ends of the bar spilled over
      the wall's ceiling/floor strip — it was inset vertically with
      `DOOR_BAR_MARGIN` (10px), so the wall's own strip is now visible at the
      top and bottom edges.)
- [x] Eighth feedback round: `LOBBY_H` was changed 84→120 — the golden elevator
      in the lobby scene (`lobby.svg`) didn't fit vertically at the previous
      height (`STRETCH_KEEP_ASPECT_COVERED` was cropping its top/bottom).
- [x] Ninth feedback round: the bellboy in the lobby (`bellboy.svg`) was replaced
      with a real receptionist image cut from a reference video the user provided
      (`ro_ve_ro_arası_gif_şeklinde.mp4` — chibi receptionist frames labeled
      "R01_Neutral"/"R03_Typing") (`assets/guests/receptionist.png` — frame
      extraction with ffmpeg + making the gray background transparent with
      Pillow + a tight crop). Because of the portrait aspect ratio it was placed
      with a custom `TextureRect` + `STRETCH_KEEP_ASPECT_CENTERED` instead of
      `_icon()`'s fixed-square box.
- [x] Seventh feedback round: the red brick texture "stuck out" —
      `assets/ui/brick_wall.svg` was recolored to warm cream/golden stone block
      tones (consistent with the `PALETTE.facade`/`facade_line`/`wood` family)
      and renamed to `assets/ui/wall_block.svg`; the pattern (running bond)
      stayed the same, only the color changed.
- [x] Tenth feedback round: an animated elevator door was added using 3 images
      (`elevator_closed/half/open.png`) cut from a reference sprite sheet the
      user sent (8 elevator door frames, closed/ajar/open)
      (`_update_elevator`, `_elevator_texture_path`, `elevator_tex`).
      The door opens and closes in a closed→ajar→open→(the queue empties
      completely)→ajar→closed cycle whenever the guest queue on the sidewalk
      (`_queue_count`) is greater than 1; about 1 second after it closes, a
      sparkle above the elevator represents "the guests reaching their rooms"
      (since per-room arrival timing does not exist in the data model, this was
      simplified into that visual acknowledgment instead of a full simulation —
      the user was informed). Previously the queue was a fixed
      `mini(3 + Game.rooms.size()/2, 8)` formula and NEVER decreased (the "long
      queue" complaint) — it now grows over time (+1 every 4 seconds, capped at
      6) and empties completely on every elevator opening; if there are 2+
      guests they all board in ONE go (instead of waiting in turn).
      An important finding during debugging: the changes I made to/removed from
      `lobby.svg` had no effect at all, because `_tex()` prefers a `.png` with
      the same name if one exists next to the `.svg` — `assets/ui/lobby.png`
      (the "chibi" final render left over from earlier rounds) still contained
      the old elevator, which is why TWO elevators were showing SIDE BY SIDE.
      Fix: the old elevator area in `lobby.png` was painted over with Pillow by
      sampling the wall's own gradient (clean, seamless).
- [x] Eleventh feedback round: the user wanted the new elevator's position to
      line up exactly with the old fixed art. The first placement was computed
      with a simple viewBox ratio (262/480 etc.) — but since `lobby_scene` uses
      `STRETCH_KEEP_ASPECT_COVERED`, the texture is cropped horizontally, which
      invalidates the simple ratio math (this was exactly the root cause of the
      "two elevators" bug). The correct transform was computed: control
      648×108, texture 1920×256, scale=max(648/1920,108/256)=0.421875
      (height dominant), 162px horizontal overflow → 81px cropped from each
      side (=192 original pixels). The old elevator's real position in
      `lobby.png` (x≈850–1040, y≈5–222) was recovered from git history (the
      commit before it was deleted) and converted into the correct fractions
      with this transform (`elevator_tex` anchors 0.535–0.685 → 0.428–0.552).
- [x] Twelfth feedback round: the user noticed a "half-finished" shape behind the
      elevator — in the previous `lobby.png` patch, x=100 had been used as the
      reference column, but that column crossed one of the wall's long
      decorative lines; that line abruptly started and stopped at the edge of
      the patch box (a cut-off look). The patch was redone using a genuinely
      clean column (x=1120, verified to be line-free along its full height) —
      it is now seamless and flat.
- [x] Thirteenth feedback round: the user clarified the logic of the elevator
      queue — "normal people will walk along the sidewalk, most of them will
      come to the hotel; if there's going to be a queue at reception, fine;
      the customers will come in through the door, not straight in." In the
      previous design `_queue_count` was incremented by a silent timer and
      STATIC icons were shown on the sidewalk — both were removed. In their
      place, `_spawn_arriving_pedestrian()`: roughly every 3 seconds an actually
      walking pedestrian appears from the right of the sidewalk; with 75%
      probability they walk to the door's real screen position
      (`_door_screen_x()`, made shared), shrink as they enter and are added to
      `_queue_count` AT THAT MOMENT (not at spawn time, but when they ARRIVE at
      the door); with 25% probability they carry on like an ordinary pedestrian
      and exit the screen (this doesn't get mixed up with the runaway-guest/
      catching mechanic, which stays separate). The 4-person welcome group at
      the start of a shift (`_guest_walk_in`) is now also added to the queue the
      same way.
- [x] Fourteenth feedback round (four fixes at once, 2026-07-13):
      (1) **Rooms looked occupied as soon as a shift started** — a new
      `_arrived_guests` counter: room cards only show the guest art once enough
      guests have gone UP in the elevator for that room's turn to come
      (`_deliver_guests` increments the counter ~1 second after the door
      closes); facility crowds are also hidden until the first delivery. If the
      app is opened in the middle of an ongoing shift, guests are considered
      settled (999).
      (2) **The city skyline in the background was removed** (`skyline.svg`
      deleted); the building view now fills all remaining vertical space on the
      screen (`zoom_viewport` EXPAND_FILL), a fit-to-width zoom is performed once
      at startup, and if the building is shorter than the viewport it is aligned
      to the BOTTOM (the road at the very bottom of the screen). This
      full-screen transition also made visible a long-standing double-offset bug
      in the road lane lines (the lines were floating outside the canvas) — fixed.
      (3) **The elevator was opening and closing constantly** — a minimum 9-second
      wait in the closed state (it opens early if the queue reaches 3+); also,
      state transitions now only swap the texture instead of doing a full
      `_rebuild_hotel` (no more full canvas rebuild once per second — this was
      also the main cause of the stutters).
      (4) **Pedestrians were getting stuck off the sidewalk** — root cause: the
      pedestrians were added to the root in screen space, so when the user
      panned/zoomed they came loose from the sidewalk. All pedestrians
      (`_walker_layer`) now live inside building_canvas in canvas-local
      coordinates — they take the zoom/pan along with the world; `_rebuild_hotel`
      preserves this layer instead of deleting it. Entering guests walk in from
      the left and reach the door on the right; a caught runaway guest also
      returns to the door and is added to the queue.
- [x] Fifteenth feedback round (five fixes at once, 2026-07-13):
      (1) **The street was empty without a shift** — the pedestrian flow was
      split into two independent channels (`_update_pedestrians`): "passing by"
      pedestrians now walk past in both directions at random 10–22 second
      intervals whether or not there is a shift (`_spawn_passerby`); guests
      coming to the hotel are a separate channel.
      (2) **"Finish now with gems" appeared not to work** — root cause:
      `skip_shift()` did end the shift, but automatic renewal (on by default)
      instantly restarted the same shift on the NEXT frame (even a comment in the
      test file had documented this oddity).
      `skip_shift()` now sets `last_shift_hours = 0`: a shift that is
      deliberately ended does not renew itself; automatic renewal is active again
      with the next manually started shift. Also a UI leg of it: because the
      `state_changed` signal was not emitted when a shift ended by its natural
      duration, the guest art in rooms stayed stuck — `_rebuild_hotel` was added
      to the elevator reset branch.
      (3+4) **Pedestrians came back to back and there were too many of them** —
      the tempo of guests coming to the hotel now scales with the room count
      (`110s / room count`, clamped to a 4–25s band, ±35% random): a 20-room
      hotel fills up in ~2 minutes, while in a 2-room hotel a guest arrives about
      every 25 seconds. If enough guests have arrived/are on their way to fill
      the empty rooms (including the `_inbound` counter), NO new ones come at
      all. The opening welcome group was also reduced from a fixed 4 to
      `min(room count, 3)`.
      (5) **Walking wasn't visible in the lobby** — a guest reaching the door no
      longer disappears: with `_spawn_lobby_walker` they walk INSIDE the lobby
      from the door to reception/the elevator, and are written into the queue
      once they fade out in front of the elevator. A caught runaway guest
      follows the same lobby path.
      Headless verification: in a 2-room hotel the group filled the rooms at
      t≈12s through the sidewalk→lobby→elevator→room chain, and the flow stopped
      once the quota was full; after `skip_shift` the shift stayed closed; a
      guest walking inside the lobby was confirmed in a screenshot.
- [x] A new "Room Shop" shelf was added (`build_shop_panel`/`build_shop_row`,
      visible only while Build Mode is on): a card per room type showing its
      price/level lock; press-and-holding a card and dragging it onto the
      building calls `Game.place_room`. The existing room-moving drag system
      (`_drag_room_id`/`_update_room_drag`/`_finish_drag`) was generalized with
      `_drag_new_type` — the two share the same state machine.
- [x] All structural editing (adding, moving, selling rooms) is now only possible
      while Build Mode is on — when it is off, the room popup shows a warning
      text instead of the Move/Sell buttons. The bottom bar "Shop" button no
      longer opens the old list, it directly turns on Build Mode.
- [x] The old targeted shop popup (`_build_shop_popup`, `place_target_floor`/
      `place_target_col`) was deleted entirely — there had previously been no
      unit tests at all for `Game.place_room`/`can_place_room`, so they were
      added to `tests/sim_check.gd`.

### Google Play release preparation (July 2026)
- [x] The real Google Play Billing + AdMob (Poing Studios) plugins were integrated
      under `addons/`; `src/autoload/ads.gd`/`iap.gd` use these plugins in a real
      Android build, while the old mock (instant success) behavior is preserved on
      desktop/editor/headless tests (`tests/sim_check.gd`) via an
      `Engine.has_singleton(...)` guard — the existing tests pass unchanged.
- [x] Purchase restore (`IAP.purchase_result` → `main.gd`) and a toast for when an
      ad isn't ready were added.
- [x] `export_presets.cfg`: gradle build enabled, min/target SDK 24/36,
      `gradle_build/export_format=1` (AAB — a Play Store requirement), adaptive
      launcher icons generated from `icon.svg` (`android/icons/`, see `tools/gen_icons.gd`).
- [x] `android/build/` (Godot's vendored gradle template) was installed — because
      the CLI flag `--install-android-build-template` froze in headless mode in
      this environment, it was installed manually with a `.build_version` marker;
      `.gitignore` was fixed so that it only excludes the generated sub-paths
      (`build/`, `.gradle/`, `libs/` [~200MB engine libraries], copied assets,
      generated icon resources) — the real template source under `android/build/`
      is committed.
- [x] A release keystore was created (`android/upload-keystore.jks`), a signed AAB
      was produced and verified (`jarsigner -verify`, with manifest/permission/plugin
      integration confirmed via `aapt2 dump badging/xmltree`).
- [x] **This July list is done — checked item by item in the console on 2026-08-21.**
      The Play Console account exists (Yilk Games), AdMob is live with three real ad
      unit IDs and no Google test IDs left in `ads.gd`, Play App Signing is enrolled,
      and the privacy policy and store listing are published. Only one thing in it was
      *not* true, and it is now its own entry below.
- [ ] **The three gem packs do not exist in Play Console.** Verified 2026-08-21:
      Monetise ▸ One-time products lists exactly **two** — `income_2x` and
      `remove_ads`, both created 26 Jul 2026. Missing: **`gems_small`,
      `gems_medium`, `gems_large`**.
      This is not cosmetic. `main.gd`'s `GEM_PACKS` table drives a live screen (the
      gems `+` button → `_build_gems_popup`), so on a real device every gem pack row
      calls `IAP.purchase("gems_small"…)` and Play answers "item unavailable" — the
      purchase fails silently and `price_for()` stays on the placeholder label
      forever. Nothing in the build catches it, because the desktop mock always
      succeeds; `tests/iap_check` verifies the ids match `docs/store/in-app-products.md`,
      which they do — the doc and the code agree, the *console* is the odd one out.
      Create them as one-time **Managed products**; there is no separate consumable
      type in Play Billing, consumption is app-side and `iap.gd` already does it.
      Ids, names and prices are in `docs/store/in-app-products.md`.
      **Attempted on 2026-08-21 and deliberately abandoned half-way — nothing was
      created, the list is still the same two products.** Three reasons to do this
      by hand instead: the price field follows the console's UI language, so `1.99`
      typed into the Turkish console produced **USD 199,99** (a 100× error that was
      caught before activating, but only by reading a row back); the create form
      repeatedly lost its Product ID through automation and ended on
      *"Değişiklikleriniz kaydedilemedi"*; and a product id, once created, cannot be
      deleted or reused — only deactivated. Both traps are now written down at the
      top of `docs/store/in-app-products.md`.

### Main menu screen (July 2026, user request + 2026 mobile UI research)
The game previously opened directly into gameplay with no main menu at all.
User request: "make nice designs for the main menu… update it according to what
users like… make sure the art and the popups don't overlap". Web research
(Pixune, Fireart Studio, mobile UI trend articles) pointed to a consistent
conclusion: players prefer simple opening screens with a single clear action
("one CTA"), plenty of whitespace, and consistency with the game's existing visual
language — so instead of inventing a separate visual style, consistency with the
existing `PALETTE`/`_button`/`_label` language was preserved.
- [x] `_build_start_screen()`: a full-screen opening layer on top (added as the
      last child) — sky gradient, clouds confined to the top third (a fixed
      region that never collides with the center column), a centered logo
      (`icon.svg`) + the hotel name + a personalized subtitle (inviting text for
      a new player, a "Level N · X ⭐" summary for a returning one) + a single
      large pulsing "PLAY"/"CONTINUE" CTA (the same embossing/shadow/pulse
      language as the collect button). At the top right an independently
      corner-anchored sound toggle, and a version label along the bottom edge —
      both OUTSIDE the flow of the center column, so they never overlap
      regardless of screen size.
- [x] The tutorial/daily reward/offline popup chain (`_maybe_show_tutorial`) is
      now triggered not in `_ready()` but AFTER "PLAY" is pressed and the menu
      closes with a fade animation — otherwise on the very first launch the
      tutorial popup would open invisibly behind the menu.
      Verified with a `--resolution 540x960` windowed screenshot:
      the menu renders on its own without overlaps, and when "PLAY" is clicked it
      fades out and closes, with the game screen underneath (top bar, hotel,
      bottom bar) and the Daily Reward popup opening on top of it laid out
      correctly and without overlap.
      `tests/sim_check.gd` (economy/save) keeps passing unchanged.

### Main menu → converted into a loading screen (July 2026)
The user clarified: this screen shouldn't really be an interactive "main menu",
it should be a **loading screen** shown when the game first launches — no CTA/PLAY
button, plain (art + the game name only), moving on to the game by itself after a
fixed amount of time.
- [x] `_build_start_screen()`: the "PLAY/CONTINUE" button, the pulse tween, the
      personalized subtitle and the sound toggle at the top right were all removed
      (sound is already in the Settings screen). Only the logo + hotel name +
      growth animation + version label remain.
- [x] `_on_play_pressed` was renamed to `_finish_loading_screen`; it is now bound
      not to a button but to `get_tree().create_timer(4.2).timeout` — right after
      the growth animation reaches the "big hotel" stage at least once, the screen
      automatically fades out and closes, and the tutorial/daily reward chain is
      triggered AFTER that close exactly as before.
      Headless verification: it was confirmed that at t≈4.6s `start_screen` is
      null and that the "Welcome" tutorial popup then opens correctly.

### Main menu art pack (July 2026, produced with Google Flow)
The main menu in its first version was entirely procedural (a flat gradient + 3
simple vector clouds); the user noted that this looked "poor" compared to the rest
of the game (chibi/pastel PNG illustrations). The first attempt with Google Flow
(labs.google/flow, Nano Banana 2) produced a painterly/soft-shadowed style, but the
user said it was "unrelated to what the game actually looks like" — the correct
style was captured on the second attempt by taking a headless screenshot
(`tests/shot.gd`) and using the game's actual style (thick dark-brown outlines, flat
cel-shaded colors, no shadows) as the reference.
- [x] A 3-stage growth sprite was produced (`assets/ui/menu_hotel_stage1|2|3.png`,
      transparent background — alpha-keying from the white backdrop with Pillow +
      cropping to the content box): a small cabin inn → a mid-size boutique hotel →
      a large/showy hotel.
- [x] `main.gd:_build_start_screen()`: in the empty area below the CTA button
      (between the button and the version label, fixed-anchored OUTSIDE the flow of
      the center column) an infinitely looping small→medium→large growth animation —
      staged scaling + texture swapping with a Tween, growing upward from a fixed
      base (pivot).
      Even at the largest stage (scale 1.15) the box size/position was tuned by
      measuring on a screenshot so that it doesn't overlap the CTA button or the
      version label (`growth_wrap` `anchor_top=0.735`, height 195px).
      `TextureRect.expand_mode = EXPAND_IGNORE_SIZE` is required — otherwise the
      control grows to the texture's real pixel size and overflows the screen (a bug
      found on the first attempt).
- [x] Google account note: the user's personal account (`ralakuss0@gmail.com`) was
      used in Flow, separate from the studio account (`yilkgamesstudio`) —
      see user memory.
- Considered and deferred: the idea of the small→large transition being a real Flow
      video (Veo) — the user preferred the in-game Tween animation (above), which
      needs no video/codec infrastructure.

### Opening tutorial + popup refresh (July 2026)
- [x] A simple 6-step popup sequence was added on the first launch (on a brand-new
      save) (`Game.tutorial_seen`, save migration v11→v12); it can be triggered
      again with Settings → Reset Save.
- [x] The daily reward, "Welcome back" (offline earnings) and tutorial popups were
      moved from Godot's native `AcceptDialog` (a look that didn't match the rest of
      the game, and a "it won't close" feeling on chained openings) to the game's own
      `_panel`/`_label`/`_button` language (`_show_simple_modal()`).

### Cloud save + Google account linking (2026-08-07)
Save backup to Firebase, and the sign-in flow that is supposed to make it survive a new
device. Setup, reasoning and the remaining manual step: `docs/cloud-save-setup.md`.
- [x] **Cloud save over REST** (Godot has no Firebase SDK): anonymous Authentication +
      a single Firestore document at `saves/{uid}`, `src/cloud/` + `src/autoload/cloud_save.gd`.
      Verified against the live project with `curl` — including the case that matters,
      a stale client trying to write an older `rev` being rejected by `firestore.rules`
      rather than by the client.
- [x] **Device clock is never trusted**: a monotonic `rev` counter decides what is newer,
      not a timestamp, so a device with its clock pushed forward cannot destroy progress.
- [x] **No automatic merge on conflict** — blending two hotels breaks the economy and
      invites abuse, so the player picks "Cloud" or "This device"; nothing is written to
      the cloud until they do, which leaves the cloud copy intact as a backup meanwhile.
- [x] **Entitlements (`remove_ads`, `permanent_income_mult`) are never carried by the
      cloud payload** — the store is their only source of truth, otherwise a cloud save
      would become a way to hand out paid goods.
- [x] **Upload throttle raised 60 s → 300 s**: at 60 s an idle game re-dirties the save
      immediately after every write, which would exhaust Firestore's free daily quota at
      roughly 500 daily active players. Backgrounding still forces an immediate write.
- [x] **Google sign-in without any native plugin** (`src/cloud/google_signin.gd`): system
      browser + `127.0.0.1` loopback redirect + PKCE (RFC 8252 / RFC 7636), in pure
      GDScript. One code path for Android, iOS and desktop — no Kotlin/Swift plugin to
      maintain and **no extra work for the iOS port**. It fills the existing
      `set_google_id_token_provider()` seam, so a native plugin can still replace it later
      by changing one call.
- [x] **The OAuth client id/secret stay out of this public repo**: loaded at runtime from
      the gitignored `src/cloud/google_oauth_client.gd`, with
      `google_oauth_client.example.gd` committed as the template. (A Desktop client secret
      is not a real secret per Google's own docs — PKCE is the actual protection — but a
      secret-shaped string in a public repo trips push protection and leak scanners.)
- [x] The stale "add the Play app-signing SHA-1 or Google sign-in breaks" blocker was
      removed from the docs: fingerprints identify *Android* OAuth clients, and this flow
      presents a Desktop client through the browser, so nothing in the path depends on how
      the APK was signed.
- [x] **Superseded 2026-08-08 — this section's closing caveat is no longer true.** It used
      to read that the OAuth Desktop client did not exist and no leg of the flow had ever
      reached Google. Both were overtaken the same night: the client was created, linking
      was run against a real account and proven across two real devices, and `afe359d`
      fixed the one bug that run exposed — the browser round trip backgrounds the game,
      Android freezes Godot's main loop and defers background network, so the token
      exchange timed out with an empty body and linking failed *silently*. The exchange
      now waits for the app to return to the foreground and retries three times.
      Still open from the original caveat: whether Google requires a verification review
      before the consent screen can be published for all players.

### Android Auto Backup (2026-08-08)
- [x] `user_data_backup/allow=true` — Godot ships this off by default, so the save had
      been dying with the app on every uninstall for no reason anyone had chosen. Now
      `user://` (`save.json`, `cloud_state.json`, `firebase_auth.json`) rides Android's
      own backup. The load-bearing file is `firebase_auth.json`: restoring the refresh
      token resumes the same anonymous UID, so the startup sync repairs the local save
      from Firestore — the backup carries the identity, the cloud carries the data.
- [x] Verified by A/B on an Android 14 emulator, same sequence, only the flag differing:
      the previous build reports `Backup is not allowed`, this one `Success` (919 KB).
- [x] **The restore leg is proven** (2026-08-21). The blocker was never ours: the local
      transport's `@pm@` `@meta@` entity was a **0-byte leftover**, so
      `PackageManagerBackupAgent` hit `EOFException` and the service reported it as the
      misleading `PM agent has no metadata`. `bmgr wipe … @pm@` does *not* clear it —
      deleting `/data/backup/com.android.localtransport.LocalTransport/@pm@` and the
      `_delta/@pm@` dataset does. After that the full cycle runs clean: seed a marked save
      → `bmgr backupnow` → uninstall → install → `bmgr restore` returns
      `restoreFinished: 0` and `save.json` / `firebase_auth.json` / a sentinel file come
      back **byte-identical**. Launching then showed the game adopting the restored
      identity — same anonymous UID as before the uninstall, restored save untouched —
      which also closes the second "unverified" note. Commands and the exact stale-file
      path are in `docs/cloud-save-setup.md`. What a device would still add: the Play/GMS
      transport instead of `com.android.localtransport`, and the ~24 h idle+wifi schedule.

### Playable web demo + Turkish screenshots (2026-08-19)
- [x] Web export preset (`Web` in `export_presets.cfg`): single-threaded, so no
      cross-origin isolation headers are needed and GitHub Pages can serve it. Carries
      the custom feature `demo`; `Game._ready()` starts such a build in English whatever
      the browser locale says, and the player can still change it in Settings.
- [x] Published to the `gh-pages` branch (49 MB: 39 MB wasm + 11 MB pck).
- [x] `tests/showcase.tscn` takes `lang=tr`, and `scripts/make_store_shots.py tr` builds
      the caption bands in Turkish (captions are hand-upper-cased — `str.upper()` is
      locale-independent and breaks Turkish "i").
- [x] Two popup titles the showcase invented were fixed to the ones the game actually
      shows ("Profile", "Room Decoration"); the made-up ones had no translation and
      stayed English in the localised set.

### Turkish localisation (2026-08-19)
- [x] The whole interface goes through `tr()`. `Label.text` / `Button.text` keep the
      **English string as the key** and Godot auto-translates them on display, so a
      language switch re-translates the standing UI for free; only strings built with
      `%` (and a handful measured before display) are wrapped explicitly at their call
      site. `data/i18n/strings.csv` holds 440 rows — every UI string plus the quest,
      achievement, room, tier, item and bundle names out of `data/*.json`.
- [x] Settings ▸ **Language** cycles System → English → Türkçe, persisted in the save
      (`language`, save v15; migrating players default to the device language, which is
      what they had before).
- [x] Two traps that only show up in another language, both fixed: room plaques were
      measured with `_fit_font_size` *before* translation, so longer Turkish names spilled
      out of the plaque; and `String.to_upper()` is locale-agnostic, so section headings
      read "TEHLIKELI BÖLGE" instead of "TEHLİKELİ BÖLGE" (`_to_upper()` now handles the
      dotted/dotless pair).
- [x] Regression: `tests/i18n_check.tscn` — every CSV key still exists in the source or
      the data files, the `%` conversions match between English and Turkish (a mismatch
      is a runtime crash, not a typo), every row actually resolves, and English still
      falls back to the key. `tests/shot.gd` takes a `lang=tr` argument for screenshots.
- [x] The Play Store listing's Turkish text is live — confirmed in the console on
      2026-08-21: **tr-TR is the default listing** (title, short and full description all
      Turkish, status *Canlı*) and en-US is the translation beside it. This entry was
      already stale when it was written down.

### Full test suite (2026-08-21)
- [x] **Sistem sistem test paketi + tek koşucu.** Altı yeni test yazıldı ve
      hepsi `tests/run_all.ps1` altında toplandı: **16 test, 2179 kontrol,
      hepsi geçiyor.** Yeniler: `economy_api_check` (game.gd'nin test edilmeyen
      17 genel fonksiyonu, sınır ve hatalı girdilerle), `data_check`
      (`data/*.json` şeması + çapraz referanslar + "verideki her `type` değerini
      kod gerçekten işliyor mu"), `sfx_check` (ses sentezi ve Android 11+
      çökmesinin regresyon kapanı), `migration_check` (kayıt göçünün her halkası,
      koruma, v11 yeniden yapılandırma), `ads_check` (reklam politikası),
      `iap_check` (Play Billing yanıtlarında consume/acknowledge ayrımı),
      `cloud_api_check` (CloudSave durum makinesi, ağa çıkmadan), `ui_check`
      (main.gd'nin her popup/sekme/modalı, iki dilde).
- [x] **Koşucu çıkış koduna güvenmiyor.** Çıktıda `SCRIPT ERROR`/`FAIL` arıyor,
      her testin kendi bitiş satırının basıldığını doğruluyor ve her teste zaman
      aşımı veriyor — `tutorial_check`'in sekiz gün boyunca 0 ile çıkarak bozuk
      kalması tam olarak bu üçünün yokluğundandı. Kendi kararını basmayan iki
      eski test (`store_compliance`, `unlink_check`) `PASS` değil **`REPORT`**
      olarak işaretleniyor.
- [x] **Paket üç gerçek hata buldu, üçü de düzeltildi:** (1) varsayılan otel adı
      18 karakterken `HOTEL_NAME_MAX_LEN` 16'ydı — yeniden adlandırma ekranı adı
      sessizce "Little Grand Hot"a kırpıyordu; (2) `cloud_state.json`'daki `uid`
      sayı olursa `_load_state()` çalışma zamanı hatasıyla yarıda ölüyordu;
      (3) oda `base` alanının tipi doğrulanmıyordu, bozuk bir kayıt
      `_load_from_dict`'in SONUNDA patlayıp atomikliği bozuyordu.
- [x] **Sertleştirme turu bitti: `fuzz_attack` artık SIFIR çalışma zamanı hatası
      basıyor** (önce 48). En büyük kalem tek bir değişiklikle kapandı:
      `room_def()` bilinmeyen tip için boş sözlük yerine `UNKNOWN_ROOM_DEF`
      döndürüyor — okuyucuların yarısı alanlara nokta ile eriştiği için
      (`room_def(r.type).category`) bozuk bir kayıt yirmi ayrı yerde
      patlıyordu. "Bu tip gerçekten var mı" sorusu artık `is_empty()` değil
      `has_room_type()`. Kalanlar: `shift_cost` tanımsız süre için 0 döner,
      `room_score`/satış fonksiyonları eşya kimliklerini tipe göre okur,
      satış fonksiyonları sınır kontrolü yapar ve `_validate_save_dict` artık
      kendi `id` okumasında patlamıyor — bozuk girdide çöken bir doğrulama
      kapısı, kapı görevini yapamıyordu.
- [x] **Yan bulgu: bir de bedava vardiya açığı vardı.** `shift_cost` tanımsız
      süre için 0 döndüğü an, bozuk bir kayıttaki `last_shift_hours = 999`
      bedava ve 999 saatlik bir vardiya başlatabilirdi. `start_shift` ve
      `_try_auto_renew` süreyi ayrıca doğruluyor, doğrulama kapısı da
      `last_shift_hours`'un tabloda tanımlı bir süre (ya da 0) olmasını şart
      koşuyor.
- [ ] **`store_compliance_check` ve `unlink_check`'e karar satırı ekle** — şu an
      yalnızca gözlem basıyorlar, yani başarısız OLAMIYORLAR.

### Tutorial test rewritten + Firebase verified live (2026-08-21)
- [x] **Firebase works end to end — checked against the real project, not mocked.**
      `tests/cloud_save_check.tscn` is deliberately network-free, so this was a live REST
      probe of all three services under project `little-grand-hotel`: anonymous `signUp`
      on Identity Toolkit (200, `sign_in_provider: anonymous`), `securetoken` refresh
      (200), and a full Firestore round trip on `saves/{uid}` — create rev 1, read back,
      update to rev 2, delete, then a 404 confirming the delete. The security rules were
      exercised too and both denials fired: writing **rev 1 over rev 2** returned
      `PERMISSION_DENIED` (the monotonic-counter guarantee holds server-side), and reading
      another uid's document returned `PERMISSION_DENIED`. The probe document and the
      throwaway anonymous user were both deleted afterwards — nothing left behind.

- [x] **`tests/tutorial_check.tscn` was silently broken and is now rewritten.** It had been
      dying since 2026-08-12 on `Invalid access to property '_tutorial_step'` — the
      spotlight work (`24cc37f`) renamed the field to `_tutorial_step_index` — while still
      **exiting 0**, so it looked green unless the output was read. A rename would not have
      been enough: the semantics moved with it. `_tutorial_step_index` is `-1` for *modal*
      steps and only set for *tap* steps, and the old test's "find the Button inside
      `tutorial_layer`" helper now finds the **Skip tutorial** button, i.e. it would have
      ended the tutorial instead of stepping through it.
- [x] The new test walks `TUTORIAL_STEPS` and branches on step type: modal steps are
      driven by pressing the modal's own action button (and its label is checked against
      the step's `btn`), tap steps assert the spotlight is up, the target control really
      exists, the ring sits on the target's rect + 6 px, the four dim strips are
      `MOUSE_FILTER_STOP`, and a *foreign* event does not advance the step — then fire the
      real one. It also covers "Skip tutorial" ending the whole sequence, and the second
      launch not showing it again. 58 assertions, exits 0 with no `SCRIPT ERROR`.
- [x] Two side defects fixed with it: the save is now restored in `_exit_tree` rather than
      in a straight line at the end (a mid-test death used to orphan the backup and leave
      the live save as whatever `new_game()` wrote), and a 45 s watchdog fails loudly
      instead of hanging when a runtime error kills the `_ready` coroutine. The Android
      back-button assertion was dropped on purpose: `_notification` calls
      `get_tree().quit()` when no popup is open, so the old test's own check would have
      ended the run — the comment in the file says why.

## To do

### Blockers — both now closed

- [x] **The Android 13+ crash was already fixed** — `09941a7` (2026-08-08), and this entry
      only existed because a note written five hours *before* that commit was never updated.
      Root cause: `Sfx.lobby_music()` set `loop_end` to the frame **count** (176400) when
      `loop_end` is an inclusive index, so the resampler's `pos + 1` interpolation read one
      sample past the end of a 352800-byte buffer every time the loop wrapped. Android 9
      (jemalloc) absorbed it; Android 11+ (Scudo) backs allocations of that size onto a
      guard page and turns it into `SIGSEGV`, 10–16 s after launch. The tombstones agreed
      exactly: `fault_addr - x22` came out 0x56220 = 352800 = the buffer size, in two
      separate crashes. Verified on both devices at the time (TECNO Spark 20 Pro / Android
      13, 180 s; Mi 9T / Android 9, 60 s). Nothing to reopen — the audio backtrace was the
      real story after all, and the `VkThread` variant was the same overflow corrupting a
      neighbouring allocation.

- [x] **Upload keystore password recovered** (2026-08-20) — release builds were blocked
      because the password for `android/upload-keystore.jks` was not written down anywhere
      after the keystore was regenerated on 2026-07-26. It was recovered from the transcript
      of the session that generated it, and verified two ways: `keytool` opens the keystore,
      and the `upload` alias certificate is
      `B1:00:9A:…:89:AF`, matching Play Console's upload certificate. A signed release AAB
      was then built end to end (62 MB, `build/android/little-grand-hotel.aab`) and its
      signer checked with `keytool -printcert -jarfile`. **No upload-key reset, and no new
      SHA-1 to register with Firebase.** The password is in
      `android/RELEASE_KEYSTORE_SECRETS.txt` (gitignored) — it belongs in a password manager,
      because one gitignored file is exactly how it went missing the first time.

### START HERE — durum devri (2026-08-21 kapanışı)

Repo temiz, `master` = `origin/master`, **paketin tamamı yeşil: 16 test,
2178 kontrol** (`pwsh tests/run_all.ps1`). Kodda bilinen açık iş yok.

**Sırada ne var — üçü de senin elinde, kod işi değil:**

1. **Play Console ▸ Yayın özeti → "2 değişikliği incelemeye gönder".** tr-TR ve
   en-US ekran görüntüleri yüklendi ve sıralandı ama kuyrukta bekliyor;
   basılmadan incelemeye gitmiyor.
2. **Üç elmas paketini oluştur** (`gems_small` / `gems_medium` / `gems_large`).
   Oyun içi elmas ekranı bunlarsız gerçek cihazda sessizce başarısız oluyor.
   Değerler ve **iki tuzak** (Türkçe konsolda `1.99` → USD 199,99; ürün kimliği
   kalıcı) `docs/store/in-app-products.md` başında.
3. **AdMob vergi formları** (TR + ABD) — ilk ödemeyi bloklar, bugün bir şeyi
   bloklamıyor. https://admob.google.com/v2/payments/settings

**Takvim:** kapalı test 14 günün 10'unu doldurdu → *Üretime başvur* ~2026-08-25.
Üretime çıkış aynı zamanda AdMob'daki "sınırlı reklam sunumu" kısıtını da
kaldırıyor (bkz. aşağıdaki reklam kontrolü).

**Kod tarafında sıradaki iş, isteğe bağlı:** `store_compliance_check` ve
`unlink_check`'e geçti/kaldı kararı eklemek — şu an yalnızca gözlem basıyorlar,
yani başarısız olamıyorlar (koşucu onları `REPORT` diye işaretliyor).

**Karar bekleyen:** tanıtım videosu (kriter netleşmeden yeni kurgu yok) ve
sekiz mağaza görselinden zayıf kalan dördünün (02, 06, 07, 08) daha dolu bir
oyun durumunda yeniden render edilmesi.

### Reklam kontrolü (2026-08-21)
- [x] **Reklamlarda düzeltilecek bir şey yok.** `ads_check` 67/67, ve panel elle
      teyit edildi: App ID + üç birim kimliği `ads.gd` ile birebir aynı, sıklık
      sınırları politikadaki gibi (App Open 1/saat, Interstitial 2/saat, ödüllü
      sınırsız), politika merkezi temiz. Google test kimliği kodda hiç yok.
- [x] **Ödüllünün panelde sınırsız olması "oyunda sınırsız" demek değil** —
      sınır oyunda: ×2 gelir bonusu aktifken buton hiç çizilmiyor (30 dakikada
      1) ve çevrimdışı ikiye katlama dönüş başına bir kez sunuluyor. Panele
      sınır koymak, oyuncu izledikten sonra ödülü boşa çıkarırdı. Stüdyo
      kuralı hâline getirildi: `pictures/ADS_POLICY.md` kural 10.
- [ ] **Sınırlı reklam sunumu — Play'de üretime çıkınca kalkacak.** Dört
      uygulamanın dördü de "İnceleme gerekli / Sınırlı reklam sunumu"
      durumunda, sebebi ceza değil: hiçbirine mağaza listesi bağlı değil. LGH'de
      son 7 günde 11 istek / 0 gösterim. Yapılacak bir şey yok, madde yalnızca
      "üretime çıkınca kontrol et" diye açık bırakıldı.

### Next session (agreed 2026-08-19)
- [~] **Play store listing page — screenshots uploaded 2026-08-21, not yet submitted.**
      Both locales now carry their own 1080x1920 set, in the intended 01→08 order:
      tr-TR (the default listing) got `docs/store-assets-originals/play-tr/`, en-US got
      `docs/store-assets-originals/play/`. Two things turned up while doing it. The two
      screenshots that were live were **596x1061** — under Play's 1080 px bar for
      promotion eligibility — and they were the July English pair, on a listing whose
      default language is Turkish. And en-US had **no set of its own**: it was inheriting
      the default listing's images, so English users would have seen Turkish caption
      bands. Both fixed.
      **The remaining step is the user's:** Play Console ▸ Yayın özeti still shows
      *"2 değişikliği incelemeye gönder"*. Saving only queues a change; nothing reaches
      review until that button is pressed. Left unpressed on purpose — it was a recorded
      decision that an upload sends the listing back through review.
      Also noted: the app is in **Kapalı test** with 12 testers, 10 of the required 14
      continuous days done, so *Üretime başvur* unlocks around 2026-08-25.
      One judgement call worth a second opinion: four of the eight shots (02 decorate,
      06 quests, 07 build/unlock, 08 empire) are popup screens that read as mostly-empty
      cream or dark panels at thumbnail size. They are honest screenshots, but they are
      the weak half of the set — worth re-rendering against a busier game state before
      the production listing goes out.
- [ ] **AdMob tax forms — checked 2026-08-21, still the user's to fill.** Verified on the
      right account (Yilk Games / yilkgamesstudio@gmail.com, pub-9709993577664180). The
      payment account is *AdSense (Türkiye)*, earnings ₺0.00 against a ₺200 threshold, and
      under AdMob ▸ Ödemeler ▸ Ayarları yönet **both** tax sections are blank:
      *Türkiye vergi bilgileri* and *Amerika Birleşik Devletleri vergi bilgileri*. Direct
      link: https://admob.google.com/v2/payments/settings. These take a tax identity (TR
      tax/ID number; a US W-8BEN with TIN and the treaty claim), so they can only be filled
      by the account holder — not something to hand off. Nothing is blocked by it today at
      ₺0 earnings; it blocks the first payout.
- [ ] **Promo video — deferred by decision (2026-08-20).** Two edits were rejected and
      the reasons were never written down (the `[[store-listing-and-media-state]]` link
      this entry used to point at does not exist), so a third blind edit would most likely
      be rejected as well. A Play listing publishes fine without a video. Picked back up
      after the store launch, and only with a stated criterion — tempo, which screens,
      music/captions. The raw material is ready either way: frames from
      `tests/showcase.tscn -- video`, and the current cut is
      `docs/store-assets-originals/demo.mp4` (1.9 MB, 2026-08-18).
- [x] **What the repo may carry is already settled** — CLAUDE.md's `docs/media/` exception
      answers it: the README set (`demo.gif` plus the 540x960 stills, a couple of MB) lives
      in the repo, and `demo.mp4`, the 1080x1920 originals, the feature graphic and the icon
      stay out, under `docs/store-assets-originals/` and the private pictures repo. Nothing
      to decide; the video question above is about the *edit*, not about where it lives.
- [~] **Refresh the GitHub repo itself** — description and topics were already in good
      shape; the repo **Website** field was empty and now points at the demo
      (https://eren-ozcan.github.io/LittleGrandHotel/). The release badge is deliberately
      not done: there is no tag or GitHub release at all, and a `v1.0.0` only means
      something once the game is actually on Play — decided 2026-08-20 to wait. The repo
      also carries no licence, which is the intended state for a commercial game: no
      licence means all rights reserved, whereas MIT/Apache would let anyone ship this
      code as their own game.
- [x] **Describe the playable demo in the README** (2026-08-20) — GitHub Pages turned out
      to be on already (`gh-pages`, root, status `built`) and
      https://eren-ozcan.github.io/LittleGrandHotel/ serves the game; verified with a
      request rather than assumed. The README now opens with a **Play in your browser**
      section and gained a **Web export** section describing why the preset is
      single-threaded and how the `gh-pages` branch is published. One claim was corrected
      while writing it: ads and IAP really are absent on the web (both gate on
      `OS.get_name() == "Android"`), but **cloud save is not** — `FirebaseConfig` has the
      API key compiled in and `is_enabled()` has no platform gate, so the public web demo
      signs in anonymously and writes to Firestore like any phone install. The README no
      longer implies otherwise. Whether to gate cloud save off behind the `demo` feature
      is an open question — see the entry in *Medium term*.

### Medium term
- [x] **The web demo no longer talks to Firebase** (2026-08-20) — `CloudSave.is_enabled()`
      was `FirebaseConfig.is_configured()` with no platform check, so every visitor to the
      public Pages build created an anonymous Firebase account and a Firestore document:
      unbounded write traffic from an unauthenticated public page, with the accounts piling
      up. It now also requires the build *not* to carry the `demo` feature. The Account
      panel says what is true for that build instead of offering a transfer path ("saved in
      this browser only, does not carry over to the phone version"), in both languages. The
      demo was re-exported and pushed to `gh-pages` (`650819c`), so the live page is the
      fixed one, not just the source tree.

- [x] **Manual save-transfer UI dropped** (2026-08-20) — the "Back up now" button and the
      whole "Move your save" card (show/copy the code, paste-and-import) are gone from
      Profile ▸ Account. Account linking covers the same job and has been proven across two
      real devices, and syncing is automatic, so the second path was redundant surface that
      could only confuse. `Game.export_save_code()` / `import_save_code()` stay in the model
      deliberately, now unreachable from the UI: `_load_from_dict()`'s validation is the real
      security surface and `tests/fuzz_attack.gd` exercises it through exactly those two
      functions — deleting them would blind the fuzzer, not tidy the code. 14 rows left
      `data/i18n/strings.csv`; `sim_check`, `cloud_save_check`, `i18n_check`, `unlink_check`
      and `fuzz_attack` all pass.
- [x] **Surface the Remove ads / Double your earnings offers** — both products live behind the Store popup's *Premium* tab, but the Store always opens on *Gems*, so most players never learned the offers existed. The Gems tab now ends with a one-line bridge row naming whichever products are still unowned, and the row disappears once both are bought (2026-08-18). Check the same promotion gap in cengeBulmaca and reefy.
- [x] **Add an unlink button and the logic behind it** — done 2026-08-18. Profile ▸ Account now has a "Disconnect account" row (soft red, two-tap confirm, same pattern as *Reset save*). It signs the Firebase session out without deleting anything server-side, keeps the local save exactly as it is, and resets `rev`/uid so the next sync starts a fresh document under a new anonymous account. Regression: `tests/unlink_check.tscn`.
- [ ] **Consider a native Credential Manager plugin — but there is no urgency, and the earlier entry here was wrong on both counts.** Re-researched 2026-08-08 against the primary docs:
  - **Correction 1: the loopback flow is not being removed from under us.** The deprecation applies to the **iOS, Android and Chrome-app** client types and it *finished in 2022* (new clients blocked 2022-03-14, all existing clients 2022-10-21). The [migration guide](https://developers.google.com/identity/protocols/oauth2/resources/loopback-migration) — last updated 2026-05-26 — still states verbatim that you need do nothing "if you are using the loopback IP address flow on a Desktop app OAuth client as usage with that OAuth client type will continue to be supported". Ours is a Desktop client. There is no announced sunset and no timeline to race.
  - What *is* real, and much softer: [OAuth 2.0 Policies](https://developers.google.com/identity/protocols/oauth2/policies) requires "a separate OAuth client for each platform" of "the client type that best matches the platform". Desktop-in-mobile is a type mismatch. The only example given is web-client-in-native-app, desktop-in-mobile is never named, and enforcement is discretionary ("Google can revoke or suspend access... for apps that misrepresent their identity"). Treat this as "could be caught by a future tightening", not "will break".
  - **Correction 2: the API 33+ claim was false.** `plugin/build.gradle.kts` declares **minSdk 24** — the README's "API 33+" is the SDK needed to *compile from source*, not a device requirement, and we would not compile anyway (a prebuilt `.aar` is committed). Google's own docs: Sign in with Google via Credential Manager "works on devices running Android 4.4 (API level 19) and higher". The Mi 9T (API 28) would **not** lose linking.
  - Candidate: [GodotGoogleSignIn](https://github.com/NiqueWrld/GodotGoogleSignIn) — MIT, 18 stars, **last push 2026-01-19** (stale), no tags, Kotlin package still named `com.niquewrld.casino.googlesignin`, compileSdk 34 against our targetSdk 36. Broader alternative: [GodotFirebaseAndroid](https://github.com/syntaxerror247/GodotFirebaseAndroid) (8 stars, last push 2026-02-13).
  - The dependency-risk objection is weaker than it looks: the whole plugin is one Kotlin file doing the standard Credential Manager → `GoogleIdTokenCredential` → `id_token` dance. Forking and maintaining it ourselves is realistic, and needs no Mac.
  - **The real cost is what it drags back in.** The plugin needs an Android OAuth client, a Web client *and* the signing SHA-1 — which means `google-services.json` returns, and so does the Play app-signing fingerprint trap ("fails only in store builds, silently") that `docs/cloud-save-setup.md` explains we designed *out*. It is also Android-only, so it forfeits the single-code-path property; iOS would need [godot-firebase-ios](https://github.com/SomniGameStudios/godot-firebase-ios) (mirrors GodotFirebaseAndroid's API, also does Sign in with Apple — but Godot 4.4+, iOS 17+, and **requires macOS/Xcode to build**).
  - **Verdict: do not migrate now.** The urgency was a misreading, the player-facing pain was already fixed (`afe359d`, foreground wait + retry), and `set_google_id_token_provider()` keeps the switch a one-call change whenever it is actually warranted. Revisit if Google announces an Android/iOS client requirement, or when the iOS port starts — at which point evaluate the Android+iOS plugin pair together rather than Android alone.
- [ ] **Consider Block Store for silent durability** — researched 2026-08-08, not started. [Block Store](https://developer.android.com/identity/block-store) stores up to 16 entries of 4 KB each and is built precisely for re-authenticating on a new device with no sign-in screen; the docs are explicit that "the user has already agreed to restore your app data as a part of the restore flow, so no additional consents are required". Storing the anonymous refresh token there would carry the identity across a reinstall *and* a device transfer with zero UI, and unlike the sign-in migration it needs **no console setup at all** — no SHA-1, no OAuth client, no consent screen, no `google-services.json`. Caveats: needs a native plugin, Android/GMS only, device-to-device transfer only fires during the factory-reset restore flow, and cloud restore targets need Android 12+ (Pixel 9+). Auto Backup (now enabled) already covers the reinstall case more broadly — it restores on *any* APK install — so Block Store is the fresher-but-narrower complement, not a prerequisite.
- [x] **Large-screen orientation warning (Play Console, seen 2026-08-18)** — Play flags `android:screenOrientation="PORTRAIT"` as a resizeability/orientation restriction. Decision (2026-08-18, with the user): **keep the portrait lock**. It is advisory, not a release blocker, and unlocking rotation would drag the top bar, popups and build mode through a landscape design pass for a phone-first idle game. What was fixed instead is the part that actually broke: when the canvas is narrower than the viewport the hotel used to stick to the left edge with the ground strips cut off at the building's width, which is what a tablet — or any Android 16 large screen, since those ignore the lock outright — would have shown. The canvas now centres and the pavement/road/grass run edge to edge. Re-checked 2026-08-19: the release manifest already carries `android:resizeableActivity="true"`, so nothing further can be turned off short of unlocking rotation. Closing this as accepted-by-decision; reopen only if Play turns the advisory into a policy requirement.
- [ ] Touch testing on a real Android device/emulator (so far only the headless export has been verified). The old "`adb` not found" note is stale — `adb` is at `%LOCALAPPDATA%\Android\Sdk\platform-tools` and the `lgh_test` AVD boots fine (used on 2026-08-21 for the backup/restore work). What blocks *touch* testing specifically is that the game renders black on the emulator (godot#121035, fixed in 4.8), so this wants a physical device
- [ ] A second building (a differently themed building after prestige) — currently limited to the single building + multiplier model, the economy/theme design needs to be settled first

### Long term
- [x] **Cross-device restore proven** (2026-08-08) — this entry claimed "nobody has ever signed in with a real Google account" long after that stopped being true; the Done section above ("Superseded 2026-08-08") records the OAuth Desktop client being created, linking run against a real account, and a save moved between two real devices. What is genuinely still open is narrower and lives there: whether Google demands a verification review before the consent screen can be published to all players. The Play Games / Game Center decision is unchanged — a platform-specific identity would break the "one player, one save on Android and iOS" model, argued at the top of `src/autoload/cloud_save.gd`.
- [ ] Visual variation for the weekly theme (not just color, but decor/asset changes)
