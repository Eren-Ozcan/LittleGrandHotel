extends Node
## Reklam entegrasyonu için platform-bağımsız arayüz.
##
## Gerçek cihazda (Android derlemesinde AdMob eklentisi aktifken) Google Mobile Ads
## SDK'sını kullanır: GDPR/CCPA onam akışı (UMP) → SDK başlatma → reklamları
## önceden yükleme → gösterim. Üç format var ve her birinin YERİ ayrıdır:
## ödüllü (oyuncunun kendi bastığı, ödül veren), geçiş/interstitial (oyun
## içi doğal molalar) ve App Open (yalnızca uygulama öne gelirken).
## Eklenti yokken (masaüstü/editör/headless test —
## `tests/sim_check.gd` de dahil) mock davranış korunur: her yerde anında "izlendi"
## sayar, böylece geliştirme/test akışı reklam beklemeden çalışmaya devam eder.
##
## Uygulama Kimliği (App ID) `admob/general/android/app_id` proje ayarında tutuluyor.
##
## Kasıtlı olarak Game autoload'ına dokunmaz (bkz. iap.gd) — reklam gösterip
## göstermeme kararını (örn. "reklamlar kaldırıldı mı") çağıran verir.

signal rewarded_ad_result(success: bool)

const _REWARDED_SINGLETON := "PoingGodotAdMobRewardedAd"
const _REWARDED_AD_UNIT_ID := "ca-app-pub-9709993577664180/1269057042"
const _INTERSTITIAL_AD_UNIT_ID := "ca-app-pub-9709993577664180/5208302053"
## Uygulama öne gelince gösterilen "App Open" biriminin kimliği. AdMob'un
## politikası uygulama açılışında/öne gelişinde GEÇİŞ (interstitial) reklamı
## göstermeyi yasaklar; bu senaryonun izin verilen formatı App Open'dır
## (bkz. show_app_open). Panelde ayrıca kullanıcı başına saatte 1 gösterim
## sıklık sınırı tanımlı — koddaki soğuma sayacından bağımsız ikinci bir
## güvenlik ağı. Kimlik boş bırakılırsa show_app_open hiçbir şey yapmaz.
const _APP_OPEN_AD_UNIT_ID := "ca-app-pub-9709993577664180/8062717606"

## İki tam ekran reklam arasındaki asgari süre. Vardiya bitişi, satın alım
## eşiği ve uygulamaya dönüş aynı anda tetiklenebildiği için tek bir ortak
## soğuma sayacı tutulur: hangi formatta olursa olsun art arda iki tam ekran
## reklam çıkmaz.
const _FULL_SCREEN_AD_COOLDOWN_SEC := 5.0 * 60.0
## AdMob'un kuralı: önceden yüklenmiş bir App Open reklamı 4 saat sonra
## bayatlar, gösterilmeden atılıp yenisi yüklenmelidir.
const _APP_OPEN_MAX_CACHE_SEC := 4.0 * 60.0 * 60.0

## Soğuma sayacı burada saklanır. Yalnızca oturum içinde tutulduğunda oyuncu
## uygulamayı kapatıp açtığında sıfırlanıyordu, yani her soğuk açılışta yeni
## bir reklam hakkı doğuyordu ("her açtığımda reklam" şikâyeti). Kayıt dosyası
## bilerek save.json'dan ayrı: reklam sayacı oyun ilerlemesi değil, silinmesi
## ya da bozulması oyunu etkilemeyen bir yan bilgi.
const _STATE_PATH := "user://ads_state.json"

var _rewarded_ad: RewardedAd
var _loading := false

var _interstitial_ad: InterstitialAd
var _interstitial_loading := false

var _app_open_ad: AppOpenAd
var _app_open_loading := false
## _app_open_ad'in yüklendiği an (bayatlama kontrolü için) — bkz. _APP_OPEN_MAX_CACHE_SEC.
var _app_open_loaded_time := 0.0

## En son gösterilen tam ekran reklamın duvar saati zamanı (Unix saniye);
## 0 = hiç gösterilmedi. Ödüllü reklam da bunu günceller (ama okumaz):
## oyuncu isteyerek bir reklam izledikten hemen sonra bir de zorunlu geçiş
## reklamı yemesin.
##
## Bu tek sayaç aynı zamanda "reklamdan dönüş" tuzağını da kapatıyor: tam ekran
## bir reklam açılırken uygulama odağı kaybedip geri kazandığı için, reklamın
## kapanışı bir "uygulama öne geldi" olayı gibi görünür — soğuma paylaşıldığı
## sürece bu, arkasından bir App Open reklamı daha tetikleyemez.
var _last_full_screen_ad_time := 0.0


func _ready() -> void:
	if _real_ads_available():
		_load_state()
		_request_consent_then_init()


## Duvar saati (Unix saniye). Soğuma süresi kalıcı olduğu için oturum içi
## Time.get_ticks_msec() yerine bu kullanılır.
func _now() -> float:
	return Time.get_unix_time_from_system()


