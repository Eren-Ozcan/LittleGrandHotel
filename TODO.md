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
- [ ] **What the user needs to do themselves**: a Play Console account (~$25),
      an AdMob account + a real App ID/rewarded ad unit ID (Google test IDs are
      currently in use, they must be changed in `ads.gd`), defining the
      `remove_ads`/`income_2x` in-app products in Play Console, Play App Signing
      enrollment, the privacy policy + store listing content.

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
- Not done, and deliberately not ticked: the OAuth Desktop app client does not exist yet,
      so **no part of the sign-in flow has ever run against a real Google account** and
      cross-device restore is still unproven on this game. Account linking stays a
      disabled "coming soon" button until someone creates that client. Also open: whether
      Google requires a verification review before the consent screen can be published for
      all players.

## To do

### Medium term
- [ ] Touch testing on a real Android device/emulator (so far only the headless export has been verified) — no device/emulator was connected in this session (`adb` not found), manual testing is required
- [ ] A second building (a differently themed building after prestige) — currently limited to the single building + multiplier model, the economy/theme design needs to be settled first

### Long term
- [ ] **Prove cross-device restore end to end** — cloud save and Google account linking are implemented (see Done, 2026-08-07), but nobody has ever signed in with a real Google account or moved a save between two devices, because the OAuth Desktop app client has not been created yet (`docs/cloud-save-setup.md` step 7). Until that is done the shareable save code remains the only transfer path known to work. Play Games / Game Center are *not* wanted here: they hand out a platform-specific identity and would break the "one player, one save on Android and iOS" model — that decision is argued out at the top of `src/autoload/cloud_save.gd` and should not be reopened casually.
- [ ] Visual variation for the weekly theme (not just color, but decor/asset changes)
