"""A disturbed bear cave releases bears at every population, including five (#6930)."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/game/objects/structures/animalspawner/bearcave.dm'
HEADER = '/obj/structure/animalspawner/bearcave/proc/aggro()'


def releases(body, population):
    """Walk aggro()'s population ladder; return whether a bear comes out."""
    conditions = re.findall(r'(?:else )?if ?\((src\.total_population[^\n]*?)\)(?: //[^\n]*)?\n', body)
    for raw in conditions[1:]:  # the first is the outer total_population > 0 guard
        expression = raw.replace('src.total_population', str(population)).replace('&&', 'and').replace('||', 'or')
        if eval(expression, {'__builtins__': {}}):
            return True
    return False


class BearCaveAggroTests(unittest.TestCase):
    def test_every_population_releases(self):
        text = SOURCE.read_text(encoding='utf-8-sig').replace('\r\n', '\n')
        start = text.index(HEADER)
        body = text[start:text.index('\n/', start + 1)]
        self.assertGreaterEqual(body.count('bear_out()'), 3)
        for population in range(1, 16):
            with self.subTest(population=population):
                self.assertTrue(releases(body, population))


if __name__ == '__main__':
    unittest.main()
