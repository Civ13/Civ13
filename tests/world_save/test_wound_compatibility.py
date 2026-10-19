"""Historical wound-control preparation retains immutable fault sources."""
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]

class HistoricalWoundCompatibility(unittest.TestCase):
    def test_historical_bodies_and_shared_content_helper_are_staged(self):
        completed = subprocess.run([
            sys.executable, 'tests/world_save/run-durable-world.py', '--prepare-only',
            '--wounds', '--negative-control', 'wound-restore'], cwd=ROOT,
            capture_output=True, text=True, timeout=60, check=True)
        output = Path(re.search(r'Retained evidence: (.+)', completed.stdout)[1])
        receipt = json.loads((output / 'receipt.json').read_text())
        sources = [p.read_text() for p in output.glob('*.dm')]
        for relative in ('code/modules/organs/wound.dm', 'code/modules/persistence/loading.dm'):
            historical = subprocess.check_output([
                'git', 'show', receipt['wound_control_commit'] + ':' + relative],
                cwd=ROOT, text=True)
            self.assertEqual(sources.count(historical), 1, relative)
        marker = '/map_storage/proc/saved_content_refs(value, version)\n'
        helpers = [s for s in sources if marker in s]
        self.assertEqual(len(helpers), 1)
        functions = (ROOT / 'code/modules/persistence/functions.dm').read_text()
        self.assertTrue(helpers[0].startswith(functions + '\n'))
        helper = helpers[0][len(functions) + 1:]
        self.assertEqual(hashlib.sha256(helper.encode()).hexdigest(),
                         receipt['wound_control_compatibility_helper_sha256'])
        self.assertTrue(receipt['prepared_only'])
        self.assertFalse((output / 'compile.log').exists())

if __name__ == '__main__':
    unittest.main()
