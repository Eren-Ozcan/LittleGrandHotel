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


## main'i yeniden kuruluma götüren tüm sinyal bağlantılarını söker.
##
## Yalnızca `_main`'e giden bağlantılar sökülür; oyunun kendi iç bağlantıları
## yerinde kalır, yoksa test ölçtüğü şeyin altını oymuş olur.
func _mute_rebuilds() -> void:
	var game := get_node("/root/Game")
	var signals: Array[Signal] = [
		game.state_changed,
		game.quest_completed,
		game.achievement_unlocked,
		game.leveled_up,
		IAP.prices_updated,
		CloudSave.status_changed,
		CloudSave.sync_finished,
	]
	var cut := 0
	for sig: Signal in signals:
		for c in sig.get_connections():
			var cb: Callable = c["callable"]
			if cb.get_object() == _main:
				sig.disconnect(cb)
				cut += 1
	print("  (yeniden kurulum bağlantıları söküldü: %d)" % cut)


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


## Press, drag DRAG_STEPS times, release. The step defaults to a swipe up; the
## build tray is horizontal and passes its own.
func _drag_from(start: Vector2, step: Vector2 = DRAG_STEP) -> void:
	_press(start, true)
	await get_tree().process_frame
	var p := start
	for i in DRAG_STEPS:
		var n := p + step
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
	# A text field is the one control that legitimately keeps the drag: dragging
	# inside it selects text. It is never the thing a finger scrolls from.
	if n is Control and (n as Control).mouse_filter == Control.MOUSE_FILTER_STOP 			and not n is LineEdit and not n is TextEdit:
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
	# The developer machine has a real cloud/device save conflict, and the
	# download that detects it lands at an unpredictable point in the run. The
	# conflict modal is a full-screen overlay, so it silently eats the taps and
	# drags this test aims at the list underneath. Clearing the state costs
	# nothing on disk or in the cloud; CloudSave.resolve_keep_local would upload
	# to the real account, which a UI test has no business doing.
	CloudSave._blocked = false
	CloudSave._pending_cloud = {}
	if CloudSave.conflict_detected.is_connected(_main._on_cloud_conflict):
		CloudSave.conflict_detected.disconnect(_main._on_cloud_conflict)
	_main._finish_loading_screen()
	await get_tree().create_timer(0.6).timeout
	# Freeze the simulation. This test measures input plumbing, not gameplay:
	# while it runs, a shift can end or a quest can complete, and main rebuilds
	# the open popup in response — which throws away the probe rows mid-drag and
	# resets scroll_vertical to 0, showing up as a rare "the drag did not
	# scroll" failure that has nothing to do with the drag.
	game.set_process(false)
	_main.set_process(false)
	# Donma TEK BAŞINA yetmiyor: yeniden kurulum _process'ten değil SİNYALDEN
	# geliyor. Süreç kapalıyken bile bir bulut durumu, bir fiyat yanıtı ya da
	# kuyrukta kalmış bir state_changed düşerse popup yeniden kuruluyor ve
	# ölçtüğümüz kaydırma sıfırlanıyor — paket yüklüyken gerçekten yaşandı
	# (2026-08-25, iki ayrı koşuda iki ayrı kontrol). Bu yüzden main'in
	# yeniden kurulum bağlantıları test boyunca sökülüyor.
	_mute_rebuilds()

	await _test_filters_every_popup()
	await _test_drag_over_card_scrolls()
	await _test_drag_over_row_does_not_press_it()
	await _test_tap_still_presses_row()
	await _test_modals_scroll()
	await _test_build_tray()

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
	# A fresh save has no facility room, so without this the facility screen —
	# one of the longest lists in the game — would silently go uncovered.
	game.buy_room("cafe")
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


func _probe_rows_alive() -> bool:
	for b in _probe_rows:
		if not is_instance_valid(b):
			return false
	return true


## main rebuilds the open popup whenever a game signal says its numbers moved,
## and a rebuild frees everything appended here. The simulation is frozen, but a
## signal queued before the freeze can still land — so build the rows, give them
## two frames to survive, and start over if they did not.
func _open_probe_popup() -> void:
	for attempt in 3:
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
		if _probe_rows_alive():
			break
	check(_probe_rows_alive(), "deneme satırları ayakta")
	_main.popup_scroll.scroll_vertical = 0
	await get_tree().process_frame


