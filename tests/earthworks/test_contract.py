"""Source contracts for the steam roller and steam shovel; this suite does not run DM.

- Both have a recipe, part inputs and a research node, refuse to work without
  fuel and burn one job of fuel a job.
- The roller only lays road types the operator may craft, only on tiles the
  ordinary floor rules allow, charges one stone a tile and lays nothing when
  the wait fails.
- The shovel takes only loose dirt and sand the ground still has, never from
  under a floor, and never more than one load.
"""
import json
import re
import subprocess
import sys
import unittest
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/modules/1713/earthworks.dm').read_text(encoding='utf-8')
RECIPES = (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8')
NODES = (ROOT / 'code/modules/research_tree/research_node.dm').read_text(encoding='utf-8')
NEEDS = json.loads((ROOT / 'config/craft_needs.json').read_text(encoding='utf-8'))
DME = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
BASE = '/obj/structure/workshop_machine/steam_site'
ROLLER = BASE + '/road_roller'
SHOVEL = BASE + '/steam_shovel'
PART = '/obj/item/machine_part/'
MACHINES = {
    ROLLER: ('rail_steam', {PART + 'gear': 1, PART + 'shaft': 2, PART + 'bearing': 2}),
    SHOVEL: ('steam_power', {PART + 'gear': 1, PART + 'shaft': 1, PART + 'bearing': 2}),
}


def proc_body(header):
    start = SOURCE.index(header)
    return SOURCE[start:SOURCE.find('\n/', start + 1)]


class Earthworks(unittest.TestCase):
    def test_recipes_parts_and_nodes(self):
        rows = {}
        for line in RECIPES.splitlines():
            if line.startswith('RECIPE: '):
                f = line[len('RECIPE: '):].split(',')
                rows.setdefault(f[2], []).append(f)
        for path, (node, inputs) in MACHINES.items():
            self.assertEqual(len(rows[path]), 1, path)
            self.assertEqual((rows[path][0][0], float(rows[path][0][3])), ('/material/iron/', 20), path)
            self.assertIn('"%s" = "%s"' % (path, node), NODES)
            self.assertEqual(NEEDS[path], {'tools': [], 'inputs': inputs}, path)
        self.assertIn('#include "code\\modules\\1713\\earthworks.dm"', DME)

    def test_no_fuel_no_job_and_one_job_of_fuel_a_job(self):
        self.assertIn('if (fuel >= 1)\n\t\treturn FALSE', proc_body(BASE + '/proc/out_of_fuel('))
        for header in (ROLLER + '/attack_hand(', SHOVEL + '/attack_hand('):
            self.assertIn('if (out_of_fuel(H))\n\t\treturn', proc_body(header))
        self.assertIn('fuel = max(0, fuel - 1)', proc_body(ROLLER + '/proc/pave('))
        self.assertIn('fuel = max(0, fuel - 1)', proc_body(SHOVEL + '/attack_hand('))
        stoke = proc_body(BASE + '/proc/stoke(')
        self.assertIn('solid_fuel_unit_value(S, steam_crane_fuel_rates)', stoke)
        self.assertIn('min(S.amount, round((fuel_limit - fuel) / each))', stoke)

    def test_roller_lays_only_roads_the_operator_may_craft(self):
        hand = proc_body(ROLLER + '/attack_hand(')
        self.assertIn('if (crafting_recipe_allowed(H, "[road_roller_types[label]]"))', hand)
        self.assertIn('player_input(H, ', hand)
        self.assertNotIn(' input(', SOURCE)
        self.assertIn('(direction & (direction - 1))', hand)
        types = re.search(r'road_roller_types = list\((.*?)\n\)', SOURCE, re.S).group(1)
        for path in re.findall(r'= (/obj/covers/roads/[a-z/]+)', types):
            self.assertIn('"%s" = "paved_infrastructure"' % path, NODES)
            self.assertIn(',%s,' % path, RECIPES)

    def test_roller_follows_the_floor_rules_and_pays_a_stone_a_tile(self):
        problem = proc_body(ROLLER + '/proc/tile_problem(')
        self.assertIn('if (!T || T.density || building_open_turf(T))', problem)
        self.assertIn('istype(T, /turf/floor/beach/water) || istype(T, /turf/floor/lava)', problem)
        self.assertIn('if (A != src && A.density)', problem)
        self.assertIn('return tile_build_refusal(T, road_type)', problem)
        self.assertIn('var/limit = min(ROLLER_MAX_RUN, stone)', proc_body(ROLLER + '/proc/run_tiles('))
        pave = proc_body(ROLLER + '/proc/pave(')
        wait = pave.index('do_after(H, max(10, ROLLER_TILE_TIME * length(run)), src)')
        self.assertLess(wait, pave.index('new road_type(T)'))
        self.assertIn('if (!done || anchored || !operator_ready(H))', pave)
        # Each tile is rechecked after the wait, and the roller only moves where saving allows.
        self.assertIn('if (stone <= 0 || tile_problem(T, road_type) || !persistence_movement_allowed(src, T))\n\t\t\tbreak', pave)
        self.assertIn('stone -= 1', pave)
        self.assertIn('persistence_set_loc(last)', pave)
        self.assertEqual(pave.count('do_after('), 1)
        self.assertIn('new /obj/item/stack/material/stone/quarried(get_turf(src), stone)', proc_body(ROLLER + '/dismantled()'))

    def test_shovel_takes_only_loose_ground_within_a_load(self):
        found = proc_body(SHOVEL + '/proc/diggings()')
        self.assertIn('var/left = SHOVEL_MAX_LOAD', found)
        self.assertIn('if (locate(/obj/covers) in T)\n\t\t\tcontinue', found)
        self.assertIn('loose = T.available_dirt', found)
        self.assertIn('loose = T.available_sand', found)
        self.assertIn('loose = min(loose, left)', found)
        dig = proc_body(SHOVEL + '/proc/dig(')
        # What is dug is counted again after the wait, from the ground as it then is.
        self.assertIn('var/list/found = diggings()', dig)
        self.assertIn('T.available_dirt -= take', dig)
        self.assertIn('T.available_sand -= take', dig)
        self.assertIn('new /obj/item/weapon/barrier(heap)', dig)
        self.assertIn('new /obj/item/stack/ore/glass(heap, sand)', dig)
        hand = proc_body(SHOVEL + '/attack_hand(')
        self.assertIn('if (!done || !anchored || !operator_ready(H))', hand)
        self.assertEqual(hand.count('do_after('), 1)

    def test_sprite_sheet_states_and_script(self):
        data = (ROOT / 'icons/obj/earthworks.dmi').read_bytes()
        at = data.index(b'zTXtDescription\x00\x00') + len(b'zTXtDescription\x00\x00')
        text = zlib.decompressobj().decompress(data[at:]).decode()
        states = {m.group(1): int(m.group(2))
                  for m in re.finditer(r'state = "([^"]+)"\n\tdirs = 1\n\tframes = (\d+)', text)}
        self.assertEqual(states, {'steam_roller': 1, 'steam_roller_on': 4, 'steam_shovel': 1, 'steam_shovel_on': 4})
        for state in ('steam_roller', 'steam_shovel'):
            self.assertIn('icon_state = "%s"\n' % state, SOURCE)
            self.assertIn('icon_state = "%s_on"' % state, SOURCE)
        try:
            import PIL  # noqa: F401
        except ImportError:
            self.skipTest('Pillow not installed')
        done = subprocess.run([sys.executable, str(ROOT / 'tests/sprites/create_earthworks.py'), '--check'],
                              capture_output=True, text=True)
        self.assertEqual(done.returncode, 0, done.stdout + done.stderr)


if __name__ == '__main__':
    unittest.main()
