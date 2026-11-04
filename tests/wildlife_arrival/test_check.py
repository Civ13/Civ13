"""Offline tests for the arrival checker; the native run is run.py."""
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('arrival_run', Path(__file__).with_name('run.py'))
run = importlib.util.module_from_spec(spec)
spec.loader.exec_module(run)


def row(subtile, arrived, entries, lag=3, moved=-1):
    return {'subtile': subtile, 'lag': lag, 'move_target_at': moved, 'arrived': arrived, 'entries': entries, 'tick_lag': 0.4}


LEGACY = [2.8 * i for i in range(1, 9)]


class ArrivalCheck(unittest.TestCase):
    def test_fixed_walker_within_one_tick_passes(self):
        self.assertEqual([], run.check([row(0, 22.4, LEGACY), row(1, 22.8, [x + 0.4 for x in LEGACY])]))

    def test_pre_fix_measurement_fails(self):
        # Measured on master before the fix: first step one interval late, 3.2 ds steps.
        before = [6.8 + 3.2 * i for i in range(8)]
        failures = run.check([row(0, 22.4, LEGACY), row(1, 29.2, before)])
        self.assertTrue(any('after legacy' in f for f in failures))
        self.assertTrue(any('mean step' in f for f in failures))

    def test_missing_arrival_and_probe_error_fail(self):
        self.assertTrue(run.check([row(0, 22.4, LEGACY), row(1, -1, LEGACY)]))
        self.assertTrue(run.check([{'error': 'boom'}]))
        self.assertTrue(run.check([]))

    def test_reaction_after_arrival_allows_one_glide_only(self):
        legacy = [0.8 * i for i in range(1, 9)] + [10.4, 11.2]
        glide = [x + 0.4 for x in legacy[:8]] + [11.6, 12.4]
        self.assertEqual([], run.check([row(0, 11.2, legacy, 1, 10), row(1, 12.4, glide, 1, 10)]))
        slow = glide[:8] + [12.4, 13.2]
        self.assertTrue(run.check([row(0, 11.2, legacy, 1, 10), row(1, 13.2, slow, 1, 10)]))
        # A target that moves while the walker is still travelling gets no glide allowance.
        self.assertTrue(run.check([row(0, 28.0, LEGACY + [25.2, 28.0], 3, 10), row(1, 31.2, LEGACY + [28.4, 31.2], 3, 10)]))

    def test_extra_step_fails(self):
        self.assertTrue(run.check([row(0, 22.4, LEGACY), row(1, 22.4, LEGACY + [25.2])]))


if __name__ == '__main__':
    unittest.main()
