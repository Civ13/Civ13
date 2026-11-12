"""Source-projected landing craft lever with fake engine boundaries.

Delayed spawn() blocks run inline through the adapter's deferred() boundary;
each test chooses which delays fire and can start a newer trip first.
"""
from pathlib import Path
from types import SimpleNamespace
import re
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'save_movement'))
from source_adapter import extract, project, read

LEVER = 'code/modules/1713/transporter/lever.dm'
DECLARATION = '/obj/structure/transport_lever/attack_hand'
FIELDS = ('next_activation', 'trip_id', 'position', 'icon_state', 'none_state', 'pushed_state',
          'depart_sound', 'cancel_save_transfer', 'gcDestroyed', 'gc_destroyed', 'persistence_set_z',
          'visible_message', 'z')


def qualify(body):
    pieces = re.split(r'("(?:[^"\\]|\\.)*")', body)
    for i in range(0, len(pieces), 2):
        piece = pieces[i].replace('/obj/structure/transport_lever', 'LEVER_TYPE')
        for name in FIELDS:
            piece = re.sub(r'(?<![\w./])' + name + r'\b', 'src.' + name, piece)
        piece = re.sub(r'(\d+) SECONDS\b', r'(\1 * SECONDS)', piece)
        piece = piece.replace('spawn (', 'spawn(')
        pieces[i] = piece
    return ''.join(pieces)


class Thing(SimpleNamespace):
    def persistence_set_z(self, z):
        self.z = z
        return True


class Lever(Thing):
    pass


def lever_at(now, next_activation=-1, position='docked'):
    lever = Lever(next_activation=next_activation, trip_id=0, position=position, icon_state='lever_none',
                  none_state='lever_none', pushed_state='lever_pulled', depart_sound='sound', z=2,
                  gcDestroyed=None, gc_destroyed=None, anchored=True, kind='lever', messages=[])
    lever.visible_message = lambda text: lever.messages.append(text)
    lever.cancel_save_transfer = lambda previous: False
    return lever


def run(lever, now, nearby=(), fire=lambda delay, lever: False, text=None):
    env = {'world': SimpleNamespace(time=now), 'LEVER_TYPE': 'lever', 'SECONDS': 10}
    env['persistence_save_active'] = lambda: False
    env['typed_iter'] = lambda items, path: [i for i in items if path.startswith('/mob') == hasattr(i, 'mob')]
    env['range'] = lambda dist, centre: list(nearby) + [lever]
    env['istype'] = lambda obj, kind: getattr(obj, 'kind', None) == kind
    env['get_turf'] = lambda obj: None
    env['get_dist'] = lambda a, b: 0
    env['deferred'] = lambda delay: fire(delay, lever)
    source = DECLARATION + '(var/mob/user as mob)\n' + qualify(extract(text or read(LEVER), DECLARATION))
    project(source, DECLARATION, 'src, user', env)(lever, None)
    return lever


class LandingCraftLever(unittest.TestCase):
    def test_rejected_press_keeps_the_deadline(self):
        lever = run(lever_at(100, next_activation=400), 100)
        self.assertEqual(lever.next_activation, 400)
        self.assertEqual(lever.trip_id, 0)

    def test_ready_press_starts_a_trip_with_full_cooldown(self):
        lever = run(lever_at(500), 500)
        self.assertEqual(lever.next_activation, 900)
        self.assertEqual(lever.trip_id, 1)
        self.assertEqual(lever.position, 'launched')

    def test_first_departure_leaves_anchored_fixtures(self):
        sign = Thing(z=2, anchored=True, kind='sign')
        crate = Thing(z=2, anchored=False, kind='crate')
        lever = run(lever_at(500), 500, nearby=(sign, crate), fire=lambda delay, _: delay == 200)
        self.assertEqual((sign.z, crate.z, lever.z), (2, 1, 1))

    def test_stale_return_is_ignored_after_a_newer_trip(self):
        crate = Thing(z=2, anchored=False, kind='crate')
        def fire(delay, lever):
            if delay == 400:
                lever.trip_id += 1  # a newer departure happened before this return
            return delay in (200, 400)
        lever = run(lever_at(500), 500, nearby=(crate,), fire=fire)
        # The transfer moved the craft to z1; the stale return must not move it back.
        self.assertEqual((crate.z, lever.z), (1, 1))
        self.assertFalse(any('is returning' in text for text in lever.messages))

    def test_current_return_still_runs(self):
        crate = Thing(z=2, anchored=False, kind='crate')
        lever = run(lever_at(500), 500, nearby=(crate,), fire=lambda delay, _: delay in (200, 400))
        self.assertEqual((crate.z, lever.z), (2, 2))
        self.assertTrue(any('is returning' in text for text in lever.messages))

    def test_negative_control_old_source(self):
        source = read(LEVER)
        old = source.replace('\t\t// A rejected press keeps the existing deadline.\n',
                             '\t\tnext_activation = world.time + 5 SECONDS\n')
        old = re.sub(r'(?m)^\t+if \(trip_id != this_trip\) return FALSE\n', '', old)
        self.assertNotEqual(old, source)
        lever = run(lever_at(100, next_activation=400), 100, text=old)
        self.assertEqual(lever.next_activation, 150)
        crate = Thing(z=2, anchored=False, kind='crate')
        def fire(delay, lever):
            if delay == 400:
                lever.trip_id += 1
            return delay in (200, 400)
        lever = run(lever_at(500), 500, nearby=(crate,), fire=fire, text=old)
        self.assertEqual(lever.z, 2)  # the stale return moved the craft back


if __name__ == '__main__':
    unittest.main()
