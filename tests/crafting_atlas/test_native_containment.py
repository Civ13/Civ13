"""Injected supervisor tests only. No native binding, process or BYOND launch."""
import importlib.util
import ctypes
import json
from pathlib import Path
from types import SimpleNamespace
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT/'scripts'))
import native_fixture as fixture


def observation(**changes):
    return dict(exited=True, total=1, active=0, terminated=0, members=[], retained=1,
                private=0, watcher=1024**2, free=8*1024**3, sockets=[], cpu=0) | changes


class FakeBackend:
    def __init__(self, samples=None, exit_code=0, preflight=None, launch_error=False, cleanup_error=False):
        self.samples = list(samples or [observation()])
        self.exit_code = exit_code
        self.preflight = preflight or (1024**2, 8*1024**3)
        self.launch_error, self.cleanup_error = launch_error, cleanup_error
        self.launched, self.cleaned = False, False

    def open(self, timeout):
        pass

    def resources(self):
        return self.preflight

    def launch(self, argv, cwd, evidence, phase):
        if self.launch_error:
            raise RuntimeError('assignment failed before resume')
        self.launched = True
        (evidence/(phase+'.stdout.log')).write_text('native stdout')
        (evidence/(phase+'.stderr.log')).write_text('')
        return SimpleNamespace(pid=101)

    def identity(self, child):
        return dict(pid=child.pid, creation_filetime=123, image='fixture-only')

    def observe(self, child):
        return self.samples.pop(0) if len(self.samples) > 1 else self.samples[0]

    def finish(self, child):
        return dict(exit_code=self.exit_code, total_processes=1, active_processes=0)

    def cleanup(self, seconds):
        self.cleaned = True
        return dict(all_retained_exited=not self.cleanup_error, errors=['wait failure'] if self.cleanup_error else [],
                    total_assigned=1 if self.launched else 0,
                    exits=[dict(identity=dict(pid=101), exit_code=self.exit_code)] if self.launched else [])


