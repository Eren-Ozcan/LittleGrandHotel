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

## Kullanıcı geri bildirimi: "çoğu UI butonu ve yazısı gereksiz küçük" —
## tüm _label/_button metinleri bu çarpanla büyütülür (bkz. _label, _button).
## İlk 1.15 denemesi sonrası "hâlâ küçük" geri bildirimiyle 1.3'e çıkarıldı.
const UI_TEXT_SCALE := 1.3

## Misafir oda tipine göre ayrı sanat havuzları: oyuncu daha pahalı oda
## Misafirler/sokak yürüyüşçüleri için karakter havuzu (referans sayfadaki
## 5 temel + 4 ekstra varyant) — tek tip 3'lü rotasyon yerine daha çeşitli.
const GUEST_TYPES := ["a", "b", "c", "d_elder", "e_couple", "f_business", "g_kid"]

## Açılış tutorial'ı: yalnızca yepyeni bir kayıtta (Game.tutorial_seen == false)
## sırayla gösterilen basit popup dizisi (bkz. _maybe_show_tutorial).
const TUTORIAL_STEPS := [
	{"title": "Welcome!", "text": "Welcome to Little Grand Hotel! You'll turn one small hotel into a grand empire, step by step. Let's take a quick look.", "btn": "Next"},
	{"title": "1. Start a Shift", "text": "Tap the clock icon in the bottom bar to start a shift — the hotel only runs, and only earns, during a shift.", "btn": "Next"},
	{"title": "2. Welcome Your Guests", "text": "Once a shift starts, guests come through the door and ride the elevator to their rooms. As rooms fill up, income starts building.", "btn": "Next"},
	{"title": "3. Collect From the Till", "text": "Tap the coin counter at the top to collect what you have earned. Don't forget — earnings sit in the till until the shift ends.", "btn": "Next"},
	{"title": "4. Decorate the Rooms", "text": "Tap a room and buy furnishings — as Style Points rise the room moves up a tier and your hotel gains stars.", "btn": "Next"},
	{"title": "5. Follow the Quests", "text": "The quest icon in the bottom bar shows your active quest — each one pays out coins and gems. Now open your doors!", "btn": "Start!"},
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
## Zoom +/- butonlarının tek bir dokunuşta uyguladığı adım.
const ZOOM_STEP := 0.15
const PAN_DRAG_THRESHOLD := 6.0

## Kaç oda/geliştirme satın alımında bir geçiş reklamı denenecek. Düşük
## tutulmadı: satın alma bu oyunun ana döngüsü, sık reklam doğrudan
## oynanışı böler. Ads ayrıca kendi soğuma süresini uygular.
const UPGRADE_AD_EVERY := 12

## Haftalık dekorasyon teması: sunucusuz, Game.current_week_index()'e göre
## deterministik seçilir — çatı tabelasını hafta boyunca tek renkte boyar.
const WEEKLY_THEMES := [
	{ "name": "Classic Red", "accent": Color("a83e35") },
	{ "name": "Summer Breeze", "accent": Color("1f8a8c") },
	{ "name": "Golden Age", "accent": Color("b8860b") },
	{ "name": "Lavender Break", "accent": Color("6a4c93") },
	{ "name": "Forest Breath", "accent": Color("2f7a4f") },
	{ "name": "Coral Sunset", "accent": Color("c9622a") },
	{ "name": "Winter Tale", "accent": Color("2f6fa8") },
]

## Elmas paketleri (gems "+" butonu → _build_gems_popup). Ürün ID'leri
## Play Console'da yönetilen ürün olarak (bu kez tüketilebilir/consumable
## türünde) oluşturulmalı — bkz. docs/store/in-app-products.md.
## price alanı YEDEK etikettir — gerçek fiyat IAP.price_for() ile mağazadan
## gelir ve oyuncunun ülkesine/para birimine göre değişir. Yedek yalnızca
## mağazaya ulaşılamadığında görünür.
const GEM_PACKS := [
	{ "product": "gems_small", "gems": 100, "price": "$1.99" },
	{ "product": "gems_medium", "gems": 350, "price": "$4.99" },
	{ "product": "gems_large", "gems": 1200, "price": "$14.99" },
]

var coins_label: Label
var gems_label: Label
var star_icons: Array = []
var level_label: Label
var xp_bar: ProgressBar
var shift_label: Label
var shift_bar_label: Label
var collect_button: Button
## Topla butonu birikim varken hafifçe nabız gibi büyüyüp küçülür (dikkat
## çekmek için) — bkz. _start_collect_pulse/_stop_collect_pulse.
var _collect_pulse_on := false
var _collect_tween: Tween
var street_node: Control
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
## _waiting_guest_icons ile aynı sırada tutulan misafir SVG tipleri (ör.
## "1", "3") — kapıdan giren misafirin görsel kimliği, asansöre binene kadar
## bu sayede korunur (bkz. _spawn_lobby_walker, eskiden burada YENİDEN
## rastgele seçiliyordu, dışarıdaki ve lobideki misafir farklı görünüyordu).
var _queued_guest_types: Array = []
## Kapı açılınca _queued_guest_types'tan aktarılan tipler (_boarding'e denk).
var _boarding_types: Array = []
## Game.rooms sırasındaki misafir-odası sırasına (guest_order) göre teslim
## edilmiş misafirlerin tipi — oda görselinin, o odaya GERÇEKTEN çıkan
## misafirle aynı tipte gösterilmesini sağlar (kullanıcı şikâyeti: "aşağıdan
## giren müşteri tipi ile odaya çıkan müşteri tipi aynı değil").
var _delivered_guest_types: Array = []
## Bir önceki karede görülen Game.stat_shifts değeri — bu değiştiğinde yeni
## bir vardiya başlamış demektir (elle veya otomatik yenilenerek). Otomatik
## yenilenmede shift_active() hiç false olmadığından, aşağıdaki "vardiya
## kapalı" sıfırlaması hiç tetiklenmiyor ve önceki vardiyadan kalan
## _arrived_guests vb. sayaçlar yeni vardiyaya taşınıp odalar kimse
## gelmeden dolu görünüyordu ("3 misafir geldi ama 6 oda doldu" şikâyeti).
var _last_stat_shifts := -1
## Oda/geliştirme satın alımlarını sayar; her _UPGRADE_AD_EVERY satın alımda
## bir düşük-sıklıklı geçiş reklamı denenir (bkz. _maybe_show_upgrade_ad) —
## oyuncu ilerledikçe reklam sıklığı da hafifçe artmış olur, ama asla bir
## satın alımın ORTASINDA değil, satın alım TAMAMLANDIKTAN sonra.
var _upgrade_ad_counter := 0
## Bir önceki karede vardiya açık mıydı — açıktan kapalıya geçiş "vardiya
## bitti" demektir ve reklam için doğal bir moladır (oyuncu zaten toplayıp
## duraklıyor). Otomatik yenilemede bu geçiş hiç yaşanmaz (bkz.
## _last_stat_shifts açıklaması), o durumda tetiklenmez.
var _shift_was_active := false
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
var roof_theme_label: Label
## Otel adı artık üst bardaki sabit panelde değil, lobi duvarındaki boş
## çerçevede (lobby.png) asılı bir tabela gibi gösteriliyor — bkz. _rebuild_hotel.
var lobby_name_label: Label
const HOTEL_NAME_MAX_LEN := 16
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
var popup_scroll: ScrollContainer
var popup_builder: Callable = Callable()

var selected_room := -1
## Taşıma modunda seçili odanın kararlı kimliği ("" = taşıma modu kapalı).
var move_from := ""

## Odayı basılı tutup sürükleyerek taşıma (kullanıcı isteği: "Move" butonuyla
## iki-dokunuşlu seçim yerine gerçek sürükle-bırak). "Move" butonu da (bkz.
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

## Açılış yükleme ekranı: her başlatmada oyunun ÜSTÜNDE (en son eklenen
## child, dolayısıyla en üstte) tam ekran kaplar, sabit bir süre sonra
## kendiliğinden kapanıp kaybolur (bkz. _finish_loading_screen — CTA yok).
## Tutorial/günlük ödül/çevrimdışı popup zinciri (bkz. _maybe_show_tutorial)
## artık _ready()'de değil, bu ekran kapandıktan SONRA tetiklenir — aksi
## halde ilk açılışta tutorial popup'ı yükleme ekranının ARKASINDA sessizce
## açılıp kullanıcı hiç göremezdi.
var start_screen: Control
var _start_growth_tween: Tween

## Bulut çakışması seçici açık mı — modal iki yoldan tetiklenebilir (yükleme
## ekranı kapanışı ve geç gelen conflict_detected sinyali), üst üste iki kez
## açılmasın.
var _cloud_conflict_open := false


func _notification(what: int) -> void:
	# Android geri tuşu: proje ayarında quit_on_go_back kapatıldı, aksi halde
	# bir popup açıkken bile geri tuşu beklenmedik şekilde uygulamayı anında
	# kapatırdı. Popup açıksa yalnızca onu kapat, değilse normal çıkışı yap.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if overlay != null and overlay.visible:
			_close_popup()
		else:
			get_tree().quit()
	# Uygulama arka plandan öne gelince (ör. kullanıcı başka bir uygulamadan
	# döndü). Burada GEÇİŞ reklamı gösterilmez: AdMob uygulama açılışında ve
	# öne gelişinde interstitial'ı açıkça yasaklıyor, bu senaryonun formatı
	# App Open (bkz. Ads.show_app_open).
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_try_app_open_ad()


## Geçiş reklamı için "doğal mola" kapısı. Bir popup açıkken asla göstermez —
## oyuncu o an bir eylemin (satın alma listesi, vardiya seçimi, ayarlar)
## ortasındadır. Sıklık sınırını Ads kendi soğuma süresiyle uyguladığı için
## burada tekrarlanmaz; reklamsız sürüm kararı da tek yerde kalsın diye
## show_if olarak geçilir.
func _try_break_interstitial() -> void:
	if overlay != null and overlay.visible:
		return
	Ads.show_interstitial(not Game.remove_ads)


## Uygulamaya dönüşte App Open reklamı. Geçiş reklamıyla aynı popup kuralına
## ve aynı (kalıcı) soğuma sayacına tabidir; oyuncu bir modalin ortasında
## uygulamadan çıkıp döndüyse ekranına reklam basılmaz.
func _try_app_open_ad() -> void:
	if overlay != null and overlay.visible:
		return
	Ads.show_app_open(not Game.remove_ads)


## Bir oda/geliştirme satın alımı TAMAMLANDIKTAN sonra çağrılır.
## Eşiğe gelindiğinde bir popup açıksa sayaç sıfırlanmaz: reklam kaybolmaz,
## popup'sız ilk satın alımda gösterilir — böylece "satın alma listesinin
## ortasında reklam" durumu hiç oluşmaz.
func _maybe_show_upgrade_ad() -> void:
	_upgrade_ad_counter += 1
	if _upgrade_ad_counter < UPGRADE_AD_EVERY:
		return
	if overlay != null and overlay.visible:
		return
	_upgrade_ad_counter = 0
	Ads.show_interstitial(not Game.remove_ads)


func _ready() -> void:
	_build_ui()
	_init_sfx()
	# Uygulama, süregelen bir vardiyanın ortasında açıldıysa misafirler
	# çoktan yerleşmiş sayılır (gelir zaten akıyor) — odalar boş görünüp
	# yeniden dolmaya başlamasın. Taze vardiyada 0'dan başlar (asansör
	# teslim ettikçe artar, bkz. _deliver_guests / _make_room_button).
	if Game.shift_active():
		_arrived_guests = _guest_room_count()
		for i in _arrived_guests:
			_delivered_guest_types.append(GUEST_TYPES[i % GUEST_TYPES.size()])
	_last_stat_shifts = Game.stat_shifts
	# Açılışta zaten süren bir vardiya varsa bunu "yeni biten vardiya" sanıp
	# ilk karede reklam açmayalım.
	_shift_was_active = Game.shift_active()
	Game.state_changed.connect(_refresh)
	Game.quest_completed.connect(_on_quest_completed)
	Game.achievement_unlocked.connect(_on_achievement_unlocked)
	IAP.purchase_result.connect(_on_purchase_restored)
	# Mağaza fiyatları bağlantı kurulduktan sonra asenkron geliyor; Elmas popup'ı
	# o sırada açıksa yedek etiketlerle çizilmiş olur, gelince tazelenir.
	IAP.prices_updated.connect(_rebuild_popup)
	# Bulut senkronu ağa bağlı olduğu için ne zaman biteceği belli değil:
	# açılış zinciri onu BEKLEMEZ (kötü ağda oyun kilitlenirdi), çakışma
	# geç gelirse sinyalle yakalanır — bkz. _on_cloud_conflict.
	CloudSave.conflict_detected.connect(_on_cloud_conflict)
	CloudSave.sync_finished.connect(func(result: String):
		if result == CloudPayload.RESULT_RESTORE:
			_refresh()
			_show_toast("Cloud save restored"))
	Ads.rewarded_ad_result.connect(func(success: bool):
		if not success:
			_show_toast("No ad is ready right now, try again shortly."))
	Game.leveled_up.connect(func(lv):
		_play("level")
		_show_toast("Level up! Level %d (+%s)" % [lv, _count(int(Game.eco.levelup_gems), "gem")]))
	_refresh()
	# Tutorial/günlük ödül/çevrimdışı zinciri artık yükleme ekranı kendiliğinden
	# kapanınca başlar (bkz. _finish_loading_screen) — arkasında görünmez
	# şekilde açılmasını önler.


## Bulut senkronu yükleme ekranı kapandıktan SONRA sonuçlanırsa (yavaş ağ):
## açılış zinciri çakışmayı beklemeden ilerlemiştir, seçiciyi burada açarız.
## Yükleme ekranı hâlâ duruyorsa hiçbir şey yapma — _finish_loading_screen
## zaten aynı modalı zincirin başında gösterecek.
func _on_cloud_conflict() -> void:
	if start_screen != null:
		return
	_show_cloud_conflict_modal()


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
		_zoom = _default_zoom()
		_clamp_pan()
		_apply_canvas_transform()
	_update_live_labels()
	_update_walker(delta)
	_update_room_drag()
	_update_elevator(delta)
	_update_pedestrians(delta)
	# Vardiya bitti: oyuncu zaten duraklıyor, reklam için doğal bir mola.
	var shift_now := Game.shift_active()
	if _shift_was_active and not shift_now:
		_try_break_interstitial()
	_shift_was_active = shift_now
	if _toast_timer > 0.0:
		_toast_timer -= delta
		if _toast_timer <= 0.0:
			toast_panel.visible = false


## Asansör: kapı animasyonu (kapalı→aralık→açık→aralık→kapalı) + kaldırım
## kuyruğu sayacı. Bkz. üstteki değişken açıklaması için tasarım gerekçesi.
func _update_elevator(delta: float) -> void:
	if elevator_tex == null or not is_instance_valid(elevator_tex):
		return
	if Game.stat_shifts != _last_stat_shifts:
		_last_stat_shifts = Game.stat_shifts
		# Yeni bir vardiya başladı — otomatik yenilenmede shift_active() hiç
		# false olmadığı için aşağıdaki "vardiya kapalı" dalı hiç çalışmaz;
		# sıfırlamayı burada, vardiya sayacındaki değişime bakarak yapıyoruz.
		_queue_count = 0
		_boarding = 0
		_inbound = 0
		_arrived_guests = 0
		_queued_guest_types.clear()
		_boarding_types.clear()
		_delivered_guest_types.clear()
		for gicon in _waiting_guest_icons:
			if is_instance_valid(gicon):
				gicon.queue_free()
		_waiting_guest_icons.clear()
		_arrival_timer = 0.0
		_rebuild_hotel()
	if not Game.shift_active():
		if _queue_count != 0 or _elevator_state != "closed" or _arrived_guests != 0:
			_queue_count = 0
			_boarding = 0
			_inbound = 0
			_arrived_guests = 0
			_queued_guest_types.clear()
			_boarding_types.clear()
			_delivered_guest_types.clear()
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
				_boarding_types = _queued_guest_types.duplicate()
				_queued_guest_types.clear()
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
				var delivered_types := _boarding_types
				_boarding = 0
				_boarding_types = []
				if delivered > 0:
					_deliver_guests(delivered, delivered_types)


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
func _deliver_guests(count: int, types: Array = []) -> void:
	get_tree().create_timer(1.0).timeout.connect(func():
		_arrived_guests += count
		for t in types:
			_delivered_guest_types.append(t)
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
	_show_toast("You turned the runaway guest back to the door! +%d coins" % bonus)
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

	# --- Üst bar (krem panel) — tıklanınca Profil açılır (kullanıcı isteği:
	# "en üstte level para yazan yere tıklayınca profile gitmeli"). Elmas +
	# butonu kendi STOP filtresiyle bu tıklamayı yutar, satın alma popup'ını
	# açar (bkz. _build_gems_popup).
	var top := _panel(PALETTE.cream, PALETTE.facade_line)
	top.mouse_filter = Control.MOUSE_FILTER_STOP
	top.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	top.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_open_popup("Profile", _build_profile_popup))
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
	var gem_add_b := _button("+", 16, PALETTE.green_deep, PALETTE.cream_text)
	gem_add_b.custom_minimum_size = Vector2(32, 32)
	gem_add_b.pressed.connect(func(): _open_popup("Buy Gems", _build_gems_popup))
	row1.add_child(gem_add_b)
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
	xp_bar.custom_minimum_size = Vector2(0, 16)
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

	collect_button = _button("", 16, PALETTE.gold, PALETTE.text)
	collect_button.custom_minimum_size = Vector2(0, 52)
	_button_icon(collect_button, "res://assets/ui/coin.svg")
	collect_button.add_theme_constant_override("icon_max_width", 22)
	# "Daha güzel bir topla butonu" isteği: normal/hover durumlarına kabartma
	# (koyu alt kenar) + gölge eklendi, disabled'a dokunulmadı (soluk kalsın).
	for state in ["normal", "hover", "pressed"]:
		var sb: StyleBoxFlat = collect_button.get_theme_stylebox(state)
		sb.border_width_bottom = 6
		sb.border_color = PALETTE.gold.darkened(0.4)
		sb.shadow_color = Color(0.1, 0.06, 0.02, 0.25)
		sb.shadow_size = 6
		sb.shadow_offset = Vector2(0, 3)
	collect_button.pressed.connect(_on_collect)
	root.add_child(collect_button)

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
	roof_theme_label = _label("", 12, PALETTE.cream_text)
	roof_theme_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	roof_panel.add_child(roof_theme_label)

	var zoom_row := HBoxContainer.new()
	zoom_row.add_theme_constant_override("separation", 6)
	root.add_child(zoom_row)
	build_mode_button = _button("🔨 Build Mode", 13, PALETTE.wood, PALETTE.cream_text)
	build_mode_button.custom_minimum_size = Vector2(0, 48)
	build_mode_button.toggle_mode = true
	build_mode_button.toggled.connect(func(on: bool):
		build_mode = on
		build_mode_button.text = "🔨 Build Mode: On" if on else "🔨 Build Mode"
		_rebuild_hotel())
	zoom_row.add_child(build_mode_button)
	var zoom_row_spacer := Control.new()
	zoom_row_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	zoom_row.add_child(zoom_row_spacer)
	var zoom_out_b := _button("−", 18, PALETTE.wood, PALETTE.cream_text)
	zoom_out_b.custom_minimum_size = Vector2(52, 48)
	zoom_out_b.pressed.connect(func(): _zoom_by(-ZOOM_STEP, zoom_viewport.size / 2.0))
	zoom_row.add_child(zoom_out_b)
	var zoom_reset_b := _button("⟳", 16, PALETTE.wood, PALETTE.cream_text)
	zoom_reset_b.custom_minimum_size = Vector2(52, 48)
	zoom_reset_b.pressed.connect(func():
		_zoom = _default_zoom()
		_canvas_pan = Vector2.ZERO
		_clamp_pan()
		_apply_canvas_transform())
	zoom_row.add_child(zoom_reset_b)
	var zoom_in_b := _button("+", 18, PALETTE.wood, PALETTE.cream_text)
	zoom_in_b.custom_minimum_size = Vector2(52, 48)
	zoom_in_b.pressed.connect(func(): _zoom_by(ZOOM_STEP, zoom_viewport.size / 2.0))
	zoom_row.add_child(zoom_in_b)

	# İnşa Modu mağaza rafı: yalnızca build_mode açıkken görünür (bkz.
	# _rebuild_hotel). Oda kartları buradan tuvale sürüklenir — tıklayınca
	# açılan liste yerine Hotel City'deki gibi "mağazadan seç, sürükle" akışı.
	build_shop_panel = VBoxContainer.new()
	build_shop_panel.visible = false
	build_shop_panel.add_theme_constant_override("separation", 2)
	root.add_child(build_shop_panel)
	build_shop_panel.add_child(_label("Room Shop — drag and drop onto the building", 12, PALETTE.wood_dark))
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
			_show_toast("New floor unlocked!")
			_maybe_show_upgrade_ad())
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

	var shift_b := _bar_button("res://assets/ui/icon_clock.svg", "Shift")
	shift_b.pressed.connect(func(): _open_popup("Shift", _build_shift_popup))
	bottom.add_child(shift_b)
	shift_bar_label = shift_b.get_meta("label")

	# "Shop" artık popup açmıyor — İnşa Modu'nu açıp mağaza rafını gösterir
	# (oda ekleme tek yol: rafından sürükleyip binaya bırakmak).
	var shop_b := _bar_button("res://assets/ui/icon_shop.svg", "Shop")
	shop_b.pressed.connect(func():
		build_mode_button.button_pressed = true
		_show_toast("Build Mode is on — drag a room from the shelf onto the building"))
	bottom.add_child(shop_b)

	# İstatistik ikonu kaldırıldı — kullanıcı isteği: alt bardan Profil'e
	# taşındı (bkz. _build_profile_popup, üst bar tıklamasıyla açılır).
	for def in [
		["res://assets/ui/icon_gear.svg", "Staff", _build_staff_popup],
		["res://assets/ui/icon_quest.svg", "Quests", _build_quests_popup],
		["res://assets/ui/icon_gear.svg", "Settings", _build_settings_popup],
	]:
		var b := _bar_button(def[0], def[1])
		var builder: Callable = def[2]
		var title: String = def[1]
		b.pressed.connect(func(): _open_popup(title, builder))
		bottom.add_child(b)

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
	var close_b := _button("Close", 15, PALETTE.wood, PALETTE.cream_text)
	close_b.pressed.connect(_close_popup)
	head.add_child(close_b)
	popup_scroll = ScrollContainer.new()
	popup_scroll.custom_minimum_size = Vector2(0, 640)
	pv.add_child(popup_scroll)
	popup_content = VBoxContainer.new()
	popup_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	popup_content.add_theme_constant_override("separation", 8)
	popup_scroll.add_child(popup_content)

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

	_build_start_screen()


