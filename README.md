# Little Grand Hotel

Mobil otel yönetimi ve dekorasyon oyunu (Godot 4.7, GDScript).
Tasarım dokümanı: GDD v1.1 — https://claude.ai/code/artifact/e65d0b6a-c8bd-4f01-ac1e-ea46c4a945cb
Yapılanlar ve yol haritası: [TODO.md](TODO.md)

## Durum: Tam sürüm — çekirdek + geç oyun + uzun vade içerikleri

Çekirdek döngü: oda → dekorasyon (Stil Puanı → kademe) → vardiya → gelir topla → yatırım.
Hotel City esintili kesit "dollhouse" görünüm: gökyüzü + silüet, duvar kağıtlı odalar,
SVG mobilya/misafir görselleri, görev zinciri (20 görev) ve çevrimdışı kazanç.

Cila sürümüyle gelenler: ikonlu koyu alt bar, temizlik parıltısı + süpürge animasyonu,
uçan coin animasyonu, misafir kapı yürüyüşü ve kıpırdanma animasyonları, prosedürel ses
efektleri + lobi müziği, elmas harcama (vardiya hızlandırma, premium eşya), oda taşıma/
satma, istatistik ekranı, ayarlar (ses/müzik, kayıt sıfırlama) ve geç oyun içerikleri
(Restoran, Çatı Bahçesi, seviye 28 denge testi).

Uzun vade eklentileri: 13 kalıcı başarım, prestij sistemi (seviye 20'de oteli devredip
kalıcı gelir çarpanı kazanma), sunucusuz haftalık dekorasyon teması, bulut kaydı yerine
paylaşılabilir kayıt kodu (dışa/içe aktarma) ve Android dışa aktarma (export preset +
imzalı debug APK). Kayıt formatı v5'e kadar adım adım göçle uyumlu.

## Çalıştırma

Godot 4.7 ikilisi `tools/` altında beklenir (repo'da yok):

```
tools\Godot_v4.7-stable_win64.exe --path .
```

## Testler (headless ekonomi doğrulaması)

```
tools\Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/sim_check.gd
```

## Android dışa aktarma

`export_presets.cfg` repoya dahildir (non-Gradle build, arm64-v8a, dikey 720×1280).
Yalnızca yerel makinede bir kereliğine kurulması gerekenler (repoya dahil değil):

1. Godot 4.7 export şablonları → `%APPDATA%\Godot\export_templates\4.7.stable\`
   (bkz. [Godot export şablonları indirme sayfası](https://godotengine.org/download))
2. Android SDK (platform-tools + build-tools 34.0.0 + platform 34), `ANDROID_HOME` ile
   veya Godot Editör Ayarları → Export → Android'den yolu göstererek
3. Debug keystore: `android/debug.keystore` (gitignore'da; `keytool` ile üretilir):
   ```
   keytool -genkeypair -v -keystore android/debug.keystore -storepass android ^
     -alias androiddebugkey -keypass android -keyalg RSA -keysize 2048 ^
     -validity 10000 -dname "CN=Android Debug,O=Android,C=US"
   ```

Kurulum tamamlandıktan sonra APK üretimi:

```
tools\Godot_v4.7-stable_win64_console.exe --headless --path . --export-debug "Android" build/android/little-grand-hotel.apk
```

## Yapı

- `data/economy.json` — tüm denge değerleri (GDD §5); kodda sabit sayı yok
- `data/quests.json` — görev zinciri (20 görev)
- `data/achievements.json` — 13 kalıcı başarım
- `src/autoload/game.gd` — simülasyon + kayıt (UI'dan bağımsız, headless test edilebilir)
- `src/main.gd` — Hotel City esintili dollhouse arayüz
- `src/sfx.gd` — prosedürel ses sentezi (dış ses dosyası gerekmez)
- `assets/` — SVG görseller (odalar, eşyalar, misafirler, UI ikonları)
- `tests/sim_check.gd` — ekonomi/kayıt birim testleri
- `export_presets.cfg` — Android dışa aktarma preset'i (bkz. yukarısı)
