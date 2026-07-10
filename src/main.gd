extends Control
## Little Grand Hotel — arayüz (MVP). Tamamen koddan kurulur.
## Kesit "dollhouse" görünüm: katlar üst üste, her katta 4 oda yuvası.

const PALETTE := {
	"bg": Color("15201c"),
	"panel": Color("1f2e27"),
	"panel2": Color("28382f"),
	"line": Color("3a4c43"),
	"text": Color("eceae2"),
	"muted": Color("9faca4"),
	"brass": Color("d9b25e"),
	"green": Color("7fc79e"),
	"red": Color("e07a5f"),
	"guest": Color("2e4a3d"),
	"guest_hi": Color("3a5d4d"),
	"facility": Color("3d3a55"),
	"functional": Color("4a3b2f"),
	"dirty": Color("6e372c"),
	"locked": Color("1a2420"),
}

const SPEEDS: Array[float] = [1.0, 60.0, 3600.0]
var speed_index := 0

var coins_label: Label
var gems_label: Label
var star_label: Label
var level_label: Label
var xp_bar: ProgressBar
var shift_label: Label
var collect_button: Button
var hotel_box: VBoxContainer
var quest_hint: Label
var toast_label: Label

var overlay: Control
var popup_title: Label
var popup_content: VBoxContainer
var popup_builder: Callable = Callable()

var selected_room := -1
var _toast_timer := 0.0


func _ready() -> void:
	_build_ui()
	Game.state_changed.connect(_refresh)
	Game.quest_completed.connect(_on_quest_completed)
	Game.leveled_up.connect(func(lv): _show_toast("Seviye atladın! Seviye %d (+%d elmas)" % [lv, int(Game.eco.levelup_gems)]))
	_refresh()
	if Game.offline_earned > 0:
		_show_offline_popup(Game.offline_earned)
		Game.offline_earned = 0


func _process(delta: float) -> void:
	_update_live_labels()
	if _toast_timer > 0.0:
		_toast_timer -= delta
		if _toast_timer <= 0.0:
			toast_label.visible = false


# --- Kurulum -----------------------------------------------------------

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = PALETTE.bg
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	# --- Üst bar
	var top := _panel()
	root.add_child(top)
	var top_box := VBoxContainer.new()
	top_box.add_theme_constant_override("separation", 4)
	top.add_child(top_box)

	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 16)
	top_box.add_child(row1)
	coins_label = _label("", 22, PALETTE.brass)
	gems_label = _label("", 22, PALETTE.green)
	star_label = _label("", 22, PALETTE.text)
	row1.add_child(coins_label)
	row1.add_child(gems_label)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row1.add_child(sp)
	row1.add_child(star_label)

	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 12)
	top_box.add_child(row2)
	level_label = _label("", 16, PALETTE.muted)
	row2.add_child(level_label)
	xp_bar = ProgressBar.new()
	xp_bar.show_percentage = false
	xp_bar.custom_minimum_size = Vector2(0, 10)
	xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row2.add_child(xp_bar)

	# --- Vardiya durumu + topla
	shift_label = _label("", 16, PALETTE.muted)
	root.add_child(shift_label)

	collect_button = _button("", 24)
	collect_button.custom_minimum_size = Vector2(0, 64)
	collect_button.pressed.connect(_on_collect)
	root.add_child(collect_button)

	# --- Görev ipucu
	quest_hint = _label("", 15, PALETTE.brass)
	quest_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(quest_hint)

	# --- Otel görünümü
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	hotel_box = VBoxContainer.new()
	hotel_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hotel_box.add_theme_constant_override("separation", 8)
	scroll.add_child(hotel_box)

	# --- Alt bar
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 8)
	root.add_child(bottom)
	for def in [
		["Vardiya", _build_shift_popup],
		["Mağaza", _build_shop_popup],
		["Görevler", _build_quests_popup],
	]:
		var b := _button(def[0], 18)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 56)
		var builder: Callable = def[1]
		var title: String = def[0]
		b.pressed.connect(func(): _open_popup(title, builder))
		bottom.add_child(b)
	var speed_b := _button("×1", 18)
	speed_b.custom_minimum_size = Vector2(72, 56)
	speed_b.pressed.connect(func():
		_cycle_speed()
		speed_b.text = "×%s" % ("1" if speed_index == 0 else ("60" if speed_index == 1 else "3600")))
	bottom.add_child(speed_b)

	# --- Toast
	toast_label = _label("", 17, PALETTE.text)
	toast_label.visible = false
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(toast_label)

	# --- Popup katmanı
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed:
			_close_popup())
	overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)
	var panel := _panel()
	panel.custom_minimum_size = Vector2(600, 0)
	center.add_child(panel)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 10)
	panel.add_child(pv)
	var head := HBoxContainer.new()
	pv.add_child(head)
	popup_title = _label("", 22, PALETTE.brass)
	popup_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(popup_title)
	var close_b := _button("Kapat", 16)
	close_b.pressed.connect(_close_popup)
	head.add_child(close_b)
	var pscroll := ScrollContainer.new()
	pscroll.custom_minimum_size = Vector2(0, 640)
	pv.add_child(pscroll)
	popup_content = VBoxContainer.new()
	popup_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	popup_content.add_theme_constant_override("separation", 8)
	pscroll.add_child(popup_content)


