"""#3051 open-water fishing from boats with bait. Offline source contract only."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = 'code/game/objects/structures/ocean_fishing.dm'


def read(path):
    return (ROOT / path).read_text(encoding='utf-8')


def proc(text, header):
    start = text.index(header)
    end = re.search(r'\n(?=[/#])', text[start + len(header):])
    return text[start:] if end is None else text[start:start + len(header) + end.start()]


class OceanFishing(unittest.TestCase):
    def setUp(self):
        self.text = read(SOURCE)
        self.cast = proc(self.text, '/turf/floor/beach/water/deep/saltwater/proc/cast_ocean_line(')

    def test_file_is_compiled(self):
        self.assertIn('#include "code\\game\\objects\\structures\\ocean_fishing.dm"', read('civ13.dme'))

    def test_only_from_a_boat_into_open_deep_saltwater(self):
        hook = proc(self.text, '/turf/floor/beach/water/deep/saltwater/attackby(')
        self.assertIn('!istype(src, /turf/floor/beach/water/deep/saltwater/underwater)', hook)
        self.assertIn('if (!H.on_boat_deck())', self.cast)
        self.assertIn('iscovered()', self.cast)

    def test_driving_a_land_vehicle_does_not_count_as_a_boat(self):
        deck = proc(self.text, '/mob/living/human/proc/on_boat_deck()')
        self.assertNotRegex(deck, r'if \(driver_vehicle\)\s*\n\s*return TRUE')
        self.assertIn('istype(driver_vehicle, /obj/structure/vehicle/boat)', deck)
        self.assertIn('istype(driver_vehicle, /obj/structure/vehicle/raft)', deck)
        self.assertIn('/obj/structure/vehicleparts/frame', deck)
        self.assertIn('/obj/structure/vehicleparts/axis', deck)

    def test_stock_is_rechecked_and_taken_only_after_the_wait(self):
        wait = self.cast.index('do_after(H,')
        self.assertLess(self.cast.index('ocean_fish_available(src) <= 0'), wait)
        take = self.cast.index('if (!ocean_fish_take(src))')
        self.assertGreater(take, wait)
        self.assertLess(take, self.cast.index('new catch_path('))

    def test_stock_is_bounded_and_regrows(self):
        self.assertIn('#define OCEAN_FISH_MAX 3', self.text)
        available = proc(self.text, '/proc/ocean_fish_available(')
        self.assertIn('entry[1] = min(OCEAN_FISH_MAX, entry[1] + regained)', available)
        take = proc(self.text, '/proc/ocean_fish_take(')
        self.assertLess(take.index('ocean_fish_available(T) <= 0'), take.index('entry[1]--'))

    def test_bait_is_loaded_from_raw_meat_or_fish_and_spent_per_cast(self):
        self.assertIn('istype(I, /obj/item/weapon/reagent_containers/food/snacks/meat)', self.text)
        self.assertIn('istype(I, /obj/item/weapon/reagent_containers/food/snacks/rawfish)', self.text)
        load = proc(self.text, '/obj/item/weapon/fishing/attackby(')
        self.assertIn('qdel(W)', load)
        self.assertIn('bait_uses = OCEAN_BAIT_USES', load)
        self.assertLess(self.cast.index('do_after(H,'), self.cast.index('F.bait_uses--'))
        self.assertIn('(baited ? 30 : 0)', self.cast)


if __name__ == '__main__':
    unittest.main()
