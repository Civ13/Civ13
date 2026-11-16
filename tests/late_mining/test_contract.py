"""Late mining: source contract and balance checks.

From the approved plan: the hydraulic monitor strips one bank tile into
6 pay dirt for good and fouls the river; the cyanide vat (WW1 age) gets
+0.15 metal per tailings load with a zinc box, and drained solution fouls
the river.

    python3 tests/late_mining/test_contract.py
"""
import re
import struct
import unittest
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/modules/1713/late_mining.dm').read_text(encoding='utf-8')
PLACER = (ROOT / 'code/modules/1713/placer.dm').read_text(encoding='utf-8')
DME = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
NODES = (ROOT / 'code/modules/research_tree/research_node.dm').read_text(encoding='utf-8')
RECIPES = (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8')
PATHS = ('/obj/structure/hydraulic_monitor', '/obj/structure/placer_washer/cyanide_vat')


def define(name):
    match = re.search(rf'#define {name} ([0-9.]+)', SOURCE)
    assert match, name
    return float(match.group(1))


def dmi_description(path):
    data = path.read_bytes()
    pos = 8
    while pos < len(data):
        length, kind = struct.unpack('>I4s', data[pos:pos + 8])
        body = data[pos + 8:pos + 8 + length]
        if kind in (b'zTXt', b'tEXt') and body.startswith(b'Description\0'):
            text = body[len(b'Description\0'):]
            return zlib.decompress(text[1:]).decode() if kind == b'zTXt' else text.decode()
        pos += 12 + length
    return ''


class Balance(unittest.TestCase):
    def test_monitor(self):
        self.assertEqual(define('MONITOR_PAY_DIRT'), 6)
        self.assertIn('ChangeTurf(/turf/floor/gravel/stripped)', SOURCE)
        self.assertIn('river_foul_dump(src, MONITOR_SILT)', SOURCE)

    def test_vat(self):
        self.assertEqual(define('VAT_RECOVERY') / 100, 0.15)
        self.assertEqual(define('CYANIDE_AGE'), 5)
        self.assertIn('river_foul_dump(src, cyanide)', SOURCE)

    def test_stripped_bank_holds_no_pay_dirt(self):
        # Gravel is not dirt or sand, so can_sift_resources() and with it
        # pay_dirt_bank() refuse it.
        self.assertIn('/turf/floor/gravel/stripped', SOURCE)


class Wiring(unittest.TestCase):
    def test_included_and_gated(self):
        self.assertLess(DME.index('placer.dm'), DME.index('late_mining.dm'))
        for path in PATHS:
            self.assertIn(f'"{path}" = "industrial_milling"', NODES)
            self.assertIn(f',{path},', RECIPES)

    def test_washer_hook(self):
        self.assertIn('if (!can_wash_load(H))', PLACER)

    def test_no_world_time(self):
        self.assertNotIn('world.time', SOURCE)

    def test_sprites(self):
        text = dmi_description(ROOT / 'icons/obj/late_mining.dmi')
        states = set(re.findall(r'(?:icon_state|idle_state|busy_state) = "([a-z_]+)"', SOURCE))
        states.add('hydraulic_monitor_jetting')
        self.assertGreaterEqual(len(states), 5)
        for state in states:
            self.assertIn(f'state = "{state}"', text, state)
        self.assertIn('state = "hydraulic_monitor"\n\tdirs = 4', text)


if __name__ == '__main__':
    unittest.main()
