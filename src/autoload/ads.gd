extends Node
## Reklam entegrasyonu için platform-bağımsız arayüz.
##
## Gerçek cihazda (Android derlemesinde AdMob eklentisi aktifken) Google Mobile Ads
## SDK'sını kullanır: GDPR/CCPA onam akışı (UMP) → SDK başlatma → ödüllü reklam
## önceden yükleme → gösterim. Eklenti yokken (masaüstü/editör/headless test —
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

## show_interstitial art arda çağrılsa da (vardiya bitişi + öne gelme aynı
## anda tetiklenebilir) oyuncuyu art arda iki reklamla boğmasın diye tutulan
## oturum içi soğuma süresi.
const _INTERSTITIAL_COOLDOWN_SEC := 5.0 * 60.0

var _rewarded_ad: RewardedAd
var _loading := false

var _interstitial_ad: InterstitialAd
var _interstitial_loading := false
var _last_interstitial_time := -INF


func _ready() -> void:
	if _real_ads_available():
		_request_consent_then_init()


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


func _init_ads() -> void:
	var listener := OnInitializationCompleteListener.new()
	listener.on_initialization_complete = func(_status):
		_load_rewarded_ad()
		_load_interstitial_ad()
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
		_rewarded_ad.full_screen_content_callback.on_ad_dismissed_full_screen_content = func():
			_rewarded_ad.destroy()
			_rewarded_ad = null
			_load_rewarded_ad()
		_rewarded_ad.full_screen_content_callback.on_ad_failed_to_show_full_screen_content = func(_err):
			_rewarded_ad.destroy()
			_rewarded_ad = null
			_load_rewarded_ad()
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
	ad.show(reward_listener)


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
			_interstitial_ad.destroy()
			_interstitial_ad = null
			_load_interstitial_ad()
		content_cb.on_ad_failed_to_show_full_screen_content = func(_err):
			_interstitial_ad.destroy()
			_interstitial_ad = null
			_load_interstitial_ad()
		_interstitial_ad.full_screen_content_callback = content_cb
	cb.on_ad_failed_to_load = func(_err):
		_interstitial_loading = false
	loader.load(_INTERSTITIAL_AD_UNIT_ID, AdRequest.new(), cb)


## Geçiş reklamı (interstitial). show_if çağıran tarafından hesaplanır
## (örn. main.gd: "not Game.remove_ads") — Ads bu kararı kendi vermez.
## Doğal mola noktalarından (vardiya bitişi, uygulama öne gelince, her 12
## oda/geliştirme satın alımında bir) çağrılır; art arda basmayı önleyen
## soğuma süresini (bkz. _INTERSTITIAL_COOLDOWN_SEC) kendi içinde tutar.
func show_interstitial(show_if: bool = true) -> void:
	if not show_if or not _real_ads_available():
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_interstitial_time < _INTERSTITIAL_COOLDOWN_SEC:
		return
	if not _interstitial_ad:
		_load_interstitial_ad()
		return
	_last_interstitial_time = now
	_interstitial_ad.show()
