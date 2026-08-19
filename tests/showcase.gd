extends Node
## Marketing capture tool: renders the game into an offscreen 1080x1920
## viewport and writes either a set of still screenshots or a numbered frame
## sequence for a video.
##
## The window is only a host — the real render target is the SubViewport, so
## captures are full phone resolution even though the desktop window is small
## (a 1080x1920 window gets clamped by the desktop and produced 1080x1061).
##
## Run (stills):  tools\Godot_v4.7-stable_win64_console.exe --path . res://tests/showcase.tscn -- shots
## Run (frames):  ... res://tests/showcase.tscn -- video
## Localised:     ... res://tests/showcase.tscn -- shots lang=tr
## Output: user://media/*.png
##
## The developer's save is never touched: the showcase hotel is built in memory.

const OUT_DIR := "user://media"
const SHOT_W := 1080
const SHOT_H := 1920

## The hotel shown in the material: full but believable, not the maxed-out
## developer save (999M coins reads as a cheat screenshot, not a game).
const LAYOUT := [
	[["housekeeping", 0], ["cafe", 1], ["gym", 2], ["restaurant", 3], ["standard", 6], ["standard", 7]],
	[["pool", 0], ["cinema", 2], ["spa", 4], ["roof_garden", 6]],
	[["deluxe", 0], ["deluxe", 2], ["suite", 4], ["suite", 6]],
	[["suite", 0], ["suite", 2], ["suite", 4], ["suite", 6]],
	[["deluxe", 0], ["deluxe", 2], ["deluxe", 4], ["deluxe", 6]],
	[["suite", 0], ["suite", 2], ["suite", 4], ["suite", 6]],
]
const SHOWCASE_COINS := 1_284_600
const SHOWCASE_GEMS := 486
const SHOWCASE_LEVEL := 24

var _view: SubViewport
var _main: Node
var _frame := 0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_build_showcase_state()
	# "lang=tr" forces the UI language so a localised screenshot set can be
	# rendered from the same showcase hotel. It is applied after the state is
	# built because new_game() resets Game back to its defaults.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("lang="):
			var g := get_node("/root/Game")
			g.language = arg.substr(5)
			g.apply_language()
	_view = SubViewport.new()
	_view.size = Vector2i(SHOT_W, SHOT_H)
	_view.transparent_bg = false
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_view)
	_main = load("res://main.tscn").instantiate()
	_view.add_child(_main)
	_main._finish_loading_screen()
	# The loading screen fades out over several frames; capturing earlier left a
	# ghost of its logo across the first shot.
	await _settle(30)
	if "video" in OS.get_cmdline_user_args():
		await _record_video()
	else:
		await _capture_stills()
	get_tree().quit()


## Fills Game with the showcase hotel. Nothing is saved to disk — Game is an
## autoload the running scene reads from, and the process exits after capture.
func _build_showcase_state() -> void:
	var g := get_node("/root/Game")
	var for_video := "video" in OS.get_cmdline_user_args()
	g.new_game()
	# The clip has to show the hotel GROWING, so it starts smaller and with an
	# undecorated room; the stills want the finished hotel instead.
	var layout: Array = LAYOUT.slice(0, 3) if for_video else LAYOUT
	g.floors = layout.size() + 1 if for_video else layout.size()
	g.floor_blocks = []
	for _i in g.floors:
		g.floor_blocks.append(int(g.eco.building.grid_cols))
	var decor: Array = []
	for it in g.eco.items:
		if it.has("anchor"):
			decor.append(String(it.id))
	g.rooms = []
	var first_guest := true
	for floor_i in range(1, layout.size() + 1):
		for entry in layout[floor_i - 1]:
			var room: Dictionary = g.make_room(String(entry[0]), floor_i, int(entry[1]))
			if String(g.room_def(room.type).get("category", "")) == "guest":
				if first_guest and not for_video:
					# The room screenshot needs items left to BUY: a fully
					# decorated room renders as a page of greyed-out "owned"
					# rows, which sells nothing.
					first_guest = false
					room["items"] = decor.slice(0, 3)
				else:
					room["items"] = decor.duplicate()
					room["base"]["bed"] = "bed_canopy"
			g.rooms.append(room)
	if for_video:
		# The room the camera pushes into starts bare so it can fill on camera.
		for r in g.rooms:
			if String(g.room_def(r.type).get("category", "")) == "guest":
				r["items"] = []
				break
	else:
		# Leave the top floor half empty: with every block used the Build screen
		# greys out all room tiles ("blocks used: 48/48") and shows nothing to buy.
		g.rooms.resize(g.rooms.size() - 2)
	g.xp = g.xp_for_level(SHOWCASE_LEVEL)
	g.staff_tier = 2
	g.tutorial_seen = true
	g.quest_index = 6
	g.unlocked_achievements = []
	for a in g.achievements.slice(0, 5):
		g.unlocked_achievements.append(String(a.id))
	g.stat_shifts = 84
	g.stat_collects = 91
	g.stat_collected_total = 2_450_000
	g.stat_cleans = 37
	# A live 24h shift so the hotel is busy and the timer is ticking.
	g.last_shift_hours = 24
	g.last_sim_unix = g.now()
	g.shift_end_unix = g.now() + 24.0 * 3600.0 / g.time_scale
	g.auto_renew_hours_left = 48.0
	g.pending_income = 18_400.0
	# Offline/daily popups must not cover the shots.
	g.offline_earned = 0
	g.auto_renew_count = 0
	g.auto_renew_spent = 0
	g.daily_streak = 3
	g.last_daily_claim_day = g.daily_day_index()
	g.coins = SHOWCASE_COINS
	g.gems = SHOWCASE_GEMS


