# Little Grand Hotel

Mobil otel yönetimi ve dekorasyon oyunu (Godot 4.7, GDScript).
Tasarım dokümanı: GDD v1.1 — https://claude.ai/code/artifact/e65d0b6a-c8bd-4f01-ac1e-ea46c4a945cb
Yapılanlar ve yol haritası: [TODO.md](TODO.md)

## Durum: Cila sürümü — tam çekirdek + geç oyun

Çekirdek döngü: oda → dekorasyon (Stil Puanı → kademe) → vardiya → gelir topla → yatırım.
Hotel City esintili kesit "dollhouse" görünüm: gökyüzü + silüet, duvar kağıtlı odalar,
SVG mobilya/misafir görselleri, görev zinciri (20 görev) ve çevrimdışı kazanç.

Cila sürümüyle gelenler: ikonlu koyu alt bar, temizlik parıltısı ve uçan coin
animasyonları, misafir animasyonları, prosedürel ses efektleri + lobi müziği,
elmas harcama (vardiya hızlandırma, premium eşya), oda taşıma/satma, istatistik
ekranı, ayarlar (ses/müzik, kayıt sıfırlama), kayıt sürüm göçü (v2→v3) ve geç
oyun içerikleri (Restoran, Çatı Bahçesi, seviye 28 denge testi).

## Çalıştırma

Godot 4.7 ikilisi `tools/` altında beklenir (repo'da yok):

```
tools\Godot_v4.7-stable_win64.exe --path .
```

## Testler (headless ekonomi doğrulaması)

```
tools\Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/sim_check.gd
```

## Yapı

- `data/economy.json` — tüm denge değerleri (GDD §5); kodda sabit sayı yok
- `data/quests.json` — görev zinciri (20 görev)
- `src/autoload/game.gd` — simülasyon + kayıt (UI'dan bağımsız, headless test edilebilir)
- `src/main.gd` — Hotel City esintili dollhouse arayüz
- `src/sfx.gd` — prosedürel ses sentezi (dış ses dosyası gerekmez)
- `assets/` — SVG görseller (odalar, eşyalar, misafirler, UI ikonları)
- `tests/sim_check.gd` — ekonomi/kayıt birim testleri
