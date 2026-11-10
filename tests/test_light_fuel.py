"""Source checks for light fuel, refuelling and handle torches.

No compiler, game or network. They pin the declarations that give portable
lights finite fuel and a refill route, and that make torches from tool handles.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
LANTERN = 'code/modules/1713/lantern.dm'
FUEL = 'code/modules/1713/light_fuel.dm'
LIGHTERS = 'code/game/objects/items/weapons/cigs_lighters.dm'
FLASHLIGHT = 'code/game/objects/items/devices/flashlight.dm'
PHONE = 'code/modules/1713/telephone.dm'


def source(path):
    return (ROOT / path).read_text(encoding='utf-8')


def type_block(text, path):
    match = re.search(r'^' + re.escape(path) + r'\n((?:\t[^\n]*\n|\n)*)', text, re.M)
    if not match:
        raise AssertionError('missing type block ' + path)
    return match[1]


def proc_body(text, path):
    match = re.search(r'^' + re.escape(path) + r'\([^\n]*\)\n((?:\t[^\n]*\n|\n)*)', text, re.M)
    if not match:
        raise AssertionError('missing proc ' + path)
    return match[1]


class LightFuelTests(unittest.TestCase):
    def test_military_lens_cycles_keep_both_sprite_families_and_effect_order(self):
        text = source(LANTERN)
        base = '/obj/item/flashlight/militarylight'
        for subtype, prefix in (('', 'militarylight'), ('/alt', 'militarylightalt')):
            body = proc_body(text, base + subtype + '/secondary_attack_self')
            self.assertEqual(body.strip(),
                'return cycle_lens(user, "{0}_on_red", "{0}_on_green", "{0}_on")'.format(prefix))

        body = proc_body(text, base + '/proc/cycle_lens')
        self.assertRegex(body, r'^\s*\tlens \+=1\n\tif \(lens > 3\)\n\t\tlens = 1\n\n\tswitch \(lens\)')
        cases = re.findall(r'(?ms)^\t\tif \(([123])\)\n(.*?)(?=^\t\tif \(|\Z)', body)
        self.assertEqual([number for number, _ in cases], ['1', '2', '3'])
        expected = {
            '1': ('1.5', '2.5', '#ad2005', 'red_state', 'red', ('message', 'icon')),
            '2': ('1.5', '2.5', '#17ad2a', 'green_state', 'green', ('icon', 'message')),
            '3': ('5', '5', '#fcffd6', 'clear_state', 'remove', ('message', 'icon')),
        }
        for number, case in cases:
            light_range, brightness, color, sprite, message, order = expected[number]
            self.assertIn('light_range = ' + light_range + '\n', case)
            self.assertIn('brightness_on = ' + brightness + '\n', case)
            self.assertIn('light_color = "' + color + '"\n', case)
            self.assertIn('on_state = ' + sprite + '\n', case)
            self.assertIn('lens = ' + number + '\n', case)
            self.assertIn(message, case)
            events = tuple('message' if line.strip().startswith('to_chat(') else 'icon'
                           for line in case.splitlines()
                           if line.strip().startswith(('to_chat(', 'update_icon(')))
            self.assertEqual(events, order)
            self.assertTrue(case.rstrip().endswith('return'))

    def test_electric_flashlights_are_finite_and_take_batteries(self):
        text = source(LANTERN)
        for path in ('/obj/item/flashlight/flashlight', '/obj/item/flashlight/modern',
                     '/obj/item/flashlight/militarylight', '/obj/item/flashlight/militarylight/alt'):
            block = type_block(text, path)
            self.assertNotIn('unlimited = TRUE', block, path)
            self.assertNotIn('uses_batteries = FALSE', block, path)
        base = type_block(source(FLASHLIGHT), '/obj/item/flashlight')
        self.assertIn('var/uses_batteries = TRUE', base)
        self.assertIn('var/max_fuel', base)
        fuel = source(FUEL)
        self.assertIn('/obj/item/weapon/battery\n', fuel)
        self.assertIn('istype(W, /obj/item/weapon/battery)', proc_body(fuel, '/obj/item/flashlight/attackby'))

    def test_dynamo_flashlight_winds(self):
        block = type_block(source(LANTERN), '/obj/item/flashlight/japflashlight')
        self.assertNotIn('unlimited = TRUE', block)
        self.assertIn('uses_batteries = FALSE', block)
        body = proc_body(source(FUEL), '/obj/item/flashlight/japflashlight/proc/wind_dynamo')
        self.assertIn('do_after(user', body)
        self.assertIn('fuel = min(max_fuel', body)

    def test_burning_lights_refill_with_oil(self):
        text = source(LANTERN)
        for path in ('/obj/item/flashlight/lantern', '/obj/item/flashlight/torch', '/obj/item/flashlight/tiki_torch'):
            block = type_block(text, path)
            self.assertIn('refuel_reagents = list(', block, path)
            self.assertIn('max_fuel = ', block, path)
            self.assertIn('"fat_oil"', block, path)
        # The old lantern handler took the whole container regardless of capacity.
        self.assertNotIn('/obj/item/flashlight/lantern/attackby(', text)
        refuel = proc_body(source(FUEL), '/obj/item/flashlight/proc/refuel_from_container')
        self.assertIn('max_fuel - max(0, fuel)', refuel)

    def test_lighters_burn_fluid_and_refill(self):
        text = source(LIGHTERS)
        block = type_block(text, '/obj/item/weapon/flame/lighter')
        self.assertIn('var/fuel = ', block)
        self.assertIn('"gasoline"', block)
        self.assertIn('fuel = ', type_block(text, '/obj/item/weapon/flame/lighter/zippo'))
        drain = proc_body(text, '/obj/item/weapon/flame/lighter/process_interval')
        self.assertIn('fuel = max(0, fuel - configured_seconds)', drain)
        self.assertIn('return PROCESS_KILL', drain)
        self.assertIn('fuel <= 0', proc_body(text, '/obj/item/weapon/flame/lighter/attack_self'))
        self.assertIn('light_fuel_from_container', proc_body(source(FUEL), '/obj/item/weapon/flame/lighter/attackby'))

    def test_smartphone_torch_uses_charge(self):
        text = source(PHONE)
        self.assertIn('var/torch_charge = ', type_block(text, '/obj/item/weapon/telephone/mobile/smartphone'))
        self.assertIn('torch_charge <= 0', proc_body(text, '/obj/item/weapon/telephone/mobile/smartphone/secondary_attack_self'))
        drain = proc_body(source(FUEL), '/obj/item/weapon/telephone/mobile/smartphone/process_interval')
        self.assertIn('torch_charge - configured_seconds', drain)

    def test_torches_come_from_handles_and_return_them(self):
        fuel = source(FUEL)
        make = proc_body(fuel, '/obj/item/weapon/material/handle/attackby')
        self.assertIn('/obj/item/weapon/reagent_containers/food/snacks/animalfat', make)
        self.assertIn('make_torch(', make)
        craft = proc_body(fuel, '/obj/item/weapon/material/handle/proc/make_torch')
        self.assertIn('torch.handle_material = material.name', craft)
        burn = proc_body(fuel, '/obj/item/flashlight/torch/burn_out_light')
        self.assertIn('new(handle_loc, handle_material', burn)
        self.assertIn('refresh_light_holder_later(holder)', burn)
        loop = proc_body(source(LANTERN), '/obj/item/flashlight/proc/do_torch')
        self.assertIn('burn_out_light()', loop)
        self.assertNotIn('qdel(src)', loop)

    def test_recipes(self):
        for path in sorted((ROOT / 'config/crafting').glob('material_recipes_*.txt')):
            text = path.read_text(encoding='utf-8')
            self.assertNotRegex(text, r'(?m)^RECIPE: [^,]*,torch,/obj/item/flashlight/torch,', path.name)
        global_text = source('config/crafting/material_recipes_global.txt')
        self.assertRegex(global_text, r'(?m)^RECIPE: /material/copper/,battery,/obj/item/weapon/battery,')
        self.assertIn('"/obj/item/weapon/battery" = "electricity"', source('code/modules/research_tree/research_node.dm'))


if __name__ == '__main__':
    unittest.main()
