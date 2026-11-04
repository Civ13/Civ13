"""Offline control-flow and disk-generation tests; never launches a game."""
import importlib.util
import json
from pathlib import Path
import tempfile
import subprocess
import sys
import unittest
from unittest.mock import Mock, patch

SOURCE = Path(__file__).resolve().parents[2] / 'scripts/nomads-lifecycle/supervisor.py'
spec = importlib.util.spec_from_file_location('nomads_supervisor', SOURCE)
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)


class SupervisorTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        config = self.root / 'config'
        config.mkdir()
        (config / 'lifecycle-token.txt').write_text('a' * 32)
        self.supervisor = m.Supervisor({'root': str(self.root / 'runtime'), 'config_directory': str(config), 'port': 1714})
        listener = patch.object(self.supervisor, 'require_owned_listener')
        self.listener = listener.start()
        self.addCleanup(listener.stop)

    def running(self):
        self.supervisor.state = {'revision': 'b' * 40, 'phase': 'ready', 'host': {'pid': 123, 'creation_filetime': 456, 'workdir': str(self.root / 'game')}}
        self.supervisor.owned_session = 'e' * 32

    def generation(self):
        folder = self.root / 'save'
        folder.mkdir()
        marker = 'round-v2:' + 'a' * 32
        (folder / 'map.txt').write_text('NOMADS_EUROPE')
        (folder / 'round.json').write_text(json.dumps({'version': 2, 'generation': marker, 'map': 'NOMADS_EUROPE', 'maxx': 375, 'maxy': 447, 'maxz': 1}))
        (folder / 'save_complete.txt').write_text(marker)
        (folder / '1.sav').write_bytes(b'isolated save bytes')
        (folder / 'restart_intent.json').write_text(json.dumps({'version': 1, 'generation': marker, 'metadata': m.digest(folder / 'map.txt', 'md5'), 'round': m.digest(folder / 'round.json', 'md5')}))
        return folder

    def test_unchanged_revision_never_builds_saves_or_starts(self):
        self.running()
        with patch.object(self.supervisor, 'candidate', return_value='b' * 40), patch.object(self.supervisor, 'alive', return_value=True), patch.object(self.supervisor, 'status', return_value={'ready': 1}), patch.object(self.supervisor, 'build') as build, patch.object(self.supervisor, 'stop_saved') as save, patch.object(self.supervisor, 'start') as start:
            self.supervisor.cycle()
            build.assert_not_called()
            save.assert_not_called()
            start.assert_not_called()

    def test_compile_failure_preserves_current_host(self):
        self.running()
        with patch.object(self.supervisor, 'candidate', return_value='c' * 40), patch.object(self.supervisor, 'alive', return_value=True), patch.object(self.supervisor, 'status', return_value={'ready': 1}), patch.object(self.supervisor, 'build', side_effect=RuntimeError('compile failed')), patch.object(self.supervisor, 'stop_saved') as save, patch.object(self.supervisor, 'start') as start:
            with self.assertRaisesRegex(RuntimeError, 'compile failed'):
                self.supervisor.cycle()
            save.assert_not_called()
            start.assert_not_called()

    def test_ordinary_save_busy_defers_same_or_new_candidate(self):
        for revision in ('b' * 40, 'c' * 40):
            self.running()
            with self.subTest(revision=revision), patch.object(self.supervisor, 'candidate', return_value=revision), patch.object(self.supervisor, 'alive', return_value=True), patch.object(self.supervisor, 'status', return_value={'ready': 0, 'busy': 1}), patch.object(self.supervisor, 'build') as build, patch.object(self.supervisor, 'stop_saved') as save:
                self.supervisor.cycle()
                build.assert_not_called()
                save.assert_not_called()

    def test_completed_ordinary_save_does_not_rebind_startup_generation(self):
        self.running()
        self.supervisor.state['generation'] = 'round-v2:startup'
        with patch.object(self.supervisor, 'candidate', return_value='b' * 40), patch.object(self.supervisor, 'alive', return_value=True), patch.object(self.supervisor, 'status', return_value={'ready': 1, 'generation': 'round-v2:later-save'}), patch.object(self.supervisor, 'build') as build:
            self.supervisor.cycle()
            build.assert_not_called()
        self.assertEqual(self.supervisor.state['generation'], 'round-v2:startup')

    def test_busy_errors_and_holds_still_fail_closed(self):
        for override in ({'error': 'save failed'}, {'restart_hold': 1}):
            self.running()
            with self.subTest(override=override), patch.object(self.supervisor, 'candidate', return_value='b' * 40), patch.object(self.supervisor, 'alive', return_value=True), patch.object(self.supervisor, 'status', return_value={'ready': 0, 'busy': 1, **override}):
                with self.assertRaisesRegex(RuntimeError, 'not ready'):
                    self.supervisor.cycle()

    def test_ready_intent_rejected_and_connected_clients_defer_update(self):
        for status in ({'ready': 1, 'restart_intent': 1}, {'ready': 1, 'clients': 1}):
            self.running()
            with self.subTest(status=status), patch.object(self.supervisor, 'candidate', return_value='c' * 40), patch.object(self.supervisor, 'alive', return_value=True), patch.object(self.supervisor, 'status', return_value=status), patch.object(self.supervisor, 'build') as build:
                if status.get('restart_intent'):
                    with self.assertRaisesRegex(RuntimeError, 'unconsumed restart intent'):
                        self.supervisor.cycle()
                else:
                    self.supervisor.cycle()
                build.assert_not_called()

    def test_staging_retains_exact_git_identity_for_catalog_generator(self):
        repository = self.root / 'repository'
        repository.mkdir()
        git = m.shutil.which('git')
        if not git:
            self.skipTest('Git is unavailable')
        def run_git(*args):
            return subprocess.check_output([git, '-C', str(repository), *args], stderr=subprocess.STDOUT).decode().strip()
        run_git('init')
        (repository / 'scripts').mkdir()
        (repository / 'UI').mkdir()
        (repository / 'code/modules/persistence').mkdir(parents=True)
        (repository / 'code/modules/persistence/nomads_lifecycle.dm').write_text('// fixture')
        (repository / 'civ13.dme').write_text('#include "maps/original.dmm"\n')
        (repository / 'scripts/build-crafting-atlas.py').write_text('import subprocess\nfrom pathlib import Path\nPath("UI/crafting-atlas.json").write_text(subprocess.check_output(["git","rev-parse","HEAD"]).decode().strip())\n')
        (repository / 'UI/.keep').write_text('')
        run_git('add', '.')
        run_git('-c', 'user.name=Lifecycle Test', '-c', 'user.email=lifecycle@example.invalid', 'commit', '-m', 'fixture')
        revision = run_git('rev-parse', 'HEAD')
        self.supervisor.config.update(git=git, repository=str(repository), python=sys.executable, compiler='injected-compiler')
        original = self.supervisor.command
        def command(arguments, cwd=None, log=None, timeout=1800):
            if arguments[0] == 'injected-compiler':
                for name in ('civ13.dmb', 'civ13.rsc'):
                    (Path(cwd) / name).write_bytes(b'fixture output')
                return '0 errors, 0 warnings'
            return original(arguments, cwd, log, timeout)
        with patch.object(self.supervisor, 'command', side_effect=command):
            build = self.supervisor.build(revision)
        self.assertEqual((build / 'game/UI/crafting-atlas.json').read_text(), revision)
        self.assertEqual(run_git('rev-parse', 'HEAD'), revision)
        self.assertIn('nomads_europe.dmm', (build / 'game/civ13.dme').read_text())

    def test_save_failure_never_starts_replacement(self):
        self.running()
        with patch.object(self.supervisor, 'candidate', return_value='c' * 40), patch.object(self.supervisor, 'alive', return_value=True), patch.object(self.supervisor, 'status', return_value={'ready': 1}), patch.object(self.supervisor, 'build', return_value=self.root), patch.object(self.supervisor, 'stop_saved', side_effect=RuntimeError('save failed')), patch.object(self.supervisor, 'start') as start:
            with self.assertRaisesRegex(RuntimeError, 'save failed'):
                self.supervisor.cycle()
            start.assert_not_called()

    def test_pid_reuse_is_not_owned(self):
        self.running()
        self.supervisor.child = Mock(pid=123, poll=Mock(return_value=None))
        with patch.object(m, 'process_identity', return_value=789):
            with self.assertRaisesRegex(RuntimeError, 'identity_mismatch'):
                self.supervisor.alive()

    def test_owned_handle_states_fail_closed_without_adoption(self):
        self.assertEqual(self.supervisor.owned_process_state(), 'absent')
        self.running()
        with patch.object(m, 'process_identity') as identity:
            self.assertEqual(self.supervisor.owned_process_state(), 'helper_lost')
            identity.assert_not_called()
        self.supervisor.child = Mock(pid=123, poll=Mock(return_value=0))
        with patch.object(m, 'process_identity') as identity:
            self.assertEqual(self.supervisor.owned_process_state(), 'exited')
            identity.assert_not_called()
        self.supervisor.child.poll.return_value = None
        for outcome, expected in ((456, 'running'), (None, 'unknown'),
                                  (PermissionError(), 'access_denied'),
                                  (OSError(), 'unknown'), (789, 'identity_mismatch')):
            with self.subTest(expected=expected), patch.object(m, 'process_identity',
                    side_effect=outcome if isinstance(outcome, Exception) else None,
                    return_value=outcome):
                self.assertEqual(self.supervisor.owned_process_state(), expected)
                if expected not in ('running',):
                    with self.assertRaisesRegex(RuntimeError, expected):
                        self.supervisor.alive()
        self.supervisor.child.pid = 124
        with patch.object(m, 'process_identity') as identity:
            self.assertEqual(self.supervisor.owned_process_state(), 'identity_mismatch')
            identity.assert_not_called()

    def test_modified_binary_rejected_again_after_copy(self):
        folder = self.root / 'binaries'
        folder.mkdir()
        for name in ('civ13.dmb', 'civ13.rsc'):
            (folder / name).write_bytes(b'compiled bytes')
        manifest = {'revision': 'b' * 40, 'map': 'NOMADS_EUROPE', 'binaries': {name: m.digest(folder / name) for name in ('civ13.dmb', 'civ13.rsc')}}
        m.verify_binaries(folder, manifest, 'b' * 40)
        (folder / 'civ13.dmb').write_bytes(b'changed after staging')
        with self.assertRaisesRegex(RuntimeError, 'binary changed'):
            m.verify_binaries(folder, manifest, 'b' * 40)

    def test_halt_latch_prevents_fetch_or_restart(self):
        (self.supervisor.root / 'HALTED.json').write_text('{}')
        with patch.object(self.supervisor, 'candidate') as candidate:
            with self.assertRaisesRegex(RuntimeError, 'latched halted'):
                self.supervisor.cycle()
            candidate.assert_not_called()

    def test_backup_copies_exact_generation_and_hashes(self):
        source = self.generation()
        target = self.root / 'backup'
        generation = m.snapshot(source, target)
        receipt = json.loads((target / 'receipt.json').read_text())
        self.assertEqual(receipt['generation'], generation)
        self.assertEqual(len(receipt['files']), 5)
        for name, expected in receipt['files'].items():
            self.assertEqual(m.digest(target / name), expected)

    def test_corrupted_round_rejected(self):
        source = self.generation()
        (source / 'round.json').write_text(json.dumps({'version': 2, 'generation': 'round-v2:other', 'maxz': 1}))
        with self.assertRaisesRegex(RuntimeError, 'generation mismatch'):
            m.snapshot(source, self.root / 'backup')

    def test_native_crlf_text_identity_preserves_raw_backup_hashes(self):
        source = self.generation()
        metadata = b'NOMADS_EUROPE\n5000\n'
        round_text = (source / 'round.json').read_bytes() + b'\n'
        intent_path = source / 'restart_intent.json'
        intent = json.loads(intent_path.read_text())
        # BYOND's published identity hashes file2text(), not on-disk CRLF bytes.
        import hashlib
        intent.update(metadata=hashlib.md5(metadata).hexdigest(), round=hashlib.md5(round_text).hexdigest())
        intent_path.write_text(json.dumps(intent))
        (source / 'map.txt').write_bytes(metadata.replace(b'\n', b'\r\n'))
        (source / 'round.json').write_bytes(round_text.replace(b'\n', b'\r\n'))
        self.assertNotEqual(m.digest(source / 'map.txt', 'md5'), intent['metadata'])
        self.assertNotEqual(m.digest(source / 'round.json', 'md5'), intent['round'])
        target = self.root / 'backup'
        m.snapshot(source, target)
        receipt = json.loads((target / 'receipt.json').read_text())
        for name in ('map.txt', 'round.json'):
            self.assertEqual((target / name).read_bytes(), (source / name).read_bytes())
            self.assertEqual(receipt['files'][name], m.digest(source / name))
        # Text-equivalent rewrites still change the independently retained raw
        # byte receipt. Actual content corruption must fail the text identity.
        (target / 'map.txt').write_bytes(metadata)
        self.assertNotEqual(m.digest(target / 'map.txt'), receipt['files']['map.txt'])
        for name in ('map.txt', 'round.json'):
            with self.subTest(tampered=name):
                original = (source / name).read_bytes()
                (source / name).write_bytes(original + b' ')
                with self.assertRaisesRegex(RuntimeError, 'metadata mismatch'):
                    m.validate_generation(source)
                (source / name).write_bytes(original)

    def test_tampered_metadata_rejected(self):
        source = self.generation()
        (source / 'map.txt').write_text('tampered')
        with self.assertRaisesRegex(RuntimeError, 'metadata mismatch'):
            m.validate_generation(source)

    def test_matching_intent_for_other_map_rejected(self):
        source = self.generation()
        path = source / 'round.json'
        state = json.loads(path.read_text())
        state['map'] = 'NOMADS_GAIA'
        path.write_text(json.dumps(state))
        intent_path = source / 'restart_intent.json'
        intent = json.loads(intent_path.read_text())
        intent['round'] = m.digest(path, 'md5')
        intent_path.write_text(json.dumps(intent))
        with self.assertRaisesRegex(RuntimeError, 'another map'):
            m.validate_generation(source)

    def test_native_lock_rejected(self):
        source = self.generation()
        (source / '1.sav.lk').write_text('locked')
        with self.assertRaisesRegex(RuntimeError, 'native locks'):
            m.validate_generation(source)

    def test_missing_level_rejected(self):
        source = self.generation()
        (source / '1.sav').unlink()
        with self.assertRaisesRegex(RuntimeError, 'Incomplete'):
            m.validate_generation(source)

    def test_missing_session_never_requests_mutation(self):
        self.running()
        with patch.object(self.supervisor, 'alive', return_value=True), patch.object(self.supervisor, 'status', return_value={'ready': 1}), patch.object(m, 'query') as query:
            with self.assertRaisesRegex(RuntimeError, 'session challenge'):
                self.supervisor.stop_saved('d' * 32)
            query.assert_not_called()

    def test_client_arriving_during_build_prevents_shutdown(self):
        self.running()
        with patch.object(self.supervisor, 'alive', return_value=True), patch.object(self.supervisor, 'status', return_value={'ready': 1, 'clients': 1, 'session': 'e' * 32}), patch.object(m, 'query') as query:
            with self.assertRaisesRegex(RuntimeError, 'not ready for a safe update'):
                self.supervisor.stop_saved('d' * 32)
            query.assert_not_called()

    def test_resumed_starting_phase_cannot_skip_generation_verification(self):
        self.running()
        self.supervisor.state.update(phase='starting', generation='round-v2:expected')
        with patch.object(self.supervisor, 'candidate', return_value='b' * 40), patch.object(self.supervisor, 'alive', return_value=True), patch.object(self.supervisor, 'status', return_value={'ready': 1, 'generation': 'round-v2:wrong', 'restart_import_complete': 1}):
            with self.assertRaisesRegex(RuntimeError, 'intended generation'):
                self.supervisor.cycle()
        self.assertEqual(self.supervisor.state['phase'], 'starting')

    def test_new_candidate_cannot_bypass_pending_recovery(self):
        self.running()
        self.supervisor.state.update(phase='starting', generation='round-v2:expected')
        with patch.object(self.supervisor, 'candidate', return_value='c' * 40), patch.object(self.supervisor, 'alive', return_value=True), patch.object(self.supervisor, 'status', return_value={'ready': 1, 'generation': 'round-v2:wrong', 'restart_import_complete': 1}), patch.object(self.supervisor, 'build') as build:
            with self.assertRaisesRegex(RuntimeError, 'intended generation'):
                self.supervisor.cycle()
            build.assert_not_called()

    def test_stale_lifecycle_intent_rejected(self):
        source = self.generation()
        with self.assertRaisesRegex(RuntimeError, 'acknowledged lifecycle operation'):
            m.snapshot(source, self.root / 'backup', 'd' * 32, 'e' * 32)
        self.assertFalse((self.root / 'backup').exists())

    def test_lifecycle_intent_requires_both_operation_and_session(self):
        source = self.generation()
        path = source / 'restart_intent.json'
        intent = json.loads(path.read_text())
        intent.update(lifecycle_operation='d' * 32, lifecycle_session='e' * 32)
        path.write_text(json.dumps(intent))
        m.validate_generation(source, 'd' * 32, 'e' * 32)
        for operation, session in (('f' * 32, 'e' * 32), ('d' * 32, 'f' * 32)):
            with self.subTest(operation=operation), self.assertRaisesRegex(RuntimeError, 'acknowledged lifecycle operation'):
                m.validate_generation(source, operation, session)

    def test_pending_intent_or_hold_cannot_report_recovered(self):
        for override in ({'restart_intent': 1}, {'restart_hold': 1}, {'restart_import_complete': 0}):
            status = {'ready': 1, 'generation': 'round-v2:expected', 'restart_import_complete': 1, **override}
            with self.subTest(override=override), self.assertRaises(RuntimeError):
                self.supervisor.accept_ready(status, 'round-v2:expected')

    def test_mutation_sent_once_with_process_session_on_failure(self):
        self.running()
        with patch.object(self.supervisor, 'alive', return_value=True), patch.object(self.supervisor, 'status', return_value={'ready': 1, 'session': 'e' * 32}), patch.object(m, 'query', side_effect=TimeoutError('unknown result')) as query:
            with self.assertRaises(TimeoutError):
                self.supervisor.stop_saved('d' * 32)
            query.assert_called_once_with(1714, 'a' * 32, 'save_shutdown', 'd' * 32, 'e' * 32)

    def test_status_checks_owned_listener_before_query(self):
        self.running()
        self.listener.side_effect = PermissionError('listener denied')
        with patch.object(m, 'query') as query, self.assertRaisesRegex(PermissionError, 'listener denied'):
            self.supervisor.status()
        query.assert_not_called()

    def test_effect_admission_failure_never_sends_save(self):
        self.running()
        with patch.object(self.supervisor, 'alive', return_value=True), \
             patch.object(self.supervisor, 'status', return_value={'ready': 1, 'session': 'e' * 32}), \
             patch.object(m, 'query') as query:
            with self.assertRaisesRegex(RuntimeError, 'expired'):
                self.supervisor.stop_saved('d' * 32, before_mutation=Mock(side_effect=RuntimeError('expired')))
            query.assert_not_called()

    def test_expiry_during_final_listener_check_prevents_first_effect(self):
        self.running()
        now = [299]
        observations = []
        def observe_listener():
            observations.append(now[0])
            if len(observations) == 3:
                now[0] = 301  # The final process/listener check crossed expiry.
        self.listener.side_effect = observe_listener
        def require_fresh():
            if now[0] > 300:
                raise RuntimeError('request expired')
        freshness = Mock(side_effect=require_fresh)
        with patch.object(self.supervisor, 'alive', return_value=True), \
                patch.object(self.supervisor, 'status', return_value={'ready': 1, 'session': 'e' * 32}), \
                patch.object(m, 'query') as query, \
                self.assertRaisesRegex(RuntimeError, 'request expired'):
            self.supervisor.stop_saved('d' * 32, before_mutation=freshness)
        self.assertEqual(len(observations), 3)
        freshness.assert_called_once()
        query.assert_not_called()

    def test_listener_change_before_save_never_sends_mutation(self):
        self.running()
        self.listener.side_effect = [None, RuntimeError('listener changed')]
        status = {'ready': 1, 'busy': 0, 'error': None, 'restart_hold': 0,
                  'restart_intent': 0, 'clients': 0, 'session': 'e' * 32}
        with patch.object(self.supervisor, 'alive', return_value=True), \
                patch.object(self.supervisor, 'status', return_value=status), \
                patch.object(m, 'query') as query, \
                self.assertRaisesRegex(RuntimeError, 'listener changed'):
            self.supervisor.stop_saved('d' * 32)
        query.assert_not_called()

    def test_shutdown_wait_does_not_query_an_absent_listener(self):
        self.running()
        self.listener.side_effect = [None, None, None, m.ListenerNotReady('closed')]
        status = {'ready': 1, 'busy': 0, 'error': None, 'restart_hold': 0,
                  'restart_intent': 0, 'clients': 0, 'session': 'e' * 32}
        operation = 'd' * 32
        with patch.object(self.supervisor, 'alive', side_effect=[True] * 6 + [False]), \
                patch.object(self.supervisor, 'status', return_value=status) as observed, \
                patch.object(self.supervisor, 'sleep'), patch.object(self.supervisor, 'record'), \
                patch.object(m, 'snapshot', return_value='generation'), \
                patch.object(m, 'query', return_value={'operation': operation}) as query:
            self.supervisor.stop_saved(operation)
        observed.assert_called_once()
        query.assert_called_once()

    def test_shutdown_exit_during_wait_does_not_query_or_reject_save(self):
        self.running()
        status = {'ready': 1, 'busy': 0, 'error': None, 'restart_hold': 0,
                  'restart_intent': 0, 'clients': 0, 'session': 'e' * 32}
        operation = 'd' * 32
        with patch.object(self.supervisor, 'alive', side_effect=[True] * 4 + [False]), \
                patch.object(self.supervisor, 'status', return_value=status) as observed, \
                patch.object(self.supervisor, 'sleep'), patch.object(self.supervisor, 'record'), \
                patch.object(m, 'snapshot', return_value='generation'), \
                patch.object(m, 'query', return_value={'operation': operation}) as query:
            self.supervisor.stop_saved(operation)
        observed.assert_called_once()
        query.assert_called_once()

    def test_save_rechecks_handle_and_bound_session_before_any_mutation(self):
        self.running()
        status = {'ready': 1, 'session': 'e' * 32}
        with patch.object(self.supervisor, 'alive', side_effect=RuntimeError('helper_lost')), \
                patch.object(self.supervisor, 'status') as status_read, patch.object(m, 'query') as query:
            with self.assertRaisesRegex(RuntimeError, 'helper_lost'):
                self.supervisor.stop_saved('d' * 32)
            status_read.assert_not_called()
            query.assert_not_called()
        with patch.object(self.supervisor, 'alive', side_effect=[True, True, False]), \
                patch.object(self.supervisor, 'status', return_value=status), patch.object(m, 'query') as query:
            with self.assertRaisesRegex(RuntimeError, 'session changed before mutation'):
                self.supervisor.stop_saved('d' * 32)
            query.assert_not_called()
        with patch.object(self.supervisor, 'alive', return_value=True), \
                patch.object(self.supervisor, 'status', return_value=dict(status, session='f' * 32)), \
                patch.object(m, 'query') as query:
            with self.assertRaisesRegex(RuntimeError, 'session changed'):
                self.supervisor.stop_saved('d' * 32)
            query.assert_not_called()
        self.supervisor.owned_session = None
        with patch.object(self.supervisor, 'alive', return_value=True), \
                patch.object(self.supervisor, 'status', return_value=status), patch.object(m, 'query') as query:
            with self.assertRaisesRegex(RuntimeError, 'session changed'):
                self.supervisor.stop_saved('d' * 32)
            query.assert_not_called()

    def test_once_refuses_before_reading_configuration_or_starting_supervisor(self):
        for args in (['--once'], ['--once', '--force-cycle']):
            with self.subTest(args=args), patch.object(sys, 'argv', ['supervisor.py', '--config', str(self.root / 'missing'), *args]), \
                    patch.object(m, 'Supervisor') as constructor:
                with self.assertRaises(SystemExit) as error:
                    m.main()
                self.assertEqual(error.exception.code, 2)
                constructor.assert_not_called()


