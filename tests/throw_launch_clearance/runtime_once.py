"""Freeze a bounded one-shot native packet; execution requires root approval.

Import and --freeze are inert with respect to native processes/networking.
--execute is deliberately separate and requires a recorded startup-loopback
approval flag. That flag records prior permission; it does not grant permission.
No frozen containment helper is changed. This reviewed wrapper retains original
socket observations while allowing only the named startup LISTEN exception.
"""
import argparse
import ctypes
import hashlib
import importlib.util
import ipaddress
import json
from pathlib import Path
import re
import shutil
import struct
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
WORKSPACE = ROOT.parent
PORT = 59474
PROFILE = 'throw-launch-startup-loopback-v2'
HELPERS = ('scripts/native_fixture.py', 'tests/human_subtile/run-diagonal.py',
           'tests/human_subtile/run.py', 'tests/human_subtile/native_1688/windows.py',
           'tests/human_subtile/native_1688/owned_job.py', 'tests/human_subtile/native_1688/guard_config.py',
           'tests/throw_launch_clearance/runtime_once.py')
BINARIES = {'dm.exe': 'f29b3041c46df453b3f999583bef0bb0ff79fe2b53ee1b8686bb46ce18c7df77',
            'dd.exe': 'abb21de26047724bf64411e17da5e17cacc74221817c3e049a79626156b44866'}


def require(ok, message):
    if not ok:
        raise RuntimeError(message)


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def git(*args):
    return subprocess.check_output(['git', '-C', str(ROOT), *args], text=True).strip()


def workspace_path(path):
    path = Path(path).resolve()
    require(path.is_relative_to(WORKSPACE.resolve()), 'Output/packet must stay in this task workspace')
    return path


