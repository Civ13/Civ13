"""Offline preparation contracts; native propagation assertions live in lighting_probe.dm."""
import json
from pathlib import Path
import subprocess
import sys
import unittest


ROOT = Path(__file__).resolve().parents[2]
RUNNER = ROOT / 'tests/world_save/run-durable-world.py'


class LightingCornerPreparation(unittest.TestCase):
    def prepare(self, control=None):
        command = [sys.executable, '-B', str(RUNNER), '--lighting', '--prepare-only']
        if control:
            command += ['--negative-control', control]
        result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        output = Path(result.stdout.split('Retained evidence: ', 1)[1].splitlines()[0])
        receipt = json.loads((output / 'receipt.json').read_text(encoding='utf-8'))
        generated = '\n'.join(path.read_text(encoding='utf-8') for path in output.glob('*.dm'))
        self.assertTrue(receipt['prepared_only'])
        self.assertFalse((output / 'compile.log').exists())
        self.assertFalse((output / 'metadata-result.json').exists())
        for name in ('lighting_corner.dm', 'lighting_source.dm'):
            self.assertIn('code/modules/lighting/' + name, receipt['production_hashes'])
        return generated

    def test_real_propagation_is_preserved(self):
        generated = self.prepare()
        self.assertIn('lighting_corner_allocation_probe()', generated)
        self.assertIn('A.smart_vis_update()', generated)
        self.assertNotIn('/datum/light_source/proc/recalc_corner', generated)

    def test_eager_control_changes_only_generated_declaration(self):
        original = (ROOT / 'code/modules/lighting/lighting_corner.dm').read_bytes()
        generated = self.prepare('lighting-eager')
        self.assertIn('var/list/datum/light_source/affecting = list() //', generated)
        self.assertEqual(original, (ROOT / 'code/modules/lighting/lighting_corner.dm').read_bytes())

    def test_shared_control_covers_both_registration_paths(self):
        original = (ROOT / 'code/modules/lighting/lighting_source.dm').read_bytes()
        generated = self.prepare('lighting-shared')
        self.assertEqual(generated.count('C.affecting = lighting_probe_shared_affecting'), 2)
        self.assertIn('var/list/lighting_probe_shared_affecting = list()', generated)
        self.assertEqual(original, (ROOT / 'code/modules/lighting/lighting_source.dm').read_bytes())


if __name__ == '__main__':
    unittest.main()
