"""Pulse wait timing: executes a projection of the actual DM wait helper.

A fractional sleep can wake before a pulse is due, and consume() refuses early
pulses. This simulates the engine's whole-tick scheduler offline with several
tick_lag values; it is not native DM execution or client timing evidence.
"""
from pathlib import Path
import math
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/game/mob/living/carbon/human/pull_pair_producer.dm'


def projected_wait():
    text = SOURCE.read_text(encoding='utf-8').replace('\r\n', '\n')
    body = text[text.index('/proc/subtile_pull_wait_until(due)\n'):]
    lines = [line for line in body.split('\n\n')[0].splitlines()[1:]]
    expected = ['\twhile (world.time < due)',
                '\t\tsleep(world.tick_lag * max(1, -round(0.001 - (due - world.time) / world.tick_lag)))']
    if lines != expected:
        raise ValueError('Unprojected wait helper: ' + repr(lines))

    def wait(world, due):
        # DM round(x) with one argument floors.
        while world['time'] < due:
            world['sleep'](world['tick_lag'] * max(1, -math.floor(0.001 - (due - world['time']) / world['tick_lag'])))
    return wait


def engine(tick_lag, start, early):
    """Whole-tick scheduler. early=True rounds a fractional sleep down (worst case)."""
    world = {'time': start, 'tick_lag': tick_lag, 'sleeps': 0}

    def sleep(amount):
        ticks = amount / tick_lag
        ticks = math.floor(ticks + 1e-9) if early else math.ceil(ticks - 1e-9)
        world['time'] = round(world['time'] + max(1, ticks) * tick_lag, 9)
        world['sleeps'] += 1
    world['sleep'] = sleep
    return world


class PulseTiming(unittest.TestCase):
    def test_every_pulse_wakes_on_or_after_due_and_at_most_one_tick_late(self):
        wait = projected_wait()
        cases = 0
        for tick_lag in (0.25, 0.4, 0.5, 1.0, 1.25):
            for interval_ticks in range(1, 41):
                for early in (True, False):
                    world = engine(tick_lag, 100.0, early)
                    start, deadline = world['time'], world['time'] + interval_ticks * tick_lag
                    for i in range(1, 17):
                        due = start + (i - 1) * (deadline - start) / 16
                        wait(world, due)
                        self.assertGreaterEqual(world['time'], due, (tick_lag, interval_ticks, i))
                        self.assertLess(world['time'] - due, tick_lag + 1e-9, (tick_lag, interval_ticks, i))
                    cases += 1
        self.assertEqual(cases, 5 * 40 * 2)

    def test_old_fractional_sleep_could_wake_before_due(self):
        # Control: the previous single sleep(due - world.time) under round-down.
        world = engine(0.5, 100.0, True)
        due = 100.0 + 0.7
        world['sleep'](due - world['time'])
        self.assertLess(world['time'], due)

    def test_perform_intent_uses_the_helper(self):
        text = SOURCE.read_text(encoding='utf-8')
        perform = text[text.index('/datum/subtile_pull_pair/proc/perform_intent()'):text.index('// Sleep whole ticks')]
        self.assertIn('subtile_pull_wait_until(due)', perform)
        self.assertNotIn('sleep(due', perform)


if __name__ == '__main__':
    unittest.main(verbosity=2)