## Açılış yükleme ekranı: sky gradyanı + logo rozeti + otel adı + küçük→
## büyük otel büyüme animasyonu. Etkileşim/CTA YOK — sabit bir süre
## gösterilip otomatik olarak oyuna geçer (kullanıcı isteği: "oyna butonu
## olmayacak, ilk başta gösterilen yükleme ekranı"; sade, yalnızca görsel +
## oyun adı, ekstra öğe (ilerleme çubuğu/ipucu metni vb.) istenmedi).
func _build_start_screen() -> void:
	start_screen = Control.new()
	start_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	start_screen.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(start_screen)

	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	grad.colors = PackedColorArray([PALETTE.sky_top, PALETTE.sky_bottom])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	var bg := TextureRect.new()
	bg.texture = gt
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	start_screen.add_child(bg)

	# Bulutlar bilerek yalnızca ÜST üçte birde: logo/başlık/buton sütunu
	# ekranın ortasında yaşıyor, bulutlar o bölgeye asla taşmıyor (çakışma
	# yok — "görsellerin üst üste gelmemesi" isteği).
	for cdef in [[46, 96, 150], [430, 150, 120], [520, 60, 90]]:
		var cloud := TextureRect.new()
		cloud.texture = _tex("res://assets/ui/cloud.svg")
		cloud.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		cloud.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		cloud.position = Vector2(cdef[0], cdef[1])
		cloud.custom_minimum_size = Vector2(cdef[2], cdef[2] * 0.46)
		cloud.size = cloud.custom_minimum_size
		cloud.mouse_filter = Control.MOUSE_FILTER_IGNORE
		start_screen.add_child(cloud)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	start_screen.add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(col)

	var logo_wrap := CenterContainer.new()
	logo_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(logo_wrap)
	var logo := TextureRect.new()
	logo.texture = _tex("res://icon.svg")
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(176, 176)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo_wrap.add_child(logo)

	var title := _label(Game.hotel_name.to_upper(), 32, PALETTE.wood_dark)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size = Vector2(560, 0)
	title.add_theme_color_override("font_outline_color", PALETTE.cream)
	title.add_theme_constant_override("outline_size", 8)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(title)

	# Alt: sürüm etiketi — köşede, sade, merkez sütundan ayrı çapa.
	var version_label := _label("v1.0", 11, PALETTE.muted)
	version_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	version_label.offset_top = -34
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	version_label.modulate.a = 0.7
	start_screen.add_child(version_label)

	# CTA'nın altındaki boş alanda: "küçük otelden büyük bir imparatorluğa"
	# vaadini özetleyen, sonsuz döngülü küçük→orta→büyük otel büyüme
	# animasyonu (Google Flow'da üretilip oyunun kendi düz-vektör/kalın
	# çizgili stiline uydurulmuş 3 aşama). Kendi sabit çapasında — merkez
	# sütunun akışı DIŞINDA, buton/sürüm etiketiyle asla çakışmıyor.
	var growth_wrap := Control.new()
	growth_wrap.anchor_left = 0.5
	growth_wrap.anchor_right = 0.5
	growth_wrap.anchor_top = 0.735
	growth_wrap.anchor_bottom = 0.735
	growth_wrap.offset_left = -100
	growth_wrap.offset_right = 100
	growth_wrap.offset_top = 0
	growth_wrap.offset_bottom = 195
	growth_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	start_screen.add_child(growth_wrap)

	var growth_tex := TextureRect.new()
	growth_tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	growth_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	growth_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	growth_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# En büyük (grand hotel, scale 1.15) aşamada bile üst kenar CTA
	# butonuyla çakışmasın diye taban (pivot) sabit, büyüme yukarı doğru.
	growth_tex.pivot_offset = Vector2(100, 195)
	growth_wrap.add_child(growth_tex)

	var growth_stages := [
		_tex("res://assets/ui/menu_hotel_stage1.png"),
		_tex("res://assets/ui/menu_hotel_stage2.png"),
		_tex("res://assets/ui/menu_hotel_stage3.png"),
	]
	growth_tex.texture = growth_stages[0]
	growth_tex.scale = Vector2(0.8, 0.8)
	growth_tex.modulate.a = 0.0

	_start_growth_tween = growth_tex.create_tween()
	_start_growth_tween.set_loops()
	_start_growth_tween.tween_property(growth_tex, "modulate:a", 1.0, 0.5)
	_start_growth_tween.tween_interval(1.3)
	_start_growth_tween.tween_callback(func(): growth_tex.texture = growth_stages[1])
	_start_growth_tween.tween_property(growth_tex, "scale", Vector2(0.95, 0.95), 0.4) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_start_growth_tween.tween_interval(1.3)
	_start_growth_tween.tween_callback(func(): growth_tex.texture = growth_stages[2])
	_start_growth_tween.tween_property(growth_tex, "scale", Vector2(1.15, 1.15), 0.45) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_start_growth_tween.tween_interval(1.8)
	_start_growth_tween.tween_property(growth_tex, "modulate:a", 0.0, 0.5)
	_start_growth_tween.tween_callback(func():
		growth_tex.texture = growth_stages[0]
		growth_tex.scale = Vector2(0.8, 0.8))
	_start_growth_tween.tween_interval(0.3)

	# CTA yok: yükleme ekranı büyüme animasyonu en az bir kez "büyük otel"
	# aşamasına ulaşacak kadar (bkz. yukarıdaki zamanlama, ~4s) gösterilip
	# kendiliğinden oyuna geçer.
	get_tree().create_timer(4.2).timeout.connect(_finish_loading_screen)


