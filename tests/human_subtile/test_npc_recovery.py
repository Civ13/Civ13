"""Offline recovery admission and transition contracts; no BYOND execution."""
from pathlib import Path
from types import SimpleNamespace
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/game/mob/living/simple_animal/subtile_movement.dm'
TACTICAL = ROOT / 'code/game/mob/living/simple_animal/hostile/tactical_ai.dm'
ANIMAL = ROOT / 'code/game/mob/living/simple_animal/simple_animal.dm'


def section(source, start, end):
    return source.split(start, 1)[1].split(end, 1)[0]


def evaluate(expression, context):
    expression = expression.replace('&&', ' and ').replace('||', ' or ').replace('null', 'None')
    expression = re.sub(r'!(?!=)', ' not ', expression).strip()
    return bool(eval(expression, {'__builtins__': {}}, context))


class RecoveryContracts(unittest.TestCase):
    def setUp(self):
        self.source = SOURCE.read_text(encoding='utf-8')
        self.context = dict(npc_subtile_recovery_enabled=True, npc_subtile_enabled=True,
            npc_subtile_ready=lambda: True, npc_subtile_offset_owned=True,
            step_x=30, step_y=0, npc_subtile_transaction=None,
            world=SimpleNamespace(time=10), npc_subtile_until=10,
            npc_subtile_intent_valid=lambda owner: owner is None)

    def admitted(self):
        request = section(self.source, '/mob/living/simple_animal/proc/npc_subtile_request_recovery()\n',
                          '/datum/npc_subtile_recovery\n')
        rejection = next(line.strip()[3:] for line in request.splitlines()
                         if line.strip().startswith('if ('))
        return not evaluate(rejection, self.context)

    def test_reeligibility_retries_owned_offsets_only(self):
        self.assertTrue(self.admitted())
        mutations = (
            lambda: self.context.update(npc_subtile_recovery_enabled=False),
            lambda: self.context.update(npc_subtile_ready=lambda: False),
            lambda: self.context.update(npc_subtile_offset_owned=False),
            lambda: self.context.update(step_x=0, step_y=0),
            lambda: self.context.update(npc_subtile_transaction=object()),
            lambda: self.context.update(npc_subtile_until=11),
            lambda: self.context.update(npc_subtile_intent_valid=lambda owner: False),
        )
        for mutate in mutations:
            with self.subTest(mutate=mutate):
                self.setUp()
                mutate()
                self.assertFalse(self.admitted())
        self.setUp()
        self.context['npc_subtile_ready'] = lambda: False
        self.assertFalse(self.admitted())
        self.context['npc_subtile_ready'] = lambda: True
        self.assertTrue(self.admitted())

    def test_recovery_is_retried_before_life_selects_follow_or_ai(self):
        life = section(ANIMAL.read_text(encoding='utf-8'),
                       '/mob/living/simple_animal/Life()\n', '// AI and Movement logic')
        self.assertLess(life.index('npc_subtile_request_recovery()'), life.index('if (following_mob)'))
        request = section(self.source, '/mob/living/simple_animal/proc/npc_subtile_request_recovery()\n',
                          '/datum/npc_subtile_recovery\n')
        self.assertLess(request.index('walk(src, 0)'), request.index('R.perform()'))
        self.assertLess(request.index('walk_id = 0'), request.index('R.perform()'))
        self.assertIn('move_gen++', request)
        ai = (ROOT / 'code/game/mob/living/simple_animal/simple_ai.dm').read_text(encoding='utf-8')
        self.assertNotIn('if (npc_subtile_recovery)\n\t\treturn', ai)

    def test_blocked_attempt_relinquishes_owner_for_bounded_retry(self):
        worker = section(self.source, '/datum/npc_subtile_recovery/proc/perform()\n',
                         '/datum/npc_subtile_recovery/proc/finish()')
        self.assertIn('var/list/before = actor.npc_subtile_snapshot()', worker)
        self.assertIn('if (valid() && human_subtile_same(before, actor.npc_subtile_snapshot()))\n\t\t\t\tbreak', worker)
        self.assertIn('finish()', worker)
        settle = section(self.source, '/mob/living/simple_animal/proc/npc_subtile_settle_axis(',
                         '/mob/living/simple_animal/proc/npc_subtile_request_recovery()')
        self.assertIn('sleep(max(world.tick_lag, interval_base))', settle)

    def test_alignment_uses_owned_native_pulses_and_no_snap(self):
        settle = section(self.source, '/mob/living/simple_animal/proc/npc_subtile_settle_axis(',
                         '/mob/living/simple_animal/proc/npc_subtile_request_recovery()')
        self.assertIn('npc_subtile_intent_valid(owner)', settle)
        self.assertIn('ai_step_wait(get_step(src, direction), interval, owner)', settle)
        self.assertIn('ai_step_wait(get_step(src, turn(direction, 180)), other_interval, owner)', settle)
        self.assertIn('interval_base * distance / 32', settle)
        self.assertIn('human_subtile_same(before, npc_subtile_snapshot())', settle)
        self.assertNotIn('forceMove', settle)
        self.assertNotRegex(settle, r'(?m)^\s*step_[xy]\s*=')
        for offset in range(1, 32):
            first = offset if offset <= 16 else 32 - offset
            self.assertGreater(first, 0)
            self.assertLessEqual(first, 16)
            self.assertEqual(first + (32 - first), 32)

    def test_other_owners_cannot_steal_active_recovery(self):
        sources = ((self.source, '/mob/living/simple_animal/proc/npc_subtile_start_follow('),
                   (self.source, '/mob/living/simple_animal/proc/npc_subtile_start_flee('),
                   (self.source, '/mob/living/simple_animal/pet/proc/npc_subtile_start_pet_walk('),
                   (TACTICAL.read_text(encoding='utf-8'), '/mob/living/simple_animal/proc/npc_subtile_start_pursuit('))
        for source, start in sources:
            with self.subTest(start=start):
                body = source.split(start, 1)[1].split('\n/', 1)[0]
                self.assertIn('if (npc_subtile_can_defer())\n\t\treturn npc_subtile_defer_intent(', body)
        self.assertIn('"npc_subtile_recovery"', self.source)
        self.assertIn('/datum/npc_subtile_recovery\n\tshould_save = FALSE', self.source)
        for path in (ROOT / 'code').rglob('*.dm'):
            self.assertNotIn('npc_subtile_recovery_enabled = TRUE',
                             path.read_text(encoding='utf-8', errors='replace'), str(path))


if __name__ == '__main__':
    unittest.main()
