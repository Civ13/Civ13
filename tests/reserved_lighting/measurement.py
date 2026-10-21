"""Bounded paired fixture measurements. Import is inert; native CLI needs a grant.

Process CPU is user+kernel seconds; private memory is a sampled Linux smaps value,
not RSS or a guaranteed peak. No production lighting, fixture or map is changed.
"""
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import re
import statistics
import sys
import time

from compare import compare

HEX = re.compile(r'[0-9a-f]{64}')
DIAGNOSTIC = re.compile(r'##\s*ERROR|runtime error|Runtime in|BUG:|CRASH|Infinite loop|Cannot (?:read|execute) null|Bad ref|Bad loc|PORT_OPEN|Unhandled exception|Out of memory|Assertion failed|Access violation', re.I)


def execution_identity():
    return {str(path.resolve()): sha(path.resolve()) for path in
            (Path(__file__), Path(__file__).with_name('compare.py'), Path(sys.executable))}


def require(value, message):
    if not value:
        raise ValueError(message)


def number(value):
    return type(value) in (int, float) and math.isfinite(value) and value >= 0


def sha(path):
    value = hashlib.sha256()
    with path.open('rb') as source:
        for chunk in iter(lambda: source.read(1024**2), b''):
            value.update(chunk)
    return value.hexdigest()


def validate_packet(packet, root):
    require(packet['execution'] == execution_identity(), 'Execution inputs changed')
    require(packet['schema'] == 1 and re.fullmatch('[0-9a-f]{40}', packet['head']), 'Packet identity')
    require(type(packet['pairs']) is int and 1 <= packet['pairs'] <= 10, 'Pair bound')
    require(number(packet['interval']) and .05 <= packet['interval'] <= .5, 'Sampling interval')
    require(HEX.fullmatch(packet['fixture_sha256']) and packet['parity_run'] == 39347909747
            and packet['parity_head'] == '2d4229c2ca3062e6c358aa21575f0c203282f995', 'Workload provenance')
    require(packet['command_tail'] == ['-close', '-trusted', '-log', 'runtime.log', '-params'], 'Comparable command')
    limits = packet['limits']
    for key, cap in {'wall': 30, 'cpu': 10, 'private': 512*1024**2, 'output': 16*1024**2, 'total_wall': 960}.items():
        require(number(limits[key]) and 0 < limits[key] <= cap, 'Limit: ' + key)
    require(type(packet['files']) is dict and 3 <= len(packet['files']) <= 256, 'Input inventory')
    root = root.resolve()
    for relative, identity in packet['files'].items():
        path = root/relative
        require(not path.is_symlink() and path.resolve().is_relative_to(root), 'Input path')
        require(path.is_file() and path.stat().st_size <= 1024**3 and sha(path) == identity, 'Input changed: ' + relative)
    require(all(packet[key] in packet['files'] for key in ('daemon', 'dmb', 'rsc')), 'Unbound executable/resource')
    require(packet['fixture'] in packet['files'] and packet['files'][packet['fixture']] == packet['fixture_sha256'], 'Unbound fixture source')
    require(packet['fixture_sha256'] == sha(Path(__file__).with_name('probe.dm')), 'Changed parity workload')
    require(Path(packet['dmb']).with_suffix('.rsc').as_posix() == packet['rsc'], 'Resource pairing')


def validate_sample(sample, identity, previous, limits):
    require(sample['identity'] == identity, 'Sample attribution')
    require(sample['children'] == [] and sample['sockets'] == [], 'Unexpected process/socket')
    require(type(sample['private_sampled']) is bool, 'Private counter provenance')
    for field in ('cpu', 'private', 'wall'):
        require(number(sample[field]), 'Invalid counter: ' + field)
        require(sample[field] <= limits[field], 'Resource bound: ' + field)
    if previous:
        require(sample['cpu'] >= previous['cpu'] and sample['wall'] >= previous['wall'], 'Counter reversal')


def output_bound(work, cap):
    paths = list(work.rglob('*'))
    require(len(paths) <= 256 and not any(p.is_symlink() for p in paths), 'Output inventory')
    require(sum(p.stat().st_size for p in paths if p.is_file()) <= cap, 'Output bound')


def private_bytes(text):
    values = []
    for name in ('Clean', 'Dirty'):
        field = re.findall(r'^Private_'+name+r':\s+(\d+) kB$', text, re.M)
        require(len(field) == 1, 'Missing/duplicate private counter')
        values.append(int(field[0])*1024)
    huge = re.findall(r'^Private_Hugetlb:\s+(\d+) kB$', text, re.M)
    require(len(huge) <= 1, 'Duplicate huge-page counter')
    return sum(values)+sum(int(value)*1024 for value in huge)


