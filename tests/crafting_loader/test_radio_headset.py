"""Radio headsets are craftable from 2013 and work like portable radios. Source text only.

The headset is a walkie-talkie subtype, so it shares the portable radio frequency,
broadcast and ";" prefix code. It is worn on one ear and needs a worn ears.dmi state.
"""
from pathlib import Path
import re
import sys
import struct
import unittest
import zlib

sys.path.insert(0, str(Path(__file__).resolve().parent))
from test_basic_clothing import ROOT, factionless_recipes, read, research  # noqa: E402

HEADSET = '/obj/item/weapon/radio/walkietalkie/headset'
WALKIE = '/obj/item/weapon/radio/walkietalkie'


def dmi_states(path):
    data = (ROOT / path).read_bytes()
    start = data.index(b'zTXt')
    length = struct.unpack('>I', data[start - 4:start])[0]
    chunk = data[start + 4:start + 4 + length]
    text = zlib.decompress(chunk[chunk.index(b'\0') + 2:]).decode()
    return re.findall(r'state = "([^"]*)"', text)


class RadioHeadset(unittest.TestCase):
    def test_headset_is_an_ear_worn_portable_radio(self):
        source = read('code/modules/1713/radio.dm')
        block = source.split(HEADSET + '\n', 1)[1].split('\n\n', 1)[0]
        self.assertIn('slot_flags = SLOT_EARS', block)
        self.assertIn('icon_state = "radio_headset"', block)
        self.assertIn('icon_override = null', block)
        self.assertIn('/headset/verb/tune_headset()', source)

    def test_worn_and_inventory_sprites_exist(self):
        self.assertIn('radio_headset', dmi_states('icons/mob/ears.dmi'))
        self.assertIn('radio_headset', dmi_states('icons/obj/device.dmi'))

    def test_recipe_wherever_walkie_talkies_are_crafted(self):
        for path in sorted((ROOT / 'config/crafting').glob('material_recipes_*.txt')):
            lines = path.read_text(encoding='utf-8').splitlines()
            has_walkie = any(',' + WALKIE + ',' in line for line in lines)
            headset = [line for line in lines if ',' + HEADSET + ',' in line]
            with self.subTest(file=path.name):
                self.assertEqual(len(headset), 1 if has_walkie else 0)
                if headset:
                    fields = headset[0][len('RECIPE: '):].split(',')
                    self.assertEqual(fields[0], '/material/electronics/')
                    self.assertEqual(fields[11], '8')

    def test_factionless_players_get_it_from_2013_not_before(self):
        nodes, requirements = research()
        self.assertEqual(nodes[requirements[HEADSET]], (8, 'Main'))
        self.assertNotIn(HEADSET, factionless_recipes(7, nodes, requirements))
        self.assertIn(HEADSET, factionless_recipes(8, nodes, requirements))


if __name__ == '__main__':
    unittest.main()