func _finish_loading_screen() -> void:
	if not start_screen:
		return
	if _start_growth_tween and is_instance_valid(_start_growth_tween):
		_start_growth_tween.kill()
	start_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := create_tween()
	t.tween_property(start_screen, "modulate:a", 0.0, 0.28).set_trans(Tween.TRANS_SINE)
	t.tween_callback(func():
		start_screen.queue_free()
		start_screen = null
		# Bulut çakışması varsa seçim EKRANI ÖNCE gelir: tutorial/günlük ödül
		# zinciri, hangi kaydın devam edeceği belli olmadan oynanmamalı.
		# Çakışma yoksa modal hiç açılmaz ve zincir olduğu gibi sürer.
		_show_cloud_conflict_modal(_maybe_show_tutorial))


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
	l.add_theme_font_size_override("font_size", roundi(size * UI_TEXT_SCALE))
	l.add_theme_color_override("font_color", color)
	return l


## _label()'ın sarmalı hâli — üst bardaki dar HBoxContainer hücrelerinde
## (coins/level gibi) autowrap varsayılan olsaydı metin dikey harf harf
## dizilip bozulurdu (autowrap min-width'i ~0'a indiriyor); bu yüzden ortak
## varsayılan yerine yalnızca uzun açıklama metinlerinde bilinçli kullanılır
## (Ayarlar/Vardiya/Profil popup'ları — kullanıcı isteği: "görünümü bozuk").
func _label_wrap(text: String, size: int, color: Color) -> Label:
	var l := _label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	b.custom_minimum_size = Vector2(0, 84)
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
		wrap.add_child(_icon(icon_path, 38))
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
	# Not: autowrap burada KASITLI OLARAK yok — bir HBoxContainer satırında
	# (ör. zoom +/- butonları) sarma açık bir buton, genişliği ~0'a sarkıtıp
	# yüksekliği yüzlerce piksele şişiriyor (min-size hesaplama tuzağı).
	# Uzun buton metinleri için elle "\n" ile satır kır (bkz. vardiya/otomatik
	# yenileme butonları) — bu her zaman güvenli ve öngörülebilir.
	b.add_theme_font_size_override("font_size", roundi(size * UI_TEXT_SCALE))
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
	if lobby_name_label:
		lobby_name_label.text = Game.hotel_name.to_upper()
	coins_label.text = _fmt(Game.coins)
	gems_label.text = str(Game.gems)
	var stars := Game.star_rating()
	for i in 5:
		star_icons[i].texture = _tex("res://assets/ui/star_full.svg" if i < stars else "res://assets/ui/star_empty.svg")
	var lv := Game.level()
	level_label.text = "Level %d" % lv
	var cur_xp := Game.xp - Game.xp_for_level(lv)
	var need := Game.xp_for_level(lv + 1) - Game.xp_for_level(lv)
	xp_bar.max_value = need
	xp_bar.value = cur_xp
	if Game.shift_active():
		shift_label.text = "%s left in the shift · %.0f coins/hour" % [
			_fmt_hms(Game.shift_remaining_game_hours()), Game.hourly_income()]
		shift_bar_label.text = _fmt_hms(Game.shift_remaining_game_hours())
		shift_bar_label.add_theme_color_override("font_color", PALETTE.gold_soft)
	else:
		shift_label.text = "No shift running — the hotel isn't earning."
		shift_bar_label.text = "Shift"
		shift_bar_label.add_theme_color_override("font_color", PALETTE.cream_text)
	collect_button.text = "COLLECT — %s" % _fmt(int(Game.pending_income))
	var has_income := int(Game.pending_income) > 0
	collect_button.disabled = not has_income
	if has_income and not _collect_pulse_on:
		_collect_pulse_on = true
		_start_collect_pulse()
	elif not has_income and _collect_pulse_on:
		_collect_pulse_on = false
		_stop_collect_pulse()


