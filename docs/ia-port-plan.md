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
`profile_account`, `profile_prestige`, `profile_stats`, `profile_settings`.
Ekran görüntüsünü prototipteki aynı ekranla yan yana koy.

Ek kontrol (bölünme kuralı için): `_build_profile_popup` altında
`IAP.purchase` çağrısı kalmamalı — grep ile doğrula.

Yığın doğrulaması geçti: Build → dekor paketi → oda seçimi → ‹ geri
(stack 1 → 2 → 1, geri butonu yalnızca 2'de görünüyor, kökte pop popup'ı
kapatıyor).

## Kapsam dışı

Mekanik ve ekonomi değişmiyor: vardiya süreleri, fiyatlar, SP eşikleri,
prestij koşulu aynı kalır. Prototipteki vardiya maliyeti ve gelir tahmini
örnek sayı — gerçek değer `Game.shift_cost()` / `Game.hourly_income()`.
