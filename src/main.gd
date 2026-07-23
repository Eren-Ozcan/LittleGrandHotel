extends Control
## Little Grand Hotel — arayüz (görsel sürüm).
## Hotel City'den ilham alan kesit "dollhouse" görünüm: parlak gökyüzü,
## sıcak cephe, duvar kağıtlı odalar, mobilya ve misafir görselleri.

const PALETTE := {
	"sky_top": Color("8fd0f5"),
	"sky_bottom": Color("ffe0ea"),
	"cream": Color("fff6e6"),
	"cream_dark": Color("f3e6cc"),
	"facade": Color("fbe6c4"),
	"facade_line": Color("e6b866"),
	"wood": Color("8a6642"),
	"wood_dark": Color("6e4f31"),
	"gold": Color("f6b83c"),
	"gold_soft": Color("ffd878"),
	"text": Color("5a3f22"),
	"muted": Color("a08a68"),
	"cream_text": Color("fdf6e3"),
	"green_deep": Color("1f7a44"),
	"banner_red": Color("e0554a"),
	"floor_wood": Color("c19a6f"),
	"locked": Color("6b5f52"),
	"frame": Color("2f2418"),
	"asphalt": Color("6b6f78"),
	"sidewalk": Color("c9c3b4"),
	"curb": Color("e0a83c"),
	"bar_dark": Color("3a2c4d"),
	"grass": Color("6cc24a"),
	"grass_dark": Color("4e9e34"),
}

## Misafir oda tipine göre ayrı sanat havuzları: oyuncu daha pahalı oda
## Misafirler/sokak yürüyüşçüleri için karakter havuzu (referans sayfadaki
## 5 temel + 4 ekstra varyant) — tek tip 3'lü rotasyon yerine daha çeşitli.
const GUEST_TYPES := ["a", "b", "c", "d_elder", "e_couple", "f_business", "g_kid"]

## Açılış tutorial'ı: yalnızca yepyeni bir kayıtta (Game.tutorial_seen == false)
## sırayla gösterilen basit popup dizisi (bkz. _maybe_show_tutorial).
const TUTORIAL_STEPS := [
	{"title": "Hoş Geldin!", "text": "Little Grand Hotel'e hoş geldin! Küçük bir oteli adım adım büyük bir imparatorluğa dönüştüreceksin. Hadi kısaca göz atalım.", "btn": "İleri"},
	{"title": "1. Vardiyayı Başlat", "text": "Alt bardaki saat ikonuna dokunup bir vardiya başlat — otel yalnızca vardiya sırasında çalışır ve gelir üretir.", "btn": "İleri"},
	{"title": "2. Misafirleri Karşıla", "text": "Vardiya başlayınca misafirler kapıdan girip asansörle odalarına çıkar. Odalar doldukça gelir birikmeye başlar.", "btn": "İleri"},
	{"title": "3. Kasadan Topla", "text": "Biriken geliri almak için üstteki coin sayacına dokun. Toplamayı unutma — birikim vardiya bitene kadar kasada bekler.", "btn": "İleri"},
	{"title": "4. Odaları Dekore Et", "text": "Bir odaya dokunup eşya satın al — Stil Puanı arttıkça oda kademe atlar, otelinin yıldızı yükselir.", "btn": "İleri"},
	{"title": "5. Görevleri Takip Et", "text": "Alt bardaki görev ikonundan aktif görevini görebilirsin — her görev coin ve elmas ödülü verir. Şimdi kapıları aç!", "btn": "Başla!"},
]


## Dekor eşyalarının oda kartı içindeki sabit bölgeleri (fractional
## anchor konumları, 0..1) — "avizenin olması gerektiği yerde durması gibi"
## (bkz. kullanıcı isteği). Aynı bölgeyi paylaşan eşyalar sırayla bu
## slotlara oturur; slot taşarsa (nadiren) fazlası gösterilmez.
const ANCHOR_POSITIONS := {
	"ceiling": [Vector2(0.5, 0.16)],
	"wall": [Vector2(0.16, 0.3), Vector2(0.84, 0.3)],
	"surface": [Vector2(0.18, 0.58)],
	"floor_rug": [Vector2(0.5, 0.86)],
	"floor_side": [Vector2(0.14, 0.86), Vector2(0.5, 0.7), Vector2(0.86, 0.86)],
}

const WALLPAPERS := {
	"standard": Color("dcebf5"),
	"deluxe": Color("f7e2e6"),
	"suite": Color("eee4f7"),
	"cafe": Color("ffe2b0"),
	"gym": Color("bfe8ee"),
	"pool": Color("b8ecf5"),
	"cinema": Color("d9cdf2"),
	"spa": Color("cdeecb"),
	"restaurant": Color("ffdcae"),
	"roof_garden": Color("cdeeb8"),
	"housekeeping": Color("efe4cc"),
}

const SPEEDS: Array[float] = [1.0, 60.0, 3600.0]
var speed_index := 0

## Serbest blok yerleşimi (v2 render): tek hücre boyutu + bina şeridinin
## sabit toplam genişliği (Game.eco.building.grid_cols × CELL_W).
const CELL_W := 90.0
const CELL_H := 112.0
const CELL_GAP := 12.0
const STREET_H := 90.0
## Kullanıcı geri bildirimi: eski 84 değerinde lobi sahnesindeki (lobby.svg)
## altın asansör dikeyde tam sığmıyordu (STRETCH_KEEP_ASPECT_COVERED geniş
## kesiti kırpıyordu) — yükseklik artırıldı.
const LOBBY_H := 120.0
const GRASS_H := 22.0
## Lobinin sağ ucundaki giriş boşluğu: duvar burada kesilir, misafirler
## vardiya açılışında bu noktaya doğru yürür (bkz. _guest_walk_in).
const DOOR_W := 60.0
## Asansör "yakınlık" tetikleyicisi: lobi yürüyüşü sırasında misafirin gerçek
## x konumu asansör merkezine (elev_x) bu mesafeden daha çok yaklaşınca kapı
## tepki verir — sabit bir bekleme süresi yerine (bkz. _spawn_lobby_walker).
const ELEVATOR_PROXIMITY_RADIUS := 28.0
## ZOOM_MIN artık mutlak taban değil, yalnızca güvenlik altsınırı: gerçek
## alt sınır _effective_zoom_min()'de bina boyutuna göre dinamik hesaplanır
## (bina viewport'u tam doldurduğu noktanın ötesine geçilemez — "minicik
## bina" sorununu önler).
const ZOOM_MIN := 0.28
const ZOOM_MAX := 1.5
const PAN_DRAG_THRESHOLD := 6.0

## Haftalık dekorasyon teması: sunucusuz, Game.current_week_index()'e göre
## deterministik seçilir — çatı tabelasını hafta boyunca tek renkte boyar.
const WEEKLY_THEMES := [
	{ "name": "Klasik Kırmızı", "accent": Color("a83e35") },
	{ "name": "Yaz Esintisi", "accent": Color("1f8a8c") },
	{ "name": "Altın Çağ", "accent": Color("b8860b") },
	{ "name": "Lavanta Molası", "accent": Color("6a4c93") },
	{ "name": "Orman Nefesi", "accent": Color("2f7a4f") },
	{ "name": "Mercan Gün Batımı", "accent": Color("c9622a") },
	{ "name": "Kış Masalı", "accent": Color("2f6fa8") },
]

var coins_label: Label
var gems_label: Label
var star_icons: Array = []
var level_label: Label
var xp_bar: ProgressBar
var shift_label: Label
var shift_bar_label: Label
var collect_button: Button
var street_node: Control
var quest_hint: Label
var toast_panel: PanelContainer
var toast_label: Label

## Asansör: kapı animasyonu (kapalı→aralık→açık→aralık→kapalı) + kaldırımda
## bekleyen misafir sayacı. Kullanıcı isteği: misafirler yaklaşınca kapı
## açılsın, binsinler, kapansın, ~1sn sonra "odalarında" belirsinler; 2+
## misafir varsa hepsi tek seferde binsin (sırayla beklemesinler) — bu da
## kuyruğun süresiz büyüyüp sabit kalması sorununu çözer (eskiden kuyruk
## Game.rooms.size()'a bağlı sabit bir sayıydı, hiç azalmıyordu).
var elevator_tex: TextureRect
var _queue_count := 0
var _elevator_state := "closed"  # closed / opening_half / open / closing_half
var _elevator_timer := 0.0
## Asansörün önünde GÖRÜNÜR biçimde bekleyen (henüz binmemiş) misafir
## ikonları. _spawn_lobby_walker artık misafiri elev_x'e varır varmaz
## soldurup silmiyor — proximity tetikleyicisiyle _queue_count'a yazıldığı
## anda burada tutulup, kapı gerçekten açılıp (_boarding'e aktarılınca)
## _board_waiting_guests() ile "biniyor" gibi kayboluyor. Eskiden misafir
## kapı önünde beklerken görünmez olup kapının tepkisiz görünmesine yol
## açabiliyordu ("asansör müşterinin yanında açılmıyor" şikâyeti).
var _waiting_guest_icons: Array = []
## Yaya akışı iki bağımsız kanaldan yürür (bkz. _update_pedestrians):
## 1) "gelip geçen" yayalar — vardiyadan BAĞIMSIZ, seyrek/rastgele aralıkla
##    (kullanıcı isteği: "vardiya yokken de insanlar yürümeli, ara ara").
## 2) otele gelen misafirler — yalnızca vardiyada; hız oda sayısına göre
##    ölçeklenir (~2 dakikada tüm odalar dolacak tempo) ve boş oda kalmadıysa
##    yeni misafir gelmez (kullanıcı isteği: "çok insan yürüyor, azalt").
var _ambient_timer := 0.0
var _next_ambient := 6.0
var _arrival_timer := 0.0
var _next_arrival := 8.0
## Kapıya/lobiye doğru hâlâ YOLDA olan (kuyruğa henüz yazılmamış) misafir
## sayısı — boş odadan fazla misafir yola çıkmasın diye kotaya dahil edilir.
var _inbound := 0
## Asansöre binen (kapı açıkken içeri alınan) misafir sayısı — kapı kapanıp
## ~1sn geçince _arrived_guests'e aktarılır.
var _boarding := 0
## Asansörle YUKARI ÇIKMIŞ toplam misafir: odalardaki misafir görselleri
## artık vardiya başlar başlamaz hepsi birden değil, ancak misafir gerçekten
## asansörle çıktıkça beliriyor (kullanıcı isteği: "oyun direkt odada
## insanlar ile başlıyor" şikâyeti).
var _arrived_guests := 0
## Yürüyen yayaların yaşadığı, _rebuild_hotel'in SİLMEDİĞİ kalıcı katman —
## building_canvas'ın çocuğu olduğu için zoom/pan'i dünyayla birlikte alır
## (eskiden yayalar ekran-uzayında root'a ekleniyordu; kullanıcı pan/zoom
## yapınca kaldırımdan kopup havada asılı kalıyorlardı).
var _walker_layer: Control = null
var _did_initial_fit := false

## Serbest yerleşim bina görünümü: zoom_viewport (sabit, clip'li pencere) →
## building_canvas (manuel konumlandırılan, ölçeklenen/kaydırılan tuval —
## kat sıraları + lobi + sokak + çim hepsi burada, birlikte zoom/pan alır).
var zoom_viewport: Control
var building_canvas: Control
var roof_panel: PanelContainer
var roof_title_label: Label
var roof_theme_label: Label
var new_floor_button: Button
var build_mode_button: Button
## İnşa Modu kapalıyken boş/kilitli hücreler sade durur (buton/metin yok);
## açıkken vurgulanır ve dokunulabilir olur (TODO: görsel kalabalığı azaltma).
var build_mode := false
var _zoom := 1.0
var _canvas_pan := Vector2.ZERO
var _pan_dragging := false
var _pan_drag_start := Vector2.ZERO
var _pan_start_canvas_pos := Vector2.ZERO

var overlay: Control
var popup_title: Label
var popup_content: VBoxContainer
var popup_builder: Callable = Callable()

var selected_room := -1
## Taşıma modunda seçili odanın kararlı kimliği ("" = taşıma modu kapalı).
var move_from := ""

## Odayı basılı tutup sürükleyerek taşıma (kullanıcı isteği: "Taşı" butonuyla
## iki-dokunuşlu seçim yerine gerçek sürükle-bırak). "Taşı" butonu da (bkz.
## move_from) hâlâ çalışır — bu, aynı hedefe ULAŞMANIN ikinci bir yolu.
## Yeni oda eklemek de aynı sürükleme sistemini paylaşır: mağaza rafındaki
## bir kartı sürüklemek _drag_new_type'ı doldurur (_drag_room_id yerine).
## İkisi aynı anda dolu olamaz.
var _drag_room_id := ""
var _drag_new_type := ""
var _drag_active := false
var _drag_start_mouse := Vector2.ZERO
var _drag_ghost: Control = null

## İnşa Modu mağaza rafı: oda tipi kartları buradan tuvale sürüklenerek
## yerleştirilir (kullanıcı isteği: "açık olmayan odalar oluşturulmamış
## olmalı" — boş hücrelerde artık tıklanabilir bir "oda ekle" butonu yok).
var build_shop_panel: Control
var build_shop_row: HBoxContainer

var _walker: Control = null
var _walker_timer := 0.0
var _toast_timer := 0.0
var _tex_cache: Dictionary = {}
## Oda id'sine göre önceki rebuild'de üretilen görsel imza + düğüm çifti
## ({sig, button, wall}). _rebuild_hotel() artık HER odayı sıfırdan
## kurmuyor: bir odanın görsel imzası (bkz. _room_visual_signature) bir
## önceki rebuild'dekiyle aynıysa, o odanın Button/duvar düğümleri teardown
## sırasında silinmeden AYNEN korunuyor. 48 odalık gerçek üst sınırda tek
## bir "collect"/"quest tamamlandı" gibi odaları hiç etkilemeyen bir olay,
## artık 48 odanın hepsini değil, hiçbirini yeniden kurmuyor — asıl maliyet
## (Button + çoklu TextureRect + tween + sinyal kurulumu, oda başına) yalnızca
## GERÇEKTEN değişen odalar için ödeniyor (bkz. tests/perf_test.gd bench 1).
var _room_visual_cache: Dictionary = {}
var _sfx_players: Dictionary = {}
var music_player: AudioStreamPlayer


func _notification(what: int) -> void:
	# Android geri tuşu: proje ayarında quit_on_go_back kapatıldı, aksi halde
	# bir popup açıkken bile geri tuşu beklenmedik şekilde uygulamayı anında
	# kapatırdı. Popup açıksa yalnızca onu kapat, değilse normal çıkışı yap.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if overlay != null and overlay.visible:
			_close_popup()
		else:
			get_tree().quit()


func _ready() -> void:
	_build_ui()
	_init_sfx()
	# Uygulama, süregelen bir vardiyanın ortasında açıldıysa misafirler
	# çoktan yerleşmiş sayılır (gelir zaten akıyor) — odalar boş görünüp
	# yeniden dolmaya başlamasın. Taze vardiyada 0'dan başlar (asansör
	# teslim ettikçe artar, bkz. _deliver_guests / _make_room_button).
	if Game.shift_active():
		_arrived_guests = 999
	Game.state_changed.connect(_refresh)
	Game.quest_completed.connect(_on_quest_completed)
	Game.achievement_unlocked.connect(_on_achievement_unlocked)
	IAP.purchase_result.connect(_on_purchase_restored)
	Ads.rewarded_ad_result.connect(func(success: bool):
		if not success:
			_show_toast("Reklam şu an hazır değil, birazdan tekrar dene."))
	Game.leveled_up.connect(func(lv):
		_play("level")
		_show_toast("Seviye atladın! Seviye %d (+%d elmas)" % [lv, int(Game.eco.levelup_gems)]))
	_refresh()
	_maybe_show_tutorial()


## Uygulama açılışında sırayla kontrol edilen popup zinciri: önce (yepyeni
## kayıtta) tutorial, sonra günlük ödül, sonra "sen yokken" özeti.
func _maybe_show_tutorial() -> void:
	if Game.tutorial_seen:
		_after_tutorial()
		return
	_show_tutorial_step(0)


func _after_tutorial() -> void:
	if Game.daily_reward_available():
		_show_daily_reward_popup(_maybe_show_offline_popup)
	else:
		_maybe_show_offline_popup()


