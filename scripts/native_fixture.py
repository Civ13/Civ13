"""Serial Windows fixture supervisor. Import is inert; no launch or approval CLI.

Reuse the versioned floor-decal adapter's detached, suspended, retained-handle
launch, but never its old terminal acceptance/accounting policy. Each phase owns
a fresh one-process Job and must account for every process ever assigned to it.
Linux CI retains its existing subprocess timeout path in the fixture callers.
"""
import ctypes
from dataclasses import dataclass
import importlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
MIB = 1024**2
CHILD_CAP = 1920*MIB
WATCHER_CAP = 128*MIB
FREE_FLOOR = 6*1024**3
LOG_CAP = 16*MIB
ARTIFACT_CAP = 1024*MIB


def require(value, message):
    if not value:
        raise RuntimeError(message)


def read_bounded(path, maximum=LOG_CAP):
    with Path(path).open('rb') as stream:
        value = stream.read(maximum+1)
    require(len(value) <= maximum, 'Fixture evidence exceeds read bound: '+str(path))
    return value.decode('utf-8', errors='replace')


def no_port_args():
    # -ip constrains any attempted initial bind. It does not mean no listener.
    # DM OpenPort overrides reject opening, and the watcher rejects ANY socket.
    return ['-ip', '127.0.0.1', '-nowebclient']


class WindowsBackend:
    """Native binding occurs only when an explicitly invoked runner creates this."""
    def __init__(self, *, adapter=None, windows=None, owned=None):
        if adapter is not None:
            require(windows is not None and owned is not None, 'Inject complete native facade')
            self.windows, self.owned, self.a = windows, owned, adapter
            self.captured = []
            return
        directory = ROOT/'tests/floor_decal_tracking'
        sys.path.insert(0, str(directory))
        try:
            modules = {name: importlib.import_module(name) for name in ('windows', 'guard_config', 'owned_job')}
        finally:
            sys.path.pop(0)
        for name, module in modules.items():
            require(Path(module.__file__).resolve() == directory/(name+'.py'), 'Wrong native adapter module')
        self.windows, self.owned = modules['windows'], modules['owned_job']
        self.a = self.windows.Adapter()
        self.captured = []

    def open(self, timeout):
        self.a.open()
        self.timeout = timeout
        limits = self.windows.JobLimits()
        limits.basic.flags = 0x2000 | 0x8 | 0x100 | 0x200 | 0x4
        limits.basic.active = 1
        limits.basic.job_time = int(timeout*10_000_000)
        limits.process_memory = CHILD_CAP
        limits.job_memory = CHILD_CAP
        self.a.check(self.a.k.SetInformationJobObject(self.a.job, 9, ctypes.byref(limits), ctypes.sizeof(limits)))

    def resources(self):
        return self.a.memory(self.a.k.GetCurrentProcess()), self.a.free()

    def launch(self, argv, cwd, evidence, phase):
        return self.a.launch(argv, cwd, evidence, phase)

    def identity(self, child):
        return self.a.identity(child)

    def observe(self, child):
        exited = self.a.exited(child)
        value = self.a.accounting()
        membership = self.owned.query_members(self.a)
        for pid in membership['pids']:
            if pid != child.pid:
                self.captured.append(self.owned.capture_unexpected(self.a, pid))
        limits = self.windows.JobLimits()
        self.a.check(self.a.k.QueryInformationJobObject(self.a.job, 9, ctypes.byref(limits), ctypes.sizeof(limits), None))
        require(limits.basic.flags == 0x230C and limits.basic.active == 1 and
                limits.basic.job_time == int(self.timeout*10_000_000) and
                limits.process_memory == limits.job_memory == CHILD_CAP, 'Native Job limits changed')
        watcher, free = self.resources()
        return dict(exited=exited, total=value.total, active=value.active, terminated=value.terminated,
                    members=membership['pids'], retained=len(self.a.retained),
                    private=0 if exited else self.a.memory(child.process), watcher=watcher, free=free,
                    sockets=self.a.sockets(child), cpu=self.a.times(child)[1])

    def finish(self, child):
        return self.a.finish(child)

    def cleanup(self, seconds):
        # Unlike the older runner, attest handle closes as well as retained waits.
        deadline = time.monotonic()+seconds
        errors, exits = [], []
        total_assigned = 0
        if self.a.job:
            try:
                total_assigned = self.a.accounting().total
            except Exception as error:
                total_assigned = None
                errors.append('Final cumulative accounting unavailable: '+str(error))
            if not self.a.k.TerminateJobObject(self.a.job, 1):
                errors.append('Job termination failed')
            if not self.a.k.CloseHandle(self.a.job):
                errors.append('Job close failed')
            self.a.job = None
        for process in self.a.retained:
            try:
                wait = self.a.k.WaitForSingleObject(process.process, max(0, int((deadline-time.monotonic())*1000)))
                require(wait == 0, 'Retained owned exit unconfirmed')
                code = self.windows.w.DWORD()
                self.a.check(self.a.k.GetExitCodeProcess(process.process, ctypes.byref(code)))
                exits.append(dict(identity=self.a.identity(process), exit_code=code.value))
            except Exception as error:
                errors.append(str(error))
            finally:
                for handle in (process.thread, process.process):
                    if handle and not self.a.k.CloseHandle(handle):
                        errors.append('Retained handle close failed')
        return dict(all_retained_exited=not errors, exits=exits, errors=errors,
                    captured_unexpected=self.captured, total_assigned=total_assigned)


