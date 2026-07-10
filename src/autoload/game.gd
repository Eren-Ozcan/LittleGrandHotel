extends Node
## Little Grand Hotel — çekirdek simülasyon (Faz 0).
## UI'dan bağımsızdır; headless test edilebilir (tests/sim_check.gd).
## Tüm denge değerleri data/economy.json'dan gelir — kodda sabit sayı yok.

signal state_changed

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 1
const ECO_PATH := "res://data/economy.json"
const AUTOSAVE_INTERVAL := 30.0

var eco: Dictionary = {}

var coins: int = 0
var gems: int = 0
var xp: int = 0
var rooms: Array = []            # her oda: {"type": String, "items": Array}
var shift_end_unix: float = 0.0
var pending_income: float = 0.0  # birikmiş, toplanmamış gelir
var last_sim_unix: float = 0.0

## Gri kutu test hızlandırması: 1.0 = gerçek zaman, 3600.0 = 1 sn : 1 oyun-saati
var time_scale: float = 1.0

var _autosave_acc := 0.0


func _ready() -> void:
	eco = load_json(ECO_PATH)
	if not load_game():
		new_game()


func _process(delta: float) -> void:
	simulate_to(now())
	_autosave_acc += delta
	if _autosave_acc >= AUTOSAVE_INTERVAL:
		_autosave_acc = 0.0
		save_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		if not eco.is_empty():
			save_game()


# --- Kuruluş -----------------------------------------------------------

func now() -> float:
	return Time.get_unix_time_from_system()


func load_json(path: String) -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func new_game() -> void:
	coins = int(eco.start.coins)
	gems = int(eco.start.gems)
	xp = 0
	rooms = [make_room("standard"), make_room("standard")]
	shift_end_unix = 0.0
	pending_income = 0.0
	last_sim_unix = now()
	state_changed.emit()


func make_room(type: String) -> Dictionary:
	return {"type": type, "items": []}


# --- Oda puanı, kademe, yıldız (GDD §4.3–4.4) --------------------------

func item_def(item_id: String) -> Dictionary:
	for it in eco.items:
		if it.id == item_id:
			return it
	return {}


func room_score(room: Dictionary) -> int:
	var total := 0
	for item_id in room.items:
		total += int(item_def(item_id).get("sp", 0))
	return total


func room_tier(room: Dictionary) -> int:
	var score := room_score(room)
	var tier := 0
	for i in eco.tier_thresholds.size():
		if score >= int(eco.tier_thresholds[i]):
			tier = i
	return tier


func tier_name(tier: int) -> String:
	return eco.tier_names[tier]


func star_rating() -> int:
	# Faz 0 basitleştirmesi: yalnızca ortalama kademe (GDD'de %50 ağırlıklı bileşen).
	# Tesis çeşitliliği ve hizmet düzeyi Faz 2'de eklenir.
	if rooms.is_empty():
		return 1
	var avg := 0.0
	for r in rooms:
		avg += room_tier(r)
	avg /= rooms.size()
	return clampi(2 + roundi(avg), 1, 5)


# --- Gelir ve vardiya (GDD §5.2) ---------------------------------------

func hourly_income() -> float:
	var total := 0.0
	for r in rooms:
		var rt: Dictionary = eco.room_types[r.type]
		total += float(rt.base_income) * float(eco.tier_mult[room_tier(r)])
	return total * float(eco.star_mult[str(star_rating())]) * float(eco.occupancy_base)


func staff_count() -> int:
	return maxi(1, ceili(rooms.size() * float(eco.staff_per_room)))


func shift_cost(hours: int) -> int:
	return staff_count() * hours * int(eco.shift_rates[str(hours)])


func shift_active() -> bool:
	return now() < shift_end_unix


func shift_remaining_game_hours() -> float:
	return maxf(0.0, (shift_end_unix - now()) * time_scale / 3600.0)


func start_shift(hours: int) -> bool:
	if shift_active():
		return false
	var cost := shift_cost(hours)
	if coins < cost:
		return false
	simulate_to(now())
	coins -= cost
	shift_end_unix = now() + hours * 3600.0 / time_scale
	state_changed.emit()
	return true


func simulate_to(to_unix: float) -> void:
	if last_sim_unix <= 0.0:
		last_sim_unix = to_unix
		return
	# Gelir yalnızca vardiya penceresi içinde birikir.
	var accrue_end := minf(to_unix, shift_end_unix)
	if accrue_end > last_sim_unix:
		var game_hours := (accrue_end - last_sim_unix) * time_scale / 3600.0
		pending_income += hourly_income() * game_hours
	last_sim_unix = maxf(last_sim_unix, to_unix)


func collect() -> int:
	simulate_to(now())
	var amount := int(pending_income)
	if amount <= 0:
		return 0
	pending_income -= amount
	coins += amount
	add_xp(maxi(1, int(amount / 10.0)))
	state_changed.emit()
	return amount


# --- Satın alma --------------------------------------------------------

func buy_room(type: String) -> bool:
	var rt: Dictionary = eco.room_types.get(type, {})
	if rt.is_empty() or level() < int(rt.unlock_level) or coins < int(rt.price):
		return false
	simulate_to(now())
	coins -= int(rt.price)
	rooms.append(make_room(type))
	state_changed.emit()
	return true


func buy_item(room_index: int, item_id: String) -> bool:
	if room_index < 0 or room_index >= rooms.size():
		return false
	var it := item_def(item_id)
	if it.is_empty() or coins < int(it.price):
		return false
	simulate_to(now())
	coins -= int(it.price)
	rooms[room_index].items.append(item_id)
	state_changed.emit()
	return true


# --- XP / seviye (GDD §5.3) --------------------------------------------

func xp_for_level(n: int) -> int:
	# Seviye n'e ulaşmak için gereken toplam XP: base × (n-1)^exp
	if n <= 1:
		return 0
	return int(float(eco.xp_curve.base) * pow(n - 1, float(eco.xp_curve.exp)))


func level() -> int:
	var n := 1
	while xp >= xp_for_level(n + 1):
		n += 1
	return n


func add_xp(amount: int) -> void:
	var before := level()
	xp += amount
	var gained := level() - before
	if gained > 0:
		gems += int(eco.levelup_gems) * gained


# --- Kayıt (GDD §10.1–10.2) --------------------------------------------

func save_game(path: String = SAVE_PATH) -> void:
	simulate_to(now())
	var data := {
		"save_version": SAVE_VERSION,
		"coins": coins,
		"gems": gems,
		"xp": xp,
		"rooms": rooms,
		"shift_end_unix": shift_end_unix,
		"pending_income": pending_income,
		"last_sim_unix": last_sim_unix,
	}
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


func load_game(path: String = SAVE_PATH) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY or int(parsed.get("save_version", 0)) != SAVE_VERSION:
		return false
	coins = int(parsed.get("coins", 0))
	gems = int(parsed.get("gems", 0))
	xp = int(parsed.get("xp", 0))
	rooms = parsed.get("rooms", [])
	shift_end_unix = float(parsed.get("shift_end_unix", 0.0))
	pending_income = float(parsed.get("pending_income", 0.0))
	last_sim_unix = float(parsed.get("last_sim_unix", now()))
	# Çevrimdışı kazanç tavanı (GDD §10.2 saat güvenliği):
	var cap_real_seconds := float(eco.offline_cap_hours) * 3600.0 / time_scale
	if now() - last_sim_unix > cap_real_seconds:
		last_sim_unix = now() - cap_real_seconds
	simulate_to(now())
	state_changed.emit()
	return true
