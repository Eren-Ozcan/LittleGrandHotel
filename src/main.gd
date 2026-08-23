extends Control
## Little Grand Hotel — arayüz (görsel sürüm).
## Hotel City'den ilham alan kesit "dollhouse" görünüm: parlak gökyüzü,
## sıcak cephe, duvar kağıtlı odalar, mobilya ve misafir görselleri.

const PALETTE := {
	"sky_top": Color("8fd0f5"),
	"sky_bottom": Color("ffe0ea"),
	"cream": Color("fff6e6"),
	"cream_dark": Color("f3e6cc"),
	# Menü sayfalarındaki kartların zemini (bkz. _card). Prototipte saf beyaz:
	# gövde krem, kart beyaz, kenar facade_line.
	"card": Color("ffffff"),
	# Prototipin uyarı/bilgi kutuları ve inert alanları.
	"red_soft": Color("fdece9"),
	# Üst bardaki elmas "+" butonu ve gökyüzü çipleri (prototip: yarı saydam
	# koyu hap + kırmızı tema hapı).
	"green_soft": Color("e7f6ec"),
	"chip_dark": Color(0.184, 0.141, 0.094, 0.62),
	"red_text": Color("b8402f"),
	# Fiyat hapının zemini ve vurgulu paketin kırmızısı (tasarımdaki mağaza
	# blokları: krem hap + altın kenar, ortadaki paket dolu kırmızı).
	"pill_cream": Color("fff5dc"),
	"pop_red": Color("b23a2e"),
	"gold_notice": Color("fff9ea"),
	"field": Color("f7f1e2"),
	"plum_text": Color("e6ddf2"),
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
	# Merkez yuvarlak butonun sert alt gölgesi (prototip: `0 6px 0 #96311f`).
	"red_lip": Color("96311f"),
	"floor_wood": Color("c19a6f"),
	"locked": Color("6b5f52"),
	"frame": Color("2f2418"),
	"asphalt": Color("6b6f78"),
	"sidewalk": Color("c9c3b4"),
	"curb": Color("e0a83c"),
	"bar_dark": Color("3a2c4d"),
	# Alt bar şeridinin üst kenarı (prototip: `border-top:3px solid #2b2039`).
	"bar_edge": Color("2b2039"),
	"grass": Color("6cc24a"),
	"grass_dark": Color("4e9e34"),
}

## Kullanıcı geri bildirimi: "çoğu UI butonu ve yazısı gereksiz küçük" —
## tüm _label/_button metinleri bu çarpanla büyütülür (bkz. _label, _button).
## Tasarımın telefon çerçevesi 360 CSS pikseli, viewport 720 — yani bire bir
## karşılık 2.0. Bu çarpanla `_label(size)` çağrılarındaki sayı doğrudan
## TASARIMDAKİ px değeri oluyor; 1.15/1.3/1.55 denemeleri hep bu ölçünün
## altında kalıp "hâlâ küçük" geri bildirimi almıştı.
const UI_TEXT_SCALE := 2.0

## Minimum touch target, in viewport pixels. Android (and iOS) ask for 48dp.
## On a 440dpi phone 48dp is 132 physical pixels, and the 720-wide viewport is
## stretched to 1080, so the scale is 1.5 and 132 / 1.5 = 88 viewport pixels.
## The bottom bar (see _bar_button) was already above it at 92; rows, tabs and
## pill buttons were well under (measured: row ~34dp, tab ~16dp).
const TOUCH_MIN := 88

## Touch scrolling in a ScrollContainer is driven by the InputEventScreenDrag
## the finger produces, and that event only reaches the ScrollContainer if every
## Control under the finger lets it through. Control defaults to
## MOUSE_FILTER_STOP, so the decorative PanelContainer a list row is painted
## with, and the transparent Button laid over it, both swallowed the drag: the
## popup lists only scrolled from the ~15px gutter beside the cards, where no
## row was in the way.
##
## Two roles, two filters. MOUSE_PASSTHROUGH is for anything that only draws —
## panels, dividers, progress bars: they are not hit targets at all. Anything
## that must still be tapped keeps receiving events but hands the drag on to the
## ScrollContainer above it (MOUSE_SCROLLABLE). A drag that gets past the
## ScrollContainer's deadzone makes it fire NOTIFICATION_SCROLL_BEGIN down the
## tree, which BaseButton reads as "cancel the press" — so scrolling over a row
## scrolls and does not also activate the row.
##
## Only popup content is set up this way. The bottom bar, the hotel canvas and
## the build tray run their own drag gestures and stay MOUSE_FILTER_STOP.
const MOUSE_PASSTHROUGH := Control.MOUSE_FILTER_IGNORE
const MOUSE_SCROLLABLE := Control.MOUSE_FILTER_PASS

## Touch scrolling starts once the finger has travelled this far, in viewport
## pixels. Godot's default is 0, which means the tiniest wobble during a tap
## already counts as a drag and cancels the row press underneath — on a phone
## almost every tap wobbles. 12 viewport pixels is 18 physical pixels at the
## 1.5 stretch: past finger jitter, well short of a deliberate swipe.
const SCROLL_DEADZONE := 12

## Modal kartın ekran kenarına bırakacağı en az boşluk, viewport pikseli —
## güvenli alanın (çentik, sistem çubukları) ÜSTÜNE eklenir. Kart bu payı
## yiyecek kadar uzarsa gövdesi kaydırmaya döner (bkz. _modal_shell).
const MODAL_SCREEN_MARGIN := 40

## The design sets every screen in Figtree, and the two currency counters in
## Pixelify Sans. Both ship as variable fonts, so one file covers every weight
## the design uses (400 body, 500/600 labels, 700 titles) through
## FontVariation. Licenses sit next to them (SIL OFL, redistribution is fine).
const FONT_UI := preload("res://assets/fonts/Figtree.ttf")
const FONT_NUM := preload("res://assets/fonts/PixelifySans.ttf")

## Bands run edge to edge, but the controls inside them must not. The Android
## manifest asks for layoutInDisplayCutoutMode=always, so the game paints into
## the notch and all the way into the display's rounded corners — the bottom
## bar's outermost tiles (Build, Store) were being clipped by that arc, and the
## top bar sits under the cutout. Every piece of chrome that touches an edge
## takes its inset from _safe_insets instead of a hand-picked number.
##
## Android reports the cutout and the system bars through the safe area, but
## NOT the corner radius, so these floors carry that case on their own. In
## viewport pixels: 24 is 36 physical pixels at the 1.5 stretch, comfortably
## past a typical corner arc.
const UI_SAFE_MIN_X := 24
const UI_SAFE_MIN_TOP := 14
const UI_SAFE_MIN_BOTTOM := 10

## The two controls that sit ON the world rather than in a menu — the top bar's
## gem "+" and the Build/Clean chips. At the full 88 the "+" swallows the top
## bar and the chips turn into big circles, so they stop at 68 (~37dp). Every
## control inside a menu still meets the full 48dp.
const TOUCH_MIN_CHROME := 68

## Mağaza politikası bağlantıları (bkz. docs/store/store-listing.md ve
## account-setup-checklist.md). Ayarlar'dan açılır, açılış ekranındaki sürüm
## etiketiyle aynı sabiti kullanır.
const GAME_VERSION := "1.0"
const PRIVACY_POLICY_URL := "https://yilkgames.com/privacy-policy/"
const SUPPORT_EMAIL := "yilkgamesstudio@gmail.com"

## Misafir oda tipine göre ayrı sanat havuzları: oyuncu daha pahalı oda
## Misafirler/sokak yürüyüşçüleri için karakter havuzu (referans sayfadaki
## 5 temel + 4 ekstra varyant) — tek tip 3'lü rotasyon yerine daha çeşitli.
const GUEST_TYPES := ["a", "b", "c", "d_elder", "e_couple", "f_business", "g_kid"]

## Açılış tutorial'ı: yalnızca yepyeni bir kayıtta (Game.tutorial_seen == false)
## gösterilen adım dizisi (bkz. _maybe_show_tutorial). İki tür adım var:
## "modal" — bilgilendirme, Next butonuna basınca ilerler (bkz. _show_simple_modal).
## "tap" — oyuncuyu GERÇEK arayüz elemanına dokunmaya zorlar: buton yok, ekranın
## geri kalanı karartılır, hedef aydınlıkta kalır ve yalnızca o elemana dokununca
## (bkz. _tutorial_advance_on çağrı noktaları) bir sonraki adıma geçilir.
const TUTORIAL_STEPS := [
	{"type": "modal", "title": "Welcome!", "text": "Welcome to Little Grand Hotel! You'll turn one small hotel into a grand empire, step by step. Let's take a quick look.", "btn": "Next"},
	{"type": "tap", "title": "1. Start a Shift", "text": "Tap the big button above the bar to start a shift — the hotel only runs, and only earns, during a shift.", "target": "shift_button", "event": "shift_tap"},
	{"type": "modal", "title": "2. Welcome Your Guests", "text": "Once a shift starts, guests come through the door and ride the elevator to their rooms. As rooms fill up, income starts building.", "btn": "Next"},
	{"type": "tap", "title": "3. Collect From the Till", "text": "The same button now reads Collect — tap it to take what you have earned. Earnings sit in the till until you collect them.", "target": "collect_button", "event": "collect_tap"},
	{"type": "tap", "title": "4. Decorate the Rooms", "text": "Tap a room and buy furnishings — as Style Points rise the room moves up a tier and your hotel gains stars.", "target": "zoom_viewport", "event": "room_tap"},
	{"type": "tap", "title": "5. Follow the Quests", "text": "Tap the quest icon — it shows your active quest, which pays out coins and gems.", "target": "quest_bar_button", "event": "quest_tap"},
	{"type": "modal", "title": "You're Ready!", "text": "Now open your doors and start building your grand hotel!", "btn": "Start!"},
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
var xp_text_label: Label
var shift_label: Label
var shift_bar_label: Label
## Merkez birincil butonun üst satırı ("Start shift" / "Collect").
var primary_label: Label
var collect_button: Button
## Topla butonu birikim varken hafifçe nabız gibi büyüyüp küçülür (dikkat
## çekmek için) — bkz. _start_collect_pulse/_stop_collect_pulse.
var _collect_pulse_on := false
var _collect_tween: Tween
var shift_button: Button
var quest_bar_button: Button
## Kenara değen parçaları ekranın çentiğinden, sistem çubuklarından ve
## yuvarlatılmış köşelerinden uzak tutan kenar boşlukları — hepsi
## _apply_safe_area tarafından tek yerden beslenir.
var bar_safe_pad: MarginContainer
var top_safe_pad: MarginContainer
var popup_head_pad: MarginContainer
var popup_pad: MarginContainer
## Alt bar sekmeleri, başlığa göre — aktif durumu boyamak için.
var _bar_buttons := {}
## Açık olan sekmenin başlığı ("" = popup kapalı).
var _active_tab := ""
var quest_badge: PanelContainer
var quest_badge_label: Label
## Quests ekranı en son açıldığında kaç görev/başarım tamamlanmıştı — rozet
## sayısı bunun üstüne biriken "görülmemiş" tamamlamalar (bkz.
## _update_bar_active). Oturumluk: uygulama yeniden açılınca sıfırlanır.
var _quests_seen_index := 0
var _achievements_seen_count := 0

## "Dokunmak zorunda" tutorial adımları için spotlight katmanı — bkz.
## _build_tutorial_layer / _show_tutorial_spotlight / TUTORIAL_STEPS.
var tutorial_layer: Control
var _tutorial_dim_top: ColorRect
var _tutorial_dim_bottom: ColorRect
var _tutorial_dim_left: ColorRect
var _tutorial_dim_right: ColorRect
var _tutorial_ring: Panel
var _tutorial_bubble: PanelContainer
var _tutorial_bubble_label: Label
var _tutorial_step_index := -1
var _tutorial_pulse_tween: Tween
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
## Tabelaya sığan en uzun ad. 16 iken oyunun KENDİ varsayılan adı ("Little Grand
## Hotel", 18 karakter) bu sınıra sığmıyordu: yeniden adlandırma modalindeki
## LineEdit önceden dolu metni sessizce kırpıyor, oyuncu hiçbir şey yazmadan
## Kaydet'e bastığında otelin adı "Little Grand Hot" oluyordu. Tabela
## autowrap + clip_text ile 18 karakteri zaten sorunsuz gösteriyor (iki satıra
## sarıyor), sınır o yüzden varsayılanı kapsayacak şekilde açıldı.
## Değişmez kural: HOTEL_NAME_MAX_LEN >= varsayılan adın uzunluğu
## (bkz. tests/ui_check.gd).
const HOTEL_NAME_MAX_LEN := 18
var build_mode_button: Button
## İnşa Modu kapalıyken boş/kilitli hücreler sade durur (buton/metin yok);
## açıkken vurgulanır ve dokunulabilir olur (TODO: görsel kalabalığı azaltma).
var build_mode := false
var clean_mode_button: Button
## Temizlik Modu: İnşa Modu gibi bir tuval modu. Açıkken kirli odalara tek tek
## dokunarak temizlenir; kapalıyken kirli odaya dokunmak diğer odalarla aynı
## şeyi yapar (oda ekranını açar). Eskiden dokunma anında temizliyordu —
## kullanıcı isteğiyle kaldırıldı, temizlik artık bilinçli bir moda girmeyi
## gerektiriyor. İki mod aynı anda açık olamaz (bkz. _set_clean_mode).
var clean_mode := false
var _zoom := 1.0
var _canvas_pan := Vector2.ZERO
var _pan_dragging := false
var _pan_drag_start := Vector2.ZERO
var _pan_start_canvas_pos := Vector2.ZERO

var overlay: Control
var popup_title: Label
var popup_content: VBoxContainer
var popup_scroll: ScrollContainer
var popup_back_button: Button
## Popup başlık şeridindeki para göstergesi (prototip): oyuncu satın alma
## ekranındayken bakiyesini görmek için ekranı kapatmak zorunda kalmasın.
var popup_coins_label: Label
var popup_gems_label: Label
## Top of _popup_stack, kept as a plain Callable so every existing caller
## (_rebuild_popup, _refresh) can keep asking "is a popup live?".
var popup_builder: Callable = Callable()
## Screen stack: [{"title": String, "builder": Callable}]. _open_popup starts a
## new stack (bottom-bar tabs must not pile up), _push_popup goes one level
## deeper (Store -> room picker), _pop_popup walks back.
var _popup_stack: Array[Dictionary] = []
## Which tab is open inside the Store / Profile popups. Popups are rebuilt on
## every state_changed, so the selection cannot live in a local.
var _store_tab := "gems"
var _profile_tab := "account"
var _quests_tab := "quests"
## Shift ▸ "Finish now" iki adımlı onayının durumu. Popup yeniden kurulduğunda
## kaybolmaması için burada tutulur (bkz. _build_shift_popup).
var _skip_shift_armed := false
## Bundle waiting for the player to pick a room in the Store -> Offers flow.
var _pending_bundle_id := ""

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
			# Yığın varsa bir seviye geri, kökteysek kapat (bkz. _pop_popup).
			_pop_popup()
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
	# Rozet yalnızca BU oturumda tamamlananları sayar; açılışta sıfırdan başlar.
	_quests_seen_index = Game.quest_index
	_achievements_seen_count = Game.unlocked_achievements.size()
	# Açılışta zaten süren bir vardiya varsa bunu "yeni biten vardiya" sanıp
	# ilk karede reklam açmayalım.
	_shift_was_active = Game.shift_active()
	Game.state_changed.connect(_refresh)
	Game.quest_completed.connect(_on_quest_completed)
	Game.achievement_unlocked.connect(_on_achievement_unlocked)
	IAP.purchase_result.connect(_on_purchase_restored)
	IAP.restore_finished.connect(_on_restore_finished)
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
			# Metin tek yerde dursun (bkz. _cloud_result_toast) — burada yalnızca
			# HANGİ sonucun duyurulacağına karar veriliyor: her senkron için toast
			# çıkarmak gürültü olurdu, geri yükleme ise oyuncunun görmesi gereken
			# tek durum.
			_show_toast(_cloud_result_toast(result)))
	# Hesap bölümü ("son yedekleme", bağlama durumu) oyuncu dokunmadan da
	# değişebilir: arka plandaki yükleme biter ya da tarayıcıdan dönen bağlama
	# akışı sonuçlanır. Açık popup varsa tazelenir (kapalıysa no-op).
	CloudSave.status_changed.connect(_rebuild_popup)
	Ads.rewarded_ad_result.connect(func(success: bool):
		if not success:
			_show_toast("No ad is ready right now, try again shortly."))
	Game.leveled_up.connect(func(lv):
		_play("level")
		_show_toast(tr("Level up! Level %d (+%s)") % [lv, _count(int(Game.eco.levelup_gems), "gem")]))
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
	_tutorial_clear_spotlight()
	if step >= TUTORIAL_STEPS.size():
		_tutorial_step_index = -1
		Game.tutorial_seen = true
		Game.save_game()
		_after_tutorial()
		return
	var s: Dictionary = TUTORIAL_STEPS[step]
	if String(s.get("type", "modal")) == "tap":
		_tutorial_step_index = step
		# Gerçek bir popup hâlâ açıksa (ör. az önce basılan Shift ikonunun kendi
		# popup'ı) spotlight'ı hemen göstermeyiz — dim şeritleri o popup'ın Close
		# düğmesini de bloklardı (bkz. _close_popup, popup kapanınca gösterir).
		if not overlay.visible:
			_show_tutorial_spotlight(s)
		return
	_tutorial_step_index = -1
	_show_simple_modal(String(s.title), String(s.text), String(s.btn),
		func(): _show_tutorial_step(step + 1),
		func():
			# Dışına tıklayarak/ESC ile atlandı — tüm tutorial'ı görülmüş say.
			Game.tutorial_seen = true
			Game.save_game()
			_after_tutorial())


## Bir "tap" adımını, hedefi kesinlikle görülür olana dek geçen adım
## sayacına bekletmeden, dokunulunca ilerlet. Yalnızca AKTİF adımın
## event alanı eşleşirse tetiklenir — diğer tüm tıklama akışları etkilenmez.
func _tutorial_advance_on(event: String) -> void:
	if _tutorial_step_index < 0 or _tutorial_step_index >= TUTORIAL_STEPS.size():
		return
	var s: Dictionary = TUTORIAL_STEPS[_tutorial_step_index]
	if String(s.get("event", "")) == event:
		_show_tutorial_step(_tutorial_step_index + 1)


func _tutorial_target_control(name: String) -> Control:
	match name:
		"shift_button":
			return shift_button
		"collect_button":
			return collect_button
		"zoom_viewport":
			return zoom_viewport
		"quest_bar_button":
			return quest_bar_button
	return null


## Spotlight: 4 karartma şeridi hedefin rect'i etrafına yerleşir (hedefin
## kendisi boşta kalır, dokunuş normal buton/viewport'a düşer), altın bir
## çerçeve hedefi vurgular, balon konum bilgisiyle metni gösterir. Boyut/
## konum her karede _tutorial_reposition_spotlight ile güncellenir (bkz.
## _process) — layout, ekran döndürme ya da bina kaydırmasıyla kaymasın.
func _show_tutorial_spotlight(s: Dictionary) -> void:
	tutorial_layer.visible = true
	_tutorial_bubble_label.text = "%s\n%s" % [tr(String(s.title)), tr(String(s.text))]
	_tutorial_reposition_spotlight()
	_start_tutorial_pulse()


func _tutorial_clear_spotlight() -> void:
	_stop_tutorial_pulse()
	if tutorial_layer != null:
		tutorial_layer.visible = false


func _tutorial_reposition_spotlight() -> void:
	if _tutorial_step_index < 0 or not tutorial_layer.visible:
		return
	var s: Dictionary = TUTORIAL_STEPS[_tutorial_step_index]
	var target := _tutorial_target_control(String(s.get("target", "")))
	if target == null or not is_instance_valid(target) or target.size == Vector2.ZERO:
		return
	var pad := 6.0
	var top_left: Vector2 = target.global_position - tutorial_layer.global_position - Vector2(pad, pad)
	var sz: Vector2 = target.size + Vector2(pad, pad) * 2.0
	var full: Vector2 = tutorial_layer.size

	_tutorial_dim_top.position = Vector2(0, 0)
	_tutorial_dim_top.size = Vector2(full.x, max(top_left.y, 0.0))
	_tutorial_dim_bottom.position = Vector2(0, top_left.y + sz.y)
	_tutorial_dim_bottom.size = Vector2(full.x, max(full.y - (top_left.y + sz.y), 0.0))
	_tutorial_dim_left.position = Vector2(0, top_left.y)
	_tutorial_dim_left.size = Vector2(max(top_left.x, 0.0), sz.y)
	_tutorial_dim_right.position = Vector2(top_left.x + sz.x, top_left.y)
	_tutorial_dim_right.size = Vector2(max(full.x - (top_left.x + sz.x), 0.0), sz.y)

	_tutorial_ring.position = top_left
	_tutorial_ring.size = sz

	var bubble_sz: Vector2 = _tutorial_bubble.size
	var bubble_below := top_left.y < full.y * 0.5
	_tutorial_bubble.position = Vector2(
		clamp(top_left.x + sz.x / 2.0 - bubble_sz.x / 2.0, 12.0, max(12.0, full.x - bubble_sz.x - 12.0)),
		(top_left.y + sz.y + 14.0) if bubble_below else (top_left.y - bubble_sz.y - 14.0))


