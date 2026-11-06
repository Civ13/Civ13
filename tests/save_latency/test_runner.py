"""Offline preparation contracts. These do not execute or validate native DM."""
import ast
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import socket
import subprocess
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]

class PreparationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        spec = importlib.util.spec_from_file_location('save_latency_preparation', ROOT / 'tests/save_latency/run.py')
        cls.runner = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.runner)
        # Only immutable/local Git reads precede the process/socket prohibition.
        commands = [('git', 'rev-parse', 'HEAD'), ('git', 'diff', 'HEAD')]
        cls.git_reads = {command: subprocess.check_output(command, cwd=ROOT) for command in commands}

    def setUp(self):
        self.spawn = self.enterContext(patch.object(subprocess, 'Popen', side_effect=AssertionError('Native process forbidden')))
        self.sockets = self.enterContext(patch.object(socket, 'socket', side_effect=AssertionError('Socket forbidden')))

    def tearDown(self):
        self.spawn.assert_not_called()
        self.sockets.assert_not_called()

    def stage(self, *arguments):
        def git_read(command, **kwargs):
            self.assertIn(tuple(command), self.git_reads)
            value = self.git_reads[tuple(command)]
            return value.decode('utf-8') if kwargs.get('text') else value
        output = Path(self.enterContext(tempfile.TemporaryDirectory(prefix='save-latency-offline-')))
        with patch.object(self.runner.tempfile, 'mkdtemp', return_value=str(output)), \
                patch.object(self.runner.subprocess, 'check_output', side_effect=git_read), \
                patch.object(sys, 'argv', ['run.py', '--byond-bin', '/not-installed', '--prepare-only', *arguments]), \
                patch('builtins.print'):
            self.runner.main()
        metadata = json.loads((output / 'metadata.json').read_text())
        for relative, expected in metadata['sources'].items():
            self.assertEqual(hashlib.sha256((output / relative).read_bytes()).hexdigest(), expected)
        for name in ('result.txt', 'compile.log', 'runtime.log', 'probe.dmb'):
            self.assertFalse((output / name).exists())
        return output, metadata

    def test_current_admission_and_transfers_are_staged(self):
        output, _ = self.stage()
        source = (output / 'code/modules/persistence/saving.dm').read_text()
        self.assertIn('return run_world_operation("save")', source)
        for call in ('operation.enter_contents', 'prepare_player_ownership()', 'capture_durable_world()',
                     'capture_round_state(', 'durable_export.bind_entry', 'before_save_context',
                     'require_export_frame(frame)', 'drain_save_transfers(frame)'):
            self.assertIn(call, source)
        self.assertIn('player_reclaim.dm', (output / 'probe.dme').read_text())
        self.assertIn('world_z_budget.dm', (output / 'probe.dme').read_text())
        functions = (output / 'code/modules/persistence/functions.dm').read_text()
        self.assertIn('storage.dimension_budget_hold || world_z_budget.active', functions)
        publication = source[source.index('var/content_value = encode_saved_contents'): ]
        self.assertLess(publication.index('drain_save_transfers(frame)'), publication.index('savefile["content"] << content_value'))

    def test_version_three_and_current_reader(self):
        output, _ = self.stage('--dense', '--verify-backup')
        writer = (output / 'code/modules/persistence/saving.dm').read_text()
        reader = (output / 'code/modules/persistence/loading.dm').read_text()
        self.assertIn('savefile["/format_version"] << 3', writer)
        self.assertIn('version && version != 2 && version != 3', reader)
        self.assertIn('saved_content_refs(value, version)', reader)

    def test_retired_old_reader_control_is_refused(self):
        # The format-3 refusal control was retired once saves moved to format 5.
        with patch.object(sys, 'argv', ['run.py', '--byond-bin', '/not-installed', '--prepare-only',
                                        '--negative-control', 'old-reader']), \
                patch('sys.stderr'), self.assertRaises(SystemExit):
            self.runner.main()

    def test_yield_mutation_is_effective(self):
        output, _ = self.stage('--negative-control', 'yield')
        writer = (output / 'code/modules/persistence/saving.dm').read_text()
        self.assertNotRegex(writer, r'(?m)^\s*sleep\((world.tick_lag|0)\)$')
        self.assertGreaterEqual(writer.count('negative control: no yield'), 2)

    def test_mutation_scenarios_are_fail_closed(self):
        for scenario in ('movement', 'parent-deletion', 'concurrent'):
            with self.subTest(scenario=scenario):
                output, metadata = self.stage('--scenario', scenario)
                self.assertEqual(metadata['scenario'], scenario)
                probe = (output / 'tests/save_latency/probe.dm').read_text()
                self.assertIn('invalidated frame was published', probe)
                self.assertIn('prior completed generation lost', probe)

    def test_native_launch_preserves_trusted_isolated_contract(self):
        runner = (ROOT / 'tests/save_latency/run.py').read_text()
        self.assertIn("['-trusted','-log','runtime.log']", runner)
        self.assertNotIn("'-safe'", runner)
        probe = (ROOT / 'tests/save_latency/probe.dm').read_text()
        self.assertIn('return ..("none")', probe)
        self.assertIn('visibility = 0', probe)

    def test_interrupted_writer_is_staged(self):
        _, metadata = self.stage('--interrupt')
        self.assertTrue(metadata['interrupt'])

if __name__ == '__main__':
    unittest.main()
