extends Node
## Bulut kaydı — Firestore'da `saves/{uid}` altında TEK doküman.
##
## Tasarım reefy'de (TypeScript/Capacitor) gerçek bir hesapla uçtan uca
## doğrulandı; burada Godot'a taşınıyor. Kararlar ve gerekçeleri:
##
## * CİHAZ SAATİNE GÜVENİLMEZ. "Son yazan kazanır" mantığı, saati ileri alınmış
##   bir cihazda kalıcı veri kaybına yol açar. Bunun yerine monotonik `rev`
##   sayacı kullanılır; `updatedAt` yalnızca kullanıcıya gösterilir ve SUNUCU
##   damgasıdır. Aynı garanti firestore.rules'da da uygulanır — bayat bir
##   istemci daha yeni ilerlemeyi EZEMEZ.
##
## * ÇAKIŞMADA OTOMATİK BİRLEŞTİRME YOK. İki ilerlemeyi harmanlamak ekonomiyi
##   bozar; oyuncuya "Bulut / Bu cihaz" seçtirilir (bkz. main.gd
##   _show_cloud_conflict_modal). Seçim yapılana kadar buluta HİÇ yazılmaz,
##   yani buluttaki sürüm kendiliğinden yedek olarak kalır.
##
## * Buluttan gelen veri YEREL doğrulama kapısından geçer (CloudPayload.apply →
##   Game._load_from_dict → _validate_save_dict). O kapı saldırı fuzzer'ıyla
##   sertleştirildi (tests/fuzz_attack.gd, commit b86add2) — bulut için ayrı,
##   gevşek bir yol açılmaz.
##
## * Entitlement'lar buluttan gelmez/gitmez — bkz. cloud_payload.gd.
##
## * Yapılandırma yoksa, ağ yoksa veya bir şey ters giderse her yol sessizce
##   no-op olur ve oyun akışı bozulmaz (ads.gd/iap.gd deyimi).
##
## NEDEN PLAY GAMES SAVED GAMES DEĞİL:
## Play Games "Saved Games" API'si Android'e özgüdür ve bu proje Android VE iOS
## hedefliyor (bkz. export ayarları / yol haritası). Kayıt katmanı platforma
## özgü bir kimliğe bağlanırsa iOS sürümünde oyuncu ilerlemesini hiç taşıyamaz,
## ya da iki platform iki ayrı kayıt tutar. Firebase UID'si her iki platformda
## da aynı çalıştığı için tek kayıt/tek oyuncu modeli korunur. Bu karar
## bilinçlidir, yeniden tartışılmadan değiştirilmemeli.

const FirebaseAuthRest := preload("res://src/cloud/firebase_auth.gd")
## Yalnızca SAVE_VERSION sabitine erişmek için — şema karşılaştırması
## (buluttaki kayıt bu istemciden yeni mi) buna bakar.
const GameScript := preload("res://src/autoload/game.gd")

## rev/dirty sayaçları CİHAZDA tutulur ve save.json'dan bağımsızdır: kayıt
## sıfırlansa (reset_game) bile bulut sürüm sayacı geriye gitmemelidir.
const STATE_PATH := "user://cloud_state.json"

const FIRESTORE_BASE := "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents"

## Firestore günlük yazma kotasını koru (Spark: 20K/gün) — sık state_changed
## sinyallerinde her değişiklikte yazmayız.
##
## 5 dakika, 1 dakika DEĞİL: bu idle bir oyun, state_changed her yüklemeden hemen
## sonra kaydı yeniden kirletiyor, yani periyodik yol pratikte her pencerede bir
## yazma demek. 60 sn'de günde yarım saat oynayan bir oyuncu ~40 yazma eder ve
## ücretsiz kota ~500 günlük aktif oyuncuda dolar; 300 sn'de aynı tavan ~4 katına
## çıkar. Karşılığında kaybedilen: süreç arka plana alınma bildirimi GÖNDERMEDEN
## sert çökerse bulut kopyası en fazla bu kadar bayat kalır — yerel kayıt yine
## sağlam olduğu için bu ancak cihaz da kaybolursa fark eder.
const UPLOAD_THROTTLE_SEC := 300.0
const REQUEST_TIMEOUT_SEC := 8.0

