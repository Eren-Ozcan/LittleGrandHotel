"""Compose Play Store screenshots: gameplay on top, a caption band at the bottom.

Every hotel game on the store does this — a coloured band with a short ALL-CAPS
promise and a character cut-out, never a bare screenshot. This script builds ours
from the renders produced by `tests/showcase.tscn` plus the receptionist cut-outs,
so the whole set can be rebuilt (or re-worded, or localised) with one command:

    python scripts/make_store_shots.py            # en-US, from */.png
    python scripts/make_store_shots.py tr         # tr-TR, from tr/*.png

The localised run reads the renders produced by `showcase.tscn -- shots lang=tr`
from docs/store-assets-originals/tr/ and writes to docs/store-assets-originals/
play-tr/. Anything the localised render does not provide (the hand-painted
before/after art) falls back to the shared file in the parent folder.

Inputs and outputs both live in docs/store-assets-originals/, which is gitignored;
the finished files are copied into the private pictures repo by hand.
"""

import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ASSETS = Path(__file__).resolve().parent.parent / "docs" / "store-assets-originals"

W, H = 1080, 1920
BAND_H = 330
PLUM = (58, 44, 77)
GOLD = (246, 184, 60)
CREAM = (253, 246, 227)

TITLE_FONT = r"C:\Windows\Fonts\seguibl.ttf"

# (source image, English caption, Turkish caption, character cut-out or None,
# keep-top fraction). Menu screens are cropped to their top portion: the popups
# are short, so the full 1080x1920 frame would be mostly empty cream.
#
# The Turkish captions are written already upper-cased by hand — Python's
# str.upper() is locale-independent and turns "i" into "I", which is wrong in
# Turkish (the same trap the game hit in `_to_upper()`).
SHOTS = [
    ("01_hotel.png", "BUILD YOUR GRAND HOTEL", "BÜYÜK OTELİNİ KUR", "pose_point.png", 1.0),
    ("03_room.png", "DECORATE EVERY ROOM", "HER ODAYI DÖŞE", None, 0.62),
    ("before_after_art.jpg", "TURN EMPTY ROOMS INTO SUITES", "BOŞ ODALARI SÜİTE ÇEVİR", None, 1.0),
    ("02_full_building.png", "POOL, CINEMA, SPA & MORE", "HAVUZ, SİNEMA, SPA VE DAHASI", "pose_point.png", 1.0),
    ("08_offline.png", "EARN WHILE YOU'RE AWAY", "SEN YOKKEN DE KAZAN", "pose_coins.png", 1.0),
    ("05_quests.png", "20 QUESTS TO CHASE", "PEŞİNDEN KOŞULACAK 20 GÖREV", None, 0.45),
    ("04_build.png", "BUILD, UNLOCK, EXPAND", "İNŞA ET, AÇ, BÜYÜT", "pose_broom.png", 0.62),
    ("06_stats.png", "GROW INTO AN EMPIRE", "BİR İMPARATORLUĞA DÖNÜŞTÜR", "pose_coins.png", 0.45),
]


def fit(img: Image.Image, w: int, h: int) -> Image.Image:
    """Scale to the target width and keep the top, padding if it comes up short.

    Cover-cropping was wrong for the menu screens: cropping their empty lower half
    made them wider than 9:16, and the cover crop then ate the left and right edges
    of the very panel the screenshot is about. Width is what must never be cut.
    """
    scale = w / img.width
    img = img.resize((w, round(img.height * scale)), Image.LANCZOS)
    if img.height >= h:
        return img.crop((0, 0, w, h))
    pad = Image.new("RGB", (w, h), img.getpixel((w // 2, img.height - 1)))
    pad.paste(img, (0, 0))
    return pad


def wrap(draw, text, font, max_w):
    words, lines, cur = text.split(), [], ""
    for word in words:
        probe = (cur + " " + word).strip()
        if draw.textlength(probe, font=font) <= max_w or not cur:
            cur = probe
        else:
            lines.append(cur)
            cur = word
    if cur:
        lines.append(cur)
    return lines


def source_path(source: str, lang: str) -> Path:
    """Prefer the localised render; fall back to the shared file for hand art."""
    if lang != "en":
        localised = ASSETS / lang / source
        if localised.exists():
            return localised
    return ASSETS / source


def build(source: str, caption: str, slug: str, pose: str | None, keep_top: float,
          index: int, lang: str) -> Path:
    raw = Image.open(source_path(source, lang)).convert("RGB")
    if keep_top < 1.0:
        raw = raw.crop((0, 0, raw.width, round(raw.height * keep_top)))
    shot = fit(raw, W, H - BAND_H)
    canvas = Image.new("RGB", (W, H), PLUM)
    canvas.paste(shot, (0, 0))
    draw = ImageDraw.Draw(canvas)
    draw.rectangle([0, H - BAND_H, W, H - BAND_H + 7], fill=GOLD)

    text_left = 40
    if pose:
        cut = Image.open(ASSETS / pose).convert("RGBA")
        target_h = BAND_H + 90          # the character overhangs the band on purpose
        cut = cut.resize((round(cut.width * target_h / cut.height), target_h), Image.LANCZOS)
        canvas.paste(cut, (25, H - target_h), cut)
        text_left = 25 + cut.width + 24

    max_w = W - text_left - 40
    size = 92
    while size > 30:
        font = ImageFont.truetype(TITLE_FONT, size)
        lines = wrap(draw, caption, font, max_w)
        if len(lines) <= 2:
            break
        size -= 4
    line_h = size * 1.12
    total = line_h * len(lines)
    y = H - BAND_H + (BAND_H - total) / 2 - 6
    for line in lines:
        draw.text((text_left, y), line, font=font, fill=CREAM)
        y += line_h

    out = ASSETS / ("play" if lang == "en" else f"play-{lang}")
    out.mkdir(parents=True, exist_ok=True)
    path = out / f"{index:02d}_{slug}.png"
    canvas.save(path)
    return path


def main() -> None:
    lang = sys.argv[1] if len(sys.argv) > 1 else "en"
    for i, (source, en, tr, pose, keep_top) in enumerate(SHOTS, start=1):
        # The file name always comes from the English caption, so the two sets
        # line up row by row when they are uploaded side by side.
        slug = en.lower().replace(" ", "_").replace(",", "").replace("'", "")[:28]
        caption = en if lang == "en" else tr
        print("wrote", build(source, caption, slug, pose, keep_top, i, lang).name)


if __name__ == "__main__":
    main()
