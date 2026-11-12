"""Offline checks for explosion remains: production wiring and the map audit."""
import contextlib
import importlib.util
import io
from pathlib import Path
import unittest

HERE = Path(__file__).resolve().parent


def load(name):
    spec = importlib.util.spec_from_file_location('explosion_remains_' + name, HERE / (name + '.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class ExplosionRemains(unittest.TestCase):
    def test_production_wiring(self):
        with contextlib.redirect_stdout(io.StringIO()) as out:
            failures = load('run').static_checks()
        self.assertEqual(failures, [], out.getvalue())

    def test_circular_explosion_walks_only_the_damage_radius(self):
        # flash_range is never applied per turf; walking trange(flash_range)
        # cost ~19 ms per (2, 2, 2, 100) artillery shell just to skip turfs.
        source = (HERE.parents[1] / 'code/processes/explosion.dm').read_text()
        body = source[source.index('/process/explosion/proc/explosion('):source.index('/process/explosion/proc/explosion_rec(')]
        self.assertIn('var/damage_range = max(devastation_range, heavy_impact_range, light_impact_range)\n', body)
        self.assertIn('for (var/turf/T in trange(damage_range, epicenter))', body)
        self.assertNotIn('trange(max_range', body)

    def test_known_maps_classify_their_upper_levels(self):
        audit = load('map_audit')
        for rel, levels in audit.EXPECTED.items():
            result = audit.classify(audit.ROOT / rel)
            for z, expected in levels.items():
                self.assertEqual(result[z][0], expected, f'{rel} z{z}')


# The frozen statement sequence is the pre-change recursive spread. The small
# interpreter below reads the matching production statements so changing their
# directions or order changes the observed traversal instead of just a string.
ORIGINAL_SPREAD_STEPS = '''
var/turf/T = get_step(s, direction)
explosion_spread(T, spread_power, direction)
T = get_step(s, turn(direction,90))
explosion_spread(T, spread_power, turn(direction,90))
T = get_step(s, turn(direction,-90))
explosion_spread(T, spread_power, turn(direction,-90))
'''


def spread_steps(source):
    body = source.split('/process/explosion/proc/explosion_spread(', 1)[1]
    body = body.split('/process/explosion/proc/queue(', 1)[0]
    start = body.index('var/turf/T = get_step(s, direction)')
    return body[start:].strip().splitlines()


def project_spread(lines, start, power, direction, seeded=None):
    """Model spread on a bounded, non-null cardinal grid; not BYOND execution."""
    import re

    visited = dict(seeded or {})
    events = []
    turn_calls = 0
    # Keep every test path away from map edges, so get_step always returns a turf.
    resistance = {(1, 0): (1, (1,)), (0, 1): (2, (0, 1)), (-1, 0): (1, ())}

    def walk(position, strength, heading):
        nonlocal turn_calls
        events.append(('visit', position, strength, heading))
        if strength <= 0:
            events.append(('nonpositive', position, strength))
            return
        if visited.get(position, 0) >= strength:
            events.append(('already-covered', position, strength))
            return
        visited[position] = strength
        turf_resistance, object_resistances = resistance.get(position, (1, ()))
        remaining = strength - turf_resistance - sum(object_resistances)
        variables = {'s': position, 'direction': heading, 'spread_power': remaining}

        def value(expression):
            nonlocal turn_calls
            expression = expression.strip()
            match = re.fullmatch(r'turn\(direction,\s*(-?90)\)', expression)
            if match:
                turn_calls += 1
                x, y = heading
                return (-y, x) if int(match.group(1)) == 90 else (y, -x)
            if expression in variables:
                return variables[expression]
            raise AssertionError('unsupported spread expression: ' + expression)

        for raw in lines:
            line = raw.strip()
            match = re.fullmatch(r'(?:var/turf/|var/)?(\w+)\s*=\s*get_step\(s,\s*(.*)\)', line)
            if match:
                dx, dy = value(match.group(2))
                variables[match.group(1)] = (position[0] + dx, position[1] + dy)
                continue
            match = re.fullmatch(r'(?:var/)?(\w+)\s*=\s*(turn\(direction,\s*-?90\))', line)
            if match:
                variables[match.group(1)] = value(match.group(2))
                continue
            match = re.fullmatch(r'explosion_spread\(T,\s*spread_power,\s*(.*)\)', line)
            if match:
                walk(variables['T'], remaining, value(match.group(1)))
                continue
            raise AssertionError('unsupported spread statement: ' + line)

    walk(start, power, direction)
    return visited, events, turn_calls


class RecursiveExplosionSpread(unittest.TestCase):
    def setUp(self):
        source = (HERE.parents[1] / 'code/processes/explosion.dm').read_text()
        body = source.split('/process/explosion/proc/explosion_spread(', 1)[1]
        body = body.split('/process/explosion/proc/queue(', 1)[0]
        # These are model assumptions for the guards and resistance calculation.
        for fragment in ('if (power <= 0)', 'if (explosion_turfs[s] >= power)',
                         'explosion_turfs[s] = power',
                         'power - s.explosion_resistance',
                         'spread_power -= O.explosion_resistance'):
            self.assertIn(fragment, body)
        self.production = spread_steps(source)
        self.original = ORIGINAL_SPREAD_STEPS.strip().splitlines()

    def test_equivalent_traversal_and_early_returns(self):
        cases = [
            ((0, 0), 0, (0, 1), {}),
            ((0, 0), 3, (1, 0), {(0, 0): 3}),
            ((0, 0), 5, (0, 1), {}),
            ((0, 0), 5, (1, 0), {}),
            ((0, 0), 5, (0, -1), {(0, 1): 5}),
            ((0, 0), 5, (-1, 0), {(-1, 0): 1}),
        ]
        for start, power, heading, seeded in cases:
            with self.subTest(power=power, heading=heading, seeded=seeded):
                original = project_spread(self.original, start, power, heading, seeded)
                actual = project_spread(self.production, start, power, heading, seeded)
                self.assertEqual(actual[:2], original[:2])
                self.assertLessEqual(actual[2], original[2])
        original = project_spread(self.original, (0, 0), 5, (0, 1))
        actual = project_spread(self.production, (0, 0), 5, (0, 1))
        self.assertLess(actual[2], original[2])
        self.assertTrue(any(event[0] == 'nonpositive' for event in actual[1]))
        self.assertTrue(any(event[0] == 'already-covered' for event in actual[1]))

    def test_wrong_recursive_heading_is_detected(self):
        mutant = list(self.production)
        index = next(i for i, line in enumerate(mutant)
                     if line.strip() == 'explosion_spread(T, spread_power, side_direction)')
        mutant[index] = mutant[index].replace('side_direction', 'direction')
        expected = project_spread(self.original, (0, 0), 5, (0, 1))
        changed = project_spread(mutant, (0, 0), 5, (0, 1))
        self.assertNotEqual(changed[:2], expected[:2])
if __name__ == '__main__':
    unittest.main()
