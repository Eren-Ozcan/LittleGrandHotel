extends Node
## Görsel doğrulama aracı: ana sahneyi yükler (açılış yükleme ekranını
## atlar), kısa bir süre sonra ekran görüntüsünü user://shot.png'ye yazar
## ve çıkar.
## Çalıştırma (pencere açar, headless DEĞİL):
##   tools\Godot_v4.7-stable_win64_console.exe --path . res://tests/shot.tscn
## Argümanlar (-- ile ayrılır): demo, zoomin, zoomout, out=isim.png,
## popup=shift|settings|staff|quests|stats|profile|gems (ilgili popup'ı açık yakalar)


func _ready() -> void:
	var demo := "demo" in OS.get_cmdline_user_args()
	if demo:
		# main.tscn eklenmeden once talep edilir, yoksa main._ready() icindeki
		# acilis akisi (tutorial/gunluk odul) popup'i ekrani kaplar.
		var game := get_node("/root/Game")
		game.tutorial_seen = true
		if game.daily_reward_available():
			game.claim_daily_reward()
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
				"stats": ["Statistics", main._build_stats_popup],
				"profile": ["Profile", main._build_profile_popup],
				"gems": ["Buy Gems", main._build_gems_popup],
			}
			var key: String = arg.substr(6)
			if builders.has(key):
				main._open_popup(builders[key][0], builders[key][1])
	await get_tree().create_timer(0.3).timeout
	var out_path := "user://shot.png"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out_path = "user://" + arg.substr(4)
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_path)
	print("SHOT_SAVED: ", ProjectSettings.globalize_path(out_path))
	get_tree().quit()
