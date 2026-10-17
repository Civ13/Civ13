"""Source-only, injected-adapter build supervisor. This module grants no lease.

The native adapter is deliberately not instantiated here and there is no CLI.
Caller supplies frozen provenance, reviewed commands and a staging callback.
"""
from dataclasses import dataclass
from hashlib import sha256
import json
import os
from pathlib import Path
import uuid

GIB = 1024 ** 3
CAP = 2 * GIB
WATCHER_RESERVE = 128 * 1024 ** 2
FLOOR = 6 * GIB
TOTAL_SECONDS = 900
CLEANUP_SECONDS = 30


class GuardFailure(RuntimeError):
    pass


@dataclass(frozen=True)
class Command:
    argv: tuple[str, ...]
    cwd: str = 'source'


def confined(root, relative):
    """Reject lexical escapes and every existing reparse component before use.

    Workspace ACLs must exclude concurrent writers: path validation cannot stop
    a hostile process exchanging a checked directory after this call.
    """
    root = Path(root).absolute()
    relative = Path(relative)
    if relative.is_absolute() or '..' in relative.parts or relative.drive:
        raise GuardFailure('Output path escapes workspace')
    candidate = root / relative
    for part in [candidate, *candidate.parents]:
        try:
            stat = part.lstat()
        except FileNotFoundError:
            continue
        if part.is_symlink() or getattr(stat, 'st_file_attributes', 0) & 0x400:
            raise GuardFailure('Reparse path is forbidden')
    return candidate


