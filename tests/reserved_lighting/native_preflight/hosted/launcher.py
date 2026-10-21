"""Source-only hosted capture launcher. Defaults to description, never a launch.

One future system service owns a private mount namespace and hard cgroup. The
worker blocks on an inherited pipe until the parent verifies that exact unit.
No Docker, package installation, image, compile or daemon action exists here.
"""
import argparse
import ctypes
import hashlib
import importlib.util
import json
import math
import os
from pathlib import Path
import re
import select
import signal
import subprocess
import sys
import time
import stat
import platform
import ipaddress

TOTAL = 135
PROPERTIES = ['LoadState', 'Description', 'InvocationID', 'ControlGroup', 'MainPID', 'ActiveState', 'MemoryMax',
              'MemorySwapMax', 'TasksMax', 'CPUQuotaPerSecUSec', 'RuntimeMaxUSec', 'TimeoutStopUSec',
              'KillMode', 'NoNewPrivileges', 'ProtectSystem', 'ProtectHome', 'User', 'SocketBindDeny', 'IPAddressAllow', 'IPAddressDeny']


def require(value, message):
    if not value: raise ValueError(message)


def unit_name(request):
    require(re.fullmatch('[0-9a-f]{32}', request.get('owner') or ''), 'Exact owner nonce')
    return 'civ13-capture-'+request['owner']+'.service'


def description(request): return 'Civ13 capture '+request['owner']+' '+request['adapter_sha256']


def owned_unit(request, row, previous=None):
    require(row.get('Description') == description(request) and re.fullmatch('[0-9a-f]{32}', row.get('InvocationID', '')), 'Exact owned service identity')
    if previous is not None and row.get('ActiveState') in ('inactive', 'failed') and row.get('ControlGroup') == '':
        # systemd v255 unit_prune_cgroup releases this property after a normal
        # empty retirement. Never adopt an empty identity at creation; reuse
        # only the earlier retained cgroup and matching invocation, then prove
        # that original worker/cgroup retired without signalling this row.
        require(row['Description'] == previous['Description'] and row['InvocationID'] == previous['InvocationID'], 'Owned unit invocation changed')
        return previous.copy()
    require(row.get('ControlGroup') == '/system.slice/'+unit_name(request), 'Exact owned service cgroup identity')
    identity = {key: row[key] for key in ('Description', 'InvocationID', 'ControlGroup')}
    require(previous is None or identity == previous, 'Owned unit invocation changed')
    return identity


def command(request, stage, uid, gid, environment):
    """Absolute tools, argv only, empty capability set, isolated service FS."""
    require(type(uid) is int and uid > 0 and type(gid) is int and gid >= 0, 'Nonroot worker UID')
    require(re.fullmatch('[0-9a-f]{64}', request.get('adapter_sha256') or '') and re.fullmatch('[0-9a-f]{64}', request.get('launcher_sha256') or ''), 'Frozen executable source hashes')
    stage = stage.as_posix() if isinstance(stage, Path) else str(stage)
    require(stage == '/tmp/civ13-capture-src-'+request['owner'], 'Exact public source stage')
    mount = '/run/civ13-capture-'+request['owner']
    args = ['/usr/bin/sudo', '-n', '/usr/bin/systemd-run', '--unit='+unit_name(request), '--description='+description(request), '--quiet', '--pipe', '--wait']
    settings = ['Type=exec', 'User='+str(uid), 'Group='+str(gid), 'MemoryMax=268435456', 'MemorySwapMax=0',
                'TasksMax=16', 'CPUQuota=100%', 'RuntimeMaxSec=120s', 'TimeoutStopSec=5s', 'KillMode=control-group',
                'LimitCPU=20', 'LimitCORE=0', 'LimitFSIZE=16777216', 'LimitNOFILE=64', 'NoNewPrivileges=yes',
                'CapabilityBoundingSet=', 'AmbientCapabilities=', 'ProtectSystem=strict', 'ProtectHome=yes',
                'PrivateDevices=yes', 'PrivateMounts=yes', 'ProtectKernelTunables=yes', 'ProtectKernelModules=yes',
                'ProtectControlGroups=yes', 'RestrictSUIDSGID=yes', 'RestrictNamespaces=yes', 'LockPersonality=yes',
                'RestrictAddressFamilies=AF_INET AF_INET6', 'SocketBindDeny=any', 'IPAddressDeny=any',
                'IPAddressAllow='+request['peer_ip'], 'UMask=0077', 'WorkingDirectory='+mount,
                'TemporaryFileSystem='+mount+':rw,size=16777216,mode=0700,uid='+str(uid)+',gid='+str(gid)+',noexec,nodev,nosuid',
                'TemporaryFileSystem=/tmp:ro', 'TemporaryFileSystem=/var/tmp:ro', 'BindReadOnlyPaths='+stage]
    # --pipe supplies the three explicit file descriptors; no journal output,
    # socket activation or StandardOutput=inherit alias of stdin is configured.
    args += ['--property='+value for value in settings]
    for key in ('GITHUB_ACTIONS', 'GITHUB_EVENT_NAME', 'GITHUB_REPOSITORY', 'GITHUB_REPOSITORY_ID', 'GITHUB_SHA',
                'RUNNER_ENVIRONMENT', 'RUNNER_OS', 'GITHUB_RUN_ATTEMPT', 'GITHUB_RUN_ID'):
        value = environment.get(key, '')
        require(value and re.fullmatch('[A-Za-z0-9_./-]+', value), 'Finite sanitized hosted identity environment')
        args.append('--setenv='+key+'='+value)
    args += ['/usr/bin/python3', '-I', '-B', stage+'/launcher.py', '--worker', '--request', stage+'/request.json', '--grant', stage+'/grant.json']
    return args