def outcome(work, cap):
    output_bound(work, cap)
    require((work/'result.txt').read_text().strip() == 'PASS', 'Partial/failed fixture')
    require((work/'port-closed.txt').read_text().strip() == 'closed', 'Missing port closure')
    for name in ('runtime.log', 'stdout.log', 'stderr.log'):
        require(not DIAGNOSTIC.search((work/name).read_text(errors='replace')), 'Native diagnostic')
    require((work/'states.jsonl').is_file(), 'Missing snapshots')
    compare(work/'states.jsonl', work/'states.jsonl')


def run(packet, root, output, adapter, clock=time.monotonic, pause=time.sleep, accept=outcome, parity=compare, lease=lambda: None):
    """Adapter owns process retention/cleanup; persist every observation before checks.

    The injected lease must reject expiration. Production CLI always supplies it.
    Fake adapters can exercise every contract without native execution.
    """
    validate_packet(packet, root)
    output.mkdir(exist_ok=False, parents=True)
    report = {'head': packet['head'], 'complete': False, 'runs': [], 'scope': 'isolated end-to-end fixture only',
              'memory_metric': 'sampled Private_Clean+Private_Dirty+Private_Hugetlb bytes; not true peak or net RAM',
              'interval_seconds': packet['interval']}
    started = clock()

    def persist():
        text = json.dumps(report, indent=2)
        require(len(text) <= 8*1024**2, 'Receipt bound')
        (output/'measurement.json').write_text(text)

    def bound():
        lease()
        require(0 <= clock()-started <= packet['limits']['total_wall'], 'Aggregate wall bound')

    try:
        # One warmup for each variant, then frozen alternating AB/BA pairs.
        order = [(None, 'baseline'), (None, 'candidate')]
        for pair in range(packet['pairs']):
            order += [(pair, mode) for mode in (('baseline', 'candidate') if pair % 2 == 0 else ('candidate', 'baseline'))]
        for index, (pair, mode) in enumerate(order):
            bound()
            validate_packet(packet, root)  # outside timed process interval
            work = output/str(index)
            work.mkdir()
            row = {'pair': pair, 'mode': mode, 'samples': [], 'complete': False}
            report['runs'].append(row)
            child = None
            try:
                bound()  # hashing/setup can consume the remaining lease
                child = adapter.launch(packet, root, work, mode)
                run_started = clock()
                row['identity'] = child.identity
                persist()
                previous = None
                while True:
                    bound()
                    sample = adapter.sample(child)
                    row['samples'].append(sample)
                    persist()
                    require(len(row['samples']) <= math.ceil(packet['limits']['wall']/packet['interval'])+2, 'Sample count bound')
                    require(0 <= clock()-run_started <= packet['limits']['wall'], 'Observer wall bound')
                    validate_sample(sample, child.identity, previous, packet['limits'])
                    output_bound(work, packet['limits']['output'])
                    previous = sample
                    if sample['exited']:
                        require(sample['exit_code'] == 0, 'Nonzero process exit')
                        row['cpu'] = sample['cpu']
                        row['wall'] = sample['wall']
                        memory_samples = [s['private'] for s in row['samples'] if s['private_sampled']]
                        require(memory_samples, 'No private memory sample')
                        row['sampled_private_peak'] = max(memory_samples)
                        break
                    pause(packet['interval'])
                accept(work, packet['limits']['output'])
            finally:
                cleanup = adapter.cleanup(child)  # also handles failed/partial launch
                row['cleanup'] = cleanup
                persist()
                require(cleanup['all_exited'] and cleanup['empty'] and not cleanup['errors'], 'Cleanup incomplete')
            bound()
            validate_packet(packet, root)
            row['complete'] = True
            if pair is not None:
                other = next((r for r in report['runs'] if r['pair'] == pair and r['mode'] != mode), None)
                if other:
                    row['parity'] = parity(output/str(report['runs'].index(other))/'states.jsonl', work/'states.jsonl')
                    require(row['parity'] == {'snapshots':6,'rows':1350,'equal':True}, 'Incomplete pair parity')
            persist()
        pairs = []
        for index in range(packet['pairs']):
            a, b = [next(r for r in report['runs'] if r['pair'] == index and r['mode'] == mode) for mode in ('baseline', 'candidate')]
            pairs.append({key: b[key]-a[key] for key in ('cpu', 'wall', 'sampled_private_peak')})
        report['paired_candidate_minus_baseline'] = pairs
        report['median_differences'] = {key: statistics.median(p[key] for p in pairs) for key in pairs[0]}
        # Final parity and input hashing can outlive the last process/lease.
        bound()
        validate_packet(packet, root)
        bound()
        report['complete'] = True
        report['interpretation'] = 'Raw fixture measurements only; significance, timer resolution and workload representativeness require review. No automatic speedup verdict.'
    except BaseException as error:
        report['error'] = str(error)
        raise
    finally:
        persist()
    return report


