class_name GoogleSignIn
extends Node
## Google ile giriş — sistem tarayıcısı + loopback yönlendirmesi (OAuth 2.0,
## RFC 8252 "OAuth 2.0 for Native Apps"), PKCE ile.
##
## Bu, cloud_save.gd'deki `set_google_id_token_provider()` seam'ini dolduran
## VARSAYILAN sağlayıcıdır: bir OIDC `id_token` üretir, gerisini
## firebase_auth.link_with_google() yapar.
##
## NEDEN YERLİ (native) EKLENTİ DEĞİL
## ----------------------------------
## Godot'un yerleşik bir Google Sign-In yolu yok; seçenekler şunlardı:
##
##   1. Android için Kotlin eklentisi (Credential Manager) + iOS için ayrı bir
##      GoogleSignIn eklentisi. En iyi UX'i verir ama İKİ ayrı yerli eklenti
##      yazmak, derlemek ve her Godot sürümünde bakmak demektir.
##   2. Play Games Services eklentisi. Android'e ÖZGÜ bir kimlik üretir ve
##      cloud_save.gd'nin başında uzun uzun gerekçelendirilen "aynı oyuncu iOS'ta
##      da aynı kayda ulaşır" kararını bozar.
##   3. Bu dosya: saf GDScript, tarayıcı tabanlı OAuth.
##
## 3 seçildi çünkü TEK kod yolu Android, iOS, Windows, macOS ve Linux'ta aynı
## çalışır: yerli eklenti yok, bakılacak AAR/Framework yok, Godot yükseltmelerinde
## kırılacak bir köprü yok ve iOS portu için EK İŞ GEREKMEZ. Karşılığında oyuncu
## hesap seçicisini uygulama içinde değil tarayıcıda görür ve mobilde giriş bitince
## oyuna elle dönmesi gerekir — cihaz değişiminde ömürde bir kez yapılan bir işlem
## için kabul edilebilir bir bedel.
##
## Seam korunduğu için bu bir tek yönlü kapı DEĞİL: ileride yerli bir eklenti
## eklenirse yalnızca CloudSave.set_google_id_token_provider() çağrısı değişir,
## bu dosya dışında hiçbir şeye dokunulmaz.
##
## GÜVENLİK
## --------
## * PKCE (S256) zorunlu: yetkilendirme kodu araya girip yakalansa bile
##   `code_verifier` olmadan token'a çevrilemez.
## * `state` üretilir ve dönen istekte DOĞRULANIR — aksi halde başka bir sekmenin
##   (ya da yerel başka bir uygulamanın) loopback portumuza kendi kodunu
##   yollaması mümkün olurdu.
## * Dinleyici YALNIZCA 127.0.0.1'e bağlanır; ağdaki başka bir cihaz erişemez.
## * Tarayıcı GÖMÜLÜ webview değil, SİSTEM tarayıcısıdır: Google gömülü
##   webview'lerden gelen girişleri zaten reddeder (`disallowed_useragent`) ve
##   oyuncunun parolasını hiçbir noktada bu uygulama görmez.

const AUTH_ENDPOINT := "https://accounts.google.com/o/oauth2/v2/auth"
const TOKEN_ENDPOINT := "https://oauth2.googleapis.com/token"

## `openid` id_token için zorunlu; `email`/`profile` hesabın tanınabilir olması
## için. Oyunun buluttaki veriye erişmesi Firebase UID'siyle olur, bu kapsamlarla
## DEĞİL — bu yüzden başka hiçbir kapsam istenmez (Google doğrulama incelemesi de
## istenen kapsam kadar ağırlaşır).
const SCOPES := "openid email profile"

## Oyuncunun tarayıcıda giriş yapması için tanınan süre. Mobilde uygulama arka
## plandayken ana döngü DURUR, yani bu süre pratikte "oyuna döndükten sonra"
## işler (bkz. _await_redirect'teki sıra notu).
const FLOW_TIMEOUT_SEC := 600.0

## Token uç noktası — kısa tutulur, açılıştaki gibi kritik bir yol değil.
const REQUEST_TIMEOUT_SEC := 15.0

