extends Node
## Firebase Authentication — REST istemcisi.
##
## Godot'un resmi bir Firebase SDK'sı yok, bu yüzden kimlik doğrulama doğrudan
## Identity Toolkit REST API'siyle (HTTPRequest) yapılır. Oyunun geri kalanı bir
## oyuncuyu YALNIZCA ensure_token()/uid() üzerinden görür — kimliğin anonim mi,
## Google ile mi elde edildiği burada kapsüllenir. iOS'ta Sign in with Apple
## eklenirken yalnızca bu dosya değişir.
##
## Kimlik bilerek platforma özgü bir kimliğe (Play Games player_id / Game Center)
## BAĞLANMAZ: Firebase UID'si Android ve iOS'ta aynı şekilde çalışır, böylece
## aynı oyuncu iki platformda tek kayda ulaşır.
##
## TOKEN TAZELEME — sessiz 401'lerin kaynağı:
## ID token 1 saatte dolar. Uzun bir oyun oturumunda (idle oyun; oturum saatlerce
## açık kalabilir) tazelenmezse Firestore yazmaları bir noktadan sonra sessizce
## 401 döner ve bulut kaydı ölür. Bu yüzden her istekten önce süre kontrol edilir
## ve marjla erken tazelenir.

## Oturum diskte: yalnızca refresh token + uid. ID token KAYDEDİLMEZ (kısa
## ömürlü, her açılışta yeniden alınır).
const STATE_PATH := "user://firebase_auth.json"

const SIGNUP_URL := "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=%s"
const REFRESH_URL := "https://securetoken.googleapis.com/v1/token?key=%s"
const IDP_URL := "https://identitytoolkit.googleapis.com/v1/accounts:signInWithIdp?key=%s"

## Kötü ağda açılışı kilitlememek için — HTTPRequest.timeout, request_completed
## sinyalinin HER YOLDA tetiklenmesini garanti eder (bkz. cloud_save.gd'deki
## "bayrak takılı kalır" notu).
const REQUEST_TIMEOUT_SEC := 8.0

## Token'ı dolmasına bu kadar kala tazele (saniye).
const TOKEN_REFRESH_MARGIN_SEC := 300.0

signal _auth_settled

var _uid := ""
var _provider := "anonymous"
var _refresh_token := ""
var _id_token := ""
var _id_token_expires_at := 0.0
var _state_loaded := false
var _in_flight := false


func uid() -> String:
	return _uid


func provider() -> String:
	return _provider


## Oturum kalıcı bir hesaba bağlı mı — yani başka bir cihazda geri alınabilir mi.
func is_linked() -> bool:
	return not _uid.is_empty() and _provider != "anonymous"


## Geçerli bir ID token döndürür; yapılandırma yoksa, ağ yoksa veya bir şey ters
## giderse BOŞ string döner ve çağıran sessizce çevrimdışı devam eder.
func ensure_token() -> String:
	if not FirebaseConfig.is_configured():
		return ""
	# Eşzamanlı çağrılar (açılış senkronu + arka plana alınırken zorunlu yazma
	# aynı anda gelebilir) tek bir oturum açma denemesini paylaşır; aksi halde
	# iki ayrı anonim kullanıcı yaratılabilirdi.
	if _in_flight:
		await _auth_settled
		return _valid_token()
	var cached := _valid_token()
	if not cached.is_empty():
		return cached
	_in_flight = true
	var token: String = await _authenticate()
	_in_flight = false
	_auth_settled.emit()
	return token


func _valid_token() -> String:
	if _id_token.is_empty():
		return ""
	if Time.get_unix_time_from_system() >= _id_token_expires_at - TOKEN_REFRESH_MARGIN_SEC:
		return ""
	return _id_token


func _authenticate() -> String:
	_load_state()
	# KRİTİK SIRA (reefy'de canlı yakalandı): önce KALICI OTURUMU geri yükle,
	# ancak hiç yoksa yeni anonim kullanıcı yarat. Ters sırada her açılışta yeni
	# bir uid üretilir; oyuncunun bağladığı hesap öksüz kalır ve bulut kaydı
	# geri dönen oyuncuda hiç çalışmaz.
	if not _refresh_token.is_empty():
		if await _refresh_id_token():
			return _id_token
		# Tazeleme başarısız: ÇEVRİMDIŞI da olabiliriz. Burada yeni bir anonim
		# kullanıcı yaratmak tam da yukarıdaki hatayı geri getirirdi — token'ı
		# olduğu gibi bırak, bir sonraki denemede (ağ gelince) tekrar denenir.
		return ""
	if await _sign_up_anonymous():
		return _id_token
	return ""


# --- REST çağrıları -----------------------------------------------------

func _sign_up_anonymous() -> bool:
	var res: Dictionary = await _post_json(SIGNUP_URL % FirebaseConfig.API_KEY,
		{"returnSecureToken": true})
	if not res.ok:
		return false
	_adopt_session(String(res.body.get("localId", "")),
		String(res.body.get("idToken", "")),
		String(res.body.get("refreshToken", "")),
		float(String(res.body.get("expiresIn", "3600")).to_int()),
		"anonymous")
	return not _id_token.is_empty()


