"""Offline compiler admission and workflow selection checks; no BYOND launch."""
from pathlib import Path
import subprocess
import sys
import unittest

from compiler_contract import HISTORICAL_VERSION, VERSIONS, compiler_is_clean

ROOT = Path(__file__).resolve().parents[2]


class CompilerContractTests(unittest.TestCase):
    def test_explicit_versions_and_historical_default(self):
        self.assertEqual(VERSIONS, ('516.1681', '516.1688'))
        self.assertEqual(HISTORICAL_VERSION, '516.1681')
        for version in VERSIONS:
            log = f'DM compiler version {version}\nprobe.dmb - 0 errors, 0 warnings (10/28/26 4:36 pm)\n'
            self.assertTrue(compiler_is_clean(0, log, version))
            other = '516.1688' if version == '516.1681' else '516.1681'
            self.assertFalse(compiler_is_clean(0, log, other))
            self.assertFalse(compiler_is_clean(0, log, '516.1700'))

    def test_fail_closed_for_bad_or_ambiguous_compiler_results(self):
        good = 'DM compiler version 516.1688\nprobe.dmb - 0 errors, 0 warnings\n'
        for log in (good.replace('516.1688', '516.16880'),
                    good + 'DM compiler version 516.1681\n',
                    good + 'DM compiler version 516.1688\n',
                    good.replace('0 errors', '1 errors'),
                    good.replace('0 warnings', '1 warning'),
                    good.replace('probe.dmb - ', ''),
                    good + 'probe.dmb - 0 errors, 0 warnings\n'):
            self.assertFalse(compiler_is_clean(0, log, '516.1688'), log)
        self.assertFalse(compiler_is_clean(1, good, '516.1688'))

    def test_both_runners_reject_unapproved_cli_version_before_launch(self):
        for name in ('run.py', 'preservation_run.py'):
            result = subprocess.run([sys.executable, '-B', str(ROOT / 'tests/food_progression' / name),
                                     '--byond-bin', '.', '--expected-byond-version', '516.1700'],
                                    capture_output=True, text=True, timeout=10)
            self.assertEqual(result.returncode, 2, result.stderr)
            self.assertIn('invalid choice', result.stderr)

    def test_selected_lane_passes_pin_to_all_original_controls(self):
        workflow = (ROOT / '.github/workflows/test.yml').read_text(encoding='utf-8')
        lane = workflow.split('      - name: Verify production food progression and seed-consumption negative control', 1)[1].split('\n      - name:', 1)[0]
        self.assertIn('if: needs.changes.outputs.extensive', lane)
        self.assertIn('tests/food_progression', lane)
        self.assertIn('--expected-byond-version "${BYOND_MAJOR}.${BYOND_MINOR}"', lane)
        commands = [line.strip() for line in lane.splitlines() if line.strip().startswith('/usr/bin/python3 tests/food_progression/')]
        self.assertEqual(len(commands), 9)
        self.assertTrue(all('"${args[@]}"' in line for line in commands))
        for required in ('--negative-control', '--probe storage', '--can-negative-control',
                         '--preservation-control nutrition', '--preservation-control age',
                         '--preservation-control conversion', '--probe cutting'):
            self.assertTrue(any(required in line for line in commands), required)
        self.assertEqual(sum('preservation_run.py' in line for line in commands), 4)
        rack = workflow.split('      - name: Verify paid rack save and six mutation controls', 1)[1].split('\n      - name:', 1)[0]
        self.assertIn('inputs.rack_save_regressions', rack)
        self.assertIn('--expected-byond-version "${BYOND_MAJOR}.${BYOND_MINOR}"', rack)
        self.assertIn('baseline coverage runtime storage stale-wait duplicate conversion', rack)

    def test_cutting_probe_is_bounded_and_evidence_is_explicit(self):
        runner = (ROOT / 'tests/food_progression/run.py').read_text()
        self.assertIn("timeout=30", runner)
        self.assertIn("runtime checks NOT RUN (--compile-only)", runner)
        self.assertIn("--evidence-dir must not exist", runner)
        workflow = (ROOT / '.github/workflows/test.yml').read_text()
        retained = workflow.split('      - name: Retain isolated cutting-board evidence', 1)[1].split('\n      - name:', 1)[0]
        self.assertIn("always()", retained)
        for name in ('metadata.json', 'compile.log', 'runtime.log', 'daemon.log',
                     'food_result.txt', 'probe.dm', 'cutting-board-routes.json',
                     'cutting-board-trace-cases.json'):
            self.assertIn('/cutting-board-evidence/' + name, retained)
        self.assertNotIn('checkout.patch', retained)
        self.assertNotIn('.dmb', retained)


if __name__ == '__main__':
    unittest.main()
