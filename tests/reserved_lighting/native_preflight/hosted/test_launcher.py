"""Injected source tests only: no systemd, mount, cgroup or network operations."""
import copy
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock
import hashlib

spec = importlib.util.spec_from_file_location('launcher', Path(__file__).with_name('launcher.py'))
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)


def request(): return {'owner': 'a'*32, 'adapter_sha256': 'b'*64, 'launcher_sha256': 'c'*64, 'peer_ip': '8.8.8.8'}


def row(value):
    return {'Description': m.description(value), 'InvocationID': 'd'*32, 'ControlGroup': '/system.slice/'+m.unit_name(value),
            'MainPID': '1234', 'ActiveState': 'active', 'MemoryMax': '268435456', 'MemorySwapMax': '0', 'TasksMax': '16',
            'CPUQuotaPerSecUSec': '1s', 'RuntimeMaxUSec': '2min', 'TimeoutStopUSec': '5s', 'KillMode': 'control-group',
            'NoNewPrivileges': 'yes', 'ProtectSystem': 'strict', 'ProtectHome': 'yes', 'User': '1001', 'IPAddressAllow': '8.8.8.8/32',
            'IPAddressDeny': '0.0.0.0/0 ::/0', 'SocketBindDeny': 'any'}


class Clock:
    now = 1000.
    def __call__(self): return self.now


class Backend:
    def __init__(self, value):
        self.row, self.started, self.gated, self.stopped, self.reaped = row(value), 0, 0, 0, 0
        self.absent = True
    def show(self, *args): return None if self.absent else self.row.copy()
    def start(self, args): self.started += 1; self.absent = False
    def retain(self, value): return {'pid': 1234, 'start': '100', 'mount_ns': 'mnt:[1]', 'cgroup_ino': 1, 'cgroup_dev': 1}
    def network(self, identity, timeout): return [{'id': 123, 'attach_type': 'egress'}]
    def gate(self): self.gated += 1
    def collect(self, timeout): return 0, json.dumps({'complete': True, 'status': 'CANDIDATE_IDENTITIES_ONLY_REQUIRES_REVIEW', 'native_count': 0}).encode()
    def stop(self, name, timeout): self.stopped += 1
    def retired(self, identity): return True
    def reap(self, timeout): self.reaped += 1; return True


