"""Small Stone Age additions: source contract checks.

    python3 tests/stone_age_extras/test_source.py
"""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/1713/stone_age_extras.dm'


class StoneAgeExtrasSource(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = SOURCE.read_text(encoding='utf-8')
        cls.research = (ROOT / 'code/modules/research_tree/research_node.dm').read_text(encoding='utf-8')

    def test_included_after_hooked_files(self):
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8').splitlines()
        index = {line: i for i, line in enumerate(dme)}
        mine = index['#include "code\\modules\\1713\\stone_age_extras.dm"']
        self.assertLess(index['#include "code\\modules\\1713\\flint_mining.dm"'], mine)
        self.assertLess(index['#include "code\\game\\objects\\farming.dm"'], mine)

    def test_bear_trap_needs_iron(self):
        self.assertIn('"/obj/item/weapon/beartrap" = "iron_tools",', self.research)
        self.assertNotIn('"/obj/item/weapon/beartrap" = "field_defenses",', self.research)

    def test_recipes(self):
        recipes = (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8')
        self.assertIn('RECIPE: /material/bone/,bone flute,/obj/item/stone_age_instrument/bone_flute,', recipes)
        self.assertIn('RECIPE: /material/leather/,frame drum,/obj/item/stone_age_instrument/frame_drum,', recipes)
        self.assertIn('"/obj/item/stone_age_instrument/bone_flute" = "ritual_worship",', self.research)
        knapping = (ROOT / 'code/modules/1713/processing_recipes.dm').read_text(encoding='utf-8')
        self.assertIn('"Sickle teeth", /obj/item/weapon/flint, /obj/item/weapon/flint_sickle_teeth', knapping)

    def test_overrides_call_parent(self):
        for header in ('/obj/item/weapon/branch/attackby(obj/item/weapon/W as obj, mob/user as mob)',
                '/obj/structure/farming/plant/attackby(obj/item/weapon/W as obj, mob/user as mob)',
                '/mob/living/simple_animal/bison/adjustBruteLoss(damage)'):
            start = self.text.index(header + '\n')
            self.assertIn('..()', self.text[start:start + 700], header)

    def test_sprites_exist(self):
        from PIL import Image
        meta = Image.open(ROOT / 'icons/obj/stone_age_extras.dmi').info.get('Description', '')
        for state in ('bone_flute', 'frame_drum', 'flint_sickle'):
            self.assertIn('state = "%s"' % state, meta)

    def test_no_forbidden_patterns(self):
        self.assertIsNone(re.search(r'(?<![a-z_])(spawn|input)\(', self.text))
        self.assertNotIn(' in world', self.text)


if __name__ == '__main__':
    unittest.main()
