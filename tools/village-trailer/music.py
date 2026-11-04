"""Compose the trailer's medieval town tune: an original jig in D dorian.

Everything is synthesised here (plucked lute, recorder, hurdy-gurdy style
drone, frame drum and tambourine), so the track carries no third-party
rights. The bar length is stretched slightly so the tune's phrases end with
a final cadence exactly at the requested duration.

    python3 tools/village-trailer/music.py --seconds 99.6 --out music.wav
"""
import argparse
import math
import wave

import numpy as np

SR = 44100
rng = np.random.default_rng(13)

# Melody phrases: one list per bar of (midi note, length in eighths), 6/8.
A = [
    [(74, 2), (76, 1), (77, 2), (76, 1)],
    [(74, 2), (72, 1), (69, 3)],
    [(72, 2), (74, 1), (76, 2), (72, 1)],
    [(74, 2), (76, 1), (77, 3)],
    [(81, 2), (79, 1), (77, 2), (76, 1)],
    [(79, 2), (77, 1), (76, 2), (72, 1)],
    [(74, 1), (76, 1), (77, 1), (76, 1), (74, 1), (72, 1)],
    [(74, 6)],
]
A_CHORDS = ['Dm', 'Dm', 'C', 'Dm', 'F', 'C', 'Am', 'Dm']
B = [
    [(81, 2), (84, 1), (81, 2), (79, 1)],
    [(79, 2), (77, 1), (76, 3)],
    [(77, 2), (79, 1), (81, 2), (86, 1)],
    [(84, 3), (81, 3)],
    [(81, 2), (79, 1), (77, 2), (79, 1)],
    [(81, 2), (79, 1), (76, 3)],
    [(77, 1), (76, 1), (74, 1), (72, 1), (74, 1), (76, 1)],
    [(74, 6)],
]
B_CHORDS = ['F', 'C', 'Dm', 'Am', 'F', 'C', 'Am', 'Dm']
VOICINGS = {
    'Dm': (50, 57, 62, 65),
    'C': (48, 55, 60, 64),
    'F': (53, 60, 65, 69),
    'Am': (45, 52, 57, 60),
}
ARPEGGIO = (0, 1, 2, 3, 2, 1)


def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


def pluck(midi, seconds, brightness=0.5):
    """Karplus-Strong plucked string, computed one period block at a time."""
    n = int(seconds * SR)
    period = max(2, int(round(SR / hz(midi))))
    y = np.zeros(n + period + 1)
    burst = rng.uniform(-1, 1, period)
    # Soften the excitation for a gut-string lute rather than a steel twang.
    for _ in range(int(3 * (1 - brightness)) + 1):
        burst = 0.5 * (burst + np.roll(burst, 1))
    y[1:period + 1] = burst
    decay = 0.996
    k = period + 1
    while k < n + period + 1:
        end = min(k + period, n + period + 1)
        a = y[k - period:end - period]
        b = y[k - period - 1:end - period - 1]
        y[k:end] = decay * 0.5 * (a + b)
        k = end
    out = y[1:n + 1]
    env = np.minimum(1, np.linspace(0, seconds, n) / 0.004)
    return out * env


def recorder(midi, seconds):
    n = int(seconds * SR)
    t = np.arange(n) / SR
    f = hz(midi)
    vib = 1 + 0.004 * np.sin(2 * math.pi * 5.2 * t) * np.clip((t - 0.18) / 0.2, 0, 1)
    phase = 2 * math.pi * f * np.cumsum(vib) / SR
    tone = np.sin(phase) + 0.18 * np.sin(2 * phase) + 0.07 * np.sin(3 * phase)
    breath = np.convolve(rng.normal(0, 1, n), np.ones(30) / 30, mode='same') * 0.04
    attack = np.clip(t / 0.03, 0, 1)
    release = np.clip((seconds - t) / 0.06, 0, 1)
    return (tone + breath) * attack * release


