"""Free movement pulses are drawn smoothly between server ticks.

BYOND's legacy movement mode never glides an atom with a step_x/step_y offset,
so free movement (always offset) used to be drawn at the raw 0.4 ds tick rate in
uneven 2px/4px jumps. human_subtile_smooth_pulse offsets the body and its camera
back to where they were drawn and animates them forward. This emulates that
proc against the real pulse schedule and checks the drawn speed is even.
Dream Seeker captures: tests/human_subtile/glide_probe/README.md.
"""
import math
from pathlib import Path
import re
import statistics
import unittest

ROOT = Path(__file__).resolve().parents[2]
MODULE = (ROOT / 'code/game/mob/living/carbon/human/subtile_movement.dm').read_text(encoding='utf-8')
DEFINES = (ROOT / 'code/__defines/mobs.dm').read_text(encoding='utf-8')
TICK = 0.4  # deciseconds, TICKLAG 0.4
FRAME = 0.1  # client FPS 100


def proc_body(name):
    start = MODULE.index('/mob/living/human/proc/%s(' % name)
    end = MODULE.index('\n/', start + 1)
    return MODULE[start:end]


def smooth_max():
    return float(re.search(r'#define HUMAN_SUBTILE_SMOOTH_MAX (\S+)', DEFINES).group(1))


def drawn_track(ticks_per_step, steps=12, smooth=True):
    """Drawn x at each client frame for a held walk (2px pulses, 16 per step)."""
    duration = ticks_per_step * TICK
    spacing = duration / 16
    pulses = []  # (tick time, dx)
    for step in range(steps):
        start = step * duration
        for i in range(1, 17):
            due = start + i * duration / 16
            pulses.append((math.ceil(due / TICK - 1e-9) * TICK, 2))
    # Server state per pulse: mirror of human_subtile_smooth_pulse.
    anims = []  # (start, from, time) drawn offset easing to 0
    real = []  # (time, real x)
    x = 0
    s_start, s_time, s_from = None, 0, 0
    for t, dx in pulses:
        x += dx
        real.append((t, x))
        lag = 0
        if s_start is not None and s_time > 0:
            left = 1 - (t - s_start) / s_time
            if left > 0:
                lag = s_from * left
        lag -= dx
        if abs(lag) > smooth_max():
            lag = 0
        time = max(TICK, spacing) + TICK
        s_start, s_time, s_from = t, time, lag
        anims.append((t, round(lag, 2), time))
    out = []
    end = pulses[-1][0]
    f = 0.0
    while f < end:
        rx = max([px for (pt, px) in real if pt <= f] or [0])
        off = 0
        if smooth:
            last = [a for a in anims if a[0] <= f]
            if last:
                a_start, a_from, a_time = last[-1]
                off = a_from * max(0, 1 - (f - a_start) / a_time)
        out.append(rx + off)
        f = round(f + FRAME, 6)
    return out


def frame_steps(track, skip=20):
    return [b - a for a, b in zip(track[skip:], track[skip + 1:])]


class SmoothPulseContracts(unittest.TestCase):
    def test_called_for_every_accepted_pulse(self):
        self.assertIn('actor.human_subtile_smooth_pulse(actual_x, actual_y, duration / pulse_count)', MODULE)

    def test_parallel_animation_body_and_own_camera(self):
        body = proc_body('human_subtile_smooth_pulse')
        self.assertEqual(body.count('flags = ANIMATION_PARALLEL'), 2)
        self.assertIn('C.eye == src && !shakecamera', body)
        self.assertIn('animate(src, pixel_w = 0, pixel_z = 0', body)
        self.assertIn('animate(C, pixel_w = 0, pixel_z = 0', body)
        # Scopes and dizziness own client pixel_x/pixel_y.
        self.assertNotIn('pixel_x', body)
        self.assertNotIn('pixel_y', body)

    def test_raw_pulses_jump_at_tick_rate(self):
        steps = frame_steps(drawn_track(13, smooth=False))
        self.assertGreater(sum(1 for s in steps if s == 0) / len(steps), 0.6)

    def test_smoothed_pace_is_even_at_walking_paces(self):
        for ticks in (6, 9, 10, 13, 16):
            steps = frame_steps(drawn_track(ticks))[:-20]
            pace = 32 / (ticks * TICK) * FRAME
            stalls = sum(1 for s in steps if s < 0.05)
            self.assertEqual(stalls, 0, ticks)
            self.assertTrue(all(s > -0.01 for s in steps), ticks)  # never backwards
            self.assertLess(statistics.pstdev(steps) / pace, 0.35, ticks)
            self.assertAlmostEqual(statistics.mean(steps), pace, delta=pace * 0.1)


if __name__ == '__main__':
    unittest.main()
