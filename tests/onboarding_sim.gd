extends SceneTree
## First-session measurement: the first 30 real minutes, at 1-second resolution.
##
## The progression sim works in 24-game-hour blocks, which is far too coarse to
## say anything about D1 retention -- that is decided in the first few minutes.
## This runs the real foreground clock (time_scale 60: 1 real minute = 1 game
## hour) with rooms getting dirty and needing taps, and reports what the player
## actually experiences minute by minute.
##
## Run:
##   tools\Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/onboarding_sim.gd

const MINUTES := 30
const SECONDS := MINUTES * 60
const CLEAN_REACTION := 8.0   # player notices and taps a dirty room within ~8s
const COLLECT_THRESHOLD := 60 # player taps the coin pile once this much has piled up

var GameScript


func _initialize() -> void:
	GameScript = load("res://src/autoload/game.gd")
	print("Little Grand Hotel - first-session (30 min) measurement")
	print("=".repeat(72))
	print("time_scale 60: 1 real minute = 1 game hour. Rooms go dirty after")
	print("stay_hours game-hours, i.e. a Standard room every %d real minutes." % 2)

	var engaged := run_session(true, {})
	var passive := run_session(false, {})

	print("")
	print("=".repeat(72))
	print("COMPARISON")
	print("%-34s %14s %14s" % ["", "engaged", "passive"])
	print("-".repeat(66))
	print("%-34s %14d %14d" % ["coins earned in 30 min", engaged.earned, passive.earned])
	print("%-34s %14d %14d" % ["level reached", engaged.level, passive.level])
	print("%-34s %14d %14d" % ["taps required", engaged.taps, passive.taps])
	print("%-34s %14s %14s" % ["income at 30 min",
		"%.0f/h" % engaged.income, "%.0f/h" % passive.income])
	print("%-34s %14s %14s" % ["longest dead stretch",
		_mmss(engaged.dead), _mmss(passive.dead)])
	var ratio := float(engaged.earned) / maxf(1.0, float(passive.earned))
	print("")
	print("Playing actively is worth x%.2f over letting it run untouched." % ratio)
	print("(Low ratio = idling is fine, tapping is optional. High ratio = the")
	print(" first session punishes anyone who puts the phone down.)")

	# --- what would fix the passive cliff? -----------------------------
	print("")
	print("=".repeat(72))
	print("FIX SWEEP - passive player's 30 minutes under different settings")
	print("%-40s %12s %12s" % ["variant", "coins", "income/h"])
	print("-".repeat(66))
	var variants := [
		["baseline (stay_hours 2, no housekeeping)", {}],
		["stay_hours 3 (the pre-change value)", {"stay_hours": 3.0}],
		["stay_hours 6", {"stay_hours": 6.0}],
		["stay_hours 12", {"stay_hours": 12.0}],
		["Housekeeping owned from the start", {"free_housekeeping": true}],
	]
	for v in variants:
		var r := run_session(false, v[1], true)
		print("%-40s %12d %12.0f" % [v[0], r.earned, r.income])
	print("")
	print("Reference: the engaged player earned %d coins in the same 30 minutes." % engaged.earned)

	quit(0)


