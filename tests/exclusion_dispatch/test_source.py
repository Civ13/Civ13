"""Offline source sensitivity checks; these do not establish native DM parity."""
import json
import base64
import hashlib
import importlib.util
from importlib.machinery import SourceFileLoader
import shutil
from types import SimpleNamespace
import os
from pathlib import Path
import re
import runpy
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch

import resources
from source_contract import reconstruct_list_baseline, BOUNDED_BLOCKS, project_bounded_save, transform, validate, project_reserved_policy, AREA_POLICY
from source_contract import (validate_current_master, validate_historical_bounded, project_lighting_policy, project_fullbright_exclusions, project_area_change_owner, CURRENT_BASE, MERGE_BASE, MERGE_MASTER, validate_merged_source, project_merged_source, event_identity, replay_reviewed_merge, resolve_event_projection, current_lighting_policy)

# Frozen reconciliation checkpoint for historical assertions, never the runner's
# live reference. Actual CI preparation uses the immutable event pair instead.
RECONCILIATION_CHECKPOINT = 'eedc9862fcb7b2b7c3617c6972965fafa650e51a'
RECONCILIATION_CANDIDATE = '2d8b3c152bf321c442e154240e52bb41c71c1688'

ROOT = Path(__file__).resolve().parents[2]
BASE = '5bf351248de6050876fe5b53f91209a970cc5668'
PATH = 'code/modules/persistence/functions.dm'
EXTRACTION_BASE = 'a8d3950f08aaa55db59ec5f20777a475b2db95bb'
historical_path = ROOT / 'tests/exclusion_dispatch/historical/source_contract.py.txt'
historical_spec = importlib.util.spec_from_loader('historical_exclusion_contract', SourceFileLoader('historical_exclusion_contract', str(historical_path)))
historical_contract = importlib.util.module_from_spec(historical_spec)
historical_spec.loader.exec_module(historical_contract)


def frozen_lighting_candidate():
    # The merged PR's temporary source commit is not an ancestor of master.
    # Preserve its actual bytes as historical evidence, never as live input.
    encoded = (ROOT / 'tests/exclusion_dispatch/historical/lighting-candidate-functions.dm.b64.txt').read_text(encoding='ascii')
    data = base64.b64decode(''.join(encoded.split()), validate=True)
    if hashlib.sha256(data).hexdigest() != '7d287e7a316bc63ca28c4d3fe27d10d0f14d2a3cf076ebfb026073e75a06fe02':
        raise ValueError('Frozen lighting candidate bytes differ from 2d8b3c15')
    return data.decode('utf-8')
NEW_KEYS = ('next_click', 'next_move', 'may_do_after', 'may_do_mob',
            'blackout_click_owner', 'blackout_click_client_ref', 'blackout_click_counts',
            'blackout_click_started', 'blackout_click_expires',
            'pickaxe_mining_owner', 'mining_in_progress', 'pickaxe_mining_action',
            'lighting_reserved', 'lighting_reserved_clearance_enabled')


def runner_argv(arguments):
    if os.environ.get('GITHUB_ACTIONS') == 'true':
        return ['run.py'] + arguments  # exercise the CI event identities unchanged
    head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    return ['run.py', '--base', RECONCILIATION_CHECKPOINT, '--head', head] + arguments


class HistoricalSourceContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.baseline = subprocess.check_output(['git', 'show', BASE + ':' + PATH], cwd=ROOT, text=True)
        cls.master = cls.baseline
        cls.baseline = reconstruct_list_baseline(cls.master)
        # Retain the original immutable comparison and its defect controls.
        cls.candidate = subprocess.check_output(['git', 'show',
            '7ca76ce0e23661f4dea5a44acb195bf3010a97eb:' + PATH], cwd=ROOT, text=True)

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

    def test_bounded_projection_is_exact_and_fail_closed(self):
        projected = project_bounded_save(self.baseline)
        for anchor, addition in BOUNDED_BLOCKS:
            self.assertIn(anchor + addition, projected)
            for changed in (self.baseline.replace(anchor, '', 1), self.baseline + anchor):
                with self.assertRaises(ValueError):
                    project_bounded_save(changed)
            with self.assertRaises(ValueError):
                validate(self.baseline, self.candidate.replace(addition, '', 1))
        with self.assertRaises(ValueError):
            validate(self.baseline + '// unrelated baseline drift\n', self.candidate)

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
        with patch.object(sys, 'argv', runner_argv(arguments)), \
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


HISTORICAL_BASE = BASE
LIGHTING_KEYS = ('next_click', 'next_move', 'may_do_after', 'may_do_mob',
            'blackout_click_owner', 'blackout_click_client_ref', 'blackout_click_counts',
            'blackout_click_started', 'blackout_click_expires',
            'pickaxe_mining_owner', 'mining_in_progress', 'pickaxe_mining_action',
            'lighting_reserved', 'lighting_reserved_clearance_enabled', 'area_change_owner',
            'original_target', 'next_animal_retaliation', 'snowfall_ground_index',
            'snowfall_ground_generation', 'weather_snow_overlay', 'persistence_zone_id')
CURRENT_AREA_POLICY = AREA_POLICY.replace(' || ..()', ' || key == "persistence_zone_id" || ..()')
SNOW_GUARD = ('\tif (key == "snowfall_ground_index" || key == "snowfall_ground_generation"'
              ' || key == "weather_snow_overlay")\n\t\treturn TRUE\n')


class CurrentMasterContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.master = subprocess.check_output(['git', 'show', RECONCILIATION_CHECKPOINT + ':' + PATH], cwd=ROOT, text=True)
        cls.candidate = frozen_lighting_candidate()

    def test_entire_current_master_is_preserved_plus_only_lighting_exclusions(self):
        validate_current_master(self.master, self.candidate)

    def test_current_guards_diagnostics_and_each_bounded_block_cannot_be_removed(self):
        for marker in ('key == "original_target"', '"next_animal_retaliation"',
                       '"validated_roof_absent"', 'saving_export_stack.len - 7',
                       'if(key == "last_save_reference_failure") return TRUE'):
            with self.subTest(marker=marker):
                self.assertIn(marker, self.candidate)
                with self.assertRaises(ValueError):
                    validate_current_master(self.master, self.candidate.replace(marker, '', 1))
        for _, addition in BOUNDED_BLOCKS:
            with self.subTest(addition=addition), self.assertRaises(ValueError):
                validate_current_master(self.master, self.candidate.replace(addition, '', 1))
        with self.assertRaises(ValueError):
            validate_current_master(self.master, self.candidate + '// unrelated drift\n')



    def test_unrelated_master_evolution_is_allowed_only_when_retained_exactly(self):
        addition = '\n// Unrelated future upstream bookkeeping.\n/map_storage/proc/base_evolution_probe()\n\treturn TRUE\n'
        evolved = self.master + addition
        validate_current_master(evolved, self.candidate + addition)
        with self.assertRaises(ValueError):
            validate_current_master(evolved, self.candidate)
        with self.assertRaises(ValueError):
            validate_current_master(self.master, self.candidate + addition)

    def test_bounded_blocks_are_upstream_and_only_lighting_is_added(self):
        for _, addition in BOUNDED_BLOCKS:
            self.assertEqual(self.master.count(addition), 1)
            self.assertEqual(self.candidate.count(addition), 1)
        self.assertEqual(project_lighting_policy(self.master), self.candidate)
        with self.assertRaises(ValueError):
            validate_current_master(project_bounded_save(self.master), self.candidate)

class LightingCurrentMasterContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.baseline = subprocess.check_output(['git', 'show', RECONCILIATION_CHECKPOINT + ':' + PATH], cwd=ROOT, text=True)
        cls.master = cls.baseline
        cls.baseline = reconstruct_list_baseline(cls.master)
        cls.historical_baseline = reconstruct_list_baseline(subprocess.check_output(
            ['git', 'show', HISTORICAL_BASE + ':' + PATH], cwd=ROOT, text=True))
        cls.candidate = frozen_lighting_candidate()

    def test_exact_transform_preserves_current_master(self):
        validate_current_master(self.master, self.candidate)
        for kind, count in [('atom', 3), ('turf', 13), ('mob', 23)]:
            body = re.search(rf'^/{kind}/persistence_runtime_var\(key\)\n(?:\t[^\n]*\n)+', self.candidate, re.M).group()
            self.assertEqual(len(re.findall(r'"[^"]+"', body)), count)
        self.assertIn('key == "weak_reference"', self.candidate)
        self.assertEqual(self.candidate.count('apply_restored_lighting()'), self.baseline.count('apply_restored_lighting()'))

    def test_reconstructed_hooks_match_reviewed_historical_hooks(self):
        historical = subprocess.check_output(['git', 'show',
            '5ac2df336b717f4ca2ccc60f2697b76ab4f2e019:' + PATH], cwd=ROOT, text=True)
        current_expected = project_reserved_policy(self.historical_baseline).replace(
            'if (key == "pickaxe_mining_action")',
            'if (key == "pickaxe_mining_action" || key == "next_animal_retaliation")', 1)
        current_expected = current_expected.replace('/turf/persistence_runtime_var(key)\n',
            '/turf/persistence_runtime_var(key)\n' + SNOW_GUARD, 1)
        for kind in ('atom', 'turf', 'mob'):
            pattern = rf'^/{kind}/persistence_runtime_var\(key\)\n(?:\t[^\n]*\n)+'
            self.assertEqual(re.search(pattern, self.historical_baseline, re.M).group(),
                             re.search(pattern, historical, re.M).group())
            self.assertEqual(re.search(pattern, self.baseline, re.M).group(),
                             re.search(pattern, current_expected, re.M).group())
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
            validate_current_master(self.master, self.candidate.replace(
                'saving_export_stack.len - 7', 'saving_export_stack.len - 8'))
        with self.assertRaises(ValueError):
            validate_current_master(self.master, self.candidate.replace(
                'if(key == "last_save_reference_failure") return TRUE', 'return FALSE'))

    def test_each_new_exclusion_omission_is_rejected(self):
        for key in LIGHTING_KEYS:
            with self.subTest(key=key), self.assertRaises(ValueError):
                validate_current_master(self.master, self.candidate.replace(f'"{key}"', '"omitted_runtime_key"', 1))

    def test_parent_dispatch_controls_are_rejected(self):
        for mutated in (self.candidate.replace('\treturn ..()', '\treturn FALSE', 1),
                        self.candidate.replace('\tswitch(key)', '\t..()\n\tswitch(key)', 1)):
            with self.subTest(mutated=mutated[:40]), self.assertRaises(ValueError):
                validate_current_master(self.master, mutated)

    def test_unrelated_and_weak_reference_changes_are_rejected(self):
        for mutated in (self.candidate + '// unrelated\n',
                        self.candidate.replace(' || key == "weak_reference"', ''),
                        self.candidate.replace('\t\tapply_restored_lighting()\n', '', 1)):
            with self.subTest(mutated=mutated[:40]), self.assertRaises(ValueError):
                validate_current_master(self.master, mutated)

    def test_reserved_projection_is_explicit_and_fails_closed(self):
        projected = project_reserved_policy(self.historical_baseline)
        self.assertIn('list("lighting_reserved", "affecting_lights"', projected)
        self.assertIn(AREA_POLICY, projected)
        with self.assertRaises(ValueError):
            project_reserved_policy(projected)
        with self.assertRaises(ValueError):
            project_reserved_policy(self.baseline)
        with self.assertRaises(ValueError):
            validate_current_master(self.master, self.candidate.replace(CURRENT_AREA_POLICY, ''))

    def test_current_snow_and_zone_exclusions_remain_independently_required(self):
        self.assertIn(SNOW_GUARD, self.master)
        self.assertIn(SNOW_GUARD, self.candidate)
        self.assertIn(CURRENT_AREA_POLICY, self.master)
        self.assertIn(CURRENT_AREA_POLICY, self.candidate)
        for anchor in (SNOW_GUARD, ' || key == "persistence_zone_id"'):
            with self.subTest(anchor=anchor), self.assertRaises(ValueError):
                validate_current_master(self.master, self.candidate.replace(anchor, '', 1))

    def test_fullbright_projection_is_exact_and_fails_closed(self):
        projected = project_fullbright_exclusions(self.baseline)
        self.assertEqual(projected.count('/atom/movable/lighting_fullbright'), 2)
        with self.assertRaises(ValueError):
            project_fullbright_exclusions(projected)
        for before in ('list(/mob/new_player, /atom/movable/lighting_overlay)',
                       'if(istype(object, /obj/map_metadata) || istype(object, /atom/movable/lighting_overlay))'):
            with self.subTest(anchor=before), self.assertRaises(ValueError):
                project_fullbright_exclusions(self.baseline.replace(before, 'missing_anchor', 1))
        for index in (0, 1):
            token = '/atom/movable/lighting_fullbright'
            positions = [match.start() for match in re.finditer(re.escape(token), self.candidate)]
            position = positions[index]
            mutated = self.candidate[:position] + '/atom/movable/invalid_runtime_type' + self.candidate[position + len(token):]
            with self.subTest(exclusion=index), self.assertRaises(ValueError):
                validate_current_master(self.master, mutated)

    def test_missing_baseline_hook_fails_closed(self):
        with self.assertRaises(ValueError):
            reconstruct_list_baseline(self.master.replace('/mob/persistence_runtime_var(key)', '/mob/other(key)'))

    def test_area_owner_projection_is_exact_and_fails_closed(self):
        projected = project_area_change_owner(self.baseline)
        self.assertEqual(projected, self.baseline.replace('/turf/persistence_runtime_var(key)\n', '/turf/persistence_runtime_var(key)\n\tif (key == "area_change_owner")\n\t\treturn TRUE\n', 1))
        with self.assertRaises(ValueError):
            project_area_change_owner(projected)
        with self.assertRaises(ValueError):
            project_area_change_owner(self.baseline.replace('/turf/persistence_runtime_var(key)', '/turf/other(key)'))

    def run_runner(self, arguments):
        with patch.object(sys, 'argv', runner_argv(arguments)), \
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
            for key in (*LIGHTING_KEYS, 'weak_reference'):
                self.assertIn(f'"{key}"', probe)
                for variant in ('baseline', 'candidate'):
                    kind = ('datum/proc' if key == 'weak_reference' else
                            'atom/movable' if key == 'original_target' else
                            'area' if key in ('lighting_reserved_clearance_enabled', 'persistence_zone_id') else
                            'turf' if key in ('pickaxe_mining_owner', 'mining_in_progress', 'lighting_reserved', 'area_change_owner',
                                             'snowfall_ground_index', 'snowfall_ground_generation', 'weather_snow_overlay') else 'mob')
                    # Multiple native same-type overrides retain the functions
                    # guard followed by the production process hook.
                    bodies = re.findall(rf'^/{kind}/{variant}_runtime\(key\)\n(?:\t[^\n]*\n)+', production, re.M)
                    self.assertTrue(any(f'"{key}"' in body for body in bodies))
            self.assertIn('source_contract.py', receipt['inputs'])
            for variant in ('baseline', 'candidate'):
                selected = production.split(f'/datum/proc/{variant}_saved()', 1)[1].split('/turf/floor/dirt/', 1)[0]
                self.assertIn('#ifdef CIV13_VARIABLE_OBSERVABILITY\n\t\t\t\tvariable_observability_skipped(src.vars[key])\n#endif\n\t\t\t\tcontinue', selected)
                self.assertIn('\n\treturn to_save\n', selected)
                self.assertLess(production.index(f'/atom/movable/{variant}_runtime(key)\n\treturn key == "original_target"'),
                                production.index(f'/atom/movable/{variant}_runtime(key)\n\tif (key == "corpse_decay_record")'))
            self.assertNotIn('#define CIV13_VARIABLE_OBSERVABILITY', (generated / 'probe.dme').read_text())

    def test_native_probe_uses_postclose_state_and_constructible_atom(self):
        probe = (ROOT / 'tests/exclusion_dispatch/probe.dm').read_text()
        self.assertNotIn('network_receipt["close_result"] != 1', probe)
        self.assertIn('network_receipt["closed_port"] != 0', probe)
        self.assertIn('network_receipt["reopen_result"] != FALSE', probe)
        self.assertIn('list(/datum,/atom/movable,/obj', probe)
        self.assertNotIn('list(/datum,/atom,/obj', probe)

    def test_early_mining_exclusions_are_preserved_before_switch(self):
        for kind, guard in (('turf', 'if (key == "pickaxe_mining_owner" || key == "mining_in_progress")'),
                            ('mob', 'if (key == "pickaxe_mining_action" || key == "next_animal_retaliation")')):
            body = re.search(rf'^/{kind}/persistence_runtime_var\(key\)\n(?:\t[^\n]*\n)+', self.candidate, re.M).group()
            self.assertLess(body.index(guard), body.index('switch(key)'))
            with self.assertRaises(ValueError):
                validate_current_master(self.master, self.candidate.replace(guard, 'if (FALSE)'))

    def test_native_mode_is_unconditionally_held_even_with_old_receipt(self):
        with tempfile.TemporaryDirectory() as directory:
            code = self.run_runner(['--output', str(Path(directory) / 'unused.json'),
                                    '--lease-receipt', str(Path(directory) / 'old-grant.json')])
            self.assertIn('Native execution held', code)
            self.assertIn('old leases invalid', code)


