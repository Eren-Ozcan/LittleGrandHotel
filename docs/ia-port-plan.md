# IA turu — HTML prototipinden main.gd'ye port planı

Kaynak: turn 2'nin HTML prototipi (`Little Grand Hotel - IA.dc.html`, repoda
tutulmuyor). Hedef: `src/main.gd`. Prototip bir **spesifikasyon**; kod
üretmiyor, hangi ekranda ne durduğunu ve hangi metnin göründüğünü sabitliyor.

Denetim kaynağı: `docs/ui-ia-audit.md` (2026-08-14). Aşağıdaki "audit madde N"
atıfları o dosyanın numaralı bulgularına.

**Prototip temsili.** Gerçek asset'ler (oda duvar kağıdı, yatak, lamba,
`lobby.svg` lobi şeridi, resepsiyonist/misafirler, tüm eşya ve alt bar
ikonları) repodan kopyalandı. Yol, kaldırım, bordür, çim ve boş blok ise
temsili: oyunda da sprite değil, `main.gd:1840-1900` civarında `ColorRect`
ile çiziliyor; prototip aynı PALETTE hex'lerini renk şeridi olarak kullanıyor
(asfalt `#6b6f78`, kaldırım `#c9c3b4`, bordür `#e0a83c`, çim `#6cc24a`).
Renkler doğru, kesin geometri değil. Kompozisyon da temsili: gerçek oyunda
8 kolonlu grid var, prototipte 2 blok + lobi. Amaç IA'yı test etmek, bina
render'ını taklit etmek değil — karşılaştırma yaparken piksel/geometri farkı
hata sayılmaz.

Sıra önemli: 0 yapılmadan 3 yapılamaz.

---

## Kimlik kararı — avatar ve satın alma bölünmesi

Prototipte üst bardaki avatar otel logosunu (`res://icon.svg`) taşıyordu ve
premium satın almalar Profile'ın içinde duruyordu. Bu iki karar birbirini
besleyerek yanlış bir zihinsel model kuruyor, ikisi de değişiyor.

**Oyunda iki ayrı kimlik var, karıştırılmayacak:**

| Kimlik | Nerede görünür |
|---|---|
| **Otel** — bina, yıldızlar, tema, seviye | Canvas'taki binanın kendisi + üst bardaki yıldız satırı. Ayrı bir ekran gerektirmiyor. |
| **Oyuncu / müdür** — hesap, kayıt, prestij, istatistik, ayarlar | Profile ekranı. |

Avatar **otel logosu olmayacak**: logo zaten uygulama ikonu ve açılış ekranı
(`main.gd:1303-1311`) olarak kullanılıyor; aynı görseli üst bara koymak dokunma
hedefini "otel bilgisi" gibi okutuyor. Oysa arkasındaki ekran hesap ve ayar
ekranı. Avatar bir **müdür/konsiyerj portresi** olacak, altında "Me" etiketi
(audit madde 9).

Varlık üretmeye gerek yok: `assets/guests/receptionist.png` repoda zaten var
(`maid.png` ile birlikte) ve hiçbir yerden kullanılmıyor. Avatar bu olacak.

**Satın alma bölünmesi — tek kural, istisnasız:**

- **Coin harcanan her şey** → Build / oda ekranı.
- **Gem veya gerçek para harcanan her şey** → Store. Başka hiçbir yerde
  satın alma bloğu durmaz.

Dolayısıyla Profile'da Premium bloğu **kalmıyor** (audit madde 7: bugünkü konum
gelir açısından en kötü konum, kayıt kodu ile prestij arasına gömülü). Otel
kimliği altında satın alma + ayrı bir Store aynı anda bulunmayacak; sorulan
tutarsızlık böyle çözülüyor.

İki kabul edilen istisna:

1. **Bağlamsal satın alma tetikleyicisi** — elmas yetmediğinde çıkan uyarı
   Store'un Gems sekmesini açar. Satış yeri yine Store, burada yalnızca giriş var.
2. **Restore purchases** — kanonik satır Store ▸ Premium'da. Settings'teki
   satır aynı yeri açan bir kısayol (mağaza politikası keşfedilebilirlik
   istiyor), ikinci bir uygulama değil.
**Prototipten sapma (uygulama sırasında düzeltildi).** Prototip Store'a
"Auto-renew" ve "bundle" da koyuyordu. İkisi de kodda **coin** fiyatlı
(`Game.auto_renew_buy_cost`, `Game.bundle_price`), yani kuralın kendisi onları
Store'un dışında tutuyor. Uygulanan hâli:

