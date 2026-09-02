extends SceneTree
## Full-playthrough pacing simulation: new game -> fully maxed hotel.
## Drives a greedy but rational player policy and reports how many play
## sessions (shift-capped income blocks) each milestone takes, plus the
## session-to-session variance ("dalgalanma") in wait time between upgrades.
##
## Run:
##   tools\Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/progression_sim.gd

const SESSION_GAME_HOURS := 24.0  # one check-in = one 24h shift's worth of income (offline cap)

var GameScript
var decorate_as_you_go := 0
var spend_log := {}      # category -> total coins spent
var blocked_goal := ""   # what the player is currently saving for
var blocked_cost := 0


func _initialize() -> void:
	GameScript = load("res://src/autoload/game.gd")
	print("Little Grand Hotel - full progression pacing sim")
	print("=" .repeat(64))

	# A single deterministic playthrough, then a sensitivity sweep on how many
	# real-world days it maps to depending on check-in frequency.
	var res := simulate_playthrough(true, {})

	_beat_analysis(res)
	_money_analysis(res)

	# Same economy, different player: decorates while building instead of
	# leaving the tower bare until the end. Separates "the bot under-decorates"
	# from "the star formula punishes expansion".
	print("")
	print("=".repeat(64))
	print("ALTERNATIVE PLAYERS: decorate while building, to a target tier")
	for tgt in [1, 2, 3]:
		var r2 := simulate_playthrough(false, {"decorate_as_you_go": tgt})
		print("")
		print("  target tier %d (%s): %d sessions  (bare-tower player: %d)" % [
			tgt, ["Basic", "Cozy", "Chic", "Luxe", "Iconic"][tgt], r2.sessions, res.sessions])
		_star_timeline(r2.log)

	_prestige_analysis(res)

	# Tuning sweep: how the single grind wall responds to floor_mult.
	print("")
	print("TUNING SWEEP - building.floor_mult")
	print("%10s %10s %12s %14s" % ["floor_mult", "sessions", "worst gap", "floor 8 price"])
	print("-".repeat(50))
	for fm in [2.2, 2.0, 1.9, 1.8, 1.7, 1.6]:
		var r := simulate_playthrough(false, {"floor_mult": fm})
		var worst := 0
		for m in r.milestones:
			worst = maxi(worst, int(m.gap))
		var f8 := int(15000.0 * pow(fm, 5))
		print("%10.1f %10d %12d %14d" % [fm, r.sessions, worst, f8])
	print("")
	print("TUNING SWEEP - xp_curve.exp (mid-game level pace)")
	print("%10s %10s %12s %16s" % ["xp exp", "sessions", "worst gap", "worst milestone"])
	print("-".repeat(54))
	for xe in [1.9, 1.85, 1.8, 1.75, 1.7, 1.65]:
		var r := simulate_playthrough(false, {"xp_exp": xe})
		var worst := 0
		var wname := ""
		for m in r.milestones:
			if int(m.gap) > worst:
				worst = int(m.gap)
				wname = String(m.name)
		print("%10.2f %10d %12d %16s" % [xe, r.sessions, worst, wname.substr(0, 16)])

	print("")
	print("TUNING SWEEP - xp_curve_early.blend_levels (how far the seam is spread)")
	print("%8s %10s %12s %12s %14s %12s" % ["blend", "sessions", "worst level",
		"its cost", "step ratio", "silent run"])
	print("-".repeat(74))
	for bl in [0, 2, 3, 4, 6, 8]:
		var rb := simulate_playthrough(false, {"blend_levels": bl})
		print("%8d %10d %12d %12d %14s %12d" % [bl, rb.sessions,
			rb.worst_level, rb.worst_level_cost, "x%.2f" % rb.worst_level_ratio,
			rb.silent_run])

	print("")
	print("Sessions to fully max out: %d" % res.sessions)
	print("")
	print("Real-world calendar time, by how often the player checks in:")
	for per_day in [2, 3, 5, 8]:
		var days := float(res.sessions) / float(per_day)
		print("  %d check-ins/day  ->  %5.1f days  (~%.1f weeks)" % [per_day, days, days / 7.0])
	print("")
	print("NOTE: income per session is hard-capped at 24 game-hours (offline")
	print("cap + 24h shift length), so extra check-ins beyond ~1/day mostly")
	print("just add more capped blocks; they do not raise the per-block yield.")

	quit(0)


