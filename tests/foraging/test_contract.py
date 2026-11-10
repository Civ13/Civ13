"""Offline source contracts, not a substitute for executing the DM probe."""
from pathlib import Path
import unittest
ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/modules/ecology/foraging.dm').read_text()

class ForagingContract(unittest.TestCase):
    def test_default_off(self):
        self.assertIn('/obj/map_metadata/var/foraging_enabled = FALSE', SOURCE)
        self.assertNotIn('foraging_enabled = TRUE', SOURCE)
    def test_sparse_and_saved(self):
        self.assertIn('saved |= "remaining"', SOURCE)
        self.assertIn('for (var/obj/foraging_cell/C in anchor)', SOURCE)
        self.assertNotIn('in world', SOURCE)
        self.assertNotIn('spawn(', SOURCE)
    def test_save_fence(self):
        for name in ('persistence_save_in_progress', 'persistence_active_operation',
                     'persistence_load_recovery_required', 'persistence_admission_identity'):
            self.assertIn(name, SOURCE)
        self.assertIn('!foraging_persistence_ready(epoch)', SOURCE)
    def test_one_unit_and_no_reroll_preview(self):
        commit = SOURCE.split('/proc/foraging_commit(turf/T, expected_identity)')[1]
        self.assertLess(commit.index('C.remaining--'), commit.index('prob(50)'))
        self.assertIn('new output(T, 1)', commit)
        self.assertNotIn('sleep(', commit)
        self.assertNotIn('input(', commit)
    def test_world_partition_projection(self):
        # Python projection of the DM round/floor expression. NOT native proof.
        anchors = {(1 + 8 * ((x-1)//8), 1 + 8 * ((y-1)//8))
                   for x in range(1, 501) for y in range(1, 351)}
        self.assertEqual(len(anchors), 63 * 44)
        for x in (1, 8, 9, 500):
            anchor = 1 + 8 * ((x-1)//8)
            self.assertLessEqual(anchor, x)
            self.assertLess(x-anchor, 8)
    def test_fixed_record_and_terrain_identity(self):
        for proc in ('/obj/foraging_cell/Move(', '/obj/foraging_cell/forceMove(',
                     '/obj/foraging_cell/persistence_set_loc('):
            self.assertIn(proc, SOURCE)
        self.assertIn('T.sifting_identity != terrain_identity', SOURCE)
    def test_source_included(self):
        self.assertIn('code\\modules\\ecology\\foraging.dm', (ROOT/'civ13.dme').read_text())

if __name__ == '__main__':
    unittest.main()
