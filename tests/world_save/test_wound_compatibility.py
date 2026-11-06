"""Wound defect control: current sources with only the #3216 fix reverted."""
import contextlib
import importlib.util
import io
import json
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
WOUND = 'code/modules/organs/wound.dm'
LOADING = 'code/modules/persistence/loading.dm'


class HistoricalWoundCompatibility(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        spec = importlib.util.spec_from_file_location('wound_compatibility_runner',
            ROOT / 'tests/world_save/run-durable-world.py')
        cls.runner = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.runner)
        cls.wound = (ROOT / WOUND).read_text(encoding='utf-8')
        cls.loading = (ROOT / LOADING).read_text(encoding='utf-8')

    def setUp(self):
        self.spawn = self.enterContext(patch.object(subprocess, 'Popen',
            side_effect=AssertionError('Native process forbidden')))
        self.sockets = self.enterContext(patch.object(socket, 'socket',
            side_effect=AssertionError('Socket forbidden')))

    def tearDown(self):
        self.spawn.assert_not_called()
        self.sockets.assert_not_called()

    def test_only_the_restore_fix_is_reverted(self):
        wound, loading, line = self.runner.historical_wound_sources(self.wound, self.loading)
        # The wound file loses only the restore-shell parameter and early return.
        self.assertNotIn('restore_shell', wound)
        self.assertEqual(wound.splitlines()[line - 1], '\tvar/damage_amt = lost_limb.max_damage')
        self.assertIn(self.runner.WOUND_HISTORICAL_HEADER, wound)
        before = self.wound.index(self.runner.WOUND_FIX_HEADER)
        after = self.wound.index(self.runner.WOUND_FAILING_READ)
        self.assertEqual(wound, self.wound[:before] + self.runner.WOUND_HISTORICAL_HEADER + self.wound[after:])
        # The loader loses only the lost-limb shell branch and its validation.
        self.assertNotIn('/datum/wound/lost_limb', loading)
        self.assertEqual(loading, self.loading.replace(self.runner.WOUND_FIX_LOADER_BRANCH, '', 1)
                         .replace(self.runner.WOUND_FIX_LOADER_CHECK, '', 1))
        self.assertIn('\t\telse\n\t\t\t// Non-atom datums have no location argument.', loading)

    def test_changed_or_repeated_fix_anchors_are_refused(self):
        header = self.runner.WOUND_FIX_HEADER
        read = self.runner.WOUND_FAILING_READ
        for wound in (self.wound.replace(header, header.replace('restore_shell', 'restored'), 1),
                      self.wound.replace(read, '\tvar/damage_amt = 0\n', 1),
                      self.wound + header,
                      self.wound + read,
                      self.wound.replace('\tif(restore_shell)\n\t\treturn ..(0)\n', '', 1)):
            with self.subTest(), self.assertRaisesRegex(RuntimeError, 'constructor'):
                self.runner.historical_wound_sources(wound, self.loading)
        for anchor in (self.runner.WOUND_FIX_LOADER_BRANCH, self.runner.WOUND_FIX_LOADER_CHECK):
            for loading in (self.loading.replace(anchor, '', 1), self.loading + anchor):
                with self.subTest(anchor=anchor), self.assertRaisesRegex(RuntimeError, 'loader'):
                    self.runner.historical_wound_sources(self.wound, loading)

    def test_control_is_staged_from_current_sources_without_git_or_launches(self):
        def git_read(command, **kwargs):
            self.assertEqual(command[0], 'git')
            self.assertNotEqual(command[1], 'show')
            if command[1:] == ['rev-parse', 'HEAD']:
                return 'offline-identity\n'
            self.assertEqual(command[1:], ['diff', 'HEAD'])
            return b''

        wound, loading, line = self.runner.historical_wound_sources(self.wound, self.loading)
        with tempfile.TemporaryDirectory() as directory, \
                patch.object(self.runner.tempfile, 'mkdtemp', return_value=directory), \
                patch.object(self.runner.subprocess, 'check_output', side_effect=git_read), \
                patch.object(sys, 'argv', ['run-durable-world.py', '--prepare-only',
                    '--wounds', '--negative-control', 'wound-restore']), \
                contextlib.redirect_stdout(io.StringIO()):
            self.runner.main()
            output = Path(directory)
            receipt = json.loads((output / 'receipt.json').read_text(encoding='utf-8'))
            self.assertEqual((output / receipt['wound_control_source']).read_text(encoding='utf-8'), wound)
            self.assertEqual((output / receipt['generated_sources'][LOADING]).read_text(encoding='utf-8'), loading)
            self.assertEqual(receipt['wound_control_line'], line)
            self.assertEqual(receipt['wound_control_reverted_fix'], '#3216')
            self.assertTrue(receipt['prepared_only'])
            self.assertFalse((output / 'compile.log').exists())
            self.assertFalse(list(output.glob('*.dmb')))
            self.assertFalse((output / 'metadata-result.json').exists())


if __name__ == '__main__':
    unittest.main()
