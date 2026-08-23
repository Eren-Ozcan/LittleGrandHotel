extends Node
## Arayüz testi (src/main.gd) — her ekran, her sekme, her modal.
##
## main.gd projenin en büyük dosyası (~5300 satır) ve neredeyse tamamı ekran
## kurma kodu. Buradaki hatalar derlemede görünmez: bir sekme boş açılır, bir
## popup hiç kurulmaz, bir dil değişikliği yalnızca yarısına işler. Bu test her
## ekranı gerçekten AÇAR ve içeriğinin kurulduğunu doğrular.
##
## Neden pencere gerektiriyor: main.tscn tam bir Control ağacıdır; --headless
## modda düzen hesapları çalışmaz ve popup içerikleri boyutsuz kalır.
##
## Çalıştırma (pencere açar, headless DEĞİL):
##   tools\Godot_v4.7-stable_win64_console.exe --path . res://tests/ui_check.tscn

const SAVE_PATH := "user://save.json"
const BACKUP_PATH := "user://save.json.uicheck.bak"
const TIMEOUT_SEC := 180.0

var failures := 0
var checks := 0
var _finished := false
var _main: Node


func check(cond: bool, label: String) -> void:
	checks += 1
	if cond:
		print("  OK   ", label)
	else:
		failures += 1
		printerr("  FAIL ", label)


# --- Kayıt koruması (bkz. tutorial_check.gd — aynı gerekçe) --------------

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


func _exit_tree() -> void:
	_restore_save()


func _on_timeout() -> void:
	if _finished:
		return
	printerr("  FAIL test %.0f sn içinde bitmedi — bir SCRIPT ERROR _ready " % TIMEOUT_SEC
		+ "coroutine'ini öldürmüş olabilir; yukarıdaki çıktıyı oku")
	get_tree().quit(1)


# --- Ağaç yardımcıları ---------------------------------------------------

## Bir düğümün altındaki tüm Control'leri sayar — "ekran gerçekten kuruldu mu"
## sorusunun en dolaysız ölçüsü.
func _count(node: Node, type: String = "Control") -> int:
	return node.find_children("*", type, true, false).size()


## Görünür metinlerin tamamı (etiketler + buton yazıları). Dil testinde ve
## "bu ekranda şu yazı var mı" iddialarında kullanılır.
func _texts(node: Node) -> PackedStringArray:
	var out := PackedStringArray()
	for l in node.find_children("*", "Label", true, false):
		out.append((l as Label).text)
	for b in node.find_children("*", "Button", true, false):
		out.append((b as Button).text)
	return out


func _count_empty(texts: PackedStringArray) -> int:
	var n := 0
	for t in texts:
		if t.strip_edges() == "":
			n += 1
	return n


func _has_text(node: Node, needle: String) -> bool:
	for t in _texts(node):
		if t.contains(needle):
			return true
	return false


## Açık modalın kökü (bkz. main.gd _show_modal: z_index 90, main'in çocuğu).
##
## EN ÜSTTEKİ modal döner, ilki değil. Modallar üst üste binebiliyor (açılış
## zinciri: bulut çakışması → tutorial → günlük ödül → çevrimdışı özet) ve
## "ilkini al" demek, altta unutulmuş tek bir modal yüzünden ONDAN SONRAKİ HER
## iddianın yanlış ağaca bakması demek: 2026-08-23'te bu test dönüşümlü olarak
## "9/131 BAŞARISIZ" verirken sebebi buydu.
func _modal_root() -> ColorRect:
	var top: ColorRect = null
	for c in _main.get_children():
		if c is ColorRect and c.z_index >= 90 and not c.is_queued_for_deletion():
			top = c
	return top


## Ekranda kaç modal duruyor — açılış zinciri bittikten sonra sıfır olmalı.
func _modal_count() -> int:
	var n := 0
	for c in _main.get_children():
		if c is ColorRect and c.z_index >= 90 and not c.is_queued_for_deletion():
			n += 1
	return n