class ExtractionHistoricalSourceContractTests(unittest.TestCase):
    validate = staticmethod(historical_contract.validate)
    diagnostic_guard = 'if(key in list("last_save_reference_failure", "restore_policy", "restore_cleanup_error")) return TRUE'
    @classmethod
    def setUpClass(cls):
        cls.baseline = subprocess.check_output(['git', 'show', EXTRACTION_BASE + ':' + PATH], cwd=ROOT, text=True)
        cls.master = cls.baseline
        cls.baseline = reconstruct_list_baseline(cls.master)
        # Preserve this packet's exact historical semantics and mutation oracles.
        # Current merged source is independently checked below, never projected
        # back into this historical packet or described as its native evidence.
        cls.candidate = subprocess.check_output(['git', 'show',
            '5aaed0a172aa3baa3fe604096cbbb8a00f519aac:' + PATH], cwd=ROOT, text=True)

    def test_exact_transform_preserves_historical_master(self):
        self.validate(self.baseline, self.candidate)
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

    def test_historical_master_diagnostics_are_preserved_exactly(self):
        start = '/map_storage/persistence_runtime_var(key)'
        end = '// Drops the save/load bookkeeping references'
        def diagnostics(source):
            return source[source.index(start):source.index(end)]
        self.assertEqual(diagnostics(self.master), diagnostics(self.candidate))
        with self.assertRaises(ValueError):
            self.validate(self.baseline, self.candidate.replace(
                'saving_export_stack.len - 7', 'saving_export_stack.len - 8'))
        with self.assertRaises(ValueError):
            self.validate(self.baseline, self.candidate.replace(
                self.diagnostic_guard, 'return FALSE'))

    def test_each_new_exclusion_omission_is_rejected(self):
        for key in NEW_KEYS:
            with self.subTest(key=key), self.assertRaises(ValueError):
                self.validate(self.baseline, self.candidate.replace(f'"{key}"', '"omitted_runtime_key"', 1))

    def test_parent_dispatch_controls_are_rejected(self):
        for mutated in (self.candidate.replace('\treturn ..()', '\treturn FALSE', 1),
                        self.candidate.replace('\tswitch(key)', '\t..()\n\tswitch(key)', 1)):
            with self.subTest(mutated=mutated[:40]), self.assertRaises(ValueError):
                self.validate(self.baseline, mutated)

    def test_unrelated_and_weak_reference_changes_are_rejected(self):
        for mutated in (self.candidate + '// unrelated\n',
                        self.candidate.replace(' || key == "weak_reference"', ''),
                        self.candidate.replace('\t\tapply_restored_lighting()\n', '', 1)):
            with self.subTest(mutated=mutated[:40]), self.assertRaises(ValueError):
                self.validate(self.baseline, mutated)

    def test_reserved_projection_is_explicit_and_fails_closed(self):
        projected = project_reserved_policy(self.baseline)
        self.assertIn('list("lighting_reserved", "affecting_lights"', projected)
        self.assertIn(AREA_POLICY, projected)
        with self.assertRaises(ValueError):
            project_reserved_policy(projected)
        with self.assertRaises(ValueError):
            self.validate(self.baseline, self.candidate.replace(AREA_POLICY, ''))

    def test_missing_baseline_hook_fails_closed(self):
        with self.assertRaises(ValueError):
            transform(self.baseline.replace('/mob/persistence_runtime_var(key)', '/mob/other(key)'))

    def run_runner(self, arguments):
        return HistoricalSourceContractTests.run_runner(self, arguments)

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
            self.assertIn('"original_target"', probe)
            self.assertIn('candidate_runtime("original_target"),TRUE', probe)
            self.assertLess(production.index('key == "original_target"'), production.index('key == "corpse_decay_record"'))
            self.assertLess((ROOT / 'civ13.dme').read_text().index('persistence\\functions.dm'),
                            (ROOT / 'civ13.dme').read_text().index('processes\\human_corpse_decay.dm'))
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
                self.validate(self.baseline, self.candidate.replace(guard, 'if (FALSE)'))

    def test_native_mode_is_unconditionally_held_even_with_old_receipt(self):
        with tempfile.TemporaryDirectory() as directory:
            code = self.run_runner(['--output', str(Path(directory) / 'unused.json'),
                                    '--lease-receipt', str(Path(directory) / 'old-grant.json')])
            self.assertIn('Native execution held', code)
            self.assertIn('old leases invalid', code)


