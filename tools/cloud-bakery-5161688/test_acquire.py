"""Offline acquisition tests: synthetic data/mocks only; no package execution.

The real ZIP is optionally read solely as immutable data by one integration test.
No acquire(), public check_dependencies(), downloader process, or Windows API runs.
"""
import ast
import hashlib
import io
import json
from pathlib import Path
import stat
import struct
import subprocess
import tempfile
import unittest
from unittest import mock
import warnings
import zipfile

import acquire as a


def sha(data):
    return hashlib.sha256(data).hexdigest()


def zip_bytes(items, compression=zipfile.ZIP_DEFLATED):
    out = io.BytesIO()
    with warnings.catch_warnings():
        warnings.simplefilter('ignore', UserWarning)
        with zipfile.ZipFile(out, 'w', compression=compression) as z:
            for name, data in items:
                z.writestr(name, data)
    return out.getvalue()


def manifest(name='byond/bin/example.txt', data=b'bounded data'):
    return [{'path': name, 'bytes': len(data), 'sha256': sha(data)}]


def validate(raw, files):
    return a._validate_archive(raw, files, expected_size=len(raw), expected_sha256=sha(raw))


def fake_pe(machine=0x14c, magic=0x10b):
    data = bytearray(512)
    data[:2] = b'MZ'
    struct.pack_into('<I', data, 0x3c, 64)
    data[64:68] = b'PE\0\0'
    struct.pack_into('<H', data, 68, machine)
    struct.pack_into('<H', data, 84, 224)
    struct.pack_into('<H', data, 88, magic)
    return bytes(data)


class ZipValidationTests(unittest.TestCase):
    def test_small_valid_archive(self):
        raw = zip_bytes([('byond/', b''), ('byond/bin/', b''), ('byond/bin/example.txt', b'bounded data')])
        self.assertEqual(validate(raw, manifest()), {'byond/bin/example.txt': b'bounded data'})

    def test_actual_45_file_manifest_is_read_as_data_only(self):
        path = Path(__file__).parent.parent / 'acquisition' / '516.1688_byond.zip'
        if not path.exists():
            self.skipTest('Optional local pinned evidence ZIP not supplied')
        self.assertEqual(len(a._validate_archive(path.read_bytes(), a._vendor()['files'])), 45)

    def test_archive_hash_mismatch_precedes_zip_parse(self):
        with self.assertRaisesRegex(a.PreflightError, 'archive_size_or_hash_mismatch'):
            a._validate_archive(b'bad', [], expected_size=3, expected_sha256='0' * 64)

    def test_invalid_zip_rejected(self):
        with self.assertRaisesRegex(a.PreflightError, 'invalid_zip'):
            validate(b'not a zip', [])

    def test_unsafe_names(self):
        names = ['../escape', '/absolute', 'C:/drive', 'byond\\escape', 'byond/../escape',
                 'byond//double', 'byond/file.', 'byond/file ', 'byond/CON.txt',
                 'byond/NUL', 'byond/COM1', 'byond/non-ascii-\u00e9', 'byond/colon:ads']
        for name in names:
            with self.subTest(name=name), self.assertRaisesRegex(a.PreflightError, 'unsafe_zip_name'):
                validate(zip_bytes([(name, b'x')]), manifest(name, b'x'))

    def test_null_name_rejected_by_name_gate(self):
        with self.assertRaisesRegex(a.PreflightError, 'unsafe_zip_name'):
            a._relative('byond/null\x00suffix')

    def test_duplicate_case_alias_rejected(self):
        raw = zip_bytes([('byond/bin/example.txt', b'bounded data'), ('BYOND/BIN/EXAMPLE.TXT', b'bounded data')])
        with self.assertRaisesRegex(a.PreflightError, 'duplicate_zip_name'):
            validate(raw, manifest())

    def test_duplicate_exact_name_rejected(self):
        raw = zip_bytes([('byond/bin/example.txt', b'bounded data')] * 2)
        with self.assertRaisesRegex(a.PreflightError, 'duplicate_zip_name'):
            validate(raw, manifest())

    def test_symlink_rejected(self):
        info = zipfile.ZipInfo('byond/bin/example.txt')
        info.create_system = 3
        info.external_attr = (stat.S_IFLNK | 0o777) << 16
        with self.assertRaisesRegex(a.PreflightError, 'zip_special_file'):
            validate(zip_bytes([(info, b'bounded data')]), manifest())

    def test_windows_reparse_metadata_rejected(self):
        info = zipfile.ZipInfo('byond/bin/example.txt')
        info.external_attr = ((stat.S_IFREG | 0o600) << 16) | 0x400
        with self.assertRaisesRegex(a.PreflightError, 'zip_special_file'):
            validate(zip_bytes([(info, b'bounded data')]), manifest())

    def test_unexpected_file_and_missing_file_rejected(self):
        with self.assertRaisesRegex(a.PreflightError, 'zip_manifest_membership_or_size'):
            validate(zip_bytes([('byond/bin/unreviewed.txt', b'bounded data')]), manifest())
        with self.assertRaisesRegex(a.PreflightError, 'incomplete_zip_manifest'):
            validate(zip_bytes([]), manifest())

    def test_member_hash_and_size_rejected(self):
        with self.assertRaisesRegex(a.PreflightError, 'zip_member_hash_mismatch'):
            validate(zip_bytes([('byond/bin/example.txt', b'altered data')]), manifest())
        with self.assertRaisesRegex(a.PreflightError, 'zip_manifest_membership_or_size'):
            validate(zip_bytes([('byond/bin/example.txt', b'wrong size')]), manifest())

    def test_compression_bomb_ratio_rejected(self):
        data = b'0' * (2 * 1024 * 1024)
        with self.assertRaisesRegex(a.PreflightError, 'zip_expansion_limit'):
            validate(zip_bytes([('byond/bin/example.txt', data)]), manifest(data=data))

    def test_entry_count_bound(self):
        raw = zip_bytes([(f'byond/f{i}.txt', b'') for i in range(a.MAX_ENTRIES + 1)])
        with self.assertRaisesRegex(a.PreflightError, 'zip_entry_limit'):
            validate(raw, [])

    def test_manifest_digest_is_bound(self):
        self.assertEqual(len(a._vendor()['files']), 45)
        with mock.patch.object(a, 'VENDOR_SHA256', '0' * 64):
            with self.assertRaisesRegex(a.PreflightError, 'vendor_manifest_hash_mismatch'):
                a._vendor()