## `since`tan bu yana geçen süre. Hiç gösterilmemişse (0) ya da cihaz saati
## geriye alınmışsa INF döner — saat oynatmak oyuncuyu reklamsız bırakmasın,
## ama saatin geri gitmesi de kalıcı bir kilide yol açmasın.
func _elapsed_since(since: float) -> float:
	if since <= 0.0:
		return INF
	var delta := _now() - since
	if delta < 0.0:
		return INF
	return delta


func _load_state() -> void:
	if not FileAccess.file_exists(_STATE_PATH):
		return
	var file := FileAccess.open(_STATE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var value: Variant = (parsed as Dictionary).get("last_full_screen_ad", 0.0)
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		_last_full_screen_ad_time = maxf(0.0, float(value))


func _save_state() -> void:
	var file := FileAccess.open(_STATE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"last_full_screen_ad": _last_full_screen_ad_time}))
	file.close()


## Bir tam ekran reklam gösterildi: soğuma sayacını ilerlet ve diske yaz.
func _mark_full_screen_ad_shown() -> void:
	_last_full_screen_ad_time = _now()
	_save_state()


func _real_ads_available() -> bool:
	return OS.get_name() == "Android" and Engine.has_singleton(_REWARDED_SINGLETON)


func _request_consent_then_init() -> void:
	var consent_info := UserMessagingPlatform.consent_information
	consent_info.update(
		ConsentRequestParameters.new(),
		func():
			if consent_info.get_is_consent_form_available():
				UserMessagingPlatform.load_consent_form(
					func(form: ConsentForm): form.show(func(_err): _init_ads()),
					func(_err): _init_ads()
				)
			else:
				_init_ads(),
		func(_err): _init_ads()
	)


## Ayarlar'daki "Ad preferences" satırı yalnızca gerçekten açılabilecekse
## gösterilir: masaüstünde/test derlemesinde UMP singleton'ı yok, orada ölü bir
## buton bırakmak yerine satır hiç çizilmez.
func consent_options_available() -> bool:
	return _real_ads_available()


## Onay bir kez alındıktan sonra oyuncunun fikrini değiştirebilmesi gerekiyor
## (GDPR + Play veri güvenliği). UMP gizlilik seçenekleri formunu yeniden açar;
## form yoksa normal onay formuna düşer.
func show_privacy_options_form() -> void:
	if not _real_ads_available():
		return
	var consent_info := UserMessagingPlatform.consent_information
	consent_info.update(
		ConsentRequestParameters.new(),
		func():
			if consent_info.get_is_consent_form_available():
				UserMessagingPlatform.load_consent_form(
					func(form: ConsentForm): form.show(func(_err): pass),
					func(_err): pass
				),
		func(_err): pass
	)


func _init_ads() -> void:
	var listener := OnInitializationCompleteListener.new()
	listener.on_initialization_complete = func(_status):
		_load_rewarded_ad()
		_load_interstitial_ad()
		_load_app_open_ad()
	MobileAds.initialize(listener)


func _load_rewarded_ad() -> void:
	if not _real_ads_available() or _loading or _rewarded_ad:
		return
	_loading = true
	var loader := RewardedAdLoader.new()
	var cb := RewardedAdLoadCallback.new()
	cb.on_ad_loaded = func(ad: RewardedAd):
		_loading = false
		_rewarded_ad = ad
		# Kapanış/hata geri çağrıları REKLAMIN KENDİSİNİ (ad) tutar, _rewarded_ad
		# alanını değil: show_rewarded gösterimden önce alanı boşaltıyor, alana
		# bakan bir kapanış geri çağrısı boş referans üzerinde patlar ve bir
		# sonraki reklam hiç yüklenmezdi (oturumda tek ödüllü reklam hakkı).
		ad.full_screen_content_callback.on_ad_dismissed_full_screen_content = func():
			_release_rewarded_ad(ad)
		ad.full_screen_content_callback.on_ad_failed_to_show_full_screen_content = func(_err):
			_release_rewarded_ad(ad)
	cb.on_ad_failed_to_load = func(_err):
		_loading = false
	loader.load(_REWARDED_AD_UNIT_ID, AdRequest.new(), cb)


## Ödüllü reklam gösterir; kullanıcı izlerse on_reward çağrılır.
## Gerçek reklam hazır değilse (yükleniyor/başarısız) ödül verilmez; rewarded_ad_result(false)
## yayınlanır ve arka planda yeni bir reklam yüklenmeye başlanır.
func show_rewarded(on_reward: Callable) -> void:
	if not _real_ads_available():
		on_reward.call()
		rewarded_ad_result.emit(true)
		return

	if not _rewarded_ad:
		rewarded_ad_result.emit(false)
		_load_rewarded_ad()
		return

	var ad := _rewarded_ad
	_rewarded_ad = null
	var reward_listener := OnUserEarnedRewardListener.new()
	reward_listener.on_user_earned_reward = func(_item):
		on_reward.call()
		rewarded_ad_result.emit(true)
	# Ödüllü reklam soğuma sayacını OKUMAZ (oyuncunun kendi isteğiyle açtığı,
	# ödül veren tek yer), ama İLERLETİR: hemen ardından bir de zorunlu geçiş
	# reklamı gelmesin.
	_mark_full_screen_ad_shown()
	ad.show(reward_listener)


