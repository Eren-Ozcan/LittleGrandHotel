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
## Ses işaretleri: hangi karede hangi efekt duyulmalı. Yakalama gerçek zamanlı
## değil (her kare diske PNG yazılıyor), yani sesi kaydederek yakalamak mümkün
## değil — bunun yerine olayın kare numarası yazılıyor ve ses, kurgu bittikten
## sonra scripts/make_promo_video.py içinde tam o saniyeye yerleştiriliyor.
var _cues: Array = []


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	# Before anything touches Game: the showcase hotel must never reach the
	# cloud, and the "which save should continue?" modal must never reach a
	# screenshot. CloudSave's opening sync is deferred, so this lands first.
	var cloud := get_node_or_null("/root/CloudSave")
	if cloud:
		cloud.disable_for_capture()
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
	if for_video:
		# No Housekeeping room in the clip: it cleans dirty rooms by itself, and it
		# swept the cleaning beat's room clean during the camera move every time,
		# so clean_room() found nothing to do and the beat silently vanished.
		var floor1: Array = []
		for entry in layout[0]:
			if String(entry[0]) != "housekeeping":
				floor1.append(entry)
		layout = [floor1, layout[1], layout[2]]
	# Two empty floors for the clip, not one: the growth beats fill them one after
	# the other, which means buy_floor() is never called and the canvas never
	# changes height. That matters — see the comment on beat 6.
	g.floors = layout.size() + 2 if for_video else layout.size()
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
		g.rooms[_video_room()]["items"] = []
	else:
		# Leave the top floor half empty: with every block used the Build screen
		# greys out all room tiles ("blocks used: 48/48") and shows nothing to buy.
		g.rooms.resize(g.rooms.size() - 2)
	g.xp = g.xp_for_level(SHOWCASE_LEVEL)
	g.staff_tier = 2
	g.tutorial_seen = true
	g.quest_index = 6
	g.stat_shifts = 84
	g.stat_collects = 91
	g.stat_collected_total = 2_450_000
	g.stat_cleans = 37
	# Shift history, or the Profile screen contradicts itself: it counted 84
	# shifts started and then said "no shift has been started yet", and the
	# empty table left the lower half of the screenshot blank.
	g.shift_history = []
	var day := 86400.0
	var at: float = g.now() - 11.0 * day
	for hours in [8, 24, 4, 24, 8, 24, 1, 8, 24, 4, 8, 24]:
		g.shift_history.append({
			"hours": hours,
			"cost": g.shift_cost(int(hours)),
			"at": at,
		})
		at += day * 0.9
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
	# Unlocked last, once the stats and the hotel it reads are in place: with a
	# fixed "first five in the file" list the Achievements screen showed rows
	# reading "20 / 20" and "5 / 5" that were still greyed out as locked.
	g.unlocked_achievements = []
	for a in g.achievements:
		var p: Array = g.quest_progress(a)
		if int(p[0]) >= int(p[1]):
			g.unlocked_achievements.append(String(a.id))


