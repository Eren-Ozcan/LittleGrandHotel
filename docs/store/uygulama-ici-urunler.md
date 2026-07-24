# Play Console — Uygulama İçi Ürünler Kurulumu

Play Console → uygulaman → "Para kazanma" → "Uygulama içi ürünler" →
"Yönetilen ürün oluştur" ile aşağıdaki iki ürünü **birebir bu Ürün ID'leriyle**
oluştur. ID'ler kodda (`src/autoload/iap.gd`) sabit, eşleşmezse satın alma
çalışmaz.

## 1. Reklamları Kaldır

| Alan | Değer |
|---|---|
| Ürün ID (**değiştirme**) | `remove_ads` |
| Ad (başlık) | Reklamları Kaldır |
| Açıklama | Tüm ödüllü reklamları kalıcı olarak kaldırır. |
| Tür | Yönetilen ürün (non-consumable / kalıcı) |
| Önerilen fiyat | ₺49,99 (öneri — dilediğin gibi ayarla) |
| Durum | Etkin |

## 2. Kazancı 2x Yap

| Alan | Değer |
|---|---|
| Ürün ID (**değiştirme**) | `income_2x` |
| Ad (başlık) | Kazancı 2x Yap |
| Açıklama | Otelinin tüm gelirini kalıcı olarak 2 katına çıkarır. |
| Tür | Yönetilen ürün (non-consumable / kalıcı) |
| Önerilen fiyat | ₺99,99 (öneri — dilediğin gibi ayarla) |
| Durum | Etkin |

## Notlar

- İkisi de kalıcı/tek seferlik satın alma — "abonelik" değil, "Yönetilen
  ürün" (managed product / one-time) olarak oluşturulmalı.
- Ürünleri oluşturduktan sonra **"Etkin" durumuna almayı unutma** —
  varsayılan taslak durumda satın alınamaz.
- Test etmek için Play Console → "Test kullanıcıları" (license testers)
  altına kendi Google hesabını eklemen gerekir; aksi halde gerçek para
  çekilir.
- Kod tarafında değişiklik gerekmiyor — `iap.gd` zaten bu iki ID'yi
  kullanıyor (`PRODUCT_REMOVE_ADS = "remove_ads"`,
  `PRODUCT_INCOME_2X = "income_2x"`).
