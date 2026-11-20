"""Exercise the flour handler's source flow with fake reagent containers."""
from pathlib import Path
from types import SimpleNamespace
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'save_movement'))
import source_adapter

PATH = 'code/modules/reagents/reagent_containers/food/condiment.dm'
PROC = '/obj/item/weapon/reagent_containers/food/condiment/flour/attack_self'
GLASS_PATH = '/obj/item/weapon/reagent_containers/glass'
DOUGH = 'new/obj/item/weapon/reagent_containers/food/snacks/dough(user.loc)'


class Reagents:
    def __init__(self, quantities, label, events):
        self.quantities = dict(quantities)
        self.label = label
        self.events = events

    def has_reagent(self, kind, amount):
        return self.quantities.get(kind, 0) >= amount

    def remove_reagent(self, kind, amount):
        self.events.append((self.label, kind, amount))
        self.quantities[kind] -= amount


class Glass:
    def __init__(self, quantities, label, events):
        self.reagents = Reagents(quantities, label, events)


def run(flours, left=None, right=None, source=None):
    events = []
    src = SimpleNamespace(reagents=Reagents(flours, 'flour', events))
    user = SimpleNamespace(l_hand=Glass(left, 'left', events) if left is not None else None,
                           r_hand=Glass(right, 'right', events) if right is not None else None,
                           loc='floor')
    body = source_adapter.extract(source or source_adapter.read(PATH), PROC)
    # Replace only DM type/constructor syntax at the injected engine boundary.
    body = body.replace('var/obj/item/weapon/reagent_containers/glass/WW', 'var/WW = null')
    body = body.replace('var/flour_reagent\n', 'var/flour_reagent = null\n')
    body = body.replace(GLASS_PATH + ')', 'GLASS_TYPE)')
    body = body.replace(DOUGH, 'make_dough(user.loc)')
    projected_source = PROC + '(mob/user)\n' + body
    env = {'GLASS_TYPE': Glass, 'istype': lambda obj, kind: isinstance(obj, kind),
           'to_chat': lambda actor, message: events.append(('warning', message)),
           'make_dough': lambda loc: events.append(('dough', loc))}
    source_adapter.project(projected_source, PROC, 'src, user', env)(src, user)
    return events


class FlourDough(unittest.TestCase):
    def test_each_flour_debits_water_then_selected_flour_and_creates_one_dough(self):
        for flour in ('flour', 'barleyflour', 'oatflour'):
            with self.subTest(flour=flour):
                self.assertEqual(run({flour: 5}, right={'water': 5}),
                                 [('right', 'water', 5), ('flour', flour, 5), ('dough', 'floor')])

    def test_mixed_flours_preserve_priority_and_left_hand_preference(self):
        self.assertEqual(run({'flour': 5, 'barleyflour': 5, 'oatflour': 5},
                             left={'water': 5}, right={'water': 5}),
                         [('left', 'water', 5), ('flour', 'flour', 5), ('dough', 'floor')])
        self.assertEqual(run({'flour': 4, 'barleyflour': 5, 'oatflour': 5}, right={'water': 5}),
                         [('right', 'water', 5), ('flour', 'barleyflour', 5), ('dough', 'floor')])

    def test_shortages_and_hand_selection_do_not_consume(self):
        cases = (
            (run({'flour': 5}), 'holding water'),
            (run({'flour': 0}, right={'water': 4}), 'more water'),
            (run({'flour': 4}, right={'water': 5}), 'more flour'),
            # The left glass wins even when the right glass has enough water.
            (run({'flour': 5}, left={'water': 4}, right={'water': 5}), 'more water'),
        )
        for events, expected in cases:
            self.assertEqual(len(events), 1)
            self.assertEqual(events[0][0], 'warning')
            self.assertIn(expected, events[0][1])

    def test_negative_control_detects_changed_priority(self):
        source = source_adapter.read(PATH)
        changed = source.replace('if (src.reagents.has_reagent("flour", 5))',
                                 'if (src.reagents.has_reagent("flour", 6))', 1)
        self.assertNotEqual(source, changed)
        self.assertEqual(run({'flour': 5, 'barleyflour': 5}, right={'water': 5}, source=changed)[1],
                         ('flour', 'barleyflour', 5))


if __name__ == '__main__':
    unittest.main()
