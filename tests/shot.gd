extends Node
## Görsel doğrulama aracı: ana sahneyi yükler (açılış yükleme ekranını
## atlar), kısa bir süre sonra ekran görüntüsünü user://shot.png'ye yazar
## ve çıkar.
## Çalıştırma (pencere açar, headless DEĞİL):
##   tools\Godot_v4.7-stable_win64_console.exe --path . res://tests/shot.tscn
## Argümanlar (-- ile ayrılır): demo, zoomin, zoomout, out=isim.png,
## popup=shift|settings|staff|quests|stats|profile|gems|build|store|room
##   (ilgili popup'ı açık yakalar; store_*/profile_* ile sekme de seçilir)


func _ready() -> void:
	var demo := "demo" in OS.get_cmdline_user_args()
	if demo:
		# main.tscn eklenmeden once talep edilir, yoksa main._ready() icindeki
		# acilis akisi (tutorial/gunluk odul) popup'i ekrani kaplar.
		var game := get_node("/root/Game")
		game.tutorial_seen = true
		if game.daily_reward_available():
			game.claim_daily_reward()
		# Cevrimdisi kazanc modali da acilista ekrani kapatiyor — kaydedilmis
		# bir birikim varsa her cekimde onun arkasina dusuyorduk.
		game.offline_earned = 0
		game.auto_renew_count = 0
		game.auto_renew_spent = 0
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	# "demo" argümanıyla: bellekte coin ver + vardiya başlat (kayda yazılmaz),
	# misafirli/kapasiteli görünümü yakalamak için.
	if demo:
		var game := get_node("/root/Game")
		game.coins += 50000
		game.start_shift(8)
	# Açılış yükleme ekranı (~4.2sn büyüme animasyonu, bkz. main.gd
	# _finish_loading_screen) her çekimde beklemek yerine burada atlanır —
	# aksi halde popup=... argümanları ekran görüntüsünde hâlâ görünen
	# yükleme ekranının ARKASINDA açılmış olurdu.
	main._finish_loading_screen()
	await get_tree().create_timer(0.6).timeout
	if "zoomin" in OS.get_cmdline_user_args():
		main._zoom_by(0.35, main.zoom_viewport.size / 2.0)
	if "zoomout" in OS.get_cmdline_user_args():
		# Alt sınıra kadar uzaklaş — tüm bina (bütün katlar) tek karede görünür.
		main._zoom_by(-10.0, main.zoom_viewport.size / 2.0)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("tut="):
			# Zorunlu açılış tutorial'ının belirli bir adımını yakalamak için.
			main._show_tutorial_step(int(arg.substr(4)))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("popup="):
			var builders := {
				"shift": ["Shift", main._build_shift_popup],
				"settings": ["Settings", main._build_settings_popup],
				"staff": ["Staff", main._build_staff_popup],
				"quests": ["Quests", main._build_quests_popup],
				"quests_achievements": ["Quests", main._build_quests_popup],
				"stats": ["Statistics", main._build_stats_popup],
				"profile": ["Profile", main._build_profile_popup],
				"gems": ["Buy Gems", main._build_gems_popup],
				"build": ["Build", main._build_build_popup],
				"store": ["Store", main._build_store_popup],
				"store_premium": ["Store", main._build_store_popup],
				"profile_account": ["Profile", main._build_profile_popup],
				"profile_prestige": ["Profile", main._build_profile_popup],
				"profile_stats": ["Profile", main._build_profile_popup],
				"profile_settings": ["Profile", main._build_profile_popup],
				"room": ["Room", main._build_room_popup],
			}
			var key: String = arg.substr(6)
			if builders.has(key):
				# Sekmeli ekranlarda hangi sekmenin açık yakalanacağı anahtarın
				# son parçasından gelir (store_premium -> premium).
				if key.begins_with("store_"):
					main._store_tab = key.substr(6)
				elif key.begins_with("quests_"):
					main._quests_tab = key.substr(7)
				elif key.begins_with("profile_"):
					main._profile_tab = key.substr(8)
				elif key == "room":
					# Oda ekrani secili bir oda ister; ilk oda her kayitta var.
					main.selected_room = 0
				main._open_popup(builders[key][0], builders[key][1])
	for arg in OS.get_cmdline_user_args():
		# Popup yiginindan bagimsiz modallar (gunluk odul / cevrimdisi kazanc).
		if arg == "modal=daily":
			main._show_daily_reward_popup()
		elif arg == "modal=conflict":
			# Sahte bir bulut cakismasi kur — modal yalnizca has_conflict()
			# dogruyken aciliyor.
			var cs := get_node("/root/CloudSave")
			cs._blocked = true
			cs._pending_cloud = {
				"summary": {"level": 7, "coins": 128400, "gems": 62, "rooms": 11},
				"updated_at": Time.get_unix_time_from_system() - 5400.0,
			}
			main._show_cloud_conflict_modal()
		elif arg.begins_with("toast="):
			main._show_toast(arg.substr(6))
		elif arg == "modal=offline":
			get_node("/root/Game").offline_seconds = 5.0 * 3600.0 + 720.0
			main._show_offline_popup(4820, 2, 900)
	await get_tree().create_timer(0.3).timeout
	var out_path := "user://shot.png"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out_path = "user://" + arg.substr(4)
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_path)
	print("SHOT_SAVED: ", ProjectSettings.globalize_path(out_path))
	get_tree().quit()
