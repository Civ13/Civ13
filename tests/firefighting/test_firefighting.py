"""Offline source contracts for firefighting tools. Gameplay behaviour is
covered by the native probe:
python3 tests/ecology_spawning/run_linux.py . tests/firefighting/probe.dm
"""
from pathlib import Path
import re
import struct
import unittest
import zlib

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/1713/firefighting.dm'
WATER = ROOT / 'code/modules/1713/firefighting_water.dm'
FIRE = ROOT / 'code/modules/1713/oil_fires.dm'
ICON = ROOT / 'icons/obj/firefighting.dmi'


def dmi_states(path):
    data = path.read_bytes()
    pos = 8
    while pos < len(data):
        length, kind = struct.unpack('>I4s', data[pos:pos + 8])
        chunk = data[pos + 8:pos + 8 + length]
        pos += 12 + length
        if kind == b'zTXt' and chunk.startswith(b'Description\0'):
            text = zlib.decompress(chunk[len(b'Description\0') + 1:]).decode('utf-8')
            return dict(re.findall(r'state = "([^"]*)"\n\tdirs = (\d+)', text))
    return {}


class FirefightingSourceTests(unittest.TestCase):
    def setUp(self):
        self.source = SOURCE.read_text(encoding='utf-8')

    def test_included_after_the_code_it_extends(self):
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8').splitlines()
        mine = dme.index('#include "code\\modules\\1713\\firefighting.dm"')
        # The stack overrides chain to the originals with ..().
        for original in ('code\\modules\\1713\\oil_fires.dm',
                         'code\\modules\\materials\\material_sheets.dm',
                         'code\\_onclick\\item_attack.dm'):
            self.assertLess(dme.index('#include "%s"' % original), mine)

    def test_every_icon_state_exists(self):
        states = dmi_states(ICON)
        for base in ('fire_beater', 'fire_flapper'):
            self.assertIn('"%s"' % base, self.source)
            self.assertEqual(states.get(base), '1')
            self.assertEqual(states.get(base + '_wet'), '1')
            for hand in ('_l', '_r'):
                self.assertIn('"%s%s"' % (base, hand), self.source)
                self.assertEqual(states.get(base + hand), '4')

    def test_overrides_fall_through(self):
        for proc in ('/obj/item/weapon/fire_beater/resolve_attackby',
                     '/obj/item/stack/material/pelt/resolve_attackby',
                     '/obj/item/stack/material/leather/resolve_attackby',
                     '/obj/item/stack/material/cloth/resolve_attackby'):
            start = self.source.index('\n' + proc + '(')
            end = self.source.find('\n/', start + 1)
            self.assertIn('return ..()', self.source[start:end], proc)

    def test_recipes_and_knowledge(self):
        recipes = (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8')
        nodes = (ROOT / 'code/modules/research_tree/research_node.dm').read_text(encoding='utf-8')
        for material, path in (('/material/wood/', '/obj/item/weapon/fire_beater'),
                               ('/material/leather/', '/obj/item/weapon/fire_beater/flapper')):
            lines = [line for line in recipes.splitlines()
                     if line.startswith('RECIPE: ') and line.split(',')[2] == path]
            self.assertEqual(len(lines), 1, path)
            fields = lines[0][len('RECIPE: '):].split(',')
            self.assertEqual(len(fields), 13)
            self.assertEqual(fields[0], material)
            self.assertIn('"%s" = "primitive_construction"' % path, nodes)

    def test_cooldown_is_runtime_state(self):
        self.assertIn('var/tmp/next_beat', self.source)
        self.assertIn('return key == "next_beat" || ..()', self.source)

    def test_water_and_blanket_hooks(self):
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8').splitlines()
        mine = dme.index('#include "code\\modules\\1713\\firefighting_water.dm"')
        self.assertLess(dme.index('#include "code\\game\\objects\\structures\\bedsheet_bin.dm"'), mine)
        fire = FIRE.read_text(encoding='utf-8')
        self.assertIn('return douse_fire_with_container(src, W, user)', fire)
        # The old check always passed, whatever the amount of water.
        self.assertNotIn('prob(max(R.volume, 100))', fire)
        water = WATER.read_text(encoding='utf-8')
        start = water.index('\n/obj/item/weapon/bedsheet/resolve_attackby(')
        self.assertIn('return ..()', water[start:water.find('\n#undef', start)])
        self.assertIn('return key == "next_smother" || ..()', water)


if __name__ == '__main__':
    unittest.main()
