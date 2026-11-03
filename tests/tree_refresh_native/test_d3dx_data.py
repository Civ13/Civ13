"""Offline D3DX preparation controls. Synthetic PE/ZIP bytes; no network or DLL load."""
from contextlib import ExitStack
from copy import deepcopy
import base64
import io
import hashlib
import json
import os
from pathlib import Path
import socket
import stat
import sys
import tempfile
import time
from types import SimpleNamespace
import unittest
from unittest.mock import patch
import zipfile

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import d3dx_data as M
import test_harness as H


def certificate():
    return dict(status='Valid', signature_type='Authenticode',
                signer=dict(simple_name='Microsoft Corporation', subject='CN=Microsoft Corporation, O=Microsoft Corporation, C=US',
                            certificate_sha256='a'*64), timestamp=dict(certificate_sha256='b'*64))


def package(path, edge=None, machine=0x14c, extras=()):
    contents = {M.D3DX: H.DependencyAudit.pe(normal=edge, machine=machine),
                M.COMPILER: H.DependencyAudit.pe(normal='kernel32.dll'),
                'LICENSE.txt': b'original license bytes\r\n', 'NOTICE.md': b'original notice bytes\n',
                '.signature.p7s': b'package signature preserved as data',
                'build/native/Microsoft.DXSDK.D3DX.targets': b'NEVER EVALUATE',
                'build/native/release/bin/x64/D3DX9_43.dll': b'NEVER STAGE'}
    with zipfile.ZipFile(path, 'w', compression=zipfile.ZIP_DEFLATED) as archive:
        for name, raw in list(contents.items())+list(extras):
            archive.writestr(name, raw)
    raw = path.read_bytes()
    with zipfile.ZipFile(path) as archive:
        entries = {name: dict(bytes=archive.getinfo(name).file_size,
                             compressed_bytes=archive.getinfo(name).compress_size) for name in (M.D3DX, M.COMPILER, *M.LEGAL)}
    return dict(url=M.PACKAGE_URL, bytes=len(raw), sha512=hashlib.sha512(raw).hexdigest(), entries=entries)