class LinuxAdapter:
    """One retained POSIX child/group per run, /proc samples and wait4 exit CPU.

    Requires externally established isolated runner/account/network. Sampling
    rejects sockets/children; it cannot prevent a connection between samples.
    """
    def __init__(self):
        require(os.name == 'posix' and Path('/proc/self/smaps_rollup').exists(), 'Linux /proc adapter required')
        self.child = None

    def launch(self, packet, root, work, mode):
        import resource
        import subprocess
        from types import SimpleNamespace
        require(self.child is None, 'Concurrent child')
        handles = []
        child = SimpleNamespace(handles=handles, process=None, started=time.monotonic(), result=None, last_private=0)
        self.child = child  # retain before launch; cleanup can close partial handles
        for name in ('stdout.log', 'stderr.log'):
            handles.append((work/name).open('wb'))
        def limits():
            resource.setrlimit(resource.RLIMIT_CPU, (10, 10))
            resource.setrlimit(resource.RLIMIT_FSIZE, (packet['limits']['output'],)*2)
        command = [str((root/packet['daemon']).resolve()), str((root/packet['dmb']).resolve())] + packet['command_tail'] + ['reserved='+('0' if mode == 'baseline' else '1')]
        child.process = subprocess.Popen(command, cwd=work, stdout=handles[0], stderr=handles[1], start_new_session=True, preexec_fn=limits)
        pid = child.process.pid
        stat = Path(f'/proc/{pid}/stat').read_text().rsplit(')', 1)[1].split()
        child.identity = {'pid': pid, 'start_ticks': int(stat[19])}
        return child

    def sample(self, child):
        require(child is self.child, 'Unknown child')
        pid = child.process.pid
        if child.result is None:
            waited, status, usage = os.wait4(pid, os.WNOHANG)
            if waited:
                child.result = (os.waitstatus_to_exitcode(status), usage.ru_utime+usage.ru_stime)
                child.process.returncode = child.result[0]
        row = {'identity': child.identity, 'wall': time.monotonic()-child.started, 'private': child.last_private,
               'private_sampled':False, 'children': [], 'sockets': [], 'exited': child.result is not None, 'exit_code': None}
        if child.result:
            row.update(cpu=child.result[1], exit_code=child.result[0])
            return row
        base = Path(f'/proc/{pid}')
        stat = (base/'stat').read_text().rsplit(')', 1)[1].split()
        require(int(stat[19]) == child.identity['start_ticks'], 'PID identity changed')
        row['cpu'] = (int(stat[11])+int(stat[12]))/os.sysconf('SC_CLK_TCK')
        data = (base/'smaps_rollup').read_text()
        row['private'] = private_bytes(data)
        row['private_sampled'] = True
        child.last_private = row['private']
        row['children'] = (base/'task'/str(pid)/'children').read_text().split()
        row['sockets'] = [p.name for p in (base/'fd').iterdir() if os.readlink(p).startswith('socket:')]
        return row

    def cleanup(self, child):
        import signal
        child = self.child
        errors = []
        empty = True
        if child and child.process:
            try:
                pid = child.process.pid
                deadline = time.monotonic()+5
                if not hasattr(child, 'identity'):
                    # Popen returned but identity acquisition failed. Until
                    # wait4 reaps it, our direct child's PID cannot be reused.
                    # Do not signal a group whose ownership was never recorded.
                    while child.result is None:
                        waited, status, usage = os.wait4(pid, os.WNOHANG)
                        if waited:
                            child.result = (os.waitstatus_to_exitcode(status), usage.ru_utime+usage.ru_stime)
                            child.process.returncode = child.result[0]
                            break
                        try:
                            os.kill(pid, signal.SIGKILL)
                        except ProcessLookupError:
                            pass  # still reap our retained child on the next pass
                        require(time.monotonic() < deadline, 'Direct-child cleanup deadline')
                        time.sleep(.01)
                    raise ValueError('Direct child reaped; group ownership unavailable, containment cleanup required')
                while True:
                    # A live leader must retain its birth identity. Descendants
                    # must retain the session/group established at launch.
                    members = self.group_members(child)
                    if members:
                        try:
                            os.killpg(pid, signal.SIGKILL)
                        except ProcessLookupError:
                            pass  # group disappeared after the ownership read
                    if child.result is None:
                        waited, status, usage = os.wait4(pid, os.WNOHANG)
                        if waited:
                            child.result = (os.waitstatus_to_exitcode(status), usage.ru_utime+usage.ru_stime)
                            child.process.returncode = child.result[0]
                    if not members and child.result is not None:
                        break
                    require(time.monotonic() < deadline, 'Cleanup deadline')
                    time.sleep(.01)
            except (OSError, ValueError) as error:
                errors.append(str(error))
                empty = False
        if child:
            for handle in child.handles:
                handle.close()
        self.child = None
        return {'all_exited': not errors, 'empty': empty, 'errors': errors}

    def group_members(self, child):
        pid = child.process.pid
        require(hasattr(child, 'identity'), 'Missing cleanup ownership identity')
        members = []
        for entry in Path('/proc').iterdir():
            if not entry.name.isdecimal():
                continue
            try:
                stat = (entry/'stat').read_text().rsplit(')', 1)[1].split()
            except FileNotFoundError:
                continue
            start = int(stat[19])
            if int(entry.name) == pid:
                require(start == child.identity['start_ticks'], 'Cleanup PID reused')
            if int(stat[2]) == pid:
                require(int(stat[3]) == pid and start >= child.identity['start_ticks'], 'Cleanup group ownership changed')
                members.append(int(entry.name))
        return members


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--packet', type=Path)
    parser.add_argument('--grant', type=Path)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--seal', type=Path, help='Hash prepared daemon/probe.dmb/probe.rsc/probe.dm/build.json only; never launch')
    parser.add_argument('--head', help='Immutable source commit for --seal')
    args = parser.parse_args()
    if args.seal:
        seal(args.seal, args.head)
        return
    require(all((args.packet, args.grant, args.output)), 'Packet/grant/output required')
    require(args.packet.stat().st_size <= 65536 and args.grant.stat().st_size <= 16384, 'Metadata bound')
    packet = json.loads(args.packet.read_text())
    grant = json.loads(args.grant.read_text())
    require(grant['packet_sha256'] == sha(args.packet) and grant['head'] == packet['head'], 'Grant identity')
    require(grant['executor'] == 'playable-owner' and grant['isolated_environment_accepted'] is True
            and grant['platform_adapter_accepted'] is True, 'Missing environment/executor grant')
    def lease():
        require(grant['starts_unix'] <= time.time() < grant['ends_unix'], 'Lease expired')
    lease()
    args.packet.with_suffix('.used').open('x').close()
    run(packet, args.packet.resolve().parent, args.output, LinuxAdapter(), lease=lease)


