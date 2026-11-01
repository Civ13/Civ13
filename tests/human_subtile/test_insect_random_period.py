"""Offline proposal contracts; these do not simulate BYOND or prove parity."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
HOSTILE = ROOT / 'code/game/mob/living/simple_animal/hostile'
MOVEMENT = ROOT / 'code/game/mob/living/simple_animal/subtile_movement.dm'
ANIMALS = ('mosquitoes', 'vampirebat')
ADDITION = '''\t// The lag-4 random walker was observed at 4 ds between starts only at
\t// 0.5 ds ticks. Keep this calibration separate from the pulse duration;
\t// other tick rates and producers need their own native measurements.
\tif (mode == "random" && world.tick_lag == 0.5 && interval == npc_subtile_native_interval(4))
\t\treturn 4
'''


def period(mode, tick, lag, candidate=True):
    interval = lag * tick
    if mode == 'towards' and lag == 3:
        return 2 * interval
    if candidate and mode == 'random' and tick == .5 and lag == 4:
        return 4
    return interval


def observed_model(start, count, cycle, elapsed):
    starts = [start]
    for _ in range(count - 1):
        starts.append(max(starts[-1] + cycle, starts[-1] + elapsed))
    return starts


class RandomPeriodContracts(unittest.TestCase):
    def test_two_calibrated_species_have_narrow_override(self):
        for name in ANIMALS:
            candidate = (HOSTILE / (name + '.dm')).read_text(encoding='utf-8')
            self.assertEqual(candidate.count(ADDITION), 1)
            override = candidate.split('/npc_subtile_wild_period(mode, interval)', 1)[1].split('/Life()', 1)[0]
            self.assertIn(ADDITION, override)
            self.assertIn('return ..()', override)

    def test_original_trace_is_a_negative_control(self):
        expected = [56, 60, 64]
        previous = observed_model(56, 4, period('random', .5, 4, False), 2.5)
        self.assertEqual(previous, [56, 58.5, 61, 63.5])
        self.assertNotEqual(previous[:3], expected)
        self.assertEqual(observed_model(56, 3, period('random', .5, 4), 2.5), expected)

    def test_period_is_distinct_from_pulse_transit(self):
        self.assertEqual(4 * .5, 2)  # native lag conversion, unchanged
        self.assertEqual(period('random', .5, 4), 4)  # candidate start period
        self.assertEqual(observed_model(56, 3, 4, 4.5), [56, 60.5, 65])

    def test_other_modes_lags_and_tick_rates_are_unchanged(self):
        for mode in ('random', 'towards', 'away', 'path', 'direction'):
            for tick in (.5, 1, 2):
                for lag in (2, 3, 4, 5):
                    if (mode, tick, lag) != ('random', .5, 4):
                        self.assertEqual(period(mode, tick, lag), period(mode, tick, lag, False))
        self.assertEqual(period('towards', .5, 3), 3)

    def test_existing_owner_and_deadline_logic_stays_in_control(self):
        text = MOVEMENT.read_text(encoding='utf-8')
        producer = text.split('/proc/npc_subtile_species_walk(', 1)[1].split('/proc/npc_subtile_start_wild_walk(', 1)[0]
        self.assertIn('npc_subtile_native_interval(lag)', producer)
        self.assertIn('walk_rand(src, lag)', producer)
        start = text.split('/proc/npc_subtile_start_wild_walk(', 1)[1].split('/mob/living/simple_animal/proc/npc_subtile_stop_wild_walk', 1)[0]
        same = start.split('if (npc_subtile_can_defer())', 1)[0]
        self.assertIn('W.valid() && W.mode == mode', same)
        self.assertNotIn('W.due =', same)
        loop = text.split('/datum/npc_subtile_wild_walk/proc/perform_loop()', 1)[1].split('/datum/npc_subtile_recovery', 1)[0]
        self.assertIn('actor.ai_step_wait(next, interval, src)', loop)
        self.assertIn('due = max(started + period, world.time)', loop)
        self.assertNotIn('adjustBruteLoss', loop)


if __name__ == '__main__':
    unittest.main()
