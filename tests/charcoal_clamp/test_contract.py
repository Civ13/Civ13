"""Charcoal clamp: source contract checks.

The clamp has one wood recipe row on an era-0 research node, its sprite
states, an Atlas route for charcoal, a capped load, a two-logs-per-lump yield
and a burn that survives a save/load.

    python3 tests/charcoal_clamp/test_contract.py
"""
import json
import re
import unittest
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PATH = '/obj/structure/charcoal_clamp'
SOURCE = (ROOT / 'code/modules/1713/charcoal_clamp.dm').read_text(encoding='utf-8')
RECIPES = (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8')
NODES = (ROOT / 'code/modules/research_tree/research_node.dm').read_text(encoding='utf-8')
DME = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
DMI = ROOT / 'icons/obj/charcoal_clamp.dmi'
ATLAS = json.loads((ROOT / 'scripts/atlas/resource-sources.json').read_text(encoding='utf-8'))
STATES = {'charcoal_clamp': 1, 'charcoal_clamp_loaded': 1, 'charcoal_clamp_on': 4}


def define(name):
    return int(re.search(r'#define %s (\d+)' % name, SOURCE).group(1))


def proc_body(header):
    start = SOURCE.index(header)
    end = SOURCE.find('\n/', start + 1)
    return SOURCE[start:end]


def dmi_states():
    data = DMI.read_bytes()
    at = data.index(b'zTXtDescription\x00\x00') + len(b'zTXtDescription\x00\x00')
    text = zlib.decompressobj().decompress(data[at:]).decode()
    return {m.group(1): int(m.group(2))
            for m in re.finditer(r'state = "([^"]+)"\n\tdirs = 1\n\tframes = (\d+)', text)}


class CharcoalClamp(unittest.TestCase):
    def test_included_once(self):
        self.assertEqual(DME.count('code\\modules\\1713\\charcoal_clamp.dm'), 1)

    def test_one_wood_recipe_on_an_era_zero_node(self):
        rows = [l[len('RECIPE: '):].split(',') for l in RECIPES.splitlines()
                if l.startswith('RECIPE: ') and l.split(',')[2] == PATH]
        self.assertEqual(len(rows), 1)
        row = rows[0]
        self.assertEqual(len(row), 13)
        self.assertEqual((row[0], int(row[3]), row[5]), ('/material/wood/', 4, '1'))
        self.assertIn('"%s" = "primitive_construction"' % PATH, NODES)
        self.assertRegex(NODES, r'register_research_node\(new /datum/research_node\("primitive_construction", "[^"]+", "[^"]+", \d+, 0, RESEARCH_MODE_ANALYSIS, null, 0\)\)')

    def test_sprite_states(self):
        states = dmi_states()
        for state, frames in STATES.items():
            self.assertEqual(states.get(state), frames, state)
        for state in re.findall(r'icon_state = "(charcoal_clamp[\w]*)"', SOURCE):
            self.assertIn(state, STATES)

    def test_yield_and_limits(self):
        self.assertEqual(define('CHARCOAL_CLAMP_LIMIT'), 20)
        self.assertEqual(define('CHARCOAL_CLAMP_LOGS_PER_LUMP'), 2)
        self.assertEqual(define('CHARCOAL_CLAMP_BURN_TIME'), 3000)
        self.assertGreaterEqual(define('CHARCOAL_CLAMP_MIN'), define('CHARCOAL_CLAMP_LOGS_PER_LUMP'))
        load = proc_body('/obj/structure/charcoal_clamp/attackby(')
        self.assertIn('min(S.amount, CHARCOAL_CLAMP_LIMIT - wood_charge)', load)
        self.assertLess(load.index('if (burning)'), load.index('wood_charge += moved'))
        self.assertIn('round(wood_charge / CHARCOAL_CLAMP_LOGS_PER_LUMP)', proc_body('/obj/structure/charcoal_clamp/proc/charcoal_yield('))
        finish = proc_body('/obj/structure/charcoal_clamp/proc/finish_burn(')
        self.assertLess(finish.index('charcoal_yield()'), finish.index('wood_charge = 0'))
        self.assertIn('new(get_turf(src), lumps)', finish)
        self.assertNotIn('C.amount = lumps', finish)

    def test_dig_out_refuses_while_burning_and_returns_logs(self):
        dig = proc_body('/obj/structure/charcoal_clamp/proc/dig_out(')
        self.assertLess(dig.index('if (burning)'), dig.index('do_after'))
        self.assertIn('/obj/item/stack/material/wood/W = new(T, wood_charge)', dig)
        self.assertNotIn('W.amount = wood_charge', dig)

    def test_burn_survives_save_and_load(self):
        self.assertRegex(SOURCE, r'var/burn_left = 0')
        self.assertRegex(SOURCE, r'var/tmp/burn_epoch = 0')
        self.assertIn('key == "burn_epoch"', proc_body('/obj/structure/charcoal_clamp/persistence_runtime_var('))
        load = proc_body('/obj/structure/charcoal_clamp/after_load(')
        self.assertIn('if (burning)', load)
        self.assertIn('start_burn_loop()', load)
        tick = proc_body('/obj/structure/charcoal_clamp/proc/burn_tick(')
        self.assertIn('epoch != burn_epoch', tick)
        self.assertNotIn('world.time', SOURCE)

    def test_atlas_route(self):
        routes = [m for m in ATLAS['mechanisms'] if PATH in m.get('tools', [])]
        self.assertEqual(len(routes), 1)
        self.assertEqual(routes[0]['outputs'], ['/obj/item/stack/ore/charcoal'])
        self.assertEqual(routes[0]['file'], 'code/modules/1713/charcoal_clamp.dm')


if __name__ == '__main__':
    unittest.main()
