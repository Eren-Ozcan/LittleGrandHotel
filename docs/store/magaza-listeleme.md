# Play Store Mağaza Listeleme İçeriği

Play Console → "Mağaza varlığı" → "Ana mağaza listesi" bölümüne aşağıdakileri
olduğu gibi kopyala-yapıştır yapabilirsin. Karakter sınırları Google'ın kendi
sınırlarıdır; hepsi sınır altında.

## Uygulama adı (max 30 karakter)

```
Little Grand Hotel
```

## Kısa açıklama (max 80 karakter)

Aşağıdakilerden birini seç (ikisi de sınır altında):

```
Küçük bir oteli dekore et, misafir ağırla, yıldızını yükselt!
```
(62 karakter)

```
Otelini inşa et, dekore et, misafirleri ağırla — idle otel yönetimi!
```
(70 karakter)

## Tam açıklama (max 4000 karakter)

```
Little Grand Hotel, kendi küçük otelini sıfırdan büyütüp yıldızlı bir
zincire dönüştürdüğün rahat bir idle yönetim oyunu.

🏨 OTELİNİ İNŞA ET
Boş bloklardan başla, yeni odalar satın al, misafir odalarından restorana,
havuzdan spa'ya kadar tesisler ekle. Odaları istediğin gibi yerleştir,
taşı, gerekirse sat.

🛋️ DEKORE ET, YILDIZINI YÜKSELT
Her odayı mobilya ve dekorla donat, Stil Puanı topla, oteli Basit'ten
İkonik'e taşı. Ne kadar şık dekore edersen otelinin yıldız derecesi o kadar
yükselir.

⏱️ VARDİYA YÖNET
1 saatlik hızlı turdan 24 saatlik uzun vardiyaya kadar seç, personel
maliyetini ve kâr marjını dengele. Otomatik vardiya yenilemesi sayesinde
oyunu kapatsan bile otelin üretime devam eder.

🧹 TEMİZLİK VE İSTİLA
Kirlenen odaları zamanında temizle, yoksa istilaya dönüşür! Temizlik Odası
kurarak bu işi otomatikleştirebilirsin.

🚶 CANLI BİR OTEL
Kapının önünde kuyruğa giren, resepsiyonda dolaşan, asansörle yukarı çıkan
misafirlerle otelin gerçekten yaşıyormuş gibi hissettir. Kaçan bir misafiri
yakala, uyuyan bir misafiri dürtüp bonus kazan.

🏆 GÖREVLER, BAŞARIMLAR, PRESTİJ
20 görevlik bir zincir, 13 kalıcı başarım ve seviye 20'de oteli devredip
kalıcı gelir çarpanı kazandığın bir prestij sistemi seni oyunda tutar.

🎁 GÜNLÜK ÖDÜLLER VE ÇEVRİMDIŞI KAZANÇ
Her gün giriş yap, artan ödülleri topla. Oyunu kapatıp döndüğünde
çevrimdışı geçen süre için de kazanç seni bekler.

📴 İNTERNETSİZ OYNANABİLİR
Oyun tamamen cihazında çalışır, ilerlemen yerel olarak kaydedilir. İstersen
Ayarlar'dan bir kayıt kodu çıkarıp başka bir cihaza taşıyabilirsin.

Little Grand Hotel'i indir, kendi küçük otel imparatorluğunu kur!
```

## Grafik varlıkları (henüz üretilmedi — hazırlanması gerekiyor)

Play Console şunları zorunlu tutar:

- [x] **Uygulama simgesi**: 512×512 px, 32-bit PNG. `icon.svg`'den
      `tools/gen_store_icon.gd` ile üretildi → `docs/store/icon_512.png`.
- [ ] **Öne çıkan görsel (feature graphic)**: 1024×500 px, JPG/24-bit PNG
      (alfasız). Şu an elde hazır bir tasarım yok — oyun görsellerinden
      (lobi sahnesi, bina görünümü) kolaj olarak hazırlanabilir.
- [ ] **Telefon ekran görüntüleri**: en az 2, en fazla 8 adet. 16:9 veya 9:16
      oran. `tests/shot.tscn` (`-- demo` argümanıyla) kullanılarak oyun
      içinden gerçek ekran görüntüsü alınabilir — bunu birlikte
      çalıştırabiliriz.
- [ ] **Kategori**: Oyun → Simülasyon (öneri).
- [ ] **İçerik derecelendirmesi anketi**: Play Console'da doldurulmalı
      (reklam + uygulama içi satın alma var, şiddet/kumar yok → muhtemelen
      "Herkes" / PEGI 3 çıkar, anket otomatik belirler).
- [ ] **Veri güvenliği (Data safety) formu**: AdMob ve Play Billing
      kullanıldığı için "reklam kimliği" ve "satın alma bilgisi" toplandığı
      beyan edilmeli — bkz. `docs/store/privacy-policy.html` içeriği bu
      beyanla tutarlı yazıldı.
- [ ] **Gizlilik politikası URL'si**: içerik hazır
      (`docs/store/privacy-policy-plaintext.md`), Google Sites'ta
      yayınlanıp elde edilecek public URL Play Console'a girilecek —
      adımlar için [`hesap-kurulum-checklist.md`](./hesap-kurulum-checklist.md).
