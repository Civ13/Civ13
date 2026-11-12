"""Offline source contracts for herb garden crops. Gameplay behaviour is covered
by the native probe: python3 tests/ecology_spawning/run_linux.py . tests/herb_garden/probe.dm 300
"""
from pathlib import Path
import re
import struct
import unittest
import zlib

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/1713/herb_garden.dm'
CROPS = ('chamomile', 'dandelion', 'mint', 'sunflower', 'rose')


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


def blocks(source):
    """Map each type path to its body text."""
    out = {}
    for match in re.finditer(r'(?m)^(/obj/[\w/]+)\n((?:\t.*\n|\n)*)', source):
        out.setdefault(match.group(1), '')
        out[match.group(1)] += match.group(2)
    return out


class HerbGardenSourceTests(unittest.TestCase):
    def setUp(self):
        self.source = SOURCE.read_text(encoding='utf-8')
        self.blocks = blocks(self.source)

    def test_included(self):
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
        self.assertIn('#include "code\\modules\\1713\\herb_garden.dm"', dme)

    def test_crop_sprites(self):
        plants = dmi_states(ROOT / 'icons/farming/plants.dmi')
        seeds = dmi_states(ROOT / 'icons/farming/seeds.dmi')
        for crop in CROPS:
            for stage in [f'-grow{i}' for i in range(1, 7)] + ['-harvest', '-dead']:
                self.assertIn(crop + stage, plants)
            self.assertIn(crop + 'seeds', seeds)

    def test_item_sprites(self):
        food = dmi_states(ROOT / 'icons/obj/food/food.dmi')
        dried = dmi_states(ROOT / 'icons/obj/food/dryed.dmi')
        dryer = dmi_states(ROOT / 'icons/obj/food/dryer.dmi')
        checked = 0
        for path, body in self.blocks.items():
            if '/snacks/grown/' not in path:
                continue
            state = re.search(r'icon_state = "([^"]*)"', body)
            if not state:
                continue
            state = state.group(1)
            icons = dried if "dryed.dmi" in body else food
            self.assertIn(state, icons, path)
            if 'dry_size' in body:
                # The dehydrator draws drying and dried items from dryer.dmi.
                self.assertIn(state, dryer, path)
                if 'dry_size = 2' in body or 'dry_size = 5' in body:
                    self.assertIn(state + 'R', dryer, path)
            checked += 1
        self.assertGreaterEqual(checked, 12)

    def test_every_tea_is_defined(self):
        teas = set(re.findall(r'steep_reagent = "([^"]*)"', self.source))
        ids = set(re.findall(r'\tid = "([^"]*)"', self.source))
        self.assertEqual(teas, {'chamomile_tea', 'mint_tea', 'dandelion_coffee', 'rosehip_tea', 'rose_tea'})
        self.assertLessEqual(teas, ids)

    def test_dried_targets_exist(self):
        for target in re.findall(r'dried_type = (/obj/[\w/]+)', self.source):
            self.assertIn(target, self.blocks)

    def test_grows_wild_and_forageable(self):
        pool = (ROOT / 'code/modules/ecology/flora_regrowth.dm').read_text(encoding='utf-8')
        forage = (ROOT / 'code/modules/ecology/foraging.dm').read_text(encoding='utf-8')
        for crop in CROPS:
            self.assertIn(f'/obj/structure/farming/plant/{crop} =', pool)
            self.assertIn(f'/obj/item/stack/farming/seeds/{crop} =', forage)

    def test_no_spawn(self):
        self.assertNotIn('spawn(', self.source)


if __name__ == '__main__':
    unittest.main()
