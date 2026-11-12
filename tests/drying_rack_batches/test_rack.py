"""Drying rack batches and salami portions (issues #4907, #4908, #4910)."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/1713/complex_production.dm'
SAUSAGE = '/obj/item/weapon/reagent_containers/food/snacks/sausage/salted'


def proc_body(text, header):
    start = text.index(header + '\n') + len(header) + 1
    lines = []
    for line in text[start:].splitlines():
        if line and not line.startswith('\t'):
            break
        lines.append(line)
    return '\n'.join(lines)


class DryingRackTest(unittest.TestCase):
    def setUp(self):
        self.text = SOURCE.read_text(encoding='utf-8')
        self.attack = proc_body(self.text, '/obj/structure/drying_rack/attackby(var/obj/item/stack/W as obj, var/mob/living/human/H as mob)')

    def test_saved_ham_and_salami_resume_after_load(self):
        body = proc_body(self.text, '/obj/structure/drying_rack/after_load()')
        self.assertIn('producttype == /obj/item/weapon/pigleg', body)
        self.assertIn('producttype == %s' % SAUSAGE, body)
        loop = body.index('for(var/i in 1 to filled)')
        self.assertIn('dry_obj(producttype)', body[loop:])

    def test_sealed_container_is_refused_before_gelatin_is_taken(self):
        sealed = self.attack.index('if(!container.is_open_container())')
        self.assertLess(sealed, self.attack.index('load_gelatin(container)'))
        self.assertEqual(self.attack[sealed:].splitlines()[2].strip(), 'return')
        load = proc_body(self.text, '/obj/structure/drying_rack/proc/load_gelatin(obj/item/weapon/reagent_containers/glass/container)')
        self.assertLess(load.index('!container.is_open_container()'), load.index('remove_reagent(feedstock, 5)'))

    def test_only_undried_sausage_hangs(self):
        self.assertNotIn('istype(W, %s))' % SAUSAGE, self.attack)
        self.assertEqual(self.attack.count('if (is_dryable_sausage(W))'), 2)
        check = proc_body(self.text, '/obj/structure/drying_rack/proc/is_dryable_sausage(obj/item/W)')
        self.assertIn('!istype(W, %s/salami)' % SAUSAGE, check)

    def test_slices_are_not_cut_again(self):
        body = proc_body(self.text, '%s/salami/attackby(var/obj/item/W as obj, var/mob/living/human/user as mob)' % SAUSAGE)
        guard = body.index('istype(src, %s/salami/slice)' % SAUSAGE)
        self.assertLess(guard, body.index('/salami/slice(user.loc)'))
        self.assertTrue(body[guard:].splitlines()[1].strip().startswith('return ..()'))


if __name__ == '__main__':
    unittest.main()