def verify_unit(request, row, uid, previous=None):
    identity = owned_unit(request, row, previous)
    require(str(row.get('MainPID', '')).isdigit()
            and int(row['MainPID']) > 0 and row.get('ActiveState') in ('activating', 'active'), 'Exact owned service identity')
    require(all(row.get(k) == v for k, v in {'MemoryMax': '268435456', 'MemorySwapMax': '0', 'TasksMax': '16',
            'CPUQuotaPerSecUSec': '1s', 'RuntimeMaxUSec': '2min', 'TimeoutStopUSec': '5s', 'KillMode': 'control-group',
            'NoNewPrivileges': 'yes', 'ProtectSystem': 'strict', 'ProtectHome': 'yes', 'User': str(uid)}.items()), 'Unit resource/protection readback drift')
    # Fail closed on systemd serialization changes; source flags alone do not
    # establish that IP/bind filters exist. Worker also checks actual cgroup and
    # denied loopback bind before TLS. Actual egress-BPF acceptance is pending.
    peer = ipaddress.ip_address(request['peer_ip'])
    require(row.get('IPAddressAllow', '').strip() == str(peer)+'/'+str(peer.max_prefixlen)
            and set(row.get('IPAddressDeny', '').split()) == {'0.0.0.0/0', '::/0'}
            and row.get('SocketBindDeny') == 'any', 'Exact IP/bind filter readback missing or widened')
    return identity