## Hedefi ring'i nabız gibi büyütüp küçülterek vurgular — bkz.
## _start_collect_pulse (aynı desen, "topla" butonundaki dikkat çekme).
func _start_tutorial_pulse() -> void:
	if _tutorial_pulse_tween and is_instance_valid(_tutorial_pulse_tween):
		_tutorial_pulse_tween.kill()
	_tutorial_ring.pivot_offset = _tutorial_ring.size / 2.0
	_tutorial_pulse_tween = _tutorial_ring.create_tween()
	_tutorial_pulse_tween.set_loops()
	_tutorial_pulse_tween.tween_property(_tutorial_ring, "scale", Vector2(1.06, 1.06), 0.55) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tutorial_pulse_tween.tween_property(_tutorial_ring, "scale", Vector2(1.0, 1.0), 0.55) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_tutorial_pulse() -> void:
	if _tutorial_pulse_tween and is_instance_valid(_tutorial_pulse_tween):
		_tutorial_pulse_tween.kill()
	if _tutorial_ring != null:
		_tutorial_ring.scale = Vector2.ONE


## Tüm tutorial'ı atlamak için sağ üstte küçük, göze batmayan bir bağlantı —
## "dokunmaya zorlama" tasarımı erişilebilirlik için hâlâ bir çıkış yolu
## bırakmalı (eski modal-zincirin dışına-tıkla/ESC ile atla desenine eşdeğer).
func _on_tutorial_skip() -> void:
	_tutorial_step_index = -1
	_tutorial_clear_spotlight()
	Game.tutorial_seen = true
	Game.save_game()
	_after_tutorial()


func _build_tutorial_layer() -> void:
	tutorial_layer = Control.new()
	tutorial_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	tutorial_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tutorial_layer.visible = false
	tutorial_layer.z_index = 80
	add_child(tutorial_layer)

	var dim_color := Color(0.05, 0.03, 0.02, 0.72)
	for dim_ref in [&"_tutorial_dim_top", &"_tutorial_dim_bottom", &"_tutorial_dim_left", &"_tutorial_dim_right"]:
		var d := ColorRect.new()
		d.color = dim_color
		d.mouse_filter = Control.MOUSE_FILTER_STOP
		tutorial_layer.add_child(d)
		set(dim_ref, d)

	_tutorial_ring = Panel.new()
	_tutorial_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ring_sb := StyleBoxFlat.new()
	ring_sb.bg_color = Color(0, 0, 0, 0)
	ring_sb.border_color = PALETTE.gold
	ring_sb.set_border_width_all(4)
	ring_sb.set_corner_radius_all(16)
	ring_sb.shadow_color = Color(PALETTE.gold, 0.55)
	ring_sb.shadow_size = 12
	_tutorial_ring.add_theme_stylebox_override("panel", ring_sb)
	tutorial_layer.add_child(_tutorial_ring)

	_tutorial_bubble = _panel(PALETTE.cream, PALETTE.gold)
	_tutorial_bubble.custom_minimum_size = Vector2(320, 0)
	_tutorial_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tutorial_layer.add_child(_tutorial_bubble)
	_tutorial_bubble_label = _label_wrap("", 15, PALETTE.text)
	_tutorial_bubble.add_child(_tutorial_bubble_label)

	var skip_b := _button("Skip tutorial", 12, PALETTE.bar_dark, PALETTE.cream_text)
	skip_b.custom_minimum_size.y = TOUCH_MIN
	skip_b.mouse_filter = Control.MOUSE_FILTER_STOP
	skip_b.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	skip_b.offset_left = -140
	skip_b.offset_right = -12
	skip_b.offset_top = 12
	skip_b.offset_bottom = 40
	skip_b.pressed.connect(_on_tutorial_skip)
	tutorial_layer.add_child(skip_b)


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
		_:
			# Elmas paketleri (tüketilebilir): ödül tam olarak burada verilir —
			# hem oyuncunun az önce yaptığı satın almada hem de yarım kalmış bir
			# satın alma açılışta mağazadan geri geldiğinde aynı yol işler.
			for pack in GEM_PACKS:
				if pack.product == product_id:
					Game.gems += int(pack.gems)
					Game.save_game()
					break


## Ayarlar ▸ Restore purchases'ın sonucu. Hakların kendisi zaten
## _on_purchase_restored'da uygulanıyor; buradaki tek iş oyuncuya ne olduğunu
## söylemek — sessiz kalmak "çalıştı mı?" sorusunu cevapsız bırakırdı.
func _on_restore_finished(count: int) -> void:
	if count < 0:
		_show_toast("The store could not be reached — try again later.")
	elif count == 0:
		_show_toast("No earlier purchases found on this account.")
	else:
		_show_toast("Your purchases were restored.")


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
	if _tutorial_step_index >= 0 and tutorial_layer != null and tutorial_layer.visible:
		_tutorial_reposition_spotlight()
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
	_show_toast(tr("You turned the runaway guest back to the door! +%d coins") % bonus)
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

	# Kök yerleşimin kenar boşluğu YOK (prototip: `left:0; right:0`) — bina ve
	# alt bar ekranın iki kenarına değer. Yan boşluğa ihtiyacı olan parçalar
	# (üst bar, gökyüzü çipleri, inşa rafı) kendi MarginContainer'ını taşır;
	# bkz. _edge_pad.
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 0)
	add_child(margin)

	var root := VBoxContainer.new()
	# Ortak ayırıcı YOK: bina ile alt bar arasında kalan boşluktan gökyüzünün
	# pembe alt ucu sızıyordu ("yeşille bar arasında beyazlık"). Aralar artık
	# tek tek, _edge_pad'in alt kenar boşluğuyla veriliyor.
	root.add_theme_constant_override("separation", 0)
	margin.add_child(root)

	# --- Üst bar (krem panel) — tıklanınca Profil açılır (kullanıcı isteği:
	# "en üstte level para yazan yere tıklayınca profile gitmeli"). Elmas +
	# butonu kendi STOP filtresiyle bu tıklamayı yutar, satın alma popup'ını
	# açar (bkz. _build_gems_popup).
	# Prototipteki yerleşim: krem kart YALNIZCA para/seviye bloğunu sarar,
	# avatar kartın DIŞINDA, gökyüzünün üstünde ayrı bir kutu olarak durur.
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 6)
	# Üstteki ilk parça bu: üst kenar boşluğu çentiğe göre büyüyebilsin diye
	# saklanır (bkz. _apply_safe_area). Sabit 14 artık yalnızca taban.
	top_safe_pad = _edge_pad(root, UI_SAFE_MIN_TOP, 10)
	top_safe_pad.add_child(top_row)
	var top := PanelContainer.new()
	var top_sb := StyleBoxFlat.new()
	top_sb.bg_color = PALETTE.cream
	top_sb.border_color = PALETTE.facade_line
	top_sb.set_border_width_all(2)
	top_sb.set_corner_radius_all(14)
	top_sb.content_margin_left = 10
	top_sb.content_margin_right = 10
	top_sb.content_margin_top = 8
	top_sb.content_margin_bottom = 8
	# Prototipteki `box-shadow: 0 3px 0 rgba(110,79,49,.18)` — yumuşak değil,
	# kaydırılmış düz bir gölge.
	top_sb.shadow_color = Color(0.43, 0.31, 0.19, 0.18)
	top_sb.shadow_size = 0
	top_sb.shadow_offset = Vector2(0, 3)
	top.add_theme_stylebox_override("panel", top_sb)
	top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.mouse_filter = Control.MOUSE_FILTER_STOP
	top.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	top.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_profile_tab = "account"
			_open_popup("Profile", _build_profile_popup))
	top_row.add_child(top)
	var top_box := VBoxContainer.new()
	top_box.add_theme_constant_override("separation", 7)
	top_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(top_box)

	# Profil girişi artık görünür bir hedef (audit 9): resepsiyonist portresi +
	# "Me" hapı. Otel logosu (icon.svg) BİLEREK kullanılmıyor — o otelin kimliği,
	# bu ekranın arkasında ise oyuncunun hesabı var.
	var avatar_b := Button.new()
	avatar_b.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed", "focus"]:
		avatar_b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	avatar_b.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	# Button bir Container DEĞİL: çocuklarını yerleştirmez ve onlardan minimum
	# boy da almaz. Boy elle verilir, içerik butona sabitlenir — yoksa avatar
	# HBox'ta 0 genişlik sayılıp ekranın dışına taşıyor.
	avatar_b.custom_minimum_size = Vector2(80, 118)
	avatar_b.pressed.connect(func():
		_profile_tab = "account"
		_open_popup("Profile", _build_profile_popup))
	top_row.add_child(avatar_b)
	var avatar_col := VBoxContainer.new()
	avatar_col.set_anchors_preset(Control.PRESET_FULL_RECT)
	avatar_col.add_theme_constant_override("separation", 2)
	avatar_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	avatar_b.add_child(avatar_col)
	var avatar_frame := PanelContainer.new()
	var av_sb := StyleBoxFlat.new()
	av_sb.bg_color = PALETTE.cream
	av_sb.border_color = PALETTE.facade_line
	av_sb.set_border_width_all(2)
	av_sb.set_corner_radius_all(26)
	av_sb.set_content_margin_all(6)
	avatar_frame.add_theme_stylebox_override("panel", av_sb)
	avatar_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	avatar_col.add_child(avatar_frame)
	avatar_frame.add_child(_icon("res://assets/guests/receptionist.png", 68))
	var me_wrap := CenterContainer.new()
	me_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	avatar_col.add_child(me_wrap)
	var me_pill := PanelContainer.new()
	var me_sb := StyleBoxFlat.new()
	me_sb.bg_color = PALETTE.cream
	me_sb.set_corner_radius_all(999)
	me_sb.content_margin_left = 14
	me_sb.content_margin_right = 14
	me_sb.content_margin_top = 2
	me_sb.content_margin_bottom = 2
	me_pill.add_theme_stylebox_override("panel", me_sb)
	me_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	me_wrap.add_child(me_pill)
	me_pill.add_child(_label("Me", 9, PALETTE.text, 700))

	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 6)
	top_box.add_child(row1)
	row1.add_child(_icon("res://assets/ui/coin.svg", 38))
	coins_label = _label("", 15, PALETTE.text, 600, true)
	row1.add_child(coins_label)
	# Prototipteki 1 piksellik ayraç — coin ve gem iki ayrı bakiye, aynı blok
	# içinde bile birbirine karışmasın.
	var divider := ColorRect.new()
	divider.color = PALETTE.cream_dark
	divider.custom_minimum_size = Vector2(2, 32)
	divider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row1.add_child(divider)
	row1.add_child(_icon("res://assets/ui/gem.svg", 36))
	gems_label = _label("", 15, PALETTE.green_deep, 600, true)
	row1.add_child(gems_label)
	var gem_add_b := _button("+", 15, PALETTE.green_soft, PALETTE.green_deep)
	gem_add_b.custom_minimum_size = Vector2(52, 52)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var gsb := gem_add_b.get_theme_stylebox(state) as StyleBoxFlat
		gsb.set_corner_radius_all(18)
		gsb.border_color = PALETTE.green_deep
		gsb.set_content_margin_all(0)
	gem_add_b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	gem_add_b.pressed.connect(func():
		_store_tab = "gems"
		_open_popup("Store", _build_store_popup))
	row1.add_child(gem_add_b)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row1.add_child(sp)
	for i in 5:
		var s := _icon("res://assets/ui/star_empty.svg", 26)
		s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		star_icons.append(s)
		row1.add_child(s)

	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 8)
	top_box.add_child(row2)
	level_label = _label("", 11, PALETTE.muted, 600)
	level_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row2.add_child(level_label)
	xp_bar = ProgressBar.new()
	xp_bar.show_percentage = false
	xp_bar.custom_minimum_size = Vector2(0, 12)
	xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var xb := StyleBoxFlat.new()
	xb.bg_color = PALETTE.cream_dark
	xb.border_color = PALETTE.facade_line
	xb.set_border_width_all(1)
	xb.set_corner_radius_all(999)
	xp_bar.add_theme_stylebox_override("background", xb)
	var xf := StyleBoxFlat.new()
	xf.bg_color = PALETTE.gold
	xf.set_corner_radius_all(999)
	xp_bar.add_theme_stylebox_override("fill", xf)
	row2.add_child(xp_bar)
	# Prototipteki "220 / 1,000 XP" sayacı — çubuk tek başına ne kadar kaldığını
	# söylemiyordu.
	xp_text_label = _label("", 10, PALETTE.muted, 600)
	row2.add_child(xp_text_label)

	# --- Gökyüzü durum çipi: bina üstündeki boş gökyüzü artık vardiya durumunu
	# taşıyor (audit 14). Eski COLLECT barı buradan kalktı — tek birincil buton
	# alt barın ortasına taşındı (bkz. collect_button aşağıda).
	var status_wrap := CenterContainer.new()
	_edge_pad(root, 0, 10).add_child(status_wrap)
	# Prototipteki gökyüzü hapı: yarı saydam koyu zemin, kenar yok, tam yuvarlak
	# uçlar. Saat ikonu çipi bir bakışta "zaman" olarak okutuyor.
	var status_chip := _chip(PALETTE.chip_dark)
	# Çip Shift sayfasının İKİNCİ girişi: merkez buton biriken para varken
	# "Collect"e döndüğü için tek başına vardiyayı bitirmeye ("Finish now")
	# ulaştırmıyordu. Durumu zaten yazan çip doğal hedef.
	status_chip.mouse_filter = Control.MOUSE_FILTER_STOP
	status_chip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	status_chip.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_tutorial_advance_on("shift_tap")
			_open_popup("Shift", _build_shift_popup))
	status_wrap.add_child(status_chip)
	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 7)
	status_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_chip.add_child(status_row)
	var clock_icon := _icon("res://assets/ui/icon_clock.svg", 28)
	clock_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	status_row.add_child(clock_icon)
	shift_label = _label("", 11, PALETTE.cream_text, 600)
	shift_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shift_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	status_row.add_child(shift_label)
	# Dokunulabilir olduğunu gösteren chevron — çip aksi hâlde salt bilgi gibi
	# okunuyor.
	var status_arrow := _label("›", 13, PALETTE.gold_soft, 700)
	status_arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	status_row.add_child(status_arrow)

	# --- Otel görünümü: çatı tabelası (sabit) + zoom kontrolleri (sabit) +
	# zoom/pan alan tuval (kat sıraları + lobi + sokak + çim, serbest blok
	# yerleşimi — kat genişlikleri farklı olabildiği için artık HBoxContainer
	# satırları yerine manuel konumlandırılmış tek bir Control tuval).
	# Tema çipi ve inşa aracı aynı satırda, zoom kontrollerinin yanında: eski
	# tam genişlik "Theme of the week" barı ve "Shop" sekmesinin Build Mode
	# toggle'ı kalktı, ikisi de canvas üstü birer çipe indi.
	var zoom_row := HBoxContainer.new()
	zoom_row.add_theme_constant_override("separation", 6)
	_edge_pad(root, 0, 10).add_child(zoom_row)
	# ✎ Build ve haftanın teması: prototipte ikisi de gökyüzü hapı — Build koyu
	# yarı saydam (durum çipinden koyu; prototipin .66'sı kullanıcı geri
	# bildirimiyle .78'e çıktı), tema hapı sabit kırmızı.
	build_mode_button = _chip_toggle("✎ Build")
	build_mode_button.toggled.connect(func(on: bool): _set_build_mode(on))
	zoom_row.add_child(build_mode_button)
	# Temizlik Modu çipi İnşa Modunun yanında: ikisi de aynı türden tuval modu,
	# oyuncu ikisinden de aynı yerden çıkıyor.
	clean_mode_button = _chip_toggle("🧹 Clean")
	clean_mode_button.toggled.connect(func(on: bool): _set_clean_mode(on))
	zoom_row.add_child(clean_mode_button)
	roof_panel = _chip(Color(PALETTE.banner_red, 0.9))
	zoom_row.add_child(roof_panel)
	roof_theme_label = _label("", 11, PALETTE.cream)
	roof_theme_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	roof_panel.add_child(roof_theme_label)
	var zoom_row_spacer := Control.new()
	zoom_row_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	zoom_row.add_child(zoom_row_spacer)
	# The zoom cluster is a canvas tool, not a menu control: at the full 88 it
	# dwarfed the top bar, so it keeps the chrome size and stays in one row.
	var zoom_cluster := HBoxContainer.new()
	zoom_cluster.add_theme_constant_override("separation", 6)
	zoom_cluster.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	zoom_row.add_child(zoom_cluster)
	var zoom_out_b := _button("−", 18, PALETTE.wood, PALETTE.cream_text)
	zoom_out_b.custom_minimum_size = Vector2(56, 56)
	zoom_out_b.pressed.connect(func(): _zoom_by(-ZOOM_STEP, zoom_viewport.size / 2.0))
	zoom_cluster.add_child(zoom_out_b)
	var zoom_reset_b := _button("⟳", 16, PALETTE.wood, PALETTE.cream_text)
	zoom_reset_b.custom_minimum_size = Vector2(56, 56)
	zoom_reset_b.pressed.connect(func():
		_zoom = _default_zoom()
		_canvas_pan = Vector2.ZERO
		_clamp_pan()
		_apply_canvas_transform())
	zoom_cluster.add_child(zoom_reset_b)
	var zoom_in_b := _button("+", 18, PALETTE.wood, PALETTE.cream_text)
	zoom_in_b.custom_minimum_size = Vector2(56, 56)
	zoom_in_b.pressed.connect(func(): _zoom_by(ZOOM_STEP, zoom_viewport.size / 2.0))
	zoom_cluster.add_child(zoom_in_b)

	# İnşa Modu mağaza rafı: yalnızca build_mode açıkken görünür (bkz.
	# _rebuild_hotel). Oda kartları buradan tuvale sürüklenir — tıklayınca
	# açılan liste yerine Hotel City'deki gibi "mağazadan seç, sürükle" akışı.
	# Raf kendi kenar boşluğunu taşır (kök yerleşim kenardan kenara): görünürlük
	# sarmalayıcının kendisinde, yoksa gizliyken bile kök VBox'ta boşluk bırakır.
	build_shop_panel = _edge_pad(root, 0, 6)
	build_shop_panel.visible = false
	var build_shop_col := VBoxContainer.new()
	build_shop_col.add_theme_constant_override("separation", 2)
	build_shop_panel.add_child(build_shop_col)
	build_shop_col.add_child(_label("Room Shop — drag and drop onto the building", 12, PALETTE.wood_dark))
	var build_shop_scroll := ScrollContainer.new()
	build_shop_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	build_shop_scroll.custom_minimum_size = Vector2(0, 112)
	build_shop_col.add_child(build_shop_scroll)
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

	# "Yeni kat aç" barı kalktı: yuvarlak birincil butonun altında kalıyordu ve
	# aynı işlem artık Build sekmesinde duruyor (bkz. _build_build_popup).

	# --- Birincil buton: tek durum makinesi. Vardiya yokken "Start shift"
	# (Shift popup'ını açar), vardiya varken "Collect" + biriken tutar. Eski
	# COLLECT barı ve Shift sekmesinin ikisinin de yerini tutar. Alt barın
	# İÇİNDE, Staff ile Quests arasında, diğer sekmelerle aynı hizada durur.
	# Görsel iki katman (prototip: radial gradient + `0 6px 0 #96311f`):
	#   1. StyleBoxFlat = yalnızca sert alt gölge. Zemin tamamen koyu kırmızı,
	#      daire 120 piksel (köşe yarıçapı 60).
	#   2. Üstüne 6 piksel YUKARIDA duran, alfası dairede biten radial
	#      GradientTexture2D. StyleBoxFlat radial gradient veremiyor; dokunun
	#      son durağı saydam olduğu için kare doku daire gibi görünüyor.
	collect_button = _button("", 15, PALETTE.red_lip, PALETTE.cream_text)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var sb: StyleBoxFlat = collect_button.get_theme_stylebox(state)
		sb.bg_color = PALETTE.red_lip
		sb.set_corner_radius_all(92)
		sb.set_border_width_all(0)
		sb.shadow_size = 0
	var primary_grad := Gradient.new()
	primary_grad.offsets = PackedFloat32Array([0.0, 0.55, 0.97, 1.0])
	primary_grad.colors = PackedColorArray([
		PALETTE.banner_red.lightened(0.22), PALETTE.banner_red,
		PALETTE.banner_red.darkened(0.18), Color(PALETTE.banner_red.darkened(0.18), 0.0),
	])
	var primary_tex := GradientTexture2D.new()
	primary_tex.gradient = primary_grad
	primary_tex.fill = GradientTexture2D.FILL_RADIAL
	primary_tex.fill_from = Vector2(0.5, 0.5)
	primary_tex.fill_to = Vector2(1.0, 0.5)
	primary_tex.width = 184
	primary_tex.height = 184
	var primary_face := TextureRect.new()
	primary_face.texture = primary_tex
	primary_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	primary_face.stretch_mode = TextureRect.STRETCH_SCALE
	primary_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	primary_face.set_anchors_preset(Control.PRESET_FULL_RECT)
	primary_face.offset_bottom = -6
	collect_button.add_child(primary_face)
	var primary_col := VBoxContainer.new()
	primary_col.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Etiketler de gölge şeridinin üstünde kalsın, dairenin ortasında dursun.
	primary_col.offset_bottom = -6
	primary_col.alignment = BoxContainer.ALIGNMENT_CENTER
	primary_col.add_theme_constant_override("separation", 0)
	primary_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	collect_button.add_child(primary_col)
	primary_label = _label("", 15, PALETTE.cream_text, 700)
	primary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	primary_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	primary_col.add_child(primary_label)
	# Alt satır: vardiya kalan süresi / biriken tutar (eski shift_bar_label).
	shift_bar_label = _label("", 10, PALETTE.gold_soft, 600)
	shift_bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shift_bar_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	primary_col.add_child(shift_bar_label)
	collect_button.pressed.connect(_on_primary_pressed)
	# Tutorial'ın "vardiya başlat" adımı da artık bu butonu işaret ediyor.
	shift_button = collect_button

	# --- Alt bar: koyu şerit üzerinde ikonlu kategoriler (Hotel City tarzı)
	# Prototipte şerit köşesiz ve altın kenarsız: düz #3a2c4d zemin, yalnızca
	# 3 piksellik koyu üst kenar. Ekranın iki kenarına değdiği için yuvarlak
	# köşe zaten kesik görünüyordu.
	var bar_panel := PanelContainer.new()
	var bar_sb := StyleBoxFlat.new()
	bar_sb.bg_color = PALETTE.bar_dark
	bar_sb.set_corner_radius_all(0)
	bar_sb.border_color = PALETTE.bar_edge
	bar_sb.border_width_top = 3
	bar_sb.set_content_margin_all(4)
	bar_panel.add_theme_stylebox_override("panel", bar_sb)
	root.add_child(bar_panel)
	# Şerit kenardan kenara, karolar değil: yuvarlatılmış ekran köşeleri en
	# dıştaki iki karoyu (Build ve Store) kesiyordu. Kenar boşluğu güvenli
	# alandan okunur, tabanı UI_SAFE_MIN_* sabitleri belirler (bkz. _apply_safe_area).
	bar_safe_pad = MarginContainer.new()
	bar_panel.add_child(bar_safe_pad)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 6)
	bar_safe_pad.add_child(bottom)

	# Dört sekme: coin harcanan her şey Build'de, gem/gerçek para harcanan her
	# şey Store'da. Shift sekmesi kalktı (merkez butona döndü), Settings
	# sekmesi kalktı (Profile ▸ ⚙ Settings'e indi, audit 10-11).
	for def in [
		["res://assets/ui/wall_block.svg", "Build", _build_build_popup],
		["res://assets/ui/broom.svg", "Staff", _build_staff_popup],
		["res://assets/ui/icon_quest.svg", "Quests", _build_quests_popup],
		["res://assets/ui/gem.svg", "Store", _build_store_popup],
	]:
		var b := _bar_button(def[0], def[1])
		var builder: Callable = def[2]
		var title: String = def[1]
		b.pressed.connect(func():
			if title == "Quests":
				_tutorial_advance_on("quest_tap")
			if title == "Store":
				_store_tab = "gems"
			_open_popup(title, builder))
		# Birincil buton barın ortasında: Staff ile Quests arasında, yuvarlak
		# kırmızı buton barın üst kenarına biner (prototip). Burada yalnızca
		# yerini tutan boşluk var, butonun kendisi ekran köküne asılı.
		if title == "Quests":
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(232, 0)
			bottom.add_child(gap)
		bottom.add_child(b)
		_bar_buttons[title] = b
		if title == "Quests":
			quest_bar_button = b
			# Görülmemiş tamamlama varsa kırmızı rozet (prototipteki "1").
			# _panel'in 12 piksellik iç boşluğu rozeti dikey ovale çeviriyordu;
			# rozet kendi tam yuvarlak stiliyle kuruluyor.
			quest_badge = PanelContainer.new()
			var badge_sb := StyleBoxFlat.new()
			badge_sb.bg_color = PALETTE.banner_red
			badge_sb.border_color = PALETTE.cream
			badge_sb.set_border_width_all(2)
			badge_sb.set_corner_radius_all(999)
			badge_sb.set_content_margin_all(2)
			quest_badge.add_theme_stylebox_override("panel", badge_sb)
			quest_badge.visible = false
			quest_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			# Rozet karonun sağ üst köşesine oturur — buton karodan çok daha
			# geniş olduğu için sağ üst köşesine asılınca ikondan kopuyordu.
			quest_badge.set_anchors_preset(Control.PRESET_CENTER_TOP)
			quest_badge.offset_left = 12
			quest_badge.offset_top = 2
			quest_badge.offset_right = 40
			quest_badge.offset_bottom = 30
			b.add_child(quest_badge)
			# Prototipte rozet bir SAYI taşıyor (`t.badge`), sabit "!" değil —
			# metni _update_bar_active tazeler.
			quest_badge_label = _label("", 12, PALETTE.cream_text)
			quest_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			quest_badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			quest_badge.add_child(quest_badge_label)

	# Birincil buton yerleşimin DIŞINDA, ekran köküne asılı: alt barın orta
	# boşluğuna oturur ve barın üst kenarına biner (prototipteki yuvarlak
	# kırmızı buton). Bar 104 yüksekliğinde ve ekranın en altına oturuyor (kök
	# kenar boşluğu kalktı); ofsetler bunun üzerinden veriliyor.
	collect_button.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	collect_button.offset_left = -92
	collect_button.offset_right = 92
	collect_button.offset_top = -190
	collect_button.offset_bottom = -6
	collect_button.grow_horizontal = Control.GROW_DIRECTION_BOTH
	collect_button.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(collect_button)

	# --- Menü katmanı: prototipteki gibi TAM EKRAN sayfa, ortalanmış kutu değil
	# (bkz. prototipin `sheetOpen` bloğu: position:absolute; inset:0; z-index:6).
	# Karartma ve "dışına dokununca kapanır" davranışı YOK — dışarısı diye bir
	# yer kalmıyor. Alt bar da örtülür: overlay collect_button'dan sonra
	# eklendiği için ağaçta en üstte.
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	# Ağaçta sonra gelmek YETMİYOR: yürüyen misafirler `_walker_layer.z_index =
	# 50` ile çiziliyor ve varsayılan z_index'li bir sayfanın üstüne taşıyordu
	# (menüdeyken sokaktaki insanlar listenin üstünde yürüyor görünüyordu).
	overlay.z_index = 100
	add_child(overlay)
	# Zemin: krem, köşesiz, tam ekran. MOUSE_FILTER_STOP — altındaki oyuna
	# dokunuş sızmasın.
	var sheet_bg := ColorRect.new()
	sheet_bg.color = PALETTE.cream
	sheet_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	sheet_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(sheet_bg)
	var pv := VBoxContainer.new()
	pv.set_anchors_preset(Control.PRESET_FULL_RECT)
	pv.add_theme_constant_override("separation", 0)
	overlay.add_child(pv)

	# Başlık şeridi (prototip): koyu plum bant, ekranın tam genişliği, köşesiz.
	# Solda ‹ (bir seviye geri; kökteyken kapatır), ortada başlık, sağda güncel
	# para göstergesi ve ✕. ✕ Android geri tuşuna bağımlı kalmamak için HER
	# ZAMAN görünür — kullanıcı isteği.
	var head_panel := PanelContainer.new()
	var head_sb := StyleBoxFlat.new()
	head_sb.bg_color = PALETTE.bar_dark
	head_sb.set_content_margin_all(10)
	head_panel.add_theme_stylebox_override("panel", head_sb)
	pv.add_child(head_panel)
	# Bant kenardan kenara kalır; ‹ ve ✕ çentiğin ve köşe yayının dışına
	# bu boşlukla çıkar (bkz. _apply_safe_area).
	popup_head_pad = MarginContainer.new()
	head_panel.add_child(popup_head_pad)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	popup_head_pad.add_child(head)
	popup_back_button = _button("‹", 20, PALETTE.wood, PALETTE.cream_text)
	popup_back_button.custom_minimum_size = Vector2(TOUCH_MIN_CHROME, TOUCH_MIN_CHROME)
	for state in ["normal", "hover", "pressed"]:
		(popup_back_button.get_theme_stylebox(state) as StyleBoxFlat).set_corner_radius_all(TOUCH_MIN_CHROME / 2)
	popup_back_button.pressed.connect(_pop_popup)
	head.add_child(popup_back_button)
	popup_title = _label("", 16, PALETTE.cream_text, 700)
	popup_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	popup_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(popup_title)
	head.add_child(_icon("res://assets/ui/coin.svg", 32))
	popup_coins_label = _label("", 13, PALETTE.cream_text, 600, true)
	popup_coins_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(popup_coins_label)
	head.add_child(_icon("res://assets/ui/gem.svg", 30))
	popup_gems_label = _label("", 13, PALETTE.cream_text, 600, true)
	popup_gems_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(popup_gems_label)
	var close_b := _button("✕", 16, PALETTE.wood, PALETTE.cream_text)
	close_b.custom_minimum_size = Vector2(TOUCH_MIN_CHROME, TOUCH_MIN_CHROME)
	for state in ["normal", "hover", "pressed"]:
		(close_b.get_theme_stylebox(state) as StyleBoxFlat).set_corner_radius_all(TOUCH_MIN_CHROME / 2)
	close_b.pressed.connect(_close_popup)
	head.add_child(close_b)
	popup_scroll = ScrollContainer.new()
	# Başlık şeridinin altında kalan TÜM alan (prototip: flex:1; overflow:auto).
	popup_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Yatay kaydırma kapalı: içerik ekran genişliğine sarsın, yana kaymasın.
	popup_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# Parmak kart ÜSTÜNDEN de kaydırabilsin diye (bkz. MOUSE_PASSTHROUGH).
	popup_scroll.scroll_deadzone = SCROLL_DEADZONE
	pv.add_child(popup_scroll)
	# Yanlar ve alt _apply_safe_area'dan gelir (sona kadar kaydırılan listenin
	# son satırı köşeye girmesin); üst boşluk başlık şeridinin altında kaldığı
	# için sabit.
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 12)
	popup_pad = pad
	popup_scroll.add_child(pad)
	popup_content = VBoxContainer.new()
	popup_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Kart araları (bkz. _card): kartlar arasındaki boşluk kart içi satır
	# boşluğundan (6) belirgin biçimde büyük olmalı ki gruplar ayrışsın.
	popup_content.add_theme_constant_override("separation", 10)
	pad.add_child(popup_content)

	# --- Toast: alt barın üstünde yüzer, yerleşimi itmez; popup'ların da üstünde.
	# Prototipteki biçim: koyu (#2f2418) tam yuvarlak hap + yumuşak gölge,
	# içeriğe göre daralır. Eski hâli yeşil, altın kenarlı, neredeyse tam
	# genişlikte bir paneldi.
	var toast_wrap := CenterContainer.new()
	toast_wrap.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	toast_wrap.offset_left = 40
	toast_wrap.offset_right = -40
	# Barın (104) ve onun üstüne binen yuvarlak butonun (tepesi -174) ikisinin de
	# ÜSTÜNDE kalır — hiçbirine binmez (audit 15).
	toast_wrap.offset_top = -274
	toast_wrap.offset_bottom = -202
	toast_wrap.grow_vertical = Control.GROW_DIRECTION_BEGIN
	toast_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Menü sayfasının (z_index 100) da üstünde — bkz. oradaki not.
	toast_wrap.z_index = 110
	add_child(toast_wrap)
	toast_panel = PanelContainer.new()
	var toast_sb := StyleBoxFlat.new()
	toast_sb.bg_color = PALETTE.frame
	toast_sb.set_corner_radius_all(999)
	toast_sb.content_margin_left = 20
	toast_sb.content_margin_right = 20
	toast_sb.content_margin_top = 11
	toast_sb.content_margin_bottom = 11
	toast_sb.shadow_color = Color(0.1, 0.06, 0.02, 0.28)
	toast_sb.shadow_size = 10
	toast_sb.shadow_offset = Vector2(0, 4)
	toast_panel.add_theme_stylebox_override("panel", toast_sb)
	toast_panel.visible = false
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_wrap.add_child(toast_panel)
	toast_label = _label("", 15, PALETTE.cream_text)
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_panel.add_child(toast_label)

	_build_tutorial_layer()
	_build_start_screen()

	# Kenara değen parçaların hepsi kurulduktan sonra, tek seferde dağıt.
	# Döndürme/yeniden boyutlandırma güvenli alanı değiştirir, o yüzden bağlı.
	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)


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
	var version_label := _label("v%s" % GAME_VERSION, 11, PALETTE.muted)
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


