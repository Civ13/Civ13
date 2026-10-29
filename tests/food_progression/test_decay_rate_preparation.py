"""Offline checks for the bounded rack decay diagnostic and mutation controls."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
RUNNER = ROOT / 'tests/food_progression/preservation_run.py'
FIXTURE = (ROOT / 'tests/food_progression/preservation.dm').read_text(encoding='utf-8')


class DecayRatePreparationTests(unittest.TestCase):
    def test_first_mutation_failures_remain_causal(self):
        runner = RUNNER.read_text(encoding='utf-8')
        self.assertIn("'FAIL: salted dried meat lasts four times longer and retains age' if args.preservation_control == 'age'", runner)
        self.assertIn("'FAIL: dried save does not restore depleted nutrition' if args.preservation_control == 'nutrition'", runner)
        self.assertIn("'FAIL: drying retains available nutrition across reagent conversion' if args.preservation_control == 'conversion'", runner)
        salted = FIXTURE.split('/proc/check_salted_meat(', 1)[1].split('\n/proc/', 1)[0]
        self.assertIn('input.reagents.remove_reagent("protein", 1)', salted)
        self.assertLess(salted.index('salted dried meat lasts four times longer and retains age'), salted.index('dried save does not restore depleted nutrition'))
        self.assertIn('restored_dried.nutriments_value() == 0', salted)
        self.assertIn("output_food.decaytimer = 0 // omission control", runner)
        self.assertIn("production = production[:start] + replacement + production[end:]", runner)

    def test_prepare_baseline_and_restart_omission_without_native_execution(self):
        with tempfile.TemporaryDirectory(prefix='food-decay-contract-') as tmp:
            for control in (None, 'omit-restart'):
                output = Path(tmp) / (control or 'baseline')
                args = [sys.executable, '-B', str(RUNNER), '--probe', 'decay-rate',
                        '--byond-bin', '.', '--expected-byond-version', '516.1688',
                        '--prepare-only', '--output', str(output)]
                if control:
                    args += ['--decay-rate-control', control]
                result = subprocess.run(args, cwd=ROOT, capture_output=True, text=True, timeout=30)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertIn('no compiler or daemon launched', result.stdout)
                meta = json.loads((output / 'metadata.json').read_text(encoding='utf-8'))
                self.assertEqual((meta['probe'], meta['food_wait_ticks'], meta['decay_rate_control']), ('decay-rate', 20, control))
                self.assertEqual(meta['rack_restart_ticks'], None if control else 21)
                food = next(output.glob('*_food.dm')).read_text(encoding='utf-8')
                production = next(output.glob('*_production.dm')).read_text(encoding='utf-8')
                probe = (output / 'probe.dm').read_text(encoding='utf-8')
                self.assertIn('spawn(20) //some spreading and randomness', food)
                self.assertIn('second_restored == second_reference', probe)
                self.assertIn('world.time == start', probe)
                if control:
                    self.assertIn('Diagnostic control omits the rack restart.', production)
                    self.assertNotIn('spawn(21) //in order not to create a duplicate process', production)
                else:
                    self.assertIn('spawn(21) //in order not to create a duplicate process', production)
                    self.assertIn('D.food_decay() //restarting decay process', production)


if __name__ == '__main__':
    unittest.main()
