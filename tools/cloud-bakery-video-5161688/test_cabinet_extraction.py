"""Offline synthetic cabinet, child-process and failure-evidence tests."""
import hashlib
import json
import os
from pathlib import Path
import struct
import sys
import tempfile
import time
import unittest
import urllib.error
from unittest.mock import patch

import bounded_extractor
import cabinet_slice
import prepare_official_toolchain as prepare


def fixture():
    rows = [{'name': f'file{i}.cab', 'bytes': i+1} for i in range(157)]
    header = bytearray(65536)
    header[:4] = b'MSCF'
    struct.pack_into('<IIIII BB HHHHH', header, 4, 0, 65536, 0, 44, 0, 3, 1, 1, 157, 0, 0, 0)
    struct.pack_into('<IHH', header, 36, 32768, 1, 0)
    pos = 44
    for row in rows:
        struct.pack_into('<IIHHHH', header, pos, row['bytes'], 0, 0, 0, 0, 32)
        name = row['name'].encode() + b'\0'
        header[pos+16:pos+16+len(name)] = name
        pos += 16 + len(name)
    return bytes(header), rows


class CabinetChecks(unittest.TestCase):
    def test_manifest_and_directory_validation(self):
        raw, rows = fixture()
        with patch.object(cabinet_slice, 'CAB_SIZE', len(raw)):
            self.assertEqual(cabinet_slice.validate_directory(raw, rows)['files'], 157)
            changed = bytearray(raw)
            struct.pack_into('<H', changed, 44+14, 16)
            with self.assertRaisesRegex(ValueError, 'cab_unsafe_member'):
                cabinet_slice.validate_directory(changed, rows)
            changed = bytearray(raw)
            changed[44+16:44+19] = b'../'
            with self.assertRaisesRegex(ValueError, 'cab_unsafe_member'):
                cabinet_slice.validate_directory(changed, rows)
            rows[0]['bytes'] += 1
            with self.assertRaisesRegex(ValueError, 'cab_directory_mismatch'):
                cabinet_slice.validate_directory(raw, rows)

    def test_slice_rejects_changed_payload(self):
        cab, rows = fixture()
        outer = b'prefix1234567' + cab + b'trailer'
        manifest = json.dumps(rows).encode()
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root/'outer').write_bytes(outer)
            (root/'manifest').write_bytes(manifest)
            with patch.multiple(cabinet_slice, OUTER_SIZE=len(outer), CAB_OFFSET=13,
                                CAB_SIZE=len(cab), OUTER_SHA=hashlib.sha256(outer).hexdigest(),
                                CAB_SHA=hashlib.sha256(cab).hexdigest(),
                                MANIFEST_SHA=hashlib.sha256(manifest).hexdigest()):
                result = cabinet_slice.write_payload(root/'outer', root/'cab', root/'manifest', lambda: None)
                self.assertEqual(result['files'], 157)
                self.assertEqual((root/'cab').read_bytes(), cab)
                (root/'outer').write_bytes(outer[:-1] + b'x')
                with self.assertRaisesRegex(ValueError, 'cab_outer_hash'):
                    cabinet_slice.write_payload(root/'outer', root/'bad', root/'manifest', lambda: None)
                self.assertFalse((root/'bad').exists())
                with self.assertRaisesRegex(ValueError, 'cab_destination_outside_workspace'):
                    cabinet_slice.write_payload(root/'outer', root/'other'/'bad', root/'manifest', lambda: None)

    def test_no_bypass_for_denied_or_unrecognized_mixed_diagnostics(self):
        self.assertTrue(prepare.is_unsupported_archive(b'tar.exe: Error opening archive: Unrecognized archive format\r\n'))
        self.assertFalse(prepare.is_unsupported_archive(b'tar.exe: Access denied'))
        self.assertFalse(prepare.is_unsupported_archive(b'Access denied\ntar: Error opening archive: Unrecognized archive format'))

    def test_system_receipt_is_bound_and_rechecks_binary_bytes(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            system = root/'windows'/'System32'
            system.mkdir(parents=True)
            binaries = {'tar.exe': b'tar-fixture', 'expand.exe': b'expand-fixture'}
            for name, raw in binaries.items(): (system/name).write_bytes(raw)
            env = {'SystemRoot': str(root/'windows'), 'GITHUB_SHA': 'a'*40,
                   'GITHUB_RUN_ID': '123', 'GITHUB_RUN_ATTEMPT': '1',
                   'GITHUB_JOB': 'bakery', 'GITHUB_REF': 'refs/heads/fixture'}
            binding = {k: env[k] for k in ('GITHUB_SHA','GITHUB_RUN_ID','GITHUB_RUN_ATTEMPT','GITHUB_JOB','GITHUB_REF')}
            files = {name: {'bytes': len(raw), 'sha256': hashlib.sha256(raw).hexdigest(),
                            'signature': 'Valid', 'signer': 'Microsoft Windows'} for name, raw in binaries.items()}
            receipt = {'status': 'PASSED', 'binding': binding, 'files': files}
            (root/'system-extractors.json').write_text(json.dumps(receipt))
            with patch.dict(os.environ, env):
                prepare.verify_system_extractors(root)
                (system/'tar.exe').write_bytes(b'altered')
                with self.assertRaisesRegex(RuntimeError, 'extractor_identity_changed'):
                    prepare.verify_system_extractors(root)
                receipt['binding']['GITHUB_RUN_ID'] = 'other'
                (root/'system-extractors.json').write_text(json.dumps(receipt))
                with self.assertRaisesRegex(RuntimeError, 'extractor_signature_receipt'):
                    prepare.verify_system_extractors(root)

    def test_failure_receipts_preserve_bounded_actionable_fields(self):
        receipt = {}
        prepare.record_failure(receipt, ValueError('file_hash:DXSETUP.exe'))
        self.assertEqual(receipt, {'error': 'file_hash', 'component': 'DXSETUP.exe'})
        receipt = {}
        prepare.record_failure(receipt, urllib.error.HTTPError('https://invalid.example/private', 403, 'denied', {}, None))
        self.assertEqual(receipt, {'error': 'HTTPError', 'http_status': 403})
        self.assertNotIn('private', json.dumps(receipt))
        receipt = {}
        prepare.record_failure(receipt, urllib.error.URLError(OSError('sensitive path')))
        self.assertEqual(receipt, {'error': 'URLError', 'network_reason_class': 'OSError'})


class ChildDiagnostics(unittest.TestCase):
    def test_logs_and_return_code_retained(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            result = bounded_extractor.invoke([sys.executable, '-c',
                "import sys; print('listing'); print('diagnostic', file=sys.stderr); sys.exit(7)"],
                root, None, 'tar-list', time.monotonic()+10)
            self.assertEqual(result['exit_code'], 7)
            self.assertTrue(result['direct_child_exited'])
            self.assertEqual((root/'tar-list.stdout.log').read_bytes().strip(), b'listing')
            self.assertEqual((root/'tar-list.stderr.log').read_bytes().strip(), b'diagnostic')
            self.assertEqual(json.loads((root/'tar-list.json').read_text())['exit_code'], 7)

    def test_oversize_is_distinct_and_bounded(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            result = bounded_extractor.invoke([sys.executable, '-c',
                "import sys; sys.stdout.write('x'*200000); sys.stdout.flush()"],
                root, None, 'tar-list', time.monotonic()+10)
            self.assertTrue(result['stdout_overflow'])
            self.assertTrue(result['direct_child_exited'])
            self.assertLessEqual((root/'tar-list.stdout.log').stat().st_size, bounded_extractor.MAX_OUTPUT)
            self.assertFalse(result['stderr_overflow'])

    def test_timeout_retained(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            result = bounded_extractor.invoke([sys.executable, '-c', 'import time; time.sleep(3)'],
                root, None, 'tar-list', time.monotonic()+0.3)
            self.assertTrue(result['timed_out'])
            self.assertTrue(result['direct_child_exited'])
            self.assertTrue((root/'tar-list.json').exists())


if __name__ == '__main__':
    unittest.main()
