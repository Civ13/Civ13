"""Offline checks for gem science uses (code/modules/1713/gem_science.dm)."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/1713/gem_science.dm'
STATES = ('jewel_bearing', 'jewel_bearing_garnet', 'diamond_grit', 'diamond_drill_bit', 'lapping_wheel',
          'quartz_uncut', 'quartz', 'galena', 'crystal_radio', 'quartz_crystal_unit', 'quartz_watch',
          'emery_powder', 'garnet_paper', 'rock_crystal_lens', 'jewel_lens', 'ruby_boule', 'ruby_rod',
          'loupe', 'gem_scale', 'refractometer')


def dmi_states(path):
    from PIL import Image
    return re.findall(r'state = "([^"]+)"', Image.open(path).info['Description'])


class GemScienceTest(unittest.TestCase):
    def setUp(self):
        self.text = SOURCE.read_text(encoding='utf-8')

    def test_used_states_exist(self):
        states = dmi_states(ROOT / 'icons/obj/gem_science.dmi')
        self.assertEqual(tuple(states), STATES)
        for used in re.findall(r'\ticon_state = "([^"]+)"', self.text):
            self.assertIn(used, states)

    def test_jewel_bearings(self):
        # Ruby and sapphire give four jewels, garnet two cheaper ones.
        for stone, kind, count in (('ruby', '/obj/item/stack/jewel_bearing', 4),
                                   ('sapphire', '/obj/item/stack/jewel_bearing', 4),
                                   ('garnet', '/obj/item/stack/jewel_bearing/garnet', 2)):
            self.assertRegex(self.text, rf'/obj/item/stack/gemstone/{stone}\n\tbearing_type = {re.escape(kind)}\n\tbearing_yield = {count}')
        self.assertIn('crafting_node_allowed_or_warn(H, "optics_instruments")', self.text)
        for target in ('/obj/item/weapon/watch/pocket/attackby', '/obj/item/clothing/gloves/watch/attackby',
                       '/obj/item/weapon/compass/attackby'):
            self.assertIn(target, self.text)
        self.assertIn('C.max_offset = min(C.max_offset, 2)', self.text)

    def test_watches_read_through_watch_reading(self):
        for path in ('code/modules/1713/apparel_industrial.dm', 'code/game/objects/items/clothing/gloves/color.dm'):
            text = (ROOT / path).read_text(encoding='utf-8')
            self.assertIn('watch_reading(src)', text)
            self.assertNotIn('It is now [clock_time()]', text)
        self.assertIn('min = round(min / 15) * 15', self.text)

    def test_included_after_lanyards(self):
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
        self.assertLess(dme.index('lanyards.dm'), dme.index('gem_science.dm'))


if __name__ == '__main__':
    unittest.main()
