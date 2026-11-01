"""Tile-only restore contracts; source-level only, not BYOND execution."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]

class TileOnlyRestoreSourceTests(unittest.TestCase):
    def test_new_candidates_omit_movement_but_preserve_art_offsets(self):
        saving = (ROOT / 'code/modules/persistence/saving.dm').read_text()
        human = (ROOT / 'code/game/mob/living/carbon/human/subtile_movement.dm').read_text()
        self.assertIn('changing_vars -= list("step_x", "step_y", "glide_size", "human_subtile_position", "human_subtile_restore_schema")', saving)
        self.assertNotIn('encode_saved_value(savefile, frame.human_spatial_position)', saving)
        runtime = human.split('/mob/living/human/persistence_runtime_var(',1)[1].split('\n/mob/',1)[0]
        self.assertIn('key == "step_x" || key == "step_y"', runtime)
        self.assertNotIn('key == "pixel_x"', runtime)
        self.assertNotIn('key == "pixel_y"', runtime)

    def test_tile_restore_zeroes_offsets_without_mutating_parent_or_active_owner(self):
        human = (ROOT / 'code/game/mob/living/carbon/human/subtile_movement.dm').read_text()
        after = human.split('/mob/living/human/after_load()',1)[1]
        tile = after.split('#ifdef CIV13_HUMAN_SPATIAL_EXPERIMENTAL',1)[1].split('#else',1)[0]
        for required in ('human_subtile_transaction || human_subtile_pulse', 'step_x = 0', 'step_y = 0',
                         'human_subtile_position = null', 'human_subtile_import_owned = FALSE',
                         'living_movement_completed()', 'human_movement_completed()'):
            self.assertIn(required,tile)
        self.assertLess(tile.index('human_subtile_transaction || human_subtile_pulse'),tile.index('step_x = 0'))
        for forbidden in ('loc =', 'forceMove(', 'Move(', 'pixel_x =', 'pixel_y =', 'sleep('):
            self.assertNotIn(forbidden,tile)
        self.assertIn('Move(loc, dir)', after.split('#else',1)[1])

    def test_historical_capsules_still_have_generation_parent_and_shape_checks(self):
        functions = (ROOT / 'code/modules/persistence/functions.dm').read_text()
        load = (ROOT / 'code/modules/persistence/loading.dm').read_text()
        human = (ROOT / 'code/game/mob/living/carbon/human/subtile_movement.dm').read_text()
        backend = functions.split('/map_storage/proc/run_world_operation(',1)[1].split('\n/map_storage/proc/',1)[0]
        self.assertLess(backend.index('validate_world_save()'),backend.index('operation.enter_backend'))
        for required in ('human_direct_preflight_generation = round_state["generation"]',
                         'human_direct_parent_counts[human_ref] != 1', '!turf_refs[parent_ref]',
                         'human_candidate_read_position(F, text2num(human_ref))',
                         'human_candidate_map_ref(F, z, position["y"], position["x"])'):
            self.assertIn(required,load)
        self.assertIn('Malformed sub-tile position capsule',human)
        self.assertNotIn('build_human_obstruction_index(',load)
        self.assertNotIn('human_direct_preflight_records',load)

    def test_saved_tile_checks_do_not_claim_object_clearance(self):
        saving=(ROOT/'code/modules/persistence/saving.dm').read_text()
        body=saving.split('/map_storage/proc/inspect_human_saved_tile_and_links(',1)[1].split('\n/map_storage/proc/',1)[0]
        self.assertIn('Human saved tile is dense',body)
        self.assertIn('Human saved physical link is unsupported',body)
        self.assertNotIn('CanPass(',body)
        self.assertNotIn('build_human_obstruction_index',saving)

    def test_final_local_clearance_runs_after_level_callbacks(self):
        human=(ROOT/'code/game/mob/living/carbon/human/subtile_movement.dm').read_text()
        load=(ROOT/'code/modules/persistence/loading.dm').read_text()
        check=human.split('/mob/living/human/proc/human_saved_tile_final_clear()',1)[1].split('#endif',1)[0]
        self.assertIn('!isturf(loc) || !human_subtile_unlinked() || pulling',check)
        self.assertIn('obounds(src, 0)',check)
        self.assertIn('nearby.len > 1024',check)
        self.assertIn('isobj(A) && isturf(A.loc) && A.density',check)
        self.assertIn('other_turf.density || other_turf.vehicle_transforming',check)
        self.assertNotIn('CanPass(',check)
        self.assertNotIn('Move(',check)
        self.assertNotIn('ismob(',check)
        self.assertLess(load.index('ob.after_load()'),load.index('H.human_saved_tile_final_clear()'))
        self.assertLess(load.index('H.human_saved_tile_final_clear()'),load.index('surface_inventory.feed_loaded_level'))
        self.assertIn('throw EXCEPTION("Restored human tile is obstructed")',load)
        self.assertIn('all_loaded != final_placement_entries || loading_z != B',load)
        placement=load.split('var/list/final_placement_entries = all_loaded',1)[1].split('#endif',1)[0]
        self.assertIn('TICK_CHECK\n\t\t\tif(!operation.current',placement)

if __name__ == '__main__': unittest.main()
