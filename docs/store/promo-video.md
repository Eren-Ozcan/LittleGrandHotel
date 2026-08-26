# Promo Video — YouTube Metadata

`scripts/make_promo_video.py` writes three cuts of the same 24.4 s footage, all
with sound, into `docs/store-assets-originals/`:

| File | Size | Used for |
| --- | --- | --- |
| `demo_landscape_tr.mp4` | 1920x1080, 27.4 s | **YouTube upload #1 → the `tr-TR` Play promo video field** |
| `demo_landscape_en.mp4` | 1920x1080, 27.4 s | **YouTube upload #2 → the `en-US` Play promo video field** |
| `demo.mp4` | 720x1280, 24.4 s | the vertical original, for social and for reference |

plus `youtube_thumb_tr.jpg` / `youtube_thumb_en.jpg`, the 1280x720 custom
thumbnails, and `demo.gif` for the README.

## Two uploads, not one

The pitch copy is burnt into the frame, so one upload cannot serve both locales.
Upload the two landscape files as **two separate YouTube videos** and give each
the title, description and tags for its language from the sections below. The
footage and the soundtrack are identical; only the left-hand copy differs.

Play only accepts the canonical watch form:
`https://www.youtube.com/watch?v=VIDEO_ID` — not `youtu.be/…`, not `/shorts/…`,
and not a URL carrying a `&list=` playlist parameter. Uploading the landscape cut
rather than the vertical one also keeps the video out of Shorts, which is where
that `/shorts/` URL would have come from.

## Settings that apply to both uploads

| Field | Value |
| --- | --- |
| Visibility | Public |
| Made for kids | **No** — "No, it's not made for kids" |
| Age restriction | None |
| Monetization | Off. A promo video the store listing points at must not open with an ad |
| Category | Gaming |
| Playlist | None. Adding one before copying the link puts `&list=` in the URL |
| Allow embedding | **On.** Play plays the promo video by embedding the YouTube player in the listing; with embedding off the field takes the URL and then shows nothing |
| Title and description language | Set it — it is a separate field from *Video language*, and Studio leaves it blank |
| Comments | Allowed, hold potentially inappropriate for review |
| License | Standard YouTube License |
| Altered content (AI disclosure) | No — the footage is captured from the running game |
| Recording date / location | Leave empty |

---

# Upload #1 — Turkish

**File:** `docs/store-assets-originals/demo_landscape_tr.mp4`
**Thumbnail:** `docs/store-assets-originals/youtube_thumb_tr.jpg`
**Video language:** Turkish · **Subtitle/caption certification:** not applicable

## Title (100 character limit)

```
Little Grand Hotel — Küçük otelini kur, dekore et, misafir ağırla
```

## Description (5000 character limit)