## Where the money goes, and what the player spends sessions waiting for.
## This is the input for any price tuning: a category that eats most of the
## coins, or a single item the player banks many sessions for, is the price
## that is actually setting the pace.
func _money_analysis(run1: Dictionary) -> void:
	print("")
	print("WHERE THE MONEY GOES")
	var spend: Dictionary = run1.spend
	var total := 0
	for k in spend:
		total += int(spend[k])
	var rows := []
	for k in spend:
		rows.append([k, int(spend[k])])
	rows.sort_custom(func(a, b): return a[1] > b[1])
	print("%-16s %14s %10s" % ["category", "coins", "share"])
	print("-".repeat(44))
	for r in rows:
		print("%-16s %14d %9.0f%%" % [r[0], r[1], 100.0 * float(r[1]) / maxf(1.0, float(total))])
	print("%-16s %14d" % ["TOTAL", total])

	# What was the player banking for, and for how long?
	var waits := {}     # goal -> sessions spent saving
	var cost_of := {}
	for e in run1.log:
		var b := String(e.get("blocked", ""))
		if b == "":
			continue
		waits[b] = int(waits.get(b, 0)) + 1
		cost_of[b] = int(e.get("blocked_cost", 0))
	var wrows := []
	for k in waits:
		wrows.append([k, int(waits[k]), int(cost_of[k])])
	wrows.sort_custom(func(a, b): return a[1] > b[1])
	print("")
	print("LONGEST SAVE-UPS - sessions spent banking, by goal")
	print("%-16s %12s %14s" % ["saving for", "sessions", "price"])
	print("-".repeat(44))
	for r in wrows.slice(0, 8):
		print("%-16s %12d %14d" % [r[0], r[1], r[2]])


## How many sessions the player spends on each star rating.
func _star_timeline(log: Array) -> void:
	print("")
	print("STAR RATING TIMELINE - the player's headline 'how good is my hotel'")
	print("%8s %8s %10s" % ["star", "from", "sessions"])
	print("-".repeat(30))
	var cur := -1
	var since := 1
	for e in log:
		if int(e.star) != cur:
			if cur >= 0:
				print("%8d %8d %10d" % [cur, since, int(e.s) - since])
			cur = int(e.star)
			since = int(e.s)
	print("%8d %8d %10d%s" % [cur, since, int(log[log.size() - 1].s) - since + 1, "  <- final"])


## How often SOMETHING happens. A milestone table hides the smaller beats
## (level-ups, quests, achievements, star changes) that actually carry the
## first week, so count them per session and find the quiet stretches.
func _beat_analysis(run1: Dictionary) -> void:
	var log: Array = run1.log
	_star_timeline(log)

	# Beats per session: a level-up, a quest completion, an achievement or a
	# star change all count as "something visibly happened this session".
	print("")
	print("BEAT DENSITY - visible events per session")
	print("%16s %10s %12s %14s" % ["window", "sessions", "beats", "beats/session"])
	print("-".repeat(56))
	var prev := {"lvl": 1, "quests": 0, "achievements": 0, "star": 2}
	var beats := []
	for e in log:
		var n := 0
		n += maxi(0, int(e.lvl) - int(prev.lvl))
		n += maxi(0, int(e.quests) - int(prev.quests))
		n += maxi(0, int(e.achievements) - int(prev.achievements))
		n += absi(int(e.star) - int(prev.star))
		beats.append(n)
		prev = {"lvl": e.lvl, "quests": e.quests, "achievements": e.achievements, "star": e.star}
	var windows := [[1, 7, "D1-D3 (2/day)"], [8, 14, "D4-D7"], [15, 30, "week 2-3"],
		[31, 50, "week 3-5"], [51, beats.size(), "endgame"]]
	for w in windows:
		var lo: int = int(w[0])
		var hi: int = mini(int(w[1]), beats.size())
		if lo > hi:
			continue
		var total := 0
		for i in range(lo - 1, hi):
			total += int(beats[i])
		print("%16s %10s %12d %14.2f" % [w[2], "%d-%d" % [lo, hi], total,
			float(total) / float(hi - lo + 1)])

	# Longest run of consecutive sessions with zero beats.
	var worst := 0
	var runlen := 0
	var worst_at := 0
	for i in beats.size():
		if int(beats[i]) == 0:
			runlen += 1
			if runlen > worst:
				worst = runlen
				worst_at = i + 2 - runlen
		else:
			runlen = 0
	print("")
	print("  longest silent stretch: %d sessions (from session %d)" % [worst, worst_at])

	_level_pacing(log)


