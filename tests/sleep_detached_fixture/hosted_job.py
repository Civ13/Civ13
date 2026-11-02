"""Manual hosted sleep-fixture preparation and separately gated execution.

This program is not invoked on import. Preparation uses the network to acquire
reviewed immutable bytes; native processes only run in explicitly selected
execute mode, after job-local identity binding. No live game is accessed.
"""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import signal
import stat
import subprocess
import sys
import tempfile
import time
import zipfile
import select

ROOT = Path(__file__).resolve().parent
REPO = ROOT.parents[1]
IMAGE_REF = 'docker.io/library/python@sha256:e859437f5f6d28ecc8452905c49f0729533f72e680feec294186e1ab3799a445'
ARCHIVE_URL = 'https://github.com/Civ13/Civ13/releases/download/byond-toolchain-cache-516.1688-linux-16278f318cde/516.1688_byond_linux.zip'
ARCHIVE_SHA = '16278f318cdeb4b77c57868dd7135032fde717ea6226269d22b2a1a50968e7f9'
ARCHIVE_SIZE = 4887281
REPO_ID = '141349998'
HEX64 = re.compile(r'^[0-9a-f]{64}$')

def require(value, message):
    if not value: raise ValueError(message)

def digest(raw): return hashlib.sha256(raw).hexdigest()

def load_module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
    return module

def verify_scope(repo, manifest, expected):
    require(HEX64.fullmatch(expected or '') is not None, 'reviewed scope hash required')
    data = manifest.read_bytes()
    require(len(data) <= 1024 * 1024 and digest(data) == expected, 'scope manifest hash')
    row = json.loads(data)
    require(type(row) is dict and row.get('schema') == 1 and type(row.get('files')) is dict, 'scope manifest')
    for name, want in row['files'].items():
        path = Path(name)
        require(not path.is_absolute() and '..' not in path.parts and HEX64.fullmatch(want or '') is not None, 'scope path')
        target = repo / path
        for part in (target, *target.parents):
            if part == repo.parent: break
            require(not part.is_symlink(), 'linked scope input')
        require(target.is_file() and target.stat().st_size <= 2 * 1024**2 and digest(target.read_bytes()) == want, 'scope input changed: ' + name)
    return row

def capture(command, env, timeout=30, trace=None):
    import resource
    def limits():
        resource.setrlimit(resource.RLIMIT_FSIZE, (1024 * 1024, 1024 * 1024))
        resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    with tempfile.TemporaryFile() as stdout, tempfile.TemporaryFile() as stderr:
        process = subprocess.Popen(command, env=env, stdin=subprocess.DEVNULL, stdout=stdout,
                                   stderr=stderr, start_new_session=True, preexec_fn=limits)
        timed_out = False; deadline = time.monotonic() + timeout
        try:
            while os.waitid(os.P_PID, process.pid, os.WEXITED | os.WNOHANG | os.WNOWAIT) is None:
                if time.monotonic() >= deadline:
                    timed_out = True; break
                time.sleep(.05)
        finally:
            try: os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError: pass
            process.wait(timeout=10)
        stdout.seek(0); stderr.seek(0)
        out = stdout.read(1024 * 1024 + 1); err = stderr.read(1024 * 1024 + 1)
        if trace:
            (trace / 'acquisition.stdout.log').write_bytes(out)
            (trace / 'acquisition.stderr.log').write_bytes(err)
        require(len(out) <= 1024 * 1024 and len(err) <= 1024 * 1024, 'command output oversized')
        require(not timed_out and process.returncode == 0, 'command failed or timed out; remote outcome may be unknown')
        return out

def download_archive(path):
    import urllib.request
    request = urllib.request.Request(ARCHIVE_URL, headers={'User-Agent': 'civ13-synthetic-fixture'})
    with urllib.request.urlopen(request, timeout=45) as response:
        data = response.read(ARCHIVE_SIZE + 1)
    require(len(data) == ARCHIVE_SIZE and digest(data) == ARCHIVE_SHA, 'BYOND archive mismatch')
    path.write_bytes(data)

