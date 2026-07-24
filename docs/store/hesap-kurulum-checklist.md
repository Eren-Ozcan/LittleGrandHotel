# Hesap Kurulumu — Yalnızca Senin Yapabileceğin Adımlar

Bunlar kimlik doğrulama/ödeme gerektirdiği için benim tarafımdan yapılamıyor.
Her adımın sonunda "kod tarafında ne yapılacak" belirtildi — o kısımları
gerçek ID'leri getirdiğinde ben tamamlarım.

## 1. Google Play Console hesabı

1. https://play.google.com/console/signup adresinden kayıt ol (~$25 tek
   seferlik ücret, kredi kartı gerekir).
2. Geliştirici hesabı onaylandıktan sonra "Uygulama oluştur" ile
   `com.littlegrandhotel.app` paket adıyla yeni bir uygulama aç (paket adı
   `export_presets.cfg` içinde zaten bu şekilde ayarlı, değiştirme).
3. **Play App Signing**: ilk AAB'yi yüklerken Play Console otomatik olarak
   Play App Signing'e kaydolmanı ister (checkbox) — ayrı bir kurulum
   gerekmiyor, ilk yükleme akışında "Devam et" demen yeterli.

Kod tarafında yapılacak bir şey yok — imzalı AAB zaten hazır
(`android/upload-keystore.jks` ile üretildi, bkz. proje geçmişi).

## 2. AdMob hesabı + gerçek reklam ID'leri

1. https://apps.admob.com adresinden AdMob hesabı aç (aynı Google
   hesabıyla girilebilir, ücretsiz).
2. "Uygulamalar → Uygulama ekle" ile Little Grand Hotel'i ekle (Play
   Console'a henüz yayınlamadıysan "Hayır, mağazalarda yayınlanmıyor"
   seçip elle paket adını `com.littlegrandhotel.app` gir).
3. Uygulama oluşunca sana bir **Uygulama Kimliği (App ID)** verilir, formatı
   `ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY`.
4. "Reklam birimleri → Reklam birimi ekle → Ödüllü" ile bir ödüllü reklam
   birimi oluştur. Sana `ca-app-pub-XXXXXXXXXXXXXXXX/ZZZZZZZZZZ` formatında
   bir **Reklam Birimi ID'si** verilir.

Bu iki değeri bana verdiğinde şurayı güncelleyeceğim:
- **App ID** → Godot editöründe Proje → Proje Ayarları →
  `admob/general/android/app_id` (şu an Google'ın test App ID'si:
  `ca-app-pub-3940256099942544~3347511713`).
- **Reklam Birimi ID'si** → `src/autoload/ads.gd:21`
  (`_REWARDED_AD_UNIT_ID`, şu an Google'ın test ID'si:
  `ca-app-pub-3940256099942544/5224354917`).

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
  1. https://sites.google.com adresine git, "Boş" yeni site oluştur.
  2. Site adını "Little Grand Hotel — Gizlilik Politikası" yap.
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
