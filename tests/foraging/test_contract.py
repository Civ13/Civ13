"""Offline source contracts, not a substitute for executing the DM probe."""
from pathlib import Path
import unittest
ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/modules/ecology/foraging.dm').read_text()

class ForagingContract(unittest.TestCase):
    def test_on_for_persistence_and_opt_in_elsewhere(self):
        self.assertIn('/obj/map_metadata/var/foraging_enabled = FALSE', SOURCE)
        self.assertNotIn('foraging_enabled = TRUE', SOURCE)
        self.assertIn('return foraging_enabled || persistence', SOURCE)
        # Every gate goes through the one availability rule.
        self.assertNotIn('map.foraging_enabled', SOURCE)
        self.assertEqual(SOURCE.count('map.foraging_active()'), 4)
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
        commit = SOURCE.split('/proc/foraging_commit(turf/T, expected_identity, focus = FORAGE_ANY)')[1]
        # The roll happens before the debit but can never skip it: a null roll returns first.
        self.assertLess(commit.index('foraging_roll(T, focus)'), commit.index('C.remaining--'))
        self.assertLess(commit.index('C.remaining--'), commit.index('new output(T, 1)'))
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
    def test_finds_are_existing_safe_items(self):
        finds = SOURCE.split('//////// What the ground can give')[1].split('//////// Search time')[0]
        self.assertNotIn('berries', finds.split('/proc/foraging_focuses()')[1])
        self.assertNotIn('mushroompsy', finds)
        self.assertNotIn('/obj/item/stack/material/iron', finds)
        self.assertIn('season != "WINTER"', finds)
    def test_skill_changes_time_not_amount(self):
        timing = SOURCE.split('/mob/living/human/proc/foraging_search_time(turf/T)')[1].split('/proc/')[0]
        self.assertIn('clamp(getStatCoeff("farming"), 1, 1.5)', timing)
        self.assertIn('clamp(time, 200, 450)', timing)
        self.assertEqual(SOURCE.count('C.remaining--'), 1)
    def test_panel_topic_checks_owner_and_focus(self):
        topic = SOURCE.split('/mob/living/human/Topic(href, href_list)')[1].split('return ..()')[0]
        self.assertIn('usr != src', topic)
        self.assertIn('in foraging_focuses()', topic)
    def test_renewal_is_lazy_and_durable(self):
        self.assertIn('saved |= "renew_from"', SOURCE)
        self.assertIn('return roundduration2text_in_ticks', SOURCE)
        renewal = SOURCE.split('//////// Renewal (phase 5)')[1].split('/proc/foraging_anchor')[0]
        self.assertNotIn('world.time', renewal.split('*/')[-1].split('/proc/foraging_clock()')[1])
        self.assertNotIn('spawn(', SOURCE)
        self.assertNotIn('START_PROCESSING', SOURCE)
        self.assertIn('min(FORAGING_CELL_STOCK', renewal)
        self.assertIn('now < renew_from', renewal)
    def test_source_included(self):
        self.assertIn('code\\modules\\ecology\\foraging.dm', (ROOT/'civ13.dme').read_text())

if __name__ == '__main__':
    unittest.main()
