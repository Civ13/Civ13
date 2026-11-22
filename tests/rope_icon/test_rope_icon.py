"""The rope coil art and the pile sprite a rope stack picks by its amount."""
import re
import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SHEETS = (ROOT / 'code/modules/materials/material_sheets.dm').read_text(encoding='utf-8', errors='replace')
sys.path.insert(0, str(ROOT / 'tests/sprites'))


class RopeIcon(unittest.TestCase):
    def test_committed_sheet_matches_the_script(self):
        run = subprocess.run([sys.executable, str(ROOT / 'tests/sprites/create_rope.py'), '--check'],
                             capture_output=True, text=True)
        self.assertEqual(run.returncode, 0, run.stdout + run.stderr)

    def test_stack_picks_a_pile_that_exists(self):
        from create_brazier_fire import read_dmi
        match = re.search(r'/obj/item/stack/material/rope/update_icon\(\)\n\ticon_state = "rope\[pile_suffix\(amount, list\(([0-9, ]+)\)\)\]"', SHEETS)
        self.assertIsNotNone(match)
        thresholds = [int(n) for n in match.group(1).split(',')]
        self.assertEqual(thresholds, sorted(set(thresholds)))
        self.assertGreater(thresholds[0], 1)             # one coil stays one coil
        states = {name for name, _, _ in read_dmi(ROOT / 'icons/obj/materials.dmi')}
        for i in range(len(thresholds) + 1):
            self.assertIn('rope' + ('_%d' % (i + 1) if i else ''), states)

    def test_taking_a_coil_refreshes_the_pile(self):
        body = SHEETS.split('/obj/item/stack/material/rope/attack_hand(', 1)[1].split('\n/', 1)[0]
        self.assertRegex(body, r'--amount\n\t+update_icon\(\)')


if __name__ == '__main__':
    unittest.main()
