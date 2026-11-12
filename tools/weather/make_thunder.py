"""Synthesise the thunder of the moving weather systems (docs/weather-systems.md).

sound/effects/thunder_near.ogg   a sharp crack, then a long roll
sound/effects/thunder_far.ogg    a low distant rumble

Both are filtered noise shaped by envelopes from a fixed seed: no recording,
no borrowed sound. Needs numpy and ffmpeg (libvorbis).

    python3 tools/weather/make_thunder.py
"""
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
RATE = 22050


def lowpass(signal, cutoff):
    """One-pole low pass, run twice for a steeper slope."""
    alpha = 1 - np.exp(-2 * np.pi * cutoff / RATE)
    for _ in range(2):
        out = np.empty_like(signal)
        level = 0.0
        for i, value in enumerate(signal):
            level += alpha * (value - level)
            out[i] = level
        signal = out
    return signal


def rumble(rng, seconds, cutoff, swells):
    count = int(seconds * RATE)
    body = lowpass(rng.standard_normal(count), cutoff)
    time = np.arange(count) / RATE
    envelope = np.zeros(count)
    for start, size, decay in swells:
        after = np.clip(time - start, 0, None)
        envelope += np.where(time >= start, size * np.minimum(1, after / 0.05) * np.exp(-after / decay), 0)
    # A slow uneven tremble, so the roll is not one smooth fade.
    tremble = 0.75 + 0.25 * lowpass(rng.standard_normal(count), 6) / 0.05
    return body * envelope * np.clip(tremble, 0.3, 1.4)


def near(rng):
    count = int(5.5 * RATE)
    out = rumble(rng, 5.5, 140, ((0.02, 1.0, 0.9), (0.7, 0.6, 1.1), (1.8, 0.4, 1.3)))
    crack = lowpass(rng.standard_normal(count), 2600)
    time = np.arange(count) / RATE
    crack_env = np.exp(-time / 0.09) + 0.5 * np.where(time >= 0.16, np.exp(-(time - 0.16) / 0.12), 0)
    return out / np.abs(out).max() * 0.85 + crack / np.abs(crack).max() * crack_env * 0.6


def far(rng):
    return rumble(rng, 7.0, 70, ((0.1, 0.5, 1.6), (1.4, 1.0, 1.5), (3.2, 0.6, 1.6)))


def write(name, samples):
    samples = samples / np.abs(samples).max() * 0.9
    fade = int(0.4 * RATE)
    samples[-fade:] *= np.linspace(1, 0, fade)
    target = ROOT / "sound/effects" / name
    with tempfile.TemporaryDirectory() as folder:
        plain = Path(folder) / "thunder.wav"
        with wave.open(str(plain), "wb") as out:
            out.setnchannels(1)
            out.setsampwidth(2)
            out.setframerate(RATE)
            out.writeframes((samples * 32767).astype("<i2").tobytes())
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", str(plain), "-c:a", "libvorbis", "-q:a", "3",
                        "-map_metadata", "-1", "-fflags", "+bitexact", "-flags:a", "+bitexact", str(target)], check=True)
    print(f"wrote {target.relative_to(ROOT)} ({target.stat().st_size} bytes)")


def main():
    rng = np.random.default_rng(1713)
    write("thunder_near.ogg", near(rng))
    write("thunder_far.ogg", far(rng))
    return 0


if __name__ == "__main__":
    sys.exit(main())
