"""Replay a constrictor's scheduled squeeze after the snake dies, from source, not BYOND."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/game/mob/living/simple_animal/hostile/snake.dm'

# The pre-fix constriction tick, frozen as a negative control.
OLD_TICK = '''/mob/living/simple_animal/hostile/poison/snake/constrictor/proc/do_constricting(var/mob/living/L)
	if (L && L.client)
		L.client.canmove = FALSE
	cons_target = L
	if (L)
		L.adjustOxyLoss(25)
		spawn(22)
			if (L)
				do_constricting(L)

'''

PROC = '/mob/living/simple_animal/hostile/poison/snake/constrictor/proc/do_constricting(var/mob/living/L)\n'


def tick_body(source):
    start = source.index(PROC) + len(PROC)
    end = source.find('\n/', start)
    return source[start:end if end != -1 else None]


def entry_guard_stops(body, snake):
    """True when the proc's opening guard returns before touching the victim."""
    first = body.split('\n', 1)[0].strip()
    if not first.startswith('if (') or 'L' in re.findall(r'\b\w+\b', first):
        return False
    return eval_condition(first[4:-1], snake)


def eval_condition(cond, snake):
    expr = cond.replace('||', ' or ').replace('&&', ' and ').replace('!constricting', ' not constricting ')
    expr = expr.replace('stat == DEAD', ' dead ').replace('stat != DEAD', ' not dead ')
    expr = re.sub(r'\bL\b', ' True ', expr)
    return bool(eval(expr, {}, dict(snake)))


def spawn_guard(body):
    return re.search(r'spawn\(22\)\n\t+if \((.*)\)\n\t+do_constricting\(L\)', body).group(1)


def squeezes_after_death(source):
    """Snake squeezes once, dies (death() clears constricting), then its spawn(22) callback fires."""
    body = tick_body(source)
    snake = {'dead': True, 'constricting': False}
    if not eval_condition(spawn_guard(body), snake):
        return 0
    return 0 if entry_guard_stops(body, snake) else 1


class ConstrictorDeathTest(unittest.TestCase):
    def setUp(self):
        self.source = SOURCE.read_text(encoding='utf-8')

    def test_dead_snake_does_not_squeeze_again(self):
        self.assertEqual(squeezes_after_death(self.source), 0)

    def test_living_snake_keeps_squeezing(self):
        body = tick_body(self.source)
        snake = {'dead': False, 'constricting': True}
        self.assertTrue(eval_condition(spawn_guard(body), snake))
        self.assertFalse(entry_guard_stops(body, snake))

    def test_both_guards_check_the_snake(self):
        body = tick_body(self.source)
        self.assertTrue(entry_guard_stops(body, {'dead': True, 'constricting': True}))
        self.assertTrue(entry_guard_stops(body, {'dead': False, 'constricting': False}))
        self.assertFalse(eval_condition(spawn_guard(body), {'dead': True, 'constricting': True}))

    def test_death_clears_constricting(self):
        death = self.source[self.source.index('/mob/living/simple_animal/hostile/poison/snake/constrictor/death()'):]
        self.assertIn('constricting = FALSE', death.split('\n/', 1)[0])

    def test_negative_control_old_tick_squeezes_corpse_victim(self):
        self.assertEqual(squeezes_after_death(OLD_TICK), 1)


if __name__ == '__main__':
    unittest.main()