## Ilk misafir odasinin indeksi — dekor ekranini bos bir tesis yerine
## gercekten dekore edilmis bir odayla yakalamak icin.
func _first_guest_room() -> int:
	var g := get_node("/root/Game")
	for i in g.rooms.size():
		if String(g.room_def(g.rooms[i].type).get("category", "")) == "guest":
			return i
	return 0


func _settle(frames: int) -> void:
	for _i in frames:
		await get_tree().process_frame


func _save(name: String) -> void:
	await _settle(2)
	var img := _view.get_texture().get_image()
	img.save_png("%s/%s.png" % [OUT_DIR, name])
	print("SAVED ", name)


func _shot_of_popup(title: String, builder: Callable, name: String) -> void:
	_main._open_popup(title, builder)
	await _settle(4)
	await _save(name)
	_main._close_popup()
	await _settle(3)


func _capture_stills() -> void:
	_main._update_live_labels()
	await _save("01_hotel")

	# Zoomed out: the whole building in one frame — the "what is this game" shot.
	_main._zoom_by(-10.0, _main.zoom_viewport.size / 2.0)
	await _save("02_full_building")
	_main._zoom = _main._default_zoom()
	_main._clamp_pan()
	_main._apply_canvas_transform()
	await _settle(3)

	_main.selected_room = _first_guest_room()
	await _shot_of_popup("Room Decoration", _main._build_room_popup, "03_room")
	await _shot_of_popup("Build", _main._build_build_popup, "04_build")
	_main._quests_tab = "quests"
	await _shot_of_popup("Quests", _main._build_quests_popup, "05_quests")
	# "Statistics" is not a title the game ever shows: the stats live under the
	# Profile popup, and a made-up title also has no translation, so it stayed
	# English in the localised set.
	await _shot_of_popup("Profile", _main._build_stats_popup, "06_stats")
	_main._store_tab = "premium"
	await _shot_of_popup("Store", _main._build_store_popup, "07_store")
	_main._store_tab = "gems"

	# Offline earnings modal — the "it kept earning while you were gone" promise.
	get_node("/root/Game").offline_seconds = 7.0 * 3600.0 + 900.0
	_main._show_offline_popup(46_800, 3, 5_400)
	await _settle(4)
	await _save("08_offline")
	await _settle(2)
	for child in get_tree().root.get_children():
		if child != self and child is CanvasLayer:
			child.queue_free()
	_main._close_popup()
	await _settle(3)

	# A dirty room, so the cleaning loop has a screenshot of its own.
	var g := get_node("/root/Game")
	var idx := _first_guest_room()
	g.rooms[idx].dirty = true
	_main.selected_room = idx
	await _shot_of_popup("Room Decoration", _main._build_room_popup, "09_dirty")


## The promo clip. Every beat has to CHANGE something on screen — the first cut was
## a slow zoom over static menus, which reads as a slideshow, not a game. So the room
## fills item by item, the building grows floor by floor and the coins actually land.
func _record_video() -> void:
	var g := get_node("/root/Game")
	var room_i := _first_guest_room()

	# 1. Hook: the hotel, and money landing in the first second.
	g.pending_income = 32_400.0
	_main._update_live_labels()
	await _run_frames(18)
	_main._on_collect()
	await _run_frames(34)

	# 2. Decorate: push in on one room and let it fill up, one piece at a time.
	await _glide(26, 0.85)
	var decor: Array = []
	for it in g.eco.items:
		if it.has("anchor"):
			decor.append(String(it.id))
	for item_id in decor:
		if g.room_has_item(room_i, item_id):
			continue
		g.buy_item(room_i, item_id)
		await _run_frames(7)
	await _run_frames(14)

	# 3. Build: new rooms appear on the empty blocks.
	await _glide(20, -0.55)
	var spots := [[4, 0], [4, 2], [4, 4], [4, 6]]
	for spot in spots:
		g.place_room("suite", int(spot[0]), int(spot[1]))
		g.state_changed.emit()
		await _run_frames(11)

	# 4. Grow: a whole new floor opens up.
	g.coins = 5_000_000
	g.buy_floor()
	await _run_frames(10)
	for col in [0, 2, 4, 6]:
		g.place_room("deluxe", g.floors, col)
		g.state_changed.emit()
		await _run_frames(9)

	# 5. Pull back to the finished hotel and let it breathe.
	await _glide(34, -1.1)
	g.pending_income = 58_900.0
	_main._update_live_labels()
	await _run_frames(16)
	_main._on_collect()
	await _run_frames(46)
	print("FRAMES ", _frame)


## Zoom spread over the frames so the camera move is smooth in the video.
func _glide(count: int, total_delta: float) -> void:
	var per := total_delta / float(count)
	for _i in count:
		_main._zoom_by(per, _main.zoom_viewport.size / 2.0)
		await _write_frame()


func _run_frames(count: int) -> void:
	for _i in count:
		await _write_frame()


func _write_frame() -> void:
	await get_tree().process_frame
	var img := _view.get_texture().get_image()
	img.save_png("%s/frame_%04d.png" % [OUT_DIR, _frame])
	_frame += 1