class Systemd:
    def __init__(self): self.process = None; self.retained = None

    def show(self, name, timeout):
        result = bounded_helper(['/usr/bin/systemctl', 'show', name, '--no-pager', '--property='+','.join(PROPERTIES)], timeout)
        if result.returncode and b'could not be found' in result.stderr: return None
        require(result.returncode == 0, 'Unit read failed: '+result.stderr.decode(errors='replace')[:256])
        row = dict(line.split('=', 1) for line in result.stdout.decode().splitlines() if '=' in line)
        return None if row.get('LoadState') == 'not-found' else row

    def start(self, args):
        self.process = subprocess.Popen(args, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, start_new_session=True)

    def gate(self): self.process.stdin.write(b'GO\n'); self.process.stdin.flush(); self.process.stdin.close()

    def retain(self, row):
        pid = int(row['MainPID']); proc = Path('/proc')/str(pid)
        record = (proc/'stat').read_text()
        start = record[record.rfind(')')+2:].split()[19]
        cgroup = Path('/sys/fs/cgroup'+row['ControlGroup'])
        self.retained = {'pid': pid, 'start': start, 'mount_ns': os.readlink(proc/'ns/mnt'),
                         'cgroup_dev': cgroup.stat().st_dev, 'cgroup_ino': cgroup.stat().st_ino}
        return self.retained.copy()

    def network(self, identity, timeout):
        result = bounded_helper(['/usr/bin/sudo', '-n', '/usr/sbin/bpftool', '-j', 'cgroup', 'show',
                                 '/sys/fs/cgroup'+identity['ControlGroup'], 'effective'], timeout)
        require(result.returncode == 0, 'Actual effective cgroup BPF observation unavailable')
        rows = json.loads(result.stdout)
        require(type(rows) is list and 0 < len(rows) <= 32, 'Bounded BPF attachment inventory')
        types = {row.get('attach_type') for row in rows}
        require({'ingress', 'egress', 'bind4', 'bind6'} <= types
                and all(type(row.get('id')) is int and row['id'] > 0 for row in rows), 'Effective IP/bind BPF hooks missing')
        return rows

    def collect(self, timeout):
        # Selector-bound reads, not communicate's unbounded in-memory capture.
        deadline, output = time.monotonic()+timeout, bytearray()
        fd = self.process.stdout.fileno(); os.set_blocking(fd, False)
        while time.monotonic() < deadline:
            ready, _, _ = select.select([fd], [], [], min(.1, max(0, deadline-time.monotonic())))
            if ready:
                block = os.read(fd, 65536)
                if not block:
                    return self.process.wait(timeout=max(.01, deadline-time.monotonic())), bytes(output)
                output.extend(block)
                require(len(output) <= 1024**2, 'Outer pipe output bound')
        raise TimeoutError('Outer capture collection deadline')

    def stop(self, name, timeout):
        result = bounded_helper(['/usr/bin/sudo', '-n', '/usr/bin/systemctl', 'stop', name], timeout)
        require(result.returncode == 0, 'Owned service stop incomplete')

    def retired(self, identity):
        # Unit's private mount namespace is destroyed when all its retained
        # processes are gone; the mount was never installed in the host view.
        require(self.retained is not None, 'No retained worker birth/cgroup identity')
        proc = Path('/proc')/str(self.retained['pid'])
        try:
            record = (proc/'stat').read_text()
            require(record[record.rfind(')')+2:].split()[19] != self.retained['start'], 'Original worker still alive')
        except FileNotFoundError: pass
        cgroup = Path('/sys/fs/cgroup'+identity['ControlGroup'])
        if not cgroup.exists(): return True
        require((cgroup.stat().st_dev, cgroup.stat().st_ino) == (self.retained['cgroup_dev'], self.retained['cgroup_ino']), 'Cgroup identity replaced')
        events = dict(line.split() for line in (cgroup/'cgroup.events').read_text().splitlines())
        return events.get('populated') == '0' and not (cgroup/'cgroup.procs').read_text().strip()

    def reap(self, timeout):
        if self.process is None: return True
        deadline = time.monotonic()+timeout
        try: self.process.wait(timeout=timeout/2)
        except subprocess.TimeoutExpired:
            # Direct retained CLI child only; never signal a guessed unit/PID.
            self.process.kill(); self.process.wait(timeout=max(0, deadline-time.monotonic()))
        for handle in (self.process.stdin, self.process.stdout):
            if handle is not None: handle.close()
        return self.process.returncode is not None