## Sessions spent per level. The milestone table only samples a few levels, so
## a single-level cliff in the XP curve hides inside a multi-level "gap". This
## breaks it down and prints the XP cost of each level next to it, so a jump in
## wait time can be attributed to the curve rather than to prices.
func _level_pacing(log: Array) -> void:
	var g = GameScript.new()
	g.eco = g.load_json("res://data/economy.json")
	print("")
	print("LEVEL PACING - sessions spent on each level, and its XP cost")
	print("%7s %10s %12s %12s %10s" % ["level", "reached", "sessions", "xp cost", "vs prev"])
	print("-".repeat(56))
	var prev_lvl := 1
	var since := 0
	for e in log:
		var lvl := int(e.lvl)
		if lvl == prev_lvl:
			continue
		for l in range(prev_lvl, lvl):
			var cost: int = g.xp_for_level(l + 1) - g.xp_for_level(l)
			var prev_cost: int = g.xp_for_level(l) - g.xp_for_level(maxi(1, l - 1))
			var ratio := float(cost) / maxf(1.0, float(prev_cost))
			print("%7d %10d %12d %12d %10s" % [l, since, int(e.s) - since, cost,
				"x%.2f" % ratio if l > 1 else "-"])
		since = int(e.s)
		prev_lvl = lvl
	g.free()


## The prestige sawtooth: how many points a run of a given length awards, and
## how much a head start of N points shortens the NEXT run. A healthy reset
## loop makes each run shorter and each run's payout comparable.
func _prestige_analysis(run1: Dictionary) -> void:
	var g = GameScript.new()
	g.eco = g.load_json("res://data/economy.json")
	print("")
	print("PRESTIGE PAYOUT - points a run awards, by when you reset")
	print("%10s %14s %10s %12s" % ["session", "collected", "points", "multiplier"])
	print("-".repeat(50))
	for e in run1.log:
		if int(e.s) % 10 != 0 and int(e.s) != int(run1.log[run1.log.size() - 1].s):
			continue
		var pts: int = g.prestige_points_for(int(e.collected))
		print("%10d %14d %10d %12s" % [e.s, int(e.collected), pts,
			"x%.2f" % (1.0 + float(g.eco.prestige.mult_per_point) * pts)])
	g.free()

	print("")
	print("PRESTIGE SPEEDUP - sessions to fully max out, with a head start")
	print("%8s %12s %10s %10s" % ["points", "multiplier", "sessions", "vs run 1"])
	print("-".repeat(46))
	for pts in [0, 5, 10, 15, 20, 30]:
		var r := simulate_playthrough(false, {"prestige_points": pts})
		var pct := 100.0 * (1.0 - float(r.sessions) / float(run1.sessions))
		print("%8d %12s %10d %9.0f%%" % [pts,
			"x%.2f" % (1.0 + 0.1 * pts), r.sessions, pct])


