"""Historical defect control with current roof dependencies; never a historical build."""
import contextlib
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import re
import socket
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
BASELINE = 'd0ffbfb2335eb735756b998f3f2ff617c28f144b'


class HistoricalWoundCompatibility(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        spec = importlib.util.spec_from_file_location('wound_compatibility_runner',
            ROOT / 'tests/world_save/run-durable-world.py')
        cls.runner = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.runner)
        # Read immutable Git blobs before prohibiting every launch during preparation.
        cls.historical = {relative: subprocess.check_output([
            'git', 'show', BASELINE + ':' + relative], cwd=ROOT)
            for relative in ('code/modules/organs/wound.dm', 'code/modules/persistence/loading.dm')}
        cls.loading = (ROOT / 'code/modules/persistence/loading.dm').read_text(encoding='utf-8')
        cls.functions = (ROOT / 'code/modules/persistence/functions.dm').read_text(encoding='utf-8')

    def setUp(self):
        self.spawn = self.enterContext(patch.object(subprocess, 'Popen',
            side_effect=AssertionError('Native process forbidden')))
        self.sockets = self.enterContext(patch.object(socket, 'socket',
            side_effect=AssertionError('Socket forbidden')))

    def tearDown(self):
        self.spawn.assert_not_called()
        self.sockets.assert_not_called()

    def test_historical_bytes_and_exact_current_roof_dependencies_are_staged_without_launches(self):
        def git_read(command, **kwargs):
            self.assertEqual(command[0], 'git')
            if command[1] == 'show':
                self.assertTrue(command[2].startswith(BASELINE + ':'))
                return self.historical[command[2].split(':', 1)[1]].decode('utf-8')
            if command[1:] == ['rev-parse', 'HEAD']:
                return 'offline-identity\n'
            self.assertEqual(command[1:], ['diff', 'HEAD'])
            return b''

        with tempfile.TemporaryDirectory() as directory, \
                patch.object(self.runner.tempfile, 'mkdtemp', return_value=directory), \
                patch.object(self.runner.subprocess, 'check_output', side_effect=git_read), \
                patch.object(sys, 'argv', ['run-durable-world.py', '--prepare-only',
                    '--wounds', '--negative-control', 'wound-restore']), \
                contextlib.redirect_stdout(io.StringIO()):
            self.runner.main()
            output = Path(directory)
            receipt = json.loads((output / 'receipt.json').read_text(encoding='utf-8'))
            sources = [p.read_bytes() for p in output.glob('*.dm')]
            for relative, historical in self.historical.items():
                self.assertEqual(sources.count(historical), 1, relative)
            self.assertEqual((output / receipt['wound_control_source']).read_bytes(),
                             self.historical['code/modules/organs/wound.dm'])
            roof = self.loading[:self.loading.index('\n/map_storage/proc/Load_Entry(')]
            expected = self.functions + '\n' + roof
            self.assertEqual(sources.count(expected.encode()), 1)
            combined = b'\n'.join(sources).decode('utf-8')
            self.assertEqual(combined.count(roof), 1)
            for name in re.findall(r'^/map_storage/proc/(\w+)\(', roof, re.M):
                self.assertEqual(len(re.findall(r'^/map_storage/proc/' + name + r'\(', combined, re.M)), 1)
            self.assertEqual(receipt['wound_control_commit'], BASELINE)
            self.assertEqual(hashlib.sha256(roof.encode()).hexdigest(),
                             receipt['wound_control_roof_helpers_sha256'])
            self.assertTrue(receipt['prepared_only'])
            self.assertFalse((output / 'compile.log').exists())
            self.assertFalse(list(output.glob('*.dmb')))
            self.assertFalse((output / 'metadata-result.json').exists())

    def test_roof_extraction_rejects_missing_or_repeated_boundaries(self):
        end = '\n/map_storage/proc/Load_Entry('
        for changed in (self.loading.replace('// Only roof transformations', '// Changed roof transformations', 1),
                        self.loading.replace(end, '\n/map_storage/proc/Changed_Load_Entry(', 1),
                        self.loading + end,
                        self.loading + self.loading[:self.loading.index(end)]):
            with self.subTest(), self.assertRaisesRegex(RuntimeError, 'compatibility anchors changed'):
                self.runner.historical_wound_roof_helpers(changed, self.functions)

    def test_roof_extraction_rejects_missing_or_duplicate_members_and_procedures(self):
        for before, after in (
                ('\tvar/list/validated_roof_types = list()\n', ''),
                ('\tvar/list/validated_roof_types = list()\n', '\tvar/list/validated_roof_types = list()\n' * 2),
                ('/map_storage/proc/clear_saved_roof_areas()', '/map_storage/proc/renamed_clear_saved_roof_areas()'),
                ('/map_storage/proc/clear_saved_roof_areas()', '/map_storage/proc/clear_saved_roof_areas()\n/map_storage/proc/clear_saved_roof_areas()')):
            with self.subTest(before=before), self.assertRaisesRegex(RuntimeError, 'compatibility (members|procedures) changed'):
                self.runner.historical_wound_roof_helpers(self.loading.replace(before, after, 1), self.functions)

    def test_roof_extraction_rejects_existing_dependency_declarations(self):
        for duplicate in ('\n/map_storage/proc/restore_validated_roof(atom/roof)\n',
                          '\n\tvar/list/validated_roof_areas = list()\n'):
            with self.subTest(), self.assertRaisesRegex(RuntimeError, 'compatibility dependencies duplicated'):
                self.runner.historical_wound_roof_helpers(self.loading, self.functions + duplicate)


if __name__ == '__main__':
    unittest.main()
