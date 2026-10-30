"""Offline source contracts for opt-in copied-packet timing, not native proof."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
SPEC = importlib.util.spec_from_file_location('datum_profile_tested', HERE / 'datum_profile.py')
profile = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(profile)


class DatumProfileTests(unittest.TestCase):
    def test_existing_reference_calls_are_wrapped_once_without_new_checks_or_yields(self):
        for name, original, replacement in (
            ('code/modules/persistence/saving.dm', '"\\ref[A]"', 'profile_native_identity(A)'),
            ('code/modules/persistence/functions.dm', 'return "\\ref[A]"', 'return profile_native_identity(A)'),
        ):
            source = (ROOT / name).read_text()
            instrumented = profile.instrument_datum_references(name, source)
            self.assertEqual(instrumented.count(replacement), source.count(original))
            self.assertNotIn(original, instrumented)
            for unchanged in ('sleep(', 'world.log', 'check()'):
                self.assertEqual(instrumented.count(unchanged), source.count(unchanged))
            self.assertEqual((ROOT / name).read_text(), source)
        self.assertIn('native_ref_type=[profile_native_ref_type]', profile.instrument_datum_references('code/modules/persistence/saving.dm', (ROOT / 'code/modules/persistence/saving.dm').read_text()))

    def test_saver_reference_count_drift_is_rejected(self):
        name = 'code/modules/persistence/saving.dm'
        source = (ROOT / name).read_text()
        self.assertEqual(source.count('"\\ref[A]"'), profile.EXPECTED_SAVER_REF_SITES)
        with self.assertRaisesRegex(ValueError, 'Native datum'):
            profile.instrument_datum_references(name, source.replace('"\\ref[A]"', '"changed"', 1))

    def test_changed_frame_anchor_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'Identity helper'):
            profile.instrument_datum_references('code/modules/persistence/functions.dm', 'no native frame reference')

    def test_shared_baseline_restores_all_old_identity_cost_paths(self):
        saving_name = 'code/modules/persistence/saving.dm'
        functions_name = 'code/modules/persistence/functions.dm'
        saver = profile.restore_old_identity_keys(saving_name, (ROOT / saving_name).read_text())
        functions = profile.restore_old_identity_keys(functions_name, (ROOT / functions_name).read_text())
        self.assertEqual(saver.count('saving_lists["\\ref[L]"]'), 2)
        self.assertNotIn('if(!moving_save_chunk && istype(A, /atom/movable)', saver)
        self.assertIn('if(durable_export) durable_export.bind_entry', saver)
        self.assertNotIn('if(istype(A, /matrix)) return A', functions)
        self.assertIn('save_entry_identity(frame.source)', functions)
        for name, text in ((saving_name, saver), (functions_name, functions)):
            profile.instrument_datum_references(name, text)
        with self.assertRaises(ValueError):
            profile.restore_old_identity_keys(saving_name, saver)
        with self.assertRaises(ValueError):
            profile.restore_matrix_reference_identity(functions)

    def test_correctness_and_benchmark_use_identical_baseline_transform(self):
        spec = importlib.util.spec_from_file_location('matrix_correctness', HERE / 'correctness.py')
        correctness = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(correctness)
        with tempfile.TemporaryDirectory() as directory:
            packet = Path(directory)
            for name in ('code/modules/persistence/saving.dm', 'code/modules/persistence/functions.dm'):
                target = packet / name
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes((ROOT / name).read_bytes())
            correctness.mutate(packet, 'old-keys')
            for name in ('code/modules/persistence/saving.dm', 'code/modules/persistence/functions.dm'):
                self.assertEqual((packet / name).read_text(), profile.restore_old_identity_keys(name, (ROOT / name).read_text()))

    def test_matrix_omission_only_removes_direct_return_branch(self):
        name = 'code/modules/persistence/functions.dm'
        source = (ROOT / name).read_text()
        mutated = profile.restore_matrix_reference_identity(source)
        self.assertEqual(mutated, source.replace('\tif(istype(A, /matrix)) return A\n', '', 1))
        self.assertIn('save_entry_identity(frame.source)', mutated)
        spec = importlib.util.spec_from_file_location('matrix_omission_correctness', HERE / 'correctness.py')
        correctness = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(correctness)
        with tempfile.TemporaryDirectory() as directory:
            packet = Path(directory)
            path = packet / name
            path.parent.mkdir(parents=True)
            path.write_text(source)
            correctness.mutate(packet, 'matrix-identity')
            self.assertEqual(path.read_text(), mutated)
        runner_source = (HERE / 'correctness.py').read_text()
        self.assertIn("(('walking',) if control == 'matrix-identity'", runner_source)
        self.assertIn('MATRIX_FRAME: matrix identity still uses native reference strings', runner_source)

    def test_final_workflow_has_full_matrix_without_opt_in_timing(self):
        workflow = (ROOT / '.github/workflows/moving-save-chunks.yml').read_text()
        command = next(line for line in workflow.splitlines() if 'benchmark.py --run-native' in line)
        self.assertNotIn('--diagnostic-subset', command)
        self.assertNotIn('--profile-datums', command)
        self.assertIn('--job-seconds 900', command)

if __name__ == '__main__': unittest.main()