def extract_runtime(archive, directory):
    directory.mkdir(mode=0o700)
    with zipfile.ZipFile(archive) as package:
        for name in ('DreamMaker', 'DreamDaemon', 'libbyond.so', 'libext.so'):
            matches = [x for x in package.infolist() if x.filename == 'byond/bin/' + name]
            require(len(matches) == 1 and 0 < matches[0].file_size <= 32 * 1024**2, 'runtime archive member')
            data = package.read(matches[0])
            require(len(data) == matches[0].file_size, 'runtime member length')
            target = directory / name
            target.write_bytes(data); target.chmod(0o500 if name in ('DreamMaker', 'DreamDaemon') else 0o400)
    verifier = load_module('sleep_runtime_identity', ROOT / 'scripts/byond_runtime.py')
    return verifier.verify_linux(directory, archive)

def image_inspect(docker, config, binding, evidence):
    env = {'PATH': '/usr/bin:/bin', 'HOME': str(config), 'LANG': 'C', 'LC_ALL': 'C'}
    binding_module = load_module('sleep_binding_check', ROOT / 'host_binding.py')
    binding_module.same_daemon(docker, config, binding)
    raw = capture([str(docker), '--host', binding_module.ENDPOINT, '--config', str(config),
                   'image', 'inspect', binding_module.IMAGE_ID], env)
    (evidence / 'image-inspect.json').write_bytes(raw)
    row = json.loads(raw)
    contract = load_module('sleep_image_contract', ROOT / 'outer_container_contract.py')
    require(type(row) is list and len(row) == 1, 'image inspect shape')
    contract.validate_image(row[0], binding_module.IMAGE_ID)
    binding_module.same_daemon(docker, config, binding)
    return {'id': row[0]['Id'], 'os': row[0]['Os'], 'architecture': row[0]['Architecture']}

def prepare(args):
    require(sys.platform.startswith('linux') and os.geteuid() != 0, 'unprivileged Linux required')
    require(os.environ.get('GITHUB_REPOSITORY_ID') == REPO_ID and os.environ.get('RUNNER_ENVIRONMENT') == 'github-hosted', 'host/repository scope')
    require(re.fullmatch(r'[0-9a-f]{40}', args.head or '') is not None and os.environ.get('GITHUB_SHA') == args.head, 'exact head required')
    require(capture(['git', '-C', str(REPO), 'rev-parse', 'HEAD'], os.environ).decode().strip() == args.head, 'checkout head mismatch')
    verify_scope(REPO, ROOT / 'hosted-scope.json', args.scope_sha256)
    require(shutil.disk_usage('/tmp').free >= 16 * 1024**3, 'less than 16 GiB free')
    args.evidence.mkdir(parents=True, exist_ok=True)
    binding_module = load_module('sleep_host_binding', ROOT / 'host_binding.py')
    docker = Path(shutil.which('docker') or '').resolve(strict=True)
    python = Path(sys.executable).resolve(strict=True)
    config = Path(tempfile.mkdtemp(prefix='sleep-docker-config-', dir='/tmp'))
    before = binding_module.socket_identity()
    daemon = binding_module.info(docker, config)
    require(binding_module.socket_identity() == before, 'socket changed during initial daemon read')
    binding = {'socket': before, 'daemon': daemon}
    env = {'PATH': '/usr/bin:/bin', 'HOME': str(config), 'LANG': 'C', 'LC_ALL': 'C'}
    # This may contact the registry; an uncertain timeout is a failed prepare.
    binding_module.same_daemon(docker, config, binding)
    capture([str(docker), '--host', binding_module.ENDPOINT, '--config', str(config),
             'pull', '--platform', 'linux/386', IMAGE_REF], env, timeout=180, trace=args.evidence)
    image = image_inspect(docker, config, binding, args.evidence)
    args.work.mkdir(mode=0o700)
    archive = args.work / 'archive.zip'; download_archive(archive)
    runtime = extract_runtime(archive, args.work / 'bin')
    binding_module.same_daemon(docker, config, binding)
    verify_scope(REPO, ROOT / 'hosted-scope.json', args.scope_sha256)
    receipt = {'schema': 1, 'status': 'prepared', 'phase': 'before_native', 'mode': args.mode,
               'run_id': os.environ.get('GITHUB_RUN_ID'), 'run_attempt': os.environ.get('GITHUB_RUN_ATTEMPT'),
               'job': os.environ.get('GITHUB_JOB'), 'head': args.head, 'scope_sha256': args.scope_sha256,
               'boot_id': binding_module.boot_identity(), 'runner_image_os': os.environ.get('ImageOS'),
               'runner_image_version': os.environ.get('ImageVersion'), 'python_path': str(python), 'python_sha256': binding_module.file_hash(python),
               'docker_path': str(docker), 'docker_sha256': binding_module.file_hash(docker),
               'endpoint': binding_module.ENDPOINT, 'socket': before, 'daemon': daemon,
               'image_id': image['id'], 'image': image, 'runtime': runtime,
               'native_executed': False, 'cleanup_scope': 'Preparation does not create a container; pull failures may have an uncertain daemon outcome.'}
    require(all(isinstance(receipt[x], str) and receipt[x] for x in ('run_id', 'run_attempt', 'job')), 'missing job identity')
    args.evidence.mkdir(parents=True, exist_ok=True)
    (args.evidence / 'prepared.json').write_text(json.dumps(receipt, sort_keys=True, indent=2) + '\n', encoding='utf-8')
    return receipt

