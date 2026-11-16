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

    def test_conditions_scale_the_cast_and_strandings_ride_the_flood_pass(self):
        cast = self.source[self.source.index('/turf/floor/beach/water/proc/fish_cast('):]
        self.assertLess(cast.index('fish_condition_factor_at(src, kind)'), cast.index('prob(round(chance))'))
        self.assertIn('chance = min(95, chance * fish_condition_factor_at(src, kind))', cast)
        flood = (ROOT / 'code/modules/1713/flood_effects.dm').read_text(encoding='utf-8')
        items = flood[flood.index('/proc/flood_items_at('):]
        # After the once-a-tick guard, so a tile is asked at most once a river minute.
        self.assertLess(items.index('flood_items_done[T] = TRUE'), items.index('fish_flood_stranding(T, band)'))

    def test_a_ship_under_way_trolls_and_sonar_reads_the_fish(self):
        cast = self.source[self.source.index('/turf/floor/beach/water/proc/fish_cast('):]
        self.assertLess(cast.index('fish_troll(W, H, ship, profile)'), cast.index('do_after('))
        troll = self.source[self.source.index('/proc/fish_troll('):]
        self.assertLess(troll.index('do_after(H, profile[1], W, can_move = TRUE)'), troll.index('craft_at(get_turf(H)) != ship'))
        self.assertLess(troll.index('craft_at(get_turf(H)) != ship'), troll.index('fish_land('))
        sub = (ROOT / 'code/modules/1713/machinery/modular_vehicles/ships/submarine_systems.dm').read_text(encoding='utf-8')
        self.assertIn('fish_finder_line(periscope_turf())', sub)

    def test_signs_are_client_images_fed_by_the_grounds(self):
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
        self.assertEqual(dme.count('#include "code\\modules\\1713\\fish_signs.dm"'), 1)
        signs = (ROOT / 'code/modules/1713/fish_signs.dm').read_text(encoding='utf-8')
        # Images on the viewer's client, never objects in the world a hull could carry.
        self.assertNotIn('/obj/', signs.replace('/obj/structure/vehicleparts/frame', ''))
        self.assertNotIn('in world', signs)
        self.assertNotIn('spawn(', signs)
        self.assertIn('fishing_ground_at(T, FALSE)', signs)
        self.assertIn('I.mouse_opacity = 0', signs)
        used = set(re.findall(r'"((?:rise|jump)_[a-c]|gulls)"', signs))
        self.assertEqual(used, {'rise_a', 'rise_b', 'rise_c', 'jump_a', 'jump_b', 'gulls'})
        self.assertTrue((ROOT / 'icons/effects/fish_signs.dmi').is_file())
        self.assertTrue((ROOT / 'tests/sprites/create_fishing_signs.py').is_file())
        flood = (ROOT / 'code/modules/1713/flood_effects.dm').read_text(encoding='utf-8')
        self.assertIn('client.fish_signs_refresh()', flood)

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
