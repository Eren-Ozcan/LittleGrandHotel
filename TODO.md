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
- [x] 17 görevlik zincir (`data/quests.json`)
- [x] Kayıt/yükleme + çevrimdışı kazanç (48 saat tavan)
- [x] 40 birim test (`tests/sim_check.gd`) — headless ekonomi doğrulaması

### Görsel sürüm — Hotel City esintili
- [x] Kesit "dollhouse" görünüm: gökyüzü, silüet, bulutlar, kırmızı çatı tabelası
- [x] SVG asset seti: odalar, eşyalar, misafirler, UI ikonları
- [x] Duvar kağıtlı odalar, koyu pencere çerçeveleri, kilitli yuva perdeleri
- [x] Bina zemine oturur; sokak şeridi + vardiyada misafir kuyruğu
- [x] Yüzen toast (yerleşim zıplaması yok), canlı SS:DD:sn vardiya geri sayımı
- [x] Hız ölçeği (time_scale) kayda dahil — hızlı moddan çıkışta vardiya bozulmaz

## Yapılacaklar

### Öncelikli
- [ ] Alt bar yeniden tasarımı: koyu şerit, saat ikonlu vardiya geri sayımı, kategori ikonları (Hotel City tarzı)
- [ ] Kirli odaya dokunma geri bildirimi: temizlik animasyonu / parıltı efekti
- [ ] Coin toplama animasyonu (kasadan uçan coin'ler)
- [ ] Elmas harcama yerleri: vardiya hızlandırma, premium eşya

### Orta vade
- [ ] Ses efektleri (dokunma, toplama, seviye atlama) + lobi müziği
- [ ] Misafir animasyonları: kuyruğun içeri girmesi, odada hareket
- [ ] Oda taşıma / satma
- [ ] İstatistik ekranı (toplam gelir, temizlik sayısı, vardiya geçmişi)
- [ ] Ayarlar: ses açık/kapalı, kayıt sıfırlama

### Uzun vade
- [ ] Android dışa aktarma + dokunmatik test (720×1280 dikey)
- [ ] Geç oyun denge turu (seviye 15+ ekonomisi, kat 5–6 fiyatlandırması)
- [ ] Yeni oda tipleri ve eşya setleri (restoran, çatı bahçesi…)
- [ ] Kayıt sürümü göçü (save migration) altyapısı
- [ ] İkinci bina / prestij sistemi
