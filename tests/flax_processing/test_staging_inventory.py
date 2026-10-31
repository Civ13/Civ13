"""Real pinned input staging; compiled files/processes remain offline fakes."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('flax_staging_runner', Path(__file__).with_name('run.py'))
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


class RequiredInputInventory(unittest.TestCase):
    def fixture(self, root):
        output = root/'evidence'
        output.mkdir()
        plan = runner.required_input_plan()
        required = runner.stage_required_inputs(output, plan)
        sources = root/'owned-sources'
        sources.mkdir()
        prefix = '.flax_probe_' + 'b'*32
        generated = [sources/(prefix+suffix) for suffix in runner.GENERATED_SUFFIXES[:6]]
        aliases = []
        for index, original in enumerate(generated):
            data = b'SYNTHETIC OFFLINE COMPILED/SOURCE DATA ' + str(index).encode()
            original.write_bytes(data)
            binary = original.suffix in ('.dmb', '.rsc')
            alias = Path('generated-artifacts' if binary else 'generated-inputs')/('generated-'+str(index)+original.suffix)
            for path in (output/alias, output/('runtime' if binary else 'generated-inputs')/original.name):
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(data)
            aliases.append({'alias_path':alias.as_posix()})
        for relative in runner.RESERVED_DIAGNOSTICS:
            path = output/relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b'{}')
        return output, sources, generated, {'required_inputs':required, 'upload_aliases':aliases}

    def test_real_eager_reads_and_complete_staged_graph_fit_separate_budgets(self):
        plan = runner.required_input_plan()
        self.assertEqual(len(plan), 147)
        self.assertEqual(sum(row['path'].startswith('config/names/') for row in plan), 146)
        self.assertIn('config/names/last_afrikaans.txt', {row['path'] for row in plan})  # file2list ( ... ) spelling.
        unused = {'first.txt','first_female_afrikaans.txt','last_cherokee.txt','last_inuit.txt'}
        with tempfile.TemporaryDirectory(prefix='flax-real-staging-') as directory:
            output, sources, generated, manifest = self.fixture(Path(directory))
            actual_names = {p.name for p in (output/'runtime/config/names').iterdir()}
            self.assertFalse(actual_names & unused)
            for phase in ('compile','daemon'):
                result = runner.validate_staged_inventory(output, generated, manifest, phase)
                self.assertEqual(result['counts']['required_inputs'], 147)
                self.assertEqual(result['counts']['generated_sources'], 4)
                self.assertEqual(result['counts']['runtime_binaries'], 2)
                self.assertEqual(result['counts']['artifact_aliases'], 6)
                self.assertEqual(result['non_required_file_limit'], 128)
                self.assertEqual(result['derived_total_file_limit'], 275)
                self.assertLessEqual(result['non_required_planned'], 128)
            with patch.object(runner,'ROOT',sources):
                runner.retain_manifest(output,generated,manifest,finalized=True)
            saved = json.loads((output/'evidence-manifest.json').read_text())
            self.assertTrue(saved['inventory_complete'])
            self.assertFalse(saved.get('inventory_truncated',False))
            self.assertEqual(len(saved['retained_outputs']),len([p for p in output.rglob('*') if p.is_file()])-1)

    def test_bad_full_staging_blocks_process_creation_and_preserves_evidence(self):
        for defect in ('missing','hash','unlisted','output_count','bytes'):
            with self.subTest(defect=defect), tempfile.TemporaryDirectory(prefix='flax-staging-negative-') as directory:
                output, sources, generated, manifest = self.fixture(Path(directory))
                relative = next(iter(manifest['required_inputs']))
                path = output/relative
                if defect == 'missing': path.rename(output/'retained-missing-input.txt')
                if defect == 'hash':
                    data = path.read_bytes();path.write_bytes(bytes([data[0]^1])+data[1:])
                if defect == 'unlisted': (output/'runtime/config/names/first.txt').write_bytes(b'unlisted')
                if defect == 'output_count':
                    for index in range(129): (output/('extra-'+str(index))).write_bytes(b'')
                byte_limit = sum(row['bytes'] for row in manifest['required_inputs'].values())-1 if defect=='bytes' else runner.OUTPUT_LIMIT
                with patch.object(runner,'OUTPUT_LIMIT',byte_limit), \
                        patch.object(runner.subprocess,'Popen',side_effect=AssertionError('No process may launch')) as launch:
                    with self.assertRaises(RuntimeError):
                        runner.run_phase(['never-launched'],cwd=output,output=output,phase='daemon',timeout=1,
                                         required_inputs=manifest['required_inputs'])
                    launch.assert_not_called()
                receipt = json.loads((output/'daemon-phase.json').read_text())
                self.assertEqual(receipt['returncode_status'],'not_started')
                self.assertIsNone(receipt['returncode'])
                self.assertEqual(receipt['status'],'failed')
                self.assertTrue((output/'generated-artifacts/generated-4.dmb').exists())

    def test_128_noninput_guard_is_not_raised_or_removed(self):
        with tempfile.TemporaryDirectory(prefix='flax-count-reserve-') as directory:
            output=Path(directory)
            required=runner.stage_required_inputs(output,runner.required_input_plan())
            for index in range(128): (output/('output-'+str(index))).write_bytes(b'')
            count,_=runner.check_output_budget(output,required)
            self.assertEqual(count,128)
            (output/'one-too-many').write_bytes(b'')
            with self.assertRaisesRegex(RuntimeError,'output budget exceeded'):
                runner.check_output_budget(output,required)

    def test_manifest_drift_cannot_exempt_unreviewed_inputs(self):
        original = json.loads((runner.ROOT/runner.REQUIRED_INPUT_MANIFEST).read_text())
        for defect in ('missing','extra','fingerprint','oversized','names_source'):
            with self.subTest(defect=defect):
                manifest = json.loads(json.dumps(original))
                if defect == 'missing': manifest['inputs'].pop()
                if defect == 'extra': manifest['inputs'].append(dict(manifest['inputs'][0]))
                if defect == 'fingerprint': manifest['inputs'][0]['sha256'] = '0'*64
                if defect == 'oversized': manifest['inputs'][0]['bytes'] = runner.INPUT_LIMIT+1
                if defect == 'names_source': manifest['names_source_sha256'] = '0'*64
                with patch.object(runner,'bounded_text',return_value=json.dumps(manifest)):
                    with self.assertRaises(RuntimeError): runner.required_input_plan()


if __name__ == '__main__': unittest.main()
