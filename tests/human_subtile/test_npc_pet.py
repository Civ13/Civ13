"""Offline pet intent contracts; no native AI or movement is executed."""
from pathlib import Path
from types import SimpleNamespace
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/game/mob/living/simple_animal/subtile_movement.dm'
ANIMAL = ROOT / 'code/game/mob/living/simple_animal/simple_animal.dm'
CAT = ROOT / 'code/game/mob/living/simple_animal/friendly/cat.dm'
DOG = ROOT / 'code/game/mob/living/simple_animal/friendly/dogs.dm'


def section(source, start, end):
    return source.split(start, 1)[1].split(end, 1)[0]


def evaluate(expression, context):
    expression = expression.replace('&&', ' and ').replace('||', ' or ')
    expression = re.sub(r'!(?!=)', ' not ', expression).strip()
    return bool(eval(expression, {'__builtins__': {}}, context))


class PetContracts(unittest.TestCase):
    def setUp(self):
        self.source = SOURCE.read_text(encoding='utf-8')
        self.owner, self.target = object(), object()
        self.actor = SimpleNamespace(npc_subtile_pet_walk=self.owner,
            npc_subtile_pet_enabled=True, npc_subtile_enabled=True,
            npc_subtile_ready=lambda: True, npc_subtile_pursuit=None,
            npc_subtile_follow=None, npc_subtile_flee=None, move_gen=3,
            stance='idle', target_mob=None, target_obj=None, following_mob=None,
            movement_target=self.target, flee_target=None, z=1)
        self.context = dict(cancelled=False, actor=self.actor, src=self.owner,
            generation=3, target=self.target, expected_stance='idle',
            expected_combat_target=None, expected_path_target=None,
            expected_following=None, isDeleted=lambda item: False, mode='towards',
            destination=SimpleNamespace(z=1), distance_limit=0,
            get_dist=lambda actor, target: 2)

    def admitted(self):
        valid = section(self.source, '/datum/npc_subtile_pet_walk/proc/valid()\n',
                        '/datum/npc_subtile_pet_walk/proc/perform()')
        rejections = [line.strip()[3:] for line in valid.splitlines()
                      if line.strip().startswith('if (')]
        accept = next(line.strip()[len('return '):] for line in valid.splitlines()
                      if line.strip().startswith('return destination'))
        return not any(evaluate(guard, self.context) for guard in rejections) and evaluate(accept, self.context)

    def test_target_and_owner_transitions(self):
        self.assertTrue(self.admitted())
        mutations = (
            lambda: self.context.update(cancelled=True),
            lambda: setattr(self.actor, 'npc_subtile_pet_walk', object()),
            lambda: setattr(self.actor, 'npc_subtile_pursuit', object()),
            lambda: setattr(self.actor, 'npc_subtile_follow', object()),
            lambda: setattr(self.actor, 'npc_subtile_flee', object()),
            lambda: setattr(self.actor, 'move_gen', 4),
            lambda: setattr(self.actor, 'movement_target', None),
            lambda: setattr(self.actor, 'following_mob', object()),
            lambda: setattr(self.actor, 'npc_subtile_ready', lambda: False),
            lambda: self.context.update(destination=SimpleNamespace(z=2)),
        )
        for mutate in mutations:
            with self.subTest(mutate=mutate):
                self.setUp()
                mutate()
                self.assertFalse(self.admitted())
        self.setUp()
        self.context.update(mode='away', distance_limit=7)
        self.actor.flee_target = self.target
        self.assertTrue(self.admitted())
        self.context.update(get_dist=lambda actor, target: 8)
        self.assertFalse(self.admitted())

    def test_pet_producers_keep_scan_targets_and_intervals(self):
        source = ANIMAL.read_text(encoding='utf-8')
        self.assertIn('npc_subtile_start_pet_walk(movement_target, "towards", 0, npc_subtile_native_interval(3))', source)
        self.assertIn('walk_to(src, movement_target, 0, 3)', source)
        self.assertIn('npc_subtile_start_pet_walk(flee_target, "away", 7, npc_subtile_native_interval(2))', source)
        self.assertIn('walk_away_od(src, flee_target, 7, 2)', source)
        cat = CAT.read_text(encoding='utf-8')
        self.assertIn('npc_subtile_start_pet_walk(movement_target, "towards", near_dist, npc_subtile_native_interval(4))', cat)
        self.assertIn('walk_to(src, movement_target, near_dist, 4)', cat)
        for path in (CAT, DOG):
            body = path.read_text(encoding='utf-8')
            scan = body.split('if (turns_since_scan > 5)', 1)[1].split('turns_since_scan = FALSE', 1)[0]
            self.assertIn('npc_subtile_stop_pet_walk()', scan)
            self.assertIn('walk(src,0)', scan)

    def test_one_owner_and_no_extra_paid_interval(self):
        start = section(self.source, '/mob/living/simple_animal/pet/proc/npc_subtile_start_pet_walk(',
                        '/mob/living/simple_animal/proc/npc_subtile_stop_pet_walk(')
        for token in ('npc_subtile_stop_follow()', 'npc_subtile_stop_flee()',
                      'npc_subtile_stop_pursuit()', 'walk(src, 0)', 'move_gen++'):
            self.assertLess(start.index(token), start.index('P.perform()'))
        loop = section(self.source, '/datum/npc_subtile_pet_walk/proc/perform_loop()\n',
                       '/datum/npc_subtile_pulse\n')
        self.assertIn('actor.ai_step_wait(next, interval, src)', loop)
        self.assertIn('get_dist(actor, target) <= distance_limit && actor.npc_subtile_offset_owned && (actor.step_x || actor.step_y)', loop)
        self.assertIn('actor.npc_subtile_settle_axis(src, interval)\n\t\t\tbreak', loop)
        self.assertIn('get_step_to(actor, target, distance_limit)', loop)
        self.assertIn('get_step_away(actor, target, distance_limit)', loop)
        self.assertIn('sleep(deadline - world.time)', loop)
        self.assertNotIn('sleep(interval)', loop)

    def test_gate_is_off_and_runtime_worker_excluded(self):
        self.assertIn('var/npc_subtile_pet_enabled = FALSE', self.source)
        self.assertIn('"npc_subtile_pet_enabled"', self.source)
        self.assertIn('"npc_subtile_pet_walk"', self.source)
        self.assertIn('/datum/npc_subtile_pet_walk\n\tshould_save = FALSE', self.source)
        for path in (ROOT / 'code').rglob('*.dm'):
            self.assertNotIn('npc_subtile_pet_enabled = TRUE',
                             path.read_text(encoding='utf-8', errors='replace'), str(path))


if __name__ == '__main__':
    unittest.main()
