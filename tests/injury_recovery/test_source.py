"""Offline source-contract and arithmetic checks; not native gameplay evidence."""
from pathlib import Path
import unittest
ROOT = Path(__file__).resolve().parents[2]
def source(name):
    return (ROOT / name).read_text()
class Recovery(unittest.TestCase):
    def test_dispatch_covers_subtype_overrides(self):
        self.assertIn('I.process()\n\t\tI.recover_internal_damage()', source('code/game/mob/living/carbon/human/human_organs.dm'))
    def test_guards(self):
        body = source('code/modules/organs/organ.dm').split('/obj/item/organ/proc/recover_internal_damage()')[1]
        for guard in ('loc != owner', 'src in owner.internal_organs', 'owner.stat == DEAD', 'owner.inducedSSD', 'damage >= max_damage', 'ORGAN_DEAD | ORGAN_CUT_AWAY', 'rejecting', 'germ_level >= INFECTION_LEVEL_ONE', 'owner.bodytemperature < 170'):
            self.assertIn(guard, body)
        self.assertIn('is_broken() ? 0.005 : 0.01', body)
        self.assertIn('config.organ_regeneration_multiplier', body)
        self.assertIn('damage = max(0, damage - recovery', body)
    def test_partial_damage_and_severe_damage_converge(self):
        for initial in (0.001, 9, 29, 59):
            damage = initial
            for tick in range(20000):
                damage = max(0, damage - (0.005 if damage >= 30 else 0.01))
                if damage == 0:
                    break
            self.assertEqual(damage, 0)
    def test_healed_bleeding_records_do_not_emit_phantom_pain(self):
        src = source('code/modules/organs/organ_external.dm')
        self.assertIn('if (W.internal && W.damage > 0 && owner.bodytemperature >= 170)', src)
        self.assertIn('min(60, W.damage)', src)
    def test_internal_pain_scales_and_parent_is_checked(self):
        src = source('code/modules/organs/pain.dm')
        self.assertIn('if(parent)\n', src)
        self.assertIn('min(50, I.damage)', src)
        self.assertNotIn('never heals on its own', src)
        self.assertIn('min(9, damage)', source('code/modules/organs/brain.dm'))
        self.assertNotIn('damage--', source('code/modules/organs/brain.dm'))
if __name__ == '__main__':
    unittest.main()
