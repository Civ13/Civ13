"""Tiny collector/reader fixture on secret-free ephemeral Linux PR CI only.

Independent hosted runner. Never changes or consumes the frozen Windows packet.
No real world/config/account inputs, client, Topic request or ACL mutation.
"""
import argparse
from datetime import datetime, timedelta, timezone
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import signal
import socket
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
from prepare_variable_probe import prepare
from run_variable_probe import Budget, CAPS, MODES, PHASES, PORT, need, validate_sockets
sys.path.insert(0, str(ROOT / 'tests/new_z_budget'))
from z_budget_evidence import DIAGNOSTIC, validate_compile


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def native_gate(output, byond, head, archive=None):
    need(sys.platform == 'linux' and os.environ.get('GITHUB_ACTIONS') == 'true'
         and os.environ.get('RUNNER_OS') == 'Linux' and os.environ.get('GITHUB_EVENT_NAME') == 'pull_request'
         and os.environ.get('GITHUB_REPOSITORY') == 'Civ13/Civ13', 'Requires isolated Linux PR CI')
    need(re.fullmatch('[a-f0-9]{40}', head) is not None, 'Exact source head required')
    workspace = Path(os.environ['GITHUB_WORKSPACE']).resolve(strict=True)
    temporary = Path(os.environ['RUNNER_TEMP']).resolve(strict=True)
    need(ROOT.resolve() == workspace and output.resolve().is_relative_to(temporary)
         and output.resolve() != temporary and not output.exists(), 'New output under RUNNER_TEMP required')
    version = '1688' if archive is not None else '1681'
    need(byond.resolve(strict=True) == workspace / 'BYOND/byond/bin'
         and os.environ.get('BYOND_MAJOR') == '516' and os.environ.get('BYOND_MINOR') == version,
         'Existing pinned CI engine required')
    if archive is not None:
        need(archive.resolve(strict=True) == workspace / 'BYOND/pinned.zip',
             'Current engine requires the exact CI archive path')


