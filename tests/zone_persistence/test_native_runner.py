"""Offline checks that keep the native zone runner, probe and controls aligned.

These tests launch no BYOND process. Native results come from run_native.py.
"""
import importlib.util
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('zone_run_native', ROOT / 'tests/zone_persistence/run_native.py')
RUNNER = importlib.util.module_from_spec(spec)
spec.loader.exec_module(RUNNER)
PROBE = (ROOT / 'tests/zone_persistence/probe.dm').read_text(encoding='utf-8')


class NativeRunnerContract(unittest.TestCase):
    def test_every_case_is_a_probe_mode_with_a_completed_writer(self):
        modes = [case[0] for case in RUNNER.CASES]
        self.assertEqual(len(modes), len(set(modes)))
        writers = {case[0]: case[1] for case in RUNNER.CASES}
        for mode, writer, checks, expected in RUNNER.CASES:
            with self.subTest(mode=mode):
                self.assertIn('"' + mode + '"', PROBE)
                self.assertIsInstance(checks, int)
                self.assertGreater(checks, 0)
                self.assertIsNone(expected)
                if writer:
                    # A reader only ever receives disk files from an earlier writer.
                    self.assertIn(writer, writers)
                    self.assertLess(modes.index(writer), modes.index(mode))
                    self.assertIsNone(writers[writer])

    def test_extended_modes_all_run(self):
        listed = PROBE.split('/proc/zone_fixture_extended_modes()', 1)[1].split('\n/proc/', 1)[0]
        extended = re.findall(r'"([a-z-]+)"', listed)
        self.assertGreaterEqual(len(extended), 13)
        modes = {case[0] for case in RUNNER.CASES}
        for mode in extended:
            self.assertIn(mode, modes)

    def test_issue_items_have_native_cases(self):
        modes = {case[0] for case in RUNNER.CASES}
        for mode in ('roof-read', 'roof-omitted-settings', 'roof-absent-base', 'ambiguous-base-write',
                     'ambiguous-base-read', 'surprise-read', 'retire-read', 'admission', 'weather-read',
                     'latejoin-read', 'unsupported-schema', 'unsupported-topology', 'legacy-read'):
            self.assertIn(mode, modes)

    def test_omission_controls_remove_one_production_step(self):
        modes = {case[0] for case in RUNNER.CASES}
        self.assertGreaterEqual(len(RUNNER.CONTROLS), 5)
        for name, (relative, before, after, target, failure) in RUNNER.CONTROLS.items():
            with self.subTest(control=name):
                text = (ROOT / relative).read_text(encoding='utf-8')
                self.assertEqual(text.count(before), 1)
                self.assertNotEqual(before, after)
                self.assertIn(target, modes)
                # The named failure is an assertion message the probe can raise.
                self.assertIn(failure, PROBE)

    def test_held_failures_check_hold_registry_and_files(self):
        body = PROBE.split('/proc/zone_fixture_expect_held_failure(', 1)[1].split('\n/proc/', 1)[0]
        for text in ('persistence_load_recovery_required', 'persistence_area_registry_blocked()',
                     'return_areas()', 'change_weather(', 'Save_World()', 'zone_fixture_save_hashes()',
                     'Load retried automatically'):
            self.assertIn(text, body)
        rejection = PROBE.split('/proc/zone_fixture_expect_rejection(', 1)[1].split('\n/proc/', 1)[0]
        for text in ('sleep(1)', 'zone_fixture_save_hashes()', '!persistence_load_recovery_required',
                     'Rejection reason differs'):
            self.assertIn(text, rejection)

    def test_runner_uses_pinned_compiler_and_isolated_cases(self):
        source = (ROOT / 'tests/zone_persistence/run_native.py').read_text(encoding='utf-8')
        self.assertIn("tools/byond/version.json", source)
        self.assertIn("'--zone-topology', '--prepare-only'", source)
        self.assertIn("start_new_session=True", source)
        self.assertIn("probe-port-closed.ack", source)

    def test_workflow_runs_suite_and_every_control(self):
        workflow = (ROOT / '.github/workflows/moving-save-chunks.yml').read_text(encoding='utf-8')
        self.assertIn("tests/zone_persistence/**", workflow)
        step = workflow.split('- name: Zone topology native acceptance', 1)[1].split('\n      - name:', 1)[0]
        self.assertIn('tests/zone_persistence/run_native.py', step)
        self.assertIn('--all-controls', step)
        # Runs before the known timing-dependent memory matrix so it is not skipped by it.
        self.assertLess(workflow.index('Zone topology native acceptance'),
                        workflow.index('Isolated native correctness and bounded memory matrix'))


if __name__ == '__main__':
    unittest.main()
