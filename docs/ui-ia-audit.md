# UI / Bilgi Mimarisi Denetimi

Tarih: 2026-08-14. Kaynak: `src/main.gd` okuması + `tests/shot.gd` ile
720x1280 çekilen 6 gerçek ekran görüntüsü (main, settings, gems, profile,
quests, shift).

Hotel City karşılaştırması sınırlı: Gamezebo walkthrough sayfası doğrudan
çekilemedi (`read ECONNRESET`, iki deneme), o taraf arama özeti + tür bilgisi
üzerinden. Diğer her madde kodla veya ekran görüntüsüyle doğrulandı.

## Mevcut IA ağacı

```
Üst bar (panele her yerden tap -> Profile)     main.gd:975
  └ gem "+"  -> Buy Gems                       main.gd:995
Alt bar (5 ikon)                               main.gd:1161-1191
  ├ Shift    -> Shift popup + Auto-renew mağazası
  ├ Shop     -> popup YOK, Build Mode'u açar
  ├ Staff    -> Staff popup
  ├ Quests   -> Quests + Achievements
  └ Settings -> Settings popup
Odaya tap -> Room Decoration / Facility        main.gd:2471-2473
Modal (yığın dışı): Cloud conflict, Daily reward, Offline
```

### İçerik dağılımı

| Ekran | İçindekiler | Satır |
|---|---|---|
| Profile | Account/bulut + kayıt kodu dışa/içe aktar + Premium (Remove Ads, 2x) + Prestige + Statistics | 3381 |
| Settings | Ses, Müzik, Kaydı sıfırla | 3689 |
| Buy Gems | 3 elmas paketi | 3665 |
| Shift | Vardiya seç/atla + reklam boost + Auto-renew satışı | 3069 |
| Room Decoration | Bundle + taban eşya yükseltme + dekor satın alma + Taşı/Sat | 3181 |

## Boşluk analizi

### Kritik — mağaza politikası riski

AAB Play Console'da incelemede olduğu için bunlar acil.

1. **`IAP.restore_purchases()` hiçbir yerden çağrılmıyor.** `iap.gd:133`'te
   tanımlı, tüm repoda tek çağıran yok. Remove Ads ve 2x income tüketilmeyen
   ürün; Play politikası geri yükleme yolu istiyor. Oyuncu cihaz değiştirince
   parasını verdiği şeyi kaybediyor.
2. **Gizlilik politikası linki yok** — UI'da hiçbir yerde yok.
3. **Hesap silme / veri silme yolu yok.** "Reset save" yerel kaydı siler,
   bulut dokümanını silmez.
4. **Reklam onayı (UMP/GDPR) yeniden açma yolu yok.** Onay bir kez alınıp bir
   daha değiştirilemiyor.
5. **Sürüm numarası yalnızca açılış ekranında** (`main.gd:1323`, "v1.0").
   Destek için Ayarlar'da olmalı.

### Tür konvansiyonu boşlukları

6. **"Shop" mağaza açmıyor**, Build Mode toggle'ı. Oyuncu para harcayacağı
   yeri arıyor, oda inşa moduna düşüyor. Türde Shop = tek satın alma merkezi.
7. **Premium ürünler (Remove Ads, 2x) Profile'ın içine gömülü** — üçüncü
   seviye derinlik, kayıt kodu ile prestij arasında. Gelir açısından en kötü
   konum.
8. **Profile beş alakasız şeyi taşıyor**: hesap + kayıt taşıma + premium +
   prestij + istatistik. Tek scroll, sekme yok.
9. **Profile'a giriş keşfedilemez** — üst bara tap. Görsel ipucu yok, alt
   barda ikonu yok.
