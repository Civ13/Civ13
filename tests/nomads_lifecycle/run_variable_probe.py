"""Grant-gated Windows collector fixture; imports are offline and side-effect free.

No grant creation, ACL mutation, live-game control, source update or activation.
The packet freezer supplies pinned copies of the previously reviewed Job adapter.
"""
import argparse
from contextlib import contextmanager
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import shutil
import socket
import sys
import time

SCOPE = 'one bounded private collector publication probe; no live runtime'
PORT = 59474
PHASES = dict(preflight=10, compile=20, writable=15, reader=10,
              missing=10, obstructed=10, final=5)
CAPS = dict(work_seconds=90, cleanup_seconds=30, aggregate_seconds=120,
            cpu_seconds=60, process_bytes=536870912, watcher_bytes=134217728,
            aggregate_bytes=805306368, generated_bytes=33554432,
            evidence_bytes=1048576, disk_free_bytes=6442450944,
            active=1, launches=4, inventory_entries=256, socket_close_seconds=5,
            receipt_bytes=262144, cleanup_bytes=262144, failure_bytes=16384)
MODES = ('writable', 'missing', 'obstructed')
SHARED_SLOT = Path('C:/Users/valza/Documents/Codex/2026-10-21/task-6/evidence/native-resource-reservations/valithor-aurora-civ13-native.active.json')
PROTOCOL_SHA256 = 'c93af043b4793075290c503d8994c50958fdc2ea665174302a4512f048d03a7a'


def need(value, message):
    if not value:
        raise RuntimeError(message)


def utc():
    return datetime.now(timezone.utc)


def digest(path, check=lambda: None):
    h = hashlib.sha256()
    with Path(path).open('rb') as source:
        while chunk := source.read(1024 * 1024):
            check()
            h.update(chunk)
    return h.hexdigest()


def read_json(path, maximum=65536):
    need(Path(path).stat().st_size <= maximum, 'JSON input bound')
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


class Budget:
    def __init__(self, end_utc, now=time.monotonic, wall=utc):
        self.now, self.wall, self.end_utc = now, wall, end_utc
        self.start = now()
        self.phase_end = self.start + CAPS['work_seconds']

    def check(self):
        need(self.now() < min(self.phase_end, self.start + CAPS['work_seconds'])
             and self.wall() < self.end_utc, 'Work, phase or lease deadline')

    @contextmanager
    def phase(self, name, records):
        begin = self.now()
        self.current = name
        self.phase_end = min(begin + PHASES[name], self.start + CAPS['work_seconds'])
        try:
            self.check()
            yield
            self.check()
        finally:
            records.append(dict(name=name, elapsed_seconds=self.now() - begin,
                                cap_seconds=PHASES[name]))


def validate_grant(packet, grant, packet_sha, runner_sha, now):
    need(packet['scope'] == grant['scope'] == SCOPE, 'Exact fixture grant scope')
    need(grant['packet_sha256'] == packet_sha and grant['runner_sha256'] == runner_sha,
         'Exact packet and runner authorization')
    need(packet['caps'] == grant['caps'] == CAPS and packet['phases'] == PHASES,
         'Fixed fixture limits')
    need(all(type(x) is int for x in (*packet['caps'].values(), *packet['phases'].values(), *grant['caps'].values())),
         'Integer-only fixed limits')
    need(packet['baseline'] == [] and grant['single_use'] is True,
         'Empty baseline and single-use required')
    starts, ends = (datetime.fromisoformat(grant[k]) for k in ('starts_utc', 'ends_utc'))
    need(starts <= now and (ends - now).total_seconds() >= CAPS['aggregate_seconds'],
         'Fresh full aggregate lease required')
    return ends


def validate_sockets(rows, *, runtime, closed):
    need(type(rows) is list and len(rows) <= 1, 'Socket inventory bound')
    for row in rows:
        need(runtime and not closed and row.get('protocol') == 'tcp'
             and row.get('state') == 'listen' and row.get('address') == '127.0.0.1'
             and row.get('port') == PORT, 'Only the fixed pre-closure loopback listener is allowed')


