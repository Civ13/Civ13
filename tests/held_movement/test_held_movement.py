"""Offline contracts for continuous held-key smooth movement; no BYOND runtime.

Each smooth step runs sixteen 2px pulses on its admitted interval, then the
movementMachine re-admits a held key. It used to wait for the machine's next
scan and start the new step from that later tick, so the body stood still at
each tile centre for a tick or more and its glide caught up and stopped.
A held key now continues in the tick the step's deadline is reached, and the
new step is timed from that exact deadline. Chained steps keep the old pace
(the deadline tick plus one scan tick), so only the stop is removed and players
do not move faster. The tick model below shows the difference; DreamSeeker
rendering is not exercised here.
"""
from pathlib import Path
import math
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
MACHINE = (ROOT / 'code/movementMachine.dm').read_text(encoding='utf-8')
MOVEMENT = (ROOT / 'code/game/mob/mob_movement.dm').read_text(encoding='utf-8')
SUBTILE = (ROOT / 'code/game/mob/living/carbon/human/subtile_movement.dm').read_text(encoding='utf-8')
TICK = 0.4


def proc_body(text, header):
    start = text.index(header)
    following = re.search(r'^/(?![*/])', text[start + len(header):], re.M)
    end = start + len(header) + following.start() if following else len(text)
    return text[start:end]


def held_pace(duration):
    ticks = -int(-round(duration / TICK, 3) // 1)
    return (max(1, ticks) + 1) * TICK


def pixels_per_tick(duration, chained, steps=12):
    """Pulses due at start + (i - 1) * d / 16 run in the first tick at or after."""
    moved, now, start, base = {}, 0.0, 0.0, duration
    for step in range(steps):
        if chained and step:
            duration = held_pace(base)
        for i in range(16):
            due = start + i * duration / 16
            now = max(now, math.ceil(round(due / TICK, 6)) * TICK)
            moved[round(now, 1)] = moved.get(round(now, 1), 0) + 2
        deadline = start + duration
        wake = max(now, math.ceil(round(deadline / TICK, 6)) * TICK)
        if chained:
            start = deadline if wake - deadline < TICK else wake
        else:
            wake += TICK
            start = wake
        now = wake
    last = int(round(max(moved) / TICK))
    return [moved.get(round(i * TICK, 1), 0) for i in range(last + 1)]


class TickModel(unittest.TestCase):
    def test_chained_steps_keep_todays_pace_without_stopping(self):
        for duration in (1.6, 2.0, 2.2, 3.3):
            with self.subTest(duration=duration):
                old = pixels_per_tick(duration, False)
                new = pixels_per_tick(duration, True)
                # Same distance in the same ticks as before, but spread evenly
                # instead of slowing into each tile centre.
                self.assertEqual(len(new), len(old))
                self.assertGreater(len(new) * TICK / 12, duration)
                # Skip the first step, which runs at the configured speed.
                before, after = old[len(old) // 6:-2], new[len(new) // 6:-2]
                self.assertNotIn(0, after)
                self.assertLessEqual(max(after) - min(after), 2)
                self.assertGreater(max(before) - min(before), 2)
                self.assertGreater(min(after), min(before))

    def test_held_pace_matches_the_old_scan_cadence(self):
        self.assertAlmostEqual(held_pace(2.0), 2.4)
        self.assertAlmostEqual(held_pace(2.2), 2.8)
        self.assertAlmostEqual(held_pace(0.1), 0.8)


class Sources(unittest.TestCase):
    def test_held_key_continues_in_the_deadline_tick(self):
        body = proc_body(MACHINE, '/movementMachine/proc/do_movement_continued(')
        self.assertIn('world.time - movtoset < world.tick_lag', body)
        self.assertIn('world.time > started', body)
        self.assertIn('held_movement_ready(M)', body)
        self.assertIn('M.client.human_subtile_chain_time = movtoset', body)
        chain = body.index('begin_held_movement(M)')
        self.assertLess(chain, body.index('M.client.movement_busy = FALSE'))
        self.assertIn('return', body[chain:body.index('M.client.movement_busy = FALSE')])
        self.assertIn('do_movement_continued(M, started)', proc_body(MACHINE, '/movementMachine/proc/do_movement('))

    def test_scan_and_chain_share_one_direction_rule(self):
        loop = proc_body(MACHINE, '/movementMachine/proc/process(')
        self.assertIn('if (held_movement_ready(M))', loop)
        self.assertIn('begin_held_movement(M)', loop)
        self.assertNotIn('movedir', loop)

    def test_client_move_consumes_the_chain_once(self):
        body = proc_body(MOVEMENT, '/client/Move(')
        self.assertLess(body.index('human_subtile_chain_time = null'), body.index('if (!canmove)'))
        self.assertIn('subtile_chain_time + H.human_subtile_held_pace(subtile_deadline - world.time)', body)
        self.assertIn('subtile_deadline = held_deadline', body)
        self.assertIn('!H.human_subtile_pull_ready(direct)', body)
        self.assertIn('H.human_subtile_chain_start = null', body)

    def test_travel_times_a_chained_step_from_the_previous_deadline(self):
        body = proc_body(SUBTILE, '/mob/living/human/proc/human_subtile_travel(')
        self.assertIn('T.start_time = human_subtile_chain_start', body)
        self.assertIn('!legacy_posture && !paid_posture && fine_step != FINE_STEP_NUDGE', body)
        self.assertIn('human_subtile_update_visuals(deadline - T.start_time', body)
        self.assertIn('"human_subtile_chain_start"', SUBTILE)

    def test_held_pace_adds_one_scan_tick(self):
        body = proc_body(SUBTILE, '/mob/living/human/proc/human_subtile_held_pace(')
        self.assertIn('-round(-round(duration / world.tick_lag, 0.001))', body)
        self.assertIn('(max(1, ticks) + 1) * world.tick_lag', body)


if __name__ == '__main__':
    unittest.main()
