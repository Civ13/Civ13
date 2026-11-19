"""Wired pole traversal visits each pole once (issue #6234).

The production transmit/ring_phone bodies run through the shared source adapter
on an inert grid. Only locate/get_turf/range/world.time are test boundaries.
"""
from pathlib import Path
import re
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tests/save_movement'))
from source_adapter import extract, project

SOURCE = (ROOT / 'code/modules/1713/telegraph.dm').read_text(encoding='utf-8')
BASE = '/obj/structure/phoneline/proc/'


class World:
    time = 100


class Thing:
    def __init__(self, grid, kind, x, y, z=1):
        self.grid, self.kind, self.x, self.y, self.z = grid, kind, x, y, z
        grid.things.append(self)


class Pole(Thing):
    def __init__(self, grid, x, y):
        super().__init__(grid, '/obj/structure/phoneline', x, y)
        self.lastproc = 0
        self.visits = 0

    def transmit(self, *args):
        # Count only entries that pass the guard and forward the traversal.
        self.visits += World.time > self.lastproc
        self.grid.depth_check()
        return self.grid.transmit(self, *args)

    def ring_phone(self, *args):
        # Count only entries that pass the guard and forward the traversal.
        self.visits += World.time > self.lastproc
        self.grid.depth_check()
        return self.grid.ring(self, *args)


class Telegraph(Thing):
    def __init__(self, grid, x, y):
        super().__init__(grid, '/obj/structure/telegraph', x, y)
        self.received = []

    def receive(self, msg, stripmsg):
        self.received.append(msg)


class Phone(Thing):
    def __init__(self, grid, x, y, number):
        super().__init__(grid, '/obj/item/weapon/telephone', x, y)
        self.phonenumber, self.ringing, self.rings = number, False, []

    def ringproc(self, origin, originphone):
        self.ringing = True
        self.rings.append(origin)


class Grid:
    def __init__(self):
        self.things, self.calls = [], 0
        env = {'world': World, 'locate': lambda x, y, z: (x, y, z),
               'get_turf': lambda turf: turf, 'range': self.range,
               'typed_iter': self.typed_iter}
        self.transmit = self.load('transmit', 'src,msg,stripmsg,TL,origin', env)
        self.ring = self.load('ring_phone', 'src,target,origin,originphone', env)

    @staticmethod
    def load(name, args, env):
        body = extract(SOURCE, BASE + name)
        # Pole members are instance fields; qualify them for the projection.
        body = re.sub(r'(?<![\w.])(x|y|z|lastproc)\b', r'src.\1', body)
        return project('/' + name + '()\n' + body, '/' + name, args, dict(env))

    def depth_check(self):
        self.calls += 1
        if self.calls > 200:
            raise AssertionError('pole traversal did not terminate')

    def range(self, dist, centre):
        return [t for t in self.things if t.z == centre.z
                and max(abs(t.x - centre.x), abs(t.y - centre.y)) <= dist]

    def typed_iter(self, where, kind):
        if isinstance(where, tuple):
            where = [t for t in self.things if (t.x, t.y, t.z) == where]
        return [t for t in list(where) if t.kind == kind]


class PoleTraversalTests(unittest.TestCase):
    def test_two_poles_ring_far_phone_once(self):
        grid = Grid()
        first, second = Pole(grid, 10, 10), Pole(grid, 13, 10)
        caller, callee = Phone(grid, 9, 10, 1234), Phone(grid, 14, 10, 5678)
        first.ring_phone(5678, 1234, caller)
        self.assertEqual(callee.rings, [1234])
        self.assertEqual((first.visits, second.visits), (1, 1))
        self.assertEqual(caller.rings, [])

    def test_square_loop_telegram_reaches_every_station_once(self):
        grid = Grid()
        poles = [Pole(grid, x, y) for x, y in ((10, 10), (13, 10), (13, 13), (10, 13))]
        sender = Telegraph(grid, 10, 9)
        far = Telegraph(grid, 14, 14)
        poles[0].transmit('hello', 'hello', sender, None)
        self.assertEqual(far.received, ['hello'])
        self.assertEqual(sender.received, [])
        self.assertEqual([p.visits for p in poles], [1, 1, 1, 1])

    def test_pole_stays_quiet_until_marker_expires(self):
        grid = Grid()
        pole = Pole(grid, 10, 10)
        far = Telegraph(grid, 11, 11)
        pole.transmit('one', 'one', object(), None)
        pole.transmit('two', 'two', object(), None)
        self.assertEqual(far.received, ['one'])
        World.time += 4
        try:
            pole.transmit('three', 'three', object(), None)
        finally:
            World.time -= 4
        self.assertEqual(far.received, ['one', 'three'])

    def test_marker_is_set_before_forwarding(self):
        for name in ('transmit', 'ring_phone'):
            body = extract(SOURCE, BASE + name)
            mark = body.index('lastproc = world.time+3')
            self.assertLess(mark, body.index('for (var/obj/structure/phoneline/PL'), name)
            self.assertEqual(body.count('lastproc = world.time+3'), 1, name)


if __name__ == '__main__':
    unittest.main()
