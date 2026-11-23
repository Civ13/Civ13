"""Source checks for issues 6970 (animal medical stacks) and 6968 (acid bath lead)."""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ANIMAL = ROOT / 'code/game/mob/living/simple_animal/simple_animal.dm'
KENOBI = ROOT / 'code/game/mob/living/simple_animal/hostile/commanded/kenobi.dm'
CONVERTERS = ROOT / 'code/game/objects/structures/converters.dm'


def block(text, header):
    start = text.index(header + '\n')
    nxt = re.search(r'^/\S', text[start + len(header) + 1:], re.M)
    return text[start:start + len(header) + 1 + nxt.start()] if nxt else text[start:]


def accepted_inputs(text, child):
    attrs = dict(re.findall(r'^\t(?:var/)?(input1?) = (\S+)', block(text, '/obj/structure/converter'), re.M))
    attrs.update(dict(re.findall(r'^\t(input1?) = (\S+)', block(text, child), re.M)))
    return {kind for kind in attrs.values() if kind != 'null'}


class AnimalMedicalTest(unittest.TestCase):
    def test_both_attackby_paths_use_the_shared_treatment(self):
        for path in (ANIMAL, KENOBI):
            text = path.read_text(encoding='utf-8')
            self.assertIn('return apply_animal_medical(O, user)', text, path.name)
            self.assertNotIn('adjustBruteLoss(-MED.heal_brute)', text, path.name)

    def test_treatment_heals_brute_and_burn_and_keeps_useless_stacks(self):
        proc = block(ANIMAL.read_text(encoding='utf-8'), '/mob/living/simple_animal/proc/apply_animal_medical(obj/item/stack/medical/MED, mob/user)')
        self.assertIn('getBruteLoss()', proc)
        self.assertIn('getBurnLoss()', proc)
        self.assertIn('adjustBurnLoss(-burn)', proc)
        keep = proc.index('if (brute <= 0 && burn <= 0)')
        self.assertLess(keep, proc.index('MED.use(1)'))
        self.assertIn('return TRUE', proc[keep:proc.index('if (brute > 0)')])


class AcidBathInputTest(unittest.TestCase):
    def test_acid_bath_accepts_only_raw_kevlar(self):
        text = CONVERTERS.read_text(encoding='utf-8')
        self.assertEqual(accepted_inputs(text, '/obj/structure/converter/acid_bath'), {'/obj/item/stack/material/rawkevlar'})

    def test_inherited_lead_secondary_would_be_caught(self):
        text = CONVERTERS.read_text(encoding='utf-8').replace(
            '\tvar/input1 = null', '\tvar/input1 = /obj/item/stack/material/lead', 1)
        self.assertIn('/obj/item/stack/material/lead', accepted_inputs(text, '/obj/structure/converter/acid_bath'))


if __name__ == '__main__':
    unittest.main()
