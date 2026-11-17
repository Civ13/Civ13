"""Cool cellars: source contracts. Behaviour is in probe.dm:

    python3 tests/cool_cellars/test_source.py
    python3 tests/ecology_spawning/run_linux.py . tests/cool_cellars/probe.dm
"""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text(encoding='utf-8')


class CoolCellarsSource(unittest.TestCase):
    def test_included(self):
        self.assertIn('#include "code\\modules\\1713\\cool_cellars.dm"', read('civ13.dme'))

    def test_temperature_hook(self):
        weather = read('code/modules/1713/weather.dm')
        self.assertIn('if (turf_in_cool_cellar(A))', weather)
        self.assertIn('loc_temp = cool_cellar_temperature(loc_temp)', weather)
        # The cellar answer is taken before the weather changes it.
        self.assertLess(weather.index('turf_in_cool_cellar(A)'), weather.index('var/local_weather = weather_at(A)'))

    def test_food_hook(self):
        food = read('code/modules/reagents/reagent_containers/food.dm')
        self.assertIn('var/decay_before = decaytimer', food)
        self.assertIn('cool_cellar_decay_step(src, decaytimer - decay_before)', food)


if __name__ == '__main__':
    unittest.main()