signal sync_finished(result: String)
signal conflict_detected()
## UI'ın (Profil popup'ı) durum satırını tazelemesi için.
signal status_changed()

var _auth: Node

var _rev := 0
var _dirty := false
var _last_synced_uid := ""

var _syncing := false
var _uploading := false
## Çakışma çözülene dek yazmalar durur; buluttaki sürüm yedek olarak korunur.
var _blocked := false
var _pending_cloud: Dictionary = {}  # {rev, payload, summary, updated_at}

var _last_upload_ticks := -INF
var _last_result := ""
var _last_success_unix := 0.0
var _upload_acc := 0.0

## Google kimliğini (OIDC id_token) sağlayan kanca. VARSAYILAN olarak _ready()'de
## google_signin.gd'ye (saf GDScript, sistem tarayıcısı + PKCE) bağlanır — yani
## hesap bağlama kutudan çıktığı gibi çalışır, bir eklenti beklemez.
##
## Kanca yine de dışa açık: ileride yerli (native) bir Google Sign-In eklentisi
## gelirse tek yapılacak set_google_id_token_provider() ile onu geçirmektir;
## cloud_save.gd'nin ya da UI'ın tek satırı değişmez.
var _google_id_token_provider := Callable()

## Varsayılan sağlayıcı düğümü. Yalnızca cancel_google_signin() için tutulur —
## akışın kendisi tamamen _google_id_token_provider üzerinden yürür.
var _google_signin: GoogleSignIn

## Bağlama akışı tarayıcıya çıkıp DAKİKALARCA sürebilir (oyuncu uygulamadan
## ayrılır). Bayrak hem ikinci bir çağrıyı engeller hem de UI'ın "tarayıcı
## bekleniyor" durumunu çizebilmesini sağlar (bkz. main.gd _build_cloud_section).
var _linking := false


func _ready() -> void:
	_auth = FirebaseAuthRest.new()
	_auth.name = "FirebaseAuth"
	add_child(_auth)
	# Varsayılan Google sağlayıcısı. Ağaca EKLENMESİ şart: akış kare kare
	# get_tree().process_frame bekliyor ve HTTPRequest'i kendine ekliyor.
	# Yapılandırma yoksa da eklenir — düğüm bedava, kapıyı
	# is_account_linking_available() tutuyor (FirebaseConfig.is_google_configured).
	_google_signin = GoogleSignIn.new()
	_google_signin.name = "GoogleSignIn"
	add_child(_google_signin)
	set_google_id_token_provider(_google_signin.request_id_token)
	_load_state()
	if not is_enabled():
		return
	var game := get_node_or_null("/root/Game")
	if game:
		game.state_changed.connect(_on_game_state_changed)
	# Açılış senkronu: bir kare bekle ki Game kaydını yüklemiş olsun.
	call_deferred("sync_now")


func _process(delta: float) -> void:
	if not is_enabled():
		return
	_upload_acc += delta
	if _upload_acc < 5.0:
		return
	_upload_acc = 0.0
	maybe_upload()


func _notification(what: int) -> void:
	# Uygulama arka plana alınırken ZORUNLU yazma: mobilde süreç bundan sonra
	# hiç uyanmadan öldürülebilir, kısıtlama (throttle) beklemesi son oturumun
	# tamamen kaybolması demek olurdu.
	if what == NOTIFICATION_APPLICATION_PAUSED \
			or what == NOTIFICATION_APPLICATION_FOCUS_OUT \
			or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT \
			or what == NOTIFICATION_WM_CLOSE_REQUEST:
		flush()


# --- Dışa açık durum (UI için) ------------------------------------------

func is_enabled() -> bool:
	return FirebaseConfig.is_configured()


func has_conflict() -> bool:
	return _blocked and not _pending_cloud.is_empty()


## Çakışma ekranının göstereceği buluttaki kaydın özeti:
## {level, coins, gems, rooms, updated_at}
func conflict_summary() -> Dictionary:
	return _pending_cloud.get("summary", {})


func conflict_updated_at() -> float:
	return float(_pending_cloud.get("updated_at", 0.0))


func last_result() -> String:
	return _last_result


func last_success_unix() -> float:
	return _last_success_unix


