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
RECIPES = (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8')
NODES = (ROOT / 'code/modules/research_tree/research_node.dm').read_text(encoding='utf-8')
NEEDS = json.loads((ROOT / 'config/craft_needs.json').read_text(encoding='utf-8'))
PARTS = (ROOT / 'code/modules/materials/machine_parts.dm').read_text(encoding='utf-8')
DME = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
DMI = ROOT / 'icons/obj/mechanical_power.dmi'
BASE = '/obj/structure/workshop_machine/mover'
GEAR, SHAFT, BEARING, BELT = ('/obj/item/machine_part/' + n for n in ('gear', 'shaft', 'bearing', 'belt'))
CRANE = '/obj/structure/workshop_machine/shear_legs/crane'
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
        body = proc_body(SOURCE, '/proc/mechanical_drive_factor(atom/A)')
        self.assertIn('range(MECHANICAL_DRIVE_REACH, T)', body)
        self.assertIn('if (factor < .)', body)
        # no process, no timer, no registry of movers or machines
        for banned in ('spawn', 'sleep(', 'process(', 'addtimer', 'var/global/list/mechanical', '/process/'):
            self.assertNotIn(banned, SOURCE, banned)
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
        self.assertIn('map.windspeedvar', SOURCE)

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
        self.assertEqual(states, expected)
        self.assertIn('icon_state = turning() ? "[base_state]_on" : base_state', SOURCE)
        try:
            import PIL  # noqa: F401
        except ImportError:
            self.skipTest('Pillow not installed')
        result = subprocess.run([sys.executable, str(ROOT / 'tests/sprites/create_mechanical_power.py'), '--check'],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == '__main__':
    unittest.main()