def current_runtime(byond, archive):
    """Explicit 1688 adapter; the no-archive historical path remains pinned 1681."""
    if archive is None:
        return None
    spec = importlib.util.spec_from_file_location('collector_current_runtime', ROOT / 'tests/world_save/current_runtime.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.select(byond, archive)


def parse_stat(text):
    prefix, fields = text.rsplit(')', 1)
    fields = fields.split()
    need(len(fields) >= 22, 'Truncated process identity')
    return dict(pid=int(prefix.split('(', 1)[0]), state=fields[0], pgrp=int(fields[2]),
                session=int(fields[3]), start_ticks=int(fields[19]), cpu_ticks=int(fields[11]) + int(fields[12]),
                resident_pages=int(fields[21]))


def identity(pid):
    return parse_stat(Path(f'/proc/{pid}/stat').read_text())


def processes():
    rows = []
    entries = list(Path('/proc').iterdir())
    need(len(entries) <= 4096, 'Host process inventory bound')
    for path in entries:
        if path.name.isdigit():
            try:
                rows.append(identity(int(path.name)))
            except FileNotFoundError:
                pass
    return rows


def native_census():
    rows = []
    for row in processes():
        try:
            name = Path(f'/proc/{row["pid"]}/comm').read_text().strip().lower()
        except FileNotFoundError:
            continue
        if name in ('dm', 'dd', 'dreammaker', 'dreamdaemon'):
            rows.append(row)
    return rows


def group_members(pid):
    return [row for row in processes() if row['pgrp'] == pid or row['session'] == pid]


def socket_rows(inodes, tables):
    rows = []
    for name in ('tcp', 'tcp6', 'udp', 'udp6'):
        need(len(tables[name]) <= 1048576, 'Socket table bound')
        for line in tables[name].splitlines()[1:]:
            fields = line.split()
            need(len(fields) >= 10, 'Truncated socket row')
            if fields[9] not in inodes:
                continue
            raw, port = fields[1].split(':')
            octets = bytes.fromhex(raw)
            address = socket.inet_ntop(socket.AF_INET6 if name.endswith('6') else socket.AF_INET,
                b''.join(octets[i:i+4][::-1] for i in range(0, len(octets), 4)))
            rows.append(dict(protocol='udp' if name.startswith('udp') else 'tcp', address=address,
                             port=int(port, 16), state='listen' if fields[3] == '0A' else fields[3]))
    return rows


def owned_sockets(pid, birth):
    need(identity(pid)['start_ticks'] == birth, 'Socket census identity changed')
    descriptors = list(Path(f'/proc/{pid}/fd').iterdir())
    need(len(descriptors) <= 256, 'Owned descriptor bound')
    inodes = set()
    for path in descriptors:
        try:
            link = os.readlink(path)
        except FileNotFoundError:
            continue
        if link.startswith('socket:['):
            inodes.add(link[8:-1])
    tables = {name: Path(f'/proc/{pid}/net/{name}').read_text() for name in ('tcp', 'tcp6', 'udp', 'udp6')}
    rows = socket_rows(inodes, tables)
    need(identity(pid)['start_ticks'] == birth, 'Socket census lost process identity')
    return rows


def acknowledge(case, rows):
    marker = case / 'probe-port-closed.txt'
    need(marker.stat().st_size <= 16 and marker.read_bytes().strip() == b'closed', 'Invalid closure marker')
    validate_sockets(rows, runtime=True, closed=True)
    (case / 'probe-port-closed.ack').write_bytes(b'closed\n')


def vacant_port():
    with socket.socket() as probe:
        probe.bind(('127.0.0.1', PORT))


def generated():
    names = {'source-manifest.json', 'result.json', 'failure.json', 'runtime-identity.json', 'prepared/writable/probe.dmb', 'prepared/writable/probe.rsc'}
    for phase in ('compile', *MODES):
        names.update(f'{phase}.{stream}.log' for stream in ('stdout', 'stderr'))
    for mode in MODES:
        names.update(f'prepared/{mode}/{name}' for name in ('probe-port-closed.txt',
            'probe-port-closed.ack', 'config/variable-observability.txt', 'config/lifecycle-token.txt',
            'config/lifecycle-revision.txt'))
    names.update('prepared/writable/data/desktop-supervisor/variable-observability/' + name for name in (
        'last-failure.json', 'native-reference.json', 'native-operation-failure.json'))
    names.update('prepared/writable/native-' + mode + '.log' for mode in MODES)
    return names


def artifacts(root, inputs, pending=0):
    total = evidence = entries = 0
    for path in root.rglob('*'):
        entries += 1
        need(entries <= CAPS['inventory_entries'] and not path.is_symlink(), 'Artifact entry/reparse bound')
        if not path.is_file():
            continue
        name = path.relative_to(root).as_posix()
        need(name in inputs or name in generated() or name.startswith('environment/'), 'Unexpected artifact: ' + name)
        size = path.stat().st_size
        if name == 'result.json' and pending:
            continue
        total += size
        if name not in inputs and name not in ('prepared/writable/probe.dmb', 'prepared/writable/probe.rsc'):
            evidence += size
    need(total + pending <= CAPS['generated_bytes'] and evidence + pending <= CAPS['evidence_bytes'], 'Artifact byte budget')
    return dict(bytes=total + pending, evidence_bytes=evidence + pending, entries=entries)


def child_limits():
    import resource
    for kind, value in ((resource.RLIMIT_AS, CAPS['process_bytes']), (resource.RLIMIT_CPU, 15),
                        (resource.RLIMIT_FSIZE, CAPS['evidence_bytes']), (resource.RLIMIT_CORE, 0)):
        resource.setrlimit(kind, (value, value))


def exited_unreaped(process):
    return os.waitid(os.P_PID, process.pid, os.WEXITED | os.WNOHANG | os.WNOWAIT) is not None


def cleanup(process, birth, deadline):
    receipt = dict(pid=process.pid, start_ticks=birth['start_ticks'], group_empty=False, errors=[])
    try:
        current = identity(process.pid)
        need(all(current[key] == birth[key] for key in ('pid', 'start_ticks', 'pgrp', 'session'))
             and current['pgrp'] == current['session'] == process.pid, 'Owned cleanup birth/group changed')
        # Like the existing extraction runner, WNOWAIT leaves this leader
        # unreaped, reserving its PID until owned process-group cleanup finishes.
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        while True:
            members = group_members(process.pid)
            if all(row['state'] == 'Z' for row in members):
                break
            need(time.monotonic() < deadline, 'Owned group cleanup deadline')
            time.sleep(.025)
        process.wait(timeout=max(.001, deadline - time.monotonic()))
        receipt.update(exit_code=process.returncode, group_empty=not group_members(process.pid))
        need(receipt['group_empty'], 'Owned group remains after reap')
    except Exception as error:
        receipt['errors'].append(str(error))
    return receipt


def load_reader():
    sys.path.insert(0, str(ROOT / 'scripts/nomads-lifecycle'))
    spec = importlib.util.spec_from_file_location('hosted_collector_reader', ROOT / 'scripts/nomads-lifecycle/variable_observability.py')
    reader = importlib.util.module_from_spec(spec); spec.loader.exec_module(reader)
    return reader


def read_captures(case, receipt, budget):
    reader = load_reader(); receipt['reader'] = {}
    for name in ('native-reference.json', 'native-operation-failure.json'):
        budget.check()
        result = reader.run(input_path=case / 'data/desktop-supervisor/variable-observability' / name,
                            revision='b' * 40, session='c' * 32, round_id='probe-round')
        receipt['reader'][name] = result
        need(result.get('ok') is True, 'Actual reader rejected retained native capture')


def native_log_path(compiled, mode):
    need(mode in MODES, 'Fixed publication mode required')
    return compiled.parent / ('native-' + mode + '.log')


def daemon_argv(byond, compiled, case):
    # Linux DreamDaemon permits a relative log basename, rejecting absolute
    # log paths even in trusted mode. Logs are anchored to the DMB directory,
    # while fixture data/config still use the explicit cwd/-cd directory.
    return [str(byond / 'DreamDaemon'), str(compiled), str(PORT), '-ip', '127.0.0.1',
            '-trusted', '-close', '-cd', str(case), '-log', native_log_path(compiled, case.name).name]


def run_child(argv, case, phase, root, inputs, binary_hashes, receipt, budget, save, runtime=None):
    import resource
    if runtime:
        budget.check()
        runtime.before_launch(phase, root)
    budget.check(); need(sha(argv[0]) == binary_hashes[Path(argv[0]).name], 'Engine changed before launch')
    need(len(receipt['children']) < CAPS['launches'], 'Native launch budget')
    child = birth = None; closed = phase == 'compile'; started = time.monotonic()
    row = dict(phase=phase, argv=argv, closed=False, samples=[], cleanup=None)
    receipt['children'].append(row)
    before_cpu = resource.getrusage(resource.RUSAGE_CHILDREN)
    environment = root / 'environment'; environment.mkdir(exist_ok=True)
    env = dict(PATH=str(Path(argv[0]).parent) + ':/usr/bin:/bin', LD_LIBRARY_PATH=str(Path(argv[0]).parent),
               HOME=str(environment), TMPDIR=str(environment), LANG='C.UTF-8')
    with (root / (phase + '.stdout.log')).open('xb') as stdout, (root / (phase + '.stderr.log')).open('xb') as stderr:
        try:
            child = subprocess.Popen(argv, cwd=case, stdin=subprocess.DEVNULL, stdout=stdout, stderr=stderr,
                                     env=env, start_new_session=True, preexec_fn=child_limits)
            birth = identity(child.pid); row['identity'] = birth
            need(birth['pgrp'] == birth['session'] == child.pid, 'Dedicated owned child session required')
            while not exited_unreaped(child):
                budget.check()
                current = identity(child.pid)
                need(current['start_ticks'] == birth['start_ticks'], 'Child birth changed')
                members = group_members(child.pid)
                need(len(members) == 1 and members[0]['pid'] == child.pid, 'Unexpected owned descendant')
                try:
                    rows = owned_sockets(child.pid, birth['start_ticks'])
                except (FileNotFoundError, PermissionError) as error:
                    # Linux can remove /proc/net or deny /proc/fd during exit.
                    # Never retry a denied read or change permissions. Only the
                    # independent WNOWAIT exit observation can end sampling;
                    # the earlier external closure acknowledgement remains mandatory.
                    if not exited_unreaped(child):
                        raise
                    row['exit_observation'] = dict(kind=type(error).__name__, closure_previously_verified=closed)
                    break
                validate_sockets(rows, runtime=phase != 'compile', closed=closed)
                if not closed:
                    need(time.monotonic() - started < CAPS['socket_close_seconds'], 'Startup closure deadline')
                    if (case / 'probe-port-closed.txt').exists():
                        acknowledge(case, rows); closed = True
                        row['closed'] = True
                        row['closure_seconds'] = time.monotonic() - started
                watcher = identity(os.getpid())['resident_pages'] * os.sysconf('SC_PAGE_SIZE')
                resident = current['resident_pages'] * os.sysconf('SC_PAGE_SIZE')
                need(watcher <= CAPS['watcher_bytes'] and resident + watcher <= CAPS['aggregate_bytes'], 'Observed RSS budget')
                row['samples'].append(dict(elapsed=time.monotonic() - started, identity=current,
                    sockets=rows, closed=closed, resident_bytes=resident, watcher_resident_bytes=watcher))
                need(len(row['samples']) <= 1000, 'Sample bound')
                artifacts(root, inputs); save(); time.sleep(.05)
            need(closed, 'Child exited before verified socket acknowledgement')
            row['closed'] = closed
        finally:
            if child is not None:
                if birth is None:
                    row['cleanup'] = dict(group_empty=False, errors=['Child birth unavailable; no foreign PID fallback'])
                else:
                    deadline = min(budget.start + CAPS['aggregate_seconds'], time.monotonic() + CAPS['cleanup_seconds'])
                    row['cleanup'] = cleanup(child, birth, deadline)
            after_cpu = resource.getrusage(resource.RUSAGE_CHILDREN)
            row['cpu_seconds'] = (after_cpu.ru_utime + after_cpu.ru_stime) - (before_cpu.ru_utime + before_cpu.ru_stime)
            row['seconds'] = time.monotonic() - started
            save()
    need(row['cleanup'] and row['cleanup'].get('exit_code') == 0 and row['cleanup']['group_empty']
         and not row['cleanup']['errors'], 'Owned child failed or cleanup incomplete')
    need(sum(item['cpu_seconds'] for item in receipt['children']) <= CAPS['cpu_seconds'], 'Aggregate owned CPU budget')


def main(output, byond, head, archive=None):
    native_gate(output, byond, head, archive)
    budget = Budget(datetime.now(timezone.utc) + timedelta(seconds=CAPS['aggregate_seconds']))
    receipt = dict(head=head, success=False, native_verified=False, phases=[], children=[],
                   scope='tiny collector and retained-file reader only; not Topic/serializer/Windows ACL acceptance')
    inputs = {}; originals = {}; output.mkdir(parents=True, exist_ok=False)

    def save():
        payload = json.dumps(receipt, indent=2).encode()
        need(len(payload) <= CAPS['receipt_bytes'], 'Receipt byte bound')
        artifacts(output, inputs, pending=len(payload))
        (output / 'result.json').write_bytes(payload)

    try:
        with budget.phase('preflight', receipt['phases']):
            need(subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, timeout=2).decode().strip() == head,
                 'Checkout differs from exact PR head')
            runtime = current_runtime(byond, archive)
            need((archive is None and runtime is None) or
                 (archive is not None and runtime is not None and runtime.identity['version'] == '516.1688'),
                 'Exact current runtime adapter required')
            need(not native_census(), 'Hosted native baseline must be empty')
            vacant_port(); need(shutil.disk_usage(output).free >= CAPS['disk_free_bytes'], 'Disk floor')
            for mode in MODES:
                prepare(output / 'prepared' / mode, mode)
            inputs = {path.relative_to(output).as_posix(): sha(path) for path in output.rglob('*') if path.is_file()}
            paths = ('tests/nomads_lifecycle/run_variable_probe_linux.py', 'tests/nomads_lifecycle/run_variable_probe.py',
                     'tests/nomads_lifecycle/prepare_variable_probe.py', 'tests/nomads_lifecycle/variable_probe.dm',
                     'tests/new_z_budget/z_budget_evidence.py', 'code/modules/persistence/variable_observability.dm',
                     'code/game/atoms_movable.dm', 'code/_helpers/text.dm',
                     'scripts/nomads-lifecycle/variable_observability.py', 'scripts/nomads-lifecycle/read_blackout.py')
            if runtime:
                paths += ('tests/world_save/current_runtime.py', 'scripts/byond_runtime.py',
                          'scripts/byond_toolchain.py', 'tools/byond/version.json')
            originals = {name:sha(ROOT / name) for name in paths}
            binaries = {name:sha(byond / name) for name in ('DreamMaker', 'DreamDaemon')}
            manifest = dict(head=head, source_sha256=originals, prepared_sha256=inputs,
                binary_sha256=binaries, native_verified=False, caps=CAPS, phases=PHASES, port=PORT)
            if runtime:
                manifest['runtime_identity'] = runtime.identity
            (output / 'source-manifest.json').write_text(json.dumps(manifest, indent=2))
            receipt['manifest_sha256'] = sha(output / 'source-manifest.json'); save()
        writable = output / 'prepared/writable'
        with budget.phase('compile', receipt['phases']):
            run_child([str(byond / 'DreamMaker'), '-max_errors', '0', 'probe.dme'], writable, 'compile', output,
                      inputs, binaries, receipt, budget, save, runtime)
            logs = ''.join((output / ('compile.' + stream + '.log')).read_text(errors='replace') for stream in ('stdout', 'stderr'))
            if runtime:
                runtime.validate_compile(0, logs, 'probe.dmb')
            else:
                validate_compile(0, logs, 'probe.dmb')
            need((writable / 'probe.dmb').is_file(), 'No tiny compiled artifact')
            receipt['compiled_sha256'] = {p.name:sha(p) for p in (writable / 'probe.dmb', writable / 'probe.rsc') if p.is_file()}
        for mode in MODES:
            case = output / 'prepared' / mode
            with budget.phase(mode, receipt['phases']):
                argv = daemon_argv(byond, writable / 'probe.dmb', case)
                run_child(argv, case, mode, output, inputs, binaries, receipt, budget, save, runtime)
                log_path = native_log_path(writable / 'probe.dmb', mode)
                text = log_path.read_text(errors='replace')
                console = ''.join((output / (mode + '.' + stream + '.log')).read_text(errors='replace') for stream in ('stdout', 'stderr'))
                footer = ('VARIABLE_OBSERVABILITY failures=0 native_collector_only=1' if mode == 'writable'
                    else f'VARIABLE_OBSERVABILITY publication={mode} failures=0 native_collector_only=1')
                need(text.splitlines().count(footer) == 1 and not DIAGNOSTIC.search(text + console), 'Native assertion/diagnostic failed')
                receipt.setdefault('native_logs', {})[mode] = dict(path=log_path.relative_to(output).as_posix(), sha256=sha(log_path))
                need(not (case / 'data/variable-observability-last-failure.json').exists(), 'Legacy output appeared')
                if mode == 'missing':
                    need(not (case / 'data/desktop-supervisor/variable-observability').exists(), 'Missing output directory created')
                if mode == 'obstructed':
                    need((case / 'data/desktop-supervisor/variable-observability/last-failure.json').is_dir(), 'Obstruction removed')
            if mode == 'writable':
                with budget.phase('reader', receipt['phases']):
                    read_captures(case, receipt, budget)
        with budget.phase('final', receipt['phases']):
            need(sha(output / 'source-manifest.json') == receipt['manifest_sha256'], 'Source manifest changed')
            need(all(sha(output / item['path']) == item['sha256'] for item in receipt['native_logs'].values()),
                 'Native log changed after its checked phase')
            need(all(sha(ROOT / name) == value for name, value in originals.items()), 'Source input changed')
            need(all(sha(output / name) == value for name, value in inputs.items()), 'Prepared input changed')
            need(all(sha(byond / name) == value for name, value in binaries.items()), 'Engine identity changed')
            if runtime:
                need(runtime.checks == ['compile', *MODES] and
                     runtime.verifier.verify_linux(runtime.bin_dir, runtime.archive) == runtime.identity,
                     'Current archive or installed runtime changed')
            need(not native_census(), 'Final native baseline not empty'); vacant_port()
            receipt.update(success=True, native_verified=True, artifacts=artifacts(output, inputs))
    except Exception as error:
        receipt['error'] = str(error)[:4096]
    finally:
        receipt['elapsed_seconds'] = time.monotonic() - budget.start
        receipt['success'] = receipt['success'] and receipt['elapsed_seconds'] <= CAPS['aggregate_seconds']
        receipt['native_verified'] = receipt['success']
        try:
            save()
        except Exception as error:
            receipt['success'] = receipt['native_verified'] = False
            failure = dict(success=False, native_verified=False, error=str(error)[:4096],
                original_error=receipt.get('error'), children=[dict(phase=x['phase'], identity=x.get('identity'),
                    cleanup=x.get('cleanup')) for x in receipt['children']])
            payload = json.dumps(failure, indent=2).encode()
            need(len(payload) <= CAPS['failure_bytes'], 'Terminal failure bound')
            (output / 'failure.json').write_bytes(payload)
    print(json.dumps(dict(success=receipt['success'], native_verified=receipt['native_verified'], output=str(output))))
    return 0 if receipt['success'] else 1


if __name__ == '__main__':
    cli = argparse.ArgumentParser(description=__doc__)
    cli.add_argument('--output', type=Path, required=True)
    cli.add_argument('--byond-bin', type=Path, required=True)
    cli.add_argument('--byond-archive', type=Path, help='Opt in to exact 516.1688 archive and member identity')
    cli.add_argument('--expected-head', required=True)
    args = cli.parse_args()
    raise SystemExit(main(args.output.resolve(), args.byond_bin.resolve(), args.expected_head,
                          args.byond_archive.absolute() if args.byond_archive else None))
