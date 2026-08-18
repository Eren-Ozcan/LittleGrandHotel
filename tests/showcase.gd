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
	g.new_game()
	g.floors = LAYOUT.size()
	g.floor_blocks = []
	for _i in g.floors:
		g.floor_blocks.append(int(g.eco.building.grid_cols))
	var decor: Array = []
	for it in g.eco.items:
		if it.has("anchor"):
			decor.append(String(it.id))
	g.rooms = []
	var first_guest := true
	for floor_i in range(1, g.floors + 1):
		for entry in LAYOUT[floor_i - 1]:
			var room: Dictionary = g.make_room(String(entry[0]), floor_i, int(entry[1]))
			if String(g.room_def(room.type).get("category", "")) == "guest":
				if first_guest:
					# The room screenshot needs items left to BUY: a fully
					# decorated room renders as a page of greyed-out "owned"
					# rows, which sells nothing.
					first_guest = false
					room["items"] = decor.slice(0, 3)
				else:
					room["items"] = decor.duplicate()
					room["base"]["bed"] = "bed_canopy"
			g.rooms.append(room)
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
	await _shot_of_popup("Room", _main._build_room_popup, "03_room")
	await _shot_of_popup("Build", _main._build_build_popup, "04_build")
	_main._quests_tab = "quests"
	await _shot_of_popup("Quests", _main._build_quests_popup, "05_quests")
	await _shot_of_popup("Statistics", _main._build_stats_popup, "06_stats")
	_main._store_tab = "premium"
	await _shot_of_popup("Store", _main._build_store_popup, "07_store")
	_main._store_tab = "gems"


## A short scripted tour, one PNG per frame. ffmpeg turns it into mp4/gif.
func _record_video() -> void:
	var plan := [
		[45, "idle"],
		[35, "zoom_out"],
		[30, "idle"],
		[35, "zoom_in"],
		[20, "idle"],
		[45, "open_room"],
		[25, "close"],
		[45, "open_build"],
		[25, "close"],
		[45, "open_quests"],
		[25, "close"],
		[40, "collect"],
		[30, "idle"],
	]
	for step in plan:
		var count: int = int(step[0])
		var action: String = String(step[1])
		match action:
			"zoom_out":
				await _glide(count, -0.9)
				continue
			"zoom_in":
				await _glide(count, 0.9)
				continue
			"open_room":
				_main.selected_room = _first_guest_room()
				_main._open_popup("Room", _main._build_room_popup)
			"open_build":
				_main._open_popup("Build", _main._build_build_popup)
			"open_quests":
				_main._quests_tab = "quests"
				_main._open_popup("Quests", _main._build_quests_popup)
			"close":
				_main._close_popup()
			"collect":
				get_node("/root/Game").pending_income = 24_800.0
				_main._on_collect()
		await _run_frames(count)
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
