"""Offline-only tests for fixed diagnostic selection and invocation scope."""
import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('diagnostic_cases', Path(__file__).with_name('diagnostic_cases.py'))
module = importlib.util.module_from_spec(SPEC)
with patch('subprocess.Popen', side_effect=AssertionError('No execution on import')):
    SPEC.loader.exec_module(module)


def full_cases():
    return [dict(count=count, payload=payload, baseline=baseline)
            for count in (64, 512, 2048)
            for payload in (1024, 16384, 65536) for baseline in (1, 0)]


class DiagnosticCaseTests(unittest.TestCase):
    def test_default_full_matrix_unchanged_and_copied(self):
        full = full_cases()
        plan = module.select_case_plan(full)
        self.assertEqual(plan['cases'], full)
        self.assertEqual(len(plan['cases']), 18)
        self.assertEqual(plan['benchmark_mode'], 'full_matrix')
        self.assertTrue(plan['comparative'])
        plan['cases'][0]['count'] = 0
        self.assertEqual(full[0]['count'], 64)

    def test_exact_four_candidate_only_subset(self):
        plan = module.select_case_plan(full_cases(), True)
        self.assertEqual(plan['cases'], [
            {'count': 64, 'payload': 1024, 'baseline': 0},
            {'count': 512, 'payload': 16384, 'baseline': 0},
            {'count': 2048, 'payload': 1024, 'baseline': 0},
            {'count': 2048, 'payload': 16384, 'baseline': 0},
        ])
        self.assertEqual(plan['benchmark_mode'], 'diagnostic_subset')
        self.assertFalse(plan['comparative'])
        self.assertIn('not comparative', plan['interpretation'])
        self.assertIn('full matrix', plan['interpretation'])

    def test_subset_cannot_expand_approved_grid(self):
        with self.assertRaisesRegex(ValueError, 'outside'):
            module.select_case_plan(full_cases()[:2], True)
        plan = module.select_case_plan(full_cases(), True)
        self.assertTrue(all(row in full_cases() for row in plan['cases']))
        self.assertFalse(any(key in plan for key in ('limits', 'case_seconds', 'rss_mib', 'job_seconds')))

    def test_acceptance_workflow_keeps_limits_and_full_uninstrumented_matrix(self):
        text = (ROOT / '.github/workflows/moving-save-chunks.yml').read_text()
        # The manual human fixture is a separate job; keep the original
        # ordinary acceptance matrix unchanged without counting its command.
        ordinary = text.split('  isolated-native:\n', 1)[1].split('\n  human-spatial:\n', 1)[0]
        commands = [line for line in ordinary.splitlines() if 'python3 -B tests/movement_save_chunks/' in line and '--run-native' in line]
        self.assertEqual(len(commands), 2)
        correctness, memory = commands
        self.assertIn('correctness.py', correctness)
        self.assertNotIn('--diagnostic-subset', correctness)
        self.assertIn('--job-seconds 240', correctness)
        self.assertIn('benchmark.py', memory)
        self.assertNotIn('--diagnostic-subset', memory)
        self.assertNotIn('--profile-datums', memory)
        self.assertIn('--job-seconds 900', memory)


if __name__ == '__main__':
    unittest.main()
