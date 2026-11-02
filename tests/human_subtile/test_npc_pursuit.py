"""Offline pursuit ownership and cadence contracts, not native DM execution."""
from pathlib import Path
from types import SimpleNamespace
import re
import unittest
import importlib.util
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
TACTICAL = ROOT / 'code/game/mob/living/simple_animal/hostile/tactical_ai.dm'
SUBTILE = ROOT / 'code/game/mob/living/simple_animal/subtile_movement.dm'


def section(source, start, end):
    return source.split(start, 1)[1].split(end, 1)[0]


def evaluate(expression, context):
    expression = expression.replace('&&', ' and ').replace('||', ' or ')
    expression = re.sub(r'!(?!=)', ' not ', expression).strip()
    return bool(eval(expression, {'__builtins__': {}}, context))


class PursuitContracts(unittest.TestCase):
    def setUp(self):
        self.source = TACTICAL.read_text(encoding='utf-8')
        self.owner = object()
        self.target = SimpleNamespace()
        self.actor = SimpleNamespace(npc_subtile_pursuit=self.owner,
            npc_subtile_pursuit_enabled=True, npc_subtile_enabled=True,
            npc_subtile_ready=lambda: True, npc_subtile_pet_walk=None, moving=True, move_gen=3,
            target_obj=self.target, target_mob=self.target, stance='attack',
            SA_attackable=lambda target: True, aggro_vision_range=7, idle_vision_range=7)
        self.context = dict(cancelled=False, actor=self.actor, target=self.target,
            src=self.owner, generation=3, expected_stance='attack',
            isDeleted=lambda item: False, view=lambda distance, actor: [self.target])

    def guard(self):
        body = section(self.source, '/datum/npc_subtile_pursuit/proc/valid()\n',
                       '/datum/npc_subtile_pursuit/proc/try_direction(')
        return next(line.strip()[len('return '):] for line in body.splitlines()
                    if line.strip().startswith('return '))

    def test_owner_and_target_invalidation(self):
        self.assertTrue(evaluate(self.guard(), self.context))
        mutations = (
            lambda: self.context.update(cancelled=True),
            lambda: setattr(self.actor, 'npc_subtile_pursuit', object()),
            lambda: setattr(self.actor, 'npc_subtile_pet_walk', object()),
            lambda: setattr(self.actor, 'move_gen', 4),
            lambda: setattr(self.actor, 'target_mob', object()),
            lambda: setattr(self.actor, 'target_obj', object()),
            lambda: setattr(self.actor, 'stance', 'idle'),
            lambda: setattr(self.actor, 'npc_subtile_ready', lambda: False),
            lambda: setattr(self.actor, 'npc_subtile_enabled', False),
            lambda: self.context.update(view=lambda distance, actor: []),
            lambda: setattr(self.actor, 'SA_attackable', lambda target: False),
        )
        for mutate in mutations:
            with self.subTest(mutate=mutate):
                self.setUp()
                mutate()
                self.assertFalse(evaluate(self.guard(), self.context))

    def test_same_target_coalesces_and_retarget_invalidates_generation(self):
        start = section(self.source, '/mob/living/simple_animal/proc/npc_subtile_start_pursuit(',
                        '/datum/npc_subtile_pursuit\n')
        self.assertLess(start.index('npc_subtile_pursuit.target == target'),
                        start.index('npc_subtile_stop_pursuit()'))
        self.assertLess(start.index('walk(src, 0)'), start.index('P.perform()'))
        self.assertLess(start.index('walk_id = 0'), start.index('P.perform()'))
        self.assertLess(start.index('move_gen++'), start.index('P.generation = move_gen'))
        stop = section(self.source, '/mob/living/simple_animal/proc/npc_subtile_stop_pursuit(',
                       '/mob/living/simple_animal/proc/npc_subtile_start_pursuit(')
        for contract in ('P.cancelled = TRUE', 'npc_subtile_pursuit = null',
                         'if (move_gen == P.generation)', 'npc_subtile_release_generation(P.generation, TRUE)'):
            self.assertIn(contract, stop)

    def test_no_double_interval_or_partial_step_retry(self):
        loop = section(self.source, '/datum/npc_subtile_pursuit/proc/perform_loop()\n',
                       '/mob/living/simple_animal/proc/MoveToTarget()')
        self.assertIn('var/deadline = started + delay', loop)
        self.assertIn('try_direction(direction, delay)', loop)
        self.assertIn('world.time == started && human_subtile_same(before, actor.npc_subtile_snapshot())', loop)
        self.assertEqual(loop.count('sleep('), 2)
        self.assertIn('sleep(deadline - world.time)', loop)
        self.assertIn('sleep(0)', loop)
        self.assertNotIn('sleep(delay)', loop)
        step = section(self.source, '/datum/npc_subtile_pursuit/proc/try_direction(',
                       '/datum/npc_subtile_pursuit/proc/perform()')
        self.assertIn('actor.ai_step_wait(', step)

    def test_attack_still_uses_ai_tick_after_target_validation(self):
        attack = section(self.source, '/mob/living/simple_animal/proc/AttackTarget()\n',
                         '/mob/living/simple_animal/proc/AttackingTarget()')
        gate = 'if (npc_subtile_pursuit_enabled && npc_subtile_pursuit && npc_subtile_transaction)'
        self.assertLess(attack.index('SA_attackable(target_mob)'), attack.index(gate))
        self.assertLess(attack.index(gate), attack.index('AttackingTarget()'))
        self.assertNotIn('AttackingTarget()', section(self.source,
            '/datum/npc_subtile_pursuit/proc/perform_loop()\n',
            '/mob/living/simple_animal/proc/MoveToTarget()'))
        expression = gate[4:-1]
        for values, expected in (((True, True, True), True),
                                 ((False, True, True), False),
                                 ((True, False, True), False),
                                 ((True, True, False), False)):
            self.assertEqual(evaluate(expression, dict(zip(
                ('npc_subtile_pursuit_enabled', 'npc_subtile_pursuit', 'npc_subtile_transaction'),
                values))), expected)

    def test_partial_owned_offset_blocks_attack_even_without_worker(self):
        attack = section(self.source, '/mob/living/simple_animal/proc/AttackTarget()\n',
                         '/mob/living/simple_animal/proc/AttackingTarget()')
        offset_gate = 'if (npc_subtile_pursuit_enabled && npc_subtile_pursuit_unsettled())'
        self.assertLess(attack.index(offset_gate), attack.index('AttackingTarget()'))
        self.assertIn('if (!npc_subtile_pursuit)\n\t\t\t\tnpc_subtile_start_pursuit(target_mob)', attack)
        self.assertIn('npc_subtile_offset_owned && (step_x || step_y)', self.source)
        for owned, sx, sy, expected in ((True, 30, 0, True), (True, 0, 30, True),
                                        (True, 0, 0, False), (False, 30, 0, False)):
            self.assertEqual(evaluate('npc_subtile_offset_owned && (step_x || step_y)',
                dict(npc_subtile_offset_owned=owned, step_x=sx, step_y=sy)), expected)
        loop = section(self.source, '/datum/npc_subtile_pursuit/proc/perform_loop()\n',
                       '/mob/living/simple_animal/proc/MoveToTarget()')
        self.assertIn('get_dist(actor, target) > 1 || actor.npc_subtile_pursuit_unsettled()', loop)
        self.assertIn('settle_axis()', loop)
        settle = section(self.source, '/datum/npc_subtile_pursuit/proc/settle_axis()\n',
                         '/datum/npc_subtile_pursuit/proc/perform()')
        self.assertIn('actor.npc_subtile_settle_axis(src, actor.move_to_delay)', settle)
        common = section(SUBTILE.read_text(encoding='utf-8'),
                         '/mob/living/simple_animal/proc/npc_subtile_settle_axis(',
                         '/mob/living/simple_animal/proc/npc_subtile_request_recovery()')
        self.assertIn('ai_step_wait(get_step(src, direction), interval, owner)', common)
        self.assertIn('ai_step_wait(get_step(src, turn(direction, 180)), other_interval, owner)', common)
        self.assertIn('human_subtile_same(before, npc_subtile_snapshot())', common)
        self.assertNotIn('forceMove', common)

    def test_ai_tick_side_decision_is_bounded_and_serialized(self):
        move = section(self.source, '/mob/living/simple_animal/proc/MoveToTarget()\n',
                       '/mob/living/simple_animal/proc/AttackTarget()')
        staged = move.split('if (npc_subtile_enabled && npc_subtile_pursuit_enabled)\n', 1)[1].split('\n\t// Stuck detection', 1)[0]
        for contract in ('if (loc == last_loc)', 'stuck_ticks++', 'if (stuck_ticks >= 3)',
                         'pick(turn(dir_to_target, 90), turn(dir_to_target, -90))',
                         'npc_subtile_start_pursuit(target_mob, side_step_dir)',
                         'if (stuck_ticks >= 6 && destroy_surroundings)', 'stuck_ticks = 0'):
            self.assertIn(contract, staged)
        self.assertEqual(staged.count('pick('), 1)
        self.assertNotIn('step(src, side_step_dir)', staged)
        loop = section(self.source, '/datum/npc_subtile_pursuit/proc/perform_loop()\n',
                       '/mob/living/simple_animal/proc/MoveToTarget()')
        self.assertIn('var/side_direction = pending_side', loop)
        self.assertIn('pending_side = 0', loop)
        self.assertIn('get_turf(actor) == side_origin && get_turf(target) == side_target', loop)
        self.assertIn('perform_side(side_direction, actor.move_to_delay)', loop)
        side = section(self.source, '/datum/npc_subtile_pursuit/proc/perform_side(',
                       '/datum/npc_subtile_pursuit/proc/perform()')
        self.assertNotIn('pick(', side)
        self.assertIn('try_direction(direction, interval)', side)
        self.assertIn('try_direction(turn(direction, 180), interval)', side)
        attack = section(self.source, '/mob/living/simple_animal/proc/AttackTarget()\n',
                         '/mob/living/simple_animal/proc/AttackingTarget()')
        self.assertLess(attack.index('if (get_dist(src, target_mob) <= 1)'),
                        attack.index('npc_subtile_pursuit_unsettled()'))

    def test_stage_is_disabled_and_runtime_state_is_not_saved(self):
        self.assertIn('var/npc_subtile_pursuit_enabled = FALSE', self.source)
        for path in (ROOT / 'code').rglob('*.dm'):
            self.assertNotIn('npc_subtile_pursuit_enabled = TRUE', path.read_text(encoding='utf-8', errors='replace'), str(path))
        save = SUBTILE.read_text(encoding='utf-8')
        self.assertIn('"npc_subtile_pursuit_enabled"', save)
        self.assertIn('"npc_subtile_pursuit"', save)
        self.assertIn('should_save = FALSE', section(self.source,
            '/datum/npc_subtile_pursuit\n', '/datum/npc_subtile_pursuit/proc/valid()'))


