"""Tools and second materials declared as data (config/craft_needs.json).

code/game/objects/items/stacks/craft_needs.dm reads the file; produce_recipe()
checks it at the start and again after the wait, and pays only then.

- Every entry names a product some catalog row makes, tool qualities the game
  knows, and input types that exist: stacks, or whole items listed in
  LOOSE_INPUTS.
- A second material is never the stack the recipe itself is made from.
- produce_recipe() checks before the wait, rechecks and pays after it, and the
  old title-matched rope blocks (which also charged "aircraft hangar" and
  "drafting set" for containing "raft") are gone.
- The Crafting window and Atlas read the same data.
"""
from pathlib import Path
import json
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
NEEDS = json.loads((ROOT / 'config/craft_needs.json').read_text(encoding='utf-8'))
SOURCE = (ROOT / 'code/game/objects/items/stacks/craft_needs.dm').read_text(encoding='utf-8')
STACK = (ROOT / 'code/game/objects/items/stacks/stack.dm').read_text(encoding='utf-8', errors='ignore').replace('\r', '')
GUARDS = (ROOT / 'code/game/objects/items/stacks/craft_guards.dm').read_text(encoding='utf-8').replace('\r', '')
SHEETS = (ROOT / 'code/modules/materials/material_sheets.dm').read_text(encoding='utf-8', errors='ignore')
ATLAS = (ROOT / 'scripts/build-crafting-atlas.py').read_text(encoding='utf-8')
DME = (ROOT / 'civ13.dme').read_text(encoding='utf-8', errors='ignore')


# Second inputs that are whole items, not stacks: type -> the file that defines it.
# Stack inputs declared outside material_sheets.dm.
OTHER_STACKS = {
    '/obj/item/stack/hay': 'code/modules/1713/hay.dm',
    '/obj/item/stack/teeth': 'code/modules/organs/organ_external.dm',
}
LOOSE_INPUTS = {
    '/obj/item/dentures/porcelain': 'code/modules/1713/dentistry.dm',
    '/obj/item/weapon/reagent_containers/food/snacks/animalfat':
        'code/modules/reagents/reagent_containers/food/snacks/meat.dm',
    '/obj/item/machine_part/gear': 'code/modules/materials/machine_parts.dm',
    '/obj/item/machine_part/shaft': 'code/modules/materials/machine_parts.dm',
    '/obj/item/machine_part/bearing': 'code/modules/materials/machine_parts.dm',
    '/obj/item/machine_part/belt': 'code/modules/materials/machine_parts.dm',
    '/obj/item/machine_part/spring': 'code/modules/materials/machine_parts.dm',
    '/obj/item/machine_part/wheel': 'code/modules/materials/machine_parts.dm',
}


def catalog_rows():
    rows = []
    for path in sorted((ROOT / 'config/crafting').glob('material_recipes_*.txt')):
        for line in path.read_text(encoding='utf-8', errors='ignore').splitlines():
            if line.startswith('RECIPE: ') and '//' not in line:
                cols = line[len('RECIPE: '):].strip().split(',')
                if len(cols) == 13:
                    rows.append(cols)
    return rows


def default_type(stack_type):
    block = re.search(r'^' + re.escape(stack_type) + r'\n((?:\t[^\n]*\n)+)', SHEETS, re.M)
    found = re.search(r'default_type = "([^"]+)"', block[1]) if block else None
    return found[1] if found else None


