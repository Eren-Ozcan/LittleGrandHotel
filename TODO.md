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

### Hotel City incelemesi sürümü (Temmuz 2026)
Orijinal Hotel City'nin Gamezebo rehberi (Web Archive) ve Playfish resmi blog
görselleri incelenerek uyarlanan mekanik + görsel turu:
- [x] **Kademeli kirlilik → istila**: 6 saatten uzun kirli kalan oda istilaya döner (hamamböceği ikonu, koyu duvar); temizliği 150 coin. `dirty_hours` çevrimdışı ilerletmede de birikir.
- [x] **Uyuyan misafiri dürtme (gizli müfettiş)**: odadaki misafire dokun — günde 20 hak, %25 şansla yıldıza göre 40+15×yıldız coin bonusu (kayıt v8).
- [x] **Kaçan misafiri yakalama**: vardiyada ~25 sn'de bir sokakta bir misafir yürüyüp geçer; dokunursan kapıya döner, saatlik gelirin %15'i bonus.
- [x] **Hazır dekor paketleri**: Konfor / Ahşap / Kraliyet paketleri, %10–12 indirimli, kilit paketteki en yüksek eşyaya göre.
- [x] **Tesis kapasitesi**: vardiya sırasında tesislerde kapasite kadar mini misafir görünür.
- [x] **Görsel yenileme**: chibi misafirler (3 karakter), komi + hizmetçi, sütunlu/asansörlü lobi sahnesi, zengin tesis sahneleri (havuz, sinema, spor, spa, temizlik), Hotel City tarzı oda kademe metresi (kırmızı→yeşil).
- [x] Ekran görüntüsü doğrulama aracı: `tests/shot.tscn` (`-- demo` argümanıyla vardiyalı görünüm).

### Serbest blok yerleşimi + mobilya sistemi (Temmuz 2026)
Hotel City'nin gerçek "toplam blok" ekonomisine sadık, büyük bir mimari
değişiklik — sabit "N kat × 4 slot" ızgarasından serbest yerleşime geçiş:
- [x] Karakter/mobilya/oda/tesis sanatının tamamı referans sayfalardan yeni
      chibi/pastel görsellerle değiştirildi (`assets/guests`, `assets/items`,
      `assets/rooms`, `assets/ui`).
- [x] `data/economy.json`: `slots_per_floor` kaldırıldı, blok ekonomisi
      (`grid_cols`, `block_price`) eklendi; her oda tipine `footprint_w`
      (1/2/3 blok); eşyalar taban (`slot`: duvar kağıdı/zemin/yatak — tek
      seçim, ücretsiz varsayılanla gelir, yükseltilebilir) ve dekor
      (`anchor`: tavan/duvar/zemin — birikimli) olarak ikiye ayrıldı.
- [x] `game.gd`: `place_room`/`can_place_room`, `buy_block`/`can_buy_block`,
      `move_room_to`, `upgrade_base` eklendi; kayıt göçü v10→v11 (gerçek
      kullanıcı kaydıyla doğrulandı, veri kaybı yok).
- [x] `main.gd`: bina görünümü `HBoxContainer` satırlarından tek bir manuel
      konumlandırılan tuvale (`building_canvas`) taşındı — değişken kat
      genişlikleri (merdiven silüeti), zoom (−/⟳/+ + fare tekerleği + pinch)
      ve pan (sürükleme).
- [x] Oda yerleştirme: boş hücreye dokunup mağazadan seçilen oda tam o
      hücreye oturuyor (`place_room`); ayrıca mevcut bir odayı **basılı
      tutup sürükleyerek** başka bir boş hücreye taşıma (gerçek
      sürükle-bırak, ghost önizleme ile).
- [x] Sokak: düz asfalt şerit yerine kaldırım (döşeme derzli) + bordür +
      şerit çizgili yol katmanları — bina bir cadde kenarında duruyormuş
      hissi.
- [x] 32 bölümlük `sim_check.gd` test paketi yeni API'ye göre güncellendi,
      gerçek kayıt `tests/fixtures/` altına golden-fixture olarak eklendi.

## Yapılacaklar

### Kısa vade — bina görünümü ince ayarları (2026-07-12'de kullanıcıyla belirlendi, henüz yapılmadı)
- [ ] **Zoom-out sınırı çok gevşek**: bina şu an minicik kalana kadar
      uzaklaşılabiliyor. `_zoom` alt sınırı (`ZOOM_MIN`, main.gd) sıkılaştırılmalı
      ya da otel her zaman ekranda makul bir asgari boyutta kalacak şekilde
      pan/zoom clamp'i yeniden düşünülmeli.
- [ ] **"Build modu" eklenmeli**: şu an boş/satın alınmamış her hücre sürekli
      "+ Oda ekle" / "Blok aç" olarak görünüyor — bu, Hotel City'deki gibi
      değil, gereksiz görsel kalabalık yaratıyor. Bunun yerine: normal
      görünümde boş hücreler sade/nötr dursun (belki hiç buton göstermesin),
      ayrı bir "İnşa Modu" aç/kapa düğmesiyle bu moda girilince yerleştirilebilir
      hücreler belirginleşsin (vurgulanmış çerçeve/parıltı gibi).
- [ ] **Bina büyüdükçe pan (sağa/sola/yukarı/aşağı bakma) tekrar gözden
      geçirilmeli**: mevcut sürükleme-ile-pan uygulaması var ama Hotel
      City'nin serbest kamera mantığına (2D yandan kaydırmalı, engelsiz
      her yöne bakabilme) göre tekrar incelenip gerekirse iyileştirilmeli
      — özellikle çok kat + geniş bloklu büyük binalarda.

### Orta vade
- [ ] Android'de gerçek cihaz/emülatörde dokunmatik test (şu ana kadar yalnızca headless export doğrulandı)
- [ ] İkinci bina (prestij sonrası farklı bir bina teması) — şu an tek bina + çarpan modeliyle sınırlı
- [ ] **Faz 4 — Yeni sanat (yapılmadı)**: boş oda kabuğu + duvar kağıdı/zemin
      doku + yatak sprite seti gerekiyor. Mantık zaten doğru (taban eşya
      ayrı yükseltiliyor) ama görsel hâlâ eski "hazır döşenmiş sahne"
      PNG'leri (`GUEST_ROOM_ART`, main.gd). Bu, yeni AI görsel üretimi
      gerektiriyor — Claude'da görsel üretme aracı yok, önceki turlardaki
      gibi kullanıcının referans sprite sayfası göndermesi (veya üretmesi)
      ve sonra kesip entegre edilmesi gerekiyor.
- [ ] **Faz 5 — Temizlik (yapılmadı, Faz 4'e bağımlı)**: eski
      `GUEST_ROOM_ART` varyant havuzunu ve ilişkili kodu/asset'leri sil.
      Faz 4 bitmeden yapılırsa odaların arka planında hiçbir görsel
      kalmaz — bu yüzden bilerek ertelendi.

### Uzun vade
- [ ] Gerçek bulut kaydı / platform servisleri (Play Games, Game Center) — şu an cihazlar arası taşıma kod ile yapılıyor
- [ ] Haftalık temaya görsel varyasyon (yalnızca renk değil, dekor/asset değişimi)
