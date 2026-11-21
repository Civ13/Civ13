"""Concurrent cattle plough removal refunds the harness once (issue #6408).

The production detach_plough body runs through the shared source adapter.
Only do_after, to_chat and item creation are test boundaries; the do_after
fake runs the competing event (a second remover, or death) during the wait.
"""
from pathlib import Path
import re
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tests/save_movement'))
from source_adapter import extract, project

SOURCE = (ROOT / 'code/game/mob/living/simple_animal/friendly/farm_animals.dm').read_text(encoding='utf-8')
DECL = '/mob/living/simple_animal/cattle/proc/detach_plough'
FIELDS = ('plough', 'stat', 'cattle_gender', 'icon_state', 'plough_material')
DEAD = 2


def projected_source():
    body = extract(SOURCE, DECL)
    body = re.sub(r'new (/[\w/]+)\(([^)]*)\)', r'spawn_item("\1", \2)', body)
    # Qualify bare fields outside string literals only.
    pieces = re.split(r'("(?:[^"\\]|\\.)*")', body)
    for i in range(0, len(pieces), 2):
        for name in FIELDS:
            pieces[i] = re.sub(r'(?<![\w.])' + name + r'\b', 'src.' + name, pieces[i])
    return DECL + '(mob/user)\n' + ''.join(pieces)


class Cattle:
    def __init__(self):
        self.plough, self.stat, self.cattle_gender = True, 0, 'female'
        self.icon_state, self.plough_material = 'cow_plough', 'wood'


class User:
    def __init__(self, name):
        self.loc = name


class Harness:
    def __init__(self, during_wait):
        self.items, self.waits = [], 0
        self.during_wait = during_wait
        env = {'to_chat': lambda *a: None, 'spawn_item': self.spawn, 'do_after': self.do_after,
               'DEAD': DEAD}
        self.detach = project(projected_source(), DECL, 'src, user', env)

    def spawn(self, path, loc):
        self.items.append(path)

    def do_after(self, user, delay, target):
        self.waits += 1
        if self.waits == 1 and self.during_wait:
            self.during_wait(self, target)
        return True


def second_remover(harness, cow):
    harness.detach(cow, User('b'))


def cow_dies(harness, cow):
    # Death drops the plough and clears the harness before a pending removal ends.
    harness.spawn('/obj/item/weapon/plough', 'corpse')
    harness.spawn('/obj/item/stack/material/rope', 'corpse')
    harness.spawn('/obj/item/stack/material/rope', 'corpse')
    cow.plough, cow.plough_material, cow.stat = False, None, DEAD


class DetachRace(unittest.TestCase):
    def counts(self, items):
        return items.count('/obj/item/stack/material/rope'), sum(i.startswith('/obj/item/weapon/plough') for i in items)

    def test_single_removal_refunds_harness(self):
        h, cow = Harness(None), Cattle()
        self.assertTrue(h.detach(cow, User('a')))
        self.assertEqual(self.counts(h.items), (2, 1))
        self.assertFalse(cow.plough)
        self.assertIsNone(cow.plough_material)
        self.assertEqual(cow.icon_state, 'cow')

    def test_concurrent_removals_refund_once(self):
        h, cow = Harness(second_remover), Cattle()
        self.assertFalse(h.detach(cow, User('a')))
        self.assertEqual(self.counts(h.items), (2, 1))

    def test_death_during_wait_refunds_once(self):
        h, cow = Harness(cow_dies), Cattle()
        self.assertFalse(h.detach(cow, User('a')))
        self.assertEqual(self.counts(h.items), (2, 1))

    def test_iron_plough_returns_iron(self):
        h, cow = Harness(None), Cattle()
        cow.plough_material = 'iron'
        h.detach(cow, User('a'))
        self.assertIn('/obj/item/weapon/plough/iron', h.items)

    def test_attach_rechecks_after_wait(self):
        block = SOURCE.split('/mob/living/simple_animal/cattle/attackby(', 1)[1].split('\n/mob/', 1)[0]
        wait = block.index('if (do_after(user,35,src))')
        guard = block.index('if (plough || stat == DEAD', wait)
        material = block.index('plough_material = ', wait)
        consume = block.index('NR.amount -= 2', wait)
        self.assertLess(guard, material)
        self.assertLess(material, consume)
        self.assertNotIn('plough_material = ', block[:wait])


if __name__ == '__main__':
    unittest.main()
