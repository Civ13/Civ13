"""Offline source contracts for wild herbs. Gameplay behaviour is covered by the
native probe: python3 tests/ecology_spawning/run_linux.py . tests/wild_herbs/probe.dm 300
"""
from pathlib import Path
import re
import struct
import unittest
import zlib

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/ecology/wild_herbs.dm'
ICON = ROOT / 'icons/farming/humanity_wild_herbs.dmi'
FOOD_ICON = ROOT / 'icons/obj/food/food.dmi'


def dmi_states(path):
    data = path.read_bytes()
    pos = 8
    while pos < len(data):
        length, kind = struct.unpack('>I4s', data[pos:pos + 8])
        chunk = data[pos + 8:pos + 8 + length]
        pos += 12 + length
        if kind == b'zTXt' and chunk.startswith(b'Description\0'):
            text = zlib.decompress(chunk[len(b'Description\0') + 1:]).decode('utf-8')
            return set(re.findall(r'state = "([^"]*)"', text))
    return set()


class WildHerbSourceTests(unittest.TestCase):
    def setUp(self):
        self.source = SOURCE.read_text(encoding='utf-8')

    def test_included_before_willows(self):
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
        herbs = dme.index('code\\modules\\ecology\\wild_herbs.dm')
        self.assertLess(herbs, dme.index('code\\modules\\ecology\\willow_trees.dm'))

    def test_seed_pass_runs_from_ticker(self):
        ticker = (ROOT / 'code/processes/ticker.dm').read_text(encoding='utf-8')
        self.assertIn('wild_herb_seed_check()', ticker)

    def test_every_icon_state_exists(self):
        used = set(re.findall(r'icon_state = "([^"]*)"', self.source))
        sprigs = {state for state in used if state.endswith('_sprig')}
        self.assertEqual(len(sprigs), 4)
        self.assertLessEqual(used - sprigs, dmi_states(ICON))
        self.assertLessEqual(sprigs, dmi_states(FOOD_ICON))

    def test_no_spawn_and_saved_stock(self):
        self.assertNotIn('spawn(', self.source)
        self.assertIn('. |= "sprigs"', self.source)

    def test_every_tea_reagent_is_defined(self):
        teas = set(re.findall(r'steep_reagent = "([^"]*)"', self.source))
        ids = set(re.findall(r'\tid = "([^"]*)"', self.source))
        self.assertEqual(teas, {'elderflower_tea', 'milk_thistle_tea'})
        self.assertLessEqual(teas, ids)


if __name__ == '__main__':
    unittest.main()
