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


BINDING = 'World opened on network port 12345 for address 127.0.0.1.\n'
CLOSURE = 'World no longer opened to new users.\n'
NETWORK_LOG = BINDING + CLOSURE
CONTROLS = {
    'mission': 'secure floors excluded by mission policy',
    'vehicle': 'only highway exits admit cars',
    'key_charge': 'successful extraction preserves remaining key uses',
    'key_construction': 'keyed factory construction failure exposes no reward',
    'stair_landing': 'all cores reject dense destination occupancy without moving the actor',
    'stair_return': 'all cores reject a missing return stair without moving the actor',
    'ordinary_replay': 'ordinary container claim is unique before reopening',
}


class NativeOracleTests(unittest.TestCase):
    def validate(self, *, report=None, expected=None, stages=None, **outputs):
        streams = {'stdout': BINDING, 'stderr': '', 'runtime.log': NETWORK_LOG}
        streams.update(outputs)
        return run_mall.validate_native_result(
            run_mall.PASS_RESULT + '\n' if report is None else report,
            run_mall.NETWORK_STAGE + '\n' if stages is None else stages,
            streams, expected)

    def failure(self, expected, line=46):
        return f'FAIL: {expected} at tests/extraction/mall_probe.dm:{line}'

    def test_exact_positive_requires_network_receipt(self):
        self.assertEqual(self.validate(), run_mall.PASS_RESULT)
        for stages in ('', run_mall.NETWORK_STAGE + '\n' + run_mall.NETWORK_STAGE):
            with self.subTest(stages=stages), self.assertRaises(RuntimeError):
                self.validate(stages=stages)

    def test_missing_nonloopback_and_malformed_bind_records_are_rejected(self):
        for output in (BINDING.replace('127.0.0.1', '0.0.0.0'),
                       BINDING.replace('127.0.0.1', '192.0.2.1'),
                       BINDING.replace('127.0.0.1', '127.0.0.1.evil'),
                       BINDING.rstrip() + ' unexpected suffix\n',
                       'World opened on network port 12345\n',
                       BINDING + 'World opened on network port 12345\n'):
            with self.subTest(output=output), self.assertRaises(RuntimeError):
                self.validate(stdout=output)
        with self.assertRaises(RuntimeError):
            self.validate(stderr=BINDING.replace('127.0.0.1', '0.0.0.0'))

    def test_canonical_runtime_log_requires_one_ordered_binding_and_closure(self):
        for log in ('', BINDING, CLOSURE, CLOSURE + BINDING,
                    BINDING + BINDING + CLOSURE, BINDING + CLOSURE + CLOSURE,
                    BINDING.rstrip() + ' unexpected suffix\n' + CLOSURE,
                    BINDING + CLOSURE.rstrip() + ' unexpected suffix\n',
                    NETWORK_LOG.replace('127.0.0.1', '0.0.0.0')):
            with self.subTest(log=log), self.assertRaises(RuntimeError):
                self.validate(**{'runtime.log': log})
        for stream in ('stdout', 'stderr'):
            for log in (BINDING + BINDING, CLOSURE + CLOSURE, CLOSURE + BINDING):
                with self.subTest(stream=stream, log=log), self.assertRaises(RuntimeError):
                    self.validate(**{stream: log})
        self.assertEqual(self.validate(stdout=NETWORK_LOG, stderr=NETWORK_LOG),
                         run_mall.PASS_RESULT)

    def test_positive_rejects_wrong_duplicate_and_collateral_results(self):
        for report in ('PASS: other contract', run_mall.PASS_RESULT + '\nFAIL: unrelated',
                       run_mall.PASS_RESULT + '\n' + run_mall.PASS_RESULT,
                       run_mall.PASS_RESULT + '\n\n'):
            with self.subTest(report=report), self.assertRaises(RuntimeError):
                self.validate(report=report)
        for stream in ('stdout', 'stderr', 'runtime.log'):
            for record in ('FAIL: unrelated\n', run_mall.PASS_RESULT + '\n'):
                with self.subTest(stream=stream, record=record), self.assertRaises(RuntimeError):
                    self.validate(**{stream: NETWORK_LOG + record})

    def test_every_control_accepts_one_exact_failure_and_native_crlf(self):
        for expected in CONTROLS.values():
            with self.subTest(expected=expected):
                failure = self.failure(expected)
                self.assertEqual(
                    self.validate(report=failure + '\r\n', expected=expected,
                                  **{'runtime.log': NETWORK_LOG.replace('\n', '\r\n')
                                     + failure + '\r\n'}),
                    'PASS: negative control rejected at ' + expected)
                # Native world.log may be mirrored once to stdout/stderr.
                self.validate(report=failure, expected=expected,
                              stdout=BINDING + failure + '\n', stderr=failure + '\n',
                              **{'runtime.log': NETWORK_LOG + failure + '\n'})

    def test_every_control_accepts_only_its_exact_runtime_assertion_dialect(self):
        for expected in CONTROLS.values():
            with self.subTest(expected=expected):
                detail = self.failure(expected).removeprefix('FAIL: ')
                report = 'FAIL: runtime ' + detail
                log = 'Runtime error: ' + detail
                self.assertEqual(
                    self.validate(report=report + '\r\n', expected=expected,
                                  stdout=BINDING + log + '\r\n', stderr=log + '\r\n',
                                  **{'runtime.log': NETWORK_LOG + log + '\r\n'}),
                    'PASS: negative control rejected at ' + expected)

    def test_runtime_result_requires_exact_message_file_and_matching_location(self):
        expected = CONTROLS['stair_return']
        detail = self.failure(expected).removeprefix('FAIL: ')
        report = 'FAIL: runtime ' + detail
        log = 'Runtime error: ' + detail
        for invalid in (report + ' extra', report + '\n' + report,
                        report + '\n' + self.failure(expected),
                        report.replace('mall_probe.dm', 'other_probe.dm'),
                        report.replace(expected, 'unrelated ' + expected)):
            with self.subTest(report=invalid), self.assertRaises(RuntimeError):
                self.validate(report=invalid, expected=expected,
                              **{'runtime.log': NETWORK_LOG + log})
        for invalid in ('', log.replace(':46', ':47'),
                        log.replace('mall_probe.dm', 'other_probe.dm'),
                        log.replace(expected, 'unrelated ' + expected)):
            with self.subTest(log=invalid), self.assertRaises(RuntimeError):
                self.validate(report=report, expected=expected,
                              **{'runtime.log': NETWORK_LOG + invalid})

    def test_runtime_controls_reject_duplicate_mixed_and_collateral_stream_records(self):
        expected = CONTROLS['stair_return']
        caught = self.failure(expected)
        detail = caught.removeprefix('FAIL: ')
        report = 'FAIL: runtime ' + detail
        log = 'Runtime error: ' + detail
        for stream in ('stdout', 'stderr', 'runtime.log'):
            for extra in (log, caught, 'FAIL: unrelated', run_mall.PASS_RESULT,
                          log.replace(':46', ':47'), *run_mall.DIAGNOSTICS):
                outputs = {'runtime.log': NETWORK_LOG + log}
                outputs[stream] = NETWORK_LOG + log + '\n' + extra
                with self.subTest(stream=stream, extra=extra), self.assertRaises(RuntimeError):
                    self.validate(report=report, expected=expected, **outputs)
            # The opposite dialect in a different stream is collateral too.
            outputs = {'runtime.log': NETWORK_LOG + log}
            outputs[stream] = NETWORK_LOG + caught
            with self.subTest(stream=stream), self.assertRaises(RuntimeError):
                self.validate(report=report, expected=expected, **outputs)
            outputs = {'runtime.log': NETWORK_LOG + caught}
            outputs[stream] = NETWORK_LOG + log
            with self.subTest(caught_mode_stream=stream), self.assertRaises(RuntimeError):
                self.validate(report=caught, expected=expected, **outputs)

    def test_positive_never_accepts_expected_looking_runtime_assertions(self):
        detail = self.failure(CONTROLS['stair_return']).removeprefix('FAIL: ')
        log = 'Runtime error: ' + detail
        for stream in ('stdout', 'stderr', 'runtime.log'):
            with self.subTest(stream=stream), self.assertRaises(RuntimeError):
                self.validate(**{stream: NETWORK_LOG + log})
        with self.assertRaises(RuntimeError):
            self.validate(report='FAIL: runtime ' + detail,
                          **{'runtime.log': NETWORK_LOG + log})

    def test_negative_requires_exact_file_message_and_one_result(self):
        expected = CONTROLS['mission']
        failure = self.failure(expected)
        for report in ('FAIL: unrelated ' + expected, failure + ' extra',
                       failure.replace('mall_probe.dm', 'other_probe.dm'),
                       failure + '\n' + failure, failure + '\nFAIL: unrelated',
                       failure + '\n' + run_mall.PASS_RESULT, run_mall.PASS_RESULT):
            with self.subTest(report=report), self.assertRaises(RuntimeError):
                self.validate(report=report, expected=expected,
                              **{'runtime.log': NETWORK_LOG + failure + '\n'})

    def test_negative_requires_matching_runtime_log_and_rejects_duplicates(self):
        expected = CONTROLS['vehicle']
        failure = self.failure(expected)
        for log in ('', self.failure(expected, line=47),
                    failure + '\n' + failure, failure + '\nFAIL: unrelated',
                    failure + '\n' + run_mall.PASS_RESULT):
            with self.subTest(log=log), self.assertRaises(RuntimeError):
                self.validate(report=failure, expected=expected,
                              **{'runtime.log': NETWORK_LOG + log})
        for stream in ('stdout', 'stderr'):
            for extra in ('FAIL: unrelated', failure + '\n' + failure,
                          self.failure(expected, line=47), run_mall.PASS_RESULT):
                with self.subTest(stream=stream, extra=extra), self.assertRaises(RuntimeError):
                    self.validate(report=failure, expected=expected,
                                  **{'runtime.log': NETWORK_LOG + failure,
                                     stream: BINDING + extra})

    def test_engine_diagnostics_rejected_in_every_stream_for_both_modes(self):
        expected = CONTROLS['stair_return']
        failure = self.failure(expected)
        for stream in ('stdout', 'stderr', 'runtime.log'):
            for diagnostic in run_mall.DIAGNOSTICS:
                with self.subTest(stream=stream, diagnostic=diagnostic):
                    with self.assertRaises(RuntimeError):
                        self.validate(**{stream: BINDING + diagnostic})
                    outputs = {'runtime.log': NETWORK_LOG + failure}
                    outputs[stream] = BINDING + failure + '\n' + diagnostic
                    with self.assertRaises(RuntimeError):
                        self.validate(report=failure, expected=expected, **outputs)

    def test_fixture_blocks_clients_exports_topics_and_port_reopening(self):
        source = (HERE / 'mall_probe.dm').read_text()
        self.assertIn('\tvisibility = 0\n', source)
        self.assertIn('/client/New()\n\tdel(src)\n\treturn null\n', source)
        self.assertIn('\tExport()\n\t\treturn null\n', source)
        self.assertIn('\tTopic()\n\t\treturn null\n', source)
        self.assertIn('\tOpenPort(port)\n\t\tif (port == "none") return ..()\n\t\treturn FALSE\n', source)
        self.assertIn('\tNew()\n\t\tworld.OpenPort("none")\n', source)
        self.assertIn('mall_assert(!world.port && !world.visibility', source)
        self.assertIn('mall_assert(!world.OpenPort(0) && !world.port', source)
        self.assertIn('world.byond_version == 516 && world.byond_build == 1681', source)
        self.assertLess(source.index('try\n'), source.index('mall_assert(!world.port'))
        self.assertLess(source.index('mall_stage("' + run_mall.NETWORK_STAGE + '")'),
                        source.index('\t\t\t\tmall_probe()'))

    def test_retail_stair_approach_precedes_production_traversal(self):
        source = (HERE / 'mall_probe.dm').read_text()
        start = source.index('\tvar/obj/structure/extraction_mall_stairs/retail\n')
        end = source.index('\tvar/obj/structure/extraction_mall_stairs/gallery', start)
        sequence = source[start:end]
        geometry = ('mall_assert(retail && retail.x == parking.x + 2'
                    ' && retail.y == parking.y && retail.z == 4'
                    ' && get_dist(H, retail) == 2,'
                    ' "mapped retail stair is two tiles from parking landing")')
        approach = 'H.forceMove(get_turf(retail))'
        traverse = ('mall_assert(retail && retail.traverse(H) && H.z == 5,'
                    ' "retail to gallery production traverse")')

        def require_approach(text):
            for statement in (geometry, approach, traverse):
                self.assertEqual(text.count(statement), 1)
            self.assertLess(text.index(geometry), text.index(approach))
            self.assertLess(text.index(approach), text.index(traverse))

        require_approach(sequence)
        # Source-only controls cannot prove movement, but must catch the omitted
        # or too-late approach that prevented the native traversal from running.
        for broken in (sequence.replace(approach, ''),
                       sequence.replace(approach, '') + '\n' + approach,
                       sequence.replace('get_dist(H, retail) == 2', 'TRUE')):
            with self.subTest(broken=broken), self.assertRaises(AssertionError):
                require_approach(broken)


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
            'civ13.dme': '#include "code\\world.dm"\n#include "code\\controllers\\mc\\globals.dm"\n'
                         '#include "code\\modules\\1713\\extraction\\mall.dm"\n'
                         '#include "code\\modules\\1713\\extraction\\loot.dm"\n'
                         '#include "code\\modules\\1713\\extraction\\equipment.dm"\n',
            'code/world.dm': '/world/New()\n\t..()\n/datum/global_init/New()\n\treturn\n',
            'code/controllers/mc/globals.dm': '/datum/controller/global_vars/New()\n\treturn\n',
            'code/modules/1713/extraction/mall.dm':
                'return level in list(1, 4, 5)\n'
                'return ..() && istype(E, /obj/effect/extraction_exit/highway) && E.z == 1\n'
                'if (A.density || isliving(A)) return FALSE\n'
                'if (!return_stairs || return_stairs.destination_z != z) return FALSE\n',
            'code/modules/1713/extraction/loot.dm':
                'stash -= list(entry)\n'
                'if (!isnull(test_fail_constructor_after) && constructed.len >= test_fail_constructor_after)\n',
            'code/modules/1713/extraction/equipment.dm': 'scalars[key] = value\n',
            'config/names/test.txt': 'fixture only\n',
        }
        for name, value in fixtures.items():
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(value, encoding='utf-8')

    def invoke(self, *, git_code=0, compile_code=0, compile_error=None,
               daemon_code=0, daemon_error=None, diagnostic='', compile_only=False,
               unlink=None, writer=None, git_output=b'a' * 40 + b'\n',
               compile_output=b'516.1681\n0 errors, 0 warnings\n',
               negative_control=None):
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
                metadata = dme.with_name(dme.stem + '_metadata.dm')
                self.compiled_metadata = metadata.read_text() if metadata.exists() else None
                dme.with_suffix('.dmb').write_bytes(b'fake bytecode')
                dme.with_suffix('.rsc').write_bytes(b'fake resources')
            else:
                target = Path(kwargs['cwd'])
                report = run_mall.PASS_RESULT
                if negative_control:
                    report = (f'FAIL: {CONTROLS[negative_control]}'
                              ' at tests/extraction/mall_probe.dm:46')
                (target / 'result.txt').write_text(report + '\n')
                (target / 'stages.txt').write_text(run_mall.NETWORK_STAGE + '\n')
                (target / 'runtime.log').write_text(
                    NETWORK_LOG + (report + '\n' if negative_control else '') + diagnostic)
                kwargs['stdout'].write(BINDING.encode())
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
        if negative_control:
            argv.extend(['--negative-control', negative_control])
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
                         run_mall.PASS_RESULT + '\n')
        self.assertIn(run_mall.PASS_RESULT, self.stdout.getvalue())
        command = self.spawn.calls[-1][0]
        self.assertEqual(command[1:], ['probe.dmb', '-ip', '127.0.0.1', '-invisible',
                                      '-close', '-trusted', '-nowebclient',
                                      '-log', 'runtime.log'])

    def test_all_seven_mutations_reach_their_exact_oracle(self):
        for control, expected in CONTROLS.items():
            with self.subTest(control=control):
                self.invoke(negative_control=control)
                self.assertEqual(len(self.spawn.calls), 3)
                self.assertIn('PASS: negative control rejected at ' + expected,
                              self.stdout.getvalue())
                manifest = json.loads((self.owner.destination / 'manifest.json').read_text())
                self.assertEqual(manifest['negative_control'], control)
                self.assertEqual(manifest['outcome'], 'passed')

    def test_stair_return_mutation_only_omits_missing_reciprocal_guard(self):
        relative = Path('code/modules/1713/extraction/mall.dm')
        production = (HERE.parents[1] / relative).read_text()
        original = 'if (!return_stairs || return_stairs.destination_z != z) return FALSE'
        replacement = 'if (return_stairs && return_stairs.destination_z != z) return FALSE'
        self.assertEqual(production.count(original), 1)
        (self.root / relative).write_text(production)
        self.invoke(negative_control='stair_return', compile_only=True)
        self.assertEqual(self.compiled_metadata, production.replace(original, replacement, 1))
        self.assertEqual(self.compiled_metadata.count(replacement), 1)
        self.assertNotIn(original, self.compiled_metadata)
        self.assertIn('var/obj/structure/extraction_mall_stairs/return_stairs',
                      self.compiled_metadata)
        self.assertIn('return_stairs = A', self.compiled_metadata)
        self.assertEqual((self.root / relative).read_text(), production)
        self.assertEqual(len(self.spawn.calls), 2)

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
