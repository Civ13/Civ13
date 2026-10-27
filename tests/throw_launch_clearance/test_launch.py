"""Execute production DM control flow with explicit, offline engine adapters.

Uses the existing audited source projector. These tests do not execute BYOND.
"""
from pathlib import Path
import importlib.util
import math
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('throw_source_adapter', ROOT / 'tests/save_movement/source_adapter.py')
ADAPTER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ADAPTER)
MOVABLE = (ROOT / 'code/game/atoms_movable.dm').read_text(encoding='utf-8-sig')
DIRS = {'N': (0, 1), 'S': (0, -1), 'E': (1, 0), 'W': (-1, 0),
        'NE': (1, 1), 'NW': (-1, 1), 'SE': (1, -1), 'SW': (-1, -1)}
FIELDS = ('throw_launch_source', 'throw_launch_dx', 'throw_launch_dy', 'throw_launch_x', 'throw_launch_y',
          'clear_throw_launch', 'begin_throw_launch', 'update_throw_launch', 'throw_impact',
          'thrower', 'throwing', 'dx', 'dy', 'x', 'y', 'z', 'original_target', 'allow_spin',
          'speed', 'range', 'throw_source', 'last_throw_source', 'dist_x', 'dist_y',
          'dist_travelled', 'a', 'error', 'throwmode')


class Turf:
    def __init__(self, world, x, y, z=1):
        self.world, self.x, self.y, self.z = world, x, y, z
        self.allow_spin = False

    def __iter__(self):
        return iter([a for a in self.world.atoms if a.z == self.z and
                     self.x * 32 < a.px + 32 and a.px < self.x * 32 + 32 and
                     self.y * 32 < a.py + 32 and a.py < self.y * 32 + 32])


class World:
    def __init__(self):
        self.tiles, self.atoms, self.registered = {}, [], []

    def tile(self, x, y, z=1):
        return self.tiles.setdefault((x, y, z), Turf(self, x, y, z))


class Atom:
    def __init__(self, world, px=96, py=96, kind='item'):
        self.world, self.px, self.py, self.z, self.kind = world, px, py, 1, kind
        self.container = None
        self.deleted = False
        self.lying = False
        self.density = kind == 'structure'
        self.throwpass = False
        self.allow_spin = False
        self.impacts = []
        self.throwing = True
        self.thrower = None
        self.dx, self.dy = 4, 1
        for name in FIELDS[:5]:
            setattr(self, name, None)
        world.atoms.append(self)

    @property
    def x(self):
        return math.floor(self.px / 32)

    @property
    def y(self):
        return math.floor(self.py / 32)

    @property
    def loc(self):
        return self.container or self.world.tile(self.x, self.y, self.z)

    def throw_impact(self, target, speed):
        self.impacts.append(target)
        if target.kind in ('human', 'living', 'structure'):
            self.throwing = False  # Harmless injected hitby boundary.


def bounds_dist(a, b):
    # Native bounds_dist returns <0 only for positive-area physical overlap.
    return max(a.px - (b.px + 32), b.px - (a.px + 32),
               a.py - (b.py + 32), b.py - (a.py + 32))


def project(declaration, args, world, source=MOVABLE):
    # Explicit syntax/engine adapters; every selected executable source line
    # is otherwise consumed by the existing projector, which fails closed.
    source = source.replace('(hop_x > 0 ? EAST : WEST)', '(EAST if hop_x > 0 else WEST)')
    source = source.replace('(hop_y > 0 ? NORTH : SOUTH)', '(NORTH if hop_y > 0 else SOUTH)')
    source = source.replace('A:lying', 'A.lying')
    source = source.replace('istype(A,/mob/living)', 'isliving(A)')
    source = source.replace('locate(/obj/structure/window/barrier) in get_turf(src)', 'has_barrier(get_turf(src))')
    source = source.replace('thrown_list += src', 'register_throw(src)')
    env = dict(EAST=4, WEST=8, NORTH=1, SOUTH=2, abs=abs,
               isitem=lambda a: a.kind == 'item', ishuman=lambda a: bool(a) and a.kind == 'human',
               isDeleted=lambda a: a.deleted, isturf=lambda a: isinstance(a, Turf),
               bounds_dist=bounds_dist, get_turf=lambda a: a.loc,
               get_area=lambda a: None, register_throw=world.registered.append,
               typed_iter=lambda where, kind: list(where),
               isliving=lambda a: a.kind in ('human', 'living'),
               isobj=lambda a: a.kind in ('item', 'structure', 'barrier'),
               istype=lambda a: a.kind == 'barrier', has_barrier=lambda t: any(a.kind == 'barrier' for a in t))
    previous = ADAPTER.FIELDS
    ADAPTER.FIELDS = previous + FIELDS
    try:
        return ADAPTER.project(source, declaration, args, env, method=True)
    finally:
        ADAPTER.FIELDS = previous


