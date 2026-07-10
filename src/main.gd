extends Control
## Faz 0 gri kutu arayüzü. Tamamen koddan kurulur; sanat yok, yalnızca döngü.

var status_label: Label
var shift_label: Label
var collect_button: Button
var rooms_box: VBoxContainer
var buy_room_button: Button
var speed_button: Button
var shift_buttons: Dictionary = {}

const SPEEDS: Array[float] = [1.0, 60.0, 3600.0]
var speed_index := 0


func _ready() -> void:
	_build_ui()
	Game.state_changed.connect(_refresh)
	_refresh()


func _process(_delta: float) -> void:
	_update_live_labels()


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	margin.add_child(root)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(status_label)

	shift_label = Label.new()
	root.add_child(shift_label)

	collect_button = Button.new()
	collect_button.pressed.connect(func(): Game.collect())
	root.add_child(collect_button)

	var shift_row := HBoxContainer.new()
	shift_row.add_theme_constant_override("separation", 8)
	root.add_child(shift_row)
	for hours in [1, 4, 8, 24]:
		var b := Button.new()
		b.pressed.connect(func(): Game.start_shift(hours))
		shift_row.add_child(b)
		shift_buttons[hours] = b

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	rooms_box = VBoxContainer.new()
	rooms_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rooms_box.add_theme_constant_override("separation", 8)
	scroll.add_child(rooms_box)

	buy_room_button = Button.new()
	buy_room_button.pressed.connect(func(): Game.buy_room("standard"))
	root.add_child(buy_room_button)

	speed_button = Button.new()
	speed_button.pressed.connect(_cycle_speed)
	root.add_child(speed_button)


func _cycle_speed() -> void:
	speed_index = (speed_index + 1) % SPEEDS.size()
	# Hız değişmeden önce mevcut birikimi eski hızla işle.
	Game.simulate_to(Game.now())
	var remaining_real := maxf(0.0, Game.shift_end_unix - Game.now())
	Game.shift_end_unix = Game.now() + remaining_real * Game.time_scale / SPEEDS[speed_index]
	Game.time_scale = SPEEDS[speed_index]
	_refresh()


func _refresh() -> void:
	_update_live_labels()

	for child in rooms_box.get_children():
		child.queue_free()
	for i in Game.rooms.size():
		var room: Dictionary = Game.rooms[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var info := Label.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var rt: Dictionary = Game.eco.room_types[room.type]
		info.text = "%d. %s · %s · SP %d · %d eşya" % [
			i + 1, rt.name, Game.tier_name(Game.room_tier(room)),
			Game.room_score(room), room.items.size(),
		]
		row.add_child(info)
		var decorate := Button.new()
		var cheapest := _cheapest_affordable_item()
		if cheapest.is_empty():
			decorate.text = "Döşe (yetersiz coin)"
			decorate.disabled = true
		else:
			decorate.text = "Döşe: %s (%d)" % [cheapest.name, int(cheapest.price)]
			var item_id: String = cheapest.id
			decorate.pressed.connect(func(): Game.buy_item(i, item_id))
		row.add_child(decorate)
		rooms_box.add_child(row)

	var price := int(Game.eco.room_types.standard.price)
	buy_room_button.text = "Yeni Standart Oda (%d coin)" % price
	buy_room_button.disabled = Game.coins < price

	for hours in shift_buttons:
		var b: Button = shift_buttons[hours]
		b.text = "%ds vardiya\n(%d coin)" % [hours, Game.shift_cost(hours)]
		b.disabled = Game.shift_active() or Game.coins < Game.shift_cost(hours)

	speed_button.text = "Test hızı: ×%s" % str(SPEEDS[speed_index])


func _cheapest_affordable_item() -> Dictionary:
	var best: Dictionary = {}
	for it in Game.eco.items:
		if int(it.price) <= Game.coins and (best.is_empty() or int(it.price) < int(best.price)):
			best = it
	return best


func _update_live_labels() -> void:
	status_label.text = "Coin: %d   Elmas: %d   Seviye: %d (XP %d)   Yıldız: %d★\nSaatlik gelir: %.0f coin · Personel: %d" % [
		Game.coins, Game.gems, Game.level(), Game.xp, Game.star_rating(),
		Game.hourly_income(), Game.staff_count(),
	]
	if Game.shift_active():
		shift_label.text = "VARDİYA AÇIK — kalan: %.1f oyun-saati" % Game.shift_remaining_game_hours()
	else:
		shift_label.text = "Vardiya kapalı — otel gelir üretmiyor."
	collect_button.text = "TOPLA: %d coin" % int(Game.pending_income)
	collect_button.disabled = int(Game.pending_income) <= 0
