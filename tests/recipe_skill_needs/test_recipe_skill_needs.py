#!/usr/bin/env python3
"""Offline source contracts for the table of recipes that need skill."""
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text(encoding='utf-8', errors='replace').replace('\r\n', '\n')


STACK = read('code/game/objects/items/stacks/stack.dm')
TABLE = read('code/game/objects/items/stacks/recipe_skill_needs.dm')


class RecipeSkillNeeds(unittest.TestCase):
    def test_the_table_is_compiled_before_its_user(self):
        dme = read('civ13.dme')
        self.assertLess(dme.index('stacks\\recipe_skill_needs.dm"'), dme.index('stacks\\stack.dm"'))

    def test_stack_has_no_skill_levels_of_its_own(self):
        # Players were told "This is too complex for your skill level" with no
        # skill, no number and no way to look it up.
        self.assertNotIn('too complex for your skill level', STACK)
        self.assertNotIn('getStatCoeff("crafting") < ', STACK)
        # The holy book's check is tied to religion and stays where it is.
        self.assertEqual(STACK.count('getStatCoeff("philosophy") < '), 1)
        self.assertEqual(STACK.count('if (recipe_skill_short(H, recipe))'), 26)

    def test_the_table_keeps_every_level(self):
        entries = re.findall(r'^\tlist\("(\w+)", ([\d.]+), ', TABLE, re.M)
        self.assertEqual(len(entries), 26)
        levels = sorted(float(level) for _, level in entries)
        self.assertEqual(levels, sorted([1.7, 1, 1, 1.35, 1.35, 1.9, 1.35, 1.1, 1.1, 1.1, 1.1, 1.55, 1.55, 1.55, 1.25, 1.25,
                                         1.35, 1.35, 1.35, 1.35, 1.35, 2.2, 2.2, 1.8, 2, 2]))
        self.assertEqual([skill for skill, _ in entries if skill != 'crafting'], ['philosophy'])

    def test_the_refusal_names_skill_need_and_own_level(self):
        self.assertIn('"Needs [capitalize(need[1])] [round(need[2] * 100)]. Yours is [round(have * 100)]."', TABLE)

    def test_the_crafting_window_and_filter_ask_the_table(self):
        self.assertIn('why = recipe_skill_refusal(viewer, R) || ""', read('code/game/objects/items/stacks/crafting_window.dm'))
        makeable = read('code/game/objects/items/stacks/stack_makeable.dm')
        self.assertIn('if (recipe_skill_refusal(H, R))\n\t\treturn FALSE', makeable)

    def test_the_atlas_asks_the_table_by_title(self):
        self.assertIn('return R ? recipe_skill_need_named(R.title, R.result_type) : null', TABLE)
        atlas = read('code/game/mob/crafting_atlas_tgui.dm')
        self.assertIn('"skill" = skill_data(viewer, recipe)', atlas)
        self.assertIn('recipe_skill_need_named(recipe["name"], result_id)', atlas)
        self.assertIn('{skill && <li>Skill: ', read('tgui/src/interfaces/CraftingAtlas.tsx'))


if __name__ == '__main__':
    unittest.main()
