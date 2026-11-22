"""Source contracts for multi-storey building levels. Never launches BYOND.

Native behaviour (support tiers, foundations, span and column rules, growth
from the highest level) is exercised by tests/building_levels/run.py.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text(encoding='utf-8')


def body(source, header):
    start = source.index(header)
    end = source.find('\n/', start + len(header))
    return source[start:end if end != -1 else len(source)]


class BuildingStoreyTests(unittest.TestCase):
    def test_gaia_opts_into_ten_levels_within_the_ceiling(self):
        gaia = read('code/game/objects/map_metadata/nomads/nomads_gaia.dm')
        self.assertIn('\tbuilding_levels = 10\n', gaia)
        budget = read('code/modules/multiz/world_z_budget.dm')
        self.assertIn('#define NEW_Z_ROOF_CEILING 10\n', budget)
        # Gaia: compiled cave and surface, then ten building levels; its three
        # deeper underground levels are unformed rock and not charged.
        self.assertLessEqual(500 * 350 * (2 + 10), 2100000)
        # A single-level map: ten building levels and four underground levels.
        self.assertIn('#define BUILDING_EXTRA_LEVELS 15\n', read('code/game/objects/building_levels.dm'))

    def test_admission_follows_the_map_cap_and_the_measured_cells(self):
        admission = read('code/modules/multiz/building_admission.dm')
        self.assertIn('#define NEW_Z_BUILDING_MEASURED_CELLS 2100000\n', admission)
        admitted = body(admission, '/datum/world_z_budget/building_admitted(target_z)')
        self.assertIn('target_z > building_base_maxz() + min(map.building_levels, initial(roof_limit))', admitted)
        self.assertIn('<= NEW_Z_BUILDING_MEASURED_CELLS', admitted)
        self.assertIn('underground_added_limit()', admitted)

    def test_a_large_one_level_map_grows_four_levels_over_its_cave(self):
        admission = read('code/modules/multiz/building_admission.dm')
        self.assertIn('#define NEW_Z_STANDING_MEASURED_CELLS 11500000\n', admission)
        self.assertIn('/obj/map_metadata/var/building_levels = 10\n', admission)
        admitted = body(admission, '/datum/world_z_budget/building_admitted(target_z)')
        self.assertIn('if (map.building_level_standing && building_base_maxz() == 1 && !pending && world.maxx * world.maxy * (target_z - caves) <= NEW_Z_STANDING_MEASURED_CELLS)', admitted)
        # The map cap is checked first, so the clause never admits a level a map did not ask for.
        self.assertLess(admitted.index('min(map.building_levels, initial(roof_limit))'), admitted.index('NEW_Z_STANDING_MEASURED_CELLS'))
        # Both Americas: surface, cave and ten open-air planes, the cave not
        # charged; an eleventh would not fit.
        for width, height in ((1132, 920), (848, 1224)):
            self.assertLessEqual(width * height * 11, 11500000)
            self.assertGreater(width * height * 12, 11500000)
        self.assertIn('#define NEW_Z_CELL_CEILING 11500000', read('code/modules/multiz/world_z_budget.dm'))
        americas = read('code/game/objects/map_metadata/nomads/nomads_americas.dm')
        self.assertEqual(americas.count('\tbuilding_levels = 10\n'), 2)
        self.assertEqual(americas.count('\tbuilding_level_standing = TRUE\n'), 2)

    def test_the_smaller_lands_fit_ten_levels_in_the_measured_cells(self):
        # name: (width, height, compiled levels, dig-down cave). Every plane up
        # to the tenth building level, and the cave where there is one, must
        # fit the measured cell count, or roofs would be refused part of the way
        # up. A dig-down land's two full planes must fit Gaia's.
        lands = {'asia': (490, 255, 1, 1), 'europe': (375, 447, 1, 1), 'jungle': (300, 300, 2, 0), 'desert': (225, 225, 2, 0)}
        for name, (width, height, base, cave) in lands.items():
            with self.subTest(name):
                meta = read('code/game/objects/map_metadata/nomads/nomads_%s.dm' % name)
                self.assertEqual(meta.count('\tbuilding_levels = 10\n'), 1)
                self.assertEqual(meta.count('\tbuilding_level_standing = TRUE\n'), 1)
                self.assertEqual(meta.count('\tdig_down_underground = TRUE\n'), cave)
                heights = read('maps/heights/nomads_%s.txt' % name).split('\n')
                self.assertEqual(heights[1], 'size %d %d' % (width, height))
                self.assertEqual(heights[2], 'z %d' % base)
                self.assertLessEqual(width * height * (base + cave + 10), 2100000)
                if cave:
                    self.assertLessEqual(width * height * 2, 350000)

    def test_concrete_walls_carry_six_storeys(self):
        levels = read('code/game/objects/building_levels.dm')
        tier = body(levels, '/obj/covers/cement_wall/building_support_tier()')
        self.assertIn('return 6 + building_brace_tier_bonus(src)', tier)
        self.assertIn('if (!wall || incomplete || health <= 0', tier)
        walls = read('code/game/objects/covers_types/covers_buildable.dm')
        self.assertIn('/obj/covers/cement_wall\n', walls)
        # Six storeys need six levels on every land that is not memory-bound.
        ceiling = re.search(r'#define NEW_Z_ROOF_CEILING (\d+)', read('code/modules/multiz/world_z_budget.dm'))
        self.assertGreaterEqual(int(ceiling.group(1)), 6)

    def test_a_dug_cave_and_building_levels_coexist(self):
        admission = read('code/modules/multiz/building_admission.dm')
        admitted = body(admission, '/datum/world_z_budget/building_admitted(target_z)')
        self.assertIn('var/caves = underground_added_limit()', admitted)
        self.assertIn('target_z > building_base_maxz() + min(map.building_levels, initial(roof_limit)) + caves', admitted)
        self.assertIn('if (caves && !dug_underground_fits())', admitted)
        dug = read('code/modules/multiz/dug_underground.dm')
        # The unformed cave costs about nothing until dug, so any measured surface fits it.
        self.assertIn('#define DUG_UNFORMED_MEASURED_CELLS 1050000\n', dug)
        self.assertIn('return world.maxx * world.maxy <= DUG_UNFORMED_MEASURED_CELLS', dug)
        under = body(dug, '/datum/world_z_budget/underground_admitted(target_z)')
        # Each underground level is dug alone under the deepest one, up to the
        # map's depth; while only unformed rock is added it is always admitted.
        self.assertIn('if (caves.len >= limit)', under)
        self.assertIn('if (charged <= building_base_maxz())\n\t\treturn TRUE', under)
        self.assertIn('/obj/map_metadata/var/underground_depth = 4\n', dug)
        # Levels climb in column order, not z order: the underground is appended.
        self.assertIn('if (z != practice_room_z && !(z in caves))', dug)
        standing = read('code/modules/multiz/standing_building_level.dm')
        self.assertIn('return map && map.building_level_standing && map.building_levels\n', standing)
        self.assertIn('return building_levels_built() > 0', standing)

    def test_a_roof_grows_only_from_the_highest_level(self):
        levels = read('code/game/objects/building_levels.dm')
        grows = body(levels, '/proc/building_grows_from(z)')
        self.assertIn('if (building_upper_z(z))\n\t\treturn FALSE', grows)
        self.assertIn('z == multiz_top_z()', grows)
        self.assertIn('z > building_base_maxz() && !underground_added(z) && building_stack_room(z)', grows)
        construct = body(levels, '/proc/building_construct_roof(')
        self.assertIn('if (building_grows_from(T.z))\n\t\tbuilding_allocate_level(world.maxz + 1)', construct)
        # Support and occupancy are rechecked after the allocation.
        self.assertEqual(construct.count('error = building_roof_error(T)'), 2)

    def test_a_practice_level_on_top_asks_the_builder_to_wait(self):
        levels = read('code/game/objects/building_levels.dm')
        error = body(levels, '/proc/building_roof_error(turf/T)')
        self.assertIn('practice_room_z && T.z + 1 == practice_room_z && building_stack_room(T.z)', error)

    def test_new_roofs_are_checked_for_design_standing_roofs_are_not(self):
        levels = read('code/game/objects/building_levels.dm')
        error = body(levels, '/proc/building_roof_error(turf/T)')
        self.assertIn('building_design_error(T)', error)
        roofs = read('code/game/objects/roof_stuff.dm')
        supported = body(roofs, '/obj/roof/proc/is_supported()')
        self.assertIn('building_supported_height(get_turf(src)) > 0', supported)
        self.assertNotIn('building_design_error', supported)

    def test_support_answers_are_memoised_per_check(self):
        levels = read('code/game/objects/building_levels.dm')
        info = body(levels, '/proc/building_slab_info(turf/T, list/memo, depth = 0)')
        self.assertLess(info.index('var/known = memo[T]'), info.index('for (var/atom/A in range(3, T))'))
        self.assertIn('memo[T] = -1', info)
        self.assertIn('memo[T] = best', info)

    def test_nothing_new_is_saved(self):
        levels = read('code/game/objects/building_levels.dm')
        saved = body(levels, '/obj/roof/get_saved_vars()')
        self.assertIn('"building_pair_id", "building_floor_z", "health", "current_area_type", "switch_area", "seasonal_construction_due"', saved)
        # Slabs carry their pair link only; storeys and strength are derived.
        self.assertIn('/obj/covers\n\tvar/building_pair_id\n\tvar/building_roof_z = 0\n\n', levels)
        self.assertIn('/obj/roof\n\tvar/building_pair_id\n\tvar/building_floor_z = 0\n\n', levels)
        # No type in the file declares a further field.
        self.assertEqual(len(re.findall(r'^/(?:obj|turf|atom)[\w/]*\n\tvar/', levels, flags=re.M)), 2)

    def test_wild_growth_samples_ground_levels_only(self):
        flora = read('code/modules/ecology/flora_regrowth.dm')
        self.assertNotIn('rand(1, world.maxz)', flora)
        self.assertIn('habitat_tiles = round(world.maxx * world.maxy * top * hits / FLORA_HABITAT_SAMPLES)', flora)
        spawning = read('code/modules/ecology/ecology_spawning.dm')
        self.assertNotIn('rand(1, world.maxz)', spawning)
        self.assertIn('for (var/z = 1, z <= multiz_top_z(), z++)', spawning)


if __name__ == '__main__':
    unittest.main()
