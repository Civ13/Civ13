"""Offline launcher contracts with injected process handles and temporary storage.

Every child is a fake object injected into the production helper. These tests
must never launch Git, a compiler, a daemon, or another real subprocess.
"""
import contextlib
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from mall_run_support import OwnedRun, write_manifest
import run_mall


class Clock:
    def __init__(self):
        self.value = 0

    def __call__(self):
        return self.value


class Child:
    """wait events are (elapsed seconds, exit code or exception)."""
    def __init__(self, clock, events=((0, 0),), *, kill_error=None):
        self.clock, self.events = clock, list(events)
        self.pid = id(self)
        self.returncode = None
        self.waits, self.kills = [], 0
        self.kill_error = kill_error

    def wait(self, timeout):
        self.waits.append(timeout)
        elapsed, result = self.events.pop(0)
        self.clock.value += elapsed
        if isinstance(result, BaseException):
            raise result
        self.returncode = result
        return result

    def poll(self):
        return self.returncode

    def kill(self):
        self.kills += 1
        if self.kill_error:
            raise self.kill_error


class Spawn:
    def __init__(self, children, callback=None):
        self.children, self.callback = list(children), callback
        self.calls = []

    def __call__(self, command, **kwargs):
        self.calls.append((command, kwargs))
        if self.callback:
            self.callback(len(self.calls), command, kwargs)
        return self.children.pop(0)


