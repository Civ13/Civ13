"""Owned direct-child launcher and durable receipts.

Popen creation and filesystem IO are not hard-wallclock bounded. An outer queue
watchdog is still required. This helper provides no descendant containment.
Adapters have their stdlib signatures; writer(path, manifest) writes JSON.
"""
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import time


def write_manifest(path, manifest, *, replace=Path.replace, sleep=time.sleep):
    """Atomically replace a receipt, briefly retrying Windows sharing denials.

    Keep the existing receipt and prepared temporary file if replacement fails.
    The replace(source, destination) and sleep(seconds) adapters permit offline
    tests without delaying or performing the injected replacement operation.
    """
    temporary = path.with_suffix('.json.tmp')
    temporary.write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    for attempt in range(4):
        try:
            replace(temporary, path)
            return
        except PermissionError as error:
            if getattr(error, 'winerror', None) not in (5, 32, 33) or attempt == 3:
                raise
            sleep(0.05)


class OwnedRun:
    def __init__(self, root, prefix, metadata, files, *, popen=subprocess.Popen,
                 clock=time.monotonic, writer=write_manifest,
                 unlink=Path.unlink, rmtree=shutil.rmtree,
                 run_budget=240, cleanup_budget=15, copy=shutil.copy2,
                 mkdtemp=tempfile.mkdtemp):
        self.root = Path(root).resolve()
        self.files = [Path(p) if Path(p).is_absolute() else self.root / p for p in files]
        suffixes = ('.dme', '_world.dm', '_globals.dm', '_metadata.dm',
                    '.dmb', '.rsc', '_loot.dm', '_equipment.dm')
        if not re.fullmatch(r'\.mall_[0-9a-f]{32}', prefix):
            raise ValueError('Owned prefix must be .mall_ followed by a UUID hex string')
        if len(self.files) != 8 or len(set(self.files)) != 8:
            raise ValueError('Exactly eight distinct generated paths are required')
        if (any(p.parent.resolve() != self.root for p in self.files)
                or {p.name for p in self.files} != {prefix + s for s in suffixes}):
            raise ValueError('Generated files must be the eight exact owned names at root')
        self.popen, self.clock, self.writer = popen, clock, writer
        self.unlink, self.rmtree, self.copy = unlink, rmtree, copy
        self.mkdtemp = mkdtemp
        self.started = clock()
        self.deadline = self.started + run_budget
        self.cleanup_budget = cleanup_budget
        parent = self.root / 'data' / 'mall-fixture'
        parent.mkdir(parents=True, exist_ok=True)
        self.destination = parent / prefix
        self.destination.mkdir(exist_ok=False)
        self.runtime = None
        self.runtime_parent = None
        self.runtime_name = None
        self.runtime_identity = None
        self.children = []
        self.failed = False
        self.checkpoint_ok = True
        self.manifest = dict(schema_version=2, metadata=metadata, head_sha=None,
                             negative_control=metadata.get('negative_control'), timed_out=False,
                             ownership_scope='direct_child', stages=[],
                             cleanup=[], outcome='running', primary_exception=None)

    @property
    def head_sha(self):
        return self.manifest['head_sha']

    @head_sha.setter
    def head_sha(self, value):
        self.manifest['head_sha'] = value
        self.checkpoint()

    def checkpoint(self):
        try:
            self.writer(self.destination / 'manifest.json', self.manifest)
        except BaseException:
            self.failed = True
            self.checkpoint_ok = False
            raise

    def __enter__(self):
        self.checkpoint()
        return self

    def create_runtime(self):
        if self.failed or self.runtime is not None:
            raise RuntimeError('Runtime creation is unavailable')
        # Capture the intended parent before accepting a returned directory.
        self.runtime_parent = self.destination.resolve()
        created = Path(self.mkdtemp(prefix='civ13-mall-', dir=self.runtime_parent))
        if (created.parent.resolve() != self.runtime_parent or created.is_symlink()
                or not created.name.startswith('civ13-mall-')):
            raise RuntimeError('Runtime creation escaped the owned receipt directory')
        self.runtime = created.resolve()
        self.runtime_name = self.runtime.name
        identity = self.runtime.stat()
        self.runtime_identity = (identity.st_dev, identity.st_ino)
        self.manifest['runtime'] = str(self.runtime)
        self.checkpoint()
        return self.runtime

    def run(self, stage, command, cwd, timeout, creationflags=0):
        if self.failed:
            raise RuntimeError('A previous failure prohibits future launches')
        command = [str(part) for part in command]
        ordinal = len(self.manifest['stages'])
        started = self.clock()
        # Stage names are labels only; filenames cannot escape the receipt.
        stem = 'stage-%02d' % ordinal
        row = dict(stage=stage, command=command, cwd=str(cwd), pid=None,
                   exit=None, status='prelaunch', timeout=False, error=None,
                   started_monotonic=started, finished_monotonic=None,
                   elapsed_seconds=None, requested_timeout=timeout, wait_allowance=None,
                   stdout=stem + '.stdout.txt', stderr=stem + '.stderr.txt')
        self.manifest['stages'].append(row)
        self.checkpoint()
        process = None
        try:
            stage_deadline = min(self.deadline, started + timeout)
            remaining = stage_deadline - self.clock()
            if remaining <= 0:
                raise subprocess.TimeoutExpired(command, 0)
            with (self.destination / row['stdout']).open('wb') as stdout:
                with (self.destination / row['stderr']).open('wb') as stderr:
                    process = self.popen(command, cwd=cwd, stdin=subprocess.DEVNULL,
                                         stdout=stdout, stderr=stderr,
                                         creationflags=creationflags)
                    self.children.append((process, row))
                    row.update(pid=process.pid, status='postlaunch')
                    self.checkpoint()
                    remaining = stage_deadline - self.clock()
                    if remaining <= 0:
                        raise subprocess.TimeoutExpired(command, 0)
                    row['wait_allowance'] = remaining
                    code = process.wait(timeout=remaining)
                    finished = self.clock()
                    row.update(exit=code, status='exited', finished_monotonic=finished,
                               elapsed_seconds=finished - started)
            if code:
                self.failed = True
                row['status'] = 'nonzero'
            self.checkpoint()
            return subprocess.CompletedProcess(
                command, code,
                (self.destination / row['stdout']).read_text(encoding='utf-8', errors='replace'),
                (self.destination / row['stderr']).read_text(encoding='utf-8', errors='replace'))
        except BaseException as error:
            self.failed = True
            self.manifest['timed_out'] |= isinstance(error, subprocess.TimeoutExpired)
            finished = self.clock()
            row.update(status='failed', timeout=isinstance(error, subprocess.TimeoutExpired),
                       error=repr(error), finished_monotonic=finished,
                       elapsed_seconds=finished - started)
            # Recording failure must never replace the launch/wait exception.
            try:
                self.checkpoint()
            except BaseException as checkpoint_error:
                self.manifest['cleanup'].append(dict(action='stage-checkpoint',
                                                    error=repr(checkpoint_error)))
            raise

    def __exit__(self, exception_type, exception, traceback):
        if exception is not None:
            self.failed = True
            self.manifest['primary_exception'] = repr(exception)
        cleanup_errors = []

        def attempt(action, operation):
            try:
                result = operation()
                self.manifest['cleanup'].append(dict(action=action, status='ok'))
                return True, result
            except BaseException as error:
                cleanup_errors.append(error)
                self.manifest['cleanup'].append(dict(action=action, status='failed',
                                                    error=repr(error)))
                return False, None

        # A failed checkpoint permanently prohibits destructive file cleanup.
        attempt('pre-cleanup-checkpoint', self.checkpoint)
        cleanup_deadline = min(self.deadline + self.cleanup_budget,
                               self.clock() + self.cleanup_budget)
        all_exited = True
        for process, row in self.children:
            try:
                code = process.poll()
                if code is None:
                    if cleanup_deadline - self.clock() <= 0:
                        raise TimeoutError('Cleanup budget exhausted before direct-child kill')
                    process.kill()
                    remaining = min(5, cleanup_deadline - self.clock())
                    if remaining <= 0:
                        raise TimeoutError('Cleanup budget exhausted before direct-child wait')
                    code = process.wait(timeout=remaining)
                row['exit'] = code
                row['direct_child_exit_confirmed'] = True
                self.manifest['cleanup'].append(dict(action='direct-child-exit',
                                                    pid=process.pid, status='confirmed'))
            except BaseException as error:
                all_exited = False
                cleanup_errors.append(error)
                row['direct_child_exit_confirmed'] = False
                self.manifest['cleanup'].append(dict(action='direct-child-exit',
                                                    pid=process.pid, error=repr(error)))

        preserve = not all_exited or not self.checkpoint_ok
        if all_exited:
            if self.runtime is not None:
                for name in ('result.txt', 'stages.txt', 'runtime.log'):
                    source = self.runtime / name
                    try:
                        if source.exists():
                            ok, _ = attempt('retain-' + name,
                                            lambda s=source, n=name: self.copy(s, self.destination / n))
                            preserve = preserve or not ok
                    except BaseException as error:
                        cleanup_errors.append(error)
                        preserve = True
                        self.manifest['cleanup'].append(dict(action='inspect-' + name,
                                                            error=repr(error)))
            hashes = {}
            for path in self.files:
                try:
                    if path.exists():
                        digest = hashlib.sha256()
                        with path.open('rb') as source:
                            for chunk in iter(lambda: source.read(1024 * 1024), b''):
                                digest.update(chunk)
                        hashes[path.name] = digest.hexdigest()
                except BaseException as error:
                    cleanup_errors.append(error)
                    preserve = True
                    self.manifest['cleanup'].append(dict(action='hash-' + path.name,
                                                        error=repr(error)))
            self.manifest['generated_sha256'] = hashes
        ok, _ = attempt('evidence-checkpoint', self.checkpoint)
        preserve = preserve or not ok or not self.checkpoint_ok
        if not preserve:
            # Attempt every exact owned file even if one unlink fails.
            for path in self.files:
                attempt('unlink-' + path.name, lambda p=path: self.unlink(p, missing_ok=True))
            if self.runtime is not None:
                def remove_runtime():
                    resolved = self.runtime.resolve()
                    if (resolved != self.runtime or resolved.parent != self.runtime_parent
                            or resolved.name != self.runtime_name
                            or not resolved.name.startswith('civ13-mall-')
                            or self.runtime.is_symlink()):
                        raise RuntimeError('Runtime ownership check failed')
                    identity = self.runtime.stat()
                    if (identity.st_dev, identity.st_ino) != self.runtime_identity:
                        raise RuntimeError('Runtime directory identity changed')
                    self.rmtree(self.runtime)
                attempt('remove-runtime', remove_runtime)
        else:
            self.manifest['cleanup'].append(dict(action='preserve-files', status='required'))
        self.manifest['outcome'] = 'failed' if self.failed or cleanup_errors else 'passed'
        written, _ = attempt('final-checkpoint', self.checkpoint)
        if not written:
            self.manifest['outcome'] = 'failed'
            self.manifest['receipt_write_failed'] = True
            # A writer may write and then raise. Best effort replaces any such
            # success snapshot; failure still propagates even if this succeeds.
            attempt('failed-final-checkpoint', self.checkpoint)
        if exception is None:
            if cleanup_errors:
                raise RuntimeError('Owned run cleanup failed; inspect receipt at ' +
                                   str(self.destination)) from cleanup_errors[0]
            if self.failed:
                raise RuntimeError('Owned run failed; inspect receipt at ' + str(self.destination))
        return False