class DependencyTests(unittest.TestCase):
    def test_x86_header_passes(self):
        self.assertEqual(a._pe_x86(fake_pe())['machine'], '0x014c')

    def test_x64_and_malformed_headers_fail(self):
        for data in (fake_pe(0x8664, 0x20b), b'', b'MZ', b'not-pe' * 80):
            with self.subTest(length=len(data)), self.assertRaises(a.PreflightError):
                a._pe_x86(data)
        data = bytearray(fake_pe())
        struct.pack_into('<I', data, 0x3c, 0xffffffff)
        with self.assertRaisesRegex(a.PreflightError, 'dependency_not_pe'):
            a._pe_x86(data)

    def test_client_closure_does_not_invent_mfc120_or_vcruntime140_1(self):
        vendor = a._vendor()
        verified = {Path(name).name.lower(): value for name, value in vendor['binaries'].items()}
        selected, regular, delayed, api_sets = a._static_needs(verified)
        self.assertTrue({'mfc140u.dll', 'vcruntime140.dll', 'msvcp140.dll', 'd3dx9_43.dll', 'ucrtbase.dll'} <= regular)
        self.assertFalse({'mfc120u.dll', 'vcruntime140_1.dll', 'mfc140.dll'} & regular)
        self.assertIn('fmodex.dll', selected)
        self.assertIn('steam_api.dll', delayed)
        self.assertTrue(api_sets)
        self.assertNotIn('dreamdeploy.exe', selected)

    def test_static_roots_match_controller_launch_executables(self):
        controller = Path(__file__).with_name('run_scene.py')
        if not controller.exists():
            self.skipTest('Controller source not supplied')
        tree = ast.parse(controller.read_text())
        launches = {node.args[1].value for node in ast.walk(tree)
                    if isinstance(node, ast.Call) and isinstance(node.func, ast.Name)
                    and node.func.id == 'launch' and len(node.args) >= 2
                    and isinstance(node.args[1], ast.Constant)}
        vendor = a._vendor()
        verified = {Path(name).name.lower(): value for name, value in vendor['binaries'].items()}
        selected, regular, _, _ = a._static_needs(verified)
        self.assertEqual(launches, {'dm.exe', 'dd.exe', 'dreamseeker.exe'})
        self.assertEqual({name for name in selected if name.endswith('.exe')}, launches)
        self.assertIn('dbghelp.dll', regular)

    def test_missing_vc_stops_before_cab_extraction(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / 'System32').mkdir()
            with mock.patch.object(a, '_vendor', return_value={}), \
                 mock.patch.object(a, '_verified_package', return_value=(root, {})), \
                 mock.patch.object(a, '_static_needs', return_value=(set(), {'mfc140u.dll', a.D3DX_NAME}, set(), set())), \
                 mock.patch.object(a, '_extract_d3dx') as extraction:
                with self.assertRaises(a.PreflightError) as result:
                    a._check_dependencies(root / 'byond' / 'bin', root, allow_cab_extraction=True)
                self.assertEqual(result.exception.details, ('mfc140u.dll',))
                extraction.assert_not_called()

    def test_x64_system_dll_rejected_even_when_present(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / 'SysWOW64').mkdir()
            (root / 'SysWOW64' / 'mfc140u.dll').write_bytes(fake_pe(0x8664, 0x20b))
            with mock.patch.object(a, '_vendor', return_value={}), \
                 mock.patch.object(a, '_verified_package', return_value=(root, {})), \
                 mock.patch.object(a, '_static_needs', return_value=(set(), {'mfc140u.dll'}, set(), set())):
                with self.assertRaisesRegex(a.PreflightError, 'dependency_not_x86_pe32: mfc140u.dll'):
                    a._check_dependencies(root / 'byond' / 'bin', root, allow_cab_extraction=False)

    def test_static_receipt_disclaims_runtime_and_omits_absolute_paths(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / 'SysWOW64').mkdir()
            (root / 'SysWOW64' / 'kernel32.dll').write_bytes(fake_pe())
            with mock.patch.object(a, '_vendor', return_value={}), \
                 mock.patch.object(a, '_verified_package', return_value=(root, {})), \
                 mock.patch.object(a, '_static_needs', return_value=(set(), {'kernel32.dll'}, {'steam_api.dll'}, {'api-ms-win-crt-runtime-l1-1-0.dll'})):
                receipt = a._check_dependencies(root / 'byond' / 'bin', root, allow_cab_extraction=False)
                self.assertEqual(receipt['runtime_validation'], 'not_performed')
                self.assertEqual(receipt['unresolved_delay_imports'], ['steam_api.dll'])
                self.assertNotIn(folder, json.dumps(receipt))
                self.assertFalse(receipt['package_code_executed'])

    def test_non_windows_public_gate_has_no_probe(self):
        with mock.patch.object(a.os, 'name', 'posix'):
            with self.assertRaisesRegex(a.PreflightError, 'windows_dependency_check_required'):
                a._windows_root()


    def test_failure_receipt_contains_exact_blocker_without_paths(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            failure = {'schema': 1, 'status': 'blocked',
                       'error': 'missing_x86_dependencies_no_install_attempted',
                       'details': ['mfc140u.dll'], 'package_code_executed': False}
            a._write_dependency_receipt(root / 'byond' / 'bin', failure)
            stored = json.loads((root / 'dependency-receipt.json').read_text())
            self.assertEqual(stored['details'], ['mfc140u.dll'])
            self.assertNotIn(folder, json.dumps(stored))
            with self.assertRaisesRegex(a.PreflightError, 'dependency_receipt_write_failed'):
                a._write_dependency_receipt(root / 'byond' / 'bin', failure)


class AcquisitionFailureReceiptTests(unittest.TestCase):
    def test_failure_receipt_is_bounded_exclusive_and_has_concrete_error(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            error = a.PreflightError('archive_size_or_hash_mismatch', ('byond/bin/dm.exe',))
            a._write_acquisition_failure(root, error)
            path = root / 'acquisition-failure.json'
            original = path.read_bytes()
            self.assertLessEqual(len(original), 8192)
            receipt = json.loads(original)
            self.assertEqual(receipt['error'], 'archive_size_or_hash_mismatch')
            self.assertEqual(receipt['details'], ['byond/bin/dm.exe'])
            self.assertNotIn(folder, original.decode())
            with self.assertRaisesRegex(a.PreflightError, 'failure_receipt_write_failed'):
                a._write_acquisition_failure(root, error)
            self.assertEqual(path.read_bytes(), original)

    def test_failure_receipt_rejects_relative_root_and_strips_path_details(self):
        with self.assertRaisesRegex(a.PreflightError, 'failure_receipt_root_not_absolute'):
            a._write_acquisition_failure(Path('relative'), a.PreflightError('blocked'))
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            with self.assertRaisesRegex(a.PreflightError, 'failure_receipt_root_not_canonical'):
                a._write_acquisition_failure(root / '..', a.PreflightError('blocked'))
            error = a.PreflightError('blocked', ('/private/user/path', '../escape',
                'C:\\Users\\private', 'line\nbreak', 'mfc140u.dll'))
            a._write_acquisition_failure(root, error)
            receipt = json.loads((root / 'acquisition-failure.json').read_bytes())
            self.assertEqual(receipt['details'], ['mfc140u.dll'])

    def test_failure_receipt_rejects_symlink_root(self):
        with tempfile.TemporaryDirectory() as folder:
            base = Path(folder)
            actual = base / 'actual'
            actual.mkdir()
            linked = base / 'linked'
            try:
                linked.symlink_to(actual, target_is_directory=True)
            except OSError:
                self.skipTest('Test environment cannot create symlinks')
            with self.assertRaisesRegex(a.PreflightError, 'non_plain_path'):
                a._write_acquisition_failure(linked, a.PreflightError('blocked'))
            self.assertFalse((actual / 'acquisition-failure.json').exists())


class ProcessAndTransportTests(unittest.TestCase):
    def test_process_timeout_kills_and_reaps_retained_handle(self):
        process = mock.Mock()
        process.wait.side_effect = [subprocess.TimeoutExpired('mock', 10), 0]
        process.poll.return_value = 0
        with mock.patch.object(a.subprocess, 'Popen', return_value=process) as launch:
            with self.assertRaisesRegex(a.PreflightError, 'cab_expand_timeout'):
                a._run_bounded(['installed-expand-placeholder'], '.', 10, 'cab_expand')
        process.kill.assert_called_once()
        self.assertEqual(process.wait.call_count, 2)
        self.assertFalse(launch.call_args.kwargs['shell'])
        self.assertEqual(launch.call_args.kwargs['stdout'], subprocess.DEVNULL)

    def test_environment_does_not_copy_unrelated_secrets(self):
        with mock.patch.dict(a.os.environ, {'UNRELATED_SECRET': 'not-copy-me', 'HTTPS_PROXY': 'http://proxy.example:8080'}, clear=True):
            self.assertEqual(a._minimal_environment(), {'HTTPS_PROXY': 'http://proxy.example:8080'})

    def test_redirects_are_refused(self):
        with self.assertRaisesRegex(a.PreflightError, 'download_redirect_refused'):
            a._NoRedirect().redirect_request(None, None, 302, None, None, 'https://different.example/')

    def test_authenticated_proxy_stops_before_request(self):
        with mock.patch.object(a.urllib.request, 'getproxies', return_value={'https': 'http://u:p@proxy.example'}), \
             mock.patch.object(a.urllib.request, 'build_opener') as opener:
            with self.assertRaisesRegex(a.PreflightError, 'authenticated_proxy_not_authorized'):
                a._download_child('must-not-be-created')
            opener.assert_not_called()

    def test_oversize_response_is_refused_before_destination_created(self):
        response = mock.MagicMock()
        response.__enter__.return_value = response
        response.status = 200
        response.geturl.return_value = a.ARCHIVE_URL
        response.headers = {'Content-Length': str(a.ARCHIVE_BYTES + 1)}
        opener = mock.Mock()
        opener.open.return_value = response
        with tempfile.TemporaryDirectory() as folder, \
             mock.patch.object(a.urllib.request, 'getproxies', return_value={}), \
             mock.patch.object(a.urllib.request, 'build_opener', return_value=opener):
            target = Path(folder) / 'not-created.zip'
            with self.assertRaisesRegex(a.PreflightError, 'download_length_refused'):
                a._download_child(target)
            self.assertFalse(target.exists())
            self.assertEqual(opener.open.call_count, 1)


if __name__ == '__main__':
    unittest.main()
