extends Node
## Uygulama içi satın alma için platform-bağımsız arayüz.
##
## Gerçek cihazda (Android derlemesinde Play Billing eklentisi aktifken) Google Play
## Billing Library'yi kullanır: bağlantı kurulunca sahip olunan satın almalar otomatik
## geri yüklenir (restore), yeni satın alma sonucu `on_purchase_updated` ile gelir ve
## (tüketilmeyen/kalıcı ürünler olduğu için) onaylanır (acknowledge). Eklenti yokken
## (masaüstü/editör/headless test — `tests/sim_check.gd` de dahil) mock davranış
## korunur: her zaman anında "başarılı" sayar.
##
## PRODUCT_REMOVE_ADS / PRODUCT_INCOME_2X sabitleri, Play Console'da oluşturulması
## gereken uygulama içi ürün (in-app product) ID'leriyle birebir eşleşmeli.
##
## Kasıtlı olarak Game autoload'ına dokunmaz: satın alma sonucunda oyun durumunun
## nasıl değişeceğine çağıran (main.gd) on_result callback'i içinde karar verir. Bu
## ayrım hem gerçek mağaza SDK'sıyla hem headless testte (autoload'ların yüklenmediği
## --script modunda) bağımsız çalışabilmesini sağlar.

signal purchase_result(product_id: String, success: bool)

## Satın alma mağaza tarafından reddedildi (kart geçmedi, ürün alınamadı…).
## Oyuncunun kendi iptali BU sinyali yaymaz — iptal bir hata değildir ve
## oyuncuya hata mesajı göstermek yanlış olur.
signal purchase_failed(product_id: String, response_code: int)

## Satın alma BEKLEMEDE: ödeme yöntemi yavaş (havale/ön ödemeli kart), onay
## gelince ürün verilecek. Ödül bu noktada verilmez.
signal purchase_pending(product_id: String)

## Mağazaya göre şu an sahip olunan ürünlerin tam listesi (yalnızca
## query_purchases yanıtından sonra). İade edilen kalıcı bir ürün bu listeden
## düşer — hakkı kapatmak dinleyenin işi.
signal entitlements_synced(owned_product_ids: PackedStringArray)

## Mağaza fiyatları geldi — fiyat gösteren ekranlar kendini tazelemeli.
signal prices_updated

## Oyuncunun elle başlattığı geri yükleme bitti: `count` mağazada bulunan
## satın alma sayısı. Yalnızca restore_purchases() çağrıldıktan sonraki ilk
## yanıtta gelir — bağlantı kurulunca yapılan otomatik sorgu sessizdir.
signal restore_finished(count: int)

const PRODUCT_REMOVE_ADS := "remove_ads"
const PRODUCT_INCOME_2X := "income_2x"
const PRODUCT_GEMS_SMALL := "gems_small"
const PRODUCT_GEMS_MEDIUM := "gems_medium"
const PRODUCT_GEMS_LARGE := "gems_large"

## Elmas paketleri tekrar tekrar satın alınabilir (consumable) — kalıcı
## ürünlerin aksine acknowledge değil consume edilmeleri gerekir, yoksa
## Play Billing aynı satın almayı "zaten sahipsin" diyip reddeder.
const _CONSUMABLE_PRODUCTS := {
	PRODUCT_GEMS_SMALL: true,
	PRODUCT_GEMS_MEDIUM: true,
	PRODUCT_GEMS_LARGE: true,
}

const _BILLING_SINGLETON := "GodotGooglePlayBilling"

var _billing: BillingClient
var _connected := false
var _pending: Dictionary = {}  # product_id -> Array[Callable]
## product_id -> mağazanın verdiği yerelleştirilmiş fiyat metni ("₺19,99", "$1.99", "€1,99"…)
var _prices: Dictionary = {}
## Oyuncu Ayarlar'dan geri yükleme istedi mi — sıradaki sorgu yanıtı
## restore_finished ile bildirilir.
var _restore_requested := false


func _ready() -> void:
	if _real_billing_available():
		_billing = BillingClient.new()
		add_child(_billing)
		_billing.connected.connect(_on_connected)
		_billing.on_purchase_updated.connect(_on_purchase_updated)
		_billing.query_purchases_response.connect(_on_query_purchases_response)
		_billing.query_product_details_response.connect(_on_query_product_details_response)
		_billing.start_connection()


func _real_billing_available() -> bool:
	return OS.get_name() == "Android" and Engine.has_singleton(_BILLING_SINGLETON)


func _on_connected() -> void:
	_connected = true
	_billing.query_purchases(BillingClient.ProductType.INAPP)
	_billing.query_product_details(PackedStringArray([
		PRODUCT_REMOVE_ADS, PRODUCT_INCOME_2X,
		PRODUCT_GEMS_SMALL, PRODUCT_GEMS_MEDIUM, PRODUCT_GEMS_LARGE,
	]), BillingClient.ProductType.INAPP)