def launch(request, args, backend, uid, clock=time.monotonic, sleep=time.sleep, deadline=None, utc_deadline=None, utc=time.time):
    """No adoption/retry: uncertain start reconciles only exact owner/source."""
    name = unit_name(request)
    deadline = clock()+TOTAL if deadline is None else deadline
    def remaining(): return min(deadline-clock(), math.inf if utc_deadline is None else utc_deadline-utc())
    require(remaining() > 130, 'Fresh full startup/capture/retirement reserve before helpers')
    require(backend.show(name, min(2, remaining()-130)) is None, 'Preexisting unit: no adoption/start/stop')
    require(remaining() > 130, 'Fresh full startup/capture/retirement reserve before unit creation')
    identity, attempted = None, False
    result = {'complete': False, 'unit': name, 'native_count': 0}
    try:
        attempted = True; backend.start(args)
        while remaining() > 125:
            row = backend.show(name, min(1, remaining()-125))
            if row is not None:
                identity = owned_unit(request, row)
                result['worker_identity'] = backend.retain(row)
                verify_unit(request, row, uid)
                require(remaining() > 125, 'Fresh reserve before effective BPF helper')
                result['effective_network_bpf'] = backend.network(identity, min(2, remaining()-125))
                break
            sleep(.05)
        require(identity is not None, 'Owned unit did not reach bounded preflight gate')
        require(remaining() > 125, 'Fresh capture/retirement reserve after helper readbacks')
        backend.gate()
        rc, output = backend.collect(remaining()-10)
        result['worker_exit'] = rc
        if rc != 0: result['worker_diagnostic_tail'] = output[-2048:].decode(errors='replace')
        require(rc == 0 and len(output) <= 1024**2, 'Capture worker failed/output bound')
        worker = json.loads(output)
        require(worker.get('complete') is True and worker.get('status') == 'CANDIDATE_IDENTITIES_ONLY_REQUIRES_REVIEW'
                and worker.get('native_count') == 0, 'Capture receipt incomplete')
        result['worker'] = worker
    except BaseException as failure: result['error'] = str(failure)[:512]
    finally:
        if attempted:
            try:
                if identity is None:
                    require(remaining() > 2, 'No cleanup/reap headroom')
                    row = backend.show(name, min(1, remaining()-2))
                    if row is not None:
                        identity = owned_unit(request, row)
                        result['worker_identity'] = backend.retain(row)
                require(identity is not None, 'Unknown unit identity: no signals, outer receipt incomplete')
                # Refuse a changed InvocationID before issuing any stop.
                require(remaining() > 2, 'No cleanup/reap headroom')
                row = backend.show(name, min(1, remaining()-2))
                if row is not None:
                    owned_unit(request, row, previous=identity)
                    if row.get('ActiveState') in ('active', 'activating', 'deactivating'):
                        require(remaining() > 2, 'No owned-stop/reap headroom')
                        backend.stop(name, min(5, remaining()-2))
                require(backend.retired(identity), 'Owned cgroup/namespace retirement incomplete')
                require(remaining() > 0, 'Final outer cleanup/grant deadline exceeded')
                result['cleanup'] = {'owned_cgroup_empty': True, 'private_mount_namespace_retired': True}
            except BaseException as failure: result['cleanup_error'] = str(failure)[:512]
            try:
                require(remaining() > 0, 'No direct CLI reap time; incomplete')
                require(backend.reap(min(1, remaining())) is True, 'Direct CLI child reap incomplete')
            except BaseException as failure: result['cli_cleanup_error'] = str(failure)[:512]
        result['complete'] = 'worker' in result and not any(k in result for k in ('error', 'cleanup_error', 'cli_cleanup_error')) and remaining() > 0
    return result


def bounded_helper(args, timeout, limit=32768, popen=None, clock=time.monotonic):
    """Stream at most limit+1 bytes; kill/reap retained direct helper on failure."""
    require(type(timeout) in (int, float) and math.isfinite(timeout) and timeout > 0, 'Positive finite helper budget')
    deadline = clock()+timeout
    work_deadline = deadline-min(.05, timeout/4)
    process = (popen or subprocess.Popen)(args, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, start_new_session=True)
    output, primary = bytearray(), None
    try:
        fd = process.stdout.fileno(); os.set_blocking(fd, False)
        while clock() < work_deadline:
            ready, _, _ = select.select([fd], [], [], min(.05, max(0, work_deadline-clock())))
            if ready:
                block = os.read(fd, min(65536, limit-len(output)+1))
                if not block:
                    rc = process.wait(timeout=max(0, deadline-clock()))
                    require(clock() <= deadline, 'Helper exit exceeded shared operation budget')
                    return subprocess.CompletedProcess(args, rc, bytes(output), b'')
                output.extend(block)
                require(len(output) <= limit, 'Bounded helper output overflow')
        raise TimeoutError('Bounded helper deadline')
    except BaseException as failure:
        primary = failure
        raise
    finally:
        try:
            if process.poll() is None:
                process.kill()  # direct retained Popen child only
                process.wait(timeout=max(0, deadline-clock()))
            process.stdout.close()
        except BaseException as failure:
            if primary is None: raise
            primary.add_note('Additional helper cleanup failure: '+str(failure)[:256])


def load_adapter():
    path = Path(__file__).with_name('adapters.py')
    spec = importlib.util.spec_from_file_location('capture_adapter', path)
    module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
    return module


