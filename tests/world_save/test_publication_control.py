"""Offline mutation/oracle contracts. No compiler, daemon or game is launched."""
import importlib.util
import contextlib
import hashlib
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
RUNNER_PATH = Path(__file__).with_name('run-string-path.py')
SPEC = importlib.util.spec_from_file_location('publication_runner', RUNNER_PATH)
RUNNER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(RUNNER)


class PublicationControlTests(unittest.TestCase):
    def test_only_final_drain_is_removed(self):
        path = ROOT / 'code/modules/persistence/saving.dm'
        before = path.read_bytes()
        source = before.decode().replace('\r\n', '\n')
        changed = RUNNER.omit_final_publication_check(source)
        self.assertEqual(changed.count('drain_save_transfers(frame)'),
                         source.count('drain_save_transfers(frame)') - 1)
        self.assertIn('\t\tdrain_save_transfers(frame)\n\t\tif(frame.accepts_children)', changed)
        self.assertEqual(changed, source.replace(RUNNER.PUBLICATION_ANCHOR,
                         RUNNER.PUBLICATION_ANCHOR.split('\n', 1)[1], 1))
        self.assertEqual(path.read_bytes(), before)

    def test_missing_duplicate_and_changed_anchors_refuse(self):
        anchor = RUNNER.PUBLICATION_ANCHOR
        for source in ('', anchor + anchor, anchor.replace('content_value', 'other')):
            with self.subTest(source=source), self.assertRaisesRegex(RuntimeError, 'exactly one anchor'):
                RUNNER.omit_final_publication_check(source)

    def test_only_exact_intended_failure_is_accepted(self):
        expected = RUNNER.PUBLICATION_FAILURE
        RUNNER.validate_publication_control('FAIL: ' + expected, expected)
        for actual, failure in [('PASS', expected), ('FAIL: unrelated', expected),
                                ('FAIL: ' + expected, 'unrelated'),
                                ('FAIL: ' + expected + ' extra', expected)]:
            with self.subTest(actual=actual, failure=failure):
                with self.assertRaisesRegex(RuntimeError, 'Wrong publication negative failure'):
                    RUNNER.validate_publication_control(actual, failure)

    def test_incompatible_control_refuses_before_native_discovery(self):
        result = subprocess.run([sys.executable, str(RUNNER_PATH), '--byond-bin', '/not-installed',
                                 '--expected-saving-sha256', 'unused', '--publication-negative-control',
                                 '--negative-control', '--prepare-only'], capture_output=True, text=True)
        self.assertEqual(result.returncode, 2)
        self.assertIn('Keep publication control separate', result.stderr)

    def test_existing_positive_and_movement_fixture_remain(self):
        fixture = (ROOT / 'tests/world_save/transfers.dm').read_text()
        self.assertIn('for(var/mutate in list(FALSE, TRUE))', fixture)
        self.assertIn('Chunk transfer publication did not detect late movement', fixture)
        self.assertIn('Version-3 paid transfer lost ownership or value', fixture)

    def test_prepare_only_stages_exact_mutation_without_native_execution(self):
        source_path = ROOT / 'code/modules/persistence/saving.dm'
        before = source_path.read_bytes()
        digest = hashlib.sha256(before).hexdigest()
        with tempfile.TemporaryDirectory(prefix='publication-prepare-') as directory:
            root = Path(directory)
            output = root / 'generated'
            output.mkdir()
            arguments = [str(RUNNER_PATH), '--byond-bin', str(root),
                         '--expected-saving-sha256', digest,
                         '--prepare-only', '--publication-negative-control']
            with patch.object(sys, 'argv', arguments), \
                    patch.object(RUNNER.tempfile, 'mkdtemp', return_value=str(output)), \
                    patch.object(RUNNER.subprocess, 'Popen',
                                 side_effect=AssertionError('Native execution forbidden')) as native, \
                    contextlib.redirect_stdout(io.StringIO()):
                RUNNER.main()
            generated = output / 'saving.dm'
            expected = RUNNER.omit_final_publication_check(
                before.decode().replace('\r\n', '\n'))
            self.assertEqual(generated.read_text(), expected)
            receipt = json.loads((output / 'source-inputs.json').read_text())
            self.assertEqual(receipt['original']['code/modules/persistence/saving.dm'], digest)
            self.assertEqual(receipt['generated']['saving.dm'],
                             hashlib.sha256(generated.read_bytes()).hexdigest())
            self.assertFalse((output / 'cleanup.json').exists())
            native.assert_not_called()
        self.assertEqual(source_path.read_bytes(), before)


if __name__ == '__main__':
    unittest.main()
