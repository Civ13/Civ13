"""Offline mutation/oracle contracts. No compiler, daemon or game is launched."""
import importlib.util
import contextlib
import hashlib
import io
import json
import shlex
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
    def test_ci_pairs_unadapted_positive_and_publication_control_in_existing_budget(self):
        workflow = (ROOT / '.github/workflows/test.yml').read_text()
        step = workflow.split('      - name: Verify bounded admitted save traversal and backup recovery\n', 1)[1].split('      - name:', 1)[0]
        self.assertIn('        timeout-minutes: 40\n', step)
        self.assertIn("if: needs.changes.outputs.extensive == 'true' || contains(fromJSON(needs.changes.outputs.new_tests || '[]'), 'tests/save_latency') || inputs.save_latency_regressions", step)
        self.assertIn('saving_sha=$(sha256sum code/modules/persistence/saving.dm', step)
        lines = [line.strip() for line in step.splitlines()]
        commands = [shlex.split(line) for line in lines
                    if line.startswith('python3 tests/world_save/run-string-path.py ')]
        positive = ['python3', 'tests/world_save/run-string-path.py', '--byond-bin',
                    '$PWD/BYOND/byond/bin', '--byond-archive', '$PWD/BYOND/pinned.zip',
                    '--expected-saving-sha256', '$saving_sha']
        self.assertEqual(commands[:2], [positive, positive + ['--publication-negative-control']])
        self.assertEqual(step.count('--publication-negative-control'), 1)
        positive_line = next(index for index, line in enumerate(lines)
                             if line.startswith('python3 tests/world_save/run-string-path.py '))
        self.assertEqual(shlex.split(lines[positive_line + 1]), positive + ['--publication-negative-control'])
        self.assertIn('export TMPDIR="$RUNNER_TEMP/save-latency"', step)
        self.assertTrue('BYOND_MAJOR: "516"' in workflow, 'Pinned BYOND major changed')
        self.assertTrue('BYOND_MINOR: "1681"' in workflow, 'Pinned BYOND minor changed')
        artifact = workflow.split('      - name: Retain bounded save source and native evidence\n', 1)[1].split('      - name:', 1)[0]
        self.assertIn("if: always() && needs.changes.result == 'success' && steps.save_latency.outcome != 'skipped'", artifact)
        self.assertIn('path: ${{ runner.temp }}/save-latency/', artifact)

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
