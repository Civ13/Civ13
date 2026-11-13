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
    def test_gaia_opts_into_four_levels_within_the_ceiling(self):
        gaia = read('code/game/objects/map_metadata/nomads/nomads_gaia.dm')
        self.assertIn('\tbuilding_levels = 4\n', gaia)
        budget = read('code/modules/multiz/world_z_budget.dm')
        self.assertIn('#define NEW_Z_ROOF_CEILING 4\n', budget)

    def test_admission_follows_the_map_cap_and_the_measured_cells(self):
        admission = read('code/modules/multiz/building_admission.dm')
        self.assertIn('#define NEW_Z_BUILDING_MEASURED_CELLS 1050000\n', admission)
        admitted = body(admission, '/datum/world_z_budget/building_admitted(target_z)')
        self.assertIn('target_z > building_base_maxz() + min(map.building_levels, NEW_Z_ROOF_CEILING)', admitted)
        self.assertIn('<= NEW_Z_BUILDING_MEASURED_CELLS', admitted)
        self.assertIn('dug_underground_supported()', admitted)

    def test_a_roof_grows_only_from_the_highest_level(self):
        levels = read('code/game/objects/building_levels.dm')
        grows = body(levels, '/proc/building_grows_from(z)')
        self.assertIn('if (building_upper_z(z))\n\t\treturn FALSE', grows)
        self.assertIn('z == multiz_top_z()', grows)
        self.assertIn('z == world.maxz && z > building_base_maxz() && building_stack_room(z)', grows)
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
