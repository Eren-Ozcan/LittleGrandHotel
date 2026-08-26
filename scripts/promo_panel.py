"""The 16:9 promo cut: the portrait game on the right, the pitch on the left.

The game is a portrait phone game and its UI cannot be re-rendered wide, so the
landscape promo is not a re-render. The captured 1080x1920 frames are placed at
full canvas height on the right of a 1920x1080 canvas, and the space that opens
up on the left carries a designed panel: the cover art's own sky-to-cream-to-pink
wash, out-of-focus gold coins, sparkles, the mascot pointing at the screen, and
one feature line that changes through the clip.

Every frame of the panel is drawn here with Pillow and piped to ffmpeg as raw
video, which is far easier to reason about than the equivalent filter graph.
"""

import math
import random
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

REPO = Path(__file__).resolve().parent.parent
ASSETS = REPO / "docs" / "store-assets-originals"
FONT_PATH = REPO / "assets" / "fonts" / "Figtree.ttf"

W, H = 1920, 1080
FOOT_W = 608                      # 1080x1920 at full canvas height, rounded even
FOOT_X = W - FOOT_W - 96
CORNER = 34
TEXT_X = 110

# The cover art's palette, sampled from cover_master.png.
SKY = (158, 211, 242)
CREAM = (255, 252, 236)
PINK = (252, 201, 210)
GOLD = (240, 186, 74)
NAVY = (38, 50, 84)                # the mascot's uniform; the type colour
SLATE = (58, 72, 110)

FADE = 0.4                         # cross-fade at both ends of a feature line
ENDCARD = 3.0                      # seconds of end card after the footage
SLIDE = 0.7                        # seconds the phone takes to leave


def _ease_out(t: float) -> float:
    return 1.0 - (1.0 - t) ** 3


def _ramp(t: float, start: float, end: float) -> float:
    """0 before `start`, 1 after `end`, eased in between."""
    if t <= start:
        return 0.0
    if t >= end:
        return 1.0
    return _ease_out((t - start) / (end - start))


def _gradient() -> Image.Image:
    """The wash, built small and scaled up - a gradient survives interpolation."""
    sw, sh = 192, 108
    small = Image.new("RGB", (sw, sh))
    px = small.load()
    for y in range(sh):
        for x in range(sw):
            t = x / sw * 0.45 + y / sh * 0.55
            if t < 0.55:
                k = t / 0.55
                px[x, y] = tuple(round(SKY[i] + (CREAM[i] - SKY[i]) * k) for i in range(3))
            else:
                k = (t - 0.55) / 0.45
                px[x, y] = tuple(round(CREAM[i] + (PINK[i] - CREAM[i]) * k) for i in range(3))
    return small.resize((W, H), Image.BICUBIC)


