extends Node
## Zorunlu açılış tutorial'ının otomatik testi (bkz. main.gd _show_tutorial_modal).
## Kullanıcı isteği: "zorunlu oynanan, sadece oyun ilk açıldığında gelen" —
## burada üç şey doğrulanır: (1) yepyeni kayıtta açılıyor, (2) her adım
## bloklayıcı ve yalnızca butonla ilerliyor, (3) bittikten sonra bir daha
## GELMİYOR (ve bu kalıcı olarak kaydediliyor).
##
## Çalıştırma (pencere açar, headless DEĞİL):
##   tools\Godot_v4.7-stable_win64_console.exe --path . res://tests/tutorial_check.tscn

var failures := 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("  OK   ", label)
	else:
		failures += 1
		printerr("  FAIL ", label)


## Adım kartındaki tek eylem butonunu bulur (panel içindeki VBox'ın son çocuğu).
func _step_button(main: Node) -> Button:
	if main.tutorial_layer == null or not is_instance_valid(main.tutorial_layer):
		return null
	for node in main.tutorial_layer.find_children("*", "Button", true, false):
		return node
	return null


## Test gerçek oyunu (ve gerçek user://save.json'u) çalıştırır — tutorial'ı
## bitirmek Game.save_game() tetiklediği için oyuncunun kaydını EZER. Bu yüzden
## kayıt teste girerken bir yana alınır, çıkarken geri konur.
const SAVE_PATH := "user://save.json"
const BACKUP_PATH := "user://save.json.tutcheck.bak"


func _stash_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE_PATH),
			ProjectSettings.globalize_path(BACKUP_PATH))


func _restore_save() -> void:
	if not FileAccess.file_exists(BACKUP_PATH):
		return
	DirAccess.copy_absolute(ProjectSettings.globalize_path(BACKUP_PATH),
		ProjectSettings.globalize_path(SAVE_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(BACKUP_PATH))
	print("  (test öncesi kayıt geri yüklendi)")


func _ready() -> void:
	print("Little Grand Hotel — zorunlu tutorial testi")
	_stash_save()
	var game := get_node("/root/Game")
	# Yepyeni kayıt durumu: tutorial hiç görülmemiş.
	game.new_game()
	check(game.tutorial_seen == false, "yeni oyunda tutorial_seen false")

	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	main._finish_loading_screen()
	# Açılış ekranı 0.28 sn soluklaşıp KAPANINCA tutorial başlar (bkz.
	# _finish_loading_screen) — tek kare beklemek yetmez.
	await get_tree().create_timer(0.6).timeout

	check(main._tutorial_step == 0, "ilk açılışta tutorial 0. adımda başladı")
	check(main.tutorial_layer != null and is_instance_valid(main.tutorial_layer),
		"tutorial katmanı oluşturuldu")
	check(main.tutorial_layer.layer > 0, "tutorial katmanı oyunun üstünde (layer %d)" % main.tutorial_layer.layer)

	# Karartma bloklayıcı mı: girdi oyuna sızmamalı (MOUSE_FILTER_STOP).
	var dim: Control = main.tutorial_layer.get_child(0)
	check(dim.mouse_filter == Control.MOUSE_FILTER_STOP, "karartma tüm dokunuşları yutuyor")

	# Zorunluluk: geri tuşu (Android) tutorial'ı kapatmıyor, oyundan da çıkmıyor.
	main._notification(main.NOTIFICATION_WM_GO_BACK_REQUEST)
	await get_tree().process_frame
	check(main._tutorial_step == 0 and game.tutorial_seen == false,
		"geri tuşu tutorial'ı atlamıyor")

	# Adımları tek tek butonla geç.
	var steps: int = main.TUTORIAL_STEPS.size()
	for i in steps:
		check(main._tutorial_step == i, "adım %d gösteriliyor" % i)
		var b := _step_button(main)
		if b == null:
			check(false, "adım %d için buton bulunamadı" % i)
			break
		b.pressed.emit()
		await get_tree().process_frame

	check(game.tutorial_seen == true, "tutorial tamamlandı, kalıcı olarak işaretlendi")
	check(main.tutorial_layer == null, "tutorial katmanı kaldırıldı")

	# İkinci açılış: bir daha gelmemeli.
	main._maybe_show_tutorial()
	await get_tree().process_frame
	check(main._tutorial_step == -1 and main.tutorial_layer == null,
		"ikinci açılışta tutorial tekrar gelmiyor")

	_restore_save()
	if failures == 0:
		print("TÜM TESTLER GEÇTİ (%d adım)" % steps)
	else:
		printerr("%d TEST BAŞARISIZ" % failures)
	get_tree().quit(1 if failures > 0 else 0)
