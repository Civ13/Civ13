"""Offline contracts. No WSL, compiler, daemon, signals or live sockets."""
import importlib.util
from contextlib import ExitStack
from pathlib import Path
import sys
import tempfile
import types
import unittest
from unittest.mock import Mock, patch

if sys.platform == 'win32':
    sys.modules.setdefault('fcntl', types.SimpleNamespace(LOCK_EX=2, flock=lambda *_: None))
spec = importlib.util.spec_from_file_location('local_wsl', Path(__file__).resolve().parents[1] / 'scripts/local-wsl.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class LocalWslTests(unittest.TestCase):
    def start_fixture(self, failure=None, cleanup_timeout=False):
        stack = self.enterContext(ExitStack())
        directory = stack.enter_context(tempfile.TemporaryDirectory())
        home = Path(directory)
        runtime = home / '.local/share/civ13-local/nomads'
        runtime.mkdir(parents=True)
        (runtime / 'source-sha.txt').write_text('a' * 40)
        process = Mock(pid=77)
        process.poll.return_value = None
        process.wait.side_effect = module.subprocess.TimeoutExpired('owned fake', 10) if cleanup_timeout else None
        process.wait.return_value = 0
        read_text, write_text = Path.read_text, Path.write_text

        def read(path, *args, **kwargs):
            if path == Path('/proc/77/stat'):
                if failure == 'stat-read':
                    raise OSError('injected stat read failure')
                if failure == 'stat-parse':
                    return '77 (DreamDaemon)'
                return '77 (DreamDaemon) ' + ' '.join(['S'] + ['0'] * 18 + ['123'])
            return read_text(path, *args, **kwargs)

        def write(path, *args, **kwargs):
            if path.name == 'process.json' and failure == 'state-write':
                raise OSError('injected state write failure')
            return write_text(path, *args, **kwargs)

        stack.enter_context(patch.object(sys, 'argv', ['local-wsl', 'start', '--server', 'nomads', '--source', directory]))
        stack.enter_context(patch.object(Path, 'home', return_value=home))
        stack.enter_context(patch.object(Path, 'read_text', read))
        stack.enter_context(patch.object(Path, 'write_text', write))
        stack.enter_context(patch.object(module, 'process_matches', return_value=False))
        stack.enter_context(patch.object(module.fcntl, 'flock'))
        stack.enter_context(patch.object(module.subprocess, 'Popen', return_value=process))
        stack.enter_context(patch.object(module.os, 'kill', side_effect=AssertionError('Unexpected signal')))
        stack.enter_context(patch.object(module.time, 'sleep', side_effect=OSError('injected startup interruption') if cleanup_timeout else None))
        return process, runtime / 'process.json'

    def test_failed_start_reaps_exact_owned_child(self):
        for failure in ('stat-read', 'stat-parse', 'state-write'):
            with self.subTest(failure=failure):
                process, state = self.start_fixture(failure)
                with self.assertRaises((OSError, IndexError)):
                    module.main()
                process.terminate.assert_called_once_with()
                process.wait.assert_called_once_with(timeout=10)
                self.assertFalse(state.exists())

    def test_failed_cleanup_preserves_identity_record(self):
        process, state = self.start_fixture(cleanup_timeout=True)
        with self.assertRaisesRegex(RuntimeError, 'owned daemon 77.*exit unconfirmed'):
            module.main()
        process.terminate.assert_called_once_with()
        process.wait.assert_called_once_with(timeout=10)
        process.kill.assert_not_called()
        self.assertEqual(module.json.loads(state.read_text()), {'pid': 77, 'started': '123'})

    def test_successful_start_retains_identity_without_stopping_child(self):
        process, state = self.start_fixture()
        module.main()
        process.terminate.assert_not_called()
        process.wait.assert_not_called()
        self.assertEqual(module.json.loads(state.read_text()), {'pid': 77, 'started': '123'})

    def test_exited_start_reaps_without_termination(self):
        process, state = self.start_fixture()
        process.poll.return_value = 7
        process.wait.return_value = 7
        with self.assertRaisesRegex(RuntimeError, 'Daemon exited'):
            module.main()
        process.terminate.assert_not_called()
        process.wait.assert_called_once_with(timeout=10)
        self.assertFalse(state.exists())

    def test_separate_mode_and_no_official_integrations(self):
        for server, mode in [('nomads', 'PERSISTENCE'), ('tdm', 'TDM')]:
            value = module.config(server, Path('/tmp/isolated') / server)
            self.assertIn('ALLOWED_GAMEMODES ' + mode, value)
            self.assertIn('HUB NO', value)
            self.assertIn('TTS_ON 0', value)
            self.assertIn('SCRIPTS_DIRECTORY null', value)
            self.assertNotIn('WEBHOOK', value)
            self.assertNotIn('civ13.com', value)
            self.assertNotIn('SKIP_PERSISTENCE', value)
        self.assertNotEqual(module.PORTS['nomads'], module.PORTS['tdm'])

    def test_stop_identity_rejects_reused_pid(self):
        root = Path('/tmp/nomads')
        fields = ['S'] + ['0'] * 18 + ['123'] + ['0'] * 5
        with patch.object(Path, 'read_text', return_value='77 (DreamDaemon) ' + ' '.join(fields)), patch.object(Path, 'read_bytes', return_value=(str(module.BIN / 'DreamDaemon') + '\0' + str(root / 'civ13.dmb') + '\0').encode()):
            self.assertTrue(module.process_matches({'pid': 77, 'started': '123'}, root))
            self.assertFalse(module.process_matches({'pid': 77, 'started': '456'}, root))
            self.assertFalse(module.process_matches({'pid': 77, 'started': '123'}, Path('/tmp/tdm')))

    def test_dirty_build_stops_before_export_or_compiler(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(module.subprocess, 'check_output', side_effect=['a' * 40, ' M code/example.dm']), patch.object(module.subprocess, 'run') as run:
            with self.assertRaisesRegex(RuntimeError, 'Commit tracked changes'):
                module.build(Path(directory), Path(directory), {})
            run.assert_not_called()

    def test_stop_identity_rejects_incomplete_process_metadata(self):
        root = Path('/tmp/nomads')
        command = (str(module.BIN / 'DreamDaemon') + '\0' + str(root / 'civ13.dmb') + '\0').encode()
        for stat in ('', '77 (DreamDaemon)', '77 (DreamDaemon) S 0'):
            with self.subTest(stat=stat), patch.object(Path, 'read_text', return_value=stat), patch.object(Path, 'read_bytes', return_value=command):
                self.assertFalse(module.process_matches({'pid': 77, 'started': '123'}, root))


if __name__ == '__main__':
    unittest.main()
