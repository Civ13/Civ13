"""Source-derived offline death/guard regression; no native engine or live I/O."""
from itertools import product
from pathlib import Path
import re
import sys
from types import SimpleNamespace as N
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tests/save_movement'))
from source_adapter import extract, project

DEATH = '/mob/living/simple_animal/death'
RIDING = ROOT / 'code/game/mob/living/simple_animal/riding.dm'
BEFORE = Path(__file__).with_name('fixtures') / 'death_before.txt'
SUBTILE = ROOT / 'code/game/mob/living/carbon/human/subtile_movement.dm'
RETURN = ROOT / 'code/modules/persistence/bed_return.dm'
HUMAN_FIELDS = ('buckled', 'riding', 'riding_mob', 'using_drone', 'control_object',
    'incorporeal_move', 'pulledby', 'grab_list', 'grabbed_by', 'using_object', 'using_cannon', 'football')
STATIONARY = object()


def qualify(body, fields):
    """Bind audited bare members without changing quoted DM message text."""
    pieces = re.split(r'("(?:[^"\\]|\\.)*")', body)
    for index in range(0, len(pieces), 2):
        for name in fields:
            pieces[index] = re.sub(r'(?<![\w.])' + name + r'\b', 'src.' + name, pieces[index])
    return ''.join(pieces)


class Turf:
    pass


class DMList(list):
    @property
    def len(self):
        return len(self)


class Rider:
    def __init__(self, world):
        self.world = world
        for field in HUMAN_FIELDS:
            setattr(self, field, False)
        self.grab_list = self.grabbed_by = DMList()
        self.riding = True
        self.riding_mob = world.mount
        self.pixel_x, self.pixel_y = 7, 9
        self.loc = Turf()
        self.persistence_owner_ckey = 'fixture'
        self.driver = self.driver_vehicle = False

    def effect(self, name, *args):
        self.world.trace.append((name, args, self.riding, getattr(self.riding_mob, 'label', None)))

    def visible_message(self, *args):
        self.effect('message', *args)

    def SpinAnimation(self, *args):
        self.effect('spin', *args)

    def forceMove(self, destination):
        self.effect('forceMove', destination)
        if self.world.on_move:
            self.world.on_move(self)

    def Weaken(self, amount):
        self.effect('weaken', amount)


class World:
    def __init__(self, text, *, can_ride=True, present=True, link='owned', riding=True,
                 parent_result=True, parent_effect=None, on_move=None):
        self.trace = []
        self.other = N(label='other')
        self.mount = N(label='mount', can_ride=can_ride, ride=True, x=4, y=5, z=1)
        self.human = Rider(self)
        self.human.riding = riding
        self.human.riding_mob = {'owned': self.mount, 'other': self.other, 'null': None}[link]
        self.mount.rider = self.human if present else None
        self.mount.overlays = N(Cut=lambda: self.trace.append(('cut', (), None, None)))
        self.on_move = on_move

        def parent(src):
            self.trace.append(('parent', (), None, None))
            if parent_effect:
                parent_effect(self)
            return parent_result

        body = qualify(extract(text, DEATH), ('can_ride', 'rider', 'ride', 'overlays', 'x', 'y', 'z'))
        body = body.replace('..()', 'parent(src)')
        self.invoke = project('/death()\n' + body + '\n', '/death', 'src',
            dict(parent=parent, isnull=lambda value: value is None, locate=lambda *p: p))

    def run(self):
        return self.invoke(self.mount)

    def normalized(self):
        return ([(name, args, riding) for name, args, riding, _ in self.trace],
                self.human.riding, self.human.pixel_x, self.human.pixel_y,
                self.mount.ride, self.mount.rider is None)


def unlinked(human):
    declaration = '/mob/living/human/proc/human_subtile_unlinked'
    body = qualify(extract(SUBTILE.read_text(), declaration), HUMAN_FIELDS)
    body = body.replace('/obj/item/weapon/gun/projectile/automatic/stationary', 'STATIONARY')
    return project('/guard()\n' + body + '\n', '/guard', 'src',
        dict(STATIONARY=STATIONARY, istype=lambda value, kind: value is kind))(human)


def character_return(human, *, pending=True, protected=False, ready=True):
    declaration = '/map_storage/proc/prepare_character_return'
    env = dict(persistence_bed_return_enabled=lambda: True,
        character_recovery_unready=lambda: not ready,
        persistence_restored_bodies={'fixture': [human] if pending else []},
        is_protected_sleep_location=lambda _: protected, isturf=lambda value: isinstance(value, Turf),
        character_return_turf=lambda actor: actor.loc,
        persistence_character_turf_safe=lambda *_: True)
    return project(RETURN.read_text(), declaration, 'H', env)(human)


class DeathTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.before = BEFORE.read_text()
        cls.after = RIDING.read_text()

    def test_frozen_preimage_diff_is_only_the_guarded_clear(self):
        inserted = '\t\tif (rider.riding_mob == src)\n\t\t\trider.riding_mob = null\n'
        self.assertEqual(extract(self.after, DEATH).replace(inserted, '').rstrip(), extract(self.before, DEATH).rstrip())

    def test_matrix_preserves_effects_and_clears_only_owned_links(self):
        for can_ride, present, link, riding, parent_result in product(
                (False, True), (False, True), ('owned', 'other', 'null'), (False, True), (None, True)):
            options = dict(can_ride=can_ride, present=present, link=link, riding=riding, parent_result=parent_result)
            with self.subTest(**options):
                old, new = World(self.before, **options), World(self.after, **options)
                self.assertIsNone(old.run())
                self.assertIsNone(new.run())
                self.assertEqual(old.normalized(), new.normalized())
                expected = None if can_ride and present and link == 'owned' else {'owned': new.mount, 'other': new.other, 'null': None}[link]
                self.assertIs(new.human.riding_mob, expected)
                self.assertEqual(sum(row[0] == 'parent' for row in new.trace), 1)

    def test_force_move_observes_unmounted_owned_rider(self):
        observed = []
        world = World(self.after, on_move=lambda h: observed.append((unlinked(h), character_return(h))))
        world.run()
        self.assertEqual([row[0] for row in world.trace], ['parent', 'message', 'spin', 'forceMove', 'weaken', 'cut'])
        movement = next(row for row in world.trace if row[0] == 'forceMove')
        self.assertEqual(movement, ('forceMove', ((5, 5, 1),), False, None))
        self.assertEqual(observed, [(True, True)])

    def test_callback_transfer_is_not_cleared_after_force_move(self):
        def transfer(human):
            human.riding_mob = human.world.other
            human.riding = True
        world = World(self.after, on_move=transfer)
        world.run()
        self.assertIs(world.human.riding_mob, world.other)
        self.assertTrue(world.human.riding)

    def test_parent_can_withdraw_rider_before_cleanup(self):
        world = World(self.after, parent_effect=lambda w: setattr(w.mount, 'rider', None))
        world.run()
        self.assertEqual([row[0] for row in world.trace], ['parent'])
        self.assertIs(world.human.riding_mob, world.mount)

    def test_repeated_death_adds_only_the_existing_parent_call(self):
        world = World(self.after)
        world.run()
        first = list(world.trace)
        world.run()
        self.assertEqual(world.trace, first + [('parent', (), None, None)])
        self.assertIsNone(world.human.riding_mob)

    def test_stale_link_control_blocks_guard_until_owned_death_clear(self):
        old, new = World(self.before), World(self.after)
        old.run()
        new.run()
        self.assertFalse(unlinked(old.human))
        self.assertTrue(unlinked(new.human))
        self.assertFalse(character_return(old.human))
        self.assertTrue(character_return(new.human))
        self.assertTrue(character_return(old.human, pending=False))
        self.assertFalse(character_return(old.human, pending=False, protected=True))

    def test_other_guard_restrictions_remain_effective(self):
        for field in HUMAN_FIELDS:
            if field == 'riding_mob':
                continue
            world = World(self.after)
            world.run()
            value = DMList([1]) if field in ('grab_list', 'grabbed_by') else STATIONARY if field == 'using_object' else True
            setattr(world.human, field, value)
            with self.subTest(guard='unlinked', field=field):
                self.assertFalse(unlinked(world.human))
        for field in ('riding', 'driver', 'driver_vehicle', 'riding_mob', 'loc'):
            world = World(self.after)
            world.run()
            setattr(world.human, field, object())
            with self.subTest(guard='return', field=field):
                self.assertFalse(character_return(world.human))
        world = World(self.after)
        world.run()
        self.assertFalse(character_return(world.human, ready=False))

    def test_mutation_controls_cover_omission_identity_and_late_clear(self):
        inserted = '\t\tif (rider.riding_mob == src)\n\t\t\trider.riding_mob = null\n'
        omitted = self.after.replace(inserted, '')
        world = World(omitted)
        world.run()
        self.assertFalse(unlinked(world.human))
        unguarded = self.after.replace(inserted, '\t\trider.riding_mob = null\n')
        world = World(unguarded, link='other')
        world.run()
        self.assertIsNone(world.human.riding_mob)
        late = self.after.replace(inserted, '').replace('\t\trider.Weaken(5)', inserted + '\t\trider.Weaken(5)')
        world = World(late, on_move=lambda h: setattr(h, 'riding_mob', h.world.other))
        world.run()
        self.assertIs(world.human.riding_mob, world.other)
        self.assertEqual(next(row for row in world.trace if row[0] == 'forceMove')[3], 'mount')


if __name__ == '__main__':
    unittest.main()
