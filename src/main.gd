extends Control
## Little Grand Hotel — arayüz (görsel sürüm).
## Hotel City'den ilham alan kesit "dollhouse" görünüm: parlak gökyüzü,
## sıcak cephe, duvar kağıtlı odalar, mobilya ve misafir görselleri.

const PALETTE := {
	"sky_top": Color("6db9e8"),
	"sky_bottom": Color("cfeafc"),
	"cream": Color("f8f2e2"),
	"cream_dark": Color("efe5cc"),
	"facade": Color("f3e4c3"),
	"facade_line": Color("b39463"),
	"wood": Color("8a6642"),
	"wood_dark": Color("6e4f31"),
	"gold": Color("e0a92f"),
	"gold_soft": Color("f0c75e"),
	"text": Color("4a3b2a"),
	"muted": Color("8a7a62"),
	"cream_text": Color("fdf6e3"),
	"green_deep": Color("14532d"),
	"banner_red": Color("a83e35"),
	"floor_wood": Color("c19a6f"),
	"locked": Color("41372c"),
	"frame": Color("2f2418"),
	"asphalt": Color("55504a"),
	"bar_dark": Color("33261a"),
}

const WALLPAPERS := {
	"standard": Color("dcebf5"),
	"deluxe": Color("f7e2e6"),
	"suite": Color("eee4f7"),
	"cafe": Color("f7ecd9"),
	"gym": Color("e3eef0"),
	"pool": Color("dff2f7"),
	"cinema": Color("e8e3ef"),
	"spa": Color("eaf3e8"),
	"restaurant": Color("f7e7d4"),
	"roof_garden": Color("e4f2dd"),
	"housekeeping": Color("efe9db"),
}

const SPEEDS: Array[float] = [1.0, 60.0, 3600.0]
var speed_index := 0

## Haftalık dekorasyon teması: sunucusuz, Game.current_week_index()'e göre
## deterministik seçilir — çatı tabelasını hafta boyunca tek renkte boyar.
const WEEKLY_THEMES := [
	{ "name": "Klasik Kırmızı", "accent": Color("a83e35") },
	{ "name": "Yaz Esintisi", "accent": Color("1f8a8c") },
	{ "name": "Altın Çağ", "accent": Color("b8860b") },
	{ "name": "Lavanta Molası", "accent": Color("6a4c93") },
	{ "name": "Orman Nefesi", "accent": Color("2f7a4f") },
	{ "name": "Mercan Gün Batımı", "accent": Color("c9622a") },
	{ "name": "Kış Masalı", "accent": Color("2f6fa8") },
]

var coins_label: Label
var gems_label: Label
var star_icons: Array = []
var level_label: Label
var xp_bar: ProgressBar
var shift_label: Label
var shift_bar_label: Label
var collect_button: Button
var hotel_box: VBoxContainer
var street_node: PanelContainer
var quest_hint: Label
var toast_panel: PanelContainer
var toast_label: Label

var overlay: Control
var popup_title: Label
var popup_content: VBoxContainer
var popup_builder: Callable = Callable()

var selected_room := -1
var move_from := -1
var _walker: Control = null
var _walker_timer := 0.0
var _toast_timer := 0.0
var _tex_cache: Dictionary = {}
var _sfx_players: Dictionary = {}
var music_player: AudioStreamPlayer


func _ready() -> void:
	_build_ui()
	_init_sfx()
	Game.state_changed.connect(_refresh)
	Game.quest_completed.connect(_on_quest_completed)
	Game.achievement_unlocked.connect(_on_achievement_unlocked)
	Game.leveled_up.connect(func(lv):
		_play("level")
		_show_toast("Seviye atladın! Seviye %d (+%d elmas)" % [lv, int(Game.eco.levelup_gems)]))
	_refresh()
	if Game.daily_reward_available():
		_show_daily_reward_popup(_maybe_show_offline_popup)
	else:
		_maybe_show_offline_popup()


func _maybe_show_offline_popup() -> void:
	if Game.offline_earned > 0 or Game.auto_renew_count > 0:
		_show_offline_popup(Game.offline_earned, Game.auto_renew_count, Game.auto_renew_spent)
		Game.offline_earned = 0
		Game.auto_renew_count = 0
		Game.auto_renew_spent = 0


func _process(delta: float) -> void:
	_update_live_labels()
	_update_walker(delta)
	if _toast_timer > 0.0:
		_toast_timer -= delta
		if _toast_timer <= 0.0:
			toast_panel.visible = false


## Kaçan misafir: vardiya sırasında ara ara sokakta bir misafir yürüyüp
## geçer; dokunursan kapıya döner ve bonus verir (Hotel City "drag guest").
func _update_walker(delta: float) -> void:
	if not Game.shift_active() or is_instance_valid(_walker):
		return
	_walker_timer += delta
	if _walker_timer < float(Game.eco.catch.interval_real_seconds):
		return
	_walker_timer = 0.0
	_spawn_walker()


func _spawn_walker() -> void:
	if street_node == null or not is_instance_valid(street_node):
		return
	var walk_y := street_node.global_position.y - 34.0
	var b := TextureButton.new()
	b.texture_normal = _tex("res://assets/guests/guest_%s.svg" % ["a", "b", "c"][randi() % 3])
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	b.custom_minimum_size = Vector2(40, 40)
	b.size = Vector2(40, 40)
	b.position = Vector2(size.x + 24.0, walk_y)
	b.z_index = 55
	add_child(b)
	_walker = b
	_animate_guest(b, randi() % 4, true)
	var tw := b.create_tween()
	b.set_meta("walk_tween", tw)
	tw.tween_property(b, "position:x", -64.0, 10.0)
	tw.tween_callback(b.queue_free)
	b.pressed.connect(func(): _on_walker_caught(b))


func _on_walker_caught(b: Control) -> void:
	var bonus := Game.catch_guest()
	if bonus <= 0:
		return
	_play("collect")
	_show_toast("Kaçan misafiri kapıya döndürdün! +%d coin" % bonus)
	var old_tw: Tween = b.get_meta("walk_tween")
	if old_tw:
		old_tw.kill()
	b.disabled = true
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := b.create_tween()
	tw.tween_property(b, "position:x", size.x / 2.0, 0.8) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(b, "scale", Vector2(0.3, 0.3), 0.25)
	tw.parallel().tween_property(b, "modulate:a", 0.0, 0.25)
	tw.tween_callback(b.queue_free)


func _init_sfx() -> void:
	var defs := {
		"tap": [[660.0, 0.05]],
		"buy": [[440.0, 0.06], [880.0, 0.1]],
		"collect": [[784.0, 0.07], [1047.0, 0.09], [1319.0, 0.12]],
		"clean": [[1319.0, 0.08], [1760.0, 0.14]],
		"shift": [[988.0, 0.1], [659.0, 0.2]],
		"quest": [[784.0, 0.08], [988.0, 0.14]],
		"level": [[523.0, 0.09], [659.0, 0.09], [784.0, 0.09], [1047.0, 0.22]],
	}
	for k in defs:
		var p := AudioStreamPlayer.new()
		p.stream = Sfx.tone_stream(defs[k])
		p.volume_db = -6.0
		add_child(p)
		_sfx_players[k] = p
	music_player = AudioStreamPlayer.new()
	music_player.stream = Sfx.lobby_music()
	music_player.volume_db = -14.0
	add_child(music_player)
	if Game.music_on:
		music_player.play()


func _play(kind: String) -> void:
	if Game.sound_on and _sfx_players.has(kind):
		_sfx_players[kind].play()


func _tex(path: String) -> Texture2D:
	if not _tex_cache.has(path):
		_tex_cache[path] = load(path)
	return _tex_cache[path]


