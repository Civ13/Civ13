"""Prime movers and the short-range mechanical drive: source contract checks.

Each mover has a recipe that takes standard machine parts, a research node and
sprite states; the drive is asked on demand with no process or list; and the
workshop machines and hoists take their step time through driven_time().

    python3 tests/mechanical_power/test_contract.py
"""
import json
import re
import subprocess
import sys
import unittest
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/modules/1713/mechanical_power.dm').read_text(encoding='utf-8')
TRANSMISSION = (ROOT / 'code/modules/1713/transmission.dm').read_text(encoding='utf-8')
RECIPES = (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8')
NODES = (ROOT / 'code/modules/research_tree/research_node.dm').read_text(encoding='utf-8')
NEEDS = json.loads((ROOT / 'config/craft_needs.json').read_text(encoding='utf-8'))
PARTS = (ROOT / 'code/modules/materials/machine_parts.dm').read_text(encoding='utf-8')
DME = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
DMI = ROOT / 'icons/obj/mechanical_power.dmi'
BASE = '/obj/structure/workshop_machine/mover'
GEAR, SHAFT, BEARING, BELT = ('/obj/item/machine_part/' + n for n in ('gear', 'shaft', 'bearing', 'belt'))
CRANE = '/obj/structure/workshop_machine/shear_legs/crane'
HAMMER = '/obj/structure/workshop_machine/trip_hammer'
SHOP_SOURCE = (ROOT / 'code/modules/1713/machine_shop.dm').read_text(encoding='utf-8')
ANVIL_RECIPES = (ROOT / 'code/game/objects/structures/blacksmithing/blacksmithing_recipes.dm').read_text(encoding='utf-8')
PART = '/obj/item/machine_part/'
# path -> (iron, research node, part inputs)
SHOP = {
    '/obj/structure/workshop_machine/trip_hammer/steam': (16, 'steam_power', {PART + 'shaft': 1, PART + 'spring': 1}),
    '/obj/structure/workshop_machine/fitting/drill_press': (10, 'machined_tools', {PART + 'gear': 1, PART + 'shaft': 1, PART + 'belt': 1}),
    '/obj/structure/workshop_machine/fitting/hydraulic_press': (14, 'factories', {PART + 'shaft': 1, PART + 'bearing': 2}),
}
# path: (wood, node, part inputs, share of hand time)
MOVERS = {
    BASE + '/treadwheel': (12, 'stone_masonry', {SHAFT: 1, BEARING: 2}, 0.65),
    BASE + '/horse_gin': (10, 'resource_processing', {GEAR: 1, SHAFT: 1, BEARING: 1}, 0.5),
    BASE + '/mill_wheel': (14, 'watermills', {GEAR: 1, SHAFT: 1, BEARING: 2}, 0.4),
    BASE + '/windmill': (16, 'watermills', {GEAR: 1, SHAFT: 1, BEARING: 2}, 0.5),
}


def recipe_rows():
    rows = {}
    for line in RECIPES.splitlines():
        if line.startswith('RECIPE: '):
            f = line[len('RECIPE: '):].split(',')
            rows.setdefault(f[2], []).append(f)
    return rows


def proc_body(text, header):
    start = text.index(header)
    end = text.find('\n/', start + 1)
    return text[start:end]


def type_block(path):
    start = SOURCE.index('\n' + path + '\n') + 1
    return SOURCE[start:SOURCE.find('\n/', start + 1)]


class MechanicalPower(unittest.TestCase):
    def test_every_mover_has_a_recipe_parts_and_a_research_node(self):
        rows = recipe_rows()
        for path, (wood, node, parts, factor) in MOVERS.items():
            self.assertEqual(len(rows.get(path, [])), 1, path)
            self.assertEqual((rows[path][0][0], float(rows[path][0][3])), ('/material/wood/', wood), path)
            self.assertIn('"%s" = "%s"' % (path, node), NODES)
            self.assertEqual(NEEDS[path], {'tools': [], 'inputs': parts}, path)
            block = type_block(path)
            self.assertIn('drive_factor = %s\n' % factor, block)
            name = path.rsplit('/', 1)[1]
            self.assertIn('base_state = "%s"' % name, block)

    def test_crane_recipe_parts_and_node(self):
        rows = recipe_rows()[CRANE]
        self.assertEqual(len(rows), 1)
        self.assertEqual((rows[0][0], float(rows[0][3])), ('/material/wood/', 16))
        self.assertIn('"%s" = "imperial_architecture"' % CRANE, NODES)
        self.assertEqual(NEEDS[CRANE], {'tools': [], 'inputs': {SHAFT: 1, BEARING: 2, BELT: 1}})

    def test_part_inputs_are_the_standard_part_types(self):
        for path in (GEAR, SHAFT, BEARING, BELT):
            self.assertRegex(PARTS, r'(?m)^%s$' % re.escape(path))

    def test_drive_is_asked_on_demand_and_is_short_range(self):
        self.assertIn('#define MECHANICAL_DRIVE_REACH 1', SOURCE)
        self.assertIn('return mechanical_load_factor(mechanical_drive_load(A))', proc_body(SOURCE, '/proc/mechanical_drive_factor(atom/A)'))
        body = proc_body(SOURCE, '/proc/mechanical_drive_load(atom/A)')
        self.assertIn('range(MECHANICAL_DRIVE_REACH, T)', body)
        self.assertIn('best = min(best, factor)', body)
        # the search through transmission parts is bounded
        self.assertIn('queue.len < MECHANICAL_DRIVE_SEARCH_LIMIT', body)
        load = proc_body(SOURCE, '/proc/mechanical_load_factor(list/load)')
        self.assertIn('return 1 - (1 - best) * share', load)
        # no process, no timer, no registry of movers or machines
        for text in (SOURCE, TRANSMISSION):
            for banned in ('spawn', 'sleep(', 'process(', 'addtimer', 'var/global/list/mechanical', '/process/'):
                self.assertNotIn(banned, text, banned)
        self.assertNotIn('mechanical_power', (ROOT / 'code/modules/persistence/world_time_stamps.dm').read_text(encoding='utf-8'))

    def test_a_mover_only_drives_when_fastened_and_turning(self):
        self.assertIn('return anchored && isturf(loc) && !idle_reason()', proc_body(SOURCE, BASE + '/proc/turning()'))
        self.assertIn('return turning() ? drive_factor : 1', proc_body(SOURCE, BASE + '/proc/current_factor()'))
        step = proc_body(SOURCE, '/obj/structure/workshop_machine/proc/driven_time(base_time)')
        self.assertIn('max(MECHANICAL_MIN_TIME, round(base_time * mechanical_drive_factor(src)))', step)

    def test_each_mover_names_what_turns_it(self):
        tread = proc_body(SOURCE, BASE + '/treadwheel/idle_reason()')
        self.assertIn('for (var/mob/living/human/H in loc)', tread)
        self.assertIn('!H.stat && !H.lying && !H.restrained()', tread)
        self.assertIn('density = FALSE', type_block(BASE + '/treadwheel'))
        gin = proc_body(SOURCE, BASE + '/horse_gin/idle_reason()')
        self.assertIn('A.stat == DEAD', gin)
        self.assertIn('/mob/living/simple_animal/horse', SOURCE)
        self.assertIn('/mob/living/simple_animal/cattle', SOURCE)
        self.assertIn('river_current_direction(T)', proc_body(SOURCE, BASE + '/mill_wheel/idle_reason()'))
        wind = proc_body(SOURCE, BASE + '/windmill/idle_reason()')
        self.assertIn('A.location != AREA_OUTSIDE', wind)
        self.assertIn('if (!wind_speed())', wind)
        self.assertIn('weather_wind_at(src)', proc_body(SOURCE, BASE + '/windmill/proc/wind_speed()'))

    def test_machines_and_hoists_take_their_time_from_the_drive(self):
        uses = {
            'code/modules/1713/clay_lime_fire.dm': 'do_after(H, driven_time(max(5, round(cost[2] / POTTERS_WHEEL_SPEED))), src)',
            'code/modules/1713/glass_stone_machines.dm': 'do_after(H, driven_time(MASONS_SAW_TIME), src)',
            'code/modules/1713/building_site.dm': 'do_after(H, driven_time(CEMENT_MIXER_TIME), src)',
            'code/modules/1713/lifting_machines.dm': 'do_after(H, driven_time(needs_hoist(load) ? heavy_time : haul_time), src)',
        }
        for path, call in uses.items():
            self.assertIn(call, (ROOT / path).read_text(encoding='utf-8'), path)
        self.assertLess(DME.index('clay_lime_fire.dm'), DME.index('mechanical_power.dm'))

    def test_trip_hammer_recipe_parts_and_node(self):
        rows = recipe_rows()[HAMMER]
        self.assertEqual(len(rows), 1)
        self.assertEqual((rows[0][0], float(rows[0][3])), ('/material/wood/', 10))
        self.assertIn('"%s" = "watermills"' % HAMMER, NODES)
        self.assertEqual(NEEDS[HAMMER], {'tools': [], 'inputs': {'/obj/item/stack/material/iron': 6, SHAFT: 1}})

    def test_trip_hammer_only_helps_when_fastened_and_driven(self):
        self.assertIn('return anchored && isturf(loc) && mechanical_drive_factor(src) < 1',
                      proc_body(SOURCE, HAMMER + '/proc/striking()'))
        self.assertIn('return striking() ? TRIP_HAMMER_FACTOR : 1', proc_body(SOURCE, HAMMER + '/forge_factor(category)'))
        self.assertIn('#define TRIP_HAMMER_FACTOR 0.5', SOURCE)
        self.assertIn('forge_role = "hammer"', type_block(HAMMER))

    def test_the_anvil_takes_the_best_machine_of_each_role(self):
        body = proc_body(SOURCE, '/obj/structure/anvil/proc/forge_time(base_time, category = null)')
        self.assertIn('for (var/obj/structure/workshop_machine/W in range(1, src))', body)
        self.assertIn('var/left = W.forge_factor(category)', body)
        self.assertIn('if (left < 1 && (!best[W.forge_role] || left < share[W.forge_role]))', body)
        self.assertIn('if (!length(best))\n\t\treturn base_time', body)
        self.assertIn('W.forge_used()', body)
        self.assertIn('return max(FORGE_MIN_TIME, round(time))', body)
        self.assertIn('#define FORGE_MIN_TIME 10', SOURCE)
        # A machine that is no helper gives no help.
        self.assertIn('return 1', proc_body(SOURCE, '/obj/structure/workshop_machine/proc/forge_factor(category)'))

    def test_both_anvil_forging_waits_ask_with_the_recipe_category(self):
        anvil = (ROOT / 'code/game/objects/structures/blacksmithing/blacksmithing.dm').read_text(encoding='utf-8')
        self.assertIn('trade_time(user, forge_time(10*anvil_recipes[parsed_choice2[1]][material_index],anvil_recipes[parsed_choice2[1]][2]), "smith")),src,can_move=FALSE)', anvil)
        self.assertIn('trade_time(user, forge_time(10*mat,row[2]), "smith")),src,can_move=FALSE)', anvil)
        self.assertNotIn('do_after(user,10*anvil_recipes', anvil)
        self.assertNotIn('do_after(user,10*mat', anvil)

    def test_machine_shop_recipes_parts_and_nodes(self):
        rows = recipe_rows()
        for path, (amount, node, inputs) in SHOP.items():
            self.assertEqual(len(rows[path]), 1, path)
            self.assertEqual((rows[path][0][0], float(rows[path][0][3])), ('/material/iron/', amount), path)
            self.assertIn('"%s" = "%s"' % (path, node), NODES)
            self.assertEqual(NEEDS[path], {'tools': [], 'inputs': inputs}, path)
            for part in inputs:
                self.assertIn('\n%s\n' % part, PARTS)
        self.assertIn('#include "code\\modules\\1713\\machine_shop.dm"', DME)

    def test_steam_hammer_burns_one_job_of_fuel_a_job(self):
        steam = '/obj/structure/workshop_machine/trip_hammer/steam'
        self.assertIn('return anchored && isturf(loc) && fuel >= 1', proc_body(SHOP_SOURCE, steam + '/striking()'))
        self.assertIn('return striking() ? STEAM_HAMMER_FACTOR : 1', proc_body(SHOP_SOURCE, steam + '/forge_factor(category)'))
        self.assertIn('fuel = max(0, fuel - 1)', proc_body(SHOP_SOURCE, steam + '/forge_used()'))
        self.assertIn('#define STEAM_HAMMER_FACTOR 0.35', SHOP_SOURCE)
        load = proc_body(SHOP_SOURCE, steam + '/attackby(')
        self.assertIn('solid_fuel_unit_value(S, steam_hammer_fuel_rates)', load)
        self.assertIn('min(S.amount, round((STEAM_HAMMER_FUEL_LIMIT - fuel) / each))', load)
        self.assertNotIn('mechanical_drive_factor', proc_body(SHOP_SOURCE, steam + '/striking()'))

    def test_fitting_machines_help_only_their_own_work(self):
        fitting = '/obj/structure/workshop_machine/fitting'
        self.assertIn('return (category && ready() && helps(category)) ? FITTING_FACTOR : 1',
                      proc_body(SHOP_SOURCE, fitting + '/forge_factor(category)'))
        self.assertIn('#define FITTING_FACTOR 0.6', SHOP_SOURCE)
        self.assertIn('return ..() && mechanical_drive_factor(src) < 1', proc_body(SHOP_SOURCE, fitting + '/drill_press/ready()'))
        self.assertIn('return category in drill_press_categories', proc_body(SHOP_SOURCE, fitting + '/drill_press/helps(category)'))
        self.assertNotIn('/hydraulic_press/ready()', SHOP_SOURCE)
        categories = set(re.findall(r'^\s*"[^"]+" = list\("[^"]*",\s*"([^"]*)"', ANVIL_RECIPES, re.M))
        drilled = set(re.findall(r'"([^"]+)"', re.search(r'drill_press_categories = list\(([^)]*)\)', SHOP_SOURCE).group(1)))
        words = re.findall(r'"([^"]+)"', re.search(r'hydraulic_press_words = list\(([^)]*)\)', SHOP_SOURCE).group(1))
        self.assertTrue(drilled <= categories, drilled - categories)
        pressed = {c for c in categories if any(w in c for w in words)}
        self.assertFalse(pressed & drilled)
        self.assertTrue({'helmets', 'armor', 'shields', 'pasgt armor', 'japanese headwear'} <= pressed)
        # Blades stay hammer work.
        self.assertFalse({'swords', 'knives', 'axes', 'keys'} & (pressed | drilled))

    def test_machine_shop_sheet_states(self):
        data = (ROOT / 'icons/obj/machine_shop.dmi').read_bytes()
        at = data.index(b'zTXtDescription\x00\x00') + len(b'zTXtDescription\x00\x00')
        text = zlib.decompressobj().decompress(data[at:]).decode()
        states = {m.group(1): int(m.group(2))
                  for m in re.finditer(r'state = "([^"]+)"\n\tdirs = 1\n\tframes = (\d+)', text)}
        self.assertEqual(states, {'steam_hammer': 1, 'steam_hammer_on': 4, 'drill_press': 1, 'drill_press_on': 4,
                                  'hydraulic_press': 1, 'hydraulic_press_on': 4})
        self.assertIn('flick("[initial(icon_state)]_on", src)', SOURCE)
        try:
            import PIL  # noqa: F401
        except ImportError:
            self.skipTest('Pillow not installed')
        import subprocess
        import sys
        done = subprocess.run([sys.executable, str(ROOT / 'tests/sprites/create_machine_shop.py'), '--check'],
                              capture_output=True, text=True)
        self.assertEqual(done.returncode, 0, done.stdout + done.stderr)

    def test_sprite_sheet_states_and_script(self):
        data = DMI.read_bytes()
        at = data.index(b'zTXtDescription\x00\x00') + len(b'zTXtDescription\x00\x00')
        text = zlib.decompressobj().decompress(data[at:]).decode()
        states = {m.group(1): int(m.group(2))
                  for m in re.finditer(r'state = "([^"]+)"\n\tdirs = 1\n\tframes = (\d+)', text)}
        expected = {}
        for path in MOVERS:
            name = path.rsplit('/', 1)[1]
            expected[name] = 1
            expected[name + '_on'] = 4
        expected.update({'trip_hammer': 1, 'trip_hammer_on': 4})
        self.assertEqual(states, expected)
        self.assertIn('icon_state = turning() ? "[base_state]_on" : base_state', SOURCE)
        try:
            import PIL  # noqa: F401
        except ImportError:
            self.skipTest('Pillow not installed')
        result = subprocess.run([sys.executable, str(ROOT / 'tests/sprites/create_mechanical_power.py'), '--check'],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


    def test_transmission_recipes_parts_and_nodes(self):
        rows = recipe_rows()
        T = '/obj/structure/workshop_machine/transmission/'
        want = {
            T + 'line_shaft': ('/material/wood/', 4, 'watermills', {BEARING: 1}),
            T + 'line_shaft/clutch': ('/material/wood/', 5, 'watermills', {GEAR: 1, BEARING: 1}),
            T + 'gear_box': ('/material/wood/', 8, 'watermills', {GEAR: 2, SHAFT: 1}),
            T + 'line_shaft/iron': ('/material/iron/', 3, 'machined_tools', {BEARING: 1}),
            T + 'rope_drive': ('/material/iron/', 4, 'machined_tools', {BEARING: 1, '/obj/item/stack/material/rope': 2}),
        }
        for path, (material, count, node, parts) in want.items():
            self.assertEqual(len(rows.get(path, [])), 1, path)
            self.assertEqual((rows[path][0][0], float(rows[path][0][3])), (material, count), path)
            self.assertIn('"%s" = "%s"' % (path, node), NODES)
            self.assertEqual(NEEDS[path], {'tools': [], 'inputs': parts}, path)
        self.assertIn('#define TRANSMISSION_WOOD_RUN 8', TRANSMISSION)
        self.assertIn('#define TRANSMISSION_IRON_RUN 16', TRANSMISSION)
        self.assertIn('code\\modules\\1713\\transmission.dm', DME)

    def test_hopper_machines_recipes_parts_and_step(self):
        rows = recipe_rows()
        H = '/obj/structure/workshop_machine/hopper/'
        want = {
            H + 'millstones': ('/material/stone/', 12, {GEAR: 1, SHAFT: 1}),
            H + 'sash_saw': ('/material/wood/', 10, {GEAR: 1, SHAFT: 1, '/obj/item/stack/material/iron': 2}),
            H + 'fulling_stocks': ('/material/wood/', 10, {SHAFT: 1}),
            H + 'bark_stamps': ('/material/wood/', 8, {SHAFT: 1, '/obj/item/stack/material/iron': 2}),
        }
        for path, (material, count, parts) in want.items():
            self.assertEqual(len(rows.get(path, [])), 1, path)
            self.assertEqual((rows[path][0][0], float(rows[path][0][3])), (material, count), path)
            self.assertIn('"%s" = "watermills"' % path, NODES)
            self.assertEqual(NEEDS[path], {'tools': [], 'inputs': parts}, path)
        hopper = (ROOT / 'code/modules/1713/hopper_machines.dm').read_text(encoding='utf-8')
        self.assertIn('#define HOPPER_OUTPUT_CAP 20', hopper)
        # the drive is asked once a step, not every object tick
        self.assertEqual(hopper.count('mechanical_drive_factor(src)'), 2)
        self.assertIn('if (world.time < next_step)', proc_body(hopper, '/obj/structure/workshop_machine/hopper/process_interval('))

    def test_contraptions_recipes_parts_and_nodes(self):
        rows = recipe_rows()
        want = {
            BASE + '/counterweight': ('/material/wood/', 10, 'watermills', {GEAR: 1, SHAFT: 1, '/obj/item/stack/material/rope': 2}),
            '/obj/structure/mechanism/cam_drum': ('/material/wood/', 6, 'watermills', {GEAR: 1, SHAFT: 1}),
            BASE + '/steam_engine': ('/material/iron/', 16, 'steam_power', {GEAR: 1, SHAFT: 1, BEARING: 2}),
        }
        for path, (material, count, node, parts) in want.items():
            self.assertEqual(len(rows.get(path, [])), 1, path)
            self.assertEqual((rows[path][0][0], float(rows[path][0][3])), (material, count), path)
            self.assertIn('"%s" = "%s"' % (path, node), NODES)
            self.assertEqual(NEEDS[path], {'tools': [], 'inputs': parts}, path)

    def test_bridges_recipes_and_nodes(self):
        rows = recipe_rows()
        for path, material, count, node in (('/obj/structure/mechanism_relay', '/material/copper/', 3, 'electricity'),
                                            ('/obj/item/circuit_shell/mechanism_port', '/material/electronics/', 5, 'digital_computing')):
            self.assertEqual(len(rows.get(path, [])), 1, path)
            self.assertEqual((rows[path][0][0], float(rows[path][0][3])), (material, count), path)
            self.assertIn('"%s" = "%s"' % (path, node), NODES)
        smart = (ROOT / 'code/modules/1713/smart_home.dm').read_text(encoding='utf-8')
        self.assertIn('if (mechanism_relay_open_on(loc))', smart)
        self.assertIn('/proc/mechanism_relay_open_on(', (ROOT / 'tests/power/fixture.dm').read_text(encoding='utf-8'))

    def test_movers_have_a_strength(self):
        for name, cap in (('treadwheel', 1), ('horse_gin', 2), ('mill_wheel', 3)):
            self.assertIn('drive_capacity = %d\n' % cap, type_block(BASE + '/' + name))
        self.assertIn('return min(3, wind_speed())', proc_body(SOURCE, BASE + '/windmill/current_capacity()'))
        self.assertIn('drive_capacity + 1', proc_body(SOURCE, BASE + '/mill_wheel/current_capacity()'))


if __name__ == '__main__':
    unittest.main()
