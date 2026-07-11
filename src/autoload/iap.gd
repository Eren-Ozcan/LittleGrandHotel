extends Node
## Uygulama içi satın alma için platform-bağımsız arayüz.
## Faz 5 Aşama A: mock backend — her platformda (Windows/headless dahil)
## anında "başarılı" sayar. Gerçek Google Play Billing (Android) / StoreKit
## (iOS) bağlanınca yalnızca bu dosya değişir.
##
## Kasıtlı olarak Game autoload'ına dokunmaz: satın alma sonucunda oyun
## durumunun nasıl değişeceğine çağıran (main.gd) on_result callback'i
## içinde karar verir. Bu ayrım hem gerçek mağaza SDK'sıyla hem headless
## testte (autoload'ların yüklenmediği --script modunda) bağımsız
## çalışabilmesini sağlar.

signal purchase_result(product_id: String, success: bool)

const PRODUCT_REMOVE_ADS := "remove_ads"
const PRODUCT_INCOME_2X := "income_2x"


func purchase(product_id: String, on_result: Callable = Callable()) -> void:
	var ok := true  # Mock: gerçek mağaza yokken her zaman başarılı.
	purchase_result.emit(product_id, ok)
	if on_result.is_valid():
		on_result.call(ok)


## Mağaza tarafında saklanan satın almaları geri getirir (Aşama B/C'de gerçek
## mağaza API'siyle doldurulacak — restore edilen her ürün için purchase_result
## yayınlanır, çağıran aynı on_result akışını kullanabilir).
func restore_purchases() -> void:
	pass