class PortProbeTests(unittest.TestCase):
    def test_probe_refuses_an_active_listener(self):
        import socket
        with socket.socket() as listener:
            listener.bind(('127.0.0.1', 0)); listener.listen()
            port = listener.getsockname()[1]
            with self.assertRaises(OSError):
                m.probe_port_free('127.0.0.1', port)
        m.probe_port_free('127.0.0.1', port)

    @unittest.skipIf(sys.platform == "win32", "Linux address reuse")
    def test_probe_ignores_time_wait_from_closed_connections(self):
        import socket
        # Server side closes first, leaving its accepted socket in TIME_WAIT.
        listener = socket.socket(); listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        listener.bind(('127.0.0.1', 0)); listener.listen(); port = listener.getsockname()[1]
        client = socket.create_connection(('127.0.0.1', port)); accepted, _ = listener.accept()
        accepted.close(); listener.close(); client.recv(1); client.close()
        m.probe_port_free('127.0.0.1', port)


class LinuxOwnershipTests(unittest.TestCase):
    """Linux /proc identity and listener ownership, against fake and real /proc."""
    BOOT = '0123456789abcdef0123456789abcdef'

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.proc = Path(self.temporary.name)
        (self.proc / 'sys/kernel/random').mkdir(parents=True)
        (self.proc / 'sys/kernel/random/boot_id').write_text('01234567-89ab-cdef-0123-456789abcdef\n')

    def stat(self, pid, state='S', start=4242, comm='DreamDaemon'):
        folder = self.proc / str(pid)
        folder.mkdir(exist_ok=True)
        fields = [state] + ['0'] * 18 + [str(start)] + ['0'] * 30
        (folder / 'stat').write_text(f'{pid} ({comm}) ' + ' '.join(fields) + '\n')

    def test_identity_binds_boot_and_start_time(self):
        self.stat(77)
        identity = m.linux_process_identity(77, self.proc)
        self.assertEqual(identity, (int(self.BOOT, 16) << 64) | 4242)
        self.stat(77, start=4243)
        self.assertNotEqual(m.linux_process_identity(77, self.proc), identity, 'a recycled PID differs')
        self.stat(77)
        (self.proc / 'sys/kernel/random/boot_id').write_text('11111111-89ab-cdef-0123-456789abcdef')
        self.assertNotEqual(m.linux_process_identity(77, self.proc), identity, 'a reboot differs')

    def test_identity_handles_hostile_command_names(self):
        self.stat(78, comm='a) Z (b')
        self.assertIsNotNone(m.linux_process_identity(78, self.proc))

    def test_missing_or_dead_process_has_no_identity(self):
        self.assertIsNone(m.linux_process_identity(79, self.proc))
        for state in ('Z', 'X'):
            self.stat(80, state=state)
            self.assertIsNone(m.linux_process_identity(80, self.proc))

    def test_malformed_identity_fails_closed(self):
        (self.proc / '81').mkdir()
        for text in ('81 (x) S 1 2', '82 (x) ' + ' '.join(['S'] + ['0'] * 25), 'garbage'):
            (self.proc / '81/stat').write_text(text)
            with self.subTest(text=text), self.assertRaises(RuntimeError):
                m.linux_process_identity(81, self.proc)
        with self.assertRaises(RuntimeError):
            m.linux_process_identity(0, self.proc)

    def test_listener_table_parsing(self):
        table = ('  sl  local_address rem_address   st tx_queue rx_queue tr tm->when retrnsmt   uid  timeout inode\n'
                 '   0: 0100007F:06B2 00000000:0000 0A 00000000:00000000 00:00000000 00000000  1000        0 555 1\n'
                 '   1: 00000000:06B2 00000000:0000 01 00000000:00000000 00:00000000 00000000  1000        0 556 1\n')
        self.assertEqual(m.linux_tcp_listeners(table, m.socket.AF_INET), [('127.0.0.1', 1714, '555')])
        with self.assertRaises(RuntimeError):
            m.linux_tcp_listeners('header\n 0: 0100007F:06B2 0A\n', m.socket.AF_INET)

    @unittest.skipUnless(sys.platform.startswith('linux'), 'symlinked fake /proc entries')
    def test_listener_observation_requires_the_owned_unique_listener(self):
        root = self.proc / 'game'
        root.mkdir()
        daemon = self.proc / 'DreamDaemon'
        daemon.write_bytes(b'inert')
        self.stat(90)
        (self.proc / '90/fd').mkdir()
        (self.proc / '90/net').mkdir()
        (self.proc / '90/exe').symlink_to(daemon)
        (self.proc / '90/cwd').symlink_to(root)
        (self.proc / '90/fd/3').symlink_to('socket:[555]')
        header = 'sl local rem st tx rx tr tm retr uid timeout inode\n'
        own = '0: 0100007F:06B2 00000000:0000 0A 0:0 0:0 0 1000 0 555 1\n'
        foreign = '1: 00000000:06B2 00000000:0000 0A 0:0 0:0 0 1000 0 999 1\n'
        host = {'pid': 90, 'creation_filetime': m.linux_process_identity(90, self.proc)}
        (self.proc / '90/net/tcp').write_text(header + own)
        seen = m.linux_listener_observation(host, daemon.resolve(), root.resolve(), 1714, '127.0.0.1', self.proc)
        self.assertEqual(seen['pid'], 90)
        (self.proc / '90/net/tcp').write_text(header + own + foreign)
        with self.assertRaisesRegex(RuntimeError, 'ambiguous'):
            m.linux_listener_observation(host, daemon.resolve(), root.resolve(), 1714, '127.0.0.1', self.proc)
        (self.proc / '90/net/tcp').write_text(header)
        with self.assertRaises(m.ListenerNotReady):
            m.linux_listener_observation(host, daemon.resolve(), root.resolve(), 1714, '127.0.0.1', self.proc)
        (self.proc / '90/net/tcp').write_text(header + own)
        with self.assertRaisesRegex(RuntimeError, 'executable or working directory'):
            m.linux_listener_observation(host, daemon.resolve(), self.proc.resolve(), 1714, '127.0.0.1', self.proc)
        stale = dict(host, creation_filetime=host['creation_filetime'] + 1)
        with self.assertRaisesRegex(RuntimeError, 'PID was reused'):
            m.linux_listener_observation(stale, daemon.resolve(), root.resolve(), 1714, '127.0.0.1', self.proc)

    @unittest.skipUnless(sys.platform.startswith('linux'), 'real Linux /proc')
    def test_real_child_identity_and_listener(self):
        import socket as real_socket
        with real_socket.socket() as probe:
            probe.bind(('127.0.0.1', 0))
            port = probe.getsockname()[1]
        code = ('import socket,sys,time;s=socket.socket();s.bind(("127.0.0.1",%d));s.listen();'
                'sys.stdout.write("ok\\n");sys.stdout.flush();time.sleep(30)' % port)
        child = subprocess.Popen([sys.executable, '-c', code], cwd=self.proc, stdout=subprocess.PIPE,
                                 start_new_session=True)
        try:
            self.assertEqual(child.stdout.readline().strip(), b'ok')
            identity = m.process_identity(child.pid)
            self.assertIsInstance(identity, int)
            self.assertEqual(m.process_identity(child.pid), identity)
            host = {'pid': child.pid, 'creation_filetime': identity}
            executable = Path(m.os.readlink(f'/proc/{child.pid}/exe')).resolve()
            seen = m.native_listener_observation(host, executable, self.proc.resolve(), port, '127.0.0.1')
            self.assertEqual(seen['pid'], child.pid)
            self.assertTrue(m.port_listening(port))
        finally:
            child.kill()
            child.wait()
            child.stdout.close()
        self.assertIsNone(m.process_identity(child.pid))
        self.assertFalse(m.port_listening(port))

    def test_native_environment_only_adds_byond_library_path(self):
        self.assertIsNone(m.native_environment('/usr/bin/git'))
        if m.is_linux():
            environment = m.native_environment(str(self.proc / 'DreamMaker'))
            self.assertTrue(environment['LD_LIBRARY_PATH'].startswith(str(self.proc.resolve())))


if __name__ == '__main__':
    unittest.main()
