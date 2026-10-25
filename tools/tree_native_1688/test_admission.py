"""Injected Git admission contract tests; never executes Git/native/socket work."""
import os
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import patch

from audit_offline import install
install()
import admission


class CheckoutAdmissionTests(unittest.TestCase):
    def setUp(self):
        self.source = Path('/tmp/synthetic-exact-head-checkout')
        self.manifest = {
            'code/example.dm': {'mode': '100644', 'type': 'blob', 'sha': 'a' * 40},
            'scripts/example.py': {'mode': '100755', 'type': 'blob', 'sha': 'b' * 40},
        }
        self.commands = [
            ('rev-parse', '--show-toplevel'), ('rev-parse', 'HEAD'),
            ('rev-parse', 'HEAD^{tree}'), ('status', '--porcelain', '--untracked-files=all'),
            ('ls-tree', '-rz', '--full-tree', 'HEAD'),
        ]
        self.responses = {
            self.commands[0]: (str(self.source) + '\n').encode(),
            self.commands[1]: (admission.HEAD + '\n').encode(),
            self.commands[2]: (admission.TREE + '\n').encode(),
            self.commands[3]: b'',
            self.commands[4]: self.tree_bytes(self.manifest),
        }

    @staticmethod
    def tree_bytes(manifest):
        return b''.join((f"{row['mode']} {row['type']} {row['sha']}\t{name}").encode() + b'\0'
                        for name, row in manifest.items())

    def verify(self):
        calls = []
        def fake_git(source, *args):
            self.assertEqual(source, self.source)
            calls.append(args)
            self.assertIn(args, self.commands)
            return self.responses[args]
        with patch.object(admission, 'git', side_effect=fake_git):
            result = admission.verify_checkout(self.source, self.manifest)
        return result, calls

    def test_exact_fixed_head_tree_root_clean_manifest(self):
        self.assertEqual(admission.HEAD, 'e773c2fae4b196ad6c7afc025235e90f488f7db8')
        self.assertEqual(admission.TREE, '4800aac2e81b45b6fb215bcf23f8ed3761186fe3')
        result, calls = self.verify()
        self.assertEqual(calls, self.commands)
        self.assertEqual(result, {'head': admission.HEAD, 'tree': admission.TREE,
                                  'tracked_files': 2, 'actual_git_checked': True})

    def test_wrong_root_head_or_tree_rejected(self):
        for command, bad in [(self.commands[0], b'/tmp/parent\n'),
                             (self.commands[1], b'c' * 40 + b'\n'),
                             (self.commands[2], b'd' * 40 + b'\n')]:
            with self.subTest(command=command):
                original = self.responses[command]; self.responses[command] = bad
                with self.assertRaises(ValueError): self.verify()
                self.responses[command] = original

    def test_dirty_and_untracked_paths_rejected(self):
        for status in [b'?? extra.dm\n', b' M code/example.dm\n', b'M  code/example.dm\n',
                       b'A  added.dm\n', b' D scripts/example.py\n']:
            with self.subTest(status=status):
                self.responses[self.commands[3]] = status
                with self.assertRaisesRegex(ValueError, 'not clean'): self.verify()

    def test_wrong_blob_mode_kind_missing_or_added_tree_member(self):
        for change in ['blob', 'mode', 'kind', 'missing', 'extra']:
            altered = {name: dict(row) for name, row in self.manifest.items()}
            if change == 'blob': altered['code/example.dm']['sha'] = 'f' * 40
            if change == 'mode': altered['code/example.dm']['mode'] = '100755'
            if change == 'kind': altered['code/example.dm']['type'] = 'commit'
            if change == 'missing': del altered['code/example.dm']
            if change == 'extra': altered['extra.dm'] = dict(self.manifest['code/example.dm'])
            self.responses[self.commands[4]] = self.tree_bytes(altered)
            with self.subTest(change=change), self.assertRaisesRegex(ValueError, 'differs'): self.verify()

    def test_duplicate_tracked_path_rejected(self):
        self.responses[self.commands[4]] += self.tree_bytes({'code/example.dm': self.manifest['code/example.dm']})
        with self.assertRaisesRegex(ValueError, 'Duplicate'): self.verify()

    def test_malformed_tree_data_rejected(self):
        for raw in [b'no-tab\0', b'100644 blob\tcode/example.dm\0', b'\xff blob abc\tx\0',
                    b'100644 blob abc\t\xff\0']:
            self.responses[self.commands[4]] = raw
            with self.subTest(raw=raw), self.assertRaises((ValueError, UnicodeError)): self.verify()

    def test_tree_order_is_not_semantic(self):
        self.responses[self.commands[4]] = self.tree_bytes(dict(reversed(list(self.manifest.items()))))
        self.assertEqual(self.verify()[0]['tracked_files'], 2)


