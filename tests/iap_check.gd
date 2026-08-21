extends Node
## Uygulama içi satın alma testi (src/autoload/iap.gd).
##
## Gerçek Play Billing eklentisi yalnızca Android'de var; masaüstünde `purchase()`
## mock davranışa düşer. Ama asıl RİSK mock'ta değil, mağazadan gelen yanıtı
## işleyen kodda: bir tüketilebilir ürünü consume etmek yerine acknowledge etmek
## oyuncunun ikinci kez elmas satın almasını Play tarafında kalıcı olarak
## engeller ("zaten sahipsin"), tersi ise kalıcı hakkın 3 gün sonra iade
## edilmesine yol açar. O yol burada gerçek yanıt sözlükleriyle sürülür.
##
## `BillingClient` her çağrısını `_plugin_singleton` var mı diye koruduğu için
## masaüstünde güvenle örneklenebilir; hangi çağrının yapıldığını görebilmek
## adına aşağıda kayıt tutan bir alt sınıf kullanılır.
##
## Çalıştırma:
##   tools\Godot_v4.7-stable_win64_console.exe --headless --path . res://tests/iap_check.tscn


## Hangi satın almanın consume, hangisinin acknowledge edildiğini kaydeder.
class SpyBilling extends BillingClient:
	var consumed: Array[String] = []
	var acknowledged: Array[String] = []
	var purchased: Array[String] = []
	var queries := 0

	func consume_purchase(purchase_token: String) -> void:
		consumed.append(purchase_token)

	func acknowledge_purchase(purchase_token: String) -> void:
		acknowledged.append(purchase_token)

	func purchase(product_id: String, _opt: String = "", _offer: String = "",
			_personalized: bool = false) -> Dictionary:
		purchased.append(product_id)
		return {}

	func query_purchases(_type: ProductType, _include: bool = false) -> void:
		queries += 1


const OK_CODE := BillingClient.BillingResponseCode.OK
const PURCHASED := BillingClient.PurchaseState.PURCHASED

var failures := 0
var checks := 0
var spy: SpyBilling
var _saved_billing
var _saved_connected: bool


func check(cond: bool, label: String) -> void:
	checks += 1
	if cond:
		print("  OK   ", label)
	else:
		failures += 1
		printerr("  FAIL ", label)


## Play'in döndürdüğü satın alma kaydının test karşılığı.
func _purchase(products: Array, token: String, acknowledged := false,
		state := PURCHASED) -> Dictionary:
	return {
		"products": products,
		"purchase_token": token,
		"is_acknowledged": acknowledged,
		"purchase_state": state,
	}


func _fresh_spy() -> void:
	if spy != null and is_instance_valid(spy):
		spy.queue_free()
	spy = SpyBilling.new()
	add_child(spy)
	IAP._billing = spy
	IAP._pending.clear()
	IAP._restore_requested = false


func _ready() -> void:
	print("Little Grand Hotel — satın alma (IAP) testi")
	print("=".repeat(64))
	_saved_billing = IAP._billing
	_saved_connected = IAP._connected

	_test_product_ids()
	_test_consumable_table()
	_test_mock_purchase_on_desktop()
	_test_apply_purchase_consumable()
	_test_apply_purchase_permanent()
	_test_apply_purchase_already_acknowledged()
	_test_pending_state_is_ignored()
	_test_purchase_updated_error_code()
	_test_pending_callbacks()
	_test_restore_flow()
	_test_prices()

	IAP._billing = _saved_billing
	IAP._connected = _saved_connected
	print("=".repeat(64))
	if failures == 0:
		print("TÜM TESTLER GEÇTİ (%d kontrol)" % checks)
	else:
		printerr("%d/%d TEST BAŞARISIZ" % [failures, checks])
	get_tree().quit(1 if failures > 0 else 0)


# --- Ürün tanımları ------------------------------------------------------