class ReviewedCurrentSource(unittest.TestCase):
    REVIEWED = 'c4585fabaf81e1357054b4527d71d4f3a2d8a0b2'

    @classmethod
    def setUpClass(cls):
        cls.feature = subprocess.check_output(['git', 'show', MERGE_BASE + ':' + PATH], cwd=ROOT, text=True)
        cls.reviewed = subprocess.check_output(['git', 'show', cls.REVIEWED + ':' + PATH], cwd=ROOT, text=True)
        cls.current = (ROOT / PATH).read_text()
        assert cls.reviewed == cls.feature
        cls.identity = event_identity(ROOT)
        if cls.identity:
            head = subprocess.check_output(['git', 'show', cls.identity['head'] + ':' + PATH], cwd=ROOT, text=True)
            if head != cls.current: raise ValueError('Checkout differs from source event head')
            ancestor = subprocess.check_output(['git', 'show', MERGE_MASTER + ':' + PATH], cwd=ROOT, text=True)
            snapshot = project_merged_source(cls.feature)
            validate_merged_source(cls.feature, snapshot)
            cls.expected, _ = resolve_event_projection(ROOT, cls.identity, cls.feature, cls.current, ancestor, snapshot)
        else:
            cls.expected = current_lighting_policy(project_merged_source(cls.feature))

    def validate_current(self, source):
        # Full-file equality includes admitted custody, roof/zone cleanup and
        # diagnostics. A future production change needs a newly reviewed pin.
        if source != self.expected:
            raise ValueError('Current runtime exclusions differ from the reviewed event projection')

    def test_complete_reviewed_source_and_all_exclusion_omissions(self):
        self.validate_current(self.current)
        hooks = re.findall(r'^/(?:atom|turf|mob|area|map_storage)/persistence_runtime_var\(key\)\n(?:\t[^\n]*\n|#(?:if[^\n]*|endif)\n)+', self.current, re.M)
        self.assertEqual(len(hooks), 5)
        keys = set(re.findall(r'"([a-z_]+)"', '\n'.join(hooks)))
        for key in (*NEW_KEYS, 'next_animal_retaliation', 'weather_snow_overlay',
                    'snowfall_ground_index', 'persistence_zone_id', 'restore_policy',
                    'validated_roof_areas', 'validated_zone_state'):
            self.assertIn(key, keys)
        for key in keys:
            with self.subTest(key=key), self.assertRaises(ValueError):
                self.validate_current(self.current.replace('"' + key + '"', '"omitted_runtime_key"', 1))

    def test_complete_guards_parent_order_and_diagnostics_cannot_drift(self):
        for guard in ('key == "pickaxe_mining_owner" || key == "mining_in_progress"',
                      'key == "pickaxe_mining_action" || key == "next_animal_retaliation"',
                      'saving_export_stack.len - 7', 'return ..()'):
            with self.subTest(guard=guard), self.assertRaises(ValueError):
                self.validate_current(self.current.replace(guard, 'omitted_guard', 1))

    def test_frozen_historical_helpers_remain_byte_identical(self):
        for name in ('run.py', 'source_contract.py', 'resources.py', 'probe.dm'):
            relative = 'tests/exclusion_dispatch/' + name
            expected = subprocess.check_output(['git', 'show',
                '5aaed0a172aa3baa3fe604096cbbb8a00f519aac:' + relative], cwd=ROOT)
            self.assertEqual((ROOT / 'tests/exclusion_dispatch/historical' / (name + '.txt')).read_bytes().replace(b'\r\n', b'\n'), expected)


class HistoricalMasterSourceContractTests(ExtractionHistoricalSourceContractTests):
    validate = staticmethod(validate)
    diagnostic_guard = 'if(key == "last_save_reference_failure") return TRUE'

    def test_bounded_projection_is_exact_and_fail_closed(self):
        projected = project_bounded_save(self.baseline)
        for anchor, addition in BOUNDED_BLOCKS:
            self.assertIn(anchor + addition, projected)
            for changed in (self.baseline.replace(anchor, '', 1), self.baseline + anchor):
                with self.assertRaises(ValueError):
                    project_bounded_save(changed)
            with self.assertRaises(ValueError):
                self.validate(self.baseline, self.candidate.replace(addition, '', 1))
        with self.assertRaises(ValueError):
            validate(self.baseline + '// unrelated baseline drift\n', self.candidate)

    @classmethod
    def setUpClass(cls):
        cls.master = subprocess.check_output(['git', 'show',
            '5bf351248de6050876fe5b53f91209a970cc5668:' + PATH], cwd=ROOT, text=True)
        cls.baseline = reconstruct_list_baseline(cls.master)
        cls.candidate = subprocess.check_output(['git', 'show',
            '7ca76ce0e23661f4dea5a44acb195bf3010a97eb:' + PATH], cwd=ROOT, text=True)