def validate_sample(sample, pid):
    # A child can enter and exit between snapshots. Empty membership is NOT
    # sufficient: the cumulative count must equal the one retained root exactly.
    require(sample['total'] == sample['retained'] == 1, 'Unretained or unexpected cumulative Job process')
    require(sample['active'] in (0, 1) and sample['terminated'] == 0, 'Job process limit/termination failure')
    require(len(sample['members']) <= 1 and all(x == pid for x in sample['members']), 'Unexpected active Job member')
    require(sample['private'] <= CHILD_CAP and sample['watcher'] <= WATCHER_CAP and
            sample['private']+sample['watcher'] <= CHILD_CAP+WATCHER_CAP, 'Native/private memory budget')
    require(sample['free'] >= FREE_FLOOR, 'Host free memory floor')
    require(not sample['sockets'], 'Owned native socket observed (including startup)')


def output_bounds(evidence, artifacts):
    for path in evidence.rglob('*'):
        require(not path.is_symlink() and not (getattr(path.lstat(), 'st_file_attributes', 0) & 0x400), 'Evidence reparse point')
    text = [p for p in evidence.rglob('*') if p.is_file() and p.suffix not in ('.dmb', '.rsc')]
    require(sum(p.stat().st_size for p in text) <= LOG_CAP, 'Generated text/state evidence budget')
    for path in [*artifacts, *evidence.glob('*.dmb'), *evidence.glob('*.rsc')]:
        if path.exists():
            require(path.is_file() and path.stat().st_size <= ARTIFACT_CAP, 'Compiled artifact budget')


