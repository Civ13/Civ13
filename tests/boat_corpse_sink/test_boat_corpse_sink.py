"""Check that a corpse on deep water a boat now covers is not sunk, from source, not BYOND."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/game/turfs/floor_types.dm'

# The pre-fix corpse callback, frozen as a negative control.
OLD = '''			if (ML && ML.stat == DEAD)
				spawn(60)
					if (A && A.loc == src)
						qdel(A)
'''


def corpse_condition(source):
    start = source.index('if (ML && ML.stat == DEAD)')
    return re.search(r'spawn\(60\)\n\t+if \((.*)\)\n\t+qdel\(A\)', source[start:]).group(1)


def sinks(source, still_there, covered):
    expr = corpse_condition(source)
    expr = expr.replace('A.loc == src', str(still_there)).replace('!iscovered()', str(not covered))
    expr = re.sub(r'\bA\b', 'True', expr).replace('&&', ' and ')
    return bool(eval(expr))


class BoatCorpseSinkTest(unittest.TestCase):
    def setUp(self):
        self.source = SOURCE.read_text(encoding='utf-8')

    def test_corpse_under_a_boat_stays(self):
        self.assertFalse(sinks(self.source, True, True))

    def test_corpse_on_open_deep_water_sinks(self):
        self.assertTrue(sinks(self.source, True, False))

    def test_moved_corpse_does_not_sink(self):
        self.assertFalse(sinks(self.source, False, False))

    def test_negative_control_old_callback_sinks_covered_corpse(self):
        self.assertTrue(sinks(OLD, True, True))


if __name__ == '__main__':
    unittest.main()
