extends Node
## Reklam entegrasyonu için platform-bağımsız arayüz.
## Faz 5 Aşama A: mock backend — her platformda (Windows/headless dahil)
## anında "izlendi" sayar. Gerçek AdMob SDK'sı Aşama B (Android) / C (iOS)
## bağlanınca yalnızca bu dosya değişir; main.gd/game.gd hiç dokunulmaz.
##
## Kasıtlı olarak Game autoload'ına dokunmaz (bkz. iap.gd) — reklam
## gösterip göstermeme kararını (örn. "reklamlar kaldırıldı mı") çağıran verir.

signal rewarded_ad_result(success: bool)


## Ödüllü reklam gösterir; kullanıcı izlerse on_reward çağrılır.
func show_rewarded(on_reward: Callable) -> void:
	on_reward.call()
	rewarded_ad_result.emit(true)


## Geçiş reklamı (interstitial). show_if çağıran tarafından hesaplanır
## (örn. main.gd: "not Game.remove_ads") — Ads bu kararı kendi vermez.
func show_interstitial(show_if: bool = true) -> void:
	if not show_if:
		return
	pass  # Mock: gösterecek gerçek reklam yok.