def restrict_ports(libc=None, close=os.close, machine=None):
    """Linux Landlock ABI4: allow TCP connect443, deny every explicit bind.

    x86_64 syscall numbers come from Linux UAPI, not a native helper binary.
    Missing support is fatal, with no fallback to a wider network policy.
    """
    require((machine or platform.machine()) == 'x86_64', 'Reviewed x86_64 Linux syscall ABI required')
    libc = libc or ctypes.CDLL(None, use_errno=True)
    libc.syscall.restype = ctypes.c_long
    abi = libc.syscall(444, 0, 0, 1)
    require(abi >= 4, 'Landlock network ABI4 required')
    class Ruleset(ctypes.Structure): _fields_ = [('fs', ctypes.c_uint64), ('net', ctypes.c_uint64)]
    class Port(ctypes.Structure): _fields_ = [('access', ctypes.c_uint64), ('port', ctypes.c_uint64)]
    ruleset, port = Ruleset(0, 3), Port(2, 443)
    fd = libc.syscall(444, ctypes.byref(ruleset), ctypes.sizeof(ruleset), 0)
    require(fd >= 0, 'Landlock ruleset creation failed')
    primary = None
    try:
        require(libc.syscall(445, fd, 2, ctypes.byref(port), 0) == 0, 'Landlock connect443 rule failed')
        require(libc.prctl(38, 1, 0, 0, 0) == 0, 'NoNewPrivs required before Landlock')
        require(libc.syscall(446, fd, 0) == 0, 'Landlock policy installation failed')
    except BaseException as failure:
        primary = failure
        raise
    finally:
        try: close(fd)
        except BaseException as failure:
            if primary is None: raise
            primary.add_note('Additional Landlock handle close failure: '+str(failure)[:256])
    return {'abi': abi, 'connect_tcp_ports': [443], 'bind_tcp_ports': []}


def socket_filter():
    # Classic seccomp BPF, Linux x86_64 seccomp_data offsets: arch4, nr0,
    # args[0]16 (family), args[1]24 (socket type), args[2]32 (protocol).
    # Reject x32 and socketpair, non-IP families;
    # allow socket only for SOCK_STREAM with protocol0/default or IPPROTO_TCP6.
    # Address families are independently limited by the system service.
    return [(0x20,0,0,4), (0x15,1,0,0xc000003e), (0x06,0,0,0x80000000),
            (0x20,0,0,0), (0x35,0,1,0x40000000), (0x06,0,0,0x80000000),
            (0x15,3,0,41), (0x15,0,1,53), (0x06,0,0,0x5000d), (0x06,0,0,0x7fff0000),
            (0x20,0,0,16), (0x15,2,0,2), (0x15,1,0,10), (0x06,0,0,0x5000d),
            (0x20,0,0,24), (0x54,0,0,15), (0x15,1,0,1), (0x06,0,0,0x5000d),
            (0x20,0,0,32), (0x15,2,0,0), (0x15,1,0,6), (0x06,0,0,0x5000d), (0x06,0,0,0x7fff0000)]


def restrict_socket_types(libc=None, machine=None):
    require((machine or platform.machine()) == 'x86_64', 'Reviewed x86_64 seccomp ABI required')
    libc = libc or ctypes.CDLL(None, use_errno=True)
    class Filter(ctypes.Structure):
        _fields_ = [('code',ctypes.c_ushort),('jt',ctypes.c_ubyte),('jf',ctypes.c_ubyte),('k',ctypes.c_uint32)]
    class Program(ctypes.Structure):
        _fields_ = [('length',ctypes.c_ushort),('filters',ctypes.POINTER(Filter))]
    rows = socket_filter()
    filters = (Filter*len(rows))(*(Filter(*row) for row in rows))
    program = Program(len(rows), filters)
    require(libc.prctl(38, 1, 0, 0, 0) == 0 and libc.prctl(22, 2, ctypes.byref(program), 0, 0) == 0,
            'Kernel TCP-stream-only seccomp installation failed')
    return {'architecture':'x86_64', 'socket_type':'SOCK_STREAM', 'protocols':[0,6], 'socketpair':False}