class OwnedRunTests(unittest.TestCase):
    def setUp(self):
        self.storage = tempfile.TemporaryDirectory(prefix='mall-unit-')
        self.addCleanup(self.storage.cleanup)
        self.root = Path(self.storage.name)
        self.prefix = '.mall_' + '0' * 32
        self.files = [self.root / (self.prefix + suffix) for suffix in
                      ('.dme', '_world.dm', '_globals.dm', '_metadata.dm',
                       '.dmb', '.rsc', '_loot.dm', '_equipment.dm')]
        self.clock = Clock()
        self.owners = 0

    def owner(self, children=(), **kwargs):
        self.owners += 1
        prefix = '.mall_' + format(self.owners, '032x')
        self.files = [path.with_name(path.name.replace(self.prefix, prefix, 1))
                      for path in self.files]
        self.prefix = prefix
        self.spawn = Spawn(children)
        return OwnedRun(self.root, self.prefix, {}, self.files,
                        clock=self.clock, popen=self.spawn, **kwargs)

    def generate(self):
        for path in self.files:
            path.write_text(path.name, encoding='utf-8')

    def receipt(self, owner):
        return json.loads((owner.destination / 'manifest.json').read_text())

    def test_manifest_replace_retries_transient_windows_denials_atomically(self):
        for code in (5, 32, 33):
            with self.subTest(winerror=code):
                receipt = self.root / 'receipt.json'
                write_manifest(receipt, {'outcome': 'old'})
                failure = PermissionError('transient sharing denial')
                failure.winerror = code
                calls = []
                sleep = mock.Mock()
                def replace(source, destination):
                    calls.append((source, destination))
                    self.assertEqual(json.loads(receipt.read_text()), {'outcome': 'old'})
                    self.assertEqual(json.loads(source.read_text()), {'outcome': 'new'})
                    if len(calls) < 4:
                        raise failure
                    source.replace(destination)
                write_manifest(receipt, {'outcome': 'new'}, replace=replace, sleep=sleep)
                self.assertEqual(len(calls), 4)
                self.assertEqual(sleep.call_args_list, [mock.call(0.05)] * 3)
                self.assertEqual(json.loads(receipt.read_text()), {'outcome': 'new'})
                self.assertFalse(receipt.with_suffix('.json.tmp').exists())

    def test_manifest_replace_exhaustion_retains_old_and_temp_and_fails_closed(self):
        owner = self.owner()
        self.generate()
        failure = PermissionError('persistent sharing denial')
        failure.winerror = 32
        replace = mock.Mock(side_effect=failure)
        sleep = mock.Mock()
        receipt = owner.destination / 'manifest.json'
        with self.assertRaises(PermissionError) as caught:
            with owner:
                old = receipt.read_bytes()
                owner.writer = lambda path, manifest: write_manifest(
                    path, manifest, replace=replace, sleep=sleep)
                try:
                    owner.checkpoint()
                except PermissionError:
                    self.assertEqual(replace.call_count, 4)
                    self.assertEqual(sleep.call_args_list, [mock.call(0.05)] * 3)
                    with self.assertRaisesRegex(RuntimeError, 'previous failure'):
                        owner.run('compile', ['must-not-start'], self.root, 10)
                    raise
        self.assertIs(caught.exception, failure)
        self.assertEqual(receipt.read_bytes(), old)
        self.assertTrue(receipt.with_suffix('.json.tmp').is_file())
        self.assertTrue(all(path.exists() for path in self.files))
        self.assertFalse(owner.checkpoint_ok)
        self.assertEqual(self.spawn.calls, [])

    def test_manifest_replace_other_errors_propagate_without_retry(self):
        failures = [PermissionError('no Windows error code'), OSError('IO failure')]
        unsupported = PermissionError('unsupported Windows error')
        unsupported.winerror = 87
        failures.append(unsupported)
        for failure in failures:
            with self.subTest(error=repr(failure)):
                receipt = self.root / 'receipt.json'
                write_manifest(receipt, {'outcome': 'old'})
                replace = mock.Mock(side_effect=failure)
                sleep = mock.Mock()
                with self.assertRaises(type(failure)) as caught:
                    write_manifest(receipt, {'outcome': 'new'}, replace=replace, sleep=sleep)
                self.assertIs(caught.exception, failure)
                replace.assert_called_once_with(receipt.with_suffix('.json.tmp'), receipt)
                sleep.assert_not_called()
                self.assertEqual(json.loads(receipt.read_text()), {'outcome': 'old'})
                self.assertEqual(json.loads(receipt.with_suffix('.json.tmp').read_text()),
                                 {'outcome': 'new'})

    def test_output_is_file_backed_and_stdin_is_devnull(self):
        child = Child(self.clock)
        owner = self.owner([child])
        def output(ordinal, command, kwargs):
            self.assertEqual(kwargs['stdin'], subprocess.DEVNULL)
            self.assertTrue(hasattr(kwargs['stdout'], 'fileno'))
            self.assertTrue(hasattr(kwargs['stderr'], 'fileno'))
            kwargs['stdout'].write(b'output\xff')
            kwargs['stderr'].write(b'diagnostic')
        self.spawn.callback = output
        with owner:
            result = owner.run('../label', ['fake-tool'], self.root, 20,
                               creationflags=123)
        self.assertEqual(result.stdout, 'output\ufffd')
        self.assertEqual(result.stderr, 'diagnostic')
        self.assertEqual(self.spawn.calls[0][1]['creationflags'], 123)
        self.assertTrue(self.spawn.calls[0][1]['stdout'].closed)
        self.assertEqual(self.receipt(owner)['outcome'], 'passed')

    def test_timeout_kills_exact_handle_and_confirms_reap(self):
        timeout = subprocess.TimeoutExpired(['fake-tool'], 10)
        child = Child(self.clock, [(10, timeout), (1, -9)])
        unrelated = Child(self.clock)
        owner = self.owner([child])
        self.generate()
        with self.assertRaises(subprocess.TimeoutExpired) as caught:
            with owner:
                runtime = owner.create_runtime()
                (runtime / 'runtime.log').write_text('retained log')
                owner.run('compile', ['fake-tool'], self.root, 10)
        self.assertIs(caught.exception, timeout)
        self.assertEqual(child.kills, 1)
        self.assertEqual(unrelated.kills, 0)
        self.assertEqual(child.waits, [10, 5])
        self.assertFalse(runtime.exists())
        self.assertTrue(all(not path.exists() for path in self.files))
        self.assertEqual((owner.destination / 'runtime.log').read_text(), 'retained log')
        self.assertTrue(self.receipt(owner)['stages'][0]['direct_child_exit_confirmed'])

    def test_uncertain_kill_or_reap_preserves_runtime_and_generated_files(self):
        for failure in ('kill', 'reap'):
            with self.subTest(failure=failure):
                primary = subprocess.TimeoutExpired(['fake-tool'], 1)
                child = Child(self.clock, [(0, primary),
                              (0, subprocess.TimeoutExpired(['fake-tool'], 5))],
                              kill_error=OSError('kill failed') if failure == 'kill' else None)
                owner = self.owner([child])
                self.generate()
                with self.assertRaises(subprocess.TimeoutExpired) as caught:
                    with owner:
                        runtime = owner.create_runtime()
                        owner.run('native', ['fake-tool'], self.root, 1)
                self.assertIs(caught.exception, primary)
                self.assertTrue(runtime.exists())
                self.assertTrue(all(path.exists() for path in self.files))
                row = self.receipt(owner)['stages'][0]
                self.assertFalse(row['direct_child_exit_confirmed'])
                # This is fake storage; no actual process can own it.
                import shutil
                shutil.rmtree(runtime)

    def test_keyboard_interrupt_and_system_exit_keep_primary_exception(self):
        def locked(path, *, missing_ok):
            raise PermissionError('unlink denied')
        for primary in (KeyboardInterrupt(), SystemExit(7)):
            with self.subTest(kind=type(primary).__name__):
                child = Child(self.clock, [(0, primary), (0, -9)])
                owner = self.owner([child], unlink=locked)
                with self.assertRaises(type(primary)) as caught:
                    with owner:
                        owner.run('compile', ['fake-tool'], self.root, 10)
                self.assertIs(caught.exception, primary)
                self.assertEqual(child.kills, 1)

    def test_run_deadline_is_shared_between_stages(self):
        first, second = Child(self.clock, [(7, 0)]), Child(self.clock)
        owner = self.owner([first, second], run_budget=10)
        with owner:
            owner.run('git', ['fake-git'], self.root, 8)
            owner.run('compile', ['fake-compiler'], self.root, 8)
        self.assertEqual(first.waits, [8])
        self.assertEqual(second.waits, [3])

    def test_expired_budget_never_spawns(self):
        owner = self.owner(run_budget=2)
        with self.assertRaises(subprocess.TimeoutExpired):
            with owner:
                self.clock.value = 2
                owner.run('compile', ['fake-tool'], self.root, 30)
        self.assertEqual(self.spawn.calls, [])

    def test_cleanup_budget_is_shared_between_children(self):
        # Injected interruption leaves both children pending; their subsequent
        # reaps consume one cleanup deadline rather than two full allocations.
        first = Child(self.clock, [(0, KeyboardInterrupt()), (4, -9)])
        second = Child(self.clock, [(0, -9)])
        owner = self.owner([first], cleanup_budget=6)
        with self.assertRaises(KeyboardInterrupt):
            with owner:
                try:
                    owner.run('compile', ['fake-tool'], self.root, 20)
                except KeyboardInterrupt:
                    owner.children.append((second, {}))
                    raise
        self.assertEqual(first.waits, [20, 5])
        self.assertEqual(second.waits, [2])

    def test_nonzero_exit_blocks_all_subsequent_launches(self):
        owner = self.owner([Child(self.clock, [(0, 4)])])
        with self.assertRaisesRegex(RuntimeError, 'failed'):
            with owner:
                result = owner.run('compile', ['fake-tool'], self.root, 10)
                self.assertEqual(result.returncode, 4)
                with self.assertRaisesRegex(RuntimeError, 'previous failure'):
                    owner.run('native', ['must-not-start'], self.root, 10)
        self.assertEqual(len(self.spawn.calls), 1)

    def test_writer_failure_keeps_primary_and_preserves_evidence(self):
        calls = []
        def writer(path, manifest):
            calls.append(manifest['outcome'])
            if len(calls) > 1:
                raise OSError('receipt storage unavailable')
            write_manifest(path, manifest)
        owner = self.owner(writer=writer)
        self.generate()
        primary = ValueError('original failure')
        with self.assertRaises(ValueError) as caught:
            with owner:
                raise primary
        self.assertIs(caught.exception, primary)
        self.assertTrue(all(path.exists() for path in self.files))
        self.assertTrue((owner.destination / 'manifest.json').exists())
        self.assertFalse(owner.checkpoint_ok)

    def test_every_owned_unlink_is_attempted_despite_one_failure(self):
        attempts = []
        def unlink(path, *, missing_ok):
            attempts.append(path)
            if path == self.files[2]:
                raise PermissionError('locked generated file')
            path.unlink(missing_ok=missing_ok)
        owner = self.owner(unlink=unlink)
        self.generate()
        unrelated = self.root / 'keep.txt'
        unrelated.write_text('unrelated')
        with self.assertRaisesRegex(RuntimeError, 'cleanup failed'):
            with owner:
                pass
        self.assertEqual(attempts, self.files)
        self.assertTrue(unrelated.exists())
        self.assertEqual(self.receipt(owner)['outcome'], 'failed')

    def test_retention_failure_prevents_destructive_cleanup(self):
        def copy(source, destination):
            raise OSError('receipt copy failed')
        owner = self.owner(copy=copy)
        self.generate()
        with self.assertRaisesRegex(RuntimeError, 'cleanup failed'):
            with owner:
                runtime = owner.create_runtime()
                (runtime / 'result.txt').write_text('PASS: fixture')
        self.assertTrue(runtime.exists())
        self.assertTrue(all(path.exists() for path in self.files))
        import shutil
        shutil.rmtree(runtime)

    def test_launch_failure_retains_exact_primary_and_prevents_retry(self):
        primary = OSError('fake spawn failed')
        owner = self.owner()
        def launch(*args, **kwargs):
            raise primary
        owner.popen = launch
        with self.assertRaises(OSError) as caught:
            with owner:
                owner.run('compile', ['fake-tool'], self.root, 10)
        self.assertIs(caught.exception, primary)
        self.assertEqual(owner.children, [])
        with self.assertRaisesRegex(RuntimeError, 'previous failure'):
            owner.run('daemon', ['must-not-launch'], self.root, 10)

    def test_redirected_runtime_is_rejected_without_deleting_foreign_path(self):
        foreign = self.root / 'civ13-mall-foreign'
        foreign.mkdir()
        removed = []
        owner = self.owner(mkdtemp=lambda **kw: str(foreign), rmtree=removed.append)
        with self.assertRaises(RuntimeError):
            with owner:
                owner.create_runtime()
        self.assertEqual(removed, [])
        self.assertTrue(foreign.exists())

    def test_replaced_runtime_directory_is_never_removed(self):
        removed = mock.Mock()
        owner = self.owner(rmtree=removed)
        with self.assertRaisesRegex(RuntimeError, 'cleanup failed'):
            with owner:
                runtime = owner.create_runtime()
                original = runtime.with_name(runtime.name + '-original')
                runtime.rename(original)
                runtime.mkdir()
                sentinel = runtime / 'unrelated.txt'
                sentinel.write_text('replacement must survive', encoding='utf-8')
        removed.assert_not_called()
        self.assertTrue(original.is_dir())
        self.assertEqual(sentinel.read_text(encoding='utf-8'), 'replacement must survive')
        receipt = self.receipt(owner)
        self.assertEqual(receipt['outcome'], 'failed')
        self.assertTrue(any(row['action'] == 'remove-runtime'
                            and 'identity changed' in row.get('error', '')
                            for row in receipt['cleanup']))

    def test_base_exceptions_survive_writer_and_kill_failures(self):
        for primary in (KeyboardInterrupt(), SystemExit(9)):
            with self.subTest(kind=type(primary).__name__):
                child = Child(self.clock, [(0, primary)], kill_error=OSError('kill denied'))
                owner = self.owner([child])
                self.generate()
                def writer(path, manifest):
                    raise OSError('writer failed during cleanup')
                with self.assertRaises(type(primary)) as caught:
                    with owner:
                        try:
                            owner.run('compile', ['fake-tool'], self.root, 10)
                        except type(primary):
                            owner.writer = writer
                            raise
                self.assertIs(caught.exception, primary)
                self.assertTrue(all(path.exists() for path in self.files))


