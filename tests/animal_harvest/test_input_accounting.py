"""Real pinned inputs and injected process boundaries; never launch BYOND."""
import importlib.util
import io
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('harvest_input_runner', ROOT/'tests/animal_harvest/run.py')
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


class HarvestInputs(unittest.TestCase):
    def test_fixture_defers_global_bootstrap_without_changing_its_body(self):
        source = (ROOT/'code/world.dm').read_text(encoding='utf-8')
        prepared = runner.prepare_world_source(source)
        marker = '/datum/global_init/New()\n'
        body = source.split(marker, 1)[1].split('\n/', 1)[0]
        deferred = prepared.split('/datum/global_init/proc/initialize_harvest_globals()\n', 1)[1].split('\n/', 1)[0]
        self.assertEqual(deferred, body)
        self.assertIn('makeDatumRefLists()', deferred)
        self.assertIn('load_configuration()', deferred)
        self.assertIn('initialize_chemical_reagents()', deferred)
        self.assertIn('initialize_chemical_reactions()', deferred)
        self.assertIn('qdel(src)', deferred)
        self.assertNotIn(marker, prepared)
        self.assertNotIn('/world/New()\n', prepared)
        self.assertEqual(prepared.count('/world/proc/unused_harvest_startup()\n'), 1)
        self.assertEqual(prepared.count('var/global/datum/global_init/init = new ()'), 1)

    def test_startup_isolation_drift_is_refused_without_a_native_launch(self):
        source = (ROOT/'code/world.dm').read_text(encoding='utf-8')
        mutations = (
            source.replace('/datum/global_init/New()\n', '', 1),
            source + '\n/datum/global_init/New()\n',
            source.replace('/world/New()\n', '', 1),
            source + '\n/world/New()\n',
            source.replace('\n\t..()', '\n\tparent_changed()'),
        )
        for mutant in mutations:
            with self.subTest(mutant=mutations.index(mutant)), \
                    patch.object(runner, 'run_retained', side_effect=AssertionError('No native launch')) as launch:
                with self.assertRaisesRegex(RuntimeError, 'Harvest .* marker'):
                    runner.prepare_world_source(mutant)
                launch.assert_not_called()

    def test_fixture_initializes_after_globals_before_scenarios_and_retains_error_guard(self):
        fixture = (ROOT/'tests/animal_harvest/probe.dm').read_text().split('/world/New()\n', 1)[1]
        self.assertEqual(fixture.count('init.initialize_harvest_globals()'), 1)
        self.assertLess(fixture.index('sleep(1)'), fixture.index('init.initialize_harvest_globals()'))
        self.assertLess(fixture.index('init.initialize_harvest_globals()'), fixture.index('new /obj/map_metadata/harvest_fixture'))
        self.assertLess(fixture.index('Production body catalog did not initialize'), fixture.index('for (var/action in list('))
        self.assertNotIn('male_body_builds =', fixture)
        source = (ROOT/'tests/animal_harvest/run.py').read_text()
        self.assertIn("'runtime error:' in log.lower()", source)
        self.assertIn('(errors.exists() and errors.stat().st_size)', source)
        self.assertIn("phase='harvest-runtime', timeout=60", source)
        self.assertIn("phase='harvest-compile', timeout=120", source)

    def stage(self, root):
        logs = root/'evidence'
        logs.mkdir()
        required = runner.stage_runtime_inputs(logs)
        return logs, required

    def assert_zero_launch_rejection(self, logs, required, message):
        with patch.object(runner.evidence.subprocess, 'Popen',
                          side_effect=AssertionError('No native process allowed')) as launch:
            with self.assertRaisesRegex(RuntimeError, message):
                runner.evidence.run_phase(['never-start-native'], cwd=logs/'runtime',
                    output=logs, phase='offline-preflight', timeout=60, required_inputs=required)
            launch.assert_not_called()
        receipt = json.loads((logs/'offline-preflight-phase.json').read_text())
        self.assertEqual(receipt['returncode_status'], 'not_started')
        self.assertIsNone(receipt['returncode'])

    def test_exact_eager_reads_and_bounds_without_unused_names(self):
        plan = json.loads((ROOT/'tests/flax_processing/required-inputs.json').read_text())
        names = [row for row in plan['inputs'] if row['path'].startswith('config/names/')]
        self.assertEqual((plan['global_name_declarations'], len(names)), (157, 146))
        self.assertEqual(sum(row['bytes'] for row in names), 134930)
        maximum = sum(row['bytes']+(ROOT/row['path']).read_bytes().replace(b'\r\n', b'\n').count(b'\n') for row in names)+len(runner.OFFLINE_CONFIG)
        self.assertEqual(maximum, runner.RUNTIME_INPUT_BYTE_LIMIT)
        self.assertEqual(maximum, 153265)
        with tempfile.TemporaryDirectory(prefix='harvest-inputs-') as directory:
            logs, required = self.stage(Path(directory))
            self.assertEqual(len(required), 147)
            self.assertEqual(set(required), {'runtime/'+row['path'] for row in names}|{'runtime/config/config.txt'})
            self.assertEqual((logs/'runtime/config/config.txt').read_bytes(), runner.OFFLINE_CONFIG)
            self.assertFalse((logs/'runtime/config/crafting').exists())
            unused = {'first.txt','first_female_afrikaans.txt','last_cherokee.txt','last_inuit.txt'}
            self.assertTrue(unused.isdisjoint(p.name for p in (logs/'runtime/config/names').iterdir()))
            summary = runner.validate_runtime_inputs(logs, required)
            self.assertEqual(summary['derived_total_files'], 275)
            self.assertEqual(summary['non_required_file_limit'], 128)
            self.assertEqual(summary['total_byte_limit'], 512*1024*1024)
            manifest = {'required_inputs': required}
            runner.evidence.retain_manifest(logs, [], manifest, finalized=True)
            self.assertTrue(manifest['inventory_complete'])
            self.assertGreater(len(manifest['retained_outputs']), 128)

    def test_missing_changed_and_unlisted_inputs_refuse_before_popen(self):
        for defect, message in (('missing','Required staged input missing'),
                                ('changed','Required input changed before process launch'),
                                ('unlisted','Unlisted staged input')):
            with self.subTest(defect=defect), tempfile.TemporaryDirectory(prefix='harvest-input-deny-') as directory:
                logs, required = self.stage(Path(directory))
                victim = logs/next(iter(required))
                if defect == 'missing':
                    victim.unlink()
                elif defect == 'changed':
                    data = victim.read_bytes()
                    victim.write_bytes(bytes([data[0]^1])+data[1:])
                else:
                    (logs/'runtime/config/names/unlisted.txt').write_bytes(b'not an admitted input')
                self.assert_zero_launch_rejection(logs, required, message)

    def test_source_plan_changes_are_rejected_without_a_process(self):
        original = json.loads((ROOT/'tests/flax_processing/required-inputs.json').read_text())
        for defect in ('names_source', 'duplicate', 'source_bytes'):
            with self.subTest(defect=defect), tempfile.TemporaryDirectory(prefix='harvest-source-deny-') as directory:
                root = Path(directory)
                (root/'code').mkdir()
                (root/'code/names.dm').write_bytes((ROOT/'code/names.dm').read_bytes())
                dest = root/'tests/flax_processing/required-inputs.json'
                dest.parent.mkdir(parents=True)
                plan = json.loads(json.dumps(original))
                if defect == 'names_source':
                    (root/'code/names.dm').write_bytes(b'changed eager source')
                elif defect == 'duplicate':
                    plan['inputs'].insert(0, plan['inputs'][0])
                else:
                    first = root/plan['inputs'][0]['path']
                    first.parent.mkdir(parents=True)
                    first.write_bytes(b'changed pinned input')
                dest.write_text(json.dumps(plan))
                with patch.object(runner, 'ROOT', root), patch.object(runner.evidence.subprocess, 'Popen') as launch:
                    with self.assertRaisesRegex(RuntimeError, 'Harvest'):
                        runner.required_name_plan()
                    launch.assert_not_called()

    def test_recipe_must_remain_a_compiled_resource_before_staging(self):
        with tempfile.TemporaryDirectory(prefix='harvest-resource-deny-') as directory:
            root = Path(directory)
            probe = root/'tests/animal_harvest/hide_recipe_probe.dm'
            probe.parent.mkdir(parents=True)
            probe.write_text('var/global/tanning_recipe_config = "config/crafting/material_recipes_global.txt"\n')
            with patch.object(runner,'ROOT',root), patch.object(runner.evidence.subprocess,'Popen') as launch:
                with self.assertRaisesRegex(RuntimeError,'recipe resource changed'):
                    runner.stage_runtime_inputs(root)
                launch.assert_not_called()
            self.assertFalse((root/'runtime').exists())

    def test_generated_file_reserve_and_combined_bytes_are_not_relaxed(self):
        with tempfile.TemporaryDirectory(prefix='harvest-output-budget-') as directory:
            logs, required = self.stage(Path(directory))
            for index in range(128):
                (logs/('output-'+str(index))).write_bytes(b'')
            self.assertEqual(runner.validate_runtime_inputs(logs, required)['non_required_present'], 128)
            self.assert_zero_launch_rejection(logs, required, 'Task-owned output budget exceeded')
        with tempfile.TemporaryDirectory(prefix='harvest-byte-budget-') as directory:
            logs, required = self.stage(Path(directory))
            huge = logs/'synthetic-large.bin'
            huge.write_bytes(b'x')
            original = Path.stat
            def size(path, *args, **kwargs):
                value = original(path, *args, **kwargs)
                if path == huge:
                    fields = list(value)
                    fields[6] = 512*1024*1024-sum(row['bytes'] for row in required.values())+1
                    return os.stat_result(fields)
                return value
            with patch.object(Path, 'stat', size):
                self.assert_zero_launch_rejection(logs, required, 'Task-owned output budget exceeded')

    def test_linked_input_is_refused_before_popen(self):
        with tempfile.TemporaryDirectory(prefix='harvest-link-deny-') as directory:
            logs, required = self.stage(Path(directory))
            victim = logs/next(iter(required))
            original = Path.is_symlink
            with patch.object(Path, 'is_symlink', lambda path: path == victim or original(path)):
                self.assert_zero_launch_rejection(logs, required, 'Required staged input changed')

    def test_same_size_input_mutation_after_injected_exit_cannot_pass(self):
        with tempfile.TemporaryDirectory(prefix='harvest-post-deny-') as directory:
            logs, required = self.stage(Path(directory))
            victim = logs/next(iter(required))
            class Child:
                pid = 123  # Offline fake, never a real process receipt.
                stdout = io.BytesIO(b'')
                stderr = io.BytesIO(b'')
                returncode = 0
                def poll(self):
                    return 0
            def launch(*args, **kwargs):
                data = victim.read_bytes()
                victim.write_bytes(bytes([data[0]^1])+data[1:])
                return Child()
            with patch.object(runner.evidence.subprocess, 'Popen', side_effect=launch):
                with self.assertRaisesRegex(RuntimeError, 'Required input changed after process launch'):
                    runner.evidence.run_phase(['injected-only'],cwd=logs/'runtime',output=logs,
                        phase='offline-postflight',timeout=60,required_inputs=required)
            receipt = json.loads((logs/'offline-postflight-phase.json').read_text())
            self.assertEqual(receipt['required_inputs_final_validation'], 'failed')
            self.assertEqual(receipt['status'], 'failed')

    def test_partial_staging_retains_the_plan_and_complete_inventory(self):
        with tempfile.TemporaryDirectory(prefix='harvest-partial-staging-') as directory:
            logs = Path(directory)/'evidence'
            logs.mkdir()
            manifest = {}
            def fail(output, rows):
                for row in rows[:129]:
                    path = output/'runtime'/row['path']
                    path.parent.mkdir(parents=True, exist_ok=True)
                    path.write_bytes(b'partial offline input')
                raise RuntimeError('Injected partial copy')
            with patch.object(runner.evidence,'stage_required_inputs',side_effect=fail), \
                    patch.object(runner.evidence.subprocess,'Popen') as launch:
                with self.assertRaisesRegex(RuntimeError,'Injected partial copy'):
                    runner.stage_runtime_inputs(logs,manifest)
                launch.assert_not_called()
            self.assertEqual(len(manifest['required_inputs']),147)
            runner.evidence.retain_manifest(logs,[],manifest,finalized=True)
            self.assertTrue(manifest['inventory_complete'])
            self.assertGreater(len(manifest['retained_outputs']),128)

    def test_input_exemption_cannot_expand_and_legacy_cap_failure_is_preserved(self):
        with tempfile.TemporaryDirectory(prefix='harvest-input-allowance-') as directory:
            logs, required = self.stage(Path(directory))
            with self.assertRaisesRegex(RuntimeError, 'Task-owned output budget exceeded'):
                runner.evidence.check_output_budget(logs)  # The old all-file cap still rejects.
            extra = dict(required, **{'runtime/config/extra.txt': {'bytes': 1, 'sha256': '0'*64}})
            with self.assertRaisesRegex(RuntimeError, 'allowance exceeded'):
                runner.validate_runtime_inputs(logs, extra)
            enlarged = {key:dict(value) for key,value in required.items()}
            enlarged[next(iter(enlarged))]['bytes'] += runner.RUNTIME_INPUT_BYTE_LIMIT
            with self.assertRaisesRegex(RuntimeError, 'allowance exceeded'):
                runner.validate_runtime_inputs(logs, enlarged)

    def test_linux_adapter_forwards_same_input_manifest_and_timeouts(self):
        required = {'offline-marker': {'bytes': 1, 'sha256': '0'*64}}
        with patch.object(runner.sys, 'platform', 'linux'), \
             patch.object(runner.evidence, 'run_phase', return_value='injected only') as retained, \
             patch.object(runner, 'run_native', side_effect=AssertionError('No alternate runner')):
            for phase, seconds in (('harvest-compile',120), ('harvest-runtime',60)):
                self.assertEqual(runner.run_retained(None,['never-native'],logs=Path('logs'),
                    cwd=Path('cwd'),phase=phase,timeout=seconds,required_inputs=required), 'injected only')
                self.assertIs(retained.call_args.kwargs['required_inputs'], required)
                self.assertEqual(retained.call_args.kwargs['timeout'], seconds)


if __name__ == '__main__':
    unittest.main()