10. **Settings neredeyse boş** (ekran görüntüsünde popup'ın yarısı beyaz).
    Dil, bildirim, titreşim, destek/iletişim yok.

### Ekran görüntülerinden görsel bulgular

11. **Staff ve Settings aynı ikonu kullanıyor** — ikisi de `icon_gear.svg`
    (`main.gd:1180` ve `1182`). Alt barda iki özdeş dişli yan yana.
12. **Settings'te geliştirici notu oyuncuya görünüyor**: "Auto-renew moved to
    Shift; Premium/Prestige and save transfer moved to Profile."
    (`main.gd:3709`). Bu bir changelog, oyuncu için anlamsız.
13. **Profile'da ham base64 kayıt kodu** bir `LineEdit` içinde açıkta duruyor
    — ürkütücü ve çirkin.
14. **Ekranın yaklaşık %35'i boş gökyüzü.** Bina alta yapışık, üstte ~450px
    kullanılmayan alan.
15. Toast alt barın üstüne biniyor; "empty room" metni oda görselinin üstüne
    taşmış.

## Yardımcı skill ile çapraz kontrol

Kaynak: `gamedev-skills/awesome-gamedev-agent-skills` reposundaki
`skills/disciplines/game-ui-ux/` (SKILL.md + references/layout-and-flow.md).
Aynı repoda `skills/godot/godot-ui-control/` de var, bu projenin katmanına
doğrudan oturuyor.

| Skill kuralı | LGH durumu |
|---|---|
| Safe-area: OS'un bildirdiği rect'i sorgula, çentik/yuvarlak köşe için içeri al | **İhlal.** Sabit 14px margin (`main.gd:958-961`). `get_display_safe_area` repoda hiç geçmiyor. Çentikli telefonda üst bar kesilir. |
| Menüleri push/pop yığını olarak modelle, bayrak çorbası değil | **Kısmen ihlal.** Tek paylaşılan `overlay` + tek `popup_builder` (`main.gd:3023`). Yığın yok, bu yüzden Profile'dan alt ekrana inip geri dönmek imkânsız — 8. bulgunun kök nedeni. |
| Geri tuşu yığını pop'lar | **Tutuyor.** `NOTIFICATION_WM_GO_BACK_REQUEST` popup'ı kapatıyor (`main.gd:336`). Tek katman olduğu için şimdilik yeterli. |
| Font boyutunu referans yüksekliğin yüzdesi olarak ver, sabit verme | **İhlal.** Her yerde sabit px: `_label(..., 21, ...)`, `_button(..., 15, ...)`. |
| Mutlak piksel konumu kullanma, container'lar aksın | **Büyük ölçüde tutuyor** (VBox/HBox/ScrollContainer). Ama popup paneli `custom_minimum_size = Vector2(620, 0)` (`main.gd:1212`) — 720px viewport'ta kenarlara 50px kalıyor, dar cihazda sıkışır. |
| Metinleri dışarı al, container içerik boyuna göre büyüsün | **İhlal.** Tüm metinler kodda gömülü İngilizce. `locale/translations` yalnızca AdMob örneğini içeriyor. |
| HUD sinyale abone olsun, `_process`'te state yoklamasın | **Tutuyor.** `state_changed` -> `_rebuild_popup`. |
| Dokunma hedefi ~9mm, küçük butonlara padding | **İhlal.** Gem "+" butonu 32x32px (`main.gd:994`). 720px genişlikte bu ~4mm. Zoom butonları 52x48 ile sınırda geçiyor. |

Skill'in katkısı: safe-area, ekran yığını ve font ölçekleme maddeleri.
Uygulanamayan kısmı: gamepad/focus bölümünün tamamı (dokunmatik-yalnız oyun).
Tür-özel IA konusunda (ne Ayarlar'da ne Mağaza'da durur) skill hiçbir şey
söylemiyor; orayı yalnızca yukarıdaki analiz kapatıyor.

## Claude Design (DesignSync) uygunluğu

Doğrudan kullanılamaz. `DesignSync` aracı claude.ai/design'daki HTML tabanlı
design system projelerini okuyup yazıyor; bileşen önizlemeleri HTML dosyası
olarak tutuluyor. Bu projenin UI'ı GDScript'te `StyleBoxFlat` + `Control`
node'u, aradaki dönüşüm otomatik değil.

Dolaylı kullanım (HTML maket üzerinde iterasyon, sonra GDScript'e port)
mümkün ama bu projede gereksiz ara katman: `tests/shot.gd` gerçek oyundan
saniyeler içinde ekran görüntüsü üretiyor.

## Sıradaki iş — tur 1: görsel/yerleşim

Yeni bir oturuma yapıştırılacak prompt:

```
LittleGrandHotel'in UI'ını görsel olarak iyileştir. Tüm UI src/main.gd
içinde kodla kuruluyor (.tscn editör layout'u yok); PALETTE sabiti, _label /
_button / _panel / _card_sb / _bar_button yardımcılarını kullan, yeni bir UI
kurma yöntemi icat etme.

Her değişiklikten sonra görsel doğrula:
  tools\Godot_v4.7-stable_win64_console.exe --path . res://tests/shot.tscn ^
    --resolution 720x1280 -- demo popup=<ad> out=<dosya>.png
popup= değerleri: shift, settings, staff, quests, stats, profile, gems.
Görüntü %APPDATA%\Godot\app_userdata\Little Grand Hotel\ altına yazılır.
Ekran görüntüsüne bak, beğenmediysen düzelt, tekrar çek.

Sırayla yap, her adımdan sonra ekran görüntüsüyle doğrula:

1. Alt bardaki Staff ve Settings ikonları aynı (ikisi de icon_gear.svg,
   main.gd:1180 ve 1182). Staff için ayrı bir ikon üret veya mevcut
   assets/ui/ altından uygun olanı kullan — önce klasörün içeriğine bak.

2. Settings popup'ındaki "Auto-renew moved to Shift; Premium/Prestige and
   save transfer moved to Profile." satırını sil (main.gd:3709). Bu bir
   geliştirici notu, oyuncuya gösterilmemeli.

3. Sabit piksel font boyutlarını referans yüksekliğe (1280) oranlı bir
   yardımcıya çevir; küçük ekranda metin taşmasın. Popup panelinin
   custom_minimum_size'ındaki sabit 620 genişliği (main.gd:1212) viewport
   genişliğinin oranına çevir.

4. Safe area uygula: main.gd:958-961'deki sabit 14px margin yerine
   DisplayServer.get_display_safe_area() ile hesaplanan inset kullan ve
   çözünürlük/yön değişiminde yeniden hesapla.

5. Gem "+" butonu 32x32px (main.gd:993-994) — dokunma hedefi için çok
   küçük. En az 48x48'e çıkar.

6. Profile popup'ındaki ham base64 kayıt kodunu açıkta gösterme: varsayılan
   olarak gizle, "Show code" ile aç.

7. Ana ekranda binanın üstünde kalan büyük boş gökyüzü alanını değerlendir:
   ya bina dikeyde ortalansın ya da boşluk anlamlı bir öğeyle dolsun.
   Kararını ekran görüntüsüne bakarak ver.

Oyun mekaniğini, ekonomiyi veya hangi içeriğin hangi popup'ta durduğunu
DEĞİŞTİRME — bu tur yalnızca görsel/yerleşim düzeltmesi. IA yeniden
düzenlemesi ayrı bir tur olacak.
```

## Sıradaki iş — tur 2: mağaza uyumluluğu

Yukarıdaki 1-5 numaralı kritik maddeler. Görsel iş değil, ayrı ele alınacak.

## Sıradaki iş — tur 3: IA yeniden düzenlemesi

6-10 numaralı maddeler. Popup yığını (push/pop) olmadan Profile'ı bölmek zor,
o yüzden bu tur muhtemelen `_open_popup` mimarisine dokunacak.