func _show_tutorial_step(step: int) -> void:
	if step >= TUTORIAL_STEPS.size():
		Game.tutorial_seen = true
		Game.save_game()
		_after_tutorial()
		return
	var s: Dictionary = TUTORIAL_STEPS[step]
	_show_simple_modal(String(s.title), String(s.text), String(s.btn),
		func(): _show_tutorial_step(step + 1),
		func():
			# Dışına tıklayarak/ESC ile atlandı — tüm tutorial'ı görülmüş say.
			Game.tutorial_seen = true
			Game.save_game()
			_after_tutorial())


## Gerçek mağazada zaten sahip olunan satın almalar bağlantı kurulunca otomatik
## geri gelir (cihaz değişimi/yeniden kurulum) — burada sessizce uygulanır; aktif
## satın alma akışının kendi buton callback'i ayrıca toast gösterir.
func _on_purchase_restored(product_id: String, success: bool) -> void:
	if not success:
		return
	match product_id:
		IAP.PRODUCT_REMOVE_ADS:
			if not Game.remove_ads:
				Game.remove_ads = true
				Game.save_game()
		IAP.PRODUCT_INCOME_2X:
			if Game.permanent_income_mult <= 1.0:
				Game.permanent_income_mult = 2.0
				Game.save_game()


func _maybe_show_offline_popup() -> void:
	if Game.offline_earned > 0 or Game.auto_renew_count > 0:
		_show_offline_popup(Game.offline_earned, Game.auto_renew_count, Game.auto_renew_spent)
		Game.offline_earned = 0
		Game.auto_renew_count = 0
		Game.auto_renew_spent = 0


func _process(delta: float) -> void:
	# İlk kare(ler)de layout oturunca bina genişliğe sığacak şekilde bir kez
	# otomatik zoom yapılır ("tam ekran otel" — bina soldan kırpık başlamasın).
	if not _did_initial_fit and zoom_viewport != null and zoom_viewport.size.x > 0.0:
		_did_initial_fit = true
		var canvas_w: float = int(Game.eco.building.grid_cols) * CELL_W
		_zoom = clampf(zoom_viewport.size.x / canvas_w, _effective_zoom_min(), ZOOM_MAX)
		_clamp_pan()
		_apply_canvas_transform()
	_update_live_labels()
	_update_walker(delta)
	_update_room_drag()
	_update_elevator(delta)
	_update_pedestrians(delta)
	if _toast_timer > 0.0:
		_toast_timer -= delta
		if _toast_timer <= 0.0:
			toast_panel.visible = false


## Asansör: kapı animasyonu (kapalı→aralık→açık→aralık→kapalı) + kaldırım
## kuyruğu sayacı. Bkz. üstteki değişken açıklaması için tasarım gerekçesi.
func _update_elevator(delta: float) -> void:
	if elevator_tex == null or not is_instance_valid(elevator_tex):
		return
	if not Game.shift_active():
		if _queue_count != 0 or _elevator_state != "closed" or _arrived_guests != 0:
			_queue_count = 0
			_boarding = 0
			_inbound = 0
			_arrived_guests = 0
			_elevator_state = "closed"
			_elevator_timer = 0.0
			_arrival_timer = 0.0
			for gicon in _waiting_guest_icons:
				if is_instance_valid(gicon):
					gicon.queue_free()
			_waiting_guest_icons.clear()
			elevator_tex.texture = _tex(_elevator_texture_path())
			# Vardiya bitti: odalardaki misafir görselleri hemen kalksın —
			# bu rebuild olmadan doğal süre dolumunda (state_changed sinyali
			# gelmediği için) misafirler odalarda asılı kalıyordu
			# ("vardiya bitirme tam çalışmıyor" şikâyetinin UI ayağı).
			_rebuild_hotel()
		return
	_elevator_timer += delta
	# Durum geçişleri artık _rebuild_hotel ÇAĞIRMIYOR (eskiden her saniyede
	# tam tuval yeniden kurulumu yapıp takılmalara yol açıyordu) — yalnızca
	# asansör dokusunu değiştiriyor; oda görselleri yalnızca misafir teslim
	# edilince (aşağıda, _deliver_guests içinde) yenileniyor.
	match _elevator_state:
		"closed":
			# Artık sabit bir bekleme yok: _queue_count yalnızca bir misafir
			# lobi yürüyüşünde FİİLEN elev_x'e ELEVATOR_PROXIMITY_RADIUS kadar
			# yaklaşınca artıyor (bkz. _spawn_lobby_walker) — yani kapı,
			# misafir gerçekten önündeyken açılıyor, keyfi bir süre
			# beklemiyor. Eski tasarımda kapı en son kapanışından beri geçen
			# süreyi sayardı; misafir kapı yeni kapanmışken varırsa görseli
			# kaybolup kapı hâlâ açılmıyordu ("asansör müşterinin yanında
			# açılmıyor" şikâyeti) — bu artık yapısal olarak imkânsız.
			if _queue_count > 0:
				_elevator_state = "opening_half"
				_elevator_timer = 0.0
				elevator_tex.texture = _tex(_elevator_texture_path())
		"opening_half":
			if _elevator_timer >= 0.35:
				_elevator_state = "open"
				_elevator_timer = 0.0
				# Kapı açılınca kuyruktaki TÜM misafirler biner — 2+ kişi
				# varsa sırayla beklemek yerine hepsi tek seferde.
				_boarding = _queue_count
				_queue_count = 0
				elevator_tex.texture = _tex(_elevator_texture_path())
				_board_waiting_guests()
		"open":
			if _elevator_timer >= 1.0:
				_elevator_state = "closing_half"
				_elevator_timer = 0.0
				elevator_tex.texture = _tex(_elevator_texture_path())
		"closing_half":
			if _elevator_timer >= 0.35:
				_elevator_state = "closed"
				_elevator_timer = 0.0
				elevator_tex.texture = _tex(_elevator_texture_path())
				var delivered := _boarding
				_boarding = 0
				if delivered > 0:
					_deliver_guests(delivered)


func _elevator_texture_path() -> String:
	match _elevator_state:
		"opening_half", "closing_half":
			return "res://assets/ui/elevator_half.png"
		"open":
			return "res://assets/ui/elevator_open.png"
		_:
			return "res://assets/ui/elevator_closed.png"


## Kapı tam açılıp kuyruktaki misafirler _boarding'e aktarılınca çağrılır:
## asansörün önünde görünür şekilde bekleyen ikonlar (_waiting_guest_icons)
## artık gerçekten "biniyor" — kısa bir sönümle kaybolur. Önceden misafir
## elev_x'e varır varmaz (kapı henüz kapalıyken bile) hemen soluyordu; bu da
## misafirin kapı önünde beklerken görünmez olup kapının "tepkisiz" görünmesi
## hissini veriyordu.
func _board_waiting_guests() -> void:
	for gicon in _waiting_guest_icons:
		if is_instance_valid(gicon):
			var tw: Tween = gicon.create_tween()
			tw.tween_property(gicon, "modulate:a", 0.0, 0.25)
			tw.tween_callback(gicon.queue_free)
	_waiting_guest_icons.clear()


## Kapı kapanışından ~1sn sonra binen misafirler "odalarına varır":
## _arrived_guests artar (oda kartları ancak bu sayaca göre misafir gösterir,
## bkz. _make_room_button) ve asansör üstünde parıltı belirir.
func _deliver_guests(count: int) -> void:
	get_tree().create_timer(1.0).timeout.connect(func():
		_arrived_guests += count
		if is_instance_valid(elevator_tex):
			_spawn_sparkles(elevator_tex.global_position + elevator_tex.size / 2.0)
		_rebuild_hotel())


## Kaçan misafir: vardiya sırasında ara ara sokakta bir misafir yürüyüp
## geçer; dokunursan kapıya döner ve bonus verir (Hotel City "drag guest").
func _update_walker(delta: float) -> void:
	if not Game.shift_active() or is_instance_valid(_walker):
		return
	_walker_timer += delta
	if _walker_timer < float(Game.eco.catch.interval_real_seconds):
		return
	_walker_timer = 0.0
	_spawn_walker()


## Kaldırımın tuval-yerel y'si: yayalar building_canvas içindeki
## _walker_layer'da yaşar (zoom/pan'i dünyayla paylaşırlar — eskiden ekran
## uzayındaydılar ve pan/zoom sonrası kaldırımdan kopup havada kalıyorlardı).
## +8: ikon gri kaldırım şeridinin (58px) içinde durur, lobiye taşmaz.
func _sidewalk_local_y(_icon_h: float) -> float:
	return float(Game.floors) * CELL_H + LOBBY_H + 8.0


## Giriş boşluğunun tuval-yerel x'i (yaya oraya varınca "içeri girer").
func _door_local_x(icon_w: float) -> float:
	return float(int(Game.eco.building.grid_cols)) * CELL_W - DOOR_W * 0.5 - icon_w * 0.5


func _spawn_walker() -> void:
	if _walker_layer == null or not is_instance_valid(_walker_layer):
		return
	var canvas_w: float = int(Game.eco.building.grid_cols) * CELL_W
	var b := TextureButton.new()
	b.texture_normal = _tex("res://assets/guests/guest_%s.svg" % GUEST_TYPES[randi() % GUEST_TYPES.size()])
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	b.custom_minimum_size = Vector2(40, 40)
	b.size = Vector2(40, 40)
	b.position = Vector2(canvas_w + 24.0, _sidewalk_local_y(40.0))
	_walker_layer.add_child(b)
	_walker = b
	_animate_guest(b, randi() % 4, true)
	var tw := b.create_tween()
	b.set_meta("walk_tween", tw)
	tw.tween_property(b, "position:x", -64.0, 12.0)
	tw.tween_callback(b.queue_free)
	b.pressed.connect(func(): _on_walker_caught(b))


func _on_walker_caught(b: Control) -> void:
	var bonus := Game.catch_guest()
	if bonus <= 0:
		return
	_play("collect")
	_show_toast("Kaçan misafiri kapıya döndürdün! +%d coin" % bonus)
	var old_tw: Tween = b.get_meta("walk_tween")
	if old_tw:
		old_tw.kill()
	b.disabled = true
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := b.create_tween()
	tw.tween_property(b, "position:x", _door_local_x(40.0), 0.8) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		b.queue_free()
		_inbound += 1
		_spawn_lobby_walker())


func _init_sfx() -> void:
	var defs := {
		"tap": [[660.0, 0.05]],
		"buy": [[440.0, 0.06], [880.0, 0.1]],
		"collect": [[784.0, 0.07], [1047.0, 0.09], [1319.0, 0.12]],
		"clean": [[1319.0, 0.08], [1760.0, 0.14]],
		"shift": [[988.0, 0.1], [659.0, 0.2]],
		"quest": [[784.0, 0.08], [988.0, 0.14]],
		"level": [[523.0, 0.09], [659.0, 0.09], [784.0, 0.09], [1047.0, 0.22]],
	}
	for k in defs:
		var p := AudioStreamPlayer.new()
		p.stream = Sfx.tone_stream(defs[k])
		p.volume_db = -6.0
		add_child(p)
		_sfx_players[k] = p
	music_player = AudioStreamPlayer.new()
	music_player.stream = Sfx.lobby_music()
	music_player.volume_db = -14.0
	add_child(music_player)
	if Game.music_on:
		music_player.play()


func _play(kind: String) -> void:
	if Game.sound_on and _sfx_players.has(kind):
		_sfx_players[kind].play()


func _tex(path: String) -> Texture2D:
	if not _tex_cache.has(path):
		# Referans sanat sayfasından kesilen PNG varsa onu tercih et;
		# yoksa elle çizilmiş SVG yedeği kullanılır.
		var p := path
		if p.ends_with(".svg"):
			var png := p.trim_suffix(".svg") + ".png"
			if ResourceLoader.exists(png, "Texture2D"):
				p = png
		_tex_cache[path] = load(p)
	return _tex_cache[path]


# --- Kurulum -----------------------------------------------------------