## Gökyüzü çipi: prototipteki tam yuvarlak uçlu hap (durum satırı, ✎ Build,
## haftanın teması). Kenarlığı yok — zemin rengi yarı saydam.
func _chip(bg: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(999)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return p


## Gökyüzündeki tuval modu çipi (✎ Build, 🧹 Clean): hap biçimli, kenarsız,
## yarı saydam koyu zemin — _chip() ile aynı dil, ama tıklanabilir/toggle.
func _chip_toggle(text: String) -> Button:
	var b := _button(text, 11, Color(PALETTE.chip_dark, 0.78), PALETTE.cream_text)
	b.custom_minimum_size.y = 56
	b.toggle_mode = true
	for state in ["normal", "hover", "pressed", "disabled"]:
		var sb := b.get_theme_stylebox(state) as StyleBoxFlat
		sb.set_corner_radius_all(999)
		sb.set_border_width_all(0)
		sb.content_margin_left = 22
		sb.content_margin_right = 22
		sb.content_margin_top = 12
		sb.content_margin_bottom = 12
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return b


## İki tuval modu birbirini dışlar: tuvalde aynı dokunuşun iki farklı anlamı
## olmasın (boş bloğa oda koymak / kirli odayı temizlemek).
func _set_build_mode(on: bool) -> void:
	if build_mode == on and build_mode_button.button_pressed == on:
		return
	if on:
		_set_clean_mode(false)
	build_mode = on
	build_mode_button.button_pressed = on
	build_mode_button.text = tr("✎ Build: On") if on else tr("✎ Build")
	_rebuild_hotel()


func _set_clean_mode(on: bool) -> void:
	if clean_mode == on and clean_mode_button.button_pressed == on:
		return
	if on:
		_set_build_mode(false)
	clean_mode = on
	clean_mode_button.button_pressed = on
	clean_mode_button.text = tr("🧹 Clean: On") if on else tr("🧹 Clean")
	_rebuild_hotel()
	if on:
		var dirty := _dirty_room_count()
		if dirty > 0:
			_show_toast(tr("Cleaning mode on — tap the %s to clean.") % _count(dirty, "dirty room"))
		else:
			_show_toast("Cleaning mode on — no dirty rooms right now.")


func _dirty_room_count() -> int:
	var n := 0
	for r in Game.rooms:
		if r.dirty:
			n += 1
	return n


func _panel(bg: Color, border: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := _card_sb(bg, border, 18, 0.14)
	sb.set_content_margin_all(12)
	p.add_theme_stylebox_override("panel", sb)
	return p


## Menü sayfası içindeki kart: prototipteki beyaz blok — 12 piksel yuvarlak
## köşe, 2 piksel `facade_line` kenar (`border:2px solid #e6b866`), gölgesiz.
## Sayfa gövdeleri düz bir satır listesi değil, her mantıksal grup kendi
## kartına girer. Dönen VBoxContainer içeriğin ekleneceği kaptır.
func _card(c: VBoxContainer, border: Color = PALETTE.facade_line) -> VBoxContainer:
	var p := PanelContainer.new()
	p.mouse_filter = MOUSE_PASSTHROUGH
	var sb := StyleBoxFlat.new()
	sb.bg_color = PALETTE.card
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(11)
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	return v


## Bölüm etiketi: prototipte başlık kartın İÇİNDE değil, satır grubunun
## ÜSTÜNDE duran küçük büyük harf metin (`text-transform:uppercase`).
func _section(c: VBoxContainer, title: String, tint: Color = PALETTE.muted) -> void:
	# tr() first, upper-case after: the key is the untouched English string.
	c.add_child(_label(_to_upper(tr(title)), 11, tint))


## String.to_upper() is locale-agnostic, so Turkish loses its dotted capital:
## "tehlikeli" would become "TEHLIKELI" instead of "TEHLİKELİ", which reads as
## a typo to a Turkish player. Only the two dotted/dotless pairs differ.
func _to_upper(s: String) -> String:
	if TranslationServer.get_locale().begins_with("tr"):
		return s.replace("i", "İ").replace("ı", "I").to_upper()
	return s.to_upper()


## Prototipin satır primitifi. Beyaz liste satırı, kahverengi birincil buton ve
## tehlike butonu — hepsi aynı iskelet: solda ikon, ortada ad + açıklama, sağda
## fiyat/rozet, tıklanabilir.
##
## Godot'da `Button` kendi çocuklarından minimum boy ALMAZ, bu yüzden görünen
## kutu bir `PanelContainer`, tıklama ise onun üstüne serilen şeffaf bir
## `Button`. `PanelContainer` her çocuğu aynı içerik dikdörtgenine yerleştirdiği
## için buton tam olarak satırı kaplar.
##
## cfg anahtarları (hepsi isteğe bağlı): bg, border, radius, icon, icon_px,
## title, title_size, title_color, meta, meta_color, right, right_color,
## pill_bg, pill_border, enabled.
func _sheet_row(c: VBoxContainer, cfg: Dictionary) -> Button:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = cfg.get("bg", PALETTE.card)
	sb.border_color = cfg.get("border", PALETTE.facade_line)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(int(cfg.get("radius", 12)) * 2)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 20
	sb.content_margin_bottom = 20
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = MOUSE_PASSTHROUGH
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.custom_minimum_size.y = TOUCH_MIN
	var enabled: bool = bool(cfg.get("enabled", true))
	if not enabled:
		# Prototipteki kilitli satır: `opacity:.5`.
		p.modulate.a = 0.5
	c.add_child(p)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 11)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(h)
	var icon_path: String = String(cfg.get("icon", ""))
	var badge_text: String = String(cfg.get("badge", ""))
	if badge_text != "":
		# Tasarımdaki vardiya bloğunun baş harfi: 38x38 krem kare, altın kenar,
		# içinde kısa etiket ("4s"). İkonun yerini alır.
		h.add_child(_row_badge(badge_text))
	elif icon_path != "":
		var ic := _icon(icon_path, int(cfg.get("icon_px", 34)))
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(ic)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_theme_constant_override("separation", 1)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(col)
	var title_l := _label_wrap(String(cfg.get("title", "")),
		int(cfg.get("title_size", 14)), cfg.get("title_color", PALETTE.text), 700)
	col.add_child(title_l)
	var meta_l := _label_wrap(String(cfg.get("meta", "")), 11, cfg.get("meta_color", PALETTE.muted))
	meta_l.visible = String(cfg.get("meta", "")) != ""
	col.add_child(meta_l)

	var right: String = String(cfg.get("right", ""))
	if right != "":
		var pill_bg: Color = cfg.get("pill_bg", Color(0, 0, 0, 0))
		var right_l := _label(right, 12, cfg.get("right_color", PALETTE.wood), 700)
		right_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if pill_bg.a > 0.0:
			# Gerçek para / gem fiyatı: prototipte yeşil hap içinde.
			var pill := PanelContainer.new()
			var psb := StyleBoxFlat.new()
			psb.bg_color = pill_bg
			var pill_border: Color = cfg.get("pill_border", Color(0, 0, 0, 0))
			if pill_border.a > 0.0:
				psb.border_color = pill_border
				psb.set_border_width_all(2)
			psb.set_corner_radius_all(20)
			psb.content_margin_left = 24
			psb.content_margin_right = 24
			psb.content_margin_top = 16
			psb.content_margin_bottom = 16
			pill.add_theme_stylebox_override("panel", psb)
			pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
			pill.add_child(right_l)
			h.add_child(pill)
		else:
			h.add_child(right_l)

	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = MOUSE_SCROLLABLE
	b.disabled = not enabled
	# Butonun kendi çizimi yok: görünen her şey alttaki panelden geliyor.
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	# Metni sonradan değiştiren çağıranlar için (iki adımlı "emin misin?"
	# onayları) etiketlere meta üzerinden erişilir — bkz. _row_set.
	b.set_meta("title_label", title_l)
	b.set_meta("meta_label", meta_l)
	b.set_meta("panel", p)
	p.add_child(b)
	return b


## _sheet_row'un baş rozeti (bkz. cfg.badge): kare krem kutu, altın kenar,
## ortalanmış kısa metin. Tasarımda süre/adet gibi tek bakışta okunan değerler
## ikon yerine burada duruyor.
func _row_badge(text: String) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PALETTE.pill_cream
	sb.border_color = PALETTE.gold
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(18)
	sb.set_content_margin_all(8)
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(60, 60)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := _label(text, 11, PALETTE.wood, 700)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p


## _sheet_row ile kurulan bir satırın metinlerini sonradan değiştirir
## (iki adımlı onaylar: "Are you sure? Tap again").
func _row_set(b: Button, title: String, meta: String = "") -> void:
	var title_l: Label = b.get_meta("title_label")
	title_l.text = title
	var meta_l: Label = b.get_meta("meta_label")
	meta_l.text = meta
	meta_l.visible = meta != ""


## Beyaz liste satırı — prototipin varsayılan biçimi.
func _row(c: VBoxContainer, icon_path: String, title: String, meta: String,
		right: String = "", enabled: bool = true,
		right_color: Color = PALETTE.wood) -> Button:
	return _sheet_row(c, {
		"icon": icon_path, "title": title, "meta": meta, "right": right,
		"right_color": right_color, "enabled": enabled,
	})


## Gerçek para / gem ile satılan satır: sağdaki fiyat, tasarımdaki krem zeminli
## altın kenarlı hapın içinde. Dolu yeşil hap oyunun geri kalanında "kazanç"
## rengi olduğu için mağaza fiyatlarında kullanılmıyor.
func _buy_row(c: VBoxContainer, icon_path: String, title: String, meta: String,
		price: String, enabled: bool = true) -> Button:
	return _sheet_row(c, {
		"icon": icon_path, "title": title, "meta": meta, "right": price,
		"right_color": PALETTE.text, "pill_bg": PALETTE.pill_cream,
		"pill_border": PALETTE.gold, "enabled": enabled,
	})


## Birincil eylem: prototipteki sola hizalı kahverengi buton (başlık krem,
## alt satır soluk krem).
func _action(c: VBoxContainer, title: String, sub: String = "",
		enabled: bool = true, kind: String = "outline") -> Button:
	var col := _menu_btn_colors(kind)
	return _sheet_row(c, {
		"bg": col.bg, "border": col.border, "radius": 12,
		"title": title, "title_size": 14, "title_color": col.fg,
		"meta": sub, "meta_color": col.meta, "enabled": enabled,
	})


## Tehlike eylemi. `solid` true: dolu kırmızı (veri silme). false: yumuşak
## kırmızı zemin + kırmızı metin (kaydı sıfırlama) — prototipteki ayrım.
func _danger(c: VBoxContainer, title: String, sub: String = "", solid: bool = false) -> Button:
	if solid:
		return _sheet_row(c, {
			"bg": PALETTE.banner_red, "border": PALETTE.banner_red.darkened(0.2),
			"radius": 12, "title": title, "title_size": 14,
			"title_color": PALETTE.cream, "meta": sub, "meta_color": PALETTE.red_soft,
		})
	return _action(c, title, sub, true, "danger")


## Bilgi/uyarı kutusu. kind: "gold" (vurgu), "warn" (kırmızı), "dark" (plum).
func _notice(c: VBoxContainer, text: String, kind: String = "gold") -> void:
	var bg := PALETTE.gold_notice
	var border := PALETTE.gold
	var fg := PALETTE.text
	match kind:
		"warn":
			bg = PALETTE.red_soft
			border = PALETTE.banner_red
			fg = PALETTE.red_text
		"dark":
			bg = PALETTE.bar_dark
			border = PALETTE.bar_dark
			fg = PALETTE.plum_text
	var p := PanelContainer.new()
	p.mouse_filter = MOUSE_PASSTHROUGH
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 11
	sb.content_margin_right = 11
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.add_child(p)
	p.add_child(_label_wrap(text, 12, fg))


## Prototipin gruplu listesi: tek beyaz kutu, satırlar arasında 1 piksel
## `cream_dark` çizgi (Ayarlar bağlantıları, istatistik tablosu). Dönen kaba
## satırlar _list_row ile eklenir.
func _list_card(c: VBoxContainer) -> VBoxContainer:
	var p := PanelContainer.new()
	p.mouse_filter = MOUSE_PASSTHROUGH
	var sb := StyleBoxFlat.new()
	sb.bg_color = PALETTE.card
	sb.border_color = PALETTE.facade_line
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(0)
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	p.add_child(v)
	return v


## _list_card içindeki tek satır: solda etiket, sağda değer ya da `›` işareti.
## `pressable` true ise satırın üstüne şeffaf buton serilir ve o döner.
func _list_row(v: VBoxContainer, label: String, right: String,
		pressable: bool = false, right_color: Color = PALETTE.wood_dark) -> Button:
	if v.get_child_count() > 0:
		var line := ColorRect.new()
		line.color = PALETTE.cream_dark
		line.mouse_filter = MOUSE_PASSTHROUGH
		line.custom_minimum_size = Vector2(0, 1)
		v.add_child(line)
	var p := PanelContainer.new()
	p.mouse_filter = MOUSE_PASSTHROUGH
	var sb := StyleBoxEmpty.new()
	sb.set_content_margin_all(12)
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(p)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 9)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(h)
	var l := _label_wrap(label, 12, PALETTE.text)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	var r := _label(right, 12, right_color)
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(r)
	if not pressable:
		return null
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = MOUSE_SCROLLABLE
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	p.add_child(b)
	return b