class NativeContainmentTests(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory()
        self.root = Path(self.folder.name)
        self.clock = 0

    def tearDown(self):
        self.folder.cleanup()

    def session(self, backend):
        def pause(seconds):
            self.clock += seconds
        return fixture.Session(self.root/'evidence', 'a'*40, backend_factory=lambda: backend,
                               now=lambda: self.clock, pause=pause)

    def run_phase(self, session, **kwargs):
        return session.run(['injected-only', 'probe.dme'], cwd=self.root,
                           phase='compile', timeout=1, **kwargs)

    def test_retained_exit_and_zero_job_are_required_on_success(self):
        backend = FakeBackend([observation(exited=False, active=1, members=[101]), observation()])
        session = self.session(backend)
        result = self.run_phase(session)
        self.assertEqual(result.stdout, 'native stdout')
        self.assertTrue(backend.cleaned)
        receipt = json.loads((session.evidence/'containment.json').read_text())
        self.assertTrue(receipt['phases'][0]['owned_exit_evidence_complete'])
        self.assertTrue(receipt['phases'][0]['accepted'])

    def test_real_backend_configures_hard_memory_one_process_and_kill_on_close(self):
        spec = importlib.util.spec_from_file_location('inert_windows', ROOT/'tests/floor_decal_tracking/windows.py')
        windows = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(windows)
        captured = []
        def set_limits(job, kind, pointer, length):
            value = ctypes.cast(pointer, ctypes.POINTER(windows.JobLimits)).contents
            captured.append((job, kind, value.basic.flags, value.basic.active,
                             value.process_memory, value.job_memory, value.basic.job_time))
            return True
        adapter = SimpleNamespace(open=lambda: None, job=77,
            k=SimpleNamespace(SetInformationJobObject=set_limits), check=lambda result: self.assertTrue(result))
        backend = fixture.WindowsBackend(adapter=adapter, windows=windows, owned=SimpleNamespace())
        backend.open(120)
        self.assertEqual(captured, [(77, 9, 0x230C, 1, fixture.CHILD_CAP, fixture.CHILD_CAP, 120*10_000_000)])

    def test_real_backend_waits_retained_handles_and_checks_every_close(self):
        spec = importlib.util.spec_from_file_location('inert_windows', ROOT/'tests/floor_decal_tracking/windows.py')
        windows = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(windows)
        calls = []
        def code(handle, pointer):
            ctypes.cast(pointer, ctypes.POINTER(windows.w.DWORD)).contents.value = 0
            return True
        adapter = SimpleNamespace(job=77, retained=[SimpleNamespace(process=101, thread=102)],
            accounting=lambda: SimpleNamespace(total=1),
            identity=lambda child: dict(pid=101, creation_filetime=123, image='inert'),
            check=lambda value: self.assertTrue(value),
            k=SimpleNamespace(TerminateJobObject=lambda job, code: calls.append(('kill-job', job)) or True,
                CloseHandle=lambda handle: calls.append(('close', handle)) or True,
                WaitForSingleObject=lambda handle, timeout: calls.append(('wait', handle)) or 0,
                GetExitCodeProcess=code))
        backend = fixture.WindowsBackend(adapter=adapter, windows=windows, owned=SimpleNamespace())
        result = backend.cleanup(1)
        self.assertTrue(result['all_retained_exited'])
        self.assertEqual(calls, [('kill-job', 77), ('close', 77), ('wait', 101), ('close', 102), ('close', 101)])

    def test_short_lived_unretained_child_fails_even_when_job_is_empty(self):
        backend = FakeBackend([observation(total=2)])
        session = self.session(backend)
        with self.assertRaisesRegex(RuntimeError, 'cleanup/exit accounting incomplete'):
            self.run_phase(session)
        row = session.phases[0]
        self.assertIn('cumulative Job process', row['error'])
        self.assertFalse(row['owned_exit_evidence_complete'])
        self.assertFalse(row['accepted'])
        self.assertTrue(backend.cleaned)

    def test_unexpected_live_member_fails_and_preserves_observation(self):
        backend = FakeBackend([observation(exited=False, total=2, active=1, members=[202])])
        session = self.session(backend)
        with self.assertRaises(RuntimeError):
            self.run_phase(session)
        self.assertEqual(session.phases[0]['samples'][0]['members'], [202])
        self.assertTrue(backend.cleaned)

    def test_memory_and_host_floor_fail_before_launch(self):
        for values in [(fixture.WATCHER_CAP+1, 8*1024**3), (1, fixture.FREE_FLOOR-1)]:
            backend = FakeBackend(preflight=values)
            with tempfile.TemporaryDirectory() as folder:
                session = fixture.Session(Path(folder)/'e', 'a'*40, backend_factory=lambda: backend)
                with self.assertRaisesRegex(RuntimeError, 'preflight memory'):
                    self.run_phase(session)
                self.assertFalse(backend.launched)
                self.assertTrue(backend.cleaned)

    def test_each_sample_rejects_socket_memory_and_job_limit_controls(self):
        for changed in [dict(private=fixture.CHILD_CAP+1), dict(watcher=fixture.WATCHER_CAP+1),
                        dict(free=fixture.FREE_FLOOR-1), dict(terminated=1), dict(active=2),
                        dict(sockets=[dict(state='listen', address='127.0.0.1', port=12345)]),
                        dict(sockets=[dict(protocol='udp')])]:
            with self.assertRaises(RuntimeError):
                fixture.validate_sample(observation(**changed), 101)

    def test_phase_deadline_terminates_only_owned_backend(self):
        backend = FakeBackend([observation(exited=False, active=1, members=[101])])
        session = self.session(backend)
        with self.assertRaisesRegex(RuntimeError, 'deadline'):
            self.run_phase(session)
        self.assertTrue(backend.cleaned)
        self.assertTrue(session.failed)

    def test_assignment_failure_still_invokes_owned_cleanup(self):
        backend = FakeBackend(launch_error=True)
        with self.assertRaisesRegex(RuntimeError, 'assignment failed'):
            self.run_phase(self.session(backend))
        self.assertTrue(backend.cleaned)

    def test_failed_launch_cannot_skip_cumulative_cleanup_accounting(self):
        backend = FakeBackend(launch_error=True)
        cleanup = backend.cleanup
        backend.cleanup = lambda seconds: cleanup(seconds) | {'total_assigned': 2}
        session = self.session(backend)
        with self.assertRaisesRegex(RuntimeError, 'cleanup/exit accounting incomplete'):
            self.run_phase(session)
        self.assertFalse(session.phases[0]['owned_exit_evidence_complete'])

    def test_cleanup_failure_prevents_next_launch(self):
        backend = FakeBackend(cleanup_error=True)
        session = self.session(backend)
        with self.assertRaisesRegex(RuntimeError, 'cleanup/exit accounting'):
            self.run_phase(session)
        with self.assertRaisesRegex(RuntimeError, 'Session failed'):
            self.run_phase(session)
        self.assertEqual(len(session.phases), 1)

    def test_nonzero_exit_marks_session_failed(self):
        session = self.session(FakeBackend(exit_code=7))
        self.assertEqual(self.run_phase(session).returncode, 7)
        self.assertTrue(session.failed)

    def test_four_launch_limit_and_no_concurrent_fallback(self):
        session = self.session(FakeBackend())
        for i in range(4):
            session.run(['injected'], cwd=self.root, phase='p'+str(i), timeout=1)
        with self.assertRaisesRegex(RuntimeError, 'launch-count'):
            self.run_phase(session)
        session.busy = True
        with self.assertRaises(RuntimeError):
            self.run_phase(session)

    def test_aggregate_deadline_prevents_launch(self):
        backend = FakeBackend()
        session = self.session(backend)
        self.clock = 330
        with self.assertRaisesRegex(RuntimeError, 'Aggregate work deadline'):
            self.run_phase(session)
        self.assertFalse(backend.launched)

    def test_terminal_total_counter_cannot_be_replaced_by_empty_membership(self):
        backend = FakeBackend()
        backend.finish = lambda child: dict(exit_code=0, active_processes=0, total_processes=2)
        session = self.session(backend)
        with self.assertRaisesRegex(RuntimeError, 'Terminal cumulative'):
            self.run_phase(session)
        self.assertFalse(session.phases[0]['accepted'])

    def test_bounded_reads_and_generated_output_controls(self):
        path = self.root/'oversized.txt'
        path.write_bytes(b'123456789')
        with self.assertRaisesRegex(RuntimeError, 'read bound'):
            fixture.read_bounded(path, 8)
        with patch.object(fixture, 'LOG_CAP', 8):
            with self.assertRaisesRegex(RuntimeError, 'evidence budget'):
                fixture.output_bounds(self.root, ())
        path.unlink()
        resource = self.root/'probe.rsc'
        resource.write_bytes(b'123456789')
        with patch.object(fixture, 'ARTIFACT_CAP', 8):
            with self.assertRaisesRegex(RuntimeError, 'artifact budget'):
                fixture.output_bounds(self.root, [resource])

    def test_windows_cannot_fall_back_to_uncontained_subprocess(self):
        with patch.object(fixture, 'os', SimpleNamespace(name='nt')), patch.object(fixture.subprocess, 'run') as run:
            with self.assertRaisesRegex(RuntimeError, 'contained Session'):
                fixture.run_native(None, ['not-executed'], cwd=self.root, phase='x', timeout=1)
            run.assert_not_called()

    def test_loopback_args_and_both_fixtures_deny_opening(self):
        self.assertEqual(fixture.no_port_args(), ['-ip', '127.0.0.1', '-nowebclient'])
        for relative in ['tests/animal_harvest/probe.dm', 'tests/crafting_atlas/probe.dm', 'tests/crafting_atlas/full_probe.dm']:
            source = (ROOT/relative).read_text()
            startup = source.split('/world/New()')[1]
            self.assertLess(startup.index('OpenPort("none")'), startup.index('!world.port && !OpenPort(12345)'))
            self.assertIn('"port-closed.txt"', startup)
        for relative in ['tests/animal_harvest/probe.dm', 'tests/crafting_atlas/probe.dm', 'tests/crafting_atlas/full_probe.dm']:
            body = (ROOT/relative).read_text().split('/world/OpenPort(port)')[1]
            self.assertIn('if (port == "none")\n\t\treturn ..()\n\treturn FALSE', body)

    def test_four_phase_driver_accepts_only_complete_sequence_without_native_calls(self):
        spec = importlib.util.spec_from_file_location('tanning_driver', ROOT/'tests/animal_harvest/validate_tanning.py')
        driver = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(driver)
        binaries = self.root/'bin'
        binaries.mkdir()
        for name in ('dm.exe', 'dd.exe'):
            (binaries/name).write_bytes(b'inert test data; never executed')
        sessions = []
        def session_factory(path, head):
            session = fixture.Session(path, head, backend_factory=FakeBackend)
            sessions.append(session)
            return session
        def runner(relative, name):
            phases = ['atlas-compile', 'atlas-runtime'] if 'atlas' in relative else ['harvest-compile', 'harvest-runtime']
            def main(argv, session):
                for phase in phases:
                    session.run(['injected'], cwd=self.root, phase=phase, timeout=1)
            return SimpleNamespace(main=main)
        with patch.object(driver, 'os', SimpleNamespace(name='nt')), patch.object(driver, 'Session', session_factory), \
             patch.object(driver, 'load', runner), patch.object(driver.subprocess, 'check_output', return_value='a'*40), \
             patch.object(driver.subprocess, 'run'), patch.object(sys, 'argv', ['driver', '--expected-commit', 'a'*40,
                 '--byond-bin', str(binaries), '--output', str(self.root/'four')]):
            driver.main()
        self.assertEqual([p['phase'] for p in sessions[0].phases], ['atlas-compile', 'atlas-runtime', 'harvest-compile', 'harvest-runtime'])
        self.assertTrue((self.root/'four/accepted.txt').exists())


if __name__ == '__main__':
    unittest.main()