def vacant_port():
    # Local bind only, never listen/connect or query an existing server.
    with socket.socket() as probe:
        if sys.platform == 'win32':
            probe.setsockopt(socket.SOL_SOCKET, socket.SO_EXCLUSIVEADDRUSE, 1)
        probe.bind(('127.0.0.1', PORT))


def inventory(root, packet, check=lambda: None, receipt_bytes=0):
    total = evidence = count = 0
    inputs = packet['files']
    for path in root.rglob('*'):
        check(); count += 1
        need(count <= CAPS['inventory_entries'], 'Full artifact inventory entry cap')
        need(not path.is_symlink() and not path.is_junction(), 'Reparse input/output refused')
        if not path.is_file():
            continue
        name = path.relative_to(root).as_posix()
        need(name in inputs or name in packet['generated_files']
             or name.startswith('outputs/environment/'), 'Unexpected generated path: ' + name)
        size = path.stat().st_size; total += size
        if name == 'outputs/receipt.json' and receipt_bytes:
            total -= size
            continue
        if name not in inputs and name not in ('prepared/writable/probe.dmb', 'prepared/writable/probe.rsc'):
            evidence += size
    need(total + receipt_bytes <= CAPS['generated_bytes'], 'Whole packet/artifact byte cap')
    need(evidence + receipt_bytes <= CAPS['evidence_bytes'], 'Logs, environment, captures and receipt cap')
    return dict(total_bytes=total, evidence_bytes=evidence, entries=count)


def preserve_failure(out, report, error):
    """Keep a bounded terminal failure even if the ordinary artifact gate failed.

    Previous logs/receipt/cleanup are retained, never deleted to satisfy a cap.
    Any measured artifact-cap breach remains a failed attempt.
    """
    summary = dict(passed=False, native_verified=False, error=str(error)[:4096],
                   original_error=str(report.get('error', ''))[:4096],
                   elapsed_seconds=report.get('elapsed_seconds'),
                   cleanup_sha256=digest(out / 'cleanup.json') if (out / 'cleanup.json').exists() else None,
                   last_sample=report.get('samples', [])[-1:] ,
                   packet_sha256=report['packet_sha256'], runner_sha256=report['runner_sha256'])
    payload = json.dumps(summary, indent=2).encode()
    need(len(payload) <= CAPS['failure_bytes'], 'Terminal failure receipt cap')
    with (out / 'failure.json').open('xb') as stream:
        stream.write(payload)