## Returns { sessions, milestones: [{name, session, gap}] , log: [...] }
func simulate_playthrough(verbose: bool, overrides: Dictionary) -> Dictionary:
	var g = GameScript.new()
	g.eco = g.load_json("res://data/economy.json")
	g.quests = g.load_json("res://data/quests.json").get("quests", [])
	g.achievements = g.load_json("res://data/achievements.json").get("achievements", [])
	if overrides.has("floor_mult"):
		g.eco.building["floor_mult"] = float(overrides.floor_mult)
	if overrides.has("xp_exp"):
		g.eco.xp_curve["exp"] = float(overrides.xp_exp)
	if overrides.has("seam_level"):
		g.eco.xp_curve_early["seam_level"] = int(overrides.seam_level)
	if overrides.has("blend_levels"):
		g.eco.xp_curve_early["blend_levels"] = int(overrides.blend_levels)
	g.new_game()
	decorate_as_you_go = int(overrides.get("decorate_as_you_go", 0))
	spend_log = {}
	if overrides.has("prestige_points"):
		g.prestige_points = int(overrides.prestige_points)  # head start from a previous run
	g.time_scale = 1.0
	g.auto_renew_hours_left = 0.0  # manual restart each session; keeps blocks clean at 24h each

	var milestones := []
	var last_ms_session := 0
	var recorded := {}

	var facility_types := ["cafe", "gym", "pool", "cinema", "spa", "restaurant", "roof_garden"]
	var guest_types := ["standard", "deluxe", "suite"]

	var session := 0
	var max_sessions := 6000
	var log := []

	while session < max_sessions:
		session += 1

		# --- production: one shift-capped block ---------------------------
		g.shift_end_unix = 0.0
		g.start_shift(24)  # deducts shift cost; sim still proceeds if it fails
		g.last_sim_unix = g.now() - SESSION_GAME_HOURS * 3600.0
		g.simulate_to(g.now())
		g.collect()

		# --- spend: greedy priority loop --------------------------------
		blocked_goal = ""
		blocked_cost = 0
		spend_round(g, facility_types, guest_types)

		# --- milestone checks -----------------------------------------
		var checks := {
			"Housekeeping bought": func(): return _has_room(g, "housekeeping"),
			"Level 8 (Deluxe unlocked)": func(): return g.level() >= 8,
			"3 stars": func(): return g.star_rating() >= 3,
			"Level 12 (Pool unlocked)": func(): return g.level() >= 12,
			"Level 18 (Suite unlocked)": func(): return g.level() >= 18,
			"Level 20 (Prestige unlocked)": func(): return g.level() >= 20,
			"Level 28 (Roof Garden unlocked)": func(): return g.level() >= 28,
			"All 8 floors built": func(): return g.floors >= 8,
			"All 64 blocks open": func(): return g.max_slots() >= 64,
			"Building full": func(): return _blocks_used(g) >= g.max_slots() and g.max_slots() >= 64,
			"Facility diversity 5": func(): return g.facility_diversity() >= 5,
			"4 stars": func(): return g.star_rating() >= 4,
			"5 stars": func(): return g.star_rating() >= 5,
			"Staff tier maxed (8)": func(): return g.staff_tier >= 8,
			"Every guest room Iconic": func(): return _all_guest_iconic(g),
		}
		for name in checks:
			if not recorded.has(name) and checks[name].call():
				recorded[name] = true
				milestones.append({
					"name": name, "session": session, "gap": session - last_ms_session,
					"income": g.hourly_income(), "coins": g.coins, "level": g.level(),
				})
				last_ms_session = session

		log.append({"s": session, "inc": g.hourly_income(), "coins": g.coins,
			"lvl": g.level(), "star": g.star_rating(), "rooms": g.rooms.size(),
			"floors": g.floors, "slots": g.max_slots(),
			"collected": g.stat_collected_total,
			"quests": g.quest_index, "achievements": g.unlocked_achievements.size(),
			"blocked": blocked_goal, "blocked_cost": blocked_cost})

		if _endgame(g):
			break

	if verbose:
		_print_report(g, milestones, log, session)

	var slowest := _slowest_level(g, log)
	var out := {"sessions": session, "milestones": milestones, "log": log,
		"spend": spend_log.duplicate(), "silent_run": _silent_run(log)}
	out.merge(slowest)
	g.free()
	return out


## The single level the player sits on longest, with that level's XP price and
## how many times steeper it is than the level before it. A wall that lands on
## one level is invisible in the milestone table, so summarise it per run.
func _slowest_level(g, log: Array) -> Dictionary:
	var since := 0
	var prev_lvl := 1
	var worst := 0
	var worst_lvl := 1
	for e in log:
		var lvl := int(e.lvl)
		if lvl == prev_lvl:
			continue
		var each := int(e.s) - since
		for l in range(prev_lvl, lvl):
			if each > worst:
				worst = each
				worst_lvl = l
		since = int(e.s)
		prev_lvl = lvl
	var cost: int = g.xp_for_level(worst_lvl + 1) - g.xp_for_level(worst_lvl)
	var prev_cost: int = g.xp_for_level(worst_lvl) - g.xp_for_level(maxi(1, worst_lvl - 1))
	return {"worst_level": worst_lvl, "worst_level_sessions": worst,
		"worst_level_cost": cost,
		"worst_level_ratio": float(cost) / maxf(1.0, float(prev_cost))}