def _bokeh() -> Image.Image:
    """Out-of-focus coins, drawn oversized so the layer can drift under the crop.

    They cover the whole canvas, not just the panel: the phone hides them while it
    is on screen, and once it slides away for the end card they carry that side too.
    """
    pad = 160
    layer = Image.new("RGBA", (W + pad, H + pad), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    rng = random.Random(7)
    for _ in range(26):
        x = rng.randint(40, W + pad - 40)
        y = rng.randint(40, H + pad - 40)
        r = rng.randint(18, 54)
        draw.ellipse([x - r, y - r, x + r, y + r], fill=(*GOLD, rng.randint(26, 68)))
    return layer.filter(ImageFilter.GaussianBlur(9))


# Where the sparkles sit, how big they are, and how fast each one breathes.
SPARKLES = [(880, 200, 26, 3.1, 0.0), (980, 300, 15, 2.3, 0.4),
            (150, 220, 18, 2.7, 0.7), (1090, 700, 22, 3.6, 0.2),
            (640, 880, 16, 2.1, 0.9)]


def _sparkle(draw: ImageDraw.ImageDraw, cx: int, cy: int, s: float, alpha: int) -> None:
    draw.polygon([(cx, cy - s), (cx + s * 0.24, cy - s * 0.24), (cx + s, cy),
                  (cx + s * 0.24, cy + s * 0.24), (cx, cy + s),
                  (cx - s * 0.24, cy + s * 0.24), (cx - s, cy),
                  (cx - s * 0.24, cy - s * 0.24)], fill=(255, 255, 255, alpha))


class Panel:
    """Everything that does not change between frames, built once."""

    MASCOT_H = 560

    def __init__(self, lang: str) -> None:
        self.base = _gradient()
        self.bokeh = _bokeh()

        self.mask = Image.new("L", (FOOT_W, H), 0)
        ImageDraw.Draw(self.mask).rounded_rectangle(
            [0, 0, FOOT_W - 1, H - 1], CORNER, fill=255)

        shadow = Image.new("RGBA", (FOOT_W + 60, H + 60), (0, 0, 0, 0))
        ImageDraw.Draw(shadow).rounded_rectangle(
            [16, 16, FOOT_W + 44, H + 44], CORNER + 14, fill=(60, 50, 70, 95))
        self.shadow = shadow.filter(ImageFilter.GaussianBlur(22))

        self.poses = {}
        for name in ("point", "coins", "broom"):
            img = Image.open(ASSETS / f"pose_{name}.png").convert("RGBA")
            w = round(img.width * self.MASCOT_H / img.height)
            self.poses[name] = img.resize((w, self.MASCOT_H), Image.LANCZOS)

        icon = Image.open(ASSETS / "icon_512_v2.png").convert("RGBA")
        self.icon = icon.resize((272, 272), Image.LANCZOS)
        badge = Image.open(ASSETS / "badges" / f"google_play_{lang}.png").convert("RGBA")
        self.badge = badge.resize(
            (380, round(badge.height * 380 / badge.width)), Image.LANCZOS)

        self.f_title = ImageFont.truetype(str(FONT_PATH), 80)
        self.f_line = ImageFont.truetype(str(FONT_PATH), 46)


def _line_alpha(t: float, start: float, end: float) -> float:
    if t < start or t >= end:
        return 0.0
    if t < start + FADE:
        return (t - start) / FADE
    if t > end - FADE:
        return max(0.0, (end - t) / FADE)
    return 1.0


def render(frames: list[Path], track: Path, out_path: Path, copy: dict,
           fps: int, lang: str) -> Path:
    panel = Panel(lang)
    clip = len(frames) / fps
    slot = clip / len(copy["lines"])
    total_frames = len(frames) + round(ENDCARD * fps)

    proc = subprocess.Popen(
        ["ffmpeg", "-y", "-v", "error",
         "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}",
         "-r", str(fps), "-i", "-",
         "-i", str(track),
         "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "20", "-preset", "medium",
         "-c:a", "aac", "-b:a", "128k", "-shortest",
         "-movflags", "+faststart", str(out_path)],
        stdin=subprocess.PIPE)

    last_shot = None
    for i in range(total_frames):
        t = i / fps
        after = max(0.0, t - clip)          # 0 while the footage is still playing
        frame = panel.base.copy()

        # The coins drift a whole 40 px across the clip: enough not to be static,
        # little enough that nobody catches it happening.
        drift = round(40 * t / (clip + ENDCARD))
        frame.paste(panel.bokeh, (-drift, -drift), panel.bokeh)

        draw = ImageDraw.Draw(frame, "RGBA")
        for cx, cy, s, period, phase in SPARKLES:
            a = 0.45 + 0.55 * math.sin(2 * math.pi * (t / period + phase))
            _sparkle(draw, cx, cy, s, round(190 * max(0.0, a)))

        if i < len(frames):
            last_shot = Image.open(frames[i]).convert("RGB").resize(
                (FOOT_W, H), Image.LANCZOS)
        shot_x = FOOT_X + round(_ramp(after, 0.0, SLIDE) * (W - FOOT_X + 40))
        if shot_x < W:
            frame.paste(panel.shadow, (shot_x - 30, -30), panel.shadow)
            frame.paste(last_shot, (shot_x, 0), panel.mask)
            draw.rounded_rectangle([shot_x - 3, -3, shot_x + FOOT_W + 2, H + 2],
                                   CORNER + 3, outline=(255, 255, 255, 200), width=3)

        # The mascot breathes, and swaps to the pose that matches the line.
        idx = min(len(copy["lines"]) - 1, int(t / slot)) if after == 0.0 else None
        pose = copy["lines"][idx]["pose"] if idx is not None else "coins"
        mascot = panel.poses[pose]
        bob = round(4 * math.sin(2 * math.pi * t / 2.6))
        frame.paste(mascot, (120, H - panel.MASCOT_H + bob), mascot)

        draw.text((TEXT_X, 270), copy["title"], font=panel.f_title, fill=NAVY)
        draw.rounded_rectangle([TEXT_X + 2, 392, TEXT_X + 72, 400], 4, fill=GOLD)

        if after == 0.0:
            for j, entry in enumerate(copy["lines"]):
                a = _line_alpha(t, j * slot, (j + 1) * slot)
                if a > 0:
                    draw.text((TEXT_X, 430), entry["text"], font=panel.f_line,
                              fill=(*SLATE, round(255 * a)))
            draw.text((470, H - 92), copy["footer"], font=panel.f_line,
                      fill=(90, 100, 130, 190))
        else:
            a = _ramp(after, 0.25, 0.9)
            if a > 0:
                draw.text((TEXT_X, 430), copy["endline"], font=panel.f_line,
                          fill=(*SLATE, round(255 * a)))
            # The icon and the official Play badge fill the space the phone left.
            b = _ramp(after, 0.55, 1.3)
            if b > 0:
                # Left of dead centre in the vacated half, so the end card
                # reads as one block with the title instead of two far corners.
                cx = 1400
                lift = round(28 * (1 - b))
                card = Image.new("RGBA", (W, H), (0, 0, 0, 0))
                card.paste(panel.icon, (cx - panel.icon.width // 2, 300 + lift), panel.icon)
                card.paste(panel.badge, (cx - panel.badge.width // 2, 620 + lift), panel.badge)
                card.putalpha(card.getchannel("A").point(lambda v: round(v * b)))
                frame = Image.alpha_composite(frame.convert("RGBA"), card).convert("RGB")

        proc.stdin.write(frame.tobytes())

    proc.stdin.close()
    if proc.wait() != 0:
        sys.exit("ffmpeg failed while encoding the landscape cut")
    return out_path


def thumbnail(frame: Path, out_path: Path, copy: dict, lang: str) -> Path:
    """The YouTube thumbnail: the same panel, with type sized for a small card.

    A thumbnail is read at a fraction of its size, so the clip's own 80 px title
    would land at roughly 25 px on a phone. It is drawn here at canvas size with
    heavier type and then reduced to the 1280x720 YouTube wants.
    """
    panel = Panel(lang)
    img = panel.base.copy()
    img.paste(panel.bokeh, (0, 0), panel.bokeh)
    draw = ImageDraw.Draw(img, "RGBA")
    for cx, cy, s, _period, _phase in SPARKLES:
        _sparkle(draw, cx, cy, s, 190)

    shot = Image.open(frame).convert("RGB").resize((FOOT_W, H), Image.LANCZOS)
    img.paste(panel.shadow, (FOOT_X - 30, -30), panel.shadow)
    img.paste(shot, (FOOT_X, 0), panel.mask)
    draw.rounded_rectangle([FOOT_X - 3, -3, FOOT_X + FOOT_W + 2, H + 2],
                           CORNER + 3, outline=(255, 255, 255, 200), width=3)

    mascot = panel.poses["point"]
    img.paste(mascot, (120, H - Panel.MASCOT_H), mascot)

    big = ImageFont.truetype(str(FONT_PATH), 118)
    sub = ImageFont.truetype(str(FONT_PATH), 62)
    draw.text((TEXT_X, 210), copy["title"], font=big, fill=NAVY)
    draw.rounded_rectangle([TEXT_X + 4, 372, TEXT_X + 108, 384], 6, fill=GOLD)
    draw.text((TEXT_X, 416), copy["endline"], font=sub, fill=SLATE)
    # Clear of the mascot, who stands from y=520 out to x=426.
    img.paste(panel.badge, (480, 640), panel.badge)

    img.resize((1280, 720), Image.LANCZOS).save(out_path, quality=92)
    return out_path
