extends Node
## Little Grand Hotel — çekirdek simülasyon v2 (MVP).
## UI'dan bağımsızdır; headless test edilebilir (tests/sim_check.gd).
## Tüm denge değerleri data/economy.json'dan, görevler data/quests.json'dan gelir.

signal state_changed
signal quest_completed(quest: Dictionary)
signal leveled_up(new_level: int)

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 2
const ECO_PATH := "res://data/economy.json"
const QUESTS_PATH := "res://data/quests.json"
const AUTOSAVE_INTERVAL := 30.0

var eco: Dictionary = {}
var quests: Array = []

var coins: int = 0
var gems: int = 0
var xp: int = 0
var floors: int = 2
var rooms: Array = []            # {"type":String, "items":Array, "dirty":bool, "clean_left":float}
var shift_end_unix: float = 0.0
var pending_income: float = 0.0
var last_sim_unix: float = 0.0

# Görev ilerlemesi
var quest_index: int = 0
var stat_shifts: int = 0
var stat_collects: int = 0
var stat_collected_total: int = 0
var stat_cleans: int = 0

## Uygulama açılışında sen-yokken kazanılan gelir (UI popup için; UI okur ve sıfırlar).
var offline_earned: int = 0

## Test hızlandırması: 1.0 = gerçek zaman, 3600.0 = 1 sn : 1 oyun-saati
var time_scale: float = 1.0

var _autosave_acc := 0.0
var _rooms_changed_in_sim := false


func _ready() -> void:
	eco = load_json(ECO_PATH)
	quests = load_json(QUESTS_PATH).get("quests", [])
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
	floors = int(eco.building.start_floors)
	rooms = [make_room("standard"), make_room("standard")]
	shift_end_unix = 0.0
	pending_income = 0.0
	last_sim_unix = now()
	quest_index = 0
	stat_shifts = 0
	stat_collects = 0
	stat_collected_total = 0
	stat_cleans = 0
	offline_earned = 0
	state_changed.emit()


func room_def(type: String) -> Dictionary:
	return eco.room_types.get(type, {})


func make_room(type: String) -> Dictionary:
	var d := room_def(type)
	return {
		"type": type,
		"items": [],
		"dirty": false,
		"clean_left": float(d.get("stay_hours", 0)),
	}


# --- Bina --------------------------------------------------------------

func max_slots() -> int:
	return floors * int(eco.building.slots_per_floor)


func floor_price() -> int:
	return int(float(eco.building.floor_price) * pow(float(eco.building.floor_mult), floors - int(eco.building.start_floors)))


func can_buy_floor() -> bool:
	return floors < int(eco.building.max_floors) and coins >= floor_price()


func buy_floor() -> bool:
	if not can_buy_floor():
		return false
	simulate_to(now())
	coins -= floor_price()
	floors += 1
	_check_quests()
	state_changed.emit()
	return true


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


func guest_rooms() -> Array:
	return rooms.filter(func(r): return room_def(r.type).category == "guest")


func has_type(type: String) -> bool:
	for r in rooms:
		if r.type == type:
			return true
	return false


func housekeeping_active() -> bool:
	return has_type("housekeeping")


func facility_diversity() -> int:
	var seen := {}
	for r in rooms:
		if room_def(r.type).category == "facility":
			seen[r.type] = true
	return seen.size()


func clean_fraction() -> float:
	var guests := guest_rooms()
	if guests.is_empty():
		return 1.0
	var clean := 0
	for r in guests:
		if not r.dirty:
			clean += 1
	return float(clean) / guests.size()


func star_rating() -> int:
	# GDD §4.4: ortalama kademe %50 + tesis çeşitliliği %30 + hizmet %20
	var guests := guest_rooms()
	var avg_tier := 0.0
	if not guests.is_empty():
		for r in guests:
			avg_tier += room_tier(r)
		avg_tier /= guests.size()
	var max_tier := float(eco.tier_names.size() - 1)
	var score := 0.5 * (avg_tier / max_tier) \
		+ 0.3 * (minf(facility_diversity(), 5.0) / 5.0) \
		+ 0.2 * clean_fraction()
	return clampi(1 + roundi(score * 4.0), 1, 5)


# --- Gelir ve vardiya (GDD §5.2) ---------------------------------------