def normalize_socket(row, owner):
    """Two closed schemas, with family derived/checked from literal addresses.

    Ownership comes from the PID-filtered backend's retained process handle,
    checked against current Job membership and a fresh creation-time query.
    Unknown fields (including unverified owner claims) are never discarded.
    """
    keys = {'protocol', 'address', 'port', 'state', 'remote_address', 'remote_port'}
    require(type(row) is dict and set(row) in (keys, keys | {'family'}), 'Unknown socket schema')
    numeric = 'family' in row
    require(type(row['protocol']) is str and row['protocol'] in ('tcp', 'udp'), 'Unknown socket protocol')
    require(type(row['port']) is int and 1 <= row['port'] <= 65535, 'Malformed local port')
    def address(value):
        require(type(value) is str and '%' not in value, 'Malformed socket address')
        try:
            parsed = ipaddress.ip_address(value)
        except ValueError as error:
            raise RuntimeError('Malformed socket address') from error
        require(str(parsed) == value, 'Ambiguous socket address')
        return parsed
    local = address(row['address'])
    if numeric:
        require(type(row['family']) is int and row['family'] in (2, 23) and
                {2: 4, 23: 6}[row['family']] == local.version, 'Socket family/address mismatch')
    if row['protocol'] == 'tcp':
        remote = address(row['remote_address'])
        require(remote.version == local.version and type(row['remote_port']) is int and
                0 <= row['remote_port'] <= 65535, 'Malformed remote endpoint')
        if numeric:
            require(type(row['state']) is int and 1 <= row['state'] <= 12, 'Unknown numeric TCP state')
            state = 'listen' if row['state'] == 2 else str(row['state'])
        else:
            require(type(row['state']) is str and row['state'] in
                    {'listen', '1', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12'},
                    'Unknown textual TCP state')
            state = row['state']
    else:
        udp_state = row['state'] is None if numeric else type(row['state']) is str and row['state'] == 'None'
        require(udp_state and row['remote_address'] is None and row['remote_port'] is None,
                'Malformed UDP observation')
        state = None
    return dict(protocol=row['protocol'], family=local.version, address=str(local), port=row['port'],
                state=state, remote_address=row['remote_address'], remote_port=row['remote_port'],
                pid=owner['pid'], creation_filetime=owner['creation_filetime'])


class StartupLoopback:
    """A single daemon's explicit startup exception, never a renewed window."""
    def __init__(self, delegate, marker, audit, clock=time.monotonic):
        self.delegate, self.marker, self.audit, self.clock = delegate, Path(marker), audit, clock
        self.started = None
        self.closed = False
        self.child = self.owner = None

    def __getattr__(self, name):
        return getattr(self.delegate, name)

    def launch(self, argv, cwd, evidence, phase):
        require(self.started is None and phase == 'throw-launch', 'Exactly one throw daemon launch')
        require(not self.marker.exists(), 'Closure marker must not pre-exist')
        self.started = self.clock()  # Before creation is conservatively earlier.
        self.child = self.delegate.launch(argv, cwd, evidence, phase)
        self.owner = dict(self.delegate.identity(self.child))
        require(set(self.owner) == {'pid', 'creation_filetime', 'image'} and
                type(self.owner['pid']) is int and self.owner['pid'] == self.child.pid and self.child.pid > 0 and
                type(self.owner['creation_filetime']) is int and self.owner['creation_filetime'] > 0 and
                type(self.owner['image']) is str and bool(self.owner['image']), 'Invalid retained owner identity')
        require(self.delegate.a.times(self.child)[0] == self.owner['creation_filetime'], 'Owner birth mismatch')
        return self.child

    def observe(self, child):
        require(self.started is not None, 'No owned daemon')
        elapsed = self.clock() - self.started
        require(elapsed >= 0 and (self.closed or elapsed <= 5), 'Startup closure deadline exceeded')
        if self.marker.exists():
            require(self.marker.stat().st_size <= 32 and self.marker.read_bytes() == b'closed\r\n',
                    'Malformed fresh closure marker')
            self.closed = True
        sample = dict(self.delegate.observe(child))
        raw = sample['sockets']
        identity, birth = self.delegate.identity(child), self.delegate.a.times(child)[0]
        elapsed = self.clock() - self.started
        self.audit(dict(elapsed=elapsed, closed=self.closed, observed_sockets=raw,
                        expected_owner=self.owner, observed_owner=identity, observed_birth=birth))
        require(child is self.child and identity == self.owner and birth == self.owner['creation_filetime'],
                'Foreign owner or changed retained birth')
        require(elapsed >= 0 and (self.closed or elapsed <= 5), 'Startup closure deadline exceeded')
        require(type(raw) is list, 'Malformed socket collection')
        normalized = [normalize_socket(row, self.owner) for row in raw]
        # A socket exception also requires this exact sole live Job member.
        owned_live = (sample['exited'] is False and type(sample['members']) is list and
                      all(type(value) is int for value in sample['members']) and
                      sample['members'] == [self.owner['pid']] and
                      all(type(sample[key]) is int for key in ('total', 'retained', 'active', 'terminated')) and
                      sample['total'] == sample['retained'] == sample['active'] == 1 and sample['terminated'] == 0)
        allowed = (not self.closed and owned_live and len(normalized) == 1 and normalized[0] == dict(
            protocol='tcp', family=4, address='127.0.0.1', port=PORT, state='listen',
            remote_address='0.0.0.0', remote_port=0, pid=self.owner['pid'],
            creation_filetime=self.owner['creation_filetime']))
        sample['observed_sockets'] = raw
        sample['normalized_sockets'] = normalized
        sample['startup_loopback_exception'] = bool(allowed)
        sample['closure_seen'] = self.closed
        # Every other socket remains visible to the unchanged strict validator.
        sample['sockets'] = [] if allowed else raw
        return sample


def port_occupied(port):
    """Read OS TCP/UDP tables for one port; never bind, connect or evict."""
    from ctypes import wintypes as w
    ip = ctypes.WinDLL('iphlpapi', use_last_error=True)
    for family in (2, 23):
        for protocol in ('tcp', 'udp'):
            fn = getattr(ip, 'GetExtendedTcpTable' if protocol == 'tcp' else 'GetExtendedUdpTable')
            fn.argtypes = [ctypes.c_void_p, ctypes.POINTER(w.DWORD), w.BOOL, w.ULONG, ctypes.c_int, w.ULONG]
            fn.restype = w.DWORD
            size = w.DWORD()
            kind = 5 if protocol == 'tcp' else 1
            code = fn(None, ctypes.byref(size), False, family, kind, 0)
            require(code in (0, 122) and size.value <= 16 * 1024**2, 'Port census unavailable/bounded table exceeded')
            buf = ctypes.create_string_buffer(max(4, size.value))
            require(fn(buf, ctypes.byref(size), False, family, kind, 0) == 0, 'Port census failed')
            count = struct.unpack_from('<I', buf.raw)[0]
            width = (24 if family == 2 else 56) if protocol == 'tcp' else (12 if family == 2 else 28)
            require(4 + count * width <= len(buf.raw), 'Truncated port census')
            offset = (8 if protocol == 'tcp' else 4) if family == 2 else 20
            if any(struct.unpack_from('!H', buf.raw, 4 + i * width + offset)[0] == port for i in range(count)):
                return True
    return False


def freeze(packet, byond, output):
    packet, output = workspace_path(packet), workspace_path(output)
    require(not output.exists(), 'Fresh frozen-contract filename required')
    head = git('rev-parse', 'HEAD')
    require(not git('status', '--porcelain'), 'Freeze requires a clean committed checkout')
    manifest = json.loads((packet / 'launch-manifest.json').read_text())
    compiled = json.loads((packet / 'compile-accepted.json').read_text())
    require(manifest['head'] == compiled['head'] == head and compiled['compile_passed'] and
            compiled['engine'] == '516.1688' and not compiled['runtime_executed'], 'Exact-head compile required')
    for relative, digest in manifest['prepared_files'].items():
        require(sha(packet / 'stage' / relative) == digest, 'Prepared source changed: ' + relative)
    dme = packet / manifest['dme']
    helpers = {relative: sha(ROOT / relative) for relative in HELPERS}
    binaries = {name: dict(path=str((Path(byond) / name).resolve()), sha256=sha(Path(byond) / name)) for name in BINARIES}
    require(all(row['sha256'] == BINARIES[name] for name, row in binaries.items()), 'Executable allowlist mismatch')
    probe = (packet / 'stage/tests/throw_launch_clearance/throw_launch.dm').read_text()
    count = re.search(r'^#define THROW_LAUNCH_EXPECTED_CHECKS (\d+)$', probe, re.M)
    require(count and int(count[1]) == 242, 'Frozen assertion count must be 242')
    contract = dict(head=head, packet=str(packet), profile=PROFILE, port=PORT, timeout=90,
        max_daemons=1, expected_assertions=242, binaries=binaries, helpers=helpers,
        manifest_sha256=sha(packet / 'launch-manifest.json'),
        artifacts={ext: dict(path=str(dme.with_suffix(ext)), sha256=sha(dme.with_suffix(ext))) for ext in ('.dmb', '.rsc')},
        native_executed=False, root_startup_loopback_permission='required before --execute')
    require(contract['artifacts']['.dmb']['sha256'] == compiled['dmb_sha256'], 'Compiled DMB changed')
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(contract, indent=2) + '\n')
    return contract


