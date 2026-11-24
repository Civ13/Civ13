"""Wired pole traversal visits each pole once (issue #6234) and delivers each
telegram to each telegraph once (issue #6235).

The production transmit/ring_phone bodies run through the shared source adapter
on an inert grid. Only locate/get_turf/range/world.time are test boundaries.
"""
from pathlib import Path
import re
import sys
import unittest
from types import SimpleNamespace

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

    def collect_clinic_stations(self, *args):
        self.grid.depth_check()
        return self.grid.collect(self, *args)

    def ring_phone(self, *args):
        # Count only entries that pass the guard and forward the traversal.
        self.visits += World.time > self.lastproc
        self.grid.depth_check()
        return self.grid.ring(self, *args)


class Telegraph(Thing):
    def __init__(self, grid, x, y):
        super().__init__(grid, '/obj/structure/telegraph', x, y)
        self.received = []
        self.name = 'telegraph'

    def clinic_station_label(self):
        return self.name

    def receive(self, msg, stripmsg):
        self.received.append(msg)


class Phone(Thing):
    def __init__(self, grid, x, y, number):
        super().__init__(grid, '/obj/item/weapon/telephone', x, y)
        self.phonenumber, self.ringing, self.rings = number, False, []

    def ringproc(self, origin, originphone):
        self.ringing = True
        self.rings.append(origin)


class DMList(list):
    """DM list semantics for the projection: += adds one entry."""
    def __iadd__(self, item):
        self.append(item)
        return self