func _refresh_id_token() -> bool:
	# Bu uç nokta form-urlencoded bekler (Firebase REST dokümantasyonu), diğer
	# Identity Toolkit uçlarından farklıdır.
	var body := "grant_type=refresh_token&refresh_token=%s" % _refresh_token.uri_encode()
	var res: Dictionary = await _request(HTTPClient.METHOD_POST, REFRESH_URL % FirebaseConfig.API_KEY,
		PackedStringArray(["Content-Type: application/x-www-form-urlencoded"]), body)
	if not res.ok:
		return false
	_adopt_session(String(res.body.get("user_id", _uid)),
		String(res.body.get("id_token", "")),
		String(res.body.get("refresh_token", _refresh_token)),
		float(String(res.body.get("expires_in", "3600")).to_int()),
		_provider)
	return not _id_token.is_empty()


## Anonim oturumu kalıcı bir Google hesabına bağlar.
##
## `google_id_token` platform tarafından (Google Sign-In / Play Services) elde
## edilmiş OIDC kimliğidir — bkz. cloud_save.gd set_google_id_token_provider().
##
## KRİTİK DAL — FEDERATED_USER_ID_ALREADY_LINKED: seçilen Google hesabı zaten
## BAŞKA bir Firebase kullanıcısına bağlıysa (oyuncu daha önce başka bir cihazda
## bağlamışsa) bağlama başarısız olur. Doğru davranış hatayı yutmak değil, O
## HESABA GEÇMEK ve buluttaki kaydı indirmektir; aksi halde oyuncunun eski
## ilerlemesi kalıcı olarak erişilemez kalır.
func link_with_google(google_id_token: String) -> Dictionary:
	if not FirebaseConfig.is_google_configured():
		return {"ok": false, "switched": false, "msg": "Google sign-in is not configured."}
	var current: String = await ensure_token()
	var post_body := "id_token=%s&providerId=google.com" % google_id_token
	var payload := {
		"postBody": post_body,
		"requestUri": "http://localhost",
		"returnSecureToken": true,
	}
	if not current.is_empty():
		payload["idToken"] = current  # mevcut anonim kullanıcıya BAĞLA
	var res: Dictionary = await _post_json(IDP_URL % FirebaseConfig.API_KEY, payload)
	if not res.ok and String(res.error).find("FEDERATED_USER_ID_ALREADY_LINKED") >= 0:
		payload.erase("idToken")
		res = await _post_json(IDP_URL % FirebaseConfig.API_KEY, payload)
		if res.ok:
			var switched_uid := _adopt_idp_session(res.body)
			return {"ok": true, "switched": true, "uid": switched_uid,
				"msg": "This account already had progress saved — switched to it."}
	if not res.ok:
		return {"ok": false, "switched": false, "msg": "Google sign-in failed, please try again later."}
	var previous := _uid
	var new_uid := _adopt_idp_session(res.body)
	return {"ok": true, "switched": new_uid != previous, "uid": new_uid,
		"msg": "Your account is linked — your progress can now be opened on your other devices."}


func _adopt_idp_session(body: Dictionary) -> String:
	_adopt_session(String(body.get("localId", "")),
		String(body.get("idToken", "")),
		String(body.get("refreshToken", "")),
		float(String(body.get("expiresIn", "3600")).to_int()),
		"google.com")
	return _uid


func _adopt_session(new_uid: String, id_token: String, refresh_token: String,
		expires_in: float, new_provider: String) -> void:
	if not new_uid.is_empty():
		_uid = new_uid
	if not refresh_token.is_empty():
		_refresh_token = refresh_token
	_provider = new_provider
	_id_token = id_token
	_id_token_expires_at = Time.get_unix_time_from_system() + maxf(60.0, expires_in)
	_save_state()


# --- Kalıcı oturum ------------------------------------------------------

func _load_state() -> void:
	if _state_loaded:
		return
	_state_loaded = true
	if not FileAccess.file_exists(STATE_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(STATE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	_uid = String(parsed.get("uid", ""))
	_refresh_token = String(parsed.get("refresh_token", ""))
	_provider = String(parsed.get("provider", "anonymous"))


func _save_state() -> void:
	var f := FileAccess.open(STATE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({
			"uid": _uid, "refresh_token": _refresh_token, "provider": _provider,
		}))


# --- HTTP yardımcıları --------------------------------------------------

func _post_json(url: String, payload: Dictionary) -> Dictionary:
	return await _request(HTTPClient.METHOD_POST, url,
		PackedStringArray(["Content-Type: application/json"]), JSON.stringify(payload))


## {ok: bool, code: int, body: Dictionary, error: String}
##
## HİÇBİR yolda askıda kalmaz: HTTPRequest.timeout ayarlandığı için
## request_completed ağ yokken de tetiklenir (bkz. dosya başı notu).
func _request(method: int, url: String, headers: PackedStringArray, body: String) -> Dictionary:
	var req := HTTPRequest.new()
	req.timeout = REQUEST_TIMEOUT_SEC
	add_child(req)
	var err := req.request(url, headers, method, body)
	if err != OK:
		req.queue_free()
		return {"ok": false, "code": 0, "body": {}, "error": "request_failed"}
	var res: Array = await req.request_completed
	req.queue_free()
	var code := int(res[1])
	var text := (res[3] as PackedByteArray).get_string_from_utf8()
	var parsed = JSON.parse_string(text)
	var doc: Dictionary = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
	if int(res[0]) != HTTPRequest.RESULT_SUCCESS or code < 200 or code >= 300:
		return {"ok": false, "code": code, "body": doc, "error": _error_of(doc)}
	return {"ok": true, "code": code, "body": doc, "error": ""}


static func _error_of(doc: Dictionary) -> String:
	var e = doc.get("error")
	if typeof(e) == TYPE_DICTIONARY:
		return String(e.get("message", ""))
	return ""