## Prototipteki ince ilerleme çubuğu (9 piksel, tam yuvarlak uçlar).
func _bar(c: VBoxContainer, ratio: float, fill: Color = PALETTE.gold) -> void:
	var pb := ProgressBar.new()
	pb.mouse_filter = MOUSE_PASSTHROUGH
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(0, 9)
	pb.max_value = 1.0
	pb.value = clampf(ratio, 0.0, 1.0)
	var bg := StyleBoxFlat.new()
	bg.bg_color = PALETTE.cream_dark
	bg.set_corner_radius_all(5)
	pb.add_theme_stylebox_override("background", bg)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	fg.set_corner_radius_all(5)
	pb.add_theme_stylebox_override("fill", fg)
	c.add_child(pb)


## Verilen metin `max_w` piksele sığana kadar font boyutunu `base_size`'dan
## `min_size`'a kadar küçültür — oda plaketlerinde metin taşmasın diye.
func _fit_font_size(text: String, max_w: float, base_size: int, min_size: int,
		weight := 500) -> int:
	# Ölçüm, etiketin GERÇEKTEN çizeceği fontla yapılmalı: fallback_font ile
	# ölçmek Figtree'ye geçtikten sonra sistematik olarak yanlış genişlik verir.
	var font: Font = _font(weight)
	for size in range(base_size, min_size - 1, -1):
		var sz := roundi(size * UI_TEXT_SCALE)
		if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x <= max_w:
			return size
	return min_size


## One FontVariation per weight, built once and shared — a Label only needs the
## resource, and rebuilding them per label would allocate on every popup.
var _font_cache := {}
## variation_opentype is keyed by the OpenType tag as an INT, not by name: with
## a "wght" string key the axis is silently ignored and every label renders at
## the file's default instance — which for Figtree is Light 300, far thinner
## than the 500-700 the design uses.
@onready var _wght_tag: int = TextServerManager.get_primary_interface().name_to_tag("wght")


func _font(weight: int, numeric := false) -> FontVariation:
	var key := weight + (10000 if numeric else 0)
	if not _font_cache.has(key):
		var fv := FontVariation.new()
		fv.base_font = FONT_NUM if numeric else FONT_UI
		fv.variation_opentype = {_wght_tag: weight}
		_font_cache[key] = fv
	return _font_cache[key]


## `weight` follows the design's CSS: 400 body, 500 meta, 600 labels, 700
## titles. `numeric` swaps in Pixelify Sans, which the design uses for the coin
## and gem counters only.
func _label(text: String, size: int, color: Color, weight := 500,
		numeric := false) -> Label:
	var l := Label.new()
	# Deliberately NOT tr(): Godot auto-translates Label.text on display and
	# re-translates it when the locale changes, so the node must keep the
	# English key. Strings already built with `%` are not keys and are wrapped
	# with tr() at their own call site instead.
	l.text = text
	l.add_theme_font_override("font", _font(weight, numeric))
	l.add_theme_font_size_override("font_size", roundi(size * UI_TEXT_SCALE))
	l.add_theme_color_override("font_color", color)
	return l


## _label()'ın sarmalı hâli — üst bardaki dar HBoxContainer hücrelerinde
## (coins/level gibi) autowrap varsayılan olsaydı metin dikey harf harf
## dizilip bozulurdu (autowrap min-width'i ~0'a indiriyor); bu yüzden ortak
## varsayılan yerine yalnızca uzun açıklama metinlerinde bilinçli kullanılır
## (Ayarlar/Vardiya/Profil popup'ları — kullanıcı isteği: "görünümü bozuk").
func _label_wrap(text: String, size: int, color: Color, weight := 500) -> Label:
	var l := _label(text, size, color, weight)
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


## Alt bar butonu: karo ikon, ETİKETSİZ (kullanıcı isteği — Clash Royale'deki
## gibi ikon alanı doldursun). Etiket düğümü yine kuruluyor ama ikonlu
## sekmelerde gizli: b.get_meta("label") sözleşmesini bozmadan (canlı metinler
## ve ikonsuz sekmeler onu kullanıyor) yazıyı kaldırmanın yolu bu.
func _bar_button(icon_path: String, text: String) -> Button:
	var b := Button.new()
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 100)
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
		# Sekme her iki durumda da bir karo (prototip satır 753-755): pasifken
		# soluk krem zemin + kenar, aktifken dolu krem + altın kenar ve sert
		# `0 3px 0 #b8862a` gölge. Karo ölçüsü 42x38, köşe 12.
		var wrap := CenterContainer.new()
		wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var box := PanelContainer.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Prototip karosu 42x38 / ikon 34'tü; kullanıcı geri bildirimi "ikonlar
		# küçük" olduğu için karo ve ikon bir kademe büyütüldü.
		box.custom_minimum_size = Vector2(92, 92)
		var box_sb := StyleBoxFlat.new()
		box_sb.bg_color = PALETTE.cream
		box_sb.border_color = PALETTE.gold
		box_sb.set_border_width_all(2)
		box_sb.set_corner_radius_all(12)
		box_sb.content_margin_left = 4
		box_sb.content_margin_right = 4
		box_sb.content_margin_top = 2
		box_sb.content_margin_bottom = 2
		# Prototipteki gölge bulanık değil, 3 piksel aşağı kaydırılmış düz bir
		# katman: shadow_size küçük tutulur, tüm etkiyi offset verir.
		box_sb.shadow_color = Color("b8862a")
		box_sb.shadow_size = 1
		box_sb.shadow_offset = Vector2(0, 3)
		box.add_theme_stylebox_override("panel", box_sb)
		var idle_sb := StyleBoxFlat.new()
		idle_sb.bg_color = Color(PALETTE.cream, 0.10)
		idle_sb.border_color = Color(PALETTE.cream, 0.16)
		idle_sb.set_border_width_all(2)
		idle_sb.set_corner_radius_all(12)
		idle_sb.content_margin_left = 4
		idle_sb.content_margin_right = 4
		idle_sb.content_margin_top = 2
		idle_sb.content_margin_bottom = 2
		box.set_meta("active_sb", box_sb)
		box.set_meta("idle_sb", idle_sb)
		box.add_theme_stylebox_override("panel", idle_sb)
		var ico := _icon(icon_path, 70)
		ico.modulate.a = 0.72
		box.add_child(ico)
		wrap.add_child(box)
		v.add_child(wrap)
		b.set_meta("icon", ico)
		b.set_meta("icon_box", box)
	var l := _label(text, 18 if icon_path == "" else 12, PALETTE.cream_text, 700)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.modulate.a = 0.78
	l.visible = icon_path == ""
	v.add_child(l)
	b.set_meta("label", l)
	return b


## Alt bar sekmesini aktif/pasif görünüme geçirir (prototipteki seçili durum:
## krem kutu + altın kenar, etiket altın ve tam opak).
func _set_bar_button_active(b: Button, active: bool) -> void:
	if b == null or not b.has_meta("icon_box"):
		return
	var box: PanelContainer = b.get_meta("icon_box")
	box.add_theme_stylebox_override("panel", box.get_meta("active_sb") if active else box.get_meta("idle_sb"))
	var ico: TextureRect = b.get_meta("icon")
	ico.modulate.a = 1.0 if active else 0.72
	var l: Label = b.get_meta("label")
	l.modulate.a = 1.0 if active else 0.78
	l.add_theme_color_override("font_color", PALETTE.gold_soft if active else PALETTE.cream_text)
	# İkon karosu tek durum göstergesi kaldı (etiket gizli): aktifken bir tık
	# büyüsün ki dokunulan sekme yazısız da okunsun.
	box.scale = Vector2.ONE * (1.06 if active else 1.0)
	box.pivot_offset = box.size / 2.0


## Cihazın güvenli alanı, viewport birimine çevrilmiş kenar boşluğu olarak:
## x = yan, y = üst, z = alt. Güvenli alan ekran pikseli cinsinden gelir,
## yerleşim ise 720 genişlikteki viewport biriminde; oran window boyutundan
## çıkarılır. Yuvarlatılmış köşeler güvenli alana YANSIMADIĞI için sonuç
## UI_SAFE_MIN_* tabanlarıyla karşılaştırılır — masaüstü/web'de zaten yalnızca
## bu tabanlar kalır.
func _safe_insets() -> Vector3:
	var out := Vector3(UI_SAFE_MIN_X, UI_SAFE_MIN_TOP, UI_SAFE_MIN_BOTTOM)
	var win := Vector2(DisplayServer.window_get_size())
	if win.x <= 0.0 or win.y <= 0.0:
		return out
	var view := get_viewport_rect().size
	var safe := DisplayServer.get_display_safe_area()
	# Sol ve sağ ayrı ayrı gelebilir (yatay çentik); yerleşim simetrik dursun
	# diye ikisinin büyüğü iki yana da uygulanır.
	var edge := maxf(float(safe.position.x), float(win.x - safe.end.x))
	out.x = maxf(out.x, edge * view.x / win.x)
	out.y = maxf(out.y, float(safe.position.y) * view.y / win.y)
	out.z = maxf(out.z, float(win.y - safe.end.y) * view.y / win.y)
	return out


## Kenara değen her parçaya güncel güvenli alan boşluğunu dağıtır. Pencere
## boyutu değişince (döndürme, masaüstünde yeniden boyutlandırma) yeniden
## çağrılır — bkz. _build_ui'daki size_changed bağlantısı.
func _apply_safe_area() -> void:
	var pad := _safe_insets()
	# Alt bar: şerit kenardan kenara kalır, karolar içeri girer.
	if bar_safe_pad != null:
		bar_safe_pad.add_theme_constant_override("margin_left", int(pad.x))
		bar_safe_pad.add_theme_constant_override("margin_right", int(pad.x))
		bar_safe_pad.add_theme_constant_override("margin_bottom", int(pad.z))
	# Üst bar: çentiğin altına iner (eski sabit 14 artık yalnızca taban).
	if top_safe_pad != null:
		top_safe_pad.add_theme_constant_override("margin_top", int(pad.y))
	# Popup başlık şeridi: bant kenardan kenara, ‹ ve ✕ düğmeleri içeri.
	if popup_head_pad != null:
		popup_head_pad.add_theme_constant_override("margin_left", int(pad.x))
		popup_head_pad.add_theme_constant_override("margin_right", int(pad.x))
		popup_head_pad.add_theme_constant_override("margin_top", int(pad.y))
	# Popup gövdesi: sona kadar kaydırıldığında son satır köşeye girmesin.
	if popup_pad != null:
		popup_pad.add_theme_constant_override("margin_left", int(pad.x))
		popup_pad.add_theme_constant_override("margin_right", int(pad.x))
		popup_pad.add_theme_constant_override("margin_bottom", int(pad.z) + 12)


## Kök yerleşim kenardan kenara olduğu için (bkz. _build_ui'daki margin),
## yan boşluğa ihtiyacı olan tekil parçalar kendi kenar boşluğunu taşır.
func _edge_pad(parent: Node, top: int = 0, bottom: int = 0) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 14)
	m.add_theme_constant_override("margin_right", 14)
	m.add_theme_constant_override("margin_top", top)
	m.add_theme_constant_override("margin_bottom", bottom)
	parent.add_child(m)
	return m


func _spacer_x(px: int) -> Control:
	var c := Control.new()
	c.mouse_filter = MOUSE_PASSTHROUGH
	c.custom_minimum_size = Vector2(px, 0)
	return c


func _spacer_y(px: int) -> Control:
	var c := Control.new()
	c.mouse_filter = MOUSE_PASSTHROUGH
	c.custom_minimum_size = Vector2(0, px)
	return c


func _button(text: String, size: int, bg: Color, fg: Color) -> Button:
	var b := Button.new()
	# See _label(): the key is stored raw, Godot translates on display.
	b.text = text
	# Not: autowrap burada KASITLI OLARAK yok — bir HBoxContainer satırında
	# (ör. zoom +/- butonları) sarma açık bir buton, genişliği ~0'a sarkıtıp
	# yüksekliği yüzlerce piksele şişiriyor (min-size hesaplama tuzağı).
	# Uzun buton metinleri için elle "\n" ile satır kır (bkz. vardiya/otomatik
	# yenileme butonları) — bu her zaman güvenli ve öngörülebilir.
	# Every button in the design is 700.
	b.add_theme_font_override("font", _font(700))
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


## Menü sayfalarının buton dili — üç biçim, hepsi 10 piksel köşe:
##
## - "outline": krem zemin, altın kenar, koyu kahve yazı. Sayfadaki normal
##   eylemler. Bir kartta yan yana iki eylem varsa ikisi de budur.
## - "primary": dolu altın, yine koyu kahve yazı. Sayfanın TEK vurgusu.
## - "danger": yumuşak kırmızı zemin, kırmızı kenar ve yazı.
##
## Kırmızı ve yeşil dolgular menüden kalktı: kırmızı yalnızca tehlike, yeşil
## yalnızca dünyadaki kazanç anlamına geliyor. Dünya HUD'u (zoom, alt bar,
## merkezdeki büyük buton) bu dilin dışında, kendi biçiminde kalır.
func _menu_btn_colors(kind: String) -> Dictionary:
	match kind:
		"primary":
			return {"bg": PALETTE.gold, "border": PALETTE.gold.darkened(0.18),
				"fg": PALETTE.text, "meta": PALETTE.wood_dark}
		"danger":
			return {"bg": PALETTE.red_soft, "border": PALETTE.banner_red,
				"fg": PALETTE.red_text, "meta": PALETTE.red_text}
	return {"bg": PALETTE.pill_cream, "border": PALETTE.gold,
		"fg": PALETTE.text, "meta": PALETTE.muted}


## _button'ın menü biçimi: _menu_btn_colors'daki üç dilden biri, sabit köşe.
func _menu_button(text: String, size: int, kind: String = "outline") -> Button:
	var col := _menu_btn_colors(kind)
	var b := _button(text, size, col.bg, col.fg)
	# Yalnızca modallerde kullanılıyor ve modalin gövdesi kaydırılabilir
	# (bkz. _modal_shell) — sürükleme butonun üstünden de geçmeli.
	b.mouse_filter = MOUSE_SCROLLABLE
	b.custom_minimum_size.y = TOUCH_MIN
	for state in ["normal", "hover", "pressed", "disabled"]:
		# _button kenarı zeminden türetiyor; menü dilinde kenar ayrı bir renk.
		var sb := b.get_theme_stylebox(state) as StyleBoxFlat
		sb.border_color = col.border
		sb.set_corner_radius_all(20)
		sb.set_content_margin_all(24)
	return b


## Satırın sağındaki eylem hapı ("Start", "Watch"): dolu altın, koyu kahve
## yazı — _menu_button'ın "primary" biçiminin satır içindeki karşılığı.
func _action_pill_cfg() -> Dictionary:
	var col := _menu_btn_colors("primary")
	return {"pill_bg": col.bg, "pill_border": col.border, "right_color": col.fg}


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
	if popup_coins_label:
		popup_coins_label.text = _fmt(Game.coins)
		popup_gems_label.text = str(Game.gems)
	var stars := Game.star_rating()
	for i in 5:
		star_icons[i].texture = _tex("res://assets/ui/star_full.svg" if i < stars else "res://assets/ui/star_empty.svg")
	var lv := Game.level()
	level_label.text = tr("Level %d") % lv
	var cur_xp := Game.xp - Game.xp_for_level(lv)
	var need := Game.xp_for_level(lv + 1) - Game.xp_for_level(lv)
	xp_bar.max_value = need
	xp_bar.value = cur_xp
	if xp_text_label:
		xp_text_label.text = "%s / %s XP" % [_fmt(cur_xp), _fmt(need)]
	_update_bar_active()
	var has_income := int(Game.pending_income) > 0
	if Game.shift_active():
		shift_label.text = tr("%s left in the shift · %.0f coins/hour") % [
			_fmt_hms(Game.shift_remaining_game_hours()), Game.hourly_income()]
	else:
		shift_label.text = tr("No shift running — the hotel isn't earning.")
	# Tek durum makinesi: biriken para varsa (vardiya bitmiş olsa da) "Collect",
	# yoksa vardiya sürüyorsa kalan süre, hiçbiri yoksa "Start shift".
	if has_income:
		primary_label.text = tr("Collect")
		# Alt satırda YALNIZCA tutar durur: kalan süre zaten gökyüzü çipinde
		# yazıyor ve ikisi birlikte 120 piksellik daireye sığmıyor.
		shift_bar_label.text = tr("%s coins") % _fmt(int(Game.pending_income))
		collect_button.disabled = false
	elif Game.shift_active():
		primary_label.text = tr("Running")
		shift_bar_label.text = tr("%s left") % _fmt_hms(Game.shift_remaining_game_hours())
		collect_button.disabled = true
	else:
		primary_label.text = tr("Start shift")
		shift_bar_label.text = tr("1-24 h")
		collect_button.disabled = false
	if has_income and not _collect_pulse_on:
		_collect_pulse_on = true
		_start_collect_pulse()
	elif not has_income and _collect_pulse_on:
		_collect_pulse_on = false
		_stop_collect_pulse()


