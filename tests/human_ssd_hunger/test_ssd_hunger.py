"""Offline projection of the Sleep (induced SSD) and asleep/unconscious hunger branches; not a BYOND runtime test."""
import importlib.util
from itertools import product
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('ssd_hunger_adapter', ROOT / 'tests/save_movement/source_adapter.py')
ADAPTER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ADAPTER)
ASLEEP = 'else if (stat == UNCONSCIOUS)'


def production():
    source = (ROOT / 'code/game/mob/living/carbon/human/human_life.dm').read_text(encoding='utf-8')
    start = source.index('\t\tif (inducedSSD) //if sleeping in SSD mode')
    end = source.index('\n\t\telse if (stat == CONSCIOUS', start)
    return source[start:end].rstrip() + '\n'


def branch_lines(fragment):
    lines = [line.strip().split('//', 1)[0].rstrip() for line in fragment.splitlines()]
    return [line for line in lines if line.startswith(('if (', 'else if ('))]


def project(fragment):
    first, second = branch_lines(fragment)
    source = '/check()\n\t' + first + '\n\t\treturn 1\n\t' + second + '\n\t\treturn 2\n\treturn 3\n'
    return ADAPTER.project(source, '/check', 'inducedSSD, buckled, stat, UNCONSCIOUS', {})


class SleepHungerChecks(unittest.TestCase):
    def test_branch_order(self):
        self.assertEqual(branch_lines(production()), ['if (inducedSSD)', ASLEEP])

    def test_any_sleep_uses_the_slow_rate(self):
        proc = project(production())
        for ssd, buckle, stat in product((False, True), (None, 'other', 'bed'), (0, 1, 2)):
            expected = 1 if ssd else (2 if stat == 1 else 3)
            self.assertEqual(proc(ssd, buckle, stat, 1), expected, (ssd, buckle, stat))
        # Negative control: the old bed-only condition leaves floor sleepers on the awake rate.
        old = project(production().replace(ASLEEP, 'else if (buckled == "bed" && stat == UNCONSCIOUS)'))
        self.assertEqual(old(False, None, 1, 1), 3)
        self.assertEqual(old(False, 'bed', 1, 1), 2)

    def test_slow_rate_is_a_tenth_of_idle(self):
        fragment = production()
        self.assertEqual(fragment.count('((0.01) * HUNGER_THIRST_MULTIPLIER'), 2)


if __name__ == '__main__':
    unittest.main()
