"""Offline timed-flee ownership checks; no BYOND behavior is executed."""
from pathlib import Path
from types import SimpleNamespace
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/game/mob/living/simple_animal/subtile_movement.dm'
AI = ROOT / 'code/game/mob/living/simple_animal/simple_ai.dm'
TACTICAL = ROOT / 'code/game/mob/living/simple_animal/hostile/tactical_ai.dm'


def section(source, start, end):
    return source.split(start, 1)[1].split(end, 1)[0]


def evaluate(expression, context):
    expression = expression.replace('&&', ' and ').replace('||', ' or ')
    expression = re.sub(r'!(?!=)', ' not ', expression).strip()
    return bool(eval(expression, {'__builtins__': {}}, context))


class FleeContracts(unittest.TestCase):
    def setUp(self):
        self.source = SOURCE.read_text(encoding='utf-8')
        self.owner, self.target = object(), object()
        self.actor = SimpleNamespace(npc_subtile_flee=self.owner,
            npc_subtile_flee_enabled=True, npc_subtile_enabled=True,
            npc_subtile_ready=lambda: True, npc_subtile_pursuit=None,
            npc_subtile_follow=None, npc_subtile_pet_walk=None, move_gen=3, stance='idle',
            target_mob=None, target_obj=None, following_mob=None, z=1)
        self.context = dict(cancelled=False, actor=self.actor, src=self.owner,
            generation=3, target=self.target, expected_stance='idle',
            expected_combat_target=None, expected_path_target=None,
            expected_following=None, isDeleted=lambda item: False,
            destination=SimpleNamespace(z=1), max_distance=7,
            get_dist=lambda actor, target: 3)

    def admitted(self):
        valid = section(self.source, '/datum/npc_subtile_flee/proc/valid()\n',
                        '/datum/npc_subtile_flee/proc/perform()')
        reject = next(line.strip()[3:] for line in valid.splitlines()
                      if line.strip().startswith('if ('))
        accept = next(line.strip()[len('return '):] for line in valid.splitlines()
                      if line.strip().startswith('return destination'))
        return not evaluate(reject, self.context) and evaluate(accept, self.context)

    def test_revocation_and_radius(self):
        self.assertTrue(self.admitted())
        changes = (
            lambda: self.context.update(cancelled=True),
            lambda: setattr(self.actor, 'npc_subtile_flee', object()),
            lambda: setattr(self.actor, 'npc_subtile_pursuit', object()),
            lambda: setattr(self.actor, 'npc_subtile_follow', object()),
            lambda: setattr(self.actor, 'npc_subtile_pet_walk', object()),
            lambda: setattr(self.actor, 'move_gen', 4),
            lambda: setattr(self.actor, 'npc_subtile_ready', lambda: False),
            lambda: setattr(self.actor, 'following_mob', object()),
            lambda: setattr(self.actor, 'target_mob', object()),
            lambda: setattr(self.actor, 'target_obj', object()),
            lambda: setattr(self.actor, 'stance', 'attack'),
            lambda: self.context.update(get_dist=lambda actor, target: 8),
            lambda: self.context.update(destination=SimpleNamespace(z=2)),
        )
        for change in changes:
            with self.subTest(change=change):
                self.setUp()
                change()
                self.assertFalse(self.admitted())

    def test_timed_scared_producer_retains_legacy_path(self):
        scared = section(AI.read_text(encoding='utf-8'), '\t\tif ("scared")',
                         '\t\tif ("wander")')
        self.assertIn('npc_subtile_start_flee(H, 7, npc_subtile_native_interval(2), flee_receipt)', scared)
        self.assertIn('walk_away_od(src, H, 7, 2)', scared)
        self.assertEqual(scared.count('spawn(50)'), 1)
        self.assertIn('flee_remaining = max(0, flee_ticket["expires_at"] - world.time)', scared)
        self.assertIn('spawn(flee_remaining)', scared)
        self.assertIn('npc_subtile_stop_flee_ticket(flee_ticket)', scared)
        self.assertNotIn('npc_subtile_stop_continuous_walk()', scared)
        self.assertEqual(scared.count('walk(src, 0)'), 1)

    def test_expired_request_cannot_cancel_a_replacement_or_its_pending_intent(self):
        timeout = section(self.source, '/mob/living/simple_animal/proc/npc_subtile_stop_flee_ticket(',
                          '/datum/npc_subtile_flee\n')
        self.assertIn('isnull(ticket) || npc_subtile_flee_ticket != ticket', timeout)
        self.assertIn('npc_subtile_pending_intent.kind == "flee" && npc_subtile_pending_intent.flee_ticket == ticket', timeout)
        self.assertIn('npc_subtile_flee && npc_subtile_flee.flee_ticket == ticket', timeout)
        self.assertIn('npc_subtile_stop_flee(FALSE)', timeout)
        self.assertNotIn('npc_subtile_stop_continuous_walk()', timeout)
        self.assertNotIn('walk(src, 0)', timeout)
        dispatch = section(self.source, '/mob/living/simple_animal/proc/npc_subtile_dispatch_pending()\n',
                           '/datum/npc_subtile_pending_intent\n')
        self.assertIn('npc_subtile_start_flee(P.target, P.distance_limit, P.interval, null, P.flee_ticket)', dispatch)
        start = section(self.source, '/mob/living/simple_animal/proc/npc_subtile_start_flee(',
                        '/mob/living/simple_animal/proc/npc_subtile_stop_flee(')
        self.assertLess(start.index('if (!npc_subtile_defer_intent('), start.index('npc_subtile_flee_ticket = flee_ticket'))
        self.assertIn('receipt["ticket"] = npc_subtile_flee.flee_ticket', start)
        self.assertIn('F.flee_ticket = flee_ticket', start)
        old, newer = object(), object()
        def expire(ticket, current, pending, active):
            # Model the source guard and its two independently scoped effects.
            if ticket is None or current is not ticket:
                return current, pending, active
            if pending and pending.kind == 'flee' and pending.ticket is ticket:
                pending = None
            if active and active.ticket is ticket:
                active = None
            return None, pending, active
        replacement = SimpleNamespace(kind='follow', ticket=newer)
        active = SimpleNamespace(ticket=newer)
        self.assertEqual(expire(old, newer, replacement, active), (newer, replacement, active))
        pending_flee = SimpleNamespace(kind='flee', ticket=old)
        self.assertEqual(expire(old, old, pending_flee, None), (None, None, None))
        self.assertEqual(expire(old, old, replacement, SimpleNamespace(ticket=old)),
                         (None, replacement, None))
        # Deferred flee can become the active owner with the identical ticket.
        self.assertEqual(expire(old, old, None, SimpleNamespace(ticket=old)), (None, None, None))
        # A genuinely replaced owner has a new ticket: the old timer is inert.
        refreshed = SimpleNamespace(ticket=newer)
        self.assertEqual(expire(old, newer, None, refreshed), (newer, None, refreshed))

    def test_same_active_and_pending_request_keep_original_deadline(self):
        start = section(self.source, '/mob/living/simple_animal/proc/npc_subtile_start_flee(',
                        '/mob/living/simple_animal/proc/npc_subtile_stop_flee(')
        active_guard = next(line.strip()[3:] for line in start.splitlines()
                            if line.startswith('\tif (npc_subtile_flee &&'))
        pending_guards = [line.strip()[3:] for line in start.splitlines()
                          if line.strip().startswith('if (isnull(flee_ticket) && P &&')]
        self.assertTrue(pending_guards, 'identical pending flee does not retain its deadline')
        pending_guard = pending_guards[0]
        class Ticket(dict):
            def __eq__(self, other): return self is other
            def __ne__(self, other): return self is not other
        ticket = Ticket(expires_at=50)
        other_ticket = Ticket(expires_at=50)
        target = object()
        owner = SimpleNamespace(target=target, max_distance=7, interval=1,
                                flee_ticket=ticket, valid=lambda: True)
        pending = SimpleNamespace(kind='flee', target=target, distance_limit=7, interval=1,
                                  flee_ticket=ticket, expires_at=50, valid=lambda: True)
        context = {'npc_subtile_flee': owner, 'npc_subtile_flee_ticket': ticket,
                   'target': target, 'max_distance': 7, 'interval': 1, 'P': pending,
                   'flee_ticket': None, 'world': SimpleNamespace(time=49),
                   'isnull': lambda x: x is None, 'isnum': lambda x: isinstance(x, (int, float))}
        self.assertTrue(evaluate(active_guard, context))
        self.assertTrue(evaluate(pending_guard, context))
        for field, value in (('target', object()), ('max_distance', 8), ('interval', 2)):
            changed = dict(context, **{field: value})
            self.assertFalse(evaluate(active_guard, changed))
            self.assertFalse(evaluate(pending_guard, changed))
        self.assertFalse(evaluate(active_guard, dict(context, npc_subtile_flee_ticket=other_ticket)))
        self.assertFalse(evaluate(pending_guard, dict(context, npc_subtile_flee_ticket=other_ticket)))
        pending.expires_at = 60
        self.assertFalse(evaluate(pending_guard, context))
        pending.expires_at = 50
        context['world'].time = 50
        self.assertFalse(evaluate(active_guard, context))
        # Actual P.valid rejects an expired pending request before reuse.
        pending.valid = lambda: context['world'].time < ticket['expires_at']
        self.assertFalse(evaluate(pending_guard, context))
        defer = section(self.source, '/mob/living/simple_animal/proc/npc_subtile_defer_intent(',
                        '/mob/living/simple_animal/proc/npc_subtile_can_defer()')
        self.assertIn('P.expires_at = flee_ticket["expires_at"]', defer)
        self.assertIn('flee_ticket = list("expires_at" = world.time + 50)', start)
        self.assertIn('receipt["ticket"] = P.flee_ticket', start)
        self.assertIn('receipt["ticket"] = npc_subtile_flee.flee_ticket', start)
        # Recovery completing at 49 keeps one ds, not a fresh 50-ds interval.
        self.assertEqual(max(0, ticket['expires_at'] - 49), 1)
        dispatch = section(self.source, '/mob/living/simple_animal/proc/npc_subtile_dispatch_pending()\n',
                           '/datum/npc_subtile_pending_intent\n')
        self.assertIn('npc_subtile_start_flee(P.target, P.distance_limit, P.interval, null, P.flee_ticket)', dispatch)

    def test_timeout_during_paid_pulse_revokes_only_the_flee_owner(self):
        stop = section(self.source, '/mob/living/simple_animal/proc/npc_subtile_stop_flee(',
                       '/datum/npc_subtile_flee\n')
        self.assertIn('npc_subtile_stop_flee(FALSE)', stop)
        self.assertLess(stop.index('npc_subtile_flee = null'), stop.index('npc_subtile_release_generation('))
        transaction = section(self.source, '/datum/npc_subtile_transaction/proc/valid()\n',
                              '/datum/npc_subtile_transaction/proc/advance()')
        self.assertIn('actor.npc_subtile_intent_valid(intent_owner)', transaction)
        intent = section(self.source, '/mob/living/simple_animal/proc/npc_subtile_intent_valid(',
                         '// The AI chooses a destination')
        expression = next(line.strip()[len('return '):] for line in intent.splitlines()
                          if line.strip().startswith('return !owner'))
        owner = object()
        context = dict(owner=owner, npc_subtile_pursuit=None, npc_subtile_follow=None,
                       npc_subtile_flee=None, npc_subtile_pet_walk=None,
                       npc_subtile_recovery=None, npc_subtile_wild_walk=None)
        self.assertFalse(evaluate(expression, context))
        context['npc_subtile_flee'] = owner
        self.assertTrue(evaluate(expression, context))

    def test_owner_handoffs_and_paid_interval(self):
        start = section(self.source, '/mob/living/simple_animal/proc/npc_subtile_start_flee(',
                        '/mob/living/simple_animal/proc/npc_subtile_stop_flee(')
        for token in ('npc_subtile_stop_follow()', 'npc_subtile_stop_pursuit()',
                      'walk(src, 0)', 'walk_id = 0', 'move_gen++'):
            self.assertLess(start.index(token), start.index('F.perform()'))
        pursuit = section(TACTICAL.read_text(encoding='utf-8'),
            '/mob/living/simple_animal/proc/npc_subtile_start_pursuit(',
            '/datum/npc_subtile_pursuit\n')
        self.assertIn('npc_subtile_stop_flee()', pursuit)
        follow = section(self.source, '/mob/living/simple_animal/proc/npc_subtile_start_follow(',
                         '/mob/living/simple_animal/proc/npc_subtile_stop_follow(')
        self.assertIn('npc_subtile_flee ||', follow)
        loop = section(self.source, '/datum/npc_subtile_flee/proc/perform_loop()\n',
                       '/mob/living/simple_animal/pet/proc/npc_subtile_start_pet_walk(')
        self.assertIn('get_step_away(actor, target, max_distance)', loop)
        self.assertIn('actor.ai_step_wait(next, interval, src)', loop)
        self.assertIn('sleep(deadline - world.time)', loop)
        self.assertNotIn('sleep(interval)', loop)

    def test_stage_disabled_and_runtime_state_excluded(self):
        self.assertIn('var/npc_subtile_flee_enabled = FALSE', self.source)
        for path in (ROOT / 'code').rglob('*.dm'):
            self.assertNotIn('npc_subtile_flee_enabled = TRUE',
                             path.read_text(encoding='utf-8', errors='replace'), str(path))
        self.assertIn('"npc_subtile_flee_enabled"', self.source)
        self.assertIn('"npc_subtile_flee"', self.source)
        self.assertIn('return key == "following_mob" || ..()', self.source)


if __name__ == '__main__':
    unittest.main()