## The room the clip pushes into. Not simply the first guest room: that one sits
## in the bottom-right corner, and at close-up zoom `_clamp_pan()` refuses to
## scroll past the canvas edge, so the camera stopped short of it every time.
## Prefers a middle column and a high floor, both of which the camera can centre.
func _video_room() -> int:
	var g := get_node("/root/Game")
	var mid: float = float(int(g.eco.building.grid_cols)) * 0.5
	var best := 0
	var best_score := INF
	for i in g.rooms.size():
		var r: Dictionary = g.rooms[i]
		if String(g.room_def(r.type).get("category", "")) != "guest":
			continue
		var score: float = absf(float(int(r.col)) + 0.5 - mid) - float(int(r.floor)) * 2.0
		if score < best_score:
			best_score = score
			best = i
	return best


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

	# Zoomed in on the lower floors, where the pool, cinema, spa and the rest of
	# the facilities are. Without this the facilities screenshot was 01 over
	# again with a different caption: zoom-out is clamped to the fit level and
	# the default view is only two ticks above it, so "whole building" and
	# "default view" render as near-identical frames.
	_main._zoom = _main._default_zoom() + 0.35
	_main._canvas_pan.y = -1_000_000.0     # _clamp_pan() pulls it back to the ground
	_main._clamp_pan()
	_main._apply_canvas_transform()
	await _settle(3)
	await _save("11_facilities")

	_main._zoom = _main._default_zoom()
	_main._clamp_pan()
	_main._apply_canvas_transform()
	await _settle(3)

	_main.selected_room = _first_guest_room()
	await _shot_of_popup("Room Decoration", _main._build_room_popup, "03_room")
	await _shot_of_popup("Build", _main._build_build_popup, "04_build")
	_main._quests_tab = "quests"
	await _shot_of_popup("Quests", _main._build_quests_popup, "05_quests")
	# The Quests tab is only a hero card plus four "next up" rows, so it fills
	# less than half a phone screen. The Achievements tab of the same popup —
	# tab bar and all — is thirteen cards tall and carries the store shot.
	_main._quests_tab = "achievements"
	await _shot_of_popup("Quests", _main._build_quests_popup, "10_achievements")
	_main._quests_tab = "quests"
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
	var room_i := _video_room()

	# 1. Hook: the hotel, and money landing in the first second. Framed close
	# enough that the building fills the shot — at the default zoom a four-floor
	# hotel sits at the bottom of the frame with the top half empty sky.
	_cut_to(_main.ZOOM_MAX, _building_center())
	g.pending_income = 32_400.0
	_main._update_live_labels()
	await _run_frames(26)
	_main._on_collect()
	_cue("collect")
	await _run_frames(44)

	# 2. Decorate: push in ON THE ROOM and let it fill up, one piece at a time.
	await _glide_to(30, 3.0, _room_center(room_i), 3.0)
	await _run_frames(10)
	var decor: Array = []
	for it in g.eco.items:
		if it.has("anchor"):
			decor.append(String(it.id))
	for item_id in decor:
		if g.room_has_item(room_i, item_id):
			continue
		g.buy_item(room_i, item_id)
		_cue("buy")
		await _run_frames(10)
	await _run_frames(24)

	# 3. Clean: a room goes dirty and gets swept. The cleaning loop is half of
	# what the player actually does minute to minute, and the clip never showed
	# it — it went straight from decorating to building.
	var dirty_i := _second_guest_room(room_i)
	await _glide_to(20, 2.6, _room_center(dirty_i), 2.6)
	g.rooms[dirty_i]["dirty"] = true
	g.rooms[dirty_i]["dirty_hours"] = 1.0
	g.state_changed.emit()
	await _run_frames(30)
	var sweep_at := _screen_pos(_room_center(dirty_i))
	if g.clean_room(dirty_i):
		_cue("clean")
		_main._spawn_clean_anim(sweep_at)
		_main._show_toast("Room cleaned (+2 XP)")
	await _run_frames(58)

	# 4. Build: pull out to the empty floor and fill it, room by room. The camera
	# rides up to that floor instead of just widening.
	var empty_floor: int = g.floors
	var floor_point := Vector2(
		_main.building_canvas.custom_minimum_size.x * 0.5,
		float(g.floors - empty_floor) * _main.CELL_H + _main.CELL_H * 0.5)
	await _glide_to(26, _main.ZOOM_MAX, floor_point)
	var spots := [[empty_floor, 0], [empty_floor, 2], [empty_floor, 4], [empty_floor, 6]]
	for spot in spots:
		g.place_room("suite", int(spot[0]), int(spot[1]))
		g.state_changed.emit()
		_cue("buy")
		await _run_frames(15)
	await _run_frames(16)

	# 5. A quest lands — the reward toast is the game telling the player why any
	# of this mattered, and it costs six frames of screen time.
	var quest: Dictionary = g.current_quest()
	if not quest.is_empty():
		_main._on_quest_completed(quest)
		_cue("quest")
		await _run_frames(62)

	# 6. Grow: the top floor fills up too, and the hotel is finished.
	#
	# This beat used to buy a floor. It cannot: buy_floor() grows the canvas by one
	# CELL_H, every row is renumbered (row_y counts DOWN from the top), and the
	# whole hotel — ground strip included — jumps ~160 px up in a single frame.
	# That cannot be cancelled from out here. _rebuild_hotel() ends in _clamp_pan(),
	# Game emits state_changed on nearly every frame, and the re-clamp lands between
	# the last chance to set the pan and the frame being drawn: measured at frame
	# 515→516, the grass moved 1351 → 1196 with the correction in place. So the clip
	# starts with the extra floor already there and simply fills it.
	for col in [0, 2, 4, 6]:
		g.place_room("deluxe", g.floors, col)
		g.state_changed.emit()
		_cue("buy")
		await _run_frames(13)
	await _run_frames(16)

	# 7. Pull back to the finished hotel and let it breathe.
	await _glide_to(44, _main.ZOOM_MAX, _building_center())
	await _run_frames(18)
	g.pending_income = 58_900.0
	_main._update_live_labels()
	await _run_frames(22)
	_main._on_collect()
	_cue("collect")
	await _run_frames(64)
	print("FRAMES ", _frame)
	_export_audio()


## The room the cleaning beat uses — not the one the camera just decorated, so
## the two beats do not play out on the same tile.
func _second_guest_room(skip: int) -> int:
	var g := get_node("/root/Game")
	for i in g.rooms.size():
		if i == skip:
			continue
		if String(g.room_def(g.rooms[i].type).get("category", "")) == "guest":
			return i
	return skip


## Zoom spread over the frames so the camera move is smooth in the video.
func _glide(count: int, total_delta: float) -> void:
	var per := total_delta / float(count)
	for _i in count:
		_main._zoom_by(per, _main.zoom_viewport.size / 2.0)
		await _write_frame()


