"""Source-projected anvil stack actions; no BYOND runtime is launched."""
from pathlib import Path
import importlib.util
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
                   menu_label=label, WWinput=menu, splittext=lambda value, sep: {1: value.split(sep)[0]},
                   crafting_recipe_allowed=lambda human, recipe: self.allowed,
                   do_after=wait, qdel=discard,
                   to_chat=lambda user, message: self.messages.append(message),
                   update_icon=lambda: None,
                   spawn_output=lambda *args: self.outputs.append(args))
        self.action = adapter.project(source, '/obj/structure/anvil/proc/forge_stack_recipe',
                                      'P, user, H, choice, material_index, material_name, src, loc', env)

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
        self.assertEqual(calls, [('6', 'iron'), ('6', 'iron'), ('5', 'steel'), ('5', 'steel'), ('8', 'kevlar'), ('7', 'bronze')])
        self.assertEqual(source.count('return forge_blackpowder_part(P, H)'), 4)

if __name__ == '__main__':
    unittest.main()