def execute(args, receipt):
    require(HEX64.fullmatch(args.expected_python or '') and HEX64.fullmatch(args.expected_docker or ''), 'reviewed host hashes required')
    require(receipt['python_sha256'] == args.expected_python and receipt['docker_sha256'] == args.expected_docker, 'host executable differs from reviewed prepare')
    require(receipt['mode'] == 'execute' and receipt['native_executed'] is False, 'invalid execution receipt')
    verify_scope(REPO, ROOT / 'hosted-scope.json', args.scope_sha256)
    sandbox = Path(tempfile.mkdtemp(prefix='sleep-owned-', dir='/tmp'))
    runner = ROOT / 'outer_container_runner.py'
    cmd = [receipt['python_path'], '-I', str(runner), '--run-native', '--sandbox', str(sandbox),
           '--byond-bin', str(args.work / 'bin'), '--byond-archive', str(args.work / 'archive.zip'),
           '--image-id', receipt['image_id'], '--docker', receipt['docker_path'], '--docker-sha256', receipt['docker_sha256'],
           '--python-sha256', receipt['python_sha256'], '--runner-sha256', digest(runner.read_bytes()), '--binding', str(args.evidence / 'prepared.json')]
    (args.evidence / 'execution-started.json').write_text(json.dumps({'status': 'started', 'sandbox': str(sandbox)}) + '\n', encoding='utf-8')
    verified = False
    try:
        supervise_outer(cmd, sandbox, args.evidence)
        verified = True
    finally:
        # An uncertain cleanup never causes traversal of container-writable tmp.
        destination = args.evidence / 'owned-sandbox'
        if sandbox.exists() and not destination.exists():
            copy_evidence(sandbox, destination, evidence_roots(verified))

def evidence_roots(cleanup_verified):
    return ('main', 'watch', 'tmp', 'source', 'runtime') if cleanup_verified is True else ('main', 'watch')

def proc_identity(pid):
    raw = Path('/proc/%d/stat' % pid).read_text(encoding='ascii')
    end = raw.rfind(')')
    require(end > 0, 'watchdog proc identity unavailable')
    fields = raw[end + 2:].split()
    require(len(fields) > 19, 'watchdog proc identity incomplete')
    return (int(fields[1]), int(fields[19]))  # parent PID, kernel start ticks

def read_host_receipt(path):
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    try:
        before = os.fstat(fd)
        require(stat.S_ISREG(before.st_mode) and before.st_size <= 4096, 'invalid host receipt')
        raw = os.read(fd, 4097); after = os.fstat(fd)
        require(len(raw) == before.st_size and (before.st_dev, before.st_ino, before.st_size, before.st_mtime_ns, before.st_ctime_ns) ==
                (after.st_dev, after.st_ino, after.st_size, after.st_mtime_ns, after.st_ctime_ns), 'host receipt changed')
        return raw
    finally: os.close(fd)