## The centre of a probe row that is fully on screen — where a thumb would land.
func _visible_probe_row() -> Button:
	var view: Rect2 = _main.popup_scroll.get_global_rect()
	var first: Button = null
	for b in _probe_rows:
		if not is_instance_valid(b):
			continue
		if first == null:
			first = b
		if view.encloses(b.get_global_rect()):
			return b
	return first


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

# --- Modals --------------------------------------------------------------
#
# A modal is a centred card, so an over-long body used to run straight off the
# screen — including its action button, which made the modal impossible to
# close. The body now lives in a ScrollContainer (see _modal_shell in
# src/main.gd), and the same drag rules apply to it as to the popup lists.

## Topmost open modal (see main.gd _modal_shell: ColorRect, z_index >= 90, a
## direct child of main). Topmost, not first: modals stack.
func _modal_root() -> ColorRect:
	var top: ColorRect = null
	for c in _main.get_children():
		if c is ColorRect and c.z_index >= 90 and not c.is_queued_for_deletion():
			top = c
	return top


func _modal_scroll(m: Node) -> ScrollContainer:
	var found := m.find_children("*", "ScrollContainer", true, false)
	return found[0] if found.size() > 0 else null


func _free_modal() -> void:
	var m := _modal_root()
	if m != null:
		m.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


## Every modal check that does not depend on how the body was built.
func _check_modal(label: String) -> void:
	var m := _modal_root()
	check(m != null, "%s: modal açıldı" % label)
	if m == null:
		return
	var scroll := _modal_scroll(m)
	check(scroll != null, "%s: gövde kaydırılabilir kapta" % label)
	if scroll == null:
		return
	var found := _blockers(scroll, [])
	check(found.is_empty(), "%s: sürüklemeyi yutan düğüm yok%s"
		% [label, "" if found.is_empty() else " — " + ", ".join(found)])
	# The card must fit on screen, or the action button is out of reach and the
	# modal cannot be dismissed at all.
	var panel := scroll.get_parent() as Control
	check(panel.size.y <= _main.get_viewport_rect().size.y,
		"%s: kart ekrana sığıyor (%d ≤ %d)"
			% [label, int(panel.size.y), int(_main.get_viewport_rect().size.y)])


