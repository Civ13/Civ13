"""Stone Age rites: source contract checks.

    python3 tests/stone_age_rites/test_source.py
"""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/1713/stone_age_rites.dm'


class StoneAgeRitesSource(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = SOURCE.read_text(encoding='utf-8')

    def test_included_after_deeds_and_graves(self):
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8').splitlines()
        index = {line: i for i, line in enumerate(dme)}
        mine = index['#include "code\\modules\\1713\\stone_age_rites.dm"']
        self.assertLess(index['#include "code\\modules\\1713\\tribal_deeds.dm"'], mine)
        self.assertLess(index['#include "code\\game\\objects\\structures\\religious.dm"'], mine)

    def test_overrides_call_parent(self):
        for header in ('/obj/structure/religious/grave/initialize()',
                '/obj/structure/religious/grave/attackby(obj/item/W, mob/user)',
                '/mob/living/human/survival_climate_food_m()'):
            start = self.text.index(header + '\n')
            self.assertIn('..()', self.text[start:start + 1200], header)

    def test_recipes_and_research(self):
        recipes = (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8')
        self.assertIn('RECIPE: /material/stone/,cairn,/obj/structure/religious/cairn,', recipes)
        self.assertIn('RECIPE: /material/leather/,feasting mat,/obj/structure/feast_mat,', recipes)
        research = (ROOT / 'code/modules/research_tree/research_node.dm').read_text(encoding='utf-8')
        self.assertIn('"/obj/structure/religious/cairn" = "ritual_worship",', research)
        self.assertIn('"/obj/structure/feast_mat" = "ritual_worship",', research)
        stack = (ROOT / 'code/game/objects/items/stacks/stack.dm').read_text(encoding='utf-8')
        self.assertIn('findtext(recipe.title, "cairn")', stack)

    def test_sprites_exist(self):
        from PIL import Image
        meta = Image.open(ROOT / 'icons/obj/stone_age_rites.dmi').info.get('Description', '')
        for state in ('burial_mound', 'cairn', 'feast_mat', 'feast_mat_food'):
            self.assertIn('state = "%s"' % state, meta)

    def test_deeds_recorded(self):
        self.assertIn('record_deed(user, "burial_mound"', self.text)
        self.assertIn('record_deed(host, "feast"', self.text)

    def test_no_forbidden_patterns(self):
        self.assertIsNone(re.search(r'(?<![a-z_])spawn\(', self.text))
        self.assertNotIn(' in world', self.text)
        self.assertNotIn('magic', self.text.lower())


if __name__ == '__main__':
    unittest.main()
