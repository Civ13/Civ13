"""Meat grinder: one batch, one crank (issue #4878)."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/1713/complex_production.dm'


def proc_body(text, header):
    start = text.index(header + '\n') + len(header) + 1
    lines = []
    for line in text[start:].splitlines():
        if line and not line.startswith('\t'):
            break
        lines.append(line)
    return '\n'.join(lines)


class MeatGrinderCrankTest(unittest.TestCase):
    def setUp(self):
        text = SOURCE.read_text(encoding='utf-8')
        self.crank = proc_body(text, '/obj/structure/meat_grinder/attack_hand(mob/living/human/user as mob)')
        self.load = proc_body(text, '/obj/structure/meat_grinder/attackby(obj/item/weapon/W as obj, mob/user as mob)')

    def test_second_crank_is_refused_while_one_is_running(self):
        guard = self.crank.index('if (cranking)')
        self.assertEqual(self.crank[guard:].splitlines()[2].strip(), 'return')
        claim = self.crank.index('cranking = TRUE')
        wait = self.crank.index('do_after(user, 35)')
        self.assertTrue(guard < claim < wait)

    def test_claim_is_released_after_any_wait_and_output_needs_a_batch(self):
        wait = self.crank.index('do_after(user, 35)')
        release = self.crank.index('cranking = FALSE')
        output = self.crank.index('new /obj/item/weapon/reagent_containers/food/snacks/mince')
        self.assertTrue(wait < release < output)
        self.assertIn('if (cranked && input != null)', self.crank)
        self.assertLess(self.crank.index('input = null'), len(self.crank))

    def test_loaded_batch_is_not_a_deleted_item_reference(self):
        self.assertNotIn('input = W\n', self.load + '\n')
        self.assertEqual(self.load.count('input = "[W.name]"'), 3)


if __name__ == '__main__':
    unittest.main()
