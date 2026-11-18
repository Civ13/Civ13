"""Dugout canoe: source contract checks.

    python3 tests/dugout_canoe/test_source.py
"""
import re
import unittest
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/1713/dugout_canoe.dm'
DMI = ROOT / 'icons/obj/vehicles/dugout_canoe.dmi'
STATES = {
    'dugout_log0': 1, 'dugout_log0_charred': 1, 'dugout_log1': 1, 'dugout_log1_charred': 1,
    'dugout_log2': 1, 'dugout_log2_charred': 1, 'dugout': 4, 'paddle': 1,
}
RESEARCH = {'/obj/structure/dugout_log': 'basic_tools', '/obj/item/weapon/paddle': 'basic_tools'}


def dmi_description(path):
    data = path.read_bytes()
    i = data.find(b'zTXtDescription')
    if i > 0:
        length = int.from_bytes(data[i - 4:i], 'big')
        chunk = data[i + 4:i + 4 + length]
        return zlib.decompress(chunk[len(b'Description') + 2:]).decode('latin1')
    i = data.find(b'tEXtDescription')
    length = int.from_bytes(data[i - 4:i], 'big')
    return data[i + 4 + len(b'Description') + 1:i + 4 + length].decode('latin1')


def proc_body(text, header):
    start = text.index(header + '\n')
    rest = text[start + len(header) + 1:]
    end = re.search(r'^\S', rest, re.M)
    return rest[:end.start()] if end else rest


class DugoutSource(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = SOURCE.read_text(encoding='utf-8')

    def test_included(self):
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
        self.assertIn('#include "code\\modules\\1713\\dugout_canoe.dm"', dme)

    def test_sprite_states(self):
        states = {n: int(d) for n, d in re.findall(r'state = "([^"]*)"\s*\n\s*dirs = (\d+)', dmi_description(DMI))}
        self.assertEqual(states, STATES)

    def test_recipes_and_research(self):
        recipes = (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8')
        research = (ROOT / 'code/modules/research_tree/research_node.dm').read_text(encoding='utf-8')
        for material in ('/material/wood/', '/material/wood/soft/'):
            self.assertIn('RECIPE: %s,dugout log,/obj/structure/dugout_log,12,200,1,1,vehicle parts,0,0,0,8,null' % material, recipes)
            self.assertIn('RECIPE: %s,paddle,/obj/item/weapon/paddle,2,40,0,1,vehicle parts,0,0,0,8,null' % material, recipes)
        for path, node in RESEARCH.items():
            self.assertIn('"%s" = "%s",' % (path, node), research)
        self.assertIn('"/obj/structure/vehicle/raft" = "carts",', research)

    def test_raft_subtype_and_sea_rules(self):
        self.assertIn('/obj/structure/vehicle/raft/dugout\n', self.text)
        check = proc_body(self.text, '/obj/structure/vehicle/raft/dugout/do_vehicle_check()')
        self.assertIn('/turf/floor/beach/water/deep', check)
        self.assertIn('weather_wind_at(W) >= rough_wind', check)
        self.assertIn('var/rough_wind = DUGOUT_ROUGH_WIND', self.text)
        self.assertIn('return ..()', check)

    def test_char_before_hollow(self):
        body = proc_body(self.text, '/obj/structure/dugout_log/attackby(obj/item/W, mob/user)')
        self.assertIn('isflamesource(W)', body)
        self.assertIn('Char it with a flame first', body)
        self.assertIn('is_tool(W, TOOL_HATCHET)', proc_body(self.text, '/proc/dugout_hollowing_tool(obj/item/W)'))

    def test_no_forbidden_patterns(self):
        for pattern in ('spawn(', 'input(', ' in world'):
            self.assertNotIn(pattern, self.text)


if __name__ == '__main__':
    unittest.main()
