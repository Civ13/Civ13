#!/usr/bin/env python3
"""Offline source contracts for the Skills Guide window."""
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text(encoding='utf-8', errors='replace').replace('\r\n', '\n')


GUIDE = read('code/modules/research_tree/skill_guide.dm')


class SkillGuide(unittest.TestCase):
    def test_the_guide_is_compiled_into_the_game(self):
        self.assertEqual(read('civ13.dme').count('research_tree\\skill_guide.dm"'), 1)

    def test_every_status_tab_skill_has_a_row(self):
        # Players asked "how do I raise this?" for skills the Status tab
        # lists; a skill shown there without a row here is the same gap.
        rows = set(re.findall(r'^\t"(\w+)" = list\("', GUIDE, re.M))
        self.assertEqual(rows, {'strength', 'crafting', 'dexterity', 'stamina', 'swords', 'bows', 'rifle', 'pistol',
                                'machinegun', 'throwing', 'medical', 'farming', 'hunting', 'swimming', 'unarmed', 'philosophy'})

    def test_magic_is_never_mentioned(self):
        self.assertNotIn('magic', GUIDE.lower().replace('magic is left out on purpose', ''))

    def test_the_tabs_point_at_the_guide(self):
        pointer = '"<b>How to raise them:</b>", "IC tab, Skills Guide"'
        self.assertIn(pointer, read('code/game/mob/living/carbon/human/human.dm'))
        self.assertIn(pointer, read('code/modules/research_tree/scholarship.dm'))
        self.assertIn('set name = "Skills Guide"\n', GUIDE)
        self.assertIn('set category = "IC"\n', GUIDE)


if __name__ == '__main__':
    unittest.main()