## Gösterimi biten/başarısız olan ödüllü reklamı yok eder ve yerine yenisini
## yükler. Aradan yeni bir reklam yüklendiyse (ad artık güncel olan değilse)
## alan boşaltılmaz.
func _release_rewarded_ad(ad: RewardedAd) -> void:
	if _rewarded_ad == ad:
		_rewarded_ad = null
	ad.destroy()
	_load_rewarded_ad()


func _load_interstitial_ad() -> void:
	if not _real_ads_available() or _interstitial_loading or _interstitial_ad:
		return
	_interstitial_loading = true
	var loader := InterstitialAdLoader.new()
	var cb := InterstitialAdLoadCallback.new()
	cb.on_ad_loaded = func(ad: InterstitialAd):
		_interstitial_loading = false
		_interstitial_ad = ad
		var content_cb := FullScreenContentCallback.new()
		content_cb.on_ad_dismissed_full_screen_content = func():
			_release_interstitial_ad(ad)
		content_cb.on_ad_failed_to_show_full_screen_content = func(_err):
			_release_interstitial_ad(ad)
		ad.full_screen_content_callback = content_cb
	cb.on_ad_failed_to_load = func(_err):
		_interstitial_loading = false
	loader.load(_INTERSTITIAL_AD_UNIT_ID, AdRequest.new(), cb)


func _release_interstitial_ad(ad: InterstitialAd) -> void:
	if _interstitial_ad == ad:
		_interstitial_ad = null
	ad.destroy()
	_load_interstitial_ad()


## Geçiş reklamı (interstitial). show_if çağıran tarafından hesaplanır
## (örn. main.gd: "not Game.remove_ads") — Ads bu kararı kendi vermez.
## Yalnızca oyunun İÇİNDEKİ doğal mola noktalarından çağrılır (vardiya bitişi,
## her 12 oda/geliştirme satın alımında bir). Uygulama açılışı/öne gelişi
## kasıtlı olarak bu listede DEĞİL — AdMob orada geçiş reklamını yasaklıyor,
## o senaryonun formatı App Open (bkz. show_app_open).
func show_interstitial(show_if: bool = true) -> void:
	if not show_if or not _real_ads_available():
		return
	if _elapsed_since(_last_full_screen_ad_time) < _FULL_SCREEN_AD_COOLDOWN_SEC:
		return
	if not _interstitial_ad:
		_load_interstitial_ad()
		return
	_mark_full_screen_ad_shown()
	_interstitial_ad.show()


func _load_app_open_ad() -> void:
	if not _real_ads_available() or _APP_OPEN_AD_UNIT_ID.is_empty():
		return
	if _app_open_loading or _app_open_ad:
		return
	_app_open_loading = true
	var loader := AppOpenAdLoader.new()
	var cb := AppOpenAdLoadCallback.new()
	cb.on_ad_loaded = func(ad: AppOpenAd):
		_app_open_loading = false
		_app_open_ad = ad
		_app_open_loaded_time = _now()
		var content_cb := FullScreenContentCallback.new()
		content_cb.on_ad_dismissed_full_screen_content = func():
			_release_app_open_ad(ad)
		content_cb.on_ad_failed_to_show_full_screen_content = func(_err):
			_release_app_open_ad(ad)
		ad.full_screen_content_callback = content_cb
	cb.on_ad_failed_to_load = func(_err):
		_app_open_loading = false
	loader.load(_APP_OPEN_AD_UNIT_ID, AdRequest.new(), cb)


func _release_app_open_ad(ad: AppOpenAd) -> void:
	if _app_open_ad == ad:
		_app_open_ad = null
	ad.destroy()
	_load_app_open_ad()


## Uygulama arka plandan öne geldiğinde çağrılır. AdMob'un uygulama
## açılışı/öne gelişi için ÖNGÖRDÜĞÜ format budur; aynı yerde geçiş reklamı
## göstermek "izin verilmeyen uygulama" sayılıyor.
##
## Geçiş reklamıyla aynı kalıcı soğuma sayacını paylaşır: oyuncu uygulamayı
## kapatıp açarak ya da bir bildirime gidip dönerek arka arkaya reklam
## üretemez.
func show_app_open(show_if: bool = true) -> void:
	if not show_if or not _real_ads_available():
		return
	if _elapsed_since(_last_full_screen_ad_time) < _FULL_SCREEN_AD_COOLDOWN_SEC:
		return
	if not _app_open_ad:
		_load_app_open_ad()
		return
	# Bayat reklam gösterilmez: at, yenisini yükle, bu seferlik hiçbir şey gösterme.
	if _elapsed_since(_app_open_loaded_time) > _APP_OPEN_MAX_CACHE_SEC:
		_release_app_open_ad(_app_open_ad)
		return
	_mark_full_screen_ad_shown()
	_app_open_ad.show()
