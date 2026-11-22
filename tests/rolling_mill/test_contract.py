"""Source contracts for the rolling mill; this suite does not run DM.

- The mill has a recipe, part inputs and a research node.
- It rolls only the listed stock into products that already exist, and only
  for someone who may craft that product.
- It works only while a prime mover turns it, takes metal only after each
  wait succeeds, and beats the hand recipe on metal for every product.
"""
import json
import re
import subprocess
import sys
import unittest
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/modules/1713/rolling_mill.dm').read_text(encoding='utf-8')
RECIPES = (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8')
NODES = (ROOT / 'code/modules/research_tree/research_node.dm').read_text(encoding='utf-8')
NEEDS = json.loads((ROOT / 'config/craft_needs.json').read_text(encoding='utf-8'))
DME = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
MILL = '/obj/structure/workshop_machine/rolling_mill'


def proc_body(header):
    start = SOURCE.index(header)
    end = SOURCE.find('\n/', start + 1)
    return SOURCE[start:end if end > 0 else len(SOURCE)]


def products():
    table = re.search(r'rolling_mill_products = list\((.*?)\n\)', SOURCE, re.S).group(1)
    return {m.group(1): (m.group(2), int(m.group(3)), m.group(4), int(m.group(5)), int(m.group(6)))
            for m in re.finditer(r'"([^"]+)" = list\(([/\w]+), (\d+), ([/\w]+), (\d+), (\d+)\)', table)}


def hand_row(material, product):
    rows = [line.split(',') for line in RECIPES.splitlines()
            if line.startswith('RECIPE: /material/%s/,' % material) and ',%s,' % product in line]
    return rows[0]


class RollingMill(unittest.TestCase):
    def test_recipe_parts_and_node(self):
        rows = [line.split(',') for line in RECIPES.splitlines() if ',%s,' % MILL in line]
        self.assertEqual(len(rows), 1)
        self.assertEqual((rows[0][0], float(rows[0][3])), ('RECIPE: /material/iron/', 16))
        self.assertIn('"%s" = "rail_steam"' % MILL, NODES)
        self.assertEqual(NEEDS[MILL], {'tools': [], 'inputs': {
            '/obj/item/machine_part/gear': 2, '/obj/item/machine_part/shaft': 2,
            '/obj/item/machine_part/bearing': 2}})
        self.assertIn('#include "code\\modules\\1713\\rolling_mill.dm"', DME)

    def test_products_beat_the_hand_recipes_on_metal(self):
        table = products()
        self.assertEqual(set(table), {'rails from iron', 'rails from steel', 'hull armour plate'})
        for label, material in (('rails from iron', 'iron'), ('rails from steel', 'steel')):
            stock, units, product, out, _ = table[label]
            self.assertEqual((stock, product), ('/obj/item/stack/material/' + material, '/obj/item/stack/rail_lengths'))
            # by hand one unit of iron makes one pair of rails
            hand = hand_row('iron', product)
            self.assertGreater(out / units, 1 / float(hand[3]))
        stock, units, product, out, _ = table['hull armour plate']
        self.assertEqual((stock, product, out), ('/obj/item/stack/material/steel', '/obj/item/hull_plate', 1))
        self.assertLess(units, float(hand_row('steel', product)[3]))
        for _, _, product, _, _ in table.values():
            self.assertIn('"%s" = ' % product, NODES)

    def test_it_needs_a_turning_prime_mover(self):
        self.assertIn('return anchored && isturf(loc) && mechanical_drive_factor(src) < 1',
                      proc_body(MILL + '/proc/rolling('))
        hand = proc_body(MILL + '/attackby(')
        self.assertLess(hand.index('handle_machine_tool(I, H)'), hand.index('takes(I)'))
        self.assertIn('if (!takes(I))\n\t\treturn ..()', hand)
        self.assertLess(hand.index('if (!rolling())'), hand.index('roll_stock(H, I, choice)'))
        self.assertIn('crafting_recipe_allowed(H, "[row[3]]")', proc_body(MILL + '/proc/roll_choices('))

    def test_metal_is_taken_after_each_wait(self):
        work = proc_body(MILL + '/proc/roll_stock(')
        wait = work.index('do_after(H, driven_time(row[5]), src)')
        self.assertLess(wait, work.index('S.use(row[2])'))
        self.assertIn('if (!worker_ready(H, S) || S.amount < row[2] || !rolling() || '
                      '!crafting_recipe_allowed(H, "[product_type]"))\n\t\t\tbreak', work)
        self.assertIn('min(left, pile.max_amount - pile.amount)', work)
        self.assertEqual(work.count('busy = FALSE'), 1)

    def test_sprite_sheet_states_and_script(self):
        data = (ROOT / 'icons/obj/rolling_mill.dmi').read_bytes()
        at = data.index(b'zTXtDescription\x00\x00') + len(b'zTXtDescription\x00\x00')
        text = zlib.decompressobj().decompress(data[at:]).decode()
        states = {m.group(1): int(m.group(2))
                  for m in re.finditer(r'state = "([^"]+)"\n\tdirs = 1\n\tframes = (\d+)', text)}
        self.assertEqual(states, {'rolling_mill': 1, 'rolling_mill_on': 4})
        try:
            import PIL  # noqa: F401
        except ImportError:
            self.skipTest('Pillow not installed')
        done = subprocess.run([sys.executable, str(ROOT / 'tests/sprites/create_rolling_mill.py'), '--check'],
                              capture_output=True, text=True)
        self.assertEqual(done.returncode, 0, done.stdout + done.stderr)

    def test_preset_stacks_count_as_plain_stock(self):
        # #6784; behaviour in tests/rolling_mill/stock_probe.dm (run_linux.py).
        stock = proc_body('/proc/rolling_mill_stock_type(')
        self.assertIn('/obj/item/stack/material/iron/twentyfive', stock)
        self.assertIn('/obj/item/stack/material/steel/twentyfive', stock)
        self.assertNotIn('maraging', stock)
        for header in (MILL + '/proc/roll_choices(', MILL + '/proc/takes(', MILL + '/proc/roll_stock('):
            body = proc_body(header)
            self.assertIn('rolling_mill_stock_type(', body)
            self.assertNotIn('.type == row[1]', body)
            self.assertNotIn('.type != row[1]', body)


if __name__ == '__main__':
    unittest.main()