class Grid:
    def __init__(self):
        self.things, self.calls = [], 0
        env = {'world': World, 'locate': lambda x, y, z: (x, y, z),
               'get_turf': lambda turf: turf, 'range': self.range,
               'typed_iter': self.typed_iter, 'list': DMList,
               'isnull': lambda value: value is None, 'lowertext': str.lower}
        self.transmit = self.load('transmit', 'src,msg,stripmsg,TL,origin,reached=None', env)
        self.collect = self.load('collect_clinic_stations', 'src,TL,visited,reached', env)
        self.receiver = project(SOURCE, '/obj/structure/telegraph/proc/clinic_receiver',
                                'src,stations,destination', dict(env))
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

    def test_telegraph_near_two_poles_prints_once(self):
        # #6235: the receiver is in reach of both poles on an acyclic line.
        grid = Grid()
        first, second = Pole(grid, 10, 10), Pole(grid, 13, 10)
        sender = Telegraph(grid, 8, 10)
        shared = Telegraph(grid, 11, 10)
        far = Telegraph(grid, 15, 10)
        first.transmit('hello', 'hello', sender, None)
        self.assertEqual(shared.received, ['hello'])
        self.assertEqual(far.received, ['hello'])
        self.assertEqual(sender.received, [])

    def test_sender_starts_one_delivery_list(self):
        sender = extract(SOURCE, '/obj/structure/telegraph/proc/transmit')
        self.assertIn('PL.transmit(msg,stripmsg,src,PL,list())', sender)
        body = extract(SOURCE, BASE + 'transmit')
        self.assertEqual(body.count('PL.transmit(msg,stripmsg,TL,src,reached)'), 5)
        self.assertLess(body.index('reached += TLG'), body.index('TLG.receive(msg,stripmsg)'))

    def test_clinic_collection_delivers_nothing_until_one_named_receiver_is_resolved(self):
        grid = Grid()
        left, right = Pole(grid, 10, 10), Pole(grid, 13, 10)
        sender = Telegraph(grid, 8, 10)
        target = Telegraph(grid, 11, 10)  # within range of two poles
        other = Telegraph(grid, 15, 10)
        far = Telegraph(grid, 30, 10)  # no path
        target.name, other.name, far.name = 'Clinic', 'Workshop', 'Clinic'
        reached = DMList()
        left.collect_clinic_stations(sender, DMList(), reached)
        self.assertCountEqual(reached, [target, other])
        self.assertEqual([node.received for node in (sender, target, other, far)], [[], [], [], []])
        self.assertIs(grid.receiver(sender, reached, 'clinic'), target)
        self.assertIsNone(grid.receiver(sender, reached, 'invalid'))
        other.name = 'CLINIC'
        self.assertIsNone(grid.receiver(sender, reached, 'clinic'))

    def test_clinic_collection_crosses_cooldowns_and_rejects_duplicate_names(self):
        grid = Grid()
        poles = [Pole(grid, x, y) for x, y in ((10, 10), (13, 10), (13, 13), (10, 13))]
        sender = Telegraph(grid, 8, 10)
        nearby, beyond = Telegraph(grid, 10, 11), Telegraph(grid, 14, 14)
        disconnected = Telegraph(grid, 30, 30)
        nearby.name, beyond.name, disconnected.name = 'Clinic', 'CLINIC', 'Clinic'
        # An active cooldown on the route must neither hide a collision nor be changed.
        poles[1].lastproc = poles[2].lastproc = World.time + 3
        before = [pole.lastproc for pole in poles]
        reached = DMList()
        poles[0].collect_clinic_stations(sender, DMList(), reached)
        self.assertCountEqual(reached, [nearby, beyond])
        self.assertIsNone(grid.receiver(sender, reached, 'clinic'))
        self.assertEqual([pole.lastproc for pole in poles], before)
        self.assertEqual([station.received for station in (sender, nearby, beyond, disconnected)], [[], [], [], []])
        # Once the reachable collision is renamed, the disconnected duplicate is irrelevant.
        beyond.name = 'Workshop'
        reached = DMList()
        poles[0].collect_clinic_stations(sender, DMList(), reached)
        self.assertIs(grid.receiver(sender, reached, 'clinic'), nearby)
        self.assertEqual([pole.lastproc for pole in poles], before)

    def test_clinic_collection_does_not_block_subsequent_normal_traffic(self):
        grid = Grid()
        first, second = Pole(grid, 10, 10), Pole(grid, 13, 10)
        sender, target = Telegraph(grid, 8, 10), Telegraph(grid, 15, 10)
        first.collect_clinic_stations(sender, DMList(), DMList())
        first.transmit('hello', 'hello', sender, None)
        self.assertEqual(target.received, ['hello'])
        self.assertEqual((first.lastproc, second.lastproc), (World.time + 3, World.time + 3))

        other = Grid()
        first, second = Pole(other, 10, 10), Pole(other, 13, 10)
        sender = Telegraph(other, 8, 10)
        caller, callee = Phone(other, 9, 10, 1234), Phone(other, 14, 10, 5678)
        first.collect_clinic_stations(sender, DMList(), DMList())
        first.ring_phone(5678, 1234, caller)
        self.assertEqual(callee.rings, [1234])

    def test_shipment_command_has_no_default_broadcast_and_rechecks_client_after_both_prompts(self):
        verb = extract(SOURCE, '/obj/structure/telegraph/verb/confirm_clinic_shipment')
        self.assertEqual(verb.count('!clinic_operator_valid(H, operator_client, terminal)'), 3)
        self.assertLess(verb.index('clinic_receiver(stations, destination)'), verb.index('receiver.receive('))
        self.assertIn('PL.collect_clinic_stations(src, list(), stations)', verb)
        self.assertLess(verb.index('var/list/stations = list()'), verb.index('PL.collect_clinic_stations('))
        self.assertLess(verb.index('PL.collect_clinic_stations('), verb.index('clinic_receiver(stations, destination)'))
        self.assertNotIn('nomad_request(', verb)

    def run_clinic_verb(self, grid, sender, destination='Clinic', reference='72A', valid=True):
        # Project the complete verb and the operator/reference/receiver procs.
        # Only BYOND input, type, HTML, time-independent turf, and message
        # boundaries are faked. Verb metadata is not executable gameplay code.
        class Turf:
            pass

        class Human:
            def incapacitated(self):
                return not valid

        sender.loc = Turf()
        sender.loc.z = sender.z
        human = Human()
        human.loc = Turf()
        human.x, human.y, human.z = sender.x, sender.y, sender.z
        human.client = SimpleNamespace(mob=human)
        sender.name = 'Origin'
        answers = iter([destination, reference])
        messages = []
        env = {
            'range': grid.range, 'typed_iter': grid.typed_iter, 'list': DMList,
            'isnull': lambda value: value is None, 'istype': lambda value: isinstance(value, Human),
            'get_turf': lambda value: value.loc, 'isturf': lambda value: isinstance(value, Turf),
            'QDELETED': lambda value: False,
            'get_dist': lambda a, b: max(abs(a.x - b.x), abs(a.y - b.y)),
            'player_input': lambda *args: next(answers), 'sanitize': lambda value, size: value[:size],
            'lowertext': str.lower, 'html_encode': lambda value: value, 'html_decode': lambda value: value,
            'SPAN_WARNING': lambda value: value, 'SPAN_NOTICE': lambda value: value,
            'to_chat': lambda mob, message: messages.append(message),
            'istext': lambda value: isinstance(value, str), 'length': len,
            'text2ascii': lambda value, i: ord(value[i - 1]), 'ascii2text': chr,
        }
        valid_proc = project(SOURCE, '/obj/structure/telegraph/proc/clinic_operator_valid',
                             'src,H,operator_client,terminal', dict(env), method=True)
        env['clinic_operator_valid'] = lambda *args: valid_proc(sender, *args)
        env['clinic_receiver'] = lambda *args: grid.receiver(sender, *args)

        # The shared adapter does not translate DM switch/range-loop syntax;
        # rewrite those syntax constructs, retaining the production branches.
        reference_source = SOURCE.replace(
            'for (var/i = 1, i <= length(value), i++)', 'for (i in range(1, length(value)+1))').replace(
            'switch (character)\n\t\t\tif (48 to 57, 65 to 90)',
            'if ((character >= 48 && character <= 57) || (character >= 65 && character <= 90))').replace(
            '\t\t\tif (97 to 122)', '\t\telse if (character >= 97 && character <= 122)').replace(
            '\t\t\telse\n\t\t\t\treturn null', '\t\telse\n\t\t\treturn null')
        # Normalize the nested action indentation after removing switch.
        reference_source = reference_source.replace('\t\t\t\tresult +=', '\t\t\tresult +=')
        reference_env = dict(env)
        reference_env['range'] = range
        ref_proc = project(reference_source, '/obj/structure/telegraph/proc/clinic_reference',
                           'src,value', reference_env)
        env['clinic_reference'] = lambda value: ref_proc(sender, value)

        verb_source = SOURCE.replace('set src in view(1)', 'set category = null')
        verb_source = verb_source.replace('html_decode(name)', 'html_decode(src.name)')
        # Convert DM's interpolation inside quoted strings to Python f-strings.
        def interpolation(match):
            literal = match.group(0)
            if '[' not in literal:
                return literal
            return 'f' + re.sub(r'\[([^]]+)\]', r'{\1}', literal)
        verb_source = re.sub(r'"(?:[^"\\]|\\.)*"', interpolation, verb_source)
        verb = project(verb_source, '/obj/structure/telegraph/verb/confirm_clinic_shipment',
                       'src,usr', env)
        verb(sender, human)
        return messages

    def test_clinic_verb_rejects_collision_and_delivers_only_unique_station(self):
        grid = Grid()
        first, second = Pole(grid, 10, 10), Pole(grid, 13, 10)
        sender = Telegraph(grid, 8, 10)
        near, far = Telegraph(grid, 11, 10), Telegraph(grid, 15, 10)
        near.name, far.name = 'Clinic', 'CLINIC'
        second.lastproc = World.time + 3
        messages = self.run_clinic_verb(grid, sender)
        self.assertEqual((near.received, far.received), ([], []))
        self.assertTrue(any('not sent' in message for message in messages))
        far.name = 'Workshop'
        messages = self.run_clinic_verb(grid, sender)
        self.assertEqual(len(near.received), 1)
        self.assertEqual(far.received, [])
        self.assertTrue(any('reached' in message for message in messages))

    def test_clinic_verb_does_not_deliver_without_pole_or_valid_operator(self):
        grid = Grid()
        sender, target = Telegraph(grid, 8, 10), Telegraph(grid, 11, 10)
        target.name = 'Clinic'
        messages = self.run_clinic_verb(grid, sender)
        self.assertEqual(target.received, [])
        self.assertTrue(any('not sent' in message for message in messages))
        Pole(grid, 10, 10)
        self.assertEqual(self.run_clinic_verb(grid, sender, valid=False), [])
        self.assertEqual(target.received, [])

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
