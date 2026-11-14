"""Source-projected hunger branch and workload/climate checks; this is not a native BYOND test."""
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
LIFE = ROOT / 'code/game/mob/living/carbon/human/human_life.dm'
# Heat waves are local weather systems now: weather_heat_at(src) answers for the mob's tile.
HEAT = [False]
BASE = 0.27 * 0.32
FOOD = {0: 0.6, 1: 0.8, 2: 1, 3: 1.75}
WATER = {0: 0.6, 1: 0.8, 2: 1, 3: 2}


def helper(name, args, env):
    source = LIFE.read_text(encoding='utf-8')
    return ADAPTER.project(source, '/mob/living/human/proc/' + name, args, env)


def helpers(body_temperature=310.15):
    """Project the production workload and climate helpers with one body temperature."""
    species = SimpleNamespace(body_temperature=310.15)
    env = {'MAP_NOMADS_DESERT': 2, 'src': None, 'weather_heat_at': lambda who: HEAT[0],
           'species': species, 'bodytemperature': body_temperature}
    food = helper('survival_work_food_m', 'workload', dict(env))
    env['survival_work_food_m'] = food
    water = helper('survival_work_water_m', 'workload', env)
    climate_food = helper('survival_climate_food_m', '', dict(env))
    climate_env = dict(env)
    climate_water = lambda location: (climate_env.__setitem__('map', location), helper('survival_climate_water_m', '', climate_env)())[1]
    return food, water, climate_food, climate_water


def projected(workload, climate_food, climate_water):
    source = LIFE.read_text(encoding='utf-8')
    start = source.index('\t\tif (inducedSSD) //if sleeping in SSD mode')
    end = source.index('\n\t\tif (find_trait("Extroverted"))', start)
    wrapped = '/check()\n' + textwrap.indent(textwrap.dedent(source[start:end]), '\t') + '\n\treturn (nutrition, water)\n'
    food, water, _, _ = helpers()
    env = {'CONSCIOUS': 0, 'UNCONSCIOUS': 1, 'HUNGER_THIRST_MULTIPLIER': 0.32,
           'survival_current_workload': lambda: workload, 'survival_work_food_m': food, 'survival_work_water_m': water,
           'survival_climate_food_m': lambda: climate_food, 'survival_climate_water_m': lambda: climate_water}
    return ADAPTER.project(wrapped, '/check', 'inducedSSD, stat, nutrition, water, food_m, water_m, activity_m', env)


class ConsciousHungerTests(unittest.TestCase):
    def test_rates_and_precedence(self):
        for workload, climate in itertools.product(range(4), ((1, 1), (1.3, 2.2), (1.6, 3.3))):
            run = projected(workload, *climate)
            for ssd, stat, activity, food, water in itertools.product(
                    (False, True), (0, 1, 2), (0.1, 1), (0, 0.8, 1.4), (0, 0.2, 2.5)):
                actual = run(ssd, stat, 500, 500, food, water, activity)
                if ssd or stat == 2:
                    expected = (500, 500)
                elif stat == 1:
                    expected = (500 - 0.01 * 0.32 * food, 500 - 0.01 * 0.32 * water)
                else:
                    expected = (500 - BASE * food * activity * FOOD[workload] * climate[0],
                                500 - BASE * water * activity * WATER[workload] * climate[1])
                self.assertEqual(actual, expected, (workload, climate, ssd, stat, activity, food, water))

    def test_workload_ladder(self):
        food, water, _, _ = helpers()
        self.assertEqual([food(w) for w in range(4)], [FOOD[w] for w in range(4)])
        self.assertEqual([water(w) for w in range(4)], [WATER[w] for w in range(4)])
        # Heavy labour must cost more than ordinary work, which costs more than resting.
        self.assertLess(food(0), food(1))
        self.assertLess(food(2), food(3))
        self.assertGreater(water(3), food(3))

    def test_pools_last_by_workload(self):
        defines = (ROOT / 'code/game/mob/living/carbon/carbon_defines.dm').read_text(encoding='utf-8')
        self.assertIn('var/max_nutrition = 600.0', defines)
        self.assertIn('var/max_water = 500.0', defines)
        food, water, _, _ = helpers()
        minutes = lambda pool, m: pool / (BASE * m) / 60
        self.assertGreater(minutes(600, food(0)), 180)    # resting: about 3 hours
        self.assertGreater(minutes(600, food(2)), 110)    # ordinary work: about 2 hours
        self.assertGreater(minutes(600, food(3)), 60)     # heavy labour: about 1 hour
        self.assertLess(minutes(600, food(3)), 77)        # heavy labour is harder than the old flat 77 minutes
        self.assertGreater(minutes(500, water(2)), 90)

    def test_climate_follows_body_temperature(self):
        normal = SimpleNamespace(ID=0)
        desert = SimpleNamespace(ID=2)
        for body, cold_food, hot_water in ((310.15, 1, 1), (306.15, 1, 1), (305.15, 1.3, 1), (295.15, 1.6, 1),
                                           (312.15, 1, 1), (313.15, 1, 1.5)):
            _, _, climate_food, climate_water = helpers(body)
            HEAT[0] = False
            self.assertEqual(climate_food(), cold_food, body)
            self.assertAlmostEqual(climate_water(normal), hot_water, msg=body)
            self.assertAlmostEqual(climate_water(desert), 2.2 * hot_water, msg=body)
            HEAT[0] = True
            self.assertAlmostEqual(climate_water(normal), 2.2 * hot_water, msg=body)
        HEAT[0] = False

    def test_weather_negative_control(self):
        source = LIFE.read_text(encoding='utf-8')
        marker = 'map.ID == MAP_NOMADS_DESERT || weather_heat_at(src)'
        self.assertEqual(source.count(marker), 1)
        _, _, _, climate_water = helpers()
        HEAT[0] = False
        self.assertEqual(climate_water(SimpleNamespace(ID=2)), 2.2)
        self.assertEqual(climate_water(SimpleNamespace(ID=0)), 1)


class PoolMigrationTests(unittest.TestCase):
    """Saved characters from the 400/350 pools keep the same fraction of a full stomach."""
    def migrate(self, nutrition, max_nutrition, water, max_water):
        source = (ROOT / 'code/game/mob/living/carbon/human/survival_workload.dm').read_text(encoding='utf-8')
        body = source[source.index('/mob/living/human/after_load()'):]
        body = body.replace('\t. = ..()\n', '')
        wrapped = body.replace('/mob/living/human/after_load()', '/check()') + '\treturn (nutrition, max_nutrition, water, max_water)\n'
        initial = {'max_nutrition': 600, 'max_water': 500}
        env = {'initial': lambda name: initial[name]}
        # initial(max_nutrition) reads the field name, not its current value.
        wrapped = wrapped.replace('initial(max_nutrition)', 'initial("max_nutrition")').replace('initial(max_water)', 'initial("max_water")')
        return ADAPTER.project(wrapped, '/check', 'nutrition, max_nutrition, water, max_water', env)(
            nutrition, max_nutrition, water, max_water)

    def test_old_pools_scale_up(self):
        self.assertEqual(self.migrate(400, 400, 350, 350), (600, 600, 500, 500))
        self.assertEqual(self.migrate(200, 400, 175, 350), (300, 600, 250, 500))
        self.assertEqual(self.migrate(-40, 400, 0, 350), (-60, 600, 0, 500))

    def test_new_pools_untouched(self):
        self.assertEqual(self.migrate(123, 600, 77, 500), (123, 600, 77, 500))


if __name__ == '__main__':
    unittest.main()