def worker(request, grant, adapter):
    adapter.hosted_identity(request)
    require(hashlib.sha256(Path(adapter.__file__).read_bytes()).hexdigest() == request['adapter_sha256']
            and hashlib.sha256(Path(__file__).read_bytes()).hexdigest() == request['launcher_sha256'], 'Worker source hash drift')
    used = Path(__file__).with_name('USED')
    require(used.stat().st_size <= 2048 and json.loads(used.read_bytes()) == {
        'request_sha256': adapter.sha(adapter.canonical(request)), 'grant_sha256': adapter.sha(adapter.canonical(grant)),
        'run_id': os.environ['GITHUB_RUN_ID'], 'owner': request['owner']}, 'Missing external atomic single-use record')
    # Only a gate from the exact parent-verified invocation permits work.
    require(select.select([sys.stdin], [], [], 10)[0] and sys.stdin.readline(4) == 'GO\n', 'No outer verified-unit gate')
    groups = Path('/proc/self/cgroup').read_text().strip().splitlines()
    expected = '/system.slice/'+unit_name(request)
    require(groups == ['0::'+expected], 'Unified exact worker cgroup')
    root = Path('/sys/fs/cgroup'+expected)
    require((root/'memory.max').read_text().strip() == '268435456' and (root/'memory.swap.max').read_text().strip() == '0'
            and (root/'pids.max').read_text().strip() == '16', 'Kernel memory/swap/PID readback drift')
    quota, period = map(int, (root/'cpu.max').read_text().split())
    require(quota > 0 and period > 0 and quota <= period, 'Kernel CPU quota readback drift')
    import resource
    require(resource.getrlimit(resource.RLIMIT_CPU) == (20, 20), 'Kernel CPU time limit drift')
    port_policy = restrict_ports()
    socket_policy = restrict_socket_types()
    import socket
    try: unwanted = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    except OSError as failure: require(failure.errno == 13, 'UDP creation must be causally denied with Linux EACCES13')
    else:
        unwanted.close()
        raise ValueError('UDP socket creation succeeded; no capture')
    family = socket.AF_INET6 if ':' in request['peer_ip'] else socket.AF_INET
    with socket.socket(family, socket.SOCK_STREAM) as forbidden:
        forbidden.settimeout(1)
        try: forbidden.connect((request['peer_ip'], 444))
        except OSError as failure: require(failure.errno == 13, 'TCP444 must be causally denied by Landlock EACCES13')
        else: raise ValueError('Non443 connect succeeded; no capture')
    # One explicitly listed negative IP observation, before any archive read.
    # A timeout alone is not causal BPF proof: retain it with actual effective
    # attachment IDs/configuration and the later successful allowed-peer TLS.
    denied_peer = '1.1.1.1' if request['peer_ip'] != '1.1.1.1' else '8.8.8.8'
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as denied:
        denied.settimeout(.25)
        try: denied.connect((denied_peer, 443))
        except OSError as failure:
            require(isinstance(failure, TimeoutError) or failure.errno in (1, 13, 101, 110, 113), 'Unexpected denied-peer observation')
            denied_observation = {'peer': denied_peer, 'port': 443, 'error': type(failure).__name__, 'errno': failure.errno}
        else: raise ValueError('Forbidden public peer connected; no capture')
    # Bind to loopback port0 only. A supported deny filter must reject this
    # before allocating any listener; success closes immediately and fails.
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as probe:
        try: probe.bind(('127.0.0.1', 0))
        except OSError as failure: require(failure.errno in (1, 13), 'Unexpected bind-denial errno')
        else: raise ValueError('Socket bind restriction not enforced; no capture')
    try:
        with os.scandir('/home') as entries: next(entries, None)
    except OSError as failure: require(failure.errno == 13, 'Expected inaccessible-home Linux EACCES13')
    else: raise ValueError('Home remains readable; no capture')
    result = adapter.capture(request, grant, adapter.HTTPS(request['peer_ip']))
    result['landlock_port_policy'] = port_policy
    result['tcp_stream_only_policy'] = socket_policy
    result['udp_socket_errno'] = 13
    result['home_read_errno'] = 13
    result['connect444_errno'] = 13
    result['denied_peer_observation'] = denied_observation
    result['loopback_bind_denied'] = True
    return result


