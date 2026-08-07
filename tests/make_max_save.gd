extends SceneTree
## Developer tool: writes a fully maxed-out save to user://save.json.
## Every floor and block bought, all room types placed, all guest rooms
## decorated to the top tier, max staff tier, all quests/achievements done.
##
## Run:
##   tools\Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/make_max_save.gd

## Layout per floor (8 blocks each): [type, col] — every block is used.
const LAYOUT := [
	# Floor 1: service + small facilities + the two starter rooms
	[["housekeeping", 0], ["cafe", 1], ["gym", 2], ["restaurant", 3], ["standard", 6], ["standard", 7]],
	# Floor 2: the wide facilities
	[["pool", 0], ["cinema", 2], ["spa", 4], ["roof_garden", 6]],
	# Floor 3: deluxe pair + first suites
	[["deluxe", 0], ["deluxe", 2], ["suite", 4], ["suite", 6]],
	# Floors 4-8: suites only (highest income per block)
	[["suite", 0], ["suite", 2], ["suite", 4], ["suite", 6]],
	[["suite", 0], ["suite", 2], ["suite", 4], ["suite", 6]],
	[["suite", 0], ["suite", 2], ["suite", 4], ["suite", 6]],
	[["suite", 0], ["suite", 2], ["suite", 4], ["suite", 6]],
	[["suite", 0], ["suite", 2], ["suite", 4], ["suite", 6]],
]

const MAX_COINS := 999_999_999
const MAX_GEMS := 999_999
const TARGET_LEVEL := 100
const PRESTIGE_LEVEL := 10


func _initialize() -> void:
	var GameScript := load("res://src/autoload/game.gd")
	var g = GameScript.new()
	g.eco = g.load_json("res://data/economy.json")
	g.quests = g.load_json("res://data/quests.json").get("quests", [])
	g.achievements = g.load_json("res://data/achievements.json").get("achievements", [])

	# Keep the player's personal settings (hotel name, sound) from the old save.
	var kept_name := "Little Grand Hotel"
	var kept_sound := true
	var kept_music := true
	if g.load_game():
		kept_name = g.hotel_name
		kept_sound = g.sound_on
		kept_music = g.music_on

	g.new_game()

	# --- Building: every floor, every block ------------------------------
	g.floors = int(g.eco.building.max_floors)
	g.floor_blocks = []
	for _i in g.floors:
		g.floor_blocks.append(int(g.eco.building.grid_cols))

	# --- Rooms: full layout, guest rooms decorated to the top tier -------
	var decor: Array = []
	for it in g.eco.items:
		if it.has("anchor"):
			decor.append(String(it.id))
	g.rooms = []
	for floor_i in range(1, g.floors + 1):
		for entry in LAYOUT[floor_i - 1]:
			var room: Dictionary = g.make_room(String(entry[0]), floor_i, int(entry[1]))
			if String(g.room_def(room.type).get("category", "")) == "guest":
				room["items"] = decor.duplicate()
				room["base"]["bed"] = "bed_canopy"
			g.rooms.append(room)

	# --- Progression -----------------------------------------------------
	g.xp = g.xp_for_level(TARGET_LEVEL)
	g.prestige_level = PRESTIGE_LEVEL
	g.staff_tier = int(g.eco.staff_upgrade.max_tier)
	g.remove_ads = true
	g.permanent_income_mult = 2.0
	g.tutorial_seen = true
	g.hotel_name = kept_name
	g.sound_on = kept_sound
	g.music_on = kept_music

	# All quests handed in, all achievements unlocked.
	g.quest_index = g.quests.size()
	g.unlocked_achievements = []
	for a in g.achievements:
		g.unlocked_achievements.append(String(a.id))

	# Lifetime stats consistent with the achievements above.
	g.stat_shifts = 500
	g.stat_collects = 500
	g.stat_collected_total = 5_000_000
	g.stat_cleans = 300

	# Daily streak parked at day 6 so the next claim lands on the day-7 reward.
	g.daily_streak = 6
	g.last_daily_claim_day = g.daily_day_index() - 1
	g.poke_day = -1
	g.poke_count = 0

	# --- Live state: a 24h shift running, plenty of auto-renew, 2x boost --
	g.auto_renew_hours_left = 999.0
	g.last_shift_hours = 24
	g.last_sim_unix = g.now()
	g.shift_end_unix = g.now() + 24.0 * 3600.0 / g.time_scale
	g.boost_mult = 2.0
	g.boost_end_unix = g.now() + 3600.0
	g.pending_income = 0.0

	# Currency last — nothing above can spend it.
	g.coins = MAX_COINS
	g.gems = MAX_GEMS

	g.save_game()

	# --- Report + round-trip check ---------------------------------------
	print("Maxed save written to: ", ProjectSettings.globalize_path("user://save.json"))
	print("  hotel        : %s" % g.hotel_name)
	print("  level        : %d (xp %d)" % [g.level(), g.xp])
	print("  coins/gems   : %d / %d" % [g.coins, g.gems])
	print("  floors/blocks: %d floors, %d blocks" % [g.floors, g.max_slots()])
	print("  rooms        : %d (%d guest)" % [g.rooms.size(), g.guest_rooms().size()])
	print("  star rating  : %d" % g.star_rating())
	print("  hourly income: %.0f coins/h" % g.hourly_income())
	print("  staff tier   : %d / %d" % [g.staff_tier, int(g.eco.staff_upgrade.max_tier)])
	print("  prestige     : %d (x%.1f)" % [g.prestige_level, g.prestige_mult()])

	var verify = GameScript.new()
	verify.eco = g.eco
	verify.quests = g.quests
	verify.achievements = g.achievements
	if verify.load_game():
		print("Round-trip load: OK (%d rooms, %d coins)" % [verify.rooms.size(), verify.coins])
	else:
		printerr("Round-trip load: FAILED — save rejected by validation")
	quit()
