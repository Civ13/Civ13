"""Wolf cubs neither conceive nor sire (issue 6942).

Native check: python3 tests/ecology_spawning/run_linux.py . tests/wolf_cubs/probe.dm
"""
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
WOLF = (ROOT / 'code/game/mob/living/simple_animal/hostile/wolf.dm').read_text(encoding='utf-8')


class WolfCubTests(unittest.TestCase):
    def test_mother_and_sire_must_be_grown(self):
        self.assertIn('if(!src.cub) //Cubs can\'t get pregnant', WOLF)
        self.assertIn('M.stat == CONSCIOUS && !M.female && !M.cub && !animal_spot_crowded(src, 0)', WOLF)


if __name__ == '__main__':
    unittest.main()