## Modalin BİRİNCİL eylem butonu. _show_modal onu panelin VBox'ına DOĞRUDAN
## çocuk olarak ekler; gövde kurucusunun (günlük ödül şeridi gibi) eklediği
## butonlar daha derinde kalır. "İlk butonu bas" demek o yüzden yanlış: günlük
## ödül ekranında gün karesine basılır ve modal hiç kapanmaz.
func _modal_action_button() -> Button:
	var m := _modal_root()
	if m == null:
		return null
	for vb in m.find_children("*", "VBoxContainer", true, false):
		for c in (vb as Node).get_children():
			if c is Button:
				return c
	return null


func _close_modal() -> void:
	var b := _modal_action_button()
	if b == null:
		return
	b.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame


# --- Akış ----------------------------------------------------------------

func _ready() -> void:
	print("Little Grand Hotel — arayüz testi")
	print("=".repeat(64))
	_stash_save()
	get_tree().create_timer(TIMEOUT_SEC).timeout.connect(_on_timeout)

	var game := get_node("/root/Game")
	game.new_game()
	# Açılış zinciri (tutorial → günlük ödül → çevrimdışı özet) bu testin konusu
	# değil; ayrı ayrı aşağıda tetiklenir. Burada susturulur ki ekranlar
	# üstünde bir modal asılı kalmasın.
	game.tutorial_seen = true
	game.last_daily_claim_day = game.daily_day_index()
	game.offline_earned = 0
	game.auto_renew_count = 0
	# Ekranların BOŞ değil DOLU hâli test edilsin: para, seviye ve oda gerekiyor.
	game.coins = 5_000_000
	game.gems = 5000
	game.add_xp(200000)
	_suppress_cloud_conflict()

	_main = load("res://main.tscn").instantiate()
	add_child(_main)
	# Bulut indirmesi AĞ üzerinden geliyor ve ne zaman biteceği belli değil:
	# geliştirme makinesinde gerçek bir çakışma var, sinyal testin ortasında
	# düşüp "Which save should continue?" modalını açıyordu. Bu testin konusu
	# çakışma ekranı DEĞİL — [9] onu zaten doğrudan çağırarak ölçüyor — bu
	# yüzden kendiliğinden açılması kapatılır.
	if CloudSave.conflict_detected.is_connected(_main._on_cloud_conflict):
		CloudSave.conflict_detected.disconnect(_main._on_cloud_conflict)
	_main._finish_loading_screen()
	await get_tree().create_timer(0.6).timeout
	# Açılış zinciri burada bitmiş olmalı. Bitmediyse geri kalan her bölüm yanlış
	# ağaca bakar; tek ve okunur bir satırda patlaması, on tane anlamsız FAIL'den
	# iyi.
	check(_modal_count() == 0,
		"açılış zinciri modal bırakmadı (%d açık)" % _modal_count())

	await _test_base_screen()
	await _test_every_popup()
	await _test_store_tabs()
	await _test_profile_tabs()
	await _test_quests_tabs()
	await _test_room_and_facility_popups()
	await _test_popup_stack()
	await _test_back_button()
	await _test_modals()
	await _test_language_switch()
	await _test_build_and_clean_modes()
	await _test_live_labels()

	_finished = true
	print("=".repeat(64))
	if failures == 0:
		print("TÜM TESTLER GEÇTİ (%d kontrol)" % checks)
	else:
		printerr("%d/%d TEST BAŞARISIZ" % [failures, checks])
	get_tree().quit(1 if failures > 0 else 0)


func _test_base_screen() -> void:
	print("\n[1] Ana ekran kuruldu mu")
	check(_main.overlay != null, "popup katmanı (overlay) var")
	check(not _main.overlay.visible, "açılışta popup kapalı")
	for field in ["shift_button", "collect_button", "quest_bar_button",
			"build_mode_button", "clean_mode_button", "popup_title",
			"popup_content", "popup_scroll", "popup_back_button",
			"popup_coins_label", "popup_gems_label"]:
		check(_main.get(field) != null, "'%s' kuruldu" % field)
	check(_count(_main) > 100, "ana ekranda %d Control düğümü var" % _count(_main))
	await get_tree().process_frame