## Birikim varken topla butonunu hafifçe büyütüp küçültüp durur ("numaraların
## patlaması" gibi hissettiren dikkat çekici mikro-etkileşim — bkz. 2026 mobil
## oyun UI araştırması, PR açıklaması).
func _start_collect_pulse() -> void:
	if _collect_tween and is_instance_valid(_collect_tween):
		_collect_tween.kill()
	collect_button.pivot_offset = collect_button.size / 2.0
	_collect_tween = collect_button.create_tween()
	_collect_tween.set_loops()
	_collect_tween.tween_property(collect_button, "scale", Vector2(1.045, 1.045), 0.55) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_collect_tween.tween_property(collect_button, "scale", Vector2(1.0, 1.0), 0.55) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_collect_pulse() -> void:
	if _collect_tween and is_instance_valid(_collect_tween):
		_collect_tween.kill()
	collect_button.scale = Vector2.ONE


func _current_theme() -> Dictionary:
	return WEEKLY_THEMES[Game.current_week_index() % WEEKLY_THEMES.size()]


func _rebuild_hotel() -> void:
	# Bir misafir odası satılıp kaldırıldığında Game.rooms küçülür ama
	# _arrived_guests (kümülatif "kaç misafir teslim edildi" sayacı) bundan
	# haberdar olmaz — fazlalık kalıyordu ve sonradan sıfırdan açılan yeni
	# odaya "sıra" hesaplamasında anında yapışıp, oda henüz kimse gelmeden
	# dolu görünüyordu ("yeni oda açınca anında müşteri" şikâyeti). Oda
	# listesi her değiştiğinde sayacı mevcut misafir odası sayısına sabitle.
	_arrived_guests = mini(_arrived_guests, _guest_room_count())
	if _delivered_guest_types.size() > _arrived_guests:
		_delivered_guest_types.resize(_arrived_guests)
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
	roof_theme_label.text = "Theme of the week: %s" % String(theme.name)

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

	# Otel adı tabelası: lobby.png'ye çizili boş duvar çerçevelerinden biri
	# (asansörün sağındaki) kullanıcı isteğiyle otel adının "asılı durduğu"
	# yer oldu — üst bardaki eski sabit panel kaldırıldı (bkz. HOTEL_NAME_MAX_LEN).
	# Çerçevenin lobby.png üzerindeki piksel konumu (1920×256 doku): iç
	# boşluk x≈1198–1380, y≈59–137. lobby_scene STRETCH_KEEP_ASPECT_COVERED
	# kullandığından elevator_tex ile aynı kırpma dönüşümü uygulanır
	# (frac_x=(px-192)/1536, frac_y=py/256 — bkz. elevator_tex yorumu).
	lobby_name_label = _label(Game.hotel_name.to_upper(), 8, PALETTE.wood_dark)
	lobby_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lobby_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lobby_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lobby_name_label.clip_text = true
	lobby_name_label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	lobby_name_label.mouse_filter = Control.MOUSE_FILTER_STOP
	lobby_name_label.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_show_rename_hotel_modal())
	lobby_name_label.anchor_left = 0.657
	lobby_name_label.anchor_right = 0.775
	lobby_name_label.anchor_top = 0.235
	lobby_name_label.anchor_bottom = 0.53
	lobby_scene.add_child(lobby_name_label)

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
		var street_l := _label("· · · the street is quiet — start a shift · · ·", 13, PALETTE.cream)
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
		new_floor_button.text = "Unlock a new floor — %s coins" % _fmt(Game.floor_price())
		new_floor_button.disabled = not Game.can_buy_floor()

	_room_visual_cache = next_room_cache


## Açık ama boş bir hücre: HİÇBİR görsel kutu/çerçeve göstermez (kullanıcı
## isteği: "açık olmayan odalar oluşturulmamış olmalı, arka plan gözükecek")
## — kat şeridinin (row_bg) kendi arka planı olduğu gibi görünür. Yeni oda
## yalnızca mağaza rafından sürükleyip bırakılarak eklenir (bkz.
## _make_shop_tray_card, _finish_drag; bırakma ham ekran koordinatından
## hücre bulur, herhangi bir Control'e ihtiyaç duymaz). İnşa Modu kapalıyken
## tamamen etkileşimsiz de olur; açıkken görünmez ama yine de dokunulabilir
## kalır — yalnızca "Move" modundaki hedef tıklaması için (bkz.
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
	var l := _label("Unlock block\n%s coins" % _fmt(Game.block_price(floor_i)), 11, Color("f0dfc4"))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(l)
	b.disabled = not Game.can_buy_block(floor_i)
	b.pressed.connect(func():
		if Game.buy_block(floor_i):
			_play("buy")
			_show_toast("New block unlocked!")
			_maybe_show_upgrade_ad())
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


## Varsayılan açılış/sıfırlama zoom'u: bina genişliğe tam sığacak seviyeden
## kullanıcı isteğiyle 2 zoom-in tıkı (2×ZOOM_STEP) daha yakın — "hâlâ küçük,
## haritaya biraz daha zoomlu baksın" geri bildirimi.
func _default_zoom() -> float:
	if zoom_viewport == null or zoom_viewport.size.x <= 0.0:
		return clampf(1.0 + 2.0 * ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)
	var canvas_w: float = int(Game.eco.building.grid_cols) * CELL_W
	var fit := zoom_viewport.size.x / canvas_w
	return clampf(fit + 2.0 * ZOOM_STEP, _effective_zoom_min(), ZOOM_MAX)


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
			var hint := _label("empty room", 12, PALETTE.muted)
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
			# Oda görselindeki misafir tipi, o sıraya GERÇEKTEN çıkan misafirle
			# eşleşsin diye teslim sırasına göre kaydedilen tipten okunur
			# (bkz. _delivered_guest_types) — eskiden idx'e göre bağımsız
			# seçiliyordu ve lobiden gelen misafirle hiç alakası olmuyordu.
			var gtype: String = _delivered_guest_types[guest_order] if guest_order < _delivered_guest_types.size() \
				else GUEST_TYPES[idx % GUEST_TYPES.size()]
			var guest := TextureButton.new()
			guest.texture_normal = _tex("res://assets/guests/guest_%s.svg" % gtype)
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
		plate_text = "INFESTED! %d c" % int(Game.eco.infest.clean_cost)
	elif is_dirty:
		plate_text = "DIRTY!"
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
	var l := _label("✦ Decorate!", 11, PALETTE.text)
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
			_show_toast("Move cancelled")
		else:
			move_from = ""
			_show_toast("That spot is taken — tap an empty cell to move there")
		return
	if room.dirty:
		# Buton yeniden kurulumda yok olacağı için merkezi temizlemeden önce al
		var center := btn.global_position + btn.size / 2.0
		var cost := Game.clean_cost(idx)
		if Game.clean_room(idx):
			_play("clean")
			_spawn_clean_anim(center)
			if cost > 0:
				_show_toast("Infestation cleared! (−%d coins, +2 XP)" % cost)
			else:
				_show_toast("Room cleaned (+2 XP)")
		elif cost > 0:
			_show_toast("Clearing the infestation costs %d coins!" % cost)
		return
	selected_room = idx
	if Game.room_def(room.type).category == "guest":
		_open_popup("Room Decoration", _build_room_popup)
	else:
		_open_popup("Facility", _build_facility_popup)


## Açık-ama-boş bir hücreye dokunma: yalnızca "Move" modundaysa (bkz.
## move_from, _add_manage_buttons) anlamlı — seçili odayı buraya taşır.
## Yeni oda eklemek artık tıklamayla değil, mağaza rafından sürükleyip
## bırakmakla olur (bkz. _make_shop_tray_card, _finish_drag).
func _on_empty_cell_move_tapped(floor_i: int, col: int) -> void:
	if move_from == "":
		_show_toast("Drag a card from the shop shelf to add a room")
		return
	var mid := move_from
	move_from = ""
	if Game.move_room_to(mid, floor_i, col):
		_play("buy")
		_show_toast("Room moved")
	else:
		_show_toast("The room doesn't fit here")


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
	var price_text := ("Unlocks at Lv.%d" % int(d.unlock_level)) if locked else "%s coins" % _fmt(int(d.price))
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
		return  # İnşa Modu kapalıyken, popup açıkken veya "Move" iki-dokunuşlu moddaysa karıştırma
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
		_show_toast("Can't drop that here")
		return
	if room_id != "":
		if Game.move_room_to(room_id, cell.x, cell.y):
			_play("buy")
			_show_toast("Room moved")
		else:
			_show_toast("The room doesn't fit here")
	else:
		if Game.place_room(new_type, cell.x, cell.y):
			_play("buy")
			_show_toast("%s placed!" % Game.room_def(new_type).name)
			_maybe_show_upgrade_ad()
		else:
			_show_toast("It doesn't fit here, your level is too low, or you can't afford it")


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
		_show_toast("You are out of nudges for today — try again tomorrow!")
		return
	var center := btn.global_position + btn.size / 2.0
	var bonus := Game.poke_guest()
	if bonus > 0:
		_play("collect")
		_spawn_sparkles(center)
		_show_toast("A secret inspector! +%d coins (%s left)" % [bonus, _count(Game.pokes_left(), "nudge")])
	else:
		_play("tap")
		_show_toast("The guest yawned and went back to sleep… (%s left)" % _count(Game.pokes_left(), "nudge"))


