"""Bare-knuckle hand injuries: offline seam checks.

The native probe (probe.dm, run.py) checks protection values and the injury
itself in a real build. These checks keep the wiring it cannot reach: the
punch and animal hooks, the wrap recipes and research, and the include.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text(encoding='utf-8')


SOURCE = read('code/game/mob/living/carbon/human/punch_injury.dm')
ATTACK = read('code/game/mob/living/carbon/human/human_attackhand.dm')
ANIMAL = read('code/game/mob/living/simple_animal/simple_animal.dm')
RECIPES = read('config/crafting/material_recipes_global.txt')
NODES = read('code/modules/research_tree/research_node.dm')
DME = read('civ13.dme')

WRAPS = {
    '/obj/item/clothing/gloves/hand_wraps': '/material/cloth/',
    '/obj/item/clothing/gloves/hand_wraps/leather': '/material/leather/',
}


class PunchInjurySources(unittest.TestCase):
    def test_source_is_compiled(self):
        self.assertIn('#include "code\\game\\mob\\living\\carbon\\human\\punch_injury.dm"', DME)

    def test_landed_full_punches_risk_the_hand(self):
        hook = ('if (H != src && istype(attack, /datum/unarmed_attack/punch) && !attack.deal_halloss)\n'
                '\t\t\t\t\tH.punch_hurts_hand(src, hit_zone, rand_damage, getarmor(affecting, "melee"))')
        self.assertIn(hook, ATTACK)
        # after the miss/block early return, so only landed punches count
        self.assertLess(ATTACK.index('if (miss_type)\n\t\t\t\t\treturn FALSE'), ATTACK.index(hook))

    def test_punching_animals_risks_the_hand(self):
        self.assertIn('M.punch_hurts_hand(src, "chest", 3)', ANIMAL)

    def test_wraps_have_recipes_and_research(self):
        rows = {}
        for line in RECIPES.splitlines():
            if line.startswith('RECIPE: '):
                cells = line[len('RECIPE: '):].split(',')
                rows[cells[2]] = cells
        for path, material in WRAPS.items():
            self.assertIn(path, rows, path)
            row = rows[path]
            self.assertEqual(len(row), 13, path)
            self.assertEqual((row[0], int(row[3]), row[7], int(row[8])), (material, 1, 'gloves', 0), path)
            self.assertIn('"%s" = "weaving",' % path, NODES)

    def test_slot_jewellery_gives_no_protection(self):
        for path in ('/obj/item/clothing/gloves/rings', '/obj/item/clothing/gloves/watch'):
            self.assertIn(path + '\n\tpunch_protection = 0', SOURCE)


if __name__ == '__main__':
    unittest.main()
