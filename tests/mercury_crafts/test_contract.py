"""Mercury crafts: source contract and balance checks.

Numbers from the approved plan: gilding +6 burden roofed (halved outdoors),
mirror 1 tin + 5u, barometer 5u, thermometer 2u, carroting 2u per pelt for
2 felt (+0.5), felt hats take 2 felt, dimercaprol draws out 30 per 5u dose.

    python3 tests/mercury_crafts/test_contract.py
"""
import re
import struct
import unittest
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/modules/1713/mercury_crafts.dm').read_text(encoding='utf-8')
MIRROR = (ROOT / 'code/game/objects/structures/mirror.dm').read_text(encoding='utf-8')
FORECAST = (ROOT / 'code/modules/1713/weather_forecast.dm').read_text(encoding='utf-8')
DME = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
NODES = (ROOT / 'code/modules/research_tree/research_node.dm').read_text(encoding='utf-8')
RECIPES = ROOT / 'config/crafting'
GLOBAL = (RECIPES / 'material_recipes_global.txt').read_text(encoding='utf-8')


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
    def test_amounts(self):
        self.assertEqual(define('GILDING_VAPOUR'), 6)
        self.assertEqual(define('MIRROR_TIN'), 1)
        self.assertEqual(define('MIRROR_MERCURY'), 5)
        self.assertEqual(define('BAROMETER_MERCURY'), 5)
        self.assertEqual(define('THERMOMETER_MERCURY'), 2)
        self.assertEqual(define('CARROT_MERCURY'), 2)
        self.assertEqual(define('CARROT_FELT'), 2)
        self.assertEqual(define('CARROT_VAPOUR'), 0.5)
        self.assertEqual(define('FELT_PER_HAT'), 2)
        self.assertEqual(define('DIMERCAPROL_PER_UNIT') * 5, 30)

    def test_every_craft_poisons(self):
        for cause in ('the fumes of fire gilding', 'silvering a mirror', 'carroting felt'):
            self.assertIn(cause, SOURCE)

    def test_dimercaprol_is_modern(self):
        self.assertIn('map.ordinal_age < 7', SOURCE)


class Wiring(unittest.TestCase):
    def test_included_after_forecast(self):
        self.assertLess(DME.index('weather_forecast.dm'), DME.index('mercury_crafts.dm'))

    def test_every_crafted_mirror_starts_bare(self):
        for path in RECIPES.glob('material_recipes_*.txt'):
            text = path.read_text(encoding='utf-8')
            self.assertNotIn(',/obj/structure/mirror,', text, path.name)
        self.assertIn(',/obj/structure/mirror/unsilvered,', GLOBAL)
        self.assertIn('new item_type(loc)', MIRROR)
        self.assertIn('new structure_type(user.loc)', MIRROR)

    def test_instruments_start_empty(self):
        self.assertIn(',/obj/item/weapon/barometer/empty,', GLOBAL)
        self.assertIn(',/obj/item/weapon/thermometer/empty,', GLOBAL)
        self.assertIn('"/obj/item/weapon/thermometer/empty" = "optics_instruments"', NODES)
        self.assertIn('"/obj/structure/mirror/unsilvered" = "sanitation"', NODES)

    def test_barometer_is_a_column(self):
        reading = FORECAST[FORECAST.index('/proc/barometer_reading'):FORECAST.index('/obj/item/weapon/barometer/attack_self')]
        self.assertNotIn('needle', reading)
        self.assertIn('quicksilver', FORECAST)

    def test_felt_hats_keep_rain_off(self):
        self.assertEqual(SOURCE.count('rain_resist = 30'), 3)

    def test_no_world_time(self):
        self.assertNotIn('world.time', SOURCE)

    def test_sprites(self):
        items = dmi_description(ROOT / 'icons/obj/mercury_crafts.dmi')
        for state in set(re.findall(r'icon_state = "([a-z_]+)"', SOURCE)):
            self.assertIn(f'state = "{state}"', items, state)
        worn = dmi_description(ROOT / 'icons/mob/mercury_crafts.dmi')
        for state in re.findall(r'slot_head_str = "([a-z_]+)"', SOURCE):
            self.assertIn(f'state = "{state}"\n\tdirs = 4', worn, state)


if __name__ == '__main__':
    unittest.main()
