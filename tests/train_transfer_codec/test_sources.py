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
        self.assertNotIn('.vars[', S)
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

if __name__ == '__main__':
    unittest.main()
