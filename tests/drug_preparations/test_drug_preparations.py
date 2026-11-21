"""Offline source contracts for traditional drug preparations. Gameplay is
covered by the native probe:
python3 tests/ecology_spawning/run_linux.py . tests/drug_preparations/probe.dm 300
"""
from pathlib import Path
import re
import struct
import unittest
import zlib

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/1713/drug_preparations.dm'


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


class DrugPreparationSourceTests(unittest.TestCase):
    def setUp(self):
        self.source = SOURCE.read_text(encoding='utf-8')

    def test_included(self):
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
        self.assertIn('#include "code\\modules\\1713\\drug_preparations.dm"', dme)

    def test_sprites(self):
        plants = dmi_states(ROOT / 'icons/farming/plants.dmi')
        self.assertLessEqual({f'khat-grow{i}' for i in range(1, 7)} | {'khat-harvest', 'khat-dead'}, plants)
        drugs = dmi_states(ROOT / 'icons/obj/drugs.dmi')
        self.assertLessEqual({'khat', 'cannabis_fresh', 'cannabis', 'hashish', 'opium_latex', 'cocaine_pile', 'cocaine_line'}, drugs)

    def test_no_instant_opium(self):
        recipes = (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8')
        self.assertNotIn('RECIPE: /material/poppy/,opium,', recipes)
        self.assertIn('RECIPE: /material/cannabis_fresh/,lump of hashish,', recipes)

    def test_mortar_rows(self):
        rows = (ROOT / 'code/modules/1713/processing_recipes.dm').read_text(encoding='utf-8')
        for line in ('/obj/item/stack/material/poppy, "poppy_straw", 3)',
                     '/obj/item/stack/material/coca, "coca_leaf", 3)',
                     '/obj/item/stack/material/cannabis, "thc", 3)'):
            self.assertIn(line, rows)

    def test_reagents_join_their_class(self):
        classes = (ROOT / 'code/modules/reagents/drug_classes.dm').read_text(encoding='utf-8')
        for rid in ('poppy_tea', 'coca_leaf', 'coca_tea', 'khat'):
            self.assertIn(f'"{rid}"', classes)
        for name in ('coca_leaf', 'khat', 'poppy_tea'):
            body = self.source.split(f'/datum/reagent/{name}/affect_blood(', 1)[1].split('\n/', 1)[0]
            self.assertIn('M.drug_dose("', body, name)

    def test_khat_wilts_and_grows_wild(self):
        self.assertRegex(self.source, r'grown/khat\n(?:\t[^\n]*\n)*\tdecay = 60\*600')
        self.assertIn('/obj/item/stack/farming/seeds/khat = list("semiarid", "savanna")',
                      (ROOT / 'code/modules/ecology/foraging.dm').read_text(encoding='utf-8'))
        self.assertIn('/obj/structure/farming/plant/khat = 1,',
                      (ROOT / 'code/modules/ecology/flora_regrowth.dm').read_text(encoding='utf-8'))

    def test_no_spawn_or_sleep(self):
        self.assertNotRegex(self.source, r'\b(spawn|sleep)\(')


if __name__ == '__main__':
    unittest.main()
