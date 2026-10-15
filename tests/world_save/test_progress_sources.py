"""Offline source-binding checks. Never compile or start a game."""
import argparse
from contextlib import redirect_stdout
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch


HERE = Path(__file__).resolve().parent
SOURCE_ROOT = HERE.parents[1]


def load(name, filename):
    spec = importlib.util.spec_from_file_location(name, HERE / filename)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


progress = load('progress_source_test', 'build-progress-probe.py')
backend = load('backend_source_test', 'build-gaia-phase-backend.py')


class ProgressSources(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix='civ13-progress-sources-')
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.output = self.root / 'generated'
        self.inputs = {}
        paths = dict(saving='code/modules/persistence/saving.dm',
                     functions='code/modules/persistence/functions.dm',
                     tick='code/__defines/_tick.dm')
        for name, relative in paths.items():
            data = (SOURCE_ROOT / relative).read_bytes()
            path = self.root / (name + '.dm')
            path.write_bytes(data)
            self.inputs[name] = (path, data)

    def arguments(self, hashes=True):
        arguments = ['source-test', '--output-dir', str(self.output)]
        for name, (path, data) in self.inputs.items():
            arguments += ['--' + name + '-source', str(path)]
            if hashes:
                arguments += ['--expected-' + name + '-sha256',
                              hashlib.sha256(data).hexdigest()]
        return arguments

    def test_source_bound_output_preserves_functions_and_inputs(self):
        with patch.object(sys, 'argv', self.arguments() + ['--phase-profile']):
            with redirect_stdout(io.StringIO()):
                progress.main()
        manifest = json.loads((self.output / 'manifest.json').read_text())
        self.assertTrue(manifest['phase_profile'])
        self.assertEqual((self.output / 'functions.dm').read_bytes(),
                         self.inputs['functions'][1])
        generated = (self.output / 'saving.dm').read_text()
        self.assertIn('/map_storage/proc/world_save_profile_original_BuildVarDirectory(', generated)
        self.assertIn('/map_storage/proc/world_save_profile_original_encode_saved_value(', generated)
        for name, (path, original) in self.inputs.items():
            self.assertEqual(path.read_bytes(), original)
            self.assertEqual(manifest['sources'][name]['sha256'],
                             hashlib.sha256(original).hexdigest())
        for name, expected in manifest['generated'].items():
            self.assertEqual(hashlib.sha256((self.output / name).read_bytes()).hexdigest(), expected)

    def test_wrong_source_hash_rejects_before_creating_outputs(self):
        for name in self.inputs:
            with self.subTest(source=name):
                arguments = self.arguments()
                index = arguments.index('--expected-' + name + '-sha256') + 1
                arguments[index] = '0' * 64
                with patch.object(sys, 'argv', arguments):
                    with self.assertRaisesRegex(ValueError, name + ' source hash mismatch'):
                        progress.main()
                self.assertFalse(self.output.exists())

    def test_missing_and_duplicate_anchors_reject(self):
        saving = self.inputs['saving'][1].decode().replace('\r\n', '\n')
        functions = self.inputs['functions'][1].decode().replace('\r\n', '\n')
        for anchor in ('/map_storage/proc/Save_World()\n',
                       '/map_storage/proc/encode_saved_value(savefile/F, value)\n',
                       '\tTICK_CHECK\n'):
            for duplicate in (False, True):
                with self.subTest(anchor=anchor, duplicate=duplicate):
                    changed = saving.replace(anchor, anchor + anchor if duplicate else '', 1)
                    with self.assertRaisesRegex(ValueError, 'Expected'):
                        progress.instrument(changed, functions, phase_profile=True)

    def test_legacy_backend_rejects_unfrozen_source_before_git_or_outputs(self):
        path, original = self.inputs['saving']
        path.write_bytes(original + b'\n// Deliberately outside the frozen legacy closure.\n')
        arguments = self.arguments(hashes=False) + ['--repository', str(SOURCE_ROOT)]
        with patch.object(sys, 'argv', arguments):
            with patch.object(backend.subprocess, 'run', side_effect=AssertionError('Unexpected Git access')):
                with self.assertRaisesRegex(ValueError, 'saving frozen source mismatch'):
                    backend.main()
        self.assertFalse(self.output.exists())


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-root', type=Path, default=SOURCE_ROOT)
    arguments, remaining = parser.parse_known_args()
    SOURCE_ROOT = arguments.source_root.resolve(strict=True)
    unittest.main(argv=[sys.argv[0], *remaining])
