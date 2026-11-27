"""Water turf questions go through code/_helpers/water_turfs.dm.

Frozen water is still a /turf/floor/beach/water, so "is this liquid water"
needs the ice exclusion every time, and boats also float on flooded trenches.
Callers spelled these out by hand and disagreed (some boat checks let ice
count as water). The helpers answer once; hand-written copies may not return.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
HELPER = ROOT / 'code/_helpers/water_turfs.dm'
W = r'/turf/floor/beach/water'
COPIES = [
    re.compile(r'istype\((\w+(?:\.\w+)?), ?' + W + r'\) && !istype\(\1, ?' + W + r'/ice\)'),
    re.compile(r'!istype\((\w+(?:\.\w+)?), ?' + W + r'\) \|\| istype\(\1, ?' + W + r'/ice\)'),
    re.compile(r'istype\((\w+), ?' + W + r'/deep/saltwater\) && !istype\(\1, ?' + W + r'/deep/saltwater/underwater\)'),
]
ALLOWED = {}


class WaterTurfsTest(unittest.TestCase):
    def test_helpers(self):
        text = HELPER.read_text(encoding='utf-8')
        self.assertIn('/proc/is_liquid_water(turf/T)\n\treturn istype(T, /turf/floor/beach/water) '
                      '&& !istype(T, /turf/floor/beach/water/ice)\n', text)
        self.assertIn('/proc/is_open_water(turf/T)\n\treturn is_liquid_water(T) '
                      '|| istype(T, /turf/floor/trench/flooded)\n', text)
        self.assertIn('/proc/is_open_sea(turf/T)\n', text)
        self.assertIn('#include "code\\_helpers\\water_turfs.dm"', (ROOT / 'civ13.dme').read_text(encoding='utf-8'))

    def test_no_hand_written_copies(self):
        found = {}
        for path in sorted((ROOT / 'code').rglob('*.dm')):
            if path == HELPER:
                continue
            text = path.read_text(encoding='utf-8', errors='replace')
            n = sum(len(p.findall(text)) for p in COPIES)
            if n:
                found[path.relative_to(ROOT).as_posix()] = n
        self.assertEqual(found, ALLOWED)

    def test_life_extinguishes_only_on_uncovered_liquid_turf(self):
        text = (ROOT / 'code/game/mob/living/life.dm').read_text(encoding='utf-8')
        life = text.split('/mob/living/Life()', 1)[1].split('/mob/living/proc/', 1)[0]
        self.assertRegex(life, r'if \(is_liquid_water\(loc\)\)\n'
                              r'\t\tvar/turf/floor/beach/water/W = loc\n'
                              r'\t\tif \(!W.iscovered\(\)\)\n'
                              r'\t\t\tW.Extinguish\(src\)')
        self.assertLess(life.index('W.Extinguish(src)'), life.index('handle_fire()'))

    def test_boats_use_open_water(self):
        for rel in ('code/modules/craft/deck_berth.dm', 'code/modules/craft/vehicle_assembly.dm',
                    'code/modules/1713/machinery/modular_vehicles/axis.dm',
                    'code/modules/1713/machinery/modular_vehicles/ships/axis.dm'):
            self.assertIn('is_open_water(', (ROOT / rel).read_text(encoding='utf-8'), rel)


if __name__ == '__main__':
    unittest.main()