func _on_collect() -> void:
	var from := collect_button.global_position + collect_button.size / 2.0
	var got := Game.collect()
	if got > 0:
		_play("collect")
		_fly_coins(from, got)
		_show_toast("+%s coins collected" % _fmt(got))


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
	var gtype: String = GUEST_TYPES[randi() % GUEST_TYPES.size()]
	var gicon := _icon("res://assets/guests/guest_%s.svg" % gtype, 36)
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
		_spawn_lobby_walker(gtype))


## Kapıdan giren misafirin lobi içindeki yürüyüşü: giriş boşluğundan
## resepsiyona/asansöre doğru yürür. Konumu `tween_method` ile her karede
## izlenir; ELEVATOR_PROXIMITY_RADIUS içine girdiği AN (yürüyüş bitmeden,
## kapının tam önüne varır varmaz) asansör kuyruğuna (_queue_count) yazılır
## — sabit bir varış/bekleme süresi yerine gerçek konuma dayalı bir tetik.
## Misafir bu noktada solmaz; kapı gerçekten açılıp bindiğinde
## _board_waiting_guests() onu kaybettirir.
func _spawn_lobby_walker(guest_type: String = "") -> void:
	if _walker_layer == null or not is_instance_valid(_walker_layer):
		_inbound = maxi(0, _inbound - 1)
		return
	var canvas_w: float = int(Game.eco.building.grid_cols) * CELL_W
	var lobby_y := float(Game.floors) * CELL_H
	# Dışarıdaki yayanın tipi aynen devam etsin diye çağıran fonksiyon
	# tipi veriyor (bkz. _spawn_arriving_pedestrian/_guest_walk_in) — eskiden
	# burada YENİDEN rastgele seçiliyordu, dışarıdaki ve lobideki misafir
	# farklı görünüyordu ("giren müşteri tipi ile odaya çıkan aynı değil").
	if guest_type == "":
		guest_type = GUEST_TYPES[randi() % GUEST_TYPES.size()]
	var gicon := _icon("res://assets/guests/guest_%s.svg" % guest_type, 36)
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
	# "triggered" tek elemanlı bir Array'e sarılıyor: GDScript'te bir lambda
	# içinde yakalanan yerel bool/int değişkenler DEĞER olarak kopyalanıyor —
	# Tween her karede AYNI closure'ı çağırsa da mutasyon bir sonraki çağrıya
	# taşınmıyordu. Sonuç: misafir ELEVATOR_PROXIMITY_RADIUS içinde kaldığı
	# HER karede (onlarca kez) _queue_count += 1 çalışıyordu — tek bir
	# misafirin varışı düzinelerce "gelmiş" sayılıp odalar gerçek misafir
	# sayısından çok daha hızlı doluyordu ("3 müşteri geldi ama 6 oda doldu"
	# şikâyetinin asıl kaynağı). Array referans tipi olduğu için içeriği
	# çağrılar arasında gerçekten paylaşılıyor — doğru tek-seferlik kilit bu.
	var triggered := [false]
	var tw := gicon.create_tween()
	tw.tween_method(func(x: float):
		if not is_instance_valid(gicon):
			return
		gicon.position.x = x
		if not triggered[0] and absf(x - elev_x) <= ELEVATOR_PROXIMITY_RADIUS:
			triggered[0] = true
			_inbound = maxi(0, _inbound - 1)
			if Game.shift_active():
				_queue_count += 1
				_waiting_guest_icons.append(gicon)
				_queued_guest_types.append(guest_type)
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
		var gtype: String = GUEST_TYPES[i % GUEST_TYPES.size()]
		var gicon := _icon("res://assets/guests/guest_%s.svg" % gtype, 36)
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
			_spawn_lobby_walker(gtype))


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
	panel.custom_minimum_size = Vector2(500, 0)
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


## Çatı tabelasına dokununca açılır: otelin adını değiştirmeyi sağlayan
## küçük bir LineEdit'li onay/vazgeç modalı (kullanıcı isteği: "otelin adı
## değiştirilebilior mu?"). _show_simple_modal ile aynı dışına-tıkla-kapat
## deseni, yalnızca metin girişi eklendi.
func _show_rename_hotel_modal() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.2, 0.15, 0.05, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.z_index = 90
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.add_child(center)
	var panel := _panel(PALETTE.cream, PALETTE.facade_line)
	panel.custom_minimum_size = Vector2(500, 0)
	center.add_child(panel)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 14)
	panel.add_child(pv)
	pv.add_child(_label("Rename your hotel", 20, PALETTE.wood_dark))
	pv.add_child(_label("Up to %d characters, so it fits the sign in the lobby." % HOTEL_NAME_MAX_LEN, 12, PALETTE.muted))
	var field := LineEdit.new()
	field.text = Game.hotel_name
	field.max_length = HOTEL_NAME_MAX_LEN
	field.placeholder_text = "Hotel name…"
	pv.add_child(field)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	pv.add_child(row)
	var closed := false
	var do_close := func():
		if closed:
			return
		closed = true
		dim.queue_free()
	var cancel_b := _button("Cancel", 15, PALETTE.wood_dark, PALETTE.cream_text)
	cancel_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel_b.pressed.connect(do_close)
	row.add_child(cancel_b)
	var save_b := _button("Save", 15, PALETTE.green_deep, PALETTE.cream_text)
	save_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var do_save := func():
		var new_name := field.text.strip_edges()
		if not new_name.is_empty():
			Game.hotel_name = new_name.substr(0, HOTEL_NAME_MAX_LEN)
			Game.save_game()
			lobby_name_label.text = Game.hotel_name.to_upper()
		do_close.call()
	save_b.pressed.connect(do_save)
	row.add_child(save_b)
	field.text_submitted.connect(func(_t): do_save.call())
	dim.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			do_close.call())
	add_child(dim)
	_play("tap")
	field.grab_focus()
	field.select_all()


func _open_popup(title: String, builder: Callable) -> void:
	_play("tap")
	popup_title.text = title
	popup_builder = builder
	overlay.visible = true
	_rebuild_popup()
	# ScrollContainer TÜM popup'lar arasında paylaşılıyor (bkz. popup_scroll) —
	# önceki popup'ta en alta kaydırılmışsa, sıfırlamadan yeni popup da
	# scroll pozisyonunu koruyup en alttan açılmış gibi görünüyordu
	# ("bir sekmede en alta kaydırınca başka sekmeye girince en alttan
	# geliyor" şikâyeti). _rebuild_popup içeriği her state_changed'de de
	# yeniler ama AYNI popup içinde scroll'u KORUMALIYIZ — sıfırlama bu
	# yüzden yalnızca burada, yeni popup AÇILIRKEN yapılır.
	popup_scroll.scroll_vertical = 0


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
		c.add_child(_label("Shift in progress — %s left." % _fmt_hms(Game.shift_remaining_game_hours()), 16, PALETTE.text))
		c.add_child(_label("You can collect your earnings whenever you like.", 14, PALETTE.muted))
		var gem_cost := Game.skip_shift_gem_cost()
		var skip_b := _button("Finish now — %s" % _count(gem_cost, "gem"), 15, PALETTE.green_deep, PALETTE.cream_text)
		skip_b.disabled = Game.gems < gem_cost
		var hk_active := Game.housekeeping_active()
		skip_b.pressed.connect(func():
			if not hk_active and not skip_b.get_meta("armed", false):
				skip_b.set_meta("armed", true)
				skip_b.text = "No Housekeeping room — some rooms may not pay full rate.\nTap again to finish anyway"
				return
			if Game.skip_shift():
				_play("buy")
				_show_toast("Shift finished with gems — the earnings are in the till!")
				_close_popup())
		c.add_child(skip_b)
		if hk_active:
			c.add_child(_label_wrap("You have a Housekeeping room — you'll earn full rate to the end of the shift, as if guests never stopped coming.", 12, PALETTE.green_deep))
		else:
			c.add_child(_label_wrap("No Housekeeping room — rooms left dirty earn nothing for this stretch.", 12, PALETTE.muted))
		if Game.now() < Game.boost_end_unix:
			var left_min := int((Game.boost_end_unix - Game.now()) / 60.0)
			c.add_child(_label("Ad bonus active: income ×%.1f (%d min left)" % [Game.boost_mult, maxi(0, left_min)], 13, PALETTE.green_deep))
		else:
			var boost_b := _button("Watch an ad — ×2 income for 30 min", 15, PALETTE.wood_dark, PALETTE.cream_text)
			_button_icon(boost_b, "res://assets/ui/ad_video.png")
			boost_b.pressed.connect(func():
				Ads.show_rewarded(func():
					Game.start_income_boost(30.0, 2.0)
					_play("buy")
					_show_toast("Ad bonus started: ×2 income for 30 min!")
					_rebuild_popup()))
			c.add_child(boost_b)
		c.add_child(_spacer_y(8))
		_add_auto_renew_shop(c)
		return
	c.add_child(_label("Pick a length — the hourly cost is the same for all:", 14, PALETTE.muted))
	for hours: int in [1, 4, 8, 24]:
		var cost := Game.shift_cost(hours)
		var est: float = Game.hourly_income() * hours
		var b := _button("%s\ncost %s · est. income ~%s" % [_count(hours, "hour"), _fmt(cost), _fmt(int(est))], 15, PALETTE.wood, PALETTE.cream_text)
		b.disabled = Game.coins < cost
		b.pressed.connect(func():
			if Game.start_shift(hours):
				_play("shift")
				_guest_walk_in()
				_show_toast("A %d-hour shift has started!" % hours)
				_close_popup())
		c.add_child(b)
	c.add_child(_label_wrap("Note: rooms left dirty earn nothing. On a long shift a Housekeeping room is a must!", 13, PALETTE.banner_red))
	c.add_child(_spacer_y(8))
	_add_auto_renew_shop(c)


