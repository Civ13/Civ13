"""Offline source contracts for drugs by class. Gameplay is covered by the
native probe: python3 tests/ecology_spawning/run_linux.py . tests/drug_classes/probe.dm 300
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/reagents/drug_classes.dm'
REAGENTS = ROOT / 'code/modules/reagents/Chemistry-Reagents'


class DrugClassSourceTests(unittest.TestCase):
    def setUp(self):
        self.source = SOURCE.read_text(encoding='utf-8')

    def test_included(self):
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
        self.assertIn('#include "code\\modules\\reagents\\drug_classes.dm"', dme)

    def test_no_single_reagent_addiction_keys(self):
        # Dependence is per class; old per-drug keys only survive as a load migration.
        for path in list(REAGENTS.glob('*.dm')) + [ROOT / 'code/modules/1713/jobs/civilian.dm']:
            text = path.read_text(encoding='utf-8', errors='ignore')
            self.assertNotRegex(text, r'addictions\["(cocaine|opium|tobacco)"\]', path.name)
        defines = (ROOT / 'code/game/mob/living/carbon/carbon_defines.dm').read_text(encoding='utf-8')
        self.assertIn('"opioid" = 0, "stimulant" = 0, "nicotine" = 0, "cannabis" = 0, "caffeine" = 0, "alcohol" = 0', defines)

    def test_hooks(self):
        life = (ROOT / 'code/game/mob/living/carbon/human/human_life.dm').read_text(encoding='utf-8')
        self.assertIn('\thandle_drugs()', life)
        self.assertNotIn('ingested.has_reagent("opium")', life)
        self.assertNotIn('ingested.has_reagent("cocaine")', life)
        base = (ROOT / 'code/modules/reagents/Chemistry-Reagents.dm').read_text(encoding='utf-8')
        self.assertIn('dose > overdose_limit(M)', base)
        examine = (ROOT / 'code/game/mob/living/carbon/human/examine.dm').read_text(encoding='utf-8')
        self.assertIn('msg += drug_examine_text(T)', examine)

    def test_classification_table_and_precedence(self):
        # Source projection only: the native probe remains the gameplay check.
        factory = self.source.split('/proc/drug_class_reagents()', 1)[1].split('\n/', 1)[0]
        entries = re.findall(r'"([^"]+)" = list\(([^)]*)\)', factory)
        table = {key: re.findall(r'"([^"]+)"', values) for key, values in entries}
        expected = {
            'opioid': ['opium', 'morphine', 'tramadol', 'laudanum', 'heroin', 'poppy_tea'],
            'stimulant': ['cocaine', 'crack', 'methamphetamine', 'dragon_powder', 'coca_leaf', 'coca_tea', 'khat'],
            'nicotine': ['nicotine'],
            'cannabis': ['thc'],
            'caffeine': ['coffee'],
            'alcohol': [],
        }
        self.assertEqual(list(table.items()), list(expected.items()))
        self.assertIn('return list(', factory)  # Public callers still get fresh lists.
        self.assertNotIn('static', factory)

        classifier = self.source.split('/proc/drug_reagent_class(datum/reagent/R)', 1)[1].split('\n/', 1)[0]
        self.assertLess(classifier.index('if (!R)'), classifier.index('istype(R, /datum/reagent/ethanol)'))
        self.assertLess(classifier.index('istype(R, /datum/reagent/ethanol)'), classifier.index('istype(R, /datum/reagent/drink/coffee)'))
        self.assertLess(classifier.index('istype(R, /datum/reagent/drink/coffee)'), classifier.index('for (var/class in table)'))
        self.assertIn('if (R.id in table[class])\n\t\t\treturn class', classifier)
        self.assertIn('return null', classifier)
        # The retained table is private and read-only within this proc.
        code = '\n'.join(line for line in classifier.splitlines() if not line.lstrip().startswith('//'))
        self.assertEqual(len(re.findall(r'\btable\b', code)), 5)
        self.assertIn('var/static/list/table\n\tif (!table)\n\t\ttable = drug_class_reagents()', code)

        def project(reagent_id):
            return next((kind for kind, ids in table.items() if reagent_id in ids), None)

        for kind, ids in expected.items():
            for reagent_id in ids:
                self.assertEqual(project(reagent_id), kind)
        for missing in (None, '', 'not-a-drug', 'Opium'):
            self.assertIsNone(project(missing))
        # Mutation control: removal of a listed ID is caught by the projection.
        table['opioid'].remove('opium')
        self.assertIsNone(project('opium'))

    def test_every_drug_doses_its_class(self):
        expected = {
            'Medicine': ('opium', 'cocaine', 'crack', 'pervitin', 'morphine', 'tramadol', 'dragonpowder'),
            'Toxins': ('thc', 'nicotine'),
        }
        for file, names in expected.items():
            text = (REAGENTS / f'Chemistry-Reagents-{file}.dm').read_text(encoding='utf-8')
            for name in names:
                body = text.split(f'/datum/reagent/{name}/affect_blood(', 1)[1].split('\n/', 1)[0]
                self.assertIn('M.drug_dose("', body, name)

    def test_dangers(self):
        med = (REAGENTS / 'Chemistry-Reagents-Medicine.dm').read_text(encoding='utf-8')
        opium = med.split('/datum/reagent/opium/overdose(', 1)[1].split('\n/', 1)[0]
        self.assertIn('adjustOxyLoss', opium)
        cocaine = med.split('/datum/reagent/cocaine/overdose(', 1)[1].split('\n/', 1)[0]
        self.assertIn('drug_heart_strain', cocaine)
        mixing = self.source.split('/mob/living/human/proc/drug_mixing()', 1)[1].split('\n/', 1)[0]
        self.assertIn('drug_class_active("opioid") && drug_class_active("alcohol")', mixing)
        self.assertLess(float(re.search(r'DRUG_DEPENDENCE_DECAY ([\d.]+)', self.source)[1]),
                        float(re.search(r'DRUG_TOLERANCE_DECAY ([\d.]+)', self.source)[1]))

    def test_drug_mood_uses_the_shared_mood_setter(self):
        # Drug mood sites left tests/mood_sleep/original_writes.json when tolerance
        # began scaling them; they still go through adjust_mood and its sleep rules.
        body = self.source.split('/mob/living/human/proc/drug_mood(', 1)[1].split('\n/', 1)[0]
        self.assertIn('adjust_mood(amount * drug_effect_scale(class), reason)', body)

    def test_no_spawn_or_sleep(self):
        self.assertNotRegex(self.source, r'\b(spawn|sleep)\(')


if __name__ == '__main__':
    unittest.main()
