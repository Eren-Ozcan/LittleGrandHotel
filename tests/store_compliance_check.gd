extends Node
## Verification harness for the store-compliance round:
## gem packs are granted exactly once (and survive an interrupted purchase),
## entitlements come back from a store restore, and restore_purchases()
## reports honestly when the store cannot be reached.
##
## Run: tools\Godot_v4.7-stable_win64_console.exe --path . res://tests/store_compliance_check.tscn
##
## AĞA ÇIKMAZ, ve bu bilinçli bir düzeltme: bu dosya 2026-08-24'e kadar
## `CloudSave.delete_cloud_data()`'yı gerçekten çağırıyordu. Firebase
## yapılandırılmış olduğu için o yol her koşuda üretimde anonim bir hesap
## yaratıp siliyor, geliştiricinin makinesinde bağlı bir Google oturumu varsa
## GERÇEK hesabı siliyordu. Ağ dalı artık sahte bir auth ile kapatılıyor
## (bkz. `StubAuth`), açılış senkronu da `_syncing`/`_uploading` ile —
## `tests/cloud_api_check.gd`'deki deyimin aynısı.

## delete_cloud_data()'nın token kapısını ağa çıkmadan sürmek için sahte auth.
## Boş token = "oturum açılamadı"; gerçek `FirebaseAuth` ağ hatasında da bunu
## döndürür, yani sürülen dal üretimdekiyle aynı dal.
class StubAuth extends Node:
	var token := ""
	var delete_called := false

	func ensure_token() -> String:
		return token

	func uid() -> String:
		return "stub-uid"

	func delete_account() -> bool:
		delete_called = true
		return true


## The purchase and deletion paths write to the real save (entitlements persist,
## and the deletion test resets the game), so the developer's save is stashed
## first and put back at the end — same discipline as tests/cloud_save_check.gd.
const SAVE_PATH := "user://save.json"
const BACKUP_PATH := "user://save.json.storetest.bak"
const CLOUD_STATE_PATH := "user://cloud_state.json"
const CLOUD_STATE_BACKUP := "user://cloud_state.json.storetest.bak"

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
## ölürse yedeği öksüz bırakır ve canlı kaydı testin bıraktığı hâlde saklar.
func _exit_tree() -> void:
	_restore(SAVE_PATH, BACKUP_PATH)
	_restore(CLOUD_STATE_PATH, CLOUD_STATE_BACKUP)
	print("  (test oncesi kayit geri yuklendi)")


## Elmas paketinin tablodaki ödülü — beklenen sayı testte değil oyunda dursun,
## yoksa tablo değişince test "doğru" kalıp yanlış şeyi ölçer.
func _pack_gems(product_id: String) -> int:
	var packs: Array = _main.GEM_PACKS
	for pack in packs:
		if pack.product == product_id:
			return int(pack.gems)
	return -1


func _ready() -> void:
	_stash(SAVE_PATH, BACKUP_PATH)
	_stash(CLOUD_STATE_PATH, CLOUD_STATE_BACKUP)
	var game := get_node("/root/Game")
	var iap := get_node("/root/IAP")
	var cloud := get_node("/root/CloudSave")
	# AĞ KAPISI: CloudSave._ready() açılış senkronunu kuyruğa aldı; bu iki bayrak
	# onu daha ilk adımda geri çevirir.
	cloud._syncing = true
	cloud._uploading = true
	game.tutorial_seen = true
	game.offline_earned = 0
	game.auto_renew_count = 0
	_main = load("res://main.tscn").instantiate()
	add_child(_main)
	_main._finish_loading_screen()
	await get_tree().process_frame

	# --- gem pack is granted exactly once through the mock purchase ---
	var expected: int = _pack_gems("gems_medium")
	check(expected > 0, "gems_medium GEM_PACKS tablosunda var")
	var before: int = game.gems
	var after: int = 0
	iap.purchase("gems_medium")
	await get_tree().process_frame
	after = game.gems
	check(after - before == expected,
		"gems_medium satın alması tam olarak %d elmas verdi (delta=%d)"
			% [expected, after - before])

	# --- an interrupted purchase that only comes back as a store restore ---
	expected = _pack_gems("gems_small")
	before = game.gems
	iap.purchase_result.emit("gems_small", true)
	await get_tree().process_frame
	after = game.gems
	check(after - before == expected,
		"yarım kalan gems_small mağazadan geri gelince %d elmas verdi (delta=%d)"
			% [expected, after - before])

	# --- entitlements restored from the store ---
	game.remove_ads = false
	game.permanent_income_mult = 1.0
	iap.purchase_result.emit("remove_ads", true)
	iap.purchase_result.emit("income_2x", true)
	await get_tree().process_frame
	var removed: bool = game.remove_ads
	var mult: float = game.permanent_income_mult
	check(removed, "remove_ads hakkı geri yüklendi")
	check(is_equal_approx(mult, 2.0),
		"income_2x çarpanı 2.0'a geri yüklendi (mult=%s)" % mult)

	# Aynı hak ikinci kez gelirse (mağaza her açılışta tüm satın almaları
	# bildirir) çarpan katlanmamalı.
	iap.purchase_result.emit("income_2x", true)
	await get_tree().process_frame
	mult = game.permanent_income_mult
	check(is_equal_approx(mult, 2.0),
		"tekrar bildirilen income_2x çarpanı KATLAMADI")

	# --- no store on desktop: restore must report failure, not a fake promise ---
	var restored: bool = iap.restore_purchases()
	check(not restored,
		"mağaza yokken restore_purchases() sahte söz vermedi (false döndü)")

	# --- deletion path: honest failure when a token cannot be obtained ---
	# Yapılandırma sabitleri const olduğu için is_enabled()==false dalı
	# (yapılandırılmamış kurulumda "silinecek bir şey yok, true dön") burada
	# sürülemez; sürülen dal ağ/oturum başarısızlığı — sessizce true dönmesi
	# oyuncuya "verin silindi" demek olurdu.
	var stub := StubAuth.new()
	var real_auth: Node = cloud._auth
	cloud._auth = stub
	cloud._rev = 7
	cloud._last_synced_uid = "before-delete"
	var deleted: bool = await cloud.delete_cloud_data()
	var enabled: bool = cloud.is_enabled()
	check(enabled, "bulut bu kurulumda yapılandırılmış (silme yolu gerçekten sürüldü)")
	check(not deleted, "oturum açılamayınca delete_cloud_data() false döndü")
	check(not stub.delete_called, "token yokken hesap silme İSTEĞİ hiç yapılmadı")
	check(cloud._rev == 7 and cloud._last_synced_uid == "before-delete",
		"başarısız silme yerel bulut durumunu SIFIRLAMADI")
	cloud._auth = real_auth
	stub.free()

	_main.queue_free()
	await get_tree().process_frame
	print("=".repeat(64))
	if failures == 0:
		print("TÜM TESTLER GEÇTİ (%d kontrol)" % checks)
	else:
		printerr("%d/%d TEST BAŞARISIZ" % [failures, checks])
	get_tree().quit(1 if failures > 0 else 0)