## Loopback dinleyicisi için port: 0 = işletim sistemi boş bir port seçsin.
## Google, "Desktop app" istemcilerinde 127.0.0.1 üzerindeki HER portu kabul eder
## (yönlendirme URI'sinin porta göre eşleşmesi bu istemci tipinde aranmaz), bu
## yüzden sabit bir port kaydetmek gerekmez ve port çakışması yaşanmaz.
const LOOPBACK_PORT_ANY := 0

## How long we wait for the player to come back to the game before giving up on
## the token exchange (see _await_foreground).
##
## The clock keeps running while the app is frozen, so this is really "how long
## the player may stay in the browser". Two minutes was shorter than the sign-in
## itself for anyone who had to type a password or pass 2FA, and the
## authorization code Google issues outlives that anyway — so it matches the
## browser round's own timeout instead.
const FOREGROUND_WAIT_SEC := FLOW_TIMEOUT_SEC

## The exchange is retried because the first request right after a resume can
## still time out while the network stack wakes up. Retrying with the same code
## is safe: Google only consumes it on a successful exchange, and a consumed
## code just fails again, which is the outcome we already had.
##
## The waits grow instead of staying at 1.5 s: a phone that just came back from
## a long browser round can need tens of seconds before background data flows
## again, and the authorization code stays valid for minutes. The old fixed
## budget (3 × 1.5 s ≈ 4.5 s) threw away a perfectly good code while the
## network was still waking up.
const EXCHANGE_BACKOFF_SEC := [1.5, 3.0, 6.0, 12.0, 20.0]

## Google errors that mean the code will never work again — retrying only
## delays telling the player. Everything else (empty body, timeout, 5xx) is
## treated as a transient network problem and retried.
const _TERMINAL_TOKEN_ERRORS := ["invalid_grant", "invalid_client", "invalid_request"]

## Used to bounce the browser back to the game once the round is done. Must match
## `package/unique_name` in export_presets.cfg — if it drifts, the auto-return
## quietly stops working and the player falls back to the button on the page.
const ANDROID_PACKAGE := "com.littlegrandhotel.app"

var _server: TCPServer
var _cancelled := false

## Tracks whether the game is in front. The browser round necessarily pushes the
## game into the background, and Android both throttles Godot's main loop and
## defers background network requests there — so a token exchange fired at that
## moment times out with an empty body and the sign-in fails silently.
var _foreground := true

## Why the last round ended without a token. Empty means "no failure recorded"
## (or the player simply cancelled). The UI turns this into a message the player
## can act on — "sign-in was not completed" alone left them with nothing to do
## and no way to tell a timeout from a rejected code.
var _last_error := ""


## Tarayıcıyı açar ve oyuncu girişi tamamlayınca Google OIDC `id_token`'ını
## döndürür. Her başarısızlık yolunda BOŞ string döner — çağıran (cloud_save.gd
## link_google) bunu "giriş tamamlanmadı" diye yorumlar ve oyun akışı bozulmaz.
func request_id_token() -> String:
	var client := FirebaseConfig.google_oauth_client()
	if String(client.get("id", "")).is_empty():
		return ""

	_cancelled = false
	_last_error = ""
	_server = TCPServer.new()
	if _server.listen(LOOPBACK_PORT_ANY, "127.0.0.1") != OK:
		_stop_server()
		return ""
	var redirect_uri := "http://127.0.0.1:%d" % _server.get_local_port()

	var verifier := _random_urlsafe(64)
	var state := _random_urlsafe(24)
	var url := "%s?%s" % [AUTH_ENDPOINT, _query_string({
		"client_id": String(client.id),
		"redirect_uri": redirect_uri,
		"response_type": "code",
		"scope": SCOPES,
		"code_challenge": _pkce_challenge(verifier),
		"code_challenge_method": "S256",
		"state": state,
		# Oyuncu daha önce bağlamış olsa bile hesabı SEÇEBİLSİN: tek hesabı olan
		# bir tarayıcıda Google aksi halde sormadan devam eder ve yanlış hesaba
		# bağlanan oyuncu geri dönemez.
		"prompt": "select_account",
	})]

	if not OS.shell_open(url) == OK:
		_stop_server()
		return ""

	var code := await _await_redirect(state)
	_stop_server()
	if code.is_empty():
		if _last_error.is_empty() and not _cancelled:
			_last_error = "no_code"
		return ""
	# The exchange itself waits for the foreground before every attempt.
	return await _exchange_code(code, verifier, redirect_uri, client)


