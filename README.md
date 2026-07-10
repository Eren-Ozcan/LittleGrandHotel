# Little Grand Hotel

Mobil otel yönetimi ve dekorasyon oyunu (Godot 4.7, GDScript).
Tasarım dokümanı: GDD v1.1 — https://claude.ai/code/artifact/e65d0b6a-c8bd-4f01-ac1e-ea46c4a945cb

## Durum: Faz 0 — Gri kutu prototip

Çekirdek döngü: oda → dekorasyon (Stil Puanı → kademe) → vardiya → gelir topla → yatırım.

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
- `src/autoload/game.gd` — simülasyon + kayıt (UI'dan bağımsız, headless test edilebilir)
- `src/main.gd` — gri kutu arayüz
- `tests/sim_check.gd` — ekonomi/kayıt birim testleri
