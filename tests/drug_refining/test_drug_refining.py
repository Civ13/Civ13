"""Offline source contracts for apothecary and refined drugs. Gameplay is
covered by the native probe:
python3 tests/ecology_spawning/run_linux.py . tests/drug_refining/probe.dm 300
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/reagents/drug_refining.dm'


class DrugRefiningSourceTests(unittest.TestCase):
    def setUp(self):
        self.source = SOURCE.read_text(encoding='utf-8')

    def test_included_after_classes(self):
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
        self.assertIn('#include "code\\modules\\reagents\\drug_refining.dm"', dme)

    def test_refining_is_research_gated(self):
        for row in ('"opium" = list("morphine", "pharmacology"',
                    '"coca_leaf" = list("cocaine", "pharmacology"',
                    '"morphine" = list("heroin", "modern_medicine"'):
            self.assertIn(row, self.source)
        self.assertIn('research_node_known(H, entry[2])', self.source)

    def test_distiller_calls_the_hook(self):
        machinery = (ROOT / 'code/modules/reagents/Chemistry-Machinery.dm').read_text(encoding='utf-8')
        self.assertIn('drug_refine(largest, operator)', machinery)
        glass = (ROOT / 'code/modules/reagents/reagent_containers/glass.dm').read_text(encoding='utf-8')
        self.assertIn('paper_twist_fold(src, W, user)', glass)

    def test_no_hand_crafts_left(self):
        recipes = (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8')
        self.assertNotIn('RECIPE: /material/coca/,cocaine,', recipes)
        self.assertNotIn('RECIPE: /material/tobacco/,cigarette,', recipes)

    def test_new_reagents_join_the_opioid_class(self):
        classes = (ROOT / 'code/modules/reagents/drug_classes.dm').read_text(encoding='utf-8')
        for rid in ('laudanum', 'heroin'):
            self.assertIn(f'"{rid}"', classes)
            body = self.source.split(f'/datum/reagent/{rid}/affect_blood(', 1)[1].split('\n/', 1)[0]
            self.assertIn('M.drug_dose("opioid"', body)
        self.assertIn('inhibitors = list("acetone" = 1)', self.source)

    def test_no_spawn_or_sleep(self):
        self.assertNotRegex(self.source, r'\b(spawn|sleep)\(')


if __name__ == '__main__':
    unittest.main()