## Oyuncu "İptal"e bastığında (ya da popup kapandığında) bekleyen akışı bırakır.
func cancel() -> void:
	_cancelled = true


## Neden token alınamadı — bkz. _last_error. Boş string: kayda değer bir hata
## yok (oyuncu vazgeçti ya da akış hiç başlamadı).
func last_error() -> String:
	return _last_error


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			_foreground = false
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN:
			_foreground = true


## Waits until the game is in front again. Only mobile suspends us hard enough
## to matter, so desktop returns immediately and keeps its current behaviour
## (there the browser is a separate window and the game keeps running).
##
## Returns false if the player never came back, cancelled, or the wait ran out —
## the caller then reports "sign-in was not completed" as it always did.
func _await_foreground() -> bool:
	if not OS.has_feature("mobile"):
		return true
	var deadline := Time.get_ticks_msec() + int(FOREGROUND_WAIT_SEC * 1000.0)
	while not _foreground:
		if _cancelled:
			return false
		if Time.get_ticks_msec() > deadline:
			return false
		await get_tree().process_frame
	return true


# --- Loopback dinleyicisi -----------------------------------------------

## Tarayıcının yönlendirmesini bekler ve `code`'u döndürür.
##
## SIRA ÖNEMLİ: her turda ÖNCE bekleyen bağlantıya bakılır, SONRA zaman aşımına.
## Mobilde uygulama arka plandayken Godot'un ana döngüsü durur; tarayıcının açtığı
## bağlantı çekirdeğin backlog'unda bekler ve oyuncu oyuna döndüğü an teslim
## edilir. Zaman aşımı önce kontrol edilseydi, tam da elimizde hazır duran kod
## atılmış olurdu.
func _await_redirect(expected_state: String) -> String:
	var started := Time.get_ticks_msec()
	while true:
		if _server != null and _server.is_connection_available():
			# await ŞART: _read_redirect kendi içinde kare bekliyor, yani bir
			# eşyordam (coroutine). await'siz çağrı ilk beklemede geri döner ve
			# Dictionary yerine null verirdi.
			var result: Dictionary = await _read_redirect(_server.take_connection())
			# Tarayıcılar /favicon.ico gibi ilgisiz istekler de atar; yalnızca
			# `state` taşıyan istek bizim yönlendirmemizdir.
			if not result.is_empty():
				if String(result.get("state", "")) != expected_state:
					# Sahte/karışmış istek: kodu KULLANMA, beklemeye devam et.
					continue
				# Oyuncu Google ekranında reddettiyse (access_denied) sebep
				# buradan gelir; sessiz "tamamlanmadı" yerine onu gösteririz.
				if result.has("error"):
					_last_error = String(result.get("error", ""))
					return ""
				return String(result.get("code", ""))
		if _cancelled:
			return ""
		if Time.get_ticks_msec() - started > FLOW_TIMEOUT_SEC * 1000.0:
			_last_error = "browser_timeout"
			return ""
		await get_tree().process_frame
	return ""