## Alt barda hangi sekmenin "seçili" göründüğü: açık popup varsa o, yoksa
## İnşa Modu açıkken Build. Görev rozeti de burada tazelenir.
func _update_bar_active() -> void:
	for title in _bar_buttons:
		var active: bool = title == _active_tab or (title == "Build" and build_mode and _active_tab == "")
		_set_bar_button_active(_bar_buttons[title], active)
	if quest_badge:
		# Rozet "ödül almaya hazır görev" sayamaz: görevler ve başarımlar
		# hedefe ulaşır ulaşmaz KENDİLİĞİNDEN tamamlanıp ödemesini yapıyor
		# (Game._check_quests / _check_achievements), yani "hazır" durumu tek
		# kare bile sürmüyor — eski `!` rozeti bu yüzden pratikte hiç
		# görünmüyordu. Anlamlı olan sayı: oyuncunun Quests ekranını en son
		# açmasından beri tamamlanan, HENÜZ GÖRMEDİĞİ görev/başarım.
		var unseen := maxi(0, Game.quest_index - _quests_seen_index) \
			+ maxi(0, Game.unlocked_achievements.size() - _achievements_seen_count)
		quest_badge.visible = unseen > 0
		if quest_badge_label:
			quest_badge_label.text = str(unseen)


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
	# Hap rengi haftalık temaya göre DEĞİŞMİYOR: prototipte sabit
	# rgba(224,85,74,.9). Bazı tema accent'leri (Golden Age, Winter Tale)
	# gökyüzünün üstünde soluk kalıyordu; tema adı zaten metinde yazıyor.
	# Yalnızca temanın adı: "Theme of the week: …" öneki hapı ekranın dışına
	# taşıracak kadar uzundu ve zaten çipin bağlamı bunu söylüyor.
	roof_theme_label.text = "✦ %s" % tr(String(theme.name))

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
	# Zemin şeritleri binadan GENİŞ çizilir: tuval viewport'tan darsa (tablet,
	# katlanabilir, yatay çevrilmiş ekran) bina ortalanıyor ve kaldırım/yol/çim
	# bina genişliğinde kesilince otel havada duran bir ada gibi görünüyordu.
	# Bir bina genişliği kadar taşma her iki yana yetiyor; şeritler düz renk
	# olduğu için maliyeti yok.
	var street_w := canvas_w * 3.0
	var ground_x := -canvas_w
	var street := Control.new()
	street.position = Vector2(ground_x, street_y)
	street.size = Vector2(street_w, STREET_H)
	street.mouse_filter = Control.MOUSE_FILTER_IGNORE
	building_canvas.add_child(street)
	street_node = street

	const SIDEWALK_H := 58.0
	const CURB_H := 7.0
	var sidewalk := ColorRect.new()
	sidewalk.color = PALETTE.sidewalk
	sidewalk.position = Vector2.ZERO
	sidewalk.size = Vector2(street_w, SIDEWALK_H)
	sidewalk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	street.add_child(sidewalk)
	for seam_x in range(0, int(street_w), 64):
		var seam := ColorRect.new()
		seam.color = PALETTE.sidewalk.darkened(0.12)
		seam.position = Vector2(seam_x, 0)
		seam.size = Vector2(2, SIDEWALK_H)
		seam.mouse_filter = Control.MOUSE_FILTER_IGNORE
		street.add_child(seam)
	var curb := ColorRect.new()
	curb.color = PALETTE.curb
	curb.position = Vector2(0, SIDEWALK_H)
	curb.size = Vector2(street_w, CURB_H)
	curb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	street.add_child(curb)
	var road := ColorRect.new()
	road.color = PALETTE.asphalt
	road.position = Vector2(0, SIDEWALK_H + CURB_H)
	road.size = Vector2(street_w, STREET_H - SIDEWALK_H - CURB_H)
	road.mouse_filter = Control.MOUSE_FILTER_IGNORE
	street.add_child(road)
	for dash_x in range(10, int(street_w), 46):
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
	# Kuyruk hâlâ BİNANIN önünde durur — şerit sola taştığı için ofset veriliyor.
	street_scroll.position = Vector2(-ground_x, 2)
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
	# Köşeler DÜZ: yerleşim kenardan kenara olduğu için yuvarlatılmış alt
	# köşeler ekranın sol/sağ ucunda "çim bitmemiş" gibi okunuyordu.
	gsb.set_corner_radius_all(0)
	gsb.border_color = PALETTE.grass_dark
	gsb.border_width_bottom = 4
	grass.add_theme_stylebox_override("panel", gsb)
	grass.position = Vector2(ground_x, street_y + STREET_H)
	grass.size = Vector2(street_w, GRASS_H)
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
	var l := _label("%s\n%s" % [tr("Unlock block"), tr("%s coins") % _fmt(Game.block_price(floor_i))], 11, Color("f0dfc4"))
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
	if content_size.x >= vp_size.x:
		_canvas_pan.x = clampf(_canvas_pan.x, vp_size.x - content_size.x, 0.0)
	else:
		# Bina viewport'tan darsa ORTALA. Eskiden sola yapışıyordu: telefonda
		# fark edilmiyordu çünkü bina her zaman genişliği dolduruyor, ama
		# tablet/katlanabilir cihazda (ve Android 16 büyük ekranda dikey
		# kısıtlamayı zaten yok saydığı için yatay çevrilen her cihazda) otel
		# solda, sağda kocaman boş gökyüzü kalıyordu.
		_canvas_pan.x = (vp_size.x - content_size.x) * 0.5
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
		"build_mode": build_mode,
		"clean_mode": clean_mode,
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
	# Temizlik Modunda dokunulabilir hedefler ayrışsın: yalnızca kirli odalar
	# altın çerçeve alır, diğerleri sönük durur.
	if clean_mode and is_dirty:
		border = PALETTE.gold
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
			var hint := _label("empty block", 12, PALETTE.muted)
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
				b.add_child(_make_decorate_badge(int(room.get("w", 1)) * CELL_W - CELL_GAP))
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

	# İsim bandı — tier · SP bilgisi yalnızca İnşa Modu açıkken gösterilir
	# (her zaman açık olunca dar odalarda "Basic · SP 20" gibi metin bitişik
	# odanın üstüne taşıyordu); kirli/istila rozeti önemli bir uyarı olduğu
	# için modu fark etmeksizin her zaman gösterilir.
	var is_sp_plate := cat == "guest" and not is_dirty and not is_infested
	if not is_sp_plate or build_mode:
		var plate := PanelContainer.new()
		var psb := StyleBoxFlat.new()
		psb.bg_color = PALETTE.banner_red if cat == "guest" else PALETTE.green_deep
		psb.set_corner_radius_all(4)
		psb.content_margin_left = 6
		psb.content_margin_right = 6
		psb.content_margin_top = 1
		psb.content_margin_bottom = 1
		plate.add_theme_stylebox_override("panel", psb)
		# Oda kutusunun genişliğine sabitlenir (eskiden içeriğe göre serbest
		# büyüyordu).
		plate.anchor_right = 1.0
		plate.offset_left = 4
		plate.offset_top = 4
		plate.offset_right = -4
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var plate_text: String = tr(String(d.name))
		if is_infested:
			plate_text = tr("INFESTED! %d c") % int(Game.eco.infest.clean_cost)
		elif is_dirty:
			plate_text = tr("DIRTY!")
		elif cat == "guest":
			plate_text = "%s · SP %d" % [tr(Game.tier_name(Game.room_tier(room))), Game.room_score(room)]
		# Oda genişliğine göre sığana kadar font küçültülür — metin hiç
		# kesilmeden tamamı görünür kalır.
		var plate_w: float = int(room.get("w", 1)) * CELL_W - CELL_GAP - 8.0 - 12.0
		var font_size := _fit_font_size(plate_text, plate_w, 11, 7)
		var pl := _label(plate_text, font_size, PALETTE.cream_text)
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
func _make_decorate_badge(max_w: float) -> Control:
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
	# Dar odada rozet, odanın soluna taşıyordu: kutu artık odanın genişliğiyle
	# sınırlı ve yazı o genişliğe sığana kadar küçülüyor (bkz. _fit_font_size,
	# oda plakasıyla aynı yöntem).
	var text := tr("✦ Decorate!")
	var room_w := max_w - 8.0
	var size := _fit_font_size(text, room_w - 18.0, 11, 8, 700)
	if _font(700).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			roundi(size * UI_TEXT_SCALE)).x > room_w - 18.0:
		# Tek hücrelik odaya kelime hiçbir boyutta sığmıyor; yıldız tek başına
		# da "burada yapılacak bir şey var" diyor.
		text = "✦"
		size = 11
	badge.offset_left = -minf(room_w, 150.0)
	badge.offset_right = -4
	badge.offset_top = 4
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := _label(text, size, PALETTE.text, 700)
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
	# Temizlik yalnızca Temizlik Modunda: mod kapalıyken kirli odaya dokunmak
	# diğer odalarla aynı şeyi yapar (oda ekranını açar). Eski "dokun = anında
	# temizle" davranışı kaldırıldı — kullanıcı isteği.
	if clean_mode:
		if not room.dirty:
			_show_toast("This room is already clean.")
			return
		# Buton yeniden kurulumda yok olacağı için merkezi temizlemeden önce al
		var center := btn.global_position + btn.size / 2.0
		var cost := Game.clean_cost(idx)
		if Game.clean_room(idx):
			_play("clean")
			_spawn_clean_anim(center)
			if cost > 0:
				_show_toast(tr("Infestation cleared! (−%d coins, +2 XP)") % cost)
			else:
				_show_toast("Room cleaned (+2 XP)")
			# Son kirli oda da temizlendiyse modda kalmanın anlamı kalmıyor.
			if _dirty_room_count() == 0:
				_set_clean_mode(false)
		elif cost > 0:
			_show_toast(tr("Clearing the infestation costs %d coins!") % cost)
		return
	selected_room = idx
	_tutorial_advance_on("room_tap")
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
	var price_text := (tr("Unlocks at Lv.%d") % int(d.unlock_level)) if locked else tr("%s coins") % _fmt(int(d.price))
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
			_show_toast(tr("%s placed!") % tr(String(Game.room_def(new_type).name)))
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
		_show_toast(tr("A secret inspector! +%d coins (%s left)") % [bonus, _count(Game.pokes_left(), "nudge")])
	else:
		_play("tap")
		_show_toast(tr("The guest yawned and went back to sleep… (%s left)") % _count(Game.pokes_left(), "nudge"))


## Merkez butonun tek giriş noktası: biriken para varsa toplar, yoksa vardiya
## seçme ekranını açar (bkz. _update_live_labels'daki aynı durum makinesi).
func _on_primary_pressed() -> void:
	if int(Game.pending_income) > 0:
		_on_collect()
		return
	_tutorial_advance_on("shift_tap")
	_open_popup("Shift", _build_shift_popup)


func _on_collect() -> void:
	_tutorial_advance_on("collect_tap")
	var from := collect_button.global_position + collect_button.size / 2.0
	var got := Game.collect()
	if got > 0:
		_play("collect")
		_fly_coins(from, got)
		_show_toast(tr("+%s coins collected") % _fmt(got))


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

## Üç modalin de ortak kabuğu: karartma + ortalanmış kart + kaydırılabilir
## gövde. `[dim, pv]` döner; `dim` ağaca EKLENMEZ (çağıran önce kendi
## sinyallerini bağlar), `pv` içeriğin gireceği kaptır.
##
## Gövde neden bir ScrollContainer: kart doğrudan CenterContainer'ın içindeydi,
## yani her zaman içeriğinin tam boyunda duruyordu. Ekrandan uzun bir gövde —
## uzun bir çeviri, küçük bir ekran, uzun bir çevrimdışı özeti — taşıyor ve
## okunamayan, hatta eylem butonu ekranın dışında kaldığı için KAPATILAMAYAN
## bir modal veriyordu. Kaydırma yalnızca gerektiği kadar açılır: kap içeriğin
## boyu ile ekranda kalan yerin küçüğünü alır, yani kısa modaller eskisi gibi
## görünür.
func _modal_shell(dim_alpha: float, min_w: int, z: int, separation: int) -> Array:
	var dim := ColorRect.new()
	dim.color = Color(0.2, 0.15, 0.05, dim_alpha)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.z_index = z
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.add_child(center)
	var panel := _panel(PALETTE.cream, PALETTE.facade_line)
	panel.custom_minimum_size = Vector2(min_w, 0)
	center.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# Parmak kart üstünden de kaydırabilsin diye (bkz. MOUSE_PASSTHROUGH).
	scroll.scroll_deadzone = SCROLL_DEADZONE
	panel.add_child(scroll)
	var pv := VBoxContainer.new()
	pv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pv.add_theme_constant_override("separation", separation)
	scroll.add_child(pv)
	# Dikey kaydırma açık bir ScrollContainer'ın en küçük boyu SIFIRDIR, yani
	# CenterContainer karta hiç yükseklik vermez; yükseklik burada elle verilir.
	# Panelin kendi iç boşluğu stilbox'tan okunur, elle tekrarlanmaz.
	var pad: float = 0.0
	var panel_sb := panel.get_theme_stylebox("panel")
	if panel_sb != null:
		pad = panel_sb.content_margin_top + panel_sb.content_margin_bottom
	var fit := func():
		var insets := _safe_insets()
		var avail: float = get_viewport_rect().size.y - insets.y - insets.z 			- MODAL_SCREEN_MARGIN * 2.0 - pad
		var want := minf(pv.get_combined_minimum_size().y, maxf(avail, 0.0))
		# Aynı değeri geri yazmak yeni bir yerleşim turu tetikler; ölçüm
		# `resized`'a bağlı olduğu için bu sonsuz döngü olurdu.
		if absf(scroll.custom_minimum_size.y - want) > 0.5:
			scroll.custom_minimum_size.y = want
	# Ölçüm GENİŞLİK belli olduktan sonra yapılmalı: satır kaydıran bir etiketin
	# en küçük yüksekliği genişliğine bağlı, genişlik 0 iken her kelime ayrı
	# satıra düşüyormuş gibi ölçülüyor ve kart ekran boyu uzuyor. `resized` ilk
	# gerçek yerleşimden sonra gelir, oradan ölçülür.
	pv.resized.connect(fit)
	var vp := get_viewport()
	vp.size_changed.connect(fit)
	dim.tree_exiting.connect(func(): vp.size_changed.disconnect(fit))
	return [dim, pv]


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
	_show_modal({
		"title": title, "text": text, "action_text": action_text,
		"on_action": on_action, "on_dismiss": on_dismiss,
	})


## _show_simple_modal'ın genel hâli: gövde düz metin yerine bir builder ile de
## doldurulabilir (günlük ödül şeridi, çevrimdışı kazanç kartı) ve birincil
## butonun ALTINA ikincil bir buton konabilir (ödüllü reklam).
##
## cfg anahtarları: title · title_icon · text · body (Callable(VBoxContainer))
## · action_text · on_action · secondary_text · secondary_icon · on_secondary
## · on_dismiss.
func _show_modal(cfg: Dictionary) -> void:
	var shell := _modal_shell(0.5, 500, 90, 14)
	var dim: ColorRect = shell[0]
	var pv: VBoxContainer = shell[1]
	# Başlık: prototipte günlük ödül başlığının solunda sparkle ikonu var.
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	pv.add_child(title_row)
	var title_icon: String = cfg.get("title_icon", "")
	if title_icon != "":
		var ti := _icon(title_icon, 26)
		ti.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		title_row.add_child(ti)
	title_row.add_child(_label(String(cfg.get("title", "")), 20, PALETTE.wood_dark))
	var text: String = cfg.get("text", "")
	if text != "":
		var body := _label(text, 15, PALETTE.text)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		pv.add_child(body)
	var body_builder: Callable = cfg.get("body", Callable())
	if body_builder.is_valid():
		body_builder.call(pv)
	var action_b := _menu_button(String(cfg.get("action_text", "OK")), 16, "primary")
	action_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pv.add_child(action_b)
	var closed := false
	var do_close := func():
		if closed:
			return
		closed = true
		dim.queue_free()
	var on_action: Callable = cfg.get("on_action", Callable())
	action_b.pressed.connect(func():
		do_close.call()
		if on_action.is_valid():
			on_action.call())
	var secondary_text: String = cfg.get("secondary_text", "")
	if secondary_text != "":
		var sec_b := _menu_button(secondary_text, 15)
		sec_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var secondary_icon: String = cfg.get("secondary_icon", "")
		if secondary_icon != "":
			_button_icon(sec_b, secondary_icon)
		var on_secondary: Callable = cfg.get("on_secondary", Callable())
		sec_b.pressed.connect(func():
			do_close.call()
			if on_secondary.is_valid():
				on_secondary.call())
		pv.add_child(sec_b)
	var on_dismiss: Callable = cfg.get("on_dismiss", Callable())
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
	var shell := _modal_shell(0.5, 500, 90, 14)
	var dim: ColorRect = shell[0]
	var pv: VBoxContainer = shell[1]
	pv.add_child(_label("Rename your hotel", 20, PALETTE.wood_dark))
	pv.add_child(_label(tr("Up to %d characters, so it fits the sign in the lobby.") % HOTEL_NAME_MAX_LEN, 12, PALETTE.muted))
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
	var cancel_b := _menu_button("Cancel", 15)
	cancel_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel_b.pressed.connect(do_close)
	row.add_child(cancel_b)
	var save_b := _menu_button("Save", 15, "primary")
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


## Yeni bir ekran yığını başlatır: alt bar sekmeleri arasında gezinmek yığını
## büyütmemeli, her sekme kendi kökü.
func _open_popup(title: String, builder: Callable) -> void:
	_popup_stack.clear()
	_skip_shift_armed = false
	_push_popup(title, builder)


## Yığına bir seviye iner (ör. Store ▸ Offers → oda seçimi). Başlıktaki ‹
## butonu buradan geri döner.
func _push_popup(title: String, builder: Callable) -> void:
	_play("tap")
	if _popup_stack.is_empty():
		_active_tab = title
	_popup_stack.append({"title": title, "builder": builder})
	_sync_popup_head()
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


## Yığında bir seviye geri gider; kökteysek popup'ı kapatır. Android geri
## tuşu ve başlıktaki ‹ butonu buraya bağlı.
func _pop_popup() -> void:
	if _popup_stack.size() <= 1:
		_close_popup()
		return
	_popup_stack.pop_back()
	_play("tap")
	_sync_popup_head()
	_rebuild_popup()
	popup_scroll.scroll_vertical = 0


## Başlık ve popup_builder'ı yığının tepesiyle eşitler. ‹ butonu her zaman
## görünür: kökteyken _pop_popup sayfayı kapatır (bkz. orası).
func _sync_popup_head() -> void:
	if _popup_stack.is_empty():
		popup_builder = Callable()
		popup_title.text = ""
		return
	var top: Dictionary = _popup_stack.back()
	# The title doubles as the tab identifier (`_active_tab`), so the stack
	# keeps the English string; the Label translates it on display.
	popup_title.text = String(top.title)
	popup_builder = top.builder


func _close_popup() -> void:
	overlay.visible = false
	_active_tab = ""
	_popup_stack.clear()
	popup_builder = Callable()
	selected_room = -1
	_pending_bundle_id = ""
	# Hesap bağlama tarayıcıyı bekliyorken bu ekranı kapatmak "vazgeçtim"
	# demektir: bekleyen turu bırak, yoksa await zaman aşımına (dakikalar) kadar
	# asılı kalır ve oyuncu yeniden deneyemez.
	if CloudSave.is_linking():
		CloudSave.cancel_google_signin()
	# Bekleyen bir "tap" adımı varsa (popup açıkken _show_tutorial_step ertelemişti,
	# bkz. orası) popup gerçekten kapanınca spotlight'ı şimdi göster.
	if _tutorial_step_index >= 0 and _tutorial_step_index < TUTORIAL_STEPS.size() \
			and String(TUTORIAL_STEPS[_tutorial_step_index].get("type", "")) == "tap" \
			and not tutorial_layer.visible:
		_show_tutorial_spotlight(TUTORIAL_STEPS[_tutorial_step_index])


func _rebuild_popup() -> void:
	# await'li düğmeler (yedekleme, hesap bağlama, IAP) işleri bitince buraya
	# döner — popup o arada KAPANMIŞ olabilir. Geçersiz bir Callable'ı çağırmak
	# çalışma zamanı hatası basardı; kapı burada tutulur ki her çağıranın ayrı
	# ayrı kontrol etmesi gerekmesin (sinyalle bağlı çağrılar dahil).
	if not overlay.visible or not popup_builder.is_valid():
		return
	for c in popup_content.get_children():
		popup_content.remove_child(c)
		c.queue_free()
	popup_builder.call(popup_content)