## Where a room sits in canvas space, in the coordinates _rebuild_hotel() lays the
## buttons out in: x from the column, y counted DOWN from the top floor.
func _room_center(idx: int) -> Vector2:
	var g := get_node("/root/Game")
	var r: Dictionary = g.rooms[idx]
	var row_y: float = float(g.floors - int(r.floor)) * _main.CELL_H
	return Vector2(
		float(int(r.col)) * _main.CELL_W + float(int(r.w)) * _main.CELL_W * 0.5,
		row_y + _main.CELL_H * 0.5)


## The middle of the whole building, for the pull-back beats.
func _building_center() -> Vector2:
	return _main.building_canvas.custom_minimum_size * 0.5


## Glides the camera to a zoom level AND a point, instead of zooming around the
## middle of the viewport. `_glide()` only ever changed the zoom, so the "push in
## on one room" beat pushed in on whatever happened to be centred — which was the
## middle of the building, never the room being decorated, and the beat read as a
## slow scale-up of the same wide shot.
##
## `hard_max` lifts the game's own ZOOM_MAX for a beat. That cap is 1.5 because
## eight columns of 90 px fill a 1080-wide phone exactly, so IN GAME the camera
## can never get closer than "the whole building" — the old push-in asked for
## +0.85 and moved nothing at all, since the shot was already at the cap. A
## close-up is the one thing a promo clip has to be able to do, so this beat
## goes past it; the pixels are still the game's own art at full resolution,
## the same shot a post-production crop would have produced, only sharper.
func _glide_to(count: int, target_zoom: float, point: Vector2, hard_max := 0.0) -> void:
	var m := _main
	var top: float = m.ZOOM_MAX if hard_max <= 0.0 else hard_max
	var start_zoom: float = m._zoom
	var start_pan: Vector2 = m._canvas_pan
	for i in range(1, count + 1):
		var t := float(i) / float(count)
		t = t * t * (3.0 - 2.0 * t)     # smoothstep, so the move has no jerk at either end
		var z := clampf(lerpf(start_zoom, target_zoom, t), m._effective_zoom_min(), top)
		m._zoom = z
		var centred: Vector2 = m.zoom_viewport.size * 0.5 - point * z
		m._canvas_pan = start_pan.lerp(centred, t)
		m._clamp_pan()
		m._apply_canvas_transform()
		await _write_frame()


## Same move with no frames written — for setting up the opening shot.
func _cut_to(target_zoom: float, point: Vector2) -> void:
	var m := _main
	m._zoom = clampf(target_zoom, m._effective_zoom_min(), m.ZOOM_MAX)
	m._canvas_pan = m.zoom_viewport.size * 0.5 - point * m._zoom
	m._clamp_pan()
	m._apply_canvas_transform()


func _run_frames(count: int) -> void:
	for _i in count:
		await _write_frame()


func _write_frame() -> void:
	await get_tree().process_frame
	var img := _view.get_texture().get_image()
	img.save_png("%s/frame_%04d.png" % [OUT_DIR, _frame])
	_frame += 1


## "Bu karede şu efekt duyulsun" notu. Sesin kendisi burada çalmıyor.
func _cue(kind: String) -> void:
	_cues.append({"frame": _frame, "kind": kind})


## Kurgunun ses malzemesi: oyunun kendi prosedürel efektleri ve lobi müziği,
## motorun ürettiği hâliyle WAV olarak yazılır. Dışarıdan tek bir ses dosyası
## gelmiyor — klipte duyulan, oyunda duyulanın aynısı.
func _export_audio() -> void:
	var music := Sfx.lobby_music()
	music.save_to_wav("%s/audio_music.wav" % OUT_DIR)
	for kind in SFX_STEPS:
		var wav := Sfx.tone_stream(SFX_STEPS[kind])
		wav.save_to_wav("%s/audio_%s.wav" % [OUT_DIR, kind])
	var f := FileAccess.open("%s/audio_cues.json" % OUT_DIR, FileAccess.WRITE)
	f.store_string(JSON.stringify({"fps": 30, "cues": _cues}, "	"))
	f.close()
	print("AUDIO ", _cues.size(), " cues")


## main.gd'nin _init_sfx() tablosunun aynısı. Kopya olduğu için kayabilir; kayarsa
## klipteki ses oyundakinden farklı olur, oyunun davranışı değişmez.
const SFX_STEPS := {
	"buy": [[440.0, 0.06], [880.0, 0.1]],
	"collect": [[784.0, 0.07], [1047.0, 0.09], [1319.0, 0.12]],
	"clean": [[1319.0, 0.08], [1760.0, 0.14]],
	"quest": [[784.0, 0.08], [988.0, 0.14]],
	"level": [[523.0, 0.09], [659.0, 0.09], [784.0, 0.09], [1047.0, 0.22]],
}


## Bir tuval noktasının ekrandaki yeri — animasyonlar (süpürge, uçan bozuk para)
## global ekran koordinatı istiyor.
func _screen_pos(canvas_point: Vector2) -> Vector2:
	return _main.zoom_viewport.global_position + _main._canvas_pan + canvas_point * _main._zoom
