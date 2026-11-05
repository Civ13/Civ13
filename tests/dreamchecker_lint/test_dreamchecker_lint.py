"""The dreamchecker ratchet parses the tool's output and compares it with the baseline; no download, no BYOND.

Input, output and comparison are pinned on a synthetic log so a baseline
regression in CI is a decision of this script, not of the formatting of the
SpacemanDMM release.
"""
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / 'scripts/dreamchecker_lint.py'
PIN = ROOT / 'tools/lint/dreamchecker.json'
BASELINE = ROOT / 'tools/lint/dreamchecker_baseline.json'

LOG = (
    '\x1b[1mParsing civ13.dme...\x1b[0m\n'
    '\n'
    'code\\modules\\a.dm, line 12, column 5:\n'
    'error: if condition is always false\n'
    '\n'
    'code/modules/b.dm, line 3, column 66:\n'
    'warning: field access requires static type: "len"\n'
    '- add a type annotation\n'
    '\n'
    'code/modules/b.dm, line 40, column 1:\n'
    'warning: field access requires static type: "len"\n'
    '\n'
    'code/processes/_process.dm, line 401, column 9:\n'
    'error: bad keyword argument "e_src" to /world/proc/Error\n'
    '\n'
    'Found 4 diagnostics\n'
)


def load():
    spec = importlib.util.spec_from_file_location('dreamchecker_lint', SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class ParseTests(unittest.TestCase):
    def setUp(self):
        self.module = load()

    def test_parse_strips_colour_normalises_paths_and_reads_the_total(self):
        diagnostics, total = self.module.parse(LOG)
        self.assertEqual(total, 4)
        self.assertEqual([(d['path'], d['line'], d['column'], d['severity']) for d in diagnostics],
                         [('code/modules/a.dm', 12, 5, 'error'), ('code/modules/b.dm', 3, 66, 'warning'),
                          ('code/modules/b.dm', 40, 1, 'warning'), ('code/processes/_process.dm', 401, 9, 'error')])
        summary = self.module.summarise(diagnostics)
        self.assertEqual(summary['by_severity']['error'], 2)
        self.assertEqual(summary['by_severity']['warning'], 2)
        self.assertEqual(summary['by_category']['warning: field access requires static type: "len"'], 2)
        self.assertEqual(summary['by_file'], {'code/modules/b.dm': 2, 'code/modules/a.dm': 1,
                                              'code/processes/_process.dm': 1})

    def test_categories_drop_numbers_only(self):
        self.assertEqual(self.module.normalise_message('bad keyword argument "e_src" to /world/proc/Error'),
                         'bad keyword argument "e_src" to /world/proc/Error')
        self.assertEqual(self.module.normalise_message('expected 3 arguments, got 12'),
                         'expected N arguments, got N')


class RatchetTests(unittest.TestCase):
    def setUp(self):
        self.module = load()
        diagnostics, _ = self.module.parse(LOG)
        self.summary = self.module.summarise(diagnostics)
        self.receipt = dict(release='suite-1.12', environment='civ13.dme', summary=self.summary,
                            diagnostics=diagnostics)

    def test_regressions_and_improvements(self):
        baseline = {'by_category': {'warning: field access requires static type: "len"': 3,
                                    'error: if condition is always false': 1,
                                    'warning: returning a value in a spawn has no effect': 2}}
        regressions, improvements = self.module.compare(self.summary, baseline)
        self.assertEqual(regressions, [('error: bad keyword argument "e_src" to /world/proc/Error', 0, 1)])
        self.assertEqual(sorted(improvements), [
            ('warning: field access requires static type: "len"', 3, 2),
            ('warning: returning a value in a spawn has no effect', 2, 0)])

    def test_check_without_baseline_reports_only(self):
        directory = Path(tempfile.mkdtemp())
        lines = []
        self.assertEqual(self.module.check(self.receipt, directory / 'none.json', out=lines.append), 0)
        self.assertTrue(any('No baseline recorded' in line for line in lines))

    def test_write_then_check_round_trip(self):
        directory = Path(tempfile.mkdtemp())
        baseline = directory / 'baseline.json'
        lines = []
        self.assertEqual(self.module.check(self.receipt, baseline, write=True, head='abc', out=lines.append), 0)
        payload = json.loads(baseline.read_text(encoding='utf-8'))
        self.assertEqual(payload['head'], 'abc')
        self.assertEqual(payload['total'], 4)
        self.assertEqual(self.module.check(self.receipt, baseline, out=lines.append), 0)
        self.receipt['summary']['by_category']['error: if condition is always false'] += 1
        self.assertEqual(self.module.check(self.receipt, baseline, out=lines.append), 1)
        self.assertTrue(any(line.startswith('REGRESSION error: if condition is always false') for line in lines))


class RepositoryContract(unittest.TestCase):
    def test_pin_names_both_platforms_with_exact_bytes(self):
        pin = json.loads(PIN.read_text(encoding='utf-8'))
        self.assertEqual(pin['release'], 'suite-1.12')
        for platform in ('linux', 'windows'):
            binding = pin[platform]
            self.assertTrue(binding['url'].startswith(
                'https://github.com/SpaceManiac/SpacemanDMM/releases/download/suite-1.12/'))
            self.assertRegex(binding['sha256'], r'^[0-9a-f]{64}$')
            self.assertGreater(binding['bytes'], 1_000_000)

    def test_baseline_matches_the_pin_and_sums_consistently(self):
        pin = json.loads(PIN.read_text(encoding='utf-8'))
        baseline = json.loads(BASELINE.read_text(encoding='utf-8'))
        self.assertEqual(baseline['release'], pin['release'])
        self.assertEqual(baseline['environment'], 'civ13.dme')
        self.assertEqual(sum(baseline['by_category'].values()), baseline['total'])
        self.assertEqual(sum(baseline['by_severity'].values()), baseline['total'])
        for category in baseline['by_category']:
            self.assertRegex(category, r'^(error|warning|hint|info|note): ')

    def test_workflow_runs_the_advisory_job_only_for_admitted_compiles(self):
        workflow = (ROOT / '.github/workflows/test.yml').read_text(encoding='utf-8')
        job = workflow.split('\n  dreamchecker:\n', 1)[1]
        self.assertIn("if: needs.changes.outputs.skip_duplicate != 'true' && needs.changes.outputs.game == 'true'", job)
        self.assertIn('scripts/dreamchecker_lint.py download --output .ci/lint/dreamchecker', job)
        self.assertIn('scripts/dreamchecker_lint.py check --receipt .ci/lint/dreamchecker.json', job)
        self.assertIn('continue-on-error: true', job)
        required = workflow.split('\n  ci-required:\n', 1)[1].split('\n', 3)[2]
        self.assertNotIn('dreamchecker', required)


if __name__ == '__main__':
    unittest.main()