- **Auto-renew** → Shift popup'ında kalır (`_add_auto_renew_shop`).
- **Dekor paketleri** → Build ▸ "Decor sets" (paket seç → oda seç akışı,
  yığın sayesinde geri dönüş çalışıyor).
- **Store** iki sekme: Gems · Premium. Üçüncü bir "Offers" sekmesi açılmadı;
  gerçek para/gem ile satılan bir teklif eklendiğinde açılır.

Profile'da kalanların ortak paydası: "benim hesabım ve geçmişim" — para
harcanan hiçbir şey yok.

---

## 0. Ekran yığını (önkoşul)

`docs/ui-ia-audit.md`'nin skill karşılaştırmasındaki kök sorun: tek paylaşılan
`overlay` + tek `popup_builder` (`main.gd:3023`). Profile içinden Settings'e inip
geri dönmek bugün imkânsız.

- `popup_builder: Callable` yerine `_popup_stack: Array[Callable]`.
- `_open_popup(builder)` → stack'e push + `_rebuild_popup()`.
- `_pop_popup()` → son elemanı at; stack boşsa `overlay.hide()`.
- `NOTIFICATION_WM_GO_BACK_REQUEST` (`main.gd:336`) `_close_popup()` yerine
  `_pop_popup()` çağırsın.
- Popup başlığına `‹` butonu: stack.size() > 1 ise `_pop_popup`, değilse kapat.

Bu adım tek başına test edilebilir: Shift → Auto-renew satın al → geri.

## 1. Alt bar: 5 ikon → 4 ikon + merkez buton

`main.gd:1161-1191`.

- Sekmeler: **Build** (`wall_block.svg`), **Staff** (`broom.svg`),
  **Quests** (`icon_quest.svg`), **Store** (`gem.svg`).
- Settings sekmesi kalkar (bkz. 3). Shift sekmesi kalkar — merkez butona döner.
- Aktif durum: seçili sekmenin ikonu `PALETTE.cream` dolgulu, `PALETTE.gold`
  kenarlı bir kutucuğa oturur; etiket `gold_soft` + bold. Seçili olmayan
  ikon `modulate.a = 0.72`, etiket soluk.
- Quests'te `_current_quest()` ödül vermeye hazırsa kırmızı badge.

## 2. Merkez birincil buton — tek durum makinesi

Bugün COLLECT ayrı bir bar (`main.gd:1016-1040`), Shift ise sekme.

- Tek yuvarlak buton: vardiya yoksa **"Start shift"** → Shift popup'ı;
  vardiya varken **"Collect"** + altında biriken tutar.
- Görsel (prototip): **kırmızı daire**, alt barın Staff–Quests boşluğunda,
  barın üst kenarına binecek şekilde. Yerleşimin dışında, ekran köküne
  `PRESET_CENTER_BOTTOM` ile asılı; bar HBox'ında yalnızca yer tutan boşluk var.
- `shift_bar_label` mantığı bu butonun alt satırına taşınır.
- Eski COLLECT barı, "Theme of the week" barı ve **"Yeni kat aç" barı** silinir;
  tema bilgisi gökyüzü çipine, kat açma Build sekmesine girer.

## 3. Shop → Store, Build Mode → canvas aracı

- `Shop` sekmesinin Build Mode toggle'ı **kalkar**; yerine canvas üzerinde
  `✎ Build` çipi (gökyüzü alanında, zoom butonlarının yanında).
- Yeni `_build_store_popup(c)`: iki sekme
  - **Gems** — mevcut `_build_gems_popup` içeriği aynen.
  - **Premium** — `_build_profile_popup`'tan **taşınan** (kopyalanan değil)
    Remove Ads + Double Your Earnings blokları + **Restore purchases** satırı,
    `IAP.restore_purchases()` çağırır (audit kritik madde 1). Taşındıktan sonra
    Profile'da bu bloklardan hiçbiri kalmaz.
- Yeni `_build_build_popup(c)` (alt bardaki Build sekmesi): kat açma · oda
  satın alma (otomatik yerleşir) · **Decor sets** (`Game.eco.bundles`, oda
  seçimi sorar, sonra `Game.buy_bundle`) · İnşa Modu'nu açan buton.
- Bölme kuralı: **coin harcanan her şey Build, gem/gerçek para harcanan her şey
  Store.** Tek tek dekor alımı odanın içinde kalır (`_build_room_popup`) —
  coin ile alınıyor.