## active=true -> player cleans rooms and reinvests; false -> starts the shift
## and never touches the screen again until the end.
func run_session(active: bool, opts: Dictionary, quiet: bool = false) -> Dictionary:
	var g = GameScript.new()
	g.eco = g.load_json("res://data/economy.json")
	g.quests = g.load_json("res://data/quests.json").get("quests", [])
	g.achievements = g.load_json("res://data/achievements.json").get("achievements", [])
	if opts.has("stay_hours"):
		for t in ["standard", "deluxe", "suite"]:
			g.eco.room_types[t]["stay_hours"] = float(opts.stay_hours)
	g.new_game()
	g.time_scale = 60.0  # the real shipping value
	if bool(opts.get("free_housekeeping", false)):
		g.rooms.append(g.make_room("housekeeping", 1, 2))

	# Virtual clock: the engine's now() is the wall clock, so we drive
	# simulate_to() with our own timeline and correct shift_end_unix to match.
	# Actions like buy_room()/clean_room() call simulate_to(now()) internally,
	# which is a harmless no-op here because our clock is always ahead of it.
	var t0: float = g.now()
	g.last_sim_unix = t0
	g.start_shift(24)
	g.shift_end_unix = t0 + 24.0 * 3600.0 / g.time_scale

	var events := []
	var taps := 1  # the tap that started the shift
	var level_before : int = g.level()
	var dirty_since := {}   # room index -> virtual time it went dirty
	var last_event_t := 0.0
	var dead := 0.0
	var earned := 0
	var samples := []

	if not quiet:
		print("")
		print("-".repeat(72))
		print("SCENARIO: %s" % ("engaged player (cleans + reinvests)" if active else "passive player (never taps)"))
		print("-".repeat(72))

	for i in range(1, SECONDS + 1):
		var t := float(i)
		g.simulate_to(t0 + t)

		# --- dirty room bookkeeping --------------------------------------
		for ri in g.rooms.size():
			var r = g.rooms[ri]
			if g.room_def(r.type).category != "guest":
				continue
			if bool(r.dirty):
				if not dirty_since.has(ri):
					dirty_since[ri] = t
					if events.size() < 40:
						events.append([t, "room %d went dirty (income stops)" % ri])
			else:
				dirty_since.erase(ri)

		if not active:
			continue

		# --- clean after the reaction delay -------------------------------
		for ri in dirty_since.keys():
			if t - float(dirty_since[ri]) >= CLEAN_REACTION:
				if g.clean_room(ri):
					taps += 1
					dirty_since.erase(ri)
					if events.size() < 40:
						events.append([t, "cleaned room %d" % ri])

		# --- collect once enough has piled up ------------------------------
		if int(g.pending_income) >= COLLECT_THRESHOLD:
			var got: int = g.collect()
			if got > 0:
				earned += got
				taps += 1
				if g.level() > level_before:
					events.append([t, "LEVEL UP -> %d (+%d gems)" % [g.level(), int(g.eco.levelup_gems)]])
					level_before = g.level()
					last_event_t = t
				# --- reinvest ---------------------------------------------
				var bought := _spend(g)
				if bought != "":
					taps += 1
					events.append([t, "bought %s" % bought])
					last_event_t = t

		dead = maxf(dead, t - last_event_t)

		if i % 300 == 0:  # every 5 minutes
			samples.append({"t": t, "coins": g.coins, "inc": g.hourly_income(),
				"lvl": g.level(), "rooms": g.rooms.size(), "taps": taps})

	# passive player collects once at the end
	if not active:
		earned = g.collect()
		taps += 1
		samples.append({"t": float(SECONDS), "coins": g.coins, "inc": g.hourly_income(),
			"lvl": g.level(), "rooms": g.rooms.size(), "taps": taps})
		dead = float(SECONDS)

	if not quiet:
		print("%8s %10s %12s %8s %8s %8s" % ["time", "coins", "income/h", "level", "rooms", "taps"])
		for s in samples:
			print("%8s %10d %12.0f %8d %8d %8d" % [_mmss(s.t), s.coins, s.inc, s.lvl, s.rooms, s.taps])
		if not events.is_empty():
			print("")
			print("  event log (first %d):" % events.size())
			for e in events:
				print("    %s  %s" % [_mmss(e[0]), e[1]])

	var res := {
		"earned": earned, "level": g.level(), "taps": taps,
		"income": g.hourly_income(), "dead": dead,
	}
	g.free()
	return res


## Cheapest useful reinvestment a new player would actually make.
func _spend(g) -> String:
	var reserve: int = g.min_shift_reserve() + g.shift_cost(24)

	# Housekeeping ends the cleaning chore -- the single best early buy.
	if g.level() >= 2 and not _has(g, "housekeeping"):
		if g.coins - int(g.room_def("housekeeping").price) >= reserve:
			if g.buy_room("housekeeping"):
				return "Housekeeping (no more cleaning taps)"

	# Another guest room while there is space.
	if g.coins - int(g.room_def("standard").price) >= reserve and g._find_open_slot("standard").x >= 0:
		if g.buy_room("standard"):
			return "Standard Room"

	# Otherwise decorate the weakest room one notch.
	var target := -1
	var low := 1 << 30
	for i in g.rooms.size():
		if g.room_def(g.rooms[i].type).category != "guest":
			continue
		var sc: int = g.room_score(g.rooms[i])
		if sc < low:
			low = sc
			target = i
	if target < 0:
		return ""
	var best := ""
	var best_sp := -1
	for it in g.eco.items:
		if not it.has("anchor") or int(it.get("gem_price", 0)) > 0:
			continue
		if g.level() < int(it.unlock_level) or g.room_has_item(target, String(it.id)):
			continue
		if g.coins - int(it.price) < reserve:
			continue
		if int(it.sp) > best_sp:
			best_sp = int(it.sp)
			best = String(it.id)
	if best != "" and g.buy_item(target, best):
		return "%s (room %d -> %s)" % [String(g.item_def(best).name), target,
			g.tier_name(g.room_tier(g.rooms[target]))]
	return ""


func _has(g, type: String) -> bool:
	for r in g.rooms:
		if r.type == type:
			return true
	return false


func _mmss(seconds: float) -> String:
	var s := int(seconds)
	return "%d:%02d" % [s / 60, s % 60]
