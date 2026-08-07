extends RefCounted
## ŞABLON — bu dosyayı `google_oauth_client.gd` adıyla KOPYALA ve doldur.
## Gerçek dosya .gitignore'ludur (bkz. src/cloud/firebase_config.gd'deki gerekçe).
##
## Değerler nereden alınır (kurulum adımları: docs/cloud-save-setup.md):
##   Google Cloud Console → APIs & Services → Credentials → Create credentials →
##   OAuth client ID → Application type: **Desktop app**
##
## İKİ ADIMI DA YAP:
##   1. İstemciyi Firebase projesi `little-grand-hotel` ile AYNI Google Cloud
##      projesinde oluştur.
##   2. Oluşan istemci kimliğini Firebase Console → Authentication → Sign-in
##      method → Google → "Whitelist client IDs from external projects" listesine
##      de ekle.
##
## Hangisinin yük taşıdığı DOĞRULANMADI: Firebase'in, `aud`'u bir Desktop
## istemcisi olan id_token'ı yalnızca proje ortaklığına bakarak kabul edip
## etmediği resmî dokümanda teyit edilemedi ve akış henüz gerçek bir hesapla
## çalıştırılmadı. Belgelenmiş olan ARIZA: `Invalid Idp Response: id_token
## audience mismatch` — yayımlanmış çözümü tam olarak 2. adımdaki liste. Bu hata
## oyuncu tarayıcıda giriş yaptıktan SONRA, en son adımda patlar; ilk bakılacak
## yer o listedir. Hangisinin yettiği ilk gerçek girişte netleşince buraya ve
## docs/cloud-save-setup.md'ye yaz.
##
## Bu dosya yoksa oyun sorunsuz çalışır: bağlama düğmesi "unavailable in this
## build" durumunda kalır (giriş KODU hazır — eksik olan yalnızca bu
## yapılandırma), bulut kaydı anonim olarak yedeklemeye devam eder.
##
## `class_name` BİLEREK YOK: gitignore'lu bir dosyanın global sınıf adı kaydı
## bırakması, dosya olmayan bir makinede .godot önbelleğinde çözülemeyen bir ada
## yol açardı. FirebaseConfig bu sabitleri load() + get_script_constant_map() ile
## okur.

const CLIENT_ID := "REPLACE_WITH_DESKTOP_CLIENT_ID.apps.googleusercontent.com"
const CLIENT_SECRET := "REPLACE_WITH_DESKTOP_CLIENT_SECRET"