## Bir ürünün gösterilecek fiyatı: mağazadan geldiyse o, yoksa verilen yedek.
##
## Mağaza fiyatı oyuncunun ülkesine ve para birimine göre gelir — sabit bir
## etiket kimin için doğruysa diğer herkes için yanlıştır. Yedek yalnızca
## mağazaya hiç ulaşılamadığında (masaüstü/test, çevrimdışı, ürün henüz
## yayınlanmamış) görünür; böylece fiyat alanı asla boş kalmaz.
func price_for(product_id: String, fallback: String) -> String:
	return _prices.get(product_id, fallback)


## Play Billing'in ProductDetails yanıtından yerelleştirilmiş fiyatı çıkarır.
##
## Anahtar adları eklentinin Java tarafından geliyor ve sürümüne göre snake_case
## ya da camelCase olabiliyor; ikisi de denenip bulunamazsa yedek etikette
## kalınır. Gerçek yanıt yalnızca Play imzalı bir kurulumda döndüğü için bu yol
## masaüstünde/emülatörde doğrulanamıyor — gelen ham yapıyı bir kez logluyoruz
## ki cihazda bakan kişi anahtarları görebilsin.
## Bir ürün kaydından tek seferlik teklif sözlüğünü çıkarır.
##
## Eklenti teklifi bir LİSTE olarak veriyor: `one_time_purchase_offer_details_list`
## (2026-08-25'te cihaz günlüğünden okundu — tek elemanlı, içinde
## `formatted_price`, `price_amount_micros`, `price_currency_code`). Tekil
## sözlük adları eski sürümler için yedekte. Liste birden fazla teklif
## taşırsa ilki alınır: satın alma seçeneği başına tek teklif tanımlı.
func _offer_of(item: Dictionary) -> Dictionary:
	var offers: Array = item.get("one_time_purchase_offer_details_list", [])
	if not offers.is_empty() and offers[0] is Dictionary:
		return offers[0]
	return item.get("one_time_purchase_offer_details",
		item.get("oneTimePurchaseOfferDetails", {}))


func _on_query_product_details_response(response: Dictionary) -> void:
	if response.get("response_code", -1) != BillingClient.BillingResponseCode.OK:
		return
	# GERÇEK ANAHTAR `product_details`: eklentinin Java tarafı (aar) bu adı
	# kullanıyor — 2026-08-25'te cihazda doğrulandı. Diğer iki ad eski
	# sürümler için yedekte tutuluyor.
	var list: Array = response.get("product_details",
		response.get("product_details_list", response.get("productDetailsList", [])))
	if list.is_empty():
		print("[IAP] ürün detayı yanıtı boş/tanınmadı: ", response.keys())
		return
	var found := 0
	for item: Dictionary in list:
		var pid: String = item.get("product_id", item.get("productId", ""))
		var offer: Dictionary = _offer_of(item)
		var price: String = offer.get("formatted_price", offer.get("formattedPrice", ""))
		if pid != "" and price != "":
			_prices[pid] = price
			found += 1
	if found == 0:
		print("[IAP] fiyat alanı bulunamadı, örnek kayıt: ", list[0])
		return
	prices_updated.emit()


func purchase(product_id: String, on_result: Callable = Callable()) -> void:
	if not _real_billing_available():
		# Mock: gerçek mağaza yokken (masaüstü/test) her zaman başarılı.
		purchase_result.emit(product_id, true)
		if on_result.is_valid():
			on_result.call(true)
		return

	if not _pending.has(product_id):
		_pending[product_id] = []
	if on_result.is_valid():
		_pending[product_id].append(on_result)

	if _connected:
		_billing.purchase(product_id)
	else:
		_billing.connected.connect(func(): _billing.purchase(product_id), CONNECT_ONE_SHOT)


## Mağaza tarafında saklanan satın almaları geri getirir (bağlantı kurulunca zaten
## otomatik çağrılır — cihaz değişimi/yeniden kurulumda hakların geri gelmesi için).
##
## Sorgu gerçekten başlatıldıysa `true` döner. Mağazaya hiç ulaşılamıyorsa
## (masaüstü/test, bağlantı yok) `false` döner ki UI "kontrol ediliyor" gibi
## yanlış bir söz vermek yerine dürüst bir mesaj gösterebilsin.
func restore_purchases() -> bool:
	if not _real_billing_available() or not _connected:
		return false
	_restore_requested = true
	_billing.query_purchases(BillingClient.ProductType.INAPP)
	return true