func _test_product_ids() -> void:
	print("\n[1] Ürün kimlikleri")
	var ids := [IAP.PRODUCT_REMOVE_ADS, IAP.PRODUCT_INCOME_2X,
		IAP.PRODUCT_GEMS_SMALL, IAP.PRODUCT_GEMS_MEDIUM, IAP.PRODUCT_GEMS_LARGE]
	var seen := {}
	for id in ids:
		check(id != "", "ürün kimliği boş değil")
		check(id == id.to_lower() and not id.contains(" "),
			"'%s' Play'in kabul ettiği biçimde (küçük harf, boşluksuz)" % id)
		check(not seen.has(id), "'%s' benzersiz" % id)
		seen[id] = true
	check(seen.size() == 5, "beş ayrı ürün tanımlı")

	# Kimlikler Play Console'da oluşturulan ürünlerle BİREBİR eşleşmeli;
	# dokümandan sapması sessiz bir "ürün bulunamadı" demektir.
	var doc := FileAccess.get_file_as_string("res://docs/store/in-app-products.md")
	check(doc != "", "in-app-products.md okunabildi")
	for id in ids:
		check(doc.contains("`%s`" % id),
			"'%s' mağaza dokümanında da listeli" % id)


func _test_consumable_table() -> void:
	print("\n[2] Tüketilebilir / kalıcı ayrımı")
	for id in [IAP.PRODUCT_GEMS_SMALL, IAP.PRODUCT_GEMS_MEDIUM, IAP.PRODUCT_GEMS_LARGE]:
		check(IAP._CONSUMABLE_PRODUCTS.has(id), "'%s' tüketilebilir" % id)
	for id in [IAP.PRODUCT_REMOVE_ADS, IAP.PRODUCT_INCOME_2X]:
		check(not IAP._CONSUMABLE_PRODUCTS.has(id),
			"'%s' KALICI — tüketilirse hak kaybolur" % id)
	check(IAP._CONSUMABLE_PRODUCTS.size() == 3, "tam olarak 3 tüketilebilir ürün")


# --- Mock yol (masaüstü/test) --------------------------------------------

func _test_mock_purchase_on_desktop() -> void:
	print("\n[3] Mağaza yokken mock davranış")
	IAP._billing = null
	var got := []
	IAP.purchase(IAP.PRODUCT_REMOVE_ADS, func(ok): got.append(ok))
	check(got.size() == 1 and got[0] == true,
		"mağaza yokken satın alma anında başarılı döner (test/geliştirme tıkanmaz)")
	check(IAP.restore_purchases() == false,
		"mağazaya ulaşılamıyorken restore_purchases DÜRÜSTÇE false döner")
	check(IAP.price_for("herhangi", "₺--") == "₺--",
		"fiyat bilinmiyorken yedek etiket döner")


# --- Mağaza yanıtlarının işlenmesi ---------------------------------------

func _test_apply_purchase_consumable() -> void:
	print("\n[4] Tüketilebilir ürün CONSUME ediliyor")
	_fresh_spy()
	var emitted := []
	var sig := func(pid: String, ok: bool): emitted.append([pid, ok])
	IAP.purchase_result.connect(sig)
	IAP._apply_purchase(_purchase([IAP.PRODUCT_GEMS_MEDIUM], "tok-gems"))
	IAP.purchase_result.disconnect(sig)
	check(spy.consumed == ["tok-gems"],
		"elmas paketi consume edildi — ikinci alım engellenmiyor")
	check(spy.acknowledged.is_empty(),
		"elmas paketi acknowledge EDİLMEDİ (consume yerine geçmez)")
	check(emitted.size() == 1 and emitted[0][0] == IAP.PRODUCT_GEMS_MEDIUM and emitted[0][1],
		"purchase_result sinyali doğru ürünle geldi")


func _test_apply_purchase_permanent() -> void:
	print("\n[5] Kalıcı ürün ACKNOWLEDGE ediliyor")
	_fresh_spy()
	IAP._apply_purchase(_purchase([IAP.PRODUCT_REMOVE_ADS], "tok-ads", false))
	check(spy.acknowledged == ["tok-ads"],
		"kalıcı ürün acknowledge edildi — 3 gün sonra iade edilmiyor")
	check(spy.consumed.is_empty(),
		"kalıcı ürün consume EDİLMEDİ (hak kaybolurdu)")


