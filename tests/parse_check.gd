extends Node
## Depodaki HER GDScript dosyasını ayrıştırır.
##
## Paketin geri kalanı yalnızca çalıştırdığı sahneleri yükler. Hiçbir testin
## dokunmadığı bir dosya (yardımcı araç, yeni eklenmiş ama henüz bağlanmamış bir
## ekran, tek seferlik bir repro betiği) ayrıştırma hatasıyla depoda durabilir ve
## paket yeşil kalır — hata ancak o yol ilk kez çalıştığında, yani oyuncuda
## patlar. Burada tek yaptığımız her `.gd`'yi yüklemek: ayrıştırma hatası hem
## `load()`'u null döndürür hem de koşucunun aradığı `SCRIPT ERROR` satırını
## bastırır.
##
## Kapsam `res://src` ve `res://tests`. `addons/` DIŞARIDA: üçüncü taraf
## eklentilerin editör tarafı betikleri (EditorPlugin, EditorExportPlugin)
## oyun çalışırken yüklenemez ve bizim sorumluluğumuz değil.
##
## Çalıştırma:
##   tools\Godot_v4.7-stable_win64_console.exe --headless --path . res://tests/parse_check.tscn

const ROOTS := ["res://src", "res://tests"]

var failures := 0
var checks := 0


func check(cond: bool, label: String) -> void:
	checks += 1
	if cond:
		print("  OK   ", label)
	else:
		failures += 1
		printerr("  FAIL ", label)


func _collect(dir_path: String, out: Array) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		var full := dir_path.path_join(name)
		if d.current_is_dir():
			_collect(full, out)
		elif name.ends_with(".gd"):
			out.append(full)
		name = d.get_next()
	d.list_dir_end()


func _ready() -> void:
	var files: Array = []
	for root: String in ROOTS:
		_collect(root, files)
	files.sort()
	print("[1] %d GDScript dosyası ayrıştırılıyor" % files.size())
	check(files.size() > 20, "beklenen sayıda dosya bulundu (%d)" % files.size())

	var bad: Array[String] = []
	for path: String in files:
		var res := load(path)
		if res == null or not (res is GDScript):
			bad.append(path)
	check(bad.is_empty(), "hepsi ayrıştırıldı%s"
		% ("" if bad.is_empty() else " — kırık: " + ", ".join(bad)))

	print("=".repeat(64))
	if failures == 0:
		print("TÜM TESTLER GEÇTİ (%d kontrol)" % checks)
	else:
		printerr("%d/%d TEST BAŞARISIZ" % [failures, checks])
	get_tree().quit(1 if failures > 0 else 0)
