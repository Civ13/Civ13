"""Single-use Windows native packet runner. Requires an exact reviewed grant."""
import argparse
import ctypes
from datetime import datetime, timezone, timedelta
import hashlib
import json
from pathlib import Path
import re
import shutil
import sys
import time
from z_budget_evidence import DIAGNOSTIC, validate_compile
from native_policy import census, validate_baseline, validate_sockets
from owned_job import query_members, validate_members, settle

RUNS = (('fixed', 'fixed', None), ('eager-parity', 'eager', None),
        ('eager-negative', 'eager', 'bare turf allocation count'),
        ('missing-lazy', 'missing-lazy', 'first decal records key'),
        ('shared', 'shared', 'two turf lists have independent identity'))


def require(value, message):
    if not value:
        raise RuntimeError(message)


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def validate_native(log, expected, eager=False):
    require(not DIAGNOSTIC.search(log) and 'FAIL diagnostic:' not in log, 'Unexpected engine/runtime diagnostic')
    failures = re.findall(r'^FAIL (.+)$', log, re.M)
    assertions = [line for line in failures if not line.startswith('exception: ')]
    if expected:
        require(assertions == [expected], f'Wrong control failure: {assertions}')
        require('PASS floor decal tracking' not in log, 'Control claimed PASS')
        require(failures == [expected, f'exception: assertion: {expected}'], 'Missing or extra controlled assertion exit')
    else:
        require(not failures, f'Unexpected fixture assertion: {failures}')
        require(re.findall(r'^PASS floor decal tracking (\d+) checks$', log, re.M) == ['33'],
                'Incomplete fixture assertion count')
        metrics = re.findall(r'^TRACKING initialized_turfs=(\d+) distinct_native_lists=(\d+)$', log, re.M)
        require(metrics == ([('128', '128')] * 3 if eager else [('0', '0'), ('1', '1'), ('2', '2')]),
                f'Wrong native tracking counts: {metrics}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--packet', required=True, type=Path)
    parser.add_argument('--grant', required=True, type=Path)
    args = parser.parse_args()
    packet = json.loads(args.packet.read_text())
    grant = json.loads(args.grant.read_text())
    require(digest(args.packet) == grant['packet_sha256'], 'Packet differs from grant')
    require(packet['head'] == grant['head'], 'Head differs from grant')
    require(digest(__file__) == packet['runner_sha256'], 'Runner changed')
    for path, sha in packet['files'].items():
        require(digest(path) == sha, 'Frozen input changed: ' + path)
    now = datetime.now(timezone.utc)
    ends = datetime.fromisoformat(grant['ends_utc'])
    require(datetime.fromisoformat(grant['starts_utc']) <= now and (ends - now).total_seconds() >= 250,
            'Invalid single-use lease or cleanup margin')
    out = args.packet.resolve().parent
    (out / 'USED').open('x').close()
    sys.path.insert(0, str(Path(packet['adapter_root']).resolve()))
    import windows as w
    import guard_config as guard
    require(Path(w.__file__).resolve() == Path(packet['adapter_root']).resolve() / 'windows.py',
            'Wrong containment adapter')
    report = {'head': packet['head'], 'pass_result': False, 'runs': [], 'live_actions': False}
    started = time.monotonic()

    def persist():
        (out / 'receipt.json').write_text(json.dumps(report, indent=2) + '\n')

    def bound():
        require(time.monotonic() - started < 230 and datetime.now(timezone.utc) < ends - timedelta(seconds=10),
                'Packet deadline reached')

    def accounting(adapter):
        value = adapter.accounting()
        return {name: getattr(value, name) for name, _ in value._fields_}

    def baseline(label):
        bound()
        rows = census()
        report.setdefault('native_census', []).append({'label': label, 'rows': rows})
        persist()
        validate_baseline(rows, packet['gaia'], packet['daemon'])
        bound()

    try:
        for label, case, expected in RUNS:
            bound()
            work = out / 'native' / label
            work.mkdir(parents=True, exist_ok=False)
            frozen = Path(packet['sources']) / case
            row = {'label': label, 'expected_failure': expected, 'phases': []}
            report['runs'].append(row)
            persist()
            adapter = w.Adapter()
            try:
                adapter.preflight(guard.LIMITS)
                adapter.open()
                for phase in ('compile', 'runtime'):
                    bound()
                    baseline(label + ':' + phase)
                    memory = 1024**3 if phase == 'compile' else 512 * 1024**2
                    limits = w.JobLimits()
                    limits.basic.flags = 0x2000 | 0x8 | 0x100
                    limits.basic.active = 1
                    limits.process_memory = memory
                    adapter.check(adapter.k.SetInformationJobObject(adapter.job, 9, ctypes.byref(limits), ctypes.sizeof(limits)))
                    if phase == 'compile':
                        command = [packet['compiler'], '-max_errors', '0', str(frozen / 'probe.dme')]
                        cwd = frozen
                    else:
                        for suffix in ('.dmb', '.rsc'):
                            source = frozen / ('probe' + suffix)
                            require(source.is_file(), 'Missing compiled artifact: ' + suffix)
                            shutil.copy2(source, work / source.name)
                        row['binary_sha256'] = {name: digest(work / name) for name in ('probe.dmb', 'probe.rsc')}
                        command = [packet['daemon'], 'probe.dmb', '59474', '-ip', '127.0.0.1',
                                   '-invisible', '-close', '-trusted', '-log', 'runtime.log']
                        if label == 'eager-parity':
                            command += ['-params', 'eager=1']
                        cwd = work
                    before = accounting(adapter)
                    child = adapter.launch(command, cwd, work, phase)
                    phase_start = time.monotonic()
                    receipt = {'phase': phase, 'identity': adapter.identity(child), 'samples': []}
                    row['phases'].append(receipt)
                    persist()
                    print(json.dumps({'label': label, 'phase': phase, 'identity': receipt['identity']}), flush=True)
                    seconds, cpu = (60, 30) if phase == 'compile' else (15, 10)
                    while not adapter.exited(child):
                        bound()
                        sample = adapter.sample(child)
                        sample['sockets'] = adapter.sockets(child)
                        sample['membership'] = query_members(adapter)
                        receipt['samples'].append(sample)
                        current = accounting(adapter)
                        sample['accounting'] = current
                        validate_members(sample['membership'], child.pid)
                        adapter.check(adapter.k.QueryInformationJobObject(adapter.job, 9, ctypes.byref(limits), ctypes.sizeof(limits), None))
                        require(limits.basic.flags == 8456 and limits.basic.active == 1 and limits.process_memory == memory,
                                'Job limits changed')
                        require(time.monotonic() - phase_start < seconds and
                                (current['user'] + current['kernel'] - before['user'] - before['kernel']) / 1e7 < cpu,
                                'Phase wall/CPU limit')
                        require(sample['private_bytes'] <= memory and sample['watcher_private_bytes'] <= 128 * 1024**2 and
                                current['terminated'] == before['terminated'], 'Resource/termination limit')
                        validate_sockets(sample['sockets'], phase, (work / 'port-closed.txt').exists())
                        require(sum(p.stat().st_size for p in work.rglob('*') if p.is_file()) <= 16 * 1024**2,
                                'Generated-output bound')
                        time.sleep(.1)
                    receipt['immediate_final'] = adapter.finish(child)
                    receipt['immediate_accounting'] = accounting(adapter)
                    receipt['immediate_membership'] = query_members(adapter)
                    persist()
                    validate_members(receipt['immediate_membership'])
                    require(receipt['immediate_final']['exit_code'] == 0, 'Native process exit failure')
                    receipt['accounting_drain'] = []

                    def drain_check(value):
                        bound()
                        require(time.monotonic() - phase_start < seconds and
                                (value['user'] + value['kernel'] - before['user'] - before['kernel']) / 1e7 < cpu,
                                'Drain phase wall/CPU limit')
                        adapter.check(adapter.k.QueryInformationJobObject(adapter.job, 9, ctypes.byref(limits), ctypes.sizeof(limits), None))
                        require(limits.basic.flags == 8456 and limits.basic.active == 1 and limits.process_memory == memory,
                                'Drain Job limits changed')
                        require(adapter.memory(adapter.k.GetCurrentProcess()) <= 128 * 1024**2 and
                                value['terminated'] == before['terminated'], 'Drain resource/termination limit')
                        require(sum(p.stat().st_size for p in work.rglob('*') if p.is_file()) <= 16 * 1024**2,
                                'Drain generated-output bound')

                    def drain_record(value):
                        receipt['accounting_drain'].append(value)
                        persist()

                    settle(lambda: accounting(adapter), lambda: query_members(adapter), drain_check, drain_record)
                    receipt['final'] = adapter.finish(child)
                    receipt['final_membership'] = query_members(adapter)
                    validate_members(receipt['final_membership'])
                    receipt['elapsed'] = time.monotonic() - phase_start
                    after = accounting(adapter)
                    require(receipt['final']['exit_code'] == 0 and after['active'] == 0 and
                            after['terminated'] == before['terminated'], 'Native exit/descendant failure')
                    require(receipt['elapsed'] < seconds and receipt['final']['cpu_seconds'] <= cpu and
                            (after['user'] + after['kernel'] - before['user'] - before['kernel']) / 1e7 <= cpu,
                            'Terminal phase limits')
                    require(sum(p.stat().st_size for p in work.rglob('*') if p.is_file()) <= 16 * 1024**2,
                            'Terminal generated-output bound')
                    logs = '\n'.join((work / (phase + '.' + suffix + '.log')).read_text(errors='replace')
                                     for suffix in ('stdout', 'stderr'))
                    require(not DIAGNOSTIC.search(logs), 'Unexpected native stdio diagnostic')
                    if phase == 'compile':
                        validate_compile(receipt['final']['exit_code'], logs, 'probe.dmb')
                    else:
                        runtime_log = work / 'runtime.log'
                        require(runtime_log.stat().st_size <= 1024**2, 'Runtime log exceeds read bound')
                        marker = work / 'port-closed.txt'
                        require(marker.stat().st_size <= 16, 'Fixture closure marker exceeds read bound')
                        require(marker.read_bytes() in (b'closed\n', b'closed\r\n'),
                                'Fixture closure marker missing or invalid')
                        validate_native(runtime_log.read_text(errors='replace'), expected,
                                        eager=label == 'eager-parity')
                    persist()
                row['pass_result'] = True
            finally:
                row['cleanup'] = adapter.cleanup(None, 10)
                persist()
                require(row['cleanup']['all_exited'] and not row['cleanup']['errors'], 'Owned cleanup incomplete')
                baseline(label + ':cleanup')
            bound()
        report['pass_result'] = True
    except BaseException as exc:
        report['error'] = str(exc)
        raise
    finally:
        report['elapsed_including_cleanup'] = time.monotonic() - started
        persist()


if __name__ == '__main__':
    main()
