"""Actual cotton insertion body with inert holders and observable stock payment."""
from pathlib import Path
import sys
from types import SimpleNamespace as NS
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).parent))
from test_barrel_ingredients import Reagents
from source_adapter import compile_body

SOURCE = (ROOT / 'code/modules/reagents/reagent_containers/glass.dm').read_text()
BRANCH = SOURCE.split('\telse if (istype(W, /obj/item/stack/material/cotton))', 1)[1].split('\n\telse if', 1)[0]


def project_cotton():
    body = '/proc/cotton_insertion()\n' + '\n'.join(line[1:] for line in BRANCH.splitlines()[1:])
    body = body.replace('\\The', 'The')
    return compile_body(body, '/proc/cotton_insertion(', 'self,W,user',
        dict(isnum=lambda value: isinstance(value, (float, int)), round=round,
             to_chat=lambda *args: None, qdel=lambda item: setattr(item, 'deleted', True)),
        ('reagents', 'is_open_container'))[0]


class CottonInsertion(unittest.TestCase):
    def fixture(self, amount=25, capacity=60, free=60, opened=True):
        self.vessel = NS(reagents=Reagents(capacity, water=capacity-free), is_open_container=lambda: opened)
        self.actor = NS(visible_message=lambda *args: None)
        self.stock = NS(amount=amount, material=NS(name='cotton'), deleted=False,
                        payments=[], fail_payment=False, fail_admission=False)
        self.stock.can_use = lambda count: not self.stock.fail_admission and self.stock.amount >= count
        def use(count):
            self.stock.payments.append(count)
            if self.stock.fail_payment: return False
            self.stock.amount -= count
            self.stock.deleted = self.stock.amount <= 0
            return True
        self.stock.use = use

    def test_whole_pile_paid_before_same_number_of_reagent_units(self):
        run = project_cotton()
        for amount in (1, 2, 25, 50):
            for capacity, free in ((60, amount), (250, amount), (60, 60)):
                with self.subTest(amount=amount, capacity=capacity, free=free):
                    self.fixture(amount, capacity, free)
                    run(self.vessel, self.stock, self.actor)
                    self.assertEqual(self.stock.payments, [amount])
                    self.assertEqual(self.stock.amount, 0)
                    self.assertTrue(self.stock.deleted)
                    self.assertEqual(self.vessel.reagents['cotton'], amount)
                    self.assertEqual(self.vessel.reagents.total_volume, capacity-free+amount)

    def test_partial_full_closed_and_undersized_holders_keep_both_sides(self):
        run = project_cotton()
        for capacity, free, opened in ((60, .5, True), (60, 24.99, True), (60, 0, True),
                                       (60, 60, False), (10, 10, True)):
            self.fixture(capacity=capacity, free=free, opened=opened)
            before = dict(self.vessel.reagents)
            run(self.vessel, self.stock, self.actor)
            self.assertEqual(self.stock.amount, 25)
            self.assertEqual(self.stock.payments, [])
            self.assertFalse(self.stock.deleted)
            self.assertEqual(dict(self.vessel.reagents), before)

    def test_invalid_amount_material_and_rejected_payment_grant_nothing(self):
        run = project_cotton()
        for change in ('zero', 'negative', 'fraction', 'null', 'text', 'wrong material',
                       'missing material', 'can_use', 'payment'):
            with self.subTest(change=change):
                self.fixture()
                if change == 'zero': self.stock.amount = 0
                if change == 'negative': self.stock.amount = -1
                if change == 'fraction': self.stock.amount = 1.5
                if change == 'null': self.stock.amount = None
                if change == 'text': self.stock.amount = '25'
                if change == 'wrong material': self.stock.material.name = 'steel'
                if change == 'missing material': self.stock.material = None
                if change == 'can_use': self.stock.fail_admission = True
                if change == 'payment': self.stock.fail_payment = True
                amount = self.stock.amount
                run(self.vessel, self.stock, self.actor)
                self.assertEqual(self.stock.amount, amount)
                self.assertFalse(self.stock.deleted)
                self.assertEqual(self.vessel.reagents.total_volume, 0)
                self.assertEqual(self.stock.payments, [25] if change == 'payment' else [])


if __name__ == '__main__':
    unittest.main()