func is_linked() -> bool:
	return _auth != null and _auth.is_linked()


## Hesap bağlama yalnızca bir Google kimlik sağlayıcısı bağlandığında anlamlı —
## bkz. _google_id_token_provider notu.
func is_account_linking_available() -> bool:
	return FirebaseConfig.is_google_configured() and _google_id_token_provider.is_valid()


func set_google_id_token_provider(provider: Callable) -> void:
	_google_id_token_provider = provider


## Bağlama akışı şu an tarayıcıyı bekliyor mu — UI bunu düğmeyi kilitli ve
## "bekleniyor" durumunda çizmek için sorar.
func is_linking() -> bool:
	return _linking


## Oyuncu vazgeçtiğinde (hesap popup'ı kapandı) bekleyen tarayıcı turunu bırakır;
## aksi halde await, google_signin.gd'deki zaman aşımı dolana kadar asılı kalırdı.
##
## Yalnızca VARSAYILAN sağlayıcıyı iptal eder: yerini bir eklenti alırsa iptali
## de o eklenti kendi yoluyla vermeli.
func cancel_google_signin() -> void:
	if _google_signin != null:
		_google_signin.cancel()


## Google hesabına bağlar ve gerekiyorsa yeni hesabın kaydını indirir.
func link_google() -> Dictionary:
	if not is_account_linking_available():
		return {"ok": false, "msg": "Linking with Google is not available in this build."}
	# İkinci çağrı, ilkinin tarayıcı turunu (ve dinleyicisini) ortasından
	# ezerdi — UI ayrıca düğmeyi kilitliyor, bu kapı son savunma.
	if _linking:
		return {"ok": false, "msg": "Sign-in is already in progress — finish it in your browser."}
	_linking = true
	status_changed.emit()
	var google_token = await _google_id_token_provider.call()
	if typeof(google_token) != TYPE_STRING or String(google_token).is_empty():
		_linking = false
		status_changed.emit()
		return {"ok": false, "msg": "Google sign-in was not completed."}
	var res: Dictionary = await _auth.link_with_google(String(google_token))
	if res.get("ok", false) and res.get("switched", false):
		# Hesap değişti: rev sayacı ESKİ hesaba aitti (bkz. _adopt_uid).
		_adopt_uid(String(res.get("uid", "")))
		await sync_now()
	_linking = false
	status_changed.emit()
	return res


# --- Senkron ------------------------------------------------------------

## Açılışta bir kez (ve hesap değişiminde) çağrılır: buluttaki kaydı yerelle
## karşılaştırır ve gerekiyorsa Game durumunu günceller.
func sync_now() -> String:
	if not is_enabled():
		return _finish(CloudPayload.RESULT_DISABLED)
	if _syncing:
		return _last_result
	_syncing = true
	var game := get_node_or_null("/root/Game")
	if game == null:
		return _finish(CloudPayload.RESULT_DISABLED)

	var token: String = await _auth.ensure_token()
	if token.is_empty():
		return _finish(CloudPayload.RESULT_DISABLED)
	var uid: String = _auth.uid()
	if uid.is_empty():
		return _finish(CloudPayload.RESULT_DISABLED)
	_adopt_uid(uid)

	var doc: Dictionary = await _get_doc(uid, token)
	if not doc.get("ok", false):
		return _finish(CloudPayload.RESULT_DISABLED)

	var decision := CloudPayload.decide(_rev, _dirty, doc.get("exists", false),
		int(doc.get("rev", 0)), int(doc.get("schema", 0)), GameScript.SAVE_VERSION)

	match decision:
		CloudPayload.RESULT_UPLOAD:
			_syncing = false
			var ok: bool = await _upload(game)
			return _finish(CloudPayload.RESULT_UPLOAD if ok else CloudPayload.RESULT_DISABLED)
		CloudPayload.RESULT_RESTORE:
			return _finish(_apply_cloud(game, doc))
		CloudPayload.RESULT_CONFLICT:
			# Taze kurulum hızlı yolu: yerel kayıt hâlâ el değmemişse çakışma
			# sormanın anlamı yok (reefy'de görülen gürültü) — doğrudan indir.
			if CloudPayload.is_pristine(game):
				return _finish(_apply_cloud(game, doc))
			_blocked = true
			_pending_cloud = {
				"rev": int(doc.get("rev", 0)),
				"payload": String(doc.get("payload", "")),
				"summary": doc.get("summary", {}),
				"updated_at": float(doc.get("updated_at", 0.0)),
			}
			conflict_detected.emit()
			return _finish(CloudPayload.RESULT_CONFLICT)
		_:
			return _finish(decision)


