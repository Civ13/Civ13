"""Source-only causal controls for the admitted-location witness guards."""
import io
import unittest
from unittest import mock

import test_contract


class WitnessMutationControls(unittest.TestCase):
    def test_removing_either_guard_breaks_the_source_contract(self):
        original = test_contract.read
        policy = original('code/modules/persistence/debug_lossy.dm')
        targets = (
            'if(!quarantine_witness_valid(ref, value)) throw EXCEPTION("Debug omitted animal changed; candidate refused")',
            'if(!quarantine_witness_valid(ref, A)) throw EXCEPTION("Debug omitted animal changed before publication")',
        )
        for target in targets:
            self.assertEqual(policy.count(target), 1)
            changed = policy.replace(target, 'if(FALSE) throw EXCEPTION("synthetic removed guard")', 1)
            def read(path):
                return changed if path == 'code/modules/persistence/debug_lossy.dm' else original(path)
            with self.subTest(target=target), mock.patch.object(test_contract, 'read', side_effect=read):
                suite = unittest.TestSuite([test_contract.DebugLossySourceContracts('test_admitted_location_witness_rechecked_before_omission_and_marker')])
                result = unittest.TextTestRunner(stream=io.StringIO()).run(suite)
                self.assertEqual((len(result.failures), len(result.errors)), (1, 0))


if __name__ == '__main__':
    unittest.main()