func _build_ui() -> void:
	# Gökyüzü degrade + şehir silüeti + bulutlar
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	grad.colors = PackedColorArray([PALETTE.sky_top, PALETTE.sky_bottom])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	var sky := TextureRect.new()
	sky.texture = gt
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sky)

	# Şehir silüeti (skyline.svg) kaldırıldı — kullanıcı isteği: "diğer bina
	# resimlerini kaldır, tam ekran otel ve otelin önündeki yol olacak".

	for cdef in [[40, 130, 130], [420, 210, 170], [230, 620, 110]]:
		var cloud := TextureRect.new()
		cloud.texture = _tex("res://assets/ui/cloud.svg")
		cloud.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		cloud.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		cloud.position = Vector2(cdef[0], cdef[1])
		cloud.custom_minimum_size = Vector2(cdef[2], cdef[2] * 0.46)
		cloud.size = cloud.custom_minimum_size
		cloud.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(cloud)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	# --- Üst bar (krem panel)
	var top := _panel(PALETTE.cream, PALETTE.facade_line)
	root.add_child(top)
	var top_box := VBoxContainer.new()
	top_box.add_theme_constant_override("separation", 6)
	top.add_child(top_box)

	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 6)
	top_box.add_child(row1)
	row1.add_child(_icon("res://assets/ui/coin.svg", 26))
	coins_label = _label("", 21, PALETTE.text)
	row1.add_child(coins_label)
	row1.add_child(_spacer_x(10))
	row1.add_child(_icon("res://assets/ui/gem.svg", 26))
	gems_label = _label("", 21, PALETTE.text)
	row1.add_child(gems_label)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row1.add_child(sp)
	for i in 5:
		var s := _icon("res://assets/ui/star_empty.svg", 24)
		star_icons.append(s)
		row1.add_child(s)

	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 10)
	top_box.add_child(row2)
	level_label = _label("", 15, PALETTE.muted)
	row2.add_child(level_label)
	xp_bar = ProgressBar.new()
	xp_bar.show_percentage = false
	xp_bar.custom_minimum_size = Vector2(0, 12)
	xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var xb := StyleBoxFlat.new()
	xb.bg_color = PALETTE.cream_dark
	xb.set_corner_radius_all(6)
	xp_bar.add_theme_stylebox_override("background", xb)
	var xf := StyleBoxFlat.new()
	xf.bg_color = PALETTE.gold
	xf.set_corner_radius_all(6)
	xp_bar.add_theme_stylebox_override("fill", xf)
	row2.add_child(xp_bar)

	# --- Vardiya durumu + topla
	shift_label = _label("", 14, PALETTE.text)
	shift_label.add_theme_color_override("font_outline_color", PALETTE.cream)
	shift_label.add_theme_constant_override("outline_size", 6)
	root.add_child(shift_label)

	collect_button = _button("", 22, PALETTE.gold, PALETTE.text)
	collect_button.custom_minimum_size = Vector2(0, 60)
	collect_button.pressed.connect(_on_collect)
	root.add_child(collect_button)

	# --- Görev ipucu
	var qp := _panel(PALETTE.green_deep, PALETTE.gold)
	root.add_child(qp)
	quest_hint = _label("", 14, PALETTE.gold_soft)
	quest_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	qp.add_child(quest_hint)

	# --- Otel görünümü: çatı tabelası (sabit) + zoom kontrolleri (sabit) +
	# zoom/pan alan tuval (kat sıraları + lobi + sokak + çim, serbest blok
	# yerleşimi — kat genişlikleri farklı olabildiği için artık HBoxContainer
	# satırları yerine manuel konumlandırılmış tek bir Control tuval).
	roof_panel = PanelContainer.new()
	var roof_sb := StyleBoxFlat.new()
	roof_sb.corner_radius_top_left = 20
	roof_sb.corner_radius_top_right = 20
	roof_sb.set_content_margin_all(12)
	roof_sb.border_color = PALETTE.gold
	roof_sb.set_border_width_all(2)
	roof_sb.border_width_bottom = 5
	roof_sb.shadow_color = Color(0.1, 0.06, 0.02, 0.18)
	roof_sb.shadow_size = 5
	roof_sb.shadow_offset = Vector2(0, 3)
	roof_panel.add_theme_stylebox_override("panel", roof_sb)
	root.add_child(roof_panel)
	var roof_col := VBoxContainer.new()
	roof_col.add_theme_constant_override("separation", 2)
	roof_panel.add_child(roof_col)
	roof_title_label = _label("★  LITTLE GRAND HOTEL  ★", 18, PALETTE.gold_soft)
	roof_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	roof_col.add_child(roof_title_label)
	roof_theme_label = _label("", 12, PALETTE.cream_text)
	roof_theme_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	roof_col.add_child(roof_theme_label)

	var zoom_row := HBoxContainer.new()
	zoom_row.add_theme_constant_override("separation", 6)
	root.add_child(zoom_row)
	build_mode_button = _button("🔨 İnşa Modu", 13, PALETTE.wood, PALETTE.cream_text)
	build_mode_button.custom_minimum_size = Vector2(0, 36)
	build_mode_button.toggle_mode = true
	build_mode_button.toggled.connect(func(on: bool):
		build_mode = on
		build_mode_button.text = "🔨 İnşa Modu: Açık" if on else "🔨 İnşa Modu"
		_rebuild_hotel())
	zoom_row.add_child(build_mode_button)
	var zoom_row_spacer := Control.new()
	zoom_row_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	zoom_row.add_child(zoom_row_spacer)
	var zoom_out_b := _button("−", 18, PALETTE.wood, PALETTE.cream_text)
	zoom_out_b.custom_minimum_size = Vector2(40, 36)
	zoom_out_b.pressed.connect(func(): _zoom_by(-0.15, zoom_viewport.size / 2.0))
	zoom_row.add_child(zoom_out_b)
	var zoom_reset_b := _button("⟳", 16, PALETTE.wood, PALETTE.cream_text)
	zoom_reset_b.custom_minimum_size = Vector2(40, 36)
	zoom_reset_b.pressed.connect(func():
		_zoom = clampf(1.0, _effective_zoom_min(), ZOOM_MAX)
		_canvas_pan = Vector2.ZERO
		_clamp_pan()
		_apply_canvas_transform())
	zoom_row.add_child(zoom_reset_b)
	var zoom_in_b := _button("+", 18, PALETTE.wood, PALETTE.cream_text)
	zoom_in_b.custom_minimum_size = Vector2(40, 36)
	zoom_in_b.pressed.connect(func(): _zoom_by(0.15, zoom_viewport.size / 2.0))
	zoom_row.add_child(zoom_in_b)

	# İnşa Modu mağaza rafı: yalnızca build_mode açıkken görünür (bkz.
	# _rebuild_hotel). Oda kartları buradan tuvale sürüklenir — tıklayınca
	# açılan liste yerine Hotel City'deki gibi "mağazadan seç, sürükle" akışı.
	build_shop_panel = VBoxContainer.new()
	build_shop_panel.visible = false
	build_shop_panel.add_theme_constant_override("separation", 2)
	root.add_child(build_shop_panel)
	build_shop_panel.add_child(_label("Oda Mağazası — sürükleyip binaya bırak", 12, PALETTE.wood_dark))
	var build_shop_scroll := ScrollContainer.new()
	build_shop_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	build_shop_scroll.custom_minimum_size = Vector2(0, 112)
	build_shop_panel.add_child(build_shop_scroll)
	build_shop_row = HBoxContainer.new()
	build_shop_row.add_theme_constant_override("separation", 6)
	build_shop_scroll.add_child(build_shop_row)

	# zoom_viewport'u kendi ScrollContainer'ına sarmalıyoruz: içeriği (bina
	# tuvali) sabit bir yüksekliğe sahip, VBox'ın "kalan alanı" hesabına göre
	# öngörülemez şekilde şişip "Yeni kat aç" butonunu ekran dışına itmesin;
	# bina taşarsa (çok kat) kullanıcı aşağı kaydırıp butona ulaşabilir.
	var view_scroll := ScrollContainer.new()
	view_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(view_scroll)
	var view_col := VBoxContainer.new()
	view_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view_scroll.add_child(view_col)

	zoom_viewport = Control.new()
	zoom_viewport.clip_contents = true
	# Kullanıcı isteği ("tam ekran otel"): sabit 460px yerine bina görünümü
	# ekranın kalan tüm dikey alanını doldurur.
	zoom_viewport.custom_minimum_size = Vector2(0, 460)
	zoom_viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
	zoom_viewport.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	zoom_viewport.mouse_filter = Control.MOUSE_FILTER_PASS
	zoom_viewport.gui_input.connect(_on_viewport_gui_input)
	view_col.add_child(zoom_viewport)
	building_canvas = Control.new()
	building_canvas.mouse_filter = Control.MOUSE_FILTER_PASS
	zoom_viewport.add_child(building_canvas)

	new_floor_button = _button("", 15, PALETTE.wood_dark, PALETTE.cream_text)
	new_floor_button.pressed.connect(func():
		if Game.buy_floor():
			_play("buy")
			_show_toast("Yeni kat açıldı!"))
	view_col.add_child(new_floor_button)

	# --- Alt bar: koyu şerit üzerinde ikonlu kategoriler (Hotel City tarzı)
	var bar_panel := PanelContainer.new()
	var bar_sb := _card_sb(PALETTE.bar_dark, PALETTE.gold, 20, 0.25)
	bar_sb.set_content_margin_all(6)
	bar_sb.shadow_size = 6
	bar_sb.shadow_offset = Vector2(0, -2)
	bar_panel.add_theme_stylebox_override("panel", bar_sb)
	root.add_child(bar_panel)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 6)
	bar_panel.add_child(bottom)

	var shift_b := _bar_button("res://assets/ui/icon_clock.svg", "Vardiya")
	shift_b.pressed.connect(func(): _open_popup("Vardiya", _build_shift_popup))
	bottom.add_child(shift_b)
	shift_bar_label = shift_b.get_meta("label")

	# "Mağaza" artık popup açmıyor — İnşa Modu'nu açıp mağaza rafını gösterir
	# (oda ekleme tek yol: rafından sürükleyip binaya bırakmak).
	var shop_b := _bar_button("res://assets/ui/icon_shop.svg", "Mağaza")
	shop_b.pressed.connect(func():
		build_mode_button.button_pressed = true
		_show_toast("İnşa Modu açıldı — bir odayı rafdan sürükleyip binaya bırak"))
	bottom.add_child(shop_b)

	for def in [
		["res://assets/ui/icon_gear.svg", "Personel", _build_staff_popup],
		["res://assets/ui/icon_quest.svg", "Görevler", _build_quests_popup],
		["res://assets/ui/icon_stats.svg", "İstatistik", _build_stats_popup],
		["res://assets/ui/icon_gear.svg", "Ayarlar", _build_settings_popup],
	]:
		var b := _bar_button(def[0], def[1])
		var builder: Callable = def[2]
		var title: String = def[1]
		b.pressed.connect(func(): _open_popup(title, builder))
		bottom.add_child(b)

	speed_index = maxi(0, SPEEDS.find(Game.time_scale))
	var speed_b := _bar_button("", "×%d" % int(SPEEDS[speed_index]))
	speed_b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	speed_b.custom_minimum_size = Vector2(64, 66)
	speed_b.pressed.connect(func():
		_cycle_speed()
		speed_b.get_meta("label").text = "×%d" % int(SPEEDS[speed_index]))
	bottom.add_child(speed_b)

	# --- Popup katmanı
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.2, 0.15, 0.05, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed:
			_close_popup())
	overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)
	var panel := _panel(PALETTE.cream, PALETTE.facade_line)
	panel.custom_minimum_size = Vector2(620, 0)
	center.add_child(panel)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 10)
	panel.add_child(pv)
	var head := HBoxContainer.new()
	pv.add_child(head)
	popup_title = _label("", 21, PALETTE.wood_dark)
	popup_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(popup_title)
	var close_b := _button("Kapat", 15, PALETTE.wood, PALETTE.cream_text)
	close_b.pressed.connect(_close_popup)
	head.add_child(close_b)
	var pscroll := ScrollContainer.new()
	pscroll.custom_minimum_size = Vector2(0, 640)
	pv.add_child(pscroll)
	popup_content = VBoxContainer.new()
	popup_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	popup_content.add_theme_constant_override("separation", 8)
	pscroll.add_child(popup_content)

	# --- Toast: alt barın üstünde yüzer, yerleşimi itmez; popup'ların da üstünde
	toast_panel = _panel(PALETTE.green_deep, PALETTE.gold)
	toast_panel.visible = false
	toast_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	toast_panel.offset_left = 40
	toast_panel.offset_right = -40
	toast_panel.offset_top = -156
	toast_panel.offset_bottom = -84
	toast_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast_panel)
	toast_label = _label("", 16, PALETTE.cream_text)
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_panel.add_child(toast_label)


## Yuvarlak köşeli + yumuşak gölgeli kart stilbox'u (referans mockup'taki
## "dollhouse kartları" hissi için) — düz StyleBoxFlat yerine ortak kullanılır.
func _card_sb(bg: Color, border: Color, radius: int, shadow: float = 0.22) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.shadow_color = Color(0.1, 0.06, 0.02, shadow)
	sb.shadow_size = 5
	sb.shadow_offset = Vector2(0, 3)
	return sb


func _panel(bg: Color, border: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := _card_sb(bg, border, 18, 0.14)
	sb.set_content_margin_all(12)
	p.add_theme_stylebox_override("panel", sb)
	return p


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _icon(path: String, px: int) -> TextureRect:
	var t := TextureRect.new()
	t.texture = _tex(path)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(px, px)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## Alt bar butonu: ikon üstte, etiket altta. Etikete b.get_meta("label") ile
## erişilir (vardiya geri sayımı gibi canlı metinler için).
func _bar_button(icon_path: String, text: String) -> Button:
	var b := Button.new()
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 66)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = PALETTE.bar_dark
		if state == "hover":
			sb.bg_color = PALETTE.bar_dark.lightened(0.08)
		elif state == "pressed":
			sb.bg_color = PALETTE.bar_dark.darkened(0.2)
		sb.set_corner_radius_all(16)
		sb.set_content_margin_all(2)
		b.add_theme_stylebox_override(state, sb)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	if icon_path != "":
		var wrap := CenterContainer.new()
		wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wrap.add_child(_icon(icon_path, 30))
		v.add_child(wrap)
	var l := _label(text, 18 if icon_path == "" else 12, PALETTE.cream_text)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(l)
	b.set_meta("label", l)
	return b


