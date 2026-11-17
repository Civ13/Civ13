"""Source contracts for the train step benchmark. Never launches BYOND."""
from pathlib import Path
import re
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
import run  # noqa: E402

BENCH = (ROOT / run.BENCH).read_text(encoding='utf-8')


class TrainStepBenchSources(unittest.TestCase):
    def test_generated_dme_swaps_the_probe(self):
        generated = run.sources()
        dme = generated[run.PREFIX + '.dme']
        self.assertIn('#include "%s"' % run.BENCH, dme)
        self.assertNotIn(run.PROBE, dme)
        self.assertNotIn('.dmm"', dme)
        self.assertEqual(set(generated), {run.PREFIX + s for s in ('.dme', '_world.dm', '_globals.dm')})

    def test_expected_rows_match_the_scenarios(self):
        loops = [len(m.group(1).split(',')) for m in re.finditer(
            r'for \(var/cars in list\(([^)]*)\)\)\n\t\tbench_measure\(', BENCH)]
        singles = len(re.findall(r'^\tbench_measure\(', BENCH, flags=re.M))
        self.assertEqual(sum(loops) + singles, run.EXPECTED_ROWS)

    def test_verify_rejects_short_runs(self):
        rows = [{'name': 'r%d' % i, 'steps': 20, 'mean_ms': 1.0} for i in range(run.EXPECTED_ROWS)]
        with self.assertRaises(ValueError):
            run.verify_result({'steps': 20, 'rows': rows[:-1]})
        rows[0]['steps'] = 3
        with self.assertRaises(ValueError):
            run.verify_result({'steps': 20, 'rows': rows})


if __name__ == '__main__':
    unittest.main()