func _test_modals_scroll() -> void:
	print("
[5] Modaller kaydırılabilir")
	var game := get_node("/root/Game")

	_main._show_simple_modal("Test", "Kısa gövde", "Tamam", func(): pass)
	await get_tree().process_frame
	await get_tree().process_frame
	_check_modal("basit modal")
	await _free_modal()

	_main._show_rename_hotel_modal()
	await get_tree().process_frame
	await get_tree().process_frame
	_check_modal("otel adı modalı")
	await _free_modal()

	_main._show_offline_popup(12345, 2, 500)
	await get_tree().process_frame
	await get_tree().process_frame
	_check_modal("çevrimdışı özet")
	await _free_modal()

	game.last_daily_claim_day = game.daily_day_index() - 1
	_main._show_daily_reward_popup()
	await get_tree().process_frame
	await get_tree().process_frame
	_check_modal("günlük ödül")
	await _free_modal()

	# The conflict screen never opens without a conflict, and the real one was
	# cleared above. Fake the state instead of provoking a real conflict — this
	# touches nothing on disk or in the cloud.
	CloudSave._blocked = true
	CloudSave._pending_cloud = {
		"rev": 1, "updated_at": Time.get_unix_time_from_system() - 60.0,
		"summary": {"level": 7, "coins": 1234, "gems": 42, "rooms": 5},
	}
	_main._cloud_conflict_open = false
	_main._show_cloud_conflict_modal()
	await get_tree().process_frame
	await get_tree().process_frame
	_check_modal("bulut çakışması")
	await _free_modal()
	_main._cloud_conflict_open = false
	CloudSave._blocked = false
	CloudSave._pending_cloud = {}

	# The case the whole change is about: a body far taller than the screen.
	var long_text := ""
	for i in 60:
		long_text += "Bu satır modalın gövdesini ekrandan uzun yapmak için var. %d
" % i
	_main._show_simple_modal("Uzun", long_text, "Tamam", func(): pass)
	await get_tree().process_frame
	await get_tree().process_frame
	_check_modal("uzun gövde")
	var m := _modal_root()
	var scroll := _modal_scroll(m)
	if scroll != null:
		check(scroll.get_v_scroll_bar().max_value > scroll.size.y + 1.0,
			"uzun gövde: kaydırma gerçekten gerekiyor (%d > %d)"
				% [int(scroll.get_v_scroll_bar().max_value), int(scroll.size.y)])
		await _drag_from(scroll.get_global_rect().get_center())
		check(scroll.scroll_vertical > 0,
			"uzun gövde: gövde üstünden sürükleme kaydırdı (scroll_vertical = %d)"
				% scroll.scroll_vertical)
	await _free_modal()

# --- Build Mode room tray -------------------------------------------------
#
# The tray is the one horizontal list in the game, and it holds more room types
# than fit on screen: without scrolling from on top of a card, the rightmost
# types are simply unreachable. It also has a second gesture on the same finger
# — press a card and pull it out to place a room — so here the two have to be
# told apart rather than one simply winning.

func _test_build_tray() -> void:
	print("
[6] İnşa Modu oda rafı")
	var game := get_node("/root/Game")
	# The tray reads the drag through _process, so the freeze has to lift.
	_main.set_process(true)
	game.set_process(false)
	_main._set_build_mode(true)
	await get_tree().process_frame
	await get_tree().process_frame
	var tray: ScrollContainer = _main.build_shop_scroll
	check(tray != null and tray.visible, "raf açıldı")
	if tray == null:
		return
	check(tray.get_h_scroll_bar().max_value > tray.size.x + 1.0,
		"raf ekrandan geniş — kaydırma zorunlu (%d > %d)"
			% [int(tray.get_h_scroll_bar().max_value), int(tray.size.x)])
	var found := _blockers(tray, [])
	check(found.is_empty(), "rafta sürüklemeyi yutan düğüm yok%s"
		% ("" if found.is_empty() else " — " + ", ".join(found)))

	var card: Button = _main.build_shop_row.get_child(0)
	var centre: Vector2 = card.get_global_rect().get_center()

	# Sideways: the tray scrolls and no room leaves the shelf.
	tray.scroll_horizontal = 0
	await get_tree().process_frame
	await _drag_from(centre, Vector2(-30, 0))
	check(tray.scroll_horizontal > 0,
		"kart üstünden yatay sürükleme rafı kaydırdı (scroll_horizontal = %d)"
			% tray.scroll_horizontal)
	check(not _main._drag_active and _main._drag_new_type == "",
		"yatay sürükleme odayı raftan ÇIKARMADI")

	# Upwards: the room comes out, and the tray stays put underneath it.
	#
	# The direction rule is driven through the state machine rather than through
	# synthetic motion: Input.parse_input_event does not move the engine's cursor,
	# and _update_room_drag reads get_global_mouse_position(). So the press is
	# real and the gesture's DIRECTION is set by moving its start point — which
	# is exactly the quantity the rule is written against.
	tray.scroll_horizontal = 0
	await get_tree().process_frame
	await get_tree().process_frame
	card = _main.build_shop_row.get_child(0)
	centre = card.get_global_rect().get_center()
	_press(centre, true)
	await get_tree().process_frame
	check(_main._drag_new_type != "", "karta basmak odayı aday yaptı")
	var here: Vector2 = _main.get_global_mouse_position()

	# Sideways gesture: stays on the shelf, so the tray can scroll.
	_main._drag_active = false
	_main._drag_start_mouse = here + Vector2(200, 0)
	_main._update_room_drag()
	check(not _main._drag_active, "yanlamasına hareket odayı raftan çıkarmıyor")

	# Upward gesture: comes out.
	_main._drag_start_mouse = here + Vector2(0, 200)
	_main._update_room_drag()
	check(_main._drag_active, "yukarı doğru hareket odayı raftan çıkardı")
	check(tray.scroll_horizontal == 0, "oda çıkarılırken raf yerinde kaldı (%d)"
		% tray.scroll_horizontal)
	_press(here, false)
	await get_tree().process_frame
	await get_tree().process_frame
	check(not _main._drag_active and _main._drag_ghost == null,
		"bırakınca sürükleme temizlendi")

	_main._set_build_mode(false)
	await get_tree().process_frame
	_main.set_process(false)
