extends Node
## Eklentinin GERÇEKTEN gönderdiği sözlük anahtarlarını çivileyen test.
##
## 2026-08-25'te gerçek cihazda para alınıp elmas verilmedi. Sebep basitti:
## `iap.gd` satın alma sözlüğünde ürün listesini `products` diye okuyordu, oysa
## eklenti `product_ids` gönderiyor. Yanlış anahtar hata vermez — `Dictionary.get`
## sessizce varsayılanı döndürür — ve `tests/iap_check.gd` fixture'ları da aynı
## uydurma adları kullandığı için paket yeşil kalmıştı. Yani test, eklentinin
## sözleşmesini değil kendi uydurduğu sözleşmeyi doğruluyordu.
##
## Buradaki fikir: anahtar adlarını EKLENTİNİN İKİLİSİNDEN oku. `.aar` bir zip,
## içindeki `classes.jar` da bir zip; sınıf dosyalarının sabit havuzunda anahtar
## adları düz metin olarak duruyor. Eklenti sürümü bir anahtarı yeniden
## adlandırırsa bu test kırmızıya döner — cihazda iade talebiyle değil.
##
## Çalıştırma:
##   tools\Godot_v4.7-stable_win64_console.exe --headless --path . res://tests/plugin_keys_check.tscn

const AAR_PATH := "res://addons/GodotGooglePlayBilling/bin/release/GodotGooglePlayBilling-release.aar"
const IAP_PATH := "res://src/autoload/iap.gd"
const JAR_TMP := "user://plugin_keys_classes.jar"

## `iap.gd`'nin eklentiden gelen sözlüklerde okuduğu anahtarlar. Her biri hem
## kaynakta geçmeli hem de eklentinin ikilisinde bulunmalı.
const REQUIRED_KEYS := [
	"response_code",
	"purchases",
	"purchase_state",
	"purchase_token",
	"is_acknowledged",
	"product_ids",
	"product_details",
	"product_id",
	"one_time_purchase_offer_details",
	"formatted_price",
]

## Yalnızca eski sürümler için yedekte tutulan adlar: eklentide OLMAMALARI
## normaldir, bu yüzden aranmazlar. Listede durmaları "bunlar bilerek yedek"
## demek — sessizce silinip sonra geri eklenmesinler diye.
const LEGACY_FALLBACK_KEYS := [
	"products",
	"product_details_list",
	"productDetailsList",
]

var failures := 0
var checks := 0


func check(cond: bool, label: String) -> void:
	checks += 1
	if cond:
		print("  OK   ", label)
	else:
		failures += 1
		printerr("  FAIL ", label)


## Anahtar adını ikili yığında arar.
##
## Metne çevirip `contains` demek İŞE YARAMAZ: sınıf dosyaları NUL dolu ve
## `get_string_from_ascii()` ilk NUL'da durur — ilk denemede tüm anahtarlar
## "bulunamadı" çıkmıştı. Bu yüzden arama bayt düzeyinde: ilk baytın geçtiği
## yerler C++ tarafında bulunur, her aday için kısa bir dilim karşılaştırılır.
func _blob_has(bytes: PackedByteArray, key: String) -> bool:
	var needle := key.to_ascii_buffer()
	var n := needle.size()
	if n == 0:
		return false
	var idx := bytes.find(needle[0])
	while idx >= 0 and idx + n <= bytes.size():
		if bytes.slice(idx, idx + n) == needle:
			return true
		idx = bytes.find(needle[0], idx + 1)
	return false


## `.aar` → `classes.jar` → tüm `.class` baytları tek yığın.
func _plugin_blob() -> PackedByteArray:
	var aar := ZIPReader.new()
	if aar.open(AAR_PATH) != OK:
		return PackedByteArray()
	var jar_bytes := aar.read_file("classes.jar")
	aar.close()
	if jar_bytes.is_empty():
		return PackedByteArray()
	var f := FileAccess.open(JAR_TMP, FileAccess.WRITE)
	if f == null:
		return PackedByteArray()
	f.store_buffer(jar_bytes)
	f.close()

	var jar := ZIPReader.new()
	if jar.open(JAR_TMP) != OK:
		return PackedByteArray()
	var blob := PackedByteArray()
	for name in jar.get_files():
		if not name.ends_with(".class"):
			continue
		blob.append_array(jar.read_file(name))
	jar.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(JAR_TMP))
	return blob


func _ready() -> void:
	print("[1] Eklenti ikilisi okunuyor")
	var blob := _plugin_blob()
	check(blob.size() > 10000,
		"classes.jar açıldı ve sınıflar okundu (%d bayt)" % blob.size())
	if blob.is_empty():
		_finish()
		return

	var src := FileAccess.get_file_as_string(IAP_PATH)
	check(src != "", "iap.gd okunabildi")

	print("\n[2] iap.gd'nin okuduğu her anahtar eklentide var mı")
	for key: String in REQUIRED_KEYS:
		check(src.contains('"%s"' % key), "iap.gd '%s' anahtarını okuyor" % key)
		check(_blob_has(blob, key), "eklenti '%s' anahtarını gönderiyor" % key)

	print("\n[3] Yedek adlar bilerek duruyor")
	for key: String in LEGACY_FALLBACK_KEYS:
		check(src.contains('"%s"' % key),
			"'%s' yedek olarak korunuyor (eski eklenti sürümleri)" % key)

	print("\n[4] Tuzak: eklentide olmayan bir ad yakalanır mı")
	# Testin kendisinin çalıştığını gösteren negatif kontrol — bu ad hiçbir
	# eklenti sürümünde yok.
	check(not _blob_has(blob, "urun_kimlikleri_uydurma"),
		"uydurma bir anahtar eklentide bulunmuyor (arama gerçekten süzüyor)")
	_finish()


func _finish() -> void:
	print("=".repeat(64))
	if failures == 0:
		print("TÜM TESTLER GEÇTİ (%d kontrol)" % checks)
	else:
		printerr("%d/%d TEST BAŞARISIZ" % [failures, checks])
	get_tree().quit(1 if failures > 0 else 0)