## Vardiya popup'ının iki kolundan da (aktif/pasif) çağrılır — bu satın alma
## önceden Ayarlar'daydı, kullanıcı isteğiyle Vardiya'ya taşındı.
func _add_auto_renew_shop(c: VBoxContainer) -> void:
	c.add_child(_label("Auto-renew balance: %s" % _fmt_hms(Game.auto_renew_hours_left),
		14, PALETTE.wood_dark if Game.auto_renew_hours_left > 0.0 else PALETTE.muted))
	c.add_child(_label_wrap("While you have hours banked, a finished shift renews itself for the same length if you can afford it, spending that many hours from your balance — so the hotel keeps earning while you are away.", 12, PALETTE.muted))
	for hours: int in [1, 4, 8, 24]:
		var ar_cost := Game.auto_renew_buy_cost(hours)
		var ar_b := _button("Buy %s of auto-renew\n%s coins" % [_count(hours, "hour"), _fmt(ar_cost)], 14,
			PALETTE.wood, PALETTE.cream_text)
		ar_b.disabled = Game.coins < ar_cost
		ar_b.pressed.connect(func():
			if Game.buy_auto_renew(hours):
				Game.save_game()
				_play("buy")
				_show_toast("Bought %s of auto-renew!" % _count(hours, "hour"))
				_rebuild_popup())
		c.add_child(ar_b)


func _build_staff_popup(c: VBoxContainer) -> void:
	var tier: int = Game.staff_tier
	var max_tier: int = int(Game.eco.staff_upgrade.max_tier)
	c.add_child(_label("Staff tier: %d / %d" % [tier, max_tier], 16, PALETTE.text))
	c.add_child(_label(
		"Shift cost: %%%.0f cheaper  ·  Income per hour: +%%%.0f" % [
			(1.0 - Game.staff_cost_mult()) * 100.0, (Game.staff_income_mult() - 1.0) * 100.0],
		14, PALETTE.muted))
	if tier >= max_tier:
		c.add_child(_label("Your staff is at the top tier — no upgrades left.", 14, PALETTE.green_deep))
		return
	var cost := Game.staff_upgrade_cost()
	var next_cost_mult := 1.0 - pow(1.0 - float(Game.eco.staff_upgrade.cost_reduction_pct), tier + 1)
	var next_income_mult := pow(1.0 + float(Game.eco.staff_upgrade.income_boost_pct), tier + 1) - 1.0
	var b := _button(
		"Upgrade tier — %s coins\nNext: -%%%.0f cost, +%%%.0f income" % [
			_fmt(cost), next_cost_mult * 100.0, next_income_mult * 100.0],
		15, PALETTE.wood, PALETTE.cream_text)
	b.disabled = not Game.can_buy_staff_upgrade()
	b.pressed.connect(func():
		if Game.buy_staff_upgrade():
			_play("buy")
			_show_toast("Staff quality upgraded! (Tier %d)" % Game.staff_tier)
			_maybe_show_upgrade_ad())
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
	c.add_child(_label("%s — %s · SP %d · %d items" % [
		Game.room_def(room.type).name, Game.tier_name(tier),
		Game.room_score(room), room.items.size()], 16, PALETTE.text))
	if tier < Game.eco.tier_names.size() - 1:
		var next_th := int(Game.eco.tier_thresholds[tier + 1])
		c.add_child(_label("Next tier (%s): needs SP %d" % [Game.tier_name(tier + 1), next_th], 13, PALETTE.wood_dark))

	# Hazır dekor paketleri: tek dokunuşla, tek tek almaktan ucuz
	var bundles: Array = Game.eco.get("bundles", [])
	if not bundles.is_empty():
		c.add_child(_label("Ready-made bundles — decorate in one tap:", 14, PALETTE.muted))
		for bd in bundles:
			var sp_total := 0
			for iid in bd.items:
				sp_total += int(Game.item_def(iid).sp)
			var pb := _button("%s — SP +%d — %s coins (%%%d off)" % [
				bd.name, sp_total, _fmt(Game.bundle_price(bd)), int(float(bd.discount) * 100.0)],
				14, PALETTE.green_deep, PALETTE.cream_text)
			var need_lv := Game.bundle_unlock_level(bd)
			if Game.level() < need_lv:
				pb.text = "%s — unlocks at level %d" % [bd.name, need_lv]
				pb.disabled = true
			else:
				pb.disabled = not Game.can_buy_bundle(bd)
				var bid: String = bd.id
				pb.pressed.connect(func():
					if Game.buy_bundle(selected_room, bid):
						_play("buy")
						_show_toast("%s placed!" % Game.bundle_def(bid).name)
						_maybe_show_upgrade_ad())
			c.add_child(pb)

	# Taban eşyalar: duvar kağıdı / zemin / yatak — odayla birlikte ücretsiz
	# varsayılanla gelir, burada YÜKSELTİLİR (öncekinin yerine geçer, birikmez).
	# Bu, oda görselinin zaten "döşenmiş" görünmesiyle mağazanın çelişmesi
	# sorununu çözer: yatak zaten var, burada sadece daha iyisine geçiliyor.
	var lv := Game.level()
	var base: Dictionary = room.get("base", {})
	var slot_names := {"wallpaper": "Wallpaper", "floor": "Floor", "bed": "Bed"}
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
			var b2 := _button("%s%s" % [it.name, "  ✓ owned" if owned else " — %s coins" % _fmt(int(it.price))],
				13, PALETTE.wood, PALETTE.cream_text)
			b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if owned:
				b2.disabled = true
			elif lv < int(it.get("unlock_level", 1)):
				b2.text = "%s — unlocks at level %d" % [it.name, int(it.unlock_level)]
				b2.disabled = true
			else:
				b2.disabled = not Game.can_afford_item(it)
				var iid2: String = it.id
				b2.pressed.connect(func():
					if Game.upgrade_base(selected_room, iid2):
						_play("buy")
						_show_toast("%s upgraded!" % Game.item_def(iid2).name)
						_maybe_show_upgrade_ad())
			c.add_child(b2)

	c.add_child(_label("Add a decoration:", 14, PALETTE.muted))
	for it in Game.eco.items:
		if not it.has("anchor"):
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		c.add_child(row)
		row.add_child(_icon("res://assets/items/%s.svg" % it.id, 40))
		var price_text: String = "%d gems ◆" % int(it.get("gem_price", 0)) if Game.item_is_premium(it) else "%s coins" % _fmt(int(it.price))
		var b := _button("%s — SP +%d — %s" % [it.name, int(it.sp), price_text], 14,
			PALETTE.green_deep if Game.item_is_premium(it) else PALETTE.wood, PALETTE.cream_text)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if lv < int(it.get("unlock_level", 1)):
			b.text = "%s — unlocks at level %d" % [it.name, int(it.unlock_level)]
			b.disabled = true
		elif Game.room_has_item(selected_room, it.id):
			b.text = "%s — owned ✓" % it.name
			b.disabled = true
		else:
			b.disabled = not Game.can_afford_item(it)
			var iid: String = it.id
			b.pressed.connect(func():
				if Game.buy_item(selected_room, iid):
					_play("buy")
					_show_toast("%s placed (+%d SP)" % [Game.item_def(iid).name, int(Game.item_def(iid).sp)])
					_maybe_show_upgrade_ad())
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
		c.add_child(_label("+%d coins/hour base income · adds to star variety" % int(d.base_income), 13, PALETTE.muted))
	else:
		c.add_child(_label("Cleans dirty rooms by itself — income never stops.", 13, PALETTE.muted))
	_add_manage_buttons(c)


## Oda popup'larının ortak yönetim satırı: Taşı + onaylı Sat.
func _add_manage_buttons(c: VBoxContainer) -> void:
	c.add_child(_spacer_y(6))
	if not build_mode:
		c.add_child(_label("Turn on Build Mode first to move or sell.", 12, PALETTE.muted))
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	c.add_child(row)
	var ridx := selected_room
	var mv := _button("Move", 14, PALETTE.wood_dark, PALETTE.cream_text)
	mv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mv.pressed.connect(func():
		move_from = String(Game.rooms[ridx].id)
		_close_popup()
		_show_toast("Tap an empty cell — tap your room again to cancel"))
	row.add_child(mv)
	var sell_text := "Sell — +%s coins" % _fmt(Game.room_sell_value(ridx))
	var sell_gems := Game.room_sell_gem_value(ridx)
	if sell_gems > 0:
		sell_text += " +%s" % _count(sell_gems, "gem")
	var sl := _button(sell_text, 14, PALETTE.banner_red, PALETTE.cream_text)
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.pressed.connect(func():
		if not sl.get_meta("armed", false):
			sl.set_meta("armed", true)
			sl.text = "Are you sure?\nTap again to sell"
			return
		if Game.sell_room(ridx):
			_play("buy")
			_close_popup()
			_show_toast("Room sold — the refund is in the till")
		else:
			_show_toast("You can't sell your last room!"))
	row.add_child(sl)


