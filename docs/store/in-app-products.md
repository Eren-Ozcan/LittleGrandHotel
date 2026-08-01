# Play Console — In-App Products Setup

Go to Play Console → your app → "Monetize" → "In-app products" → "Create managed
product" and create the following two products **with exactly these Product IDs**.
The IDs are hardcoded in the code (`src/autoload/iap.gd`); if they don't match,
purchases won't work.

## 1. Remove Ads

| Field | Value |
|---|---|
| Product ID (**do not change**) | `remove_ads` |
| Name (title) | Remove Ads |
| Description | Permanently removes all rewarded ads. |
| Type | Managed product (non-consumable / permanent) |
| Suggested price | ₺49.99 (suggestion — set it however you like) |
| Status | Active |

## 2. Double Your Income

| Field | Value |
|---|---|
| Product ID (**do not change**) | `income_2x` |
| Name (title) | Double Your Income |
| Description | Permanently doubles all income from your hotel. |
| Type | Managed product (non-consumable / permanent) |
| Suggested price | ₺99.99 (suggestion — set it however you like) |
| Status | Active |

## 3. Gem Packs (consumable)

These are not **Managed products** in the sense of being one-off; because they need
to be purchasable again and again, `consumePurchase` is called on the code side — on
the Play Console side they are still created as "Managed products" (Play Billing has
no separate "consumable" product type, consumption is done by the app via
`consumePurchase` — the code already does this).

| Product ID (**do not change**) | Name | Gems | Suggested price |
|---|---|---|---|
| `gems_small`  | Small Gem Pack  | 100  | ₺19.99  |
| `gems_medium` | Medium Gem Pack | 350  | ₺49.99  |
| `gems_large`  | Large Gem Pack  | 1200 | ₺149.99 |

All of them must be "Status: Active". If the amounts/prices change, also update the
`GEM_PACKS` constant in `src/main.gd`.

## Notes

- Both are permanent/one-time purchases — they must be created as a "Managed
  product" (one-time), not a "subscription".
- After creating the products, **don't forget to set them to "Active"** — in the
  default draft state they cannot be purchased.
- To test, you need to add your own Google account under Play Console → "License
  testers"; otherwise real money will be charged.
- No changes are needed on the code side — `iap.gd` already uses these two IDs
  (`PRODUCT_REMOVE_ADS = "remove_ads"`,
  `PRODUCT_INCOME_2X = "income_2x"`).