def execute(contract_path, output, startup_loopback_approved):
    require(startup_loopback_approved, 'Root must establish exact startup-loopback permission first')
    contract = json.loads(Path(contract_path).read_text())
    require(contract['profile'] == PROFILE and contract['timeout'] == 90 and contract['max_daemons'] == 1 and
            contract['port'] == PORT and contract['expected_assertions'] == 242, 'Frozen one-shot profile mismatch')
    require(git('rev-parse', 'HEAD') == contract['head'] and not git('status', '--porcelain'), 'Source head/state changed')
    packet, output = workspace_path(contract['packet']), workspace_path(output)
    require(not output.exists(), 'Fresh runtime evidence directory required')
    require(sha(packet / 'launch-manifest.json') == contract['manifest_sha256'], 'Prepared manifest changed')
    manifest = json.loads((packet / 'launch-manifest.json').read_text())
    for relative, digest in manifest['prepared_files'].items():
        require(sha(packet / 'stage' / relative) == digest, 'Prepared source/config changed: ' + relative)
    for relative, digest in contract['helpers'].items():
        require(sha(ROOT / relative) == digest, 'Launcher/helper bytes changed')
    for name, row in contract['binaries'].items():
        require(row['sha256'] == BINARIES[name] == sha(row['path']), 'Executable bytes changed')
    for row in contract['artifacts'].values():
        require(sha(row['path']) == row['sha256'], 'Compiled artifact changed')
    require(not port_occupied(PORT), 'Port59474 is already owned; no eviction or alternate port')
    output.mkdir()
    (output / 'execution-policy.json').write_text(json.dumps(dict(profile=PROFILE,
        sampled_socket_policy='Only one IPv4 TCP LISTEN 127.0.0.1:59474 before closure, maximum five seconds; all raw observations retained; any other sampled socket fails',
        continuous_network_prevention=False), indent=2) + '\n')
    work = output / 'runtime'
    work.mkdir()
    for ext, row in contract['artifacts'].items():
        destination = work / ('human_subtile' + ext)
        shutil.copy2(row['path'], destination)
        require(sha(destination) == row['sha256'], 'Runtime copy changed')
    shutil.copytree(packet / 'stage/config', work / 'config')
    spec = importlib.util.spec_from_file_location('one_shot_current_runner', ROOT / 'tests/human_subtile/run-diagonal.py')
    current = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(current)
    audit_path = output / 'network-observations.jsonl'
    def audit(row):
        text = json.dumps(row) + '\n'
        require((audit_path.stat().st_size if audit_path.exists() else 0) + len(text.encode()) <= 2 * 1024**2,
                'Network audit bound exceeded')
        with audit_path.open('a', encoding='utf-8') as stream:
            stream.write(text)
    backend = StartupLoopback(current.current_backend(), work / 'port-closed.txt', audit)
    session = current.Session(output / 'supervisor', contract['head'], backend_factory=lambda: backend)
    result = current.run_phase(session, [contract['binaries']['dd.exe']['path'], str(work / 'human_subtile.dmb'),
        str(PORT), '-ports', str(PORT), '-ip', '127.0.0.1', '-nowebclient', '-invisible', '-close', '-trusted',
        '-params', 'tested_commit=' + contract['head'], '-log', 'runtime.log'],
        cwd=work, phase='throw-launch', timeout=90, state_directory=work)
    diagnostic = result.stdout + result.stderr + (work / 'runtime.log').read_text(errors='replace')
    require(result.returncode == 0 and not current.legacy.DIAGNOSTICS.search(diagnostic), 'Native diagnostic/exit failure')
    receipt = json.loads((work / 'receipt.json').read_text())
    require(receipt['head'] == contract['head'] and (receipt['byond_version'], receipt['byond_build']) == (516, 1688) and
            receipt['initial_native_port'] == PORT and receipt['port'] == 0 and receipt['error'] is None and
            receipt['launch_checks'] == 242 and receipt['checks'] == receipt['mining_checks'] == 0, 'Incomplete native receipt')
    require(backend.closed and (work / 'result.txt').read_bytes() == b'PASS\r\n', 'Missing closure/PASS marker')
    (output / 'accepted.json').write_text(json.dumps(dict(head=contract['head'], checks=242,
        profile=PROFILE, native_executed=True, connected_client=False, receipt=receipt), indent=2) + '\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--freeze', action='store_true')
    mode.add_argument('--execute', action='store_true')
    parser.add_argument('--packet', type=Path)
    parser.add_argument('--byond-bin', type=Path)
    parser.add_argument('--frozen-inputs', type=Path)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--startup-loopback-approved', action='store_true')
    args = parser.parse_args()
    if args.freeze:
        parser.error('--freeze needs --packet and --byond-bin') if not (args.packet and args.byond_bin) else None
        contract = freeze(args.packet, args.byond_bin, args.output)
        print(json.dumps(dict(head=contract['head'], expected_assertions=242, native_executed=False,
                              dmb_sha256=contract['artifacts']['.dmb']['sha256'])))
    else:
        parser.error('--execute needs --frozen-inputs') if not args.frozen_inputs else None
        execute(args.frozen_inputs, args.output, args.startup_loopback_approved)


if __name__ == '__main__':
    main()
