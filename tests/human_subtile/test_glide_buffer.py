"""Fresh free movement starts with a small client glide buffer.

The emulator follows the BYOND 516 web client's pixel glide (Glide.glide in
byond/web/webclient.dart.js): unfinished glide carries into the next update, a
lag over one tile speeds the glide up, and a glide within 0.5px of its target
snaps there. Pulses follow subtile_movement.dm: sixteen 2px pulses per step,
due at start + i * duration / 16, each run on the first tick at or after it.
"""
import math
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
MODULE = (ROOT / 'code/game/mob/living/carbon/human/subtile_movement.dm').read_text(encoding='utf-8')
DEFINES = (ROOT / 'code/__defines/mobs.dm').read_text(encoding='utf-8')
TICK = 40.0  # TICKLAG 0.4
FRAME = 10.0  # default client FPS 100


def define(name):
    return float(re.search(r'#define %s (\S+)' % name, DEFINES).group(1))


def glide_distance(ticks, fresh):
    """Mirror of human_subtile_glide_distance for a 32px step."""
    if not fresh or ticks < 2:
        return 32.0
    per_tick = 32.0 / ticks
    return 32.0 - min(max(per_tick, define('HUMAN_SUBTILE_GLIDE_BUFFER_MIN')), define('HUMAN_SUBTILE_GLIDE_BUFFER_MAX'))


def frozen_frames(ticks, buffered, steps=30, jitter=None):
    """Client frames where the sprite stops while a held walk is under way."""
    received = []  # (arrival ms, cumulative px)
    position, pulses = 0, []
    for step in range(steps):
        start = (2 + step * ticks) * TICK
        pulses += [math.ceil((start + i * ticks * TICK / 16) / TICK - 1e-9) for i in range(16)]
    last_arrival = 0.0
    for tick in range(2 + steps * ticks + 30):
        position += 2 * sum(1 for p in pulses if p == tick)
        arrival = tick * TICK + (jitter(tick) if jitter else 0.0)
        last_arrival = max(last_arrival, arrival)
        received.append((last_arrival, position))
    remaining, got, index, shown, now = 0.0, 0, 0, [], 1.0
    while index < len(received) or remaining:
        while index < len(received) and received[index][0] <= now:
            remaining += received[index][1] - got
            got = received[index][1]
            index += 1
        speed = glide_distance(ticks, buffered and got <= 32) / ticks
        if remaining > 32:
            speed = math.ceil(speed * remaining / 32)
        speed *= FRAME / TICK
        remaining = 0.0 if remaining <= speed + 0.5 else remaining - speed
        shown.append(got - remaining)
        now += FRAME
    walking = [s for s in shown if 4 < s < 32 * steps - 4]
    return sum(1 for a, b in zip(walking, walking[1:]) if b - a < 0.05)


class GlideBufferContracts(unittest.TestCase):
    def test_only_fresh_whole_steps_get_the_buffer(self):
        self.assertIn('(fine_step == FINE_STEP_NUDGE) ? 2 : human_subtile_glide_distance(deadline, deadline - T.start_time)', MODULE)
        self.assertIn('world.time > human_subtile_glide_deadline + world.tick_lag', MODULE)
        self.assertIn('if (!fresh || duration < 2 * world.tick_lag)', MODULE)
        self.assertIn('var/tmp/human_subtile_glide_deadline', MODULE)
        self.assertEqual(define('HUMAN_SUBTILE_GLIDE_BUFFER_MIN'), 6)
        self.assertEqual(define('HUMAN_SUBTILE_GLIDE_BUFFER_MAX'), 8)

    def test_walking_paces_no_longer_judder(self):
        # 9-14 ticks per tile: walking, snow and injuries at TICKLAG 0.4.
        # Slower paces (15+ ticks) still pause one frame in four: the client
        # snaps a glide within 0.5px, which eats a buffer this small.
        for ticks in (9, 10, 11, 13, 14):
            with self.subTest(ticks=ticks):
                self.assertGreater(frozen_frames(ticks, buffered=False), 20)
                self.assertLessEqual(frozen_frames(ticks, buffered=True), 3)

    def test_running_stays_smooth(self):
        for ticks in (4, 5, 6, 7, 8, 9, 10):
            with self.subTest(ticks=ticks):
                self.assertEqual(frozen_frames(ticks, buffered=True), 0)

    def test_small_jitter_is_absorbed(self):
        # Every fifth update arrives 25 ms late (TCP keeps order).
        late = lambda tick: 25.0 if tick % 5 == 0 else 0.0
        for ticks in range(4, 15):
            with self.subTest(ticks=ticks):
                self.assertLessEqual(frozen_frames(ticks, buffered=True, jitter=late), min(4, frozen_frames(ticks, buffered=False, jitter=late)))


if __name__ == '__main__':
    unittest.main()
