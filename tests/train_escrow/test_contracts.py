"""Source contracts for inactive save-barrier helpers, not runtime evidence."""
from pathlib import Path
import unittest
ROOT = Path(__file__).resolve().parents[2]
S = (ROOT / 'code/modules/persistence/train_escrow.dm').read_text()
class EscrowContracts(unittest.TestCase):
    def test_no_async_capture_or_deletion(self):
        helper = S.split('/obj/structure/region_gate/proc/train_escrow_record_capture')[1]
        for unsafe in ('sleep(', 'request(', 'qdel(', 'send_player'):
            self.assertNotIn(unsafe, helper)
        self.assertIn('train_escrow_records += text', helper)
        self.assertIn('train_escrow_durable -= M["journey"]', helper)
    def test_persisted_receipt_excludes_runtime_cache(self):
        self.assertIn('if(key == "train_escrow_durable") return TRUE', S)
        self.assertIn('/obj/structure/region_gate/after_load()', S)
        bridge = (ROOT / 'code/modules/persistence/transfer_bridge.dm').read_text()
        saved = bridge.split('/datum/transfer_bridge/proc/saved')[1].split('/datum/transfer_bridge/proc/loaded')[0]
        self.assertLess(saved.index('train_escrow_saved()'), saved.index('request("/save"'))
    def test_bad_records_and_account_rejoin_fail_closed(self):
        self.assertIn('if(train_escrow_hold_reason) return TRUE', S)
        self.assertIn('train_escrow_account_held(C.ckey)', (ROOT / 'code/modules/persistence/region_home.dm').read_text())
    def test_coordinate_elements_are_not_silently_skipped(self):
        self.assertIn('for(var/entry in R["centres"])', S)
        self.assertIn('if(!islist(entry)) return null', S)
    def test_malformed_container_is_not_empty_escrow(self):
        validator = S.split('/obj/structure/region_gate/proc/train_escrow_container_valid()')[1].split('/proc/train_escrow_saved()')[0]
        self.assertIn('islist(train_escrow_records)', validator)
        self.assertIn('train_escrow_records.len <= TRAIN_ESCROW_LIMIT', validator)
        self.assertIn('train_escrow_hold_reason =', validator)
        saved = S.split('/proc/train_escrow_saved()')[1].split('/proc/train_escrow_account_held')[0]
        held = S.split('/proc/train_escrow_account_held')[1].split('// A caller')[0]
        self.assertLess(saved.index('train_escrow_container_valid()'), saved.index('for(var/text'))
        self.assertLess(held.index('train_escrow_container_valid()'), held.index('for(var/text'))
        self.assertIn('if(!S.train_escrow_container_valid()) return TRUE', held)
        capture = S.split('/obj/structure/region_gate/proc/train_escrow_record_capture')[1]
        self.assertIn('train_escrow_hold_reason || QDELETED(src)', capture)
        self.assertIn('if(!train_escrow_container_valid()', capture)
    def test_source_stage_stays_gated(self):
        self.assertIn('Whole-train staging awaits the accepted body codec', S)
        self.assertNotIn('begin_escrow(', S)
if __name__ == '__main__': unittest.main()