def bind_watchdog(ready_path, owner_pid):
    """Pin the still-owned watchdog, refusing reparenting and PID replacement."""
    raw = read_host_receipt(ready_path)
    require(len(raw) <= 4096, 'watchdog ready oversized')
    row = json.loads(raw)
    require(type(row) is dict, 'watchdog ready shape')
    pid = row.get('watchdog_pid')
    require(type(pid) is int and pid > 1 and row.get('owner_pid') == owner_pid, 'watchdog ready identity')
    before = proc_identity(pid)
    require(before[0] == owner_pid, 'watchdog parent changed')
    fd = os.pidfd_open(pid, 0)
    try:
        poll = select.poll(); poll.register(fd, select.POLLIN)
        require(not poll.poll(0) and proc_identity(pid) == before and read_host_receipt(ready_path) == raw,
                'watchdog changed while binding')
        return fd, poll
    except Exception:
        os.close(fd); raise

def classify_watchdog_events(events, watcher_fd, pollin):
    if any(fd == watcher_fd and flags & pollin for fd, flags in events): return 'pidfd_exit_observed'
    return 'pidfd_unexpected_event' if events else 'not_observed_before_deadline'

def supervise_outer(command, sandbox, evidence):
    import resource
    def limits():
        resource.setrlimit(resource.RLIMIT_FSIZE, (8 * 1024**2, 8 * 1024**2))
        resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    timed_out = False; watcher_fd = None; watcher_poll = None; watcher_bind = 'not_observed'; owner_error = None
    with (evidence / 'outer.stdout.log').open('xb') as out, (evidence / 'outer.stderr.log').open('xb') as err:
        proc = subprocess.Popen(command, stdin=subprocess.DEVNULL, stdout=out, stderr=err,
                                start_new_session=True, preexec_fn=limits)
        deadline = time.monotonic() + 550
        try:
            while os.waitid(os.P_PID, proc.pid, os.WEXITED | os.WNOHANG | os.WNOWAIT) is None:
                ready = sandbox / 'watch/watchdog-ready.json'
                if watcher_bind == 'not_observed' and ready.is_file():
                    try:
                        watcher_fd, watcher_poll = bind_watchdog(ready, proc.pid)
                        watcher_bind = 'pidfd_bound'
                    except (OSError, ValueError, TypeError, AttributeError, KeyError):
                        watcher_bind = 'identity_unverified'
                if time.monotonic() >= deadline:
                    timed_out = True; break
                time.sleep(.1)
        except Exception as exc:
            owner_error = 'outer wait unverified: ' + str(exc)[:512]
        finally:
            try: os.killpg(proc.pid, signal.SIGKILL)
            except ProcessLookupError: pass
            except OSError as exc: owner_error = 'outer group signal unverified: ' + str(exc)
            try: proc.wait(timeout=10)
            except subprocess.TimeoutExpired: owner_error = 'outer process termination unverified'
    monitor = {'binding': watcher_bind, 'termination': 'unknown', 'cleanup_receipt': 'not_observed', 'owner_error': owner_error}
    try:
        if watcher_poll is not None:
            try:
                events = watcher_poll.poll(60000 if (timed_out or owner_error or proc.returncode != 0) else 0)
                monitor['termination'] = classify_watchdog_events(events, watcher_fd, select.POLLIN)
            except OSError:
                monitor['termination'] = 'pidfd_poll_failed'
        if (sandbox / 'watch/watchdog-result.json').is_file():
            monitor['cleanup_receipt'] = 'present_uninterpreted'
        (evidence / 'watchdog-monitor.json').write_text(json.dumps(monitor, sort_keys=True) + '\n', encoding='utf-8')
    finally:
        if watcher_fd is not None: os.close(watcher_fd)
    if timed_out:
        raise TimeoutError('outer deadline; cleanup requires retained watchdog review')
    require(owner_error is None, owner_error)
    require(proc.returncode == 0, 'outer runner did not pass; inspect retained evidence')
    result = json.loads((sandbox / 'main/outer-result.json').read_bytes())
    require(result.get('status') == 'passed_synthetic' and
            result.get('cleanup', {}).get('status') == 'docker_cleanup_verified', 'outer result or cleanup unverified')