## Mevcut durumda anlık saatlik gelir (kirli odalar hariç, otomasyon payı dahil).
func hourly_income() -> float:
	var smult := float(eco.star_mult[str(star_rating())])
	var occ := float(eco.occupancy_base)
	var hk := housekeeping_active()
	var total := 0.0
	for r in rooms:
		var d := room_def(r.type)
		if d.category == "facility":
			total += float(d.base_income)
		elif d.category == "guest":
			if r.dirty and not hk:
				continue
			var rate := float(d.base_income) * float(eco.tier_mult[room_tier(r)])
			if hk:
				rate *= float(d.stay_hours) / (float(d.stay_hours) + float(eco.auto_clean_hours))
			total += rate
	return total * smult * occ


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
	stat_shifts += 1
	_check_quests()
	state_changed.emit()
	return true


## Vardiyanın kalan kısmını elmasla anında bitirmenin bedeli.
func skip_shift_gem_cost() -> int:
	if not shift_active():
		return 0
	return maxi(1, ceili(shift_remaining_game_hours() / float(eco.gem_skip_hours)))


## Elmas harcayarak vardiyanın kalanını anında işler ve vardiyayı bitirir.
func skip_shift() -> bool:
	if not shift_active():
		return false
	var cost := skip_shift_gem_cost()
	if gems < cost:
		return false
	simulate_to(now())
	gems -= cost
	_advance(shift_remaining_game_hours())
	shift_end_unix = now()
	_check_quests()
	state_changed.emit()
	return true


func simulate_to(to_unix: float) -> void:
	if last_sim_unix <= 0.0:
		last_sim_unix = to_unix
		return
	var accrue_end := minf(to_unix, shift_end_unix)
	if accrue_end > last_sim_unix:
		var game_hours := (accrue_end - last_sim_unix) * time_scale / 3600.0
		_advance(game_hours)
	last_sim_unix = maxf(last_sim_unix, to_unix)
	if _rooms_changed_in_sim:
		_rooms_changed_in_sim = false
		state_changed.emit()


## Vardiya penceresi içindeki game_hours kadar ilerlet.
func _advance(game_hours: float) -> void:
	var smult := float(eco.star_mult[str(star_rating())])
	var occ := float(eco.occupancy_base)
	var hk := housekeeping_active()
	for r in rooms:
		var d := room_def(r.type)
		if d.category == "facility":
			pending_income += float(d.base_income) * game_hours * smult * occ
		elif d.category == "guest":
			var rate := float(d.base_income) * float(eco.tier_mult[room_tier(r)]) * smult * occ
			if hk:
				# Otomasyon: temizlik molaları duty oranıyla modellenir, oda hiç "kirli" kalmaz.
				var duty := float(d.stay_hours) / (float(d.stay_hours) + float(eco.auto_clean_hours))
				pending_income += rate * game_hours * duty
				if r.dirty:
					r.dirty = false
					_rooms_changed_in_sim = true
			else:
				if r.dirty:
					continue
				var earn_h := minf(game_hours, float(r.clean_left))
				pending_income += rate * earn_h
				r.clean_left = float(r.clean_left) - earn_h
				if r.clean_left <= 0.0001:
					r.dirty = true
					_rooms_changed_in_sim = true


func clean_room(index: int) -> bool:
	if index < 0 or index >= rooms.size():
		return false
	var r: Dictionary = rooms[index]
	if not r.dirty:
		return false
	simulate_to(now())
	r.dirty = false
	r.clean_left = float(room_def(r.type).get("stay_hours", 0))
	stat_cleans += 1
	add_xp(2)
	_check_quests()
	state_changed.emit()
	return true


func collect() -> int:
	simulate_to(now())
	var amount := int(pending_income)
	if amount <= 0:
		return 0
	pending_income -= amount
	coins += amount
	stat_collects += 1
	stat_collected_total += amount
	add_xp(maxi(1, int(amount / 10.0)))
	_check_quests()
	state_changed.emit()
	return amount


# --- Satın alma --------------------------------------------------------

func can_buy_room(type: String) -> bool:
	var d := room_def(type)
	if d.is_empty():
		return false
	return rooms.size() < max_slots() \
		and level() >= int(d.unlock_level) \
		and coins >= int(d.price)


func buy_room(type: String) -> bool:
	if not can_buy_room(type):
		return false
	simulate_to(now())
	coins -= int(room_def(type).price)
	rooms.append(make_room(type))
	_check_quests()
	state_changed.emit()
	return true


