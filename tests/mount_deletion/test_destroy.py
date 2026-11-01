"""Offline mount Destroy and qdel-admission evidence, not native completion."""
from itertools import product
from pathlib import Path
import re
import sys
from types import SimpleNamespace as N
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tests/save_movement'))
from source_adapter import extract, project

SOURCE = ROOT / 'code/game/mob/living/simple_animal/simple_animal.dm'
BEFORE = Path(__file__).with_name('fixtures') / 'destroy_before.txt'
DECLARATION = '/mob/living/simple_animal/Destroy'
DEFINES = (ROOT / 'code/__defines/qdel.dm').read_text()


def macro(name):
    matches = re.findall(r'^#define ' + re.escape(name) + r'\(X\) (.+)$', DEFINES, re.M)
    if len(matches) != 1:
        raise AssertionError('Expected one canonical macro: ' + name)
    return matches[0]


def qdeleted_function():
    expression = macro('QDELETED').replace('QDELING(X)', macro('QDELING'))
    expression = re.sub(r'\bX\b', 'value', expression)
    return project('/qdeleted()\n\treturn ' + expression + '\n', '/qdeleted', 'value', {})


QDELETED = qdeleted_function()


def admission_function():
    """Project complete valid/null/type/reentry guards, ending at the marker write.

    Profiling, Destroy dispatch and finalization are outside this prefix. The
    test dispatcher invokes the projected Destroy only after admission succeeds.
    """
    body = extract((ROOT / 'code/processes/garbage.dm').read_text(), '/proc/qdel')
    marker = '\tvar/profile_type = '
    if body.count(marker) != 1:
        raise AssertionError('Ambiguous qdel admission boundary')
    prefix = body.split(marker)[0]
    if not prefix.rstrip().endswith('A.gc_destroyed = GC_CURRENTLY_BEING_QDELETED'):
        raise AssertionError('Admission must finish at the retirement marker')
    prefix = prefix.replace('\t\tdel(A)', '\t\tnative_del(A)')
    value = int(re.search(r'^#define GC_CURRENTLY_BEING_QDELETED (-?\d+)$', DEFINES, re.M)[1])

    def unexpected(*_):
        raise AssertionError('Invalid-target boundary is outside this fixture')

    return project('/admit()\n' + prefix + '\treturn TRUE\n', '/admit', 'A', dict(
        istype=lambda obj: isinstance(obj, Animal), warning=unexpected,
        crash_with=unexpected, native_del=unexpected, processes=N(garbage=None),
        GC_CURRENTLY_BEING_QDELETED=value))


def label(value):
    return getattr(value, 'label', value)


class Human:
    def __init__(self, world, name, marker=0):
        object.__setattr__(self, 'world', world)
        object.__setattr__(self, 'label', name)
        object.__setattr__(self, 'gc_destroyed', marker)
        object.__setattr__(self, 'gcDestroyed', 0)
        object.__setattr__(self, 'riding', True)
        object.__setattr__(self, 'riding_mob', None)

    def __getattribute__(self, field):
        if field in ('riding', 'riding_mob') and object.__getattribute__(self, 'gc_destroyed'):
            raise AssertionError('Read from retiring mock rider')
        return object.__getattribute__(self, field)

    def __setattr__(self, field, value):
        if field in ('riding', 'riding_mob'):
            if self.gc_destroyed:
                raise AssertionError('Write to retiring mock rider')
            self.world.trace.append(('write', self.label, field, label(value)))
        object.__setattr__(self, field, value)

    def snapshot(self):
        return tuple(label(object.__getattribute__(self, field)) for field in ('riding', 'riding_mob'))


class Animal:
    def __init__(self, world, name):
        self.world, self.label = world, name
        self.gc_destroyed = self.gcDestroyed = 0
        self.rider = None
        self.ride = True

    def unregisterSpawner(self):
        self.world.trace.append(('spawner', self.world.human.snapshot()))
        if self.world.on_spawner:
            self.world.on_spawner(self.world)


class World:
    def __init__(self, text, *, present=True, link='owned', marker=0, riding=True,
                 parent_hint=None, on_spawner=None, on_parent=None):
        self.trace = []
        self.mount, self.other_mount = Animal(self, 'mount'), Animal(self, 'other-mount')
        self.human = Human(self, 'human', marker)
        self.other_human = Human(self, 'other-human')
        object.__setattr__(self.human, 'riding', riding)
        object.__setattr__(self.human, 'riding_mob', {'owned': self.mount, 'foreign': self.other_mount, 'null': None}[link])
        self.mount.rider = self.human if present else None
        if link == 'foreign':
            self.other_mount.rider = self.human
        self.on_spawner, self.on_parent = on_spawner, on_parent
        self.attempts = self.cleanups = 0

        def parent(src):
            self.trace.append(('parent', self.human.snapshot()))
            if on_parent:
                on_parent(self)
            return parent_hint

        body = extract(text, DECLARATION)
        for field in ('rider', 'unregisterSpawner'):
            body = re.sub(r'(?<![\w.])' + field + r'\b', 'src.' + field, body)
        body = body.replace('..()', 'parent(src)')
        self.cleanup = project('/cleanup()\n' + body + '\n', '/cleanup', 'src', dict(parent=parent, QDELETED=QDELETED))
        self.admit = admission_function()

    def qdel_admission_and_destroy(self):
        self.attempts += 1
        if not self.admit(self.mount):
            return None
        self.cleanups += 1
        return self.cleanup(self.mount)


class DestroyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.before, cls.after = BEFORE.read_text(), SOURCE.read_text()

    def test_matching_live_rider_detaches_before_existing_effects(self):
        before, after = World(self.before), World(self.after)
        before.qdel_admission_and_destroy()
        self.assertEqual(before.human.snapshot(), (True, 'mount'))
        self.assertIsNone(after.qdel_admission_and_destroy())
        self.assertEqual(after.human.snapshot(), (False, None))
        self.assertEqual(after.trace, [('write', 'human', 'riding', False),
            ('write', 'human', 'riding_mob', None), ('spawner', (False, None)), ('parent', (False, None))])

    def test_matching_foreign_absent_and_retiring_matrix(self):
        for present, link, marker, riding in product((False, True), ('owned', 'foreign', 'null'),
                                                    (0, -2, -1, 17), (False, True)):
            options = dict(present=present, link=link, marker=marker, riding=riding)
            with self.subTest(**options):
                old, new = World(self.before, **options), World(self.after, **options)
                old.qdel_admission_and_destroy()
                new.qdel_admission_and_destroy()
                matched = present and link == 'owned' and marker == 0
                self.assertEqual(new.human.snapshot(), (False, None) if matched else old.human.snapshot())
                self.assertEqual([row[0] for row in new.trace if row[0] != 'write'], ['spawner', 'parent'])
                self.assertTrue(new.mount.ride and new.other_mount.ride)
                self.assertIs(new.other_mount.rider, new.human if link == 'foreign' else None)

    def test_canonical_qdeleted_uses_null_or_modern_marker(self):
        self.assertTrue(QDELETED(None))
        for marker in (0, -2, -1, 17):
            rider = N(gc_destroyed=marker, gcDestroyed=0)
            self.assertEqual(bool(QDELETED(rider)), marker != 0)
        self.assertFalse(QDELETED(N(gc_destroyed=0, gcDestroyed=17)))

    def test_retiring_subject_is_not_mistaken_for_retiring_rider(self):
        world = World(self.after)
        world.qdel_admission_and_destroy()
        self.assertTrue(QDELETED(world.mount))
        self.assertFalse(QDELETED(world.human))
        self.assertEqual(world.human.snapshot(), (False, None))

    def test_parent_hint_remains_ignored(self):
        for hint in (None, 0, 1, 2, 3, 4):
            world = World(self.after, parent_hint=hint)
            self.assertIsNone(world.qdel_admission_and_destroy())
            self.assertEqual([row[0] for row in world.trace if row[0] != 'write'], ['spawner', 'parent'])

    def test_spawner_callback_reentry_is_blocked_by_source_admission(self):
        world = World(self.after, on_spawner=lambda w: w.qdel_admission_and_destroy())
        world.qdel_admission_and_destroy()
        self.assertEqual((world.attempts, world.cleanups), (2, 1))
        self.assertEqual([row[0] for row in world.trace], ['write', 'write', 'spawner', 'parent'])

    def test_parent_reentry_and_new_relation_survive(self):
        def callback(world):
            world.qdel_admission_and_destroy()
            world.human.riding_mob = world.other_mount
            world.human.riding = True
            world.other_mount.rider = world.human
        world = World(self.after, on_parent=callback)
        world.qdel_admission_and_destroy()
        self.assertEqual((world.attempts, world.cleanups), (2, 1))
        self.assertEqual(world.human.snapshot(), (True, 'other-mount'))
        self.assertIs(world.other_mount.rider, world.human)

    def test_spawner_callback_slot_replacement_has_no_late_writes(self):
        def callback(world):
            world.mount.rider = world.other_human
            world.other_human.riding_mob = world.other_mount
            world.other_mount.rider = world.other_human
        world = World(self.after, on_spawner=callback)
        world.qdel_admission_and_destroy()
        self.assertEqual(world.human.snapshot(), (False, None))
        self.assertEqual(world.other_human.snapshot(), (True, 'other-mount'))
        self.assertIs(world.mount.rider, world.other_human)
        self.assertIs(world.other_mount.rider, world.other_human)

    def test_direct_repeat_has_no_additional_rider_writes(self):
        world = World(self.after)
        world.qdel_admission_and_destroy()
        first = [row for row in world.trace if row[0] == 'write']
        world.cleanup(world.mount)  # Deliberately bypass admission: no GC claim.
        self.assertEqual([row for row in world.trace if row[0] == 'write'], first)
        self.assertEqual([row[0] for row in world.trace if row[0] != 'write'], ['spawner', 'parent', 'spawner', 'parent'])

    def test_mutation_controls_cover_omission_identity_retirement_and_subject(self):
        world = World(self.before)
        world.qdel_admission_and_destroy()
        self.assertEqual(world.human.snapshot(), (True, 'mount'))
        unbound = self.after.replace(' && rider.riding_mob == src', '')
        world = World(unbound, link='foreign')
        world.qdel_admission_and_destroy()
        self.assertEqual(world.human.snapshot(), (False, None))
        wrong_subject = self.after.replace('!QDELETED(rider)', '!QDELETED(src)')
        world = World(wrong_subject)
        world.qdel_admission_and_destroy()
        self.assertEqual(world.human.snapshot(), (True, 'mount'))
        no_retirement = self.after.replace('!QDELETED(rider) && ', '')
        with self.assertRaisesRegex(AssertionError, 'retiring mock rider'):
            World(no_retirement, marker=-2).qdel_admission_and_destroy()


if __name__ == '__main__':
    unittest.main()