# --- Kurulum -----------------------------------------------------------

func _build_ui() -> void:
	# Gökyüzü degrade + şehir silüeti + bulutlar
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	grad.colors = PackedColorArray([PALETTE.sky_top, PALETTE.sky_bottom])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	var sky := TextureRect.new()
	sky.texture = gt
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sky)

	var skyline := TextureRect.new()
	skyline.texture = _tex("res://assets/ui/skyline.svg")
	skyline.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	skyline.stretch_mode = TextureRect.STRETCH_SCALE
	skyline.anchor_left = 0.0
	skyline.anchor_right = 1.0
	skyline.anchor_top = 1.0
	skyline.anchor_bottom = 1.0
	skyline.offset_top = -320
	skyline.offset_bottom = -150
	skyline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(skyline)

	for cdef in [[40, 130, 130], [420, 210, 170], [230, 620, 110]]:
		var cloud := TextureRect.new()
		cloud.texture = _tex("res://assets/ui/cloud.svg")
		cloud.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		cloud.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		cloud.position = Vector2(cdef[0], cdef[1])
		cloud.custom_minimum_size = Vector2(cdef[2], cdef[2] * 0.46)
		cloud.size = cloud.custom_minimum_size
		cloud.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(cloud)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	# --- Üst bar (krem panel)
	var top := _panel(PALETTE.cream, PALETTE.facade_line)
	root.add_child(top)
	var top_box := VBoxContainer.new()
	top_box.add_theme_constant_override("separation", 6)
	top.add_child(top_box)

	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 6)
	top_box.add_child(row1)
	row1.add_child(_icon("res://assets/ui/coin.svg", 26))
	coins_label = _label("", 21, PALETTE.text)
	row1.add_child(coins_label)
	row1.add_child(_spacer_x(10))
	row1.add_child(_icon("res://assets/ui/gem.svg", 26))
	gems_label = _label("", 21, PALETTE.text)
	row1.add_child(gems_label)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row1.add_child(sp)
	for i in 5:
		var s := _icon("res://assets/ui/star_empty.svg", 24)
		star_icons.append(s)
		row1.add_child(s)

	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 10)
	top_box.add_child(row2)
	level_label = _label("", 15, PALETTE.muted)
	row2.add_child(level_label)
	xp_bar = ProgressBar.new()
	xp_bar.show_percentage = false
	xp_bar.custom_minimum_size = Vector2(0, 12)
	xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var xb := StyleBoxFlat.new()
	xb.bg_color = PALETTE.cream_dark
	xb.set_corner_radius_all(6)
	xp_bar.add_theme_stylebox_override("background", xb)
	var xf := StyleBoxFlat.new()
	xf.bg_color = PALETTE.gold
	xf.set_corner_radius_all(6)
	xp_bar.add_theme_stylebox_override("fill", xf)
	row2.add_child(xp_bar)

	# --- Vardiya durumu + topla
	shift_label = _label("", 14, PALETTE.text)
	shift_label.add_theme_color_override("font_outline_color", PALETTE.cream)
	shift_label.add_theme_constant_override("outline_size", 6)
	root.add_child(shift_label)

	collect_button = _button("", 22, PALETTE.gold, PALETTE.text)
	collect_button.custom_minimum_size = Vector2(0, 60)
	collect_button.pressed.connect(_on_collect)
	root.add_child(collect_button)

	# --- Görev ipucu
	var qp := _panel(PALETTE.green_deep, PALETTE.gold)
	root.add_child(qp)
	quest_hint = _label("", 14, PALETTE.gold_soft)
	quest_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	qp.add_child(quest_hint)

	# --- Otel görünümü
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	hotel_box = VBoxContainer.new()
	hotel_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hotel_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hotel_box.add_theme_constant_override("separation", 0)
	scroll.add_child(hotel_box)

	# --- Alt bar: koyu şerit üzerinde ikonlu kategoriler (Hotel City tarzı)
	var bar_panel := PanelContainer.new()
	var bar_sb := StyleBoxFlat.new()
	bar_sb.bg_color = PALETTE.bar_dark
	bar_sb.set_corner_radius_all(12)
	bar_sb.set_content_margin_all(6)
	bar_sb.border_color = PALETTE.gold
	bar_sb.set_border_width_all(2)
	bar_panel.add_theme_stylebox_override("panel", bar_sb)
	root.add_child(bar_panel)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 6)
	bar_panel.add_child(bottom)

	var shift_b := _bar_button("res://assets/ui/icon_clock.svg", "Vardiya")
	shift_b.pressed.connect(func(): _open_popup("Vardiya", _build_shift_popup))
	bottom.add_child(shift_b)
	shift_bar_label = shift_b.get_meta("label")

	for def in [
		["res://assets/ui/icon_shop.svg", "Mağaza", _build_shop_popup],
		["res://assets/ui/icon_quest.svg", "Görevler", _build_quests_popup],
		["res://assets/ui/icon_stats.svg", "İstatistik", _build_stats_popup],
		["res://assets/ui/icon_gear.svg", "Ayarlar", _build_settings_popup],
	]:
		var b := _bar_button(def[0], def[1])
		var builder: Callable = def[2]
		var title: String = def[1]
		b.pressed.connect(func(): _open_popup(title, builder))
		bottom.add_child(b)

	speed_index = maxi(0, SPEEDS.find(Game.time_scale))
	var speed_b := _bar_button("", "×%d" % int(SPEEDS[speed_index]))
	speed_b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	speed_b.custom_minimum_size = Vector2(64, 66)
	speed_b.pressed.connect(func():
		_cycle_speed()
		speed_b.get_meta("label").text = "×%d" % int(SPEEDS[speed_index]))
	bottom.add_child(speed_b)

	# --- Popup katmanı
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.2, 0.15, 0.05, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed:
			_close_popup())
	overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)
	var panel := _panel(PALETTE.cream, PALETTE.facade_line)
	panel.custom_minimum_size = Vector2(620, 0)
	center.add_child(panel)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 10)
	panel.add_child(pv)
	var head := HBoxContainer.new()
	pv.add_child(head)
	popup_title = _label("", 21, PALETTE.wood_dark)
	popup_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(popup_title)
	var close_b := _button("Kapat", 15, PALETTE.wood, PALETTE.cream_text)
	close_b.pressed.connect(_close_popup)
	head.add_child(close_b)
	var pscroll := ScrollContainer.new()
	pscroll.custom_minimum_size = Vector2(0, 640)
	pv.add_child(pscroll)
	popup_content = VBoxContainer.new()
	popup_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	popup_content.add_theme_constant_override("separation", 8)
	pscroll.add_child(popup_content)

	# --- Toast: alt barın üstünde yüzer, yerleşimi itmez; popup'ların da üstünde
	toast_panel = _panel(PALETTE.green_deep, PALETTE.gold)
	toast_panel.visible = false
	toast_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	toast_panel.offset_left = 40
	toast_panel.offset_right = -40
	toast_panel.offset_top = -156
	toast_panel.offset_bottom = -84
	toast_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast_panel)
	toast_label = _label("", 16, PALETTE.cream_text)
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_panel.add_child(toast_label)