def main(packet_path):
    root = Path(packet_path).resolve(strict=True).parent
    # This refusal precedes native imports, outputs, USED and all host queries.
    grant_path = root / 'grant.json'
    grant = read_json(grant_path)
    packet = read_json(packet_path)
    need(root.name.startswith('collector-native-packet-') and not (root / '.git').exists(),
         'Dedicated non-repository fixture root required')
    need(Path(packet['root']) == root and not root.is_symlink() and not root.is_junction(),
         'Pinned fixture root')
    need(Path(__file__).resolve() == root / 'run_variable_probe.py', 'Use the sealed packet runner')
    need(Path(packet['shared_slot']) == SHARED_SLOT, 'Established coordinator key only')
    need(Path(packet['compiler']).name == 'dm.exe' and Path(packet['daemon']).name == 'dd.exe'
         and packet['compiler'] in packet['executables'] and packet['daemon'] in packet['executables']
         and str(Path(sys.executable).resolve()) in packet['executables'], 'All exact execution identities pinned')
    need(all(not Path(name).is_absolute() and '..' not in Path(name).parts
             for name in (*packet['files'], *packet['generated_files'])), 'Packet-relative artifact paths only')
    end = validate_grant(packet, grant, digest(packet_path), digest(__file__), utc())
    budget = Budget(end)
    report = dict(passed=False, native_verified=False, scope=SCOPE, phases=[], samples=[],
                  identities=[], caps=CAPS, packet_sha256=digest(packet_path),
                  runner_sha256=digest(__file__), socket_observations=[])
    admission_hashes = {'packet.json': digest(packet_path), 'grant.json': digest(grant_path)}
    adapter = proc = None
    with budget.phase('preflight', report['phases']):
        need(not (root / 'USED').exists() and not (root / 'outputs').exists(), 'Attempt already consumed')
        for name, expected in packet['files'].items():
            budget.check()
            need(digest(root / name, budget.check) == expected, 'Frozen input changed: ' + name)
        for name, expected in packet['executables'].items():
            need(digest(name, budget.check) == expected, 'Pinned executable changed')
        slot_path = Path(packet['shared_slot'])
        need(digest(slot_path, budget.check) == grant['shared_slot_raw_sha256'], 'Matching coordinator slot required')
        slot = read_json(slot_path)
        need(slot.get('protocol_sha256') == PROTOCOL_SHA256, 'Existing coordination protocol required')
        for key, value in (('attempt_id', grant['attempt_id']), ('packet_sha256', digest(packet_path)),
                           ('runner_sha256', digest(__file__)), ('scope', SCOPE),
                           ('executor', grant['executor'])):
            need(slot.get(key) == value, 'Coordinator binding changed: ' + key)
        need(datetime.fromisoformat(slot['issued_utc']) <= utc()
             and datetime.fromisoformat(slot['expires_utc']) >= end, 'Grant must fit coordinator window')
        need(grant['single_use'] and grant['shared_claim_sha256'] == digest(grant['shared_claim_path']),
             'Fresh allocator-consumed shared claim required')
        claim = read_json(grant['shared_claim_path'])
        for key, value in (('attempt_id', grant['attempt_id']), ('packet_sha256', digest(packet_path)),
                           ('runner_sha256', digest(__file__)), ('scope', SCOPE), ('executor', grant['executor'])):
            need(claim.get(key) == value, 'Consumed claim binding changed: ' + key)
        inventory(root, packet, budget.check)
        sys.path.insert(0, str(root / 'helpers'))
        from windows import Adapter
        from owned_job import query_members, validate_members, capture_unexpected
        from native_policy import census
        from z_budget_evidence import validate_compile
        import guard_config
        need(guard_config.LIMITS == {'process_private_bytes': CAPS['process_bytes'],
                                    'watcher_private_bytes': CAPS['watcher_bytes']}, 'Hard adapter limits')
        need(census(timeout=2) == [], 'Native baseline must be empty; never stop Gaia to satisfy this')
        vacant_port(); budget.check()
        need(shutil.disk_usage(root).free >= CAPS['disk_free_bytes'], 'Disk floor')
        adapter = Adapter()
        adapter.preflight(guard_config.LIMITS)
        need(adapter.free() >= CAPS['aggregate_bytes'] + 4 * 1024**3, 'Physical memory floor')
    (root / 'USED').open('x').close()
    out = root / 'outputs'; out.mkdir()

    def save():
        encoded = json.dumps(report, indent=2).encode()
        need(len(encoded) <= CAPS['receipt_bytes'], 'Main receipt reserve cap')
        inventory(root, packet, receipt_bytes=len(encoded))
        (out / 'receipt.json').write_bytes(encoded)

    def sample(*, runtime=False, closed=True):
        budget.check()
        account, members = adapter.accounting(), query_members(adapter)
        # Retained handles identify the process after exit, but Windows may no
        # longer provide its memory counters. Never invent a zero memory sample.
        usage = (dict(exited=True, private_bytes=None,
                      watcher_private_bytes=adapter.memory(adapter.k.GetCurrentProcess()),
                      cpu_seconds=adapter.times(proc)[1])
                 if adapter.exited(proc) else adapter.sample(proc))
        row = dict(utc=utc().isoformat(), elapsed=budget.now() - budget.start,
                   phase=budget.current, usage=usage, membership=members,
                   accounting={k: getattr(account, k) for k, _ in account._fields_})
        report['samples'].append(row)
        need(len(report['samples']) <= 1000 and not account.terminated
             and account.total <= CAPS['launches'] and account.active <= 1
             and (account.user + account.kernel) / 1e7 <= CAPS['cpu_seconds'], 'Job bounds')
        need((usage['private_bytes'] is None or usage['private_bytes'] <= CAPS['process_bytes'])
             and usage['watcher_private_bytes'] <= CAPS['watcher_bytes']
             and (usage['private_bytes'] or 0) + usage['watcher_private_bytes'] <= CAPS['aggregate_bytes'], 'Memory bounds')
        for pid in members['pids']:
            if pid != proc.pid:
                row.setdefault('unexpected', []).append(capture_unexpected(adapter, pid))
        validate_members(members, proc.pid)
        sockets = adapter.sockets(proc)
        validate_sockets(sockets, runtime=runtime, closed=closed)
        report['socket_observations'].append(dict(pid=proc.pid, closed=closed, phase=budget.current,
                                                  elapsed=budget.now() - budget.start, rows=sockets))
        inventory(root, packet, budget.check); save()

    def run_child(name, argv, cwd):
        nonlocal proc
        child_begin = budget.now()
        proc = adapter.launch(argv, cwd, out, name)
        report['identities'].append(adapter.identity(proc)); save()
        runtime = name != 'compile'
        closed = not runtime
        close_end = min(budget.phase_end, child_begin + CAPS['socket_close_seconds'])
        while not adapter.exited(proc):
            sample(runtime=runtime, closed=closed)
            marker = cwd / 'probe-port-closed.txt'
            if runtime and not closed:
                need(budget.now() < close_end, 'Startup socket closure deadline')
                if marker.exists():
                    need(marker.stat().st_size <= 16 and marker.read_bytes().strip() == b'closed', 'Closure marker')
                    need(not adapter.sockets(proc), 'External closure not verified')
                    (cwd / 'probe-port-closed.ack').write_bytes(b'closed\n')
                    closed = True
                    report.setdefault('closures', []).append(dict(mode=name, pid=proc.pid,
                                                                   elapsed=budget.now() - child_begin))
            time.sleep(.1)
        final = adapter.finish(proc); report.setdefault('exits', []).append(final)
        need(final['exit_code'] == 0 and closed, 'Child failed or closure unacknowledged')
        drain_end = min(budget.phase_end, budget.now() + 2)
        while True:
            sample(runtime=runtime, closed=closed)
            account, members = adapter.accounting(), query_members(adapter)
            if account.active == 0 and members['pids'] == []:
                break
            need(budget.now() < drain_end, 'Owned Job did not drain')
            time.sleep(.025)
        return final

    try:
        adapter.open(); adapter.verify_job_empty = True
        with budget.phase('compile', report['phases']):
            writable = root / 'prepared/writable'
            final = run_child('compile', [packet['compiler'], 'probe.dme'], writable)
            logs = '\n'.join((out / ('compile.' + suffix + '.log')).read_text(errors='replace') for suffix in ('stdout', 'stderr'))
            validate_compile(final['exit_code'], logs, 'probe.dmb')
            need((writable / 'probe.dmb').is_file(), 'No compiled fixture')
            report['artifacts'] = {p.name: dict(bytes=p.stat().st_size, sha256=digest(p, budget.check))
                                   for p in (writable / 'probe.dmb', writable / 'probe.rsc') if p.is_file()}
        for mode in MODES:
            with budget.phase(mode, report['phases']):
                cwd = root / ('prepared/' + mode)
                argv = [packet['daemon'], str(writable / 'probe.dmb'), str(PORT), '-ip', '127.0.0.1',
                        '-trusted', '-invisible', '-close', '-cd', str(cwd), '-log', str(cwd / 'native.log')]
                run_child(mode, argv, cwd)
                text = (cwd / 'native.log').read_text(errors='replace')
                expected = ('VARIABLE_OBSERVABILITY failures=0 native_collector_only=1' if mode == 'writable'
                            else f'VARIABLE_OBSERVABILITY publication={mode} failures=0 native_collector_only=1')
                from z_budget_evidence import DIAGNOSTIC
                need(text.splitlines().count(expected) == 1 and not DIAGNOSTIC.search(text), 'Native assertion/diagnostic failure')
                need(not (cwd / 'data/variable-observability-last-failure.json').exists(), 'Legacy output appeared')
                if mode == 'missing':
                    need(not (cwd / 'data/desktop-supervisor/variable-observability').exists(), 'Missing directory was created')
                if mode == 'obstructed':
                    need((cwd / 'data/desktop-supervisor/variable-observability/last-failure.json').is_dir(), 'Obstruction changed')
            if mode == 'writable':
                with budget.phase('reader', report['phases']):
                    sys.path.insert(0, str(root / 'reader'))
                    import variable_observability as reader
                    report['reader'] = {}
                    for name in ('native-reference.json', 'native-operation-failure.json'):
                        result = reader.run(input_path=cwd / 'data/desktop-supervisor/variable-observability' / name,
                                            revision='b' * 40, session='c' * 32, round_id='probe-round')
                        need(result.get('ok') is True, 'Actual reader rejected native capture')
                        report['reader'][name] = result
                        budget.check()
        with budget.phase('final', report['phases']):
            for name, expected in admission_hashes.items():
                need(digest(root / name, budget.check) == expected, 'Admission metadata changed')
            for name, expected in packet['files'].items():
                need(digest(root / name, budget.check) == expected, 'Input changed: ' + name)
            need(census(timeout=2) == [], 'Final native census not empty')
            vacant_port(); inventory(root, packet, budget.check)
            report['passed'] = True
    except Exception as error:
        report['error'] = str(error)
    finally:
        remaining = min(CAPS['cleanup_seconds'], budget.start + CAPS['aggregate_seconds'] - budget.now(),
                        (end - utc()).total_seconds()) - 2
        try:
            report['cleanup'] = adapter.cleanup(proc, max(0, remaining))
        except Exception as error:
            # No foreign-PID fallback. Preserve inability to confirm cleanup.
            report['cleanup'] = dict(all_exited=False, retained_handles_all_exited=False,
                job_empty_verified=False, job_termination_success=False, exits=[],
                errors=['Owned cleanup raised: ' + str(error)[:4096]])
        clean = report['cleanup']
        cleanup_error = None
        cleanup_bytes = json.dumps(clean, indent=2).encode()
        if len(cleanup_bytes) <= CAPS['cleanup_bytes']:
            (out / 'cleanup.json').write_bytes(cleanup_bytes)
        else:
            # Preserve a bounded terminal summary; earlier membership samples
            # remain in receipt.json. Oversized cleanup evidence cannot pass.
            cleanup_error = 'Owned cleanup receipt cap'
            summary = {key: value for key, value in clean.items() if key != 'job_exit_samples'}
            summary['job_exit_sample_count'] = len(clean.get('job_exit_samples', []))
            summary['omitted_samples_sha256'] = hashlib.sha256(cleanup_bytes).hexdigest()
            summary['evidence_truncated'] = True
            encoded = json.dumps(summary, indent=2).encode()
            if len(encoded) <= CAPS['cleanup_bytes']:
                (out / 'cleanup.json').write_bytes(encoded)
        report['passed'] = report['passed'] and clean['all_exited'] and clean['retained_handles_all_exited'] and clean['job_empty_verified'] and clean['job_termination_success'] and not clean['errors']
        report['passed'] = report['passed'] and sum(x['cpu_seconds'] for x in clean['exits']) <= CAPS['cpu_seconds']
        try:
            left = min(2, budget.start + CAPS['aggregate_seconds'] - budget.now(), (end - utc()).total_seconds())
            need(left > 0 and census(timeout=left) == [], 'Post-cleanup census failed')
            vacant_port()
            report['fixed_port_vacant_after_cleanup'] = True
        except Exception as error:
            report['passed'] = False; report['cleanup_observation_error'] = str(error)
        report['elapsed_seconds'] = budget.now() - budget.start
        report['passed'] = report['passed'] and report['elapsed_seconds'] <= CAPS['aggregate_seconds'] and utc() <= end
        report['native_verified'] = report['passed']
        try:
            need(cleanup_error is None, cleanup_error)
            save()
        except Exception as error:
            report['passed'] = report['native_verified'] = False
            preserve_failure(out, report, error)
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    cli = argparse.ArgumentParser(description=__doc__)
    cli.add_argument('--packet', type=Path, required=True)
    try:
        raise SystemExit(main(cli.parse_args().packet))
    except (OSError, ValueError, KeyError, RuntimeError) as error:
        print(json.dumps(dict(passed=False, native_verified=False, error=str(error))))
        raise SystemExit(2)
