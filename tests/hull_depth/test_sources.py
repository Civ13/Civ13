"""Offline contracts; the native carrier probe is separate."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
depth = (ROOT / 'code/modules/naval/hull_depth.dm').read_text()
ledger = (ROOT / 'code/modules/naval/hull_ledger.dm').read_text()
layer = (ROOT / 'code/modules/1713/machinery/modular_vehicles/ships/sea_layer.dm').read_text()


class HullDepth(unittest.TestCase):
    def test_only_explicit_adjacent_link_and_real_saltwater(self):
        self.assertIn('target != (rising ? multiz_level_above(z) : multiz_level_below(z))', depth)
        self.assertIn('sea_layer_cell(D) || (rising && sea_layer_open_surface(D))', depth)
        self.assertIn('craft_holding(D)', depth)
        self.assertIn('lower_tile_count()', depth)

    def test_snapshot_validation_before_carry_and_level_commit(self):
        self.assertLess(depth.index('if (other && other != craft)'), depth.index('craft_rigid_begin'))
        self.assertLess(depth.index('craft_step_move(M, D'), depth.index('\n\tz = target\n'))
        self.assertIn('if (QDELETED(M) || M.loc != D)', depth)
        self.assertIn('craft_step_move(M, S', depth)
        self.assertIn('R.building_floor_z = C.z', depth)
        self.assertIn('C.building_roof_z = R.z', depth)

    def test_same_hull_persists_and_requires_repair_to_refloat(self):
        self.assertIn('!holes && fill() < 0.40', depth)
        self.assertIn('persistence_save_active()', depth)
        self.assertNotIn('qdel(', depth)
        self.assertIn('"depth_disabled" = depth_disabled', ledger)
        self.assertIn('depth_disabled = state["depth_disabled"]', ledger)
        sink = ledger.split('/datum/hull_ledger/proc/sink()', 1)[1].split('// ---- The step', 1)[0]
        self.assertNotIn('decommission()', sink)
        self.assertIn('T.crossing_hold_current()', sink)

    def test_a_sunk_deck_is_not_a_submarine_airlock(self):
        self.assertIn('iscovered() && !submerged_built_hull_deck(src)', layer)
        self.assertIn('from.iscovered() && !submerged_built_hull_deck(from)', layer)
        drowning = (ROOT / 'code/game/mob/living/carbon/human/human_helpers.dm').read_text()
        self.assertIn('on_sunken_deck && !free_diving && !seabed_diving_rating()', drowning)
        self.assertIn('if (exposed_seabed && !seabed_diving_rating())', drowning)
        self.assertIn('var/datum/craft/C = craft_holding(T)', depth)
