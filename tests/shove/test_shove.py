"""Offline shove admission projections and source contracts, not native acceptance.

The complete admission prefix (through body/size checks) is executed from the
current DM source. Engine adjacency, restraints, messages and grip breaking are
explicit fakes. Movement contracts below inspect source only; they do not prove
BYOND collision, displacement, animation, timing, or save/load behavior.
"""
import importlib.util
from pathlib import Path
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[2]
HUMAN = ROOT / 'code/game/mob/living/carbon/human/human_attackhand.dm'
MOVEMENT = ROOT / 'code/game/mob/living/carbon/human/subtile_movement.dm'
LIVING = ROOT / 'code/game/mob/living/living.dm'
_spec = importlib.util.spec_from_file_location('shove_source_adapter', ROOT / 'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(adapter)
DECL = '/mob/living/human/proc/try_deliberate_shove'


class ShoveOwner:
    pass


def admission(user_changes=None, target_changes=None, *, same=False):
    """Execute the real prefix; the spatial sweep is intentionally not projected."""
    events = []
    user = SimpleNamespace(stat=0, canmove=True, lying=False, prone=False,
        buckled=False, loc='turf', z=1, pacifist=False,
        next_deliberate_shove=0, stats={'stamina': {1: 30}}, mob_size=2)
    user.restrained = lambda: False
    user.setClickCooldown = lambda value: events.append(('cooldown', value))
    user.do_attack_animation = lambda target: events.append(('animation',))
    target = SimpleNamespace(loc='turf', z=1, shove_recovery_until=0, mob_size=2, human_subtile_pulse=None, human_subtile_transaction=None)
    target.Adjacent = lambda actor: True
    target.break_all_grabs = lambda actor: False
    target.shove_body_ready = lambda: True
    for name, value in (user_changes or {}).items():
        setattr(user, name, value)
    for name, value in (target_changes or {}).items():
        setattr(target, name, value)
    body = adapter.extract(HUMAN.read_text(encoding='utf-8'), DECL)
    marker = '\tvar/dx = '
    assert body.count(marker) == 1, 'Admission boundary changed; re-audit projection'
    prefix = body[:body.index(marker)]
    # Preserve the type guard with an explicit fake DM subtype boundary.
    prefix = prefix.replace('/datum/human_subtile_transaction/shove', 'SHOVE_TYPE')
    source = '/fixture/admit()\n' + prefix + '\treached()\n\treturn TRUE\n'
    env = {'world': SimpleNamespace(time=100), 'max': max,
           'isturf': lambda loc: loc == 'turf',
           'istype': isinstance, 'SHOVE_TYPE': ShoveOwner,
           'to_chat': lambda *args: None, 'SPAN_WARNING': lambda text: text,
           'playsound': lambda *args: None,
           'reached': lambda: events.append(('spatial',))}
    fields = adapter.FIELDS
    try:
        adapter.FIELDS += ('loc', 'shove_recovery_until', 'Adjacent',
                           'break_all_grabs', 'shove_body_ready', 'mob_size', 'human_subtile_pulse', 'human_subtile_transaction')
        action = adapter.project(source, '/fixture/admit', 'src, user', env, method=True)
    finally:
        adapter.FIELDS = fields
    result = action(target, target if same else user)
    return result, user, events


class ShoveAdmission(unittest.TestCase):
    def test_admitted_attempt_pays_stamina_and_shared_cooldown(self):
        result, user, events = admission()
        self.assertTrue(result)
        self.assertEqual(user.stats['stamina'][1], 20)
        self.assertEqual(user.next_deliberate_shove, 120)
        self.assertIn(('cooldown', 20), events)
        self.assertIn(('spatial',), events)

    def test_actor_protections_reject_without_payment(self):
        for changes in ({'stat': 1}, {'canmove': False}, {'lying': True},
                        {'prone': True}, {'restrained': lambda: True},
                        {'buckled': True}, {'loc': 'container'}, {'z': 2},
                        {'pacifist': True}, {'next_deliberate_shove': 101},
                        {'stats': {'stamina': {1: 9}}}):
            with self.subTest(changes=changes):
                result, user, events = admission(changes)
                self.assertFalse(result)
                self.assertFalse(events)

    def test_target_range_and_recovery_reject_without_payment(self):
        for changes in ({'loc': 'container'}, {'Adjacent': lambda actor: False},
                        {'shove_recovery_until': 101}):
            with self.subTest(changes=changes):
                result, user, events = admission(target_changes=changes)
                self.assertFalse(result)
                self.assertEqual(user.stats['stamina'][1], 30)
                self.assertFalse(events)

    def test_deadline_equality_and_exact_stamina_are_allowed(self):
        result, user, events = admission({'next_deliberate_shove': 100,
            'stats': {'stamina': {1: 10}}}, {'shove_recovery_until': 100})
        self.assertTrue(result)
        self.assertEqual(user.stats['stamina'][1], 0)
        self.assertIn(('spatial',), events)

    def test_breaking_grips_consumes_action_without_displacement(self):
        result, user, events = admission(target_changes={'break_all_grabs': lambda actor: True})
        self.assertTrue(result)
        self.assertEqual(user.stats['stamina'][1], 20)
        self.assertNotIn(('spatial',), events)

    def test_active_shove_and_inflight_pulse_reject_reentry(self):
        for changes in ({'human_subtile_transaction': ShoveOwner()},
                        {'human_subtile_pulse': object()}):
            with self.subTest(changes=changes):
                result, user, events = admission(target_changes=changes)
                self.assertFalse(result)
                self.assertNotIn(('spatial',), events)
        # An ordinary sleeping walk is not mistaken for an active shove.
        result, user, events = admission(target_changes={'human_subtile_transaction': object()})
        self.assertTrue(result)
        self.assertIn(('spatial',), events)
    def test_immovable_or_larger_target_does_not_reach_sweep(self):
        for changes in ({'shove_body_ready': lambda: False}, {'mob_size': 3}):
            with self.subTest(changes=changes):
                result, user, events = admission(target_changes=changes)
                self.assertFalse(result)
                self.assertNotIn(('spatial',), events)


class ShoveSourceContracts(unittest.TestCase):
    def test_disarm_dispatch_preserves_aimed_and_martial_routes(self):
        source = HUMAN.read_text(encoding='utf-8')
        self.assertIn('H.mind.martial_art.disarm_act(H, src)', source)
        self.assertIn('M.targeted_organ == "chest"', source)
        self.assertIn('M.targeted_organ == "random"', source)
        self.assertIn('try_deliberate_shove(M)', source)
        self.assertIn('drop_from_inventory(I)', source)
        self.assertIn('M.resist_grab()', source)

    def test_sweep_is_bounded_native_collision_not_teleport(self):
        source = MOVEMENT.read_text(encoding='utf-8')
        sweep = adapter.extract(source, '/datum/human_subtile_transaction/shove/perform')
        self.assertIn('i <= 16', sweep)
        self.assertIn('list(NORTH, SOUTH, EAST, WEST)', sweep)
        self.assertIn('actor.Move(destination, direction)', sweep)
        self.assertIn('persistence_movement_allowed(actor, destination)', sweep)
        self.assertIn('map.check_caribbean_block(actor, front)', sweep)
        self.assertIn('actor.human_subtile_pulse_climbs(dx, dy)', sweep)
        for forbidden in ('forceMove(', 'sleep(', 'spawn(', 'Weaken(', 'apply_damage('):
            self.assertNotIn(forbidden, sweep)

    def test_stagger_only_after_displacement_and_no_new_knockdown(self):
        body = adapter.extract(HUMAN.read_text(encoding='utf-8'), DECL)
        self.assertLess(body.index('if (!moved)'), body.index('shove_recovery_until ='))
        self.assertIn('shove_recovery_until = world.time + 30', body)
        self.assertIn('setClickCooldown(4)', body)
        self.assertNotIn('Weaken(', body)
        self.assertNotIn('drop_from_inventory(', body)

    def test_shove_bump_suppression_precedes_delayed_push(self):
        body = adapter.extract(LIVING.read_text(encoding='utf-8'), '/mob/living/Bump')
        marker = 'istype(shoved.human_subtile_transaction, /datum/human_subtile_transaction/shove)'
        self.assertLess(body.index(marker), body.index('spawn('))
        self.assertIn(marker + ')\n\t\t\treturn', body)

    def test_body_swap_is_rejected_for_shove_owner(self):
        body = adapter.extract(LIVING.read_text(encoding='utf-8'), '/mob/living/proc/swap_passable')
        self.assertIn('istype(shoved.human_subtile_transaction, /datum/human_subtile_transaction/shove))\n\t\t\treturn FALSE', body)

    def test_cancelled_walk_finishes_and_releases_visuals_before_new_owner(self):
        body = adapter.extract(HUMAN.read_text(encoding='utf-8'), DECL)
        cancel = body.index('human_subtile_transaction.cancelled = TRUE')
        release = body.index('human_subtile_transaction.release_visuals()')
        finish = body.index('human_subtile_transaction.finish()')
        claim = body.index('human_subtile_transaction = T')
        self.assertLess(cancel, release)
        self.assertLess(release, finish)
        self.assertLess(finish, claim)
        self.assertIn('!shove_body_ready()', body[finish:claim])
        self.assertIn('human_subtile_pulse', body[finish:claim])
    def test_deadlines_excluded_from_custom_persistence(self):
        body = adapter.extract(MOVEMENT.read_text(encoding='utf-8'), '/mob/living/human/persistence_runtime_var')
        self.assertIn('key == "next_deliberate_shove"', body)
        self.assertIn('key == "shove_recovery_until"', body)
        self.assertIn('return TRUE', body.split('key == "shove_recovery_until"', 1)[1])

class Body:
    pass


def body_ready(changes=None, *, leased=False, hanging=False):
    body = Body()
    for name in ('stat', 'lying', 'prone', 'anchored', 'driver', 'transforming',
                 'throwing', 'status_flags', 'pulling', 'other_mobs'):
        setattr(body, name, 0)
    body.human_subtile_enabled = True
    body.pinned = None
    body.loc = []
    body.human_subtile_shape = lambda: True
    body.human_subtile_unlinked = lambda: True
    for name, value in (changes or {}).items():
        setattr(body, name, value)
    if hanging:
        body.loc = [SimpleNamespace(hanging=body)]
    env = {'LEAPING': 16,
           'subtile_pull_ownership': SimpleNamespace(owners={body: leased}),
           'typed_iter': lambda values, kind: iter(values)}
    fields = adapter.FIELDS
    try:
        adapter.FIELDS += ('loc', 'human_subtile_shape', 'stat', 'lying', 'prone',
                          'anchored', 'driver', 'transforming', 'throwing',
                          'status_flags', 'pinned', 'human_subtile_unlinked', 'pulling',
                          'human_subtile_enabled', 'other_mobs')
        action = adapter.project(HUMAN.read_text(encoding='utf-8'),
            '/mob/living/human/proc/shove_body_ready', 'src', env, method=True)
    finally:
        adapter.FIELDS = fields
    return action(body)


class ShoveBodyReadiness(unittest.TestCase):
    def test_standing_unlinked_body_is_eligible(self):
        self.assertTrue(body_ready())

    def test_each_body_exclusion_rejects_displacement(self):
        for name in ('stat', 'lying', 'prone', 'anchored', 'driver',
                     'transforming', 'throwing', 'pulling', 'other_mobs'):
            with self.subTest(field=name):
                self.assertFalse(body_ready({name: 1}))
        self.assertFalse(body_ready({'human_subtile_enabled': False}))
        self.assertFalse(body_ready({'status_flags': 16}))
        self.assertFalse(body_ready({'pinned': SimpleNamespace(len=1)}))
        self.assertFalse(body_ready({'human_subtile_shape': lambda: False}))
        self.assertFalse(body_ready({'human_subtile_unlinked': lambda: False}))
        self.assertFalse(body_ready(leased=True))
        self.assertFalse(body_ready(hanging=True))

    def test_self_shove_rejected(self):
        result, user, events = admission(same=True)
        self.assertFalse(result)
        self.assertFalse(events)

if __name__ == '__main__':
    unittest.main()
