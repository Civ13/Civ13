"""Offline control-flow and disk-generation tests; never launches a game."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

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

    def running(self):
        self.supervisor.state = {'revision': 'b' * 40, 'phase': 'ready', 'host': {'pid': 123, 'creation_filetime': 456, 'workdir': str(self.root / 'game')}}

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
        with patch.object(self.supervisor, 'candidate', return_value='c' * 40), patch.object(self.supervisor, 'alive', return_value=True), patch.object(self.supervisor, 'build', side_effect=RuntimeError('compile failed')), patch.object(self.supervisor, 'stop_saved') as save, patch.object(self.supervisor, 'start') as start:
            with self.assertRaisesRegex(RuntimeError, 'compile failed'):
                self.supervisor.cycle()
            save.assert_not_called()
            start.assert_not_called()

    def test_save_failure_never_starts_replacement(self):
        self.running()
        with patch.object(self.supervisor, 'candidate', return_value='c' * 40), patch.object(self.supervisor, 'alive', return_value=True), patch.object(self.supervisor, 'build', return_value=self.root), patch.object(self.supervisor, 'stop_saved', side_effect=RuntimeError('save failed')), patch.object(self.supervisor, 'start') as start:
            with self.assertRaisesRegex(RuntimeError, 'save failed'):
                self.supervisor.cycle()
            start.assert_not_called()

    def test_pid_reuse_is_not_owned(self):
        self.running()
        with patch.object(m, 'process_identity', return_value=789):
            with self.assertRaisesRegex(RuntimeError, 'PID was reused'):
                self.supervisor.alive()

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
        with patch.object(self.supervisor, 'status', return_value={'ready': 1}), patch.object(m, 'query') as query:
            with self.assertRaisesRegex(RuntimeError, 'session challenge'):
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
        with patch.object(self.supervisor, 'status', return_value={'ready': 1, 'session': 'e' * 32}), patch.object(m, 'query', side_effect=TimeoutError('unknown result')) as query:
            with self.assertRaises(TimeoutError):
                self.supervisor.stop_saved('d' * 32)
            query.assert_called_once_with(1714, 'a' * 32, 'save_shutdown', 'd' * 32, 'e' * 32)


if __name__ == '__main__':
    unittest.main()