class MasterBoundedHistoryTests(unittest.TestCase):
    def test_master_bounded_projection_and_each_omission_remain_exact(self):
        master = subprocess.check_output(['git', 'show', CURRENT_BASE + ':' + PATH], cwd=ROOT, text=True)
        candidate = subprocess.check_output(['git', 'show',
            'd0c744919ba181e7a0bcfae222b5a37687af48fb:' + PATH], cwd=ROOT, text=True)
        validate_historical_bounded(master, candidate)
        for marker in ('key == "original_target"', '"next_animal_retaliation"',
                       '"validated_roof_absent"', 'saving_export_stack.len - 7',
                       'if(key == "last_save_reference_failure") return TRUE'):
            self.assertIn(marker, candidate)
            with self.subTest(marker=marker), self.assertRaises(ValueError):
                validate_historical_bounded(master, candidate.replace(marker, '', 1))
        for _, addition in BOUNDED_BLOCKS:
            with self.subTest(addition=addition), self.assertRaises(ValueError):
                validate_historical_bounded(master, candidate.replace(addition, '', 1))
        with self.assertRaises(ValueError): validate_historical_bounded(master, candidate + '// unrelated drift\n')

    def test_merged_projection_rejects_omission_and_duplicate_anchors(self):
        feature = subprocess.check_output(['git', 'show', MERGE_BASE + ':' + PATH], cwd=ROOT, text=True)
        current = project_merged_source(feature)
        validate_merged_source(feature, current)
        for anchor, addition in BOUNDED_BLOCKS:
            with self.subTest(anchor=anchor), self.assertRaises(ValueError):
                validate_merged_source(feature, current.replace(addition, '', 1))
            with self.subTest(duplicate=anchor), self.assertRaises(ValueError):
                project_merged_source(feature + anchor)
        for marker in ('if(current_state < GAME_STATE_PLAYING)', 'last_persistence_save_time = world.time',
                       'restore_cleanup_error', 'authorize_restore_mutation'):
            self.assertIn(marker, current)
            with self.subTest(marker=marker), self.assertRaises(ValueError):
                validate_merged_source(feature, current.replace(marker, 'omitted_guard', 1))