class DisabledPursuitFallback(unittest.TestCase):
    """Project the real dispatch/setter bodies with explicit movement boundaries."""
    @classmethod
    def setUpClass(cls):
        spec = importlib.util.spec_from_file_location("disabled_pursuit_adapter", ROOT / "tests/save_movement/source_adapter.py")
        cls.adapter = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.adapter)

    def setUp(self):
        self.calls = []
        self.target = object()
        self.location = object()
        self.actor = SimpleNamespace(npc_subtile_enabled=False, npc_subtile_pursuit_enabled=True,
            npc_subtile_pursuit=None, npc_subtile_pending_intent=None, npc_subtile_wild_walk=None, npc_subtile_transaction=None,
            npc_subtile_pulse=None, npc_subtile_offset_owned=False, step_x=0, step_y=0,
            move_gen=3, moving=False, found_path=[], target_obj=None, target_mob=self.target,
            stance="idle", loc=self.location, last_loc=object(), stuck_ticks=0,
            aggro_vision_range=7, idle_vision_range=7, move_to_delay=3, destroy_surroundings=False)
        a = self.actor
        a.npc_subtile_shape = lambda: True
        a.npc_subtile_release_glide = lambda: self.calls.append("release_glide")
        def cancel_pending(kind):
            if a.npc_subtile_pending_intent == kind: a.npc_subtile_pending_intent = None
        def release_generation(generation, transfer_pending):
            if a.move_gen != generation: return False
            a.move_gen += 1
            return True
        a.npc_subtile_cancel_pending = cancel_pending
        a.npc_subtile_release_generation = release_generation
        def stop():
            self.calls.append("stop_pursuit")
            return self.stop(a)
        a.npc_subtile_stop_pursuit = stop
        a.npc_subtile_stop_wild_walk = lambda: self.calls.append("stop_wild")
        def ai_step(*args):
            self.calls.append(("ai_step", args))
            return 2 if a.npc_subtile_enabled and not a.npc_subtile_transaction else False
        a.ai_step = ai_step
        a.Move = lambda *args: self.calls.append(("Move", args)) or True
        def do_movement(target):
            self.calls.append(("legacy_path", target))
            a.move_gen += 1
            a.moving = True
            a.target_obj = target
        a.do_movement = do_movement
        a.SA_attackable = lambda target: True
        a.npc_subtile_start_pursuit = lambda *args: self.calls.append(("staged_pursuit", args)) or True
        a.DestroySurroundings = lambda: self.calls.append("destroy")
        env = dict(isDeleted=lambda actor: False, view=lambda *_: [self.target],
            walk=lambda *_: self.calls.append("walk_stop"), get_dir=lambda *_: 4,
            turn=lambda direction, degrees: (direction, degrees), pick=lambda *xs: xs[0],
            step=lambda *args: self.calls.append(("step", args)) or True,
            HOSTILE_STANCE_IDLE="idle", HOSTILE_STANCE_ATTACK="attack")
        fields = ("npc_subtile_enabled", "npc_subtile_pursuit_enabled", "npc_subtile_pursuit",
            "npc_subtile_pending_intent", "npc_subtile_wild_walk", "npc_subtile_transaction", "npc_subtile_pulse",
            "npc_subtile_offset_owned", "step_x", "step_y", "npc_subtile_shape", "npc_subtile_release_glide",
            "npc_subtile_stop_pursuit", "npc_subtile_stop_wild_walk", "npc_subtile_start_pursuit", "npc_subtile_cancel_pending",
            "npc_subtile_release_generation", "move_gen", "moving", "found_path", "target_obj", "ai_step", "Move",
            "move_to_delay", "target_mob", "SA_attackable", "stance", "last_loc", "stuck_ticks",
            "aggro_vision_range", "idle_vision_range", "destroy_surroundings", "DestroySurroundings",
            "actor", "target")
        with patch.object(self.adapter, "FIELDS", self.adapter.FIELDS + fields):
            self.stop = self.adapter.project(TACTICAL.read_text(),
                "/mob/living/simple_animal/proc/npc_subtile_stop_pursuit", "src, cancel_pending=True", env, method=True)
            self.wander = self.adapter.project(TACTICAL.read_text(),
                "/mob/living/simple_animal/proc/npc_subtile_combat_wander", "src, destination", env, method=True)
            self.pursue = self.adapter.project(TACTICAL.read_text(),
                "/mob/living/simple_animal/proc/MoveToTarget", "src", env, method=True)
            self.enable = self.adapter.project(SUBTILE.read_text(),
                "/mob/living/simple_animal/proc/set_npc_subtile", "src, enabled", env, method=True)
            self.finish = self.adapter.project(TACTICAL.read_text(),
                "/datum/npc_subtile_pursuit/proc/finish", "src", env, method=True)

    def test_disabled_pursuit_flags_route_both_producers_to_legacy(self):
        for enabled, pursuit, staged in ((False, True, False), (False, False, False),
                                         (True, False, False), (True, True, True)):
            with self.subTest(enabled=enabled, pursuit=pursuit):
                self.setUp(); self.actor.npc_subtile_enabled=enabled; self.actor.npc_subtile_pursuit_enabled=pursuit
                self.wander(self.actor, self.location)
                self.pursue(self.actor)
                names=[x[0] for x in self.calls if isinstance(x,tuple)]
                self.assertEqual(names, ["ai_step", "staged_pursuit"] if staged else ["Move", "legacy_path"])

    def test_successful_disable_retires_old_owner_before_legacy_replacement(self):
        a=self.actor; a.npc_subtile_enabled=True; a.moving=True; a.target_obj=self.target
        old=SimpleNamespace(actor=a,target=self.target,generation=a.move_gen,cancelled=False)
        a.npc_subtile_pursuit=old; a.npc_subtile_pending_intent="pursuit"
        self.assertTrue(self.enable(a, False))
        self.assertFalse(a.npc_subtile_enabled); self.assertTrue(old.cancelled)
        self.assertIsNone(a.npc_subtile_pursuit); self.assertIsNone(a.npc_subtile_pending_intent)
        self.pursue(a); generation=a.move_gen
        self.assertTrue(a.moving); self.assertIs(a.target_obj,self.target)
        self.finish(old)
        self.assertEqual(a.move_gen,generation); self.assertTrue(a.moving); self.assertIs(a.target_obj,self.target)
        self.assertEqual(sum(x=="stop_pursuit" for x in self.calls),1)

    def test_direct_disabled_stale_owner_retires_before_legacy_dispatch(self):
        for operation in ("wander", "pursue"):
            with self.subTest(operation=operation):
                self.setUp()
                a = self.actor
                a.npc_subtile_enabled = False
                old = SimpleNamespace(actor=a, target=self.target, generation=a.move_gen, cancelled=False)
                a.npc_subtile_pursuit = old
                if operation == "wander":
                    self.wander(a, self.location)
                    expected = "Move"
                else:
                    self.pursue(a)
                    expected = "legacy_path"
                names = [x[0] if isinstance(x, tuple) else x for x in self.calls]
                self.assertLess(names.index("stop_pursuit"), names.index(expected))
                self.assertTrue(old.cancelled)
                self.assertIsNone(a.npc_subtile_pursuit)
                generation = a.move_gen
                before = (a.moving, a.target_obj)
                self.finish(old)
                self.assertEqual(a.move_gen, generation)
                self.assertEqual((a.moving, a.target_obj), before)
                self.assertEqual(sum(x == "stop_pursuit" for x in self.calls), 1)

    def test_disable_rejected_while_pulse_owned_without_retiring_owner(self):
        a=self.actor; a.npc_subtile_enabled=True; a.npc_subtile_transaction=object()
        owner=SimpleNamespace(actor=a,target=self.target,generation=a.move_gen,cancelled=False);a.npc_subtile_pursuit=owner
        self.assertFalse(self.enable(a,False)); self.assertTrue(a.npc_subtile_enabled)
        self.assertIs(a.npc_subtile_pursuit,owner); self.assertFalse(owner.cancelled)
        self.assertNotIn("stop_pursuit",self.calls)

    def test_direct_disabled_owned_partial_or_active_pulse_never_moves_legacy(self):
        for field in ("npc_subtile_transaction", "npc_subtile_pulse", "partial"):
            with self.subTest(field=field):
                self.setUp();a=self.actor
                if field=="partial": a.npc_subtile_offset_owned=True; a.step_x=2
                else: setattr(a,field,object())
                self.assertFalse(self.wander(a,self.location));self.pursue(a)
                self.assertFalse(any(isinstance(x,tuple) and x[0] in ("Move","legacy_path") for x in self.calls))

    def test_legacy_stuck_side_and_destruction_policy_remain(self):
        a=self.actor;a.last_loc=a.loc;a.stuck_ticks=5;a.destroy_surroundings=True
        self.pursue(a)
        self.assertEqual([x[0] if isinstance(x,tuple) else x for x in self.calls],["step","destroy"])
        self.assertEqual(a.stuck_ticks,0)



if __name__ == '__main__':
    unittest.main()