func _apply_cloud(game, doc: Dictionary) -> String:
	var payload := String(doc.get("payload", ""))
	if payload.is_empty() or not CloudPayload.apply(game, payload):
		return CloudPayload.RESULT_DISABLED
	_rev = int(doc.get("rev", 0))
	_dirty = false
	_blocked = false
	_pending_cloud = {}
	_save_state()
	game.save_game()
	return CloudPayload.RESULT_RESTORE


## Çakışmayı "bu cihaz kazansın" diye çözer: buluttaki rev devralınır (yoksa
## yazma kural gereği reddedilirdi) ve yerel kayıt gönderilir.
func resolve_keep_local() -> void:
	if _pending_cloud.has("rev"):
		_rev = int(_pending_cloud.rev)
	_blocked = false
	_pending_cloud = {}
	_dirty = true
	_save_state()
	var game := get_node_or_null("/root/Game")
	if game:
		await _upload(game)
	status_changed.emit()


## Çakışmayı "buluttaki kazansın" diye çözer.
func resolve_keep_cloud() -> bool:
	var game := get_node_or_null("/root/Game")
	if game == null or _pending_cloud.is_empty():
		return false
	var result := _apply_cloud(game, _pending_cloud)
	status_changed.emit()
	return result == CloudPayload.RESULT_RESTORE


# --- Yükleme ------------------------------------------------------------

func _on_game_state_changed() -> void:
	if not _dirty:
		_dirty = true
		_save_state()


## Kısıtlamalı yükleme — _process'ten periyodik çağrılır.
func maybe_upload() -> void:
	if not _dirty or _blocked or _uploading:
		return
	if Time.get_ticks_msec() / 1000.0 - _last_upload_ticks < UPLOAD_THROTTLE_SEC:
		return
	var game := get_node_or_null("/root/Game")
	if game:
		await _upload(game)


## Anında yükleme (arka plana alınırken). Kısıtlamayı atlar ama yalnızca
## gerçekten gönderilmemiş değişiklik varsa iş yapar — masaüstünde her
## odak kaybında boşuna yazma olmaz.
func flush() -> void:
	if not is_enabled() or not _dirty or _blocked or _uploading:
		return
	var game := get_node_or_null("/root/Game")
	if game:
		await _upload(game)


func _upload(game) -> bool:
	if _blocked or _uploading or not is_enabled():
		return false
	_uploading = true
	# Kısıtlamayı denemenin BAŞINDA güncelle: aksi halde çevrimdışıyken her
	# başarısız deneme kısıtlamayı sıfır bırakır ve periyodik tetikleyici bir
	# yeniden deneme fırtınasına dönüşür.
	_last_upload_ticks = Time.get_ticks_msec() / 1000.0

	var token: String = await _auth.ensure_token()
	if token.is_empty():
		_uploading = false
		return false
	var uid: String = _auth.uid()
	if uid.is_empty():
		_uploading = false
		return false
	_adopt_uid(uid)

	var payload := CloudPayload.build(game)
	# Doküman tavanını aşan kayıt (olmamalı) sessizce atlanır; yerel kayıt sağlam.
	if payload.length() > CloudPayload.MAX_PAYLOAD_BYTES:
		_uploading = false
		return false

	var next_rev := _rev + 1
	var ok: bool = await _commit(uid, token, payload, next_rev,
		CloudPayload.summary(game), GameScript.SAVE_VERSION)
	# Başarısız olsa bile rev ilerletilir: aynı rev'i tekrar denemek, yazma
	# sunucuya düşmüşse kural tarafından reddedilir (rev > mevcut olmalı) ve
	# senkron kalıcı olarak takılırdı. Sayaç ucuz, ilerletmek güvenli.
	_rev = next_rev
	if ok:
		_dirty = false
		_last_success_unix = Time.get_unix_time_from_system()
	_save_state()
	_uploading = false
	status_changed.emit()
	return ok


