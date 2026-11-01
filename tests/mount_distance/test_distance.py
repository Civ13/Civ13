"""Offline complete-branch distance cleanup with inert range/movement/icons."""
from itertools import product
from pathlib import Path
import re
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tests/save_movement'))
from source_adapter import project

SOURCE = ROOT / 'code/game/mob/living/carbon/human/human_life.dm'
BEFORE = Path(__file__).with_name('fixtures') / 'distance_before.txt'
HEADER = '\tif (riding && riding_mob)'


def branch(text):
    """Select the entire uniquely anchored Life branch, including nested guards."""
    lines = text.splitlines()
    matches = [index for index, line in enumerate(lines) if line == HEADER]
    if len(matches) != 1:
        raise AssertionError('Expected exactly one complete riding distance branch')
    result = [HEADER]
    for line in lines[matches[0] + 1:]:
        if line.strip() and len(line) - len(line.lstrip('\t')) <= 1:
            break
        result.append(line)
    return '\n'.join(result).rstrip()


def label(value):
    return getattr(value, 'label', value)


class Human:
    def __init__(self, world, name):
        object.__setattr__(self, 'world', world)
        object.__setattr__(self, 'label', name)
        object.__setattr__(self, 'riding', False)
        object.__setattr__(self, 'riding_mob', None)
        object.__setattr__(self, 'loc', 'same-current-location')

    def __setattr__(self, name, value):
        if name in ('riding', 'riding_mob'):
            self.world.trace.append(('write', self.label, name, label(value)))
        object.__setattr__(self, name, value)

    def forceMove(self, destination):
        self.world.trace.append(('forceMove', self.label, destination, self.riding, label(self.riding_mob)))
        if self.world.on_move:
            self.world.on_move(self.world)
        return self.world.move_result


class Animal:
    def __init__(self, world, name):
        object.__setattr__(self, 'world', world)
        object.__setattr__(self, 'label', name)
        object.__setattr__(self, 'gc_destroyed', False)
        object.__setattr__(self, 'ride', True)
        object.__setattr__(self, 'rider', None)
        object.__setattr__(self, 'stop_automated_movement', True)

    def __getattribute__(self, name):
        if name in ('ride', 'rider', 'stop_automated_movement') and object.__getattribute__(self, 'gc_destroyed'):
            raise AssertionError('Source read a retired mock animal')
        return object.__getattribute__(self, name)

    def __setattr__(self, name, value):
        if name in ('ride', 'rider', 'stop_automated_movement'):
            if self.gc_destroyed:
                raise AssertionError('Source wrote a retired mock animal')
            self.world.trace.append(('write', self.label, name, label(value)))
        object.__setattr__(self, name, value)

    def update_icons(self):
        self.world.trace.append(('icons', self.label, self.ride, label(self.rider)))
        if self.world.on_icons:
            self.world.on_icons(self.world)

    def snapshot(self):
        return tuple(label(object.__getattribute__(self, field)) for field in (
            'gc_destroyed', 'ride', 'rider', 'stop_automated_movement'))


class World:
    def __init__(self, text, *, riding=True, present=True, nearby=False, owner='human',
                 retired=False, on_move=None, on_icons=None, move_result=False):
        self.trace = []
        self.human, self.other = Human(self, 'human'), Human(self, 'other')
        self.old, self.new = Animal(self, 'old'), Animal(self, 'new')
        object.__setattr__(self.human, 'riding', riding)
        object.__setattr__(self.human, 'riding_mob', self.old if present else None)
        object.__setattr__(self.old, 'rider', {'human': self.human, 'other': self.other, 'null': None}[owner])
        object.__setattr__(self.old, 'gc_destroyed', retired)
        self.on_move, self.on_icons, self.move_result = on_move, on_icons, move_result
        self.ranges = []

        def nearby_range(distance, actor):
            self.ranges.append((distance, actor.label))
            return [self.old] if nearby else []

        body = branch(text)
        for field in ('riding', 'riding_mob', 'forceMove'):
            body = re.sub(r'(?<![\w.])' + field + r'\b', 'src.' + field, body)
        self.invoke = project('/distance()\n' + body + '\n', '/distance', 'src', dict(
            range=nearby_range, QDELETED=lambda animal: animal is None or animal.gc_destroyed,
            isnull=lambda value: value is None))

    def run(self):
        return self.invoke(self.human)

    def snapshot(self):
        return self.human.riding, label(self.human.riding_mob), self.old.snapshot(), self.new.snapshot()


def attach(human, animal):
    human.riding = True
    human.riding_mob = animal
    animal.ride = True
    animal.rider = human
    animal.stop_automated_movement = True


class DistanceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.before = BEFORE.read_text()
        cls.after = SOURCE.read_text()

    def test_separation_releases_captured_mount_and_preserves_effect_order(self):
        old, new = World(self.before), World(self.after)
        old.run()
        self.assertEqual(old.old.snapshot(), (False, True, 'human', True))
        new.run()
        self.assertEqual(new.snapshot(), (False, None, (False, False, None, False), (False, True, None, True)))
        self.assertEqual(new.trace, [
            ('write', 'human', 'riding', False), ('write', 'human', 'riding_mob', None),
            ('forceMove', 'human', 'same-current-location', False, None),
            ('write', 'old', 'ride', False), ('write', 'old', 'rider', None),
            ('icons', 'old', False, None), ('write', 'old', 'stop_automated_movement', False)])

    def test_admission_owner_and_retirement_matrix(self):
        for riding, present, nearby, owner, retired in product(
                (False, True), (False, True), (False, True), ('human', 'other', 'null'), (False, True)):
            options = dict(riding=riding, present=present, nearby=nearby, owner=owner, retired=retired)
            with self.subTest(**options):
                old, new = World(self.before, **options), World(self.after, **options)
                self.assertIsNone(old.run())
                self.assertIsNone(new.run())
                admitted = riding and present and not nearby
                released = admitted and owner == 'human' and not retired
                self.assertEqual(new.snapshot()[:2], old.snapshot()[:2])
                self.assertEqual(new.new.snapshot(), old.new.snapshot())
                self.assertEqual(new.old.snapshot(), (False, False, None, False) if released else old.old.snapshot())
                self.assertEqual(new.ranges, old.ranges)
                self.assertEqual(sum(row[0] == 'forceMove' for row in new.trace), int(admitted))
                self.assertEqual(sum(row[0] == 'icons' for row in new.trace), int(released))

    def test_force_move_reassignment_preserves_new_mount(self):
        callback = lambda w: attach(w.human, w.new)
        before, after = World(self.before, on_move=callback), World(self.after, on_move=callback)
        before.run()
        self.assertFalse(before.new.ride)  # Frozen code follows the new pointer.
        after.run()
        self.assertIs(after.human.riding_mob, after.new)
        self.assertTrue(after.human.riding)
        self.assertIs(after.new.rider, after.human)
        self.assertTrue(after.new.ride and after.new.stop_automated_movement)
        self.assertEqual(after.old.snapshot(), (False, False, None, False))

    def test_force_move_reattachment_to_same_mount_is_preserved(self):
        world = World(self.after, on_move=lambda w: attach(w.human, w.old))
        world.run()
        self.assertEqual(world.snapshot()[:3], (True, 'old', (False, True, 'human', True)))
        self.assertFalse(any(row[0] == 'icons' for row in world.trace))

    def test_force_move_foreign_owner_and_retirement_are_preserved(self):
        for callback in (lambda w: attach(w.other, w.old),
                         lambda w: object.__setattr__(w.old, 'gc_destroyed', True)):
            world = World(self.after, on_move=callback)
            world.run()
            self.assertFalse(any(row[0] == 'icons' for row in world.trace))
            self.assertFalse(any(row[:3] == ('write', 'old', 'stop_automated_movement') and row[3] is False for row in world.trace))

    def test_icon_reassignment_retirement_or_partial_claim_does_not_resume_ai(self):
        callbacks = (lambda w: attach(w.human, w.old), lambda w: attach(w.other, w.old),
            lambda w: object.__setattr__(w.old, 'gc_destroyed', True),
            lambda w: setattr(w.old, 'ride', True),
            lambda w: setattr(w.human, 'riding_mob', w.old))
        for callback in callbacks:
            with self.subTest(callback=callback):
                world = World(self.after, on_icons=callback)
                world.run()
                self.assertTrue(object.__getattribute__(world.old, 'stop_automated_movement'))
                self.assertEqual(sum(row[0] == 'icons' for row in world.trace), 1)

    def test_force_move_result_does_not_change_cleanup(self):
        for result in (False, True):
            world = World(self.after, move_result=result)
            self.assertIsNone(world.run())
            self.assertEqual(world.old.snapshot(), (False, False, None, False))

    def test_icon_transfer_to_other_mount_releases_old_and_keeps_new(self):
        world = World(self.after, on_icons=lambda w: attach(w.human, w.new))
        world.run()
        self.assertEqual(world.snapshot(), (True, 'new', (False, False, None, False), (False, True, 'human', True)))

    def test_negative_controls_cover_owner_reattachment_retirement_and_icon_boundary(self):
        foreign = self.after.replace(' && old_mount.rider == src', '')
        world = World(foreign, owner='other')
        world.run()
        self.assertEqual(world.old.snapshot(), (False, False, None, False))
        reattached = self.after.replace(' && riding_mob != old_mount', '')
        world = World(reattached, on_move=lambda w: attach(w.human, w.old))
        world.run()
        self.assertFalse(world.old.ride)
        no_retirement = self.after.replace('!QDELETED(old_mount) && ', '')
        with self.assertRaisesRegex(AssertionError, 'retired mock animal'):
            World(no_retirement, on_move=lambda w: object.__setattr__(w.old, 'gc_destroyed', True)).run()
        post_guard = 'if (!QDELETED(old_mount) && !old_mount.ride && isnull(old_mount.rider) && riding_mob != old_mount)'
        no_recheck = self.after.replace(post_guard, 'if (TRUE)')
        world = World(no_recheck, on_icons=lambda w: attach(w.other, w.old))
        world.run()
        self.assertFalse(world.old.stop_automated_movement)


if __name__ == '__main__':
    unittest.main()
