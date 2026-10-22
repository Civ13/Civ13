"""Offline boundary check: compile-only never launches the runtime."""
import importlib.util
from pathlib import Path
import subprocess
import sys
import unittest
from unittest.mock import patch


SPEC = importlib.util.spec_from_file_location('extraction_runner', Path(__file__).with_name('run.py'))
RUNNER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(RUNNER)
IPC_SPEC = importlib.util.spec_from_file_location('extraction_ipc_runner', Path(__file__).with_name('run_ipc.py'))
IPC_RUNNER = importlib.util.module_from_spec(IPC_SPEC)
IPC_SPEC.loader.exec_module(IPC_RUNNER)


class CompileOnlyBoundary(unittest.TestCase):
    def test_ipc_returns_before_runtime_and_export(self):
        result = subprocess.CompletedProcess([], 0, 'DM compiler version 516.1681\n0 errors, 0 warnings', '')
        with patch.object(sys, 'argv', ['run_ipc.py', '--byond-bin', '.', '--compile-only']):
            with patch.object(IPC_RUNNER.subprocess, 'run', return_value=result) as execute:
                IPC_RUNNER.main()
        self.assertEqual(execute.call_count, 1)
        self.assertIn(execute.call_args.args[0][0].split('/')[-1].split('\\')[-1], ('dm.exe', 'DreamMaker'))

    def test_negative_control_accepts_only_exact_assertion(self):
        expected = 'assembled wheel retains actual identity and paid wear'
        assertion = f'Runtime error: {expected} at tests/extraction/equipment_probe.dm:38\n'
        self.assertTrue(RUNNER.intended_assertion_only(assertion, expected))
        for log in (assertion + assertion, assertion + 'Runtime error: unrelated\n',
                    assertion + 'Bad ref\n', assertion + '## ERROR\n',
                    assertion.replace('equipment_probe.dm', 'production.dm'),
                    assertion.replace(expected, 'different assertion')):
            self.assertFalse(RUNNER.intended_assertion_only(log, expected))

    def test_mode_returns_before_runtime_and_artifact_copy(self):
        root = Path(__file__).resolve().parents[2]
        result = subprocess.CompletedProcess([], 0, 'DM compiler version 516.1681\n0 errors, 0 warnings', '')
        with patch.object(RUNNER.subprocess, 'run', return_value=result) as execute:
            RUNNER.equipment(root, Path('compiler'), Path('daemon'), 0, 'mode', compile_only=True)
        self.assertEqual(execute.call_count, 1)
        self.assertEqual(execute.call_args.args[0][0], 'compiler')

    def test_vehicle_control_accepts_only_one_exact_caught_assertion(self):
        expected = 'equal-value replacement refuses captured native identity'
        assertion = f'FAIL: {expected} at tests/extraction/equipment_probe.dm:38\n'
        self.assertTrue(RUNNER.caught_vehicle_assertion_only(assertion, expected))
        self.assertFalse(RUNNER.intended_assertion_only(assertion, expected))
        for log in (assertion + assertion, assertion + 'FAIL: unrelated\n',
                    assertion + 'Runtime error: unrelated\n',
                    assertion + 'Bad ref\n', assertion + '## ERROR\n',
                    assertion.replace('equipment_probe.dm', 'production.dm'),
                    assertion.replace(expected, 'different assertion'),
                    assertion.replace('FAIL:', 'Runtime error:'),
                    assertion.rstrip() + ' unexpected suffix\n'):
            with self.subTest(log=log):
                self.assertFalse(RUNNER.caught_vehicle_assertion_only(log, expected))

    def test_corpse_control_uses_current_caught_assertion(self):
        root = Path(__file__).resolve().parents[2]
        expected = 'corpse retirement releases the actual configured insured weapon'
        assertion = f'FAIL: {expected} at tests/extraction/equipment_probe.dm:38\n'
        cases = [
            (assertion, '', '', 0, 'FAIL: equipment verification', True),
            (assertion + assertion, '', '', 0, 'FAIL: equipment verification', False),
            (assertion + 'FAIL: unrelated\n', '', '', 0, 'FAIL: equipment verification', False),
            (assertion, 'Runtime error: unrelated', '', 0, 'FAIL: equipment verification', False),
            (assertion, '', 'Bad ref', 0, 'FAIL: equipment verification', False),
            (assertion, '', '', 1, 'FAIL: equipment verification', False),
            (assertion, '', '', 0, 'PASS: equipment verification', False),
            (assertion.replace(expected, 'bones transition releases original nested insured equipment with stable identity and condition'), '', '', 0, 'FAIL: equipment verification', False),
        ]
        for log, stdout, stderr, code, result, accepted in cases:
            with self.subTest(log=log, stdout=stdout, stderr=stderr, code=code, result=result):
                def execute(command, **kwargs):
                    if command[0] == 'compiler':
                        return subprocess.CompletedProcess(command, 0, 'DM compiler version 516.1681\n0 errors, 0 warnings', '')
                    target = Path(kwargs['cwd'])
                    (target / 'runtime.log').write_text(log)
                    (target / 'result.txt').write_text(result)
                    return subprocess.CompletedProcess(command, code, stdout, stderr)
                with patch.object(RUNNER.subprocess, 'run', side_effect=execute), patch.object(RUNNER.shutil, 'copy2'), patch.object(RUNNER.shutil, 'copytree'):
                    if accepted:
                        RUNNER.equipment(root, Path('compiler'), Path('daemon'), 0, 'mode', corpse_release_control=True)
                    else:
                        with self.assertRaisesRegex(RuntimeError, 'Corpse release control failed outside its intended assertion'):
                            RUNNER.equipment(root, Path('compiler'), Path('daemon'), 0, 'mode', corpse_release_control=True)

    def test_store_returns_before_runtime(self):
        result = subprocess.CompletedProcess([], 0, 'DM compiler version 516.1681\n0 errors, 0 warnings', '')
        with patch.object(sys, 'argv', ['run.py', '--byond-bin', '.', '--probe', 'store', '--compile-only']):
            with patch.object(RUNNER.subprocess, 'run', return_value=result) as execute:
                RUNNER.main()
        self.assertEqual(execute.call_count, 1)
        self.assertIn(execute.call_args.args[0][0].split('/')[-1].split('\\')[-1], ('dm.exe', 'DreamMaker'))

    def test_city_pursuit_control_cli_compiles_without_runtime(self):
        result = subprocess.CompletedProcess([], 0, 'DM compiler version 516.1681\n0 errors, 0 warnings', '')
        with patch.object(sys, 'argv', ['run.py', '--byond-bin', '.', '--probe', 'city', '--compile-only', '--city-pursuit-negative-control']):
            with patch.object(RUNNER.subprocess, 'run', return_value=result) as execute:
                RUNNER.main()
        self.assertEqual(execute.call_count, 1)
        self.assertIn(execute.call_args.args[0][0].split('/')[-1].split('\\')[-1], ('dm.exe', 'DreamMaker'))

    def test_auxiliary_controls_compile_without_runtime(self):
        root = Path(__file__).resolve().parents[2]
        result = subprocess.CompletedProcess([], 0, 'DM compiler version 516.1681\n0 errors, 0 warnings', '')
        for control in ('escrow', 'mail_binding', 'auxiliary_pending', 'home_owner', 'home_graph', 'home_placement', 'home_revision', 'world_stale', 'fresh_incomplete', 'home_admission', 'marker_save', 'home_retire_owner', 'home_retire_partial', 'home_retire_graph', 'home_retire_remove', 'home_retire_restart', 'home_retire_prepare'):
            with self.subTest(control=control):
                with patch.object(RUNNER.subprocess, 'run', return_value=result) as execute:
                    RUNNER.equipment(root, Path('compiler'), Path('daemon'), 0, 'mode', compile_only=True, surface_control=control)
                self.assertEqual(execute.call_count, 1)
                self.assertEqual(execute.call_args.args[0][0], 'compiler')


if __name__ == '__main__':
    unittest.main()
