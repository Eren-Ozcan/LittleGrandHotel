extends Node
## Görsel doğrulama aracı: ana sahneyi yükler, 1,5 sn sonra ekran
## görüntüsünü user://shot.png'ye yazar ve çıkar.
## Çalıştırma (pencere açar, headless DEĞİL):
##   tools\Godot_v4.7-stable_win64_console.exe --path . res://tests/shot.tscn


func _ready() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	# "demo" argümanıyla: bellekte coin ver + vardiya başlat (kayda yazılmaz),
	# misafirli/kapasiteli görünümü yakalamak için.
	if "demo" in OS.get_cmdline_user_args():
		var game := get_node("/root/Game")
		game.coins += 50000
		game.start_shift(8)
	await get_tree().create_timer(1.5).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://shot.png")
	print("SHOT_SAVED: ", ProjectSettings.globalize_path("user://shot.png"))
	get_tree().quit()
