"""Offline/mocked admission, source identity and sequencing checks."""
import hashlib
import json
from pathlib import Path
import tempfile
import time
import unittest
from unittest.mock import patch

import activation
import directx_official_setup as installer
import encoder_proof
import prepare_official_toolchain as preparation
import prepare_nuget_toolchain as nuget_prepare
import nuget_local_runtime
import toolchain_workflow as orchestration


class Response:
    def __init__(self, body):
        self.body = body
        self.headers = {'Content-Length': str(len(body))}
    def __enter__(self): return self
    def __exit__(self, *args): return False
    def geturl(self): return 'https://download.microsoft.com/example'
    def read(self, count):
        result, self.body = self.body[:count], self.body[count:]
        return result


class PreparationTests(unittest.TestCase):
    def test_actual_toolchain_state_matches_activation(self):
        a = json.loads((Path(__file__).parent/'activation.json').read_text(encoding='utf-8'))
        self.assertIs(type(a['released']), bool)
        for value in (preparation.PREPARE_ENABLED, installer.OFFICIAL_INSTALL_ENABLED,
                      orchestration.ORCHESTRATION_ENABLED):
            self.assertIs(value, False)
        for value in (nuget_prepare.PREPARE_NUGET_ENABLED, nuget_prepare.NUGET_LICENSE_ACCEPTED,
                      nuget_local_runtime.APPLOCAL_STAGE_ENABLED, nuget_local_runtime.NUGET_LICENSE_ACCEPTED,
                      encoder_proof.ENCODER_PROOF_ENABLED):
            self.assertIs(value, a['released'])
        with patch.object(preparation, 'PREPARE_ENABLED', False), \
             patch.object(activation, 'require_runtime', side_effect=AssertionError('unexpected binding')):
            with self.assertRaisesRegex(RuntimeError, 'toolchain_prepare_disabled'):
                preparation.prepare('unused')

    def test_held_and_released_snapshot_contract(self):
        for released in (False, True):
            with self.subTest(released=released):
                self.assertIs(activation.validate_release_states(released, released, False), released)
                with self.assertRaisesRegex(RuntimeError, 'Release states disagree'):
                    activation.validate_release_states(released, not released, False)
                with self.assertRaisesRegex(RuntimeError, 'Release states disagree'):
                    activation.validate_release_states(released, released, True)

    def test_download_rejects_wrong_digest_and_accepts_exact_bytes_without_network(self):
        class Opener:
            def open(self, *args, **kwargs): return Response(b'fixture')
        with tempfile.TemporaryDirectory() as temp, patch.object(preparation.urllib.request, 'build_opener', return_value=Opener()):
            root = Path(temp)
            expected = hashlib.sha256(b'fixture').hexdigest()
            result = preparation.fetch('https://download.microsoft.com/example', root/'ok', 7, expected,
                                       {'download.microsoft.com'}, time.monotonic()+5)
            self.assertEqual(result['sha256'], expected)
            with self.assertRaisesRegex(RuntimeError, 'download_identity_mismatch'):
                preparation.fetch('https://download.microsoft.com/example', root/'bad', 7, '0'*64,
                                  {'download.microsoft.com'}, time.monotonic()+5)

    def test_cross_host_and_http_redirects_rejected(self):
        handler = preparation.AllowedRedirects({'download.microsoft.com'})
        for url in ('http://download.microsoft.com/x', 'https://wrong.example/x',
                    'https://download.microsoft.com:444/x'):
            with self.subTest(url=url), self.assertRaisesRegex(RuntimeError, 'unapproved_redirect'):
                handler.redirect_request(None, None, 302, '', {}, url)

    def test_encoder_checks_deadline_and_logs_after_exit(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root/'encode.stdout.log').write_bytes(b'x' * (1024*1024+1))
            with self.assertRaisesRegex(RuntimeError, 'encoder_log_limit'):
                encoder_proof.check_output_budget(root, root/'out.mp4', lambda: None)
            def deadline(): raise RuntimeError('encoder_work_timeout')
            with self.assertRaisesRegex(RuntimeError, 'encoder_work_timeout'):
                encoder_proof.check_output_budget(root, root/'out.mp4', deadline)
        source = (Path(__file__).parent/'encoder_proof.py').read_text(encoding='utf-8')
        self.assertIn('adapter.pause(0.05)\n                check_output_budget(output, clip, budget)\n                done = adapter.finish', source)

    def test_install_only_when_missing_then_reprobe(self):
        available = {'status': 'AVAILABLE_PINNED_SYSTEM_COMPONENTS'}
        missing = {'status': 'BLOCKED_SYSTEM_COMPONENTS'}
        with patch.object(orchestration, 'ORCHESTRATION_ENABLED', True), \
             patch.object(activation, 'require_runtime'), \
             patch.object(orchestration.acquire, '_plain_ancestors'), \
             patch.object(orchestration.installed_directx, 'probe', side_effect=[missing, available]), \
             patch.object(orchestration, 'missing_system_dlls', return_value=['d3dx9_43.dll']), \
             patch.object(orchestration.installed_directx, 'verify') as verify, \
             patch.object(orchestration.directx_official_setup, 'run') as run:
            self.assertEqual(orchestration.prepare_runtime(Path('unused'))['after'], available['status'])
            run.assert_called_once()
            verify.assert_called_once()
        with patch.object(orchestration, 'ORCHESTRATION_ENABLED', True), \
             patch.object(activation, 'require_runtime'), \
             patch.object(orchestration.acquire, '_plain_ancestors'), \
             patch.object(orchestration.installed_directx, 'probe', side_effect=[available, available]), \
             patch.object(orchestration.installed_directx, 'verify'), \
             patch.object(orchestration.directx_official_setup, 'run') as run:
            orchestration.prepare_runtime(Path('unused'))
            run.assert_not_called()

    def test_missing_dll_is_distinguished_from_mismatch(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root/'SysWOW64').mkdir()
            (root/'SysWOW64'/'present.dll').write_bytes(b'x')
            pins = {'present.dll': (1, hashlib.sha256(b'x').hexdigest()),
                    'missing.dll': (1, hashlib.sha256(b'y').hexdigest())}
            with patch.object(orchestration.acquire, '_windows_root', return_value=root), \
                 patch.object(orchestration.acquire, '_pe_x86'), \
                 patch.object(installer, 'DLLS', pins):
                self.assertEqual(orchestration.missing_system_dlls(), ['missing.dll'])
                (root/'SysWOW64'/'present.dll').write_bytes(b'z')
                with self.assertRaisesRegex(RuntimeError, 'existing_system_dll_mismatch'):
                    orchestration.missing_system_dlls()

    def test_workflow_state_order_and_fresh_branch_agree(self):
        here = Path(__file__).parent
        w = (here/'workflow.reference.txt').read_text(encoding='utf-8')
        released = json.loads((here/'activation.json').read_text(encoding='utf-8'))['released']
        self.assertIn(('true' if released else 'false') + ' && github.repository', w)
        stages = ['prepare_nuget_toolchain.py --root', 'verify_nuget_signatures.ps1',
                  'nuget_local_runtime.py --root', 'run_encoder_proof.py --root', 'firewall_supervisor.ps1']
        self.assertEqual([w.index(s) for s in stages], sorted(w.index(s) for s in stages))
        branch = 'ci/cloud-bakery225-control-5161688-20261031-r1'
        self.assertEqual(activation.BRANCH, branch)
        self.assertEqual(installer.BRANCH, 'refs/heads/' + branch)
        for name in ('firewall_supervisor.ps1', 'run_scene.py', 'workflow.reference.txt'):
            self.assertIn(branch, (here/name).read_text(encoding='utf-8'))
        self.assertEqual(activation.DEADLINE, '2026-10-31T20:00:00Z')


if __name__ == '__main__':
    unittest.main()