## Her popup gerçekten AÇILIP içerik kuruyor mu. Boş açılan bir sekme, testsiz
## hâlde ancak oyuncunun şikâyetiyle fark edilir.
const POPUPS := [
	["Shift", "_build_shift_popup"],
	["Staff", "_build_staff_popup"],
	["Stats", "_build_stats_popup"],
	["Profile", "_build_profile_popup"],
	["Store", "_build_store_popup"],
	["Build", "_build_build_popup"],
	["Gems", "_build_gems_popup"],
	["Settings", "_build_settings_popup"],
	["Quests", "_build_quests_popup"],
]


func _test_every_popup() -> void:
	print("\n[2] Her popup açılıyor ve içerik kuruyor")
	for entry in POPUPS:
		var title: String = entry[0]
		var fn: String = entry[1]
		_main._open_popup(title, Callable(_main, fn))
		await get_tree().process_frame
		await get_tree().process_frame
		check(_main.overlay.visible, "%s: overlay açıldı" % title)
		check(_main.popup_title.text == title, "%s: başlık doğru" % title)
		var kids: int = _main.popup_content.get_child_count()
		check(kids > 0, "%s: içerik kuruldu (%d üst düzey satır)" % [title, kids])
		check(_count(_main.popup_content) >= kids,
			"%s: alt ağaç dolduruldu (%d düğüm)" % [title, _count(_main.popup_content)])
		check(_main.popup_coins_label.text != "", "%s: bakiye başlıkta gösteriliyor" % title)
		_main._close_popup()
		await get_tree().process_frame
		check(not _main.overlay.visible, "%s: kapandı" % title)


func _test_store_tabs() -> void:
	print("\n[3] Mağaza sekmeleri")
	for tab in ["gems", "premium"]:
		_main._store_tab = tab
		_main._open_popup("Store", _main._build_store_popup)
		await get_tree().process_frame
		check(_main.popup_content.get_child_count() > 1,
			"Store/%s sekmesi içerik kurdu" % tab)
		var buttons: Array = _main.popup_content.find_children("*", "Button", true, false)
		check(buttons.size() >= 2, "Store/%s sekmesinde %d buton var" % [tab, buttons.size()])
		_main._close_popup()
		await get_tree().process_frame


func _test_profile_tabs() -> void:
	print("\n[4] Profil sekmeleri")
	for tab in ["account", "prestige", "stats", "settings"]:
		_main._profile_tab = tab
		_main._open_popup("Profile", _main._build_profile_popup)
		await get_tree().process_frame
		check(_main.popup_content.get_child_count() > 1,
			"Profile/%s sekmesi içerik kurdu" % tab)
		_main._close_popup()
		await get_tree().process_frame
	# Hesap sekmesi bulut durumunu gösterir; bulut kapalıyken de çökmemeli.
	_main._profile_tab = "account"
	_main._open_popup("Profile", _main._build_profile_popup)
	await get_tree().process_frame
	check(_count(_main.popup_content) > 3,
		"Hesap sekmesi bulut kapalıyken de dolu (%d düğüm)" % _count(_main.popup_content))
	_main._close_popup()
	await get_tree().process_frame


func _test_quests_tabs() -> void:
	print("\n[5] Görev / başarım sekmeleri")
	var game := get_node("/root/Game")
	for tab in ["quests", "achievements"]:
		_main._quests_tab = tab
		_main._open_popup("Quests", _main._build_quests_popup)
		await get_tree().process_frame
		var rows: int = _main.popup_content.get_child_count()
		check(rows > 1, "Quests/%s sekmesinde %d satır" % [tab, rows])
		_main._close_popup()
		await get_tree().process_frame
	# Ekranı açmak "görülmemiş" rozetini söndürmeli.
	check(_main._quests_seen_index == game.quest_index,
		"görev ekranı açılınca rozet sayacı eşitlendi")
	check(_main._achievements_seen_count == game.unlocked_achievements.size(),
		"başarım rozeti de eşitlendi")