def bounded_fd_copy(fd, destination, budget):
    """Copy bytes from one already-open descriptor, enforcing bounds while reading."""
    before = os.fstat(fd)
    require(stat.S_ISREG(before.st_mode) and before.st_size <= 256 * 1024**2, 'invalid evidence file')
    copied = 0
    with destination.open('xb') as out:
        while True:
            data = os.read(fd, min(1024 * 1024, 256 * 1024**2 - copied + 1))
            if not data: break
            copied += len(data); budget['bytes'] += len(data)
            require(copied <= 256 * 1024**2 and budget['bytes'] <= 512 * 1024**2, 'evidence byte limit')
            out.write(data)
    after = os.fstat(fd)
    identity = lambda x: (x.st_dev, x.st_ino, x.st_size, x.st_mtime_ns, x.st_ctime_ns)
    require(identity(before) == identity(after) and copied == before.st_size, 'evidence changed during copy')

def copy_evidence(source, destination, roots):
    """No-follow descriptor traversal with live entry and byte budgets."""
    require(hasattr(os, 'O_NOFOLLOW') and hasattr(os, 'O_DIRECTORY') and os.scandir in os.supports_fd and os.open in os.supports_dir_fd,
            'descriptor-bound evidence copy unavailable')
    require(type(roots) is tuple and all(name in ('main', 'watch', 'tmp', 'source', 'runtime') for name in roots), 'evidence roots')
    flags = os.O_RDONLY | os.O_NOFOLLOW | os.O_DIRECTORY
    budget = {'entries': 0, 'bytes': 0}
    destination.mkdir(mode=0o700)
    def walk(fd, target, depth):
        require(depth <= 8, 'evidence depth')
        with os.scandir(fd) as entries:
            for entry in entries:
                budget['entries'] += 1
                require(budget['entries'] <= 1024, 'evidence entry limit')
                info = entry.stat(follow_symlinks=False)
                require(not stat.S_ISLNK(info.st_mode), 'linked evidence refused')
                if stat.S_ISDIR(info.st_mode):
                    child = os.open(entry.name, flags, dir_fd=fd)
                    try:
                        (target / entry.name).mkdir(mode=0o700)
                        walk(child, target / entry.name, depth + 1)
                    finally: os.close(child)
                else:
                    require(stat.S_ISREG(info.st_mode), 'special evidence refused')
                    child = os.open(entry.name, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=fd)
                    try: bounded_fd_copy(child, target / entry.name, budget)
                    finally: os.close(child)
    rootfd = os.open(source, flags)
    try:
        for name in roots:
            try: child = os.open(name, flags, dir_fd=rootfd)
            except FileNotFoundError: continue
            try:
                (destination / name).mkdir(mode=0o700)
                walk(child, destination / name, 0)
            finally: os.close(child)
    finally: os.close(rootfd)

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--mode', choices=('prepare', 'execute'), required=True)
    p.add_argument('--head', required=True); p.add_argument('--scope-sha256', required=True)
    p.add_argument('--work', type=Path, required=True); p.add_argument('--evidence', type=Path, required=True)
    p.add_argument('--expected-python', default=''); p.add_argument('--expected-docker', default='')
    args = p.parse_args()
    try:
        receipt = prepare(args)
        if args.mode == 'execute': execute(args, receipt)
    except Exception as exc:
        args.evidence.mkdir(parents=True, exist_ok=True)
        (args.evidence / 'hosted-failure.json').write_text(json.dumps({'status': 'held', 'error': str(exc)[:1024]}, indent=2) + '\n', encoding='utf-8')
        raise

if __name__ == '__main__': main()
