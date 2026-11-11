"""Offline leash-follow ownership contracts; no native movement is executed."""
from pathlib import Path
from types import SimpleNamespace
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/game/mob/living/simple_animal/subtile_movement.dm'
ANIMAL = ROOT / 'code/game/mob/living/simple_animal/simple_animal.dm'
TACTICAL = ROOT / 'code/game/mob/living/simple_animal/hostile/tactical_ai.dm'


def section(source, start, end):
    return source.split(start, 1)[1].split(end, 1)[0]


def evaluate(expression, context):
    expression = expression.replace('&&', ' and ').replace('||', ' or ')
    expression = re.sub(r'!(?!=)', ' not ', expression).strip()
    return bool(eval(expression, {'__builtins__': {}}, context))


# Frozen pre-change follow block. This restricted Python projection compares the
# source flow; it does not execute DM or prove native scheduling or movement.
FOLLOW_BASELINE = '''\
if (following_mob)
\tstop_automated_movement = TRUE
\tif (get_dist(src, following_mob) > 2)
\t\tturns_since_move++
\t\tif (turns_since_move >= move_to_delay)
\t\t\tif (get_dist(src, following_mob) > 1)
\t\t\t\tif (npc_subtile_follow_enabled && npc_subtile_enabled)
\t\t\t\t\tnpc_subtile_start_follow(following_mob)
\t\t\t\telse if (npc_subtile_enabled || npc_subtile_continuous_legacy_ready("follow"))
\t\t\t\t\twalk_to(src, following_mob, 1, 6)
\t\t\t\tturns_since_move = FALSE
\tif (get_dist(src, following_mob) > 6)
\t\tnpc_set_following(null)
\t\tstop_automated_movement = FALSE
'''


def follow_block(source):
    life = section(source, '/mob/living/simple_animal/Life()\n', '// AI and Movement logic')
    return life[life.index('\tif (following_mob)'):].rstrip().replace('\t', '    ')


def project_follow(block, distance, turns, mode, callback_distance=None):
    """Execute only the explicitly recognized follow statements as Python."""
    translations = {
        'if (following_mob)': 'if following_mob:',
        'stop_automated_movement = TRUE': 'stop_automated_movement = True',
        'if (get_dist(src, following_mob) > 2)': 'if get_dist(src, following_mob) > 2:',
        'if (get_dist(src, following_mob) > 1)': 'if get_dist(src, following_mob) > 1:',
        'turns_since_move++': 'turns_since_move += 1',
        'if (turns_since_move >= move_to_delay)': 'if turns_since_move >= move_to_delay:',
        'if (npc_subtile_follow_enabled && npc_subtile_enabled)':
            'if npc_subtile_follow_enabled and npc_subtile_enabled:',
        'npc_subtile_start_follow(following_mob)': 'npc_subtile_start_follow(following_mob)',
        'else if (npc_subtile_enabled || npc_subtile_continuous_legacy_ready("follow"))':
            'elif npc_subtile_enabled or npc_subtile_continuous_legacy_ready("follow"):',
        'walk_to(src, following_mob, 1, 6)': 'walk_to(src, following_mob, 1, 6)',
        'turns_since_move = FALSE': 'turns_since_move = False',
        'if (get_dist(src, following_mob) > 6)': 'if get_dist(src, following_mob) > 6:',
        # Used only by the cached-distance negative control.
        'if (initial_dist > 6)': 'if initial_dist > 6:',
        'npc_set_following(null)': 'npc_set_following(None)',
        'stop_automated_movement = FALSE': 'stop_automated_movement = False',
    }
    projected = []
    for line in block.replace('\t', '    ').splitlines():
        statement = line.strip()
        if not statement or statement.startswith('//'):
            continue
        if statement not in translations:
            raise AssertionError(f'Unrecognized follow statement: {statement}')
        projected.append(' ' * (len(line) - len(line.lstrip())) + translations[statement])
    code = '\n'.join(projected)
    code = '\n'.join(line[4:] for line in code.splitlines()) if code.startswith('    ') else code

    target = object()
    state = {'distance': distance, 'calls': []}
    ctx = {'__builtins__': {}, 'src': object(), 'following_mob': target,
           'turns_since_move': turns, 'move_to_delay': 2,
           'stop_automated_movement': False, 'initial_dist': distance,
           'npc_subtile_follow_enabled': mode == 'staged',
           'npc_subtile_enabled': mode in ('staged', 'legacy_subtile')}
    ctx['get_dist'] = lambda actor, followed: state['distance']
    ctx['npc_subtile_continuous_legacy_ready'] = lambda kind: mode == 'legacy'

    def move(kind):
        state['calls'].append(kind)
        if callback_distance is not None:
            state['distance'] = callback_distance

    ctx['npc_subtile_start_follow'] = lambda followed: move('staged')
    ctx['walk_to'] = lambda actor, followed, distance, interval: move('legacy')
    ctx['npc_set_following'] = lambda followed: ctx.update(following_mob=followed)
    exec(code, ctx)
    return (ctx['turns_since_move'], ctx['following_mob'] is None,
            ctx['stop_automated_movement'], tuple(state['calls']))