func _panel(bg: Color, border: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(12)
	sb.border_color = border
	sb.set_border_width_all(2)
	p.add_theme_stylebox_override("panel", sb)
	return p


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _icon(path: String, px: int) -> TextureRect:
	var t := TextureRect.new()
	t.texture = _tex(path)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(px, px)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## Alt bar butonu: ikon üstte, etiket altta. Etikete b.get_meta("label") ile
## erişilir (vardiya geri sayımı gibi canlı metinler için).
func _bar_button(icon_path: String, text: String) -> Button:
	var b := Button.new()
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 66)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = PALETTE.bar_dark
		if state == "hover":
			sb.bg_color = PALETTE.bar_dark.lightened(0.08)
		elif state == "pressed":
			sb.bg_color = PALETTE.bar_dark.darkened(0.2)
		sb.set_corner_radius_all(9)
		sb.set_content_margin_all(2)
		b.add_theme_stylebox_override(state, sb)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	if icon_path != "":
		var wrap := CenterContainer.new()
		wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wrap.add_child(_icon(icon_path, 30))
		v.add_child(wrap)
	var l := _label(text, 18 if icon_path == "" else 12, PALETTE.cream_text)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(l)
	b.set_meta("label", l)
	return b


func _spacer_x(px: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(px, 0)
	return c


func _spacer_y(px: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, px)
	return c


func _button(text: String, size: int, bg: Color, fg: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", fg)
	b.add_theme_color_override("font_pressed_color", fg)
	b.add_theme_color_override("font_disabled_color", Color(fg, 0.5))
	for state in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = bg
		if state == "hover":
			sb.bg_color = bg.lightened(0.07)
		elif state == "pressed":
			sb.bg_color = bg.darkened(0.1)
		elif state == "disabled":
			sb.bg_color = bg.darkened(0.2)
		sb.set_corner_radius_all(9)
		sb.set_content_margin_all(9)
		sb.border_color = bg.darkened(0.35)
		sb.set_border_width_all(2)
		b.add_theme_stylebox_override(state, sb)
	return b


# --- Yenileme ----------------------------------------------------------

func _refresh() -> void:
	_update_live_labels()
	_rebuild_hotel()
	if overlay.visible and popup_builder.is_valid():
		_rebuild_popup()


func _update_live_labels() -> void:
	coins_label.text = _fmt(Game.coins)
	gems_label.text = str(Game.gems)
	var stars := Game.star_rating()
	for i in 5:
		star_icons[i].texture = _tex("res://assets/ui/star_full.svg" if i < stars else "res://assets/ui/star_empty.svg")
	var lv := Game.level()
	level_label.text = "Seviye %d" % lv
	var cur_xp := Game.xp - Game.xp_for_level(lv)
	var need := Game.xp_for_level(lv + 1) - Game.xp_for_level(lv)
	xp_bar.max_value = need
	xp_bar.value = cur_xp
	if Game.shift_active():
		shift_label.text = "Vardiya bitimine %s · %.0f coin/saat" % [
			_fmt_hms(Game.shift_remaining_game_hours()), Game.hourly_income()]
		shift_bar_label.text = _fmt_hms(Game.shift_remaining_game_hours())
		shift_bar_label.add_theme_color_override("font_color", PALETTE.gold_soft)
	else:
		shift_label.text = "Vardiya kapalı — otel gelir üretmiyor."
		shift_bar_label.text = "Vardiya"
		shift_bar_label.add_theme_color_override("font_color", PALETTE.cream_text)
	collect_button.text = "TOPLA — %s" % _fmt(int(Game.pending_income))
	collect_button.disabled = int(Game.pending_income) <= 0


func _current_theme() -> Dictionary:
	return WEEKLY_THEMES[Game.current_week_index() % WEEKLY_THEMES.size()]


func _rebuild_hotel() -> void:
	for c in hotel_box.get_children():
		hotel_box.remove_child(c)
		c.queue_free()

	# Bina küçükken zemine otursun diye üstte esneyen boşluk
	var top_gap := Control.new()
	top_gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hotel_box.add_child(top_gap)

	# Çatı tabelası (haftalık temaya göre renklenen tente)
	var theme: Dictionary = _current_theme()
	var roof := _panel(theme.accent, PALETTE.gold)
	hotel_box.add_child(roof)
	var roof_col := VBoxContainer.new()
	roof_col.add_theme_constant_override("separation", 2)
	roof.add_child(roof_col)
	var roof_l := _label("★  LITTLE GRAND HOTEL  ★", 18, PALETTE.gold_soft)
	roof_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	roof_col.add_child(roof_l)
	var theme_l := _label("Haftanın teması: %s" % String(theme.name), 12, PALETTE.cream_text)
	theme_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	roof_col.add_child(theme_l)

	var spf := int(Game.eco.building.slots_per_floor)
	for f: int in range(Game.floors, 0, -1):
		var row_panel := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = PALETTE.facade
		sb.border_color = PALETTE.frame
		sb.set_border_width_all(3)
		sb.set_content_margin_all(6)
		row_panel.add_theme_stylebox_override("panel", sb)
		hotel_box.add_child(row_panel)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row_panel.add_child(row)
		for s in spf:
			var idx := (f - 1) * spf + s
			row.add_child(_make_slot(idx))

	# Lobi: sütunlu resepsiyon sahnesi + komi (Hotel City lobisi)
	var lobby := PanelContainer.new()
	var lsb := StyleBoxFlat.new()
	lsb.bg_color = Color("f3e7d8")
	lsb.border_color = PALETTE.frame
	lsb.set_border_width_all(3)
	lsb.set_content_margin_all(0)
	lobby.add_theme_stylebox_override("panel", lsb)
	hotel_box.add_child(lobby)
	var lobby_scene := TextureRect.new()
	lobby_scene.texture = _tex("res://assets/ui/lobby.svg")
	lobby_scene.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lobby_scene.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	lobby_scene.custom_minimum_size = Vector2(0, 76)
	lobby_scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lobby.add_child(lobby_scene)
	var bellboy := _icon("res://assets/guests/bellboy.svg", 48)
	bellboy.anchor_left = 0.16
	bellboy.anchor_right = 0.16
	bellboy.anchor_top = 1.0
	bellboy.anchor_bottom = 1.0
	bellboy.offset_left = -24
	bellboy.offset_right = 24
	bellboy.offset_top = -66
	bellboy.offset_bottom = -8
	lobby_scene.add_child(bellboy)
	_animate_guest(bellboy, 2, false)

	# Sokak: kaldırım + kapı önünde misafir kuyruğu
	var street := PanelContainer.new()
	var ssb := StyleBoxFlat.new()
	ssb.bg_color = PALETTE.asphalt
	ssb.border_color = PALETTE.frame
	ssb.border_width_top = 3
	ssb.content_margin_left = 12
	ssb.content_margin_top = 2
	ssb.content_margin_bottom = 2
	street.add_theme_stylebox_override("panel", ssb)
	hotel_box.add_child(street)
	street_node = street
	var queue := HBoxContainer.new()
	queue.add_theme_constant_override("separation", 4)
	street.add_child(queue)
	if Game.shift_active():
		for gi in mini(3 + Game.rooms.size() / 2, 8):
			var gicon := _icon("res://assets/guests/guest_%s.svg" % ["a", "b", "c"][gi % 3], 34)
			queue.add_child(gicon)
			_animate_guest(gicon, gi, true)
	else:
		var street_l := _label("· · · sokak sakin — vardiya başlat · · ·", 12, PALETTE.cream)
		queue.add_child(street_l)

	# Yeni kat
	if Game.floors < int(Game.eco.building.max_floors):
		var fb := _button("Yeni kat aç — %s coin" % _fmt(Game.floor_price()), 15, PALETTE.wood_dark, PALETTE.cream_text)
		fb.disabled = not Game.can_buy_floor()
		fb.pressed.connect(func():
			if Game.buy_floor():
				_show_toast("Yeni kat açıldı!"))
		hotel_box.add_child(fb)

	var q: Dictionary = Game.current_quest()
	if q.is_empty():
		quest_hint.text = "Tüm görevler tamamlandı — otel senin!"
	else:
		var p: Array = Game.quest_progress(q)
		quest_hint.text = "Görev: %s (%d/%d)" % [q.name, mini(p[0], p[1]), p[1]]


func _make_slot(idx: int) -> Control:
	if idx < Game.rooms.size():
		return _make_room_button(idx)
	elif idx == Game.rooms.size() and idx < Game.max_slots():
		var b := _button("+\nOda ekle", 14, PALETTE.cream_dark, PALETTE.muted)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 118)
		b.pressed.connect(func(): _open_popup("Mağaza", _build_shop_popup))
		return b
	else:
		var p := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = PALETTE.locked
		sb.border_color = PALETTE.frame
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(3)
		p.add_theme_stylebox_override("panel", sb)
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p.custom_minimum_size = Vector2(0, 118)
		var l := _label("▚ perde kapalı ▞", 11, Color("8d8070"))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		p.add_child(l)
		return p


func _make_room_button(idx: int) -> Button:
	var room: Dictionary = Game.rooms[idx]
	var d: Dictionary = Game.room_def(room.type)
	var cat: String = d.category
	var is_dirty: bool = cat == "guest" and room.dirty
	var is_infested: bool = is_dirty and Game.room_infested(room)

	var b := Button.new()
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 118)
	var wall: Color = WALLPAPERS.get(room.type, PALETTE.cream)
	if is_infested:
		wall = wall.darkened(0.45)
	elif is_dirty:
		wall = wall.darkened(0.25)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = wall if state != "hover" else wall.lightened(0.05)
		sb.border_color = PALETTE.frame
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(3)
		b.add_theme_stylebox_override(state, sb)
	b.pressed.connect(func(): _on_room_tapped(idx, b))

	# Zemin şeridi
	var floor_rect := ColorRect.new()
	floor_rect.color = PALETTE.floor_wood if not is_dirty else PALETTE.floor_wood.darkened(0.25)
	floor_rect.anchor_top = 1.0
	floor_rect.anchor_bottom = 1.0
	floor_rect.anchor_right = 1.0
	floor_rect.offset_top = -16
	floor_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(floor_rect)

	# İçerik
	if cat == "guest":
		var strip := HBoxContainer.new()
		strip.add_theme_constant_override("separation", 2)
		strip.anchor_top = 1.0
		strip.anchor_bottom = 1.0
		strip.anchor_right = 1.0
		strip.offset_top = -62
		strip.offset_bottom = -12
		strip.offset_left = 6
		strip.alignment = BoxContainer.ALIGNMENT_CENTER
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(strip)
		var shown := 0
		var seen := {}
		for item_id in room.items:
			if seen.has(item_id) or shown >= 4:
				continue
			seen[item_id] = true
			var it := _icon("res://assets/items/%s.svg" % item_id, 46)
			strip.add_child(it)
			shown += 1
		if room.items.size() == 0 and not is_dirty:
			var hint := _label("boş oda", 12, PALETTE.muted)
			hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
			strip.add_child(hint)
			# Dekorasyon dürtmesi: en ucuz eşya karşılanabiliyorsa yanıp sönen rozet.
			# Yıldızın oda/kat büyütmenin gölgesinde kalmaması için (TODO gözlemi).
			var cheapest := Game.cheapest_item_price()
			if cheapest > 0 and Game.coins >= cheapest:
				b.add_child(_make_decorate_badge())
		# Misafir (vardiya açık + temiz odada) — dokununca dürtülür (gizli müfettiş)
		if Game.shift_active() and not is_dirty:
			var g_idx := idx % 3
			var guest := TextureButton.new()
			guest.texture_normal = _tex("res://assets/guests/guest_%s.svg" % ["a", "b", "c"][g_idx])
			guest.ignore_texture_size = true
			guest.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			guest.custom_minimum_size = Vector2(44, 44)
			guest.mouse_filter = Control.MOUSE_FILTER_STOP
			guest.pressed.connect(func(): _on_guest_poked(guest))
			strip.add_child(guest)
			_animate_guest(guest, idx, false)
	else:
		# Temizlik odasında vardiya boyunca hizmetçi çalışır
		if room.type == "housekeeping" and Game.shift_active():
			var maid := _icon("res://assets/guests/maid.svg", 44)
			maid.anchor_left = 0.12
			maid.anchor_right = 0.12
			maid.anchor_top = 1.0
			maid.anchor_bottom = 1.0
			maid.offset_left = -22
			maid.offset_right = 22
			maid.offset_top = -60
			maid.offset_bottom = -14
			b.add_child(maid)
			_animate_guest(maid, idx, false)
		# Tesis kapasitesi: vardiyada içerideki müşteriler görünür
		if cat == "facility" and Game.shift_active():
			var cap_row := HBoxContainer.new()
			cap_row.add_theme_constant_override("separation", 1)
			cap_row.anchor_top = 1.0
			cap_row.anchor_bottom = 1.0
			cap_row.offset_top = -44
			cap_row.offset_bottom = -14
			cap_row.offset_left = 4
			cap_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(cap_row)
			for ci in int(d.get("capacity", 0)):
				var cg := _icon("res://assets/guests/guest_%s.svg" % ["a", "b", "c"][(idx + ci) % 3], 26)
				cap_row.add_child(cg)
				_animate_guest(cg, idx + ci, false)
		var art := _icon("res://assets/rooms/%s.svg" % room.type, 64)
		art.anchor_left = 0.5
		art.anchor_right = 0.5
		art.anchor_top = 1.0
		art.anchor_bottom = 1.0
		art.offset_left = -44
		art.offset_right = 44
		art.offset_top = -76
		art.offset_bottom = -14
		art.custom_minimum_size = Vector2.ZERO
		b.add_child(art)

	# Kirli göstergesi (istilada hamamböceği)
	if is_dirty:
		var dust := _icon("res://assets/ui/roach.svg" if is_infested else "res://assets/ui/dust.svg", 52)
		dust.anchor_left = 0.5
		dust.anchor_right = 0.5
		dust.anchor_top = 0.5
		dust.anchor_bottom = 0.5
		dust.offset_left = -28
		dust.offset_right = 28
		dust.offset_top = -30
		dust.offset_bottom = 12
		dust.custom_minimum_size = Vector2.ZERO
		b.add_child(dust)

	# İsim bandı
	var plate := PanelContainer.new()
	var psb := StyleBoxFlat.new()
	psb.bg_color = PALETTE.banner_red if cat == "guest" else PALETTE.green_deep
	psb.set_corner_radius_all(4)
	psb.content_margin_left = 6
	psb.content_margin_right = 6
	psb.content_margin_top = 1
	psb.content_margin_bottom = 1
	plate.add_theme_stylebox_override("panel", psb)
	plate.position = Vector2(4, 4)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var plate_text: String = d.name
	if is_infested:
		plate_text = "İSTİLA! %d c" % int(Game.eco.infest.clean_cost)
	elif is_dirty:
		plate_text = "KİRLİ!"
	elif cat == "guest":
		plate_text = "%s · SP %d" % [Game.tier_name(Game.room_tier(room)), Game.room_score(room)]
	var pl := _label(plate_text, 11, PALETTE.cream_text)
	pl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(pl)
	b.add_child(plate)

	# Oda metresi (Hotel City): kademe ilerlemesi kırmızıdan yeşile dolar,
	# tavan kademede tam yeşil kalır.
	if cat == "guest" and not is_dirty:
		var score := Game.room_score(room)
		var t := Game.room_tier(room)
		var frac := 1.0
		if t < Game.eco.tier_thresholds.size() - 1:
			var lo := int(Game.eco.tier_thresholds[t])
			var hi := int(Game.eco.tier_thresholds[t + 1])
			frac = clampf(float(score - lo) / float(hi - lo), 0.0, 1.0)
		var meter_bg := ColorRect.new()
		meter_bg.color = Color(0, 0, 0, 0.3)
		meter_bg.position = Vector2(4, 23)
		meter_bg.size = Vector2(58, 7)
		meter_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(meter_bg)
		var meter := ColorRect.new()
		meter.color = Color(0.16, 0.62, 0.29) if frac >= 1.0 \
			else Color(0.85 - 0.55 * frac, 0.3 + 0.45 * frac, 0.18)
		meter.position = Vector2(5, 24)
		meter.size = Vector2(maxf(2.0, 56.0 * frac), 5)
		meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(meter)

	return b