class CraftNeeds(unittest.TestCase):
    def test_entries_are_well_formed(self):
        qualities = set(re.findall(r'^\t"(\w+)" = TOOL_\w+,', SOURCE, re.M))
        self.assertGreaterEqual(len(qualities), 11)
        products = {cols[2] for cols in catalog_rows()}
        self.assertTrue(NEEDS)
        for product, need in NEEDS.items():
            self.assertIn(product, products, product)
            self.assertTrue({'tools', 'inputs'} <= set(need) <= {'tools', 'inputs', 'water'}, product)
            self.assertTrue(need['tools'] or need['inputs'] or need.get('water'), product)
            if 'water' in need:
                self.assertIsInstance(need['water'], int, product)
                self.assertGreater(need['water'], 0, product)
            for tool in need['tools']:
                self.assertIn(tool, qualities, product)
            for input_type, amount in need['inputs'].items():
                if input_type.startswith('/obj/item/stack/'):
                    source = SHEETS
                    if input_type in OTHER_STACKS:
                        source = (ROOT / OTHER_STACKS[input_type]).read_text(encoding='utf-8', errors='ignore')
                    self.assertRegex(source, r'(?m)^' + re.escape(input_type) + r'$')
                else:
                    self.assertIn(input_type, LOOSE_INPUTS, product)
                    defined = (ROOT / LOOSE_INPUTS[input_type]).read_text(encoding='utf-8', errors='ignore')
                    self.assertRegex(defined, r'(?m)^' + re.escape(input_type) + r'$')
                self.assertIsInstance(amount, int)
                self.assertGreater(amount, 0)

    def test_loose_inputs_pay_whole_items(self):
        lines = SOURCE[SOURCE.index('/proc/craft_need_lines('):SOURCE.index('/proc/craft_needs_refusal(')]
        self.assertIn('ispath(input_type, /obj/item/stack)', lines)
        self.assertIn('craft_need_items(input_type, amount, candidates)', lines)
        items = SOURCE[SOURCE.index('/proc/craft_need_items('):SOURCE.index('// One list(')]
        self.assertIn('found.len >= amount', items)
        self.assertIn('return null', items)
        pay = SOURCE[SOURCE.index('/proc/craft_needs_pay('):SOURCE.index('/datum/craft_guard/needs\n')]
        self.assertIn('S.use(line["amount"])', pay)
        self.assertIn('qdel(I)', pay)
        self.assertEqual(NEEDS['/obj/item/machine_part/bearing']['inputs'],
                         {'/obj/item/weapon/reagent_containers/food/snacks/animalfat': 1})

    def test_second_material_is_not_the_recipe_stack(self):
        materials = dict(re.findall(r'^(/material(?:/\w+)+)\n\tname = "([^"]+)"',
                                    (ROOT / 'code/modules/materials/materials.dm').read_text(encoding='utf-8', errors='ignore'), re.M))
        for cols in catalog_rows():
            need = NEEDS.get(cols[2])
            if not need:
                continue
            paying = materials.get(cols[0].rstrip('/'))
            for stack_type in need['inputs']:
                # A loose item (a wheel, a chain) is never the stack that pays.
                if default_type(stack_type) is not None:
                    self.assertNotEqual(default_type(stack_type), paying, cols[1])

    def test_rope_products_keep_their_cost(self):
        self.assertEqual(NEEDS['/obj/structure/vehicle/raft']['inputs'], {'/obj/item/stack/material/rope': 2})
        self.assertEqual(NEEDS['/obj/structure/vehicle/carriage']['inputs'], {'/obj/item/stack/material/rope': 20})

    def test_produce_recipe_checks_then_pays_after_the_wait(self):
        body = STACK[STACK.index('/obj/item/stack/proc/produce_recipe('):STACK.index('/obj/item/stack/proc/crafting_stack_accessible(')]
        first = body.index('craft_needs_refusal(H, recipe, quantity, src)')
        wait = body.index('CRAFT_GUARD_FINISH')
        second = body.index('craft_needs_refusal(H, recipe, quantity, src)', first + 1)
        use = body.index('if (use(required, (joinery || carving) ? null : H))')
        pay = body.index('craft_needs_pay(H, recipe, quantity, src)')
        self.assertLess(first, wait)
        self.assertLess(wait, second)
        self.assertLess(second, use)
        self.assertLess(use, pay)
        self.assertLess(pay, body.index('trial_craft_ruined('))
        self.assertNotIn('do_after', body[second:pay])
        self.assertNotIn('sleep(', body[second:pay])
        self.assertEqual(body.count('craft_needs_pay('), 1)

    def test_title_matched_rope_blocks_are_gone(self):
        self.assertNotIn('at least 20 ropes', STACK)
        self.assertNotIn('stack of 2 ropes', STACK)
        self.assertNotIn('findtext(recipe.title, "raft")', STACK)

    def test_nothing_is_searched_beyond_hands_equipment_and_feet(self):
        candidates = SOURCE[SOURCE.index('/proc/craft_need_candidates('):SOURCE.index('/proc/craft_need_tool(')]
        self.assertIn('slot_equipment_priority', candidates)
        self.assertIn('++visited > 32', candidates)
        self.assertNotIn('contents', candidates)
        self.assertNotIn('range(', candidates)

    def test_window_and_atlas_read_the_same_data(self):
        self.assertIn('/datum/craft_guard/needs/describe_lines(', SOURCE)
        self.assertIn('G.describe_lines(H, R)', GUARDS)
        self.assertIn('config/craft_needs.json', ATLAS)
        self.assertIn('craft_needs.dm', DME)
        self.assertIn("need.get('water')", ATLAS)

    def test_water_is_drawn_from_a_container_or_running_water(self):
        self.assertIn('if (spec["water"])', SOURCE)
        self.assertIn('craft_need_water(H, water, candidates)', SOURCE)
        self.assertIn('C.reagents.remove_reagent("water", line["amount"])', SOURCE)
        for product in ('/obj/item/weapon/clay/advclaybricks', '/obj/item/weapon/clay/advclaybricks/cement', '/obj/item/weapon/paper'):
            self.assertEqual(NEEDS[product].get('water'), 10, product)


    def test_logs_and_sawn_planks_both_pay_for_wood(self):
        # Player report 2026-11-16: the iron sickle asked for a "wooden plank"
        # (the log stack's old name) and never counted a sawn plank.
        self.assertIn('/obj/item/stack/material/wood = list(/obj/item/stack/material/woodplank)', SOURCE)
        self.assertIn('/obj/item/stack/material/wood = "wood (a log or a plank)"', SOURCE)
        stack = SOURCE[SOURCE.index('/proc/craft_need_stack('):SOURCE.index('// The loose items')]
        self.assertIn('craft_need_alternates[stack_type]', stack)
        self.assertIn('istype(S, accepted_type)', stack)
        self.assertNotIn('istype(S, stack_type)', stack)
        lines = SOURCE[SOURCE.index('/proc/craft_need_lines('):SOURCE.index('/proc/craft_needs_refusal(')]
        self.assertIn('craft_need_input_names[input_type]', lines)
        self.assertIn('[amount] [shown_name] (held or at your feet)', lines)
        for product, need in NEEDS.items():
            self.assertNotIn('/obj/item/stack/material/woodplank', need['inputs'], product)


if __name__ == '__main__':
    unittest.main()
