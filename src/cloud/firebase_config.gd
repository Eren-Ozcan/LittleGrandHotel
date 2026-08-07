class_name FirebaseConfig
extends RefCounted
## Firebase proje yapılandırması (bulut kaydı — bkz. src/autoload/cloud_save.gd).
##
## Buradaki değerler istemciye gömülmesi GÜVENLİ tanımlayıcılardır, sır değil:
## Web API anahtarı yalnızca "hangi Firebase projesi" sorusunu yanıtlar. Gerçek
## koruma sunucu tarafındaki güvenlik kurallarındadır (bkz. firestore.rules) —
## bir istemci her zaman değiştirilmiş olabilir, bu yüzden "rev geriye gidemez"
## gibi garantiler istemci mantığına bırakılmaz.
##
## Placeholder'lar doldurulmadan is_configured() false döner ve bulut kaydı
## tamamen sessiz kalır (Ads/IAP'teki "eklenti yoksa no-op" deyiminin aynısı):
## oyun yalnızca yerel kayıtla, bugünkü davranışıyla çalışmaya devam eder.
## Kurulum adımları: docs/cloud-save-setup.md

## Firebase Console → Proje ayarları → Genel → Web API Anahtarı
const API_KEY := "AIzaSyDVQ7-VJKP94TYJ-VFLzJaoukPeRbqBanU"

## Firebase Console → Proje ayarları → Proje kimliği
const PROJECT_ID := "little-grand-hotel"

## Firebase'in Google sağlayıcısını kurarken ürettiği OAuth "Web istemcisi"
## kimliği. Oyun bunu ÇAĞIRMAZ (giriş akışı aşağıdaki Desktop istemcisini
## kullanır, bkz. google_signin.gd); burada, Firebase Console'daki Google
## sağlayıcı ayarının hangi istemciye baktığını belgelemek için durur.
const GOOGLE_WEB_CLIENT_ID := "210451589020-cjd16vctnebvnef5p1ithf3ibq45r50o.apps.googleusercontent.com"

## Google ile giriş akışının kullandığı OAuth "Desktop app" istemcisi.
##
## Bu iki değer BU DOSYAYA YAZILMAZ, ayrı ve gitignore'lu bir dosyadan okunur:
## Desktop istemcisinin `client_secret`'ı Google'ın kendi dokümanına göre gerçek
## bir sır değildir (dağıtılan her ikili dosyadan çıkarılabilir; asıl koruma
## PKCE'dir), ama bu repo PUBLIC ve sızıntı tarayıcıları böyle bir dizeyi
## gördüğünde hem GitHub push koruması hem Google "leaked secret" uyarısı
## tetikler. Bu yüzden `android/*.jks` ile aynı desen kullanılır: şablon
## `google_oauth_client.example.gd` commit edilir, gerçek dosya edilmez.
##
## Dosya yoksa hesap bağlama kapalı kalır (is_google_configured() false) ve
## bulut kaydı anonim olarak çalışmaya devam eder — hiçbir yol patlamaz.
const OAUTH_CLIENT_PATH := "res://src/cloud/google_oauth_client.gd"


## Bulut kaydının açık olup olmadığı tek kapı — ağ isteği yapan HER yol önce
## buna bakar.
static func is_configured() -> bool:
	return not API_KEY.begins_with("REPLACE_") and not PROJECT_ID.begins_with("REPLACE_")


## Google hesabı bağlama ayrıca bir OAuth istemcisi ister.
static func is_google_configured() -> bool:
	return is_configured() and not google_oauth_client().is_empty()


## {id, secret} — yapılandırma yoksa BOŞ sözlük.
static func google_oauth_client() -> Dictionary:
	if not ResourceLoader.exists(OAUTH_CLIENT_PATH):
		return {}
	var script := load(OAUTH_CLIENT_PATH) as GDScript
	if script == null:
		return {}
	var consts := script.get_script_constant_map()
	var id := String(consts.get("CLIENT_ID", ""))
	if id.is_empty() or id.begins_with("REPLACE_"):
		return {}
	return {"id": id, "secret": String(consts.get("CLIENT_SECRET", ""))}
