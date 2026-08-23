extends Node
## Popup lists must scroll from anywhere, including from on top of a card.
##
## The bug this test locks down: Control defaults to MOUSE_FILTER_STOP, so the
## decorative PanelContainer every list row is painted with — and the
## transparent Button laid over it — swallowed the InputEventScreenDrag before
## the popup's ScrollContainer ever saw it. The lists only scrolled from the
## ~15px gutter beside the cards, which is the one strip with no row under the
## finger. See MOUSE_PASSTHROUGH / MOUSE_SCROLLABLE in src/main.gd.
##
## Two halves, because either one alone can pass while the feature is broken:
##
##   [1] Structural — no Control under popup_scroll may be MOUSE_FILTER_STOP.
##       Cheap, covers every popup and every tab, and catches the next row
##       primitive that is added without thinking about the drag.
##   [2] Behavioural — a real drag started on top of a row scrolls the list AND
##       does not activate the row, while a plain tap still activates it.
##
## Why it needs a window: --headless does not run layout, so the rows have no
## rect to aim a touch at. Same reason as ui_check.gd.
##
## Touch on the desktop: ScrollContainer only reads drags when the display
## reports a touchscreen, so the test turns on mouse-to-touch emulation and
## feeds events through Input.parse_input_event — the same path a real finger
## takes on the phone.
##
## Run (opens a window, NOT headless):
##   tools\Godot_v4.7-stable_win64_console.exe --path . res://tests/scroll_check.tscn

const SAVE_PATH := "user://save.json"
const BACKUP_PATH := "user://save.json.scrollcheck.bak"
const TIMEOUT_SEC := 120.0

## How far the synthetic finger travels per step, and how many steps. Ten 30px
## steps is 300px: far past SCROLL_DEADZONE, and past the height of any single
## row, so a failure cannot be read as "it nearly scrolled".
const DRAG_STEP := Vector2(0, -30)
const DRAG_STEPS := 10

var failures := 0
var checks := 0
var _finished := false
var _main: Node


func check(cond: bool, label: String) -> void:
	checks += 1
	if cond:
		print("  OK   ", label)
	else:
		failures += 1
		printerr("  FAIL ", label)


# --- Save guard (see tutorial_check.gd — same reason) --------------------

func _stash_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE_PATH),
			ProjectSettings.globalize_path(BACKUP_PATH))


