"""Source contracts for the wire drawing bench; this suite does not run DM.

- The bench has a recipe, part inputs and a research node.
- It draws only the listed metals, into the standard coil types the cable
  code owns, and only for someone who may craft that coil.
- A unit of metal is taken only after its wait succeeds, and gives more cable
  than the hand recipe does.
"""
import json
import re
import subprocess
import sys
import unittest
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/modules/1713/wire_bench.dm').read_text(encoding='utf-8')
WIRES = (ROOT / 'code/modules/materials/wire_materials.dm').read_text(encoding='utf-8')
RECIPES = (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8')
NODES = (ROOT / 'code/modules/research_tree/research_node.dm').read_text(encoding='utf-8')
NEEDS = json.loads((ROOT / 'config/craft_needs.json').read_text(encoding='utf-8'))
DME = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
BENCH = '/obj/structure/workshop_machine/wire_bench'


def proc_body(header):
    start = SOURCE.index(header)
    return SOURCE[start:SOURCE.find('\n/', start + 1)]


class WireBench(unittest.TestCase):
    def test_recipe_parts_and_node(self):
        rows = [line.split(',') for line in RECIPES.splitlines() if ',%s,' % BENCH in line]
        self.assertEqual(len(rows), 1)
        self.assertEqual((rows[0][0], float(rows[0][3])), ('RECIPE: /material/wood/', 8))
        self.assertIn('"%s" = "electricity"' % BENCH, NODES)
        self.assertEqual(NEEDS[BENCH], {'tools': [], 'inputs': {
            '/obj/item/stack/material/iron': 4, '/obj/item/machine_part/shaft': 1}})
        self.assertIn('#include "code\\modules\\1713\\wire_bench.dm"', DME)

    def test_it_draws_the_standard_coils(self):
        table = re.search(r'wire_bench_coils = list\((.*?)\n\)', SOURCE, re.S).group(1)
        pairs = dict(re.findall(r'(/obj/item/stack/material/\w+) = (/obj/item/stack/cable_coil[/\w]*)', table))
        self.assertEqual(pairs['/obj/item/stack/material/copper'], '/obj/item/stack/cable_coil')
        for metal in ('iron', 'aluminium', 'silver', 'gold'):
            coil = '/obj/item/stack/cable_coil/' + metal
            self.assertEqual(pairs['/obj/item/stack/material/' + metal], coil)
            self.assertIn('"%s" = %s' % (metal, coil), WIRES)
            self.assertIn('"%s" = "electricity"' % coil, NODES)
        self.assertEqual(len(pairs), 5)

    def test_only_listed_metal_on_a_fastened_bench(self):
        hand = proc_body(BENCH + '/attackby(')
        self.assertIn('if (!I || !(I.type in wire_bench_coils))\n\t\treturn ..()', hand)
        self.assertIn('if (!can_start_material_work(H))\n\t\treturn\n\tdraw_wire(H, I)', hand)
        self.assertLess(hand.index('handle_machine_tool(I, H)'), hand.index('wire_bench_coils'))

    def test_metal_is_taken_after_each_wait_and_yields_more_than_by_hand(self):
        draw = proc_body(BENCH + '/proc/draw_wire(')
        self.assertIn('!crafting_recipe_allowed(H, "[type]") || !crafting_recipe_allowed(H, "[coil_type]")', draw)
        wait = draw.index('do_after(H, driven_time(WIRE_BENCH_TIME), src)')
        self.assertLess(wait, draw.index('S.use(1)'))
        self.assertIn('if (!worker_ready(H, S) || S.amount < 1 || !crafting_recipe_allowed(H, "[coil_type]"))\n\t\t\tbreak', draw)
        self.assertIn('coil.amount + WIRE_BENCH_YIELD > coil.max_amount', draw)
        self.assertEqual(draw.count('busy = FALSE'), 1)
        yield_ = int(re.search(r'#define WIRE_BENCH_YIELD (\d+)', SOURCE).group(1))
        time = int(re.search(r'#define WIRE_BENCH_TIME (\d+)', SOURCE).group(1))
        coils = (ROOT / 'code/modules/1713/machinery/cables_types.dm').read_text(encoding='utf-8')
        block = coils[coils.index('\n/obj/item/stack/cable_coil\n'):]
        hand_yield = int(re.search(r'\tamount = (\d+)', block).group(1))
        max_amount = int(re.search(r'\tmax_amount = (\d+)', block).group(1))
        self.assertGreater(yield_, hand_yield)
        self.assertLessEqual(yield_, max_amount)
        hand_row = [line.split(',') for line in RECIPES.splitlines() if ',/obj/item/stack/cable_coil/iron,' in line][0]
        self.assertEqual(float(hand_row[3]), 1)
        self.assertLess(time, float(hand_row[4]))

    def test_sprite_sheet_states_and_script(self):
        data = (ROOT / 'icons/obj/wire_bench.dmi').read_bytes()
        at = data.index(b'zTXtDescription\x00\x00') + len(b'zTXtDescription\x00\x00')
        text = zlib.decompressobj().decompress(data[at:]).decode()
        states = {m.group(1): int(m.group(2))
                  for m in re.finditer(r'state = "([^"]+)"\n\tdirs = 1\n\tframes = (\d+)', text)}
        self.assertEqual(states, {'wire_bench': 1, 'wire_bench_on': 4})
        try:
            import PIL  # noqa: F401
        except ImportError:
            self.skipTest('Pillow not installed')
        done = subprocess.run([sys.executable, str(ROOT / 'tests/sprites/create_wire_bench.py'), '--check'],
                              capture_output=True, text=True)
        self.assertEqual(done.returncode, 0, done.stdout + done.stderr)


if __name__ == '__main__':
    unittest.main()
