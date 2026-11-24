"""Land registry and deeds: source contract checks.

    python3 tests/land_registry/test_source.py
Native probe: python3 tests/ecology_spawning/run_linux.py . tests/land_registry/probe.dm
"""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/game/mob/groups/land_registry.dm'


class LandRegistrySource(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = SOURCE.read_text(encoding='utf-8')

    def test_included_after_treasury(self):
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
        self.assertIn('#include "code\\game\\mob\\groups\\faction_treasury.dm"\n#include "code\\game\\mob\\groups\\land_registry.dm"', dme)

    def test_recipe_and_research(self):
        recipes = (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8')
        self.assertIn('RECIPE: /material/stone/,boundary stone,/obj/structure/boundary_stone,', recipes)
        self.assertNotIn('/obj/item/land_deed', recipes)  # deeds come only from the register
        research = (ROOT / 'code/modules/research_tree/research_node.dm').read_text(encoding='utf-8')
        self.assertIn('"/obj/structure/boundary_stone" = "early_economy"', research)

    def test_hammer_can_remove_marker_without_unclaiming_land(self):
        marker = self.text.split('/obj/structure/boundary_stone\n', 1)[1].split('\n/', 1)[0]
        self.assertIn('\n\tnot_disassemblable = FALSE', marker)
        self.assertIn('\n\tdismantle_wood_fallback = FALSE', marker)
        destroy = self.text.split('/obj/structure/boundary_stone/Destroy()\n', 1)[1].split('\n/', 1)[0]
        self.assertEqual(destroy.strip().splitlines(), ['boundary_stones -= src', '\treturn ..()'])

    def test_rename_and_normalize_hooks(self):
        roster = (ROOT / 'code/game/mob/groups/faction_roster.dm').read_text(encoding='utf-8')
        self.assertIn('land_rename(old_name, new_name)', roster)
        self.assertIn('land_normalize()', roster)

    def test_registrar_rechecked_after_prompts(self):
        stone = self.text.split('/obj/structure/boundary_stone/attack_hand(', 1)[1].split('\n/', 1)[0]
        after = stone.split('var/choice = WWinput(', 1)[1]
        self.assertGreaterEqual(after.count('faction_power(user, faction, "registry")'), 4)

    def test_deed_never_opens_jails_or_the_treasury(self):
        locks = self.text.split('/obj/item/land_deed/proc/lockables(', 1)[1].split('\n/', 1)[0]
        self.assertIn('/obj/structure/simple_door/key_door/custom/jail', locks)
        self.assertIn('/obj/structure/closet/crate/faction_strongbox', locks)

    def test_land_tax_is_paid_at_the_strongbox(self):
        treasury = (ROOT / 'code/game/mob/groups/faction_treasury.dm').read_text(encoding='utf-8')
        self.assertIn('pay_land_tax(user)', treasury)


if __name__ == '__main__':
    unittest.main()
