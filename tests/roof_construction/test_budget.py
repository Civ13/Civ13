"""Offline production arithmetic projection, including native float32 divisions."""
from pathlib import Path
import re
import struct
import unittest

from test_roof import CORE, ROOT, RoofProjection, body, project

MODULE = ROOT / 'code/modules/multiz/world_z_budget.dm'


def arithmetic(source=None):
    source = source or MODULE.read_text(encoding='utf-8')
    ceiling = int(re.search(r'#define NEW_Z_CELL_CEILING (\d+)', source)[1])
    # These are the two production divisions, with native precision emulated.
    # Multiplication only occurs after the plane bound; <=1.4m is exact in f32.
    source = source.replace('cell_limit / (width * height)', 'divide(cell_limit, (width * height))')
    source = source.replace('cell_limit / height', 'divide(cell_limit, height)')
    source = source.replace('(purpose == "instance" ? added : 0)',
                            '(added if purpose == "instance" else 0)')
    source = source.replace('(purpose == "safehouse" ? added : 0)',
                            '(added if purpose == "safehouse" else 0)')
    env = dict(NEW_Z_CELL_CEILING=ceiling, NEW_Z_ROOF_CEILING=1,
               BUILDING_MAX_Z=32, BUILDING_EXTRA_LEVELS=8,
               isnum=lambda x: isinstance(x, (int, float)), round=round,
               list=lambda *x: list(x),
               divide=lambda a, b: struct.unpack('f', struct.pack('f', a / b))[0])
    env['new_z_integer'] = project(source, '/proc/new_z_integer(value, maximum)',
                                  'integer', 'value, maximum', env)
    return project(source,
        '/proc/new_z_grid_error(width, height, current_z, base_z, target_z, purpose, cell_limit, roof_limit, instance_reserve, safehouse_reserve, instance_used = 0, safehouse_used = 0)',
        'grid_error', 'width, height, current_z, base_z, target_z, purpose="restore", '
        'cell_limit=1400000, roof_limit=1, instance_reserve=0, safehouse_reserve=0, '
        'instance_used=0, safehouse_used=0', env)


class BudgetTests(unittest.TestCase):
    def test_below_exact_and_single_cell_above_ceiling(self):
        error = arithmetic()
        self.assertIsNone(error(466666, 1, 2, 1, 3))  # 1,399,998
        self.assertIsNone(error(700000, 1, 1, 1, 2, 'roof'))  # 1,400,000
        self.assertIsNotNone(error(466667, 1, 2, 1, 3))  # 1,400,001
        self.assertIsNotNone(error(1400000, 1400000, 1, 1, 2))  # plane before product

    def test_repeated_requests_and_whole_target_charge_existing_planes(self):
        error = arithmetic()
        current = 1
        for target in range(2, 8):
            self.assertIsNone(error(200000, 1, current, 1, target))
            current = target
        self.assertEqual(current * 200000, 1400000)
        self.assertIsNotNone(error(200000, 1, current, 1, current + 1))
        self.assertIsNotNone(error(200000, 1, 1, 1, 8))

    def test_lower_host_budget_reservations_and_other_caps_remain_effective(self):
        error = arithmetic()
        self.assertIsNotNone(error(700000, 1, 1, 1, 2, cell_limit=1399999))
        self.assertIsNotNone(error(700000, 1, 1, 1, 2, instance_reserve=1))
        self.assertIsNotNone(error(10, 10, 1, 1, 3, 'roof'))
        self.assertIsNotNone(error(10, 10, 1, 1, 10))
        self.assertIsNotNone(error(10, 10, 1, 1, 33))
        self.assertIsNotNone(error(10, 10, 1, 1, 2, cell_limit=1400001))
        self.assertIsNotNone(error(10, 10, 1, 1, 2, 'instance'))
        self.assertIsNone(error(700001, 1, 2, 1, 2))  # existing world retained

    def test_production_memory_admission_and_claim_rechecks_remain(self):
        source = MODULE.read_text(encoding='utf-8')
        self.assertIn('return "UNMEASURED:', body(source,
            '/datum/world_z_budget/proc/memory_admission_error(target_z, purpose)'))
        self.assertIn('return memory_admission_error(target_z, purpose)', source)
        self.assertIn('last_error = error(R.target_z, R.purpose, R)', source)
        self.assertIn('var/cell_limit = NEW_Z_CELL_CEILING', source)
        self.assertIn('var/new_z_cell_budget = 1400000',
                      (ROOT / 'code/datums/configuration.dm').read_text(encoding='utf-8'))
        # There is exactly one production native resize; every caller reaches
        # its reservation/claim boundary rather than writing world.maxz itself.
        writers = []
        for path in (ROOT / 'code').rglob('*.dm'):
            if re.search(r'world\.maxz\s*(?:=(?!=)|\+=|\+\+)', path.read_text(encoding='utf-8')):
                writers.append(path.relative_to(ROOT).as_posix())
        self.assertEqual(writers, ['code/game/objects/building_levels.dm'])

    def test_cap_denial_still_allows_roof_only_fallback(self):
        error = arithmetic()
        self.assertIsNotNone(error(466667, 1, 2, 1, 3))
        f = RoofProjection(allocate=False)
        item = f.use_builder()
        self.assertEqual((item.debits, f.world.maxz, f.floor_creations), (1, 1, 0))
        self.assertEqual(len(f.site.roofs), 1)

    def test_negative_controls_for_removed_limit_and_exclusive_boundary(self):
        source = MODULE.read_text(encoding='utf-8')
        self.assertEqual(source.count('if (exceeds_budget)'), 1)
        removed = arithmetic(source.replace('if (exceeds_budget)', 'if (FALSE)'))
        self.assertIsNone(removed(466667, 1, 2, 1, 3), 'removed cap must wrongly accept 1,400,001')
        # Mutate before projection, using the exact production expression.
        marker = 'charged_levels > cell_limit / (width * height)'
        self.assertEqual(source.count(marker), 1)
        exclusive = arithmetic(source.replace(marker, marker.replace(' > ', ' >= ')))
        self.assertIsNotNone(exclusive(700000, 1, 1, 1, 2, 'roof'),
                             'exclusive comparison must wrongly reject exact ceiling')


if __name__ == '__main__':
    unittest.main()