## Longest run of consecutive sessions in which nothing visible happened.
func _silent_run(log: Array) -> int:
	var prev := {"lvl": 1, "quests": 0, "achievements": 0, "star": 2}
	var worst := 0
	var runlen := 0
	for e in log:
		var n := 0
		n += maxi(0, int(e.lvl) - int(prev.lvl))
		n += maxi(0, int(e.quests) - int(prev.quests))
		n += maxi(0, int(e.achievements) - int(prev.achievements))
		n += absi(int(e.star) - int(prev.star))
		prev = {"lvl": e.lvl, "quests": e.quests, "achievements": e.achievements, "star": e.star}
		if n == 0:
			runlen += 1
			worst = maxi(worst, runlen)
		else:
			runlen = 0
	return worst


## One spending pass with a phased, save-toward-next-goal policy.
##  Phase 1 (build-out): only structural buys (housekeeping, facilities,
##    guest rooms, blocks, floors, staff). If the cheapest useful structural
##    buy is unaffordable, bank the coins - do NOT fritter them on decor.
##  Phase 2 (structure done): pour everything into decor toward Iconic.
func spend_round(g, facility_types: Array, guest_types: Array) -> void:
	var safety := 0
	while safety < 400:
		safety += 1
		if _try_structural_buy(g, facility_types, guest_types):
			continue
		# structural buy either done for this session or being saved for
		break

	if _structure_complete(g, facility_types):
		var dsafety := 0
		while dsafety < 400 and _decorate_one(g):
			dsafety += 1
	elif decorate_as_you_go > 0:
		# Alternative player: keeps every room at a target tier while building,
		# instead of leaving the whole tower bare until the end. Tests whether
		# the long star-3 plateau is a bot artifact or the star formula itself.
		var dsafety := 0
		while dsafety < 200 and _decorate_below_tier(g, decorate_as_you_go):
			dsafety += 1


## One structural purchase, by priority (not by price). Returns true if
## something was bought; false when nothing is actionable OR the current
## priority goal is merely unaffordable (caller then banks coins toward it).
func _try_structural_buy(g, facility_types: Array, guest_types: Array) -> bool:
	# 1) Housekeeping.
	if g.level() >= 1 and not _has_room(g, "housekeeping") and _slot_exists(g, "housekeeping"):
		return _buy(g, "housekeeping", int(g.room_def("housekeeping").price),
			func(): return g.buy_room("housekeeping"), "housekeeping")

	# 2) Every unlocked facility we don't own yet and can place -- bought as
	#    soon as affordable, ahead of guest rooms/blocks (diversity + income).
	for t in facility_types:
		if not _has_room(g, t) and g.level() >= int(g.room_def(t).unlock_level) and _slot_exists(g, t):
			return _buy(g, t, int(g.room_def(t).price), func(): return g.buy_room(t), "facility")

	# 3) Staff quality to max tier -- low priority: only when comfortably
	#    affordable (never bank a dozen sessions for one tier), and only
	#    after the tower is fully built out.
	if g.staff_tier < int(g.eco.staff_upgrade.max_tier) and _structure_built(g, facility_types):
		var sc: int = g.staff_upgrade_cost()
		if g.coins - sc * 2 >= _reserve(g):
			if g.buy_staff_upgrade():
				spend_log["staff"] = int(spend_log.get("staff", 0)) + sc
				return true

	# 4) Expansion + guest fill: pick the cheapest of {block on a full floor,
	#    new floor, best guest room that fits}. Once the tower is at full
	#    height, ring-fence blocks for facilities not yet unlocked/owned.
	var cands := []
	for fi in range(1, g.floors + 1):
		if g.can_buy_block(fi) and _floor_is_full(g, fi):
			cands.append({"cost": g.block_price(fi), "kind": "block", "arg": fi})
	if g.floors < 8 and _floor_has_any(g, g.floors):
		cands.append({"cost": g.floor_price(), "kind": "floor", "arg": 0})

	var reserved := 0
	if g.floors >= 8:
		for t in facility_types:
			if not _has_room(g, t):
				reserved += int(g.room_def(t).get("footprint_w", 1))
	var pick := ""
	var pick_w := 1
	for t in guest_types:
		if g.level() >= int(g.room_def(t).unlock_level) and _slot_exists(g, t):
			pick = t
			pick_w = int(g.room_def(t).get("footprint_w", 1))
	if pick != "" and _blocks_used(g) + pick_w <= g.max_slots() - reserved:
		cands.append({"cost": int(g.room_def(pick).price), "kind": "room", "arg": pick})

	if cands.is_empty():
		return false
	cands.sort_custom(func(a, b): return a.cost < b.cost)
	var c = cands[0]
	match c.kind:
		"room":  return _buy(g, String(c.arg), int(c.cost), func(): return g.buy_room(c.arg), "guest room")
		"block": return _buy(g, "block", int(c.cost), func(): return g.buy_block(c.arg), "block")
		"floor": return _buy(g, "floor %d" % (g.floors + 1), int(c.cost), func(): return g.buy_floor(), "floor")
	return false