func _panel() -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PALETTE.panel
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(14)
	sb.border_color = PALETTE.line
	sb.set_border_width_all(1)
	p.add_theme_stylebox_override("panel", sb)
	return p


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _button(text: String, size: int, bgcolor: Color = PALETTE.panel2) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", PALETTE.text)
	b.add_theme_color_override("font_disabled_color", PALETTE.muted)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = bgcolor
		if state == "hover":
			sb.bg_color = bgcolor.lightened(0.08)
		elif state == "pressed":
			sb.bg_color = bgcolor.darkened(0.1)
		elif state == "disabled":
			sb.bg_color = bgcolor.darkened(0.25)
		sb.set_corner_radius_all(8)
		sb.set_content_margin_all(10)
		b.add_theme_stylebox_override(state, sb)
	return b


# --- Yenileme ----------------------------------------------------------

func _refresh() -> void:
	_update_live_labels()
	_rebuild_hotel()
	if overlay.visible and popup_builder.is_valid():
		_rebuild_popup()


func _update_live_labels() -> void:
	coins_label.text = "%s coin" % _fmt(Game.coins)
	gems_label.text = "%d elmas" % Game.gems
	star_label.text = "Yıldız %d/5" % Game.star_rating()
	var lv := Game.level()
	level_label.text = "Seviye %d" % lv
	var cur_xp := Game.xp - Game.xp_for_level(lv)
	var need := Game.xp_for_level(lv + 1) - Game.xp_for_level(lv)
	xp_bar.max_value = need
	xp_bar.value = cur_xp
	if Game.shift_active():
		shift_label.text = "Vardiya açık · kalan %.1f oyun-saati · gelir %.0f coin/saat" % [
			Game.shift_remaining_game_hours(), Game.hourly_income()]
	else:
		shift_label.text = "Vardiya kapalı — otel gelir üretmiyor. Alttan vardiya başlat."
	collect_button.text = "TOPLA — %s coin" % _fmt(int(Game.pending_income))
	collect_button.disabled = int(Game.pending_income) <= 0


