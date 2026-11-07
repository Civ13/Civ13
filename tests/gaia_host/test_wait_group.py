"""Offline tests for scripts/windows/host/wait_group.py (the waits deploy.bat uses)."""
import importlib.util
from pathlib import Path
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('wait_group', ROOT / 'scripts/windows/host/wait_group.py')
wait_group = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(wait_group)


def region(state, phase, action='stop', listening=False, ready=None, busy=False, error=None):
    entry = {'state': state, 'listening': listening, 'busy': busy,
             'operation': {'action': action, 'phase': phase, 'error': error}}
    if ready is not None:
        entry['world'] = {'ready': ready}
    return entry


class WaitGroupTests(unittest.TestCase):
    def test_stopped_needs_every_region_down_and_idle(self):
        self.assertTrue(wait_group.reached(region('stopped', 'done'), 'stopped'))
        self.assertTrue(wait_group.reached(region('cold', 'done'), 'stopped'))
        self.assertFalse(wait_group.reached(region('awake', 'saving', listening=True), 'stopped'))
        self.assertFalse(wait_group.reached(region('stopped', 'done', busy=True), 'stopped'))

    def test_compiled_only_after_an_update(self):
        self.assertTrue(wait_group.reached(region('stopped', 'compiled', action='update'), 'compiled'))
        self.assertFalse(wait_group.reached(region('stopped', 'compiling', action='update'), 'compiled'))
        self.assertTrue(wait_group.reached(region('stopped', 'done', action='update'), 'compiled'))
        self.assertFalse(wait_group.reached(region('stopped', 'done', action='stop'), 'compiled'))

    def test_awake_needs_a_ready_world(self):
        self.assertTrue(wait_group.reached(region('awake', 'done', 'start', True, ready=1), 'awake'))
        self.assertFalse(wait_group.reached(region('awake', 'loading', 'start', True, ready=0), 'awake'))

    def test_errors_and_failures_end_the_wait(self):
        self.assertTrue(wait_group.failed(region('stopped', 'failed')))
        self.assertEqual(wait_group.failed(region('stopped', 'compiling', error='dm exited 1')), 'dm exited 1')
        self.assertIsNone(wait_group.failed(region('awake', 'saving', listening=True, busy=True), 'stopped'))

    def test_staged_waits_for_the_build_beside_the_running_world(self):
        running = region('awake', 'done', 'start', True, ready=1)
        self.assertFalse(wait_group.reached(running, 'staged'))
        self.assertIn('no build', wait_group.failed(running, 'staged'))
        for phase in ('accepted', 'waiting for another region\'s compile', 'preparing', 'compiling'):
            building = dict(running, stage={'phase': phase})
            self.assertFalse(wait_group.reached(building, 'staged'))
            self.assertIsNone(wait_group.failed(building, 'staged'))
        self.assertTrue(wait_group.reached(dict(running, stage={'phase': 'ready'}), 'staged'))
        self.assertTrue(wait_group.reached(dict(running, stage={'phase': 'current'}), 'staged'))
        broken = dict(running, stage={'phase': 'failed', 'error': 'compile failed: 1 error'})
        self.assertEqual(wait_group.failed(broken, 'staged'), 'compile failed: 1 error')
        # A world whose own last action failed can still stage.
        old_failure = dict(region('stopped', 'failed', error='old'), stage={'phase': 'compiling'})
        self.assertIsNone(wait_group.failed(old_failure, 'staged'))
        with mock.patch.object(wait_group, 'status', return_value={'gaia': broken}):
            self.assertEqual(wait_group.main(['--config', 'g.json', '--until', 'staged']), 1)

    def test_handed_over_counts_a_region_already_on_the_latest_build(self):
        # Its handover is refused ("no staged build"), so the last action is still its start.
        current = dict(region('awake', 'done', 'start', True, ready=1), stage={'phase': 'current'})
        self.assertTrue(wait_group.reached(current, 'handed-over'))
        refused = dict(region('awake', 'done', 'start', True, ready=1), stage={'phase': 'ready'})
        self.assertFalse(wait_group.reached(refused, 'handed-over'))
        self.assertIn('refused', wait_group.failed(refused, 'handed-over'))
        handing = dict(region('awake', 'saving', 'handover', True, busy=True), stage={'phase': 'ready'})
        self.assertFalse(wait_group.reached(handing, 'handed-over'))
        self.assertIsNone(wait_group.failed(handing, 'handed-over'))
        done = dict(region('awake', 'done', 'handover', True, ready=1), stage={'phase': 'ready'})
        self.assertTrue(wait_group.reached(done, 'handed-over'))
        with mock.patch.object(wait_group, 'status', return_value={'gaia': done, 'railyard': current}):
            self.assertEqual(wait_group.main(['--config', 'g.json', '--until', 'handed-over']), 0)

    def test_a_running_region_with_no_save_under_way_never_stops(self):
        # Its stop was refused (busy or not ready world): no lock, still listening.
        refused = region('awake', 'done', action='start', listening=True, ready=1)
        self.assertIn('not saving', wait_group.failed(refused, 'stopped'))
        self.assertIsNone(wait_group.failed(refused, 'awake'))
        gave_up = region('awake', 'failed', listening=True, error='the world reported a save error: disk full')
        self.assertEqual(wait_group.failed(gave_up, 'stopped'), 'the world reported a save error: disk full')

    def test_main_returns_on_reaching_failing_and_timing_out(self):
        done = {'gaia': region('stopped', 'done'), 'railyard': region('stopped', 'done')}
        with mock.patch.object(wait_group, 'status', return_value=done):
            self.assertEqual(wait_group.main(['--config', 'g.json', '--until', 'stopped']), 0)
        # Down is down: a stop that failed after the world went down (force-stopped mid-save)
        # still reaches stopped; the start step checks the save.
        down = {'gaia': region('stopped', 'failed', error='save failed')}
        with mock.patch.object(wait_group, 'status', return_value=down):
            self.assertEqual(wait_group.main(['--config', 'g.json', '--until', 'stopped']), 0)
        broken = {'gaia': region('awake', 'failed', listening=True, error='save failed'),
                  'railyard': region('stopped', 'done')}
        with mock.patch.object(wait_group, 'status', return_value=broken):
            self.assertEqual(wait_group.main(['--config', 'g.json', '--until', 'stopped']), 1)
        # One region only (deploy.bat gaia): the others may keep running and saving nothing.
        mixed = {'gaia': region('stopped', 'done'), 'railyard': region('awake', 'done', 'start', True, ready=1)}
        with mock.patch.object(wait_group, 'status', return_value=mixed):
            self.assertEqual(wait_group.main(['--config', 'g.json', '--until', 'stopped', '--region', 'gaia']), 0)
            self.assertEqual(wait_group.main(['--config', 'g.json', '--until', 'stopped', '--region', 'gaia', '--region', 'railyard']), 1)
            self.assertEqual(wait_group.main(['--config', 'g.json', '--until', 'stopped', '--region', 'moon']), 1)
        compile_failed = {'gaia': region('stopped', 'failed', action='update', error='compile failed')}
        with mock.patch.object(wait_group, 'status', return_value=compile_failed):
            self.assertEqual(wait_group.main(['--config', 'g.json', '--until', 'compiled']), 1)
        saving = {'gaia': region('awake', 'saving', listening=True, busy=True)}
        with mock.patch.object(wait_group, 'status', return_value=saving), \
                mock.patch.object(wait_group.time, 'sleep'), \
                mock.patch.object(wait_group.time, 'monotonic', side_effect=[0, 0, 10]):
            self.assertEqual(wait_group.main(['--config', 'g.json', '--until', 'stopped', '--timeout', '5']), 2)


if __name__ == '__main__':
    unittest.main()
