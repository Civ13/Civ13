"""Execute the production teardown control flow against inert registry boundaries.

This source projection does not execute BYOND or model engine garbage collection.
"""
from pathlib import Path
import re
import sys
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tests/save_movement'))
from source_adapter import project

MOVEMENT = ROOT / 'code/modules/1713/machinery/modular_vehicles/movement.dm'
SAIL = ROOT / 'code/modules/1713/machinery/modular_vehicles/ships/movement.dm'


def destroy_body():
    source = MOVEMENT.read_text(encoding='utf-8')
    bodies = re.findall(r'(?m)^\tDestroy\(\)\n((?:\t\t.*\n)+)', source)
    if len(bodies) != 1:
        raise AssertionError('Expected exactly one movement Destroy body')
    return ''.join(line[1:] for line in bodies[0].splitlines(keepends=True))


def teardown(body):
    body = re.sub(r'(?<![\w.])(?:axis|connected)\b', lambda m: 'src.' + m[0], body)
    body = re.sub(r'(?m)^(\t*)while \((.*)\)$', r'\1while \2:', body)
    body = body.replace('..()', 'parent()')
    return project('/destroy()\n' + body, '/destroy', 'src', {'parent': lambda: None})


class Registry(list):
    def __isub__(self, item):
        # Model one-at-a-time removal, the more demanding list boundary.
        if item in self:
            self.remove(item)
        return self


class ComponentTeardownTests(unittest.TestCase):
    def setUp(self):
        self.destroy = teardown(destroy_body())

    def test_duplicate_entries_and_replacement_slot(self):
        for registry in ('wheels', 'masts'):
            with self.subTest(registry=registry):
                part, replacement = SimpleNamespace(), object()
                owner = SimpleNamespace(wheels=Registry(), masts=Registry())
                getattr(owner, registry).extend([part, replacement, part])
                frame = SimpleNamespace(mwheel=replacement)
                part.axis, part.connected = owner, frame
                self.destroy(part)
                self.assertEqual(getattr(owner, registry), [replacement])
                self.assertIs(frame.mwheel, replacement)
                self.assertIsNone(part.axis)
                self.assertIsNone(part.connected)

    def test_owned_slot_and_detached_component(self):
        part = SimpleNamespace(axis=None, connected=SimpleNamespace(mwheel=None))
        part.connected.mwheel = part
        frame = part.connected
        self.destroy(part)
        self.assertIsNone(frame.mwheel)
        self.destroy(part)

    def test_sail_override_delegates_to_movement_cleanup(self):
        body = SAIL.read_text(encoding='utf-8').split('/movement/sail/Destroy()', 1)[1]
        self.assertIn('\n\t..()', body)
        self.assertNotIn('axis.wheels -= src', body)

    def test_previous_behavior_would_lose_replacement_and_leave_mast(self):
        previous = '\tif (axis)\n\t\taxis.wheels -= src\n\tif (connected)\n\t\tconnected.mwheel = null\n\t..()\n'
        part, replacement = SimpleNamespace(), object()
        owner = SimpleNamespace(wheels=Registry(), masts=Registry([part]))
        frame = SimpleNamespace(mwheel=replacement)
        part.axis, part.connected = owner, frame
        teardown(previous)(part)
        self.assertIsNone(frame.mwheel)
        self.assertIn(part, owner.masts)


class SailCooldownTests(unittest.TestCase):
    def test_cooldown_preserves_wheel_masts_and_retry_deadline(self):
        topic = SAIL.with_name('wheels.dm').read_text(encoding='utf-8')
        sail_action = topic.split('\n\tif (href_list["set_sails"])\n', 1)[1].split(
            '\n\tif (href_list["set_heading_left"])', 1)[0]
        sail_action = re.sub(r'(?<![\w.])(?:spamtimer|sails_on)\b',
                             lambda m: 'src.' + m[0], sail_action)
        sail_action = sail_action.replace('ship.masts.len', 'len(ship.masts)')
        source = '/sails()\n' + '\n'.join(line[1:] for line in sail_action.splitlines())
        now, messages, refreshes = SimpleNamespace(time=110), [], []
        action = project(source, '/sails', 'src, ship, user', {
            'world': now, 'typed_iter': lambda values, _kind: values,
            'SPAN_NOTICE': str, 'to_chat': lambda _user, message: messages.append(message),
        })
        wheel = SimpleNamespace(sails_on=False, spamtimer=120)
        masts = [SimpleNamespace(sails_on=False, update_icon=lambda: refreshes.append(1)) for _ in range(2)]
        ship = SimpleNamespace(masts=masts)
        for time in (110, 120):
            now.time = time
            action(wheel, ship, None)
            self.assertFalse(wheel.sails_on)
            self.assertEqual([mast.sails_on for mast in masts], [False, False])
            self.assertEqual(wheel.spamtimer, 120)
            self.assertFalse(refreshes)
            self.assertIn('Wait', messages[-1])
        now.time = 121
        action(wheel, ship, None)
        self.assertTrue(wheel.sails_on)
        self.assertEqual([mast.sails_on for mast in masts], [True, True])
        self.assertEqual(wheel.spamtimer, 141)
        self.assertEqual(len(refreshes), 2)
        self.assertIn('hoist', messages[-1])
        now.time = 132
        action(wheel, ship, None)
        self.assertTrue(wheel.sails_on)
        self.assertEqual(wheel.spamtimer, 141)
        self.assertEqual(len(refreshes), 2)
        now.time = 142
        action(wheel, ship, None)
        self.assertFalse(wheel.sails_on)
        self.assertEqual([mast.sails_on for mast in masts], [False, False])
        self.assertEqual(wheel.spamtimer, 162)
        self.assertEqual(len(refreshes), 4)
        self.assertIn('retract', messages[-1])


if __name__ == '__main__':
    unittest.main()
