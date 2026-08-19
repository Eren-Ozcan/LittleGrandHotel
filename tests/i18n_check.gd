extends Node
## Verification harness for the Turkish translation.
##
## Three things can quietly break localisation, and each is checked here:
##   1. a key in `data/i18n/strings.csv` that no longer matches the source
##      string (tr() then silently returns English),
##   2. a translated line whose `%` placeholders do not match the English one
##      (that crashes at format time, in whichever screen happens to use it),
##   3. a UI string in the source that never made it into the CSV at all.
##
## Run: tools\Godot_v4.7-stable_win64_console.exe --headless --path . res://tests/i18n_check.tscn

const CSV_PATH := "res://data/i18n/strings.csv"
const SOURCES := [
	"res://src/main.gd",
	"res://src/autoload/game.gd",
	"res://src/autoload/cloud_save.gd",
	"res://src/cloud/google_signin.gd",
]

var _failures := 0


func _fail(msg: String) -> void:
	_failures += 1
	print("FAIL: %s" % msg)


## "%s coins" -> ["%s"] — the ordered list of real conversions, with "%%"
## (a literal per cent sign) dropped because it consumes no argument.
func _specs(s: String) -> Array:
	var out: Array = []
	var i := 0
	while i < s.length():
		if s[i] != "%":
			i += 1
			continue
		if i + 1 < s.length() and s[i + 1] == "%":
			i += 2
			continue
		var j := i + 1
		while j < s.length() and not s[j] in ["d", "s", "f", "x", "c", "o"]:
			j += 1
		if j < s.length():
			out.append(s.substr(i, j - i + 1))
		i = j + 1
	return out


func _read_csv() -> Array:
	var f := FileAccess.open(CSV_PATH, FileAccess.READ)
	var rows: Array = []
	f.get_csv_line()  # header
	while not f.eof_reached():
		var line := f.get_csv_line()
		if line.size() >= 2 and line[0] != "":
			rows.append(line)
	return rows


func _source_text() -> String:
	var all := ""
	for path in SOURCES:
		all += FileAccess.get_file_as_string(path)
	return all


func _ready() -> void:
	var rows := _read_csv()
	print("[i18n] %d rows in %s" % [rows.size(), CSV_PATH])
	if rows.size() < 300:
		_fail("the CSV looks truncated (%d rows)" % rows.size())

	var source := _source_text()
	var data := FileAccess.get_file_as_string("res://data/economy.json")
	data += FileAccess.get_file_as_string("res://data/quests.json")
	data += FileAccess.get_file_as_string("res://data/achievements.json")

	TranslationServer.set_locale("tr")
	var seen := {}
	for row in rows:
		var key: String = row[0]
		var value: String = row[1]
		if seen.has(key):
			_fail("duplicate key: %s" % key)
		seen[key] = true

		# 1. The key has to still exist somewhere the game can produce it.
		if not source.contains(key) and not data.contains(key):
			_fail("key is in no source or data file: %s" % key)

		# 2. Same conversions, same order — otherwise `%` blows up at runtime.
		if _specs(key) != _specs(value):
			_fail("placeholders differ: %s  ->  %s" % [key, value])

		# 3. The lookup itself works.
		if tr(key) != value:
			_fail("lookup failed for: %s" % key)

	# 4. Nothing regressed to English on a screen we know by heart.
	for probe in ["Collect", "Start shift", "Delete account data", "Quests"]:
		if tr(probe) == probe:
			_fail("still English after switching to tr: %s" % probe)

	TranslationServer.set_locale("en")
	if tr("Collect") != "Collect":
		_fail("English locale does not fall back to the key")

	print("[i18n] %s" % ("FAILURES: %d" % _failures if _failures > 0 else "all checks passed"))
	get_tree().quit(1 if _failures > 0 else 0)
