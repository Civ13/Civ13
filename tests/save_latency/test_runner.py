"""Offline preparation contracts. These do not execute or validate native DM."""
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]

class PreparationTests(unittest.TestCase):
    def stage(self, *arguments):
        completed = subprocess.run([sys.executable, str(ROOT / 'tests/save_latency/run.py'),
                                    '--byond-bin', '/not-installed', '--prepare-only', *arguments],
                                   cwd=ROOT, text=True, capture_output=True, check=True)
        output = Path(re.search(r'Evidence: (.+)', completed.stdout)[1])
        metadata = json.loads((output / 'metadata.json').read_text())
        for relative, expected in metadata['sources'].items():
            self.assertEqual(hashlib.sha256((output / relative).read_bytes()).hexdigest(), expected)
        self.assertFalse((output / 'result.txt').exists())
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

    def test_version_three_and_current_reader(self):
        output, _ = self.stage('--dense', '--verify-backup')
        writer = (output / 'code/modules/persistence/saving.dm').read_text()
        reader = (output / 'code/modules/persistence/loading.dm').read_text()
        self.assertIn('savefile["/format_version"] << 3', writer)
        self.assertIn('version && version != 2 && version != 3', reader)
        self.assertIn('saved_content_refs(value, version)', reader)

    def test_pinned_old_reader_rejects_version_three(self):
        output, _ = self.stage('--negative-control', 'old-reader')
        reader = (output / 'code/modules/persistence/loading.dm').read_text()
        self.assertIn('if(version && version != 2)', reader)
        self.assertNotIn('/map_storage/proc/saved_content_refs', reader)

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

    def test_interrupted_writer_is_staged(self):
        _, metadata = self.stage('--interrupt')
        self.assertTrue(metadata['interrupt'])

if __name__ == '__main__':
    unittest.main()
