"""Liquid fuels are described once.

code/_helpers/liquid_fuels.dm holds a per-fuel table (oil slicks,
bursting when shot), and code/__defines/liquid_fuels.dm holds the
burn-anything engine list. The table values are frozen here
(they replaced hand-written chains with the same numbers), and the old chains
and copied lists may not come back.
"""
from fractions import Fraction
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
TABLE = ROOT / 'code/_helpers/liquid_fuels.dm'
DEFINES = ROOT / 'code/__defines/liquid_fuels.dm'
FROZEN = {
    'petroleum': {'slick': 1, 'explode': 40},
    'gasoline': {'slick': 1, 'explode': 10},
    'diesel': {'slick': Fraction(1, 2), 'explode': 30},
    'biodiesel': {'slick': Fraction(1, 2), 'explode': 30},
    'ethanol': {'explode': 10},
    'olive_oil': {'slick': Fraction(1, 3)},
    'fat_oil': {'slick': Fraction(1, 3)},
}
ANY = 'list("petroleum", "gasoline", "diesel", "pethanol", "biodiesel", "olive_oil", "fat_oil")'
# Reads its own copy from source (tests/water_treatment).
ALLOWED_COPIES = ['code/modules/1713/machinery/engines/heatsource.dm']


def table():
    text = TABLE.read_text(encoding='utf-8')
    rows = {}
    for fuel, body in re.findall(r'^\t"(\w+)" = list\(([^)]*)\),?$', text, re.M):
        rows[fuel] = {k: Fraction(v) for k, v in re.findall(r'"(\w+)" = ([\d/]+)', body)}
    return rows


class LiquidFuelsTest(unittest.TestCase):
    def test_table_values_are_frozen(self):
        self.assertEqual(table(), FROZEN)

    def test_fuel_lists(self):
        text = DEFINES.read_text(encoding='utf-8')
        self.assertIn(f'#define ANY_ENGINE_FUELS {ANY}\n', text)

    def test_callers_use_the_table(self):
        checks = {
            'code/modules/reagents/reagent_containers/glass.dm': 'liquid_fuel_can_explode(reagents)',
            'code/modules/reagents/reagent_containers.dm': 'round(liquid_fuel_slick_units(reagents, spill_amount))',
            'code/modules/1713/machinery/engines/internal_combustion.dm': 'fuels = ANY_ENGINE_FUELS',
        }
        for rel, needle in checks.items():
            self.assertIn(needle, (ROOT / rel).read_text(encoding='utf-8'), rel)

    def test_no_copied_fuel_lists(self):
        found = []
        for path in sorted((ROOT / 'code').rglob('*.dm')):
            if path in (TABLE, DEFINES):
                continue
            text = path.read_text(encoding='utf-8', errors='replace')
            if ANY in text or 'reagents.has_reagent("gasoline",10) || reagents.has_reagent("diesel",30)' in text:
                found.append(path.relative_to(ROOT).as_posix())
        self.assertEqual(found, ALLOWED_COPIES)


if __name__ == '__main__':
    unittest.main()
