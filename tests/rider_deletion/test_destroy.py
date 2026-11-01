"""Source-derived rider cleanup and admission evidence; no native finalization."""
from itertools import product
from pathlib import Path
import re
import sys
from types import SimpleNamespace as N
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tests/save_movement'))
from source_adapter import extract, project

SOURCE = ROOT / 'code/game/mob/living/carbon/human/human.dm'
CARBON = ROOT / 'code/game/mob/living/carbon/carbon.dm'
BEFORE = Path(__file__).with_name('fixtures') / 'destroy_before.txt'
DECLARATION = '/mob/living/human/Destroy'
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
    """Only the actual qdel valid-target/reentry prefix through its marker write."""
    body = extract((ROOT / 'code/processes/garbage.dm').read_text(), '/proc/qdel')
    boundary = '\tvar/profile_type = '
    if body.count(boundary) != 1:
        raise AssertionError('Ambiguous admission boundary')
    prefix = body.split(boundary)[0]
    if not prefix.rstrip().endswith('A.gc_destroyed = GC_CURRENTLY_BEING_QDELETED'):
        raise AssertionError('Admission must finish at the retirement marker')
    prefix = prefix.replace('\t\tdel(A)', '\t\tnative_del(A)')
    marker = int(re.search(r'^#define GC_CURRENTLY_BEING_QDELETED (-?\d+)$', DEFINES, re.M)[1])

    def unexpected(*_):
        raise AssertionError('Invalid-target boundary is outside this fixture')

    return project('/admit()\n' + prefix + '\treturn TRUE\n', '/admit', 'A', dict(
        istype=lambda obj: isinstance(obj, Human), warning=unexpected,
        crash_with=unexpected, native_del=unexpected, processes=N(garbage=None),
        GC_CURRENTLY_BEING_QDELETED=marker))


def label(value):
    return getattr(value, 'label', value)


class Members(list):
    """Inert global-list boundary; DM -= removes the last matching member."""
    def __init__(self, world, name, values):
        super().__init__(values)
        self.world, self.name = world, name

    def __isub__(self, value):
        self.world.trace.append(('remove', self.name, label(value)))
        for index in range(len(self) - 1, -1, -1):
            if self[index] is value:
                self.pop(index)
                break
        return self


class Human:
    def __init__(self, world, name):
        object.__setattr__(self, 'world', world)
        object.__setattr__(self, 'label', name)
        self.gc_destroyed = self.gcDestroyed = 0
        object.__setattr__(self, 'riding', True)
        object.__setattr__(self, 'riding_mob', None)
        self.organs = ['external-a', 'external-b']
        self.ingested, self.touching = 'ingested', 'touching'
        self.internal_organs, self.stomach_contents = ['internal'], ['food']

    def __setattr__(self, field, value):
        if field in ('riding', 'riding_mob'):
            self.world.trace.append(('write', self.label, field, label(value)))
        object.__setattr__(self, field, value)

    def snapshot(self):
        return (self.riding, label(self.riding_mob))

    def cancel_exercise(self):
        self.world.effect('exercise')

    def unregister_corpse_decay(self):
        self.world.effect('corpse')


class Animal:
    FIELDS = ('ride', 'rider', 'stop_automated_movement')

    def __init__(self, world, name, marker=0, ride=True, stop=True):
        object.__setattr__(self, 'world', world)
        object.__setattr__(self, 'label', name)
        self.gc_destroyed, self.gcDestroyed = marker, 0
        for key, value in zip(self.FIELDS, (ride, None, stop)):
            object.__setattr__(self, key, value)

    def __getattribute__(self, field):
        if field in Animal.FIELDS and object.__getattribute__(self, 'gc_destroyed'):
            raise AssertionError('Read from retiring mock mount')
        return object.__getattribute__(self, field)

    def __setattr__(self, field, value):
        if field in self.FIELDS:
            if self.gc_destroyed:
                raise AssertionError('Write to retiring mock mount')
            self.world.trace.append(('write', self.label, field, label(value)))
        object.__setattr__(self, field, value)

    def snapshot(self):
        # Observation bypasses the guard; projected production accesses do not.
        return tuple(label(object.__getattribute__(self, key)) for key in self.FIELDS)

    def update_icons(self):
        if self.gc_destroyed:
            raise AssertionError('Icon call on retiring mock mount')
        self.world.effect('icons')


def projected_layer(text, parent, world):
    body = extract(text, DECLARATION)
    for field in ('riding_mob', 'riding', 'cancel_exercise', 'unregister_corpse_decay',
                  'organs', 'ingested', 'touching', 'internal_organs', 'stomach_contents'):
        body = re.sub(r'(?<![\w.])' + field + r'\b', 'src.' + field, body)
    for field in ('human_mob_list', 'human_clients_mob_list'):
        body = re.sub(r'(?<![\w.])' + field + r'\b', 'state.' + field, body)
    body = body.replace('..()', 'parent(src)')
    return project('/cleanup()\n' + body + '\n', '/cleanup', 'src', dict(
        parent=parent, state=world, qdel=world.delete_effect, QDELETED=QDELETED))


