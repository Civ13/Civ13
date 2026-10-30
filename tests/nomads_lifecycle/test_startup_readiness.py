"""Owned readiness publication and help follow-up; no native process or socket."""
import copy
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch

SCRIPTS = Path(__file__).resolve().parents[2] / 'scripts/nomads-lifecycle'
sys.path.insert(0, str(SCRIPTS))
SPEC = importlib.util.spec_from_file_location('readiness_supervisor', SCRIPTS / 'supervisor.py')
m = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(m)
import help_manager


class StartupReadinessTests(unittest.TestCase):
    def setUp(self):
        self.storage = tempfile.TemporaryDirectory()
        self.addCleanup(self.storage.cleanup)
        self.root = Path(self.storage.name)
        self.run = self.root / 'runs/one'
        self.run.mkdir(parents=True)
        self.revision = 'b' * 40
        self.session = 'c' * 32
        self.host = {'pid': 100, 'creation_filetime': 200, 'workdir': str(self.run)}
        self.state = {'revision': self.revision, 'map': 'NOMADS_GAIA',
                      'phase': 'fresh_gaia_available', 'host': self.host, 'generation': None}
        self.save_state()
        self.status = {'ok': 1, 'ready': 1, 'busy': 0, 'restart_hold': 0,
                       'restart_intent': 0, 'error': None, 'revision': self.revision,
                       'map': 'NOMADS_GAIA', 'session': self.session,
                       'generation': '', 'restart_import_complete': 0, 'clients': 1}

    def save_state(self):
        m.write_json(self.root / 'state.json', self.state)

    def publish(self, **overrides):
        arguments = {'revision': self.revision, 'expected_map': 'NOMADS_GAIA',
                     'host': self.host.copy(), 'generation': None, 'session': self.session,
                     'status': self.status.copy(), 'identity': lambda pid: 200}
        arguments.update(overrides)
        return m.publish_ready(self.root, **arguments)

    def unchanged_rejection(self, **arguments):
        before = (self.root / 'state.json').read_bytes()
        with self.assertRaises((RuntimeError, OSError)):
            self.publish(**arguments)
        self.assertEqual((self.root / 'state.json').read_bytes(), before)

    def test_fresh_ready_publishes_and_strict_manager_starts_once(self):
        files = [self.root / name for name in ('python.exe', 'bridge.py', 'config.json')]
        for path in files:
            path.touch()
        child = Mock(pid=101)
        child.poll.return_value = None
        spawn = Mock(return_value=child)
        manager = help_manager.HelpManager(self.root, *files,
            identity=lambda pid: {100: 200, 101: 201}.get(pid), spawn=spawn)
        self.addCleanup(lambda: manager.log.close() if manager.log else None)
        self.assertEqual(manager.tick(), 'waiting_for_ready_game')
        spawn.assert_not_called()
        result = self.publish()
        self.assertEqual(result, dict(self.state, phase='ready'))
        self.assertNotIn(self.session, (self.root / 'state.json').read_text())
        self.assertEqual(manager.tick(), 'running')
        self.assertEqual(manager.tick(), 'running')
        spawn.assert_called_once()
        self.assertEqual(manager.attempts, 1)

    def test_healthy_lobby_and_unsafe_status_never_publish(self):
        for change in ({'ready': 0}, {'ready': '1'}, {'busy': 1}, {'busy': None},
                       {'ok': 0}, {'restart_hold': 1}, {'restart_intent': 1},
                       {'error': 'recovery failed'}, {'revision': 'd' * 40},
                       {'map': 'NOMADS_EUROPE'}):
            with self.subTest(change=change):
                self.unchanged_rejection(status=dict(self.status, **change))

    def test_session_is_valid_lower_hex_and_bound_to_initial_challenge(self):
        for session in (None, '', 'C' * 32, 'g' * 32, 'c' * 31, 7):
            with self.subTest(session=session):
                self.unchanged_rejection(session=session)
                self.unchanged_rejection(status=dict(self.status, session=session))
        self.unchanged_rejection(status=dict(self.status, session='d' * 32))

    def test_restored_startup_requires_exact_generation_and_completed_import(self):
        generation = 'round-v2:' + 'a' * 32
        self.state.update(phase='starting', generation=generation)
        self.save_state()
        restored = dict(self.status, generation=generation, restart_import_complete=1)
        for change in ({'generation': 'round-v2:other'}, {'restart_import_complete': 0},
                       {'restart_intent': 1}, {'restart_hold': 1}):
            with self.subTest(change=change):
                self.unchanged_rejection(generation=generation, status=dict(restored, **change))
        self.assertEqual(self.publish(generation=generation, status=restored)['phase'], 'ready')

    def test_fresh_startup_rejects_autoload_and_malformed_generation_without_mutation(self):
        for change in ({'generation': 'round-v2:' + 'a' * 32}, {'restart_import_complete': 1},
                       {'generation': None}, {'generation': 0}, {'generation': False},
                       {'generation': []}, {'restart_import_complete': None}):
            with self.subTest(change=change):
                status = dict(self.status, **change)
                before = copy.deepcopy(status)
                self.unchanged_rejection(status=status)
                self.assertEqual(status, before)
        for field in ('generation', 'restart_import_complete'):
            with self.subTest(missing=field):
                status = {key: value for key, value in self.status.items() if key != field}
                before = copy.deepcopy(status)
                self.unchanged_rejection(status=status)
                self.assertEqual(status, before)

    def test_stale_owned_context_and_invalid_run_never_publish(self):
        for change in ({'revision': 'd' * 40}, {'expected_map': 'NOMADS_EUROPE'},
                       {'host': dict(self.host, pid=101)}, {'generation': 'round-v2:other'}):
            with self.subTest(change=change):
                self.unchanged_rejection(**change)
        for change in ({'workdir': str(self.root)}, {'pid': True},
                       {'pid': 0}, {'creation_filetime': None}):
            with self.subTest(host_change=change):
                self.state['host'] = dict(self.host, **change)
                self.save_state()
                self.unchanged_rejection(host=self.state['host'].copy())

    def test_missing_recycled_or_denied_process_identity_never_publish(self):
        for identity in (lambda pid: None, lambda pid: 999,
                         Mock(side_effect=PermissionError('identity unavailable'))):
            with self.subTest(identity=identity):
                self.unchanged_rejection(identity=identity)

    def test_owned_state_change_during_identity_check_is_not_overwritten(self):
        def identity(pid):
            m.write_json(self.root / 'state.json', dict(self.state, phase='saving'))
            return 200
        with self.assertRaisesRegex(RuntimeError, 'state changed before publication'):
            self.publish(identity=identity)
        self.assertEqual(json.loads((self.root / 'state.json').read_text())['phase'], 'saving')

    def supervisor(self, statuses, *, clock=lambda: 0):
        config = self.root / 'config'
        config.mkdir(exist_ok=True)
        (config / 'lifecycle-token.txt').write_text('a' * 32)
        supervisor = m.Supervisor({'root': str(self.root), 'config_directory': str(config),
            'port': 1714, 'daemon': 'injected-no-native', 'startup_timeout_seconds': 5},
            clock=clock, sleep=lambda _: None)
        supervisor.status = Mock(side_effect=statuses)
        return supervisor

    def staged_build(self):
        build = self.root / 'builds' / self.revision
        game = build / 'game'
        game.mkdir(parents=True)
        for name in ('civ13.dmb', 'civ13.rsc'):
            (game / name).write_bytes(b'inert offline binary fixture')
        manifest = {'revision': self.revision, 'map': 'NOMADS_EUROPE',
                    'binaries': {name: m.digest(game / name) for name in ('civ13.dmb', 'civ13.rsc')}}
        m.write_json(build / 'build.json', manifest)
        return build

    def test_actual_public_start_uses_publisher_for_fresh_and_restored(self):
        build = self.staged_build()
        for restored in (False, True):
            with self.subTest(restored=restored):
                generation = 'round-v2:' + 'a' * 32 if restored else None
                backup = self.root / 'backup' if restored else None
                if backup:
                    backup.mkdir()
                    (backup / 'round.json').write_text('isolated fixture')
                status = dict(self.status, map='NOMADS_EUROPE', generation=generation or '',
                              restart_import_complete=int(restored))
                supervisor = self.supervisor([dict(status, ready=0), status])
                child = Mock(pid=100, poll=Mock(return_value=None))
                with patch.object(m.socket, 'socket'), patch.object(m.subprocess, 'Popen', return_value=child), \
                        patch.object(m, 'process_identity', return_value=200), \
                        patch.object(m, 'publish_ready', wraps=m.publish_ready) as publisher:
                    supervisor.start(build, backup, generation, 'e' * 32 if restored else 'f' * 32)
                publisher.assert_called_once()
                self.assertIs(supervisor.child, child)
                self.assertEqual(supervisor.state['phase'], 'ready')
                self.assertEqual(supervisor.state['map'], 'NOMADS_EUROPE')
                self.assertNotIn(self.session, (self.root / 'events.jsonl').read_text())

    def test_actual_public_start_lobby_or_changed_session_cannot_promote(self):
        build = self.staged_build()
        status = dict(self.status, map='NOMADS_EUROPE')
        for changed_session in (False, True):
            with self.subTest(changed_session=changed_session):
                statuses = [dict(status, ready=0), dict(status, session='d' * 32)]
                supervisor = self.supervisor(statuses, clock=lambda: 0) if changed_session else \
                    self.supervisor([dict(status, ready=0)], clock=Mock(side_effect=[0, 6]))
                with patch.object(m.socket, 'socket'), patch.object(m.subprocess, 'Popen', return_value=Mock(pid=100, poll=Mock(return_value=None))), \
                        patch.object(m, 'process_identity', return_value=200), \
                        patch.object(m, 'publish_ready', wraps=m.publish_ready) as publisher:
                    with self.assertRaisesRegex(RuntimeError, 'session changed' if changed_session else 'readiness timeout'):
                        supervisor.start(build, None, None, '1' * 32 if changed_session else '2' * 32)
                publisher.assert_not_called()
                self.assertEqual(supervisor.state['phase'], 'starting')

    def test_restarted_helper_does_not_adopt_persisted_pid(self):
        self.save_state()
        supervisor = self.supervisor([self.status])
        with patch.object(supervisor, 'candidate', return_value=self.revision) as candidate, \
                patch.object(m, 'process_identity') as identity, \
                patch.object(m, 'publish_ready') as publisher, \
                patch.object(supervisor, 'build') as build:
            with self.assertRaisesRegex(RuntimeError, 'helper_lost'):
                supervisor.cycle()
            identity.assert_not_called()
            candidate.assert_not_called()
            supervisor.status.assert_not_called()
            publisher.assert_not_called()
            build.assert_not_called()


if __name__ == '__main__':
    unittest.main()
