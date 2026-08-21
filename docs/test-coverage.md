# Test kapsamı

Bu dosya, `tests/` altındaki paketin neyi kapsadığını ve — daha önemlisi —
**neyi kapsamadığını** kayda geçirir. Kapsamayan yerlerin listesi burada
duruyor ki bir dahaki sefere sıfırdan aranmasın.

Hepsini çalıştırmak:

```powershell
pwsh tests/run_all.ps1            # 16 test
pwsh tests/run_all.ps1 -Headless  # pencere gerektirenleri atlar (CI)
pwsh tests/run_all.ps1 -Filter cloud
```

Koşucu yalnızca çıkış koduna bakmaz. Bunun bir sebebi var:
`tests/tutorial_check` 2026-08-12'den 2026-08-20'ye kadar **0 ile çıkarak**
bozuk kaldı — bir GDScript çalışma zamanı hatası `_ready()` coroutine'ini
sessizce öldürüyor ama süreç yine de başarıyla kapanıyordu. Koşucu bu yüzden
çıktıda `SCRIPT ERROR` / `FAIL` / `Parse Error` arar **ve** her testin kendi
bitiş satırının gerçekten basıldığını doğrular; ayrıca her testin bir zaman
aşımı vardır (sahne hiç yüklenemezse süreç asılıyor).

## Testler

| Test | Ne kapsıyor | Pencere | Kontrol |
|---|---|:---:|---:|
| `sim_check` | Oynanış akışı: vardiya → gelir → temizlik → satın alma → prestij | — | 239 |
| `economy_api_check` | `game.gd`'nin geri kalan genel API'si, sınır ve hatalı girdilerle | — | 135 |
| `data_check` | `data/*.json` şeması, çapraz referanslar, kod-veri uyumu | — | 595 |
| `sfx_check` | Prosedürel ses sentezi + Android 11+ çökmesinin regresyon kapanı | — | 42 |
| `migration_check` | Kayıt göçü: her sürüm → güncel, koruma, v11 yeniden yapılandırma | — | 110 |
| `fuzz_attack` | Kötü niyetli/bozuk kayıtlar, rastgele eylem dizileri, sınır çağrıları | — | 110 |
| `cloud_save_check` | Bulut payload'ı, çakışma karar tablosu, hak sızdırmama | — | 71 |
| `cloud_api_check` | CloudSave durum makinesi: kapılar, 300 sn kısıt, durum dosyası | — | 115 |
| `ads_check` | Reklam politikası: soğuma kalıcılığı, açılışta App Open, rıza | — | 67 |
| `iap_check` | Play Billing yanıtları: consume/acknowledge ayrımı, geri yükleme, fiyat | — | 59 |
| `i18n_check` | Çeviri anahtarları, `%` dönüşümleri, İngilizce yedeği | — | 428 |
| `google_signin_check` | Yeniden deneme bütçesi, tarayıcı turu zamanlaması | — | 13 |
| `tutorial_check` | Zorunlu açılış tutorial'ı: her adım, atlama, tekrar gelmeme | ✔ | 61 |
| `ui_check` | `main.gd`: her popup, her sekme, her modal, iki dil, canlı etiketler | ✔ | 134 |
| `store_compliance_check` | Mağaza uyumu gözlemleri | — | rapor |
| `unlink_check` | Hesap bağlantısını kaldırma akışı gözlemleri | — | rapor |

Son ikisi bir geçti/kaldı kararı basmıyor, yalnızca gözlem satırları yazıyor.
Koşucu onları `PASS` değil **`REPORT`** diye işaretler — sessizce yeşil görünen
test istemiyoruz. Verdikleri satırlar elle okunmalı; bir karar satırı eklemek
açık bir iş.

## Kaynak kapsamı

Fonksiyon adının testlerde geçip geçmediğine bakan kaba bir ölçü — satır
kapsamı değil. GDScript'te satır kapsamı ölçen bir araç yok, o yüzden "her satır
kapsandı" gibi bir iddia doğrulanamaz; buradaki sayı yalnızca *hangi API'nin
hiç dokunulmadığını* gösterir.

| Dosya | Satır | Genel API | Kapsanan | İç fonksiyon | Kapsanan |
|---|---:|---:|---:|---:|---:|
| `src/autoload/game.gd` | 1669 | 92 | 92/92 (%100) | 18 | 12/18 (%67) |
| `src/main.gd` | 5337 | 0 | - | 165 | 46/165 (%28) |
| `src/autoload/ads.gd` | 332 | 5 | 5/5 (%100) | 15 | 8/15 (%53) |
| `src/autoload/iap.gd` | 197 | 3 | 3/3 (%100) | 8 | 5/8 (%62) |
| `src/autoload/cloud_save.gd` | 684 | 19 | 18/19 (%95) | 19 | 8/19 (%42) |
| `src/cloud/cloud_payload.gd` | 122 | 6 | 5/6 (%83) | 0 | - |
| `src/cloud/firebase_auth.gd` | 300 | 7 | 3/7 (%43) | 12 | 2/12 (%17) |
| `src/cloud/google_signin.gd` | 435 | 3 | 0/3 (%0) | 14 | 1/14 (%7) |
| `src/cloud/firebase_config.gd` | 65 | 3 | 2/3 (%67) | 0 | - |
| `src/sfx.gd` | 52 | 2 | 2/2 (%100) | 0 | - |
| **Toplam** | **9193** | **140** | **130/140 (%93)** | **251** | **82/251 (%33)** |

