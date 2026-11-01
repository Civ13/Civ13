"""Source contracts and arithmetic examples only; does not execute DM."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


def overlaps(a, b):
    return not (a[0] >= b[2] or b[0] >= a[2] or a[1] >= b[3] or b[1] >= a[3])


class DirectRestoreSourceTests(unittest.TestCase):
    def test_half_open_example_detects_overhang_but_not_edge_contact(self):
        human = (4, 4, 36, 36)
        self.assertTrue(overlaps(human, (32, 32, 64, 64)))
        self.assertFalse(overlaps(human, (36, 4, 68, 36)))
        self.assertFalse(overlaps(human, (4, 36, 36, 68)))

    def test_schema_is_new_and_historical_branch_keeps_native_move(self):
        saving = (ROOT / 'code/modules/persistence/saving.dm').read_text()
        human = (ROOT / 'code/game/mob/living/carbon/human/subtile_movement.dm').read_text()
        self.assertIn('changing_vars |= list("human_subtile_position", "human_subtile_restore_schema")', saving)
        self.assertIn('value = encode_saved_value(savefile, 1)', saving)
        prepare = human.split('/mob/living/human/proc/human_subtile_prepare_import(', 1)[1].split('\n/mob/', 1)[0]
        self.assertIn('human_subtile_restore_schema = 0', prepare)
        after = human.split('/mob/living/human/after_load()', 1)[1]
        direct = after.split('if(human_subtile_restore_schema == 1)', 1)[1].split('\n\telse\n', 1)[0]
        legacy = after.split('\n\telse\n', 1)[1]
        for forbidden in ('sleep(', '.CanPass(', 'Move('): self.assertNotIn(forbidden, direct)
        self.assertLess(direct.index('human_subtile_restore_hard_clear'), direct.index('step_x = S["sx"]'))
        self.assertIn('human_subtile_same(S, human_subtile_snapshot())', direct)
        self.assertIn('human_subtile_destination_clear(S)', legacy)
        self.assertIn('Move(loc, dir)', legacy)
        self.assertEqual(after.count('living_movement_completed()'), 1)
        self.assertEqual(after.count('human_movement_completed()'), 1)

    def test_preflight_and_final_check_are_owned_and_generation_bound(self):
        functions = (ROOT / 'code/modules/persistence/functions.dm').read_text()
        load = (ROOT / 'code/modules/persistence/loading.dm').read_text()
        backend = functions.split('/map_storage/proc/run_world_operation(', 1)[1].split('\n/map_storage/proc/', 1)[0]
        self.assertLess(backend.index('validate_world_save()'), backend.index('operation.enter_backend'))
        self.assertIn('human_direct_preflight_generation = round_state["generation"]', load)
        self.assertIn('human_direct_preflight_records["[z]:[human_ref]"]', load)
        self.assertIn('human_direct_preflight_records["[loading_z]:[ind]"]', load)
        human = (ROOT / 'code/game/mob/living/carbon/human/subtile_movement.dm').read_text()
        self.assertIn('human_subtile_same(S, human_direct_preflight_position)', human)
        self.assertIn('human_direct_parent_counts[human_ref] != 1', load)
        self.assertIn('build_human_obstruction_index(', load)
        self.assertIn('operation.validate_human_direct_restores()', functions)

    def test_saved_index_scans_anchor_tiles_and_computes_pixel_bounds(self):
        saving = (ROOT / 'code/modules/persistence/saving.dm').read_text()
        index = saving.split('/map_storage/proc/build_human_obstruction_index(', 1)[1].split('\n/map_storage/proc/', 1)[0]
        self.assertIn('for(var/y = 1, y <= world.maxy, y++)', index)
        self.assertIn('for(var/x = 1, x <= world.maxx, x++)', index)
        self.assertIn('shape["step_x"] + shape["bound_x"]', index)
        self.assertIn('shape["step_y"] + shape["bound_y"]', index)
        self.assertIn('if(ispath(path, /mob)) continue', index)
        self.assertIn('Human obstruction index object has duplicate parents', index)
        self.assertIn('Human obstruction index bounds are not finite', index)
        self.assertGreaterEqual(index.count('edge_work % 256 == 0'), 2)


if __name__ == '__main__':
    unittest.main()