func _build_shift_popup(c: VBoxContainer) -> void:
	if Game.shift_active():
		var head := _card(c)
		head.add_child(_label(tr("Shift in progress — %s left.") % _fmt_hms(Game.shift_remaining_game_hours()), 15, PALETTE.text))
		head.add_child(_label("You can collect your earnings whenever you like.", 12, PALETTE.muted))
		var gem_cost := Game.skip_shift_gem_cost()
		var hk_active := Game.housekeeping_active()
		var skip_b := _action(c, tr("Finish now — %s") % _count(gem_cost, "gem"),
			"Ends the shift immediately and banks the earnings.",
			Game.gems >= gem_cost, "primary")
		# "Emin misin?" durumu butonun META'sında DEĞİL, üye değişkende durur:
		# popup her state_changed'de baştan kuruluyor (oda kirlenmesi bile
		# yetiyor), meta ile tutulunca iki dokunuş arasında silinip vardiya
		# hiç bitmiyordu — "gem ile bitirdim ama süre devam ediyor" hatası.
		if _skip_shift_armed:
			_row_set(skip_b, "Tap again to finish anyway",
				"No Housekeeping room — some rooms may not pay full rate.")
		skip_b.pressed.connect(func():
			if not hk_active and not _skip_shift_armed:
				_skip_shift_armed = true
				_row_set(skip_b, "Tap again to finish anyway",
					"No Housekeeping room — some rooms may not pay full rate.")
				return
			_skip_shift_armed = false
			if Game.skip_shift():
				_play("buy")
				_show_toast("Shift finished with gems — the earnings are in the till!")
				_close_popup())
		if hk_active:
			_notice(c, "You have a Housekeeping room — you'll earn full rate to the end of the shift, as if guests never stopped coming.", "gold")
		else:
			_notice(c, "No Housekeeping room — rooms left dirty earn nothing for this stretch.", "warn")
		if Game.now() < Game.boost_end_unix:
			var left_min := int(
				(Game.boost_end_unix - Game.now()) * Game.time_scale / 60.0)
			_row(c, "res://assets/ui/ad_video.png", "Ad bonus active",
				tr("Income ×%.1f · %d min left") % [Game.boost_mult, maxi(0, left_min)],
				"", false)
		else:
			var boost_cfg := _action_pill_cfg()
			boost_cfg.merge({
				"icon": "res://assets/ui/ad_video.png",
				"title": "Watch an ad — ×2 income",
				"meta": "For the next 30 minutes", "right": "Watch",
			})
			var boost_b := _sheet_row(c, boost_cfg)
			boost_b.pressed.connect(func():
				Ads.show_rewarded(func():
					Game.start_income_boost(30.0, 2.0)
					_play("buy")
					_show_toast("Ad bonus started: ×2 income for 30 min!")
					_rebuild_popup()))
		_add_auto_renew_shop(c)
		return
	_section(c, "Start a shift")
	c.add_child(_label("Pick a length — the hourly cost is the same for all:", 12, PALETTE.muted))
	for hours: int in [1, 4, 8, 24]:
		var cost := Game.shift_cost(hours)
		var est: float = Game.hourly_income() * hours
		# Tasarımdaki vardiya bloğu: solda süre rozeti, sağda birincil buton.
		var shift_cfg := _action_pill_cfg()
		shift_cfg.merge({
			"badge": tr("%dh") % hours,
			"title": _count(hours, "hour"),
			"meta": tr("cost %s · est. income ~%s") % [_fmt(cost), _fmt(int(est))],
			"right": "Start", "enabled": Game.coins >= cost,
		})
		var b := _sheet_row(c, shift_cfg)
		b.pressed.connect(func():
			if Game.start_shift(hours):
				_play("shift")
				_guest_walk_in()
				_show_toast(tr("A %d-hour shift has started!") % hours)
				_close_popup())
	_notice(c, "Note: rooms left dirty earn nothing. On a long shift a Housekeeping room is a must!", "warn")
	_add_auto_renew_shop(c)


## Vardiya popup'ının iki kolundan da (aktif/pasif) çağrılır — bu satın alma
## önceden Ayarlar'daydı, kullanıcı isteğiyle Vardiya'ya taşındı.
func _add_auto_renew_shop(c: VBoxContainer) -> void:
	_section(c, tr("Auto-renew · balance %s") % _fmt_hms(Game.auto_renew_hours_left))
	c.add_child(_label_wrap("While you have hours banked, a finished shift renews itself for the same length if you can afford it, spending that many hours from your balance — so the hotel keeps earning while you are away.", 11, PALETTE.muted))
	for hours: int in [1, 4, 8, 24]:
		var ar_cost := Game.auto_renew_buy_cost(hours)
		var ar_b := _sheet_row(c, {
			"badge": tr("%dh") % hours,
			"title": tr("Buy %s of auto-renew") % _count(hours, "hour"),
			"right": tr("%s coins") % _fmt(ar_cost), "right_color": PALETTE.text,
			"pill_bg": PALETTE.pill_cream, "pill_border": PALETTE.gold,
			"enabled": Game.coins >= ar_cost,
		})
		ar_b.pressed.connect(func():
			if Game.buy_auto_renew(hours):
				Game.save_game()
				_play("buy")
				_show_toast(tr("Bought %s of auto-renew!") % _count(hours, "hour"))
				_rebuild_popup())


func _build_staff_popup(c: VBoxContainer) -> void:
	# Temizlik bu ekranın işi: personel kadar odaların bakımı da burada. Buton
	# İnşa Modu gibi bir tuval modu açar, sayfayı kapatır ve oyuncu kirli
	# odalara tek tek dokunur (bkz. _set_clean_mode, _on_room_tapped).
	_section(c, "Housekeeping")
	var dirty := _dirty_room_count()
	var clean_b := _action(c, "Cleaning mode",
		tr("Tap dirty rooms one by one to clean them. %s right now.") % _count(dirty, "dirty room"),
		dirty > 0)
	clean_b.pressed.connect(func():
		_close_popup()
		_set_clean_mode(true))

	_section(c, "Staff")
	var tier: int = Game.staff_tier
	var max_tier: int = int(Game.eco.staff_upgrade.max_tier)
	# Personel görseli bu ekranın tek görseli — liste satırlarının 34 piksellik
	# ikonundan belirgin biçimde büyük duruyor (kullanıcı geri bildirimi).
	_sheet_row(c, {
		"icon": "res://assets/guests/maid.png", "icon_px": 96,
		"title": tr("Staff tier: %d / %d") % [tier, max_tier], "title_size": 15,
		"meta": tr("Shift cost: %%%.0f cheaper · Income per hour: +%%%.0f") % [
			(1.0 - Game.staff_cost_mult()) * 100.0, (Game.staff_income_mult() - 1.0) * 100.0],
	}).disabled = true
	if tier >= max_tier:
		_notice(c, "Your staff is at the top tier — no upgrades left.", "gold")
		return
	var cost := Game.staff_upgrade_cost()
	var next_cost_mult := 1.0 - pow(1.0 - float(Game.eco.staff_upgrade.cost_reduction_pct), tier + 1)
	var next_income_mult := pow(1.0 + float(Game.eco.staff_upgrade.income_boost_pct), tier + 1) - 1.0
	var b := _action(c, tr("Upgrade tier — %s coins") % _fmt(cost),
		tr("Next: -%%%.0f cost, +%%%.0f income") % [next_cost_mult * 100.0, next_income_mult * 100.0],
		Game.can_buy_staff_upgrade(), "primary")
	b.pressed.connect(func():
		if Game.buy_staff_upgrade():
			_play("buy")
			_show_toast(tr("Staff quality upgraded! (Tier %d)") % Game.staff_tier)
			_maybe_show_upgrade_ad())


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
	# Kirli oda: tuvalde dokunmak artık temizlemiyor (bkz. Temizlik Modu), bu
	# yüzden oda ekranı temizliğin ikinci yolu — oyuncu buraya kadar gelmişken
	# moda girmek zorunda kalmasın.
	if room.dirty:
		var clean_cost := Game.clean_cost(selected_room)
		_notice(c, "This room is dirty — it earns nothing until it's cleaned.", "warn")
		var clean_b := _action(c,
			tr("Clean this room") + ("" if clean_cost <= 0 else tr(" — %s coins") % _fmt(clean_cost)),
			"Or open Cleaning mode in Staff to clear several rooms in a row.",
			clean_cost <= 0 or Game.coins >= clean_cost, "primary")
		clean_b.pressed.connect(func():
			if Game.clean_room(selected_room):
				_play("clean")
				_show_toast("Room cleaned (+2 XP)" if clean_cost <= 0
					else tr("Infestation cleared! (−%s coins, +2 XP)") % _fmt(clean_cost))
			else:
				_show_toast(tr("Clearing the infestation costs %s coins!") % _fmt(clean_cost)))
	# Oda başlığı kartı: ad + tier, altında bir sonraki tier'a SP ilerlemesi
	# (prototipteki ince yeşil çubuk).
	var head := _card(c)
	head.add_child(_label(tr("%s — %s · SP %d · %d items") % [
		tr(String(Game.room_def(room.type).name)), tr(Game.tier_name(tier)),
		Game.room_score(room), room.items.size()], 15, PALETTE.text))
	if tier < Game.eco.tier_names.size() - 1:
		var next_th := int(Game.eco.tier_thresholds[tier + 1])
		_bar(head, float(Game.room_score(room)) / maxf(1.0, float(next_th)), PALETTE.green_deep)
		head.add_child(_label(tr("Next tier (%s): SP %d") % [tr(Game.tier_name(tier + 1)), next_th], 11, PALETTE.wood_dark))

	# Hazır dekor paketleri: tek dokunuşla, tek tek almaktan ucuz
	var bundles: Array = Game.eco.get("bundles", [])
	if not bundles.is_empty():
		_section(c, "Ready-made bundles")
		for bd in bundles:
			var sp_total := 0
			for iid in bd.items:
				sp_total += int(Game.item_def(iid).sp)
			var need_lv := Game.bundle_unlock_level(bd)
			var locked := Game.level() < need_lv
			var pb := _row(c, "", String(bd.name),
				tr("unlocks at level %d") % need_lv if locked else tr("SP +%d · %%%d off") % [sp_total, int(float(bd.discount) * 100.0)],
				"" if locked else tr("%s coins") % _fmt(Game.bundle_price(bd)),
				not locked and Game.can_buy_bundle(bd))
			if not locked:
				var bid: String = bd.id
				pb.pressed.connect(func():
					if Game.buy_bundle(selected_room, bid):
						_play("buy")
						_show_toast(tr("%s placed!") % tr(String(Game.bundle_def(bid).name)))
						_maybe_show_upgrade_ad())

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
		_section(c, String(slot_names.get(slot_key, slot_key)))
		for it in alts:
			var owned: bool = current == String(it.id)
			var locked2: bool = lv < int(it.get("unlock_level", 1))
			var meta2 := "✓ owned" if owned else (
				tr("unlocks at level %d") % int(it.unlock_level) if locked2 else "")
			var b2 := _row(c, "res://assets/items/%s.svg" % it.id, String(it.name), meta2,
				"" if owned or locked2 else tr("%s coins") % _fmt(int(it.price)),
				not owned and not locked2 and Game.can_afford_item(it))
			if not owned and not locked2:
				var iid2: String = it.id
				b2.pressed.connect(func():
					if Game.upgrade_base(selected_room, iid2):
						_play("buy")
						_show_toast(tr("%s upgraded!") % tr(String(Game.item_def(iid2).name)))
						_maybe_show_upgrade_ad())

	_section(c, "Add a decoration")
	for it in Game.eco.items:
		if not it.has("anchor"):
			continue
		var premium: bool = Game.item_is_premium(it)
		var locked: bool = lv < int(it.get("unlock_level", 1))
		var owned3: bool = Game.room_has_item(selected_room, it.id)
		var meta := "SP +%d" % int(it.sp)
		if locked:
			meta = tr("unlocks at level %d") % int(it.unlock_level)
		elif owned3:
			meta = "owned ✓"
		var price_text := ""
		if not locked and not owned3:
			price_text = "%d ◆" % int(it.get("gem_price", 0)) if premium else tr("%s coins") % _fmt(int(it.price))
		var b := _row(c, "res://assets/items/%s.svg" % it.id, String(it.name), meta, price_text,
			not locked and not owned3 and Game.can_afford_item(it),
			PALETTE.green_deep if premium else PALETTE.wood)
		if not locked and not owned3:
			var iid: String = it.id
			b.pressed.connect(func():
				if Game.buy_item(selected_room, iid):
					_play("buy")
					_show_toast(tr("%s placed (+%d SP)") % [tr(String(Game.item_def(iid).name)), int(Game.item_def(iid).sp)])
					_maybe_show_upgrade_ad())
	_add_manage_buttons(c)


func _build_facility_popup(c: VBoxContainer) -> void:
	if selected_room < 0 or selected_room >= Game.rooms.size():
		return
	var room: Dictionary = Game.rooms[selected_room]
	var d: Dictionary = Game.room_def(room.type)
	var meta := "Cleans dirty rooms by itself — income never stops."
	if d.category == "facility":
		meta = tr("+%d coins/hour base income · adds to star variety") % int(d.base_income)
	_row(c, "res://assets/rooms/%s.svg" % room.type, String(d.name), meta, "", true).disabled = true
	_add_manage_buttons(c)


## Oda popup'larının ortak yönetim satırı: Taşı + onaylı Sat.
func _add_manage_buttons(c: VBoxContainer) -> void:
	_section(c, "Manage")
	if not build_mode:
		c.add_child(_label("Turn on Build Mode first to move or sell.", 12, PALETTE.muted))
		return
	var ridx := selected_room
	var mv := _action(c, "Move room", "Pick an empty block for it")
	mv.pressed.connect(func():
		move_from = String(Game.rooms[ridx].id)
		_close_popup()
		_show_toast("Tap an empty cell — tap your room again to cancel"))
	var sell_text := tr("Sell — +%s coins") % _fmt(Game.room_sell_value(ridx))
	var sell_gems := Game.room_sell_gem_value(ridx)
	if sell_gems > 0:
		sell_text += " +%s" % _count(sell_gems, "gem")
	var sl := _danger(c, sell_text, "Everything placed in it is gone for good")
	sl.pressed.connect(func():
		if not sl.get_meta("armed", false):
			sl.set_meta("armed", true)
			_row_set(sl, "Tap again to sell", "Are you sure?")
			return
		if Game.sell_room(ridx):
			_play("buy")
			_close_popup()
			_show_toast("Room sold — the refund is in the till")
		else:
			_show_toast("You can't sell your last room!"))


## Profil ile (bkz. _build_profile_popup) ve tests/shot.gd'nin "stats" test
## anahtarıyla paylaşılan asıl istatistik içeriği — alt bardaki ayrı
## İstatistik ikonu kaldırıldı, artık yalnızca Profil üzerinden erişilir.
func _add_stats_rows(c: VBoxContainer) -> void:
	var rows := [
		["Total income collected", tr("%s coins") % _fmt(Game.stat_collected_total)],
		["Collections", str(Game.stat_collects)],
		["Rooms cleaned", str(Game.stat_cleans)],
		["Shifts started", str(Game.stat_shifts)],
		["Rooms", tr("%s (%d / %d blocks used)") % [_count(Game.rooms.size(), "room"), _blocks_used(), Game.max_slots()]],
		["Facility variety", "%d / 5" % Game.facility_diversity()],
		["Star rating", "%d / 5" % Game.star_rating()],
		["Level", "%d (XP %s)" % [Game.level(), _fmt(Game.xp)]],
		["Income per hour (now)", tr("%.0f coins") % Game.hourly_income()],
		["Prestige multiplier", tr("×%.2f (prestige %d)") % [Game.prestige_mult(), Game.prestige_level]],
		["Daily login streak", _count(Game.daily_streak, "day")],
	]
	# Prototipteki gruplu tablo: tek beyaz kutu, satırlar ince çizgiyle ayrık.
	var sv := _list_card(c)
	for r in rows:
		_list_row(sv, String(r[0]), String(r[1]))
	_section(c, tr("Shift history (last %d)") % Game.shift_history.size())
	if Game.shift_history.is_empty():
		c.add_child(_label("No shift has been started yet.", 12, PALETTE.muted))
		return
	var hv := _list_card(c)
	var bias: int = int(Time.get_time_zone_from_system().bias) * 60
	for i in range(Game.shift_history.size() - 1, -1, -1):
		var h: Dictionary = Game.shift_history[i]
		var dt := Time.get_datetime_dict_from_unix_time(int(float(h.at)) + bias)
		_list_row(hv, tr("%02d.%02d %02d:%02d — %dh") % [dt.day, dt.month, dt.hour, dt.minute, int(h.hours)],
			tr("%s coins") % _fmt(int(h.cost)))


func _build_stats_popup(c: VBoxContainer) -> void:
	_add_stats_rows(c)


## Üst bardaki avatara dokununca açılır. Dört sekme: Account / Prestige /
## Statistics / ⚙ Settings. Premium ürünler burada DEĞİL — gerçek para ve gem
## harcanan her şey Store'a taşındı (audit 7-8), burada yalnızca "benim
## hesabım ve geçmişim" duruyor.
func _build_profile_popup(c: VBoxContainer) -> void:
	var pick := func(k: String):
		_profile_tab = k
		_rebuild_popup()
		popup_scroll.scroll_vertical = 0
	_popup_tab_row(c, [
		["account", "Account"], ["prestige", "Prestige"],
		["stats", "Stats"], ["settings", "⚙ Settings"],
	], _profile_tab, pick)
	match _profile_tab:
		"prestige":
			_add_prestige_rows(c)
		"stats":
			_add_stats_rows(c)
		"settings":
			_build_settings_popup(c)
		_:
			_add_account_rows(c)


func _add_account_rows(c: VBoxContainer) -> void:
	_build_cloud_section(c)


func _add_prestige_rows(c: VBoxContainer) -> void:
	var v := _card(c)
	v.add_child(_label(tr("Prestige — multiplier ×%.2f (round %d)") % [
		Game.prestige_mult(), Game.prestige_level], 14, PALETTE.wood_dark))
	var min_lv := int(Game.eco.prestige.min_level)
	if not Game.can_prestige():
		v.add_child(_label(tr("Prestige requires level %d (you are %d).") % [min_lv, Game.level()], 11, PALETTE.muted))
		_bar(c, float(Game.level()) / maxf(1.0, float(min_lv)))
		c.add_child(_label(tr("Level %d of %d") % [Game.level(), min_lv], 11, PALETTE.muted))
		return
	var next_mult: float = Game.prestige_mult() + float(Game.eco.prestige.mult_gain)
	var p_b := _action(c, "Prestige the hotel", tr("New multiplier ×%.2f") % next_mult, true, "primary")
	p_b.pressed.connect(func():
		if p_b.get_meta("armed", false):
			Game.do_prestige()
			_close_popup()
			_show_toast(tr("Prestiged! New income multiplier: ×%.2f") % Game.prestige_mult())
		else:
			p_b.set_meta("armed", true)
			_row_set(p_b, "Tap again to prestige", "Progress will be reset"))
	_notice(c, "Prestige resets your coins, rooms, quests and achievements; the multiplier is permanent.", "dark")


