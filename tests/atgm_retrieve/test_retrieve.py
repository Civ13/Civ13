"""Source-projected foldable ATGM retrieval with fake engine boundaries."""
from pathlib import Path
from types import SimpleNamespace
import re
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'save_movement'))
from source_adapter import extract, project, read

MG = 'code/modules/1713/weapons/guns/mg/stationary/mg.dm'
BASE = '/obj/item/weapon/gun/projectile/automatic/stationary/atgm/foldable'


def qualify(body, names):
    # Member names become explicit fake-object fields; strings stay untouched.
    pieces = re.split(r'("(?:[^"\\]|\\.)*")', body)
    for i in range(0, len(pieces), 2):
        for name in names:
            pieces[i] = re.sub(r'(?<![\w.])' + name + r'\b', 'src.' + name, pieces[i])
    return ''.join(pieces)


class DMList(list):
    def __isub__(self, item):
        if item in self:
            self.remove(item)
        return self


class Launcher:
    def __init__(self):
        self.retrieving = False
        self.rocket = SimpleNamespace(loc='launcher')
        self.rockets = DMList([self.rocket])
        self.path = 'folded'
        self.deleted = False


def build(source, user, launcher, adjacent_after_wait=True, wait_ok=True):
    env = {'src': launcher, 'usr': user, 'events': []}
    env['ishuman'] = lambda mob: mob.human
    env['QDELETED'] = lambda obj: obj.deleted
    env['SPAN_WARNING'] = lambda text: text
    env['to_chat'] = lambda mob, text: env['events'].append('chat')
    env['visible_message'] = lambda text: None
    env['get_turf'] = lambda obj: 'turf'
    env['typed_iter'] = lambda items, path: list(items)
    def qdel(obj):
        obj.deleted = True
    env['qdel'] = qdel
    env['new_item'] = lambda path: path
    def do_after(mob, delay, target):
        env['events'].append('wait')
        mob.adjacent = adjacent_after_wait
        return wait_ok
    env['do_after'] = do_after
    names = ('retrieving', 'rockets', 'path', 'can_retrieve')
    can = project(qualify(extract(source, BASE + '/proc/can_retrieve'), names).join(
        [BASE + '/proc/can_retrieve(mob/user)\n', '']), BASE + '/proc/can_retrieve', 'user', env)
    launcher.can_retrieve = can
    verb = qualify(extract(source, BASE + '/verb/retrieve'), names).replace('new src.path', 'new_item(src.path)')
    verb = verb.replace('\tset src in range(1)\n', '')  # verb reach metadata, not a runtime check
    retrieve = project(BASE + '/verb/retrieve()\n' + verb, BASE + '/verb/retrieve', '', env)
    alt = project(qualify(extract(source, BASE + '/AltClick'), names).join(
        [BASE + '/AltClick(mob/living/human/user)\n', '']), BASE + '/AltClick', 'user', dict(env, retrieve=retrieve))
    return alt, retrieve, env


def human(adjacent=True):
    user = SimpleNamespace(human=True, adjacent=adjacent, l_hand=None, r_hand=None, received=[])
    user.incapacitated = lambda: False
    user.Adjacent = lambda target: user.adjacent
    user.face_atom = lambda target: None
    user.put_in_any_hand_if_possible = lambda item, prioritize_active_hand: user.received.append(item)
    return user


class AtgmRetrieve(unittest.TestCase):
    def test_adjacent_alt_click_retrieves(self):
        user, launcher = human(), Launcher()
        alt, _, _ = build(read(MG), user, launcher)
        alt(user)
        self.assertTrue(launcher.deleted)
        self.assertEqual(user.received, ['folded'])
        self.assertEqual(launcher.rocket.loc, 'turf')
        self.assertFalse(launcher.retrieving)

    def test_remote_alt_click_does_nothing(self):
        user, launcher = human(adjacent=False), Launcher()
        alt, _, env = build(read(MG), user, launcher)
        alt(user)
        self.assertFalse(launcher.deleted)
        self.assertEqual(user.received, [])
        self.assertNotIn('wait', env['events'])

    def test_leaving_during_wait_keeps_launcher(self):
        user, launcher = human(), Launcher()
        alt, _, _ = build(read(MG), user, launcher, adjacent_after_wait=False)
        alt(user)
        self.assertFalse(launcher.deleted)
        self.assertEqual(user.received, [])
        self.assertEqual(launcher.rockets, [launcher.rocket])
        self.assertEqual(launcher.rocket.loc, 'launcher')
        self.assertFalse(launcher.retrieving)

    def test_concurrent_retrieval_is_refused(self):
        user, launcher = human(), Launcher()
        launcher.retrieving = True
        _, retrieve, env = build(read(MG), user, launcher)
        retrieve()
        self.assertFalse(launcher.deleted)
        self.assertNotIn('wait', env['events'])

    def test_negative_control_old_alt_click_reaches_from_range(self):
        old = read(MG).replace('\tif(!can_retrieve(user))\n\t\treturn\n\tretrieve()',
                               '\tif(!ishuman(user))\n\t\treturn\n\tretrieve()')
        old = old.replace('\tif (retrieving || !can_retrieve(usr))\n\t\treturn\n', '')
        old = old.replace('do_after(usr, 30, get_turf(usr)) && can_retrieve(usr)', 'do_after(usr, 30, get_turf(usr))')
        self.assertNotEqual(old, read(MG))
        user, launcher = human(adjacent=False), Launcher()
        alt, _, _ = build(old, user, launcher)
        alt(user)
        self.assertTrue(launcher.deleted)


if __name__ == '__main__':
    unittest.main()
