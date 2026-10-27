"""Offline control tests: fake adapter only; no installer or Windows API calls."""
import json
from pathlib import Path
import tempfile
import types
import unittest
from unittest.mock import patch

import directx_setup as dx


class Fake:
    exit_code = 0
    total = 1
    rows = []
    clean = True
    launch_error = False
    ticks = 0
    def preflight(self, limits): pass
    def free(self): return 3 * 1024 ** 3
    def open(self, **kw): kw['creation_guard']()
    def launch(self, argv, cwd, root, phase, **kw):
        self.argv = argv
        kw['creation_guard']()
        if self.launch_error: raise RuntimeError('launch failed')
        return types.SimpleNamespace(process=123)
    def exited(self, process): return self.ticks >= 1
    def pause(self, seconds): self.ticks += 1
    def accounting(self): return types.SimpleNamespace(total=self.total)
    def memory(self, handle): return 1
    def times(self, process): return (1, 0)
    def sockets(self, process): return self.rows
    def finish(self, process):
        return {'exit_code': self.exit_code, 'total_processes': self.total, 'active_processes': 0}
    def cleanup(self, process, seconds):
        self.cleaned = seconds
        return {'all_exited': self.clean}


class SetupControls(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.out = self.root / 'directx-evidence'
        self.fake = Fake()
        self.patches = [
            patch.object(dx, 'binding', return_value={'run': '1'}),
            patch.object(dx.acquire, 'verify_files'),
            patch.object(dx.acquire, '_read', return_value=b'x' * 537432),
            patch.object(dx.acquire, '_sha', return_value=dx.SETUP_SHA256),
            patch.object(dx.acquire, '_pe_x86'),
            patch.object(dx, 'system_dlls', return_value={'verified': True}),
            patch.object(dx, 'DLLS', {'fixture.dll': (1, 'a' * 64)}),
            patch('windows.Adapter', return_value=self.fake),
        ]
        for item in self.patches:
            item.start()
            self.addCleanup(item.stop)

    def run_setup(self):
        return dx.run(self.root, self.out, accept_terms=True)

    def test_no_acceptance_stops_before_environment_or_native_work(self):
        with self.assertRaisesRegex(RuntimeError, 'acceptance'):
            dx.run(self.root, self.out)
        dx.binding.assert_not_called()
        dx.acquire.verify_files.assert_not_called()
        self.assertFalse(self.out.exists())

    def test_exact_single_silent_command_and_confirmed_cleanup(self):
        result = self.run_setup()
        self.assertEqual(self.fake.argv, [str(self.root/'byond/directx/DXSETUP.exe'), '/silent'])
        self.assertEqual(self.fake.cleaned, 5)
        self.assertEqual(result['status'], 'PASSED')
        self.assertTrue(result['cleanup']['all_exited'])
        self.assertEqual(json.loads((self.out/'directx-setup-receipt.json').read_text()), result)

    def test_nonzero_and_reboot_required_are_failures(self):
        for code in (1, 3010, 0xc0000005):
            with self.subTest(code=code):
                self.fake.exit_code = code
                self.out = self.root / str(code)
                with self.assertRaisesRegex(RuntimeError, 'nonzero_or_reboot'):
                    self.run_setup()
                self.assertEqual(self.fake.cleaned, 5)
                self.assertEqual(json.loads((self.out/'directx-setup-receipt.json').read_text())['status'], 'FAILED')

    def test_unexpected_child_and_socket_stop(self):
        for child in (True, False):
            self.out = self.root / str(child)
            self.fake.ticks = 0
            self.fake.total = 2 if child else 1
            self.fake.rows = [] if child else [{'protocol': 'tcp'}]
            with self.assertRaisesRegex(RuntimeError, 'child|socket'):
                self.run_setup()
            self.assertEqual(self.fake.cleaned, 5)

    def test_unconfirmed_cleanup_prevents_success(self):
        self.fake.clean = False
        with self.assertRaisesRegex(RuntimeError, 'cleanup_unconfirmed'):
            self.run_setup()
        self.assertEqual(json.loads((self.out/'directx-setup-receipt.json').read_text())['status'], 'FAILED')

    def test_cleanup_exception_prevents_success(self):
        self.fake.cleanup = lambda *args: (_ for _ in ()).throw(RuntimeError('cleanup'))
        with self.assertRaisesRegex(RuntimeError, 'cleanup'):
            self.run_setup()
        result = json.loads((self.out/'directx-setup-receipt.json').read_text())
        self.assertEqual(result['status'], 'FAILED')
        self.assertFalse(result['cleanup']['all_exited'])

    def test_launch_failure_still_closes_job(self):
        self.fake.launch_error = True
        with self.assertRaisesRegex(RuntimeError, 'launch failed'):
            self.run_setup()
        self.assertEqual(self.fake.cleaned, 5)

    def test_unresolved_pin_stops_before_native_work(self):
        with patch.object(dx, 'DLLS', {'missing': (0, 'UNRESOLVED')}):
            with self.assertRaisesRegex(RuntimeError, 'unresolved_review_pin'):
                self.run_setup()
        self.assertFalse(self.out.exists())

    def test_work_timeout_still_cleans_owned_handle(self):
        with patch.object(dx.time, 'monotonic', side_effect=[0, 0, 0, 61]):
            with self.assertRaisesRegex(RuntimeError, 'timeout'):
                self.run_setup()
        self.assertEqual(self.fake.cleaned, 5)

    def test_same_run_setup_receipt_required(self):
        record = self.run_setup()
        self.patches[2].stop()
        with patch.object(dx.acquire, '_read', return_value=json.dumps(record).encode()):
            self.assertEqual(dx.verify_setup_receipt(self.root, self.out/'directx-setup-receipt.json'), record)
            record['binding'] = {'run': 'another'}
        with patch.object(dx.acquire, '_read', return_value=json.dumps(record).encode()):
            with self.assertRaisesRegex(RuntimeError, 'same_successful_run'):
                dx.verify_setup_receipt(self.root, self.out/'directx-setup-receipt.json')

    def test_receipt_location_bound_to_engine_root(self):
        with self.assertRaisesRegex(RuntimeError, 'receipt_location'):
            dx.verify_setup_receipt(self.root, self.root/'other/directx-setup-receipt.json')

    def test_existing_output_never_overwritten(self):
        self.out.mkdir()
        with self.assertRaisesRegex(RuntimeError, 'fresh_setup_output'):
            self.run_setup()


class Admission(unittest.TestCase):
    @patch('activation.require_runtime', return_value=None)
    def test_non_windows_and_wrong_branch_rejected(self, fresh_binding):
        # Isolate the unchanged DirectX checks; the added held binding is
        # exercised separately by test_lighting_packet with no native calls.
        env = {'GITHUB_ACTIONS': 'true', 'RUNNER_ENVIRONMENT': 'github-hosted',
               'GITHUB_REPOSITORY': 'Civ13/Civ13', 'GITHUB_RUN_ATTEMPT': '1',
               'GITHUB_REF': dx.BRANCH, 'GITHUB_SHA': 'a' * 40,
               'GITHUB_RUN_ID': '123', 'GITHUB_JOB': 'bakery'}
        with patch.dict(dx.os.environ, env, clear=True), patch.object(dx.os, 'name', 'posix'):
            with self.assertRaisesRegex(RuntimeError, 'hosted_windows'):
                dx.binding()
        with patch.dict(dx.os.environ, env, clear=True), patch.object(dx.os, 'name', 'nt'):
            self.assertEqual(dx.binding()['GITHUB_RUN_ID'], '123')
            dx.os.environ['GITHUB_REF'] = 'refs/heads/master'
            with self.assertRaisesRegex(RuntimeError, 'wrong_run_admission'):
                dx.binding()

    def test_native_source_has_no_alternate_launch_route(self):
        source = Path(dx.__file__).read_text()
        for token in ('subprocess', 'ShellExecute', 'rundll32', 'regsvr32', 'urllib', 'winreg'):
            self.assertNotIn(token, source)
        self.assertIn("[str(executable), '/silent']", source)
        self.assertIn('adapter.cleanup(process, CLEANUP_SECONDS)', source)


class SystemPins(unittest.TestCase):
    def test_exact_hash_and_architecture_required(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root/'SysWOW64').mkdir()
            (root/'SysWOW64/fixture.dll').write_bytes(b'MZfixture')
            with patch.object(dx.acquire, '_windows_root', return_value=root), \
                 patch.object(dx, 'DLLS', {'fixture.dll': (9, dx.acquire._sha(b'MZfixture'))}), \
                 patch.object(dx.acquire, '_pe_x86') as pe:
                self.assertEqual(dx.system_dlls()['fixture.dll']['bytes'], 9)
                pe.assert_called_once()
                (root/'SysWOW64/fixture.dll').write_bytes(b'MZchanged')
                with self.assertRaisesRegex(RuntimeError, 'hash_mismatch'):
                    dx.system_dlls()
                pe.side_effect = RuntimeError('wrong architecture')
                with self.assertRaisesRegex(RuntimeError, 'wrong architecture'):
                    dx.system_dlls()


if __name__ == '__main__':
    unittest.main()
