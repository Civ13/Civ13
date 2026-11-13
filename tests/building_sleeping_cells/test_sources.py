"""Source contracts for sleeping open-air cells of added building levels.

An added level is nothing but /turf/sky/building cells that skipped their
constructor. The world restore must leave them unlit, a sparse save must take
them as the baseline without comparing fields, and season scans for ground
turfs must not walk a level that is still all open air. Never launches BYOND.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text(encoding='utf-8')


def body(source, header):
    start = source.index(header)
    end = source.find('\n/', start + len(header))
    return source[start:end if end != -1 else len(source)]


class SleepingCellTests(unittest.TestCase):
    def test_asleep_means_unregistered_unlit_open_air(self):
        lighting = read('code/modules/multiz/building_lighting.dm')
        proc = body(lighting, '/proc/building_cell_asleep(turf/T)')
        self.assertIn('istype(T, /turf/sky/building)', proc)
        self.assertIn('!turf_registry_members[T]', proc)
        self.assertIn('!T.lighting_overlay', proc)

    def test_waking_registers_the_cell(self):
        lighting = read('code/modules/multiz/building_lighting.dm')
        wake = body(lighting, '/turf/sky/building/proc/building_wake()')
        self.assertIn('turf_registry_members[src] = TRUE', wake)

    def test_restore_leaves_sleeping_cells_unlit(self):
        zones = read('code/modules/persistence/zone_topology.dm')
        restore = body(zones, '/map_storage/proc/restore_zone_topology()')
        self.assertIn('var/cell_asleep = text2path("/proc/building_cell_asleep")', restore)
        skip = restore.index('if(cell_asleep && A.dynamic_lighting && call(cell_asleep)(T))')
        build = restore.index('T.lighting_build_overlay()')
        # The skip comes after membership and the dirty window flag, before lighting.
        self.assertLess(restore.index('A.contents += T'), skip)
        self.assertLess(restore.index('T.window_coeff_dirty = TRUE'), skip)
        self.assertLess(skip, build)
        self.assertIn('continue', restore[skip:build])
        # An unlit zone still clears overlays for every cell.
        self.assertIn('\t\t\t\telse T.lighting_clear_overlay()\n', restore)

    def test_sparse_save_fast_path_is_building_only_and_checks_the_cell(self):
        saving = read('code/modules/persistence/saving.dm')
        self.assertIn('var/cell_asleep = sparse_kind == "building" ? text2path("/proc/building_cell_asleep") : null', saving)
        line = next(l for l in saving.splitlines() if 'call(cell_asleep)(T)' in l)
        for needed in ('T.type == sparse_turf', 'T.loc == sparse_area', '!T.contents.len',
                       '|| sparse_baseline_cell(T, sparse_turf, sparse_area)'):
            self.assertIn(needed, line)

    def test_season_scan_skips_levels_that_are_all_open_air(self):
        metadata = read('code/game/objects/map_metadata/_map_metadata.dm')
        scan = body(metadata, '/obj/map_metadata/proc/season_world_candidates(')
        self.assertNotIn('for (var/turf/T in world)', scan)
        self.assertIn('text2path("/proc/building_level_only_sky")', scan)
        self.assertIn('if (only_sky && call(only_sky)(z))\n\t\t\t\tcontinue', scan)
        self.assertIn('block(locate(1, 1, z), locate(world.maxx, world.maxy, z))', scan)

    def test_a_replaced_cell_marks_its_level_as_ground(self):
        lighting = read('code/modules/multiz/building_lighting.dm')
        change = body(lighting, '/turf/sky/building/ChangeTurf(')
        self.assertIn('if (!ispath(path, /turf/sky/building))\n\t\tbuilding_levels_with_ground["[z]"] = TRUE', change)
        only_sky = body(lighting, '/proc/building_level_only_sky(z)')
        self.assertIn('building_level_lazy(z)', only_sky)
        self.assertIn('z != practice_room_z', only_sky)
        self.assertIn('!building_levels_with_ground["[z]"]', only_sky)


if __name__ == '__main__':
    unittest.main()