def seal(root, head):
    """Build the runnable bounded packet from owner-supplied compiled artifacts.

    build.json is provenance, not independent proof of compilation. The executor
    must check the referenced exact-head build evidence before granting a run.
    """
    root = root.resolve()
    require(re.fullmatch('[0-9a-f]{40}', head or ''), 'Seal head')
    names = ('daemon', 'probe.dmb', 'probe.rsc', 'probe.dm', 'build.json')
    for name in names:
        path = root/name
        require(path.is_file() and not path.is_symlink() and path.stat().st_size <= 1024**3, 'Seal input bound')
    require((root/'build.json').stat().st_size <= 16384, 'Build provenance bound')
    build = json.loads((root/'build.json').read_text())
    require(build['head'] == head and build['byond_version'] == '516.1681'
            and HEX.fullmatch(build['compiler_sha256']), 'Build provenance')
    for name in names[:4]:
        require(build['files'][name] == sha(root/name), 'Build input mismatch')
    packet = {'schema':1, 'head':head, 'pairs':10, 'interval':.1, 'execution':execution_identity(),
              'parity_run':39347909747, 'parity_head':'2d4229c2ca3062e6c358aa21575f0c203282f995',
              'fixture':'probe.dm', 'fixture_sha256':sha(root/'probe.dm'),
              'daemon':'daemon', 'dmb':'probe.dmb', 'rsc':'probe.rsc',
              'files':{name:sha(root/name) for name in names},
              'command_tail':['-close','-trusted','-log','runtime.log','-params'],
              'limits':{'wall':30,'cpu':10,'private':512*1024**2,'output':16*1024**2,'total_wall':960}}
    validate_packet(packet, root)
    with (root/'measurement-packet.json').open('x') as target:
        target.write(json.dumps(packet, indent=2)+'\n')
    return packet


if __name__ == '__main__':
    main()