## Profil popup'ının "Hesap / Bulut kaydı" bölümü.
##
## Bulut kapalıyken (yapılandırma placeholder'da ya da web demosunda, bkz.
## CloudSave.is_enabled()) bölüm yalnızca durumu söyler: kayıt bu cihazda
## duruyor. Elle taşıma yolu artık YOK — paylaşılabilir kayıt kodu arayüzü
## kaldırıldı, çünkü hesap bağlama aynı işi iki gerçek cihazda kanıtlanmış
## şekilde yapıyor ve iki ayrı taşıma yolu yalnızca kafa karıştırıyordu.
func _build_cloud_section(c: VBoxContainer) -> void:
	var v := _card(c)
	# Not: prototipteki bulut ikonu burada KULLANILAMAZ — `cloud.svg` beyaz
	# gövdeli bir gökyüzü bulutu, beyaz kartın üstünde görünmüyor.
	v.add_child(_label("Account", 13, PALETTE.text))
	if not CloudSave.is_enabled():
		# İki ayrı durum, tek dal: web demosunda bulut BİLEREK kapalı, masaüstü
		# derlemesinde ise yapılandırma eksik olabilir. Oyuncunun bilmesi gereken
		# ikisinde de aynı: kayıt nerede duruyor.
		if OS.has_feature("demo"):
			v.add_child(_label_wrap("This is the browser demo — your hotel is saved in this browser only, and it does not carry over to the phone version.", 11, PALETTE.muted))
		else:
			v.add_child(_label_wrap("Cloud save is not enabled in this build — your hotel is saved on this device only.", 11, PALETTE.muted))
		# Bulut tamamen kapalıyken bağlamanın anlamı yok: bağlanacak bir kayıt
		# yok. "Coming soon" DEMEZ — kod hazır, eksik olan bu derlemenin
		# yapılandırması; oyuncuya söz vermek yerine durumu söylüyoruz.
		_inert(v, "Link with Google — unavailable in this build")
		return

	if CloudSave.has_conflict():
		v.add_child(_label_wrap("The cloud holds different progress than this device. You decide which one to keep.", 11, PALETTE.red_text))
		var pick_b := _danger(v, "Choose a save", "Cloud / This device", true)
		pick_b.pressed.connect(func(): _show_cloud_conflict_modal())

	var who := "Linked to this device (anonymous)" if not CloudSave.is_linked() else "Linked to a Google account"
	v.add_child(_label_wrap(who, 12, PALETTE.text))
	v.add_child(_label(tr("Last backup: %s") % _cloud_sync_text(), 11, PALETTE.muted))

	if CloudSave.is_linked():
		_inert(v, "Your account is linked")
		# Bağlama tek yönlü bir kapı olmamalı: paylaşılan cihaz ya da yanlış
		# hesapla giriş gerçek bir ihtimal (giriş akışı bu yüzden hesap seçtiriyor).
		# Dolu kırmızı DEĞİL — bu bir silme değil, geri alınabilir bir ayrılma;
		# "Reset save" satırıyla aynı yumuşak kırmızı ve aynı iki dokunuşlu onay.
		var unlink_b := _danger(v, "Disconnect account",
			"Your progress stays on this device")
		unlink_b.pressed.connect(func():
			if not unlink_b.get_meta("armed", false):
				unlink_b.set_meta("armed", true)
				_row_set(unlink_b, "Tap again to disconnect", "Backups will stop")
				return
			var res: Dictionary = CloudSave.unlink_account()
			_show_toast(String(res.get("msg", "")))
			_rebuild_popup())
		v.add_child(_label_wrap("Disconnecting leaves the cloud copy on that Google account — sign in again to get it back. This device keeps playing, but it starts a fresh backup.", 11, PALETTE.muted))
		return

	if not CloudSave.is_account_linking_available():
		# Giriş akışı ARTIK bir platform eklentisi istemiyor (saf GDScript,
		# sistem tarayıcısı + PKCE — bkz. src/cloud/google_signin.gd); eksik olan
		# tek şey bu derlemede bulunmayan OAuth istemci dosyası
		# (src/cloud/google_oauth_client.gd, gitignore'lu). O yokken yedekleme
		# yine çalışır, yalnızca cihaz değişiminde geri alınamaz.
		_inert(v, "Link with Google — unavailable in this build")
		v.add_child(_label_wrap("Account linking isn't set up in this build. Your save is still backed up to the cloud, but you need a linked account to open it on a new device.", 11, PALETTE.muted))
		return

	# Bağlama SİSTEM TARAYICISINA çıkar: oyuncu uygulamadan ayrılır, girişi orada
	# yapar ve elle geri döner — bu await dakikalarca sürebilir. Bu yüzden (a)
	# oyuncuya ne olacağı BASMADAN ÖNCE söylenir, (b) düğme kilitlenir ve (c)
	# durum CloudSave'de tutulur: popup arada yeniden çizilirse (state_changed /
	# status_changed) düğme yeniden basılabilir hâle GELMEZ.
	if CloudSave.is_linking():
		_inert(v, "Waiting for your browser…")
	else:
		var link_b := _action(v, "Link with Google", "", true, "primary")
		link_b.pressed.connect(func():
			link_b.disabled = true
			_row_set(link_b, "Waiting for your browser…")
			_show_toast("Opening your browser — sign in there, then come back to the game.")
			var res: Dictionary = await CloudSave.link_google()
			_show_toast(String(res.get("msg", "")))
			# Popup bu arada kapanmış olabilir; _rebuild_popup kendi kapısını
			# tutuyor (bkz. oradaki not).
			_rebuild_popup())
	v.add_child(_label_wrap("Linking opens your browser. Sign in with Google there, then switch back to the game — closing this screen cancels it.", 11, PALETTE.muted))


## Prototipteki tıklanamaz durum şeridi (`background:#f7f1e2`, ortalanmış soluk
## metin) — "bu derlemede yok" / "bağlandı" gibi bilgi satırları için.
func _inert(c: VBoxContainer, text: String) -> void:
	var p := PanelContainer.new()
	p.mouse_filter = MOUSE_PASSTHROUGH
	var sb := StyleBoxFlat.new()
	sb.bg_color = PALETTE.field
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(10)
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.add_child(p)
	var l := _label_wrap(text, 11, PALETTE.muted)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)


## Son senkron durumunun tek satırlık özeti.
func _cloud_sync_text() -> String:
	var at: float = CloudSave.last_success_unix()
	if at <= 0.0:
		return tr("not yet")
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
		return tr("just now")
	if diff < 3600.0:
		return tr("%s ago") % _count(int(diff / 60.0), "minute")
	if diff < 86400.0:
		return tr("%s ago") % _count(int(diff / 3600.0), "hour")
	return tr("%s ago") % _count(int(diff / 86400.0), "day")


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

	var shell := _modal_shell(0.6, 560, 95, 12)
	var dim: ColorRect = shell[0]
	var pv: VBoxContainer = shell[1]
	pv.add_child(_label("Which save should continue?", 20, PALETTE.wood_dark))
	pv.add_child(_label_wrap("There are two different saves, one in the cloud and one on this device. They are never merged automatically — pick one and the other stays as it is.", 12, PALETTE.muted))

	# Prototipteki düzen: iki YAN YANA kart, seçim butonu her kartın kendi
	# içinde. Eskiden özetler kartsız iki sütun, butonlar ise altta ayrı bir
	# yığındı — hangi butonun hangi sütuna ait olduğu okunmuyordu.
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 12)
	pv.add_child(cols)
	var cloud_card := _cloud_side_card("Cloud",
		int(cloud.get("level", 0)), int(cloud.get("coins", 0)),
		int(cloud.get("gems", 0)), int(cloud.get("rooms", 0)),
		_fmt_relative(cloud_at) if cloud_at > 0.0 else tr("time unknown"),
		"Use this one")
	cols.add_child(cloud_card)
	var local_card := _cloud_side_card("This device",
		Game.level(), Game.coins, Game.gems, Game.rooms.size(), "now",
		"Use this one")
	cols.add_child(local_card)

	var closed := false
	var do_close := func():
		if closed:
			return
		closed = true
		_cloud_conflict_open = false
		dim.queue_free()
		if on_closed.is_valid():
			on_closed.call()

	var cloud_b: Button = cloud_card.get_meta("button")
	cloud_b.pressed.connect(func():
		var ok: bool = CloudSave.resolve_keep_cloud()
		do_close.call()
		_show_toast("Cloud save loaded" if ok else "The cloud save could not be read; this device's save was kept")
		_refresh())

	var local_b: Button = local_card.get_meta("button")
	local_b.pressed.connect(func():
		do_close.call()
		_show_toast("Kept this device's save and uploading it to the cloud")
		await CloudSave.resolve_keep_local())

	# Çakışma modalı dışına tıklayarak KAPATILAMAZ: kararı ertelemek, seçim
	# yapılana dek buluta hiç yazılmaması demek — oyuncunun bunu fark etmeden
	# oynamaya devam etmesi daha kötü bir durum.
	add_child(dim)
	_play("tap")


## Çakışma modalının bir tarafı: beyaz kart + özet + kendi seçim butonu.
## Buton çağırana `get_meta("button")` ile döner (kart oluşturulurken kapanış
## callable'ı henüz tanımlı değil).
func _cloud_side_card(title: String, lv: int, coins: int, gems: int,
		rooms: int, when: String, action_text: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = MOUSE_PASSTHROUGH
	var sb := StyleBoxFlat.new()
	sb.bg_color = PALETTE.card
	sb.border_color = PALETTE.facade_line
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(11)
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	p.add_child(box)
	box.add_child(_label(title, 16, PALETTE.wood_dark))
	box.add_child(_label(when, 11, PALETTE.muted))
	box.add_child(_label(tr("Level %d") % lv, 13, PALETTE.text))
	box.add_child(_label(tr("%s coins") % _fmt(coins), 13, PALETTE.text))
	box.add_child(_label(_count(gems, "gem"), 13, PALETTE.text))
	box.add_child(_label(_count(rooms, "room"), 13, PALETTE.text))
	box.add_child(_spacer_y(2))
	var b := _menu_button(action_text, 13)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(b)
	p.set_meta("button", b)
	return p


## Popup içi sekme şeridi. Seçim popup dışında (üye değişkende) durur, çünkü
## popup her state_changed'de baştan kurulur.
func _popup_tab_row(c: VBoxContainer, tabs: Array, current: String, on_pick: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	c.add_child(row)
	for t in tabs:
		var key: String = String(t[0])
		var active: bool = key == current
		# Hap sekme: `border-radius:999px; padding:7px 12px`. Seçili sekme
		# BEYAZ + altın kenar, seçilmeyen krem zemine karışır — dolu altın
		# sayfada tek bir yere ayrıldı (bkz. _menu_btn_colors "primary").
		var b := _button(String(t[1]), 11,
			PALETTE.card if active else PALETTE.field,
			PALETTE.text if active else PALETTE.muted)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.mouse_filter = MOUSE_SCROLLABLE
		for state in ["normal", "hover", "pressed", "disabled"]:
			var sb := b.get_theme_stylebox(state) as StyleBoxFlat
			sb.set_corner_radius_all(999)
			sb.content_margin_top = 14
			sb.content_margin_bottom = 14
			sb.content_margin_left = 24
			sb.content_margin_right = 24
			sb.border_color = PALETTE.gold if active else PALETTE.field
		b.pressed.connect(func(): on_pick.call(key))
		row.add_child(b)


## Mağaza: gem veya gerçek parayla alınan HER ŞEY burada. Coin harcanan hiçbir
## şey buraya girmez (o taraf Build ve oda ekranı) — dekor paketleri ve
## auto-renew coin fiyatlı olduğu için prototipin aksine Store'da DEĞİL.
func _build_store_popup(c: VBoxContainer) -> void:
	var pick := func(k: String):
		_store_tab = k
		_rebuild_popup()
		popup_scroll.scroll_vertical = 0
	_popup_tab_row(c, [["gems", "Gems"], ["premium", "Premium"]], _store_tab, pick)
	match _store_tab:
		"premium":
			_add_premium_rows(c)
		_:
			_build_gems_popup(c)


## Kalıcı ürünler + geri yükleme. Remove Ads ve 2x buraya Profile'dan taşındı
## (audit 7): gerçek parayla alınan her şeyin tek adresi Store.
func _add_premium_rows(c: VBoxContainer) -> void:
	if Game.remove_ads:
		_row(c, "res://assets/ui/ad_video.png", "Remove Ads", "Owned — thank you!",
			"✓", false, PALETTE.green_deep)
	else:
		var no_ads_b := _buy_row(c, "res://assets/ui/ad_video.png", "Remove Ads",
			"One-time purchase", IAP.price_for(IAP.PRODUCT_REMOVE_ADS, "$4.99"))
		no_ads_b.pressed.connect(func():
			IAP.purchase(IAP.PRODUCT_REMOVE_ADS, func(ok: bool):
				if ok:
					Game.remove_ads = true
					Game.save_game()
					_play("buy")
					_show_toast("Ads removed!")
					_rebuild_popup()))
	if Game.permanent_income_mult > 1.0:
		_row(c, "res://assets/ui/dollar.png", "Double Your Earnings",
			tr("Active — income ×%.1f") % Game.permanent_income_mult, "✓", false, PALETTE.green_deep)
	else:
		var x2_b := _buy_row(c, "res://assets/ui/dollar.png", "Double Your Earnings",
			"Permanent ×2, offline included", IAP.price_for(IAP.PRODUCT_INCOME_2X, "$9.99"))
		x2_b.pressed.connect(func():
			IAP.purchase(IAP.PRODUCT_INCOME_2X, func(ok: bool):
				if ok:
					Game.permanent_income_mult = 2.0
					Game.save_game()
					_play("buy")
					_show_toast("Earnings doubled!")
					_rebuild_popup()))

	# Auto-renew BİLEREK burada değil: coin ile alınıyor, kural para birimine
	# göre — coin harcanan her şey oyun tarafında kalır. Yeri Shift popup'ı
	# (bkz. _add_auto_renew_shop).
	_add_restore_purchases_row(c)


## Play politikası tüketilmeyen ürünler için geri yükleme yolu istiyor
## (denetim kritik madde 1). Kanonik yer burası; Ayarlar'daki satır buraya
## getirir, ikinci bir akış yazılmaz.
##
## Beyaz liste satırı olarak eklenir (prototipteki "Restore purchases" satırı:
## bulut ikonu, açıklama, sağda "Restore" rozeti).
func _add_restore_purchases_row(c: VBoxContainer) -> void:
	var r_b := _row(c, "", "Restore purchases",
		"Brings back Remove Ads and ×2 on a new device", "Restore")
	r_b.pressed.connect(func():
		if IAP.restore_purchases():
			_show_toast("Checking the store for your earlier purchases…")
		else:
			_show_toast("The store is not reachable right now — try again later."))


## Hazır dekor paketleri (coin fiyatlı, bu yüzden Build'in altında). Oda
## ekranından da alınabiliyor; burada önce paket, sonra oda seçiliyor — yığın
## sayesinde geri dönüş çalışıyor.
##
## KENDİ bölüm etiketini yazmaz (bkz. _section): çağıran zaten "Decor sets"
## etiketini koyuyor.
func _add_offer_rows(c: VBoxContainer) -> void:
	var bundles: Array = Game.eco.get("bundles", [])
	if bundles.is_empty():
		c.add_child(_label("No offers right now — check back later.", 12, PALETTE.muted))
		return
	for bd in bundles:
		var sp_total := 0
		for iid in bd.items:
			sp_total += int(Game.item_def(iid).sp)
		var need_lv := Game.bundle_unlock_level(bd)
		var locked := Game.level() < need_lv
		var b := _sheet_row(c, {
			"bg": Color("f2faf5"), "border": PALETTE.green_deep, "radius": 13,
			"title": String(bd.name),
			"meta": tr("unlocks at level %d") % need_lv if locked else tr("SP +%d · %%%d off") % [sp_total, int(float(bd.discount) * 100.0)],
			"right": "" if locked else tr("%s coins") % _fmt(Game.bundle_price(bd)),
			"right_color": PALETTE.green_deep,
			"enabled": not locked and Game.can_buy_bundle(bd),
		})
		if not locked:
			var bid: String = bd.id
			b.pressed.connect(func():
				_pending_bundle_id = bid
				_push_popup("Choose a room", _build_bundle_room_picker))
	c.add_child(_label_wrap("Pick a set, then pick the room it goes into.", 11, PALETTE.muted))


func _build_bundle_room_picker(c: VBoxContainer) -> void:
	var bd := Game.bundle_def(_pending_bundle_id)
	if bd.is_empty():
		c.add_child(_label("That set is no longer available.", 12, PALETTE.muted))
		return
	var head := _card(c)
	head.add_child(_label(tr("%s — %s coins") % [tr(String(bd.name)), _fmt(Game.bundle_price(bd))], 14, PALETTE.wood_dark))
	head.add_child(_label("Which room should it decorate?", 11, PALETTE.muted))
	if Game.rooms.is_empty():
		c.add_child(_label("You have no rooms yet — build one first.", 12, PALETTE.muted))
		return
	var bid := _pending_bundle_id
	for i in Game.rooms.size():
		var room: Dictionary = Game.rooms[i]
		var idx := i
		var b := _row(c, _room_icon_path(String(room.type)),
			String(Game.room_def(room.type).name),
			"%s · SP %d" % [tr(Game.tier_name(Game.room_tier(room))), Game.room_score(room)])
		b.pressed.connect(func():
			if Game.buy_bundle(idx, bid):
				_play("buy")
				_show_toast(tr("%s placed!") % tr(String(Game.bundle_def(bid).name)))
				_pop_popup()
				_maybe_show_upgrade_ad()
			else:
				_show_toast("Not enough coins for that set"))


## Prototipteki oda/tesis karosu: 3'lü ızgarada beyaz kutu — üstte ikon, altında
## ad ve fiyat, ortalanmış. Kilitliyken sönük.
func _tile(grid: GridContainer, icon_path: String, name: String, meta: String,
		enabled: bool) -> Button:
	var p := PanelContainer.new()
	p.mouse_filter = MOUSE_PASSTHROUGH
	var sb := StyleBoxFlat.new()
	sb.bg_color = PALETTE.card
	sb.border_color = PALETTE.facade_line
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(10)
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not enabled:
		p.modulate.a = 0.5
	grid.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	var wrap := CenterContainer.new()
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(_icon(icon_path, 40))
	v.add_child(wrap)
	var n := _label_wrap(name, 11, PALETTE.text)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(n)
	var m := _label_wrap(meta, 10, PALETTE.wood)
	m.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(m)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = MOUSE_SCROLLABLE
	b.disabled = not enabled
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	p.add_child(b)
	return b


## Oda tipinin listelerde kullanılacak ikonu. Misafir odalarının (standard /
## deluxe / suite) `assets/rooms/` altında kendi görseli YOK — prototip de
## onları yatak görselleriyle temsil ediyor.
const ROOM_LIST_ICONS := {
	"standard": "res://assets/items/bed_basic.svg",
	"deluxe": "res://assets/items/bed_wood.svg",
	"suite": "res://assets/items/bed_canopy.svg",
}


func _room_icon_path(type: String) -> String:
	return String(ROOM_LIST_ICONS.get(type, "res://assets/rooms/%s.svg" % type))


## Build ekranındaki 3'lü oda ızgarası. `category` "guest" ise yalnızca misafir
## odaları, boşsa misafir OLMAYAN her şey (tesisler + housekeeping).
func _add_room_tiles(c: VBoxContainer, title: String, category: String) -> void:
	var types: Array = []
	for type in Game.eco.room_types:
		var is_guest: bool = String(Game.room_def(type).category) == "guest"
		if is_guest == (category == "guest"):
			types.append(type)
	if types.is_empty():
		return
	_section(c, title)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	c.add_child(grid)
	for type: String in types:
		var d: Dictionary = Game.room_def(type)
		var need_lv := int(d.unlock_level)
		var locked := Game.level() < need_lv
		var t: String = type
		var tile := _tile(grid, _room_icon_path(type), String(d.name),
			tr("%s · Lv.%d") % [_fmt(int(d.price)), need_lv] if locked else _fmt(int(d.price)),
			not locked and Game.can_buy_room(type))
		if not locked:
			tile.pressed.connect(func():
				if Game.buy_room(t):
					_play("buy")
					_show_toast(tr("%s built!") % tr(String(Game.room_def(t).name)))
					_maybe_show_upgrade_ad())


## İnşa: coin harcanan yapısal alımlar. Oda tek tek buradan da alınabilir
## (otomatik yerleşir), sürükle-bırak için İnşa Modu açılır.
func _build_build_popup(c: VBoxContainer) -> void:
	_notice(c, "Build Mode is a canvas tool, not a tab: the hotel stays visible, empty blocks light up, and this tray is what you place from.", "gold")
	c.add_child(_label(tr("Blocks used: %d / %d · floors %d") % [
		_blocks_used(), Game.max_slots(), Game.floors], 11, PALETTE.muted))
	# Prototip 349'daki blok fiyatı satırı. Fiyat kata göre değişiyor (kat ne
	# kadar genişlediyse o kadar pahalı), bu yüzden tek bir sayı yerine hâlâ
	# genişletilebilen katların en ucuzu yazılır.
	var cheapest_block := -1
	var grid_cols := int(Game.eco.building.grid_cols)
	for floor_i in range(1, Game.floors + 1):
		if Game.floor_open_width(floor_i) >= grid_cols:
			continue
		var price := Game.block_price(floor_i)
		if cheapest_block < 0 or price < cheapest_block:
			cheapest_block = price
	if cheapest_block >= 0:
		c.add_child(_label("Empty blocks: from %s coins each — widen a floor in Build Mode."
			% _fmt(cheapest_block), 11, PALETTE.muted))

	# Prototip misafir odalarını ve tesisleri ayrı ızgaralarda gösteriyor —
	# ikisi farklı karar: biri gelir kapasitesi, diğeri yıldız çeşitliliği.
	_add_room_tiles(c, "Guest rooms", "guest")
	_add_room_tiles(c, "Facilities", "")

	if Game.floors < int(Game.eco.building.max_floors):
		var f_b := _action(c, tr("Unlock a new floor — %s coins") % _fmt(Game.floor_price()),
			"", Game.can_buy_floor(), "primary")
		f_b.pressed.connect(func():
			if Game.buy_floor():
				_play("buy")
				_show_toast("New floor unlocked!")
				_maybe_show_upgrade_ad())

	_section(c, "Decor sets")
	_add_offer_rows(c)

	var bm_b := _action(c, "✎ Open Build Mode", "Place rooms yourself")
	bm_b.pressed.connect(func():
		build_mode_button.button_pressed = true
		_close_popup()
		_show_toast("Build Mode is on — drag a room from the shelf onto the building"))


## Tasarımdaki elmas paketi karosu: beyaz kutu, ortalanmış ikon + miktar, altta
## tam genişlik fiyat hapı. `popular` olan karo kırmızı kenarlı, dolu kırmızı
## fiyat hapı ve üstünde "MOST POPULAR" rozeti taşır.
##
## Rozet, karonun İÇİNDE en üstte durur ve rozetsiz karolar aynı yükseklikte
## boş bir yuva alır — böylece üç karonun ikonları aynı hizada kalır.
func _gem_tile(row: HBoxContainer, amount: int, price: String, popular: bool,
		icon_px: int) -> Button:
	var p := PanelContainer.new()
	p.mouse_filter = MOUSE_PASSTHROUGH
	var sb := StyleBoxFlat.new()
	sb.bg_color = PALETTE.card
	sb.border_color = PALETTE.gold if popular else PALETTE.facade_line
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(13)
	sb.content_margin_left = 9
	sb.content_margin_right = 9
	sb.content_margin_top = 9
	sb.content_margin_bottom = 11
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(p)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)

	var badge_slot := CenterContainer.new()
	badge_slot.custom_minimum_size = Vector2(0, 18)
	badge_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(badge_slot)
	if popular:
		var badge := PanelContainer.new()
		var bsb := StyleBoxFlat.new()
		bsb.bg_color = PALETTE.gold
		bsb.set_corner_radius_all(999)
		bsb.content_margin_left = 8
		bsb.content_margin_right = 8
		bsb.content_margin_top = 2
		bsb.content_margin_bottom = 2
		badge.add_theme_stylebox_override("panel", bsb)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_child(_label("MOST POPULAR", 8, PALETTE.text))
		badge_slot.add_child(badge)

	var ic := _icon("res://assets/ui/gem.svg", icon_px)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)

	var amount_l := _label(_fmt(amount), 15 if popular else 13, PALETTE.text)
	amount_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(amount_l)

	var pill := PanelContainer.new()
	var psb := StyleBoxFlat.new()
	psb.bg_color = PALETTE.gold if popular else PALETTE.pill_cream
	psb.border_color = PALETTE.gold.darkened(0.18) if popular else PALETTE.gold
	psb.set_border_width_all(2)
	psb.set_corner_radius_all(9)
	psb.content_margin_left = 4
	psb.content_margin_right = 4
	psb.content_margin_top = 10
	psb.content_margin_bottom = 10
	pill.add_theme_stylebox_override("panel", psb)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(pill)
	var price_l := _label(price, 11, PALETTE.text)
	price_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pill.add_child(price_l)

	# Satır primitifiyle aynı hile: görünen kutu panel, tıklama üstteki
	# şeffaf buton (bkz. _sheet_row).
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = MOUSE_SCROLLABLE
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	b.set_meta("title_label", amount_l)
	b.set_meta("panel", p)
	p.add_child(b)
	return b