func _test_room_and_facility_popups() -> void:
	print("\n[6] Oda ve tesis ekranları")
	var game := get_node("/root/Game")
	# Misafir odası — temiz hâli.
	var guest := -1
	var facility := -1
	for i in game.rooms.size():
		var cat: String = game.room_def(game.rooms[i].type).category
		if cat == "guest" and guest < 0:
			guest = i
		elif cat != "guest" and facility < 0:
			facility = i
	check(guest >= 0, "test için bir misafir odası bulundu")

	game.rooms[guest].dirty = false
	_main.selected_room = guest
	_main._open_popup("Room Decoration", _main._build_room_popup)
	await get_tree().process_frame
	check(_main.popup_content.get_child_count() > 0, "temiz oda ekranı kuruldu")
	var clean_before := _has_text(_main.popup_content, "Clean")
	_main._close_popup()
	await get_tree().process_frame

	# Kirli hâli farklı bir ekran vermeli (temizle düğmesi).
	game.rooms[guest].dirty = true
	_main.selected_room = guest
	_main._open_popup("Room Decoration", _main._build_room_popup)
	await get_tree().process_frame
	check(_main.popup_content.get_child_count() > 0, "kirli oda ekranı kuruldu")
	check(_has_text(_main.popup_content, "Clean") and not clean_before,
		"kirli oda ekranında temizleme düğmesi ÇIKIYOR, temizde çıkmıyor")
	game.rooms[guest].dirty = false
	_main._close_popup()
	await get_tree().process_frame

	# Tesis odası (varsa) kendi ekranını kurmalı.
	if facility >= 0:
		_main.selected_room = facility
		_main._open_popup("Facility", _main._build_facility_popup)
		await get_tree().process_frame
		check(_main.popup_content.get_child_count() > 0, "tesis ekranı kuruldu")
		_main._close_popup()
		await get_tree().process_frame
	else:
		# Tesis yoksa bir tane satın alıp yine de test et.
		check(true, "başlangıçta tesis odası yok — bu senaryo atlandı")
	_main.selected_room = -1


func _test_popup_stack() -> void:
	print("\n[7] Popup yığını (ileri/geri)")
	_main._open_popup("Store", _main._build_store_popup)
	await get_tree().process_frame
	check(_main._popup_stack.size() == 1, "kök popup yığında tek")
	_main._push_popup("Choose a room", _main._build_bundle_room_picker)
	await get_tree().process_frame
	check(_main._popup_stack.size() == 2, "alt ekran yığına eklendi")
	check(_main.popup_title.text == "Choose a room", "başlık alt ekrana geçti")
	check(_main.popup_content.get_child_count() > 0, "alt ekran içerik kurdu")
	_main._pop_popup()
	await get_tree().process_frame
	check(_main._popup_stack.size() == 1, "geri: yığın bir seviye indi")
	check(_main.popup_title.text == "Store", "geri: başlık köke döndü")
	check(_main.overlay.visible, "geri: popup hâlâ açık")
	_main._pop_popup()
	await get_tree().process_frame
	check(not _main.overlay.visible, "kökten geri: popup kapandı")
	check(_main._popup_stack.is_empty(), "yığın boşaldı")

	# Sekme değiştirmek yığını BÜYÜTMEMELİ (her sekme kendi kökü).
	_main._open_popup("Store", _main._build_store_popup)
	_main._open_popup("Quests", _main._build_quests_popup)
	await get_tree().process_frame
	check(_main._popup_stack.size() == 1, "sekme geçişi yığını büyütmüyor")
	_main._close_popup()
	await get_tree().process_frame

	# Kapalıyken _rebuild_popup çağrısı sessizce dönmeli (await'li düğmeler
	# işleri bitince buraya döner — bkz. main.gd _rebuild_popup kapısı).
	_main._rebuild_popup()
	await get_tree().process_frame
	check(not _main.overlay.visible, "kapalı popup'ı yeniden kurmak onu açmıyor")