func _spacer_x(px: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(px, 0)
	return c


func _spacer_y(px: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, px)
	return c


func _button(text: String, size: int, bg: Color, fg: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", fg)
	b.add_theme_color_override("font_pressed_color", fg)
	b.add_theme_color_override("font_disabled_color", Color(fg, 0.5))
	for state in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = bg
		if state == "hover":
			sb.bg_color = bg.lightened(0.07)
		elif state == "pressed":
			sb.bg_color = bg.darkened(0.1)
		elif state == "disabled":
			sb.bg_color = bg.darkened(0.2)
		sb.set_corner_radius_all(14)
		sb.set_content_margin_all(9)
		sb.border_color = bg.darkened(0.35)
		sb.set_border_width_all(2)
		b.add_theme_stylebox_override(state, sb)
	return b


## Butona sol ikon ekler (reklam/IAP butonlarındaki sanat sayfası ikonları).
func _button_icon(b: Button, path: String) -> void:
	b.icon = _tex(path)
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width", 26)
	b.add_theme_constant_override("h_separation", 8)


# --- Yenileme ----------------------------------------------------------

func _refresh() -> void:
	_update_live_labels()
	_rebuild_hotel()
	if overlay.visible and popup_builder.is_valid():
		_rebuild_popup()


func _update_live_labels() -> void:
	coins_label.text = _fmt(Game.coins)
	gems_label.text = str(Game.gems)
	var stars := Game.star_rating()
	for i in 5:
		star_icons[i].texture = _tex("res://assets/ui/star_full.svg" if i < stars else "res://assets/ui/star_empty.svg")
	var lv := Game.level()
	level_label.text = "Seviye %d" % lv
	var cur_xp := Game.xp - Game.xp_for_level(lv)
	var need := Game.xp_for_level(lv + 1) - Game.xp_for_level(lv)
	xp_bar.max_value = need
	xp_bar.value = cur_xp
	if Game.shift_active():
		shift_label.text = "Vardiya bitimine %s · %.0f coin/saat" % [
			_fmt_hms(Game.shift_remaining_game_hours()), Game.hourly_income()]
		shift_bar_label.text = _fmt_hms(Game.shift_remaining_game_hours())
		shift_bar_label.add_theme_color_override("font_color", PALETTE.gold_soft)
	else:
		shift_label.text = "Vardiya kapalı — otel gelir üretmiyor."
		shift_bar_label.text = "Vardiya"
		shift_bar_label.add_theme_color_override("font_color", PALETTE.cream_text)
	collect_button.text = "TOPLA — %s" % _fmt(int(Game.pending_income))
	collect_button.disabled = int(Game.pending_income) <= 0


func _current_theme() -> Dictionary:
	return WEEKLY_THEMES[Game.current_week_index() % WEEKLY_THEMES.size()]


func _rebuild_hotel() -> void:
	# Hangi odaların düğümleri (Button + duvar TextureRect'i) bir önceki
	# rebuild'den bu yana görsel olarak DEĞİŞMEDİ — bunlar teardown'dan
	# muaf tutulup aynen korunacak (bkz. _room_visual_signature, üstteki
	# _room_visual_cache açıklaması).
	var next_room_cache := {}
	var kept_nodes := {}
	for i in Game.rooms.size():
		var rid := String(Game.rooms[i].id)
		var prev = _room_visual_cache.get(rid)
		if prev != null and is_instance_valid(prev.button) and is_instance_valid(prev.wall) \
				and prev.sig == _room_visual_signature(i):
			next_room_cache[rid] = prev
			kept_nodes[prev.button] = true
			kept_nodes[prev.wall] = true
	for c in building_canvas.get_children():
		if c == _walker_layer or kept_nodes.has(c):
			continue  # yürüyen yayalar rebuild'lerde hayatta kalır
		building_canvas.remove_child(c)
		c.queue_free()
	if _walker_layer == null or not is_instance_valid(_walker_layer):
		_walker_layer = Control.new()
		_walker_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_walker_layer.z_index = 50  # bina öğelerinin üstünde çizilsin
		building_canvas.add_child(_walker_layer)

	# Çatı tabelası (haftalık temaya göre renklenen tente) — sabit, tuvalin
	# dışında; zoom/pan yalnızca kat sıraları + lobi + sokak + çimi kapsar.
	var theme: Dictionary = _current_theme()
	(roof_panel.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = theme.accent
	roof_theme_label.text = "Haftanın teması: %s" % String(theme.name)

	var grid_cols := int(Game.eco.building.grid_cols)
	var canvas_w := grid_cols * CELL_W
	var floors_h := Game.floors * CELL_H
	var canvas_h := floors_h + LOBBY_H + STREET_H + GRASS_H
	building_canvas.custom_minimum_size = Vector2(canvas_w, canvas_h)
	building_canvas.size = building_canvas.custom_minimum_size

	# Kat sıraları: artık kat başına dolgu bir zemin şeridi YOK (kullanıcı
	# isteği: boş/kilitsiz alanlarda arka plan — gökyüzü/silüet — görünsün,
	# odalar sanki havada duruyormuş gibi; bkz. Hotel City'nin "total block"
	# sistemi). Her oda ve kilitli blok zaten kendi tam kartını çiziyor;
	# açık-ama-boş hücreler hiçbir Control eklemiyor (bkz. _make_add_cell_button).
	for floor_i in range(Game.floors, 1 - 1, -1):
		if floor_i < 1:
			break
		var row_y := float(Game.floors - floor_i) * CELL_H

		var open_w := Game.floor_open_width(floor_i)
		var occupied := {}
		for i in Game.rooms.size():
			var r: Dictionary = Game.rooms[i]
			if int(r.floor) != floor_i:
				continue
			var rid := String(r.id)
			if not next_room_cache.has(rid):
				# Duvar çerçevesi: odanın TAM hücre alanını (CELL_GAP boşluğu
				# dahil) kaplar, oda kartı bunun üstüne biraz içeriden oturur —
				# geriye kalan ince boşlukta duvar bloğu dokusu görünür. Yan
				# yana odalar bitişik hücrelerde olduğundan duvar alanları da
				# bitişik oluyor ve kesintisiz tek duvar hissi veriyor
				# (kullanıcı isteği).
				var wall_block := TextureRect.new()
				wall_block.texture = _tex("res://assets/ui/wall_block.svg")
				wall_block.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				wall_block.stretch_mode = TextureRect.STRETCH_TILE
				wall_block.position = Vector2(int(r.col) * CELL_W, row_y)
				wall_block.size = Vector2(int(r.w) * CELL_W, CELL_H)
				wall_block.mouse_filter = Control.MOUSE_FILTER_IGNORE
				building_canvas.add_child(wall_block)
				var btn := _make_room_button(i)
				btn.position = Vector2(int(r.col) * CELL_W + CELL_GAP * 0.5, row_y + CELL_GAP * 0.5)
				btn.size = Vector2(int(r.w) * CELL_W - CELL_GAP, CELL_H - CELL_GAP)
				building_canvas.add_child(btn)
				next_room_cache[rid] = {"sig": _room_visual_signature(i), "button": btn, "wall": wall_block}
			for cc in range(int(r.col), int(r.col) + int(r.w)):
				occupied[cc] = true

		for col in range(grid_cols):
			if occupied.has(col):
				continue
			var cell: Control = _make_add_cell_button(floor_i, col) if col < open_w \
				else _make_block_cell_button(floor_i, col)
			cell.position = Vector2(col * CELL_W + CELL_GAP * 0.5, row_y + CELL_GAP * 0.5)
			cell.size = Vector2(CELL_W - CELL_GAP, CELL_H - CELL_GAP)
			building_canvas.add_child(cell)

	# Lobi: sütunlu resepsiyon sahnesi + komi (Hotel City lobisi). Odalarla
	# aynı duvar çerçevesi muamelesi görür, ama sağ ucunda duvar kesilip
	# hiçbir şey çizilmeyen bir boşluk bırakılır — kullanıcı isteği: 2D dik
	# kesitte kapı objesi çizmeye gerek yok, duvardaki boşluğun kendisi
	# zaten kapı gibi okunuyor (önceki üç deneme — ışıklı boşluk, camlı
	# çift kanat, düz renkli dikdörtgen — hepsi gereksiz görüldü ve
	# kaldırıldı). Misafirler oraya doğru yürür (bkz. _guest_walk_in).
	var lobby_y := floors_h
	var lobby_wall := TextureRect.new()
	lobby_wall.texture = _tex("res://assets/ui/wall_block.svg")
	lobby_wall.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lobby_wall.stretch_mode = TextureRect.STRETCH_TILE
	lobby_wall.position = Vector2(0, lobby_y)
	lobby_wall.size = Vector2(canvas_w - DOOR_W, LOBBY_H)
	lobby_wall.mouse_filter = Control.MOUSE_FILTER_IGNORE
	building_canvas.add_child(lobby_wall)
	# Kullanıcı isteği: ince, cam mavisi bir çubuk — sağ duvarın ÜSTÜNE
	# gelecek (duvarın son kısmıyla çakışır, boşluğa taşmaz). Üst/alt
	# kenarlarda duvarın tavan/taban şeridi (lobby.svg) altta kalmasın diye
	# dikeyde biraz içeriden başlayıp bitiyor.
	const DOOR_BAR_W := 10.0
	const DOOR_BAR_MARGIN := 10.0
	var door_bar := ColorRect.new()
	door_bar.color = Color("bfe6f2")
	door_bar.position = Vector2(canvas_w - DOOR_W - DOOR_BAR_W, lobby_y + DOOR_BAR_MARGIN)
	door_bar.size = Vector2(DOOR_BAR_W, LOBBY_H - DOOR_BAR_MARGIN * 2.0)
	door_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	building_canvas.add_child(door_bar)
	var lobby := PanelContainer.new()
	var lsb := StyleBoxFlat.new()
	lsb.bg_color = Color("f3e7d8")
	lsb.border_color = PALETTE.facade_line
	lsb.set_border_width_all(2)
	lsb.set_content_margin_all(0)
	lobby.add_theme_stylebox_override("panel", lsb)
	lobby.position = Vector2(CELL_GAP * 0.5, lobby_y + CELL_GAP * 0.5)
	lobby.size = Vector2(canvas_w - DOOR_W - CELL_GAP, LOBBY_H - CELL_GAP)
	building_canvas.add_child(lobby)
	var lobby_scene := TextureRect.new()
	lobby_scene.texture = _tex("res://assets/ui/lobby.svg")
	lobby_scene.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lobby_scene.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	lobby_scene.set_anchors_preset(Control.PRESET_FULL_RECT)
	lobby_scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lobby.add_child(lobby_scene)
	# Animasyonlu asansör kapısı: eski sabit lobby.png asansörünün TAM olarak
	# aynı ekran konumuna oturur. lobby_scene STRETCH_KEEP_ASPECT_COVERED
	# kullandığından basit piksel/viewBox oranı yeterli değil — COVERED
	# dokunun yatayda kırptığı payı (crop) hesaba katan gerçek dönüşüm
	# gerekiyor: control 648×108, doku 1920×256, ölçek=max(648/1920,108/256)
	# =0.421875 (yükseklik baskın) → görünen doku genişliği 810, yatayda
	# 162px taşar, her yandan 81px (=192 orijinal piksel) kırpılır. Eski
	# asansörün orijinal lobby.png konumu (x≈850–1040, y≈5–222, 1920×256
	# üzerinden) bu dönüşümle şu kesirlere karşılık geliyor.
	elevator_tex = TextureRect.new()
	elevator_tex.texture = _tex(_elevator_texture_path())
	elevator_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	elevator_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	elevator_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	elevator_tex.anchor_left = 0.428
	elevator_tex.anchor_right = 0.552
	elevator_tex.anchor_top = 0.02
	elevator_tex.anchor_bottom = 0.87
	lobby_scene.add_child(elevator_tex)
	# Resepsiyonist (kullanıcının gönderdiği referans karakterden kesilmiş
	# gerçek görsel — bkz. assets/guests/receptionist.png); bellboy.svg'nin
	# yerini aldı. Boy oranı portre (dar/uzun) olduğu için _icon()'ın
	# sabit-kare kutusu yerine kendi en-boy oranına göre boyutlandırılıyor.
	var receptionist := TextureRect.new()
	receptionist.texture = _tex("res://assets/guests/receptionist.png")
	receptionist.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	receptionist.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	receptionist.mouse_filter = Control.MOUSE_FILTER_IGNORE
	receptionist.anchor_left = 0.16
	receptionist.anchor_right = 0.16
	receptionist.anchor_top = 1.0
	receptionist.anchor_bottom = 1.0
	receptionist.offset_left = -26
	receptionist.offset_right = 26
	receptionist.offset_top = -90
	receptionist.offset_bottom = -8
	lobby_scene.add_child(receptionist)
	_animate_guest(receptionist, 2, false)

	# Sokak: bina bir kaldırım kenarında duruyormuş hissi — açık gri kaldırım
	# (döşeme derzleriyle) + bordür şeridi + koyu asfalt yol, bina ile aynı
	# tuval içinde (aynı zoom/pan'i paylaşır), önceki dar şeritten belirgin geniş.
	var street_y := lobby_y + LOBBY_H
	var street := Control.new()
	street.position = Vector2(0, street_y)
	street.size = Vector2(canvas_w, STREET_H)
	street.mouse_filter = Control.MOUSE_FILTER_IGNORE
	building_canvas.add_child(street)
	street_node = street

	const SIDEWALK_H := 58.0
	const CURB_H := 7.0
	var sidewalk := ColorRect.new()
	sidewalk.color = PALETTE.sidewalk
	sidewalk.position = Vector2.ZERO
	sidewalk.size = Vector2(canvas_w, SIDEWALK_H)
	sidewalk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	street.add_child(sidewalk)
	for seam_x in range(0, int(canvas_w), 64):
		var seam := ColorRect.new()
		seam.color = PALETTE.sidewalk.darkened(0.12)
		seam.position = Vector2(seam_x, 0)
		seam.size = Vector2(2, SIDEWALK_H)
		seam.mouse_filter = Control.MOUSE_FILTER_IGNORE
		street.add_child(seam)
	var curb := ColorRect.new()
	curb.color = PALETTE.curb
	curb.position = Vector2(0, SIDEWALK_H)
	curb.size = Vector2(canvas_w, CURB_H)
	curb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	street.add_child(curb)
	var road := ColorRect.new()
	road.color = PALETTE.asphalt
	road.position = Vector2(0, SIDEWALK_H + CURB_H)
	road.size = Vector2(canvas_w, STREET_H - SIDEWALK_H - CURB_H)
	road.mouse_filter = Control.MOUSE_FILTER_IGNORE
	street.add_child(road)
	for dash_x in range(10, int(canvas_w), 46):
		var dash := ColorRect.new()
		dash.color = PALETTE.gold_soft
		# Konum, road'un KENDİ yerel uzayında (road zaten SIDEWALK_H+CURB_H
		# ofsetinde) — eski çift-ofset çizgileri tuvalin dışına taşırıyordu
		# (viewport 460px'e kırpılıyken görünmüyordu, tam ekranda ortaya çıktı).
		dash.position = Vector2(dash_x, (STREET_H - SIDEWALK_H - CURB_H) * 0.5 - 1.5)
		dash.size = Vector2(22, 3)
		dash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		road.add_child(dash)

	var street_scroll := ScrollContainer.new()
	street_scroll.position = Vector2(0, 2)
	street_scroll.size = Vector2(canvas_w, SIDEWALK_H - 4)
	street_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	street.add_child(street_scroll)
	var queue := HBoxContainer.new()
	queue.add_theme_constant_override("separation", 8)
	queue.size_flags_vertical = Control.SIZE_EXPAND_FILL
	street_scroll.add_child(queue)
	if not Game.shift_active():
		# Vardiya aktifken kaldırımda artık sabit duran ikonlar YOK —
		# kullanıcı isteği: "kaldırımdan normal insanlar yürüyecek" — bkz.
		# _spawn_arriving_pedestrian (gerçek yürüyen yayalar, tuvalin dışında
		# root seviyesinde ayrı overlay node'lar olarak, bu kutunun dışında).
		var street_l := _label("· · · sokak sakin — vardiya başlat · · ·", 13, PALETTE.cream)
		street_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		queue.add_child(street_l)

	# Çim tabanı: binayı bir "dollhouse nesnesi" gibi zemine oturtan yeşil kapak
	var grass := PanelContainer.new()
	var gsb := StyleBoxFlat.new()
	gsb.bg_color = PALETTE.grass
	gsb.corner_radius_bottom_left = 20
	gsb.corner_radius_bottom_right = 20
	gsb.border_color = PALETTE.grass_dark
	gsb.border_width_bottom = 4
	gsb.shadow_color = Color(0.1, 0.06, 0.02, 0.18)
	gsb.shadow_size = 5
	gsb.shadow_offset = Vector2(0, 3)
	grass.add_theme_stylebox_override("panel", gsb)
	grass.position = Vector2(0, street_y + STREET_H)
	grass.size = Vector2(canvas_w, GRASS_H)
	building_canvas.add_child(grass)

	_clamp_pan()
	_apply_canvas_transform()

	# İnşa Modu mağaza rafı: yalnızca açıkken görünür ve her yeniden
	# kurulumda güncel fiyat/seviye kilidiyle tazelenir.
	build_shop_panel.visible = build_mode
	if build_mode:
		for c in build_shop_row.get_children():
			build_shop_row.remove_child(c)
			c.queue_free()
		for type in Game.eco.room_types:
			build_shop_row.add_child(_make_shop_tray_card(type))

	# Yeni kat (tuvalin dışında, sabit — satın alınca yeni bir kat satırı
	# tuvale eklenir)
	new_floor_button.visible = Game.floors < int(Game.eco.building.max_floors)
	if new_floor_button.visible:
		new_floor_button.text = "Yeni kat aç — %s coin" % _fmt(Game.floor_price())
		new_floor_button.disabled = not Game.can_buy_floor()

	var q: Dictionary = Game.current_quest()
	if q.is_empty():
		quest_hint.text = "Tüm görevler tamamlandı — otel senin!"
	else:
		var p: Array = Game.quest_progress(q)
		quest_hint.text = "Görev: %s (%d/%d)" % [q.name, mini(p[0], p[1]), p[1]]

	_room_visual_cache = next_room_cache


## Açık ama boş bir hücre: HİÇBİR görsel kutu/çerçeve göstermez (kullanıcı
## isteği: "açık olmayan odalar oluşturulmamış olmalı, arka plan gözükecek")
## — kat şeridinin (row_bg) kendi arka planı olduğu gibi görünür. Yeni oda
## yalnızca mağaza rafından sürükleyip bırakılarak eklenir (bkz.
## _make_shop_tray_card, _finish_drag; bırakma ham ekran koordinatından
## hücre bulur, herhangi bir Control'e ihtiyaç duymaz). İnşa Modu kapalıyken
## tamamen etkileşimsiz de olur; açıkken görünmez ama yine de dokunulabilir
## kalır — yalnızca "Taşı" modundaki hedef tıklaması için (bkz.
## _on_empty_cell_move_tapped).
func _make_add_cell_button(floor_i: int, col: int) -> Control:
	if not build_mode:
		return _make_plain_empty_cell()
	var b := Button.new()
	for state in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	b.pressed.connect(func(): _on_empty_cell_move_tapped(floor_i, col))
	return b


## Boş hücrenin görünmez hâli: hiçbir Control eklemez, kat şeridinin
## kendi arka planı olduğu gibi görünür.
func _make_plain_empty_cell() -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## Henüz satın alınmamış blok: kullanıcı isteği üzerine kapalı perde görseli
## de kaldırıldı — İnşa Modu kapalıyken diğer boş hücreler gibi tamamen
## görünmez (bkz. _make_plain_empty_cell). Perde + fiyat etiketi + "blok al"
## dokunuşu yalnızca İnşa Modu açıkken görünür.
func _make_block_cell_button(floor_i: int, col: int) -> Control:
	if not build_mode:
		return _make_plain_empty_cell()
	var b := Button.new()
	b.clip_text = true
	for state in ["normal", "hover", "pressed", "disabled"]:
		var sb := _card_sb(PALETTE.locked, PALETTE.facade_line, 12, 0.12)
		b.add_theme_stylebox_override(state, sb)
	b.clip_contents = true
	var curt := TextureRect.new()
	curt.texture = _tex("res://assets/ui/curtain_closed.svg")
	curt.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	curt.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	curt.set_anchors_preset(Control.PRESET_FULL_RECT)
	curt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(curt)
	var l := _label("Blok aç\n%s coin" % _fmt(Game.block_price(floor_i)), 11, Color("f0dfc4"))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(l)
	b.disabled = not Game.can_buy_block(floor_i)
	b.pressed.connect(func():
		if Game.buy_block(floor_i):
			_play("buy")
			_show_toast("Yeni blok açıldı!"))
	return b


# --- Bina görünümü: zoom / pan -----------------------------------------

func _apply_canvas_transform() -> void:
	building_canvas.scale = Vector2(_zoom, _zoom)
	building_canvas.position = _canvas_pan


## Tuvalin viewport dışına taşmasını (fazla pan/zoom-out) engeller.
func _clamp_pan() -> void:
	var content_size: Vector2 = building_canvas.custom_minimum_size * _zoom
	var vp_size: Vector2 = zoom_viewport.size
	var min_x: float = minf(0.0, vp_size.x - content_size.x)
	_canvas_pan.x = clampf(_canvas_pan.x, min_x, 0.0)
	if content_size.y >= vp_size.y:
		_canvas_pan.y = clampf(_canvas_pan.y, vp_size.y - content_size.y, 0.0)
	else:
		# Bina viewport'tan kısaysa TABANA hizala — yol/kaldırım ekranın
		# dibinde durur ("tam ekran otel ve önündeki yol"), bina gökyüzünde
		# asılı görünmez.
		_canvas_pan.y = vp_size.y - content_size.y


## Binanın viewport'u tam olarak dolduracağı (kırpılmadan tamamen sığacağı)
## zoom seviyesini hesaplar — bunun altına inmek yalnızca boş alan ekler ve
## binayı gereksiz yere küçültür, bu yüzden gerçek alt sınır budur.
func _effective_zoom_min() -> float:
	var content: Vector2 = building_canvas.custom_minimum_size
	var vp: Vector2 = zoom_viewport.size
	if content.x <= 0.0 or content.y <= 0.0 or vp.x <= 0.0 or vp.y <= 0.0:
		return ZOOM_MIN
	var fit_zoom := minf(vp.x / content.x, vp.y / content.y)
	return clampf(fit_zoom, ZOOM_MIN, ZOOM_MAX)


## Belirli bir ekran noktasını (ör. tıklanan yer) sabit tutarak yakınlaştırır.
func _zoom_by(delta: float, around: Vector2) -> void:
	var old_zoom := _zoom
	_zoom = clampf(_zoom + delta, _effective_zoom_min(), ZOOM_MAX)
	if not is_zero_approx(old_zoom):
		var local := (around - _canvas_pan) / old_zoom
		_canvas_pan = around - local * _zoom
	_clamp_pan()
	_apply_canvas_transform()


## zoom_viewport'a düşen (oda/hücre butonlarının TÜKETMEDİĞİ) girdiler:
## fare tekerleği ile zoom, sürükleme ile pan, mobil pinch (magnify gesture).
func _on_viewport_gui_input(event: InputEvent) -> void:
	if event is InputEventMagnifyGesture:
		_zoom_by(event.factor - 1.0, event.position)
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_by(0.1, event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_by(-0.1, event.position)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_pan_dragging = true
				_pan_drag_start = event.position
				_pan_start_canvas_pos = _canvas_pan
			else:
				_pan_dragging = false
	elif event is InputEventMouseMotion and _pan_dragging:
		_canvas_pan = _pan_start_canvas_pos + (event.position - _pan_drag_start)
		_clamp_pan()
		_apply_canvas_transform()


## _make_room_button(idx)'in ÜRETECEĞİ görseli belirleyen her şeyin anlık
## anlık "imzası" — iki rebuild arasında bu imza aynıysa (Dictionary == ile
## karşılaştırılır), o odanın düğümleri yeniden kurulmadan aynen korunur.
## Ham değerler yerine (ör. Game.coins, ham _arrived_guests sayısı) yalnızca
## SONUÇ booleanları tutulur (guest_visible, show_badge, ...) — aksi halde
## her coin/misafir değişikliğinde TÜM odaların imzası değişir ve önbellek
## hiçbir rebuild'de işe yaramazdı.
func _room_visual_signature(idx: int) -> Dictionary:
	var room: Dictionary = Game.rooms[idx]
	var d: Dictionary = Game.room_def(room.type)
	var cat: String = d.category
	var is_dirty: bool = cat == "guest" and room.dirty
	var is_infested: bool = is_dirty and Game.room_infested(room)
	var shift_active := Game.shift_active()
	var guest_visible := false
	var show_badge := false
	if cat == "guest":
		var guest_order := 0
		for j in range(idx):
			if String(Game.room_def(Game.rooms[j].type).get("category", "")) == "guest":
				guest_order += 1
		guest_visible = shift_active and not is_dirty and guest_order < _arrived_guests
		if room.items.size() == 0 and not is_dirty:
			var cheapest := Game.cheapest_item_price()
			show_badge = cheapest > 0 and Game.coins >= cheapest
	return {
		"floor": int(room.floor), "col": int(room.col), "w": int(room.w),
		"type": String(room.type), "dirty": is_dirty, "infested": is_infested,
		"items": room.items.duplicate(),
		"bed": String(room.get("base", {}).get("bed", "bed_basic")),
		"guest_visible": guest_visible, "show_badge": show_badge,
		"show_capacity": cat == "facility" and shift_active and _arrived_guests > 0,
		"show_maid": room.type == "housekeeping" and shift_active,
	}


func _make_room_button(idx: int) -> Button:
	var room: Dictionary = Game.rooms[idx]
	var d: Dictionary = Game.room_def(room.type)
	var cat: String = d.category
	var is_dirty: bool = cat == "guest" and room.dirty
	var is_infested: bool = is_dirty and Game.room_infested(room)

	var b := Button.new()
	# Konum/boyut artık kat/sütun/genişliğe göre çağıran (_rebuild_hotel)
	# tarafından tuval üzerinde manuel verilir (serbest blok yerleşimi).
	# Mockup'taki gibi odalar arası sabit, tek tip duvar/çerçeve rengi —
	# oda içi zaten kendi sanatıyla (guest_room_*.png) renkli; kutunun
	# kendisi rastgele renk-index'ine göre değişmemeli.
	var wall: Color = PALETTE.facade if cat == "guest" else WALLPAPERS.get(room.type, PALETTE.cream)
	# Duvar rengi (PALETTE.facade_line) artık kat şeridi kaldırıldığı için
	# yetersiz kalıyordu — oda, boş/gökyüzü fonunun içinde net bir "oda"
	# olarak okunsun diye belirgin bir duvar çerçevesi (PALETTE.frame,
	# kalın kenarlık) eklendi (kullanıcı isteği: "odaların etrafına duvar
	# gibi bir çerçeve").
	var border: Color = PALETTE.frame
	if is_infested:
		wall = wall.darkened(0.45)
	elif is_dirty:
		wall = wall.darkened(0.25)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var sb := _card_sb(wall if state != "hover" else wall.lightened(0.05), border, 8, 0.12)
		sb.set_border_width_all(7)
		b.add_theme_stylebox_override(state, sb)
	b.pressed.connect(func(): _on_room_tapped(idx, b))
	var rid: String = String(room.id)
	b.button_down.connect(func(): _on_room_press_start(rid, b))

	# Döşenmiş oda içi (Faz 4 — serbest yerleşimin taban eşya sistemine göre
	# gerçekten döşenmiş kabuk): duvar kağıdı (kademeye göre tonlanır) +
	# perde + zemin dokusu + oyuncunun gerçekten satın aldığı yatak
	# (room.base.bed — önceki hazır-sahne PNG havuzu, oyuncu yatağı
	# yükseltince görsel HİÇ değişmiyordu; artık değişiyor).
	if cat == "guest":
		var shell := Control.new()
		shell.set_anchors_preset(Control.PRESET_FULL_RECT)
		shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if is_infested:
			shell.modulate = Color(0.45, 0.45, 0.5)
		elif is_dirty:
			shell.modulate = Color(0.66, 0.66, 0.7)
		b.add_child(shell)

		var wallpaper := TextureRect.new()
		wallpaper.texture = _tex("res://assets/rooms/guest_wallpaper.svg")
		wallpaper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		wallpaper.stretch_mode = TextureRect.STRETCH_TILE
		wallpaper.set_anchors_preset(Control.PRESET_FULL_RECT)
		wallpaper.modulate = WALLPAPERS.get(room.type, PALETTE.cream)
		wallpaper.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shell.add_child(wallpaper)

		var curtains := TextureRect.new()
		curtains.texture = _tex("res://assets/rooms/guest_curtains.svg")
		curtains.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		curtains.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		curtains.anchor_right = 1.0
		curtains.anchor_bottom = 0.55
		curtains.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shell.add_child(curtains)

		var floor_tex := TextureRect.new()
		floor_tex.texture = _tex("res://assets/rooms/guest_floor.svg")
		floor_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		floor_tex.stretch_mode = TextureRect.STRETCH_TILE
		floor_tex.anchor_top = 1.0
		floor_tex.anchor_bottom = 1.0
		floor_tex.anchor_right = 1.0
		floor_tex.offset_top = -26
		floor_tex.modulate = PALETTE.floor_wood
		floor_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shell.add_child(floor_tex)

		var bed_id := String(room.get("base", {}).get("bed", "bed_basic"))
		var bed := TextureRect.new()
		bed.texture = _tex("res://assets/items/%s.svg" % bed_id)
		bed.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bed.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		bed.anchor_left = 0.5
		bed.anchor_right = 0.5
		bed.anchor_top = 1.0
		bed.anchor_bottom = 1.0
		bed.offset_left = -32
		bed.offset_right = 32
		bed.offset_top = -58
		bed.offset_bottom = -10
		bed.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shell.add_child(bed)

	# Zemin şeridi (misafir odası artık kendi zemin dokusunu çiziyor — bkz.
	# yukarıdaki shell; burada yalnızca tesisler için düz renk şerit)
	if cat != "guest":
		var floor_rect := ColorRect.new()
		floor_rect.color = PALETTE.floor_wood if not is_dirty else PALETTE.floor_wood.darkened(0.25)
		floor_rect.anchor_top = 1.0
		floor_rect.anchor_bottom = 1.0
		floor_rect.anchor_right = 1.0
		floor_rect.offset_top = -16
		floor_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(floor_rect)

	# İçerik: dekor eşyaları artık düz bir ikon şeridi değil, türüne göre
	# odanın sabit bir bölgesine (tavan/duvar/zemin) oturur.
	if cat == "guest":
		if room.items.size() == 0 and not is_dirty:
			# Oda görseli zaten döşenmiş görünüyor; sadece küçük bir ipucu.
			var hint := _label("boş oda", 12, PALETTE.muted)
			hint.anchor_left = 0.0
			hint.anchor_right = 1.0
			hint.anchor_top = 1.0
			hint.anchor_bottom = 1.0
			hint.offset_top = -18
			hint.offset_bottom = -4
			hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(hint)
			# Dekorasyon dürtmesi: en ucuz eşya karşılanabiliyorsa yanıp sönen rozet.
			var cheapest := Game.cheapest_item_price()
			if cheapest > 0 and Game.coins >= cheapest:
				b.add_child(_make_decorate_badge())
		else:
			var anchor_counts := {}
			for item_id in room.items:
				var anchor: String = String(Game.item_def(item_id).get("anchor", "floor_side"))
				var slots: Array = ANCHOR_POSITIONS.get(anchor, ANCHOR_POSITIONS.floor_side)
				var slot_i: int = int(anchor_counts.get(anchor, 0))
				anchor_counts[anchor] = slot_i + 1
				if slot_i >= slots.size():
					continue  # bu bölgenin slotları doldu — nadiren olur, fazlası atlanır
				var frac: Vector2 = slots[slot_i]
				var it := _icon("res://assets/items/%s.svg" % item_id, 34)
				it.anchor_left = frac.x
				it.anchor_right = frac.x
				it.anchor_top = frac.y
				it.anchor_bottom = frac.y
				it.offset_left = -17
				it.offset_right = 17
				it.offset_top = -17
				it.offset_bottom = 17
				b.add_child(it)
		# Misafir (vardiya açık + temiz odada) — dokununca dürtülür (gizli
		# müfettiş). Kullanıcı isteği: vardiya başlar başlamaz TÜM odalar
		# dolu görünmesin — misafir görseli ancak o odaya sıra gelecek kadar
		# misafir asansörle YUKARI ÇIKMIŞSA (_arrived_guests) belirir; odalar
		# Game.rooms sırasına göre teker teker dolar.
		var guest_order := 0
		for j in range(idx):
			if String(Game.room_def(Game.rooms[j].type).get("category", "")) == "guest":
				guest_order += 1
		if Game.shift_active() and not is_dirty and guest_order < _arrived_guests:
			var g_idx := idx % GUEST_TYPES.size()
			var guest := TextureButton.new()
			guest.texture_normal = _tex("res://assets/guests/guest_%s.svg" % GUEST_TYPES[g_idx])
			guest.ignore_texture_size = true
			guest.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			guest.custom_minimum_size = Vector2(44, 44)
			guest.anchor_left = 0.5
			guest.anchor_right = 0.5
			guest.anchor_top = 1.0
			guest.anchor_bottom = 1.0
			guest.offset_left = -22
			guest.offset_right = 22
			guest.offset_top = -50
			guest.offset_bottom = -6
			guest.mouse_filter = Control.MOUSE_FILTER_STOP
			guest.pressed.connect(func(): _on_guest_poked(guest))
			b.add_child(guest)
			_animate_guest(guest, idx, false)
	else:
		# Tesis/fonksiyonel oda içi: referans sayfadan kesilen hazır oda
		# görseli (varsa) — küçük ikon yerine misafir odalarıyla aynı
		# "tam döşenmiş" sunum. PNG yoksa _tex() eski SVG ikona düşer.
		var fac_bg := TextureRect.new()
		fac_bg.texture = _tex("res://assets/rooms/%s.svg" % room.type)
		fac_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		fac_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		fac_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		fac_bg.offset_left = 3
		fac_bg.offset_top = 3
		fac_bg.offset_right = -3
		fac_bg.offset_bottom = -3
		fac_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(fac_bg)
		# Temizlik odasında vardiya boyunca hizmetçi çalışır
		if room.type == "housekeeping" and Game.shift_active():
			var maid := _icon("res://assets/guests/maid.svg", 44)
			maid.anchor_left = 0.12
			maid.anchor_right = 0.12
			maid.anchor_top = 1.0
			maid.anchor_bottom = 1.0
			maid.offset_left = -22
			maid.offset_right = 22
			maid.offset_top = -60
			maid.offset_bottom = -14
			b.add_child(maid)
			_animate_guest(maid, idx, false)
		# Tesis kapasitesi: vardiyada içerideki müşteriler görünür
		if cat == "facility" and Game.shift_active() and _arrived_guests > 0:
			var cap_row := HBoxContainer.new()
			cap_row.add_theme_constant_override("separation", 1)
			cap_row.anchor_top = 1.0
			cap_row.anchor_bottom = 1.0
			cap_row.offset_top = -44
			cap_row.offset_bottom = -14
			cap_row.offset_left = 4
			cap_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(cap_row)
			for ci in int(d.get("capacity", 0)):
				var cg := _icon("res://assets/guests/guest_%s.svg" % GUEST_TYPES[(idx + ci) % GUEST_TYPES.size()], 26)
				cap_row.add_child(cg)
				_animate_guest(cg, idx + ci, false)

	# Kirli göstergesi (istilada hamamböceği)
	if is_dirty:
		var dust := _icon("res://assets/ui/roach.svg" if is_infested else "res://assets/ui/dust.svg", 52)
		dust.anchor_left = 0.5
		dust.anchor_right = 0.5
		dust.anchor_top = 0.5
		dust.anchor_bottom = 0.5
		dust.offset_left = -28
		dust.offset_right = 28
		dust.offset_top = -30
		dust.offset_bottom = 12
		dust.custom_minimum_size = Vector2.ZERO
		b.add_child(dust)

	# İsim bandı
	var plate := PanelContainer.new()
	var psb := StyleBoxFlat.new()
	psb.bg_color = PALETTE.banner_red if cat == "guest" else PALETTE.green_deep
	psb.set_corner_radius_all(4)
	psb.content_margin_left = 6
	psb.content_margin_right = 6
	psb.content_margin_top = 1
	psb.content_margin_bottom = 1
	plate.add_theme_stylebox_override("panel", psb)
	plate.position = Vector2(4, 4)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var plate_text: String = d.name
	if is_infested:
		plate_text = "İSTİLA! %d c" % int(Game.eco.infest.clean_cost)
	elif is_dirty:
		plate_text = "KİRLİ!"
	elif cat == "guest":
		plate_text = "%s · SP %d" % [Game.tier_name(Game.room_tier(room)), Game.room_score(room)]
	var pl := _label(plate_text, 11, PALETTE.cream_text)
	pl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(pl)
	b.add_child(plate)

	# Oda metresi (Hotel City): kademe ilerlemesi kırmızıdan yeşile dolar,
	# tavan kademede tam yeşil kalır.
	if cat == "guest" and not is_dirty:
		var score := Game.room_score(room)
		var t := Game.room_tier(room)
		var frac := 1.0
		if t < Game.eco.tier_thresholds.size() - 1:
			var lo := int(Game.eco.tier_thresholds[t])
			var hi := int(Game.eco.tier_thresholds[t + 1])
			frac = clampf(float(score - lo) / float(hi - lo), 0.0, 1.0)
		var meter_bg := ColorRect.new()
		meter_bg.color = Color(0, 0, 0, 0.3)
		meter_bg.position = Vector2(4, 23)
		meter_bg.size = Vector2(58, 7)
		meter_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(meter_bg)
		var meter := ColorRect.new()
		meter.color = Color(0.16, 0.62, 0.29) if frac >= 1.0 \
			else Color(0.85 - 0.55 * frac, 0.3 + 0.45 * frac, 0.18)
		meter.position = Vector2(5, 24)
		meter.size = Vector2(maxf(2.0, 56.0 * frac), 5)
		meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(meter)

	return b


## Boş misafir odasının sağ üstünde yanıp sönen altın "Dekore et!" rozeti.
func _make_decorate_badge() -> Control:
	var badge := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PALETTE.gold
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	sb.border_color = PALETTE.wood_dark
	sb.set_border_width_all(1)
	badge.add_theme_stylebox_override("panel", sb)
	badge.anchor_left = 1.0
	badge.anchor_right = 1.0
	badge.offset_left = -84
	badge.offset_right = -4
	badge.offset_top = 4
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := _label("✦ Dekore et!", 11, PALETTE.text)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(l)
	var tw := badge.create_tween().set_loops()
	tw.tween_property(badge, "modulate:a", 0.55, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(badge, "modulate:a", 1.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return badge


func _on_room_tapped(idx: int, btn: Control) -> void:
	var room: Dictionary = Game.rooms[idx]
	# Taşıma modu: artık hedef BOŞ bir hücre olmalı (serbest yerleşimde
	# değişken footprint'ler yüzünden iki dolu odayı takas etmek anlamsız —
	# bkz. plan, "Riskler"). Bir odaya dokunmak yalnızca kendisiyse iptal eder.
	if move_from != "":
		if move_from == String(room.id):
			move_from = ""
			_show_toast("Taşıma iptal edildi")
		else:
			move_from = ""
			_show_toast("Hedef dolu — taşımak için boş bir hücreye dokun")
		return
	if room.dirty:
		# Buton yeniden kurulumda yok olacağı için merkezi temizlemeden önce al
		var center := btn.global_position + btn.size / 2.0
		var cost := Game.clean_cost(idx)
		if Game.clean_room(idx):
			_play("clean")
			_spawn_clean_anim(center)
			if cost > 0:
				_show_toast("İstila temizlendi! (−%d coin, +2 XP)" % cost)
			else:
				_show_toast("Oda temizlendi (+2 XP)")
		elif cost > 0:
			_show_toast("İstila temizliği için %d coin gerek!" % cost)
		return
	selected_room = idx
	if Game.room_def(room.type).category == "guest":
		_open_popup("Oda Dekorasyonu", _build_room_popup)
	else:
		_open_popup("Tesis", _build_facility_popup)


## Açık-ama-boş bir hücreye dokunma: yalnızca "Taşı" modundaysa (bkz.
## move_from, _add_manage_buttons) anlamlı — seçili odayı buraya taşır.
## Yeni oda eklemek artık tıklamayla değil, mağaza rafından sürükleyip
## bırakmakla olur (bkz. _make_shop_tray_card, _finish_drag).
func _on_empty_cell_move_tapped(floor_i: int, col: int) -> void:
	if move_from == "":
		_show_toast("Oda eklemek için mağaza rafından bir kartı sürükle")
		return
	var mid := move_from
	move_from = ""
	if Game.move_room_to(mid, floor_i, col):
		_play("buy")
		_show_toast("Oda taşındı")
	else:
		_show_toast("Oda buraya sığmıyor")


## Mağaza rafındaki tek bir oda tipi kartı: ikon + isim + fiyat. Kilitliyse
## (seviye yetmiyorsa) devre dışı ve sürüklenemez. Tıklama/pressed'e değil
## button_down'a bağlanır — kart bir buton gibi tıklanmaz, yalnızca
## sürüklenerek binaya bırakılır (bkz. _on_shop_card_press_start).
func _make_shop_tray_card(type: String) -> Control:
	var d: Dictionary = Game.room_def(type)
	var locked := Game.level() < int(d.unlock_level)
	var b := Button.new()
	b.custom_minimum_size = Vector2(92, 104)
	b.disabled = locked
	for state in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(state, _card_sb(PALETTE.locked if locked else PALETTE.wood, PALETTE.facade_line, 10, 0.15))
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(col)
	var icon_wrap := CenterContainer.new()
	icon_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(icon_wrap)
	if String(d.category) == "guest":
		var sw := ColorRect.new()
		sw.color = WALLPAPERS.get(type, PALETTE.cream)
		sw.custom_minimum_size = Vector2(36, 36)
		sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_wrap.add_child(sw)
	else:
		icon_wrap.add_child(_icon("res://assets/rooms/%s.svg" % type, 36))
	var name_l := _label(String(d.name), 11, PALETTE.muted if locked else PALETTE.cream_text)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(name_l)
	var price_text := ("Sv.%d'de açılır" % int(d.unlock_level)) if locked else "%s coin" % _fmt(int(d.price))
	var price_l := _label(price_text, 10, PALETTE.muted if locked else PALETTE.gold_soft)
	price_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(price_l)
	if not locked:
		var t: String = type
		b.button_down.connect(func(): _on_shop_card_press_start(t))
	return b


# --- Oda sürükleyerek taşıma / mağazadan sürükleyerek ekleme -------------
# İkisi de aynı sürükleme durum makinesini paylaşır: _drag_room_id (mevcut
# odayı taşı) veya _drag_new_type (mağaza rafından yeni oda ekle) — aynı
# anda yalnızca biri dolu olabilir. Her ikisi de sadece İnşa Modu açıkken
# başlatılabilir (kullanıcı isteği: "yapım modu olsun, düzenleme/ekleme
# orada olsun").

## Bir oda kartına basıldığında çağrılır (button_down) — henüz sürükleme
## değil, yalnızca aday. Gerçek eşik main.gd:_update_room_drag'de.
func _on_room_press_start(room_id: String, _btn: Control) -> void:
	if not build_mode or move_from != "" or overlay.visible:
		return  # İnşa Modu kapalıyken, popup açıkken veya "Taşı" iki-dokunuşlu moddaysa karıştırma
	_drag_room_id = room_id
	_drag_new_type = ""
	_drag_active = false
	_drag_start_mouse = get_global_mouse_position()


## Mağaza rafındaki bir oda kartına basıldığında çağrılır — yeni oda
## sürüklemesi başlatır (bkz. _make_shop_tray_card).
func _on_shop_card_press_start(type: String) -> void:
	if not build_mode or move_from != "" or overlay.visible:
		return
	_drag_new_type = type
	_drag_room_id = ""
	_drag_active = false
	_drag_start_mouse = get_global_mouse_position()


## Her karede: basılı tutulan kart eşik kadar hareket ettiyse sürükleme
## moduna geç (ghost oluştur, imleci takip et); fare bırakılınca hücreye
## bırak (move_room_to / place_room) veya iptal et.
func _update_room_drag() -> void:
	if _drag_room_id == "" and _drag_new_type == "":
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if _drag_active:
			_finish_drag()
		else:
			_drag_room_id = ""
			_drag_new_type = ""
		return
	var mouse := get_global_mouse_position()
	if not _drag_active:
		if mouse.distance_to(_drag_start_mouse) < PAN_DRAG_THRESHOLD * 2.0:
			return
		_drag_active = true
		var w := int(Game.rooms[_room_index_by_id(_drag_room_id)].w) if _drag_room_id != "" else Game.room_footprint(_drag_new_type)
		var type_name := String(Game.room_def(Game.rooms[_room_index_by_id(_drag_room_id)].type).name) if _drag_room_id != "" else String(Game.room_def(_drag_new_type).name)
		_drag_ghost = _make_drag_ghost(w, type_name)
		add_child(_drag_ghost)
	_drag_ghost.position = mouse - _drag_ghost.size / 2.0


func _make_drag_ghost(w: int, type_name: String) -> Control:
	var g := PanelContainer.new()
	g.add_theme_stylebox_override("panel", _card_sb(PALETTE.gold_soft, PALETTE.facade_line, 8, 0.2))
	g.modulate = Color(1.0, 1.0, 1.0, 0.8)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.size = Vector2(w * CELL_W - CELL_GAP, CELL_H - CELL_GAP) * _zoom
	g.z_index = 100
	var l := _label(type_name, 13, PALETTE.text)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	g.add_child(l)
	return g


func _room_index_by_id(room_id: String) -> int:
	for i in Game.rooms.size():
		if String(Game.rooms[i].get("id", "")) == room_id:
			return i
	return -1


func _finish_drag() -> void:
	var room_id := _drag_room_id
	var new_type := _drag_new_type
	_drag_room_id = ""
	_drag_new_type = ""
	_drag_active = false
	if _drag_ghost != null and is_instance_valid(_drag_ghost):
		_drag_ghost.queue_free()
	_drag_ghost = null
	var cell := _canvas_cell_at_screen_pos(get_global_mouse_position())
	if cell.x < 1:
		_show_toast("Buraya bırakılamaz")
		return
	if room_id != "":
		if Game.move_room_to(room_id, cell.x, cell.y):
			_play("buy")
			_show_toast("Oda taşındı")
		else:
			_show_toast("Oda buraya sığmıyor")
	else:
		if Game.place_room(new_type, cell.x, cell.y):
			_play("buy")
			_show_toast("%s yerleştirildi!" % Game.room_def(new_type).name)
		else:
			_show_toast("Buraya sığmıyor, seviye yetmiyor ya da bedeli karşılanamıyor")


## Ekran koordinatını (global mouse) tuval yerel kat/sütununa çevirir.
## floor=-1 ise kat alanının dışına (lobi/sokak/çim ya da dışarı) bırakıldı.
func _canvas_cell_at_screen_pos(screen_pos: Vector2) -> Vector2i:
	var local := (screen_pos - zoom_viewport.global_position - _canvas_pan) / _zoom
	var floors_h := float(Game.floors) * CELL_H
	var grid_cols := int(Game.eco.building.grid_cols)
	if local.y < 0.0 or local.y >= floors_h or local.x < 0.0 or local.x >= grid_cols * CELL_W:
		return Vector2i(-1, -1)
	var floor_i := Game.floors - int(floor(local.y / CELL_H))
	var col := int(floor(local.x / CELL_W))
	if floor_i < 1 or floor_i > Game.floors or col < 0 or col >= grid_cols:
		return Vector2i(-1, -1)
	return Vector2i(floor_i, col)


## Uyuyan misafiri dürtme: Hotel City'deki gizli müfettiş şansı.
func _on_guest_poked(btn: Control) -> void:
	if Game.pokes_left() <= 0:
		_play("tap")
		_show_toast("Bugünlük dürtme hakkın bitti — yarın yine dene!")
		return
	var center := btn.global_position + btn.size / 2.0
	var bonus := Game.poke_guest()
	if bonus > 0:
		_play("collect")
		_spawn_sparkles(center)
		_show_toast("Gizli müfettiş çıktı! +%d coin (kalan hak: %d)" % [bonus, Game.pokes_left()])
	else:
		_play("tap")
		_show_toast("Misafir esnedi, uyumaya devam etti… (kalan hak: %d)" % Game.pokes_left())


func _on_collect() -> void:
	var from := collect_button.global_position + collect_button.size / 2.0
	var got := Game.collect()
	if got > 0:
		_play("collect")
		_fly_coins(from, got)
		_show_toast("+%s coin toplandı" % _fmt(got))


## Misafir canlandırması: kuyruktakiler paytak yürür, odadakiler kıpırdanır.
## Container yerleşimine dokunmamak için yalnızca rotation/scale kullanılır;
## tween misafir düğümüne bağlıdır, düğüm silinince kendiliğinden ölür.
func _animate_guest(g: Control, seed_i: int, walking: bool) -> void:
	g.pivot_offset = Vector2(g.custom_minimum_size.x / 2.0, g.custom_minimum_size.y)
	var dur := 0.32 + 0.06 * (seed_i % 4)
	var tw := g.create_tween().set_loops()
	if walking:
		tw.tween_property(g, "rotation", 0.09, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(g, "rotation", -0.09, dur * 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(g, "rotation", 0.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		tw.tween_property(g, "scale", Vector2(1.04, 0.95), dur * 2.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(g, "scale", Vector2.ONE, dur * 2.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Yaya akışının kalp atışı — iki bağımsız kanal:
## 1) Gelip geçen yayalar: vardiya olsun olmasın, seyrek/rastgele aralıkla
##    (kullanıcı isteği: sokak vardiyasız da yaşasın, insanlar ara ara geçsin).
## 2) Otele gelen misafirler: yalnızca vardiyada, hız oda sayısına
##    ölçeklenir (~2 dakikada dolacak tempo) ve boş oda kotası dolunca durur.
func _update_pedestrians(delta: float) -> void:
	if _walker_layer == null or not is_instance_valid(_walker_layer):
		return
	_ambient_timer += delta
	if _ambient_timer >= _next_ambient:
		_ambient_timer = 0.0
		_next_ambient = randf_range(10.0, 22.0)
		_spawn_passerby()
	if not Game.shift_active():
		return
	var guest_rooms := _guest_room_count()
	if _arrived_guests + _queue_count + _boarding + _inbound >= guest_rooms:
		return  # tüm odalara yetecek misafir zaten geldi/yolda — yenisi gelmesin
	_arrival_timer += delta
	if _arrival_timer >= _next_arrival:
		_arrival_timer = 0.0
		# Oda sayısına ölçekli tempo: N odalı otel ~110 saniyede dolsun
		# (kullanıcı isteği: "20 odam var, dolması 1-2 dakika almalı").
		var base := clampf(110.0 / maxf(float(guest_rooms), 1.0), 4.0, 25.0)
		_next_arrival = base * randf_range(0.75, 1.35)
		_spawn_arriving_pedestrian()


func _guest_room_count() -> int:
	var n := 0
	for r in Game.rooms:
		if String(Game.room_def(r.type).get("category", "")) == "guest":
			n += 1
	return n


## Sıradan bir yaya: otele girmez, kaldırım boyunca yürüyüp ekrandan çıkar.
## Yön rastgeledir; vardiya gerekmez.
func _spawn_passerby() -> void:
	var canvas_w: float = int(Game.eco.building.grid_cols) * CELL_W
	var walk_y := _sidewalk_local_y(36.0)
	var gicon := _icon("res://assets/guests/guest_%s.svg" % GUEST_TYPES[randi() % GUEST_TYPES.size()], 36)
	gicon.pivot_offset = Vector2(18, 36)
	_walker_layer.add_child(gicon)
	_animate_guest(gicon, randi() % GUEST_TYPES.size(), true)
	var tw := gicon.create_tween()
	if randf() < 0.5:
		gicon.position = Vector2(canvas_w + 24.0, walk_y)
		tw.tween_property(gicon, "position:x", -64.0, randf_range(7.0, 11.0)) \
			.set_trans(Tween.TRANS_LINEAR)
	else:
		gicon.position = Vector2(-64.0, walk_y)
		tw.tween_property(gicon, "position:x", canvas_w + 24.0, randf_range(7.0, 11.0)) \
			.set_trans(Tween.TRANS_LINEAR)
	tw.tween_callback(gicon.queue_free)


## Otele gelen bir misafir: soldan kaldırım boyunca sağ uçtaki kapıya yürür;
## kapıda kaldırım ikonu kaldırılır ve misafir LOBİDE görünür şekilde
## kapıdan asansöre yürür (bkz. _spawn_lobby_walker) — kullanıcı isteği:
## "lobide yürümeleri gözükmüyor".
func _spawn_arriving_pedestrian() -> void:
	var walk_y := _sidewalk_local_y(36.0)
	var gicon := _icon("res://assets/guests/guest_%s.svg" % GUEST_TYPES[randi() % GUEST_TYPES.size()], 36)
	gicon.pivot_offset = Vector2(18, 36)
	gicon.position = Vector2(-40.0, walk_y)
	_walker_layer.add_child(gicon)
	_animate_guest(gicon, randi() % GUEST_TYPES.size(), true)
	_inbound += 1
	var tw := gicon.create_tween()
	tw.tween_property(gicon, "position:x", _door_local_x(36.0), randf_range(4.5, 6.0)) \
		.set_trans(Tween.TRANS_LINEAR)
	tw.tween_callback(func():
		gicon.queue_free()
		_spawn_lobby_walker())


## Kapıdan giren misafirin lobi içindeki yürüyüşü: giriş boşluğundan
## resepsiyona/asansöre doğru yürür. Konumu `tween_method` ile her karede
## izlenir; ELEVATOR_PROXIMITY_RADIUS içine girdiği AN (yürüyüş bitmeden,
## kapının tam önüne varır varmaz) asansör kuyruğuna (_queue_count) yazılır
## — sabit bir varış/bekleme süresi yerine gerçek konuma dayalı bir tetik.
## Misafir bu noktada solmaz; kapı gerçekten açılıp bindiğinde
## _board_waiting_guests() onu kaybettirir.
func _spawn_lobby_walker() -> void:
	if _walker_layer == null or not is_instance_valid(_walker_layer):
		_inbound = maxi(0, _inbound - 1)
		return
	var canvas_w: float = int(Game.eco.building.grid_cols) * CELL_W
	var lobby_y := float(Game.floors) * CELL_H
	var gicon := _icon("res://assets/guests/guest_%s.svg" % GUEST_TYPES[randi() % GUEST_TYPES.size()], 36)
	gicon.pivot_offset = Vector2(18, 36)
	# Lobi zemininde: ikon tabanı lobinin taban şeridine otursun.
	var start_x := canvas_w - DOOR_W - 10.0
	gicon.position = Vector2(start_x, lobby_y + LOBBY_H - 50.0)
	_walker_layer.add_child(gicon)
	_animate_guest(gicon, randi() % GUEST_TYPES.size(), true)
	# Asansörün tuval-yerel merkezi: lobi paneli CELL_GAP/2'de başlar,
	# genişliği canvas_w - DOOR_W - CELL_GAP; asansör lobinin ~%49'unda
	# (bkz. elevator_tex anchor'ları).
	var elev_x := CELL_GAP * 0.5 + (canvas_w - DOOR_W - CELL_GAP) * 0.49 - 18.0
	var triggered := false
	var tw := gicon.create_tween()
	tw.tween_method(func(x: float):
		if not is_instance_valid(gicon):
			return
		gicon.position.x = x
		if not triggered and absf(x - elev_x) <= ELEVATOR_PROXIMITY_RADIUS:
			triggered = true
			_inbound = maxi(0, _inbound - 1)
			if Game.shift_active():
				_queue_count += 1
				_waiting_guest_icons.append(gicon)
			else:
				gicon.queue_free()
		, start_x, elev_x, 2.8).set_trans(Tween.TRANS_LINEAR)


## Vardiya açılış sahnesi: küçük bir karşılama grubu soldan kaldırım boyunca
## kapıya yürür ve lobiden geçip asansör kuyruğuna katılır. Grup, boş oda
## sayısını aşmayacak kadar küçük tutulur.
func _guest_walk_in() -> void:
	await get_tree().process_frame  # yeni yerleşim otursun
	if _walker_layer == null or not is_instance_valid(_walker_layer):
		return
	var walk_y := _sidewalk_local_y(36.0)
	var door_x := _door_local_x(36.0)
	var count := clampi(_guest_room_count(), 1, 3)
	for i in count:
		var gicon := _icon("res://assets/guests/guest_%s.svg" % GUEST_TYPES[i % GUEST_TYPES.size()], 36)
		gicon.position = Vector2(-40.0 - i * 44.0, walk_y)
		gicon.pivot_offset = Vector2(18, 36)
		_walker_layer.add_child(gicon)
		_animate_guest(gicon, i, true)
		_inbound += 1
		var tw := gicon.create_tween()
		tw.tween_property(gicon, "position:x", door_x, 3.6 + i * 0.4) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_callback(func():
			gicon.queue_free()
			_spawn_lobby_walker())


## Temizlik geri bildirimi: önce süpürge sağa sola süpürür, ardından parıltılar.
func _spawn_clean_anim(center: Vector2) -> void:
	var broom := _icon("res://assets/ui/broom.svg", 48)
	broom.position = center + Vector2(-24.0, -34.0)
	broom.pivot_offset = Vector2(24, 44)
	broom.z_index = 61
	add_child(broom)
	var tw := create_tween()
	for i in 3:
		tw.tween_property(broom, "rotation", 0.45, 0.11).set_trans(Tween.TRANS_SINE)
		tw.tween_property(broom, "rotation", -0.45, 0.11).set_trans(Tween.TRANS_SINE)
	tw.tween_property(broom, "modulate:a", 0.0, 0.18)
	tw.tween_callback(broom.queue_free)
	get_tree().create_timer(0.5).timeout.connect(func(): _spawn_sparkles(center))


## Oda üzerinde büyüyüp sönen altın parıltılar.
func _spawn_sparkles(center: Vector2) -> void:
	for i in 7:
		var s := _icon("res://assets/ui/sparkle.svg", 22)
		s.position = center + Vector2(randf_range(-46.0, 46.0), randf_range(-40.0, 28.0))
		s.pivot_offset = Vector2(11, 11)
		s.scale = Vector2.ZERO
		s.z_index = 60
		add_child(s)
		var tw := create_tween()
		tw.tween_interval(i * 0.05)
		tw.tween_property(s, "scale", Vector2.ONE * randf_range(0.8, 1.5), 0.2) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(s, "rotation", randf_range(-0.7, 0.7), 0.4)
		tw.tween_property(s, "modulate:a", 0.0, 0.3)
		tw.tween_callback(s.queue_free)


## Toplama geri bildirimi: kasadan coin sayacına uçan coin'ler.
func _fly_coins(from: Vector2, amount: int) -> void:
	var to := coins_label.global_position + coins_label.size / 2.0
	var count := clampi(3 + amount / 200, 4, 10)
	for i in count:
		var cn := _icon("res://assets/ui/coin.svg", 24)
		cn.position = from + Vector2(randf_range(-40.0, 40.0), randf_range(-12.0, 12.0))
		cn.z_index = 60
		add_child(cn)
		var tw := create_tween()
		tw.tween_interval(i * 0.045)
		tw.tween_property(cn, "position", to, 0.45) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(cn, "modulate:a", 0.55, 0.45)
		tw.tween_callback(cn.queue_free)


func _cycle_speed() -> void:
	speed_index = (speed_index + 1) % SPEEDS.size()
	Game.simulate_to(Game.now())
	var remaining_real := maxf(0.0, Game.shift_end_unix - Game.now())
	Game.shift_end_unix = Game.now() + remaining_real * Game.time_scale / SPEEDS[speed_index]
	Game.time_scale = SPEEDS[speed_index]
	_refresh()


# --- Popuplar ----------------------------------------------------------

## Oyunun kendi görsel diliyle (yuvarlak kart, PALETTE renkleri, _panel/_label/
## _button) tek eylem butonlu basit bir modal — açılış tutorial'ı, günlük ödül
## ve "sen yokken" popup'ları için ortak. Godot'un varsayılan AcceptDialog'u
## (native tema, her adımda içeriğe göre değişen boyut/konum) hem oyunun geri
## kalanıyla görsel olarak uyuşmuyordu hem de art arda açılan popup'larda
## "kapanmadı" hissi veriyordu — bunun yerine her zaman aynı sabit panelde,
## dışına tıklayınca/ESC ile de kapanabilen tek bir Control ağacı kullanılır.
## on_action: eylem butonuna basılınca çağrılır. on_dismiss: dışına tıklayarak/
## ESC ile kapatılırsa çağrılır (verilmezse hiçbir şey yapılmaz).
func _show_simple_modal(title: String, text: String, action_text: String,
		on_action: Callable, on_dismiss: Callable = Callable()) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.2, 0.15, 0.05, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.z_index = 90
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.add_child(center)
	var panel := _panel(PALETTE.cream, PALETTE.facade_line)
	panel.custom_minimum_size = Vector2(420, 0)
	center.add_child(panel)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 14)
	panel.add_child(pv)
	pv.add_child(_label(title, 20, PALETTE.wood_dark))
	var body := _label(text, 15, PALETTE.text)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pv.add_child(body)
	var action_b := _button(action_text, 16, PALETTE.green_deep, PALETTE.cream_text)
	action_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pv.add_child(action_b)
	var closed := false
	var do_close := func():
		if closed:
			return
		closed = true
		dim.queue_free()
	action_b.pressed.connect(func():
		do_close.call()
		if on_action.is_valid():
			on_action.call())
	dim.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			do_close.call()
			if on_dismiss.is_valid():
				on_dismiss.call())
	add_child(dim)
	_play("tap")


func _open_popup(title: String, builder: Callable) -> void:
	_play("tap")
	popup_title.text = title
	popup_builder = builder
	overlay.visible = true
	_rebuild_popup()


func _close_popup() -> void:
	overlay.visible = false
	popup_builder = Callable()
	selected_room = -1


func _rebuild_popup() -> void:
	for c in popup_content.get_children():
		popup_content.remove_child(c)
		c.queue_free()
	popup_builder.call(popup_content)


func _build_shift_popup(c: VBoxContainer) -> void:
	if Game.shift_active():
		c.add_child(_label("Vardiya sürüyor — bitimine %s." % _fmt_hms(Game.shift_remaining_game_hours()), 16, PALETTE.text))
		c.add_child(_label("Birikimi istediğin an toplayabilirsin.", 14, PALETTE.muted))
		var gem_cost := Game.skip_shift_gem_cost()
		var skip_b := _button("Elmasla şimdi bitir — %d elmas" % gem_cost, 15, PALETTE.green_deep, PALETTE.cream_text)
		skip_b.disabled = Game.gems < gem_cost
		skip_b.pressed.connect(func():
			if Game.skip_shift():
				_play("buy")
				_show_toast("Vardiya elmasla tamamlandı — birikim kasada!")
				_close_popup())
		c.add_child(skip_b)
		if Game.now() < Game.boost_end_unix:
			var left_min := int((Game.boost_end_unix - Game.now()) / 60.0)
			c.add_child(_label("Reklam bonusu aktif: gelir ×%.1f (%d dk kaldı)" % [Game.boost_mult, maxi(0, left_min)], 13, PALETTE.green_deep))
		else:
			var boost_b := _button("Reklam izle — 30 dk gelir ×2", 15, PALETTE.wood_dark, PALETTE.cream_text)
			_button_icon(boost_b, "res://assets/ui/ad_video.png")
			boost_b.pressed.connect(func():
				Ads.show_rewarded(func():
					Game.start_income_boost(30.0, 2.0)
					_play("buy")
					_show_toast("Reklam bonusu başladı: 30 dk gelir ×2!")
					_rebuild_popup()))
			c.add_child(boost_b)
		return
	c.add_child(_label("Süre seç — saatlik maliyet hepsinde aynıdır:", 14, PALETTE.muted))
	for hours: int in [1, 4, 8, 24]:
		var cost := Game.shift_cost(hours)
		var est: float = Game.hourly_income() * hours
		var b := _button("%d saat — maliyet %s · tahmini gelir ~%s" % [hours, _fmt(cost), _fmt(int(est))], 15, PALETTE.wood, PALETTE.cream_text)
		b.disabled = Game.coins < cost
		b.pressed.connect(func():
			if Game.start_shift(hours):
				_play("shift")
				_guest_walk_in()
				_show_toast("%d saatlik vardiya başladı!" % hours)
				_close_popup())
		c.add_child(b)
	if Game.auto_renew_shift:
		c.add_child(_label("Otomatik yenileme açık: vardiya bitince coin yeterse kendiliğinden devam eder.", 12, PALETTE.green_deep))
	else:
		c.add_child(_label("Otomatik yenileme kapalı: vardiya bitince elle yeniden başlatman gerekir (Ayarlar).", 12, PALETTE.muted))
	c.add_child(_label("Not: temizlenmeyen odalar gelir üretmez. Uzun vardiyada Temizlik Odası şart!", 13, PALETTE.banner_red))


func _build_staff_popup(c: VBoxContainer) -> void:
	var tier: int = Game.staff_tier
	var max_tier: int = int(Game.eco.staff_upgrade.max_tier)
	c.add_child(_label("Personel kademesi: %d / %d" % [tier, max_tier], 16, PALETTE.text))
	c.add_child(_label(
		"Vardiya maliyeti: %%%.0f indirimli  ·  Saatlik gelir: +%%%.0f" % [
			(1.0 - Game.staff_cost_mult()) * 100.0, (Game.staff_income_mult() - 1.0) * 100.0],
		14, PALETTE.muted))
	if tier >= max_tier:
		c.add_child(_label("Personel en üst kademede — daha fazla yükseltme yok.", 14, PALETTE.green_deep))
		return
	var cost := Game.staff_upgrade_cost()
	var next_cost_mult := 1.0 - pow(1.0 - float(Game.eco.staff_upgrade.cost_reduction_pct), tier + 1)
	var next_income_mult := pow(1.0 + float(Game.eco.staff_upgrade.income_boost_pct), tier + 1) - 1.0
	var b := _button(
		"Kademeyi yükselt — %s coin\nSonraki: -%%%.0f maliyet, +%%%.0f gelir" % [
			_fmt(cost), next_cost_mult * 100.0, next_income_mult * 100.0],
		15, PALETTE.wood, PALETTE.cream_text)
	b.disabled = not Game.can_buy_staff_upgrade()
	b.pressed.connect(func():
		if Game.buy_staff_upgrade():
			_play("buy")
			_show_toast("Personel kalitesi yükseltildi! (Kademe %d)" % Game.staff_tier))
	c.add_child(b)


## Toplam kullanılan blok sayısı (değişken footprint yüzünden artık
## rooms.size() ile aynı şey değil — bkz. plan §1).
func _blocks_used() -> int:
	var total := 0
	for r in Game.rooms:
		total += int(r.w)
	return total


func _build_room_popup(c: VBoxContainer) -> void:
	if selected_room < 0 or selected_room >= Game.rooms.size():
		return
	var room: Dictionary = Game.rooms[selected_room]
	var tier := Game.room_tier(room)
	c.add_child(_label("%s — %s · SP %d · %d eşya" % [
		Game.room_def(room.type).name, Game.tier_name(tier),
		Game.room_score(room), room.items.size()], 16, PALETTE.text))
	if tier < Game.eco.tier_names.size() - 1:
		var next_th := int(Game.eco.tier_thresholds[tier + 1])
		c.add_child(_label("Sonraki kademe (%s): SP %d gerekir" % [Game.tier_name(tier + 1), next_th], 13, PALETTE.wood_dark))

	# Hazır dekor paketleri: tek dokunuşla, tek tek almaktan ucuz
	var bundles: Array = Game.eco.get("bundles", [])
	if not bundles.is_empty():
		c.add_child(_label("Hazır paketler — tek dokunuşla dekor:", 14, PALETTE.muted))
		for bd in bundles:
			var sp_total := 0
			for iid in bd.items:
				sp_total += int(Game.item_def(iid).sp)
			var pb := _button("%s — SP +%d — %s coin (%%%d indirimli)" % [
				bd.name, sp_total, _fmt(Game.bundle_price(bd)), int(float(bd.discount) * 100.0)],
				14, PALETTE.green_deep, PALETTE.cream_text)
			var need_lv := Game.bundle_unlock_level(bd)
			if Game.level() < need_lv:
				pb.text = "%s — Seviye %d'de açılır" % [bd.name, need_lv]
				pb.disabled = true
			else:
				pb.disabled = not Game.can_buy_bundle(bd)
				var bid: String = bd.id
				pb.pressed.connect(func():
					if Game.buy_bundle(selected_room, bid):
						_play("buy")
						_show_toast("%s yerleştirildi!" % Game.bundle_def(bid).name))
			c.add_child(pb)

	# Taban eşyalar: duvar kağıdı / zemin / yatak — odayla birlikte ücretsiz
	# varsayılanla gelir, burada YÜKSELTİLİR (öncekinin yerine geçer, birikmez).
	# Bu, oda görselinin zaten "döşenmiş" görünmesiyle mağazanın çelişmesi
	# sorununu çözer: yatak zaten var, burada sadece daha iyisine geçiliyor.
	var lv := Game.level()
	var base: Dictionary = room.get("base", {})
	var slot_names := {"wallpaper": "Duvar Kağıdı", "floor": "Zemin", "bed": "Yatak"}
	for slot_key in ["bed", "wallpaper", "floor"]:
		if not base.has(slot_key):
			continue  # ör. tesis odalarında yatak yok
		var current: String = String(base[slot_key])
		var alts: Array = Game.eco.items.filter(func(it): return String(it.get("slot", "")) == slot_key)
		if alts.size() <= 1:
			continue  # tek seçenek varsa yükseltilecek bir şey yok, göstermeye gerek yok
		c.add_child(_label(String(slot_names.get(slot_key, slot_key)) + ":", 14, PALETTE.muted))
		for it in alts:
			var owned: bool = current == String(it.id)
			var b2 := _button("%s%s" % [it.name, "  ✓ mevcut" if owned else " — %s coin" % _fmt(int(it.price))],
				13, PALETTE.wood, PALETTE.cream_text)
			b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if owned:
				b2.disabled = true
			elif lv < int(it.get("unlock_level", 1)):
				b2.text = "%s — Seviye %d'de açılır" % [it.name, int(it.unlock_level)]
				b2.disabled = true
			else:
				b2.disabled = not Game.can_afford_item(it)
				var iid2: String = it.id
				b2.pressed.connect(func():
					if Game.upgrade_base(selected_room, iid2):
						_play("buy")
						_show_toast("%s güncellendi!" % Game.item_def(iid2).name))
			c.add_child(b2)

	c.add_child(_label("Dekor eşyası ekle:", 14, PALETTE.muted))
	for it in Game.eco.items:
		if not it.has("anchor"):
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		c.add_child(row)
		row.add_child(_icon("res://assets/items/%s.svg" % it.id, 40))
		var price_text: String = "%d elmas ◆" % int(it.get("gem_price", 0)) if Game.item_is_premium(it) else "%s coin" % _fmt(int(it.price))
		var b := _button("%s — SP +%d — %s" % [it.name, int(it.sp), price_text], 14,
			PALETTE.green_deep if Game.item_is_premium(it) else PALETTE.wood, PALETTE.cream_text)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if lv < int(it.get("unlock_level", 1)):
			b.text = "%s — Seviye %d'de açılır" % [it.name, int(it.unlock_level)]
			b.disabled = true
		elif Game.room_has_item(selected_room, it.id):
			b.text = "%s — sahipsin ✓" % it.name
			b.disabled = true
		else:
			b.disabled = not Game.can_afford_item(it)
			var iid: String = it.id
			b.pressed.connect(func():
				if Game.buy_item(selected_room, iid):
					_play("buy")
					_show_toast("%s yerleştirildi (+%d SP)" % [Game.item_def(iid).name, int(Game.item_def(iid).sp)]))
		row.add_child(b)
	_add_manage_buttons(c)


func _build_facility_popup(c: VBoxContainer) -> void:
	if selected_room < 0 or selected_room >= Game.rooms.size():
		return
	var room: Dictionary = Game.rooms[selected_room]
	var d: Dictionary = Game.room_def(room.type)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	c.add_child(row)
	row.add_child(_icon("res://assets/rooms/%s.svg" % room.type, 48))
	row.add_child(_label(String(d.name), 17, PALETTE.text))
	if d.category == "facility":
		c.add_child(_label("Saatlik +%d coin taban gelir · yıldız çeşitliliğine katkı" % int(d.base_income), 13, PALETTE.muted))
	else:
		c.add_child(_label("Kirlenen odaları kendiliğinden temizler — gelir hiç durmaz.", 13, PALETTE.muted))
	_add_manage_buttons(c)


## Oda popup'larının ortak yönetim satırı: Taşı + onaylı Sat.
func _add_manage_buttons(c: VBoxContainer) -> void:
	c.add_child(_spacer_y(6))
	if not build_mode:
		c.add_child(_label("Taşımak veya satmak için önce İnşa Modu'nu aç.", 12, PALETTE.muted))
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	c.add_child(row)
	var ridx := selected_room
	var mv := _button("Taşı", 14, PALETTE.wood_dark, PALETTE.cream_text)
	mv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mv.pressed.connect(func():
		move_from = String(Game.rooms[ridx].id)
		_close_popup()
		_show_toast("Boş bir hücreye dokun — iptal için odana tekrar dokun"))
	row.add_child(mv)
	var sell_text := "Sat — +%s coin" % _fmt(Game.room_sell_value(ridx))
	var sell_gems := Game.room_sell_gem_value(ridx)
	if sell_gems > 0:
		sell_text += " +%d elmas" % sell_gems
	var sl := _button(sell_text, 14, PALETTE.banner_red, PALETTE.cream_text)
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.pressed.connect(func():
		if not sl.get_meta("armed", false):
			sl.set_meta("armed", true)
			sl.text = "Emin misin? Satmak için tekrar dokun"
			return
		if Game.sell_room(ridx):
			_play("buy")
			_close_popup()
			_show_toast("Oda satıldı — iade kasada")
		else:
			_show_toast("Son oda satılamaz!"))
	row.add_child(sl)


func _build_stats_popup(c: VBoxContainer) -> void:
	var rows := [
		["Toplam toplanan gelir", "%s coin" % _fmt(Game.stat_collected_total)],
		["Toplama sayısı", str(Game.stat_collects)],
		["Temizlenen oda", str(Game.stat_cleans)],
		["Başlatılan vardiya", str(Game.stat_shifts)],
		["Oda sayısı", "%d oda (%d / %d blok dolu)" % [Game.rooms.size(), _blocks_used(), Game.max_slots()]],
		["Tesis çeşitliliği", "%d / 5" % Game.facility_diversity()],
		["Yıldız derecesi", "%d / 5" % Game.star_rating()],
		["Seviye", "%d (XP %s)" % [Game.level(), _fmt(Game.xp)]],
		["Saatlik gelir (şu an)", "%.0f coin" % Game.hourly_income()],
		["Prestij çarpanı", "×%.2f (devir %d)" % [Game.prestige_mult(), Game.prestige_level]],
		["Günlük giriş serisi", "%d gün" % Game.daily_streak],
	]
	for r in rows:
		var row := HBoxContainer.new()
		c.add_child(row)
		var ll := _label(String(r[0]), 14, PALETTE.muted)
		ll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(ll)
		row.add_child(_label(String(r[1]), 14, PALETTE.text))
	c.add_child(_spacer_y(6))
	c.add_child(_label("Vardiya geçmişi (son %d):" % Game.shift_history.size(), 14, PALETTE.wood_dark))
	if Game.shift_history.is_empty():
		c.add_child(_label("Henüz vardiya başlatılmadı.", 13, PALETTE.muted))
		return
	var bias: int = int(Time.get_time_zone_from_system().bias) * 60
	for i in range(Game.shift_history.size() - 1, -1, -1):
		var h: Dictionary = Game.shift_history[i]
		var dt := Time.get_datetime_dict_from_unix_time(int(float(h.at)) + bias)
		c.add_child(_label("%02d.%02d %02d:%02d — %d saat · maliyet %s coin" % [
			dt.day, dt.month, dt.hour, dt.minute, int(h.hours), _fmt(int(h.cost))], 13, PALETTE.text))


func _build_settings_popup(c: VBoxContainer) -> void:
	var s_b := _button("Ses efektleri: %s" % ("Açık" if Game.sound_on else "Kapalı"), 15,
		PALETTE.wood if Game.sound_on else PALETTE.wood_dark, PALETTE.cream_text)
	s_b.pressed.connect(func():
		Game.sound_on = not Game.sound_on
		Game.save_game()
		_play("tap")
		_rebuild_popup())
	c.add_child(s_b)

	var m_b := _button("Lobi müziği: %s" % ("Açık" if Game.music_on else "Kapalı"), 15,
		PALETTE.wood if Game.music_on else PALETTE.wood_dark, PALETTE.cream_text)
	m_b.pressed.connect(func():
		Game.music_on = not Game.music_on
		music_player.playing = Game.music_on
		Game.save_game()
		_rebuild_popup())
	c.add_child(m_b)

	var ar_b := _button("Vardiya otomatik yenilensin: %s" % ("Açık" if Game.auto_renew_shift else "Kapalı"), 15,
		PALETTE.wood if Game.auto_renew_shift else PALETTE.wood_dark, PALETTE.cream_text)
	ar_b.pressed.connect(func():
		Game.auto_renew_shift = not Game.auto_renew_shift
		Game.save_game()
		_play("tap")
		_rebuild_popup())
	c.add_child(ar_b)
	c.add_child(_label("Açıkken bir vardiya bitince, coin yeterse aynı süreyle otomatik yenilenir — otel sen yokken de üretime devam eder.", 12, PALETTE.muted))

	c.add_child(_spacer_y(10))
	c.add_child(_label("Premium", 15, PALETTE.wood_dark))
	if Game.remove_ads:
		c.add_child(_label("Reklamlar kaldırıldı. Teşekkürler!", 13, PALETTE.green_deep))
	else:
		var no_ads_b := _button("Reklamları Kaldır", 15, PALETTE.green_deep, PALETTE.cream_text)
		_button_icon(no_ads_b, "res://assets/ui/ad_video.png")
		no_ads_b.pressed.connect(func():
			IAP.purchase(IAP.PRODUCT_REMOVE_ADS, func(ok: bool):
				if ok:
					Game.remove_ads = true
					Game.save_game()
					_play("buy")
					_show_toast("Reklamlar kaldırıldı!")
					_rebuild_popup()))
		c.add_child(no_ads_b)
	if Game.permanent_income_mult > 1.0:
		c.add_child(_label("Kazanç çarpanı aktif: ×%.1f" % Game.permanent_income_mult, 13, PALETTE.green_deep))
	else:
		var x2_b := _button("Kazancı 2x Yap", 15, PALETTE.green_deep, PALETTE.cream_text)
		_button_icon(x2_b, "res://assets/ui/dollar.png")
		x2_b.pressed.connect(func():
			IAP.purchase(IAP.PRODUCT_INCOME_2X, func(ok: bool):
				if ok:
					Game.permanent_income_mult = 2.0
					Game.save_game()
					_play("buy")
					_show_toast("Kazanç 2x oldu!")
					_rebuild_popup()))
		c.add_child(x2_b)

	c.add_child(_spacer_y(10))
	c.add_child(_label("Prestij — çarpan ×%.2f (devir %d)" % [Game.prestige_mult(), Game.prestige_level], 15, PALETTE.wood_dark))
	if Game.can_prestige():
		var next_mult: float = Game.prestige_mult() + float(Game.eco.prestige.mult_gain)
		var p_b := _button("Oteli devret — yeni çarpan ×%.2f" % next_mult, 15, PALETTE.green_deep, PALETTE.cream_text)
		p_b.pressed.connect(func():
			if p_b.get_meta("armed", false):
				Game.do_prestige()
				_close_popup()
				_show_toast("Devrettin! Yeni gelir çarpanı: ×%.2f" % Game.prestige_mult())
			else:
				p_b.set_meta("armed", true)
				p_b.text = "Emin misin? İlerleme sıfırlanacak, tekrar dokun")
		c.add_child(p_b)
		c.add_child(_label("Devretmek coin, oda, görev ve başarım ilerlemeni sıfırlar; çarpan kalıcıdır.", 12, PALETTE.muted))
	else:
		c.add_child(_label("Devretmek için Seviye %d gerekir (şu an %d)." % [int(Game.eco.prestige.min_level), Game.level()], 13, PALETTE.muted))

	c.add_child(_spacer_y(10))
	c.add_child(_label("Kaydı taşı — bulut yerine paylaşılabilir kod:", 15, PALETTE.wood_dark))
	var export_code := Game.export_save_code()
	var export_field := LineEdit.new()
	export_field.text = export_code
	export_field.editable = false
	c.add_child(export_field)
	var copy_b := _button("Kodu panoya kopyala", 14, PALETTE.wood, PALETTE.cream_text)
	copy_b.pressed.connect(func():
		DisplayServer.clipboard_set(export_code)
		_show_toast("Kayıt kodu panoya kopyalandı"))
	c.add_child(copy_b)

	c.add_child(_spacer_y(6))
	c.add_child(_label("Başka bir kaydı içe aktar:", 14, PALETTE.text))
	var import_field := LineEdit.new()
	import_field.placeholder_text = "Kayıt kodunu buraya yapıştır…"
	c.add_child(import_field)
	var import_b := _button("İçe aktar — mevcut kaydın üzerine yazar", 14, PALETTE.banner_red, PALETTE.cream_text)
	import_b.pressed.connect(func():
		if not import_b.get_meta("armed", false):
			import_b.set_meta("armed", true)
			import_b.text = "Emin misin? Üzerine yazmak için tekrar dokun"
			return
		if Game.import_save_code(import_field.text):
			Game.save_game()
			_close_popup()
			_show_toast("Kayıt içe aktarıldı!")
		else:
			_show_toast("Kod geçersiz — kontrol edip tekrar dene"))
	c.add_child(import_b)

	c.add_child(_spacer_y(8))
	c.add_child(_label("Tehlikeli bölge:", 13, PALETTE.banner_red))
	var r_b := _button("Kaydı sıfırla", 15, PALETTE.banner_red, PALETTE.cream_text)
	r_b.pressed.connect(func():
		if r_b.get_meta("armed", false):
			Game.reset_game()
			_close_popup()
			_show_toast("Kayıt sıfırlandı — yeni oyun başladı!")
		else:
			r_b.set_meta("armed", true)
			r_b.text = "Emin misin? Silmek için tekrar dokun")
	c.add_child(r_b)
	c.add_child(_label("Sıfırlama tüm ilerlemeyi kalıcı olarak siler.", 12, PALETTE.muted))


func _build_quests_popup(c: VBoxContainer) -> void:
	var q: Dictionary = Game.current_quest()
	if q.is_empty():
		c.add_child(_label("Tüm görevler tamamlandı. Tebrikler, otelci!", 16, PALETTE.green_deep))
	else:
		var p: Array = Game.quest_progress(q)
		c.add_child(_label(String(q.name), 19, PALETTE.wood_dark))
		var desc := _label(String(q.desc), 15, PALETTE.text)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		c.add_child(desc)
		c.add_child(_label("İlerleme: %d / %d" % [mini(p[0], p[1]), p[1]], 14, PALETTE.muted))
		var reward := "Ödül: %s coin" % _fmt(int(q.get("reward_coins", 0)))
		if int(q.get("reward_gems", 0)) > 0:
			reward += " + %d elmas" % int(q.reward_gems)
		c.add_child(_label(reward, 14, PALETTE.green_deep))
	c.add_child(_label("Tamamlanan görev: %d / %d" % [Game.quest_index, Game.quests.size()], 13, PALETTE.muted))

	c.add_child(_spacer_y(10))
	c.add_child(_label("Başarımlar — %d / %d açıldı" % [Game.unlocked_achievements.size(), Game.achievements.size()], 16, PALETTE.wood_dark))
	for a: Dictionary in Game.achievements:
		var unlocked: bool = Game.unlocked_achievements.has(String(a.id))
		var p: Array = Game.quest_progress(a)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		c.add_child(row)
		var mark := _label("✓" if unlocked else "•", 15, PALETTE.green_deep if unlocked else PALETTE.muted)
		mark.custom_minimum_size = Vector2(18, 0)
		row.add_child(mark)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		col.add_child(_label(String(a.name), 14, PALETTE.text if unlocked else PALETTE.muted))
		if not unlocked:
			col.add_child(_label("%s — %d / %d" % [String(a.desc), mini(p[0], p[1]), p[1]], 12, PALETTE.muted))


# --- Geri bildirim -----------------------------------------------------

func _on_quest_completed(q: Dictionary) -> void:
	_play("quest")
	var msg := "Görev tamam: %s — +%s coin" % [q.name, _fmt(int(q.get("reward_coins", 0)))]
	if int(q.get("reward_gems", 0)) > 0:
		msg += ", +%d elmas" % int(q.reward_gems)
	_show_toast(msg)


func _on_achievement_unlocked(a: Dictionary) -> void:
	_play("quest")
	var msg := "Başarım açıldı: %s — +%s coin" % [a.name, _fmt(int(a.get("reward_coins", 0)))]
	if int(a.get("reward_gems", 0)) > 0:
		msg += ", +%d elmas" % int(a.reward_gems)
	_show_toast(msg)


func _show_toast(msg: String) -> void:
	toast_label.text = msg
	toast_panel.visible = true
	_toast_timer = 3.0


func _show_offline_popup(amount: int, renew_count: int = 0, renew_spent: int = 0) -> void:
	var text := ""
	if amount > 0:
		text += "Sen yokken otelin çalıştı ve %s coin birikti.\nKasadan toplamayı unutma!" % _fmt(amount)
	if renew_count > 0:
		if not text.is_empty():
			text += "\n\n"
		text += "Vardiyan bitince otel boş durmadı: %d kez otomatik yenilendi (personel maliyeti %s coin)." % [renew_count, _fmt(renew_spent)]
	_show_simple_modal("Hoş geldin!", text, "Harika", func(): pass)


## Uygulama açılışında (bugün henüz alınmadıysa) otomatik gösterilen günlük
## ödül popup'ı. on_closed, popup ne şekilde kapanırsa kapansın (Al ya da
## dışına tıklama/ESC) çağrılır — böylece "Hoş geldin" popup'ı üst üste
## binmeden sırayla açılır.
func _show_daily_reward_popup(on_closed: Callable = Callable()) -> void:
	var streak: int = Game.daily_next_streak()
	var cycle: Array = Game.eco.get("daily_rewards", [])
	if cycle.is_empty():
		if on_closed.is_valid():
			on_closed.call()
		return
	var reward: Dictionary = cycle[(streak - 1) % cycle.size()]
	var reward_text := "%s coin" % _fmt(int(reward.get("coins", 0)))
	if int(reward.get("gems", 0)) > 0:
		reward_text += " + %d elmas" % int(reward.gems)
	_show_simple_modal("Günlük Ödül", "%d. gün serisi!\nÖdülün: %s" % [streak, reward_text], "Al",
		func():
			var granted := Game.claim_daily_reward()
			if not granted.is_empty():
				_play("quest")
				_show_toast("Günlük ödül alındı — gün %d serisi!" % Game.daily_streak)
			if on_closed.is_valid():
				on_closed.call(),
		on_closed)


func _fmt_hms(game_hours: float) -> String:
	var total := int(game_hours * 3600.0)
	return "%02d:%02d:%02d" % [total / 3600, (total % 3600) / 60, total % 60]


func _fmt(n: int) -> String:
	var s := str(n)
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "." + out
	return out
