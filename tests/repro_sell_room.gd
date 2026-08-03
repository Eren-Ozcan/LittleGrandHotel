extends Node
## Bug tekrar-üretme + doğrulama: bir misafir odası satıldığında main.gd'nin
## _arrived_guests sayacı gerçek oda sayısına göre sınırlanıyor mu, ve
## sonradan sıfırdan açılan yeni oda anında dolu görünüyor mu? (bkz.
## kullanıcı şikâyeti: "yeni oda açınca içinde müşteri spawn oluyor")
## Mevcut kayıtlı oyun durumuna göre çalışır (oda sayısı sabit varsayılmaz).
## Çalıştırma:
##   tools\Godot_v4.7-stable_win64_console.exe --path . res://tests/repro_sell_room.tscn


func _guest_order_of(main: Node, room_idx: int) -> int:
	var game := get_node("/root/Game")
	var order := 0
	for j in range(room_idx):
		if String(game.room_def(game.rooms[j].type).get("category", "")) == "guest":
			order += 1
	return order


func _ready() -> void:
	var game := get_node("/root/Game")
	game.tutorial_seen = true
	if game.daily_reward_available():
		game.claim_daily_reward()

	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	game.coins += 100000
	game.start_shift(8)
	main._finish_loading_screen()
	await get_tree().create_timer(0.6).timeout

	# 3 yeni misafir odası ekle (mevcut kayıtlı odalara ek olarak) - bunlar
	# her zaman dizinin SONUNA eklenir, o yüzden index'leri biliniyor.
	for i in 3:
		game.buy_room("standard")

	# Tüm misafir odaları "dolu" say (gerçek oyunda vardiya boyunca doğal
	# olarak buraya varılır; testte doğrudan atıyoruz).
	var full_count: int = main._guest_room_count()
	main._arrived_guests = full_count
	main._rebuild_hotel()
	await get_tree().create_timer(0.2).timeout
	print("STEP1 guest_rooms=%d arrived=%d" % [main._guest_room_count(), main._arrived_guests])
	await _shot(main, "user://shot_1_full.png")

	# Son eklenen (misafir tipi garanti) odayı sat -> guest_rooms 1 azalir
	# ama eskiden _arrived_guests HALA eski (daha yuksek) degerdeydi.
	var sell_idx: int = game.rooms.size() - 1
	var sold_was_guest: bool = String(game.room_def(game.rooms[sell_idx].type).get("category", "")) == "guest"
	game.sell_room(sell_idx)
	await get_tree().create_timer(0.2).timeout
	var after_sell_rooms: int = main._guest_room_count()
	print("STEP2 sold_guest_room=%s guest_rooms=%d arrived=%d (beklenen arrived <= guest_rooms)" \
		% [sold_was_guest, after_sell_rooms, main._arrived_guests])
	var clamp_ok: bool = main._arrived_guests <= after_sell_rooms
	print("CLAMP_OK=%s" % clamp_ok)
	await _shot(main, "user://shot_2_after_sell.png")

	# Sifirdan yeni bir oda ac - eskiden bu odada ANINDA misafir goruluyordu.
	game.buy_room("standard")
	await get_tree().create_timer(0.2).timeout
	var new_room_idx: int = game.rooms.size() - 1
	var new_room_order: int = _guest_order_of(main, new_room_idx)
	var new_room_shows_guest: bool = new_room_order < main._arrived_guests
	print("STEP3 guest_rooms=%d arrived=%d new_room_guest_order=%d new_room_shows_guest_instantly=%s" \
		% [main._guest_room_count(), main._arrived_guests, new_room_order, new_room_shows_guest])
	print("BUG_FIXED=%s" % (not new_room_shows_guest))
	await _shot(main, "user://shot_3_new_room.png")

	print("DONE")
	get_tree().quit()


func _shot(main: Node, out_path: String) -> void:
	await get_tree().create_timer(0.1).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_path)
	print("SHOT_SAVED: ", ProjectSettings.globalize_path(out_path))
