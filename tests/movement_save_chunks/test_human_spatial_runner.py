"""Offline synthetic contracts; all child-process operations are mocked."""
from pathlib import Path
import importlib.util
import json
import shutil
import tempfile
import time
import unittest
from unittest import mock

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('human_spatial_runner', HERE / 'human_spatial_run.py')
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


class RunnerTests(unittest.TestCase):
    def test_exact_capsule_and_generation_across_fresh_reader(self):
        head = 'a' * 40
        capsule = dict(x=1, y=1, z=1, sx=4, sy=6)
        writer = dict(phase='writer', head=head, byond_version=516, byond_build=1688,
                      port=0, error=None, mode='restart', handoffs=1,
                      pulses_after_handoff=2, capsule=capsule, generation='round-v1:' + 'a' * 32)
        expected = runner.writer_receipt(writer, head, 'restart')
        reader = dict(phase='reader', head=head, byond_version=516, byond_build=1688,
                      port=0, error=None, generation=expected['generation'], position=capsule.copy())
        runner.reader_receipt(reader, head, expected)
        reader['position']['sx'] += 1
        with self.assertRaisesRegex(RuntimeError, 'capsule or generation'):
            runner.reader_receipt(reader, head, expected)
        reader['position'] = capsule.copy()
        reader['generation'] = 'round-v1:other'
        with self.assertRaisesRegex(RuntimeError, 'capsule or generation'):
            runner.reader_receipt(reader, head, expected)

    def test_named_controls_and_finite_output_budget(self):
        self.assertEqual(set(runner.NEGATIVES), {'wall', 'dense', 'contained', 'buckle', 'roster', 'pulling', 'duplicate', 'missing_roster', 'unsafe_default'})
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / 'a').write_bytes(b'1234')
            self.assertEqual(runner.inventory(root)['a']['bytes'], 4)
            with self.assertRaisesRegex(RuntimeError, 'output budget'):
                runner.inventory(root, total_limit=3)

    def test_rejected_candidate_cannot_publish_new_marker_with_old_backup(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            seed, current, backup = (root / name for name in ('seed', 'current', 'backup'))
            seed.mkdir()
            (seed / 'save_complete.txt').write_bytes(b'round-v1:old')
            (seed / '1.sav').write_bytes(b'old synthetic generation')
            shutil.copytree(seed, backup)
            current.mkdir()
            (current / 'save_complete.txt').write_bytes(b'round-v1:new')
            with self.assertRaisesRegex(RuntimeError, 'published a different current marker'):
                runner.negative_publication(current, backup, seed)
            (current / 'save_complete.txt').unlink()
            runner.negative_publication(current, backup, seed)
            (current / 'save_complete.txt').write_bytes(b'round-v1:old')
            with self.assertRaisesRegex(RuntimeError, 'current seed marker covers changed files'):
                runner.negative_publication(current, backup, seed)
            (current / '1.sav').write_bytes(b'old synthetic generation')
            runner.negative_publication(current, backup, seed)

    def test_unreviewed_head_or_scope_refuses_before_staging(self):
        head, scope = 'a' * 40, 'b' * 64
        with tempfile.TemporaryDirectory() as tmp, \
             mock.patch.object(runner.sys, 'platform', 'linux'), \
             mock.patch.object(runner.subprocess, 'check_output', return_value=(head + '\n').encode()), \
             mock.patch.object(runner.human_spatial_stage, 'review_scope', return_value={'sha256': scope}), \
             mock.patch.object(runner.human_spatial_stage, 'stage') as stage:
            out = Path(tmp) / 'not-created'
            with self.assertRaisesRegex(RuntimeError, 'checkout differs'):
                runner.run(out, Path(tmp), Path(tmp), 'c' * 40, scope)
            with self.assertRaisesRegex(RuntimeError, 'source differs'):
                runner.run(out, Path(tmp), Path(tmp), head, 'd' * 64)
            stage.assert_not_called()
            self.assertFalse(out.exists())

    def test_final_acceptance_checks_deadline_after_negative_controls(self):
        source = (HERE / 'human_spatial_run.py').read_text()
        self.assertLess(source.index('negative_publication(work /'), source.index("require(time.monotonic() < job_deadline, 'native sequence deadline exceeded before final acceptance')"))
        self.assertLess(source.index("require(time.monotonic() < job_deadline, 'native sequence deadline exceeded before final acceptance')"), source.index("result['execution'] = 'passed'"))

    def test_owned_group_cleanup_when_monitor_rejects(self):
        child = mock.Mock(pid=123456, returncode=0)
        child.poll.return_value = None
        with tempfile.TemporaryDirectory() as tmp, \
             mock.patch.object(runner.legacy.subprocess, 'Popen', return_value=child) as popen, \
             mock.patch.object(runner.legacy.os, 'killpg', create=True) as killpg, \
             mock.patch.object(runner.legacy.signal, 'SIGKILL', 9, create=True):
            with self.assertRaisesRegex(RuntimeError, 'sample failure'):
                runner.legacy.run_process(['synthetic'], Path(tmp), 'test', 1,
                                          preexec_fn=runner.bounded_child,
                                          monitor=lambda *_: (_ for _ in ()).throw(RuntimeError('sample failure')))
            self.assertIs(popen.call_args.kwargs['preexec_fn'], runner.bounded_child)
            self.assertTrue(popen.call_args.kwargs['start_new_session'])
            killpg.assert_called_once()
            child.wait.assert_called_once()

    def test_retained_leader_is_reaped_only_after_group_cleanup(self):
        child = mock.Mock(pid=123456, returncode=0)
        events = []
        child.wait.side_effect = lambda **_: events.append('wait')
        with tempfile.TemporaryDirectory() as tmp, \
             mock.patch.object(runner.legacy.subprocess, 'Popen', return_value=child), \
             mock.patch.object(runner.legacy.os, 'waitid', return_value=object(), create=True), \
             mock.patch.object(runner.legacy.os, 'P_PID', 1, create=True), \
             mock.patch.object(runner.legacy.os, 'WEXITED', 4, create=True), \
             mock.patch.object(runner.legacy.os, 'WNOHANG', 1, create=True), \
             mock.patch.object(runner.legacy.os, 'WNOWAIT', 0x1000000, create=True), \
             mock.patch.object(runner.legacy.os, 'killpg', side_effect=lambda *_: events.append('kill'), create=True), \
             mock.patch.object(runner.legacy.signal, 'SIGKILL', 9, create=True):
            runner.legacy.run_process(['synthetic'], Path(tmp), 'test', 1, retain_leader=True)
            self.assertEqual(events, ['kill', 'wait'])
            child.poll.assert_not_called()

    def test_launch_records_failure_and_does_not_inherit_secrets(self):
        def fake_process(command, cwd, name, deadline, **kwargs):
            self.assertEqual(set(kwargs['env']), {'PATH', 'HOME', 'TMPDIR', 'LANG', 'LC_ALL', 'LD_LIBRARY_PATH'})
            self.assertTrue(kwargs['retain_leader'])
            kwargs['on_event']('spawn', 123)
            kwargs['monitor'](123, cwd)
            kwargs['on_event']('group_signal_sent', 123)
            kwargs['on_event']('wait', -9)
            raise RuntimeError('synthetic timeout')
        with tempfile.TemporaryDirectory() as tmp, \
             mock.patch.object(runner.legacy, 'run_process', side_effect=fake_process), \
             mock.patch.object(runner.benchmark, 'proc_memory', return_value={'rss_bytes': 1024}):
            cwd = Path(tmp)
            with self.assertRaisesRegex(RuntimeError, 'synthetic timeout'):
                runner.launch(['synthetic'], cwd, 'writer', 90, time.monotonic() + 100, cwd)
            trace = json.loads((cwd / 'writer-supervision.json').read_text())
            self.assertEqual(trace['status'], 'failed')
            self.assertEqual([e['event'] for e in trace['events']], ['spawn', 'group_signal_sent', 'wait'])
            self.assertEqual(trace['events'][-1]['value'], -9)
            self.assertEqual(trace['memory']['count'], 1)

    def test_missing_rss_is_tolerated_only_after_an_observed_exit(self):
        with tempfile.TemporaryDirectory() as tmp, \
             mock.patch.object(runner.benchmark, 'proc_memory', side_effect=[{'rss_bytes': 1024}, {}, {}]), \
             mock.patch.object(runner, 'child_exited_unreaped', side_effect=[True, False]):
            monitor, samples = runner.monitor_for(Path(tmp), time.monotonic() - 2, time.monotonic() + 10)
            monitor(123, Path(tmp))
            monitor(123, Path(tmp))
            self.assertEqual(samples['count'], 1)
            self.assertTrue(samples['rss_exit_race'])
            with self.assertRaisesRegex(RuntimeError, 'RSS sampling unavailable'):
                monitor(123, Path(tmp))

    def test_exit_without_any_memory_sample_still_fails(self):
        def fake_process(command, cwd, name, deadline, **kwargs):
            kwargs['monitor'](123, cwd)
            return {'returncode': 0}
        with tempfile.TemporaryDirectory() as tmp, \
             mock.patch.object(runner.legacy, 'run_process', side_effect=fake_process), \
             mock.patch.object(runner.benchmark, 'proc_memory', return_value={}):
            cwd = Path(tmp)
            with self.assertRaisesRegex(RuntimeError, 'RSS was not sampled'):
                runner.launch(['synthetic'], cwd, 'writer', 90, time.monotonic() + 100, cwd)


if __name__ == '__main__':
    unittest.main()
