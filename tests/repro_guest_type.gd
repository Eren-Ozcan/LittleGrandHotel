extends Node
## Doğrulama: lobiye (asansöre) giren misafirin tipi, teslim edildiğinde
## odada gösterilen misafirin tipiyle AYNI mı? (bkz. kullanıcı şikâyeti:
## "aşağıdan giren müşteri tipi ile odaya çıkan müşteri tipi aynı değil")
## Ayrıca her 0.5sn'de bir durumu loglayarak TEK bir _spawn_lobby_walker
## çağrısının kaç kez teslimat ürettiğini gözlemler (issue #2 ile bağlantı
## şüphesi: "3 müşteri geldi ama 6 oda doldu").
## Çalıştırma:
##   tools\Godot_v4.7-stable_win64_console.exe --headless --path . res://tests/repro_guest_type.tscn


func _ready() -> void:
	var game := get_node("/root/Game")
	game.tutorial_seen = true
	if game.daily_reward_available():
		game.claim_daily_reward()

	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	game.coins += 100000
	var started: bool = game.start_shift(8)
	# Kalıcı kayıttaki eski bir vardiya test sırasında (time_scale hızlandırmasıyla)
	# aniden bitip sayaçları sıfırlayabiliyor — testin ortasında rastgele
	# bitmesin diye vardiya bitişini uzağa sabitliyoruz.
	game.shift_end_unix = game.now() + 999999.0
	main._finish_loading_screen()
	await get_tree().create_timer(0.6).timeout

	print("PRECHECK started=%s arrived=%d guest_rooms=%d queued_types=%s" \
		% [started, main._arrived_guests, main._guest_room_count(), main._queued_guest_types])

	main._spawn_lobby_walker("d_elder")
	print("SPAWNED_ONE_LOBBY_WALKER")

	for i in 16:
		await get_tree().create_timer(0.5).timeout
		print("t=%.1f queue=%d boarding=%d inbound=%d arrived=%d delivered_types=%s elevator_state=%s" \
			% [(i + 1) * 0.5, main._queue_count, main._boarding, main._inbound,
			main._arrived_guests, main._delivered_guest_types, main._elevator_state])

	var ok: bool = main._delivered_guest_types.size() > 0 and main._delivered_guest_types[0] == "d_elder"
	print("GUEST_TYPE_MATCH=%s" % ok)
	print("DONE")
	get_tree().quit()
