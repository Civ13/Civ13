"""Offline source contract for Unbinding an enemy ward; does not execute DM."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


def read(rel):
    return (ROOT / rel).read_text(encoding='utf-8')


TEXT = read('code/modules/divine/arcane_unbind.dm')
ENCHANT = read('code/modules/divine/arcane_enchant.dm')


def body(text, header):
    return text.split(header, 1)[1].split('\n/', 1)[0]


class ArcaneUnbindSource(unittest.TestCase):
    def test_included(self):
        self.assertIn('#include "code\\modules\\divine\\arcane_unbind.dm"', read('civ13.dme'))

    def test_worked_through_imbue_beside_a_lit_fire(self):
        self.assertIn('"Work an Unbinding"', ENCHANT)
        self.assertIn('arcane_fires_beside()', ENCHANT)
        self.assertIn('arcane_unbind_fire(O)', read('code/modules/divine/arcane_ward.dm'))
        fire = body(TEXT, '/proc/arcane_unbind_fire(')
        self.assertIn('F.on && F.open_flame', fire)

    def test_only_other_gods_wards_over_the_fire(self):
        wards = body(TEXT, '/mob/living/human/proc/arcane_unbind_wards(')
        self.assertIn('wards_at(get_turf(fire))', wards)
        self.assertIn('repo.magic_repo_deity != god', wards)

    def test_needs_three_affliction_and_a_vigil(self):
        self.assertIn('#define ARCANE_UNBIND_MIN 3', TEXT)
        self.assertIn('"affliction"', body(TEXT, '/mob/living/human/proc/arcane_unbind_materials('))
        self.assertIn('arcane_vigil_holds()', body(TEXT, '/mob/living/human/proc/arcane_unbind_problem('))
        self.assertIn('if (kind == "unbinding" || (needs && needs["vigil"]))', ENCHANT)

    def test_drains_fifty_per_strength_and_logs(self):
        self.assertIn('#define ARCANE_UNBIND_PER_STRENGTH 50', TEXT)
        apply = body(TEXT, '/mob/living/human/proc/arcane_unbind_apply(')
        self.assertIn('ward_drain(repo, amount, src)', apply)
        self.assertIn('log_admin("Unbinding:', apply)
        # the amount is worked out before the materials burn
        imbue = body(ENCHANT, '/mob/living/human/proc/arcane_imbue_apply(')
        self.assertLess(imbue.index('arcane_unbind_amount(materials)'), imbue.index('qdel(M)'))

    def test_not_an_enchantment(self):
        self.assertNotIn('"unbinding" = "', ENCHANT.split('arcane_enchant_names = list(', 1)[1].split(')', 1)[0])


if __name__ == '__main__':
    unittest.main()