## Boş misafir odasının sağ üstünde yanıp sönen altın "Dekore et!" rozeti.
func _make_decorate_badge() -> Control:
	var badge := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PALETTE.gold
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	sb.border_color = PALETTE.wood_dark
	sb.set_border_width_all(1)
	badge.add_theme_stylebox_override("panel", sb)
	badge.anchor_left = 1.0
	badge.anchor_right = 1.0
	badge.offset_left = -84
	badge.offset_right = -4
	badge.offset_top = 4
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := _label("✦ Dekore et!", 11, PALETTE.text)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(l)
	var tw := badge.create_tween().set_loops()
	tw.tween_property(badge, "modulate:a", 0.55, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(badge, "modulate:a", 1.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return badge


func _on_room_tapped(idx: int, btn: Control) -> void:
	# Taşıma modu: hedef odaya dokununca yer değiştir, aynı odaya dokununca iptal
	if move_from >= 0:
		var from := move_from
		move_from = -1
		if from == idx:
			_show_toast("Taşıma iptal edildi")
		elif Game.move_room(from, idx):
			_play("buy")
			_show_toast("Odalar yer değiştirdi")
		return
	var room: Dictionary = Game.rooms[idx]
	if room.dirty:
		# Buton yeniden kurulumda yok olacağı için merkezi temizlemeden önce al
		var center := btn.global_position + btn.size / 2.0
		var cost := Game.clean_cost(idx)
		if Game.clean_room(idx):
			_play("clean")
			_spawn_clean_anim(center)
			if cost > 0:
				_show_toast("İstila temizlendi! (−%d coin, +2 XP)" % cost)
			else:
				_show_toast("Oda temizlendi (+2 XP)")
		elif cost > 0:
			_show_toast("İstila temizliği için %d coin gerek!" % cost)
		return
	selected_room = idx
	if Game.room_def(room.type).category == "guest":
		_open_popup("Oda Dekorasyonu", _build_room_popup)
	else:
		_open_popup("Tesis", _build_facility_popup)


## Uyuyan misafiri dürtme: Hotel City'deki gizli müfettiş şansı.
func _on_guest_poked(btn: Control) -> void:
	if Game.pokes_left() <= 0:
		_play("tap")
		_show_toast("Bugünlük dürtme hakkın bitti — yarın yine dene!")
		return
	var center := btn.global_position + btn.size / 2.0
	var bonus := Game.poke_guest()
	if bonus > 0:
		_play("collect")
		_spawn_sparkles(center)
		_show_toast("Gizli müfettiş çıktı! +%d coin (kalan hak: %d)" % [bonus, Game.pokes_left()])
	else:
		_play("tap")
		_show_toast("Misafir esnedi, uyumaya devam etti… (kalan hak: %d)" % Game.pokes_left())


func _on_collect() -> void:
	var from := collect_button.global_position + collect_button.size / 2.0
	var got := Game.collect()
	if got > 0:
		_play("collect")
		_fly_coins(from, got)
		_show_toast("+%s coin toplandı" % _fmt(got))


## Misafir canlandırması: kuyruktakiler paytak yürür, odadakiler kıpırdanır.
## Container yerleşimine dokunmamak için yalnızca rotation/scale kullanılır;
## tween misafir düğümüne bağlıdır, düğüm silinince kendiliğinden ölür.
func _animate_guest(g: Control, seed_i: int, walking: bool) -> void:
	g.pivot_offset = Vector2(g.custom_minimum_size.x / 2.0, g.custom_minimum_size.y)
	var dur := 0.32 + 0.06 * (seed_i % 4)
	var tw := g.create_tween().set_loops()
	if walking:
		tw.tween_property(g, "rotation", 0.09, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(g, "rotation", -0.09, dur * 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(g, "rotation", 0.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		tw.tween_property(g, "scale", Vector2(1.04, 0.95), dur * 2.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(g, "scale", Vector2.ONE, dur * 2.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Vardiya açılış sahnesi: misafirler sağ kenardan sokak boyunca kapıya
## yürür, kapıda küçülerek içeri girer. Overlay olduğu için yerleşimi bozmaz.
func _guest_walk_in() -> void:
	await get_tree().process_frame  # yeni yerleşim otursun
	if street_node == null or not is_instance_valid(street_node):
		return
	var walk_y := street_node.global_position.y - 26.0
	var door_x := size.x / 2.0
	for i in 4:
		var gicon := _icon("res://assets/guests/guest_%s.svg" % ["a", "b", "c"][i % 3], 36)
		gicon.position = Vector2(size.x + 24.0 + i * 34.0, walk_y)
		gicon.pivot_offset = Vector2(18, 36)
		gicon.z_index = 55
		add_child(gicon)
		_animate_guest(gicon, i, true)
		var tw := gicon.create_tween()
		tw.tween_property(gicon, "position:x", door_x, 1.5 + i * 0.18) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(gicon, "scale", Vector2(0.3, 0.3), 0.25)
		tw.parallel().tween_property(gicon, "modulate:a", 0.0, 0.25)
		tw.tween_callback(gicon.queue_free)


## Temizlik geri bildirimi: önce süpürge sağa sola süpürür, ardından parıltılar.
func _spawn_clean_anim(center: Vector2) -> void:
	var broom := _icon("res://assets/ui/broom.svg", 48)
	broom.position = center + Vector2(-24.0, -34.0)
	broom.pivot_offset = Vector2(24, 44)
	broom.z_index = 61
	add_child(broom)
	var tw := create_tween()
	for i in 3:
		tw.tween_property(broom, "rotation", 0.45, 0.11).set_trans(Tween.TRANS_SINE)
		tw.tween_property(broom, "rotation", -0.45, 0.11).set_trans(Tween.TRANS_SINE)
	tw.tween_property(broom, "modulate:a", 0.0, 0.18)
	tw.tween_callback(broom.queue_free)
	get_tree().create_timer(0.5).timeout.connect(func(): _spawn_sparkles(center))


## Oda üzerinde büyüyüp sönen altın parıltılar.
func _spawn_sparkles(center: Vector2) -> void:
	for i in 7:
		var s := _icon("res://assets/ui/sparkle.svg", 22)
		s.position = center + Vector2(randf_range(-46.0, 46.0), randf_range(-40.0, 28.0))
		s.pivot_offset = Vector2(11, 11)
		s.scale = Vector2.ZERO
		s.z_index = 60
		add_child(s)
		var tw := create_tween()
		tw.tween_interval(i * 0.05)
		tw.tween_property(s, "scale", Vector2.ONE * randf_range(0.8, 1.5), 0.2) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(s, "rotation", randf_range(-0.7, 0.7), 0.4)
		tw.tween_property(s, "modulate:a", 0.0, 0.3)
		tw.tween_callback(s.queue_free)


## Toplama geri bildirimi: kasadan coin sayacına uçan coin'ler.
func _fly_coins(from: Vector2, amount: int) -> void:
	var to := coins_label.global_position + coins_label.size / 2.0
	var count := clampi(3 + amount / 200, 4, 10)
	for i in count:
		var cn := _icon("res://assets/ui/coin.svg", 24)
		cn.position = from + Vector2(randf_range(-40.0, 40.0), randf_range(-12.0, 12.0))
		cn.z_index = 60
		add_child(cn)
		var tw := create_tween()
		tw.tween_interval(i * 0.045)
		tw.tween_property(cn, "position", to, 0.45) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(cn, "modulate:a", 0.55, 0.45)
		tw.tween_callback(cn.queue_free)


func _cycle_speed() -> void:
	speed_index = (speed_index + 1) % SPEEDS.size()
	Game.simulate_to(Game.now())
	var remaining_real := maxf(0.0, Game.shift_end_unix - Game.now())
	Game.shift_end_unix = Game.now() + remaining_real * Game.time_scale / SPEEDS[speed_index]
	Game.time_scale = SPEEDS[speed_index]
	_refresh()


# --- Popuplar ----------------------------------------------------------

func _open_popup(title: String, builder: Callable) -> void:
	_play("tap")
	popup_title.text = title
	popup_builder = builder
	overlay.visible = true
	_rebuild_popup()


func _close_popup() -> void:
	overlay.visible = false
	popup_builder = Callable()
	selected_room = -1


func _rebuild_popup() -> void:
	for c in popup_content.get_children():
		popup_content.remove_child(c)
		c.queue_free()
	popup_builder.call(popup_content)


func _build_shift_popup(c: VBoxContainer) -> void:
	if Game.shift_active():
		c.add_child(_label("Vardiya sürüyor — bitimine %s." % _fmt_hms(Game.shift_remaining_game_hours()), 16, PALETTE.text))
		c.add_child(_label("Birikimi istediğin an toplayabilirsin.", 14, PALETTE.muted))
		var gem_cost := Game.skip_shift_gem_cost()
		var skip_b := _button("Elmasla şimdi bitir — %d elmas" % gem_cost, 15, PALETTE.green_deep, PALETTE.cream_text)
		skip_b.disabled = Game.gems < gem_cost
		skip_b.pressed.connect(func():
			if Game.skip_shift():
				_play("buy")
				_show_toast("Vardiya elmasla tamamlandı — birikim kasada!")
				_close_popup())
		c.add_child(skip_b)
		return
	c.add_child(_label("Süre seç — saatlik maliyet hepsinde aynıdır:", 14, PALETTE.muted))
	for hours: int in [1, 4, 8, 24]:
		var cost := Game.shift_cost(hours)
		var est: float = Game.hourly_income() * hours
		var b := _button("%d saat — maliyet %s · tahmini gelir ~%s" % [hours, _fmt(cost), _fmt(int(est))], 15, PALETTE.wood, PALETTE.cream_text)
		b.disabled = Game.coins < cost
		b.pressed.connect(func():
			if Game.start_shift(hours):
				_play("shift")
				_guest_walk_in()
				_show_toast("%d saatlik vardiya başladı!" % hours)
				_close_popup())
		c.add_child(b)
	if Game.auto_renew_shift:
		c.add_child(_label("Otomatik yenileme açık: vardiya bitince coin yeterse kendiliğinden devam eder.", 12, PALETTE.green_deep))
	else:
		c.add_child(_label("Otomatik yenileme kapalı: vardiya bitince elle yeniden başlatman gerekir (Ayarlar).", 12, PALETTE.muted))
	c.add_child(_label("Not: temizlenmeyen odalar gelir üretmez. Uzun vardiyada Temizlik Odası şart!", 13, PALETTE.banner_red))


func _build_shop_popup(c: VBoxContainer) -> void:
	var lv := Game.level()
	var free_slots := Game.max_slots() - Game.rooms.size()
	c.add_child(_label("Boş yuva: %d — oda satın al:" % free_slots, 14, PALETTE.muted))
	for type in Game.eco.room_types:
		var d: Dictionary = Game.eco.room_types[type]
		var cat: String = d.category
		var desc := ""
		if cat == "guest":
			desc = "%d coin/saat taban" % int(d.base_income)
		elif cat == "facility":
			desc = "+%d coin/saat · yıldıza katkı" % int(d.base_income)
		else:
			desc = "odaları otomatik temizler"
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		c.add_child(row)
		if cat != "guest":
			row.add_child(_icon("res://assets/rooms/%s.svg" % type, 40))
		var b := _button("%s — %s coin\n%s" % [d.name, _fmt(int(d.price)), desc], 14, PALETTE.wood, PALETTE.cream_text)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if lv < int(d.unlock_level):
			b.text = "%s — Seviye %d'de açılır" % [d.name, int(d.unlock_level)]
			b.disabled = true
		else:
			b.disabled = not Game.can_buy_room(type)
			var t: String = type
			b.pressed.connect(func():
				if Game.buy_room(t):
					_play("buy")
					_show_toast("%s satın alındı!" % Game.room_def(t).name))
		row.add_child(b)
	if Game.floors < int(Game.eco.building.max_floors):
		var fb := _button("Yeni kat aç — %s coin (+%d yuva)" % [_fmt(Game.floor_price()), int(Game.eco.building.slots_per_floor)], 14, PALETTE.wood_dark, PALETTE.cream_text)
		fb.disabled = not Game.can_buy_floor()
		fb.pressed.connect(func():
			if Game.buy_floor():
				_show_toast("Yeni kat açıldı!"))
		c.add_child(fb)


func _build_room_popup(c: VBoxContainer) -> void:
	if selected_room < 0 or selected_room >= Game.rooms.size():
		return
	var room: Dictionary = Game.rooms[selected_room]
	var tier := Game.room_tier(room)
	c.add_child(_label("%s — %s · SP %d · %d eşya" % [
		Game.room_def(room.type).name, Game.tier_name(tier),
		Game.room_score(room), room.items.size()], 16, PALETTE.text))
	if tier < Game.eco.tier_names.size() - 1:
		var next_th := int(Game.eco.tier_thresholds[tier + 1])
		c.add_child(_label("Sonraki kademe (%s): SP %d gerekir" % [Game.tier_name(tier + 1), next_th], 13, PALETTE.wood_dark))

	# Hazır dekor paketleri: tek dokunuşla, tek tek almaktan ucuz
	var bundles: Array = Game.eco.get("bundles", [])
	if not bundles.is_empty():
		c.add_child(_label("Hazır paketler — tek dokunuşla dekor:", 14, PALETTE.muted))
		for bd in bundles:
			var sp_total := 0
			for iid in bd.items:
				sp_total += int(Game.item_def(iid).sp)
			var pb := _button("%s — SP +%d — %s coin (%%%d indirimli)" % [
				bd.name, sp_total, _fmt(Game.bundle_price(bd)), int(float(bd.discount) * 100.0)],
				14, PALETTE.green_deep, PALETTE.cream_text)
			var need_lv := Game.bundle_unlock_level(bd)
			if Game.level() < need_lv:
				pb.text = "%s — Seviye %d'de açılır" % [bd.name, need_lv]
				pb.disabled = true
			else:
				pb.disabled = not Game.can_buy_bundle(bd)
				var bid: String = bd.id
				pb.pressed.connect(func():
					if Game.buy_bundle(selected_room, bid):
						_play("buy")
						_show_toast("%s yerleştirildi!" % Game.bundle_def(bid).name))
			c.add_child(pb)

	c.add_child(_label("Eşya ekle:", 14, PALETTE.muted))
	var lv := Game.level()
	for it in Game.eco.items:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		c.add_child(row)
		row.add_child(_icon("res://assets/items/%s.svg" % it.id, 40))
		var price_text: String = "%d elmas ◆" % int(it.get("gem_price", 0)) if Game.item_is_premium(it) else "%s coin" % _fmt(int(it.price))
		var b := _button("%s — SP +%d — %s" % [it.name, int(it.sp), price_text], 14,
			PALETTE.green_deep if Game.item_is_premium(it) else PALETTE.wood, PALETTE.cream_text)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if lv < int(it.get("unlock_level", 1)):
			b.text = "%s — Seviye %d'de açılır" % [it.name, int(it.unlock_level)]
			b.disabled = true
		else:
			b.disabled = not Game.can_afford_item(it)
			var iid: String = it.id
			b.pressed.connect(func():
				if Game.buy_item(selected_room, iid):
					_play("buy")
					_show_toast("%s yerleştirildi (+%d SP)" % [Game.item_def(iid).name, int(Game.item_def(iid).sp)]))
		row.add_child(b)
	_add_manage_buttons(c)


func _build_facility_popup(c: VBoxContainer) -> void:
	if selected_room < 0 or selected_room >= Game.rooms.size():
		return
	var room: Dictionary = Game.rooms[selected_room]
	var d: Dictionary = Game.room_def(room.type)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	c.add_child(row)
	row.add_child(_icon("res://assets/rooms/%s.svg" % room.type, 48))
	row.add_child(_label(String(d.name), 17, PALETTE.text))
	if d.category == "facility":
		c.add_child(_label("Saatlik +%d coin taban gelir · yıldız çeşitliliğine katkı" % int(d.base_income), 13, PALETTE.muted))
	else:
		c.add_child(_label("Kirlenen odaları kendiliğinden temizler — gelir hiç durmaz.", 13, PALETTE.muted))
	_add_manage_buttons(c)


## Oda popup'larının ortak yönetim satırı: Taşı + onaylı Sat.
func _add_manage_buttons(c: VBoxContainer) -> void:
	c.add_child(_spacer_y(6))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	c.add_child(row)
	var ridx := selected_room
	var mv := _button("Taşı", 14, PALETTE.wood_dark, PALETTE.cream_text)
	mv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mv.pressed.connect(func():
		move_from = ridx
		_close_popup()
		_show_toast("Hedef odaya dokun — iptal için aynı odaya dokun"))
	row.add_child(mv)
	var sell_text := "Sat — +%s coin" % _fmt(Game.room_sell_value(ridx))
	var sell_gems := Game.room_sell_gem_value(ridx)
	if sell_gems > 0:
		sell_text += " +%d elmas" % sell_gems
	var sl := _button(sell_text, 14, PALETTE.banner_red, PALETTE.cream_text)
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.pressed.connect(func():
		if not sl.get_meta("armed", false):
			sl.set_meta("armed", true)
			sl.text = "Emin misin? Satmak için tekrar dokun"
			return
		if Game.sell_room(ridx):
			_play("buy")
			_close_popup()
			_show_toast("Oda satıldı — iade kasada")
		else:
			_show_toast("Son oda satılamaz!"))
	row.add_child(sl)


func _build_stats_popup(c: VBoxContainer) -> void:
	var rows := [
		["Toplam toplanan gelir", "%s coin" % _fmt(Game.stat_collected_total)],
		["Toplama sayısı", str(Game.stat_collects)],
		["Temizlenen oda", str(Game.stat_cleans)],
		["Başlatılan vardiya", str(Game.stat_shifts)],
		["Oda sayısı", "%d / %d yuva" % [Game.rooms.size(), Game.max_slots()]],
		["Tesis çeşitliliği", "%d / 5" % Game.facility_diversity()],
		["Yıldız derecesi", "%d / 5" % Game.star_rating()],
		["Seviye", "%d (XP %s)" % [Game.level(), _fmt(Game.xp)]],
		["Saatlik gelir (şu an)", "%.0f coin" % Game.hourly_income()],
		["Prestij çarpanı", "×%.2f (devir %d)" % [Game.prestige_mult(), Game.prestige_level]],
		["Günlük giriş serisi", "%d gün" % Game.daily_streak],
	]
	for r in rows:
		var row := HBoxContainer.new()
		c.add_child(row)
		var ll := _label(String(r[0]), 14, PALETTE.muted)
		ll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(ll)
		row.add_child(_label(String(r[1]), 14, PALETTE.text))
	c.add_child(_spacer_y(6))
	c.add_child(_label("Vardiya geçmişi (son %d):" % Game.shift_history.size(), 14, PALETTE.wood_dark))
	if Game.shift_history.is_empty():
		c.add_child(_label("Henüz vardiya başlatılmadı.", 13, PALETTE.muted))
		return
	var bias: int = int(Time.get_time_zone_from_system().bias) * 60
	for i in range(Game.shift_history.size() - 1, -1, -1):
		var h: Dictionary = Game.shift_history[i]
		var dt := Time.get_datetime_dict_from_unix_time(int(float(h.at)) + bias)
		c.add_child(_label("%02d.%02d %02d:%02d — %d saat · maliyet %s coin" % [
			dt.day, dt.month, dt.hour, dt.minute, int(h.hours), _fmt(int(h.cost))], 13, PALETTE.text))


func _build_settings_popup(c: VBoxContainer) -> void:
	var s_b := _button("Ses efektleri: %s" % ("Açık" if Game.sound_on else "Kapalı"), 15,
		PALETTE.wood if Game.sound_on else PALETTE.wood_dark, PALETTE.cream_text)
	s_b.pressed.connect(func():
		Game.sound_on = not Game.sound_on
		Game.save_game()
		_play("tap")
		_rebuild_popup())
	c.add_child(s_b)

	var m_b := _button("Lobi müziği: %s" % ("Açık" if Game.music_on else "Kapalı"), 15,
		PALETTE.wood if Game.music_on else PALETTE.wood_dark, PALETTE.cream_text)
	m_b.pressed.connect(func():
		Game.music_on = not Game.music_on
		music_player.playing = Game.music_on
		Game.save_game()
		_rebuild_popup())
	c.add_child(m_b)

	var ar_b := _button("Vardiya otomatik yenilensin: %s" % ("Açık" if Game.auto_renew_shift else "Kapalı"), 15,
		PALETTE.wood if Game.auto_renew_shift else PALETTE.wood_dark, PALETTE.cream_text)
	ar_b.pressed.connect(func():
		Game.auto_renew_shift = not Game.auto_renew_shift
		Game.save_game()
		_play("tap")
		_rebuild_popup())
	c.add_child(ar_b)
	c.add_child(_label("Açıkken bir vardiya bitince, coin yeterse aynı süreyle otomatik yenilenir — otel sen yokken de üretime devam eder.", 12, PALETTE.muted))

	c.add_child(_spacer_y(10))
	c.add_child(_label("Prestij — çarpan ×%.2f (devir %d)" % [Game.prestige_mult(), Game.prestige_level], 15, PALETTE.wood_dark))
	if Game.can_prestige():
		var next_mult: float = Game.prestige_mult() + float(Game.eco.prestige.mult_gain)
		var p_b := _button("Oteli devret — yeni çarpan ×%.2f" % next_mult, 15, PALETTE.green_deep, PALETTE.cream_text)
		p_b.pressed.connect(func():
			if p_b.get_meta("armed", false):
				Game.do_prestige()
				_close_popup()
				_show_toast("Devrettin! Yeni gelir çarpanı: ×%.2f" % Game.prestige_mult())
			else:
				p_b.set_meta("armed", true)
				p_b.text = "Emin misin? İlerleme sıfırlanacak, tekrar dokun")
		c.add_child(p_b)
		c.add_child(_label("Devretmek coin, oda, görev ve başarım ilerlemeni sıfırlar; çarpan kalıcıdır.", 12, PALETTE.muted))
	else:
		c.add_child(_label("Devretmek için Seviye %d gerekir (şu an %d)." % [int(Game.eco.prestige.min_level), Game.level()], 13, PALETTE.muted))

	c.add_child(_spacer_y(10))
	c.add_child(_label("Kaydı taşı — bulut yerine paylaşılabilir kod:", 15, PALETTE.wood_dark))
	var export_code := Game.export_save_code()
	var export_field := LineEdit.new()
	export_field.text = export_code
	export_field.editable = false
	c.add_child(export_field)
	var copy_b := _button("Kodu panoya kopyala", 14, PALETTE.wood, PALETTE.cream_text)
	copy_b.pressed.connect(func():
		DisplayServer.clipboard_set(export_code)
		_show_toast("Kayıt kodu panoya kopyalandı"))
	c.add_child(copy_b)

	c.add_child(_spacer_y(6))
	c.add_child(_label("Başka bir kaydı içe aktar:", 14, PALETTE.text))
	var import_field := LineEdit.new()
	import_field.placeholder_text = "Kayıt kodunu buraya yapıştır…"
	c.add_child(import_field)
	var import_b := _button("İçe aktar — mevcut kaydın üzerine yazar", 14, PALETTE.banner_red, PALETTE.cream_text)
	import_b.pressed.connect(func():
		if not import_b.get_meta("armed", false):
			import_b.set_meta("armed", true)
			import_b.text = "Emin misin? Üzerine yazmak için tekrar dokun"
			return
		if Game.import_save_code(import_field.text):
			Game.save_game()
			_close_popup()
			_show_toast("Kayıt içe aktarıldı!")
		else:
			_show_toast("Kod geçersiz — kontrol edip tekrar dene"))
	c.add_child(import_b)

	c.add_child(_spacer_y(8))
	c.add_child(_label("Tehlikeli bölge:", 13, PALETTE.banner_red))
	var r_b := _button("Kaydı sıfırla", 15, PALETTE.banner_red, PALETTE.cream_text)
	r_b.pressed.connect(func():
		if r_b.get_meta("armed", false):
			Game.reset_game()
			_close_popup()
			_show_toast("Kayıt sıfırlandı — yeni oyun başladı!")
		else:
			r_b.set_meta("armed", true)
			r_b.text = "Emin misin? Silmek için tekrar dokun")
	c.add_child(r_b)
	c.add_child(_label("Sıfırlama tüm ilerlemeyi kalıcı olarak siler.", 12, PALETTE.muted))


func _build_quests_popup(c: VBoxContainer) -> void:
	var q: Dictionary = Game.current_quest()
	if q.is_empty():
		c.add_child(_label("Tüm görevler tamamlandı. Tebrikler, otelci!", 16, PALETTE.green_deep))
	else:
		var p: Array = Game.quest_progress(q)
		c.add_child(_label(String(q.name), 19, PALETTE.wood_dark))
		var desc := _label(String(q.desc), 15, PALETTE.text)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		c.add_child(desc)
		c.add_child(_label("İlerleme: %d / %d" % [mini(p[0], p[1]), p[1]], 14, PALETTE.muted))
		var reward := "Ödül: %s coin" % _fmt(int(q.get("reward_coins", 0)))
		if int(q.get("reward_gems", 0)) > 0:
			reward += " + %d elmas" % int(q.reward_gems)
		c.add_child(_label(reward, 14, PALETTE.green_deep))
	c.add_child(_label("Tamamlanan görev: %d / %d" % [Game.quest_index, Game.quests.size()], 13, PALETTE.muted))

	c.add_child(_spacer_y(10))
	c.add_child(_label("Başarımlar — %d / %d açıldı" % [Game.unlocked_achievements.size(), Game.achievements.size()], 16, PALETTE.wood_dark))
	for a: Dictionary in Game.achievements:
		var unlocked: bool = Game.unlocked_achievements.has(String(a.id))
		var p: Array = Game.quest_progress(a)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		c.add_child(row)
		var mark := _label("✓" if unlocked else "•", 15, PALETTE.green_deep if unlocked else PALETTE.muted)
		mark.custom_minimum_size = Vector2(18, 0)
		row.add_child(mark)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		col.add_child(_label(String(a.name), 14, PALETTE.text if unlocked else PALETTE.muted))
		if not unlocked:
			col.add_child(_label("%s — %d / %d" % [String(a.desc), mini(p[0], p[1]), p[1]], 12, PALETTE.muted))


# --- Geri bildirim -----------------------------------------------------

func _on_quest_completed(q: Dictionary) -> void:
	_play("quest")
	var msg := "Görev tamam: %s — +%s coin" % [q.name, _fmt(int(q.get("reward_coins", 0)))]
	if int(q.get("reward_gems", 0)) > 0:
		msg += ", +%d elmas" % int(q.reward_gems)
	_show_toast(msg)


func _on_achievement_unlocked(a: Dictionary) -> void:
	_play("quest")
	var msg := "Başarım açıldı: %s — +%s coin" % [a.name, _fmt(int(a.get("reward_coins", 0)))]
	if int(a.get("reward_gems", 0)) > 0:
		msg += ", +%d elmas" % int(a.reward_gems)
	_show_toast(msg)


func _show_toast(msg: String) -> void:
	toast_label.text = msg
	toast_panel.visible = true
	_toast_timer = 3.0


func _show_offline_popup(amount: int, renew_count: int = 0, renew_spent: int = 0) -> void:
	var dlg := AcceptDialog.new()
	dlg.title = "Hoş geldin!"
	var text := ""
	if amount > 0:
		text += "Sen yokken otelin çalıştı ve %s coin birikti.\nKasadan toplamayı unutma!" % _fmt(amount)
	if renew_count > 0:
		if not text.is_empty():
			text += "\n\n"
		text += "Vardiyan bitince otel boş durmadı: %d kez otomatik yenilendi (personel maliyeti %s coin)." % [renew_count, _fmt(renew_spent)]
	dlg.dialog_text = text
	dlg.ok_button_text = "Harika"
	add_child(dlg)
	dlg.popup_centered()


## Uygulama açılışında (bugün henüz alınmadıysa) otomatik gösterilen günlük
## ödül popup'ı. on_closed, popup ne şekilde kapanırsa kapansın (Al ya da
## X/ESC) çağrılır — böylece "Hoş geldin" popup'ı üst üste binmeden sırayla açılır.
func _show_daily_reward_popup(on_closed: Callable = Callable()) -> void:
	var streak: int = Game.daily_next_streak()
	var cycle: Array = Game.eco.get("daily_rewards", [])
	if cycle.is_empty():
		if on_closed.is_valid():
			on_closed.call()
		return
	var reward: Dictionary = cycle[(streak - 1) % cycle.size()]
	var reward_text := "%s coin" % _fmt(int(reward.get("coins", 0)))
	if int(reward.get("gems", 0)) > 0:
		reward_text += " + %d elmas" % int(reward.gems)
	var dlg := AcceptDialog.new()
	dlg.title = "Günlük Ödül"
	dlg.dialog_text = "%d. gün serisi!\nÖdülün: %s" % [streak, reward_text]
	dlg.ok_button_text = "Al"
	dlg.confirmed.connect(func():
		var granted := Game.claim_daily_reward()
		if not granted.is_empty():
			_play("quest")
			_show_toast("Günlük ödül alındı — gün %d serisi!" % Game.daily_streak))
	dlg.visibility_changed.connect(func():
		if dlg.visible:
			return
		dlg.queue_free()
		if on_closed.is_valid():
			on_closed.call())
	add_child(dlg)
	dlg.popup_centered()


func _fmt_hms(game_hours: float) -> String:
	var total := int(game_hours * 3600.0)
	return "%02d:%02d:%02d" % [total / 3600, (total % 3600) / 60, total % 60]


func _fmt(n: int) -> String:
	var s := str(n)
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "." + out
	return out