`main.gd`'nin genel API'si yok (hepsi `_` ile başlayan ekran kurma kodu); oradaki
%28, `ui_check`'in gerçekten açtığı ekranlar. `main.gd` 5337 satırla projenin
yarısından fazlası ve büyük kısmı düğüm kurma/yerleştirme — bir düğümün
"doğru göründüğünü" iddia etmek ekran görüntüsü karşılaştırması ister
(`tests/shot.gd` bunu elle yapıyor, otomatik değil).

## Kapsanmayanlar ve nedeni

- **`google_signin.gd` (%0) ve `firebase_auth.gd`'nin ağ yolları** —
  `request_id_token`, `ensure_token`, `link_with_google`, `delete_account`,
  `sign_out`. Bunlar gerçek bir tarayıcı turu ve gerçek Firebase istekleri
  gerektiriyor. `google_signin_check` yalnızca zamanlama/bütçe mantığını sürüyor.
  Ağ yolları 2026-08-21'de **elle** uçtan uca doğrulandı (anonim giriş, token
  yenileme, Firestore gidiş-dönüş, kural reddi) — bkz. `TODO.md`.
- **`cloud_save.gd`'nin `_upload`/`sync_now` gövdeleri** — bilerek. Her test
  çalışmasında üretim Firestore'una yazmak, gerçek veriyi test çöpüyle doldurur.
  `cloud_api_check` ağ dalına hiç girmeden karar mantığını sürüyor.
- **`unlink_account`, `strip_entitlements`** — ilki ağ, ikincisi
  `cloud_save_check` içinde dolaylı olarak çalışıyor ama adıyla çağrılmıyor.
- **Dokunmatik/gerçek cihaz davranışı** — emülatörde oyun siyah render ediyor
  (godot#121035, 4.8'de düzeldi), o yüzden fiziksel cihaz gerekiyor.

## Bu paketin bulduğu hatalar

Paket yazılırken üç gerçek kusur çıktı (üçü de düzeltildi):

1. **Otel adı sessizce kırpılıyordu.** Varsayılan ad 18 karakter,
   `HOTEL_NAME_MAX_LEN` 16'ydı; yeniden adlandırma modali önceden dolu metni
   kesiyor, oyuncu hiçbir şey yazmadan Kaydet'e bastığında otelin adı
   "Little Grand Hot" oluyordu. Sınır 18'e çıkarıldı; tabela autowrap ile bunu
   zaten gösteriyordu. (`ui_check`)
2. **Bozuk `cloud_state.json` açılışta hata veriyordu.** `uid` bir sayıysa
   `String(int)` geçersiz bir çağrı olduğu için `_load_state()` yarıda ölüyordu.
   Üç alanın da tipi artık tek tek doğrulanıyor. (`cloud_api_check`)
3. **Bozuk oda `base` alanı atomikliği bozuyordu.** `_validate_save_dict`
   `base`'in tipini kontrol etmiyordu; yanlış tip `room_score()` içinde,
   `_load_from_dict`'in SONUNDAKİ başarım kontrolünde patlıyordu — yani oyun
   durumu çoktan değişmiş oluyordu. Tip kapısı eklendi, `fuzz_attack`'a dört
   varyant kondu. (`fuzz_attack` + koşucu)

## Bilinen açık: kötü niyetli kayıtlarda kalan hata noktaları

`fuzz_attack` "bulgu yok" diyor (denetlediği değişmezler tutuyor) ama motor
hâlâ bozuk kayıtlarda çalışma zamanı hatası basıyor. Yukarıdaki 3 numaralı
madde bu ailenin ilk üyesiydi; kalanların yerleri:

| Yer | Sayı |
|---|---:|
| `game.gd:577` `shift_cost` | 19 |
| `game.gd:502` (`guest_rooms` lambda'sı) | 12 |
| `game.gd:519` `facility_diversity` | 6 |
| `game.gd:480-481` `room_score` | 7 |
| `game.gd:560` `hourly_income` | 2 |
| `game.gd:1112` `room_sell_gem_value` | 1 |
| `game.gd:1553` `_validate_save_dict` (doğrulamanın kendisi) | 1 |

Sonuncusu en dikkat çekeni: doğrulama kapısının kendisi bozuk girdide hata
verirse kapı görevini yapamaz. Bunların her biri kendi tip kapısını istiyor;
bunu bir sonraki sertleştirme turuna bırakmak makul, ama artık **görünür**.
