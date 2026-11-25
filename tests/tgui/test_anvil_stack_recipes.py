"""Source-projected anvil stack actions; no BYOND runtime is launched."""
from pathlib import Path
import importlib.util
import json
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
source_path = ROOT / 'code/game/objects/structures/blacksmithing/blacksmithing.dm'
spec = importlib.util.spec_from_file_location('source_adapter', ROOT / 'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)

class Menu(list):
    pass

class Stack:
    def __init__(self, amount):
        self.amount = amount
        self.deleted = False

class AnvilStackRecipe(unittest.TestCase):
    def setUp(self, remove_stock_recheck=False):
        self.messages, self.outputs, self.waits, self.menus = [], [], [], []
        self.timing_events = []
        self.duration = lambda cost: cost * 10
        self.allowed, self.wait_result = True, True
        self.on_wait = lambda: None
        self.selection = 'Helmet - 2 iron'
        self.rows = {
            'Helmet': {1: 'Helmet', 2: 'helmets', 3: 1, 4: 4, 5: 3, 6: 2, 7: 4, 8: 5, 9: 'helmet_type'},
            'Sword': {1: 'Sword', 2: 'weapons', 3: 1, 4: 4, 5: 1, 6: 1, 7: 1, 8: 1, 9: 'sword_type'},
        }
        source = source_path.read_text(encoding='utf-8').split('/obj/structure/anvil/attackby(', 1)[0]
        if remove_stock_recheck:
            guarded = '\t\t\t\tif (P.amount >= anvil_recipes[parsed_choice2[1]][material_index] && crafting_recipe_allowed(H, "[anvil_recipes[parsed_choice2[1]][9]]"))'
            self.assertEqual(source.count(guarded), 1)
            source = source.replace(guarded, '\t\t\t\tif (crafting_recipe_allowed(H, "[anvil_recipes[parsed_choice2[1]][9]]"))')
        changes = {
            'newlist += "[anvil_recipes[i][1]] - [anvil_recipes[i][material_index]] [material_name]" + crafting_recipe_manual_suffix(H, "[anvil_recipes[i][9]]")':
                'newlist.append(menu_label(anvil_recipes[i], material_index, material_name))',
            'crafting_recipe_allowed(H, "[anvil_recipes[parsed_choice2[1]][9]]")':
                'crafting_recipe_allowed(H, anvil_recipes[parsed_choice2[1]][9])',
            'new rtype (loc,material_name)': 'spawn_output(rtype, loc, material_name)',
        }
        for before, after in changes.items():
            self.assertEqual(source.count(before), 3 if before.startswith('crafting_recipe_allowed') else 1)
            source = source.replace(before, after)
        def wait(user, ticks, anvil, can_move):
            self.timing_events.append(('wait', ticks))
            self.waits.append((ticks, can_move))
            self.on_wait()
            return self.wait_result
        def menu(user, prompt, title, default, choices):
            self.menus.append(list(choices))
            return self.selection
        def discard(item):
            item.deleted = True
        def label(row, index, material):
            return f'{row[1]} - {row[index]} {material} (manual)'
        env = dict(list=lambda item: Menu([item]), anvil_recipes=self.rows,
                   map=type('Map', (), {'ordinal_age': 2})(),
                   recipe_age_allowed=lambda age: age >= 2,
                   # The shared row filter (blacksmithing_recipes.dm); no machine parts in these rows.
                   anvil_recipe_offered=lambda row, category, cost, material=None, cast=False: bool(
                       row and row[2] == category and 2 >= row[3] and row[4] >= 2 and cost > 0),
                   menu_label=label, WWinput=menu, splittext=lambda value, sep: {1: value.split(sep)[0]},
                   crafting_recipe_allowed=lambda human, recipe: self.allowed,
                   do_after=wait, qdel=discard,
                   # Modifier inputs are exercised by the mechanical power contract.
                   stack_forge_duration=lambda user, human, row, cost: self.duration(cost),
                   show_stack_forge_progress=lambda human, delay: self.timing_events.append(('progress', delay)),
                   to_chat=lambda user, message: self.messages.append(message),
                   update_icon=lambda: None,
                   note_craft_practice=lambda user, path: None,
                   trial_craft_ruined=lambda user, path: False,
                   # The steel grade (steel_grades.dm) only touches the made piece.
                   apply_stock_grade=lambda made, stock: made,
                   # Clay hardening and the quench (quench_tub.dm) only touch the made piece.
                   finish_forged_piece=lambda made, user, human, material: None,
                   spawn_output=lambda *args: self.outputs.append(args))
        self.action = adapter.project(source, '/obj/structure/anvil/proc/forge_stack_recipe',
                                      'P, user, H, choice, material_index, material_name, src, loc, picked=None', env)

    def run_action(self, amount=9, index=6, material='iron', category='helmets'):
        stack = Stack(amount)
        self.action(stack, 'user', 'human', category, index, material, 'anvil', 'tile')
        return stack

    def test_each_material_uses_its_own_cost_and_output(self):
        for index, material, cost in ((6, 'iron', 2), (5, 'steel', 3), (7, 'bronze', 4), (8, 'kevlar', 5)):
            with self.subTest(material=material):
                self.setUp()
                stack = self.run_action(index=index, material=material)
                self.assertEqual(stack.amount, 9-cost)
                self.assertEqual(self.outputs, [('helmet_type', 'tile', material)])
                self.assertEqual(self.waits, [(10*cost, False)])
                self.assertEqual(self.menus, [['Cancel', f'Helmet - {cost} {material} (manual)']])

    def test_accepted_wait_publishes_the_same_duration_not_the_raw_base(self):
        self.rows['Helmet'][6] = 4
        self.duration = lambda cost: round(cost * 10 * .75)
        self.run_action()
        self.assertEqual(self.timing_events, [('progress', 30), ('wait', 30)])
        self.setUp()
        self.allowed = False
        self.run_action()
        self.assertEqual(self.timing_events, [])

    def test_interruption_and_post_wait_resource_or_permission_change_do_not_pay(self):
        for condition in ('interrupted', 'stock', 'permission'):
            with self.subTest(condition=condition):
                self.setUp()
                stack = Stack(2)
                if condition == 'interrupted': self.wait_result = False
                if condition == 'stock': self.on_wait = lambda: setattr(stack, 'amount', 1)
                if condition == 'permission': self.on_wait = lambda: setattr(self, 'allowed', False)
                self.action(stack, 'user', 'human', 'helmets', 6, 'iron', 'anvil', 'tile')
                self.assertEqual(stack.amount, 1 if condition == 'stock' else 2)
                self.assertFalse(stack.deleted)
                self.assertEqual(self.outputs, [])

    def test_cancel_and_insufficient_stock_do_not_wait_or_pay(self):
        self.selection = 'Cancel'
        stack = self.run_action(amount=2)
        self.assertEqual((stack.amount, self.waits, self.outputs), (2, [], []))
        self.setUp()
        stack = self.run_action(amount=1)
        self.assertEqual((stack.amount, self.waits, self.outputs), (1, [], []))

    def test_exhausted_stack_is_deleted_once_and_empty_category_has_no_menu(self):
        stack = self.run_action(amount=2)
        self.assertTrue(stack.deleted)
        self.assertEqual(stack.amount, 0)
        self.setUp()
        self.run_action(category='unknown')
        self.assertEqual(self.menus, [])
        self.assertIn('There is nothing that you can craft of this type.', self.messages)

    def test_age_and_initial_permission_gates_are_respected(self):
        self.rows['Helmet'][3] = 3
        stack = self.run_action()
        self.assertEqual((stack.amount, self.menus, self.waits, self.outputs), (9, [], [], []))
        self.setUp()
        self.allowed = False
        stack = self.run_action()
        self.assertEqual((stack.amount, self.waits, self.outputs), (9, [], []))

    def test_negative_control_removing_stock_recheck_overdraws(self):
        self.setUp(remove_stock_recheck=True)
        stack = Stack(2)
        self.on_wait = lambda: setattr(stack, 'amount', 1)
        self.action(stack, 'user', 'human', 'helmets', 6, 'iron', 'anvil', 'tile')
        self.assertEqual(stack.amount, -1)
        self.assertEqual(self.outputs, [('helmet_type', 'tile', 'iron')])

    def test_material_entrypoints_preserve_dispatch_fields(self):
        source = source_path.read_text(encoding='utf-8')
        calls = re.findall(r'return forge_stack_recipe\(P, user, H, choice, (\d+), "(\w+)"\)', source)
        self.assertEqual(calls, [('6', 'iron'), ('5', 'steel'), ('8', 'kevlar'), ('7', 'bronze')])
        self.assertEqual(source.count('return forge_blackpowder_part(P, H)'), 2)

class AnvilWindowRoutes(unittest.TestCase):
    def setUp(self):
        self.window = source_path.with_name('anvil_window.dm').read_text()
        self.snapshot = self.window.split('/datum/crafting_window/anvil/build_data()', 1)[1].split('/datum/crafting_window/anvil/Topic', 1)[0]
        self.topic = self.window.split('/datum/crafting_window/anvil/Topic', 1)[1].split('/obj/structure/anvil/proc/show_stack_forge_progress', 1)[0]

    def test_estimate_is_quiet_and_active_time_is_only_set_at_admission(self):
        self.assertIn('var/list/assist_cache = list()', self.snapshot)
        self.assertIn('"time" = anvil.stack_forge_duration(viewer, viewer, R, cost, TRUE, assist_cache)', self.snapshot)
        self.assertNotIn('"time" = 10 *', self.topic)
        progress = self.window.split('/obj/structure/anvil/proc/show_stack_forge_progress', 1)[1].split('/obj/structure/anvil/proc/anvil_window_shown', 1)[0]
        self.assertRegex(progress, r'if \(istype\(W\) && W.anvil == src && W.working && !W.pending && W.still_valid\(H\)\)\s+W.working\["time"\] = delay\s+GLOB.nanomanager.update_uis\(W\)')

    def test_breaking_a_research_prerequisite_opens_only_the_offered_nodes_hint(self):
        self.assertIn('"tech_tree" = hint && tech_tree_view ? 1 : 0', self.snapshot)
        self.assertIn('hint = crafting_recipe_manual_hint(viewer, result)', self.snapshot)
        link = self.topic.split('if (href_list["tech_tree"])', 1)[1].split('if (href_list["pin"])', 1)[0]
        self.assertLess(self.topic.index('!still_valid(H)'), self.topic.index('if (href_list["tech_tree"])'))
        self.assertRegex(link, r'var/gated = offered_name\(href_list\["tech_tree"\]\)\s+if \(gated && tech_tree_view\)')
        self.assertIn('var/list/R = anvil_recipes[gated]', link)
        self.assertRegex(link, r'if \(crafting_recipe_manual_hint\(H, product\)\)\s+tech_tree_view.show\(H, get_recipe_node_req\(product\)\)')
        self.assertNotIn('tech_tree_view.show(H, href_list', link)

    def test_atlas_routes_steel_and_iron_to_their_own_producers_or_falls_back(self):
        atlas = self.topic.split('if (href_list["atlas"])', 1)[1].split('if (href_list["tech_tree"])', 1)[0]
        self.assertIn('offered_name(href_list["atlas"])', atlas)
        self.assertIn('crafting_atlas_reference.anvil_variant_id(shown, metal[2], R[metal[1]], product)', atlas)
        self.assertIn('show(H, product, 1, product, recipe_id = recipe)', atlas)
        resolver = self.window.split('/datum/crafting_atlas_reference/proc/anvil_variant_id', 1)[1].split('/datum/crafting_window/anvil/build_data', 1)[0]
        for source_contract in ('recipe["kind"] != "Anvil" || recipe["name"] != display_name', '"/material/[material]"',
                                'length(inputs) != 1 || length(outputs) != 1', 'ingredient["id"] == ingredient_id',
                                'text2num("[ingredient["quantity"]]") == cost', 'output["id"] == product',
                                'return recipe["id"]', 'return ""'):
            self.assertIn(source_contract, resolver)
        craft = json.loads((ROOT / 'UI/crafting-atlas.json').read_text())
        rows = [v for group in craft['recipes'] if group['kind'] == 'Anvil' for v in group.get('variants', [group])]
        product = '/obj/item/clothing/suit/armor/samurai/warrior'

        def matching(material, cost, item=product):
            return [r['id'] for r in rows if r['kind'] == 'Anvil'
                    and r['name'] == f'Metal Samurai Armor [{material}]'
                    and len(r['inputs']) == len(r['outputs']) == 1
                    and r['inputs'][0]['id'] == f'/material/{material}'
                    and float(r['inputs'][0]['quantity']) == cost
                    and r['outputs'][0]['id'] == item]

        steel, iron = matching('steel', 11), matching('iron', 14)
        self.assertEqual((len(steel), len(iron)), (1, 1))
        self.assertNotEqual(steel, iron)
        self.assertEqual(matching('steel', 14), [])
        self.assertEqual(matching('steel', 11, product + '/red'), [])

if __name__ == '__main__':
    unittest.main()