class GitInvocationTests(unittest.TestCase):
    def test_fixed_readonly_arguments_and_sanitized_git_environment(self):
        injected = {
            'PATH': '/synthetic/bin', 'HOME': '/synthetic/home',
            'GIT_DIR': '/bad/repo', 'GIT_WORK_TREE': '/bad/work', 'GIT_INDEX_FILE': '/bad/index',
            'GIT_OBJECT_DIRECTORY': '/bad/objects', 'GIT_ALTERNATE_OBJECT_DIRECTORIES': '/bad/alternates',
            'GIT_CONFIG_COUNT': '1', 'GIT_CONFIG_KEY_0': 'alias.status', 'GIT_CONFIG_VALUE_0': '!bad',
            'GIT_CONFIG_GLOBAL': '/bad/global', 'GIT_CONFIG_SYSTEM': '/bad/system',
            'GIT_REPLACE_REF_BASE': 'refs/custom', 'GIT_TRACE': '/bad/trace',
        }
        with patch.dict(os.environ, injected, clear=True), \
             patch.object(admission.subprocess, 'run', return_value=SimpleNamespace(stdout=b'output', stderr=b'')) as run:
            result = admission.git(Path('/tmp/fake'), 'rev-parse', 'HEAD')
        self.assertEqual(result, b'output')
        args, kwargs = run.call_args
        self.assertEqual(args, (['git', '--no-replace-objects', '-c', 'core.fsmonitor=false',
                                 '-c', 'core.untrackedCache=false', 'rev-parse', 'HEAD'],))
        self.assertEqual(kwargs['cwd'], Path('/tmp/fake'))
        self.assertIs(kwargs['check'], True); self.assertIs(kwargs['capture_output'], True)
        self.assertEqual(kwargs['timeout'], 30); self.assertNotIn('shell', kwargs)
        expected_git = {'GIT_CONFIG_NOSYSTEM': '1', 'GIT_CONFIG_GLOBAL': os.devnull,
                        'GIT_OPTIONAL_LOCKS': '0', 'GIT_TERMINAL_PROMPT': '0', 'GIT_NO_REPLACE_OBJECTS': '1'}
        self.assertEqual({k: v for k, v in kwargs['env'].items() if k.startswith('GIT_')}, expected_git)
        self.assertEqual(kwargs['env']['PATH'], injected['PATH'])
        self.assertEqual(kwargs['env']['HOME'], injected['HOME'])

    def test_output_bounds(self):
        for stdout, stderr in [(b'x' * (16 * 1024**2 + 1), b''), (b'', b'x' * (1024**2 + 1))]:
            with self.subTest(stdout=len(stdout), stderr=len(stderr)), \
                 patch.object(admission.subprocess, 'run', return_value=SimpleNamespace(stdout=stdout, stderr=stderr)), \
                 self.assertRaisesRegex(ValueError, 'exceeds bound'):
                admission.git(Path('/tmp/fake'), 'rev-parse', 'HEAD')

    def test_subprocess_failure_is_not_blessed(self):
        for error in [admission.subprocess.CalledProcessError(1, ['git']),
                      admission.subprocess.TimeoutExpired(['git'], 30), FileNotFoundError('git')]:
            with self.subTest(error=type(error).__name__), \
                 patch.object(admission.subprocess, 'run', side_effect=error), self.assertRaises(type(error)):
                admission.git(Path('/tmp/fake'), 'rev-parse', 'HEAD')


if __name__ == '__main__':
    unittest.main(verbosity=2)