func _test_apply_purchase_already_acknowledged() -> void:
	print("\n[6] Zaten onaylanmış satın alma")
	_fresh_spy()
	var emitted := []
	var sig := func(pid: String, _ok: bool): emitted.append(pid)
	IAP.purchase_result.connect(sig)
	IAP._apply_purchase(_purchase([IAP.PRODUCT_INCOME_2X], "tok-2x", true))
	IAP.purchase_result.disconnect(sig)
	check(spy.acknowledged.is_empty(), "ikinci kez acknowledge edilmiyor")
	check(spy.consumed.is_empty(), "consume da edilmiyor")
	check(emitted == [IAP.PRODUCT_INCOME_2X],
		"hak yine de uygulanıyor — yeniden kurulumda geri geliyor")


func _test_pending_state_is_ignored() -> void:
	print("\n[7] PURCHASED olmayan durumlar")
	for state in [BillingClient.PurchaseState.PENDING,
			BillingClient.PurchaseState.UNSPECIFIED_STATE]:
		_fresh_spy()
		var emitted := []
		var sig := func(pid: String, _ok: bool): emitted.append(pid)
		IAP.purchase_result.connect(sig)
		IAP._apply_purchase(_purchase([IAP.PRODUCT_REMOVE_ADS], "tok-x", false, state))
		IAP.purchase_result.disconnect(sig)
		# PENDING = ödeme henüz tamamlanmadı (nakit/aile onayı). Burada hak
		# verilirse ödeme hiç gerçekleşmeden ürün bedava dağıtılır.
		check(emitted.is_empty(), "durum %d: hak VERİLMEDİ" % state)
		check(spy.acknowledged.is_empty() and spy.consumed.is_empty(),
			"durum %d: mağazaya onay/tüketim gönderilmedi" % state)


func _test_purchase_updated_error_code() -> void:
	print("\n[8] Hatalı yanıt kodu")
	_fresh_spy()
	var emitted := []
	var sig := func(pid: String, _ok: bool): emitted.append(pid)
	IAP.purchase_result.connect(sig)
	IAP._on_purchase_updated({
		"response_code": BillingClient.BillingResponseCode.USER_CANCELED,
		"purchases": [_purchase([IAP.PRODUCT_REMOVE_ADS], "tok-cancel")],
	})
	IAP.purchase_result.disconnect(sig)
	check(emitted.is_empty(),
		"kullanıcı iptal ettiğinde satın alma listesi İŞLENMİYOR")

	# Doğru kodla aynı yanıt işlenmeli — testin kendisinin boş geçmediğini kanıtlar.
	_fresh_spy()
	var ok_emitted := []
	var sig2 := func(pid: String, _ok: bool): ok_emitted.append(pid)
	IAP.purchase_result.connect(sig2)
	IAP._on_purchase_updated({
		"response_code": OK_CODE,
		"purchases": [_purchase([IAP.PRODUCT_REMOVE_ADS], "tok-ok")],
	})
	IAP.purchase_result.disconnect(sig2)
	check(ok_emitted == [IAP.PRODUCT_REMOVE_ADS], "OK kodunda satın alma işlendi")


func _test_pending_callbacks() -> void:
	print("\n[9] Bekleyen callback'ler")
	_fresh_spy()
	var calls := []
	IAP._pending[IAP.PRODUCT_REMOVE_ADS] = [
		func(ok): calls.append(["a", ok]),
		func(ok): calls.append(["b", ok]),
	]
	IAP._apply_purchase(_purchase([IAP.PRODUCT_REMOVE_ADS], "tok-cb"))
	check(calls.size() == 2, "kayıtlı iki callback de çağrıldı")
	check(calls[0][1] == true and calls[1][1] == true, "ikisine de başarı bildirildi")
	check(not IAP._pending.has(IAP.PRODUCT_REMOVE_ADS),
		"kuyruk temizlendi — aynı callback ikinci kez çağrılmaz (çift ödül)")

	# Geçersiz (hedefi silinmiş) bir Callable kuyruğu çökertmemeli.
	_fresh_spy()
	IAP._pending[IAP.PRODUCT_INCOME_2X] = [Callable()]
	IAP._apply_purchase(_purchase([IAP.PRODUCT_INCOME_2X], "tok-dead"))
	check(not IAP._pending.has(IAP.PRODUCT_INCOME_2X),
		"geçersiz callback çökertmedi, kuyruk yine temizlendi")


