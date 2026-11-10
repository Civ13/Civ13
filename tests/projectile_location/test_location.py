"""Offline, source-driven model of the projectile location lookup seam.

The model is intentionally restricted to the statements in this seam and the
current plot_vector implementation. It is not a DM interpreter or native BYOND
evidence. It assumes synchronous, deterministic locate() and models ordinary
in-bounds and out-of-bounds results. Callbacks record their order and observed
location, but do not themselves mutate state. It does not model allocation
failure, runtime dispatch, garbage collection, or globally observable
identities of fresh datums.
"""

from dataclasses import dataclass
from pathlib import Path
import math
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
PROJECTILE = ROOT / 'code/modules/projectiles/projectile.dm'
VECTOR = ROOT / 'code/_helpers/vector.dm'

# Frozen original seam, independent of Git history. Keep the failure callbacks
# and the post-assignment guard: both are part of the compared contract.
ORIGINAL = '''
if (!trajectory.return_location(location))
    for (var/atom/movable/AM in loc)
        do_bullet_act(AM)
    do_bullet_act(loc)
    on_impact(loc)
    qdel(src)
    return
location = trajectory.return_location(location)
if (!location)
    qdel(src)
    return
'''

VECTOR_BODY = '''
if (!data)
    data = new()
data.loc = locate(round(loc_x / world.icon_size, TRUE), round(loc_y / world.icon_size, TRUE), loc_z)
if (!data.loc)
    return
data.pixel_x = loc_x - (data.loc.x * world.icon_size)
data.pixel_y = loc_y - (data.loc.y * world.icon_size)
return data
'''


def lines(text):
    """Remove comments and normalize one indentation unit to four spaces."""
    cleaned = []
    for raw in text.expandtabs(4).splitlines():
        raw = raw.split('//', 1)[0].rstrip()
        if raw.strip():
            cleaned.append(raw)
    minimum = min(len(line) - len(line.lstrip()) for line in cleaned)
    return [line[minimum:] for line in cleaned]


def source_seam():
    text = PROJECTILE.read_text(encoding='utf-8')
    process = text.split('/obj/item/projectile/process()', 1)[1]
    return process.split('trajectory.increment()', 1)[1].split('var/list/_untouchable', 1)[0]


def verify_vector_source():
    source = VECTOR.read_text(encoding='utf-8')
    body = source.split('/datum/plot_vector/proc/return_location(var/datum/vector_loc/data)', 1)[1]
    body = body.split('\n/*', 1)[0]
    if lines(body) != lines(VECTOR_BODY):
        raise AssertionError('return_location source changed; review the model')


def parse(text):
    """Parse only the supported source grammar; reject every unknown line."""
    source = lines(text)

    def block(index, indent):
        result = []
        while index < len(source):
            line = source[index]
            depth = len(line) - len(line.lstrip())
            if depth < indent:
                break
            if depth != indent:
                raise AssertionError(f'unexpected indentation: {line!r}')
            statement = line.strip()
            match = re.fullmatch(r'if \(!(.+)\)', statement)
            if match:
                condition = match.group(1)
                if not (re.fullmatch(r'[A-Za-z_]\w*', condition) or
                        condition == 'trajectory.return_location(location)'):
                    raise AssertionError(f'unknown condition: {condition}')
                child, index = block(index + 1, indent + 4)
                if not child:
                    raise AssertionError('empty conditional')
                result.append(('if_not', condition, child))
                continue
            if statement == 'for (var/atom/movable/AM in loc)':
                child, index = block(index + 1, indent + 4)
                if not child:
                    raise AssertionError('empty loop')
                result.append(('for', child))
                continue
            match = re.fullmatch(r'(?:var/datum/vector_loc/)?([A-Za-z_]\w*) = '
                                 r'(trajectory\.return_location\(location\)|[A-Za-z_]\w*|null)', statement)
            if match:
                result.append(('assign', *match.groups()))
            elif statement in ('do_bullet_act(AM)', 'do_bullet_act(loc)',
                               'on_impact(loc)', 'qdel(src)', 'return'):
                result.append(('action', statement))
            else:
                raise AssertionError(f'unknown seam statement: {statement!r}')
            index += 1
        return result, index

    result, end = block(0, 0)
    if end != len(source):
        raise AssertionError('unparsed source')
    return result


@dataclass
class VectorLoc:
    loc: object = None
    pixel_x: object = None
    pixel_y: object = None


