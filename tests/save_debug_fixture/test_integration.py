"""Source contracts for the recovery and moving-human integration."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


class IntegrationContracts(unittest.TestCase):
    def test_audit_and_human_proofs_precede_completion_marker(self):
        text = (ROOT / 'code/modules/persistence/saving.dm').read_text()
        body = text.split('/map_storage/proc/BuildVarDirectory', 1)[0]
        audit = body.rindex('if(debug_policy) debug_policy.audit(generation, operation)')
        proof = body.rindex('operation.validate_human_spatial_candidates()')
        marker = body.index('text2file(generation,"map_saves/save_complete.txt")')
        self.assertLess(audit, marker)
        self.assertLess(proof, marker)
        self.assertIn('round_state["debug_recovery"] = debug_policy.audit(generation, operation)', body)
        self.assertIn('operation.seal_human_containment_proof()', body)

    def test_manual_selectors_keep_recovery_separate(self):
        text = (ROOT / '.github/workflows/moving-save-chunks.yml').read_text()
        for name in ('lighting-interleave', 'human-spatial', 'human-scale'):
            job = text.split('  ' + name + ':\n', 1)[1]
            self.assertIn('inputs.debug_lossy_only != true', '\n'.join(job.split('\n', 4)[:4]))
        debug = text.split('  debug-lossy:\n', 1)[1]
        for name in ('SPATIAL_ONLY', 'SCALE_ONLY', 'LIGHTING_ONLY'):
            check = 'test "$' + name + '" != true'
            self.assertIn(check, debug)
            self.assertLess(debug.index(check), debug.index('dpkg --add-architecture i386'))


if __name__ == '__main__':
    unittest.main()
