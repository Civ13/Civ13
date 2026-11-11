"""Offline source contracts for hay. Gameplay behaviour is covered by the
native probe: python3 tests/ecology_spawning/run_linux.py . tests/hay/probe.dm
"""
from pathlib import Path
import re
import struct
import unittest
import zlib

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/1713/hay.dm'
ICON = ROOT / 'icons/obj/hay.dmi'


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


class HaySourceTests(unittest.TestCase):
    def setUp(self):
        self.source = SOURCE.read_text(encoding='utf-8')

    def test_included_after_animal_code(self):
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8').splitlines()
        hay = dme.index('#include "code\\modules\\1713\\hay.dm"')
        # The simple_animal and floor overrides chain to the originals with ..().
        for original in ('code\\game\\mob\\living\\simple_animal\\simple_animal.dm',
                         'code\\game\\mob\\living\\simple_animal\\simple_ai.dm',
                         'code\\game\\turfs\\floor_attackby.dm'):
            self.assertLess(dme.index('#include "%s"' % original), hay)

    def test_every_icon_state_exists(self):
        states = dmi_states(ICON)
        used = set(re.findall(r'"(drying_grass(?:_half)?|hay_bale(?:_half)?|hay)"', self.source))
        self.assertEqual(used, {'hay', 'drying_grass', 'drying_grass_half', 'hay_bale', 'hay_bale_half'})
        self.assertLessEqual(used, states)

    def test_overrides_fall_through(self):
        for proc in ('/turf/floor/attackby', '/mob/living/simple_animal/attackby',
                     '/mob/living/simple_animal/check_food'):
            start = self.source.index('\n' + proc + '(')
            end = self.source.find('\n/', start + 1)
            self.assertIn('return ..()', self.source[start:end], proc)

    def test_thatch_uses_roofing_knowledge_and_callback_epoch_is_runtime(self):
        self.assertIn('crafting_recipe_allowed(user, "/obj/item/weapon/roofbuilder/leaves")', self.source)
        self.assertIn('var/tmp/drying_epoch', self.source)
        self.assertIn('return key == "drying_epoch" || ..()', self.source)


if __name__ == '__main__':
    unittest.main()