func _test_restore_flow() -> void:
	print("\n[10] Geri yükleme akışı")
	# Bağlantı kurulunca yapılan OTOMATİK sorgu sessiz olmalı: oyuncu bir şey
	# istemediyse ekrana "2 satın alma bulundu" diye bir kutu çıkmamalı.
	_fresh_spy()
	var finished := []
	var sig := func(n: int): finished.append(n)
	IAP.restore_finished.connect(sig)
	IAP._on_query_purchases_response({
		"response_code": OK_CODE,
		"purchases": [_purchase([IAP.PRODUCT_REMOVE_ADS], "t1", true)],
	})
	check(finished.is_empty(), "otomatik sorgu restore_finished YAYMIYOR")

	# Oyuncu elle istediyse sonuç bildirilmeli.
	IAP._restore_requested = true
	IAP._on_query_purchases_response({
		"response_code": OK_CODE,
		"purchases": [
			_purchase([IAP.PRODUCT_REMOVE_ADS], "t1", true),
			_purchase([IAP.PRODUCT_INCOME_2X], "t2", true),
		],
	})
	check(finished == [2], "elle geri yüklemede bulunan sayı bildirildi (2)")
	check(IAP._restore_requested == false, "bayrak tüketildi — sonraki sorgu sessiz")

	# Hata durumunda -1: UI "0 satın alma bulundu" gibi YANLIŞ bir şey dememeli.
	finished.clear()
	IAP._restore_requested = true
	IAP._on_query_purchases_response({
		"response_code": BillingClient.BillingResponseCode.SERVICE_DISCONNECTED,
		"purchases": [],
	})
	IAP.restore_finished.disconnect(sig)
	check(finished == [-1], "hata durumu -1 ile ayırt ediliyor (0'dan farklı)")


func _test_prices() -> void:
	print("\n[11] Yerelleştirilmiş fiyatlar")
	IAP._prices.clear()
	check(IAP.price_for(IAP.PRODUCT_REMOVE_ADS, "₺--") == "₺--", "başlangıçta yedek etiket")

	var updated := [0]
	var sig := func(): updated[0] += 1
	IAP.prices_updated.connect(sig)

	# Eklentinin snake_case biçimi.
	IAP._on_query_product_details_response({
		"response_code": OK_CODE,
		"product_details_list": [{
			"product_id": IAP.PRODUCT_REMOVE_ADS,
			"one_time_purchase_offer_details": {"formatted_price": "₺149,99"},
		}],
	})
	check(IAP.price_for(IAP.PRODUCT_REMOVE_ADS, "₺--") == "₺149,99",
		"snake_case yanıt okundu")

	# Aynı eklentinin camelCase biçimi — sürüme göre değişiyor, ikisi de
	# desteklenmezse cihazda fiyat sessizce yedek etikette kalır.
	IAP._on_query_product_details_response({
		"response_code": OK_CODE,
		"productDetailsList": [{
			"productId": IAP.PRODUCT_INCOME_2X,
			"oneTimePurchaseOfferDetails": {"formattedPrice": "$9.99"},
		}],
	})
	check(IAP.price_for(IAP.PRODUCT_INCOME_2X, "$--") == "$9.99",
		"camelCase yanıt da okundu")
	check(updated[0] == 2, "her başarılı fiyat yanıtında prices_updated yayıldı")

	# Bozuk/eksik yanıtlar sinyal yaymamalı ve mevcut fiyatı bozmamalı.
	var before: int = updated[0]
	IAP._on_query_product_details_response({"response_code": OK_CODE, "product_details_list": []})
	IAP._on_query_product_details_response({
		"response_code": OK_CODE,
		"product_details_list": [{"bilinmeyen": "yapı"}],
	})
	IAP._on_query_product_details_response({
		"response_code": BillingClient.BillingResponseCode.ERROR,
		"product_details_list": [{
			"product_id": IAP.PRODUCT_REMOVE_ADS,
			"one_time_purchase_offer_details": {"formatted_price": "BOZUK"},
		}],
	})
	IAP.prices_updated.disconnect(sig)
	check(updated[0] == before, "boş/tanınmayan/hatalı yanıtlar sinyal yaymadı")
	check(IAP.price_for(IAP.PRODUCT_REMOVE_ADS, "₺--") == "₺149,99",
		"hatalı yanıt önceki geçerli fiyatı EZMEDİ")
