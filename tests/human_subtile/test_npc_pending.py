"""Offline contracts for one replaceable deferred recovery command."""
from pathlib import Path
from types import SimpleNamespace
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/game/mob/living/simple_animal/subtile_movement.dm'
TACTICAL = ROOT / 'code/game/mob/living/simple_animal/hostile/tactical_ai.dm'
AI = ROOT / 'code/game/mob/living/simple_animal/simple_ai.dm'


def section(source, start, end):
    return source.split(start, 1)[1].split(end, 1)[0]


def evaluate(expression, context):
    expression = expression.replace('&&', ' and ').replace('||', ' or ').replace('null', 'None')
    expression = re.sub(r'!(?!=)', ' not ', expression).strip()
    return bool(eval(expression, {'__builtins__': {}}, context))


class PendingContracts(unittest.TestCase):
    def setUp(self):
        self.source = SOURCE.read_text(encoding='utf-8')
        self.owner, self.target = object(), object()
        self.actor = SimpleNamespace(npc_subtile_pending_intent=self.owner,
            npc_subtile_recovery_enabled=True, npc_subtile_enabled=True,
            npc_subtile_pursuit_enabled=True, npc_subtile_follow_enabled=True,
            npc_subtile_flee_enabled=True, client=None, stat=0, move_gen=5,
            stance='attack', behaviour='hunt', target_mob=self.target,
            following_mob=None, z=1, aggro_vision_range=7, idle_vision_range=9,
            SA_attackable=lambda target: True)
        self.context = dict(actor=self.actor, src=self.owner, target=self.target,
            kind='pursuit', mode=None, generation=5, expected_stance='attack', expected_behaviour='hunt',
            expected_combat_target=self.target, expected_following=None,
            isDeleted=lambda item: False, isnum=lambda item: isinstance(item, (int, float)),
            world=SimpleNamespace(time=10, tick_lag=.5),
            expires_at=60, distance_limit=7, interval=2,
            side_direction=0, alldirs=(1, 2, 4, 8, 5, 6, 9, 10),
            get_dist=lambda actor, target: 3, view=lambda distance, actor: [self.target])

    def rejection(self):
        valid = section(self.source, '/datum/npc_subtile_pending_intent/proc/base_valid()\n',
                        '/datum/npc_subtile_pending_intent/proc/valid()')
        return next(line.strip()[3:] for line in valid.splitlines() if line.strip().startswith('if ('))

    def mode_guard(self, kind, next_kind):
        valid = section(self.source, '/datum/npc_subtile_pending_intent/proc/valid()\n',
                        '/datum/npc_subtile_recovery\n')
        body = valid.split('\t\tif ("' + kind + '")', 1)[1]
        if next_kind:
            body = body.split('\t\tif ("' + next_kind + '")', 1)[0]
        return next(line.strip()[len('return '):] for line in body.splitlines()
                    if line.strip().startswith('return '))

    def test_replaced_cancelled_or_changed_context_is_invalid(self):
        self.assertFalse(evaluate(self.rejection(), self.context))
        changes = (
            lambda: setattr(self.actor, 'npc_subtile_pending_intent', object()),
            lambda: setattr(self.actor, 'move_gen', 6),
            lambda: setattr(self.actor, 'client', object()),
            lambda: setattr(self.actor, 'stat', 1),
            lambda: setattr(self.actor, 'stance', 'idle'),
            lambda: setattr(self.actor, 'behaviour', 'wander'),
            lambda: setattr(self.actor, 'target_mob', object()),
            lambda: setattr(self.actor, 'following_mob', object()),
            lambda: setattr(self.actor, 'npc_subtile_recovery_enabled', False),
            lambda: self.context.update(target=None),
        )
        for change in changes:
            with self.subTest(change=change):
                self.setUp()
                change()
                self.assertTrue(evaluate(self.rejection(), self.context))

    def test_pursuit_follow_and_flee_revalidate_before_replay(self):
        self.assertTrue(evaluate(self.mode_guard('pursuit', 'follow'), self.context))
        self.context['view'] = lambda distance, actor: [] if distance == 7 else [self.target]
        self.assertTrue(evaluate(self.mode_guard('pursuit', 'follow'), self.context))
        self.context['view'] = lambda distance, actor: []
        self.assertFalse(evaluate(self.mode_guard('pursuit', 'follow'), self.context))
        self.setUp()
        self.actor.following_mob = self.target
        self.assertTrue(evaluate(self.mode_guard('follow', 'flee'), self.context))
        self.context['get_dist'] = lambda actor, target: 7
        self.assertFalse(evaluate(self.mode_guard('follow', 'flee'), self.context))
        self.setUp()
        flee = self.mode_guard('flee', 'pet')
        self.assertTrue(evaluate(flee, self.context))
        self.context['world'].time = 60
        self.assertFalse(evaluate(flee, self.context))

    def test_deferred_side_is_rejected_if_either_turf_changes(self):
        pursuit = self.mode_guard('pursuit', 'follow')
        origin, destination = object(), object()
        self.context.update(side_direction=4, side_origin=origin, side_target=destination,
            target_turf=destination, get_turf=lambda actor: origin)
        self.assertTrue(evaluate(pursuit, self.context))
        self.context['get_turf'] = lambda actor: object()
        self.assertFalse(evaluate(pursuit, self.context))
        self.context.update(get_turf=lambda actor: origin, target_turf=object())
        self.assertFalse(evaluate(pursuit, self.context))
        valid = section(self.source, '/datum/npc_subtile_pending_intent/proc/valid()\n',
                        '/datum/npc_subtile_recovery\n')
        self.assertIn('side_direction = 0\n\t\tside_origin = null\n\t\tside_target = null', valid)
        self.assertLess(valid.index('side_direction = 0'), valid.index('switch (kind)'))
        self.context['side_direction'] = 0
        self.assertTrue(evaluate(pursuit, self.context))

    def test_single_slot_expiry_and_consume_before_dispatch(self):
        defer = section(self.source, '/mob/living/simple_animal/proc/npc_subtile_defer_intent(',
                        '/mob/living/simple_animal/proc/npc_subtile_cancel_pending(')
        self.assertEqual(defer.count('npc_subtile_pending_intent = P'), 1)
        self.assertIn('npc_subtile_pending_intent = previous\n\t\tnpc_subtile_prune_pending()', defer)
        self.assertIn('P.expires_at = world.time + 50', defer)
        self.assertNotIn('spawn(', defer)
        self.assertNotIn('+=', defer)
        dispatch = section(self.source, '/mob/living/simple_animal/proc/npc_subtile_dispatch_pending()\n',
                           '/datum/npc_subtile_pending_intent\n')
        self.assertLess(dispatch.index('npc_subtile_prune_pending()'), dispatch.index('switch (P.kind)'))
        self.assertLess(dispatch.index('npc_subtile_pending_intent = null'), dispatch.index('switch (P.kind)'))
        for guard in ('npc_subtile_recovery', 'npc_subtile_transaction', '!npc_subtile_ready()',
                      'npc_subtile_offset_owned && (step_x || step_y)', '!npc_subtile_intent_valid(null)'):
            self.assertIn(guard, dispatch)

    def test_invalid_direct_replacement_leaves_pending_intact(self):
        source_by_kind = {
            'pursuit': (TACTICAL.read_text(encoding='utf-8'), '/mob/living/simple_animal/proc/npc_subtile_start_pursuit('),
            'follow': (self.source, '/mob/living/simple_animal/proc/npc_subtile_start_follow('),
            'flee': (self.source, '/mob/living/simple_animal/proc/npc_subtile_start_flee('),
            'pet': (self.source, '/mob/living/simple_animal/pet/proc/npc_subtile_start_pet_walk('),
        }
        target = object()
        target_turf = SimpleNamespace(z=1)
        context = dict(npc_subtile_can_defer=lambda: False, npc_subtile_enabled=True,
            npc_subtile_pursuit_enabled=True, npc_subtile_follow_enabled=True,
            npc_subtile_flee_enabled=True, npc_subtile_pet_enabled=True,
            npc_subtile_ready=lambda: True, npc_subtile_pursuit=None, npc_subtile_flee=None,
            target=target, target_mob=target, following_mob=target, movement_target=target,
            flee_target=target, SA_attackable=lambda item: True, z=1, target_turf=target_turf,
            get_turf=lambda item: target_turf, get_dist=lambda actor, item: 3,
            src=object(), aggro_vision_range=7, idle_vision_range=9,
            view=lambda distance, actor: [target], side_direction=0,
            alldirs=(1, 2, 4, 8, 5, 6, 9, 10), mode='towards', distance_limit=7,
            max_distance=7, interval=2, world=SimpleNamespace(tick_lag=.5),
            isnum=lambda item: isinstance(item, (int, float)), list=lambda *items: items)

        def rejected(kind, ctx):
            source, declaration = source_by_kind[kind]
            prefix = source.split(declaration, 1)[1].split('npc_subtile_pending_intent = null', 1)[0]
            lines = prefix.splitlines()
            guards = []
            for index, line in enumerate(lines):
                if line.startswith('\tif ('):
                    expression = line.strip()[3:]
                    if 'npc_subtile_can_defer()' in expression:
                        continue
                    self.assertEqual(lines[index + 1].strip(), 'return FALSE', kind)
                    guards.append(expression)
            self.assertGreaterEqual(len(guards), 2, kind)
            return any(evaluate(guard, ctx) for guard in guards)

        for kind in source_by_kind:
            with self.subTest(kind=kind, state='valid'):
                self.assertFalse(rejected(kind, context))
            for name, value in (('npc_subtile_' + kind + '_enabled', False),
                                ('npc_subtile_ready', lambda: False), ('target', None)):
                with self.subTest(kind=kind, state=name):
                    changed = dict(context)
                    changed[name] = value
                    self.assertTrue(rejected(kind, changed))
        for kind, field in (('pursuit', 'target_mob'), ('follow', 'following_mob'),
                            ('pet', 'movement_target')):
            changed = dict(context)
            changed[field] = object()
            self.assertTrue(rejected(kind, changed), kind)
        changed = dict(context, get_dist=lambda actor, item: 8)
        self.assertTrue(rejected('follow', changed))
        self.assertTrue(rejected('flee', changed))
        self.assertFalse(rejected('pet', changed))  # towards has no fixed range cutoff

    def test_ineligible_owned_offset_can_wait_before_recovery_exists(self):
        body = section(self.source, '/mob/living/simple_animal/proc/npc_subtile_can_defer()\n',
                       '// Only automatic cleanup')
        expression = next(line.strip()[len('return '):] for line in body.splitlines()
                          if line.strip().startswith('return '))
        context = dict(npc_subtile_recovery=None, npc_subtile_recovery_enabled=True,
                       npc_subtile_offset_owned=True, step_x=30, step_y=0,
                       npc_subtile_ready=lambda: False, client=None, stat=0)
        self.assertTrue(evaluate(expression, context))
        for key, value in (('npc_subtile_recovery_enabled', False),
                           ('npc_subtile_offset_owned', False), ('client', object()), ('stat', 1)):
            changed = dict(context)
            changed[key] = value
            self.assertFalse(evaluate(expression, changed))
        changed = dict(context)
        changed['step_x'] = changed['step_y'] = 0
        self.assertFalse(evaluate(expression, changed))

    def test_generation_transfer_and_explicit_stop_cancel(self):
        request = section(self.source, '/mob/living/simple_animal/proc/npc_subtile_request_recovery()\n',
                          '/mob/living/simple_animal/proc/npc_subtile_defer_intent(')
        self.assertLess(request.index('npc_subtile_prune_pending()'), request.index('move_gen++'))
        self.assertIn('npc_subtile_pending_intent.generation == previous_generation', request)
        finish = section(self.source, '/datum/npc_subtile_recovery/proc/finish()\n',
                         '/mob/living/simple_animal/proc/npc_subtile_start_follow(')
        self.assertLess(finish.index('npc_subtile_prune_pending()'), finish.index('move_gen++'))
        self.assertLess(finish.index('npc_subtile_pending_intent.generation = actor.move_gen'),
                        finish.index('npc_subtile_dispatch_pending()'))
        self.assertIn('if (actor.move_gen == generation && actor.npc_subtile_intent_valid(src))\n\t\t\tactor.npc_subtile_prune_pending()\n\t\telse\n\t\t\tactor.npc_subtile_pending_intent = null', finish)
        for path, name in ((SOURCE, 'follow'), (SOURCE, 'flee'), (SOURCE, 'pet_walk'),
                           (TACTICAL, 'pursuit')):
            source = path.read_text(encoding='utf-8')
            stop = source.split('/mob/living/simple_animal/proc/npc_subtile_stop_' + name + '(', 1)[1].split('\n/', 1)[0]
            pending_kind = 'pet' if name == 'pet_walk' else name
            self.assertIn('npc_subtile_cancel_pending("' + pending_kind + '")', stop)
            self.assertIn('npc_subtile_release_generation(', stop)
            self.assertIn('generation, TRUE)', stop)
            self.assertLess(stop.index('npc_subtile_cancel_pending('), stop.index('npc_subtile_release_generation('))
        release = section(self.source, '/mob/living/simple_animal/proc/npc_subtile_release_generation(',
                          '/mob/living/simple_animal/proc/npc_subtile_cancel_pending(')
        self.assertLess(release.index('npc_subtile_prune_pending()'), release.index('move_gen++'))
        self.assertIn('npc_subtile_pending_intent.generation == generation', release)
        scared = AI.read_text(encoding='utf-8').split('\t\tif ("scared")', 1)[1].split('\t\tif ("wander")', 1)[0]
        self.assertIn('npc_subtile_stop_continuous_walk()', scared)

    def test_control_death_and_deletion_clear_pending(self):
        animal = (ROOT / 'code/game/mob/living/simple_animal/simple_animal.dm').read_text(encoding='utf-8')
        login = section(animal, '/mob/living/simple_animal/Login()\n',
                        '/mob/living/simple_animal/adjustBruteLoss(')
        self.assertIn('npc_subtile_pending_intent = null', login)
        life = section(animal, '/mob/living/simple_animal/Life()\n',
                       '\tif (health > maxHealth)')
        self.assertIn('if (npc_subtile_pending_intent && (client || stat))', life)
        self.assertLess(life.index('npc_subtile_pending_intent = null'), life.index('if (stat == DEAD)'))
        self.assertIn('/mob/living/simple_animal/Destroy()\n\tnpc_subtile_pending_intent = null', animal)
        self.assertIn('/mob/living/simple_animal/death(gibbed, deathmessage = "dies!")\n\tnpc_subtile_pending_intent = null', animal)
        advance = section(self.source, '/datum/npc_subtile_transaction/proc/advance()\n',
                          '/datum/npc_subtile_transaction/proc/perform_rest(')
        self.assertLess(advance.index('actor.npc_subtile_prune_pending_fast()'), advance.index('if (!valid()'))
        fast = section(self.source, '/mob/living/simple_animal/proc/npc_subtile_prune_pending_fast()\n',
                       '/mob/living/simple_animal/proc/npc_subtile_dispatch_pending()')
        self.assertIn('.base_valid()', fast)
        self.assertNotIn('view(', fast)

    def test_runtime_only_and_no_species_activation(self):
        self.assertIn('/datum/npc_subtile_pending_intent\n\tshould_save = FALSE', self.source)
        self.assertIn('"npc_subtile_pending_intent"', self.source)
        for path in (ROOT / 'code').rglob('*.dm'):
            self.assertNotIn('npc_subtile_recovery_enabled = TRUE',
                             path.read_text(encoding='utf-8', errors='replace'), str(path))


if __name__ == '__main__':
    unittest.main()
