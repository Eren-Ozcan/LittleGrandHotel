extends Node
## Verification harness for "Disconnect account": the row only exists while an
## account is linked, it asks twice, and disconnecting resets the cloud identity
## without touching the local save.
##
## The linked state is faked by handing FirebaseAuth a session, because a real
## browser sign-in cannot run in a test.
##
## Run: tools\Godot_v4.7-stable_win64_console.exe --path . res://tests/unlink_check.tscn
## Add "shot" to the user args to also write user://unlink.png.
##
## AĞA ÇIKMAZ: sahte oturum yazıldığı için açılış senkronu üretimdeki Firestore'a
## uzanırdı; `_syncing`/`_uploading` kapısı `tests/cloud_api_check.gd`'deki
## deyimin aynısıdır. Sahte oturum gerçek `user://firebase_auth.json`'a da
## yazılıyor (bağlantı kesme onu temizler), o yüzden geliştiricinin oturum ve
## bulut durum dosyaları teste girerken bir yana alınıp çıkarken geri konur.

const AUTH_PATH := "user://firebase_auth.json"
const AUTH_BACKUP := "user://firebase_auth.json.unlink.bak"
const CLOUD_STATE_PATH := "user://cloud_state.json"
const CLOUD_STATE_BACKUP := "user://cloud_state.json.unlink.bak"

var failures := 0
var checks := 0
var _main: Node


func check(cond: bool, label: String) -> void:
	checks += 1
	if cond:
		print("  OK   ", label)
	else:
		failures += 1
		printerr("  FAIL ", label)


func _stash(path: String, backup: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(path),
			ProjectSettings.globalize_path(backup))


func _restore(path: String, backup: String) -> void:
	if not FileAccess.file_exists(backup):
		return
	DirAccess.copy_absolute(ProjectSettings.globalize_path(backup),
		ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(backup))


## Geri koyma _exit_tree'de: düz bir "en sonda çağır" satırı, test ortasında
## ölürse yedeği öksüz bırakır ve gerçek oturumu testin bıraktığı hâlde saklar.
func _exit_tree() -> void:
	_restore(AUTH_PATH, AUTH_BACKUP)
	_restore(CLOUD_STATE_PATH, CLOUD_STATE_BACKUP)


func _find(node: Node, text: String) -> Button:
	if node is Button and node.has_meta("title_label"):
		var title_l: Label = node.get_meta("title_label")
		if title_l != null and title_l.text.begins_with(text):
			return node
	for child in node.get_children():
		var found := _find(child, text)
		if found != null:
			return found
	return null


func _ready() -> void:
	_stash(AUTH_PATH, AUTH_BACKUP)
	_stash(CLOUD_STATE_PATH, CLOUD_STATE_BACKUP)
	var game := get_node("/root/Game")
	var cloud := get_node("/root/CloudSave")
	# AĞ KAPISI: CloudSave._ready() açılış senkronunu kuyruğa aldı.
	cloud._syncing = true
	cloud._uploading = true
	game.tutorial_seen = true
	game.offline_earned = 0
	game.auto_renew_count = 0
	_main = load("res://main.tscn").instantiate()
	add_child(_main)
	_main._finish_loading_screen()
	await get_tree().process_frame

	# Pretend the player finished a Google sign-in on this device.
	var auth: Node = cloud._auth
	auth._state_loaded = true
	auth._uid = "test-uid-1234"
	auth._provider = "google.com"
	auth._refresh_token = "test-refresh"
	cloud._last_synced_uid = auth._uid
	cloud._rev = 7
	var linked: bool = cloud.is_linked()
	check(linked, "sahte oturumla is_linked() true")

	_main._profile_tab = "account"
	_main._open_popup("Profile", _main._build_profile_popup)
	await get_tree().process_frame
	var unlink_b := _find(get_tree().root, "Disconnect account")
	check(unlink_b != null, "hesap bağlıyken 'Disconnect account' satırı çizildi")
	if unlink_b == null:
		_finish()
		return
	if "shot" in OS.get_cmdline_user_args():
		await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.save_png("user://unlink.png")
		print("SHOT_SAVED: ", ProjectSettings.globalize_path("user://unlink.png"))

	var coins_before: int = game.coins
	unlink_b.emit_signal("pressed")
	await get_tree().process_frame
	linked = cloud.is_linked()
	var confirm := _find(get_tree().root, "Tap again to disconnect")
	check(linked, "ilk dokunuş bağlantıyı KESMEDİ")
	check(confirm != null, "ilk dokunuş onay satırını gösterdi")
	if confirm == null:
		_finish()
		return

	confirm.emit_signal("pressed")
	await get_tree().process_frame
	linked = cloud.is_linked()
	var uid: String = auth.uid()
	var rev: int = cloud._rev
	var coins_after: int = game.coins
	check(not linked, "ikinci dokunuş bağlantıyı kesti")
	check(uid.is_empty(), "bulut kimliği temizlendi (uid='%s')" % uid)
	check(rev == 0, "sonraki yükleme sıfırdan yazsın diye rev sıfırlandı (rev=%d)" % rev)
	check(coins_after == coins_before, "YEREL kayda dokunulmadı (coins korundu)")

	# The row must be gone and the sign-in offer back in its place.
	check(_find(get_tree().root, "Disconnect account") == null,
		"bağlantı kesilince satır kayboldu")
	check(_find(get_tree().root, "Link with Google") != null,
		"yerine 'Link with Google' teklifi geri geldi")
	_finish()


func _finish() -> void:
	print("=".repeat(64))
	if failures == 0:
		print("TÜM TESTLER GEÇTİ (%d kontrol)" % checks)
	else:
		printerr("%d/%d TEST BAŞARISIZ" % [failures, checks])
	get_tree().quit(1 if failures > 0 else 0)
