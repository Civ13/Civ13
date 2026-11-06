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
        self.assertTrue(wait_group.failed(region('stopped', 'compiling', error='dm exited 1')))
        self.assertFalse(wait_group.failed(region('awake', 'saving', listening=True)))

    def test_main_returns_on_reaching_failing_and_timing_out(self):
        done = {'gaia': region('stopped', 'done'), 'railyard': region('stopped', 'done')}
        with mock.patch.object(wait_group, 'status', return_value=done):
            self.assertEqual(wait_group.main(['--config', 'g.json', '--until', 'stopped']), 0)
        broken = {'gaia': region('stopped', 'failed', error='save failed')}
        with mock.patch.object(wait_group, 'status', return_value=broken):
            self.assertEqual(wait_group.main(['--config', 'g.json', '--until', 'stopped']), 1)
        saving = {'gaia': region('awake', 'saving', listening=True)}
        with mock.patch.object(wait_group, 'status', return_value=saving), \
                mock.patch.object(wait_group.time, 'sleep'), \
                mock.patch.object(wait_group.time, 'monotonic', side_effect=[0, 0, 10]):
            self.assertEqual(wait_group.main(['--config', 'g.json', '--until', 'stopped', '--timeout', '5']), 2)


if __name__ == '__main__':
    unittest.main()