- Elmas yetersizken çıkan uyarı Store ▸ Gems'i açar (yığın sayesinde geri
  dönüş çalışır).

## 4. Profile → 4 sekme, Settings onun içine

`main.gd:3381` tek scroll'u böl. Premium bölümü buraya **girmiyor** (bkz.
kimlik kararı):

| Sekme | Ne taşır | Bugünkü kaynak |
|---|---|---|
| Account | bulut + kayıt kodu (maskeli, "Show code") | `_build_cloud_section` + 3384-3412 |
| Prestige | çarpan + prestij butonu | 3445-3461 |
| Statistics | `_add_stats_rows` | 3463-3465 |
| ⚙ Settings | ses/müzik + destek/yasal + tehlike bölgesi | `_build_settings_popup` |

- Üst bara resepsiyonist avatarı (`assets/guests/receptionist.png`) + altına
  **"Me"** etiketi (audit madde 9). Otel logosu kullanılmaz.
- Üst barın tamamına tap yerine, Profile girişi bu avatar. Panelin geri
  kalanı (coin/gem/yıldız) bilgi alanı olarak kalır; gem "+" bugünkü gibi
  Store ▸ Gems'i açar.
- Kayıt kodu `LineEdit`'i `secret = true` başlar, "Show code" ile açılır
  (audit madde 13).

## 5. Settings içeriği

`main.gd:3689`.

