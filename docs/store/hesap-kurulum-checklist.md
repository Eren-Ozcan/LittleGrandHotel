# Hesap Kurulumu — Yalnızca Senin Yapabileceğin Adımlar

Bunlar kimlik doğrulama/ödeme gerektirdiği için benim tarafımdan yapılamıyor.
Her adımın sonunda "kod tarafında ne yapılacak" belirtildi — o kısımları
gerçek ID'leri getirdiğinde ben tamamlarım.

## 1. Google Play Console hesabı — ✅ Tamamlandı

`yilkgamesstudio@gmail.com` hesabıyla Play Console'a kayıt olundu (stüdyo
adı: **Yilk Games**). Kalanlar:

1. Play Console'da "Uygulama oluştur" ile `com.littlegrandhotel.app` paket
   adıyla yeni bir uygulama aç (paket adı `export_presets.cfg` içinde zaten
   bu şekilde ayarlı, değiştirme). Geliştirici adı olarak "Yilk Games"
   görünecek.
2. **Play App Signing**: ilk AAB'yi yüklerken Play Console otomatik olarak
   Play App Signing'e kaydolmanı ister (checkbox) — ayrı bir kurulum
   gerekmiyor, ilk yükleme akışında "Devam et" demen yeterli.

Kod tarafında yapılacak bir şey yok — imzalı AAB zaten hazır
(`android/upload-keystore.jks` ile üretildi, bkz. proje geçmişi).

## 2. AdMob hesabı + gerçek reklam ID'leri — ✅ Tamamlandı

Ödeme profili (AdSense Türkiye) bağlandı, uygulama eklendi, iki reklam birimi
oluşturuldu ve kod tarafına işlendi:

- **Hesap**: `yilkgamesstudio@gmail.com` (Play Console ile aynı hesap — ilk
  turda yanlışlıkla farklı bir kişisel hesapta (`crazything5341@gmail.com`)
  oluşturulmuştu, o hesaptaki uygulama/reklam birimleri silindi).
- **App ID**: `ca-app-pub-9709993577664180~6521383725`
  (`project.godot` → `[admob] general/android/app_id`)
- **Rewarded reklam birimi**: `ca-app-pub-9709993577664180/1269057042`
  (`src/autoload/ads.gd` → `_REWARDED_AD_UNIT_ID`)
- **Interstitial reklam birimi**: `ca-app-pub-9709993577664180/5208302053`
  (`src/autoload/ads.gd` → `_INTERSTITIAL_AD_UNIT_ID`) — ID hazır ama
  `show_interstitial()` hâlâ boş bir stub (`main.gd`'de hiçbir yerden
  çağrılmıyor); gösterim mantığı ayrı bir iş olarak eklenmeli.

Not: Yeni reklam birimlerinin gerçek reklam göstermeye başlaması AdMob
tarafında ~1 saat sürebilir.

## 3. Play Console'da uygulama içi ürünler

Ayrıntılı ID/isim/açıklama önerileri: [`uygulama-ici-urunler.md`](./uygulama-ici-urunler.md).
Kod tarafında ekstra değişiklik gerekmiyor, ürün ID'leri zaten kodla eşleşecek
şekilde yazıldı (`remove_ads`, `income_2x`).

## 4. Gizlilik politikası ve mağaza listeleme

- Metinler hazır: [`privacy-policy.html`](./privacy-policy.html) (biçimli,
  bilgi için), [`privacy-policy-plaintext.md`](./privacy-policy-plaintext.md)
  (Google Sites'a kopyala-yapıştır için düz metin),
  [`magaza-listeleme.md`](./magaza-listeleme.md).
- **Google Sites ile yayınlama** (git/repo'ya hiç dokunmadan):
  1. https://sites.google.com adresine `yilkgamesstudio@gmail.com` ile
     git, "Boş" yeni site oluştur.
  2. Site adını "Little Grand Hotel — Gizlilik Politikası (Yilk Games)" yap.
  3. `privacy-policy-plaintext.md` içeriğini kopyala, metin kutusuna
     yapıştır; `##` ile başlayan satırları Sites editöründe "Heading"
     stiliyle biçimlendir (elle, birkaç tıklama).
  4. Sağ üstten "Yayınla" (Publish) → sana bir web adresi verir (örn.
     `sites.google.com/view/little-grand-hotel-privacy`).
  5. O adresi Play Console → "Politikalar" → "Gizlilik politikası" alanına
     yapıştır.
- Grafik varlıkları: hi-res simge hazır (`icon_512.png`). Öne çıkan görsel
  (1024×500) ve telefon ekran görüntüleri henüz yok — `magaza-listeleme.md`
  içindeki checklist'te detay var, istersen birlikte üretelim.