## Buys if affordable, otherwise records what the player is now saving for.
## Every purchase is tallied by category so the report can show where the
## money actually goes -- the input any price tuning needs.
func _buy(g, label: String, cost: int, do_buy: Callable, category: String) -> bool:
	if not _afford(g, cost):
		blocked_goal = label
		blocked_cost = cost
		return false
	if do_buy.call():
		spend_log[category] = int(spend_log.get(category, 0)) + cost
		return true
	return false


func _slot_exists(g, type: String) -> bool:
	return g._find_open_slot(type) != Vector2i(-1, -1)


## Tower fully built: 8 floors, all blocks open and filled, every facility
## owned. Does NOT require staff maxed (that is a parallel low-prio track).
func _structure_built(g, facility_types: Array) -> bool:
	if g.floors < 8 or g.max_slots() < 64 or _blocks_used(g) < g.max_slots():
		return false
	for t in facility_types:
		if not _has_room(g, t):
			return false
	return true

func _structure_complete(g, facility_types: Array) -> bool:
	return _structure_built(g, facility_types) and g.staff_tier >= int(g.eco.staff_upgrade.max_tier)


# --- decorating -------------------------------------------------------

## Like _decorate_one, but stops as soon as every guest room has reached
## `tier` -- the "keep the hotel presentable while building" policy.
func _decorate_below_tier(g, tier: int) -> bool:
	var any := false
	for r in g.rooms:
		if g.room_def(r.type).category == "guest" and g.room_tier(r) < tier:
			any = true
			break
	if not any:
		return false
	return _decorate_one(g)


func _decorate_one(g) -> bool:
	# pick the guest room with the lowest score that is not yet Iconic
	var target := -1
	var low := 1 << 30
	for i in g.rooms.size():
		var r = g.rooms[i]
		if g.room_def(r.type).category != "guest":
			continue
		if g.room_tier(r) >= 4:
			continue
		var sc : int = g.room_score(r)
		if sc < low:
			low = sc
			target = i
	if target < 0:
		return false
	var r = g.rooms[target]

	# upgrade bed to the best affordable unlocked bed
	var beds := [["bed_canopy", 19], ["bed_wood", 6]]
	for b in beds:
		var it = g.item_def(b[0])
		if g.level() >= int(it.unlock_level) and String(r["base"].get("bed", "")) != b[0] and _afford(g, int(it.price)):
			# only take it if it is actually an upgrade
			var cur = g.item_def(String(r["base"].get("bed", "bed_basic")))
			if int(it.sp) > int(cur.get("sp", 0)):
				r["base"]["bed"] = b[0]
				g.coins -= int(it.price)
				spend_log["decor"] = int(spend_log.get("decor", 0)) + int(it.price)
				return true

	# add the most valuable affordable decor item not already in the room
	var best_item := ""
	var best_sp := -1
	for it in g.eco.items:
		if it.has("slot"):
			continue  # bed/wallpaper/floor handled via base
		var iid := String(it.id)
		if g.room_has_item(target, iid):
			continue
		if g.level() < int(it.unlock_level):
			continue
		var price := int(it.get("price", 0))
		if price <= 0:
			continue  # skip gem-only premium items in this sim
		if not _afford(g, price):
			continue
		if int(it.sp) > best_sp:
			best_sp = int(it.sp)
			best_item = iid
	if best_item != "":
		if g.buy_item(target, best_item):
			spend_log["decor"] = int(spend_log.get("decor", 0)) + int(g.item_def(best_item).price)
			return true
	return false