- `3709`'daki geliştirici notunu **sil** (audit madde 12).
- Yeni satırlar: Restore purchases (Store ▸ Premium'a gider) · Privacy policy
  (URL) · Ad preferences (UMP formunu yeniden aç) · Contact support ·
  **Delete account data** (yerel kayıt + Firestore dokümanı) · alt satırda
  `v1.0`. Bunlar audit'in 1-5 numaralı mağaza politikası maddeleri.
- "Reset save" kalır, iki adımlı onay davranışı korunur.

## 6. Yerleşim düzeltmeleri (audit 14-15)

- Prototipteki çözüm: **bina yerinde (altta) kalır**, gökyüzü durum satırını
  taşır — tek satır durum çipi ("No shift running — the hotel isn't earning.")
  + tema çipi ("Theme of the week: …") + `✎ Build` çipi. Yani boşluk binayı
  yukarı çekerek değil, gökyüzüne anlam yükleyerek kapanıyor.
- Toast alt barın **ve yuvarlak butonun** üstünde ayrı bir katmanda, ikisine de
  binmeyecek şekilde.
- Staff ikonu `broom.svg`, dişli yalnız Settings'te kalır (audit madde 11).

## 8. Prototipin görsel dili (IA değil, görünüm)

Prototipten alınanlar:

- **Alt bar seçili durumu**: aktif sekmenin ikonu krem dolgulu + altın kenarlı
  kutucuğa oturur, etiketi `gold_soft`; pasif ikon `modulate.a = 0.72`, etiket
  0.78. "Aktif" = açık popup, popup yoksa İnşa Modu açıkken Build.
- **Görev rozeti**: ödül almaya hazır görev varken Quests ikonunun sağ üstünde
  kırmızı rozet.
- **Popup başlık şeridi**: koyu plum bant — solda yuvarlak `‹` (yığın >1),
  ortada başlık, sağda coin/gem göstergesi, sağ uçta yuvarlak `✕`. Oyuncu
  satın alma ekranındayken bakiyesini görmek için ekranı kapatmıyor.
- **XP sayacı**: üst barda çubuğun sağında "0 / 55 XP".

## 7. Avatar varlığı

- Kaynak: **`assets/guests/receptionist.png`** — repoda var, bugün hiçbir
  yerden referans edilmiyor. Yeni varlık üretilmeyecek.
- ~64x64 gösterilecek, yuvarlak maskeli `PALETTE.gold` çerçeve içinde;
  `TextureRect` + `STRETCH_KEEP_ASPECT_CENTERED`.
- `icon.svg` (otel logosu) avatar olarak **kullanılmaz**; yeri açılış ekranı
  ve uygulama ikonu.

---

## Doğrulama

Her adımdan sonra, `docs/ui-ia-audit.md`'de yazılı komutla:

```
tools\Godot_v4.7-stable_win64_console.exe --path . res://tests/shot.tscn ^
  --resolution 720x1280 -- demo popup=<ad> out=<dosya>.png
```

`popup=` değerleri (eklendi): `build`, `store`, `store_premium`,
`profile_account`, `profile_prestige`, `profile_stats`, `profile_settings`,
`room`.
Ekran görüntüsünü prototipteki aynı ekranla yan yana koy.

Ek kontrol (bölünme kuralı için): `_build_profile_popup` altında
`IAP.purchase` çağrısı kalmamalı — grep ile doğrula.

Yığın doğrulaması geçti: Build → dekor paketi → oda seçimi → ‹ geri
(stack 1 → 2 → 1, geri butonu yalnızca 2'de görünüyor, kökte pop popup'ı
kapatıyor).

## Kart turu (portun ikinci turu)

İlk portta bilerek atlanmış iki madde tamamlandı:

- **Kart tasarımı.** Popup içerikleri düz satır listesi olmaktan çıktı; her
  mantıksal grup `_section(c, "Başlık")` ile kendi kartına girdi (krem zemin,
  ince altın kenar, küçük büyük harf başlık — bkz. `_card` / `_section`,
  `main.gd`). Popup gövdesi kartlardan ayrışsın diye `cream_dark`'a indi.
  Tehlike bölgesi kartı kırmızı kenar + kırmızı başlık alır (`_section`'ın
  `accent` parametresi).
- **Saat ikonu.** Gökyüzü durum çipi artık `icon_clock.svg` + metin.

## Tam ekran menü sayfası (portun üçüncü turu)

Menüler ortalanmış popup kutusu olmaktan çıktı; prototipin `sheetOpen` bloğunun
birebir karşılığı oldu:

```html
<div style="position:absolute;inset:0;z-index:6;background:#fff6e6;
            display:flex;flex-direction:column">
  <div style="padding:12px;background:#3a2c4d"> ‹  Başlık   🪙 …  💎 … </div>
  <div style="flex:1;overflow:auto;padding:12px"> …kartlar… </div>
</div>
```

- `overlay` tam ekran: karartma, ortalanmış kutu ve "dışına dokununca kapanır"
  davranışı kalktı — dışarısı diye bir yer yok. Alt bar da örtülür (prototipte
  bar `z-index:4`, sayfa `z-index:6`); `overlay` ağaçta `collect_button`'dan
  sonra eklendiği için üstte kalıyor.
- Başlık şeridi köşesiz, ekran genişliğinde, `bar_dark` (#3a2c4d).
- `‹` **her zaman** görünür: yığın >1 ise bir seviye geri, kökteyse sayfayı
  kapatır. `✕` de her zaman görünür ve doğrudan kapatır — Android geri tuşuna
  bağımlı kalınmasın diye (kullanıcı isteği, prototipte yalnızca `‹` vardı).
- Kartlar prototipteki değerlere hizalandı: zemin saf beyaz, kenar
  `2px facade_line` (#e6b866), köşe 12. Sayfa gövdesi `cream` (#fff6e6).
- `_fit_popup_height` kalktı: sayfa zaten tüm ekranı kaplıyor.
- `overlay.z_index = 100`, `toast_panel.z_index = 110`. Ağaçta sonra gelmek
  yetmiyordu: yürüyen misafirler `_walker_layer.z_index = 50` ile çiziliyor ve
  menü açıkken listenin üstünde yürüyor görünüyorlardı.

### Sayfa içi biçimler

Menü gövdeleri de prototipin satır diline çevrildi. Ortak primitif
`_sheet_row(c, cfg)`: görünen kutu bir `PanelContainer`, tıklama onun üstüne
serilen şeffaf `Button` (Godot'da `Button` çocuklarından minimum boy almaz).
Üzerine kurulan biçimler:

| Yardımcı | Prototip karşılığı |
|---|---|
| `_row` | beyaz liste satırı: ikon 34px · ad + açıklama · sağda fiyat |
| `_buy_row` | aynısı, fiyat yeşil hap içinde (gerçek para / gem) |
| `_action` | sola hizalı kahverengi birincil buton, iki satır |
| `_danger` | dolu kırmızı (veri silme) / yumuşak kırmızı (sıfırlama) |
| `_tile` + `_add_room_tiles` | 3'lü ızgara karo: ikon üstte, ad, fiyat |
| `_list_card` + `_list_row` | tek kutu, satırlar 1px `cream_dark` çizgiyle |
| `_notice` | kutular: `gold` vurgu · `warn` kırmızı · `dark` plum |
| `_bar` | 9 piksel, tam yuvarlak uçlu ilerleme çubuğu |
| `_section` | kart İÇİNDE başlık değil, grubun ÜSTÜNDE büyük harf etiket |
| `_inert` / `_style_field` | `#f7f1e2` inert şerit / metin kutusu |

Sekmeler prototipteki gibi hap (`border-radius:999px`).

### Üst bar ve gökyüzü çipleri

- Krem kart artık YALNIZCA para/seviye bloğunu sarıyor; avatar kartın dışında,
  gökyüzünün üstünde ayrı bir kutu (prototipte de öyle). Kart gölgesi
  `0 3px 0 rgba(110,79,49,.18)` — yumuşak değil, kaydırılmış düz gölge.
- Coin ile gem arasında 1 piksellik `cream_dark` ayraç; gem sayısı yeşil.
  `+` butonu 30 piksel, yeşil kenarlı, `green_soft` zeminli.
- Seviye satırı: `LEVEL n` küçük büyük harf · 10 piksel tam yuvarlak çubuk
  (`cream_dark` iz + `facade_line` kenar, altın dolgu) · `n / m XP`.
- Avatar 62×86 kutu + altında krem "Me" hapı.
- Durum satırı, `✎ Build` ve haftanın teması artık `_chip()` hapları: yarı
  saydam koyu zemin (`chip_dark`), tema hapı `theme.accent` %90 saydamlıkta.

Uyarı: `Button` bir `Container` DEĞİL — çocuklarını yerleştirmez ve onlardan
minimum boy almaz. Avatar butonu bir kez bu yüzden HBox'ta 0 genişlik sayılıp
ekranın dışına taştı; boy elle veriliyor, içerik `PRESET_FULL_RECT` ile
sabitleniyor (aynı desen `_sheet_row` ve `_tile`'da da var).

Prototipten iki zorunlu sapma:

- **Bulut ikonu kullanılmadı** (Account kartı, Restore satırı): `cloud.svg`
  beyaz gövdeli bir gökyüzü bulutu, beyaz kartın üstünde görünmüyor.
- **Misafir odalarının ikonu yatak görselleri** (`ROOM_LIST_ICONS`):
  standard/deluxe/suite için `assets/rooms/` altında görsel yok — prototip de
  aynı şeyi yapıyor.

## Dördüncü tur — kalan istekler ve prototip farkları

Kullanıcının 5 maddelik listesi + prototipte olup aktarılmamış 9 fark bu turda
kapatıldı.

### Kullanıcı istekleri

1. **Alt bar sekmeleri karo oldu.** Pasif karo artık görünür: `rgba(cream,.10)`
   zemin + `rgba(cream,.16)` kenar, ölçü 42×38, köşe 12. Aktif karo dolu krem +
   altın kenar ve `0 3px 0 #b8862a` gölge (`_bar_button`).
2. **Vardiya bitirilebiliyor.** Merkez buton birikim varken "Collect"e döndüğü
   için Shift sayfasına ("Finish now — N gems") ulaşılamıyordu. Gökyüzü durum
   çipi ikinci giriş oldu: tıklanabilir, sonunda `›` chevron taşıyor.
3. **Tam genişlik yerleşim.** Kök `MarginContainer` 14 → 0; bina ve alt bar iki
   kenara değiyor. Yan boşluğa ihtiyacı olan parçalar (üst bar, gökyüzü
   çipleri, inşa rafı) `_edge_pad()` ile kendi boşluğunu taşıyor. Merkez buton
   ve toast ofsetleri 14 piksel aşağı kaydı.
4. **Temizlik Modu.** Kirli odaya dokununca anında temizleme KALKTI. Staff
   ekranındaki "Cleaning mode" satırı İnşa Modu gibi bir tuval modu açıyor
   (`_set_clean_mode`), gökyüzünde `🧹 Clean` çipi var, kirli odalar modda altın
   çerçeve alıyor ve son kirli oda temizlenince mod kendiliğinden kapanıyor.
   İki tuval modu birbirini dışlar.
5. **Gökyüzü çip renkleri sabitlendi.** Tema hapı artık haftalık `theme.accent`
   ile renklenmiyor, prototipteki sabit `rgba(224,85,74,.9)`; `✎ Build` çipi
   `rgba(47,36,24,.66)`.

### Prototipten aktarılan 9 fark

1. **Günlük ödül D1…D7 şeridi** (`_daily_strip`) + başlıkta `sparkle.svg`.
   Bugünkü karo vurgulu, geçmiş günler sönük.
2. **Çevrimdışı kazanç modalı**: süre + tavan satırı, coin ikonlu tutar kartı,
   **Collect** ve **Watch an ad — double it** (`Game.add_pending_income`).
   Süreyi yazabilmek için `Game.offline_seconds` eklendi.
3. **Quests ekranı iki hap sekme** (Quests · Achievements) + **NEXT UP** listesi
   (sıradaki en fazla 4 görev, kilitli satır biçiminde).
4. **Quest rozeti sayı taşıyor** (`quest_badge_label`), sabit `!` değil.
5. **Build ekranında blok fiyatı satırı** — fiyat kata göre değiştiği için
   "hâlâ genişletilebilen katların en ucuzu" yazılıyor.
6. **Toast** koyu `#2f2418` hap oldu; içeriğe göre daralıyor (autowrap'ın
   minimum genişlik tuzağı için metin genişliği elle ölçülüyor, üst sınır 420).
7. **Alt bar şeridi** köşesiz, altın kenarsız: düz `bar_dark` + `3px` `bar_edge`
   üst kenar.
8. **Merkez yuvarlak buton**: StyleBoxFlat yalnızca sert alt gölge (`red_lip`),
   üstüne 6 piksel yukarıda duran radial `GradientTexture2D` — son durağı
   saydam olduğu için kare doku daire gibi görünüyor.
9. **Bulut çakışma modalı** iki yan yana kart; seçim butonu her kartın içinde
   (`_cloud_side_card`).

Doğrulama: `tests/shot.gd`'ye `modal=daily`, `modal=offline`, `modal=conflict`,
`toast=<metin>` ve `popup=quests_achievements` argümanları eklendi. Demo
çekimlerinde açılışta çıkan çevrimdışı modalı ekranı kapatmasın diye
`offline_earned` sıfırlanıyor.

### Cihaz/gözden geçirme sonrası düzeltmeler

Turun ardından oyun üzerinden yapılan gözden geçirmede çıkanlar:

- **Çim köşeleri düz**, kök VBox'ın ortak ayırıcısı kalktı — bina ile alt bar
  arasından gökyüzünün pembe alt ucu sızıyordu. Aralar `_edge_pad`'in alt kenar
  boşluğuyla veriliyor.
- **Alt bar ikonları büyüdü** (karo 52×46, ikon 42, bar 104) — prototip ölçüsü
  (42×38 / 34) kullanıcıya küçük geldi. Merkez buton ve toast ofsetleri kaydı.
- **Merkez buton** vardiya sürerken ama kazanç yokken "Running" yazıyor;
  "Collect" yalnızca toplanacak bir şey varken.
- **Gökyüzü mod çipleri** `.66` yerine `.78` opaklıkta.
- **Quest rozeti yeniden tanımlandı.** "Ödül almaya hazır görev" sayılamıyor:
  görevler/başarımlar hedefe ulaşır ulaşmaz kendiliğinden tamamlanıp ödüyor,
  yani hazır durum tek kare sürmüyor ve eski `!` rozeti pratikte hiç
  görünmüyordu. Rozet artık "Quests ekranı en son açıldığından beri tamamlanan"
  sayısını gösteriyor (oturumluk). Rozet ayrıca tam yuvarlak oldu ve karonun
  köşesine oturdu.
- **Gem ile vardiya bitirme hatası.** "Finish now"un iki adımlı onayı butonun
  meta'sındaydı; popup her `state_changed`'de baştan kurulduğu için iki dokunuş
  arasında siliniyor ve vardiya hiç bitmiyordu. Durum artık üye değişkende
  (`_skip_shift_armed`). Motor tarafı temizdi — `tests/repro_skip_shift.tscn`
  bunu gösteriyor.
- **Kirli oda ekranı** artık doğrudan "Clean this room" butonu taşıyor.
- **Android: `stretch/aspect="expand"`.** Varsayılan `keep`, 19.5:9 telefonlarda
  alta/üste siyah bant koyuyor ve tam genişlik yerleşim fiziksel kenara
  ulaşmıyordu.

## Kapsam dışı

Mekanik ve ekonomi değişmiyor: vardiya süreleri, fiyatlar, SP eşikleri,
prestij koşulu aynı kalır. Prototipteki vardiya maliyeti ve gelir tahmini
örnek sayı — gerçek değer `Game.shift_cost()` / `Game.hourly_income()`.
