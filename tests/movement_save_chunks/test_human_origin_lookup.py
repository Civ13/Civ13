"""Source-bound equivalence model for direct-human origin admission.

The model does not execute DM or native savefile operations.
"""
import itertools
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/persistence/loading.dm'


def previous(grid, parent, count, position, z):
    inverse = {ref: (x, y, z) for (x, y), ref in grid.items()}
    if count != 1 or parent not in inverse or position is None:
        return False
    x, y, saved_z, sx, sy = position
    return inverse[parent] == (x, y, saved_z) and bool(sx or sy)


def proposed(grid, parent, count, position, z, width, height):
    refs = set(grid.values())
    if count != 1 or parent not in refs or position is None:
        return False
    x, y, saved_z, sx, sy = position
    if saved_z != z or not 1 <= x <= width or not 1 <= y <= height or not (sx or sy):
        return False
    return grid.get((x, y)) == parent


class OriginLookupContract(unittest.TestCase):
    def test_equivalence_for_unique_validated_grids_and_mismatched_edges(self):
        cells = tuple(itertools.product(range(1, 3), range(1, 3)))
        for permutation in itertools.permutations((1, 2, 3, 4)):
            grid = dict(zip(cells, permutation))
            for parent in (None, 1, 2, 3, 4, 5):
                for count in (0, 1, 2):
                    for x, y, z, sx in itertools.product((0, 1, 2, 3), (0, 1, 2, 3), (1, 2), (0, 3)):
                        pos = (x, y, z, sx, 0)
                        self.assertEqual(previous(grid, parent, count, pos, 1),
                                         proposed(grid, parent, count, pos, 1, 2, 2))
            self.assertFalse(proposed(grid, 1, 1, None, 1, 2, 2))

    def test_source_retains_grid_uniqueness_and_parent_geometry_admission(self):
        source = SOURCE.read_text(encoding='utf-8')
        proc = source.split('/map_storage/proc/validate_world_save()', 1)[1].split('\n/map_storage/', 1)[0]
        self.assertNotIn('human_direct_turfs', proc)
        for required in ('turf_refs["[ref]"]', 'Missing or duplicate turf',
                         'human_direct_parent_counts[human_ref] != 1', '!turf_refs[parent_ref]',
                         'human_candidate_read_position(F, text2num(human_ref))',
                         'position["z"] != z', 'position["x"] < 1', 'position["x"] > world.maxx',
                         'position["y"] < 1', 'position["y"] > world.maxy',
                         '(!position["sx"] && !position["sy"])',
                         'human_candidate_map_ref(F, z, position["y"], position["x"])',
                         'validate_human_saved_geometry(F, text2num(human_ref)'):
            self.assertIn(required, proc)
        self.assertLess(proc.index('Missing or duplicate turf'), proc.index('!turf_refs[parent_ref]'))
        self.assertLess(proc.index('human_candidate_map_ref(F, z,'), proc.index('validate_human_saved_geometry(F,'))


if __name__ == '__main__':
    unittest.main()