class MainTests(unittest.TestCase):
    def setUp(self):
        self.storage = tempfile.TemporaryDirectory(prefix='mall-main-unit-')
        self.addCleanup(self.storage.cleanup)
        self.root = Path(self.storage.name)
        fixtures = {
            'civ13.dme': '#include "code\\world.dm"\n#include "code\\controllers\\mc\\globals.dm"\n',
            'code/world.dm': '/world/New()\n\t..()\n/datum/global_init/New()\n\treturn\n',
            'code/controllers/mc/globals.dm': '/datum/controller/global_vars/New()\n\treturn\n',
            'config/names/test.txt': 'fixture only\n',
        }
        for name, value in fixtures.items():
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(value, encoding='utf-8')

    def invoke(self, *, git_code=0, compile_code=0, compile_error=None,
               daemon_code=0, daemon_error=None, diagnostic='', compile_only=False,
               unlink=None, writer=None, git_output=b'a' * 40 + b'\n',
               compile_output=b'516.1681\n0 errors, 0 warnings\n'):
        clock = Clock()
        children = [Child(clock, [(0, git_code)]),
                    Child(clock, [(0, compile_error or compile_code), (0, -9)]),
                    Child(clock, [(0, daemon_error or daemon_code), (0, -9)])]
        self.owner = None
        def output(ordinal, command, kwargs):
            if ordinal == 1:
                kwargs['stdout'].write(git_output)
            elif ordinal == 2:
                kwargs['stdout'].write(compile_output)
                dme = self.root / command[-1]
                dme.with_suffix('.dmb').write_bytes(b'fake bytecode')
                dme.with_suffix('.rsc').write_bytes(b'fake resources')
            else:
                target = Path(kwargs['cwd'])
                (target / 'result.txt').write_text('PASS: fake native contract')
                (target / 'runtime.log').write_text(diagnostic)
        self.spawn = Spawn(children, output)
        def factory(root, prefix, metadata, files):
            options = {'unlink': unlink} if unlink else {}
            if writer:
                options['writer'] = writer
            self.owner = OwnedRun(root, prefix, metadata, files,
                                  clock=clock, popen=self.spawn, **options)
            return self.owner
        self.stdout = io.StringIO()
        argv = ['--byond-bin', str(self.root / 'fake-byond')]
        if compile_only:
            argv.append('--compile-only')
        # Guard accidental subprocess.run calls as well as the injected Popen.
        with mock.patch.object(subprocess, 'run', side_effect=AssertionError('real subprocess forbidden')):
            with mock.patch.object(subprocess, 'Popen', side_effect=AssertionError('real subprocess forbidden')):
                with contextlib.redirect_stdout(self.stdout):
                    run_mall.main(argv, root=self.root, run_factory=factory)

    def test_git_failure_prevents_compilation(self):
        with self.assertRaises(RuntimeError):
            self.invoke(git_code=1)
        self.assertEqual(len(self.spawn.calls), 1)
        self.assertNotIn('PASS:', self.stdout.getvalue())

    def test_malformed_git_head_and_missing_compiler_banner_reject_success(self):
        for options, launches in (({'git_output': b'not-a-commit\n'}, 1),
                                  ({'compile_output': b'0 errors, 0 warnings\n'}, 2)):
            with self.subTest(options=options):
                with self.assertRaises(RuntimeError):
                    self.invoke(**options)
                self.assertEqual(len(self.spawn.calls), launches)
                self.assertNotIn('PASS:', self.stdout.getvalue())

    def test_compiler_failure_or_timeout_never_launches_daemon(self):
        for failure in (7, subprocess.TimeoutExpired(['fake-compiler'], 120)):
            with self.subTest(failure=type(failure).__name__):
                options = {'compile_error': failure} if isinstance(failure, BaseException) else {'compile_code': failure}
                with self.assertRaises((RuntimeError, subprocess.TimeoutExpired)):
                    self.invoke(**options)
                self.assertEqual(len(self.spawn.calls), 2)
                self.assertNotIn('PASS:', self.stdout.getvalue())

    def test_compile_only_retains_receipts_and_success_follows_cleanup(self):
        self.invoke(compile_only=True)
        self.assertEqual(len(self.spawn.calls), 2)
        manifest = json.loads((self.owner.destination / 'manifest.json').read_text())
        self.assertEqual(manifest['head_sha'], 'a' * 40)
        self.assertEqual(manifest['outcome'], 'passed')
        self.assertTrue(all(not path.exists() for path in self.owner.files))
        self.assertIn('PASS: pinned mall fixture compile', self.stdout.getvalue())

    def test_cleanup_failure_suppresses_success(self):
        def locked(path, *, missing_ok):
            raise PermissionError('locked fixture')
        with self.assertRaisesRegex(RuntimeError, 'cleanup failed'):
            self.invoke(compile_only=True, unlink=locked)
        self.assertNotIn('PASS:', self.stdout.getvalue())

    def test_final_writer_that_writes_then_raises_cannot_publish_success(self):
        failed_once = []
        def writer(path, manifest):
            write_manifest(path, manifest)
            if manifest['outcome'] == 'passed' and not failed_once:
                failed_once.append(True)
                raise OSError('failure after final write')
        with self.assertRaisesRegex(RuntimeError, 'cleanup failed'):
            self.invoke(compile_only=True, writer=writer)
        self.assertNotIn('PASS:', self.stdout.getvalue())
        manifest = json.loads((self.owner.destination / 'manifest.json').read_text())
        self.assertEqual(manifest['outcome'], 'failed')
        self.assertEqual(self.owner.manifest['outcome'], 'failed')
        self.assertTrue(manifest['receipt_write_failed'])

    def test_daemon_timeout_reaps_and_retains_receipts(self):
        primary = subprocess.TimeoutExpired(['fake-daemon'], 90)
        with self.assertRaises(subprocess.TimeoutExpired) as caught:
            self.invoke(daemon_error=primary)
        self.assertIs(caught.exception, primary)
        self.assertEqual(len(self.spawn.calls), 3)
        self.assertFalse(self.owner.runtime.exists(), json.dumps(self.owner.manifest, indent=2))
        self.assertTrue((self.owner.destination / 'runtime.log').exists())
        self.assertTrue(self.owner.manifest['stages'][-1]['direct_child_exit_confirmed'])
        self.assertNotIn('PASS:', self.stdout.getvalue())

    def test_native_success_retains_report_and_removes_runtime(self):
        self.invoke()
        self.assertEqual(len(self.spawn.calls), 3)
        self.assertFalse(self.owner.runtime.exists())
        self.assertEqual((self.owner.destination / 'result.txt').read_text(),
                         'PASS: fake native contract')
        self.assertIn('PASS: fake native contract', self.stdout.getvalue())

    def test_native_nonzero_and_diagnostics_reject_pass_report(self):
        for code, log in ((4, ''), (0, 'Runtime error'), (0, 'Bad ref'),
                          (0, '## Error'), (0, 'Opened on network port 1234')):
            with self.subTest(code=code, log=log):
                with self.assertRaises(RuntimeError):
                    self.invoke(daemon_code=code, diagnostic=log)
                self.assertNotIn('PASS:', self.stdout.getvalue())
                self.assertTrue((self.owner.destination / 'runtime.log').exists())


if __name__ == '__main__':
    unittest.main()
