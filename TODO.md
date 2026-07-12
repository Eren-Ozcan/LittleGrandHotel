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

### Bina görünümü ince ayarları (2026-07-12'de kullanıcıyla belirlendi)
- [x] **Zoom-out sınırı sıkılaştırıldı**: `ZOOM_MIN` artık mutlak taban
      değil, gerçek alt sınır `_effective_zoom_min()` ile bina boyutuna göre
      dinamik hesaplanıyor — bina viewport'u tam dolduracağı noktanın
      ötesine zoom-out ile geçilemiyor (11 katlı bir binayla headless
      ekran görüntüsüyle doğrulandı: tam sığdığında kenarlıksız duruyor).
- [x] **"İnşa Modu" eklendi**: bina görünümü üstünde aç/kapa düğmesi
      (`build_mode_button`). Kapalıyken boş hücreler sade/nötr panel
      (buton/metin yok), kilitli bloklar yalnızca perde görseli (fiyat
      etiketi yok); açıkken hücreler vurgulanır ve dokunulabilir olur.
      (Not: aynı gün içinde bu davranış tekrar değiştirildi — bkz. aşağıdaki
      "Mağaza rafından sürükle" bölümü; "+ Oda ekle" butonu tamamen
      kaldırıldı.)
- [x] **Pan büyük binalarda doğrulandı**: dinamik zoom-min sayesinde artık
      boş kenar boşluğu bırakacak şekilde aşırı zoom-out mümkün değil;
      İnşa Modu kapalıyken boş/kilitli hücreler artık fare olaylarını
      yutmadığından (mouse_filter ignore) sürükle-ile-pan bina geneline
      daha pürüzsüz yayılıyor. Ayrı bir kamera modeli değişikliğine gerek
      görülmedi.

