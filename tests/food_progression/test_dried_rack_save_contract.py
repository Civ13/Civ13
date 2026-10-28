"""Offline source contract for a dried product's rack save and removal."""
from pathlib import Path
import math
import unittest

ROOT = Path(__file__).resolve().parents[2]
RACK = (ROOT / 'code/modules/1713/production.dm').read_text(encoding='utf-8')
SAVE = (ROOT / 'code/modules/persistence/functions.dm').read_text(encoding='utf-8')
FIXTURE = (ROOT / 'tests/food_progression/preservation.dm').read_text(encoding='utf-8')


def section(source, start, end='\n/obj/'):
    return source.split(start, 1)[1].split(end, 1)[0]


class DriedRackSaveContractTests(unittest.TestCase):
    def test_save_pauses_food_and_preserves_encoded_identity(self):
        put = section(RACK, '/proc/put_in_place(')
        self.assertIn('DECAY_[num2text(D.decay, 8, 10)]', put)
        self.assertIn('D.decay = 0', put)
        before = section(RACK, '/before_save() //before save to map')
        self.assertIn('clean_drop_slots()', before)
        drop = section(RACK, '/proc/clean_drop_slots()')
        self.assertIn('storage.remove_from_storage(slots[R][P])', drop)
        self.assertNotIn('.decay =', drop)
        self.assertNotIn('.name =', drop)
        self.assertIn('src.vars[key] != initial(src.vars[key])', SAVE)
        # A rack-paused zero differs from the dried type's 150000 default.
        self.assertNotEqual(0, 250 * 600)

    def test_fixture_checks_paused_state_then_actual_removal_without_relaxing_age(self):
        salted = FIXTURE.split('/proc/check_salted_meat(', 1)[1].split('\n/proc/', 1)[0]
        saved = salted.index('rack.before_save()')
        write = salted.index('map_storage.BuildVarDirectory(dried_save, product, 1)')
        load = salted.index('map_storage.Load_Entry(dried_save, dried_ref')
        refill = salted.index('rack.refill()', load)
        remove = salted.index('rack.take_product_by_x_y(', refill)
        active = salted.index('restored_dried.decay == 600000', remove)
        self.assertLess(saved, write)
        self.assertLess(write, load)
        self.assertLess(load, refill)
        self.assertLess(refill, remove)
        self.assertLess(remove, active)
        self.assertIn('restored_dried.name == saved_name && restored_dried.decay == 0', salted)
        for field in ('decay', 'decaytimer', 'salted_meat', 'name'):
            self.assertIn(f'("{field}" in dried_fields)', salted)
        self.assertIn('abs(restored_dried.decaytimer - 80000) < 0.01', salted)
        self.assertIn('restored_dried.nutriments_value() == 0', salted)
        self.assertIn('released == restored_dried && released.loc == T', salted)
        remove_proc = section(RACK, '/proc/remove_from_dehydrator(')
        self.assertIn('D.decay = text2num(copytext(S.name, T, T+8))', remove_proc)
        self.assertIn('D.food_decay()', remove_proc)

    def test_fixture_click_coordinates_select_every_rack_slot(self):
        for row in range(1, 5):
            for column in range(1, 4):
                x = 9 + (column - 1) * 5
                y = 4 + (4 - row) * 6
                selected_row = max(1, min(5 - math.ceil((y - 3) / 6), 4))
                selected_column = max(1, min(math.ceil((x - 8) / 5), 3))
                self.assertEqual((selected_row, selected_column), (row, column))


if __name__ == '__main__':
    unittest.main()
