"""Execute the fixed-dose branches; independent fixtures freeze existing yields."""
import json
from pathlib import Path
import re
import sys
from types import SimpleNamespace as NS
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).parent))
from test_barrel_ingredients import Reagents, path_is

SOURCE = (ROOT / 'code/modules/reagents/reagent_containers/glass.dm').read_text()
ROUTES = json.loads(Path(__file__).with_name('glass-extraction-routes.json').read_text())
BODY = SOURCE.split('/obj/item/weapon/reagent_containers/glass/attackby(', 1)[1].split('\n/proc/barrel_powder_reagent(', 1)[0]
BRANCHES = [m.group() for m in re.finditer(r'\telse if \(istype\(W, [^\n]+\n.*?(?=\n\telse if|\Z)', BODY, re.S)
            if re.search(r'reagents.add_reagent\("[^"]+", \d+\)', m.group())]


def handler():
    """Project the actual fixed-dose chain, retaining every guard and debit."""
    from source_adapter import compile_body
    body = '/proc/fixed_extraction()\n' + '\n'.join(BRANCHES)
    body = body.replace('\telse if (', '\tif (', 1)
    # DM's article expansion is presentation only; Python has no such escape.
    body = body.replace('\\The', 'The')
    return compile_body(body, '/proc/fixed_extraction(', 'self,W,user',
        dict(istype=lambda item, kind: path_is(item.type, kind),
             to_chat=lambda *args: None,
             qdel=lambda item: setattr(item, 'deleted', True)),
        ('reagents', 'is_open_container'))[0]


class GlassExtraction(unittest.TestCase):
    def fixture(self, kind, capacity=60, free=60, opened=True):
        vessel = NS(reagents=Reagents(capacity, water=capacity-free),
                    is_open_container=lambda: opened)
        food = NS(type=kind, deleted=False)
        actor = NS(visible_message=lambda *args: None)
        return vessel, food, actor

    def test_frozen_routes_preserve_every_fixed_food_yield_and_order(self):
        actual = []
        for branch in BRANCHES:
            reagent, dose = re.search(r'add_reagent\("([^"]+)", (\d+)\)', branch).groups()
            actual.append(dict(input=re.search(r'istype\(W, ([^)]+)\)', branch)[1], reagent=reagent, dose=int(dose)))
        self.assertEqual(actual, ROUTES)
        self.assertEqual(len(actual), 15)

    def test_each_whole_yield_fits_exactly_or_with_headroom(self):
        run = handler()
        for row in ROUTES:
            for capacity, free in ((60, row['dose']), (250, row['dose']), (60, 60)):
                with self.subTest(row=row, capacity=capacity, free=free):
                    vessel, food, actor = self.fixture(row['input'], capacity, free)
                    run(vessel, food, actor)
                    self.assertTrue(food.deleted)
                    self.assertEqual(vessel.reagents[row['reagent']], row['dose'])
                    self.assertEqual(vessel.reagents.total_volume, capacity-free+row['dose'])

    def test_partial_room_and_full_vessels_retain_food_and_recipient(self):
        run = handler()
        for row in ROUTES:
            for free in (0, .5, row['dose']-1, row['dose']-.01):
                with self.subTest(row=row, free=free):
                    vessel, food, actor = self.fixture(row['input'], free=free)
                    before = dict(vessel.reagents)
                    run(vessel, food, actor)
                    self.assertFalse(food.deleted)
                    self.assertEqual(dict(vessel.reagents), before)

    def test_closed_vessels_refuse_all_routes_even_with_room(self):
        run = handler()
        for row in ROUTES:
            vessel, food, actor = self.fixture(row['input'], opened=False)
            run(vessel, food, actor)
            self.assertFalse(food.deleted)
            self.assertEqual(vessel.reagents.total_volume, 0)

    def test_actual_holder_capacity_and_ordinary_subtype_still_apply(self):
        run = handler()
        for row in ROUTES:
            vessel, food, actor = self.fixture(row['input'], row['dose']-1, row['dose']-1)
            run(vessel, food, actor)
            self.assertFalse(food.deleted)
            self.assertEqual(vessel.reagents.total_volume, 0)
        row = ROUTES[0]
        vessel, food, actor = self.fixture(row['input'] + '/ordinary_subtype')
        run(vessel, food, actor)
        self.assertTrue(food.deleted)
        self.assertEqual(vessel.reagents[row['reagent']], row['dose'])


if __name__ == '__main__':
    unittest.main()