## Profil ile (bkz. _build_profile_popup) ve tests/shot.gd'nin "stats" test
## anahtarıyla paylaşılan asıl istatistik içeriği — alt bardaki ayrı
## İstatistik ikonu kaldırıldı, artık yalnızca Profil üzerinden erişilir.
func _add_stats_rows(c: VBoxContainer) -> void:
	var rows := [
		["Total income collected", "%s coins" % _fmt(Game.stat_collected_total)],
		["Collections", str(Game.stat_collects)],
		["Rooms cleaned", str(Game.stat_cleans)],
		["Shifts started", str(Game.stat_shifts)],
		["Rooms", "%s (%d / %d blocks used)" % [_count(Game.rooms.size(), "room"), _blocks_used(), Game.max_slots()]],
		["Facility variety", "%d / 5" % Game.facility_diversity()],
		["Star rating", "%d / 5" % Game.star_rating()],
		["Level", "%d (XP %s)" % [Game.level(), _fmt(Game.xp)]],
		["Income per hour (now)", "%.0f coins" % Game.hourly_income()],
		["Prestige multiplier", "×%.2f (prestige %d)" % [Game.prestige_mult(), Game.prestige_level]],
		["Daily login streak", _count(Game.daily_streak, "day")],
	]
	for r in rows:
		var row := HBoxContainer.new()
		c.add_child(row)
		var ll := _label(String(r[0]), 14, PALETTE.muted)
		ll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(ll)
		row.add_child(_label(String(r[1]), 14, PALETTE.text))
	c.add_child(_spacer_y(6))
	c.add_child(_label("Shift history (last %d):" % Game.shift_history.size(), 14, PALETTE.wood_dark))
	if Game.shift_history.is_empty():
		c.add_child(_label("No shift has been started yet.", 13, PALETTE.muted))
		return
	var bias: int = int(Time.get_time_zone_from_system().bias) * 60
	for i in range(Game.shift_history.size() - 1, -1, -1):
		var h: Dictionary = Game.shift_history[i]
		var dt := Time.get_datetime_dict_from_unix_time(int(float(h.at)) + bias)
		c.add_child(_label("%02d.%02d %02d:%02d — %dh · cost %s coins" % [
			dt.day, dt.month, dt.hour, dt.minute, int(h.hours), _fmt(int(h.cost))], 13, PALETTE.text))


func _build_stats_popup(c: VBoxContainer) -> void:
	_add_stats_rows(c)


## Üst bardaki seviye/para alanına dokununca açılır (bkz. _rebuild_hotel'deki
## top.gui_input). Hesap bağlama (ileride) + Premium + Prestij + İstatistik
## tek ekranda toplandı — kullanıcı isteği: bunlar Ayarlar'dan sadeleştirildi.
func _build_profile_popup(c: VBoxContainer) -> void:
	_build_cloud_section(c)

	c.add_child(_spacer_y(6))
	c.add_child(_label("Move your save — a shareable code instead of the cloud:", 14, PALETTE.text))
	var export_code := Game.export_save_code()
	var export_field := LineEdit.new()
	export_field.text = export_code
	export_field.editable = false
	c.add_child(export_field)
	var copy_b := _button("Copy code to clipboard", 14, PALETTE.wood, PALETTE.cream_text)
	copy_b.pressed.connect(func():
		DisplayServer.clipboard_set(export_code)
		_show_toast("Save code copied to the clipboard"))
	c.add_child(copy_b)
	c.add_child(_spacer_y(4))
	var import_field := LineEdit.new()
	import_field.placeholder_text = "Paste another save code here…"
	c.add_child(import_field)
	var import_b := _button("Import\noverwrites your current save", 14, PALETTE.banner_red, PALETTE.cream_text)
	import_b.pressed.connect(func():
		if not import_b.get_meta("armed", false):
			import_b.set_meta("armed", true)
			import_b.text = "Are you sure?\nTap again to overwrite"
			return
		if Game.import_save_code(import_field.text):
			Game.save_game()
			_close_popup()
			_show_toast("Save imported!")
		else:
			_show_toast("Invalid code — check it and try again"))
	c.add_child(import_b)

	c.add_child(_spacer_y(10))
	c.add_child(_label("Premium", 15, PALETTE.wood_dark))
	if Game.remove_ads:
		c.add_child(_label("Ads removed. Thank you!", 13, PALETTE.green_deep))
	else:
		var no_ads_b := _button("Remove Ads", 15, PALETTE.green_deep, PALETTE.cream_text)
		_button_icon(no_ads_b, "res://assets/ui/ad_video.png")
		no_ads_b.pressed.connect(func():
			IAP.purchase(IAP.PRODUCT_REMOVE_ADS, func(ok: bool):
				if ok:
					Game.remove_ads = true
					Game.save_game()
					_play("buy")
					_show_toast("Ads removed!")
					_rebuild_popup()))
		c.add_child(no_ads_b)
	if Game.permanent_income_mult > 1.0:
		c.add_child(_label("Income multiplier active: ×%.1f" % Game.permanent_income_mult, 13, PALETTE.green_deep))
	else:
		var x2_b := _button("Double Your Earnings", 15, PALETTE.green_deep, PALETTE.cream_text)
		_button_icon(x2_b, "res://assets/ui/dollar.png")
		x2_b.pressed.connect(func():
			IAP.purchase(IAP.PRODUCT_INCOME_2X, func(ok: bool):
				if ok:
					Game.permanent_income_mult = 2.0
					Game.save_game()
					_play("buy")
					_show_toast("Earnings doubled!")
					_rebuild_popup()))
		c.add_child(x2_b)

	c.add_child(_spacer_y(10))
	c.add_child(_label("Prestige — multiplier ×%.2f (round %d)" % [Game.prestige_mult(), Game.prestige_level], 15, PALETTE.wood_dark))
	if Game.can_prestige():
		var next_mult: float = Game.prestige_mult() + float(Game.eco.prestige.mult_gain)
		var p_b := _button("Prestige the hotel — new multiplier ×%.2f" % next_mult, 15, PALETTE.green_deep, PALETTE.cream_text)
		p_b.pressed.connect(func():
			if p_b.get_meta("armed", false):
				Game.do_prestige()
				_close_popup()
				_show_toast("Prestiged! New income multiplier: ×%.2f" % Game.prestige_mult())
			else:
				p_b.set_meta("armed", true)
				p_b.text = "Are you sure?\nProgress will be reset — tap again")
		c.add_child(p_b)
		c.add_child(_label_wrap("Prestige resets your coins, rooms, quests and achievements; the multiplier is permanent.", 12, PALETTE.muted))
	else:
		c.add_child(_label("Prestige requires level %d (you are %d)." % [int(Game.eco.prestige.min_level), Game.level()], 13, PALETTE.muted))

	c.add_child(_spacer_y(10))
	c.add_child(_label("Statistics", 15, PALETTE.wood_dark))
	_add_stats_rows(c)


## Profil popup'ının "Hesap / Bulut kaydı" bölümü.
##
## Firebase yapılandırılmamışken (placeholder'lar dururken, bkz.
## src/cloud/firebase_config.gd) bölüm bugünkü davranışını korur: bulut yok,
## kayıt yalnızca aşağıdaki paylaşılabilir kodla taşınır. Yapılandırma
## geldiğinde aynı bölüm kendiliğinden durum + yedekleme + hesap bağlamaya
## dönüşür — UI'da ayrıca bir bayrak açmak gerekmez.
func _build_cloud_section(c: VBoxContainer) -> void:
	c.add_child(_label("Account", 16, PALETTE.wood_dark))
	if not CloudSave.is_enabled():
		c.add_child(_label_wrap("Cloud save is not enabled in this build yet — for now you can move your save to another device with the code below.", 12, PALETTE.muted))
		var soon_b := _button("Link with Google — coming soon", 14, PALETTE.wood_dark, PALETTE.cream_text)
		soon_b.disabled = true
		c.add_child(soon_b)
		return

	if CloudSave.has_conflict():
		c.add_child(_label_wrap("The cloud holds different progress than this device. You decide which one to keep.", 12, PALETTE.banner_red))
		var pick_b := _button("Choose a save — Cloud / This device", 15, PALETTE.banner_red, PALETTE.cream_text)
		pick_b.pressed.connect(func(): _show_cloud_conflict_modal())
		c.add_child(pick_b)
		c.add_child(_spacer_y(6))

	var who := "Linked to this device (anonymous)" if not CloudSave.is_linked() else "Linked to a Google account"
	c.add_child(_label(who, 13, PALETTE.text))
	c.add_child(_label("Last backup: %s" % _cloud_sync_text(), 12, PALETTE.muted))

	var backup_b := _button("Back up now", 14, PALETTE.wood, PALETTE.cream_text)
	backup_b.pressed.connect(func():
		backup_b.disabled = true
		var result: String = await CloudSave.sync_now()
		_show_toast(_cloud_result_toast(result))
		_rebuild_popup())
	c.add_child(backup_b)

	var link_b := _button("Link with Google", 14, PALETTE.green_deep, PALETTE.cream_text)
	if CloudSave.is_linked():
		link_b.text = "Your account is linked"
		link_b.disabled = true
	elif not CloudSave.is_account_linking_available():
		# Google girişi bir platform eklentisi ister (bkz. cloud_save.gd
		# set_google_id_token_provider) — eklenti yokken yedekleme yine çalışır,
		# yalnızca cihaz değişiminde geri alınamaz.
		link_b.text = "Link with Google — coming soon"
		link_b.disabled = true
		c.add_child(link_b)
		c.add_child(_label_wrap("Your save is backed up even without linking, but you need a linked account to open it on a new device.", 12, PALETTE.muted))
		return
	else:
		link_b.pressed.connect(func():
			link_b.disabled = true
			var res: Dictionary = await CloudSave.link_google()
			_show_toast(String(res.get("msg", "")))
			_rebuild_popup())
	c.add_child(link_b)


## Son senkron durumunun tek satırlık özeti.
func _cloud_sync_text() -> String:
	var at: float = CloudSave.last_success_unix()
	if at <= 0.0:
		return "not yet"
	return _fmt_relative(at)


func _cloud_result_toast(result: String) -> String:
	match result:
		CloudPayload.RESULT_RESTORE:
			return "Cloud save restored"
		CloudPayload.RESULT_CONFLICT:
			return "The cloud holds different progress — pick which one to keep"
		CloudPayload.RESULT_NEEDS_UPDATE:
			return "The cloud save comes from a newer version — update the game first"
		CloudPayload.RESULT_DISABLED:
			return "Could not reach the cloud — check your connection and try again"
	return "Your save is backed up to the cloud"


## "3 dakika önce" gibi göreli zaman. Bulut tarafı için SUNUCU damgası kullanılır
## (bkz. cloud_save.gd) — cihaz saatiyle hesaplanan bir "önce" yanıltıcı olurdu.
func _fmt_relative(unix: float) -> String:
	var diff := Time.get_unix_time_from_system() - unix
	if diff < 60.0:
		return "just now"
	if diff < 3600.0:
		return "%s ago" % _count(int(diff / 60.0), "minute")
	if diff < 86400.0:
		return "%s ago" % _count(int(diff / 3600.0), "hour")
	return "%s ago" % _count(int(diff / 86400.0), "day")


