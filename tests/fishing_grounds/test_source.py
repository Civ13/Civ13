"""Offline source contracts for fishing grounds.

The native probe beside this file (probe.dm, run through
tests/ecology_spawning/run_linux.py) executes the stock and its regrowth.
These checks only hold the wiring in place: fish are a stock of the water,
no fishing spot object exists anywhere, and every fishing tool goes through
the one cast on the water turf.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/1713/fishing_grounds.dm'
SPOT = re.compile(r'/obj/structure/fish(?![a-z_])')


class FishingGrounds(unittest.TestCase):
    def setUp(self):
        self.source = SOURCE.read_text(encoding='utf-8')

    def test_included_once(self):
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
        self.assertEqual(dme.count('#include "code\\modules\\1713\\fishing_grounds.dm"'), 1)
        self.assertNotIn('ocean_fishing.dm', dme)

    def test_no_fishing_spot_objects_remain(self):
        found = []
        for folder, pattern in (('code', '*.dm'), ('maps', '*.dmm'), ('tools/procedural_maps', '*.py')):
            for path in sorted((ROOT / folder).rglob(pattern)):
                if SPOT.search(path.read_text(encoding='utf-8', errors='replace')):
                    found.append(path.relative_to(ROOT).as_posix())
        self.assertEqual(found, [])

    def test_nothing_ticks(self):
        self.assertNotIn('spawn(', self.source)
        self.assertNotIn('addtimer', self.source)
        self.assertNotIn('in world', self.source)

    def test_one_cast_for_every_tool(self):
        self.assertIn('/turf/floor/beach/water/attackby(obj/item/C as obj, mob/user as mob)\n'
                      '\tif (ishuman(user) && fishing_tool_profile(C))\n\t\tfish_cast(C, user)\n\t\treturn\n\t..()\n',
                      self.source)
        cast = self.source[self.source.index('/turf/floor/beach/water/proc/fish_cast('):]
        # The stock is asked before the wait and debited after the roll.
        self.assertLess(cast.index('G.available() < 1'), cast.index('do_after('))
        self.assertLess(cast.index('do_after('), cast.index('prob(round(chance))'))
        self.assertLess(cast.index('prob(round(chance))'), cast.index('G.take(1)'))
        self.assertLess(cast.index('G.take(1)'), cast.index('new catch_path('))

    def test_set_gear_draws_on_the_ground(self):
        self.assertIn('/proc/fish_ground_trap_catch(turf/T)', self.source)
        traps = (ROOT / 'code/modules/1713/stone_age_traps.dm').read_text(encoding='utf-8')
        weir = traps[traps.index('/obj/structure/stone_age_trap/weir/settle('):]
        self.assertLess(weir.index('prob(chance)'), weir.index('fish_ground_trap_catch(loc)'))
        self.assertLess(weir.index('fish_ground_trap_catch(loc)'), weir.index('fish++'))
        sea = (ROOT / 'code/game/objects/structures/sea.dm').read_text(encoding='utf-8')
        self.assertIn('ispath(picked, /obj/item/weapon/reagent_containers/food/snacks/rawfish) && !fish_ground_trap_catch(T)', sea)

    def test_a_net_takes_no_bait(self):
        bait = self.source[self.source.index('/obj/item/weapon/fishing/attackby('):]
        self.assertLess(bait.index('/obj/item/weapon/fishing/net'), bait.index('bait_uses = FISH_BAIT_USES'))

    def test_spears_ask_the_stone_age_numbers(self):
        arms = (ROOT / 'code/modules/1713/stone_age_arms.dm').read_text(encoding='utf-8')
        self.assertIn('/proc/spear_fishing_delay()\n\treturn SPEAR_FISHING_DELAY\n', arms)
        self.assertIn('/proc/spear_fishing_chance()\n\treturn SPEAR_FISHING_CHANCE\n', arms)
        self.assertIn('list(spear_fishing_delay(), spear_fishing_chance(), TRUE, 1)', self.source)

    def test_world_start_seeds_no_fish(self):
        for path in ('code/modules/1713/roundstart_etc.dm', 'code/game/objects/map_metadata/jungle_colony.dm',
                     'code/game/objects/map_metadata/nomads/nomads_continental.dm',
                     'code/game/objects/map_metadata/nomads/nomads_mediterranean.dm'):
            text = (ROOT / path).read_text(encoding='utf-8')
            self.assertNotIn('nomads_fish_boot', text, path)
            self.assertNotIn('seaturfs', text, path)


if __name__ == '__main__':
    unittest.main()
