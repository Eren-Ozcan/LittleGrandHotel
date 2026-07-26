extends Node
## Görsel doğrulama aracı: ana sahneyi yükler, 1,5 sn sonra ekran
## görüntüsünü user://shot.png'ye yazar ve çıkar.
## Çalıştırma (pencere açar, headless DEĞİL):
##   tools\Godot_v4.7-stable_win64_console.exe --path . res://tests/shot.tscn


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
	await get_tree().create_timer(1.2).timeout
	if "zoomin" in OS.get_cmdline_user_args():
		main._zoom_by(0.35, main.zoom_viewport.size / 2.0)
	await get_tree().create_timer(0.3).timeout
	var out_path := "user://shot.png"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out_path = "user://" + arg.substr(4)
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_path)
	print("SHOT_SAVED: ", ProjectSettings.globalize_path(out_path))
	get_tree().quit()
