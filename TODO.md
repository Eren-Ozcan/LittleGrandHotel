# Yol Haritası

## Yapılanlar

### Faz 0 — Gri kutu prototip
- [x] Çekirdek döngü: oda → dekorasyon → vardiya → gelir → yatırım
- [x] Veri güdümlü ekonomi (`data/economy.json`) — kodda sabit sayı yok

### MVP v2 — Çekirdek oyun
- [x] Vardiya sistemi (1/4/8/24 saat, personel maliyeti, marj bandı %5–35)
- [x] Temizlik döngüsü: odalar `stay_hours` sonunda kirlenir, gelir durur
- [x] Temizlik Odası otomasyonu (duty oranı modeli)
- [x] Dekorasyon: eşya → Stil Puanı → kademe (Basit → İkonik)
- [x] Yıldız derecesi (kademe %50 + tesis çeşitliliği %30 + hizmet %20)
- [x] XP / seviye eğrisi + seviye atlama elması
- [x] Görev zinciri (`data/quests.json`)
- [x] Kayıt/yükleme + çevrimdışı kazanç (48 saat tavan)
- [x] Birim testler (`tests/sim_check.gd`) — headless ekonomi doğrulaması

### Görsel sürüm — Hotel City esintili
- [x] Kesit "dollhouse" görünüm: gökyüzü, silüet, bulutlar, kırmızı çatı tabelası
- [x] SVG asset seti: odalar, eşyalar, misafirler, UI ikonları
- [x] Duvar kağıtlı odalar, koyu pencere çerçeveleri, kilitli yuva perdeleri
- [x] Bina zemine oturur; sokak şeridi + vardiyada misafir kuyruğu
- [x] Yüzen toast (yerleşim zıplaması yok), canlı SS:DD:sn vardiya geri sayımı
- [x] Hız ölçeği (time_scale) kayda dahil — hızlı moddan çıkışta vardiya bozulmaz

### Cila sürümü — tam çekirdek + geç oyun (Temmuz 2026)
- [x] Alt bar yeniden tasarımı: koyu şerit, saat ikonlu canlı vardiya geri sayımı, kategori ikonları
- [x] Kirli odaya dokunma geri bildirimi: altın parıltı animasyonu
- [x] Coin toplama animasyonu (kasadan sayaca uçan coin'ler)
- [x] Elmas harcama: vardiyayı elmasla anında bitirme + premium eşyalar (Altın Heykel, Kraliyet Akvaryumu)
- [x] Ses efektleri (prosedürel WAV sentezi — dış dosya yok) + lobi müziği
- [x] Misafir animasyonları: kuyrukta paytak yürüyüş, odada kıpırdanma
- [x] Oda taşıma / satma (%50 iade, premium eşya iadesi elmasla, onaylı satış)
- [x] İstatistik ekranı (toplam gelir, temizlik, vardiya geçmişi — son 20)
- [x] Ayarlar: ses/müzik aç-kapa, onaylı kayıt sıfırlama
- [x] Kayıt sürümü göçü altyapısı (v2 → v3, adım adım migrasyon zinciri)
- [x] Geç oyun denge turu (seviye 28 senaryosu, 6 kat, marj testi)
- [x] Yeni oda tipleri: Restoran (Sv.24) ve Çatı Bahçesi (Sv.28)
- [x] Görev zinciri 20 göreve çıktı (q18–q20)

### Uzun vade sürümü (Temmuz 2026)
- [x] Misafir kuyruğunun kapıdan içeri "yürüme" sahnesi (konum bazlı animasyon)
- [x] Kirli oda için parıltı yerine süpürge mini animasyonu (ardından parıltı)
- [x] Başarımlar sistemi: 13 kalıcı hedef (`data/achievements.json`), Görevler popup'ında liste, kayıt v4
- [x] Prestij sistemi: seviye 20'de oteli devredip kalıcı +%20 gelir çarpanı, kayıt v5
- [x] Haftalık dekorasyon teması: sunucusuz, `Game.current_week_index()` ile deterministik (7 tema)
- [x] Bulut kaydı yerine paylaşılabilir kayıt kodu (base64, Ayarlar'dan dışa/içe aktarma)
- [x] Android dışa aktarma: `export_presets.cfg` + ETC2 sıkıştırma + yerel imzalı debug APK doğrulandı

### Level design incelemesi + modern tüketim alışkanlıkları (Temmuz 2026)
- [x] **Kritik ekonomi çıkmazı düzeltildi**: açgözlü oda/eşya alımı oyuncuyu en ucuz vardiyayı bile karşılayamayan, kurtulması imkansız bir duruma düşürebiliyordu (headless simülasyonla bulundu). `min_shift_reserve()` artık her alımdan sonra en az 1 saatlik vardiya bedelini garanti ediyor.
- [x] **Otomatik vardiya yenileme**: vardiya bitince otel tamamen duruyordu, oyuncu günler sonra döndüğünde çoğu süre boşa gitmiş oluyordu — modern idle oyun beklentisiyle (uzaktayken de üretim sürer) çelişiyordu. Artık coin yeterse otomatik yenileniyor (kapatılabilir), "Hoş geldin" popup'ı şeffaflıkla bildiriyor.
- [x] **Vardiya süre seçiminde tuzak seçenek düzeltildi**: kısa vardiya saat başına daha ucuzdu; otomatik yenilemeyle bu, oyuncuyu tek bir "doğru" seçime kilitleyen anlamsız bir tercihe dönüşüyordu. Saatlik oran artık tüm sürelerde eşit.
- [x] **Günlük giriş serisi ödülü** eklendi: modern F2P'nin en standart tutundurma mekaniği eksikti. 7 günlük artan ödül döngüsü, sunucusuz/deterministik.
- [x] **Dekorasyon dürtmesi**: açgözlü/deneyimsiz oyuncu profilinde yıldız derecesinin hiç yükselmeme riskine karşı, boş misafir odalarında (en ucuz eşya karşılanabiliyorsa) yanıp sönen altın "✦ Dekore et!" rozeti gösteriliyor. Rozet oda butonunun sağ üstünde, dokunma zaten dekorasyon popup'ını açıyor.

## Yapılacaklar

### Orta vade
- [ ] Android'de gerçek cihaz/emülatörde dokunmatik test (şu ana kadar yalnızca headless export doğrulandı)
- [ ] İkinci bina (prestij sonrası farklı bir bina teması) — şu an tek bina + çarpan modeliyle sınırlı

### Uzun vade
- [ ] Gerçek bulut kaydı / platform servisleri (Play Games, Game Center) — şu an cihazlar arası taşıma kod ile yapılıyor
- [ ] Haftalık temaya görsel varyasyon (yalnızca renk değil, dekor/asset değişimi)
