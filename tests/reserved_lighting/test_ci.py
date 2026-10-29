"""Offline checks of CI admission; native state parity requires native execution."""
import importlib.util
from contextlib import redirect_stdout
import io
from pathlib import Path
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).parent))
spec = importlib.util.spec_from_file_location('reserved_ci', Path(__file__).with_name('run-ci.py'))
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


class CIAdmission(unittest.TestCase):
    def staged_pipeline(self, parent, mutate=False):
        commands = []
        def execute(command, work, log, timeout, flags):
            commands.append(log)
            self.assertEqual(timeout, 180)
            self.assertEqual(len(list((work/'config/names').glob('*.txt'))), 146)
            self.assertFalse((work/'config/config.txt').exists())
            self.assertFalse((work/'map_saves').exists())
            self.assertIn('var/global/datum/global_init/init = null', (work/'world.dm').read_text(encoding='utf-8'))
            if log == 'compile.log':
                if mutate:
                    (work/'config/names/first_male.txt').write_bytes(b'changed during compile')
                return SimpleNamespace(returncode=0, stdout='DM compiler version 516.1688\nprobe.dmb - 0 errors, 0 warnings (1.0s)\n', stderr='')
            (work/'runtime.log').write_text('Welcome BYOND! (5.0 Public Version 516.1688)\n')
            (work/'port-closed.txt').write_text('closed')
            (work/'result.txt').write_text('PASS')
            return SimpleNamespace(returncode=0, stdout='', stderr='')
        def compare(left, right):
            if right.parent.name == 'virtual-master':
                raise ValueError('Native snapshot mismatch: injected comparator')
            if right.parent.name == 'lumcount-guard':
                raise ValueError('Native lumcount mismatch: injected comparator')
            return {'injected_offline_only': True}
        with patch.object(sys, 'argv', ['run-ci.py', '--byond-bin', str(parent/'unexecuted-bin'),
                                      '--byond-archive', str(parent/'unexecuted.zip'), '--output', str(parent/'out')]), \
             patch.object(runner, 'startup_module', return_value=SimpleNamespace(run_logged=execute)), \
             patch.object(runner, 'verify_runtime', return_value={'version':'516.1688'}), \
             patch.object(runner, 'EXPECTED', {'baseline':'PASS', 'candidate':'PASS'}), \
             patch.object(runner, 'compare', side_effect=compare), redirect_stdout(io.StringIO()):
            if mutate:
                with self.assertRaisesRegex(ValueError, 'Runtime input changed'):
                    runner.main()
            else:
                runner.main()
        return commands

    def test_actual_pipeline_stages_public_inputs_before_injected_compiler_and_daemon(self):
        with tempfile.TemporaryDirectory() as temporary:
            self.assertEqual(self.staged_pipeline(Path(temporary)),
                             ['compile.log','daemon.log','compile.log','daemon.log'])

    def test_compile_input_mutation_prevents_daemon(self):
        with tempfile.TemporaryDirectory() as temporary:
            self.assertEqual(self.staged_pipeline(Path(temporary), mutate=True), ['compile.log'])

    def test_missing_public_file_diagnostic_rejects_an_otherwise_passing_run(self):
        with tempfile.TemporaryDirectory() as temporary:
            work = Path(temporary)
            (work/'runtime.log').write_text('Welcome BYOND! (5.0 Public Version 516.1688)\n## ERROR: File not found (config/names/first_male.txt)\n')
            (work/'port-closed.txt').write_text('closed')
            (work/'result.txt').write_text('PASS')
            with self.assertRaisesRegex(RuntimeError, 'Unexpected native diagnostic'):
                runner.validate_runtime(SimpleNamespace(returncode=0,stdout='',stderr=''), work, 'baseline')

    def test_generated_dme_resolves_checkout_resources(self):
        with tempfile.TemporaryDirectory() as temp:
            work = Path(temp)/'fixture'
            work.mkdir()
            runner.bind_resources(runner.ROOT, work)
            for relative in runner.RESOURCE_DIRECTORIES:
                self.assertEqual((work/relative).resolve(), (runner.ROOT/relative).resolve())
            self.assertTrue((work/'icons/chattags.dmi').is_file())
            self.assertTrue((work/'code/js/view_variables.js').is_file())
            self.assertFalse((work/'config').exists())
            self.assertFalse((work/'map_saves').exists())

    def test_each_control_requires_its_exact_outcome(self):
        with tempfile.TemporaryDirectory() as temp:
            work = Path(temp)
            (work/'runtime.log').write_text('Welcome BYOND! (5.0 Public Version 516.1688)\n')
            (work/'port-closed.txt').write_text('closed\n')
            result = SimpleNamespace(returncode=0, stdout='', stderr='')
            for name, expected in runner.EXPECTED.items():
                (work/'result.txt').write_text(expected + '\n')
                runner.validate_runtime(result, work, name)
                (work/'result.txt').write_text('FAIL: unrelated failure')
                with self.assertRaises(RuntimeError):
                    runner.validate_runtime(result, work, name)

    def test_diagnostics_exit_and_port_refuse_even_with_pass(self):
        with tempfile.TemporaryDirectory() as temp:
            work = Path(temp)
            (work/'result.txt').write_text('PASS')
            for exit_code, log, marker in ((1, '', 'closed'), (0, 'runtime error', 'closed'), (0, '', 'open')):
                (work/'runtime.log').write_text(log)
                (work/'port-closed.txt').write_text(marker)
                with self.assertRaises(RuntimeError):
                    runner.validate_runtime(SimpleNamespace(returncode=exit_code, stdout='', stderr=''), work, 'candidate')

    def test_merge_preserves_mining_and_reserved_runtime_ownership(self):
        source = (runner.ROOT/'code/modules/persistence/functions.dm').read_text()
        self.assertIn('key == "pickaxe_mining_owner" || key == "mining_in_progress"', source)
        self.assertIn('switch(key)\n\t\tif ("lighting_reserved", "affecting_lights"', source)
        self.assertIn('return key == "lighting_reserved_clearance_enabled" || key == "persistence_zone_id" || ..()', source)
        corner = (runner.ROOT/'code/modules/lighting/lighting_corner.dm').read_text()
        self.assertIn('T.lighting_overlay || T.omit_reserved_lighting_overlay()', corner)


if __name__ == '__main__':
    unittest.main()
