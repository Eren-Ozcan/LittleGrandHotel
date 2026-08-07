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

## Google ile giriş için OAuth "Web istemcisi" kimliği. Yalnızca hesap bağlama
## (signInWithIdp) yolunda gerekir; anonim bulut kaydı bunsuz da çalışır.
const GOOGLE_WEB_CLIENT_ID := "210451589020-cjd16vctnebvnef5p1ithf3ibq45r50o.apps.googleusercontent.com"


## Bulut kaydının açık olup olmadığı tek kapı — ağ isteği yapan HER yol önce
## buna bakar.
static func is_configured() -> bool:
	return not API_KEY.begins_with("REPLACE_") and not PROJECT_ID.begins_with("REPLACE_")


## Google hesabı bağlama ayrıca bir OAuth istemci kimliği ister.
static func is_google_configured() -> bool:
	return is_configured() and not GOOGLE_WEB_CLIENT_ID.begins_with("REPLACE_")
