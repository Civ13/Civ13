"""Source contracts for the powered cranes; this suite does not run DM.

- The steam crane and tower crane each have a recipe, part inputs and a
  research node, and are the shear-legs hoist with their own engine.
- A powered crane refuses to haul without fuel, burns one haul a haul and
  winds in a fraction of the hand time.
- The tower crane takes motor fuel, and only moves a load through open air:
  up while the tile over the load is open, down a column that stays open.
"""
import json
import re
import subprocess
import sys
import unittest
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/modules/1713/power_cranes.dm').read_text(encoding='utf-8')
LIFTING = (ROOT / 'code/modules/1713/lifting_machines.dm').read_text(encoding='utf-8')
RECIPES = (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8')
NODES = (ROOT / 'code/modules/research_tree/research_node.dm').read_text(encoding='utf-8')
NEEDS = json.loads((ROOT / 'config/craft_needs.json').read_text(encoding='utf-8'))
DME = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
STEAM = '/obj/structure/workshop_machine/shear_legs/crane/steam'
TOWER = STEAM + '/tower'
PART = '/obj/item/machine_part/'
# path -> (material, amount, node, inputs)
CRANES = {
    STEAM: ('/material/iron/', 20, 'steam_power', {PART + 'gear': 1, PART + 'shaft': 1, PART + 'bearing': 2}),
    TOWER: ('/material/steel/', 30, 'modern_construction', {PART + 'gear': 2, PART + 'shaft': 1, PART + 'bearing': 2}),
}


def proc_body(header):
    start = SOURCE.index(header)
    return SOURCE[start:SOURCE.find('\n/', start + 1)]


class PowerCranes(unittest.TestCase):
    def test_recipes_parts_and_nodes(self):
        rows = {}
        for line in RECIPES.splitlines():
            if line.startswith('RECIPE: '):
                f = line[len('RECIPE: '):].split(',')
                rows.setdefault(f[2], []).append(f)
        for path, (material, amount, node, inputs) in CRANES.items():
            self.assertEqual(len(rows[path]), 1, path)
            self.assertEqual((rows[path][0][0], float(rows[path][0][3])), (material, amount), path)
            self.assertIn('"%s" = "%s"' % (path, node), NODES)
            self.assertEqual(NEEDS[path], {'tools': [], 'inputs': inputs}, path)
        self.assertIn('#include "code\\modules\\1713\\power_cranes.dm"', DME)

    def test_a_powered_crane_is_the_shear_legs_hoist(self):
        # The haul itself, its checks and its single wait stay in lifting_machines.dm.
        self.assertNotIn('/haul(', SOURCE)
        self.assertNotIn('do_after', SOURCE)
        self.assertIn('driven_time(needs_hoist(load) ? heavy_time : haul_time)', LIFTING)
        self.assertIn('reach = 4', proc_body('\n' + STEAM + '\n'))
        self.assertIn('reach = 6', proc_body('\n' + TOWER + '\n'))

    def test_no_fuel_no_haul_and_one_haul_of_fuel_a_haul(self):
        self.assertIn('if (fuel >= 1)\n\t\treturn FALSE', proc_body(STEAM + '/proc/out_of_fuel('))
        self.assertIn('if (out_of_fuel(user))\n\t\treturn', proc_body(STEAM + '/MouseDrop_T('))
        self.assertIn('if (!istype(H) || out_of_fuel(H))\n\t\treturn', proc_body(STEAM + '/attack_hand('))
        wind = proc_body(STEAM + '/driven_time(base_time)')
        self.assertIn('fuel = max(0, fuel - 1)', wind)
        self.assertIn('max(POWER_CRANE_MIN_TIME, round(base_time * POWER_CRANE_FACTOR))', wind)
        self.assertIn('#define POWER_CRANE_FACTOR 0.35', SOURCE)

    def test_fuel_is_taken_only_up_to_the_limit(self):
        solid = proc_body(STEAM + '/proc/take_fuel(')
        self.assertIn('solid_fuel_unit_value(S, steam_crane_fuel_rates)', solid)
        self.assertIn('min(S.amount, round((fuel_limit - fuel) / each))', solid)
        self.assertIn('S.use(moved)', solid)
        motor = proc_body(TOWER + '/take_fuel(')
        self.assertIn('for (var/id in tower_crane_fuels)', motor)
        self.assertIn('min(room - added, round(C.reagents.get_reagent_amount(id) / TOWER_CRANE_FUEL_UNITS))', motor)
        self.assertIn('C.reagents.remove_reagent(id, hauls * TOWER_CRANE_FUEL_UNITS)', motor)
        self.assertNotIn('solid_fuel', motor)
        self.assertIn('tower_crane_fuels = list("diesel", "biodiesel", "gasoline")', SOURCE)
        ids = (ROOT / 'code/modules/reagents/Chemistry-Reagents/Chemistry-Reagents-Other.dm').read_text(encoding='utf-8')
        for fuel in ('diesel', 'biodiesel', 'gasoline'):
            self.assertIn('id = "%s"' % fuel, ids)

    def test_tower_crane_moves_loads_only_through_open_air(self):
        body = proc_body(TOWER + '/haul_choices(')
        self.assertIn('lift_levels = 3', proc_body('\n' + TOWER + '\n'))
        self.assertEqual(body.count('for (var/i = 1 to lift_levels)'), 2)
        # Up: every level passed must be open over the load.
        self.assertIn('if (!level || !edge_open_air(locate(load.x, load.y, level)))\n\t\t\tbreak', body)
        self.assertIn('landing_on(level)', body)
        # Down: only columns open on the crane's level, kept only while they stay open.
        self.assertIn('if (edge_open_air(T))\n\t\t\tcolumns += T', body)
        self.assertIn('if (edge_open_air(under))\n\t\t\t\tdeeper += T', body)
        self.assertIn('if (!ledge_landing_clear(under))\n\t\t\t\tcontinue', body)
        self.assertIn('columns = deeper', body)
        self.assertIn('if (!level || !length(columns))\n\t\t\tbreak', body)

    def test_sprite_sheet_states_and_script(self):
        data = (ROOT / 'icons/obj/power_cranes.dmi').read_bytes()
        at = data.index(b'zTXtDescription\x00\x00') + len(b'zTXtDescription\x00\x00')
        text = zlib.decompressobj().decompress(data[at:]).decode()
        states = {m.group(1): int(m.group(2))
                  for m in re.finditer(r'state = "([^"]+)"\n\tdirs = 1\n\tframes = (\d+)', text)}
        self.assertEqual(states, {'steam_crane': 1, 'steam_crane_haul': 4, 'tower_crane': 1, 'tower_crane_haul': 4})
        for state in ('steam_crane', 'tower_crane'):
            self.assertIn('base_state = "%s"' % state, SOURCE)
        try:
            import PIL  # noqa: F401
        except ImportError:
            self.skipTest('Pillow not installed')
        done = subprocess.run([sys.executable, str(ROOT / 'tests/sprites/create_power_cranes.py'), '--check'],
                              capture_output=True, text=True)
        self.assertEqual(done.returncode, 0, done.stdout + done.stderr)


if __name__ == '__main__':
    unittest.main()