## Eşyanın elmasla mı (premium) yoksa coin'le mi satıldığını söyler.
func item_is_premium(it: Dictionary) -> bool:
	return int(it.get("gem_price", 0)) > 0


func can_afford_item(it: Dictionary) -> bool:
	if item_is_premium(it):
		return gems >= int(it.gem_price)
	return coins >= int(it.price)


func buy_item(room_index: int, item_id: String) -> bool:
	if room_index < 0 or room_index >= rooms.size():
		return false
	var it := item_def(item_id)
	if it.is_empty() or not can_afford_item(it) or level() < int(it.get("unlock_level", 1)):
		return false
	simulate_to(now())
	if item_is_premium(it):
		gems -= int(it.gem_price)
	else:
		coins -= int(it.price)
	rooms[room_index].items.append(item_id)
	_check_quests()
	state_changed.emit()
	return true


# --- XP / seviye (GDD §5.3) --------------------------------------------

func xp_for_level(n: int) -> int:
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
		leveled_up.emit(level())


# --- Görevler (GDD §4.7) -----------------------------------------------

func current_quest() -> Dictionary:
	if quest_index >= quests.size():
		return {}
	return quests[quest_index]


func quest_progress(q: Dictionary) -> Array:
	# [mevcut, hedef]
	var target := int(q.get("target", 1))
	match String(q.type):
		"start_shifts":
			return [stat_shifts, target]
		"collects":
			return [stat_collects, target]
		"collect_total":
			return [stat_collected_total, target]
		"cleans":
			return [stat_cleans, target]
		"rooms":
			return [rooms.size(), target]
		"floors":
			return [floors, target]
		"star":
			return [star_rating(), target]
		"own_type":
			return [1 if has_type(String(q.get("room", ""))) else 0, 1]
		"tier":
			var best := 0
			for r in rooms:
				if room_def(r.type).category == "guest":
					best = maxi(best, room_tier(r))
			return [best, target]
	return [0, target]


func _quest_done(q: Dictionary) -> bool:
	var p := quest_progress(q)
	return p[0] >= p[1]


func _check_quests() -> void:
	while true:
		var q := current_quest()
		if q.is_empty() or not _quest_done(q):
			break
		coins += int(q.get("reward_coins", 0))
		gems += int(q.get("reward_gems", 0))
		quest_index += 1
		quest_completed.emit(q)


# --- Kayıt (GDD §10.1–10.2) --------------------------------------------

func save_game(path: String = SAVE_PATH) -> void:
	simulate_to(now())
	var data := {
		"save_version": SAVE_VERSION,
		"coins": coins,
		"gems": gems,
		"xp": xp,
		"floors": floors,
		"rooms": rooms,
		"shift_end_unix": shift_end_unix,
		"pending_income": pending_income,
		"last_sim_unix": last_sim_unix,
		"quest_index": quest_index,
		"stat_shifts": stat_shifts,
		"stat_collects": stat_collects,
		"stat_collected_total": stat_collected_total,
		"stat_cleans": stat_cleans,
		"time_scale": time_scale,
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
	floors = int(parsed.get("floors", int(eco.building.start_floors)))
	rooms = parsed.get("rooms", [])
	shift_end_unix = float(parsed.get("shift_end_unix", 0.0))
	pending_income = float(parsed.get("pending_income", 0.0))
	last_sim_unix = float(parsed.get("last_sim_unix", now()))
	quest_index = int(parsed.get("quest_index", 0))
	stat_shifts = int(parsed.get("stat_shifts", 0))
	stat_collects = int(parsed.get("stat_collects", 0))
	stat_collected_total = int(parsed.get("stat_collected_total", 0))
	stat_cleans = int(parsed.get("stat_cleans", 0))
	# Vardiya bitişi gerçek saniye tutulur; ölçek geri yüklenmezse
	# hızlı modda kaydedilen vardiya normal hızda 60/3600 kat kısalır.
	time_scale = float(parsed.get("time_scale", 1.0))
	# Çevrimdışı kazanç tavanı (GDD §10.2 saat güvenliği)
	var cap_real_seconds := float(eco.offline_cap_hours) * 3600.0 / time_scale
	if now() - last_sim_unix > cap_real_seconds:
		last_sim_unix = now() - cap_real_seconds
	var pending_before := pending_income
	simulate_to(now())
	offline_earned = int(pending_income - pending_before)
	state_changed.emit()
	return true
