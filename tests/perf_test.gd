extends Node
## Detaylı runtime performans testi: oda sayısına göre _rebuild_hotel()
## ölçeklenmesi, boşta/kalabalık kare süresi (frame time) ve yaya/misafir
## katmanında node sızıntısı kontrolü.
## Çalıştırma (gerçek pencere açar, headless DEĞİL — Performance monitörleri
## ve tween/animasyon akışı için canlı render döngüsü gerekiyor):
##   tools\Godot_v4.7-stable_win64_console.exe --path . res://tests/perf_test.tscn

var main: Node
var game: Node


func _ready() -> void:
	main = load("res://main.tscn").instantiate()
	add_child(main)
	game = get_node("/root/Game")
	await get_tree().process_frame

	print("Little Grand Hotel — performans testi")
	print("=".repeat(64))

	await _bench_rebuild_scaling()
	await _bench_frame_time_idle()
	await _bench_guest_flood()
	await _bench_node_leak_check()

	print("=".repeat(64))
	print("PERF_DONE")
	get_tree().quit()


func _set_room_count(floors: int, rooms_per_floor: int) -> void:
	game.floors = floors
	game.floor_blocks = []
	for _i in floors:
		game.floor_blocks.append(rooms_per_floor)
	game.rooms = []
	for f in range(1, floors + 1):
		for c in range(rooms_per_floor):
			game.rooms.append(game.make_room("standard", f, c))


## Her çağrıdan sonra bir kare bekleyip queue_free() ile serbest bırakılan
## düğümlerin gerçekten belleğe düşmesini sağlıyoruz — aksi halde art arda
## (kare beklemeden) yapılan ölçümlerde serbest bırakılmayı bekleyen eski
## düğümler birikip sahte biçimde artan bir maliyet gibi görünebiliyor.
func _time_rebuild(n: int) -> Dictionary:
	await get_tree().process_frame
	var times: Array = []
	for _i in n:
		var t0 := Time.get_ticks_usec()
		main._rebuild_hotel()
		var t1 := Time.get_ticks_usec()
		times.append((t1 - t0) / 1000.0)
		await get_tree().process_frame
	times.sort()
	var total := 0.0
	for t in times:
		total += t
	return {"min": times[0], "max": times[-1], "avg": total / times.size()}


func _bench_rebuild_scaling() -> void:
	print("\n--- 1) _rebuild_hotel() maliyeti — oda sayısına göre ölçeklenme ---")
	print("  (her ölçümden sonra bir kare beklenip queue_free() düğümleri gerçekten boşaltılıyor)")
	# economy.json: building.max_floors=6, grid_cols=8 — yani gerçek oyunda
	# ulaşılabilecek gerçek üst sınır 6 kat x 8 oda = 48 oda. 10/30/60 kat
	# senaryoları saf ölçekleme eğilimini görmek için kasıtlı olarak
	# oyundaki üst sınırın ötesine taşıyor (gerçekçi değil, sadece trend).
	for cfg in [[2, 2], [6, 8], [10, 8], [30, 8]]:
		var floors: int = cfg[0]
		var rpf: int = cfg[1]
		_set_room_count(floors, rpf)
		var stats: Dictionary = await _time_rebuild(15)
		print("  %3d kat x %d oda = %4d oda  ->  ort %6.2fms  min %6.2fms  max %6.2fms  |  toplam node: %d" % [
			floors, rpf, floors * rpf, stats.avg, stats.min, stats.max, get_tree().get_node_count()
		])


func _sample_frame_times(duration: float, label: String) -> void:
	var samples: Array = []
	var elapsed := 0.0
	while elapsed < duration:
		await get_tree().process_frame
		var dt: float = get_process_delta_time()
		if dt <= 0.0:
			continue
		samples.append(dt * 1000.0)
		elapsed += dt
	samples.sort()
	var total := 0.0
	for s in samples:
		total += s
	var avg: float = total / samples.size()
	var p95: float = samples[int(samples.size() * 0.95)]
	print("  [%-9s] %4d kare | ort %5.2fms (~%3.0f FPS) | p95 %5.2fms | maks %5.2fms | node sayısı %d" % [
		label, samples.size(), avg, 1000.0 / avg, p95, samples[-1], get_tree().get_node_count()
	])


func _bench_frame_time_idle() -> void:
	print("\n--- 2) Boşta kare süresi (vardiya yok, düşük oda sayısı) ---")
	_set_room_count(2, 2)
	main._rebuild_hotel()
	await _sample_frame_times(3.0, "boşta")


func _bench_guest_flood() -> void:
	print("\n--- 3) Yoğun misafir/yaya trafiği altında kare süresi ---")
	_set_room_count(20, 8)
	main._rebuild_hotel()
	game.start_shift(24)
	# Gerçek "kalabalık lobi" senaryosunu zorla üret: art arda çok sayıda
	# kaldırım yayası + geçip giden yaya spawn'ı, elevator kuyruğunu ve
	# walker_layer'ı doldurur.
	for _i in 40:
		main._spawn_arriving_pedestrian()
	for _i in 20:
		main._spawn_passerby()
	await _sample_frame_times(5.0, "kalabalık")
	print("  kuyruk (_queue_count): %d  |  yolda (_inbound): %d  |  walker_layer node: %d" % [
		main._queue_count, main._inbound, main._walker_layer.get_child_count()
	])


func _bench_node_leak_check() -> void:
	print("\n--- 4) Sızıntı kontrolü: yoğunluk sonrası walker_layer boşalıyor mu ---")
	print("  (yeni spawn yok, mevcut tween'lerin/kuyruğun tükenmesi bekleniyor — 15sn)")
	var t := 0.0
	while t < 15.0:
		await get_tree().create_timer(3.0).timeout
		t += 3.0
		print("  t=%2.0fs  walker_layer node: %3d  |  kuyruk: %d  |  yolda: %d  |  toplam node: %d" % [
			t, main._walker_layer.get_child_count(), main._queue_count, main._inbound, get_tree().get_node_count()
		])
	if main._walker_layer.get_child_count() > 5:
		printerr("  UYARI: walker ikonları serbest bırakılmıyor olabilir (olası sızıntı)")
	else:
		print("  OK: walker katmanı büyük ölçüde temizlendi")