# --- helpers ---------------------------------------------------------

func _reserve(g) -> int:
	# A rational player keeps a few 24h shifts' worth of cash, not just the
	# bare 1h-shift reserve the engine enforces -- otherwise a big buy can
	# drop them below the next shift cost and stall all income.
	return g.min_shift_reserve() + g.shift_cost(24) * 3

func _afford(g, cost: int) -> bool:
	return g.coins - cost >= _reserve(g)

func _has_room(g, type: String) -> bool:
	for r in g.rooms:
		if r.type == type:
			return true
	return false

func _blocks_used(g) -> int:
	var n := 0
	for r in g.rooms:
		n += int(r.w)
	return n

func _floor_is_full(g, fi: int) -> bool:
	var used := 0
	for r in g.rooms:
		if int(r.floor) == fi:
			used += int(r.w)
	return used >= g.floor_open_width(fi)

func _floor_has_any(g, fi: int) -> bool:
	for r in g.rooms:
		if int(r.floor) == fi:
			return true
	return false

func _all_guest_iconic(g) -> bool:
	var any := false
	for r in g.rooms:
		if g.room_def(r.type).category == "guest":
			any = true
			if g.room_tier(r) < 4:
				return false
	return any

func _endgame(g) -> bool:
	return g.floors >= 8 \
		and g.max_slots() >= 64 \
		and _blocks_used(g) >= g.max_slots() \
		and g.staff_tier >= 8 \
		and g.star_rating() >= 5 \
		and _all_guest_iconic(g)


func _print_report(g, milestones: Array, log: Array, sessions: int) -> void:
	print("")
	print("MILESTONE TIMELINE (session = one 24h income block)")
	print("%-34s %8s %6s %12s %10s" % ["milestone", "session", "+gap", "income/h", "coins"])
	print("-".repeat(74))
	for m in milestones:
		print("%-34s %8d %6d %12.0f %10d" % [m.name, m.session, m.gap, m.income, m.coins])

	print("")
	print("INCOME CURVE (every ~1/12 of the run)")
	print("%8s %6s %6s %6s %8s %12s" % ["session", "level", "star", "rooms", "floors", "income/h"])
	print("-".repeat(56))
	var step := maxi(1, log.size() / 12)
	var i := 0
	while i < log.size():
		var e = log[i]
		print("%8d %6d %6d %6d %8d %12.0f" % [e.s, e.lvl, e.star, e.rooms, e.floors, e.inc])
		i += step
	var last = log[log.size() - 1]
	print("%8d %6d %6d %6d %8d %12.0f  <- final" % [last.s, last.lvl, last.star, last.rooms, last.floors, last.inc])

	# variance of the milestone gaps = the "dalgalanma"
	var gaps := []
	for m in milestones:
		gaps.append(m.gap)
	var mean := 0.0
	for x in gaps:
		mean += x
	mean /= maxf(1.0, gaps.size())
	var vsum := 0.0
	for x in gaps:
		vsum += (x - mean) * (x - mean)
	var sd := sqrt(vsum / maxf(1.0, gaps.size()))
	var mx := 0
	var mn := 1 << 30
	for x in gaps:
		mx = maxi(mx, x)
		mn = mini(mn, x)
	gaps.sort()
	var median : float = gaps[gaps.size() / 2] if gaps.size() > 0 else 0.0
	print("")
	print("PACING VARIANCE (sessions between consecutive milestones)")
	print("  mean %.1f   median %.0f   stddev %.1f   min %d   max %d" % [mean, median, sd, mn, mx])
	print("  -> most milestones are ~%d sessions apart; the one %d-session gap" % [median, mx])
	print("     is the single grind wall (see timeline).")
