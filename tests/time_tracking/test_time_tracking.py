"""Source-bound elapsed-clock model, not native BYOND execution."""
from pathlib import Path
import re
import unittest

SOURCE = (Path(__file__).resolve().parents[2] / 'code/processes/time_track.dm').read_text()


def sample(last_real, now_real, last_game, now_game):
    expression = re.search(r'dilation = game_elapsed > 0 \? (.+) : 0', SOURCE)[1]
    real_elapsed = now_real - last_real
    if real_elapsed < 0:
        real_elapsed += 864000
    game_elapsed = now_game - last_game
    return eval(expression, {'__builtins__': {}, 'max': max},
                {'real_elapsed': real_elapsed, 'game_elapsed': game_elapsed}) if game_elapsed > 0 else 0


class TimeTracking(unittest.TestCase):
    def test_production_clock_contract(self):
        fire = SOURCE.split('/process/time_track/fire()')[1].split('/process/time_track/proc/')[0]
        for text in ('var/current_realtime = world.timeofday',
                     'var/current_byondtime = world.time',
                     'var/real_elapsed = current_realtime - last_tick_realtime',
                     'real_elapsed += 864000',
                     'var/game_elapsed = current_byondtime - last_tick_byond_time',
                     'last_tick_realtime = current_realtime',
                     'last_tick_byond_time = current_byondtime', 'check_lag_capture()'):
            self.assertIn(text, fire)
        self.assertNotIn('world.tick_lag', fire)
        self.assertNotIn('last_tick_tickcount', SOURCE)
        self.assertNotIn('864000 + schedule_interval', fire)

    def test_no_lag_and_double_wall_time(self):
        self.assertEqual(sample(100, 110, 1000, 1010), 0)
        self.assertEqual(sample(100, 120, 1000, 1010), 100)

    def test_midnight_keeps_actual_elapsed(self):
        self.assertEqual(sample(863995, 5, 1000, 1010), 0)
        self.assertEqual(sample(863995, 25, 1000, 1010), 200)

    def test_zero_game_progress_and_clock_jitter(self):
        self.assertEqual(sample(100, 110, 1000, 1000), 0)
        self.assertEqual(sample(100, 109, 1000, 1010), 0)

    def test_fps_changes_do_not_change_elapsed_ratio(self):
        for old_lag, new_lag in ((1, .5), (.5, 1), (1, 1)):
            with self.subTest(old_lag=old_lag, new_lag=new_lag):
                self.assertEqual(sample(100, 120, 10000, 10010), 100)
                # Old cumulative-tick formula: changing tick_lag corrupts the denominator.
                old = ((20 - 10) / new_lag) / (10010 / new_lag - 10000 / old_lag) * 100
                if old_lag != new_lag:
                    self.assertNotEqual(old, 100)

    def test_old_midnight_substitution_is_detected(self):
        old_elapsed = 864000 + 10 - 863995
        self.assertNotEqual(max(0, (old_elapsed - 10) / 10) * 100,
                            sample(863995, 5, 1000, 1010))


if __name__ == '__main__':
    unittest.main()
