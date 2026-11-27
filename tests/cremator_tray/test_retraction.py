"""Project mortuary tray interactions using fake engine objects."""
import sys
import unittest
from pathlib import Path
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tests' / 'save_movement'))
import source_adapter


def close_tray():
    source = (ROOT / 'code/game/objects/structures/morgue.dm').read_text()
    start = source.index('\tif ((src.connected) && (src.locked == FALSE))',
                         source.index('/obj/structure/cremator/attack_hand('))
    end = source.index('\telse if (src.locked == FALSE)', start)
    branch = source[start:end].replace(
        'for (var/atom/movable/A as mob|obj in src.connected.loc)',
        'for (A in src.connected.loc)')
    lines = []
    for line in branch.splitlines():
        if line.lstrip().startswith('playsound('):
            line = line[:len(line) - len(line.lstrip('\t'))] + 'sound()'
        lines.append(line)
    fixture = '/cremator/close()\n' + '\n'.join(lines) + '\n'
    old = source_adapter.FIELDS
    try:
        source_adapter.FIELDS += ('connected',)
        return source_adapter.project(fixture, '/cremator/close', 'src',
                                      {'qdel': delete_tray, 'sound': lambda: None}, method=True)
    finally:
        source_adapter.FIELDS = old


def delete_tray(tray):
    if tray is None:
        return
    tray.deleted = True
    if tray.connected and tray.connected.connected is tray:
        tray.connected.connected = None
    tray.connected = None


class CrematorTrayTests(unittest.TestCase):
    def test_retraction_moves_contents_and_deletes_the_same_tray(self):
        cremator = SimpleNamespace(connected=None, locked=False, loc='cremator tile')
        patient = SimpleNamespace(anchored=False, forceMove=lambda target: moved.append(target))
        anchored = SimpleNamespace(anchored=True, forceMove=lambda target: self.fail('anchored item moved'))
        tray = SimpleNamespace(loc=[patient, anchored], connected=cremator, deleted=False)
        cremator.connected = tray
        moved = []
        close_tray()(cremator)
        self.assertEqual(moved, [cremator])
        self.assertTrue(tray.deleted)
        self.assertIsNone(tray.connected)
        self.assertIsNone(cremator.connected)

    def test_locked_cremator_keeps_tray(self):
        cremator = SimpleNamespace(connected=SimpleNamespace(deleted=False), locked=True)
        tray = cremator.connected
        close_tray()(cremator)
        self.assertIs(cremator.connected, tray)
        self.assertFalse(tray.deleted)


class TrayDropTests(unittest.TestCase):
    def setUp(self):
        source = (ROOT / 'code/game/objects/structures/morgue.dm').read_text(encoding='utf-8-sig')
        declaration = '/proc/can_load_mortuary_tray'
        guard = source_adapter.extract(source, declaration)
        for path in ('/atom/movable', '/obj/structure/closet/body_bag'):
            guard = guard.replace(f', {path})', f', "{path}")')
        fixture = f'{declaration}()\n{guard}\n'
        self.movable = '/atom/movable'
        self.bag = '/obj/structure/closet/body_bag'
        self.env = {
            'ismob': lambda atom: 'mob' in atom.dm_types,
            'istype': lambda atom, path: path in atom.dm_types,
            'get_dist': lambda _user, atom: atom.distance,
        }
        self.env['can_load_mortuary_tray'] = source_adapter.project(
            fixture, declaration, 'tray, target, user', self.env.copy())
        self.source = source

    def drop(self, tray_type, *, target_types=None, reject=None):
        class Contents(list):
            def Find(self, atom):
                return any(item is atom for item in self)

        class Viewer(SimpleNamespace):
            def __lshift__(self, message):
                deliveries.append((self, message))

        moves = []
        deliveries = []
        user = SimpleNamespace(dm_types=('mob', self.movable), stat=False, lying=False, stunned=False,
                               contents=Contents(), anchored=False, distance=0, forceMove=moves.append)
        target = SimpleNamespace(dm_types=target_types, anchored=False, distance=1, forceMove=moves.append)
        tray = SimpleNamespace(loc=object(), distance=1)
        viewer = Viewer(client=True, blinded=False)
        observers = (viewer, Viewer(client=True, blinded=True), Viewer(client=False, blinded=False))
        if target_types is None:
            target = user
        if reject == 'held_tray':
            user.contents.append(tray)
        elif reject == 'held_target':
            user.contents.append(target)
        elif reject:
            subject, field, value = reject
            setattr({'target': target, 'user': user, 'tray': tray}[subject], field, value)

        env = dict(self.env, typed_iter=lambda atoms, _path: atoms,
                   viewers=lambda _user, _radius: observers,
                   to_chat=lambda recipient, message: deliveries.append((recipient, message)),
                   text=lambda pattern, *values: (pattern, *values))
        proc = source_adapter.project(self.source, f'/obj/structure/{tray_type}/MouseDrop_T',
                                      'src, O, user', env, method=True)
        proc(tray, target, user)
        return tray.loc, viewer, moves, deliveries

    def test_both_trays_move_bodies_and_body_bags_and_notify_visible_players(self):
        for tray_type in ('m_tray', 'c_tray'):
            for target_types in (('mob', self.movable), (self.bag, self.movable), None):
                with self.subTest(tray=tray_type, target_types=target_types):
                    destination, viewer, moves, deliveries = self.drop(tray_type, target_types=target_types)
                    self.assertEqual(moves, [destination])
                    self.assertEqual([recipient for recipient, _ in deliveries], [] if target_types is None else [viewer])

    def test_both_trays_reject_invalid_drops_without_moving_or_notifying(self):
        invalid = (
            ('target', 'dm_types', ()),
            ('target', 'dm_types', (self.movable,)),
            ('target', 'anchored', True),
            ('target', 'distance', 2),
            ('tray', 'distance', 2),
            'held_tray',
            'held_target',
            ('user', 'dm_types', ()),
            ('user', 'stat', True),
            ('user', 'lying', True),
            ('user', 'stunned', True),
        )
        for tray_type in ('m_tray', 'c_tray'):
            for reject in invalid:
                with self.subTest(tray=tray_type, reject=reject):
                    _, _, moves, deliveries = self.drop(tray_type, target_types=(self.bag, self.movable),
                                                       reject=reject)
                    self.assertEqual(moves, [])
                    self.assertEqual(deliveries, [])


if __name__ == '__main__':
    unittest.main()