class DataPreparation(unittest.TestCase):
    def setUp(self):
        self.guards = ExitStack()
        # Model the hosted Windows identity without changing global os.name or Path.
        self.guards.enter_context(patch.object(M, 'os', SimpleNamespace(
            name='nt', environ=os.environ)))
        self.guards.enter_context(patch.object(socket, 'create_connection', side_effect=AssertionError('offline only')))
        self.guards.enter_context(patch.object(M.urllib.request.OpenerDirector, 'open', side_effect=AssertionError('offline only')))
        self.guards.enter_context(patch.object(M.subprocess, 'run', side_effect=AssertionError('no external commands')))
        self.addCleanup(self.guards.close)
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.archive = self.root/'synthetic.zip'
        self.deadline = time.monotonic()+30

    def test_frozen_pin_provenance_and_original_toolchain(self):
        pin = M.load_pin()
        self.assertEqual(pin['sha512'], '9f6a95ed858555c1c438a85219ede32c82729068b21dd7ecf11de01cf3cdd525b2f04a58643bfcc14c48a29403dc1c80246f0a12a1ef4377b91b855f6d6d7986')
        self.assertEqual(pin['entries'][M.D3DX]['bytes'], 2001304)
        self.assertEqual(pin['entries'][M.COMPILER]['bytes'], 2109336)
        self.assertEqual(pin['byond_evidence']['artifact'], 13170505270)
        self.assertEqual(pin['byond']['files']['dreamseeker.exe']['sha256'], 'dde2893d7d6721eb8cb73d9e6b9f8cb28d86d1e432b42edaad10b066800a97e4')
        self.assertFalse(any('D3DX' in name for name in pin['byond']['files']))

    def test_selective_extraction_excludes_targets_x64_and_unneeded_compiler(self):
        pin = package(self.archive)
        result = M.stage_members(self.archive, self.root, pin, self.deadline)
        self.assertFalse(result['compiler_included'])
        self.assertEqual(set(result['files']), {'x86/D3DX9_43.dll', 'licenses/LICENSE.txt', 'licenses/NOTICE.md', 'licenses/.signature.p7s'})
        self.assertEqual((self.root/'selected/licenses/LICENSE.txt').read_bytes(), b'original license bytes\r\n')
        self.assertEqual(result['package']['sha256'], hashlib.sha256(self.archive.read_bytes()).hexdigest())
        for item in result['files'].values():
            self.assertEqual(item['sha256'], hashlib.sha256((self.root/item['path']).read_bytes()).hexdigest())

    def test_companion_requires_actual_normal_or_delay_import(self):
        for kind in ('normal', 'delay'):
            with self.subTest(kind=kind), tempfile.TemporaryDirectory() as directory:
                root = Path(directory); archive = root/'test.zip'
                pin = package(archive, edge='D3DCompiler_43.dll')
                if kind == 'delay':
                    # Preserve the same full guarded extraction path for a delay edge.
                    with zipfile.ZipFile(archive) as old:
                        files = {i.filename: old.read(i) for i in old.infolist()}
                    files[M.D3DX] = H.DependencyAudit.pe(delay='d3dcompiler_43.dll')
                    with zipfile.ZipFile(archive, 'w', compression=zipfile.ZIP_DEFLATED) as out:
                        for name, raw in files.items(): out.writestr(name, raw)
                    raw = archive.read_bytes(); pin['bytes'] = len(raw); pin['sha512'] = hashlib.sha512(raw).hexdigest()
                    with zipfile.ZipFile(archive) as z:
                        pin['entries'][M.D3DX]['compressed_bytes'] = z.getinfo(M.D3DX).compress_size
                result = M.stage_members(archive, root, pin, self.deadline)
                self.assertTrue(result['compiler_included'])
                self.assertEqual(result['compiler_import_edges'][0]['kind'], kind)
                self.assertIn('x86/D3DCompiler_43.dll', result['files'])

    def test_hash_or_size_failure_precedes_zip_parser(self):
        pin = package(self.archive)
        for field, value in (('sha512', '0'*128), ('bytes', pin['bytes']+1)):
            bad = deepcopy(pin); bad[field] = value
            with self.subTest(field=field), patch.object(M.zipfile, 'ZipFile') as parse:
                with self.assertRaises(ValueError): M.stage_members(self.archive, self.root, bad, self.deadline)
                parse.assert_not_called()

    def test_x64_member_cannot_be_admitted_as_x86(self):
        pin = package(self.archive, machine=0x8664)
        with self.assertRaisesRegex(ValueError, 'x86'): M.stage_members(self.archive, self.root, pin, self.deadline)

    def test_catalog_member_drift_and_missing_legal_fail(self):
        pin = package(self.archive)
        for field in ('bytes', 'compressed_bytes'):
            bad = deepcopy(pin); bad['entries']['LICENSE.txt'][field] += 1
            with self.subTest(field=field), zipfile.ZipFile(self.archive) as z:
                with self.assertRaisesRegex(ValueError, 'metadata drift'): M.archive_index(z, bad)
        with zipfile.ZipFile(self.archive) as z:
            bad = deepcopy(pin); bad['entries']['MISSING.txt'] = bad['entries'].pop('NOTICE.md')
            with self.assertRaisesRegex(ValueError, 'Missing'): M.archive_index(z, bad)

    def test_path_duplicate_and_link_controls(self):
        for name in ('../escape', '/absolute', 'C:/absolute', 'a\\b', 'a/../b', 'a//b', 'CON.txt', 'a./b', 'a:stream', 'a?b', 'a\x01b'):
            with self.subTest(name=name), self.assertRaises(ValueError): M.safe_member(name)
        for extra in ('license.TXT', 'LICENSE.txt/'):
            with self.subTest(extra=extra):
                pin = package(self.archive, extras=((extra, b'bad'),))
                with zipfile.ZipFile(self.archive) as z:
                    with self.assertRaisesRegex(ValueError, 'Duplicate'): M.archive_index(z, pin)
        link = zipfile.ZipInfo('link'); link.external_attr = (stat.S_IFLNK | 0o777) << 16
        pin = package(self.archive, extras=((link, b'target'),))
        with zipfile.ZipFile(self.archive) as z:
            with self.assertRaisesRegex(ValueError, 'Linked'): M.archive_index(z, pin)

    def test_selected_member_crc_failure_is_not_accepted(self):
        pin = package(self.archive)
        with zipfile.ZipFile(self.archive) as z:
            info = z.getinfo(M.D3DX); info.CRC ^= 1
            with self.assertRaises(zipfile.BadZipFile): M.read_member(z, info, self.deadline)

    def test_deadline_and_retention_ceiling(self):
        pin = package(self.archive)
        with self.assertRaisesRegex(ValueError, 'deadline'): M.stage_members(self.archive, self.root, pin, 0)
        with patch.object(M, 'CAP', 1):
            with self.assertRaisesRegex(ValueError, 'retained'): M.census(self.root)
        self.assertFalse((self.root/'preparation.json').exists())

    def test_signature_requires_valid_embedded_microsoft_timestamp(self):
        M.validate_signature(certificate())
        for mutation in ('status', 'catalog', 'name', 'organization', 'hash', 'timestamp'):
            item = certificate()
            if mutation == 'status': item['status'] = 'UnknownError'
            if mutation == 'catalog': item['signature_type'] = 'Catalog'
            if mutation == 'name': item['signer']['simple_name'] = 'Someone else'
            if mutation == 'organization': item['signer']['subject'] = 'CN=Microsoft Corporation, O=Someone else'
            if mutation == 'hash': item['signer']['certificate_sha256'] = 'not a hash'
            if mutation == 'timestamp': item['timestamp'] = None
            with self.subTest(mutation=mutation), self.assertRaises(ValueError): M.validate_signature(item)

    def test_signature_command_has_only_fixed_metadata_script_and_literal_path(self):
        with patch.dict(os.environ, {'SystemRoot': r'C:\Windows'}), patch.object(M.subprocess, 'run') as run:
            run.return_value = SimpleNamespace(stdout=json.dumps(certificate()).encode(), stderr=b'', returncode=0)
            actual = M.signature_file(self.root/'selected.dll', self.deadline)
            self.assertEqual(actual['status'], 'Valid')
            args = run.call_args.args[0]
            self.assertTrue(args[0].endswith('powershell.exe'))
            self.assertIn('-NoProfile', args); self.assertIn('-NonInteractive', args)
            self.assertEqual(args[-2:], ['-LiteralFile', str(self.root/'selected.dll')])
            self.assertEqual(Path(args[args.index('-File')+1]).name, 'd3dx-signature.ps1')
            self.assertLessEqual(run.call_args.kwargs['timeout'], 20)
        script = (HERE/'d3dx-signature.ps1').read_text()
        self.assertIn('Get-AuthenticodeSignature -LiteralPath', script)
        self.assertNotIn('Set-ExecutionPolicy', script)
        self.assertNotIn('Add-Type', script)
        self.assertNotIn('rundll32', script)

    PRIVATE_CANARY = br'C:\private\account\canary.json token=TEST_ONLY_SIGNATURE_CANARY'

    def assert_private_failure_facts(self, detail):
        self.assertEqual(detail['retained_raw_output_bytes'], 0)
        self.assertFalse(detail['output_limit_enforced_during_capture'])
        self.assertEqual(detail['checked_output_limit_bytes'], 32768)
        self.assertEqual(detail['hint_scan_limit_bytes_per_stream'], 8192)
        for stream in ('stdout', 'stderr'):
            self.assertEqual(set(detail[stream]), {
                'captured_bytes', 'hint', 'hint_scan_bytes', 'hint_scan_truncated'})
            self.assertIn(detail[stream]['hint'], {
                'unclassified_error', 'powershell_security_error', 'powershell_command_not_found',
                'powershell_parse_error', 'powershell_runtime_error'})
            self.assertLessEqual(detail[stream]['hint_scan_bytes'], 8192)
        serialized = json.dumps(detail)
        self.assertNotIn('TEST_ONLY_SIGNATURE_CANARY', serialized)
        self.assertNotIn('canary.json', serialized)
        self.assertNotIn(base64.b64encode(self.PRIVATE_CANARY).decode(), serialized)
        self.assertNotIn('prefix_base64', serialized)
        self.assertNotIn('sha256', serialized)  # No fingerprints of possibly secret text.

    def test_nonzero_signature_exit_keeps_only_allowlisted_output_facts(self):
        stdout = json.dumps(dict(certificate(), debug=self.PRIVATE_CANARY.decode())).encode()
        stderr = self.PRIVATE_CANARY+b' PSSecurityException '+b'\xff'*10000
        with patch.dict(os.environ, {'SystemRoot': r'C:\Windows'}), patch.object(
                M.subprocess, 'run', return_value=SimpleNamespace(
                    stdout=stdout, stderr=stderr, returncode=23)):
            with self.assertRaises(M.SignatureMetadataError) as raised:
                M.signature_file(self.root/'selected.dll', self.deadline)
        detail = raised.exception.diagnostic
        self.assertEqual((detail['reason'], detail['returncode']), ('nonzero_exit', 23))
        self.assertTrue(detail['capture_complete'])
        self.assertLessEqual(detail['timeout_seconds'], 20)
        self.assertEqual(detail['stdout']['captured_bytes'], len(stdout))
        self.assertEqual(detail['stderr']['captured_bytes'], len(stderr))
        self.assertEqual(detail['stderr']['hint'], 'powershell_security_error')
        self.assertTrue(detail['stderr']['hint_scan_truncated'])
        self.assert_private_failure_facts(detail)
        with self.assertRaises(ValueError):
            M.validate_signature(dict(status='command_failed'))

    def test_output_hints_are_closed_and_scan_only_a_bounded_sample(self):
        cases = [(self.PRIVATE_CANARY+b' CommandNotFoundException', 'powershell_command_not_found'),
                 ((self.PRIVATE_CANARY.decode()+' ParserError').encode('utf-16-le'), 'powershell_parse_error'),
                 (b'x'*8192+b' PSSecurityException '+self.PRIVATE_CANARY, 'unclassified_error'),
                 (self.PRIVATE_CANARY+b' unknown free-form diagnostic', 'unclassified_error')]
        for raw, expected in cases:
            with self.subTest(expected=expected), patch.dict(os.environ, {'SystemRoot': r'C:\Windows'}), \
                    patch.object(M.subprocess, 'run', return_value=SimpleNamespace(
                        stdout=b'', stderr=raw, returncode=1)):
                with self.assertRaises(M.SignatureMetadataError) as raised:
                    M.signature_file(self.root/'selected.dll', self.deadline)
                detail = raised.exception.diagnostic
                self.assertEqual(detail['stderr']['hint'], expected)
                self.assertEqual(detail['stderr']['captured_bytes'], len(raw))
                self.assert_private_failure_facts(detail)

    def test_invalid_or_excessive_signature_output_stays_rejected(self):
        for stdout, reason in ((b'{', 'invalid_json'), (b'\xff', 'invalid_json'),
                               (b'[]', 'non_object_json'), (b'x'*32769, 'output_limit')):
            with self.subTest(reason=reason), patch.dict(os.environ, {'SystemRoot': r'C:\Windows'}), \
                    patch.object(M.subprocess, 'run', return_value=SimpleNamespace(
                        stdout=stdout, stderr=b'', returncode=0)):
                with self.assertRaises(M.SignatureMetadataError) as raised:
                    M.signature_file(self.root/'selected.dll', self.deadline)
                detail = raised.exception.diagnostic
                self.assertEqual(detail['reason'], reason)
                self.assertEqual(detail['returncode'], 0)
                self.assertEqual(detail['stdout']['captured_bytes'], len(stdout))
                self.assert_private_failure_facts(detail)

    def test_signature_timeout_and_start_errors_retain_partial_facts(self):
        for error, reason in ((M.subprocess.TimeoutExpired('fixed command', 20,
                                    output=self.PRIVATE_CANARY,
                                    stderr=self.PRIVATE_CANARY+b' RuntimeException'), 'timeout'),
                              (OSError(2, self.PRIVATE_CANARY.decode()), 'start_failed')):
            with self.subTest(reason=reason), patch.dict(os.environ, {'SystemRoot': r'C:\Windows'}), \
                    patch.object(M.subprocess, 'run', side_effect=error):
                with self.assertRaises(M.SignatureMetadataError) as raised:
                    M.signature_file(self.root/'selected.dll', self.deadline)
                detail = raised.exception.diagnostic
                self.assertEqual(detail['reason'], reason)
                self.assertIsNone(detail['returncode'])
                self.assertFalse(detail['capture_complete'])
                self.assert_private_failure_facts(detail)
                if reason == 'timeout':
                    self.assertEqual(detail['stderr']['hint'], 'powershell_runtime_error')
                else:
                    self.assertEqual(detail['os_error']['errno'], 2)
                    self.assertEqual(set(detail['os_error']), {'errno', 'winerror'})
                    self.assertEqual(detail['stdout']['captured_bytes'], 0)

    def test_non_numeric_exception_attributes_cannot_become_public_text(self):
        error = OSError(2, self.PRIVATE_CANARY.decode())
        error.errno = self.PRIVATE_CANARY.decode()
        error.winerror = 2**80
        with patch.dict(os.environ, {'SystemRoot': r'C:\Windows'}), patch.object(
                M.subprocess, 'run', side_effect=error):
            with self.assertRaises(M.SignatureMetadataError) as raised:
                M.signature_file(self.root/'selected.dll', self.deadline)
        detail = raised.exception.diagnostic
        self.assertEqual(detail['os_error'], dict(errno=None, winerror=None))
        self.assert_private_failure_facts(detail)

    def failed_signature_preparation(self, **command):
        pin, binary, environment = self.prepare_fixture()
        def fake_fetch(path, unused_pin, deadline):
            path.write_bytes(self.archive.read_bytes())
        with patch.dict(os.environ, dict(environment, SystemRoot=r'C:\Windows')), \
                patch.object(M, 'load_pin', return_value=pin), \
                patch.object(M, 'fetch_package', side_effect=fake_fetch), \
                patch.object(M.subprocess, 'run', **command) as run:
            out = self.root/'tree-d3dx-data'
            report = M.prepare('a'*40, binary, out)
        self.assertEqual(run.call_count, 1)  # No companion attempt after failure.
        self.assertEqual(report['status'], 'failed')
        self.assertFalse(report['native_ready'])
        self.assertTrue(report['byond_preserved'])
        self.assertEqual(report['byond_before'], report['byond_after'])
        fact = report['staging']['files']['x86/D3DX9_43.dll']
        self.assertNotIn('signature', fact)
        saved = json.loads((out/'preparation.json').read_text())
        self.assertEqual(saved['staging']['files']['x86/D3DX9_43.dll'][
            'signature_command_failure'], fact['signature_command_failure'])
        self.assertLessEqual((out/'preparation.json').stat().st_size, M.REPORT_CAP)
        self.assertLessEqual(M.census(out), M.CAP)
        self.assert_private_failure_facts(fact['signature_command_failure'])
        self.assertNotIn('TEST_ONLY_SIGNATURE_CANARY', json.dumps(saved))
        self.assertNotIn('canary.json', json.dumps(saved))
        return saved, fact['signature_command_failure']

    def test_nonzero_command_details_survive_report_and_input_cleanup(self):
        report, detail = self.failed_signature_preparation(return_value=SimpleNamespace(
            stdout=json.dumps(dict(certificate(), debug=self.PRIVATE_CANARY.decode())).encode(),
            stderr=self.PRIVATE_CANARY+b' RuntimeException '+b'failure detail'*1700, returncode=31))
        self.assertEqual(report['error'], 'Signature metadata command failed')
        self.assertEqual(detail['returncode'], 31)
        self.assertEqual(detail['stderr']['hint'], 'powershell_runtime_error')
        self.assertTrue(detail['stderr']['hint_scan_truncated'])

    def test_timeout_details_survive_report_and_input_cleanup(self):
        report, detail = self.failed_signature_preparation(side_effect=M.subprocess.TimeoutExpired(
            'fixed metadata command', 20, output=self.PRIVATE_CANARY,
            stderr=(self.PRIVATE_CANARY.decode()+' PSSecurityException').encode('utf-16-le')))
        self.assertEqual(report['error'], 'Signature metadata command timed out')
        self.assertEqual(detail['reason'], 'timeout')
        self.assertFalse(detail['capture_complete'])
        self.assertEqual(detail['stderr']['hint'], 'powershell_security_error')

    def test_fetch_url_response_bounds_and_no_redirect(self):
        raw = b'only synthetic package bytes'
        pin = dict(url=M.PACKAGE_URL, bytes=len(raw), sha512=hashlib.sha512(raw).hexdigest())
        def response(data=raw, status=200, url=M.PACKAGE_URL, length=None):
            result = io.BytesIO(data); result.status = status; result.geturl = lambda: url
            result.headers = {} if length is None else {'Content-Length': length}; return result
        with patch.object(M.urllib.request, 'build_opener') as build:
            build.return_value.open.return_value = response()
            M.fetch_package(self.root/'good.nupkg', pin, self.deadline)
            self.assertEqual(build.return_value.open.call_args.args[0].full_url, M.PACKAGE_URL)
            self.assertIsInstance(build.call_args.args[1], M.NoRedirect)
            for label, data, status, url, length in (
                ('oversize', raw+b'x', 200, M.PACKAGE_URL, None),
                ('short', raw[:-1], 200, M.PACKAGE_URL, None),
                ('status', raw, 302, M.PACKAGE_URL, None),
                ('url', raw, 200, 'https://example.invalid/data', None),
                ('length', raw, 200, M.PACKAGE_URL, '999')):
                build.return_value.open.return_value = response(data, status, url, length)
                with self.subTest(label=label), self.assertRaises(ValueError):
                    M.fetch_package(self.root/(label+'.nupkg'), pin, self.deadline)
        for url in (M.PACKAGE_URL, 'http://api.nuget.org/file', 'https://example.invalid/file'):
            with self.subTest(url=url), self.assertRaisesRegex(ValueError, 'redirects'):
                M.NoRedirect().redirect_request(None, None, 302, '', None, url)
        with self.assertRaisesRegex(ValueError, 'Exact Microsoft'):
            M.fetch_package(self.root/'wrong-url', dict(pin, url='https://example.invalid/file'), self.deadline)

    def prepare_fixture(self):
        pin = package(self.archive, edge='D3DCompiler_43.dll')
        original = M.load_pin()['byond']
        binary = self.root/'original-bin'; binary.mkdir()
        files = {}
        for name in original['files']:
            raw = ('original input '+name).encode(); (binary/name).write_bytes(raw)
            files[name] = dict(bytes=len(raw), sha256=M.sha256(raw))
        pin['byond'] = dict(original, files=files)
        environment = dict(RUNNER_TEMP=str(self.root), D3DX_DATA_PREPARE='approved-data-only', RUNNER_ENVIRONMENT='github-hosted',
                           RUNNER_OS='Windows', GITHUB_REPOSITORY='Civ13/Civ13', GITHUB_EVENT_NAME='workflow_dispatch',
                           GITHUB_SHA='a'*40, GITHUB_WORKFLOW_SHA='a'*40, GITHUB_RUN_ATTEMPT='1')
        return pin, binary, environment

    def test_actual_non_windows_admission_rejects_before_acquisition(self):
        unused_pin, binary, environment = self.prepare_fixture()
        with patch.dict(os.environ, environment), patch.object(
                M, 'os', SimpleNamespace(name='posix', environ=os.environ)), \
                patch.object(M, 'fetch_package') as fetch, patch.object(M.A, 'acquire') as acquire:
            with self.assertRaisesRegex(ValueError, 'hosted Windows'):
                M.prepare('a'*40, binary, self.root/'tree-d3dx-data')
            with self.assertRaisesRegex(ValueError, 'hosted Windows'):
                M.prepare_with_input('a'*40, self.root/'tree-d3dx-data')
            fetch.assert_not_called()
            acquire.assert_not_called()
            self.assertFalse((self.root/'tree-d3dx-data').exists())

    def test_full_preparation_preserves_inputs_and_records_dependency_facts(self):
        pin, binary, environment = self.prepare_fixture()
        def fake_fetch(target, unused_pin, deadline): target.write_bytes(self.archive.read_bytes())
        with patch.dict(os.environ, environment), patch.object(M, 'load_pin', return_value=pin), \
             patch.object(M, 'fetch_package', side_effect=fake_fetch), patch.object(M, 'signature_file', return_value=certificate()) as signature:
            out = self.root/'tree-d3dx-data'; report = M.prepare('a'*40, binary, out)
        self.assertEqual(report['status'], 'completed_data_preparation')
        self.assertEqual(signature.call_count, 2)
        self.assertTrue(report['byond_preserved']); self.assertEqual(report['byond_before'], report['byond_after'])
        self.assertFalse(report['native_ready']); self.assertFalse(report['native_executed']); self.assertFalse(report['software_installed'])
        self.assertEqual(M.census(out), sum(p.stat().st_size for p in out.rglob('*') if p.is_file()))
        self.assertEqual(json.loads((out/'preparation.json').read_text())['status'], report['status'])
        self.assertEqual({p.name for p in binary.iterdir()}, set(pin['byond']['files']))

    def test_failures_retain_trust_and_input_preservation_evidence(self):
        pin, binary, environment = self.prepare_fixture()
        def fake_fetch(target, unused_pin, deadline): target.write_bytes(self.archive.read_bytes())
        invalid = certificate(); invalid['status'] = 'NotTrusted'
        with patch.dict(os.environ, environment), patch.object(M, 'load_pin', return_value=pin), \
             patch.object(M, 'fetch_package', side_effect=fake_fetch), patch.object(M, 'signature_file', return_value=invalid):
            out = self.root/'tree-d3dx-data'; report = M.prepare('a'*40, binary, out)
        self.assertEqual(report['status'], 'failed'); self.assertTrue(report['byond_preserved'])
        self.assertIn('signature', report['error'])
        self.assertEqual(report['staging']['files']['x86/D3DX9_43.dll']['signature']['status'], 'NotTrusted')
        self.assertEqual(json.loads((out/'preparation.json').read_text())['status'], 'failed')

    def test_post_signature_input_or_license_mutation_cannot_pass(self):
        for target in ('byond', 'license'):
            with self.subTest(target=target), tempfile.TemporaryDirectory() as directory:
                previous = self.root
                self.root = Path(directory)
                self.archive = self.root/'synthetic.zip'
                pin, binary, environment = self.prepare_fixture()
                def fake_fetch(path, unused_pin, deadline): path.write_bytes(self.archive.read_bytes())
                def trust(path, deadline):
                    altered = binary/'dd.exe' if target == 'byond' else self.root/'tree-d3dx-data/selected/licenses/LICENSE.txt'
                    altered.write_bytes(b'altered')
                    return certificate()
                with patch.dict(os.environ, environment), patch.object(M, 'load_pin', return_value=pin), \
                     patch.object(M, 'fetch_package', side_effect=fake_fetch), patch.object(M, 'signature_file', side_effect=trust):
                    out = self.root/'tree-d3dx-data'; report = M.prepare('a'*40, binary, out)
                self.assertEqual(report['status'], 'failed')
                self.assertEqual(json.loads((out/'preparation.json').read_text())['status'], 'failed')
                if target == 'byond':
                    self.assertFalse(report['byond_preserved'])
                    self.assertIn('BYOND', report['preservation_error'])
                else:
                    self.assertTrue(report['byond_preserved'])
                    self.assertIn('Selected file changed', report['error'])
                self.root = previous

    def test_original_hash_inventory_and_changed_input_reject(self):
        pin, binary, environment = self.prepare_fixture()
        self.assertEqual(M.byond_snapshot(binary, pin, self.deadline), pin['byond']['files'])
        file = binary/'dd.exe'; raw = file.read_bytes(); file.write_bytes(raw[:-1]+b'X')
        with self.assertRaisesRegex(ValueError, 'hash drift'): M.byond_snapshot(binary, pin, self.deadline)
        file.write_bytes(raw); (binary/'unexpected.dll').write_bytes(b'extra')
        with self.assertRaisesRegex(ValueError, 'inventory'): M.byond_snapshot(binary, pin, self.deadline)

    def test_exclusive_hosted_controller_prepares_input_without_execution(self):
        pin, unused_binary, environment = self.prepare_fixture()
        def acquired(work, byond_pin, **bounds):
            self.assertEqual(bounds, dict(download_seconds=35, extract_seconds=25, read_timeout=10))
            work.mkdir(); binary = work/'bin'; binary.mkdir()
            for name in pin['byond']['files']:
                (binary/name).write_bytes(('original input '+name).encode())
            (work/'bin-path.txt').write_text(str(binary))
            (work/'extract.log').write_bytes(b'data extraction only')
            return pin['byond']
        def fake_fetch(target, unused_pin, deadline): target.write_bytes(self.archive.read_bytes())
        with patch.dict(os.environ, environment), patch.object(M, 'load_pin', return_value=pin), \
             patch.object(M.A, 'acquire', side_effect=acquired) as acquire, \
             patch.object(M, 'fetch_package', side_effect=fake_fetch), patch.object(M, 'signature_file', return_value=certificate()):
            out = self.root/'tree-d3dx-data'; report = M.prepare_with_input('a'*40, out)
        acquire.assert_called_once()
        self.assertEqual(report['status'], 'completed_data_preparation')
        self.assertTrue(report['byond_preserved'])
        self.assertFalse(report['input_preparation']['software_executed'])
        self.assertEqual(report['input_preparation']['toolchain'], pin['byond'])
        self.assertEqual((out/'input-extract.log').read_bytes(), b'data extraction only')
        self.assertFalse(any(p.suffix.lower() in ('.exe', '.bat') for p in out.rglob('*')))
        self.assertLessEqual(M.census(out), 16*1024**2)
        self.assertIn('trust-metadata', report['authorization_scope'])
        self.assertEqual(report['execution']['GITHUB_SHA'], 'a'*40)
        self.assertEqual(report['execution']['GITHUB_RUN_ATTEMPT'], '1')

    def test_input_failure_is_retained_and_cannot_fetch_microsoft(self):
        pin, unused_binary, environment = self.prepare_fixture()
        with patch.dict(os.environ, environment), patch.object(M, 'load_pin', return_value=pin), \
             patch.object(M.A, 'acquire', side_effect=ValueError('pinned input failure')), patch.object(M, 'fetch_package') as fetch:
            out = self.root/'tree-d3dx-data'; report = M.prepare_with_input('a'*40, out)
        fetch.assert_not_called()
        self.assertEqual(report['status'], 'failed')
        self.assertIn('pinned input failure', json.loads((out/'preparation.json').read_text())['error'])
        self.assertFalse(report['native_executed'])

    def test_input_manifest_drift_is_recorded_and_stops_microsoft(self):
        pin, unused_binary, environment = self.prepare_fixture()
        bad = deepcopy(pin['byond']); bad['files']['dd.exe']['sha256'] = '0'*64
        with patch.dict(os.environ, environment), patch.object(M, 'load_pin', return_value=pin), \
             patch.object(M.A, 'acquire', return_value=bad), patch.object(M, 'fetch_package') as fetch:
            report = M.prepare_with_input('a'*40, self.root/'tree-d3dx-data')
        fetch.assert_not_called()
        self.assertEqual(report['status'], 'failed')
        self.assertEqual(report['input_preparation']['toolchain'], bad)

    def test_slow_input_stops_before_package_and_retains_failure(self):
        pin, unused_binary, environment = self.prepare_fixture()
        with patch.dict(os.environ, environment), patch.object(M, 'load_pin', return_value=pin), \
             patch.object(M.A, 'acquire', return_value=pin['byond']), \
             patch.object(M.time, 'monotonic', side_effect=[0,80,80]), patch.object(M, 'fetch_package') as fetch:
            report = M.prepare_with_input('a'*40, self.root/'tree-d3dx-data')
        fetch.assert_not_called()
        self.assertEqual(report['status'], 'failed')
        self.assertIn('reserve', report['error'])
        self.assertTrue((self.root/'tree-d3dx-data/preparation.json').is_file())

    def test_reusable_byond_acquisition_limits_cannot_expand(self):
        for bounds in (dict(download_seconds=121), dict(extract_seconds=91), dict(read_timeout=31), dict(download_seconds=0)):
            with self.subTest(bounds=bounds), patch.dict(os.environ, dict(RUNNER_ENVIRONMENT='github-hosted', RUNNER_OS='Windows')):
                with self.assertRaisesRegex(ValueError, 'only tighten'):
                    M.A.acquire(self.root/'must-not-exist', {}, **bounds)
                self.assertFalse((self.root/'must-not-exist').exists())

    def test_workflow_mode_excludes_native_and_audit_jobs(self):
        workflow = (M.ROOT/'.github/workflows/tree-refresh-native.yml').read_text()
        fixture = workflow.split('  fixture:\n', 1)[1].split('  dependency-audit:\n', 1)[0]
        audit = workflow.split('  dependency-audit:\n', 1)[1].split('  d3dx-data:\n', 1)[0]
        job = workflow.split('  d3dx-data:\n', 1)[1]
        self.assertIn("(inputs.mode == 'prepare' || inputs.mode == 'execute')", fixture)
        self.assertIn("inputs.mode == 'dependency-audit'", audit)
        self.assertIn("inputs.mode == 'd3dx-data'", job)
        self.assertIn('timeout-minutes: 5', job)
        self.assertIn('timeout-minutes: 3', job)
        self.assertIn('GITHUB_WORKFLOW_SHA', job); self.assertIn('git rev-parse HEAD', job)
        self.assertIn("GITHUB_RUN_ATTEMPT -ne '1'", job)
        self.assertIn('--prepare-input', job); self.assertIn('--acquire-data', job)
        self.assertIn('trust-metadata', job); self.assertIn('trust policy stays unchanged', job)
        self.assertIn('path: ${{ runner.temp }}/tree-d3dx-data', job)
        for entrypoint in ('runner.py', 'prepare.py', 'dm.exe', 'dd.exe', 'dreamseeker.exe', 'New-NetFirewallRule'):
            self.assertNotIn(entrypoint, job)
        self.assertNotIn('contents: write', workflow)

    def test_wrong_source_attempt_mode_or_paths_do_not_fetch(self):
        pin, binary, environment = self.prepare_fixture()
        for key, value in (('GITHUB_SHA', 'b'*40), ('GITHUB_RUN_ATTEMPT', '2'),
                           ('GITHUB_EVENT_NAME', 'push'), ('D3DX_DATA_PREPARE', '')):
            with self.subTest(key=key), patch.dict(os.environ, dict(environment, **{key:value})), patch.object(M, 'fetch_package') as fetch:
                with self.assertRaises(ValueError): M.prepare('a'*40, binary, self.root/'tree-d3dx-data')
                fetch.assert_not_called()
        with patch.dict(os.environ, environment), patch.object(M, 'fetch_package') as fetch:
            with self.assertRaises(ValueError): M.prepare('a'*40, binary, binary/'output')
            with self.assertRaises(ValueError): M.prepare('a'*40, binary, self.root/'different-output')
            fetch.assert_not_called()
        out = self.root/'tree-d3dx-data'; out.mkdir()
        with patch.dict(os.environ, environment), patch.object(M, 'fetch_package') as fetch:
            with self.assertRaises(ValueError): M.prepare('a'*40, binary, out)
            fetch.assert_not_called()


if __name__ == '__main__':
    unittest.main()