## Çakışma seçici: "Bulut / Bu cihaz". KOD KENDİ KARAR VERMEZ ve iki ilerlemeyi
## BİRLEŞTİRMEZ (bkz. cloud_save.gd tasarım notu) — oyuncuya her iki tarafın
## özeti gösterilir ve seçmediği taraf olduğu yerde durur.
func _show_cloud_conflict_modal(on_closed: Callable = Callable()) -> void:
	if not CloudSave.has_conflict() or _cloud_conflict_open:
		if on_closed.is_valid():
			on_closed.call()
		return
	_cloud_conflict_open = true
	var cloud: Dictionary = CloudSave.conflict_summary()
	var cloud_at: float = CloudSave.conflict_updated_at()

	var dim := ColorRect.new()
	dim.color = Color(0.2, 0.15, 0.05, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.z_index = 95
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.add_child(center)
	var panel := _panel(PALETTE.cream, PALETTE.facade_line)
	panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(panel)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 12)
	panel.add_child(pv)
	pv.add_child(_label("Which save should continue?", 20, PALETTE.wood_dark))
	pv.add_child(_label_wrap("There are two different saves, one in the cloud and one on this device. They are never merged automatically — pick one and the other stays as it is.", 12, PALETTE.muted))

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 12)
	pv.add_child(cols)
	cols.add_child(_cloud_side_column("Cloud",
		int(cloud.get("level", 0)), int(cloud.get("coins", 0)),
		int(cloud.get("gems", 0)), int(cloud.get("rooms", 0)),
		_fmt_relative(cloud_at) if cloud_at > 0.0 else "time unknown"))
	cols.add_child(_cloud_side_column("This device",
		Game.level(), Game.coins, Game.gems, Game.rooms.size(), "now"))

	var closed := false
	var do_close := func():
		if closed:
			return
		closed = true
		_cloud_conflict_open = false
		dim.queue_free()
		if on_closed.is_valid():
			on_closed.call()

	var cloud_b := _button("Use the cloud's", 15, PALETTE.green_deep, PALETTE.cream_text)
	cloud_b.pressed.connect(func():
		var ok: bool = CloudSave.resolve_keep_cloud()
		do_close.call()
		_show_toast("Cloud save loaded" if ok else "The cloud save could not be read; this device's save was kept")
		_refresh())
	pv.add_child(cloud_b)

	var local_b := _button("Use this device's", 15, PALETTE.wood_dark, PALETTE.cream_text)
	local_b.pressed.connect(func():
		do_close.call()
		_show_toast("Kept this device's save and uploading it to the cloud")
		await CloudSave.resolve_keep_local())
	pv.add_child(local_b)

	# Çakışma modalı dışına tıklayarak KAPATILAMAZ: kararı ertelemek, seçim
	# yapılana dek buluta hiç yazılmaması demek — oyuncunun bunu fark etmeden
	# oynamaya devam etmesi daha kötü bir durum.
	add_child(dim)
	_play("tap")


func _cloud_side_column(title: String, lv: int, coins: int, gems: int,
		rooms: int, when: String) -> Control:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(_label(title, 16, PALETTE.wood_dark))
	box.add_child(_label(when, 12, PALETTE.muted))
	box.add_child(_label("Level %d" % lv, 14, PALETTE.text))
	box.add_child(_label("%s coins" % _fmt(coins), 14, PALETTE.text))
	box.add_child(_label(_count(gems, "gem"), 14, PALETTE.text))
	box.add_child(_label(_count(rooms, "room"), 14, PALETTE.text))
	return box


func _build_gems_popup(c: VBoxContainer) -> void:
	c.add_child(_label("Buy gems", 16, PALETTE.wood_dark))
	c.add_child(_label_wrap("Prices are set in the store (Play Console) — the ones below are suggestions.", 12, PALETTE.muted))
	for pack in GEM_PACKS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		c.add_child(row)
		row.add_child(_icon("res://assets/ui/gem.svg", 32))
		var product: String = pack.product
		var amount: int = pack.gems
		var price_label: String = IAP.price_for(pack.product, pack.price)
		var b := _button("%s — %s" % [_count(amount, "gem"), price_label], 15, PALETTE.green_deep, PALETTE.cream_text)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func():
			IAP.purchase(product, func(ok: bool):
				if ok:
					Game.gems += amount
					Game.save_game()
					_play("buy")
					_show_toast("%s added!" % _count(amount, "gem"))
					_rebuild_popup()))
		row.add_child(b)


func _build_settings_popup(c: VBoxContainer) -> void:
	var s_b := _button("Sound effects: %s" % ("On" if Game.sound_on else "Off"), 15,
		PALETTE.wood if Game.sound_on else PALETTE.wood_dark, PALETTE.cream_text)
	s_b.pressed.connect(func():
		Game.sound_on = not Game.sound_on
		Game.save_game()
		_play("tap")
		_rebuild_popup())
	c.add_child(s_b)

	var m_b := _button("Lobby music: %s" % ("On" if Game.music_on else "Off"), 15,
		PALETTE.wood if Game.music_on else PALETTE.wood_dark, PALETTE.cream_text)
	m_b.pressed.connect(func():
		Game.music_on = not Game.music_on
		music_player.playing = Game.music_on
		Game.save_game()
		_rebuild_popup())
	c.add_child(m_b)

	c.add_child(_spacer_y(8))
	c.add_child(_label_wrap("Auto-renew moved to Shift; Premium/Prestige and save transfer moved to Profile.", 12, PALETTE.muted))
	c.add_child(_spacer_y(4))
	c.add_child(_label("Danger zone:", 13, PALETTE.banner_red))
	var r_b := _button("Reset save", 15, PALETTE.banner_red, PALETTE.cream_text)
	r_b.pressed.connect(func():
		if r_b.get_meta("armed", false):
			Game.reset_game()
			_close_popup()
			_show_toast("Save reset — a new game has begun!")
		else:
			r_b.set_meta("armed", true)
			r_b.text = "Are you sure?\nTap again to delete")
	c.add_child(r_b)
	c.add_child(_label("Resetting erases all progress permanently.", 12, PALETTE.muted))


func _build_quests_popup(c: VBoxContainer) -> void:
	var q: Dictionary = Game.current_quest()
	if q.is_empty():
		c.add_child(_label("Every quest is done. Congratulations, hotelier!", 16, PALETTE.green_deep))
	else:
		var p: Array = Game.quest_progress(q)
		c.add_child(_label(String(q.name), 19, PALETTE.wood_dark))
		var desc := _label(String(q.desc), 15, PALETTE.text)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		c.add_child(desc)
		c.add_child(_label("Progress: %d / %d" % [mini(p[0], p[1]), p[1]], 14, PALETTE.muted))
		var reward := "Reward: %s coins" % _fmt(int(q.get("reward_coins", 0)))
		if int(q.get("reward_gems", 0)) > 0:
			reward += " + %s" % _count(int(q.reward_gems), "gem")
		c.add_child(_label(reward, 14, PALETTE.green_deep))
	c.add_child(_label("Quests completed: %d / %d" % [Game.quest_index, Game.quests.size()], 13, PALETTE.muted))

	c.add_child(_spacer_y(10))
	c.add_child(_label("Achievements — %d / %d unlocked" % [Game.unlocked_achievements.size(), Game.achievements.size()], 16, PALETTE.wood_dark))
	for a: Dictionary in Game.achievements:
		var unlocked: bool = Game.unlocked_achievements.has(String(a.id))
		var p: Array = Game.quest_progress(a)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		c.add_child(row)
		var mark := _label("✓" if unlocked else "•", 15, PALETTE.green_deep if unlocked else PALETTE.muted)
		mark.custom_minimum_size = Vector2(22, 0)
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
	var msg := "Quest complete: %s — +%s coins" % [q.name, _fmt(int(q.get("reward_coins", 0)))]
	if int(q.get("reward_gems", 0)) > 0:
		msg += ", +%s" % _count(int(q.reward_gems), "gem")
	_show_toast(msg)


func _on_achievement_unlocked(a: Dictionary) -> void:
	_play("quest")
	var msg := "Achievement unlocked: %s — +%s coins" % [a.name, _fmt(int(a.get("reward_coins", 0)))]
	if int(a.get("reward_gems", 0)) > 0:
		msg += ", +%s" % _count(int(a.reward_gems), "gem")
	_show_toast(msg)


func _show_toast(msg: String) -> void:
	toast_label.text = msg
	toast_panel.visible = true
	_toast_timer = 3.0


func _show_offline_popup(amount: int, renew_count: int = 0, renew_spent: int = 0) -> void:
	var text := ""
	if amount > 0:
		text += "Your hotel kept running while you were away and earned %s coins.\nDon't forget to collect from the till!" % _fmt(amount)
	if renew_count > 0:
		if not text.is_empty():
			text += "\n\n"
		text += "Your hotel didn't sit idle when the shift ended: it auto-renewed %s (staff cost %s coins)." % [_count(renew_count, "time"), _fmt(renew_spent)]
	_show_simple_modal("Welcome back!", text, "Great", func(): pass)


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
	var reward_text := "%s coins" % _fmt(int(reward.get("coins", 0)))
	if int(reward.get("gems", 0)) > 0:
		reward_text += " + %s" % _count(int(reward.gems), "gem")
	_show_simple_modal("Daily Reward", "Day %d streak!\nYour reward: %s" % [streak, reward_text], "Buy",
		func():
			var granted := Game.claim_daily_reward()
			if not granted.is_empty():
				_play("quest")
				_show_toast("Daily reward claimed — day %d streak!" % Game.daily_streak)
			if on_closed.is_valid():
				on_closed.call(),
		on_closed)


func _fmt_hms(game_hours: float) -> String:
	var total := int(game_hours * 3600.0)
	return "%02d:%02d:%02d" % [total / 3600, (total % 3600) / 60, total % 60]


## "1 hour" / "3 hours" — sayı ve ismi İngilizce çoğul kuralına göre birleştirir.
## Türkçede sayıdan sonra isim çoğullanmadığı için ("1 saat", "4 saat") özgün
## metinlerde bu ayrım yoktu; doğrudan çeviri "1 hours" gibi bozuk ifadeler
## üretiyordu. Düzensiz çoğullar için ikinci biçim açıkça verilir.
func _count(n: int, one: String, many: String = "") -> String:
	var word: String = one if n == 1 else (many if many != "" else one + "s")
	return "%d %s" % [n, word]


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
