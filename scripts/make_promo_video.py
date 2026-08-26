"""Turn the showcase frame sequence into the promo clips, with sound.

`tests/showcase.tscn -- video` writes one PNG per frame plus the raw material for
the soundtrack: the game's own procedural effects and lobby music as WAV, and
`audio_cues.json` saying which frame each effect belongs to. The capture loop is
not real time — every frame is a PNG write — so the audio cannot be recorded off
the running game; it is assembled here instead, at the exact timestamps.

    python scripts/make_promo_video.py

Reads from Godot's user data folder and writes into docs/store-assets-originals/:

* `demo.mp4` — the 720x1280 vertical cut, for social and for reference.
* `demo_landscape_tr.mp4` / `demo_landscape_en.mp4` — the 1920x1080 cut the Play
  listing's promo video field points at, one per locale. The panel beside the
  footage is drawn by `promo_panel.py`; its copy is the `COPY` table below.
* `demo.gif` — the silent README loop, also copied into docs/media/.
"""

import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

import promo_panel

REPO = Path(__file__).resolve().parent.parent
MEDIA = Path(os.environ["APPDATA"]) / "Godot" / "app_userdata" / "Little Grand Hotel" / "media"
ASSETS = REPO / "docs" / "store-assets-originals"
README_MEDIA = REPO / "docs" / "media"

FPS = 30
# The music sits well under the effects: it is a loop, and a loop at full volume
# is the fastest way to make a 22-second clip feel long.
MUSIC_DB = -17.0
SFX_DB = -6.0

# The copy burnt into the landscape frame is what makes this a two-file job: one
# upload can no longer serve both locales, so a cut is rendered per language and
# each Play listing points at its own video. `pose` picks which mascot drawing
# stands beside the line — she points at the screen while the pitch is about
# building, takes the broom for the cleaning beat, and holds her coins for the
# one about earning.
COPY = {
    "tr": {
        "title": "Little Grand Hotel",
        "footer": "Google Play'de",
        "endline": "Kendi otel imparatorluğunu kur",
        "lines": [
            {"text": "Kendi otelini sıfırdan kur", "pose": "point"},
            {"text": "Her odayı dekore et, yıldızını yükselt", "pose": "point"},
            {"text": "Kirli odaları temizle, istilaya izin verme", "pose": "broom"},
            {"text": "Restoran, havuz, spa, sinema", "pose": "point"},
            {"text": "20 görev, 13 başarım, prestij", "pose": "point"},
            {"text": "Sen kapatsan da otelin kazanır", "pose": "coins"},
        ],
    },
    "en": {
        "title": "Little Grand Hotel",
        "footer": "On Google Play",
        "endline": "Build your own little hotel empire",
        "lines": [
            {"text": "Build your own hotel from scratch", "pose": "point"},
            {"text": "Decorate every room, raise your stars", "pose": "point"},
            {"text": "Clean dirty rooms before they infest", "pose": "broom"},
            {"text": "Restaurant, pool, spa, cinema", "pose": "point"},
            {"text": "20 quests, 13 achievements, prestige", "pose": "point"},
            {"text": "It keeps earning while you are away", "pose": "coins"},
        ],
    },
}


def run(args: list[str]) -> None:
    proc = subprocess.run(args, capture_output=True, text=True)
    if proc.returncode != 0:
        sys.exit("ffmpeg failed:\n" + proc.stderr.strip()[-2000:])


def build_audio(cues: list[dict], duration: float, out: Path) -> None:
    """One music bed plus one delayed copy of each effect, all summed."""
    inputs: list[str] = ["-stream_loop", "-1", "-i", str(MEDIA / "audio_music.wav")]
    filters = [f"[0:a]volume={MUSIC_DB}dB[m]"]
    labels = ["[m]"]
    for i, cue in enumerate(cues, start=1):
        wav = MEDIA / f"audio_{cue['kind']}.wav"
        if not wav.exists():          # a cue whose effect was never exported
            continue
        inputs += ["-i", str(wav)]
        ms = round(cue["frame"] / FPS * 1000)
        # adelay needs one delay per channel; these are mono, so one value.
        filters.append(f"[{i}:a]adelay={ms}|{ms},volume={SFX_DB}dB[s{i}]")
        labels.append(f"[s{i}]")
    # amix with normalize=0 keeps each source at the level it was mixed at, so the
    # sum lands wherever it lands — here around -33 dB mean, which is inaudibly
    # quiet on a phone. loudnorm pulls the whole bed up to broadcast level, and
    # the tail is faded out rather than cut off mid-loop.
    fade = max(0.0, duration - 1.4)
    filters.append(
        "".join(labels) + f"amix=inputs={len(labels)}:normalize=0:dropout_transition=0,"
        f"loudnorm=I=-16:TP=-1.5:LRA=11,afade=t=out:st={fade:.3f}:d=1.4[out]")
    run(["ffmpeg", "-y", "-v", "error", *inputs,
         "-filter_complex", ";".join(filters), "-map", "[out]",
         "-t", f"{duration:.3f}", "-ac", "1", "-ar", "44100", str(out)])


def main() -> None:
    frames = sorted(MEDIA.glob("frame_*.png"))
    if not frames:
        sys.exit(f"no frames in {MEDIA} — run showcase.tscn -- video first")
    cues_path = MEDIA / "audio_cues.json"
    cues = json.loads(cues_path.read_text())["cues"] if cues_path.exists() else []
    duration = len(frames) / FPS
    print(f"{len(frames)} frames ({duration:.1f}s), {len(cues)} cues")

    # Two tracks: the vertical cut ends with the footage, the landscape cut runs
    # on through the end card, and each wants its fade-out in its own place.
    track = MEDIA / "audio_track.wav"
    build_audio(cues, duration, track)
    long_track = MEDIA / "audio_track_long.wav"
    build_audio(cues, duration + promo_panel.ENDCARD, long_track)

    written = []

    mp4 = ASSETS / "demo.mp4"
    run(["ffmpeg", "-y", "-v", "error",
         "-framerate", str(FPS), "-i", str(MEDIA / "frame_%04d.png"),
         "-i", str(track),
         "-vf", "scale=720:1280:flags=lanczos",
         "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "22",
         "-c:a", "aac", "-b:a", "128k", "-shortest",
         "-movflags", "+faststart", str(mp4)])
    written.append(mp4)

    for lang, copy in COPY.items():
        out = ASSETS / f"demo_landscape_{lang}.mp4"
        print(f"rendering {out.name} ...")
        written.append(promo_panel.render(frames, long_track, out, copy, FPS, lang))

    # The README GIF is the same cut without the sound: smaller, and GIFs are
    # silent anyway. 10 fps and 96 colours keep it near the couple-of-MB budget
    # CLAUDE.md sets for what may live in the repo — the cut is 22 s now, so the
    # frame rate and palette had to come down to stay inside it.
    gif = ASSETS / "demo.gif"
    run(["ffmpeg", "-y", "-v", "error",
         "-framerate", str(FPS), "-i", str(MEDIA / "frame_%04d.png"),
         "-vf", ("fps=10,scale=320:568:flags=lanczos,split[a][b];"
                 "[a]palettegen=max_colors=96[p];[b][p]paletteuse=dither=bayer:bayer_scale=5"),
         str(gif)])
    shutil.copyfile(gif, README_MEDIA / "demo.gif")
    written.append(gif)

    for f in written:
        print(f"wrote {f} ({f.stat().st_size / 1024 / 1024:.2f} MB)")


if __name__ == "__main__":
    main()