```
Little Grand Hotel, kendi küçük otelini sıfırdan yıldızlı bir zincire büyüttüğün sakin bir boşta (idle) otel yönetim oyunu. Boş bir arsayla başlıyorsun: oda satın alıyor, döşüyor, misafir ağırlıyor ve otelin seviye atladıkça yeni tesislerin kilidini açıyorsun.

▸ İNDİR: https://play.google.com/store/apps/details?id=com.littlegrandhotel.app

━━━━━━━━━━━━━━━━━━━━
OYUNDA NE VAR
━━━━━━━━━━━━━━━━━━━━

🏨 OTELİNİ SEN KUR
Boş bloklarla başla, yeni odalar satın al. Misafir odasından restorana, havuzdan spaya, sinemadan çatı bahçesine kadar tesis ekle. Odaları istediğin gibi yerleştir, taşı, gerekirse sat.

🛋️ DEKORE ET, YILDIZINI YÜKSELT
Her odayı mobilya ve dekorla döşe, Stil Puanı topla, otelini Sade'den İkonik'e taşı. Ne kadar şık dekore edersen otelinin yıldız puanı o kadar yükselir.

⏱️ VARDİYALARI YÖNET
1 saatlik hızlı turdan 24 saatlik uzun vardiyaya kadar seç, personel maliyetiyle kâr marjını dengele. Otomatik vardiya yenileme sayesinde oyunu kapattığında da otelin üretmeye devam eder.

🧹 TEMİZLİK VE İSTİLALAR
Kirli odaları zamanında temizle, yoksa istilaya dönüşürler. Kat Hizmetleri odası kurarak bu işi otomatiğe bağlayabilirsin.

🚶 YAŞAYAN BİR OTEL
Kapının önünde sıraya giren, resepsiyonda dolaşan, asansörle yukarı çıkan misafirler. Kaçan misafiri yakala, uyuyan misafiri dürt, bonus kazan.

🏆 GÖREVLER, BAŞARIMLAR, PRESTİJ
20 görevlik bir zincir, 13 kalıcı başarım ve 20. seviyede otelini devredip kalıcı bir gelir çarpanı kazandığın prestij sistemi.

🎁 GÜNLÜK ÖDÜLLER VE ÇEVRİMDIŞI KAZANÇ
Her gün giriş yap, artan ödülleri topla. Oyunu kapatıp geri döndüğünde çevrimdışı geçirdiğin sürenin kazancı da seni bekliyor olur.

☁️ ÇEVRİMDIŞI OYNANIR, BULUTA YEDEKLENİR
Oyunun kendisi bağlantı istemez, uçakta bile oynayabilirsin. İlerlemen cihazında saklanır ve arka planda buluta yedeklenir; bir Google hesabı bağlarsan otelini yeni bir telefonda kaldığın yerden devralırsın. Ayarlar'daki tek bir buton buluttaki kopyayı ve yerel kaydı birlikte siler.

🌍 TÜRKÇE VE İNGİLİZCE
Oyunun tamamı iki dilde oynanabiliyor, Ayarlar'dan istediğin an dili değiştirebilirsin.

━━━━━━━━━━━━━━━━━━━━

Bu videodaki her şey oyunun kendi motorundan alındı — sesler dâhil: efektlerin ve lobi müziğinin hepsi oyunun kendi prosedürel sesi.

Gizlilik politikası: https://yilkgames.com/privacy-policy/
Geliştirici: Yilk Games · Godot Engine ile yapıldı

#oteloyunu #idlegame #mobiloyun
```

## Tags (500 character budget for the whole list)

```
little grand hotel, otel oyunu, otel yönetimi, boşta oyun, idle game, idle tycoon, hotel tycoon, simülasyon oyunu, dekorasyon oyunu, otel kurma oyunu, mobil oyun, android oyun, türkçe oyun, godot, yilk games
```

---

# Upload #2 — English

**File:** `docs/store-assets-originals/demo_landscape_en.mp4`
**Thumbnail:** `docs/store-assets-originals/youtube_thumb_en.jpg`
**Video language:** English · **Subtitle/caption certification:** not applicable

## Title (100 character limit)

```
Little Grand Hotel — Build, decorate and run your own little hotel
```

## Description (5000 character limit)

```
Little Grand Hotel is a relaxing idle management game where you grow your own little hotel from scratch into a starred chain. You start with an empty plot: buy rooms, furnish them, welcome guests, and unlock new facilities as your hotel levels up.

▸ GET IT: https://play.google.com/store/apps/details?id=com.littlegrandhotel.app

━━━━━━━━━━━━━━━━━━━━
WHAT IS IN THE GAME
━━━━━━━━━━━━━━━━━━━━

🏨 BUILD THE HOTEL YOURSELF
Start with empty blocks and buy new rooms. Add facilities from guest rooms to a restaurant, from a pool to a spa, from a cinema to a rooftop garden. Place your rooms however you like, move them, and sell them if you need to.

🛋️ DECORATE, RAISE YOUR STARS
Furnish every room with furniture and decor, collect Style Score, and take your hotel from Basic to Iconic. The more stylishly you decorate, the higher your hotel's star rating climbs.

⏱️ MANAGE SHIFTS
Choose anything from a quick 1-hour round to a long 24-hour shift, and balance staff cost against profit margin. Thanks to automatic shift renewal, your hotel keeps producing even when you close the game.

🧹 CLEANING AND INFESTATIONS
Clean dirty rooms in time, or they turn into infestations. You can automate the job by building a Cleaning Room.

🚶 A LIVING HOTEL
Guests queue outside the door, wander around reception and ride the elevator up. Catch a runaway guest, poke a sleeping guest, earn a bonus.

🏆 QUESTS, ACHIEVEMENTS, PRESTIGE
A chain of 20 quests, 13 permanent achievements, and a prestige system where you hand over your hotel at level 20 to earn a permanent income multiplier.

🎁 DAILY REWARDS AND OFFLINE EARNINGS
Log in every day and collect increasing rewards. When you close the game and come back, the earnings for the time you spent offline are waiting for you too.

☁️ PLAYS OFFLINE, BACKED UP TO THE CLOUD
The game itself needs no connection — you can play it on a plane. Your progress is saved on your device and backed up to the cloud in the background; link a Google account and you can pick your hotel up on a new phone exactly where you left it. A single button in Settings deletes the cloud copy and the local save together.

🌍 ENGLISH AND TURKISH
The whole game is playable in both languages, and you can switch between them at any time from Settings.

━━━━━━━━━━━━━━━━━━━━

Everything in this video comes out of the game's own engine, sound included: every effect and the lobby music are the game's own procedural audio.

Privacy policy: https://yilkgames.com/privacy-policy/
Developer: Yilk Games · Made with Godot Engine

#idlegame #hotelgame #mobilegame
```

