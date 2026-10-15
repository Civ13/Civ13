"""Offline contracts. No WSL, compiler, daemon, signals or live sockets."""
import importlib.util
from pathlib import Path
import sys
import tempfile
import types
import unittest
from unittest.mock import patch

if sys.platform == 'win32':
    sys.modules.setdefault('fcntl', types.SimpleNamespace(LOCK_EX=2, flock=lambda *_: None))
spec = importlib.util.spec_from_file_location('local_wsl', Path(__file__).resolve().parents[1] / 'scripts/local-wsl.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class LocalWslTests(unittest.TestCase):
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