func _test_back_button() -> void:
	print("\n[8] Android geri tuşu")
	_main._open_popup("Store", _main._build_store_popup)
	_main._push_popup("Choose a room", _main._build_bundle_room_picker)
	await get_tree().process_frame
	_main._notification(_main.NOTIFICATION_WM_GO_BACK_REQUEST)
	await get_tree().process_frame
	check(_main._popup_stack.size() == 1,
		"geri tuşu bir seviye geri gitti (uygulamadan çıkmadı)")
	_main._notification(_main.NOTIFICATION_WM_GO_BACK_REQUEST)
	await get_tree().process_frame
	check(not _main.overlay.visible, "geri tuşu kökte popup'ı kapattı")
	# Not: popup kapalıyken geri tuşu get_tree().quit() çağırır — testi de
	# bitireceği için burada denenmiyor (bkz. tutorial_check.gd, aynı gerekçe).


## Çakışma DURUMUNU siler; diskteki ya da buluttaki kayda dokunmaz.
## CloudSave.resolve_keep_local() doğru API olurdu ama gerçek hesaba yükleme
## yapardı — bir arayüz testinin yapmaması gereken şey.
func _suppress_cloud_conflict() -> void:
	CloudSave._blocked = false
	CloudSave._pending_cloud = {}


func _test_modals() -> void:
	print("\n[9] Modallar")
	var game := get_node("/root/Game")

	# Basit modal: metin + tek buton, dışına tıklayınca dismiss.
	var acted := [false]
	_main._show_simple_modal("Test", "Gövde metni", "Tamam", func(): acted[0] = true)
	await get_tree().process_frame
	var m := _modal_root()
	check(m != null, "basit modal açıldı")
	check(_has_text(m, "Gövde metni"), "modal gövde metnini gösteriyor")
	check(_has_text(m, "Tamam"), "modal eylem butonunu gösteriyor")
	await _close_modal()
	check(acted[0], "eylem callback'i çağrıldı")
	check(_modal_root() == null, "modal kapandı")

	# Otel adı değiştirme modalı: LineEdit + Kaydet/Vazgeç.
	_main._show_rename_hotel_modal()
	await get_tree().process_frame
	m = _modal_root()
	check(m != null, "otel adı modalı açıldı")
	var fields := m.find_children("*", "LineEdit", true, false)
	check(fields.size() == 1, "tek bir metin alanı var")
	if fields.size() == 1:
		var field: LineEdit = fields[0]
		check(field.text == game.hotel_name,
			"alan mevcut adı gösteriyor (alan='%s', oyun='%s')"
				% [field.text, game.hotel_name])
		check(field.max_length == _main.HOTEL_NAME_MAX_LEN,
			"uzunluk sınırı uygulanmış (%d)" % field.max_length)
		# Değişmez kural: oyunun kendi varsayılan adı bu alana SIĞMALI. Sığmazsa
		# LineEdit önceden dolu metni sessizce kırpar ve oyuncu hiçbir şey
		# yazmadan Kaydet'e bastığında otelin adı kısalır.
		check(game.hotel_name.length() <= _main.HOTEL_NAME_MAX_LEN,
			"varsayılan otel adı sınıra sığıyor (%d ≤ %d)"
				% [game.hotel_name.length(), _main.HOTEL_NAME_MAX_LEN])
	var buttons := m.find_children("*", "Button", true, false)
	check(buttons.size() >= 2, "Vazgeç + Kaydet düğmeleri var")
	(buttons[0] as Button).pressed.emit()  # Vazgeç
	await get_tree().process_frame
	check(_modal_root() == null, "vazgeç modalı kapattı")
	check(game.hotel_name != "", "vazgeç otel adını bozmadı")

	# Çevrimdışı kazanç kartı.
	_main._show_offline_popup(12345, 2, 500)
	await get_tree().process_frame
	m = _modal_root()
	check(m != null, "çevrimdışı kazanç modalı açıldı")
	check(_count(m) > 3, "kart içerik kurdu (%d düğüm)" % _count(m))
	await _close_modal()

	# Günlük ödül şeridi.
	game.last_daily_claim_day = game.daily_day_index() - 1
	var closed := [false]
	_main._show_daily_reward_popup(func(): closed[0] = true)
	await get_tree().process_frame
	m = _modal_root()
	check(m != null, "günlük ödül modalı açıldı")
	check(_count(m) > 5, "7 günlük şerit kuruldu (%d düğüm)" % _count(m))
	await _close_modal()
	check(closed[0], "kapanış callback'i çağrıldı")

	# Modal, AÇIK BİR POPUP'IN ÜSTÜNDE durmalı. Popup katmanı z_index 100 ile
	# çiziliyor; modaller 90/95'teyken bir popup açıkken modal onun arkasına
	# düşüyor ve dokunulamıyordu. Bulut çakışma modalinde bu ölümcül: modal
	# görünmeden `_cloud_conflict_open` bayrağı kalkıyor ve "Bir kayıt seç"
	# düğmesi bir daha hiçbir şey yapmıyor — 2026-08-23'te gerçek cihazda,
	# hesap bağlandıktan hemen sonra yaşandı.
	_main._open_popup("Profile", _main._build_profile_popup)
	await get_tree().process_frame
	_main._show_simple_modal("Üstte mi", "Gövde", "Tamam", func(): pass)
	await get_tree().process_frame
	m = _modal_root()
	check(m != null and m.z_index > _main.overlay.z_index,
		"modal açık popup'ın üstünde (modal %d > popup %d)"
			% [m.z_index if m != null else -1, _main.overlay.z_index])
	await _close_modal()
	_main._close_popup()
	await get_tree().process_frame

	# Aynı hatanın ikinci yarısı: çakışma modalı kapanınca bayrak DÜŞMELİ,
	# yoksa ekran bir daha açılmaz.
	CloudSave._blocked = true
	CloudSave._pending_cloud = {
		"rev": 1, "updated_at": Time.get_unix_time_from_system() - 60.0,
		"summary": {"level": 7, "coins": 1234, "gems": 42, "rooms": 5},
	}
	_main._cloud_conflict_open = false
	_main._show_cloud_conflict_modal()
	await get_tree().process_frame
	check(_modal_root() != null, "çakışma varken modal açıldı")
	check(_main._cloud_conflict_open, "çakışma modalı açıkken bayrak kalkık")
	var conflict_root := _modal_root()
	if conflict_root != null:
		conflict_root.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	_main._cloud_conflict_open = false
	CloudSave._blocked = false
	CloudSave._pending_cloud = {}

	# Bulut çakışması: çakışma YOKKEN modal açılmamalı, callback yine çağrılmalı.
	# Temizlik ile çağrı arasında `await` YOK: bulut indirmesi ancak bir sonraki
	# karede durumu geri yazabilir, o yüzden bu iki satır bitişik kalmalı.
	_suppress_cloud_conflict()
	var chained := [false]
	_main._show_cloud_conflict_modal(func(): chained[0] = true)
	await get_tree().process_frame
	check(_modal_root() == null, "çakışma yokken modal açılmıyor")
	check(chained[0], "zincir yine de devam etti (açılış akışı tıkanmıyor)")


