"""Four-hour checkpoint for occupied persistent worlds (Val, 2026-11-21).

The persistence loop keeps every other automatic save out of active play, but
calls persistence_occupied_checkpoint() so the last completed save is never
more than about four hours old. Source-contract checks plus a Python
projection of the due/backoff decision.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/modules/persistence/occupied_checkpoint.dm').read_text(encoding='utf-8')
WORLD = (ROOT / 'code/world.dm').read_text(encoding='utf-8')


def proc_body(text, signature):
    start = text.index(signature)
    rest = text[start + len(signature):]
    end = re.search(r'\n/proc/|\n/[a-z_]+/proc/|\nvar/|\n#undef', rest)
    return rest[:end.start()] if end else rest


def define(name):
    return int(re.search(r'#define %s (\d+)' % name, SOURCE).group(1))


TARGET = define('PERSISTENCE_CHECKPOINT_TARGET')
LEAD = define('PERSISTENCE_CHECKPOINT_LEAD')
STAGGER = define('PERSISTENCE_CHECKPOINT_STAGGER')
BACKOFF = define('PERSISTENCE_CHECKPOINT_BACKOFF')


def due(port):
    return TARGET - LEAD - (max(0, port) % 10) * STAGGER


def decide(age, port, now, retry_at=0, running=False, blocked=False):
    """Projection of persistence_occupied_checkpoint()."""
    if running or now < retry_at:
        return False
    if blocked:
        return False
    return age >= due(port)


class Contract(unittest.TestCase):
    def test_included_in_dme(self):
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
        self.assertIn('#include "code\\modules\\persistence\\occupied_checkpoint.dm"', dme)

    def test_loop_calls_checkpoint_only_while_occupied(self):
        loop = proc_body(WORLD, '/proc/start_persistence_loop()')
        players = loop.index('if (persistence_active_players())')
        empty = loop.index('\t\t\t\telse\n', players)
        self.assertIn('persistence_occupied_checkpoint()', loop[players:empty])
        self.assertEqual(loop.count('persistence_occupied_checkpoint()'), 1)

    def test_target_is_four_hours_and_starts_early(self):
        self.assertEqual(TARGET, 4 * 60 * 60 * 10)
        latest = due(9)
        self.assertGreaterEqual(TARGET - latest, 20 * 600)
        self.assertLessEqual(TARGET - latest, 30 * 600)

    def test_age_comes_from_completed_save_stamp(self):
        body = proc_body(SOURCE, '/proc/persistence_checkpoint_age(')
        self.assertIn('persistence_last_save_refresh()', body)
        self.assertIn('valid_persistence_save_stamp(stamp)', body)
        self.assertIn('wall_clock_elapsed(stamp["timeofday"], stamp["realtime"]', body)

    def test_respects_existing_holds(self):
        body = proc_body(SOURCE, '/proc/persistence_checkpoint_block_reason()')
        for guard in ('config.skip_persistence_saving', 'map.persistence', 'GAME_STATE_PLAYING',
                      'persistence_restart.startup_hold', 'persistence_restart.busy',
                      'persistence_reboot_scheduled', 'persistence_admission_blocked()',
                      'persistence_save_active()'):
            self.assertIn(guard, body)

    def test_save_only_never_restarts(self):
        self.assertNotIn('Reboot', SOURCE)
        self.assertNotIn('planned_shutdown', SOURCE)
        run = proc_body(SOURCE, '/proc/persistence_run_checkpoint()')
        self.assertEqual(run.count('ticker.savemap()'), 1)

    def test_warning_precedes_save_and_rechecks(self):
        run = proc_body(SOURCE, '/proc/persistence_run_checkpoint()')
        warn = run.index('sleep(PERSISTENCE_CHECKPOINT_WARNING)')
        recheck = run.index('persistence_checkpoint_block_reason()', warn)
        fresh = run.index('persistence_checkpoint_age() < persistence_checkpoint_due()', warn)
        save = run.index('ticker.savemap()')
        self.assertLess(warn, recheck)
        self.assertLess(fresh, save)

    def test_failure_backs_off_without_moving_deadline(self):
        run = proc_body(SOURCE, '/proc/persistence_run_checkpoint()')
        failed = run[run.index('\telse\n'):]
        self.assertIn('persistence_checkpoint_retry_at = world.time + PERSISTENCE_CHECKPOINT_BACKOFF', failed)
        self.assertNotIn('persistence_checkpoint_baseline', run)
        self.assertNotIn('persistence_last_save', run)


class Projection(unittest.TestCase):
    def test_boundaries(self):
        for port in (0, 1, 1714, 5009, 65535):
            d = due(port)
            self.assertFalse(decide(d - 1, port, now=0))
            self.assertTrue(decide(d, port, now=0))
            self.assertLess(d, TARGET)

    def test_regions_are_staggered(self):
        self.assertEqual(len({due(p) for p in range(1710, 1720)}), 10)

    def test_backoff_and_running(self):
        d = due(1714)
        self.assertFalse(decide(d + 1, 1714, now=10, retry_at=10 + BACKOFF))
        self.assertTrue(decide(d + 1, 1714, now=10 + BACKOFF, retry_at=10 + BACKOFF))
        self.assertFalse(decide(TARGET * 2, 1714, now=0, running=True))
        self.assertFalse(decide(TARGET * 2, 1714, now=0, blocked=True))

    def test_negative_control_wrong_target_detected(self):
        # A loop that waited the full six-hour periodic interval would miss the target.
        self.assertGreater(216000 - LEAD, TARGET)


if __name__ == '__main__':
    unittest.main()
