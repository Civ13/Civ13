"""Offline source contracts for syringe protection and injector appearance."""
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


class THCInjectorAppearance(unittest.TestCase):
    def setUp(self):
        type_path = '/obj/item/weapon/reagent_containers/syringe/thc'
        refresh = SOURCE.split(f'\n{type_path}/update_icon()\n', 1)[1].split('\n/', 1)[0]
        self.filled, self.empty = refresh.split('\n\telse\n', 1)

    def test_filled_injector_uses_its_declared_sprite(self):
        self.assertIn('\tif (reagents.total_volume > 0)\n', self.filled + '\n')
        self.assertIn('\t\ticon_state = initial(icon_state)', self.filled)

    def test_empty_injector_uses_its_matching_spent_sprite(self):
        self.assertIn('\t\ticon_state = "[initial(icon_state)]_empty"\n', self.empty)
        self.assertIn('\t\tused = TRUE\n', self.empty)


if __name__ == '__main__':
    unittest.main()