func _rebuild_hotel() -> void:
	for c in hotel_box.get_children():
		hotel_box.remove_child(c)
		c.queue_free()
	var spf := int(Game.eco.building.slots_per_floor)
	# Üst kat en üstte görünür
	for f: int in range(Game.floors, 0, -1):
		var row_panel := _panel()
		hotel_box.add_child(row_panel)
		var v := VBoxContainer.new()
		row_panel.add_child(v)
		v.add_child(_label("Kat %d" % f, 13, PALETTE.muted))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		v.add_child(row)
		for s in spf:
			var idx := (f - 1) * spf + s
			row.add_child(_make_slot(idx))
	# Yeni kat satırı
	if Game.floors < int(Game.eco.building.max_floors):
		var fb := _button("Yeni kat aç — %s coin" % _fmt(Game.floor_price()), 16, PALETTE.functional)
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
	var spf_total := Game.max_slots()
	if idx < Game.rooms.size():
		var room: Dictionary = Game.rooms[idx]
		var d: Dictionary = Game.room_def(room.type)
		var cat: String = d.category
		var color: Color = PALETTE.guest
		var line2 := ""
		if cat == "guest":
			color = PALETTE.dirty if room.dirty else PALETTE.guest
			line2 = "KİRLİ — dokun!" if room.dirty else "%s · SP %d" % [Game.tier_name(Game.room_tier(room)), Game.room_score(room)]
		elif cat == "facility":
			color = PALETTE.facility
			line2 = "+%d coin/saat" % int(d.base_income)
		else:
			color = PALETTE.functional
			line2 = "otomasyon"
		var b := _button("%s\n%s" % [d.name, line2], 14, color)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 84)
		b.pressed.connect(func(): _on_room_tapped(idx))
		return b
	elif idx == Game.rooms.size() and idx < spf_total:
		var b := _button("+\nOda ekle", 14, PALETTE.panel2)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 84)
		b.pressed.connect(func(): _open_popup("Mağaza", _build_shop_popup))
		return b
	else:
		var p := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = PALETTE.locked
		sb.set_corner_radius_all(8)
		p.add_theme_stylebox_override("panel", sb)
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p.custom_minimum_size = Vector2(0, 84)
		return p


func _on_room_tapped(idx: int) -> void:
	var room: Dictionary = Game.rooms[idx]
	if room.dirty:
		if Game.clean_room(idx):
			_show_toast("Oda temizlendi (+2 XP)")
		return
	if Game.room_def(room.type).category == "guest":
		selected_room = idx
		_open_popup("Oda Dekorasyonu", _build_room_popup)


func _on_collect() -> void:
	var got := Game.collect()
	if got > 0:
		_show_toast("+%s coin toplandı" % _fmt(got))


func _cycle_speed() -> void:
	speed_index = (speed_index + 1) % SPEEDS.size()
	Game.simulate_to(Game.now())
	var remaining_real := maxf(0.0, Game.shift_end_unix - Game.now())
	Game.shift_end_unix = Game.now() + remaining_real * Game.time_scale / SPEEDS[speed_index]
	Game.time_scale = SPEEDS[speed_index]
	_refresh()


# --- Popuplar ----------------------------------------------------------

func _open_popup(title: String, builder: Callable) -> void:
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
		c.add_child(_label("Vardiya sürüyor — kalan %.1f oyun-saati." % Game.shift_remaining_game_hours(), 17, PALETTE.text))
		c.add_child(_label("Birikimi istediğin an toplayabilirsin.", 15, PALETTE.muted))
		return
	c.add_child(_label("Süre seç — kısa vardiya saat başına daha ucuzdur:", 15, PALETTE.muted))
	for hours: int in [1, 4, 8, 24]:
		var cost := Game.shift_cost(hours)
		var est: float = Game.hourly_income() * hours
		var b := _button("%d saat — maliyet %s · tahmini gelir ~%s" % [hours, _fmt(cost), _fmt(int(est))], 16)
		b.disabled = Game.coins < cost
		b.pressed.connect(func():
			if Game.start_shift(hours):
				_show_toast("%d saatlik vardiya başladı!" % hours)
				_close_popup())
		c.add_child(b)
	c.add_child(_label("Not: temizlenmeyen odalar gelir üretmez. Uzun vardiyada Temizlik Odası şart!", 14, PALETTE.brass))


