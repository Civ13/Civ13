"""Source-bound elapsed-clock model, not native BYOND execution."""
from pathlib import Path
import re
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/processes/time_track.dm').read_text()


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

    def test_load_suppression_precedes_sampling_and_is_reserved_at_admission(self):
        fire = SOURCE.split('/process/time_track/fire()', 1)[1].split('/process/time_track/proc/', 1)[0]
        self.assertTrue(fire.startswith('\n\tif (persistence_active_operation?.kind == "load")\n'
                                       '\t\tignore_load_dilation()\n\t\treturn\n'))
        self.assertLess(fire.index('ignore_load_dilation()'), fire.index('averages += dilation'))
        self.assertLess(fire.index('ignore_load_dilation()'), fire.index('check_lag_capture()'))
        ops = (ROOT / 'code/modules/persistence/functions.dm').read_text()
        begin = ops.split('/proc/begin_persistence_operation(', 1)[1]
        expected = ('persistence_active_operation = operation\n'
                    '\t// A whole load can occur between samples, so reset the monitor at admission.\n'
                    '\tif(kind == "load" && processes && processes.time_track)\n\t\tprocesses.time_track.ignore_load_dilation()')
        self.assertIn(expected, begin)

    def test_interrupted_automatic_capture_is_discarded_without_stopping_manual_profiler(self):
        body = SOURCE.split('/process/time_track/proc/ignore_load_dilation()\n', 1)[1].split('\n\n', 1)[0]
        lines = []
        for raw in body.splitlines():
            line = raw.strip().replace('&&', 'and').replace('!profile_dump_running', 'not profile_dump_running')
            line = re.sub(r'\bTRUE\b', 'True', line)
            line = re.sub(r'\bFALSE\b', 'False', line)
            if line.startswith('if ('):
                line += ':'
            lines.append('    ' * (len(raw) - len(raw.lstrip('\t')) - 1) + line)
        code = compile('\n'.join(lines), 'ignore_load_dilation', 'exec')
        for due, owner, manual, stops in ((100, True, False, [1]), (100, True, True, []),
                                         (100, False, True, []), (0, True, False, [])):
            calls = []
            env = dict(first_run=False, dilation=480, lag_seconds=2, lag_capture_due=due,
                       lag_capture_started_profiler=owner, profile_dump_running=manual,
                       world=SimpleNamespace(Profile=calls.append), PROFILE_STOP=1)
            exec(code, {'__builtins__': {}}, env)
            self.assertEqual(calls, stops)
            self.assertEqual([env[k] for k in ('first_run', 'dilation', 'lag_seconds', 'lag_capture_due',
                                                'lag_capture_started_profiler')], [True, 0, 0, 0, False])

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
