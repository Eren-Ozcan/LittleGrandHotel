"""Turn the showcase frame sequence into the promo clip, with sound.

`tests/showcase.tscn -- video` writes one PNG per frame plus the raw material for
the soundtrack: the game's own procedural effects and lobby music as WAV, and
`audio_cues.json` saying which frame each effect belongs to. The capture loop is
not real time — every frame is a PNG write — so the audio cannot be recorded off
the running game; it is assembled here instead, at the exact timestamps.

    python scripts/make_promo_video.py

Reads from Godot's user data folder, writes demo.mp4 and demo.gif into
docs/store-assets-originals/, and copies the GIF into docs/media/ for the README.
"""

import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
MEDIA = Path(os.environ["APPDATA"]) / "Godot" / "app_userdata" / "Little Grand Hotel" / "media"
ASSETS = REPO / "docs" / "store-assets-originals"
README_MEDIA = REPO / "docs" / "media"

FPS = 30
# The music sits well under the effects: it is a loop, and a loop at full volume
# is the fastest way to make a 22-second clip feel long.
MUSIC_DB = -17.0
SFX_DB = -6.0


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
    # quiet on a phone. loudnorm pulls the whole bed up to broadcast level.
    filters.append(
        "".join(labels) + f"amix=inputs={len(labels)}:normalize=0:dropout_transition=0,"
        "loudnorm=I=-16:TP=-1.5:LRA=11[out]")
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

    track = MEDIA / "audio_track.wav"
    build_audio(cues, duration, track)

    mp4 = ASSETS / "demo.mp4"
    run(["ffmpeg", "-y", "-v", "error",
         "-framerate", str(FPS), "-i", str(MEDIA / "frame_%04d.png"),
         "-i", str(track),
         "-vf", "scale=720:1280:flags=lanczos",
         "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "22",
         "-c:a", "aac", "-b:a", "128k", "-shortest",
         "-movflags", "+faststart", str(mp4)])

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

    for f in (mp4, gif):
        print(f"wrote {f} ({f.stat().st_size / 1024 / 1024:.2f} MB)")


if __name__ == "__main__":
    main()