class EventRunnerTests(unittest.TestCase):
    """Exercise the actual source-only runner with evolving, injected event identities."""
    @classmethod
    def setUpClass(cls):
        cls.base_source = subprocess.check_output(['git', 'show', MERGE_MASTER + ':' + PATH], cwd=ROOT, text=True)
        feature = subprocess.check_output(['git', 'show', MERGE_BASE + ':' + PATH], cwd=ROOT, text=True)
        cls.feature_source = feature
        cls.merged = current_lighting_policy(project_merged_source(feature))
        cls.helpers = {p: (ROOT / p).read_text() for p in (
            'code/processes/human_corpse_decay.dm', 'code/processes/abandoned_items.dm',
            'code/modules/1713/active_training.dm')}
        cls.feature_helpers = {p: subprocess.check_output(['git', 'show', MERGE_BASE + ':' + p], cwd=ROOT, text=True)
                               for p in cls.helpers}

    def execute_runner(self, directory, control=None, *, mismatch=False, changed_helper=False, bad_event=False,
                       base_edit='\n// unrelated future base evolution\n', head_edit=None,
                       event_kind='pull_request', event_base=None, source_version='516.1681', feature_base=False,
                       replace_target=False, drop_custody=False, ancestry_result=0):
        base_sha, head_sha = 'b' * 40, 'a' * 40
        base = (self.feature_source if feature_base else self.base_source) + base_edit
        candidate = self.merged + (base_edit if head_edit is None else head_edit)
        if drop_custody:
            candidate = current_lighting_policy(base)
        if replace_target:
            anchor = 'return key == "original_target" || ..()'
            assert base.count(anchor) == candidate.count(anchor) == 1
            base = base.replace(anchor, 'return ..()', 1)
            candidate = candidate.replace(anchor, 'return ..()', 1)
        event = directory / 'event.json'
        event.write_text(json.dumps({'pull_request': {'base': {'sha': base_sha}, 'head': {'sha': 'c'*40 if bad_event else head_sha}},
                                     'before': base_sha if event_base is None else event_base,
                                     'after': 'c'*40 if bad_event else head_sha,
                                     'inputs': {'exclusion_comparison_base': base_sha if event_base is None else event_base}}))
        out = directory / ('receipt-' + (control or 'positive') + '.json')
        original_check_output = subprocess.check_output
        original_run = subprocess.run
        original_read_text = Path.read_text
        def git(command, **kwargs):
            if command[:3] == ['git', 'rev-parse', '--verify']:
                return command[3].removesuffix('^{commit}') + '\n'
            if command[:3] == ['git', 'rev-parse', 'HEAD']: return head_sha + '\n'
            if command[:2] == ['git', 'merge-base']:
                if command[-1] == MERGE_BASE:
                    return (MERGE_BASE if command[2] == head_sha or feature_base else MERGE_MASTER) + '\n'
                return (MERGE_MASTER if event_kind == 'pull_request' else base_sha) + '\n'
            if command[:2] == ['git', 'show']:
                ref, file = command[2].split(':', 1)
                if ref in (base_sha, head_sha):
                    if file == PATH: value = base if ref == base_sha else candidate
                    elif file in self.helpers:
                        value = self.feature_helpers[file] if feature_base and ref == base_sha else self.helpers[file]
                        if changed_helper and ref == head_sha: value += '\n// changed helper\n'
                    else:
                        value = original_read_text(ROOT / file, encoding='utf-8')
                    return value if kwargs.get('text') else value.encode()
            return original_check_output(command, **kwargs)
        def run(command, **kwargs):
            if command[:3] == ['git', 'merge-base', '--is-ancestor']:
                if isinstance(ancestry_result, Exception):
                    raise ancestry_result
                return subprocess.CompletedProcess(command, ancestry_result, '', 'injected Git error')
            return original_run(command, **kwargs)
        def read(path, *args, **kwargs):
            if path == ROOT / PATH: return candidate + ('// dirty checkout\n' if mismatch else '')
            return original_read_text(path, *args, **kwargs)
        argv = ['run.py', '--base', base_sha, '--head', head_sha, '--source-only', '--output', str(out)]
        if source_version != '516.1681': argv += ['--source-version', source_version]
        if control: argv += ['--negative-control', control]
        with patch.dict(os.environ, {'GITHUB_ACTIONS':'true', 'GITHUB_EVENT_NAME':event_kind,
                                     'GITHUB_EVENT_PATH':str(event), 'GITHUB_SHA':head_sha}), \
             patch.object(sys, 'argv', argv), patch.object(Path, 'read_text', read), \
             patch.object(subprocess, 'check_output', side_effect=git), \
             patch.object(subprocess, 'run', side_effect=run), \
             patch.object(resources.Budget, 'run', side_effect=AssertionError('Native launch attempted')), \
             patch.object(resources, 'binary_info', side_effect=AssertionError('Binary query attempted')):
            with self.assertRaises(SystemExit) as exited:
                runpy.run_path(str(ROOT / 'tests/exclusion_dispatch/run.py'), run_name='__main__')
        self.assertEqual(exited.exception.code, 0)
        receipt = json.loads(out.read_text())
        self.assertEqual(receipt['event_identity']['head'], head_sha)
        self.assertEqual(receipt['event_identity']['base'], base_sha)
        self.assertFalse(receipt['native_execution'])
        self.assertEqual(receipt['required_version'], source_version)
        self.assertEqual(receipt['projection'], 'feature-base' if feature_base else 'master-base')
        return out.with_suffix('.sources').joinpath('production.dm').read_text()

    def test_actual_runner_accepts_evolved_base_and_mutates_all_controls(self):
        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp)
            normal = self.execute_runner(directory)
            for control in ('omit', 'parent', 'eager'):
                changed = self.execute_runner(directory, control)
                self.assertNotEqual(changed, normal)
                atom = re.search(r'^/atom/candidate_runtime\(key\)\n(?:\t[^\n]*\n)+', changed, re.M).group()
                if control == 'omit': self.assertNotIn('"appearance"', atom)
                if control == 'parent': self.assertIn('return FALSE', atom)
                if control == 'eager': self.assertIn('\t..()\n\tswitch(key)', atom)

    def test_actual_runner_projects_movable_and_target_omission_without_touching_corpse_hook(self):
        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp)
            normal = self.execute_runner(directory)
            omitted = self.execute_runner(directory, 'target-omit', source_version='516.1688')
            pattern = r'^/atom/movable/(baseline|candidate)_runtime\(key\)\n(?:\t[^\n]*\n)+'
            normal_hooks = [m.group() for m in re.finditer(pattern, normal, re.M)]
            omitted_hooks = [m.group() for m in re.finditer(pattern, omitted, re.M)]
            self.assertEqual(len(normal_hooks), 4)
            self.assertEqual(len(omitted_hooks), 4)
            self.assertIn('key == "original_target"', normal_hooks[0])
            self.assertIn('key == "corpse_decay_record"', normal_hooks[1])
            self.assertIn('key == "original_target"', normal_hooks[2])
            self.assertIn('key == "corpse_decay_record"', normal_hooks[3])
            self.assertEqual(normal_hooks[:2], omitted_hooks[:2])
            self.assertNotIn('key == "original_target"', omitted_hooks[2])
            self.assertEqual(normal_hooks[3], omitted_hooks[3])
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaisesRegex(ValueError, 'Original-target control anchor changed'):
                self.execute_runner(Path(tmp), 'target-omit', replace_target=True)

    def test_actual_runner_refuses_head_base_or_checkout_drift(self):
        for options in ({'mismatch':True}, {'changed_helper':True}, {'bad_event':True},
                        {'head_edit':'\n// unrelated head drift\n'}, {'drop_custody':True}):
            with self.subTest(options=options), tempfile.TemporaryDirectory() as tmp:
                with self.assertRaises(ValueError): self.execute_runner(Path(tmp), **options)

    def test_actual_push_and_manual_runner_use_distinct_validated_base(self):
        for kind in ('push', 'workflow_dispatch'):
            with self.subTest(kind=kind), tempfile.TemporaryDirectory() as tmp:
                self.execute_runner(Path(tmp), event_kind=kind)
        with tempfile.TemporaryDirectory() as tmp:
            self.execute_runner(Path(tmp), event_kind='push', feature_base=True)
        for base in ('0'*40, 'a'*40):
            with self.subTest(base=base), tempfile.TemporaryDirectory() as tmp:
                with self.assertRaises(ValueError):
                    self.execute_runner(Path(tmp), event_kind='push', event_base=base)
        for base in ('', 'b'*7, '0'*40, 'a'*40):
            with self.subTest(manual_base=base), tempfile.TemporaryDirectory() as tmp:
                with self.assertRaises(ValueError):
                    self.execute_runner(Path(tmp), event_kind='workflow_dispatch', event_base=base)
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaises(ValueError):
                self.execute_runner(Path(tmp), event_kind='push', bad_event=True)

    def test_actual_runner_refuses_unavailable_extraction_ancestry_before_output(self):
        failures = (128, subprocess.TimeoutExpired('git', 15), OSError('git unavailable'))
        for failure in failures:
            with self.subTest(failure=failure), tempfile.TemporaryDirectory() as tmp:
                directory = Path(tmp)
                with self.assertRaisesRegex(ValueError, 'Cannot verify extraction ancestry'):
                    self.execute_runner(directory, ancestry_result=failure, drop_custody=True)
                self.assertFalse((directory / 'receipt-positive.json').exists())
                self.assertFalse((directory / 'receipt-positive.sources').exists())

    def test_projection_conflict_does_not_accept_overlapping_base_edit(self):
        changed = self.base_source.replace('if(key == "last_save_reference_failure") return TRUE',
                                           'if(key == "last_save_reference_failure") return FALSE', 1)
        with self.assertRaises(ValueError): replay_reviewed_merge(changed, self.base_source, self.merged)


