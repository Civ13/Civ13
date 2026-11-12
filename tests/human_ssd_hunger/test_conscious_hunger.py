"""Source-projected hunger branch checks; this is not a native BYOND test."""
import importlib.util
import itertools
from pathlib import Path
from types import SimpleNamespace
import textwrap
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('hunger_adapter', ROOT / 'tests/save_movement/source_adapter.py')
ADAPTER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ADAPTER)


def projected(mutate=None):
    source = (ROOT / 'code/game/mob/living/carbon/human/human_life.dm').read_text(encoding='utf-8')
    start = source.index('\t\tif (inducedSSD) //if sleeping in SSD mode')
    end = source.index('\n\t\tif (find_trait("Extroverted"))', start)
    branch = source[start:end]
    if mutate:
        branch = mutate(branch)
    wrapped = '/check()\n' + textwrap.indent(textwrap.dedent(branch), '\t') + '\n\treturn (nutrition, water)\n'
    env = {'CONSCIOUS': 0, 'UNCONSCIOUS': 1, 'MAP_NOMADS_DESERT': 2, 'HUNGER_THIRST_MULTIPLIER': 0.32}
    return ADAPTER.project(wrapped, '/check', 'inducedSSD, stat, map, nutrition, water, food_m, water_m, activity_m', env)


class ConsciousHungerTests(unittest.TestCase):
    def test_rates_and_precedence(self):
        run = projected()
        for ssd, stat, heat, desert, activity, food, water in itertools.product(
                (False, True), (0, 1, 2), (False, True), (False, True), (0.1, 1), (0, 0.8, 1.4), (0, 0.2, 2.5)):
            location = SimpleNamespace(heat_wave=heat, ID=2 if desert else 0)
            actual = run(ssd, stat, location, 500, 500, food, water, activity)
            if ssd or stat == 2:
                expected = (500, 500)
            elif stat == 1:
                expected = (500 - 0.01 * 0.32 * food, 500 - 0.01 * 0.32 * water)
            else:
                expected = (500 - 0.27 * 0.32 * food * activity,
                            500 - (0.7 if heat or desert else 0.27) * 0.32 * water * activity)
            self.assertEqual(actual, expected, (ssd, stat, heat, desert, activity, food, water))

    def test_weather_negative_control(self):
        def omit_desert(branch):
            marker = 'map.heat_wave || map.ID == MAP_NOMADS_DESERT'
            assert branch.count(marker) == 1
            return branch.replace(marker, 'map.heat_wave')
        normal = projected()
        control = projected(omit_desert)
        desert = SimpleNamespace(heat_wave=False, ID=2)
        args = (False, 0, desert, 500, 500, 1, 1, 1)
        self.assertNotEqual(normal(*args), control(*args))


if __name__ == '__main__':
    unittest.main()