def run(adapter, output_parent, commands, environment, provenance: bytes, stage):
    """Run serialized roots in ONE new job; terminate only this owned job.

    Adapter contract: new_process returns fresh suspended process/thread handles;
    events reports every new/exit process through a completion port associated
    before assignment. Its handles survive until final exit verification. Unknown
    ownership or lost notifications fail closed. stage(root) does filesystem-only
    preparation, never launches processes. Caller authenticates source/gitlinks,
    patch and SDK BEFORE supplying provenance; this guard does not certify them.
    """
    start = adapter.now()
    cleanup_deadline = start + TOTAL_SECONDS
    work_deadline = cleanup_deadline - CLEANUP_SECONDS
    commands = tuple(commands)
    if not commands or not provenance or not environment:
        raise ValueError('Explicit commands, provenance and environment required')
    for command in commands:
        if not command.argv or not Path(command.argv[0]).is_absolute():
            raise ValueError('Executable must be an explicit absolute trusted path')
        if any('\0' in value for value in command.argv):
            raise ValueError('NUL in argv')
    parent = confined(output_parent, '.')
    if not parent.is_dir():
        raise ValueError('Existing workspace parent required')
    root = confined(parent, 'server-build-' + str(uuid.uuid4()))
    root.mkdir()  # atomic, never reuse an existing output
    receipt = root / 'caller-provenance.bin'
    receipt.write_bytes(provenance)
    digest = sha256(provenance).hexdigest()
    job = None
    handles = {}  # PID -> retained handle; never PID-only termination
    threads = []
    unassigned = []  # only freshly created suspended roots
    root_results = []
    owned_exits = []
    failures = []
    cleanup_errors = []
    peak = 0
    min_free = None

    def collect():
        for kind, pid in adapter.events(job):
            if kind == 'new':
                if pid not in handles:
                    handle = adapter.open_owned(job, pid)
                    handles[pid] = handle
                if not adapter.in_job(job, handles[pid]):
                    raise GuardFailure('Unknown child ownership')
            elif kind == 'exit':
                if pid not in handles:
                    raise GuardFailure('Exit notification without retained handle')
            else:
                raise GuardFailure('Unknown Job notification')
        active = adapter.active_pids(job)
        if any(pid not in handles for pid in active):
            raise GuardFailure('Active process lacks retained membership handle')
        for pid in active:
            if not adapter.in_job(job, handles[pid]):
                raise GuardFailure('Lost Job membership')
        if not active and adapter.assigned_count(job) != len(handles):
            raise GuardFailure('Job accounting reveals an unretained child')
        return active

    def sample():
        nonlocal peak, min_free
        active = collect()
        watcher = adapter.watcher_private()
        if watcher is None or watcher > WATCHER_RESERVE:
            raise GuardFailure('Watcher exceeds reserved budget or is unmeasured')
        values = [adapter.private(handles[pid]) for pid in active]
        if any(value is None for value in values):
            raise GuardFailure('Unmeasured owned memory')
        total = watcher + sum(values)
        available = adapter.free_memory()
        peak = max(peak, total)
        min_free = available if min_free is None else min(min_free, available)
        if total > CAP:
            raise GuardFailure('Aggregate private memory cap')
        if available < FLOOR:
            raise GuardFailure('Host free memory floor')
        if adapter.now() >= work_deadline:
            raise GuardFailure('Work deadline (cleanup reserved)')
        return active

    try:
        watcher = adapter.watcher_private()
        if adapter.free_memory() < FLOOR or watcher is None or watcher > WATCHER_RESERVE:
            raise GuardFailure('Preflight resource floor/reserve')
        job = adapter.new_job(CAP - WATCHER_RESERVE)
        stage(root)
        sample()
        env = dict(environment)
        for name in ('TEMP', 'TMP', 'DOTNET_CLI_HOME', 'NUGET_PACKAGES',
                     'NUGET_HTTP_CACHE_PATH', 'MSBUILDDEBUGPATH'):
            path = confined(root, 'cache/' + name.lower())
            path.mkdir(parents=True, exist_ok=True)
            env[name] = str(path)
        env.update(MSBUILDDISABLENODEREUSE='1', DOTNET_PROCESSOR_COUNT='2',
                   DOTNET_CLI_TELEMETRY_OPTOUT='1', DOTNET_GCHeapHardLimit='0x30000000')
        for command in commands:
            sample()
            if sha256(confined(root, 'caller-provenance.bin').read_bytes()).hexdigest() != digest:
                raise GuardFailure('Frozen caller receipt changed')
            cwd = confined(root, command.cwd)
            if not cwd.is_dir():
                raise GuardFailure('Command working directory missing')
            process, thread, pid = adapter.new_process(command.argv, cwd, env)
            unassigned.append(process)
            threads.append(thread)
            adapter.assign(job, process)
            unassigned.remove(process)
            handles[pid] = process
            if not adapter.in_job(job, process):
                raise GuardFailure('Root assignment unverified before resume')
            sample()
            adapter.resume(thread)
            # Do not start next root while ANY descendants of this root survive.
            while sample():
                adapter.pause(min(0.1, max(0, work_deadline - adapter.now())))
            code = adapter.exit_code(process)
            root_results.append({'argv': list(command.argv), 'exit_code': code})
            if code != 0:
                raise GuardFailure('Command root failed')
            # Check every child exit before permitting the next command root.
            for handle in handles.values():
                if adapter.exit_code(handle) != 0:
                    raise GuardFailure('Owned child failed')
    except Exception as error:
        failures.append(str(error))
    finally:
        # Assignment failure cannot leak a fresh, still-suspended root. This is
        # the ONLY direct-process termination: never attach an existing process.
        for process in unassigned:
            try:
                adapter.stop_unassigned(process)
                if not adapter.wait(process, max(0, cleanup_deadline - adapter.now())):
                    raise GuardFailure('Unassigned root did not exit')
                adapter.exit_code(process)
            except Exception as error:
                cleanup_errors.append(str(error))
        if job is not None:
            try:
                adapter.terminate(job)
                while collect():
                    if adapter.now() >= cleanup_deadline:
                        raise GuardFailure('Job cleanup deadline')
                    adapter.pause(min(0.1, cleanup_deadline - adapter.now()))
            except Exception as error:
                cleanup_errors.append(str(error))
            # Invoke kill-on-close BEFORE retained waits, so a failed explicit
            # terminate cannot consume the cleanup budget with live processes.
            try:
                adapter.close_job(job)
            except Exception as error:
                cleanup_errors.append(str(error))
        # A broken notification/inventory must not skip retained-handle checks.
        for pid, handle in handles.items():
            try:
                if not adapter.wait(handle, max(0, cleanup_deadline - adapter.now())):
                    raise GuardFailure('Retained owned handle did not exit')
                owned_exits.append({'pid': pid, 'exit_code': adapter.exit_code(handle)})
            except Exception as error:
                cleanup_errors.append(str(error))
        # Kill-on-close remains the fallback, even when inventory/cleanup failed.
        for handle in [*threads, *handles.values(), *unassigned]:
            try:
                adapter.close(handle)
            except Exception as error:
                cleanup_errors.append(str(error))
        if adapter.now() > cleanup_deadline:
            cleanup_errors.append('Overall 15-minute deadline exceeded')
    result = dict(success=not failures and not cleanup_errors, failures=failures,
                  cleanup_errors=cleanup_errors, commands=root_results,
                  owned_exits=owned_exits,
                  caller_provenance_sha256=digest, peak_private_bytes=peak,
                  minimum_host_free_bytes=min_free, elapsed=adapter.now()-start)
    confined(root, 'guard-result.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
    return root, result