class ManualPostIntegrationRunnerTests(unittest.TestCase):
    """Run source preparation against a real synthetic two-parent Git history."""
    def test_explicit_prior_master_not_feature_parent_carries_serializer_and_helper_evolution(self):
        from preparation import FIXTURE
        checkpoint = '9ac92766a575cc30211ba8c86e1fc3e0af2fabe2'
        paths = (PATH, 'code/processes/human_corpse_decay.dm',
                 'code/processes/abandoned_items.dm', 'code/modules/1713/active_training.dm')
        with tempfile.TemporaryDirectory(prefix='exclusion-manual-history-') as directory:
            root=Path(directory); repo=root/'repo'; repo.mkdir()
            def git(*args, data=None):
                result=subprocess.run(['git','-C',str(repo),'-c','user.name=Offline fixture',
                    '-c','user.email=offline@example.invalid',*args],input=data,capture_output=True,timeout=30,check=True)
                return result.stdout.decode().strip()
            git('init','-q')
            common = subprocess.check_output(['git','rev-parse','--git-common-dir'],cwd=ROOT,text=True).strip()
            objects=(ROOT/Path(common)/'objects').resolve()
            alternates=repo/'.git/objects/info/alternates';alternates.parent.mkdir(parents=True,exist_ok=True)
            alternates.write_bytes((objects.as_posix()+'\n').encode('utf-8'))
            git('read-tree',checkpoint)
            feature_source=subprocess.check_output(['git','show',MERGE_BASE+':'+PATH],cwd=ROOT,text=True)
            combined=current_lighting_policy(project_merged_source(feature_source)).encode('utf-8')
            def index(path,data):
                blob=git('hash-object','-w','--stdin',data=data)
                git('update-index','--add','--cacheinfo',f'100644,{blob},{path}')
            index(PATH,combined)
            for path in FIXTURE:
                index(path,(ROOT/path).read_text(encoding='utf-8').encode('utf-8'))
            foundation_tree=git('write-tree')
            foundation=git('commit-tree',foundation_tree,'-p',checkpoint,'-m','fixture combined foundation')
            feature=git('commit-tree',foundation_tree,'-p',foundation,'-m','fixture feature branch')
            changed={}
            for path,label in ((PATH,'serializer'),('code/processes/abandoned_items.dm','helper')):
                original=subprocess.check_output(['git','show',foundation+':'+path],cwd=repo)
                data=original+b'\n// prior master '+label.encode()+b' evolution\n'
                index(path,data);changed[path]=data
            tree=git('write-tree')
            prior=git('commit-tree',tree,'-p',foundation,'-m','fixture prior master')
            head=git('commit-tree',tree,'-p',prior,'-p',feature,'-m','fixture post integration merge')
            git('update-ref','refs/heads/fixture',head); git('symbolic-ref','HEAD','refs/heads/fixture')
            self.assertEqual(git('rev-list','--parents','-n','1','HEAD').split(),[head,prior,feature])
            for path in (*paths,*FIXTURE):
                destination=repo/path;destination.parent.mkdir(parents=True,exist_ok=True)
                destination.write_bytes(subprocess.check_output(['git','show',head+':'+path],cwd=repo))
            def execute(base, label):
                event=root/(label+'-event.json');event.write_text(json.dumps({'inputs':{'exclusion_comparison_base':base}}))
                output=root/(label+'-receipt.json')
                env=dict(os.environ,GITHUB_ACTIONS='true',GITHUB_EVENT_NAME='workflow_dispatch',
                         GITHUB_EVENT_PATH=str(event),GITHUB_SHA=head,CI_BASE=base,CI_HEAD=head)
                result=subprocess.run([sys.executable,'-B',str(repo/'tests/exclusion_dispatch/run.py'),
                    '--source-only','--output',str(output)],cwd=repo,env=env,capture_output=True,text=True,timeout=40)
                return result,output
            result,output=execute(prior,'prior-master')
            self.assertEqual(result.returncode,0,result.stderr)
            receipt=json.loads(output.read_text());self.assertEqual(receipt['event_identity']['base'],prior)
            self.assertEqual(receipt['event_identity']['head'],head);self.assertFalse(receipt['native_execution'])
            for base,label in (('', 'missing'),(feature,'feature-parent')):
                result,output=execute(base,label)
                self.assertNotEqual(result.returncode,0);self.assertFalse(output.exists())
                if not base: self.assertIn('exclusion_comparison_base',result.stderr)
            # Exercise the real CLI with a master base that predates the
            # extraction custody projection, including one-sided omissions.
            master='3d35f802e580ac4f4d012a4ffc448bd485b62b53'
            prhead=git('commit-tree',foundation_tree,'-p',master,'-p',foundation,'-m','fixture extraction integration')
            def checkout_fixture(revision):
                git('update-ref','refs/heads/fixture',revision)
                for path in (*paths,*FIXTURE):
                    (repo/path).write_bytes(subprocess.check_output(['git','show',revision+':'+path],cwd=repo))
            def execute_pr(revision,label):
                event=root/(label+'-event.json')
                event.write_text(json.dumps({'pull_request':{'base':{'sha':master},'head':{'sha':revision}}}))
                output=root/(label+'-receipt.json')
                env=dict(os.environ,GITHUB_ACTIONS='true',GITHUB_EVENT_NAME='pull_request',
                         GITHUB_EVENT_PATH=str(event),CI_BASE=master,CI_HEAD=revision)
                result=subprocess.run([sys.executable,'-B',str(repo/'tests/exclusion_dispatch/run.py'),
                    '--source-only','--output',str(output)],cwd=repo,env=env,capture_output=True,text=True,timeout=40)
                return result,output
            checkout_fixture(prhead)
            result,output=execute_pr(prhead,'extraction-pr')
            self.assertEqual(result.returncode,0,result.stderr)
            self.assertEqual(json.loads(output.read_text())['projection'],'master-base')
            for path,anchor,label in (
                (PATH,b'proc/authorize_restore_mutation(', 'missing-custody'),
                ('code/processes/abandoned_items.dm',b'/obj/item/persistence_runtime_var(key)', 'changed-helper')):
                git('read-tree',prhead)
                data=subprocess.check_output(['git','show',prhead+':'+path],cwd=repo)
                self.assertEqual(data.count(anchor),1)
                index(path,data.replace(anchor,anchor+b'_omitted',1))
                broken=git('commit-tree',git('write-tree'),'-p',prhead,'-m','fixture rejected mutation')
                checkout_fixture(broken)
                result,output=execute_pr(broken,label)
                self.assertNotEqual(result.returncode,0);self.assertFalse(output.exists())