class FollowContracts(unittest.TestCase):
    def setUp(self):
        self.source = SOURCE.read_text(encoding='utf-8')
        self.owner, self.target = object(), object()
        self.actor = SimpleNamespace(npc_subtile_follow=self.owner,
            npc_subtile_follow_enabled=True, npc_subtile_enabled=True,
            npc_subtile_ready=lambda: True, npc_subtile_pursuit=None, npc_subtile_flee=None,
            npc_subtile_pet_walk=None,
            move_gen=3, following_mob=self.target, stance='idle',
            target_mob=None, target_obj=None, z=1)
        self.context = dict(cancelled=False, actor=self.actor, src=self.owner,
            generation=3, target=self.target, expected_stance='idle',
            expected_combat_target=None, expected_path_target=None,
            isDeleted=lambda item: False, destination=SimpleNamespace(z=1),
            get_dist=lambda actor, target: 2)

    def guards(self):
        valid = section(self.source, '/datum/npc_subtile_follow/proc/valid()\n',
                        '/datum/npc_subtile_follow/proc/perform()')
        reject = next(line.strip()[3:] for line in valid.splitlines()
                      if line.strip().startswith('if ('))
        accept = next(line.strip()[len('return '):] for line in valid.splitlines()
                      if line.strip().startswith('return destination'))
        return reject, accept

    def admitted(self):
        reject, accept = self.guards()
        return not evaluate(reject, self.context) and evaluate(accept, self.context)

    def test_owned_follow_and_revocation(self):
        self.assertTrue(self.admitted())
        changes = (
            lambda: self.context.update(cancelled=True),
            lambda: setattr(self.actor, 'npc_subtile_follow', object()),
            lambda: setattr(self.actor, 'npc_subtile_pursuit', object()),
            lambda: setattr(self.actor, 'npc_subtile_flee', object()),
            lambda: setattr(self.actor, 'npc_subtile_pet_walk', object()),
            lambda: setattr(self.actor, 'move_gen', 4),
            lambda: setattr(self.actor, 'following_mob', None),
            lambda: setattr(self.actor, 'npc_subtile_ready', lambda: False),
            lambda: setattr(self.actor, 'target_mob', object()),
            lambda: setattr(self.actor, 'target_obj', object()),
            lambda: setattr(self.actor, 'stance', 'attack'),
            lambda: self.context.update(get_dist=lambda actor, target: 7),
            lambda: self.context.update(destination=SimpleNamespace(z=2)),
        )
        for change in changes:
            with self.subTest(change=change):
                self.setUp()
                change()
                self.assertFalse(self.admitted())

    def test_leash_link_is_durable_and_runtime_owner_is_excluded(self):
        follow = section(self.source, '/mob/living/simple_animal/proc/npc_subtile_start_follow(',
                         '/datum/npc_subtile_pulse\n')
        self.assertNotRegex(follow, r'following_mob\s*=(?!=)')
        self.assertIn('"npc_subtile_follow_enabled"', self.source)
        self.assertIn('"npc_subtile_follow"', self.source)
        self.assertIn('return key == "following_mob" || ..()', self.source)
        self.assertIn('should_save = FALSE', follow)

    def test_pursuit_preempts_worker_without_erasing_leash(self):
        start = section(self.source, '/mob/living/simple_animal/proc/npc_subtile_start_follow(',
                        '/mob/living/simple_animal/proc/npc_subtile_stop_follow(')
        self.assertIn('npc_subtile_pursuit ||', start)
        self.assertLess(start.index('walk(src, 0)'), start.index('F.perform()'))
        self.assertLess(start.index('move_gen++'), start.index('F.generation = move_gen'))
        self.assertIn('moving = FALSE', start)
        pursuit = section(TACTICAL.read_text(encoding='utf-8'),
            '/mob/living/simple_animal/proc/npc_subtile_start_pursuit(',
            '/datum/npc_subtile_pursuit\n')
        self.assertLess(pursuit.index('npc_subtile_stop_follow()'), pursuit.index('P.perform()'))

    def test_existing_leash_gate_and_interval_remain_visible(self):
        life = section(ANIMAL.read_text(encoding='utf-8'),
                       '/mob/living/simple_animal/Life()\n', '// AI and Movement logic')
        for contract in ('get_dist(src, following_mob) > 2',
                         'turns_since_move >= move_to_delay',
                         'npc_subtile_start_follow(following_mob)',
                         'walk_to(src, following_mob, 1, 6)',
                         'get_dist(src, following_mob) > 6'):
            self.assertIn(contract, life)
        loop = section(self.source, '/datum/npc_subtile_follow/proc/perform_loop()\n',
                       '/datum/npc_subtile_pulse\n')
        self.assertIn('actor.ai_step_wait(next, interval, src)', loop)
        self.assertIn('actor.npc_subtile_native_interval(6)', loop)
        self.assertIn('get_step_to(actor, target, 1)', loop)
        self.assertIn('get_dist(actor, target) <= 1 && actor.npc_subtile_offset_owned && (actor.step_x || actor.step_y)', loop)
        self.assertIn('actor.npc_subtile_settle_axis(src, interval)\n\t\t\tbreak', loop)
        self.assertIn('sleep(deadline - world.time)', loop)
        self.assertNotIn('sleep(6)', loop)

    def test_follow_life_projection_matches_pre_change_and_rejects_mutants(self):
        current = follow_block(ANIMAL.read_text(encoding='utf-8'))
        self.assertEqual(current.count('get_dist(src, following_mob)'), 2)
        scenarios = [(distance, turns, mode, after)
                     for distance in (0, 1, 2, 3, 6, 7)
                     for turns in (0, 1)
                     for mode in ('staged', 'legacy', 'legacy_subtile', 'disabled')
                     for after in (None, 1, 7)]
        def outputs(block):
            return [project_follow(block, *case) for case in scenarios]

        expected = outputs(FOLLOW_BASELINE)
        self.assertEqual(outputs(current), expected)
        missing_gate = current.replace('get_dist(src, following_mob) > 2',
                                       'get_dist(src, following_mob) > 1', 1)
        cached_detach = current.replace('get_dist(src, following_mob) > 6', 'initial_dist > 6', 1)
        self.assertNotEqual(outputs(missing_gate), expected)
        self.assertNotEqual(outputs(cached_detach), expected)

    def test_stage_is_default_off(self):
        self.assertIn('var/npc_subtile_follow_enabled = FALSE', self.source)
        for path in (ROOT / 'code').rglob('*.dm'):
            self.assertNotIn('npc_subtile_follow_enabled = TRUE',
                             path.read_text(encoding='utf-8', errors='replace'), str(path))


if __name__ == '__main__':
    unittest.main()
