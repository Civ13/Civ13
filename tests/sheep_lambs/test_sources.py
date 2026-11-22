"""Sheep lambs neither conceive nor sire (issue #6847).

Behaviour is covered natively (adults conceive; a ewe lamb or a ram lamb
does not):

    python3 tests/ecology_spawning/run_linux.py . tests/sheep_lambs/probe.dm
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/game/mob/living/simple_animal/friendly/farm_animals.dm').read_text(encoding='utf-8')


class SheepLambs(unittest.TestCase):
    def test_conception_requires_mature_parents(self):
        body = SOURCE.split('/mob/living/simple_animal/sheep/female/Life()', 1)[1].split('\n/', 1)[0]
        gate = body.index('if (!pregnant && !lamb && ')
        ram = body.index('M.stat == CONSCIOUS && !M.lamb && ')
        self.assertLess(gate, ram)
        self.assertLess(ram, body.index('pregnant = TRUE'))


if __name__ == '__main__':
    unittest.main()
