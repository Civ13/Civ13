from pathlib import Path
import unittest
import re
import sys
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parents[2]
MOVEMENT = ROOT / 'code/game/mob/living/simple_animal/subtile_movement.dm'
sys.path.insert(0, str(ROOT / 'tests/save_movement'))
from source_adapter import project


def section(source, start, end):
    return source.split(start, 1)[1].split(end, 1)[0]


class WildWalkContracts(unittest.TestCase):
    def setUp(self):
        self.source = MOVEMENT.read_text(encoding='utf-8')

    def test_legacy_fallback_and_units(self):
        wrapper = section(self.source, '/mob/living/simple_animal/proc/npc_subtile_species_walk(', '/mob/living/simple_animal/proc/npc_subtile_start_wild_walk(')
        for statement in ('walk_rand(src, lag)', 'walk_towards(src, target, lag)', 'walk_away_od(src, target, distance_limit, lag)', 'walk(src, 0)', 'walk(src, direction, lag)', 'npc_subtile_native_interval(lag)'):
            self.assertIn(statement, wrapper)
        self.assertLess(wrapper.index('if (!npc_subtile_species_enabled)'), wrapper.index('walk_rand(src, lag)'))
        self.assertIn('var/npc_subtile_species_enabled = FALSE', self.source)
        self.assertIn('return lag * world.tick_lag', self.source)
        world = SimpleNamespace(tick_lag=1)
        convert = project(self.source, '/mob/living/simple_animal/proc/npc_subtile_native_interval', 'src, lag', {'world': world})
        for tick, lag, expected in ((0.5, 6, 3), (1, 2, 2), (2, 3, 6)):
            world.tick_lag = tick
            self.assertEqual(convert(None, lag), expected)

    def test_latest_request_reuses_one_owner_and_invalidates_receipt(self):
        start = section(self.source, '/mob/living/simple_animal/proc/npc_subtile_start_wild_walk(', '/mob/living/simple_animal/proc/npc_subtile_stop_wild_walk(')
        self.assertLess(start.index('if (!npc_subtile_ready())'), start.index('npc_subtile_pending_intent = null'))
        self.assertIn('var/new_owner = !W', start)
        self.assertIn('if (new_owner)\n\t\tspawn(0)', start)
        self.assertLess(start.index('move_gen++'), start.index('W.generation = move_gen'))
        for token in ('W.revision++', 'W.due = world.time + interval', 'npc_subtile_stop_follow()', 'npc_subtile_stop_flee()', 'npc_subtile_stop_pet_walk()', 'npc_subtile_stop_pursuit()'):
            self.assertIn(token, start)
        loop = section(self.source, '/datum/npc_subtile_wild_walk/proc/perform_loop()', '/datum/npc_subtile_recovery\n')
        for token in ('actor.npc_subtile_transaction', 'actor.npc_subtile_until', 'revision == current_revision', 'actor.ai_step_wait(next, interval, src)', 'actor.npc_subtile_settle_axis(src, interval)', 'human_subtile_same(before, actor.npc_subtile_snapshot())'):
            self.assertIn(token, loop)
        self.assertIn('actor.npc_subtile_defer_intent("wild", target, mode, distance_limit, interval, direction, TRUE)', loop)
        self.assertLess(loop.index('actor.npc_subtile_defer_intent("wild"'), loop.index('\n\t\t\t\tbreak'))
        for call in ('get_step_rand(actor)', 'get_step_towards(actor, target)', 'get_step_away(actor, target, distance_limit)', 'get_step_to(actor, target, distance_limit)', 'get_step(actor, direction)'):
            self.assertIn(call, loop)

    def test_species_decisions_and_redirects_are_preserved(self):
        flies = (ROOT / 'code/game/mob/living/simple_animal/friendly/flies.dm').read_text(encoding='utf-8')
        mosquito = (ROOT / 'code/game/mob/living/simple_animal/hostile/mosquitoes.dm').read_text(encoding='utf-8')
        bat = (ROOT / 'code/game/mob/living/simple_animal/hostile/vampirebat.dm').read_text(encoding='utf-8')
        for text in (flies, mosquito):
            self.assertIn('npc_subtile_species_walk("away", M, 3, 0, 3)', text)
            self.assertIn('M.npc_subtile_species_walk("direction", null, 3, turn(dir,180))', text)
        for text, count in ((flies, 1), (mosquito, 3), (bat, 4)):
            self.assertEqual(text.count('npc_subtile_species_walk("random", null, 4)'), count)
        for target in ('H', 'S'):
            self.assertIn(f'npc_subtile_species_walk("towards", {target}, 3)', mosquito)
        for target in ('H', 'cow', 'bull'):
            self.assertIn(f'npc_subtile_species_walk("towards", {target}, 3)', bat)
        for chance in ('prob(70)', 'prob(15)', 'prob(10)'):
            self.assertIn(chance, mosquito)
        for chance in ('prob(80)', 'prob(20)', 'prob(5)'):
            self.assertIn(chance, bat)

    def test_semantic_change_cannot_be_reauthorized_on_readiness_loss(self):
        body = section(self.source, '/datum/npc_subtile_wild_walk/proc/semantic_valid()', '/datum/npc_subtile_wild_walk/proc/valid()')
        condition = next(line.strip()[3:] for line in body.splitlines() if line.strip().startswith('if ('))
        condition = re.sub(r'!(?!=)', ' not ', condition.replace('&&', ' and ').replace('||', ' or ')).strip()
        owner, target = object(), object()
        actor = SimpleNamespace(npc_subtile_wild_walk=owner, npc_subtile_species_enabled=True,
            npc_subtile_enabled=True, npc_subtile_intent_valid=lambda value: value is owner,
            move_gen=8, stance='idle', behaviour='wander', target_mob=target,
            target_obj=None, following_mob=None, npc_subtile_ready=lambda: False)
        context = dict(actor=actor, src=owner, cancelled=False, generation=8,
            expected_stance='idle', expected_behaviour='wander', expected_combat_target=target,
            expected_path_target=None, expected_following=None, isDeleted=lambda value: False)
        evaluate = lambda: bool(eval(condition, {'__builtins__': {}}, context))
        self.assertFalse(evaluate())
        for field, changed in (('target_mob', object()), ('target_obj', object()),
                               ('stance', 'attack'), ('behaviour', 'hunt'),
                               ('following_mob', object()), ('move_gen', 9)):
            original = getattr(actor, field)
            setattr(actor, field, changed)
            self.assertTrue(evaluate(), field)
            setattr(actor, field, original)
        finish = section(self.source, '/datum/npc_subtile_wild_walk/proc/finish()', '/datum/npc_subtile_wild_walk/proc/perform_loop()')
        self.assertIn('semantic_valid() && !actor.npc_subtile_ready() && actor.npc_subtile_can_defer() && !actor.npc_subtile_pending_intent', finish)

    def test_contact_roll_stays_in_life_without_gating_movement(self):
        loop = section(self.source, '/datum/npc_subtile_wild_walk/proc/perform_loop()', '/datum/npc_subtile_recovery\n')
        self.assertNotIn('await_contact', loop)
        self.assertNotIn('npc_subtile_wait_contact_tick', self.source)
        self.assertIn('actor.ai_step_wait(next, interval, src)', loop)
        self.assertNotIn('prob(', loop)
        for name, chance in (('mosquitoes', 'prob(10)'), ('vampirebat', 'prob(5)')):
            text = (ROOT / f'code/game/mob/living/simple_animal/hostile/{name}.dm').read_text(encoding='utf-8')
            life = text.split('/Life()\n', 1)[1]
            self.assertNotIn('npc_subtile_contact_tick()', life)
            self.assertIn('if (!npc_subtile_contact_settled())', life)
            self.assertEqual(life.count(chance), 2 if name == 'mosquitoes' else 1)

    def test_monster_path_and_stops_keep_legacy_adapter(self):
        monsters = (ROOT / 'code/game/mob/living/simple_animal/hostile/monsters.dm').read_text(encoding='utf-8')
        self.assertIn('npc_subtile_species_walk("path", closest_oven, move_to_delay, 0, 1)', monsters)
        self.assertIn('npc_subtile_species_walk("path", H, move_to_delay, 0, TRUE)', monsters)
        self.assertIn('npc_subtile_species_walk("path", investigate_turf, move_to_delay, 0, TRUE)', monsters)
        self.assertIn('set_investigate_turf(T)', monsters)
        self.assertIn('npc_subtile_cancel_pending("wild")', monsters)

if __name__ == '__main__':
    unittest.main()