func _restore_save() -> void:
	if not FileAccess.file_exists(BACKUP_PATH):
		return
	DirAccess.copy_absolute(ProjectSettings.globalize_path(BACKUP_PATH),
		ProjectSettings.globalize_path(SAVE_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(BACKUP_PATH))
	print("  (test öncesi kayıt geri yüklendi)")


func _exit_tree() -> void:
	_restore_save()


func _on_timeout() -> void:
	if _finished:
		return
	printerr("  FAIL test %.0f sn içinde bitmedi — yukarıdaki çıktıyı oku" % TIMEOUT_SEC)
	get_tree().quit(1)


# --- Synthetic finger ----------------------------------------------------
#
# Input.parse_input_event takes SCREEN coordinates; every rect the UI reports is
# in viewport coordinates, and the two differ by the canvas_items stretch. The
# root viewport's final transform is exactly that conversion.

func _to_screen(viewport_pos: Vector2) -> Vector2:
	return get_tree().root.get_final_transform() * viewport_pos


func _press(viewport_pos: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = _to_screen(viewport_pos)
	e.global_position = e.position
	Input.parse_input_event(e)


func _move(from_pos: Vector2, to_pos: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = _to_screen(to_pos)
	e.global_position = e.position
	e.relative = _to_screen(to_pos) - _to_screen(from_pos)
	e.screen_relative = e.relative
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(e)


## Press, drag DRAG_STEPS times, release.
func _drag_from(start: Vector2) -> void:
	_press(start, true)
	await get_tree().process_frame
	var p := start
	for i in DRAG_STEPS:
		var n := p + DRAG_STEP
		_move(p, n)
		p = n
		await get_tree().process_frame
	_press(p, false)
	await get_tree().process_frame
	await get_tree().process_frame


func _tap(pos: Vector2) -> void:
	_press(pos, true)
	await get_tree().process_frame
	_press(pos, false)
	await get_tree().process_frame
	await get_tree().process_frame


# --- Tree walk -----------------------------------------------------------

## Every Control under the node that still stops the drag, reported as
## "Class < ParentClass" so the offending primitive is identifiable without a
## node path (these trees are built in code and unnamed).
func _blockers(n: Node, out: Array) -> Array:
	if n is Control and (n as Control).mouse_filter == Control.MOUSE_FILTER_STOP:
		var parent := n.get_parent()
		var key := "%s < %s" % [n.get_class(), parent.get_class() if parent else "?"]
		if not out.has(key):
			out.append(key)
	for c in n.get_children():
		_blockers(c, out)
	return out


func _check_no_blockers(label: String) -> void:
	var found := _blockers(_main.popup_scroll, [])
	check(found.is_empty(), "%s: sürüklemeyi yutan düğüm yok%s"
		% [label, "" if found.is_empty() else " — " + ", ".join(found)])


# --- Flow ----------------------------------------------------------------

func _ready() -> void:
	print("Little Grand Hotel — popup kaydırma testi")
	print("=".repeat(64))
	_stash_save()
	get_tree().create_timer(TIMEOUT_SEC).timeout.connect(_on_timeout)
	# A desktop display reports no touchscreen, and ScrollContainer reads drags
	# only when one is present. This is the switch the phone flips for real.
	Input.set_emulate_touch_from_mouse(true)

	var game := get_node("/root/Game")
	game.new_game()
	game.tutorial_seen = true
	game.last_daily_claim_day = game.daily_day_index()
	game.offline_earned = 0
	game.auto_renew_count = 0
	game.coins = 5_000_000
	game.gems = 5000
	game.add_xp(200000)

	_main = load("res://main.tscn").instantiate()
	add_child(_main)
	_main._finish_loading_screen()
	await get_tree().create_timer(0.6).timeout

	await _test_filters_every_popup()
	await _test_drag_over_card_scrolls()
	await _test_drag_over_row_does_not_press_it()
	await _test_tap_still_presses_row()

	_finished = true
	print("=".repeat(64))
	if failures == 0:
		print("TÜM TESTLER GEÇTİ (%d kontrol)" % checks)
	else:
		printerr("%d/%d TEST BAŞARISIZ" % [failures, checks])
	get_tree().quit(1 if failures > 0 else 0)


const POPUPS := [
	["Shift", "_build_shift_popup"],
	["Staff", "_build_staff_popup"],
	["Stats", "_build_stats_popup"],
	["Profile", "_build_profile_popup"],
	["Store", "_build_store_popup"],
	["Build", "_build_build_popup"],
	["Gems", "_build_gems_popup"],
	["Settings", "_build_settings_popup"],
	["Quests", "_build_quests_popup"],
]


func _test_filters_every_popup() -> void:
	print("\n[1] Her popup ve her sekme sürüklemeyi geçiriyor mu")
	for entry in POPUPS:
		_main._open_popup(entry[0], Callable(_main, entry[1]))
		await get_tree().process_frame
		await get_tree().process_frame
		_check_no_blockers(entry[0])
		_main._close_popup()
		await get_tree().process_frame

	for tab in ["account", "prestige", "stats", "settings"]:
		_main._profile_tab = tab
		_main._open_popup("Profile", _main._build_profile_popup)
		await get_tree().process_frame
		_check_no_blockers("Profile/" + tab)
		_main._close_popup()
		await get_tree().process_frame

	for tab in ["gems", "premium"]:
		_main._store_tab = tab
		_main._open_popup("Store", _main._build_store_popup)
		await get_tree().process_frame
		_check_no_blockers("Store/" + tab)
		_main._close_popup()
		await get_tree().process_frame

	for tab in ["quests", "achievements"]:
		_main._quests_tab = tab
		_main._open_popup("Quests", _main._build_quests_popup)
		await get_tree().process_frame
		_check_no_blockers("Quests/" + tab)
		_main._close_popup()
		await get_tree().process_frame

	# Room and facility screens are reached from the building, not the bar, and
	# they are the longest lists in the game — worth covering by hand.
	var game := get_node("/root/Game")
	var guest := -1
	var facility := -1
	for i in game.rooms.size():
		var cat: String = game.room_def(game.rooms[i].type).category
		if cat == "guest" and guest < 0:
			guest = i
		elif cat != "guest" and facility < 0:
			facility = i
	if guest >= 0:
		_main.selected_room = guest
		_main._open_popup("Room Decoration", _main._build_room_popup)
		await get_tree().process_frame
		_check_no_blockers("Room Decoration")
		_main._close_popup()
		await get_tree().process_frame
	if facility >= 0:
		_main.selected_room = facility
		_main._open_popup("Facility", _main._build_facility_popup)
		await get_tree().process_frame
		_check_no_blockers("Facility")
		_main._close_popup()
		await get_tree().process_frame
	_main.selected_room = -1


## The rows the behavioural half drags over. They are appended to a popup that
## is already open rather than reusing a real row, so that a stray press cannot
## spend the player's coins — and so the list is guaranteed taller than the
## screen no matter how the real screens change.
var _probe_rows: Array[Button] = []
var _probe_hits := 0


func _open_probe_popup() -> void:
	_main._open_popup("Settings", _main._build_settings_popup)
	await get_tree().process_frame
	_probe_rows.clear()
	_probe_hits = 0
	for i in 30:
		var b: Button = _main._sheet_row(_main.popup_content,
			{"title": "probe row %d" % i, "meta": "scroll test"})
		b.pressed.connect(func(): _probe_hits += 1)
		_probe_rows.append(b)
	await get_tree().process_frame
	await get_tree().process_frame
	_main.popup_scroll.scroll_vertical = 0
	await get_tree().process_frame


## The centre of a probe row that is fully on screen — where a thumb would land.
func _visible_probe_row() -> Button:
	var view: Rect2 = _main.popup_scroll.get_global_rect()
	for b in _probe_rows:
		if view.encloses(b.get_global_rect()):
			return b
	return _probe_rows[0]


func _test_drag_over_card_scrolls() -> void:
	print("\n[2] Kartın ÜSTÜNDEN sürükleyince liste kayıyor")
	await _open_probe_popup()
	var scroll: ScrollContainer = _main.popup_scroll
	check(scroll.get_v_scroll_bar().max_value > scroll.size.y,
		"deneme listesi ekrandan uzun (%d > %d)"
		% [int(scroll.get_v_scroll_bar().max_value), int(scroll.size.y)])
	await _drag_from(_visible_probe_row().get_global_rect().get_center())
	check(scroll.scroll_vertical > 0,
		"kart üstünden sürükleme kaydırdı (scroll_vertical = %d)" % scroll.scroll_vertical)
	_main._close_popup()
	await get_tree().process_frame


func _test_drag_over_row_does_not_press_it() -> void:
	print("\n[3] Sürükleme satırı TIKLAMIYOR")
	await _open_probe_popup()
	await _drag_from(_visible_probe_row().get_global_rect().get_center())
	check(_probe_hits == 0, "sürükleme satırı tetiklemedi (%d tıklama)" % _probe_hits)
	_main._close_popup()
	await get_tree().process_frame


func _test_tap_still_presses_row() -> void:
	print("\n[4] Düz dokunuş satırı hâlâ açıyor")
	await _open_probe_popup()
	await _tap(_visible_probe_row().get_global_rect().get_center())
	check(_probe_hits == 1, "dokunuş satırı bir kez tetikledi (%d tıklama)" % _probe_hits)
	check(_main.popup_scroll.scroll_vertical == 0,
		"dokunuş listeyi kaydırmadı (scroll_vertical = %d)" % _main.popup_scroll.scroll_vertical)
	_main._close_popup()
	await get_tree().process_frame
