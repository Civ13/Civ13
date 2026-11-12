"""Source projection of burning-human protection; does not execute BYOND."""
import importlib.util
from itertools import product
import math
from pathlib import Path
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).parent
SPEC = importlib.util.spec_from_file_location('source_adapter', ROOT / 'tests/save_movement/source_adapter.py')
ADAPTER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ADAPTER)
SOURCE = ROOT / 'code/game/mob/living/carbon/human/human_life.dm'
DECL = '/mob/living/human/handle_fire'
ARGS = 'fire_burn_temperature, get_heat_protection, get_heat_protection_flags, get_thermal_protection, body, species, organs, prob, typed_iter, round, log, BODYTEMP_HEATING_MAX'


def production():
    body = ADAPTER.extract(SOURCE.read_text(encoding='utf-8-sig'), DECL)
    start = body.index('\tvar/burn_temperature = fire_burn_temperature()')
    return '/check()\n' + body[start:].rstrip() + '\n'


def project(source):
    # Keep the changed body complete, while exposing its mutable scalar to the harness.
    source = source.replace('bodytemperature', 'body.value')
    return ADAPTER.project(source, '/check', ARGS, {})


class Organ:
    def __init__(self, name, part, events):
        self.name, self.body_part, self.events = name, part, events

    def take_damage(self, **kwargs):
        self.events.append(('damage', self.name, kwargs['burn'], kwargs['used_weapon']))


def run(proc, garments, temperature, initial_body, rolls):
    events = []
    body = SimpleNamespace(value=initial_body)
    species = SimpleNamespace(heat_level_1=360, heat_level_2=400, heat_level_3=500)
    organs = [Organ('head', 1, events), Organ('torso', 2, events),
              Organ('arm', 4, events), Organ('leg', 8, events)]
    remaining = iter(rolls)

    def fire_temp():
        events.append(('burn_temperature', temperature))
        return temperature

    def flags(temp):
        # Model the production helper's six clothing slots, nonzero threshold,
        # inclusive temperature comparison, and OR of qualifying coverage flags.
        result = 0
        for maximum, coverage in garments:
            if maximum and maximum >= temp:
                result |= coverage
        events.append(('flags', temp, result))
        return result

    def thermal(mask):
        events.append(('thermal', mask))
        return mask.bit_count() / 4

    def heat(temp):
        return thermal(flags(temp))

    def probability(percent):
        value = next(remaining)
        events.append(('prob', percent, value))
        return value

    def typed_iter(values, kind):
        assert kind == '/obj/item/organ/external'
        return iter(values)

    def dm_round(value, step):
        return math.floor(value / step + 0.5) * step

    proc(fire_temp, heat, flags, thermal, body, species, organs, probability,
         typed_iter, dm_round, lambda base, value: math.log(value, base), 10)
    return body.value, events


def without_second_flags(trace):
    result = []
    seen = 0
    for event in trace:
        if event[0] == 'flags':
            seen += 1
            if seen == 2:
                continue
        result.append(event)
    return result


class FireProtectionChecks(unittest.TestCase):
    def test_equivalence_and_wrong_flags_control(self):
        before = (HERE / 'before.dm.txt').read_text(encoding='utf-8-sig')
        current = production()
        first = 'var/protected_limbs = get_heat_protection_flags(burn_temperature)'
        second = 'var/thermal_protection = get_thermal_protection(protected_limbs)'
        self.assertEqual(current.count(first), 1)
        self.assertEqual(current.count(second), 1)
        self.assertLess(current.index(first), current.index(second))
        self.assertNotIn('get_heat_protection(burn_temperature)', current)
        mutant = current.replace('get_thermal_protection(protected_limbs)', 'get_thermal_protection(0)')
        self.assertNotEqual(mutant, current)
        original, candidate, wrong = map(project, (before, current, mutant))
        # No, partial, full and threshold-limited protection; overlapping items
        # exercise OR rather than counting garment entries.
        garments = ((), ((1000, 1),), ((1000, 15),),
                    ((400, 3), (500, 2), (0, 15)))
        differing = 0
        for clothes, temp, body, rolls in product(garments, (360, 361, 399, 400, 401, 499, 500, 501),
                                                   (300, 400, 600), ((True,) * 4, (False, True, False, True))):
            expected_body, old_events = run(original, clothes, temp, body, rolls)
            actual_body, new_events = run(candidate, clothes, temp, body, rolls)
            self.assertEqual(actual_body, expected_body, (clothes, temp, body, rolls))
            self.assertEqual(new_events, without_second_flags(old_events), (clothes, temp, body, rolls))
            self.assertEqual(sum(event[0] == 'flags' for event in old_events), 2)
            self.assertEqual(sum(event[0] == 'flags' for event in new_events), 1)
            wrong_body, wrong_events = run(wrong, clothes, temp, body, rolls)
            differing += (wrong_body, [e for e in wrong_events if e[0] in ('prob', 'damage')]) != (actual_body, [e for e in new_events if e[0] in ('prob', 'damage')])
        self.assertGreater(differing, 0, 'wrong-flags mutant survived')

    def test_damage_and_temperature_gates_are_exercised(self):
        candidate = project(production())
        body, trace = run(candidate, ((1000, 1),), 401, 300, (True,) * 4)
        self.assertGreater(body, 300)
        self.assertEqual([entry[1] for entry in trace if entry[0] == 'damage'], ['torso', 'arm', 'leg'])
        full_body, full_trace = run(candidate, ((1000, 15),), 401, 300, (True,) * 4)
        self.assertEqual(full_body, 300)
        self.assertFalse(any(entry[0] in ('prob', 'damage') for entry in full_trace))
        _, below_trace = run(candidate, (), 360, 300, (True,) * 4)
        self.assertFalse(any(entry[0] in ('prob', 'damage') for entry in below_trace))


if __name__ == '__main__':
    unittest.main()
