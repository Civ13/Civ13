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

    def test_store_returns_before_runtime(self):
        result = subprocess.CompletedProcess([], 0, 'DM compiler version 516.1681\n0 errors, 0 warnings', '')
        with patch.object(sys, 'argv', ['run.py', '--byond-bin', '.', '--probe', 'store', '--compile-only']):
            with patch.object(RUNNER.subprocess, 'run', return_value=result) as execute:
                RUNNER.main()
        self.assertEqual(execute.call_count, 1)
        self.assertIn(execute.call_args.args[0][0].split('/')[-1].split('\\')[-1], ('dm.exe', 'DreamMaker'))

    def test_auxiliary_controls_compile_without_runtime(self):
        root = Path(__file__).resolve().parents[2]
        result = subprocess.CompletedProcess([], 0, 'DM compiler version 516.1681\n0 errors, 0 warnings', '')
        for control in ('escrow', 'mail_binding', 'auxiliary_pending', 'home_owner', 'home_graph', 'home_placement', 'home_revision', 'world_stale', 'fresh_incomplete', 'home_admission', 'marker_save'):
            with self.subTest(control=control):
                with patch.object(RUNNER.subprocess, 'run', return_value=result) as execute:
                    RUNNER.equipment(root, Path('compiler'), Path('daemon'), 0, 'mode', compile_only=True, surface_control=control)
                self.assertEqual(execute.call_count, 1)
                self.assertEqual(execute.call_args.args[0][0], 'compiler')


if __name__ == '__main__':
    unittest.main()
