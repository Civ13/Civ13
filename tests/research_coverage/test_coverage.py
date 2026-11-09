"""Source-derived phase-0 contracts; these are not native gameplay evidence."""
import copy
import json
from pathlib import Path
import re
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts'))
from atlas.research_coverage import annotate_research, research_contract, NODE_SOURCE, GATE_SOURCE


def files():
    return {path: (ROOT / path).read_text(encoding='utf-8') for path in (NODE_SOURCE, GATE_SOURCE)}


def canon(path):
    return path.replace('/obj/item/stack/material/', '/material/', 1)


def record(kind='Native stack', output='/obj/item/weapon/saw', raw='', path='fixture.dm'):
    return dict(id='fixture', kind=kind, name='Test', outputs=[{'id': output}], raw=raw, file=path, line=1)


class Coverage(unittest.TestCase):
    def test_unknown_craft_fails_closed(self):
        with self.assertRaisesRegex(ValueError, 'lack valid research'):
            annotate_research([record(output='/obj/item/new_unreviewed_recipe')], files(), canon)

    def test_node_removal_is_a_negative_control(self):
        source = files()
        source[NODE_SOURCE] = source[NODE_SOURCE].replace('"/obj/item/weapon/saw" = "iron_tools",', '')
        with self.assertRaisesRegex(ValueError, 'lack valid research'):
            annotate_research([record()], source, canon)

    def test_unknown_node_rejected(self):
        source = files()
        source[NODE_SOURCE] = source[NODE_SOURCE].replace('"/obj/item/weapon/saw" = "iron_tools"', '"/obj/item/weapon/saw" = "typo"')
        with self.assertRaisesRegex(ValueError, 'Unknown research nodes'):
            research_contract(source, canon)

    def test_only_confirmed_basics(self):
        _, _, basics, _, _ = research_contract(files(), canon)
        self.assertEqual(basics, {'/obj/item/stack/material/rope', '/obj/item/stack/material/stonebrick', '/obj/structure/researchdesk'})
        for path in basics:
            row = record(output=canon(path))
            annotate_research([row], files(), canon)
            self.assertEqual(row['research_status'], 'basic')
        with self.assertRaises(ValueError):
            annotate_research([record(output='/obj/structure/researchdesk/unreviewed')], files(), canon)

    def test_chemistry_and_acquisition_are_excluded_not_free_crafts(self):
        for kind in ('Chemistry', 'Acquisition / processing'):
            row = record(kind=kind, output='arbitrary_reagent')
            annotate_research([row], files(), canon)
            self.assertEqual(row['research_status'], 'excluded')
            self.assertEqual(row['research_nodes'], [])
        # A production recipe producing that reagent cannot borrow the exclusion.
        with self.assertRaises(ValueError):
            annotate_research([record(kind='New reagent production', output='arbitrary_reagent')], files(), canon)

    def test_hide_and_flint_harvesting_exclusions_are_narrow(self):
        row = record(kind='Leather tanning', output='/material/rawhide', path='code/modules/1713/animal_harvest.dm')
        annotate_research([row], files(), canon)
        self.assertEqual(row['research_status'], 'excluded')
        row = record(kind='Leather tanning', output='/material/leather', path='code/game/objects/items/stacks/sheets/leather.dm')
        annotate_research([row], files(), canon)
        self.assertEqual(row['research_nodes'], ['resource_processing'])
        row = record(kind='Flintlock preparation', output='/obj/item/weapon/flint/sharpened')
        annotate_research([row], files(), canon)
        self.assertEqual(row['research_nodes'], ['stone_arms'])

    def test_route_specific_factory_gate_wins_over_basic_output(self):
        row = record(kind='Factory fabricator', output='/material/stonebrick', raw='FACTORY: bricks|/obj/item/stack/material/stonebrick|2|stone=2|20|1|assembly_line')
        annotate_research([row], files(), canon)
        self.assertEqual(row['research_status'], 'gated')
        self.assertEqual(row['research_nodes'], ['assembly_line'])

    def test_material_mapping_uses_raw_output_not_label(self):
        row = record(kind='Material / global', output='/material/rope', raw='RECIPE: /material/iron/,rope,/obj/item/weapon/saw,1,20,0,1,none,0,0,0,8,null')
        annotate_research([row], files(), canon)
        self.assertEqual(row['research_nodes'], ['iron_tools'])

    def test_generated_catalog_has_no_silent_gap(self):
        recipes = json.loads((ROOT / 'UI/crafting-atlas.json').read_text())['recipes']
        nodes = research_contract(files(), canon)[0]
        self.assertGreaterEqual(len(recipes), 3418)
        for row in recipes:
            with self.subTest(recipe=row['id']):
                self.assertIn(row.get('research_status'), ('gated', 'basic', 'excluded'))
                if row['research_status'] == 'gated':
                    self.assertTrue(row['research_nodes'])
                    self.assertTrue(set(row['research_nodes']) <= nodes)
                else:
                    self.assertEqual(row['research_nodes'], [])
                if row['kind'] == 'Chemistry':
                    self.assertEqual(row['research_status'], 'excluded')
                for variant in row.get('variants', []):
                    self.assertTrue(variant['file'].startswith('config/crafting/'))

    def test_runtime_gate_and_material_wait_recheck(self):
        source = files()[GATE_SOURCE]
        self.assertIn('get_research_node(node_id) && map.is_node_done(faction, node_id)', source)
        self.assertIn('return crafting_node_allowed(H, get_recipe_node_req(result_path_string))', source)
        stack = (ROOT / 'code/game/objects/items/stacks/stack.dm').read_text()
        self.assertIn('if (!crafting_recipe_allowed(H, "[recipe.result_type]"))', stack)
        self.assertIn('if (!do_after(user, buildtime) || !crafting_recipe_allowed(H, "[recipe.result_type]"))', stack)
        menu = (ROOT / 'code/game/objects/items/stacks/civ_recipes.dm').read_text()
        self.assertIn('research_allowed = is_basic_crafting_recipe(i[3])', menu)
        self.assertNotIn('research_allowed = (current_res[1]', menu)


if __name__ == '__main__':
    unittest.main()