func _build_gems_popup(c: VBoxContainer) -> void:
	c.add_child(_label_wrap("Prices are set in the store (Play Console) — the ones below are suggestions.", 11, PALETTE.muted))
	# Tasarımdaki blok: paketler alt alta satır değil, yan yana üçlü karo —
	# oyuncu üçünü tek bakışta karşılaştırsın diye. Ortadaki vurgulu.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	c.add_child(row)
	# İkon boyu paketle birlikte büyür (tasarım: 26 / 30 / 34 px).
	var icon_sizes := [26, 30, 34]
	for i in GEM_PACKS.size():
		var pack: Dictionary = GEM_PACKS[i]
		var product: String = pack.product
		var amount: int = pack.gems
		var b := _gem_tile(row, amount, IAP.price_for(product, pack.price),
			i == 1, int(icon_sizes[mini(i, icon_sizes.size() - 1)]))
		b.pressed.connect(func():
			IAP.purchase(product, func(ok: bool):
				if ok:
					# Elmasları BU callback eklemez — ekleme tek yerde,
					# _on_purchase_restored'da. Böylece uygulama satın alma ile
					# ödül arasında öldürülse bile elmaslar bir sonraki açılışta
					# mağaza sorgusundan gelir (oyuncu parayı ödeyip boşa
					# düşmez); burada iki kez eklenmesi de imkânsız olur.
					_play("buy")
					_show_toast(tr("%s added!") % _count(amount, "gem"))
					_rebuild_popup()))
	_add_premium_teaser(c)


## Premium sekmesine köprü. İki kalıcı ürün (Remove Ads, ×2) sekmenin arkasında
## duruyordu ve Store hep Gems'te açıldığı için çoğu oyuncu tekliflerin
## VARLIĞINDAN habersiz kalıyordu. Ayrı bir kart yerine tek satırlık bir bağlantı:
## elmas paketlerinin önüne geçmez, ama teklifler görünür olur. Her ikisi de
## alınmışsa satır hiç çizilmez.
func _add_premium_teaser(c: VBoxContainer) -> void:
	if Game.remove_ads and Game.permanent_income_mult > 1.0:
		return
	var missing: Array[String] = []
	# Ürün adları burada BİRLEŞTİRİLDİĞİ için tek tek çevrilmeli — birleşmiş
	# dize artık bir çeviri anahtarı değil.
	if not Game.remove_ads:
		missing.append(tr("Remove Ads"))
	if Game.permanent_income_mult <= 1.0:
		missing.append(tr("Double Your Earnings"))
	var t_b := _row(c, "res://assets/ui/dollar.png", " · ".join(missing),
		"One-time purchases, no ads or timers involved", "›")
	t_b.pressed.connect(func():
		_store_tab = "premium"
		_rebuild_popup()
		popup_scroll.scroll_vertical = 0)


func _build_settings_popup(c: VBoxContainer) -> void:
	var s_b := _action(c, tr("Sound effects: %s") % (tr("On") if Game.sound_on else tr("Off")), "",
		true, "primary" if Game.sound_on else "outline")
	s_b.pressed.connect(func():
		Game.sound_on = not Game.sound_on
		Game.save_game()
		_play("tap")
		_rebuild_popup())

	var m_b := _action(c, tr("Lobby music: %s") % (tr("On") if Game.music_on else tr("Off")), "",
		true, "primary" if Game.music_on else "outline")
	m_b.pressed.connect(func():
		Game.music_on = not Game.music_on
		music_player.playing = Game.music_on
		Game.save_game()
		_rebuild_popup())

	# Dil seçici. Üç seçenek olduğu için ayrı bir liste ekranı yerine aynı
	# ses/müzik satırlarındaki gibi dokundukça sırayla dolaşan tek bir satır —
	# seçili dilin adı KENDİ dilinde yazılır, yanlış dile düşen oyuncu da
	# kendi dilini tanıyıp geri dönebilsin diye.
	var l_b := _action(c, tr("Language: %s") % tr(Game.language_name()), "", true)
	l_b.pressed.connect(func():
		Game.cycle_language()
		_play("tap")
		# Sabit metinleri Godot kendisi yeniden çevirir (auto_translate);
		# elle `%` ile kurulanlar için canlı etiketleri ve popup'ı tazele.
		_update_live_labels()
		_rebuild_popup())

	# Prototipteki bağlantı listesi: tek beyaz kutu, satırlar çizgiyle ayrık,
	# sağda `›` (uygulama içi) ya da `↗` (dışarı çıkar).
	_section(c, "Support & legal")
	var lv := _list_card(c)
	_list_row(lv, "Restore purchases", "›", true).pressed.connect(func():
		if IAP.restore_purchases():
			_show_toast("Checking the store for your earlier purchases…")
		else:
			_show_toast("The store is not reachable right now — try again later."))
	_list_row(lv, "Privacy policy", "↗", true).pressed.connect(func():
		OS.shell_open(PRIVACY_POLICY_URL))
	# Reklam onayı bir kez alınıp bir daha değiştirilemiyordu (audit 4) — UMP
	# gizlilik seçenekleri formu buradan yeniden açılır.
	if Ads.consent_options_available():
		_list_row(lv, "Ad preferences", "›", true).pressed.connect(func():
			Ads.show_privacy_options_form()
			_show_toast("Opening your ad preferences…"))
	_list_row(lv, "Contact support", "↗", true).pressed.connect(func():
		OS.shell_open("mailto:%s?subject=Little%%20Grand%%20Hotel" % SUPPORT_EMAIL))

	_section(c, "Danger zone", PALETTE.banner_red)
	# "Reset save" yalnızca yerel kaydı siliyordu; buluttaki doküman kalıyordu
	# (audit 3). "Delete account data" ikisini birden siler, bu yüzden dolu
	# kırmızı; sıfırlama yumuşak kırmızı (prototipteki ayrım).
	var del_b := _danger(c, "Delete account data",
		"This device's save and the cloud copy", true)
	del_b.pressed.connect(func():
		if not del_b.get_meta("armed", false):
			del_b.set_meta("armed", true)
			_row_set(del_b, "Tap again to delete everything", "Are you sure?")
			return
		del_b.disabled = true
		var cloud_ok: bool = await CloudSave.delete_cloud_data()
		Game.reset_game()
		_close_popup()
		_show_toast("Your data was deleted." if cloud_ok else "Local data deleted — the cloud copy could not be reached.")
	)
	var r_b := _danger(c, "Reset save", "Erases all progress permanently")
	r_b.pressed.connect(func():
		if r_b.get_meta("armed", false):
			Game.reset_game()
			_close_popup()
			_show_toast("Save reset — a new game has begun!")
		else:
			r_b.set_meta("armed", true)
			_row_set(r_b, "Tap again to reset", "Are you sure?"))

	var ver := _label(tr("Little Grand Hotel · v%s") % GAME_VERSION, 10, PALETTE.muted)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(ver)


## Prototipteki iki hap sekme: Quests · Achievements. Eskiden ikisi tek uzun
## sayfada alt alta duruyordu ve sıradaki görevler hiç görünmüyordu.
func _build_quests_popup(c: VBoxContainer) -> void:
	# Ekran açıldı: birikmiş "görülmemiş" tamamlamalar sıfırlanır, rozet söner.
	_quests_seen_index = Game.quest_index
	_achievements_seen_count = Game.unlocked_achievements.size()
	var pick := func(k: String):
		_quests_tab = k
		_rebuild_popup()
		popup_scroll.scroll_vertical = 0
	_popup_tab_row(c, [["quests", "Quests"], ["achievements", "Achievements"]], _quests_tab, pick)
	if _quests_tab == "achievements":
		_add_achievement_rows(c)
	else:
		_add_quest_rows(c)


func _add_quest_rows(c: VBoxContainer) -> void:
	var q: Dictionary = Game.current_quest()
	if q.is_empty():
		_notice(c, "Every quest is done. Congratulations, hotelier!", "gold")
	else:
		# Güncel görev prototipte vurgulu kart: altın kenar, krem-sarı zemin,
		# görev ikonu, ince ilerleme çubuğu, yeşil ödül satırı.
		var p: Array = Game.quest_progress(q)
		var hero := _card(c, PALETTE.gold)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 8)
		hero.add_child(head)
		head.add_child(_icon("res://assets/ui/icon_quest.svg", 22))
		head.add_child(_label(String(q.name), 15, PALETTE.wood_dark))
		hero.add_child(_label_wrap(String(q.desc), 12, PALETTE.text))
		_bar(hero, float(mini(p[0], p[1])) / maxf(1.0, float(p[1])))
		hero.add_child(_label("%d / %d" % [mini(p[0], p[1]), p[1]], 11, PALETTE.muted))
		var reward := tr("Reward: %s coins") % _fmt(int(q.get("reward_coins", 0)))
		if int(q.get("reward_gems", 0)) > 0:
			reward += " + %s" % _count(int(q.reward_gems), "gem")
		hero.add_child(_label(reward, 12, PALETTE.green_deep))

	c.add_child(_label(tr("Quests completed: %d / %d") % [Game.quest_index, Game.quests.size()], 11, PALETTE.muted))

	# "NEXT UP" (prototip 222-249): sıradaki görevler bugüne kadar hiç
	# görünmüyordu — oyuncu neyin peşinde olduğunu ancak güncel görev bitince
	# öğreniyordu. Kilitli satır biçimi (%50 saydam) sırayı belli ediyor.
	var upcoming: Array = []
	for i in range(Game.quest_index + 1, Game.quests.size()):
		upcoming.append(Game.quests[i])
		if upcoming.size() >= 4:
			break
	if not upcoming.is_empty():
		_section(c, "Next up")
		for nq: Dictionary in upcoming:
			var nreward := tr("%s coins") % _fmt(int(nq.get("reward_coins", 0)))
			if int(nq.get("reward_gems", 0)) > 0:
				nreward += " + %s" % _count(int(nq.reward_gems), "gem")
			_row(c, "res://assets/ui/icon_quest.svg", String(nq.name), String(nq.desc),
				nreward, false, PALETTE.green_deep)


func _add_achievement_rows(c: VBoxContainer) -> void:
	_section(c, tr("Achievements — %d / %d unlocked") % [
		Game.unlocked_achievements.size(), Game.achievements.size()])
	# Tek uzun çizgili liste yerine her başarım kendi kartında (kullanıcı
	# geri bildirimi: "görevleri de ayır birbirinden"). Açılmış olan yeşil
	# kenarlı ve tam opak, kalanlar sönük.
	for a: Dictionary in Game.achievements:
		var unlocked: bool = Game.unlocked_achievements.has(String(a.id))
		var p2: Array = Game.quest_progress(a)
		_sheet_row(c, {
			"border": PALETTE.green_deep if unlocked else PALETTE.facade_line,
			"title": String(a.name),
			"title_color": PALETTE.text if unlocked else PALETTE.wood_dark,
			"meta": String(a.desc),
			"right": "✓" if unlocked else "%d / %d" % [mini(p2[0], p2[1]), p2[1]],
			"right_color": PALETTE.green_deep if unlocked else PALETTE.muted,
		}).disabled = true


# --- Geri bildirim -----------------------------------------------------

func _on_quest_completed(q: Dictionary) -> void:
	_play("quest")
	var msg := tr("Quest complete: %s — +%s coins") % [tr(String(q.name)), _fmt(int(q.get("reward_coins", 0)))]
	if int(q.get("reward_gems", 0)) > 0:
		msg += ", +%s" % _count(int(q.reward_gems), "gem")
	_show_toast(msg)


func _on_achievement_unlocked(a: Dictionary) -> void:
	_play("quest")
	var msg := tr("Achievement unlocked: %s — +%s coins") % [tr(String(a.name)), _fmt(int(a.get("reward_coins", 0)))]
	if int(a.get("reward_gems", 0)) > 0:
		msg += ", +%s" % _count(int(a.reward_gems), "gem")
	_show_toast(msg)


func _show_toast(msg: String) -> void:
	msg = tr(msg)
	toast_label.text = msg
	# Hap içeriğe göre daralsın: autowrap açık bir Label'ın minimum genişliği en
	# uzun KELİME kadardır, o yüzden ortalanmış kapta metnin gerçek genişliği
	# elle verilir (bir üst sınıra kadar; ötesinde sarar).
	var font := toast_label.get_theme_font("font")
	var fs := toast_label.get_theme_font_size("font_size")
	toast_label.custom_minimum_size.x = minf(
		font.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x, 420.0)
	toast_panel.visible = true
	_toast_timer = 3.0


func _show_offline_popup(amount: int, renew_count: int = 0, renew_spent: int = 0) -> void:
	# Prototip 372-379: süre + 24 saat tavanı, coin ikonlu tutar kartı ve iki
	# buton — Collect · "Watch an ad — double it". Eski hâli tek "Great"
	# butonlu düz metindi; ikiye katlama hiç yoktu.
	var away := Game.offline_seconds
	var cap_hours := float(Game.eco.get("offline_cap_hours", 24))
	var cap_real := cap_hours * 3600.0 / Game.time_scale
	var capped := away > cap_real
	var meta := tr("Away for %s") % _fmt_duration(away)
	if capped:
		meta += tr(" · capped at %s of hotel time") % _count(int(cap_hours), "hour")
	var lines: Array[String] = []
	if renew_count > 0:
		lines.append(tr("Your hotel didn't sit idle when the shift ended: it auto-renewed %s (staff cost %s coins).")
			% [_count(renew_count, "time"), _fmt(renew_spent)])
	var cfg := {
		"title": "Welcome back!",
		"text": "\n\n".join(lines),
		"body": func(pv: VBoxContainer):
			# Modal auto-renew yüzünden kazançsız da açılabilir — o zaman kart yok.
			# Kart tıklanamaz ama SÖNÜK DEĞİL ("enabled": false satırı %50
			# saydam yapıyor); modalın ana bilgisi bu tutar.
			if amount > 0:
				_sheet_row(pv, {
					"icon": "res://assets/ui/coin.svg",
					"title": tr("%s coins earned") % _fmt(amount), "title_size": 15,
					"meta": meta,
				}).disabled = true,
		"action_text": "Collect",
		"on_action": func(): _on_collect(),
	}
	if amount > 0:
		cfg["secondary_text"] = "Watch an ad — double it"
		cfg["secondary_icon"] = "res://assets/ui/ad_video.png"
		cfg["on_secondary"] = func():
			Ads.show_rewarded(func():
				Game.add_pending_income(amount)
				_play("buy")
				_show_toast(tr("Offline earnings doubled — +%s coins!") % _fmt(amount))
				_on_collect())
	_show_modal(cfg)


## "45m" / "3h 12m" / "2d 4h" — çevrimdışı kalınan gerçek süre.
func _fmt_duration(seconds: float) -> String:
	var total := maxi(0, int(seconds))
	var days := total / 86400
	var hours := (total % 86400) / 3600
	var minutes := (total % 3600) / 60
	if days > 0:
		return tr("%dd %dh") % [days, hours]
	if hours > 0:
		return tr("%dh %dm") % [hours, minutes]
	return tr("%dm") % maxi(1, minutes)


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
	var index := (streak - 1) % cycle.size()
	var reward: Dictionary = cycle[index]
	var reward_text := tr("%s coins") % _fmt(int(reward.get("coins", 0)))
	if int(reward.get("gems", 0)) > 0:
		reward_text += " + %s" % _count(int(reward.gems), "gem")
	_show_modal({
		"title": "Daily Reward",
		"title_icon": "res://assets/ui/sparkle.svg",
		"text": "%s\n%s" % [tr("Day %d streak!") % streak, tr("Your reward: %s") % reward_text],
		"body": func(pv: VBoxContainer): _daily_strip(pv, cycle, index),
		"action_text": "Claim",
		"on_action": func():
			var granted := Game.claim_daily_reward()
			if not granted.is_empty():
				_play("quest")
				_show_toast(tr("Daily reward claimed — day %d streak!") % Game.daily_streak)
			if on_closed.is_valid():
				on_closed.call(),
		"on_dismiss": on_closed,
	})


## Günlük ödül şeridi (prototip 360-370): D1…D7 karoları, bugünkü vurgulu,
## alınmış günler sönük. Döngü uzunluğu economy.json'dan gelir, 7 sabit değil.
func _daily_strip(c: VBoxContainer, cycle: Array, index: int) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	c.add_child(row)
	for i in cycle.size():
		var d: Dictionary = cycle[i]
		var today := i == index
		var past := i < index
		var p := PanelContainer.new()
		p.mouse_filter = MOUSE_PASSTHROUGH
		var sb := StyleBoxFlat.new()
		sb.bg_color = PALETTE.gold_soft if today else (PALETTE.cream_dark if past else PALETTE.card)
		sb.border_color = PALETTE.gold if today else PALETTE.facade_line
		sb.set_border_width_all(3 if today else 2)
		sb.set_corner_radius_all(10)
		sb.content_margin_left = 5
		sb.content_margin_right = 5
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		p.add_theme_stylebox_override("panel", sb)
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(p)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		p.add_child(v)
		var day_l := _label("D%d" % (i + 1), 10, PALETTE.wood_dark if today else PALETTE.muted)
		day_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(day_l)
		var gems := int(d.get("gems", 0))
		var ico := _icon("res://assets/ui/gem.svg" if gems > 0 else "res://assets/ui/coin.svg", 18)
		ico.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(ico)
		var amount_l := _label(
			str(gems) if gems > 0 else _fmt_short(int(d.get("coins", 0))),
			10, PALETTE.green_deep if gems > 0 else PALETTE.text)
		amount_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(amount_l)
		if past:
			p.modulate.a = 0.55


## Şerit karosuna sığan kısa sayı: 1200 -> "1.2k". Tam biçim (_fmt) yedi karoyu
## ekran dışına taşırıyor.
func _fmt_short(n: int) -> String:
	if n < 1000:
		return str(n)
	var k := float(n) / 1000.0
	return ("%.1fk" % k).replace(".0k", "k")


func _fmt_hms(game_hours: float) -> String:
	var total := int(game_hours * 3600.0)
	return "%02d:%02d:%02d" % [total / 3600, (total % 3600) / 60, total % 60]


## "1 hour" / "3 hours" — sayı ve ismi İngilizce çoğul kuralına göre birleştirir.
## Türkçede sayıdan sonra isim çoğullanmadığı için ("1 saat", "4 saat") özgün
## metinlerde bu ayrım yoktu; doğrudan çeviri "1 hours" gibi bozuk ifadeler
## üretiyordu. Düzensiz çoğullar için ikinci biçim açıkça verilir.
func _count(n: int, one: String, many: String = "") -> String:
	# Turkish (and most locales we may add) keeps the noun singular after a
	# number, so the -s is an English-only step. Deciding on the locale name
	# would be wrong: a German device shows the English UI, and that UI still
	# has to say "3 gems". The honest test is whether this noun was translated
	# at all — if it was not, English is what is on screen.
	var word := tr(one)
	if word == one:
		word = one if n == 1 else (many if many != "" else one + "s")
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
