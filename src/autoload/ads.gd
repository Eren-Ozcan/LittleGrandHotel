extends Node
## Reklam entegrasyonu için platform-bağımsız arayüz.
##
## Gerçek cihazda (Android derlemesinde AdMob eklentisi aktifken) Google Mobile Ads
## SDK'sını kullanır: GDPR/CCPA onam akışı (UMP) → SDK başlatma → ödüllü reklam
## önceden yükleme → gösterim. Eklenti yokken (masaüstü/editör/headless test —
## `tests/sim_check.gd` de dahil) mock davranış korunur: her yerde anında "izlendi"
## sayar, böylece geliştirme/test akışı reklam beklemeden çalışmaya devam eder.
##
## Yayın öncesi TODO: _REWARDED_AD_UNIT_ID şu an Google'ın herkese açık test ID'si —
## kendi AdMob hesabınızdan alınan gerçek ödüllü reklam birimi ID'siyle değiştirin.
## Uygulama Kimliği (App ID) `admob/general/android/app_id` proje ayarında tutuluyor
## (varsayılan yine Google test App ID) — gerçek hesap kurulunca orada güncelleyin.
##
## Kasıtlı olarak Game autoload'ına dokunmaz (bkz. iap.gd) — reklam gösterip
## göstermeme kararını (örn. "reklamlar kaldırıldı mı") çağıran verir.

signal rewarded_ad_result(success: bool)

const _REWARDED_SINGLETON := "PoingGodotAdMobRewardedAd"
const _REWARDED_AD_UNIT_ID := "ca-app-pub-3940256099942544/5224354917"  # Google test ID

var _rewarded_ad: RewardedAd
var _loading := false


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
	listener.on_initialization_complete = func(_status): _load_rewarded_ad()
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


## Geçiş reklamı (interstitial). show_if çağıran tarafından hesaplanır
## (örn. main.gd: "not Game.remove_ads") — Ads bu kararı kendi vermez.
func show_interstitial(show_if: bool = true) -> void:
	if not show_if:
		return
	pass  # Şu an kullanılmıyor; gerekirse rewarded ile aynı yükle-önce desende eklenir.
