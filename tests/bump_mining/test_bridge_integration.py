"""Source regression for independent optional wait contexts."""
from pathlib import Path
import sys
import unittest
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts/gameplay_bridge'))
from gather_context import FEATURE, project

class BridgeMiningIntegration(unittest.TestCase):
    def test_signature_and_rejection_precede_both_claims(self):
        source = project((ROOT / 'code/_helpers/mobs.dm').read_text(), {FEATURE})[0]
        wait = source[source.index('/proc/do_after('):source.index('//Returns a list of all mobs')]
        signature = wait.splitlines()[0]
        self.assertIn('datum/pickaxe_mining_action/mining_context = null, datum/gameplay_action_lease/gameplay_context = null)', signature)
        reject = wait.index('if (!isnull(gameplay_context) && !isnull(mining_context))')
        for claim in ('claim_gather_wait(user, target)', 'mining_context.claim(user, target)', 'user.survival_action_started()'):
            self.assertLess(reject, wait.index(claim))
        self.assertIn('mining_context.progressbar = null', wait)
        self.assertIn('mining_context.wait_started = FALSE', wait)
        self.assertEqual(wait.count('user.survival_action_finished()'), 1)

    def test_enabled_native_checks_cover_independent_ownership(self):
        fixture = Path(__file__).with_name('probe.dm').read_text()
        for label in ('ninth_slot_remains_mining', 'dual_context_denied_before_claims', 'cancelled_mining_releases_only_owned_state'):
            self.assertIn(label, fixture)
