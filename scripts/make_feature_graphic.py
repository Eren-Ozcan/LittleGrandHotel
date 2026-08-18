"""Build the 1024x500 Play feature graphic from the cover art.

The title is drawn here rather than by the image model, which garbles letters, and
it sits in the empty sky on the right with the safe margin Play may crop kept clear.

    python scripts/make_feature_graphic.py
"""

from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ASSETS = Path(__file__).resolve().parent.parent / "docs" / "store-assets-originals"
TITLE = ["Little Grand", "Hotel"]
SUB = "Decorate · Host · Grow"


def main() -> None:
    im = Image.open(ASSETS / "cover_master.png").convert("RGB")
    W, H = im.size
    ratio = 1024 / 500
    crop_h = min(H, int(W / ratio))
    crop_w = int(crop_h * ratio)
    top = (H - crop_h) // 2
    fg = im.crop((0, top, crop_w, top + crop_h)).resize((1024, 500), Image.LANCZOS)

    draw = ImageDraw.Draw(fg)
    box_left, box_right = 660, 1024 - 45
    max_w = box_right - box_left
    size = 20
    while size < 120:
        probe = ImageFont.truetype(r"C:\Windows\Fonts\comicz.ttf", size + 1)
        if max(draw.textlength(l, font=probe) for l in TITLE) > max_w:
            break
        size += 1
    font = ImageFont.truetype(r"C:\Windows\Fonts\comicz.ttf", size)
    sub_font = ImageFont.truetype(r"C:\Windows\Fonts\seguisb.ttf", 22)
    cx = (box_left + box_right) / 2
    line_h = size * 1.05
    ty = (500 - (line_h * len(TITLE) + 34)) / 2

    glow = Image.new("RGBA", fg.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    for i, line in enumerate(TITLE):
        w = draw.textlength(line, font=font)
        gd.text((cx - w / 2, ty + i * line_h), line, font=font, fill=(255, 236, 190, 210))
    fg = Image.alpha_composite(fg.convert("RGBA"), glow.filter(ImageFilter.GaussianBlur(12))).convert("RGB")

    draw = ImageDraw.Draw(fg)
    for i, line in enumerate(TITLE):
        w = draw.textlength(line, font=font)
        draw.text((cx - w / 2, ty + i * line_h), line, font=font,
                  fill=(255, 252, 242), stroke_width=6, stroke_fill=(120, 72, 38))
    sw = draw.textlength(SUB, font=sub_font)
    draw.text((cx - sw / 2, ty + line_h * len(TITLE) + 8), SUB, font=sub_font,
              fill=(92, 58, 28), stroke_width=4, stroke_fill=(255, 246, 226))

    out = ASSETS / "feature_graphic_1024x500_v2.png"
    fg.save(out)
    print("wrote", out)


if __name__ == "__main__":
    main()
