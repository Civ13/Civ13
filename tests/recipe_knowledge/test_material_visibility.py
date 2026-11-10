"""Offline checks of the book-mode material-row predicate, not native gameplay."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/game/objects/items/stacks/civ_recipes.dm').read_text(encoding='utf-8-sig')
NODES = (ROOT / 'code/modules/research_tree/research_node.dm').read_text(encoding='utf-8-sig')
ROWS = (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8-sig')


def book_predicate(source=SOURCE):
    match = re.search(r'(?m)^\s*research_allowed = (.+)$', source[source.index('if (node_req && map && map.book_research_enabled())'):])
    if not match:
        raise AssertionError('book-mode predicate missing')
    expression = match.group(1).replace('&&', ' and ').replace('||', ' or ')
    return compile(expression, '<book-mode material predicate>', 'eval')


def visibility(predicate, *, era, node_era, user, allowed=False, writing=False):
    class Node:
        era_tier = node_era
    class Map:
        ordinal_age = era
    return bool(eval(predicate, {'__builtins__': {}}, {
        'map': Map(), 'RN': Node(), 'user': user, 'i': [None] * 4,
        'is_book_research_writing_supply': lambda _: writing,
        'crafting_recipe_allowed': lambda actor, _: actor and allowed,
    }))


class MaterialVisibility(unittest.TestCase):
    def test_real_stone_wall_can_be_learned_in_stone_age(self):
        self.assertRegex(NODES, r'"/obj/covers/stone_wall"\s*=\s*"stone_masonry"')
        self.assertRegex(NODES, r'"stone_masonry"[^\n]*list\("primitive_construction"\), 1\)')
        row = next(line for line in ROWS.splitlines() if line.startswith('RECIPE: /material/stone/,stone wall,'))
        self.assertEqual(row.split(',')[11], '2')  # last permitted age
        p = book_predicate()
        self.assertFalse(visibility(p, era=0, node_era=1, user=True))
        self.assertTrue(visibility(p, era=0, node_era=1, user=True, allowed=True))
        self.assertTrue(visibility(p, era=1, node_era=1, user=True))
        self.assertFalse(visibility(p, era=0, node_era=1, user=False, allowed=True))

    def test_negative_control_detects_missing_personal_exception(self):
        before = SOURCE.replace(' || (user && crafting_recipe_allowed(user, i[3]))', '')
        self.assertFalse(visibility(book_predicate(before), era=0, node_era=1, user=True, allowed=True))

    def test_both_entry_paths_forward_actor_and_legacy_and_expiry_remain(self):
        self.assertEqual(SOURCE.count('generate_recipes_civs(current_res, faction, user ? user.civilization : null, user)'), 2)
        self.assertIn('else if (node_req && map)\n\t\t\tresearch_allowed = map.is_node_done(research_faction, node_req)', SOURCE)
        self.assertIn('if(material_allowed && research_allowed && map && recipe_age_allowed(text2num(i[12])))', SOURCE)


if __name__ == '__main__':
    unittest.main()
