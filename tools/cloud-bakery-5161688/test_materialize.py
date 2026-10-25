"""Offline raw-Git materialization regressions, using an owned synthetic repository.

No BYOND executable, network, checkout, download, or published repository is used.
The archive negative control deliberately demonstrates Git's CRLF conversion; it
must not be replaced with an in-memory archive made from already-correct bytes.
"""
import hashlib
import io
import os
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile
import unittest
from unittest import mock
import zlib

import materialize


@unittest.skipUnless(shutil.which('git'), 'Git is required for actual-object regression tests')
class RawGitMaterializationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='raw-git-materialization-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.repository = self.root / 'synthetic.git'
        # Isolate test Git from user/system configuration. These environment
        # overrides and the local config below affect this owned fixture only.
        config = {
            'GIT_CONFIG_NOSYSTEM': '1',
            'GIT_CONFIG_SYSTEM': os.devnull,
            'GIT_CONFIG_GLOBAL': os.devnull,
            'GIT_CONFIG_COUNT': '0',
            'GIT_AUTHOR_NAME': 'Offline Fixture',
            'GIT_AUTHOR_EMAIL': 'fixture@example.invalid',
            'GIT_COMMITTER_NAME': 'Offline Fixture',
            'GIT_COMMITTER_EMAIL': 'fixture@example.invalid',
        }
        self.environment = mock.patch.dict(os.environ, config)
        self.environment.start()
        self.addCleanup(self.environment.stop)
        subprocess.run(
            ['git', 'init', '--bare', '--quiet', '--object-format=sha1', str(self.repository)],
            check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        )
        self.git('config', '--local', 'core.autocrlf', 'true')
        self.payloads = {
            'tools/demo/lf.txt': b'alpha\nbeta\n',
            'tools/demo/crlf.txt': b'original\r\nCRLF\r\n',
            'tools/demo/no-final-newline.txt': b'no final newline',
            'tools/demo/empty.txt': b'',
            'tools/demo/binary.bin': b'\x00\xff\r\n\n0123456789 blob 12\n\x00tail',
            'tools/demo/name with spaces.txt': b'spaced filename\n',
            'outside/not-selected.txt': b'must not be exported\n',
        }
        self.ids = {name: self.blob(data) for name, data in self.payloads.items()}
        self.tree = self.tree_for(self.ids)
        self.commit = self.git('commit-tree', self.tree, input=b'Synthetic offline fixture\n').decode().strip()
        self.destination = self.root / 'output'

    def git(self, *arguments, input=None):
        return subprocess.run(
            ['git', '-C', str(self.repository), *arguments],
            input=input, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        ).stdout

    def blob(self, payload):
        oid = self.git('hash-object', '-w', '--stdin', input=payload).decode().strip()
        # Independent oracle for Git's canonical blob object identifier.
        self.assertEqual(oid, hashlib.sha1(b'blob ' + str(len(payload)).encode('ascii') + b'\0' + payload).hexdigest())
        return oid

    def raw_tree(self, entries):
        """Build actual Git trees, including unusual names rejected by checkout."""
        body = b''.join(
            mode.encode('ascii') + b' ' + kind.encode('ascii') + b' ' + oid.encode('ascii')
            + b'\t' + name.encode('utf-8') + b'\0'
            for mode, kind, oid, name in entries
        )
        return self.git('mktree', '-z', '--missing', input=body).decode().strip()

    def tree_for(self, entries):
        nested = {}
        for name, oid in entries.items():
            node = nested
            parts = name.split('/')
            for part in parts[:-1]:
                node = node.setdefault(part, {})
            node[parts[-1]] = oid

        def build(node):
            result = []
            for name, value in sorted(node.items()):
                if isinstance(value, dict):
                    result.append(('040000', 'tree', build(value), name))
                else:
                    result.append(('100644', 'blob', value, name))
            return self.raw_tree(result)

        return build(nested)

    def export(self, *, revision=None, paths=None, expected=None, destination=None):
        return materialize.export_blobs(
            self.repository,
            revision or self.commit,
            destination or self.destination,
            ['tools/demo'] if paths is None else paths,
            expected=expected,
        )

    def assert_rejected(self, **kwargs):
        with self.assertRaises((ValueError, RuntimeError, OSError, subprocess.SubprocessError)):
            self.export(**kwargs)

    def assert_exact_output(self, selected, result):
        actual = {
            path.relative_to(self.destination).as_posix(): path.read_bytes()
            for path in self.destination.rglob('*') if path.is_file()
        }
        self.assertEqual(actual, selected)
        self.assertEqual(result['count'], len(selected))
        self.assertEqual(result['bytes'], sum(map(len, selected.values())))

    def test_actual_git_archive_changes_lf_but_raw_export_does_not(self):
        archive = self.git('-c', 'core.autocrlf=true', 'archive', '--format=tar', self.commit, 'tools/demo/lf.txt')
        with tarfile.open(fileobj=io.BytesIO(archive), mode='r:') as source:
            archived = source.extractfile('tools/demo/lf.txt').read()
        original = self.payloads['tools/demo/lf.txt']
        self.assertEqual(archived, original.replace(b'\n', b'\r\n'))
        self.assertNotEqual(archived, original, 'Negative control must observe actual Git conversion')
        result = self.export(paths=['tools/demo/lf.txt'])
        self.assert_exact_output({'tools/demo/lf.txt': original}, result)

    def test_binary_batch_framing_empty_blobs_and_original_line_endings(self):
        selected = {name: data for name, data in self.payloads.items() if name.startswith('tools/demo/')}
        expected = {name: self.ids[name] for name in selected}
        self.assert_exact_output(selected, self.export(expected=expected))
        self.assertEqual((self.destination / 'tools/demo/crlf.txt').read_bytes(), b'original\r\nCRLF\r\n')

    def test_exact_tree_id_is_accepted_for_offline_fixture(self):
        selected = {'tools/demo/lf.txt': self.payloads['tools/demo/lf.txt']}
        self.assert_exact_output(selected, self.export(revision=self.tree, paths=list(selected)))

    def test_disjoint_file_selection_preserves_repository_relative_paths(self):
        names = ['tools/demo/lf.txt', 'outside/not-selected.txt']
        selected = {name: self.payloads[name] for name in names}
        self.assert_exact_output(selected, self.export(paths=names, expected={name: self.ids[name] for name in names}))

    def test_executable_regular_blob_is_allowed(self):
        oid = self.blob(b'#!/bin/sh\nexit 0\n')
        tree = self.raw_tree([('100755', 'blob', oid, 'script.sh')])
        self.assert_exact_output({'script.sh': b'#!/bin/sh\nexit 0\n'}, self.export(revision=tree, paths=['script.sh']))

    def test_expected_blob_mismatch_is_rejected(self):
        self.assert_rejected(paths=['tools/demo/lf.txt'], expected={'tools/demo/lf.txt': self.ids['tools/demo/crlf.txt']})

    def test_expected_mapping_cannot_omit_a_selected_blob(self):
        self.assert_rejected(expected={'tools/demo/lf.txt': self.ids['tools/demo/lf.txt']})

    def test_expected_mapping_cannot_add_an_unselected_blob(self):
        self.assert_rejected(paths=['tools/demo/lf.txt'], expected={
            'tools/demo/lf.txt': self.ids['tools/demo/lf.txt'],
            'outside/not-selected.txt': self.ids['outside/not-selected.txt'],
        })

    def test_empty_expected_mapping_is_not_treated_as_no_pin(self):
        self.assert_rejected(paths=['tools/demo/lf.txt'], expected={})

    def test_existing_destination_is_rejected_without_touching_it(self):
        self.destination.mkdir()
        marker = self.destination / 'do-not-touch.txt'
        marker.write_bytes(b'unchanged\r\n')
        self.assert_rejected()
        self.assertEqual(marker.read_bytes(), b'unchanged\r\n')
        self.assertEqual(list(self.destination.iterdir()), [marker])

    def test_existing_empty_destination_is_also_rejected(self):
        self.destination.mkdir()
        self.assert_rejected()
        self.assertEqual(list(self.destination.iterdir()), [])

    def test_symlink_blob_mode_is_rejected(self):
        tree = self.raw_tree([('120000', 'blob', self.blob(b'../../escape'), 'link')])
        self.assert_rejected(revision=tree, paths=['link'])
        self.assertFalse((self.root / 'escape').exists())

    def test_gitlink_mode_is_rejected(self):
        tree = self.raw_tree([('160000', 'commit', self.commit, 'submodule')])
        self.assert_rejected(revision=tree, paths=['submodule'])

    def test_case_aliased_files_are_rejected_even_on_case_sensitive_host(self):
        tree = self.raw_tree([
            ('100644', 'blob', self.ids['tools/demo/lf.txt'], 'Fixture.dm'),
            ('100644', 'blob', self.ids['tools/demo/crlf.txt'], 'fixture.dm'),
        ])
        self.assert_rejected(revision=tree, paths=['Fixture.dm', 'fixture.dm'])

    def test_case_aliased_parent_directories_are_rejected(self):
        tree = self.tree_for({
            'Code/first.dm': self.ids['tools/demo/lf.txt'],
            'code/second.dm': self.ids['tools/demo/crlf.txt'],
        })
        self.assert_rejected(revision=tree, paths=['Code', 'code'])

    def test_file_directory_case_alias_is_rejected(self):
        tree = self.tree_for({
            'Code': self.ids['tools/demo/lf.txt'],
            'code/second.dm': self.ids['tools/demo/crlf.txt'],
        })
        self.assert_rejected(revision=tree, paths=['Code', 'code'])

    def test_unsafe_selected_paths_are_rejected(self):
        for index, path in enumerate(('../outside', '/absolute', r'tools\demo', 'C:/absolute', 'tools/../outside')):
            with self.subTest(path=path):
                self.assert_rejected(paths=[path], destination=self.root / ('unsafe-selection-' + str(index)))

    def test_unsafe_tree_paths_are_rejected(self):
        leaf = self.ids['tools/demo/lf.txt']
        inner = self.raw_tree([('100644', 'blob', leaf, 'escaped.txt')])
        for index, name in enumerate(('..', '.', '.git', r'back\slash', 'C:drive')):
            with self.subTest(name=name):
                # Selecting the safe outer directory exercises validation of
                # actual ls-tree records, not merely the caller's path list.
                bad = self.raw_tree([('040000', 'tree', inner, name)])
                tree = self.raw_tree([('040000', 'tree', bad, 'safe')])
                self.assert_rejected(revision=tree, paths=['safe'], destination=self.root / ('unsafe-tree-' + str(index)))
        self.assertFalse((self.root / 'escaped.txt').exists())

    def test_mutable_or_abbreviated_revision_is_rejected(self):
        self.git('update-ref', 'refs/heads/fixture', self.commit)
        for index, revision in enumerate(('refs/heads/fixture', self.commit[:12], self.commit + '^{tree}')):
            with self.subTest(revision=revision):
                self.assert_rejected(revision=revision, destination=self.root / ('bad-revision-' + str(index)))

    def test_canonical_blob_hash_is_verified_not_only_cat_file_header(self):
        payload = b'original immutable bytes\n'
        oid = self.blob(payload)
        tree = self.raw_tree([('100644', 'blob', oid, 'pinned.txt')])
        corrupt = b'changed! immutable bytes\n'
        self.assertEqual(len(payload), len(corrupt))
        object_path = self.repository / 'objects' / oid[:2] / oid[2:]
        object_path.chmod(0o600)
        object_path.write_bytes(zlib.compress(b'blob ' + str(len(corrupt)).encode('ascii') + b'\0' + corrupt))
        # Actual cat-file still reports the requested OID in its batch header;
        # export must independently hash the body instead of trusting the label.
        self.assertEqual(self.git('cat-file', 'blob', oid), corrupt)
        self.assert_rejected(revision=tree, paths=['pinned.txt'], expected={'pinned.txt': oid})


if __name__ == '__main__':
    unittest.main(verbosity=2)