## Oyuncunun buluttaki kayıt dokümanını siler (Ayarlar ▸ Delete account data).
## Yerel kaydı SİLMEZ — onu çağıran taraf Game.reset_game() ile halleder.
##
## Bulut hiç yapılandırılmamışsa silinecek bir şey yoktur, `true` döner: oyuncu
## açısından "verim silindi mi?" sorusunun cevabı evet. Ağ/izin hatasında
## `false` döner ki UI dürüst bir mesaj gösterebilsin.
func delete_cloud_data() -> bool:
	if not is_enabled():
		return true
	var token: String = await _auth.ensure_token()
	if token.is_empty():
		return false
	var uid: String = _auth.uid()
	if uid.is_empty():
		return false
	var url := (FIRESTORE_BASE % FirebaseConfig.PROJECT_ID) + "/saves/" + uid.uri_encode()
	var res: Dictionary = await _request(HTTPClient.METHOD_DELETE, url, token, "")
	# 404 = doküman zaten yok; oyuncu için sonuç aynı.
	var ok: bool = res.ok or res.code == 404
	if ok:
		# Bir sonraki yükleme yeni bir dokümanı sıfırdan yazsın.
		_rev = 0
		_dirty = false
		_last_success_unix = 0.0
		_save_state()
		status_changed.emit()
	return ok


# --- Firestore REST -----------------------------------------------------

func _doc_name(uid: String) -> String:
	return "projects/%s/databases/(default)/documents/saves/%s" % [FirebaseConfig.PROJECT_ID, uid]


## {ok, exists, rev, payload, schema, summary, updated_at}
func _get_doc(uid: String, token: String) -> Dictionary:
	var url := (FIRESTORE_BASE % FirebaseConfig.PROJECT_ID) + "/saves/" + uid.uri_encode()
	var res: Dictionary = await _request(HTTPClient.METHOD_GET, url, token, "")
	# 404 = henüz kayıt yok (hata değil); diğer başarısızlıklar ağ/izin sorunu.
	if res.code == 404:
		return {"ok": true, "exists": false}
	if not res.ok:
		return {"ok": false, "exists": false}
	var fields: Dictionary = res.body.get("fields", {})
	if typeof(fields) != TYPE_DICTIONARY or fields.is_empty():
		return {"ok": true, "exists": false}
	return {
		"ok": true,
		"exists": true,
		"rev": _read_int(fields, "rev"),
		"schema": _read_int(fields, "schemaVersion"),
		"payload": _read_string(fields, "payload"),
		"summary": _read_summary(fields),
		"updated_at": _read_timestamp(fields, "updatedAt"),
	}


func _commit(uid: String, token: String, payload: String, rev: int,
		summary: Dictionary, schema: int) -> bool:
	var summary_fields := {}
	for k in summary:
		summary_fields[k] = {"integerValue": str(int(summary[k]))}
	var body := {
		"writes": [{
			"update": {
				"name": _doc_name(uid),
				"fields": {
					"payload": {"stringValue": payload},
					"rev": {"integerValue": str(rev)},
					"schemaVersion": {"integerValue": str(schema)},
					"platform": {"stringValue": OS.get_name()},
					"summary": {"mapValue": {"fields": summary_fields}},
				},
			},
			# updatedAt SUNUCU tarafında damgalanır — çakışma ekranındaki
			# "x dakika önce" cihaz saatine güvenmemeli (bkz. dosya başı notu).
			"updateTransforms": [
				{"fieldPath": "updatedAt", "setToServerValue": "REQUEST_TIME"},
			],
		}],
	}
	var url := (FIRESTORE_BASE % FirebaseConfig.PROJECT_ID) + ":commit"
	var res: Dictionary = await _request(HTTPClient.METHOD_POST, url, token, JSON.stringify(body))
	return res.ok