### Faz 4/5 — misafir odası kabuğu + eski varyant temizliği (2026-07-12)
- [x] **Faz 4 — Yeni sanat**: beklenenin aksine yeni AI görsel üretimi
      gerekmedi — `assets/rooms/guest_wallpaper.svg` (tintable duvar kağıdı
      deseni) ve `assets/items/bed_basic|bed_wood|bed_canopy` (chibi/pastel
      yatak sprite'ları) önceki turlardan zaten repoda duruyordu ama hiç
      koda bağlanmamıştı. `_make_room_button` artık misafir odalarını
      gerçek kabukla çiziyor: `WALLPAPERS` kademesine göre tonlanan duvar
      kağıdı + yeni `guest_floor.svg` zemin şeridi + odanın `base.bed`
      alanına göre seçilen gerçek yatak sprite'ı — daha önce yatak
      yükseltmenin (`Game.upgrade_base`) görselde HİÇBİR etkisi yoktu
      (rastgele "hazır sahne" PNG'si oda tipine göre sabitti), bu artık
      düzeltildi. Yan ürün olarak `bed_wood.png`'nin yanlışlıkla
      `wardrobe_oak.png` ile aynı gardırop görseli olduğu bulundu (asset
      eşleştirme hatası) — elle çizilmiş doğru bir `bed_wood.svg` ile
      değiştirildi.
- [x] **Faz 5 — Temizlik**: eski `GUEST_ROOM_ART` sabiti (main.gd) ve artık
      hiçbir yerden kullanılmayan 15 adet `assets/rooms/guest_room_*.png`
      (+ .import) dosyası silindi.

### Mağaza rafından sürükleyerek oda ekleme (2026-07-12, kullanıcı isteği + Hotel City referansı)
Kullanıcı isteği: "açık olmayan odalar oluşturulmamış olmalı… odalar mağaza
gibi bir yerde olup orada seçip tut-sürükle şeklinde eklenmeli… yapım modu
olsun, orada düzenleme/ekleme vs olsun" (bkz. Gamezebo Hotel City rehberi).
- [x] Boş açık hücrelerdeki "+ Oda ekle" butonu tamamen kaldırıldı — artık
      hiçbir hücre kendiliğinden "oluşturulmuş" bir ekleme butonu göstermiyor.
      İlk halinde İnşa Modu açıkken hâlâ vurgulu bir çerçeve kutusu
      kalmıştı; kullanıcı geri bildirimiyle (ekran görüntüsü) bu da
      kaldırıldı — boş hücre artık İnşa Modu açık/kapalı fark etmeksizin
      HİÇBİR görsel kutu/çerçeve göstermiyor (`_make_add_cell_button`/
      `_make_plain_empty_cell`, `StyleBoxEmpty`).
- [x] İkinci geri bildirim turu: kat başına dolgu "zemin şeridi" (`row_bg`,
      her katı tam genişlikte kaplayan bej `PanelContainer`) de kaldırıldı —
      odalar ve kilitli bloklar zaten kendi tam kartlarını çiziyor, boş
      alanlarda artık doğrudan gökyüzü/silüet fonu görünüyor (Hotel City'nin
      "rooms appear to be floating in midair" total-block estetiğiyle
      birebir).
- [x] Üçüncü geri bildirim turu: kilitli blokların kırmızı perde görseli de
      (`_make_block_cell_button`) İnşa Modu kapalıyken kaldırıldı — artık
      diğer boş hücreler gibi tamamen görünmez, yalnızca İnşa Modu açıkken
      perde + fiyat + "blok al" görünüyor. Buna karşılık, artık hem odalar
      hem boş alan aynı şeffaf fon üzerinde olduğundan odaların net
      okunması için `_make_room_button`'a belirgin bir duvar çerçevesi
      eklendi (önceden tanımlı ama hiç kullanılmayan `PALETTE.frame`, kalın
      4px kenarlık) — kullanıcı isteği: "odaların etrafına duvar gibi bir
      çerçeve".
- [x] Dördüncü geri bildirim turu: oda kartları arasındaki `CELL_GAP`
      boşluğu (o ana kadar çıplak gökyüzü gösteriyordu) yeni bir dokuyla
      (`assets/ui/brick_wall.svg`, tileable running-bond tuğla deseni)
      dolduruldu — her odanın TAM hücre alanına (boşluk dahil) döşenip
      oda kartı bunun üstüne biraz içeriden oturuyor; yan yana odalar
      bitişik hücrelerde olduğundan tuğla alanları da birleşip kesintisiz
      tek duvar gibi görünüyor (kullanıcı isteği: "yan yana gelince
      birbirini tamamlasın").
- [x] Beşinci geri bildirim turu: çerçeve/tuğla "görsel olarak tutarsız,
      biraz daha geniş olsun" — `CELL_GAP` 6→12px, oda çerçeve kalınlığı
      4→7px yapıldı; tuğla dokusu artık tek tek tuğlaların seçilebildiği
      belirgin bir şerit olarak görünüyor. Ayrıca çok-hücreli oda genişliği
      (2x1/3x1 vb.) zaten mevcuttu ve doğru çalıştığı doğrulandı — Deluxe/
      Süit/Havuz/Sinema/Spa/Çatı Bahçesi 2 blok, Restoran 3 blok
      (`data/economy.json: footprint_w`), ekran görüntüsüyle (Deluxe +
      Restoran yan yana) doğru orantıda render edildiği teyit edildi.
- [x] Altıncı geri bildirim turu: lobiye de oda duvar çerçevesiyle aynı
      muamele eklendi (`lobby_wall`, `_rebuild_hotel`), sağ ucunda `DOOR_W`
      (60px) genişliğinde duvar kesiliyor. Dört deneme gerekti: (1) ayrıntılı
      SVG (sıcak ışıklı boşluk + ahşap pervaz) — kullanıcı ne olduğunu
      anlayamadı; (2) çift kanatlı camlı kapı — kullanıcı "2D dik kesitte
      gerçek kapı objesi görünmez" dedi; (3) kullanıcının gönderdiği Hotel
      City ekran görüntüsünü yanlış yorumlayıp düz renkli dikdörtgen +
      kalın çerçeve eklendi; (4) kullanıcı bunu da reddedip netleştirdi:
      "boşluk kapı gibi gözükecek zaten" — hiçbir obje/renk YOK, yalnızca
      duvarın kesilip arka planın (gökyüzü) göründüğü düz bir boşluk kaldı.
      Vardiya açılışındaki misafir yürüme animasyonu (`_guest_walk_in`) bu
      boşluğun gerçek tuval konumuna (zoom/pan'e göre çevrilmiş) doğru
      yürüyor. (Beşinci alt-turda kullanıcı fikrini değiştirip aynı konuma
      düz mavi bir `ColorRect` — `door_bar` — istedi; ilk hâli çok kalın ve
      yanlış konumdaydı (tüm `DOOR_W` boşluğunu kaplıyordu, koyu lacivert) —
      kullanıcı düzeltti: "sağdaki duvarın üstüne gelecek, cam mavisi" →
      ince (10px, `DOOR_BAR_W`) ve duvarın (`lobby_wall`) hemen sağ
      kenarına, boşluğa taşmayacak şekilde taşındı, rengi açık cam mavisine
      (`#bfe6f2`) çevrildi. Ardından kullanıcı çubuğun üst/alt uçlarının
      duvarın tavan/taban şeridine taştığını işaretledi — `DOOR_BAR_MARGIN`
      (10px) ile dikeyde içeri çekildi, üst/alt kenarlarda artık duvarın
      kendi şeridi görünüyor.)
- [x] Sekizinci geri bildirim turu: `LOBBY_H` 84→120 yapıldı — lobi
      sahnesindeki (`lobby.svg`) altın asansör önceki yükseklikte dikeyde
      tam sığmıyordu (`STRETCH_KEEP_ASPECT_COVERED` üst/altını kırpıyordu).
- [x] Dokuzuncu geri bildirim turu: lobideki komi (`bellboy.svg`) kullanıcının
      sağladığı bir referans videodan (`ro_ve_ro_arası_gif_şeklinde.mp4` —
      "R01_Neutral"/"R03_Typing" etiketli chibi resepsiyonist kareleri)
      kesilen gerçek bir resepsiyonist görseliyle değiştirildi
      (`assets/guests/receptionist.png` — ffmpeg ile kare çıkarımı +
      Pillow ile gri arka plan şeffaflaştırma + sıkı kırpma). Portre en-boy
      oranı yüzünden `_icon()`'ın sabit-kare kutusu yerine özel
      `TextureRect` + `STRETCH_KEEP_ASPECT_CENTERED` ile yerleştirildi.
- [x] Yedinci geri bildirim turu: kırmızı tuğla teksturla "sırıttı" —
      `assets/ui/brick_wall.svg` → `assets/ui/wall_block.svg` olarak sıcak
      krem/altın taş bloğu tonlarına (`PALETTE.facade`/`facade_line`/`wood`
      ailesiyle uyumlu) yeniden boyanıp yeniden adlandırıldı; desen (running-
      bond) aynı kaldı, yalnızca renk değişti.
- [x] Onuncu geri bildirim turu: kullanıcının gönderdiği bir referans sprite
      sayfasından (asansör kapısı 8 karesi, kapalı/aralık/açık) kesilen 3
      görselle (`elevator_closed/half/open.png`) animasyonlu asansör kapısı
      eklendi (`_update_elevator`, `_elevator_texture_path`, `elevator_tex`).
      Kapı, kaldırımdaki misafir kuyruğu (`_queue_count`) 1'den büyükse
      kapalı→aralık→açık→(kuyruk tamamen boşalır)→aralık→kapalı döngüsüyle
      açılıp kapanıyor; kapanıştan ~1sn sonra asansörün üstünde bir parıltı
      "misafirlerin odalarına vardığını" temsil ediyor (oda-bazlı varış
      zamanlaması veri modelinde olmadığı için tam simülasyon yerine bu
      görsel onaya sadeleştirildi — kullanıcıya bildirildi). Eskiden kuyruk
      `mini(3 + Game.rooms.size()/2, 8)` sabit bir formüldü ve HİÇ
      azalmıyordu ("uzun kuyruk" şikâyeti) — artık zamanla büyüyüp (4sn'de
      bir +1, tavan 6) asansör her açılışta tamamen boşalıyor; 2+ misafir
      varsa hepsi TEK seferde biniyor (sırayla beklemek yerine).
      Debug sırasında önemli bir bulgu: `lobby.svg`'ye eklediğim/kaldırdığım
      değişiklikler hiç etki etmiyordu çünkü `_tex()` `.svg` yanında aynı adlı
      bir `.png` varsa onu tercih ediyor — `assets/ui/lobby.png` (önceki
      turlardan kalma "chibi" nihai render) hâlâ eski asansörü içeriyordu,
      bu yüzden yeni animasyonlu katmanla YAN YANA iki asansör görünüyordu.
      Çözüm: `lobby.png`'deki eski asansör bölgesi Pillow ile duvarın kendi
      gradyanından örneklenerek boyandı (temiz, dikişsiz).
- [x] Yeni "Oda Mağazası" rafı eklendi (`build_shop_panel`/`build_shop_row`,
      yalnızca İnşa Modu açıkken görünür): her oda tipi için fiyat/seviye
      kilidi gösteren bir kart; kartı basılı tutup binaya sürükleyip
      bırakmak `Game.place_room` çağırıyor. Var olan oda-taşıma sürükleme
      sistemi (`_drag_room_id`/`_update_room_drag`/`_finish_drag`)
      `_drag_new_type` ile genelleştirildi — ikisi aynı durum makinesini
      paylaşıyor.
- [x] Tüm yapısal düzenlemeler (oda ekleme, taşıma, satma) artık yalnızca
      İnşa Modu açıkken mümkün — kapalıyken oda popup'ında Taşı/Sat butonları
      yerine bir uyarı metni gösteriliyor. Alt bar "Mağaza" butonu artık eski
      listeyi açmıyor, doğrudan İnşa Modu'nu açıyor.
- [x] Eski hedefli mağaza popup'ı (`_build_shop_popup`, `place_target_floor`/
      `place_target_col`) tamamen silindi — `Game.place_room`/`can_place_room`
      için önceden hiç birim testi yoktu, `tests/sim_check.gd`'ye eklendi.

## Yapılacaklar

### Orta vade
- [ ] Android'de gerçek cihaz/emülatörde dokunmatik test (şu ana kadar yalnızca headless export doğrulandı) — bu oturumda cihaz/emülatör bağlı değildi (`adb` bulunamadı), elle test gerekiyor
- [ ] İkinci bina (prestij sonrası farklı bir bina teması) — şu an tek bina + çarpan modeliyle sınırlı, önce ekonomi/tema tasarımı netleşmeli

### Uzun vade
- [ ] Gerçek bulut kaydı / platform servisleri (Play Games, Game Center) — şu an cihazlar arası taşıma kod ile yapılıyor
- [ ] Haftalık temaya görsel varyasyon (yalnızca renk değil, dekor/asset değişimi)
