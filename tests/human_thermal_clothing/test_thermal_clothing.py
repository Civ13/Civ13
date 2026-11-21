"""Source-projected thermal branches; this does not execute BYOND."""
import importlib.util
from itertools import product
from pathlib import Path
import unittest
from types import SimpleNamespace

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
OLD_OVERLAP = '\t\t\tprotection += 0.16 * get_thermal_protection(coverage & covered)'
NEW_OVERLAP = ('\t\t\tvar/overlap = coverage & covered\n'
               '\t\t\tif (overlap)\n'
               '\t\t\t\tprotection += 0.16 * get_thermal_protection(overlap)')

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
        for old in (OLD_HEAT, OLD_COLD, OLD_LAYER, OLD_OVERLAP):
            self.assertEqual(before.count(old), 1)
        expected = (before.replace(OLD_HEAT, NEW_HEAT).replace(OLD_COLD, NEW_COLD)
                    .replace(OLD_LAYER, NEW_LAYER).replace(OLD_OVERLAP, NEW_OVERLAP))
        self.assertEqual(production(), expected)

    def test_thresholds_layers_and_negative_controls(self):
        before = (HERE / 'before.dm.txt').read_text(encoding='utf-8')
        after = production()
        original = [project(before, name) for name in DECLARATIONS]
        current = [project(after, name) for name in DECLARATIONS]
        mutations = [after.replace('C.max_heat_protection_temperature >= temperature', 'C.max_heat_protection_temperature > temperature'),
                     after.replace('C.min_cold_protection_temperature <= temperature', 'C.min_cold_protection_temperature < temperature'),
                     after.replace('var/overlap = coverage & covered', 'var/overlap = coverage & ~covered')]
        mutants = [project(mutations[i], name) for i, name in enumerate(DECLARATIONS)]
        differences = [0, 0, 0]
        choices = (None, object(), Clothing('one', 200, 310, 1), Clothing('overlap', 244, 350, 3), Clothing('unrated', 0, 0, 4))
        for prefix, temp, disabled, wetness in product(product(choices, repeat=3), (2.7, 200, 244, 310, 400), (0, 1), (0, 1)):
            slots = (*prefix, None, None, None)
            for index in range(3):
                expected_value, expected_events = run(original[index], slots, temp, disabled, wetness)
                actual_value, actual_events = run(current[index], slots, temp, disabled, wetness)
                self.assertEqual(actual_value, expected_value)
                if index == 2:
                    # The old layer emits coverage, first-layer thermal and overlap thermal
                    # in groups of three. Only the zero-overlap call is removed.
                    expected_events = [event for i, event in enumerate(expected_events)
                                       if i % 3 != 2 or event != ('thermal', 0)]
                self.assertEqual(actual_events, expected_events)
                differences[index] += run(mutants[index], slots, temp, disabled, wetness)[0] != actual_value
        self.assertTrue(all(differences), differences)

    def test_thermal_call_counts_for_disjoint_and_overlapping_layers(self):
        before = project((HERE / 'before.dm.txt').read_text(encoding='utf-8'), DECLARATIONS[2])
        after = project(production(), DECLARATIONS[2])
        for masks, expected_new in (((1, 2, 4), 3), ((1, 1, 1), 5), ((0, 0, 0), 3)):
            slots = tuple(Clothing(str(i), 200, 350, mask) for i, mask in enumerate(masks)) + (None,) * 3
            old_value, old_events = run(before, slots, 244)
            new_value, new_events = run(after, slots, 244)
            self.assertEqual(new_value, old_value)
            self.assertEqual(sum(event[0] == 'thermal' for event in old_events), 6)
            self.assertEqual(sum(event[0] == 'thermal' for event in new_events), expected_new)


class DiscomfortCoverageChecks(unittest.TestCase):
    """Project the production loops; fake only clothing and list boundaries."""

    def test_exposed_parts_and_cold_coverage_calls(self):
        source = (ROOT / 'code/game/mob/living/carbon/human/species/species.dm').read_text(encoding='utf-8')
        section = source[source.index('/datum/species/proc/get_environment_discomfort('):]
        masks = dict(zip(('HEAD', 'UPPER_TORSO', 'LOWER_TORSO', 'LEGS', 'FEET', 'ARMS', 'HANDS'),
                         (1, 2, 4, 8, 16, 32, 64)))
        regions = {'HEAD': ('head',), 'UPPER_TORSO': ('chest',), 'LOWER_TORSO': ('groin',),
                   'LEGS': ('l_leg', 'r_leg'), 'FEET': ('l_foot', 'r_foot'),
                   'ARMS': ('l_arm', 'r_arm'), 'HANDS': ('l_hand', 'r_hand')}

        class DMList(list):
            def __isub__(self, item):
                self[:] = [value for value in self if value != item]
                return self

        class Garment:
            def __init__(self, name, heat, cold, cape=0):
                self.name, self.heat_protection, self.cold_protection, self.cape = name, heat, cold, cape
            def get_cold_coverage(self):
                events.append(self.name)
                return self.cold_protection | self.cape

        def typed_iter(values, kind):
            assert kind == '/obj/item/clothing'
            return (value for value in values if isinstance(value, Garment))

        chunks = []
        cursor = 0
        for _ in range(2):
            start = section.index('\n\t\tvar/sum = 0', cursor) + 1
            end = section.index('\n\n\t\tfor (var/i in exposed_bp)', start)
            chunks.append(section[start:end])
            cursor = end

        for is_cold, chunk in enumerate(chunks):
            # Adapt only this contiguous production block; keep every loop and test.
            body = '\n'.join(line[1:] for line in chunk.splitlines())
            program = '/check()\n' + body + '\n\treturn exposed_bp\n'
            env = {**masks}
            proc = ADAPTER.project(program, '/check', 'H, typed_iter, list', env)
            mutant = ADAPTER.project(program.replace('if (sum & HEAD)', 'if (0)'),
                                     '/check', 'H, typed_iter, list', {**masks})
            mutant_detected = False
            for combined in range(128):
                # Repeated bits, empty slots, and cape-added cold coverage.
                first = Garment('first', combined & 0x55, combined & 0x55)
                second = Garment('second', combined & 0x2a, combined & 0x2a, combined & 1)
                slots = (first, None, second, object(), None, None)
                h = SimpleNamespace(**dict(zip(('head', 'wear_suit', 'w_uniform', 'shoes', 'gloves', 'wear_mask'), slots)))
                events = []
                result = proc(h, typed_iter, lambda *values: DMList(values))
                recorded = events[:]
                initial = (['l_foot','r_foot'] if is_cold else []) + ['l_leg','r_leg','chest','groin','l_arm','r_arm'] + (['l_hand','r_hand'] if is_cold else []) + ['head']
                covered = set()
                for name, bit in masks.items():
                    if combined & bit:
                        covered.update(regions[name])
                self.assertEqual(result, [part for part in initial if part not in covered])
                expected_calls = [item.name for item in (first, second) if item.cold_protection] if is_cold else []
                self.assertEqual(recorded, expected_calls)
                events = []
                mutant_detected |= mutant(h, typed_iter, lambda *values: DMList(values)) != result
            self.assertTrue(mutant_detected, 'missing head coverage must be detected')


if __name__ == '__main__':
    unittest.main()