class World:
    def __init__(self, text, *, present=True, owner='self', marker=0, riding=True,
                 ride=True, stop=True, parent_hint=None, callbacks=None):
        self.trace, self.callbacks = [], callbacks or {}
        self.human, self.other_human = Human(self, 'human'), Human(self, 'other-human')
        self.mount = Animal(self, 'mount', marker, ride, stop)
        self.other_mount = Animal(self, 'other-mount')
        object.__setattr__(self.mount, 'rider', {'self': self.human, 'foreign': self.other_human, 'null': None}[owner])
        if owner == 'foreign':
            object.__setattr__(self.other_human, 'riding_mob', self.mount)
        object.__setattr__(self.human, 'riding_mob', self.mount if present else None)
        object.__setattr__(self.human, 'riding', riding)
        self.human_mob_list = Members(self, 'humans', [self.human, self.other_human, self.human])
        self.human_clients_mob_list = Members(self, 'clients', [self.other_human, self.human])
        self.attempts = self.cleanups = 0

        def parent(src):
            self.effect('parent')
            return parent_hint

        carbon = projected_layer(CARBON.read_text(), parent, self)
        self.cleanup = projected_layer(text, carbon, self)
        self.admit = admission_function()

    def effect(self, name):
        self.trace.append((name, self.human.snapshot(), self.mount.snapshot()))
        if name in self.callbacks:
            self.callbacks[name](self)

    def delete_effect(self, target):
        self.effect('qdel-' + target)

    def qdel_admission_and_destroy(self):
        self.attempts += 1
        if not self.admit(self.human):
            return None
        self.cleanups += 1
        return self.cleanup(self.human)


EFFECTS = ['exercise', 'corpse', 'remove', 'remove', 'qdel-external-a',
           'qdel-external-b', 'qdel-ingested', 'qdel-touching', 'qdel-internal', 'qdel-food', 'parent']


class RiderDestroyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.before, cls.after = BEFORE.read_text(), SOURCE.read_text()

    def test_matching_cleanup_precedes_icons_and_all_existing_effects(self):
        old, new = World(self.before), World(self.after)
        old.qdel_admission_and_destroy()
        new.qdel_admission_and_destroy()
        self.assertEqual(old.mount.snapshot(), (True, 'human', True))
        self.assertEqual(new.human.snapshot(), (False, None))
        self.assertEqual(new.mount.snapshot(), (False, None, False))
        self.assertEqual(new.trace[:6], [('write', 'human', 'riding', False),
            ('write', 'human', 'riding_mob', None), ('write', 'mount', 'ride', False),
            ('write', 'mount', 'rider', None), ('write', 'mount', 'stop_automated_movement', False),
            ('icons', (False, None), (False, None, False))])
        self.assertEqual([row[0] for row in new.trace if row[0] not in ('write', 'icons')], EFFECTS)
        self.assertEqual(list(new.human_mob_list), [new.human, new.other_human])
        self.assertEqual(list(new.human_clients_mob_list), [new.other_human])

    def test_192_case_presence_ownership_retirement_and_flags_matrix(self):
        for present, owner, marker, riding, ride, stop in product((False, True),
                ('self', 'foreign', 'null'), (0, -2, -1, 17), (False, True), (False, True), (False, True)):
            options = dict(present=present, owner=owner, marker=marker, riding=riding, ride=ride, stop=stop)
            with self.subTest(**options):
                old, new = World(self.before, **options), World(self.after, **options)
                old.qdel_admission_and_destroy()
                new.qdel_admission_and_destroy()
                matched = present and owner == 'self' and not marker
                self.assertEqual(new.human.snapshot(), (False, None))
                self.assertEqual(new.mount.snapshot(), (False, None, False) if matched else old.mount.snapshot())
                self.assertEqual(new.other_human.snapshot(), old.other_human.snapshot())
                self.assertEqual(new.other_mount.snapshot(), old.other_mount.snapshot())
                self.assertEqual([row[0] for row in new.trace if row[0] != 'write'], (['icons'] if matched else []) + EFFECTS)

    def test_canonical_macro_and_deleting_subject_admission(self):
        self.assertTrue(QDELETED(None))
        for marker in (0, -2, -1, 17):
            self.assertEqual(bool(QDELETED(N(gc_destroyed=marker, gcDestroyed=0))), bool(marker))
        self.assertFalse(QDELETED(N(gc_destroyed=0, gcDestroyed=17)))
        world = World(self.after)
        world.qdel_admission_and_destroy()
        self.assertTrue(QDELETED(world.human))
        self.assertFalse(QDELETED(world.mount))
        self.assertEqual(world.mount.snapshot(), (False, None, False))

    def test_effective_same_type_layers_follow_dme_order(self):
        dme = (ROOT / 'civ13.dme').read_text()
        paths = ('code\\game\\mob\\living\\carbon\\carbon.dm',
                 'code\\game\\mob\\living\\carbon\\human\\human.dm')
        self.assertLess(dme.index('"' + paths[0] + '"'), dme.index('"' + paths[1] + '"'))
        self.assertEqual(CARBON.read_text().count(DECLARATION + '('), 1)
        self.assertEqual(self.after.count(DECLARATION + '('), 1)

    def test_parent_return_hint_propagates_through_both_human_layers(self):
        for hint in (None, 0, 1, 2, 3, 4):
            world = World(self.after, parent_hint=hint)
            self.assertEqual(world.qdel_admission_and_destroy(), hint)
            self.assertEqual([row[0] for row in world.trace if row[0] not in ('write', 'icons')], EFFECTS)

    def test_icon_callback_new_mount_owner_is_not_overwritten(self):
        def callback(world):
            world.mount.rider = world.other_human
            world.mount.ride = True
            world.mount.stop_automated_movement = True
            world.other_human.riding_mob = world.mount
        world = World(self.after, callbacks={'icons': callback})
        world.qdel_admission_and_destroy()
        self.assertEqual(world.mount.snapshot(), (True, 'other-human', True))
        self.assertEqual(world.other_human.snapshot(), (True, 'mount'))
        icon_index = next(i for i, row in enumerate(world.trace) if row[0] == 'icons')
        self.assertEqual([row for row in world.trace[icon_index+1:] if row[0] == 'write'], [
            ('write', 'mount', 'rider', 'other-human'), ('write', 'mount', 'ride', True),
            ('write', 'mount', 'stop_automated_movement', True), ('write', 'other-human', 'riding_mob', 'mount')])

    def test_icon_callback_new_human_link_is_not_cleared_later(self):
        def callback(world):
            world.human.riding_mob = world.other_mount
            world.human.riding = True
            world.other_mount.rider = world.human
        world = World(self.after, callbacks={'icons': callback})
        world.qdel_admission_and_destroy()
        self.assertEqual(world.human.snapshot(), (True, 'other-mount'))
        self.assertEqual(world.other_mount.snapshot(), (True, 'human', True))

    def test_icon_callback_retiring_mount_has_no_late_access(self):
        world = World(self.after, callbacks={'icons': lambda w: setattr(w.mount, 'gc_destroyed', -2)})
        world.qdel_admission_and_destroy()
        self.assertEqual(world.mount.snapshot(), (False, None, False))
        self.assertTrue(QDELETED(world.mount))
        self.assertEqual([row[0] for row in world.trace if row[0] not in ('write', 'icons')], EFFECTS)

    def test_icon_callback_reentry_is_rejected_by_source_admission(self):
        world = World(self.after, callbacks={'icons': lambda w: w.qdel_admission_and_destroy()})
        world.qdel_admission_and_destroy()
        self.assertEqual((world.attempts, world.cleanups), (2, 1))
        self.assertEqual(sum(row[0] == 'icons' for row in world.trace), 1)

    def test_existing_callback_reentry_and_reassignment_survive(self):
        def callback(world):
            world.qdel_admission_and_destroy()
            world.mount.rider = world.other_human
            world.mount.ride = True
            world.mount.stop_automated_movement = True
            world.other_human.riding_mob = world.mount
        world = World(self.after, callbacks={'exercise': callback})
        world.qdel_admission_and_destroy()
        self.assertEqual((world.attempts, world.cleanups), (2, 1))
        self.assertEqual(world.mount.snapshot(), (True, 'other-human', True))

    def test_direct_repeat_does_not_touch_animal_again(self):
        world = World(self.after)
        world.qdel_admission_and_destroy()
        first = [row for row in world.trace if row[:2] == ('write', 'mount')]
        world.cleanup(world.human)  # Deliberately bypass admission, not native GC.
        self.assertEqual([row for row in world.trace if row[:2] == ('write', 'mount')], first)
        self.assertEqual(sum(row[0] == 'icons' for row in world.trace), 1)

    def test_mutation_controls_omission_identity_retirement_subject_and_late_write(self):
        world = World(self.before)
        world.qdel_admission_and_destroy()
        self.assertEqual(world.mount.snapshot(), (True, 'human', True))
        unbound = self.after.replace(' && old_mount.rider == src', '')
        world = World(unbound, owner='foreign')
        world.qdel_admission_and_destroy()
        self.assertEqual(world.mount.snapshot(), (False, None, False))
        no_retirement = self.after.replace('!QDELETED(old_mount) && ', '')
        with self.assertRaisesRegex(AssertionError, 'retiring mock mount'):
            World(no_retirement, marker=-2).qdel_admission_and_destroy()
        wrong_subject = self.after.replace('!QDELETED(old_mount)', '!QDELETED(src)')
        world = World(wrong_subject)
        world.qdel_admission_and_destroy()
        self.assertEqual(world.mount.snapshot(), (True, 'human', True))
        late_write = self.after.replace('\t\told_mount.stop_automated_movement = FALSE\n\t\told_mount.update_icons()',
                                       '\t\told_mount.update_icons()\n\t\told_mount.stop_automated_movement = FALSE')
        def callback(world):
            world.mount.rider = world.other_human
            world.mount.ride = True
            world.mount.stop_automated_movement = True
        world = World(late_write, callbacks={'icons': callback})
        world.qdel_admission_and_destroy()
        self.assertEqual(world.mount.snapshot(), (True, 'other-human', False))


if __name__ == '__main__':
    unittest.main()