@dataclass
class Session:
    """One in-process supervisor for four serial phases; no grant-file layer."""
    evidence: Path
    head: str
    backend_factory: object = WindowsBackend
    now: object = time.monotonic
    pause: object = time.sleep

    def __post_init__(self):
        self.evidence = Path(self.evidence).resolve()
        self.evidence.mkdir(parents=True, exist_ok=False)
        self.started = self.now()
        self.deadline = self.started+330
        self.cleanup_deadline = self.started+360
        self.phases = []
        self.busy = False
        self.failed = False

    def persist(self):
        value = json.dumps(dict(head=self.head, phases=self.phases,
                               elapsed=self.now()-self.started, failed=self.failed,
                               network_limit='Any sampled socket fails; no continuous/transient absence claim'), indent=2)
        require(len(value.encode()) <= 4*MIB, 'Supervisor receipt budget')
        (self.evidence/'containment.json').write_text(value, encoding='utf-8')

    def run(self, argv, *, cwd, phase, timeout, artifacts=(), state_directory=None):
        require(not self.failed and not self.busy and len(self.phases) < 4, 'Session failed, concurrent or launch-count limit')
        require(self.now() < self.deadline, 'Aggregate work deadline')
        require(phase.replace('-', '').isalnum(), 'Invalid phase evidence name')
        require(0 < timeout <= 120, 'Invalid phase timeout')
        native = self.backend_factory()
        row = dict(phase=phase, argv=list(map(str, argv)), cwd=str(cwd), samples=[], accepted=False)
        self.phases.append(row)
        work = self.evidence/phase
        work.mkdir(exist_ok=False)
        self.busy = True
        child = None
        maximum_total = 0
        try:
            native.open(timeout)
            watcher, free = native.resources()
            require(watcher <= WATCHER_CAP and free >= FREE_FLOOR, 'Native preflight memory budget')
            self.persist()
            child = native.launch(list(map(str, argv)), Path(cwd), work, phase)
            row['identity'] = native.identity(child)
            start = self.now()
            drained_since = None
            while True:
                require(self.now() < min(self.deadline, start+timeout), 'Phase/aggregate work deadline')
                sample = native.observe(child)
                row['samples'].append(sample)
                maximum_total = max(maximum_total, sample['total'])
                self.persist()  # Preserve the rejected observation before raising.
                validate_sample(sample, child.pid)
                require(sample['cpu'] <= timeout, 'Native CPU budget')
                output_bounds(work, artifacts)
                if state_directory is not None:
                    output_bounds(Path(state_directory), ())
                if sample['exited']:
                    if sample['active'] == 0 and not sample['members']:
                        break
                    drained_since = self.now() if drained_since is None else drained_since
                    require(self.now()-drained_since < 2, 'Exited Job accounting did not settle')
                self.pause(.1)
            row['final'] = native.finish(child)
            require(row['final']['total_processes'] == 1 and row['final']['active_processes'] == 0,
                    'Terminal cumulative Job process mismatch')
            output_bounds(work, artifacts)
            if state_directory is not None:
                output_bounds(Path(state_directory), ())
            stdout = read_bounded(work/(phase+'.stdout.log'))
            stderr = read_bounded(work/(phase+'.stderr.log'))
            row['accepted'] = row['final']['exit_code'] == 0
            self.failed = not row['accepted']
            return subprocess.CompletedProcess(argv, row['final']['exit_code'], stdout, stderr)
        except BaseException as error:
            row['error'] = str(error)
            self.failed = True
            raise
        finally:
            try:
                row['cleanup'] = native.cleanup(max(0, min(30, self.cleanup_deadline-self.now())))
                cleanup_total = row['cleanup']['total_assigned']
                row['owned_exit_evidence_complete'] = (cleanup_total is not None and
                                                       max(maximum_total, cleanup_total) == len(row['cleanup']['exits']) and
                                                       row['cleanup']['all_retained_exited'])
                require(row['owned_exit_evidence_complete'] and not row['cleanup']['errors'], 'Owned cleanup/exit accounting incomplete')
                require(self.now() <= self.cleanup_deadline, 'Aggregate cleanup deadline')
            except BaseException as error:
                row['cleanup_error'] = str(error)
                row['accepted'] = False
                self.failed = True
                raise
            finally:
                self.busy = False
                self.persist()


def run_native(session, argv, *, cwd, phase, timeout, artifacts=(), state_directory=None):
    if session is not None:
        return session.run(argv, cwd=cwd, phase=phase, timeout=timeout,
                           artifacts=artifacts, state_directory=state_directory)
    require(os.name != 'nt', 'Windows native fixtures require their contained Session')
    return subprocess.run(argv, cwd=cwd, capture_output=True, text=True, timeout=timeout)