class Model:
    def __init__(self, x, y, existing=False):
        self.x, self.y = x, y
        self.initial = VectorLoc((2, 2, 1), 7, -9) if existing else None
        self.variables = {'location': self.initial}
        self.calls = 0
        self.callbacks = []
        self.deleted = False

    def snapshot(self):
        value = self.variables['location']
        if value is None:
            return None
        return (value is self.initial, value.loc, value.pixel_x, value.pixel_y)

    def lookup(self):
        self.calls += 1
        data = self.variables['location'] or VectorLoc()
        # The tested points avoid half-tile ties; this is a model of the
        # documented nearest-centre lookup, not a BYOND rounding oracle.
        tx, ty = math.floor(self.x / 32 + 0.5), math.floor(self.y / 32 + 0.5)
        data.loc = (tx, ty, 1) if 1 <= tx <= 4 and 1 <= ty <= 4 else None
        if data.loc is None:
            return None
        data.pixel_x, data.pixel_y = self.x - tx * 32, self.y - ty * 32
        return data

    def evaluate(self, expression):
        if expression == 'trajectory.return_location(location)':
            return self.lookup()
        if expression == 'null':
            return None
        if expression not in self.variables:
            raise AssertionError(f'unknown variable: {expression}')
        return self.variables[expression]

    def execute(self, program):
        for item in program:
            kind = item[0]
            if kind == 'assign':
                self.variables[item[1]] = self.evaluate(item[2])
            elif kind == 'if_not':
                if not self.evaluate(item[1]) and self.execute(item[2]):
                    return True
            elif kind == 'for':
                for name in ('first atom', 'second atom'):
                    self.variables['AM'] = name
                    if self.execute(item[1]):
                        return True
            elif kind == 'action':
                action = item[1]
                if action == 'return':
                    return True
                if action == 'qdel(src)':
                    self.deleted = True
                self.callbacks.append((action, self.variables.get('AM') if action == 'do_bullet_act(AM)' else None,
                                       self.snapshot()))
            else:
                raise AssertionError(f'unknown operation: {item!r}')
        return False

    def outcome(self):
        return self.snapshot(), self.callbacks, self.deleted


class ProjectileLocationTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        verify_vector_source()
        cls.baseline = parse(ORIGINAL)
        cls.actual = parse(source_seam())

    def test_valid_and_off_map_equivalence(self):
        # Integer, off-centre and off-map points; no half-tile rounding ties.
        for existing in (False, True):
            for x, y in ((32, 32), (77, 91), (128, 128), (160, 32), (32, -32)):
                with self.subTest(existing=existing, x=x, y=y):
                    before, after = Model(x, y, existing), Model(x, y, existing)
                    before.execute(self.baseline)
                    after.execute(self.actual)
                    self.assertEqual(before.outcome(), after.outcome())
                    self.assertEqual(after.calls, 1)
                    self.assertEqual(before.calls, 2 if before.snapshot() and before.snapshot()[1] else 1)

    def test_success_then_off_map_retains_mutated_previous_location(self):
        for existing in (False, True):
            before, after = Model(77, 91, existing), Model(77, 91, existing)
            before.execute(self.baseline)
            after.execute(self.actual)
            before.x = after.x = 160
            before.execute(self.baseline)
            after.execute(self.actual)
            self.assertEqual(before.outcome(), after.outcome())
            self.assertEqual(after.calls, 2)
            self.assertEqual(after.snapshot()[1:], (None, 13, -5))

    def test_known_valid_coordinates_and_identity(self):
        for existing in (False, True):
            shot = Model(77, 91, existing)
            shot.execute(self.actual)
            self.assertEqual(shot.snapshot(), (existing, (2, 3, 1), 13, -5))
            self.assertEqual(shot.callbacks, [])
            self.assertFalse(shot.deleted)

    def test_negative_control_early_assignment_changes_failure_callbacks(self):
        early = parse('''
            location = trajectory.return_location(location)
            if (!location)
                for (var/atom/movable/AM in loc)
                    do_bullet_act(AM)
                do_bullet_act(loc)
                on_impact(loc)
                qdel(src)
                return
        ''')
        baseline, mutated = Model(160, 32, True), Model(160, 32, True)
        baseline.execute(self.baseline)
        mutated.execute(early)
        self.assertNotEqual(baseline.callbacks, mutated.callbacks)
        self.assertEqual(baseline.callbacks[0][2], (True, None, 7, -9))
        self.assertIsNone(mutated.callbacks[0][2])

    def test_negative_control_duplicate_lookup_is_detected(self):
        duplicate = Model(77, 91)
        duplicate.execute(self.baseline)
        self.assertEqual(duplicate.calls, 2)
        with self.assertRaises(AssertionError):
            self.assertEqual(duplicate.calls, 1)


if __name__ == '__main__':
    unittest.main()
