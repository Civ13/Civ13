"""Offline safety contracts, not native execution of the DM codec."""
from pathlib import Path
import unittest
ROOT = Path(__file__).resolve().parents[2]
S = (ROOT / 'code/modules/persistence/train_transfer_codec.dm').read_text()

class CodecContracts(unittest.TestCase):
    def test_capture_is_nondestructive_and_validates_before_tagging(self):
        capture = S.split('/proc/train_transfer_capture', 1)[1].split('/proc/train_transfer_decode', 1)[0]
        self.assertNotIn('qdel(', capture)
        self.assertLess(capture.index('if(!train_transfer_decode'), capture.index('for(var/atom/movable/A in cars + loads)'))
        self.assertIn('car in cars || cars.len >= TRAIN_TRANSFER_SEGMENTS', capture)

    def test_bounded_explicit_codecs(self):
        apply = S.split('/proc/train_transfer_apply_structure_state', 1)[1].split('// API result', 1)[0]
        self.assertIn('for(var/key in train_transfer_structure_fields(A.type))', apply)
        self.assertIn('!train_transfer_structure_state_valid(A.type, state)', apply)
        self.assertIn('party_freight_entry_valid(E["payload"])', S)
        self.assertIn('region_travel_decode(E["payload"])', S)
        self.assertIn('length(text) > TRAIN_TRANSFER_TEXT', S)
        self.assertIn('TRAIN_TRANSFER_CRATE_ITEMS', S)
        self.assertNotIn('PARTY_FREIGHT_ITEMS', S)

    def test_build_preflights_geometry_and_handles_partial_delivery(self):
        build = S.split('/proc/train_transfer_build', 1)[1].split('/proc/train_transfer_remove', 1)[0]
        self.assertLess(build.index('if(found_partial) return null'), build.index('new path(T)'))
        self.assertLess(build.index('Validate the complete footprint'), build.index('new path(T)'))
        self.assertIn('for(var/atom/movable/B in built) qdel(B)', build)
        self.assertLess(build.index('A.train_transfer_id'), build.index('head.train_transfer_built = TRUE'))
        self.assertIn('car.automovement = FALSE', build)

    def test_rejects_unpreservable_entities(self):
        self.assertIn('All riders must be healthy, unrestrained and unbuckled', S)
        self.assertIn('cannot travel in a physical train yet', S)
        self.assertIn('C.type != /obj/structure/closet/crate', S)
        self.assertIn('if(accounts.len != owners.len) return null', S)

    def test_removal_is_scoped_to_the_exact_journey(self):
        removal = S.split('/proc/train_transfer_remove', 1)[1]
        self.assertTrue(removal.startswith('(id, journey)'))
        self.assertIn('!train_transfer_string(journey)', removal)
        self.assertIn('A.train_transfer_id == id && A.train_transfer_journey == journey', removal)
        self.assertNotIn('if(A.train_transfer_id == id) qdel(A)', removal)

    def test_build_requires_journey_digest_and_refuses_old_account_bodies(self):
        build = S.split('/proc/train_transfer_build', 1)[1].split('/proc/train_transfer_remove', 1)[0]
        guard = 'existing.train_transfer_journey != M["journey"] || existing.train_transfer_digest != digest'
        self.assertIn(guard, build)
        self.assertLess(build.index(guard), build.index('if(completed_head) return completed_head'))
        self.assertLess(build.index('existing_body.persistence_owner_ckey in M["accounts"]'), build.index('new path(T)'))
        self.assertIn('car.train_transfer_journey = M["journey"]', build)
        self.assertIn('A.train_transfer_digest = digest', build)

    def test_recapture_preserves_preleased_journey_and_rejects_malformed_input(self):
        capture = S.split('/proc/train_transfer_capture', 1)[1].split('/proc/train_transfer_decode', 1)[0]
        self.assertTrue(capture.startswith('(obj/structure/trains/head, party, source, destination, station, journey = null)'))
        guard = 'if(!isnull(journey) && !train_transfer_string(journey))'
        self.assertLess(capture.index(guard), capture.index('head.train_transfer_id ='))
        self.assertIn('if(isnull(journey))\n\t\tjourney = md5(', capture)
        self.assertIn('copytext(journey, i, i + 1)', capture)
        self.assertIn('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.:@-', capture)
        self.assertNotIn('var/journey =', capture)
        self.assertEqual(1, capture.count('journey = md5('))
        self.assertIn('"journey" = journey', capture)
        self.assertIn('A.train_transfer_journey = journey', capture)

    def test_baseline_admission_is_exact_and_preserves_unknown_rejection(self):
        baseline = S.split('/proc/train_transfer_structure_baseline', 1)[1].split('/proc/train_transfer_structure_state(', 1)[0]
        self.assertIn('islist(value) && !length(value)', baseline)
        self.assertIn('isnum(value) && value == 2', baseline)
        self.assertIn('animate_movement = 2', (ROOT / 'code/game/objects/objs.dm').read_text())
        self.assertIn('M.a == 1 && M.b == 0 && M.c == 0 && M.d == 0 && M.e == 1 && M.f == 0', baseline)
        self.assertIn('!length(A.filters)', baseline)
        self.assertIn('B.overlays[i] != expected[i]', baseline)
        self.assertTrue(baseline.rstrip().endswith('return FALSE'))
        self.assertIn('!(key in ignored) && !train_transfer_structure_baseline(A, key)', S)

    def test_capture_marks_the_validated_journey_on_all_roots(self):
        capture = S.split('/proc/train_transfer_capture', 1)[1].split('/proc/train_transfer_decode', 1)[0]
        self.assertIn('"journey" = journey', capture)
        self.assertLess(capture.index('if(!train_transfer_decode'), capture.index('A.train_transfer_journey = journey'))
        self.assertIn('C.train_transfer_built = FALSE', capture)

if __name__ == '__main__':
    unittest.main()
