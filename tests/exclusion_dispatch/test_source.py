"""Offline source sensitivity checks; these do not establish native DM parity."""
import json
from pathlib import Path
import re
import runpy
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

import resources
from source_contract import reconstruct_list_baseline, transform, validate, project_reserved_policy, AREA_POLICY

ROOT = Path(__file__).resolve().parents[2]
BASE = '5bf351248de6050876fe5b53f91209a970cc5668'
PATH = 'code/modules/persistence/functions.dm'
NEW_KEYS = ('next_click', 'next_move', 'may_do_after', 'may_do_mob',
            'blackout_click_owner', 'blackout_click_client_ref', 'blackout_click_counts',
            'blackout_click_started', 'blackout_click_expires',
            'pickaxe_mining_owner', 'mining_in_progress', 'pickaxe_mining_action',
            'lighting_reserved', 'lighting_reserved_clearance_enabled')


class SourceContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.baseline = subprocess.check_output(['git', 'show', BASE + ':' + PATH], cwd=ROOT, text=True)
        cls.master = cls.baseline
        cls.baseline = reconstruct_list_baseline(cls.master)
        cls.candidate = (ROOT / PATH).read_text()

    def test_exact_transform_preserves_current_master(self):
        validate(self.baseline, self.candidate)
        for kind, count in [('atom', 3), ('turf', 9), ('mob', 22)]:
            body = re.search(rf'^/{kind}/persistence_runtime_var\(key\)\n(?:\t[^\n]*\n)+', self.candidate, re.M).group()
            self.assertEqual(len(re.findall(r'"[^"]+"', body)), count)
        self.assertIn('key == "weak_reference"', self.candidate)
        self.assertEqual(self.candidate.count('apply_restored_lighting()'), self.baseline.count('apply_restored_lighting()'))

    def test_reconstructed_hooks_match_reviewed_historical_hooks(self):
        historical = subprocess.check_output(['git', 'show',
            '5ac2df336b717f4ca2ccc60f2697b76ab4f2e019:' + PATH], cwd=ROOT, text=True)
        for kind in ('atom', 'turf', 'mob'):
            pattern = rf'^/{kind}/persistence_runtime_var\(key\)\n(?:\t[^\n]*\n)+'
            self.assertEqual(re.search(pattern, self.baseline, re.M).group(),
                             re.search(pattern, historical, re.M).group())
        for kind in ('atom', 'turf', 'mob'):
            with self.assertRaises(ValueError):
                reconstruct_list_baseline(self.master.replace(
                    f'/{kind}/persistence_runtime_var(key)', f'/{kind}/missing(key)'))
        with self.assertRaises(ValueError):
            reconstruct_list_baseline(self.baseline)

    def test_current_master_diagnostics_are_preserved_exactly(self):
        start = '/map_storage/persistence_runtime_var(key)'
        end = '// Drops the save/load bookkeeping references'
        def diagnostics(source):
            return source[source.index(start):source.index(end)]
        self.assertEqual(diagnostics(self.master), diagnostics(self.candidate))
        with self.assertRaises(ValueError):
            validate(self.baseline, self.candidate.replace(
                'saving_export_stack.len - 7', 'saving_export_stack.len - 8'))
        with self.assertRaises(ValueError):
            validate(self.baseline, self.candidate.replace(
                'if(key == "last_save_reference_failure") return TRUE', 'return FALSE'))

    def test_each_new_exclusion_omission_is_rejected(self):
        for key in NEW_KEYS:
            with self.subTest(key=key), self.assertRaises(ValueError):
                validate(self.baseline, self.candidate.replace(f'"{key}"', '"omitted_runtime_key"', 1))

    def test_parent_dispatch_controls_are_rejected(self):
        for mutated in (self.candidate.replace('\treturn ..()', '\treturn FALSE', 1),
                        self.candidate.replace('\tswitch(key)', '\t..()\n\tswitch(key)', 1)):
            with self.subTest(mutated=mutated[:40]), self.assertRaises(ValueError):
                validate(self.baseline, mutated)

    def test_unrelated_and_weak_reference_changes_are_rejected(self):
        for mutated in (self.candidate + '// unrelated\n',
                        self.candidate.replace(' || key == "weak_reference"', ''),
                        self.candidate.replace('\t\tapply_restored_lighting()\n', '', 1)):
            with self.subTest(mutated=mutated[:40]), self.assertRaises(ValueError):
                validate(self.baseline, mutated)

    def test_reserved_projection_is_explicit_and_fails_closed(self):
        projected = project_reserved_policy(self.baseline)
        self.assertIn('list("lighting_reserved", "affecting_lights"', projected)
        self.assertIn(AREA_POLICY, projected)
        with self.assertRaises(ValueError):
            project_reserved_policy(projected)
        with self.assertRaises(ValueError):
            validate(self.baseline, self.candidate.replace(AREA_POLICY, ''))

    def test_missing_baseline_hook_fails_closed(self):
        with self.assertRaises(ValueError):
            transform(self.baseline.replace('/mob/persistence_runtime_var(key)', '/mob/other(key)'))

    def run_runner(self, arguments):
        with patch.object(sys, 'argv', ['run.py'] + arguments), \
             patch.object(resources.Budget, 'run', side_effect=AssertionError('Native launch attempted')), \
             patch.object(resources, 'binary_info', side_effect=AssertionError('Binary query attempted')):
            with self.assertRaises(SystemExit) as exited:
                runpy.run_path(str(ROOT / 'tests/exclusion_dispatch/run.py'), run_name='__main__')
        return exited.exception.code

    def test_source_only_generates_actual_hooks_and_cases_without_native(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / 'source.json'
            self.assertEqual(self.run_runner(['--source-only', '--output', str(output)]), 0)
            receipt = json.loads(output.read_text())
            self.assertFalse(receipt['native_execution'])
            self.assertEqual(receipt['binaries'], {})
            self.assertIn('-trusted', receipt['commands']['daemon'])
            self.assertNotIn('-safe', receipt['commands']['daemon'])
            self.assertIn('HELD', receipt['execution_authorization'])
            generated = output.with_suffix('.sources')
            production = (generated / 'production.dm').read_text()
            probe = (generated / 'probe.dm').read_text()
            for key in (*NEW_KEYS, 'weak_reference'):
                self.assertIn(f'"{key}"', probe)
                for variant in ('baseline', 'candidate'):
                    kind = ('datum/proc' if key == 'weak_reference' else
                            'area' if key == 'lighting_reserved_clearance_enabled' else
                            'turf' if key in ('pickaxe_mining_owner', 'mining_in_progress', 'lighting_reserved') else 'mob')
                    body = re.search(rf'^/{kind}/{variant}_runtime\(key\)\n(?:\t[^\n]*\n)+', production, re.M).group()
                    self.assertIn(f'"{key}"', body)
            self.assertIn('source_contract.py', receipt['inputs'])

    def test_native_probe_uses_postclose_state_and_constructible_atom(self):
        probe = (ROOT / 'tests/exclusion_dispatch/probe.dm').read_text()
        self.assertNotIn('network_receipt["close_result"] != 1', probe)
        self.assertIn('network_receipt["closed_port"] != 0', probe)
        self.assertIn('network_receipt["reopen_result"] != FALSE', probe)
        self.assertIn('list(/datum,/atom/movable,/obj', probe)
        self.assertNotIn('list(/datum,/atom,/obj', probe)

    def test_early_mining_exclusions_are_preserved_before_switch(self):
        for kind, guard in (('turf', 'if (key == "pickaxe_mining_owner" || key == "mining_in_progress")'),
                            ('mob', 'if (key == "pickaxe_mining_action")')):
            body = re.search(rf'^/{kind}/persistence_runtime_var\(key\)\n(?:\t[^\n]*\n)+', self.candidate, re.M).group()
            self.assertLess(body.index(guard), body.index('switch(key)'))
            with self.assertRaises(ValueError):
                validate(self.baseline, self.candidate.replace(guard, 'if (FALSE)'))

    def test_native_mode_is_unconditionally_held_even_with_old_receipt(self):
        with tempfile.TemporaryDirectory() as directory:
            code = self.run_runner(['--output', str(Path(directory) / 'unused.json'),
                                    '--lease-receipt', str(Path(directory) / 'old-grant.json')])
            self.assertIn('Native execution held', code)
            self.assertIn('old leases invalid', code)


if __name__ == '__main__':
    unittest.main()
