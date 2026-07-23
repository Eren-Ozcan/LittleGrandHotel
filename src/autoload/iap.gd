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

const PRODUCT_REMOVE_ADS := "remove_ads"
const PRODUCT_INCOME_2X := "income_2x"

const _BILLING_SINGLETON := "GodotGooglePlayBilling"

var _billing: BillingClient
var _connected := false
var _pending: Dictionary = {}  # product_id -> Array[Callable]


func _ready() -> void:
	if _real_billing_available():
		_billing = BillingClient.new()
		add_child(_billing)
		_billing.connected.connect(_on_connected)
		_billing.on_purchase_updated.connect(_on_purchase_updated)
		_billing.query_purchases_response.connect(_on_query_purchases_response)
		_billing.start_connection()


func _real_billing_available() -> bool:
	return OS.get_name() == "Android" and Engine.has_singleton(_BILLING_SINGLETON)


func _on_connected() -> void:
	_connected = true
	_billing.query_purchases(BillingClient.ProductType.INAPP)


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
func restore_purchases() -> void:
	if not _real_billing_available():
		return
	if _connected:
		_billing.query_purchases(BillingClient.ProductType.INAPP)


func _on_purchase_updated(response: Dictionary) -> void:
	var response_code: int = response.get("response_code", -1)
	if response_code != BillingClient.BillingResponseCode.OK:
		return
	for p in response.get("purchases", []):
		_apply_purchase(p)


func _on_query_purchases_response(response: Dictionary) -> void:
	var response_code: int = response.get("response_code", -1)
	if response_code != BillingClient.BillingResponseCode.OK:
		return
	for p in response.get("purchases", []):
		_apply_purchase(p)


func _apply_purchase(p: Dictionary) -> void:
	if p.get("purchase_state", 0) != BillingClient.PurchaseState.PURCHASED:
		return
	var token: String = p.get("purchase_token", "")
	if not p.get("is_acknowledged", false):
		_billing.acknowledge_purchase(token)
	for product_id in p.get("products", []):
		purchase_result.emit(product_id, true)
		_flush_pending(product_id, true)


func _flush_pending(product_id: String, ok: bool) -> void:
	if not _pending.has(product_id):
		return
	for cb: Callable in _pending[product_id]:
		if cb.is_valid():
			cb.call(ok)
	_pending.erase(product_id)