def execute(request, grant, adapter):
    """Real future entry, explicitly gated; never called by offline controls."""
    deadline = time.monotonic()+TOTAL
    adapter.hosted_identity(request)
    unit_name(request)  # validate nonce before deriving any filesystem target
    require(request.get('scope') == adapter.SCOPE and request.get('url') == adapter.URL and request.get('limits') == adapter.LIMITS
            and adapter.ipaddress.ip_address(request['peer_ip']).is_global
            and all(request.get(key) == 0 for key in ('image_count', 'compile_count', 'daemon_count', 'package_install_count')), 'Exact bounded nonnative capture request')
    require(request.get('run_id') == os.environ.get('GITHUB_RUN_ID') == grant.get('run_id')
            and re.fullmatch('[1-9][0-9]{0,19}', request.get('run_id') or ''), 'Exact external one-run admission')
    # Validate immutable admission before any directory/unit write. capture's
    # network code is not invoked to perform this check.
    now = time.time()
    require(grant.get('granted') is True and grant.get('scope') == adapter.SCOPE and grant.get('request_sha256') == adapter.sha(adapter.canonical(request))
            and grant.get('head') == request.get('head') and grant.get('executor') == request.get('executor')
            and type(grant.get('starts')) in (int, float) and type(grant.get('ends')) in (int, float)
            and math.isfinite(grant['starts']) and math.isfinite(grant['ends'])
            and grant['starts'] <= now < grant['ends'] and grant['ends']-now >= TOTAL
            and grant.get('external_controls_reviewed') is True, 'No complete exact outer capture admission')
    sources = {'adapters.py': Path(adapter.__file__).read_bytes(), 'launcher.py': Path(__file__).read_bytes()}
    require(all(len(data) <= 65536 for data in sources.values()) and
            all(hashlib.sha256(sources[name]).hexdigest() == request[key] for name, key in
                [('adapters.py', 'adapter_sha256'), ('launcher.py', 'launcher_sha256')]), 'Frozen executable bytes required')
    stage = Path('/tmp/civ13-capture-src-'+request['owner'])
    # Exclusive stage/USED persists beyond all run scratch cleanup. A repeat
    # invocation in this job cannot acquire the same admission again. The run
    # ID is also frozen in the allocator's external immutable dispatch record.
    used = {'request_sha256': adapter.sha(adapter.canonical(request)), 'grant_sha256': adapter.sha(adapter.canonical(grant)),
            'run_id': request['run_id'], 'owner': request['owner']}
    files = {**sources, 'request.json': adapter.canonical(request), 'grant.json': adapter.canonical(grant), 'USED': adapter.canonical(used)}
    stage_once(stage, files)
    args = command(request, stage, os.geteuid(), os.getegid(), os.environ)
    result = launch(request, args, Systemd(), os.geteuid(), deadline=deadline, utc_deadline=grant['ends'], clock=time.monotonic, utc=time.time)
    result['single_use_record_sha256'] = hashlib.sha256(adapter.canonical(used)).hexdigest()
    result['single_use_stage_retained_until_runner_disposal'] = str(stage)
    return result


def stage_once(stage, files):
    require(set(files) == {'adapters.py', 'launcher.py', 'request.json', 'grant.json', 'USED'}
            and all(type(data) is bytes for data in files.values()) and sum(map(len, files.values())) <= 128*1024,
            'Aggregate exact public source/admission staging bound')
    stage.mkdir(mode=0o700)
    for name, data in files.items():
        with (stage/name).open('xb') as output: output.write(data)
        (stage/name).chmod(0o444)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--worker', action='store_true')
    parser.add_argument('--launch', action='store_true')
    parser.add_argument('--request', type=Path); parser.add_argument('--grant', type=Path)
    options = parser.parse_args()
    require(not (options.worker and options.launch), 'One explicit entry only')
    if not options.worker and not options.launch:
        print(json.dumps({'status': 'INERT_NO_LAUNCH', 'outer_seconds': TOTAL, 'registered_workflow': False}))
    else:
        require(options.request and options.grant, 'Frozen request/grant paths required')
        require(options.request.stat().st_size <= 65536 and options.grant.stat().st_size <= 65536, 'Bounded admission input files')
        request, grant = json.loads(options.request.read_bytes()), json.loads(options.grant.read_bytes())
        receipt = worker(request, grant, load_adapter()) if options.worker else execute(request, grant, load_adapter())
        print(json.dumps(receipt, sort_keys=True), flush=True)
        sys.exit(0 if receipt['complete'] else 1)