class Current1688RunnerTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # The legacy Linux module imports resource; tests do not use its limits
        # or launch children on Windows.
        with patch.dict(sys.modules, {'resource': SimpleNamespace()}):
            spec = importlib.util.spec_from_file_location('exclusion_ci_1688', ROOT / 'scripts/exclusion_ci_1688.py')
            cls.runner = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(cls.runner)
        cls.original_workflow = subprocess.check_output(['git', 'show',
            '3d35f802e580ac4f4d012a4ffc448bd485b62b53:.github/workflows/test.yml'], cwd=ROOT, text=True)
        cls.original_runner = subprocess.check_output(['git', 'show',
            '3d35f802e580ac4f4d012a4ffc448bd485b62b53:tests/exclusion_dispatch/run-ci.py'], cwd=ROOT)

    def result(self, mode='parity'):
        return dict(cases=1000, failures=0 if mode=='parity' else 1,
                    target_failures=1 if mode=='target-omit' else 0,
                    byond_version=516, byond_build=1688, samples=[], details=[],
                    network=dict(closed_port=0, reopen_result=0, after_reopen_port=0))

    def test_historical_runner_unchanged_and_workflow_only_replaces_existing_guarded_lane(self):
        self.assertEqual((ROOT / 'tests/exclusion_dispatch/run-ci.py').read_bytes().replace(b'\r\n', b'\n'), self.original_runner)
        workflow=(ROOT / '.github/workflows/test.yml').read_text()
        after='python3 tests/exclusion_dispatch/run-ci-current.py --byond-bin "$PWD/BYOND/byond/bin" --byond-archive "$PWD/BYOND/pinned.zip" --output "$RUNNER_TEMP/exclusion-native"'
        self.assertEqual(workflow.count(after), 1)
        for name in ('Verify Linux exclusion dispatch parity and mutation controls',
                     'Retain Linux exclusion dispatch evidence'):
            marker='      - name: '+name+'\n'
            current=workflow.split(marker,1)[1].split('      - name:',1)[0]
            expected=self.original_workflow.split(marker,1)[1].split('      - name:',1)[0]
            current=current.replace('name: exclusion-native-1688-${{ github.event.pull_request.head.sha || github.sha }}',
                                                          'name: exclusion-native-${{ github.event.pull_request.head.sha || github.sha }}')
            self.assertEqual(current,expected)

    def test_result_keeps_legacy_oracles_and_demands_exact_observed_version_and_target_control(self):
        log='World opened on network port 12345 for address 127.0.0.1.\n'
        self.assertEqual(self.runner.MODES, ('parity', 'omit', 'parent', 'eager'))
        for mode in (*self.runner.MODES, 'target-omit'):
            self.runner.validate_result(mode,self.result(mode),log)
        for field,value in (('byond_version',515),('byond_version',516.0),('byond_build',1681),('byond_build',16880),('byond_build',1688.0),('target_failures',True),('target_failures',1)):
            result=self.result(); result[field]=value
            with self.subTest(field=field,value=value), self.assertRaises(RuntimeError): self.runner.validate_result('parity',result,log)
        result=self.result('target-omit');result['target_failures']=0
        with self.assertRaises(RuntimeError): self.runner.validate_result('target-omit',result,log)
        with self.assertRaises(RuntimeError): self.runner.validate_result('parity',self.result(),'runtime error: bad ref')

    def test_actual_main_threads_archive_and_checks_every_child_without_launch(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp); output=root/'packet'; binary=root/'bin'; archive=root/'pinned.zip'
            checks=[]; calls=[]
            runtime=SimpleNamespace(bin_dir=binary, identity={'version':'516.1688'},
                before_launch=lambda role,where: checks.append((role,where)),
                validate_compile=Mock())
            def run(command, work, role, deadline):
                calls.append((role,command))
                if role.endswith('-prepare'):
                    mode=role.removesuffix('-prepare'); packet=output/(mode+'.json')
                    self.assertIn('--source-version',command); self.assertIn('516.1688',command)
                    packet.write_text(json.dumps({'required_version':'516.1688','native_execution':False}))
                    packet.with_suffix('.sources').mkdir()
                    return ''
                mode=Path(work).name.removesuffix('.sources')
                self.assertEqual(checks[-1][0],mode+'-'+role)
                if role=='compile': return 'DM compiler version 516.1688\nprobe.dmb - 0 errors, 0 warnings\n'
                (Path(work)/'runtime.log').write_text('World opened on network port 1 for address 127.0.0.1.\n')
                (Path(work)/'result.json').write_text(json.dumps(self.result(mode)))
                return ''
            with patch.object(sys,'argv',['runner','--byond-bin',str(binary),'--byond-archive',str(archive),'--output',str(output)]), \
                 patch.object(self.runner.sys,'platform','linux'), patch.object(self.runner.current,'select',return_value=runtime) as select, \
                 patch.object(self.runner.legacy,'run',side_effect=run), patch.object(subprocess,'Popen',side_effect=AssertionError('native forbidden')), \
                 patch('builtins.print'):
                self.runner.main()
            select.assert_called_once_with(binary,archive)
            self.assertEqual([role for role,_ in checks],[mode+'-'+role for mode in self.runner.MODES for role in ('compile','daemon')])
            self.assertEqual(runtime.validate_compile.call_count,len(self.runner.MODES))
            self.assertEqual(json.loads((output/'native-ci-1688.json').read_text())['status'],'passed')
            self.assertEqual(len(calls),len(self.runner.MODES)*3)

    def test_current_compiler_contract_rejects_wrong_duplicate_and_dirty_evidence(self):
        runtime=object.__new__(self.runner.current.CurrentRuntime)
        runtime.identity={'version':'516.1688'}
        runtime.compiler=self.runner.current.load('exclusion_compile_contract',ROOT/'tests/new_z_budget/z_budget_evidence.py')
        clean='DM compiler version 516.1688\nprobe.dmb - 0 errors, 0 warnings\n'
        runtime.validate_compile(0,clean,'probe.dmb')
        for bad in (clean.replace('1688','1681'), clean.replace('1688','16880'), clean+clean,
                    clean.replace('probe.dmb','other.dmb'), clean+'runtime error: bad ref\n'):
            with self.subTest(bad=bad), self.assertRaises(RuntimeError): runtime.validate_compile(0,bad,'probe.dmb')
        with self.assertRaises(RuntimeError): runtime.validate_compile(1,clean,'probe.dmb')

    def test_identity_failure_precedes_first_compiler_and_leaves_native_unexecuted(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp); output=root/'packet'; binary=root/'bin'; archive=root/'pinned.zip'
            runtime=SimpleNamespace(bin_dir=binary, identity={'version':'516.1688'},
                before_launch=Mock(side_effect=ValueError('archive member changed')))
            def prepare(command, work, role, deadline):
                self.assertEqual(role, 'parity-prepare')
                packet=output/'parity.json'
                packet.write_text(json.dumps({'required_version':'516.1688','native_execution':False}))
                packet.with_suffix('.sources').mkdir()
                return ''
            with patch.object(sys,'argv',['runner','--byond-bin',str(binary),'--byond-archive',str(archive),'--output',str(output)]), \
                 patch.object(self.runner.sys,'platform','linux'), patch.object(self.runner.current,'select',return_value=runtime), \
                 patch.object(self.runner.legacy,'run',side_effect=prepare) as run, \
                 patch.object(subprocess,'Popen',side_effect=AssertionError('native forbidden')), patch('builtins.print'):
                with self.assertRaisesRegex(ValueError,'archive member changed'): self.runner.main()
            self.assertEqual(run.call_count, 1)
            summary=json.loads((output/'native-ci-1688.json').read_text())
            self.assertFalse(summary['native_execution'])
            self.assertEqual(summary['status'],'incomplete')




if __name__ == '__main__':
    unittest.main()
