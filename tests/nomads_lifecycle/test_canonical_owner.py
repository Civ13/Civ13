import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import Mock, patch

SOURCE = Path(__file__).resolve().parents[2] / 'scripts/nomads-lifecycle'
sys.path.insert(0, str(SOURCE))
import canonical_owner as owner


class CanonicalOwnerTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.config = {'canonical_owner_enabled': True, 'canonical_update_enabled': True,
                       'canonical_bot_enabled': False, 'canonical_initial_start_enabled': True,
                       'canonical_initial_generation': 'round-v2:' + 'a' * 32,
                       'canonical_owner_revision': 'b' * 40, 'canonical_owner_dmb_sha256': 'c' * 64,
                       'canonical_owner_rsc_sha256': 'd' * 64, 'map': 'NOMADS_GAIA'}
        self.supervisor = Mock()
        self.supervisor.child = None
        self.factory = Mock(return_value=self.supervisor)
        self.updater = Mock()
        self.updater_factory = Mock(return_value=self.updater)
        self.coordinator = Mock()
        self.coordinator_factory = Mock(return_value=self.coordinator)
        self.cancelled = False
        self.sleep = Mock()
        self.configuration = patch.object(owner.canonical, 'configuration', return_value=(self.root, self.root))
        self.configuration.start()
        self.addCleanup(self.configuration.stop)

    def run_owner(self):
        return owner.run(self.config, cancelled=lambda: self.cancelled, sleep=self.sleep,
                         supervisor_factory=self.factory, updater_factory=self.updater_factory,
                         coordinator_factory=self.coordinator_factory)

    def test_disabled_or_unpinned_config_never_constructs_owner(self):
        for field, value in [('canonical_owner_enabled', False), ('canonical_update_enabled', False),
                             ('canonical_bot_enabled', True), ('canonical_bot_enabled', None),
                             ('canonical_initial_start_enabled', False), ('canonical_owner_revision', 'bad'),
                             ('canonical_owner_dmb_sha256', ''), ('canonical_initial_generation', 'bad')]:
            changed = dict(self.config, **{field: value})
            with self.subTest(field=field), self.assertRaises(RuntimeError):
                owner.run(changed, cancelled=lambda: False, supervisor_factory=self.factory)
        self.factory.assert_not_called()
        self.assertEqual(list(self.root.iterdir()), [])

    def test_existing_records_refuse_before_owner_or_mutation(self):
        for name in ('state.json', 'HALTED.json', 'update-state.json', 'admin-maintenance',
                     'bot-control', 'updates', 'backups'):
            path = self.root / name
            if '.' in name:
                path.write_text('preserve')
            else:
                path.mkdir()
                (path / 'evidence').write_text('preserve')
            with self.subTest(name=name), self.assertRaisesRegex(RuntimeError, 'reconciliation'):
                self.run_owner()
            self.factory.assert_not_called()
            if path.is_dir():
                (path / 'evidence').unlink()
                path.rmdir()
            else:
                path.unlink()

    def test_cancellation_before_spawn_preserves_written_evidence(self):
        def startup(**kwargs):
            (self.root / 'update-state.json').write_text('evidence')
            self.cancelled = True
            kwargs['before_effect']()
            self.fail('spawn admitted after cancellation')
        self.updater.start_initial.side_effect = startup
        with self.assertRaisesRegex(RuntimeError, 'cancelled before spawn'):
            self.run_owner()
        self.assertEqual((self.root / 'update-state.json').read_text(), 'evidence')
        self.coordinator_factory.assert_not_called()

    def test_one_owner_and_lease_survive_admitted_operation_then_cancel(self):
        child = Mock()
        child.poll.side_effect = [None, None, 0]
        self.supervisor.child = child
        events = []
        def startup(**kwargs):
            self.assertEqual(kwargs['authority'], 'owner')
            kwargs['held_lock'].require(self.root / 'supervisor.lock')
            kwargs['before_effect']()
            events.append('started')
        def poll(*, before_update):
            before_update()
            events.append('admitted')
            self.cancelled = True
            events.append('completed')
        self.updater.start_initial.side_effect = startup
        self.coordinator.poll_admin.side_effect = poll
        self.sleep.side_effect = lambda _: self.updater.start_initial.call_args.kwargs['held_lock'].require(
            self.root / 'supervisor.lock')
        self.run_owner()
        lease = self.updater.start_initial.call_args.kwargs['held_lock']
        self.coordinator_factory.assert_called_once_with(self.config, self.supervisor, lease)
        self.assertEqual(self.coordinator.poll_admin.call_count, 1)
        self.assertEqual(events, ['started', 'admitted', 'completed'])
        self.assertEqual(self.sleep.call_count, 2)
        self.assertEqual(child.poll.call_count, 3)

    def test_listener_failure_or_unknown_child_never_retries_or_releases_early(self):
        child = Mock()
        child.poll.side_effect = [PermissionError('unknown'), None, 0]
        self.supervisor.child = child
        self.coordinator.poll_admin.side_effect = PermissionError('listener unavailable')
        self.sleep.side_effect = lambda _: self.updater.start_initial.call_args.kwargs['held_lock'].require(
            self.root / 'supervisor.lock')
        with self.assertRaisesRegex(PermissionError, 'listener unavailable'):
            self.run_owner()
        self.assertEqual(self.coordinator.poll_admin.call_count, 1)
        self.assertEqual(self.sleep.call_count, 2)
        self.assertEqual(child.poll.call_count, 3)

    def test_owner_loss_stale_state_blocks_a_second_invocation(self):
        (self.root / 'state.json').write_text('{"phase":"ready","host":{"pid":123}}')
        with self.assertRaisesRegex(RuntimeError, 'reconciliation'):
            self.run_owner()
        self.factory.assert_not_called()
        self.assertTrue((self.root / 'state.json').exists())

    def test_unreadable_history_is_not_treated_as_absent(self):
        with patch.object(Path, 'lstat', side_effect=PermissionError('denied')):
            with self.assertRaisesRegex(RuntimeError, 'Cannot inspect existing owner records'):
                owner.require_empty_history(self.root)
        self.factory.assert_not_called()

    def test_unreadable_record_directory_is_not_treated_as_empty(self):
        (self.root / 'admin-maintenance').mkdir()
        with patch.object(owner.os, 'scandir', side_effect=PermissionError('denied')):
            with self.assertRaisesRegex(RuntimeError, 'Cannot inspect existing owner records'):
                owner.require_empty_history(self.root)

    def test_cancellation_at_maintenance_admission_stops_before_effect(self):
        child = Mock()
        child.poll.return_value = 0
        self.supervisor.child = child
        effects = []
        def poll(*, before_update):
            self.cancelled = True
            before_update()
            effects.append('effect')
        self.coordinator.poll_admin.side_effect = poll
        with self.assertRaisesRegex(RuntimeError, 'cancelled before maintenance admission'):
            self.run_owner()
        self.assertEqual(effects, [])
        self.assertEqual(self.coordinator.poll_admin.call_count, 1)

    def test_failed_log_and_wait_do_not_release_running_child(self):
        child = Mock()
        child.poll.side_effect = [None, None, 0]
        self.supervisor.child = child
        self.coordinator.poll_admin.side_effect = lambda **_: setattr(self, 'cancelled', True)
        self.sleep.side_effect = [OSError('wait unavailable'), None]
        broken = Mock()
        broken.write.side_effect = OSError('log unavailable')
        with patch.object(owner.sys, 'stderr', broken):
            self.run_owner()
        self.assertEqual(child.poll.call_count, 3)

    def test_cancel_before_bootstrap_never_constructs_owner(self):
        self.cancelled = True
        self.run_owner()
        self.factory.assert_not_called()
        self.updater_factory.assert_not_called()

    def test_cli_defers_delivered_signal_and_restores_handlers(self):
        path = self.root / 'config.json'
        path.write_text(json.dumps(self.config))
        installed = {}
        prior = {owner.signal.SIGINT: object(), owner.signal.SIGTERM: object()}
        def register(sig, handler):
            if sig not in installed:
                installed[sig] = handler
                return prior[sig]
            self.assertIs(handler, prior[sig])
            return None
        def run(_config, *, cancelled):
            self.assertFalse(cancelled())
            installed[owner.signal.SIGINT](owner.signal.SIGINT, None)
            self.assertTrue(cancelled())
        with patch.object(sys, 'argv', ['canonical_owner.py', '--config', str(path)]), \
             patch.object(owner.signal, 'signal', side_effect=register) as signals, \
             patch.object(owner, 'run', side_effect=run):
            owner.main()
        self.assertEqual(signals.call_count, 4)


if __name__ == '__main__':
    unittest.main()
