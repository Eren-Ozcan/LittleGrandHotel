class_name CloudPayload
extends RefCounted
## Bulut kaydının AĞDAN BAĞIMSIZ çekirdeği: payload üretme/uygulama, entitlement
## soyma ve çakışma kararı. Tamamen saf (static) fonksiyonlar — headless test
## edilebilsin diye HTTPRequest'ten bilerek ayrıldı (bkz. tests/cloud_save_check.gd).
##
## ENTITLEMENT (satın alınmış hak) BULUTTAN GELMEZ
## ------------------------------------------------
## `remove_ads` ve `permanent_income_mult` gerçek para karşılığı alınmış kalıcı
## haklardır ve tek doğruluk kaynakları mağazadır (bkz. iap.gd
## restore_purchases). Bunlar payload'a YAZILMAZ ve payload'dan OKUNMAZ:
##
##   * Yazma tarafı: bir kaydın (bulut dokümanı ya da dışa aktarma kodu)
##     paylaşılması bedava reklamsız/2x sürüm dağıtmak anlamına gelirdi.
##   * Okuma tarafı: elle düzenlenmiş bir payload bu alanları true yaparak aynı
##     hakkı bedavaya verirdi. Bu yüzden gelen dict'ten de temizlenir ve
##     CİHAZDAKİ değer korunur — savunma derinliği, tek yönlü filtre yetmez.
##
## Elmas (gems) bilerek payload'da KALIR: oyun içinde de kazanılan bir kaynak
## olduğu için "satın alınmış elmas" ile "görevden kazanılmış elmas" ayırt
## edilemez, ve soyulursa meşru bir bulut geri yüklemesi oyuncunun ilerlemesini
## silerdi. Bulut dokümanı zaten yalnızca sahibinin okuyabildiği `saves/{uid}`
## altında durur (bkz. firestore.rules), yani bir paylaşım vektörü değildir.
const ENTITLEMENT_KEYS := ["remove_ads", "permanent_income_mult"]

## Firestore doküman tavanı 1 MiB; kurallardaki sınırla (firestore.rules) aynı.
const MAX_PAYLOAD_BYTES := 400000

# --- Senkron kararı (saf) ----------------------------------------------

const RESULT_DISABLED := "disabled"        # yapılandırma/ağ yok — sessizce yerel devam
const RESULT_IN_SYNC := "in-sync"          # yerel en az bulut kadar güncel
const RESULT_UPLOAD := "upload"            # bulutta kayıt yok / yerel gönderilmeli
const RESULT_RESTORE := "restore"          # buluttaki daha yeni, yerelde bekleyen değişiklik yok
const RESULT_CONFLICT := "conflict"        # iki taraf da ilerlemiş — kararı oyuncu verir
const RESULT_NEEDS_UPDATE := "needs-update" # buluttaki şema bu istemciden yeni


## Çakışma kararının tamamı burada, tek bir saf fonksiyonda. Cihaz saati
## KULLANILMAZ: saati ileri alınmış bir cihaz sonsuza dek "daha yeni" görünüp
## kalıcı veri kaybına yol açardı. Karşılaştırma yalnızca monotonik `rev`
## sayacıyla yapılır (aynı garanti sunucu tarafında firestore.rules ile de
## uygulanır — istemci mantığına güvenilmez).
static func decide(local_rev: int, dirty: bool, cloud_exists: bool, cloud_rev: int,
		cloud_schema: int, local_schema: int) -> String:
	if not cloud_exists:
		return RESULT_UPLOAD
	# Daha yeni bir istemcinin yazdığı kayıt: göç (migrate) bilmediği alanları
	# eleyip veriyi bozacağı için hiç dokunma.
	if cloud_schema > local_schema:
		return RESULT_NEEDS_UPDATE
	if cloud_rev <= local_rev:
		return RESULT_UPLOAD if dirty else RESULT_IN_SYNC
	# Bulut ileride ve yerelde de gönderilmemiş değişiklik var → gerçek çakışma.
	# OTOMATİK BİRLEŞTİRME YOK: iki ilerlemeyi harmanlamak (coin'leri topla?
	# odaları birleştir?) ekonomiyi bozar ve istismara açar; kararı oyuncu verir.
	if dirty:
		return RESULT_CONFLICT
	return RESULT_RESTORE


# --- Payload üretme / uygulama -----------------------------------------

## Verilen kayıt sözlüğünden entitlement alanlarını çıkarır (kopya döner).
static func strip_entitlements(data: Dictionary) -> Dictionary:
	var copy := data.duplicate(true)
	for k in ENTITLEMENT_KEYS:
		copy.erase(k)
	return copy


## Game durumundan buluta gönderilecek JSON metnini üretir.
static func build(game) -> String:
	return JSON.stringify(strip_entitlements(game._save_dict()))


## Çakışma ekranının payload'ı açmadan gösterebildiği özet. Bulut dokümanında
## ayrı alanlar olarak saklanır, böylece "Bulut / Bu cihaz" karşılaştırması
## 400 KB'lık payload'ı ayrıştırmadan çizilebilir.
static func summary(game) -> Dictionary:
	return {
		"level": game.level(),
		"coins": game.coins,
		"gems": game.gems,
		"rooms": game.rooms.size(),
	}


## Buluttan gelen payload'ı oyun durumuna uygular.
##
## Veri, YEREL KAYITLARLA AYNI doğrulama kapısından geçer: _load_from_dict →
## _migrate_save → _validate_save_dict. O kapı fuzzer'la sertleştirildi (bkz.
## tests/fuzz_attack.gd, commit b86add2); buluttan gelen veri de en az
## forumdan yapıştırılan bir kayıt kodu kadar güvenilmezdir, bu yüzden
## kendine ait gevşek bir yol AÇILMAZ.
##
## Bozuk/geçersiz veride false döner ve oyun durumu DEĞİŞMEZ (kapı atomiktir).
static func apply(game, payload: String) -> bool:
	var parsed = JSON.parse_string(payload)
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	# Entitlement'lar cihazdan gelir; gelen payload ne derse desin yok sayılır.
	var kept := {}
	for k in ENTITLEMENT_KEYS:
		kept[k] = game.get(k)
	var incoming: Dictionary = strip_entitlements(parsed)
	if not game._load_from_dict(incoming):
		return false
	for k in ENTITLEMENT_KEYS:
		game.set(k, kept[k])
	return true


## Yepyeni/el değmemiş bir yerel kayıt mı — bulut çakışması sorulmadan doğrudan
## geri yüklenebilir. reefy'de canlı görülen sorun: taze kurulumda oyuncu birkaç
## saniye içinde kaydı "değişmiş" saydırıyor ve kod kendi başına taraf seçmediği
## için gereksiz bir çakışma ekranı açılıyordu. Burada o hızlı yol var.
static func is_pristine(game) -> bool:
	return game.stat_shifts == 0 and game.stat_collects == 0 \
		and game.stat_cleans == 0 and game.quest_index == 0 \
		and game.prestige_level == 0 and game.rooms.size() <= 2 \
		and game.floors <= 2 and game.xp == 0
