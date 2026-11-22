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
                      '\tif (ishuman(user) && fishing_tool_profile(C))\n\t\tfish_cast(C, user)\n\t\treturn\n'
                      '\t// Salt keeps water and ice open (ice_dynamics.dm).\n'
                      '\tif (ishuman(user) && ice_salt_ok(C))\n\t\tice_salt(src, C, user)\n\t\treturn\n\t..()\n',
                      self.source)
        cast = self.source[self.source.index('/turf/floor/beach/water/proc/fish_cast('):]
        # The stock is asked before the wait and debited after the roll.
        self.assertLess(cast.index('G.available() < 1'), cast.index('do_after('))
        self.assertLess(cast.index('do_after('), cast.index('prob(round(chance))'))
        self.assertLess(cast.index('prob(round(chance))'), cast.index('G.take(1)'))
        self.assertLess(cast.index('G.take(1)'), cast.index('new catch_path('))

    def test_shoals_hold_no_state(self):
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
        self.assertEqual(dme.count('#include "code\\modules\\1713\\fish_shoals.dm"'), 1)
        shoals = (ROOT / 'code/modules/1713/fish_shoals.dm').read_text(encoding='utf-8')
        for banned in ('spawn(', 'addtimer', 'in world', '/obj/', '/datum/'):
            self.assertNotIn(banned, shoals)
        # A shoal's place follows from the time of day alone.
        self.assertIn('/proc/fish_shoal_position(z, index, t)', shoals)
        self.assertIn('world.timeofday', shoals)
        self.assertIn('* fish_shoal_factor(T)', self.source)
        self.assertIn('if (!(shoal && prob(FISH_SHOAL_FREE)) && !G.take(1))', self.source)

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

    def test_ice_holes_fish_the_ground_under_the_ice(self):
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
        self.assertEqual(dme.count('#include "code\\modules\\1713\\ice_fishing.dm"'), 1)
        ice = (ROOT / 'code/modules/1713/ice_fishing.dm').read_text(encoding='utf-8')
        self.assertIn('/turf/floor/beach/water/ice/attackby(obj/item/C as obj, mob/user as mob)\n'
                      '\tif (ishuman(user) && ice_hole_tool_delay(C))\n\t\tice_hole_cut(src, C, user)\n', self.source)
        fish = ice[ice.index('/obj/structure/ice_hole/attackby('):]
        self.assertLess(fish.index('G.available() < 1'), fish.index('do_after('))
        self.assertLess(fish.index('do_after('), fish.index('fish_land('))
        # The hole closes by a saved wall-clock time, and its timer token is not saved.
        self.assertIn('cut_at = trap_minutes_text(trap_now_minutes())', ice)
        self.assertIn('return key == "check_epoch" || key == "cutting" || ..()', ice)
        self.assertTrue((ROOT / 'icons/obj/fishing_gear.dmi').is_file())

    def test_broken_ice_refreezes_and_stops_boats(self):
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
        self.assertEqual(dme.count('#include "code\\modules\\1713\\ice_breaking.dm"'), 1)
        ice = (ROOT / 'code/modules/1713/ice_breaking.dm').read_text(encoding='utf-8')
        # Only broken tiles are watched: nothing walks the world's ice.
        self.assertNotIn('in world', ice)
        self.assertNotIn('spawn(', ice)
        self.assertNotIn('addtimer(CALLBACK(src', ice)
        self.assertEqual(ice.count('addtimer('), 2)
        self.assertIn('var/global/list/broken_ice_marks\n', ice)
        # Harm intent on an ice tile or hole breaks it; a crowbar breaks on any intent.
        fishing = (ROOT / 'code/modules/1713/ice_fishing.dm').read_text(encoding='utf-8')
        self.assertIn('\tif (H.a_intent == I_HARM)\n\t\tice_break(T, W, H)', fishing)
        self.assertIn('user.a_intent == I_HARM && ice_break_tool_delay(W)', fishing)
        self.assertIn('\tif (ishuman(user) && ice_break_tool_delay(C))\n\t\tice_break(src, C, user)\n', self.source)
        # Small boats and rafts ask about ice in the refusal every move check calls first.
        leaks = (ROOT / 'code/modules/naval/small_craft_leaks.dm').read_text(encoding='utf-8')
        self.assertIn('/obj/structure/vehicle/proc/swamped_refusal()\n\tif (!small_craft_ice_ok(small_craft_ahead()))\n\t\treturn TRUE\n', leaks)
        # A built ship plans around ice and breaks the thin ice it was cleared for.
        built = (ROOT / 'code/modules/craft/built_body.dm').read_text(encoding='utf-8')
        self.assertIn('why = ice_refusal(D, mine_set)', built)
        self.assertLess(built.index('break_ice_ahead(P[4], old)'), built.index('var/list/cargo = list()'))
        self.assertIn('/datum/craft_body/built/air/ice_refusal(turf/D, list/mine_set)\n\treturn null', ice)

    def test_ice_forms_and_melts_in_one_batched_sweep(self):
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
        self.assertEqual(dme.count('#include "code\\modules\\1713\\ice_dynamics.dm"'), 1)
        dyn = (ROOT / 'code/modules/1713/ice_dynamics.dm').read_text(encoding='utf-8')
        # One looping timer over the registered water, never a timer per tile
        # or a walk through the world.
        self.assertEqual(dyn.count('addtimer('), 1)
        self.assertIn('TIMER_LOOP | TIMER_STOPPABLE', dyn)
        self.assertNotIn('in world', dyn)
        self.assertNotIn('spawn(', dyn)
        self.assertIn('water_turf_list[ice_front_cursor++]', dyn)
        self.assertIn('/hook/roundstart/proc/ice_front_begin()', dyn)
        # Shared state starts empty: no initialised global lists.
        for name in ('ice_area_temps', 'ice_front_changed', 'ice_kept_open'):
            self.assertIn('var/global/list/%s ' % name, dyn)
        # Salt is offered to both open water and ice.
        self.assertEqual(self.source.count('ice_salt(src, C, user)'), 2)
        # The shared temperatures live in __defines.
        defines = (ROOT / 'code/__defines/fishing.dm').read_text(encoding='utf-8')
        for name in ('ICE_FREEZE_TEMP', 'ICE_MELT_TEMP', 'ICE_SALT_LIMIT', 'ICE_SALT_MINUTES'):
            self.assertIn('#define %s ' % name, defines)

    def test_new_species_are_raw_fish_with_their_own_sheet(self):
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
        self.assertEqual(dme.count('#include "code\\modules\\1713\\fish_species.dm"'), 1)
        species = (ROOT / 'code/modules/1713/fish_species.dm').read_text(encoding='utf-8')
        for name in ('trout', 'catfish', 'herring', 'tuna'):
            self.assertIn('/obj/item/weapon/reagent_containers/food/snacks/rawfish/%s\n' % name, species)
            self.assertIn('icon_state = "%s"' % name, species)
            self.assertIn('rotten_icon_state = "rotten_%s"' % name, species)
            self.assertIn('snacks/rawfish/%s' % name, self.source)
        self.assertTrue((ROOT / 'icons/obj/food/fish_species.dmi').is_file())

    def test_the_trawl_is_industrial_and_only_works_under_way(self):
        research = (ROOT / 'code/modules/research_tree/research_node.dm').read_text(encoding='utf-8')
        self.assertIn('"/obj/item/weapon/fishing/trawl" = "rail_steam",', research)
        recipes = (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8')
        self.assertEqual(recipes.count(',/obj/item/weapon/fishing/trawl,'), 1)
        cast = self.source[self.source.index('/turf/floor/beach/water/proc/fish_cast('):]
        # Under way she goes to fish_troll; standing still the trawl is refused before any wait.
        self.assertLess(cast.index('fish_troll(W, H, ship, profile)'), cast.index('A trawl has to be dragged.'))
        self.assertLess(cast.index('A trawl has to be dragged.'), cast.index('do_after('))
        troll = self.source[self.source.index('/proc/fish_troll('):]
        self.assertLess(troll.index('fish_craft_step(ship) >= VESSEL_SPEED_FULL'), troll.index('do_after('))

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