## Tags (500 character budget for the whole list)

```
little grand hotel, hotel game, hotel management, hotel tycoon, idle game, idle tycoon, idle hotel, management sim, simulation game, decoration game, tycoon game, mobile game, android game, godot, yilk games
```

---

## How the landscape cut is made

The game is a portrait phone game and cannot be re-rendered wide — the whole UI
and every camera beat in `tests/showcase.gd` is framed for 1080x1920. The
landscape cut therefore is not a re-render: it is the same frames placed at full
height on the right of a 1920x1080 canvas. The gameplay footage is identical to
the vertical cut, pixel for pixel.

The space that opens up on the left carries a designed panel, drawn frame by
frame by `scripts/promo_panel.py` and piped to ffmpeg as raw video:

- The **background** is the cover art's own wash — sky blue to cream to pink,
  sampled from `cover_master.png` — with out-of-focus gold coins that drift 40 px
  across the clip and five sparkles that breathe on their own periods.
- The **type** is the game's UI font (`assets/fonts/Figtree.ttf`) in the mascot's
  navy, over a gold rule: the title, then one feature line per sixth of the clip,
  cross-fading between lines.
- **Rosie**, the mascot, stands bottom left with a slow breathing bob and points
  at the screen. She swaps drawing to match the line — `pose_broom.png` on the
  cleaning beat, `pose_coins.png` on the one about earning, `pose_point.png`
  otherwise.
- The **footage** sits in rounded corners with a hairline and a soft drop shadow,
  so it reads as a phone screen rather than a hole cut in the background.
- An **end card** runs for the last 3 s: the phone slides off to the right, and
  the icon and the official Google Play badge fade up in the space it leaves,
  under a closing line. The soundtrack runs on through it and fades out.

The copy — title, the six feature lines and their poses, the closing line, the
footer — lives in the `COPY` table at the top of `scripts/make_promo_video.py`.
Edit it there, not in a video editor, and rebuild. The same table drives the
thumbnails.

The Play badges are Google's own artwork, downloaded per locale from
`play.google.com/intl/<locale>/badges/` into
`docs/store-assets-originals/badges/`. Google's brand guidelines say the badge
must not be recoloured, redrawn or distorted, so it is only ever scaled.

## After uploading

- [ ] Paste each `watch?v=` URL into its own listing: Play Console ▸ Main store
      listing ▸ Graphics ▸ Promo video. The `tr-TR` listing takes the Turkish
      upload, `en-US` takes the English one. Then **Save** and send for review.
- [ ] Do not leave `en-US` empty. A locale with no video of its own inherits the
      default listing's, which here would show Turkish copy to English readers.
- [x] Both videos uploaded on 27 Aug 2026, still **Private** — make them Public
      before Play can reach them. Studio hands out the `youtu.be` short form; the
      canonical URLs Play needs are:
      - `tr-TR: https://www.youtube.com/watch?v=tiwE3rWlYa0`
      - `en-US: https://www.youtube.com/watch?v=2HachmgCwIM`
- [ ] **Allow embedding** must stay on for both. Play plays the promo video by
      embedding the YouTube player in the listing; with embedding off, the field
      accepts the URL and then shows nothing.
- [ ] Set *Title and description language* on both (it is a separate field from
      *Video language*, and was left unset at upload).