## Satın alma akışı bir sonuçla döndü. Başarısızlık da bir sonuçtur: oyuncu
## iptal ettiyse ya da kart reddettiyse bekleyen geri çağrılar TEMİZLENİR,
## yoksa çağıran taraf sonsuza kadar sessizce bekler ve ekranda hiçbir şey
## olmaz. (Google'ın "her zaman reddeder" test kartı tam bu yolu sürüyor.)
func _on_purchase_updated(response: Dictionary) -> void:
	var response_code: int = response.get("response_code", -1)
	if response_code != BillingClient.BillingResponseCode.OK:
		_fail_all_pending(response_code)
		return
	for p in response.get("purchases", []):
		_apply_purchase(p)


## Bekleyen tüm satın almaları başarısız olarak kapatır.
##
## Hangi ürünün reddedildiğini yanıt söylemiyor (başarısız yanıtta satın alma
## listesi boş gelir), ama aynı anda birden fazla akış açık olamaz: satın alma
## ekranı modaldir. Bu yüzden bekleyenlerin hepsi kapatılır.
func _fail_all_pending(response_code: int) -> void:
	if _pending.is_empty():
		return
	var cancelled := response_code == BillingClient.BillingResponseCode.USER_CANCELED
	for product_id: String in _pending.keys().duplicate():
		if not cancelled:
			purchase_failed.emit(product_id, response_code)
		purchase_result.emit(product_id, false)
		_flush_pending(product_id, false)


func _on_query_purchases_response(response: Dictionary) -> void:
	var requested := _restore_requested
	_restore_requested = false
	var response_code: int = response.get("response_code", -1)
	if response_code != BillingClient.BillingResponseCode.OK:
		if requested:
			restore_finished.emit(-1)
		return
	var purchases: Array = response.get("purchases", [])
	for p in purchases:
		_apply_purchase(p)
	# MUTABAKAT: bu yanıt mağazanın SAHİP OLUNAN ürünler listesinin tamamı.
	# İade edilen (ya da geri alınan) kalıcı bir ürün listeden düşer; oyunun
	# hakkı kendiliğinden kapanmazsa iade alan oyuncu ürünü kullanmaya devam
	# eder. Kararı burada vermiyoruz — hakkın sahibi Game/main; buradan yalnızca
	# "mağazaya göre şu an sahip olunanlar" duyurulur.
	var owned := PackedStringArray()
	for p in purchases:
		if p.get("purchase_state", 0) != BillingClient.PurchaseState.PURCHASED:
			continue
		for pid in p.get("product_ids", p.get("products", [])):
			owned.append(String(pid))
	entitlements_synced.emit(owned)
	if requested:
		restore_finished.emit(purchases.size())


func _apply_purchase(p: Dictionary) -> void:
	var state: int = p.get("purchase_state", 0)
	if state == BillingClient.PurchaseState.PENDING:
		# Yavaş ödeme yöntemleri (havale, ön ödemeli kart) satın almayı BEKLEMEDE
		# bırakır. Ödül burada VERİLMEZ; onaylanınca satın alma bir sonraki
		# query_purchases yanıtında PURCHASED olarak gelir ve orada verilir.
		# Oyuncuya durumu söylemek çağıranın işi — sessiz kalmak "para gitti,
		# bir şey olmadı" hissi veriyor.
		for pid in p.get("product_ids", p.get("products", [])):
			purchase_pending.emit(String(pid))
		return
	if state != BillingClient.PurchaseState.PURCHASED:
		return
	var token: String = p.get("purchase_token", "")
	# Eklenti satın alma sözlüğünde ürün listesini `product_ids` diye veriyor
	# (aar'dan doğrulandı). Yanlış anahtar okununca satın alma sessizce
	# uygulanmıyordu: oyuncu ödüyor, elması alamıyor.
	var products: Array = p.get("product_ids", p.get("products", []))
	if products.is_empty():
		# Sessizce dönmek 2026-08-25'te yakalanan hatanın ta kendisiydi: ödeme
		# alınıyor, ürün verilmiyordu. Anahtar adı yine değişirse bu satır
		# cihaz günlüğünde görünür.
		print("[IAP] satın alma kaydında ürün kimliği yok, anahtarlar: ", p.keys())
		return
	var consumable := products.any(func(pid): return _CONSUMABLE_PRODUCTS.has(pid))
	if consumable:
		_billing.consume_purchase(token)
	elif not p.get("is_acknowledged", false):
		_billing.acknowledge_purchase(token)
	for product_id in products:
		purchase_result.emit(product_id, true)
		_flush_pending(product_id, true)


func _flush_pending(product_id: String, ok: bool) -> void:
	if not _pending.has(product_id):
		return
	for cb: Callable in _pending[product_id]:
		if cb.is_valid():
			cb.call(ok)
	_pending.erase(product_id)
