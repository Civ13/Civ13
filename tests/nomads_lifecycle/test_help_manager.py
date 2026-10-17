import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch

SCRIPTS = Path(__file__).resolve().parents[2] / 'scripts/nomads-lifecycle'
sys.path.insert(0, str(SCRIPTS))
spec = importlib.util.spec_from_file_location('help_manager', SCRIPTS / 'help_manager.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class HelpManagerTests(unittest.TestCase):
    def setUp(self):
        self.storage = tempfile.TemporaryDirectory()
        self.root = Path(self.storage.name)
        self.run = self.root / 'runs/one'
        (self.run / 'SQL/player-help').mkdir(parents=True)
        self.files = [self.root / name for name in ('python.exe', 'bridge.py', 'config.json')]
        for path in self.files:
            path.touch()
        self.host = {'pid': 100, 'creation_filetime': 200, 'workdir': str(self.run)}
        self.state()
        self.identities = {100: 200, 101: 201}
        self.child = Mock(pid=101)
        self.child.poll.return_value = None
        self.spawn = Mock(return_value=self.child)
        self.now = 0
        self.manager = self.make()

    def make(self):
        return module.HelpManager(self.root, *self.files,
            identity=lambda pid: self.identities.get(pid), spawn=self.spawn,
            clock=lambda: self.now)

    def state(self, phase='ready'):
        (self.root / 'state.json').write_text(json.dumps({'phase': phase, 'host': self.host}))

    def tearDown(self):
        if self.manager.log:
            self.manager.log.close()
        self.storage.cleanup()

    def test_one_worker_and_fixed_arguments(self):
        self.assertEqual(self.manager.tick(), 'running')
        self.assertEqual(self.manager.tick(), 'running')
        self.spawn.assert_called_once()
        argv = self.spawn.call_args.args[0]
        self.assertEqual(argv[:6], [str(self.files[0]), str(self.files[1]),
            '--game-root', str(self.run), '--config', str(self.files[2])])
        self.assertEqual(argv[6], '--stop-file')
        self.assertEqual(json.loads(self.manager.receipt.read_text())['worker']['creation'], 201)

    def test_external_worker_never_adopted_or_removed(self):
        lock = self.run / 'SQL/player-help/worker.lock'
        lock.mkdir()
        (lock / 'pid').write_text('777')
        self.assertEqual(self.manager.tick(), 'external_worker')
        self.assertEqual((lock / 'pid').read_text(), '777')
        self.assertIsNone(self.manager.child)
        self.spawn.assert_not_called()

    def test_recycled_or_missing_game_identity(self):
        for created in (None, 999):
            self.identities[100] = created
            self.assertEqual(self.manager.tick(), 'waiting_for_ready_game')
        self.spawn.assert_not_called()

    def test_external_old_run_blocks_new_run_and_manager_restart(self):
        lock = self.run / 'SQL/player-help/worker.lock'
        lock.mkdir()
        (lock / 'pid').write_text('777')
        self.identities[777] = 888
        self.assertEqual(self.manager.tick(), 'external_worker')
        new_run = self.root / 'runs/two'
        new_run.mkdir()
        self.host['workdir'] = str(new_run)
        self.state()
        self.manager = self.make()
        self.assertEqual(self.manager.tick(), 'external_worker')
        (lock / 'pid').unlink()
        lock.rmdir()
        self.assertEqual(self.manager.tick(), 'external_worker')
        self.identities[777] = None
        self.assertEqual(self.manager.tick(), 'running')
        self.spawn.assert_called_once()

    def test_nonready_and_outside_run_never_launch(self):
        self.state('starting')
        self.assertEqual(self.manager.tick(), 'waiting_for_ready_game')
        self.host['workdir'] = str(self.root)
        self.state()
        self.assertEqual(self.manager.tick(), 'waiting_for_ready_game')
        self.spawn.assert_not_called()

    def test_missing_optional_file_does_not_touch_game_state(self):
        before = (self.root / 'state.json').read_bytes()
        self.files[2].unlink()
        self.assertEqual(self.manager.tick(), 'optional_files_unavailable')
        self.assertEqual((self.root / 'state.json').read_bytes(), before)
        self.spawn.assert_not_called()

    def test_finite_attempts_and_backoff_survive_manager_restart(self):
        self.spawn.side_effect = OSError('unavailable')
        self.assertEqual(self.manager.tick(), 'spawn_failed')
        self.assertEqual(self.manager.tick(), 'backoff')
        self.now = 10
        self.assertEqual(self.manager.tick(), 'spawn_failed')
        self.now = 40
        self.assertEqual(self.manager.tick(), 'spawn_failed')
        self.manager = self.make()
        self.now = 1000
        self.assertEqual(self.manager.tick(), 'attempts_exhausted')
        self.assertEqual(self.spawn.call_count, 3)

    def test_restart_with_worker_or_spawn_intent_refuses_adoption(self):
        for worker in ({'intent': 'pending'}, {'pid': 101, 'creation': 201}):
            self.manager.report('starting', worker)
            restarted = self.make()
            before = restarted.receipt.read_bytes()
            self.assertEqual(restarted.tick(), 'ownership_uncertain')
            self.assertEqual(restarted.receipt.read_bytes(), before)
        self.spawn.assert_not_called()

    def test_run_transition_requests_graceful_stop_then_waits_for_exit(self):
        self.manager.tick()
        old_stop = Path(self.manager.record['stop_file'])
        new_run = self.root / 'runs/two'
        (new_run / 'SQL/player-help').mkdir(parents=True)
        self.host['workdir'] = str(new_run)
        self.state()
        self.assertEqual(self.manager.tick(), 'stopping')
        self.assertTrue(old_stop.exists())
        self.now = 151
        self.assertEqual(self.manager.tick(), 'stop_timeout')
        self.spawn.assert_called_once()
        self.child.kill.assert_not_called()
        self.child.terminate.assert_not_called()
        self.child.poll.return_value = 0
        self.assertEqual(self.manager.tick(), 'worker_exited')
        self.child.poll.return_value = None
        self.assertEqual(self.manager.tick(), 'running')
        self.assertEqual(self.spawn.call_count, 2)

    def test_crash_leaves_lock_for_operator(self):
        self.manager.tick()
        lock = self.run / 'SQL/player-help/worker.lock'
        lock.mkdir()
        self.child.poll.return_value = 1
        self.assertEqual(self.manager.tick(), 'worker_exited')
        self.now = 100
        self.assertEqual(self.manager.tick(), 'external_worker')
        self.assertTrue(lock.exists())
        self.spawn.assert_called_once()

    def test_child_identity_mismatch_never_signals(self):
        self.manager.tick()
        self.identities[101] = 999
        self.assertEqual(self.manager.tick(), 'ownership_uncertain')
        self.assertFalse(Path(self.manager.record['stop_file']).exists())
        self.child.terminate.assert_not_called()

    def test_manager_lock_rejects_second_owner(self):
        with module.exclusive_lock(self.root / 'help-manager.lock'):
            with self.assertRaises(OSError):
                with module.exclusive_lock(self.root / 'help-manager.lock'):
                    self.fail('Second owner acquired lock')

    def test_entrypoint_waits_for_optional_files_then_launches_once(self):
        self.files[1].unlink()
        self.files[2].unlink()
        original_manager = module.HelpManager
        observed = []
        def construct(*args, **kwargs):
            self.manager = original_manager(*args, **kwargs,
                identity=lambda pid: self.identities.get(pid), spawn=self.spawn,
                clock=lambda: self.now)
            original_tick = self.manager.tick
            def tick():
                result = original_tick()
                observed.append(result)
                return result
            self.manager.tick = tick
            return self.manager
        def advance(_):
            if len(observed) == 1:
                self.files[1].touch()
                self.files[2].touch()
            else:
                raise InterruptedError('End bounded entrypoint probe')
        argv = ['help_manager', '--root', str(self.root), '--python', str(self.files[0]),
                '--bridge', str(self.files[1]), '--config', str(self.files[2])]
        with patch.object(sys, 'argv', argv), patch.object(module, 'HelpManager', construct):
            with patch.object(module.signal, 'signal'), patch.object(module.time, 'sleep', advance):
                with self.assertRaises(InterruptedError):
                    module.main()
        self.assertEqual(observed, ['optional_files_unavailable', 'running'])
        self.spawn.assert_called_once()


if __name__ == '__main__':
    unittest.main()