## Tek bir HTTP isteğini okur, tarayıcıya kapanış sayfasını yazar ve sorgu
## parametrelerini döndürür. İlgisiz istekte boş sözlük döner.
func _read_redirect(peer: StreamPeerTCP) -> Dictionary:
	if peer == null:
		return {}
	# İstek satırı ("GET /?code=... HTTP/1.1") tek bir TCP parçasında gelmeyebilir;
	# satır sonu görülene kadar kısa bir süre toplanır.
	var raw := ""
	var deadline := Time.get_ticks_msec() + 2000
	while Time.get_ticks_msec() < deadline:
		peer.poll()
		if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED and peer.get_available_bytes() == 0:
			break
		var available := peer.get_available_bytes()
		if available > 0:
			var chunk: Array = peer.get_partial_data(available)
			if int(chunk[0]) == OK:
				raw += (chunk[1] as PackedByteArray).get_string_from_utf8()
			if raw.find("\r\n") >= 0:
				break
		await get_tree().process_frame

	var line := raw.substr(0, raw.find("\r\n")) if raw.find("\r\n") >= 0 else raw
	var params := _parse_request_line(line)
	# Yanıtı HER durumda yaz: aksi halde tarayıcı "bağlantı sıfırlandı" gösterir
	# ve oyuncu girişin başarısız olduğunu sanır.
	_write_page(peer, params)
	peer.disconnect_from_host()
	if params.has("state") or params.has("error"):
		return params
	return {}


## "GET /?code=x&state=y HTTP/1.1" → {"code": "x", "state": "y"}
static func _parse_request_line(line: String) -> Dictionary:
	var parts := line.split(" ")
	if parts.size() < 2:
		return {}
	var q := parts[1].find("?")
	if q < 0:
		return {}
	var out := {}
	for pair in parts[1].substr(q + 1).split("&", false):
		var eq := pair.find("=")
		if eq > 0:
			out[pair.substr(0, eq).uri_decode()] = pair.substr(eq + 1).uri_decode()
	return out


## Tarayıcıda kalan sekmeye gösterilen kapanış sayfası. Tamamen kendi kendine
## yeter (dış CSS/font yok) — oyuncunun tarayıcısı bu noktada çevrimdışı bile
## olabilir.
func _write_page(peer: StreamPeerTCP, params: Dictionary) -> void:
	var ok := params.has("code")
	var title := "You're signed in" if ok else "Sign-in cancelled"
	var body := "You can close this tab and return to Little Grand Hotel." if ok \
		else "Nothing was changed. You can close this tab and try again from the game."
	var html := """<!doctype html><html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>%s</title></head>
<body style="margin:0;display:flex;align-items:center;justify-content:center;height:100vh;
background:#f3e6cf;font-family:system-ui,-apple-system,Segoe UI,Roboto,sans-serif;color:#4a3728">
<div style="text-align:center;padding:24px;max-width:26rem">
<h1 style="font-size:1.4rem;margin:0 0 .5rem">%s</h1>
<p style="margin:0;opacity:.75;line-height:1.5">%s</p>%s</div></body></html>""" \
		% [title, title, body, _return_block(ok)]
	var bytes := html.to_utf8_buffer()
	var head := "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\n" \
		+ "Content-Length: %d\r\nConnection: close\r\n\r\n" % bytes.size()
	peer.put_data(head.to_utf8_buffer())
	peer.put_data(bytes)


## Android only: sends the browser back to the game as soon as the round is done,
## so the player is not left staring at a tab wondering what to do. The button is
## kept visible as a fallback because not every stock browser honours intent://
## links, and it doubles as the manual way back if the jump is blocked.
##
## KNOWN LIMIT — this cannot rescue a suspended game, and it was measured failing
## to: the page is written by the very process it is supposed to wake, so while
## Android holds the game frozen the browser's request just sits unaccepted in
## the kernel backlog and this HTML is never sent. It helps only when the game is
## still alive behind the browser. The real cure is dropping the loopback flow
## for a native Credential Manager plugin (see TODO.md).
func _return_block(ok: bool) -> String:
	if not ok or not OS.has_feature("android"):
		return ""
	var uri := "intent://signed-in#Intent;package=%s;end" % ANDROID_PACKAGE
	return """<p style="margin:1.25rem 0 0"><a href="%s" style="display:inline-block;
padding:.6rem 1.2rem;border-radius:.5rem;background:#2f6f4f;color:#fff;
text-decoration:none">Return to the game</a></p>
<script>setTimeout(function(){location.href="%s"},600)</script>""" % [uri, uri]


