"""Offline source-binding checks. Never compile or start a game."""
import argparse
import ast
from contextlib import redirect_stdout
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from types import SimpleNamespace
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
    def test_phase_negative_results_do_not_fall_through_to_positive_check(self):
        # Execute the runner's actual result dispatcher without compiling DM.
        tree = ast.parse((HERE / 'run-string-path.py').read_text())
        main = next(node for node in tree.body if isinstance(node, ast.FunctionDef) and node.name == 'main')
        dispatch = next(node for node in main.body if isinstance(node, ast.If)
                        and isinstance(node.test, ast.Attribute)
                        and node.test.attr == 'phase_profile_attribution_negative_control')
        dispatch_nodes = []
        for node in main.body[main.body.index(dispatch):]:
            if not isinstance(node, ast.If):
                break
            dispatch_nodes.append(node)
        executable = compile(ast.Module(body=dispatch_nodes, type_ignores=[]), '<result-dispatch>', 'exec')
        marker = self.root / 'map_saves/save_complete.txt'
        marker.parent.mkdir()
        marker.write_text('completed generation')
        for control, failure in (
            ('phase_profile_attribution_negative_control', 'phase category attribution failed'),
            ('phase_profile_negative_control', 'phase value calls missing'),
        ):
            with self.subTest(control=control):
                arguments = SimpleNamespace(phase_profile_attribution_negative_control=False,
                                            phase_profile_negative_control=False)
                setattr(arguments, control, True)
                environment = dict(args=arguments, output=self.root, actual='FAIL: expected control',
                                   read=lambda path: failure)
                exec(executable, environment)
                environment['read'] = lambda path: 'unrelated failure'
                with self.assertRaisesRegex(RuntimeError, 'Wrong .* negative failure'):
                    exec(executable, environment)

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

    def test_current_admission_precedes_profile_and_is_not_wrapped(self):
        saving = self.inputs['saving'][1].decode().replace('\r\n', '\n')
        if 'save_world_contents(' not in saving:
            self.skipTest('Legacy source has no operation-admission boundary')
        generated, _ = progress.instrument(saving, '', phase_profile=True)
        self.assertIn('/map_storage/proc/Save_World()\n\treturn run_world_operation("save")\n', generated)
        self.assertNotIn('world_save_progress_original_Save_World', generated)
        self.assertEqual(generated.count('operation.enter_contents(src, "save")'), 1)
        self.assertIn('if(!operation || !operation.enter_contents(src, "save")) return FALSE\n\tworld_save_progress_begin()\n', generated)
        for broken in ('', '\treturn TRUE\n'):
            with self.assertRaisesRegex(ValueError, 'Expected'):
                progress.instrument(saving.replace('\tif(!operation || !operation.enter_contents(src, "save")) return FALSE\n', broken), '', True)

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