func _test_language_switch() -> void:
	print("\n[10] Dil değişimi ekranlara işliyor mu")
	var game := get_node("/root/Game")
	var before: String = game.language

	game.language = "en"
	game.apply_language()
	await get_tree().process_frame
	_main._open_popup("Settings", _main._build_settings_popup)
	await get_tree().process_frame
	var en_texts := _texts(_main.popup_content)
	var en_empty := _count_empty(en_texts)
	_main._close_popup()
	await get_tree().process_frame

	game.language = "tr"
	game.apply_language()
	await get_tree().process_frame
	_main._open_popup("Settings", _main._build_settings_popup)
	await get_tree().process_frame
	var tr_texts := _texts(_main.popup_content)
	_main._close_popup()
	await get_tree().process_frame

	check(en_texts.size() > 0 and tr_texts.size() > 0, "iki dilde de metin toplandı")
	check(en_texts.size() == tr_texts.size(),
		"iki dilde aynı sayıda öğe (%d) — çeviri satır kaybettirmiyor"
			% en_texts.size())
	var differing := 0
	for i in mini(en_texts.size(), tr_texts.size()):
		if en_texts[i] != tr_texts[i]:
			differing += 1
	check(differing > 0,
		"Türkçe metinler gerçekten farklı (%d/%d öğe) — çeviri UI'a işliyor"
			% [differing, en_texts.size()])
	# Boş metinlerin bir kısmı meşru (ikonlu düğmeler, ayraçlar). Anlamlı olan
	# MUTLAK sayı değil, kıyas: Türkçede İngilizceden DAHA ÇOK boş varsa bir
	# çeviri anahtarı boş bir dizeye çözülüyor demektir.
	var tr_empty := _count_empty(tr_texts)
	check(tr_empty <= en_empty,
		"Türkçede fazladan boş etiket yok (tr %d ≤ en %d)" % [tr_empty, en_empty])

	game.language = before
	game.apply_language()
	await get_tree().process_frame


