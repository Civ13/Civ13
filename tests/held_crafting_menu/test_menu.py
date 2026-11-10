"""Held recipe browser checks: real client script plus source action contracts.

This does not simulate native Topic delivery, paid crafting, or Dream Seeker.
"""
from pathlib import Path
import hashlib
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/game/objects/items/stacks/stack.dm').read_text()
MENU = SOURCE.split('/obj/item/stack/proc/list_recipes(', 1)[1].split('// Custom qdel', 1)[0]


class HeldCraftingMenu(unittest.TestCase):
    def test_client_behaviors(self):
        result = subprocess.run(['node', 'tests/held_crafting_menu/menu.test.cjs'], cwd=ROOT,
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('PASS:', result.stdout)

    def test_category_and_leaf_ids_are_not_filtered_indices(self):
        self.assertIn('for (var/i=1;i<=recipes.len;i++)', MENU)
        self.assertIn('for (var/j=1;j<=srl.recipes.len;j++)', MENU)
        self.assertIn('"sublist" = i, "index" = j', MENU)
        self.assertIn('"sublist" = "", "index" = i', MENU)
        self.assertIn('var/action = "byond://?src=\\ref[src];sublist=[sublist];make=[index]"', MENU)
        self.assertIn("value='[action];multiplier=[n]'", MENU)
        self.assertIn("href='[action];multiplier=1'", MENU)

    def test_lock_and_cost_hints_survive(self):
        self.assertIn('crafting_recipe_manual_hint(user, "[R.result_type]")', MENU)
        self.assertIn('if (manual_hint)', MENU)
        self.assertIn('else if (max_multiplier < 1)', MENU)
        self.assertIn('html_encode(manual_hint)', MENU)
        self.assertIn('html_encode(cost)', MENU)
        self.assertIn('html_encode(details)', MENU)
        self.assertIn('Not enough material', MENU)

    def test_read_only_presentation_and_escaped_text(self):
        for action in ('produce_recipe(', 'use(', 'new R.result_type', 'recipes.Cut(', 'recipes.Remove('):
            self.assertNotIn(action, MENU)
        for field in ('srl.title', 'title', 'category', '"[R.title] [category]"'):
            self.assertIn('html_encode(' + field + ')', MENU)
        self.assertIn("browse_rsc('code/js/stack_crafting.js'", MENU)
        self.assertIn("<!DOCTYPE html><html><head><meta http-equiv='X-UA-Compatible' content='IE=edge'>", MENU)

    def test_authoritative_topic_body_unchanged(self):
        topic = SOURCE.split('/obj/item/stack/Topic(href, href_list)', 1)[1].split('// The normal menu', 1)[0]
        # Narrow frozen contract, not a whole-file pin: the UI cannot replace
        # held-stack admission, actor busy flag, or production dispatch.
        self.assertEqual(hashlib.sha256(topic.encode()).hexdigest(), '2b2160ac2f0e33abe69d384c2e35cd5df48a9da85a00698a08649457c9c047d8')


if __name__ == '__main__':
    unittest.main()