func _stop_server() -> void:
	if _server != null:
		_server.stop()
		_server = null


# --- Kod → id_token -----------------------------------------------------

func _exchange_code(code: String, verifier: String, redirect_uri: String,
		client: Dictionary) -> String:
	var form := {
		"code": code,
		"client_id": String(client.get("id", "")),
		"code_verifier": verifier,
		"grant_type": "authorization_code",
		"redirect_uri": redirect_uri,
	}
	# Google'ın "Desktop app" istemcileri bir client_secret ile gelir ve kod
	# değişiminde ONU DA ister. Bu değer bir sır DEĞİLDİR (Google'ın kendi
	# dokümanı da böyle der: istemciye dağıtılan her ikili dosyadan çıkarılabilir)
	# — gerçek koruma PKCE'dir. Yine de public repo'ya yazılmaz, çünkü sızıntı
	# tarayıcıları gereksiz yere alarma geçirir; bkz. FirebaseConfig.
	var secret := String(client.get("secret", ""))
	if not secret.is_empty():
		form["client_secret"] = secret

	for attempt in EXCHANGE_BACKOFF_SEC.size():
		# The player can walk away again between attempts (a notification, a
		# second browser trip); exchanging from the background is exactly what
		# fails, so every attempt waits for the foreground first.
		if not await _await_foreground():
			_last_error = "no_foreground"
			return ""
		var res: Dictionary = await _post_form(TOKEN_ENDPOINT, form)
		if res.ok:
			var id_token := String(res.body.get("id_token", ""))
			if id_token.is_empty():
				_last_error = "no_id_token"
			return id_token
		var reason := String(res.body.get("error", ""))
		print("[GoogleSignIn] token exchange attempt %d failed: %s" % [
			attempt + 1, reason if not reason.is_empty() else "network"])
		if reason in _TERMINAL_TOKEN_ERRORS:
			_last_error = reason
			return ""
		_last_error = reason if not reason.is_empty() else "network"
		if _cancelled or attempt == EXCHANGE_BACKOFF_SEC.size() - 1:
			break
		await get_tree().create_timer(float(EXCHANGE_BACKOFF_SEC[attempt])).timeout
	return ""


func _post_form(url: String, form: Dictionary) -> Dictionary:
	var req := HTTPRequest.new()
	req.timeout = REQUEST_TIMEOUT_SEC
	add_child(req)
	var headers := PackedStringArray(["Content-Type: application/x-www-form-urlencoded"])
	var err := req.request(url, headers, HTTPClient.METHOD_POST, _query_string(form))
	if err != OK:
		req.queue_free()
		return {"ok": false, "body": {}}
	var res: Array = await req.request_completed
	req.queue_free()
	var code := int(res[1])
	var parsed = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
	var doc: Dictionary = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
	if int(res[0]) != HTTPRequest.RESULT_SUCCESS or code < 200 or code >= 300:
		return {"ok": false, "body": doc}
	return {"ok": true, "body": doc}


# --- PKCE / yardımcılar -------------------------------------------------

static func _query_string(params: Dictionary) -> String:
	var parts := PackedStringArray()
	for k in params:
		parts.append("%s=%s" % [String(k).uri_encode(), String(params[k]).uri_encode()])
	return "&".join(parts)


## RFC 7636 §4.1: `code_verifier` 43-128 karakter, base64url alfabesinden.
static func _random_urlsafe(bytes: int) -> String:
	return _base64url(Crypto.new().generate_random_bytes(bytes))


## RFC 7636 §4.2: challenge = base64url(SHA256(verifier)) — verifier'ın ASCII
## HÂLİ hash'lenir, ham rastgele baytlar değil.
static func _pkce_challenge(verifier: String) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(verifier.to_utf8_buffer())
	return _base64url(ctx.finish())


## base64url (RFC 4648 §5): standart base64'ten +/ yerine -_ ve dolgu (=) yok.
static func _base64url(data: PackedByteArray) -> String:
	return Marshalls.raw_to_base64(data) \
		.replace("+", "-").replace("/", "_").replace("=", "")
