"""Poisonous frog meat coats crossbow bolts as well as arrows (issue #5258).

Offline structural checks on current source. No BYOND, network or saves.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
MEAT = ROOT / 'code/modules/reagents/reagent_containers/food/snacks/meat.dm'
HEADER = '/obj/item/weapon/reagent_containers/food/snacks/meat/poisonfrog/attack_self(mob/user as mob)'


def proc_body(text, header):
    lines = text.splitlines()
    start = lines.index(header)
    body = []
    for line in lines[start + 1:]:
        if line and not line.startswith('\t'):
            break
        body.append(line)
    return '\n'.join(body)


class PoisonFrogBoltTests(unittest.TestCase):
    def setUp(self):
        self.body = proc_body(MEAT.read_text(encoding='utf-8'), HEADER)
        self.selection = self.body[:self.body.index('if (CURRENT)')]

    def test_either_hand_selects_a_bolt(self):
        for other in ('r_hand', 'l_hand'):
            with self.subTest(other=other):
                self.assertIn(f'istype(user.{other}, /obj/item/ammo_casing/bolt)', self.selection)
                self.assertIn(f'istype(user.{other}, /obj/item/ammo_casing/arrow)', self.selection)

    def test_selection_still_needs_a_use_left(self):
        self.assertEqual(self.selection.count('uses >= 1'), 2)

    def test_bolt_branch_poisons_and_spends_a_use(self):
        branch = self.body[self.body.index('istype(CURRENT, /obj/item/ammo_casing/bolt)'):]
        self.assertIn('/obj/item/projectile/arrow/bolt/vial/poisonous', branch)
        self.assertIn('uses = (uses - 1)', branch)

    def test_poisoned_bolt_types_exist(self):
        projectiles = (ROOT / 'code/modules/projectiles/__projectiles.dm').read_text(encoding='utf-8')
        self.assertRegex(projectiles, r'(?m)^/obj/item/projectile/arrow/bolt/vial/poisonous$')


if __name__ == '__main__':
    unittest.main()
