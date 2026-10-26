"""Offline runtime/archive identity controls. No executable, network or extraction."""
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import stat
import tempfile
import unittest
from unittest.mock import patch
import warnings
import zipfile

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('tested_byond_runtime', ROOT / 'scripts/byond_runtime.py')
runtime = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runtime)


class RuntimeIdentityTests(unittest.TestCase):
    def setUp(self):
        self.root = Path(self.enterContext(tempfile.TemporaryDirectory(prefix='byond-runtime-offline-'))).resolve()
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        self.archive = self.root / 'pinned.zip'
        self.bodies = {name: ('offline member ' + name).encode() for name in runtime.MEMBERS}
        for name, body in self.bodies.items():
            (self.bin / name).write_bytes(body)
        self.metadata = {'version': '516.1688', 'linux': {}}
        self.enterContext(patch.object(runtime.pin, 'load', side_effect=lambda: self.metadata))
        self.make_archive()

    def make_archive(self, omit=None, duplicate=None, link=None):
        output = io.BytesIO()
        with warnings.catch_warnings(), zipfile.ZipFile(output, 'w') as package:
            warnings.simplefilter('ignore', UserWarning)
            for name, body in self.bodies.items():
                if name == omit:
                    continue
                entry = zipfile.ZipInfo('byond/bin/' + name)
                entry.create_system = 3
                entry.external_attr = ((stat.S_IFLNK if name == link else stat.S_IFREG) | 0o755) << 16
                package.writestr(entry, body)
                if name == duplicate:
                    package.writestr(entry, body)
        self.set_archive(output.getvalue())

    def set_archive(self, data):
        self.archive.write_bytes(data)
        self.metadata['linux'] = {'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()}

    def verify(self):
        return runtime.verify_linux(self.bin, self.archive)

    def test_exact_members_return_version_bound_passive_evidence(self):
        result = self.verify()
        self.assertEqual(result['version'], '516.1688')
        self.assertEqual(result['platform'], 'linux')
        self.assertEqual(result['identity_basis'], 'exact-member-match-to-pinned-linux-archive')
        self.assertEqual(result['archive'], self.metadata['linux'])
        self.assertEqual(result['members'], {name: {'sha256': hashlib.sha256(body).hexdigest(), 'bytes': len(body)}
                                              for name, body in self.bodies.items()})

    def test_wrong_archive_hash_or_size_refused_before_zip_open(self):
        for field, value in [('sha256', '0' * 64), ('bytes', self.archive.stat().st_size + 1)]:
            with self.subTest(field=field), patch.dict(self.metadata['linux'], {field: value}), \
                    patch.object(runtime.zipfile, 'ZipFile', side_effect=AssertionError('Unexpected ZIP open')):
                with self.assertRaises(ValueError):
                    self.verify()

    def test_missing_wrong_or_truncated_installed_members_refused(self):
        for name, body in self.bodies.items():
            for mode in ('missing', 'wrong', 'short'):
                with self.subTest(name=name, mode=mode):
                    target = self.bin / name
                    target.unlink()
                    if mode != 'missing':
                        target.write_bytes(b'X' * len(body) if mode == 'wrong' else body[:-1])
                    with self.assertRaises((ValueError, OSError)):
                        self.verify()
                    target.write_bytes(body)

    def test_missing_duplicate_or_symlink_archive_member_refused(self):
        for name in runtime.MEMBERS:
            for defect in ('omit', 'duplicate', 'link'):
                with self.subTest(name=name, defect=defect):
                    self.make_archive(**{defect: name})
                    with self.assertRaises(ValueError):
                        self.verify()

    def test_oversized_member_refused_before_read(self):
        with patch.object(runtime, 'MAX_MEMBER_BYTES', 1), self.assertRaises(ValueError):
            self.verify()

    def test_directory_in_place_of_archive_or_member_refused(self):
        for path in (self.archive, self.bin / 'DreamDaemon'):
            original = path.read_bytes()
            path.unlink()
            path.mkdir()
            with self.subTest(path=path), self.assertRaises(ValueError):
                self.verify()
            path.rmdir()
            path.write_bytes(original)

    @unittest.skipIf(os.name == 'nt', 'Symlink creation requires separate Windows privilege')
    def test_symlink_leaf_and_ancestor_paths_refused(self):
        for path in (self.archive, self.bin / 'DreamDaemon'):
            original = path.with_name(path.name + '.original')
            path.rename(original)
            path.symlink_to(original)
            with self.subTest(path=path), self.assertRaises(ValueError):
                self.verify()
            path.unlink()
            original.rename(path)
        linked = self.root / 'linked-bin'
        linked.symlink_to(self.bin, target_is_directory=True)
        with self.assertRaises(ValueError):
            runtime.verify_linux(linked, self.archive)
        ancestor = self.root / 'linked-root'
        ancestor.symlink_to(self.root, target_is_directory=True)
        with self.assertRaises(ValueError):
            runtime.verify_linux(ancestor / 'bin', self.archive)
        with self.assertRaises(ValueError):
            runtime.verify_linux(self.bin, ancestor / 'pinned.zip')

    def test_parent_traversal_refused(self):
        with self.assertRaises(ValueError):
            runtime.verify_linux(self.bin, self.root / 'bin/../pinned.zip')

    def test_malformed_reviewed_archive_refused(self):
        self.set_archive(b'not a zip even if its bytes were pinned')
        with self.assertRaises(zipfile.BadZipFile):
            self.verify()

    def test_installed_change_after_success_is_not_cached(self):
        self.verify()
        (self.bin / 'DreamDaemon').write_bytes(b'X' * len(self.bodies['DreamDaemon']))
        with self.assertRaises(ValueError):
            self.verify()

    @unittest.skipUnless(hasattr(os, 'mkfifo'), 'Requires POSIX FIFO support')
    def test_fifo_member_is_rejected_without_opening(self):
        path = self.bin / 'DreamDaemon'
        path.unlink()
        os.mkfifo(path)
        with self.assertRaises(ValueError):
            self.verify()

    def test_cli_emits_only_verified_json_evidence(self):
        with patch('sys.stdout', new_callable=io.StringIO) as output:
            runtime.main(['--byond-bin', str(self.bin), '--byond-archive', str(self.archive)])
        self.assertEqual(json.loads(output.getvalue()), self.verify())

    def test_cli_help_and_missing_inputs_do_not_verify_or_read_runtime(self):
        for arguments, expected_code in [(['--help'], 0), ([], 2), (['--unknown'], 2)]:
            with self.subTest(arguments=arguments), patch.object(runtime, 'verify_linux') as verify, \
                    patch('sys.stdout', new_callable=io.StringIO), patch('sys.stderr', new_callable=io.StringIO):
                with self.assertRaises(SystemExit) as result:
                    runtime.main(arguments)
                self.assertEqual(result.exception.code, expected_code)
                verify.assert_not_called()


if __name__ == '__main__':
    unittest.main()