class Launcher(unittest.TestCase):
    def test_seccomp_policy_semantics_with_injected_interpreter_and_kernel(self):
        def evaluate(number, socket_type=1, protocol=0, architecture=0xc000003e, family=2):
            words = {0:number,4:architecture,16:family,24:socket_type,32:protocol}
            instructions = m.socket_filter(); pc, value = 0, 0
            for _ in range(64):
                code, jt, jf, k = instructions[pc]
                if code == 0x20: value = words[k]
                elif code == 0x54: value &= k
                elif code == 0x15: pc += jt if value == k else jf
                elif code == 0x35: pc += jt if value >= k else jf
                elif code == 0x06: return k
                else: self.fail('Unknown reviewed BPF opcode')
                pc += 1
            self.fail('Unterminated BPF program')
        for flags in (0, 0x800, 0x80000, 0x80800):
            for protocol in (0,6): self.assertEqual(evaluate(41, 1|flags, protocol), 0x7fff0000)
        for kind, protocol in ((2,17),(3,0),(5,0),(1,132),(1,17)):
            self.assertEqual(evaluate(41, kind, protocol), 0x5000d)
        self.assertEqual(evaluate(53), 0x5000d)
        self.assertEqual(evaluate(41, family=10), 0x7fff0000)
        for family in (1,17,0): self.assertEqual(evaluate(41, family=family), 0x5000d)
        self.assertEqual(evaluate(0x40000029), 0x80000000)
        self.assertEqual(evaluate(41, architecture=0x40000003), 0x80000000)
        self.assertEqual(evaluate(0), 0x7fff0000)
        libc = mock.Mock(); libc.prctl.return_value = 0
        self.assertEqual(m.restrict_socket_types(libc, machine='x86_64')['protocols'], [0,6])
        self.assertEqual(libc.prctl.call_args.args[2]._obj.length, len(m.socket_filter()))
        libc.prctl.return_value = -1
        with self.assertRaisesRegex(ValueError, 'installation'): m.restrict_socket_types(libc, machine='x86_64')
    def test_actual_execute_slow_staging_is_charged_before_creation(self):
        adapter = m.load_adapter()
        for phase in ('positive', 'monotonic', 'utc'):
            value, clock, utc = request(), Clock(), Clock()
            value.update(scope=adapter.SCOPE, url=adapter.URL, limits=dict(adapter.LIMITS), head='e'*40,
                         executor='injected', run_id='12345', image_count=0, compile_count=0, daemon_count=0, package_install_count=0,
                         adapter_sha256=hashlib.sha256(Path(adapter.__file__).read_bytes()).hexdigest(),
                         launcher_sha256=hashlib.sha256(Path(m.__file__).read_bytes()).hexdigest())
            grant = {'scope': adapter.SCOPE, 'granted': True, 'head': value['head'], 'executor': value['executor'],
                     'request_sha256': adapter.sha(adapter.canonical(value)), 'run_id': '12345', 'starts': 999., 'ends': 1135.,
                     'external_controls_reviewed': True}
            environment = {'GITHUB_ACTIONS': 'true', 'GITHUB_EVENT_NAME': 'workflow_dispatch', 'GITHUB_REPOSITORY': 'Civ13/Civ13',
                           'GITHUB_REPOSITORY_ID': '141349998', 'GITHUB_SHA': value['head'], 'RUNNER_ENVIRONMENT': 'github-hosted',
                           'RUNNER_OS': 'Linux', 'GITHUB_RUN_ATTEMPT': '1', 'GITHUB_RUN_ID': '12345'}
            backend = Backend(value)
            def staged(*args):
                if phase == 'monotonic': clock.now += 6
                if phase == 'utc': utc.now += 6
            with mock.patch.dict(m.os.environ, environment), mock.patch.object(adapter, 'hosted_identity'), \
                 mock.patch.object(m.time, 'monotonic', clock), mock.patch.object(m.time, 'time', utc), \
                 mock.patch.object(m, 'stage_once', staged), mock.patch.object(m, 'Systemd', return_value=backend), \
                 mock.patch.object(m.os, 'geteuid', return_value=1001, create=True), mock.patch.object(m.os, 'getegid', return_value=1001, create=True):
                if phase == 'positive': self.assertTrue(m.execute(value, grant, adapter)['complete'])
                else:
                    with self.assertRaisesRegex(ValueError, 'reserve'): m.execute(value, grant, adapter)
                    self.assertEqual((backend.started, backend.gated), (0, 0), phase)

    def test_helper_timeout_uncertain_reap_preserves_primary_and_no_extension(self):
        process = mock.Mock(); process.stdout.fileno.return_value = 42; process.poll.return_value = None
        process.wait.side_effect = subprocess.TimeoutExpired('injected', 0)
        clock = Clock()
        def tick(*args): clock.now += .3; return [], [], []
        with mock.patch.object(m.os, 'set_blocking'), mock.patch.object(m.select, 'select', tick):
            with self.assertRaisesRegex(TimeoutError, 'deadline') as raised:
                m.bounded_helper(['injected'], 1, popen=mock.Mock(return_value=process), clock=clock)
        self.assertIn('Additional helper cleanup failure', raised.exception.__notes__[0])
        process.kill.assert_called_once()
        self.assertEqual(process.wait.call_args.kwargs['timeout'], 0)
    def test_actual_orchestration_widened_peer_never_opens_gate(self):
        for widened in ('8.8.8.8/32 0.0.0.0/0 ::/0', '8.8.8.8/32 1.1.1.1/32', '8.8.8.8/24'):
            value, clock = request(), Clock(); backend = Backend(value); backend.row['IPAddressAllow'] = widened
            result = m.launch(value, [], backend, 1001, clock)
            self.assertFalse(result['complete'], widened); self.assertEqual(backend.gated, 0)
            self.assertEqual(backend.stopped, 1)

    def test_actual_orchestration_late_entry_never_starts_unit(self):
        value, clock = request(), Clock(); backend = Backend(value)
        with self.assertRaisesRegex(ValueError, 'reserve'):
            m.launch(value, [], backend, 1001, clock, deadline=clock()+5)
        self.assertEqual((backend.started, backend.gated, backend.stopped), (0, 0, 0))

    def test_delayed_precheck_and_utc_jump_refuse_creation_and_late_gate(self):
        for phase in ('precheck', 'utc_before_start', 'utc_before_gate'):
            value, clock, utc = request(), Clock(), Clock(); backend = Backend(value)
            old_show, old_network = backend.show, backend.network
            def delayed(*args):
                result = old_show(*args)
                if result is None:
                    if phase == 'precheck': clock.now += 6
                    if phase == 'utc_before_start': utc.now += 6
                return result
            def late_network(*args):
                if phase == 'utc_before_gate': utc.now += 11
                return old_network(*args)
            backend.show, backend.network = delayed, late_network
            if phase == 'utc_before_gate':
                result = m.launch(value, [], backend, 1001, clock, utc_deadline=1135, utc=utc)
                self.assertFalse(result['complete']); self.assertEqual((backend.started, backend.gated, backend.stopped), (1, 0, 1))
            else:
                with self.assertRaisesRegex(ValueError, 'reserve'):
                    m.launch(value, [], backend, 1001, clock, utc_deadline=1135, utc=utc)
                self.assertEqual((backend.started, backend.gated, backend.stopped), (0, 0, 0))

    def test_home_is_inaccessible_and_only_public_stage_is_rebound(self):
        value = request()
        environment = dict.fromkeys(('GITHUB_ACTIONS','GITHUB_EVENT_NAME','GITHUB_REPOSITORY','GITHUB_REPOSITORY_ID',
                                    'GITHUB_SHA','RUNNER_ENVIRONMENT','RUNNER_OS','GITHUB_RUN_ATTEMPT','GITHUB_RUN_ID'), 'safe')
        args = m.command(value, '/tmp/civ13-capture-src-'+value['owner'], 1001, 1001, environment)
        self.assertIn('--property=ProtectHome=yes', args)
        self.assertNotIn('--property=ProtectHome=read-only', args)
        self.assertEqual([x for x in args if x.startswith('--property=BindReadOnlyPaths=')],
                         ['--property=BindReadOnlyPaths=/tmp/civ13-capture-src-'+value['owner']])

    def test_real_helper_stream_stops_at_bound_and_reaps_direct_process(self):
        process = mock.Mock(); process.stdout.fileno.return_value = 42; process.poll.return_value = None; process.wait.return_value = 0
        read = mock.Mock(side_effect=lambda fd, n: b'x'*n)
        with mock.patch.object(m.os, 'set_blocking'), mock.patch.object(m.select, 'select', return_value=([42], [], [])), mock.patch.object(m.os, 'read', read):
            with self.assertRaisesRegex(ValueError, 'overflow'):
                m.bounded_helper(['injected'], 1, popen=mock.Mock(return_value=process), clock=Clock())
        self.assertEqual(read.call_args.args[1], 32769)
        process.kill.assert_called_once(); process.wait.assert_called_once(); process.stdout.close.assert_called_once()

    def test_all_three_actual_helpers_use_streaming_not_postcapture_limits(self):
        for name in ('show', 'network', 'stop'):
            with self.subTest(name=name):
                observed, failure = [], None
                def streamed(args, timeout):
                    observed.append((args, timeout))
                    if name == 'show': payload = b'LoadState=not-found\n'
                    elif name == 'network': payload = json.dumps([{'id': i+1, 'attach_type': t} for i, t in enumerate(('ingress','egress','bind4','bind6'))]).encode()
                    else: payload = b''
                    return subprocess.CompletedProcess(args, 0, payload, b'')
                with mock.patch.object(m, 'bounded_helper', streamed, create=True), mock.patch.object(m.subprocess, 'run', side_effect=AssertionError('unbounded capture_output')):
                    try:
                        backend = m.Systemd()
                        if name == 'show': backend.show('injected', 1)
                        elif name == 'network': backend.network({'ControlGroup':'/injected'}, 1)
                        else: backend.stop('injected', 1)
                    except BaseException as caught: failure = caught
                self.assertIsNone(failure, str(failure)); self.assertEqual(len(observed), 1)
    def test_landlock_real_policy_builder_with_injected_syscalls_and_failure(self):
        libc = mock.Mock(); libc.syscall.side_effect = [4, 9, 0, 0]; libc.prctl.return_value = 0
        closed = mock.Mock()
        result = m.restrict_ports(libc=libc, close=closed, machine='x86_64')
        self.assertEqual(result['connect_tcp_ports'], [443]); closed.assert_called_once_with(9)
        calls = libc.syscall.call_args_list
        self.assertEqual(calls[1].args[1]._obj.net, 3)
        self.assertEqual((calls[2].args[3]._obj.access, calls[2].args[3]._obj.port), (2, 443))
        self.assertEqual(calls[-1].args, (446, 9, 0))
        libc = mock.Mock(); libc.syscall.side_effect = [3]
        with self.assertRaisesRegex(ValueError, 'ABI4'): m.restrict_ports(libc, machine='x86_64')
        libc.prctl.assert_not_called()
        libc = mock.Mock(); libc.syscall.side_effect = [4, 9, -1]
        closed = mock.Mock(side_effect=OSError('close error'))
        with self.assertRaisesRegex(ValueError, 'rule failed') as raised: m.restrict_ports(libc, close=closed, machine='x86_64')
        self.assertIn('close error', raised.exception.__notes__[0]); closed.assert_called_once_with(9)
    def test_atomic_stage_collision_preserves_external_single_use_record(self):
        with tempfile.TemporaryDirectory() as temporary:
            stage = Path(temporary)/'fresh'
            files = {name: b'original' for name in ('adapters.py', 'launcher.py', 'request.json', 'grant.json', 'USED')}
            m.stage_once(stage, files)
            with self.assertRaises(FileExistsError): m.stage_once(stage, dict(files, USED=b'replacement'))
            self.assertEqual((stage/'USED').read_bytes(), b'original')
            for file in stage.iterdir(): file.chmod(0o600)
            with self.assertRaises(ValueError): m.stage_once(Path(temporary)/'escape', {'../escape': b'bad'})
    def test_default_cli_inert(self):
        result = subprocess.run([sys.executable, '-B', m.__file__], capture_output=True, text=True, check=True)
        self.assertEqual(json.loads(result.stdout)['status'], 'INERT_NO_LAUNCH')

    def test_profile_has_all_hard_bounds_and_no_shell_credentials_or_image(self):
        value = request()
        env = {'GITHUB_ACTIONS': 'true', 'GITHUB_EVENT_NAME': 'workflow_dispatch', 'GITHUB_REPOSITORY': 'Civ13/Civ13',
               'GITHUB_REPOSITORY_ID': '141349998', 'GITHUB_SHA': 'e'*40, 'RUNNER_ENVIRONMENT': 'github-hosted',
               'RUNNER_OS': 'Linux', 'GITHUB_RUN_ATTEMPT': '1', 'GITHUB_RUN_ID': '12345', 'SECRET': 'never-forward'}
        args = m.command(value, '/tmp/civ13-capture-src-'+value['owner'], 1001, 1001, env)
        for setting in ('MemoryMax=268435456', 'MemorySwapMax=0', 'TasksMax=16', 'CPUQuota=100%', 'RuntimeMaxSec=120s',
                        'TimeoutStopSec=5s', 'KillMode=control-group', 'LimitCPU=20', 'ProtectSystem=strict',
                        'IPAddressDeny=any', 'IPAddressAllow=8.8.8.8', 'SocketBindDeny=any', 'CapabilityBoundingSet='):
            self.assertIn('--property='+setting, args)
        self.assertFalse(any('never-forward' in part for part in args))
        self.assertFalse(any('StandardOutput=inherit' in part or 'journal' in part for part in args))
        self.assertIn('--pipe', args); self.assertIn('--property=BindReadOnlyPaths=/tmp/civ13-capture-src-'+value['owner'], args)
        self.assertFalse(any(part in ('docker', 'sh', '-c') for part in args))

    def test_actual_orchestration_exact_gate_and_owned_retirement(self):
        value, clock = request(), Clock(); backend = Backend(value)
        result = m.launch(value, [], backend, 1001, clock)
        self.assertTrue(result['complete'], result)
        self.assertEqual((backend.started, backend.gated, backend.stopped, backend.reaped), (1, 1, 1, 1))
        self.assertEqual(result['worker_identity']['start'], '100')

    def test_normal_retired_systemd_empty_cgroup_uses_original_identity_without_signal(self):
        for changed in (False, True):
            value, clock = request(), Clock(); backend = Backend(value)
            old_collect = backend.collect
            def retired(timeout):
                backend.row.update(ActiveState='inactive', MainPID='0', ControlGroup='')
                if changed: backend.row['InvocationID'] = 'f'*32
                return old_collect(timeout)
            backend.collect = retired
            result = m.launch(value, [], backend, 1001, clock)
            self.assertEqual(result['complete'], not changed, result)
            self.assertEqual(backend.stopped, 0)
            if changed: self.assertIn('changed', result['cleanup_error'])

    def test_readback_drift_stops_owned_unit_without_opening_capture_gate(self):
        for key, changed in [('MemoryMax', 'max'), ('MemorySwapMax', 'max'), ('TasksMax', '32'),
                             ('IPAddressAllow', '1.1.1.1/32'), ('IPAddressDeny', ''), ('SocketBindDeny', '')]:
            value, clock = request(), Clock(); backend = Backend(value); backend.row[key] = changed
            result = m.launch(value, [], backend, 1001, clock)
            self.assertFalse(result['complete'], key)
            self.assertEqual((backend.started, backend.gated, backend.stopped, backend.reaped), (1, 0, 1, 1), key)

    def test_preexisting_collision_and_unknown_create_never_signal_or_retry(self):
        value, clock = request(), Clock(); backend = Backend(value); backend.absent = False
        with self.assertRaisesRegex(ValueError, 'Preexisting'): m.launch(value, [], backend, 1001, clock)
        self.assertEqual((backend.started, backend.stopped), (0, 0))
        backend = Backend(value)
        def failed(args): backend.started += 1; raise OSError('uncertain start')
        backend.start = failed
        result = m.launch(value, [], backend, 1001, clock)
        self.assertIn('uncertain start', result['error']); self.assertIn('Unknown', result['cleanup_error'])
        self.assertEqual((backend.started, backend.gated, backend.stopped, backend.reaped), (1, 0, 0, 1))

    def test_uncertain_owned_start_reconciles_for_cleanup_only(self):
        value, clock = request(), Clock(); backend = Backend(value)
        def failed(args): backend.started += 1; backend.absent = False; raise OSError('original start error')
        backend.start = failed
        result = m.launch(value, [], backend, 1001, clock)
        self.assertEqual(result['error'], 'original start error'); self.assertFalse(result['complete'])
        self.assertEqual((backend.started, backend.gated, backend.stopped, backend.reaped), (1, 0, 1, 1))

    def test_missing_actual_bpf_readback_keeps_gate_closed_and_cleans_owner(self):
        value, clock = request(), Clock(); backend = Backend(value)
        def missing(*args): raise ValueError('actual BPF unavailable')
        backend.network = missing
        result = m.launch(value, [], backend, 1001, clock)
        self.assertFalse(result['complete']); self.assertIn('BPF unavailable', result['error'])
        self.assertEqual((backend.gated, backend.stopped, backend.reaped), (0, 1, 1))

    def test_invocation_replacement_refuses_stop_and_preserves_original(self):
        value, clock = request(), Clock(); backend = Backend(value)
        def failed(timeout):
            backend.row['InvocationID'] = 'f'*32
            raise ValueError('original worker failure')
        backend.collect = failed
        result = m.launch(value, [], backend, 1001, clock)
        self.assertIn('original worker failure', result['error']); self.assertIn('changed', result['cleanup_error'])
        self.assertEqual((backend.started, backend.stopped, backend.reaped), (1, 0, 1))

    def test_outer_deadline_includes_cleanup_and_fresh_preflight_reserve(self):
        for phase in ('preflight', 'cleanup'):
            value, clock = request(), Clock(); backend = Backend(value)
            if phase == 'preflight':
                old = backend.show
                def slow(*args):
                    value = old(*args)
                    if value is not None: clock.now += 130
                    return value
                backend.show = slow
            else:
                old = backend.retired
                def slow(identity): clock.now += 136; return old(identity)
                backend.retired = slow
            result = m.launch(value, [], backend, 1001, clock)
            self.assertFalse(result['complete'], phase)
            if phase == 'preflight': self.assertEqual(backend.gated, 0)


if __name__ == '__main__': unittest.main()