def bind(atom, source=MOVABLE):
    for name, args in (('clear_throw_launch', 'src'), ('begin_throw_launch', 'src'),
                       ('update_throw_launch', 'src, advanced'), ('hit_check', 'src, speed, advanced=False'),
                       ('throw_at', 'src, target, _range, _speed, _thrower')):
        declaration = '/atom/movable/proc/' + name
        fn = project(declaration, args, atom.world, source)
        setattr(atom, name, lambda *values, fn=fn: fn(atom, *values))
    return atom


def launch(world, direction='N', source_position=(96, 98), *, thrower_kind='human', item_kind='item', source=MOVABLE):
    actor = Atom(world, *source_position, kind=thrower_kind)
    item = bind(Atom(world, actor.x * 32, actor.y * 32, kind=item_kind), source)
    dx, dy = DIRS[direction]
    item.throw_at(world.tile(item.x + dx * 8, item.y + dy * 8), 7, 2, actor)
    return actor, item


def hop(item, dx, dy, advanced=True):
    if advanced:
        item.px += dx * 32
        item.py += dy * 32
    item.hit_check(2, advanced)


class LaunchTests(unittest.TestCase):
    def test_all_directions_and_partial_offsets_execute_actual_launch_and_hit_code(self):
        for direction, (dx, dy) in DIRS.items():
            for phase in (0, 1, 2, 7, 8, 15, 16):
                with self.subTest(direction=direction, phase=phase):
                    w = World()
                    actor, item = launch(w, direction, (96 + dx * phase * 2, 96 + dy * phase * 2))
                    hop(item, dx, 0) if dx else hop(item, 0, dy)
                    self.assertNotIn(actor, item.impacts)
                    self.assertEqual((item.range, item.speed), (7, 2))
                    self.assertIn(item, w.registered)

    def test_all_directions_aligned_release_then_actor_pulse(self):
        for direction, (dx, dy) in DIRS.items():
            with self.subTest(direction=direction):
                actor, item = launch(World(), direction, (96, 96))
                actor.px += dx * 2
                actor.py += dy * 2
                hop(item, dx, 0) if dx else hop(item, 0, dy)
                self.assertNotIn(actor, item.impacts)

    def test_stationary_aligned_first_hop_separates_and_clears_all_fields(self):
        for direction, (dx, dy) in DIRS.items():
            actor, item = launch(World(), direction, (96, 96))
            hop(item, dx, 0) if dx else hop(item, 0, dy)
            self.assertNotIn(actor, item.impacts)
            self.assertTrue(all(getattr(item, name) is None for name in FIELDS[:5]))

    def test_odd_partial_offsets_and_diagonal_second_axis_remain_initial_overlap(self):
        for offset in (1, 2, 15, 16, 30, 31):
            actor, item = launch(World(), 'NE', (96 + offset, 96 + offset))
            hop(item, 1, 0)
            self.assertIs(item.throw_launch_source, actor)
            hop(item, 0, 1)
            self.assertIs(item.throw_launch_source, actor)
            self.assertNotIn(actor, item.impacts)

    def test_separation_on_empty_turf_then_recontact_hits(self):
        actor, item = launch(World(), 'N')
        hop(item, 0, 1)
        self.assertIs(item.throw_launch_source, actor)
        hop(item, 0, 1)
        self.assertIsNone(item.throw_launch_source)
        actor.py = item.py + 32
        hop(item, 0, 1)
        self.assertIn(actor, item.impacts)

    def test_other_mob_is_hit_during_source_overlap(self):
        w = World()
        actor, item = launch(w)
        other = Atom(w, 96, 128, kind='human')
        hop(item, 0, 1)
        self.assertNotIn(actor, item.impacts)
        self.assertIn(other, item.impacts)

    def test_redirection_before_separation_and_unannounced_reverse_both_allow_source_hit(self):
        for update_direction in (True, False):
            actor, item = launch(World(), 'N')
            hop(item, 0, 1)
            if update_direction:
                item.dy = 2
            hop(item, 0, -1)
            self.assertIsNone(item.throw_launch_source)
            self.assertIn(actor, item.impacts)

    def test_blocked_or_direct_hit_check_keeps_existing_source_collision(self):
        for default_call in (True, False):
            actor, item = launch(World(), 'N')
            item.hit_check(2) if default_call else hop(item, 0, 1, advanced=False)
            self.assertIsNone(item.throw_launch_source)
            self.assertIn(actor, item.impacts)

    def test_new_launch_replaces_owner_and_null_thrower_disarms(self):
        w = World()
        actor, item = launch(w)
        other = Atom(w, 96, 98, kind='human')
        item.throw_at(w.tile(3, 10), 5, 3, other)
        self.assertIs(item.throw_launch_source, other)
        item.throw_at(w.tile(3, 10), 5, 3, None)
        self.assertIsNone(item.throw_launch_source)

    def test_unrelated_entrypoints_and_thrown_mobs_do_not_acquire_clearance(self):
        for source_kind, item_kind in (('living', 'item'), ('human', 'living')):
            actor, item = launch(World(), thrower_kind=source_kind, item_kind=item_kind)
            self.assertIsNone(item.throw_launch_source)
        w = World()
        actor, item = launch(w)
        actor.px += 64
        item.throw_at(w.tile(3, 10), 5, 3, actor)
        self.assertIsNone(item.throw_launch_source)

    def test_invalid_source_ownership_or_location_disarms(self):
        for invalid in ('deleted', 'contained', 'cross_z', 'reattributed', 'stopped', 'jump'):
            actor, item = launch(World())
            if invalid == 'deleted': actor.deleted = True
            if invalid == 'contained': actor.container = object()
            if invalid == 'cross_z': actor.z = 2
            if invalid == 'reattributed': item.thrower = None
            if invalid == 'stopped': item.throwing = False
            if invalid == 'jump': item.py += 32
            hop(item, 0, 1)
            self.assertIsNone(item.throw_launch_source)

    def test_lying_target_and_legacy_barrier_exception_are_preserved(self):
        actor, item = launch(World())
        actor.lying = True
        hop(item, 0, 1, advanced=False)
        self.assertNotIn(actor, item.impacts)
        w = World()
        actor, item = launch(w)
        barrier = Atom(w, 96, 96, kind='barrier')
        barrier.CanPass = lambda *args: True
        hop(item, 0, 1, advanced=False)
        self.assertNotIn(actor, item.impacts)

    def test_source_filter_control_reproduces_north_defect(self):
        control = MOVABLE.replace('\t\t\t\tif (A == throw_launch_source) continue\n', '')
        self.assertNotEqual(control, MOVABLE)
        actor, item = launch(World(), source=control)
        hop(item, 0, 1)
        self.assertIn(actor, item.impacts)

    def test_permanent_immunity_control_is_rejected_by_later_selfhit_contract(self):
        control = MOVABLE.replace('if (A == throw_launch_source) continue', 'if (A == thrower) continue')
        actor, item = launch(World(), source=control)
        hop(item, 0, 1)
        hop(item, 0, 1)
        actor.py = item.py + 32
        hop(item, 0, 1)
        self.assertNotIn(actor, item.impacts)  # The prohibited mutant loses the legitimate hit.

    def test_first_hop_only_control_loses_second_diagonal_overlap(self):
        control = MOVABLE.replace('if (A == throw_launch_source) continue',
                                  'if (A == throw_launch_source && dist_travelled == 0) continue')
        actor, item = launch(World(), 'NE', (98, 98), source=control)
        hop(item, 1, 0)
        item.dist_travelled = 1
        hop(item, 0, 1)
        self.assertIn(actor, item.impacts)  # Rejected: still the initial overlap.

    def test_missing_empty_turf_separation_control_loses_later_hit(self):
        control = MOVABLE.replace(' || bounds_dist(src, throw_launch_source) >= 0)', ')')
        self.assertNotEqual(control, MOVABLE)
        actor, item = launch(World(), source=control)
        hop(item, 0, 1)
        hop(item, 0, 1)
        actor.py = item.py + 32
        hop(item, 0, 1)
        self.assertNotIn(actor, item.impacts)  # Rejected: stale launch latch.

    def test_ordinary_bottle_and_scripted_calls_share_base_launch_admission(self):
        human = (ROOT / 'code/game/mob/living/carbon/carbon.dm').read_text()
        bottle = (ROOT / 'code/modules/reagents/reagent_containers/food/drinks/bottle.dm').read_text()
        football = (ROOT / 'code/modules/1713/football.dm').read_text()
        self.assertIn('item.throw_at(target, throw_range, item.throw_speed, src)', human)
        self.assertIn('..(target, range, speed, thrower)', bottle)
        self.assertIn('FB.throw_at(NEAR, FB.throw_range, FB.throw_speed, src)', football)
        body = ADAPTER.extract(MOVABLE, '/atom/movable/proc/throw_at')
        self.assertLess(body.index('begin_throw_launch()'), body.index('thrown_list += src'))
        self.assertEqual(MOVABLE.count('begin_throw_launch()'), 2)  # declaration + common launch

    def test_actual_process_consumes_move_result_in_all_four_branches(self):
        fire = (ROOT / 'code/processes/throwing.dm').read_text()
        expected = ('var/advanced = FALSE', 'advanced = AM.forceMove_nondenseturf(step)',
                    'AM.hit_check(AM.speed, advanced)')
        for text in expected:
            self.assertEqual(fire.count(text), 4)
        pattern = r'var/advanced = FALSE\s+if \(canMove\)\s+advanced = AM.forceMove_nondenseturf\(step\)\s+AM.hit_check\(AM.speed, advanced\)\s+AM.error'
        self.assertEqual(len(re.findall(pattern, fire)), 4)

    def test_lifecycle_and_custom_save_policy(self):
        for declaration in ('/atom/movable/Destroy', '/atom/movable/Bump', '/atom/movable/proc/finished_throwing'):
            body = ADAPTER.extract(MOVABLE, declaration)
            self.assertIn('clear_throw_launch()', body)
        finish = ADAPTER.extract(MOVABLE, '/atom/movable/proc/finished_throwing')
        self.assertLess(finish.index('clear_throw_launch()'), finish.index('throw_impact('))
        force = ADAPTER.extract(MOVABLE, '/atom/movable/proc/forceMove')
        self.assertLess(force.index('clear_throw_launch()'), force.index('loc = destination'))
        items = (ROOT / 'code/game/objects/items.dm').read_text()
        self.assertIn('clear_throw_launch()', ADAPTER.extract(items, '/obj/item/proc/pickup'))
        policy = (ROOT / 'code/modules/persistence/functions.dm').read_text()
        fn = ADAPTER.project(policy.replace('..()', 'parent(key)'), '/atom/movable/persistence_runtime_var',
                             'src, key', {'parent': lambda key: False}, method=True)
        for key in FIELDS[:5]: self.assertTrue(fn(None, key), key)
        for key in ('amount', 'loc', 'thrower', 'speed', 'range'): self.assertFalse(fn(None, key), key)


if __name__ == '__main__':
    unittest.main(verbosity=2)
