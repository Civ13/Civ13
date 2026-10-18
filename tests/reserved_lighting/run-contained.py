"""Single-use five-case runner, for core only after an exact reviewed grant."""
import argparse
import ctypes
from datetime import datetime, timezone, timedelta
import hashlib
import json
from pathlib import Path
import shutil
import sys
import time


def require(value, message):
    if not value:
        raise RuntimeError(message)


def digest(path):
    value = hashlib.sha256()
    with Path(path).open('rb') as source:
        for chunk in iter(lambda: source.read(1024**2), b''):
            value.update(chunk)
    return value.hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--packet', type=Path, required=True)
    parser.add_argument('--grant', type=Path, required=True)
    args = parser.parse_args()
    require(args.packet.stat().st_size <= 4 * 1024**2 and args.grant.stat().st_size <= 16384, 'Input metadata bound')
    packet = json.loads(args.packet.read_text(encoding='utf-8'))
    grant = json.loads(args.grant.read_text(encoding='utf-8'))
    require(digest(args.packet) == grant['packet_sha256'] and packet['head'] == grant['head'], 'Grant/packet mismatch')
    require(grant['executor'] == 'core' and grant['helper_native_accepted'] is True, 'Core/helper acceptance absent')
    out = args.packet.resolve().parent
    for relative, identity in packet['files'].items():
        path = (out/relative).resolve()
        require(path.is_relative_to(out) and path.stat().st_size == identity['bytes']
                and digest(path) == identity['sha256'], 'Frozen input changed: ' + relative)
    require(Path(__file__).resolve() == out/'run-contained.py', 'Wrong runner')
    for path, identity in packet['binaries'].items():
        require(digest(path) == identity, 'Pinned executable changed')
    sys.path.insert(0, str(out/'adapter'))
    import windows as w
    import guard_config as guard
    from native_policy import census, validate_baseline, validate_sockets
    from owned_job import query_members, validate_members, settle
    from z_budget_evidence import DIAGNOSTIC, validate_compile
    sys.path.insert(0, str(out/'source/tests/reserved_lighting'))
    from compare import compare
    require(Path(w.__file__).resolve() == out/'adapter/windows.py', 'Wrong adapter')
    now = datetime.now(timezone.utc)
    ends = datetime.fromisoformat(grant['ends_utc'])
    require(datetime.fromisoformat(grant['starts_utc']) <= now and (ends-now).total_seconds() >= 620, 'Lease margin')
    (out/'USED').open('x').close()
    started = time.monotonic()
    report = {'head': packet['head'], 'pass_result': False, 'profiles': [], 'no_live_actions': True}

    def persist():
        text = json.dumps(report, indent=2)
        require(len(text.encode()) <= 8 * 1024**2, 'Receipt bound')
        (out/'receipt.json').write_text(text, encoding='utf-8')

    def bound():
        require(time.monotonic()-started < 600 and datetime.now(timezone.utc) < ends-timedelta(seconds=10), 'Total/lease bound')

    def baseline():
        bound()
        validate_baseline(census(), grant['gaia'], packet['daemon'])
        bound()

    def accounting(adapter):
        value = adapter.accounting()
        return {name: getattr(value, name) for name, _ in value._fields_}

    def text_bound(work):
        files = [p for p in (out/'native').rglob('*') if p.is_file() and p.suffix not in ('.dmb', '.rsc')]
        require(sum(p.stat().st_size for p in files) + ((out/'receipt.json').stat().st_size if (out/'receipt.json').exists() else 0)
                <= 16 * 1024**2, 'Generated logs/state/receipt bound')

    expected = {'virtual-master': None, 'halo': 'overlay allocation count', 'refusal-owner': 'refused constructor detached before deferred deletion'}
    try:
        for profile in packet['profiles']:
            baseline()
            name = profile['name']
            work = out/'native'/name
            work.mkdir(parents=True, exist_ok=False)
            row = {'name': name, 'phases': [], 'pass_result': False}
            report['profiles'].append(row)
            adapter = w.Adapter()
            try:
                adapter.preflight(guard.LIMITS)
                adapter.open()
                for phase in ('compile', 'runtime'):
                    baseline()
                    memory = 1024**3 if phase == 'compile' else 512 * 1024**2
                    seconds, cpu = (75, 30) if phase == 'compile' else (30, 10)
                    limits = w.JobLimits()
                    limits.basic.flags = 0x2000 | 0x8 | 0x100
                    limits.basic.active = 1
                    limits.process_memory = memory
                    adapter.check(adapter.k.SetInformationJobObject(adapter.job, 9, ctypes.byref(limits), ctypes.sizeof(limits)))
                    dme = Path(profile['dme'])
                    if phase == 'compile':
                        command, cwd = [packet['compiler'], '-max_errors', '0', str(dme)], dme.parent
                    else:
                        row['artifacts'] = {}
                        for suffix in ('.dmb', '.rsc'):
                            source = dme.with_suffix(suffix)
                            require(source.is_file() and source.stat().st_size <= packet['compiled_artifact_bound_each'], 'Compiled resource/artifact bound')
                            row['artifacts'][suffix] = {'bytes': source.stat().st_size, 'sha256': digest(source)}
                            shutil.copyfile(source, work/source.name)
                        command = [packet['daemon'], dme.with_suffix('.dmb').name, '59474', '-ip', '127.0.0.1',
                                   '-invisible', '-close', '-trusted', '-log', 'runtime.log', '-params',
                                   'reserved=' + ('1' if profile['reserved'] else '0')]
                        cwd = work
                    before = accounting(adapter)
                    child = adapter.launch(command, cwd, work, phase)
                    phase_start = time.monotonic()
                    receipt = {'phase': phase, 'identity': adapter.identity(child), 'samples': [], 'drain': []}
                    row['phases'].append(receipt)

                    def check(current):
                        bound()
                        require(time.monotonic()-phase_start < seconds and
                                (current['user']+current['kernel']-before['user']-before['kernel'])/1e7 < cpu, 'Phase wall/CPU bound')
                        adapter.check(adapter.k.QueryInformationJobObject(adapter.job, 9, ctypes.byref(limits), ctypes.sizeof(limits), None))
                        require(limits.basic.flags == 8456 and limits.basic.active == 1 and limits.process_memory == memory, 'Job limit drift')
                        require(current['terminated'] == before['terminated'] and adapter.memory(adapter.k.GetCurrentProcess()) <= 128 * 1024**2,
                                'Termination/watcher bound')
                        text_bound(work)

                    while not adapter.exited(child):
                        sample = adapter.sample(child)
                        sample['membership'] = query_members(adapter)
                        validate_members(sample['membership'], child.pid)
                        sample['sockets'] = adapter.sockets(child)
                        validate_sockets(sample['sockets'], phase, (work/'port-closed.txt').exists())
                        require(sample['private_bytes'] <= memory and sample['watcher_private_bytes'] <= 128 * 1024**2, 'Private memory bound')
                        receipt['samples'].append(sample)
                        check(accounting(adapter))
                        persist()
                        time.sleep(.1)
                    receipt['immediate_final'] = adapter.finish(child)
                    receipt['immediate_accounting'] = accounting(adapter)
                    receipt['immediate_membership'] = query_members(adapter)
                    persist()
                    validate_members(receipt['immediate_membership'])
                    require(receipt['immediate_final']['exit_code'] == 0, 'Native exit failed')

                    def record(value):
                        receipt['drain'].append(value)
                        persist()

                    settle(lambda: accounting(adapter), lambda: query_members(adapter), check, record)
                    receipt['final'] = adapter.finish(child)
                    receipt['final_membership'] = query_members(adapter)
                    validate_members(receipt['final_membership'])
                    check(accounting(adapter))
                    require(receipt['final']['exit_code'] == 0 and receipt['final']['cpu_seconds'] <= cpu, 'Terminal limits')
                    logs = '\n'.join((work/(phase+'.'+suffix+'.log')).read_text(errors='replace') for suffix in ('stdout', 'stderr'))
                    require(not DIAGNOSTIC.search(logs), 'Unexpected stdio diagnostic')
                    if phase == 'compile':
                        validate_compile(0, logs, dme.with_suffix('.dmb').name)
                    else:
                        require((work/'port-closed.txt').read_bytes() in (b'closed\n', b'closed\r\n'), 'Closure marker')
                        runtime = (work/'runtime.log').read_text(errors='replace')
                        require(not DIAGNOSTIC.search(runtime), 'Unexpected runtime diagnostic')
                        actual = (work/'result.txt').read_text().strip()
                        row['actual'] = actual
                        if name in ('baseline', 'candidate'):
                            require(actual == 'PASS', 'Positive fixture failed: ' + actual)
                        elif expected[name] is not None:
                            require(actual == 'FAIL: assertion: ' + expected[name], 'Wrong control failure: ' + actual)
                        else:
                            require(actual == 'PASS', 'Virtual-master must reach structural comparison')
                    persist()
            finally:
                row['cleanup'] = adapter.cleanup(None, 10)
                persist()
                require(row['cleanup']['all_exited'] and not row['cleanup']['errors'], 'Owned cleanup incomplete')
                baseline()
            row['pass_result'] = True
        report['parity'] = compare(out/'native/baseline/states.jsonl', out/'native/candidate/states.jsonl')
        try:
            compare(out/'native/baseline/states.jsonl', out/'native/virtual-master/states.jsonl')
        except ValueError as error:
            require(str(error).startswith('Native snapshot mismatch:'), 'Incomplete virtual-master control')
            report['virtual_master_detected'] = str(error)
        else:
            raise RuntimeError('Virtual-master control escaped detection')
        report['pass_result'] = True
    except BaseException as error:
        report['error'] = str(error)
        raise
    finally:
        report['elapsed_including_cleanup'] = time.monotonic()-started
        persist()


if __name__ == '__main__':
    main()
