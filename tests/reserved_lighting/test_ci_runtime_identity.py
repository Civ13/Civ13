"""Synthetic archive/pin controls for the reserved lane; no native or network calls."""
import copy
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import stat
import sys
import tempfile
import unittest
from unittest.mock import patch
import zipfile

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).parent))


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


RUNNERS = (module('reserved_current_runtime_test', ROOT / 'tests/reserved_lighting/run-ci.py'),)
COMPILER = 'DM compiler version 516.1688\nprobe.dmb - 0 errors, 0 warnings (1.0s)\n'
BANNER = 'Welcome BYOND! (5.0 Public Version 516.1688)\n'


class CurrentLinuxRuntime(unittest.TestCase):
    def setUp(self):
        self.root = Path(self.enterContext(tempfile.TemporaryDirectory())).resolve()
        self.bin = self.root / 'bin'; self.bin.mkdir()
        self.archive = self.root / 'synthetic.zip'
        self.bodies = {name: ('synthetic unexecuted ' + name).encode()
                       for name in ('DreamMaker', 'DreamDaemon', 'libbyond.so', 'libext.so')}
        self.pin = {'version': '516.1688', 'linux': {}}
        self.make_archive()
        for runner in RUNNERS:
            runtime = runner.runtime_module()
            self.enterContext(patch.object(runtime.pin, 'load', return_value=self.pin))
            if sys.platform != 'linux':
                # Linux descriptor/change-time semantics are not Windows
                # platform acceptance. Inject only that file-read adapter;
                # the actual ZIP/member hashing and drift checks still run.
                self.enterContext(patch.object(runtime, '_read_regular', side_effect=self.fixture_read))
            self.enterContext(patch.object(runner, 'runtime_module', return_value=runtime))
        self.enterContext(patch('subprocess.Popen', side_effect=AssertionError('Native launch attempted')))
        self.enterContext(patch('subprocess.run', side_effect=AssertionError('Native launch attempted')))

    def fixture_read(self, path, expected_bytes, maximum):
        path = Path(path)
        info = path.lstat()
        if (path.is_symlink() or not stat.S_ISREG(info.st_mode)
                or info.st_size != expected_bytes or not 0 < expected_bytes <= maximum):
            raise ValueError('Synthetic Linux regular-file contract')
        with path.open('rb') as stream:
            value = stream.read(expected_bytes + 1)
        if len(value) != expected_bytes:
            raise ValueError('Synthetic Linux file length changed')
        return value

    def make_archive(self):
        output = io.BytesIO()
        with zipfile.ZipFile(output, 'w') as archive:
            for name, body in self.bodies.items():
                entry = zipfile.ZipInfo('byond/bin/' + name)
                entry.create_system = 3
                entry.external_attr = (stat.S_IFREG | 0o755) << 16
                archive.writestr(entry, body)
                (self.bin / name).write_bytes(body)
        value = output.getvalue()
        self.archive.write_bytes(value)
        self.pin['linux'] = {'sha256': hashlib.sha256(value).hexdigest(), 'bytes': len(value)}

    def test_current_manifest_members_are_verified_before_any_native_call(self):
        for runner in RUNNERS:
            with self.subTest(runner=runner.__name__):
                value = runner.verify_runtime(self.bin, self.archive)
                self.assertEqual(value['version'], '516.1688')
                self.assertEqual(value['archive'], self.pin['linux'])
                self.assertEqual(set(value['members']), set(self.bodies))
                runner.verify_runtime(self.bin, self.archive, value)

    def test_old_or_lookalike_target_is_not_a_current_runtime(self):
        for version in ('516.1681', '516.16880'):
            self.pin['version'] = version
            for runner in RUNNERS:
                with self.subTest(version=version, runner=runner.__name__), self.assertRaisesRegex(RuntimeError, 'Pinned 516.1688'):
                    runner.verify_runtime(self.bin, self.archive)

    def test_each_mismatched_binary_or_bundled_library_is_refused(self):
        for name, body in self.bodies.items():
            (self.bin / name).write_bytes(b'X' * len(body))
            for runner in RUNNERS:
                with self.subTest(member=name, runner=runner.__name__), self.assertRaisesRegex(ValueError, 'differs'):
                    runner.verify_runtime(self.bin, self.archive)
            (self.bin / name).write_bytes(body)

    def test_archive_drift_is_refused_without_trusting_installed_names(self):
        data = self.archive.read_bytes()
        self.archive.write_bytes(b'X' * len(data))
        for runner in RUNNERS:
            with self.subTest(runner=runner.__name__), self.assertRaisesRegex(ValueError, 'SHA-256'):
                runner.verify_runtime(self.bin, self.archive)

    def test_coherent_member_and_archive_rewrite_cannot_replace_original_binding(self):
        originals = [copy.deepcopy(runner.verify_runtime(self.bin, self.archive)) for runner in RUNNERS]
        self.bodies['DreamDaemon'] = b'new synthetic unexecuted daemon'
        self.make_archive()
        for runner, expected in zip(RUNNERS, originals):
            with self.subTest(runner=runner.__name__), self.assertRaisesRegex(RuntimeError, 'drift'):
                runner.verify_runtime(self.bin, self.archive, expected)

    def test_compiler_requires_one_exact_current_banner_clean_counts_and_exit(self):
        for runner in RUNNERS:
            runner.validate_compiler(0, COMPILER)
            for code, log in ((1, COMPILER), (0, COMPILER.replace('1688', '1681')),
                              (0, COMPILER.replace('1688', '16880')), (0, COMPILER + COMPILER),
                              (0, COMPILER.replace('0 warnings', '1 warnings')), (0, COMPILER + 'runtime error: bad')):
                with self.subTest(code=code, runner=runner.__name__), self.assertRaises(RuntimeError):
                    runner.validate_compiler(code, log)

    def test_runtime_rejects_missing_old_mixed_or_lookalike_banners(self):
        for runner in RUNNERS:
            runner.validate_runtime_banner(BANNER)
            # stdout and runtime.log may contain the same current banner.
            runner.validate_runtime_banner(BANNER + BANNER)
            for log in ('', BANNER.replace('1688', '1681'), BANNER.replace('1688', '16880'),
                        BANNER + BANNER.replace('1688', '1681')):
                with self.subTest(runner=runner.__name__), self.assertRaises(RuntimeError):
                    runner.validate_runtime_banner(log)

    def test_stream_boundary_does_not_hide_a_second_compiler_banner(self):
        runner = RUNNERS[0]
        result = type('Result', (), {'stdout': COMPILER.rstrip('\n'),
                                    'stderr': 'DM compiler version 516.1681\n'})()
        with self.assertRaises(RuntimeError):
            runner.validate_compiler(0, runner.combined_output(result))


if __name__ == '__main__':
    unittest.main()