## {ok, code, body}. HİÇBİR yolda askıda kalmaz: HTTPRequest.timeout,
## request_completed'ın ağ yokken de tetiklenmesini garanti eder — reefy'de
## çevrimdışı bir yazma hiç sonuçlanmayıp `uploading` bayrağını kilitlemiş ve
## bulut kaydını tüm oturum boyunca öldürmüştü.
func _request(method: int, url: String, token: String, body: String) -> Dictionary:
	var req := HTTPRequest.new()
	req.timeout = REQUEST_TIMEOUT_SEC
	add_child(req)
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer " + token,
	])
	var err := req.request(url, headers, method, body)
	if err != OK:
		req.queue_free()
		return {"ok": false, "code": 0, "body": {}}
	var res: Array = await req.request_completed
	req.queue_free()
	var code := int(res[1])
	var parsed = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
	var doc: Dictionary = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
	if int(res[0]) != HTTPRequest.RESULT_SUCCESS or code < 200 or code >= 300:
		return {"ok": false, "code": code, "body": doc}
	return {"ok": true, "code": code, "body": doc}


# --- Firestore değer okuma (REST tipli değerler) ------------------------

static func _read_int(fields: Dictionary, key: String) -> int:
	var v = fields.get(key, {})
	if typeof(v) != TYPE_DICTIONARY:
		return 0
	# REST'te integerValue string olarak taşınır.
	return String(v.get("integerValue", "0")).to_int()


static func _read_string(fields: Dictionary, key: String) -> String:
	var v = fields.get(key, {})
	if typeof(v) != TYPE_DICTIONARY:
		return ""
	return String(v.get("stringValue", ""))


static func _read_summary(fields: Dictionary) -> Dictionary:
	var v = fields.get("summary", {})
	if typeof(v) != TYPE_DICTIONARY:
		return {}
	var inner = v.get("mapValue", {})
	if typeof(inner) != TYPE_DICTIONARY:
		return {}
	var sub = inner.get("fields", {})
	if typeof(sub) != TYPE_DICTIONARY:
		return {}
	var out := {}
	for k in sub:
		out[k] = _read_int(sub, String(k))
	return out


## RFC3339 ("2026-08-07T12:34:56.123456Z") → unix saniye. Godot'un ayrıştırıcısı
## kesirli saniye ve sondaki Z ile çalışmadığı için temizlenir.
static func _read_timestamp(fields: Dictionary, key: String) -> float:
	var v = fields.get(key, {})
	if typeof(v) != TYPE_DICTIONARY:
		return 0.0
	var raw := String(v.get("timestampValue", ""))
	if raw.is_empty():
		return 0.0
	var clean := raw.replace("Z", "")
	var dot := clean.find(".")
	if dot >= 0:
		clean = clean.substr(0, dot)
	return float(Time.get_unix_time_from_datetime_string(clean))


# --- Yerel durum (rev/dirty/uid) ----------------------------------------

## Oturum başka bir hesaba geçtiğinde: rev sayacı CİHAZDA tutulur ve ESKİ hesaba
## aitti; yeni hesap için anlamsızdır. Sıfırlanmazsa yerel sayaç buluttakinden
## büyük görünüp "yerel güncel" sanılır ve diğer hesabın ilerlemesi sessizce
## ezilirdi. Sıfırlayıp dirty işaretleyince bir sonraki sync iki tarafı da görüp
## kullanıcıya seçtirir.
func _adopt_uid(uid: String) -> void:
	if uid.is_empty() or uid == _last_synced_uid:
		return
	if not _last_synced_uid.is_empty():
		_rev = 0
		_dirty = true
		_blocked = false
		_pending_cloud = {}
	_last_synced_uid = uid
	_save_state()


func _load_state() -> void:
	if not FileAccess.file_exists(STATE_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(STATE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	_rev = maxi(0, int(parsed.get("rev", 0)))
	_dirty = bool(parsed.get("dirty", false))
	_last_synced_uid = String(parsed.get("uid", ""))


func _save_state() -> void:
	var f := FileAccess.open(STATE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({
			"rev": _rev, "dirty": _dirty, "uid": _last_synced_uid,
		}))


func _finish(result: String) -> String:
	_syncing = false
	_last_result = result
	if result == CloudPayload.RESULT_UPLOAD or result == CloudPayload.RESULT_RESTORE \
			or result == CloudPayload.RESULT_IN_SYNC:
		_last_success_unix = Time.get_unix_time_from_system()
	sync_finished.emit(result)
	status_changed.emit()
	return result