func _build_shop_popup(c: VBoxContainer) -> void:
	var lv := Game.level()
	var free_slots := Game.max_slots() - Game.rooms.size()
	c.add_child(_label("Boş yuva: %d — oda satın al:" % free_slots, 15, PALETTE.muted))
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
		var b := _button("%s — %s coin\n%s" % [d.name, _fmt(int(d.price)), desc], 15)
		if lv < int(d.unlock_level):
			b.text = "%s — Seviye %d'de açılır" % [d.name, int(d.unlock_level)]
			b.disabled = true
		else:
			b.disabled = not Game.can_buy_room(type)
			var t: String = type
			b.pressed.connect(func():
				if Game.buy_room(t):
					_show_toast("%s satın alındı!" % Game.room_def(t).name))
		c.add_child(b)
	if Game.floors < int(Game.eco.building.max_floors):
		var fb := _button("Yeni kat aç — %s coin (+%d yuva)" % [_fmt(Game.floor_price()), int(Game.eco.building.slots_per_floor)], 15, PALETTE.functional)
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
		Game.room_score(room), room.items.size()], 17, PALETTE.text))
	if tier < Game.eco.tier_names.size() - 1:
		var next_th := int(Game.eco.tier_thresholds[tier + 1])
		c.add_child(_label("Sonraki kademe (%s): SP %d gerekir" % [Game.tier_name(tier + 1), next_th], 14, PALETTE.brass))
	c.add_child(_label("Eşya ekle:", 15, PALETTE.muted))
	var lv := Game.level()
	for it in Game.eco.items:
		var b := _button("%s — SP +%d — %s coin" % [it.name, int(it.sp), _fmt(int(it.price))], 15)
		if lv < int(it.get("unlock_level", 1)):
			b.text = "%s — Seviye %d'de açılır" % [it.name, int(it.unlock_level)]
			b.disabled = true
		else:
			b.disabled = Game.coins < int(it.price)
			var iid: String = it.id
			b.pressed.connect(func():
				if Game.buy_item(selected_room, iid):
					_show_toast("%s yerleştirildi (+%d SP)" % [Game.item_def(iid).name, int(Game.item_def(iid).sp)]))
		c.add_child(b)


func _build_quests_popup(c: VBoxContainer) -> void:
	var q: Dictionary = Game.current_quest()
	if q.is_empty():
		c.add_child(_label("Tüm görevler tamamlandı. Tebrikler, otelci!", 17, PALETTE.green))
	else:
		var p: Array = Game.quest_progress(q)
		c.add_child(_label(String(q.name), 20, PALETTE.brass))
		var desc := _label(String(q.desc), 16, PALETTE.text)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		c.add_child(desc)
		c.add_child(_label("İlerleme: %d / %d" % [mini(p[0], p[1]), p[1]], 15, PALETTE.muted))
		var reward := "Ödül: %s coin" % _fmt(int(q.get("reward_coins", 0)))
		if int(q.get("reward_gems", 0)) > 0:
			reward += " + %d elmas" % int(q.reward_gems)
		c.add_child(_label(reward, 15, PALETTE.green))
	c.add_child(_label("Tamamlanan görev: %d / %d" % [Game.quest_index, Game.quests.size()], 14, PALETTE.muted))


# --- Geri bildirim -----------------------------------------------------

func _on_quest_completed(q: Dictionary) -> void:
	var msg := "Görev tamam: %s — +%s coin" % [q.name, _fmt(int(q.get("reward_coins", 0)))]
	if int(q.get("reward_gems", 0)) > 0:
		msg += ", +%d elmas" % int(q.reward_gems)
	_show_toast(msg)


func _show_toast(msg: String) -> void:
	toast_label.text = msg
	toast_label.visible = true
	_toast_timer = 3.0


func _show_offline_popup(amount: int) -> void:
	var dlg := AcceptDialog.new()
	dlg.title = "Hoş geldin!"
	dlg.dialog_text = "Sen yokken otelin çalıştı ve %s coin birikti.\nKasadan toplamayı unutma!" % _fmt(amount)
	dlg.ok_button_text = "Harika"
	add_child(dlg)
	dlg.popup_centered()


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
