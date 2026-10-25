"""Offline backend helper/gate tests; never activate the proposed controller."""
import ast
import hashlib
import io
import tempfile
import unittest
import zipfile
from pathlib import Path
from unittest.mock import patch
from audit_offline import install
install()
import backend_proposal as backend


class BackendTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def test_entrypoint_default_gated_before_effects(self):
        with patch.object(backend, 'safe_root', side_effect=AssertionError('IO reached')):
            with self.assertRaisesRegex(RuntimeError, 'Native activation blocked'):
                backend.run_native(None, None, None, None, None, None)
        tree = ast.parse(Path(backend.__file__).read_text())
        node = next(n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == 'run_native')
        self.assertEqual(ast.unparse(node.body[1]), 'activation_gate(reviewed_native)')

    def test_owned_controller_remains_exact(self):
        self.assertEqual(backend.controller_hashes()['owned_process_1688.py'], backend.OWNED_CONTROLLER)

    def test_inputs_and_tamper(self):
        rows = {}
        backend.write_input(self.root, 'nested/input.dm', b'abc', rows)
        backend.verify_inputs(self.root, rows)
        self.assertEqual(backend.output_inventory(self.root, rows)['extra_files'], 0)
        (self.root / 'nested/input.dm').write_bytes(b'xyz')
        with self.assertRaisesRegex(ValueError, 'Phase input changed'):
            backend.verify_inputs(self.root, rows)

    def test_private_home_metadata_only(self):
        home = self.root / 'home/.byond'
        home.mkdir(parents=True)
        (home / 'cache').write_bytes(b'not read')
        with patch.object(backend, 'bounded_file', side_effect=AssertionError('HOME content read')):
            self.assertEqual(backend.private_home_inventory(self.root),
                             {'files': 1, 'bytes': 8, 'directories': 1})

    def test_output_symlink_rejected(self):
        (self.root / 'data').write_bytes(b'x')
        (self.root / 'alias').symlink_to(self.root / 'data')
        with self.assertRaises(ValueError):
            backend.aggregate_inventory(self.root)
        with self.assertRaises(ValueError):
            backend.output_inventory(self.root, {})

    def test_aggregate_cap(self):
        (self.root / 'data').write_bytes(b'1234')
        self.assertEqual(backend.aggregate_inventory(self.root), {'bytes': 4, 'files': 1})
        with patch.dict(backend.OUTPUT_LIMITS, aggregate_evidence_bytes=3):
            with self.assertRaisesRegex(ValueError, 'Aggregate evidence bound'):
                backend.aggregate_inventory(self.root)

    def test_every_auxiliary_log_scanned(self):
        (self.root / 'unexpected.log').write_text('runtime error: hidden failure')
        with self.assertRaisesRegex(ValueError, 'Fatal native diagnostic'):
            backend.auxiliary_logs(self.root, {})

    def test_auxiliary_excludes_input_and_private_home(self):
        (self.root / 'source.log').write_text('runtime error: historical source input')
        home = self.root / 'home/.byond'
        home.mkdir(parents=True)
        (home / 'private.log').write_text('runtime error: private data')
        (self.root / 'process.log').write_text('bounded normal log')
        self.assertEqual(backend.auxiliary_logs(self.root, {'source.log': {}}),
                         {'process.log': 'bounded normal log'})

    def name_fixture(self):
        source = self.root / 'source'
        work = self.root / 'runtime'
        work.mkdir()
        files = {'code/names.dm': b'var/list/n = file2list ("config/names/first.txt")',
                 'config/names/first.txt': b'Alice\n', 'config/names/extra.txt': b'Bob\n'}
        manifest = {}
        for name, data in files.items():
            target = source / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
            manifest[name] = {'size': len(data), 'sha256': hashlib.sha256(data).hexdigest()}
        return source, work, manifest

    def test_runtime_names_manifest_bound_and_immutable(self):
        source, work, manifest = self.name_fixture()
        (source / 'config/names/unmanifested.txt').write_text('must not copy')
        inputs = {}
        names = backend.stage_runtime_names(source, manifest, work, inputs)
        self.assertEqual(set(names), {'config/names/first.txt', 'config/names/extra.txt'})
        self.assertFalse((work / 'config/names/unmanifested.txt').exists())
        backend.verify_inputs(work, inputs)
        (work / 'config/names/first.txt').write_bytes(b'Other\n')
        with self.assertRaisesRegex(ValueError, 'Phase input changed'):
            backend.verify_inputs(work, inputs)

    def test_runtime_names_missing_required_manifest_member(self):
        source, work, manifest = self.name_fixture()
        del manifest['config/names/first.txt']
        with self.assertRaisesRegex(ValueError, 'absent from candidate'):
            backend.stage_runtime_names(source, manifest, work, {})

    def test_runtime_names_source_tamper(self):
        source, work, manifest = self.name_fixture()
        (source / 'config/names/first.txt').write_bytes(b'Other\n')
        with self.assertRaisesRegex(ValueError, 'differs from candidate'):
            backend.stage_runtime_names(source, manifest, work, {})

    def test_runtime_names_declaration_tamper(self):
        source, work, manifest = self.name_fixture()
        (source / 'code/names.dm').write_text('changed')
        with self.assertRaisesRegex(ValueError, 'declarations differ'):
            backend.stage_runtime_names(source, manifest, work, {})

    def test_runtime_names_source_link_rejected(self):
        source, work, manifest = self.name_fixture()
        target = source / 'config/names/first.txt'
        target.unlink()
        target.symlink_to(source / 'config/names/extra.txt')
        with self.assertRaisesRegex(ValueError, 'Linked file'):
            backend.stage_runtime_names(source, manifest, work, {})

    def test_daemon_branch_always_stages_names(self):
        tree = ast.parse(Path(backend.__file__).read_text())
        node = next(n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == 'run_native')
        branches = [n for n in ast.walk(node) if isinstance(n, ast.If) and ast.unparse(n.test) == "role == 'compiler'"]
        staging = [n for n in branches if any(isinstance(x, ast.Expr) and isinstance(x.value, ast.Call)
                   and ast.unparse(x.value.func) == 'stage_runtime_names' for x in n.orelse)]
        self.assertEqual(len(staging), 1)
        text = '\n'.join(ast.unparse(x) for x in staging[0].orelse)
        self.assertLess(text.index('stage_runtime_names'), text.index("binary / 'DreamDaemon'"))


    def archive(self):
        buffer = io.BytesIO()
        with zipfile.ZipFile(buffer, 'w') as archive:
            for name in backend.MEMBERS:
                archive.writestr('byond/bin/' + name, name.encode())
                (self.root / name).write_bytes(name.encode())
        data = buffer.getvalue()
        path = self.root / 'archive.zip'
        path.write_bytes(data)
        return path, hashlib.sha256(data).hexdigest()

    def test_archive_and_members_exact(self):
        path, expected = self.archive()
        with patch.object(backend, 'ARCHIVE', expected):
            self.assertEqual(set(backend.binaries(self.root, path)), set(backend.MEMBERS))
            (self.root / 'DreamMaker').write_bytes(b'tamper')
            with self.assertRaisesRegex(ValueError, 'Runtime member bytes differ'):
                backend.binaries(self.root, path)

    def test_archive_link_rejected(self):
        path, expected = self.archive()
        link = self.root / 'linked.zip'
        link.symlink_to(path)
        with patch.object(backend, 'ARCHIVE', expected):
            with self.assertRaisesRegex(ValueError, 'Linked file'):
                backend.binaries(self.root, link)

    def test_archive_hardlink_rejected(self):
        path, expected = self.archive()
        (self.root / 'hard.zip').hardlink_to(path)
        with patch.object(backend, 'ARCHIVE', expected):
            with self.assertRaisesRegex(ValueError, 'hardlinked'):
                backend.binaries(self.root, path)

    def test_unreviewed_archive_rejected(self):
        path, _ = self.archive()
        with self.assertRaisesRegex(ValueError, 'Unreviewed BYOND archive'):
            backend.binaries(self.root, path)


if __name__ == '__main__':
    unittest.main()