def drone(seconds):
    n = int(seconds * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for midi, gain in ((38, 1.0), (45, 0.7), (50, 0.35)):
        f = hz(midi) * (1 + 0.0015 * np.sin(2 * math.pi * 0.3 * t + midi))
        phase = 2 * math.pi * np.cumsum(f) / SR
        saw = sum(np.sin(k * phase) / k for k in range(1, 9))
        out += gain * saw
    return lowpass(out, 900)


def lowpass(x, cutoff):
    spec = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(len(x), 1 / SR)
    spec /= np.sqrt(1 + (freqs / cutoff) ** 4)
    return np.fft.irfft(spec, len(x))


def frame_drum(accent):
    n = int(0.45 * SR)
    t = np.arange(n) / SR
    pitch = 55 + 70 * np.exp(-t * 30)
    body = np.sin(2 * math.pi * np.cumsum(pitch) / SR) * np.exp(-t * 9)
    slap = lowpass(rng.normal(0, 1, n), 2500) * np.exp(-t * 80) * 0.2
    return (body + slap) * accent


def tambourine(accent):
    n = int(0.18 * SR)
    t = np.arange(n) / SR
    # A few metallic partials rather than white noise, so it shimmers
    # instead of hissing.
    jingle = sum(np.sin(2 * math.pi * f * t + rng.uniform(0, 6)) for f in (5100, 6300, 7400, 8900))
    jingle *= 1 + 0.5 * rng.normal(0, 1, n)
    return jingle * np.exp(-t * 35) * accent * 0.25


def reverb(x, seconds=1.6, mix=0.22):
    n = int(seconds * SR)
    t = np.arange(n) / SR
    ir = rng.normal(0, 1, n) * np.exp(-t * 4.2)
    ir = lowpass(ir, 4500)
    ir /= np.sqrt(np.sum(ir ** 2))
    size = 1 << int(math.ceil(math.log2(len(x) + n)))
    wet = np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(ir, size), size)[:len(x)]
    return (1 - mix) * x + mix * wet


def add(track, sound, start, gain=1.0):
    i = int(start * SR)
    if i >= len(track):
        return
    j = min(len(track), i + len(sound))
    track[i:j] += gain * sound[:j - i]


def compose(seconds):
    tail = 2.5
    # Intro (4 bars) + 9 eight-bar phrases + a 2-bar closing cadence.
    phrases = max(2, round((((seconds - tail) / 1.25) - 6) / 8))
    bars = 4 + 8 * phrases + 2
    bar = (seconds - tail) / bars
    eighth = bar / 6
    n = int(seconds * SR)
    lute = np.zeros(n)
    flute = np.zeros(n)
    drums = np.zeros(n)
    order = [A, A, B, A, B, B, A, B, A, A, B, A]
    chord_of = {id(A): A_CHORDS, id(B): B_CHORDS}
    plan = []  # (bar index, chord, melody bar or None, intensity)
    for b in range(4):
        plan.append(('Dm', None, 0))
    for p in range(phrases):
        tune = order[p % len(order)]
        for i in range(8):
            plan.append((chord_of[id(tune)][i], tune[i], 1 if p == 0 else 2))
    plan.append(('Am', [(76, 3), (72, 3)], 2))
    plan.append(('Dm', [(74, 6)], 3))
    for b, (chord, melody, intensity) in enumerate(plan):
        t0 = b * bar
        voicing = VOICINGS[chord]
        last = b == len(plan) - 1
        if last:
            # Final strum, left to ring through the fade.
            for k, note in enumerate(voicing):
                add(lute, pluck(note, tail + bar, 0.6), t0 + k * 0.035, 0.55)
        else:
            for k, idx in enumerate(ARPEGGIO):
                accent = 0.75 if k in (0, 3) else 0.5
                add(lute, pluck(voicing[idx], eighth * 2.2, 0.45), t0 + k * eighth, accent)
        if melody:
            t = t0
            for note, length in melody:
                dur = length * eighth * (0.92 if length < 6 else 1.0)
                if last:
                    dur = tail + bar * 0.8
                add(flute, recorder(note, dur), t, 0.32)
                t += length * eighth
        if intensity >= 1 and not last:
            add(drums, frame_drum(0.9), t0, 0.5)
            add(drums, frame_drum(0.6), t0 + 3 * eighth, 0.5)
        if intensity >= 2 and not last:
            for k in range(6):
                add(drums, tambourine(0.5 if k in (0, 3) else 0.25), t0 + k * eighth, 0.2)
        if last:
            add(drums, frame_drum(1.0), t0, 0.5)
    hum = drone(seconds) * 0.05
    t = np.arange(n) / SR
    hum *= np.clip(t / 6.0, 0, 1)  # the drone swells in under the intro
    left = reverb(lute * 0.95 + flute * 0.75 + drums * 0.85 + hum)
    right = reverb(lute * 0.75 + flute * 0.95 + drums * 0.85 + hum)
    mix = np.stack([left, right], axis=1)
    fade = np.clip((seconds - t) / 2.0, 0, 1)[:, None]
    mix *= fade
    mix *= 0.89 / np.max(np.abs(mix))
    return mix


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--seconds', type=float, required=True)
    p.add_argument('--out', required=True)
    a = p.parse_args()
    mix = compose(a.seconds)
    with wave.open(a.out, 'wb') as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((mix * 32767).astype('<i2').tobytes())
    print(a.out, len(mix) / SR)


if __name__ == '__main__':
    main()
