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
        self.assertIn('npc_subtile_start_flee(H, 7, npc_subtile_native_interval(2))', scared)
        self.assertIn('walk_away_od(src, H, 7, 2)', scared)
        self.assertEqual(scared.count('spawn(50)'), 2)
        self.assertIn('npc_subtile_stop_continuous_walk()', scared)
        self.assertEqual(scared.count('walk(src, 0)'), 1)

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
