"""Source-projected thermal branches; this does not execute BYOND."""
import importlib.util
from itertools import product
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).parent
SPEC = importlib.util.spec_from_file_location('thermal_adapter', ROOT / 'tests/save_movement/source_adapter.py')
ADAPTER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ADAPTER)
START = '/mob/living/human/proc/get_heat_protection_flags('
END = '/mob/living/human/proc/get_thermal_protection('
DECLARATIONS = ('/mob/living/human/proc/get_heat_protection_flags',
                '/mob/living/human/proc/get_cold_protection_flags',
                '/mob/living/human/get_cold_protection')
OLD_HEAT = '\t\tif (C)\n\t\t\tif (C.max_heat_protection_temperature && C.max_heat_protection_temperature >= temperature)\n\t\t\t\t. |= C.heat_protection'
NEW_HEAT = '\t\tif (C.max_heat_protection_temperature && C.max_heat_protection_temperature >= temperature)\n\t\t\t. |= C.heat_protection'
OLD_COLD = '\t\tif (C)\n\t\t\tif (C.min_cold_protection_temperature && C.min_cold_protection_temperature <= temperature)\n\t\t\t\t. |= C.get_cold_coverage()'
NEW_COLD = '\t\tif (C.min_cold_protection_temperature && C.min_cold_protection_temperature <= temperature)\n\t\t\t. |= C.get_cold_coverage()'
OLD_LAYER = 'if (C && C.min_cold_protection_temperature && C.min_cold_protection_temperature <= temperature)'
NEW_LAYER = 'if (C.min_cold_protection_temperature && C.min_cold_protection_temperature <= temperature)'
ARGS = ('temperature, head, wear_suit, w_uniform, shoes, gloves, wear_mask, '
        'cold_protection_disabled_timer, cold_wetness, get_thermal_protection, typed_iter, list')


def production():
    source = (ROOT / 'code/game/mob/living/carbon/human/human_life.dm').read_text(encoding='utf-8')
    return source[source.index(START):source.index(END)].rstrip() + '\n'


def project(fragment, declaration):
    body = ADAPTER.extract(fragment, declaration).replace('. |= ', 'result |= ')
    if declaration != DECLARATIONS[2]:
        body += '\n\treturn result'
    return ADAPTER.project('/check()\n' + body + '\n', '/check', ARGS, {})


class Clothing:
    def __init__(self, name, low, high, coverage):
        self.name = name
        self.min_cold_protection_temperature = low
        self.max_heat_protection_temperature = high
        self.heat_protection = coverage
        self.coverage = coverage
        self.events = None

    def get_cold_coverage(self):
        self.events.append(('coverage', self.name))
        return self.coverage


def run(proc, slots, temperature, disabled=0, wetness=0):
    events = []
    for item in slots:
        if isinstance(item, Clothing):
            item.events = events

    # Model BYOND's documented typed-list iteration; it filters null and
    # unrelated values before executing the production loop body.
    def typed_iter(values, kind):
        assert kind == '/obj/item/clothing'
        return (item for item in values if isinstance(item, Clothing))

    def thermal(flags):
        events.append(('thermal', flags))
        return flags.bit_count() / 4

    value = proc(temperature, *slots, disabled, wetness, thermal, typed_iter, lambda *items: list(items))
    return value, events


class ThermalClothingChecks(unittest.TestCase):
    def test_only_typed_loop_checks_change(self):
        before = (HERE / 'before.dm.txt').read_text(encoding='utf-8')
        for old in (OLD_HEAT, OLD_COLD, OLD_LAYER):
            self.assertEqual(before.count(old), 1)
        expected = before.replace(OLD_HEAT, NEW_HEAT).replace(OLD_COLD, NEW_COLD).replace(OLD_LAYER, NEW_LAYER)
        self.assertEqual(production(), expected)

    def test_thresholds_layers_and_negative_controls(self):
        before = (HERE / 'before.dm.txt').read_text(encoding='utf-8')
        after = production()
        original = [project(before, name) for name in DECLARATIONS]
        current = [project(after, name) for name in DECLARATIONS]
        mutations = [after.replace('C.max_heat_protection_temperature >= temperature', 'C.max_heat_protection_temperature > temperature'),
                     after.replace('C.min_cold_protection_temperature <= temperature', 'C.min_cold_protection_temperature < temperature'),
                     after.replace('coverage & covered)', 'coverage & ~covered)')]
        mutants = [project(mutations[i], name) for i, name in enumerate(DECLARATIONS)]
        differences = [0, 0, 0]
        choices = (None, object(), Clothing('one', 200, 310, 1), Clothing('overlap', 244, 350, 3), Clothing('unrated', 0, 0, 4))
        for prefix, temp, disabled, wetness in product(product(choices, repeat=3), (2.7, 200, 244, 310, 400), (0, 1), (0, 1)):
            slots = (*prefix, None, None, None)
            for index in range(3):
                expected = run(original[index], slots, temp, disabled, wetness)
                self.assertEqual(run(current[index], slots, temp, disabled, wetness), expected)
                differences[index] += run(mutants[index], slots, temp, disabled, wetness) != expected
        self.assertTrue(all(differences), differences)


if __name__ == '__main__':
    unittest.main()
