"""Repair the two garbled words in the generated cover art.

The image model wrote "HOTBY" on the lobby sign and a different name on the
receptionist's badge than the one the character cut-outs use. Both are repainted
here rather than by hand, so the fix can be re-applied if the cover is regenerated.

    python scripts/fix_cover_text.py <source.jpg>
"""

import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter

OUT = Path(__file__).resolve().parent.parent / "docs" / "store-assets-originals" / "cover_master.png"
FONT = r"C:\Windows\Fonts\seguibl.ttf"


def repaint(im, box, blur):
    """Erase a word by stretching the pixels on either side of it across the box."""
    px = im.load()
    x0, y0, x1, y1 = box
    for y in range(y0, y1):
        left, right = px[x0 - 5, y], px[x1 + 4, y]
        span = max(1, x1 - x0 - 1)
        for i, x in enumerate(range(x0, x1)):
            t = i / span
            px[x, y] = tuple(int(left[c] + (right[c] - left[c]) * t) for c in range(3))
    pad = 5
    reg = im.crop((x0 - pad, y0 - pad, x1 + pad, y1 + pad)).filter(ImageFilter.GaussianBlur(blur))
    im.paste(reg, (x0 - pad, y0 - pad))


def fit_font(draw, text, max_w, ceiling):
    size = 6
    while size < ceiling:
        probe = ImageFont.truetype(FONT, size + 1)
        if draw.textlength(text, font=probe) > max_w:
            break
        size += 1
    return ImageFont.truetype(FONT, size)


def centred(draw, text, font, box, dy=0):
    x0, y0, x1, y1 = box
    w = draw.textlength(text, font=font)
    asc, desc = font.getmetrics()
    return x0 + (x1 - x0 - w) / 2, y0 + ((y1 - y0) - (asc + desc)) / 2 + dy


def main(src):
    im = Image.open(src).convert("RGB")

    # 1. Lobby sign: "HOTBY" -> "HOTEL", lit cream letters.
    sign = (1096, 1134, 1230, 1180)
    repaint(im, sign, 2.2)
    draw = ImageDraw.Draw(im)
    font = fit_font(draw, "HOTEL", (sign[2] - sign[0]) - 14, 200)
    x, y = centred(draw, "HOTEL", font, sign, dy=2)
    glow = Image.new("RGBA", im.size, (0, 0, 0, 0))
    ImageDraw.Draw(glow).text((x, y), "HOTEL", font=font, fill=(255, 226, 150, 170))
    im = Image.alpha_composite(im.convert("RGBA"), glow.filter(ImageFilter.GaussianBlur(6))).convert("RGB")
    ImageDraw.Draw(im).text((x, y), "HOTEL", font=font, fill=(255, 245, 208),
                            stroke_width=2, stroke_fill=(190, 140, 88))

    # 2. Name badge: match the cut-outs, which say ROSIE. The star to the left of the
    #    text stays, so the box starts after it and the letters are kept small.
    badge = (636, 1252, 710, 1279)
    repaint(im, badge, 1.0)
    draw = ImageDraw.Draw(im)
    font = fit_font(draw, "ROSIE", (badge[2] - badge[0]) - 8, 40)
    x, y = centred(draw, "ROSIE", font, badge, dy=0)
    draw.text((x, y), "ROSIE", font=font, fill=(86, 54, 32))

    im.save(OUT)
    print("wrote", OUT)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else r"C:\Users\ereno\Downloads\Receptionist_waving_in_hotel_game_202608181420.jpeg")