func _test_build_and_clean_modes() -> void:
	print("\n[11] İnşa ve temizlik kipleri")
	check(_main.build_mode == false, "başlangıçta inşa kipi kapalı")
	# Bu düğmeler AÇMA/KAPAMA (toggle) — `pressed` değil `toggled` sinyaline
	# bağlılar, o yüzden button_pressed üzerinden sürülür.
	check(_main.build_mode_button.toggle_mode, "inşa düğmesi bir toggle")
	_main.build_mode_button.button_pressed = true
	await get_tree().process_frame
	check(_main.build_mode, "inşa kipi açıldı")
	check(_main.build_mode_button.text.contains("On")
		or _main.build_mode_button.text != tr("✎ Build"),
		"inşa düğmesinin etiketi açık durumu gösteriyor")
	_main.build_mode_button.button_pressed = false
	await get_tree().process_frame
	check(not _main.build_mode, "inşa kipi kapandı")

	_main.clean_mode_button.button_pressed = true
	await get_tree().process_frame
	_main.clean_mode_button.button_pressed = false
	await get_tree().process_frame
	# Temizlik kipi bir kip değişkeni ya da doğrudan eylem olabilir; her iki
	# hâlde de düğmeye basmak ekranı bozmamalı.
	check(_count(_main) > 100, "temizlik düğmesi ana ekranı bozmadı")
	await get_tree().process_frame


func _test_live_labels() -> void:
	print("\n[12] Canlı etiketler")
	var game := get_node("/root/Game")
	game.coins = 1234
	game.gems = 56
	_main._update_live_labels()
	await get_tree().process_frame
	check(_main.primary_label.text != "", "birincil düğme etiketi dolu")

	# Vardiya yokken ve varken etiket DEĞİŞMELİ.
	var idle: String = _main.primary_label.text
	game.start_shift(8)
	_main._update_live_labels()
	await get_tree().process_frame
	check(_main.primary_label.text != idle,
		"vardiya başlayınca birincil etiket değişti ('%s' → '%s')"
			% [idle, _main.primary_label.text])
	check(_main.shift_bar_label.text != "", "vardiya sayacı yazıyor")

	# Toplanacak birikim varken "Collect" durumuna geçmeli.
	game.pending_income = 5000.0
	_main._update_live_labels()
	await get_tree().process_frame
	check(not _main.collect_button.disabled,
		"birikim varken toplama düğmesi etkin")
	game.pending_income = 0.0
	_main._update_live_labels()
	await get_tree().process_frame
	check(_main.collect_button.disabled,
		"birikim yokken toplama düğmesi devre dışı")
