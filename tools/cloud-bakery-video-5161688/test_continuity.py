import copy
import unittest
from continuity import validate


class WitnessChecks(unittest.TestCase):
    def setUp(self):
        self.before = dict(phase='before', time=10, flour='flour', bucket='bucket',
                           baker='baker', customer='customer', oven='oven', counter='counter',
                           water_before=5, flour_before=10)
        self.after = dict(phase='after', time=95, flour='flour', bucket='bucket',
                          baker='baker', customer='customer', oven='oven', counter='counter',
                          water_after=0, flour_after=5, mixed_at=20, dough_input='dough',
                          product='flatbread', produced_ref='bread', placed_ref='bread',
                          received_ref='bread', customer_holds_output=1, fuel_paid=1,
                          cook_started=30, produced_at=80, placed_at=85, received_at=95,
                          cooking_time=50)

    def test_valid(self):
        validate(self.before, self.after, 130)

    def test_invalid_evidence_rejected(self):
        mutations = [('flour_after', 10), ('water_after', 1), ('received_ref', 'other bread'),
                     ('customer_holds_output', 0), ('cooking_time', 40), ('produced_at', 79),
                     ('placed_at', 84), ('received_at', 94), ('mixed_at', 19),
                     ('cook_started', 29), ('baker', 'other actor'), ('fuel_paid', 0),
                     ('time', 121), ('dough_input', 'bread')]
        for key, value in mutations:
            with self.subTest(key=key):
                after = copy.deepcopy(self.after)
                after[key] = value
                with self.assertRaises(ValueError):
                    validate(self.before, after, 130)

    def test_end_precedes_action_is_rejected(self):
        with self.assertRaises(ValueError):
            validate(self.before, self.after, 94)


if __name__ == '__main__':
    unittest.main()
