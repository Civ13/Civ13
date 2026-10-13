"""Compiler-free diagnostic, control-scope and evidence comparator regression."""
import copy
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('season_runner', HERE / 'run.py')
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)
GUARD = """Infinite loop suspected--switching proc to background.
If it is not an infinite loop, either do 'set background=1' or set world.loop_checks=0.
proc name: seasons (/obj/map_metadata/proc/seasons)
  usr: null
  src: the map metadata (/obj/map_metadata)
  src.loc: the drywater2 (1,1,1) (/turf/floor/beach/drywater2)
  call stack:
the map metadata (/obj/map_metadata): seasons(0, 0, 1)
world: New()
"""

class HarnessTests(unittest.TestCase):
    def test_diagnostic_parser_and_scopes(self):
        runner.self_test_diagnostics()
        self.assertTrue(runner.classify_runtime(GUARD, True)['valid'])
        for log in (GUARD.replace('seasons(0, 0, 1)', 'seasons(1, 0, 1)'),
                    GUARD + 'Bad ref\n', GUARD + 'ASSERTION\n'):
            with self.subTest(log=log):
                self.assertFalse(runner.classify_runtime(log, True)['valid'])

    def evidence(self):
        rows = [{'cycle': i, 'season': str(i), 'terrain_md5': str(i),
                 'rng_calls': i, 'clock': i, 'elapsed_ticks': 1,
                 'all_phase_completion_ticks': 2} for i in range(1, 5)]
        return dict(mode='baseline', profiling_enabled=False, profiling_scope=None,
                    request_scenarios=False, dimensions=[660, 550, 1],
                    baseline_sha=runner.BASELINE, phase_delay_adapter={'divisor': 10},
                    daemon_timeout_seconds=900, budget_adapter='actual',
                    negative_control='legacy-loop', negative_control_detected=True,
                    runtime_diagnostics=runner.classify_runtime(GUARD, True),
                    cycles=4, samples=rows, process_cpu_seconds=1,
                    daemon_wall_seconds=1, process_peak_memory_bytes=1,
                    peak_helper_slots=1, memory_samples=1, identity_failures=0,
                    operation_trace=[], clock=4, rng_thresholds=[], events=[],
                    reference_scope='guarded legacy reference', process_metric_scope='synthetic',
                    peak_gap_ds=1, peak_gap_ticks=1, positive_pause_calls=1,
                    zero_pause_calls=1)

    def test_guarded_comparator_and_fail_closed_controls(self):
        old = self.evidence()
        new = copy.deepcopy(old)
        new.update(mode='candidate', negative_control='none',
                   runtime_diagnostics=runner.classify_runtime('Welcome\n'),
                   reference_scope='strict clean',
                   budget_service={'seen': 1, 'progress': True, 'serviced': True})
        with tempfile.TemporaryDirectory(prefix='season-harness-test-') as tmp:
            a, b = Path(tmp) / 'old.json', Path(tmp) / 'new.json'
            a.write_text(json.dumps(old))
            command = [sys.executable, str(HERE / 'compare.py'), str(a), str(b), '--max-gap-ds', '10']
            def compare(evidence, opt_in=True):
                b.write_text(json.dumps(evidence))
                return subprocess.run(command + (['--allow-legacy-loop-baseline'] if opt_in else []), capture_output=True, text=True)
            positive = compare(new)
            self.assertEqual(positive.returncode, 0, positive.stderr)
            output = json.loads(positive.stdout)
            self.assertIsNone(output['candidate_baseline_ratios'])
            self.assertFalse(output['clean_paired_performance_equivalence'])
            self.assertNotEqual(compare(new, False).returncode, 0)
            for name in ('candidate_guard', 'ordered_parity', 'missing_telemetry', 'partial_cycles'):
                bad = copy.deepcopy(new)
                if name == 'candidate_guard': bad['runtime_diagnostics'] = runner.classify_runtime(GUARD)
                elif name == 'ordered_parity': bad['events'] = ['changed']
                elif name == 'missing_telemetry': bad['process_cpu_seconds'] = None
                else: bad['samples'].pop()
                with self.subTest(name=name):
                    self.assertNotEqual(compare(bad).returncode, 0)

if __name__ == '__main__':
    unittest.main()
