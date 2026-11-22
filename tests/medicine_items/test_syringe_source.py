"""Offline source contract for syringe injection protection (#6201).

Behaviour is covered natively by tests/medicine_items/probe.dm.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/modules/reagents/reagent_containers/syringe.dm').read_text(encoding='utf-8-sig')


class SyringeProtection(unittest.TestCase):
    def test_human_check_runs_without_a_suit(self):
        inject = SOURCE.split('if (SYRINGE_INJECT)', 1)[1]
        self.assertIn('H.can_inject(user, TRUE, tgt)', inject)
        self.assertNotIn('if (H.wear_suit)', inject)

    def test_check_uses_the_resolved_target_before_the_wait(self):
        inject = SOURCE.split('if (SYRINGE_INJECT)', 1)[1]
        self.assertLess(inject.index('tgt = pick('), inject.index('H.can_inject(user, TRUE, tgt)'))
        self.assertLess(inject.index('H.can_inject(user, TRUE, tgt)'), inject.index('do_after(user, injtime, target)'))


if __name__ == '__main__':
    unittest.main()
